# LEG-P1.5r-a3 — the last ABI readers: found by the R-G pre-gate (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). This is a **third follow-up on P1.5r** — the
part that owns tools reading the ABI's version and text at a pinned value. The orchestrator's `R-G`
pre-gate at `12a8ecd9` (`evidence/R-G/SUMMARY.tsv`, `logs/`) ran every `R-G` target: 12 of 16 green, and
three of the four reds are this class. Each was hidden behind an earlier red until P1.7r's classifier fix
unmasked it. You do not edit the ADR or the plan, you do not write the dagr run file, and you do not touch
other panes or worktrees.

## What is red, and why

1. **`make profile_definition`, `make driver_only`** — `tools/profile_definition/check_fixtures.py:161`,
   `check_omission_basis()`: `re.search(r"BudgetShaper\(\(ExtCtx,\s*BudgetPlan\)…", abi)` → at 8.0 the
   payload is `BudgetShaper((PureCtx, BudgetPlan) -> BudgetPatch)` → `FAIL: could not read
   Capability.BudgetShaper's payload`. Re-point it at the 8.0 text **keeping what it asserts** (the return
   type and the row — WI-B4's omission basis), exactly as P1.5r did for `run_declared_vs_performed.sh:124`.
   Then grep **every** ABI-text regex in `tools/` and `scripts/` for a 7.4 context name
   (`ExtCtx` inside a `Capability` payload pattern) — any other one is yours too; list them all.
2. **`make declared_vs_performed`, 130 passed / 5 failed** (`logs/declared_vs_performed.log`):
   - `IMPORTED SUM (named-wide)` (`scripts/dst/run_declared_vs_performed.sh:~966-980`, the B8 block using
     `write_abi_ctor`): the probe builds `Compactor(impl)` with `impl: (ExtCtx, [Msg]) -> …`; at 8.0 the slot
     takes `AiCtx`, so it is rejected **for the wrong reason** and the row says it "establishes nothing".
     Re-point the B8 block's probes at 8.0 types so each rejects/accepts for the reason it measures.
     Check its sibling rows (unannot, annot, exact-ctl, smuggle) the same way even though they pass.
   - **Four absorption pins**: `register_with_config` rows 17 → 16; `Env` 17 → 16; `FS` 15 → 13;
     `Process` 9 → 3. These are **measurements the migration really moved** (8.0 moved effectful payloads out
     of registration functions into named top-level functions). Do **not** just edit the numbers: re-read
     the note in `scripts/dst/declared_vs_performed.ail` the failure names, state what each new count means
     for "how much the WI-D6/D7/D8 slot narrowings actually enforce", re-pin by hand, and put that
     explanation in the commit and in the note.

The fourth red (`cd src/tui && bun run test`: 420/420 tests pass, 5 suites fail on a Jest teardown
import from `env-server.test.ts`) is **pre-existing at `2f3ee4d1`** and is the operator's to rule on. Not yours.

## Grounding and rules

Branch `arniwesth/031-abi-8-0`, HEAD at or after `12a8ecd9`; the tree is fully migrated (gate 18/18). You are
the only delegate running. ABI frozen at 8.0 (Amendments 1–4). `check_fixtures.py`'s other rules and the ADR
section of `run_declared_vs_performed.sh` (P0.2/P0.2b's rows, 72/0) stay as they are. Traps as in every brief:
lock-free workspaces for anything that compiles; `cmd | grep -q X` → exit 141; mutgate rows assert your own
results.

## Exit checks

1. `make profile_definition`, `make driver_only`, `make declared_vs_performed` — **green** in the primary
   checkout at your commit (nothing else is writing). If one stays red, say exactly on what.
2. The full list of ABI-text regexes you found, and what each now matches.
3. The four re-pinned counts with their explanation.
4. mutgate from a fresh clone, spec under `evidence/P1.5r-a3/`: revert the `check_fixtures.py` pattern → red;
   revert a B8 probe to `ExtCtx` → "establishes nothing" red; change one absorption pin by one → red.

Last act: commit `ADR-001 (031) P1.5r: third follow-up — the last ABI-text readers and the absorption re-pins`,
then print `RESULT P1.5r-a3`. Stage only your paths; never `git stash`; do not edit the plan/ADR/`.dagr/`;
do not touch pane `w3:p1`, tab `w3:t1`, pane `w3:pZ` or `/workspaces/motoko_agent-eval`.
