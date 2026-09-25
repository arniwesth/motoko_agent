# LEG-P0.3 — the registration-shape gate (PLAN-001 (031) v1.1, release line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not
edit the ADR or the plan, you do not write the dagr run file, and you do not touch other panes, tabs or
worktrees.

## What this is

`P0.3` in `PLAN-001-implement-adr-001-abi-8.md` §2 — ADR-001 D2's **registration-shape rule**, built as
a separate per-extension result field in `tools/ext_ambient_inventory/hook_scope.py` with its own
rejection shapes and a failing exit. It is freeze evidence **8** and the boundary half of **2(b)**: P0.2
committed the suite that shows 12 escapes the bare compiler accepts; your gate is what must reject
them. Anchor-independent: it reads the tree and changes tooling only.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 1, 6, 7; §2 **P0.3** (the whole part — it names
   every function and line you change); §9's **P0.2** record (what landed and where).
2. `ADR-001-extension-owned-structured-decisions.md` v0.8 — the **acceptance rule** under "Freeze
   evidence and implementation handoff" first; then **D2** `:109-450`, especially facts 1–6
   (`:151-199`), the registration boundary and its three layers (`:195` on), the shape rule in AILANG's
   **scoping order**, and N42, N43, N51, N52, N62, N63; then freeze evidence items 2(b) and 8.
3. `tools/ext_ambient_inventory/hook_scope.py` and `derive.py` at HEAD, at the anchors the plan names:
   `func_body` `:371`, `_body_at` `:415`, `_resolve_func` `:763` (and the closure-wide table
   `:557-558`, `:773-777`), `Scope.locate` `:626-663` (the overwrite at `:659`), `_binding_text`
   `:910-942`, the walk's `hook-binding-unresolvable` at `:882-886`, `emit_hook_scope` `:1122`, the
   self-test pins `:1230-1240`; `derive.py:888`; `Makefile:507-519` (`DST_TARGETS`).
4. `scripts/dst/fixtures/adr001_boundary/` and its rows in `scripts/dst/run_declared_vs_performed.sh`
   — P0.2's suite. Read the group-3 escapes: they are what your gate must reject.
5. `.agent/projects/013_core_architecture_for_dst/GATE-mutation-red-submission-precondition.md`,
   `mutgate.sh`.

## Grounding

Branch `arniwesth/031-abi-8-0`; HEAD moves (other parts land beside you) — read it and work from it.
`tools/` is byte-identical to `2062605`, so every anchor above is current unless P0.4 touches it (it
does not: P0.4 is `packages/motoko-ext-abi/` only). AILANG `v0.33.0`, the pin. **P0.4 is running in
parallel** and will land ABI 8.0 types; your gate recognizes the `{ config, caps }` head P0.4 defines.
Do not wait for P0.4 and do not depend on its package compiling: the gate reads source shape.

## What you build (plan §2 P0.3, restated as a checklist)

All in `hook_scope.py` unless noted:
- `func_body` (`:371`) and `_body_at` (`:415`) return the signature's **parameter names** beside the body.
- `_resolve_func` (`:763`) takes the **per-hop scope chain**: locals and parameters first, then the
  **home module's** imports, then the home module's declarations — **never** the closure-wide table.
- `Scope.locate` (`:626-663`) records `(module, parameters, lets)` **per hop** instead of overwriting
  `producing_body` (`:659`); recognizes the **`{ config, caps }`** head with a literal or delegated
  `caps`; **fails** on a computed, `match`-selected or unknown list.
- `_binding_text` (`:910-942`) accepts only a bare name resolving through the chain to a top-level
  `func` or import; rejects inline lambdas, `let`-bound lambdas and partial applications.
- `registration_shape_result: pass | fail(reason)` computed from `locate` and the binding pass — **not**
  from `sc.rejections` (the walk emits `hook-binding-unresolvable` too, `:882-886`).
- `emit_hook_scope` (`:1122`) returns **nonzero from that field alone**.
- `derive.py` returns it (`:888`) **without touching the default mode's closure verdict**.
- `Makefile`: add `ext_hook_scope` to `DST_TARGETS` (`:507-519`) beside `ext_hook_scope_selftest`.
  This is the one `Makefile` edit you make.
- The self-test's `capability_list_atoms` and `registration_shape` pins **re-pinned by hand** for the
  new head; `closure_port_mediated` asserted **unmoved** (`:1230-1240`).

## Fixtures — `scripts/dst/fixtures/adr001_boundary/gate/`

Underscore, not the plan's hyphen: the pin refuses a hyphen in a module path (P0.2's §9 record).
- **pass**: `fx_named_ok`, `fx_empty`, `fx_residue` (a named callback with `show` in its walk — pass).
- **fail**: `fx_shadow`, `fx_delegate_shadow`, `fx_param_shadow`, `fx_delegate_param`, `fx_partial`,
  `fx_computed`, `fx_match`, `fx_unknown`.
- **fail, compiler-clean**: `fx_import_shadow`, `fx_delegate_import_shadow` — D2's locals-first rule
  over-rejects these by design (P0.2's group 4).
- **one fixture per in-tree registration form** — P1.2 will flip these from fail to pass as it migrates.

## Exit checks — run them yourself, record the output

1. The gate is **red on every fail fixture and green on every pass fixture**, each run shown.
2. On the unmigrated tree the gate is **red by 35 bindings**. Record the number you actually get. If it
   is not 35, **do not adjust the gate to hit 35** — report the number and the list; the plan's 35 is a
   review count, and a different measured count is a finding.
3. `make ext_hook_scope_selftest` green with the re-pinned yields; `closure_port_mediated` unmoved.
4. **mutgate** on the result field: break the shadow rejection → `fx_shadow` passes → restore:
   ```
   bash .agent/projects/013_core_architecture_for_dst/mutgate.sh --spec <spec.tsv> \
     --clone-from /workspaces/motoko_agent --repo /workspaces/mutgate-031-p03
   ```
   Run it in the clone only. Known trap: a `test_cmd` shaped `cmd | grep -q X` scores baseline red,
   because `mutgate.sh` evals under `set -o pipefail` and `grep -q`'s early exit SIGPIPEs the producer
   (exit 141) on a successful match. Make success a real exit 0.

`make ext_hook_scope` (the tree-wide run) is **expected red** until P1.2 migrates the 45 sites — that is
the design, and you record it rather than fix it. Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P0.3: registration-shape gate in hook_scope.py — per-hop scope chain, {config,caps} head, own result field, nonzero exit
```

Body: each change against its anchor; the fixture verdict table; the measured tree count (and whether
it is 35); the re-pinned self-test yields; the mutgate verdict; the pin. Then print:

```
RESULT P0.3
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
fixtures: pass <n>/<n> green, fail <n>/<n> red
tree_red_bindings: <n>   (plan expected 35)
commands:
  - make ext_hook_scope_selftest -> exit <n>
  - <gate on fixtures> -> <result>
  - make ext_hook_scope -> exit <n> (expected red)
  - mutgate.sh ... -> exit <n> (<pass>/<rows>)
closure_port_mediated: unmoved | MOVED
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

If a D2 sentence cannot be implemented as written — a rejection shape the source cannot distinguish,
a scoping order the pinned compiler contradicts, a fixture whose expected verdict cannot hold — **stop
and report the artifact** (the fixture and the gate's output). The ADR changes only by a numbered
amendment citing it, written by the orchestrator. Do not edit the ADR; do not re-score a fixture to make
the gate green.

## Rules that bind you

- `tools/ext_ambient_inventory/`, `scripts/dst/fixtures/adr001_boundary/gate/`, and the one
  `DST_TARGETS` line in the `Makefile`. Not `src/`, not `packages/` (P0.4 is there now), not
  P0.2's fixtures or rows.
- One commit, named as above, as your last act. Leave every unrelated modified or untracked path alone.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- Privacy: fixtures are synthetic; nothing from a session, no credentials, no host addresses.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
