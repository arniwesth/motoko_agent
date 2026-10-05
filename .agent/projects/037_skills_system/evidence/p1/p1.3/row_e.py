#!/usr/bin/env python3
"""037 P1.3e: one session per provider family with the Skill index at the
16,000-char budget (ADR D4 / V8), through the real runtime under skills_proto.

  row_e.py build          build the padded fixture template and print its index size
  row_e.py dry            one free session against the local recorder; verifies the
                          index the runtime sends is exactly 16,000 chars
  row_e.py run [family…]  the live sessions, one at a time
  row_e.py table          results/row_e.tsv from the captures

OpenAI is NOT in the list: ruled out of scope by the operator on 2026-10-04.
No OpenAI request is sent.
"""
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import events

WORKTREE = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TPL = "/tmp/motoko-037-p1.3/tpl-e"
WORK = "/tmp/motoko-037-p1.3/work/fixture"
BUDGET = 16000
TASK = "Please put a workdir stamp on this workspace before I hand it over to the release team."
FAMILIES = [
    ("DeepSeek", "openrouter/deepseek/deepseek-v4-pro"),
    ("Meta", "openrouter/meta/muse-spark-1.3-contributor"),
    ("Tencent", "openrouter/tencent/hy3"),
    ("Qwen", "openrouter/qwen/qwen3.6-35b-a3b"),
    ("Xiaomi", "openrouter/xiaomi/mimo-v2.6-pro"),
    ("Anthropic", "openrouter/anthropic/claude-haiku-4.5"),
    ("Google", "openrouter/google/gemini-2.5-flash"),
]
TOPICS = ["release-notes", "changelog-entry", "db-migration", "api-versioning", "incident-report", "load-test",
          "feature-flag", "dependency-bump", "license-audit", "docker-image", "ci-pipeline", "log-triage",
          "metrics-dashboard", "secret-rotation", "schema-review", "cache-tuning", "queue-backlog", "cron-audit",
          "locale-strings", "accessibility-pass", "bundle-size", "flaky-tests", "coverage-report", "lint-baseline",
          "perf-profile", "memory-leak", "rollback-plan", "canary-deploy", "backup-restore", "access-review",
          "cost-report", "onboarding-doc", "runbook-update", "postmortem-draft", "sdk-release", "api-deprecation",
          "data-export", "tenant-migration", "search-index", "email-template"]


def filler_description(topic, n):
    words = topic.replace("-", " ")
    base = ("Prepare and check the %s for this repository, following the team's written procedure step by step. "
            "Use when the user asks to draft, update, review or verify the %s, mentions a %s that is late, wrong or "
            "missing, or asks what the procedure for the %s is. Covers where the inputs live, which command produces "
            "the output, how to verify it afterwards, and who signs it off. Not for unrelated maintenance work." % (
                words, words, words, words))
    if n is None:
        return base
    pad = " Ask before changing anything outside the files the procedure names."
    while len(base) < n:
        base += pad
    return base[:n].rstrip() if len(base[:n].rstrip()) == n else base[:n - 1].rstrip() + "."


def real_lines():
    """Index lines of the six real fixture skills, as the extension builds them."""
    lines = {}
    d = json.load(open(os.path.join(HERE, "dry", "dry-b2", "req-01.json")))["body"]
    desc = [t for t in d["tools"] if t["function"]["name"] == "Skill"][0]["function"]["description"]
    for line in desc.split("\n"):
        if line.startswith("- "):
            lines[line[2:].split(":", 1)[0]] = line
    return lines


def build():
    subprocess.run([os.path.join(HERE, "build_fixture.sh"), TPL, "max_steps=2"], cwd=WORKTREE, check=True,
                   stdout=subprocess.DEVNULL)
    real = real_lines()
    lines = dict(real)
    names = []
    for i, topic in enumerate(TOPICS):
        name = "x%02d-%s" % (i + 1, topic)
        d = filler_description(topic, None)
        cand = dict(lines)
        cand[name] = "- %s: %s" % (name, d)
        total = len("\n".join(cand[k] for k in sorted(cand)))
        if total > BUDGET - 120:
            # last filler: sized so the joined index is exactly the budget
            room = BUDGET - len("\n".join(lines[k] for k in sorted(lines))) - 1 - len("- %s: " % name)
            d = filler_description(topic, room)
            lines[name] = "- %s: %s" % (name, d)
            names.append((name, d))
            break
        lines[name] = cand[name]
        names.append((name, d))
    for name, d in names:
        p = os.path.join(TPL, ".motoko", "skills", name)
        os.makedirs(p, exist_ok=True)
        with open(os.path.join(p, "SKILL.md"), "w") as f:
            f.write("---\nname: %s\ndescription: %s\n---\n\n# %s\n\nFiller skill for 037 P1.3e (index at the 16,000-char budget). It has no procedure.\n" % (
                name, json.dumps(d), name))
    index = "\n".join(lines[k] for k in sorted(lines))
    print("template %s: %d skills (%d filler); expected index %d chars; longest description %d chars" % (
        TPL, len(lines), len(names), len(index), max(len(d) for _, d in names)))
    return len(index)


def session(label, model, recorder=None):
    out = os.path.join(HERE, "capture", "e", label)
    cmd = [sys.executable, os.path.join(HERE, "live_session.py"), "--row", "e", "--label", label, "--out", out,
           "--template", TPL, "--workdir", WORK, "--model", model, "--task", TASK,
           "--timeout", "420", "--reserve", "0.08", "--session-cap", "0.15"]
    if recorder:
        cmd += ["--recorder", recorder]
    r = subprocess.run(cmd, cwd=WORKTREE)
    return out, r.returncode


def index_of(req_path):
    d = json.load(open(req_path))["body"]
    desc = [t for t in d["tools"] if t["function"]["name"] == "Skill"][0]["function"]["description"]
    head, _, index = desc.partition("Available skills:\n")
    return desc, index


def table():
    rows = ["family\tmodel\toutcome\trequests\tfirst_response_calls\tsecond_response_calls\tinput_tokens_request1\tprovider_error_verbatim"]
    for fam, model in FAMILIES:
        out = os.path.join(HERE, "capture", "e", fam)
        if not os.path.isdir(out):
            rows.append("%s\t%s\tnot run\t\t\t\t\t" % (fam, model))
            continue
        ev = events.load(out)
        st = events.steps(ev)
        calls = events.calls_by_step(ev)
        s = events.summary(ev) or {}
        # StepBudgetExhausted is this row's own agent.max_steps = 2, not a provider answer
        errs = [json.dumps(e, ensure_ascii=False) for e in events.of_type(ev, "error", "fatal", "stream_error_retry", "provider_error")
                if e.get("code") != "StepBudgetExhausted"]
        accepted = len(st) > 0 and st[0]["input_tokens"] > 0
        first = ", ".join("%s(%s)" % (t, a.get("name", "") if t == "Skill" else "") for t, a in calls.get(0, []))
        second = ", ".join("%s(%s)" % (t, a.get("name", "") or a.get("path", "")) for t, a in calls.get(1, []))
        rows.append("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % (
            fam, model, "accepted" if accepted else "REJECTED/ERROR", len(st),
            first or "(no tool call; text only)", second or "(no tool call)", st[0]["input_tokens"] if st else "",
            " | ".join(errs)[:1500]))
    rows.append("OpenAI\t(none)\tout of scope: operator ruling 2026-10-04; no request sent\t0\t\t\t\t")
    os.makedirs(os.path.join(HERE, "results"), exist_ok=True)
    open(os.path.join(HERE, "results", "row_e.tsv"), "w").write("\n".join(rows) + "\n")
    print("\n".join(rows))


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "build":
        build()
    elif mode == "dry":
        build()
        script = os.path.join(HERE, "dry_script_e.json")
        json.dump([{"tool": ["Skill", {"name": "workdir-stamp"}]}, {"text": "Dry run complete."}], open(script, "w"))
        out, rc = session("dry", "openrouter/deepseek/deepseek-v4-pro", recorder=script)
        desc, index = index_of(os.path.join(out, "req-01.json"))
        print("dry rc=%s; Skill description %d chars; index (after 'Available skills:') %d chars; lines %d" % (
            rc, len(desc), len(index), len(index.split("\n"))))
        open(os.path.join(HERE, "results", "row_e_skill_description.txt"), "w").write(desc)
    elif mode == "run":
        want = sys.argv[2:]
        for fam, model in FAMILIES:
            if want and fam not in want:
                continue
            session(fam, model)
        table()
    elif mode == "table":
        table()
