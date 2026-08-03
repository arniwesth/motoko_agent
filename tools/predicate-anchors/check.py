#!/usr/bin/env python3
"""The classifier-2 predicate documentation check (WI-A11, ADR-001 D1).

**This is an anchor-set DRIFT check, not a containment check, and that choice is
forced rather than preferred.** The ADR records that its normative statements of
the predicate are "substantively aligned, not word-identical -- the six use six
formulations". A check requiring one canonical sentence to appear at all six is
therefore RED ON THE UNMUTATED ADR by construction, and the alternative --
canonicalising the six -- is six amendments this project does not budget and
would destroy the information each formulation carries.

So: every passage in the ADR's normative region that mentions the rule is
recorded in `anchors.json` with a content hash, a classification, and a NAMED
REVIEWER who accepted it. The check fails when

  * a recorded passage's text changed without a re-accepted hash;
  * a mention appears that no record accounts for (a new statement of the
    predicate, or an old one reformulated);
  * a record has no reviewer.

Passages are matched BY HASH, not by line. Line numbers are recorded as a hint
and a stale hint is reported, never failed on: the ADR is amended regularly and
a line-keyed check would go red on every unrelated edit, which trains people to
re-baseline it without reading. The hash is the identity.

The unit hashed is the PARAGRAPH containing the mention, not the line. A rule
restated across a sentence that wraps would otherwise change meaning without
changing the hashed line, which is the silent failure this check exists to
prevent.

**The count "six" is not what is checked -- the ENUMERATION is.** An earlier
reading of the ADR asserted six normative sites without saying which; two
defensible sixes existed, and a check built on either would have been asserting
a curation rather than verifying one. The ADR was amended (2026-08-03) to
enumerate them, and `anchors.json` is that enumeration plus the classification
of every other mention.

Exit codes: 0 clean, 1 drift, 2 harness error.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


def paragraph_at(lines: list[str], idx: int) -> tuple[int, int]:
    """The blank-line-delimited block containing line `idx` (0-based)."""
    a = idx
    while a > 0 and lines[a - 1].strip() != "":
        a -= 1
    b = idx
    while b + 1 < len(lines) and lines[b + 1].strip() != "":
        b += 1
    return a, b


def normalize(text: str) -> str:
    """Collapse whitespace so a reflow is not reported as a rewrite.

    Reflowing a paragraph to a different column width is an editorial change that
    alters no claim; treating it as drift would produce false triage on every
    formatting pass. Anything that changes a WORD changes the hash.
    """
    return " ".join(text.split())


def digest(text: str) -> str:
    return "sha256:" + hashlib.sha256(normalize(text).encode()).hexdigest()[:32]


def find_mentions(adr: Path, patterns: list[str], region_end_marker: str) -> list[dict]:
    lines = adr.read_text().splitlines()

    end = len(lines)
    for i, ln in enumerate(lines):
        if ln.startswith(region_end_marker):
            end = i
            break

    rx = re.compile("|".join(patterns))
    seen: set[tuple[int, int]] = set()
    out: list[dict] = []
    for i in range(end):
        if not rx.search(lines[i]):
            continue
        a, b = paragraph_at(lines, i)
        if (a, b) in seen:
            continue          # one paragraph, one passage, however many mentions
        seen.add((a, b))
        body = "\n".join(lines[a:b + 1])
        out.append({"line": a + 1, "hash": digest(body),
                    "first": lines[i].strip()[:100]})
    return out, end


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--adr", default=".agent/projects/009_motoko_dst_execution/"
                                     "ADR-001-deterministic-test-world-architecture.md")
    ap.add_argument("--anchors", default="tools/predicate-anchors/anchors.json")
    ap.add_argument("--emit", action="store_true",
                    help="print the measured passages as JSON records, for re-baselining "
                         "after an accepted ADR change. A reviewer still has to accept each.")
    args = ap.parse_args()

    adr = Path(args.adr)
    spec = json.loads(Path(args.anchors).read_text())

    found, region_end = find_mentions(adr, spec["patterns"], spec["normative_region_ends_at"])

    if args.emit:
        print(json.dumps(found, indent=2))
        return 0

    records = {r["hash"]: r for r in spec["passages"]}
    fails: list[str] = []

    by_hash = {f["hash"]: f for f in found}

    # 1. every mention must be accounted for
    for f in found:
        if f["hash"] not in records:
            fails.append(
                f"UNACCOUNTED passage at ADR:{f['line']}\n"
                f"    {f['first']}\n"
                f"    hash {f['hash']}\n"
                f"    Either a recorded passage was edited (its old hash will also be reported\n"
                f"    missing below), or a NEW statement of the predicate appeared. Both are\n"
                f"    triage events: classify it as `anchor` or `reference` in anchors.json\n"
                f"    with a reviewer, or revert the edit.")

    # 2. every recorded passage must still be present
    for h, r in records.items():
        if h not in by_hash:
            fails.append(
                f"MISSING recorded passage: {r['section']} ({r['kind']})\n"
                f"    recorded at ADR:{r['line']}, hash {h}\n"
                f"    reviewer {r['reviewer']}\n"
                f"    Its text changed or it was deleted. A changed anchor needs a\n"
                f"    RE-ACCEPTED hash from a named reviewer, not a re-baseline.")

    # 3. every record needs a reviewer -- the artifact's own correctness condition
    for h, r in records.items():
        if not r.get("reviewer"):
            fails.append(f"NO REVIEWER for {r['section']} ({h})")

    anchors = [r for r in records.values() if r["kind"] == "anchor"]
    refs = [r for r in records.values() if r["kind"] == "reference"]

    print(f"ADR                {adr}")
    print(f"normative region   lines 1-{region_end} (ends at '{spec['normative_region_ends_at']}')")
    print(f"mentions found     {len(found)}")
    print(f"recorded           {len(records)}  ({len(anchors)} anchors, {len(refs)} references)")
    print()
    print("anchors -- the passages that STATE the rule:")
    for r in sorted(anchors, key=lambda x: x["line"]):
        live = "ok " if r["hash"] in by_hash else "GONE"
        hint = by_hash[r["hash"]]["line"] if r["hash"] in by_hash else None
        moved = f"  (recorded ADR:{r['line']}, now ADR:{hint} -- hint stale, not a failure)" \
            if hint and hint != r["line"] else ""
        print(f"  [{live}] {r['section']:<34} {r['reviewer']:<14}{moved}")
    print()
    print("references -- passages that APPLY or discuss the rule:")
    for r in sorted(refs, key=lambda x: x["line"]):
        live = "ok " if r["hash"] in by_hash else "GONE"
        print(f"  [{live}] {r['section']:<34} {r['reviewer']}")

    if fails:
        print(f"\nDRIFT ({len(fails)}):")
        for f in fails:
            print(f"  {f}\n")
        return 1

    print(f"\nno drift: {len(anchors)} anchors and {len(refs)} references all match their "
          f"accepted hashes, and no unaccounted mention exists in the normative region.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
