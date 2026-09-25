# P1.6r-a2 — follow-up: the DST driver scripts onto ABI 8.0 (evidence)

PLAN-001 (031) line R. Brief `LEG-P1.6r-a2.md`. HEAD before: `6b66d244`. AILANG `v0.33.0`. Scope: `scripts/` only.
Files here: `TARGETS.log`, `make-dst-summary.txt`, `mutgate-result.tsv`, `p16ra2_mutgate_spec.tsv`.

## What was red, and the first real error in each

Nine files behind the nine targets. `depth_canary`'s file is `scripts/dst/export_trace.ail` (the canary runs it per
seed): it did not compile, so every seed "exited 1 without RT_REC_003". That was an unrelated failure, not a depth
result, and the canary's pins are unchanged. `park_wake`'s file is `park_wake_dst.ail`: its fixture literal lacked
`config`, so the in-process fixtures never ran.

## The changes (only what 8.0 requires; every assertion kept)

The P1.6r / batch D mechanical set:
- every `fixture_hooks` override record carries `config: jo([])` (all 8 fixture files);
- callbacks take their view: `PromptShaper`/`BudgetShaper`/`ToolPolicy` → `PureCtx`, `Compactor` → `AiCtx`,
  `ToolProvider` → `ProviderCtx` with row `+Trace`, `ResponseInterceptor` → `InterceptCtx`, `SolverJudge` → `ProcessCtx`;
- `DescribeTools` takes the config: `no_describe(_config: Json)`;
- the `std/json` imports gain `Json`/`jo` where needed.

**Compose entries** (`driver_plus_compose_dst`, `discovery_dst`'s `compose_rt`): `register_with_config` returns
`ExtRegistration { config, caps }` at 8.0. The entry is `{ id: "compose", config: reg.config, caps: reg.caps }`, the
shape `declared_vs_performed.ail` already uses.

**`discovery`'s "expected 9, got 10" was the literal.** `FixtureOverrides` (`src/core/test/ext_fixture.ail`) has 10
fields, including `config`. The 9-field side was `approval_overrides()`'s literal. The checker reports a
return-annotation mismatch with the literal as "expected", so the direction reads backwards. The type was current and
the literal was stale.

**`discovery`'s WI-D26 grep probe moved slot, from `ResponseInterceptor` to `ToolProvider`.** It calls compose's
real `dispatch_author_tool_with_globs`, which takes all of `ExtPorts`. At 8.0 an interceptor gets `InterceptPorts`
(no `ai_step`, no `env_get`). The only view that carries `ExtPorts` is `ProviderCtx`, and that is where compose
itself runs its author tools. The other option was `ExtPorts` padded with two dummy ports, which batch D ruled out.
The hook is now `grep_probe_handle`: it is gated on tool `"T"` under `allow_policy`, like the batch scenario, and the
world's script is `tool_step("T", …)` then `prose_step("done")`. It answers `Handled`, so no native dispatch runs.
The verdict still leaves the hook only through the recorded `file_write`. All three rows are unchanged and green,
with `verdict=SCANNED (expect_extension_effect=1)`. The row is not vacuous: the routed search ran and reached the
recorder.

## Exit checks

1. **The 9 targets are green** in the primary checkout at `6b66d244` plus these paths (`TARGETS.log`).
2. **`make dst DST_JOBS=1`**, run alone: **all targets passed, 1076 s wall, -j1, 0 NEW reds**
   (`make-dst-summary.txt`). Both register entries, `driver_plus_herdr` and `herdr_graded`, **passed**, and the
   Makefile prints its own "drop it from DST_KNOWN_RED" note for each. They are not mine to edit, so I left them.
3. **mutgate 10/10 discriminate** (`mutgate-result.tsv`). The spec is `p16ra2_mutgate_spec.tsv`: one row per changed
   file, plus a second `discovery` row for the grep slot move. It ran on a fresh `git clone --shared` at `6b66d244`
   with exactly these 9 paths applied, through `mutgate.sh --spec … --repo …`. Each row uses P1.6r's
   `p16r_ws.sh check` workspace, which is lock-free: nothing resolves to the primary checkout. There are no pipes in
   a `test_cmd`.
