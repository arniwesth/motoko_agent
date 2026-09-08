# Plan: Z3 contract adoption for `src/core/`

Date: 2026-08-29. Status: proposed, not started; **P2–P4 revised the same day** after a
delegated adversarial review (ADR §7). Supersedes the phase plan in
`design_docs/planned/m-motoko-z3-contracts.md` (which stays as the origin record).
Evidence base: `RESEARCH-contract-baseline.md` in this directory — every claim below is
measured there, including experiments E1–E6. The governing decision (what counts as progress)
is `ADR-001-contract-classification-register.md`; P0 is its precondition and P3 is its
mechanism.

**Thesis.** The blocker is not that nobody has written contracts, and it is not the language:
nothing upstream is in the way. It is that the gate cannot tell a proof from a tautology —
and that the tautology check the gate needs is one the solver can already answer, if anyone
asks it. Make the gate honest, make the classification computed, then write contracts.
Writing contracts first produces a green number that means nothing, which is the failure mode
this repo already has a name for.

## Phase ordering and why

```
P0 honest gate ──▶ P1 reachable proofs ──▶ P2 string tier ──▶ P3 computed register ──▶ P4 DP7 oracle
                                             │
                                             └──▶ P5 guard-predicate sweep (independent of P3/P4)
```

Strictly sequential now. The first draft ran P2 in parallel because it was an upstream ask
with an unknown landing date; it is a local refactor, so it queues with the rest.

**Ship P0 and P2 as one commit.** P0 alone would leave `compress.ail` failing with its fix in
a later change; together they are the smallest increment that leaves the tree green and the
gate honest. P1 is nearly free and independent — take it next. If only one item from this plan
ever lands, it should be **P5 step 2**: it is the only one that closes a real gap rather than
improving the accounting.

P4 is last and conditional — on a wall-clock budget and on DP7's rejection message
distinguishing a type error from a contract failure, **not** on contracts having stopped
being vacuous. A vacuous contract layer can only make DP7 approve; it cannot mislead the
model into a wrong fix. That was the first draft's reasoning and it was backwards (ADR §6).

---

## P0 — Make `verify_core` unable to report a false green (~0.5d, blocking)

`Makefile:2338`. Today a file with `requires` and no `ensures` prints `✓ ... (0 proven)` and
counts toward `2 with contracts`.

1. Add two new buckets, split by *cause* — amber is not one thing, and the two halves need
   opposite treatment (ADR §3):
   ```
   verify_core: N proven, M unstated (requires, no ensures), K blocked (ensures, out of
                fragment), F failed, B bare
   ```
   - **unstated** — `requires` with no `ensures`. Nobody ever wrote an obligation. This is
     the false green the whole phase exists to kill. `compress.ail` is the entire population
     today (measured: it is the only file in `src/core/` with `requires` and no `ensures`).
   - **blocked** — an `ensures` exists and the fragment rejected it (`NOT_PURE`, `RECURSIVE`,
     `HIGHER_ORDER`, `UNENCODABLE_TYPE`). Someone tried and the solver could not.

   Neither is ticked. `unstated` becomes **failing** at the end of P2, when `compress.ail` is
   fixed — see step 4. `blocked` is reported and never fails.
2. Print the skip **reason** for every unticked file, so a reader sees *why* nothing was proven
   rather than inferring it from a count. Not the rejection code: `verify.go:340-349` strips
   codes from the human reason and the `no ensures` path (`:289-304`) bypasses code
   generation entirely, so machine-readable codes need JSON plumbing upstream and are not
   worth blocking P0 on.
3. Same changes in `verify_ext` (`Makefile:2367`), which shares the shape.
4. **Flip `unstated` to failing in the same commit as P2**, not on a later milestone. The
   entire cost of adopting the rule is one file, and P2 fixes that file. Deferring a
   zero-cost ratchet to an expensive milestone is how ratchets die — `verify_core` and
   `verify_ext` themselves shipped as the design doc's Phase 1 and then sat green and empty
   while the contracts never came.

**Files**: `Makefile`.
**Done when**: `make verify_core` reports `compress.ail` as `unstated` with reason
`no ensures clause`, no file with zero `VERIFIED` lines prints a ✓, and — after P2 — an
`unstated` file exits non-zero while a `blocked` file does not.

---

## P1 — Land the two proofs that are reachable, delete the claim that is not (~0.5d)

`src/core/agents_md.ail:186-200` carries a `Z3 / SMT verification targets` banner over two
`@verify(depth: 1)` predicates that no tool reads (RESEARCH §2.2).

1. **`is_root`** — promote to `pure func`, move the dead predicate's property onto it as a
   contract, delete `is_root_length_bound`. Measured: `✓ VERIFIED is_root [21.0ms]` (E2).
   ```ailang
   pure func is_root(path: string) -> bool
     ensures { not result || str_length(path) <= 3 }
     tests [ ... ]                                   -- unchanged
   ```
2. **`dirname_shrinks`** — cannot be honoured: `dirname` calls the recursive `find_last`
   (`agents_md.ail:33`), so it is rejected as not SMT-encodable in context (E3). Delete the
   predicate and replace the banner comment with the truth:
   ```ailang
   -- contracts: BLOCKED — RECURSIVE. The shrinking property that makes walk_agents
   -- terminate needs dirname's callee find_last de-recursed first. Covered today by
   -- dirname's tests block only.
   ```
   De-recursing `find_last` (a bounded backwards scan) is a real option but is its own
   change; do not fold it in here.
3. `normalize_range` (`tool_runtime.ail:196`) is already substantive — leave it and cite it
   in P3 as the reference example of a contract weaker than its body.

**Files**: `src/core/agents_md.ail`.
**Done when**: `verify_core` reports `agents_md.ail (1 proven)`, no `@verify` annotation
remains without a contract beside it, and `make check_core` + `make test` pass.

---
## P2 — The string tier, which is reachable now (~0.5d)

RESEARCH §3 E4 originally called this an upstream blocker. It is not — that conclusion was
corrected after review. `concat_String` is ordinary surface syntax (`ailang/std/sem.ail:63`)
and encodes to `str.++` (`ailang/internal/smt/types.go:297`). Measured, in scratch:

```ailang
pure func truncate_with_suffix(text: string, max_chars: int) -> string
  requires { max_chars >= 0 }
  ensures  { _str_len(result) <= max_chars + 15 }
  { ... concat_String(kept, "\n... (truncated)") }
```
```
  ✓ VERIFIED truncate_with_suffix  [18.99ms]
```

So the design doc's flagship claim lands for two local edits: promote `func` → `pure func`,
and replace the interpolation `"${kept}\n... (truncated)"` with `concat_String`. Do the same
sweep for `compress_output`'s bound. Confirm `make test` still passes — the change is
behaviour-preserving but the interpolation is on a hot path.

What does **not** work, recorded so it is not retried: interpolation (lowers through `show`,
unencodable), `++` (list-only by design), `std/string.concat` (unmapped, and type-different
— `[string] -> string` against `concat_String`'s two arguments, so the "one-line map entry"
the first draft proposed would have been ill-typed).

**Optional upstream item**, not a phase and not blocking: the provable form is the one nobody
reaches for, and `std/string.ail:73`'s own docstring recommends interpolation for mixed
building. Lowering a single-expression interpolation of a `string` to `concat_String` would
close that gap. Route via the `ailang-feedback` skill with the E4 verdicts as the repro.

**Files**: `src/core/compress.ail`.
**Done when**: `verify_core` reports `compress.ail (2 proven)` and `make test` passes.

---

## P3 — The computed register (~1d, after P0)

The design doc's acceptance criterion was `verify_core: >= 5 proven`. Three of the four
contracts that exist today would satisfy a target like that while constraining nothing.
Replace the count with a classification the solver computes — ADR §1–§3.

1. **`verify_classify` target.** For each contract, generate two probe modules
   (RESEARCH §3 E5) and read the verdicts:
   - *body-independent* — bind the result to a free argument, keep the `ensures`. VERIFIED
     means it holds for every body.
   - *determining* — bind the result free, `requires` the contract, `ensures` it equals the
     body. VERIFIED means the contract admits only the body's answer.
   - *proper abstraction* — VIOLATION on both.

   ~40 lines of generator over a module the verifier already accepts. No AILANG change.

2. **Provenance axis** for `determining` contracts: *verbatim* (contract text ≡ body text)
   vs *independent*. Syntactic, and the only part of the classification that is not a solver
   query.

3. **Pin by hash.** The register maps `name → (solver class, provenance)` and is keyed on
   contract and body hashes, so a co-edit invalidates the entry instead of inheriting it.
   Divergence between generated and pinned is red in both directions.

4. **Human override, narrow and cited.** The probes cannot catch a contract that is a proper
   abstraction of an irrelevant property (`ensures { result.start >= -1000 }`). An override
   exists for exactly that residual and must name the probe result it overrides.

5. **Policy** in `CONTRIBUTING.md` (ADR §4): every **new** `pure func` in `src/core/` carries
   a contract or a comment naming a rejection code from
   `ailang/internal/smt/encodable.go`. Keyed on `git diff` — ~1545 existing declarations have
   no migration story and a tree-wide rule would be unenforceable on day one. CI synthesises
   a trivial contract for each annotated function and confirms the claimed code is the one
   the verifier actually returns; an unchecked code comment is as self-asserted as an excuse.

6. **Then** write contracts where a property is load-bearing: bounds callers rely on,
   totality, termination, length preservation. Do not sweep — 1069 of 1545 `pure func`s pass
   a crude in-fragment filter and most are DST-world constructors where a contract would
   restate a constructor.

**Done when**: `verify_classify` runs in CI, the register is generated and pinned by hash,
`verify_core` reports proper-abstraction count separately from the total, and the register
carries **per-contract solve time** so P4 can see the tail before it rides in DP7's path
rather than after (Q2).

---

## P4 — Raise DP7's oracle (conditional, ~0.5d)

`check_core` is DP7's verification command (`src/core/session.ail:1803`; `config.ail:476`
default; `enabled: true` in all six real profiles). Folding `verify_core` in makes the
autonomous loop's pre-`done` gate a proof obligation rather than a type check — the oracle
upgrade [2503.10784](https://arxiv.org/abs/2503.10784) argues for, in the slot ESBMC-AI puts
a bounded model checker.

Preconditions, per ADR §5 — note these are **not** "wait until contracts stop being vacuous",
which was the first draft's reasoning and was backwards:

1. **Touched-file scoping.** Measured: `verify_core` 18.9s against `check_core` 21.2s, so
   folding it in nearly doubles a gate that fires on every `done`. But Q2 below locates that
   cost: ~97% is per-module fixed overhead (53 modules at ~350ms), ~3% is contract solving at
   ~11ms each. Fifty contracts add ~0.6s. So a wall-clock *budget* watches the wrong number —
   scope DP7 to the modules the step touched, which `m-motoko-dp7-verifier-gate.md` already
   defers as v2 work, and the marginal cost becomes one module's parse plus its contracts.
   Roll out in the `dogfood` profile first regardless.
2. **Fix the rejection message.** `session.ail:1826` hard-codes "The code you just wrote does
   not type-check." A Z3 violation or timeout arriving under that text is a false diagnosis.
   Distinguish type-check failure from contract failure before wiring.
3. **Pin the verified set.** A contract silently dropping from `VERIFIED` to `SKIPPED` must
   be red, or the gate can weaken without failing.

A vacuous contract layer can only make DP7 *approve*, so it is not a correctness hazard —
the hazards are cost and a wrong message.

**Done when**: `verification.command` includes `verify_core` in at least the `dogfood`
profile, DP7 re-verifies only touched modules, and the measured per-finalize delta is recorded
here alongside the slowest contract's solve time.

---

## P5 — Guard-predicate sweep (~1d, after P2; independent of P3 and P4)

The highest-value contracts in the tree are not in the modules the design doc listed. They are
on the guards, and RESEARCH §3 E7 measured both the gap and the fix.

**The gap.** In the write-path guard chain (`tool_runtime.ail:351-374`), `is_absolute_path`
(:276) has no test or property coverage — its contract is the only mechanical check on that
link. Worse, `has_shell_tokens` (:32) and `shell_tokens_in_process` (:50), which decide whether
a command is wrapped in a shell (`:20`, `:888`), have **no test, no property, and no contract**.

**The fix, and why it is not a restatement.** For each guard write a *pair* of substantive
contracts:

- **recall** — what the guard must catch. One-directional, so it survives the list growing:
  ```ailang
  ensures { (not contains(s, ";")  || result) && (not contains(s, "|") || result)
         && (not contains(s, "$(") || result) && (not contains(s, "`") || result) }
  ```
  Measured (E7): ✓ on the current body, ✗ with `";"` removed (counterexample `s = ";"`),
  ✓ with a ninth token added.
- **precision** — what it must not reject:
  ```ailang
  ensures { result == false || contains(path, "/") }       -- ✓ VERIFIED [73ms]
  ```

Both are strictly weaker than their bodies, so both classify **substantive** under ADR §1 and
count. Neither alone pins the guard (an always-`true` body satisfies recall); the pair is
nearly as strong as a restatement while each half survives a different legitimate edit.

**Steps.**
1. Promote `has_shell_tokens`, `any_shell_tokens`, `shell_tokens_in_process` to `pure func`
   where the fragment allows. `any_shell_tokens` is recursive — expect `RECURSIVE`, and
   annotate it rather than contorting it.
2. Write the recall/precision pair for `has_shell_tokens` and `starts_with_root_dir`.
3. Replace `is_absolute_path`'s restatement with a substantive contract if one exists; if it
   does not, leave the restatement and register it as a waypoint with that finding recorded.
4. Re-run `make test` — these are hot-path guards and promotion must be behaviour-preserving.

**Done when**: `verify_core` reports the shell-token guard proven, the mutation check (remove
a token, expect VIOLATION) is a test, and no guard in `validate_path_common` is covered by
nothing.

---

## Non-goals

- A coverage sweep toward "most `pure func`s have contracts". See P3.6.
- De-recursing `find_last` (P1.2 names it; it is a separate change).
- Contracts on `src/core/ext/**` effectful hooks — out of fragment by construction
  (`NOT_PURE`), and the design doc's open question 3 already settles this correctly.
- Retrofitting the P3.5 policy across the ~1545 existing declarations.
- Anything requiring the `ailang verify <verify.ail>` runtime mode — that is
  `m-motoko-verify-ail.md`, a different layer (post-condition checks on an artifact, per
  `023_hybrid_verification_cris` §8).

## Open questions

1. ~~Should amber fail the build, and when?~~ **Answered: split it by cause, and flip the
   failing half at P2** (ADR §3, P0 steps 1 and 4). Not "advisory until the register lands" —
   that ties a zero-cost ratchet to an expensive milestone, which is how the design doc's
   Phase 1 ended up shipped-and-empty. `unstated` (`requires`, no `ensures`) fails: an
   incomplete annotation is worse than none, because it reads as specified. `blocked`
   (`ensures` the fragment rejected) never fails: failing there punishes the attempt and makes
   *deleting the contract* the cheapest route to green. Population today is one file, fixed by
   P2, so tree-wide adoption is affordable now — unlike ADR §4's policy, which had to be
   `git diff`-keyed because of ~1545 existing declarations.
2. ~~How much does `verify_classify` cost, and does it decide whether P4's budget is
   affordable?~~ **Answered, and the premise was wrong.** Measured: contract solving is
   **~11ms per contract and linear** — 4/16/64 probes in one module take 67/183/694ms for
   integer contracts and 70/223/817ms for string-theory ones, so the two flavours barely
   differ and nothing blows up. The worst single contract measured anywhere in this project is
   73ms (`root_implies_slash`, a 9-way `startsWith` disjunction), so a pessimistic band is
   ~75ms per contract.

   Two consequences.

   **The two budgets are independent.** `verify_classify` emits two extra probes per contract
   and maintains `contracts.register` in CI. It never runs in DP7's path — DP7 needs only
   `verify_core`. At fifty contracts, classification is ~3 × 50 × 11ms ≈ 1.7s of solving plus
   per-module parse for the generated probe modules. It is a CI cost of a few seconds and it
   gates nothing.

   **P4's cost driver is not contracts.** `verify_core`'s 15.3s is ~97% per-module fixed
   overhead: 53 modules at ~350ms each (measured individually: `compaction.ail` 284ms,
   `ports.ail` 294ms, `phase_vocab.ail` 129ms, `tool_runtime.ail` 171ms *with* its four
   contracts — contract count is not what varies). Fifty new contracts add ~0.6s to that,
   about 3%. So "set a wall-clock budget and watch it" is the wrong instrument; the right one
   is **touched-file scoping** for DP7, already deferred as v2 work in
   `m-motoko-dp7-verifier-gate.md`. P4's precondition list is updated accordingly (ADR §5).

   What remains genuinely unknown is the *tail*: every contract measured so far is shallow.
   A contract over `_str_slice` arithmetic or a deep disjunction could time out rather than
   cost 11ms, and a timeout in DP7's path is the failure mode that matters. P3 should record
   per-contract solve time in the register so the tail is visible before P4, not after.
3. ~~Does the `spec-equals-body` tier deserve its own target — a "regression lock" sweep over
   guard predicates with no test coverage?~~ **Answered: no** (RESEARCH §3 E7). For both guards
   that motivated the question a *substantive* contract exists, verifies, and is strictly
   better — it catches the same regression with a counterexample and does not obstruct
   legitimate strengthening. A restatement is not the ceiling for a guard predicate; it is what
   you get when nobody looks for the weaker property. The sweep is worth doing and is now P5,
   writing substantive contracts rather than locks.
