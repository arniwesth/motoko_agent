#!/usr/bin/env python3
"""034 PLAN-001 W1.7: the Phase 1 mutation run.

One source change per rule W1 states, the test expected to fail named before
the run, one mutant at a time (meta-decision
`mutate-each-stated-rule-once-and-see-its-test-fail.md`, standing rule 3).
There is no shared runner; this script is W0.6's (`../mutation-019f1c6c/`)
with W1's suites, and implements that document's rules 2, 3 and 6 itself:

- A mutant is KILLED when every test named in its `expect` set is red, in a run
  where every suite compiled and ran to its own summary. Any other test going
  red is recorded in `also_red` and never counts toward the kill.
- A compile error, a run that printed no summary, or a timeout is recorded as
  what it is (`NOT-RUN`), never as a kill.
- The source is green before the first mutant (control C-baseline), every
  mutated file is restored by copy and its sha256 compared with the original,
  and the source is green again after the last (control C-restored). K0, a
  comment-only edit, must leave every suite green.

Every mutant runs the same seventeen suites, so `also_red` is complete:

  inline (`ailang test --json <file>`): ports, dst_replay, ext_world,
    tool_phase, session, dst_fault_catalogue, dst_persistence, dst_program,
    dst_corpus, tool_fault, adapter (tool_dispatch_adapter)
  pp    `make program_persistence`'s AILANG suite (program_persistence_dst)
  ep    `make execution_program`'s (execution_program_dst)
  fc    `make fault_catalogue`'s (fault_catalogue_dst)
  sr    `make strict_replay`'s main entry (strict_replay_dst)
  cp    `make corpus_pr`'s AILANG suite (corpus_pr_dst), plus the target's
        before-dispatch wire count as one row
  bank  `bank_replay.ail` beside this script: the survival case for the PR
        bank, every member decoded and strictly replayed

An inline test is named `suite:function`. A row of a script suite is named
`suite:text`, a fragment of its pass line; it is red when fewer pass lines
carry the fragment than in C-baseline. Digits are compared as `#` (except after
`v` or `/`, so `v08` and `execution-program/5` stay themselves), so a count
that moves inside a passing line is not read as a failure.

Run it from the worktree root, as a non-root user, on a clean tree at COMMIT:

  python3 .agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-w1-f160eebb/mutate.py

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

COMMIT = "f160eebb"
HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = os.path.join(HERE, "runs")
REL = os.path.relpath(HERE)
TIMEOUT = 900
CAPS = "IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace"

PO = "src/core/ports.ail"
PE = "src/core/dst_persistence.ail"
RP = "src/core/dst_replay.ail"
EW = "src/core/ext_world.ail"
TP = "src/core/tool_phase.ail"
SE = "src/core/session.ail"
FC = "src/core/dst_fault_catalogue.ail"
TRACKED = [PO, PE, RP, EW, TP, SE, FC]

INLINE = [("ports", PO), ("dst_replay", RP), ("ext_world", EW), ("tool_phase", TP), ("session", SE),
          ("dst_fault_catalogue", FC), ("dst_persistence", PE), ("dst_program", "src/core/dst_program.ail"),
          ("dst_corpus", "src/core/dst_corpus.ail"), ("tool_fault", "src/core/tool_fault.ail"),
          ("adapter", "src/core/tool_dispatch_adapter.ail")]
# name, argv, the summary line that says the suite ran to its end
SCRIPTS = [
    ("pp", ["ailang", "run", "--caps", "IO,FS", "--entry", "main", "scripts/dst/program_persistence_dst.ail"],
     r"^program_persistence_dst (PASS|FAIL)$"),
    ("ep", ["ailang", "run", "--caps", "IO", "--entry", "main", "scripts/dst/execution_program_dst.ail"],
     r"^execution_program_dst (PASS|FAIL)$"),
    ("fc", ["ailang", "run", "--caps", "IO", "--entry", "main", "scripts/dst/fault_catalogue_dst.ail"],
     r"^fault_catalogue_dst (PASS|FAIL)$"),
    ("sr", ["ailang", "run", "--caps", CAPS, "--ai-stub", "--entry", "main", "scripts/dst/strict_replay_dst.ail"],
     r"^strict_replay_dst (PASS|FAIL)$"),
    ("cp", ["ailang", "run", "--caps", CAPS, "--ai-stub", "--entry", "main", "scripts/dst/corpus_pr_dst.ail"],
     r"^(✓ WI-A15 commit 1: the blocking PR corpus|✗ WI-A15 commit 1 FAILED)$"),
    ("bank", ["ailang", "run", "--relax-modules", "--caps", CAPS, "--ai-stub", "--entry", "main",
              os.path.join(REL, "bank_replay.ail")],
     r"^bank_replay (PASS|FAIL)$"),
]
SCRATCH = [".ailang/dst-artifacts", ".ailang/dst-corpus"]

# The world-only row's fragment, the five uses of it below.
GUARD_SR = "sr:world_truth: no world-only class id in any projected tool message"
GUARD_CP = "cp:no projected tool message contains a world-only class id"
WT_LOG = "sr:world_truth: the effect log holds the completed call and the applied fault"
V5_LOG = "sr:v5_fixture: replay reproduces the effect log"
LEGACY = "pp:the v1, v2, v3 and v4 specimens all decode, each with an empty world-truth list"

# A ToolFault whose effects are the other value, built from the builders the
# file already imports, so a mutant changes the disclosure and keeps the kind.
AS_NONE = "| effects: failed_fault(false).effects }"
AS_UNKNOWN = "| effects: failed_fault(true).effects }"

V01_HELPER = '''
-- 034 W1.7 mutant v01: every fault-status interaction, as if all applied.
pure func w17_all_faults(xs: [Interaction]) -> [int] {
  match xs {
    [] => [],
    x :: rest => (match x.outcome.status { OutcomeFault => [x.identity.ordinal], _ => [] }) ++ w17_all_faults(rest)
  }
}
'''
V01B_HELPER = '''
-- 034 W1.7 mutant v01b: every TOOL fault, as if all applied.
pure func w17_tool_faults(xs: [Interaction]) -> [int] {
  match xs {
    [] => [],
    x :: rest =>
      (match x.identity.body {
         ToolIdentity(_, _, _) => (match x.outcome.status { OutcomeFault => [x.identity.ordinal], _ => [] }),
         _ => []
       }) ++ w17_tool_faults(rest)
  }
}
'''
V12_HELPER = '''
-- 034 W1.7 mutant v12: the typed renderer, told whether the fault applied,
-- names the world-only class in `fault_class`.
pure func w17_v12_render(call: ToolCall, o: ToolOutcome, applied: bool) -> Message {
  if not applied then tool_outcome_message(call, o)
  else match o {
    ToolFailed(f) =>
      tool_fault_message(call, "tool_effect_applied_then_failed", failed_fault(f.after_dispatch), encode(jo([
        kv("code", js(f.code)), kv("message", js(f.message)), kv("tool_call_id", js(f.tool_call_id))
      ]))),
    ToolDeadlineExceeded(d) =>
      tool_fault_message(call, "tool_effect_applied_then_deadline", deadline_fault(d.elapsed_ms), encode(jo([
        kv("tool_call_id", js(d.tool_call_id)),
        kv("elapsed_ms", jnum(_int_to_float(d.elapsed_ms))),
        kv("timeout_ms", jnum(_int_to_float(d.timeout_ms)))
      ]))),
    _ => tool_outcome_message(call, o)
  }
}
'''
EOF = "<EOF>"  # an edit whose old string is EOF appends its new string

# id, rule, edit (what the change does, with its site at COMMIT), file,
# [(old, new)] each old occurring exactly once, expected-red tests.
MUTANTS = [
    ("v01", "W1.2 a legacy program decodes with an empty world-truth list",
     "dst_persistence.ail:1342 project: a pre-v5 program decodes with every fault-status ordinal listed (all applied)", PE,
     [("    applied_faults: applied_faults_at(version, hs) }\n",
       "    applied_faults: if version_has_applied_faults(version) then applied_faults_at(version, hs) else w17_all_faults(xs) }\n"),
      (EOF, V01_HELPER)],
     [LEGACY]),
    ("v01b", "W1.2 a legacy program decodes with an empty world-truth list (added: tool faults only)",
     "dst_persistence.ail:1342 project: a pre-v5 program decodes with every TOOL fault ordinal listed", PE,
     [("    applied_faults: applied_faults_at(version, hs) }\n",
       "    applied_faults: if version_has_applied_faults(version) then applied_faults_at(version, hs) else w17_tool_faults(xs) }\n"),
      (EOF, V01B_HELPER)],
     [LEGACY]),
    ("v02", "W1.2 a new-version program must carry the field",
     "dst_persistence.ail:1247 decode_body: check_required uses the table without applied_faults, so its absence decodes as []", PE,
     [("      let structural = check_required(hs, req)\n",
       "      let structural = check_required(hs, with_bounds_arity(required_header_tags(), bounds_arity_at(version)))\n")],
     ["pp:artifact-missing-section ← the execution-program/5 world-truth line (applied_faults) deleted"]),
    ("v03", "W1.2 a listed ordinal must be an after-dispatch fault (not a completed outcome)",
     "dst_replay.ail:859 applied_fault_check: a listed OutcomeOk ordinal is accepted", RP,
     [("        OutcomeOk => Some(AppliedFaultCompleted(ord)),\n", "        OutcomeOk => None,\n")],
     ["dst_replay:test_a_listed_completed_tool_outcome_refuses_replay"]),
    ("v04", "D4 `applied` on a before-dispatch fault is rejected",
     "dst_replay.ail:864 applied_fault_check: a listed before-dispatch fault is accepted", RP,
     [("if t.code != \"\" && not t.after_dispatch then Some(AppliedFaultBeforeDispatch(ord))",
       "if false then Some(AppliedFaultBeforeDispatch(ord))")],
     ["dst_replay:test_a_listed_before_dispatch_fault_refuses_replay"]),
    ("v05", "W1.3 replay sets `applied` from the list",
     "dst_replay.ail:767 tools_of ignores the list: every reconstituted entry has applied false", RP,
     [("Ok(tail) => Ok({ t | applied: listed_ordinal(listed, i.identity.ordinal) } :: tail)",
       "Ok(tail) => Ok({ t | applied: false } :: tail)")],
     ["sr:world_truth: the reconstituted queue has `applied` on the listed fault only",
      "sr:world_truth: replay rebuilds the effect log"]),
    ("v06", "W1.2 `applied` never enters the served payload",
     "ports.ail:1856 scripted_tool_outcome writes `applied` into the ToolFailed message, which the payload encodes", PO,
     [("ToolFailed({ tool_call_id: inv.call.id, code: t.code, message: t.message,\n",
       "ToolFailed({ tool_call_id: inv.call.id, code: t.code, message: if t.applied then \"${t.message} applied\" else t.message,\n")],
     ["sr:world_truth (b): two programs differing only in the list serve identical interactions",
      "ports:test_applied_never_reaches_the_outcome_or_its_payload"]),
    ("v07", "W1.3 a fault enters the effect log only when `applied`",
     "ports.ail:1816 world_tool appends on every scripted fault", PO,
     [("let applied = match outcome { ToolCompleted(_) => true, _ => t.applied };",
       "let applied = match outcome { ToolCompleted(_) => true, _ => true };")],
     [WT_LOG, V5_LOG]),
    ("v08", "D4 a world-only row's twin must exist",
     "dst_fault_catalogue.ail:668 twin_rejections accepts a missing twin", FC,
     [("        None => [WorldOnlyTwinMissing(r.class_id, t)],\n", "        None => [],\n")],
     ["dst_fault_catalogue:test_world_only_twin_missing_fails", "fc:v08: a world-only row whose twin is not a row"]),
    ("v09", "D4 the twin must not be world-only",
     "dst_fault_catalogue.ail:672 twin_rejections accepts a world-only twin", FC,
     [("            WorldOnly(_) => [WorldOnlyTwinWorldOnly(r.class_id, t)]\n", "            WorldOnly(_) => []\n")],
     ["dst_fault_catalogue:test_world_only_twin_that_is_world_only_fails",
      "fc:v09: a world-only row whose twin is itself world-only"]),
    ("v10", "D4 the twin's delivery constructor must match",
     "dst_fault_catalogue.ail:675 twin_rejections accepts a different constructor", FC,
     [("            if twin.delivery_constructor == r.delivery_constructor then []\n", "            if true then []\n")],
     ["dst_fault_catalogue:test_world_only_twin_constructor_differs_fails",
      "fc:v10: a world-only row whose delivery constructor differs"]),
    ("v11", "D4 the twin's recovery branch must match",
     "dst_fault_catalogue.ail:678 twin_rejections accepts a different branch", FC,
     [("            if same_branch(twin.recovery_branch, r.recovery_branch) then []\n", "            if true then []\n")],
     ["dst_fault_catalogue:test_world_only_twin_branch_differs_fails",
      "fc:v11: a world-only row whose recovery branch differs"]),
    ("v12", "D4 no world-only class id reaches the wire (guard intact)",
     "tool_phase.ail:515 the native dispatch renders through a typed renderer that, for a fault whose effect the world logged (applied), puts the world-only id in fault_class; line-neutral, helper at EOF", TP,
     [("msg: tool_outcome_message(call, execution.outcome),",
       "msg: w17_v12_render(call, execution.outcome, List.length(execution.next_state.effect_log) > List.length(budget.next_state.effect_log)),"),
      (EOF, V12_HELPER)],
     [GUARD_SR, GUARD_CP]),
    ("v13", "W1.4 before-dispatch ToolFailed -> none",
     "tool_phase.ail:293 tool_outcome_message renders every ToolFailed as after dispatch (unknown)", TP,
     [("failed_fault(f.after_dispatch), encode(jo([", "failed_fault(true), encode(jo([")],
     ["tool_phase:test_w14_tool_failed_before_dispatch_none"]),
    ("v14", "W1.4 after-dispatch ToolFailed -> unknown",
     "tool_phase.ail:293 tool_outcome_message renders every ToolFailed as before dispatch (none)", TP,
     [("failed_fault(f.after_dispatch), encode(jo([", "failed_fault(false), encode(jo([")],
     ["tool_phase:test_w14_tool_failed_after_dispatch_unknown"]),
    ("v15a", "W1.4 deadline -> unknown",
     "tool_phase.ail:301 the deadline fault discloses none (kind deadline kept)", TP,
     [("deadline_fault(d.elapsed_ms), encode(jo([", "{ deadline_fault(d.elapsed_ms) " + AS_NONE + ", encode(jo([")],
     ["tool_phase:test_w14_deadline_unknown"]),
    ("v15b", "W1.4 correlation mismatch -> unknown",
     "tool_phase.ail:297 the correlation-mismatch fault discloses none (kind kept)", TP,
     [("fault_class_tool_correlation_mismatch(), correlation_mismatch_fault(), encode",
       "fault_class_tool_correlation_mismatch(), { correlation_mismatch_fault() " + AS_NONE + ", encode")],
     ["tool_phase:test_w14_correlation_mismatch_unknown"]),
    ("v16a", "W1.4 policy denial -> none",
     "tool_phase.ail:116 denial_message discloses unknown (kind denied kept)", TP,
     [("kv(fault_key(), fault_to_json(denied_fault())),",
       "kv(fault_key(), fault_to_json({ denied_fault() " + AS_UNKNOWN + ")),")],
     ["tool_phase:test_denial_message_uses_tool_role_and_call_id"]),
    ("v16b", "W1.4 approval denial -> none",
     "session.ail:2065 policy_denied_message discloses unknown (kind denied kept); session.ail:43 imports failed_fault, line-neutral", SE,
     [("import src/core/tool_fault (fault_key, denied_fault)", "import src/core/tool_fault (fault_key, denied_fault, failed_fault)"),
      ("kv(fault_key(), fault_to_json(denied_fault())),",
       "kv(fault_key(), fault_to_json({ denied_fault() " + AS_UNKNOWN + ")),")],
     ["session:test_w14_policy_denied_message_none"]),
    ("v16c", "W1.4 undecodable arguments -> none",
     "tool_phase.ail:365 undecodable_arguments_message discloses unknown (kind kept)", TP,
     [("kv(fault_key(), fault_to_json(arguments_undecodable_fault())),",
       "kv(fault_key(), fault_to_json({ arguments_undecodable_fault() " + AS_UNKNOWN + ")),")],
     ["tool_phase:test_w14_undecodable_arguments_none"]),
    ("v16d", "W1.4 delegated deferral -> none",
     "tool_phase.ail:222 delegated_deferred_message discloses unknown (kind refused kept)", TP,
     [("kv(fault_key(), fault_to_json(refused_fault())),",
       "kv(fault_key(), fault_to_json({ refused_fault() " + AS_UNKNOWN + ")),")],
     ["tool_phase:test_w14_delegated_deferred_none"]),
    ("v17", "W1.2 the stage round-trips through the codec",
     "ports.ail:2678 encode_tool_outcome drops the stage key", PO,
     [('kv("message", js(f.message)),\n                 kv("stage", js(if f.after_dispatch then "after_dispatch" else "before_dispatch"))])),',
       'kv("message", js(f.message))\n                 ])),')],
     ["ports:test_the_dispatch_stage_round_trips_through_the_tool_codec_both_values"]),
    ("v18", "W1.2 a legacy fault decodes as after dispatch",
     "ports.ail:2766 decode_tool_outcome defaults an absent stage to before dispatch", PO,
     [('after_dispatch: not has_key(root, "stage") || stage == "after_dispatch",',
       'after_dispatch: stage == "after_dispatch",')],
     ["ports:test_a_legacy_failed_tool_payload_decodes_as_after_dispatch"]),
    ("v19", "W1.3 world truth stays out of the token",
     "ext_world.ail:272 scripted_tool_json writes applied", EW,
     [('    kv("after_dispatch", jb(t.after_dispatch))\n',
       '    kv("after_dispatch", jb(t.after_dispatch)), kv("applied", jb(t.applied))\n')],
     ["ext_world:test_the_world_token_holds_neither_applied_nor_the_effect_log"]),
    ("v20", "W1.3 world truth is re-seated after adoption",
     "ext_world.ail:707 adopt_world drops the applied re-seat (the token's false stands)", EW,
     [("{ adopted | tools: reseat_applied(adopted.tools, pre.tools), effect_log: pre.effect_log }",
       "{ adopted | effect_log: pre.effect_log }")],
     ["ext_world:test_adoption_re_seats_applied_from_the_pre_hook_world"]),
    ("v20b", "W1.3 world truth is re-seated after adoption (added: the tool_phase site)",
     "tool_phase.ail:437 the tool-handle adoption re-seats from a pre-hook world with no tools, so applied resets", TP,
     [("let handle_world = adopt_world(handled.next_state, world);",
       "let handle_world = adopt_world(handled.next_state, { world | tools: [] });")],
     [WT_LOG]),
    ("v20c", "W1.3 world truth is re-seated after adoption (added: the session pre-step site)",
     "session.ail:3465 the pre-step chain's adoption re-seats from a world with no tools, so applied resets", SE,
     [("dispatch_step(st.provider, adopt_world(chain.next_state, st.world_state), ",
       "dispatch_step(st.provider, adopt_world(chain.next_state, { st.world_state | tools: [] }), ")],
     [WT_LOG]),
    ("v21", "W1.3 the effect log is re-seated after adoption",
     "ext_world.ail:707 adopt_world drops the effect log's re-seat (the token's [] stands)", EW,
     [("{ adopted | tools: reseat_applied(adopted.tools, pre.tools), effect_log: pre.effect_log }",
       "{ adopted | tools: reseat_applied(adopted.tools, pre.tools) }")],
     ["ext_world:test_adoption_re_seats_the_effect_log_from_the_pre_hook_world"]),
    ("v22", "W1.3 completed calls enter the effect log",
     "ports.ail:1816 world_tool appends for applied faults only", PO,
     [("let applied = match outcome { ToolCompleted(_) => true, _ => t.applied };",
       "let applied = match outcome { ToolCompleted(_) => false, _ => t.applied };")],
     [WT_LOG, V5_LOG]),
]

# A survivor's sentence, written after the run measured it (it is in the
# notes column; the verdict stays what was measured).
SENTENCES = {
    "v01b": ("SURVIVOR, with its sentence: an equivalent mutant on every pre-v5 artifact this tree holds. The four frozen legacy specimens (scripts/dst/fixtures/execution-program-v1..v4.artifact) record no tool fault - their one fault, #3, is an extension effect - and no gate builds a pre-v5 program that has one, so listing only tool faults lists nothing and decodes exactly what the rule requires. v01 (every fault) kills the same branch (dst_persistence.applied_faults_at's pre-v5 arm); what v01b shows is that the legacy row would not see a decoder that special-cased tool faults. Not closed here (one commit, no new source): a pre-v5 tool-fault row is a few lines in program_persistence_dst, the v5 specimen rebuilt at execution-program/4 without its applied_faults line (rebuild_at, as the UnknownTag row does), and is handed to W1.8."),
}

# A control mutant: a comment-only edit must leave every suite green, so a
# recompile alone is shown not to count as a kill. At the end of the file, so
# no line moves.
K0 = ("K0", "control: a comment-only edit", "dst_replay.ail gains a comment line at its end", RP,
      [(EOF, "-- W1.7 K0 control: comment only.\n")], [])

# Rows that must stay green on the unmutated source: the bank, the legacy
# fixtures and the frozen v5 fixture decode and replay clean (the plan's
# survival case), and the two driver scenarios replay.
SURVIVAL = [
    "pp:the frozen v1 specimen decodes", "pp:the frozen v2 specimen decodes",
    "pp:the frozen v3 specimen decodes", "pp:the frozen v4 specimen decodes",
    "pp:the frozen v5 specimen decodes",
    LEGACY,
    "pp:the frozen v5 specimen decodes to the specimen", "pp:the current encoder still produces those exact bytes",
    "pp:the frozen program replays against itself with no fatal",
    "sr:v5_fixture: the frozen bytes list #", "sr:v5_fixture: the replayed tool seam serves the recorded outcomes",
    V5_LOG, "sr:world_truth: the decoded program replays to an identical interaction log",
    "sr:rich: the exact program replays to an identical interaction log",
    "sr:maxsteps: the exact program replays to an identical interaction log",
    "cp:the retained bytes load back to the same identity",
    "bank:decodes, reconstitutes, and replays to an identical interaction log",
    "bank:replay rebuilds world truth",
    "bank:all # bank members decode and replay clean",
]

# `skip` is a contract property with no generator (13 at W0.6, 7 here in
# tool_fault): it ran nothing, and a verdict reads a status, never the exit code.
GREEN = ("pass", "skip")

ANSI = re.compile(r"\x1b\[[0-9;]*m")
DIGITS = re.compile(r"(?<![v/])\d+")


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
        # `make corpus_pr`'s 034 W1.6 wire witness, as the target computes it.
        before = sum(l.count('"kind":"failed","effects":"none"') for l in out.splitlines()
                     if '"type":"native_tool_results"' in l)
        if before > 0:
            passed[norm("wire: a before-dispatch ToolFailed is rendered with effects none")] += 1
        else:
            failed.append("wire: a before-dispatch ToolFailed is rendered with effects none (0 on the wire)")
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
        raise SystemExit("run as a non-root user (uid 1001): the W1 gates are run as one")
    head = git("rev-parse", "--short=8", "HEAD")
    if head != COMMIT:
        raise SystemExit("HEAD is %s, this run is for %s" % (head, COMMIT))
    if tree_dirty():
        raise SystemExit("the tree is not clean outside the evidence directory:\n" + "\n".join(tree_dirty()))
    originals = {p: sha(p) for p in TRACKED}

    if apply_check:
        lines = []
        for mid, _, _, path, edits, _ in spec:
            backup = path + ".w17.orig"
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

    shutil.rmtree(RUNS, ignore_errors=True)
    os.makedirs(RUNS)
    rows = []
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    base = {}

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
        write(rows, started)
        raise SystemExit("baseline is not green: no mutant is run")
    for mid, _, _, _, _, expect in spec:
        for t in expect:
            if not found(t, base, base):
                write(rows, started)
                raise SystemExit("spec error: %s's expected test %s is not in the baseline" % (mid, t))

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
            suites, rcs = run_suites(d)
        finally:
            shutil.copyfile(backup, path)
            os.remove(backup)
        if sha(path) != originals[path]:
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
    write(rows, started)


HEAD_COLS = ["id", "kind", "rule", "edit", "file", "expect_red", "seen_red", "verdict", "also_red",
             "survival_red", "notes", "run", "exit", "wall_secs", "commit"]


def write(rows, started):
    with open(os.path.join(HERE, "mutants.tsv"), "w") as f:
        f.write("\t".join(HEAD_COLS) + "\n")
        for r in rows:
            f.write("\t".join(str(c).replace("\t", " ").replace("\n", " ") for c in r + [COMMIT]) + "\n")
    with open(os.path.join(HERE, "meta.txt"), "w") as f:
        f.write("commit\t%s\nuid\t%d\nailang\t%s\nstarted\t%s\nended\t%s\n" % (
            git("rev-parse", "HEAD"), os.getuid(),
            subprocess.run(["ailang", "--version"], stdout=subprocess.PIPE).stdout.decode().split("\n")[0],
            started, time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())))


if __name__ == "__main__":
    main()
