# LEG-P0.4 — ABI 8.0 types (PLAN-001 (031) v1.1, release line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not
implement any other part, you do not edit the ADR or the plan, you do not write the dagr run file, and
you do not touch other panes, tabs or worktrees.

## What this is

`P0.4` in `PLAN-001-implement-adr-001-abi-8.md` §2. You write the **ABI 8.0 type contract** — and
nothing that consumes it. `packages/motoko-ext-abi/` only. This is the freeze: after `P0G` the types
you write here are what every other part of the release line migrates onto, and the 8.x stability rule
you put in the header is what the release promises (033 G5d).

**The tree goes red when you land, and that is the design** (plan §0 item 3). An ABI major that
re-signs every `Capability` cannot be landed with the tree green between parts: 37 `ExtCtx` literals in
28 files, 8 `ExtEntry` literals in 3 files, and all 45 registration sites change type together, and
those are P1's. Your green is `ailang check packages/motoko-ext-abi/types.ail` **alone**. Do not touch
`src/`, `tools/`, `scripts/` or any other package to keep something compiling — that is P1.1's work and
taking it here breaks the plan's sequencing.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §0 items 3, 4, 7, 10; §2 `P0.4` (the whole part); §1a for
   why P0.4 is in line R.
2. `ADR-001-extension-owned-structured-decisions.md` v0.8 — read its **acceptance rule** under "Freeze
   evidence and implementation handoff" first, then:
   - **D2** (`:109-450`): the two decision capabilities and their signatures (`:117-137`), what the
     views guarantee and what they do not (`:143-176` — restricted *supplied authority*, not
     compile-time purity), the **views-to-ports table at `:320-327`**, the `Trace` widening and the
     "no dummy ports" rule (`:329-339`), and the configuration channel (`ext_config`,
     `ExtRegistration = { config, caps }`).
   - **D3** (`:451-585`): the typed observation vocabulary — `NamedQuestion` … `DecisionUsage`,
     `VerificationEvidence`, `ToolEvidenceWindow`, `DecisionInvocationState` with its two config
     projections and five ledger terms, and explicit absence.
   - **D7** (`:899-917`): the migration table. Row 1 (`ABI 7.4 → 8.0`) is your scope statement; every
     other row belongs to a later part and you implement none of it.
3. `packages/motoko-ext-abi/types.ail` and `packages/motoko-ext-abi/ailang.toml` at HEAD — what you are
   changing. The header already assigns a `Capability` variant addition to a major version; you extend
   that header, you do not replace its reasoning.
4. `../033_release/ADR-001-release-scope.md` — **D1 item 2** and the **G5d** cell: the exact stability
   promise the header must carry.
5. `.agent/projects/013_core_architecture_for_dst/GATE-mutation-red-submission-precondition.md` and
   `mutgate.sh`.

## Grounding

Branch `arniwesth/031-abi-8-0`. HEAD moves under you — `SWEEP` and `P0.2` have landed on it — so start
by reading the current HEAD and working from it; the ABI package itself is untouched by both. `src/`,
`packages/`, `tools/`, `scripts/` and the `Makefile` are byte-identical to `2062605`, the commit every
review was grounded at. Extension ABI **7.4** today. AILANG `v0.33.0` — the pin. Do not upgrade it and
do not work around it; a bump is a plan §7 event.

**The sweep is green for your purposes.** `make dst DST_JOBS=1` ran at `75fefdcb`: 49 of 51 targets
passed. The two reds (`profile_definition`, `driver_only`) are one pre-existing cause on 013's evaluator
surface, ruled a known false positive by the operator, and P0.4 was unblocked on that ruling. Do not
try to fix them. **One consequence you must know and must not act on:** the ABI-version pin sweep in
`tools/profile_definition/check_fixtures.py` compares 31 `abi_version` literals across 25 tracked `.ail`
files against whatever `ailang.toml` declares live. When you set 8.0, all 31 drift and those two targets
go red on 31 sites. That is **expected, ruled, and owned by a separate part (P1.5r)**. It is not your
defect and not your repair.

## What you write

`packages/motoko-ext-abi/types.ail` and `packages/motoko-ext-abi/ailang.toml`. The D2/D3/D7 contract:

- **Six context views** — `PureCtx`, `ProcessCtx`, `FsCtx`, `AiCtx`, `InterceptCtx`, `ProviderCtx` — with
  exactly the ports of the table at ADR `:320-327`, and **an exported constructor for each**. `PureCtx`
  is `ExtCtx` without `ports` and without `world`; every other field, including the D3 additions, is
  present. `ProcessCtx` keeps `world` for `next_state` and carries no ports view.
- **`ext_config: Json` on every view.**
- **`Capability` re-signed on every variant** — each callback takes its row's view, not `ExtCtx`.
- `DescribeTools((Json) -> [ToolSchema])` — the extension's configuration, no context (N49).
- `ToolProvider`'s row gains **`Trace`**, so `ProviderCtx` carries all ten port fields.
- The two new variants: **`DecisionSolverJudge`** and **`DecisionToolPolicy`**, with
  `DecisionPolicyDescriptor`, `JudgePreparation`, `ToolPreparation`.
- The **D3 vocabulary**: `NamedQuestion` … `DecisionUsage`, `VerificationEvidence`,
  `ToolEvidenceWindow`, `DecisionInvocationState` with the two config projections and the five ledger
  terms.
- **Nullary `Accept`.**
- **`ExtRegistration = { config: Json, caps }`** as `register_with_config`'s return; **`ExtEntry.config`**.
- The **8.x stability rule in the header** (033 G5d, D1 item 2), stated so a reader can act on it: 8.x
  minors add context fields **only behind the constructors this package exports**, so a consumer using a
  constructor keeps compiling; a `Capability` variant or row change waits for **9.0**.
- `ai_summary` in `ailang.toml` **rewritten for 8.0**, and the package `version` at **`8.0`**.

## Exit checks — run them yourself, record the output

1. `ailang check packages/motoko-ext-abi/types.ail` **green**.
2. `ailang.toml` declares `8.0` and `ai_summary` describes 8.0, not 7.4.
3. **Red-first, recorded**: write a scratch consumer using a **7.4** signature (an `ExtCtx`-typed
   callback in a `Capability` payload) and show it **fails** to check against 8.0. Quote the error. Keep
   the scratch file out of the commit, or commit it under the package's own fixtures if it has a home —
   say which you did and why.
4. **mutgate**, the submission precondition:
   ```
   bash .agent/projects/013_core_architecture_for_dst/mutgate.sh \
     --spec <your spec.tsv> \
     --clone-from /workspaces/motoko_agent --repo /workspaces/mutgate-031-p04
   ```
   Spec is TSV: `fix_id <TAB> target_file <TAB> sed_expr <TAB> test_cmd`, run **in the clone**, never
   against this checkout. Mutate something the check names — widen a view to carry a port its row
   forbids, or drop `ext_config` from a view — and show the check goes red, then restore. A trap the
   P0.2 delegate hit and documented: a `test_cmd` shaped `script | grep -q X` scores baseline red,
   because `mutgate.sh` evals under `set -o pipefail` and `grep -q`'s early exit SIGPIPEs the producer
   into exit 141 on a *successful* match. Write the `test_cmd` so success is a real exit 0.

Whole-tree `make check_core` is **not** yours and will not be green after you land. Do not run `make
dst` — heavy runs are one at a time and not this part's.

## Your last act: the commit, then the envelope

One commit:

```
ADR-001 (031) P0.4: extension ABI 8.0 — six context views, the decision variants, the D3 vocabulary, the 8.x rule
```

The message body carries: the six views and their port sets, the two new variants, the D3 types added,
the 8.x stability rule verbatim as it went into the header, the red-first record with the quoted error,
the mutgate verdict, and the pin. Then print:

```
RESULT P0.4
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
views: [PureCtx: <ports>, ProcessCtx: …, FsCtx: …, AiCtx: …, InterceptCtx: …, ProviderCtx: …]
capability_variants: <n> (new: DecisionSolverJudge, DecisionToolPolicy)
d3_types_added: [<names>]
commands:
  - ailang check packages/motoko-ext-abi/types.ail -> exit <n>
  - mutgate.sh ... -> exit <n> (<pass>/<rows> discriminate)
red_first_record: <the 7.4-signature consumer's error, one line>
abi_version: 8.0   ai_summary: rewritten
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

If a type in D2 or D3 **will not compile** as written — a row that cannot be expressed, a constructor
the language will not take, a view the table describes that contradicts itself — **stop and report the
compile error as the artifact**. The ADR is frozen as text (acceptance rule ii): it changes only by a
numbered amendment citing your error, written by the orchestrator. Do not edit the ADR, and do not
quietly pick a different type to make the check pass. A design you had to choose between two readings of
the ADR is also worth reporting, with both readings.

## Rules that bind you

- `packages/motoko-ext-abi/` **only**. Not `src/`, not `tools/`, not `scripts/`, not another package,
  not the `Makefile`.
- One commit, named as above, as your last act. `git status` shows unrelated modified and untracked
  paths on this branch — leave every one alone.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md` (the orchestrator writes §9), the ADR, or `.dagr/`.
- Privacy: no session content, credentials, tailnet or host addresses in the types, a comment, a commit
  message or the envelope.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
