#!/usr/bin/env python3
"""Re-derive the ADR-001 boundary probe fixtures from the review appendices.

P0.2's central provenance claim is that every fixture in
`scripts/dst/fixtures/adr001_boundary/` is the source QUOTED in a review
appendix, not a case re-invented from a prose description. That claim is worth
nothing as a promise, so this script makes it a check: it re-extracts every
fenced ```ailang block whose first line is `module repro/<name>` from the five
review documents and compares it, after the one mechanical edit below, with the
committed fixture.

THE ONE EDIT. The reviews ran in a scratch package with `module_prefix = repro`.
In the tree the fixtures live under `scripts/dst/fixtures/adr001_boundary/`, and
AILANG resolves an import path to a file path, so the module and import lines
must name that directory. Nothing else is touched -- not a token of any body.

  module repro/<x>        ->  module scripts/dst/fixtures/adr001_boundary/<x>
  import repro/<y> (...)  ->  import scripts/dst/fixtures/adr001_boundary/<y> (...)

WHY THE DIRECTORY IS SPELLED WITH AN UNDERSCORE. PLAN-001 §0 item 6 names
`scripts/dst/fixtures/adr001-boundary/`. The pinned compiler refuses a hyphen in
a module or import path -- `PAR_HYPHEN_IN_MODULE ... hyphens in module paths are
parsed as subtraction` -- and this suite's whole mechanism is a fixture importing
its `Capability`/`Slot` sum from a sibling module. So the directory is
`adr001_boundary`, under the plan's own "a part may move one with the reason
recorded" clause. The reason is a compiler verdict, recorded here and in the
commit.

Usage:
  adr001_boundary_provenance.py verify    compare committed fixtures (exit 1 on drift)
  adr001_boundary_provenance.py write     (re)generate the fixtures from the reviews
"""
import hashlib
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FIXTURES = REPO / "scripts/dst/fixtures/adr001_boundary"
DOCS = REPO / ".agent/projects/031_system_one_decisions"
HOME = "scripts/dst/fixtures/adr001_boundary"

REVIEWS = [
    ("v0.3", "REVIEW-adr001-v0.3-verdicts-codex.md"),
    ("v0.4", "REVIEW-adr001-v0.4-verdicts-claude-opus-5.md"),
    ("v0.5", "REVIEW-adr001-v0.5-verdicts-claude-fable-5-1.md"),
    ("v0.6", "REVIEW-adr001-v0.6-verdicts-codex.md"),
    ("v0.7", "REVIEW-adr001-v0.7-verdicts-claude-fable-5-1.md"),
]

# Quoted in a review appendix but deliberately NOT made a fixture. Each entry is
# the reason, and each reason is the review's own.
NOT_FIXTURES = {
    "constructor_shadow":
        "v0.6 A.3 records it as an invalid setup (undefined variable RealToolPolicy) "
        "that 'supplies no evidence'; a row on it would be a rejection for the wrong "
        "reason by construction, which the row idiom forbids",
    "v7_ctor_shadow":
        "its support module repro/v7_mk (mk_policy, invoke) is described but never "
        "quoted in v0.7 A.3, so the case cannot be built from a quoted source",
}


def extract() -> dict[str, tuple[str, str]]:
    """name -> (review, source text), byte-identical across reviews that quote it."""
    found: dict[str, list[tuple[str, str]]] = {}
    for rev, name in REVIEWS:
        text = (DOCS / name).read_text()
        for m in re.finditer(r"```ailang\n(.*?)```", text, re.S):
            body = m.group(1)
            mm = re.match(r"^module repro/([A-Za-z0-9_]+)$", body.split("\n", 1)[0].strip())
            if mm:
                found.setdefault(mm.group(1), []).append((rev, body))
    out = {}
    for name, entries in sorted(found.items()):
        digests = {hashlib.sha256(t.encode()).hexdigest() for _, t in entries}
        if len(digests) != 1:
            raise SystemExit(
                f"FAIL: {name} is quoted in {[r for r, _ in entries]} and the copies "
                f"DIFFER. The suite cannot claim one fixture per case until the "
                f"reviews agree on the source."
            )
        out[name] = (",".join(r for r, _ in entries), entries[0][1])
    return out


def repath(src: str) -> str:
    src = re.sub(r"^module repro/", f"module {HOME}/", src, flags=re.M)
    return re.sub(r"^import repro/", f"import {HOME}/", src, flags=re.M)


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "verify"
    cases = extract()
    drift, wrote, skipped = [], 0, []
    for name, (rev, src) in cases.items():
        if name in NOT_FIXTURES:
            skipped.append(name)
            continue
        want = repath(src)
        path = FIXTURES / f"{name}.ail"
        if mode == "write":
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(want)
            wrote += 1
        elif not path.exists():
            drift.append(f"{name}: fixture missing at {path.relative_to(REPO)}")
        elif path.read_text() != want:
            drift.append(f"{name}: fixture differs from the {rev} quoted source")
    if mode == "write":
        print(f"wrote {wrote} fixtures to {FIXTURES.relative_to(REPO)} "
              f"({len(skipped)} quoted cases deliberately not made fixtures: {', '.join(skipped)})")
        return 0
    for name in sorted(NOT_FIXTURES):
        if (FIXTURES / f"{name}.ail").exists():
            drift.append(f"{name}: present as a fixture, but {NOT_FIXTURES[name]}")
    if drift:
        print("adr001 boundary provenance: FAILED")
        for d in drift:
            print(f"  {d}")
        return 1
    print(f"adr001 boundary provenance: {len(cases) - len(skipped)} fixtures are "
          f"byte-identical to their quoted review sources (module/import path re-written only)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
