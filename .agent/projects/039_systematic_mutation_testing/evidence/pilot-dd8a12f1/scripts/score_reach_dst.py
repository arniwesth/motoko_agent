#!/usr/bin/env python3
"""039 random-mutant pilot, follow-up F1: reach probes read under a full `make dst`.

    score_reach_dst.py <scratch root> <id>...   read runs/dst/<id>/ for each probe id
    score_reach_dst.py selftest

Tier 2 ran each probe under `make corpus_judge` only. F1 runs the same probes (fixed_edits.py,
unchanged) under `make dst`, so "not reached" can be read against the whole suite.

A probe REACHES its site under make dst when the sweep's log holds the probe's own runtime error,
`RT001: integer division by zero at <file>:<line>:<col>`, at the probe's file and line. The line
is where the probe's anchor text starts in the unmutated file. Nothing else counts as reach: a probe
adds a statement, so a static check (a contract, a line pin) can go red without the site running.
Each hit is attributed to the make target whose `*** [Makefile:N: <target>]` failure line follows
it in the log (make dst syncs output per target).

Readings:
  REACHED      the probe's error is in the log; the targets that printed it are listed
  NOT REACHED  the sweep finished, no probe error, and no target is newly red against C-base
  READ BY HAND the sweep finished, no probe error, but a target is newly red: read its output
  INCOMPLETE   no summary block, or a timeout
"""
import os
import re
import sys

E = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(E, "scripts"))
import fixed_edits  # noqa: E402
import score_dst  # noqa: E402

FAIL_LINE = re.compile(r"\*\*\* \[Makefile:\d+: ([^\]]+)\]")


def probe_location(root, pid):
    rows = [e for e in fixed_edits.EDITS if e[0] == pid]
    assert len(rows) == 1, pid
    _, path, anchor, old, _new, _what = rows[0]
    text = open(os.path.join(root, path), encoding="utf-8").read()
    start = text.index(anchor) if anchor else 0
    i = text.index(old, start)
    if not anchor:
        assert text.count(old) == 1, (pid, "old text not unique")
    return path, text[:i].count("\n") + 1


def hits(text, path, line):
    pat = re.compile(r"RT001: integer division by zero at (?:\S*/)?" + re.escape(path) + ":" + str(line) + r":\d+")
    out = []
    lines = text.splitlines()
    for n, l in enumerate(lines):
        if pat.search(l):
            target = "unattributed"
            for later in lines[n + 1:]:
                m = FAIL_LINE.search(later)
                if m:
                    target = m.group(1)
                    break
            out.append(target)
    return out


def read(text, rc, path, line, base_failed):
    if rc == 124:
        return "INCOMPLETE", [], []
    failed = score_dst.parse(text)
    if failed is None:
        return "INCOMPLETE", [], []
    new = sorted(failed - base_failed)
    h = hits(text, path, line)
    if h:
        return "REACHED", sorted(set(h)), new
    if new:
        return "READ BY HAND", [], new
    return "NOT REACHED", [], new


def selftest():
    base = {"declared_vs_performed"}
    summ_ok = "\n─── make dst ───\n  FAILED (1):\n    declared_vs_performed        known-red — listed\n"
    summ_new = "\n─── make dst ───\n  FAILED (2):\n    park_resume                  NEW — this one is yours\n    declared_vs_performed        known-red — listed\n"
    err = "Error: execution failed: RT001: integer division by zero at src/core/session.ail:2761:30\n"
    cases = [
        ("probe error, attributed", "x\n" + err + "make[2]: *** [Makefile:900: park_resume] Error 1\n" + summ_new, 2, "REACHED", ["park_resume"]),
        ("probe error, absolute path", "x\nError: execution failed: RT001: integer division by zero at /w/s/src/core/session.ail:2761:30\nmake[2]: *** [Makefile:9: a] Error 1\n" + summ_new, 2, "REACHED", ["a"]),
        ("division by zero at another line is not this probe", "x\n" + err.replace(":2761:", ":2762:") + "make[2]: *** [Makefile:900: park_resume] Error 1\n" + summ_new, 2, "READ BY HAND", []),
        ("another file, same line", "x\n" + err.replace("session.ail", "tool_phase.ail") + summ_ok, 2, "NOT REACHED", []),
        ("clean sweep", "x\n" + summ_ok, 2, "NOT REACHED", []),
        ("new red, no probe error", "x\nmake[2]: *** [Makefile:445: verify_core] Error 1\n" + summ_new, 2, "READ BY HAND", []),
        ("no summary", "partial", 2, "INCOMPLETE", []),
        ("timeout", "x\n" + err + summ_new, 124, "INCOMPLETE", []),
        ("error with no failure line after it", "x\n" + err + summ_ok, 2, "REACHED", ["unattributed"]),
    ]
    ok = True
    for name, text, rc, want, want_t in cases:
        got, targets, _ = read(text, rc, "src/core/session.ail", 2761, base)
        good = got == want and targets == want_t
        ok &= good
        print(f"{'ok  ' if good else 'FAIL'} {name}: {got} {targets}")
    print("score_reach_dst selftest:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["selftest"]:
        sys.exit(selftest())
    root, ids = a[0], a[1:]
    btext, _, _ = score_dst.read("C-base")
    base = score_dst.parse(btext)
    print("probe\tlocation\treading\ttargets_that_printed_the_probe_error\tnew_red_vs_C-base\trc\twall_secs")
    for pid in ids:
        path, line = probe_location(root, pid)
        text, rc, wall = score_dst.read(pid)
        st, targets, new = read(text, rc, path, line, base)
        print(f"{pid}\t{path}:{line}\t{st}\t{' '.join(targets) or '-'}\t{' '.join(new) or '-'}\t{rc}\t{wall}")
