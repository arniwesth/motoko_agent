# RESEARCH: How AILANG plans and documents, read in full — what Motoko's planning system can take from it

Date: 2026-10-04
Status: Research note. No decision taken. Candidate follow-ons are listed in §6.
Amended the same day with §9, on Midspiral, and candidates 11 to 13; and with §10, on a public
skills repository, and candidates 14 to 19.
Grounded at: AILANG upstream `sunholo-data/ailang`, branch `dev`, commit `2a1f3f295` (2026-10-03),
read from a sparse clone that is not in this tree. Motoko `main` at `cf54dff9`.
Supersedes: the "Upstream comparison" section of `NOTE-docs-system-design-discussion.md`, surveyed
2026-07-15 from four files. That section is left as written; §5 says what in it no longer holds.

Method: one session surveyed the repository by script, then nine reader agents each read one part
and wrote notes with line citations. Those notes are filed verbatim under `evidence/ailang-survey/`
and indexed in §8. This document is the synthesis.

How far each statement was verified:
- **[checked]** — the orchestrating session re-read the cited line in the source.
- **[measured]** — the orchestrating session counted it with a script.
- unmarked — taken from a reader's notes and not re-checked. Each reader separated what it observed
  from what it inferred; the evidence files carry those marks.

Paths written `ailang:<path>:<line>` are in the AILANG repository at the commit above. All other
paths are in this repository.

Relates to:
- `ADR-001-plan-structure-in-dagr-and-retiring-linear.md` — accepted the same day. §4 and §6 here
  are outside evidence for its D2 and D3, and §6 item 2 bears on the level it left without a home.
- `../021_herdr_delegation/DESIGN-dagr-as-delegation-view.md` §4 — evidence tiers. §3.6 here is the
  strongest outside case found for them.
- `../../meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
  — AILANG reached the same conclusion by a longer road (§3.4, §4).
- `../../meta-decisions/re-ground-inherited-anchors-before-building.md` — AILANG's equivalent is
  the Gate 2 reality check (§3.3).

---

## 1. Why read it again

The July survey described a design-doc lifecycle and one mission. Since then:

| | July survey | 2026-10-03 **[measured]** |
|---|---|---|
| Design docs in the three status directories | 1,013 | 1,532 |
| Implemented / planned / rejected | 898 / 110 / 5 | 1,159 / 368 / 5, plus 30 deferred |
| All markdown under `design_docs/` | not counted | 1,834 |
| Mission charters | 1 | 4 (`v1`, `docs`, `fleet`, `motoko`) |
| Skills | about 43 | about 43 |

What was read this time: the v1 charter (930 KB, 4,908 lines) in full; the `mission-control` skill
with its twelve reference files (488 KB) in full; and in part the coordinator (about 27,700
non-test lines of Go), messaging (9,650), the mission runtime (10,500 plus about 5,000 of shell),
and the docs site (147 published pages). §7 lists what was not opened.

## 2. The system in one page

| Layer | Artifact | Mechanism |
|---|---|---|
| North star | `ailang:design_docs/PROGRAM.md`, 123 lines | Invariants and a three-lane routing rule |
| Missions | Four charters from `ailang:design_docs/mission-charter-TEMPLATE.md` | One skill runs one iteration through gates 0 to 5 |
| Design docs | `planned/` to `implemented/vX_Y_Z/` | Status is the directory; scripts move a doc |
| Sprint state | About 180 JSON files in `ailang:.ailang/state/sprints/` | One per sprint, beside a prose plan |
| Work intake | Messages (local SQLite or cloud Firestore), GitHub issues | The coordinator daemon dispatches agents on messages |
| Agent instructions | `CLAUDE.md` (152 lines), 12 path-scoped rules, skills | Three loading tiers, enforced by `make check-context-docs` |

A mission charter holds a bar of numbered clauses, an ordered queue of tagged rows, a decision
ledger between HTML comment markers, and the three newest status stamps. Beside it sit an
append-only log, an index and a status archive.

## 3. Findings by part

### 3.1 The charter's front matter and decision ledger

Evidence: `evidence/ailang-survey/charter-front.md`. Source: `ailang:design_docs/v1-mission.md`
lines 1 to 520.

- **The ledger is 63 rows, all resolved.** A row is one table line: id, status, the question,
  lettered options, the loop's recommendation and, from D-51 on, a "Default if unanswered". The
  answer is appended in the same cell.
- **Only the human resolves a row** (`:56`–`57`). Of the 63, the reader counts 40 answered in an
  attended session, 10 by an allowlisted comment on a weekly bookkeeping issue, and 6 delegated to
  an agent in an attended session.
- **What is checked is form.** `ailang:scripts/mission_decisions.sh --check` validates the markers,
  unique ids, the two statuses and non-empty cells **[checked]**. Who may resolve a row is prose:
  "The control is the charter rule" (`:122`).
- **The recurring failure is at the edge.** Questions written as prose never became rows and never
  reached the human; five ledger rows exist to repair that (D-31, D-37, D-40, D-43, D-51).
- **There is no superseded status.** A reversal is text inside the row or a new row. D-62 relaxes
  D-56 a day later with no cross-reference.
- **There is no rotation.** The ledger section is 127 KB of the 179 KB front matter **[measured]**.
- **Rulings that changed the loop itself:** un-park a queue row in the iteration that reads the
  ruling, after a P0 doc sat "absent from the queue for **eight days**" (D-12, `:74`); continue
  evaluator rounds only while findings shrink, "Hard cap **5**" (D-36, `:103`); and a rule after
  six of fifteen iterations left no record (D-52, `:119`).
- **The goal unit was replaced.** Iteration 309 counted open queue rows. D-51 dropped that unit
  "because that unit was anti-correlated with good work — an iteration that landed a milestone and
  fixed a real defect moved it by 0, while an iteration filing five triage rows moved it
  backwards" (`:137`–`139`) **[checked]**. The unit is now design docs remaining.
- **"Folder location is evidence, not truth"** (`:151`) **[checked]**.
- **All three live status stamps read "goal unmoved (HARNESS)".** The newest is dated 2026-09-14.

### 3.2 The queue

Evidence: `evidence/ailang-survey/charter-queue-a.md`, `evidence/ailang-survey/charter-queue-b.md`.
Source: `ailang:design_docs/v1-mission.md` lines 521 to 4908, 749 KB **[measured]**.

Both readers concluded, independently, that a program cannot reliably extract the ordered list of
open work from this text.

| | Lines 521–2700 | Lines 2701–4908 |
|---|---|---|
| Rows | 157 | 119 |
| Led by NEXT / LANDED | 77 / 53 | 32 / 45 |
| Led by a tag outside the legend | 22 | 23 other forms; 27 leading forms in all |
| Median / 90th percentile / max length (characters) | 1,530 / 3,548 / 19,377 | 2,204 / 7,087 / 19,351 |

- **`[RULED OUT]` leads no row in the file** **[checked]**. Rejections are inline notes. The
  closing section "Done / superseded" still reads "*(nothing yet — mission initialized
  2026-07-10)*" (`:4908`).
- **Rows accumulate.** The status bracket is rewritten and the body gains dated addenda. One row is
  headed "LANDED COMPLETE … ALL FOUR MILESTONES" while its body ends "**Resume predicate: execute
  M4**" (`:618`–`619`).
- **Nothing is pruned.** Landed rows hold 53% of the characters in the second half.
- **Tags contradict bodies.** Four rows are still tagged as parked on decisions resolved on
  2026-08-19 (`:3188`, `:3202`, `:3216`, `:3531` against `:3848`–`3869`).
- **Position is not priority.** The first eight rows are closed; one block says it is "listed in
  ruling order, not priority order" (`:3854`).
- **Dependencies are prose** ("Do not pick this before … lands", `:661`). None is machine-readable.
- **Links rot.** 11 of 36 design-doc links in the second half point at files that no longer exist.
- **The second half looks unmaintained.** Its highest iteration is 267 and its latest date
  2026-08-31, while the file header is at iteration 354.
- **The text records its own failures:** "PARKED FOR MARK — IN PROSE, WHERE NOTHING READS IT"
  (`:1456`); "THIS ROW WAS MISSING UNTIL ITER-142" (`:3184`); "Iteration 187 measured this same
  defect and it survived 90 iterations" (`:1506`); "a follow-up filed in another row's prose is not
  a backlog item" (`:3205`). One queue row finds 11 of 12 prose parks absent from the ledger
  (`:1480`).
- **And states the rule that would have prevented them:** "the marked block is state, prose is only
  evidence" (`:1460`) **[checked]**.

### 3.3 The skill: gates 0 to 2 and the standing rules

Evidence: `evidence/ailang-survey/skill-gates-0-2.md`. Source:
`ailang:.claude/skills/mission-control/`.

- **The skill file is an index.** Each gate is a nine-line stub: "this stub is an index entry, not
  a summary you may act on" (`SKILL.md:239`–`242`). The procedure is in the reference files.
- **Gate 2's reality check treats a doc's status as "a claim, not a fact"**
  (`resources/gate-2-pick.md:284`). Before work starts it checks whether the item already landed
  against a fresh origin, whether an earlier iteration died holding it, and whether a blocker's
  purpose still exists. Survey-sourced rows must be reproduced live, because "4 of 7" were ghosts
  (`:470`).
- **Rules pile up.** Rule 7 (never end a turn while background work runs) has six amendments, each
  correcting the previous remedy, and is 40% of the file.
- **What is enforced in code is small:** the directive allowlist, a pre-push scope guard, a
  spawn-pin hook, the ledger validator, the base-commit recorder and a billing test. Nearly every
  rule about evidence quality is prose.
- **The size gate leaves room to regrow.** `SKILL.md` is 620 lines against a grandfathered
  allowance of 2,781 **[measured]**. Reference files have no cap.
- **Changing the skill is rationed:** "Max ONE skill edit per iteration; requires ≥2 recorded
  frictions pointing at the same gap" (`resources/gate-5-retro.md:9`–`10`) **[checked]**.

### 3.4 Gates 3 to 5 and the verification protocol

Evidence: `evidence/ailang-survey/skill-gates-3-5.md`.

- **Each stage hands over the artifact, and the receiver re-measures it.** The executor returns an
  uncommitted diff; the controller re-runs the gates and builds the commits. "`rc=0` FROM pi IS NOT
  A CLAIM THAT ANY WORK HAPPENED" (`resources/gate-3-route.md:381`).
- **Evaluator rounds:** "Max 3 rounds" in the skill (`resources/gate-3-route.md:683`), "Hard cap 5"
  in ledger row D-36. This read did not reconcile the two.
- **Landed means an observed green run** on the full pushed commit
  (`resources/gate-3b-ci-green.md:303`). The reader tabulated 19 recorded miscalls, including a
  poll that printed `ALL COMPLETE` over three in-progress runs because two empty strings compared
  equal.
- **Of 18 artifacts written at the end of an iteration, few are checked by a script:** log
  rotation, index regeneration, the base-commit record, the cost chain and the heartbeat. Queue
  tags, the dashboard and status rotation are trusted.
- **A trusted write went badly wrong.** A status rotation moved the "1,571-line queue into the
  archive. It exited 0 and printed a plausible `archived: [...]` line"
  (`resources/gate-4-record.md:292`) **[checked]**.
- **The loop consumed itself.** A counter over the last twenty iterations tracks the share spent on
  the harness; self-repair rose "to 55% and cost it two weeks (iterations 309–348: 16 lines of
  compiler and stdlib)" (`resources/gate-5-retro.md:27`) **[checked]**.
- **The verification protocol has no single definition of verified.** Every result is a claim until
  a named control holds: an empty result needs a known-positive control in the same call; a green
  needs its scope matched to the sentence it supports; a predicted red needs a run with the
  mechanism removed.
- **It catalogues about 98 false greens and false reds** in seven groups: a stale or wrong
  instrument; a reading lost in a pipe; an empty result believed; a real green over-read; a red
  credited to the wrong cause; tests that could not fail for the stated reason; and a run that
  never happened reported as success.
- **Written rules did not stop recurrence.** The reader lists seven places where a rule existed and
  was missed anyway.

### 3.5 The mission runtime: how much is code

Evidence: `evidence/ailang-survey/mission-runtime.md`.

- **Code surrounds an iteration; prose runs it.** The live path is a scheduler, a 2,511-line shell
  driver, and one headless session told to follow its gates.
- **A durable replacement exists but is not the live path.** It is described as "This opt-in path"
  (`ailang:docs/docs/guides/mission-iteration.md:16`) **[checked]**, and "activation currently
  supports local Docs only" (`ailang:cmd/ailang/mission_activation.go:59`) **[checked]**.
- **No Go code parses the charter.** The format contracts are the ledger markers, four heading
  patterns used by log rotation, and the driver's `grep '^## '`.
- **On the live path no record of the picked item survives a crash.** The driver labels the slot;
  crediting or discarding the dead iteration's work is prose.
- **The generated index is real for one mission only.** By the reader's replay of the patterns,
  log rotation would refuse the `docs` and `motoko` logs; both indexes are hand-maintained and say
  so. Rotation is not idempotent: the v1 log carries eight copies of its notice.
- **Design quorum:** three reviewers from five vendors with the author's vendor benched; any reject
  blocks; a cap of $0.30 per reviewer.
- **Human input:** the issue-comment channel is enforced in code. The ledger channel is a
  convention, by the script's own admission (`ailang:scripts/mission_answer.sh:44`–`48`).

### 3.6 The coordinator

Evidence: `evidence/ailang-survey/coordinator.md`. Source: `ailang:internal/coordinator/`.

- **A task is one record per inbox message**, with eleven statuses and no transition table.
- **Completion was a claim, then became a computation.** "`completed` used to mean 'the executor
  exited 0', which is not the same as 'work landed' and could not be told apart from it. Measured
  store-wide: 1,249 completion records, 16 marked completed, 6 that ever changed a file"
  (`task_status.go:11`–`13`) **[checked]**. Wrapper code now derives status from the git diff.
- **Approvals are identity-based and the code calls that "not enforcement".** The approve path
  never compares the approver with the task's agent.
- **There is no fixed design, plan, execute, evaluate chain in code.** Each agent names what its
  completion triggers.
- **A task carries no design-doc or sprint id**, only two path strings filled from a marker the
  agent prints.
- **Several mechanisms are present but not connected**, by absence of callers in the directories
  read: stale re-dispatch, a ledger takeover sweep, an evaluator automation gate.

### 3.7 Messaging

Evidence: `evidence/ailang-survey/messaging.md`. Source: `ailang:internal/messaging/`.

- **It is an intake and dispatch queue, not a tracker** (the reader's inference). Four statuses are
  declared (`inbox.go:46`–`49`) **[checked]**; only `unread` and `read` are ever written.
- **"Read" is overloaded:** acknowledged, merely viewed, dispatched as a task, or folded by
  dedupe. The guide concedes there is no command to mark a message resolved.
- **A message never links to the doc or PR that answered it**, and nothing acknowledges a message
  when its GitHub issue closes.
- **Reading the wrong store is the recurring incident.** A banner showed 16 unread against 74 in
  the canonical store.
- **The reader found 13 places where the docs contradict the code.**

### 3.8 The docs site

Evidence: `evidence/ailang-survey/docs-site.md`. Source: `ailang:docs/`.

- **Only generated-and-gated pages stay true.** The CLI reference is byte-compared against the
  dispatch table in CI. Page prose, 1,192 inline code fences (against 73 imported examples) and 83
  pages with hard-coded versions are unchecked.
- **Advisory checks found nothing to stop.** `docs-sync` exits 0 whatever it finds. One guard exits
  0 when the binary is not on the path.
- **`llms.txt` is stale.** The committed copy is dated 2026-05-16 and embeds prompt v0.16.0; the
  active prompt is v0.16.6. CI does not regenerate it.
- **Public status is the directory path.** A doc whose header says "RULED OUT" is listed as
  planned, as are at least seven marked "Implemented".
- **The docs mission defines good documentation in seven clauses**, one of which says "deletion is
  the normal outcome". None is recorded as met, and two of its twelve landed items edited the site.
- **Recorded failures** include a charter that archived its own goal, after which twelve iterations
  ran without a definition of done.

### 3.9 Measurements made by the orchestrating session

All **[measured]**, by scripts that are not in the tree.

- **Status by directory rots both ways.** Of 114 completed sprints whose JSON names a design doc,
  27 docs still sit in `planned/`, and 51 name a path that no longer exists because the doc moved.
- **Sprint status is free text:** eight spellings across the JSON files, including both
  `completed` and `complete`.
- **`planned/` holds 368 files:** 129 at its root, 133 in folders named for versions already
  released, 40 in future-version folders, 66 in topic folders. 78 are sprint plans.
- **The context gate** caps a rule at 200 lines, a skill file at 500 and `CLAUDE.md` at 300, and
  requires every rule's path glob to match a tracked file. It was written after a rule scoped to
  `stdlib/**` was found never to load because the tree has `std/`.
- **16 `check_*.sh` scripts; 9 have a `test_check_*.sh`.** Their headers state what a green does
  not prove.
- **Handover documents are nearly absent:** one file in `.claude/handovers/` and three dated
  mission handovers. This repository has 153 `HANDOFF-*` files.

## 4. The pattern across the parts

1. **The checked block held and the prose structure did not.** The ledger, a marked block a script
   validates, has no open rows and is trusted. The queue, the artifact the loop reads every
   iteration, cannot be parsed and was abandoned as a measure of progress.
2. **A question that is not a typed record does not reach the human.** Five ledger rows exist
   because asks were written in prose.
3. **Status encoded in a path rots**, and so do the links that point at the path.
4. **Prose rules accrete and do not prevent recurrence.** One rule has six amendments; the
   verification protocol lists seven misses of rules that already existed.
5. **Always-read documents grow unless every loaded file is capped.** Splitting the skill moved
   488 KB into uncapped reference files. The ledger and the charter have no rotation.
6. **"Done" was a claim until it was computed.** 6 of 1,249 is the measurement.
7. **A self-improving loop can spend itself on itself.** 55% of iterations, two weeks.
8. **Only generated-and-gated documentation stayed true.** Advisory checks that exit 0 changed
   nothing.

## 5. Corrections to earlier statements

To the July note:
- It reported one mission. There are four, on a shared template.
- It called the lifecycle "mechanized transitions". The transitions are scripted and the outcome
  still drifts (§3.9).
- It reported no YAML frontmatter anywhere. Design docs were not re-checked for this; path-scoped
  rules do carry `paths:` frontmatter.

To this session's first summary of AILANG, given to the operator before the full read:
- **It recommended the tagged queue as the level above a plan.** Withdrawn. §3.2 shows the queue
  failed as a structure.
- **It called the index "regenerated wholesale".** True for v1 only (§3.5).
- **It said nine check scripts each have a test.** There are 16, of which 9 have one.

## 6. Implications for Motoko

Candidates, not decisions. "ADR-001" is the plan-structure ADR in this directory.

| # | Candidate | Basis | Relation to ADR-001 | State |
|---|---|---|---|---|
| 1 | Plan structure is a checked document, never prose | §3.2, §4.1 | Already decided (D2, D3). This is outside evidence for it. | Decided |
| 2 | The level above a plan is also a checked document: a dagr document whose tasks are whole plans, so its dependencies stay inside one file | §3.2 | Fills the gap F2 left open, without the fork | Not built, not tested |
| 3 | An operator question exists only as a typed record (a dagr `question` task, or a ledger row). Prose asks do not count | §3.1, §3.2 | Extends D2 | Not decided |
| 4 | A decision ledger for decisions that outlive a plan, with a superseded status and rotation, both of which AILANG lacks | §3.1 | Outside its scope; belongs to the documentation-convention ADR still owed | Not decided |
| 5 | Measure the share of work spent on the harness itself | §3.4 | None | Not built |
| 6 | Compute completion from the diff; treat an exit code as a report, not a result | §3.6 | Supports dagr's evidence tiers | Partly existing (021) |
| 7 | A context-document gate that caps every loaded file, reference files included, with no grandfathered headroom, and checks that path globs match | §3.3, §3.9 | None | Not built |
| 8 | Status lives in validated content, never in a path | §3.8, §3.9 | Consistent with D2 | Belongs to the owed convention ADR |
| 9 | A pick-time reality check before a plan starts: already landed, died mid-flight, premise still true | §3.3 | Complements D4 | Not built |
| 10 | Generate and gate documentation where a generator exists; do not rely on advisory checks | §3.8 | None | Not built |
| 11 | A round-trip check between a plan's prose and its dagr document: one model reads only the dagr document and says what will be done and what counts as done; a second compares that with the ADR's decisions | §9 | Guards the split D3 makes | Not built. The informalizer and comparator exist in `packages/motoko-ext-compose/claimcheck.ail` |
| 12 | A report generated per ADR from the dagr documents: each decision, its tasks, their evidence tier, the commit. It also checks coverage both ways | §9 | Replaces hand-written status | Not built |
| 13 | Every check gets its opposite direction, for example "every decision has a task" beside "no plan contains attempts" | §9 | Applies to its §6 | Not built |
| 14 | Parallel work happens in separate git worktrees: one task, one worktree, one branch, stated in `AGENTS.md`, with a script, a status report and a commit hook | §10 | None | Drafted as PR #218 at the operator's request. The hook is not installed |
| 15 | A short `AGENTS.md` that states the workflow, since every harness here loads it | §10 | None | Started by PR #218, which states the worktree rule only |
| 16 | An overlap check before starting: which open pull requests and which uncommitted work touch the paths a task needs | §10 | Complements candidate 9 | Built as `tools/worktree/status.sh` in PR #218 |
| 17 | `untested` as a first-class result, and a stamped evidence file per outcome (commit, branch, environment) | §10 | Supports D8 and dagr's evidence tiers | Not built |
| 18 | Capture the "before" state before the fix, when it is cheapest | §10 | None | Not built |
| 19 | A provenance table for vendored skills: source, licence, what was changed | §10 | None | Not built |

Not to take: a markdown queue; status by directory; a hand-maintained index; rules added as prose
amendments; and the scheduled-loop infrastructure, which is specific to AILANG's always-on rig.

## 7. Coverage and limits

- **No git history.** The clone is depth 1. Every statement about change over time comes from
  dates and iteration numbers in the text.
- **Incident numbers are AILANG's own records.** None was checked against logs or CI.
- **Read in full:** the v1 charter; the `mission-control` skill and its twelve reference files.
- **Read in part:**
  - Coordinator: 36 source files, 120 of 140 test files and 68 of 77 command files were not opened.
  - Messaging: no test files were opened.
  - Mission runtime: about 1,700 of the driver's 2,511 lines; no test bodies.
  - Docs site: 68 guides, 28 of 35 retro entries and the architecture and benchmark pages were not
    opened.
- **Not read at all:** the other three charters beyond their headings, the mission logs and
  archives, the inner-loop skills (`design-doc-creator`, `sprint-planner`, `sprint-executor`,
  `sprint-evaluator`), and `internal/server`.
- **Negative findings are scoped.** "No caller" and "never set" cover only the directories that
  were checked out.
- **Twelve statements in §3 carry [checked].** They are the ones this document leans on hardest;
  the rest rest on the readers. The quotes in §9 were checked separately.
- **Side effect during the read:** three readers ran a tree-wide search on the scratch clone,
  which fetched extra objects into it. Its working tree was unchanged and no result depends on it.

## 8. Evidence index

All under `evidence/ailang-survey/`, filed verbatim as the readers wrote them.

| File | Lines | Covers |
|---|---|---|
| `evidence/ailang-survey/charter-front.md` | 730 | v1 charter lines 1–520: ledger, bar, goal, guardrails, routing |
| `evidence/ailang-survey/charter-queue-a.md` | 278 | v1 queue, lines 521–2700 |
| `evidence/ailang-survey/charter-queue-b.md` | 192 | v1 queue, lines 2701–4908 |
| `evidence/ailang-survey/skill-gates-0-2.md` | 849 | Skill file, gates 0–2, standing rules, routing references |
| `evidence/ailang-survey/skill-gates-3-5.md` | 1,020 | Gates 3–5, the verification protocol, the false-green catalogue |
| `evidence/ailang-survey/mission-runtime.md` | 939 | Mission registry, driver, iteration runtime, quorum, log rotation |
| `evidence/ailang-survey/coordinator.md` | 1,050 | Task model, storage, approvals, pipelines, verification |
| `evidence/ailang-survey/messaging.md` | 898 | Message model, stores, GitHub sync, triage |
| `evidence/ailang-survey/docs-site.md` | 748 | Site structure, sync mechanisms, the docs mission, retros |

## 9. Addendum: Midspiral (2026-10-04)

Added the same day at the operator's suggestion. Midspiral (midspiral.com/blog) builds formal
verification tools for AI-written code: lemmafit, claimcheck and LemmaScript.

How it was read: eight of its ten posts through a summarising fetch tool; then five were fetched
directly and every passage quoted below was found word for word **[checked]**. The posts on React
state and on reconciliation in collaborative apps were not read.

Motoko already took one technique from it. claimcheck is in
`packages/motoko-ext-compose/claimcheck.ail`, and
`../../research/Claimcheck_for_system_prompts.md` adapts it to system prompt assembly.

Four ideas bear on the planning system.

1. **The executor adjusts the spec.** "LLMs, when faced with a spec they can’t prove, will
   sometimes adjust the spec itself. This isn’t inherently bad. … But it requires vigilance. The
   human must review the final specification." This became D8 of the plan-structure ADR.
2. **Round-trip informalization.** One model reads only the formal artifact and says in plain
   English what it guarantees: "The model does not see the original requirement; it works only
   from the formal code." A second model compares that with the requirement. The measurement: "36
   requirement-lemma pairs, including 8 deliberately bogus lemmas", and "96.3% accuracy across 108
   comparisons (3 runs × 36 pairs)". The stated limit: "Coverage is not checked." Candidate 11.
3. **A generated guarantees report.** lemmafit keeps requirements as structured entries and
   generates "a human-readable report mapping each spec requirement to its corresponding proof",
   showing "what’s been mathematically verified, what relies on assumptions, and what’s still
   unproven." Its stated limit: "The proofs are only as good as the specs." Candidate 12.
4. **Completeness, not only soundness.** A planted bug that rejected a valid outcome survived
   property tests: "We ran 50,000 random action sequences against the buggy kernel with zero
   failures. The tests passed because they check invariants". A test that asked "if a valid
   interpretation exists, did dispatch find it?" did not miss: "we caught the bug 100% of the
   time." This is outside support for rule 3 of the review-loop meta-decision. Candidate 13.

On rules kept as prose it says "markdown files are just fancy prompts", against "You cannot modify
constraints to fit your code. You must modify your code to fit constraints." That agrees with §4.4.

LemmaScript and the Antithesis workshop recap are about verification, not planning. They belong
with projects 027 to 029 and 035, and were not analysed here.

Sources, all under midspiral.com/blog/:
- `claimcheck-narrowing-the-gap-between-proof-and-intent/`
- `intent-envelope-proofs-for-completeness-not-just-soundness/`
- `constraint-driven-programming/`
- `introducing-lemmafit-a-verifier-in-the-ai-loop/`
- `from-intent-to-proof-dafny-verification-for-web-apps/`
- `formally-verified-ai-generated-code-is-already-here/` (summary only)
- `lemmascript-a-verification-toolchain-for-typescript/` (summary only)
- `talking-software-correctness-at-antithesis-sf/` (summary only)

## 10. Addendum: a public skills repository (2026-10-04)

Added the same day at the operator's suggestion. `github.com/michaelshimeles/skills`, read at
`4b72f46` (2026-09-17), is seven agent skills and an `AGENTS.md` that sequences them into four
steps: isolate in a worktree, build, prove with evidence, ship with before-and-after proof and a
review loop.

Read in full: its `AGENTS.md` and `README.md`, and the skills `new-feature`,
`evidence-driven-testing`, `greploop` and `unslop`. Of the evidence recorder
(`evidence-driven-testing/scripts/evidence.py`) only its session states were read. `code-structure`
and `before-and-after` were not read; they are specific to application and UI code.

What bears on Motoko:

1. **One task, one worktree, one branch.** Its `new-feature` skill starts every task in a fresh
   worktree cut from `origin/main` and forbids reusing another agent's. The operator made this a
   rule for this repository the same day. Measured here that day **[measured]**: nineteen agent
   processes had been started in the shared checkout against one in a worktree, and the shared
   checkout held 8 modified tracked files. Nothing an agent loads stated the rule; `AGENTS.md` was
   empty. Candidate 14, drafted as PR #218.
2. **A short `AGENTS.md` that states the workflow.** Theirs is 5 KB: the four steps, the
   multi-agent rules and a completion checklist, with slots for what is specific to a repository.
   Claude Code, Codex and Motoko all load the root `AGENTS.md` here, Motoko through
   `src/core/agents_md.ail`. Candidate 15.
3. **An overlap check before starting.** "Skim open PRs' changed files … and look for uncommitted
   work in shared checkouts. On overlap, stop and ask for direction." Run on this repository
   **[measured]**: 16 open pull requests, 181 files touched by more than one, `Makefile` in seven.
   The same check found PR #216, whose operator ruling reversed part of F2 in the plan-structure
   ADR; that became the ADR's second amendment. Candidate 16.
4. **`untested` is a result.** Its recorder accepts `passed`, `failed` or `untested` and stamps
   each session with the commit, branch and environment: "If a test cannot run … mark it
   `untested` with the reason — never skip silently." In the seven local plan run files
   **[measured]**: 155 outcomes, of which 79 are `verified`, 64 `reported` and 12 `heuristic`; 140
   carry a receipt and every receipt is free text; 15 carry none. A `verified` outcome cannot
   today be re-checked from its receipt. Candidate 17.
5. **Capture the before state first.** "Capture the **before** state while reproducing the issue —
   prior to fixing it, when it is cheapest". Candidate 18.
6. **Say where a vendored skill came from.** Its `AGENTS.md` ends with a table of each skill's
   source and what was changed. Of the five skills under `.claude/skills/` here, `dagr-producer`,
   `herdr` and `observer` state no source **[measured]**. The `dagr-producer` copy is identical to
   what the installed binary prints. Candidate 19.

Not taken:

- **The review loop.** It stops at a fixed ten rounds and resolves a thread it judges a false
  positive. The disposition records of `tools/pr` and the convergence rule in the review-loop
  meta-decision are stricter.
- **The prose-cleanup skill.** A style decision for the operator, not a finding.

One thing building candidate 14 turned up, recorded in PR #218: a commit hook cannot be installed
through the repository's git config here, because the R7 audit
(`.devcontainer/agent_confined/checks/r7_git_audit.py` on this branch; moved to
`.devcontainer/agent_sandbox/checks/` on `main` since) names `core.hooksPath` among the settings
through which agent-writable configuration runs as the operator on the host.
