"""The L0–L2 map's GPU-free half (010, task 2.2).

Everything here runs in the container, where D10 says the viewer cannot: the
render plan, the D4 style routing, the hover tooltip and the click target. The
host is then only needed for the acceptance walk, not for finding bugs — the
lesson the D7 gate charged four round-trips to teach.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "viewer"))

import bundling as bd  # noqa: E402
import map_view as mv  # noqa: E402
import styles  # noqa: E402

SNAPSHOT = "c" * 64

LAYOUT = [
    {"node_id": "src", "level": 0, "x": -0.4, "y": 0.0, "radius": 0.5, "snapshot": SNAPSHOT},
    {"node_id": "scripts", "level": 0, "x": 0.5, "y": 0.0, "radius": 0.35, "snapshot": SNAPSHOT},
    {"node_id": "src/core", "level": 1, "x": -0.4, "y": 0.0, "radius": 0.4, "snapshot": SNAPSHOT},
    {"node_id": "scripts/solo", "level": 1, "x": 0.5, "y": 0.0, "radius": 0.3, "snapshot": SNAPSHOT},
    {"node_id": "src/core/alpha", "level": 2, "x": -0.5, "y": 0.05, "radius": 0.12, "snapshot": SNAPSHOT},
    {"node_id": "src/core/beta", "level": 2, "x": -0.25, "y": -0.05, "radius": 0.09, "snapshot": SNAPSHOT},
    {"node_id": "scripts/solo", "level": 2, "x": 0.5, "y": 0.0, "radius": 0.3, "snapshot": SNAPSHOT},
]

EDGES = [
    {"level": 2, "src_agg": "src/core/alpha", "dst_agg": "src/core/beta", "kind": "imports",
     "weight": 1, "exactness": "exact"},
    {"level": 2, "src_agg": "scripts/solo", "dst_agg": "src/core/alpha", "kind": "imports",
     "weight": 1, "exactness": "exact"},
    {"level": 2, "src_agg": "src/core/alpha", "dst_agg": "src/core/beta", "kind": "invokes",
     "weight": 4, "exactness": "approximate"},
    {"level": 1, "src_agg": "src/core", "dst_agg": "src/core", "kind": "imports",
     "weight": 7, "exactness": "exact"},
    {"level": 1, "src_agg": "scripts/solo", "dst_agg": "src/core", "kind": "imports",
     "weight": 1, "exactness": "exact"},
    {"level": 0, "src_agg": "scripts", "dst_agg": "src", "kind": "imports",
     "weight": 2, "exactness": "exact"},
]

N_FUNCS = {"src/core/alpha": 12, "src/core/beta": 5, "scripts/solo": 3}


def _data(stale: bool = False) -> mv.MapData:
    return mv.MapData(
        layout=[dict(r) for r in LAYOUT],
        edges=[dict(r) for r in EDGES],
        n_funcs=dict(N_FUNCS),
        snapshot=SNAPSHOT,
        stale=stale,
        stale_reason="layout snapshot does not match the current extraction" if stale else None,
        profile="all",
    )


# --------------------------------------------------------------------------
# render plan
# --------------------------------------------------------------------------


def test_plan_covers_every_level_and_bundles_every_edge() -> None:
    plan = mv.build_render_plan(_data())
    assert [len(plan.levels[i].node_ids) for i in (0, 1, 2)] == [2, 2, 3]
    assert sum(len(e.polylines) for e in plan.edges) == len(EDGES)
    assert sum(e.unresolved for e in plan.edges) == 0


def test_edges_are_grouped_by_level_and_kind_not_flattened() -> None:
    plan = mv.build_render_plan(_data())
    keys = {(e.level, e.kind) for e in plan.edges}
    assert keys == {(2, "imports"), (2, "invokes"), (1, "imports"), (0, "imports")}


def test_style_table_is_the_only_source_of_edge_appearance() -> None:
    # A render path that draws `invokes` like `imports` must fail here rather
    # than survive to a review comment (D4).
    plan = mv.build_render_plan(_data())
    for buffer in plan.edges:
        assert buffer.style == styles.style_for(buffer.kind, buffer.exactness, stale=False)
    l2 = {e.kind: e.style for e in plan.edges if e.level == 2}
    assert l2["imports"].is_solid and not l2["invokes"].is_solid


def test_a_stale_snapshot_restyles_every_edge_and_raises_a_banner() -> None:
    fresh = mv.build_render_plan(_data(stale=False))
    stale = mv.build_render_plan(_data(stale=True))
    assert fresh.banner is None
    assert stale.banner is not None and stale.banner.startswith("STALE: ")
    for a, b in zip(fresh.edges, stale.edges):
        assert a.style != b.style, "a stale map must not look identical to a fresh one"
    # ...and the exact/approximate distinction must survive the restyle.
    stale_l2 = {e.kind: e.style for e in stale.edges if e.level == 2}
    assert stale_l2["imports"] != stale_l2["invokes"]


def test_only_modules_get_labels() -> None:
    plan = mv.build_render_plan(_data())
    labelled = {text for text, _, _ in plan.levels[2].labels}
    assert labelled == {"alpha", "beta", "solo"}
    assert plan.levels[0].labels == [] and plan.levels[1].labels == []


def test_bundled_edges_connect_the_nodes_they_claim_to() -> None:
    plan = mv.build_render_plan(_data())
    data = _data()
    row = EDGES[1]  # scripts/solo -> src/core/alpha, a cross-tree edge
    line = bd.bundle_edge(row["src_agg"], row["dst_agg"], data.positions)
    assert line[0] == data.positions[row["src_agg"]]
    assert line[-1] == data.positions[row["dst_agg"]]


def test_render_plan_is_deterministic() -> None:
    assert mv.build_render_plan(_data()).stats() == mv.build_render_plan(_data()).stats()


def test_lod_thresholds_map_camera_width_to_level() -> None:
    assert mv.lod_for_camera_width(2.0) == 0
    assert mv.lod_for_camera_width(0.9) == 1
    assert mv.lod_for_camera_width(0.2) == 2


# --------------------------------------------------------------------------
# hover
# --------------------------------------------------------------------------


def test_tooltip_shows_the_module_path_and_its_counts() -> None:
    text = mv.node_summary(_data(), "src/core/alpha")
    assert text.startswith("src/core/alpha")
    assert "12 funcs" in text
    assert "imports" in text and "invokes" in text


def test_tooltip_labels_invokes_as_approximate_in_the_text_itself() -> None:
    # A number in a tooltip reads as a fact unless it says otherwise; the edge
    # style alone is not enough when the reader is looking at digits.
    text = mv.node_summary(_data(), "src/core/alpha")
    invokes_line = next(line for line in text.splitlines() if line.startswith("invokes"))
    assert "approximate" in invokes_line
    exact_line = next(line for line in text.splitlines() if line.startswith("imports"))
    assert "exact" in exact_line


def test_tooltip_reports_intra_edges_rather_than_hiding_them_behind_out_zero() -> None:
    # src/core in the real store has 0 outbound imports and 181 internal ones.
    # Showing only in/out would make the densest package on the map look inert.
    text = mv.node_summary(_data(), "src/core")
    imports_line = next(line for line in text.splitlines() if line.startswith("imports"))
    assert "out 0" in imports_line
    assert "intra 7" in imports_line


def test_container_tooltip_aggregates_its_members() -> None:
    text = mv.node_summary(_data(), "src/core")
    assert text.startswith("src/core/")
    assert "2 modules" in text and "17 funcs" in text


# --------------------------------------------------------------------------
# click-to-editor
# --------------------------------------------------------------------------


def test_editor_target_prefers_an_explicit_template() -> None:
    target = mv.editor_target(_data(), "src/core/alpha", Path("/repo"),
                              env={"MOTOKO_MAP_EDITOR_URL": "idea://open?file={path}&line={line}",
                                   "EDITOR": "vim"})
    assert target.kind == "url"
    assert target.value == "idea://open?file=/repo/src/core/alpha.ail&line=1"


def test_editor_target_falls_back_to_EDITOR_then_to_a_url() -> None:
    with_editor = mv.editor_target(_data(), "src/core/alpha", Path("/repo"), env={"EDITOR": "code -g"})
    assert with_editor.kind == "command"
    assert with_editor.value == ["code", "-g", "/repo/src/core/alpha.ail"]
    bare = mv.editor_target(_data(), "src/core/alpha", Path("/repo"), env={})
    assert bare.kind == "url" and bare.value.startswith("vscode://file/")


def test_modules_open_a_file_and_containers_open_a_directory() -> None:
    module = mv.editor_target(_data(), "src/core/alpha", Path("/repo"), env={})
    container = mv.editor_target(_data(), "src/core", Path("/repo"), env={})
    assert module.path.endswith("src/core/alpha.ail")
    assert container.path.endswith("src/core")
    assert not container.path.endswith(".ail")
