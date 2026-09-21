#!/usr/bin/env python3
"""Check the P0.2b reconstructions against review 5's §A.3 table.

PLAN-001 (031) §2 P0.2b. Review 5 (`REVIEW-adr001-v0.5-verdicts-claude-fable-5-1.md`
§A.3) measured its named-arm attacks as a TABLE OF SHAPES and quoted full source
for only five cases, which P0.2 committed and `adr001_boundary_provenance.py`
re-derives byte-for-byte. The other rows cannot be re-derived, because there is
no source to derive them from. They are rebuilt from their Shape column under
`scripts/dst/fixtures/adr001_boundary/reconstructed/`. A reconstruction is new
authorship, not the review's evidence, and this check keeps that visible:

  1. THE SET IS DERIVED FROM THE TABLE, NOT LISTED HERE. The expected cases are
     every §A.3 row whose result is a rejection, minus the rows whose source §A.3
     quotes under a `####` heading (P0.2's fixtures), plus the one control row
     (`q=1`). The escape rows are all quoted, so none is a reconstruction.
  2. EACH FIXTURE'S HEADER QUOTES ITS TABLE ROW BYTE-FOR-BYTE, on line 3, under a
     line that says `Reconstructed from shape, not quoted source.`
  3. A TABLE ROW WITH NO FIXTURE MUST BE LISTED IN `NOT_RECONSTRUCTED` WITH THE
     REASON. That list holds the rows that could not be made to reject for the
     reason the table records. Such a row is reported, not forced.
  4. NO EXTRA CASES. Support modules are named in `SUPPORT`, and any other file
     in the directory fails the check.

This script leaves `adr001_boundary_provenance.py` alone, and that script never
reads `reconstructed/`. So P0.2's 52 quoted fixtures still re-derive exactly as
before.

Usage: adr001_boundary_reconstructed_provenance.py   (exit 1 on any drift)
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DIR = REPO / "scripts/dst/fixtures/adr001_boundary/reconstructed"
REVIEW = REPO / ".agent/projects/031_system_one_decisions/REVIEW-adr001-v0.5-verdicts-claude-fable-5-1.md"
SECTION = "### A.3 Q-1: attacking the named-function arm"
LINE2 = "-- PLAN-001 (031) P0.2b. Reconstructed from shape, not quoted source."

SUPPORT = {"judge_types", "rec_types"}

NOT_RECONSTRUCTED = {
    "q_named_toplevel_xmod":
        "table records 'rejected: app' (closed-row unification at the Pure(body) "
        "application). Every shape-faithful build tried on v0.33.0 rejects by the same "
        "closed-row labels, but at apply(ctx, w) parameter 1 (record field 'f') inside "
        "body: the IMPORTED W closes the row before body can carry IO. Attempt and "
        "compiler output: evidence/P0.2b/",
}


def table() -> tuple[dict[str, str], set[str]]:
    text = REVIEW.read_text()
    start = text.index(SECTION)
    end = text.find("\n### ", start + 1)
    sec = text[start:end if end > 0 else len(text)]
    rows = {}
    for line in sec.split("\n"):
        m = re.match(r"^\| (?:\*\*)?`([A-Za-z0-9_]+)`(?:\*\*)? \|", line)
        if m:
            rows[m.group(1)] = line
    quoted = set(re.findall(r"^#### `([A-Za-z0-9_]+)`", sec, re.M))
    return rows, quoted


def main() -> int:
    rows, quoted = table()
    expected = {}
    for name, line in rows.items():
        result = line.rstrip(" |").rsplit(" | ", 1)[-1]
        if name in quoted:
            continue
        if result.startswith("rejected") or result == "`q=1`":
            expected[name] = line
    drift = []
    present = {p.stem for p in DIR.glob("*.ail")}
    for name, line in sorted(expected.items()):
        if name in NOT_RECONSTRUCTED:
            if name in present:
                drift.append(f"{name}: listed NOT_RECONSTRUCTED but a fixture exists")
            continue
        if name not in present:
            drift.append(f"{name}: table row has no reconstruction and no NOT_RECONSTRUCTED reason")
            continue
        head = (DIR / f"{name}.ail").read_text().split("\n")
        if len(head) < 3 or head[0] != LINE2:
            drift.append(f"{name}: header line 1 is not the reconstructed-from-shape label")
        elif head[2] != f"-- {line}":
            drift.append(f"{name}: header line 3 does not quote the §A.3 table row byte-for-byte")
    for name in sorted(present - set(expected) - SUPPORT):
        drift.append(f"{name}: not a §A.3 unquoted row, not a support module")
    for name in sorted(set(NOT_RECONSTRUCTED) - set(expected)):
        drift.append(f"{name}: NOT_RECONSTRUCTED names a case the table does not hold")
    if drift:
        print("adr001 reconstructed provenance: FAILED")
        for d in drift:
            print(f"  {d}")
        return 1
    built = len(expected) - len(NOT_RECONSTRUCTED)
    print(f"adr001 reconstructed provenance: {built} of {len(expected)} unquoted §A.3 rows "
          f"reconstructed, each header quoting its table row byte-for-byte; "
          f"{len(NOT_RECONSTRUCTED)} not reconstructed, reason recorded "
          f"({', '.join(sorted(NOT_RECONSTRUCTED))})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
