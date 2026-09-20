# ADR-001 review verdicts + independent re-measurement

Date: 2026-09-05. Status: **review complete — ADR-001 is rejected as written; a v2 is owed.**
Reviewer: one independent adversarial delegate with no stake in the ADR. Every load-bearing
claim was re-read at `file:line` or re-run on HEAD `9a1a253` (the ADR is grounded at `2192092`;
`git diff --stat 2192092 HEAD` touches `dst_profile.ail`, `dst_profile_coverage.ail`,
`ext/exit_manifest.ail`, `ext/registry_normalize.ail` and `contracts.register` — none of the
files D1, D2 or C1 rest on). **No file outside this review was modified**; `make dst` was not
run, per the ADR's own D6. Three fact-check sweeps (AILANG docs; Makefile/anchors/catalogue;
numeric census) were delegated and their commands are quoted where used.

Reviewed: `ADR-001-sequencing-the-dst-architecture-caps.md` against RESEARCH (2026-08-13),
NOTE-165 (2026-08-18), NOTE-002 (2026-09-05), the 2026-09-05 learning, 028 ADR-001 / NOTE-002 /
NOTE-003 / NOTE-005 / PLAN-002, 027 ADR-001, 016 ADR-001 §Corrections, 009 ADR-001 D1/D3, and
the code at the paths the ADR names.

## 1. Verdicts

| # | Verdict | One line |
|---|---|---|
| C1 | **REJECT** | Half of it is a disambiguation of RESEARCH presented as a correction; the other half (the four sites, "unrecorded keyed lookups", "the trace survives the drop") is contradicted by the code it cites |
| C2 | ACCEPT | Dates and priority reproduce (NOTE-165 §16 row "3 … Core policy"; NOTE-005 2026-09-01 = 14 days) |
| C3 | ACCEPT | NOTE-002 §4.5/§4.6 and the migration doc's row V7 ("5 of 6 profiles absent") reproduce |
| D1 | ACCEPT WITH CORRECTIONS | The sum is right; "exactly two places" is wrong — the tree already projects the int with two different meanings at the ABI, plus a wire field, a seal parameter and a status field; "fail-closed" is redefined; a step-0 event exists |
| D2 | **REJECT** as designed | Part 3 compares two fields of the same hand-threaded record, so the common drop pattern leaves it green; the "four sites go red" consequence is false because those sites perform no request; the one documented drop and the one post-finalization drop are outside its reach; per-adapter increments double-count under recording |
| D3 | ACCEPT WITH CORRECTIONS | Three asks, not four: the replay-contracts phase is `implemented/v0_30_0/`; the "V/R34" citation points at the wrong document |
| D4 | ACCEPT WITH CORRECTIONS | The relocation is sound; "mechanical preconditions" and "after item 3 it is a file" are not earned — `tool_phase.ail` already exists with the dispatcher in it |
| D5 | ACCEPT WITH CORRECTIONS | Accurate as far as it goes; the render is world-mediated inbound only — its successor is discarded, which also bears on D2 |
| D6 | ACCEPT WITH CORRECTIONS | Right gate, overstated mechanism: a listed target that passes prints a NOTE; it does not fail the summary |
| D7 | ACCEPT | Dispositions stand; D3's row becomes three items and D2 needs a v2 design before a PLAN |

## 2. Findings, most load-bearing first

### F1. D2 part 3 cannot go red on the drop pattern this driver actually has

**ADR says** (D2 part 3): "This goes red because the trace is not the world: a dropped
successor leaves `high_water` ahead of `ordinal` at the next append." And (Grounding): "The
driver's trace is a field of driver state (`src/core/session.ail:177, :412`), threaded
separately from `world_state`. This is what D2 rests on." And (TL;DR): "the successor's ordinal
is recorded by the driver's trace, which a dropped successor cannot discard".

**Evidence.**

- `session.ail:177` is `TracedSessionResult`, the *result* record (`grep -n 'export type
  TracedSessionResult' src/core/session.ail` → 176). Driver state is `C2LoopState` at :383;
  its `world_state` is :400 and its `trace` is :412. Both are fields of one record.
- That record is rebuilt by literal at ≥4 sites and every literal chooses both fields by hand
  (`sed -n 2380,2400p`): `world_state: st.world_state, … trace: trace_with_decision, …` — the
  same shape at :2136–2148, :2183–2195, :2407–2420. A `world_high_water` field would be one
  more line in each literal, copied from `st` by the same hand.
- The driver's own comment on the emissions channel (`:421–425`) states what a same-record
  invariant can and cannot see: "It is threaded ALONGSIDE `trace` … a branch that carries one
  channel forward and drops the other goes red". It goes red on a *one-channel* drop. The
  approval site's comment (`:2457–2465`) describes the drop the tree is prone to — "Passing
  `st` here instead of `post`" — which drops *every* channel of `post` at once: world, trace,
  emissions and any high-water mark. Under that drop `st.world_state.ordinal ==
  st.world_high_water` still holds, because both are stale together.
- The more disciplined the helper, the less the invariant sees: if the helper returns a
  `C2LoopState` with both fields advanced (the only way "the helper is the only writer" can be
  true), a drop is always "use `st` instead of `post`", and the two fields never separate.
- `ledger_append` is `pure func (LedgerTrace, LedgerRecord) -> LedgerTrace`
  (`phase_vocab.ail:604`) and has no access to `st`. An invariant in `dst_invariants.ail` is
  evaluated post-hoc over `ExecutionUnderTest = { result, world, … }` (`dst_invariants.ail:553`)
  — it sees the *final* world and trace, not "every append". Checking "at every `WireRecord`
  append" therefore needs the pair on the record, i.e. a `LedgerRecord` schema change the ADR
  neither names nor prices (it says D2 changes no `LedgerEvent`; `LedgerRecord` is the
  three-arm sum at `phase_vocab.ail:594–597` that wraps it).
- The only observer a drop cannot un-happen is the wire: `ledger_emit` is
  `-> () ! {IO, Trace}` (`:335`) and the parity families exist precisely because wire and
  returned trace can disagree (`dst_invariants.ail:63–66`).

**Concrete failure of (b), two ways the ADR's brief asked for.** (i) *A drop with no
subsequent append:* `c2_loop`'s `Finalize` arm calls `c2_finalize` (:2368), which performs
`ports.clock_now(world)` and threads it into `finalized.world` (:1529–1533), then calls
`publish_turn_exit_manifest(…, finalized.world)` (:2372) as `let _ = …`. That function performs
`ports.env_get(world, manifest_path_var(), "")` (:3385), threads `named.next_state` into the
render's ctx (:3400, :3403), and returns `()` (:3409–3410). The returned world is
`finalized.world`; the env read's successor and the render's successor are discarded after
"finalization". A high-water mark bumped there is compared against nothing. (ii) *A site that
drops the whole driver record:* `:3265`, `session_policy_with_model` at `model_change`, whose
comment reads "The SUCCESSOR IS DROPPED HERE … this loop threads no world at all, a
deterministic run drives the traced entry point directly and never reaches it". No
`C2LoopState` exists there, no trace, no finalization; D2 has no home for `world_high_water`
and no run that could evaluate the invariant. This is the one drop the tree *documents*, and
the ADR does not name it.

**Corrected text.** "Parts 1 and 2 add a field and a discipline. Part 3 as a same-record
comparison detects only a drop that threads the high-water mark while discarding the world; the
tree's documented drop shape (`:2457–2465`, `:3265`) discards both. A gate that survives a drop
must read an observer the drop cannot un-happen: emit the successor's ordinal on the wire at
each request (a field on an existing event, or a new variant — which D6 gates) and assert
strict monotonicity over the wire ledger, with the final `world.ordinal` equal to the last
emitted value. Alternatively, state that part 3 is a single-channel consistency check and count
it as a test, not a gate."

### F2. The four `st.world_state` sites perform no request today, so nothing goes red "the moment part 1 lands"

**ADR says** (D2, "Consequence stated up front"): "the four `st.world_state` reuses at
`session.ail:2332` become four `WorldSuccessorDropped` violations the moment part 1 lands,
because a keyed read's successor is no longer identical to its input. They are fixed by
threading `r_limit.next_state`, which is what the 657-execution comment argued was
unnecessary." And (C1): "The four reuse sites at `session.ail:2332` were safe precisely because
the reads there are unrecorded keyed lookups whose successor is *identical* to the input". And
(Consequences): "D2 makes four existing production sites red by design. That is the acceptance
test for part 3".

**Evidence.** Each of the four sites says it performs no read:

- Finalize, `:2327–2346`: "WI-D4. READ, not re-resolved. `session_policy_init` already
  resolved this model's limit and stored it here; WI-D3 re-resolved it at this and three
  sibling sites … SUCCESSOR: none is lost … `st.world_state` is both the predecessor and — with
  no read performed — the successor."
- Approval, `:2456–2465`: "WI-D4 removed WI-D3's `post_ctx` here … The successor that
  disappears with the resolution is the resolution's own; the one that must survive is
  `input.next_state`, and it does, in `post`." The approval read *is* threaded (:2456
  `let post: C2LoopState = { st | world_state: input.next_state }`).
- RunTools, `:2501–2509`: "WI-D4. The stored limit, and WI-D3's `st_ctx` goes with the
  resolution that produced it … `done.world` — the successor that IS load-bearing here — is
  untouched."
- CallModel, `:2594–2602`: "the deleted resolution was the first thing this arm did to the
  world, so its successor was `st`'s own."

`grep -n 'r_limit' src/core/session.ail` → only :1935 and :1971 (inside `session_policy_init`
and `session_policy_with_model`, both of which return `next_state: r_limit.next_state`), plus
the two historical comments at :2344 and :2506. There is no `r_limit` at any of the four sites
to thread.

The reads that *would* be there if WI-D3's re-resolution were restored are not "unrecorded
keyed lookups": `resolve_context_limit` makes five env requests and three file requests
(`context_usage.ail:158–160`), and `recording_env` records every env read
(`ports.ail:1569–1585`, `next_state: record_interaction(…)`); only the file reads are
unrecorded (`stub_step.ail:495–500`). Restoring them is the thing WI-D4 removed for a measured
reason: "Three reads per `resolve_context_limit` call at eight driver call sites is a log that
grows on every profile at once, and WI-D4 measured what a changed driver read count does to a
fixed seed bank" (`stub_step.ail:543–547`).

The 657-execution comment did not argue that threading was unnecessary; it argued that
*re-resolving* was unnecessary because the stored value equals a fresh resolution ("SAFE BECAUSE
IT WAS MEASURED … comparing the stored value against a fresh resolution", `:2333–2336`).
RESEARCH §2.B and NOTE-002 §1 both describe it correctly ("reuse `st.world_state` rather than a
fresh resolution"; "justified four `st.world_state` reuses"). The ADR's "correction" introduced
the error.

**Corrected text.** "The four WI-D4 sites read a stored policy value and make no request; part 1
changes nothing there and they cannot serve as the red-before-fix demonstration. The
demonstration must be a planted drop in a fixture (a `consuming_pre_step`-style binding, as
`world_state_probe` already does for the seal terminals, `:2622–2625`) or the documented drop
at `:3265` once that loop threads a world."

### F3. D1's "exactly two places" is wrong about the tree, and the ABI projection already has two meanings

**ADR says** (D1 rule 1): "The reason is erased at exactly two places, and each is one named
function. `context_limit_for_ext(ContextLimit) -> int` populates `ExtCtx.context_limit` …
`effective_input_limit` takes the sum … Every other consumer matches on the sum". And (contract
candidates): "`context_limit_for_ext` (`ensures { result >= 0 }` plus `Bounded → result ==
raw_window`)".

**Evidence** (`grep -n 'context_limit' src/core/*.ail | grep -v dst_ | grep -vE ':\s*--'`):

- `ExtCtx.context_limit` is populated at six `mk_v2_ext_ctx` sites with **two meanings**:
  `:2630–2631` passes `ext_context_limit = max(0, effective_input_limit(limit) −
  pinned_tokens)` (the working input budget net of the pinned prefix); `:2466`, `:2510`,
  `:2774` pass the raw `policy.step.compaction.context_limit`; `:3399` passes `0`
  (`publish_turn_exit_manifest`); `rpc.ail:142` and `:337` pass the ambient raw value into the
  budget-plan and system-prompt hook contexts (they are `ExtCtx` sites, not "status sites").
  A single `context_limit_for_ext` with `Bounded → result == raw_window` is false at `:2630`,
  or changes what `compaction_ai.ail:425/467/501/533` sees on the pre-step path — which rule 4
  ("No behaviour changes under `Bounded`") forbids.
- `EmptyStopFinalize.context_limit: int` is a wire field (`phase_vocab.ail:580`, projected at
  `:803`, golden-tested at `:1244`, required by the vocabulary at
  `dst_event_vocabulary.ail:370`). A third erasure, on the ledger.
- `seal_compacted_payload(…, raw_context_limit: int, …)` (`phase_vocab.ail:145`) takes the int
  and calls `effective_input_limit` inside (`:150`). Either its signature takes the sum (a
  `phase_vocab` hub edit, fan-in 15 — `grep -rl 'import src/core/phase_vocab' src packages
  --include=*.ail | wc -l` → 15, of which 2 in `src/core/test/`; NOTE-003's 13 excludes them)
  or the int is projected before the call — a fourth site.
- `runtime_status_json` (`session.ail:564–590`) reads the int at `:564`, keeps its own
  sentinel branch at `:566` (`if limit == 0 then 0`), and emits it at `:590`. A status int is
  a fifth projection even after `context_limit_source` is added beside it.
- `history_usage_percent_calibrated` and `checkpoint_would_relieve` under `should_checkpoint`
  (`step_machine.ail:87–90`) take the int.
- Fixture constructors that take a bare `context_limit: int`: `mk_policy` (18 callers),
  `mk_state` (16), `mk_state_with_messages` (4) in `step_machine.ail:145–179`, plus six in
  `scripts/` (`phase_f_pipeline_wiring.ail:29,49`; `dst/phase_c_l1_scenarios.ail:77,93,313`;
  `dst/phase_c_seeded_dst.ail:122`).

**Corrected text.** "The reason is erased at two *kinds* of place, each a named pure function:
the ABI projection and the budget arithmetic. The ABI projection is two functions today, not
one — a raw-window projection at the tool/approval/post-step sites and a working-budget
projection at the pre-step site (`:2630`) — and the PLAN either names both or records the
behaviour change of unifying them. Three further int surfaces remain and are projected through
the same functions: the `EmptyStopFinalize` wire field, the `seal_compacted_payload` parameter,
and `MotokoRuntimeStatus.context_window.context_limit`. The fixture constructors in
`step_machine.ail` (38 call sites) and six in `scripts/` change signature."

### F4. D3 files an upstream ask for a feature that has shipped, and cites the wrong document for R34

**ADR says** (D3 table, row 4): "Replay contracts per effect | `m-effect-refinement.md` P3 |
DRAFT §5.2's prose contract; the 9-of-12 census is what 'no contract' costs". And (Grounding):
"the sunholo migration doc's row V/R34 measured the same absence".

**Evidence** (delegated sweep, commands as run):

```
find ailang/design_docs -name 'm-effect-refinement*'
  planned/v1_0_0/m-effect-refinement.md            Status: Decomposed (2026-07-11) — umbrella doc
find ailang/design_docs -name 'm-effect-replay-contracts*'
  implemented/v0_30_0/m-effect-replay-contracts.md
  implemented/v0_30_0/m-effect-replay-contracts-sprint-plan.md
sed -n 18p planned/v1_0_0/m-effect-refinement.md
  | P3 replay contract registry | Planned | [m-effect-replay-contracts](…) (sprint 2, ~3d) |   <- stale row; the link dangles
grep -n 'R34' ailang/design_docs/planned/m-motoko-dst-refactor-migration.md
  354: … (see the mission log's R16/R34)          <- no row labelled R34 or V/R34
sed -n 40p ailang/design_docs/planned/m-motoko-fork-disposition.md
  | R34 | … `runtime_config_resolved`, `config_resolved`, `policy_resolved`, `resolved_config` are **all 0** … |
```

Also: `ailang/` is a gitignored standalone checkout at `de5a141e4` (`v0.33.1-85`), not a
submodule; `ailang.lock` pins the *CLI* at v0.33.0. The handlers doc's Target is "v0.21.0
(Phase 1) → v0.22.0 / v1.0.0 for full surface"; Phase 1 estimate "~30–40h" (line 6, 189).
Rows 1–3 of the table otherwise reproduce (Status Planned; ~2.5d; ~3d; the priority quote is
verbatim). The third column's "198 hand-threaded sites" is the whole-`src/core` count; the
per-file attribution the ADR inherits from NOTE-002 (90/64/18/13) sums to 185 — the other 13
are in the three DST drivers, `dst_fault_catalogue.ail`, `ext_world.ail` and `rpc.ail`
(`grep -c next_state src/core/*.ail | grep -v ':0$'`).

**Corrected text.** "Three asks. The replay-contract registry (refinement P3) shipped in
v0.30.0 (`implemented/v0_30_0/m-effect-replay-contracts.md`); what Motoko owes 012 for that row
is an *adoption* entry, not an ask. The resolved-policy absence is
`planned/m-motoko-fork-disposition.md` row R34, not the migration doc."

### F5. C1 corrects inputs that were right, and misreads `ports.ail:219`

**ADR says** (C1): "RESEARCH §2.B1 as stated cannot go red … Nothing inside pure state
threading can observe a value that was never threaded." And (D2 part 1): "on `ports.ail:219`'s
own anticipation of 'encounter ordinals'. 29 adapter bodies, mechanical."

**Evidence.**

- RESEARCH §2.B1 (line 137–140): "a monotone request ordinal in `WorldState`, plus a
  finalization invariant that the returned world's ordinal equals the recorded request count".
  "Recorded request count" is not defined. If it means the world's own `log`, the ADR is right
  and the check is vacuous. If it means a count the *driver* or the *wire* keeps — the natural
  reading of "recorded" in a tree whose recorder is `record_interaction` and whose ledger is
  the wire — RESEARCH B1 *is* D2 parts 2–3, and the ADR has not corrected it, only chosen one
  reading. Either way the ADR's own D2 puts its observer inside the same pure state threading
  (F1), so C1's principle, applied to D2, rejects D2.
- `ports.ail:215–219`: "Unlike `script` and `approvals` this is a KEYED LOOKUP, not a cursor:
  reads do not consume it and the successor is the same world. `EnvRead` still carries a
  successor … because A13's interaction log will want to record the read (encounter ordinals)".
  The ordinals anticipated there are the *interaction-log* ordinals, which have since landed:
  `record_interaction` (`:1525`) assigns `ordinal: List.length(state.log)` and its header says
  "This is the ONLY place an ordinal is assigned and the ONLY place the log grows. Both
  properties are deliberate" (`:1516–1524`). D2 part 1's 29-site increment is the design that
  comment was written to forbid.
- The 29 adapters are not independent: `recording_clock` calls `virtual_clock` (`:1550`),
  `recording_env` calls `scripted_env` (`:1570`), `recording_file_write` calls
  `scripted_file_write` (`:1630`), `recording_approval` calls `scripted_approval` (`:1719`).
  "Incremented by every adapter" advances a recording world by 2 per request and a scripted
  world by 1, so a recorded run and its strict replay end with different ordinals on the new
  field. Beyond `ports.ail`: `bounded_scripted_ports`' capacity-rejection arm returns
  `next_state: state` (`stub_step.ail:~360`), and four more identity returns sit outside
  `ports.ail` (`grep -n 'next_state: state\b'` → 24 in `ports.ail`, 5 elsewhere).
- The token round-trip: `world_to_token`/`token_to_world` (`ext_world.ail:562–566`) go through
  `world_json`/`world_of_json` (`:543–553`), whose decoder is total with per-field fallbacks. A
  new `ordinal` field that is not added to both sides is silently reset to its fallback on
  every hook dispatch — the six `ext_ports_of` sites plus every `dispatch_*` — and the
  invariant fires falsely on every run.

**Corrected text.** "RESEARCH B1's 'recorded request count' is ambiguous; this ADR reads it as
the world's own log, under which reading the check is vacuous, and moves the observer outside
the world. The ordinal is assigned at one site, not 29 — either at `record_interaction`'s
single append (which then covers only recorded classes) or in the request helper — and the
`ExtWorld` token carries it. `ports.ail:219` anticipated the log ordinal, which exists."

### F6. "Fail-closed" is quietly redefined

**ADR says** (Relates to): "`../028_…/ADR-001` (fail-closed rule, which D1 instantiates)". And
(Context): "**Fail-closed at every boundary** (028 ADR-001): an absent input becomes 'cannot
measure', never 'no problem'." And (Options, D1 #4): "*Refuse to run under `Unknown`* — the
literal fail-closed reading. Rejected now … Loud, not blocking."

**Evidence.** 028 ADR-001 §Decision: "`Err(_) => Reject` with the infra error surfaced as the
rejection reason; make the gate non-configurable for shipped profiles"; §Consequences: "Cost:
rejection on verifier infra failure may block legitimate work until the environment is fixed —
accepted; silent approval is worse." The "cannot measure, never no problem" phrasing is
NOTE-005 §1's ("an absent input becomes 'no problem detected' rather than 'cannot measure'"),
not 028 ADR-001's. Option 4 is the 028 rule; the ADR rejects it and keeps the label.

**Corrected text.** "D1 makes the measurement boundary fail-*loud*: the miss is named at step 0
and on every poll, and the loop proceeds. That is NOTE-005 suggested item 1 plus a type. It is
a recorded departure from 028 ADR-001's fail-closed (blocking) form, deferred to 'Not decided'
with the reasons Option 4 gives; it does not instantiate that rule."

### F7. D4's "mechanical preconditions" and "after item 3 it is a file" are not earned

**ADR says** (D4): "placed after items 2 (one entry point, options record) and 3 (loop / DP7 /
fixtures split), which are its mechanical preconditions and are already there." And: "The
pilot is the tool phase (RESEARCH Q5). It is the most self-contained, and after PLAN-002 item 3
it is a file."

**Evidence.** `src/core/tool_phase.ail` exists: 642 lines; header "Phase C approval-planning
surface. Full native/delegated execution moves here later"; exports `execute_allowed_tool_call`
(`:304`) and `dispatch_tool_entries_with_builtin` (`:459`); its three port sites are
`ports.clock_now` `:413`, `ports.env_get` `:414`, `ports.tool_exec` `:421`; `session.ail:151`
imports it and it does not import `session`. What remains in the loop is the `RunTools` arm
(`session.ail:2496–2590`: plan, `NativeToolCalls` event, the dispatch call at `:2546`, state
rebuild). PLAN-002 item 3 (`:38–48`) splits `phase_vocab` and `session.ail` into "loop body /
DP7 gate / scripted-ports fixtures" and does not mention the tool phase; item 2 (`:23–31`) is a
surface check and a `RunV2Options` record, which a commands pilot in the tool phase neither
needs nor touches.

**Corrected text.** "The tool phase's dispatcher already lives in `tool_phase.ail` (642 lines,
three port sites); the pilot's command vocabulary is those three sites plus the dispatch call at
`session.ail:2546`. PLAN-002 item 3 shrinks the loop file the pilot edits and item 2 removes
entry points it would otherwise have to keep parity with; both help, neither is a precondition.
The phase is placed after them for sequencing, not dependency."

### F8. D6's mechanism claim overstates what the Makefile does

**ADR says** (D6): "The Makefile already enforces the other direction (a listed target that
passes fails the summary), so the list cannot go stale in the direction that hides a red".

**Evidence.** `Makefile:481–493`: "It waives nothing: the exit code is propagated untouched …
`scripts/dst/sweep_summary.sh` also reports a target on this list that PASSES, so the list
cannot outlive the failure it describes." `scripts/dst/sweep_summary.sh:82–86, 106–109`:
`fixed` targets get `NOTE: %s is listed in DST_KNOWN_RED but PASSED. Drop it from that list`;
`rc` is never modified and `Makefile:512` is `exit $$rc`. `DST_KNOWN_RED :=` is empty (`:493`).
`DST_JOBS ?= $(shell nproc …)` (`:433`).

**Corrected text.** "A listed target that passes is *reported* with a drop instruction; the
exit code is untouched in both directions. The list is disclosure, not a waiver, and it is
empty at HEAD. D6's obligation is therefore to populate it, and a v2 should say the reverse
check is a printed note a reader has to act on, not a red."

### F9. D5: the exit render is world-mediated inbound only

**ADR says** (D5): "the exit render is world-mediated since `4b37439`, the exit *execution* is
a host effect and stays one".

**Evidence.** `git show --stat 4b37439` → `session.ail` hunk `- ports: noop_ext_ports()` /
`+ ports: ext_ports_of(provider.ports, provider.world, env_url)`; confirmed. But
`publish_turn_exit_manifest` (`:3362–3410`) threads `named.next_state` *into* the render and
returns `()`; the render's outcome world never comes back, and at `:2372` the call is `let _ =`
after `c2_finalize`. `exit_manifest.ail:7–21` confirms execution is TUI-side and why.

**Corrected text.** "The render reads through the world since `4b37439` and its successor is
discarded by design (`:3409–3410`), so the exit end is world-mediated in one direction; a
driven exit end threads that successor back or records why it cannot. This is also the
post-finalization request F1(i) names."

### F10. Grounding and prose that claims more than the code earns (learning §6)

Each sentence below asserts something I could not confirm, or that the code contradicts.

| ADR sentence | What is true |
|---|---|
| "The `1`, `10`, `464` fixtures NOTE-165 §0 describes cannot be written." (D1 rule 5) | `Bounded({ raw_window: 10, source: Catalogue })` is that fixture with a label; `effective_input_limit` still maps it to no-budget. The type forces the arm to be named; it does not prevent the value. |
| "29 adapter bodies, mechanical." (D2 part 1) | Four recording adapters wrap scripted ones (F5); the token decoder must carry the field (F5); the ordinal has one assignment site by design (`ports.ail:1516–1524`). |
| "the successor's ordinal is recorded by the driver's trace, which a dropped successor cannot discard" (TL;DR D2) vs "A high-water mark in driver state, `world_high_water: int`" (D2 part 2) | Two different designs in one ADR; neither survives the whole-record drop (F1). |
| "The comment is then deleted; the invariant is what replaces it." (D2) | The comment argues stored == fresh resolution; the invariant argues nothing about that. Deleting it removes the only record of why the four sites read a stored value. |
| "there is no step-0 resolved-policy event to extend today" (D1 rule 2) | `SessionStart(SessionStartInfo)` (`phase_vocab.ail:727`, `{ task, model, mode }` at `:585`) is emitted at `session.ail:3288`. There is a step-0 event; it lacks the field. The v2 should name it as the default vehicle and check whether the traced `run_v2*` entry points emit it. |
| "Every number this ADR leans on is there [NOTE-002] with a reproduce command" (Relates to) | The 27/24/3/8 receiver census, "2 of 14 profiles", "23 rows" and "eight times" are not in NOTE-002. The census reproduces (below); the profile and catalogue numbers are NOTE-005's and reproduce (`ls -d .motoko/config/*/ | wc -l` → 14; `grep -l '"context_limit"' .motoko/config/*/config.json` → 2; `context_limits` keys → 23). |
| "27 direct port-request sites in the driver by receiver grep" (Grounding) | Reproduces exactly (`session.ail` 24 across receivers `p`, `ports`, `provider.ports`, `st.provider`; `tool_phase.ail` 3; `context_usage.ail` 8 behind `r.`). It excludes three named-helper indirections (`execute_allowed_tool_call` `:2481`, `dispatch_tool_entries_with_builtin` `:2546`, `dispatch_pre_step_chain` `:2632`) and the six `ext_ports_of` forwarders; D2 part 2's "27 direct port sites" is the wrong count for "every site that receives a world response". |
| "`ContextLimit` is one more sum through the `phase_vocab` hub (fan-in 13)" | 15 importers (13 outside `src/core/test/`). |
| "20,831 lines of `src/core/dst_*.ail`" (D3 table) | 20,831 at `2192092`; 20,858 at HEAD (`9a1a253` touched `dst_profile*.ail`). Correct at the ADR's own HEAD. |
| "`src/core/session.ail:177, :412`" for the driver's trace | `:177` is `TracedSessionResult.trace`; driver state is `C2LoopState` (`:383`), trace at `:412`. |
| "which its own log says have been re-baselined eight times" (Consequences) | The log's counter reads "AN EIGHTH TIME" (`anchors.sh:309`); it records eleven `session.ail` anchor movements (WI-D24, WI-D25 and the 7.0 review are unnumbered). |
| "Violation constructor `WorldSuccessorDropped({ at: LedgerRecord, carried: int, high_water: int })`" | All 37 `Violation` constructors are positional (`dst_invariants.ail:283–332`); the register is `sample_violations()` pinned at 37 (`:1887`, `:1903`), so a new constructor moves that pin, `violation_rule` and `violation_family`. Style, but the ADR says the family is "in `dst_invariants.ail`" without pricing the pin. |
| D1 acceptance "Decoy: … an ambient read that bypasses the world reports `Bounded` where the routed read reports `Unknown`" | Distinguishing, but it re-tests the routing WI-D3 landed and `make world_state`'s poison pair already guards (`dst_driver_only.ail:821`). D1 does not change routing. D1's own seam is the *int*: the decoy that matters is a fixture where `Unknown` and `Disabled` project to the same `0` and the status field and step-0 record must differ. Arm C says this; it should be called the decoy. |
| "both `rpc.ail` status sites" (D1 rule 1) | `rpc.ail:128→:142` and `:323→:337` populate the `context_limit` field of `ExtCtx`-shaped records for the budget-plan and system-prompt hooks. They are ABI-projection sites, not status sites; under rule 1 they call the projection function rather than "match on the sum". |

**Options considered.** No straw men found. D1's five options are each real (option 1 is
NOTE-005 item 1 verbatim; option 5's "two homes" objection is the `ports.ail` header's own
argument); D2's four and D4's two are fairly stated. Option D2-3 ("wait for D4's interpreter")
is the one this review would revisit: with part 3 unable to go red (F1), the case for parts 1
and 3 now, ahead of the single-site interpreter, weakens.

**Decisions with no named gate.** D3 (a filed issue is not a gate; acceptable, it is
outward-facing). D4 (a placement; its gate is 028's). D5 (explicitly deferred). D7 (a table).
D1 and D6 name gates. D2 names one that does not see (F1).

### F11. Costs

**ADR says:** D1 3–4 days; D2 2–3 days; D3 half a day; D6 half a day; ~7 working days.

**Against the evidence:**

- **D1.** Sites: `CompactionPolicy` field (hub, 15 importers); six `mk_v2_ext_ctx` sites with
  two projection semantics; `EmptyStopFinalize` info + wire projection + golden + vocabulary
  row; `seal_compacted_payload` signature; `runtime_status_json` (+ the new source field);
  `should_checkpoint`; two `rpc.ail` sites; 38 `mk_policy`/`mk_state*` call sites and six
  `scripts/` constructors; three arms + decoy; the anchor cascade (seven files incl. three
  profile re-issues, `anchors.sh:285–293`); `make event_vocabulary` if a variant is chosen;
  two contract candidates under 027's register. **5–8 days**, of which the cascade is a known
  half-day-to-day each time `session.ail` moves.
- **D2.** As designed it cannot go red (F1), so its cost is undefined until a v2 design
  exists. For the mechanical parts alone: one ordinal site + the token codec (`ext_world.ail`)
  + 17 `WorldState` literals in 6 files (`grep -rn 'clock_ms:' src scripts --include=*.ail |
  grep -v -- '-- '` → ports 5, dst_replay 4, invariants_dst 3, dst_execution 2, ext_world 2,
  dst_invariants 1) + a helper at 24 + 3 + 3 indirect + 1 exit-manifest sites + a wire event or
  record field (D6-gated) + the invariant with its 37→38 pin + a derivation script on the
  `derive.py` pattern (33 KB). **4–6 days after a corrected design**, not 2–3.
- **D3.** Half a day for three records; fine.
- **D6.** Half a day to run (NOTE-005 measured 789 s) and populate the list; the three reds
  NOTE-005 reported are not priced and could each be a day. Fine as stated for the list.
- **Total.** 10–15 working days for D1 + D2 + D3 + D6, versus the ADR's ~7, and D2's number
  is only meaningful once F1 is answered.

## 3. What the ADR got right

- C2 and C3 both reproduce; the re-ranking of the sentinel fix to first is correct and the
  NOTE-005 chain (`context_usage.ail:91, :94, :132, :135–141` → `compaction.ail:26, :43` →
  `compaction_structural.ail:42, :61, :89`, `compaction_ai.ail:533`) is exactly as cited.
- D1's core shape — a closed sum at the resolution boundary, `Disabled` declared not inferred,
  `agent.context_limit: 0` and an absent key resolving identically today
  (`context_usage.ail:137–141`; `resolve_context_limit:166` falls through on `0`) — is right,
  and NOTE-165 §8's three-arm acceptance is the right shape.
- The grounding numbers that matter reproduce: `verify_core` 11/0/1/48 and 9 substantive;
  `fault_catalogue` 11 classes, four `FaultBoundary` variants with an exhaustive `boundary_id`
  and `required_class_ids()` pinned at 11 (`:288`, `:835`); 29 adapters; 12 port fields; four
  `resolve_context_limit` sites; 37 `ledger_emit` sites, private; `c2_loop` 682 lines;
  `session.ail` 3,813; the receiver census 24/3/8.
- D5's facts: `4b37439` replaced `noop_ext_ports()`; execution is TUI-side
  (`exit_manifest.ail:10–21`); `verify_exit_intent` case 8 plants `w1:pDECOY`
  (`scripts/verify_exit_intent.ail:291–335`); adding a `FaultBoundary` variant is a
  compile-time obligation and the required list is a coverage claim, so deferring the classes is
  consistent with 009 D3's waiver rule.
- D6's instinct: the sweep's state is unknown, `DST_KNOWN_RED` is empty, and nothing that
  changes `Ports`, the loop or `LedgerEvent` should start before it is established.
- D4's relocation to 028 and the dropped paper gate (NOTE-002 §4.7) are sound; D7's
  dispositions are sound.
- The anchor cascade is quoted accurately (five anchors at `anchors.sh:384`; the six-file list
  at `:287–293` and the "contract-frozen" sentence at `:301`).
- D3's first three rows: paths, Status lines, estimates and the priority quote all reproduce;
  the local record format (`## Status` / `## Not yet filed upstream`) and the feedback skill's
  channels 1–2 are as described.

## 4. What a v2 must change

1. **D2 is redesigned around an observer a drop cannot un-happen.** Either the ordinal goes
   on the wire at each request and the invariant is monotonicity over the wire ledger plus
   final equality (which makes D2 D6-gated, and the ADR must say so), or part 3 is demoted to a
   single-channel consistency test and D2 is honestly a field plus a discipline. The
   red-before-fix demonstration is a planted drop in a fixture, not the four WI-D4 sites.
2. **C1 is rewritten.** Drop the parenthetical about the four sites and "unrecorded keyed
   lookups"; state RESEARCH B1's ambiguity and which reading the ADR takes; cite
   `ports.ail:1516–1524` for the single-assignment design and `ports.ail:219` for what it
   actually anticipated; name `:3265` and `:2372→:3385` as the drops that exist.
3. **D1 rule 1 lists the projection sites as they are**: two ABI projection functions (raw
   and net-of-pinned) or one with a recorded behaviour change; the wire field, the seal
   parameter and the status field named as int surfaces served by those functions; the
   `rpc.ail` sites called what they are. Rule 5's "cannot be written" becomes "must name the
   arm". `SessionStart` is named as the default step-0 vehicle.
4. **"Fail-closed" is replaced by "fail-loud"** everywhere D1 is described, with the
   departure from 028 ADR-001 recorded as such.
5. **D3 becomes three asks** plus one 012 adoption entry; the R34 citation moves to
   `m-motoko-fork-disposition.md:40`; the "198" attribution is corrected to 185 + 13.
6. **D4 drops "mechanical preconditions" and "it is a file"**; states that `tool_phase.ail`
   already holds the dispatcher and what the pilot's command vocabulary is.
7. **D6 describes the reverse check as a printed note**, not a summary failure.
8. **D5 records the outbound drop** at `:3409–3410` as the exit end's real gap.
9. **Costs re-derived** from the site lists above (F11); D2 unpriced until item 1 is done.
10. **The Grounding block** corrects `:177` → `:383/:412`, fan-in 13 → 15, and stops claiming
    every number is in NOTE-002.
