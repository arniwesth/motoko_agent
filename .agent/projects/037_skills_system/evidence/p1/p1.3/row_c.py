#!/usr/bin/env python3
"""037 P1.3c: a long run driven past the compaction threshold, once under the
structural compactor (70%) and once under compaction_ai (75%), per model.

  row_c.py build                     the two fixture templates (profile copies + workload)
  row_c.py dry <structural|ai>       one free session against the local recorder
  row_c.py run <structural|ai> <model-short> [...]   live, one at a time
  row_c.py table                     results/row_c.tsv and row_c_<run>.txt

THE DECLARED LIMIT IS 131,472, NOT 64,000. The compactors do not see
agent.context_limit: they see it less the 65,536-token output allowance and less
the system prefix (src/core/context_limit.ail `working_budget_for_ext`,
src/core/session.ail:3770). A declared 64,000 gives them 0, and nothing is ever
compacted (dry/limit-64000). 131,472 - 65,536 - 1,936 = 64,000, which is the
working limit the approval priced.

Each compactor has its own copy of the profile:
  structural  extensions.order = empty_stop_guard, progress_contract_guard, compaction_structural, skills
  ai          extensions.order = empty_stop_guard, progress_contract_guard, compaction_ai, skills
              (compaction_ai.json as skills_proto has it: deepseek-v4-flash, 75%, keep_recent 10)
agent.max_steps is 60 in both.

What a request carried is RECONSTRUCTED from the event stream (the provider is
real, so there is no request capture): the history from history_seeded and
history_appended, and the compaction applied to each request from that step's
compaction_extension note. The reconstruction is checked against each
provider_call_prepared's msg_count and estimated_input_tokens.
"""
import json, os, re, shutil, subprocess, sys
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import events

WORKTREE = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
WORK = "/tmp/motoko-037-p1.3/work/fixture"
DECLARED = 131472
WORKING = 64000
SKILL = "dagr-producer"
BASE = "empty_stop_guard,progress_contract_guard"
TPL = {"structural": "/tmp/motoko-037-p1.3/tpl-c-structural", "ai": "/tmp/motoko-037-p1.3/tpl-c-ai"}
ORDER = {"structural": BASE + ",compaction_structural,skills", "ai": BASE + ",compaction_ai,skills"}
MODELS = {"deepseek-v4-pro": "openrouter/deepseek/deepseek-v4-pro",
          "deepseek-v4-flash": "openrouter/deepseek/deepseek-v4-flash",
          "muse-spark-1.3-contributor": "openrouter/meta/muse-spark-1.3-contributor"}
SESSION_CAP = {"deepseek-v4-pro": 0.80, "deepseek-v4-flash": 0.45, "muse-spark-1.3-contributor": 0.45}
TASK = ("You are the record keeper for the atlas-release project. Use the dagr-producer skill and follow it exactly. "
        "PROJECT.md describes the project and its tasks. The delegates' reports are in reports/, R01.md to R14.md, in the "
        "order they arrived. Maintain the dagr run file .dagr/run-atlas.json so that it records what the reports say. "
        "Work through the reports strictly one at a time, in order: read the whole report (each is under 100 lines), "
        "update the run file to record what that report says, and validate the file the way the skill requires before "
        "you move on to the next report. Do not read ahead and do not batch reports. When all 14 reports are recorded, "
        "give a one-paragraph summary of the final state of the run.")


def build():
    for comp in ("structural", "ai"):
        subprocess.run([os.path.join(HERE, "build_fixture.sh"), TPL[comp], "context_limit=%d" % DECLARED,
                        "max_steps=60", "order=" + ORDER[comp]], cwd=WORKTREE, check=True)
        subprocess.run([sys.executable, os.path.join(HERE, "row_c_fixture.py"), TPL[comp]], check=True)


def session(comp, short, recorder=None):
    label = "%s.%s" % (comp, short)
    out = os.path.join(HERE, "dry" if recorder else "capture", "c" if not recorder else "", label).replace("//", "/")
    cap = SESSION_CAP.get(short, 0.3)
    cmd = [sys.executable, os.path.join(HERE, "live_session.py"), "--row", "c", "--label", label, "--out", out,
           "--template", TPL[comp], "--workdir", WORK, "--model", MODELS.get(short, "x"), "--task", TASK,
           "--timeout", "5400", "--reserve", "%.2f" % cap, "--session-cap", "%.2f" % cap]
    if recorder:
        cmd += ["--recorder", recorder]
    r = subprocess.run(cmd, cwd=WORKTREE)
    # keep what the run wrote, before the next session resets the workdir
    keep = os.path.join(out, "workdir_dagr")
    shutil.rmtree(keep, ignore_errors=True)
    if os.path.isdir(os.path.join(WORK, ".dagr")):
        shutil.copytree(os.path.join(WORK, ".dagr"), keep)
        for f in sorted(os.listdir(keep)):
            if f.endswith(".json"):
                c = subprocess.run(["dagr", "check", os.path.join(keep, f), "--strict", "--json"], capture_output=True, text=True)
                open(os.path.join(out, "dagr_check_%s.txt" % f), "w").write("exit=%d\n%s%s" % (c.returncode, c.stdout, c.stderr))
    return r.returncode


def tok(s):
    return (len(s) + 3) // 4


def analyse(out):
    ev = events.load(out)
    hist = []          # every message appended, in order
    snaps = []         # one per provider request
    note = {}
    diags = []
    summaries = {}     # step -> summary text when compaction_ai refreshed its artifact
    for e in ev:
        t = e.get("type")
        if t == "history_seeded":
            hist = [dict(m) for m in e.get("messages", [])]
        elif t == "history_appended":
            m = dict(e.get("message", {}))
            m["_step"] = e.get("step")
            if e.get("replaces_previous") and hist:
                hist[-1] = m
            else:
                hist.append(m)
        elif t == "compaction_extension":
            note[e.get("step")] = e.get("note", "")
        elif t == "extension_diagnostic":
            diags.append((e.get("step"), e.get("extension"), e.get("code"), {f["key"]: f["value"] for f in e.get("fields", [])}))
        elif t == "state_delta":
            art = (e.get("ext_artifacts") or {}).get("compaction_ai") if isinstance(e.get("ext_artifacts"), dict) else None
            if art and "summary" in art:
                summaries[e.get("step")] = art
        elif t == "provider_call_prepared":
            snaps.append({"step": e.get("step"), "hist_len": len(hist), "msg_count": e.get("msg_count"),
                          "est": e.get("estimated_input_tokens")})
    st = {s["step"]: s for s in events.steps(ev)}
    n_sys = 0
    for m in hist:
        if m.get("role") == "system":
            n_sys += 1
        else:
            break
    handled = {e.get("id"): e.get("exit_code") for e in events.of_type(ev, "ext_tool_handled")}
    skill_calls = []   # (step, name, exit, call id)
    for e in events.of_type(ev, "native_tool_calls"):
        for c in e.get("tool_calls", []):
            if c.get("tool") == "Skill":
                skill_calls.append((e.get("step"), (c.get("arguments") or {}).get("name"), handled.get(c.get("id")), c.get("id")))
    # indices in hist of whole deliveries of the skill under test
    copies = [i for i, m in enumerate(hist) if m.get("role") == "tool" and (m.get("content") or "").find('"tool":"Skill"') in range(0, 120)
              and ('"stdout":".motoko/skills/%s' % SKILL) in (m.get("content") or "")[:200]]
    rows = []
    mismatch = 0
    for s in snaps:
        h = hist[:s["hist_len"]]
        body = h[n_sys:]
        n = note.get(s["step"], "")
        whole = []
        if n.startswith("structural"):
            keep = int(re.search(r"keep_last=(\d+)", n).group(1))
            tool_idx = [i for i, m in enumerate(h) if m.get("role") == "tool"]
            kept = set(tool_idx[-keep:]) if keep > 0 else set()
            est = 0
            for i, m in enumerate(h):
                c = m.get("content") or ""
                if m.get("role") == "tool" and i not in kept and len(c) > 80:
                    c2 = c[:80] + "...[elided %d chars]" % (len(c) - 80)
                    c = c2 if len(c2) < len(c) else c
                est += len(c)
            est = (est + 3) // 4
            whole = [i for i in copies if i < len(h) and i in kept]
            count = len(h)
            mode = "structural"
        elif n.startswith("AI-"):
            k = int(re.search(r"(\d+) turns", n).group(1))
            whole = [i for i in copies if i < len(h) and (i - n_sys) >= k]
            count = n_sys + 1 + (len(body) - k)
            est = None
            mode = "ai-folded" if n.startswith("AI-folded") else "ai-cache"
        else:
            whole = [i for i in copies if i < len(h)]
            count = len(h)
            est = (sum(len(m.get("content") or "") for m in h) + 3) // 4
            mode = ""
        ok = (count == s["msg_count"]) and (est is None or est == s["est"])
        mismatch += 0 if ok else 1
        rows.append({"step": s["step"], "mode": mode, "note": n, "msgs": s["msg_count"], "est": s["est"],
                     "in": st.get(s["step"], {}).get("input_tokens", 0), "out": st.get(s["step"], {}).get("output_tokens", 0),
                     "whole_copies": whole, "copies_in_history": len([i for i in copies if i < len(h)]), "recon_ok": ok})
    return {"ev": ev, "hist": hist, "rows": rows, "skill_calls": skill_calls, "copies": copies, "diags": diags,
            "summaries": summaries, "mismatch": mismatch, "n_sys": n_sys}


def describe(out, label):
    a = analyse(out)
    ev, rows, hist = a["ev"], a["rows"], a["hist"]
    s = events.summary(ev) or {}
    tx = events.session_txt(out)
    lines = []
    loads = [(stp, ex) for stp, name, ex, _ in a["skill_calls"] if name == SKILL]
    ok_loads = [stp for stp, ex in loads if ex == 0]
    first_load = ok_loads[0] if ok_loads else None
    reloads = ok_loads[1:]
    compacted = [r for r in rows if r["mode"]]
    first_comp = compacted[0]["step"] if compacted else None
    copy_tokens = [tok(hist[i].get("content") or "") for i in a["copies"]]
    # requests after the first load that carried no whole copy of the skill
    after = [r for r in rows if first_load is not None and r["step"] > first_load]
    without = [r["step"] for r in after if not r["whole_copies"]]
    # loss episodes: maximal runs of consecutive requests without a whole copy
    episodes = []
    for r in after:
        if not r["whole_copies"]:
            if episodes and episodes[-1][1] == r["step"] - 1:
                episodes[-1][1] = r["step"]
            else:
                episodes.append([r["step"], r["step"]])
    ep_txt = []
    answered = 0
    for a0, a1 in episodes:
        nxt = [x for x in reloads if a0 <= x <= a1 + 1]
        if nxt:
            answered += 1
            ep_txt.append("%d-%d reloaded at step %d (after %d requests without it)" % (a0, a1, nxt[0], nxt[0] - a0 + 1))
        else:
            ep_txt.append("%d-%d never reloaded (%d requests without it)" % (a0, a1, a1 - a0 + 1))
    # tokens: each reload's result, and the input tokens spent carrying reloaded copies
    first_copy = a["copies"][0] if a["copies"] else None
    carry_reload = sum(tok(hist[i].get("content") or "") for r in rows for i in r["whole_copies"] if i != first_copy)
    carry_first = sum(tok(hist[i].get("content") or "") for r in rows for i in r["whole_copies"] if i == first_copy)
    tin = int(tx.get("input_tokens") or 0)
    tout = int(tx.get("output_tokens") or 0)
    folds = [r for r in rows if r["mode"] == "ai-folded"]
    reports_read = sorted(set(re.findall(r"reports/(R\d\d)\.md", json.dumps([c for e in events.of_type(ev, "native_tool_calls") for c in e.get("tool_calls", [])]))))
    checks = {}
    for f in sorted(os.listdir(out)):
        if f.startswith("dagr_check_"):
            checks[f[len("dagr_check_"):-4]] = open(os.path.join(out, f)).read().split("\n")[0]
    other_skill = [(stp, name, ex) for stp, name, ex, _ in a["skill_calls"] if name != SKILL]
    # the skill's text or bundled files fetched by a tool other than Skill (ReadFile,
    # or BashExec with cat/sed/grep): the directory line makes that possible
    side = []
    results = {}
    for e in events.of_type(ev, "history_appended"):
        m = e.get("message", {})
        if m.get("role") == "tool":
            results.setdefault(e.get("step"), []).append(len(m.get("content") or ""))
    for e in events.of_type(ev, "native_tool_calls"):
        for c in e.get("tool_calls", []):
            blob = json.dumps(c.get("arguments") or {})
            if c.get("tool") != "Skill" and (".motoko/skills/%s" % SKILL) in blob:
                what = "SKILL.md" if "SKILL.md" in blob else ("examples" if "examples" in blob else "dir")
                side.append((e.get("step"), c.get("tool"), what))
    side_after = [x for x in side if first_comp is not None and x[0] >= first_comp]
    res = {
        "run": label, "model": tx.get("model", ""), "requests": len(rows), "finish": s.get("finish_reason") or tx.get("finish_reason"),
        "killed": tx.get("killed", ""), "input_tokens": tin, "output_tokens": tout, "list_cost_usd": tx.get("list_cost_usd", ""),
        "first_compacted_request": first_comp, "compacted_requests": len(compacted),
        "skill_first_load_step": first_load, "skill_reload_steps": reloads, "reloads": len(reloads),
        "failed_skill_calls": [(stp, ex) for stp, ex in loads if ex != 0],
        "skill_result_tokens": copy_tokens[0] if copy_tokens else 0,
        "requests_without_whole_skill": len(without), "loss_episodes": len(episodes), "episodes_answered_by_reload": answered,
        "reload_result_tokens_total": sum(copy_tokens[1:]), "input_tokens_carrying_reloaded_copies": carry_reload,
        "input_tokens_carrying_first_copy": carry_first,
        "reload_share_of_input_pct": round(100.0 * carry_reload / tin, 1) if tin else 0,
        "ai_folds": len(folds), "reports_read": len(reports_read), "last_report_read": reports_read[-1] if reports_read else "",
        "dagr_check": checks, "other_skill_calls": other_skill, "reconstruction_mismatches": a["mismatch"],
        "skill_file_reads_by_other_tools": side,
        "skill_md_reads_after_first_compaction": [x for x in side_after if x[2] == "SKILL.md"],
        "example_reads_after_first_compaction": [x for x in side_after if x[2] == "examples"],
    }
    lines.append("run %s  model %s" % (label, res["model"]))
    for k in ("requests", "finish", "killed", "input_tokens", "output_tokens", "list_cost_usd", "first_compacted_request",
              "compacted_requests", "skill_first_load_step", "skill_reload_steps", "failed_skill_calls", "skill_result_tokens",
              "requests_without_whole_skill", "loss_episodes", "episodes_answered_by_reload", "reload_result_tokens_total",
              "input_tokens_carrying_reloaded_copies", "input_tokens_carrying_first_copy", "reload_share_of_input_pct",
              "ai_folds", "reports_read", "last_report_read", "dagr_check", "other_skill_calls", "reconstruction_mismatches",
              "skill_file_reads_by_other_tools", "skill_md_reads_after_first_compaction", "example_reads_after_first_compaction"):
        lines.append("  %-40s %s" % (k, res[k]))
    lines.append("  loss episodes: " + ("; ".join(ep_txt) or "none"))
    lines.append("  diagnostics: " + json.dumps(a["diags"])[:1500])
    for stp, art in sorted(a["summaries"].items()):
        txt = art.get("summary", "")
        lines.append("  compaction_ai summary refreshed at step %s: %d chars, boundary %s; mentions the skill: %s; mentions 'Skill': %s" % (
            stp, len(txt), art.get("boundary_marker"), SKILL in txt, "Skill" in txt))
    lines.append("  step  mode        msgs  est_tok  in_tok  out_tok  whole_copies/in_history  note")
    calls = events.calls_by_step(ev)
    for r in rows:
        cs = ", ".join("%s%s" % (t, "(" + str(a2.get("name") or a2.get("path") or (a2.get("cmd") or "")[:38]) + ")") for t, a2 in calls.get(r["step"], []))
        lines.append("  %4s  %-10s %5s  %7s %7s %7s   %d/%d%s  %s  -> %s" % (
            r["step"], r["mode"], r["msgs"], r["est"], r["in"], r["out"], len(r["whole_copies"]), r["copies_in_history"],
            "" if r["recon_ok"] else " !recon", r["note"], cs[:150]))
    return res, "\n".join(lines)


def table():
    cols = ["run", "model", "requests", "finish", "input_tokens", "output_tokens", "list_cost_usd", "first_compacted_request",
            "compacted_requests", "skill_first_load_step", "reloads", "skill_reload_steps", "skill_result_tokens",
            "requests_without_whole_skill", "loss_episodes", "episodes_answered_by_reload", "reload_result_tokens_total",
            "input_tokens_carrying_reloaded_copies", "reload_share_of_input_pct", "ai_folds", "reports_read",
            "last_report_read", "dagr_check", "reconstruction_mismatches", "skill_md_reads_after_first_compaction",
            "example_reads_after_first_compaction"]
    out = ["\t".join(cols)]
    base = os.path.join(HERE, "capture", "c")
    for comp in ("structural", "ai"):
        for short in MODELS:
            d = os.path.join(base, "%s.%s" % (comp, short))
            if not os.path.isdir(d):
                continue
            res, txt = describe(d, "%s.%s" % (comp, short))
            open(os.path.join(HERE, "results", "row_c_%s.%s.txt" % (comp, short)), "w").write(txt + "\n")
            out.append("\t".join(str(res[c]) for c in cols))
    open(os.path.join(HERE, "results", "row_c.tsv"), "w").write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "build":
        build()
    elif mode == "dry":
        comp = sys.argv[2]
        script = os.path.join(HERE, "dry_script_c.json")
        steps = [{"tool": ["Skill", {"name": SKILL}]}, {"tool": ["ReadFile", {"path": "PROJECT.md"}]}]
        for i in range(1, 15):
            steps.append({"tool": ["ReadFile", {"path": "reports/R%02d.md" % i}]})
            if i == 9:
                steps.append({"tool": ["Skill", {"name": SKILL}]})
        steps.append({"text": "Dry run complete."})
        json.dump(steps, open(script, "w"))
        session(comp, "dry", recorder=script)
        res, txt = describe(os.path.join(HERE, "dry", "%s.dry" % comp), "%s.dry" % comp)
        print(txt)
    elif mode == "run":
        comp = sys.argv[2]
        for short in sys.argv[3:]:
            rc = session(comp, short)
            if rc == 3:
                break
        table()
    elif mode == "table":
        table()
