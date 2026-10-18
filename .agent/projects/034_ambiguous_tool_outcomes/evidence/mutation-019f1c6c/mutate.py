#!/usr/bin/env python3
"""034 PLAN-001 W0.6: the Phase 0 mutation run.

One source change per stated rule, the test expected to fail named before the
run, one mutant at a time (meta-decision
`mutate-each-stated-rule-once-and-see-its-test-fail.md`). There is no shared
runner; this script implements that document's rules 2, 3 and 6 itself:

- A mutant is KILLED when every test named in its `expect` set is red, in a run
  that compiled and ran to its own end. Any other test going red is recorded in
  `also_red` and never counts toward the kill.
- A compile error, a run that printed no summary, or a timeout is recorded as
  what it is (`NOT-RUN`), never as a kill.
- The source is green before the first mutant (control C-baseline), every
  mutated file is restored by copy and its sha256 compared with the original,
  and the source is green again after the last (control C-restored).

Each mutant runs the same three suites, so `also_red` is complete:

  tool_fault  `ailang test --json src/core/tool_fault.ail` (W0.2's mapping rows)
  adapter     `ailang test --json src/core/tool_dispatch_adapter.ail` (W0.3's)
  w05         `make world_state`'s `fault_disclosure_witness` entry (W0.5 rows a-p)

Run it from the repository root, as a non-root user, on a clean tree:

  python3 .agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-019f1c6c/mutate.py

`--apply-check` applies each mutant, runs `ailang check` on the file it edits,
and restores it, without running a suite: the spec's own self-test.

`--followup` runs the #277 review's follow-up instead, at FOLLOWUP_COMMIT:
its own controls, the mutants in FOLLOWUP, and a fourth suite,

  runtime     `ailang test --json src/core/tool_runtime.ail` (`search_argv`'s test)

with W0.5 at rows a-s. It rewrites `mutants.tsv` keeping every row of the
first run except the `s-rg` survivor, which m36 replaces with a measured
result, and appends its own rows, each naming FOLLOWUP_COMMIT. Its meta and
self-test go to `meta-followup.txt` and `apply-check-followup.txt`.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

COMMIT = "019f1c6c"
FOLLOWUP_COMMIT = "d3047dd1"
HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = os.path.join(HERE, "runs")
TIMEOUT = 300

RT = "src/core/tool_runtime.ail"
TF = "src/core/tool_fault.ail"
AD = "src/core/tool_dispatch_adapter.ail"
WITNESS = "scripts/dst/world_state_probe.ail"
TRACKED = [RT, TF, AD, WITNESS]

UNKNOWN_REFUSAL = "fault: { kind: refused_fault().kind, effects: EffectsUnknown }"

# id, rule, edit (what the change does, with its site at COMMIT), file,
# [(old, new)] each old occurring exactly once, expected-red tests.
MUTANTS = [
    ("m01", "D2 SpawnFailed -> unknown", "process_error_effects maps SpawnFailed to none", TF,
     [("    SpawnFailed(_) => EffectsUnknown,", "    SpawnFailed(_) => EffectsNone,")],
     ["tool_fault:t_effects_spawn_failed"]),
    ("m02", "D2 PermissionDenied -> unknown (ruling 3)", "process_error_effects maps PermissionDenied to none", TF,
     [("    PermissionDenied(_) => EffectsUnknown,", "    PermissionDenied(_) => EffectsNone,")],
     ["tool_fault:t_effects_permission_denied"]),
    ("m03", "D2 Timeout -> unknown", "process_error_effects maps Timeout to none", TF,
     [("    Timeout(_) => EffectsUnknown,", "    Timeout(_) => EffectsNone,")],
     ["tool_fault:t_effects_timeout"]),
    ("m04", "D2 OutputLimitExceeded -> unknown", "process_error_effects maps OutputLimitExceeded to none", TF,
     [("    OutputLimitExceeded(_) => EffectsUnknown,", "    OutputLimitExceeded(_) => EffectsNone,")],
     ["tool_fault:t_effects_output_limit_exceeded"]),
    ("m05", "D2 AbnormalExit -> unknown", "process_error_effects maps AbnormalExit to none", TF,
     [("    AbnormalExit(_, _) => EffectsUnknown\n", "    AbnormalExit(_, _) => EffectsNone\n")],
     ["tool_fault:t_effects_abnormal_exit", "w05:a"]),
    ("m06", "D2 NotFound -> none", "process_error_effects maps NotFound to unknown", TF,
     [("    NotFound(_) => EffectsNone,", "    NotFound(_) => EffectsUnknown,")],
     ["tool_fault:t_effects_not_found", "w05:b"]),
    ("m07", "D2 NotAllowed -> none (ruling 2)", "process_error_effects maps NotAllowed to unknown", TF,
     [("    NotAllowed(_) => EffectsNone,", "    NotAllowed(_) => EffectsUnknown,")],
     ["tool_fault:t_effects_not_allowed"]),
    ("m08", "D2 WriteFile after mkdirAllResult -> unknown", "tool_runtime.ail:705 (plan :701) the mkdirAllResult Err fault is none", RT,
     [('fault: io_error_fault(EffectsUnknown), message: "cannot create parent directory',
       'fault: io_error_fault(EffectsNone), message: "cannot create parent directory')],
     ["w05:d"]),
    ("m09", "D2 WriteFile after writeFileResult -> unknown", "tool_runtime.ail:707 (plan :703) the writeFileResult Err fault is none", RT,
     [('tool: "WriteFile", fault: io_error_fault(EffectsUnknown), message: msg',
       'tool: "WriteFile", fault: io_error_fault(EffectsNone), message: msg')],
     ["w05:e"]),
    ("m10", "D2 EditFile after atomic_write -> unknown", "tool_runtime.ail:903 (plan :899) the atomic_write Err fault is none", RT,
     [('tool: "EditFile", fault: io_error_fault(EffectsUnknown), message: msg',
       'tool: "EditFile", fault: io_error_fault(EffectsNone), message: msg')],
     ["w05:f"]),
    ("m11", "D2 a refusal before the effect -> none", "tool_runtime.ail:881 (plan :877) the expected_sha256 refusal is unknown", RT,
     [('fault: refused_fault(), message: "expected_sha256 mismatch"',
       UNKNOWN_REFUSAL + ', message: "expected_sha256 mismatch"')],
     ["w05:g"]),
    ("m12", "D2 read-only failure -> none", "tool_runtime.ail:530 (plan :529) the ReadFile Err fault is unknown", RT,
     [('tool: "ReadFile", fault: io_error_fault(EffectsNone), message: msg',
       'tool: "ReadFile", fault: io_error_fault(EffectsUnknown), message: msg')],
     ["w05:h"]),
    ("m13", "D1 a call that ran to its own exit carries no disclosure",
     "tool_dispatch_adapter.ail:219 fault_field renders a fault on the Ok arm (fault = None)", AD,
     [("    None => []\n", "    None => [kv(fault_key(), fault_to_json(io_error_fault(EffectsUnknown)))]\n")],
     ["adapter:t_bash_ok_unchanged", "adapter:t_run_tests_ok_unchanged", "w05:c"]),
    ("m13b", "D1 a call that ran to its own exit carries no disclosure (added: the construction site)",
     "tool_runtime.ail:952 to_bash_result, the Ok arm, constructs Some(fault)", RT,
     [("  BashExecResult({\n    id: id,\n    fault: None,\n",
       "  BashExecResult({\n    id: id,\n    fault: Some(io_error_fault(EffectsUnknown)),\n")],
     ["w05:c"]),
    ("m14", "D3 as tightened in W0.3: fault precedes every unbounded field",
     "tool_dispatch_adapter.ail:151-154 BashExecResult renders cmd before fault", AD,
     [('      [kv("tool", js("BashExec"))]\n      ++ fault_field(r.fault)\n      ++ [\n        kv("cmd", js(r.cmd)),\n',
       '      [kv("tool", js("BashExec")), kv("cmd", js(r.cmd))]\n      ++ fault_field(r.fault)\n      ++ [\n')],
     ["adapter:t_long_cmd_keeps_fault"]),
    ("m15", "D3 every harness-reported fault carries effects",
     "tool_dispatch_adapter.ail:174 ToolErrorResult renders no fault", AD,
     [("      kv(fault_key(), fault_to_json(r.fault)),\n", "")],
     ["adapter:t_tool_error_renders_fault"]),
    ("m16", "C3 kind of NotAllowed", "process_error_fault_kind maps NotAllowed to FaultNotFound", TF,
     [("    NotAllowed(_) => FaultNotAllowed,", "    NotAllowed(_) => FaultNotFound,")],
     ["tool_fault:t_kind_not_allowed"]),
    ("m17", "C3 kind of NotFound", "process_error_fault_kind maps NotFound to FaultNotAllowed", TF,
     [("    NotFound(_) => FaultNotFound,", "    NotFound(_) => FaultNotAllowed,")],
     ["tool_fault:t_kind_not_found"]),
    ("m18", "C3 kind of PermissionDenied", "process_error_fault_kind maps PermissionDenied to FaultSpawnFailed", TF,
     [("    PermissionDenied(_) => FaultPermissionDenied,", "    PermissionDenied(_) => FaultSpawnFailed,")],
     ["tool_fault:t_kind_permission_denied"]),
    ("m19", "C3 kind of SpawnFailed", "process_error_fault_kind maps SpawnFailed to FaultPermissionDenied", TF,
     [("    SpawnFailed(_) => FaultSpawnFailed,", "    SpawnFailed(_) => FaultPermissionDenied,")],
     ["tool_fault:t_kind_spawn_failed"]),
    ("m20", "C3 kind of Timeout", "process_error_fault_kind maps Timeout(ms) to FaultOutputLimit(ms)", TF,
     [("    Timeout(ms) => FaultDeadline(ms),", "    Timeout(ms) => FaultOutputLimit(ms),")],
     ["tool_fault:t_kind_timeout"]),
    ("m21", "C3 kind of OutputLimitExceeded", "process_error_fault_kind maps OutputLimitExceeded(n) to FaultDeadline(n)", TF,
     [("    OutputLimitExceeded(n) => FaultOutputLimit(n),", "    OutputLimitExceeded(n) => FaultDeadline(n),")],
     ["tool_fault:t_kind_output_limit_exceeded"]),
    ("m22", "C3 kind of AbnormalExit", "process_error_fault_kind maps AbnormalExit to FaultSpawnFailed", TF,
     [("    AbnormalExit(sig, name) => FaultSignal(sig, name)\n", "    AbnormalExit(_, _) => FaultSpawnFailed\n")],
     ["tool_fault:t_kind_abnormal_exit"]),
    ("m23", "D2 refusal -> none, unknown tool", "tool_runtime.ail:249 (plan :248) the unknown-tool refusal is unknown", RT,
     [('fault: refused_fault(), message: "${call.tool} requires extension',
       UNKNOWN_REFUSAL + ', message: "${call.tool} requires extension')],
     ["w05:i"]),
    ("m24", "D2 refusal -> none, path_error", "tool_runtime.ail:405 (plan :404) path_error's refusal is unknown", RT,
     [("ToolErrorResult({ id: id, tool: tool, fault: refused_fault(), message: message })",
       "ToolErrorResult({ id: id, tool: tool, " + UNKNOWN_REFUSAL + ", message: message })")],
     ["w05:j"]),
    ("m25", "D2 refusal -> none, Search missing pattern", "tool_runtime.ail:591 (plan :590) the missing-pattern refusal is unknown", RT,
     [('fault: refused_fault(), message: "missing pattern"', UNKNOWN_REFUSAL + ', message: "missing pattern"')],
     ["w05:k"]),
    ("m26", "D2 refusal -> none, EditFile no file", "tool_runtime.ail:874 (plan :870) the no-file refusal is unknown", RT,
     [('fault: refused_fault(), message: "path does not exist: ${path}"',
       UNKNOWN_REFUSAL + ', message: "path does not exist: ${path}"')],
     ["w05:l"]),
    ("m27", "D2 refusal -> none, EditFile no edits", "tool_runtime.ail:876 (plan :872) the no-edits refusal is unknown", RT,
     [('fault: refused_fault(), message: "missing edits"', UNKNOWN_REFUSAL + ', message: "missing edits"')],
     ["w05:m"]),
    ("m28", "D2 refusal -> none, EditFile edits do not apply", "tool_runtime.ail:884 (plan :880) the apply_edits refusal is unknown", RT,
     [('tool: "EditFile", fault: refused_fault(), message: msg', 'tool: "EditFile", ' + UNKNOWN_REFUSAL + ', message: msg')],
     ["w05:n"]),
    ("m29", "D2 refusal -> none, delegated backend", "tool_runtime.ail:993 (plan :987) the delegated-backend refusal is unknown", RT,
     [('fault: refused_fault(), message: "requires delegated backend', UNKNOWN_REFUSAL + ', message: "requires delegated backend')],
     ["w05:o"]),
    ("m30", "D3 every harness-reported fault carries effects, RunTests arm",
     "tool_dispatch_adapter.ail:162-163 the RunTestsResult arm renders no fault", AD,
     [('      [kv("tool", js("RunTests"))]\n      ++ fault_field(r.fault)\n', '      [kv("tool", js("RunTests"))]\n')],
     ["adapter:t_run_tests_faulted_key_order", "w05:p"]),
    ("m30b", "D3 every harness-reported fault carries effects, RunTests arm (added: the construction site)",
     "tool_runtime.ail:1008 run_process_result's Err arm constructs RunTestsResult with fault None", RT,
     [("          RunTestsResult({\n            id: id,\n            fault: Some(process_fault(err)),\n",
       "          RunTestsResult({\n            id: id,\n            fault: None,\n")],
     ["w05:p"]),
    ("m31", "D3 exit_code stays 1 on a faulted result",
     "tool_dispatch_adapter.ail:83-84 tool_result_exit_code is 0 for a BashExec or RunTests result carrying a fault", AD,
     [("    BashExecResult(r) => r.exit_code,\n    RunTestsResult(r) => r.exit_code,\n",
       "    BashExecResult(r) => match r.fault { Some(_) => 0, None => r.exit_code },\n"
       "    RunTestsResult(r) => match r.fault { Some(_) => 0, None => r.exit_code },\n")],
     ["w05:a", "w05:p"]),
    ("m32", "C3 deadline's extra field", "tool_dispatch_adapter.ail:203 fault_extra_fields drops elapsed_ms", AD,
     [("    FaultDeadline(ms) => [kv(fault_elapsed_ms_key(), jnum(_int_to_float(ms)))],", "    FaultDeadline(_) => [],")],
     ["adapter:t_kind_deadline_fields"]),
    ("m33", "C3 output_limit's extra field", "tool_dispatch_adapter.ail:204 fault_extra_fields drops bytes", AD,
     [("    FaultOutputLimit(n) => [kv(fault_bytes_key(), jnum(_int_to_float(n)))],", "    FaultOutputLimit(_) => [],")],
     ["adapter:t_kind_output_limit_fields"]),
    ("m34", "C3 signal's extra fields", "tool_dispatch_adapter.ail:205-208 fault_extra_fields drops signal and signal_name", AD,
     [("    FaultSignal(sig, name) => [\n      kv(fault_signal_key(), jnum(_int_to_float(sig))),\n      kv(fault_signal_name_key(), js(name))\n    ],",
       "    FaultSignal(_, _) => [],")],
     ["adapter:t_kind_signal_fields"]),
    ("m34b", "C3 signal's extra fields (added: signal_name alone, which no W0.5 row reads)",
     "tool_dispatch_adapter.ail:207 fault_extra_fields drops signal_name and keeps signal", AD,
     [("    FaultSignal(sig, name) => [\n      kv(fault_signal_key(), jnum(_int_to_float(sig))),\n      kv(fault_signal_name_key(), js(name))\n    ],",
       "    FaultSignal(sig, _) => [\n      kv(fault_signal_key(), jnum(_int_to_float(sig)))\n    ],")],
     ["adapter:t_kind_signal_fields"]),
    ("m35", "W0.3 the defensive arm -> unknown", "tool_dispatch_adapter.ail:281 typed_dispatch_result's defensive branch renders effects none", AD,
     [("             kv(fault_key(), fault_to_json(io_error_fault(EffectsUnknown))),\n",
       "             kv(fault_key(), fault_to_json(io_error_fault(EffectsNone))),\n")],
     ["adapter:t_defensive_arm_no_results", "adapter:t_defensive_arm_two_results"]),
]

# A control mutant: a comment-only edit must leave every suite green, so a
# recompile alone is shown not to count as a kill.
K0 = ("K0", "control: a comment-only edit", "tool_runtime.ail:2 gains a comment line", RT,
      [("module src/core/tool_runtime\n", "module src/core/tool_runtime\n-- W0.6 K0 control: comment only.\n")], [])

SURVIVORS = [
    ("s-nowildcard", "C3/D2 a new upstream ProcessError arm is a compile error in both mappings",
     "none possible: the property is the absence of a wildcard arm",
     "No mutant is possible: the property is that no wildcard exists, and that is checked by reading the "
     "code; this script reads it (process_error_fault_kind and process_error_effects each have the seven "
     "ProcessError arms and no `_ =>` arm)."),
]
# `s-rg` was the second survivor: "No input reaches it portably: the arm is Err
# only when rg itself cannot be launched". That was false (#277 review, finding
# 3): an 11 MiB matching file launches `rg` normally and reaches the arm with
# OutputLimitExceeded(10485760). It is now m36 in FOLLOWUP, run against W0.5
# row r, and its row in `mutants.tsv` is that measured result.

SURVIVAL_ROWS = ["w05:b", "w05:c", "w05:g", "w05:h", "w05:i", "w05:j", "w05:k", "w05:l", "w05:m", "w05:n"]

# The #277 review's follow-up, at FOLLOWUP_COMMIT (`d3047dd1`, the review's
# three fixes and W0.5 rows q, r and s). Line numbers are that commit's.
SEARCH_ARGV = '  ["-n", "--no-heading", "--color", "never", "--no-config", "-e", pattern, "--", target]\n'
FOLLOWUP = [
    ("m36", "D2 read-only failure -> none, Search's rg process error (was survivor s-rg)",
     "tool_runtime.ail:637 run_search's Err arm discloses unknown", RT,
     [("fault: { kind: process_error_fault_kind(err), effects: EffectsNone }, message: process_error_to_string(err)",
       "fault: { kind: process_error_fault_kind(err), effects: EffectsUnknown }, message: process_error_to_string(err)")],
     ["w05:r"]),
    # Under m37 `rg` reads `--pre=<helper>` as an option and the directory as
    # the pattern, so with no path it searches the process's own directory, the
    # repository, running the helper on each file: the helper only `cat`s the
    # file and touches a marker in W0.5's scratch workdir.
    ("m37", "#277 finding 1: Search's pattern is text (-e, --)",
     "tool_runtime.ail:616 search_argv passes the pattern positionally again, with no -e and no --", RT,
     [(SEARCH_ARGV, '  ["-n", "--no-heading", "--color", "never", "--no-config", pattern, target]\n')],
     ["runtime:t_search_argv_reads_only", "w05:q"]),
    ("m38", "#277 finding 1: Search reads no ripgrep config (--no-config)",
     "tool_runtime.ail:616 search_argv drops --no-config", RT,
     [(SEARCH_ARGV, '  ["-n", "--no-heading", "--color", "never", "-e", pattern, "--", target]\n')],
     ["runtime:t_search_argv_reads_only"]),
    ("m39", "#277 finding 2: the unknown-tool refusal echoes the name cut",
     "tool_runtime.ail:258 unknown_tool_refusal echoes the caller's name uncut", RT,
     [("  let shown = echoed_tool_name(name, 200);\n", "  let shown = name;\n")],
     ["adapter:t_long_unknown_tool_keeps_fault", "w05:s"]),
]
K0F = ("K0f",) + K0[1:]
FOLLOWUP_SURVIVAL_ROWS = SURVIVAL_ROWS + ["w05:q", "w05:r", "w05:s"]

ANSI = re.compile(r"\x1b\[[0-9;]*m")


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
    with open(log, "w") as f:
        f.write(ANSI.sub("", out))
    return out, rc, time.time() - t0


def inline_suite(name, path, d):
    """{test: 'pass'|'fail'|...} or None when the file did not compile or run."""
    out, rc, _ = sh(["ailang", "test", "--json", "--no-color", path], os.path.join(d, name + ".log"))
    i = out.find("{")
    try:
        doc = json.loads(out[i:]) if i >= 0 else None
    except ValueError:
        doc = None
    if not doc or "tests" not in doc:
        return None, rc
    res = {}
    for t in doc["tests"]:
        res["%s:%s" % (name, re.sub(r"_test_\d+$", "", t["name"]))] = t["status"]
    return res, rc


def witness_suite(d, rows):
    """W0.5's rows: 16 (a-p) at COMMIT, 19 (a-s) at FOLLOWUP_COMMIT."""
    cmd = ["ailang", "run", "--caps", "IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace", "--ai-stub",
           "--entry", "fault_disclosure_witness", WITNESS]
    out, rc, _ = sh(cmd, os.path.join(d, "w05.log"))
    out = ANSI.sub("", out)
    res = {}
    for line in out.splitlines():
        m = re.match(r"\s*([✓✗]) row ([a-z]):", line)
        if m:
            res["w05:" + m.group(2)] = "pass" if m.group(1) == "✓" else "fail"
    complete = re.search(r"^fault_disclosure_witness (PASS|FAIL)", out, re.M) is not None
    if "NOT EVALUATED" in out or len(res) != rows or not complete:
        return None, rc
    return res, rc


def run_suites(d, followup=False):
    os.makedirs(d, exist_ok=True)
    suites = {}
    rcs = {}
    suites["tool_fault"], rcs["tool_fault"] = inline_suite("tool_fault", TF, d)
    suites["adapter"], rcs["adapter"] = inline_suite("adapter", AD, d)
    if followup:
        suites["runtime"], rcs["runtime"] = inline_suite("runtime", RT, d)
    suites["w05"], rcs["w05"] = witness_suite(d, 19 if followup else 16)
    return suites, rcs


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def apply(path, edits):
    with open(path) as f:
        src = f.read()
    for old, new in edits:
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


def no_wildcard_check():
    with open(TF) as f:
        src = f.read()
    found = []
    for fn in ("process_error_fault_kind", "process_error_effects"):
        m = re.search(r"export pure func %s\(err: ProcessError\)[^{]*\{\n  match err \{\n(.*?)\n  \}\n\}" % fn, src, re.S)
        if not m:
            return False, "%s not found" % fn
        arms = [l.strip() for l in m.group(1).splitlines() if l.strip()]
        heads = sorted(a.split("(")[0] for a in arms)
        wild = [a for a in arms if a.startswith("_")]
        if wild or heads != sorted(["NotAllowed", "NotFound", "PermissionDenied", "SpawnFailed", "Timeout",
                                    "OutputLimitExceeded", "AbnormalExit"]):
            return False, "%s arms %s" % (fn, arms)
        found.append("%s: %d arms, no wildcard" % (fn, len(arms)))
    return True, "; ".join(found)


def red_set(suites):
    return {t for s in suites.values() if s for t, st in s.items() if st != "pass"}


def main():
    apply_check = "--apply-check" in sys.argv
    followup = "--followup" in sys.argv
    commit = FOLLOWUP_COMMIT if followup else COMMIT
    spec = FOLLOWUP + [K0F] if followup else MUTANTS + [K0]
    controls = ("F-baseline", "F-restored") if followup else ("C-baseline", "C-restored")
    survival_rows = FOLLOWUP_SURVIVAL_ROWS if followup else SURVIVAL_ROWS
    if os.getuid() == 0:
        raise SystemExit("run as a non-root user: as root W0.5 rows e and f are not evaluated")
    head = git("rev-parse", "--short=8", "HEAD")
    if not apply_check and head != commit:
        raise SystemExit("HEAD is %s, this run is for %s" % (head, commit))
    if git("status", "--porcelain", "--", *TRACKED):
        raise SystemExit("the source this run mutates is not clean")
    originals = {p: sha(p) for p in TRACKED}

    if apply_check:
        for mid, _, _, path, edits, _ in spec:
            backup = path + ".w06.orig"
            shutil.copyfile(path, backup)
            try:
                apply(path, edits)
                p = subprocess.run(["ailang", "check", path], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                print("%s\t%s\t%s" % (mid, "compiles" if p.returncode == 0 else "DOES NOT COMPILE",
                                      ANSI.sub("", p.stdout.decode()).strip().splitlines()[-1:] if p.returncode else ""))
            finally:
                shutil.copyfile(backup, path)
                os.remove(backup)
            assert sha(path) == originals[path], "restore failed for " + mid
        return

    # Only this run's own directories are cleared: the other run's stay.
    for rid in [m[0] for m in spec] + list(controls):
        if os.path.isdir(os.path.join(RUNS, rid)):
            shutil.rmtree(os.path.join(RUNS, rid))
    os.makedirs(RUNS, exist_ok=True)
    rows = []
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    def control(cid, note):
        t0 = time.time()
        suites, rcs = run_suites(os.path.join(RUNS, cid), followup)
        ok = all(s is not None for s in suites.values())
        red = red_set(suites)
        n = sum(len(s) for s in suites.values() if s)
        surv = [t for t in survival_rows if suites["w05"] and suites["w05"].get(t) == "pass"]
        verdict = "PASS" if ok and not red else "FAIL"
        seen = "%d tests ran, %d red%s; survival rows %s green" % (
            n, len(red), (": " + " ".join(sorted(red))) if red else "", "all %d" % len(surv)
            if len(surv) == len(survival_rows) else "%d of %d" % (len(surv), len(survival_rows)))
        rows.append([cid, "control", note, "none: unmutated source at %s" % commit, "-", "nothing red",
                     seen, verdict, "-", "", "complete" if ok else "NOT-RUN",
                     " ".join("%s=%s" % kv for kv in rcs.items()), "%.0f" % (time.time() - t0)])
        print(cid, verdict, seen, flush=True)
        return verdict == "PASS"

    if not control(controls[0], "every suite green before the first mutant, survival rows included"):
        write(rows, started, followup)
        raise SystemExit("baseline is not green: no mutant is run")

    for mid, rule, edit, path, edits, expect in spec:
        d = os.path.join(RUNS, mid)
        os.makedirs(d)
        backup = os.path.join(d, "orig.ail")
        shutil.copyfile(path, backup)
        t0 = time.time()
        try:
            apply(path, edits)
            with open(os.path.join(d, "mutant.diff"), "w") as f:
                f.write(unified_diff(backup, path, path))
            suites, rcs = run_suites(d, followup)
        finally:
            shutil.copyfile(backup, path)
            os.remove(backup)
        restored = sha(path) == originals[path]
        if not restored:
            raise SystemExit("%s: restore left different bytes in %s" % (mid, path))
        complete = all(s is not None for s in suites.values())
        red = red_set(suites)
        seen = [t for t in expect if t in red]
        missing = [t for t in expect if not any(s and t in s for s in suites.values())]
        also = sorted(red - set(expect))
        if mid in ("K0", "K0f"):
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
        for k, s in suites.items():
            if s is None:
                notes.append("%s did not run to its end (rc=%s): see runs/%s/%s.log" % (k, rcs[k], mid, k))
        rows.append([mid, "control" if mid in ("K0", "K0f") else "mutant", rule, edit, path,
                     " ".join(expect) if expect else "nothing red", " ".join(seen) if seen else
                     ("nothing red" if not red else "none of the expected"),
                     verdict, " ".join(also) if also else "none", "; ".join(notes),
                     "complete" if complete else "NOT-RUN", " ".join("%s=%s" % kv for kv in rcs.items()),
                     "%.0f" % (time.time() - t0)])
        print(mid, verdict, "also:", len(also), flush=True)

    if not followup:
        ok, why = no_wildcard_check()
        for sid, rule, edit, sentence in SURVIVORS:
            note = sentence + ((" Read at %s: %s." % (COMMIT, why)) if sid == "s-nowildcard" else "")
            if sid == "s-nowildcard" and not ok:
                note = "THE READ FAILED: " + why
            rows.append([sid, "survivor", rule, edit, "-", "-", "-", "SURVIVOR", "-", note, "not run", "-", "0"])

    control(controls[1], "every suite green after the last mutant, on the restored source")
    for p in TRACKED:
        assert sha(p) == originals[p], "tree not restored: " + p
    if git("status", "--porcelain", "--", *TRACKED):
        raise SystemExit("the mutated source is not clean after the run")
    write(rows, started, followup)


HEAD_COLS = ["id", "kind", "rule", "edit", "file", "expect_red", "seen_red", "verdict", "also_red", "notes",
             "run", "exit", "wall_secs", "commit"]


def write(rows, started, followup=False):
    commit = FOLLOWUP_COMMIT if followup else COMMIT
    lines = [r + [commit] for r in rows]
    if followup:
        # The first run's rows stay, but for `s-rg`, which m36 replaces, and any
        # row of an earlier follow-up run, which this one replaces.
        drop = {"s-rg"} | {r[0] for r in rows}
        with open(os.path.join(HERE, "mutants.tsv")) as f:
            kept = [l.rstrip("\n").split("\t") for l in f.readlines()[1:]]
        lines = [r for r in kept if r[0] not in drop and r[-1] == COMMIT] + lines
    with open(os.path.join(HERE, "mutants.tsv"), "w") as f:
        f.write("\t".join(HEAD_COLS) + "\n")
        for r in lines:
            f.write("\t".join(str(c).replace("\t", " ").replace("\n", " ") for c in r) + "\n")
    with open(os.path.join(HERE, "meta-followup.txt" if followup else "meta.txt"), "w") as f:
        f.write("commit\t%s\nuid\t%d\nailang\t%s\nstarted\t%s\nended\t%s\n" % (
            git("rev-parse", "HEAD"), os.getuid(),
            subprocess.run(["ailang", "--version"], stdout=subprocess.PIPE).stdout.decode().split("\n")[0],
            started, time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())))


if __name__ == "__main__":
    main()
