"""D4 honesty as a style table (ADR-001 010, D4 / plan task 2.2).

ADR-002's discipline says approximate results are labelled, never laundered into
facts. D4 extends that to pixels: a map that draws an approximate edge in the
exact style is lying at a glance, which is worse than lying in a table.

The mechanism is deliberately **one function with unit tests**, not a convention
a reviewer has to police: ``style_for(kind, exactness, stale, incomplete)``. A
render path that draws ``invokes`` like ``imports`` fails a test, not a review
comment.

Pure stdlib on purpose — no GPU, no fastplotlib, no numpy — so the container can
test it (D10: the container is not the execution environment, but it is where
review happens) and so ``overlay/render_heat.py`` can share it without inheriting
viewer dependencies.
"""

from __future__ import annotations

from dataclasses import dataclass, replace

RGBA = tuple[float, float, float, float]

# Hue carries *kind*; everything else carries *epistemic status*. Keeping those
# two axes separate is what makes "approximate" legible at a glance without
# needing a legend for every combination.
KIND_HUE: dict[str, tuple[float, float, float]] = {
    "imports": (0.20, 0.45, 0.85),
    "invokes": (0.90, 0.55, 0.15),
}
UNKNOWN_GREY = (0.62, 0.62, 0.64)

VALID_EXACTNESS = ("exact", "approximate")


@dataclass(frozen=True)
class EdgeStyle:
    """A drawable edge style. ``dash`` is a pattern in line-width units; the
    empty tuple means solid. ``legend`` is the text the viewer must show — an
    unlabelled distinction is not honesty, it is decoration."""

    color: RGBA
    dash: tuple[int, ...]
    thickness: float
    legend: str

    @property
    def is_solid(self) -> bool:
        return self.dash == ()


def _blend(base: tuple[float, float, float], toward: tuple[float, float, float], amount: float
           ) -> tuple[float, float, float]:
    return tuple(round(b + (t - b) * amount, 6) for b, t in zip(base, toward))  # type: ignore[return-value]


def _desaturate(rgb: tuple[float, float, float], amount: float) -> tuple[float, float, float]:
    """Pull a colour toward its own luminance. Used for `approximate` and again
    for `stale`, so the two compose visibly instead of cancelling."""
    lum = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    return tuple(round(c + (lum - c) * amount, 6) for c in rgb)  # type: ignore[return-value]


def style_for(kind: str, exactness: str, stale: bool = False, incomplete: bool = False) -> EdgeStyle:
    """The single D4 decision point.

    ``incomplete=True`` wins over everything: ``ailang-graph`` says agents must
    treat ``incomplete`` as *unknown*, never as *no*, so the edge renders in a
    distinct unknown treatment and is **never** dropped or drawn blank.
    """
    if kind not in KIND_HUE:
        raise ValueError(f"unknown edge kind {kind!r}; expected one of {sorted(KIND_HUE)}")
    if exactness not in VALID_EXACTNESS:
        raise ValueError(f"unknown exactness {exactness!r}; expected one of {VALID_EXACTNESS}")

    if incomplete:
        # Unknown collapses *exactness* — "we don't know" outranks how well we
        # would have known — but it must NOT collapse *kind*: an unresolved
        # `invokes` row is still an invokes question, and greying both kinds into
        # one swatch would discard a fact we do have. Grey carries the doubt; a
        # 25% tint carries the kind.
        style = EdgeStyle(
            color=_blend(UNKNOWN_GREY, KIND_HUE[kind], 0.25) + (0.90,),
            dash=(1, 3),
            thickness=1.6,
            legend=f"{kind}: unknown (typed extraction incomplete — not 'no edge')",
        )
    elif exactness == "exact":
        style = EdgeStyle(
            color=KIND_HUE[kind] + (0.95,),
            dash=(),
            thickness=2.0,
            legend=f"{kind}: exact",
        )
    else:
        style = EdgeStyle(
            color=_desaturate(KIND_HUE[kind], 0.45) + (0.70,),
            dash=(6, 4),
            thickness=1.2,
            legend=f"{kind}: approximate (source-parsed, not compiler-derived)",
        )

    if stale:
        rgb = style.color[:3]
        style = replace(
            style,
            color=_desaturate(rgb, 0.55) + (round(style.color[3] * 0.6, 6),),
            thickness=round(style.thickness * 0.8, 6),
            legend=style.legend + " — STALE snapshot",
        )
    return style


def legend_entries(stale: bool = False) -> list[EdgeStyle]:
    """Everything the canvas can draw, in a fixed order, for an on-canvas key."""
    entries = []
    for kind in sorted(KIND_HUE):
        for exactness in VALID_EXACTNESS:
            entries.append(style_for(kind, exactness, stale=stale))
        entries.append(style_for(kind, "exact", stale=stale, incomplete=True))
    return entries


def stale_banner(snapshot: str | None, reason: str | None) -> str:
    """Mirrors ``cgq.py``'s banner text so the canvas and the CLI say the same
    thing about the same condition."""
    return f"STALE: {reason or 'layout snapshot does not match the current extraction'}" + (
        f" (layout snapshot {snapshot[:12]}…)" if snapshot else ""
    )
