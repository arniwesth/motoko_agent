# LEG-P1.7r — the tool self-test fixtures onto 8.0 (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.7r` in `PLAN-001-implement-adr-001-abi-8.md` §3, added by the operator's ruling on P1.1's inventory:
fixtures whose **expected verdicts are pinned in a self-test**. Per fixture you either **migrate it to 8.0**
or **keep its 7.4 shape deliberately** because the gate is testing the old form — and record which, with
the reason. `make ext_hook_scope_selftest` is on `R-G`'s checklist; `ext_ambient_inventory_selftest` and
`ext_call_inventory_selftest` are DST targets.

**Your scope is 17 fixtures**, all under `tools/ext_ambient_inventory/fixtures/`:
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_capability_list_empty.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_capability_list_inline.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_capability_list_named_wide.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_capability_list_same_kind.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_ext_ports_call.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_hook_reaches_env.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_interpolated_call.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_named_hook_in_register.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/control_registration_only.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/reject_applied_local.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/reject_binding_unresolvable.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/reject_capability_list_arity.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/reject_capability_list_computed.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/reject_capability_list_element.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/reject_capability_list_juxtaposed.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/reject_capability_list_unknown_kind.ail`
- `tools/ext_ambient_inventory/fixtures/hook_scope/reject_unknown_callee.ail`

The inventory also marked **39 files under `scripts/dst/fixtures/adr001_boundary/`** as gate fixtures. The
orchestrator has dispositioned them **kept, not yours**: they are P0.2's frozen regression suite — byte-
identical to the reviews' quoted sources under `scripts/dst/adr001_boundary_provenance.py`, written against
their **own local types** (not the ABI), scored by `run_declared_vs_performed.sh`'s ADR section (72/0).
**Do not touch them**; if your work shows one breaks on 8.0, stop and report it.

## Ground truth to read first

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 7, 13; §3 **P1.7r**; §9's **P0.3** (the gate, its
   self-test re-pins), **P0.5** (the arity table), **P1.1**, **P1.2a–d**.
2. `ADR-001-extension-owned-structured-decisions.md` — acceptance rule, **"## Amendments"** 1–4; D2's
   registration boundary and the shape rule.
3. `tools/ext_ambient_inventory/hook_scope.py` and `derive.py` — how each fixture's verdict is pinned
   (the self-test's expected yields), and `tools/ext_call_inventory/` for its self-test.
4. `GATE-mutation-red-submission-precondition.md`, `mutgate.sh` (013).

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

**The self-tests may now provision.** P0.5 and P1.1 recorded `make ext_hook_scope_selftest` failing closed
at its cache precondition because the 18 extension roots were 7.4. They are all 8.0 now. Run the three
self-tests first, as they stand, and record exactly what fails and why before changing anything.

## Exit checks — run them yourself, record the output

1. `make ext_hook_scope_selftest`, `make ext_ambient_inventory_selftest`, `make ext_call_inventory_selftest`
   — **green**; if one stays red for a reason outside your 17 files, say exactly what and whose.
2. A table of the 17: migrated / kept-7.4, and for every kept one, the gate behaviour it pins.
3. `closure_port_mediated` and P0.3's registration-shape pins: unmoved unless 8.0 moves them — any re-pin
   by hand, named, with the reason.
4. **mutgate** from a fresh clone/workspace, spec under `evidence/P1.7r/`: at least one migrated fixture
   (revert it → its self-test → red) and one kept fixture (migrate it anyway → the self-test verdict it
   pins → red).

Do not run `make dst`.

## Your last act

Commit `ADR-001 (031) P1.7r: tool self-test fixtures onto ABI 8.0 (migrated or kept with reason)`, then
print `RESULT P1.7r` (head_before, commit, files_touched, the three self-tests' exits, migrated/kept
counts, re-pins, mutgate, could_not_run).

## Rules that bind you

- Your listed files and `evidence/P1.7r/`. Not `packages/`, not `src/core` (P1.3r's follow-up and then
  P1.5r's follow-up are its sole writers), not another part's files.
- One commit, named as above, as your last act. Stage **only your own paths**; several delegates share
  this checkout. Leave every unrelated path alone, and **never run `git stash`**.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
