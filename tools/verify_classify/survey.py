#!/usr/bin/env python3
"""Which functions in src/core COULD carry a Z3 contract? Ask the solver.

The question this answers is not "which functions have contracts" -- `make
verify_core` reports that -- but "which ones would the solver decide if someone
wrote one". Guessing at it from the six rejection codes in
`ailang/internal/smt/encodable.go` is how PLAN P3.6 arrived at "1069 of 1545 pass
a crude in-fragment filter", an estimate that turned out to be off by a factor of
four in the direction that matters.

Method: for each module, synthesise `ensures { true }` on every `pure func` that
does not already have an ensures, verify the module once, and read the per-
function verdict.

  VERIFIED   the function is INSIDE the fragment -- a real contract on it would
             be decided. This is the candidate list.
  SKIPPED    outside, with the verifier's reason (recursive callee, unencodable
             builtin, unencodable type).
  ERROR      the encoder reached the body and failed on it.
  EFFECTS    declares an effect row, so `isPure` rejects it before the body is
             read. Not probed.
  NOCOMPILE  the synthesised module did not parse -- a signature shape this tool
             does not handle yet. Reported, never hidden: a survey that silently
             drops what it cannot read is the failure this project is named for.

Being in the fragment does NOT mean a contract is worth writing. `exhaustion_pct`
is `{ 95 }` and verifies; a contract there restates a literal. Use this to find
candidates, then ADR-001 §1 to decide whether what you wrote counts.

Usage:
  survey.py                      report, production modules first
  survey.py --all                include dst_* (mostly world constructors)
  survey.py --module session     one module
  survey.py --json out.json      machine-readable, for diffing across runs
"""

import argparse
import collections
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src" / "core"
GEN = Path(__file__).resolve().parent / "generated"

START = re.compile(r"^(?:export\s+)?pure\s+func\s+(?P<name>\w+)\s*\(", re.M)


def _close(text: str, i: int, open_c: str, close_c: str) -> int:
    """Index of the delimiter matching the one at `i`, skipping string literals."""
    depth = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def insertion_point(text: str, m: re.Match) -> tuple[int | None, str]:
    """Where `ensures` may go: after the return type, before the body.

    Returns (offset, "") or (None, reason). Handles every signature shape in
    src/core: a body opening on the signature line, a `= expr` body, a record
    return type, a return type spanning lines (`-> [\\n  {key: string}]`), a
    whole declaration on one line, and an effect row (`-> T ! {IO, FS}`), which
    is not probed because a declared effect fails `isPure` before the body is
    read.
    """
    p = _close(text, text.index("(", m.end() - 1), "(", ")")
    if p < 0:
        return None, "unbalanced parameter list"
    arrow = text.find("->", p)
    if arrow < 0 or text.count("\n", p, arrow) > 1:
        return None, "no return type found"

    i, n = arrow + 2, len(text)
    while i < n and text[i] in " \t":
        i += 1
    if i < n and text[i] == "{":                    # record return type, not a body
        i = _close(text, i, "{", "}") + 1
        if i == 0:
            return None, "unbalanced record return type"

    depth = 0
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif depth == 0 and c == "!":
            return None, "declares an effect row"
        elif depth == 0 and c in "{=":
            return i, ""                            # body starts here
        elif c in "[({":
            depth += 1
        elif c in "])}":
            depth -= 1
        elif c == "\n" and depth == 0:
            return i, ""                            # clauses or body on later lines
        i += 1
    return None, "ran off the end of the file"


def next_clause(text: str, at: int) -> str:
    for line in text[at:at + 400].splitlines():
        s = line.strip()
        if not s or s.startswith("--"):
            continue
        return s.split()[0]
    return ""


VERDICT = re.compile(r"\b(VERIFIED|SKIPPED|ERROR)\s+(\w+)\b")


def probe_module(path: Path, keep: bool = False) -> dict[str, tuple[str, str]]:
    text = path.read_text()
    out: dict[str, tuple[str, str]] = {}
    points, names = [], []

    for m in START.finditer(text):
        at, why = insertion_point(text, m)
        if at is None:
            out[m.group("name")] = ("EFFECTS" if "effect" in why else "UNREADABLE", why)
            continue
        # Skip anything already contracted: an existing ensures is the answer, and
        # a requires would need the synthesised clause ordered after it.
        if next_clause(text, at + 1 if text[at] == "{" else at) in ("ensures", "requires"):
            continue
        points.append(at)
        names.append(m.group("name"))

    if not points:
        return out

    parts, prev = [], 0
    for at in points:
        parts.append(text[prev:at])
        parts.append("\n  ensures { true }\n  ")
        prev = at
    parts.append(text[prev:])

    stem = path.stem
    probed = "".join(parts).replace(
        f"module src/core/{stem}",
        f"module tools/verify_classify/generated/{stem}_survey", 1)
    GEN.mkdir(parents=True, exist_ok=True)
    probe = GEN / f"{stem}_survey.ail"
    probe.write_text(probed)

    res = subprocess.run(["ailang", "verify", str(probe.relative_to(ROOT))],
                         capture_output=True, text=True, cwd=ROOT)
    blob = res.stdout + res.stderr

    if not VERDICT.search(blob):
        first = next((l for l in blob.splitlines() if "rror" in l), "")
        # Kept on disk: a NOCOMPILE is a bug in this tool, and the file is the repro.
        return out | {n: ("NOCOMPILE", first[:200]) for n in names}

    if not keep:
        probe.unlink(missing_ok=True)

    lines = blob.splitlines()
    seen: dict[str, tuple[str, str]] = {}
    for i, line in enumerate(lines):
        mm = VERDICT.search(line)
        if not mm:
            continue
        reason = ""
        for nxt in lines[i + 1:i + 3]:
            if "Reason:" in nxt or "error:" in nxt:
                reason = nxt.strip().replace("Reason: ", "")
                break
        seen[mm.group(2)] = (mm.group(1), reason)
    return out | {n: seen.get(n, ("ABSENT", "no verdict line")) for n in names}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="include dst_* modules")
    ap.add_argument("--module", help="probe one module (stem, e.g. `session`)")
    ap.add_argument("--json", help="write the raw verdicts here")
    args = ap.parse_args()

    mods = [p for p in sorted(SRC.glob("*.ail")) if not p.name.endswith("_test.ail")]
    if args.module:
        mods = [p for p in mods if p.stem == args.module]
        if not mods:
            raise SystemExit(f"no such module: src/core/{args.module}.ail")

    results = {}
    for i, path in enumerate(mods, 1):
        r = probe_module(path)
        if r:
            results[path.name] = r
        print(f"[{i}/{len(mods)}] {path.name}", file=sys.stderr)

    if args.json:
        Path(args.json).write_text(json.dumps(results, indent=1))

    def show(pred, title):
        rows = []
        for mod, fns in sorted(results.items()):
            if not pred(mod):
                continue
            names = sorted(n for n, (v, _) in fns.items() if v == "VERIFIED")
            if names:
                rows.append((mod, names))
        if not rows:
            return 0
        print(f"\n{title}")
        total = 0
        for mod, names in rows:
            total += len(names)
            print(f"  {mod} ({len(names)})")
            for n in names:
                print(f"      {n}")
        return total

    prod = show(lambda m: not m.startswith("dst_"),
                "IN FRAGMENT -- production modules (a contract here would be decided)")
    dst = sum(1 for m, f in results.items() if m.startswith("dst_")
              for v in f.values() if v[0] == "VERIFIED")
    if args.all:
        show(lambda m: m.startswith("dst_"), "IN FRAGMENT -- dst_* modules")

    counts = collections.Counter(v[0] for f in results.values() for v in f.values())
    print(f"\nsurvey: {sum(counts.values())} declarations probed across {len(results)} modules")
    for k in ("VERIFIED", "SKIPPED", "ERROR", "EFFECTS", "NOCOMPILE", "UNREADABLE", "ABSENT"):
        if counts.get(k):
            print(f"  {counts[k]:5d}  {k}")
    print(f"\n  of {counts.get('VERIFIED', 0)} in fragment: {prod} in production modules, "
          f"{dst} in dst_* (world constructors -- a contract there usually restates one)")

    if counts.get("NOCOMPILE"):
        print(f"\n  {counts['NOCOMPILE']} NOCOMPILE: a signature shape this tool cannot "
              f"rewrite. The\n  generated file is left in {GEN.relative_to(ROOT)}/ as the repro.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
