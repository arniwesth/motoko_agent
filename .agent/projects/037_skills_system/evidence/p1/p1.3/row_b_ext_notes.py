#!/usr/bin/env python3
"""037 P1.3b extension: the counts behind the report's notes, for the four new
models. Reads results/row_b_ext_sessions.tsv and the captures. No model call.

  row_b_ext_notes.py            prints, and writes results/row_b_ext_notes.txt
"""
import collections, csv, glob, json, os, sys
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import events
import row_b
from row_b_ext import NEW_MODELS

out = []


def p(s=""):
    out.append(s)
    print(s)


rows = [r for r in csv.DictReader(open(os.path.join(HERE, "results", "row_b_ext_sessions.tsv")), delimiter="\t")
        if r["model"] in NEW_MODELS]
p("new-model sessions scored: %d" % len(rows))
for model in NEW_MODELS:
    mine = [r for r in rows if r["model"] == model]
    trig = [r for r in mine if r["kind"] == "m2" and r["expected"] != "-"]
    ctrl = [r for r in mine if r["kind"] == "m2" and r["expected"] == "-"]
    stamp = [r for r in mine if r["kind"] == "stamp"]
    p("")
    p("== %s: %d sessions (trials %s)" % (model, len(mine), sorted(set(r["trial"] for r in mine))))
    p("  trigger %d: skill_first %d, skill_any_first %d, expected_first %d, expected_within_run %d, outcomes %s" % (
        len(trig), sum(int(r["skill_first"]) for r in trig), sum(int(r["skill_any"]) for r in trig),
        sum(int(r["hit_first_response"]) for r in trig), sum(int(r["hit_within_run"]) for r in trig),
        dict(collections.Counter(r["outcome"] for r in trig))))
    p("  control %d: Skill in the first response %d, Skill in any request %d, outcomes %s" % (
        len(ctrl), sum(int(r["skill_any"]) for r in ctrl), sum(bool(r["skill_calls_run"]) for r in ctrl),
        dict(collections.Counter(r["outcome"] for r in ctrl))))
    p("  stamp %d: Skill(workdir-stamp) first call %d, bundled file read with ReadFile %d, via BashExec %d, STAMP.txt with token %d, stamp states %s, in launch dir %d" % (
        len(stamp), sum(int(r["skill_first"]) and r["loaded"] == "workdir-stamp" for r in stamp),
        sum(int(r["read_bundled"] or 0) for r in stamp), sum(int(r["bash_bundled"] or 0) for r in stamp),
        sum(r["stamp"] == "done" for r in stamp), dict(collections.Counter(r["stamp"] for r in stamp)),
        sum(int(r["stamp_in_launch"] or 0) for r in stamp)))
    p("  first response: %s; nudged after the first response %d" % (
        dict(collections.Counter(r["first_kind"] for r in mine)), sum(int(r["nudged_after_first"] or 0) for r in mine)))
    p("  requests per session %s; finish %s" % (
        dict(sorted(collections.Counter(r["requests"] for r in mine).items())), dict(collections.Counter(r["finish"] for r in mine))))
    tin = sum(int(r["input_tokens"] or 0) for r in mine)
    tout = sum(int(r["output_tokens"] or 0) for r in mine)
    cost = [float(r["cost"] or 0) for r in mine]
    p("  tokens in %d out %d; list cost $%.4f, dearest session $%.4f" % (tin, tout, sum(cost), max(cost) if cost else 0))

    # per-capture facts the session table does not carry
    length = killed = stubs = launch_writes = 0
    stub_tools = collections.Counter()
    writers = collections.Counter()
    errs = collections.Counter()
    length_sessions = []
    for r in mine:
        d = row_b.out_dir(model, int(r["task"]), int(r["trial"]))
        ev = events.load(d)
        tx = events.session_txt(d)
        n_len = sum(1 for s in events.steps(ev) if s["finish_reason"] == "length")
        if n_len:
            length += n_len
            length_sessions.append("%s x%d" % (os.path.basename(d), n_len))
        if tx.get("killed", "no") != "no":
            killed += 1
            p("    KILLED %s: %s" % (os.path.basename(d), tx.get("killed")))
        sl = os.path.join(d, "stub_calls.log")
        if os.path.exists(sl):
            lines = [l for l in open(sl, errors="replace").read().splitlines() if l.strip()]
            stubs += len(lines)
            for l in lines:
                stub_tools[next((w for w in ("gh", "herdr") if w in l.split()[:4] or l.startswith(w)), "?")] += 1
        lr = os.path.join(d, "launch_restore.txt")
        if os.path.exists(lr) and open(lr).read().strip():
            launch_writes += 1
        for e in ev:
            if e.get("type") == "error" and e.get("code") != "StepBudgetExhausted":
                errs[str(e.get("code"))] += 1
        if r["kind"] == "stamp":
            calls = events.calls_by_step(ev)
            w = [t for cs in calls.values() for t, a in cs if "STAMP" in json.dumps(a) and t in ("WriteFile", "BashExec", "EditFile")]
            writers[",".join(sorted(set(w))) or "-"] += 1
    p("  responses cut off at the output limit (finish_reason length): %d, in %d sessions %s" % (length, len(length_sessions), length_sessions[:12]))
    p("  sessions killed by a guard: %d; stub calls: %d %s; sessions that wrote into the launch dir: %d; other error events: %s" % (
        killed, stubs, dict(stub_tools), launch_writes, dict(errs)))
    p("  stamp written with: %s" % dict(writers))
    for r in mine:
        miss = (r["kind"] != "m2" or r["expected"] != "-") and r["hit_first_response"] != "1"
        ctrl_skill = r["kind"] == "m2" and r["expected"] == "-" and r["skill_calls_run"]
        nostamp = r["kind"] == "stamp" and r["stamp"] != "done"
        if miss or ctrl_skill or nostamp or r["outcome"] == "error":
            p("    NOTE task %s trial %s (%s, expected %s): outcome %s, first_kind %s, first_tool %s, loaded %s, skill calls %s, requests %s, finish %s, stamp %s %s" % (
                r["task"], r["trial"], r["kind"], r["expected"], r["outcome"], r["first_kind"], r["first_tool"], r["loaded"],
                r["skill_calls_run"] or "-", r["requests"], r["finish"], r["stamp"] or "-", r["error"]))

p("")
errs = sorted(glob.glob(os.path.join(HERE, "capture", "b-errors", "*")))
p("capture/b-errors: %s" % [os.path.basename(e) for e in errs])
open(os.path.join(HERE, "results", "row_b_ext_notes.txt"), "w").write("\n".join(out) + "\n")
