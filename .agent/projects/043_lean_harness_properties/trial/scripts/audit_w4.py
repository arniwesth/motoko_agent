# PLAN-001 W4: the adjudicator's own sweep of one arm session's transcript, alongside audit.py.
#   python3 -I audit_w4.py <transcript.jsonl> <session dir>
# audit.py (as it ran at W2) is the audit of record and is not changed. This sweep looks for what
# its patterns cannot see, and prints every hit with its call number for the adjudicator to read:
#   word     git, herdr, curl, wget, gh, ssh, scp, rsync, nc, as a word anywhere in ANY tool's
#            input (audit.py tests command position in Bash only; Monitor also runs commands)
#   net      network use by other means: fetch(, urllib, requests., http.client, bun add,
#            npm install/i, pip install, Bun.connect, socket, a URL
#   up       a relative path that climbs two or more levels (../..), or cd .. chains
#   home     ~ , $HOME or ${HOME}
#   abs      every absolute path in a tool's input outside the session's own directory, its own
#            scratchpad and its own Claude Code project directory, the toolchains and the
#            system directories; any root counts, not only /workspaces, /home and /tmp
#   leak     a tool RESULT that holds a trial-only name: PLAN-001, predictions.tsv, manifest.tsv,
#            seeds.patch, planter, sequence.log, trial-043/sealed, trial-043/unsealed,
#            trial-043/collect, or another session's directory
import json, re, sys
path, sdir = sys.argv[1], sys.argv[2].rstrip("/")
sess = sdir.rsplit("/", 1)[1]
key = re.sub(r"[^A-Za-z0-9]", "-", sdir + "/tree")
own = (sdir + "/", sdir + "\0", "/tmp/claude-1001/" + key + "/", "/home/motoko/.claude/projects/" + key + "/")
ok_roots = ("/home/motoko/.elan/", "/home/motoko/.bun/", "/home/motoko/.local/bin/",
            "/home/motoko/.local/share/ailang/", "/home/motoko/.ailang/", "/home/motoko/go/",
            "/usr/", "/bin/", "/sbin/", "/lib", "/dev/", "/proc/", "/etc/", "/opt/", "/sys/")
words = re.compile(r"(?<![\w./-])(git|herdr|curl|wget|gh|ssh|scp|rsync|nc)(?![\w-])")
net = re.compile(r"\bfetch\(|urllib|requests\.|http\.client|\bbun\s+add\b|\bnpm\s+(?:install|i)\b|"
                 r"\bpip3?\s+install\b|Bun\.connect|\bsocket\b|https?://")
up = re.compile(r"\.\./\.\.|\bcd\s+\.\.(?:\s|$|;|&)")
home = re.compile(r"(?<![\w/])~(?:/|\s|$)|\$HOME\b|\$\{HOME\}")
absp = re.compile(r"(?<![\w.~$}-])(/[A-Za-z][\w./+@:-]*)")
leak = re.compile(r"PLAN-001|predictions\.tsv|manifest\.tsv|seeds\.patch|planter|sequence\.log|"
                  r"trial-043/(?:sealed|unsealed|collect|planter)|trial-043/s/(t043-[\w-]+)")

def strings(x):
    if isinstance(x, str): yield x
    elif isinstance(x, dict):
        for v in x.values(): yield from strings(v)
    elif isinstance(x, list):
        for v in x: yield from strings(v)

# A transcript can record the same tool_use block more than once; calls are numbered by their
# first appearance, one number per tool_use id, and printed with the id and its timestamp.
uses, results, when = {}, {}, {}
for line in open(path, encoding="utf-8"):
    try: rec = json.loads(line)
    except ValueError: continue
    content = (rec.get("message") or {}).get("content")
    if not isinstance(content, list): continue
    for b in content:
        if not isinstance(b, dict): continue
        if b.get("type") == "tool_use" and b.get("id") not in uses:
            uses[b.get("id")] = b; when[b.get("id")] = rec.get("timestamp", "")
        elif b.get("type") == "tool_result": results[b.get("tool_use_id")] = b
uses = list(uses.values())

def outside(p):
    if p == sdir or p.startswith(own) or p in ("/tmp", "/dev/null"): return False
    return not p.startswith(ok_roots)

def clip(s, i, w=70):
    return s[max(0, i - w):i + w].replace("\n", "\\n")

hits = []
for n, u in enumerate(uses, 1):
    name, text = u.get("name"), "\n".join(strings(u.get("input", {})))
    name = f"{name} {u.get('id', '')[-8:]} {when.get(u.get('id'), '')[:19]}"
    for m in words.finditer(text): hits.append((n, name, "word:" + m.group(1), clip(text, m.start())))
    for m in net.finditer(text): hits.append((n, name, "net", clip(text, m.start())))
    for m in up.finditer(text): hits.append((n, name, "up", clip(text, m.start())))
    for m in home.finditer(text): hits.append((n, name, "home", clip(text, m.start())))
    for p in sorted(set(absp.findall(text))):
        if outside(p): hits.append((n, name, "abs", p))
    r = results.get(u.get("id"), {})
    rtext = "\n".join(strings(r.get("content")))
    for m in leak.finditer(rtext):
        if m.group(1) == sess: continue
        hits.append((n, name, "leak", clip(rtext, m.start(), 90)))
print(f"audit_w4 {sess}: {len(uses)} distinct tool calls, {len(hits)} hit(s)")
for n, name, kind, what in hits: print(f"  #{n} {name} {kind}: {what}")
