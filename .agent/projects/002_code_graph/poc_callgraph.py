#!/usr/bin/env python3
"""PoC: internal-function call graph for AILANG via raw-source parsing.

No compilation / no hydration. Sees internal functions (which `ailang iface`
hides). Heuristic but resolves calls against locally-defined + imported names.
"""
import re, sys, json
from pathlib import Path

DECL_RE = re.compile(r'^(?:export\s+)?(?:pure\s+)?func\s+([A-Za-z_]\w*)')
TOPLEVEL_RE = re.compile(r'^(?:export\s+)?(?:pure\s+)?(?:func|type)\b|^module\b|^import\b')
CALL_RE = re.compile(r'(?<![.\w])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*\(')
KEYWORDS = {'if','then','else','let','match','func','type','module','import',
            'requires','ensures','in','case','of','true','false','and','or','not'}

def strip_noise(s: str) -> str:
    s = re.sub(r'--[^\n]*', '', s)          # line comments
    s = re.sub(r'"(?:\\.|[^"\\])*"', '""', s)  # string literals (drop interpolation too, PoC)
    return s

def module_name(text: str, path: Path) -> str:
    m = re.search(r'^module\s+(\S+)', text, re.M)
    return m.group(1) if m else str(path)

def parse_imports(text: str):
    """name(possibly aliased) -> target module slug, for resolving calls."""
    imp = {}
    for line in text.splitlines():
        m = re.match(r'^import\s+(\S+)(?:\s+as\s+(\w+))?\s*(?:\(([^)]*)\))?', line)
        if not m: continue
        mod, alias, syms = m.group(1), m.group(2), m.group(3)
        if syms:
            for s in (x.strip() for x in syms.split(',')):
                if not s: continue
                key = f'{alias}.{s}' if alias else s
                imp[key] = mod
                if alias: imp[s] = mod  # also allow bare (PoC tolerance)
    return imp

def func_spans(lines):
    """Yield (name, start_idx, end_idx) per top-level func, segmented by next top-level decl."""
    starts = [(i, DECL_RE.match(l)) for i, l in enumerate(lines)]
    decls = [i for i, l in enumerate(lines) if TOPLEVEL_RE.match(l)]
    for i, m in starts:
        if not m: continue
        nxt = next((d for d in decls if d > i), len(lines))
        yield m.group(1), i, nxt

def extract(path: Path):
    text = path.read_text()
    mod = module_name(text, path)
    imports = parse_imports(text)
    lines = text.splitlines()
    local = {name for name, _, _ in func_spans(lines)}
    out = []  # (from_slug, to_slug, kind)
    for name, s, e in func_spans(lines):
        body = strip_noise('\n'.join(lines[s:e]))
        called = {c for c in CALL_RE.findall(body)}
        from_slug = f'{mod}.{name}'
        for c in called:
            if c in KEYWORDS or c == name: continue
            if c in local:
                out.append((from_slug, f'{mod}.{c}', 'local'))
            elif c in imports:
                out.append((from_slug, f'{imports[c]}.{c.split(".")[-1]}', 'import'))
            # else: builtin/ctor/higher-order param -> dropped
    return mod, local, out

if __name__ == '__main__':
    files = [Path(p) for p in sys.argv[1:]]
    all_edges = []
    for f in files:
        mod, local, edges = extract(f)
        print(f'\n=== {mod}  ({len(local)} funcs, {len(edges)} resolved call-edges) ===')
        for frm, to, kind in sorted(edges):
            print(f'  {frm.split("/")[-1]:42} -> {to.split("/")[-1]:30} [{kind}]')
        all_edges += edges
    print(f'\nTOTAL resolved edges: {len(all_edges)}')
