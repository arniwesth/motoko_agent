"""Hierarchical edge bundling along the containment tree (010, task 2.2; D3).

D3 requires cross-hierarchy edges to be bundled along the containment tree, and
it requires that **nothing is aggregated at render time**. Both are satisfied the
same way: bundle control points are a pure function of the layout tree, so every
polyline is computed once during the viewer's load step and the render loop only
ever swaps precomputed buffers.

The method is Holten's: an edge u→v is routed through the path up the containment
tree from u to LCA(u, v) and back down to v, then relaxed toward the straight
line by a strength β and smoothed with a clamped cubic B-spline. β = 1 is fully
bundled (every edge hugs the hierarchy), β = 0 is a straight line; the curve
passes through the endpoints and only *near* the interior control points, which
is what makes parallel edges gather into visible trunks.

Pure stdlib — no GPU, no numpy — so all of it is testable in the container, where
D10 says the viewer cannot run.
"""

from __future__ import annotations

import math

Point = tuple[float, float]

# Chosen so cross-package edges bundle visibly without hiding which two modules
# an edge actually connects. Exposed as an argument everywhere so the viewer can
# offer a slider later without this constant becoming a hidden default.
DEFAULT_BETA = 0.85
DEFAULT_SAMPLES = 16
ROOT = ""


def parent_of(node_id: str) -> str:
    """Containment parent. The root is the empty string and is a real node in
    the tree — an edge between two top-level directories legitimately routes
    through it."""
    return node_id.rsplit("/", 1)[0] if "/" in node_id else ROOT


def lca(a: str, b: str) -> str:
    """Lowest common ancestor of two path-shaped node ids."""
    if a == b:
        return a
    sa, sb = a.split("/"), b.split("/")
    common: list[str] = []
    for x, y in zip(sa, sb):
        if x != y:
            break
        common.append(x)
    return "/".join(common)


def control_path(u: str, v: str) -> list[str]:
    """Node ids from u up to LCA(u, v) and back down to v, inclusive."""
    meet = lca(u, v)
    up: list[str] = []
    node = u
    while node != meet and node != ROOT:
        up.append(node)
        node = parent_of(node)
    up.append(meet)

    down: list[str] = []
    node = v
    while node != meet and node != ROOT:
        down.append(node)
        node = parent_of(node)
    return up + list(reversed(down))


def straighten(points: list[Point], beta: float) -> list[Point]:
    """Relax control points toward the straight line between the endpoints.

    Without this every edge would be pinned to the hierarchy and the map would
    read as a tree rather than as a graph over a tree.
    """
    if len(points) < 3 or beta >= 1.0:
        return list(points)
    first, last = points[0], points[-1]
    n = len(points) - 1
    out: list[Point] = []
    for i, (px, py) in enumerate(points):
        t = i / n
        sx = first[0] + t * (last[0] - first[0])
        sy = first[1] + t * (last[1] - first[1])
        out.append((beta * px + (1 - beta) * sx, beta * py + (1 - beta) * sy))
    return out


def bspline(points: list[Point], samples: int = DEFAULT_SAMPLES) -> list[Point]:
    """Clamped uniform cubic B-spline through ``points``.

    Endpoints are tripled so the curve starts exactly at the first control point
    and ends exactly at the last — an edge that visibly missed its own endpoints
    would be a lie about which modules it connects.
    """
    if len(points) < 2:
        return list(points)
    if len(points) == 2:
        return list(points)

    control = [points[0]] * 2 + list(points) + [points[-1]] * 2
    out: list[Point] = []
    windows = len(control) - 3
    for w in range(windows):
        p0, p1, p2, p3 = control[w:w + 4]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            b0 = (1 - 3 * t + 3 * t2 - t3) / 6.0
            b1 = (4 - 6 * t2 + 3 * t3) / 6.0
            b2 = (1 + 3 * t + 3 * t2 - 3 * t3) / 6.0
            b3 = t3 / 6.0
            out.append((
                b0 * p0[0] + b1 * p1[0] + b2 * p2[0] + b3 * p3[0],
                b0 * p0[1] + b1 * p1[1] + b2 * p2[1] + b3 * p3[1],
            ))
    # Pin both endpoints exactly. The clamped basis already evaluates to them
    # analytically, but (1/6 + 4/6 + 1/6)·P accumulates ~1e-16 of rounding — and
    # "the curve starts at its endpoint" is a claim worth making exactly true
    # rather than nearly true, so callers can compare identity without a
    # tolerance.
    out[0] = points[0]
    out.append(points[-1])
    return out


def bundle_edge(
    src: str,
    dst: str,
    positions: dict[str, Point],
    beta: float = DEFAULT_BETA,
    samples: int = DEFAULT_SAMPLES,
) -> list[Point] | None:
    """Bundled polyline for one edge, or None if an endpoint has no position.

    Returning None rather than guessing keeps the "unresolved endpoint" case
    countable by the caller — an edge silently dropped is exactly the omission
    D4 says the map must not commit.
    """
    if src not in positions or dst not in positions:
        return None
    if src == dst:
        return self_loop(positions[src], samples=samples)
    path = control_path(src, dst)
    # The root is a real routing node at the origin. Any OTHER missing ancestor
    # is skipped rather than defaulted: a control point invented at (0, 0) would
    # drag the curve across the map. Endpoints are already known present, so the
    # edge still connects the two modules it claims to.
    points: list[Point] = []
    for node in path:
        if node == ROOT:
            points.append((0.0, 0.0))
        elif node in positions:
            points.append(positions[node])
    if len(points) < 2:
        return None
    return bspline(straighten(points, beta), samples=samples)


def self_loop(centre: Point, radius: float = 0.0, samples: int = DEFAULT_SAMPLES) -> list[Point]:
    """A self-edge is real data; drawing nothing would be lying by omission at
    the pixels. Rendered as a small closed loop beside the node."""
    r = radius or 0.02
    cx, cy = centre[0] + r * 1.2, centre[1]
    return [
        (cx + r * math.cos(2 * math.pi * i / samples), cy + r * math.sin(2 * math.pi * i / samples))
        for i in range(samples + 1)
    ]


def bundle_all(
    edges: list[tuple[str, str]],
    positions: dict[str, Point],
    beta: float = DEFAULT_BETA,
    samples: int = DEFAULT_SAMPLES,
    self_loop_radius: dict[str, float] | None = None,
) -> tuple[list[list[Point]], int]:
    """Bundle a whole edge set at load time. Returns (polylines, unresolved)."""
    polylines: list[list[Point]] = []
    unresolved = 0
    for src, dst in edges:
        if src == dst and src in positions:
            r = (self_loop_radius or {}).get(src, 0.0)
            polylines.append(self_loop(positions[src], radius=r, samples=samples))
            continue
        line = bundle_edge(src, dst, positions, beta=beta, samples=samples)
        if line is None:
            unresolved += 1
        else:
            polylines.append(line)
    return polylines, unresolved
