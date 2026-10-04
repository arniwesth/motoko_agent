#!/usr/bin/env python3
"""037 P1.3b: the research's M2 task set through the real runtime under
skills_proto, on the three profile models, plus two tasks for the checkable
action (workdir-stamp).

  row_b.py run [trials] [first_trial]   live sessions, one at a time (default 5 trials)
  row_b.py table                         results/row_b_sessions.tsv and row_b.tsv

The 15 M2 tasks and the three models are IMPORTED from
.agent/projects/037_skills_system/evidence/m2_trigger_probe.py, unchanged; so
is its `score` function. The two stamp tasks are new and are listed below.

Order is trial-major (trial, then model, then task), so a run that stops early
has the same number of trials for every model and task. A session whose capture
already holds a finished run is skipped, so the command resumes.

M2-task sessions use the template whose profile copy has agent.max_steps = 3;
stamp sessions use the one with agent.max_steps = 8.
"""
import importlib.util, json, os, subprocess, sys
sys.dont_write_bytecode = True  # importing the M2 probe must not leave a __pycache__ in the evidence folder
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import events

WORKTREE = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
spec = importlib.util.spec_from_file_location(
    "m2", os.path.join(WORKTREE, ".agent/projects/037_skills_system/evidence/m2_trigger_probe.py"))
m2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m2)

MODELS = m2.MODELS
STAMP_TASKS = [
    ("workdir-stamp", "Stamp the working directory. We are freezing this workspace for the 0.9 release."),
    ("workdir-stamp", "Before I hand this workspace over to the night shift, mark it so they can see it was checked today."),
]
TASKS = [(e, t, "m2") for e, t in m2.TASKS] + [(e, t, "stamp") for e, t in STAMP_TASKS]
NAMES = ["ailang-feedback", "dagr-producer", "herdr", "observer", "pr-review-loop", "workdir-stamp"]
TPL = {"m2": "/tmp/motoko-037-p1.3/tpl-b-m2", "stamp": "/tmp/motoko-037-p1.3/tpl-b-stamp"}
WORK = "/tmp/motoko-037-p1.3/work/fixture"
TOKEN = "motoko-skill-stamp-7f3a"


def short(model):
    return model.split("/")[-1]


def label(model, ti, trial):
    return "%s.t%02d.r%d" % (short(model), ti, trial)


def out_dir(model, ti, trial):
    return os.path.join(HERE, "capture", "b", label(model, ti, trial))


def finished(d):
    """A capture counts when the model answered at least once. A session the
    provider refused before any answer (seen on muse: `ModelNotFound: Provider
    returned error`) is moved to capture/b-errors/ and run again."""
    return bool(events.steps(events.load(d)))


def set_aside(d):
    if not os.path.isdir(d):
        return
    dst_root = os.path.join(HERE, "capture", "b-errors")
    os.makedirs(dst_root, exist_ok=True)
    n = 1
    while os.path.exists(os.path.join(dst_root, "%s.try%d" % (os.path.basename(d), n))):
        n += 1
    os.rename(d, os.path.join(dst_root, "%s.try%d" % (os.path.basename(d), n)))


def run(trials, first):
    for trial in range(first, trials):
        for model in MODELS:
            for ti, (expected, task, kind) in enumerate(TASKS):
                d = out_dir(model, ti, trial)
                tries = 0
                while not (os.path.isdir(d) and finished(d)) and tries < 2:
                    tries += 1
                    set_aside(d)
                    r = subprocess.run([
                        sys.executable, os.path.join(HERE, "live_session.py"), "--row", "b",
                        "--label", label(model, ti, trial), "--out", d, "--template", TPL[kind], "--workdir", WORK,
                        "--model", "openrouter/" + model, "--task", task,
                        "--timeout", "420" if kind == "m2" else "600",
                        "--reserve", "0.03", "--session-cap", "0.06" if kind == "m2" else "0.12"], cwd=WORKTREE)
                    if r.returncode == 3:
                        print("STOPPED: the spend guard refused the next session")
                        return 3
        print("=== trial %d complete ===" % trial, flush=True)
    return 0


def score_session(model, ti, trial):
    expected, task, kind = TASKS[ti]
    d = out_dir(model, ti, trial)
    if not os.path.isdir(d):
        return None
    ev = events.load(d)
    st = events.steps(ev)
    calls = events.calls_by_step(ev)
    s = events.summary(ev) or {}
    tx = events.session_txt(d)
    row = {"model": model, "task": ti, "kind": kind, "trial": trial, "expected": expected or "-",
           "requests": len(st), "finish": s.get("finish_reason") or tx.get("finish_reason", ""),
           "input_tokens": tx.get("input_tokens", ""), "output_tokens": tx.get("output_tokens", ""),
           "cost": tx.get("list_cost_usd", "")}
    if not st:
        row.update(outcome="error", first_tool="", skill_first=0, skill_any=0, loaded="", hit_first_response=0,
                   hit_within_run=0, stamp="", error=(s.get("error") or tx.get("killed", ""))[:200])
        return row
    first = calls.get(0, [])
    # what the first response was: tool calls, text only, or nothing at all (the
    # empty-stop guard then nudges the model and the run goes on)
    first_kind = "tool_calls" if first else ("text" if (st[0]["text"] or "").strip() else "empty")
    nudged = int(any(e.get("type") == "ext_solver_feedback" and e.get("step") == 0 for e in ev))
    row.update(first_kind=first_kind, nudged_after_first=nudged, out_tokens_first=st[0]["output_tokens"])
    m2calls = [(t, json.dumps(a)) for t, a in first]
    outcome, loaded, first_tool, _ = m2.score(expected, m2calls, NAMES)
    all_skill = [(stp, a.get("name")) for stp, cs in sorted(calls.items()) for t, a in cs if t == "Skill"]
    row.update(outcome=outcome, first_tool=first_tool, loaded=loaded,
               skill_first=int(first_tool == "Skill"),
               skill_any=int(any(t == "Skill" for t, _ in first)),
               hit_first_response=int(outcome == "hit"),
               hit_within_run=int(expected is not None and any(n == expected for _, n in all_skill)),
               skill_calls_run=";".join("%s@%s" % (n, stp) for stp, n in all_skill),
               error=(s.get("error") or "")[:200])
    if kind == "stamp":
        wd = os.path.join(d, "STAMP.workdir.txt")
        ln = os.path.join(d, "STAMP.launch.txt")
        txt = open(wd, errors="replace").read() if os.path.exists(wd) else ""
        read_bundled = any(t == "ReadFile" and "stamp-format.txt" in str(a.get("path", "")) for cs in calls.values() for t, a in cs)
        bash_bundled = any(t == "BashExec" and "stamp-format" in json.dumps(a) for cs in calls.values() for t, a in cs)
        row.update(stamp=("done" if TOKEN in txt else ("file-without-token" if txt else "no-file")),
                   stamp_line=txt.strip().replace("\t", " ")[:120],
                   stamp_in_launch=int(os.path.exists(ln)),
                   read_bundled=int(read_bundled), bash_bundled=int(bash_bundled),
                   extra_files=open(os.path.join(d, "workdir_diff.txt")).read().strip().replace("\n", " | ")[:200])
    else:
        row.update(stamp="")
    return row


def table():
    rows = []
    for model in MODELS:
        for ti in range(len(TASKS)):
            for trial in range(0, 9):
                r = score_session(model, ti, trial)
                if r:
                    rows.append(r)
    cols = ["model", "task", "kind", "trial", "expected", "outcome", "first_kind", "nudged_after_first", "out_tokens_first", "first_tool", "skill_first", "skill_any", "loaded",
            "hit_first_response", "hit_within_run", "skill_calls_run", "requests", "finish", "stamp", "stamp_line",
            "stamp_in_launch", "read_bundled", "bash_bundled", "extra_files", "input_tokens", "output_tokens", "cost", "error"]
    os.makedirs(os.path.join(HERE, "results"), exist_ok=True)
    with open(os.path.join(HERE, "results", "row_b_sessions.tsv"), "w") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r.get(c, "")) for c in cols) + "\n")
    lines = []

    def pct(a, b):
        return "%d/%d (%d%%)" % (a, b, round(100.0 * a / b)) if b else "0/0"
    lines.append("model\tset\tsessions\terrors\tfirst_response_empty\tskill_first_call\tskill_any_first_response\texpected_skill_first_response\texpected_skill_within_run\twrong_skill\tstamp_done")
    for model in MODELS:
        mine = [r for r in rows if r["model"] == model]
        for name, sel in (("M2 trigger tasks (10)", lambda r: r["kind"] == "m2" and r["expected"] != "-"),
                          ("M2 control tasks (5)", lambda r: r["kind"] == "m2" and r["expected"] == "-"),
                          ("stamp tasks (2)", lambda r: r["kind"] == "stamp")):
            g = [r for r in mine if sel(r)]
            ok = [r for r in g if r["outcome"] != "error"]
            n = len(ok)
            stamp = pct(sum(r["stamp"] == "done" for r in ok), n) if name.startswith("stamp") else ""
            lines.append("\t".join([model, name, str(len(g)), str(len(g) - n),
                                    pct(sum(r.get("first_kind") == "empty" for r in ok), n),
                                    pct(sum(r["skill_first"] for r in ok), n), pct(sum(r["skill_any"] for r in ok), n),
                                    pct(sum(r["hit_first_response"] for r in ok), n) if "control" not in name else "n/a",
                                    pct(sum(r["hit_within_run"] for r in ok), n) if "control" not in name else "n/a",
                                    str(sum(r["outcome"] in ("wrong-skill", "bad-args", "skill-as-tool") for r in ok)), stamp]))
    lines.append("")
    lines.append("per expected skill, expected-skill-in-first-response / sessions, by model")
    lines.append("skill\t" + "\t".join(short(m) for m in MODELS))
    for sk in NAMES:
        cells = []
        for model in MODELS:
            g = [r for r in rows if r["model"] == model and r["expected"] == sk and r["outcome"] != "error"]
            cells.append("%d/%d" % (sum(r["hit_first_response"] for r in g), len(g)))
        lines.append(sk + "\t" + "\t".join(cells))
    open(os.path.join(HERE, "results", "row_b.tsv"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("\nsessions scored: %d; list cost of these sessions: $%.4f" % (len(rows), sum(float(r["cost"] or 0) for r in rows)))


if __name__ == "__main__":
    if sys.argv[1] == "run":
        trials = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        first = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        rc = run(trials, first)
        table()
        sys.exit(rc)
    else:
        table()
