#!/usr/bin/env python3
"""Layout stability probe (010, task 1.4) — the movement half of the two-sided pair.

``validate_layout``'s determinism rule asserts *sameness*: same inputs, same
bytes. This probe asserts the other direction and puts a number on it: when the
tree changes, how far does everything *else* move?

**Metric (pinned by the plan).** For a snapshot pair (A, B), over nodes present
in both and **outside the expected-motion zone**, report
``d_i = ||pos_B(i) - pos_A(i)||`` in unit-root coordinates — max and mean, plus
the same for radius change.

**Expected-motion zone** (the operational definition the plan settled, because
"outside the changed subtree" alone does not say whether repacked siblings
count): the subtree rooted at the **immediate parent** of each added / removed /
re-areaed node — that container must repack, so sibling motion there is
legitimate — **plus the ancestor-chain nodes themselves**, whose radii
legitimately grow and shrink. Everything outside that zone is *ripple*, which is
what the threshold bounds.

Fixtures: synthetic mutations of the real all-profile tree, plus an optional
historical pair (``--historical-store``) built from an older commit's
extraction.

Also reports the Q4 degeneracy eyeball: if ``modules.n_funcs`` produces
pathological area variance, the recorded alternative is
``source_files.n_lines`` — a one-line change and a probe re-run, decided in the
NOTE and never silently.
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
import tempfile
from math import sqrt
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_layout as bl  # noqa: E402

INPUT_TABLES = ("modules.csv", "extraction_status.csv", "imports.csv", "invokes.csv")

# Calibrated 2026-08-08 against the all-profile tree at 225 modules; the
# measurements and the reasoning behind each number live in
# .agent/projects/010_simulation_visualization/NOTE-p1-stability-probe.md.
#
# The two insertion classes carry real *stability thresholds* — insertion is the
# common refresh and its ripple is small and reproducible. The deletion and
# re-area classes carry deliberately loose *regression ceilings*: circle packing
# does not bound them at a useful level, so the number catches "the whole map
# fell apart", not "the map is stable". The historical pair has no threshold at
# all — it depends on which commit you diff against, so it is a diagnostic.
THRESHOLDS = {
    "add-one-module-deep": {"kind": "threshold", "mean": 0.010, "max": 0.015},
    "add-ten-modules-one-package": {"kind": "threshold", "mean": 0.040, "max": 0.060},
    "delete-mid-size-dir": {"kind": "ceiling", "mean": 0.150, "max": 0.600},
    "grow-one-module-5x": {"kind": "ceiling", "mean": 0.200, "max": 0.300},
}


# --------------------------------------------------------------------------
# metric
# --------------------------------------------------------------------------


def _parent(node_id: str) -> str | None:
    return node_id.rsplit("/", 1)[0] if "/" in node_id else None


def geometry(rows: list[dict]) -> dict[str, tuple[float, float, float]]:
    geo: dict[str, tuple[float, float, float]] = {}
    for row in rows:
        geo[row["node_id"]] = (float(row["x"]), float(row["y"]), float(row["radius"]))
    return geo


def expected_motion_zone(changed: set[str], all_nodes: set[str]) -> set[str]:
    zone: set[str] = set()
    for node in sorted(changed):
        parent = _parent(node)
        if parent is None:
            # A top-level node changed: the root repacks, so nothing is outside
            # the zone. Reported honestly rather than measured against a floor.
            return set(all_nodes)
        prefix = parent + "/"
        zone.update(n for n in all_nodes if n == parent or n.startswith(prefix))
        ancestor: str | None = parent
        while ancestor is not None:
            zone.add(ancestor)
            ancestor = _parent(ancestor)
    return zone


def _stats(values: list[float]) -> dict:
    if not values:
        return {"n": 0, "max": None, "mean": None, "p95": None}
    ordered = sorted(values)
    idx = min(len(ordered) - 1, int(round(0.95 * (len(ordered) - 1))))
    return {
        "n": len(values),
        "max": round(ordered[-1], 9),
        "mean": round(sum(values) / len(values), 9),
        "p95": round(ordered[idx], 9),
    }


def compare(geo_a: dict, geo_b: dict, changed: set[str]) -> dict:
    common = set(geo_a) & set(geo_b)
    all_nodes = set(geo_a) | set(geo_b)
    zone = expected_motion_zone(changed, all_nodes)
    outside = sorted(common - zone)
    inside = sorted(common & zone)

    def measure(nodes: list[str]) -> tuple[list[float], list[float]]:
        disp, radius = [], []
        for node in nodes:
            ax, ay, ar = geo_a[node]
            bx, by, br = geo_b[node]
            disp.append(sqrt((bx - ax) ** 2 + (by - ay) ** 2))
            radius.append(abs(br - ar))
        return disp, radius

    def decompose(nodes: list[str]) -> dict:
        """Split ripple into the part that translates the whole map and the part
        that reshuffles it. A rigid shift preserves every relative position; a
        residual does not. Diagnostic only — the pinned metric is the total."""
        if not nodes:
            return {"rigid_shift": None, "residual": _stats([])}
        vectors = [(geo_b[n][0] - geo_a[n][0], geo_b[n][1] - geo_a[n][1]) for n in nodes]
        mx = sum(v[0] for v in vectors) / len(vectors)
        my = sum(v[1] for v in vectors) / len(vectors)
        residual = [sqrt((vx - mx) ** 2 + (vy - my) ** 2) for vx, vy in vectors]
        return {"rigid_shift": round(sqrt(mx * mx + my * my), 9), "residual": _stats(residual)}

    out_disp, out_rad = measure(outside)
    in_disp, in_rad = measure(inside)
    worst = max(zip(out_disp, outside), default=(0.0, None))
    return {
        "outside_zone_decomposition": decompose(outside),
        "nodes_a": len(geo_a),
        "nodes_b": len(geo_b),
        "nodes_common": len(common),
        "zone_size": len(zone),
        "outside_zone": {"displacement": _stats(out_disp), "radius_change": _stats(out_rad)},
        "inside_zone": {"displacement": _stats(in_disp), "radius_change": _stats(in_rad)},
        "worst_outside_node": worst[1],
        # Two-sided guard: if the zone itself did not move, the probe measured
        # nothing and its "outside" numbers are meaningless.
        "zone_actually_moved": bool(in_disp and max(in_disp) > 1e-9),
    }


# --------------------------------------------------------------------------
# fixtures
# --------------------------------------------------------------------------


def _clone_store(src: Path, dst: Path) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    for name in INPUT_TABLES:
        shutil.copy2(src / name, dst / name)


def _write_modules(path: Path, rows: list[dict]) -> None:
    fields = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _module_row(template: dict, slug: str, n_funcs: int) -> dict:
    row = dict(template)
    row.update({"slug": slug, "path": f"{slug}.ail", "module_decl": slug, "n_funcs": n_funcs})
    return row


def _deepest_dir(slugs: list[str]) -> str:
    best = ""
    for slug in sorted(slugs):
        parent = _parent(slug)
        if parent and parent.count("/") > best.count("/"):
            best = parent
    return best


def _largest_l1_dir(slugs: list[str]) -> str:
    counts: dict[str, int] = {}
    for slug in slugs:
        segs = slug.split("/")
        if len(segs) >= 3:
            counts["/".join(segs[:2])] = counts.get("/".join(segs[:2]), 0) + 1
    return max(sorted(counts), key=lambda k: (counts[k], k))


def _mid_size_dir(slugs: list[str]) -> str:
    counts: dict[str, int] = {}
    for slug in slugs:
        parent = _parent(slug)
        if parent and parent.count("/") >= 1:
            counts[parent] = counts.get(parent, 0) + 1
    ranked = sorted((n, d) for d, n in counts.items() if 2 <= n <= 12)
    return ranked[len(ranked) // 2][1] if ranked else sorted(counts)[0]


def synthetic_fixtures(modules: list[dict]) -> list[tuple[str, str, list[dict], set[str]]]:
    """(name, description, mutated module rows, changed node ids)."""
    slugs = [row["slug"] for row in modules]
    template = modules[0]
    fixtures = []

    deep = _deepest_dir(slugs)
    added = f"{deep}/zz_probe_new"
    fixtures.append((
        "add-one-module-deep",
        f"add 1 module to the deepest directory ({deep})",
        modules + [_module_row(template, added, 8)],
        {added},
    ))

    pkg = _largest_l1_dir(slugs)
    new_ten = [f"{pkg}/zz_probe_{i:02d}" for i in range(10)]
    fixtures.append((
        "add-ten-modules-one-package",
        f"add 10 modules to the largest L1 package ({pkg})",
        modules + [_module_row(template, s, 6) for s in new_ten],
        set(new_ten),
    ))

    victim = _mid_size_dir(slugs)
    removed = {s for s in slugs if s.startswith(victim + "/")}
    fixtures.append((
        "delete-mid-size-dir",
        f"delete a mid-size directory ({victim}, {len(removed)} modules)",
        [row for row in modules if row["slug"] not in removed],
        removed,
    ))

    grown = sorted(slugs, key=lambda s: (-int(dict(zip([r["slug"] for r in modules], modules))[s]["n_funcs"] or 0), s))[0]
    grow_rows = []
    for row in modules:
        if row["slug"] == grown:
            row = dict(row)
            row["n_funcs"] = int(row["n_funcs"] or 1) * 5
        grow_rows.append(row)
    fixtures.append((
        "grow-one-module-5x",
        f"grow one module's n_funcs by 5x ({grown})",
        grow_rows,
        {grown},
    ))
    return fixtures


def q4_degeneracy(layout_rows: list[dict], modules: list[dict]) -> dict:
    """Q4's recorded degeneracy eyeball: does area = n_funcs produce a sane
    radius spread, or does one module swallow the picture?"""
    slugs = {row["slug"] for row in modules}
    radii = sorted(float(r["radius"]) for r in layout_rows if int(r["level"]) == 2 and r["node_id"] in slugs)
    funcs = sorted(int(row["n_funcs"] or 0) for row in modules)
    return {
        "module_radius_min": round(radii[0], 9),
        "module_radius_median": round(radii[len(radii) // 2], 9),
        "module_radius_max": round(radii[-1], 9),
        "module_radius_max_over_min": round(radii[-1] / radii[0], 3) if radii[0] else None,
        "n_funcs_min": funcs[0],
        "n_funcs_median": funcs[len(funcs) // 2],
        "n_funcs_max": funcs[-1],
        "n_funcs_zero_count": sum(1 for f in funcs if f == 0),
    }


# --------------------------------------------------------------------------
# driver
# --------------------------------------------------------------------------


def run(out_dir: Path, historical: Path | None) -> dict:
    baseline_rows, _, baseline_report = bl.build_rows(out_dir)
    modules = bl.read_csv(out_dir / "modules.csv")
    geo_base = geometry(baseline_rows)

    results = []
    with tempfile.TemporaryDirectory(prefix="cg-layout-probe-") as tmp:
        tmp_dir = Path(tmp)
        for name, description, mutated, changed in synthetic_fixtures(modules):
            store = tmp_dir / name
            _clone_store(out_dir, store)
            _write_modules(store / "modules.csv", mutated)
            rows, _, _ = bl.build_rows(store)
            entry = {"fixture": name, "description": description, "changed_nodes": len(changed)}
            entry.update(compare(geo_base, geometry(rows), changed))
            results.append(entry)

    if historical is not None:
        hist_rows, _, hist_report = bl.build_rows(historical)
        hist_modules = bl.read_csv(historical / "modules.csv")
        old = {row["slug"]: int(row["n_funcs"] or 0) for row in hist_modules}
        new = {row["slug"]: int(row["n_funcs"] or 0) for row in modules}
        changed = set(old) ^ set(new)
        changed |= {s for s in set(old) & set(new) if old[s] != new[s]}
        entry = {
            "fixture": "historical-pair",
            "description": f"real extraction pair: {len(old)} modules -> {len(new)} modules",
            "changed_nodes": len(changed),
        }
        entry.update(compare(geometry(hist_rows), geo_base, changed))
        results.append(entry)

    return {
        "profile": baseline_report["profile"],
        "snapshot": baseline_report["snapshot"],
        "layout_version": bl.LAYOUT_VERSION,
        "sep": bl.SEP,
        "pad": bl.PAD,
        "modules": len(modules),
        "q4_degeneracy": q4_degeneracy(baseline_rows, modules),
        "fixtures": results,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=bl.DEFAULT_OUT, help="baseline store (default: tools/code-graph/.out)")
    ap.add_argument("--historical-store", type=Path, default=None,
                    help="a second store built from an older commit's extraction, for the real-pair fixture")
    ap.add_argument("--check", action="store_true",
                    help="exit non-zero if a fixture breaches its calibrated threshold / regression ceiling")
    ns = ap.parse_args(argv)
    report = run(ns.out, ns.historical_store)
    breaches = []
    for fixture in report["fixtures"]:
        limits = THRESHOLDS.get(fixture["fixture"])
        if not limits:
            continue
        disp = fixture["outside_zone"]["displacement"]
        for key in ("mean", "max"):
            if disp[key] is not None and disp[key] > limits[key]:
                breaches.append(f"{fixture['fixture']} {key} {disp[key]} > {limits['kind']} {limits[key]}")
    report["breaches"] = breaches
    print(json.dumps(report, indent=2, sort_keys=True))
    unmoved = [f["fixture"] for f in report["fixtures"] if not f["zone_actually_moved"]]
    if unmoved:
        print(f"PROBE DEFECT: expected-motion zone did not move for {unmoved}", file=sys.stderr)
        return 1
    if ns.check and breaches:
        for breach in breaches:
            print(f"STABILITY BREACH: {breach}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
