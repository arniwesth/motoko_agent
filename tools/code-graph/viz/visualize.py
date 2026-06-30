#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
OUT_DIR = TOOL_ROOT / ".out"


def render_svg(mmd_path: Path) -> None:
    svg_path = mmd_path.with_suffix(".svg")
    mmd2svg = REPO_ROOT / "tools" / "mmd2svg" / "mmd2svg.ts"
    result = subprocess.run(["bun", str(mmd2svg), str(mmd_path), str(svg_path)],
                            capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ERROR rendering {mmd_path.name}: {result.stderr}", file=sys.stderr)
    else:
        print(f"rendered: {svg_path}")


def rows(name: str) -> list[dict]:
    path = OUT_DIR / f"{name}.csv"
    if not path.exists():
        return []
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def node_id(slug: str) -> str:
    return "n_" + "".join(ch if ch.isalnum() else "_" for ch in slug)


def module_deps(scope: str = "", coarsen_dir: str = "src/core/ext") -> Path:
    modules = {r["slug"]: r for r in rows("modules")}
    edges = rows("imports")
    def label(mod: str) -> str:
        return coarsen_dir if coarsen_dir and mod.startswith(coarsen_dir + "/") else mod
    nodes = set()
    out_edges = set()
    for e in edges:
        if scope and not (e["from_module"].startswith(scope) or e["to_module"].startswith(scope)):
            continue
        a, b = label(e["from_module"]), label(e["to_module"])
        nodes.update([a, b])
        if a != b:
            out_edges.add((a, b))
    lines = ["graph LR"]
    for n in sorted(nodes):
        lines.append(f'  {node_id(n)}["{n}"]')
    for a, b in sorted(out_edges):
        lines.append(f"  {node_id(a)} --> {node_id(b)}")
    path = OUT_DIR / "module_deps.mmd"
    path.write_text("\n".join(lines) + "\n")
    return path


def core_extensions() -> Path:
    modules = {
        r["slug"]: r for r in rows("modules")
        if r["slug"].startswith("src/core/")
    }
    edges = set()
    for edge in rows("imports"):
        a, b = edge["from_module"], edge["to_module"]
        if a in modules and b in modules:
            edges.add((a, b))

    def label(slug: str) -> str:
        if slug.startswith("src/core/ext/"):
            return "ext/" + slug.removeprefix("src/core/ext/")
        if slug.startswith("src/core/test/"):
            return "test/" + slug.removeprefix("src/core/test/")
        return slug.removeprefix("src/core/")

    lines = [
        "graph LR",
        "  classDef ext fill:#fff4cc,stroke:#b58900,color:#111;",
        "  classDef core fill:#eef7ff,stroke:#2474a6,color:#111;",
        "  classDef test fill:#f2f2f2,stroke:#777,color:#111;",
        "",
    ]
    for slug in sorted(modules):
        klass = "ext" if slug.startswith("src/core/ext/") else "test" if slug.startswith("src/core/test/") else "core"
        lines.append(f'  {node_id(slug)}["{label(slug)}"]:::{klass}')
    lines.append("")
    for a, b in sorted(edges):
        lines.append(f"  {node_id(a)} --> {node_id(b)}")
    path = OUT_DIR / "core_modules_extensions.mmd"
    path.write_text("\n".join(lines) + "\n")
    return path


def calls(scope: str = "") -> Path:
    edges = rows("invokes")
    nodes = set()
    out_edges = set()
    for e in edges:
        if scope and not (e["from_slug"].startswith(scope) or e["to_slug"].startswith(scope)):
            continue
        nodes.update([e["from_slug"], e["to_slug"]])
        out_edges.add((e["from_slug"], e["to_slug"]))
    lines = ["graph LR"]
    for n in sorted(nodes)[:250]:
        lines.append(f'  {node_id(n)}["{n}"]')
    for a, b in sorted(out_edges)[:400]:
        lines.append(f"  {node_id(a)} --> {node_id(b)}")
    path = OUT_DIR / "calls.mmd"
    path.write_text("\n".join(lines) + "\n")
    return path


def effects(effect: str = "Net") -> Path:
    edges = [r for r in rows("effect_edges") if r.get("effect") == effect]
    nodes = set()
    out_edges = set()
    for e in edges:
        src = e["source_func_slug"]
        dst = e["func_slug"]
        nodes.update([src, dst])
        if src != dst:
            out_edges.add((src, dst))
    lines = ["graph LR"]
    for n in sorted(nodes)[:250]:
        lines.append(f'  {node_id(n)}["{n}"]')
    for a, b in sorted(out_edges)[:400]:
        lines.append(f"  {node_id(a)} --> {node_id(b)}")
    path = OUT_DIR / f"effect_{effect}.mmd"
    path.write_text("\n".join(lines) + "\n")
    return path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--module-deps", action="store_true")
    ap.add_argument("--core-extensions", action="store_true")
    ap.add_argument("--calls", action="store_true")
    ap.add_argument("--effect", default="")
    ap.add_argument("--scope", default="")
    ap.add_argument("--no-render", action="store_true")
    ns = ap.parse_args()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    paths = []
    if ns.module_deps or (not ns.calls and not ns.effect and not ns.core_extensions):
        paths.append(module_deps(ns.scope))
    if ns.core_extensions:
        paths.append(core_extensions())
    if ns.calls:
        paths.append(calls(ns.scope))
    if ns.effect:
        paths.append(effects(ns.effect))
    if not ns.no_render:
        for p in paths:
            render_svg(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
