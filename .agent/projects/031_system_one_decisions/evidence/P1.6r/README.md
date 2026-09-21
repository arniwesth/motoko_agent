# P1.6r — scripts, non-`.ail` code and the root lock onto ABI 8.0 (evidence)

PLAN-001 (031) line R. Brief `LEG-P1.6r.md`. HEAD before: `d83b8d63`. Checked against `6d81fbce` (the P1.3r
follow-up, which landed while this part ran and removed the Scenario collision below). Committed on `00361f07`: the
two commits after `6d81fbce` (the P1.5r follow-up and its §9 record) touch none of this part's paths.
AILANG `v0.33.0`. Files here: `CHECKS.log`, `LOCK.log`, `B-CLASSIFICATION.tsv`, `mutgate-result.tsv`,
`p16r_ws.sh`, `p16r_lock_check.py`, `p16r_mutgate_spec.tsv`.

## A — the 13 scripts (only what 8.0 requires; every assertion kept)

The same five mechanical changes, as in batch D (`a3a82311`):
- callbacks take their **view**: `PromptShaper`/`BudgetShaper`/`ToolPolicy` → `PureCtx`, `Compactor` → `AiCtx`,
  `ToolProvider` → `ProviderCtx` with the row `+Trace`, `ResponseInterceptor` → `InterceptCtx`,
  `SolverJudge` → `ProcessCtx`, `ExitIntent` → `FsCtx`;
- `DescribeTools` takes the disclosed config: `() -> [ToolSchema]` → `(_config: Json) -> [ToolSchema]`;
- every `fixture_hooks` override record carries `config: jo([])`, and `ExtEntry` literals `config: jo([])`;
- `ExtCtx` literals gain `verification: NotReached, tool_evidence: empty_tool_evidence(), decision_state: None`
  on their `world:` line;
- rows that now reach the `ToolProvider` row gain `Trace` (`hook_guard_dst` scenarios and `main`;
  `smoke_v2_handle` `main`). Every Makefile/runner invocation already grants `Trace`.

Two specific ones: `registry_multiplicity_dst` calls the three-argument `normalize_registration(id, jo([]), caps)`;
`world_state_probe`'s `consume_steps` takes `AiPorts` (the Compactor's ports record at 8.0 is `AiPorts`, whose one
field is the `ai_step` the comment already names).

## B — non-`.ail` read-through

`B-CLASSIFICATION.tsv`, every file: **needs change 1, comment only 6, fine 15** (22 files).
- **needs change:** `tools/profile_definition/check_no_op_profile.py`. `hook_scope_atoms()` required B2's
  7.4 head `capability-list`; every 8.0 package reads `config-caps`, so the B8 denominator guard failed closed on
  every installed extension. It now requires `config-caps`. Mutgate row `p16r_no_op_profile_head`.
- **comment only, changed:** `tools/ext_registry_gen/generate.py` docstring (said the real registry is red until P1.1).
- **comment only, not rewritten** (prose, 033 G4): five `design_docs/planned/*` sketches in 7.x shapes.
- The three pinned-data files were run through their own gates and left unchanged (`CHECKS.log` §B).

## C — the root `ailang.lock`

Ran **`ailang lock`** at the repo root, **not** `make sync_packages`. `sync_packages` first rsyncs the working
tree's `src/core` (being edited by other delegates) into the ignored `.packages/`, and nothing in the regenerated lock
resolves through `.packages/`: the old `sunholo/motoko_core` entry was stale, and no dependency names it. So that step
adds nothing to the lock and would touch the shared checkout. `packages/` in the checkout was clean against HEAD.
The result, with paths normalized, is **identical to a lock generated in a `git archive HEAD` workspace**. The changes:
- `sunholo/motoko_ext_abi` `7.4 → 8.0`;
- `sunholo/motoko_ext_conformance` `5.0.0 → 6.0.0`, which was also stale;
- the stale `sunholo/motoko_core` entry dropped;
- 22 entries, each at its own `ailang.toml` version (`LOCK.log`).

**`ailang check` does not read a lock entry's version.** Measured: with the ABI entry set back to 7.4, a check still
reads clean. The repo's own reader is `scripts/eval/journal_replay.sh` (`lock_abi_version`, compared by A9b), so
`p16r_lock_check.py` makes the same reads: `d83b8d63`'s lock is RED and the regenerated lock is GREEN.

## D — `examples/`

Both examples now use 8.0.
- **`smoke_a2a_delegate`** reads the names from `collect_tool_names` (the list the registration hands `ToolProvider`).
  It reads the schemas through the config channel, `collect_schemas(parse_a2a_json(a2a_config_json(cfg)).agents)`,
  which is what `DescribeTools(config)` returns. 3/3 pass.
- **`smoke_registry_roundtrip`**: the two "registers capabilities" rows cannot stay pure, because the capability list
  is built only inside `register_with_config ! {Env, FS}`. They moved to `main`, which calls the real a2a and mcp
  registrations: both ✓. The a2a name rows read `collect_tool_names` and pass.
- **Not ABI:** two *untouched* mcp parse rows fail under `ailang test`. The error is
  `intToFloat: expected IntValue ... TaggedValue` inside `std/json.decode`. The same decode + `parse_mcp_config` gives
  the right answer under `ailang run`. It is an AILANG v0.33.0 test-harness defect, reported rather than rewritten.

## Exit checks

1. **Checks:** 15 changed `.ail` (13 scripts, 2 examples) green against `6d81fbce` + these paths. These are the
   mutgate baselines, each in a fresh lock-free workspace (table in `mutgate-result.tsv`).
   `runtime_status_tool_dst` was red at `d83b8d63` inside `src/core/test/dst_harness`: `runtime.ail:40`'s
   conformance-harness import collided with `dst_harness.Scenario`. The untouched `phase_c_l1_scenarios.ail` failed
   identically. With the collision isolated it checked clean. At `6d81fbce`, which the P1.3r follow-up owns, it is
   green unaided.
2. **R-G targets these files feed** (`CHECKS.log`):
   - `world_state` **green**.
   - `compaction_dst` **green** (runtime_status_tool 5/5, scripted_cursor_probe PASS).
   - `registry_gen_check` **green**.
   - `driver_plus_no_ops`, `profile_definition`, `driver_only` **still red, not on these files.** Each one's
     acceptance script PASSes, then the Python guard stops at a classifier-2 inventory run with `--json` (exit 1):
     - `tools/ext_ambient_inventory/derive.py` reads all 18 extensions UNRESOLVED. The reason is 15 "ExtPorts field
       taken as a VALUE" hits in `packages/motoko-ext-abi/types.ail:1238-1260`, the 8.0 projections `fs_ports`,
       `ai_ports` and `intercept_ports`, which sit in every closure.
     - `tools/ext_call_inventory/derive.py` has 24 unresolved: those 15, plus compose 8 and agentcli 1.
     - Neither tool is in this part's files. The `ext_call_inventory` gap was **assigned to P1.7r** by the §9 record
       `00361f07`, which landed while this part ran; that red is behind `profile_definition` and `driver_only`.
       **The `ext_ambient_inventory/derive.py --json` gap, which is what `driver_plus_no_ops` stops on, is the same
       15 ABI projections in a second tool, and that record does not assign it.** P1.5r's rule-1 red, which sat
       behind these, was fixed by `37ad833d`.
   - Also green: `hook_guard`, `registry_multiplicity`, `ledger_parity`, `park_resume`, `ext_call_inventory_selftest`,
     and runs of the five smoke scripts.
   - `ext_hook_scope_selftest` has every `adr001_boundary` gate row ok. Its 4 failures are the tree-yield pins in
     `tools/ext_ambient_inventory/fixtures/hook_scope/expected.json`, which still expect the 7.4 tree (P1.7r's
     surface), plus "SHIPPED VERDICT MOVED", which has the same classifier-2 root as above.
3. **B:** `B-CLASSIFICATION.tsv`.
4. **Lock:** `LOCK.log`. In the primary with the new lock, `ailang check examples/smoke_a2a_delegate.ail` is clean.
5. **mutgate:** `mutgate-result.tsv`, 17 rows: 15 `.ail`, the no-op-profile guard and the lock. The spec is
   `p16r_mutgate_spec.tsv`. It ran as two halves on two fresh `git clone --shared` checkouts at `6d81fbce`, with
   exactly this part's paths applied, and with `mutgate.sh --spec … --repo …`.

`make dst` was not run.
