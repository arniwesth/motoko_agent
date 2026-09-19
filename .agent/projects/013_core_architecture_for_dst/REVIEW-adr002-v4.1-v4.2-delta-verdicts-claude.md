# ADR-002 v4.1 → v4.2 delta review verdicts

Date: 2026-09-13
Reviewed HEAD: `d888585749c4c1b6244b91a9f7dcfdbf548b8548` (`git rev-parse HEAD`, branch `arniwesth/013-plan003-and-herdr`). The ADR file is clean in the tree (`git status` does not list it), so its line numbers below are HEAD's. Every code file cited below is also clean at HEAD. The only dirty tracked file is `ailang.lock`, and nothing here cites it.
Subject: `ADR-002-park-and-wake.md` v4.1 (commit `80743bc`) and v4.2 (commit `b48e2f2`; `git diff 80743bc b48e2f2` adds the history entry at `:180–187` and the Consequences paragraph at `:604–640`, and nothing else)
Against: `REVIEW-adr002-v4-verdicts-fable.md` (HEAD `3ee3d03`), its "Required changes" 1–6

**Scope.** This review covers only the v4.1 folds and the v4.2 paragraph. It does not re-review v4. Each fold is checked twice:
- **At `3ee3d03`**, through `git show 3ee3d03:<path>`, because the ADR pins its code coordinates there (`:25–26`, `:692`). This judges the fold as written.
- **At `d888585`**, because PLAN-001 P1/P2 and PLAN-003 P1/P3/P3ORD have landed since. This judges whether PLAN-002 can be written against the text today.

No `make dst` sweep was run. No live measurement was re-derived.

## Overall verdict

**Accept with corrections. All six v4.1 folds are in the text, and each is correct at the HEAD the ADR pins. PLAN-002 steps 1–5 can be written now.** None of the residuals below reopens a decision. They are text edits that events since `3ee3d03` forced, plus one wrong premise that started in the v4 review itself:

1. **P2 has landed, so D5 step 3's conditional is settled in one direction.** The ADR still says "no `ordinal` on `WorldState` at HEAD" and offers a pre-P2 default (`:557–562`). At `d888585`, `WorldState` carries `ordinal` and `pending` (`src/core/ports.ail:493–494`). `advance` is at `src/core/world_ordinal.ail:33–36` (P2A `bd0eac7`, through P2D `a6abda4` and the sweep follow-up `633366c`). Step 3 now lands after P2, so the only default left is `advance(world, WakeRead)`. Two landed tests pin that `wake_read` is *not* a class, and step 3 has to flip both. Neither the ADR nor the v4 review names them:
   - `world_ordinal.ail:112`: `request_class_of_id("wake_read")` must be `None`.
   - `src/core/ext_world.ail:811–823`: a forged `"wake_read"` witness must be dropped as unknown.

   The freeze note at `tools/driver_leaf_inventory/derive.py:21` ("no sixth variant") also moves.
2. **"No fixture that reaches this arm enables a verifier" is false, both at `3ee3d03` and at HEAD. The conclusion it supports still holds.** v4.1 copied the premise (`:159`, `:356–357`) from the v4 review's §3. Two gated fixtures run a live-shaped verifier on a non-blank, tool-free candidate:
   - `scripts/dst/ledger_parity_dst.ail:260–263` (`dp7_rt`, `enabled: true, command: "exit 3"`), whose scenario at `:493–500` scripts `prose_step("done")`. It runs under `make ledger_parity`, which is in `DST_TARGETS` (`Makefile:489`).
   - `scripts/smoke_v2_dp7_gate.ail:38–41` (`enabled_rt`), run by `smoke_driver` (`Makefile:2314–2317`), also in `DST_TARGETS` (`:481`).

   Both use `registry: { entries: [] }`, so solver dispatch returns `NoDecision`. The persist nudge is off by default (comment at `src/core/session.ail:2262`). Moving DP7 ahead of solver dispatch therefore cannot change either fixture's decision sequence, and "fixtures do not move" survives. The sentence should name these two fixtures as step 2's DP7-before-solver regression gate instead of claiming there are none.

   One thing is not verified: on a DP7 rejection under stage 2 the solver never runs. The world that arm carries would then be `intercepted.next_state` rather than `token_to_world(finalized.next_state)` (`session.ail:3721`, `:3724`, `:3794`). That is identical only if an empty-registry dispatch returns its input world unchanged after `clear_holder`. `ledger_parity` frames its runs on the wire (P2G `c1bc518`), so step 2's gate will show any difference. Worth one sentence in the plan.
3. **v4.2's paragraph contradicts v4.1 fold 3 in one phrase.** "`Park` with a request id out of `decide`" (`:627–628`) contradicts "`Park` carries **only the waits**; the driver builds the `ParkRequest`" (`:376–379`, `:163–164`). It should say "`Park` out of `decide`, a `ParkRequest` built by the driver".
4. **Coordinates are pinned at `3ee3d03` and have moved.** The ADR's pin is honest, but a plan written today must cite HEAD. The map is in §3. v4.2's own paragraph mixes bases: `herdr_graded_dst.ail` did not exist at `3ee3d03`, while `ports.ail:979–983`/`:2558` in the same paragraph are `3ee3d03`'s.

| Decision (delta only) | Verdict | Short reason |
|---|---|---|
| D1 | **no delta** (v4 ACCEPT stands) | v4.1 and v4.2 do not touch D1; not re-reviewed. |
| D2 | **ACCEPT WITH CORRECTIONS** | Folds 2, 3 and 6 are present and correct. Residual 2 (the false premise, true conclusion) and residual 3 (v4.2's "`Park` with a request id"). "Blank" is not defined; both code notions are `trim(s) == ""`. |
| D3 | **ACCEPT** | Fold 4 is present. `settled` is still absent from the code, so "new" stays true. At HEAD `meta_timed` has a seventh key, so the six-name list is stale but was right at `3ee3d03`. |
| D4 | **ACCEPT** | Fold 5 is present. The gap it names is still real at HEAD. P3ORD adds cross-run ordinal continuity on the resume path, not in the live loop. |
| D5 | **ACCEPT WITH CORRECTIONS** | Fold 1 is present as a conditional that P2's landing has settled. Residual 1: keep the `advance` variant only, and name the two negative tests step 3 flips. |
| D6 | **no delta** (v4 ACCEPT stands) | Untouched. |
| Consequences (v4.2) | **ACCEPT WITH CORRECTIONS** | The argument is sound and correctly bounded. Residual 3; the "20 s" figure is now 45 s at HEAD; one coordinate base mix. |

## 1. Disposition of the v4 review's "Required changes"

| # | required (v4 review `:163–170`) | disposition | evidence at `3ee3d03` (as pinned) | at HEAD `d888585` |
|---|---|---|---|---|
| 1 | D5 step 3: "with P2", or a pre-P2 default that returns the world unchanged | **Folded** (`:149–152`, `:557–562`, TL;DR `:205`). The ADR takes the second option: unchanged before P2, `advance(world, WakeRead)` with or after it. | `ports.ail:183–196` has no `ordinal` ✓; `PLAN-001:370–375` is P2 Part 1 ✓ | **Settled by events.** P2 landed: `ports.ail:493–494` (`ordinal`, `pending`), `world_ordinal.ail:33–36` (`advance`), five classes at `:41–61`. The pre-P2 branch is dead, so the default is `advance(world, WakeRead)`. Step 3 also flips `world_ordinal.ail:112` and `ext_world.ail:811–823` and edits `derive.py:21`/`:164`. Residual 1. |
| 2 | D2 stage 2: price the verifier or gate on non-blank; replace "their fixtures move" | **Folded** (`:153–160`; stage table `:340`; priced `:351–357`; Consequences `:581–582`). Both halves were taken: the gate and the price. | verifier `exec` `session.ail:1933` ✓, `dp7_rejection_errors` `:1976–1978` ✓, `empty_rt` verification off `stub_step.ail:786` ✓ | Verifier at `session.ail:2197–2211` (`exec` `:2200`, enabled check `:2198`); `dp7_rejection_errors` `:2243–2255`, called only from `c2_after_dp7` `:2922`, which is reached from `:3724` (`Accept`) and `:3794` (`NoDecision`, no nudge) ✓ price accurate. `empty_rt` `stub_step.ail:788–791` (disabled at `:789`) ✓. Premise "no fixture enables a verifier" ✗, conclusion ✓ (residual 2). |
| 3 | D2: say where `ParkRequest.request_id` is built | **Folded** (`:161–165`, `:376–380`, TL;DR `:202`). `Park` carries only waits; the driver builds the request from `RunIdentity` and `park_ordinal` in `C2LoopState`. | `StepState` `phase_vocab.ail:308–318` ✓; `decide` `step_machine.ail:114–138` ✓ | `StepState` `phase_vocab.ail:424–434` still has neither `run_id` nor a park ordinal ✓. `decide` `step_machine.ail:116–141` is effect-free ✓. **Code already anticipates the driver half:** `c2_loop` takes `identity: RunIdentity` (`session.ail:2985`, param `:2998`), and `run_id_for` builds `<session_id>.r<resume_count>.<run_ordinal>` (`:4269–4271`), matching `:373–375`. `C2LoopState` (`:509–545`) has no `park_ordinal` yet, as expected. No `ParkRequest`/`open_waits`/`wake_read` anywhere in `src`, `packages`, `scripts` or `tools` except the two negative tests in item 1. **Nothing contradicts.** |
| 4 | D3: name `settled` as new; add the error-without-settle row | **Folded** (`:166–169`; row `:478`, new row `:479`). | `meta_timed` `herdr.ail:172–177`, six keys ✓; error branch `:1100–1102` ✓ | `meta_timed` is now `herdr.ail:199–206` with a **seventh** key, `elapsed_is_exact` (`:205`), so the ADR's six-name list (`:167`, `:478`) is stale. No `settled` key anywhere, so "new" stays true. Error-without-settle branch is now `:1466–1478`: it settles `lost` only under `means_agent_gone` (`:1470–1474`), otherwise writes a note (`:1475`) and returns `err_result` (`:1476`). Same shape ✓. |
| 5 | D4: the framing subset includes threading `traced.world` into the loop | **Folded** (`:170–173`; D4 `:514–520`; step 5 `:567–568`; TL;DR `:205`). | `session.ail:3380–3386` (the "SUCCESSOR IS DROPPED" comment), `:3419`, `:3426`, `:3611` ✓ | **Still real.** The loop now takes `provider: PortedProvider` (`:4307`), which carries a world (`provider.world` read at `:4371`; seeded `{ live_provider \| world: init.next_state }` at `:4638`, `:4674`, `:4830`). But the `user_message` arm hands `traced.world` only to `publish_turn_exit_manifest`, whose result is dropped (`let _ =` at `:4463`), and recurses on the pre-turn `provider` (`:4484`, `:4491`, `:4498`). P3ORD (`d888585`) asserts `BEGIN₂.ordinal₀ == END₁.final` through `run_summary.world_ordinal` and the journal fold (`journal_resume_dst`), which is the resume path, not this loop. It gives the frame-identity rule (`:504–508`) an implemented precedent without closing the subset. Because the world slot already exists on `provider`, the threading may be cheaper than "the largest single piece" implies; PLAN-002 should price it at HEAD. |
| 6 | Coordinates: EOF `:3368`; `decide` tests `:246–396`; `dp7_fail_open` has no producer | **Folded** (`:174–178`; EOF `:498`; tests `:359`; no producer `:361–362`). | EOF `if raw == "" then ()` at `session.ail:3368` ✓ (`:3372` is `let cmd_type`); first `decide` test `step_machine.ail:246`, fifteenth ends `:395` ✓; `ext/runtime.ail:676–677` ✓ | EOF `session.ail:4352`, `cmd_type` `:4356`, restart `SessionSuspend` `:4385–4389`. `decide` tests at `step_machine.ail:258–408`, still fifteen: `:258`, `:268`, `:280`, `:292`, `:302`, `:316`, `:325`, `:334`, `:347`, `:356`, `:365`, `:374`, `:383`, `:392`, `:401`. **`dp7_fail_open` still has no producer:** the only occurrences are the class at `step_machine.ail:130` and the test at `:374–381`. `smoke_v2_dp7_gate.ail:110`'s `test_dp7_fail_open_on_missing_make` is named for the behaviour, but `run_dp7_verifier` returns `Approve` on missing infrastructure (`session.ail:2201`, `:2206`), so it produces `dp7_approved` (`:2971`). `dispatch_solver_candidate` is now `ext/runtime.ail:721–728`, row `{Process, IO, Clock}` ✓. |

## 2. Per-decision verdicts on the deltas

### D2 — accept with corrections

**The stage-2 gate.** Stage 2 fires on "complete **and non-blank**" (`:340`). A blank candidate falls to stage 3 (it parks, `:341`) or stage 4, where the empty-stop guard owns it (`:342`). That matches the code's owners of blank:
- `empty_stop_guard.decide_with_budget` bounces `is_blank(candidate)` (`packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:62–66`, `is_blank` = `trim(s) == ""` at `:8–10`).
- The progress guard ignores blanks (`progress_contract_guard.ail:204`, `trim(candidate) != ""`).
- The core floor `EmptyStopFinalize` tests `trim(info.output) == ""` inside the `Finalize` arm (`session.ail:3058`).

The ADR never defines "blank". PLAN-002 should use `trim(candidate) == ""` so all four sites agree.

**The price.** "With verification enabled, `run_dp7_verifier` runs its command on every non-blank complete candidate, where today it runs only on the ones solver policy let through to `c2_after_dp7`" (`:351–354`) is exact at HEAD (§1 row 2). The effect row `{Process, IO, Clock, Trace}` for `classify_candidate` (`:333–335`) is the union of `dispatch_solver_candidate`'s `{Process, IO, Clock}` (`ext/runtime.ail:721`) and `dp7_rejection_errors`'s `{Process, IO, Trace}` (`session.ail:2243`) ✓.

**"Fixtures do not move."** The conclusion is right and the premise is wrong (residual 2). The guards are still pure over `(ctx, candidate)` at HEAD. 7.3 added `ctx.work_in_flight`, read purely at `progress_contract_guard.ail:189–200`, so "their own tests are pure" (`:356`) holds. The wiring scenarios still use `empty_rt()` or verification-disabled runtimes (`scripts/dst/phase_c2_wiring_scenarios.ail:145`, `:186`, `:289`, `:318`, `:328`, `:349`, `:359`).

**`decide` payload.** Fold 3 is consistent with the code (§1 row 3). The fifteen tests stay untouched as long as `Park` carries only waits.

**v4.2 wording.** Residual 3.

### D3 — accept

Fold 4 is in the table (`:478–479`). The seventh `meta_timed` key (`elapsed_is_exact`, `herdr.ail:205`, added after `3ee3d03`) makes the enumerated list incomplete at HEAD. That is informational, not a correction to the decision: `settled` is still absent and still new.

### D4 — accept

Fold 5 is in D4 (`:514–520`) and in D5 step 5 (`:567–568`). The gap is verified real at HEAD (§1 row 5). The cited coordinates are `3ee3d03`'s; at HEAD the recursion sites are `session.ail:4354`, `:4376`, `:4484`, `:4491`, `:4498`, `:4503`, and the entry calls are `:4638`, `:4697`, `:4755`, `:4759`, `:4766`, `:4846`.

### D5 — accept with corrections

Fold 1 is in the text as written. Residual 1 is the correction P2's landing forces. Three more notes:
- "The scanner recognises the field in both cases; only the witness gate (P2's) sees the difference" (`:561–562`). The witness gate now exists (P2B `6b33f36`, P2G `c1bc518`, P2T `2fe783a`). A step-4 call site must therefore witness the `WakeRead` it advances, or the frame-boundary rule "no `END` with `pending` non-empty" (PLAN-001 P2 Part 1) goes red. That is the gate working as intended; state it in the plan.
- The "three literal entries" are still three: `ports_shape_probe` at `ports.ail:2596–2612`, and `long_qwen_compaction_dst.ail:385–405`, `:515–535`.
- The ADR handoff's precondition, "PLAN-003 P1 must land first" (`:669–670`), is met: `RunIdentity` is in `session.ail`'s imports (`:174`) and is threaded through `c2_loop`.

### Consequences, v4.2's "What becomes testable" — accept with corrections

**The argument is sound and correctly bounded.** Waiting costs wall-clock time, and DST's clock does not model elapsed time, only the order and count of scripted effects. So the polling cost cannot show up in any fixture. A park turns that wait into a discrete transition (`Park` out, a wake back in) whose order and count *can* be asserted. The "what still is not testable" paragraph (`:634–640`) stops the claim from growing past that.

**Spot-checks.** These are prose consistency and coordinates only; no live measurement was re-derived and no DST target was run.

| claim | check | result |
|---|---|---|
| `eff(duration_ms, exit_code, stdout)` at `herdr_graded_dst.ail:151–155` | `git show b48e2f2:` and HEAD | ✓ both |
| determinism assertion at `:748–758`; 97+101+103+107+109+113 = 630 ms | HEAD comment `:748–757`, assert `:758`; `eff(97, …)` at `:166` | ✓ arithmetic and text |
| the file's own admission that `format_ms` rounds | `:754–757` | ✓ |
| "the only DST script that reaches the extension" | `grep` for herdr imports in `scripts/dst/*.ail` finds only `herdr_graded_dst.ail`; `src/core/dst_driver_plus_herdr.ail` is a profile module, not a script | ✓ |
| "`DelegateCheck` appears in no DST fixture" | only a comment, `dst_driver_plus_herdr.ail:161` | ✓ |
| `WorkInFlight` criterion-2 slot at `dst_driver_plus_herdr.ail:194` | `criterion_2_slot_ids` → `["tool_provider[0]", "work_in_flight[0]"]`, `:194–196` | ✓ |
| `ports.ail:979–983`, "bound at `:2558`" | ✓ at `3ee3d03`; HEAD `:1019–1024`, `:2598` | base mix (residual 4) |
| "`herdr agent wait --timeout 20000`", "N x 20 s" | `register.ail:142` default `20000` at `b48e2f2` ✓; HEAD `register.ail:173` default **45000** (`5f73d8f`, 2026-09-08 18:17, after `b48e2f2` at 16:54) | stale at HEAD; argument unaffected |
| "a 300-step budget consumed in 88 minutes, ~120 of the steps heartbeats" | consistent with `9bfcc2f`'s message ("exhausted 299 steps in 88 minutes with roughly 120 of them heartbeats"), which also raised the default `max_steps` 300 → 1200 | consistent as prose; **not re-derived** |
| "`make dst` was green throughout" (history `:186–187`) | not re-run. `e69df2c` bisects the herdr targets green at `b48e2f2` and red from `d72fff1`; both are `DST_KNOWN_RED` at HEAD (`Makefile:655`). The run clauses of `herdr_graded` are green, but its "profile record loads clean" clause is red | true for its date; the one fixture the paragraph leans on is a known red at HEAD |
| "`Park` with a request id out of `decide`" (`:627–628`) | against fold 3 (`:376–379`) | ✗ residual 3 |

## 3. Coordinate map, `3ee3d03` → `d888585`

The ADR's citations are correct at the HEAD it pins. This map covers the ones PLAN-002 will need. It lists the coordinates the folds cite plus the v4.2 paragraph's.

| ADR cites (`3ee3d03`) | HEAD `d888585` |
|---|---|
| `session.ail:684–697` `c2_step_state` | `:926–940` |
| `session.ail:1930–1934` verifier / `:1933` exec | `:2197–2211` / `:2200` |
| `session.ail:1976–1978` `dp7_rejection_errors` | `:2243–2255` |
| `session.ail:2352` / `:2394` (`dp7_rejected` / `dp7_approved`) | call `:2922`; reasons `:2942` / `:2971` |
| `session.ail:3012–3082`, `:3017`, `:3020`, `:3080` | `None =>` branch `:3716–3797`; dispatch `:3721`; `Accept` → `c2_after_dp7` `:3724`; nudge test `:3758`; else `:3794` |
| `session.ail:2468–2488` empty floor / Done / RunSummary | floor `:3057–3061`; `DoneEvent` `:3069–3070`; `c2_finalize` `:3075`; emit `:3076` |
| `session.ail:3367–3430`, `:3368` EOF, `:3372` cmd_type, `:3391–3399` restart | loop `:4294–4507`; `:4352`; `:4356`; `:4378–4390` |
| `session.ail:3380–3386`, `:3419`, `:3426`, `:3611` | `:4463` (dropped `traced.world`), `:4484`, `:4491`, `:4498`; entries `:4638`, `:4697`, `:4755–4766`, `:4846` |
| `step_machine.ail:93–111` / `:114–138` / `:134–135` / `:246–396` | `:96–114` / `:116–141` / `:136–137` / `:258–408` |
| `phase_vocab.ail:308–318` `StepState` | `:424–434` |
| `ext/runtime.ail:676–677` | `:721–728` |
| `ports.ail:183–196` (no ordinal) | `ordinal`/`pending` at `:493–494`; `advance` `world_ordinal.ail:33–36` |
| `ports.ail:979–983` / `:2556–2572` / `:2558` | `:1019–1024` / `:2596–2612` / `:2598` |
| `long_qwen_compaction_dst.ail:383–402`, `:513–532` | `:385–405`, `:515–535` |
| `stub_step.ail:786` | `:788–791` (flag at `:789`) |
| `derive.py:142` / `:151–155` | `:164` / `:173–177` (`HELPED` unchanged at `:94–105`) |
| `herdr.ail:172–177` / `:1100–1102` | `:199–206` (+`elapsed_is_exact`) / `:1466–1478` |
| `ADR-001:448–449` | unchanged (`:448`) |

## Required changes (text only; no decision reopened)

1. D5 step 3 (`:557–562`, TL;DR `:205`, history `:149–152`): P2 has landed (`ports.ail:493–494`, `world_ordinal.ail:33–36`). Keep only `next_state: advance(world, WakeRead)`. Say that step 3 flips `world_ordinal.ail:112` and `ext_world.ail:811–823` and edits `derive.py:21`/`:164`. Say that step 4's call site owes a witness under P2's frame-boundary rule.
2. D2 (`:355–357`, history `:158–160`): replace "no fixture that reaches this arm enables a verifier" with "the two that do, `ledger_parity_dst.ail:260–263`/`:493–500` and `smoke_v2_dp7_gate.ail:38–41`, run with an empty registry, so their decision sequences are order-invariant; they are step 2's DP7-before-solver gate". Define blank as `trim(candidate) == ""`.
3. v4.2 (`:627–628`): "`Park` out of `decide` and a `ParkRequest` built by the driver", not "`Park` with a request id".
4. v4.2 (`:614`, `:623`): note that `HERDR_CHECK_WAIT_MS` defaults to 45 s since `5f73d8f`. Note that the paragraph's `herdr_graded_dst.ail`/`dst_driver_plus_herdr.ail` coordinates are post-`3ee3d03`, and that `herdr_graded` is `DST_KNOWN_RED` at HEAD (`Makefile:655`).
5. PLAN-002 cites HEAD, not `3ee3d03` (§3).

PLAN-002 steps 1–2 writable: yes; steps 3–5 writable: yes (residuals: D5 step 3's default is the `advance` variant only, since P2 has landed, and the step flips the two landed negative `wake_read` tests at `world_ordinal.ail:112` and `ext_world.ail:811–823`; D2's "no verifier-enabled fixture" premise names `ledger_parity` dp7 and `smoke_v2_dp7_gate` as step 2's order-invariant gate; v4.2's "`Park` with a request id" wording; the stale 20 s figure; every coordinate re-cited at HEAD).
