"""Hierarchical edge bundling geometry (010, task 2.2; D3).

All of this is pure, so it is tested where the viewer cannot run (D10). The
load-bearing assertions are the two that would let the map lie:

* a bundled edge must START and END exactly at its endpoints — a curve that
  visibly misses them misrepresents which modules are connected;
* bundling must be a load-time computation, so the geometry is a pure function
  of (tree, beta) with no render-time aggregation anywhere (D3 hard rule).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "viewer"))

import bundling as bd  # noqa: E402

POSITIONS: dict[str, tuple[float, float]] = {
    "src": (-0.4, 0.0),
    "src/core": (-0.4, 0.0),
    "src/core/alpha": (-0.5, 0.1),
    "src/core/beta": (-0.3, -0.1),
    "src/core/ext": (-0.45, 0.2),
    "src/core/ext/gamma": (-0.46, 0.22),
    "scripts": (0.5, 0.0),
    "scripts/solo": (0.5, 0.0),
}


def _close(a, b, tol=1e-9):
    return math.isclose(a[0], b[0], abs_tol=tol) and math.isclose(a[1], b[1], abs_tol=tol)


# --------------------------------------------------------------------------
# tree
# --------------------------------------------------------------------------


def test_parent_of_walks_to_the_root() -> None:
    assert bd.parent_of("src/core/alpha") == "src/core"
    assert bd.parent_of("src/core") == "src"
    assert bd.parent_of("src") == bd.ROOT


def test_lca_of_siblings_is_their_container() -> None:
    assert bd.lca("src/core/alpha", "src/core/beta") == "src/core"


def test_lca_across_top_level_dirs_is_the_root() -> None:
    assert bd.lca("src/core/alpha", "scripts/solo") == bd.ROOT


def test_lca_of_an_ancestor_pair_is_the_ancestor() -> None:
    assert bd.lca("src/core", "src/core/alpha") == "src/core"
    assert bd.lca("src/core/alpha", "src/core/alpha") == "src/core/alpha"


def test_control_path_routes_up_and_back_down() -> None:
    assert bd.control_path("src/core/alpha", "src/core/beta") == [
        "src/core/alpha", "src/core", "src/core/beta",
    ]


def test_control_path_across_the_tree_passes_through_the_root() -> None:
    path = bd.control_path("src/core/alpha", "scripts/solo")
    assert path[0] == "src/core/alpha" and path[-1] == "scripts/solo"
    assert bd.ROOT in path, "a cross-package edge must route through the containment root"
    assert path == ["src/core/alpha", "src/core", "src", bd.ROOT, "scripts", "scripts/solo"]


def test_control_path_between_a_node_and_its_own_container_is_direct() -> None:
    assert bd.control_path("src/core", "src/core/alpha") == ["src/core", "src/core/alpha"]


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------


def test_bspline_starts_and_ends_exactly_at_the_endpoints() -> None:
    # Exact, not approximate: callers compare endpoint identity without a
    # tolerance, so the clamped basis's ~1e-16 rounding is pinned away.
    pts = [(0.0, 0.0), (0.5, 1.0), (1.0, 0.0)]
    curve = bd.bspline(pts, samples=8)
    assert curve[0] == pts[0]
    assert curve[-1] == pts[-1]


def test_bundled_edge_starts_and_ends_exactly_at_its_endpoints() -> None:
    curve = bd.bundle_edge("src/core/alpha", "scripts/solo", POSITIONS)
    assert curve is not None
    assert curve[0] == POSITIONS["src/core/alpha"]
    assert curve[-1] == POSITIONS["scripts/solo"]


def test_bundling_bends_the_edge_toward_the_hierarchy() -> None:
    # A bundled cross-tree edge must not be the straight line; if it were, D3's
    # bundling requirement would be satisfied in name only.
    a, b = POSITIONS["src/core/alpha"], POSITIONS["scripts/solo"]
    curve = bd.bundle_edge("src/core/alpha", "scripts/solo", POSITIONS, beta=1.0)
    mid = curve[len(curve) // 2]
    straight_mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    assert not _close(mid, straight_mid, tol=1e-3)


def test_beta_zero_collapses_to_a_straight_line() -> None:
    curve = bd.bundle_edge("src/core/alpha", "scripts/solo", POSITIONS, beta=0.0)
    a, b = POSITIONS["src/core/alpha"], POSITIONS["scripts/solo"]
    for x, y in curve:
        # every sample lies on the segment: cross product ~ 0
        cross = (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0])
        assert abs(cross) < 1e-9


def test_higher_beta_bends_further_than_lower_beta() -> None:
    def deviation(beta: float) -> float:
        a, b = POSITIONS["src/core/alpha"], POSITIONS["scripts/solo"]
        curve = bd.bundle_edge("src/core/alpha", "scripts/solo", POSITIONS, beta=beta)
        return max(
            abs((b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0])) for x, y in curve
        )

    assert deviation(0.9) > deviation(0.4) > deviation(0.0)


def test_straighten_is_identity_at_full_strength() -> None:
    pts = [(0.0, 0.0), (0.3, 0.9), (1.0, 0.0)]
    assert bd.straighten(pts, 1.0) == pts


def test_bundling_is_deterministic() -> None:
    first = bd.bundle_edge("src/core/alpha", "src/core/ext/gamma", POSITIONS)
    second = bd.bundle_edge("src/core/alpha", "src/core/ext/gamma", POSITIONS)
    assert first == second


def test_missing_endpoint_yields_none_and_is_countable() -> None:
    assert bd.bundle_edge("src/core/alpha", "src/core/ghost", POSITIONS) is None
    lines, unresolved = bd.bundle_all(
        [("src/core/alpha", "src/core/beta"), ("src/core/alpha", "src/core/ghost")], POSITIONS
    )
    assert len(lines) == 1 and unresolved == 1


def test_missing_intermediate_ancestor_does_not_drag_the_curve_to_the_origin() -> None:
    # An ancestor absent from `layout` must be skipped, not defaulted to (0, 0):
    # an invented control point would haul the edge across the whole map.
    sparse = {k: v for k, v in POSITIONS.items() if k != "src/core"}
    curve = bd.bundle_edge("src/core/alpha", "src/core/beta", sparse, beta=1.0)
    assert curve is not None
    assert all(abs(x) > 0.05 for x, _ in curve), "curve was dragged toward the origin"


def test_self_loop_is_drawn_not_dropped() -> None:
    lines, unresolved = bd.bundle_all([("src/core/beta", "src/core/beta")], POSITIONS)
    assert unresolved == 0
    assert len(lines) == 1 and len(lines[0]) > 3
    # It is a closed loop that does not sit on top of the node centre.
    assert _close(lines[0][0], lines[0][-1], tol=1e-9)
    centre = POSITIONS["src/core/beta"]
    assert any(not _close(p, centre, tol=1e-6) for p in lines[0])


def test_bundle_all_is_a_load_time_pure_function() -> None:
    # D3's hard rule: no aggregation at render time. The whole edge set must be
    # computable from (edges, positions) alone, with no viewer state involved.
    edges = [("src/core/alpha", "src/core/beta"), ("src/core/alpha", "scripts/solo")]
    a, _ = bd.bundle_all(edges, POSITIONS)
    b, _ = bd.bundle_all(edges, dict(POSITIONS))
    assert a == b
