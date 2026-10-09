#!/usr/bin/env python3
"""Over-approximate scan: local binders that share a name with an explicitly imported
lowercase name in the same .ail file. AILANG v0.52.0 made such a binder shadow the import;
before, the import won. Heuristic (regex), so every hit needs reading."""
import re, sys, pathlib

IMPORT_RE = re.compile(r'^\s*import\s+([A-Za-z0-9_./-]+)(?:\s+as\s+[A-Za-z0-9_]+)?\s*\(([^)]*)\)', re.M | re.S)
KEYWORDS = {"if", "then", "else", "match", "let", "letrec", "in", "func", "true", "false", "type",
            "import", "export", "module", "pure", "tests", "requires", "ensures", "with", "as", "_"}

def strip_comments(src: str) -> str:
    out = []
    for line in src.split("\n"):
        i = line.find("--")
        # keep it simple: a `--` inside a string literal is rare enough to tolerate here
        out.append(line if i < 0 else line[:i])
    return "\n".join(out)

def strip_strings(src: str) -> str:
    return re.sub(r'"(?:\\.|[^"\\\n])*"', '""', src)

def imported_names(src: str):
    names = {}
    for m in IMPORT_RE.finditer(src):
        mod = m.group(1)
        for item in m.group(2).split(","):
            item = item.strip()
            if not item:
                continue
            parts = re.split(r'\s+as\s+', item)
            bare = parts[-1].strip()
            if re.match(r'^[a-z_][A-Za-z0-9_]*$', bare) and bare not in KEYWORDS:
                names[bare] = mod
    return names

def balanced(src: str, start: int) -> int:
    """index just past the paren group opening at src[start] == '('"""
    depth = 0
    for i in range(start, len(src)):
        c = src[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i + 1
    return len(src)

def split_top(s: str):
    parts, depth, cur = [], 0, ""
    for c in s:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur); cur = ""
        else:
            cur += c
    parts.append(cur)
    return parts

def line_of(src: str, idx: int) -> int:
    return src.count("\n", 0, idx) + 1

def scan(path: pathlib.Path):
    raw = path.read_text(errors="replace")
    src = strip_strings(strip_comments(raw))
    names = imported_names(src)
    if not names:
        return []
    hits = []
    # 1. let / letrec binders (single name)
    for m in re.finditer(r'\b(let|letrec)\s+([a-z_][A-Za-z0-9_]*)\b', src):
        n = m.group(2)
        if n in names:
            hits.append((line_of(src, m.start()), n, m.group(1)))
    # 1b. tuple lets: let (a, b) = ...
    for m in re.finditer(r'\blet\s*\(([^)=]*)\)\s*=', src):
        for n in re.findall(r'[a-z_][A-Za-z0-9_]*', m.group(1)):
            if n in names:
                hits.append((line_of(src, m.start()), n, "let-tuple"))
    # 2. func parameters (named funcs and anonymous func(...))
    for m in re.finditer(r'\bfunc\b\s*[A-Za-z0-9_]*\s*(?:\[[^\]]*\])?\s*\(', src):
        op = m.end() - 1
        end = balanced(src, op)
        for p in split_top(src[op + 1:end - 1]):
            pm = re.match(r'\s*([a-z_][A-Za-z0-9_]*)\s*(?::|$)', p)
            if pm and pm.group(1) in names:
                hits.append((line_of(src, op), pm.group(1), "param"))
    # 3. backslash lambdas: \x y. body
    for m in re.finditer(r'\\\s*((?:[a-z_][A-Za-z0-9_]*\s*)+)\.', src):
        for n in m.group(1).split():
            if n in names:
                hits.append((line_of(src, m.start()), n, "lambda"))
    # 4. match-arm binders: identifiers left of `=>` on the arm's line(s), not applied, not a field label
    for m in re.finditer(r'=>', src):
        ls = src.rfind("\n", 0, m.start()) + 1
        seg = src[ls:m.start()]
        # an arm guard (`if cond`) is an expression, not a pattern
        seg = re.split(r'\bif\b', seg)[0]
        # keep only the pattern after the last `{` or `|` that opens the arm on this line
        for sep in ("{", "|"):
            if sep in seg:
                seg = seg[seg.rfind(sep) + 1:]
        for im in re.finditer(r'(?<![A-Za-z0-9_.])([a-z_][A-Za-z0-9_]*)\b(?!\s*[:(.])', seg):
            n = im.group(1)
            if n in names and n not in KEYWORDS:
                hits.append((line_of(src, ls), n, "match-binder?"))
    return [(path, ln, n, kind, names[n]) for ln, n, kind in sorted(set(hits))]

def main():
    roots = [pathlib.Path(p) for p in sys.argv[1:]]
    total_files = 0
    all_hits = []
    for root in roots:
        for path in sorted(root.rglob("*.ail")):
            sp = str(path)
            if "/.ailang/" in sp or "/node_modules/" in sp or "/.packages/" in sp:
                continue
            total_files += 1
            all_hits.extend(scan(path))
    for path, ln, n, kind, mod in all_hits:
        print(f"{path}:{ln}\t{kind}\t{n}\t(import {mod})")
    print(f"# {total_files} files scanned, {len(all_hits)} candidate hits in {len({h[0] for h in all_hits})} files", file=sys.stderr)

if __name__ == "__main__":
    main()
