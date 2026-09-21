# LEG-P1.2a — registration sites, batch A: the calibration batch (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.2a` in `PLAN-001-implement-adr-001-abi-8.md` §3 — the first of four batches migrating the 45
extension registration sites onto the frozen ABI 8.0. **This batch is the calibration**: the orchestrator
records its item count and how many items come back defective at intake, and that measured rate caps
the size of batches B, C and D (plan §0 item 12; `.agent/meta-decisions/measure-review-loop-convergence…`
rule 4). Care here is worth more than speed.

**Batch A:** `compaction-structural`, `decision-framework`, `empty-stop-guard`, `microrag`, `omnigraph`,
`progress-contract-guard` — **9 sites, 1 capture** (omnigraph's cached prompt).

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 7, 12; §3 **P1.2** (the table and the per-batch
   rule); §9 in full, especially **P0.3** (the gate and its measured tree count), **P0.4**, **P0.6** (how a
   consumer takes its configuration through the channel), **P1.1** (core on 8.0).
2. `ADR-001-extension-owned-structured-decisions.md` — the acceptance rule and **"## Amendments"**; D2:
   the registration boundary (every payload a **named, unshadowed, top-level function bound directly**),
   the `{ config, caps }` grammar, the configuration channel and its **names-not-values** convention for
   environment captures (`:370-372`).
3. `REVIEW-adr001-v0.6-verdicts-codex.md` **§Q-1** — the 45-row site ledger; your 9 rows are there.
   Verified by `REVIEW-adr001-v0.7-verdicts-claude-fable-5-1.md` §A.5.
4. `.agent/projects/031_system_one_decisions/evidence/P1.1/INVENTORY.tsv` — the rows owned by `P1.2a`
   and the `UNOWNED` rows marked `pkg-7.4 (compaction_structural)` / `pkg-7.4 (empty_stop_guard)`.
5. `packages/motoko-ext-abi/types.ail` at HEAD; `packages/motoko_ext_conformance/examples/` (P0.6's
   consumers — the shape a migrated registration takes).
6. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `b509a191`. ADR accepted, ABI frozen at 8.0; core on 8.0
(P1.1). AILANG `v0.33.0`, the pin. The other 12 packages stay 7.4 until batches B–D, so the tree stays red.

## What you do

For each of batch A's 9 sites: the payload becomes a **named top-level function bound directly** in the
capability list; `register_with_config` returns **`ExtRegistration = { config, caps }`**; each callback
takes its row's **view**, not `ExtCtx`; every captured registration value goes through **`config`**
(omnigraph's cached prompt is the one capture), encoded once if several callbacks use it; no
environment **value** captured into config (names, not values); the package's `ailang.toml` pins ABI
**8.0**. No dummy ports: a helper a narrower view no longer fits takes `PureCtx` or the smallest ports
record it uses.

## Exit checks — run them yourself, record the output

1. `ailang check` **clean on each of the 6 packages** against 8.0.
2. Each package's **own tests** green (name the command per package).
3. **The P0.3 gate on the batch**: every batch-A extension's registration-shape result **passes**. On the
   tree, `make ext_hook_scope` should now read **shape pass 6 of 18** and **binding rejections 32**
   (35 − omnigraph's 2 − progress-contract-guard's 1). Record the numbers you get; if they differ,
   report why — do not tune the gate.
4. `src/core/test/integration_tests.ail` — P1.1 left it failing only on its `compaction_structural`
   import. Check it now and report.
5. The `UNOWNED` inventory rows masked by your packages (`pkg-7.4 (compaction_structural)`,
   `pkg-7.4 (empty_stop_guard)`): **check each and report its status. Do not migrate them** — their
   owner is pending an operator ruling.
6. **mutgate** from a fresh clone/workspace, spec and helpers **committed** under `evidence/P1.2a/` with
   repo-relative paths. At least one row per package: re-inline one payload as a lambda → the gate
   rejects → red; for omnigraph, read the cached prompt from a captured module value instead of config →
   red. **`ailang.lock` trap:** path dependencies are pinned to the primary checkout's absolute path, so a
   package check inside a `git clone` resolves the **primary's** packages — build a throwaway workspace
   (`evidence/P0.4-amendment-1/p04_consumer_check.sh`, `evidence/P1.1/p11_core_check.sh` are the
   patterns). Known trap: `cmd | grep -q X` under `set -o pipefail` scores baseline red (exit 141).

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P1.2a: batch A onto ABI 8.0 — 9 sites named, config through the channel
```

```
RESULT P1.2a
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
items: 9 sites in 6 packages (captures: <n>)
per_package: [<pkg>: check <exit>, tests <exit>, shape <pass|fail>, ...]
gate_tree: shape pass <n>/18, binding rejections <n> (expected 6/18, 32)
integration_tests.ail: <status>
masked_rows: [<file>: <status>, ...]
commands:
  - mutgate.sh ... -> exit <n> (<pass>/<rows>)
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

A site that cannot be written as a named function bound directly, a capture that cannot go through
config, a view that does not fit a slot — **stop and report the artifact** (compile error, gate output).
ADR changes are numbered amendments written by the orchestrator.

## Rules that bind you

- The 6 batch-A packages and `evidence/P1.2a/`. Not `packages/motoko-ext-abi/` (frozen), not another
  package, not `src/`, `scripts/`, `tools/`.
- One commit, named as above, as your last act. Stage **only your own paths** (`git add <paths>`, never
  `git add -A` or `.`): another delegate is editing scripts and tools in this checkout (P1.5r). Leave
  every unrelated path alone, and **never run `git stash`**.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
