# ADR-003 v4 adversarial review verdicts

Date: 2026-09-06
Reviewed HEAD: `97827bf17400595461c23d08c4d5093b259bd40b` (`git rev-parse HEAD`; unchanged through v1–v4)
Subject: `ADR-003-session-snapshot-and-resume.md` v4
Prior reviews: v1, v2, v3 (`REVIEW-adr003-*-verdicts-fable.md`); v3 left five required changes.

Only the sections v4 changed were re-read against the code; every coordinate carried from v1–v3 stands on those audits, and the new ones are in §6.

## Overall verdict

**Accept with corrections. PLAN-003 can be written now.** All five v3 changes are folded, and the mechanisms they add close the two design gaps v3 named: the loop learns every write's generation through `written`, and the resumed frame opens at a value the child actually holds. What remains is enumeration, not decision: the identity inputs the *traced run* and the *conversation loop* need in order to perform the writes v4 assigns to them, and two edge rules around the `+2` relation and a failed write. None of these changes a decision; all of them belong in the ADR so the plan does not invent them.

The residuals, in order of weight:

1. **The traced run needs `generation` and `profile` as inputs.** `SnapshotWritten.generation` is produced *inside* the run (the success arm at `src/core/session.ail:2486` and `c2_suspend`), so the run must know the previous generation to write `generation + 1`; and every snapshot carries `compat.profile` and `compat.ext_set_digest` (`ADR-003:285–286`), which `c2_loop` does not have (`session.ail:2407–2421`; it has `rt: ExtRuntime` at `:2408`, from which the digest can be computed, but no profile name). D5 says the run "receives `run_id` as an argument and derives nothing" (`ADR-003:526–527`); it must also receive `generation` and `profile`, or one identity record carrying all three.
2. **The conversation loop's fresh `TurnSnapshot` cannot fill `boot.task`, `compat.profile` or `compat.ext_set_digest`.** The no-snapshot restart rule (`ADR-003:459`) says the loop writes "from the loop's `history` and its pre-turn `provider.world`, which is all it has". The loop's parameters (`session.ail:3330–3345`) include `env_url`, `hybrid_tools`, `budget`, `step_budget`, `ohmy_pi`, `max_cost_millicents`, `cost_rates`, `model`, `workdir`, but not the task, the profile or the extension digest. Give the loop the same identity record (item 1) plus `task`, or state that the fallback snapshot takes `task` from the history's first user message (`rpc.ail:345`) and the profile from a new parameter.
3. **A failed write must still advance the in-memory generation.** The loop rule (`ADR-003:524–526`) sets `generation := w.generation` on any `Some(w)` regardless of `published`, which is right: if a failed write left the in-memory generation unchanged and reset `run_ordinal` to 0, the next run would reuse a `run_id` already issued. Say so, and say that the on-disk generation may therefore skip numbers.
4. **The `+2` relation does not hold for the fallback `TurnSnapshot`.** Its `world` is the pre-turn `provider.world` (`session.ail:3380–3386`), which is below the failed run's `final` by that run's request count. Step 2's gate is scoped to "a run that snapshots then finalises" (`ADR-003:719–722`), so it is not wrong; the D3 paragraph (`:447–453`) should say the relation is for in-run writes only.

| Decision | Verdict | Short reason |
|---|---|---|
| D1 | **ACCEPT** | Unchanged from v3. |
| D2 | **ACCEPT WITH CORRECTIONS** | `written` is the right field and the loop rule is sufficient (§3); the run's inputs (item 1) and the failed-write rule (item 3) are missing. |
| D3 | **ACCEPT WITH CORRECTIONS** | Frame-opening rule is consistent with ADR-001 (§4); the fallback `TurnSnapshot` lacks three envelope fields (item 2) and sits outside the `+2` relation (item 4). |
| D4 | **ACCEPT** | Unchanged; one optional refusal noted (§4). |
| D5 | **ACCEPT WITH CORRECTIONS** | Lease hooks and allowlist key are right; the fresh-session seed is unstated and two signal listeners that both re-raise need one sentence (§2 D5). |
| D6 | **ACCEPT** | One stale word in the test list. |
| D7 | **ACCEPT** | Unchanged from v3. |
| D8 | **ACCEPT** | Step 1's total world codec and step 2's single `+2` assertion are consistent. |

## 1. Disposition of the five required changes

| # | v3 change | Disposition | Residual |
|---|---|---|---|
| 1 | `written: Option[SnapshotWritten]` set by every write; the loop's `generation`/`run_ordinal` rule in both arms of both outer loops | **Folded** (`ADR-003:362–368`, `:520–528`) | The run's own inputs (item 1); the failed-write rule (item 3); the fresh-session seed (`generation := 0`, `run_ordinal := 0`) is implied but not written (§3). |
| 2 | Resumed frame opens at `snapshot.world.ordinal`; `SessionResumed.from_ordinal`; `+2` only in step 2's gate | **Folded** (`:447–453`, `:573–577`, `:719–722`) | The fallback `TurnSnapshot` exclusion (item 4); the D6 test line still says "frame opening at `final`" (`:637–638`). |
| 3 | Unconditional lease hooks; `MOTOKO_LEASE_HELD` in the allowlist | **Folded** (`:543–549`) | Two independent `process.on(signal)` listeners that each re-raise (`herdr-agent-state.ts:296–301` pattern) need a stated order or a single shared handler (§2 D5). |
| 4 | Restart with no snapshot yet | **Partly folded** (`:459`) | The loop cannot fill `task`, `profile`, `ext_set_digest` (item 2). |
| 5 | Step 1's round trip uses the total `world_of_json` | **Folded** (`:702–705`) | None. |

The ADR's references into the v3 review (`ADR-003:786–788`: "overall items 1–2 the `written` field and the frame-opening argument, §2 D5 the lease hook, §6 the coordinate audit") name the right sections.

## 2. Per-decision verdicts

### D1 — accept

No v4 change. The envelope (`ADR-003:276–304`) already carries `compat.profile` and `compat.ext_set_digest`; the only new consequence is that whoever writes a snapshot must be handed them (items 1 and 2), which is D2's and D3's correction, not D1's.

### D2 — accept with corrections

Verified: the success arm (`session.ail:2486`) and the `Fail` arm (`:2437`) are both inside `c2_loop` (`:2407–2422`), so a `written` value built there is returned through `c2_finalize`'s literal (`:1554`, `None` by default) or set after it; the outer loops' arms (`:3418–3427`, `:3603–3612`) are where the rule runs; no DST fixture matches `TracedSessionResult` by full literal (v1 audit, §3), so the additive field compiles everywhere.

Corrections:

1. State the run's identity inputs: `run_id`, `generation`, `profile` (item 1). `c2_loop`'s signature (`:2407–2421`) gains them, or a record does; `ext_set_digest` is computable from `rt` (`:2408`) at write time.
2. State that `written.generation` is authoritative even when `published` is false (item 3).
3. State the fresh-session seed: the initial traced run at `:3600` runs as `g0.r0`; its `TurnEnd` write is generation 1, which matches the fallback rule's "generation 1" (`ADR-003:459`).

### D3 — accept with corrections

Verified: the `restart` arm is between turns (`session.ail:3367`, `:3391–3399`) and now has `generation` as a loop parameter (`ADR-003:521–522`), so "holds the last generation from the previous run's `written`" (`:459`) is true; the host's `Abort` write after child exit is unchanged from v3 and coherent; the conversation loop's parameters (`:3330–3345`) lack `task`, `profile`, `ext_set_digest`.

Corrections: items 2 and 4. For item 2 the smallest fix is to pass the loop the same identity record as the run (`session_id`, `generation`, `run_ordinal`, `profile`) plus `task`; `run_v2_with_conversation` (`:3561`) has `task` and `rpc.run_with_config` has `cfg.profile` (`rpc.ail:257`), so both are one parameter away.

### D4 — accept

No v4 change. One optional addition: a decoded snapshot's `world.pending` must be empty, since the snapshot is taken after the publish's witness and before its own write's `advance` (`ADR-003:443–444`; `ADR-001:386–389`, `:396–404`); a strict `WorldField("pending")` refusal for a non-empty queue costs one line and makes `from_ordinal` unambiguous.

### D5 — accept with corrections

Verified: `initHerdrReporter` returns at `herdr-agent-state.ts:280` outside a herdr pane and registers its `exit`/signal hooks at `:295–301` only after that; `initExitActions` registers unconditionally (`exit-actions.ts:425–428`); `buildChildEnv` is the allowlist (`runtime-process.ts:337–389`); the TUI outlives its children (`:362–371`); `rpc.main` (`rpc.ail:355–359`).

Corrections:

1. **Signal listeners.** The reporter's handler calls `releaseHerdrReporter()` and then `process.kill(process.pid, signal)` (`herdr-agent-state.ts:297–301`). A second, independent listener for the same signal that also re-raises means the order in which the two run, and which re-raise ends the process, depends on registration order. Say that the lease release is registered before the reporter (as `initExitActions` is, `exit-actions.ts:422–423`) and does **not** re-raise itself, leaving the re-raise to the last handler; or fold both into one handler.
2. **Fresh-session seed** (D2 correction 3).
3. **Hostless abnormal exit.** A hostless runtime "removes [the lease] on return" (`ADR-003:554`); a crash leaves a dead-pid lease, which `--resume-force` clears (`:556–557`). Fine as written; note that the AILANG side has no exit hook equivalent, so "on return" is the only release.

### D6 — accept

Verified in v3. One stale word: the test list says "the same through `--resume` in a fresh driver with the frame opening at `final`" (`ADR-003:637–638`); under v4 it opens at `from_ordinal`, and the gate asserts `final == from_ordinal + 2`.

### D7 — accept

No v4 change.

### D8 — accept

Step 1's round trip through the total `world_of_json` (`ext_world.ail:543–553`) is honest about what it can and cannot detect (`ADR-003:702–705`). Step 2's gate is now the only holder of the `+2` (`:719–722`). Step 1 lists "the loop's `generation`/`run_ordinal` parameters and their rule" (`:705`); it should also list the run's identity inputs (item 1), which are the same change.

## 3. Is `written` plus the loop rule sufficient?

**Yes for D3's `Restart` update and D5's `run_id`, given the inputs in items 1–3.** Walking every path:

| path | run returns | loop rule | next `run_id` |
|---|---|---|---|
| fresh session, first run (`session.ail:3600`) | — | seed `generation 0`, `run_ordinal 0` | `g0.r0` |
| success | `Ok`, `written: Some({ g+1, TurnEnd, published })` | `generation := g+1`, `run_ordinal := 0` | `g(g+1).r0` |
| budget suspension | `Err`, `suspended: Some`, `written: Some({ g+1, BudgetExhausted, … })` | same | same; the in-process resume runs as `g(g+1).r0` |
| non-budget failure | `Err`, `written: None` | `run_ordinal + 1` | `g(g).r(n+1)` |
| write failed | `written: Some({ g+1, …, published: false })` | `generation := g+1` (item 3) | `g(g+1).r0`, unique even though disk still holds `g` |
| `restart` with a snapshot on disk | — | child writes `generation + 1` from the loop's `generation` | the respawn seeds from disk |
| `restart` with none | — | child writes generation 1 (needs `task`, `profile`, digest: item 2) | same |
| `--resume` | — | seed `generation := snapshot.generation`, `run_ordinal := 0` | `g(s).r0` |

Both outer loops are covered because the rule is applied in the `Ok` and `Err` arms of both (`ADR-003:523–526`; `session.ail:3418–3427`, `:3603–3612`), and the `model_change` and discard arms (`:3374–3390`, `:3430`) recurse with the parameters unchanged, which the "beside `suspended`" placement implies. The `run_id` inside a snapshot names the run that *wrote* it (`g(g).r(n)` writing generation `g+1`), which is consistent and worth one clause.

## 4. Is `from_ordinal` consistent with ADR-001's frame gate?

**Yes.** ADR-001 D2 part 3 frames a traced invocation with `WORLD_RUN_BEGIN <label> <ordinal0>` and `WORLD_RUN_END <label> <final>`, both printed by the script from `run.world.ordinal`, and checks *within* a frame that ordinals run `ordinal0+1, ordinal0+2, …` and `last == final`; "Equal ordinals in different frames are valid" (`ADR-001:415–427`). A resumed run is a new frame whose `ordinal0` is the decoded snapshot's `world.ordinal`, two below the previous frame's `final` (write, then `c2_finalize`'s clock read, `session.ail:1550`, `:1554`; `derive.py:96–97`). Nothing in the per-frame gate objects to a lower opening ordinal, and the script already prints both numbers, so the cross-frame assertion in step 2's gate (`ADR-003:719–722`) needs no new vocabulary: `END_1.final == BEGIN_2.ordinal0 + 2`. `SessionResumed.from_ordinal` (`:573–577`) duplicates `BEGIN_2.ordinal0` for live runs that print no frame, which is the right reason to carry it.

Two edges to state: the `+2` is for in-run writes (`TurnEnd`, `BudgetExhausted`, `Park`), and metadata updates copy the previous in-run snapshot's world so they inherit it; the fallback `TurnSnapshot` from the pre-turn world does not (item 4). And a decoded `world.pending` must be empty for `ordinal0` to be well-defined (§2 D4).

## 5. Can PLAN-003 be written?

**Yes.** Every decision a plan would otherwise have to make is made: the additive `suspended` and `written` fields, the loop rule, the frame-opening rule and its single gate, the one-writer rule with the child-`Restart`/host-`Abort` split, the lease as the writer guarantee, the narrowed generation check, the profile switch with `ext_artifacts` reset, the headless-only `error` in step 1, and the total world codec until step 2.

The plan must carry the four residuals as step-1 items (they are signatures and two rules, not decisions), and the ADR should record them so the plan cites rather than invents:

1. The traced run's identity inputs: `run_id`, `generation`, `profile` (`session.ail:2407–2421`).
2. The conversation loop's `task` and the same identity record (`:3330–3345`; `rpc.ail:257`, `:345`; `session.ail:3561`).
3. `written.generation` advances the loop's generation regardless of `published`.
4. The `+2` relation is for in-run writes; the fallback `TurnSnapshot` is outside it; a decoded `pending` must be empty.

Plus the two textual fixes: "frame opening at `final`" → `from_ordinal` (`ADR-003:637–638`); the signal-listener order (§2 D5). ADR-002 remains v2.1 with D6 in its TL;DR; the v3 edit (`ADR-003:733–734`) is still to be made and can be PLAN-003's first documentation item.

## 6. Coordinate audit (new in v4)

| cited | verified | note |
|---|---|---|
| `session.ail:3359–3366` | yes | the "NOT routed" comment: deterministic runs never reach the conversation loop |
| `:3418–3427`, `:3603–3612`, `:3597–3612` | yes | the two outer loops' `Ok`/`Err` arms; the empty-task guard at `:3597–3598` |
| `:3419`, `:3380–3386`, `:3394–3397`, `:2486`, `:1554` | v3 | |
| `ext_world.ail:543–553` | v2 | the total decoder step 1 reuses |
| `herdr-agent-state.ts:278–280`, `:292–302`, `:295–301`, `:297–301` | yes | early return at `:280`; hooks after it; the re-raise at `:300` |
| `exit-actions.ts:425–428`, `:422–423` | yes | unconditional `exit` hook; "registered BEFORE the herdr reporter" |
| `runtime-process.ts:337–389`, `:362–371` | v2 | `buildChildEnv` allowlist |
| `rpc.ail:355–359` | v3 | |
| `ADR-001:415–419`, `:422–427`, `:426–427` | yes | frames printed by the script; equal ordinals across frames valid |
| `REVIEW-adr003-v3` "overall items 1–2", "§2 D5", "§6" | yes | |
| "which is all it has" (`ADR-003:459`) | **partly** | the loop also lacks `task`, `profile`, `ext_set_digest` (`session.ail:3330–3345`) |
| "receives `run_id` as an argument and derives nothing" (`:526–527`) | **incomplete** | the run must also receive `generation` and `profile` to write a snapshot |
| "frame opening at `final`" (`:637–638`) | **stale** | v4's rule is `from_ordinal` |

## Required changes (carry into PLAN-003 or a v5 line edit)

1. D2/D5: the traced run receives `run_id`, `generation` and `profile`; `ext_set_digest` is computed from `rt` at write time.
2. D3: the conversation loop receives `task` and the identity record, so the fallback `TurnSnapshot` can fill `boot.task`, `compat.profile`, `compat.ext_set_digest`; delete "which is all it has".
3. D5: `generation := w.generation` on every `Some(w)`, `published` or not; disk may skip numbers.
4. D3: the `+2` relation is for in-run writes; the fallback `TurnSnapshot` is outside it; add a non-empty-`pending` refusal to D4.
5. D5: order the lease's signal listener before the reporter's and do not re-raise from it, or use one handler.
6. D6 tests: "opening at `final`" → "opening at `from_ordinal`".
