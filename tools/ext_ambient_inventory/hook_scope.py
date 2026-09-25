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

B8 NOTE (ADR-001 Phase B).  The paragraph above was measured over the 5.x
`ExtensionHooks` RECORD.  After B8 the ABI has no record and no
`default_hooks`: `register_with_config` returns a literal `[Capability]` list
(the B2 head), and that is the ONLY registration shape this tool reads.  The
record head, the `{ default_hooks(id) | ... }` update head and their two
rejection shapes (`hook-record-unresolvable`, `hook-slot-missing`) were
removed rather than kept beside the list head; anything that is not a literal
list reachable through delegation is `capability-list-unresolvable`.  The
argument stands unchanged: the hook-reachable text still lives in
`register.ail` for most extensions, now as constructor arguments.

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

THE REGISTRATION-SHAPE GATE (031 ADR-001 D2 layer (a), freeze item 8; PLAN-001 P0.3)
-------------------------------------------------------------------------------------
031's ADR-001 puts a SECOND, SEPARATE result beside the walk: the
registration-shape result, `pass | fail(reason)`, one per installable
extension.  It is the boundary half of freeze evidence 2(b): P0.2's suite
(`scripts/dst/fixtures/adr001_boundary/`) shows twelve constructions the bare
compiler accepts and performs; this field is what rejects them.  It is computed
from `locate` and the binding pass and NEVER from the walk's `rejections`,
because the walk emits `hook-binding-unresolvable` for an imported callee
outside the closure too, and on the real tree that fires for reasons unrelated
to any registration rule.  `emit_hook_scope` exits nonzero from this field
alone; the walk's HOOK-* verdicts are unchanged and stay an instrument.

The rule, as D2 states it, in AILANG's scoping order.  `register_with_config`
returns the 8.0 record `{ config, caps }` at its tail; `caps` is a LITERAL LIST
of constructor applications or a DELEGATED CALL to a named function that,
recursively, satisfies the rule; every function payload is a BARE NAME that
resolves, lexically at EVERY hop, to a top-level `func` of the home module or
an import, and is NOT `let`-bound or parameter-bound in the producing body or
in any delegated body on the path.  Resolution is locals and parameters first,
then the HOME module's imports, then the home module's own declarations --
never another closure module's, and never a closure-wide table keyed by bare
name, which resolved a clean `body` to an effectful `body` in another module.
This is stricter than the pinned compiler in one direction the ADR takes by
design: v0.33.0 resolves an IMPORTED name over a local of the same name (fact
6, N62), so a local that shadows an import is over-rejected here, and P0.2
scores those rows as a fourth, compiler-clean class.  A computed list, a
`match`-selected list, an unknown list, an inline lambda, a `let`-bound
lambda, a partial application and every other expression fail closed.

The 7.4 bare `[Capability]` list is still ENUMERATED -- the walk instrument and
the per-binding count need it, and the whole tree is on it until P1.2 -- but it
is a `return-shape-unsupported` failure of the shape result.  On the unmigrated
tree the gate is therefore red by the head on every extension AND by every
binding that is not a named top-level function; "green on the migrated tree"
means exactly that those bindings have moved (ADR D2, "The gate").  Counting
only binding rejections is not the criterion: a computed list produces zero of
them, because nothing is enumerated, and that is a failure of the result too.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

IDENT = r"[A-Za-z_][A-Za-z0-9_]*"

REGISTER_FUNC = "register_with_config"

#: THE 8.0 HEAD (031 ADR-001 D2; P0.4 writes the type): `register_with_config`
#: returns `ExtRegistration = { config: Json, caps: [Capability] }`.  The gate
#: reads the record LITERAL at the registration function's tail, with exactly
#: these two fields.  `config` is data and is not inspected; `caps` is the list.
REGISTRATION_FIELDS = ("config", "caps")

#: Where the gate's own fixtures live (PLAN-001 P0.3).  Underscore, not the
#: plan's hyphen: the pin refuses a hyphen in a module path (P0.2's §9 record).
SHAPE_GATE_FIXTURES = "scripts/dst/fixtures/adr001_boundary/gate"

#: B8: the 5.x `SLOTS` tuple (the eight `ExtensionHooks` fields and the tiling
#: assertion over them) and the `default_hooks` / `ABI_TYPES` update-head
#: resolution are gone with the record.  `CAPABILITY_KINDS` below is the
#: enumeration that now fails closed in their place.

#: THE 6.0 REGISTRATION SHAPE (ADR-001 Phase B, B2): `register_with_config`
#: returns a LITERAL LIST of capability-constructor applications,
#: `[Kind(arg, ...), ...]`, and every function-typed argument is a hook binding.
#: `kind -> (arity, function-typed argument positions)`, from the type-checked
#: `Capability` sketch (answer …9903186 / tmp/017-capability/capability.ail).
#: Held here rather than derived so that a variant added to the ABI makes this
#: tool FAIL on it (`capability-list-unresolvable`) rather than silently skip
#: the atom -- the discipline the 5.x `SLOTS` tuple carried.  "Literal lists
#: only": a list built by an expression is a rejection, and B8 makes that an
#: ABI rule.  8.0's two decision variants were added by 031 P0.5, below; until
#: then an atom of either kind was `list-not-enumerable` -- a failure, never a
#: skip.  Since P0.5 every row is ALSO checked against the ABI's own
#: `export type Capability` declaration (`abi_capability_arities`, run by the
#: self-test and by `--gate-fixtures`), so the table is hand-held for the
#: fail-closed reason above and cannot drift from the signature it transcribes.
CAPABILITY_KINDS: dict[str, tuple[int, tuple[int, ...]]] = {
    "DescribeTools": (1, (0,)),
    "PromptShaper": (1, (0,)),
    "BudgetShaper": (1, (0,)),
    "Compactor": (1, (0,)),
    "ToolPolicy": (1, (0,)),
    "ToolProvider": (2, (1,)),          # (names, handle); names is data, not a binding
    "ResponseInterceptor": (1, (0,)),
    "SolverJudge": (1, (0,)),
    # 7.0: (label, enabled, render). The first two are DATA -- the intent's name
    # and the operator opt-in resolved at registration -- and only the third is
    # a hook binding, exactly as `ToolProvider`'s names are data and its handle
    # is the binding.
    "ExitIntent": (3, (2,)),
    # 7.3: (label, render). `label` is DATA -- a word for diagnostics -- and the
    # render is the binding. No `enabled` third field: unlike the exit intent
    # this performs nothing, so there is no operator opt-in to resolve.
    "WorkInFlight": (2, (1,)),
    # 8.0 (031 ADR-001 D2): (descriptor, prepare, interpret). The descriptor is
    # DATA -- the policy's identity, versions and configs -- and both callbacks
    # are bindings, each keyed `Kind[i]@position`, and each goes through the
    # shape pass on its own: a named `prepare` does not excuse an inline
    # `interpret`.
    "DecisionSolverJudge": (3, (1, 2)),
    "DecisionToolPolicy": (3, (1, 2)),
}

#: Where the `Capability` declaration `CAPABILITY_KINDS` transcribes lives.
ABI_CAPABILITY_SOURCE = "packages/motoko-ext-abi/types.ail"


def _has_top_arrow(text: str) -> bool:
    """True when `->` occurs at bracket depth 0 -- a function TYPE, as opposed
    to data (`[string]`, `bool`, `DecisionPolicyDescriptor`) or a parenthesised
    type that only contains an arrow deeper down."""
    depth = 0
    for i, ch in enumerate(text):
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        elif ch == "-" and depth == 0 and text[i + 1:i + 2] == ">":
            return True
    return False


def abi_capability_arities(abi_text: str) -> dict[str, tuple[int, tuple[int, ...]]]:
    """`Capability` variant -> (arity, function-typed argument positions), read
    from the ABI's own declaration: the second producer `CAPABILITY_KINDS` is
    checked against (031 P0.5).  Comments are stripped line by line (no string
    literal occurs in the declaration); the block runs from `export type
    Capability` to the next `export`; variants split at depth-0 `|`, arguments
    at depth-0 `,`, and an argument is a binding exactly when its type is a
    function type.  An unreadable declaration is an empty map, which the caller
    reports as a failure rather than as agreement."""
    code = "\n".join(line.split("--", 1)[0] for line in abi_text.splitlines())
    m = re.search(r"^export type Capability\b\s*=(.*?)(?=^export\s)", code, re.M | re.S)
    if not m:
        return {}
    variants, depth, cur = [], 0, ""
    for ch in m.group(1):
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        if ch == "|" and depth == 0:
            variants.append(cur.strip())
            cur = ""
        else:
            cur += ch
    variants.append(cur.strip())
    out: dict[str, tuple[int, tuple[int, ...]]] = {}
    for v in variants:
        vm = re.fullmatch(rf"({IDENT})\s*(?:\((.*)\))?", v, re.S)
        if vm is None:
            return {}
        args = split_args(vm.group(2) or "")
        out[vm.group(1)] = (len(args), tuple(i for i, a in enumerate(args) if _has_top_arrow(a)))
    return out


def check_capability_arities(repo: Path) -> tuple[list[str], list[str]]:
    """Every `CAPABILITY_KINDS` row against its 8.0 signature, both directions:
    a variant the ABI declares and the table lacks, a row the ABI no longer
    declares, and an arity or binding position that disagrees are each a
    failure.  Returns `(failures, lines)`."""
    src = repo / ABI_CAPABILITY_SOURCE
    if not src.is_file():
        return [f"ABI ARITY: no ABI declaration at {ABI_CAPABILITY_SOURCE}"], []
    abi = abi_capability_arities(src.read_text())
    if not abi:
        return [f"ABI ARITY: `export type Capability` in {ABI_CAPABILITY_SOURCE} could not be "
                f"read, so no arity in CAPABILITY_KINDS is checked"], []
    fails, lines = [], []
    for kind in sorted(set(abi) | set(CAPABILITY_KINDS)):
        if kind not in CAPABILITY_KINDS:
            fails.append(f"ABI ARITY: the ABI declares `{kind}` {abi[kind]} and CAPABILITY_KINDS "
                         f"does not enumerate it -- an atom of it would be `list-not-enumerable`")
        elif kind not in abi:
            fails.append(f"ABI ARITY: CAPABILITY_KINDS enumerates `{kind}`, which the ABI does "
                         f"not declare")
        elif abi[kind] != CAPABILITY_KINDS[kind]:
            fails.append(f"ABI ARITY: `{kind}` is (arity, bindings) {abi[kind]} in the ABI and "
                         f"{CAPABILITY_KINDS[kind]} in CAPABILITY_KINDS")
        else:
            lines.append(f"  ok  arity {kind:<22} {abi[kind][0]} arg(s), binding(s) at "
                         f"{list(abi[kind][1])}")
    return fails, lines

#: Rejection shapes this module adds to the parent's five.  Each is a REJECTION
#: of the WALK -- the instrument.  B8 removed `hook-record-unresolvable` and
#: `hook-slot-missing` with the record.
HOOK_SHAPES = {
    "capability-list-unresolvable": "`register_with_config`'s tail (possibly behind delegation "
                                    "hops such as `make_hooks(cfg)`) is not a LITERAL LIST (the "
                                    "6.0 `[Capability]` shape) this tool can enumerate atom by "
                                    "atom: no `register_with_config`, an unresolvable or "
                                    "over-deep delegation, a tail that is neither a list nor a "
                                    "call, an element that is not `Kind(arg, ...)` for a known "
                                    "capability constructor, a computed or spread element, a wrong "
                                    "arity, a list built by an expression (`xs ++ ys`, a "
                                    "conditional), or an element count that does not match the "
                                    "atoms emitted. Over a list there is no tiling to assert, so "
                                    "the fail-closed denominator is the element count, and an "
                                    "atom this tool did not read is an atom nothing scanned",
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

#: THE REGISTRATION-SHAPE RESULT'S OWN REJECTION SHAPES (031 ADR-001 D2 (a),
#: N43, N52, N63).  Disjoint from `HOOK_SHAPES`: a shape rejection is a failure
#: of the GATE and never of the walk, and a walk rejection never fails the gate.
#: Every one of these is exercised by a fixture under `SHAPE_GATE_FIXTURES`,
#: and the self-test refuses a reason no fixture reaches.
SHAPE_REASONS = {
    "registration-missing": "the closure root has no readable `register_with_config` "
                            "declaration, so there is no registration to judge",
    "return-shape-unsupported": "`register_with_config`'s tail is not the 8.0 record literal "
                                "`{ config, caps }` (ADR D2): the 7.4 bare `[Capability]` list, "
                                "a record with other fields, a record reached only behind a "
                                "delegation, or an expression that is neither. The bare list is "
                                "still enumerated so the walk and the binding count can run; "
                                "it is a failure of the result all the same",
    "caps-computed": "`caps` is built by an expression -- a conditional, a concatenation "
                     "(`xs ++ ys`), a spread, or a list that is not a literal to its last "
                     "bracket. Fact 6's `if … then [ToolPolicy(…)] else []` compiles and "
                     "performs, and a reader that enumerates only literal lists never sees "
                     "its payload",
    "caps-match-selected": "`caps` is selected by a `match`. Each arm may bind a different "
                           "payload and the reader cannot enumerate which one registers",
    "caps-unknown": "`caps` is a name or an expression the reader cannot resolve to a literal "
                    "list or to a delegated call of a named top-level function -- a "
                    "`let`-bound list, a field read, a value threaded through a parameter",
    "delegation-let-bound": "the delegated callee that returns `caps` is `let`-bound in a body "
                            "on the path (fact 6, `delegate_shadow`): a local `let make_hooks` "
                            "over a top-level `func make_hooks` registers the LOCAL, and a "
                            "reader that resolves the name to the declaration certifies a "
                            "callback that never runs. Over an IMPORTED `make_hooks` the pinned "
                            "compiler runs the import (N62); the rule rejects the local anyway",
    "delegation-parameter-bound": "the delegated callee that returns `caps` is a PARAMETER of a "
                                  "body on the path (`v7_delegate_param`): whatever the caller "
                                  "passed runs, and a reader that never read a signature "
                                  "certified the declaration of the same name",
    "delegation-unresolved": "the delegated callee that returns `caps` resolves to no top-level "
                             "`func` in its home module or the home module's imports within "
                             "the closure, or the delegation exceeds the hop limit",
    "list-not-enumerable": "the capability list was reached but could not be enumerated atom "
                           "by atom: an element that is not `Kind(arg, ...)`, an unknown "
                           "constructor, a wrong arity, a spread, an empty element, or a "
                           "head count that disagrees with the atoms emitted",
    "payload-inline-lambda": "a function payload is an inline function expression (`func(…) "
                             "{ … }` or `\\ctx. …`). Fact 1: an inline lambda may call a field "
                             "its parameter type does not have and `ailang check` accepts it; "
                             "fact 4: it may capture a locally-typed record holding an "
                             "effectful lambda. Every payload is a named top-level function",
    "payload-let-bound": "a function payload is a bare name that is `let`-bound in the "
                         "producing body or a delegated body on the path (fact 5, "
                         "`q_named_shadow`): a local `let body = func(…)` over a top-level "
                         "`func body` registers the lambda. Over an IMPORTED `body` the pinned "
                         "compiler runs the import (N62); the rule rejects the local anyway",
    "payload-parameter-bound": "a function payload is a bare name that is a PARAMETER of a "
                               "body on the path (`v7_param_shadow`): `make_hooks(body: (Ctx) "
                               "-> int)` binds whatever its caller passed under the name of a "
                               "top-level function",
    "payload-partial-application": "a function payload is a call -- a partial application such "
                                   "as `Pure(apply_w(w))` (`q_named_partial`) -- whose value is a "
                                   "function built at registration from what it captured",
    "payload-not-a-name": "a function payload is an expression that is neither a bare name "
                          "nor an inline function -- a field read, a parenthesised value, a "
                          "constructor -- and the rule admits only a bare name",
    "payload-unresolved": "a function payload is a bare name that resolves to no top-level "
                          "`func` in its home module or the home module's imports within the "
                          "closure (a `std/*` import is not a hooks producer either)",
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
            # THE DELIMITERS SURVIVE, and only the TEXT is blanked -- which is
            # what this function's name and docstring have always claimed.
            # Blanking the quotes too made a string-literal argument
            # INDISTINGUISHABLE FROM AN ABSENT ONE, and the capability-list
            # reader rejects an empty argument as `Kind(, f)`. ABI 7.0's
            # `ExitIntent("label", enabled, render)` is the first atom in the
            # tree with a literal in a DATA position, and it was rejected as a
            # wrong-arity application ("applied to 3 argument(s); the
            # constructor takes 3" -- the emptiness half of the same check).
            # Keeping the quotes costs nothing downstream: no matcher here
            # reads `"` as an identifier, and `balanced`/`split_args` count only
            # brackets, so offsets and depths are unchanged.
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


def _prefix_of(body: str, tail: str) -> str:
    """The registration text BEFORE the tail expression -- what runs at install."""
    return body[:len(body) - len(tail)] if body.endswith(tail) else body


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


def _whole_group(expr: str, open_ch: str, close_ch: str) -> str | None:
    """The inside of `expr` when the WHOLE of it is one balanced group, else None.

    `balanced` returns the leading group and is happy with `[x].head` or
    `{ a: 1 }.a`; the heads below need the group to run to the last character,
    so a trailing field read or operator cannot ride on a literal.
    """
    e = expr.strip()
    if not e.startswith(open_ch) or not e.endswith(close_ch):
        return None
    depth = 0
    for i, ch in enumerate(e):
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
            if depth == 0:
                return e[1:i] if i == len(e) - 1 else None
    return None


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


def record_fields(expr: str) -> dict[str, str] | None:
    """`{ f: e, g: e }` -> {f: e, g: e}, or None when `expr` is not a plain record literal.

    The 8.0 head is a record LITERAL with two named fields.  A block body
    (`{ let x = …; x }`), a record update (`{ r | f: v }`) and a record with a
    trailing operator are all None here and fail closed at the caller.
    """
    inner = _whole_group(expr, "{", "}")
    if inner is None:
        return None
    fields: dict[str, str] = {}
    for part in split_args(inner):
        m = re.fullmatch(rf"({IDENT})\s*:\s*(.*)", part, re.S)
        if m is None:
            return None
        fields[m.group(1)] = m.group(2).strip()
    return fields


def _has_depth0(text: str, token: str) -> bool:
    depth = 0
    for i, ch in enumerate(text):
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        elif depth == 0 and text.startswith(token, i):
            return True
    return False


def classify_caps(expr: str) -> str:
    """Why a `caps` expression that is neither a literal list nor a call fails."""
    e = expr.strip()
    if re.match(r"match\b", e):
        return "caps-match-selected"
    if re.match(r"if\b", e) or e.startswith("[") or e.startswith("...") or _has_depth0(e, "++"):
        return "caps-computed"
    return "caps-unknown"


def top_level_constructor_heads(text: str) -> int:
    """The number of depth-0 capability-constructor heads `Kind(` in `text` --
    the INDEPENDENT atom count.

    Independent in the way that matters, which a depth-0 COMMA count was not:
    the element parser splits `text` on depth-0 commas and then emits exactly
    one atom per element, so counting those same commas is the same measurement
    twice and cannot disagree with it -- a denominator that reads as fail-closed
    and is in fact unreachable.  Counting constructor HEADS measures a different
    feature of the same text, and it disagrees on precisely the shape the
    element parser gets wrong:

        [ToolPolicy(p) ++ PromptShaper(q)]

    is ONE comma-delimited element, and `Kind\\s*\\((.*)\\)` accepts it whole --
    the greedy `.*` swallows `p) ++ PromptShaper(q` -- so the parser emits ONE
    atom for TWO capabilities and the comma count agrees with it.  Two heads
    against one atom is the rejection that catches it.

    Heads inside an argument (`Compactor(pick(SolverJudge(j)))`) sit at depth
    >= 1 and are not elements, so they are not counted.
    """
    depths, depth = [], 0
    for ch in text:
        depths.append(depth)
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
    return sum(1 for m in re.finditer(rf"\b({IDENT})\s*\(", text)
               if depths[m.start()] == 0 and m.group(1) in CAPABILITY_KINDS)


# --------------------------------------------------------------------------
# signatures and bodies
# --------------------------------------------------------------------------

def _params_at(text: str, pos: int) -> tuple[tuple[str, ...], int] | None:
    """The parameter NAMES of the `(...)` at or just after `pos`, and the offset
    after its closing parenthesis; None when no parameter list starts there.

    P0.3 (031 ADR-001 N63): until this function existed the signature was
    DISCARDED -- `func_body` skipped straight to the body -- and parameters were
    never read, which is how a payload or a delegated callee bound to a
    PARAMETER that shadows a top-level function was certified as named
    (`v7_param_shadow`, `v7_delegate_param`).  A leading `[..]` type-parameter
    list is skipped.  A name is the text before its `:` annotation; a
    destructuring pattern that is not an identifier contributes nothing.
    """
    n = len(text)
    i = pos
    while i < n and text[i].isspace():
        i += 1
    if i < n and text[i] == "[":
        depth = 0
        while i < n:
            if text[i] == "[":
                depth += 1
            elif text[i] == "]":
                depth -= 1
                if depth == 0:
                    i += 1
                    break
            i += 1
        while i < n and text[i].isspace():
            i += 1
    if i >= n or text[i] != "(":
        return None
    depth, j = 0, i
    while j < n:
        if text[j] in "([{":
            depth += 1
        elif text[j] in ")]}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    names = []
    for part in split_args(text[i + 1:j]):
        p = part.split(":")[0].strip()
        if re.fullmatch(IDENT, p):
            names.append(p)
    return tuple(names), j + 1


def func_body(text: str, name: str) -> tuple[str, tuple[str, ...]] | None:
    """`(body, parameter names)` of `func <name>`, skipping the effect row.

    An AILANG signature ends `-> T ! {IO, Clock} {`, so the first `{` after the
    header is the EFFECT ROW.  Taking it yields a fragment in which nothing is
    ever found -- the parent tool records this as the single most expensive bug
    in its history, and the same trap is here.

    P0.3: the parameter names come back BESIDE the body (N63).  Every caller
    that resolves a name through this body's scope reads them first.
    """
    m = re.search(rf"^\s*(?:export\s+)?(?:pure\s+)?func\s+{re.escape(name)}\b", text, re.M)
    if not m:
        return None
    sig = _params_at(text, m.end())
    params, after = sig if sig is not None else ((), m.end())
    # AILANG has TWO declaration forms and this tree uses both.  The
    # expression-bodied one --
    #   `export func bridge_path() -> Result[string, string] ! {FS} = <expr>`
    # (`motoko-ext-mcp/assets.ail:20`) -- has no brace body at all, so a
    # brace-only reader returns None and the caller rejects a perfectly
    # resolvable function.  Its body runs to the next top-level declaration.
    eq = _expression_body(text, after)
    if eq is not None:
        return (eq, params)
    b = _body_at(text, m.end())
    return (b[0], params) if b is not None else None


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


def _body_at(text: str, pos: int) -> tuple[str, tuple[str, ...]] | None:
    """`(body, parameter names)` of the function whose parameter list starts at
    or after `pos`; the brace-balanced body skips effect rows.

    An effect row is recognised SYNTACTICALLY, by the `!` that introduces it, and
    NOT by its contents.  The content test the parent tool uses -- "a bare
    comma-separated list of capitalised names" -- is a fail-open here, because
    this tree's hook bodies are things like `{ NoOpinion }`, `{ Delegate }` and
    `{ PassThrough }`.  Every one of those matches the content pattern exactly,
    so a content-testing reader skips the real body, finds nothing after it, and
    reports the hook as unresolvable -- or, worse, walks on to an unrelated brace.
    Measured at WI-D15 on `a2a` and `mcp`, whose `on_tool_policy` is
    `func(...) -> ToolPolicyDecision { NoOpinion }` with no effect row at all.

    P0.3: the parameter list is read BEFORE the body is looked for, and comes
    back beside it -- both for `func name(...)` and for an inline `func(...)`.
    """
    sig = _params_at(text, pos)
    params, i = sig if sig is not None else ((), pos)
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
            return (text[i + 1:j], params)
        i += 1
    return None


def lambda_body(expr: str) -> tuple[str, tuple[str, ...]] | None:
    """`(reachable text, parameter names)` of an inline hook binding, or None if
    it is not one.

    Two forms, and both are in this tree:
      `func(ctx: ExtCtx, m) -> T ! {..} { body }`  -- brace body after the row
      `\\ctx _. expr`                              -- everything after the dot
    """
    e = expr.strip()
    if e.startswith("func") and re.match(r"func\s*[\[(]", e):
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
                params = tuple(p for p in e[1:i].split() if re.fullmatch(IDENT, p))
                return (e[i + 1:], params)
        return None
    return None


def let_bindings(body: str) -> dict[str, str]:
    """`let x = <expr>;` and `let x: T = <expr>;` -> {x: expr}.

    Every `let` in the text, at ANY depth, is collected: the value scan stops at
    the first `;` at depth 0 relative to the binding.  For the walk that is what
    "a local of this text" means, since the walk scans applications at every
    depth too.  For the shape rule it is the ADR's phrase "let-bound in the
    producing body or in any delegated body on the path" read at its widest,
    which over-rejects a nested `let body` that a payload could not lexically
    see -- the fail-closed direction, taken on purpose.
    """
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
                "why": HOOK_SHAPES.get(self.shape) or SHAPE_REASONS.get(self.shape, "")}


class Hop:
    """One body on the registration path: `(module, parameters, lets)` (N63).

    `Scope.locate` records one of these per delegation hop instead of
    overwriting a single `producing_body`: the ADR's rule looks a name up in
    the calling body's locals and parameters first, and "the calling body" is a
    different function at every hop.  `name` is for the rejection text.
    """
    __slots__ = ("module", "name", "params", "lets")

    def __init__(self, module: Path, name: str, params, lets: dict[str, str]):
        self.module, self.name = module, name
        self.params: frozenset[str] = frozenset(params)
        self.lets = lets


class Scope:
    """One extension's hook-reachable scope, and the registration scope beside it.

    `mods` and `texts` come from the parent tool's closure so that both answers
    quantify over exactly the same source.  The only thing that differs is which
    part of it a hook can reach.
    """

    def __init__(self, ext: str, root: Path, mods: list[Path], repo: Path, resolve):
        self.ext, self.root, self.repo, self.resolve = ext, root.resolve(), repo, resolve
        #: the registration HEAD once located: "config-caps" (8.0, the
        #: `{ config, caps }` record) or "capability-list" (the 7.4 bare list,
        #: enumerated and failed); None when no list was reached.  The 5.x
        #: "record" value and the update head went with B8.
        self.registration_shape: str | None = None
        #: the atoms of a capability-list registration, keyed (kind, index)
        #: where `index` counts WITHIN the kind, plus the list `position`.
        self.atoms: list[dict] = []
        self.mods = [p.resolve() for p in mods]
        # door 4: interpolation-preserving, NOT the parent's `strip_noise`
        self.texts = {p: keep_interpolations(p.read_text(errors="replace")) for p in self.mods}
        #: the WALK's rejections -- the instrument's
        self.rejections: list[Rejection] = []
        #: the REGISTRATION-SHAPE result's rejections -- the gate's.  Disjoint
        #: from `rejections` by construction: nothing here is read from there.
        self.shape_rejections: list[Rejection] = []

        # THE DECLARATION TABLE IS PER HOME MODULE (N63).  A closure-wide table
        # keyed by bare name resolved a clean `body` to an effectful `body` in
        # another module; a name is declared in ONE module and is visible in
        # another only through that module's imports.
        self.decls: dict[Path, set[str]] = {}
        self.types: set[str] = set()
        for p, tx in self.texts.items():
            self.decls[p] = {m.group(1) for m in _DECL.finditer(tx)}
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
        #: slot -> (the chain of hops the binding was written under, its expression)
        self.bindings: dict[str, tuple[list[Hop], str]] = {}
        self.registration_text: str = ""
        self.reached: list[tuple[Path, str]] = []
        self.delegation_hops = 0
        #: the registration path, `register_with_config` first, the body that
        #: holds the list last (N63: per hop, never one overwritten body)
        self.chain: list[Hop] = []
        #: door-3 residue: applied names no producer at HEAD can classify.  Kept
        #: per extension so the counterfactual yield is derived from the tool's
        #: own findings rather than asserted beside them.
        self.unresolved_callees: set[str] = set()

    # -- the two kinds of rejection ------------------------------------------

    def _shape_reject(self, reason: str, where: Path, detail: str) -> None:
        assert reason in SHAPE_REASONS, reason
        self.shape_rejections.append(Rejection(reason, self._rel(where), detail))

    def _walk_reject(self, shape: str, where: Path, detail: str) -> None:
        assert shape in HOOK_SHAPES, shape
        self.rejections.append(Rejection(shape, self._rel(where), detail))

    # -- locating the bindings ---------------------------------------------

    def locate(self) -> bool:
        """Find the registration head and enumerate its capability list, through
        delegation hops, recording the shape result as it goes.

        Returns True when the bindings were ENUMERATED (the walk may run), which
        is independent of the shape result: the 7.4 bare list enumerates and
        fails the shape; a computed `caps` fails the shape and enumerates
        nothing.  Every failure to enumerate is also `capability-list-unresolvable`
        for the walk -- fail closed on both answers, never a pass on either."""
        text = self.texts.get(self.root)
        if text is None:
            self._shape_reject("registration-missing", self.root,
                               "the closure root is not a readable module")
            self._walk_reject("capability-list-unresolvable", self.root,
                              "the closure root is not a readable module")
            return False
        sig = func_body(text, REGISTER_FUNC)
        if sig is None:
            self._shape_reject("registration-missing", self.root,
                               f"no `{REGISTER_FUNC}` declaration")
            self._walk_reject("capability-list-unresolvable", self.root,
                              f"no `{REGISTER_FUNC}` declaration")
            return False
        body, params = sig
        expr = tail_expression(body)
        self.registration_text = _prefix_of(body, expr)
        chain = [Hop(self.root, REGISTER_FUNC, params, let_bindings(body))]

        # THE 8.0 HEAD: the record literal `{ config, caps }` at the tail.
        rec = record_fields(expr)
        if rec is not None:
            if sorted(rec) != sorted(REGISTRATION_FIELDS):
                self._shape_reject("return-shape-unsupported", self.root,
                                   f"the registration record has fields {sorted(rec)}; the 8.0 "
                                   f"head is `{{ config, caps }}` and nothing else")
                self._walk_reject("capability-list-unresolvable", self.root,
                                  f"registration record has fields {sorted(rec)}, not "
                                  f"`{{ config, caps }}`")
                return False
            self.registration_shape = "config-caps"
            return self._locate_caps(chain, rec["caps"], legacy=False)

        # THE 7.4 HEAD: a bare list, or a delegated call whose tail is one.
        # Enumerated for the walk and for the binding count; failed for the
        # shape (see the module docstring).  A record found only BEHIND a
        # delegation is not the 8.0 head either: the rule wants the record at
        # `register_with_config`'s tail and the delegation at `caps`.
        return self._locate_caps(chain, expr, legacy=True)

    def _locate_caps(self, chain: list[Hop], expr: str, legacy: bool) -> bool:
        """Follow `expr` -- the record's `caps`, or on the 7.4 head the whole
        registration tail -- through delegation hops to a literal list, then
        enumerate it and run the binding pass.

        Every hop is resolved through `chain` (locals and parameters of every
        body on the path first, then the home module's imports, then its
        declarations) and the chain GROWS by one `Hop` per delegation.
        """
        hops = 0
        while True:
            home = chain[-1].module
            e = expr.strip()
            inner = _whole_group(e, "[", "]")
            if inner is not None:
                if legacy:
                    self.registration_shape = "capability-list"
                    self._shape_reject(
                        "return-shape-unsupported", home,
                        f"`{REGISTER_FUNC}` returns the 7.4 bare `[Capability]` list"
                        + (f" through `{chain[-1].name}`" if hops else "")
                        + " -- the 8.0 head is the record `{ config, caps }` at the "
                          "registration tail (ADR D2); the list is enumerated below so its "
                          "bindings are counted, and the head is a failure all the same")
                self.chain = chain
                self.hook_home = home
                self.delegation_hops = hops
                return self._locate_capability_list(chain, inner)
            if legacy and record_fields(e) is not None:
                self._shape_reject(
                    "return-shape-unsupported", home,
                    f"the `{{ config, caps }}` record is written in `{chain[-1].name}`, "
                    f"{hops} hop(s) behind `{REGISTER_FUNC}` -- the rule wants the record "
                    f"at the registration tail and admits delegation at `caps` only")
                self._walk_reject("capability-list-unresolvable", home,
                                  f"registration record reached only behind {hops} delegation "
                                  f"hop(s), in `{chain[-1].name}`")
                return False
            m = re.match(rf"({IDENT})\s*\(", e)
            if m is None or not e.endswith(")") or _whole_group(e[m.end() - 1:], "(", ")") is None:
                reason = classify_caps(e)
                what = "the registration tail" if legacy else "`caps`"
                if legacy:
                    # the 7.4 head's tail IS its caps: not the record (the head
                    # is unsupported) AND not a list this reader can enumerate
                    self._shape_reject("return-shape-unsupported", home,
                                       f"`{REGISTER_FUNC}`'s tail `{e[:60]}` is not the 8.0 "
                                       f"record `{{ config, caps }}`")
                self._shape_reject(reason, home,
                                   f"{what} `{e[:60]}` is neither a literal list nor a call to "
                                   f"a named function -- {reason.split('-', 1)[1].replace('-', ' ')}")
                self._walk_reject("capability-list-unresolvable", home,
                                  f"tail expression `{e[:60]}` builds the capability list by an "
                                  f"expression rather than writing it as a literal -- literal lists only"
                                  if reason != "caps-unknown" else
                                  f"tail expression `{e[:60]}` is neither a literal list nor a call")
                return False
            callee = m.group(1)
            if hops >= MAX_DELEGATION_HOPS:
                self._shape_reject("delegation-unresolved", home,
                                   f"delegation exceeded {MAX_DELEGATION_HOPS} hops at `{e[:60]}`")
                self._walk_reject("capability-list-unresolvable", home,
                                  f"delegation exceeded {MAX_DELEGATION_HOPS} hops at `{e[:60]}`")
                return False
            r = self._resolve_func(chain, callee)
            if r is None:
                self._shape_reject("delegation-unresolved", home,
                                   f"`{callee}` returns `caps` and resolves to no top-level `func` "
                                   f"in `{self._rel(home)}` or its imports within the closure")
                self._walk_reject("capability-list-unresolvable", home,
                                  f"`{callee}` returns the capability list but resolves to no "
                                  f"declaration in this closure")
                return False
            if r[0] == "shadow":
                _, kind, hop = r
                self._shape_reject(
                    "delegation-let-bound" if kind == "let" else "delegation-parameter-bound",
                    home, self._shadow_detail(callee, kind, hop, "returns `caps`"))
                self._walk_reject("capability-list-unresolvable", home,
                                  f"`{callee}` returns the capability list and is a {kind} of "
                                  f"`{hop.name}`, not a declaration")
                return False
            _, module, fbody, fparams = r
            inner_tail = tail_expression(fbody)
            # the delegated function may perform registration effects of its own
            self.registration_text += _prefix_of(fbody, inner_tail)
            chain = chain + [Hop(module, callee, fparams, let_bindings(fbody))]
            expr = inner_tail
            hops += 1

    def _shadow_detail(self, name: str, kind: str, hop: Hop, role: str) -> str:
        home = self.chain[-1].module if self.chain else hop.module
        also = []
        if name in self.decls.get(hop.module, set()):
            also.append(f"shadows the top-level `func {name}` of `{self._rel(hop.module)}`")
        imp = self.imports.get(hop.module, {}).get(name)
        if imp is not None:
            also.append(f"shadows the import of `{imp[1]}` from `{imp[0]}` -- the pinned "
                        f"compiler (v0.33.0) resolves the IMPORT over the local (N62); the "
                        f"rule takes the local, which is the fail-closed direction")
        bound = (f"is `let`-bound in `{hop.name}`" if kind == "let"
                 else f"is a parameter of `{hop.name}`")
        return f"`{name}` {role} and {bound}" + (" -- " + "; ".join(also) if also else "")

    def _locate_capability_list(self, chain: list[Hop], body: str) -> bool:
        """`Kind(arg, ...), Kind(arg, ...)` -> atoms + bindings, or a rejection.

        Every element must be an application of a constructor in
        `CAPABILITY_KINDS` at its arity; every function-typed argument becomes a
        binding keyed `Kind[index]` (index within the kind), which `walk`
        resolves exactly as it resolves a record slot: an inline lambda to its
        text, a bare name to its declaration's BODY.  A wide-rowed named
        function is therefore scanned, not trusted -- its row bounds nothing
        in constructor-argument position (B1's probe).  Anything else is
        `capability-list-unresolvable` for the walk and `list-not-enumerable`
        for the shape, and so is any disagreement between the depth-0
        constructor-head count and the atoms emitted -- see
        `top_level_constructor_heads` for why the heads, and not the commas the
        split itself reads, are what makes that a live check.  Once enumerated,
        every binding goes through the SHAPE pass (`_shape_of_binding`)."""
        home = chain[-1].module
        elements = split_args(body)
        expected = top_level_constructor_heads(body)
        per_kind: dict[str, int] = {}
        bindings: dict[str, tuple[list[Hop], str]] = {}
        atoms: list[dict] = []

        def fail(detail: str) -> bool:
            self._shape_reject("list-not-enumerable", home, detail)
            self._walk_reject("capability-list-unresolvable", home, detail)
            return False

        for pos, el in enumerate(elements):
            if not el:
                return fail(f"capability list element {pos} is empty (a trailing or doubled "
                            f"comma) -- the {expected} constructor head(s) cannot be reconciled "
                            f"with the atoms")
            if el.startswith("..."):
                return fail(f"capability list element {pos} is a spread `{el[:40]}` -- its atoms "
                            f"are text this tool has not read")
            m = re.fullmatch(rf"({IDENT})\s*\((.*)\)", el, re.S)
            if m is None:
                return fail(f"capability list element {pos} `{el[:60]}` is not a constructor "
                            f"application `Kind(arg, ...)` -- a computed element is an atom this "
                            f"tool cannot enumerate")
            kind, argtext = m.group(1), m.group(2)
            if kind not in CAPABILITY_KINDS:
                return fail(f"capability list element {pos} applies `{kind}`, which is not one of "
                            f"the {len(CAPABILITY_KINDS)} capability constructors this tool "
                            f"enumerates -- a new ABI variant must be added to CAPABILITY_KINDS, "
                            f"not scanned around")
            arity, fn_args = CAPABILITY_KINDS[kind]
            args = split_args(argtext)
            if len(args) != arity or any(not a for a in args):
                return fail(f"`{kind}` at element {pos} is applied to {len(args)} argument(s); "
                            f"the constructor takes {arity}")
            idx = per_kind.get(kind, 0)
            per_kind[kind] = idx + 1
            for ai in fn_args:
                key = f"{kind}[{idx}]" if len(fn_args) == 1 else f"{kind}[{idx}]@{ai}"
                bindings[key] = (chain, args[ai])
            atoms.append({"kind": kind, "index": idx, "position": pos,
                          "binding": args[fn_args[0]][:40]})
        if len(atoms) != expected:
            return fail(f"the capability list holds {expected} depth-0 constructor head(s) and "
                        f"{len(atoms)} atom(s) were emitted -- an atom was dropped or two were "
                        f"read as one, which is fail-open")
        self.atoms = atoms
        self.bindings = bindings
        # THE BINDING PASS: the shape rule over every payload, in chain order.
        for slot, (ch, expr) in bindings.items():
            self._shape_of_binding(ch, slot, expr)
        return True

    def _rel(self, p: Path) -> str:
        try:
            return str(p.relative_to(self.repo))
        except ValueError:
            return str(p)

    def _resolve_func(self, chain: list[Hop], name: str):
        """`name`, looked up in AILANG's scoping order and stricter (ADR D2 (a)):

          1. the locals and parameters of EVERY body on `chain` -- a hit is
             `("shadow", "let" | "param", hop)`, never a resolution;
          2. the HOME module's imports (the last hop's module) -- resolved to
             the imported module's declaration when that module is in the
             closure; a `std/*` import or a module outside the closure is None;
          3. the home module's own declarations -- `("func", module, body, params)`.

        Never the closure-wide table: a name declared in another module is
        reachable only through an import, and resolving it anyway is how a
        clean `body` stood in for an effectful one (N63).
        """
        for hop in reversed(chain):
            if name in hop.lets:
                return ("shadow", "let", hop)
            if name in hop.params:
                return ("shadow", "param", hop)
        home = chain[-1].module
        imp = self.imports.get(home, {}).get(name)
        if imp is not None:
            mpath, src = imp
            if mpath.startswith("std/"):
                return None                       # a std symbol is not a hooks producer
            kind, target = self.resolve(mpath)
            if kind == "file":
                t = target.resolve()
                if t in self.texts:
                    fb = func_body(self.texts[t], src)
                    if fb is not None:
                        return ("func", t, fb[0], fb[1])
            return None
        if name in self.decls.get(home, set()):
            fb = func_body(self.texts[home], name)
            if fb is not None:
                return ("func", home, fb[0], fb[1])
        return None

    # -- the shape pass ----------------------------------------------------

    def _shape_of_binding(self, chain: list[Hop], slot: str, expr: str) -> None:
        """The shape rule over one payload: a bare name resolving through the
        chain to a top-level `func` of the home module or an import PASSES;
        everything else records its own reason (N42, N51, N62)."""
        home = chain[-1].module
        e = expr.strip()
        if lambda_body(e) is not None:
            self._shape_reject("payload-inline-lambda", home,
                               f"{slot} is bound to the inline function `{e[:50]}`")
            return
        if re.fullmatch(IDENT, e):
            r = self._resolve_func(chain, e)
            if r is None:
                self._shape_reject("payload-unresolved", home,
                                   f"{slot} is bound to `{e}`, which resolves to no top-level "
                                   f"`func` in `{self._rel(home)}` or its imports within the closure")
            elif r[0] == "shadow":
                _, kind, hop = r
                self._shape_reject(
                    "payload-let-bound" if kind == "let" else "payload-parameter-bound",
                    home, f"{slot}: " + self._shadow_detail(e, kind, hop, "is the payload"))
            return
        if re.fullmatch(rf"{IDENT}\s*\(.*\)", e, re.S):
            self._shape_reject("payload-partial-application", home,
                               f"{slot} is bound to the call `{e[:50]}` -- a function value built "
                               f"at registration, not a named function")
            return
        self._shape_reject("payload-not-a-name", home,
                           f"{slot} is bound to `{e[:50]}`, which is neither a bare name nor an "
                           f"inline function")

    def registration_shape_result(self) -> dict:
        """`pass | fail(reason)` -- THE GATE'S OWN FIELD (ADR D2 "The gate", N43,
        N52).  Pass exactly when the head is the 8.0 record, the list was
        enumerated, and the binding pass and every delegation hop recorded
        nothing.  Read from `shape_rejections` only; never from `rejections`."""
        if self.registration_shape == "config-caps" and not self.shape_rejections:
            return {"result": "pass", "head": self.registration_shape, "atoms": len(self.atoms)}
        return {"result": "fail", "head": self.registration_shape,
                "reasons": [r.as_dict() for r in self.shape_rejections]}

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
        stack: list[tuple[list[Hop], str, str]] = []

        for slot, (chain, expr) in self.bindings.items():
            r = self._binding_text(chain, slot, expr)
            if r is not None:
                stack.append((r[0], r[1], slot))

        while stack:
            chain, text, slot = stack.pop()
            home = chain[-1].module
            self.reached.append((home, slot))
            # Locals visible here are this text's OWN binders plus everything
            # every body on its chain bound.  Door 6's dangerous corner lives in
            # the second half: `let injected = cfg.callback;` in
            # `register_with_config`, applied inside an inline hook body.  Scoping
            # the lookup to the hook body alone reports that as `unknown-callee`
            # -- still a rejection, so no verdict moves, but it names the wrong
            # thing, and a rejection a reader cannot triage is one they will
            # eventually wave through.  A NAMED callee's chain is its own hop
            # alone: a top-level function captures nothing.
            locals_here = (set(let_bindings(text)) | _param_names(text)
                           | {n for h in chain for n in h.params}
                           | {n for h in chain for n in h.lets})
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
                        self._walk_reject(
                            "applied-local", home,
                            f"`.{name}(...)` at line {line} is a field call on a value this tool "
                            f"cannot resolve to an `ExtPorts`-typed receiver")
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
                if imp is not None and imp[0].startswith("std/"):
                    mpath, src = imp
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

                # Everything else resolves through the CHAIN: locals and
                # parameters of every body on it first, then the home module's
                # imports, then its declarations (N63) -- the same order the
                # shape pass uses, so the walk cannot certify a callee the gate
                # would reject.
                r = self._resolve_func(chain, name)
                if r is None:
                    if imp is not None:
                        self._walk_reject(
                            "hook-binding-unresolvable", home,
                            f"`{name}` is imported from `{imp[0]}` and resolves to no declaration "
                            f"this closure holds")
                    elif name in locals_here:
                        self._walk_reject(
                            "applied-local", home,
                            f"`{name}` is a local or parameter and is APPLIED at line {line}")
                    else:
                        self.unresolved_callees.add(name)
                        self._walk_reject(
                            "unknown-callee", home,
                            f"`{name}` is applied at line {line} and resolves to no declaration, "
                            f"import or builtin with producer evidence")
                    continue
                if r[0] == "shadow":
                    _, kind, hop = r
                    self._walk_reject(
                        "applied-local", home,
                        f"`{name}` is a {'local' if kind == 'let' else 'parameter'} of "
                        f"`{hop.name}` and is APPLIED at line {line}")
                    continue
                _, module, fbody, fparams = r
                stack.append(([Hop(module, name, fparams, let_bindings(fbody))], fbody, slot))

        return ambient, ports

    def _binding_text(self, chain: list[Hop], slot: str,
                      expr: str) -> tuple[list[Hop], str] | None:
        """A slot's bound expression -> (the chain it is read under, the text a
        hook can reach), or None + a WALK rejection.

        This is the walk's reader, not the gate's: the shape pass has already
        recorded an inline or `let`-bound lambda as a failure of the result,
        and the walk still enters it, because the instrument's question -- what
        does this text reach -- is worth answering about the text that runs.
        The order is the chain's (N42): a local `let body` is entered BEFORE a
        top-level `body` is looked for, so fact 5's shadow is walked as the
        lambda it registers and not as the declaration it hides.
        """
        home = chain[-1].module
        lb = lambda_body(expr)
        if lb is not None:
            body, params = lb
            return (chain + [Hop(home, f"<inline {slot}>", params, let_bindings(body))], body)
        m = re.fullmatch(rf"({IDENT})", expr.strip())
        if m:
            name = m.group(1)
            r = self._resolve_func(chain, name)
            if r is None:
                self._walk_reject(
                    "hook-binding-unresolvable", home,
                    f"{slot} is bound to the bare name `{name}`, which resolves to no declaration, "
                    f"import or local lambda")
                return None
            if r[0] == "shadow":
                _, kind, hop = r
                if kind == "let":
                    lb2 = lambda_body(hop.lets[name])
                    if lb2 is not None:
                        body, params = lb2
                        return (chain + [Hop(hop.module, f"<let {name}>", params,
                                             let_bindings(body))], body)
                    self._walk_reject(
                        "hook-binding-unresolvable", home,
                        f"{slot} is bound to the local `{name}`, whose `let` is "
                        f"`{hop.lets[name][:50]}` -- not a function expression this tool can enter")
                    return None
                self._walk_reject(
                    "hook-binding-unresolvable", home,
                    f"{slot} is bound to `{name}`, a parameter of `{hop.name}` -- a value "
                    f"threaded through a parameter")
                return None
            _, module, fbody, fparams = r
            return ([Hop(module, name, fparams, let_bindings(fbody))], fbody)
        # a call expression returning a function value: not resolvable, and it is
        # exactly the "computed" shape classifier 2 refuses.
        self._walk_reject(
            "hook-binding-unresolvable", home,
            f"{slot} is bound to `{expr[:60]}` -- neither an inline function nor a bare name")
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
    """Parameter names of the INLINE lambdas inside a body -- best effort, and
    only ever used to turn an unknown callee into the MORE specific
    `applied-local` rejection.  Both are rejections, so a miss here cannot
    change a verdict.  A named function's own signature is read by
    `_params_at`, not here."""
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
    REGISTRATION reaches -- and, since P0.3, the registration-shape result
    beside them.

    The closure comes from the parent tool, so the two verdicts quantify over
    exactly the same source and any difference between them is the reading and
    nothing else.  `registration_only` is the set difference and it is the
    artifact this item owes: those effects are real, they run at install time,
    and ruling them out of criterion 2 does not account for them.
    """
    exts = c3.installable_extensions(repo)
    resolve = c3.module_resolver(repo)

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
            "registration_shape": sc.registration_shape,
            "registration_shape_result": sc.registration_shape_result(),
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


def shape_summary(res: dict) -> dict:
    """The gate's numbers, derived from the per-extension field and nothing
    else: how many pass, and the rejections by reason.  `binding_rejections`
    is the count ADR D2 states the unmigrated tree is red by ("red by 35
    bindings"): one per payload the rule refuses, over every extension."""
    by_reason: dict[str, int] = {}
    failing = []
    for e in sorted(res):
        r = res[e]["registration_shape_result"]
        if r["result"] != "pass":
            failing.append(e)
            for x in r["reasons"]:
                by_reason[x["shape"]] = by_reason.get(x["shape"], 0) + 1
    binding = sum(n for s, n in by_reason.items() if s.startswith("payload-"))
    delegation = sum(n for s, n in by_reason.items() if s.startswith("delegation-"))
    caps = sum(n for s, n in by_reason.items() if s.startswith("caps-"))
    head = by_reason.get("return-shape-unsupported", 0)
    return {"extensions": len(res), "passing": len(res) - len(failing), "failing": failing,
            "by_reason": by_reason, "binding_rejections": binding,
            "delegation_rejections": delegation, "caps_rejections": caps,
            "head_rejections": head}


def emit_hook_scope(res: dict, closure_verdicts: dict[str, str]) -> int:
    """Print both answers side by side, then the gate.  The delta IS the report;
    the exit code is the REGISTRATION-SHAPE result's and nothing else's."""
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
    print()

    # THE GATE (031 ADR-001 D2 "The gate", freeze item 8; release G5e).  Its
    # own per-extension field, its own reasons, and the exit code.  Nothing
    # above feeds it: a HOOK-UNRESOLVED extension with a clean shape passes it,
    # and a HOOK-PORT-MEDIATED extension on the 7.4 head fails it.
    s = shape_summary(res)
    print("REGISTRATION SHAPE -- 031 ADR-001 D2 (a), the gate's own total result per")
    print("installable extension: the `{ config, caps }` head, every atom enumerated,")
    print("every payload a named unshadowed top-level function, every delegation resolved")
    print("in scope.  Computed from `locate` and the binding pass, never from the walk.")
    print()
    print(f"{'extension':<26}{'head':<18}{'shape':<8}{'reasons'}")
    for e in sorted(res):
        r = res[e]["registration_shape_result"]
        reasons: dict[str, int] = {}
        for x in r.get("reasons", []):
            reasons[x["shape"]] = reasons.get(x["shape"], 0) + 1
        why = ", ".join(f"{k} x{n}" if n > 1 else k for k, n in sorted(reasons.items()))
        print(f"  {e:<24}{str(r['head']):<18}{r['result']:<8}{why}")
    print()
    print(f"REGISTRATION SHAPE: pass {s['passing']} of {s['extensions']}; "
          f"fail {len(s['failing'])}")
    print(f"  binding rejections    {s['binding_rejections']:>3}  "
          f"({', '.join(f'{k} {n}' for k, n in sorted(s['by_reason'].items()) if k.startswith('payload-')) or '-'})"
          f"  -- ADR D2: red by these on the unmigrated tree")
    print(f"  head rejections       {s['head_rejections']:>3}  (return-shape-unsupported: the 7.4 "
          f"bare list, or a record not at the registration tail)")
    print(f"  delegation rejections {s['delegation_rejections']:>3}")
    print(f"  caps rejections       {s['caps_rejections']:>3}")
    print(f"  enumeration           {s['by_reason'].get('list-not-enumerable', 0):>3}  "
          f"(list-not-enumerable)")
    other = {k: n for k, n in s["by_reason"].items()
             if k in ("registration-missing",)}
    if other:
        print(f"  other                 {sum(other.values()):>3}  ({', '.join(sorted(other))})")
    if s["failing"]:
        print(f"GATE: RED -- exit 1 from the registration-shape field alone. Green means every")
        print(f"installable extension passes; P1.2 migrates the sites and P1.2's batches flip them.")
        return 1
    print("GATE: GREEN -- every installable extension has a total, passing registration-shape result.")
    return 0


# --------------------------------------------------------------------------
# the fixture suites
# --------------------------------------------------------------------------

def fixture_resolver(repo: Path):
    """An import resolver for FIXTURE closures: a path that names a file under
    the repo resolves to it, `std/*` is std, anything else is residue.  The
    parent's `module_resolver` knows `src/` and `pkg/` only, and the gate's
    fixtures import their sibling ABI by repository path, as P0.2's do."""
    def resolve(path: str):
        if path.startswith("std/"):
            return ("std", path)
        f = repo / (path + ".ail")
        return ("file", f) if f.is_file() else ("residue", path)
    return resolve


def fixture_closure(root: Path, resolve) -> list[Path]:
    """Every module a fixture root transitively imports through `resolve`."""
    seen: set[Path] = set()
    stack, mods = [root], []
    while stack:
        f = stack.pop().resolve()
        if f in seen or not f.is_file():
            continue
        seen.add(f)
        mods.append(f)
        for path, _syms, _form in _imports_of(keep_interpolations(f.read_text(errors="replace"))):
            kind, target = resolve(path)
            if kind == "file":
                stack.append(target)
    return sorted(mods)


def gate_fixture_suite(repo: Path, gate_dir: Path, producer=None, builtins=None,
                       ext_fields: tuple[str, ...] = (), ailang_check: bool = False,
                       only: set[str] | None = None) -> tuple[list[str], list[str]]:
    """THE GATE'S FIXTURES (PLAN-001 P0.3; ADR D2 "The gate's fixtures").

    One fixture per rejection reason and per in-tree registration form, each
    pinned in `expected.json` with its shape result, its reasons, its head and
    its atom count; the pass fixtures are the positive controls without which
    a reader that resolves nothing would pass every fail row.  With a
    `producer` (the self-test) the walk runs too and a fixture may pin its
    walk verdict beside its shape result -- `fx_residue` is the one that
    matters: walk residue (`show`) and a PASSING shape, side by side, which is
    the ADR's "distinct from and never hidden by" made checkable.  With
    `ailang_check` the pinned compiler's verdict is asserted where a fixture
    pins one: the import-shadow rows are compiler-CLEAN and gate-rejected, by
    design (P0.2's group 4).

    Returns `(failures, lines)`; a failure is a pin that did not hold.
    """
    fails: list[str] = []
    lines: list[str] = []
    if not gate_dir.is_dir():
        return [f"no gate fixture directory at {gate_dir}"], lines
    expected = json.loads((gate_dir / "expected.json").read_text())
    resolve = fixture_resolver(repo)
    present = sorted(p.stem for p in gate_dir.glob("fx_*.ail"))
    if only:
        present = [p for p in present if p in only]
        missing = sorted(only - set(present))
        if missing:
            fails.append(f"--only names fixtures that are not present: {missing}")
    covered: set[str] = set()
    results: dict[str, str] = {}
    for name in present:
        want = expected["fixtures"].get(name)
        if want is None:
            fails.append(f"{name}: fixture present but not declared in expected.json")
            continue
        root = gate_dir / f"{name}.ail"
        mods = fixture_closure(root, resolve)
        sc = Scope(name, root, mods, repo, resolve)
        located = sc.locate()
        shape = sc.registration_shape_result()
        reasons = sorted({r.shape for r in sc.shape_rejections})
        covered |= set(want.get("reasons", []))
        results[name] = shape["result"]
        problems = []
        if shape["result"] != want["shape"]:
            problems.append(f"expected shape {want['shape']}, got {shape['result']}")
        if reasons != sorted(want.get("reasons", [])):
            problems.append(f"expected reasons {sorted(want.get('reasons', []))}, got {reasons}")
        if sc.registration_shape != want.get("head"):
            problems.append(f"expected head {want.get('head')}, got {sc.registration_shape}")
        if "atoms" in want and len(sc.atoms) != want["atoms"]:
            problems.append(f"expected {want['atoms']} atom(s), enumerated {len(sc.atoms)}")
        extra = ""
        if producer is not None and "verdict" in want:
            ambient, _ports = sc.walk(producer, builtins or {}, ext_fields) if located else ([], [])
            verdict = sc.verdict(ambient)
            wshapes = sorted({r.shape for r in sc.rejections})
            if verdict != want["verdict"]:
                problems.append(f"expected walk verdict {want['verdict']}, got {verdict} "
                                f"(walk shapes {wshapes})")
            elif want.get("walk_shapes") is not None and wshapes != sorted(want["walk_shapes"]):
                problems.append(f"expected walk shapes {sorted(want['walk_shapes'])}, got {wshapes}")
            extra += f"  walk={verdict}"
        if ailang_check and "compiler" in want:
            # REPO-RELATIVE, on purpose: the pinned compiler derives the module
            # path from the path it is handed, and an absolute path makes it
            # demand `module workspaces/...`, which is a rejection of the wrong thing.
            try:
                rel = str(root.relative_to(repo))
            except ValueError:
                rel = str(root)
            rc = subprocess.run(["ailang", "check", rel], cwd=repo,
                                capture_output=True, text=True).returncode
            got = "clean" if rc == 0 else "rejected"
            if got != want["compiler"]:
                problems.append(f"expected the pinned compiler to find it {want['compiler']}, "
                                f"it found it {got}")
            extra += f"  compiler={got}"
        if problems:
            fails.append(f"{name}: " + "; ".join(problems) + f"  [{want['form']}]")
        else:
            lines.append(f"  ok  {name:<30} {shape['result']:<5} "
                         f"{', '.join(reasons) or '-':<52} {want['form']}{extra}")
    if not only:
        for gone in sorted(set(expected["fixtures"]) - set(present)):
            fails.append(f"{gone}: declared in expected.json but the fixture file is gone")
        for reason in SHAPE_REASONS:
            if reason not in covered:
                fails.append(f"SHAPE COVERAGE: no gate fixture exercises `{reason}`")
        if not any(v == "pass" for v in results.values()):
            fails.append("POSITIVE CONTROL: no gate fixture passes. A rejection-only suite is "
                         "passed by a reader that resolves nothing.")
        if not any(v == "fail" for v in results.values()):
            fails.append("TWO-SIDED CONTROL: no gate fixture fails.")
    return fails, lines


def self_test(repo: Path, c3, producer, builtins: dict[str, str],
              ext_fields: tuple[str, ...]) -> int:
    """One fixture per rejection shape, each PAIRED with a resolving control.

    The pair that carries the reading is `control_registration_only` /
    `control_hook_reaches_env`: the same import and the same call, differing only
    in position.  If those two ever agree, this tool has stopped measuring the
    reading and is measuring the file again -- so they are asserted to DISAGREE,
    explicitly, rather than only asserted individually.

    P0.3 adds, beside every walk pin, the SHAPE pin of the same fixture (head,
    result, reasons -- re-pinned by hand for the 8.0 head), the gate's own
    fixture suite, and the tree-wide shape yield: per extension the head and the
    result, and the binding-rejection count the ADR states the unmigrated tree
    is red by.
    """
    fx = repo / "tools/ext_ambient_inventory/fixtures/hook_scope"
    if not fx.is_dir():
        print(f"self-test: no fixture directory at {fx}", file=sys.stderr)
        return 2
    expected = json.loads((fx / "expected.json").read_text())
    fails: list[str] = []

    def trivial_resolve(path: str):
        return ("std", path) if path.startswith("std/") else ("residue", path)

    present = sorted(p.stem for p in fx.glob("*.ail"))

    # THE FIXTURES' OWN CACHE PRECONDITION, ESTABLISHED RATHER THAN ASSUMED --
    # the parent's discipline (`provision`), applied to this suite.  `_hook_scope`
    # provisions the eighteen extension roots, whose closures never import
    # `std/clock`; `control_interpolated_call` does.  On a warm checkout its
    # `iface.json` is there from some earlier compile under `src/` or
    # `scripts/`; in a fresh clone it is not, and the fixture reads
    # `no-cached-interface` -- a cold-cache answer that is not the fixture's,
    # and that scored this suite red-by-construction in P0.3's mutgate clone.
    # So every fixture is compiled here, into the fixture directory's own
    # repo-local cache, and the producer loads that directory too.  `load` is
    # additive and compares copies, so a warm tree gains nothing and loses
    # nothing.  The compile's own verdict is not asserted: these fixtures are
    # shape probes, several deliberately unresolvable, and a rejection at check
    # still writes the std rows this suite needs.
    env = dict(os.environ, AILANG_RELAX_MODULES="1")
    for name in present:
        subprocess.run(["ailang", "check", str((fx / f"{name}.ail").relative_to(repo))],
                       capture_output=True, text=True, cwd=repo, env=env)
    # the fixture directory's own cache, or the DST lane when `make` set one
    # (`AILANG_CACHE_DIR`): wherever those compiles just wrote
    producer.load([fx] + c3.cache_roots(repo))

    got_verdicts: dict[str, str] = {}
    for name in present:
        want = expected["fixtures"].get(name)
        if want is None:
            fails.append(f"{name}: fixture present but not declared in expected.json")
            continue
        f = fx / f"{name}.ail"
        sc = Scope(name, f, [f], fx, trivial_resolve)
        located = sc.locate()
        ambient, ports = sc.walk(producer, builtins, ext_fields) if located else ([], [])
        verdict = sc.verdict(ambient)
        got_verdicts[name] = verdict
        shapes = sorted({r.shape for r in sc.rejections})
        shape = sc.registration_shape_result()
        shape_reasons = sorted({r.shape for r in sc.shape_rejections})
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
        elif sc.registration_shape != want.get("head"):
            # THE HEAD PIN (P0.3): which registration head the fixture resolved
            # through -- "capability-list" (7.4) or "config-caps" (8.0) -- or
            # None when no list was reached.  Pinned by hand on every fixture.
            fails.append(f"{name}: pinned as head {want.get('head')!r} but resolved as "
                         f"{sc.registration_shape!r}")
        elif shape["result"] != want.get("shape"):
            fails.append(f"{name}: expected registration shape {want.get('shape')!r}, got "
                         f"{shape['result']!r} (reasons {shape_reasons})")
        elif shape_reasons != sorted(want.get("shape_reasons", [])):
            fails.append(f"{name}: expected shape reasons {sorted(want.get('shape_reasons', []))}, "
                         f"got {shape_reasons}")
        else:
            extra = f"  atoms={len(sc.atoms)}" if located else ""
            print(f"  ok  {name:<34} {verdict:<20} shape={shape['result']:<5}"
                  f"{want['form']}{extra}")
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

    # THE ARITY TABLE AGAINST THE ABI (031 P0.5): every row, both directions.
    afails, alines = check_capability_arities(repo)
    for ln in alines:
        print(ln)
    fails.extend(afails)

    # THE GATE'S OWN FIXTURES (P0.3), with the walk beside the shape.
    gate_dir = repo / SHAPE_GATE_FIXTURES
    gfails, glines = gate_fixture_suite(repo, gate_dir, producer, builtins, ext_fields)
    for ln in glines:
        print(ln)
    fails.extend(f"GATE {x}" for x in gfails)

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
    # head each extension registers through and how many atoms each holds.
    # Empty on the 5.x tree; B8 re-pinned it with seventeen entries by hand;
    # P0.3 re-pinned it by hand for the 8.0 head -- every entry is still on the
    # 7.4 list until P1.2 moves it.  A pin in both directions, so an extension
    # migrating early is noticed and a list read short is noticed.
    got_lists = {e: r["atom_count"] for e, r in res.items()
                 if r["registration_shape"] in ("capability-list", "config-caps")}
    want_lists = want.get("capability_list_atoms", {})
    if got_lists != want_lists:
        fails.append(f"YIELD capability-list atoms: expected {want_lists}, derived {got_lists}. "
                     f"Per-extension atom counts are the fail-closed denominator and must be "
                     f"re-pinned by hand, never inherited.")
    else:
        print(f"  ok  capability-list atoms         {sum(got_lists.values())} atom(s) over "
              f"{len(got_lists)} of {len(res)} extension(s)")
    got_heads = {e: r["registration_shape"] for e, r in res.items()}
    want_heads = want.get("registration_heads", {})
    if got_heads != want_heads:
        fails.append(f"YIELD registration heads: expected {want_heads}, derived {got_heads}. "
                     f"The head is the 8.0 record or the 7.4 list per extension; P1.2 moves "
                     f"each by hand, and the pin moves with it, never ahead of it.")
    else:
        print(f"  ok  registration heads          "
              f"{sum(1 for h in got_heads.values() if h == 'config-caps')} on `{{ config, caps }}`, "
              f"{sum(1 for h in got_heads.values() if h == 'capability-list')} on the 7.4 list")

    # THE GATE'S YIELD (P0.3): per extension pass/fail, and the binding count.
    got_shape = {e: r["registration_shape_result"]["result"] for e, r in res.items()}
    want_shape = want.get("registration_shape_results", {})
    if got_shape != want_shape:
        fails.append(f"YIELD registration shape: expected {want_shape}, derived {got_shape}. "
                     f"An extension that flips is a P1.2 batch landing (re-pin it with the "
                     f"batch) or a gate that moved (do not re-pin; find out which).")
    else:
        s = shape_summary(res)
        print(f"  ok  registration shape          pass {s['passing']} of {s['extensions']}")
    s = shape_summary(res)
    want_bind = want.get("shape_binding_rejections")
    if s["binding_rejections"] != want_bind:
        fails.append(f"YIELD shape binding rejections: expected {want_bind}, measured "
                     f"{s['binding_rejections']} ({s['by_reason']}). ADR D2 states the "
                     f"unmigrated tree is red by 35 bindings; this pin is the MEASURED number "
                     f"and moves only with a P1.2 batch or a recorded finding.")
    else:
        print(f"  ok  shape binding rejections    {s['binding_rejections']} "
              f"({', '.join(f'{k} {n}' for k, n in sorted(s['by_reason'].items()) if k.startswith('payload-'))})")

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


# --------------------------------------------------------------------------
# standalone: the gate's fixtures without the producer
# --------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    """`hook_scope.py --gate-fixtures [DIR] [--ailang-check] [--only a,b]`

    Runs the registration-shape gate over its fixtures and exits 0 only when
    every pin holds.  Needs no producer and no cache: the shape result is
    textual.  This is the `test_cmd` the mutation gate runs (013
    `GATE-mutation-red-submission-precondition.md`): break a rejection, and the
    fixture that names it reads pass against a pin that says fail.
    """
    import argparse
    ap = argparse.ArgumentParser(description=main.__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=".", help="repository root")
    ap.add_argument("--gate-fixtures", nargs="?", const=SHAPE_GATE_FIXTURES,
                    metavar="DIR", help="run the gate over its fixture directory")
    ap.add_argument("--ailang-check", action="store_true",
                    help="also assert each fixture's pinned compiler verdict (`ailang check`)")
    ap.add_argument("--only", default="", help="comma-separated fixture names to run")
    args = ap.parse_args(argv)
    repo = Path(args.repo).resolve()
    if args.gate_fixtures is None:
        ap.print_help()
        return 2
    only = {x for x in args.only.split(",") if x} or None
    fails, lines = gate_fixture_suite(repo, repo / args.gate_fixtures,
                                      ailang_check=args.ailang_check, only=only)
    for ln in lines:
        print(ln)
    # 031 P0.5: the arity table the gate enumerates atoms with, against the ABI.
    afails, alines = check_capability_arities(repo)
    for ln in alines:
        print(ln)
    fails.extend(afails)
    print(f"\nregistration-shape gate fixtures: {len(lines)} ok, {len(fails)} failure(s)")
    for f in fails:
        print(f"  FAIL {f}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
