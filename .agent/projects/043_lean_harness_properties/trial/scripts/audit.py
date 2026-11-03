# PLAN-001 §7 / A1 item 4: the blinding audit of one arm session's transcript.
#   python3 -I audit.py <transcript.jsonl> <session dir>
# A tool call that names a denied location, or runs `git`, is a BREACH when its result was not a
# refusal, and a REFUSED ATTEMPT when the permission rules stopped it (it revealed nothing, and is
# listed). Other paths outside the session's own directories and the toolchains are notes. Tool
# results that show a denied location are notes too: they can mean a program read one at run time.
# Exit 1 on any breach.
import json, re, sys
path, sdir = sys.argv[1], sys.argv[2].rstrip("/")
own = (sdir + "/",)
denied = ("/workspaces", "/tmp/claude-1001", "/home/motoko/.claude", "/home/motoko/.codex",
          "/home/motoko/trial-043")
tools = ("/home/motoko/.elan/", "/home/motoko/.bun/", "/home/motoko/.local/bin/",
         "/home/motoko/.ailang/", "/home/motoko/go/", "/usr/", "/bin/", "/dev/", "/proc/", "/tmp/", "/etc/")
abs_path = re.compile(r"(?<![\w.~-])(/(?:workspaces|home|tmp)[\w./~+-]*)")
git_cmd = re.compile(r"(?:^|[;&|(`\s])git(?:\s|$)")
refusal = re.compile(r"denied|permission settings|Permission to use", re.I)

def strings(x):
    if isinstance(x, str): yield x
    elif isinstance(x, dict):
        for v in x.values(): yield from strings(v)
    elif isinstance(x, list):
        for v in x: yield from strings(v)

uses, results = [], {}
for line in open(path, encoding="utf-8"):
    try: rec = json.loads(line)
    except ValueError: continue
    content = (rec.get("message") or {}).get("content")
    if not isinstance(content, list): continue
    for b in content:
        if not isinstance(b, dict): continue
        if b.get("type") == "tool_use": uses.append(b)
        elif b.get("type") == "tool_result": results[b.get("tool_use_id")] = b

def classify(p):
    if p == sdir or p.startswith(own): return None
    if p.startswith(denied): return "denied"
    if p.startswith(tools): return None
    return "other"

breaches, refused, notes = [], [], []
for u in uses:
    name, inp = u.get("name"), u.get("input", {})
    hits = []
    if name == "Bash" and git_cmd.search(inp.get("command", "")): hits.append(("denied", "git command"))
    for p in abs_path.findall("\n".join(strings(inp))):
        c = classify(p)
        if c: hits.append((c, p))
    if not hits: continue
    r = results.get(u.get("id"), {})
    rtext = "\n".join(strings(r.get("content")))
    was_refused = bool(r.get("is_error")) and bool(refusal.search(rtext))
    for c, p in hits:
        tag = f"{name}: {p}"
        if c == "denied": (refused if was_refused else breaches).append(tag)
        else: notes.append(tag)
for r in results.values():
    for p in abs_path.findall("\n".join(strings(r.get("content")))):
        if classify(p) == "denied": notes.append(f"a result shows {p}")
print(f"audit: {len(uses)} tool calls; {len(breaches)} breach(es), {len(refused)} refused attempt(s), "
      f"{len(notes)} note(s)")
for b in dict.fromkeys(breaches): print("  BREACH", b)
for b in dict.fromkeys(refused): print("  refused", b)
for n in list(dict.fromkeys(notes))[:25]: print("  note", n)
sys.exit(1 if breaches else 0)
