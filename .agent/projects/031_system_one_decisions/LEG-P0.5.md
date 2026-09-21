# LEG-P0.5 — conformance, no-op profiles, kind and arity maps against 8.0 (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P0.5` in `PLAN-001-implement-adr-001-abi-8.md` §2: the **tooling that reads the ABI** moves to 8.0 —
the conformance package, the no-op constructors, the registry generator's `ExtEntry` template, and the
kind/arity maps in three tools. P0.4 landed the 8.0 types (`f7df893c`) under **ADR Amendment 1**
(`62bd3a83`); you consume them. P0.6 (the scripted consumers) opens after you, in the same conformance
package, and its exit needs your harness green on 8.0.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 6, 7; §2 **P0.5**; §9's P0.3 and P0.4 records.
2. `ADR-001-extension-owned-structured-decisions.md` — the **acceptance rule**, then **"## Amendments"**
   (Amendment 1: the preparation constructors are `JudgeImmediate`/`JudgeQuery` and
   `ToolImmediate`/`ToolQuery`), D2's views table (`:320-327`) and residual, D7's "Extensions and
   tooling" row (`:916`) and the tooling list after it (`:950-957`).
3. `packages/motoko-ext-abi/types.ail` at HEAD — the 8.0 contract, its header's 8.x rule and the view
   constructors (`pure_ctx`, `pure_ctx_of`, …) near `:1030`.
4. The files you change, at HEAD: `packages/motoko_ext_conformance/` (`invariants.ail`, `harness.ail`);
   `tools/ext_registry_gen/generate.py` (`ExtEntry` template `:154-165`); the arity table in
   `tools/ext_ambient_inventory/hook_scope.py` (P0.3 rewrote much of this file at `19139488` — read it
   at HEAD, not at the plan's anchors); the kind list in `tools/profile_definition/check_fixtures.py`;
   the capability maps and classification in `dst_profile_coverage.ail`.
5. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `5e54996b`. **The tree is red by design** from P0.4
until `R-G` (plan §0 item 3): core and 45 registration sites are still on 7.4 and will not check. Your
green is the three exits below, not `make check_core`. AILANG `v0.33.0`, the pin.

**Known red that is not yours:** `make profile_definition` and `make driver_only` fail on 31 manifest
ABI pins now drifted to 8.0. That is ruled and owned by **P1.5r**. You edit `check_fixtures.py`'s
**kind list** only — do not touch its pin sweep, and do not repair the pins.

## What you do

- `packages/motoko_ext_conformance/` (`invariants.ail`, `harness.ail`) compiles and runs against 8.0:
  every callback on its row's view, not `ExtCtx`.
- **No-op constructors**: `DescribeTools(\_cfg . [])` and **neutral** decision callbacks for both new
  variants — a `prepare` that returns `JudgeImmediate(NoDecision)` / `ToolImmediate(NoOpinion)` and never
  queries, and an `interpret` that returns the same. Neutral means the atom exists and changes nothing.
- `generate.py`'s `ExtEntry` template (`:154-165`) emits `config` (`ExtEntry.config`) and consumes
  `register_with_config`'s `ExtRegistration = { config, caps }`.
- `hook_scope.py`'s **arity table** gains the two decision variants at their real arities, and every
  existing slot's arity is checked against its 8.0 signature.
- `check_fixtures.py`'s **kind list**: `CAPABILITY_KINDS` gains **two** kinds.
- `dst_profile_coverage.ail`: capability maps carry both new kinds; the two new **pure** slots are
  classified as ADR D2's residual states them (views plus boundary — restricted supplied authority, not
  compile-time purity).

## Exit checks — run them yourself, record the output

1. `make conformance` **green**.
2. `make registry_gen_check` **green against a fixture tree** — the real registry is red until P1, so
   build a small fixture tree for it and say where it lives and why.
3. `make ext_hook_scope_selftest` **green**, with P0.3's pins unmoved except where the arity table
   changes them — any re-pin is by hand and named in the commit.
4. **mutgate** from a fresh clone, after your commit:
   ```
   bash .agent/projects/013_core_architecture_for_dst/mutgate.sh --spec <spec.tsv committed with your work> \
     --clone-from /workspaces/motoko_agent --repo /workspaces/mutgate-031-p05
   ```
   At least: drop one of the two new kinds from `CAPABILITY_KINDS` → red; make a neutral callback
   non-neutral (e.g. `JudgeImmediate(ContinueWithFeedback(..))`) → red. Two traps already hit on this
   line: a `test_cmd` shaped `cmd | grep -q X` scores baseline red under `set -o pipefail` (exit 141);
   and this repo's `ailang.lock` pins path dependencies to the **primary checkout's absolute path**, so a
   check inside the clone can resolve the primary's packages instead of the clone's — P0.4's
   `evidence/P0.4-amendment-1/p04_consumer_check.sh` shows the fix (a throwaway workspace). **Commit the
   spec and any helper in the repo** with repo-relative paths; nothing in `/tmp` survives your session.

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P0.5: conformance, no-op profiles, kind and arity maps on ABI 8.0
```

Body: each change against its file and anchor; the two kinds added; the neutral constructors; the
registry fixture tree; any self-test re-pin; the three exit results; the mutgate verdict; the pin. Then:

```
RESULT P0.5
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
capability_kinds_added: [<two names>]
commands:
  - make conformance -> exit <n>
  - make registry_gen_check (fixture tree <path>) -> exit <n>
  - make ext_hook_scope_selftest -> exit <n>
  - mutgate.sh ... -> exit <n> (<pass>/<rows>)
mutgate_spec: <repo path>
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

A slot whose 8.0 signature cannot be given an arity, a neutral callback the types will not admit, a
classification D2's residual contradicts — **stop and report the artifact**. The ADR changes only by a
numbered amendment written by the orchestrator (Amendment 1 is the precedent). Do not edit the ADR.

## Rules that bind you

- The files above only. Not `packages/motoko-ext-abi/` (frozen at P0.4 + Amendment 1), not `src/core/ext/*`
  (P1.1), not any extension package (P1.2), not `check_fixtures.py`'s pin sweep (P1.5r).
- One commit, named as above, as your last act. Leave every unrelated modified or untracked path alone —
  and **never run `git stash`**: two unrelated files in this checkout belong to another session.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
