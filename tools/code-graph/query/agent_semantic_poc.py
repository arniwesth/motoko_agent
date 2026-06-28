#!/usr/bin/env python3
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import math
import os
import re
import time
import urllib.request
from urllib.error import HTTPError
from dataclasses import dataclass
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
DEFAULT_CACHE = TOOL_ROOT / ".out" / "agent_section_embeddings_embeddinggemma.jsonl"
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
WORD_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_/#.-]*")


@dataclass
class Section:
    item_id: str
    path: str
    heading: str
    level: int
    start_line: int
    end_line: int
    text: str
    embed_text: str
    sha256: str


def repo_rel(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()


def _file_title(path: Path, lines: list[str]) -> str:
    for line in lines:
        match = HEADING_RE.match(line)
        if match:
            return match.group(2).strip()
    return path.stem.replace("_", " ").replace("-", " ")


def _heading_stack(starts: list[tuple[int, int, str]], pos: int) -> list[str]:
    stack: list[tuple[int, str]] = []
    for _start, level, heading in starts[:pos + 1]:
        while stack and stack[-1][0] >= level:
            stack.pop()
        stack.append((level, heading))
    return [heading for _level, heading in stack]


def _raw_sections(path: Path) -> list[tuple[int, int, str, int, int, str]]:
    rel = repo_rel(path)
    lines = path.read_text(errors="replace").splitlines()
    starts: list[tuple[int, int, str]] = []
    for idx, line in enumerate(lines, start=1):
        match = HEADING_RE.match(line)
        if match:
            starts.append((idx, len(match.group(1)), match.group(2).strip()))
    if not starts:
        starts = [(1, 1, path.stem)]
    raw: list[tuple[int, int, str, int, int, str]] = []
    for pos, (start, level, heading) in enumerate(starts):
        end = (starts[pos + 1][0] - 1) if pos + 1 < len(starts) else len(lines)
        text = "\n".join(lines[start - 1:end]).strip()
        hierarchy = " > ".join(_heading_stack(starts, pos))
        raw.append((start, end, heading, level, pos, text if text else hierarchy))
    return raw


def _merge_tiny(raw: list[tuple[int, int, str, int, int, str]], min_chars: int) -> list[tuple[int, int, str, int, int, str]]:
    if min_chars <= 0:
        return raw
    merged: list[tuple[int, int, str, int, int, str]] = []
    pending: tuple[int, int, str, int, int, str] | None = None
    for current in raw:
        item = current
        if pending is not None:
            start, _end, heading, level, pos, text = pending
            item = (start, current[1], f"{heading} / {current[2]}", level, pos, text + "\n\n" + current[5])
            pending = None
        if len(item[5]) < min_chars and item is not raw[-1]:
            pending = item
            continue
        merged.append(item)
    if pending is not None:
        if merged:
            prev = merged.pop()
            merged.append((prev[0], pending[1], prev[2], prev[3], prev[4], prev[5] + "\n\n" + pending[5]))
        else:
            merged.append(pending)
    return merged


def split_markdown(path: Path, max_chars: int, min_chars: int, context_prefix: bool) -> list[Section]:
    rel = repo_rel(path)
    lines = path.read_text(errors="replace").splitlines()
    title = _file_title(path, lines)
    starts: list[tuple[int, int, str]] = []
    for idx, line in enumerate(lines, start=1):
        match = HEADING_RE.match(line)
        if match:
            starts.append((idx, len(match.group(1)), match.group(2).strip()))
    if not starts:
        starts = [(1, 1, path.stem)]
    raw = _merge_tiny(_raw_sections(path), min_chars)
    sections: list[Section] = []
    for start, end, heading, level, pos, text in raw:
        if len(text) > max_chars:
            text = text[:max_chars]
        hierarchy = " > ".join(_heading_stack(starts, min(pos, len(starts) - 1)))
        embed_text = text
        if context_prefix:
            embed_text = f"Path: {rel}\nTitle: {title}\nSection: {hierarchy}\n\n{text}"
        digest = hashlib.sha256(embed_text.encode()).hexdigest()
        slug = re.sub(r"[^A-Za-z0-9]+", "-", heading).strip("-").lower() or "section"
        item_id = f"{rel}:{start}:{slug}"
        sections.append(Section(item_id, rel, heading, level, start, end, text, embed_text, digest))
    return sections


def query_terms(query: str) -> list[str]:
    return [term.lower() for term in WORD_RE.findall(query) if len(term) >= 3]


def lexical_boost(query: str, section: Section) -> float:
    terms = query_terms(query)
    if not terms:
        return 0.0
    haystack = f"{section.path}\n{section.heading}\n{section.text}".lower()
    hits = sum(1 for term in terms if term in haystack)
    exact = 0.03 * hits
    symbol_hits = sum(1 for term in terms if any(ch in term for ch in "_#/.") and term in haystack)
    symbol = 0.05 * symbol_hits
    tiny_penalty = 0.04 if len(section.text) < 200 else 0.0
    return exact + symbol - tiny_penalty


def default_cache_path(backend: str, model: str, dimension: int) -> Path:
    safe_model = re.sub(r"[^A-Za-z0-9_.-]+", "-", model).strip("-").lower()
    suffix = f"_{dimension}" if dimension else ""
    if backend == "ollama" and model == "embeddinggemma" and not suffix:
        return DEFAULT_CACHE
    return TOOL_ROOT / ".out" / f"agent_section_embeddings_{backend}_{safe_model}{suffix}.jsonl"


def load_cache(path: Path, backend: str, model: str, dimension: int) -> dict[str, list[float]]:
    cache: dict[str, list[float]] = {}
    if not path.exists():
        return cache
    for line in path.read_text(errors="replace").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        row_backend = row.get("backend", "ollama" if row.get("model") == "embeddinggemma" else "")
        row_dimension = int(row.get("dimension") or 0)
        if row_backend == backend and row.get("model") == model and row_dimension == dimension:
            cache[row["cache_key"]] = row["embedding"]
    return cache


def append_cache(path: Path, backend: str, model: str, dimension: int, cache_key: str, embedding: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as f:
        f.write(json.dumps({
            "backend": backend,
            "model": model,
            "dimension": dimension,
            "cache_key": cache_key,
            "embedding": embedding,
        }) + "\n")


def embed(ollama_url: str, model: str, text: str) -> list[float]:
    vectors, _usage = embed_many(ollama_url, model, [text])
    return vectors[0]


OPENROUTER_GEMINI_EMBEDDING_2_USD_PER_M_TOKENS = 0.20


def embed_many(ollama_url: str, model: str, texts: list[str]) -> tuple[list[list[float]], dict]:
    body = json.dumps({"model": model, "input": texts}).encode()
    req = urllib.request.Request(
        ollama_url.rstrip("/") + "/api/embed",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=120) as response:
        data = json.loads(response.read())
    vectors = data.get("embeddings") or []
    if len(vectors) != len(texts):
        raise RuntimeError(f"empty embedding response from {ollama_url}")
    return [[float(x) for x in vector] for vector in vectors], {}


def hosted_prepare_document(text: str, title: str) -> str:
    safe_title = title.strip() or "none"
    return f"title: {safe_title} | text: {text}"


def hosted_prepare_query(text: str) -> str:
    return f"task: search result | query: {text}"


def embed_many_openrouter(api_key: str, model: str, texts: list[str], dimension: int) -> tuple[list[list[float]], dict]:
    body_dict = {"model": model, "input": texts}
    if dimension:
        body_dict["dimensions"] = dimension
    body = json.dumps(body_dict).encode()
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/embeddings",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "HTTP-Referer": "https://github.com/motoko-agent/motoko_agent",
            "X-Title": "motoko-agent project memory embedding PoC",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            data = json.loads(response.read())
    except HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise RuntimeError(f"OpenRouter embedding request failed: HTTP {exc.code}: {detail}") from exc
    vectors = []
    for item in data.get("data", []):
        vectors.append([float(x) for x in item["embedding"]])
    if len(vectors) != len(texts):
        raise RuntimeError(f"OpenRouter returned {len(vectors)} embeddings for {len(texts)} inputs")
    return vectors, data.get("usage") or {}


def embed_many_backend(
    backend: str,
    ollama_url: str,
    api_key: str,
    model: str,
    texts: list[str],
    dimension: int,
) -> tuple[list[list[float]], dict]:
    if backend == "openrouter":
        if not api_key:
            raise RuntimeError("OpenRouter backend requires OPENROUTER_API_KEY or --api-key-env")
        return embed_many_openrouter(api_key, model, texts, dimension)
    return embed_many(ollama_url, model, texts)


def add_usage(total: dict, usage: dict) -> None:
    for key, value in usage.items():
        if isinstance(value, (int, float)):
            total[key] = total.get(key, 0) + value


def estimated_tokens(texts: list[str]) -> int:
    return max(1, math.ceil(sum(len(text) for text in texts) / 4))


def cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def main() -> int:
    started = time.perf_counter()
    parser = argparse.ArgumentParser(description="PoC semantic search over .agent Markdown sections via Ollama.")
    parser.add_argument("query")
    parser.add_argument("--backend", choices=["ollama", "openrouter"], default=os.environ.get("EMBED_BACKEND", "ollama"))
    parser.add_argument("--ollama-url", default=os.environ.get("OLLAMA_URL", "http://host.docker.internal:11435"))
    parser.add_argument("--model", default=None)
    parser.add_argument("--api-key-env", default="OPENROUTER_API_KEY")
    parser.add_argument("--dimension", type=int, default=768,
                        help="hosted embedding output dimension; ignored for Ollama")
    parser.add_argument("--glob", default=".agent/projects/002_code_graph/*.md")
    parser.add_argument("--cache", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=8)
    parser.add_argument("--max-chars", type=int, default=6000)
    parser.add_argument("--min-section-chars", type=int, default=200)
    parser.add_argument("--legacy-chunks", action="store_true",
                        help="disable context prefixes and tiny-section merging")
    parser.add_argument("--no-lexical-boost", action="store_true")
    parser.add_argument("--batch-size", type=int, default=64)
    args = parser.parse_args()
    if args.model is None:
        args.model = "google/gemini-embedding-2" if args.backend == "openrouter" else os.environ.get("OLLAMA_MODEL", "embeddinggemma")
    dimension = args.dimension if args.backend == "openrouter" else 0
    if args.cache is None:
        args.cache = default_cache_path(args.backend, args.model, dimension)
    hosted_api_key = os.environ.get(args.api_key_env, "")

    paths = sorted(Path(p) for p in glob.glob(str(REPO_ROOT / args.glob), recursive=True))
    min_chars = 0 if args.legacy_chunks else args.min_section_chars
    context_prefix = not args.legacy_chunks
    sections = [
        section
        for path in paths
        for section in split_markdown(path, args.max_chars, min_chars, context_prefix)
    ]
    cache = load_cache(args.cache, args.backend, args.model, dimension)
    embedded_by_id: dict[str, list[float]] = {}
    missing: list[tuple[Section, str]] = []
    misses = 0
    embedding_requests = 0
    embedded_chars = 0
    estimated_input_tokens = 0
    api_usage: dict = {}
    for section in sections:
        cache_key = hashlib.sha256(f"{args.backend}\0{args.model}\0{dimension}\0document\0{section.sha256}".encode()).hexdigest()
        vector = cache.get(cache_key)
        if vector is None:
            missing.append((section, cache_key))
        else:
            embedded_by_id[section.item_id] = vector
    batch_size = max(1, args.batch_size)
    for idx in range(0, len(missing), batch_size):
        batch = missing[idx:idx + batch_size]
        batch_texts = [
            hosted_prepare_document(section.embed_text, section.heading) if args.backend == "openrouter" else section.embed_text
            for section, _key in batch
        ]
        vectors, usage = embed_many_backend(
            args.backend,
            args.ollama_url,
            hosted_api_key,
            args.model,
            batch_texts,
            dimension,
        )
        embedding_requests += 1
        embedded_chars += sum(len(text) for text in batch_texts)
        estimated_input_tokens += estimated_tokens(batch_texts)
        add_usage(api_usage, usage)
        for (section, cache_key), vector in zip(batch, vectors):
            append_cache(args.cache, args.backend, args.model, dimension, cache_key, vector)
            cache[cache_key] = vector
            embedded_by_id[section.item_id] = vector
            misses += 1
    embedded = [(section, embedded_by_id[section.item_id]) for section in sections]

    query_text = hosted_prepare_query(args.query) if args.backend == "openrouter" else args.query
    query_vectors, query_usage = embed_many_backend(
        args.backend,
        args.ollama_url,
        hosted_api_key,
        args.model,
        [query_text],
        dimension,
    )
    query_vector = query_vectors[0]
    embedding_requests += 1
    embedded_chars += len(query_text)
    estimated_input_tokens += estimated_tokens([query_text])
    add_usage(api_usage, query_usage)
    scored = sorted(
        (
            (
                cosine(query_vector, vector)
                + (0.0 if args.no_lexical_boost else lexical_boost(args.query, section)),
                section,
            )
            for section, vector in embedded
        ),
        key=lambda item: item[0],
        reverse=True,
    )
    elapsed_seconds = time.perf_counter() - started
    usage_tokens = int(api_usage.get("total_tokens") or api_usage.get("prompt_tokens") or 0)
    billable_token_estimate = usage_tokens or estimated_input_tokens
    estimated_cost_usd = None
    if args.backend == "openrouter" and args.model == "google/gemini-embedding-2":
        estimated_cost_usd = billable_token_estimate * OPENROUTER_GEMINI_EMBEDDING_2_USD_PER_M_TOKENS / 1_000_000
    print(json.dumps({
        "query": args.query,
        "backend": args.backend,
        "model": args.model,
        "dimension": dimension or len(query_vector),
        "cache": str(args.cache),
        "sections": len(sections),
        "cache_misses": misses,
        "embedding_requests": embedding_requests,
        "elapsed_seconds": round(elapsed_seconds, 3),
        "embedded_chars": embedded_chars,
        "estimated_input_tokens": estimated_input_tokens,
        "api_usage": api_usage,
        "billable_token_estimate": billable_token_estimate,
        "estimated_cost_usd": None if estimated_cost_usd is None else round(estimated_cost_usd, 6),
        "batch_size": batch_size,
        "min_section_chars": min_chars,
        "context_prefix": context_prefix,
        "lexical_boost": not args.no_lexical_boost,
        "results": [{
            "score": round(score, 4),
            "path": section.path,
            "heading": section.heading,
            "start_line": section.start_line,
            "end_line": section.end_line,
        } for score, section in scored[:max(0, args.limit)]],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
