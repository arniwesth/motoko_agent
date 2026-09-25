# LEG-P0.2 — the boundary probe suite in its home (PLAN-001 (031) v1.1, release line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not
implement any other part, you do not edit the ADR or the plan, you do not write the dagr run file, and
you do not touch other panes, tabs or worktrees.

## What this is

`P0.2` in `PLAN-001-implement-adr-001-abi-8.md` §2. Seven reviews of ADR-001 produced a body of compiler
probes — attacks, controls and escapes — that live today only as quoted sources inside review
appendices. **P0.2 gives them a home and makes them a regression**: fixtures in the tree, rows in
`run_declared_vs_performed.sh`, scored in four groups with their own expected results. This is ADR-001's
freeze evidence 2(b), and it is anchor-independent: it reads the tree and writes only under
`scripts/dst/`.

The boundary rule itself (the shape gate) is **P0.3**, a different delegate. You build the suite that
gate will later be measured against. Red-first is natural here: run the rows before the boundary exists
and record that the escapes are **accepted** — that is the documented state, not a failure.

## Ground truth to read first, in this order

1. `.agent/projects/031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md` — §0 items 1, 7, 9, 10;
   §2 `P0.2` (the whole part).
2. `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md` — the
   **acceptance rule** under "Freeze evidence and implementation handoff", then freeze evidence item 2,
   especially 2(b): the three classes, the three scored groups, and the **fourth class**
   (compiler-clean, boundary-rejected — the import shadows the rule over-rejects by design). D2 is the
   boundary the groups are named against.
3. `.agent/projects/031_system_one_decisions/NOTE-001-effect-inference-gap.md` — the gap
   (`fb_30e82f6bdc5fc8c3`) and §7's re-test procedure.
4. The five reviews' appendices — **these are your sources**:
   - `REVIEW-adr001-v0.3-verdicts-codex.md` **§A.2** — the 21 cases, with captured outputs.
   - `REVIEW-adr001-v0.4-verdicts-claude-opus-5.md` **§A.2** — the escape set. The **unannotated variant
     moves into the escapes**, per the plan.
   - `REVIEW-adr001-v0.5-verdicts-claude-fable-5-1.md` **§A.3** — 20 named-arm attacks + 1 control + 3
     recognizer escapes.
   - `REVIEW-adr001-v0.6-verdicts-codex.md` **§A.3** — `delegate_shadow`, `computed_list`,
     `registration_record`, `named_static_constant`, `config_projection`; its **§A.1** carries
     `repro/helpers.ail` and `repro/boundary_types.ail`.
   - `REVIEW-adr001-v0.7-verdicts-claude-fable-5-1.md` **§A.3** — the `v7_*` set; its **§A.1** carries
     `repro/v7_mkmod.ail`.
   Every source is quoted in the appendix. Use the quoted source; do not re-invent a case from its prose
   description. Where two reviews carry the same case, it is one fixture and one row.
5. `scripts/dst/run_declared_vs_performed.sh` — `write_abi_ctor` at **`:945-1000`**, and the two-sided
   idiom at **`:751-771`**.
6. `.agent/projects/013_core_architecture_for_dst/GATE-mutation-red-submission-precondition.md` and
   `mutgate.sh` — the submission precondition you must meet.

## Grounding

Branch `arniwesth/031-abi-8-0`; HEAD `75fefdcb` (documents-only on top of `2f3ee4d1`; `src/`, `packages/`,
`tools/`, `scripts/`, `Makefile` byte-identical to `2062605`, the commit every review was grounded at, so
every anchor above is current). Extension ABI `7.4`. AILANG `v0.33.0`, **the pin** — every row's
expectation is a property of this build. Do not upgrade AILANG, do not work around it, do not "fix" a
compiler behaviour a row measures. A bump is a plan §7 event.

## Where it goes

- Fixtures: `scripts/dst/fixtures/adr001-boundary/<case>.ail`, one file per case, named from its D2 home
  name (the review's case name where it has one).
- Shared modules beside them: `types.ail`, `helpers.ail`, `boundary_types.ail`, `v7_mkmod.ail`.
- Rows: appended to `scripts/dst/run_declared_vs_performed.sh` **through `write_abi_ctor` (`:945-1000`),
  not `write_lim`** — the imported-ABI sum is what the real registration boundary uses, and the
  local-sum verdicts are known to reverse against it (read the comment at `:945`).

You touch `scripts/dst/` and nothing else. Not `src/`, not `packages/`, not `tools/`, not the `Makefile`
(`make declared_vs_performed` already exists).

## The four groups, each with its own expected result

ADR freeze 2(b). Every row is scored into exactly one:

1. **compiler-rejected controls** — the named-arm attacks the pinned compiler itself rejects.
2. **compiler-accepted ordinary controls** — legitimate registrations that must keep compiling.
3. **compiler-accepted escapes** — accepted by the bare compiler, and the **boundary must reject them**:
   the pass-through lambda capturing a locally-typed record (annotated *and* unannotated) from `PureCtx`,
   from `FsCtx` and at the `prepare` arity, its parenthesized spelling, the partial application, the
   local `let` shadowing a top-level `func`, the local `let make_hooks` shadowing a **delegated**
   top-level `make_hooks`, the parameter shadow, the delegated parameter, and the computed capability
   list.
4. **compiler-clean, boundary-rejected** — the import-shadow rows the D2 rule over-rejects **by design**,
   with no effect performed.

A group's denominator is fixed by its membership. **New cases are new rows** — never fold a new case into
an old group's denominator, and never change an existing row's group to make a count come out.

## The row idiom (two-sided, `:751-771`)

Each limitation row is written so that the pin's behaviour and its upstream fix are *both* legible:

- when the pinned compiler **accepts** what the row measures:
  `ok "LIMITATION n still holds: <what> — fb_30e82f6bdc5fc8c3"`
- when it **rejects**:
  `bad "LIMITATION n IS FIXED UPSTREAM: <what this invalidates and what must be re-read>"`

Name `fb_30e82f6bdc5fc8c3` in the still-holds text. A row that cannot distinguish the two sides is not a
row; a rejection that lands for the wrong reason (not the row's own mechanism) is `bad` with the error
line quoted, exactly as the existing rows do at `:965` and `:975`.

## Exit checks — run them yourself, record the output

1. `make declared_vs_performed` **green on the pin**, with every group scored and its count printed.
2. **Red-first record**: run the rows before the boundary exists and record that the group-3 escapes are
   *accepted*. That is the documented pre-boundary state and it belongs in the commit message.
3. **mutgate**, the submission precondition — flip one limitation row's expectation, watch it go red,
   restore, watch it go green, bytes identical:
   ```
   .agent/projects/013_core_architecture_for_dst/mutgate.sh \
     --spec <your spec.tsv> \
     --clone-from /workspaces/motoko_agent --repo /workspaces/mutgate-031-p02
   ```
   Spec is TSV: `fix_id <TAB> target_file <TAB> sed_expr <TAB> test_cmd`. Run it **in the clone**, never
   against this checkout. Keep `mutgate.tsv` and quote it in the envelope. A submission without a
   discriminating pair is refused at intake.

Your green is `make declared_vs_performed` plus the mutgate pair. Whole-tree `make check_core` is not
yours and is not expected to be green later in this plan.

## Your last act: the commit, then the envelope

Commit everything this part produced, as one commit:

```
ADR-001 (031) P0.2: boundary probe suite in scripts/dst/fixtures/adr001-boundary + four-group rows
```

The message body carries: the four group names with their counts, the red-first record (escapes accepted
pre-boundary), the mutgate verdict, and the AILANG pin. Then run mutgate against the commit
(`--clone-from` clones committed state); if it refuses, fix in the working tree, amend, re-run.

Then print the typed result envelope, verbatim in this shape:

```
RESULT P0.2
head_before: 75fefdcb
commit: <sha>
files_touched: [<paths>]
fixtures: <n> (group1 <n>, group2 <n>, group3 <n>, group4 <n>)
commands:
  - make declared_vs_performed -> exit <n>
  - mutgate.sh ... -> exit <n> (<pass>/<rows> discriminate)
red_first_record: <one line: which escapes were accepted pre-boundary>
sources_covered: [v0.3 A.2, v0.4 A.2, v0.5 A.3, v0.6 A.3+A.1, v0.7 A.3+A.1]
sources_NOT_covered: [<case>: <why>, ...]
could_not_run: [<what>: <why>, ...]
```

## If the ADR turns out to be wrong

If a fixture shows a D2 sentence false — a case the ADR says the boundary rejects that nothing can
reject, a group whose expected result cannot hold on the pin — **stop and report the artifact**. The ADR
is frozen as text (acceptance rule ii): it changes only by a numbered amendment citing your failing
fixture, written by the orchestrator. Do not edit the ADR. Do not silently re-score a group to make the
suite green.

## Rules that bind you

- One commit, named as above, as your last act. Do not commit anyone else's files; `git status` will show
  unrelated modified and untracked paths on this branch — leave every one of them alone.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md` (the orchestrator writes §9), the ADR, or `.dagr/`.
- Privacy: fixtures are **synthetic**. No session content, no credentials, no tailnet or host addresses
  in a fixture, a row, a commit message or the envelope.
- Heavy runs are one at a time; `make dst` is not yours to run. `make declared_vs_performed` alone is.
- Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or `/workspaces/motoko_agent-eval`.
