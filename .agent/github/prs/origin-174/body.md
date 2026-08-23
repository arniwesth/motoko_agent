---
repo: arniwesth/motoko_agent
pr: 174
branch: arniwesth/mot-121-motoko-ext-herdr-delegate-a-sub-task-to-a-coding-agent-in-a
ticket: MOT-121
title: "MOT-121: motoko-ext-herdr — delegate a sub-task to an agent in a herdr pane"
---

## Summary

Adds `packages/motoko-ext-herdr`: two tools that hand a bounded sub-task to a coding agent running
in its own herdr pane. `Delegate` splits a pane, starts the agent, passes the task and returns a
handle; `DelegateCheck` reports state and collects the answer. herdr is the state store — no lock
file, no `delegates.json`.

Phase A of the handoff came first: the six measurements 021 §7 owed, taken against a running herdr
0.8.2 inside `agent_confined`. **Three of them overrode the spec**, and the package is built to the
measurements rather than to 021 where they disagree.

**Base is `arniwesth/mot-102-formalize-agent_confined-adr-acceptance-sweep-residuals`**, not `main`
— that branch carries `agent_confined`, without which none of this can run.

## What measurement changed

| 021 said | measured | what the code does |
|---|---|---|
| `Delegate` waits up to 25 s so fast tasks finish in one call (§4.1) | median 23.1 s, worst 91.2 s, **half exceed 25 s** — while `agent get` costs 4 ms and a prompt without `--wait` costs 3–5 ms | poll-first: submit and return a handle, never `--wait` |
| avoid #158 by having `agent prompt` read from a file (§3.1) | **v0.8.2 has no such option** — the text is an argv element | the prompt goes in a **task file**; argv carries a fixed, token-free sentence |
| the transcript is the fallback, the answer file the primary channel (§3.2) | a delegate can settle `done`, reply with the path, and have **written nothing** (seen 3×) | the file is stat'd independently; "path replied, file absent" is a named failure |

Two more that 021 could not have known:

- **herdr's `interactive_ready` is not readiness.** It came back `true` for an unauthenticated codex
  and for a claude stuck on its API-key modal. `agent explain --json` separates them
  (`matched_rule` populated, `fallback_reason` null), so `Delegate` gates on that before prompting.
  Not cosmetic: prompting the false-ready codex pressed Enter on its sign-in menu and started an
  OAuth device flow.
- **The error surface has five shapes, not §5.4's two** — herdr JSON, CLI syntax (exit 2, plain
  text), argument validation (plain text), the nested-herdr guard (ANSI plain text), and
  `ProcessError`'s seven constructors. 018 F1's one-PATH-sentence-for-everything is what the
  branches avoid.

Because the argv is token-free by construction and `cwd` travels as an ordinary argument to
`pane split --cwd`, neither of #158's triggers fires — so this package uses `ExtPorts.proc_exec`
rather than ambient `exec`. That answers 021 §7 item 4 affirmatively and recovers the WI-D24 holder
stamping 018 §2.4 had to give up.

## Two defects only a real run could find

Both were invisible to `ailang check` and both are fixed here.

1. **The pane environment never reached the extension.** 021 §4.4 has the gate read `HERDR_ENV` etc.
   in `register_with_config`. But the AILANG runtime is a *grandchild* of the pane, and
   `buildChildEnv` is an explicit allowlist — the variables were dropped, the gate correctly closed,
   and the extension advertised nothing *inside* a pane. Now forwarded, with a test covering both
   directions.
2. **The work directory cannot live in `/tmp`.** The TUI pins `AILANG_FS_SANDBOX` to the workdir,
   and a path outside it is a **fatal execution failure**, not an `Err` — the first `dir_make` killed
   the run with no diagnosis. Default moved to `<workdir>/.motoko/herdr-delegates` (gitignored), and
   `path_within` refuses out-of-sandbox directories *before* any filesystem call.

## Verification

- **107 inline `tests [...]`** in `types.ail`, all green. Every pure function carries them (018 F8).
- **The gate, both ways** — `make verify_herdr_gate`: 0 tools with the variables stripped, 2 inside
  a pane. The empty leg runs everywhere; the in-pane leg is skipped elsewhere rather than failed.
- **End to end in an `agent_confined` pane**, default profile,
  `openrouter/~deepseek/deepseek-v4-flash-latest`: Motoko called `Delegate` → pane split → claude
  delegate started → task passed off-argv in a file → delegate wrote the answer → `DelegateCheck`
  polled three times over steps 3–5 → the answer reached the model as
  *"The delegate answered: 17 × 23 = 391."* Six steps; the delegate pane was reaped on collection.
- **Both error vocabularies demonstrated** producing distinct, accurate messages.
- `make check_core` 56/56, `make test` green.
- **`make dst`** — see below. It was *not* run before this PR was first opened; that was a mistake,
  and running it found real work.

## What the DST sweep said

`make dst` reported five failures. **None were caused by this branch** — verified by running each in
a worktree at the base commit rather than inferring it — but **four were made worse by it**, in
precisely the way the framework exists to catch.

`agentcli` had been added to `[extensions]` without being declared in the profiles that enumerate the
installable set, so the base was already failing with *"extension(s) `['agentcli']` … appear in
neither this profile's install list nor its omissions"* and *"expected 15, got 16"*. `herdr` repeated
the omission and took it to 17. `driver_plus_compose` states the principle: **"an extension in
neither is a decision INHERITED rather than taken (WI-D7)."** So declaring it was an obligation.

Both are now declared, and the shared barrier reason survives on a **measurement**:
`make ext_ambient_inventory` classifies both AMBIENT. `herdr` carries 1 ambient source and 5
`ExtPorts` field calls — the one source is `std/env.getEnvOr` in the gate, which §4.4 requires, and
it is the lowest ambient count of any AMBIENT extension.

**Hook scope independently confirms the design claim above.** `agentcli` derives **HOOK-AMBIENT** —
its argv carries a model-authored prompt, so #158 forced ambient `exec` on it — while `herdr` derives
neither ambient nor port-mediated at hook scope. The expectation files are pinned in both directions,
so that is asserted, not tolerated.

**Sweep now: 5 failures → 1.** The remainder, `declared_vs_performed`, is byte-identical at base and
on this branch (41 passed, 5 FAILED) and is untouched here.

Two things the sweep says about itself, deliberately left alone: `test_coverage` and
`test_coverage_selftest` are on `DST_KNOWN_RED` and both now **pass**, and the summary asks for them
to be dropped. Not this branch's list to edit.

## Owner decision recorded

`codex` cannot run unattended in this container: its sandbox is bubblewrap, bubblewrap needs
unprivileged user namespaces, and the stock Docker seccomp profile denies `unshare` outright. Arni
chose `-s danger-full-access -a never` over `--dangerously-bypass-approvals-and-sandbox` (identical
in effect here — the sandbox half is already a no-op — but legible). It ships as `codex`'s per-kind
argv, opt-in and commented. **`claude` remains the default**: unattended with no relaxation at all,
and ~1.3× faster. Scope of the grant is written out in MEASUREMENTS §P2-7.

## Things a reviewer should push back on if they disagree

- **The spine landed as two commits, not three.** `Delegate` and `DelegateCheck` cannot be split
  without breaking the handoff's own rule that the extension must not advertise a tool it cannot
  honour — `Delegate` returns a handle only `DelegateCheck` can redeem.
- **F-5 is not closed.** Narrowest behaviour that works: `Delegate` closes the pane it created on
  failure, `DelegateCheck` closes it once settled. Nothing sweeps. Ownership is *positive*
  (`owns_name` on a `mot-dlg-` prefix), because during Phase A `agent list` returned a codex pane
  belonging to the operator that a looser rule would have destroyed.
- **`src/core/ext/registry_generated.ail`'s effect row is hand-corrected after generation.** AILANG
  v0.33.0's `generate-extension-registry` ignores `[extensions] effects` and stamps the union of
  package ceilings, reintroducing `SharedIndex` and breaking every consumer — the exact failure #159
  and commit 8916b16 describe. The row is put back to the pinned contract; the generator regression
  is upstream, not ours.

## Known-not-fixed

- `.devcontainer/agent_confined/{Dockerfile,herdr.toml}` show as modified in `git status` and are
  **not part of this PR**. `.devcontainer/**` is mounted read-only in the agent's container, so git
  cannot write them on checkout and `git checkout --` fails with EROFS. Nothing under
  `.devcontainer/**` is staged here.
- `r9-container.sh --in-container` reports one pre-existing failure, leg6
  (`host.docker.internal` resolves). Unrelated to this change and unreachable from inside the
  container. `agent.sh check` itself is host-only by design and needs an operator run.
- The TUI Jest suite has 15 pre-existing failing suites / 1 failing test, identical before and after
  this branch. This PR adds one suite and two passing tests.
- `make dst` still exits 2 on `declared_vs_performed`, which is red at base with the identical
  counts. Triaging it is a D5/017 question about barrier slots, not this branch's.

## Linear

MOT-121 (parent) · MOT-122 measurements (done) · MOT-123 skeleton · MOT-124 `Delegate` ·
MOT-125 `DelegateCheck` · MOT-126 the 019 container findings · MOT-118 closed by the cross-pointers.

Issues created through the Linear MCP server are authored by the API key's owner rather than
`motoko-agent`, because a Linear API key is personal. That is 022 F-1 and stays open.
