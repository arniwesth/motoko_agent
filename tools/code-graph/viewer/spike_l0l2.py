#!/usr/bin/env python3
"""The D7 gate spike (010, plan task 2.1). Disposable by design — the findings
outlive it, the code does not.

Renders the full all-profile L0–L2 scene from ``.out/layout.csv`` +
``.out/edges_agg.csv`` as a standalone fastplotlib app (native glfw window, Q5)
and measures itself against the six gate criteria written down *before* it ran.

    1. full L0–L2 scene: all nodes + edges_agg line collections, both kinds in
       visibly distinct styles (D4, via styles.style_for)
    2. sustained pan/zoom >= 30 fps at L2 density
    3. picking: click -> node identity < 100 ms; hover tooltip shows module path
    4. LOD switching on camera scale with no re-upload stall (> 1 dropped-frame
       hitch at a threshold crossing fails)
    5. >= 200 simultaneous L2 labels without dropping below criterion 2
    6. runs end-to-end on the host from .out/ through the shared mount, as a
       standalone app window, launched exactly as install_host.sh printed

**This must be launched via ``install_host.sh``'s printed command on the host.**
A verdict from a hand-built environment does not count (ADR D10).

Modes:
    --dry-run   build the scene and print statistics, importing NOTHING that
                needs a GPU. Runs in the devcontainer; this is how scene
                construction is verified without spending a host round-trip.
    --auto      scripted camera sweep, measures, writes the verdict JSON, exits.
                The D7 gate is graded from this file — a hand-run or partial
                result is not a verdict.
    (default)   interactive window for the manual acceptance walk; real click and
                hover latencies are recorded into the same JSON on exit.

Scale note recorded deliberately: criterion 2 names "~1k module nodes", but this
repo's all profile has 225. ``--stress N`` replicates the scene to reach N nodes
so criterion 2 can be graded at the density it actually names. Stress results are
labelled synthetic and never substituted for the real-scene numbers.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
import sys
import time
import traceback
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import styles  # noqa: E402

VIEWER_DIR = Path(__file__).resolve().parent
TOOL_ROOT = VIEWER_DIR.parent
REPO_ROOT = TOOL_ROOT.parents[1]
DEFAULT_OUT = TOOL_ROOT / ".out"
DEFAULT_REPORT = REPO_ROOT / ".agent" / "projects" / "010_simulation_visualization" / "host-spike-report.json"

# Camera width at which each LOD level takes over. The scene is a unit-radius
# circle, so width 2.0 is "whole map". Precomputed buffers are swapped by
# visibility only — never re-aggregated at render time (D3 hard rule).
LOD_THRESHOLDS = ((0, 2.0), (1, 0.9), (2, 0.35))

RING_SEGMENTS_CONTAINER = 64
RING_SEGMENTS_MODULE = 28
TARGET_FPS = 30.0
PICK_BUDGET_MS = 100.0
MIN_LABELS = 200


# --------------------------------------------------------------------------
# scene construction — deliberately GPU-free so it is testable in the container
# --------------------------------------------------------------------------


@dataclass
class LevelData:
    node_ids: list[str] = field(default_factory=list)
    centers: list[tuple[float, float]] = field(default_factory=list)
    radii: list[float] = field(default_factory=list)
    rings: list[list[tuple[float, float, float]]] = field(default_factory=list)


@dataclass
class EdgeGroup:
    level: int
    kind: str
    exactness: str
    style: styles.EdgeStyle
    segments: list[list[tuple[float, float, float]]] = field(default_factory=list)
    self_loops: int = 0
    unresolved: int = 0


@dataclass
class Scene:
    levels: dict[int, LevelData]
    edge_groups: list[EdgeGroup]
    labels: list[tuple[str, float, float]]
    snapshot: str
    stress_factor: int = 1

    def node_count(self, level: int) -> int:
        return len(self.levels[level].node_ids)

    def stats(self) -> dict:
        return {
            "snapshot": self.snapshot,
            "stress_factor": self.stress_factor,
            "nodes_per_level": {str(lvl): self.node_count(lvl) for lvl in sorted(self.levels)},
            "labels": len(self.labels),
            "edge_groups": [
                {
                    "level": g.level,
                    "kind": g.kind,
                    "exactness": g.exactness,
                    "segments": len(g.segments),
                    "self_loops": g.self_loops,
                    "unresolved_endpoints": g.unresolved,
                    "solid": g.style.is_solid,
                    "legend": g.style.legend,
                }
                for g in self.edge_groups
            ],
        }


def _read(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def _ring(cx: float, cy: float, r: float, segments: int, z: float = 0.0) -> list[tuple[float, float, float]]:
    return [
        (cx + r * math.cos(2 * math.pi * i / segments), cy + r * math.sin(2 * math.pi * i / segments), z)
        for i in range(segments + 1)
    ]


def _self_loop(cx: float, cy: float, r: float) -> list[tuple[float, float, float]]:
    """A self-loop is real data. Drawing nothing would be lying by omission at
    the pixels, so it gets a small visible stub outside the node."""
    return _ring(cx + r * 1.15, cy, r * 0.35, 12, z=0.02)


def build_scene(layout_rows: list[dict], edge_rows: list[dict], stress: int = 0) -> Scene:
    snapshots = {row["snapshot"] for row in layout_rows}
    snapshot = snapshots.pop() if len(snapshots) == 1 else "MIXED"

    geo: dict[str, tuple[float, float, float]] = {}
    per_level: dict[int, list[str]] = {0: [], 1: [], 2: []}
    for row in layout_rows:
        node = row["node_id"]
        geo[node] = (float(row["x"]), float(row["y"]), float(row["radius"]))
        per_level[int(row["level"])].append(node)

    replicas = _replica_offsets(stress, len(per_level[2]))
    factor = len(replicas)

    levels: dict[int, LevelData] = {}
    for level in (0, 1, 2):
        data = LevelData()
        segments = RING_SEGMENTS_MODULE if level == 2 else RING_SEGMENTS_CONTAINER
        for suffix, (ox, oy, scale) in replicas:
            for node in sorted(per_level[level]):
                x, y, r = geo[node]
                cx, cy, cr = ox + x * scale, oy + y * scale, r * scale
                data.node_ids.append(node + suffix)
                data.centers.append((cx, cy))
                data.radii.append(cr)
                data.rings.append(_ring(cx, cy, cr, segments))
        levels[level] = data

    positions = {
        level: {nid: (cx, cy, r) for nid, (cx, cy), r in
                zip(levels[level].node_ids, levels[level].centers, levels[level].radii)}
        for level in (0, 1, 2)
    }

    groups: dict[tuple[int, str], EdgeGroup] = {}
    for row in edge_rows:
        level = int(row["level"])
        kind = row["kind"]
        exactness = row["exactness"]
        key = (level, kind)
        group = groups.get(key)
        if group is None:
            group = EdgeGroup(level=level, kind=kind, exactness=exactness,
                              style=styles.style_for(kind, exactness))
            groups[key] = group
        for suffix, _ in replicas:
            src = positions[level].get(row["src_agg"] + suffix)
            dst = positions[level].get(row["dst_agg"] + suffix)
            if src is None or dst is None:
                group.unresolved += 1
                continue
            if row["src_agg"] == row["dst_agg"]:
                group.self_loops += 1
                group.segments.append(_self_loop(src[0], src[1], src[2]))
            else:
                group.segments.append([(src[0], src[1], 0.0), (dst[0], dst[1], 0.0)])

    # One label per L2 node. levels[2] already spans every replica, so iterating
    # replicas here again would multiply the label count (and the fps criterion
    # that depends on it) by the stress factor.
    labels = [
        (nid.split("#", 1)[0].rsplit("/", 1)[-1], cx, cy)
        for nid, (cx, cy) in zip(levels[2].node_ids, levels[2].centers)
    ]

    return Scene(
        levels=levels,
        edge_groups=[groups[k] for k in sorted(groups)],
        labels=labels,
        snapshot=snapshot,
        stress_factor=factor,
    )


def _replica_offsets(stress: int, real_l2_nodes: int) -> list[tuple[str, tuple[float, float, float]]]:
    """Grid of scene copies needed to reach `stress` L2 nodes. Copies are laid
    out side by side at reduced scale so the whole thing still fits a unit view."""
    if stress <= 0 or real_l2_nodes <= 0 or stress <= real_l2_nodes:
        return [("", (0.0, 0.0, 1.0))]
    copies = math.ceil(stress / real_l2_nodes)
    side = math.ceil(math.sqrt(copies))
    scale = 1.0 / side
    out = []
    for i in range(copies):
        row, col = divmod(i, side)
        ox = (col - (side - 1) / 2) * 2.0 * scale
        oy = (row - (side - 1) / 2) * 2.0 * scale
        out.append((f"#stress{i}" if i else "", (ox, oy, scale)))
    return out


def lod_for_camera_width(width: float) -> int:
    level = 0
    for lvl, threshold in LOD_THRESHOLDS:
        if width <= threshold:
            level = lvl
    return level


def resolve_pick(scene: Scene, level: int, pick_info: dict) -> str | None:
    """Node identity from a pygfx pick_info dict.

    Points and Line pick_info carry ``vertex_index`` (pygfx/objects/_more.py:148)
    and **not** a world position — so an index lookup is both the correct path
    and an exact O(1) one, since the scatter's vertex order is exactly
    ``scene.levels[level].node_ids``. The world-position branch is a fallback for
    renderer-level events that do carry one.
    """
    index = pick_info.get("vertex_index")
    node_ids = scene.levels[level].node_ids
    if isinstance(index, int) and 0 <= index < len(node_ids):
        return node_ids[index]
    pos = pick_info.get("world_position") or pick_info.get("position")
    if pos is not None and len(pos) >= 2:
        return resolve_node(scene, level, float(pos[0]), float(pos[1]))
    return None


def resolve_node(scene: Scene, level: int, x: float, y: float) -> str | None:
    """Point -> node identity. The smallest circle containing the point wins, so
    a click inside a module resolves to the module and not to its container."""
    data = scene.levels[level]
    best: tuple[float, str] | None = None
    for nid, (cx, cy), r in zip(data.node_ids, data.centers, data.radii):
        if (x - cx) ** 2 + (y - cy) ** 2 <= r * r and (best is None or r < best[0]):
            best = (r, nid)
    return best[1] if best else None


# --------------------------------------------------------------------------
# measurement harness
# --------------------------------------------------------------------------


class Measurements:
    def __init__(self) -> None:
        self.frame_dt: list[float] = []
        self.lod_crossings: list[dict] = []
        self.pick_ms: list[float] = []
        self.pick_source: str | None = None
        self.hover_ms: list[float] = []
        self.hover_sample: str | None = None
        self.errors: list[dict] = []

    def note_error(self, where: str) -> None:
        self.errors.append({"where": where, "traceback": traceback.format_exc()})

    def fps(self) -> float | None:
        usable = [dt for dt in self.frame_dt if dt > 0]
        return round(1.0 / statistics.median(usable), 2) if usable else None

    def fps_p5(self) -> float | None:
        """5th-percentile fps — the honest number for "sustained"; a median that
        hides 200 ms hitches is exactly the vibes-grading the gate forbids."""
        usable = sorted((dt for dt in self.frame_dt if dt > 0), reverse=True)
        if not usable:
            return None
        # Round toward the *worse* side: with exactly 5% bad frames, a
        # boundary-rounding index would report the good value and call five
        # half-second stalls "sustained".
        idx = min(len(usable) - 1, max(0, math.ceil(0.05 * len(usable)) - 1))
        return round(1.0 / usable[idx], 2)

    def hitches(self, budget_s: float = 2.0 / 60.0) -> int:
        return sum(1 for c in self.lod_crossings if c["frame_dt"] > budget_s)


def grade(scene: Scene, m: Measurements, windowed: bool, stress_stats: dict | None) -> dict:
    fps = m.fps()
    fps_p5 = m.fps_p5()
    labels = len(scene.labels)
    edge_solid = {(g.kind, g.style.is_solid) for g in scene.edge_groups}
    kinds_distinct = len({(g.kind, g.style.color, g.style.dash) for g in scene.edge_groups
                          if g.level == 2}) >= 2

    def verdict(ok: bool | None) -> str:
        return "pass" if ok is True else ("fail" if ok is False else "not-measured")

    criteria = {
        "1_full_l0_l2_scene": {
            "verdict": verdict(all(scene.node_count(l) > 0 for l in (0, 1, 2))
                               and any(g.segments for g in scene.edge_groups) and kinds_distinct),
            "detail": scene.stats()["nodes_per_level"],
            "kinds_visually_distinct": kinds_distinct,
        },
        "2_pan_zoom_fps": {
            "verdict": verdict(None if fps is None else (fps >= TARGET_FPS and (fps_p5 or 0) >= TARGET_FPS)),
            "median_fps": fps,
            "p5_fps": fps_p5,
            "target": TARGET_FPS,
            "frames": len(m.frame_dt),
        },
        "3_picking_latency": {
            "verdict": verdict(None if not m.pick_ms else max(m.pick_ms) < PICK_BUDGET_MS),
            "max_ms": round(max(m.pick_ms), 3) if m.pick_ms else None,
            "median_ms": round(statistics.median(m.pick_ms), 3) if m.pick_ms else None,
            "samples": len(m.pick_ms),
            "measured": m.pick_source,
            "hover_tooltip_sample": m.hover_sample,
        },
        "4_lod_switch_no_stall": {
            "verdict": verdict(None if not m.lod_crossings else m.hitches() <= 1),
            "crossings": len(m.lod_crossings),
            "hitches_over_two_frames": m.hitches() if m.lod_crossings else None,
            "worst_crossing_ms": round(max((c["frame_dt"] for c in m.lod_crossings), default=0) * 1000, 2)
            if m.lod_crossings else None,
        },
        "5_l2_labels": {
            "verdict": verdict(None if fps is None else (labels >= MIN_LABELS and fps >= TARGET_FPS)),
            "labels_rendered": labels,
            "minimum": MIN_LABELS,
            "note": None if labels >= MIN_LABELS else
            "the all profile has fewer L2 modules than the criterion's label floor; "
            "grade this from the --stress run",
        },
        "6_standalone_window_from_store": {
            "verdict": verdict(windowed),
            "detail": "native glfw window rendering the shared-mount .out/ tables"
            if windowed else "no window opened (dry-run or offscreen)",
        },
    }
    passed = all(c["verdict"] == "pass" for c in criteria.values())
    return {
        "criteria": criteria,
        "overall": "pass" if passed else "fail",
        "unmeasured": [k for k, c in criteria.items() if c["verdict"] == "not-measured"],
        "stress_run": stress_stats,
        "errors": m.errors,
    }


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------


def run_window(scene: Scene, auto: bool, m: Measurements, duration: float,
               on_complete=None) -> bool:
    """Build the fastplotlib scene and drive it. Every optional feature is
    guarded: a missing API records an error and keeps going, because a report
    that says exactly which call failed is worth far more than a traceback."""
    import numpy as np
    import fastplotlib as fpl

    fig = fpl.Figure(size=(1600, 1000))
    subplot = fig[0, 0]
    graphics: dict[int, list] = {0: [], 1: [], 2: []}
    # Pick targets are the scatters only: their vertex order is exactly
    # scene.levels[level].node_ids, which is what makes pick_info["vertex_index"]
    # an exact identity lookup rather than a hit test.
    pick_targets: dict[int, object] = {}

    for level in (0, 1, 2):
        data = scene.levels[level]
        if data.rings:
            rings = [np.array(r, dtype=np.float32) for r in data.rings]
            colour = (0.55, 0.58, 0.66, 0.85) if level < 2 else (0.80, 0.83, 0.90, 0.95)
            graphics[level].append(subplot.add_line_collection(rings, colors=colour, thickness=1.0))
        if data.centers:
            pts = np.array([(x, y, -0.01) for x, y in data.centers], dtype=np.float32)
            scatter = subplot.add_scatter(pts, colors=(0.35, 0.40, 0.50, 0.9), sizes=6)
            graphics[level].append(scatter)
            pick_targets[level] = scatter

    for group in scene.edge_groups:
        if not group.segments:
            continue
        segs = [np.array(s, dtype=np.float32) for s in group.segments]
        try:
            gfx = subplot.add_line_collection(segs, colors=group.style.color,
                                              thickness=group.style.thickness)
        except Exception:
            m.note_error(f"add_line_collection(level={group.level}, kind={group.kind})")
            continue
        graphics[group.level].append(gfx)

    label_graphics = []
    for text, x, y in scene.labels:
        try:
            label_graphics.append(subplot.add_text(text, offset=(x, y, 0.05), font_size=9,
                                                   face_color=(0.9, 0.9, 0.95, 1.0)))
        except Exception:
            m.note_error("add_text")
            break
    graphics[2].extend(label_graphics)

    state = {"level": None, "last": None, "start": None, "frames": 0, "finished": False}

    def apply_lod(level: int) -> None:
        for lvl, items in graphics.items():
            for gfx in items:
                try:
                    gfx.visible = (lvl <= level)
                except Exception:
                    m.note_error("set graphic.visible")

    def pick_at(x: float, y: float) -> tuple[str | None, float]:
        started = time.perf_counter()
        node = resolve_node(scene, state["level"] or 2, x, y)
        return node, (time.perf_counter() - started) * 1000.0

    def on_pointer(event) -> None:
        try:
            started = time.perf_counter()
            info = getattr(event, "pick_info", None) or {}
            node = resolve_pick(scene, state["level"] or 2, dict(info))
            elapsed_ms = (time.perf_counter() - started) * 1000.0
            if node is None:
                return
            m.pick_ms.append(elapsed_ms)
            m.pick_source = "real pointer event (pick_info vertex_index)"
            # Criterion 3's second half: the hover tooltip must show the module
            # PATH, not an index — so the recorded sample is the full slug.
            m.hover_sample = node
        except Exception:
            m.note_error("pointer handler")

    for level, target in sorted(pick_targets.items()):
        try:
            target.add_event_handler(on_pointer, "pointer_down")
            target.add_event_handler(on_pointer, "pointer_move")
        except Exception:
            m.note_error(f"add_event_handler(level={level})")
            break

    def animate(_fig=None) -> None:
        now = time.perf_counter()
        if state["start"] is None:
            state["start"] = now
            state["last"] = now
            return
        dt = now - state["last"]
        state["last"] = now
        m.frame_dt.append(dt)
        state["frames"] += 1
        elapsed = now - state["start"]

        if auto:
            # Scripted sweep: whole map -> deep zoom -> back, with a lateral pan,
            # crossing every LOD threshold in both directions.
            phase = (elapsed / duration) * 2.0
            t = phase if phase <= 1.0 else 2.0 - phase
            width = 2.0 * math.exp(math.log(0.15 / 2.0) * t)
            try:
                subplot.camera.width = width
                cam = subplot.camera.local
                cam.position = (0.25 * math.sin(elapsed * 1.5), 0.15 * math.cos(elapsed * 1.1), cam.position[2])
            except Exception:
                m.note_error("camera drive")
        try:
            width = float(subplot.camera.width)
        except Exception:
            width = 2.0
        level = lod_for_camera_width(width)
        if level != state["level"]:
            if state["level"] is not None:
                m.lod_crossings.append({"from": state["level"], "to": level,
                                        "camera_width": round(width, 5), "frame_dt": dt})
            state["level"] = level
            apply_lod(level)

        if auto and elapsed >= duration:
            if not state["finished"]:
                state["finished"] = True
                if not m.pick_ms:
                    # No human to click. Measure the half we own — identity
                    # resolution — and label it so nobody reads it as an event
                    # round-trip. The interactive run supplies the real number.
                    for i in range(50):
                        ang = 2 * math.pi * i / 50
                        _, ms = pick_at(0.4 * math.cos(ang), 0.4 * math.sin(ang))
                        m.pick_ms.append(ms)
                    m.pick_source = "synthetic: identity resolution only (no event round-trip)"
                # WRITE THE REPORT BEFORE ATTEMPTING SHUTDOWN. Closing a figure
                # is not guaranteed to stop the event loop, and a hang after a
                # complete measurement would throw away the whole run — the one
                # outcome an expensive host round-trip cannot afford.
                if on_complete is not None:
                    try:
                        on_complete()
                    except Exception:
                        m.note_error("on_complete report write")
            # Belt and braces, retried each frame: close the window, then stop
            # the loop. Either alone has been known to leave the other running.
            for label, closer in (("figure close", fig.close),
                                  ("canvas close", getattr(fig.canvas, "close", lambda: None)),
                                  ("loop stop", getattr(fpl.loop, "stop", lambda: None))):
                try:
                    closer()
                except Exception:
                    m.note_error(label)

    apply_lod(0)
    try:
        fig.add_animations(animate)
    except Exception:
        m.note_error("add_animations")

    fig.show()
    try:
        fpl.loop.run()
    except Exception:
        m.note_error("event loop")
        return False
    return True


# --------------------------------------------------------------------------
# cli
# --------------------------------------------------------------------------


def load_scene(out_dir: Path, stress: int) -> Scene:
    layout_path = out_dir / "layout.csv"
    edges_path = out_dir / "edges_agg.csv"
    for path in (layout_path, edges_path):
        if not path.exists():
            raise SystemExit(
                f"missing {path}. Generate it CONTAINER-side (no GPU needed):\n"
                f"  tools/code-graph/extract.sh --profile=all"
            )
    return build_scene(_read(layout_path), _read(edges_path), stress=stress)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    ap.add_argument("--auto", action="store_true", help="scripted measurement run; writes the verdict JSON and exits")
    ap.add_argument("--dry-run", action="store_true", help="build the scene and print stats; imports nothing GPU-bound")
    ap.add_argument("--stress", type=int, default=0, help="replicate the scene to reach N L2 nodes (synthetic)")
    ap.add_argument("--duration", type=float, default=20.0, help="--auto sweep length in seconds")
    ns = ap.parse_args(argv)

    scene = load_scene(ns.out, ns.stress)

    if ns.dry_run:
        print(json.dumps(scene.stats(), indent=2, sort_keys=True))
        return 0

    m = Measurements()
    windowed = False

    def write_report(is_windowed: bool) -> dict:
        report = {
            "stage": "d7-spike",
            "mode": "auto" if ns.auto else "interactive",
            "scene": scene.stats(),
            "gate": grade(scene, m, is_windowed, None),
            "launched_via": "install_host.sh printed command (assert this yourself — "
                            "a verdict from a hand-built env is invalid, ADR D10)",
        }
        ns.report.parent.mkdir(parents=True, exist_ok=True)
        ns.report.write_text(json.dumps(report, indent=2, sort_keys=True))
        return report

    try:
        # The in-loop callback writes a complete report the moment measurement
        # finishes, so a shutdown that hangs costs a Ctrl-C rather than the run.
        windowed = run_window(scene, ns.auto, m, ns.duration, on_complete=lambda: write_report(True))
    except Exception:
        m.note_error("run_window")

    report = write_report(windowed)
    print(json.dumps(report["gate"], indent=2, sort_keys=True))
    print(f"\nfull report: {ns.report}", file=sys.stderr)
    return 0 if report["gate"]["overall"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
