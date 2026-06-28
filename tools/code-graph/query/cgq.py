#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import chdb

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
OUT_DIR = TOOL_ROOT / ".out"
GRAPH_SCHEMA = 1
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
    "extraction_status": "module String, iface_status String, iface_detail String, iface_error String, built_at String, ailang_version String, graph_schema Int64, iface_schema String, profile String, include_tests Int64",
}


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


def live_ailang_version() -> str:
    try:
        return subprocess.run(["ailang", "--version"], capture_output=True, text=True, check=False,
                              cwd=REPO_ROOT).stdout.strip()
    except FileNotFoundError:
        return "ailang not found"


def status_meta(effect_query: bool = False) -> dict:
    meta = {
        "built_at": None,
        "ailang_version": None,
        "graph_schema": None,
        "profile": None,
        "include_tests": False,
        "stale": True,
        "stale_reason": "missing extraction_status",
        "approximate": True,
        "coverage": {"ok": 0, "failed": 0, "partial": 0, "total": 0},
        "row_counts": {},
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
    meta["profile"] = first.get("profile") or "unknown"
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
    newest = 0.0
    for path in run_sql("SELECT path FROM modules")["data"]:
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
    if effect_query and (incomplete or meta["stale"]):
        meta["incomplete"] = True
        meta["incomplete_modules"] = incomplete
    return meta


def wrap(parsed: dict, limit: int, effect_query: bool = False) -> dict:
    rows = parsed.get("data", [])
    total = len(rows)
    data = rows[:limit]
    meta = status_meta(effect_query)
    meta.update({"rows_returned": len(data), "rows_total": total, "truncated": total > len(data)})
    return {"data": data, "meta": meta}


def named_query(name: str, args: list[str]) -> tuple[str, bool]:
    if name == "module-deps":
        if args:
            mod = args[0]
            return f"SELECT * FROM imports WHERE from_module = '{mod}' OR to_module = '{mod}' ORDER BY from_module, to_module", False
        return "SELECT * FROM imports ORDER BY from_module, to_module", False
    if name == "importers":
        mod = args[0]
        return f"""
WITH RECURSIVE r(from_module, to_module, distance) AS (
  SELECT from_module, to_module, 1 FROM imports WHERE to_module = '{mod}'
  UNION ALL
  SELECT i.from_module, i.to_module, r.distance + 1 FROM imports i JOIN r ON i.to_module = r.from_module WHERE r.distance < 50
)
SELECT DISTINCT from_module AS importer FROM r ORDER BY importer
""", False
    if name == "callers":
        target = args[0]
        predicate = f"to_slug = '{target}'" if "#" in target else f"to_slug LIKE '%#{target}'"
        return f"""
WITH RECURSIVE r(from_slug, to_slug, distance) AS (
  SELECT from_slug, to_slug, 1 FROM invokes WHERE {predicate}
  UNION ALL
  SELECT i.from_slug, i.to_slug, r.distance + 1 FROM invokes i JOIN r ON i.to_slug = r.from_slug WHERE r.distance < 20
)
SELECT DISTINCT from_slug AS caller, min(distance) AS distance FROM r GROUP BY from_slug ORDER BY distance, caller
""", False
    if name == "reaches":
        eff = args[0]
        return f"SELECT DISTINCT func_slug, effect, min(distance) AS distance FROM effect_edges WHERE effect = '{eff}' GROUP BY func_slug, effect ORDER BY distance, func_slug", True
    if name == "effects-of":
        func = args[0]
        predicate = f"func_slug = '{func}'" if "#" in func else f"func_slug LIKE '%#{func}'"
        return f"""
SELECT 'declared' AS kind, func_slug, effect, 0 AS distance FROM effects WHERE {predicate}
UNION ALL
SELECT 'reachable' AS kind, func_slug, effect, min(distance) AS distance FROM effect_edges WHERE {predicate} GROUP BY func_slug, effect
ORDER BY kind, effect
""", True
    if name == "unimported":
        return """
WITH RECURSIVE reach(module, distance) AS (
  SELECT slug, 0 FROM modules WHERE is_root = 1
  UNION ALL
  SELECT i.to_module, r.distance + 1 FROM imports i JOIN reach r ON i.from_module = r.module WHERE r.distance < 50
)
SELECT slug AS module, 'unimported (not reachable via static imports from declared roots)' AS label
FROM modules WHERE slug NOT IN (SELECT DISTINCT module FROM reach) ORDER BY slug
""", False
    if name == "fan":
        mod = args[0]
        return f"""
SELECT m.slug AS module,
       (SELECT count() FROM imports WHERE to_module = m.slug) AS fan_in,
       (SELECT count() FROM imports WHERE from_module = m.slug) AS fan_out
FROM modules m WHERE m.slug = '{mod}'
""", False
    if name == "failures":
        return """
SELECT module, iface_status, iface_detail, iface_error
FROM extraction_status
WHERE iface_status IN ('partial', 'failed')
ORDER BY iface_status, module
""", False
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
        result = {"data": [], "meta": status_meta(False)}
    elif ns.cmd == "sql":
        result = wrap(run_sql(ns.sql), limit, False)
    else:
        sql, effect = named_query(ns.name, ns.args)
        result = wrap(run_sql(sql), limit, effect)
    if not ns.no_banner and result["meta"].get("stale"):
        print(f"STALE: {result['meta'].get('stale_reason')}", file=sys.stderr)
    if not ns.no_banner and result["meta"].get("incomplete"):
        print("INCOMPLETE: effect answer is unknown where typed coverage is failed/partial or stale", file=sys.stderr)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
