# ADR-001: Which of 013's caps get worked first, in what shape, and where — the limit type, the world ordinal, the AILANG asks, and a new home for commands + interpreter

Date: 2026-09-05 (v2 and v3: 2026-09-05, same day)
Status: **Proposed (v3 — supersedes v2 after a second adversarial review).** v1 was reviewed
by a Claude delegate and rejected (`REVIEW-adr001-verdicts.md`): C1 carried factual errors and
D2's observer and its four-site red demonstration failed. v2 was reviewed by a Codex delegate
and rejected (`REVIEW-adr001-v2-verdicts-codex.md`): D2's observer was found viable but its
gate had no run framing, no single counted domain, no helper interface before the loop exists,
and an incomplete inventory; D1 conflated two denominators; several numbers had been copied
from the first review rather than re-measured. v3 answers the Codex list in full. Decides the
five candidates in `NOTE-002-re-read-2026-09-05.md` §7 and answers RESEARCH open question 7.
Nothing below has been implemented.
Grounded at: HEAD `62cb753` on `arniwesth/exit-intent-abi`. This work lives on branch
`arniwesth/013-dst-architecture-adr`, cut at `3fe71b0`; `git diff --stat 62cb753 3fe71b0`
touches only `tools/verify_classify/new_contract_policy.py`, so every citation below holds at
the branch point. The working tree carries NOTE-002, this ADR, both reviews (untracked) and
two amendment markers in 028 PLAN-002 (uncommitted).

Grounding verified at `62cb753`, 2026-09-05. Numbers marked † are from this session or the
Codex review's re-measurement and are not in NOTE-002; the rest reproduce from NOTE-002 §1–§4.
- No RESEARCH §4 item has been started in the tree. NOTE-002 §2 records a Linear search on
  2026-09-05 that found no issue naming one; that claim is that dated search's, not re-run here.
- `make verify_core`: 11 contracts proven, 0 unstated, 1 blocked, 48 bare; 9 substantive.
- `make fault_catalogue`: 11 classes; four `FaultBoundary` variants; `required_class_ids()`
  pinned at 11 (`dst_fault_catalogue.ail:288`). `make event_vocabulary`: 34 `LedgerEvent`
  variants, 34 rows, 34 goldens.†
- `src/core/dst_*.ail`: 20,858 lines; `session.ail` 3,813; `tool_phase.ail` 642; `c2_loop` 682.
- `ContextLimitRead = { value: int, next_state: WorldState }` (`context_usage.ail:34`); both
  resolvers return `value: 0` on every miss (`:91, :94, :132, :135–141`); `resolve_context_limit`
  (`:164–167`) falls through to the catalogue on an override of `0`.
- `ExtCtx.context_limit: int` with "0 means unknown" is v2.2.0-vintage ABI text
  (`packages/motoko-ext-abi/types.ail:549–554`); the ABI is at 7.0. No `CompactionPolicy` or
  `StepPolicy` reference exists under `packages/`.†
- Driver state is `C2LoopState` (`session.ail:383`); `world_state` (`:400`), `trace` (`:412`)
  and `emissions` (`:428`) are fields of that one record, rebuilt by literal at `:2136`,
  `:2183`, `:2380`, `:2407`. `:177` is `TracedSessionResult`, the result record.†
- **The wire is stdout IO.** `ledger_emit` (`:335–342`) calls `emit_json` (`:222–224`), which is
  `println` under `IO`; `emit_trace_event` (`:280–288`) reaches `Trace.event` only for
  `session_start` and `run_summary` (`:226–228`). Emission and append are separate calls:
  `ledger_emit` returns `()`; `ledger_append` (`phase_vocab.ail:604–606`) is pure and returns a
  new trace. Wire-vs-returned parity is a shell wrapper, `scripts/dst/run_ledger_parity_wire.sh`,
  which captures the whole process's stdout, strips the eight `LEDGER_TRACE` labels, and
  compares aggregate counts per required logical variant; all 104 wire lines of that fixture
  carry one `session_id`.†
- Leaf request sites by comment-aware grep:† `session.ail` has 22 direct `Ports` calls, of which
  ten are the `ExtPorts` forwarding fields built at `:910–1178` (`ext_ai_step` at `:816` among
  them) and one is the post-finalization `env_get` at `:3385`; `tool_phase.ail` 3 (`:413`,
  `:414`, `:421`); `context_usage.ail` 8 behind the `ContextReader` record, whose functions
  carry closed `{Env}` / `{Env, FS}` rows. The driver's model call is `dispatch_step` at
  `:2676`, whose leaf is `ports.model_step` in `src/core/test/stub_step.ail:705–713` — outside
  `session.ail`. `ExtPorts.ai_step`'s row is `{AI, IO, Trace}` (`types.ail:294`); the other
  forwarding rows are Env/FS/Clock/Process only.
- Full `WorldState` literals: three, at `ports.ail:725`, `ext_world.ail:544`, `ext_world.ail:651`;
  the other `clock_ms:` matches are record updates, a field declaration and `initial_clock_ms`
  parameters. The token codec `world_json`/`world_of_json` (`ext_world.ail:543–553`) decodes with
  per-field fallbacks.†
- `phase_vocab.ail` importers: 15 (13 outside `src/core/test/`). `context_usage` imports `ports`
  (`:9`) and `ports` imports `phase_vocab` (`:44`), so a type defined in `context_usage` cannot be
  imported by `phase_vocab` without a cycle.†
- `SessionStart(SessionStartInfo)` carries `{ task, model, mode }` (`phase_vocab.ail:585`, `:727`),
  is display-only and wire-only, and is emitted at `session.ail:3288` once per follow-up user
  message in the live loop. The initial live turn (`:3478`) and every traced entry call the
  shared helper at `:2994`, which calls `c2_loop` (`:3021`) and emits no session-level event.†
- The status surface is reachable from DST: `runtime_status_json` (`:555`) runs under the
  `MotokoRuntimeStatus` builtin in the real `RunTools` arm (`:2542–2546`), and
  `scripts/dst/runtime_status_tool_dst.ail` (under `make compaction_dst`) drives it and parses
  the returned tool message; it passes at HEAD.†
- `should_checkpoint` (`step_machine.ail:85–90`) passes the **raw** `pol.compaction.context_limit`
  to `history_usage_percent_calibrated` and `checkpoint_would_relieve` (`phase_vocab.ail:387–394`,
  both `int`); the seal subtracts the output allowance internally (`phase_vocab.ail:145–153`).
  `calibrated_usage_percent_anchored` is imported by `compaction_ai.ail:16`.†
- Fixture constructors: `mk_policy` 17 call expressions, `mk_state` 15, `mk_state_with_messages`
  3 (35 total, three definitions, `step_machine.ail:145–179`); `mk_state*` and the script helpers
  `state_with_pressure` / `state_from_msgs` use the int as `last_input_tokens` telemetry, not
  as a policy limit.†
- `DST_KNOWN_RED :=` is empty (`Makefile:493`); `sweep_summary.sh` prints a NOTE for a listed
  target that passes (`:82–86`, `:106–111`) and `Makefile:512` returns the original rc.
- `tools/predicate-anchors/anchors.sh` **checks** five `session.ail` pins (`:384–385`, lines
  `1164 1423 1529 3016 3126`) and edits nothing; its six-file cascade list is at `:287–293` and
  the "contract-frozen unless the item prices this" sentence at `:301`.
- `make dst` was **not** run in this session or by either review. D6 exists because of that.

Relates to:
- `REVIEW-adr001-verdicts.md` (v1, Claude) and `REVIEW-adr001-v2-verdicts-codex.md` (v2, Codex)
  — the evidence for every retraction below. Cited as F-numbers with the reviewer's initial:
  cF1 is the Codex review's F1; kF1 the Claude review's.
- `RESEARCH-core-architecture-for-dst.md` — the five caps and §4 sequence. Re-sequenced, not
  re-argued.
- `NOTE-issue-165-dst-architecture-findings.md` (NOTE-165) — §2, §5, §8, §16.
- `NOTE-002-re-read-2026-09-05.md` — the measurements, with reproduce commands.
- `../028_verified_runtime_closing_the_loop/` — ADR-001 (the fail-closed rule D1 *departs*
  from), NOTE-005 §1 and its suggested item 1 (which D1 absorbs), NOTE-002 (fold wall, W1–W4),
  PLAN-002 items 2–3 (which D4 joins; its item-3 marker was corrected with this version).
- `../027_z3_contracts/ADR-001-contract-classification-register.md` — the unit-of-progress
  discipline and the retraction-first form.
- `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` — D1 there
  ("every request returns a successor"); D3 there (`:816–830`, a required class needs a
  production outcome, recovery branch, transition and explicit applicability or waiver);
  lines 340–341 ("exactly one home, visibly threaded").
- `../011_improve_test_axises/NOTE-declare-the-chunk-draw-range-closeout.md` — the three-commit
  route for a schema or version bump.
- `../021_herdr_delegation/DESIGN-exit-intent-abi.md` and `src/core/ext/exit_manifest.ail` —
  the exit end D2 part 5 and D5 change.
- `.agent/learnings/2026-09-05-mocked-seams-and-overclaiming-prose.md` — §5 (decoys), §6
  (prose that overclaims), §7 (gates). v1 and v2 each broke §6; v3 is written under it.

---

## Version history and retractions

**From v1 (Claude review; all sixteen v2 retractions were re-checked one by one in cF12 and
stand, with one wording correction folded in below).** The four WI-D4 sites perform no request
and cannot serve as a red demonstration. A same-record high-water mark cannot see a
whole-record drop. Per-adapter increments double-count under recording. `ports.ail:219`
anticipated the interaction-log ordinal. "Exactly two places" was false. D1 is fail-loud, not
028's fail-closed. The replay-contract ask had shipped. PLAN-002 items 2–3 are not
preconditions. A passing known-red target prints a note. Costs were understated.

**From v2 (Codex review).** Each names the finding.

1. **D2's gate had no run frame (cF1).** DST scripts run many traced invocations per process
   under one `session_id`; the parity wrapper aggregates counts and cannot attribute a wire
   line to a run. "No duplicate across the stdout stream" would fail two honest runs and pass
   a run that dropped its last request. D2 part 3 now frames every invocation.
2. **The counted domain was inconsistent (cF2).** If the helper is the only writer, exempt
   forwarders create no gaps; "a gap is attributed, not red" excused an error in the counted
   domain. The census subtraction `ordinal − length(log)` was false because the log also
   holds extension requests. `hook_guard` does not check successors and was the wrong gate to
   cite. D2 now counts helped leaf requests only, strictly +1.
3. **The inventory double-counted and omitted the model call (cF3).** The "24 + 3 + 8 plus
   forwarders plus `:3385`" list counted the forwarders and `:3385` twice; there are ten
   forwarding fields, not six; `ext_ports_of` construction calls are not request sites; and
   `dispatch_step` → `stub_step.ail:705–713` is the driver's model call and was outside the
   three scan roots. "The forwarders cannot emit" was false for `ai_step`.
4. **"Like every event" and the classification tradeoff were wrong (cF4).** Emission and
   append are separate calls the helper must both perform. A display-only `WireRecord` in the
   returned trace is already a violation (`DisplayOnlyInTrace`), so display-only was not a
   cheaper option but an illegal one under part 2. Strict replay compares interactions and the
   trajectory key hashes interactions, so "moves every replay digest" had no consumer.
5. **The helper had no interface before the loop exists (cF5).** The eight resolution reads
   run in closed `{Env, FS}` rows before `C2LoopState` is built; the loop's trace is seeded
   empty; a `context_usage` import of `session` is a cycle. D2 now separates a pure advance from
   a session-side witness and seeds the loop trace from the bootstrap.
6. **The exit repair and the drop list were incomplete (cF6).** `exit_manifest.publish_exit_manifest`
   returns a `bool` and discards the rendered world at `:182–205`; appending the publish
   request after `RunSummary` would be `RecordAfterTerminal`. A second reachable drop exists at
   `:2730`. D2 part 5 now orders the exit before the finalizing clock and covers `:2730`.
7. **D1's checkpoint denominator is raw (cF7).** Handing `should_checkpoint` a budget net of
   65,536 changes policy under `Bounded`, violating rule 4. The exit context is an explicit
   literal `0` (`:3399`), not a projection. `Bounded → result == raw_window` with `result >= 0`
   needs positivity by construction. There are four `mk_v2_ext_ctx` calls, one exit literal and
   two RPC literals.
8. **D1's per-run record and compatibility claims contradicted each other (cF8).** `SessionStart`
   is per follow-up turn, absent on the initial live turn, and carries no policy; a new event
   changes the returned trace and the vocabulary version, so D1 is not wire-schema-neutral and
   is D6-gated like D2. A status fixture already exists and is the witness. Unknown's reason
   must be the failed chain, not `ProfileConfigAbsent` when the catalogue then succeeded.
9. **Numbers copied from the first review were textual matches (cF9).** Three full `WorldState`
   literals, not seventeen; 35 constructor call expressions across three definitions, not 38
   signatures; two of the six script constructors carry telemetry, not a limit; 31 of the 198
   `next_state` lines are comments.
10. **D3's payoff claims exceeded the cited designs (cF10).** The replay-contract registry
    landed *partially* (Rand pilot, AI labels; Clock/Net/FS in another sprint); scope-params
    freezes Rand+AI grants only, so "converts 20 entries to measured" was unsupported; the
    handlers doc describes language work, not a proof that the userland stack disappears.
11. **D4's end state was asserted from purity (cF11).** A pure `step` does not by itself sit in
    the solver fragment, and IO-capable hooks and callbacks can still print. D4 now names pilot
    gates. `make anchors` checks pins and does not re-baseline them. Landing D1 and D2 on one
    branch does not pay the cascade once if both move pinned lines.
12. **The wire was misidentified as a `Trace` effect (c§3).** It is stdout IO. The `export_trace`
    header's description is superseded by the implementation.
13. **v2's opening misdescribed the v1 verdict (cF12).** The v1 table rejected C1 and D2; D1 was
    accepted with corrections.

C2 and C3 have now survived two reviews unchanged.

---

## TL;DR

| # | Decision | Cost |
|---|---|---|
| D1 | The resolved context limit becomes a sum in a leaf module; three named projections serve every `int` surface; `Unknown` carries the failed chain and is loud on every poll and in one per-run logical record | 5–8 days, D6-gated |
| D2 | A world ordinal advanced by one pure function at every helped leaf request, witnessed onto the stdout wire by `session.ail` before the successor can be dropped, and checked per framed run at shell level for strict +1, no duplicates, and final equality | 6–9 days after the inventory and D6 |
| D3 | Three AILANG asks as local records now and upstream through the feedback channel, owner-filed; one 012 evaluation entry for the partially shipped replay-contract registry | half a day plus filing and a bounded evaluation |
| D4 | Commands + interpreter becomes a phase of 028 PLAN-002, sequenced after its items 2–3; the tool phase is the pilot; two pilot gates named | none now |
| D5 | Lifecycle at both ends; each fault class enters the pinned list only when its own boundary is driven and its outcome reachable | none now |
| D6 | The sweep at the branch point is run and disclosed before D1, D2, D4's phase, D5, or §2.A | half a day, reds unpriced |
| D7 | D1–D3 get one PLAN here; D2's first deliverable is the inventory; D4 lives in 028; §2.A gets a spike; §2.C and `WorldM` get nothing | — |

Cluster: **12–18 working days**, excluding standing-red repairs. Not a commitment; a range
derived from the site lists in the Codex review.

---

## Corrections to the inputs

**C1 — RESEARCH §2.B1 is ambiguous; this ADR takes the reading that puts the observer outside
the world.** RESEARCH proposes "a monotone request ordinal in `WorldState`, plus a finalization
invariant that the returned world's ordinal equals the recorded request count", without saying
who keeps the count. Read as the world's own log, the check is vacuous: a dropped successor
discards its own increment and its own log entry together. Read as a count kept outside the
world, B1 is D2. Two facts from the tree bound D2: the interaction-log ordinal is assigned at
exactly one site (`record_interaction`, `ports.ail:1516–1524`, `:1532`), the single-assignment
shape D2's `advance` copies; and the one observer a whole-record drop cannot un-happen is the
stdout wire written by `ledger_emit`. Drops that exist today: the documented one at `:3265`
(the stdin multi-turn loop, which no deterministic run enters), the post-finalization one at
`:2372 → :3385 → :3409–3410` and inside `exit_manifest.ail:182–205`, and the non-retryable
provider-error path at `:2730`, which reads `MOTOKO_CAPTURE_FAILED_PAYLOAD` from
`st.world_state` and discards the successor. The list is what two reviews found; it is not
claimed exhaustive — the inventory in D2 part 6 is what makes it so.

**C2 — NOTE-165 §16 ranked the sentinel fix priority 3.** It became 028 NOTE-005's
highest-consequence finding fourteen days later (NOTE-002 §3). D1 is first.

**C3 — RESEARCH §2.A is not a prerequisite for shrinking**, and the sunholo fork's missing
profiles are runtime config directories, not `ProfileDefinition`s (NOTE-002 §4.5, §4.6).

---

## Context / the question

NOTE-002 measured 013 against `2192092`: every cap the same size or larger, no item started,
and the picture changed by six developments it had not seen. The question this ADR answers is
narrower than RESEARCH's: *what is worked first, in what shape that can actually go red, and
which project owns it* — given a contract tier that stops at effectful bodies, a second ABI
major just shipped, a second tree adopting `Ports`, and a sweep whose state at HEAD nobody has
established.

Two rules bound every decision, and this version says honestly where they apply:

- **An absent input must not render as health.** NOTE-005 §1 located a measurement boundary
  where five consumers, each individually correct, compose into "0% because unmeasured"
  reading as "0% because healthy". 028 ADR-001's rule at *enforcement* boundaries is
  fail-closed and blocking. D1 applies fail-loud, non-blocking, at this *measurement*
  boundary, and records the departure.
- **A gate, not a paragraph** (learning §6–7). D1, D2 and D6 name executable gates and the
  fixtures that prove the gate can see. D3 and D7 are administrative and have deliverables,
  not gates. D4 names its pilot's gates as acceptance goals. D5 is deferred and cannot waive
  D2's obligations at the exit end.

---

## Options considered

Kept from v2, where both reviews found the options real. Two comparisons are restated so they
are no longer loaded (cF11).

**For the limit (D1).** 1. Status field only (NOTE-005 item 1) — visible to a poller, invisible
to `decide`. 2. **A sum in the core, `int` projected at the ABI — chosen.** 3. A sum through the
ABI — the next major. 4. Refuse under `Unknown` — 028's rule applied literally; rejected now
(2 of 14 profiles set an override, the catalogue has 23 rows, NOTE-008 ran an uncatalogued
model for a full session); loud, not blocking. 5. An additive reason field beside the `int` —
two homes for one fact; rejected on `ports.ail`'s own `file_remove` argument.

**For the ordinal (D2).** 1. The count inside the world — vacuous (C1). 2. A same-record
high-water mark — rejected (kF1). 3. **The successor's ordinal witnessed onto the stdout
wire at each helped request, checked per framed run — chosen.** 4. Wait for D4's interpreter —
not taken: the field, the codec, the wire event and the two production drops are unchanged by
D4; the inventory collapses under it, and D2 says so. 5. A linear world token — upstream.

**For classification of the new events.** Logical, appended and emitted, is the only choice
compatible with the current observation contract: the vocabulary's D6 criterion makes an event
whose presence or order can change an invariant result logical, and a display-only record in
the returned trace is already `DisplayOnlyInTrace`. A wire-only event would be a change to
that contract, not a cheaper classification. Not a cost tradeoff; a validity constraint.

**For commands + interpreter (D4).** A 013 plan after the paper freezes — rejected (gates on
nothing). **A phase of 028 PLAN-002 — chosen.**

**For the exemptions in D2.** The ten `ExtPorts` forwarding fields are exempt because their
requests are extension-initiated, not because none can emit — `ai_step` can. Origin decides;
the per-field rows are recorded in the inventory.

---

## Decision

### D1 — The resolved context limit is a sum, and `Unknown` is loud

The types live in a **new leaf module** (`src/core/context_limit.ail`, name the PLAN's) that
imports nothing from `phase_vocab`, `ports` or `context_usage`, so both `context_usage` and
`phase_vocab` can import it without closing the `context_usage → ports → phase_vocab` cycle.
Sketch:

```ailang
export type LimitSource = ProfileOverride | Catalogue
export type ProfileMiss = ProfileConfigAbsent | ProfileConfigUndecodable | ProfileKeyAbsent | ProfileKeyNonPositive
export type CatalogueMiss = CatalogueAbsent | CatalogueUndecodable | ModelNotInCatalogue(string)

export type ContextLimit
  = Bounded({ raw_window: int, source: LimitSource })   -- raw_window > 0 by construction
  | Disabled                                             -- declared; see rule 3
  | Unknown({ profile: ProfileMiss, catalogue: CatalogueMiss })   -- the failed chain, both halves

export type InputBudget = Budget(int) | NoBudget(BudgetMiss)
export type BudgetMiss = LimitUnknown({ profile: ProfileMiss, catalogue: CatalogueMiss }) | LimitDisabled | InvalidWindow({ raw: int, allowance: int })
```

`Bounded` is constructed only by the two resolvers, only from a decoded `n > 0`; the
projections carry `requires { raw_window > 0 }` on that arm. `Unknown` is reached only when
both halves failed and carries both misses (cF8).

Rules the PLAN must keep:

1. **Three named pure projections serve every `int` surface; nothing else erases the reason.**
   - `raw_window_of(ContextLimit) -> int`: `Bounded → raw_window`, else `0`. Serves the three
     raw `mk_v2_ext_ctx` calls (`session.ail:2466`, `:2510`, `:2774`), the two `rpc.ail`
     hook-context literals (`:142`, `:337`), the **measurement denominators**
     (`should_checkpoint`'s two callees keep their `int` signatures and receive this value, so
     checkpoint policy is unchanged under `Bounded`), the status int (`:564–590`, whose private
     sentinel at `:566` goes), and the `EmptyStopFinalize` wire field (`phase_vocab.ail:580`,
     `:803`, golden `:1244`) — so that field's schema and golden do not move.
   - `working_budget_for_ext(ContextLimit, pinned_tokens) -> int`: reproduces today's
     `max(0, effective_input_limit(raw) − pinned)` for the pre-step call at `:2631`. Kept
     separate from the raw projection because unifying them changes pre-step behaviour (rule 4).
   - `effective_input_limit(ContextLimit) -> InputBudget`: the seal, `seal_compacted_payload`
     (`phase_vocab.ail:145`), takes the sum in place of its `raw_context_limit: int` and calls
     this where it calls the old function (`:150`). Internal to core; not an ABI change.
   - The exit render context keeps its explicit `context_limit: 0` at `:3399`, with the reason
     named at the site: no window is supplied to the exit context. It is not `Disabled`.
   - Shared extension-facing helpers keep their `int` signatures; `calibrated_usage_percent_anchored`
     is imported by `compaction_ai` and is not touched.
   - `CompactionPolicy.context_limit` (`phase_vocab.ail:174`) carries the sum; `session_policy_init`
     / `session_policy_with_model` (`:1935`, `:1971`) store it. No `packages/` code references
     `CompactionPolicy` or `StepPolicy`, so the sum does not leak into ABI 7.x.
   - Fixture constructors: `mk_policy` (17 call expressions) takes the sum; `mk_state`,
     `mk_state_with_messages`, `state_with_pressure` and `state_from_msgs` carry telemetry and
     are unchanged; the remaining four script constructors that build a policy take the sum.
2. **`Unknown` is visible on every poll and once per run.** The status object keeps its raw
   `context_limit` int and its three percentages for compatibility and gains
   `context_limit_source` (NOTE-005 item 1's name) carrying the arm and, for `Unknown`, both
   misses; the `MotokoRuntimeStatus` tool description (`tool_catalog.ail:70`) states that the
   percentages are unmeasured when the source is not `bounded`. Rendering "unmeasured" in the
   TUI counter is a TypeScript follow-up, named, not done here. The per-run record is **one
   logical event**, `ContextLimitResolved`, emitted and appended at the shared per-run entry
   (`:2994`), which the initial live turn, every follow-up turn and every traced entry pass
   through; `SessionStart` is untouched and remains a display-only banner. The event gets a
   vocabulary row, projection, golden and version bump under `make event_vocabulary`.
3. **`Disabled` is declared, never inferred.** An absent or non-positive profile key is a
   `ProfileMiss` and falls through to the catalogue as today (`context_usage.ail:137–141`,
   `:166`); `Disabled` requires an explicit profile key the PLAN names. No shipped profile is
   `Disabled` at adoption.
4. **No policy change under `Bounded`, under a named projection.** Every `decide` outcome, every
   compaction and seal decision, and every existing event payload must be identical before and
   after for artifacts whose limit resolves to a positive window, when the returned trace is
   compared with the new `ContextLimitResolved` record projected out. The new record is tested
   separately. The three profiles and the corpus are the gate; **D6 applies to D1**, because D1
   edits `c2_loop`'s expressions and adds a `LedgerEvent`.
5. **Fixtures must name their arm.** The type does not prevent `Bounded({ raw_window: 10 })`;
   it prevents it from being unlabelled, which is what let NOTE-165 §0's fixtures change class
   silently. It says nothing about whether a labelled window is usable.

Acceptance — the witness is the existing fixture `scripts/dst/runtime_status_tool_dst.ail`,
extended, plus an independent assertion on the returned trace:

- **Arm A**, `Unknown`: the run's `ContextLimitResolved` record names both misses; the status
  message returned by the builtin carries `context_limit_source` naming them; the loop proceeds.
- **Arm B**, `Bounded` neighbour: same history, a catalogue row present; decisions and existing
  payloads identical to HEAD under rule 4's projection. The liveness witness.
- **Arm C, the decoy**, `Disabled`: same ABI int and same non-enforcement as arm A, different
  reason; the record and the status field must differ from arm A's, or the arm is not measuring
  the reason. If `Disabled` is deferred (risk 1), the replacement control is two `Unknown` runs
  with different misses, same int, required to differ in both witnesses.

Contract candidates under 027's register: `effective_input_limit`, `raw_window_of`
(`requires { raw_window > 0 }` on `Bounded`; `ensures { result >= 0 }` and
`Bounded → result == raw_window`), `working_budget_for_ext` (`ensures { result >= 0 && result
<= raw_window_of(limit) }`). Three candidates; each recorded as substantive or the PLAN says why.

### D2 — A world ordinal, advanced once, witnessed onto the wire, checked per framed run

**Vocabulary.** A *leaf request* is a direct call of a `Ports` field by driver-side code. A
*helped* leaf is one D2 instruments; an *exempt* leaf is one it does not, with the reason
recorded. *Aggregate helpers* (`resolve_context_limit`, `session_policy_init`,
`session_policy_with_model`, `derive_session_id`, `execute_allowed_tool_call`,
`dispatch_tool_entries_with_builtin`, `dispatch_pre_step_chain`, `dispatch_step`) carry
successors and evidence and are not request sites. At adoption the exempt set is the ten
`ExtPorts` forwarding fields: extension-initiated requests, invisible to this count. Their
successor drops are a stated coverage limitation, not a gap; `hook_guard` does not check
successors (it decides dispatch before the call), and the `world_state_probe` consuming
fixtures cover two seal seams only.

Six parts.

1. **One pure writer.** `WorldState` gains `ordinal: int` and `pending: [RequestWitness]`, with
   `RequestWitness = { ordinal: int, class: RequestClass }`. A pure `advance(w, class)` in a
   leaf module (imports `ports` only) is the **only** writer of both: it returns the successor
   with `ordinal + 1` and the witness pushed. Every helped leaf calls it on the successor the
   port returned, including the eight reads inside `context_usage` (their `{Env}`/`{Env, FS}`
   rows are unchanged, because `advance` is pure), the three in `tool_phase`, `:2730`, `:3385`,
   and `dispatch_step`'s leaf in `stub_step.ail`. The three full `WorldState` literals gain
   the fields; `world_json`/`world_of_json` carry both, and a nonzero round-trip fixture
   followed by a helped request proves the codec does not reset them. If the fields are
   serialized into the program schema, 011 WI-1's three-commit route applies.
2. **One effectful witness, in `session.ail`.** `witness(session_id, trace, w) -> { trace, world }
   ! {IO, Trace}` drains `pending` in order: for each record it calls `ledger_emit(session_id,
   WorldRequest({ ordinal, class }))` — the wire — **and** `ledger_append(trace, WireRecord(…))`
   — the returned trace — then clears `pending`. It lives in `session.ail` because `ledger_emit`
   is private there and stays so (sole emission is preserved). It is called at every site where
   a successor *arrives in* `session.ail`: immediately after a helped leaf there, and on receipt
   from `tool_phase`, `context_usage`, the resolvers and `dispatch_step` — always **before** the
   successor enters any driver record. That ordering is the mechanism: the wire holds the
   witness before the literal that may drop the world is built.
   - *Bootstrap.* `session_policy_init`, `derive_session_id` and the initial clock read
     (`:3015–3016`, `:3044`) run before `C2LoopState` exists. Their successors carry pending
     witnesses; the entry chain calls `witness` with `empty_ledger_trace()` and seeds
     `c2_initial_state_with_counts` (`:709–730`) with the resulting trace instead of an empty
     one. No initialization request is silently exempt.
   - *Tool phase.* Its three leaves `advance`; the `RunTools` arm witnesses the returned world
     on receipt.
   - *Order-of-witness.* A helped leaf whose successor is dropped before its witness is the
     one shape the wire cannot see; part 6's derivation script pins that every helped leaf is
     witnessed before any record construction on its path.
3. **The gate: per-run frames on the stdout wire, checked at shell level.** Each traced
   invocation in a DST script is framed by two labelled lines the *script* prints —
   `WORLD_RUN_BEGIN <label> <ordinal0>` before the entry call and `WORLD_RUN_END <label>
   <final>` after, from `run.world.ordinal` (not from `DstResult`, which carries no world) —
   and the script refuses to print `END` if `run.world.pending` is non-empty. A shell gate on
   the `run_ledger_parity_wire.sh` pattern partitions the JSON wire lines by frame and asserts,
   per frame: exactly one `END` per `BEGIN` and the expected frame count; every
   `world_request` line inside a frame; ordinals exactly `ordinal0+1, ordinal0+2, …` (**strict
   +1**, since exempt requests do not advance); last == `final`. Red on a repeated or backward
   ordinal (a stale-world re-request), a gap (a leaf advanced but not witnessed on that path,
   or an unhelped leaf), a final mismatch (a drop after the last witness), a `world_request`
   outside any frame, or a missing, duplicated or truncated marker. Frames are **not**
   `RunSummary` or `done`: the exit publish is one of the requests under test. Equal ordinals
   in different frames are valid. Precedent for the labelled line: `LEDGER_TRACE` in
   `ledger_parity_dst.ail:330`.
4. **Classification and artifacts.** `WorldRequest` is **logical** and always appended, so it
   needs no gap-register entry: a vocabulary row with projection, golden, classification and
   version bump (one more variant; 36 once D1's and D2's both land), and a Row 7 witness in the eight-subject parity fixture, where it
   becomes a required row and the existing wire-vs-returned count comparison gives a second
   signal — narrowly, for a drop that loses the returned record on a subject the fixture
   reaches. Priced artifacts: the returned trace and the exporter; the vocabulary version in
   the manifest, which changes newly encoded program bytes; nothing else — the trajectory key
   hashes interactions, strict replay compares interactions, and discovery determinism compares
   variant names, which are identical across deterministic runs. No corpus re-roll.
5. **Terminal ordering and the two production drops, shown red before the fix.**
   (a) *Exit.* `publish_turn_exit_manifest` moves **before** `c2_finalize`'s clock read and
   `RunSummary`, takes the loop's world, advances at its env read, and returns `{ world, trace }`;
   `exit_manifest.publish_exit_manifest` returns the rendered world instead of a `bool`
   (`:182–205`) so the render's successor is not discarded; `c2_finalize` takes that world;
   `RunSummary` stays last and publication stays before `done`. Red first: instrument the read,
   leave the discards, run — the frame's `final` is behind the last witness.
   (b) *Provider error.* The `:2730` read advances and is witnessed, and its successor, not
   `exchange.next_state`, feeds the terminal call at `:2759`. Red first the same way.
   Out of reach and recorded: `:3265` (no deterministic run enters the stdin loop) and the
   live-loop publish calls at `:3294`/`:3479`, which are separately framed lifecycle operations
   (Not decided).
6. **The pin.** A derivation script on the `tools/ext_call_inventory` pattern produces the
   de-duplicated leaf inventory across `session.ail`, `tool_phase.ail`, `context_usage.ail` and
   `stub_step.ail`'s `dispatch_step`, plus the call graph of aggregate helpers, and fails when a
   leaf is neither advanced-and-witnessed-in-order nor on the exempt list with a reason.
   Fixtures: an un-advanced direct leaf; an un-advanced leaf behind a named indirection (the
   alias bypass); a helped leaf witnessed after a record construction; and a control. **This
   is D2's first deliverable**, because every cost below depends on it. If it cannot be built
   reliably (the `keep_interpolations` class of parser defect, learning §7), D2 lands parts 1–5
   with a hand-maintained inventory and this ADR is amended to say the **no-bypass gate is
   missing** and the coverage claim is restricted to the listed sites.

**What D2 does not touch.** The four WI-D4 sites and their comment. The adapters. Extension-side
drops. `LedgerEvent` beyond the one new variant. **D2 is D6-gated.**

**Under D4's interpreter**, the interpreter's request arm is the only helped leaf and the only
witness call; parts 1–5 are constraints the interpreter must preserve, stated here, not
demonstrated for a design that does not yet exist.

**Removed from earlier versions:** the census subtraction (no total census is derivable from an
undifferentiated log); "a gap is attributed, not red"; the claim that the gate uniquely
diagnoses a dropped successor — it localizes an inconsistent sequence in a framed run, and the
PLAN's fixtures distinguish a drop from a codec reset or a double emission.

### D3 — File three AILANG asks; evaluate the fourth

Each ask is a local record in the existing format (`.agent/issues/ailang-*.md`, `## Status` /
`## Not yet filed upstream`) and is filed upstream through the `ailang-feedback` skill — channel
2 if the CLI is configured, channel 1 otherwise — with the local record then carrying the issue
URL. Filing is outward-facing and is done by the owner or under explicit delegation.

| Ask | AILANG doc (local checkout, read 2026-09-05) | The Motoko fact that makes the case |
|---|---|---|
| Fund `m-effect-handlers` Phase 1 | `planned/v1_1_0/` — Planned; target v0.21.0 Phase 1 → v0.22.0/v1.0.0; ~30–40h Phase 1; tree at v0.33.0 | 20,858 lines of `src/core/dst_*.ail` implement a world boundary, virtual clock, synthetic FS and replay in userland. Handlers may replace selected boundary plumbing; which parts is measured after adoption, not claimed here |
| Per-hook capability narrowing | `planned/v1_0_0/m-effect-scope-params.md` — Planned; ~16h; Rand+AI grants only, FS/Net future | 20 of 40 coverage entries rest on a declared row (RESEARCH §2.C). Narrowing may convert the subset whose hooks are Rand/AI-scoped; the PLAN lists candidate hooks first |
| Pinned clock and fixture FS modes | `planned/v1_0_0/m-effect-clock-net-fs-modes.md` — Planned; ~20h | `WorldState.clock_ms` and `WorldState.files` are the feature in userland, under 167 non-comment `next_state` lines (198 textual, 31 comments) |

The fourth row from earlier versions, replay contracts, is **LANDED (PARTIAL)** in
`implemented/v0_30_0/m-effect-replay-contracts.md` — the Rand dispatch pilot and Rand+AI
contract labels; Clock/Net/FS rows are another sprint. No Motoko code references the registry
(`ReplayContract`, `mode=`, `replay/contracts`: zero matches). What Motoko owes is a bounded
012 **evaluation** entry: does the shipped Rand/AI registry express any part of DRAFT §5.2's
prose contract, and what would the Clock/FS rows need. Not an ask; not a claimed adoption.

The estimates in the table are upstream design estimates, not Motoko integration estimates.
Order: the first two records are written first; all three are filed the same day. RESEARCH
§3's constraint is kept: D3 completes before D4's phase starts.

### D4 — Commands + interpreter moves to 028 PLAN-002, with two pilot gates

RESEARCH §2.D leaves 013's sequence and becomes a named phase of 028 PLAN-002, placed after
items 2 and 3 **for sequencing, not dependency**: item 3 shrinks the loop file the pilot edits
and item 2 removes entry points it would otherwise keep parity with. Neither is a precondition;
the PLAN-002 item-3 marker was corrected to say so with this version.

Fixed here so 028 does not re-decide them:

- **The pilot is the tool phase.** Its dispatcher already lives in `tool_phase.ail`
  (`execute_allowed_tool_call` `:304`, `dispatch_tool_entries_with_builtin` `:459`; leaves at
  `:413`, `:414`, `:421`); the loop's `RunTools` arm is `:2495–2590` with the dispatch call at
  `:2546`. The pilot's command vocabulary is those three leaves plus that call.
- **Two pilot gates, as acceptance goals, not consequences of purity.** (i) *Fragment
  membership:* the pilot's `step` carries at least one substantive contract in 027's register,
  or the PLAN records the fragment reason it cannot. (ii) *Emission ownership:* D2's derivation
  script shows the only `ledger_emit` reachable from the tool phase is the interpreter's request
  arm; IO-capable hooks and callbacks (`ExtPorts.ai_step`, Compactor rows, the `ext_ai_step`
  callback at `:809–816`) are enumerated as the remaining emitters. Parity stays evidence until
  both gates exist.
- **The paper gate is dropped.** D3 and D6 precede the phase.

### D5 — Lifecycle at both ends, one class at a time

RESEARCH §2.E is re-scoped to registration at start and exit actions at end. The exit render
reads through the world since `4b37439` and its successor is discarded inside
`exit_manifest.ail:182–205` and at `:3409–3410`; D2 part 5(a) is the repair, and a comment
explaining the discard does not satisfy D2. Exit *execution* is TUI-side and stays a host
effect.

A fifth `FaultBoundary`, `LifecycleBoundary`, with `extension_registration_failure` and
`exit_action_unexecutable`, is decided but not made. Adding the variant is a compile-time
obligation on `boundary_id`. **Each class enters `required_class_ids()` when its own boundary
is driven and its outcome is reachable**, per 009 ADR-001 D3 (`:816–830`): a production
outcome, a recovery branch, a transition, and explicit applicability or waiver. Driving
registration alone does not admit `exit_action_unexecutable`; while exit execution stays in
the TUI that class is a recorded conditional waiver, not a pin. The catalogue stays at 11
until then.

D5 has no plan until D4's pilot has landed or the next ABI major is scheduled.

### D6 — The sweep precedes any boundary change, D1 included

Before D1, D2, D4's phase, D5, or anything under §2.A, `make dst DST_JOBS=1` is run at the
branch point and every red is fixed or added to `DST_KNOWN_RED` (`Makefile:493`, empty at HEAD)
with its reason. The list is disclosure, not a waiver: the exit code is untouched in both
directions, and a listed target that passes is reported with a drop instruction, not failed.
Nothing in the Makefile enforces this precondition; it is a workflow rule, and the PLAN retains
the baseline evidence. The state of the sweep at `62cb753` is unknown to this ADR; the reds it
finds are not priced here.

### D7 — What gets a plan (RESEARCH Q7)

| Item | Disposition |
|---|---|
| D1, D2, D3 | one `PLAN-001` in this directory; D3 first (free, non-blocking); D1 and D2 after D6; **D2's first deliverable is the inventory** (part 6), and its PLAN section is written from that inventory, not before |
| D4 | 028 PLAN-002, as a phase with the two gates in D4; 013 keeps the design record |
| D5 | no plan yet; its per-class trigger is decided |
| §2.A defunctionalization | a spike document first: vocabulary (Q1), corpus migration under 011 WI-1's route (Q2), consumer list without the shrinking claim |
| §2.C generic profile runner | no plan; revisit after D4's pilot |
| `WorldM` (§2.B2) | dropped |
| 012 evaluation entry for replay contracts | written with D3's records; not a 013 item |
| one-of-forty aggregator, `driver_only` register defect | optional PLAN-001 items, no dependency, not required for acceptance |

---

## Consequences

**Gates that move.** Per learning §4, derive the width from the gates. What can be said now:

- **D1 and D2 both edit `session.ail` above its five pins.** The anchor script's cascade is
  seven files including `session.ail`, and it says `session.ail` "is therefore contract-frozen
  unless the item prices this". Both price it. The procedure: re-baseline every moved pin
  yourself, then run `make anchors`, which **checks and does not edit**; then
  `make attribution_table` and the three profile targets derive the re-issues. Two commits
  that each move pinned lines each need coherent pins; sequence edits so one commit lands the
  final positions, or budget both updates. Branch count does not decide the work.
- **D1 edits the `phase_vocab` hub** (15 importers): `CompactionPolicy`, the seal signature, a
  new event. Land before 028 PLAN-002 item 3's split or rebase across it.
- **D1 and D2 each add one logical `LedgerEvent`** and bump the vocabulary version;
  `make event_vocabulary` and the goldens are the gate; the manifest version moves under 011
  WI-1's route.
- **D2 touches three full `WorldState` literals, the token codec, the bootstrap chain, the
  tool phase, `stub_step.ail`'s `dispatch_step`, both exit functions and `:2730`**; `make
  world_state`, `strict_replay`, `program_persistence`, `event_vocabulary`, `ledger_parity` and
  the corpus targets are the gate, plus the new framed-wire gate and the derivation script.
  No `Violation` constructor is added.
- **D2 makes two production sites red by design** and runs them red before the fix.

**Costs** (cF13's re-derivation, adopted). D1 five to eight days, provisional: separate raw and
net arithmetic, the leaf type module, the new event and status field, the checkpoint boundary
control, three contracts, the cascade. D2 six to nine days after the inventory and D6: the
inventory and call graph, `advance` at every helped leaf, `witness` at every receipt, bootstrap
threading and trace seeding, the framed shell gate with marker mutants, the vocabulary row, two
production repairs with terminal-trace preservation, the codec fixture. D3 half a day plus the
owner's filing and a bounded evaluation. D6 half a day plus unpriced reds. Cluster **12–18
working days**, a range, not a commitment.

**What gets better.** A fail-open measurement boundary becomes fail-loud with the failed chain
named. The paper's frozen-cursor anecdote becomes a framed wire gate that names the ordinal at
which a run's request sequence broke. Three upstream asks exist as issues and one shipped
feature gets an honest evaluation. `decide` gains a reason it can act on later.

**What gets worse.** One more sum through the hub. Three projections where one would be
cleaner, kept apart because unifying them changes behaviour. One new wire event per run plus
one per helped request; the volume is absorbed by the Makefile's `grep -v '^{'`. Every DST
script that traces a run gains two marker lines per invocation. The ABI comment on
`context_limit` is true-but-partial until the next major.

**Risks named.**
- `Disabled` needs a profile key; if it cannot be added without a schema change, it is
  deferred and arm C's replacement control (two `Unknown` misses) stands in.
- D2's inventory may not be derivable reliably; then the no-bypass gate is missing and the
  ADR says so (part 6).
- The exit reordering changes when the manifest is rendered relative to the final clock read;
  `verify_exit_intent` and the 7.0 design's publication-before-`done` rule are the gate.
- D3's asks may be declined or parked upstream; that changes nothing here.

---

## Not decided

- **Behaviour under `Unknown`** beyond loudness, and whether the measurement boundary should
  ever be blocking in 028 ADR-001's sense. Needs an owner's number.
- **TUI rendering of unmeasured percentages.** A TypeScript follow-up.
- **World-threading the multi-turn loop** (`:3265`) and framing the live-loop publish calls
  (`:3294`, `:3479`). Named, not scheduled.
- **§2.A's vocabulary and corpus migration.** The spike.
- **Whether sponsoring handlers upstream is faster than §2.A + §2.D in userland.** Not
  answerable until D3 has a reply.
- **The generic profile runner's design.** Deferred with the runner.

---

## Implementation handoff

PLAN-001 in this directory carries D1–D3. Its first section is the D6 sweep and its disclosure
list. Its second is D2's inventory and call graph, with the derivation script's four fixtures.
Then, per cluster: the gate list derived at the branch point; D1's three arms on the existing
status fixture with the per-run record asserted independently; D2's framed-wire gate with the
whole-record-drop, missing-marker, dropped-last-request and two-honest-runs cases, and the two
production sites shown red before their repair; D3's three records and the evaluation entry
with upstream status.

The 028 phase for D4 is written by whoever next touches PLAN-002, from RESEARCH §2.D and this
ADR's D4, with its two gates.

---

## Cross-references

- The two reviews: `REVIEW-adr001-verdicts.md` (kF1–kF11) and `REVIEW-adr001-v2-verdicts-codex.md`
  (cF1–cF13, §3 prose corrections, §6 the list this version answers).
- Measurements: `NOTE-002-re-read-2026-09-05.md` §1–§4.
- The retraction form: `../027_z3_contracts/ADR-001-…` §Retractions; `../016_github_ops/ADR-001-…`
  §Corrections.
- The three-arm shape: `NOTE-issue-165-dst-architecture-findings.md` §8. The decoy rule: the
  2026-09-05 learning §5.
- The wire's implementation: `session.ail:222–228`, `:280–288`, `:335–342`; the parity wrapper
  `scripts/dst/run_ledger_parity_wire.sh`; the labelled-line precedent `ledger_parity_dst.ail:330`.
