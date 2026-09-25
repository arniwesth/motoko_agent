# LEG-P1.4r — truthful evidence defaults, and the decision state at decision sites (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.4r` in `PLAN-001-implement-adr-001-abi-8.md` §3 — the three D3 evidence fields on every context view,
populated **truthfully** under line R: `verification = NotReached`; `tool_evidence = { records: [],
complete_from_session_start: false, omitted_count: None }`; and `decision_state = None` at **ordinary**
sites, **`Some(...)` at decision sites** carrying the atom's identity, its limits, the descriptor's **two
config projections** (`question_config`, `interpretation_config`) and **zeroed ledger terms**. Never
asserting success (D3). Real evidence construction is line X (P1.4x), not yours.

**Where the work actually is.** P1.1 already put the ordinary-site defaults into the context literals in
`session.ail` (`:1955`, `:5089`) and `rpc.ail` (`:150`, `:383`, `:492`) and `ext/runtime.ail` (`:853`), line
neutrally, and said "P1.4r owns their fixtures". P1.3r's decision cursor (`4109827b`) passes each decision
atom's `prepare`/`interpret` a `PureCtx` whose `decision_state` is "whatever the host's context carries
(P1.4r)" (`ext/runtime.ail:277`) — i.e. `None` today. So your substance is: **at the cursor, stamp
`decision_state = Some(...)` from the atom's own descriptor**, and prove every default with fixtures and
mutation. The plan names `session.ail`; the decision sites are in `ext/runtime.ail`. Both are yours.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 4, 7, **13**; §3 **P1.4r**, P1.4x (not yours); §9's
   **P1.1** and **P1.3r** records.
2. `ADR-001-extension-owned-structured-decisions.md` — acceptance rule and **"## Amendments"**; **D3**
   (`:451-585`): `VerificationEvidence`, `ToolEvidenceWindow`, `DecisionInvocationState` with its two
   config projections and the five ledger terms, explicit absence; D5 on limits; D2 on the descriptor.
3. `packages/motoko-ext-abi/types.ail` at HEAD — the exact shapes and constructors of those types.
4. `src/core/ext/runtime.ail` at HEAD (`4109827b`): the cursor, `:277`, the folds; `git show 4109827b`.
5. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `4109827b`. ADR accepted with Amendments 1–2; ABI frozen at
8.0. AILANG `v0.33.0`, the pin. **You are the only writer in `src/core`** (plan §0 item 13). Batches B, C, D
work in `packages/` beside you. **Anchors stay neutral** (`make anchors`, `make driver_leaf_inventory`
byte-identical) — `session.ail` and `ext/runtime.ail` carry pinned anchors.

**Checks:** reuse `evidence/P1.1/p11_core_check.sh` (a workspace from `src/core` + the ABI; immune to the
`ailang.lock` trap) and P1.3r's `evidence/P1.3r/p13r_check.sh`. `make check_core`/`make test` are `R-G`'s and
unreachable on the red tree — do not chase them.

## Exit checks — run them yourself, record the output

1. Every tracked `src/core` module on 8.0 (P1.3r left 71/72, the one failure `test/integration_tests.ail`
   on a package the workspace does not include — say what it is when you run); `ailang test` green on
   every module you touch.
2. **Fixtures per variant**: an ordinary site shows `NotReached` / the empty incomplete window / `None`;
   a `DecisionSolverJudge` and a `DecisionToolPolicy` atom each see `Some` with **their own** descriptor's
   identity, limits, both projections byte-equal to what they registered, and every ledger term zero.
3. P0.6's two consumers through the cursor still vote as before (P1.3r's `E2E`), now reading
   `interpretation_config` from the state they are handed.
4. Anchors neutral.
5. **mutgate** in a workspace, spec committed under `evidence/P1.4r/` with repo-relative paths. At least:
   default `verification = Passed` → red; `complete_from_session_start = true` → red; a decision site
   handed `None` → red; a projection taken from the wrong atom → red; a ledger term non-zero → red.
   Known trap: `cmd | grep -q X` under `set -o pipefail` scores baseline red (exit 141).

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P1.4r: truthful evidence defaults; decision_state stamped from each atom's descriptor at the cursor
```

```
RESULT P1.4r
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
src_core_check: <n>/<m> (failures: <file: cause>)
fixtures: [ordinary: <ok>, decision_solver_judge: <ok>, decision_tool_policy: <ok>]
commands:
  - make anchors -> exit <n>;  make driver_leaf_inventory -> exit <n> (byte-identical?)
  - mutgate ... -> exit <n> (<pass>/<rows>)
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

A projection D3 names that the descriptor does not carry, a ledger term with no zero, a limit the cursor
cannot know — **stop and report the artifact**. ADR changes are numbered amendments written by the
orchestrator.

## Rules that bind you

- `src/core` (the context literals, `ext/runtime.ail`'s decision sites, their tests/fixtures) and
  `evidence/P1.4r/`. Not `packages/`, `scripts/`, `tools/`; no new `Ports` field, no leaf in `session.ail`
  or `tool_phase.ail` (P1.3x).
- One commit, named as above, as your last act. Stage **only your own paths**; several delegates share
  this checkout. Leave every unrelated path alone, and **never run `git stash`**.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
