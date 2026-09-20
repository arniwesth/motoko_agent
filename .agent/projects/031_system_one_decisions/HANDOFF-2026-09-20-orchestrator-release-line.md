# HANDOFF 2026-09-20 — Orchestrator for PLAN-001 (031) release line R: ABI 8.0 closed

You are the **Orchestrator** for the implementation of ADR-001 (031) v0.8's release line, as laid out in
`PLAN-001-implement-adr-001-abi-8.md` v1.1 §1a. You run in your own Herdr tab; you delegate every task to a
fresh agent in a pane you open; you are the **single writer** of the dagr run file that renders the work; you
never implement a task yourself. The operator supervises through the graph and may attach an observer.

## Ground truth to read before anything else, in this order

1. `.agent/projects/031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md` — §0 standing rules, §1a the
   release line (your scope), §2–§3 the parts you will delegate, §9 where you append records. Lines X (P0.7,
   P1.3x, P1.4x, P2–P4, REV) are **not yours**.
2. `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md` — v0.8. Read its
   **acceptance rule** under "Freeze evidence and implementation handoff" first: no review round on the text;
   a change lands only as a numbered amendment citing a failing fixture, a compile error or a measured probe.
   Then D2 (the boundary, the configuration channel), D3 (the types), D7 (the migration table).
3. `../033_release/ADR-001-release-scope.md` — G5 and its sub-gates; you update the G5 row at R-G.
4. `.dagr/run-031-plan001-r.json` — the graph. Fifteen tasks; `claude` owns every delegate task; the operator
   owns P0G and R-G. SWEEP and P0.2 are ready.
5. The seven reviews' appendices (`REVIEW-adr001-v0.3…v0.7-*.md`): they hold every probe source P0.2 commits.
   `NOTE-001-effect-inference-gap.md` §7 is the re-test procedure.
6. `.claude/skills/dagr-producer/SKILL.md` and `.claude/skills/herdr/SKILL.md` — you use both constantly.
7. `.agent/meta-decisions/`: `sequence-implementation-handoffs-by-source-surface`, `measure-review-loop-
   convergence…` (rules 4 and 5), `re-ground-inherited-anchors-before-building`, `author-each-artifact…`.
8. `../013_core_architecture_for_dst/PLAN-004-implement-adr-004.md` §0 and §6, `GATE-mutation-red-submission-
   precondition.md`, `mutgate.sh`, `LEG-TEMPLATE.sh` — the conventions you inherit for §9 records and intake.

Grounding: branch `arniwesth/031-abi-8-0`, HEAD `2f3ee4d1`; `src/core`, `packages`, `tools`, `scripts`, Makefile
byte-identical to `2062605`, the commit every review was grounded at, so every anchor in the plan and ADR is
current. ABI `7.4`; AILANG `v0.33.0` (pinned; a bump is a §7 event, never silent).

## Your first three acts

1. **Take the graph.** In one write: set `run.orchestrator.pane` to your `$HERDR_PANE_ID`, refresh
   `generated_at`, append a `note` event ("orchestrator-031 took the run in <pane>"). Always `run.json.tmp →
   dagr check --strict --json → [] → mv`. The previous producer (pane `w3:p5V`) has stopped writing.
2. **Commit the documents** so implementation has a clean base: the ADR v0.8, PLAN-001 v1.1, the seven
   reviews, `NOTE-001`, the handoffs (this one included), and `033/ADR-001` — one commit,
   `ADR-001 (031): v0.8 accepted on artifacts; PLAN-001 v1.1; reviews 3–7`. Do not commit the eleven files
   under `.agent/plans`, `benchmarks`, `design_docs` and `.motoko/config` that are also modified — they belong to
   the operator's earlier commit stream on this branch; if `git status` shows them, leave them staged-out and say
   so in your first report. Do not touch `.agent/meta-decisions/*` or `013_core_architecture_for_dst/STATE-*`,
   which another session owns.
3. **Open SWEEP and P0.2.** SWEEP is heavy and runs alone (plan §0 item 2); P0.2 only reads the tree and may run
   beside it. Each gets a fresh delegate in a pane you split, an attempt with `locator` and `liveness`, and an
   `attempt_started` event.

## How you delegate

- **One delegate per task, fresh, at HEAD.** Split a pane in your tab (`herdr pane split --current --direction
  <right|down> --cwd /workspaces/motoko_agent --no-focus`), start `claude` there with a scoped allowlist (the
  harness refuses full permission bypass for agents; a delegate needs `Read Grep Glob Write Edit` and
  `Bash(make:*) Bash(ailang:*) Bash(git:*) Bash(python3:*) Bash(bun:*) Bash(sha256sum:*) Bash(cat:*) Bash(sed:*)
  Bash(ls:*) Bash(wc:*) Bash(mkdir:*) Bash(grep:*)`), default model `claude-opus-5`; use `claude-fable-5-1` for
  P0.3 and P1.1, the two design-sensitive parts. Model chip in the attempt: `opus5·max` / `fable·xhigh`.
- **The brief is a file**, `LEG-<task>.md` beside this one, written from the plan's part text plus the task's
  `criteria` from the graph: exact files, exact anchors, the exit checks, the commit name, and the rule that the
  delegate's last act is the commit and a typed result envelope (files touched, commands run with exit codes,
  what could not run). The prompt points at the file.
- **Intake is a precondition, not a review** (rule 5): before you settle an attempt `done`, run the part's make
  targets yourself and the `mutgate` two-sided check; a part that fails intake is `rejected` with the reason,
  and the fix is a **new attempt** with `cause: sent_back`. Evidence tier is `verified` only with your own
  mechanical receipt; a delegate's envelope alone is `reported`.
- **Batch size is measured** (rule 4): after P1.2a record items and intake defects in §9; cap B, C and D so the
  whole batch has a plausible chance of passing; split a batch rather than run it large. B, C and D may run on
  parallel delegates — disjoint packages — once A's rate is known.
- **The tree is red on purpose from P0.4 to R-G** (plan §0 item 3). A part's green is `ailang check` on what it
  touched plus the shape gate on what it migrated; whole-tree `make check_core` is R-G's, not a part's.
- **Records.** Every settled attempt gets a §9 entry in PLAN-001: HEAD, command, exit code, output excerpt, what
  could not run, intake count. Heavy runs (SWEEP, P1.2d's measurement) are §9 records, no commit.
- **Gates are the operator's.** P0G and R-G: when the fan-in completes, append the `promoted` event, open the
  gate's attempt with `actor: operator`, and send the operator the checklist through the graph's message path
  or a directive request; you do not settle a gate yourself.
- **Amendments, not revisions.** If a part shows the ADR wrong — a fixture fails, a type will not compile, a
  measurement contradicts a sentence — the delegate stops, you record the artifact, and the ADR gets a numbered
  amendment citing it. Nobody opens a review round on the ADR text.

## Rules that bind you

- Never edit `src/`, `packages/`, `tools/`, `scripts/` yourself; delegates do, one commit per part named
  `ADR-001 (031) <part>: …`.
- Do not touch Herdr pane `w3:p1` (the PLAN-004 orchestrator, mid-run), its tab `w3:t1`, or the worktree
  `/workspaces/motoko_agent-eval`. Do not touch `w3:pZ` (its observer). The dagr view of your run is in `w3:p5W`;
  leave it, or open another with `make dagr`.
- Heavy runs one at a time (`make dst`, anything on real segments); the memory guard's `flock` is the rule.
- No session content, credentials or host addresses in a brief, a record, a fixture or a commit.
- Report to the operator in the graph and in one short message per settled part: what landed, what failed
  intake, what is ready next. Ask nothing you can decide from the plan; escalate only what the plan marks as the
  operator's (a sweep red not in the register; the gates; §7's open questions when their fixture answers).
