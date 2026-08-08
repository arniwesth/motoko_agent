"""Container-side tests for the D7 spike's GPU-free half (010, task 2.1).

The devcontainer cannot run the spike (ADR D10), and every host round-trip is
expensive. So everything in the spike that does *not* need an adapter — scene
construction, the LOD mapping, node resolution, stress replication, and the
grading function itself — is tested here. The host then only exercises what
genuinely needs a GPU.

The load-bearing test is the last one: a spike that measured nothing must grade
as ``not-measured``, never as ``pass``. A gate that passes by default is not a
gate.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "viewer"))

import spike_l0l2 as spike  # noqa: E402
import styles  # noqa: E402

SNAPSHOT = "a" * 64

LAYOUT = [
    {"node_id": "src", "level": 0, "x": -0.4, "y": 0.0, "radius": 0.5, "snapshot": SNAPSHOT},
    {"node_id": "scripts", "level": 0, "x": 0.5, "y": 0.0, "radius": 0.4, "snapshot": SNAPSHOT},
    {"node_id": "src/core", "level": 1, "x": -0.4, "y": 0.0, "radius": 0.4, "snapshot": SNAPSHOT},
    {"node_id": "scripts/solo", "level": 1, "x": 0.5, "y": 0.0, "radius": 0.3, "snapshot": SNAPSHOT},
    {"node_id": "src/core/alpha", "level": 2, "x": -0.5, "y": 0.0, "radius": 0.15, "snapshot": SNAPSHOT},
    {"node_id": "src/core/beta", "level": 2, "x": -0.2, "y": 0.0, "radius": 0.10, "snapshot": SNAPSHOT},
    {"node_id": "scripts/solo", "level": 2, "x": 0.5, "y": 0.0, "radius": 0.3, "snapshot": SNAPSHOT},
]

EDGES = [
    {"level": 2, "src_agg": "src/core/alpha", "dst_agg": "src/core/beta", "kind": "imports",
     "weight": 1, "exactness": "exact"},
    {"level": 2, "src_agg": "src/core/beta", "dst_agg": "src/core/beta", "kind": "imports",
     "weight": 1, "exactness": "exact"},
    {"level": 2, "src_agg": "scripts/solo", "dst_agg": "src/core/alpha", "kind": "invokes",
     "weight": 4, "exactness": "approximate"},
    {"level": 1, "src_agg": "scripts/solo", "dst_agg": "src/core", "kind": "imports",
     "weight": 1, "exactness": "exact"},
    {"level": 0, "src_agg": "scripts", "dst_agg": "src", "kind": "imports",
     "weight": 1, "exactness": "exact"},
]


def _scene(stress: int = 0):
    return spike.build_scene(LAYOUT, EDGES, stress=stress)


def test_scene_has_every_level_and_carries_the_snapshot() -> None:
    scene = _scene()
    assert scene.node_count(0) == 2
    assert scene.node_count(1) == 2
    assert scene.node_count(2) == 3
    assert scene.snapshot == SNAPSHOT


def test_mixed_snapshots_are_surfaced_not_silently_picked() -> None:
    rows = [dict(r) for r in LAYOUT]
    rows[0]["snapshot"] = "b" * 64
    assert spike.build_scene(rows, EDGES).snapshot == "MIXED"


def test_edge_kinds_reach_the_scene_in_visually_distinct_styles() -> None:
    scene = _scene()
    l2 = [g for g in scene.edge_groups if g.level == 2]
    signatures = {(g.style.color, g.style.dash, g.style.thickness) for g in l2}
    assert len(signatures) == len(l2) >= 2, "D4 must survive scene construction, not just the style table"
    assert next(g for g in l2 if g.kind == "imports").style.is_solid
    assert not next(g for g in l2 if g.kind == "invokes").style.is_solid


def test_self_loops_are_drawn_not_dropped() -> None:
    scene = _scene()
    imports_l2 = next(g for g in scene.edge_groups if g.level == 2 and g.kind == "imports")
    assert imports_l2.self_loops == 1
    # 2 rows at L2 for imports, both produce geometry — one line, one loop stub.
    assert len(imports_l2.segments) == 2


def test_edges_whose_endpoints_are_missing_are_counted_not_crashed() -> None:
    rows = EDGES + [{"level": 2, "src_agg": "src/core/alpha", "dst_agg": "src/core/ghost",
                     "kind": "imports", "weight": 1, "exactness": "exact"}]
    scene = spike.build_scene(LAYOUT, rows)
    imports_l2 = next(g for g in scene.edge_groups if g.level == 2 and g.kind == "imports")
    assert imports_l2.unresolved == 1


def test_lod_thresholds_map_camera_width_to_level() -> None:
    assert spike.lod_for_camera_width(2.0) == 0
    assert spike.lod_for_camera_width(1.5) == 0
    assert spike.lod_for_camera_width(0.9) == 1
    assert spike.lod_for_camera_width(0.5) == 1
    assert spike.lod_for_camera_width(0.35) == 2
    assert spike.lod_for_camera_width(0.01) == 2


def test_resolve_node_prefers_the_smallest_containing_circle() -> None:
    scene = _scene()
    # A point inside src/core/beta is also inside nothing else at L2 here, but the
    # rule that matters is that the tightest circle wins, not the first found.
    assert spike.resolve_node(scene, 2, -0.2, 0.0) == "src/core/beta"
    assert spike.resolve_node(scene, 1, -0.4, 0.0) == "src/core"
    assert spike.resolve_node(scene, 0, 0.5, 0.0) == "scripts"


def test_resolve_node_returns_none_outside_every_circle() -> None:
    assert spike.resolve_node(_scene(), 2, 5.0, 5.0) is None


def test_stress_replication_reaches_the_requested_density() -> None:
    scene = _scene(stress=30)
    assert scene.stress_factor == 10  # 3 L2 nodes per copy
    assert scene.node_count(2) >= 30
    # One label per L2 node — a replicated scene must not multiply the label count
    # again, or criterion 5 would be graded against a number that is not real.
    assert len(scene.labels) == scene.node_count(2)
    assert len(set(scene.levels[2].node_ids)) == scene.node_count(2), "replica ids must stay unique"


def test_stress_below_the_real_node_count_is_a_no_op() -> None:
    scene = _scene(stress=2)
    assert scene.stress_factor == 1
    assert scene.levels[2].node_ids == _scene().levels[2].node_ids


def test_replicated_scene_still_resolves_to_a_single_node() -> None:
    scene = _scene(stress=30)
    nid = scene.levels[2].node_ids[7]
    idx = scene.levels[2].node_ids.index(nid)
    cx, cy = scene.levels[2].centers[idx]
    assert spike.resolve_node(scene, 2, cx, cy) == nid


# --------------------------------------------------------------------------
# grading — the gate must not pass by default
# --------------------------------------------------------------------------


def test_a_spike_that_measured_nothing_does_not_pass() -> None:
    scene = _scene()
    report = spike.grade(scene, spike.Measurements(), windowed=False, stress_stats=None)
    assert report["overall"] == "fail"
    assert set(report["unmeasured"]) >= {"2_pan_zoom_fps", "3_picking_latency", "4_lod_switch_no_stall"}
    assert report["criteria"]["6_standalone_window_from_store"]["verdict"] == "fail"


def test_slow_frames_fail_the_fps_criterion() -> None:
    m = spike.Measurements()
    m.frame_dt = [0.1] * 60  # 10 fps
    report = spike.grade(_scene(), m, windowed=True, stress_stats=None)
    assert report["criteria"]["2_pan_zoom_fps"]["verdict"] == "fail"


def test_a_median_that_hides_hitches_still_fails_on_p5() -> None:
    m = spike.Measurements()
    m.frame_dt = [1 / 120] * 95 + [0.5] * 5  # great median, terrible tail
    report = spike.grade(_scene(), m, windowed=True, stress_stats=None)
    criterion = report["criteria"]["2_pan_zoom_fps"]
    assert criterion["median_fps"] >= spike.TARGET_FPS
    assert criterion["verdict"] == "fail", "sustained fps must be graded on the tail, not the median"


def test_slow_picking_fails_and_fast_picking_passes() -> None:
    scene = _scene()
    slow = spike.Measurements()
    slow.frame_dt = [1 / 60] * 60
    slow.pick_ms = [12.0, 350.0]
    assert spike.grade(scene, slow, True, None)["criteria"]["3_picking_latency"]["verdict"] == "fail"
    fast = spike.Measurements()
    fast.frame_dt = [1 / 60] * 60
    fast.pick_ms = [1.2, 3.4]
    assert spike.grade(scene, fast, True, None)["criteria"]["3_picking_latency"]["verdict"] == "pass"


def test_more_than_one_lod_hitch_fails() -> None:
    scene = _scene()
    m = spike.Measurements()
    m.frame_dt = [1 / 60] * 60
    m.lod_crossings = [
        {"from": 0, "to": 1, "camera_width": 0.9, "frame_dt": 0.2},
        {"from": 1, "to": 2, "camera_width": 0.35, "frame_dt": 0.3},
    ]
    assert spike.grade(scene, m, True, None)["criteria"]["4_lod_switch_no_stall"]["verdict"] == "fail"
    m.lod_crossings = [
        {"from": 0, "to": 1, "camera_width": 0.9, "frame_dt": 0.2},
        {"from": 1, "to": 2, "camera_width": 0.35, "frame_dt": 1 / 90},
    ]
    assert spike.grade(scene, m, True, None)["criteria"]["4_lod_switch_no_stall"]["verdict"] == "pass"


def test_label_criterion_flags_a_scene_too_small_to_grade_it() -> None:
    m = spike.Measurements()
    m.frame_dt = [1 / 60] * 60
    report = spike.grade(_scene(), m, True, None)  # 3 labels, far under the 200 floor
    criterion = report["criteria"]["5_l2_labels"]
    assert criterion["verdict"] == "fail"
    assert "stress" in (criterion["note"] or "")


def test_style_table_is_the_only_source_of_edge_appearance() -> None:
    # Regression guard against a future spike edit that hardcodes a colour and
    # quietly drops the exact/approximate distinction.
    scene = _scene()
    for group in scene.edge_groups:
        assert group.style == styles.style_for(group.kind, group.exactness)
