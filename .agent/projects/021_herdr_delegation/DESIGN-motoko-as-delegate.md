# Motoko as a delegate kind — validated recipe, verification, and why it is not in PR #174

Date: 2026-08-23
Status: **Design + measurements. Not implemented.** Recommended as its own change; see §5.
Linear: **MOT-127**. Relates to MOT-121 (PR #174), MOT-125, MOT-120.
Provenance: prototyped end to end by the operator's tester; the measurements in §2 are theirs,
those in §3 are this session's verification and one correction that improves the recipe.

---

## 1. The recipe, and why it cannot use `agent start`

`agent start --kind` takes a fixed list of 22 baked into the herdr binary. `motoko` is not on it and
cannot be — 020 ADR-001 option B, closed. But Motoko does not need detection: it is a lifecycle
**authority** (020 D1), so it announces itself.

```
herdr pane run <pane> "./scripts/run-agent.sh '<task text>'"
```

The task travels as **argv[2]** (`index.ts`, preserved by `parseMotokoFlags`), which sidesteps both
channels this package cannot use: `agent prompt` refuses reported agents ("not an active named
agent"), and `pane send-text` is screen-driving, which the handoff's *Stop and report* list forbids.

## 2. Measured by the operator's tester

| | |
|---|---|
| live `motoko` row after `pane run` | **0.8 s** (vs 3.9 s for `agent start --kind claude`) |
| answer correctness | matched an independent ground-truth check |
| the 22–26 s in the 020 briefing | was `make run` doing `check_core` + `tsc`; the build is already done, so `run-agent.sh` direct is the right entry point |

## 3. Verified here, including one correction that improves the recipe

**3.1 `agent rename` works on a self-reported agent — so the existing handle model extends
unchanged.** This is the important one. Measured: row live in 869 ms, then

```
herdr agent rename w1:p1B mot-dlg-selftest   -> ok
herdr agent get mot-dlg-selftest             -> name: mot-dlg-selftest  agent: motoko  pane: w1:p1B
```

The tester flagged naming as MOT-120 territory — every motoko delegate reports the label `motoko`,
so `agent list` cannot disambiguate. `rename` resolves it **for this package's delegates without
needing MOT-120 settled**: generate `mot-dlg-<ms>` as usual, rename the reported agent to it, and
`agent get <name>`, `owns_name`'s prefix ownership and self-exclusion all keep working. No new state,
no parallel handle model.

**3.2 The startup-idle trap is real.** Confirmed by observation: the row read `motoko idle` at 869 ms
with the task not yet begun. That is 020 D2's deliberate initial report. Consequence for the code as
it stands today: `is_settled("idle")` returns true, so `DelegateCheck` would take the settled branch,
find no answer file, and report the **P2-3 "finished but never wrote"** failure — against a delegate
that has not started. The gate must be the answer file, never the agent state.

**3.3 It does not stop after answering.** Confirmed: `working` for 18 s+ after the answer landed.
Reaping must be an explicit `pane close` triggered by the answer file, not by waiting for a settle
that never comes.

**3.4 The sandbox question, settled — the existing `register.ail` comment is correct.** The tester
saw a motoko delegate write to `/tmp` and flagged that it might contradict the fatal-sandbox comment
the `work_dir` reasoning rests on. Both are true and there is no contradiction:

| access, under `AILANG_FS_SANDBOX=/workspaces/motoko_agent` | result |
|---|---|
| Motoko's own `std/fs` (`mkdirAllResult("/tmp/…")`) | **fatal** — `execution failed: path "/tmp/…" escapes sandbox`, kills the run |
| a subprocess it spawns (`exec("bash", …)` writing `/tmp`) | **writes freely** — the sandbox does not reach it |

Their hypothesis was right: the delegate wrote via its own BashExec. The `work_dir` reasoning is
about **Motoko's own reads** of the answer file and stands unchanged.

## 4. What the implementation would have to be

Not a 23rd `kind`. `kind_default_args` and `argv_start` do not apply, so this is a **second lifecycle
behind the same two tools**, selected explicitly:

| step | claude/codex | motoko |
|---|---|---|
| spawn | `pane split` → `agent start --kind` | `pane split` → `pane run './scripts/run-agent.sh <task>'` |
| addressing | name from `agent start` | **`agent rename` to the same `mot-dlg-<ms>` handle** (§3.1) |
| readiness | `agent explain --json` rule match | the row appearing (~0.8 s) |
| task delivery | task file + `agent prompt` | **argv[2]** — the task file is still the right carrier for the text; only paths interpolate |
| completion | `agent wait` + answer file | **answer file only** (§3.2) |
| reaping | `pane close` on settle | **`pane close` on answer file** (§3.3) |

Three of six steps differ, which is why this is a branch rather than a table entry.

**One tension to resolve.** `pane run` goes through the pane's shell, so the command string carries
quotes — and `argv_is_safe` as written would refuse it. The guard exists to stop #158 mangling a
`herdr` argv; a `pane run` payload is a different thing being protected against a different failure.
It needs its own predicate, not a loosened one. Do not widen `argv_is_safe`.

## 5. Why this is not in PR #174 — a recommendation, not a refusal

The feature is worth having and the recipe works. It should be its own change, for four reasons:

1. **#174 is a defect-fix PR.** It has already absorbed four field findings. This is a feature with
   its own lifecycle path.
2. **It closes decisions that are the owner's** — recursion depth and cost — which the handoff's
   scope fence reserves.
3. **It would make F-5 materially worse while F-5 is still open.** §5.1's orphan is currently a
   coding agent. A motoko orphan is an **orchestrator**, which can spawn its own delegates: orphans
   that beget orphans. Shipping recursive self-delegation without an orphan story would close F-5 by
   implementation, in the worst direction.
4. **The current check path would actively misreport it** (§3.2), so it is not an additive change.

## 6. The recursion question, with a mechanism

Recursion is live — the tester measured `ext: … herdr` on the delegate's own status line, so a
motoko delegate can delegate.

**Recommendation: default it off, depth 1, and make the limit an operator knob.** The mechanism
already exists as a side effect of this PR's env fix: `buildChildEnv` now forwards the whole `HERDR_`
prefix, so a `HERDR_DELEGATE_DEPTH` set on a delegate's pane reaches that delegate's own extension.
Increment on spawn, refuse above the limit, and the recursion is bounded by construction rather than
by hoping.

Defaulting to no recursion is the safe start: the cost of a runaway tree of LLM agent loops
(`max_steps` 100 each, no budget propagation between parent and delegate) is unbounded and nothing
in the current design would notice it happening.
