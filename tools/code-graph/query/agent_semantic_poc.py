#!/usr/bin/env python3
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import math
import os
import re
import urllib.request
from dataclasses import dataclass
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
DEFAULT_CACHE = TOOL_ROOT / ".out" / "agent_section_embeddings_embeddinggemma.jsonl"
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")


@dataclass
class Section:
    item_id: str
    path: str
    heading: str
    level: int
    start_line: int
    end_line: int
    text: str
    sha256: str


def repo_rel(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()


def split_markdown(path: Path, max_chars: int) -> list[Section]:
    rel = repo_rel(path)
    lines = path.read_text(errors="replace").splitlines()
    starts: list[tuple[int, int, str]] = []
    for idx, line in enumerate(lines, start=1):
        match = HEADING_RE.match(line)
        if match:
            starts.append((idx, len(match.group(1)), match.group(2).strip()))
    if not starts:
        starts = [(1, 1, path.stem)]
    sections: list[Section] = []
    for pos, (start, level, heading) in enumerate(starts):
        end = (starts[pos + 1][0] - 1) if pos + 1 < len(starts) else len(lines)
        text = "\n".join(lines[start - 1:end]).strip()
        if len(text) > max_chars:
            text = text[:max_chars]
        digest = hashlib.sha256(text.encode()).hexdigest()
        slug = re.sub(r"[^A-Za-z0-9]+", "-", heading).strip("-").lower() or "section"
        item_id = f"{rel}:{start}:{slug}"
        sections.append(Section(item_id, rel, heading, level, start, end, text, digest))
    return sections


def load_cache(path: Path, model: str) -> dict[str, list[float]]:
    cache: dict[str, list[float]] = {}
    if not path.exists():
        return cache
    for line in path.read_text(errors="replace").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if row.get("model") == model:
            cache[row["cache_key"]] = row["embedding"]
    return cache


def append_cache(path: Path, model: str, cache_key: str, embedding: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as f:
        f.write(json.dumps({"model": model, "cache_key": cache_key, "embedding": embedding}) + "\n")


def embed(ollama_url: str, model: str, text: str) -> list[float]:
    body = json.dumps({"model": model, "input": text}).encode()
    req = urllib.request.Request(
        ollama_url.rstrip("/") + "/api/embed",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=120) as response:
        data = json.loads(response.read())
    vectors = data.get("embeddings") or []
    if not vectors:
        raise RuntimeError(f"empty embedding response from {ollama_url}")
    return [float(x) for x in vectors[0]]


def cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def main() -> int:
    parser = argparse.ArgumentParser(description="PoC semantic search over .agent Markdown sections via Ollama.")
    parser.add_argument("query")
    parser.add_argument("--ollama-url", default=os.environ.get("OLLAMA_URL", "http://host.docker.internal:11435"))
    parser.add_argument("--model", default=os.environ.get("OLLAMA_MODEL", "embeddinggemma"))
    parser.add_argument("--glob", default=".agent/projects/002_code_graph/*.md")
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--limit", type=int, default=8)
    parser.add_argument("--max-chars", type=int, default=6000)
    args = parser.parse_args()

    paths = sorted(Path(p) for p in glob.glob(str(REPO_ROOT / args.glob), recursive=True))
    sections = [section for path in paths for section in split_markdown(path, args.max_chars)]
    cache = load_cache(args.cache, args.model)
    embedded: list[tuple[Section, list[float]]] = []
    misses = 0
    for section in sections:
        cache_key = hashlib.sha256(f"{args.model}\0{section.sha256}".encode()).hexdigest()
        vector = cache.get(cache_key)
        if vector is None:
            vector = embed(args.ollama_url, args.model, section.text)
            append_cache(args.cache, args.model, cache_key, vector)
            cache[cache_key] = vector
            misses += 1
        embedded.append((section, vector))

    query_vector = embed(args.ollama_url, args.model, args.query)
    scored = sorted(
        ((cosine(query_vector, vector), section) for section, vector in embedded),
        key=lambda item: item[0],
        reverse=True,
    )
    print(json.dumps({
        "query": args.query,
        "model": args.model,
        "sections": len(sections),
        "cache_misses": misses,
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
