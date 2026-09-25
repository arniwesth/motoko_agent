# LEG-P0.6 — the scripted consumers and the `DescribeTools` example (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P0.6` in `PLAN-001-implement-adr-001-abi-8.md` §2 — **ADR freeze evidence 2(c), "ordinary success"**:
compiled ABI-8 consumers of **both** decision variants, registered as **named top-level functions
reading their configuration through `ext_config`**, plus a `DescribeTools` consumer whose catalog
differs between a configured and an empty tool set. This is the last P0 artifact before the operator's
`P0G` gate accepts the ADR. P0.4 landed the 8.0 types (`f7df893c`) under **Amendment 1** (`62bd3a83`);
P0.5 moved the conformance kit to 8.0 (`616f9f1e`). You build on both.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 7, 9; §2 **P0.6**; §9's P0.3, P0.4 and P0.5
   records (read P0.5's closely: it tells you which exits are reachable on a red tree).
2. `ADR-001-extension-owned-structured-decisions.md` — the **acceptance rule**, then **"## Amendments"**
   (the preparation constructors are `JudgeImmediate`/`JudgeQuery` and `ToolImmediate`/`ToolQuery`),
   then D2 (the two signatures `:111-137`, the registration boundary, the configuration channel and
   `DescribeTools` taking `(Json)`), D3 (the observation vocabulary your interpreters match on), freeze
   evidence **2(c)**.
3. `packages/motoko-ext-abi/types.ail` at HEAD; `packages/motoko_ext_conformance/` at HEAD (P0.5's
   `neutral_registration`, `registration_neutral`, the view constructors in `harness.ail`).
4. `scripts/dst/fixtures/adr001_boundary/v7_describe_config.ail` — the seventh review's
   configured-versus-empty probe your `DescribeTools` example grows from.
5. `.agent/projects/031_system_one_decisions/evidence/P0.5/` — `EVIDENCE.txt`, `p05_conformance_check.sh`
   (the throwaway-workspace pattern you will need), `p05_mutgate_spec.tsv`.
6. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `616f9f1e`. **The tree is red by design** from P0.4
until `R-G`: core and the 18 in-tree extensions are on 7.4 and will not check. AILANG `v0.33.0`, the pin.

**Two exits are unreachable on the red tree, and you must not chase them.** `make conformance` fails
in `scripts/dst/conformance_selftest.ail` (it registers `compaction_ai`, still 7.4), and
`make ext_hook_scope_selftest` fails closed at its provision step (all 18 extension roots are 7.4). Both
were red at P0.4's commit, before P0.5 — the orchestrator re-verified that at P0.5's intake. Your
**stand-in** for "the conformance harness green" is P0.5's pattern: check and run your consumers
against this checkout's 8.0 ABI and conformance kit in a throwaway workspace. The repo's `ailang.lock`
pins path dependencies to the **primary checkout's absolute path**, so a check in place inside a
mutgate clone resolves the primary's packages — the workspace is what makes mutgate honest.

## What you build — in `packages/motoko_ext_conformance/` (the plan's home), a new `examples/` directory

1. **A finalize consumer** (`DecisionSolverJudge`) — the completion-guard skeleton: evidence selection
   from `verification` / `tool_evidence`, **one** `DecisionRequest`, then `NoDecision` or a **bounded**
   `ContinueWithFeedback` built from its **own templates**; thresholds read from
   `interpretation_config` (the D3 projection), never hard-coded.
2. **A tool-policy consumer** (`DecisionToolPolicy`) — compares a proposed call with recent typed
   outcomes; returns `Deny(..)` or `NoOpinion`.
3. **A `DescribeTools` consumer** — its catalog comes from `ext_config`; **configured → 1 tool, empty →
   0 tools** (`configured=1 empty=0`).

Every callback — `prepare`, `interpret`, `DescribeTools` — is a **named, unshadowed, top-level
function bound directly** in the capability list, and each consumer's `register_with_config` returns
`ExtRegistration = { config, caps }`. Each consumer reads what it needs **only** through `ext_config` or
the descriptor's config projections. A **scripted backend**: exercise each consumer's `prepare` and
`interpret` against constructed `DecisionObservation`s — at least one `Answered` and one `Unavailable`
per decision consumer — and show the vote each returns. No provider, no host service, no wire.

## Exit checks — run them yourself, record the output

1. `ailang check` **clean** on every example module against the 8.0 ABI (throwaway workspace).
2. **The scripted run**: each decision consumer's vote on `Answered` and on `Unavailable`, printed; the
   `DescribeTools` example prints `configured=1 empty=0`.
3. **P0.3's gate is green on the examples** — every example's registration passes the shape result
   (`hook_scope.py`'s registration-shape pass over the example package, or its fixture runner pointed at
   it; say which and how).
4. **mutgate** from a fresh clone, after your commit, with the spec and any helper **committed in the
   repo** under `evidence/P0.6/` with repo-relative paths:
   ```
   bash .agent/projects/013_core_architecture_for_dst/mutgate.sh --spec <repo path> \
     --clone-from /workspaces/motoko_agent --repo /workspaces/mutgate-031-p06
   ```
   The plan's row: **make a consumer read a value not in `ext_config`** (a captured module-level value,
   or an inline lambda closing over one) → the gate or the compiler rejects → restore. Add at least:
   empty `ext_config` makes `DescribeTools` still return a tool → red; the finalize consumer's bound on
   `ContinueWithFeedback` removed → red. Known trap: `cmd | grep -q X` under `set -o pipefail` scores
   baseline red (exit 141); make success a real exit 0.

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P0.6: scripted finalize and tool-policy consumers + the DescribeTools example on ABI 8.0 (freeze 2(c))
```

Body: each consumer, its config fields, its named callbacks; the scripted votes; `configured=1
empty=0`; the gate result; the mutgate verdict; the pin. Then:

```
RESULT P0.6
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
consumers: [finalize: <votes on Answered/Unavailable>, tool_policy: <votes>, describe_tools: configured=<n> empty=<n>]
commands:
  - ailang check <examples> (workspace) -> exit <n>
  - scripted run -> exit <n>
  - shape gate on examples -> <pass n/n>
  - mutgate.sh ... -> exit <n> (<pass>/<rows>)
mutgate_spec: <repo path>
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

If a consumer the ADR describes **cannot be written** against the 8.0 types — a projection that does not
carry what the ADR says it does, an observation the interpreter cannot match, a `DescribeTools` catalog
that cannot depend on config — **stop and report the compile error as the artifact**. The ADR changes
only by a numbered amendment written by the orchestrator (Amendment 1 is the precedent). Do not edit
the ADR or the ABI.

## Rules that bind you

- `packages/motoko_ext_conformance/examples/` and `evidence/P0.6/` only. Not `packages/motoko-ext-abi/`
  (frozen), not P0.5's kit files, not `src/`, `tools/`, `scripts/`, not any extension package.
- One commit, named as above, as your last act. Leave every unrelated modified or untracked path alone,
  and **never run `git stash`** — two unrelated files in this checkout belong to another session.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- Fixtures and backends are synthetic: no session content, credentials or host addresses.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
