#!/usr/bin/env python3
"""The protected-source checker. ADR-004 v5 D5; PLAN-004 v2 §3 P1.4b.

    gen   --at <commit> --symbols <starting_set.json> [--out M] [--skip-crosscheck] [--allow-flags]
    check --manifest M --tree <dir|rev> [--json] [--pins-root DIR]
    diff  --manifest M --parent <dir|rev> --candidate <dir|rev>
    pins  --at <commit> [--pins-root DIR]
    crosscheck --at <commit> --symbols <starting_set.json>

Exit codes: 0 clean; 1 refused (check) or a pin mismatch (pins) or a failed
cross-check or a flagged unlisted callee (gen); 2 hard error (lexer, overlap, missing/duplicate symbol at gen,
usage).

`gen` reads `git show <commit>:<path>` and never the working tree. `check`
takes the decision AT C, by symbol: a protected symbol missing, duplicated,
moved to another file, or hashing differently (declaration, call site,
imports region) refuses, naming each. A new declaration between spans is
allowed unless it duplicates a protected name. `diff` only names the spans a
hunk overlaps; it decides nothing. The evaluator copies' `-- SOURCE` pins
(P1.4a) are verified against A by `pins` and their drift at C is REPORTED by
`check`, never refused (D5 "The evaluator").
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import difflib
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ailspan as S  # noqa: E402

MANIFEST_SCHEMA = "eval-protected-manifest/1"
DECL_KINDS = ("func", "func_unbraced", "type_braced", "type_unbraced", "let")
UNBRACED_KINDS = ("func_unbraced", "type_unbraced", "let")
PIN_RE = re.compile(
    rb"^-- SOURCE (\S+) L(\d+)-(\d+) B(\d+)-(\d+) sha256:([0-9a-f]{64}) symbol=(\S+)\s*$", re.M)


class HardError(Exception):
    pass


# ---------------------------------------------------------------------------
# Sources: a git revision (gen: always) or a directory (a scratch tree).
# ---------------------------------------------------------------------------

class GitSource:
    def __init__(self, rev: str, repo: str = "."):
        r = subprocess.run(["git", "-C", repo, "rev-parse", "--verify", f"{rev}^{{commit}}"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise HardError(f"not a commit: {rev}")
        self.repo, self.commit = repo, r.stdout.strip()
        self.label = self.commit

    def read(self, path: str):
        r = subprocess.run(["git", "-C", self.repo, "show", f"{self.commit}:{path}"],
                           capture_output=True)
        return r.stdout if r.returncode == 0 else None

    def ail_files(self):
        r = subprocess.run(["git", "-C", self.repo, "ls-tree", "-r", "--name-only", self.commit],
                           capture_output=True, text=True, check=True)
        return sorted(p for p in r.stdout.splitlines() if p.endswith(".ail"))


class DirSource:
    def __init__(self, root: str):
        self.root = os.path.abspath(root)
        self.commit = None
        self.label = self.root

    def read(self, path: str):
        p = os.path.join(self.root, path)
        if not os.path.isfile(p):
            return None
        with open(p, "rb") as f:
            return f.read()

    def ail_files(self):
        out = []
        for base, dirs, files in os.walk(self.root):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for fn in files:
                if fn.endswith(".ail"):
                    out.append(os.path.relpath(os.path.join(base, fn), self.root))
        return sorted(out)


def source_of(spec: str):
    return DirSource(spec) if os.path.isdir(spec) else GitSource(spec)


class Tree:
    """Parsed files of one source, cached. A lexer error is a HardError."""

    def __init__(self, src):
        self.src = src
        self._p = {}

    def parsed(self, path: str):
        if path not in self._p:
            data = self.src.read(path)
            if data is None:
                self._p[path] = None
            else:
                try:
                    self._p[path] = S.parse(data, path)
                except S.SpanError as e:
                    raise HardError(str(e))
        return self._p[path]

    def must(self, path: str):
        p = self.parsed(path)
        if p is None:
            raise HardError(f"{path}: not present in {self.src.label}")
        return p


def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


# ---------------------------------------------------------------------------
# Membership (gen): the starting set plus the type closure.
# ---------------------------------------------------------------------------

def _types_named(tree, path, span):
    """(file, type span) for each type the span names, directly or by a
    constructor, resolved in `path` or through its import statements."""
    p = tree.must(path)
    out = []

    def match(q, name):
        return [d for d in q.decls if d.kind.startswith("type") and (d.symbol == name or name in d.names)]

    def via_module(mod, name):
        if not mod.startswith("src/"):
            return []
        q = tree.parsed(mod + ".ail")
        return [(mod + ".ail", d) for d in match(q, name)] if q else []

    for name in sorted(x for x in S.idents_in(p, span) if x[:1].isupper()):
        local = [(path, d) for d in match(p, name)]
        if local:
            out += local
            continue
        for st in p.stmts:
            if name in st.names:
                out += via_module(st.module, name)
    for alias, name in sorted(S.qualified_refs(p, span)):
        for st in p.stmts:
            if st.alias == alias:
                out += via_module(st.module, name)
    return out


def _funcs_called(tree, path, span, members):
    p = tree.must(path)
    names = {x for x in S.idents_in(p, span) if x[:1].islower()}
    out = set()
    for d in p.decls:
        if d.kind.startswith("func") and d.symbol in names and d.symbol != span.symbol \
                and (path, d.symbol) not in members:
            out.add(f"{d.symbol}@{path}")
    for st in p.stmts:
        if st.module.startswith("src/"):
            for n in st.names:
                if n in names and (st.module + ".ail", n) not in members:
                    q = tree.parsed(st.module + ".ail")
                    if q and any(d.symbol == n and d.kind.startswith("func") for d in q.decls):
                        out.add(f"{n}@{st.module}.ail")
    return sorted(out)


def resolve_members(tree, symset):
    files = symset["files"]
    closure_files = set(symset.get("type_closure_files", files.keys()))
    members = {}          # (file, symbol) -> Span
    order = []
    for path, spec in files.items():
        p = tree.must(path)
        for s in spec.get("symbols", []):
            ds = p.by_name(s)
            if not ds:
                raise HardError(f"{path}: protected symbol {s} is missing")
            if len(ds) > 1:
                raise HardError(f"{path}: protected symbol {s} is declared {len(ds)} times "
                                f"(lines {', '.join(str(d.line_start) for d in ds)})")
            members[(path, s)] = ds[0]
            order.append((path, s, "starting_set"))
    not_pinned = {}
    if symset.get("type_closure"):
        work = [(k[0], v) for k, v in members.items()]
        while work:
            path, span = work.pop()
            for tpath, tspan in _types_named(tree, path, span):
                key = (tpath, tspan.symbol)
                if key in members:
                    continue
                if tpath not in closure_files:
                    not_pinned.setdefault(f"{tspan.symbol}@{tpath}", set()).add(f"{span.symbol}@{path}")
                    continue
                dup = tree.must(tpath).by_name(tspan.symbol)
                if len(dup) > 1:
                    raise HardError(f"{tpath}: protected symbol {tspan.symbol} is declared {len(dup)} times")
                members[key] = tspan
                order.append((tpath, tspan.symbol, f"type_closure:{span.symbol}"))
                work.append((tpath, tspan))
    callees, via = unlisted_closure(tree, members)
    return members, order, {k: sorted(v) for k, v in sorted(not_pinned.items())}, callees, via


def unlisted_closure(tree, members):
    """The callee report, transitive to a fixed point (P1R R2): every function
    a member calls that is not a member, then every function THOSE call, until
    nothing new is reached. Returns caller -> [callee] for every function
    walked (members and unlisted callees alike) and, per unlisted callee, the
    first caller it was reached through."""
    callees, via = {}, {}
    work = sorted((path, s, span) for (path, s), span in members.items() if span.kind.startswith("func"))
    work.reverse()
    while work:
        path, s, span = work.pop()
        c = _funcs_called(tree, path, span, members)
        if not c:
            continue
        callees[f"{s}@{path}"] = c
        for key in c:
            if key in via:
                continue
            via[key] = f"{s}@{path}"
            name, cpath = key.split("@", 1)
            ds = [d for d in tree.must(cpath).by_name(name) if d.kind.startswith("func")]
            if len(ds) == 1:
                work.append((cpath, name, ds[0]))
            else:
                raise HardError(f"{cpath}: unlisted callee {name} is declared {len(ds)} times")
    return dict(sorted(callees.items())), dict(sorted(via.items()))


def _glob_re(pattern):
    out = []
    i = 0
    while i < len(pattern):
        if pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


def path_refused_by(path, patterns):
    for pat in patterns:
        if _glob_re(pat).match(path):
            return pat
    return None


def closure_status(via, patterns):
    """Per unlisted callee: `path_refused:<pattern>`, or FLAGGED (a missing
    member by D5's definition: a candidate may edit it and no span covers it)."""
    status, flags = {}, []
    for key in sorted(via):
        pat = path_refused_by(key.split("@", 1)[1], patterns)
        status[key] = f"path_refused:{pat}" if pat else "FLAGGED"
        if not pat:
            flags.append(key)
    return status, flags


def file_spans(tree, path, decl_symbols, call_sites):
    """Every protected span of one file, at this tree: the declarations by
    symbol, the call sites, and the aggregate imports runs. Checks overlap."""
    p = tree.must(path)
    spans = [d for d in p.decls if d.symbol in decl_symbols]
    for callee in call_sites:
        spans += S.call_sites(p, callee)
    spans += p.imports
    return p, spans


def check_overlap(path, spans):
    ss = sorted(spans, key=lambda s: (s.start, s.end))
    for a, b in zip(ss, ss[1:]):
        if b.start < a.end:
            raise HardError(f"{path}: spans overlap: {a.symbol} (L{a.line_start}-{a.line_end}) "
                            f"and {b.symbol} (L{b.line_start}-{b.line_end})")


def span_record(span, src, commit, path):
    r = {"file": path, "symbol": span.symbol, "kind": span.kind,
         "sha256": span.sha256(src), "source_commit": commit,
         "lines": [span.line_start, span.line_end], "bytes": [span.start, span.end]}
    if span.kind == "imports":
        r["statements"] = [stmt_record(st, src) for st in span.statements]
    if span.names:
        r["constructors"] = span.names
    return r


def stmt_record(st, src):
    return {"module": st.module, "alias": st.alias, "names": st.names,
            "line": st.line_start, "sha256": sha(src[st.start:st.end])}


# ---------------------------------------------------------------------------
# gen
# ---------------------------------------------------------------------------

def generate(commit_spec, symset, crosscheck=True, log=sys.stderr, allow_flags=False):
    gs = GitSource(commit_spec)
    tree = Tree(gs)
    members, order, not_pinned, callees, via = resolve_members(tree, symset)
    status, flags = closure_status(via, symset.get("path_refused", []))
    files = sorted({k[0] for k in members} | set(symset["files"].keys()))
    by_file = {f: set() for f in files}
    for (f, s) in members:
        by_file[f].add(s)
    out_spans = []
    for f in files:
        calls = symset["files"].get(f, {}).get("call_sites", [])
        p, spans = file_spans(tree, f, by_file[f], calls)
        for c in calls:
            n = len([s for s in spans if s.symbol == f"{c}@call"])
            if n != 1:
                raise HardError(f"{f}: call site {c}( found {n} times, want exactly 1")
        check_overlap(f, spans)
        src = p.lx.src
        for s in sorted(spans, key=lambda s: s.start):
            rec = span_record(s, src, gs.commit, f)
            if s.kind in DECL_KINDS:
                rec["declared_in_other_protected_files"] = sorted(
                    g for g in files if g != f and tree.must(g).by_name(s.symbol))
            out_spans.append(rec)
    why = {f"{s}@{f}": w for f, s, w in order}
    for r in out_spans:
        if r["kind"] in DECL_KINDS:
            r["member_of"] = why[f"{r['symbol']}@{r['file']}"]
    # after every hard error (exit 2) and before the slow cross-check
    if flags and not allow_flags:
        raise ClosureFlagged([(k, via[k]) for k in flags])
    for k in flags:
        print(f"FLAG unlisted callee {k} (via {via[k]}): recorded in closure_flags (--allow-flags)", file=log)
    unbraced = [r for r in out_spans if r["kind"] in UNBRACED_KINDS]
    cc = {"status": "skipped", "spans": len(unbraced)}
    if crosscheck:
        cc = run_crosscheck(gs, tree, unbraced, log=log)
        if cc["failed"]:
            raise CrossCheckFailed(cc)
    return {
        "schema": MANIFEST_SCHEMA,
        "source_commit": gs.commit,
        "symbols_file_sha256": sha(json.dumps(symset, sort_keys=True).encode()),
        "protected_files": [{"file": f, "sha256": sha(tree.must(f).lx.src)} for f in files],
        "spans": out_spans,
        "crosscheck": cc,
        "named_types_not_pinned": not_pinned,
        "unlisted_callees": callees,
        "unlisted_callee_status": status,
        "closure_flags": flags,
    }


class ClosureFlagged(Exception):
    def __init__(self, flags):
        super().__init__("unlisted callees outside every path-refused file")
        self.flags = flags


class CrossCheckFailed(Exception):
    def __init__(self, cc):
        super().__init__("parser cross-check failed")
        self.cc = cc


# ---------------------------------------------------------------------------
# The parser cross-check (the non-braced heuristic against `ailang check`).
# ---------------------------------------------------------------------------

def _ailang_check(root, rel, cache_root):
    cache = tempfile.mkdtemp(prefix="cache-", dir=cache_root)
    env = dict(os.environ, AILANG_CACHE_DIR=cache)
    r = subprocess.run(["ailang", "check", "--format", "agent", rel], cwd=root, env=env,
                       capture_output=True, text=True, timeout=600)
    shutil.rmtree(cache, ignore_errors=True)
    return r.returncode, r.stdout + r.stderr


def _probe(root, module, names, tag, cache_root):
    rel = f"src/zz_eval_protected_probe/p_{tag}.ail"
    os.makedirs(os.path.join(root, os.path.dirname(rel)), exist_ok=True)
    with open(os.path.join(root, rel), "w") as f:
        f.write(f"module {rel[:-4]}\n\nimport {module} ({', '.join(names)})\n\n"
                f"export pure func zz_probe() -> int {{ 0 }}\n")
    return _ailang_check(root, rel, cache_root)


def _names_of(span):
    return [span.symbol] + list(span.names)


UNBOUND_RE = re.compile(r"undefined (?:variable|type|constructor)[^:]*: (\w+)")


def _with_export(src, p, span):
    """The file with `export ` put before this declaration's keyword line,
    if it has none (only in the scratch copy; only to probe its names)."""
    ln = span.line_start
    while p.lx.line_text(ln).startswith(b"@"):
        ln += 1
    if p.lx.line_text(ln).startswith(b"export"):
        return src, 0
    off = p.lx.line_starts[ln - 1]
    return src[:off] + b"export " + src[off:], len(b"export ")


def run_crosscheck(gs, tree, unbraced_records, log=sys.stderr, jobs=4, scratch=None,
                   span_override=None):
    """The parser cross-check of every protected non-braced span (PLAN-004
    P1.4b: the non-braced rule is a heuristic, not a parse). In a scratch copy
    of the commit's tree (`git archive`), per span:

      (1) REMOVED: the file with exactly that span removed is type-checked.
          It must either pass (nothing in the file uses the names) or fail
          with an unbound-name error naming one of THIS declaration's names
          (the type or a constructor). A parse error, or an unbound name of
          any other declaration, fails the span. (`ailang check` v0.33.0
          reports only the first error, so (1) sees one name; (2) and (3)
          cover the rest.)
      (2) MOVED: the same copy with the span re-appended at EOF must pass.
          A span that is too short leaves debris at its old place, and a span
          that is not one whole declaration does not parse at EOF.
      (3) PROBED: when (1) passes, a probe module importing each of the
          declaration's names alone must be refused (IMP010 'not exported')
          against the removed copy, after a baseline probe importing them all
          succeeds against the original (the declaration is exported in the
          copy if it was not).

    `ailang check` runs with a fresh AILANG_CACHE_DIR each time.
    `span_override` (self-test only) replaces a computed span, to show that a
    wrong span fails."""
    base = scratch or tempfile.mkdtemp(prefix="eval-protected-xc-")
    root = os.path.join(base, "tree")
    os.makedirs(root, exist_ok=True)
    arch = subprocess.run(["git", "archive", gs.commit, "src", "ailang.toml", "ailang.lock"],
                          capture_output=True, check=True)
    subprocess.run(["tar", "-x", "-C", root], input=arch.stdout, check=True)
    cache_root = os.path.join(base, "caches")
    os.makedirs(cache_root, exist_ok=True)
    results = []

    def write(path, data):
        with open(os.path.join(root, path), "wb") as f:
            f.write(data)

    try:
        for r in unbraced_records:
            path = r["file"]
            p = tree.must(path)
            orig = p.lx.src
            module = path[:-4]
            span = _find(p, r["symbol"])
            if span_override and (path, r["symbol"]) in span_override:
                span = span_override[(path, r["symbol"])](p, span)
            names = _names_of(_find(p, r["symbol"]))
            text = orig[span.start:span.end]
            cut = orig[:span.start] + orig[span.end:]
            moved = cut.rstrip(b"\n") + b"\n\n" + text + b"\n"
            steps = []
            write(path, cut)
            rc, out = _ailang_check(root, path, cache_root)
            m = UNBOUND_RE.search(out)
            if rc == 0:
                steps.append({"step": "removed", "ok": True, "detail": "passes (names unused in the file)"})
            elif m and m.group(1) in names:
                steps.append({"step": "removed", "ok": True, "detail": f"unbound {m.group(1)}"})
            else:
                steps.append({"step": "removed", "ok": False, "detail": _first_line(out)})
            write(path, moved)
            rc2, out2 = _ailang_check(root, path, cache_root)
            steps.append({"step": "moved", "ok": rc2 == 0, "detail": "" if rc2 == 0 else _first_line(out2)})
            if rc == 0:
                exp, _ = _with_export(orig, p, span)
                write(path, exp)
                rcb, outb = _probe(root, module, names, "baseline", cache_root)
                steps.append({"step": "probe-baseline", "ok": rcb == 0,
                              "detail": "" if rcb == 0 else _first_line(outb)})
                write(path, cut)
                with cf.ThreadPoolExecutor(jobs) as ex:
                    futs = {ex.submit(_probe, root, module, [n], str(i), cache_root): n
                            for i, n in enumerate(names)}
                    for fu in cf.as_completed(futs):
                        n = futs[fu]
                        rcp, outp = fu.result()
                        good = rcp != 0 and f"symbol '{n}' not exported" in outp
                        steps.append({"step": f"probe:{n}", "ok": good,
                                      "detail": "" if good else _first_line(outp)})
            write(path, orig)
            ok = all(st["ok"] for st in steps)
            steps.sort(key=lambda st: st["step"])
            results.append({"file": path, "symbol": r["symbol"], "lines": [span.line_start, span.line_end],
                            "ok": ok, "steps": steps})
            print(f"  crosscheck {path} {r['symbol']} L{span.line_start}-{span.line_end}: "
                  f"{'ok' if ok else 'FAILED'} ("
                  + ", ".join(f"{st['step']}={'ok' if st['ok'] else 'FAIL'}" for st in steps) + ")",
                  file=log)
            if not ok:
                for st in steps:
                    if not st["ok"]:
                        print(f"    {st['step']}: {st['detail']}", file=log)
    finally:
        if scratch is None:
            shutil.rmtree(base, ignore_errors=True)
    failed = [r for r in results if not r["ok"]]
    return {"status": "ok" if not failed else "failed", "spans": len(unbraced_records),
            "checked": len(results), "failed": [f"{r['symbol']}@{r['file']}" for r in failed],
            "results": results}


def _find(p, symbol):
    ds = p.by_name(symbol)
    if len(ds) != 1:
        raise HardError(f"{p.lx.path}: {symbol} declared {len(ds)} times")
    return ds[0]


def _first_line(out):
    for line in out.splitlines():
        if "ERROR" in line or "IMP" in line or "error" in line.lower():
            return line[:300]
    return out.strip().splitlines()[-1][:300] if out.strip() else ""


# ---------------------------------------------------------------------------
# check (C-side decision)
# ---------------------------------------------------------------------------

def check(manifest, tree_spec):
    tree = Tree(source_of(tree_spec))
    findings = []
    spans = manifest["spans"]
    files = [f["file"] for f in manifest["protected_files"]]
    by_file = {}
    for r in spans:
        by_file.setdefault(r["file"], []).append(r)
    all_decl_names = {r["symbol"] for r in spans if r["kind"] in DECL_KINDS}
    other_index = None

    def elsewhere(symbol, home):
        nonlocal other_index
        if other_index is None:
            other_index = {}
            for f in tree.src.ail_files():
                try:
                    q = tree.parsed(f)
                except HardError:
                    q = None  # an unrelated unparsable file is not ours to judge
                if not q:
                    continue
                for d in q.decls:
                    if d.symbol in all_decl_names:
                        other_index.setdefault(d.symbol, []).append((f, d))
        return [(f, d) for f, d in other_index.get(symbol, []) if f != home]

    for path in files:
        p = tree.parsed(path)
        recs = by_file.get(path, [])
        if p is None:
            for r in recs:
                findings.append(_finding("missing", r, f"file {path} absent"))
            continue
        src = p.lx.src
        decl_syms = {r["symbol"] for r in recs if r["kind"] in DECL_KINDS}
        callees = {r["symbol"][:-5] for r in recs if r["kind"] == "call_site"}
        _, now = file_spans(tree, path, decl_syms, callees)
        # overlap among what we can delimit (duplicates are reported, not overlaps)
        uniq = {}
        for s in now:
            uniq.setdefault(s.symbol, []).append(s)
        check_overlap(path, [v[0] for v in uniq.values()])
        for r in recs:
            got = uniq.get(r["symbol"], [])
            if r["kind"] == "imports":
                continue
            if not got:
                if r["kind"] in DECL_KINDS:
                    moved = elsewhere(r["symbol"], path)
                    if moved:
                        same = [f for f, d in moved if d.sha256(tree.must(f).lx.src) == r["sha256"]]
                        findings.append(_finding("moved", r, "now declared in " + ", ".join(
                            f"{f}:{d.line_start}" + (" (span unchanged)" if f in same else " (span changed)")
                            for f, d in moved)))
                        continue
                findings.append(_finding("missing", r, "not declared" if r["kind"] != "call_site"
                                         else "no call site"))
                continue
            if len(got) > 1:
                findings.append(_finding("duplicate", r, "declared at lines " + ", ".join(
                    str(s.line_start) for s in got)))
                continue
            h = got[0].sha256(src)
            if h != r["sha256"]:
                findings.append(_finding("changed", r, f"L{got[0].line_start}-{got[0].line_end} "
                                         f"sha256 {h[:12]} != {r['sha256'][:12]}"))
            if r["kind"] in DECL_KINDS:
                for g in files:
                    if g != path and g not in r.get("declared_in_other_protected_files", []):
                        q = tree.parsed(g)
                        if q and q.by_name(r["symbol"]):
                            findings.append(_finding("duplicate", r, f"also declared in protected file {g}"))
        # imports regions: compared as a list
        want = [r for r in recs if r["kind"] == "imports"]
        have = p.imports
        for i in range(max(len(want), len(have))):
            w = want[i] if i < len(want) else None
            h = have[i] if i < len(have) else None
            if w is None:
                findings.append({"finding": "changed", "file": path, "symbol": h.symbol, "kind": "imports",
                                 "detail": f"new imports region L{h.line_start}-{h.line_end}: "
                                           + _stmt_delta([], h, src)})
            elif h is None:
                findings.append(_finding("missing", w, "imports region gone"))
            elif h.sha256(src) != w["sha256"]:
                findings.append(_finding("changed", w, f"L{h.line_start}-{h.line_end}: "
                                         + _stmt_delta(w["statements"], h, src)))
    return findings


def _stmt_delta(want_stmts, span, src):
    have = [stmt_record(st, src) for st in span.statements]
    wh = [s["sha256"] for s in want_stmts]
    hh = [s["sha256"] for s in have]
    added = [s for s in have if s["sha256"] not in wh]
    removed = [s for s in want_stmts if s["sha256"] not in hh]
    parts = []
    for s in removed:
        parts.append(f"-import {s['module']}" + (f" as {s['alias']}" if s["alias"] else "")
                     + f" ({len(s['names'])} names, was L{s['line']})")
    for s in added:
        parts.append(f"+import {s['module']}" + (f" as {s['alias']}" if s["alias"] else "")
                     + f" ({len(s['names'])} names, L{s['line']})")
    if not parts:
        parts.append("statements unchanged; bytes between them changed")
    return "; ".join(parts)


def _finding(kind, r, detail):
    return {"finding": kind, "file": r["file"], "symbol": r["symbol"], "kind": r["kind"], "detail": detail}


# ---------------------------------------------------------------------------
# pins (P1.4a's `-- SOURCE` lines)
# ---------------------------------------------------------------------------

def read_pins(pins_root=None, pins_rev=None):
    """The `-- SOURCE` pins of every evaluator module under src/eval/, read
    from a directory (the evaluator root) or from a commit."""
    pins = []
    items = []
    if pins_rev:
        gs = GitSource(pins_rev)
        for f in gs.ail_files():
            if f.startswith("src/eval/"):
                items.append((f, gs.read(f)))
    else:
        for f in sorted(glob.glob(os.path.join(pins_root, "src/eval/**/*.ail"), recursive=True)):
            with open(f, "rb") as fh:
                items.append((os.path.relpath(f, pins_root), fh.read()))
    for rel, data in items:
        for m in PIN_RE.finditer(data):
            pins.append({"in": rel, "file": m.group(1).decode(),
                         "lines": [int(m.group(2)), int(m.group(3))],
                         "bytes": [int(m.group(4)), int(m.group(5))],
                         "sha256": m.group(6).decode(), "symbol": m.group(7).decode()})
    return pins


def verify_pins(pins, tree):
    """At the pins' own commit: the byte range hashes to the pin; the line
    range is exactly that byte range (through the last line's newline); and
    the checker's own span for the symbol is that range less its newline."""
    out = []
    for pin in pins:
        p = tree.must(pin["file"])
        src, lx = p.lx.src, p.lx
        x, y = pin["bytes"]
        a, b = pin["lines"]
        errs = []
        if sha(src[x:y]) != pin["sha256"]:
            errs.append("byte-range hash differs")
        line_end_nl = lx.line_starts[b] if b < lx.nlines else len(src)
        if lx.line_starts[a - 1] != x or line_end_nl != y:
            errs.append(f"lines L{a}-{b} are bytes {lx.line_starts[a-1]}-{line_end_nl}")
        ds = p.by_name(pin["symbol"])
        if len(ds) != 1:
            errs.append(f"symbol declared {len(ds)} times")
        elif not (ds[0].start == x and src[ds[0].end:y] in (b"\n", b"")):
            errs.append(f"checker span is bytes {ds[0].start}-{ds[0].end}")
        out.append({**pin, "ok": not errs, "errors": errs})
    return out


def pin_drift(pins, tree):
    """At C: each pinned symbol's span (+ its newline, the pin rule) hashed
    and compared. REPORTED, never refused."""
    out = []
    for pin in pins:
        try:
            p = tree.parsed(pin["file"])
        except HardError as e:
            out.append({"symbol": pin["symbol"], "file": pin["file"], "drift": f"unreadable: {e}"})
            continue
        ds = p.by_name(pin["symbol"]) if p else []
        if len(ds) != 1:
            out.append({"symbol": pin["symbol"], "file": pin["file"],
                        "drift": f"declared {len(ds)} times"})
            continue
        d = ds[0]
        end = d.end + 1 if p.lx.src[d.end:d.end + 1] == b"\n" else d.end
        h = sha(p.lx.src[d.start:end])
        if h != pin["sha256"]:
            out.append({"symbol": pin["symbol"], "file": pin["file"], "drift": "span hash differs"})
    return out


# ---------------------------------------------------------------------------
# diff (report only)
# ---------------------------------------------------------------------------

def diff_names(manifest, parent_spec, cand_spec):
    tp, tc = Tree(source_of(parent_spec)), Tree(source_of(cand_spec))
    by_file = {}
    for r in manifest["spans"]:
        by_file.setdefault(r["file"], []).append(r)
    touched = []
    for f, recs in by_file.items():
        a, b = tp.parsed(f), tc.parsed(f)
        if a is None or b is None:
            touched.append({"file": f, "spans": sorted({r["symbol"] for r in recs}), "why": "file absent"})
            continue
        dsyms = {r["symbol"] for r in recs if r["kind"] in DECL_KINDS}
        calls = {r["symbol"][:-5] for r in recs if r["kind"] == "call_site"}
        _, sa = file_spans(tp, f, dsyms, calls)
        _, sb = file_spans(tc, f, dsyms, calls)
        la = a.lx.src.split(b"\n")
        lb = b.lx.src.split(b"\n")
        names = set()
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, la, lb, autojunk=False).get_opcodes():
            if tag == "equal":
                continue
            names |= _hit(sa, i1, i2)
            names |= _hit(sb, j1, j2)
        if names:
            touched.append({"file": f, "spans": sorted(names)})
    return touched


def _hit(spans, i1, i2):
    """Spans whose (0-based) line range [ls-1, le-1] a hunk [i1, i2) overlaps;
    a pure insertion (i1 == i2) hits a span it lands strictly inside."""
    out = set()
    for s in spans:
        lo, hi = s.line_start - 1, s.line_end - 1
        if i1 == i2:
            if lo < i1 <= hi:
                out.add(s.symbol)
        elif i1 <= hi and lo <= i2 - 1:
            out.add(s.symbol)
    return out


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(prog="eval_protected", description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen")
    g.add_argument("--at", required=True)
    g.add_argument("--symbols", required=True)
    g.add_argument("--out")
    g.add_argument("--skip-crosscheck", action="store_true")
    g.add_argument("--allow-flags", action="store_true",
                   help="write the manifest although unlisted callees are flagged; each is recorded in "
                        "closure_flags and printed (for a membership ruling, never silently)")
    c = sub.add_parser("check")
    c.add_argument("--manifest", required=True)
    c.add_argument("--tree", required=True)
    c.add_argument("--json", action="store_true")
    c.add_argument("--pins-root", default=None,
                   help="evaluator root whose src/eval/**/*.ail SOURCE pins are drift-reported")
    c.add_argument("--pins-rev", default=None, help="as --pins-root, read from a commit")
    d = sub.add_parser("diff")
    d.add_argument("--manifest", required=True)
    d.add_argument("--parent", required=True)
    d.add_argument("--candidate", required=True)
    pn = sub.add_parser("pins")
    pn.add_argument("--at", required=True)
    pn.add_argument("--pins-root", default=".")
    pn.add_argument("--pins-rev", default=None, help="read the pins from this commit instead")
    x = sub.add_parser("crosscheck")
    x.add_argument("--at", required=True)
    x.add_argument("--symbols", required=True)
    args = ap.parse_args(argv)
    try:
        if args.cmd == "gen":
            with open(args.symbols) as f:
                symset = json.load(f)
            try:
                m = generate(args.at, symset, crosscheck=not args.skip_crosscheck, allow_flags=args.allow_flags)
            except CrossCheckFailed as e:
                print(json.dumps(e.cc, indent=1), file=sys.stderr)
                print("eval_protected gen: parser cross-check FAILED: " + ", ".join(e.cc["failed"]),
                      file=sys.stderr)
                return 1
            except ClosureFlagged as e:
                for key, caller in e.flags:
                    print(f"FLAG unlisted callee {key} (via {caller}): not a member, and its file is not "
                          f"path-refused (a missing member, ADR-004 v5 D5)", file=sys.stderr)
                print(f"eval_protected gen: closure not closed: {len(e.flags)} flagged callees; "
                      f"no manifest written", file=sys.stderr)
                return 1
            text = json.dumps(m, indent=1, sort_keys=False) + "\n"
            if args.out:
                with open(args.out, "w") as f:
                    f.write(text)
            else:
                sys.stdout.write(text)
            print(f"eval_protected gen: {len(m['spans'])} spans in {len(m['protected_files'])} files "
                  f"at {m['source_commit'][:12]}; crosscheck {m['crosscheck']['status']}; "
                  f"{len(m['unlisted_callee_status'])} unlisted callees, {len(m['closure_flags'])} flagged",
                  file=sys.stderr)
            return 0
        if args.cmd == "check":
            with open(args.manifest) as f:
                m = json.load(f)
            if m.get("schema") != MANIFEST_SCHEMA:
                raise HardError(f"manifest schema {m.get('schema')!r} != {MANIFEST_SCHEMA}")
            findings = check(m, args.tree)
            drift = []
            if args.pins_root or args.pins_rev:
                drift = pin_drift(read_pins(args.pins_root, args.pins_rev), Tree(source_of(args.tree)))
            if args.json:
                print(json.dumps({"refused": bool(findings), "findings": findings, "pin_drift": drift}, indent=1))
            else:
                for fd in findings:
                    print(f"REFUSED ProtectedRegionTouched {fd['finding']} {fd['file']} {fd['symbol']}: {fd['detail']}")
                for dr in drift:
                    print(f"REPORT pin drift {dr['file']} {dr['symbol']}: {dr['drift']}")
                print(f"eval_protected check: {len(m['spans'])} spans, {len(findings)} findings, "
                      f"{len(drift)} pin drift reports -> {'REFUSED' if findings else 'clean'}")
            return 1 if findings else 0
        if args.cmd == "diff":
            with open(args.manifest) as f:
                m = json.load(f)
            print(json.dumps(diff_names(m, args.parent, args.candidate), indent=1))
            return 0
        if args.cmd == "pins":
            res = verify_pins(read_pins(args.pins_root, args.pins_rev), Tree(GitSource(args.at)))
            for r in res:
                print(f"{'ok ' if r['ok'] else 'BAD'} {r['in']} {r['symbol']} {r['file']} "
                      f"L{r['lines'][0]}-{r['lines'][1]} {'; '.join(r['errors'])}")
            bad = [r for r in res if not r["ok"]]
            print(f"eval_protected pins: {len(res)} pins, {len(bad)} bad")
            return 1 if bad or not res else 0
        if args.cmd == "crosscheck":
            with open(args.symbols) as f:
                symset = json.load(f)
            m = generate(args.at, symset, crosscheck=False, allow_flags=True)
            gs = GitSource(args.at)
            cc = run_crosscheck(gs, Tree(gs), [r for r in m["spans"] if r["kind"] in UNBRACED_KINDS])
            print(json.dumps({k: v for k, v in cc.items() if k != "results"}, indent=1))
            return 0 if not cc["failed"] else 1
    except HardError as e:
        print(f"eval_protected: HARD ERROR: {e}", file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())
