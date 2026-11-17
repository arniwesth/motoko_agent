#!/usr/bin/env python3
"""039 random-mutant pilot: the five operators, as one text edit each.

    mutator.py enumerate <root> <outdir>   write candidates.tsv, sites.tsv, counts.tsv
    mutator.py apply <id> <root>           make that one edit under <root>; refuse unless the
                                           file is byte-identical to the one enumerated
    mutator.py show <id> <root>            print the edit, nothing written
    mutator.py selftest                    the planted cases

The definitions are in `../operators.md`; this file is their executable form. It reads the
source as text through `ailsrc.py`: every comment and every string literal (interpolations
included) is one opaque token, so no operator can reach inside either. Sites are taken only
inside the body of a population function (`../population.tsv`).

Whether a mutant type-checks is not decided here. `ailang check` decides it at the draw.
"""
import glob
import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ailsrc  # noqa: E402
from ailsrc import OPEN, CLOSE, match_close  # noqa: E402

CMP = {"==", "!=", "<", "<=", ">", ">="}
NEGATE = {"==": "!=", "!=": "==", "<": ">=", ">=": "<", ">": "<=", "<=": ">"}
BOUNDARY = {"<": "<=", "<=": "<", ">": ">=", ">=": ">"}
WORLD_FIELDS = {"world_state", "world", "next_state"}
# A right operand of `++` (or a head of `::`) stops at these, at its own depth.
STOP_RIGHT = {",", ";", ")", "]", "}", "++", "then", "else", "&&", "||", "==", "!=", "=>"}
STOP_LEFT = {"(", "[", "{", ",", ";", "=", "=>", "->", "then", "else", "::", "++", "|", ":"}

ABBR = {"src/core/session.ail": "session", "src/core/tool_phase.ail": "tool_phase",
        "src/core/step_machine.ail": "step_machine", "src/core/recovery.ail": "recovery"}


# ---------------------------------------------------------------------------------------------
# Signatures from every function under src/: which parameter positions are a `WorldState`, and
# which functions add to a `LedgerTrace`. A name is used only when every definition agrees.
# ---------------------------------------------------------------------------------------------
def file_imports(src):
    """{name: module path} for every `import <path> (names)` in the file, wherever it sits on a
    line (this source joins several imports onto one line), comments excluded."""
    ct = [t for t in ailsrc.tokens(src) if t.kind != "comment"]
    out = {}
    for i, t in enumerate(ct):
        if t.kind == "ident" and t.text == "import" and (i == 0 or ct[i - 1].text != "."):
            j, parts = i + 1, []
            while j < len(ct) and ct[j].text != "(" and ct[j].text != "import":
                parts.append(ct[j].text)
                j += 1
            if j >= len(ct) or ct[j].text != "(":
                continue
            mod = "".join(parts).split(" as ")[0]
            close = match_close(ct, j)
            k = j + 1
            while k < close:
                if ct[k].kind == "ident" and ct[k - 1].text in ("(", ","):
                    out[ct[k].text] = mod
                k += 1
    return out


def _sig_of(f):
    ret = f.sig.split("->")[-1].split("!")[0].strip() if "->" in f.sig else ""
    return tuple(t for _, t in f.params), ret


def signatures(root):
    """Every function under src/: {module path: {name: (param types, return type)}}."""
    by_mod, skipped = {}, []
    for p in sorted(glob.glob(os.path.join(root, "src", "**", "*.ail"), recursive=True)):
        rel = os.path.relpath(p, root)
        mod = rel[:-len(".ail")]
        try:
            s = open(p, encoding="utf-8").read()
            fs = ailsrc.functions(s, rel)
        except Exception as e:  # recorded, never silent
            skipped.append(f"{rel}: {e}")
            continue
        by_mod[mod] = {f.name: _sig_of(f) for f in fs}
    return by_mod, skipped


def resolver(by_mod, path, src):
    """A callee's signature as the calling file sees it: its own definition; else the module it
    imports the name from; else the definitions under src/ when they all agree; else None."""
    own = path[:-len(".ail")]
    imps = file_imports(src)
    everywhere = {}
    for m, fs in by_mod.items():
        for n, sg in fs.items():
            everywhere.setdefault(n, set()).add(sg)
    unresolved = set()

    def resolve(name):
        if name in by_mod.get(own, {}):
            return by_mod[own][name]
        if name in imps and name in by_mod.get(imps[name], {}):
            return by_mod[imps[name]][name]
        defs = everywhere.get(name, set())
        if len(defs) == 1:
            return next(iter(defs))
        if defs:
            unresolved.add(name)
        return None
    return resolve, unresolved


def world_positions(sig):
    return tuple(i for i, t in enumerate(sig[0]) if t == "WorldState") if sig else ()


def trace_position(sig):
    if not sig:
        return None
    lt = [i for i, t in enumerate(sig[0]) if t == "LedgerTrace"]
    return lt[0] if sig[1] == "LedgerTrace" and len(lt) == 1 else None


def port_world_methods(root):
    """`Ports` fields whose first parameter is a `WorldState`, read from src/core/ports.ail."""
    import re
    s = open(os.path.join(root, "src/core/ports.ail"), encoding="utf-8").read()
    return sorted(set(re.findall(r"^\s+([a-z_][a-z0-9_]*): \(WorldState\b", s, re.M)))


# ---------------------------------------------------------------------------------------------
# Small token helpers over a body's code tokens (comments dropped, strings kept as opaque tokens).
# ---------------------------------------------------------------------------------------------
def split_top(ct, a, b, sep=","):
    """Split ct[a:b] at depth-0 `sep` tokens; return [(i0, i1)] index ranges, possibly empty."""
    out, depth, start = [], 0, a
    for i in range(a, b):
        t = ct[i]
        if t.kind == "op" and t.text in OPEN:
            depth += 1
        elif t.kind == "op" and t.text in CLOSE:
            depth -= 1
        elif depth == 0 and t.text == sep and t.kind == "op":
            out.append((start, i))
            start = i + 1
    out.append((start, b))
    return [(x, y) for x, y in out if y > x]


def scan_right(ct, k):
    """From ct[k], the end index (exclusive) of an operand that stops at a depth-0 STOP_RIGHT."""
    depth, i = 0, k
    while i < len(ct):
        t = ct[i]
        if t.kind == "op" and t.text in OPEN:
            i = match_close(ct, i) + 1
            continue
        if t.text in STOP_RIGHT and (t.kind == "op" or t.text in ("then", "else")):
            break
        i += 1
    return i


def scan_left(ct, k, lo):
    """From ct[k-1] leftwards, the start index of an operand that stops at a STOP_LEFT."""
    i = k - 1
    while i >= lo:
        t = ct[i]
        if t.kind == "op" and t.text in CLOSE:
            # jump to the matching opener
            depth = 0
            while i >= lo:
                u = ct[i]
                if u.kind == "op" and u.text in CLOSE:
                    depth += 1
                elif u.kind == "op" and u.text in OPEN:
                    depth -= 1
                    if depth == 0:
                        break
                i -= 1
            i -= 1
            continue
        if t.text in STOP_LEFT and (t.kind == "op" or t.text in ("then", "else")):
            break
        i -= 1
    return i + 1


def is_binary_context(prev):
    return prev is not None and (prev.kind in ("ident", "num", "string") or prev.text in (")", "]", "}"))


# ---------------------------------------------------------------------------------------------
# Enumeration.
# ---------------------------------------------------------------------------------------------
class Cand:
    def __init__(self, file, func, op, shape, start, end, new, src, variant=""):
        self.file, self.func, self.op, self.shape = file, func, op, shape
        self.start, self.end, self.new, self.variant = start, end, new, variant
        self.old = src[start:end]
        # the first character the edit changes, for the line and column
        n = 0
        while n < min(len(self.old), len(new)) and self.old[n] == new[n]:
            n += 1
        p = start + n if n < len(self.old) or n < len(new) else start
        self.line = src.count("\n", 0, p) + 1
        self.col = p - (src.rfind("\n", 0, p) + 1) + 1
        self.id = ""


def predecessor(f):
    for name, t in f.params:
        if name == "st" and t == "C2LoopState":
            return "st.world_state"
    for name, t in f.params:
        if t == "WorldState":
            return name
    for name, t in f.params:
        if t == "PortedProvider":
            return f"{name}.world"
    return None


def enumerate_file(path, src, funcs, resolve, port_methods):
    toks = ailsrc.tokens(src)
    out = []
    for f in funcs:
        ct = [t for t in toks if f.body_start <= t.start < f.body_end and t.kind != "comment"]
        pred = predecessor(f)

        def C(op, shape, a, b, new, variant=""):
            c = Cand(path, f.name, op, shape, a, b, new, src, variant)
            if c.old != c.new:
                out.append(c)

        # match arms and their pattern spans (for MAS, and to keep `::` and list drops out of patterns)
        pattern_spans = []
        arms_of = []
        for i, t in enumerate(ct):
            if t.kind == "ident" and t.text == "match":
                j, depth = i + 1, 0
                while j < len(ct):
                    u = ct[j]
                    if u.kind == "op" and u.text in ("(", "["):
                        j = match_close(ct, j) + 1
                        continue
                    if u.kind == "op" and u.text == "{":
                        break
                    j += 1
                close = match_close(ct, j)
                arms = []
                for a, b in split_top(ct, j + 1, close):
                    arrow = next((k for k in range(a, b) if ct[k].text == "=>" and ct[k].kind == "op"
                                  and _depth(ct, a, k) == 0), None)
                    if arrow is None or arrow + 1 >= b:
                        continue
                    pattern_spans.append((ct[a].start, ct[arrow].end))
                    arms.append((a, arrow, b))
                arms_of.append(arms)
        in_pattern = lambda pos: any(x <= pos < y for x, y in pattern_spans)

        # MAS
        for arms in arms_of:
            for (a1, r1, b1), (a2, r2, b2) in zip(arms, arms[1:]):
                A0, A1 = ct[r1 + 1].start, ct[b1 - 1].end
                B0, B1 = ct[r2 + 1].start, ct[b2 - 1].end
                A, B = src[A0:A1], src[B0:B1]
                if A == B:
                    continue
                c = Cand(path, f.name, "MAS", "swap", A0, B1, B + src[A1:B0] + A, src)
                # its line is the first arm's pattern line, by definition
                c.line = src.count("\n", 0, ct[a1].start) + 1
                c.col = ct[a1].start - (src.rfind("\n", 0, ct[a1].start) + 1) + 1
                out.append(c)

        # where each name is first bound: parameters before the body, `let`s at their index
        bound = {n: -1 for n, _ in f.params}
        for i, t in enumerate(ct):
            prev = ct[i - 1] if i else None
            nxt = ct[i + 1] if i + 1 < len(ct) else None
            # CF and OBO(a)
            if t.kind == "op" and t.text in CMP:
                C("CF", "negate", t.start, t.end, NEGATE[t.text])
                if t.text in BOUNDARY:
                    C("OBO", "boundary", t.start, t.end, BOUNDARY[t.text])
            # OBO(b)
            if t.kind == "num" and "." not in t.text:
                k = int(t.text)
                operand = (prev is not None and prev.kind == "op" and prev.text in CMP) or \
                          (nxt is not None and nxt.kind == "op" and nxt.text in CMP) or \
                          (prev is not None and prev.kind == "op" and prev.text in ("+", "-")
                           and is_binary_context(ct[i - 2] if i >= 2 else None))
                if operand:
                    C("OBO", "literal", t.start, t.end, str(k + 1), "+1")
                    if k >= 1:
                        C("OBO", "literal", t.start, t.end, str(k - 1), "-1")
            # BF
            if t.kind == "op" and t.text in ("&&", "||"):
                C("BF", "connective", t.start, t.end, "||" if t.text == "&&" else "&&")
            if t.kind == "ident" and t.text in ("true", "false"):
                C("BF", "literal", t.start, t.end, "false" if t.text == "true" else "true")
            if t.kind == "ident" and t.text == "not" and nxt is not None:
                C("BF", "not", t.start, nxt.start, "")
            # SR.stmt
            if t.kind == "op" and t.text == ";":
                s0 = scan_stmt_start(ct, i)
                first = ct[s0]
                if first.text == "let" and s0 + 1 < i:
                    name = ct[s0 + 1].text
                    if name == "_" or (bound.get(name, len(ct)) < s0 and ct[s0 + 2].text in ("=", ":")):
                        C("SR", "stmt", first.start, t.end, "")
                else:
                    C("SR", "stmt", first.start, t.end, "")
            if t.kind == "ident" and t.text == "let" and nxt is not None and nxt.kind == "ident":
                bound.setdefault(nxt.text, i)
            # SR.record (i): a call that adds to a LedgerTrace
            tpos = trace_position(resolve(t.text)) if t.kind == "ident" and nxt is not None and nxt.text == "(" \
                and (prev is None or prev.text != ".") else None
            if tpos is not None:
                close = match_close(ct, i + 1)
                args = split_top(ct, i + 2, close)
                pos = tpos
                if pos < len(args):
                    a, b = args[pos]
                    C("SR", "record", t.start, ct[close].end, src[ct[a].start:ct[b - 1].end])
            # SR.record (ii): `A ++ B` keeps A
            if t.kind == "op" and t.text == "++" and prev is not None:
                e = scan_right(ct, i + 1)
                if e > i + 1:
                    C("SR", "record", prev.end, ct[e - 1].end, "")
            # SR.record (iii): `H :: T` keeps T, outside patterns
            if t.kind == "op" and t.text == "::" and not in_pattern(t.start) and nxt is not None:
                h = scan_left(ct, i, 0)
                if h < i:
                    C("SR", "record", ct[h].start, nxt.start, "")
            # SR.record (iv): a list literal of two or more elements loses one
            if t.kind == "op" and t.text == "[" and not in_pattern(t.start) and not _is_type_bracket(ct, i):
                close = match_close(ct, i)
                elems = split_top(ct, i + 1, close)
                if len(elems) >= 2:
                    for n, (a, b) in enumerate(elems):
                        if n + 1 < len(elems):
                            C("SR", "record", ct[a].start, ct[elems[n + 1][0]].start, "", f"e{n}")
                        else:
                            C("SR", "record", ct[elems[n - 1][1] - 1].end, ct[b - 1].end, "", f"e{n}")
            # SR.world (i): a record field that carries a world
            if pred and t.kind == "ident" and t.text in WORLD_FIELDS and nxt is not None and nxt.text == ":" \
                    and prev is not None and prev.text in ("{", ",", "|") and not in_pattern(t.start):
                e = scan_right(ct, i + 2)
                if e > i + 2:
                    v0, v1 = ct[i + 2].start, ct[e - 1].end
                    val = src[v0:v1]
                    if val.strip() not in (pred, "WorldState"):
                        C("SR", "world", v0, v1, pred)
            # SR.world (ii): a call argument at a WorldState position
            if pred and t.kind == "ident" and nxt is not None and nxt.text == "(":
                if prev is not None and prev.text == ".":
                    positions = (0,) if t.text in port_methods else ()
                else:
                    positions = world_positions(resolve(t.text))
                if positions:
                    close = match_close(ct, i + 1)
                    args = split_top(ct, i + 2, close)
                    for pos in positions:
                        if pos < len(args):
                            a, b = args[pos]
                            v0, v1 = ct[a].start, ct[b - 1].end
                            if src[v0:v1].strip() != pred:
                                C("SR", "world", v0, v1, pred, f"arg{pos}")
    return out


def _depth(ct, a, k):
    d = 0
    for i in range(a, k):
        t = ct[i]
        if t.kind == "op" and t.text in OPEN:
            d += 1
        elif t.kind == "op" and t.text in CLOSE:
            d -= 1
    return d


def _is_type_bracket(ct, i):
    """`let name: [T]` and `(x: [T])` are types, not list literals."""
    if i >= 2 and ct[i - 1].text == ":" and ct[i - 2].kind == "ident":
        return i >= 3 and ct[i - 3].text in ("let", "(", ",") and ct[i - 3].text != "{"
    return False


def scan_stmt_start(ct, k):
    """`ct[k]` is a `;`. The index of the first token of the statement it ends."""
    i = k - 1
    while i >= 0:
        t = ct[i]
        if t.kind == "op" and t.text in CLOSE:
            depth = 0
            while i >= 0:
                u = ct[i]
                if u.kind == "op" and u.text in CLOSE:
                    depth += 1
                elif u.kind == "op" and u.text in OPEN:
                    depth -= 1
                    if depth == 0:
                        break
                i -= 1
            i -= 1
            continue
        if t.kind == "op" and (t.text == ";" or t.text in OPEN):
            return i + 1
        i -= 1
    return 0


def load_population(here):
    rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(here, "population.tsv"), encoding="utf-8")][1:]
    pop = {}
    for r in rows:
        if r and r[0]:
            pop.setdefault(r[0], []).append(r[1])
    return pop


def enumerate_all(root, pop=None):
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pop = pop or load_population(here)
    by_mod, skipped = signatures(root)
    ports = port_world_methods(root)
    cands, hashes, resolved_log = [], {}, {}
    for path in sorted(pop):
        src = open(os.path.join(root, path), encoding="utf-8").read()
        hashes[path] = hashlib.sha256(src.encode()).hexdigest()
        funcs = [f for f in ailsrc.functions(src, path) if f.name in pop[path]]
        missing = set(pop[path]) - {f.name for f in funcs}
        if missing:
            sys.exit(f"population names functions not found in {path}: {sorted(missing)}")
        resolve, unresolved = resolver(by_mod, path, src)
        cands += enumerate_file(path, src, funcs, resolve, ports)
        names = sorted({t.text for f in funcs for t in ailsrc.body_tokens(src, f) if t.kind == "ident"})
        resolved_log[path] = {
            "world": {n: world_positions(resolve(n)) for n in names if world_positions(resolve(n))},
            "trace": {n: trace_position(resolve(n)) for n in names if trace_position(resolve(n)) is not None},
            "unresolved": sorted(unresolved)}
    # ids: file:line:col:OP.shape, with the variant, unique
    seen = {}
    for c in sorted(cands, key=lambda c: (c.file, c.start, c.end, c.op, c.shape, c.variant)):
        base = f"{ABBR.get(c.file, c.file)}:{c.line}:{c.col}:{c.op}.{c.shape}" + (f".{c.variant}" if c.variant else "")
        n = seen.get(base, 0)
        seen[base] = n + 1
        c.id = base if n == 0 else f"{base}.{n}"
    cands.sort(key=lambda c: (c.file, c.line, c.col, c.op, c.shape, c.variant, c.id))
    meta = {"resolved": resolved_log, "skipped": skipped, "ports": ports, "hashes": hashes}
    return cands, meta


def esc(s):
    return s.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")


def cmd_enumerate(root, outdir):
    cands, meta = enumerate_all(root)
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "candidates.tsv"), "w", encoding="utf-8") as o:
        o.write("id\tfile\tline\tfunction\toperator\tshape\told\tnew\n")
        for c in cands:
            o.write("\t".join([c.id, c.file, str(c.line), c.func, c.op, c.shape, esc(c.old), esc(c.new)]) + "\n")
    sites = {}
    for c in cands:
        sites.setdefault((c.file, c.line), {}).setdefault(c.op, []).append(c.id)
    with open(os.path.join(outdir, "sites.tsv"), "w", encoding="utf-8") as o:
        o.write("site\tfile\tline\toperators\tcandidates_per_operator\n")
        for (fp, ln), ops in sorted(sites.items()):
            o.write(f"{ABBR[fp]}:{ln}\t{fp}\t{ln}\t{','.join(sorted(ops))}\t"
                    + ",".join(f"{k}={len(v)}" for k, v in sorted(ops.items())) + "\n")
    ops = ["SR", "CF", "BF", "MAS", "OBO"]
    with open(os.path.join(outdir, "counts.tsv"), "w", encoding="utf-8") as o:
        o.write("operator\tshape\tcandidates\tsite_operator_pairs\n")
        for op in ops:
            pairs = sum(1 for v in sites.values() if op in v)
            for shape in sorted({c.shape for c in cands if c.op == op}):
                o.write(f"{op}\t{shape}\t{sum(1 for c in cands if c.op == op and c.shape == shape)}\t-\n")
            o.write(f"{op}\tALL\t{sum(1 for c in cands if c.op == op)}\t{pairs}\n")
        o.write(f"TOTAL\tALL\t{len(cands)}\t{sum(len(v) for v in sites.values())}\n")
        o.write(f"SITES\t-\t{len(sites)}\t-\n")
    with open(os.path.join(outdir, "enumeration-meta.txt"), "w", encoding="utf-8") as o:
        for k, v in meta["hashes"].items():
            o.write(f"source {k} sha256={v}\n")
        o.write(f"ports_world_methods {' '.join(meta['ports'])}\n")
        for path, r in sorted(meta["resolved"].items()):
            o.write(f"{path} trace_accumulators {' '.join(f'{k}@{v}' for k, v in sorted(r['trace'].items()))}\n")
            o.write(f"{path} world_positions " + " ".join(f"{k}@{','.join(map(str, v))}" for k, v in sorted(r['world'].items())) + "\n")
            o.write(f"{path} names_with_disagreeing_definitions_not_used {' '.join(r['unresolved'])}\n")
        o.write(f"files_skipped_by_the_signature_reader {len(meta['skipped'])}\n")
        for s in meta["skipped"]:
            o.write(f"  {s}\n")
    print(f"{len(cands)} candidates at {len(sites)} sites")


def find(cid, root):
    cands, meta = enumerate_all(root)
    c = next((c for c in cands if c.id == cid), None)
    if c is None:
        sys.exit(f"unknown candidate {cid}")
    return c, meta


def cmd_apply(cid, root, write=True):
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    c, meta = find(cid, root)
    expected = None
    meta_path = os.path.join(here, "enumeration-meta.txt")
    if os.path.exists(meta_path):
        for l in open(meta_path, encoding="utf-8"):
            if l.startswith(f"source {c.file} sha256="):
                expected = l.strip().split("=", 1)[1]
    if expected and meta["hashes"][c.file] != expected:
        sys.exit(f"{cid}: {c.file} is not the file enumerated (sha256 differs); refused")
    path = os.path.join(root, c.file)
    src = open(path, encoding="utf-8").read()
    if src[c.start:c.end] != c.old:
        sys.exit(f"{cid}: the old text is not at its offset; refused")
    new_src = src[:c.start] + c.new + src[c.end:]
    if new_src == src:
        sys.exit(f"{cid}: a no-op; refused")
    if write:
        open(path, "w", encoding="utf-8").write(new_src)
        print(f"{cid} applied at {c.file}:{c.line} in {c.func}")
    else:
        print(f"{cid}\t{c.file}:{c.line}\t{c.func}\n--- old\n{c.old}\n+++ new\n{c.new}")


# ---------------------------------------------------------------------------------------------
# Planted cases.
# ---------------------------------------------------------------------------------------------
TOY = '''module toy

import src/core/vocab (ledger_append) import src/core/wo (advance) -- two imports on one line, as the source does

type C2LoopState = { world_state: WorldState, n: int }

-- a comment with == and && and not and true and world_state: x
func toy(st: C2LoopState, xs: [int], w2: WorldState) -> C2LoopState ! {IO} {
  let s = "a == b && ${show(1 > 2)} not true";
  let _ = emit(ev);
  let n = if st.n >= 1 && not done then 0 else st.n + 1;
  let ys = xs ++ [1, 2];
  let zs = 3 :: ys;
  let t = ledger_append(st.trace, WireRecord(e));
  let n = n + 5;
  let b = false;
  Trace.spanStart(sid);
  let w3 = advance(w9, 1);
  match xs {
    [] => { st | world_state: w2 },
    x :: rest => { st | n: x }
  }
}
'''


def cmd_selftest():
    import tempfile
    d = tempfile.mkdtemp()
    os.makedirs(os.path.join(d, "src/core"))
    open(os.path.join(d, "src/core/ports.ail"), "w").write("type Ports = {\n  clock_now: (WorldState) -> int\n}\n")
    open(os.path.join(d, "src/core/toy.ail"), "w").write(TOY)
    # `advance` defined twice with different world positions: only the import may decide
    open(os.path.join(d, "src/core/wo.ail"), "w").write(
        "export pure func advance(w: WorldState, c: int) -> WorldState { w }\n")
    open(os.path.join(d, "src/core/gen.ail"), "w").write("pure func advance(x: int) -> int { x }\n")
    open(os.path.join(d, "src/core/vocab.ail"), "w").write(
        "export pure func ledger_append(t: LedgerTrace, r: LedgerRecord) -> LedgerTrace { t }\n")
    cands, _ = enumerate_all(d, {"src/core/toy.ail": ["toy"]})
    got = {(c.op, c.shape, c.old, c.new) for c in cands}
    want = {
        ("CF", "negate", ">=", "<"), ("OBO", "boundary", ">=", ">"),
        ("OBO", "literal", "1", "2"), ("OBO", "literal", "1", "0"),
        ("BF", "connective", "&&", "||"), ("BF", "not", "not ", ""),
        ("SR", "stmt", "let _ = emit(ev);", ""),
        ("SR", "record", " ++ [1, 2]", ""),
        ("SR", "record", "1, ", ""), ("SR", "record", ", 2", ""),
        ("SR", "record", "3 :: ", ""),
        ("SR", "record", "ledger_append(st.trace, WireRecord(e))", "st.trace"),
        ("SR", "world", "w2", "st.world_state"),
        ("SR", "stmt", "let n = n + 5;", ""), ("BF", "literal", "false", "true"),
        ("SR", "stmt", "Trace.spanStart(sid);", ""), ("OBO", "literal", "5", "6"),
        ("SR", "world", "w9", "st.world_state"),
        ("MAS", "swap", "{ st | world_state: w2 },\n    x :: rest => { st | n: x }",
         "{ st | n: x },\n    x :: rest => { st | world_state: w2 }"),
    }
    ok = True
    for w in sorted(want):
        if w not in got:
            print(f"MISSING  {w}")
            ok = False
    # nothing inside the comment or the string; nothing from the `x :: rest` pattern
    for c in cands:
        line = TOY.splitlines()[c.line - 1]
        if line.strip().startswith("--") or "\"a ==" in c.old:
            print(f"TOUCHED A COMMENT OR STRING  {c.id}")
            ok = False
        if c.old.startswith("x ::"):
            print(f"TOUCHED A PATTERN  {c.id}")
            ok = False
    s_line = next(i for i, l in enumerate(TOY.splitlines(), 1) if l.strip().startswith("let s ="))
    if any(c.line == s_line and c.op != "SR" for c in cands):
        print("AN OPERATOR REACHED INTO THE STRING LINE")
        ok = False
    # `st.n + 1`: the literal is an operand of `+`; `then 0` is not an operand of anything
    zero_line = next(i for i, l in enumerate(TOY.splitlines(), 1) if "then 0 else" in l)
    zeros = [c for c in cands if c.line == zero_line and c.op == "OBO" and c.old == "0"]
    if zeros:
        print("OBO TOOK A LITERAL THAT IS NOT A BOUND")
        ok = False
    # the first `let n` binds a new name: removing it is not a statement removal
    if any(c.op == "SR" and c.shape == "stmt" and c.old.startswith("let n = if") for c in cands):
        print("A FIRST BINDING WAS OFFERED FOR REMOVAL")
        ok = False
    print(f"selftest: {len(cands)} candidates; {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["enumerate"] and len(a) == 3:
        cmd_enumerate(a[1], a[2])
    elif a[:1] == ["apply"] and len(a) == 3:
        cmd_apply(a[1], a[2])
    elif a[:1] == ["show"] and len(a) == 3:
        cmd_apply(a[1], a[2], write=False)
    elif a == ["selftest"]:
        sys.exit(cmd_selftest())
    else:
        sys.exit(__doc__)
