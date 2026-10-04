#!/usr/bin/env python3
"""037 P1.3b extension (operator ruling 2026-10-04): row b on four more models.

  row_b_ext.py smoke [model ...]        one session per new model on one M2 trigger task
  row_b_ext.py run [trials] [first]     live sessions, one at a time (default 3 trials)
  row_b_ext.py table                    results/row_b_ext.tsv and row_b_ext_sessions.tsv

Everything that decides a result is row_b.py's, imported and unchanged: the 17
tasks, the two fixture templates (max_steps 3 / 8), the session command line
(live_session.py), `finished`, `set_aside` and `score_session`. What is new here:

  * the model list (NEW_MODELS, in the ruling's order);
  * the P1.3 cap passed to live_session.py is 7.00, and the reserve is the
    session cap plus 0.03, so a session that runs to its own cap still ends
    under 7.00;
  * glm-5.3's per-session dollar guard is doubled (see SESSION_CAP_BY_MODEL);
  * the smoke sessions go to capture/b-smoke/ and are not scored;
  * the tables are COPIES of row b's with the new models' rows appended:
    row_b.tsv and row_b_sessions.tsv are not rewritten. `table` checks that the
    first three models' lines in the copies are identical to the originals.

Order is trial-major, as in row b. Captures go to capture/b/<model>.tNN.rN/.
"""
import os, subprocess, sys
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import events
import row_b

NEW_MODELS = [
    "deepseek/deepseek-v4.1-flash",
    "z-ai/glm-5.3",
    "xiaomi/mimo-v2.6-pro",
    "tencent/hy4-preview",
]
ALL_MODELS = list(row_b.MODELS) + NEW_MODELS
CAP = "7.00"
SESSION_CAP = {"m2": 0.06, "stamp": 0.12}   # row b's
# glm-5.3 lists at $1.40 / $4.40 per million, 7 to 60 times the first three
# models' input price. Its smoke session (3 requests, one of them cut off at the
# 4,096-token output limit) cost $0.053, so row b's $0.06 guard would end
# sessions before their step cap and drop the last response's calls from the
# score. The dollar guard is doubled for this model only; max_steps is the same.
SESSION_CAP_BY_MODEL = {"z-ai/glm-5.3": {"m2": 0.12, "stamp": 0.24}}
SMOKE_TASK = 2                               # dagr-producer: "Set up a dagr run file ..."


def session(model, ti, label, out, row):
    expected, task, kind = row_b.TASKS[ti]
    cap = SESSION_CAP_BY_MODEL.get(model, SESSION_CAP)[kind]
    return subprocess.run([
        sys.executable, os.path.join(HERE, "live_session.py"), "--row", row,
        "--label", label, "--out", out, "--template", row_b.TPL[kind], "--workdir", row_b.WORK,
        "--model", "openrouter/" + model, "--task", task,
        "--timeout", "420" if kind == "m2" else "600",
        "--cap", CAP, "--reserve", "%.2f" % (cap + 0.03),
        "--session-cap", "%.2f" % cap], cwd=row_b.WORKTREE).returncode


def smoke(models):
    worst = 0
    for model in models:
        label = "%s.t%02d.smoke" % (row_b.short(model), SMOKE_TASK)
        d = os.path.join(HERE, "capture", "b-smoke", label)
        n = 1
        while os.path.isdir(d):          # keep an earlier try, never overwrite it
            n += 1
            d = os.path.join(HERE, "capture", "b-smoke", "%s.try%d" % (label, n))
        rc = session(model, SMOKE_TASK, label, d, "b-smoke")
        ev = events.load(d)
        st = events.steps(ev)
        calls = events.calls_by_step(ev)
        s = events.summary(ev) or {}
        started = bool(events.start(ev))
        tools = [t for _, cs in sorted(calls.items()) for t, _ in cs]
        ok = started and bool(st) and bool(tools)
        print("SMOKE %s: %s | runtime started=%s provider responses=%d tool calls=%s first=%s finish=%s error=%s rc=%s" % (
            model, "PASS" if ok else "FAIL", started, len(st), tools,
            [(t, a.get("name")) if t == "Skill" else t for t, a in calls.get(0, [])],
            s.get("finish_reason"), (s.get("error") or "")[:160], rc), flush=True)
        if rc == 3:
            print("STOPPED: the spend guard refused the session")
            return 3
        worst = worst or (0 if ok else 1)
    return worst


def run(trials, first):
    for trial in range(first, trials):
        for model in NEW_MODELS:
            for ti in range(len(row_b.TASKS)):
                d = row_b.out_dir(model, ti, trial)
                tries = 0
                while not (os.path.isdir(d) and row_b.finished(d)) and tries < 2:
                    tries += 1
                    row_b.set_aside(d)
                    rc = session(model, ti, row_b.label(model, ti, trial), d, "b")
                    if rc == 3:
                        print("STOPPED: the spend guard refused the next session")
                        return 3
        print("=== trial %d complete ===" % trial, flush=True)
        subprocess.run([sys.executable, os.path.join(HERE, "key_usage.py"),
                        "P1.3b extension: trial %d of the 4 new models complete" % trial])
    return 0


def table():
    """row_b.table()'s two tables, over seven models, written to the _ext copies."""
    rows = []
    for model in ALL_MODELS:
        for ti in range(len(row_b.TASKS)):
            for trial in range(0, 9):
                r = row_b.score_session(model, ti, trial)
                if r:
                    rows.append(r)
    cols = ["model", "task", "kind", "trial", "expected", "outcome", "first_kind", "nudged_after_first", "out_tokens_first", "first_tool", "skill_first", "skill_any", "loaded",
            "hit_first_response", "hit_within_run", "skill_calls_run", "requests", "finish", "stamp", "stamp_line",
            "stamp_in_launch", "read_bundled", "bash_bundled", "extra_files", "input_tokens", "output_tokens", "cost", "error"]
    res = os.path.join(HERE, "results")
    sess = ["\t".join(cols)] + ["\t".join(str(r.get(c, "")) for c in cols) for r in rows]
    open(os.path.join(res, "row_b_ext_sessions.tsv"), "w").write("\n".join(sess) + "\n")
    lines = []

    def pct(a, b):
        return "%d/%d (%d%%)" % (a, b, round(100.0 * a / b)) if b else "0/0"
    lines.append("model\tset\tsessions\terrors\tfirst_response_empty\tskill_first_call\tskill_any_first_response\texpected_skill_first_response\texpected_skill_within_run\twrong_skill\tstamp_done")
    for model in ALL_MODELS:
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
    lines.append("skill\t" + "\t".join(row_b.short(m) for m in ALL_MODELS))
    for sk in row_b.NAMES:
        cells = []
        for model in ALL_MODELS:
            g = [r for r in rows if r["model"] == model and r["expected"] == sk and r["outcome"] != "error"]
            cells.append("%d/%d" % (sum(r["hit_first_response"] for r in g), len(g)))
        lines.append(sk + "\t" + "\t".join(cells))
    open(os.path.join(res, "row_b_ext.tsv"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    new = [r for r in rows if r["model"] in NEW_MODELS]
    print("\nsessions scored: %d (%d on the new models); list cost of the new models' scored sessions: $%.4f" % (
        len(rows), len(new), sum(float(r["cost"] or 0) for r in new)))

    # the copies must carry the first three models' lines unchanged
    n3 = len(row_b.MODELS)
    o_sess = open(os.path.join(res, "row_b_sessions.tsv")).read().splitlines()
    o_tab = open(os.path.join(res, "row_b.tsv")).read().splitlines()
    same_sess = sess[:len(o_sess)] == o_sess
    same_tab = lines[:1 + 3 * n3] == o_tab[:1 + 3 * n3]
    o_skill = {l.split("\t")[0]: l.split("\t")[1:] for l in o_tab[-len(row_b.NAMES):]}
    e_skill = {l.split("\t")[0]: l.split("\t")[1:1 + n3] for l in lines[-len(row_b.NAMES):]}
    print("copies carry row b unchanged: sessions %s, summary %s, per-skill %s" % (same_sess, same_tab, o_skill == e_skill))
    return 0 if (same_sess and same_tab and o_skill == e_skill) else 4


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "table"
    if cmd == "smoke":
        sys.exit(smoke(sys.argv[2:] or NEW_MODELS))
    elif cmd == "run":
        trials = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        first = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        rc = run(trials, first)
        table()
        sys.exit(rc)
    else:
        sys.exit(table())
