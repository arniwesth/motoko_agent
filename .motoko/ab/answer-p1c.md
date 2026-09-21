# PLAN-001 P1C — answer (the P1 gate: anchors, three-arm acceptance, step 8, Done-when, sweep)

Branch `arniwesth/013-plan003-and-herdr`, parent `ad558d0` (P1B). One commit, not pushed.
**Commit hash:** this file is inside the commit, so it cannot contain its own hash. Run
`git log -1 --format=%H -- .motoko/ab/answer-p1c.md`; the orchestrator's reply also gives it.

The working tree carried other authors' uncommitted edits: `.devcontainer/agent_confined/docker-compose.yml`
and `ailang.lock`, plus several untracked paths. They were **left out of the commit**.

## 1. Anchor re-baseline (first, as briefed)

**Re-derived with the plan's grep:**
`grep -rn '\(session\|tool_phase\|ext/runtime\).ail", line: [0-9]' --include=*.ail .`

- The only `session.ail` pins are `dst_attribution_table.ail` (5 rows + 1 test literal) and
  `attribution_table_dst.ail:123`.
- `:127`'s `4242` is the synthetic "discovered by nobody" site. It is not an anchor, and it
  still names no live clock site.
- The `ext/runtime.ail:199` and `tool_phase.ail:389/318/484` pins did not move.

**D4 judgement evidence:**
- `grep -o 'clock_now.*'` gives the same output over `git show ad558d0~1:src/core/session.ail`
  and over the tree: thirteen hits, same text, same order.
- All five anchored lines are byte-identical at their new offsets, compared with `sed -n` against
  `git show ad558d0~1:`.

| before | after | Δ | expression (identical) |
|---|---|---|---|
| 1422 | 1431 | +9 | `let reading = p.clock_now(w0);` |
| 1681 | 1690 | +9 | `let reading = ports.clock_now(env_id.next_state);` |
| 1793 | 1802 | +9 | `let reading = ports.clock_now(world);` |
| 3884 | 3893 | +9 | `let started = provider.ports.clock_now(derived.next_state);` |
| 4096 | 4114 | +18 | `let started = provider.ports.clock_now(derived.next_state);` |

**Width: the six-file form.**
1. `tools/predicate-anchors/anchors.sh`: the loop, plus a tenth re-baseline note.
2. `src/core/dst_attribution_table.ail`: 5 rows and the `:1793` test literal.
3. `scripts/dst/attribution_table_dst.ail`: the `omitted_site` literal.
4. The three profiles, each with a new version, the new table hash
   `sha256:01f5ebc537f53e3487ee3d0180b72f7a3b774e6aa6f2cc77344887528d823f38` (was `2c86584b…`), and a
   re-issue note:
   - `driver_only` v29 → v30
   - `driver_plus_no_ops` v18 → v19
   - `driver_plus_compose` v10 → v11
   - The live hash was read off `make driver_only`'s own rejection before the bump.

**`driver_plus_herdr` was not re-issued, and nothing here needed it green.**
- It carries no `session.ail` line pin.
- Its stale ref (`eba3f47…`) predates this item. It stays in `DST_KNOWN_RED`.

## 2. Three-arm acceptance — `scripts/dst/runtime_status_tool_dst.ail`

**Setup.**
- The existing two scenarios are kept unchanged. Three are added.
- One history, one script (a `MotokoRuntimeStatus` call, then prose), and one catalogue seeded in
  `WorldState.files` at `.motoko/model-catalog.json`: `{"context_limits":{"runtime-status-neighbour":71}}`.
- The runs go through `run_v2_session_traced(..., ScriptedWorld(world))`, the real driver and the
  real builtin.

**Each arm asserts two witnesses independently:**
- **The status message.** `context_window.context_limit_source` is matched as a **literal**,
  together with the raw int, so the wire shape is pinned rather than re-derived.
- **The returned trace's `ContextLimitResolved` record.** It must be the **second record, directly
  after `HistorySeeded`**, exactly **one** per run, and it is matched on the `ContextLimit` sum
  itself.

| Arm | World / model | Trace record (sum) | Status literal | Also |
|---|---|---|---|---|
| A `Unknown` | catalogue without the row; `runtime-status-model`; no profile | `Unknown{ProfileConfigAbsent, ModelNotInCatalogue("runtime-status-model")}` | `"context_limit":0,…"arm":"unknown",…"profile_miss":"profile_config_absent","catalogue_miss":"model_not_in_catalogue","model":"runtime-status-model"` | all three pcts `0`; the loop proceeds (`CallModel,RunTools,CallModel,Finalize`) |
| B `Bounded` neighbour | same catalogue; `runtime-status-neighbour` | `Bounded{71, Catalogue}` | `"context_limit":71,…"arm":"bounded","origin":"catalogue"` | pcts are measured (`usage_pct` 281); rule 4, see below |
| C `Disabled` (decoy) | A's world plus `MOTOKO_PROFILE_DIR=/w/runtime-status-profile` and `config.json` `{"agent":{"context_limit":"disabled"}}`; A's model | `Disabled` | `"context_limit":0,…"arm":"disabled"` | same int 0 as A in both records; the arm id differs from A's in the trace; the status contains C's literal and not A's, while A's contains A's |

**Arm B's rule-4 witness is two comparisons.**
1. **Exact, on a tool-less pair.** Same history, script `[prose "done"]`, A's world against B's.
   The projection removes the `ContextLimitResolved` record and writes the neighbour's model id as
   A's. The model is the arm's *input*, and it rides in `thinking_stream_start`. After projection,
   every decision and every existing record's wire bytes must be **byte-identical**.
2. **On the status pair.**
   - Decisions are identical and the projected record-*kind* sequence is identical.
   - The **first byte difference must be the status tool result** carrying `"arm":"bounded"`.
   - The status run cannot be byte-compared past that record, and the report does not pretend it
     can. The status message *is* the measured quantity, it enters the history, and every chain
     digest after it moves by construction.
   - The first draft compared the status pair byte-for-byte and went red at index 2 on the model
     id. That is why the projection names the model rewrite explicitly.

**Result:** `runtime_status_tool_dst PASS count=5`.

**Mutation (the arms can go red).** A throwaway copy made two changes: the catalogue row renamed to
`someone-else`, and C's world stripped of its profile. Result: `FAIL failed=2`.
- Arm B went red: `second_record=ContextLimitResolved(unknown, raw=0)`.
- Arm C went red: `same_int=true trace_differs=false status_differs=false`.
- Arm A stayed green, correctly: its model is still absent.
- The mutant file was deleted.

## 3. Step 8 — the three contract candidates under 027's register

**P1A's two int contracts were not actually holding.** `ailang verify src/core/context_limit.ail` at HEAD:
- **`raw_window_of`: VIOLATION.** `ensures { result >= 0 }` fails on `Bounded({raw_window: -1})`.
  Positivity is by construction, and the type cannot say so.
- **`working_budget_for_ext`: SKIPPED.** It called `output_token_allowance()`, and the verifier
  rejects the unencodable type `()`.
- **Consequence:** `make verify_core` was red on this file since `a24a78a`, and neither contract was
  in `contracts.register`. `verify_core` and `verify_classify_check` are not `make dst` targets,
  which is how this went unseen.

| Candidate | Change | `ailang verify` | Register class |
|---|---|---|---|
| `raw_window_of` | body `Bounded(r) => if r.raw_window > 0 then r.raw_window else 0`; `ensures { result >= 0 }` | VERIFIED | **substantive** (taut VIOLATION, det VIOLATION) |
| `working_budget_for_ext` | allowance as a `let` literal (65536); `ensures { result >= 0 && result <= raw_window_of(limit) }`, the plan's candidate | VERIFIED | **unclassified**, with the reason below |
| `effective_input_limit` | **no contract; reason recorded at the site** | a wrapper with `ensures { match result { Budget(n) => n >= 0, NoBudget(_) => true } }` SKIPS: "calls user function effective_input_limit that is not SMT-encodable in this context" (the `InputBudget` sum result) | not registered |

**Why `raw_window_of`'s guard is safe (rule 4):**
- The guard is unreachable from both resolvers (`n > 0`), so every constructed `Bounded` reads what
  it read before.
- A grep finds no `Bounded({ raw_window: 0|-… })` construction in `src`, `scripts` or `packages`.
- A hand-built non-positive window now reads 0, the same int as the unmeasured arms.
- New unit test: `raw_window_of_non_positive_bounded_is_zero`.

**Why the inlined literal cannot drift:** the new unit test
`working_budget_allowance_is_the_seal_allowance` pins the literal to `output_token_allowance()`.

**Why `working_budget_for_ext` is unclassified, not substantive:**
- The real module VERIFIES the upper bound.
- Both of `classify.py`'s generated probes (`taut_…` and `det_…`) SKIP: "calls user function
  `raw_window_of` that is not SMT-encodable in this context". A contract that references another
  function is outside what the probes can encode.
- I kept the plan's stronger bound rather than weakening it to `result >= 0` just to win a
  `substantive` label.
- No override was added, because an override must disagree with a probe *result* and there is none.

**`contracts.register` was regenerated by `classify.py --write`.** Two new entries; the other twelve
keep their class and hashes (only solve times and column width changed). Totals went from
`9 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified` to
`10 substantive, 2 tautology, 0 spec-equals-body, 2 unclassified`.

## 4. Gate evidence (tiered; only checks actually run)

| Gate | Tier | Result |
|---|---|---|
| `tools/predicate-anchors/anchors.sh` before any edit | anchor check | ✗, five `session.ail` anchors (expected; P1B's drift) |
| `make anchors` | anchor check | ✓ |
| `make attribution_table` | DST + unit | ✓ `attribution_table_dst PASS`, 15/15 |
| `make driver_only` before the bump | profile | ✗ `the attribution table was corrected and driver_only was not re-issued (D4)` (the expected re-issue signal; gave the live hash) |
| `make driver_only` / `driver_plus_no_ops` / `driver_plus_compose` | profile | ✓ PASS ×3 (unit 6/6, 7/7, 9/9) |
| `make profile_definition` | profile | ✓ `profile_definition_dst PASS` |
| `scripts/dst/runtime_status_tool_dst.ail` | DST fixture, real driver | ✓ PASS count=5; mutant ✗ failed=2 (B, C) |
| `make event_vocabulary` | DST gate | ✓ 42 variants == 42 rows == 42 goldens; 42 round-trip; 36 logical / 6 display-only; `dst_event_vocabulary.ail` 13/13 run directly |
| `ailang check` on all 7 modified `.ail` + all 9 importers of `context_limit` | type/effect | ✓ all |
| `ailang test` on the 5 modified core modules | unit | ✓ context_limit 6 pass / 3 skip (no ADT generator, as P1A); the rest all pass |
| `ailang verify src/core/context_limit.ail` | Z3 | ✓ 2 verified (was 1 violation, 1 skipped) |
| `python3 tools/verify_classify/classify.py --write` | Z3 register | ✓ 14 contracts classified |
| `make check_core` | type/effect + boot probes | ✓ `src/core/ type-check: 59 passed, 0 failed`; `verify_extensions (default): 9 booted, 0 failed` |
| `make verify_core` | Z3 | ✓ `13 contracts proven, 0 unstated, 1 blocked; 0 files failed, 50 bare`; `src/core/context_limit.ail (2 proven)` |
| `make verify_classify_check` | Z3 register | ✓ 5/5 unit; `14 contracts, register agrees (10 substantive, 2 tautology, 0 spec-equals-body, 2 unclassified)` |
| `make compaction_dst` (the fixture's sweep line and its three siblings) | DST | ✓ `compaction_policy_dst PASS count=3`, `runtime_status_tool_dst PASS count=5`, `scripted_cursor_probe PASS`, `long_qwen_compaction_dst PASS count=12` |

## 5. Phase-gate sweep

SWEEP_PLACEHOLDER

## 6. Gates NOT run, and why

- **`driver_plus_herdr` re-issue: NOT DONE, by the brief.**
  - It does not pin `session.ail`, and the cascade did not need it.
  - It stays red for its own stale ref and in `DST_KNOWN_RED`, alongside `herdr_graded` and
    `depth_canary`.
- **`event_vocabulary_version()` string bump: NOT DONE.** It is still `"event-vocabulary/1"`. It is
  P1B's deviation 1, owner-held: bumping it moves every profile manifest, `driver_plus_herdr`'s
  included.
- **The seal taking the sum** (plan step 2c; P1B deviation 2): **NOT DONE.**
  - Not in the P1C brief.
  - `seal_compacted_payload` still takes `raw_window_of(sum)`, and behaviour is identical.
- **PLAN-001's own text was not edited.** Its Done-when still says "35 variants" and its anchor
  lines are stale. The brief names 42 as the HEAD count, and 42 is what was gated.
- **TUI rendering of "unmeasured"** is a TypeScript follow-up and a plan non-goal.
- **Standalone runs of `ledger_parity`, `invariants`, `journal_resume`, `strict_replay` and the
  corpus targets: NOT run on their own.** They are covered only as far as the sweep in §5 covers
  them.

## 7. Done-when, line by line

| Done-when clause | Status |
|---|---|
| `runtime_status_tool_dst.ail` passes three arms | ✓ PASS count=5 (2 existing + A, B, C); mutant red on B and C |
| per-run record independently asserted | ✓ second record after `HistorySeeded`, exactly one, matched on the sum, in every arm |
| `make event_vocabulary` at the HEAD count | ✓ 42 (the plan's 35 is stale: P1B took it 41 → 42) |
| `make anchors` + `make attribution_table` + three profile targets | ✓ all green, plus `make profile_definition` |
| `make check_core` on every modified `.ail` | ✓ full target green; every modified file and every `context_limit` importer checked individually |
| three contract candidates registered or reason recorded | ✓ `raw_window_of` substantive; `working_budget_for_ext` verified, unclassified with the probe reason; `effective_input_limit` reason recorded at the site |

## 8. What P2A consumes

P2A in `.dagr/run-plan001.json` is **"P2-1: advance() + ordinal/pending + RequestClass enum + codec
round-trip"**, with dependencies INV and P1B. P1C did not verify INV's state.

1. **The leaf-module pattern.**
   - `src/core/context_limit.ail` imports only `std/option`, so it is the model for `advance`'s
     leaf module, which imports `ports` only.
   - Keep any contract on that module inside the SMT fragment. Two traps are measured here:
     - A call to a `() -> T` helper makes the verifier SKIP the whole function.
     - A contract that calls another user function verifies in the real module, but the
       classifier's probes SKIP it, so it pins as `unclassified`.
2. **The ordering precedent P2B's `witness` follows.**
   - `ContextLimitResolved` is emitted **and** appended at `run_v2_traced_from_seed`, directly
     after `HistorySeeded`.
   - The same record is also emitted at the untraced `run_v2_from_messages_with_policy_and_counts`.
   - Both sit in the `session.ail` block between the 4th and 5th anchors.
   - It performs no request, so no successor moves: the per-run bootstrap chain is unchanged for
     P2B's trace seeding.
3. **The anchors are now coherent** at `session.ail` 1431/1690/1802/3893/4114 and
   `tool_phase.ail:484`, table hash `sha256:01f5ebc5…`, profiles v30/v19/v11.
   - P2A's expected edits (`WorldState` in `ports.ail`, `advance` at the `context_usage` reads,
     the codec in `ext_world.ail`) touch no anchored file.
   - The three `tool_phase` leaves **do** sit in an anchored file. A line move above `:484` or
     `:389` widens the cascade past the six-file form. Measured by this item's grep:
     - `tool_phase.ail:389` is pinned in `dst_attribution_table.ail` (twice) and in five scripts:
       `driver_only_dst`, `driver_plus_no_ops_dst`, `driver_plus_compose_dst`,
       `attribution_table_dst` and `profile_definition_dst`.
     - `herdr_graded_dst` pins `:318`.
     - Price that width, or keep those edits line-neutral.
   - If P2A must edit `session.ail`, the six-file cascade applies again. Sequence the edits so one
     commit lands the final positions.
4. **Event vocabulary is at 42.** P2B's `WorldRequest` makes it **43**; the plan's "36" is stale.
   The `event_vocabulary_version` string bump is still open, for one deliberate commit.
5. **A seeded world for P2 fixtures.** `ScriptedWorld({ scripted_world_state(script) | env: […],
   files: […] })` drives the real traced entry with env and files in the world, as the three arms
   here do.
   - `resolve_context_limit_sum`'s request count is data-dependent. Against arm C's world,
     `MOTOKO_PROFILE_DIR` short-circuits two env reads, and `Disabled` skips the catalogue half.
   - The strict +1 frame gate must count the requests of the world a frame actually seeds.
6. **The register now pins `context_limit.ail`.** Any body edit to `raw_window_of` or
   `working_budget_for_ext` stale-pins it, so run `make verify_classify` and then
   `make verify_classify_check`.
   - Neither `verify_core` nor `verify_classify_check` is a `make dst` target. That is how P1A's
     VIOLATION survived two items.
   - Run both explicitly for any core contract edit.
