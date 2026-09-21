# LEG-P1.2d — registration sites, batch D (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.2d` in `PLAN-001-implement-adr-001-abi-8.md` §3 — batch D of the four batches migrating the 45
extension registration sites onto the frozen ABI 8.0. **Batch D:** `motoko-ext-compose`, `motoko-ext-herdr` — **11 sites**; compose's `runtime_cfg`, `snippet_caps`, `composition_mode`; herdr's `cfg`, `tools`, `orch`.
Batch A (the calibration) came back with **no independent defects**; its one intake finding was a
method gap — its check workspace never applied each package's own `[effects].max` — now closed by
**ADR Amendment 2** and an exit below. So this batch runs at its planned size, beside the others.

This is the largest cross-view helper migration and carries **the ADR's one measured cost claim**.

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
compose's interceptor passes `ctx.ports` to three helpers typed `ExtPorts` (`:312,326,921,1018` at `2062605` — re-find at HEAD): re-type them to the smallest ports record each uses, no dummy ports. herdr's `ExitIntent`/`WorkInFlight` renderers take `FsCtx` (`file_read` only). herdr's `register_with_config` reads `HERDR_ENV`, `HERDR_BIN_PATH`, `HERDR_PANE_ID` today: disclose **names** (or what the ADR's names-not-values rule permits), never a pane id or path **value**, in config.

**The measurement (ADR D2's cost expectation).** Hook latency **before and after** for compose's interceptor and herdr's prompt shaper, and the **retained `config` size** per extension. "Before" is 7.4: build it in a lock-free workspace from `181051d0` (7.4 ABI, 7.4 compose/herdr), never in a clone against the root lock. Same inputs, same repetitions, report median and spread. If the result does not survive the ADR's sentence that per-call decoding is cheap against a hook's cost, **stop and report the numbers** — that is an amendment with the artifact attached.

## Exit checks — run them yourself, record the output

1. **Each package checked as its own root with its own `ailang.toml`** (`pkgcheck.sh` or batch A's
   adaptation) — clean. This is the exit batch A missed; it is not optional.
2. Each package's **own tests** green (name the command); any failure shown pre-existing at `181051d0`
   in a lock-free workspace, as batch A did for compaction-structural.
3. **The P0.3 gate**: every batch-D extension's registration-shape result **passes**
   (`python3 tools/ext_ambient_inventory/derive.py --hook-scope --no-provision`). Record the tree's
   `shape pass n of 18` and `binding rejections n` **as you measure them** — batches run in parallel, so
   the totals include whatever has landed; report your own packages' rows exactly.
4. **Masked files** (`scripts/dst/compose_live_exec.ail`, `scripts/dst/declared_vs_performed.ail`, `scripts/dst/herdr_graded_dst.ail` and the eight `scripts/verify_*` herdr files): each checks on 8.0 in a workspace from committed HEAD, changed only
   where 8.0 requires; one mutgate row each.
4b. The measurement: before/after latency (median, spread, n) for both hooks; retained config bytes per extension; committed under `evidence/P1.2d/`.
5. **mutgate** from a fresh clone/workspace, spec and helpers **committed** under `evidence/P1.2d/`
   with repo-relative paths: at least one row per package (re-inline a payload → the gate rejects → red),
   one per capture (read it from a captured value instead of config → red), one per widened ceiling
   (drop the added effect → own-root check red). Known trap: `cmd | grep -q X` under `set -o pipefail`
   scores baseline red (exit 141) — log to a file, then grep it.

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P1.2d: batch D onto ABI 8.0 — 11 sites named, config through the channel
```

```
RESULT P1.2d
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
items: 11 sites in 2 packages (captures: <n>)
per_package: [<pkg>: own-root check <exit>, tests <exit>, shape <pass|fail>, ceiling added <effects>, ...]
gate_tree: shape pass <n>/18, binding rejections <n> (at <sha>)
masked: [<file>: <status>, ...]
measurement: compose interceptor <before>/<after>, herdr prompt shaper <before>/<after>, config bytes: [compose <n>, herdr <n>]
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

- Your 2 packages, your masked files, and `evidence/P1.2d/`. Not `packages/motoko-ext-abi/`
  (frozen), not another batch's package, not `src/` (except a masked file listed above), not `tools/`.
- One commit, named as above, as your last act. Stage **only your own paths** (`git add <paths>`, never
  `-A` or `.`): several delegates share this checkout. Leave every unrelated path alone, and **never run
  `git stash`**.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
