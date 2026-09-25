# P1.2b — stopped before editing: batch B's captures are environment values

LEG-P1.2b "If the ADR turns out to be wrong": *a capture that cannot go through config … a measurement
the ADR's sentence does not survive — stop and report the artifact.* HEAD `eebc4d13`, AILANG v0.33.0.
No package file was edited.

## The sentence, and the measurement

ADR-001 D2 (`:372-374`): "Configuration carries no credentials (D1) … **the in-tree captures hold
environment-variable *names*, not values**". The brief turns this into a rule: "no environment
**value** is captured into config". Read at HEAD, every settings capture in batch B is an env
**value**, read with `getEnvOr` in `register_with_config`. Where the callback's 8.0 view has no
`env_get`, config is the only way the value can reach it:

| Q-1 | site | 7.4 capture | source | 8.0 view | `env_get` on view? |
|---:|---|---|---|---|:---:|
| 14 | context-mode `PromptShaper` | `cached_prompt` | file under `MOTOKO_WORKDIR` (like omnigraph, accepted in P1.2a) | `PureCtx` | no, but not an env value |
| 16 | context-mode `ToolProvider` | `CtxConfig` | `CONTEXT_MODE_{BIN,TIMEOUT_MS,MAX_OUTPUT_CHARS,SNAPSHOT_KEY_PREFIX}` | `ProviderCtx` | **yes**, names-only is possible |
| 17 | context-mode `SolverJudge` | `CtxConfig` (`bin`, `timeout_ms`, `snapshot_key_prefix`, via `finalize_with_index`) | same | `ProcessCtx` | **no** |
| 20 | exa-search `PromptShaper` | `cached_prompt` | file under `MOTOKO_WORKDIR` | `PureCtx` | no, but not an env value |
| 21 | exa-search `ToolProvider` | `McpServerConfig` (`timeout_ms`, `max_output_chars`; the key is already a name, `auth_env_var: "EXA_API_KEY"`) | `EXA_TIMEOUT_MS`, `EXA_MAX_OUTPUT_CHARS` | `ProviderCtx` | **yes** |
| 36 | repetition-guard `ToolPolicy` | `calls: int` | `MOTOKO_REPEAT_CALL_BUDGET` | `PureCtx` | **no** |
| 37 | repetition-guard `SolverJudge` | `answers: int` | `MOTOKO_REPEAT_ANSWER_BUDGET` | `ProcessCtx` | **no** |
| 38 | test-dummy `PromptShaper` | `prompt_marker` | `EXT_DUMMY_PROMPT` | `PureCtx` | **no** |
| 39 | test-dummy `BudgetShaper` | `budget_total` | `EXT_DUMMY_BUDGET_TOTAL` | `PureCtx` | **no** |
| 40 | test-dummy `ToolPolicy` | `tool_decision` | `EXT_DUMMY_TOOL_DECISION` | `PureCtx` | **no** |
| 41 | test-dummy `SolverJudge` | `finalize` | `EXT_DUMMY_FINALIZE` | `ProcessCtx` | **no** |
| 45 | scratchpad `ToolProvider` | `timeout_secs` | `MOTOKO_SCRATCHPAD_TIMEOUT_SECS` | `ProviderCtx` | **yes** |

Rows 15, 42, 43, 44 capture nothing. So **7 of the 14 sites** (17, 36–41) need an environment
value, and the view has no port to read it with. Under the brief's rule those captures cannot go
through config. The plan's own table (§3 P1.2, batch B: "ints, strings, one config record") lists
these same values as the data the channel carries. The two texts disagree for these seven sites.

## The compile artifact (`env_probe/`, `probe.sh` → `RESULT.txt`)

This probe uses the ABI at committed HEAD, in a lock-free workspace, with a permissive ceiling so
that only the slot row is being tested:

- `a_policy_reads_env`: a named `ToolPolicy(PureCtx, …)` calling `getEnvOr`. Check fails:
  `Missing effects: Env`.
- `a2_policy_declares_env`: the same function, declaring `! {Env}`. Check fails at the constructor:
  `incompatible closed rows: r1 has extra labels [], r2 has extra labels [Env]`.
- `b_judge_reads_env`: a named `SolverJudge(ProcessCtx, …) ! {Process}` calling `getEnvOr`. Check
  fails: `Missing effects: Env`.
- `c_policy_reads_config` (control): the same policy reading the budget **value** from
  `ctx.ext_config`. Check is clean.

This is by design: env reads were removed from the pure slots (D2, "`env_get` survives only in
`ProviderCtx`"). For a pure or judge callback, an operator setting that arrives through the
environment can only be (a) disclosed as a value in config, (b) dropped, or (c) moved to a host
source such as `RuntimeConfig`. `RuntimeConfig` has no field for any of these, and
repetition-guard and test-dummy take `_cfg: a` and do not import core.

## What each reading would do (for the orchestrator's ruling)

1. **Values allowed when they are not credentials and do not identify the host.** Budgets,
   decision strings, the marker and timeouts are disclosed as config values. Credentials stay
   names (exa already works this way). The workdir and absolute paths are never disclosed.
   context-mode's `bin` (default `context-mode`, a command name; an operator may set a path) is
   the one borderline value. This reading matches the plan's table and batch A's omnigraph
   precedent (a derived value in config, the workdir withheld). It needs the ADR's `:374`
   sentence restated as an amendment.
2. **Names only.** Rows 16, 21 and 45 disclose names plus defaults, and the provider reads the
   value per call through `ctx.ports.env_get`. That is a behaviour change: one read per call
   instead of one at registration, now recorded. Rows 17 and 36–41 cannot be migrated without
   losing the operator override. That needs an amendment or a descoping ruling.

No choice has been made here. The rule text is the orchestrator's to amend (Amendments 1–2 are
the precedent).
