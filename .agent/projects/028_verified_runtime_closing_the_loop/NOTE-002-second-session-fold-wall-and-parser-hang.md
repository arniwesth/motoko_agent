# NOTE-002 — Second independent session: the fold-verification wall, a parser hang, and the example that rots (2026-08-30)

Evidence base: a second, independent Motoko session (~130 live steps), run one
day after the first assessment (NOTE-motoko-session-assessment.md, 2026-08-29).
Every claim below is backed by a tool result from that session. Findings that
**cross-confirm** the first session are marked `[x-confirm]`; findings that
**extend** it are marked `[extend]`; one finding **contradicts** an assumption
both sessions carried, and is the most actionable item in this note.

## What was verified

| Item | Result |
|---|---|
| `make check_core` | 56 passed, 0 failed — run twice, start and end of session `[x-confirm]` |
| `make verify_core` | 9 contracts proven, 0 unstated, 2 blocked, 0 files failed; 49 bare `[x-confirm]` |
| `make test` (core) | 19/19 passed `[new]` |
| `make registry_gen_check` | registry matches generator `[new]` |
| TUI protocol tests (bun) | 14/14 pass (stream-protocol, tool-progress, unknown-events) `[new]` |
| End-to-end loop | `run_v2_with_scripted_ports` + `deny_all_rt` → `run_summary: finish_reason=stop, steps_executed=2` with real ledger JSONL `[new]` |
| Architecture | Production `step_machine.decide` (pure) driven offline: `RunTools → CallModel → Finalize(model_stop)`; sealed `History` type enforces system-head-prefix invariant by construction `[new]` |
| Calibration | `affine_calibrate` replicated in py: 3/3 value matches; stability experiment: affine spread 5.7% vs naive 45.2% across anchor sizes; 5 live `MotokoRuntimeStatus` snapshots show density 1.96→1.57 as fixed overhead dilutes — the anchor design earns its keep `[new]` |
| DST PRNG | djb2+MINSTD: 9/9 exact py↔AILANG state matches across a 3-draw trajectory; zero-absorbing-state fix confirmed `[new]` |

## Defects found (all reproduced, not hypothesized)

1. `[new]` **Parser hang on escaped quote inside interpolation.**
   `"${show(f(\"x\"))}"` sends the vendored parser into `PAR_INFINITE_LOOP`
   (hangs, reports at EOF; delimiters balance). Bisected: prose-side escapes
   and plain-string args pass alone; the escape *inside the interpolated
   expression* is the trigger. Workaround: hoist the argument to a `let`.
   Worst-case failure mode for an agent consumer: silent spin, not an error.
2. `[new]` **Example rot in the teaching set.**
   `ailang/examples/ai_devtools_workflow/discount_calculator.ail` — the file
   that *teaches contract syntax* — no longer compiles (`++` on strings was
   removed after it was written). Examples are not CI-gated, so the docs rot
   silently. Ironic pairing with defect 1: the language's idiom moved out from
   under its own tutorial.
3. `[x-confirm]` **Optional-backend fragility.** Lean/Lake missing in this
   container too — Lean proof cells report "Lean/Lake unavailable; cells were
   skipped". Same consequence as first session: proof-tier claims must degrade
   to model-checking. (`FORK.md` still absent `[x-confirm]` — PLAN-001 item 3
   remains open.)

## The fold-verification wall (the session's main finding) `[extend]`

`compaction.ail` annotates its fold-based functions "SKIPPED — Z3 fragment
requires non-higher-order". **That annotation is stale.** The real blocker is
elsewhere, and probing the live verifier showed the wall has four distinct
layers:

| # | Probe (live `ailang verify`) | Result |
|---|---|---|
| 1 | `(length(s)+3)/4`, primitive callee | ✅ VERIFIED, 53ms |
| 2 | `foldl(\acc x. acc+x, 0, xs)` literal lambda | ⚠️ SKIP: *calls foldl whose signature uses an unencodable type "b"* |
| 3 | `map`/`filter`, literal lambda | ⚠️ SKIP: same, `Option[b]`/`Option[a]` |
| 4 | hand-recursive helper `sum_go` | ⚠️ SKIP: callee closure, "not SMT-encodable in this context" |
| 5 | self-recursive cons match + `--verify-recursive-depth 8` | ❌ **ERROR**: `match pattern: unsupported pattern type *core.ListPattern` |

Mechanism, from source:

- `hof_inline.go` **already implements** literal-lambda specialization for
  `map`/`filter`/`foldl` (`knownHOFStdlib`, `matchHOFCall`), generating
  head/tail-based code that *avoids* the `ListPattern` encoding gap — probe 5
  shows the general unroller lacks that workaround and errors (an ERROR, which
  per `verify_core`'s own taxonomy would fail the build, unlike a skip).
- But `cmd/ailang/verify.go` (~L317) runs the **callee-sort gate**
  (`firstUnencodableCalleeType`) *before* codegen Step 1.55 (`InlineHOFCalls`)
  can specialize anything. The gate sees foldl's polymorphic signature,
  rejects, skips — the specializer never fires.
- `encodable.go:hasHigherOrder` also does not consult
  `AllHigherOrderIsInlinable` (one file over), so literal-lambda HOF calls
  draw `HIGHER_ORDER` rejections.

**The fix is re-wiring, not new machinery.** In priority order:

- **W1**: exempt `$builtin`/`std/list` `map`/`filter`/`foldl` from the
  callee-sort gate in `verify.go` + `ai_check.go` (they are specialized away
  before encoding; their type variables cannot leak).
- **W2**: `IsSMTEncodable`/`IsSMTEncodableForCallee` should consult
  `AllHigherOrderIsInlinable`, so literal-lambda HOF calls stop drawing
  `HIGHER_ORDER`.
- **W3**: compute the callee closure *after* HOF inlining (or dry-run the
  inliner), so the gate sees the monomorphic body actually encoded.
- **W4**: acceptance contracts on the unlocked functions —
  `estimate_tokens_messages` `ensures { result >= 0 }` + monotonicity in list
  length; each becomes the pinned regression for W1-W3.

Safety argument: the architecture already fails safe (a bad fold encoding
degrades to SKIP, never to a false proof — ADR-001's taxonomy holds). Why
folds *first*: W1-W3 are surgical vs. the `ListPattern` sort/constructor
project (probe 5) which is a real one with undecidability/latency risk; folds
are the idiom the core is written in (token sums, cost meters, draw counts —
today every one auto-skips, teaching contributors to avoid the language's
native style); and the payoff targets the compaction policy that governs this
very session's context window. Z3 is pinned at 4.8.12 (2019); modern sequence
theories might eventually obsolete the unroller, but W1-W3 is a weekend.

## Structural observation `[extend]`

The first session mapped the AILANG/TS asymmetry. This session adds the
**second axis: the tiering inside verification itself.** It degrades gracefully
and honestly — Z3 verified → Z3 skipped → exhaustive model-check → unit tests —
and the runtime reports which tier produced each claim (this session's proofs
were explicitly reported "skipped, not proven"). But the top of the ladder is
environment-dependent (Lean absent here), and the bottom two tiers (4, 5)
carry the compaction policy — the highest-consequence numeric code in the
runtime — with zero solver coverage. The fold wall (above) is what pins the
compaction math to tier 4. Closing it moves the most safety-critical heuristic
in the harness from "tested" to "verified" — the same move ADR-001 makes at
the finalization boundary, applied to the numeric core.

## Cross-session consistency

Two independent sessions, one day apart, agree on: gate honesty (56/56,
9 proven/2 blocked/0 failed), telemetry honesty, fail-closed-at-the-cell /
fail-open-at-the-boundary as the pattern (DP7 there, batch-skip there, both
structural), and doc-drift as a recurring cost of the fast-moving language.
The second session adds: the verification *coverage* gap has a specific,
mechanical, already-90%-built fix (W1-W3) — stronger than the first note's
general "Z3 fragments are narrow" observation.

## Verdict

Consistent with NOTE-001's 9/10 / 7/10 / 6/10. The fold-wall finding does not
move the scores; it converts one vague work item ("extend the Z3 fragment")
into a concrete, ordered, small diff (W1-W4) with a safety net already in
place — and identifies the `ListPattern` gap as the item to *not* do first.
