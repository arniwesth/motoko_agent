# P1.2b — batch B onto ABI 8.0 (evidence)

PLAN-001 (031) §3 P1.2, batch B: `repetition-guard`, `test-dummy`, `motoko_scratchpad`, `exa-search`,
`context-mode`, plus batch B's masked file `scripts/verify_repetition_guard.ail`. This attempt
resumed after the stop recorded in `STOP-env-captures.md` / `env_probe/`, which became **ADR-001
Amendment 3** (`791be004`): non-credential registration values go through `config`, environment
values included; a credential travels as a name only. HEAD before: `eebc4d13` (stop), resumed at
`791be004`, checked at `f21e508d`. AILANG v0.33.0.

## The sites (Q-1 rows 14–17, 20–21, 36–45)

Fourteen sites changed binding form. Rows 15 and 44 were already named and are only re-typed.

| # | site | 7.4 | 8.0 payload (view) | reads from `ext_config` |
|---:|---|:---:|---|---|
| 14 | context-mode `PromptShaper` | I | `ctx_prompt` (`PureCtx`) | `cached_prompt` |
| 15 | context-mode `ToolPolicy` | N | `on_tool_policy` (`PureCtx`) | — |
| 16 | context-mode `ToolProvider` | L | `ctx_tool_handle` (`ProviderCtx`, row +`Trace`) | `bin`, `timeout_ms`, `max_output_chars`, `snapshot_key_prefix` |
| 17 | context-mode `SolverJudge` | L | `ctx_finalize` (`ProcessCtx`) | `bin`, `timeout_ms` (same record) |
| 20 | exa-search `PromptShaper` | I | `exa_prompt` (`PureCtx`) | `cached_prompt` |
| 21 | exa-search `ToolProvider` | L | `exa_tool_handle` (`ProviderCtx`, +`Trace`) | `timeout_ms`, `max_output_chars` |
| 36 | repetition-guard `ToolPolicy` | L | `policy` (`PureCtx`) | `calls` |
| 37 | repetition-guard `SolverJudge` | L | `finalize` (`ProcessCtx`) | `answers` |
| 38 | test-dummy `PromptShaper` | I | `dummy_prompt` (`PureCtx`) | `prompt_marker` |
| 39 | test-dummy `BudgetShaper` | I | `dummy_budget` (`PureCtx`) | `budget_total` |
| 40 | test-dummy `ToolPolicy` | I | `dummy_tool_policy` (`PureCtx`) | `tool_decision` |
| 41 | test-dummy `SolverJudge` | I | `dummy_finalize` (`ProcessCtx`) | `finalize` |
| 42 | scratchpad `DescribeTools` | I | `on_describe_tools(_cfg: Json)` | — (fixed schema) |
| 43 | scratchpad `PromptShaper` | I | `scratchpad_prompt` (`PureCtx`) | — |
| 44 | scratchpad `ToolPolicy` | N | `on_tool_policy` (`PureCtx`) | — |
| 45 | scratchpad `ToolProvider` | L | `scratchpad_tool_handle` (`ProviderCtx`, +`Trace`) | `timeout_secs` |

Every `register_with_config` returns `ExtRegistration = { config, caps }`, and `caps` is a literal
list. Each package encodes its configuration once, with one codec (`budget_config` /
`dummy_config_json` / `timeout_config` / `exa_config` / `ctx_config_json`), and each callback
decodes it per call. An absent key decodes to the registration default, so an empty config gives
the stock behaviour. **Values moved into config: 15.** repetition-guard has 2, test-dummy 4,
scratchpad 1, exa-search 3 (the prompt plus 2 settings) and context-mode 5 (the prompt plus 4
`CtxConfig` fields, shared by three callbacks). All are read once at registration, as in 7.4,
including the ones on `ProviderCtx` (Amendment 3).

**Not disclosed:**
- the workdir. exa-search and context-mode read their prompt file from it at registration; the
  probes assert the workdir string is absent from the config.
- the one credential. exa-search's key travels as `auth_env_var: "EXA_API_KEY"`, a name inside
  the module-constant MCP config, and the bridge resolves it. The probe sets a synthetic key
  value, asserts it is absent from the config, and asserts the *name* reaches the bridge argv.
- the tool mappings. They are a module constant (code), not configuration.

## Choices, with reasons

- **Shared helpers take `PureCtx`** (ADR D2, `:335-337`).
  - repetition-guard's `worst_repeat` / `restating` / `decide_*` / `prior_answers` now take
    `PureCtx`. The judge projects its `ProcessCtx` with `pure_view` (constructor plus record
    update, batch A's form).
  - context-mode's `bridge_args_for` and `ensure_context_mode_ready` are called from the provider
    and the judge, so they take `PureCtx` through `pure_of_provider` / `pure_of_process`.
  - `finalize_with_index` takes `PureCtx`. No dummy ports anywhere in the packages.
- **Effectful payloads live in `register.ail`.** On the pin, binding a payload *imported* from
  another module charges its whole row to `register_with_config`'s inferred effects. The same
  function defined in the registering module does not (`import_leak_probe/`, `RESULT.txt`:
  local exit 0; imported `Missing effects: AI, Clock, Env, FS, IO, Net, Process, Rand, SharedMem,
  Stream, Trace`). This is why omnigraph's wrapper also sits in its `register`. The providers and
  judges are therefore defined in `register.ail`; pure payloads may be imported. This is a
  candidate for AILANG feedback, and was not filed from here.
- **Changes forced by 8.0 alone:**
  - `Accept(c)` → `Accept` (nullary in 8.0) in repetition-guard, test-dummy and the masked file.
  - `DescribeTools` takes `Json`.
  - `ws_loopback.ail`'s three functions on the path to core's 8.0 dispatch gain `Trace`.
  - The registration rows shrank to what they perform: scratchpad `{Env, Net, Rand}` → `{Env}`;
    exa-search `{Env, FS, Process, Rand}` → `{Env, FS}`; context-mode
    `{Env, FS, Process, SharedMem, Rand}` → `{Env, FS}`.
- **The pin.** Each `ailang.toml` reads `{ path = "../motoko-ext-abi", version = "8.0" }`. None of
  the five has a tracked lock.

## Effect ceilings (Amendment 2): what was added

| package | slots registered (rows) | added to `max` |
|---|---|---|
| repetition-guard | ToolPolicy `{}`, SolverJudge `{Process}` | — |
| test-dummy | PromptShaper, BudgetShaper, ToolPolicy `{}`; SolverJudge `{Process}` | `Process` (the judge is now named; at 7.4 it was an inline lambda the ceiling did not see) |
| scratchpad | DescribeTools, PromptShaper, ToolPolicy `{}`; ToolProvider (all eleven) | `Rand`, `Trace` |
| exa-search | PromptShaper `{}`; ToolProvider (all eleven) | `IO`, `AI`, `Net`, `SharedMem`, `Clock`, `Stream`, `Rand`, `Trace` |
| context-mode | PromptShaper, ToolPolicy `{}`; ToolProvider (all eleven); SolverJudge `{Process}` | `IO`, `AI`, `Net`, `Stream`, `Rand`, `Trace` |

All 17 added effects are load-bearing: dropping any one fails the own-root check (mutgate rows
`*_ceiling_*`). **Surplus, reported and not narrowed** (measured by narrowing a scratch copy):
repetition-guard passes with exactly `[Process, Env, FS]`, so `IO, AI, Net, SharedMem, Clock,
Stream` admit no slot and no performed effect. `FS` stays because `register_with_config` still
declares `! {Env, FS}` from 7.4. context-mode's `SharedIndex` is **used** (`std/sem`'s
`store_frame_ns`).

## Exit checks (receipts in `CHECKS.log`)

1. **Own root.** `p12b_pkgroot.sh` (adapted from `p12a_pkgroot.sh`) checks each package as its own
   root, with its own `ailang.toml`: **5/5 ok**. exa-search's `motoko-ext-mcp` dependency is read
   from committed HEAD (batch C owns it). scratchpad's undeclared `src/core` imports resolve
   against HEAD's `src/core`. `ws_loopback.ail` cannot load as a package root at all
   (→ `tool_envelope_dispatch` → the generated registry → this very package), so it is skipped
   there, printed as skipped, and checked in the core workspace (item 4).
2. **Own tests** (`p12b_ws.sh test`):
   - repetition-guard `repetition_guard.ail`: 8/8.
   - exa-search `exa_search.ail`: 1 passed, 2 failed. **Both failures are pre-existing and
     identical at `181051d0`** (`exa_search_test_at_74.log`, from `p12b_exa_test_at_74.sh`, a
     lock-free workspace): `mappings_define_expected_canonicals` and
     `alias_resolves_to_mcp_tool` test mcp's resolver at HEAD, which this part does not touch.
   - test-dummy, scratchpad and context-mode have no inline tests.
   - Channel probes (`p12b_ws.sh probe rg|td|sp|exa|cm`): **5/5 OK**. Each registers under
     synthetic environment values and runs every callback on a real view stamped with the
     disclosed config. The value must arrive, an **empty** config must give the default, and no
     workdir or credential value may appear. The providers really execute: exa-search and
     context-mode run against `p12b_fake_bridge.mjs` (logs its argv, talks to nothing);
     scratchpad posts to `p12b_echo_server.py` on loopback; context-mode's prefix is read back
     from the readiness marker in shared memory.
3. **The P0.3 gate** (`derive.py --hook-scope --no-provision`): all five batch-B extensions
   `config-caps pass`. On **HEAD `f21e508d` plus only this part's paths**: shape pass
   **11 of 18**, binding rejections **18** (batch A's 6 / 32, minus this batch's 14). On the shared
   working tree, which carries other batches' uncommitted work, the reading was 16 of 18 · 0 at
   the time of measuring.
4. **Masked file and core-reaching module** (`p12b_core_check.sh`: `git archive HEAD src/core`, the
   registry generated over batch A (HEAD) and batch B's eleven real packages, mcp from HEAD):
   - `scripts/verify_repetition_guard.ail` checks and runs **all OK**. Changed only where 8.0
     requires: the context is a `PureCtx` built by `pure_ctx` + record update (which drops its
     `src/core/ext/ctx_defaults` import), and `Accept` is nullary.
   - `deps/motoko_scratchpad/ws_loopback.ail`, `src/core/tool_phase.ail`,
     `src/core/ext/registry_generated.ail` and `src/core/ext/runtime.ail` check clean.
5. **mutgate**: `p12b_mutgate.sh --overlay` (a fresh clone of HEAD plus this part's paths, under
   `/workspaces`) over `p12b_mutgate_spec.tsv`, generated by `p12b_mutgate_spec.py`. Result:
   **46/46 discriminate**, bytes same, on the first run (HEAD `f21e508d` plus these paths;
   `mutgate-result.tsv`). The rows:
   - 5 re-inlined payloads (one per package) and 1 tree row;
   - 15 per-value "read from a module value instead of `ext_config`" rows, plus the judge's own
     read of context-mode's record;
   - 2 registrations withholding a value, and 1 credential value put into config;
   - 17 dropped-ceiling-effect rows;
   - 1 pin, 1 own-test row, 1 masked-file row and 1 `ws_loopback` `Trace` row.

## Files

`p12b_ws.sh` (check / test / probe / gate / tree), `p12b_pkgroot.sh` (own root),
`p12b_core_check.sh` (core workspace), `p12b_{rg,td,sp,exa,cm}_channel.ail`, `p12b_fake_bridge.mjs`,
`p12b_echo_server.py`, `p12b_exa_test_at_74.sh` + `exa_search_test_at_74.log`,
`p12b_mutgate_spec.py` → `p12b_mutgate_spec.tsv`, `p12b_mutgate.sh`, `mutgate-result.tsv`,
`CHECKS.log`, `import_leak_probe/`. The stop record: `STOP-env-captures.md`, `env_probe/`.
