#!/usr/bin/env python3
"""Static heat overlay (project 010, plan task 3.5; ADR-001 D6 view 1).

Renders `layout` circles coloured by per-subject activity counts for ONE trace.
Matplotlib only — **deliberately no fastplotlib dependency**, which is what makes
P3 genuinely parallel with P2 (D6 view 1: "needs no interactive viewer") and
keeps all of P3 container-side under D10.

**The picture and the query cannot disagree**, because they are not two
computations: the totals come from `cgq.named_query("touched", …)` — the exact
function the `q touched` CLI runs — and `validate_overlay.py` then recomputes
them independently and asserts equality.

D4 for the overlay:
  * `unattributed` has no layout node by construction, so it is rendered as an
    explicit off-map swatch carrying its count. It is never omitted — a picture
    that silently drops unattributed records is the failure mode the ADR
    acceptance criterion names.
  * modules with **zero activity** are visually distinct from unattributed *and*
    from low activity: "we looked and nothing happened here" is a different
    statement from "something happened and we do not know where".
  * a stale `layout` snapshot is bannered on the canvas, mirroring `cgq.py`.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT / "query"))

import cgq  # noqa: E402

DEFAULT_OUT = TOOL_ROOT / ".out"

# Deliberately not a continuous ramp all the way to zero: the three states below
# must be tellable apart at a glance, not by squinting at a gradient.
ZERO_FACE = "#1b1d23"
ZERO_EDGE = "#3a3f4b"
UNATTRIBUTED_FACE = "#8a8f99"
UNATTRIBUTED_HATCH = "///"
CONTAINER_EDGE = "#4a5060"


def subject_totals(seed: int, out_dir: Path = DEFAULT_OUT) -> dict[str, int]:
    """Per-subject record counts for one seed, via the SHARED query."""
    cgq.OUT_DIR = out_dir
    sql, _flags = cgq.named_query("touched", [str(seed)])
    rows = cgq.run_sql(sql).get("data", [])
    return {row["subject_id"]: int(row["records"]) for row in rows}


def read_layout(out_dir: Path) -> list[dict]:
    path = out_dir / "layout.csv"
    if not path.exists():
        raise SystemExit(f"missing {path} — run tools/code-graph/layout/build_layout.py")
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def _layout_banner(out_dir: Path) -> str | None:
    """The heat renderer checks layout freshness itself: `activity` is keyed to
    trace files, not to extractions, so it carries no extraction-staleness
    verdict — but the circles it draws over are the layout's."""
    cgq.OUT_DIR = out_dir
    try:
        status = cgq.run_sql("SELECT * FROM extraction_status").get("data", [])
        profile = (status[0].get("profile") if status else "") or "unknown"
        stale, reason, _snapshot = cgq._layout_freshness(status, profile)
    except Exception as exc:
        return f"STALE: layout freshness unverifiable ({exc})"
    return f"STALE: {reason}" if stale else None


def render(seed: int, profile: str, out_dir: Path, dest: Path | None = None) -> dict:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.cm import ScalarMappable
    from matplotlib.colors import Normalize
    from matplotlib.patches import Circle

    layout = read_layout(out_dir)
    totals = subject_totals(seed, out_dir)
    unattributed = totals.get("unattributed", 0)
    mapped = {k: v for k, v in totals.items() if k != "unattributed"}

    geo = {row["node_id"]: (float(row["x"]), float(row["y"]), float(row["radius"])) for row in layout}
    levels: dict[str, int] = {}
    for row in layout:
        node = row["node_id"]
        levels[node] = max(levels.get(node, 0), int(row["level"]))

    orphans = sorted(k for k in mapped if k not in geo)
    peak = max(mapped.values(), default=0)
    norm = Normalize(vmin=0, vmax=peak or 1)
    cmap = plt.get_cmap("inferno")

    fig, ax = plt.subplots(figsize=(12, 12))
    ax.set_aspect("equal")
    ax.set_xlim(-1.08, 1.08)
    ax.set_ylim(-1.14, 1.08)
    ax.axis("off")
    fig.patch.set_facecolor("#0e1014")
    ax.set_facecolor("#0e1014")

    for node, (x, y, r) in sorted(geo.items()):
        if levels.get(node, 2) >= 2 or node in mapped:
            continue
        ax.add_patch(Circle((x, y), r, facecolor="none", edgecolor=CONTAINER_EDGE,
                            linewidth=0.6, alpha=0.7))

    drawn = 0
    for node, (x, y, r) in sorted(geo.items()):
        count = mapped.get(node)
        if count is None and levels.get(node, 2) < 2:
            continue  # container already drawn as context
        if count:
            ax.add_patch(Circle((x, y), r, facecolor=cmap(norm(count)), edgecolor="#ffffff",
                                linewidth=0.5, alpha=0.95))
            drawn += 1
        else:
            ax.add_patch(Circle((x, y), r, facecolor=ZERO_FACE, edgecolor=ZERO_EDGE,
                                linewidth=0.4, alpha=0.9))

    # Unattributed: no node exists to colour, so it gets an explicit swatch. This
    # is the "never dropped" acceptance criterion made visible rather than
    # promised.
    ax.add_patch(Circle((-0.92, -1.03), 0.045, facecolor=UNATTRIBUTED_FACE, edgecolor="#ffffff",
                        linewidth=0.6, hatch=UNATTRIBUTED_HATCH))
    ax.text(-0.85, -1.035, f"unattributed: {unattributed} records (no subject module)",
            color="#d8dbe2", fontsize=9, va="center")
    ax.add_patch(Circle((-0.92, -1.10), 0.045, facecolor=ZERO_FACE, edgecolor=ZERO_EDGE, linewidth=0.6))
    ax.text(-0.85, -1.105, "no activity (looked, nothing happened)", color="#d8dbe2",
            fontsize=9, va="center")

    ax.set_title(f"DST activity heat — profile {profile}, seed {seed}\n"
                 f"{drawn} subjects lit · peak {peak} records · "
                 f"{sum(mapped.values())} attributed + {unattributed} unattributed",
                 color="#e8ebf2", fontsize=12)

    bar = fig.colorbar(ScalarMappable(norm=norm, cmap=cmap), ax=ax, fraction=0.03, pad=0.02)
    bar.set_label("records attributed to subject", color="#d8dbe2")
    bar.ax.yaxis.set_tick_params(color="#d8dbe2")
    plt.setp(plt.getp(bar.ax.axes, "yticklabels"), color="#d8dbe2")

    banner = _layout_banner(out_dir)
    if banner:
        ax.text(0.0, 1.045, banner, color="#ffb347", fontsize=11, ha="center", weight="bold")
    if orphans:
        ax.text(0.0, -1.11, f"{len(orphans)} subject(s) have no layout node: {', '.join(orphans[:3])}"
                            + ("…" if len(orphans) > 3 else ""),
                color="#ffb347", fontsize=8, ha="center")

    dest = dest or (out_dir / "heat" / profile / f"{seed}.svg")
    dest.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(dest, format="svg", facecolor=fig.get_facecolor(), bbox_inches="tight")
    plt.close(fig)

    return {
        "seed": seed,
        "profile": profile,
        "path": str(dest),
        "subjects_lit": drawn,
        "attributed_records": sum(mapped.values()),
        "unattributed_records": unattributed,
        "peak": peak,
        "subjects_without_layout_node": orphans,
        "layout_banner": banner,
        # Echoed so the agreement check in validate_overlay.py has the exact
        # numbers the picture was drawn from.
        "totals": dict(sorted(totals.items())),
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--profile", default="driver_only")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--dest", type=Path, default=None)
    ns = ap.parse_args(argv)
    print(json.dumps(render(ns.seed, ns.profile, ns.out, ns.dest), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
