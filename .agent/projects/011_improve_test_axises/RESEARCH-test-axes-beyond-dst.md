# RESEARCH: Test and verification axes beyond DST — what exists, what's dormant, what's missing

Date: 2026-08-13
Status: Research — survey + prioritization (no decision yet)
Pinned binary: AILANG **v0.33.0** (`ailang.lock`)
Relates to:
- `papers/motoko-dst-report/DRAFT.md` (§8 self-diagnosed evaluation gaps, §9 future work)
- `.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` (the seeded-axis-is-PBT classification)
- `.agent/research/DST/motoko-dst-generalized-system.md` (2026-06 "DST Plus Fuzzing" sketch, §290–320)
- `design_docs/planned/m-motoko-z3-contracts.md` (the unexecuted Z3 plan)
- AILANG docs MCP: `guides/testing.md` (native `property` + shrinking), `reference/implementation-status.md` (verification component status)

---

## TL;DR

Motoko already touches every testing axis this note surveys — mostly in ad-hoc, dormant, or
hand-driven form. The question is not "which new techniques to adopt" but "which existing
seams to industrialize." Ranked by leverage-per-effort:

1. **Z3 contracts** — toolchain shipped, gate wired (`make verify_core`, advisory), plan
   written (`m-motoko-z3-contracts.md`, est. 2–3 days), **6 contracts authored**. Execute the plan.
2. **Program shrinking** — the single most-cited gap (DRAFT §8/§9, SCOPE.md:68, ADR notes).
   Strict replay already exists, which makes ddmin over `ExecutionProgram` steps nearly free.
   Note: AILANG's native shrinker does **not** solve this (it shrinks values, not recorded programs).
3. **Systematic mutation of the SUT** — answers the paper's own top gap: *"no systematic
   mutation study showing which of the twelve invariant families would catch which classes of
   incorrect recovery. Reachability is not oracle strength."* Mutant rows today test the test
   machinery; nothing mutates `session.ail` / `decide` and measures kill rate per family.
4. **AILANG-native `property` adoption** — the language construct (QuickCheck-style, built-in
   shrinking, seedable) is documented and **unused anywhere in this repo** (461 inline
   `tests [` blocks, 0 `property` blocks).
5. **Boundary fuzzing** — design sketch exists (2026-06), never implemented. Target the parse
   boundaries the deterministic world cannot see.
6. **Metamorphic testing + small-scope exhaustive enumeration** — the novel additions; both
   have natural anchors in the codebase (the pair-of-executions discovery-contract family is
   already metamorphic; `decide` is pure and enumerable).

Not worth investing in: golden/snapshot tests (ledger + counting-as-oracle already covers
this, and the repo deliberately avoided them), live chaos testing (excluded from CI by
policy; the 11-class fault catalogue is the in-world equivalent).

---

## 1. Baseline: what the repo already has, per axis

| Axis | Status at HEAD | Evidence |
|---|---|---|
| DST | Shipped, 41-target `make dst` sweep, 12+1 invariant families, ~53 violation constructors, 11-class fault catalogue, discovery/strict-replay split | `src/core/dst_*.ail`, `scripts/dst/`, DRAFT §3 |
| Property-based | The **named predecessor** of DST here (ADR-001:33: "the seeded axis is property-based testing, not DST"); two codified rules (invariants-only; import policy constants). AILANG-native `property` construct **unused** | `scripts/dst/phase_c_seeded_dst.ail`, `compaction_seeded_dst.ail`, DRAFT §4.4 |
| Shrinking / minimization | **None.** Failing nightly seeds promoted to corpus by hand | DRAFT.md:780, 808; SCOPE.md:68–69 |
| Z3 / SMT | Wired (`make verify_core` / `verify_ext` → `ailang verify`, Z3 4.15.4 ships with AILANG), **advisory** in CI, 6 contracts total (`compress.ail:57,69`; `tool_runtime.ail:24,196,277,1007`) | Makefile:2082,2104; `.github/workflows/verify-extensions.yml` |
| Mutation testing | Practiced, hand-written: inline "mutant rows" in ~19 DST gates; `tools/test_coverage/mutants.py` (14 rows against `derive.py`); 147-site literal-mutation loop recorded once | `scripts/dst/invariants_dst.ail` (62 refs), 009/NOTE-b3:173 |
| Fuzzing | Design sketch only ("DST Plus Fuzzing", 2026-06): structured, in-world, seed-persisted; boundary list drafted. Never implemented | `.agent/research/DST/motoko-dst-generalized-system.md:290–320` |
| Golden/snapshot | None in Motoko (deliberate; the 206 `.golden` files are the vendored compiler's own) | — |
| Unit / inline tests | 461 `tests [` blocks across 43+ files; `make test_coverage` derives + cross-checks them (currently on `DST_KNOWN_RED`) | `tools/test_coverage/derive.py` |
| Runtime verification | Ledger invariants exist but run only in simulation, never over production ledgers | `src/core/dst_invariants.ail` |

Two standing house caveats worth repeating because they constrain everything below:

- *Mutation testing proves a guard CAN fire and cannot see a guard that fires too much* —
  stated in four places (Makefile:2355, derive.py:535, seeded_generator_dst.ail:78,
  invariants_dst.ail:10). Surviving control fixtures are mandatory in any mutation design.
- *Faults are modeled as outcomes at the typed boundary*, never Buggify-style in-code fault
  points — production carries no test-only branches (`dst_fault_catalogue.ail`). Any fuzzing
  or mutation design must not break this.

## 2. What AILANG v0.33.0 offers (verified against docs MCP)

- **`property "name" (x: int, y: int) = expr`** — QuickCheck-style, 100 cases default,
  conditional properties via `==>`, generators for int/float/bool/string/list/option/result/
  custom ADTs and records. **Shrinking built in**: binary search toward zero (ints),
  element/chunk removal (lists/strings), minimal counterexample reported. Reproducible via
  `AILANG_TEST_SEED`; case count via `AILANG_TEST_RUNS`; size bounds via
  `AILANG_TEST_MAX_SIZE` / `AILANG_TEST_MIN_INT` / `AILANG_TEST_MAX_INT`.
- **Contracts** (v0.6.1+): `requires` / `ensures` clauses, SMT backend with Z3, cross-function
  inlining, Dafny-style bounded recursion unrolling (`--verify-recursive-depth n`),
  policy mode for redundant verification.
- AILANG's own CI precedent: golden-file parser tests, per-package coverage gates,
  `make fuzz-parser` random-input fuzzing.

## 3. The axes, in priority order

### 3.1 Z3 contract expansion (execute the existing plan)

Lowest friction of everything here. The pipeline is proven end-to-end by the 6 existing
contracts; `m-motoko-z3-contracts.md` already proposes the per-PR rule ("every new
`pure func` needs a contract or a justification comment") and a candidate table.

What SMT adds over DST: **∀ where DST samples.** Best targets are the pure algebra:

- `decide : StepState → StepDecision` (`step_machine.ail`) — postconditions on decision
  well-formedness per state class.
- **The invariant checkers themselves** (`dst_invariants.ail`) — a contract-verified checker
  hardens the oracle every other axis leans on. This is the highest-value target.
- `compress.ail` bounds (already started), program serialization round-trip properties.

Path: grow contract count → track proof health as a number the sweep reports → only then
flip advisory → blocking (consistent with the standing ADR decision in
007/PLAN-ci-dst-gates.md:64,196 that Z3 stays advisory until proof health is deliberately
raised).

Open questions: how `--verify-recursive-depth` interacts with the deeply recursive ledger
folds; whether the two active language bugs (polymorphic arithmetic in lambdas; pattern
guards not evaluated) block any candidate contract.

### 3.2 Program shrinking (ddmin over `ExecutionProgram`, strict replay as oracle)

The reproduction key is the serialized `ExecutionProgram` (`dst_program.ail`), **not the
seed** — so AILANG's native value-shrinker is the wrong tool, and nothing off the shelf
applies. But the expensive half is already built: strict replay (`dst_replay.ail`,
`strict_replay_dst.ail`) re-executes a program without the generator and compares normalized
terminal traces. That reduces shrinking to classic delta debugging:

1. Failing discovery run records program P violating invariant constructor V.
2. ddmin over P's step list (and secondarily over per-step payload fields): candidate P′ →
   strict replay → keep P′ iff the violation is **the same constructor V** (not merely "some
   violation" — the one subtle design decision; see below).
3. Minimized P\* is auto-promoted into the fixed corpus with provenance (nightly run id,
   original seed, original/minimized step counts).

At ~381 ms/seed replay cost, a 100-probe ddmin run is ~40 s — viable in the nightly job
itself. This closes both halves of the most-cited gap: no shrinking, and no automatic
promotion.

Design decision to settle before implementing: **what counts as "same failure."** Same
constructor is the obvious criterion; but constructors were deliberately made 1:1 with rules
(~53 of them), so same-constructor may still be too coarse (e.g. pairing violations at
different steps) or too fine (a shrink that shifts the failure to an adjacent, equally
interesting constructor gets discarded). Proposal: primary criterion = same constructor;
record discarded shrinks that failed with a *different* constructor as secondary findings
rather than dropping them.

Validity constraint: a shrunk program must still be a well-formed program (correlation ids
pair up, versioned schema intact). Either ddmin operates on a step granularity that
preserves pairing by construction (remove call+result atomically), or replay's existing
program validation rejects malformed candidates cheaply — the latter is probably free.

### 3.3 Systematic mutation of the SUT (the oracle-strength study)

DRAFT §8's self-diagnosis, verbatim: *"The evaluation is conformance-heavy and yield-light…
there is no systematic mutation study showing which of the twelve invariant families would
catch which classes of incorrect recovery. Reachability is not oracle strength."*

Everything mutation-shaped in the repo today points the arrow at the **test machinery**
(mutant rows prove a specific guard goes red; mutants.py mutates the coverage deriver). The
missing study mutates **production**: the recovery branches in `session.ail` and the
transitions in `decide`, then runs the DST sweep and records, per mutant, which invariant
family (if any) kills it.

Output = a kill matrix: 11 fault classes × 12 invariant families, with per-family mutation
score. This is exactly the yield table the paper wants, and it directly tests the fault
catalogue's claim that each fault class maps to a *named* recovery branch.

Mechanics: no AILANG mutation framework exists. Feasible operators without one:
- literal swaps (the 147-site cache-cold loop in 009/NOTE-b3:173 is the precedent),
- comparison/boolean operator flips, branch-arm swaps in `match`, off-by-one on bounds —
  all implementable as source-text rewrites keyed off the code-graph tooling
  (`tools/code-graph/`), or via the vendored compiler's AST if text-level proves too noisy.

Scope control: full sweep per mutant is 196 s at -j8; a 100-mutant study is ~5.5 h — a
nightly/weekly job, not a PR gate. Start with mutants targeted at the 9 reached recovery
branches rather than exhaustive operator application.

House caveat applies: include surviving-control mutants (changes that *should* be caught by
nothing, e.g. log-message edits) to detect over-firing invariants, per the four-times-stated
rule.

### 3.4 AILANG-native `property` adoption (value-level PBT)

Complementary to the seeded axis, not competing with it: the seeded axis is workload-level
PBT over the whole driver; `property` blocks are value-level PBT over the pure algebra, with
free shrinking. Zero usages today. Candidates where algebraic laws exist:

- phase vocab / ledger record encode-decode round-trips (`phase_vocab.ail`),
- ledger normalization idempotence (normalize ∘ normalize = normalize),
- `ExecutionProgram` serialization round-trip (this also hardens the shrinking work in §3.2),
- compress bounds and monotonicity, generator-state threading laws in `dst_generator.ail`.

Constraints to respect: the generator modules structurally must not import `std/rand`
(`world_state` gate) — `property` blocks live in test files, so this should not collide, but
verify the structural assertion's scope before adding property files under `src/core/`.
Also decide interaction with `make test_coverage`'s deriver: it counts `tests [` blocks
syntactically; `property` blocks would be invisible to it (or worse, "phantom") until
`derive.py` learns the second syntax.

### 3.5 Boundary fuzzing (implement the 2026-06 sketch, narrowed)

DST already *is* structured fuzzing — generator + fault catalogue + strong oracle. The
genuine delta is **malformed input at parse boundaries**, which the deterministic world
deliberately never produces. The sketch's boundary list, narrowed to the three highest-value:

1. the parser over model-generated text (tool-call extraction from prose),
2. the JSONL rpc boundary (`rpc.ail` ↔ TS TUI),
3. the compose-snippet effect-declaration guard
   (`compose_guard_semiformal.test.ts` / `env-server.ts`) — TS-side, `fast-check` under
   jest works today with no new infrastructure.

Keep the sketch's discipline: seed-reproducible, seed persisted in the failure trace, no
coverage feedback assumed (the AILANG interpreter has none) — generational fuzzing with
dictionaries derived from the wire schemas. Faults remain modeled at the typed boundary;
fuzzing malformed *bytes* into a parser does not violate the no-Buggify rule because the
parser's input domain legitimately includes garbage.

### 3.6 Metamorphic testing (new axis, natural fit)

For an LLM harness there is no ground truth for "correct behavior," only relations between
runs — which is exactly the metamorphic setting, and the thirteenth invariant family
(discovery-contract, over a *pair* of executions) is already metamorphic in structure.
Candidate relations, each checkable with existing scripted-ports machinery:

- Installing a **no-op extension** leaves the ledger unchanged modulo hook events
  (this would also convert part of the 40-hook vacuity accounting from a static count into a
  dynamic guarantee).
- **Compaction on/off** preserves decisions when context fits either way.
- **Tool registration order permutation** does not change outcomes.
- Latency scaling below deadline thresholds changes only clock readings, not decisions
  (the latency-pair gate is halfway to this already).

### 3.7 Small-scope exhaustive enumeration / lightweight model checking

`decide` is pure. For a bounded projection of `StepState`, enumerate **all** states and check
decision well-formedness exhaustively — strictly stronger than sampling for the step
machine, and cheap because no world is needed. Related: symbolic execution with the
already-present Z3 could settle whether the 2 waived fault classes are truly unreachable or
merely unreached — turning waivers into either proofs or bugs.

### 3.8 Invariants as production monitors (second life of the oracle)

The 12 families are typed, pure, and cheap. Running them over *real* session ledgers (not
simulated ones) turns the DST oracle into runtime telemetry — the standard FoundationDB
move. No new invariant code; only a reporting path. Fits the "evals are not regression
oracles" philosophy since it asserts ledger well-formedness, never model quality.

## 4. Explicitly rejected

- **Golden/snapshot tests** — the ledger oracle + counting-as-oracle + pinned digests
  already occupy this niche; the repo avoided free-floating snapshots deliberately.
- **Live chaos testing** — no live/network target runs in CI by policy; the fault catalogue
  is the in-world equivalent; live-provider runs stay manual calibration smokes.
- **LLM-as-judge / eval-based regression** — excluded by the report's philosophy ("evals are
  not regression oracles"); nothing here reopens that.

## 5. Open questions

1. Shrinking: is same-violation-constructor the right "same failure" criterion, or does it
   need a coarser equivalence over constructor families? (§3.2)
2. Mutation: text-level rewrites vs vendored-compiler AST mutation — which survives AILANG
   version bumps with less maintenance? (§3.3)
3. Z3: does `--verify-recursive-depth` reach anything useful on the ledger folds, and do the
   two active language bugs block any candidate contract? (§3.1)
4. `derive.py` and `property` blocks: extend the deriver before or after first adoption? (§3.4)
5. Which axes deserve WI-numbered execution plans vs staying research — proposal: §3.1 and
   §3.2 go to PLAN documents first; §3.3 needs a small operator-feasibility spike before
   planning.
