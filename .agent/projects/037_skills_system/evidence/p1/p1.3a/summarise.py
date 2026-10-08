#!/usr/bin/env python3
"""037 P1.3a: read one capture directory and print what the session did.

  summarise.py <capture-dir>

Reads req-NN.json (the request bodies the recorder saved) and session.stdout.jsonl
(the runtime's event stream). Writes skill_description.txt beside them.
"""
import glob, hashlib, json, os, sys

out = sys.argv[1]
reqs = sorted(glob.glob(os.path.join(out, "req-*.json")))
print("requests recorded:", len(reqs))

events = []
p = os.path.join(out, "session.stdout.jsonl")
if os.path.exists(p):
    for line in open(p, encoding="utf-8", errors="replace"):
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except ValueError:
                pass

for e in events:
    if e.get("type") == "session_start" and "config_profile" in e:
        print("session_start: config_profile=%r config_dir=%r loaded_extensions=%r" % (
            e.get("config_profile"), e.get("config_dir"), e.get("loaded_extensions")))
    if e.get("type") in ("warning", "error", "fatal"):
        print("EVENT %s: %s" % (e["type"], json.dumps(e, ensure_ascii=False)[:600]))

if reqs:
    b = json.load(open(reqs[0]))["body"]
    tools = b.get("tools", [])
    print("request 1 tools:", [t["function"]["name"] for t in tools])
    sk = [t for t in tools if t["function"]["name"] == "Skill"]
    print("Skill schemas in request 1:", len(sk))
    if sk:
        d = sk[0]["function"]["description"]
        open(os.path.join(out, "skill_description.txt"), "w", encoding="utf-8").write(d)
        print("Skill description: %d chars, sha256 %s" % (len(d), hashlib.sha256(d.encode()).hexdigest()))
        print("Skill parameters:", json.dumps(sk[0]["function"]["parameters"]))
    sysmsg = [m for m in b.get("messages", []) if m.get("role") == "system"]
    print("request 1 system messages: %d, chars %s" % (
        len(sysmsg), [len(m.get("content") or "") for m in sysmsg]))

for e in events:
    t = e.get("type")
    if t == "native_tool_calls":
        for c in e.get("tool_calls", []):
            print("step %s CALL %s %s" % (e.get("step"), c.get("tool"), json.dumps(c.get("arguments"))))
    elif t == "ext_tool_handled":
        print("step %s ext_tool_handled tool=%s exit_code=%s" % (e.get("step"), e.get("tool"), e.get("exit_code")))
    elif t == "history_appended" and e.get("message", {}).get("role") == "tool":
        c = e["message"].get("content") or ""
        print("step %s TOOL MESSAGE (%d chars): %s" % (e.get("step"), len(c), c[:700]))
    elif t == "run_summary":
        print("run_summary: finish_reason=%r steps_executed=%r" % (e.get("finish_reason"), e.get("steps_executed")))
