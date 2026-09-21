# P1.2a — batch A onto ABI 8.0 (evidence)

PLAN-001 (031) §3 P1.2, batch A (calibration): `compaction-structural`, `decision-framework`,
`empty-stop-guard`, `microrag`, `omnigraph`, `progress-contract-guard` — **9 sites, 1 capture**.
Plus the masked files the operator assigned to batch A (§3 P1.2, `68791469`):
`scripts/dst/compaction_policy_dst.ail`, `scripts/dst/compaction_seeded_dst.ail`,
`scripts/smoke_v2_compaction_full_loop.ail`, `scripts/dst/phase_c2_wiring_scenarios.ail`,
`src/core/test/integration_tests.ail`. HEAD before: `031c0f16`. AILANG v0.33.0.

## The 9 sites

| # (Q-1) | site | 7.4 form | 8.0 |
|---:|---|:---:|---|
| 9 | compaction-structural `Compactor` | N | `Compactor(pre_step)`, `pre_step(ctx: AiCtx, …)` |
| 18 | decision-framework `PromptShaper` | N | `conditional_prompt_patch(ctx: PureCtx)` |
| 19 | empty-stop-guard `SolverJudge` | N | `finalize(ctx: ProcessCtx, …)` |
| 29 | microrag `DescribeTools` | N | `microrag_describe_tools(_cfg: Json)` |
| 30 | microrag `ToolPolicy` | N | `microrag_tool_policy(_ctx: PureCtx, …)` |
| 31 | microrag `ToolProvider` | N | `microrag_tool_handle(ctx: ProviderCtx, …)`, row `+Trace` |
| 32 | omnigraph `PromptShaper` | **I**, captures `cached_prompt` | named `omnigraph_prompt(ctx: PureCtx)`; the prompt goes through `config` |
| 33 | omnigraph `ToolPolicy` | N | `on_tool_policy(_ctx: PureCtx, …)` |
| 34 | omnigraph `ToolProvider` | **I** | named `omnigraph_tool_handle(ctx: ProviderCtx, …)` in `register.ail` (see below) |
| 35 | progress-contract-guard `SolverJudge` | **I** | named `finalize(ctx: ProcessCtx, …)` |

Every `register_with_config` returns `ExtRegistration = { config, caps }` with a literal `caps`.
`config` is `jo([])` for five packages. For omnigraph it is `{"cached_prompt": <text>}`, encoded once
(`prompts.prompt_config`) and decoded per call (`prompts.cached_prompt_of`). The workdir is read at
registration, as before, and **not** disclosed (names, not values). Nothing else is captured.

## Choices, with reasons

- **Helper contexts.** The guards' `decide*` helpers read data only and are called only from the
  judge, whose view is `ProcessCtx` (no ports; `world` kept). So they take `ProcessCtx`, and their
  tests build it with `process_ctx({ pure_ctx(jo([])) | … }, empty_ext_world())`. The ten-port no-op
  stub blocks the tests carried are deleted, not narrowed. `compact_for_pre_step` reads data only
  (`context_limit`, `telemetry`, `artifacts`), but the Compactor's view `AiCtx` carries `ai_step`. So
  per the ADR's rule it takes **`PureCtx`**. `pre_step` projects its `AiCtx` with
  `pure_view` = `{ pure_ctx(ctx.ext_config) | …every data field… }` (constructor plus record update, the
  8.x rule's form). The ABI exports no view→`PureCtx` projection. Row-polymorphic parameters
  (`{ context_limit: int | r }`) do compile on the pin. They were **not** used, because the ADR names
  `PureCtx` or a ports record.
- **omnigraph's `ToolProvider`.** `on_tool_handle` declares `! {Process}`, and a closed row does not
  unify with the slot's row. That is why 7.4 wrapped it in an inline lambda. It is now a named wrapper
  that carries the slot row (with `Trace`).
- **The pin.** `ailang.toml` path dependencies carried no version. Each of the six now reads
  `{ path = "../motoko-ext-abi", version = "8.0" }`. The pin is enforced: a `7.4` pin fails
  `ailang lock` in the package (mutgate row `pin_8_0`). **It is not enforced transitively:** a root
  manifest that locks the package does not check the package's own pin, so `p12a_ws.sh check` locks
  each package by itself. The three tracked package locks were regenerated. They recorded ABI 4.0
  (two) and a registry 2.2.0 plus a `motoko_core` path (compaction-structural).
- **compaction-structural no longer depends on core.** Its test context was the only user of
  `src/core/ext/ctx_defaults` (no-op ports), reached through a `sunholo/motoko_core` path dependency
  on the git-ignored `.packages/motoko_core`, which a fresh clone does not have. The import and that
  dependency are removed.

## Exit checks (receipts in `CHECKS.log`)

1. `ailang check` clean on every module of the six packages, in place and in the workspace.
2. Own tests: compaction-structural 9 passed / 1 failed / 1 skipped. **The failure
   (`test_oversized_recent_tool_result_is_capped_under_pressure`) is pre-existing:** the same module at
   `181051d0` (P0.4's parent, ABI 7.4) gives the identical 9/1/1
   (`compaction_structural_test_at_74.log`). It is not touched here. decision-framework 2/2,
   empty-stop-guard 7/7, microrag 2/2, progress-contract-guard 20/20; omnigraph (no inline tests) boot
   smoke `_smoke.ail` OK, plus the configuration-channel probe `p12a_omnigraph_channel.ail` OK.
3. The gate: **shape pass 6 of 18, binding rejections 32** (inline-lambda 19→16, let-bound 16), head
   rejections 12. `make ext_hook_scope` as written **cannot reach the table** on this tree. It fails
   closed on the cache precondition while the other 12 extensions are 7.4 (the P0.5 / P0.6
   unreachable-exit class). The stand-in is `derive.py --hook-scope --no-provision`, the same
   registration-shape field, computed from text.
4. `integration_tests.ail`: checks clean in place; `ailang test` 3/3. No edit was needed; its only 8.0
   blocker was the 7.4 `compaction_structural` import.
5. Masked files: all five check clean **in the core workspace** (`p12a_core_check.sh`, which is P1.1's
   helper with the registry generated over batch A's six real packages) and run green: policy 3
   scenarios, seeded 5 seeds, full loop PASS, phase_c2 26 scenarios. **In place**,
   `integration_tests.ail`, `compaction_policy_dst.ail` and `compaction_seeded_dst.ail` check clean;
   `smoke_v2_compaction_full_loop.ail` and `phase_c2_wiring_scenarios.ail` still stop at 7.4
   `test_dummy` (batch B), reached through `src/core/ext/registry_generated.ail`, and cannot check in
   place until batches B–D land. The core workspace copies the **working tree's** `src/core`; P1.5r was
   editing `src/core/ext/runtime.ail` concurrently. One `CHECKS.log` pass, taken during that edit and
   the mutgate run, failed both `run` rows; a re-run passed, and the mutgate (HEAD's `src/core` plus
   only P1.2a's paths) is the clean record.
6. mutgate: `p12a_mutgate.sh --overlay` (a fresh clone of HEAD plus P1.2a's working-tree paths, under
   `/workspaces`, since `derive.py` refuses `/tmp`) → **19/19 discriminate**, bytes same
   (`mutgate-result.tsv`). The rows: six gate rows (one payload per package re-inlined → shape fail),
   the tree reading 6/18 · 32, omnigraph's shaper reading a module value (the channel probe on an empty
   config goes red), registration withholding the prompt, the `version = "8.0"` pin set back to `7.4`,
   the three repaired test contexts, the `AiCtx`→`PureCtx` projection through the real runtime, and
   one row per masked file. **The first run was 17/19 and was refused:** `integ_tests` (mutating
   `elide_tier_pct`) and `seeded_dst_ctx` (a huge `context_limit`) were **vacuous**. The tests assert
   the ≥95% exhaustion path and "below the elide tier passes through", and those mutations cannot break
   either. Both rows were re-aimed (`emergency_pct` 95→99; `context_limit` 1). The spec's comment
   records this.

## Files

`p12a_ws.sh` (packages: check / test / smoke / channel / gate / tree), `p12a_core_check.sh` (core
workspace), `p12a_omnigraph_channel.ail`, `p12a_mutgate_spec.tsv`, `p12a_mutgate.sh`,
`mutgate-result.tsv`, `CHECKS.log`, `compaction_structural_test_at_74.log`.
