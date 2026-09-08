#!/usr/bin/env python3
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import math
import os
import time
from pathlib import Path

from agent_semantic_poc import (
    REPO_ROOT,
    TOOL_ROOT,
    Section,
    add_usage,
    append_cache,
    cosine,
    default_cache_path,
    embed_many_backend,
    estimated_tokens,
    hosted_prepare_document,
    hosted_prepare_query,
    lexical_boost,
    load_cache,
    split_markdown,
)

DEFAULT_QUERIES = Path(__file__).with_name("agent_semantic_benchmark_queries.json")


def cache_key(backend: str, model: str, dimension: int, kind: str, digest: str) -> str:
    return hashlib.sha256(f"{backend}\0{model}\0{dimension}\0{kind}\0{digest}".encode()).hexdigest()


def query_cache_key(backend: str, model: str, dimension: int, query: str) -> str:
    digest = hashlib.sha256(query.encode()).hexdigest()
    return cache_key(backend, model, dimension, "query", digest)


def section_cache_key(backend: str, model: str, dimension: int, section: Section) -> str:
    return cache_key(backend, model, dimension, "document", section.sha256)


def load_sections(glob_pattern: str, max_chars: int, min_chars: int, context_prefix: bool) -> list[Section]:
    paths = sorted(Path(p) for p in glob.glob(str(REPO_ROOT / glob_pattern), recursive=True))
    return [
        section
        for path in paths
        for section in split_markdown(path, max_chars, min_chars, context_prefix)
    ]


def ensure_document_embeddings(
    *,
    sections: list[Section],
    cache: dict[str, list[float]],
    cache_path: Path,
    backend: str,
    model: str,
    dimension: int,
    ollama_url: str,
    api_key: str,
    batch_size: int,
    populate_missing: bool,
) -> tuple[list[tuple[Section, list[float]]], int, int, int, dict]:
    missing: list[tuple[Section, str]] = []
    embedded_by_id: dict[str, list[float]] = {}
    for section in sections:
        key = section_cache_key(backend, model, dimension, section)
        vector = cache.get(key)
        if vector is None:
            missing.append((section, key))
        else:
            embedded_by_id[section.item_id] = vector
    if missing and not populate_missing:
        raise SystemExit(
            f"missing {len(missing)} document embeddings in {cache_path}; "
            "run agent_semantic_poc.py first or rerun benchmark with --populate-missing"
        )

    requests = 0
    chars = 0
    est_tokens = 0
    usage: dict = {}
    for idx in range(0, len(missing), batch_size):
        batch = missing[idx:idx + batch_size]
        texts = [
            hosted_prepare_document(section.embed_text, section.heading) if backend == "openrouter" else section.embed_text
            for section, _key in batch
        ]
        vectors, batch_usage = embed_many_backend(backend, ollama_url, api_key, model, texts, dimension)
        requests += 1
        chars += sum(len(text) for text in texts)
        est_tokens += estimated_tokens(texts)
        add_usage(usage, batch_usage)
        for (section, key), vector in zip(batch, vectors):
            append_cache(cache_path, backend, model, dimension, key, vector)
            cache[key] = vector
            embedded_by_id[section.item_id] = vector

    return [(section, embedded_by_id[section.item_id]) for section in sections], len(missing), requests, chars, usage | {"estimated_tokens": est_tokens}


def ensure_query_embedding(
    *,
    query: str,
    cache: dict[str, list[float]],
    cache_path: Path,
    backend: str,
    model: str,
    dimension: int,
    ollama_url: str,
    api_key: str,
) -> tuple[list[float], bool, int, int, dict]:
    prepared = hosted_prepare_query(query) if backend == "openrouter" else query
    key = query_cache_key(backend, model, dimension, prepared)
    cached = cache.get(key)
    if cached is not None:
        return cached, False, 0, 0, {}
    vectors, usage = embed_many_backend(backend, ollama_url, api_key, model, [prepared], dimension)
    append_cache(cache_path, backend, model, dimension, key, vectors[0])
    cache[key] = vectors[0]
    return vectors[0], True, len(prepared), estimated_tokens([prepared]), usage


def expected_match(result: dict, expected: dict) -> bool:
    if expected.get("path") and result["path"] != expected["path"]:
        return False
    needle = expected.get("heading_contains")
    if needle and needle.lower() not in result["heading"].lower():
        return False
    return True


def find_rank(results: list[dict], expected: list[dict]) -> int | None:
    for idx, result in enumerate(results, start=1):
        if any(expected_match(result, item) for item in expected):
            return idx
    return None


def main() -> int:
    started = time.perf_counter()
    parser = argparse.ArgumentParser(description="Evaluate semantic search over .agent docs against expected-hit queries.")
    parser.add_argument("--queries", type=Path, default=DEFAULT_QUERIES)
    parser.add_argument("--backend", choices=["ollama", "openrouter"], default=os.environ.get("EMBED_BACKEND", "ollama"))
    parser.add_argument("--model", default=None)
    parser.add_argument("--dimension", type=int, default=768)
    parser.add_argument("--cache", type=Path, default=None)
    parser.add_argument("--glob", default=".agent/**/*.md")
    parser.add_argument("--ollama-url", default=os.environ.get("OLLAMA_URL", "http://host.docker.internal:11435"))
    parser.add_argument("--api-key-env", default="OPENROUTER_API_KEY")
    parser.add_argument("--max-chars", type=int, default=6000)
    parser.add_argument("--min-section-chars", type=int, default=200)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--k", type=int, default=10)
    parser.add_argument("--populate-missing", action="store_true")
    parser.add_argument("--no-lexical-boost", action="store_true")
    args = parser.parse_args()

    model = args.model or ("google/gemini-embedding-2" if args.backend == "openrouter" else os.environ.get("OLLAMA_MODEL", "embeddinggemma"))
    dimension = args.dimension if args.backend == "openrouter" else 0
    cache_path = args.cache or default_cache_path(args.backend, model, dimension)
    api_key = os.environ.get(args.api_key_env, "")
    batch_size = max(1, args.batch_size)
    queries = json.loads(args.queries.read_text())
    sections = load_sections(args.glob, args.max_chars, args.min_section_chars, True)
    cache = load_cache(cache_path, args.backend, model, dimension)

    embedded, doc_misses, doc_requests, doc_chars, doc_usage = ensure_document_embeddings(
        sections=sections,
        cache=cache,
        cache_path=cache_path,
        backend=args.backend,
        model=model,
        dimension=dimension,
        ollama_url=args.ollama_url,
        api_key=api_key,
        batch_size=batch_size,
        populate_missing=args.populate_missing,
    )

    per_query = []
    query_requests = 0
    query_chars = 0
    query_est_tokens = 0
    api_usage: dict = {}
    add_usage(api_usage, {k: v for k, v in doc_usage.items() if k != "estimated_tokens"})
    for spec in queries:
        query_vector, query_miss, chars, est_tokens, usage = ensure_query_embedding(
            query=spec["query"],
            cache=cache,
            cache_path=cache_path,
            backend=args.backend,
            model=model,
            dimension=dimension,
            ollama_url=args.ollama_url,
            api_key=api_key,
        )
        query_requests += int(query_miss)
        query_chars += chars
        query_est_tokens += est_tokens
        add_usage(api_usage, usage)
        scored = sorted(
            (
                (
                    cosine(query_vector, vector)
                    + (0.0 if args.no_lexical_boost else lexical_boost(spec["query"], section)),
                    section,
                )
                for section, vector in embedded
            ),
            key=lambda item: item[0],
            reverse=True,
        )
        top = [{
            "score": round(score, 4),
            "path": section.path,
            "heading": section.heading,
            "start_line": section.start_line,
            "end_line": section.end_line,
        } for score, section in scored[:max(args.k, 1)]]
        rank = find_rank(top, spec["expected"])
        per_query.append({
            "id": spec["id"],
            "query": spec["query"],
            "rank": rank,
            "hit_at_k": rank is not None,
            "reciprocal_rank": 0.0 if rank is None else round(1 / rank, 4),
            "top": top[:3],
        })

    hits = sum(1 for row in per_query if row["hit_at_k"])
    mrr = sum(row["reciprocal_rank"] for row in per_query) / max(len(per_query), 1)
    usage_tokens = int(api_usage.get("total_tokens") or api_usage.get("prompt_tokens") or 0)
    estimated_tokens_total = int(doc_usage.get("estimated_tokens") or 0) + query_est_tokens
    billable_token_estimate = usage_tokens or estimated_tokens_total
    estimated_cost_usd = None
    if args.backend == "openrouter" and model == "google/gemini-embedding-2":
        estimated_cost_usd = billable_token_estimate * 0.20 / 1_000_000

    print(json.dumps({
        "backend": args.backend,
        "model": model,
        "dimension": dimension or (len(embedded[0][1]) if embedded else None),
        "cache": str(cache_path),
        "queries": len(queries),
        "sections": len(sections),
        "k": args.k,
        "hit_at_k": hits,
        "recall_at_k": round(hits / max(len(queries), 1), 4),
        "mrr_at_k": round(mrr, 4),
        "document_cache_misses": doc_misses,
        "query_cache_misses": query_requests,
        "embedding_requests": doc_requests + query_requests,
        "elapsed_seconds": round(time.perf_counter() - started, 3),
        "embedded_chars": doc_chars + query_chars,
        "estimated_input_tokens": estimated_tokens_total,
        "api_usage": api_usage,
        "billable_token_estimate": billable_token_estimate,
        "estimated_cost_usd": None if estimated_cost_usd is None else round(estimated_cost_usd, 6),
        "results": per_query,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
