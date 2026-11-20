#!/usr/bin/env python3
"""Text-level reading of AILANG source for the 039 random-mutant pilot.

Nothing here knows about tests, gates or coverage. It reads the source as text:

  tokens(src)        code tokens, with every comment and string literal kept as ONE token of
                     kind 'comment' or 'string', so that no operator ever looks inside either.
  functions(src)     the top-level functions: name, header span, body span, parameters.
  calls_in(...)      the identifiers a body names that are functions of the four files.

A string literal is skipped whole, `${...}` interpolations included: the brief says to skip
string literals mechanically, and an interpolation is part of the literal's text.
"""
import re

TWO = ("==", "!=", "<=", ">=", "->", "=>", "&&", "||", "++", "::")
ONE = set("()[]{},;:.=<>+-*/%|\\!@?&^~")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
NUM = re.compile(r"[0-9]+(\.[0-9]+)?")


class Tok:
    __slots__ = ("kind", "text", "start", "end", "line")

    def __init__(self, kind, text, start, end, line):
        self.kind, self.text, self.start, self.end, self.line = kind, text, start, end, line

    def __repr__(self):
        return f"Tok({self.kind},{self.text!r},L{self.line})"


def _string_end(src, i):
    """`src[i]` is the opening quote. Return the index just past the closing quote."""
    assert src[i] == '"'
    i += 1
    n = len(src)
    while i < n:
        c = src[i]
        if c == "\\":
            i += 2
            continue
        if c == '"':
            return i + 1
        if c == "$" and i + 1 < n and src[i + 1] == "{":
            # An interpolation: code up to the matching brace, which may hold strings.
            i += 2
            depth = 1
            while i < n and depth:
                d = src[i]
                if d == '"':
                    i = _string_end(src, i)
                    continue
                if d == "{":
                    depth += 1
                elif d == "}":
                    depth -= 1
                i += 1
            continue
        i += 1
    raise ValueError("unterminated string literal")


def tokens(src):
    out = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if src.startswith("--", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(Tok("comment", src[i:j], i, j, line))
            i = j
            continue
        if c == '"':
            j = _string_end(src, i)
            out.append(Tok("string", src[i:j], i, j, line))
            line += src.count("\n", i, j)
            i = j
            continue
        m = IDENT.match(src, i)
        if m:
            out.append(Tok("ident", m.group(0), i, m.end(), line))
            i = m.end()
            continue
        m = NUM.match(src, i)
        if m:
            out.append(Tok("num", m.group(0), i, m.end(), line))
            i = m.end()
            continue
        two = src[i:i + 2]
        if two in TWO:
            out.append(Tok("op", two, i, i + 2, line))
            i += 2
            continue
        if c in ONE:
            out.append(Tok("op", c, i, i + 1, line))
            i += 1
            continue
        raise ValueError(f"unexpected character {c!r} at line {line}")
    return out


OPEN = {"(": ")", "[": "]", "{": "}"}
CLOSE = {")", "]", "}"}


def match_close(ct, k):
    """`ct[k]` is an opening bracket in a comment-free token list. Return the index of its match."""
    depth = 0
    for j in range(k, len(ct)):
        t = ct[j]
        if t.kind == "op" and t.text in OPEN:
            depth += 1
        elif t.kind == "op" and t.text in CLOSE:
            depth -= 1
            if depth == 0:
                return j
    raise ValueError(f"unbalanced bracket from line {ct[k].line}")


DECL_START = re.compile(r"^(export\s+)?(pure\s+)?(func|type|import|module)\b", re.M)


class Func:
    def __init__(self, **kw):
        self.__dict__.update(kw)

    def __repr__(self):
        return f"Func({self.name}, L{self.line}-{self.end_line})"


def functions(src, path=""):
    """Top-level functions. The body is the last depth-0 `{...}` group before the next
    top-level declaration, so a signature's effect row, contract block, record return type and
    `tests [...]` are all outside it."""
    starts = [m.start() for m in DECL_START.finditer(src)]
    starts.append(len(src))
    toks = tokens(src)
    out = []
    for a, b in zip(starts, starts[1:]):
        head = src[a:src.find("\n", a) if src.find("\n", a) >= 0 else len(src)]
        m = re.match(r"(export\s+)?(pure\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", head)
        if not m:
            # a func header may span lines only after `(`; the name is on the first line
            continue
        name = m.group(3)
        ct = [t for t in toks if a <= t.start < b and t.kind != "comment"]
        # parameters: the first `(` after the name
        k0 = next(i for i, t in enumerate(ct) if t.kind == "op" and t.text == "(")
        k1 = match_close(ct, k0)
        params = []
        depth, cur = 0, []
        for t in ct[k0 + 1:k1]:
            if t.kind == "op" and t.text in OPEN:
                depth += 1
            elif t.kind == "op" and t.text in CLOSE:
                depth -= 1
            if depth == 0 and t.kind == "op" and t.text == ",":
                params.append(cur)
                cur = []
            else:
                cur.append(t)
        if cur:
            params.append(cur)
        plist = []
        for p in params:
            if len(p) >= 3 and p[0].kind == "ident" and p[1].text == ":":
                ptype = src[p[2].start:p[-1].end]
                plist.append((p[0].text, " ".join(ptype.split())))
        # body: the last depth-0 `{` group in the span
        body_open = None
        depth = 0
        k = k1 + 1
        while k < len(ct):
            t = ct[k]
            if t.kind == "op" and t.text in OPEN:
                if depth == 0 and t.text == "{":
                    body_open = k
                close = match_close(ct, k)
                k = close + 1
                continue
            k += 1
        if body_open is None:
            continue
        body_close = match_close(ct, body_open)
        out.append(Func(
            name=name, path=path, start=a, line=src.count("\n", 0, a) + 1,
            pure=bool(m.group(2)), export=bool(m.group(1)), params=plist,
            sig=" ".join(src[a:ct[body_open].start].split()),
            body_start=ct[body_open].start, body_end=ct[body_close].end,
            end_line=src.count("\n", 0, ct[body_close].end) + 1,
        ))
    return out


def body_tokens(src, f, toks=None):
    toks = toks if toks is not None else tokens(src)
    return [t for t in toks if f.body_start <= t.start < f.body_end]


def calls_in(src, f, names, toks=None):
    """Names in `names` that the body applies (`name(`) or passes as a value (`(name,` `,name)`
    and the like), never after a `.`: comments and strings are excluded by construction."""
    bt = [t for t in body_tokens(src, f, toks) if t.kind != "comment"]
    seen = []
    for i, t in enumerate(bt):
        if t.kind != "ident" or t.text not in names or t.text in seen:
            continue
        prev = bt[i - 1].text if i else ""
        nxt = bt[i + 1].text if i + 1 < len(bt) else ""
        if prev == ".":
            continue
        if nxt == "(" or (prev in ("(", ",") and nxt in (",", ")")):
            seen.append(t.text)
    return seen


def imports(src):
    """`import src/core/<mod> (a, b, ...)` -> {mod: [names]}, over the whole file."""
    out = {}
    for m in re.finditer(r"^import\s+src/core/([A-Za-z_]+)\s*\(([^)]*)\)", src, re.M):
        names = [n.strip().split(" as ")[0] for n in re.sub(r"--[^\n]*", "", m.group(2)).split(",")]
        out.setdefault(m.group(1), []).extend(n for n in names if n)
    return out
