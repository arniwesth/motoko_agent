#!/usr/bin/env python3
"""The L0–L2 architecture map (project 010, task 2.2; ADR-001 D3 + D4 + D8).

The D7 gate passed (`NOTE-d7-spike-verdict.md`), so this is the map proper. The
spike was disposable; what it left behind is the verdict and five wiring facts,
all inherited here and commented where they bite.

What this adds over the spike:

* **Hierarchical edge bundling** along the containment tree (D3), precomputed
  into polylines at load. The render loop only swaps precomputed buffers — no
  aggregation, no re-bundling, ever.
* **D8's shared access layer**: tables are read through ``cgq.run_sql``, the same
  chdb views the agent CLI queries. There is deliberately no parallel store
  surface; if a number differs between the map and ``cgq``, that is a bug in one
  query rather than two sources of truth.
* **D4 at the pixels**: every edge appearance comes from
  ``styles.style_for`` — a render path that draws ``invokes`` like ``imports``
  fails a unit test rather than a review comment. A stale layout snapshot
  restyles every edge *and* pins a banner mirroring ``cgq.py``'s wording.
* Hover → module path and counts; click → the real editor (D3 puts anything
  beyond a static preview out of scope, so click-through leaves the canvas).

Run on the HOST via the environment ``install_host.sh`` builds (D10):

    cd tools/code-graph/viewer && uv run --frozen python map_view.py

``--dry-run`` builds the whole render plan importing nothing GPU-bound, so the
geometry is verifiable in the container where the viewer cannot run.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

VIEWER_DIR = Path(__file__).resolve().parent
TOOL_ROOT = VIEWER_DIR.parent
REPO_ROOT = TOOL_ROOT.parents[1]
sys.path.insert(0, str(VIEWER_DIR))
sys.path.insert(0, str(TOOL_ROOT / "query"))

import bundling as bd  # noqa: E402
import styles  # noqa: E402

DEFAULT_OUT = TOOL_ROOT / ".out"

LOD_THRESHOLDS = ((0, 2.0), (1, 0.9), (2, 0.35))
RING_SEGMENTS_CONTAINER = 64
RING_SEGMENTS_MODULE = 28


# --------------------------------------------------------------------------
# data — through cgq's chdb views, never a parallel reader (D8)
# --------------------------------------------------------------------------


@dataclass
class MapData:
    layout: list[dict]
    edges: list[dict]
    n_funcs: dict[str, int]
    snapshot: str
    stale: bool
    stale_reason: str | None
    profile: str

    positions: dict[str, tuple[float, float]] = field(default_factory=dict)
    radii: dict[str, float] = field(default_factory=dict)
    levels: dict[str, int] = field(default_factory=dict)

    def __post_init__(self) -> None:
        for row in self.layout:
            node = row["node_id"]
            self.positions[node] = (float(row["x"]), float(row["y"]))
            self.radii[node] = float(row["radius"])
            self.levels[node] = max(self.levels.get(node, 0), int(row["level"]))

    def is_module(self, node_id: str) -> bool:
        return node_id in self.n_funcs


def load_map(out_dir: Path = DEFAULT_OUT) -> MapData:
    import cgq

    cgq.OUT_DIR = out_dir
    for name in ("layout.csv", "edges_agg.csv"):
        if not (out_dir / name).exists():
            raise SystemExit(
                f"missing {out_dir / name}. Generate it CONTAINER-side (no GPU needed):\n"
                f"  tools/code-graph/extract.sh --profile=all"
            )
    layout = cgq.run_sql("SELECT node_id, level, x, y, radius, snapshot FROM layout").get("data", [])
    edges = cgq.run_sql(
        "SELECT level, src_agg, dst_agg, kind, weight, exactness FROM edges_agg"
    ).get("data", [])
    modules = cgq.run_sql("SELECT slug, n_funcs FROM modules").get("data", [])
    status = cgq.run_sql("SELECT * FROM extraction_status").get("data", [])
    profile = (status[0].get("profile") if status else "") or "unknown"
    stale, reason, snapshot = cgq._layout_freshness(status, profile)
    return MapData(
        layout=layout,
        edges=edges,
        n_funcs={row["slug"]: int(row["n_funcs"]) for row in modules},
        snapshot=snapshot or "unknown",
        stale=bool(stale),
        stale_reason=reason,
        profile=profile,
    )


# --------------------------------------------------------------------------
# render plan — pure, so the container can verify it (D10)
# --------------------------------------------------------------------------


@dataclass
class LevelBuffers:
    node_ids: list[str] = field(default_factory=list)
    centers: list[tuple[float, float]] = field(default_factory=list)
    radii: list[float] = field(default_factory=list)
    rings: list[list[tuple[float, float]]] = field(default_factory=list)
    labels: list[tuple[str, float, float]] = field(default_factory=list)


@dataclass
class EdgeBuffer:
    level: int
    kind: str
    exactness: str
    style: styles.EdgeStyle
    polylines: list[list[tuple[float, float]]] = field(default_factory=list)
    unresolved: int = 0


@dataclass
class RenderPlan:
    levels: dict[int, LevelBuffers]
    edges: list[EdgeBuffer]
    banner: str | None
    legend: list[styles.EdgeStyle]
    snapshot: str
    profile: str

    def stats(self) -> dict:
        return {
            "profile": self.profile,
            "snapshot": self.snapshot,
            "banner": self.banner,
            "nodes_per_level": {str(k): len(v.node_ids) for k, v in sorted(self.levels.items())},
            "labels": sum(len(v.labels) for v in self.levels.values()),
            "edge_buffers": [
                {
                    "level": e.level, "kind": e.kind, "exactness": e.exactness,
                    "polylines": len(e.polylines), "unresolved": e.unresolved,
                    "solid": e.style.is_solid, "legend": e.style.legend,
                }
                for e in self.edges
            ],
            "legend_entries": len(self.legend),
        }


def _ring(cx: float, cy: float, r: float, segments: int) -> list[tuple[float, float]]:
    return [
        (cx + r * math.cos(2 * math.pi * i / segments), cy + r * math.sin(2 * math.pi * i / segments))
        for i in range(segments + 1)
    ]


def build_render_plan(data: MapData, beta: float = bd.DEFAULT_BETA) -> RenderPlan:
    per_level: dict[int, list[str]] = {0: [], 1: [], 2: []}
    for row in data.layout:
        per_level[int(row["level"])].append(row["node_id"])

    levels: dict[int, LevelBuffers] = {}
    for level in (0, 1, 2):
        buffers = LevelBuffers()
        segments = RING_SEGMENTS_MODULE if level == 2 else RING_SEGMENTS_CONTAINER
        for node in sorted(per_level[level]):
            cx, cy = data.positions[node]
            r = data.radii[node]
            buffers.node_ids.append(node)
            buffers.centers.append((cx, cy))
            buffers.radii.append(r)
            buffers.rings.append(_ring(cx, cy, r, segments))
            if level == 2 and data.is_module(node):
                buffers.labels.append((node.rsplit("/", 1)[-1], cx, cy))
        levels[level] = buffers

    grouped: dict[tuple[int, str], EdgeBuffer] = {}
    for row in data.edges:
        level, kind = int(row["level"]), row["kind"]
        key = (level, kind)
        buffer = grouped.get(key)
        if buffer is None:
            buffer = EdgeBuffer(
                level=level, kind=kind, exactness=row["exactness"],
                # D4: appearance comes from the style table and nowhere else. A
                # stale snapshot restyles every edge, so the canvas cannot look
                # authoritative while the tables are behind the source.
                style=styles.style_for(kind, row["exactness"], stale=data.stale),
            )
            grouped[key] = buffer
        line = bd.bundle_edge(row["src_agg"], row["dst_agg"], data.positions, beta=beta)
        if line is None:
            buffer.unresolved += 1
        else:
            buffer.polylines.append(line)

    banner = styles.stale_banner(data.snapshot, data.stale_reason) if data.stale else None
    return RenderPlan(
        levels=levels,
        edges=[grouped[k] for k in sorted(grouped)],
        banner=banner,
        legend=styles.legend_entries(stale=data.stale),
        snapshot=data.snapshot,
        profile=data.profile,
    )


def lod_for_camera_width(width: float) -> int:
    level = 0
    for lvl, threshold in LOD_THRESHOLDS:
        if width <= threshold:
            level = lvl
    return level


# --------------------------------------------------------------------------
# hover and click — pure, so both are testable without a window
# --------------------------------------------------------------------------


def node_summary(data: MapData, node_id: str) -> str:
    """Tooltip text: the module path plus the counts a reader needs to judge it.

    The `invokes` counts are labelled approximate in the text itself, not only in
    the edge style — a number in a tooltip reads as a fact unless it says
    otherwise, which is the same discipline ADR-002 applies to query results.
    """
    level = data.levels.get(node_id, 2)
    is_module = data.is_module(node_id)

    def fan(kind: str) -> tuple[int, int, int]:
        """in, out, intra. The intra count is shown rather than folded away:
        `src/core` has 0 outbound imports (it is the base layer, importing only
        std/*) and 181 internal ones, and a tooltip reading `out 0` with no
        further detail would make a dense package look inert."""
        into = out = intra = 0
        for row in data.edges:
            if row["kind"] != kind or int(row["level"]) != level:
                continue
            src, dst, weight = row["src_agg"], row["dst_agg"], int(row["weight"])
            if src == node_id and dst == node_id:
                intra += weight
            elif dst == node_id:
                into += weight
            elif src == node_id:
                out += weight
        return into, out, intra

    imports_in, imports_out, imports_intra = fan("imports")
    invokes_in, invokes_out, invokes_intra = fan("invokes")

    if is_module:
        head = f"{node_id}  ({data.n_funcs.get(node_id, 0)} funcs)"
    else:
        members = sum(1 for slug in data.n_funcs if slug.startswith(node_id + "/"))
        funcs = sum(n for slug, n in data.n_funcs.items() if slug.startswith(node_id + "/"))
        head = f"{node_id}/  ({members} modules, {funcs} funcs)"
    return (
        f"{head}\n"
        f"imports  in {imports_in} / out {imports_out} / intra {imports_intra}   (exact)\n"
        f"invokes  in {invokes_in} / out {invokes_out} / intra {invokes_intra}   "
        f"(approximate — source-parsed, not compiler-derived)"
    )


@dataclass(frozen=True)
class EditorTarget:
    kind: str  # "command" | "url"
    value: list[str] | str
    path: str


def editor_target(data: MapData, node_id: str, repo_root: Path = REPO_ROOT,
                  env: dict[str, str] | None = None) -> EditorTarget:
    """Where a click should open. D3 puts in-canvas code out of scope beyond a
    static preview, so click-through hands off to the real editor.

    Precedence is deliberate: an explicit template wins, then $EDITOR, then a
    vscode:// URL as the last resort — the fallback is the guess, so it goes
    last.
    """
    env = os.environ if env is None else env
    relative = f"{node_id}.ail" if data.is_module(node_id) else node_id
    absolute = str((repo_root / relative).resolve())

    template = env.get("MOTOKO_MAP_EDITOR_URL")
    if template:
        return EditorTarget("url", template.format(path=absolute, line=1), absolute)
    editor = env.get("EDITOR")
    if editor:
        return EditorTarget("command", editor.split() + [absolute], absolute)
    return EditorTarget("url", f"vscode://file/{absolute}:1", absolute)


def open_target(target: EditorTarget) -> None:
    if target.kind == "command":
        subprocess.Popen(target.value)  # noqa: S603
        return
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    subprocess.Popen([opener, str(target.value)])  # noqa: S603


# --------------------------------------------------------------------------
# the window
# --------------------------------------------------------------------------


def run(plan: RenderPlan, data: MapData) -> None:
    import numpy as np
    import fastplotlib as fpl

    fig = fpl.Figure(size=(1700, 1050))
    subplot = fig[0, 0]
    graphics: dict[int, list] = {0: [], 1: [], 2: []}
    pick_targets: dict[int, object] = {}

    for level in (0, 1, 2):
        buffers = plan.levels[level]
        if buffers.rings:
            rings = [np.array([(x, y, 0.002 * level) for x, y in r], dtype=np.float32)
                     for r in buffers.rings]
            colour = (0.55, 0.58, 0.66, 0.85) if level < 2 else (0.80, 0.83, 0.90, 0.95)
            graphics[level].append(subplot.add_line_collection(rings, colors=colour, thickness=1.0))
        if buffers.centers:
            # Inherited from the D7 spike, each fact earned by a host round-trip:
            # world-space sizes so the pickable target IS the visible circle, and
            # depth staggered by level so a module wins the pick over the
            # container it sits in.
            pts = np.array([(x, y, 0.01 * level) for x, y in buffers.centers], dtype=np.float32)
            sizes = np.array([2.0 * r for r in buffers.radii], dtype=np.float32)
            scatter = subplot.add_scatter(
                pts, colors=(0.32, 0.37, 0.48, 0.55 if level == 2 else 0.10),
                sizes=sizes, size_space="world",
            )
            # pygfx materials default to pick_write=False and fastplotlib does
            # not set it for scatter, so without this no pointer event ever
            # fires (pygfx/materials/_base.py:161).
            try:
                scatter.world_object.material.pick_write = True
            except Exception:
                pass
            graphics[level].append(scatter)
            pick_targets[level] = scatter

    for buffer in plan.edges:
        if not buffer.polylines:
            continue
        lines = [np.array([(x, y, 0.0) for x, y in line], dtype=np.float32)
                 for line in buffer.polylines]
        graphics[buffer.level].append(
            subplot.add_line_collection(lines, colors=buffer.style.color,
                                        thickness=buffer.style.thickness)
        )

    for text, x, y in plan.levels[2].labels:
        graphics[2].append(subplot.add_text(text, offset=(x, y, 0.05), font_size=9,
                                            face_color=(0.90, 0.92, 0.97, 1.0)))

    hud = subplot.add_text("", offset=(0.0, 1.06, 0.1), font_size=12,
                           face_color=(0.85, 0.88, 0.95, 1.0))
    if plan.banner:
        # D4: a stale snapshot is bannered persistently, in cgq.py's own wording,
        # and every edge is already restyled to match.
        subplot.add_text(plan.banner, offset=(0.0, 1.12, 0.1), font_size=13,
                         face_color=(1.0, 0.70, 0.28, 1.0))

    legend_text = "   ".join(style.legend for style in plan.legend)
    subplot.add_text(legend_text, offset=(0.0, -1.12, 0.1), font_size=9,
                     face_color=(0.72, 0.76, 0.85, 1.0))

    state = {"level": None, "hover": None}

    def apply_lod(level: int) -> None:
        for lvl, items in graphics.items():
            for gfx in items:
                try:
                    gfx.visible = (lvl <= level)
                except Exception:
                    pass

    def node_at(event) -> str | None:
        info = getattr(event, "pick_info", None) or {}
        index = dict(info).get("vertex_index")
        node_ids = plan.levels[state["level"] or 2].node_ids
        if isinstance(index, int) and 0 <= index < len(node_ids):
            return node_ids[index]
        return None

    def on_hover(event) -> None:
        node = node_at(event)
        if node is None or node == state["hover"]:
            return
        state["hover"] = node
        try:
            hud.text = node_summary(data, node)
        except Exception:
            pass

    def on_click(event) -> None:
        node = node_at(event)
        if node is None:
            return
        try:
            open_target(editor_target(data, node))
        except Exception:
            pass

    for target in pick_targets.values():
        try:
            target.add_event_handler(on_hover, "pointer_move")
            target.add_event_handler(on_click, "double_click")
        except Exception:
            pass

    def animate(_fig=None) -> None:
        try:
            level = lod_for_camera_width(float(subplot.camera.width))
        except Exception:
            return
        if level != state["level"]:
            state["level"] = level
            apply_lod(level)

    apply_lod(0)
    fig.add_animations(animate)
    fig.show()
    fpl.loop.run()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--beta", type=float, default=bd.DEFAULT_BETA,
                    help="edge bundling strength: 1 hugs the hierarchy, 0 is straight lines")
    ap.add_argument("--dry-run", action="store_true",
                    help="build the render plan and print stats; imports nothing GPU-bound")
    ns = ap.parse_args(argv)

    data = load_map(ns.out)
    plan = build_render_plan(data, beta=ns.beta)
    if ns.dry_run:
        print(json.dumps(plan.stats(), indent=2, sort_keys=True))
        return 0
    run(plan, data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
