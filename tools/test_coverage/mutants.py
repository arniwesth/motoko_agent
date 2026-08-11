#!/usr/bin/env python3
"""C5 mutation testing for tools/test_coverage/derive.py.

Each row breaks exactly ONE guard in the implementation and requires the
self-test to go red naming the fixture that guard owns. A mutant that leaves
the self-test green is an escape.

The last row is the S7 direction -- a guard that fires TOO MUCH -- which
mutation testing cannot see on its own and only the survivors can catch.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path("/workspaces/motoko_agent")
SRC = REPO / "tools" / "test_coverage" / "derive.py"
BACKUP = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/derive.orig.py")

MUTANTS = [
    ("M1  failing disabled",
     "        if r.failed:", "        if False:", "failing_test.ail"),
    ("M2  unrunnable disabled",
     "        if r.parse_error or r.harness_error:", "        if False:", "unrunnable.ail"),
    ("M3  undetected disabled",
     "        if r.total > 0 and not r.syntactic:", "        if False:", "undetected_form.ail"),
    ("M4  phantom disabled",
     "        if r.total == 0 and r.syntactic:", "        if False:", "phantom_pattern.ail"),
    # Disabling the lookup rather than the branch: `if rec is None` -> `if
    # False` makes the else-branch dereference None and the self-test goes red
    # on a CRASH, which is not the guard firing. A mutant must break the rule,
    # not the harness.
    ("M5  unrecorded_skip disabled",
     '            rec = next((x for x in records if reason.startswith(x["prefix"])), None)',
     "            rec = records[0] if records else None", "skip_unrecorded.ail"),
    ("M6  stale_skip_record disabled",
     '        if rec.get("expected") == "always":', "        if False:", "stale_skip_record"),
    ("M7  sealing: a compiling probe accepted",
     "    if returncode == 0:", "    if False:", "COMPILES"),
    ("M8  sealing: wrong error code accepted",
     "    if SEALING_CODE not in output:", "    if False:", "wrong code"),
    ("M9  sealing: wrong symbol accepted",
     "    if not any(sym in output for sym in SEALING_SYMBOLS):", "    if False:",
     "other symbol"),
    ("M10 workflow comments not stripped",
     '        line = re.sub(r"(^|\\s)#.*$", "", line)', "        pass", "commented-out"),
    ("M11 walk not recursive",
     "    return sorted(root.rglob(\"*.ail\"))", "    return sorted(root.glob(\"*.ail\"))",
     "discover"),
    ("M12 named-test form dropped",
     '    "named-test": r"^\\s*test \\"",', "", "named_only.ail"),
    ("M13 tests-block form dropped",
     '    "tests-block": r"^\\s*tests \\[",', "", "control_has_tests.ail"),
    # S7: over-firing. Mutation testing structurally cannot catch this -- every
    # mutant produces its own rule -- and only a fixture that must SURVIVE can.
    ("M14 failing fires on everything (over-firing)",
     "        if r.failed:", "        if True:", "control_has_tests.ail"),
]


def run_selftest() -> tuple[int, str]:
    p = subprocess.run([sys.executable, str(SRC), "--self-test"],
                       capture_output=True, text=True, cwd=REPO)
    return p.returncode, p.stdout + p.stderr


def main() -> int:
    shutil.copy(SRC, BACKUP)
    orig = SRC.read_text()
    escapes = []
    try:
        for label, old, new, witness in MUTANTS:
            if old not in orig:
                escapes.append(f"{label}: PATTERN NOT FOUND -- mutant never applied")
                print(f"  ! {label}: pattern not found")
                continue
            SRC.write_text(orig.replace(old, new, 1))
            rc, out = run_selftest()
            named = witness in out
            if rc != 0 and named:
                print(f"  ✓ {label} -> red, names `{witness}`")
            elif rc != 0:
                escapes.append(f"{label}: red but did not name `{witness}`")
                print(f"  ! {label}: red, but `{witness}` not named")
            else:
                escapes.append(f"{label}: ESCAPED (self-test still green)")
                print(f"  ✗ {label}: ESCAPED")
    finally:
        SRC.write_text(orig)

    rc, out = run_selftest()
    print(f"\nrestored: self-test exit {rc}")
    print(f"mutants: {len(MUTANTS)}, escapes: {len(escapes)}")
    for e in escapes:
        print(f"  ✗ {e}")
    return 1 if escapes or rc != 0 else 0


if __name__ == "__main__":
    sys.exit(main())
