# LEG-P1.5r-a2 — follow-up: the ABI version text a literal sweep cannot see (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). This is a **follow-up attempt on P1.5r**
(`3eb6b71a`, accepted), for findings P1.5r reported and the orchestrator assigned back to it. You do not
edit the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What remains (P1.5r's own findings, `evidence/P1.5r/README.md`)

1. **Rule-1 profile-record prose** — `tools/profile_definition/check_fixtures.py`'s `check_abi_version()`
   **rule 1** checks the ABI version named in profile-record `note:` strings, a different set from rule 2's
   pins (which P1.5r moved). Four still say `ABI 7.4`, so rule 1 fails at 8.0 and keeps `make
   profile_definition` / `make driver_only` red at `R-G` even once everything else is green:
   `src/core/dst_driver_only.ail:882`, `src/core/dst_driver_plus_compose.ail:734`,
   `src/core/dst_driver_plus_no_ops.ail:689`, `src/core/dst_driver_plus_herdr.ail:333` (re-find at HEAD).
2. **`herdr_abi_version() -> string { "7.4" }`** (`src/core/dst_driver_plus_herdr.ail:137`) feeds
   `herdr_graded_dst.ail`'s `record_manifest(…)` — a manifest ABI pin in substance that the literal sweep
   misses because it arrives through a call. It reads `8.0`, and the sweep learns to see it **or** the
   function is replaced by a reference to a single source of the version — say which and why.

Say, in the envelope, whether any **other** version-bearing call or prose of either kind exists in the tree
(grep the pattern classes, not just these files) — a third instance found now is cheaper than at `R-G`.

## Grounding and rules

Branch `arniwesth/031-abi-8-0`, HEAD at or after `6d81fbce`. ABI frozen at 8.0 (Amendments 1–4); all 18
packages on 8.0. **You are the sole writer in `src/core`** now (plan §0 item 13). P1.6r and P1.7r run beside
you in `scripts/`, `tools/` — they check against committed HEAD. `check_fixtures.py` is **P1.5r's** (rule 2
was its work); you may change rule 1 and the sweep, nothing else in it. `ailang.lock` trap and mutgate traps
as in every brief: lock-free workspaces (`evidence/P1.1/p11_core_check.sh`); `cmd | grep -q X` → exit 141;
rows assert your own files' results.

## Exit checks

1. `python3 tools/profile_definition/check_fixtures.py` rule 1 and rule 2 both pass at 8.0 — run each
   standalone (P1.5r added `--abi-pins`; add the equivalent for rule 1 if there is none) and record it.
2. Every touched `src/core` module checks on 8.0 (`p11_core_check.sh`); `make anchors`,
   `make driver_leaf_inventory` byte-identical (these files carry pinned anchors? check, and say).
3. `make profile_definition` and `make driver_only`: run them; if still red, name exactly on what and whose.
4. mutgate from a fresh clone, spec under `evidence/P1.5r-a2/`: revert one note to `ABI 7.4` → rule 1 red;
   revert `herdr_abi_version()` → the sweep (or its replacement) red.

Last act: commit `ADR-001 (031) P1.5r: follow-up — rule-1 profile prose and herdr_abi_version() at 8.0`, then
print `RESULT P1.5r-a2`. Stage only your paths; never `git stash`; do not edit the plan/ADR/`.dagr/`; do not
touch pane `w3:p1`, tab `w3:t1`, pane `w3:pZ` or `/workspaces/motoko_agent-eval`.
