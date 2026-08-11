"""Hermetic tests for the 010/P1 layout builder and its validator.

This is the "fixture mini-tree" the plan (task 1.3, Gap 1) recorded as a
proposal: builder + validator run end to end in milliseconds without a full
extraction, so any workflow that later adopts them has something cheap to run.

Every rule is exercised **two-sided** (the standing meta-decision): a clean
tree must validate green, and a deliberately broken table must produce that
rule's finding. A validator that can only say "yes" is not a detector.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "layout"))

import build_layout as bl  # noqa: E402
import validate_layout as vl  # noqa: E402

MODULES = [
    # slug, n_funcs
    ("src/core/alpha", 5),
    ("src/core/beta", 3),
    ("src/core/ext/gamma", 2),  # forces a depth-3 packing container: src/core/ext
    ("scripts/solo", 1),  # depth-2 module -> its own L1 aggregate
    ("packages/p-one/mod", 4),
    ("examples/zero", 0),  # area floor keeps zero-func modules visible
]

IMPORTS = [
    ("src/core/alpha", "src/core/beta"),
    ("src/core/alpha", "src/core/ext/gamma"),
    ("scripts/solo", "src/core/alpha"),
    ("packages/p-one/mod", "src/core/alpha"),
    ("src/core/beta", "src/core/beta"),  # self-loop: kept, never dropped
    ("src/core/alpha", "src/core/beta"),  # duplicate pair: weight stays 1
]

INVOKES = [
    ("src/core/alpha#a1", "src/core/beta#b1"),
    ("src/core/alpha#a2", "src/core/beta#b1"),
    ("src/core/alpha#a1", "src/core/ext/gamma#g1"),
    ("scripts/solo#s1", "src/core/alpha#a1"),
]


def _write(path: Path, fields: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


@pytest.fixture()
def mini_store(tmp_path: Path) -> Path:
    out = tmp_path / ".out"
    _write(
        out / "modules.csv",
        ["slug", "path", "module_decl", "decl_matches_path", "n_funcs", "is_generated", "is_root", "root_reason"],
        [
            {
                "slug": slug,
                "path": f"{slug}.ail",
                "module_decl": slug,
                "decl_matches_path": 1,
                "n_funcs": n,
                "is_generated": 0,
                "is_root": 0,
                "root_reason": "",
            }
            for slug, n in MODULES
        ],
    )
    _write(
        out / "extraction_status.csv",
        [
            "module", "iface_status", "iface_detail", "iface_error", "built_at", "ailang_version",
            "graph_schema", "source_schema", "iface_schema", "profile", "include_tests",
        ],
        [
            {
                "module": slug,
                "iface_status": "ok",
                "iface_detail": "ok",
                "iface_error": "",
                "built_at": "2026-08-08T00:00:00+00:00",
                "ailang_version": "AILANG test",
                "graph_schema": 1,
                "source_schema": 1,
                "iface_schema": "ailang.iface/v1",
                "profile": "all",
                "include_tests": 0,
            }
            for slug, _ in MODULES
        ],
    )
    _write(
        out / "imports.csv",
        ["from_module", "to_module", "alias", "symbols"],
        [{"from_module": a, "to_module": b, "alias": "", "symbols": ""} for a, b in IMPORTS],
    )
    _write(
        out / "invokes.csv",
        ["from_slug", "to_slug", "resolution", "approximate"],
        [{"from_slug": a, "to_slug": b, "resolution": "local", "approximate": 1} for a, b in INVOKES],
    )
    return out


def _build(store: Path):
    return bl.build_rows(store)


# --------------------------------------------------------------------------
# positive direction
# --------------------------------------------------------------------------


def test_clean_tree_validates_green(mini_store: Path) -> None:
    layout_rows, edge_rows, report = _build(mini_store)
    assert vl.validate_rows(layout_rows, edge_rows, mini_store) == []
    assert report["dropped_edge_endpoints"] == {"imports": 0, "invokes": 0}


def test_builder_writes_only_after_validating(mini_store: Path) -> None:
    report = bl.build(mini_store, write=True, validate=True)
    assert report["findings"] == []
    assert (mini_store / "layout.csv").exists()
    assert (mini_store / "edges_agg.csv").exists()
    assert vl.validate_store(mini_store) == []


def test_level_mapping_is_the_pinned_prefix_class_rule(mini_store: Path) -> None:
    layout_rows, edge_rows, _ = _build(mini_store)
    by_level: dict[int, set[str]] = {}
    for row in layout_rows:
        by_level.setdefault(int(row["level"]), set()).add(row["node_id"])

    # L0 = first path segment, one row per top-level directory.
    assert by_level[0] == {"src", "scripts", "packages", "examples"}
    # A depth-2 module is its own L1 aggregate and still has its L2 row.
    assert "scripts/solo" in by_level[1]
    assert "scripts/solo" in by_level[2]
    # A depth-3 directory is a packing container: L2 layout row, no L0/L1 row...
    assert "src/core/ext" in by_level[2]
    assert "src/core/ext" not in by_level[0] and "src/core/ext" not in by_level[1]
    # ...and it never appears as an edges_agg endpoint.
    endpoints = {row["src_agg"] for row in edge_rows} | {row["dst_agg"] for row in edge_rows}
    assert "src/core/ext" not in endpoints
    # Every module has exactly one L2 row.
    assert {slug for slug, _ in MODULES} <= by_level[2]


def test_zero_func_modules_keep_a_visible_radius(mini_store: Path) -> None:
    layout_rows, _, _ = _build(mini_store)
    radius = next(float(r["radius"]) for r in layout_rows if r["node_id"] == "examples/zero")
    assert radius > 0.0


def test_import_pairs_are_deduplicated_and_self_loops_kept(mini_store: Path) -> None:
    _, edge_rows, _ = _build(mini_store)
    l2 = {(r["src_agg"], r["dst_agg"]): int(r["weight"]) for r in edge_rows if r["kind"] == "imports" and r["level"] == 2}
    assert l2[("src/core/alpha", "src/core/beta")] == 1  # duplicate row collapsed
    assert l2[("src/core/beta", "src/core/beta")] == 1  # self-loop present, not dropped


def test_rollup_totals_are_conserved_across_levels(mini_store: Path) -> None:
    _, edge_rows, _ = _build(mini_store)
    totals: dict[tuple[str, int], int] = {}
    for row in edge_rows:
        key = (row["kind"], row["level"])
        totals[key] = totals.get(key, 0) + int(row["weight"])
    for kind in ("imports", "invokes"):
        assert totals[(kind, 0)] == totals[(kind, 1)] == totals[(kind, 2)]


def test_snapshot_changes_when_layout_version_changes(mini_store: Path, monkeypatch) -> None:
    status = bl.read_csv(mini_store / "extraction_status.csv")
    before = bl.compute_snapshot(status, "all")
    monkeypatch.setattr(bl, "LAYOUT_VERSION", bl.LAYOUT_VERSION + 1)
    assert bl.compute_snapshot(status, "all") != before


# --------------------------------------------------------------------------
# negative direction — one deliberate break per rule
# --------------------------------------------------------------------------


def _rules(findings) -> set[str]:
    return {f.rule for f in findings}


def test_rollup_sum_rule_catches_a_tampered_weight(mini_store: Path) -> None:
    layout_rows, edge_rows, _ = _build(mini_store)
    target = next(r for r in edge_rows if r["level"] == 1 and r["kind"] == "imports")
    target["weight"] += 1
    assert "rollup-sum" in _rules(vl.validate_rows(layout_rows, edge_rows, mini_store, check_determinism=False))


def test_containment_rule_catches_a_child_pushed_outside_its_parent(mini_store: Path) -> None:
    layout_rows, edge_rows, _ = _build(mini_store)
    for row in layout_rows:
        if row["node_id"] == "src/core/alpha":
            row["x"] = bl.q(9.0)
    assert "containment" in _rules(vl.validate_rows(layout_rows, edge_rows, mini_store, check_determinism=False))


def test_sibling_overlap_rule_catches_two_circles_on_top_of_each_other(mini_store: Path) -> None:
    layout_rows, edge_rows, _ = _build(mini_store)
    alpha = next(r for r in layout_rows if r["node_id"] == "src/core/alpha")
    for row in layout_rows:
        if row["node_id"] == "src/core/beta":
            row["x"], row["y"] = alpha["x"], alpha["y"]
    findings = vl.validate_rows(layout_rows, edge_rows, mini_store, check_determinism=False)
    assert "sibling-overlap" in _rules(findings)


def test_coverage_rule_catches_a_missing_l2_row(mini_store: Path) -> None:
    layout_rows, edge_rows, _ = _build(mini_store)
    kept = [r for r in layout_rows if not (r["node_id"] == "src/core/beta" and int(r["level"]) == 2)]
    assert "coverage" in _rules(vl.validate_rows(kept, edge_rows, mini_store, check_determinism=False))


def test_coverage_rule_catches_an_edge_endpoint_with_no_layout_row(mini_store: Path) -> None:
    layout_rows, edge_rows, _ = _build(mini_store)
    edge_rows.append(
        {"level": 2, "src_agg": "src/core/alpha", "dst_agg": "src/core/ghost", "kind": "imports",
         "weight": 1, "exactness": "exact"}
    )
    findings = vl.validate_rows(layout_rows, edge_rows, mini_store, check_determinism=False)
    assert "coverage" in _rules(findings)
    assert "rollup-sum" in _rules(findings)  # the phantom edge also breaks the sum


def test_determinism_rule_catches_a_nondeterministic_builder(mini_store: Path, monkeypatch) -> None:
    layout_rows, edge_rows, _ = _build(mini_store)
    real_sib_key = bl._sib_key

    def flaky(node):
        # The rebuild orders siblings differently from the build under test —
        # the exact failure mode (dict order, RNG, platform sort) the rule exists to catch.
        digest, path = real_sib_key(node)
        return (digest[::-1], path)

    monkeypatch.setattr(bl, "_sib_key", flaky)
    assert "determinism" in _rules(vl.validate_rows(layout_rows, edge_rows, mini_store))


def test_geometry_disagreement_across_levels_is_reported(mini_store: Path) -> None:
    layout_rows, edge_rows, _ = _build(mini_store)
    # scripts/solo appears at L1 and L2; make the two rows disagree.
    for row in layout_rows:
        if row["node_id"] == "scripts/solo" and int(row["level"]) == 1:
            row["radius"] = bl.q(0.123456789)
    assert "containment" in _rules(vl.validate_rows(layout_rows, edge_rows, mini_store, check_determinism=False))


def test_module_that_is_also_a_directory_prefix_is_refused(tmp_path: Path) -> None:
    # The pinned level mapping does not define this case; the builder must stop
    # loudly rather than invent a rule (plan guardrail: a scope question is a
    # finding, not a silent workaround).
    with pytest.raises(SystemExit):
        bl.build_tree(
            [
                {"slug": "src/core", "n_funcs": "1"},
                {"slug": "src/core/alpha", "n_funcs": "1"},
            ]
        )
