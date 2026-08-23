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

## Busy-polling, found on the first real run and fixed here

The operator ran the happy path and it worked — correct answer, no pane leaked, tree clean — but an
**11-second delegation cost ten `DelegateCheck` steps**, one per second, each returning the same
"still working".

Checked rather than assumed: `DelegateCheck` only called `agent get`, which returns in **4 ms**, and
a model cannot sleep — so the loop ran as fast as the model could emit tool calls. The *rate* is
model-dependent; the *behaviour* is not. Against M6's median of 23.1 s that is ~23 steps of a
100-step budget spent watching, ~90 for the worst case measured, doubled per concurrent delegate,
with history growing quadratically.

`DelegateCheck` now blocks server-side first — `herdr agent wait <name> --timeout 20000`. Four
measurements say it is safe:

| case | measured |
|---|---|
| already settled | 6 ms, exit 0 — a wait costs nothing once the answer landed |
| still working | exit 1, code `timeout`, 4201 ms for a 4000 ms bound |
| agent reaped | exit 1, `agent_not_found`, **2 ms** — a collected delegate does not block |
| settles mid-wait | exit 0 the moment it does (13.3 s of a 25 s bound) |

So `timeout` is the one non-zero code that must **not** be an error — and `types.ail` already
carried the right sentence for it, reachable until now only from `Delegate`'s old `--wait` path.

Two things deliberately not done the easy way. The wait is **unconditional, not a parameter**: the
observed failure *is* a model failing to pace itself, so a knob it must remember to set would
reproduce the bug. And it is **wait-then-check, never wait-instead-of-check**, because the wait
settles on the *agent* going idle and P2-3 measured a delegate reaching a clean `done` having
written nothing.

**Re-measured on the identical task: 11 steps → 2.** One `Delegate`, one `DelegateCheck`.

## Kind selection is operator policy, not a model token

Second finding from operator testing: a delegation ran **codex** with `HERDR_DELEGATE_KIND` unset
and `default_kind()` returning claude. The *model* passed `kind: "codex"`, and the only trace was the
pane label.

**This is a defect against a decision this PR already claims, not a new policy.** P2-7 records the
owner's decision as shipping codex's `-s danger-full-access -a never` *"opt-in, named, and attached
to its evidence"* — and the section below repeats "opt-in and commented". It wasn't: the schema
advertised codex and `Delegate` resolved `arg_str(arguments, "kind", cfg.kind)`, so a model could
take the privileged kind unilaterally. **Opt-in a model can take on its own is opt-out.**

Not a claim that codex is dangerous — P2-7's parity argument stands and is not reopened. Motoko's own
`BashExec` can do anything a full-access codex can, so no new capability enters the system. What
changes is *who decides* and whether it is legible. One real asymmetry sits under it: claude runs
under an auto-mode classifier that can still decline; `-a never` removes the approval path entirely.

`HERDR_ALLOWED_KINDS` now gates it, **defaulting to `claude` alone**. Measured, no task favours codex
here — ~1.3× slower unattended *and* it is the one needing the relaxation — so a model picking it
chooses slower and more permissive for no nameable benefit. A `claude,codex` default would not have
fixed the finding, since the model could still select codex unprompted.

**To restore the previous behaviour: `HERDR_ALLOWED_KINDS=claude,codex`.**

Three things follow. The schema now names the *allowed* set, so the model isn't invited to pick what
it cannot have. `known_kind`'s 22 kinds no longer leak through to `agent start` — `gemini` used to
spend a pane and a start timeout to learn something already known. And the grant is legible in the
**transcript**, not just the pane label: a relaxed delegate reports *"…which the operator has
permitted to run with its sandbox and approval prompts disabled"*.

### A defect found by testing the opt-in instead of assuming it

With `HERDR_ALLOWED_KINDS=claude,codex` the refusal **still fired**. `buildChildEnv` forwards a
*named* list, and the earlier fix named only the three gate variables — so every operator knob this
extension reads was unreachable (`ALLOWED_KINDS`, `DELEGATE_KIND`, `DELEGATE_DIR`,
`START_TIMEOUT_MS`, `CHECK_WAIT_MS`, `MAX_OUTPUT_CHARS`). It now forwards the `HERDR_` **prefix**:
herdr injects that family into the pane and the extension reads that family, so the family is the
unit. Enumerating members of a family that grows was the fragility, not the allowlist.

Measured on all three paths: model asks for codex under default policy → refused in 1 step, **no pane
and no start timeout spent**. Operator permits codex → runs, 2 steps, correct answer, privilege note
in the transcript. Default claude → unchanged, 2 steps, correct answer, no note.

## Elapsed time, which the polling fix silently removed

Third finding, and unlike the other two it is a **side effect of a fix rather than something that
predated it**. Before the server-side wait, ten polls made elapsed time obvious as a by-product of
the waste. After it, one call returns with an answer and the model cannot tell whether it waited
200 ms or 20 s. In a head-to-head both checks were dispatched together and returned together, fusing
the two kinds into one figure; Motoko reported *"no meaningful difference in time-to-answer"*, which
was false and which it had no instrument to disprove.

The fix was still right — two steps instead of eleven is the better trade. What it removed was an
observability nothing replaced.

**The measurement point is the whole design, and the obvious choice is worse than nothing.**
`now − start` at the *end* of the handler would have reported claude 26.3 s and codex 22.3 s on that
run — **inverting** the true 15.7 s / 18.9 s, because both results return at the later wait's
boundary. Timestamping immediately after the wait *returns* recovers the true figures, whether
concurrent tool calls run sequentially or in parallel.

**The handle is the only start time available.** `herdr agent get` carries no timestamp — sixteen
fields, none time-like — and herdr is the state store by design. Parsing a name is normally a poor
dependency; it's acceptable here because `delegate_name` and `start_ms_of` are adjacent in one module
and pinned by a round-trip test, so changing the format without changing the parser fails the build.

**What the number is**, stated precisely because the obvious reading is slightly wrong: handle
creation → delegate *settling*, spanning pane split, `agent start`, the readiness gate, the work, and
the wind-down after the answer is written. It is **not** the answer file's mtime, which is
unreachable (`path_stat` returns a kind, no timestamp). Verified against ground truth — reported
14.5 s/23.0 s where files landed at 12.7 s/19.0 s, so the lag is ~1.8 s and ~4.0 s. The ratio survives
(1.59 vs 1.50 true) and the ordering never wobbles, which is what comparing kinds needs.

It also distinguishes **exact from bounded**: if the wait blocked, the figure is real; if it returned
at once, the message says *"at most … an upper bound"* rather than asserting a runtime it cannot know.

`Delegate` now reports its own setup cost too — *"Starting it took 4.0s"* — which is what made two
`Delegate` calls in one step land 3.9 s apart with nothing saying why. Timing is in metadata as well
as prose (`started_ms`, `elapsed_ms`, `waited_ms`, `elapsed_is_exact`).

**Re-measured on the same head-to-head shape:** the model now concludes *"claude finished first at
14.5s, codex took 23.0s"* instead of "no meaningful difference".

## Owner decision recorded

`codex` cannot run unattended in this container: its sandbox is bubblewrap, bubblewrap needs
unprivileged user namespaces, and the stock Docker seccomp profile denies `unshare` outright. Arni
chose `-s danger-full-access -a never` over `--dangerously-bypass-approvals-and-sandbox` (identical
in effect here — the sandbox half is already a no-op — but legible). It ships as `codex`'s per-kind
argv, opt-in and commented. **`claude` remains the default**: unattended with no relaxation at all,
and ~1.3× faster. Scope of the grant is written out in MEASUREMENTS §P2-7.

## Why a 020 commit is riding along

`a8320ea` is a **cherry-pick of the code half of `f338d9b`** (020 / PR #173), and it is here
deliberately rather than by accident.

The defect: herdr accepts a `report-agent` only when `--seq` is strictly greater than the last it
accepted for that `(pane, source)`, and that high-water mark survives both `release-agent` and the
reporting process exiting. A counter starting at 1 in each new process is therefore dropped for the
whole of a *second* Motoko run in the same pane — silently, because herdr rejects server-side and
the CLI still exits 0. The operator hit it twice while testing this package.

`#173` fixes it, but **it is a sibling of this branch, not an ancestor** — both are cut from mot-102,
so nothing #173 does reaches here, and it sits six PRs deep in the stack. Waiting was not a plan for
anyone running Motoko on this branch today.

Verified before keeping it: two files, both `src/tui/src/herdr-agent-state.*`; **no** 020 ADR content
(that record stays with #173, so the eventual rebase is not made worse); the resulting
`herdr-agent-state.ts` is byte-identical to `f338d9b`'s apart from this branch's own MOT-118 comment
block, and the test file is byte-identical. `tsc` clean, herdr suites 17 passing.

Verified *behaviourally*, which matters more than that it merged: three consecutive Motoko runs in
one pane, with `state_change_seq` advancing **207 → 209** on the third — so the repeat run's reports
are accepted rather than dropped, and the row is live rather than stale.

**At rebase time: drop `a8320ea`.** Once mot-102 carries `f338d9b`, this is patch-identical to its
code half and git will usually spot it. Also noted in the commit message.

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
