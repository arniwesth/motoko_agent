#!/usr/bin/env python3
"""034 PLAN-001 W3.2: the Phase 3 mutation run.

One source change per rule W3 states, the test expected to fail named before
the run, one mutant at a time (meta-decision
`mutate-each-stated-rule-once-and-see-its-test-fail.md`, standing rule 3).
There is no shared runner; this script is W1.7's (`../mutation-w1-f160eebb/`)
with W3's suites, and implements that document's rules 2, 3 and 6 itself:

- A mutant is KILLED when every test named in its `expect` set is red, in a run
  where every suite compiled and ran to its own summary. Any other test going
  red is recorded in `also_red` and never counts toward the kill.
- A compile error, a run that printed no summary, or a timeout is recorded as
  what it is (`NOT-RUN`), never as a kill.
- The source is green before the first mutant (control C-baseline), the
  mutated file is restored by copy and its sha256 compared with the original,
  and the source is green again after the last (control C-restored). K0, a
  comment-only edit, must leave every suite green.

Every mutant runs the same four suites, so `also_red` is complete for the
code that imports `dst_run_report`:

  inline (`ailang test --json <file>`): dst_run_report, dst_corpus
  rr    `make run_report`'s AILANG suite (run_report_dst)
  cp    `make corpus_pr`'s AILANG suite (corpus_pr_dst), plus two rows the
        script computes from its output: the target's W3.1 wire witness (each
        twin id's wire count is its twin's REPORTCOUNT plus its world-only
        row's), and the bank's REPORTKEYS duplicate count, which must be 0

An inline test is named `suite:function`. A row of a script suite is named
`suite:text`, a fragment of its pass line; it is red when fewer pass lines
carry the fragment than in C-baseline. Digits are compared as `#` (except after
`v` or `/`), so a count that moves inside a passing line is not read as a
failure.

Run it from the worktree root, as a non-root user, on a clean tree at COMMIT:

  python3 .agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-w3-7b822058/mutate.py

`--apply-check` applies each mutant, runs `ailang check` on the file it edits,
and restores it, without running a suite: the spec's own self-test.
"""

import collections
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

COMMIT = "7b822058"
HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = os.path.join(HERE, "runs")
REL = os.path.relpath(HERE)
TIMEOUT = 900
CAPS = "IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace"

RR = "src/core/dst_run_report.ail"
TRACKED = [RR]

INLINE = [("dst_run_report", RR), ("dst_corpus", "src/core/dst_corpus.ail")]
# name, argv, the summary line that says the suite ran to its end
SCRIPTS = [
    ("rr", ["ailang", "run", "--caps", "IO", "--entry", "main", "scripts/dst/run_report_dst.ail"],
     r"^run_report_dst (PASS|FAIL)$"),
    ("cp", ["ailang", "run", "--caps", CAPS, "--ai-stub", "--entry", "main", "scripts/dst/corpus_pr_dst.ail"],
     r"^(✓ WI-A15 commit 1: the blocking PR corpus|✗ WI-A15 commit 1 FAILED)$"),
]
SCRATCH = [".ailang/dst-artifacts", ".ailang/dst-corpus"]

# The rows the plan's W3.2 table names, and the two cp rows computed here.
R1_TEST = "dst_run_report:test_a_world_only_row_is_counted_from_the_effect_log"
R2_TEST = "dst_run_report:test_a_twin_and_its_world_only_row_are_not_counted_together"
R3_TEST = "dst_run_report:test_a_repeated_effect_key_is_one_duplicate"
ZERO_TEST = "dst_run_report:test_no_repeated_effect_key_reports_zero"
R1_BANK = "cp:seed-102: the report counts tool_effect_applied_then_failed from the effect log"
R2_BANK = "cp:seed-102: and not under its twin"
R3_RR = "rr:the duplicate-effect-key count reads 1 on a log with one repeated key"
ZERO_RR = "rr:survival: a log with no repeated key reports 0 duplicates"
WIRE_ROW = "wire: each twin id's wire count is its twin's REPORTCOUNT plus its world-only row's"
KEYS_ROW = "bank: no repeated effect key, and the report counts none"

EOF = "<EOF>"  # an edit whose old string is EOF appends its new string

# id, rule, edit (what the change does, with its site at COMMIT), file,
# [(old, new)] each old occurring exactly once, expected-red tests.
MUTANTS = [
    ("r1", "W3.1 a world-only row is counted from the effect log",
     "dst_run_report.ail:367 class_times: a world-only row is counted from the typed outcome "
     "(interactions whose fault_class_id is its own id, which none records)", RR,
     [("    WorldOnly(twin) => count_partition(xs, applied, twin, true),\n",
       "    WorldOnly(_) => count_class(xs, r.class_id),\n")],
     [R1_TEST, R1_BANK]),
    ("r2", "W3.1 a twin and its world-only row are not counted together",
     "dst_run_report.ail:370 class_times: a twin counts every interaction under its id, "
     "the world-only row's applied ones included", RR,
     [("      if is_a_twin(rows, r.class_id) then count_partition(xs, applied, r.class_id, false)\n",
       "      if is_a_twin(rows, r.class_id) then count_class(xs, r.class_id)\n")],
     [R2_TEST, R2_BANK]),
    ("r3", "W3.1 duplicate effect keys are counted",
     "dst_run_report.ail:499 duplicates_after: counts distinct keys (a key's first entry) "
     "instead of the entries an earlier one repeats", RR,
     [("      if contains_str(seen, e.effect_key) then 1 + duplicates_after(rest, seen)\n"
       "      else duplicates_after(rest, e.effect_key :: seen)\n",
       "      if contains_str(seen, e.effect_key) then duplicates_after(rest, seen)\n"
       "      else 1 + duplicates_after(rest, e.effect_key :: seen)\n")],
     [R3_TEST, R3_RR]),
]

# A survivor's sentence, written after the run measured it (rule 4).
SENTENCES = {}

K0 = ("K0", "control: a comment-only edit", "dst_run_report.ail gains a comment line at its end", RR,
      [(EOF, "-- 034 W3.2 K0: a comment-only edit\n")], [])

# The survival case (rule 5): a log with no repeated key reports 0, inline, in
# the scenario and on the bank; and the report's counts are unchanged where the
# rules hold.
SURVIVAL = [
    ZERO_TEST, ZERO_RR, "cp:" + KEYS_ROW,
    "dst_run_report:test_the_counts_fold_into_both_counters",
    "rr:each world-only row is reached from the effect log, once",
    "cp:on every member, the rows the report counts are the tool rows the class observer reached",
    "cp:on every member, each twin's count plus its world-only row's is the twin id's recorded interactions",
    "cp:" + WIRE_ROW,
]

# `skip` is a contract property with no generator: it ran nothing, and a
# verdict reads a status, never the exit code.
GREEN = ("pass", "skip")

ANSI = re.compile(r"\x1b\[[0-9;]*m")
DIGITS = re.compile(r"(?<![v/])\d+")
TOOL_IDS = ["ToolFailed", "tool_effect_applied_then_failed", "ToolDeadlineExceeded",
            "tool_effect_applied_then_deadline", "ToolCorrelationMismatch"]


def norm(s):
    return DIGITS.sub("#", s)


def sh(cmd, log):
    t0 = time.time()
    env = dict(os.environ)
    env.pop("AILANG_FS_SANDBOX", None)
    try:
        p = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=TIMEOUT, env=env)
        out, rc = p.stdout.decode("utf-8", "replace"), p.returncode
    except subprocess.TimeoutExpired as e:
        out, rc = (e.stdout or b"").decode("utf-8", "replace") + "\n[TIMEOUT]\n", "timeout"
    out = ANSI.sub("", out)
    with open(log, "w") as f:
        # The driver's JSON wire records are the bulk of a run and none is a
        # row; the logs keep the rows and what surrounds them.
        f.write("\n".join(l for l in out.splitlines() if not l.startswith("{")) + "\n")
    return out, rc, time.time() - t0


def inline_suite(name, path, d):
    """{name:test: status} or None when the file did not compile or run."""
    out, rc, _ = sh(["ailang", "test", "--json", "--no-color", path], os.path.join(d, name + ".log"))
    i = out.find("{")
    try:
        doc = json.loads(out[i:]) if i >= 0 else None
    except ValueError:
        doc = None
    if not doc or "tests" not in doc:
        return None, rc
    res = {}
    for t in doc["tests"] + (doc.get("properties") or []):
        res["%s:%s" % (name, re.sub(r"_test_\d+$", "", t["name"]))] = t["status"]
    return res, rc


def report_counts(out):
    counts = {}
    for l in out.splitlines():
        m = re.match(r"^REPORTCOUNT ([A-Za-z_]+)=(\d+)$", l.strip())
        if m:
            counts[m.group(1)] = int(m.group(2))
    return counts


def script_suite(name, cmd, summary, d):
    """{'pass': Counter of normalized pass lines, 'fail': [failing lines]} or None."""
    for s in SCRATCH:
        shutil.rmtree(s, ignore_errors=True)
    out, rc, _ = sh(cmd, os.path.join(d, name + ".log"))
    rows = [l for l in out.splitlines() if not l.startswith("{")]
    if not any(re.match(summary, l.strip()) for l in rows) or "[TIMEOUT]" in out:
        return None, rc
    passed = collections.Counter()
    failed = []
    for l in rows:
        m = re.match(r"\s*([✓✗])\s+(.*)$", l)
        if m and m.group(1) == "✓":
            passed[norm(m.group(2).strip())] += 1
        elif m:
            failed.append(m.group(2).strip())
    if name == "cp":
        # `make corpus_pr`'s 034 W3.1 wire witness, as the target computes it:
        # fault_class occurrences over the whole output, against REPORTCOUNT.
        wire = {c: out.count('"fault_class":"%s"' % c)
                for c in ("ToolFailed", "ToolDeadlineExceeded", "ToolCorrelationMismatch")}
        rc_ = report_counts(out)
        have = all(c in rc_ for c in TOOL_IDS)
        ok = (have and all(rc_[c] > 0 for c in TOOL_IDS[:4])
              and wire["ToolFailed"] == rc_["ToolFailed"] + rc_["tool_effect_applied_then_failed"]
              and wire["ToolDeadlineExceeded"] == rc_["ToolDeadlineExceeded"] + rc_["tool_effect_applied_then_deadline"]
              and wire["ToolCorrelationMismatch"] == rc_["ToolCorrelationMismatch"])
        detail = "wire %s, report %s" % (
            " ".join("%s=%d" % kv for kv in wire.items()),
            " ".join("%s=%s" % (c, rc_.get(c, "absent")) for c in TOOL_IDS))
        if ok:
            passed[norm(WIRE_ROW)] += 1
        else:
            failed.append("%s (%s)" % (WIRE_ROW, detail))
        keys = re.search(r"^REPORTKEYS effects=(\d+) duplicates=(\d+)$", out, re.M)
        if keys and int(keys.group(1)) > 0 and int(keys.group(2)) == 0:
            passed[norm(KEYS_ROW)] += 1
        else:
            failed.append("%s (%s)" % (KEYS_ROW, keys.group(0) if keys else "no REPORTKEYS line"))
        with open(os.path.join(d, name + ".log"), "a") as f:
            f.write("[mutate.py] %s\n[mutate.py] %s\n" % (detail, keys.group(0) if keys else "no REPORTKEYS line"))
    return {"pass": passed, "fail": failed}, rc


def run_suites(d):
    os.makedirs(d, exist_ok=True)
    suites, rcs = {}, {}
    for name, path in INLINE:
        suites[name], rcs[name] = inline_suite(name, path, d)
    for name, cmd, summary in SCRIPTS:
        suites[name], rcs[name] = script_suite(name, cmd, summary, d)
    for s in SCRATCH:
        shutil.rmtree(s, ignore_errors=True)
    return suites, rcs


def is_script(name):
    return any(name == s[0] for s in SCRIPTS)


def found(test, suites, base):
    """Whether the test exists in this run's suite and in the baseline."""
    suite, _, key = test.partition(":")
    s = suites.get(suite)
    if s is None:
        return False
    if is_script(suite):
        return base_count(test, base) > 0
    return test in s


def base_count(test, base):
    suite, _, frag = test.partition(":")
    return sum(n for line, n in base[suite]["pass"].items() if norm(frag) in line)


def is_red(test, suites, base):
    suite, _, frag = test.partition(":")
    s = suites[suite]
    if is_script(suite):
        return sum(n for line, n in s["pass"].items() if norm(frag) in line) < base_count(test, base)
    return s.get(test) not in GREEN


def red_set(suites, base):
    """Every red test: inline tests not passing, and script pass lines lost against the baseline."""
    red = set()
    for name, s in suites.items():
        if s is None:
            continue
        if is_script(name):
            lost = base[name]["pass"] - s["pass"] if base else collections.Counter()
            red |= {"%s:%s" % (name, l) for l in lost}
            red |= {"%s:✗ %s" % (name, norm(l)) for l in s["fail"]}
        else:
            red |= {t for t, st in s.items() if st not in GREEN}
    return red


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def apply(path, edits):
    with open(path) as f:
        src = f.read()
    for old, new in edits:
        if old == EOF:
            src = src + new
            continue
        n = src.count(old)
        if n != 1:
            raise SystemExit("spec error: %r occurs %d times in %s" % (old[:60], n, path))
        src = src.replace(old, new)
    with open(path, "w") as f:
        f.write(src)


def unified_diff(orig, mutated, path):
    p = subprocess.run(["diff", "-u", "--label", "a/" + path, "--label", "b/" + path, orig, mutated],
                       stdout=subprocess.PIPE)
    return p.stdout.decode()


def git(*args):
    return subprocess.run(["git"] + list(args), stdout=subprocess.PIPE, check=True).stdout.decode().strip()


def tree_dirty():
    """Anything git sees changed or untracked outside this evidence directory."""
    lines = git("status", "--porcelain", "--untracked-files=all").splitlines()
    return [l for l in lines if not l[3:].startswith(REL + "/")]


def main():
    apply_check = "--apply-check" in sys.argv
    spec = MUTANTS + [K0]
    if os.getuid() == 0:
        raise SystemExit("run as a non-root user (uid 1001): the W3 gates are run as one")
    head = git("rev-parse", "--short=8", "HEAD")
    if head != COMMIT:
        raise SystemExit("HEAD is %s, this run is for %s" % (head, COMMIT))
    if tree_dirty():
        raise SystemExit("the tree is not clean outside the evidence directory:\n" + "\n".join(tree_dirty()))
    originals = {p: sha(p) for p in TRACKED}

    if apply_check:
        lines = []
        for mid, _, _, path, edits, _ in spec:
            backup = path + ".w32.orig"
            shutil.copyfile(path, backup)
            try:
                apply(path, edits)
                p = subprocess.run(["ailang", "check", path], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                tail = ANSI.sub("", p.stdout.decode()).strip().splitlines()[-1:] if p.returncode else ""
                lines.append("%s\t%s\t%s\t%s" % (mid, path, "compiles" if p.returncode == 0 else "DOES NOT COMPILE", tail))
                print(lines[-1], flush=True)
            finally:
                shutil.copyfile(backup, path)
                os.remove(backup)
            assert sha(path) == originals[path], "restore failed for " + mid
        with open(os.path.join(HERE, "apply-check.txt"), "w") as f:
            f.write("\n".join(lines) + "\n")
        return

    # The predictions are this script's MUTANTS, SURVIVAL and K0: hashed before
    # the first suite runs, and the hash is the run's first line.
    spec_sha = sha(os.path.abspath(__file__))
    print("spec sha256 %s (mutate.py, before any suite ran)" % spec_sha, flush=True)
    shutil.rmtree(RUNS, ignore_errors=True)
    os.makedirs(RUNS)
    rows = []
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    base = {}
    restores = []

    def control(cid, note):
        t0 = time.time()
        suites, rcs = run_suites(os.path.join(RUNS, cid))
        ok = all(s is not None for s in suites.values())
        if cid == "C-baseline" and ok:
            base.update(suites)
        red = red_set(suites, base)
        n = sum(len(s) if not is_script(k) else sum(s["pass"].values()) + len(s["fail"])
                for k, s in suites.items() if s)
        missing_surv = [t for t in SURVIVAL if not ok or not found(t, suites, base) or is_red(t, suites, base)]
        verdict = "PASS" if ok and not red and not missing_surv else "FAIL"
        seen = "%d tests and rows ran, %d red%s; survival rows %s" % (
            n, len(red), (": " + " ".join(sorted(red))) if red else "",
            "all %d green" % len(SURVIVAL) if not missing_surv else "NOT GREEN: " + " | ".join(missing_surv))
        rows.append([cid, "control", note, "none: unmutated source at %s" % COMMIT, "-", "nothing red",
                     seen, verdict, "-", "-", "", "complete" if ok else "NOT-RUN",
                     " ".join("%s=%s" % kv for kv in rcs.items()), "%.0f" % (time.time() - t0)])
        print(cid, verdict, seen, flush=True)
        return verdict == "PASS"

    if not control("C-baseline", "every suite green before the first mutant, survival rows included"):
        write(rows, started, spec_sha, originals, restores)
        raise SystemExit("baseline is not green: no mutant is run")
    for mid, _, _, _, _, expect in spec:
        for t in expect:
            if not found(t, base, base):
                write(rows, started, spec_sha, originals, restores)
                raise SystemExit("spec error: %s's expected test %s is not in the baseline" % (mid, t))

    for mid, rule, edit, path, edits, expect in spec:
        d = os.path.join(RUNS, mid)
        os.makedirs(d)
        backup = os.path.join(d, "orig.ail")
        shutil.copyfile(path, backup)
        t0 = time.time()
        try:
            apply(path, edits)
            mutated_sha = sha(path)
            with open(os.path.join(d, "mutant.diff"), "w") as f:
                f.write(unified_diff(backup, path, path))
            suites, rcs = run_suites(d)
        finally:
            shutil.copyfile(backup, path)
            os.remove(backup)
        restored_sha = sha(path)
        restores.append((mid, path, mutated_sha, restored_sha))
        if restored_sha != originals[path]:
            raise SystemExit("%s: restore left different bytes in %s" % (mid, path))
        complete = all(s is not None for s in suites.values())
        red = red_set(suites, base)
        missing = [t for t in expect if not found(t, suites, base)]
        seen = [t for t in expect if t not in missing and is_red(t, suites, base)]
        expect_keys = set()
        for t in expect:
            suite, _, frag = t.partition(":")
            if is_script(suite):
                expect_keys |= {r for r in red if r.startswith(suite + ":") and norm(frag) in r}
            else:
                expect_keys.add(t)
        also = sorted(red - expect_keys)
        surv_red = [t for t in SURVIVAL if suites.get(t.partition(":")[0]) is not None and is_red(t, suites, base)]
        if mid == "K0":
            verdict = "PASS" if complete and not red else "FAIL"
        elif not complete or missing:
            verdict = "NOT-RUN"
        elif len(seen) == len(expect):
            verdict = "KILL"
        elif seen:
            verdict = "PARTIAL"
        else:
            verdict = "SURVIVED"
        notes = []
        if missing:
            notes.append("expected test not found: " + " ".join(missing))
        if verdict == "SURVIVED" and mid in SENTENCES:
            notes.append(SENTENCES[mid])
        for k, s in suites.items():
            if s is None:
                notes.append("%s did not run to its end (rc=%s): see runs/%s/%s.log" % (k, rcs[k], mid, k))
        rows.append([mid, "control" if mid == "K0" else "mutant", rule, edit, path,
                     " | ".join(expect) if expect else "nothing red",
                     " | ".join(seen) if seen else ("nothing red" if not red else "none of the expected"),
                     verdict, " | ".join(also) if also else "none",
                     " | ".join(surv_red) if surv_red else "none", "; ".join(notes),
                     "complete" if complete else "NOT-RUN", " ".join("%s=%s" % kv for kv in rcs.items()),
                     "%.0f" % (time.time() - t0)])
        print(mid, verdict, "also:", len(also), "survival red:", len(surv_red), flush=True)

    control("C-restored", "every suite green after the last mutant, on the restored source")
    for p in TRACKED:
        assert sha(p) == originals[p], "tree not restored: " + p
    if tree_dirty():
        raise SystemExit("the tree is not clean after the run:\n" + "\n".join(tree_dirty()))
    write(rows, started, spec_sha, originals, restores)


HEAD_COLS = ["id", "kind", "rule", "edit", "file", "expect_red", "seen_red", "verdict", "also_red",
             "survival_red", "notes", "run", "exit", "wall_secs", "commit"]


def write(rows, started, spec_sha, originals, restores):
    with open(os.path.join(HERE, "mutants.tsv"), "w") as f:
        f.write("\t".join(HEAD_COLS) + "\n")
        for r in rows:
            f.write("\t".join(str(c).replace("\t", " ").replace("\n", " ") for c in r + [COMMIT]) + "\n")
    with open(os.path.join(HERE, "meta.txt"), "w") as f:
        f.write("commit\t%s\nuid\t%d\nailang\t%s\nstarted\t%s\nended\t%s\n" % (
            git("rev-parse", "HEAD"), os.getuid(),
            subprocess.run(["ailang", "--version"], stdout=subprocess.PIPE).stdout.decode().split("\n")[0],
            started, time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())))
        f.write("spec_sha256\t%s\tmutate.py, hashed before the first suite ran\n" % spec_sha)
        for p, h in originals.items():
            f.write("original_sha256\t%s\t%s\n" % (p, h))
        for mid, p, m, r in restores:
            f.write("restore\t%s\t%s\tmutated=%s\trestored=%s\t%s\n" % (
                mid, p, m, r, "byte-identical" if r == originals[p] else "DIFFERENT"))
        for p in originals:
            f.write("final_sha256\t%s\t%s\n" % (p, sha(p)))


if __name__ == "__main__":
    main()
