from __future__ import annotations

import json
from collections import defaultdict, deque
from pathlib import Path

from .seed_catalog import effects_for


def compute_effect_edges(std_calls: list[dict], invokes: list[dict], catalog: dict) -> list[dict]:
    reverse: dict[str, set[str]] = defaultdict(set)
    for edge in invokes:
        reverse[edge["to_slug"]].add(edge["from_slug"])

    rows: dict[tuple[str, str, str], dict] = {}
    queue: deque[tuple[str, str, str, int]] = deque()
    for call in std_calls:
        seed = call["from_slug"]
        for eff in effects_for(catalog, call["std_module"], call["symbol"]):
            key = (seed, eff, seed)
            row = {"func_slug": seed, "effect": eff, "source_func_slug": seed,
                   "distance": 0, "derivation": "primitive_seed"}
            rows[key] = row
            queue.append((seed, eff, seed, 0))

    while queue:
        func, eff, source, dist = queue.popleft()
        for caller in reverse.get(func, set()):
            key = (caller, eff, source)
            ndist = dist + 1
            old = rows.get(key)
            if old and int(old["distance"]) <= ndist:
                continue
            rows[key] = {"func_slug": caller, "effect": eff, "source_func_slug": source,
                         "distance": ndist, "derivation": "backward_reachable"}
            queue.append((caller, eff, source, ndist))
    return sorted(rows.values(), key=lambda r: (r["func_slug"], r["effect"], r["source_func_slug"], r["distance"]))


def oracle_report(funcs: list[dict], declared_rows: list[dict], effect_edges: list[dict], out_path: Path | None = None) -> dict:
    declared: dict[str, set[str]] = defaultdict(set)
    reachable: dict[str, set[str]] = defaultdict(set)
    for row in declared_rows:
        declared[row["func_slug"]].add(row["effect"])
    for row in effect_edges:
        reachable[row["func_slug"]].add(row["effect"])

    checked = [f["slug"] for f in funcs if f.get("exported") == 1 and f.get("module_iface_status") == "ok"]
    missing = []
    over = []
    for slug in checked:
        d = declared.get(slug, set())
        r = reachable.get(slug, set())
        m = sorted(d - r)
        o = sorted(r - d)
        if m:
            missing.append({"func_slug": slug, "effects": m})
        if o:
            over.append({"func_slug": slug, "effects": o})
    report = {
        "checked_ok_exported_funcs": len(checked),
        "declared_subset_reachable": len(checked) - len(missing),
        "missing_declared": missing,
        "over_reached": over,
        "funcs_with_zero_over_reach": len(checked) - len(over),
        "over_seed_rate": (len(over) / len(checked)) if checked else 0,
    }
    if out_path:
        out_path.write_text(json.dumps(report, indent=2, sort_keys=True))
    return report
