#!/usr/bin/env python3
"""Deterministic containment layout for the ailang-graph store (project 010, P1).

Emits two generated tables beside the existing CSVs in ``tools/code-graph/.out/``:

    layout(node_id, level, x, y, radius, snapshot)
    edges_agg(level, src_agg, dst_agg, kind, weight, exactness)

Implements ADR-001 (010) D1/D2/D3/D4 as pinned by
``PLAN-map-and-overlay-p1-p3.md`` tasks 1.1 and 1.2:

* packing runs over the **full directory tree** (every directory is a
  containment circle); LOD levels are **path-prefix classes** — L0 is the first
  path segment, L1 the two-segment prefix, L2 the module itself. A module
  shallower than a level's prefix depth is its own aggregate at that level.
  Directories deeper than two segments are packing containers only: they get
  ``layout`` rows at level 2 but never appear in ``edges_agg``.
* area = ``modules.n_funcs`` (Q4), floored at 1 so empty modules stay visible.
* sibling order = ascending ``sha256(node_path)``; no RNG anywhere; every
  collection is sorted before iteration; coordinates are emitted with fixed
  9-decimal quantization so byte-identity is well defined.
* the builder **self-validates**: ``validate_layout`` runs before anything is
  written, so no artifact that fails its validator ever lands.

Run standalone (fast, no re-extraction) or via ``extract.sh`` (task 1.5).
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import sys
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = TOOL_ROOT / ".out"

# Bump when the packing algorithm or the level mapping changes on purpose: the
# snapshot key folds it in, so a deliberate change declares itself as staleness
# instead of silently producing a different picture under the same key.
LAYOUT_VERSION = 1

# Geometry constants. SEP separates siblings (each child is inflated by this
# fraction while packing, then restored), PAD gives every parent an inner ring
# so containment reads at a glance. Both are pure constants: no tuning per run.
SEP = 0.06
PAD = 0.04

QUANT = 9
_QUANT_ZERO = "0." + "0" * QUANT

EDGE_KINDS = (
    # (kind, exactness) — pinned by task 1.2. `imports` is module-level exact;
    # `invokes` is source-parsed and therefore approximate, and it exists in P1
    # precisely so D4 has a real target in P2.
    ("imports", "exact"),
    ("invokes", "approximate"),
)


# --------------------------------------------------------------------------
# circle packing (deterministic port of d3-hierarchy's packSiblings/enclose,
# with the randomized shuffle removed — sibling order is already the sha256
# order, which is what makes the result reproducible)
# --------------------------------------------------------------------------


def _place(b: dict, a: dict, c: dict) -> None:
    dx = b["x"] - a["x"]
    dy = b["y"] - a["y"]
    d2 = dx * dx + dy * dy
    if d2:
        a2 = a["r"] + c["r"]
        a2 *= a2
        b2 = b["r"] + c["r"]
        b2 *= b2
        if a2 > b2:
            x = (d2 + b2 - a2) / (2 * d2)
            y = math.sqrt(max(0.0, b2 / d2 - x * x))
            c["x"] = b["x"] - x * dx - y * dy
            c["y"] = b["y"] - x * dy + y * dx
        else:
            x = (d2 + a2 - b2) / (2 * d2)
            y = math.sqrt(max(0.0, a2 / d2 - x * x))
            c["x"] = a["x"] + x * dx - y * dy
            c["y"] = a["y"] + x * dy + y * dx
    else:
        c["x"] = a["x"] + c["r"]
        c["y"] = a["y"]


def _intersects(a: dict, b: dict) -> bool:
    dr = a["r"] + b["r"] - 1e-6
    dx = b["x"] - a["x"]
    dy = b["y"] - a["y"]
    return dr > 0 and dr * dr > dx * dx + dy * dy


def _score(node: dict) -> float:
    a = node["_"]
    b = node["next"]["_"]
    ab = a["r"] + b["r"]
    dx = (a["x"] * b["r"] + b["x"] * a["r"]) / ab
    dy = (a["y"] * b["r"] + b["y"] * a["r"]) / ab
    return dx * dx + dy * dy


def _encloses_not(a: dict, b: dict) -> bool:
    dr = a["r"] - b["r"]
    dx = b["x"] - a["x"]
    dy = b["y"] - a["y"]
    return dr < 0 or dr * dr < dx * dx + dy * dy


def _encloses_weak(a: dict, b: dict) -> bool:
    dr = a["r"] - b["r"] + max(a["r"], b["r"], 1.0) * 1e-9
    dx = b["x"] - a["x"]
    dy = b["y"] - a["y"]
    return dr > 0 and dr * dr > dx * dx + dy * dy


def _encloses_weak_all(a: dict, basis: list) -> bool:
    return all(_encloses_weak(a, b) for b in basis)


def _enclose_basis1(a: dict) -> dict:
    return {"x": a["x"], "y": a["y"], "r": a["r"]}


def _enclose_basis2(a: dict, b: dict) -> dict:
    x1, y1, r1 = a["x"], a["y"], a["r"]
    x2, y2, r2 = b["x"], b["y"], b["r"]
    x21, y21, r21 = x2 - x1, y2 - y1, r2 - r1
    ell = math.sqrt(x21 * x21 + y21 * y21)
    return {
        "x": (x1 + x2 + x21 / ell * r21) / 2,
        "y": (y1 + y2 + y21 / ell * r21) / 2,
        "r": (ell + r1 + r2) / 2,
    }


def _enclose_basis3(a: dict, b: dict, c: dict) -> dict:
    x1, y1, r1 = a["x"], a["y"], a["r"]
    x2, y2, r2 = b["x"], b["y"], b["r"]
    x3, y3, r3 = c["x"], c["y"], c["r"]
    a2 = x1 - x2
    a3 = x1 - x3
    b2 = y1 - y2
    b3 = y1 - y3
    c2 = r2 - r1
    c3 = r3 - r1
    d1 = x1 * x1 + y1 * y1 - r1 * r1
    d2 = d1 - x2 * x2 - y2 * y2 + r2 * r2
    d3 = d1 - x3 * x3 - y3 * y3 + r3 * r3
    ab = a3 * b2 - a2 * b3
    xa = (b2 * d3 - b3 * d2) / (ab * 2) - x1
    xb = (b3 * c2 - b2 * c3) / ab
    ya = (a3 * d2 - a2 * d3) / (ab * 2) - y1
    yb = (a2 * c3 - a3 * c2) / ab
    aq = xb * xb + yb * yb - 1
    bq = 2 * (r1 + xa * xb + ya * yb)
    cq = xa * xa + ya * ya - r1 * r1
    r = -((bq + math.sqrt(max(0.0, bq * bq - 4 * aq * cq))) / (2 * aq) if abs(aq) > 1e-6 else cq / bq)
    return {"x": x1 + xa + xb * r, "y": y1 + ya + yb * r, "r": r}


def _enclose_basis(basis: list) -> dict:
    if len(basis) == 1:
        return _enclose_basis1(basis[0])
    if len(basis) == 2:
        return _enclose_basis2(basis[0], basis[1])
    return _enclose_basis3(basis[0], basis[1], basis[2])


def _extend_basis(basis: list, p: dict) -> list:
    if _encloses_weak_all(p, basis):
        return [p]
    for b in basis:
        if _encloses_not(p, b) and _encloses_weak_all(_enclose_basis2(b, p), basis):
            return [b, p]
    for i in range(len(basis) - 1):
        for j in range(i + 1, len(basis)):
            bi, bj = basis[i], basis[j]
            if (
                _encloses_not(_enclose_basis2(bi, bj), p)
                and _encloses_not(_enclose_basis2(bi, p), bj)
                and _encloses_not(_enclose_basis2(bj, p), bi)
                and _encloses_weak_all(_enclose_basis3(bi, bj, p), basis)
            ):
                return [bi, bj, p]
    raise AssertionError("enclose: no basis found (numeric degeneracy)")


def enclose(circles: list) -> dict | None:
    """Smallest enclosing circle. Deterministic Welzl (no shuffle)."""
    i = 0
    n = len(circles)
    basis: list = []
    e: dict | None = None
    while i < n:
        p = circles[i]
        if e is not None and _encloses_weak(e, p):
            i += 1
        else:
            basis = _extend_basis(basis, p)
            e = _enclose_basis(basis)
            i = 0
    return e


def pack_siblings(circles: list) -> float:
    """Place ``circles`` (dicts carrying ``r``) around the origin; return the
    enclosing radius. Mutates each circle's ``x``/``y``. Order-dependent and
    therefore deterministic for a fixed input order."""
    n = len(circles)
    if n == 0:
        return 0.0
    for c in circles:
        c["x"] = 0.0
        c["y"] = 0.0
    a = circles[0]
    if n == 1:
        return a["r"]
    b = circles[1]
    a["x"] = -b["r"]
    b["x"] = a["r"]
    b["y"] = 0.0
    if n == 2:
        return a["r"] + b["r"]
    c = circles[2]
    _place(b, a, c)

    na = {"_": a}
    nb = {"_": b}
    nc = {"_": c}
    na["next"] = nc["previous"] = nb
    nb["next"] = na["previous"] = nc
    nc["next"] = nb["previous"] = na
    a, b = na, nb

    i = 3
    while i < n:
        _place(a["_"], b["_"], circles[i])
        c = {"_": circles[i]}
        j = b["next"]
        k = a["previous"]
        sj = b["_"]["r"]
        sk = a["_"]["r"]
        restart = False
        while True:
            if sj <= sk:
                if _intersects(j["_"], c["_"]):
                    b = j
                    a["next"] = b
                    b["previous"] = a
                    restart = True
                    break
                sj += j["_"]["r"]
                j = j["next"]
            else:
                if _intersects(k["_"], c["_"]):
                    a = k
                    a["next"] = b
                    b["previous"] = a
                    restart = True
                    break
                sk += k["_"]["r"]
                k = k["previous"]
            if j is k:
                break
        if restart:
            continue

        c["previous"] = a
        c["next"] = b
        a["next"] = b["previous"] = c

        b = c
        aa = _score(a)
        node = c["next"]
        while node is not b:
            ca = _score(node)
            if ca < aa:
                a = node
                aa = ca
            node = node["next"]
        b = a["next"]
        i += 1

    chain = [b["_"]]
    node = b["next"]
    while node is not b:
        chain.append(node["_"])
        node = node["next"]
    e = enclose(chain)
    assert e is not None
    for circ in circles:
        circ["x"] -= e["x"]
        circ["y"] -= e["y"]
    return e["r"]


# --------------------------------------------------------------------------
# tree
# --------------------------------------------------------------------------


class Node:
    __slots__ = ("path", "kind", "children", "area", "r", "x", "y", "ax", "ay")

    def __init__(self, path: str, kind: str) -> None:
        self.path = path
        self.kind = kind  # "root" | "dir" | "module"
        self.children: list[Node] = []
        self.area = 0.0
        self.r = 0.0
        self.x = 0.0
        self.y = 0.0
        self.ax = 0.0
        self.ay = 0.0

    @property
    def depth(self) -> int:
        return 0 if self.path == "" else self.path.count("/") + 1


def _sib_key(node: Node) -> tuple[str, str]:
    return (hashlib.sha256(node.path.encode("utf-8")).hexdigest(), node.path)


def build_tree(modules: list[dict]) -> tuple[Node, dict[str, Node]]:
    root = Node("", "root")
    dirs: dict[str, Node] = {"": root}
    leaves: dict[str, Node] = {}
    for row in sorted(modules, key=lambda r: r["slug"]):
        slug = row["slug"]
        segs = slug.split("/")
        parent = root
        for i in range(1, len(segs)):
            prefix = "/".join(segs[:i])
            node = dirs.get(prefix)
            if node is None:
                node = Node(prefix, "dir")
                dirs[prefix] = node
                parent.children.append(node)
            parent = node
        if slug in dirs:
            raise SystemExit(
                f"layout: module slug {slug!r} is also a directory prefix; the pinned level "
                "mapping does not define this case — record it as a plan finding before proceeding"
            )
        leaf = Node(slug, "module")
        leaf.area = float(max(int(row["n_funcs"] or 0), 1))
        parent.children.append(leaf)
        leaves[slug] = leaf
    collide = sorted(set(dirs) & set(leaves))
    if collide:
        raise SystemExit(f"layout: slug/directory collision: {collide}")
    return root, leaves


def _layout_node(node: Node) -> None:
    if node.kind == "module":
        node.r = math.sqrt(node.area)
        return
    node.children.sort(key=_sib_key)
    for child in node.children:
        _layout_node(child)
    circles = [{"r": child.r * (1.0 + SEP)} for child in node.children]
    enclosing = pack_siblings(circles)
    for child, circ in zip(node.children, circles):
        child.x = circ["x"]
        child.y = circ["y"]
    node.r = enclosing * (1.0 + PAD)


def _absolutize(node: Node, ox: float, oy: float) -> None:
    node.ax = ox + node.x
    node.ay = oy + node.y
    for child in node.children:
        _absolutize(child, node.ax, node.ay)


def _walk(node: Node):
    yield node
    for child in node.children:
        yield from _walk(child)


# --------------------------------------------------------------------------
# LOD level mapping (pinned by task 1.1)
# --------------------------------------------------------------------------


def agg_at(slug: str, level: int) -> str:
    """The prefix-class aggregate of a module at ``level``.

    L0 = first path segment, L1 = two-segment prefix, L2 = the module itself.
    A module shallower than the level's prefix depth is its own aggregate.
    """
    if level >= 2:
        return slug
    segs = slug.split("/")
    return "/".join(segs[: level + 1])


def levels_for(node: Node) -> list[int]:
    """Which ``layout.level`` rows a packing-tree node produces."""
    if node.kind == "module":
        return list(range(min(node.depth - 1, 2), 3))
    return [min(node.depth - 1, 2)]


# --------------------------------------------------------------------------
# reading / writing
# --------------------------------------------------------------------------


def read_csv(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def compute_snapshot(status_rows: list[dict], profile: str) -> str:
    """sha256 over (sorted built_at values, profile, LAYOUT_VERSION).

    Shared with ``cgq.py``'s staleness banner (task 1.5) so the two sides can
    never drift on what "the same snapshot" means.
    """
    h = hashlib.sha256()
    h.update(f"layout_version={LAYOUT_VERSION}\n".encode("utf-8"))
    h.update(f"profile={profile}\n".encode("utf-8"))
    for ts in sorted({(r.get("built_at") or "") for r in status_rows}):
        h.update(f"built_at={ts}\n".encode("utf-8"))
    return h.hexdigest()


def q(value: float) -> str:
    """Fixed decimal quantization — formatted, never float-repr'd, so
    byte-identity across platforms is a well-defined claim."""
    text = f"{value:.{QUANT}f}"
    return _QUANT_ZERO if text == "-" + _QUANT_ZERO else text


def _module_of(func_slug: str) -> str:
    return func_slug.split("#", 1)[0]


def build_rows(out_dir: Path) -> tuple[list[dict], list[dict], dict]:
    """Compute both tables. Pure over the store's CSVs; writes nothing."""
    modules = read_csv(out_dir / "modules.csv")
    status = read_csv(out_dir / "extraction_status.csv")
    if not modules:
        raise SystemExit(f"layout: {out_dir}/modules.csv is empty — run extract.sh --profile=all")
    profile = (status[0].get("profile") if status else "") or "unknown"
    snapshot = compute_snapshot(status, profile)

    root, leaves = build_tree(modules)
    _layout_node(root)
    _absolutize(root, 0.0, 0.0)
    scale = root.r or 1.0

    layout_rows: list[dict] = []
    seen: set[tuple[str, int]] = set()
    for node in _walk(root):
        if node.kind == "root":
            continue
        for level in levels_for(node):
            key = (node.path, level)
            if key in seen:
                continue
            seen.add(key)
            layout_rows.append(
                {
                    "node_id": node.path,
                    "level": level,
                    "x": q(node.ax / scale),
                    "y": q(node.ay / scale),
                    "radius": q(node.r / scale),
                    "snapshot": snapshot,
                }
            )
    layout_rows.sort(key=lambda r: (r["level"], r["node_id"]))

    known = set(leaves)
    report: dict = {
        "profile": profile,
        "snapshot": snapshot,
        "layout_version": LAYOUT_VERSION,
        "modules": len(modules),
        "layout_rows": len(layout_rows),
        "dropped_edge_endpoints": {},
    }

    base: dict[str, dict[tuple[str, str], int]] = {}
    dropped: dict[str, int] = {}

    imports = read_csv(out_dir / "imports.csv")
    pairs = set()
    n_dropped = 0
    for row in imports:
        src, dst = row["from_module"], row["to_module"]
        if src not in known or dst not in known:
            n_dropped += 1
            continue
        pairs.add((src, dst))
    base["imports"] = {pair: 1 for pair in pairs}
    dropped["imports"] = n_dropped

    invokes = read_csv(out_dir / "invokes.csv")
    inv: dict[tuple[str, str], int] = {}
    n_dropped = 0
    seen_fn: set[tuple[str, str]] = set()
    for row in invokes:
        fs, ts = row["from_slug"], row["to_slug"]
        if (fs, ts) in seen_fn:
            continue
        seen_fn.add((fs, ts))
        src, dst = _module_of(fs), _module_of(ts)
        if src not in known or dst not in known:
            n_dropped += 1
            continue
        inv[(src, dst)] = inv.get((src, dst), 0) + 1
    base["invokes"] = inv
    dropped["invokes"] = n_dropped
    report["dropped_edge_endpoints"] = dropped

    edge_rows: list[dict] = []
    for kind, exactness in EDGE_KINDS:
        for level in (0, 1, 2):
            agg: dict[tuple[str, str], int] = {}
            for (src, dst), weight in base[kind].items():
                key = (agg_at(src, level), agg_at(dst, level))
                agg[key] = agg.get(key, 0) + weight
            for (src, dst), weight in agg.items():
                edge_rows.append(
                    {
                        "level": level,
                        "src_agg": src,
                        "dst_agg": dst,
                        "kind": kind,
                        "weight": weight,
                        "exactness": exactness,
                    }
                )
    edge_rows.sort(key=lambda r: (r["level"], r["kind"], r["src_agg"], r["dst_agg"]))
    report["edges_agg_rows"] = len(edge_rows)
    return layout_rows, edge_rows, report


LAYOUT_FIELDS = ("node_id", "level", "x", "y", "radius", "snapshot")
EDGES_FIELDS = ("level", "src_agg", "dst_agg", "kind", "weight", "exactness")


def write_csv(path: Path, fields: tuple[str, ...], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(fields), lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def build(out_dir: Path, write: bool = True, validate: bool = True) -> dict:
    layout_rows, edge_rows, report = build_rows(out_dir)
    if validate:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import validate_layout  # noqa: PLC0415  (deliberate: keeps the CLI standalone)

        findings = validate_layout.validate_rows(layout_rows, edge_rows, out_dir)
        report["findings"] = [f.as_dict() for f in findings]
        if findings:
            raise validate_layout.ValidationFailed(findings)
    if write:
        out_dir.mkdir(parents=True, exist_ok=True)
        write_csv(out_dir / "layout.csv", LAYOUT_FIELDS, layout_rows)
        write_csv(out_dir / "edges_agg.csv", EDGES_FIELDS, edge_rows)
        report["written"] = [str(out_dir / "layout.csv"), str(out_dir / "edges_agg.csv")]
    return report


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="store directory (default: tools/code-graph/.out)")
    ap.add_argument("--dry-run", action="store_true", help="validate only; write nothing")
    ap.add_argument("--no-validate", action="store_true", help="escape hatch for debugging; never use to land an artifact")
    ns = ap.parse_args(argv)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import validate_layout

    try:
        report = build(ns.out, write=not ns.dry_run, validate=not ns.no_validate)
    except validate_layout.ValidationFailed as exc:
        print("LAYOUT VALIDATION FAILED — nothing written", file=sys.stderr)
        for finding in exc.findings:
            print(f"  [{finding.rule}] {finding.detail}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
