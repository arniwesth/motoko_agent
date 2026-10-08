#!/usr/bin/env python3
"""037 P1.3d: a context limit small enough that D8's size check must answer
with its error instead of loading the skill. Live sessions, real runtime.

  row_d.py run pro [n]     declared agent.context_limit = 16,000 on deepseek-v4-pro
  row_d.py run reka [n]    rekaai/reka-edge, a real 16,384-token model (declared 16,384)
  row_d.py table

The task is M2 task 2 (dagr-producer), unchanged. dagr-producer's result is about
6,071 tokens by the handler's arithmetic, over 25% of either limit.
"""
import importlib.util, json, os, subprocess, sys
sys.dont_write_bytecode = True  # importing the M2 probe must not leave a __pycache__ in the evidence folder
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import events
WORKTREE = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
spec = importlib.util.spec_from_file_location(
    "m2", os.path.join(WORKTREE, ".agent/projects/037_skills_system/evidence/m2_trigger_probe.py"))
m2 = importlib.util.module_from_spec(spec); spec.loader.exec_module(m2)
TASK = m2.TASKS[2][1]
WORK = "/tmp/motoko-037-p1.3/work/fixture"
VARIANTS = {
    "pro": ("openrouter/deepseek/deepseek-v4-pro", "/tmp/motoko-037-p1.3/tpl-d-pro", 16000),
    "reka": ("openrouter/rekaai/reka-edge", "/tmp/motoko-037-p1.3/tpl-d-reka", 16384),
}


def run(variant, n):
    model, tpl, limit = VARIANTS[variant]
    subprocess.run([os.path.join(HERE, "build_fixture.sh"), tpl, "context_limit=%d" % limit, "max_steps=5"],
                   cwd=WORKTREE, check=True)
    for i in range(n):
        d = os.path.join(HERE, "capture", "d", "%s.r%d" % (variant, i))
        if os.path.isdir(d) and events.load(d):
            continue
        r = subprocess.run([sys.executable, os.path.join(HERE, "live_session.py"), "--row", "d",
                            "--label", "%s.r%d" % (variant, i), "--out", d, "--template", tpl, "--workdir", WORK,
                            "--model", model, "--task", TASK, "--timeout", "480", "--reserve", "0.05",
                            "--session-cap", "0.08"], cwd=WORKTREE)
        if r.returncode == 3:
            return


def table():
    out = ["session\tmodel\tdeclared_limit\tlimit_resolved\trequests\tskill_calls(step:name:exit)\tskill_error_verbatim\tcalled_again_after_error\tnext_calls_after_error\tfinish\tprovider_or_run_error"]
    for variant, (model, tpl, limit) in VARIANTS.items():
        for i in range(0, 6):
            d = os.path.join(HERE, "capture", "d", "%s.r%d" % (variant, i))
            if not os.path.isdir(d):
                continue
            ev = events.load(d)
            clr = events.of_type(ev, "context_limit_resolved")
            calls = events.calls_by_step(ev)
            handled = {e.get("id"): e.get("exit_code") for e in events.of_type(ev, "ext_tool_handled")}
            skill = []
            verb = ""
            first_err_step = None
            for e in events.of_type(ev, "native_tool_calls"):
                for c in e.get("tool_calls", []):
                    if c.get("tool") == "Skill":
                        ex = handled.get(c.get("id"))
                        skill.append("%s:%s:%s" % (e.get("step"), (c.get("arguments") or {}).get("name"), ex))
                        if ex == 1 and first_err_step is None:
                            first_err_step = e.get("step")
            for st, c in events.tool_messages(ev):
                if '"tool":"Skill"' in c[:90] and '"exit_code":1' in c[:120] and not verb:
                    try:
                        verb = json.loads(c).get("stderr", "")
                    except ValueError:
                        verb = c[:400]
            again = ""
            nxt = ""
            if first_err_step is not None:
                later = [(s, t, a) for s, cs in sorted(calls.items()) if s > first_err_step for t, a in cs]
                again = "yes" if any(t == "Skill" and a.get("name") == "dagr-producer" for _, t, a in later) else "no"
                nxt = "; ".join("%s:%s%s" % (s, t, ("(" + str(a.get("name") or a.get("path") or a.get("cmd") or "")[:40] + ")")) for s, t, a in later[:6])
            s = events.summary(ev) or {}
            errs = [e for e in events.of_type(ev, "error", "fatal") if e.get("code") != "StepBudgetExhausted"]
            retry = events.of_type(ev, "stream_error_retry")
            perr = " | ".join(json.dumps({k: e.get(k) for k in ("type", "source", "code", "message")}, ensure_ascii=False) for e in errs + retry[:1])
            out.append("\t".join(str(x) for x in [
                "%s.r%d" % (variant, i), model, limit, clr[0].get("context_limit") if clr else "",
                len(events.steps(ev)), ", ".join(skill), verb, again, nxt, s.get("finish_reason"), perr[:1500]]))
    open(os.path.join(HERE, "results", "row_d.tsv"), "w").write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    if sys.argv[1] == "run":
        run(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 3)
    table()
