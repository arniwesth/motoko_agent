# ADR-001: Where does plan structure live once Linear is gone, and what must dagr become to hold it?

Date: 2026-10-04
Status: **Accepted 2026-10-04; nothing below is executed.** The direction is the operator's, given
that day: *"I would like to get off Linear. dagr (possible our own extended fork) should be single
source of truth for plan structure."* D1–D7 were this document's proposal for carrying that out.
The operator's ruling, the same day: *"I will go with your recommendations"*, in reply to a summary
that listed D1–D7, named D4 as the decision most worth scrutiny, and gave a recommendation for each
of F1–F4. That is read here as accepting D1–D7 and closing F1–F4 as recommended (§7). D4 was not
discussed separately.
**Amended 2026-10-04 with D8**, proposed after reading Midspiral (§2.4) and approved by the operator
the same day (*"yes, do that"*, in reply to a proposal to add it as a dated amendment). D1–D7 are
unchanged in wording except for one pointer at the end of D4, which D8 narrows.
**Amended a second time 2026-10-04: F2 is reversed in part.** In another session that day the
operator ruled that the tree runs our fork of dagr, pinned: *"We will not do upstream PRs for now.
This is a very good reason to move to our own fork and pin it."* The ruling is recorded as D1 of
021's ADR-002 (see "Relates to"). The words were checked against the operator's own message in the
session that received them (2026-10-04 09:52 UTC; a local transcript, not in the tree). The
operator approved recording it here (*"I will go with your recommendations"*, in reply to a
proposal for this amendment). F2, D7, D8, §5, §9 and Appendix B carry the changes, each marked
with the date. The text they amend is left in place.
Grounded at: branch `main`, HEAD `cf54dff9`; `dagr 0.3.1 (contract v3; reads v1/v2)`; the Linear
workspace as read through its MCP server on 2026-10-04.
Provenance: authored in the session that re-read `NOTE-docs-system-design-discussion.md` against
HEAD and surveyed outside practice. The probes in §2.3 were run in that session; their scripts are
not in the tree.

Grounding verified at that HEAD, 2026-10-04:
- The Linear coupling is `tools/pr/linear.ts` (174 lines), its two calls at `tools/pr/pr.ts:295`
  and `tools/pr/pr.ts:326`, `ticketFromBranch` at `tools/pr/lib.ts:153` (used at
  `tools/pr/pr.ts:244`, `tools/pr/pr.ts:316`, `tools/pr/loop.ts:465`, and by `titleFromBranch` at
  `tools/pr/lib.ts:159`), the `linear` server at `.mcp.json:14`, and `LINEAR_API_KEY` at
  `.devcontainer/agent_confined/docker-compose.yml:204`. Motoko itself has no Linear access.
- `.gitignore:116` ignores `.dagr/`. No plan document is tracked. The one tracked run file is
  evidence: `.agent/projects/013_core_architecture_for_dst/evidence/plan004-v2/run-plan004-v2.json`.
- `Makefile:2746` pins `DAGR_VERSION ?= 0.3.1`. Upstream is `aemrebarut/herdr-dagr`: latest release
  v0.3.1 (2026-08-21), last commit 2026-08-23, no pull requests open or closed.
- `motoko-agent/herdr-dagr` is a fork of it, last pushed 2026-09-07. Its `apply-command` branch is
  one commit ahead of upstream `main` and none behind.
- **Not re-run in this session:** `make verify_dagr_producer` (`Makefile:2771`). **Not built or
  exercised in this session:** the fork's `apply` command; what it does is taken from
  `../021_herdr_delegation/DESIGN-dagr-as-delegation-view.md` §10.6.

Relates to:
- `NOTE-docs-system-design-discussion.md` — the discussion this project opened with. **This is not
  the ADR that note expected.** That one, on the documentation convention, is still owed. This
  decides a narrower thing: who owns the structure of planned work.
- `../021_herdr_delegation/DESIGN-dagr-as-delegation-view.md` §10 — the plan/run split (option A2,
  built 2026-09-08) that D2 and D4 build on, and §10.6, the fork. D4 changes one rule that section
  set.
- `../021_herdr_delegation/ADR-002-verified-writes-to-dagr-files.md` — **not on `main`**: it is on
  branch `feat/dagr-verified-writes`, draft PR #216, read at `11e52dc8`. Its D1 is the operator
  ruling that reverses the timing half of F2 here. Its D3 to D9, including the `RunRecord` tool
  that bears on D8, are proposals the operator has not ruled on; this ADR cites them and does not
  adopt them.
- `../../issues/herdr-extension-run-file-drifts-from-operator-plan-file.md` — open. It says nothing
  migrates an operator with a hand-maintained plan file. D2, D4 and D5 are that migration.
- `../016_github_ops/ADR-001-github-pr-ops-pipeline.md` D4 — the PR record's frontmatter. The
  `ticket:` field is not in that ADR; it is in the implementation (`tools/pr/pr.ts:186`). D6
  changes it. That ADR calls its schema provisional pending this project's frontmatter decision
  and expects one migration for it; D6 is a second change unless it is held for that one.
- `../022_linear_integration/RESEARCH-linear-integration.md` — its one taken decision (Motoko
  should create and update Linear issues autonomously) is withdrawn by D1. Nothing was built.
- `../../meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
  rule 2 — why §6 says which checks exist and which are only named.
- `../../meta-decisions/sequence-implementation-handoffs-by-source-surface.md` — why Appendix B
  clusters the way it does.

---

## 1. Context / the question

The structure of planned work (which tasks exist, what each depends on, which are gates, what
counts as done) is written down in three places today, and none of them is authoritative.

| Store | What it holds | State |
|---|---|---|
| Linear | 137 issues, 12 projects | Stale; §2.1 |
| `PLAN-*.md` under `.agent/projects/` (40 files) | Work items, order, gates, in prose | Committed; the copy humans review |
| `.dagr/run-*plan*.json` (7 files) | The same tasks as a typed graph, plus live state | Gitignored; the copy the orchestrator runs from |

The plan files in `.dagr/` are transcribed from the markdown by the orchestrating session. They are
the only copy with typed dependencies, and they exist on one machine.

Three terms are used below with fixed meanings:

- **Plan**: what is intended. Projects, tasks, kinds, owners, dependencies, gate inputs, criteria,
  policies. It changes when the intent changes.
- **Run**: what happened. Attempts, outcomes, evidence tiers, liveness, events, and the task states
  those imply. It changes on every delegate state change.
- **Binding**: which pane holds which authority over a plan in one session. `run.orchestrator`
  with its `mode`, and `run.observer` with its grant.

Today one file holds all three.

## 2. What exists, measured

### 2.1 Linear

Read 2026-10-04: issues MOT-1 to MOT-138 (MOT-94 absent), 12 projects.

- **Nothing has been touched since 2026-09-05** (MOT-133). No issue was created after MOT-138.
- **24 issues are not closed**: 13 backlog, 10 started, 1 unstarted. Seven of the ten "started"
  were last updated in June. Appendix A lists all 24.
- **It disagrees with the tree.** MOT-136 (the dagr producer) is `backlog`; its gate is
  `Makefile:2771`. MOT-134 (reap delegates on exit) is `backlog`; the switch it names is read at
  `packages/motoko-ext-herdr/register.ail:186`. `Makefile:2661` cites MOT-137 for the dagr pane;
  Linear's MOT-137 is about the Lean proof tier. PR #167's record
  (`.agent/github/prs/origin-167/body.md`) carries `ticket: MOT-159`, an id Linear does not have.
- **Practice already left.** The last `mot-N` branch commit is 2026-09-05. Branches since are
  named by project number (`arniwesth/013-dst-architecture-adr`, 2026-09-07, onward).
- **The repo still references it.** 40 documents under `.agent/` and 8 Makefile lines cite `MOT-`
  ids. 11 of the 12 PR bodies that carry a `ticket:` field name one.

### 2.2 dagr

- A third-party herdr plugin, Rust, about 12,100 lines in 16 files, MIT or Apache-2.0.
- Its contract states its limits. It is *"a representation kernel, not an enforcement kernel. It
  carries no fencing, no CAS, no capabilities, and no scheduler/action engine"* ("Design stance" in
  the plugin's `CONTRACT.md` at v0.3.1, which is not in this tree). The binary reads: `check`,
  `view`, `stats`. Every writer replaces the whole document.
- Transport is *"A single JSON document read from a path"*. One run per file. A dagr "project" is
  a visual scope inside one run. Nothing in the contract refers to another document.
- Bounds: 4,096 combined projects, tasks, attempts and futures per document; 32,768 events.
- **The plan/run split is half built.** Since 2026-09-08 `motoko-ext-herdr` reads a plan it never
  writes and seeds its own run file from it (`seed_from_plan`,
  `packages/motoko-ext-herdr/dagr.ail:272`). Seeding is one-directional and happens once per task:
  *"A plan task already present is left completely alone"* (`dagr.ail:194`).
- **The plan file is pane-bound.** Orchestrator mode turns on when a run file under `.dagr/` names
  the session's own pane with `mode: "delegate"` (`mode_from_doc`,
  `packages/motoko-ext-herdr/orchestrator.ail:116`; the scan is `orchestrator_mode`,
  `packages/motoko-ext-herdr/register.ail:230`). The observer's grant lives in the same file
  (`.claude/skills/observer/SKILL.md:43`).
- **In practice the plan file is also the orchestrator's live document.**
  `.dagr/run-031-plan001-r.json` holds 28 tasks, 36 attempts and 142 events.

### 2.3 The probe: can a committed plan be a dagr document at the pinned release?

Each of the seven plan files was projected to structure only: `run.id` and `run.title`, projects,
and per task `id`, `title`, `kind`, `owner`, `project`, `deps`, `inputs`, `criteria`, `policy`,
`note`, with `state` set to `queued` (or left `canceled`). Attempts, events, `run.orchestrator`
and timestamps were dropped. Each projection was then run through `dagr check --strict` at 0.3.1.

| Question | Result |
|---|---|
| Does a structure-only document pass `--strict`? | Yes, once `generated_at` is present. Without it: W100, which `--strict` treats as failure. Checked on the 28-task and 40-task plans. |
| Are extra fields accepted? | Yes. A top-level `plan` block and a per-task `refs` list pass `--strict`. `CONTRACT.md`: *"Unknown fields are ignored (forward compat)."* |
| May `state` be omitted from a plan task? | No. 28 errors on 28 tasks. |
| May a task depend on a task in another document? | No. One error per such edge. |
| How much of a plan file is structure? | 10% to 59% of bytes across the seven files; 16% for `.dagr/run-031-plan001-r.json` (20 KB of 127 KB). The rest is run state. |
| Is the structure also in the markdown? | Yes. 28 of 28 task ids of `.dagr/run-031-plan001-r.json` appear in `.agent/projects/031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md`; 40 of 40 of `.dagr/run-plan004-v2.json` appear in `.agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md`. |

So the pinned upstream release can hold a committed plan today. What it cannot hold is anything
that spans two plans.

### 2.4 Outside practice

Teams running agents at scale keep work state as structured data, not prose: a dependency graph
with a "ready" query (Beads, github.com/steveyegge/beads), or a machine-readable pass/fail feature
list beside a progress log (anthropic.com/engineering/effective-harnesses-for-long-running-agents).
Cursor's planner/worker runs (cursor.com/blog/scaling-agents) report that shared state with locks
failed and that removing roles helped. All three are self-reported. They support the direction and
say nothing about dagr specifically.

Midspiral (midspiral.com/blog), read 2026-10-04, builds formal verification tools for AI-written
code. Two of its observations bear on D8. From its Dafny work: "LLMs, when faced with a spec they
can’t prove, will sometimes adjust the spec itself. This isn’t inherently bad. … But it requires
vigilance. The human must review the final specification"
(midspiral.com/blog/from-intent-to-proof-dafny-verification-for-web-apps). And on rules kept as
prose, "markdown files are just fancy prompts", against the rule it proposes instead: "You cannot
modify constraints to fit your code. You must modify your code to fit constraints"
(midspiral.com/blog/constraint-driven-programming). Both passages were checked against the pages.
Motoko already uses one Midspiral technique: `packages/motoko-ext-compose/claimcheck.ail`.

## 3. Options considered

- **O1. Keep Linear as the tracker and dagr as a view.** The status quo. Rejected by the operator,
  and §2.1 shows it is not being maintained.
- **O2. Markdown is the source; the dagr document is generated from `PLAN-*.md`.** Rejected.
  Deriving dependencies from text is the step that drifts today, and dagr lists it as a non-goal
  (*"No inference of structure … no deriving deps from text"*).
- **O3. A committed dagr document is the source; markdown explains it; run state stays local.**
  Chosen. D2–D5.
- **O4. Commit the live run file, one document for structure and state.** Rejected. It carries
  pane ids and liveness, it is rewritten in full on every delegate state change
  (`.gitignore:112`–`115` says so), and structure is a minority of its bytes.
- **O5. Adopt a different tracker built for agents.** Not pursued. The operator named dagr, the
  extension, the observer and the producer skill already speak its contract, and a new store would
  be a fourth format.

## 4. Decision

**D1. Linear is retired.** No new issues, no `mot-N` branches, no `ticket:` values. The coupling
listed under "Grounding verified" is removed. The workspace is left in place and read-only so the
`MOT-` ids already in the tree still resolve; nothing in Linear is deleted. Old references are not
rewritten.

**D2. Each plan has one committed dagr document, and it is the only place the plan's structure is
stated.** It lives beside its markdown as `PLAN-NNN.dagr.json` in the project directory. It is a
contract-v3 document that passes `dagr check --strict` at the pinned version, and it contains no
attempts, no events and no pane ids. Every task carries `state: "queued"` or `"canceled"`, and the
document carries `generated_at` (the time of its last edit), because §2.3 shows the pinned release
requires both. A plan is revised by commit, not by a new file (`.dagr/run-plan004.json` and
`.dagr/run-plan004-v2.json` would be one path). A task id is never reused or deleted once it is on
`main`; a plan withdraws work with `canceled`.

**D3. `PLAN-*.md` stops restating structure.** It keeps what a graph cannot say: why the plan
exists, what each criterion means at length, risks, and what was considered. It refers to tasks by
id and does not carry dependency tables or sequence lists. This applies to plans started after
adoption. The 40 existing files are history and are not edited.

**D4. Run state is a separate, local document, and structure flows one way into it.** `.dagr/`
stays gitignored. The extension keeps sole ownership of its run file. **Changed from 021 §10.5:**
the structural fields of a task already in the run follow the plan on every publish, where today a
seeded task is never touched again. Attempts, events, liveness and the states they imply remain
the run's and are never overwritten by the plan. At close-out the settled run is committed beside
the plan as the durable record of what happened, as was done by hand for
`.agent/projects/013_core_architecture_for_dst/evidence/plan004-v2/run-plan004-v2.json`.
D8 narrows this for the acceptance fields of a task that has been started.

**D5. The binding leaves the plan.** `run.orchestrator` (with `mode` and `max_in_flight`) and
`run.observer` name panes and grant authority for one session. They move to a local binding
document under `.dagr/` that points at the committed plan. The binding is the only one of the
three documents that names a pane.

**D6. A task's address is `NNN/PLAN-NNN/<task id>`**, for example `031/PLAN-001/P1.2c`. It replaces
`MOT-N` wherever a work item is cited: the PR record's frontmatter, commit messages, handoffs.
Branches are named by project number, which is already the practice. This changes the PR record's
frontmatter (016 D4; the field is defined at `tools/pr/pr.ts:186`).

**D7. Stay on the pinned upstream release for D2–D6; adopt the fork when something needs it, and
name now what would.** §2.3 shows D2–D6 need nothing upstream lacks. Four things do need a fork:

| Capability | Why upstream cannot | State |
|---|---|---|
| A dependency on a task in another plan | Measured: an error at 0.3.1 | Not built. Until then a plan may carry it in an ignored `plan.after` field, which is neither checked nor drawn. |
| A view across documents | One document per path | Not built |
| Partial, refusable edits (`dagr apply`) | The binary only reads | Built on the fork, unreleased, not exercised here |
| A plan mode that drops `state` and `generated_at` | Both required | Not built |

Adopting the fork changes the supply chain: CI stops fetching a published upstream binary by
digest and runs one built from `motoko-agent/herdr-dagr`. That is a larger commitment than any
feature in the table. F2 ruled it out for now (§7).

*Amended 2026-10-04.* The condition D7 named has been met for one row of the table: the operator
adopted the fork for `dagr apply` (021 ADR-002 D1). For this ADR that means:

- **D2–D6 still need nothing beyond the upstream contract.** The fork's first release is proposed
  as upstream 0.3.1 plus `apply`, with the contract unchanged (021 ADR-002 D3, not yet ruled). A
  committed plan therefore stays readable by an upstream binary, and §2.3 still describes what a
  plan must satisfy.
- **The `dagr apply` row is now adopted.** Its release and pin are 021's work. The other three
  rows are unchanged: not built.
- **The supply-chain change described above is no longer hypothetical.** It is 021's to carry
  out, not this ADR's.

**D8. Once a task has been started, the terms it is judged by change only by directive.** *Added
2026-10-04, after acceptance; see the Status line.* A task's acceptance fields are `criteria`,
`deps`, `inputs`, `kind` and `policy`. While a task has no attempt, the plan may change them
freely. Once it has one, a change to any of them, or cancelling the task, must be matched by a
`directive` event that names the task, from the operator or from an observer acting inside a
recorded grant. The agent executing a plan may add work. It may not redefine what finished means
for work it has begun. A producer does not carry an unmatched change into the run, and every
unmatched change is listed for the operator at close-out.

The reason is a gap in D1–D7. D2 has the orchestrator edit the committed plan during a run and D4
carries those edits into the run, so nothing stopped an agent loosening a task's `criteria` until
the task could settle. §2.4 gives the outside evidence that agents do this.

What D8 does not buy. The check sees that the terms changed, not whether they became weaker. And a
`directive` event is itself written by an agent, because dagr "carries no fencing, no CAS, no
capabilities" (§2.2). So D8 makes such an edit visible, attributable and refused by default; it
does not make it impossible. What the operator reviews is the diff of `PLAN-NNN.dagr.json` in the
pull request, with these edits called out.

*Amended 2026-10-04.* 021 ADR-002 proposes a tool, `RunRecord`, through which an operator's ruling
reaches the run file only if the quoted words appear in an operator message (its D4 and D5,
proposed, not ruled). If that is accepted, the directive D8 asks for is a `rule` written through
that tool, and the limit above shrinks to the one that ADR states for itself: a model can still
write the file by hand.

## 5. Consequences

- **`tools/pr` loses a network dependency**, and the confined container stops handing delegates a
  Linear key that acts with write access as its owner
  (`.devcontainer/agent_confined/docker-compose.yml:196`–`204`).
- **The drift issue can close**, because the operator no longer maintains a second file.
- **022 closes without building.** Its open question (whose Linear account an agent acts as)
  dissolves.
- **The orchestrator edits a committed file during a run.** Adding a task mid-run becomes a change
  to `PLAN-NNN.dagr.json`, which the extension reads. In the PLAN-001 live run the orchestrator
  rewrote its plan file about 20 times while delegating (021 DESIGN §10.2). How many of those
  changed structure was not counted. The ones that did would now show up in `git status` and in
  review, which is the point, and a cost.
- **Plans are reviewed as JSON diffs.** A 28-task plan is about 20 KB. Whole-document rewrites
  make noisy diffs unless the writer keeps a stable key order. `dagr apply` would help; it is on
  the fork side of D7. *Amended 2026-10-04:* with the fork adopted, a plan's owner can change a
  committed plan by patch with a precondition instead of rewriting the document (021 ADR-002 D9,
  proposed).
- **Two branches editing one plan will conflict in git.** Nothing here solves that.
- **The level above a plan has no home in dagr.** F2 left it out for now. Linear's 12 projects
  were that level,
  and were stale: eleven read "In Progress", including "Improve Compaction", whose five issues are
  all completed.
- **Expect the fork to be permanent if adopted.** `apply` is a compare-and-set, and upstream's
  contract says it carries no CAS. This is an inference: no pull request has been opened to test
  it. *Amended 2026-10-04:* it is adopted, and the operator has ruled out an upstream pull request
  for now.
- **What Linear gave that nothing here replaces:** a web and mobile view, and notifications.
- **An operator's ruling does not yet survive a restart.** *Added 2026-10-04.* A new session
  starts a new run file seeded from the plan, so a ruling recorded only in the old run file is not
  in it. 021 ADR-002 §5 leaves that question to D4 and D5 here. D2 says a plan holds no state, and
  D8's check has to find the directive. This is open (§9). One candidate is a small rulings block
  in the committed plan, which dagr would ignore (§2.3), modelled on the decision ledger described
  in `RESEARCH-ailang-planning-system-implications.md` §3.1.
- **Two ADRs now edit the same extension files.** *Added 2026-10-04.* WI-2 here and 021 ADR-002's
  tool both change `packages/motoko-ext-herdr/orchestrator.ail`,
  `packages/motoko-ext-herdr/register.ail`, `packages/motoko-ext-herdr/dagr.ail` and the producer
  skill. 021 proposes that its change lands first and this one re-grounds. The operator has not
  ruled on the order.
- **Under D8 the orchestrator loses a shortcut it has today.** Between the two versions of
  PLAN-004's plan file, the criteria of 2 of the 13 started tasks were rewritten with no directive
  naming them (§6). Both read as wording updates for a plan revision; the check cannot tell.

## 6. Checks this ADR names, and whether they exist

| Check | Status |
|---|---|
| A committed plan passes `dagr check --strict` | The binary exists. Run in this session on projections of existing plans (§2.3), not on a plan authored under D2. |
| A committed plan contains no attempts, events or pane ids | Not built |
| The structural fields of a run equal its plan's (D4) | Not built |
| At close-out, the settled run and the plan agree on task ids and deps | Not built |
| A started task's acceptance fields changed with no directive naming it (D8) | Smallest version built in the amending session, `.agent/projects/008_docs_system/evidence/spec_edit_probe.py`. Not wired into anything. |

The second, third and fourth are named, not specified. Each should be built as its smallest working
version before any document relies on it.

The D8 probe compares an earlier and a later document for one plan. On `.dagr/run-plan004.json`
against `.dagr/run-plan004-v2.json` (31 tasks in common, 13 started in the earlier file) it found
10 tasks with an acceptance field changed, 2 of them started, both in `criteria`, neither with a
directive naming the task. On two other pairs, a settled snapshot against its live file and the
tracked evidence copy of plan004-v2 against the local one, it found no change. It covers
`criteria`, `deps`, `inputs` and `kind`; it does not cover `policy` or cancellation. Its inputs
are gitignored files on one machine, so the run cannot be repeated from the tree.

## 7. Forks, closed by the operator 2026-10-04

Each was ruled as recommended.

- **F1. The 24 open Linear issues. RULED:** the ones still wanted are filed as GitHub issues
  through `make issue` (`Makefile:113`) and the rest are closed. They are backlog, not plan
  structure. **Still owed:** which of the 24 are wanted. That is a per-issue call and has not been
  made; Appendix A is the list to make it from.
- **F2. Does "plan structure" include the level above a plan, and when is the fork adopted?
  RULED:** per-plan graphs first, on upstream 0.3.1. The fork is not adopted now. It is reconsidered,
  together with the supply-chain change, when cross-plan dependencies or a portfolio view are wanted
  in dagr. Until then the level above a plan has no home in dagr (§5).
  **REVERSED IN PART 2026-10-04.** The timing half no longer holds: the fork is adopted now, for
  `dagr apply` (Status line; D7). The scope half stands. The first fork release is proposed as
  upstream 0.3.1 plus `apply` and nothing else, so cross-plan dependencies and a view across
  documents are still unbuilt, and the level above a plan still has no home in dagr.
- **F3. The address format and field name in D6. RULED:** `NNN/PLAN-NNN/<task id>`, and the PR
  record field is renamed from `ticket:` to `task:`.
- **F4. Plans already in flight. RULED:** they finish as they are. D2–D5 apply to plans started
  after adoption. This includes the one live in `.dagr/run-037-plan001.json`.

## 8. Predictions to settle at project close

- (a) No PR record created after the Linear coupling is removed carries a `MOT-` id, and
  `tools/pr` makes no request to Linear.
- (b) For each plan started under this ADR, the committed plan and the settled run agree on task
  ids and dependencies at close-out.
- (c) `.agent/issues/herdr-extension-run-file-drifts-from-operator-plan-file.md` closes and no issue of the same
  shape opens.
- (d) No settled run committed under this ADR shows an acceptance field changed on a started
  task without a directive naming it (D8).
- **Kill criterion:** if, in the first two plans run under this ADR, the orchestrator makes
  structural edits in a `.dagr/` copy that never reach the committed plan, D2 has failed and this
  question reopens.

## 9. What this does not decide

- The documentation convention for the rest of `.agent/` (the ADR the 008 note expected).
- Whether `.agent/issues/` is frozen in favour of GitHub issues.
- Any index over documents, including `../036_chdb_memory/`.
- The binding document's format (D5) and the mechanism of D4's re-projection. Those belong to the
  implementation plan, written fresh against the source.
- Where an operator's ruling lives between sessions (§5). *Added 2026-10-04.*
- Anything in 021 ADR-002 beyond its D1, and the order in which the two ADRs' extension changes
  land. *Added 2026-10-04.*
- A round-trip check that a plan's dagr document says what its prose intends, and a generated
  report from each decision to its tasks and their evidence. Both are candidates in
  `RESEARCH-ailang-planning-system-implications.md` §9.

## Appendix A: the 24 open Linear issues (as read 2026-10-04)

| Id | Linear status | Last updated | Title |
|---|---|---|---|
| MOT-138 | backlog | 2026-09-02 | verify_core: an undecided verdict fails the build as if the code were broken |
| MOT-137 | backlog | 2026-09-02 | Lean proof tier: report `unavailable` as a counted state, not silence |
| MOT-136 | backlog | 2026-08-31 | dagr producer: motoko-ext-herdr writes the delegation run file (built; gate at `Makefile:2771`) |
| MOT-135 | backlog | 2026-08-31 | Tolerant answer envelope: optional outcome line in delegate answers |
| MOT-134 | backlog | 2026-08-31 | F-5 TUI side: reap owned delegates on clean exit (switch read at `register.ail:186`) |
| MOT-126 | backlog | 2026-08-23 | agent_confined: fix R9 leg6's misattribution, document the sandbox denial, close the permission audit gap |
| MOT-120 | backlog | 2026-08-23 | Candidate: make `herdr agent wait motoko` work by calling `agent rename` |
| MOT-119 | backlog | 2026-08-22 | Candidate: put display tokens in the sidebar row via `pane report-metadata` |
| MOT-117 | backlog | 2026-08-22 | Settle D3's second path: the blocked row superseded by the runtime-exit recovery idle |
| MOT-112 | backlog | 2026-08-22 | R9 leg 4 checks git config, not what commits actually carry |
| MOT-108 | backlog | 2026-08-22 | Residual 4: the operator's devcontainer stays unhardened, as a standing accepted risk |
| MOT-107 | backlog | 2026-08-22 | Residual 3: R9 leg 6 cannot pass on OrbStack |
| MOT-106 | backlog | 2026-08-22 | Residual 2: OBSIDIAN_MCP_TOKEN, the stated premise for removing it is false |
| MOT-116 | started | 2026-08-22 | Take the ADR's five owed measurements against a live herdr pane |
| MOT-95 | started | 2026-08-13 | New projects scoping |
| MOT-66 | started | 2026-08-05 | Close acceptance row 10 |
| MOT-23 | started | 2026-06-27 | Fix lean binary not found |
| MOT-22 | started | 2026-06-23 | Prevent Motoko banner from being printed in headless mode |
| MOT-14 | started | 2026-06-22 | Add Bedrock / LiteLLM compatibility |
| MOT-18 | started | 2026-06-21 | Fix TUI edit rendering |
| MOT-19 | started | 2026-06-21 | Fix TUI test harness |
| MOT-17 | started | 2026-06-21 | Re-enable graceful ESC steering capability |
| MOT-10 | started | 2026-06-21 | Merge main into latest auto-research branch |
| MOT-13 | unstarted | 2026-06-21 | Remove stale AILANG teacher prompt |

Only MOT-136 and MOT-134 were compared with the tree. The other 22 carry Linear's status as read.

## Appendix B: implementation sequence (carried forward)

Clustered by shared source surface. The plan is authored fresh from a handoff, not here.

- **WI-0, retire the Linear coupling, and WI-3, the PR record's identity (D1, D6).** One cluster:
  both edit `tools/pr/lib.ts` and `tools/pr/pr.ts`. Also `.mcp.json`, the two compose files, and
  `tools/pr/README.md`.
- **WI-1, the plan document convention and its check (D2, D3).** Reads the tree; independent of
  the others. Includes the first check in §6 as a `make` target and the smallest version of the
  second.
- **WI-2, the extension: binding and re-projection (D4, D5), with D8's refusal.**
  `packages/motoko-ext-herdr/` (`orchestrator.ail`, `register.ail`, `dagr.ail`), the observer
  skill, the dagr-producer skill. Ends in `make verify_dagr_producer` green. *Amended 2026-10-04:*
  if 021 ADR-002's change to these files lands first, this work re-grounds against it.
- **WI-4, close-out snapshot (D4), with D8's list of unmatched changes.** After WI-2.
- **WI-5, the fork (D7).** Out of scope under F2's ruling, until that question is reopened.
  *Amended 2026-10-04:* reopened and ruled. The fork release and the pin are 021's work, not a work
  item of this ADR. Cross-plan dependencies and a view across documents remain unplanned.
- **The Linear triage (F1).** Not a work item for an agent to run unattended: it files public
  issues and closes Linear ones, and which of the 24 are wanted is the operator's call.
