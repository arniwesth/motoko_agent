#!/usr/bin/env python3
"""Find record-literal sites of ScriptedTool, WorldState, ExecutionProgram and ToolFailed's
record in .ail files. Usage: litscan.py <root> <paths...>"""
import os, re, sys
root = sys.argv[1]
TYPES = {
 "ScriptedTool": {"tool_call_id","duration_ms","code","message","content","exit_code"},
 "WorldState": {"script","clock_ms","approvals","wakes","tools","env","files","log","gen"},
 "ExecutionProgram": {"schema_version","generator_id","generator_version","seed","initial_world","bounds","manifest","interactions"},
}
TF = {"tool_call_id","code","message"}
typeval = re.compile(r'^\s*(string|int|bool|float|[A-Z][\w.]*(\[.*\])?|\[.*\]|\(.*\))\s*$', re.S)

def blank(src):
    out = list(src); i = 0; n = len(src)
    while i < n:
        c = src[i]
        if c == '-' and src.startswith('--', i):
            j = src.find('\n', i); j = n if j < 0 else j
            for k in range(i, j): out[k] = ' '
            i = j; continue
        if c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == '\\' else 1
            for k in range(i + 1, min(j, n)):
                if out[k] != '\n': out[k] = ' '
            i = j + 1; continue
        i += 1
    return ''.join(out)

def split_top(s):
    parts, depth, cur = [], 0, []
    for ch in s:
        if ch in '([{': depth += 1
        elif ch in ')]}': depth -= 1
        if ch == ',' and depth == 0:
            parts.append(''.join(cur)); cur = []
        else: cur.append(ch)
    parts.append(''.join(cur)); return parts

def scan(path):
    src = open(path, encoding='utf-8', errors='replace').read()
    b = blank(src); stack = []; hits = []
    for i, ch in enumerate(b):
        if ch == '{': stack.append(i)
        elif ch == '}' and stack:
            o = stack.pop(); body = b[o+1:i]
            # top-level '|' means record update
            d = 0; upd = False
            for c2 in body:
                if c2 in '([{': d += 1
                elif c2 in ')]}': d -= 1
                elif c2 == '|' and d == 0: upd = True; break
            if upd: continue
            keys, vals = set(), []
            for p in split_top(body):
                m = re.match(r'\s*(\w+)\s*:(?!:)(.*)$', p, re.S)
                if not m: keys = None; break
                keys.add(m.group(1)); vals.append(m.group(2))
            if not keys: continue
            if all(typeval.match(v) for v in vals): continue   # a record TYPE
            line = src.count('\n', 0, o) + 1
            pre = b[max(0, o-40):o]
            for t, req in TYPES.items():
                if req <= keys and (t != "ScriptedTool" or keys == req or keys == req | {"applied"}):
                    hits.append((t, line))
            if keys == TF and re.search(r'ToolFailed\s*\(\s*$', pre):
                hits.append(("ToolFailed", line))
    return hits

for base in sys.argv[2:]:
    for dp, dn, fn in os.walk(os.path.join(root, base)):
        dn[:] = [d for d in dn if d not in ('node_modules', '.git')]
        for f in sorted(fn):
            if f.endswith('.ail'):
                p = os.path.join(dp, f)
                for t, l in scan(p):
                    print(f"{t}\t{os.path.relpath(p, root)}:{l}")
