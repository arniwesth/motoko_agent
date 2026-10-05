#!/usr/bin/env python3
"""Does a model call `Skill` for a matching task, and does it matter whether the
skill index sits in the tool description or in the system prompt?

Evidence for RESEARCH-skills-system.md §9 M2. Not a gate.

    python3 .agent/projects/037_skills_system/evidence/m2_trigger_probe.py [trials]

A PROXY, not the harness: one chat-completions request per case, straight to
OpenRouter, with Motoko's SYSTEM.md as the system message, the seven native
tool schemas parsed from src/core/tool_catalog.ail, and one `Skill` tool built
from the five skills in .claude/skills/. Only the first assistant response is
scored. The profile's extension tools and prompt patches are absent, and no
skill body is ever returned.

Needs OPENROUTER_API_KEY. Run from the repo root. Writes m2_results.tsv beside
this file. About 90 requests per trial; under $0.10 per trial at 2026-10-03
prices.
"""
import concurrent.futures as cf
import glob
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = [
    "meta/muse-spark-1.3-contributor",  # default profile
    "deepseek/deepseek-v4-pro",         # most profiles
    "deepseek/deepseek-v4-flash",       # cheapest profile model
]

# (expected skill or None, task). Controls expect no Skill call.
TASKS = [
    ("ailang-feedback", "`ailang check src/core/prompts.ail` fails with 'cannot unify type constructors: BStatus vs AStatus' on two identically shaped sum types. Is this an AILANG bug, and should it be filed upstream?"),
    ("ailang-feedback", "The AILANG parser rejects a zero-argument lambda in expression position. That looks like a language limitation rather than our code. What should we do about it?"),
    ("dagr-producer", "I'm about to orchestrate three delegates for the release work. Set up a dagr run file so the dagr pane shows the tasks and their gates."),
    ("dagr-producer", "Record a new attempt and its evidence for task P1.2 in the dagr run file."),
    ("herdr", "Use Herdr to open a new pane and start a second agent in it."),
    ("herdr", "Check with herdr what the agent in the other pane is doing."),
    ("observer", "You are the Observer for this run. Supervise the orchestrator in the other pane and tell me whether the graph is telling the truth."),
    ("observer", "Babysit the orchestrator run and audit its state against the dagr file."),
    ("pr-review-loop", "Did anyone comment on our open PRs? Triage whatever review feedback is outstanding."),
    ("pr-review-loop", "Work the PR comment queue and respond to the reviewer on #210."),
    (None, "Fix the typo 'a a highly' in SYSTEM.md."),
    (None, "What does src/core/prompts.ail export? Summarize it."),
    (None, "Run the core checks and tell me if anything fails."),
    (None, "Add a unit test for dirname in src/core/agents_md.ail covering a Windows path."),
    (None, "How many extension packages are under packages/?"),
]

HOW = ("Skills are task-specific instructions. Before starting a task that matches a "
       "skill's description, call Skill with its name to load the instructions. "
       "Do not load a skill that does not match the task.")


def native_tools():
    src = open("src/core/tool_catalog.ail").read()
    s = r'"((?:[^"\\]|\\.)*)"'
    out = []
    for n, d, p in re.findall(rf"name: {s},\s*description: {s},\s*parameters: {s}", src):
        unq = lambda x: json.loads('"' + x + '"')
        out.append({"type": "function", "function": {
            "name": unq(n), "description": unq(d), "parameters": json.loads(unq(p))}})
    assert len(out) == 7, len(out)
    return out


def skills():
    out = []
    for p in sorted(glob.glob(".claude/skills/*/SKILL.md")):
        fm = re.match(r"^---\n(.*?)\n---\n", open(p).read(), re.S).group(1)
        name = re.search(r"^name:\s*(.*)$", fm, re.M).group(1).strip()
        desc = re.search(r"^description:\s*(.*)$", fm, re.M).group(1).strip()
        out.append((name, desc))
    assert len(out) == 5, len(out)
    return out


def build(variant, sk):
    index = "\n".join(f"- {n}: {d}" for n, d in sk)
    system = open("SYSTEM.md").read()
    params = {"type": "object", "properties": {"name": {"type": "string", "enum": [n for n, _ in sk]}},
              "required": ["name"]}
    if variant == "tool":
        desc = f"Load a skill by name. {HOW}\n\nAvailable skills:\n{index}"
    else:
        desc = "Load a skill by name. The available skills are listed in the Skills section of the system prompt."
        system = f"{system}\n\n## Skills\n\n{HOW}\n\nAvailable skills:\n{index}\n"
    tools = native_tools() + [{"type": "function", "function": {
        "name": "Skill", "description": desc, "parameters": params}}]
    return system, tools


def call(model, system, tools, task):
    body = json.dumps({
        "model": model,
        "messages": [{"role": "system", "content": system}, {"role": "user", "content": task}],
        "tools": tools,
        "max_tokens": 2000,
    }).encode()
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions", data=body,
        headers={"Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}",
                 "Content-Type": "application/json",
                 "X-Title": "motoko_agent"})
    last = ""
    for _ in range(3):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                d = json.load(r)
            if "choices" not in d:
                last = "no-choices:" + json.dumps(d)[:120]
                continue
            msg = d["choices"][0]["message"]
            calls = [(c["function"]["name"], c["function"].get("arguments") or "{}")
                     for c in (msg.get("tool_calls") or [])]
            return calls, d.get("usage", {}), ""
        except Exception as e:  # network or decode; retried
            last = f"{type(e).__name__}:{str(e)[:100]}"
    return None, {}, last


def score(expected, calls, names):
    """-> (outcome, loaded, first_tool, skill_args)

    hit            Skill called with the expected name
    miss           no Skill call in the first response
    wrong-skill    Skill called with another valid name
    bad-args       Skill called, but no usable `name` argument
    skill-as-tool  a tool named after a skill was called instead of Skill
    """
    if calls is None:
        return "error", "", "", ""
    first = calls[0][0] if calls else ""
    as_tool = next((n for n, _ in calls if n in names), "")
    loaded, raw = "", ""
    for n, a in calls:
        if n == "Skill":
            raw = a
            try:
                v = json.loads(a).get("name", "")
                loaded = v if isinstance(v, str) and v in names else "?"
            except Exception:
                loaded = "?"
            break
    if expected is None:
        return ("false-positive" if (loaded or as_tool) else "correct-none"), loaded, first, raw
    if loaded == expected:
        return "hit", loaded, first, raw
    if loaded == "?":
        return "bad-args", loaded, first, raw
    if loaded:
        return "wrong-skill", loaded, first, raw
    if as_tool:
        return "skill-as-tool", as_tool, first, raw
    return "miss", loaded, first, raw


def main():
    trials = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    sk = skills()
    names = [n for n, _ in sk]
    built = {v: build(v, sk) for v in ("tool", "system")}
    jobs = [(m, v, i, t) for m in MODELS for v in built for i in range(len(TASKS)) for t in range(trials)]

    def run(job):
        m, v, i, t = job
        expected, task = TASKS[i]
        calls, usage, err = call(m, built[v][0], built[v][1], task)
        outcome, loaded, first, raw = score(expected, calls, names)
        return job, expected, outcome, loaded, first, usage, err, raw

    rows = []
    with cf.ThreadPoolExecutor(8) as ex:
        for r in ex.map(run, jobs):
            rows.append(r)

    with open(os.path.join(HERE, "m2_results.tsv"), "w") as f:
        f.write("model\tvariant\ttask\ttrial\texpected\toutcome\tloaded\tfirst_tool\tprompt_tokens\terror\tskill_args\n")
        for (m, v, i, t), expected, outcome, loaded, first, usage, err, raw in rows:
            raw = raw.replace("\t", " ").replace("\n", " ")[:120]
            f.write(f"{m}\t{v}\t{i}\t{t}\t{expected or '-'}\t{outcome}\t{loaded}\t{first}\t{usage.get('prompt_tokens', '')}\t{err}\t{raw}\n")

    tin = sum(r[5].get("prompt_tokens", 0) for r in rows)
    tout = sum(r[5].get("completion_tokens", 0) for r in rows)
    print(f"requests={len(rows)} trials={trials} prompt_tokens={tin} completion_tokens={tout}\n")
    print(f"{'model':34} {'index in':8} {'hit':>9} {'miss':>5} {'wrong':>6} {'badarg':>7} {'astool':>7} {'ctrl ok':>8} {'false+':>7} {'err':>4}")
    for m in MODELS:
        for v in built:
            c = {}
            for (mm, vv, _, _), _, outcome, *_ in rows:
                if mm == m and vv == v:
                    c[outcome] = c.get(outcome, 0) + 1
            trig = sum(c.get(k, 0) for k in ("hit", "miss", "wrong-skill", "bad-args", "skill-as-tool"))
            print(f"{m:34} {v:8} {c.get('hit', 0):>4}/{trig:<4} {c.get('miss', 0):>5} {c.get('wrong-skill', 0):>6} "
                  f"{c.get('bad-args', 0):>7} {c.get('skill-as-tool', 0):>7} "
                  f"{c.get('correct-none', 0):>8} {c.get('false-positive', 0):>7} {c.get('error', 0):>4}")
    print("\nper skill, hits/attempts (tool | system), all models:")
    for name, _ in sk:
        cell = []
        for v in built:
            h = sum(1 for (_, vv, i, _), e, o, *_ in rows if vv == v and e == name and o == "hit")
            n = sum(1 for (_, vv, i, _), e, o, *_ in rows if vv == v and e == name and o != "error")
            cell.append(f"{h}/{n}")
        print(f"  {name:16} {cell[0]:>6} | {cell[1]:>6}")


if __name__ == "__main__":
    main()
