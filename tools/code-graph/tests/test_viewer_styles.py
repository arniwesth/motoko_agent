"""D4 honesty, checked as code (010, plan Validation §5.4).

These run in the container with no GPU, which is the point: D10 says the
container is not the execution environment, but it is where the honesty rules
have to be reviewable. Golden images only ever join this if the opportunistic
lavapipe extra lands — they are never the gate.

The load-bearing assertion is **pairwise distinctness**: exact, approximate and
unknown must differ from each other for every kind, and a task that draws
`invokes` like `imports` must fail here rather than survive to a review comment.
"""

from __future__ import annotations

import itertools
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "viewer"))

import styles  # noqa: E402


def _visual_signature(style: styles.EdgeStyle) -> tuple:
    """Everything a viewer actually draws with. Two styles that share this are
    indistinguishable on the canvas no matter what their legends claim."""
    return (style.color, style.dash, style.thickness)


ALL_KINDS = sorted(styles.KIND_HUE)


def test_exact_is_solid_and_approximate_is_not() -> None:
    for kind in ALL_KINDS:
        assert styles.style_for(kind, "exact").is_solid
        assert not styles.style_for(kind, "approximate").is_solid


def test_exact_approximate_unknown_are_pairwise_distinct_per_kind() -> None:
    for kind in ALL_KINDS:
        variants = {
            "exact": styles.style_for(kind, "exact"),
            "approximate": styles.style_for(kind, "approximate"),
            "unknown": styles.style_for(kind, "exact", incomplete=True),
        }
        for (a_name, a), (b_name, b) in itertools.combinations(variants.items(), 2):
            assert _visual_signature(a) != _visual_signature(b), (
                f"{kind}: {a_name} and {b_name} render identically"
            )


def test_kinds_are_distinguishable_at_equal_exactness() -> None:
    for exactness in styles.VALID_EXACTNESS:
        signatures = {kind: _visual_signature(styles.style_for(kind, exactness)) for kind in ALL_KINDS}
        assert len(set(signatures.values())) == len(signatures), (
            f"kinds collide at exactness={exactness}: {signatures}"
        )


def test_incomplete_renders_as_unknown_never_blank_and_never_dropped() -> None:
    for kind in ALL_KINDS:
        for exactness in styles.VALID_EXACTNESS:
            style = styles.style_for(kind, exactness, incomplete=True)
            assert style.color[3] > 0.0, "unknown must not be transparent"
            assert style.thickness > 0.0, "unknown must not be zero-width"
            assert "unknown" in style.legend.lower()
            # An incomplete edge must not be mistakable for a known answer.
            assert _visual_signature(style) != _visual_signature(styles.style_for(kind, exactness))


def test_incomplete_collapses_exactness_but_not_kind() -> None:
    # `incomplete` means "we do not know", which outranks any exactness label the
    # row happens to carry — treating incomplete as 'no' is the documented trap.
    # But kind is still *known* when completeness is not, so greying the two
    # kinds into one swatch would discard a fact we actually have.
    for kind in ALL_KINDS:
        a = styles.style_for(kind, "exact", incomplete=True)
        b = styles.style_for(kind, "approximate", incomplete=True)
        assert _visual_signature(a) == _visual_signature(b)
    unknown_by_kind = {k: _visual_signature(styles.style_for(k, "exact", incomplete=True)) for k in ALL_KINDS}
    assert len(set(unknown_by_kind.values())) == len(unknown_by_kind)


def test_stale_is_visible_and_composes_with_every_other_state() -> None:
    for kind in ALL_KINDS:
        for exactness in styles.VALID_EXACTNESS:
            for incomplete in (False, True):
                fresh = styles.style_for(kind, exactness, stale=False, incomplete=incomplete)
                stale = styles.style_for(kind, exactness, stale=True, incomplete=incomplete)
                assert _visual_signature(fresh) != _visual_signature(stale)
                assert "STALE" in stale.legend


def test_stale_does_not_erase_the_exact_approximate_distinction() -> None:
    # Regression guard: a stale treatment that desaturates everything to the same
    # grey would silently destroy D4 exactly when the map is least trustworthy.
    for kind in ALL_KINDS:
        exact = styles.style_for(kind, "exact", stale=True)
        approx = styles.style_for(kind, "approximate", stale=True)
        assert _visual_signature(exact) != _visual_signature(approx)


def test_every_style_carries_a_legend() -> None:
    for style in styles.legend_entries() + styles.legend_entries(stale=True):
        assert style.legend.strip(), "a distinction with no legend is decoration, not honesty"


def test_legend_covers_every_renderable_combination() -> None:
    entries = styles.legend_entries()
    assert len(entries) == len(ALL_KINDS) * (len(styles.VALID_EXACTNESS) + 1)
    assert len({_visual_signature(s) for s in entries}) == len(entries)


def test_unknown_kind_or_exactness_is_refused_not_guessed() -> None:
    with pytest.raises(ValueError):
        styles.style_for("effect_edges", "exact")
    with pytest.raises(ValueError):
        styles.style_for("imports", "probably")


def test_stale_banner_mirrors_cgq_wording() -> None:
    assert styles.stale_banner(None, None).startswith("STALE: ")
    assert "abc123" in styles.stale_banner("abc123def456789", "layout snapshot does not match")
