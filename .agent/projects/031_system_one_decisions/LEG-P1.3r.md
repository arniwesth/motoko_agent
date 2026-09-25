# LEG-P1.3r — the dispatch cursor with a stub adapter arm (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P1.3r` in `PLAN-001-implement-adr-001-abi-8.md` §3 — ADR D4's **per-atom two-phase cursor** for the two
decision capabilities, in `src/core/ext/runtime.ail`, with a **stub adapter arm** in place of any
provider. Under line R an extension that registers a decision capability gets a deterministic
`Unavailable(UnconfiguredBackend)` and votes on it through its own interpreter — the ADR's abstention
path — so both variants run end to end with no host service, no wire and no new port. The live arm is
line X (P1.3x), not yours.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 4, 7, **13**; §3 **P1.3r**, and P1.3x / P1.4r so you
   know what is **not** yours; §9's **P0.6** (the scripted consumers you will run) and **P1.1** (how core
   projects views and stamps `ext_config`).
2. `ADR-001-extension-owned-structured-decisions.md` — acceptance rule and **"## Amendments"**
   (`JudgeImmediate`/`JudgeQuery`, `ToolImmediate`/`ToolQuery`); **D4** (`:586-637`) the cursor and its
   placement; D2's two signatures (`:111-137`); D3's `DecisionObservation` / `Unavailable` reasons; D5 on
   immediate votes.
3. `src/core/ext/runtime.ail` at HEAD (P1.1 rewrote it at `08669414`): the dispatchers (`:402-416`,
   `:710-719` at `2062605` — re-find them at HEAD) and how vote families merge.
4. `packages/motoko_ext_conformance/examples/` — P0.6's finalize and tool-policy consumers.
5. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after P1.5r's commit. ADR accepted, ABI frozen at 8.0; core on
8.0 (P1.1). AILANG `v0.33.0`, the pin. **You are the only writer in `src/core`** (plan §0 item 13); P1.4r
(`session.ail`) opens after you. P1.2a works in `packages/` beside you.

**Plan exits not reachable yet — do not chase them.** `make check_core` and `make test` need all 18
extension packages on 8.0 (P1.2 batches) and are `R-G`'s. Your stand-ins: every tracked `src/core`
module checked on 8.0 with `evidence/P1.1/p11_core_check.sh check <all src/core>` (P1.1 left it at
71/72, the one failure `test/integration_tests.ail`'s 7.4 import — say what it is when you run),
`ailang test` on `ext/runtime.ail` and every module you touch. **Try** `make driver_plus_no_ops` and
`make profile_coverage`; if either is unreachable on the red tree, say exactly why and give a stand-in.

**`ailang.lock` trap:** path dependencies are pinned to the primary checkout's absolute path, so any
check inside a `git clone` resolves the primary's packages. `p11_core_check.sh` builds its own workspace
— reuse it, including for mutgate.

## What you build (plan §3 P1.3r)

- Per decision atom, in registry/atom order: **prepare** → on `JudgeQuery`/`ToolQuery` the caller answers
  → **interpret** → next atom. **Every atom runs.** `JudgeImmediate`/`ToolImmediate` votes are applied
  through the **existing merges**.
- **The stub arm**, inside the dispatcher: every query is answered `Unavailable(UnconfiguredBackend)`
  with **zero usage**. No port is read, no ordinal advances, no world token is threaded through a leaf.
- **Vote families** enforced (P1.1's normalization); **precedence preserved** exactly.
- **No** leaf in `session.ail` or `tool_phase.ail`; **no** `Ports` field; **anchors neutral**
  (`make anchors`, `make driver_leaf_inventory` byte-identical).
- The no-op profile gains a **neutral decision atom** of each variant (P0.5's neutral constructors).

## Exit checks — run them yourself, record the output

1. All `src/core` modules checked on 8.0 (count and every failure's cause); `ailang test` green on what
   you touched.
2. **End to end, per variant**: P0.6's finalize and tool-policy consumers dispatched through your cursor
   — each `prepare` that queries gets `Unavailable(UnconfiguredBackend)`, its `interpret` votes
   (`NoDecision` / `NoOpinion` per P0.6's scripts), the vote merges, the next atom runs.
3. Precedence: a test that fixes the legacy-vs-decision order in each family.
4. `make anchors` and `make driver_leaf_inventory` — neutral.
5. `make driver_plus_no_ops`, `make profile_coverage` — result, or the reason and the stand-in.
6. **mutgate** in a workspace, spec committed under `evidence/P1.3r/` with repo-relative paths. At least:
   the stub returns `Answered(..)` → the consumer's interpreter is reached with a fabricated answer → red;
   the cursor skips an atom → red; an `Immediate` vote bypasses the merge → red; the stub advances an
   ordinal or reads a port → red. Known trap: `cmd | grep -q X` under `set -o pipefail` scores baseline
   red (exit 141) — log to a file, then grep it.

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P1.3r: the per-atom decision cursor with the stub adapter arm (Unavailable, zero usage)
```

```
RESULT P1.3r
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
src_core_check: <n>/<m> (failures: <file: cause>)
end_to_end: [finalize: <votes>, tool_policy: <votes>]
commands:
  - make anchors -> exit <n>;  make driver_leaf_inventory -> exit <n> (byte-identical?)
  - make driver_plus_no_ops -> exit <n> | stand-in
  - make profile_coverage -> exit <n> | stand-in
  - mutgate ... -> exit <n> (<pass>/<rows>)
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

A cursor D4 describes that cannot keep precedence, a stub the types will not admit, an immediate vote
the merges cannot take — **stop and report the artifact**. ADR changes are numbered amendments written by
the orchestrator (Amendment 1 is the precedent).

## Rules that bind you

- `src/core/ext/runtime.ail`, the no-op profile, their tests/fixtures, and `evidence/P1.3r/`. Not
  `session.ail`/`tool_phase.ail`/`ports.ail` (P1.3x, P1.4r), not `packages/`, `scripts/`, `tools/`.
- One commit, named as above, as your last act. Stage **only your own paths**; another delegate edits
  `packages/`. Leave every unrelated path alone, and **never run `git stash`**.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- No session content, credentials or host addresses anywhere.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
