#!/usr/bin/env python3
"""Smallest working version of the check ADR-001 D8 names.

Given an earlier and a later dagr document for the same plan, report every task
that had already been started in the earlier one (it has at least one attempt)
and whose acceptance-bearing fields differ in the later one, and say whether the
later document records an operator directive on that task in between.

Usage: spec_edit_probe.py EARLIER.json LATER.json [more pairs...]
"""
import json
import sys
from pathlib import Path

SPEC_FIELDS = ("criteria", "deps", "inputs", "kind")  # what "done" means and what gates it


def load(p):
    d = json.loads(Path(p).read_text())
    return d, {t["id"]: t for t in d.get("tasks", [])}


def operator_directive(later_doc, task_id, since):
    for e in later_doc.get("events", []):
        if e.get("type") != "directive" or e.get("task") != task_id:
            continue
        if since and e.get("at", "") <= since:
            continue
        by = (e.get("by") or e.get("actor") or "").lower()
        if "operator" in by or "human" in by:
            return e
    return None


def compare(a_path, b_path, show=4):
    a_doc, a = load(a_path)
    b_doc, b = load(b_path)
    since = a_doc.get("generated_at", "")
    started = {i for i, t in a.items() if t.get("attempts")}
    common = set(a) & set(b)
    edits = []
    for i in sorted(common):
        changed = [f for f in SPEC_FIELDS if a[i].get(f) != b[i].get(f)]
        if changed:
            edits.append((i, changed, i in started, operator_directive(b_doc, i, since)))
    removed_started = sorted(i for i in started if i not in b)
    on_started = [e for e in edits if e[2]]
    undirected = [e for e in on_started if e[3] is None]
    print(f"{Path(a_path).name}  ->  {Path(b_path).name}")
    print(f"  tasks: {len(a)} -> {len(b)}   common: {len(common)}   added: {len(set(b) - set(a))}   "
          f"started in earlier: {len(started)}")
    print(f"  spec fields changed on a common task: {len(edits)}   "
          f"of those on a STARTED task: {len(on_started)}   "
          f"with no operator directive recorded: {len(undirected)}")
    by_field = {}
    for _, ch, st, _ in edits:
        if st:
            for f in ch:
                by_field[f] = by_field.get(f, 0) + 1
    if by_field:
        print(f"  started-task edits by field: {by_field}")
    if removed_started:
        print(f"  started tasks that disappeared: {removed_started}")
    for i, ch, st, d in undirected[:show]:
        f = ch[0]
        old, new = a[i].get(f), b[i].get(f)
        if isinstance(old, str) and isinstance(new, str):
            print(f"    {i} [{f}] {len(old)} -> {len(new)} chars")
            print(f"       was: {old[:150]!r}")
            print(f"       now: {new[:150]!r}")
        else:
            print(f"    {i} [{f}] {old!r} -> {new!r}")
    print()
    return len(on_started), len(undirected)


def main(argv):
    if len(argv) < 2 or len(argv) % 2:
        print(__doc__)
        return 2
    tot = und = 0
    for k in range(0, len(argv), 2):
        s, u = compare(argv[k], argv[k + 1])
        tot += s
        und += u
    print(f"TOTAL spec edits on started tasks: {tot}; without an operator directive: {und}")
    return 1 if und else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
