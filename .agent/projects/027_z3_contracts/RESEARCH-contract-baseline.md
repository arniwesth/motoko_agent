# Research: what `ailang verify` actually proves about `src/core/` today

Date: 2026-08-29. Status: measured baseline, **revised the same day** after a delegated
adversarial review corrected §3 E4 and §4 — see §6 for provenance. All numbers in this note were produced on
branch `arniwesth/mot-129-extension-abi-phase-a` at HEAD `76178f86` with Z3 4.8.12, and
every experiment in §3 was reverted — the tree is unchanged by this note.

Source design doc: `design_docs/planned/m-motoko-z3-contracts.md` (Status: Planned).
Turned into a decision by `ADR-001-contract-classification-register.md` and a phase plan by
`PLAN-z3-contract-adoption.md`, both in this directory.
Companions: `design_docs/planned/m-motoko-dp7-verifier-gate.md` (implemented — see
`src/core/session.ail:1800`), `.agent/projects/023_hybrid_verification_cris/`,
`papers/README.md` → [2503.10784](https://arxiv.org/abs/2503.10784).

_Written because the design doc's plan cannot be executed as written. Three of its four
phases are already done, half-done, or aimed at functions that no longer exist; its flagship
example needs two local edits the doc does not mention before the solver will look at it; and
its success
metric ("`verify_core` reports >= 5 proven") is satisfiable today with contracts that prove
nothing. The useful output is a measured baseline and a metric that cannot be gamed — plus,
after §6's review, the finding that the honest metric needs no upstream work at all: the
solver already answers it._

## 1. The baseline

```
$ make verify_core
  ✓ src/core/compress.ail (0 proven)
  ✓ src/core/tool_runtime.ail (4 proven)
verify_core: 2 with contracts, 0 failed, 51 without contracts     # exit 0
```

53 non-test modules in `src/core/`, 1545 `pure func` declarations, 4 verified contracts.

The four live in `src/core/tool_runtime.ail`. Classified by what they actually constrain:

| Function | Contract | Class |
|---|---|---|
| `normalize_range` (:196) | `result.start >= 1 && result.end >= result.start` | **substantive** — an invariant the body establishes, strictly weaker than the body |
| `is_absolute_path` (:277) | `result == startsWith(path, "/")` | determining, verbatim — the body *is* `startsWith(path, "/")`; Z3 proves the body equals itself. Not worthless: it locks the body against a lone edit (§3 E6 row 4), and this function has no `tests` block while guarding the write path at `:360` |
| `isSome` (:24) | `result == true \|\| result == false` | tautology over `bool` |
| `is_native_backend` (:1007) | `result == true \|\| result == false` | tautology over `bool` |

**One of Motoko's four proven contracts is substantive.** Two would hold if the bodies were
replaced by any `bool`-returning expression whatsoever — measured, not eyeballed: §3 E5's
free-result probe verifies them with no body at all. The third would hold if
`is_absolute_path` were rewritten to any other predicate, because the contract would be
rewritten with it (§3 E6 row 3) — though it would *not* survive the body being rewritten
alone (row 4).

This is the same shape as the DST report's computed vacuity register ("one of forty
classification entries is measured and substantive", `papers/motoko-dst-report/SCOPE.md`).
The difference is that DST *computes* its register and pins it; the contract layer has no
register at all, so the vacuity is invisible to the gate.

## 2. Three ways the current state reads as verification and is not

### 2.1 `verify_core` prints ✓ for a file that proves nothing

`src/core/compress.ail` carries the two `requires { max_chars >= 0 }` clauses from the
design doc's Phase 2 table (:57, :69). The `ensures` clauses from the same table never
landed. `ailang verify` correctly reports both functions `SKIPPED — no ensures clause
(nothing to verify)`; `ailang/cmd/ailang/verify.go:290-297` is the check. But `verify_core`
(`Makefile:2338`) classifies a file by whether the string `no functions with contracts`
appears, so a file with `requires` and no `ensures` lands in the ✓ bucket and prints
`(0 proven)`. The tick is doing the reading; the count is not.

Half-annotated is the worst state available: the file looks specified to a reader, is green
in CI, and constrains nothing.

### 2.2 Two `@verify` predicates in `agents_md.ail` are dead code under a verification banner

`src/core/agents_md.ail:186-200` has a header comment reading `Z3 / SMT verification
targets`, followed by two `@verify(depth: 1)` predicates: `is_root_length_bound` and
`dirname_shrinks`. The second is annotated as "the key property that ensures `walk_agents`
terminates".

```
$ ailang verify src/core/agents_md.ail
  0 functions: no functions with contracts
```

`@verify(depth: N)` sets the unrolling depth (`meta.VerifyDepth`, `verify.go:310`) for
functions that **already carry contracts**; `verify.go:273` drops any function with zero
contracts before depth is ever consulted. Neither predicate has a `requires`/`ensures`
clause, so neither is seen. Neither is called, exported, or covered by a `tests [...]`
block anywhere in `src/`, `scripts/`, or the `Makefile` — they are unreachable functions
whose only effect is to make a reader believe a termination property is checked.

### 2.3 The design doc is stale about its own targets

Of the thirteen functions in its Phase 2 table:

- `context_limit_for`, `count_tool_msgs`, `elide_old_tool_results` — **do not exist**.
  Structural elision moved to `pkg/sunholo/motoko_ext_compaction_structural`;
  `usage_percent` is now `usage_percent_with_limit` (`compaction.ail:25`).
- The `compaction.ail` entries are unreachable and the module already says so, correctly:
  four `-- contracts: SKIPPED — uses foldl (Z3 fragment requires non-higher-order)` comments
  (`compaction.ail:16,24,100,106`, plus `session.ail:512`).
- Phase 1 ("add `verify_core`") is **already done** — `verify_core` and `verify_ext` are both
  in the `Makefile` (:2338, :2367).
- Phase 3's justification-comment convention is **partly applied** in source, but
  `CONTRIBUTING.md` contains no contract policy text at all.
## 3. What is actually reachable — seven experiments

The Z3 fragment is defined by six rejection codes in
`ailang/internal/smt/encodable.go:44` (`IsSMTEncodable`): no contracts, not pure, recursive,
higher-order (unless inlinable), patterns deeper than 1, unencodable builtin or type.
Rather than reason about it, I applied contracts and read the verdicts. **Every edit below
was reverted; E5, E6 and E7 ran entirely in scratch modules.**

**E1 — `func` is not pure.** Adding an `ensures` to `is_root`/`dirname` as declared yields
`SKIPPED — Function "is_root" has effects`. Plain `func` fails `isPure` regardless of body;
promotion to `pure func` is step zero for every candidate. The four contracts that verify
today are all `pure func`.

**E2 — `is_root_length_bound` is real, and two lines away.** With `is_root` promoted to
`pure func` and given the dead predicate's property as a contract:

```ailang
pure func is_root(path: string) -> bool
  ensures { not result || str_length(path) <= 3 }
```
```
  ✓ VERIFIED is_root  [21.0ms]
```

**E3 — `dirname_shrinks` is not reachable.** Same treatment on `dirname`:

```
  ⚠ SKIPPED dirname
    Reason: ... calls user function "find_last" that is not SMT-encodable in this context
```

`find_last` (`agents_md.ail:33`) is recursive, so the `walk_agents` termination property is
blocked behind de-recursing it — not behind writing a contract. The dead predicate's
comment claims a guarantee that no tool has ever checked and no tool can check today.

**E4 — string-producing functions ARE provable; the two obvious ways just both fail.**

> **Corrected 2026-08-29 after delegate review.** This experiment originally concluded that
> no string-producing function in `src/core/` was provable and that the fix was an upstream
> map entry. That conclusion was **wrong**, and the error was method: I tested the two forms
> I reached for, both failed, and I generalised from two failures instead of testing the
> builtin directly. Recorded rather than deleted, because the failure mode — concluding
> "impossible" from an unrepresentative sample — is the one this whole note is about.

The two natural forms do fail. Adding `ensures { _str_len(result) <= max_chars + 15 }` to
`truncate_with_suffix`:

- as written, with the interpolation `"${kept}\n... (truncated)"` —
  `SKIPPED — unencodable builtin: show`
- with `kept ++ "..."` — rejected by the type checker: ``` `++` is for lists only ```
- with `concat([kept, "..."])` — `SKIPPED — unencodable builtin: std/string.concat`

But `concat_String` is ordinary surface syntax — `ailang/std/sem.ail:63` calls it — and
`ailang/internal/smt/types.go:297` maps it to SMT-LIB `str.++`. With `pure func` and the
interpolation replaced by `concat_String(kept, "\n... (truncated)")`:

```
  ✓ VERIFIED truncate_with_suffix  [18.99ms]
```

The design doc's flagship claim is provable **today**, for two local edits and no upstream
change. Note also that the map entry this note originally proposed would have been
ill-typed: `std/string.concat : [string] -> string` (`std/string.ail:74`, `_str_join(xs,"")`)
against `concat_String : string -> string -> string`.

What survives from the original E4 is an ergonomics finding, not a blocker: the provable
form is the one nobody reaches for, and the idiomatic form (`"${...}"`, which the stdlib
docstring for `concat` actively recommends for mixed building) is the unprovable one.

**E5 — vacuity is solver-decidable today, with no new AILANG feature.** Rewrite a contract
with the result bound to a *free* argument. `VERIFIED` then means the `ensures` holds for
every possible result, i.e. independent of any body:

```ailang
pure func taut_isSome(r: bool) -> bool
  ensures { result == true || result == false } { r }              -- ✓ VERIFIED  ⇒ tautology

pure func taut_normalize_range(r: {start:int, end:int}) -> {start:int, end:int}
  ensures { result.start >= 1 && result.end >= result.start } { r } -- ✗ VIOLATION ⇒ substantive
```

The violation even returns the witness: `{start: 0, end: 1}`. A second probe — bind the
result free, `requires` the contract, `ensures` it equals the body — decides whether the
contract *determines* the body. Both probes are source-to-source rewrites over a module the
verifier already accepts; classification needs a generator, not a language feature.

**E6 — what a determining contract does and does not catch.** Four variants of
`is_absolute_path`'s shape, run together:

| Variant | Contract | Body | Verdict |
|---|---|---|---|
| verbatim | `result == startsWith(path,"/")` | `startsWith(path,"/")` | ✓ VERIFIED |
| independent | `result == (_str_slice(path,0,1) == "/")` | `startsWith(path,"/")` | ✓ VERIFIED |
| co-edit | `result == startsWith(path,"\\")` | `startsWith(path,"\\")` | ✓ VERIFIED |
| body-only edit | `result == startsWith(path,"/")` | `startsWith(path,"\\")` | ✗ VIOLATION, `path="\\"` |

Row 4 is why a verbatim restatement is not worthless: it locks the body against a lone edit,
universally quantified over inputs. Row 3 is why it is not a proof: contract and body live
in one declaration, and a co-edit passes. Row 2 is the case the three-class taxonomy missed
— an *independently formulated* contract lands in the same solver class as a copy but proves
a real theorem relating two different string operations, which is a cross-check in the sense
that writing a test's expected value by hand is a cross-check.

Relevant to how row 1 should be valued here: **none** of the four contract-bearing functions
in `tool_runtime.ail` has a `tests [...]` block, and `is_absolute_path` guards the write
path — `tool_runtime.ail:360` rejects absolute paths with it. For that function the contract
is its only mechanical coverage, and it fences a sandbox boundary.

**E7 — for a real guard predicate, the substantive contract is available and beats the
restatement.** E6 shows what a determining contract catches. It does not show whether one is
the *best available* contract, and for the guards that motivated the question it is not.

The write-path guard chain is `validate_path_common` (`tool_runtime.ail:351-374`). Its
coverage, measured — "property coverage" means another function with a `tests [...]` block
that calls it:

| Guard | pure | own tests | property coverage |
|---|---|---|---|
| `strip_workdir_prefix` (:327) | yes | no | `strip_under_workdir` |
| `has_parent_traversal_segment` (:265) | no (recursive) | no | `t_path_traversal_segment` |
| `starts_with_root_dir` (:287) | yes | no | `root_dir_check_blocks_bare_abs` |
| `is_absolute_path` (:276) | yes | no | **none — its contract is the only check** |
| `has_shell_tokens` (:32) | no | no | **none** |
| `shell_tokens_in_process` (:50) | no | no | **none** |

Two findings, one of which is not about contracts at all. `is_absolute_path` is the only link
in the path chain with no example coverage, which is what made its restatement look valuable.
And `has_shell_tokens` / `shell_tokens_in_process` — which decide whether a command is wrapped
in a shell (`:20`, `:888`) — have neither tests nor contract. That is the real gap in this
cluster, and E6's argument was never about it.

Both are contractable, and in both cases a **substantive** contract exists. For
`starts_with_root_dir`, a bound on false positives:

```ailang
pure func root_implies_slash(path: string) -> bool
  ensures { result == false || contains(path, "/") }        -- ✓ VERIFIED [73ms]
```

For `has_shell_tokens` — a pure enumeration, where a restatement looks unavoidable — a
one-directional "must catch at least these", run against three bodies:

```ailang
ensures { (not contains(s, ";")  || result) && (not contains(s, "|") || result)
       && (not contains(s, "$(") || result) && (not contains(s, "`") || result) }
```

| Body | Verdict |
|---|---|
| current (8 tokens) | ✓ VERIFIED |
| `";"` removed from the list | ✗ VIOLATION, counterexample `s = ";"` |
| a ninth token added | ✓ VERIFIED |

That contract is strictly better than the restatement on every axis. It catches the removal
edit — the one that matters in a security guard — with the exact counterexample. It does not
obstruct the addition edit, which a restatement would fail, forcing a co-edit and teaching
people to update contracts mechanically. And two different bodies satisfying it is a direct
demonstration that it is non-determining, so it lands in the counting class.

The generalisation is a pair: a **recall** property bounds what a guard must catch, a
**precision** property bounds what it must not reject. Neither alone pins the guard — an
always-`true` body satisfies the recall contract — but together they are nearly as strong as a
restatement while each survives a different legitimate edit.

## 4. Ranked findings

1. **The metric is the problem.** "N proven" rises fastest by writing tautologies, and three
   of four existing contracts already are. Any plan that ships against a proven-count target
   is optimising the wrong thing.
2. **The classification can be computed, so it must be** (E5). A hand-maintained register
   would reproduce the failure `dst_invariants.ail:72-84` documents — a pin and a survey
   edited together, agreeing with each other about a claim neither checks. Here it would be
   worse than in the DST case, because the register entry *is* the judgment, so
   "edit both together" is not an attack but the normal workflow. Two-way name parity proves
   inventory, not classification truth.
3. **`verify_core` must stop ticking `requires`-only files.** One-line fix, and it converts
   `compress.ail` from a false green into an honest `unstated`. Note the line can print the
   *reason* but not the rejection code: `verify.go:340-349` strips codes from the human
   reason, and the `no ensures` path (`:289-304`) bypasses code generation entirely.
4. **Nothing upstream is blocking** (E4, corrected). The compress/truncate tier is reachable
   now. The only upstream item left is ergonomic — that the provable concatenation form is
   not the idiomatic one — and it is worth a feedback item, not a phase.
5. **The uncovered guard is `has_shell_tokens`, not `is_absolute_path`** (E7). The shell-token
   detector gates command wrapping and has no test, no property, and no contract. A recall +
   precision contract pair is available for it and for `starts_with_root_dir`, both verified.
   This also answers whether a restatement deserves its own workstream: no — where one looked
   like the only option, a substantive contract existed and was better.
6. **Delete or discharge the `@verify` banner in `agents_md.ail`.** E2 converts one predicate
   into a real proof for two lines; E3 says the other cannot be honoured and its comment
   should stop claiming otherwise until `find_last` is de-recursed.
7. **The DP7 connection is the point, and its risk is cost, not deception.** `check_core` is
   DP7's oracle (`session.ail:1803`, enabled in all six real profiles). Measured:
   `verify_core` 18.9s against `check_core` 21.2s — folding it in nearly doubles every
   finalize *before a single new contract exists*. And `session.ail:1826` hard-codes
   "The code you just wrote does not type-check", so a Z3 timeout would reach the model as a
   type error. A vacuous gate can only ever make DP7 **approve**; it cannot produce a
   misleading rejection.

## 5. What deliberately does not transfer from the design doc

Recorded so it is not re-litigated: the Phase 2 table as a work list (three targets deleted,
four unreachable via `foldl`); Phase 1 (already shipped); the `>= 5 proven` acceptance
criterion (gameable, and 4 of the current 4 illustrate how). What survives is Phase 3 — the
per-`pure func` policy — and the compress/truncate tier, which E4 (corrected) puts back on
the table.

## 6. Provenance of the corrections

§3 E4, §4.2, §4.3, §4.4 and §4.6 were rewritten on 2026-08-29 after an adversarial review
delegated through herdr to two agents working from one standalone brief
(`.motoko/herdr-delegates/task-adr027-review.md`; answers preserved as
`answer-adr027-claude.md` and `answer-adr027-codex.md` in the same directory).

- The codex delegate found E4's conclusion false. Verified independently before accepting.
- The claude delegate found the solver-decidable vacuity probe (E5), falsifying the ADR's
  original claim that the check needed an upstream feature. Verified independently.
- Both, separately, found the DP7 justification inverted and the hand register unable to
  validate its own labels.
- The claude delegate *confirmed* E4 — reproducing the two failures I had reproduced, and
  not testing the third form. A false confirmation from testing what the author tested; it
  is the reason two delegates were used rather than one.
- E6 was run to settle a disagreement between them and is new in this revision.
