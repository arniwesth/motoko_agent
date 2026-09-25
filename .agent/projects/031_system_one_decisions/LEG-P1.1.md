# LEG-P1.1 — core to ABI 8.0: views, config, catalog, registry (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.1` in `PLAN-001-implement-adr-001-abi-8.md` §3 — the first P1 part, and the one every package batch
(P1.2a–d), the dispatch cursor (P1.3r), the evidence defaults (P1.4r) and the pin part (P1.5r) waits on.
**ADR-001 was accepted on artifacts at `P0G` (2026-09-21) and the ABI is frozen at 8.0** with
Amendment 1: you migrate `src/core` onto a contract that no longer moves. A change to the ABI now is a
numbered amendment with an artifact, never an edit.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 4, 7, 12; §3 **P1.1**, and P1.3r / P1.4r / P1.5r so
   you know what is **not** yours; §9 in full (every P0 record, P0G's ruling, the lock-trap method note
   under P0.2b).
2. `ADR-001-extension-owned-structured-decisions.md` — the acceptance rule and **"## Amendments"**; D2
   (views table `:320-327`, "no dummy ports" `:333-339`, the configuration channel: stamping `ext_config`
   from `ExtEntry.config`, the config digest over `config` **plus constructor data positions** (N58));
   D7's first and "Extensions and tooling" rows and the tooling list `:950-957`.
3. `packages/motoko-ext-abi/types.ail` at HEAD — the 8.0 contract and its view constructors (`:1030` on).
4. `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md` — **every count and line in
   the plan is from `2062605`; re-derive before you build on it.**
5. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `bff0948f`. `src/core` is byte-identical to `2062605`
except `dst_profile_coverage.ail` (P0.5), so the plan's anchors are current for every file you touch —
re-check each anyway. AILANG `v0.33.0`, the pin. **The tree is red by design** until `R-G`: the 18
extension packages are 7.4 until P1.2. Your green is `ailang check` on every module you touched, not
`make check_core`.

**`ailang.lock` trap (P0.4, P0.5, P0.2b all hit it):** path dependencies are pinned to the **primary
checkout's absolute path**. A check inside a `git clone` resolves the primary's packages, not the
clone's. For mutgate, and for any "was it red before?" comparison, use a throwaway workspace
(`evidence/P0.4-amendment-1/p04_consumer_check.sh`, `evidence/P0.5/p05_conformance_check.sh` show how)
or say plainly why your check is immune.

## What you do (plan §3 P1.1, restated)

- The host **builds the full context once and projects each view** through the ABI's exported
  constructors. No dummy ports: a helper typed `ExtPorts`/`ExtCtx` that a narrower view no longer fits
  takes `PureCtx` or the smallest ports record it uses (D2).
- **Stamp `ext_config`** on every view from `ExtEntry.config`.
- `register_with_config` consumers read **`ExtRegistration = { config, caps }`**.
- Move the **`ExtCtx` literals** and the 8 **`ExtEntry` literals** (`runtime.ail:829,1067-1068`;
  `registry_normalize.ail:264,389-391`; `ext_fixture.ail:188`). The plan's "37 in 28 files" is a
  first-review count — **re-derive it at HEAD** and record yours.
- `generate.py`'s template: **P0.5 already moved it** (`616f9f1e`). Verify; do not redo.
- `tool_catalog.ail:107-110` passes **`e.config`** to `DescribeTools`.
- `registry_normalize.ail` **rejects a legacy and a new variant in one vote family** (`:168-174,231`) and
  computes the per-epoch **config digest over `config` plus data positions** where `capability_kind`
  already reads them (`runtime.ail:1139-1151`); **`ext_set_digest` (`:1107-1122`) stays kind-only**.
- Dispatchers (`runtime.ail:402-416`, `:710-719`) **unchanged in precedence**, re-typed to views.

**Scope in `src/core`:** every module that must change for the tree's core to type-check against 8.0 —
not only `src/core/ext/*` — **except** the new behaviour of P1.3r (the per-atom cursor and stub arm in
`ext/runtime.ail`), P1.4r (evidence-default population in `session.ail`) and P1.5r (the ABI-version pin
literals). Where one of those files needs only a type re-signature to compile, that re-signature is
yours; the new behaviour is theirs.

## The inventory — a deliverable, not a side note

At HEAD, **82 files outside `packages/` name `ExtCtx`**: 16 in `src/core`, 22 in `scripts/dst`, 15
`scripts/verify_*`/`smoke_*`, 21 tool self-test fixtures under `tools/ext_ambient_inventory` and
`tools/ext_call_inventory`, 8 under `.agent/` (documents — ignore). Only part of that is yours. Commit
`evidence/P1.1/INVENTORY.tsv`: one row per file outside `packages/` and `.agent/` that names `ExtCtx`,
`ExtEntry` or `register_with_config`, with columns `file`, `sites`, `kind` (literal / type annotation /
helper signature / fixture), `exercised_by` (the make target(s) that compile it — derive from the
Makefile, don't guess), `owner` (`P1.1` done here / `P1.3r` / `P1.4r` / `P1.5r` / **`UNOWNED`**), and for
yours, `status`. Every `UNOWNED` row is a finding the orchestrator takes to the operator. Do not migrate
`scripts/` or `tools/` files to empty the list — report them.

## Exit checks — run them yourself, record the output

1. `ailang check` **clean on every module you touched** (list them with exit codes).
2. The **ext fixtures** green (`src/core/ext` tests; name the command).
3. **Line-neutral**: `make anchors` and `make driver_leaf_inventory` with no re-baseline. If either is
   unreachable on the red tree, say why and give a stand-in (e.g. the anchor table diffed before/after).
4. Precedence: a test or fixture showing the two dispatchers' vote-family precedence unchanged.
5. **mutgate** from a fresh workspace/clone, spec and helpers **committed** under `evidence/P1.1/` with
   repo-relative paths. At least: a legacy + new variant in one vote family accepted → red; `ext_set_digest`
   made to include config → red; the config digest omitting a constructor data position → red;
   `DescribeTools` passed `{}` instead of `e.config` → red. Known trap: `cmd | grep -q X` under
   `set -o pipefail` scores baseline red (exit 141) — write to a log, then grep the file.

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P1.1: core onto ABI 8.0 — views projected once, ext_config stamped, config digest, catalog config
```

Then:

```
RESULT P1.1
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
extctx_literals_at_head: <n> in <m> files (plan said 37 in 28)
extentry_literals: <n>
modules_checked: <n> clean / <n>
commands:
  - <ext fixtures> -> exit <n>
  - make anchors -> exit <n> | stand-in: <what>
  - make driver_leaf_inventory -> exit <n> | stand-in: <what>
  - mutgate.sh ... -> exit <n> (<pass>/<rows>)
inventory: evidence/P1.1/INVENTORY.tsv (<n> rows: P1.1 <n>, P1.3r <n>, P1.4r <n>, P1.5r <n>, UNOWNED <n>)
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

A view the host cannot build, a digest the data positions do not determine, a precedence the re-typing
cannot keep — **stop and report the artifact** (compile error, failing fixture). ADR changes are numbered
amendments written by the orchestrator. Do not edit the ADR or the ABI package.

## Rules that bind you

- `src/core` as scoped above, and `evidence/P1.1/`. Not `packages/` (the ABI is frozen; extension packages
  are P1.2), not `scripts/` or `tools/` (inventory them), not the Makefile.
- One commit, named as above, as your last act. Leave every unrelated modified or untracked path alone,
  and **never run `git stash`** — two unrelated files in this checkout belong to another session.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
