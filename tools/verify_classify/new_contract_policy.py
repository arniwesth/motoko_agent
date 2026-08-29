#!/usr/bin/env python3
"""Every NEW `pure func` in src/core/ carries a contract or a checked excuse.

ADR-001 §4. Free text is what let compaction.ail's honest comments and
agents_md.ail's misleading `Z3 / SMT verification targets` banner look alike to a
reader, so a justification here is not taken on trust: for each annotated
function the checker synthesises a trivial contract (`ensures { true }`) and
confirms the verifier really does reject the function. An unchecked excuse is as
self-asserted as no excuse.

Keyed on the diff, not the tree. ~1545 `pure func` declarations predate this rule
and have no migration story; a tree-wide version would be unenforceable on day
one and therefore enforced on no one.

WHAT THIS CHECKS, PRECISELY. Not that the claimed rejection *code* is the one the
verifier returns -- codes are not available on the text path: verify.go:340-349
prints only the human message, and the `no ensures` path bypasses code generation
entirely (ADR-001 retraction 5). What it checks is the claim's substance: that the
function does not, in fact, verify. That catches the failure mode that matters --
an excuse on a function that would have verified fine -- and it reports the
verifier's actual words next to the claim so a wrong reason is visible to a reader
even when it cannot be matched mechanically.

Usage:  new_contract_policy.py [--base main_dst]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN = Path(__file__).resolve().parent / "generated"

DECL_RE = re.compile(r"^\+(?:export\s+)?pure\s+func\s+(?P<name>\w+)\s*\(")
HUNK_FILE_RE = re.compile(r"^\+\+\+ b/(?P<path>.+)$")
JUSTIFY_RE = re.compile(r"--\s*contracts:\s*(?P<claim>.+)$", re.M)


def added_pure_funcs(base: str) -> dict[str, list[str]]:
    """{path: [names]} for `pure func`s added under src/core/ since `base`."""
    if subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{base}^{{commit}}"],
                      capture_output=True, cwd=ROOT).returncode != 0:
        # A shallow checkout does not have the base. Fetching is the fix; failing
        # loudly is the point -- a policy that quietly passes when it cannot see
        # the diff is worse than no policy.
        subprocess.run(["git", "fetch", "--no-tags", "--depth=200", "origin",
                        base.split("/", 1)[-1]], capture_output=True, cwd=ROOT)
        if subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{base}^{{commit}}"],
                          capture_output=True, cwd=ROOT).returncode != 0:
            raise SystemExit(
                f"new_contract_policy: cannot resolve base ref {base!r}. Pass --base, or "
                f"deepen the checkout (actions/checkout needs fetch-depth: 0).")

    diff = subprocess.run(
        ["git", "diff", f"{base}...HEAD", "--unified=0", "--", "src/core"],
        capture_output=True, text=True, cwd=ROOT, check=True).stdout

    out: dict[str, list[str]] = {}
    path = None
    for line in diff.splitlines():
        m = HUNK_FILE_RE.match(line)
        if m:
            path = m.group("path")
            continue
        m = DECL_RE.match(line)
        if m and path and path.endswith(".ail") and not path.endswith("_test.ail"):
            out.setdefault(path, []).append(m.group("name"))
    return out


def declaration_of(text: str, name: str) -> tuple[int, int] | None:
    """(start-of-preceding-comment-block, end-of-signature-line)."""
    m = re.search(rf"^(?:export\s+)?pure\s+func\s+{re.escape(name)}\s*\(", text, re.M)
    if not m:
        return None
    start = m.start()
    # walk back over the contiguous comment block directly above
    lines = text[:start].splitlines()
    i = len(lines)
    while i > 0 and lines[i - 1].lstrip().startswith("--"):
        i -= 1
    return sum(len(l) + 1 for l in lines[:i]), text.index("\n", m.end())


def has_contract(text: str, name: str) -> bool:
    m = re.search(rf"^(?:export\s+)?pure\s+func\s+{re.escape(name)}\s*\([^)]*\)[^\n]*\n"
                  r"(?P<clauses>(?:[ \t]*(?:--[^\n]*|requires\b|ensures\b|tests\b)[^\n]*\n)*)",
                  text, re.M)
    return bool(m and re.search(r"^\s*ensures\b", m.group("clauses"), re.M))


def verifier_rejects(path: str, name: str) -> tuple[bool | None, str]:
    """Synthesise `ensures { true }` on `name` and report whether it verifies.

    Returns (True, reason) if the verifier rejects it -- the excuse stands;
    (False, _) if it VERIFIES -- the excuse is wrong; (None, detail) if the
    claim could not be checked at all, which is reported as a failure rather
    than waved through.
    """
    src_path = ROOT / path
    text = src_path.read_text()
    m = re.search(rf"^((?:export\s+)?pure\s+func\s+{re.escape(name)}\s*\([^)]*\)[^\n]*)$",
                  text, re.M)
    if not m:
        return None, "declaration not found for probing"

    sig = m.group(1)
    # The body may open on the signature line. Distinguish that trailing `{`
    # from a record return type (`-> { start: int, end: int }`) by brace balance
    # after the arrow, so the synthesised clause goes before the body, not into it.
    after = sig.split("->", 1)[-1]
    body_opens_here = sig.rstrip().endswith("{") and after.count("{") - after.count("}") == 1
    head = sig.rstrip()[:-1].rstrip() if body_opens_here else sig
    tail = "\n  {" if body_opens_here else ""

    probed = text[:m.start()] + head + "\n  ensures { true }" + tail + text[m.end():]
    stem = src_path.stem
    probed = probed.replace(f"module src/core/{stem}",
                            f"module tools/verify_classify/generated/{stem}_policy", 1)
    GEN.mkdir(parents=True, exist_ok=True)
    probe = GEN / f"{stem}_policy.ail"
    probe.write_text(probed)

    res = subprocess.run(
        ["ailang", "verify", str(probe.relative_to(ROOT))],
        capture_output=True, text=True, cwd=ROOT)
    probe.unlink(missing_ok=True)

    lines = (res.stdout + res.stderr).splitlines()
    for i, line in enumerate(lines):
        if re.search(rf"\b(VERIFIED|SKIPPED|ERROR)\s+{re.escape(name)}\b", line):
            if "VERIFIED" in line:
                return False, "VERIFIED"
            detail = ""
            for nxt in lines[i + 1:i + 3]:
                if "Reason:" in nxt or "error:" in nxt:
                    detail = nxt.strip()
                    break
            return True, detail or line.strip()

    head_err = next((l for l in lines if "rror" in l), "")
    return None, ("the module did not compile with a trivial contract, so the claim "
                  f"could not be checked. {head_err.strip()}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="main_dst")
    args = ap.parse_args()

    added = added_pure_funcs(args.base)
    if not added:
        print(f"new_contract_policy: no pure func added under src/core/ since {args.base}")
        return 0

    problems = []
    checked = 0
    for path, names in sorted(added.items()):
        text = (ROOT / path).read_text()
        for name in names:
            span = declaration_of(text, name)
            if span is None:
                continue          # added then removed again in a later commit
            checked += 1
            if has_contract(text, name):
                print(f"  ✓ {path} {name}: carries a contract")
                continue

            claim = JUSTIFY_RE.search(text[span[0]:span[1]])
            if not claim:
                problems.append(
                    f"  ✗ {path} {name}: new `pure func` with neither a contract nor a\n"
                    f"      `-- contracts: ...` line saying what blocks one (ADR-001 §4).")
                continue

            rejects, detail = verifier_rejects(path, name)
            short = claim.group("claim").strip()
            if rejects is True:
                print(f"  ✓ {path} {name}: excuse checked -- {short}")
                print(f"      verifier: {detail}")
            elif rejects is False:
                problems.append(
                    f"  ✗ {path} {name}: claims `{short}` but with a trivial contract the\n"
                    f"      verifier returns VERIFIED. The excuse is wrong; write the contract.")
            else:
                problems.append(
                    f"  ✗ {path} {name}: claims `{short}`, and the claim could not be\n"
                    f"      checked -- {detail}\n"
                    f"      An unchecked excuse is as self-asserted as no excuse (ADR-001 §4).")

    if problems:
        print(f"new_contract_policy: {len(problems)} of {checked} new declarations unjustified")
        print("\n".join(problems))
        return 1

    print(f"new_contract_policy: {checked} new pure func declarations, all justified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
