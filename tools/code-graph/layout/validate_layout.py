#!/usr/bin/env python3
"""Validator for the generated ``layout`` / ``edges_agg`` tables (010, task 1.3).

Five named rules, each reported as an enumerated finding (ADR-002 oracle style —
never a bare boolean):

    rollup-sum       D3's invariant: weight(n, A->B) == sum of children at n+1,
                     exact integer equality per kind per level pair.
    containment      every child circle lies inside its parent's circle.
    sibling-overlap  no two siblings overlap.
    coverage         every module has exactly one L2 row; every edges_agg
                     endpoint exists in layout at its level; every module's
                     L0/L1 prefix-class aggregates exist as layout rows.
    determinism      rebuilding from a copy of the same inputs in a temp dir
                     produces byte-identical CSVs.

Used two ways:

* imported by ``build_layout.build`` and run **before** anything is written, so
  no artifact that fails a rule ever lands in the store;
* as a standalone CLI over an existing ``.out/`` for whatever workflow later
  adopts it (there is no code-graph CI today — plan Gap 1).

The determinism rule is the *sameness* direction only. Its two-sided partner is
``stability_probe.py`` (task 1.4), which asserts a mutated tree *moves*.
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
import tempfile
from dataclasses import dataclass
from math import sqrt
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_layout as bl  # noqa: E402

# Coordinates are quantized to 9 decimals against a unit root circle, so the
# largest representation error a comparison can inherit is well under 1e-8.
EPS = 1e-8

MAX_DETAIL_PER_RULE = 20


@dataclass(frozen=True)
class Finding:
    rule: str
    detail: str

    def as_dict(self) -> dict:
        return {"rule": self.rule, "detail": self.detail}


class ValidationFailed(Exception):
    def __init__(self, findings: list[Finding]) -> None:
        self.findings = findings
        super().__init__(f"{len(findings)} layout validation finding(s)")


class _Collector:
    def __init__(self) -> None:
        self.findings: list[Finding] = []
        self._counts: dict[str, int] = {}

    def add(self, rule: str, detail: str) -> None:
        n = self._counts.get(rule, 0) + 1
        self._counts[rule] = n
        if n <= MAX_DETAIL_PER_RULE:
            self.findings.append(Finding(rule, detail))
        elif n == MAX_DETAIL_PER_RULE + 1:
            self.findings.append(Finding(rule, f"... further {rule} findings suppressed"))

    def totals(self) -> dict[str, int]:
        return dict(self._counts)


def _parent_of(node_id: str) -> str | None:
    if "/" not in node_id:
        return None
    return node_id.rsplit("/", 1)[0]


def _geometry(layout_rows: list[dict], out: _Collector) -> dict[str, tuple[float, float, float]]:
    """node_id -> (x, y, radius). A node_id that appears at several levels is
    the same circle by construction; disagreement is itself a containment-class
    defect and is reported rather than silently resolved."""
    geo: dict[str, tuple[float, float, float]] = {}
    for row in layout_rows:
        node = row["node_id"]
        val = (float(row["x"]), float(row["y"]), float(row["radius"]))
        prev = geo.get(node)
        if prev is None:
            geo[node] = val
        elif prev != val:
            out.add("containment", f"node {node} has inconsistent geometry across levels: {prev} vs {val}")
    return geo


def _check_rollup(edge_rows: list[dict], out: _Collector) -> None:
    by_level: dict[tuple[str, int], dict[tuple[str, str], int]] = {}
    for row in edge_rows:
        key = (row["kind"], int(row["level"]))
        by_level.setdefault(key, {})[(row["src_agg"], row["dst_agg"])] = int(row["weight"])
    kinds = sorted({row["kind"] for row in edge_rows})
    for kind in kinds:
        for level in (0, 1):
            parent = by_level.get((kind, level), {})
            child = by_level.get((kind, level + 1), {})
            rolled: dict[tuple[str, str], int] = {}
            for (src, dst), weight in child.items():
                key = (bl.agg_at(src, level), bl.agg_at(dst, level))
                rolled[key] = rolled.get(key, 0) + weight
            for key in sorted(set(parent) | set(rolled)):
                have = parent.get(key, 0)
                want = rolled.get(key, 0)
                if have != want:
                    out.add(
                        "rollup-sum",
                        f"{kind} L{level} {key[0]} -> {key[1]}: stored weight {have}, "
                        f"sum of L{level + 1} children {want}",
                    )


def _check_geometry(geo: dict[str, tuple[float, float, float]], out: _Collector) -> None:
    children: dict[str, list[str]] = {}
    for node in geo:
        parent = _parent_of(node)
        if parent is None or parent not in geo:
            continue
        px, py, pr = geo[parent]
        cx, cy, cr = geo[node]
        dist = sqrt((cx - px) ** 2 + (cy - py) ** 2)
        if dist + cr > pr + EPS:
            out.add(
                "containment",
                f"{node} escapes {parent}: dist {dist:.9f} + r {cr:.9f} > parent r {pr:.9f}",
            )
        children.setdefault(parent, []).append(node)

    for parent in sorted(children):
        sibs = sorted(children[parent])
        for i in range(len(sibs)):
            ax, ay, ar = geo[sibs[i]]
            for j in range(i + 1, len(sibs)):
                bx, by, br = geo[sibs[j]]
                dist = sqrt((bx - ax) ** 2 + (by - ay) ** 2)
                if dist + EPS < ar + br:
                    out.add(
                        "sibling-overlap",
                        f"{sibs[i]} overlaps {sibs[j]} under {parent}: "
                        f"dist {dist:.9f} < r1+r2 {ar + br:.9f}",
                    )


def _check_coverage(
    layout_rows: list[dict],
    edge_rows: list[dict],
    modules: list[dict],
    out: _Collector,
) -> None:
    by_level: dict[int, set[str]] = {}
    l2_counts: dict[str, int] = {}
    for row in layout_rows:
        level = int(row["level"])
        by_level.setdefault(level, set()).add(row["node_id"])
        if level == 2:
            l2_counts[row["node_id"]] = l2_counts.get(row["node_id"], 0) + 1

    slugs = [row["slug"] for row in modules]
    for slug in sorted(slugs):
        n = l2_counts.get(slug, 0)
        if n != 1:
            out.add("coverage", f"module {slug} has {n} L2 layout rows (expected exactly 1)")
        for level in (0, 1):
            agg = bl.agg_at(slug, level)
            if agg not in by_level.get(level, set()):
                out.add("coverage", f"module {slug}: L{level} aggregate {agg} has no layout row at level {level}")

    for row in edge_rows:
        level = int(row["level"])
        for side in ("src_agg", "dst_agg"):
            node = row[side]
            if node not in by_level.get(level, set()):
                out.add("coverage", f"edges_agg L{level} {row['kind']} {side}={node} has no layout row at that level")


def _check_determinism(out_dir: Path, layout_rows: list[dict], edge_rows: list[dict], out: _Collector) -> None:
    inputs = ("modules.csv", "extraction_status.csv", "imports.csv", "invokes.csv")
    with tempfile.TemporaryDirectory(prefix="cg-layout-det-") as tmp:
        tmp_dir = Path(tmp)
        src_dir = tmp_dir / "in"
        src_dir.mkdir()
        for name in inputs:
            shutil.copy2(out_dir / name, src_dir / name)
        try:
            rebuilt_layout, rebuilt_edges, _ = bl.build_rows(src_dir)
        except SystemExit as exc:
            out.add("determinism", f"rebuild failed: {exc}")
            return
        for name, fields, first, second in (
            ("layout.csv", bl.LAYOUT_FIELDS, layout_rows, rebuilt_layout),
            ("edges_agg.csv", bl.EDGES_FIELDS, edge_rows, rebuilt_edges),
        ):
            a = tmp_dir / f"a-{name}"
            b = tmp_dir / f"b-{name}"
            bl.write_csv(a, fields, first)
            bl.write_csv(b, fields, second)
            ab, bb = a.read_bytes(), b.read_bytes()
            if ab != bb:
                first_diff = next(
                    (i for i, (x, y) in enumerate(zip(ab, bb)) if x != y),
                    min(len(ab), len(bb)),
                )
                out.add("determinism", f"{name} differs on rebuild at byte {first_diff}")


def validate_rows(
    layout_rows: list[dict],
    edge_rows: list[dict],
    out_dir: Path,
    check_determinism: bool = True,
) -> list[Finding]:
    out = _Collector()
    modules = bl.read_csv(out_dir / "modules.csv")
    geo = _geometry(layout_rows, out)
    _check_rollup(edge_rows, out)
    _check_geometry(geo, out)
    _check_coverage(layout_rows, edge_rows, modules, out)
    if check_determinism:
        _check_determinism(out_dir, layout_rows, edge_rows, out)
    return out.findings


def validate_store(out_dir: Path, check_determinism: bool = True) -> list[Finding]:
    layout_path = out_dir / "layout.csv"
    edges_path = out_dir / "edges_agg.csv"
    missing = [p.name for p in (layout_path, edges_path) if not p.exists()]
    if missing:
        return [Finding("coverage", f"missing generated table(s): {', '.join(missing)} — run build_layout.py")]
    with layout_path.open(newline="", encoding="utf-8") as fh:
        layout_rows = list(csv.DictReader(fh))
    with edges_path.open(newline="", encoding="utf-8") as fh:
        edge_rows = list(csv.DictReader(fh))
    return validate_rows(layout_rows, edge_rows, out_dir, check_determinism=check_determinism)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=bl.DEFAULT_OUT, help="store directory (default: tools/code-graph/.out)")
    ap.add_argument("--skip-determinism", action="store_true", help="skip the rebuild/byte-compare rule")
    ns = ap.parse_args(argv)
    findings = validate_store(ns.out, check_determinism=not ns.skip_determinism)
    print(json.dumps({"findings": [f.as_dict() for f in findings], "ok": not findings}, indent=2, sort_keys=True))
    if findings:
        for finding in findings:
            print(f"  [{finding.rule}] {finding.detail}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
