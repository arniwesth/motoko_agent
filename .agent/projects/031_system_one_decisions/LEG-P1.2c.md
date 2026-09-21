# LEG-P1.2c — registration sites, batch C (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.2c` in `PLAN-001-implement-adr-001-abi-8.md` §3 — batch C of the four batches migrating the 45
extension registration sites onto the frozen ABI 8.0. **Batch C:** `motoko-ext-a2a`, `motoko-ext-agentcli`, `motoko-ext-ailang-docs`, `motoko-ext-mcp`, `motoko-ext-compaction-ai` — **11 sites**; records, lists and **four `DescribeTools(config)`** — the configuration channel under load.
Batch A (the calibration) came back with **no independent defects**; its one intake finding was a
method gap — its check workspace never applied each package's own `[effects].max` — now closed by
**ADR Amendment 2** and an exit below. So this batch runs at its planned size, beside the others.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 7, 12, **13**; §3 **P1.2** (the table, the per-batch
   rule, the **masked files** paragraph); §9's **P0.3**, **P0.6**, **P1.1**, **P1.2a** records.
2. `ADR-001-extension-owned-structured-decisions.md` — acceptance rule and **"## Amendments"**: Amendment 1
   (`JudgeImmediate`/`JudgeQuery`, `ToolImmediate`/`ToolQuery`) and **Amendment 2** (a package's
   `[effects].max` admits the full row of every slot it registers); D2: payloads are **named, unshadowed,
   top-level functions bound directly**, `{ config, caps }`, the configuration channel and its
   **names-not-values** rule for environment captures (`:370-372`), no dummy ports (`:333-339`).
3. `REVIEW-adr001-v0.6-verdicts-codex.md` **§Q-1** — the 45-row site ledger (your 11 rows).
4. **Batch A as the worked example**: `git show df2df96e` and `evidence/P1.2a/` (`p12a_ws.sh`,
   `p12a_core_check.sh`, the mutgate spec) — reuse its workspace scripts rather than rebuild them.
5. `evidence/amendment-2/pkgcheck.sh` — checks one package as its own root with its own `ailang.toml`.
6. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `6a6041d2`. ADR accepted with Amendments 1–2; ABI frozen
at 8.0; core on 8.0 (P1.1). AILANG `v0.33.0`, the pin. Other batches run **beside you in `packages/`**
on disjoint packages, and **P1.3r is editing `src/core/ext/runtime.ail` right now** (the core lane).

**Check against committed state, never another part's working tree** (plan §0 item 13). Anything that
compiles against `src/core` — your masked files, anything importing core — is checked in a workspace
built from **committed HEAD** (`git archive HEAD src/core …` or `git show HEAD:<path>`), not from the
checkout. **`ailang.lock` trap:** path dependencies are pinned to the primary checkout's absolute path;
never check inside a `git clone` against the root lock — use a workspace, as batch A did.

## What you do

For each site: the payload becomes a **named top-level function bound directly** in a literal `caps`;
`register_with_config` returns **`ExtRegistration = { config, caps }`**; each callback takes its row's
**view**; every captured registration value goes through **`config`** (encoded once if several callbacks
share it), and no environment **value** is captured into config; the package's `ailang.toml` pins ABI
**8.0**; its **`[effects].max` admits the full row of every slot it registers** and nothing beyond what
its code performs (Amendment 2 — say per package what you added). No dummy ports: a helper a narrower
view no longer fits takes `PureCtx` or the smallest ports record it uses.
compaction-ai threads `ExtCtx` through its chain (ADR D2 `:337`): re-type it to the views, no dummy ports. Each `DescribeTools` payload is a named function of the extension's config; its catalog **differs between a configured and an empty config** (P0.6's `configured=1 empty=0` pattern).

## Exit checks — run them yourself, record the output

1. **Each package checked as its own root with its own `ailang.toml`** (`pkgcheck.sh` or batch A's
   adaptation) — clean. This is the exit batch A missed; it is not optional.
2. Each package's **own tests** green (name the command); any failure shown pre-existing at `181051d0`
   in a lock-free workspace, as batch A did for compaction-structural.
3. **The P0.3 gate**: every batch-C extension's registration-shape result **passes**
   (`python3 tools/ext_ambient_inventory/derive.py --hook-scope --no-provision`). Record the tree's
   `shape pass n of 18` and `binding rejections n` **as you measure them** — batches run in parallel, so
   the totals include whatever has landed; report your own packages' rows exactly.
4. **Masked files** (`scripts/dst/conformance_selftest.ail`, `scripts/dst/long_qwen_compaction_dst.ail`): each checks on 8.0 in a workspace from committed HEAD, changed only
   where 8.0 requires; one mutgate row each.
4b. Every `DescribeTools` in the batch: catalog for its real config vs `{}` shown, and they differ where the extension's tools depend on config.
5. **mutgate** from a fresh clone/workspace, spec and helpers **committed** under `evidence/P1.2c/`
   with repo-relative paths: at least one row per package (re-inline a payload → the gate rejects → red),
   one per capture (read it from a captured value instead of config → red), one per widened ceiling
   (drop the added effect → own-root check red). Known trap: `cmd | grep -q X` under `set -o pipefail`
   scores baseline red (exit 141) — log to a file, then grep it.

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P1.2c: batch C onto ABI 8.0 — 11 sites named, config through the channel
```

```
RESULT P1.2c
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
items: 11 sites in 5 packages (captures: <n>)
per_package: [<pkg>: own-root check <exit>, tests <exit>, shape <pass|fail>, ceiling added <effects>, ...]
gate_tree: shape pass <n>/18, binding rejections <n> (at <sha>)
masked: [<file>: <status>, ...]
describe_tools: [<pkg>: configured=<n> empty=<n>, ...]
commands:
  - mutgate.sh ... -> exit <n> (<pass>/<rows>)
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

A site that cannot be a named function bound directly, a capture that cannot go through config, a view
that does not fit a slot, a measurement the ADR's sentence does not survive — **stop and report the
artifact**. ADR changes are numbered amendments written by the orchestrator (Amendments 1 and 2 are the
precedent).

## Rules that bind you

- Your 5 packages, your masked files, and `evidence/P1.2c/`. Not `packages/motoko-ext-abi/`
  (frozen), not another batch's package, not `src/` (except a masked file listed above), not `tools/`.
- One commit, named as above, as your last act. Stage **only your own paths** (`git add <paths>`, never
  `-A` or `.`): several delegates share this checkout. Leave every unrelated path alone, and **never run
  `git stash`**.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
