# Plan: implement the ADR-002 compaction DST scenarios

Date: 2026-07-06
Implements: `001_DST/ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md`
Branch: `arniwesth/mot-27-phased-core-architecture`
Toolchain pin: AILANG **v0.26.0** (`3b52a24`) — verify `ailang --version` before starting.
Grounding HEAD: **`03b63c7`** ("Rerveiw of ADR"). Re-verify the Anchor Log below if commits have
landed on `packages/motoko-ext-compaction-structural/`, `src/core/phase_vocab.ail`,
`src/core/context_usage.ail`, or `scripts/phase_c_l1_scenarios.ail`.

---

## Goal

Land the five "now" scenarios from ADR-002 §4 (Decision detail 4) plus its precondition:

1. `compaction.segment_excludes_system_prefix` — core-only, `{IO}`.
2. `compaction.estimate_tier_ladder` — policy, `{IO}`, imports the compaction pkg.
3. `compaction.tool_shape_preserved_by_elision` — policy, `{IO}`.
4. `compaction.emergency_recovery_or_defer` — policy, `{IO}`.
5. `compaction.catalog_limit_qwen` — catalog binding, `{IO, Env, FS}`.

Each targets the **live** hook `compact_for_pre_step` (not the off-path `compact_step_with_limit`),
asserts against **imported** tier constants (no hardcoded thresholds), and reports scenario id +
first failed invariant on failure. The three gated scenarios (`actual_tokens_*`,
`summarizer_uses_agent_model`) are **not** implemented here — they are blocked on ABI v3
`ExtCtx.telemetry` + a fake `ai_step` port (ADR-002 §4 gated list).

## Out of scope (do not touch here)

- The three **gated** scenarios and anything ABI v3 (`ExtCtx.telemetry`, the fake `ai_step` port,
  re-homing the 60/75/85 actual tiers). ADR-002 §Out-of-scope.
- The **#76 harness-boundary / env-manifest** work (`NOTE-harness-spawn-boundary-in-core-…`,
  `004/NOTE-env-manifest-…`). Separate track; independent of this plan.
- Extracting the `phase_c_l1` harness helpers into a shared module. Noted as an optional future
  consolidation (D-P2); this plan re-declares the ~40 trivial lines instead of refactoring a green
  file.
- Any edit to ADR-002, ADR-001, or the research draft.

## TL;DR — harness layout (D-P1)

Three files, matching ADR-002's cap/dependency distinctions exactly:

| Scenario(s) | File | Effect row / run caps | Imports pkg? |
|---|---|---|---|
| `segment_excludes_system_prefix` | **extend** `scripts/phase_c_l1_scenarios.ail` | `{IO}` / `--caps IO` | no (keeps the core-only gate hydration-free) |
| the 3 policy scenarios | **new** `scripts/compaction_policy_dst.ail` | `{IO}` / `--caps IO` | yes (isolates the pkg dependency, finding 6) |
| `catalog_limit_qwen` | **new** `scripts/compaction_catalog_dst.ail` | `{IO, Env, FS}` / `--caps IO,Env,FS` | no |

This keeps `phase_c_l1` core-only (its value as a hydration-free gate), quarantines the extension-pkg
dependency to one file, and honors that the catalog scenario has a wider effect row than pure `{IO}`.

## Plan-level decisions

- **D-P1 — three files (above).** Rationale in the TL;DR. The alternative (put everything in
  `phase_c_l1`) would make the whole L1 gate pkg-dependent and cannot host the `{Env, FS}` catalog
  scenario under its `main() -> () ! {IO}` anyway.
- **D-P2 — re-declare the minimal harness in the new files.** `phase_c_l1` exports only
  `ScenarioFailure`/`Scenario` (types), not `run_all`/`run_one`/`ok_or_failure`/`msg` (plain `func`).
  The two new files re-declare those ~40 lines (`print_trace`, `run_one`, `run_all`, `ok_or_failure`,
  and local `msg`/`tool` builders). A shared `scripts/dst_harness.ail` module is a nice future
  consolidation but out of scope — it would perturb the green `phase_c_l1` imports.
- **D-P3 — the policy scenarios use ABI types (compile-verified this session via a throwaway probe).**
  `compact_for_pre_step` takes `(ctx: ExtCtx, msgs: [Msg])` and returns `PreStepDecision`. Import
  `ExtCtx, Msg, PreStepDecision, PassThrough, Compacted` from `pkg/sunholo/motoko_ext_abi/types` (the
  same origins the extension uses); import `ToolCall` from `std/ai` (needed to build an assistant
  `tool_calls` fixture in scenario 2). `Msg` is `{ role, content, tool_calls: [ToolCall], tool_call_id }`
  — build it locally; the pkg's own `tool`/`user`/`ctx` helpers are unexported. **Use the clean
  13-field `ExtCtx` literal in WI-2 below** (verified to check + run) — do **not** copy the pkg's
  test-helper literal at `compaction_structural.ail:197-211` verbatim: it lists `context_limit`
  *twice* (a source quirk AILANG tolerates); the type has one `context_limit`.
- **D-P4 — assert structurally against imported constants; small tractable limit; mind the elide
  threshold.** The tier scenario injects a **small** `ctx.context_limit` (fixtures cross the bands
  cheaply, per `smoke_v2_compaction_tiers.ail`'s target-percent helpers) with `model:
  "ollama/qwen3.6:35b-a3b-mxfp8"` as a label only — the tiers are qwen-agnostic (ADR-002 D2).
  Assertions count preserved recent tool messages against `elide_keep_last()` /
  `elide_hard_keep_last()` etc.; **do not** sniff the `structural_note` string, and **do not** hardcode
  70/85/95. **Two traps** to observe a `Compacted` (else `compact_for_pre_step` returns `PassThrough`
  via its `same_msgs` guard): (a) you need **more tool messages than the tier's keep-last**; and (b)
  **`elide_content` is a no-op for content ≤ 80 chars** (`compaction_structural.ail:42-49`) — the
  older, elidable tool messages must carry **long content** (use a ~200-char `long_tool_content()`
  string, as the pkg's own tests do) or elision changes nothing and the decision is `PassThrough`.
  Size the limit so total usage lands in the target band *given* that long content (a ~250–300 limit
  with ≥11 long tool messages puts you in tier-1; scale up for hard/emergency).
- **D-P5 — the catalog scenario depends on the catalog file.** `catalog_context_limit_for` reads
  `.motoko/model-catalog.json` (or `$MOTOKO_MODELS_FILE` / `$MOTOKO_REPO/.motoko/model-catalog.json`).
  The scenario asserts `== 262144` for `"ollama/qwen3.6:35b-a3b-mxfp8"`; it is the only place the
  `262144` literal appears in the DST code.

---

## Work breakdown

Baseline to establish first (all green expected at HEAD): `ailang run --caps IO --entry main
scripts/phase_c_l1_scenarios.ail` → 12 PASS; `ailang check
src/core/test/integration_tests.ail` → clean (proves the pkg resolves).

### WI-0 — precondition: fix the red catalog smoke

**Purpose.** ADR-002 Preconditions: do not add DST on top of a red smoke.
`scripts/smoke_catalog_compaction.ail` fails to check — it imports `compact_step_with_limit` from
`src/core/compaction`, which no longer defines it.

**Change (pick one).**
- **Repoint** the import to the pkg:
  `import pkg/sunholo/motoko_ext_compaction_structural/compaction_structural (compact_step_with_limit)`
  (the function lives there, `:90`), keeping the catalog→compaction smoke alive; **or**
- **Retire** the file if it duplicates `smoke_v2_compaction_tiers.ail` with no unique coverage.

**Verification.**
```
ailang check scripts/smoke_catalog_compaction.ail    # green (or file removed)
```
**Rollback.** `git checkout scripts/smoke_catalog_compaction.ail`.

### WI-1 — `segment_excludes_system_prefix` (core-only) in `phase_c_l1_scenarios.ail`

**Purpose.** Guard the construction invariant that any compactor can only ever receive non-system
messages, at the seam that enforces it (`split_for_compaction`), not the hook in isolation
(ADR-002 §4 / de-dup map).

**File-level changes (`scripts/phase_c_l1_scenarios.ail`; `split_for_compaction`/`segment_messages`
are already imported at `:32`/`:29`).**
- Add the scenario func (near the other `scenario_*` funcs):
  ```
  func no_system_in(msgs: [Message]) -> bool {
    match msgs {
      [] => true,
      m :: rest => if m.role == "system" then false else no_system_in(rest)
    }
  }
  func scenario_segment_excludes_system_prefix() -> Result[(), ScenarioFailure] {
    let split = split_for_compaction([msg("system", "s1"), msg("system", "s2"), msg("user", "u"), msg("assistant", "a")]);
    let seg = segment_messages(split.segment);
    let pinned_ok = length(split.pinned) == 2;   -- the two-message system prefix is pinned out
    ok_or_failure(no_system_in(seg) && pinned_ok, "compactable segment excludes the system prefix",
      ["segment_had_system_or_bad_pin"])   -- plain marker; harness already prints scenario id + invariant
  }
  ```
  (Keep the trace line simple — a plain `"segment_had_system"` marker on failure is enough; the
  harness prints `scenario=… invariant=…`.)
- Add the builder + register in `main`'s list (mirror the existing `_scenario()` funcs at `:88`,
  `:367-407`, and the `scenarios` list in `main`):
  ```
  func segment_excludes_system_prefix_scenario() -> Scenario {
    { id: "segment_excludes_system_prefix", run: scenario_segment_excludes_system_prefix }
  }
  ```

**Verification.**
```
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # 13 PASS
```
**Teeth check.** Temporarily feed the scenario a split built from a single `[msg("user","u")]` and
assert `length(split.pinned)==2` still holds → it must FAIL (pinned is empty), proving the assertion
bites; revert.
**Rollback.** Remove the scenario func, builder, and `main` registration.

### WI-2 — the three policy scenarios in new `scripts/compaction_policy_dst.ail`

**Purpose.** The fast, pure, `--caps IO` tier-decision-granularity layer over the live hook
`compact_for_pre_step` (ADR-002 §4 policy list; complements the Layer-2 `smoke_v2_compaction_full_loop`).

**New file skeleton.**
```
module scripts/compaction_policy_dst

import std/io (println)
import std/list (length)
import std/result (Result, Ok, Err)
import std/ai (ToolCall)
import pkg/sunholo/motoko_ext_abi/types (ExtCtx, Msg, PreStepDecision, PassThrough, Compacted)
import pkg/sunholo/motoko_ext_compaction_structural/compaction_structural (
  compact_for_pre_step, elide_old_tool_results,
  elide_tier_pct, elide_hard_tier_pct, emergency_pct,
  elide_keep_last, elide_hard_keep_last, emergency_keep_last, emergency_final_keep_last
)

-- re-declared minimal harness (D-P2): ScenarioFailure, Scenario, print_trace, run_one, run_all,
-- ok_or_failure  — copy verbatim from phase_c_l1_scenarios.ail:40-82,114-117.

func tool(id: string, content: string) -> Msg { { role: "tool", content: content, tool_calls: [], tool_call_id: id } }
func user(content: string) -> Msg { { role: "user", content: content, tool_calls: [], tool_call_id: "" } }
-- long content so elide_content actually shortens (≤80 chars is a no-op — D-P4):
func long_content() -> string { "long tool output that genuinely exceeds eighty characters and keeps going well past the elide threshold so shortening actually happens and the decision becomes Compacted not PassThrough" }

-- ctx with an injected small limit. This clean 13-field literal is compile+run verified
-- (do NOT replicate the pkg helper's duplicate context_limit at :197-211).
func ctx(limit: int) -> ExtCtx { { task: "t", step: 0, model: "ollama/qwen3.6:35b-a3b-mxfp8", context_limit: limit, cwd: ".", hybrid_tools: false, budget: { total: 1, solver: 1, verifier: 0 }, mode: "default", workdir: ".", env_server_url: "", budget_remaining: 1, history_slice: [], state_key: "k" } }
```

**Scenario 1 — `estimate_tier_ladder`.** Build fixtures crossing each band against a small
`ctx(limit)`. Per D-P4 you need **> keep-last** tool messages **with long (>80-char) content** in the
elidable positions, or elision is a no-op and you get `PassThrough`. Mirror
`smoke_v2_compaction_tiers.ail`'s target-percent sizing. Assert:
```
-- count tool messages whose content is unshortened == the tier's keep-last
func kept(msgs: [Msg], full: int) -> int { ... count tool msgs with length(content) == full ... }
-- below elide_tier_pct(): PassThrough
-- in [elide_tier_pct(), elide_hard_tier_pct()): Compacted(m,_) with kept(m,·)==elide_keep_last()
-- in [elide_hard_tier_pct(), emergency_pct()): kept==elide_hard_keep_last()
-- >= emergency_pct(): Compacted with kept==emergency_keep_last() (or emergency_final_keep_last())
```
Match on `PreStepDecision`; assert the counts against the **imported** constants.

**Scenario 2 — `tool_shape_preserved_by_elision`.** Over `elide_old_tool_results(msgs, keep_last)`
directly: `length` preserved; order preserved; every `tool_call_id` preserved; non-tool messages
untouched (byte-identical `content`); the last `keep_last` tool messages preserved verbatim. Use a
mix of assistant(+tool_calls)/user/tool messages.

**Scenario 3 — `emergency_recovery_or_defer`.** At `>= emergency_pct()`:
- **recovery:** a tool-heavy fixture ⇒ `compact_for_pre_step` returns `Compacted` (keep-last 3, then
  1) — assert the result differs from input.
- **defer:** a fixture whose non-tool content alone keeps usage `>= emergency_pct()` ⇒ `PassThrough`
  (elision can't touch non-tool content). Assert `PassThrough`; note the exhaustion itself is core
  `seal` (covered by `oversized_payload_rejected`) — **not asserted here**.

**Builders + `main`.**
```
export func main() -> () ! {IO} {
  let scenarios = [ estimate_tier_ladder_scenario(), tool_shape_preserved_by_elision_scenario(), emergency_recovery_or_defer_scenario() ];
  let failed = run_all(scenarios, 0);
  if failed == 0 then println("compaction_policy_dst PASS count=${...}") else println("compaction_policy_dst FAIL failed=${...}")
}
```

**Verification.**
```
ailang check scripts/compaction_policy_dst.ail
ailang run --caps IO --entry main scripts/compaction_policy_dst.ail    # 3 PASS
# constants are imported and referenced in assertions (positive check):
grep -nE 'elide_tier_pct|elide_hard_tier_pct|emergency_pct|elide_keep_last|elide_hard_keep_last|emergency_keep_last|emergency_final_keep_last' scripts/compaction_policy_dst.ail
# and no bare tier PERCENT literal is used in a comparison (70/85/95 may only appear in a limit/size, not `>= 70`):
grep -nE '(>=|>|==|<)\s*(70|85|95)\b' scripts/compaction_policy_dst.ail || echo "good: no hardcoded threshold comparison"
```
**Teeth check (per scenario).** Flip one assertion's expected constant (e.g. `elide_keep_last()` →
`elide_hard_keep_last()`) → the scenario must FAIL naming its id + invariant; revert.
**Rollback.** Delete the file.

### WI-3 — `catalog_limit_qwen` in new `scripts/compaction_catalog_dst.ail`

**Purpose.** Guard the `qwen → 262144` catalog binding in exactly one place (ADR-002 D2).

**New file.**
```
module scripts/compaction_catalog_dst
import std/io (println)
import src/core/context_usage (catalog_context_limit_for)
export func main() -> () ! {IO, Env, FS} {
  let n = catalog_context_limit_for("ollama/qwen3.6:35b-a3b-mxfp8");
  if n == 262144 then println("scenario=catalog_limit_qwen ok")
  else { let _ = println("scenario=catalog_limit_qwen invariant=qwen maps to 262144 actual=${show(n)}"); println("compaction_catalog_dst FAIL") }
}
```
(Optionally wrap in the same `Scenario`/`run_all` shape for reporting parity; a single scenario makes
the inline form acceptable.)

**Verification.**
```
ailang check scripts/compaction_catalog_dst.ail
ailang run --caps IO,Env,FS --entry main scripts/compaction_catalog_dst.ail   # ok
```
Confirm `.motoko/model-catalog.json:43` is the source; if the run can't find the catalog, set
`MOTOKO_MODELS_FILE` or run from repo root.
**Rollback.** Delete the file.

### WI-4 — wire the new scenarios into the build gate

**Purpose.** Without this the two new scripts never run in CI and guard nothing. WI-1's scenario
already rides the existing `phase_c_l1:` target (`Makefile:53-54`, runs
`scripts/phase_c_l1_scenarios.ail` under `--caps IO`); the two **new** files are wired into nothing.

**Change (`Makefile`).** Add a `compaction_dst` target and make it reachable from the same gate that
runs `phase_c_l1` (and, if CI runs `test`, chain it there — note `test: test_core` does **not**
currently include `phase_c_l1`, so confirm what CI actually invokes):
```
compaction_dst:
	ailang run --caps IO --entry main scripts/compaction_policy_dst.ail
	ailang run --caps IO,Env,FS --entry main scripts/compaction_catalog_dst.ail
```
Prefer extending the existing `phase_c_l1` target to also invoke `compaction_dst` (or list it as a
prerequisite) so the L1 compaction DST travels with the rest of the L1 gate. (001_DST/ADR-001's
`make test_dst` naming is aspirational — reuse the live `phase_c_l1` gate rather than inventing an
unreferenced target.)

**Verification.** `make compaction_dst` (or `make phase_c_l1` if chained) runs green.
**Rollback.** Remove the target / prerequisite.

### WI-5 — acceptance gate (maps to ADR-002 §Acceptance criteria)

```
# crit 1: four pure scenarios green under --caps IO
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail        # 13 PASS (incl. segment_…)
ailang run --caps IO --entry main scripts/compaction_policy_dst.ail       # 3 PASS
# crit 1: catalog under wider caps
ailang run --caps IO,Env,FS --entry main scripts/compaction_catalog_dst.ail   # ok
# crit 2: constants imported & used (positive), and no bare threshold comparison
grep -nE 'elide_tier_pct|elide_hard_tier_pct|emergency_pct|elide_keep_last|elide_hard_keep_last|emergency_keep_last' scripts/compaction_policy_dst.ail
grep -nE '(>=|>|==|<)\s*(70|85|95)\b' scripts/compaction_policy_dst.ail || echo "good: no hardcoded threshold comparison"
# crit 3: scenarios target compact_for_pre_step, not compact_step_with_limit
grep -n 'compact_step_with_limit' scripts/compaction_policy_dst.ail || echo "good: none"
# crit 4: 262144 appears only in the catalog file
grep -rn '262144' scripts/compaction_policy_dst.ail scripts/phase_c_l1_scenarios.ail || echo "good: only in catalog file"
# crit 6: no mocking / providers / recorder
grep -nE 'run_v2|scripted_ports|dispatch_step|LiveAI|--caps (AI|Net)' scripts/compaction_policy_dst.ail scripts/compaction_catalog_dst.ail || echo "good: none"
# checks green
ailang check src/core/phase_vocab.ail && ailang check src/core/context_usage.ail
```
Manual: confirm the three gated scenarios remain **unregistered** in any `main` list (crit 5).

---

## Anchor re-verification log (HEAD `03b63c7`, v0.26.0 / `3b52a24`)

- Harness to extend: `scripts/phase_c_l1_scenarios.ail` — `ScenarioFailure`/`Scenario` `:40/:45`
  (exported), `print_trace/run_one/run_all` `:50-82`, `msg` `:92`, `ok_or_failure` `:114`, builders
  `:88,:367-407`, `main` scenarios list; imports `split_for_compaction:32`, `segment_messages:29`
  from `phase_vocab`.
- Core scaffold: `PinnedSplit = { pinned, segment }` `phase_vocab.ail:117`; `split_for_compaction:130`
  (`pinned = take_system_prefix`, `segment = MkSegment(take_non_system_tail)`); `segment_messages:134`.
- Extension: `packages/motoko-ext-compaction-structural/compaction_structural.ail` — imports
  `ExtCtx, Msg, PreStepDecision, PassThrough, Compacted` from `pkg/sunholo/motoko_ext_abi/types`
  (`:6-12`); constants `:14/:16/:18/:20/:22/:24/:26`; `elide_old_tool_results:72`;
  `compact_for_pre_step:117` (pure, `PreStepDecision`, no exhaustion `Err`); ctx literal shape to copy
  `:197-211`. Off-path (do not target): `compact_step_with_limit:90`.
- `Msg` shape: `src/core/types.ail:16` `{ role, content, tool_calls: [ToolCall], tool_call_id }`;
  `PreStepDecision = PassThrough | Compacted(msgs, note)` mirror `src/core/ext/types.ail:67-70`.
- Catalog: `catalog_context_limit_for:50` in `src/core/context_usage.ail` (`{Env, FS}`);
  `.motoko/model-catalog.json:43` → `"ollama/qwen3.6:35b-a3b-mxfp8": 262144`.
- Red precondition smoke: `scripts/smoke_catalog_compaction.ail` (imports absent
  `compact_step_with_limit` from `src/core/compaction`).
- Fixture-generation reference: `scripts/smoke_v2_compaction_tiers.ail` (target-percent message
  builders against a limit).
