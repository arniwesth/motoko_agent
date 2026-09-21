"""AILANG-aware lexer and span finder for the protected-source checker.

ADR-004 D5, PLAN-004 §3 P1.4b. Everything here works on the ORIGINAL BYTES of
a file; nothing is normalised. Offsets are 0-based and half-open.

The lexer knows exactly three things about AILANG, and they are all it needs
to count braces honestly:

  * `--` starts a comment that runs to the end of the line (outside literals);
  * `"` starts a string literal; `\\` escapes the next byte (so `\\"` and
    `\\${` are literal); `${` opens an interpolation holding CODE — which may
    itself hold strings, comments and brackets — closed by the `}` that
    balances it; a literal may span lines;
  * `(`/`)`, `{`/`}`, `[`/`]` are counted outside literals and comments.

An unterminated literal (or interpolation) and an unbalanced or mismatched
bracket are hard errors (`SpanError`, exit 2 at the CLI), reported with file
and line.

`derive.py`'s `strip_noise`/`func_spans` are the technique this borrows (line
starts at column 0, depth tracking); their hashes are not borrowed, because
they erase literals and extend a span to the next start (ADR-004 D5).
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field

DECL_KEYWORDS = (b"import", b"func", b"pure", b"export", b"type", b"module", b"let")
MODIFIERS = (b"export", b"pure")
OPEN = {ord("("): ord(")"), ord("{"): ord("}"), ord("["): ord("]")}
CLOSE = {v: k for k, v in OPEN.items()}
IDENT_START = set(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_")
IDENT_CHAR = IDENT_START | set(b"0123456789")


class SpanError(Exception):
    """A hard error: the file cannot be delimited. Exit 2."""

    def __init__(self, path: str, line: int, msg: str):
        super().__init__(f"{path}:{line}: {msg}")
        self.path, self.line, self.msg = path, line, msg


@dataclass
class Tok:
    kind: str      # ident | open | close | str | punct
    text: bytes
    start: int
    end: int
    line: int      # 1-based line of `start`
    depth: int     # top-level bracket depth BEFORE this token (open) / AFTER (close)
    interp: bool   # inside a `${…}` interpolation (not structural)


@dataclass
class Lexed:
    path: str
    src: bytes
    toks: list            # every token; structural ones have interp=False
    line_starts: list     # byte offset of each line (index 0 = line 1)
    line_depth: list      # top-level depth at the start of each line
    line_in_lit: list     # True if the line starts inside a literal/interpolation

    def line_of(self, off: int) -> int:
        lo, hi = 0, len(self.line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.line_starts[mid] <= off:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1

    def line_text(self, line: int) -> bytes:
        s = self.line_starts[line - 1]
        e = self.line_starts[line] if line < len(self.line_starts) else len(self.src)
        return self.src[s:e]

    def line_end(self, line: int) -> int:
        """Offset of the last byte of `line` + 1, excluding its newline."""
        t = self.line_text(line)
        s = self.line_starts[line - 1]
        return s + len(t.rstrip(b"\r\n"))

    @property
    def nlines(self) -> int:
        return len(self.line_starts)


def lex(src: bytes, path: str) -> Lexed:
    n = len(src)
    line_starts = [0]
    for i, b in enumerate(src):
        if b == 10 and i + 1 < n:
            line_starts.append(i + 1)
    line_depth = [0] * len(line_starts)
    line_in_lit = [False] * len(line_starts)
    toks: list = []

    # frames: ("code", brackets, start_off) for top level / interpolation;
    #         ("str", None, start_off) for a string literal.
    top: list = []                       # top-level bracket stack: (byte, line)
    frames: list = [("code", top, 0)]
    i, line = 0, 1
    lit_start = None                     # outermost literal start, for its token

    while i < n:
        b = src[i]
        if b == 10:
            line += 1
            if line - 1 < len(line_starts):
                line_depth[line - 1] = len(top)
                line_in_lit[line - 1] = len(frames) > 1
            i += 1
            continue
        kind, stack, fstart = frames[-1]
        interp = len(frames) > 1
        if kind == "str":
            if b == 92:                  # backslash: skip the escaped byte
                if i + 1 < n and src[i + 1] == 10:
                    i += 1               # let the newline branch count it
                else:
                    i += 2
                continue
            if b == 34:                  # closing quote
                frames.pop()
                i += 1
                if len(frames) == 1:
                    toks.append(Tok("str", src[lit_start:i], lit_start, i,
                                    _line_at(line_starts, lit_start), len(top), False))
                continue
            if b == 36 and i + 1 < n and src[i + 1] == 123:   # ${
                frames.append(("code", [], i))
                i += 2
                continue
            i += 1
            continue
        # code
        if b == 45 and i + 1 < n and src[i + 1] == 45:        # -- comment
            j = src.find(b"\n", i)
            i = n if j < 0 else j
            continue
        if b == 34:
            if not interp:
                lit_start = i
            frames.append(("str", None, i))
            i += 1
            continue
        if b in OPEN:
            depth = len(stack)
            stack.append((b, line))
            toks.append(Tok("open", bytes([b]), i, i + 1, line, depth, interp))
            i += 1
            continue
        if b in CLOSE:
            if not stack:
                if interp and b == 125:  # closes the interpolation
                    frames.pop()
                    i += 1
                    continue
                raise SpanError(path, line, f"unbalanced '{chr(b)}': no matching opener")
            ob, oline = stack.pop()
            if OPEN[ob] != b:
                raise SpanError(path, line, f"mismatched '{chr(b)}' closes '{chr(ob)}' opened at line {oline}")
            toks.append(Tok("close", bytes([b]), i, i + 1, line, len(stack), interp))
            i += 1
            continue
        if b in IDENT_START:
            j = i + 1
            while j < n and src[j] in IDENT_CHAR:
                j += 1
            toks.append(Tok("ident", src[i:j], i, j, line, len(stack), interp))
            i = j
            continue
        if b in (32, 9, 13):
            i += 1
            continue
        toks.append(Tok("punct", bytes([b]), i, i + 1, line, len(stack), interp))
        i += 1

    if len(frames) > 1:
        kind, _, fstart = frames[1]
        what = "string literal" if kind == "str" else "interpolation"
        # report the outermost open literal
        raise SpanError(path, _line_at(line_starts, frames[1][2]), f"unterminated {what}")
    if top:
        ob, oline = top[-1]
        raise SpanError(path, oline, f"unbalanced '{chr(ob)}': never closed")
    return Lexed(path, src, toks, line_starts, line_depth, line_in_lit)


def _line_at(line_starts, off):
    lo, hi = 0, len(line_starts) - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if line_starts[mid] <= off:
            lo = mid
        else:
            hi = mid - 1
    return lo + 1


# ---------------------------------------------------------------------------
# Spans
# ---------------------------------------------------------------------------

@dataclass
class Span:
    file: str
    symbol: str
    kind: str          # func | type_braced | type_unbraced | imports | call_site
    start: int
    end: int           # half-open
    line_start: int
    line_end: int
    names: list = field(default_factory=list)      # type: its constructors
    statements: list = field(default_factory=list)  # imports: per-statement records

    def sha256(self, src: bytes) -> str:
        return hashlib.sha256(src[self.start:self.end]).hexdigest()


@dataclass
class ImportStmt:
    module: str
    alias: str | None
    names: list
    start: int
    end: int
    line_start: int
    line_end: int


@dataclass
class Parsed:
    lx: Lexed
    decls: list        # Span for every func/type declaration, in file order
    imports: list      # aggregate imports spans
    stmts: list        # every ImportStmt

    def by_name(self, name: str) -> list:
        return [d for d in self.decls if d.symbol == name]


def _decl_starts(lx: Lexed):
    """Lines that begin, at column 0, depth 0 and outside a literal, with a
    declaration keyword (the plan's six, plus top-level `let`). Returns
    [(line, keyword, annotated_from)], where annotated_from is the first line
    of a contiguous run of column-0 `@annotation(…)` lines directly above
    (AILANG decorators), or the line itself; it is where the previous
    declaration ends. A line holding only `export`/`pure` (and a comment) is
    joined with the declaration line that follows it."""
    struct_by_line = {}
    for t in lx.toks:
        if not t.interp:
            struct_by_line.setdefault(t.line, []).append(t)
    raw = []
    for ln in range(1, lx.nlines + 1):
        if lx.line_depth[ln - 1] != 0 or lx.line_in_lit[ln - 1]:
            continue
        t = lx.line_text(ln)
        for kw in DECL_KEYWORDS:
            if t.startswith(kw) and (len(t) == len(kw) or t[len(kw)] not in IDENT_CHAR):
                raw.append((ln, kw.decode()))
                break
    out = []
    skip = set()
    for i, (ln, kw) in enumerate(raw):
        if ln in skip:
            continue
        toks = struct_by_line.get(ln, [])
        if toks and all(x.kind == "ident" and x.text in MODIFIERS for x in toks) and i + 1 < len(raw):
            skip.add(raw[i + 1][0])
        first = ln
        p = ln - 1
        while p >= 1 and lx.line_text(p).startswith(b"@"):
            first = p
            p -= 1
        # an annotation may span lines: accept a run that starts at depth 0
        if first != ln and (lx.line_depth[first - 1] != 0 or lx.line_in_lit[first - 1]):
            first = ln
        out.append((ln, kw, first))
    return out


def _is_comment_or_blank(t: bytes) -> bool:
    s = t.strip()
    return not s or s.startswith(b"--")


def parse(src: bytes, path: str) -> Parsed:
    lx = lex(src, path)
    starts = _decl_starts(lx)
    struct = [t for t in lx.toks if not t.interp]
    # index structural tokens by start offset for range queries
    offs = [t.start for t in struct]

    import bisect

    def toks_between(a, b):
        return struct[bisect.bisect_left(offs, a):bisect.bisect_left(offs, b)]

    decls, stmts = [], []
    for idx, (ln, kw, ann) in enumerate(starts):
        # A span starts at its keyword line (PLAN-004 P1.4b: "from its first
        # line's first byte"); `@annotation` lines above it are not in it —
        # they only end the PREVIOUS declaration. No protected file holds an
        # annotation at A; an annotation is outside every span, like a comment.
        a = lx.line_starts[ln - 1]
        # the next declaration begins at its first annotation line
        nxt_line = starts[idx + 1][2] if idx + 1 < len(starts) else None
        b = lx.line_starts[nxt_line - 1] if nxt_line else len(src)
        ts = toks_between(lx.line_starts[ln - 1], b)
        if kw == "module":
            continue
        if kw == "let":
            if len(ts) < 2 or ts[1].kind != "ident":
                raise SpanError(path, ln, "top-level let without a name")
            end, last = _unbraced_end(lx, ln, nxt_line)
            decls.append(Span(path, ts[1].text.decode(), "let", a, end, ln, last))
            continue
        if kw == "import":
            stmts.extend(_parse_imports(lx, ts, path))
            continue
        # export? pure? (func|type) NAME
        k = 0
        words = []
        while k < len(ts) and ts[k].kind == "ident" and ts[k].text in (b"export", b"pure"):
            words.append(ts[k].text.decode())
            k += 1
        if k >= len(ts) or ts[k].kind != "ident" or ts[k].text not in (b"func", b"type"):
            raise SpanError(path, ln, "declaration keyword not followed by func/type")
        which = ts[k].text.decode()
        if k + 1 >= len(ts) or ts[k + 1].kind != "ident":
            raise SpanError(path, ln, f"{which} without a name")
        name = ts[k + 1].text.decode()
        if which == "func":
            if any(_lone_eq(ts, q) for q in range(k + 2, len(ts))):
                end, last = _unbraced_end(lx, ln, nxt_line)
                decls.append(Span(path, name, "func_unbraced", a, end, ln, last))
            else:
                end = _braced_end(lx, ts, k + 2, path, ln, name)
                decls.append(Span(path, name, "func", a, end, ln, lx.line_of(end - 1)))
            continue
        # type: find '=' at depth 0
        j = k + 2
        while j < len(ts) and not (ts[j].kind == "punct" and ts[j].text == b"=" and ts[j].depth == 0):
            j += 1
        if j + 1 >= len(ts):
            raise SpanError(path, ln, f"type {name} has no '= …' body")
        first = ts[j + 1]
        if first.kind == "open" and first.text == b"{":
            end = _braced_end(lx, ts, j + 1, path, ln, name)
            decls.append(Span(path, name, "type_braced", a, end, ln, lx.line_of(end - 1)))
            continue
        end, last = _unbraced_end(lx, ln, nxt_line)
        body = toks_between(lx.line_starts[ln - 1], end)
        ctors = []
        for q in range(j + 1, len(body)):
            t = body[q]
            prev = body[q - 1]
            if (t.kind == "ident" and t.depth == 0 and t.text[:1].isupper()
                    and prev.kind == "punct" and prev.text in (b"=", b"|") and prev.depth == 0):
                ctors.append(t.text.decode())
        decls.append(Span(path, name, "type_unbraced", a, end, ln, last, names=ctors))

    imports = _aggregate_imports(lx, stmts, struct, path)
    return Parsed(lx, decls, imports, stmts)


def _lone_eq(ts, q) -> bool:
    """ts[q] is a depth-0 `=` that is not part of `==`, `=>`, `<=`, `>=`, `!=`."""
    t = ts[q]
    if not (t.kind == "punct" and t.text == b"=" and t.depth == 0):
        return False
    for o in (ts[q - 1] if q else None, ts[q + 1] if q + 1 < len(ts) else None):
        if o is not None and o.kind == "punct" and (o.end == t.start or o.start == t.end) \
                and o.text in (b"=", b">", b"<", b"!"):
            return False
    return True


def _unbraced_end(lx, ln, nxt_line):
    """THE HEURISTIC (checked against the parser by `crosscheck`): a
    non-braced declaration starting at line `ln` runs to the last non-blank
    line before the next column-0 declaration line (`nxt_line`, already moved
    up over its annotations), or before a column-0 `--` comment block that
    runs (blank lines allowed) into it, or EOF. Returns (end, last_line)."""
    stop = nxt_line if nxt_line else lx.nlines + 1
    if nxt_line:
        p = nxt_line - 1
        first_comment = None
        while p > ln:
            t = lx.line_text(p)
            if t.startswith(b"--"):
                first_comment = p
            elif t.strip():
                break
            p -= 1
        if first_comment:
            stop = first_comment
    last = stop - 1
    while last > ln and not lx.line_text(last).strip():
        last -= 1
    return lx.line_end(last), last


def _braced_end(lx, ts, k, path, ln, name) -> int:
    """End (half-open) of a braced declaration whose tokens are ts[k:]. The
    body is the last depth-0 `{…}` group; a following `deriving (…)` or
    `tests […]` extends the span. Anything else after the body is an error."""
    groups = []   # (open_tok_index, close_tok_index)
    stack = []
    for q in range(k, len(ts)):
        t = ts[q]
        if t.kind == "open" and t.depth == 0:
            stack.append(q)
        elif t.kind == "close" and t.depth == 0:
            groups.append((stack.pop(), q))
    # the tail after the body: only `deriving (…)` / `tests […]`
    q = len(ts) - 1
    end_idx = q
    while groups:
        o, c = groups[-1]
        if c != q:
            raise SpanError(path, ts[q].line, f"{name}: unexpected token {ts[q].text!r} after the declaration body")
        opener = ts[o].text
        prev = ts[o - 1] if o - 1 >= k else None
        if opener == b"{":
            return ts[end_idx].end
        if prev is not None and prev.kind == "ident" and (
                (opener == b"(" and prev.text == b"deriving") or (opener == b"[" and prev.text == b"tests")):
            groups.pop()
            q = o - 2
            continue
        break
    raise SpanError(path, ln, f"{name}: cannot find the braced body")


def _parse_imports(lx, ts, path):
    """Import statements in ts (tokens from one `import` line up to the next
    declaration line): `import <path> [as Alias] [( … )]`, repeated."""
    out = []
    q = 0
    while q < len(ts):
        t = ts[q]
        if not (t.kind == "ident" and t.text == b"import"):
            raise SpanError(path, t.line, f"unexpected token {t.text!r} in an import region")
        start = t.start
        q += 1
        parts = []
        while q < len(ts) and (ts[q].kind == "ident" or (ts[q].kind == "punct" and ts[q].text == b"/")):
            # the path ends where an identifier is not preceded by '/'
            if ts[q].kind == "ident" and parts and parts[-1] != "/":
                break
            parts.append(ts[q].text.decode())
            q += 1
        if not parts:
            raise SpanError(path, t.line, "import without a module path")
        end = ts[q - 1].end
        alias = None
        if q + 1 < len(ts) and ts[q].kind == "ident" and ts[q].text == b"as" and ts[q + 1].kind == "ident":
            alias = ts[q + 1].text.decode()
            end = ts[q + 1].end
            q += 2
        names = []
        if q < len(ts) and ts[q].kind == "open" and ts[q].text == b"(":
            q += 1
            while q < len(ts) and not (ts[q].kind == "close" and ts[q].depth == 0):
                tq = ts[q]
                if tq.kind == "ident" and tq.text != b"as":
                    prevt = ts[q - 1]
                    if not (prevt.kind == "ident" and prevt.text == b"as"):
                        names.append(tq.text.decode())
                q += 1
            if q >= len(ts):
                raise SpanError(path, t.line, "import list never closed")
            end = ts[q].end
            q += 1
        out.append(ImportStmt("".join(parts), alias, names, start, end,
                              lx.line_of(start), lx.line_of(end - 1)))
    return out


def _aggregate_imports(lx, stmts, struct, path):
    """One span per contiguous run of import statements: statements with no
    non-import code token between them. The span runs from the first byte of
    the first line holding a statement to the last byte of the last such
    line (its trailing comment included)."""
    runs = []
    if not stmts:
        return runs
    offs = [t.start for t in struct]
    import bisect
    cur = [stmts[0]]
    for s in stmts[1:]:
        between = struct[bisect.bisect_left(offs, cur[-1].end):bisect.bisect_left(offs, s.start)]
        if between:
            runs.append(cur)
            cur = [s]
        else:
            cur.append(s)
    runs.append(cur)
    out = []
    for i, run in enumerate(runs, 1):
        l0, l1 = run[0].line_start, run[-1].line_end
        a = lx.line_starts[l0 - 1]
        e = lx.line_end(l1)
        # a code token after the last statement on its line is not an import
        tail = struct[bisect.bisect_left(offs, run[-1].end):bisect.bisect_left(offs, e)]
        if tail:
            raise SpanError(path, l1, "code after an import statement on the same line")
        out.append(Span(path, f"<imports:{i}>", "imports", a, e, l0, l1,
                        statements=run))
    return out


def call_sites(p: Parsed, callee: str) -> list:
    """Statement spans of each structural call `callee(` that is not in an
    import statement and not the head of callee's own declaration. The span
    runs from the first byte of the call's line through the matching `)`
    and a directly following `;`."""
    struct = [t for t in p.lx.toks if not t.interp]
    heads = {d.start for d in p.decls if d.symbol == callee}
    out = []
    for i, t in enumerate(struct):
        if not (t.kind == "ident" and t.text == callee.encode()):
            continue
        if i + 1 >= len(struct) or struct[i + 1].text != b"(":
            continue
        if any(s.start <= t.start < s.end for s in p.stmts):
            continue
        if i >= 1 and struct[i - 1].text == b"func":
            continue
        depth = struct[i + 1].depth
        j = i + 2
        while j < len(struct) and not (struct[j].kind == "close" and struct[j].depth == depth):
            j += 1
        end = struct[j].end
        if j + 1 < len(struct) and struct[j + 1].text == b";":
            end = struct[j + 1].end
        ln = p.lx.line_of(t.start)
        out.append(Span(p.lx.path, f"{callee}@call", "call_site",
                        p.lx.line_starts[ln - 1], end, ln, p.lx.line_of(end - 1)))
    return out


def idents_in(p: Parsed, span: Span) -> set:
    """Every identifier token (interpolations included) inside a span."""
    return {t.text.decode() for t in p.lx.toks
            if t.kind == "ident" and span.start <= t.start < span.end}


def qualified_refs(p: Parsed, span: Span) -> set:
    """`Alias.Name` references inside a span: {(alias, name)}."""
    toks = [t for t in p.lx.toks if span.start <= t.start < span.end]
    out = set()
    for a, dot, b in zip(toks, toks[1:], toks[2:]):
        if (a.kind == "ident" and dot.text == b"." and b.kind == "ident"
                and dot.start == a.end and b.start == dot.end):
            out.add((a.text.decode(), b.text.decode()))
    return out
