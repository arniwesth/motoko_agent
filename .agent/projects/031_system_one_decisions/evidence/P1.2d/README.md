# P1.2d — batch D onto ABI 8.0 (evidence)

PLAN-001 (031) §3 P1.2, batch D: `motoko-ext-compose` and `motoko-ext-herdr`. It has **10 sites and 6
captures** (the brief first said 11). The batch also owns eleven masked files:
- `scripts/dst/compose_live_exec.ail`, `declared_vs_performed.ail` and `herdr_graded_dst.ail`;
- the eight `scripts/verify_*` herdr scripts.

It was stopped twice. Each stop became an amendment and is kept here, committed by the orchestrator:
- `STOP.md` and `fs_view_probe/` became **Amendment 3**: environment values go through `config`.
- `STOP-measurement.md` and `bench/` became **Amendment 4**: the decode cost is stated against the step.

AILANG v0.33.0.

## The 10 sites

| # (Q-1) | site | 7.4 form, capture | 8.0 payload (named, bound directly) | what it decodes from `ext_config` |
|---:|---|---|---|---|
| 10 | compose `PromptShaper` | N | `on_build_system_prompt(_ctx: PureCtx)` | nothing |
| 11 | compose `ToolPolicy` | I, `composition_mode` | `on_tool_policy(ctx: PureCtx, call)` | `compose.mode` |
| 12 | compose `ToolProvider` | L, `runtime_cfg`, `snippet_caps` | `compose_tool_handle(ctx: ProviderCtx, call)`, row `+Trace` | the whole host config |
| 13 | compose `ResponseInterceptor` | L, `composition_mode`, `snippet_caps` | `compose_intercept(ctx: InterceptCtx, text)` | `compose.mode`, `snippet_caps` |
| 22 | herdr `DescribeTools` | L, `cfg`, `tools` | `herdr_describe(config: Json)` | `cfg.allowed_kinds`, `cfg.kind`, `tools` |
| 23 | herdr `PromptShaper` | I, `orch` | `herdr_prompt(ctx: PureCtx)` | `orch` |
| 24 | herdr `ToolPolicy` | I, `orch` | `herdr_policy(ctx: PureCtx, call)` | `orch` |
| 25 | herdr `ToolProvider` | L, `cfg` | `herdr_tool_handle(ctx: ProviderCtx, call)`, row `+Trace` | `cfg` |
| 26 | herdr `ExitIntent` | L, `cfg` | `herdr_exit(ctx: FsCtx)` | `cfg` (pane, session, dagr dir, bin, knobs) |
| 27 | herdr `WorkInFlight` | L, `cfg` | `herdr_waiting(ctx: FsCtx)` | `cfg` (pane, session, dagr dir) |

**The registration head.** Each `register.ail` writes `{ config, caps }` at its own tail. The shape
rule admits delegation at `caps` only, so `caps` is delegated to a named function that returns a
literal list:
- compose: `compose_caps()`;
- herdr: `herdr_caps(tools, exit_enabled)`. Its two arguments are the constructor **data** positions
  (the advertised names and `ExitIntent`'s `enabled`), which the host digests beside `config` (N58).

The scripts' entry points keep a registration-shaped result:
- `compose.register_with_config(ComposeHostConfig)` now returns `ExtRegistration`;
- herdr's `make_hooks` and `make_hooks_with` do the same.

**The configuration channel.** Each package encodes its config **once**:
- compose: `config.host_config_json`, holding the whole `ComposeHostConfig`. This is the one value
  behind `runtime_cfg`, `snippet_caps` and `composition_mode`. Only the profile directory is left
  out, because no callback reads it.
- herdr: `herdr.herdr_config_json(cfg, tools, orch)`.

Every field is written explicitly, and round-trip tests pin decode ∘ encode = id:
- `config.ail` `host_config_roundtrip`;
- `herdr.ail` `cfg_roundtrip`;
- `orchestrator.ail` `mode_roundtrip`.

Under **Amendment 3**, herdr's config holds registration **values**: this pane's id, the session time,
the bin path, the delegate and dagr directories, and the orchestrator's pane and run-file paths. None
is a credential. **Its config digest therefore differs per session by construction**, so a resume
records a new policy epoch for herdr. herdr has no decision atoms, so no refusal follows.

**Ports (no dummy ports).** compose's three helpers are shared between the tool path (`ProviderCtx`,
all of `ExtPorts`) and the interceptor (`InterceptCtx`, `InterceptPorts`). They now take the smallest
records they call:
- `check_snippet` and `run_snippet` take `SnippetExecPorts { tool_handle }`;
- `remove_if_file` takes `RemovePorts { path_stat, file_remove }`.

Each caller projects its own record (`exec_ports`/`exec_ports_i`, `remove_ports`/`remove_ports_i`).
The tool-path helpers take `ProviderCtx`, since `ExtPorts` is exactly its ports record. herdr's exit
and work renders take `FsCtx` and use `file_read` only.

**Ceilings (Amendment 2)**, each load-bearing (mutgate rows `*_ceiling_*`):

| package | added to `max` | why |
|---|---|---|
| compose | `Rand`, `Trace` | the named `compose_tool_handle` declares the ToolProvider row. `Rand` was **already** over the ceiling at 7.4 (`on_tool_handle`, `register_with_config`): see `own_root_at_181051d0.log` |
| herdr | `AI`, `Net`, `SharedMem`, `Stream`, `Rand`, `Trace` | the named `herdr_tool_handle` declares the ToolProvider row; herdr's own code performs none of them |

**Pins:** both manifests read `{ path = "../motoko-ext-abi", version = "8.0" }`. Neither package has a
tracked lock.

## Masked files, changed only where 8.0 requires

- **`ExtCtx` literals** gain the three D3 fields on the line that already held `world:`:
  `verification: NotReached`, `tool_evidence: empty_tool_evidence()`, `decision_state: None`.
- **Registry entries** carry the registration's `config` (`{ id, config: r.config, caps: r.caps }`).
- **The six `on_tool_handle` callers** keep their `ExtCtx` builder (renamed `mk_ext_ctx`). They wrap it
  as `ProviderCtx` through `provider_ctx(pure_ctx_of(c, jo([])), c.ports, c.world)`.
- **`verify_herdr_orchestrator`** calls the atoms the way the host does: on `pure_ctx_of(ctx,
  r.config)`.
- **`declared_vs_performed`**:
  - its fixture lambdas take their views (`AiCtx`, `PureCtx`, `InterceptCtx`, `ProcessCtx`);
  - every entry carries `config`, and the `reg_*` arms count `h.caps`;
  - the solver witness moves from `Accept(s)` to `ContinueWithFeedback(s)`, because `Accept` is
    nullary at 8.0. The printed witness is unchanged.

## Exit checks (`CHECKS.log`)

1. **Own root** (`p12d_pkgroot.sh`, adapted from P1.2a's, with compose's ai-compat dependency): both
   clean.
2. **Own tests** (`p12d_ws.sh test`):
   - compose `config.ail` 2/2 (new; compose had no tests);
   - herdr `herdr.ail` 8/8, `orchestrator.ail` 90/90, `dagr.ail` 73/73, `types.ail` 282/282.
3. **Gate** (`derive.py --hook-scope --no-provision`): compose and herdr both `config-caps pass`. The
   tree, measured on committed HEAD plus batch D: **pass 18 of 18, binding rejections 0**.
4. **Masked files** (`p12d_core_check.sh`): the workspace is `git archive HEAD` plus P1.2d's paths
   only, with the registry generated over every 8.0 package and the real scratchpad.
   - **11/11 check.**
   - `suite` runs each file as its Makefile or runner recipe does and asserts the same markers.
     compose_live_exec, herdr_graded_dst, the 8 verify scripts and verify_herdr_delegate_wait's
     `print_fixtures` all pass.
   - declared_vs_performed's batch-D arms all pass with the runner's caps and witnesses: `compose_*`,
     both threading spines, and `reg`/`budget` for compose and herdr.

   **4b. Measurement:** `bench/`, now Amendment 4.
5. **mutgate** (`p12d_mutgate.sh --overlay`, spec `p12d_mutgate_spec.tsv`, verdicts `mutgate-result.tsv`):
   **44/44 discriminate**, bytes same. **The first run was 43/44 and was refused.**
   `herdr_capture_describe_cfg` was vacuous: the probe looked for "codex", which the schema's fixed
   `model` text names whatever the config says. The probe now checks two strings only the config can
   produce: "permits claude,codex" and `"required":["prompt","kind"]`. The spec's comment records
   this. Every row asserts **batch D's own** results (its own shape rows, probes, own-root checks and masked-file
   runs), never whole-tree totals. The rows cover:
   - one re-inlined payload per site family;
   - one per capture (read from a constant instead of `ext_config`);
   - registration withholding what it read;
   - the `ExitIntent` data position;
   - the three codecs;
   - the narrowed ports record;
   - each of the 8 added effects;
   - both pins;
   - one per masked file.

## Files

- `p12d_ws.sh`: package workspace (check, test, gate, tree, channel, provider, registration).
- `p12d_pkgroot.sh`: the own-root check.
- `p12d_core_check.sh`: core workspace from committed HEAD (check, test, run, suite).
- `p12d_channel.ail`: the configuration-channel probe. Recording ports put what a payload read or ran
  into its world token.
- `p12d_mutgate.sh`, `p12d_mutgate_spec.tsv`, `mutgate-result.tsv`: the mutgate and its verdicts.
- `CHECKS.log`, `own_root_at_181051d0.log`: receipts.
- `STOP.md`, `fs_view_probe/`, `STOP-measurement.md`, `bench/`: the two stops.
