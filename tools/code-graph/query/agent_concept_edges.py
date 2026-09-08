#!/usr/bin/env python3
"""Extract directed concept relations between .agent Markdown sections.

Companion to ``agent_semantic_poc.py``. Where that script embeds sections and
ranks them by cosine similarity, this one turns *undirected* semantic proximity
into *directed* relations so the concept graph can infer a hierarchical order:

    prerequisite  -- understanding A is needed before B (A is foundational)
    implements    -- B implements / realizes the plan or idea in A
    supersedes    -- B replaces or updates A
    references    -- related, but no dependency direction
    none          -- not meaningfully related

Candidate pairs are restricted to each section's nearest neighbours in cosine
space (reusing the embedding cache), so the LLM only judges plausibly-related
pairs instead of the full O(n^2) product. Results are cached to ``.out/`` keyed
by the unordered pair of section hashes, exactly like the embedding cache, so a
cold run is a one-off cost and re-runs are nearly free.

Evidence-first, per tools/code-graph/AGENTS.md: every edge carries a relation
kind and a confidence, and these are model-derived approximations, not facts.

Strategies:
    --strategy llm         ask a chat model (OpenRouter or Ollama) per pair batch
    --strategy structural  derive edges deterministically from heading/path
                           nesting (no API; free baseline and offline test path)

Example:
    export OPENROUTER_API_KEY=...
    python3 tools/code-graph/query/agent_concept_edges.py \
      --glob '.agent/**/*.md' \
      --strategy llm --backend openrouter --model deepseek/deepseek-chat \
      --k 8 --threshold 0.5
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import re
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.error import HTTPError
from pathlib import Path

import sys

TOOL_ROOT = Path(__file__).resolve().parents[1]
QUERY_ROOT = TOOL_ROOT / "query"
if str(QUERY_ROOT) not in sys.path:
    sys.path.insert(0, str(QUERY_ROOT))

from agent_semantic_poc import (  # noqa: E402
    REPO_ROOT,
    Section,
    default_cache_path,
    load_cache,
    split_markdown,
)

import glob as _glob  # noqa: E402

DEFAULT_EDGES_CACHE = TOOL_ROOT / ".out" / "agent_concept_edges.jsonl"
DEFAULT_CSV = TOOL_ROOT / ".out" / "concept_edges.csv"
RELATIONS = ("prerequisite", "implements", "supersedes", "references", "none")
JSON_ARRAY_RE = re.compile(r"\[.*\]", re.DOTALL)
# Column order must match the cgq.py SCHEMAS["concept_edges"] entry.
CSV_COLUMNS = [
    "relation", "confidence", "similarity",
    "from_path", "from_heading", "to_path", "to_heading",
    "a_path", "b_path", "from_sha", "to_sha", "a_sha", "b_sha",
    "model", "strategy",
]


def pair_key(sha_a: str, sha_b: str, strategy: str, model: str) -> str:
    lo, hi = sorted((sha_a, sha_b))
    return hashlib.sha256(f"{strategy}\0{model}\0{lo}\0{hi}".encode()).hexdigest()


def load_sections(glob_pat: str, max_chars: int, min_chars: int) -> list[Section]:
    paths = sorted(Path(p) for p in _glob.glob(str(REPO_ROOT / glob_pat), recursive=True))
    return [
        section
        for path in paths
        for section in split_markdown(path, max_chars, min_chars, context_prefix=True)
    ]


def section_vectors(
    sections: list[Section], backend: str, model: str, dimension: int, cache: Path
) -> dict[str, list[float]]:
    """Map section.item_id -> embedding using the existing embedding cache."""
    raw = load_cache(cache, backend, model, dimension)
    out: dict[str, list[float]] = {}
    for s in sections:
        key = hashlib.sha256(f"{backend}\0{model}\0{dimension}\0document\0{s.sha256}".encode()).hexdigest()
        vec = raw.get(key)
        if vec is not None:
            out[s.item_id] = vec
    return out


def knn_candidate_pairs(
    sections: list[Section], vectors: dict[str, list[float]], k: int, threshold: float
) -> list[tuple[int, int, float]]:
    """Undirected nearest-neighbour pairs in cosine space (needs numpy)."""
    import numpy as np

    indexed = [(i, s) for i, s in enumerate(sections) if s.item_id in vectors]
    if len(indexed) < 2:
        return []
    idx = [i for i, _ in indexed]
    matrix = np.array([vectors[s.item_id] for _, s in indexed], dtype=np.float32)
    matrix = matrix / np.maximum(np.linalg.norm(matrix, axis=1, keepdims=True), 1e-12)
    pairs: dict[tuple[int, int], float] = {}
    rows = len(idx)
    chunk = 512
    kk = min(k + 1, rows)
    for start in range(0, rows, chunk):
        block = matrix[start:start + chunk] @ matrix.T  # (chunk, rows)
        for local, sims in enumerate(block):
            i = start + local
            sims[i] = -1.0
            top = np.argpartition(-sims, kk - 1)[:kk]
            for j in top:
                sim = float(sims[j])
                if sim < threshold:
                    continue
                a, b = (i, int(j)) if i < int(j) else (int(j), i)
                if a == b:
                    continue
                prev = pairs.get((a, b))
                if prev is None or sim > prev:
                    pairs[(a, b)] = sim
    return [(idx[a], idx[b], sim) for (a, b), sim in pairs.items()]


# ---------------------------------------------------------------- LLM backends

def chat_openrouter(api_key: str, model: str, system: str, user: str) -> tuple[str, dict]:
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0,
    }).encode()
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "HTTP-Referer": "https://github.com/motoko-agent/motoko_agent",
            "X-Title": "motoko-agent concept edge extraction",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.loads(resp.read())
    except HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise RuntimeError(f"OpenRouter chat failed: HTTP {exc.code}: {detail}") from exc
    text = data["choices"][0]["message"]["content"]
    return text, data.get("usage") or {}


def chat_ollama(url: str, model: str, system: str, user: str) -> tuple[str, dict]:
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "stream": False,
        "options": {"temperature": 0},
    }).encode()
    req = urllib.request.Request(
        url.rstrip("/") + "/api/chat",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = json.loads(resp.read())
    return data.get("message", {}).get("content", ""), {}


SYSTEM_PROMPT = (
    "You build a concept dependency graph from documentation sections. For each "
    "numbered PAIR decide the single best relation between section A and section B:\n"
    "- prerequisite: understanding A is needed before B (A is the foundation)\n"
    "- implements: B implements or realizes the plan/idea described in A\n"
    "- supersedes: B replaces or updates A\n"
    "- references: related but neither depends on the other\n"
    "- none: not meaningfully related\n"
    'Reply with ONLY a JSON array, one object per pair, in order: '
    '[{"pair":1,"relation":"prerequisite","from":"A","to":"B","confidence":0.82}]. '
    'For prerequisite/implements/supersedes set from/to to the directed pair (from = '
    'foundation/plan/older, to = dependent/result/newer). For references/none set '
    'from and to to null. confidence is 0..1.'
)


def excerpt(section: Section, limit: int = 320) -> str:
    body = " ".join(section.text.split())
    return body[:limit]


def build_user_prompt(batch: list[tuple[Section, Section, float]]) -> str:
    lines = ["PAIRS:"]
    for n, (a, b, _sim) in enumerate(batch, start=1):
        lines.append(f"{n}. A: {a.path} :: {a.heading}\n   {excerpt(a)}")
        lines.append(f"   B: {b.path} :: {b.heading}\n   {excerpt(b)}")
    return "\n".join(lines)


def parse_relations(text: str, batch_len: int) -> list[dict]:
    match = JSON_ARRAY_RE.search(text)
    if not match:
        return []
    try:
        data = json.loads(match.group(0))
    except json.JSONDecodeError:
        return []
    out: list[dict] = []
    for item in data:
        if isinstance(item, dict):
            out.append(item)
    return out


# ----------------------------------------------------------------- structural

def structural_edges(sections: list[Section]) -> list[dict]:
    """Deterministic directed edges from heading + path nesting.

    Parent heading -> child heading within a file (prerequisite), and shallower
    path -> deeper path is left to the LLM strategy; here we only use the
    in-file heading tree, which is unambiguous and needs no model.
    """
    by_path: dict[str, list[Section]] = {}
    for s in sections:
        by_path.setdefault(s.path, []).append(s)
    edges: list[dict] = []
    for _path, secs in by_path.items():
        secs = sorted(secs, key=lambda s: s.start_line)
        stack: list[Section] = []
        for s in secs:
            while stack and stack[-1].level >= s.level:
                stack.pop()
            if stack:
                parent = stack[-1]
                edges.append({
                    "from_sha": parent.sha256, "to_sha": s.sha256,
                    "a_id": parent.item_id, "b_id": s.item_id,
                    "relation": "prerequisite", "confidence": 0.5,
                })
            stack.append(s)
    return edges


def call_llm(batch, backend, api_key, ollama_url, model) -> tuple[str, dict]:
    user = build_user_prompt([(a, b, sim) for a, b, sim, _ in batch])
    if backend == "openrouter":
        return chat_openrouter(api_key, model, SYSTEM_PROMPT, user)
    return chat_ollama(ollama_url, model, SYSTEM_PROMPT, user)


def rows_from_response(batch, text: str, model: str) -> list[dict]:
    parsed = parse_relations(text, len(batch))
    by_pair = {int(item.get("pair", 0)): item for item in parsed if "pair" in item}
    out: list[dict] = []
    for n, (a, b, sim, key) in enumerate(batch, start=1):
        item = by_pair.get(n, {})
        relation = item.get("relation")
        if relation not in RELATIONS:
            relation = "none"
        frm, to = item.get("from"), item.get("to")
        from_sha = to_sha = None
        if relation in ("prerequisite", "implements", "supersedes"):
            if frm == "A" and to == "B":
                from_sha, to_sha = a.sha256, b.sha256
            elif frm == "B" and to == "A":
                from_sha, to_sha = b.sha256, a.sha256
        try:
            confidence = float(item.get("confidence", 0.0))
        except (TypeError, ValueError):
            confidence = 0.0
        out.append({
            "key": key, "strategy": "llm", "model": model,
            "a_id": a.item_id, "a_sha": a.sha256,
            "b_id": b.item_id, "b_sha": b.sha256,
            "similarity": round(sim, 4),
            "relation": relation, "confidence": round(confidence, 3),
            "from_sha": from_sha, "to_sha": to_sha,
        })
    return out


def export_csv(jsonl_path: Path, csv_path: Path, sections: list[Section]) -> int:
    """Flatten the directed-edge JSONL cache into a chDB-queryable CSV.

    Denormalizes path + heading for both endpoints (and the directed from/to)
    so cgq.py queries read without a join. References/none rows keep a_/b_ but
    leave from_/to_ blank. Confidence and similarity are carried through so the
    table stays evidence-first: these are model approximations, not facts.
    """
    meta = {s.sha256: (s.path, s.heading) for s in sections}

    def lookup(sha, fallback_id):
        if sha and sha in meta:
            return meta[sha]
        if fallback_id:  # item_id is "<path>:<line>:<slug>"
            return fallback_id.rsplit(":", 2)[0], ""
        return "", ""

    csv_path.parent.mkdir(parents=True, exist_ok=True)
    written = 0
    with csv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_COLUMNS)
        writer.writeheader()
        for line in jsonl_path.read_text(errors="replace").splitlines():
            if not line.strip():
                continue
            r = json.loads(line)
            a_path, a_head = lookup(r.get("a_sha"), r.get("a_id"))
            b_path, b_head = lookup(r.get("b_sha"), r.get("b_id"))
            from_path, from_head = lookup(r.get("from_sha"), None)
            to_path, to_head = lookup(r.get("to_sha"), None)
            writer.writerow({
                "relation": r.get("relation", ""),
                "confidence": r.get("confidence", ""),
                "similarity": r.get("similarity", ""),
                "from_path": from_path, "from_heading": from_head,
                "to_path": to_path, "to_heading": to_head,
                "a_path": a_path, "b_path": b_path,
                "from_sha": r.get("from_sha") or "", "to_sha": r.get("to_sha") or "",
                "a_sha": r.get("a_sha") or "", "b_sha": r.get("b_sha") or "",
                "model": r.get("model", ""), "strategy": r.get("strategy", ""),
            })
            written += 1
    return written


# ---------------------------------------------------------------------- driver

def main() -> int:
    started = time.perf_counter()
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--glob", default=".agent/**/*.md")
    p.add_argument("--strategy", choices=["llm", "structural"], default="llm")
    p.add_argument("--backend", choices=["openrouter", "ollama"], default="openrouter")
    p.add_argument("--model", default=None, help="chat model (default: deepseek/deepseek-chat or llama3.1)")
    p.add_argument("--ollama-url", default=os.environ.get("OLLAMA_URL", "http://host.docker.internal:11435"))
    p.add_argument("--api-key-env", default="OPENROUTER_API_KEY")
    # embedding source for candidate generation
    p.add_argument("--embed-backend", choices=["ollama", "openrouter"], default="ollama")
    p.add_argument("--embed-model", default="embeddinggemma")
    p.add_argument("--embed-dimension", type=int, default=0)
    p.add_argument("--embed-cache", type=Path, default=None)
    # candidate + chunking knobs (chunking must match the notebook defaults)
    p.add_argument("--k", type=int, default=8, help="nearest neighbours per node for candidate pairs")
    p.add_argument("--threshold", type=float, default=0.5, help="min cosine similarity for a candidate pair")
    p.add_argument("--max-chars", type=int, default=6000)
    p.add_argument("--min-section-chars", type=int, default=200)
    p.add_argument("--batch-pairs", type=int, default=12)
    p.add_argument("--concurrency", type=int, default=8, help="parallel in-flight LLM requests")
    p.add_argument("--limit", type=int, default=0, help="cap pairs sent to the LLM (0 = no cap)")
    p.add_argument("--cache", type=Path, default=DEFAULT_EDGES_CACHE)
    p.add_argument("--dry-run", action="store_true", help="report candidate pairs, do not call the LLM")
    p.add_argument("--export-csv", nargs="?", type=Path, const=DEFAULT_CSV, default=None,
                   help="flatten --cache into a chDB-queryable CSV and exit (default .out/concept_edges.csv)")
    args = p.parse_args()

    if args.model is None:
        args.model = "deepseek/deepseek-chat" if args.backend == "openrouter" else "llama3.1"
    embed_dim = args.embed_dimension if args.embed_backend == "openrouter" else 0
    if args.embed_cache is None:
        args.embed_cache = default_cache_path(args.embed_backend, args.embed_model, embed_dim)

    sections = load_sections(args.glob, args.max_chars, args.min_section_chars)
    by_sha = {s.sha256: s for s in sections}

    if args.export_csv is not None:
        if not args.cache.exists():
            print(json.dumps({"error": f"edge cache not found: {args.cache}"}, indent=2))
            return 1
        n = export_csv(args.cache, args.export_csv, sections)
        print(json.dumps({
            "exported_rows": n, "from": str(args.cache), "csv": str(args.export_csv),
            "elapsed_seconds": round(time.perf_counter() - started, 3),
        }, indent=2))
        return 0

    if args.strategy == "structural":
        edges = structural_edges(sections)
        args.cache.parent.mkdir(parents=True, exist_ok=True)
        with args.cache.open("w") as f:
            for e in edges:
                f.write(json.dumps({**e, "strategy": "structural", "model": "structural"}) + "\n")
        print(json.dumps({
            "strategy": "structural", "sections": len(sections), "edges": len(edges),
            "cache": str(args.cache), "elapsed_seconds": round(time.perf_counter() - started, 3),
        }, indent=2))
        return 0

    vectors = section_vectors(sections, args.embed_backend, args.embed_model, embed_dim, args.embed_cache)
    if not vectors:
        print(json.dumps({
            "error": "no embeddings found; run agent_semantic_poc.py to populate the cache first",
            "embed_cache": str(args.embed_cache),
        }, indent=2))
        return 1
    candidates = knn_candidate_pairs(sections, vectors, args.k, args.threshold)
    candidates.sort(key=lambda t: t[2], reverse=True)

    # skip already-cached pairs
    cached_keys: set[str] = set()
    if args.cache.exists():
        for line in args.cache.read_text(errors="replace").splitlines():
            if line.strip():
                row = json.loads(line)
                if row.get("key"):
                    cached_keys.add(row["key"])

    todo: list[tuple[Section, Section, float, str]] = []
    for ia, ib, sim in candidates:
        a, b = sections[ia], sections[ib]
        key = pair_key(a.sha256, b.sha256, args.strategy, args.model)
        if key in cached_keys:
            continue
        todo.append((a, b, sim, key))
    if args.limit:
        todo = todo[:args.limit]

    if args.dry_run:
        print(json.dumps({
            "strategy": "llm", "sections": len(sections), "with_vectors": len(vectors),
            "candidate_pairs": len(candidates), "uncached_pairs": len(todo),
            "k": args.k, "threshold": args.threshold, "cache": str(args.cache),
        }, indent=2))
        return 0

    api_key = os.environ.get(args.api_key_env, "")
    if args.backend == "openrouter" and not api_key:
        print(json.dumps({"error": f"set {args.api_key_env} for the openrouter backend"}, indent=2))
        return 1

    args.cache.parent.mkdir(parents=True, exist_ok=True)
    bp = max(1, args.batch_pairs)
    batches = [todo[i:i + bp] for i in range(0, len(todo), bp)]
    requests = 0
    written = 0
    failed = 0
    usage_total: dict = {}
    write_lock = threading.Lock()

    def work(batch):
        text, usage = call_llm(batch, args.backend, api_key, args.ollama_url, args.model)
        return rows_from_response(batch, text, args.model), usage

    with args.cache.open("a") as out:
        with ThreadPoolExecutor(max_workers=max(1, args.concurrency)) as pool:
            futures = [pool.submit(work, batch) for batch in batches]
            for done in as_completed(futures):
                try:
                    batch_rows, usage = done.result()
                except Exception:  # one bad batch must not abort the sweep
                    failed += 1
                    continue
                requests += 1
                with write_lock:
                    for row in batch_rows:
                        out.write(json.dumps(row) + "\n")
                        written += 1
                    out.flush()
                for kx, vx in usage.items():
                    if isinstance(vx, (int, float)):
                        usage_total[kx] = usage_total.get(kx, 0) + vx

    tokens = int(usage_total.get("total_tokens") or usage_total.get("prompt_tokens") or 0)
    print(json.dumps({
        "strategy": "llm", "backend": args.backend, "model": args.model,
        "sections": len(sections), "with_vectors": len(vectors),
        "candidate_pairs": len(candidates), "judged_pairs": written,
        "llm_requests": requests, "failed_batches": failed,
        "concurrency": max(1, args.concurrency), "batch_pairs": bp,
        "api_usage": usage_total, "tokens": tokens,
        "cache": str(args.cache), "elapsed_seconds": round(time.perf_counter() - started, 3),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
