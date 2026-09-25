#!/usr/bin/env python3
"""Every NEW `pure func` in src/core/ carries a contract or a checked excuse.

ADR-001 §4. Free text is what let compaction.ail's honest comments and
agents_md.ail's misleading `Z3 / SMT verification targets` banner look alike to a
reader, so a justification here is not taken on trust: for each annotated
function the checker synthesises a trivial contract (`ensures { true }`) and
confirms the verifier really does reject the function. An unchecked excuse is as
self-asserted as no excuse.

Keyed on the diff, not the tree. ~1545 `pure func` declarations predate this rule
and have no migration story; a tree-wide version would be unenforceable on day
one and therefore enforced on no one.

WHAT THIS CHECKS, PRECISELY. Not that the claimed rejection *code* is the one the
verifier returns -- codes are not available on the text path: verify.go:340-349
prints only the human message, and the `no ensures` path bypasses code generation
entirely (ADR-001 retraction 5). What it checks is the claim's substance: that the
function does not, in fact, verify. That catches the failure mode that matters --
an excuse on a function that would have verified fine -- and it reports the
verifier's actual words next to the claim so a wrong reason is visible to a reader
even when it cannot be matched mechanically.

SCOPE. A new `pure func` reachable ONLY from a `tests [...]` block is out of §4
(027's ruling of 2026-09-24). That is computed from each module's reference graph,
never read off a name, a path or a comment -- see the SCOPE section below.

Usage:  new_contract_policy.py [--base main_dst]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Under ROOT, not beside this file: `--root` points the policy at another tree,
# and `ailang verify` runs from ROOT with the probe named by its relative path.
GEN_REL = Path("tools/verify_classify/generated")

DECL_ADD_RE = re.compile(r"^\+(?:export\s+)?pure\s+func\s+(?P<name>\w+)\s*\(")
DECL_DEL_RE = re.compile(r"^-(?:export\s+)?pure\s+func\s+(?P<name>\w+)\s*\(")
HUNK_FILE_RE = re.compile(r"^\+\+\+ b/(?P<path>.+)$")
JUSTIFY_RE = re.compile(r"--\s*contracts:\s*(?P<claim>.+)$", re.M)


def added_pure_funcs(base: str) -> dict[str, list[str]]:
    """{path: [names]} for `pure func`s added under src/core/ since `base`."""
    if subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{base}^{{commit}}"],
                      capture_output=True, cwd=ROOT).returncode != 0:
        # A shallow checkout does not have the base. Fetching is the fix; failing
        # loudly is the point -- a policy that quietly passes when it cannot see
        # the diff is worse than no policy.
        subprocess.run(["git", "fetch", "--no-tags", "--depth=200", "origin",
                        base.split("/", 1)[-1]], capture_output=True, cwd=ROOT)
        if subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{base}^{{commit}}"],
                          capture_output=True, cwd=ROOT).returncode != 0:
            raise SystemExit(
                f"new_contract_policy: cannot resolve base ref {base!r}. Pass --base, or "
                f"deepen the checkout (actions/checkout needs fetch-depth: 0).")

    diff = subprocess.run(
        ["git", "diff", f"{base}...HEAD", "--unified=0", "--", "src/core"],
        capture_output=True, text=True, cwd=ROOT, check=True).stdout

    added: dict[str, list[str]] = {}
    removed: dict[str, set[str]] = {}
    path = None
    for line in diff.splitlines():
        m = HUNK_FILE_RE.match(line)
        if m:
            path = m.group("path")
            continue
        # No file is exempt by its NAME: a `_test.ail` suffix used to skip the
        # whole file, which let a production declaration out of §4 by a rename.
        # Whether a declaration is test-only is the SCOPE pass's question.
        if not (path and path.endswith(".ail")):
            continue
        m = DECL_ADD_RE.match(line)
        if m:
            added.setdefault(path, []).append(m.group("name"))
            continue
        m = DECL_DEL_RE.match(line)
        if m:
            removed.setdefault(path, set()).add(m.group("name"))

    # A declaration whose signature line was also DELETED was edited, not added:
    # bumping a literal in a one-line body (`... -> string { "11" }` to `"12"`)
    # rewrites the `pure func` line and would otherwise read as a new function.
    # The rule is about declarations that did not exist before, so those are
    # dropped. A `func` PROMOTED to `pure func` is still counted: its deleted
    # line has no `pure`, so it does not match DECL_DEL_RE, and the declaration
    # is newly subject to the rule.
    return {p: [n for n in names if n not in removed.get(p, ())]
            for p, names in added.items()
            if [n for n in names if n not in removed.get(p, ())]}


def declaration_of(text: str, name: str) -> tuple[int, int] | None:
    """(start-of-preceding-comment-block, end-of-signature-line)."""
    m = re.search(rf"^(?:export\s+)?pure\s+func\s+{re.escape(name)}\s*\(", text, re.M)
    if not m:
        return None
    start = m.start()
    # walk back over the contiguous comment block directly above
    lines = text[:start].splitlines()
    i = len(lines)
    while i > 0 and lines[i - 1].lstrip().startswith("--"):
        i -= 1
    return sum(len(l) + 1 for l in lines[:i]), text.index("\n", m.end())


def has_contract(text: str, name: str) -> bool:
    m = re.search(rf"^(?:export\s+)?pure\s+func\s+{re.escape(name)}\s*\([^)]*\)[^\n]*\n"
                  r"(?P<clauses>(?:[ \t]*(?:--[^\n]*|requires\b|ensures\b|tests\b)[^\n]*\n)*)",
                  text, re.M)
    return bool(m and re.search(r"^\s*ensures\b", m.group("clauses"), re.M))


def verifier_rejects(path: str, name: str) -> tuple[bool | None, str]:
    """Synthesise `ensures { true }` on `name` and report whether it verifies.

    Returns (True, reason) if the verifier rejects it -- the excuse stands;
    (False, _) if it VERIFIES -- the excuse is wrong; (None, detail) if the
    claim could not be checked at all, which is reported as a failure rather
    than waved through.
    """
    src_path = ROOT / path
    text = src_path.read_text()
    m = re.search(rf"^((?:export\s+)?pure\s+func\s+{re.escape(name)}\s*\([^)]*\)[^\n]*)$",
                  text, re.M)
    if not m:
        return None, "declaration not found for probing"

    sig = m.group(1)
    # The body may open on the signature line. Distinguish that trailing `{`
    # from a record return type (`-> { start: int, end: int }`) by brace balance
    # after the arrow, so the synthesised clause goes before the body, not into it.
    after = sig.split("->", 1)[-1]
    body_opens_here = sig.rstrip().endswith("{") and after.count("{") - after.count("}") == 1
    head = sig.rstrip()[:-1].rstrip() if body_opens_here else sig
    tail = "\n  {" if body_opens_here else ""

    probed = text[:m.start()] + head + "\n  ensures { true }" + tail + text[m.end():]
    stem = src_path.stem
    # THE MODULE LINE IS DERIVED FROM THE PATH, not assumed flat. `module
    # src/core/{stem}` matched nothing for a file under `src/core/ext/`, whose
    # declaration reads `module src/core/ext/exit_manifest` -- so the copy landed
    # in `generated/` still claiming the original module name and every probe
    # died on `Error MOD010: module ... doesn't match file path`. The excuse was
    # then reported as "could not be checked", which is the correct fail-closed
    # answer to a question this tool could not ask: every new `pure func` under
    # `src/core/ext/` was unjustifiable BY CONSTRUCTION, and the policy globs
    # `src/core`, which includes it.
    rel_module = src_path.relative_to(ROOT).with_suffix("").as_posix()
    # `_`-flattened so `src/core/foo.ail` and `src/core/ext/foo.ail` cannot write
    # the same probe file and silently answer for each other.
    probe_stem = rel_module.replace("/", "_")
    probed = probed.replace(f"module {rel_module}",
                            f"module tools/verify_classify/generated/{probe_stem}_policy", 1)
    gen = ROOT / GEN_REL
    gen.mkdir(parents=True, exist_ok=True)
    probe = gen / f"{probe_stem}_policy.ail"
    probe.write_text(probed)

    res = subprocess.run(
        ["ailang", "verify", str(probe.relative_to(ROOT))],
        capture_output=True, text=True, cwd=ROOT)
    probe.unlink(missing_ok=True)

    lines = (res.stdout + res.stderr).splitlines()
    for i, line in enumerate(lines):
        if re.search(rf"\b(VERIFIED|SKIPPED|ERROR)\s+{re.escape(name)}\b", line):
            if "VERIFIED" in line:
                return False, "VERIFIED"
            detail = ""
            for nxt in lines[i + 1:i + 3]:
                if "Reason:" in nxt or "error:" in nxt:
                    detail = nxt.strip()
                    break
            return True, detail or line.strip()

    head_err = next((l for l in lines if "rror" in l), "")
    return None, ("the module did not compile with a trivial contract, so the claim "
                  f"could not be checked. {head_err.strip()}")


# =============================================================================
# SCOPE -- which new declarations §4 is about at all.
#
# 027 ADR-001 §4, ANSWERED 2026-09-24 (reading 2 of
# .agent/projects/027_z3_contracts/QUESTION-2026-09-24-test-scaffolding-in-scope.md):
# a `pure func` in src/core/ reachable ONLY from a `tests [...]` block is out of
# scope. Everything else is in, unchanged.
#
# COMPUTED, NEVER ASSERTED. Of the 83 test-only declarations the ruling was
# measured on, 14 were named test_* and 4 sat under a test/ path; 79 lived in
# production files. So nothing here reads a name, a prefix, a directory or a
# comment, and there is no list to maintain: the day a fixture is called from
# production it is in scope, because the graph says so and nobody has to.
#
# THE GRAPH, per module. One node per top-level `func`. An edge A -> B whenever
# the NAME B occurs anywhere in A's text outside a comment -- body, contracts, a
# lambda inside it, a `${...}` interpolation -- APPLIED OR NOT.
#   production roots: every `export`ed declaration, anything named `main`, and
#                     the text of every other top-level item except `module` and
#                     `import` lines (types, annotations -- none can name a
#                     private function today; if one ever does, it counts).
#   test roots:       every `tests [...]` clause. It invokes the declaration that
#                     carries it, and whatever its cases mention.
# OUT of scope iff a test root reaches it and no production root does. Reached by
# neither -- dead code -- is IN: "only from tests" needs a test to reach it.
#
# WHY ONE MODULE AT A TIME IS ENOUGH. A declaration without `export` cannot be
# named outside its module (AILANG v0.33: a selective import of one is `undefined
# variable`, and `ailang run --entry` finds only exports). Every mention of a
# private declaration is therefore in its own file, and an exported one is a
# production root whoever imports it: the pass never exempts an export.
#
# INDIRECTION -- what the pass does with it:
#  * A function referenced but not applied (`caps: [ToolPolicy(allow_now)]`),
#    aliased (`let f = allow_now`), or handed to a higher-order function: the edge
#    is on the MENTION, not the call. AILANG has no reflection and no by-name
#    lookup of a private declaration, so a function value exists only where some
#    text names it, and only code holding that value can call it. If every
#    mention is in code only a test reaches, the value never exists in a
#    production run, whatever production code calls it during the test. If ANY
#    mention is in production-reachable code -- unapplied, into a list nobody
#    reads -- it is in scope. The pass does not try to see through higher-order
#    calls; it does not need to.
#  * The graph over-approximates. A local that shadows a top-level name, or a
#    record field spelled like one, still makes an edge. Every such error ADDS
#    reachability, so it can only put a declaration in scope, never take one out.
#  * String text is data; its `${...}` interpolations are code and are read as
#    code. Comments (`--` and `//`) are dropped: they do not execute.
#  * Whatever the lexer does not understand -- an unterminated string, an
#    unbalanced bracket, a top-level form it has no rule for (`instance`, `class`,
#    `test`, `property`, a top-level `let`), a `'` in code, a `tests` where no
#    clause can be -- stops the pass for that MODULE, and every new declaration in
#    it stays in scope. It fails toward requiring a contract, never toward
#    exempting.
# =============================================================================

class ScopeUnknown(Exception):
    """The module could not be read with confidence; nothing in it is exempt."""


IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
NUMBER_RE = re.compile(r"[0-9][A-Za-z0-9_]*(?:\.[0-9][A-Za-z0-9_]*)?")
MULTI_OPS = ("->", "=>", "==", "!=", "<=", ">=", "&&", "||", "::", "++", "..")
# Keywords AILANG has (`ailang prompt` lists them) that this pass has no rule
# for. Meeting one where it would be read as part of a func's header or `= expr`
# body is a ScopeUnknown: text misfiled into a test-only func is how a misread
# would exempt something.
UNRULED = {"instance", "class", "test", "property", "properties", "let", "extern",
           "deriving", "assert"}
# `module a/b/c`, and `import a/b/c` with an optional `as M` and an optional
# `(x, y as z)` list, as token shapes (I = an identifier; the keyword itself is
# not in the shape). An import can only name ANOTHER module's exports, so it
# carries no edge -- which is why its shape has to be exactly this.
SHAPES = {"module": re.compile(r"I(/I)*"),
          "import": re.compile(r"I(/I)*(asI)?(\(I(asI)?(,I(asI)?)*,?\))?")}


class _Lexer:
    """Tokens as (kind, text, line, col, depth, interp).

    `depth` counts the brackets enclosing the token (a bracket's own depth is
    that of its surroundings); `interp` marks a token inside a `${...}`, which
    is a reference and nothing else.
    """

    def __init__(self, text: str):
        self.s, self.i, self.line, self.bol = text, 0, 1, 0
        self.toks: list[tuple[str, str, int, int, int, bool]] = []

    def fail(self, why: str):
        raise ScopeUnknown(f"line {self.line}: {why}")

    def code(self, depth: int, interp: bool) -> None:
        s, stack = self.s, []
        while self.i < len(s):
            c, col = s[self.i], self.i - self.bol
            if c == "\n":
                self.i += 1
                self.line, self.bol = self.line + 1, self.i
            elif c.isspace():
                self.i += 1
            elif s.startswith(("--", "//"), self.i):
                j = s.find("\n", self.i)
                self.i = len(s) if j < 0 else j
            elif c == '"':
                self.string(depth + len(stack))
            elif c in "([{":
                self.toks.append(("open", c, self.line, col, depth + len(stack), interp))
                stack.append(c)
                self.i += 1
            elif c in ")]}":
                if not stack:
                    if interp and c == "}":
                        self.i += 1
                        return
                    self.fail(f"unbalanced {c!r}")
                if stack.pop() != "([{"[")]}".index(c)]:
                    self.fail(f"mismatched {c!r}")
                self.toks.append(("close", c, self.line, col, depth + len(stack), interp))
                self.i += 1
            elif c == "'":
                self.fail("`'` in code")
            elif m := IDENT_RE.match(s, self.i):
                self.toks.append(("id", m.group(), self.line, col, depth + len(stack), interp))
                self.i = m.end()
            elif m := NUMBER_RE.match(s, self.i):
                self.i = m.end()
            else:
                op = next((o for o in MULTI_OPS if s.startswith(o, self.i)), c)
                self.toks.append(("op", op, self.line, col, depth + len(stack), interp))
                self.i += len(op)
        if interp:
            self.fail("unterminated `${`")
        if stack:
            self.fail(f"unclosed {stack[-1]!r}")

    def string(self, depth: int) -> None:
        s = self.s
        self.i += 1
        while self.i < len(s):
            c = s[self.i]
            if c == '"':
                self.i += 1
                return
            if c == "\\":
                if s[self.i + 1:self.i + 2] == "\n":
                    self.line, self.bol = self.line + 1, self.i + 2
                self.i += 2
            elif s.startswith("${", self.i):
                self.i += 2
                self.code(depth + 1, interp=True)
            else:
                if c == "\n":
                    self.line, self.bol = self.line + 1, self.i + 1
                self.i += 1
        self.fail("unterminated string")


def _item_start(toks, k):
    """(kind, name, exported, tokens consumed) if a top-level item starts at k."""
    def text(j):
        return toks[j][1] if j < len(toks) and not toks[j][5] else None
    t = text(k)
    if t in ("module", "import"):
        return t, None, False, 1
    if t == "type":
        return "other", None, False, 1
    if toks[k][0] == "op" and t == "@":          # an annotation, `@allow_empty_ok(...)`
        return "other", None, False, 1
    exported = t == "export"
    j = k + 1 if exported else k
    if exported and text(j) == "type":
        return "other", None, False, 2
    if text(j) == "pure":
        j += 1
        if text(j) != "func":
            raise ScopeUnknown(f"line {toks[k][2]}: `pure` without `func`")
    if text(j) == "func" and j + 1 < len(toks) and toks[j + 1][0] == "id" and not toks[j + 1][5]:
        return "func", toks[j + 1][1], exported, j + 2 - k
    if exported or t == "pure":
        raise ScopeUnknown(f"line {toks[k][2]}: `{t}` starts no item this pass has a rule for")
    return None   # e.g. a lambda's `func(` inside an `= expr` body


def module_scope(text: str) -> "Scope":
    """The reference graph of one module and who reaches what. Raises ScopeUnknown."""
    lx = _Lexer(text)
    lx.code(0, interp=False)
    toks = lx.toks

    items: list[dict] = []
    cur = None
    k = 0
    while k < len(toks):
        kind, t, line, col, depth, interp = toks[k]
        if depth == 0 and not interp:
            start = _item_start(toks, k)
            if start:
                ikind, name, exported, used = start
                cur = {"kind": ikind, "name": name, "exported": exported, "line": line,
                       "refs": [], "tests": [], "body": False, "shape": ""}
                items.append(cur)
                k += used
                continue
            if cur is None:
                raise ScopeUnknown(f"line {line}: {t!r} before the first top-level item")
            if col == 0 and kind not in ("open", "close"):
                raise ScopeUnknown(f"line {line}: top-level {t!r} has no rule here")
            # Text absorbed into a `type` or an annotation is a production root,
            # so misreading it errs toward scope; `module`/`import` are shape-
            # checked below. A func is where a misread would EXEMPT something.
            if cur["kind"] == "func" and kind == "id" and t in UNRULED \
                    and not (t == "let" and cur["body"]):
                raise ScopeUnknown(f"line {line}: `{t}` outside a body has no rule here")
            if kind == "id" and t == "tests":
                nxt = toks[k + 1] if k + 1 < len(toks) else None
                if cur["kind"] != "func" or cur["body"] or not nxt or nxt[1] != "[" or nxt[4] != 0:
                    raise ScopeUnknown(f"line {line}: `tests` where no clause can be")
                j, group = k + 2, []
                while not (toks[j][0] == "close" and toks[j][4] == 0 and not toks[j][5]):
                    if toks[j][0] == "id":
                        group.append(toks[j][1])
                    j += 1
                cur["tests"].append(group)
                k = j + 1
                continue
            if kind == "op" and t == "=" and cur["kind"] == "func":
                cur["body"] = True    # `func f() -> T = expr`: no clause after this
        if kind == "id" and cur is not None:
            cur["refs"].append(t)
        if cur is not None and cur["kind"] in ("module", "import"):
            cur["shape"] += "I" if kind == "id" and t != "as" else t
        k += 1

    for it in items:
        if it["kind"] in SHAPES and not SHAPES[it["kind"]].fullmatch(it["shape"]):
            raise ScopeUnknown(f"line {it['line']}: `{it['kind']}` of a shape this pass "
                               f"has no rule for")

    funcs = [it for it in items if it["kind"] == "func"]
    names = [it["name"] for it in funcs]
    if len(set(names)) != len(names):
        dup = next(n for n in names if names.count(n) > 1)
        raise ScopeUnknown(f"`{dup}` is declared twice")
    return Scope(funcs, [it for it in items if it["kind"] == "other"])


class Scope:
    """Who reaches each top-level func: production roots, test roots, or neither."""

    def __init__(self, funcs: list[dict], others: list[dict]):
        names = {f["name"] for f in funcs}
        self.edges = {f["name"]: [r for r in f["refs"] if r in names] for f in funcs}

        # Roots as {name: the path that reaches it}, for the report.
        prod = {f["name"]: [f"export {f['name']}"] for f in funcs if f["exported"]}
        if "main" in names:
            prod.setdefault("main", ["main"])
        for o in others:
            for r in o["refs"]:
                if r in names:
                    prod.setdefault(r, [f"the top-level item at line {o['line']}", r])
        tests: dict[str, list[str]] = {}
        for f in funcs:
            for group in f["tests"]:
                tests.setdefault(f["name"], [f"tests [...] of {f['name']}"])
                for r in group:
                    if r in names:
                        tests.setdefault(r, [f"tests [...] of {f['name']}", r])
        self.prod = self._reach(prod)
        self.test = self._reach(tests)

    def _reach(self, roots: dict[str, list[str]]) -> dict[str, list[str]]:
        """{name: path from a root}, breadth-first so each path is a shortest one."""
        seen = dict(roots)
        frontier = list(roots)
        while frontier:
            nxt = []
            for a in frontier:
                for b in self.edges[a]:
                    if b not in seen:
                        seen[b] = seen[a] + [b]
                        nxt.append(b)
            frontier = nxt
        return seen

    def exempt(self, name: str) -> bool:
        return name in self.test and name not in self.prod

    def why(self, name: str) -> str:
        if name in self.prod:
            return "reachable from production: " + " -> ".join(self.prod[name])
        if name in self.test:
            return "reachable only from " + " -> ".join(self.test[name])
        return "reached by no tests block and no production root (dead code stays in scope)"


def main() -> int:
    global ROOT
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="main_dst")
    # For the self-test's scratch repositories (test_new_contract_policy.py).
    ap.add_argument("--root", type=Path, default=ROOT)
    args = ap.parse_args()
    ROOT = args.root.resolve()

    added = added_pure_funcs(args.base)
    if not added:
        print(f"new_contract_policy: no pure func added under src/core/ since {args.base}")
        return 0

    problems = []
    checked = out_of_scope = 0
    for path, names in sorted(added.items()):
        text = (ROOT / path).read_text()
        try:
            scope: Scope | None = module_scope(text)
            unknown = ""
        except ScopeUnknown as e:
            scope, unknown = None, str(e)
            print(f"  ! {path}: scope not computed ({unknown}); every new declaration "
                  f"in it stays in scope")
        for name in names:
            span = declaration_of(text, name)
            if span is None:
                continue          # added then removed again in a later commit
            checked += 1
            # Scope first, so the counts mean what they say: a test-only function
            # that carries a contract anyway is out of scope, not in and justified.
            if scope and scope.exempt(name):
                out_of_scope += 1
                anyway = " (carries a contract anyway)" if has_contract(text, name) else ""
                print(f"  ✓ {path} {name}: out of scope{anyway} -- {scope.why(name)}")
                continue
            if has_contract(text, name):
                print(f"  ✓ {path} {name}: carries a contract")
                continue
            in_scope = (f"      in scope: {scope.why(name)}" if scope else
                        f"      in scope: the module's graph was not computed ({unknown})")

            claim = JUSTIFY_RE.search(text[span[0]:span[1]])
            if not claim:
                problems.append(
                    f"  ✗ {path} {name}: new `pure func` with neither a contract nor a\n"
                    f"      `-- contracts: ...` line saying what blocks one (ADR-001 §4).\n"
                    + in_scope)
                continue

            rejects, detail = verifier_rejects(path, name)
            short = claim.group("claim").strip()
            if rejects is True:
                print(f"  ✓ {path} {name}: excuse checked -- {short}")
                print(f"      verifier: {detail}")
            elif rejects is False:
                problems.append(
                    f"  ✗ {path} {name}: claims `{short}` but with a trivial contract the\n"
                    f"      verifier returns VERIFIED. The excuse is wrong; write the contract.\n"
                    + in_scope)
            else:
                problems.append(
                    f"  ✗ {path} {name}: claims `{short}`, and the claim could not be\n"
                    f"      checked -- {detail}\n"
                    f"      An unchecked excuse is as self-asserted as no excuse (ADR-001 §4).\n"
                    + in_scope)

    scoped = (f"; {out_of_scope} more out of scope, reachable only from a tests block"
              if out_of_scope else "")
    if problems:
        print(f"new_contract_policy: {len(problems)} of {checked - out_of_scope} in-scope new "
              f"declarations unjustified{scoped}")
        print("\n".join(problems))
        return 1

    print(f"new_contract_policy: {checked - out_of_scope} in-scope new pure func declarations, "
          f"all justified{scoped}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
