# LEG-P1.6r — scripts and non-`.ail` code onto 8.0, and the root lock (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.6r` in `PLAN-001-implement-adr-001-abi-8.md` §3, added by the operator's ruling on P1.1's inventory.
The last files outside `src/core` and `packages/` that break on 8.0, and **several of them feed `R-G`'s own
targets** (`driver_plus_no_ops`, `profile_definition`, `driver_only`, `world_state`, `compaction_dst`) — so
`R-G` is red on them until you land.

## Ground truth to read first

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 7, 13; §3 **P1.6r** and **P1G = R-G** (its checklist);
   §9's P1.1 (the inventory), P1.2a–d, P1.5r records.
2. `ADR-001-extension-owned-structured-decisions.md` — acceptance rule and **"## Amendments"** 1–4.
3. `evidence/P1.1/INVENTORY.tsv` — your rows (`check8 = FAIL`, and `not checked`).
4. How the batches migrated their masked scripts: `git show a3a82311 -- scripts/` (batch D) is the richest
   worked example (`ExtCtx` literals gain the three D3 fields; entries carry config; `on_tool_handle`
   callers wrap as `ProviderCtx`; `Accept` is nullary).
5. `GATE-mutation-red-submission-precondition.md`, `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `e9212412`. ADR-001 accepted with **Amendments 1–4**; ABI
frozen at 8.0; core on 8.0 (P1.1, P1.3r, P1.4r); **all 18 extension packages on 8.0** (P1.2a–d) — the
registration-shape gate reads 18 of 18 at committed HEAD. AILANG `v0.33.0`, the pin.

**Check against committed HEAD, never the working tree** (plan §0 item 13): the P1.3r follow-up is editing
`src/core/ext/runtime.ail` now, and P1.5r's follow-up edits `src/core/dst_driver_*.ail` after it. Build any
workspace that compiles against `src/core` or `packages/` from `git archive HEAD` / `git show HEAD:<path>`.
**`ailang.lock` trap:** path dependencies are pinned to the primary checkout's absolute path; never check
inside a `git clone` against the root lock — use a lock-free workspace (`evidence/P1.2*/p12*_ws.sh`,
`evidence/P1.1/p11_core_check.sh` are the patterns). Known mutgate trap: `cmd | grep -q X` under
`set -o pipefail` scores baseline red (exit 141); rows assert **your own files' results**, never whole-tree
totals (batch C was refused on exactly that).

## Your files

**A. The 13 that fail on 8.0** — change only what 8.0 requires, keep every assertion:
- `scripts/dst/hook_guard_dst.ail`
- `scripts/dst/ledger_parity_dst.ail`
- `scripts/dst/park_resume_dst.ail`
- `scripts/dst/registry_multiplicity_dst.ail`
- `scripts/dst/runtime_status_tool_dst.ail`
- `scripts/dst/scripted_cursor_probe.ail`
- `scripts/dst/world_state_poison.ail`
- `scripts/dst/world_state_probe.ail`
- `scripts/smoke_v2_compaction_chain.ail`
- `scripts/smoke_v2_handle.ail`
- `scripts/smoke_v2_pending.ail`
- `scripts/smoke_v2_pending_full_loop.ail`
- `scripts/smoke_v2_policy_denial.ail`

**B. Non-`.ail` read-through** — classify each **needs change / comment only / fine**, change where it
must, and record the classification for every file:
- `.github/workflows/verify-extensions.yml`
- `.motoko/ab/answer-p2a.md`
- `Makefile`
- `ailang.toml`
- `design_docs/planned/m-motoko-chain-provenance.md`
- `design_docs/planned/m-motoko-ext-auto-linter.md`
- `design_docs/planned/m-motoko-ext-describe-tools.md`
- `design_docs/planned/m-motoko-ext-skills-import.md`
- `design_docs/planned/m-motoko-extensions-as-packages.md`
- `design_docs/planned/m-motoko-verify-ail.md`
- `omnigraph/extractions/batch-3.jsonl`
- `omnigraph/seed/data.jsonl`
- `phase_log.md`
- `scripts/dst/fixtures/adr001_boundary/gate/expected.json`
- `scripts/dst/run_depth_canary.sh`
- `src/tui/src/herdr-child-env.test.ts`
- `src/tui/src/runtime-process.ts`
- `tools/eval_protected/manifest-A.json`
- `tools/ext_call_inventory/fixtures/expected.json`
- `tools/ext_registry_gen/generate.py`
- `tools/profile_definition/check_compose_profile.py`
- `tools/profile_definition/check_no_op_profile.py`

(`scripts/dst/fixtures/adr001_boundary/gate/expected.json`, `tools/ext_call_inventory/fixtures/expected.json`
and `tools/eval_protected/manifest-A.json` are pinned data of other gates — change only if their own gate
proves they are stale on 8.0, and say which. Design docs, `phase_log.md`, `omnigraph/*.jsonl`,
`.motoko/ab/*` are prose/data: classify, do not rewrite — they go to 033 G4.)

**C. The root `ailang.lock`** still records `sunholo/motoko_ext_abi` at `"version": "7.4"` while its
`ailang.toml` says `8.0`. Regenerate it the way the repo does (`make sync_packages` runs
`scripts/sync-extension-packages.sh` then `ailang lock`; say which you ran and why), and show the ABI entry
at 8.0 and every other entry's version from its package's `ailang.toml`.

**D. `examples/`** — batch C removed `make_hooks` from a2a/compaction-ai; `examples/smoke_a2a_delegate` and
`examples/smoke_registry_roundtrip` import it and were already red before 031. Bring them onto 8.0 or report
exactly why not.

## Exit checks — run them yourself, record the output

1. Every changed `.ail` checks on 8.0 against committed HEAD (list with exit codes).
2. For each `R-G` target your A-files feed: the target's own run, or a stand-in that runs the file's
   entry, and whether the target is now green or still red **and on what** (another owner's red is
   reported, not chased).
3. B: the classification table, every file.
4. C: the regenerated lock's ABI entry and a clean `ailang check` of a root module that resolves through it.
5. **mutgate** from a fresh clone/workspace, spec committed under `evidence/P1.6r/`: at least one row per
   changed `.ail` (revert its 8.0 change → its check or run → red) and one for the lock (restore the 7.4 ABI
   entry → a check that reads the lock → red).

Do not run `make dst`.

## Your last act

Commit `ADR-001 (031) P1.6r: scripts, non-.ail code and the root lock onto ABI 8.0`, then print
`RESULT P1.6r` (head_before, commit, files_touched, per-file check results, R-G targets and their state,
B's classification counts, the lock's ABI entry, mutgate, could_not_run).

## Rules that bind you

- Your listed files and `evidence/P1.6r/`. Not `packages/`, not `src/core` (P1.3r's follow-up and then
  P1.5r's follow-up are its sole writers), not another part's files.
- One commit, named as above, as your last act. Stage **only your own paths**; several delegates share
  this checkout. Leave every unrelated path alone, and **never run `git stash`**.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
