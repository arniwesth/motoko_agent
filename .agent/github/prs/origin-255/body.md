---
repo: arniwesth/motoko_agent
pr: 255
branch: arniwesth/005-w3-7-compose-ignores-hybrid-flag
ticket: null
title: "fix(compose): current_composition_mode no longer reads hybrid_tools (005 W3-7)"
---

## Summary

The Compose extension no longer reads `hybrid_tools` from its context. Until now, when the flag
was false, Compose turned its subagent mode into inline mode and denied the `Compose` tool. The
mode now comes from the extension's own config alone.

This is task W3-7 of the finalize-policy migration plan, and the operator's decision 8. It has to
land before W3-4, which has the host write `false` into the context views. Without this change
that would switch Compose's subagent mode off on the `ailang` profile.

**Why the check could go.** It dates from the first release, where the flag chose between a step
with typed tool calls and a legacy step without them, and Compose could not offer a tool in the
second. That legacy step was deleted on 2026-05-06 (`6350b7ad`). Every session has had typed tool
calls since.

**What changed in the code.** One file, `packages/motoko-ext-compose/compose.ail`:

- `current_composition_mode` returns the configured mode and nothing else.
- It and `on_tool_policy_with_mode` lose the context parameter they no longer use. Both are
  private. The exported `on_tool_policy` keeps its signature.
- A new inline test, `subagent_mode_allows_compose`: in subagent mode the tool is allowed under
  either value of the flag. `compose.ail` had no inline tests before.

**`ailang.lock` changes by two lines**, `generated_at` and the package's `content_hash`, from
`ailang lock`. Without that, every `ailang` run in the tree warns that the dependency's content
changed, and the warning reaches the stderr of Compose's routed `ailang check`.

**What this does not do.**

- The ABI's context views keep the `hybrid_tools` field, as Amendment 2 says they do.
- `scripts/dst/compose_live_exec.ail:116` still writes `false` into its context, and is
  unchanged. It configures inline mode and drives the response interceptor, which took its mode
  from config and never read the flag.
- The `ailang` profile still sets `tools.hybrid: true`. Switching it off is now possible, and is
  a separate change.
- The package version stays `0.2.4`. The `driver_plus_compose` profile record pins it.
- `.agent/plans/AILANG_Composition_Subagent.md:892-898` still describes the fallback. Marking it
  is W3-5's.

**One record no longer matches the code.** Row `compose_capture_mode_policy` of
`.agent/projects/031_system_one_decisions/evidence/P1.2d/p12d_mutgate_spec.tsv` (line 17) holds a
sed pattern for the old call `on_tool_policy_with_mode(composition_mode_of(ctx.ext_config), ctx,
call)`. The call has one argument fewer now, so the pattern would not apply. No make target or
workflow runs that spec, and it is not edited here.

## Changes

- fix(compose): current_composition_mode no longer reads hybrid_tools (005 W3-7)

2 files changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.md`, decision 8
  and work item W3-7.
- `.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`, Amendment 2,
  closed question OQ-B2.

## Predicted outcome

- **A `Compose` call in subagent mode is allowed when `hybrid_tools` is false.** Checked by the
  inline test, which fails on `main` for that value.
- **No session behaves differently today.** `ailang` is the one tracked profile that loads
  `compose`, and it sets `tools.hybrid: true`, where the old code allowed the tool too.
- **`inline` and `off` modes deny the tool as before.** Those two branches are not edited, and
  no test here covers them.
- **W3-4 can write `false` into the context views without disabling Compose.** That is checked
  when W3-4 lands, and by W3-6's live `Compose` call on the `ailang` profile.

## Test evidence

Run on 2026-10-10, AILANG v0.52.5, on `main` at `86f2b817` and on this branch at `ef5cd5f6`.

- [x] **The task's gate, as the plan writes it:**
  `env -u AILANG_FS_SANDBOX make verify_extensions driver_plus_compose compose_live_exec`.

  | | `main` | this branch |
  |---|---|---|
  | exit code | 0 | 0 |
  | `verify_extensions` | `(default): 9 booted, 0 failed` | `(default): 9 booted, 0 failed` |
  | `driver_plus_compose` | `driver_plus_compose_dst PASS` | `driver_plus_compose_dst PASS` |
  | `compose_live_exec` | `compose_live_exec PASS` | `compose_live_exec PASS` |

- [x] **`compose` boots on the profile that loads it.** The gate's `verify_extensions` reads the
  `default` profile, which does not load `compose`. So also:
  `env -u AILANG_FS_SANDBOX MOTOKO_CONFIG=ailang make verify_extensions`, exit 0,
  `✓ compose register_with_config`, `verify_extensions (ailang): 4 booted, 0 failed`.
- [x] **The inline test fails before the change and passes after.**
  `ailang test packages/motoko-ext-compose/compose.ail`.

  | | old `current_composition_mode` | this branch |
  |---|---|---|
  | exit code | 1 | 0 |
  | `hybrid_tools: false` | `expected true, got false` | passed |
  | `hybrid_tools: true` | passed | passed |

  No make target runs this file's inline tests.
- [x] **The inventories that read Compose's sources:** `env -u AILANG_FS_SANDBOX make
  --keep-going profile_definition ext_ambient_inventory ext_call_inventory ext_hook_scope
  declared_vs_performed discovery`, exit 0.
- [x] **`ailang lock` changed two lines**, and the stale-content warning it removes was seen in
  `compose_live_exec`'s output before the lock was regenerated.
- [ ] `make check_core`, `make test`, `make corpus_pr` and the full `make dst` were not run.
- [ ] No live session was run. No `Compose` call was made against a provider.
- [ ] CI had not finished when this was written.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
