# PLAN-001: implement ADR-001 v3 decisions D1, D2, D3 and D6

Date: 2026-09-05. Status: **proposed, not started.**
Grounded at: HEAD `3fe71b0` on branch `arniwesth/013-dst-architecture-adr`.
Evidence base: `NOTE-002-re-read-2026-09-05.md` (measurements at `2192092`),
`REVIEW-adr001-verdicts.md` (v1, Claude) and
`REVIEW-adr001-v2-verdicts-codex.md` (v2, Codex). Governing decision:
`ADR-001-sequencing-the-dst-architecture-caps.md` version 3.

**Thesis.** A fail-open measurement boundary (the unresolved context limit `0` meaning
"unmeasured" reading as "healthy") becomes a fail-loud, named-sum boundary. A world ordinal
advanced at each helped driver request and witnessed onto the stdout wire before any record
construction replaces a same-record invariant that two reviews showed cannot see the tree's
documented drop shape. Three upstream AILANG asks are filed and one shipped feature gets an
honest adoption evaluation. The sweep at the branch point is run and disclosed before any of
it starts.

---

## 1. D6 — the sweep at the branch point

The sweep was run by the operator on 2026-09-05 at `3fe71b0` on this branch: `make dst
DST_JOBS=1`, 830 s wall (NOTE-005 measured 789 s on 2026-09-01), exit 2, **one red**, zero
listed-and-passing. Full log at `.ailang/dst-last.log`; the result is in the table below.
The delegate that drafted this plan did not run it (it exceeds a Motoko tool's time budget).

### Procedure

```
make dst DST_JOBS=1
```

The Makefile target (`Makefile:500–512`) runs the timed targets sequentially, then the
parallel targets under `-j$(DST_JOBS)` with `--output-sync=target --keep-going`, pipes
everything to `$(DST_LOG)`, and passes the log to `scripts/dst/sweep_summary.sh` with the
original exit code, elapsed wall-clock, and job count.

### Reading the summary

`sweep_summary.sh` splits the log into three populations:

- **Failed** — targets whose make recipe exited non-zero. These are the reds.
- **New** — targets in the log that are not in `DST_KNOWN_RED` and not in `DST_REQUESTED`.
- **Fixed** — targets listed in `DST_KNOWN_RED` that passed. Each gets a `NOTE:` line with a
  drop instruction (`:106–111`): a listed target that passes is reported, not failed.
  `DST_KNOWN_RED` is empty at HEAD (`Makefile:493`).

### Disposition per red

For each red the operator:

1. Fixes it (preferred) and re-runs the target alone, **or**
2. Adds it to `DST_KNOWN_RED` with an inline comment naming the reason — e.g.
   `DST_KNOWN_RED := target_name  # NOTE-005 §x: <reason>`.

The list is **disclosure, not a waiver**: the exit code is propagated untouched
(`Makefile:512`), and a listed target that later passes prints a NOTE telling the next reader
to drop it. Nothing in the Makefile prevents editing a boundary before the sweep; D6 is a
workflow precondition, carried by this plan.

### Results table

| Red target | Disposition | Reason |
|---|---|---|
| `ext_ambient_inventory_selftest` | **re-pin (recommended)**: re-pin, re-run target alone; list only if re-pin fails | `FAIL YIELD: expected 17 registrable extensions resolved through ailang.toml, got 18`. A stale pin, not a behavioural regression: `tools/ext_ambient_inventory/fixtures/expected.json:84` still says `"extensions": 17` and its `package_dirs` lacks `repetition_guard`, while the sibling `fixtures/hook_scope/expected.json` was already re-pinned to 18 for that extension's arrival (commit `1104687` re-pinned six artifacts; this is the seventh). The tool resolves all 18 and reads `repetition_guard` as AMBIENT in the closure reading, so `port_mediated` (4) is unchanged; the re-pin is `extensions: 18` plus one `package_dirs` entry. Every other target in the sweep passed. This red exists on the parent branch `arniwesth/exit-intent-abi` at the same commit, since this branch adds only documents. |

Every target that is red at the branch point and not fixed by a code change is listed above
with its reason before D1, D2, or any future D4-phase work begins.

---

## 2. D2's inventory and the event-classification decision

Per the ADR's Implementation handoff, the inventory is D2's first deliverable — every later
D2 cost depends on it. The classification decision for the two new events is also stated here
once.

### 2.1 Derivation script

A Python script on the `tools/ext_call_inventory/derive.py` pattern. Its scan roots:

- `src/core/session.ail` — the driver loop; 22 direct `Ports` calls verified at HEAD
  (ten are `ExtPorts` forwarding fields at `:910–1178`, one is the post-finalization
  `env_get` at `:3385`).
- `src/core/tool_phase.ail` — three leaf requests: `ports.clock_now` (`:413`),
  `ports.env_get` (`:414`), `ports.tool_exec` (`:421`).
- `src/core/context_usage.ail` — eight requests behind `ContextReader` closures with
  `{Env}`/`{Env, FS}` rows (`:49`, `:88`, `:110`, `:129`, `:164`).
- `src/core/test/stub_step.ail` — `dispatch_step` (`:705–713`), the driver's model call,
  forwarding to `ports.model_step`.

Produces:

1. A **de-duplicated leaf inventory**: every direct `Ports` field call by driver-side code,
   with its file, line, receiver name, and whether it is helped or exempt.
2. A **call graph of aggregate helpers** — functions that carry successors and request
   evidence without being request sites: `resolve_context_limit`, `session_policy_init`,
   `session_policy_with_model`, `derive_session_id`, `execute_allowed_tool_call`,
   `dispatch_tool_entries_with_builtin`, `dispatch_pre_step_chain`, `dispatch_step`.
3. The **exempt list**: the ten `ExtPorts` forwarding fields, with each field's effect row
   recorded. `ExtPorts.ai_step` carries `{AI, IO, Trace}` (`types.ail:294`; `session.ail:933`);
   `tool_handle` carries `{IO, Process, FS}`; the other eight are Env/FS/Clock only. Exempt
   because extension-initiated, not because their rows forbid emission.

**Four fixtures:**

- **Un-advanced direct leaf** — a `ports.env_get` call whose successor is discarded; the
  script reports it as un-advanced-and-unwitnessed.
- **Un-advanced leaf behind a named indirection** — the alias bypass: wrap a port call in a
  local `let f = \x. ports.env_get(x, …)` and discard its successor; the script follows the
  indirection and catches it.
- **Helped leaf witnessed after a record construction** — `advance` is called, but
  `witness` runs after `{ world_state: … }` is built; the script reports
  witnessed-after-construction (the one shape the wire cannot see).
- **Control** — a correctly helped-and-witnessed-in-order leaf; the script reports it clean.

If the script cannot be built reliably (the `keep_interpolations` class of parser defect;
learning §7), the ADR is amended to say the no-bypass gate is missing and the coverage claim
is restricted to the hand-maintained inventory. Parts 1–5 of D2 land with that restriction.

### 2.2 Event classification

Two new events, both **logical**, both appended (to the returned trace) and emitted (to the
wire):

- **`ContextLimitResolved`** (D1) — one per run, emitted at the shared per-run entry
  (`session.ail:2994`), carrying the `ContextLimit` arm and, for `Unknown`, both misses.
- **`WorldRequest`** (D2) — one per helped leaf request, emitted from `witness` before the
  successor enters any driver record; carries ordinal and request class.

Classification is logical under the D6 criterion (`dst_event_vocabulary.ail:41–55`): an
event whose presence or order can change an invariant result. A display-only `WireRecord` in
the returned trace is already `DisplayOnlyInTrace` (`dst_invariants.ail:854–865`), so
display-only is not a cheaper option — it is illegal under D2 part 2's requirement that the
helper appends as well as emits.

**Moving artifacts per new variant:**

| Artifact | D1 | D2 |
|---|---|---|
| Vocabulary row + projection | 1 new | 1 new |
| Golden | 1 new | 1 new |
| `make event_vocabulary` version bump | 34→36 variants (once both land) | same |
| Manifest version | changes newly encoded program bytes | same |
| Row 7 parity witness | new required row in `ledger_parity_dst.ail` | same |
| Exporter | wire-only records in `export_trace.ail` | same |
| Gap register | none (always appended) | same |
| Trajectory key | unchanged (hashes interactions) | unchanged |
| Strict replay | unchanged (compares interactions) | unchanged |
| Discovery determinism | unchanged (compares variant names) | unchanged |

**Artifacts that do NOT move:** the trajectory key hashes interactions only
(`dst_corpus.ail:174–181`); strict replay compares `program.interactions` with
`replay.world.log` (`strict_replay_dst.ail:737–752`); discovery determinism compares
variant names (`dst_invariants.ail:1742–1773`). No corpus re-roll is required.

---

## Phases (ADR order: D3, D1, D2)

**Sequencing.** The inventory script (§2.1) is a standalone deliverable, hereafter
**P-INV** (~1–2 days, D6-gated, D3-independent). P-INV lands as its own commit
before P1 begins: P1 consumes the `context_usage` leaves and `ExtPorts` rows from
the landed inventory, and P2 consumes the full leaf inventory plus D1's
`context_limit.ail` leaf-module pattern. P0 (D3) runs in parallel with any of
P-INV/P1/P2. Concretely: D6 → P-INV → P1 → P2. P1 does not duplicate the leaf
list; if P-INV hits its fallback (hand-maintained inventory, §2.1), P1 and P2
proceed under that restriction and the ADR is amended once.

### P0 — D3: file three AILANG asks and one evaluation entry (~half a day plus filing)

**Dependencies.** None. Can proceed in parallel with D6.

**Form.** Three local records in `.agent/issues/`, each following the format of
`.agent/issues/ailang-no-tail-call-optimization.md`: `## Status` with tree version, `## Not
yet filed upstream`, and the symptom/evidence. Filing is outward-facing, through the
`ailang-feedback` skill — channel 2 if the CLI is configured, channel 1 otherwise — and the
local record is then updated with the issue URL.

**Steps.**

1. Write `.agent/issues/ailang-fund-m-effect-handlers-phase-1.md`
   - Upstream: `ailang/design_docs/planned/v1_1_0/m-effect-handlers.md` — Planned; target
     v0.21.0 Phase 1 → v0.22.0/v1.0.0; ~30–40h Phase 1; tree at v0.33.0.
   - Motoko case: 20,858 lines of `src/core/dst_*.ail` implement world boundary, virtual
     clock, synthetic FS and replay in userland. Handlers may replace selected boundary
     plumbing; which parts is measured after adoption, not claimed here.

2. Write `.agent/issues/ailang-per-hook-capability-narrowing.md`
   - Upstream: `ailang/design_docs/planned/v1_0_0/m-effect-scope-params.md` — Planned; ~16h;
     Rand+AI grants only, FS/Net future.
   - Motoko case: 20 of 40 coverage entries rest on a declared row (RESEARCH §2.C).
     Narrowing may convert the subset whose hooks are Rand/AI-scoped; candidate hooks listed
     first.

3. Write `.agent/issues/ailang-pinned-clock-and-fixture-fs-modes.md`
   - Upstream: `ailang/design_docs/planned/v1_0_0/m-effect-clock-net-fs-modes.md` — Planned;
     ~20h.
   - Motoko case: `WorldState.clock_ms` and `WorldState.files` are the feature in userland,
     under 167 non-comment `next_state` lines (198 textual, 31 comments).

4. Write a bounded 012 evaluation entry for the partially shipped replay-contract registry.
   - Upstream: `ailang/design_docs/implemented/v0_30_0/m-effect-replay-contracts.md` — LANDED
     (PARTIAL): Rand dispatch pilot, Rand+AI contract labels; Clock/Net/FS rows belong to
     another sprint.
   - No Motoko code references the registry (`ReplayContract`, `mode=`, `replay/contracts`:
     zero matches in `src packages scripts`).
   - Answers: does the shipped Rand/AI registry express any part of DRAFT §5.2's prose
     contract, and what would the Clock/FS rows need. Not an ask; not a claimed adoption.

5. File all three upstream through the `ailang-feedback` skill. Update each local record with
   the issue URL.

**Gates.** A filed issue is an administrative deliverable, not a red/green gate.

**Done when.** Three local records written; upstream filing initiated with URLs recorded;
evaluation entry written.

**Do not:** claim 20 coverage conversions or deletion of the userland architecture from
handlers; claim the upstream design estimates are Motoko integration estimates; claim the
replay-contract registry is fully shipped across all effects.

---
### P1 — D1: the resolved context limit as a named sum (~5–8 days, D6-gated)

**Dependencies.** D6 (sweep at branch point); P-INV's landed inventory for the `context_usage`
leaves and the `ExtPorts` rows. Does not wait on D3.

**Type home.** A new leaf module, `src/core/context_limit.ail`, importing nothing from
`phase_vocab`, `ports` or `context_usage`, so both `context_usage` and `phase_vocab` can
import it without closing the `context_usage → ports → phase_vocab` cycle
(`context_usage.ail:9` imports `ports`; `ports.ail:44` imports `phase_vocab`). The ADR's
sketch types are the specification.

**Steps.**

1. Define `ContextLimit`, `LimitSource`, `ProfileMiss`, `CatalogueMiss`, `InputBudget`,
   `BudgetMiss` in `src/core/context_limit.ail`. `Bounded` constructed only by the two
   resolvers, only from `n > 0`.

2. Implement three pure projections:

   a. `raw_window_of(ContextLimit) -> int`: `Bounded → raw_window`, else `0`. Serves:
      - Three raw `mk_v2_ext_ctx` sites: `session.ail:2466` (approval), `:2510` (tools),
        `:2774` (post-step).
      - Two `rpc.ail` hook-context literals (`:142`, `:337`).
      - `should_checkpoint`'s two callees (`step_machine.ail:87–90`), keeping `int`
        signatures — checkpoint denominator is raw, unchanged under `Bounded`.
      - `runtime_status_json` (`session.ail:564–590`); the private `if limit == 0 then 0`
        sentinel at `:566` goes.
      - `EmptyStopFinalize.context_limit` (`phase_vocab.ail:580`, projected at `:803`,
        golden at `:1244`) — schema and golden do not move.

   b. `working_budget_for_ext(ContextLimit, pinned_tokens) -> int`: reproduces `max(0,
      effective_input_limit(raw) - pinned)` for the pre-step call at `:2630–2631`. Kept
      separate — unifying the two ABI projections changes behaviour under `Bounded` (rule 4).

   c. `effective_input_limit(ContextLimit) -> InputBudget`: the seal,
      `seal_compacted_payload` (`phase_vocab.ail:145`), takes the sum in place of
      `raw_context_limit: int` and calls this where it calls `effective_input_limit` (`:150`).
      Internal; not an ABI change.

3. Add `context_limit_source` to `runtime_status_json` (`session.ail:555–600`), carrying
   the arm and, for `Unknown`, both misses. The three percentage fields render as `0` when
   the source is not `bounded` (the raw `context_limit` int stays for compatibility). The
   `MotokoRuntimeStatus` tool description (`tool_catalog.ail:70`) states that percentages
   are unmeasured when the source is not `bounded`. TUI rendering of "unmeasured" is a
   TypeScript follow-up.

4. Emit one logical `ContextLimitResolved` event at the shared per-run entry
   (`session.ail:2994`), which the initial live turn (`:3478`), every follow-up turn
   (`:3288–3293`) and every traced entry pass through. `SessionStart` is untouched and
   remains display-only. The event gets a vocabulary row, projection, golden and version
   bump under `make event_vocabulary`.

5. The exit context (`session.ail:3399`) keeps `context_limit: 0`, with the reason named
   at the site: no window is supplied to the exit context. It is not `Disabled`.

6. Add `Disabled` profile key (name TBD). An absent or non-positive profile key is a
   `ProfileMiss` and falls through to the catalogue — `Disabled` requires an explicit key.

7. Update `session_policy_init` (`:1935`) and `session_policy_with_model` (`:1971`) to
   store the sum in `CompactionPolicy.context_limit` (`phase_vocab.ail:174`).

8. **Contract candidates** under 027's register:
   - `effective_input_limit`: the ADR's sketch.
   - `raw_window_of`: `requires { raw_window > 0 }` on `Bounded`; `ensures { result >= 0 }`
     and `Bounded → result == raw_window`.
   - `working_budget_for_ext`: `ensures { result >= 0 && result <= raw_window_of(limit) }`.
   Three candidates; each recorded as substantive or the PLAN says why.

**Anchor cascade.** `session.ail` has five pinned anchors (`anchors.sh`, `for` loop over
`1164 1423 1529 3016 3126`). The general rule is derived, not read off the edited
file: the cascade's width is the set of files that PIN the anchors that moved
(`grep -rn '\\(session\\|tool_phase\\|ext/runtime\\).ail", line: [0-9]' --include=*.ail .`).
For P1's expected session.ail-only move above the first anchor, the six-file form
applies: `anchors.sh` itself, `dst_attribution_table.ail`, `attribution_table_dst.ail`,
the three profiles (`dst_driver_only.ail`, `dst_driver_plus_no_ops.ail`,
`dst_driver_plus_compose.ail`) via version + `content_hash`, plus `session.ail` as cause
(the four discovered-site fixtures pin only `ext/runtime.ail:199` and
`tool_phase.ail:318`, so they are untouched unless those anchors move). Re-baseline
procedure: edit, run `tools/predicate-anchors/anchors.sh` to list moved anchors,
compare each moved anchored expression to `git show HEAD:` character by character
(byte-identical = pure offset drift; anything else is a D4 judgement, do not
re-baseline), update the recorded line numbers, bump the three profile versions +
hashes and the one `attribution_table_dst.ail` literal if pinned. Then run
`make anchors` (checks, does not edit), then `make attribution_table` and the three
profile targets (`driver_only`, `driver_plus_no_ops`, `driver_plus_compose`) plus
`make profile_definition` to derive re-issues. Sequence
edits so one commit lands the final positions or budget both updates — two commits that
each move pinned lines each need coherent pins.

**Acceptance — three arms on the existing fixture.** `scripts/dst/runtime_status_tool_dst.ail`
(under `make compaction_dst`, `Makefile:~2159–2162`) is extended. The fixture's world is
seeded in-code (no catalogue file on disk): catalogue rows ride in `WorldState.files`
under the `catalog_path` the run resolves (precedent: `program_persistence_dst.ail:677`
seeds `/w/seed/catalog.json` as an `FsFile` with `{"context_limits":{...}}`; the
`long_qwen_compaction_dst.ail:332` shape). Concrete models — neighbour pair sharing
one catalogue row: `runtime-status-model` (absent → Unknown) and `runtime-status-neighbour`
(present → Bounded). Profile override rides in `WorldState.env` + `WorldState.files`
(`MOTOKO_PROFILE_DIR` → dir containing `config.json` with `agent.context_limit`).
Each arm drives the
`MotokoRuntimeStatus` builtin (`session.ail:2542–2546`) and parses the returned tool message,
plus independently asserts the per-run `ContextLimitResolved` record on the returned trace.

- **Arm A — `Unknown`:** model `runtime-status-model`, not in catalogue, no profile override. The
  `ContextLimitResolved` record names both misses (profile miss + catalogue miss); the
  status message's `context_limit_source` names them; the loop proceeds; three percentage
  fields in the status are `0`.
- **Arm B — `Bounded` neighbour:** model `runtime-status-neighbour`, catalogue row present
  (`{"context_limits":{"runtime-status-neighbour":<N>}}`, `N` a small positive such as 71
  per the `program_persistence_dst.ail:677` precedent), same history. Decisions and existing event payloads identical to HEAD under rule 4's
  projection (new `ContextLimitResolved` record projected out). The liveness witness.
- **Arm C — `Disabled` (or replacement control):** an explicit profile key
  (`agent.context_limit` in the seeded `config.json`; key name frozen when P1 starts —
  owner: whoever takes P1, recorded in the P1 kickoff; if the key needs a schema change
  it is deferred per Open Q3) sets `Disabled`.
  Same ABI int `0` as arm A, different reason in both witnesses. If `Disabled` is deferred,
  the replacement is two `Unknown` runs with different misses, same int, required to differ
  in both witnesses.

**Done when.** `scripts/dst/runtime_status_tool_dst.ail` passes three arms; per-run record
independently asserted; `make event_vocabulary` passes at 35 variants; `make anchors` +
`make attribution_table` + three profile targets all pass; `make check_core` passes on
every modified `.ail` file; three contract candidates registered or reason recorded.

**Do not:**
- Conflate raw checkpoint denominator with net seal budget (cF7).
- Emit `ContextLimitResolved` only on follow-up turns (cF8).
- Unify `raw_window_of` and `working_budget_for_ext` — that changes pre-step behaviour
  under `Bounded`.
- Delete the WI-D4 comment — it records why the four sites read a stored value.
- Claim D1 is wire-schema-neutral: the new event and the status field change the returned
  trace (cF8).
- Reintroduce per-adapter increments (kF1).
- Adopt a same-record high-water mark (kF1).
- Use `Unknown`'s reason as `ProfileConfigAbsent` when the catalogue then succeeded (cF8).

---
### P2 — D2: world ordinal, witnessed onto the wire, checked per framed run (~6–9 days after inventory and D6)

**Dependencies.** D6; P-INV's landed inventory and call graph (§2.1);
D1's `context_limit.ail` for the leaf module pattern and its `ContextLimitResolved` event
in the per-run entry. Does not wait on D3. P2 starts only after P1's per-run entry
(`session.ail:2994`) exists, since `ContextLimitResolved` is the ordering precedent
`witness` follows.

**Six parts (ADR specification).**

#### Part 1 — one pure writer

`WorldState` gains two fields: `ordinal: int` and `pending: [RequestWitness]`. Pending is
bounded by construction: `advance` pushes exactly one witness per helped leaf, and
`witness` drains the whole queue in order and clears it, so `pending` is non-empty only
between a helped leaf and its witness on the same path. Production rule: no traced
entry returns, and no frame prints `END`, with `pending` non-empty — a non-empty
`pending` at a frame boundary is a gate red (dropped witness), not a silent drain.
`RequestWitness = { ordinal: int, class: RequestClass }`. `RequestClass` is a closed
enum fixed by P-INV's landed inventory — one variant per helped leaf kind, namely
`EnvRead`, `FileRead`, `ClockRead`, `ToolExec`, `ModelStep` (names frozen at P-INV;
if P-INV finds an additional helped kind, the enum gains a variant and Part 4's
vocabulary projection covers it). The exempt ten `ExtPorts` forwarding fields never
construct a `RequestClass` value — exemption is structural (extension-initiated),
not a sixth variant. A pure `advance(w, class)` in a
leaf module (imports `ports` only) is the **only** writer of both: returns the successor with
`ordinal + 1` and the witness pushed.

Every helped leaf calls `advance` on the successor the port returned, including:
- The eight reads inside `context_usage` (their `{Env}`/`{Env, FS}` rows are unchanged —
  `advance` is pure).
- The three in `tool_phase` (`:413`, `:414`, `:421`).
- `:2730` (the non-retryable provider-error env read) and `:3385` (the exit publish).
- `dispatch_step`'s leaf in `stub_step.ail:705–713`.

The three full `WorldState` literals (`ports.ail:725`, `ext_world.ail:544`, `:651`) gain the
fields. `world_json`/`world_of_json` carry both (intent: extend the codec — program bytes
change, so the manifest version moves per §2.2; if that counts as program schema under
011 WI-1, its three-commit route applies); a nonzero round-trip fixture followed by a
helped request proves the codec does not reset them.

#### Part 2 — one effectful witness, in `session.ail`

`witness(session_id, trace, w) -> { trace, world } ! {IO, Trace}` drains `pending` in order:
for each record it calls `ledger_emit(session_id, WorldRequest({ ordinal, class }))` — the
wire — **and** `ledger_append(trace, WireRecord(…))` — the returned trace — then clears
`pending`. Lives in `session.ail` because `ledger_emit` is private there and stays so.

Called at every site where a successor *arrives in* `session.ail`: immediately after a
helped leaf, and on receipt from `tool_phase`, `context_usage`, the resolvers and
`dispatch_step` — always **before** the successor enters any driver record.

**Bootstrap.** `session_policy_init` (`session.ail:1923–1925`), `derive_session_id` (`:1419`)
and the initial clock read (`:3015–3016`, `:3044`) run before `C2LoopState` exists. Their
successors carry pending witnesses; the entry chain calls `witness` with
`empty_ledger_trace()` and seeds `c2_initial_state_with_counts` (`:709–730`) with the
resulting trace instead of an empty one.

**Tool phase.** Its three leaves `advance`; the `RunTools` arm (`session.ail:2495–2590`)
witnesses the returned world on receipt.

#### Part 3 — the gate: per-run frames on the stdout wire

Each traced invocation in a DST script is framed by two labelled lines the *script* prints:
`WORLD_RUN_BEGIN <label> <ordinal0>` before the entry call and `WORLD_RUN_END <label>
<final>` after (from `run.world.ordinal`, not from `DstResult`). The script refuses to
print `END` if `run.world.pending` is non-empty.

A new shell gate `scripts/dst/run_world_framed_wire.sh`, written on the
`scripts/dst/run_ledger_parity_wire.sh` pattern (not a modification of it — the
parity gate keeps its own target), with a new Makefile target `make world_framed_wire`
wired into the DST sweep. It partitions the JSON
wire lines by frame and asserts per frame:
- Exactly one `END` per `BEGIN` and the expected frame count.
- Every `world_request` line inside a frame.
- Ordinals exactly `ordinal0+1, ordinal0+2, …` (**strict +1** — exempt requests do not advance).
- Last == `final`.

Red on: a repeated or backward ordinal (stale-world re-request), a gap (leaf advanced but
not witnessed on that path, or unhelped leaf), a final mismatch (drop after last witness),
a `world_request` outside any frame, or a missing/duplicated/truncated marker. Precedent
for the labelled line: `LEDGER_TRACE` in `ledger_parity_dst.ail:330`.

**Acceptance cases:**
- **Whole-record drop** — the `st`-instead-of-`post` bug at the approval site
  (`session.ail:2456–2465`) produces a repeated ordinal → gate red.
- **Missing end marker** — the script exits before printing `WORLD_RUN_END` → red.
- **Dropped last request** — `witness` not called after the last helped leaf; final
  ordinal mismatch → red.
- **Two honest runs sharing `session_id`** — equal ordinals, different frames → both green.

#### Part 4 — classification and artifacts

`WorldRequest` is logical per §2.2. Artifacts as listed there: vocabulary row, projection,
golden, version bump (34→36 once both D1 and D2 land); Row 7 witness as a new required row
in `ledger_parity_dst.ail`. No gap-register entry (always appended). Trajectory key,
strict replay and discovery determinism are unchanged.

#### Part 5 — terminal ordering and the two production drops, shown red before fix

**(a) Exit.** `publish_turn_exit_manifest` moves **before** `c2_finalize`'s clock read
and `RunSummary` (`session.ail:2368–2374`), takes the loop's world, advances at its env
read (`:3385`), and returns `{ world, trace }`. `exit_manifest.publish_exit_manifest`
(`src/core/ext/exit_manifest.ail:182–205`) returns the rendered world instead of a `bool`.
Its only direct caller is `publish_turn_exit_manifest` (`session.ail:3362`, call at `:3409`;
the three `publish_turn_exit_manifest` call sites `:2372`/`:3294`/`:3479` inherit the new
return shape through it — no other caller to update).
`c2_finalize` takes that world; `RunSummary` stays last and publication stays before
`done`. **Red first:** instrument the read, leave the discards, run — the frame's `final`
is behind the last witness.

**(b) Provider error.** The `:2730` read (`session.ail:2730`) advances and is witnessed,
and its successor (not `exchange.next_state`) feeds the terminal call at `:2759`. **Red
first** the same way.

**Out of reach and recorded:** `:3265` (no deterministic run enters the stdin loop) and the
live-loop publish calls at `:3294`/`:3479`, which are separately framed lifecycle operations
(see Non-goals).

#### Part 6 — the pin (derivation script, §2.1)

Already specified in §2.1. This is D2's first deliverable. Run it after every edit; it must
stay green or the ADR is amended per its fallback rule.

**Gates.** `make world_state`, `make strict_replay`, `make program_persistence`,
`make event_vocabulary`, `make ledger_parity`, the new `make world_framed_wire` gate
and the derivation
script.

**Done when.** Inventory script passes four fixtures; all six gates pass —
`make event_vocabulary` at 36 variants (35 after D1, 36 once D2's row lands); the two production
sites are shown red then green; `make check_core` passes on every modified `.ail` file.

**Do not:**
- Derive a total census by subtracting `ordinal - List.length(log)` (cF2).
- Claim `hook_guard` checks successors — it decides dispatch before the call (cF2).
- Use `RunSummary` or `done` as the frame boundary (cF1).
- Claim the gate uniquely diagnoses a dropped successor — it localizes an inconsistent
  sequence in a framed run; fixtures distinguish a drop from a codec reset or double
  emission.
- Present display-only as a cheaper classification alternative — it is illegal under the
  current observation contract (cF4).
- Delete the WI-D4 comment — an ordinal says nothing about stored-versus-fresh policy
  equivalence (kF1).
- Claim "moves every replay digest" — the trajectory key hashes interactions only (cF4).

---
## Optional items

These are stated as optional by the ADR (D7 table). Neither is required for acceptance.

### O1 — standing one-of-forty aggregator

NOTE-002 §8 records the `dst_run_report.ail` counts class reach, not classification basis.
DRAFT §8's one-of-forty aggregator is "a documented one-shot fold, NOT a standing
instrument." If completed, this becomes a DST target gated by the inventory from §2.1. No
estimate; no dependency; not required for P0–P2.

### O2 — `driver_only` coverage-statement register defect

NOTE-002 §8 records `dst_driver_only.ail:29` reads "the basis now is D5's coverage
criterion read directly", which is about basis, not the statement. Whether the register
defect is closed is unverified. If not closed, a fix is a one-line correction. No estimate;
no dependency; not required for P0–P2.

---

## Non-goals

This PLAN does **not** cover:

- **D4** (commands + interpreter). Lives in `../028_verified_runtime_closing_the_loop/PLAN-002`
  as a phase after its items 2–3, with two pilot gates named in the ADR. 013 keeps the
  design record.
- **D5** (lifecycle at both ends). No plan until D4's pilot has landed or the next ABI
  major is scheduled. The per-class trigger is decided in the ADR.
- **§2.A** defunctionalization. A spike document first: vocabulary (Q1), corpus migration
  under 011 WI-1's route (Q2), consumer list without the shrinking claim.
- **§2.C** generic profile runner. Revisit after D4's pilot.
- **`WorldM`** (§2.B2). Dropped per ADR D7.
- **Behaviour under `Unknown`** beyond loudness — whether the measurement boundary should
  ever be blocking in 028 ADR-001's sense. Needs an owner's number (ADR Not decided).
- **TUI rendering of unmeasured percentages.** A TypeScript follow-up (ADR Not decided).
- **World-threading the multi-turn loop** (`session.ail:3265`) and framing the live-loop
  publish calls (`:3294`, `:3479`). Named in the ADR, not scheduled.

---

## Open questions

1. **State of `make dst` at HEAD — resolved 2026-09-05, disposition recommended.** One red at `3fe71b0`, a stale yield
   pin in `tools/ext_ambient_inventory/fixtures/expected.json` (§1 table). Recommended disposition:
   re-pin to 18 and re-run the target alone (stale pin, not a behavioural regression);
   list in `DST_KNOWN_RED` only if the re-pin fails. Record the closing commit hash in §1
   when done. Either closes
   D6 for D1 and D2.

2. **ADR's `context_usage` leaf count versus the tree.** The ADR says eight leaves behind
   `ContextReader` closures. The tree has five functions (`config_context_limit_override`,
   `catalog_context_limit_for`, `profile_dir_path`, `catalog_path`, `resolve_context_limit`)
   that together make up to eight env + file requests, but the exact count is data-dependent
   (an explicit `MOTOKO_PROFILE_DIR` short-circuits some env reads —
   `context_usage.ail:160–163`). The inventory script (§2.1) settles the actual leaf count.

3. **`Disabled` profile key.** The ADR says `Disabled` is never inferred and requires an
   explicit profile key. Key name frozen when P1 starts — owner: whoever takes P1,
   recorded in the P1 kickoff (default: `agent.context_limit` sentinel in the seeded
   `config.json`; see P1 acceptance). If it cannot be added without a schema change,
   it is deferred and arm C's replacement control (two `Unknown` runs with different misses)
   stands in per the ADR's risk 1.

4. **Whether the derivation script (§2.1) can be built reliably.** The `keep_interpolations`
   class of parser defect (learning §7) affects string-literal handling in AILANG source
   scanning. If the script cannot distinguish a comment mention of a port call from a real
   one, the ADR's fallback (restricted coverage claim) applies.

5. **Whether the partially shipped replay-contract registry expresses any DRAFT §5.2 prose
   contract.** The 012 evaluation entry (P0 step 4) answers this.

6. **Whether sponsoring handlers upstream is faster than §2.A + §2.D in userland.** Not
   answerable until D3 has a reply.

7. **Whether the `driver_only` coverage-statement register defect (O2) is still open.**
   NOTE-002 §8 could not verify this. A one-line check settles it.

---

## Cross-references

- The ADR: `ADR-001-sequencing-the-dst-architecture-caps.md` v3.
- The two reviews: `REVIEW-adr001-verdicts.md` (kF1–kF11) and
  `REVIEW-adr001-v2-verdicts-codex.md` (cF1–cF13).
- Measurements: `NOTE-002-re-read-2026-09-05.md` §1–§4.
- Style exemplars: `../027_z3_contracts/PLAN-z3-contract-adoption.md` and
  `../011_improve_test_axises/PLAN-resource-growth-relation.md`.
- The three-arm shape: `NOTE-issue-165-dst-architecture-findings.md` §8.
- The decoy rule: `.agent/learnings/2026-09-05-mocked-seams-and-overclaiming-prose.md` §5.
- The wire's implementation: `session.ail:222–228, :280–288, :335–342`; the parity wrapper
  `scripts/dst/run_ledger_parity_wire.sh`; the labelled-line precedent
  `ledger_parity_dst.ail:330`.
- The anchor cascade: `tools/predicate-anchors/anchors.sh` (derived-width rule and
  six-file form ~:281–353; session.ail checks at :384–385).
- The exit manifest: `src/core/ext/exit_manifest.ail:182–205`.
