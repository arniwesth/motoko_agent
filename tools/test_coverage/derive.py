#!/usr/bin/env python3
r"""The `ailang test` coverage axis (WI-A17, ADR-001).

`make check_core` type-checks `src/core/*.ail` and never RUNS their inline
tests. **`ailang check` coverage and `ailang test` coverage are separate axes
and only the first had a target.** Cluster 4 found `session.ail`'s 21 tests and
`phase_vocab.ail`'s 27 executed by nothing; at the time this tool was written,
fourteen files under `src/core` carrying inline tests were named by no `make`
target at all.

**The enumeration is a recursive walk, and a list of filenames is the defect
rather than the fix.** A list goes stale the first time a file gains tests and
nobody edits it, and it goes stale silently. So every `.ail` file under
`src/core` is discovered by `rglob` and run, and the coverage question is
answered by construction instead of by a membership test against a hand-kept
roster. `check_core` globs `src/core/*.ail` -- one directory, no recursion --
which is exactly why it never saw `src/core/test/scripted_ports.ail` or
`src/core/ext/runtime.ail`. A single-directory enumeration reproduces that bug,
so `fixtures/nested/` exists to keep the recursion asserted.

## What is authoritative, and why there are two derivations

Test counts come from `ailang test --format json`, which reports
`total_tests`, `passed_tests`, `failed_tests`, `skipped_tests` and a status per
test. That is authoritative in a way a grep is not.

A grep is kept anyway, and the two are **cross-checked per file** (S8). The
handoff that commissioned this work proposed deriving "carries inline tests"
from `^\s+tests \[` alone. A file whose tests use a form that pattern misses
drops out of such an inventory **silently**, and a file that has dropped out
reads identically to a file that never had tests -- the same failure as a
pinned digest certifying only the paths its trajectory walks. That is not
hypothetical here: `src/core/prompts_test.ail` carries six tests in `test
"..."` block form and matches `^\s+tests \[` zero times, so the commissioning
measurement did not list it. `src/core/compress.ail` gets two more tests from
`requires` contracts, which no `tests`-shaped pattern can see.

So the rule is not "trust the grep" and not "drop the grep": it is **the two
derivations must agree, per file, every run** (`undetected` / `phantom`). A
form the pattern misses is now RED rather than absent.

`requires`-derived properties are deliberately NOT in the syntactic pattern. A
`requires` clause is a contract, not a test, and AILANG generating a property
from it is a behaviour this tool does not want to assert. A file carrying only
`requires` therefore trips `undetected` -- which is correct and loud, and is
the direction that fails safe. Putting `requires` in the pattern would instead
risk `phantom` on any contract that generates no property.

## Counts, not exit statuses

`ailang test` **exits 0, and prints "All tests passed!", when every test in the
file was SKIPPED.** Measured at HEAD on v0.26.0: `src/core/prompts_test.ail`
reports `6 tests: 0 passed, 0 failed, 6 skipped`, `"success": true`, exit 0.
Six tests certify nothing and the exit status says they are fine. A target
built on `ailang test X && echo ok` is green over that file.

(The complementary claim -- that `ailang test` exits 0 on a file with ZERO
tests -- is false on this pin: `total_tests: 0` sets `"success": false` and
exits 1. That is the reason a file with no tests must be recognised and passed
over rather than treated as a failure.)

Every rule below therefore reads a NUMBER or a per-test STATUS. None reads the
process exit code.

## Skips: recorded by REASON, never by filename

A skipped test is lost coverage, but not every skip is a defect this repo can
fix, and cluster 13 established that an absence is sometimes deliberate --
`fb_2ad074d754cd2c25` moved a flaky assertion out of a `tests` block into an
acceptance script on purpose, and an inventory that flags that produces a false
positive, false positives get relaxed, and a relaxed inventory is the
hand-maintained list this tool exists to avoid.

The resolution is that **nothing here asserts an expected count for any file**,
so a deliberate absence is structurally invisible to it; and skips are
tolerated by **REASON**, read out of the runner's own output, never by
filename. `skip_reasons.json` records each tolerated reason with a
justification and a disposition. Any skip whose reason is not recorded is red
(`unrecorded_skip`), so a NEW kind of skip cannot arrive quietly.

A record marked `expected: always` that matches no skip in the run is also red
(`stale_skip_record`): either upstream implemented the feature and the tests
should be switched back on, or the tests were deleted. Records marked
`expected: sometimes` are non-deterministic by nature -- a property whose
precondition is usually unsatisfiable may occasionally be satisfied -- and a
stale one is REPORTED, never failed on, because a flaky gate gets relaxed.

**What this tool deliberately does not catch:** a file that had tests and lost
all of them. Both derivations agree on zero and no rule fires. Distinguishing
that from a legitimate deletion needs an expected count per file, which is the
hand-maintained list again. The boundary is stated rather than papered over.

## Rules

Each is separately named so a self-test row can assert ITS OWN rule rather than
"something was reported" -- cluster 14's third mutant sampled one member twice
and omitted another, keeping a length check green, and was caught only by
membership-by-name.

Exit codes: 0 clean, 1 findings, 2 harness error.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

RULES: dict[str, str] = {
    "failing": "a file's inline tests do not all pass",
    "unrunnable": "`ailang test` could not execute the file at all",
    "undetected": "the file has tests the syntactic derivation cannot see",
    "phantom": "the syntactic derivation matched a file with no tests",
    "untracked": "a file that runs locally is not in git, so CI never sees it",
    "unrecorded_skip": "a test was skipped for a reason no record accounts for",
    "stale_skip_record": "a record marked `always` matched no skip in this run",
    "ci_unreachable": "no CI workflow invokes the target that runs this",
    "dst_unreachable": "`make dst` does not invoke the target that runs this",
    "sealing_probe": "the sealed-constructor probe no longer fails with IMP010",
}

# The syntactic derivation. A BOOLEAN per file, never a count: `tests [(a,b),
# (c,d)]` is one match and two tests, so match counts and test counts are
# different quantities and comparing them would fire on every multi-case block.
#
# Only forms a fixture exercises are listed. `ailang test --help` also
# documents `property "name" (x: int) = ...`, and it is deliberately absent:
# no file in this repo uses it, so a pattern for it would be a regex no
# fixture can assert -- and a pattern that is silently wrong is the same
# failure as no pattern at all, only harder to see. A file using the form
# trips `undetected` instead, which is loud and says exactly what to add.
SYNTACTIC_FORMS: dict[str, str] = {
    "tests-block": r"^\s*tests \[",
    "named-test": r"^\s*test \"",
}

# The probe whose FAILURE is its PASS. Its first line reads "This probe is
# expected to FAIL with IMP010: phase_vocab's sealed constructors must not be
# importable outside src/core/phase_vocab.ail", and project 004 records that
# failure as its pass condition. It imports MkHistory and MkPayload
# deliberately; the compiler refusing the import IS the sealing assertion
# holding, and making it compile would invert an invariant held since 004.
#
# The check is on the ERROR CODE and the SYMBOL, not on a non-zero exit. A
# probe that started failing for an unrelated reason -- a syntax error, a
# renamed module -- would satisfy "exit != 0" while asserting nothing about
# sealing. That is S8's negative-control complement: a control rejected by
# clause 1 certifies nothing about clause 2.
SEALING_PROBE = Path("scripts/probe_phase_vocab_sealed.ail")
SEALING_CODE = "IMP010"
SEALING_SYMBOLS = ("MkHistory", "MkPayload")


@dataclass
class Finding:
    rule: str
    subject: str
    detail: str

    def __str__(self) -> str:
        return f"  \u2717 [{self.rule}] {self.subject}\n      {self.detail}"


@dataclass
class FileResult:
    path: Path
    total: int = 0
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    syntactic: bool = False
    forms: list[str] = field(default_factory=list)
    parse_error: bool = False
    harness_error: str = ""
    failures: list[str] = field(default_factory=list)
    skips: list[tuple[str, str]] = field(default_factory=list)


def syntactic_forms(text: str) -> list[str]:
    return [n for n, pat in SYNTACTIC_FORMS.items() if re.search(pat, text, re.M)]


def parse_report(stdout: str) -> dict | None:
    """`ailang test --format json` prefixes the JSON with a progress line."""
    start = stdout.find("{")
    if start < 0:
        return None
    try:
        return json.loads(stdout[start:])
    except json.JSONDecodeError:
        return None


def run_file(path: Path, timeout: int) -> FileResult:
    res = FileResult(path=path)
    try:
        res.forms = syntactic_forms(path.read_text())
    except OSError as exc:
        res.harness_error = f"unreadable: {exc}"
        return res
    res.syntactic = bool(res.forms)

    try:
        proc = subprocess.run(
            ["ailang", "test", "--format", "json", str(path)],
            capture_output=True, text=True, stdin=subprocess.DEVNULL,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        res.harness_error = f"`ailang test` did not finish within {timeout}s"
        return res
    except FileNotFoundError:
        res.harness_error = "`ailang` is not on PATH"
        return res

    report = parse_report(proc.stdout)
    if report is None:
        tail = (proc.stderr or proc.stdout).strip().splitlines()[-3:]
        res.harness_error = "no JSON report; " + " / ".join(tail)
        return res

    res.total = int(report.get("total_tests", 0))
    res.passed = int(report.get("passed_tests", 0))
    res.failed = int(report.get("failed_tests", 0))
    res.skipped = int(report.get("skipped_tests", 0))

    for entry in list(report.get("tests", [])) + list(report.get("properties", [])):
        name = entry.get("name", "?")
        status = entry.get("status", "?")
        # A file that does not parse is reported as a single synthetic failing
        # "test" with an empty location rather than as a compile error, so it
        # would otherwise be indistinguishable from a genuine assertion failure.
        if status == "fail" and not entry.get("location") and name in ("parse", "typecheck", "load"):
            res.parse_error = True
            # The synthetic entry usually carries no `error`, so the compiler's
            # own message is recovered from stderr -- without it the finding
            # says "module failed to parse" and nothing about where.
            detail = entry.get("error") or " / ".join(
                (proc.stderr or "").strip().splitlines()[-2:])
            res.harness_error = detail or f"module failed to {name}"
        elif status == "fail":
            res.failures.append(f"{name} at {entry.get('location', '?')}")
        elif status == "skip":
            res.skips.append((name, entry.get("error", "")))
    return res


def load_skip_records(path: Path) -> list[dict]:
    data = json.loads(path.read_text())
    return data["records"]


def classify(results: list[FileResult], records: list[dict]) -> list[Finding]:
    out: list[Finding] = []
    matched: set[str] = set()

    for r in results:
        rel = str(r.path)
        if r.parse_error or r.harness_error:
            out.append(Finding("unrunnable", rel, r.harness_error))
            continue

        if r.failed:
            out.append(Finding(
                "failing", rel,
                f"{r.failed} of {r.total} failed: " + "; ".join(r.failures[:4])))

        if r.total > 0 and not r.syntactic:
            out.append(Finding(
                "undetected", rel,
                f"`ailang test` reports {r.total} test(s); no syntactic form "
                f"in {sorted(SYNTACTIC_FORMS)} matches. The pattern is blind to "
                f"a form in use -- widen it or the next such file goes missing "
                f"instead of red."))

        if r.total == 0 and r.syntactic:
            out.append(Finding(
                "phantom", rel,
                f"matched {r.forms} but `ailang test` reports no tests. The "
                f"pattern matched something that is not a test block."))

        for name, reason in r.skips:
            rec = next((x for x in records if reason.startswith(x["prefix"])), None)
            if rec is None:
                out.append(Finding(
                    "unrecorded_skip", f"{rel}::{name}",
                    f"skipped with an unrecorded reason: {reason[:160]}"))
            else:
                matched.add(rec["prefix"])

    for rec in records:
        if rec["prefix"] in matched:
            continue
        if rec.get("expected") == "always":
            out.append(Finding(
                "stale_skip_record", rec["prefix"],
                "recorded as always present, but nothing skipped for this "
                "reason. Either it was fixed upstream and the tests should be "
                "switched back on, or the tests are gone. Delete the record or "
                "restore the tests."))
    return out


def check_git_tracking(root: Path, results: list[FileResult]) -> list[Finding]:
    """A file with tests but no git entry runs here and does not exist in CI.

    The inventory's whole claim is "every file carrying tests is run by a
    target CI invokes". A file the working tree has and the repository does not
    satisfies that claim locally and fails it in the only place it matters.
    Files with no tests are ignored: an untracked scratch module is not a
    coverage hole, and reporting it would train people to ignore the rule.
    """
    try:
        proc = subprocess.run(
            ["git", "ls-files", "-z", "--", f"{root}/*.ail"],
            capture_output=True, text=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        return [Finding("untracked", str(root), f"could not list git files: {exc}")]
    tracked = {Path(p) for p in proc.stdout.split("\0") if p}
    return [
        Finding("untracked", str(r.path),
                f"carries {r.total} test(s) and is not tracked by git, so it "
                f"runs on this machine and does not exist in CI")
        for r in sorted(results, key=lambda r: str(r.path))
        if r.total > 0 and r.path not in tracked
    ]


def make_invocations(text: str) -> set[str]:
    """Target names invoked by `make` in `text`, with comments removed first.

    Cluster 14's site 31: a guard greping `MOTOKO_DST_SCALE.*demo` matched the
    workflow's own comment explaining that the string must not appear. A
    comment naming this target does not run it, so comments go before the
    match, not after.
    """
    cleaned = []
    for line in text.splitlines():
        line = re.sub(r"(^|\s)#.*$", "", line)
        cleaned.append(line)
    # `make` in a workflow, `$(MAKE)` in a recipe. Matching only the literal
    # word reported the `dst` recipe as not invoking this target when it plainly
    # did -- a guard that is blind rather than wrong, and it fired on the real
    # tree before a fixture could ask about it.
    targets: set[str] = set()
    for m in re.finditer(r"(?:\bmake\b|\$\(MAKE\))([^\n|;&]*)", "\n".join(cleaned)):
        for tok in m.group(1).split():
            if tok.startswith("-") or "=" in tok or tok.startswith("$"):
                continue
            targets.add(tok)
    return targets


def check_reachability(target: str, workflows: Path, makefile: Path) -> list[Finding]:
    out: list[Finding] = []

    seen_in: list[str] = []
    if workflows.is_dir():
        for wf in sorted(workflows.glob("*.yml")) + sorted(workflows.glob("*.yaml")):
            if target in make_invocations(wf.read_text()):
                seen_in.append(wf.name)
    if not seen_in:
        out.append(Finding(
            "ci_unreachable", target,
            f"no workflow under {workflows} runs `make {target}`. Every file "
            f"this target covers is unrun in CI, which is the defect this "
            f"target exists to close -- one level up."))

    if makefile.is_file():
        text = makefile.read_text()
        m = re.search(r"^dst:\n(?:\t.*\n)+", text, re.M)
        if m is None:
            out.append(Finding("dst_unreachable", target,
                               "could not find the `dst:` recipe in the Makefile"))
        elif target not in make_invocations(m.group(0)):
            out.append(Finding(
                "dst_unreachable", target,
                "`make dst` does not invoke it, so the local gate is blind to "
                "the axis it covers"))
    return out


def check_sealing_probe(probe: Path) -> list[Finding]:
    if not probe.is_file():
        return [Finding("sealing_probe", str(probe),
                        "the probe is missing; the sealing invariant is unasserted")]
    try:
        proc = subprocess.run(["ailang", "check", str(probe)],
                              capture_output=True, text=True,
                              stdin=subprocess.DEVNULL, timeout=120)
    except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
        return [Finding("sealing_probe", str(probe), f"could not run: {exc}")]

    return judge_sealing(proc.returncode, proc.stdout + proc.stderr, probe)


def judge_sealing(returncode: int, output: str, probe: Path) -> list[Finding]:
    """Split out so the self-test can drive it without a compiler run."""
    if returncode == 0:
        return [Finding(
            "sealing_probe", str(probe),
            "the probe COMPILED. Its failure is its pass condition: it imports "
            f"{' and '.join(SEALING_SYMBOLS)} from src/core/phase_vocab "
            "deliberately, and the compiler refusing that import is the sealing "
            "assertion holding. A successful compile means phase_vocab's sealed "
            "constructors are importable from outside, inverting an invariant "
            "held since project 004.")]
    if SEALING_CODE not in output:
        return [Finding(
            "sealing_probe", str(probe),
            f"the probe failed, but not with {SEALING_CODE}. A probe that fails "
            "for an unrelated reason -- a syntax error, a renamed module -- "
            "certifies nothing about sealing while still exiting non-zero. "
            f"Output: {output.strip().splitlines()[-1] if output.strip() else '(empty)'}")]
    if not any(sym in output for sym in SEALING_SYMBOLS):
        return [Finding(
            "sealing_probe", str(probe),
            f"the probe failed with {SEALING_CODE} but named none of "
            f"{SEALING_SYMBOLS}, so the rejected import is not the sealed one")]
    return []


def discover(root: Path) -> list[Path]:
    return sorted(root.rglob("*.ail"))


def run_inventory(root: Path, records: list[dict], jobs: int,
                  timeout: int) -> tuple[list[FileResult], list[Finding]]:
    files = discover(root)
    if jobs > 1:
        with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
            results = list(pool.map(lambda p: run_file(p, timeout), files))
    else:
        results = [run_file(p, timeout) for p in files]
    return results, classify(results, records)


def report(results: list[FileResult], findings: list[Finding], root: Path) -> None:
    with_tests = [r for r in results if r.total > 0]
    total = sum(r.total for r in results)
    ran = sum(r.passed for r in results)
    skipped = sum(r.skipped for r in results)

    for r in sorted(with_tests, key=lambda r: str(r.path)):
        mark = "\u2713" if not r.failed and not r.parse_error else "\u2717"
        note = f" ({r.skipped} skipped)" if r.skipped else ""
        print(f"  {mark} {r.path}: {r.passed}/{r.total} passed{note}")

    print()
    print(f"{root}: {len(results)} .ail files discovered, {len(with_tests)} carry "
          f"tests, {total} tests, {ran} passed, {skipped} skipped")

    if findings:
        print()
        by_rule: dict[str, list[Finding]] = {}
        for f in findings:
            by_rule.setdefault(f.rule, []).append(f)
        for rule in RULES:
            for f in by_rule.get(rule, []):
                print(f)
        print()
        print(f"test_coverage: {len(findings)} finding(s) across "
              f"{len(by_rule)} rule(s): {', '.join(sorted(by_rule))}")
    else:
        # `ran` rather than `total`, and the skipped count named rather than
        # folded in: "every test passed" over a file whose suite was skipped is
        # the exact sentence `ailang test` prints and the reason this tool
        # exists. Every skip here is accounted for by a record in
        # skip_reasons.json -- that is what makes the run green, not silence.
        tail = f", {skipped} skipped against a record" if skipped else ""
        print(f"test_coverage: every file carrying inline tests was run; "
              f"{ran} of {total} passed{tail}")


# ---------------------------------------------------------------------------
# Self-test (C5). One fixture per rule the fixture suite can express, each
# asserted BY ITS OWN RULE NAME, plus survivors that must not be reported at
# all -- mutation testing proves a guard CAN fire and cannot see a guard that
# fires TOO MUCH (S7).
# ---------------------------------------------------------------------------

# The fixture table's `expected` is the set of rules that fixture must fire,
# matched by NAME. A count would be satisfied by firing one rule twice and
# another not at all -- cluster 14's third mutant exactly.
EXPECTED: dict[str, set[str]] = {
    "control_has_tests.ail": set(),
    "nested/nested_has_tests.ail": set(),
    "no_tests.ail": set(),
    "skip_recorded.ail": set(),
    "named_only.ail": set(),
    "failing_test.ail": {"failing"},
    "unrunnable.ail": {"unrunnable"},
    "undetected_form.ail": {"undetected"},
    "phantom_pattern.ail": {"phantom"},
    "skip_unrecorded.ail": {"unrecorded_skip"},
}

# The self-test's own skip table records ONLY the named-test-block limitation,
# so skip_recorded.ail survives and skip_unrecorded.ail -- which skips for a
# different reason -- fires. Both directions of the table are exercised by real
# skips rather than by a stubbed reason string.
SELFTEST_RECORDS = [{
    "prefix": "Named test blocks not yet implemented",
    "expected": "always",
}]

# S7's distinctness obligation, named rather than inferred: these are the pairs
# of quantities that different rules read and could therefore be confused for
# one another. Each needs a fixture where the two differ, in both directions
# where both directions are possible.
DISCRIMINATED_PAIRS = [("failed", "skipped"), ("passed", "total")]


def self_test(repo: Path, timeout: int, jobs: int) -> int:
    fixtures = repo / "tools" / "test_coverage" / "fixtures"
    if not fixtures.is_dir():
        print(f"self-test: no fixture directory at {fixtures}", file=sys.stderr)
        return 2

    results, findings = run_inventory(fixtures, SELFTEST_RECORDS, jobs, timeout)
    fails: list[str] = []

    by_file: dict[str, set[str]] = {}
    for f in findings:
        rel = f.subject.split("::")[0]
        try:
            key = str(Path(rel).relative_to(fixtures))
        except ValueError:
            fails.append(f"finding on an unexpected subject: {f.subject} [{f.rule}]")
            continue
        by_file.setdefault(key, set()).add(f.rule)

    # A survivor that was never DISCOVERED reads exactly like a survivor that
    # was discovered and not reported, so "not in the findings" is not enough:
    # changing `rglob` to `glob` drops fixtures/nested/ from the walk and every
    # row below still passes. The enumeration is therefore asserted directly,
    # by name. This is cluster 14's third mutant -- absence indistinguishable
    # from correctness -- arriving on the fixture suite itself.
    discovered = {str(Path(str(r.path)).relative_to(fixtures)) for r in results}
    if discovered != set(EXPECTED):
        missing, extra = sorted(set(EXPECTED) - discovered), sorted(discovered - set(EXPECTED))
        fails.append(f"the walk did not discover exactly the fixture set: "
                     f"missing {missing}, unexpected {extra}")
    else:
        print(f"  ✓ the walk discovered all {len(discovered)} fixtures, "
              f"including {sum('/' in n for n in discovered)} below the top level")

    seen = set(by_file) | set(EXPECTED)
    for name in sorted(seen):
        want = EXPECTED.get(name)
        got = by_file.get(name, set())
        if want is None:
            fails.append(f"{name}: fixture is not in the expected table (got {sorted(got)})")
        elif want != got:
            missing, extra = sorted(want - got), sorted(got - want)
            bits = []
            if missing:
                bits.append(f"did not fire {missing}")
            if extra:
                bits.append(f"also fired {extra}")
            fails.append(f"{name}: " + "; ".join(bits))
        else:
            kind = "survives" if not want else f"fires {sorted(want)}"
            print(f"  \u2713 {name} {kind}")

    # Every rule the fixture suite is meant to cover has a fixture. Adding a
    # rule without a fixture is red, so the suite cannot silently fall behind
    # the rule set.
    fixture_rules = {r for rules in EXPECTED.values() for r in rules}
    constructed = {"untracked", "stale_skip_record", "ci_unreachable",
                   "dst_unreachable", "sealing_probe"}
    uncovered = set(RULES) - fixture_rules - constructed
    if uncovered:
        fails.append(f"rules with no fixture and no constructed row: {sorted(uncovered)}")
    else:
        print(f"  \u2713 all {len(RULES)} rules are covered by a fixture or a "
              f"constructed row")

    # S7: the quantities different rules read must be unequal somewhere, or a
    # rule reading the wrong one looks right.
    quantities = {str(Path(str(r.path)).relative_to(fixtures)):
                  {"total": r.total, "passed": r.passed,
                   "failed": r.failed, "skipped": r.skipped}
                  for r in results}
    for a, b in DISCRIMINATED_PAIRS:
        witnesses = [n for n, q in quantities.items() if q[a] != q[b]]
        if not witnesses:
            fails.append(f"no fixture distinguishes `{a}` from `{b}`; a rule "
                         f"reading one where it means the other would pass")
        else:
            print(f"  \u2713 `{a}` and `{b}` differ in {len(witnesses)} fixture(s)")

    fails.extend(_constructed_rows())

    print(f"\nself-test: {len(fails)} failure(s)")
    for f in fails:
        print(f"  \u2717 {f}")
    return 1 if fails else 0


def _constructed_rows() -> list[str]:
    """Rows for rules no `.ail` fixture can express, driven by constructed input."""
    fails: list[str] = []

    def row(label: str, got: list[Finding], want: set[str]) -> None:
        rules = {f.rule for f in got}
        if rules == want:
            print(f"  \u2713 {label}")
        else:
            fails.append(f"{label}: expected {sorted(want)}, got {sorted(rules)}")

    probe = Path("scripts/probe_phase_vocab_sealed.ail")

    # `judge_sealing` has three clauses -- exit status, error code, symbol --
    # and each control below is built to be rejected by ITS OWN clause and to
    # SATISFY the other two. That is not fussiness: the first version of these
    # rows passed `(0, "")` for the compiling case, which clause 2 rejects for
    # having no IMP010, so the row stayed green when clause 1 was deleted. A
    # control rejected by an earlier clause certifies nothing about a later one
    # (S8's complement, site 23), and C5 caught both rows here.
    row("a probe that COMPILES fires sealing_probe (clause 1 alone)",
        judge_sealing(0, "IMP010: symbol 'MkHistory' not exported", probe),
        {"sealing_probe"})
    row("a probe failing with the wrong code fires sealing_probe (clause 2 alone)",
        judge_sealing(1, "Error: PAR_UNEXPECTED_TOKEN near MkHistory", probe),
        {"sealing_probe"})
    row("a probe failing IMP010 on some other symbol fires sealing_probe (clause 3 alone)",
        judge_sealing(1, "Error: IMP010: symbol 'Unrelated' not exported", probe),
        {"sealing_probe"})
    row("a probe failing IMP010 on the sealed symbol survives (all three clauses)",
        judge_sealing(1, "Error: IMP010: symbol 'MkHistory' not exported", probe), set())

    # ci_unreachable / dst_unreachable, and the site-31 trap: a comment naming
    # the target must not satisfy the rule.
    commented = "jobs:\n  a:\n    steps:\n      # run: make test_coverage one day\n      - run: make check_core\n"
    real = "jobs:\n  a:\n    steps:\n      - run: make test_coverage\n"
    if "test_coverage" in make_invocations(commented):
        fails.append("a commented-out `make test_coverage` counted as an invocation")
    else:
        print("  \u2713 a commented-out invocation does not satisfy ci_unreachable")
    if "test_coverage" not in make_invocations(real):
        fails.append("a real `run: make test_coverage` was not recognised")
    else:
        print("  \u2713 a real invocation is recognised")
    recipe = "dst:\n\t+$(MAKE) --keep-going conformance test_coverage smoke_driver\n"
    if "test_coverage" not in make_invocations(recipe):
        fails.append("a `$(MAKE)` recipe invocation was not recognised")
    else:
        print("  \u2713 a `$(MAKE)` recipe invocation is recognised")

    # stale_skip_record, both dispositions.
    always = [{"prefix": "Never Happens", "expected": "always"}]
    sometimes = [{"prefix": "Never Happens", "expected": "sometimes"}]
    empty = [FileResult(path=Path("x.ail"), total=1, passed=1, syntactic=True,
                        forms=["tests-block"])]
    row("an `always` record matching nothing fires stale_skip_record",
        classify(empty, always), {"stale_skip_record"})
    row("a `sometimes` record matching nothing is not a failure",
        classify(empty, sometimes), set())
    return fails


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default="src/core",
                    help="directory walked recursively for .ail files")
    ap.add_argument("--target", default="test_coverage",
                    help="the make target whose CI reachability is checked")
    # Serial by default, and measured rather than assumed: over src/core at
    # HEAD, --jobs 1 takes 3m40 and --jobs 4 takes 4m10 while burning twice the
    # CPU (4m27 user vs 9m08). Concurrent `ailang test` processes contend on
    # the shared compile cache and lose more to recompilation than they gain
    # from the cores. The flag stays because that balance is a property of the
    # toolchain, not a law.
    ap.add_argument("--jobs", type=int, default=1,
                    help="parallel `ailang test` processes (measured slower above 1)")
    ap.add_argument("--timeout", type=int, default=300,
                    help="per-file timeout in seconds")
    ap.add_argument("--self-test", action="store_true",
                    help="run the fixture suite instead of the inventory")
    args = ap.parse_args()

    repo = Path(__file__).resolve().parents[2]
    if Path.cwd() != repo:
        print(f"note: running from {repo}", file=sys.stderr)

    if args.self_test:
        return self_test(repo, args.timeout, args.jobs)

    records = load_skip_records(repo / "tools" / "test_coverage" / "skip_reasons.json")
    root = Path(args.root)
    if not root.is_dir():
        print(f"no such directory: {root}", file=sys.stderr)
        return 2

    results, findings = run_inventory(root, records, args.jobs, args.timeout)
    findings += check_git_tracking(root, results)
    findings += check_reachability(args.target, Path(".github/workflows"),
                                   Path("Makefile"))
    findings += check_sealing_probe(SEALING_PROBE)
    report(results, findings, root)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
