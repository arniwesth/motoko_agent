# PLAN-001 P1B — answer (P1 steps 3–7)

Branch `arniwesth/013-plan003-and-herdr`, parent `db0dbc7`. One commit, not pushed.
**Commit hash:** this file is inside the commit, so it cannot contain the commit's own hash.
Run `git log -1 --format=%H -- .motoko/ab/answer-p1b.md` to get it. The orchestrator's
report also gives it.

## Frozen decision: the `Disabled` profile key (Open question 3)

**Frozen as `agent.context_limit: "disabled"`**: the string value `"disabled"` under the
profile's existing `agent.context_limit` key in `config.json`. The single home is
`context_limit.disabled_profile_value()`.

- **No schema change, so nothing is deferred.** `config.load_agent` never decodes
  `agent.context_limit`. `context_usage` read it with `getInt`, so a string there was already
  a silent fall-through. No TS parser reads the key: `src/tui/src/models.ts` reads only the
  catalogue's `context_limits`.
- **Rule 3 holds.** An absent key is `ProfileKeyAbsent` and a non-int, non-sentinel value is
  also `ProfileKeyAbsent`. An int ≤ 0 is `ProfileKeyNonPositive`. Every one of these falls
  through to the catalogue.
- **Only the explicit string gives `Disabled`.** It then skips the catalogue half, the same
  way a positive override always has.
- No shipped profile declares it.

## What landed, step by step (with drift from the plan's stale references)

| Step | Where (current tree) | What |
|---|---|---|
| 3 | `session.ail` `runtime_status_json` (plan said :555–600; HEAD :665) | New `context_window.context_limit_source` field. The private `limit == 0` sentinel is gone: `measured = is_bounded(sum)`, and all three percentages render 0 when the arm is not bounded. The raw `context_limit` int stays, via `raw_window_of`. `tool_catalog.ail` `MotokoRuntimeStatus` description updated. |
| 4 | `session.ail` `run_v2_traced_from_seed` (plan said :2994; HEAD :3867) | `ContextLimitResolved({ run_id, limit })` is emitted **and** appended once per run, **after `HistorySeeded`**, so the seed stays the first journal-class record. The same record is also added at the one entry that bypasses the shared helper, the untraced `run_v2_from_messages_with_policy_and_counts` (HEAD :4074), so no run path lacks it (cF8). |
| 4 | `phase_vocab.ail` | New variant, `ContextLimitResolvedInfo`, and a projection `{type, run_id, context_limit, context_limit_source}`. Three goldens, one per arm. `context_limit_source_json` is the single home for the reason's JSON shape. Its keys are fixed on every arm: `arm`, `origin`, `profile_miss`, `catalogue_miss`, `model`. The status field and the event both use it. |
| 4 | `dst_event_vocabulary.ail`, `scripts/dst/event_vocabulary_dst.ail` | New row: Logical, `reaches_trace_today: true`. Count **41 → 42**: 36 logical, 6 display-only. The D6.4 gap is unchanged at 2. |
| 5 | `session.ail` exit context (plan said :3399; HEAD :4528) | `context_limit: 0` kept. The site now says: no window is supplied to the exit context; this is a literal, not a projection, and not `Disabled`. |
| 6 | `context_usage.ail`, `context_limit.ail` | The sentinel above. |
| 7 | `context_usage.ail` | New `resolve_context_limit_sum -> { limit: ContextLimit, next_state }`. It makes the same env and file requests in the same order. `Bounded` is built only through `resolve_bounded_from_{profile,catalogue}`. `Unknown` carries the profile miss **and** the catalogue miss. `resolve_context_limit` and `catalog_context_limit_for` stay as int wrappers built on `raw_window_of`, because `rpc.ail` (3 sites) and three scripts still read `.value`. `rpc.ail` is **untouched**: it carries another author's uncommitted edits. |
| 7 | `phase_vocab.ail` `CompactionPolicy.context_limit: ContextLimit`; `session_policy_init` / `session_policy_with_model` store `r_limit.limit` | Int readers now go through named projections: `step_machine.should_checkpoint` → `raw_window_of` (raw denominator, cF7); `EmptyStopFinalize.context_limit` and both RunTools `mk_v2_ext_ctx` sites → `raw_window_of`; the CallModel `context_limit` local (seal and post/boot ctx) → `raw_window_of`; the pre-step working budget → `working_budget_for_ext` (kept separate, rule 4). |

**Fixture constructors (rule 5):**
- `step_machine.mk_policy` now takes the sum. All 18 call expressions name their arm:
  `fixture_unmeasured()` = `Unknown{ProfileKeyAbsent, CatalogueAbsent}`, or `fixture_bounded(n)`.
- The three script `policy(int)` constructors wrap their int in `fixture_limit(n)`.
  `n > 0` becomes `Bounded` through the catalogue resolver; anything else becomes `Unknown`.
  Scripts: `phase_c_seeded_dst`, `phase_c_l1_scenarios`, `phase_f_pipeline_wiring`.
- The two `session.ail` inline tests use `Bounded{1000, Catalogue}`.

**Rule 4 (no behaviour change under `Bounded`)** holds by construction. Each projection
reproduces the int the site read before: `raw_window_of` gives `raw_window`, and
`working_budget_for_ext` equals the old `effective − pinned` floor for `pinned ≥ 0`.
Every existing record keeps its relative order. The new record is the only trace change.

### Deviations recorded, not silently decided

1. **`event_vocabulary_version()` stays `"event-vocabulary/1"`.**
   - I read "version bump under `make event_vocabulary`" as the gate's count (41 → 42), per
     the brief.
   - The string was not bumped through PLAN-003's seven additions either.
     `REVIEW-plan003-v3.1-verdicts-claude.md` note 2 records that as wanting "one deliberate
     commit covering both". That commit should now cover `ContextLimitResolved` too.
   - Bumping it here would move every profile manifest, `driver_plus_herdr`'s included, so it
     stays out of P1B.
2. **The seal keeps its `raw_context_limit: int` signature.**
   - `session.ail` passes it `raw_window_of(sum)`, and the seal subtracts the output allowance
     internally, as before.
   - The plan's step 2c wiring (the seal takes the sum and calls
     `context_limit.effective_input_limit`) would re-sign 11 call expressions across
     phase_vocab tests and three DST scripts. It was not in the P1B brief and is left for
     P1C or its owner.
   - Behaviour is identical: `NoBudget` and `Budget(0)` both meant pct 0 before.
3. **`scripts/dst/ledger_parity_dst.ail`'s pinned order literals were re-pinned.** Both the
   `native` and `capped` subjects now read `HistorySeeded|ContextLimitResolved|…`. This is the
   plan §2.2 "Row 7 parity witness" artifact moving with the event, a direct consequence of
   step 4. Without it `make ledger_parity` is red. No new required-row list was added, and the
   wire-count comparison picked the variant up automatically.
4. **A non-int, non-sentinel `agent.context_limit` maps to `ProfileKeyAbsent`**, because
   `ProfileMiss` has no "wrong type" variant. A catalogue that decodes without a
   `context_limits` object maps to `CatalogueUndecodable`.

## Gate evidence (tiered)

| Gate | Tier | Result |
|---|---|---|
| `ailang check` on every modified `.ail` (7 core + 4 scripts) | type/effect | ✓ all clean |
| `ailang check` over all 96 files: `src/core/*.ail` + every script/package importing a changed module | type/effect | 95 ✓, 1 ✗ = `scripts/probe_phase_vocab_sealed.ail` IMP010 `MkHistory`. This is the **inverted-polarity** sealing probe (Makefile:3079); its failure is its pass. |
| `ailang test src/core/context_limit.ail` | unit | 4 pass, 3 skip (no ADT generator; same as P1A) |
| `ailang test src/core/context_usage.ail` | unit | 3/3 |
| `ailang test src/core/phase_vocab.ail` (includes the 3 new goldens) | unit / byte golden | 28/28 |
| `ailang test src/core/step_machine.ail` | unit | 17/17 |
| `ailang test src/core/dst_event_vocabulary.ail` (42-row pins) | unit | 13/13. Run directly, because `make event_vocabulary` discards this status after `;`. |
| `ailang test src/core/session.ail` (includes both runtime_status tests) | unit | 27/27 |
| `make event_vocabulary` | DST gate | ✓ PASS: 42 variants == 42 rows == 42 goldens; 42 round-trip; 36 logical / 6 display-only |
| `scripts/dst/runtime_status_tool_dst.ail` (the `compaction_dst` line, run alone) | DST fixture, real driver | ✓ PASS count=2. Model `runtime-status-model` now resolves `Unknown`. The existing assertions do not read percentages. |
| `make ledger_parity` | DST wire-vs-trace | ✓ PASS after the re-pin. `ContextLimitResolved: projected 8, returned 8`. It was ✗ before the re-pin, on the order row only. |
| `make invariants` | DST | ✓ PASS; the D6.4 gap is still ScratchpadResult, SessionSuspend |
| `make journal_resume` | DST, out-of-process | ✓ PASS rows=13. SessionResumed is still the first record of the resumed frame. |
| `tools/predicate-anchors/anchors.sh` | anchor check | ✗ **expected red**. The five session.ail clock anchors moved (see cascade). |

## Gates NOT run, and why

- **`make dst` (full sweep): NOT RUN.** Forbidden by the brief because of the memory
  ceiling.
- **`make anchors`, `make attribution_table`, `make driver_only`, `make driver_plus_no_ops`,
  `make driver_plus_compose`, `make profile_definition`: NOT RUN.** The anchors are moved and
  deliberately not re-baselined (the brief says P1C owns the gate). These targets would be red
  on anchor drift that is expected here, so a run proves nothing until P1C re-baselines.
- **The rest of `make compaction_dst`: NOT RUN** (`compaction_policy_dst`,
  `compaction_catalog_dst`, `scripted_cursor_probe`, `long_qwen_compaction_dst`). Only the
  runtime_status line is P1B's fixture. All four type-check clean.
- **Other sweep targets that consume the trace or wire and were not named in the brief: NOT
  RUN.** Examples: `phase_c_l1`, `phase_c_seeded`, `terminal_trace`, `strict_replay`, corpus
  targets, `stream_parity`, `recorded_stream`, the discovery and world-state probes.
  - A grep found no other pinned `HistorySeeded|…` order literal.
  - The shell gates count per wire type, and none counts `context_limit_resolved`.
  - Any target that pins total trace length or total wire lines is unverified.
  - `terminal_trace`'s `{ result:` literal count is unchanged: no terminal literal was added.

## Anchor cascade (re-derived; not re-baselined)

Used the plan's grep: `grep -rn '\(session\|tool_phase\|ext/runtime\).ail", line: [0-9]' --include=*.ail .`

- The brief's five-anchor list is correct at HEAD. `anchors.sh:552` has `1422 1681 1793 3884 4096`;
  the plan's `1164 1423 1529 3016 3126` is stale.
- **Moved, all pure offset drift.** Each anchored line (`clock_now(`) is byte-identical to
  `git show HEAD:`:

| HEAD | now | Δ |
|---|---|---|
| 1422 | 1431 | +9 |
| 1681 | 1690 | +9 |
| 1793 | 1802 | +9 |
| 3884 | 3893 | +9 |
| 4096 | 4114 | +18 |

- **Pinning files** (this is the cascade width):
  - `tools/predicate-anchors/anchors.sh` (:552)
  - `src/core/dst_attribution_table.ail` (:239–247 all five; :734 `1793`)
  - `scripts/dst/attribution_table_dst.ail` (:123 `1793`; :127 `4242` is a synthetic
    "discovered by nobody" site, not a live anchor — P1C to judge)
  - the three P1 profiles via version + `content_hash`: `dst_driver_only`,
    `dst_driver_plus_no_ops`, `dst_driver_plus_compose`
- The `tool_phase.ail` (389, 484) and `ext/runtime.ail:199` pins did not move, so the seven
  discovered-site fixtures are untouched.
- **`driver_plus_herdr`: not re-issued, and not required green.**
  - `dst_driver_plus_herdr.ail` has no `session.ail` line pin; the grep matched only
    `herdr_graded_dst.ail`'s ext/runtime and tool_phase pins, which did not move.
  - Its manifest reads the live `event_vocabulary_version()`, which is unchanged.
  - Nothing in P1B needs it green.

## What P1C consumes

1. **Anchor re-baseline.** The five new positions and the byte-identity result are above. Bump
   the three profile versions + hashes, then run `make anchors`, `make attribution_table`, the
   three profile targets and `make profile_definition`.
2. **The three-arm acceptance on `scripts/dst/runtime_status_tool_dst.ail`.** P1B only kept the
   existing two scenarios green. Each arm asserts the status message's
   `context_window.context_limit_source` and the returned trace's `ContextLimitResolved`
   record (second record, after `HistorySeeded`).
   - **Arm A.** `runtime-status-model`, no catalogue row, no profile. With the fixture's empty
     world this resolves to `Unknown{profile_config_absent, catalogue_absent}`; seeding a
     catalogue without the row gives `model_not_in_catalogue`.
   - **Arm B.** A catalogue row for `runtime-status-neighbour` gives
     `Bounded{catalogue}`.
   - **Arm C.** `MOTOKO_PROFILE_DIR` plus `config.json` with
     `{"agent":{"context_limit":"disabled"}}` gives `Disabled`.
3. **Step 8 contract candidates** on `raw_window_of`, `working_budget_for_ext` and
   `effective_input_limit`. P1A carries int-only `ensures`, and no candidate was added here.
   The new helpers (`is_bounded`, `limit_*_id`) are pure string/bool maps with no substantive
   contract.
4. **Open owner items.**
   - The `event_vocabulary_version` string bump (deviation 1).
   - Optionally the seal's sum signature (deviation 2).
   - TUI rendering of "unmeasured" (TypeScript follow-up, a non-goal).
