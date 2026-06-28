#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
from pathlib import Path

from extractor import config
from extractor.effects import compute_effect_edges, oracle_report
from extractor.iface_pass import ailang_version, apply_iface
from extractor.roots import assemble_roots
from extractor.seed_catalog import write_catalog
from extractor.slugs import assert_unique
from extractor.source_parser import discover_files, parse_all

MODULE_FIELDS = ["slug", "path", "module_decl", "decl_matches_path", "n_funcs", "is_generated", "is_root", "root_reason"]
FUNC_FIELDS = ["slug", "module", "name", "exported", "is_internal", "has_typed_sig", "type_sig", "declared_effects", "pure", "module_iface_status"]
TYPE_FIELDS = ["slug", "module", "name", "kind", "n_ctors"]
CTOR_FIELDS = ["slug", "module", "name", "type_slug", "source"]
IMPORT_FIELDS = ["from_module", "to_module", "alias", "symbols"]
INVOKE_FIELDS = ["from_slug", "to_slug", "resolution", "approximate"]
STD_FIELDS = ["from_slug", "std_module", "symbol", "resolution"]
USES_FIELDS = ["from_slug", "type_slug", "resolved"]
EFFECT_FIELDS = ["func_slug", "effect"]
EFFECT_EDGE_FIELDS = ["func_slug", "effect", "source_func_slug", "distance", "derivation"]
STATUS_FIELDS = ["module", "iface_status", "iface_detail", "built_at", "ailang_version", "graph_schema", "iface_schema"]


def write_csv(path: Path, fields: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--structural-only", action="store_true")
    args = ap.parse_args()
    out = config.OUT_DIR
    out.mkdir(parents=True, exist_ok=True)
    files = discover_files(config.REPO_ROOT)
    parsed = parse_all(files, config.REPO_ROOT)
    roots = assemble_roots(files)

    modules = []
    funcs = []
    imports = []
    invokes = []
    std_calls = []
    ctors = []
    for p in parsed:
        modules.append({"slug": p.slug, "path": p.path, "module_decl": p.module_decl,
                        "decl_matches_path": p.decl_matches_path, "n_funcs": len(p.funcs),
                        "is_generated": int("registry_generated" in p.slug),
                        "is_root": int(p.slug in roots), "root_reason": roots.get(p.slug, "")})
        funcs.extend(p.funcs)
        imports.extend(p.imports)
        invokes.extend(p.invokes)
        std_calls.extend(p.std_calls)
        ctors.extend(p.ctors)

    typed_types: list[dict] = []
    typed_ctors: list[dict] = []
    uses: list[dict] = []
    declared: list[dict] = []
    status_rows = []
    version = ailang_version()
    built_at = datetime.now(timezone.utc).isoformat()
    if args.structural_only:
        for m in modules:
            status_rows.append({"module": m["slug"], "iface_status": "failed", "iface_detail": "structural_only"})
    else:
        funcs, typed_types, typed_ctors, uses, declared, status_rows = apply_iface(parsed)
        ctors.extend(typed_ctors)
    for row in status_rows:
        row.update({"built_at": built_at, "ailang_version": version, "graph_schema": config.GRAPH_SCHEMA,
                    "iface_schema": config.IFACE_SCHEMA})
    status_by_module = {r["module"]: r["iface_status"] for r in status_rows}
    for f in funcs:
        if not f.get("module_iface_status"):
            f["module_iface_status"] = status_by_module.get(f["module"], "")

    catalog = write_catalog(out / "seed_catalog.json")
    effect_edges = [] if args.structural_only else compute_effect_edges(std_calls, invokes, catalog)
    if not args.structural_only:
        oracle_report(funcs, declared, effect_edges, out / "oracle_report.json")

    assert_unique("modules", modules)
    assert_unique("funcs", funcs)
    assert_unique("types", typed_types)
    # Same ctor may be found by source and iface; uniqueness is per (slug, source) for this table in v1.
    seen_ctor_sources = set()
    for c in ctors:
        key = (c["slug"], c["source"])
        if key in seen_ctor_sources:
            continue
        seen_ctor_sources.add(key)
    write_csv(out / "modules.csv", MODULE_FIELDS, modules)
    write_csv(out / "funcs.csv", FUNC_FIELDS, funcs)
    write_csv(out / "types.csv", TYPE_FIELDS, typed_types)
    write_csv(out / "ctors.csv", CTOR_FIELDS, ctors)
    write_csv(out / "imports.csv", IMPORT_FIELDS, imports)
    write_csv(out / "invokes.csv", INVOKE_FIELDS, invokes)
    write_csv(out / "std_calls.csv", STD_FIELDS, std_calls)
    write_csv(out / "uses.csv", USES_FIELDS, uses)
    write_csv(out / "effects.csv", EFFECT_FIELDS, declared)
    write_csv(out / "effect_edges.csv", EFFECT_EDGE_FIELDS, effect_edges)
    write_csv(out / "extraction_status.csv", STATUS_FIELDS, status_rows)
    print(f"wrote {out}: {len(modules)} modules, {len(funcs)} funcs, {len(invokes)} invokes, {len(std_calls)} std calls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
