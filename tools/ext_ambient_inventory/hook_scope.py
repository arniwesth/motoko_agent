#!/usr/bin/env python3
"""Classifier 3, HOOK SCOPE -- the sharpened unit WI-D15 measured.

WHAT THIS IS, AND WHY IT IS A SECOND ANSWER RATHER THAN A REPLACEMENT
---------------------------------------------------------------------
ADR-001 D5 (`ADR:1295-1300`) quantifies criterion 2 over HOOKS: "every hook
reachable within that profile is either ... effectful only through D1
world-mediated ports".  Amendment A's property 2 (`ADR:1484-1490`) opens with
the same quantifier -- "Criterion 2 quantifies over every hook an installed
extension registers" -- and then picks the extension's transitive module CLOSURE
as the unit that makes the measurement total over hooks.  The closure is a sound
OVER-approximation of hook reachability, not an enlargement of the quantifier,
and the ADR already labels it as such at the yield paragraph: "The coarsening is
*conservative*, so it is the right direction, but it caps the instrument's reach
at four extensions."

So `register.ail`'s `std/env` and `std/fs` are inside the UNIT and outside the
SCOPE.  This module measures the scope: what an extension's eight hook bindings
can actually reach.  It does NOT change `derive.py`'s shipped verdict, because
what a profile may record on is an ADR-scope question and this is an instrument.

THE FILE IS NOT THE SPLIT, AND MICRORAG IS THE PROOF
-----------------------------------------------------
The obvious sharpening -- drop `register.ail` from the closure -- is FAIL-OPEN
and this tree contains the counterexample.  `motoko-ext-microrag/register.ail`
holds `microrag_tool_handle`, which is BOUND TO `on_tool_handle` and reaches
`std/fs.writeFile` and `std/process.exec` through `auto_write_with_microrag`.
Dropping the file clears microrag of two ambient sources a hook really reaches.
`register.ail` is not "the registration module".  Measured over the fifteen:
NINE hold the `ExtensionHooks` record itself, so every inline hook body lives
there, and SIX go further and declare named top-level hook functions in it.
Dropping the file drops hook-reachable text for nine of fifteen extensions.

The split is therefore REACHABILITY-granular, computed from the eight bindings
outward, and every step it cannot resolve is a rejection.

THE DOORS, ENUMERATED BEFORE THE UNIT WAS CHOSEN (plan rule S16, as WI-D12
extended it).  An effect reaches a hook by exactly these routes:

  1. an effect-bearing `std/*` symbol applied in text the binding reaches;
  2. a `_`-prefixed compiler builtin applied there -- WI-D12's door, which needs
     no import;
  3. a NON-underscore language builtin applied there -- `show` is one, it is
     applied in six of the fifteen closures, and NO producer at HEAD carries a
     row for it.  This door is NEW at WI-D15 and `derive.py` does not watch it;
     see `unknown-callee` below;
  4. a call site inside a STRING INTERPOLATION.  `strip_noise` blanks string
     literals to keep prose out of the scan, and `"${show(n)}"` goes with them.
     Measured over the fifteen closures: 10 builtin calls and 2 effectful std
     symbol calls live only inside interpolations.  None changes `derive.py`'s
     import-granular verdict -- but this module is CALL-granular, so for it the
     lid is a fail-open.  `keep_interpolations` below is the fix;
  5. a hook bound to something this tool cannot resolve to text -- a computed
     expression, a threaded value, an unresolvable delegation.  A rejection;
  6. an effect performed at REGISTRATION whose result a hook closes over.  This
     is out of criterion 2's scope by the reading above and it is NOT harmless:
     it is reported separately as `registration_only`, and what accounts for it
     is D5's disclosure obligation, not this instrument.

Verdicts: HOOK-PORT-MEDIATED | HOOK-AMBIENT | HOOK-UNRESOLVED.  As in the parent
tool, unresolved is a rejection and never a pass, and a green answer can never be
produced by resolving nothing: the binding tiling is asserted before the walk.
"""

from __future__ import annotations

import re
from pathlib import Path

IDENT = r"[A-Za-z_][A-Za-z0-9_]*"

#: The eight ABI slots.  Held here rather than derived so that a slot added to
#: the ABI makes this tool FAIL (tiling assertion) rather than silently scan
#: seven -- the shape ADR:1317-1337 records as having already cost this project
#: one correction ("when a count and an enumeration disagree by one, the
#: enumeration is the claim").
SLOTS = (
    "on_describe_tools", "on_build_system_prompt", "on_budget_plan", "on_pre_step",
    "on_tool_policy", "on_tool_handle", "on_response_intercept", "on_solver_candidate",
)

REGISTER_FUNC = "register_with_config"

#: The ABI's neutral record (`packages/motoko-ext-abi/types.ail`, ADR-001 §1).
#: A registration written as `{ default_hooks(id) | on_x: f }` binds the seven
#: un-overridden slots to THIS function's literal, so it is the second place
#: hook-reachable text can live.  It is resolved through the closure first
#: (the real tree imports it) and through `ABI_TYPES` second (the fixture
#: suite's closure is one file); any OTHER update base is a rejection.
DEFAULT_HOOKS = "default_hooks"
ABI_TYPES = Path("packages/motoko-ext-abi/types.ail")

#: THE 6.0 REGISTRATION SHAPE (ADR-001 Phase B, B2): `register_with_config`
#: returns a LITERAL LIST of capability-constructor applications,
#: `[Kind(arg, ...), ...]`, and every function-typed argument is a hook binding.
#: `kind -> (arity, function-typed argument positions)`, from the type-checked
#: `Capability` sketch (answer …9903186 / tmp/017-capability/capability.ail).
#: Held here rather than derived so that a variant added to the ABI makes this
#: tool FAIL on it (`capability-list-unresolvable`) rather than silently skip
#: the atom -- the same discipline as `SLOTS` above.  "Literal lists only": a
#: list built by an expression is a rejection, and B8 makes that an ABI rule.
CAPABILITY_KINDS: dict[str, tuple[int, tuple[int, ...]]] = {
    "DescribeTools": (1, (0,)),
    "PromptShaper": (1, (0,)),
    "BudgetShaper": (1, (0,)),
    "Compactor": (1, (0,)),
    "ToolPolicy": (1, (0,)),
    "ToolProvider": (2, (1,)),          # (names, handle); names is data, not a binding
    "ResponseInterceptor": (1, (0,)),
    "SolverJudge": (1, (0,)),
}

#: Rejection shapes this module adds to the parent's five.  Each is a REJECTION.
HOOK_SHAPES = {
    "hook-record-unresolvable": "`register_with_config`'s tail expression is neither an "
                                "ExtensionHooks record literal, nor a record UPDATE of the "
                                "ABI's `default_hooks(id)`, nor a resolvable call that "
                                "returns one, so the eight bindings cannot be located at all. "
                                "An update whose base is anything but `default_hooks` -- a "
                                "computed base, a local builder -- is this rejection too: the "
                                "un-overridden slots would be bound to text this tool has not "
                                "read, which is fail-open",
    "capability-list-unresolvable": "`register_with_config`'s tail is a LIST (the 6.0 "
                                    "`[Capability]` shape) that this tool cannot enumerate atom "
                                    "by atom: an element that is not `Kind(arg, ...)` for a known "
                                    "capability constructor, a computed or spread element, a wrong "
                                    "arity, a list built by an expression (`xs ++ ys`, a "
                                    "conditional), or an element count that does not match the "
                                    "atoms emitted. Over a list there is no tiling to assert, so "
                                    "the fail-closed denominator is the element count, and an "
                                    "atom this tool did not read is an atom nothing scanned",
    "hook-slot-missing": "the resolved record literal does not bind all eight ABI slots. "
                         "The bindings must TILE the record: a slot this tool cannot see "
                         "is a slot it cannot scan, and scanning seven of eight silently "
                         "is the failure the assertion exists to prevent",
    "hook-binding-unresolvable": "a slot is bound to an expression this tool cannot resolve "
                                 "to reachable text -- a computed expression, a value threaded "
                                 "through a parameter, or a delegation past the hop limit",
    "unknown-callee": "an identifier is APPLIED in hook-reachable text and resolves to no "
                      "declaration in the closure, no import, and no builtin with producer "
                      "evidence. `show` is the live instance: it is a language builtin, it "
                      "needs no import, and every `show(` in the stdlib corpus is inside a "
                      "COMMENT -- so no cached row anywhere carries evidence for it",
    "applied-local": "an identifier bound as a local or a parameter is APPLIED in "
                     "hook-reachable text. A local can hold a function value, so its effects "
                     "are whatever the caller passed. Classifier 2's discipline: an "
                     "unresolvable receiver is a rejection, not a pass",
}

MAX_DELEGATION_HOPS = 4

_DECL = re.compile(rf"^\s*(?:export\s+)?(?:pure\s+)?func\s+({IDENT})", re.M)
_TYPE = re.compile(rf"^\s*(?:export\s+)?type\s+({IDENT})", re.M)
_APPLY = re.compile(rf"\b({IDENT})\s*\(")
_RENAME = re.compile(rf"\b({IDENT})\s+as\s+({IDENT})\b")
#: `let x = e` and `let x: T = e` both bind `x`.  The annotated form is not
#: exotic -- `motoko_scratchpad/scratchpad.ail:100` writes the whole hook type
#: out before the `=` -- and an unannotated-only reader loses the binding, then
#: rejects a slot bound to it as unresolvable.  The annotation is skipped by
#: balancing, because it contains `->`, `!` and a brace-delimited effect row.
_LET = re.compile(rf"\blet\s+({IDENT})\s*(?::|=)")
_BUILTIN = re.compile(rf"\b(_[a-z][A-Za-z0-9_]*)\s*\(")

#: Applied names that are syntax, not callees.  Kept short and explicit: every
#: name here is one this tool declines to resolve, so the list is the honest
#: statement of what it is not checking.
_SYNTAX = frozenset({"func", "if", "match", "then", "else", "not", "let", "in", "case", "while",
                     "deriving", "tests", "export", "pure", "type", "import", "module"})


#: DOOR 3, AND WHY IT IS REPORTED RATHER THAN CLOSED.
#:
#: `derive.py` classifies `_`-prefixed builtins and nothing else.  An identifier
#: like `show` -- applied, needing no import, declared nowhere -- is therefore
#: neither resolved NOR rejected by the parent tool: it is not looked at.  For an
#: import-granular verdict that costs nothing.  For a call-granular one it is a
#: hole, and `show` is applied inside `compaction_structural`, the extension the
#: second profile's entire criterion-2 coverage rests on.
#:
#: Closing it needs per-symbol effect data for language builtins, and NO PRODUCER
#: AT HEAD HAS IT.  The parent's evidence rule -- a std export whose cached row is
#: a closed empty row proves its direct callees effect-free -- cannot reach these
#: names, and WI-D15 measured both halves of that:
#:
#:   * every `show(` in the 46-module stdlib corpus is inside a `--` COMMENT, so
#:     no cached row anywhere carries evidence for it, interpolation-aware or not;
#:   * a textual scan for the general case cannot tell a language builtin from a
#:     higher-order PARAMETER applied in a std body.  Tried at WI-D15 and
#:     discarded: it resolved `f`, `p`, `pred`, `get`, `put` and `cas` as
#:     "language builtins", classifying `f` EFFECTFUL and `p` PURE.  A rule that
#:     invents evidence is worse than one that reports its absence.
#:
#: So an unresolved language builtin is `unknown-callee` -- a REJECTION -- and the
#: names are reported as a named RESIDUE with the counterfactual yield beside
#: them, labelled as a counterfactual.  This is the same shape as Amendment A's
#: condition A-1, which names classifier 1's broken producer dependency rather
#: than working around it.
LANGUAGE_BUILTIN_RESIDUE_NOTE = (
    "an applied identifier that is neither declared in the closure, nor imported, "
    "nor a `_`-prefixed builtin with producer evidence. No producer at HEAD carries "
    "per-symbol effect data for AILANG's language builtins"
)


# --------------------------------------------------------------------------
# door 4: keeping `${...}` while still dropping prose
# --------------------------------------------------------------------------

def keep_interpolations(text: str) -> str:
    """Blank comments and literal string TEXT, but KEEP `${...}` contents.

    Offsets are preserved, so line numbers stay true, exactly as in the parent's
    `strip_noise`.  The difference is the whole of door 4: `strip_noise` blanks
    a string literal wholesale, and AILANG's `show` is used almost exclusively as
    `"${show(n)}"`, so an import-granular tool never had to care and a call-
    granular one cannot afford not to.
    """
    out = list(text)
    n = len(text)
    i = 0

    def blank(a: int, b: int) -> None:
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        ch = text[i]
        if ch == '"':
            j = i + 1
            blank(i, i + 1)
            while j < n and text[j] != '"':
                if text[j] == "\\":
                    blank(j, j + 2)
                    j += 2
                    continue
                if text.startswith("${", j):
                    depth, k = 0, j + 1
                    while k < n:
                        if text[k] == "{":
                            depth += 1
                        elif text[k] == "}":
                            depth -= 1
                            if depth == 0:
                                break
                        k += 1
                    # blank the `${` and the closing `}`; KEEP the expression
                    blank(j, j + 2)
                    if k < n:
                        blank(k, k + 1)
                    j = k + 1
                    continue
                blank(j, j + 1)
                j += 1
            blank(j, j + 1)
            i = j + 1
        elif ch == "-" and text.startswith("--", i):
            j = text.find("\n", i)
            j = n if j == -1 else j
            blank(i, j)
            i = j
        else:
            i += 1
    return "".join(out)


# --------------------------------------------------------------------------
# expression shapes
# --------------------------------------------------------------------------

def tail_expression(body: str) -> str:
    """A function body's trailing expression: everything after the last `;` at depth 0.

    `let a = ...; let b = ...; make_hooks(b)` -> `make_hooks(b)`.  The registration
    effects live in the discarded prefix, which is precisely the distinction this
    module exists to draw -- so the prefix is not thrown away, it is handed back
    to the caller as the registration scope.
    """
    depth, last = 0, -1
    for i, ch in enumerate(body):
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        elif ch == ";" and depth == 0:
            last = i
    return body[last + 1:].strip()


def balanced(expr: str, open_ch: str = "{", close_ch: str = "}") -> str | None:
    """The inside of the leading balanced `{...}` of `expr`, or None."""
    e = expr.strip()
    if not e.startswith(open_ch):
        return None
    depth = 0
    for i, ch in enumerate(e):
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return e[1:i]
    return None


def split_record(body: str) -> dict[str, str]:
    """`{ a: x, b: y }` body -> `{a: 'x', b: 'y'}`, splitting on depth-0 commas."""
    parts, depth, cur = [], 0, ""
    for ch in body:
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    out: dict[str, str] = {}
    for p in parts:
        m = re.match(rf"\s*({IDENT})\s*:\s*(.+)", p, re.S)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


def split_args(text: str) -> list[str]:
    """Depth-0 comma split of an argument list or list body.  A lambda holding
    commas (`func(ctx: ExtCtx, call: ToolCallEnvelope) -> ...`) splits correctly
    because its commas sit inside `(`/`{`.  An EMPTY or whitespace-only text is
    zero elements; an empty element between commas is kept (as `""`) so the
    caller can reject it rather than silently drop it."""
    if not text.strip():
        return []
    parts, depth, cur = [], 0, ""
    for ch in text:
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    parts.append(cur.strip())
    return parts


def top_level_commas(text: str) -> int:
    """The number of depth-0 commas in `text` -- the INDEPENDENT element count
    (commas + 1 for a non-blank list), computed without parsing an element, so
    an element the parser drops is a mismatch rather than a silence."""
    depth, n = 0, 0
    for ch in text:
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        elif ch == "," and depth == 0:
            n += 1
    return n


def split_update(body: str) -> tuple[str, str] | None:
    """`{ base | a: x, b: y }` body -> (`base`, `a: x, b: y`), or None if it is
    a plain literal.  The split is on the first depth-0 `|` that is not `||`,
    so a lambda body holding `a || b` inside an override does not split."""
    depth = 0
    i = 0
    while i < len(body):
        ch = body[i]
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        elif ch == "|" and depth == 0:
            if i + 1 < len(body) and body[i + 1] == "|":
                i += 2
                continue
            return body[:i].strip(), body[i + 1:]
        i += 1
    return None


def func_body(text: str, name: str) -> str | None:
    """The brace-balanced body of `func <name>`, skipping the effect row.

    An AILANG signature ends `-> T ! {IO, Clock} {`, so the first `{` after the
    header is the EFFECT ROW.  Taking it yields a fragment in which nothing is
    ever found -- the parent tool records this as the single most expensive bug
    in its history, and the same trap is here.
    """
    m = re.search(rf"^\s*(?:export\s+)?(?:pure\s+)?func\s+{re.escape(name)}\b", text, re.M)
    if not m:
        return None
    # AILANG has TWO declaration forms and this tree uses both.  The
    # expression-bodied one --
    #   `export func bridge_path() -> Result[string, string] ! {FS} = <expr>`
    # (`motoko-ext-mcp/assets.ail:20`) -- has no brace body at all, so a
    # brace-only reader returns None and the caller rejects a perfectly
    # resolvable function.  Its body runs to the next top-level declaration.
    eq = _expression_body(text, m.end())
    if eq is not None:
        return eq
    return _body_at(text, m.end())


def _expression_body(text: str, pos: int) -> str | None:
    """`func f(...) -> T ! {row} = <expr>` -> `<expr>`, or None if not that form."""
    depth, i = 0, pos
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        elif ch == "\n" and depth == 0:
            nxt = re.match(r"\s*(?:export\s+|pure\s+)*(?:func|type|import)\b", text[i:])
            if nxt:
                return None
        elif ch == "=" and depth == 0 and text[i + 1:i + 2] != "=" and text[i - 1:i] not in "<>!=":
            end = re.search(rf"^\s*(?:export\s+)?(?:pure\s+)?(?:func|type)\s", text[i:], re.M)
            return text[i + 1:i + end.start()] if end else text[i + 1:]
        i += 1
    return None


def _body_at(text: str, pos: int) -> str | None:
    """The brace-balanced body at or after `pos`, skipping effect rows.

    An effect row is recognised SYNTACTICALLY, by the `!` that introduces it, and
    NOT by its contents.  The content test the parent tool uses -- "a bare
    comma-separated list of capitalised names" -- is a fail-open here, because
    this tree's hook bodies are things like `{ NoOpinion }`, `{ Delegate }` and
    `{ PassThrough }`.  Every one of those matches the content pattern exactly,
    so a content-testing reader skips the real body, finds nothing after it, and
    reports the hook as unresolvable -- or, worse, walks on to an unrelated brace.
    Measured at WI-D15 on `a2a` and `mcp`, whose `on_tool_policy` is
    `func(...) -> ToolPolicyDecision { NoOpinion }` with no effect row at all.
    """
    i = pos
    n = len(text)
    while i < n:
        if text[i] == "{":
            depth, j = 0, i
            while j < n:
                if text[j] == "{":
                    depth += 1
                elif text[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            prev = text[:i].rstrip()[-1:]
            # `!` opens an effect row; `->`, `[`, `(`, `,` and `:` all mean this
            # brace group is part of the TYPE, not the body.  The second half of
            # that list is not decoration: `exec.ail`'s
            #   `func shell_exec(...) -> Result[{ stdout: string, ... }, string] ! {Process} {`
            # puts a brace-delimited RECORD TYPE inside the return type, and a
            # reader that takes the first brace group returns `stdout: string, ...`
            # as the body.  Nothing is ever found in it, so `shell_exec` looks
            # effect-free -- and with it `run_omnigraph`, and with it omnigraph's
            # `on_tool_handle`, which calls `std/process.exec`.  Measured at
            # WI-D15: before this line omnigraph reported HOOK-PORT-MEDIATED.
            if prev in ("!", ">", "[", "(", ",", ":"):
                i = j + 1
                continue
            return text[i + 1:j]
        i += 1
    return None


def lambda_body(expr: str) -> str | None:
    """Reachable text of an inline hook binding, or None if it is not one.

    Two forms, and both are in this tree:
      `func(ctx: ExtCtx, m) -> T ! {..} { body }`  -- brace body after the row
      `\\ctx _. expr`                              -- everything after the dot
    """
    e = expr.strip()
    if e.startswith("func"):
        return _body_at(e, 4)
    if e.startswith("\\"):
        # the parameter list ends at the first `.` that is not inside brackets
        depth = 0
        for i, ch in enumerate(e):
            if ch in "{[(":
                depth += 1
            elif ch in "}])":
                depth -= 1
            elif ch == "." and depth == 0 and i > 0:
                return e[i + 1:]
        return None
    return None


def let_bindings(body: str) -> dict[str, str]:
    """`let x = <expr>;` and `let x: T = <expr>;` -> {x: expr}, depth-0 only."""
    out: dict[str, str] = {}
    for m in _LET.finditer(body):
        start = m.end()
        if body[m.end() - 1] == ":":
            # skip the annotation: the first `=` at depth 0 ends it.  The
            # annotation may hold `(A, B) -> C ! {IO, ...}`, so depth tracking
            # is what keeps the effect row's braces from ending the scan.
            depth, i = 0, start
            while i < len(body):
                ch = body[i]
                if ch in "{[(":
                    depth += 1
                elif ch in "}])":
                    depth -= 1
                elif ch == "=" and depth == 0 and body[i + 1:i + 2] != "=":
                    break
                i += 1
            start = i + 1
        depth, i = 0, start
        while i < len(body):
            ch = body[i]
            if ch in "{[(":
                depth += 1
            elif ch in "}])":
                depth -= 1
                if depth < 0:
                    break
            elif ch == ";" and depth == 0:
                break
            i += 1
        out[m.group(1)] = body[start:i].strip()
    return out


# --------------------------------------------------------------------------
# the per-extension scope
# --------------------------------------------------------------------------

class Rejection:
    def __init__(self, shape: str, where: str, detail: str):
        self.shape, self.where, self.detail = shape, where, detail

    def as_dict(self) -> dict:
        return {"shape": self.shape, "where": self.where, "detail": self.detail,
                "why": HOOK_SHAPES.get(self.shape, "")}


class Scope:
    """One extension's hook-reachable scope, and the registration scope beside it.

    `mods` and `texts` come from the parent tool's closure so that both answers
    quantify over exactly the same source.  The only thing that differs is which
    part of it a hook can reach.
    """

    def __init__(self, ext: str, root: Path, mods: list[Path], repo: Path, resolve,
                 abi_types: Path | None = None):
        self.ext, self.root, self.repo, self.resolve = ext, root.resolve(), repo, resolve
        #: where `default_hooks` is read from when the closure does not hold it
        self.abi_types = abi_types if abi_types is not None else repo / ABI_TYPES
        #: the record-update head, when the record is `{ head | … }`; None for
        #: a full literal.  Reported so a reader can see WHICH shape resolved.
        self.update_head: str | None = None
        #: "record" (5.x `ExtensionHooks`, literal or update) or
        #: "capability-list" (6.0 `[Capability]`); None until located.  Both
        #: heads coexist until B8 flips the ABI.
        self.registration_shape: str | None = None
        #: the atoms of a capability-list registration, keyed (kind, index)
        #: where `index` counts WITHIN the kind, plus the list `position`.
        self.atoms: list[dict] = []
        self.mods = [p.resolve() for p in mods]
        # door 4: interpolation-preserving, NOT the parent's `strip_noise`
        self.texts = {p: keep_interpolations(p.read_text(errors="replace")) for p in self.mods}
        self.rejections: list[Rejection] = []

        self.declared: dict[str, list[Path]] = {}
        self.types: set[str] = set()
        for p, tx in self.texts.items():
            for m in _DECL.finditer(tx):
                self.declared.setdefault(m.group(1), []).append(p)
            for m in _TYPE.finditer(tx):
                self.types.add(m.group(1))

        # per-module import tables.  `local -> (module, source symbol)`, so a
        # rename is resolvable (the parent's decision 3) while a whole-module
        # alias stays a rejection there and is simply invisible here.
        self.imports: dict[Path, dict[str, tuple[str, str]]] = {}
        # Renames are resolved PER IMPORT STATEMENT, not per file.  A file-wide
        # `source -> local` map is wrong whenever two modules export the same
        # name under different aliases, and this tree has that case:
        # `compaction_ai.ail` imports `std/list (length as list_length)` AND
        # `std/string (length as string_length)`.  A file-wide map keyed on the
        # source name keeps one of them and drops the other silently -- which
        # turns a resolvable rename into an `unknown-callee` rejection, i.e. an
        # answer that is wrong in the fail-CLOSED direction and therefore easy
        # to mistake for the tool working.
        for p, tx in self.texts.items():
            table: dict[str, tuple[str, str]] = {}
            for mpath, pairs, form in _imports_of(tx):
                if not pairs:
                    continue
                for local, src in pairs:
                    table[local] = (mpath, src)
            self.imports[p] = table

        self.hook_home: Path | None = None
        self.bindings: dict[str, tuple[Path, str]] = {}
        self.registration_text: str = ""
        self.reached: list[tuple[Path, str]] = []
        self.delegation_hops = 0
        #: door-3 residue: applied names no producer at HEAD can classify.  Kept
        #: per extension so the counterfactual yield is derived from the tool's
        #: own findings rather than asserted beside them.
        self.unresolved_callees: set[str] = set()
        #: locals of the function that produced the hooks record -- everything an
        #: inline binding closes over.  Populated by `locate`.
        self.producing_locals: set[str] = set()
        self.producing_body: str = ""

    # -- locating the eight bindings ---------------------------------------

    def locate(self) -> bool:
        text = self.texts.get(self.root)
        if text is None:
            self.rejections.append(Rejection("hook-record-unresolvable", str(self.root),
                                             "the closure root is not a readable module"))
            return False
        body = func_body(text, REGISTER_FUNC)
        if body is None:
            self.rejections.append(Rejection("hook-record-unresolvable", self._rel(self.root),
                                             f"no `{REGISTER_FUNC}` declaration"))
            return False

        home, expr = self.root, tail_expression(body)
        self.registration_text = body[:len(body) - len(expr)] if body.endswith(expr) else body
        # The body that PRODUCES the record, which is where a slot bound to a
        # bare name may find its `let`.  It is `register_with_config`'s body only
        # until the first delegation hop: five of the fifteen extensions return
        # `make_hooks(cfg)`, and their `handle`/`intercept`/`finalize` locals live
        # in `make_hooks`.  Looking them up by the REGISTRATION function's name
        # after a hop finds nothing and rejects a resolvable binding.
        self.producing_body = body
        hops = 0
        record = balanced(expr)
        cap_list = balanced(expr, "[", "]")
        while cap_list is None and (record is None or not self._looks_like_hooks(record)):
            if hops >= MAX_DELEGATION_HOPS:
                self.rejections.append(Rejection(
                    "hook-record-unresolvable", self._rel(home),
                    f"delegation exceeded {MAX_DELEGATION_HOPS} hops at `{expr[:60]}`"))
                return False
            m = re.match(rf"({IDENT})\s*\(", expr)
            if not m:
                # a tail that MENTIONS a capability constructor but is not a
                # literal list -- `[A(f)] ++ more(cfg)`, `if c then [..] else [..]`
                # -- is the 6.0 computed-list shape and is named as such
                if any(re.search(rf"\b{k}\s*\(", expr) for k in CAPABILITY_KINDS):
                    self.rejections.append(Rejection(
                        "capability-list-unresolvable", self._rel(home),
                        f"tail expression `{expr[:60]}` builds the capability list by an "
                        f"expression rather than writing it as a literal -- literal lists only"))
                    return False
                self.rejections.append(Rejection(
                    "hook-record-unresolvable", self._rel(home),
                    f"tail expression `{expr[:60]}` is neither a record literal nor a call"))
                return False
            nxt = self._resolve_func(home, m.group(1))
            if nxt is None:
                self.rejections.append(Rejection(
                    "hook-record-unresolvable", self._rel(home),
                    f"`{m.group(1)}` returns the hooks record but resolves to no declaration "
                    f"in this closure"))
                return False
            home, fbody = nxt
            # the delegated function may perform registration effects of its own
            inner = tail_expression(fbody)
            self.registration_text += fbody[:len(fbody) - len(inner)] if fbody.endswith(inner) else fbody
            self.producing_body = fbody
            expr = inner
            record = balanced(expr)
            cap_list = balanced(expr, "[", "]")
            hops += 1

        self.hook_home = home
        self.delegation_hops = hops
        self.producing_locals = set(let_bindings(self.producing_body))

        # THE CAPABILITY LIST (ADR-001 Phase B, B2): the 6.0 shape.  A list of
        # constructor applications, every function-typed argument a binding.
        # There is no record to tile; what fails closed instead is the ELEMENT
        # COUNT, computed independently of the parse.
        if cap_list is not None:
            # a balanced `[` at the tail could also be the tail of a record-
            # bearing expression like `[x].head` -- require the whole tail
            if not re.fullmatch(r"\[.*\]", expr.strip(), re.S):
                self.rejections.append(Rejection(
                    "capability-list-unresolvable", self._rel(home),
                    f"tail expression `{expr[:60]}` starts a list but does not end it -- "
                    f"the capability list is not a literal"))
                return False
            self.registration_shape = "capability-list"
            return self._locate_capability_list(home, cap_list)
        self.registration_shape = "record"

        # THE RECORD-UPDATE HEAD (ADR-001 §1, Q4).  `{ default_hooks(id) | on_x: f }`
        # binds ONE slot in this file and SEVEN in the ABI's literal.  The seven
        # are text a hook reaches, so they are bound here to that literal's own
        # lambdas and walked like any other binding -- and the tiling assertion
        # below then runs over the MERGED set, so a slot the ABI literal stops
        # binding still fails closed rather than being scanned around.
        fields: dict[str, tuple[Path, str]] = {}
        upd = split_update(record)
        if upd is not None:
            head, rest = upd
            base = self._resolve_update_head(home, head)
            if base is None:
                return False
            base_home, base_fields = base
            self.update_head = head
            fields = {k: (base_home, v) for k, v in base_fields.items()}
            for k, v in split_record(rest).items():
                fields[k] = (home, v)
        else:
            fields = {k: (home, v) for k, v in split_record(record).items()}

        missing = [s for s in SLOTS if s not in fields]
        if missing:
            self.rejections.append(Rejection(
                "hook-slot-missing", self._rel(home),
                f"the resolved record binds {len(fields)} field(s) and is missing "
                f"{', '.join(missing)} -- the eight bindings do not tile it"))
            return False
        self.bindings = {s: fields[s] for s in SLOTS}
        return True

    def _locate_capability_list(self, home: Path, body: str) -> bool:
        """`Kind(arg, ...), Kind(arg, ...)` -> atoms + bindings, or a rejection.

        Every element must be an application of a constructor in
        `CAPABILITY_KINDS` at its arity; every function-typed argument becomes a
        binding keyed `Kind[index]` (index within the kind), which `walk`
        resolves exactly as it resolves a record slot: an inline lambda to its
        text, a bare name to its declaration's BODY.  A wide-rowed named
        function is therefore scanned, not trusted -- its row bounds nothing
        in constructor-argument position (B1's probe).  Anything else is
        `capability-list-unresolvable`, and so is any disagreement between the
        depth-0 comma count and the atoms emitted."""
        elements = split_args(body)
        expected = 0 if not body.strip() else top_level_commas(body) + 1
        per_kind: dict[str, int] = {}
        bindings: dict[str, tuple[Path, str]] = {}
        atoms: list[dict] = []
        for pos, el in enumerate(elements):
            if not el:
                self.rejections.append(Rejection(
                    "capability-list-unresolvable", self._rel(home),
                    f"capability list element {pos} is empty (a trailing or doubled comma) -- "
                    f"the element count ({expected}) cannot be reconciled with the atoms"))
                return False
            if el.startswith("..."):
                self.rejections.append(Rejection(
                    "capability-list-unresolvable", self._rel(home),
                    f"capability list element {pos} is a spread `{el[:40]}` -- its atoms are "
                    f"text this tool has not read"))
                return False
            m = re.fullmatch(rf"({IDENT})\s*\((.*)\)", el, re.S)
            if m is None:
                self.rejections.append(Rejection(
                    "capability-list-unresolvable", self._rel(home),
                    f"capability list element {pos} `{el[:60]}` is not a constructor "
                    f"application `Kind(arg, ...)` -- a computed element is an atom this tool "
                    f"cannot enumerate"))
                return False
            kind, argtext = m.group(1), m.group(2)
            if kind not in CAPABILITY_KINDS:
                self.rejections.append(Rejection(
                    "capability-list-unresolvable", self._rel(home),
                    f"capability list element {pos} applies `{kind}`, which is not one of the "
                    f"{len(CAPABILITY_KINDS)} capability constructors this tool enumerates -- a "
                    f"new ABI variant must be added to CAPABILITY_KINDS, not scanned around"))
                return False
            arity, fn_args = CAPABILITY_KINDS[kind]
            args = split_args(argtext)
            if len(args) != arity or any(not a for a in args):
                self.rejections.append(Rejection(
                    "capability-list-unresolvable", self._rel(home),
                    f"`{kind}` at element {pos} is applied to {len(args)} argument(s); the "
                    f"constructor takes {arity}"))
                return False
            idx = per_kind.get(kind, 0)
            per_kind[kind] = idx + 1
            for ai in fn_args:
                key = f"{kind}[{idx}]" if len(fn_args) == 1 else f"{kind}[{idx}]@{ai}"
                bindings[key] = (home, args[ai])
            atoms.append({"kind": kind, "index": idx, "position": pos,
                          "binding": args[fn_args[0]][:40]})
        if len(atoms) != expected:
            self.rejections.append(Rejection(
                "capability-list-unresolvable", self._rel(home),
                f"the capability list has {expected} element(s) by depth-0 comma count and "
                f"{len(atoms)} atom(s) were emitted -- an atom was dropped, which is fail-open"))
            return False
        self.atoms = atoms
        self.bindings = bindings
        return True

    def _resolve_update_head(self, home: Path, head: str
                             ) -> tuple[Path, dict[str, str]] | None:
        """`default_hooks(<arg>)`, or a local bound to that call, -> the ABI
        literal's fields keyed by slot.  Anything else is a rejection: the base
        of an update is where the un-overridden slots' text lives, and a base
        this tool has not read is seven slots it cannot scan."""
        h = head.strip()
        call = re.fullmatch(rf"({IDENT})\s*\((.*)\)", h, re.S)
        if call is None and re.fullmatch(IDENT, h):
            lb = let_bindings(self.producing_body).get(h)
            if lb is None:
                self.rejections.append(Rejection(
                    "hook-record-unresolvable", self._rel(home),
                    f"record-update base `{h}` is a bare name with no `let` in the "
                    f"producing body -- a threaded or imported base cannot be scanned"))
                return None
            call = re.fullmatch(rf"({IDENT})\s*\((.*)\)", lb.strip(), re.S)
            if call is None:
                self.rejections.append(Rejection(
                    "hook-record-unresolvable", self._rel(home),
                    f"record-update base `{h}` is bound to `{lb[:50]}`, which is not a "
                    f"`{DEFAULT_HOOKS}(...)` call"))
                return None
        if call is None:
            self.rejections.append(Rejection(
                "hook-record-unresolvable", self._rel(home),
                f"record-update base `{h[:60]}` is a computed expression, not "
                f"`{DEFAULT_HOOKS}(...)` or a local bound to it"))
            return None
        callee = call.group(1)
        if callee != DEFAULT_HOOKS:
            self.rejections.append(Rejection(
                "hook-record-unresolvable", self._rel(home),
                f"record-update base is `{callee}(...)`, not the ABI's `{DEFAULT_HOOKS}` -- "
                f"the un-overridden slots would be bound to text this tool has not read"))
            return None
        nxt = self._resolve_func(home, DEFAULT_HOOKS)
        if nxt is None and self.abi_types is not None and self.abi_types.is_file():
            abi = self.abi_types.resolve()
            if abi not in self.texts:
                self.texts[abi] = keep_interpolations(abi.read_text(errors="replace"))
            b = func_body(self.texts[abi], DEFAULT_HOOKS)
            if b is not None:
                nxt = (abi, b)
        if nxt is None:
            self.rejections.append(Rejection(
                "hook-record-unresolvable", self._rel(home),
                f"`{DEFAULT_HOOKS}` resolves to no declaration in this closure and no ABI "
                f"module at `{self.abi_types}` -- the seven default slots cannot be read"))
            return None
        base_home, body = nxt
        literal = balanced(tail_expression(body))
        base_fields = split_record(literal) if literal is not None else {}
        if literal is None or not self._looks_like_hooks(literal):
            self.rejections.append(Rejection(
                "hook-record-unresolvable", self._rel(base_home),
                f"`{DEFAULT_HOOKS}`'s tail expression is not an ExtensionHooks literal "
                f"this tool can split"))
            return None
        return base_home, base_fields

    def _looks_like_hooks(self, record: str | None) -> bool:
        if record is None:
            return False
        # a record UPDATE is a hooks-record attempt whatever it overrides; its
        # base is judged by `_resolve_update_head`, which fails closed
        if split_update(record) is not None:
            return True
        f = split_record(record)
        return sum(1 for s in SLOTS if s in f) >= 4

    def _rel(self, p: Path) -> str:
        try:
            return str(p.relative_to(self.repo))
        except ValueError:
            return str(p)

    def _resolve_func(self, home: Path, name: str) -> tuple[Path, str] | None:
        """`name` -> (module, body), through imports and closure declarations."""
        imp = self.imports.get(home, {}).get(name)
        if imp is not None:
            mpath, src = imp
            if mpath.startswith("std/"):
                return None                       # a std symbol is not a hooks producer
            kind, target = self.resolve(mpath)
            if kind == "file":
                t = target.resolve()
                if t in self.texts:
                    b = func_body(self.texts[t], src)
                    if b is not None:
                        return (t, b)
            return None
        for p in self.declared.get(name, []):
            b = func_body(self.texts[p], name)
            if b is not None:
                return (p, b)
        return None

    # -- the walk ----------------------------------------------------------

    def walk(self, producer, builtins: dict[str, str],
             ext_fields: tuple[str, ...] = ()) -> tuple[list[dict], list[dict]]:
        """(ambient findings, ExtPorts field-call findings) over hook-reachable text.

        Every applied identifier must resolve.  What it resolves to decides:
        a std symbol is classified by the producer; a `_`builtin by the builtin
        evidence map; a closure declaration is recursed into; a constructor or
        type is skipped; anything else is a REJECTION.
        """
        ambient: list[dict] = []
        ports: list[dict] = []
        seen: set[tuple[Path, str]] = set()
        stack: list[tuple[Path, str, str]] = []

        for slot, (home, expr) in self.bindings.items():
            text = self._binding_text(home, slot, expr, stack)
            if text is not None:
                stack.append((home, text, slot))

        while stack:
            home, text, slot = stack.pop()
            self.reached.append((home, slot))
            # Locals visible here are this text's OWN binders plus everything the
            # producing function closed over.  Door 6's dangerous corner lives in
            # the second half: `let injected = cfg.callback;` in
            # `register_with_config`, applied inside a hook body.  Scoping the
            # lookup to the hook body alone reports that as `unknown-callee` --
            # still a rejection, so no verdict moves, but it names the wrong
            # thing, and a rejection a reader cannot triage is one they will
            # eventually wave through.
            locals_here = (set(let_bindings(text)) | _param_names(text)
                           | self.producing_locals)
            for m in _APPLY.finditer(text):
                name = m.group(1)
                if name in _SYNTAX or name in self.types or name[0].isupper():
                    continue
                key = (home, name)
                if key in seen:
                    continue
                seen.add(key)
                line = text[:m.start()].count("\n") + 1

                # PROPERTY 1's POSITIVE HALF.  `ctx.ports.ai_step(...)` is a FIELD
                # call on an `ExtPorts`-typed value, which is exactly what
                # criterion 2 admits -- so it must be recorded as mediated, not
                # rejected as an unresolvable callee.  Without this arm the one
                # extension in the tree that actually mediates can never clear,
                # which is the defect WI-D15 set out to test rather than to
                # reproduce.  A dotted call whose field is NOT an `ExtPorts`
                # field is a call on some other record and stays a rejection,
                # on classifier 2's discipline.
                if text[:m.start()].rstrip().endswith("."):
                    if name in ext_fields:
                        ports.append(self._finding(home, slot, "ExtPorts", name, None,
                                                   f"`ExtPorts.{name}` applied at line {line} -- a "
                                                   f"world-mediated port, which criterion 2 admits"))
                    else:
                        self.rejections.append(Rejection(
                            "applied-local", self._rel(home),
                            f"`.{name}(...)` at line {line} is a field call on a value this tool "
                            f"cannot resolve to an `ExtPorts`-typed receiver"))
                    continue

                if name.startswith("_"):
                    kind = builtins.get(name)
                    if kind == "PURE":
                        continue
                    if kind == "EFFECTFUL":
                        ambient.append(self._finding(home, slot, "<builtin>", name, None,
                                                     f"`{name}` is a compiler builtin wrapped by an "
                                                     f"effect-bearing std export"))
                    else:
                        self.rejections.append(Rejection(
                            "unknown-callee" if kind is None else kind, self._rel(home),
                            f"`{name}` is called as a compiler builtin from hook-reachable text "
                            f"and no std export whose body calls it carries a usable row"))
                    continue

                imp = self.imports.get(home, {}).get(name)
                if imp is not None:
                    mpath, src = imp
                    if mpath.startswith("std/"):
                        kind, labels = producer.classify(mpath, src)
                        if kind in ("TYPE", "PURE", "VALUE"):
                            continue
                        if kind == "EFFECTFUL":
                            ambient.append(self._finding(home, slot, mpath, src, labels,
                                                         f"`{mpath}.{src}` performs "
                                                         f"{{{', '.join(labels)}}} and is applied in "
                                                         f"hook-reachable text"))
                        else:
                            self.rejections.append(Rejection(kind, self._rel(home),
                                                             f"`{mpath}.{src}` applied at line {line}"))
                        continue
                    nxt = self._resolve_func(home, name)
                    if nxt is None:
                        self.rejections.append(Rejection(
                            "hook-binding-unresolvable", self._rel(home),
                            f"`{name}` is imported from `{mpath}` and resolves to no declaration "
                            f"this closure holds"))
                        continue
                    stack.append((nxt[0], nxt[1], slot))
                    continue

                if name in self.declared:
                    nxt = self._resolve_func(home, name)
                    if nxt is not None:
                        stack.append((nxt[0], nxt[1], slot))
                        continue

                if name in locals_here:
                    self.rejections.append(Rejection(
                        "applied-local", self._rel(home),
                        f"`{name}` is a local or parameter and is APPLIED at line {line}"))
                    continue

                self.unresolved_callees.add(name)
                self.rejections.append(Rejection(
                    "unknown-callee", self._rel(home),
                    f"`{name}` is applied at line {line} and resolves to no declaration, "
                    f"import or builtin with producer evidence"))

        return ambient, ports

    def _binding_text(self, home: Path, slot: str, expr: str,
                      stack: list) -> str | None:
        """A slot's bound expression -> the text a hook can reach, or None + a rejection."""
        body = lambda_body(expr)
        if body is not None:
            return body
        m = re.fullmatch(rf"({IDENT})", expr.strip())
        if m:
            name = m.group(1)
            nxt = self._resolve_func(home, name)
            if nxt is not None:
                return nxt[1]
            lb = let_bindings(self.producing_body).get(name)
            if lb is not None:
                inner = lambda_body(lb)
                if inner is not None:
                    return inner
                self.rejections.append(Rejection(
                    "hook-binding-unresolvable", self._rel(home),
                    f"{slot} is bound to the local `{name}`, whose `let` is `{lb[:50]}` "
                    f"-- not a function expression this tool can enter"))
                return None
            self.rejections.append(Rejection(
                "hook-binding-unresolvable", self._rel(home),
                f"{slot} is bound to the bare name `{name}`, which resolves to no declaration, "
                f"import or local lambda"))
            return None
        # a call expression returning a function value: not resolvable, and it is
        # exactly the "computed" shape classifier 2 refuses.
        self.rejections.append(Rejection(
            "hook-binding-unresolvable", self._rel(home),
            f"{slot} is bound to `{expr[:60]}` -- neither an inline function nor a bare name"))
        return None

    def _finding(self, home: Path, slot: str, origin: str, sym: str,
                 labels, why: str) -> dict:
        return {"extension": self.ext, "file": self._rel(home), "slot": slot,
                "origin": origin, "symbol": sym, "effects": labels, "why": why}

    def verdict(self, ambient: list[dict]) -> str:
        if self.rejections:
            return "HOOK-UNRESOLVED"
        return "HOOK-AMBIENT" if ambient else "HOOK-PORT-MEDIATED"


def _param_names(text: str) -> set[str]:
    """Parameter names visible in a body -- best effort, and only ever used to
    turn an unknown callee into the MORE specific `applied-local` rejection.
    Both are rejections, so a miss here cannot change a verdict."""
    out: set[str] = set()
    for m in re.finditer(rf"func\s*\(([^)]*)\)", text):
        for part in m.group(1).split(","):
            p = part.strip().split(":")[0].strip()
            if re.fullmatch(IDENT, p):
                out.add(p)
    for m in re.finditer(rf"\\\s*([^.]*)\.", text):
        for p in m.group(1).split():
            if re.fullmatch(IDENT, p):
                out.add(p)
    return out


def _imports_of(clean: str):
    """`(module, [(local name, source name)] | None, form)`.

    The parent's reader returns SOURCE symbols, which is what an import-granular
    inventory wants.  A call-granular one needs both halves of a rename: the
    local name is what appears at the call site and the source name is what the
    producer carries a row for.  The symbol list is brace-balanced rather than
    line-scoped for the parent's reason -- several `motoko_ext_abi/types` imports
    wrap across lines, and a line-scoped reader drops every symbol after the
    first newline, silently and in the direction that flatters the extension.
    """
    pat = re.compile(rf"^import\s+([A-Za-z0-9_/]+)\s*(\(|as\b)?", re.M)
    out = []
    for m in pat.finditer(clean):
        path, tok = m.group(1), m.group(2)
        if tok == "(":
            depth, i = 0, m.end() - 1
            while i < len(clean):
                if clean[i] == "(":
                    depth += 1
                elif clean[i] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            pairs = []
            for part in clean[m.end():i].split(","):
                toks = part.split()
                if not toks:
                    continue
                if len(toks) >= 3 and toks[1] == "as":
                    pairs.append((toks[2], toks[0]))
                else:
                    pairs.append((toks[0], toks[0]))
            out.append((path, pairs, "list"))
        elif tok == "as":
            out.append((path, None, "module-alias"))
        else:
            out.append((path, None, "bare-module"))
    return out


# --------------------------------------------------------------------------
# the derivation, and the registration scope beside it
# --------------------------------------------------------------------------

def derive_hook_scope(repo: Path, c3, producer, builtins: dict[str, str],
                      ext_fields: tuple[str, ...]) -> dict:
    """Both answers over one closure: what a HOOK reaches, and what only
    REGISTRATION reaches.

    The closure comes from the parent tool, so the two verdicts quantify over
    exactly the same source and any difference between them is the reading and
    nothing else.  `registration_only` is the set difference and it is the
    artifact this item owes: those effects are real, they run at install time,
    and ruling them out of criterion 2 does not account for them.
    """
    exts = c3.installable_extensions(repo)
    resolve = c3.module_resolver(repo)
    closure_report = {}

    out: dict[str, dict] = {}
    for ext, d in sorted(exts.items()):
        mods, residue = c3.closure(d / "register.ail", resolve)
        # the parent's import-granular findings over the same closure
        closure_ambient = []
        for p in mods:
            for f in c3.inventory_module(ext, p, repo, producer, builtins):
                if f.verdict == "AMBIENT":
                    closure_ambient.append((f.file, f.source, f.sym))

        sc = Scope(ext, d / "register.ail", mods, repo, resolve)
        located = sc.locate()
        ambient, ports = sc.walk(producer, builtins, ext_fields) if located else ([], [])
        verdict = sc.verdict(ambient)

        hook_srcs = {(a["origin"], a["symbol"]) for a in ambient}
        reg_only = sorted({(f, o, s) for (f, o, s) in closure_ambient
                           if (o, s) not in hook_srcs})

        out[ext] = {
            "package_dir": str(d.relative_to(repo)),
            "verdict": verdict,
            "located": located,
            "delegation_hops": sc.delegation_hops,
            "hook_home": sc._rel(sc.hook_home) if sc.hook_home else None,
            "record_update_head": sc.update_head,
            "registration_shape": sc.registration_shape,
            "atoms": sc.atoms,
            "atom_count": len(sc.atoms),
            "slots_bound": sorted(sc.bindings),
            "hook_ambient": ambient,
            "ext_ports_calls": ports,
            "rejections": [r.as_dict() for r in sc.rejections],
            "unresolved_callees": sorted(sc.unresolved_callees),
            "closure_ambient_count": len(closure_ambient),
            "registration_only": [{"file": f, "origin": o, "symbol": s} for f, o, s in reg_only],
        }
    return out


def emit_hook_scope(res: dict, closure_verdicts: dict[str, str]) -> int:
    """Print both answers side by side.  The delta IS the report."""
    clean = sorted(e for e, r in res.items() if r["verdict"] == "HOOK-PORT-MEDIATED")
    amb = sorted(e for e, r in res.items() if r["verdict"] == "HOOK-AMBIENT")
    unres = sorted(e for e, r in res.items() if r["verdict"] == "HOOK-UNRESOLVED")

    print("CLASSIFIER 3, HOOK SCOPE -- criterion 2 quantified over HOOKS (ADR:1295-1300),")
    print("beside the shipped CLOSURE unit (ADR:1484-1490).  Same closure, same producer;")
    print("the only difference is which part of it a hook can reach.")
    print()
    print(f"{'extension':<26}{'closure unit':<18}{'hook scope':<22}{'reg-only sources'}")
    for e in sorted(res):
        r = res[e]
        n = len(r["registration_only"])
        print(f"  {e:<24}{closure_verdicts.get(e, '?'):<18}{r['verdict']:<22}{n}")
    print()
    print(f"HOOK-PORT-MEDIATED ({len(clean)} of {len(res)}): {', '.join(clean) or '-'}")
    print(f"HOOK-AMBIENT       ({len(amb)}): {', '.join(amb) or '-'}")
    print(f"HOOK-UNRESOLVED    ({len(unres)}): {', '.join(unres) or '-'}")
    print()

    # The residue, and the counterfactual it supports -- LABELLED as a
    # counterfactual, because a number that is not a verdict must not read as one.
    residue: dict[str, list[str]] = {}
    for e, r in res.items():
        for n in r["unresolved_callees"]:
            residue.setdefault(n, []).append(e)
    if residue:
        print("DOOR-3 RESIDUE -- applied names no producer at HEAD can classify:")
        for n, es in sorted(residue.items(), key=lambda kv: -len(kv[1])):
            print(f"  {n:<20} blocks {len(es)} extension(s): {', '.join(sorted(es))}")
        blocked = {e for es in residue.values() for e in es}
        would = sorted(e for e in blocked
                       if not [x for x in res[e]["rejections"]
                               if x["shape"] != "unknown-callee"]
                       and not res[e]["hook_ambient"])
        print(f"  COUNTERFACTUAL (not a verdict): were these resolved effect-free, "
              f"HOOK-PORT-MEDIATED would be {len(clean) + len(would)} of {len(res)}")
        print(f"  adding {', '.join(would) or '-'}")
        print()

    print("REGISTRATION-ONLY AMBIENT SOURCES -- in the closure, out of criterion 2's")
    print("scope on the hooks reading, and NOT thereby harmless.  D5's disclosure")
    print("obligation is what must account for these; this tool only names them.")
    for e in sorted(res):
        ro = res[e]["registration_only"]
        if ro:
            names = ", ".join(f"{x['origin']}.{x['symbol']}" for x in ro[:5])
            more = f" (+{len(ro) - 5})" if len(ro) > 5 else ""
            print(f"  {e:<24} {len(ro):>2}  {names}{more}")
    return 0


# --------------------------------------------------------------------------
# the fixture suite
# --------------------------------------------------------------------------

def self_test(repo: Path, c3, producer, builtins: dict[str, str],
              ext_fields: tuple[str, ...]) -> int:
    """One fixture per rejection shape, each PAIRED with a resolving control.

    The pair that carries the reading is `control_registration_only` /
    `control_hook_reaches_env`: the same import and the same call, differing only
    in position.  If those two ever agree, this tool has stopped measuring the
    reading and is measuring the file again -- so they are asserted to DISAGREE,
    explicitly, rather than only asserted individually.
    """
    fx = repo / "tools/ext_ambient_inventory/fixtures/hook_scope"
    if not fx.is_dir():
        print(f"self-test: no fixture directory at {fx}", file=__import__("sys").stderr)
        return 2
    import json
    expected = json.loads((fx / "expected.json").read_text())
    fails: list[str] = []

    def trivial_resolve(path: str):
        return ("std", path) if path.startswith("std/") else ("residue", path)

    present = sorted(p.stem for p in fx.glob("*.ail"))
    got_verdicts: dict[str, str] = {}
    for name in present:
        want = expected["fixtures"].get(name)
        if want is None:
            fails.append(f"{name}: fixture present but not declared in expected.json")
            continue
        f = fx / f"{name}.ail"
        # the fixture closure is one file, so `default_hooks` is read from the
        # REAL ABI module: the control for the update head measures the shape
        # the tree ships, not a copy of it
        sc = Scope(name, f, [f], fx, trivial_resolve, abi_types=repo / ABI_TYPES)
        located = sc.locate()
        ambient, ports = sc.walk(producer, builtins, ext_fields) if located else ([], [])
        verdict = sc.verdict(ambient)
        got_verdicts[name] = verdict
        shapes = sorted({r.shape for r in sc.rejections})
        if verdict != want["verdict"]:
            fails.append(f"{name}: expected {want['verdict']}, got {verdict} "
                         f"(shapes {shapes}, ambient {len(ambient)})  [{want['form']}]")
        elif want["shapes"] and shapes != sorted(want["shapes"]):
            fails.append(f"{name}: expected shapes {sorted(want['shapes'])}, got {shapes}")
        elif "atoms" in want and len(sc.atoms) != want["atoms"]:
            # THE FAIL-CLOSED DENOMINATOR (B2): a list fixture pins how many
            # atoms it holds, so a reader that resolves a list by reading fewer
            # atoms than are written cannot report the fixture green.
            fails.append(f"{name}: expected {want['atoms']} atom(s), enumerated {len(sc.atoms)} "
                         f"({[(a['kind'], a['index']) for a in sc.atoms]})")
        elif "atoms" in want and sc.registration_shape != "capability-list":
            fails.append(f"{name}: pinned as a capability list but resolved as "
                         f"{sc.registration_shape}")
        else:
            extra = (f"  atoms={len(sc.atoms)}"
                     if sc.registration_shape == "capability-list" and located else "")
            print(f"  ok  {name:<34} {verdict:<20} {want['form']}{extra}")
    for gone in sorted(set(expected["fixtures"]) - set(present)):
        fails.append(f"{gone}: declared in expected.json but the fixture file is gone")

    # Every shape this module adds must be exercised by some fixture.
    covered = {s for w in expected["fixtures"].values() for s in w["shapes"]}
    for shape in HOOK_SHAPES:
        if shape not in covered:
            fails.append(f"SHAPE COVERAGE: no fixture exercises `{shape}`")

    # POSITIVE CONTROL: without one, a classifier that resolved NOTHING would
    # report every rejection fixture correctly and pass the suite.
    if not any(v == "HOOK-PORT-MEDIATED" for v in got_verdicts.values()):
        fails.append("POSITIVE CONTROL: no fixture resolved HOOK-PORT-MEDIATED. A "
                     "rejection-only suite is passed by a classifier that resolves nothing.")
    if not any(v == "HOOK-AMBIENT" for v in got_verdicts.values()):
        fails.append("TWO-SIDED CONTROL: no fixture resolved HOOK-AMBIENT, so nothing shows "
                     "the walk is sensitive to an ambient effect at all.")

    # THE READING'S OWN CONTROL: the twin pair must disagree.
    a = got_verdicts.get("control_registration_only")
    b = got_verdicts.get("control_hook_reaches_env")
    if a is None or b is None:
        fails.append("READING CONTROL: the twin fixtures are not both present")
    elif a == b:
        fails.append(f"READING CONTROL: `control_registration_only` and "
                     f"`control_hook_reaches_env` BOTH report {a}. They differ only in where "
                     f"the call sits, so agreement means this tool is measuring the file "
                     f"rather than hook reachability -- the exact fail-open WI-D15 rejected.")
    else:
        print(f"  ok  reading control            registration={a}, hook={b} -- they DISAGREE")

    # And the yield over the real fifteen, pinned in both directions.
    res = derive_hook_scope(repo, c3, producer, builtins, ext_fields)
    want = expected["yield"]
    if len(res) != want["extensions"]:
        fails.append(f"YIELD: expected {want['extensions']} extensions, got {len(res)}")
    for key, verdict in (("hook_port_mediated", "HOOK-PORT-MEDIATED"),
                         ("hook_ambient", "HOOK-AMBIENT")):
        got = sorted(e for e, r in res.items() if r["verdict"] == verdict)
        if got != sorted(want[key]):
            fails.append(f"YIELD {verdict}: expected {sorted(want[key])}, derived {got} "
                         f"(residue {sorted(set(got) ^ set(want[key]))})")
        else:
            print(f"  ok  yield {verdict:<20} {len(got)} of {len(res)}: {', '.join(got)}")

    # The registration SHAPE over the real tree, pinned per extension: which
    # extensions resolve through the 6.0 list head and how many atoms each
    # holds.  Empty on the 5.x tree; B8 re-pins it with seventeen entries.  A
    # pin in both directions, so an extension migrating early is noticed and a
    # list read short is noticed.
    got_lists = {e: r["atom_count"] for e, r in res.items()
                 if r["registration_shape"] == "capability-list"}
    want_lists = want.get("capability_list_atoms", {})
    if got_lists != want_lists:
        fails.append(f"YIELD capability-list atoms: expected {want_lists}, derived {got_lists}. "
                     f"Per-extension atom counts are the fail-closed denominator and must be "
                     f"re-pinned by hand, never inherited.")
    else:
        print(f"  ok  capability-list shape         {len(got_lists)} of {len(res)} extension(s) "
              f"register through the 6.0 list head")

    residue = sorted({n for r in res.values() for n in r["unresolved_callees"]})
    if residue != sorted(want["door_3_residue"]):
        fails.append(f"DOOR-3 RESIDUE: expected {sorted(want['door_3_residue'])}, got {residue}. "
                     f"This set is pinned because it is a PRODUCER gap, not a verdict: it must "
                     f"neither grow unnoticed nor be quietly assumed away.")
    else:
        print(f"  ok  door-3 residue              {', '.join(residue)}")

    # The shipped closure verdict must NOT have moved.  This item reports a
    # second reading; promoting one is an ADR-scope decision.
    closure = c3.derive(repo, do_provision=False)
    closure_clean = sorted(e for e, r in closure["extensions"].items()
                           if r["verdict"] == "PORT-MEDIATED")
    if closure_clean != sorted(want["closure_port_mediated"]):
        fails.append(f"SHIPPED VERDICT MOVED: closure PORT-MEDIATED is {closure_clean}, "
                     f"expected {sorted(want['closure_port_mediated'])}. WI-D15 measures a "
                     f"second reading and must not change the first.")
    else:
        print(f"  ok  shipped closure verdict    unmoved, {len(closure_clean)} of 15")

    print(f"\nhook-scope self-test: {len(fails)} failure(s)")
    for f in fails:
        print(f"  FAIL {f}")
    return 1 if fails else 0
