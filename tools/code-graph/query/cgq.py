#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import chdb

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
OUT_DIR = TOOL_ROOT / ".out"
GRAPH_SCHEMA = 1
SOURCE_SCHEMA = 1
SCHEMAS = {
    "modules": "slug String, path String, module_decl String, decl_matches_path Int64, n_funcs Int64, is_generated Int64, is_root Int64, root_reason String",
    "funcs": "slug String, module String, name String, exported Int64, is_internal Int64, has_typed_sig Int64, type_sig String, declared_effects String, pure String, module_iface_status String",
    "types": "slug String, module String, name String, kind String, n_ctors Int64",
    "ctors": "slug String, module String, name String, type_slug String, source String",
    "imports": "from_module String, to_module String, alias String, symbols String",
    "invokes": "from_slug String, to_slug String, resolution String, approximate Int64",
    "std_calls": "from_slug String, std_module String, symbol String, resolution String",
    "uses": "from_slug String, type_slug String, resolved Int64",
    "effects": "func_slug String, effect String",
    "effect_edges": "func_slug String, effect String, source_func_slug String, distance Int64, derivation String",
    "source_files": "path String, module String, lang String, bytes Int64, sha256 String, n_lines Int64, profile String, include_tests UInt8",
    "source_lines": "path String, module String, lang String, line_no Int64, line String, is_comment UInt8, profile String, include_tests UInt8",
    "source_chunks": "chunk_slug String, func_slug String, path String, module String, lang String, kind String, name String, start_line Int64, end_line Int64, text String, profile String, include_tests UInt8",
    "extraction_status": "module String, iface_status String, iface_detail String, iface_error String, built_at String, ailang_version String, graph_schema Int64, source_schema Int64, iface_schema String, profile String, include_tests Int64",
}
_TOKEN_SUPPORT: bool | None = None


@dataclass(frozen=True)
class QueryFlags:
    effect_query: bool = False
    source_query: bool = False
    search_mode: str | None = None


def csv_tables() -> list[str]:
    return sorted(p.stem for p in OUT_DIR.glob("*.csv"))


def view_preamble() -> str:
    parts = []
    for table in csv_tables():
        path = (OUT_DIR / f"{table}.csv").resolve()
        schema = SCHEMAS.get(table)
        if schema:
            parts.append(f"CREATE VIEW {table} AS SELECT * FROM file('{path}','CSVWithNames','{schema}');")
        else:
            parts.append(f"CREATE VIEW {table} AS SELECT * FROM file('{path}','CSVWithNames');")
    return "\n".join(parts) + "\n"


def run_sql(sql: str) -> dict:
    out = chdb.query(view_preamble() + sql, "JSON")
    return json.loads(str(out))


def sql_lit(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def token_supported() -> bool:
    global _TOKEN_SUPPORT
    if _TOKEN_SUPPORT is not None:
        return _TOKEN_SUPPORT
    if os.environ.get("CGQ_FORCE_TOKEN_PROBE_FAIL"):
        _TOKEN_SUPPORT = False
        return _TOKEN_SUPPORT
    try:
        chdb.query("SELECT hasToken('a b', 'b')", "JSON")
        _TOKEN_SUPPORT = True
    except Exception:
        _TOKEN_SUPPORT = False
    return _TOKEN_SUPPORT


def search_predicate(column: str, term: str, mode: str) -> tuple[str, str]:
    literal = sql_lit(term)
    if mode == "token":
        if token_supported():
            return f"hasToken({column}, {literal})", "token"
        return f"positionCaseInsensitive({column}, {literal}) > 0", "substring_fallback"
    return f"positionCaseInsensitive({column}, {literal}) > 0", "substring"


def live_ailang_version() -> str:
    try:
        return subprocess.run(["ailang", "--version"], capture_output=True, text=True, check=False,
                              cwd=REPO_ROOT).stdout.strip()
    except FileNotFoundError:
        return "ailang not found"


def _source_freshness(meta: dict) -> tuple[bool, str | None]:
    if not (OUT_DIR / "source_files.csv").exists():
        return True, "missing source_files"
    if int(meta.get("source_schema") or 0) != SOURCE_SCHEMA:
        return True, "source_schema mismatch"
    try:
        rows = run_sql("SELECT path, sha256 FROM source_files ORDER BY path").get("data", [])
    except Exception as exc:
        return True, f"source_files unreadable: {exc}"
    for row in rows:
        source = REPO_ROOT / row["path"]
        if not source.exists():
            return True, f"indexed source missing: {row['path']}"
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != row.get("sha256"):
            return True, f"indexed source hash mismatch: {row['path']}"
    return False, None


def status_meta(flags: QueryFlags | None = None) -> dict:
    flags = flags or QueryFlags()
    meta = {
        "built_at": None,
        "ailang_version": None,
        "graph_schema": None,
        "source_schema": None,
        "profile": None,
        "include_tests": False,
        "stale": True,
        "stale_reason": "missing extraction_status",
        "source_profile": None,
        "source_stale": True,
        "source_stale_reason": "missing source_files",
        "approximate": True,
        "coverage": {"ok": 0, "failed": 0, "partial": 0, "total": 0},
        "row_counts": {},
        "source_row_counts": {},
        "storage_mode": "csv_scan",
        "search_mode": flags.search_mode,
        "incomplete": False,
        "incomplete_modules": [],
    }
    status_path = OUT_DIR / "extraction_status.csv"
    if not status_path.exists():
        return meta
    parsed = run_sql("SELECT * FROM extraction_status")
    rows = parsed.get("data", [])
    if not rows:
        return meta
    first = rows[0]
    meta["built_at"] = first.get("built_at")
    meta["ailang_version"] = first.get("ailang_version")
    meta["graph_schema"] = int(first.get("graph_schema") or 0)
    meta["source_schema"] = int(first.get("source_schema") or 0)
    meta["profile"] = first.get("profile") or "unknown"
    meta["source_profile"] = meta["profile"]
    meta["include_tests"] = bool(int(first.get("include_tests") or 0))
    counts = {"ok": 0, "failed": 0, "partial": 0, "total": len(rows)}
    incomplete = []
    for row in rows:
        st = row.get("iface_status", "")
        if st in counts:
            counts[st] += 1
        if st in {"failed", "partial"}:
            incomplete.append(row.get("module"))
    meta["coverage"] = counts
    for table in csv_tables():
        if table == "extraction_status":
            meta["row_counts"][table] = len(rows)
            continue
        try:
            meta["row_counts"][table] = int(run_sql(f"SELECT count() AS n FROM {table}")["data"][0]["n"])
        except Exception:
            pass
    for table in ("source_files", "source_lines", "source_chunks"):
        if table in meta["row_counts"]:
            meta["source_row_counts"][table] = meta["row_counts"][table]
    newest = 0.0
    for path in run_sql("SELECT path FROM modules").get("data", []):
        source = REPO_ROOT / path["path"]
        if source.exists():
            newest = max(newest, source.stat().st_mtime)
    stale_reason = None
    try:
        built_ts = __import__("datetime").datetime.fromisoformat(meta["built_at"]).timestamp()
        if newest > built_ts:
            stale_reason = "newer .ail mtime"
    except Exception:
        stale_reason = "invalid built_at"
    if meta["ailang_version"] != live_ailang_version():
        stale_reason = "ailang_version drift"
    if meta["graph_schema"] != GRAPH_SCHEMA:
        stale_reason = "graph_schema mismatch"
    meta["stale"] = stale_reason is not None
    meta["stale_reason"] = stale_reason
    source_stale, source_reason = _source_freshness(meta)
    meta["source_stale"] = source_stale
    meta["source_stale_reason"] = source_reason
    if flags.effect_query and (incomplete or meta["stale"]):
        meta["incomplete"] = True
        meta["incomplete_modules"] = incomplete
    return meta


def wrap(parsed: dict, limit: int, flags: QueryFlags | None = None) -> dict:
    flags = flags or QueryFlags()
    rows = parsed.get("data", [])
    total = len(rows)
    data = rows[:limit]
    meta = status_meta(flags)
    meta.update({"rows_returned": len(data), "rows_total": total, "truncated": total > len(data)})
    return {"data": data, "meta": meta}


def named_query(name: str, args: list[str]) -> tuple[str, QueryFlags]:
    if name == "module-deps":
        if args:
            mod = sql_lit(args[0])
            return f"SELECT * FROM imports WHERE from_module = {mod} OR to_module = {mod} ORDER BY from_module, to_module", QueryFlags()
        return "SELECT * FROM imports ORDER BY from_module, to_module", QueryFlags()
    if name == "importers":
        mod = sql_lit(args[0])
        return f"""
WITH RECURSIVE r(from_module, to_module, distance) AS (
  SELECT from_module, to_module, 1 FROM imports WHERE to_module = {mod}
  UNION ALL
  SELECT i.from_module, i.to_module, r.distance + 1 FROM imports i JOIN r ON i.to_module = r.from_module WHERE r.distance < 50
)
SELECT DISTINCT from_module AS importer FROM r ORDER BY importer
""", QueryFlags()
    if name == "callers":
        target = args[0]
        predicate = f"to_slug = {sql_lit(target)}" if "#" in target else f"to_slug LIKE {sql_lit('%#' + target)}"
        return f"""
WITH RECURSIVE r(from_slug, to_slug, distance) AS (
  SELECT from_slug, to_slug, 1 FROM invokes WHERE {predicate}
  UNION ALL
  SELECT i.from_slug, i.to_slug, r.distance + 1 FROM invokes i JOIN r ON i.to_slug = r.from_slug WHERE r.distance < 20
)
SELECT DISTINCT from_slug AS caller, min(distance) AS distance FROM r GROUP BY from_slug ORDER BY distance, caller
""", QueryFlags()
    if name == "reaches":
        eff = sql_lit(args[0])
        return f"SELECT DISTINCT func_slug, effect, min(distance) AS distance FROM effect_edges WHERE effect = {eff} GROUP BY func_slug, effect ORDER BY distance, func_slug", QueryFlags(effect_query=True)
    if name == "effects-of":
        func = args[0]
        predicate = f"func_slug = {sql_lit(func)}" if "#" in func else f"func_slug LIKE {sql_lit('%#' + func)}"
        return f"""
SELECT 'declared' AS kind, func_slug, effect, 0 AS distance FROM effects WHERE {predicate}
UNION ALL
SELECT 'reachable' AS kind, func_slug, effect, min(distance) AS distance FROM effect_edges WHERE {predicate} GROUP BY func_slug, effect
ORDER BY kind, effect
""", QueryFlags(effect_query=True)
    if name == "unimported":
        return """
WITH RECURSIVE reach(module, distance) AS (
  SELECT slug, 0 FROM modules WHERE is_root = 1
  UNION ALL
  SELECT i.to_module, r.distance + 1 FROM imports i JOIN reach r ON i.from_module = r.module WHERE r.distance < 50
)
SELECT slug AS module, 'unimported (not reachable via static imports from declared roots)' AS label
FROM modules WHERE slug NOT IN (SELECT DISTINCT module FROM reach) ORDER BY slug
""", QueryFlags()
    if name == "fan":
        mod = sql_lit(args[0])
        return f"""
SELECT m.slug AS module,
       (SELECT count() FROM imports WHERE to_module = m.slug) AS fan_in,
       (SELECT count() FROM imports WHERE from_module = m.slug) AS fan_out
FROM modules m WHERE m.slug = {mod}
""", QueryFlags()
    if name == "failures":
        return """
SELECT module, iface_status, iface_detail, iface_error
FROM extraction_status
WHERE iface_status IN ('partial', 'failed')
ORDER BY iface_status, module
""", QueryFlags()
    if name in {"search", "search-line"}:
        term = args[0]
        pred, mode = search_predicate("line", term, "substring")
        return f"""
SELECT path, line_no, lang, module, line
FROM source_lines
WHERE {pred}
ORDER BY path, line_no
""", QueryFlags(source_query=True, search_mode=mode)
    if name == "search-chunk":
        term = args[0]
        pred, mode = search_predicate("text", term, "substring")
        return f"""
SELECT chunk_slug, func_slug, path, module, lang, kind, name, start_line, end_line, left(text, 500) AS text_preview
FROM source_chunks
WHERE {pred}
ORDER BY path, start_line, chunk_slug
""", QueryFlags(source_query=True, search_mode=mode)
    if name == "search-effects":
        effect = sql_lit(args[0])
        term = args[1]
        pred, mode = search_predicate("c.text", term, "token")
        return f"""
SELECT c.func_slug AS func_slug, c.chunk_slug AS chunk_slug, f.name AS name, e.effect AS effect,
       c.path AS path, c.start_line AS start_line, c.end_line AS end_line, left(c.text, 500) AS text_preview
FROM source_chunks c
JOIN funcs f ON f.slug = c.func_slug
JOIN effect_edges e ON e.func_slug = c.func_slug
WHERE e.effect = {effect}
  AND {pred}
ORDER BY c.path, c.start_line
""", QueryFlags(effect_query=True, source_query=True, search_mode=mode)
    raise SystemExit(f"unknown named query: {name}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--format", choices=["json", "table"], default="json")
    ap.add_argument("--limit", type=int, default=200)
    ap.add_argument("--no-banner", action="store_true")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    sqlp = sub.add_parser("sql")
    sqlp.add_argument("sql")
    qp = sub.add_parser("q")
    qp.add_argument("name")
    qp.add_argument("args", nargs="*")
    ns = ap.parse_args()
    limit = max(0, min(ns.limit, 1000))
    if ns.cmd == "status":
        result = {"data": [], "meta": status_meta(QueryFlags())}
    elif ns.cmd == "sql":
        result = wrap(run_sql(ns.sql), limit, QueryFlags())
    else:
        sql, flags = named_query(ns.name, ns.args)
        result = wrap(run_sql(sql), limit, flags)
    if not ns.no_banner and result["meta"].get("stale"):
        print(f"STALE: {result['meta'].get('stale_reason')}", file=sys.stderr)
    if not ns.no_banner and result["meta"].get("source_stale") and result["meta"].get("search_mode"):
        print(f"STALE: source index {result['meta'].get('source_stale_reason')}", file=sys.stderr)
    if not ns.no_banner and result["meta"].get("incomplete"):
        print("INCOMPLETE: effect answer is unknown where typed coverage is failed/partial or stale", file=sys.stderr)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
