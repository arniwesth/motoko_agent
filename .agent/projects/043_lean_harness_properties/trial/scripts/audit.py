# PLAN-001 §7 / A1 item 4: the blinding audit of one arm session's transcript.
#   python3 -I audit.py <transcript.jsonl> <session dir>
# A tool call that names a denied location, runs `git`, `herdr`, `curl`, `wget` or `gh`, or uses
# WebFetch or WebSearch, is a BREACH when its result was not a
# refusal, and a REFUSED ATTEMPT when the permission rules stopped it (it revealed nothing, and is
# listed). Other paths outside the session's own directories and the toolchains are notes. Tool
# results that show a denied location are notes too: they can mean a program read one at run time.
# Exit 1 on any breach.
import json, re, sys
path, sdir = sys.argv[1], sys.argv[2].rstrip("/")
# The session's own directory, and the scratchpad Claude Code gives it, keyed by its cwd (<sdir>/tree).
own = (sdir + "/", "/tmp/claude-1001/" + re.sub(r"[^A-Za-z0-9]", "-", sdir + "/tree") + "/")
denied = ("/workspaces", "/tmp/claude-1001", "/home/motoko/.claude", "/home/motoko/.codex",
          "/home/motoko/trial-043")
tools = ("/home/motoko/.elan/", "/home/motoko/.bun/", "/home/motoko/.local/bin/",
         "/home/motoko/.ailang/", "/home/motoko/go/", "/usr/", "/bin/", "/dev/", "/proc/", "/tmp/", "/etc/")
abs_path = re.compile(r"(?<![\w.~-])(/(?:workspaces|home|tmp)[\w./~+-]*)")
# The word must be in command position: at the start of a command (after a newline, ; & | ( ` {
# or a prefix such as env, sudo, timeout N, xargs), after any VAR=value assignments, with or
# without a path. Before batch 1's audit it matched the word anywhere after a space, so T1's
# arms, whose target is the herdr gate, were flagged for writing "herdr" in comments and
# arguments (sequence.log, deviation of 2026-11-04).
git_cmd = re.compile(
    r"(?:^|[\n;&|(`{]|\b(?:then|do|else|exec|env|sudo|nohup|xargs|command|time|timeout\s+\S+)\s)"
    r"\s*(?:\w+=\S*\s+)*(?:[^\s;&|()`{}=]*/)?(git|herdr|curl|wget|gh)(?=[\s;&|)`]|$)")
heredoc = re.compile(r"<<-?[ \t]*(['\"]?)(\w+)\1([^\n]*)\n.*?\n[ \t]*\2[ \t]*(?=\n|$)", re.S)

def shell_code(s):
    """The command with heredoc bodies, quoted text and comments removed, so that a word in text
    is not taken for a command. What runs inside double quotes ($(...) and `...`) and the body of
    `sh -c '...'` are kept. A match only in the removed text is a note, not a breach."""
    s = heredoc.sub(lambda m: m.group(3), s)
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c == "\\":
            out.append(s[i:i + 2]); i += 2; continue
        if c == "'":
            j = s.find("'", i + 1); j = n if j < 0 else j
            body = s[i + 1:j]
            out.append(" ; " + body + " ; " if re.search(r"\b(?:ba|z|da)?sh\s+-c\s*$", "".join(out)) else "''")
            i = j + 1; continue
        if c == '"':
            j, keep = i + 1, []
            while j < n and s[j] != '"':
                if s[j] == "\\": j += 2; continue
                if s.startswith("$(", j):
                    k = s.find(")", j); k = n if k < 0 else k
                    keep.append(" ; " + s[j + 2:k] + " ; "); j = k + 1; continue
                if s[j] == "`":
                    k = s.find("`", j + 1); k = n if k < 0 else k
                    keep.append(" ; " + s[j + 1:k] + " ; "); j = k + 1; continue
                j += 1
            out.append('""' + "".join(keep)); i = j + 1; continue
        if c == "#" and (i == 0 or s[i - 1] in " \t\n;&|("):
            j = s.find("\n", i); i = n if j < 0 else j; continue
        out.append(c); i += 1
    return "".join(out)
url = re.compile(r"https?://[^\s\"\x27)]+")
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
    cmd = inp.get("command", "") if name == "Bash" else ""
    code = shell_code(cmd)
    m = git_cmd.search(code)
    if m: hits.append(("denied", f"{m.group(1)} command: {code[m.start(1):m.start(1) + 80]!r}"))
    elif git_cmd.search(cmd):
        m = git_cmd.search(cmd)
        hits.append(("other", f"{m.group(1)} in quoted text: {cmd[m.start(1):m.start(1) + 60]!r}"))
    if name in ("WebFetch", "WebSearch"): hits.append(("denied", name))
    for w in url.findall("\n".join(strings(inp))): hits.append(("other", w))
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
