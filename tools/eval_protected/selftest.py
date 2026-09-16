#!/usr/bin/env python3
"""`make eval_protected_selftest` — PLAN-004 v2 §3 P1.4b's self-test list, matrix row M7.

Every case runs the checker's CLI (`protected.py`) as a subprocess against a
MUTATED COPY of A's tree in a scratch directory, with the manifest generated
independently from the commit (`gen --at A`, which reads `git show`, never
the scratch copy and never the working tree). Each case asserts the exit code
AND the exact set of findings (finding kind, symbol), so a case that is
refused for the wrong reason fails.

    python3 tools/eval_protected/selftest.py [--at A] [--keep] [--observed-tsv PATH]
                                             [--only CASE,...] [--skip-crosscheck]

`--skip-crosscheck` is for iterating on this file only; the make target never
passes it, and without the cross-check the `crosscheck.*` cases are not run
and the self-test exits 1.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ailspan as S  # noqa: E402
import protected as P  # noqa: E402

TOOL = os.path.join(HERE, "protected.py")
SYMBOLS = os.path.join(HERE, "starting_set.json")
DEFAULT_A = "65003110ff5a15e2ae5b1f0e205e0ffa705d18dc"   # PLAN-004 P1.1's commit, the D5 basis
PORTS = "src/core/ports.ail"
STUB = "src/core/test/stub_step.ail"
SESSION = "src/core/session.ail"
CONTRACT = "src/core/tool_contract.ail"
OTHER = "src/core/dst_generator.ail"       # not a protected file
PINS_REV = "62a919d4c6c00656859558c4ad58574789625e8c"   # P1.4a's commit: digests.ail, 19 pins
PINS_REV_READER = "a225404"                              # P1.2a's commit: + reader.ail, 127 pins in all
NONBRACED_AT_A = 8                         # protected non-braced spans at A (the cross-check's population)


def run(args, **kw):
    r = subprocess.run([sys.executable, TOOL] + args, capture_output=True, text=True, **kw)
    return r.returncode, r.stdout, r.stderr


# ---------------------------------------------------------------------------
# Mutation helpers: every edit asserts its anchor, so a drifted basis fails
# loudly instead of mutating nothing.
# ---------------------------------------------------------------------------

def rd(tree, path):
    with open(os.path.join(tree, path), "rb") as f:
        return f.read()


def wr(tree, path, data):
    with open(os.path.join(tree, path), "wb") as f:
        f.write(data)


def span_of(data, path, symbol):
    ds = S.parse(data, path).by_name(symbol)
    assert len(ds) == 1, f"{symbol} declared {len(ds)} times in {path}"
    return ds[0]


def replace_once(data, old, new, lo=0, hi=None):
    hi = len(data) if hi is None else hi
    seg = data[lo:hi]
    assert seg.count(old) >= 1, f"anchor {old!r} not found"
    i = lo + seg.index(old)
    return data[:i] + new + data[i + len(old):]


def edit(tree, path, fn):
    wr(tree, path, fn(rd(tree, path)))


def in_span(path, symbol, old, new):
    def fn(data):
        s = span_of(data, path, symbol)
        return replace_once(data, old, new, s.start, s.end)
    return fn


def cut_span(data, path, symbol):
    s = span_of(data, path, symbol)
    end = s.end + 1 if data[s.end:s.end + 1] == b"\n" else s.end
    return data[:s.start] + data[end:], data[s.start:s.end]


def append(data, text):
    return data.rstrip(b"\n") + b"\n\n" + text + b"\n"


def line_bounds(data, line):
    starts = [0] + [i + 1 for i, b in enumerate(data) if b == 10]
    return starts[line - 1], starts[line] - 1


# ---------------------------------------------------------------------------
# The cases. Each: (id, description, mutate(tree), expect_exit, expect_findings)
# expect_findings: set of (finding, symbol) for exit 1; None when not compared.
# ---------------------------------------------------------------------------

def m_ws_literal(t):
    # whitespace inside a projection string literal of the tool codec
    edit(t, PORTS, in_span(PORTS, "encode_tool_outcome", b'js("completed")', b'js("completed ")'))


def m_ws_doubled(t):
    # an existing space doubled inside a codec literal: invisible to any
    # whitespace-collapsing hash (tools/predicate-anchors/check.py's normalize)
    edit(t, PORTS, in_span(PORTS, "decode_tool_outcome", b'"the payload is not JSON"',
                           b'"the payload is  not JSON"'))


def m_token(t):
    edit(t, PORTS, in_span(PORTS, "tool_outcome_record",
                           b"status: OutcomeFault, fault_class_id: fault_class_tool_failed()",
                           b"status: OutcomeOk, fault_class_id: fault_class_tool_failed()"))


def m_import_paren_add(t):
    # a name added inside the multi-line `import src/core/ports ( … )`
    edit(t, STUB, lambda d: replace_once(d, b"  ScriptedStep, empty_world_state, ports_shape_probe, virtual_clock,",
                                         b"  ScriptedStep, empty_world_state, ports_shape_probe, virtual_clock, scripted_file,"))


def m_import_joined(t):
    # a second import statement joined onto an existing import line
    edit(t, PORTS, lambda d: replace_once(d, b"import std/result (Result)\n",
                                          b"import std/result (Result) import std/math (abs)\n"))


def m_alias(t):
    edit(t, PORTS, lambda d: replace_once(d, b"import std/list as List (length, sortBy, dedup)",
                                          b"import std/list as L (length, sortBy, dedup)"))


def m_comment_in_span(t):
    edit(t, PORTS, in_span(PORTS, "recording_tool", b"{\n", b"{\n  -- a comment inside the span\n"))


def m_unbraced_last_line(t):
    def fn(d):
        s = span_of(d, PORTS, "ToolOutcome")
        assert s.kind == "type_unbraced" and s.line_end > s.line_start
        a, b = line_bounds(d, s.line_end)
        return replace_once(d, b"timeout_ms: int", b"timeout_ms: int, retry: int", a, b)
    edit(t, PORTS, fn)


def m_deriving(t):
    def fn(d):
        # anchored on the declaration's start, not on the checker's span end,
        # so a span that stopped before `deriving` shows as an ALLOWED case
        s = span_of(d, CONTRACT, "ToolCallEnvelope")
        return replace_once(d, b"  deriving (Eq)", b"  deriving (Eq, Ord)", s.start, s.start + 200)
    edit(t, CONTRACT, fn)


def m_moved_other_file(t):
    d, text = cut_span(rd(t, PORTS), PORTS, "scripted_step_faults")
    wr(t, PORTS, d)
    edit(t, OTHER, lambda o: append(o, text))


def m_renamed(t):
    edit(t, PORTS, in_span(PORTS, "recording_tool", b"func recording_tool(", b"func recording_tool_renamed("))


def m_renamed_readded(t):
    d = rd(t, PORTS)
    text = d[span_of(d, PORTS, "recording_tool").start:span_of(d, PORTS, "recording_tool").end]
    d = in_span(PORTS, "recording_tool", b"func recording_tool(", b"func recording_tool_renamed(")(d)
    wr(t, PORTS, append(d, text))


def m_moved_within(t):
    d, text = cut_span(rd(t, PORTS), PORTS, "tool_outcome_record")
    wr(t, PORTS, append(d, text))


def m_outside(t):
    # a non-member function of a protected file, and the comments between spans
    def fn(d):
        s = span_of(d, PORTS, "generated_provider_entry")
        d = replace_once(d, b"{\n", b"{\n  -- an edit outside every protected span\n", s.start, s.end)
        return replace_once(d, b"-- WI-D1: the PROVIDER fault, projected the two ways",
                            b"-- WI-D1 (edited): the PROVIDER fault, projected the two ways")
    edit(t, PORTS, fn)


def m_interp_brace(t):
    # `${` inside a string holding `}` and `{`, in a NEW declaration between two spans
    def fn(d):
        s = span_of(d, PORTS, "tool_outcome_record")
        new = (b'\nexport pure func zz_interp_brace(a: string) -> string {\n'
               b'  "open ${ if a == "}" then "{" else "}" } close \\${ not } \\" q"\n}\n')
        return d[:s.end + 1] + new + d[s.end + 1:]
    edit(t, PORTS, fn)


def m_new_decl_dup_name(t):
    # a new declaration elsewhere in the file that duplicates a protected name
    edit(t, PORTS, lambda d: append(d, b"export pure func tool_calls_json(x: int) -> int { x }"))


def m_dup_in_other_protected(t):
    edit(t, SESSION, lambda d: append(d, b"pure func bool_field(x: int) -> int { x }"))


def m_unterminated(t):
    edit(t, PORTS, lambda d: append(d, b'export pure func zz_bad() -> string { "never closed }'))


def m_unbalanced(t):
    edit(t, PORTS, lambda d: append(d, b"export pure func zz_bad() -> int { (1 + 2 }"))


def m_call_site(t):
    edit(t, SESSION, lambda d: replace_once(d, b"let exchange = dispatch_step(st.provider,",
                                            b"let exchange = dispatch_step(st.provider ,"))


def m_call_site_twice(t):
    edit(t, SESSION, lambda d: append(
        d, b"func zz_second_call(st: int) -> int {\n  let e = dispatch_step(st);\n  e\n}"))


def m_pin_drift(t):
    edit(t, "src/core/phase_vocab.ail", in_span("src/core/phase_vocab.ail", "frame", b"(", b"( "))


CHECK_CASES = [
    ("clean", "A's own tree", lambda t: None, 0, set()),
    ("ws_in_literal", "whitespace inside a projection string literal", m_ws_literal, 1,
     {("changed", "encode_tool_outcome")}),
    ("ws_doubled_in_literal", "an existing space doubled inside a codec string literal", m_ws_doubled, 1,
     {("changed", "decode_tool_outcome")}),
    ("token_tool_outcome_record", "one token in tool_outcome_record", m_token, 1,
     {("changed", "tool_outcome_record")}),
    ("import_paren_name", "a name added inside a multi-line import's parentheses", m_import_paren_add, 1,
     {("changed", "<imports:1>")}),
    ("import_joined", "a second import joined onto an import line", m_import_joined, 1,
     {("changed", "<imports:1>")}),
    ("import_alias", "an `as` alias changed", m_alias, 1, {("changed", "<imports:1>")}),
    ("comment_in_span", "a comment inside a span", m_comment_in_span, 1, {("changed", "recording_tool")}),
    ("unbraced_last_line", "a multi-line non-braced type changed on its last line", m_unbraced_last_line, 1,
     {("changed", "ToolOutcome")}),
    ("deriving", "a deriving clause changed", m_deriving, 1, {("changed", "ToolCallEnvelope")}),
    ("moved_other_file", "a protected function moved to another file", m_moved_other_file, 1,
     {("moved", "scripted_step_faults")}),
    ("renamed_missing", "a protected function renamed", m_renamed, 1, {("missing", "recording_tool")}),
    ("renamed_readded", "renamed, and re-added under its name elsewhere in the file (moved within file)",
     m_renamed_readded, 0, set()),
    ("moved_within_file", "a protected function moved within its file", m_moved_within, 0, set()),
    ("outside_every_span", "a change outside every span (not detected, by design)", m_outside, 0, set()),
    ("interp_brace", "`${` inside a string containing `}` (spans unchanged; a new declaration between spans)",
     m_interp_brace, 0, set()),
    ("new_decl_dup_name", "a new declaration duplicating a protected name", m_new_decl_dup_name, 1,
     {("duplicate", "tool_calls_json")}),
    ("dup_in_other_protected_file", "a protected name declared in another protected file",
     m_dup_in_other_protected, 1, {("duplicate", "bool_field")}),
    ("call_site_changed", "the dispatch_step call site changed", m_call_site, 1,
     {("changed", "dispatch_step@call")}),
    ("call_site_duplicated", "a second dispatch_step call site", m_call_site_twice, 1,
     {("duplicate", "dispatch_step@call")}),
    ("unterminated_string", "an unterminated string literal", m_unterminated, 2, None),
    ("unbalanced_paren", "an unbalanced parenthesis", m_unbalanced, 2, None),
    ("pin_drift_reported", "a pinned copy's source changed: drift reported, not refused", m_pin_drift, 0, set()),
]

# per-case extra assertions on the check's JSON / stderr
EXTRA = {
    "import_paren_name": lambda rep, err: _detail_has(rep, "<imports:1>", "+import src/core/ports")
    and _detail_has(rep, "<imports:1>", "-import src/core/ports"),
    "import_joined": lambda rep, err: _detail_has(rep, "<imports:1>", "+import std/math"),
    "import_alias": lambda rep, err: _detail_has(rep, "<imports:1>", "+import std/list as L "),
    "moved_other_file": lambda rep, err: _detail_has(rep, "scripted_step_faults", OTHER)
    and _detail_has(rep, "scripted_step_faults", "span unchanged"),
    "unterminated_string": lambda rep, err: "unterminated string literal" in err and PORTS in err,
    "unbalanced_paren": lambda rep, err: ("mismatched" in err or "unbalanced" in err) and PORTS in err,
    "pin_drift_reported": lambda rep, err: [d["symbol"] for d in rep["pin_drift"]] == ["frame"],
}


def _detail_has(rep, symbol, text):
    return any(f["symbol"] == symbol and text in f["detail"] for f in rep["findings"])


# ---------------------------------------------------------------------------

class Runner:
    def __init__(self, scratch, at, manifest_path):
        self.scratch, self.at, self.m = scratch, at, manifest_path
        self.rows = []
        self.failures = []

    def record(self, cid, desc, ok, observed_verdict, observed_first, detail=""):
        self.rows.append((cid, desc, ok, observed_verdict, observed_first))
        mark = "ok  " if ok else "FAIL"
        print(f"  {mark} M7.{cid}: {desc} -> {observed_verdict} {observed_first}"
              + (f"\n       {detail}" if detail and not ok else ""))
        if not ok:
            self.failures.append(cid)


def verdict_of(code):
    return {0: "allowed", 1: "refused", 2: "hard_error"}.get(code, f"exit{code}")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--at", default=DEFAULT_A)
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--observed-tsv")
    ap.add_argument("--skip-crosscheck", action="store_true")
    args = ap.parse_args(argv)
    only = set(filter(None, args.only.split(",")))
    t0 = time.time()
    scratch = tempfile.mkdtemp(prefix="eval-protected-selftest-")
    os.environ.setdefault("TMPDIR", scratch)
    print(f"eval_protected selftest: A={args.at[:12]} scratch={scratch}")
    manifest = os.path.join(scratch, "manifest.json")
    try:
        # 1. the independent manifest, from the commit
        gen_args = ["gen", "--at", args.at, "--symbols", SYMBOLS, "--out", manifest]
        if args.skip_crosscheck:
            gen_args.append("--skip-crosscheck")
        rc, out, err = run(gen_args)
        sys.stdout.write(err)
        if rc != 0:
            print(f"FAIL: gen exited {rc}")
            return 1
        with open(manifest) as f:
            m = json.load(f)
        R = Runner(scratch, args.at, manifest)

        # 2. the pristine copy of A's tree
        pristine = os.path.join(scratch, "pristine")
        os.makedirs(pristine)
        arch = subprocess.run(["git", "archive", args.at, "src"], capture_output=True, check=True)
        subprocess.run(["tar", "-x", "-C", pristine], input=arch.stdout, check=True)

        # 3. check-side cases
        for cid, desc, mut, want_rc, want in CHECK_CASES:
            if only and cid not in only:
                continue
            tree = os.path.join(scratch, "case-" + cid)
            shutil.copytree(pristine, tree)
            mut(tree)
            rc, out, err = run(["check", "--manifest", manifest, "--tree", tree, "--json",
                                "--pins-rev", PINS_REV])
            rep = json.loads(out) if rc in (0, 1) and out.strip() else {"findings": [], "pin_drift": []}
            got = {(f["finding"], f["symbol"]) for f in rep["findings"]}
            ok = rc == want_rc and (want is None or got == want)
            extra = EXTRA.get(cid)
            if ok and extra:
                ok = bool(extra(rep, err))
            first = (f"{rep['findings'][0]['finding']}:{rep['findings'][0]['symbol']}"
                     if rep["findings"] else ("-" if rc != 2 else "SpanError"))
            R.record(cid, desc, ok, verdict_of(rc), first,
                     detail=f"exit {rc} (want {want_rc}); findings {sorted(got)} (want {want}); {err.strip()[:300]}")
            if not args.keep:
                shutil.rmtree(tree)

        # 4. diff names spans and decides nothing
        if not only or "diff_names_only" in only:
            tree = os.path.join(scratch, "case-diff")
            shutil.copytree(pristine, tree)
            m_ws_literal(tree)
            m_outside(tree)
            rc, out, err = run(["diff", "--manifest", manifest, "--parent", pristine, "--candidate", tree])
            touched = json.loads(out) if rc == 0 else []
            ok = rc == 0 and touched == [{"file": PORTS, "spans": ["encode_tool_outcome"]}]
            R.record("diff_names_only", "diff names the spans a hunk overlaps, exit 0", ok, verdict_of(rc),
                     ",".join(s for t in touched for s in t["spans"]) or "-", detail=out[:300] + err[:300])
            shutil.rmtree(tree)

        # 5. gen-side hard errors (exit 2)
        def gen_case(cid, desc, symset, repo=None, needle=""):
            if only and cid not in only:
                return
            sp = os.path.join(scratch, cid + ".json")
            with open(sp, "w") as f:
                json.dump(symset, f)
            cmd = [sys.executable, TOOL, "gen", "--at", "HEAD" if repo else args.at, "--symbols", sp,
                   "--skip-crosscheck"]
            r = subprocess.run(cmd, capture_output=True, text=True, cwd=repo or os.getcwd())
            ok = r.returncode == 2 and needle in r.stderr
            R.record(cid, desc, ok, verdict_of(r.returncode), needle,
                     detail=f"exit {r.returncode}; {r.stderr.strip()[:300]}")

        gen_case("gen_missing_symbol", "gen: a missing symbol",
                 {"files": {PORTS: {"symbols": ["recording_tool", "zz_no_such_symbol"]}}},
                 needle="protected symbol zz_no_such_symbol is missing")
        gen_case("gen_overlap", "gen: two protected spans overlap (a call site inside a protected declaration)",
                 {"files": {PORTS: {"symbols": ["recording_tool"], "call_sites": ["world_tool"]}}},
                 needle="spans overlap")
        if not only or "gen_duplicate_symbol" in only:
            repo = os.path.join(scratch, "dup-repo")
            shutil.copytree(pristine, os.path.join(repo))
            edit(repo, PORTS, lambda d: append(d, d[span_of(d, PORTS, "recording_tool").start:
                                                   span_of(d, PORTS, "recording_tool").end]))
            git = ["git", "-c", "user.name=selftest", "-c", "user.email=selftest@invalid", "-C", repo]
            subprocess.run(git + ["init", "-q"], check=True)
            subprocess.run(git + ["add", "-A"], check=True)
            subprocess.run(git + ["commit", "-q", "-m", "duplicate"], check=True)
            gen_case("gen_duplicate_symbol", "gen: a duplicate symbol",
                     {"files": {PORTS: {"symbols": ["recording_tool"]}}}, repo=repo,
                     needle="protected symbol recording_tool is declared 2 times")
            shutil.rmtree(repo)

        # overlap of two different DECLARATIONS: the parser cannot produce one
        # (each declaration ends before the next column-0 start), so the guard
        # is exercised directly on two synthetic declaration spans.
        if not only or "overlap_two_declarations" in only:
            a = S.Span(PORTS, "x", "func", 0, 10, 1, 2)
            b = S.Span(PORTS, "y", "type_unbraced", 5, 20, 2, 3)
            try:
                P.check_overlap(PORTS, [a, b])
                ok = False
            except P.HardError as e:
                ok = "spans overlap: x" in str(e)
            # and through the CLI's exit path: a HardError is exit 2
            R.record("overlap_two_declarations", "overlap of two different declarations (guard, direct)",
                     ok, "hard_error" if ok else "none", "spans overlap")

        # 6. the parser cross-check on every non-braced span
        if not only or any(c.startswith("crosscheck") for c in only):
            cc = m["crosscheck"]
            if args.skip_crosscheck:
                R.record("crosscheck_every_nonbraced_span", "parser cross-check (SKIPPED by flag)", False,
                         "skipped", "-")
            else:
                n_unbraced = sum(1 for s in m["spans"] if s["kind"] in P.UNBRACED_KINDS)
                ok = (cc["status"] == "ok" and cc["checked"] == n_unbraced == NONBRACED_AT_A
                      and not cc["failed"])
                R.record("crosscheck_every_nonbraced_span",
                         f"parser cross-check on every non-braced span ({cc['checked']}/{n_unbraced})",
                         ok, "pass" if ok else "fail", "-")
                # a wrong span fails it: ToolOutcome's span shortened by one line
                gs = P.GitSource(args.at)
                tree = P.Tree(gs)

                def shorten(p, span):
                    last = span.line_end - 1
                    return S.Span(span.file, span.symbol, span.kind, span.start, p.lx.line_end(last),
                                  span.line_start, last, names=span.names)
                rec = [s for s in m["spans"] if s["symbol"] == "ToolOutcome"]
                bad = P.run_crosscheck(gs, tree, rec, log=sys.stdout,
                                       span_override={(PORTS, "ToolOutcome"): shorten})
                ok = bad["failed"] == [f"ToolOutcome@{PORTS}"]
                R.record("crosscheck_detects_short_span", "cross-check fails a span one line short",
                         ok, "fail" if ok else "pass", "crosscheck:ToolOutcome")

        # 7. the P1.4a pins, against A, and a corrupted pin
        if not only or "pins" in only:
            rc, out, err = run(["pins", "--at", args.at, "--pins-rev", PINS_REV])
            n = sum(1 for line in out.splitlines() if line.startswith("ok "))
            ok = rc == 0 and n == 19
            R.record("pins_at_a", f"the 19 P1.4a SOURCE pins verify against A ({n} ok)", ok, verdict_of(rc), "-",
                     detail=out[-400:])
            rc, out, err = run(["pins", "--at", args.at, "--pins-rev", PINS_REV_READER])
            n = sum(1 for line in out.splitlines() if line.startswith("ok "))
            ok = rc == 0 and n == 127
            R.record("pins_at_a_with_reader", f"P1.4a's and P1.2a's 127 SOURCE pins verify against A ({n} ok)",
                     ok, verdict_of(rc), "-", detail=out[-400:])
            root = os.path.join(scratch, "pins-bad")
            os.makedirs(os.path.join(root, "src/eval/journal"))
            d = P.GitSource(PINS_REV).read("src/eval/journal/digests.ail")
            i = d.index(b"sha256:") + len(b"sha256:")
            d = d[:i] + (b"0" if d[i:i + 1] != b"0" else b"1") + d[i + 1:]
            with open(os.path.join(root, "src/eval/journal/digests.ail"), "wb") as f:
                f.write(d)
            rc, out, err = run(["pins", "--at", args.at, "--pins-root", root])
            ok = rc == 1 and "18 ok" not in out and out.count("BAD") == 1
            R.record("pins_corrupted", "one corrupted pin is reported", ok, verdict_of(rc), "BAD", detail=out[-400:])

        print(f"eval_protected selftest: {len(R.rows) - len(R.failures)}/{len(R.rows)} cases ok "
              f"in {time.time() - t0:.0f}s")
        if args.observed_tsv:
            with open(args.observed_tsv, "w") as f:
                f.write("case_id\ttest_name\tobserved_verdict\tobserved_first_finding\tobserved_position\n")
                for cid, desc, ok, v, first in R.rows:
                    f.write(f"M7.{cid}\ttools/eval_protected/selftest.py:{cid}\t{v}\t{first}\taggregate:protected\n")
        if R.failures:
            print("FAILED: " + ", ".join(R.failures))
            return 1
        return 0
    finally:
        if not args.keep:
            shutil.rmtree(scratch, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
