# P1.2c — batch C onto ABI 8.0 (evidence)

PLAN-001 (031) §3 P1.2, batch C: `motoko-ext-a2a`, `motoko-ext-agentcli`, `motoko-ext-ailang-docs`,
`motoko-ext-mcp`, `motoko-ext-compaction-ai`. It also covers batch C's masked files,
`scripts/dst/conformance_selftest.ail` and `scripts/dst/long_qwen_compaction_dst.ail`. HEAD before:
`4109827b` (the brief was grounded at `eebc4d13`; P1.3r landed in between). AILANG v0.33.0. The part runs
under ADR-001 Amendments 1–3. Amendment 3 (`791be004`) arrived mid-part, and its effect is recorded below.

## The sites: 9 by the ledger, not 11

The brief and the plan's table say **11 sites** and **four `DescribeTools`**. The 45-row ledger
(`REVIEW-adr001-v0.6-verdicts-codex.md` §Q-1), which the plan names as the site list, gives these five
packages **9 rows** (#1–8 and #28). Three of them are `DescribeTools`: a2a, agentcli and ailang-docs. The
fourth catalog that captures configuration is herdr's (#22), which is in batch D. The gate agrees: before this part,
these five extensions held **9** of the tree's 32 binding rejections, and after it they hold 0 (32 → 23).
Batch totals by the ledger are A 10, B 16, C 9, D 10. The plan's 9/14/11/11 are a planning count. The
orchestrator should reconcile them; this part does not edit the plan.

| # (Q-1) | site | 7.4 form | 8.0 payload (named, in `register.ail`) | reads from `ext_config` |
|---:|---|:---:|---|---|
| 1 | a2a `DescribeTools` | I | `a2a_describe_tools(cfg: Json)` | agents → one schema each |
| 2 | a2a `ToolProvider` | L | `a2a_tool_handle(ctx: ProviderCtx, …)` | agents |
| 3 | agentcli `DescribeTools` | I | `agentcli_describe_tools(cfg: Json)` | providers |
| 4 | agentcli `ToolProvider` | L | `agentcli_tool_handle(ctx: ProviderCtx, …)` | providers (resolved model and flags), lock path, output cap |
| 5 | ailang-docs `DescribeTools` | I | `ailang_docs_describe_tools(cfg: Json)` | `active` → 23 schemas or none |
| 6 | ailang-docs `PromptShaper` | I | `ailang_docs_prompt(ctx: PureCtx)` | — (reads `ctx.task`) |
| 7 | ailang-docs `ToolProvider` | L | `ailang_docs_tool_handle(ctx: ProviderCtx, …)` | bridge timeout and output cap |
| 8 | compaction-ai `Compactor` | I | `compaction_ai_compact(ctx: AiCtx, …)` | the resolved `CompactionAiConfig` |
| 28 | mcp `ToolProvider` | L | `mcp_tool_handle(ctx: ProviderCtx, …)` | server list |

**Captures: 8** (every row except #6), encoded as **5 configs**, one per package. Each config is encoded once
and shared by the payloads that read it:

- a2a: `{"agents":[{name,url,description,skill_id}]}`, the file's own shape, which `parse_a2a_json` decodes.
- agentcli: `{"providers":[{id,model,extra_flags}],"lock_path","max_output_chars"}`. The ids index the provider
  table in `providers.ail`, which is code. The model and flags are the values resolved from `CODEX_MODEL`,
  `CODEX_EXTRA_FLAGS`, and the rest, at registration, as in 7.4.
- ailang-docs: `{"active","timeout_ms","max_output_chars"}`.
- mcp: `{"servers":[…]}`, in `mcp.json`'s shape, which `parse_mcp_config` decodes, with its defaults written out.
- compaction-ai: the resolved `CompactionAiConfig`. `config_of_json({})` is `default_config()`.

**No credentials.** None of these packages reads one. mcp's `auth_env_var` is a name. The profile
directory and workdir **values** only locate files at registration and are not disclosed, as omnigraph did.
agentcli's `lock_path` embeds the profile directory, because the handler needs that path.

**Amendment 3, applied.** The first cut read the old D2 `:370-372` wording ("names, not values") strictly.
It moved agentcli's resolved model, flags, lock path and output cap, and ailang-docs' two limits, to per-call
`ctx.ports.env_get` reads. Amendment 3 says those values go through `config`, and that `ProviderCtx` sites also
take them at registration. Both packages now resolve once at registration and disclose the result. The
channel probe checks that synthetic `CODEX_MODEL` / `AILANG_DOCS_TIMEOUT_MS` values reach `config`.

## Choices, with reasons

- **The payloads live in `register.ail`, and this is a measured requirement, not taste.** On the pin, an
  **imported** effectful function used as a constructor argument charges its row to the function that
  registers it. `register_with_config ! {Env, FS}` then fails with `Missing effects: AI, Clock, Env, …`. A
  function declared in the same module does not trigger this. Evidence: `import_leak_probe/`. `r1` imports
  the handler and `r2` declares it, and only `r2` checks. This is why omnigraph's handler is in `register.ail`
  too. It is probably worth an AILANG report, which I have not filed. The helpers stay in their modules
  (`a2a_decide`, `mcp_decide`, `on_tool_handle`, …).
- **compaction-ai's chain takes `AiCtx` end to end** (ADR D2 `:337`). Every helper in it is reached only from
  the Compactor, so the chain uses the Compactor's view rather than projecting to `PureCtx`. The ten-port
  no-op test ports are gone. The tests build `AiCtx` with `pure_ctx` + record update + `ai_ctx`, and they
  carry a failing or a succeeding `ai_step`.
- **compaction-ai no longer imports `src/core`.** It used `src/core/ext/ctx_defaults` in its tests and
  `src/core/compaction.calibrated_usage_percent_anchored` at runtime. A package that imports the host's source
  tree cannot be checked as its own root (exit 1) and cannot be published. The calibration is 12 lines of
  arithmetic (`estimate → affine_calibrate(…, 1235‰) → percent`) and is now carried in `compaction_ai.ail`
  over `Msg`. **Two copies now exist, and a parity probe holds them equal:** `p12c_calib_parity.ail`
  runs 9 cases against HEAD's core, and mutgate row `cai_calib_parity` covers it. A change to the core's
  calibration has to be made in both places. The comment says so.
- **Registration rows narrowed.** No `register_with_config` performs the effects of its handlers any more.
  a2a changed from `{Env, FS, Net, Rand}` to `{Env, FS}`. compaction-ai changed from ten effects to
  `{Env, FS}`. agentcli changed from `{Env, FS, IO, Process}` to `{Env}`. mcp and ailang-docs are `{Env, FS}`.
- **Removed exports.** `make_hooks` in a2a, agentcli, ailang-docs and mcp built the 7.4 list with inline
  payloads, and 8.0 cannot express it. Two files outside this part import it: `examples/smoke_a2a_delegate.ail`
  and `examples/smoke_registry_roundtrip.ail`. They call it and inspect the returned list. At HEAD they were
  already red, because the 7.4 packages they import do not compile against the 8.0 ABI. Now they are red on the
  missing export instead. They are outside this part's paths and have no owner in the plan's P1 inventory. They are reported, not edited. mcp's `types`/`exec`/`resolve`, which batch B's
  exa-search imports, are unchanged.

## Ceilings (ADR-001 Amendment 2)

| package | slots registered | `[effects].max` before | added | removed |
|---|---|---|---|---|
| a2a | DescribeTools; ToolProvider (all eleven) | Net FS Env Rand IO | Process AI SharedMem Clock Stream Trace | — |
| agentcli | DescribeTools; ToolProvider | Process FS Env IO | AI Net SharedMem Clock Stream Rand Trace | — |
| ailang-docs | DescribeTools, PromptShaper; ToolProvider | Process FS Env | IO AI Net SharedMem Clock Stream Rand Trace | — |
| mcp | ToolProvider | Process FS Env IO | AI Net SharedMem Clock Stream Rand Trace | — |
| compaction-ai | Compactor `{AI, IO, Trace}` | AI IO Process FS Env Net SharedMem Clock Stream | Trace | Process Net SharedMem Clock Stream |

The four `ToolProvider` packages admit all eleven effects, as the amendment requires.
**compaction-ai was narrowed** to exactly `[AI, IO, Trace, Env, FS]`. That is its slot row plus
registration's reads, and it follows the brief's "nothing beyond what its code performs". Its test and smoke
declarations were over-declared at ten effects and are now `{AI, IO, Trace}` (smoke: `+ Env, FS`). Each
added effect has a mutgate row (`ceiling_*`), and 29 rows drop one each. Every package's ABI dependency now
pins `version = "8.0"`. The two tracked locks (agentcli and compaction-ai recorded ABI 4.0 under v0.26.0)
were regenerated.

## Masked files

- `conformance_selftest.ail`: two edits, `expect_accept(…, ai.caps)` and `(…, structural.caps)`. Both
  registrations now return `ExtRegistration`. The kit stamps `{}`, which compaction-ai decodes to its
  defaults. That matches 7.4's behaviour with no profile file. It checks on HEAD and runs **PASS**.
- `long_qwen_compaction_dst.ail`: what 8.0 requires, and nothing more. The contexts are `AiCtx` built by
  `ai_ctx` (only the `ai_step` shim is kept). `headroom_direct_ctx` is a `PureCtx`, because P1.2a moved
  `compact_for_pre_step` to `PureCtx`. A local `pure_view(AiCtx)` handles the fixture's structural compactor.
  Fixture overrides carry `config: jo([])`, and the `provide` rows gain `Trace`. The nine `fixed_ext_*` port
  definitions are left in place, unused.
  - **At HEAD `4109827b` it fails to check on a cold cache. The failure is not in this file:**
    `type error in src/core/test/dst_harness (decl 4) … cannot unify list[Capability] with ()`.
  - **Cause:** P1.3r made `src/core/ext/runtime.ail:40` import `motoko_ext_conformance/harness`
    (`neutral_registration`). That module declares its own `Scenario` (`run: [Capability] -> …`). On the pin,
    a program that reaches both it and core's `dst_harness.Scenario` (`run: () -> …`) resolves one name to
    the other.
  - **Which side breaks depends on compile order.** Moving the import makes the error move into the
    conformance harness. It also depends on the compile cache: after another script warms the cache, the same
    bytes check clean. So an ordinary warm checkout can hide the failure.
  - **Minimal reproduction** (`scenario_collision_probe/min_collision.ail`): import `src/core/ext/runtime`
    together with `dst_harness` and call `run_all`. On a cold cache it fails at `4109827b` and checks clean
    at `a7aa68a8`, P1.3r's parent. Both results were measured.
  - **Checked against `a7aa68a8`'s core** (8.0, without that import), the file checks clean and runs **PASS
    count=12**. The mutgate row uses that revision (`P12C_REV`).
  - **Any other script that imports session or runtime together with `dst_harness` is likely affected.** That
    is the core lane's (P1.3r / P1.4r) to settle. A rename of either `Scenario` would do it. Nothing in batch
    C's surface can.

## Exit checks (receipts in `CHECKS.log`)

1. Own root, own `ailang.toml`, ABI from HEAD (`p12c_pkgroot.sh`): **5/5 clean**. ailang-docs' path
   dependency on mcp is resolved inside the workspace.
2. Own tests (`p12c_ws.sh test`, which runs `ailang test` per module): a2a 7 + 4, agentcli 1, ailang-docs 1 + 2,
   mcp 5 + 4, compaction-ai 11 + 2. **All pass. No test was removed.** The per-module counts at HEAD were
   7/3/0/0/2/4/4/11/0, and the new tests are the config codecs. Smokes: mcp OK, compaction-ai OK.
3. Gate (`derive.py --hook-scope --no-provision`): all five **pass**. On **committed HEAD `f21e508d` plus
   batch C only** (a fresh clone, `CHECKS.log` §3b) the tree reads **shape pass 11 of 18, binding rejections
   23**, which is 32 minus these 9. The shared working tree reads 16 of 18 by the end of the part, because it
   also holds batches B and D's uncommitted edits. That reading is not this part's number (`CHECKS.log` §3).
4. Masked files: see above.
4b. `DescribeTools`, real config vs `{}`: **a2a 1/0, agentcli 2/0, ailang-docs 23/0** (`p12c_channel.ail`,
   run through the real registrations against synthetic fixtures).
5. mutgate: `p12c_mutgate.sh --overlay` runs a fresh clone of HEAD with this part's paths, over
   `p12c_mutgate_spec.tsv`. **51/51 discriminate** with bytes restored; the verdicts are in
   `mutgate-result.tsv`. The rows cover 5 re-inlines (one per package), the tree reading 11/23, 8 captures
   read from a module value, 3 registrations withholding what they read (Amendment 3), the 8.0 pin, the
   failing test port, calibration parity, both masked files, and 29 ceiling effects.
   **The first run scored 49/51 and was refused.** Two rows were vacuous. `cai_calib_parity`'s 1‰ drift
   vanished in the probe's rounding; the probe gained a limit-1 case. `masked_long_qwen` mutated the
   structural fixture, which no scenario asserts on; the row was re-aimed at the rebuilt `AiCtx`, and 5
   scenarios now fail under it. The spec's comments record both.

## Files

`p12c_pkgroot.sh`, `p12c_ws.sh`, `p12c_core_check.sh` (HEAD via `git archive`, `P12C_REV`, `P12C_KEEP`),
`p12c_channel.ail`, `p12c_calib_parity.ail`, `import_leak_probe/`, `scenario_collision_probe/`, `p12c_mutgate_spec.tsv`,
`p12c_mutgate.sh`, `mutgate-result.tsv`, `CHECKS.log`.
