# Prompt: start Motoko on PLAN-004 by delegation

Use in a **fresh** Motoko session in herdr pane `w1:p18` (exit the current session first: its plan marker
names `run-plan003.json`, and orchestrator mode is read when Motoko starts). Paste everything inside the fence.

```
Implement PLAN-004 by delegation: you orchestrate, delegates implement.

Plan: .agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md
(v1.2 with its six review corrections). §0, §0.10 and §8 are binding.
Operator plan graph: .dagr/run-plan004.json. You are its run.orchestrator
(mode "delegate", at most 2 delegations in flight).

This is a fresh session. On your FIRST Delegate pass
`dagr_plan: ".dagr/run-plan004.json"`, and pass `dagr_task: <graph task id>`
on EVERY Delegate. Never declare another dagr_plan in this session.
.dagr/run-plan003.json (PLAN-003, complete) also names this pane — do not
work on it. After your first Delegate, READ THE RESULT: if the plan was not
recorded, could not be read, or dagr_task was not linked, stop and report.

STEP 0 — before any delegation
1. Read the plan's §0, §0.10, §2 and §8 in full, and `git log --oneline -15`.
   Git is authoritative for what has landed (HEAD 3920814 or later).
2. Run `dagr check .dagr/run-plan004.json --strict --json`; it must print [].
3. Ask me, the operator, in ONE message, and wait for the answers:
   a. PLAN1G — may it be settled? Its criteria: PLANW done by REV2·a2's
      ACCEPT WITH CORRECTIONS (REVIEW-plan004-v1.2-delta-verdicts-codex.md)
      with the six corrections applied (plan §9; PLANW·a3's receipt).
   b. QRET — the corpus retention ruling (plan §0.11 has the proposed default).
   Record each answer in the graph: a `directive` event (verb `rule` for
   PLAN1G, `answer` for QRET) plus an attempt with actor `operator` that
   settles the task, evidence `reported`, receipt quoting my words.
   If I do not settle PLAN1G, delegate nothing.
4. Before your first Delegate, append the first two-file receipt note with
   producer_run=absent (§8).

THE PLAN GRAPH (§8)
- You are its only writer while you run. SETTLE only: append attempts and
  events, set states, edit `policy` exactly as §0.10 says. Every write: a .tmp
  copy, `dagr check --strict --json` must print [], then `mv`. Never add,
  remove or rename tasks; never change deps, criteria or projects. A structural
  need: stop and write a handoff.
- Settle each task BEFORE the next delegation. Receipt = commit hash, or review
  document path + sha256 + verdict, or the plan §6 record location.
- Before each delegation and at each gate append the note
  `receipt task=<id> producer_run=<run file path> producer_state=<state>/<attempt>
  plan_state=<state>/<attempt> evidence=<commit | doc sha256 | §6 record>`.
  An evidence mismatch (producer shows the delegate lost/failed while the plan
  says done, or a commit git does not have) blocks the gate until I rule.

WHAT TO DELEGATE, IN ORDER (only after PLAN1G is done)
- Ready then: SWEEP (heavy), V5 (docs), P2.1 (impl). PRESERVE after QRET;
  SCAN0 after PRESERVE; P1.1 after SWEEP (and after my directive if SWEEP found
  an unexplained red); P1.1R after P1.1; V5R after V5; PSYNC after V5G.
- Opening: V5 and SWEEP in parallel; P2.1 when a slot frees.
- Everything else in P1, and all of P2.2/P3, waits behind PLAN2G. PLAN2G ends
  this session: write a handoff; I start a fresh session on
  .dagr/run-plan004-v2.json.
- Before each Delegate, say which task you picked and why.

DELEGATE CALLS
- Always pass `kind`. Allowed in this container: claude, motoko. Use
  `kind: claude` for impl, docs, test and review tasks. Codex is NOT an allowed
  kind here, so the reviews the plan assigns to Codex (V5R, P1.1R, PREV) go to
  claude — say so in the brief and in the receipt. If I run a review with Codex
  myself and give you its document, record it as the review attempt with actor
  `codex (operator-run)`.
- `task_kind`: impl | docs | test | review, matching the graph task's kind.
  `retry_of`: only when re-issuing a failed or under-delivered delegation of the
  same task.
- The brief must stand alone. Include: the task's plan section IN FULL (quote
  it), the §0 standing rules, the ADR-004 decisions it cites, the gate commands,
  "exactly ONE commit, do not push, message `ADR-004 Dn: …`" (or that task's
  §0.7 exception), and: "the plan is grounded at 3920814 — resolve stale line
  numbers by reading the code and note the drift; do not stop to ask."
  Review briefs follow BRIEF-adr004-v4-review.md's shape: read-only, one review
  file, no commit, no heavy runs, verdict per decision.
- Privacy (§0.6): no corpus content in any brief, note, commit or §6 record —
  counts, digests, indices, identities only. No real session content is copied
  before QRET is answered.

REVIEWS (§0.10) — exactly
- Author done → author task state `review`, attempt stays open. OPEN THE REVIEW
  YOURSELF; its row shows "waits <author>" by design. From round 2 the review
  attempt is `followup` ref the author attempt.
- Verdict → review attempt `done` (receipt: doc path, sha256, verdict). In the
  same document: ACCEPT, or ACCEPT WITH CORRECTIONS with the corrections applied
  and named → author attempt `done`. RETURN → author attempt `rejected`, a new
  author attempt `sent_back` ref the review attempt, and the author policy's
  fail future moved from ·aN to ·aN+1.
- Third RETURN → author task `blocked`. A fourth round only in the same mutation
  as my unblock directive (remove the ·ask future, set rounds_max). dagr will not
  stop you; this rule does. A directive never turns a RETURN into acceptance.
- PLAN1G, QRET, V5G, PLAN2G, P1G, P3G are mine: verify the criteria, report,
  record my answer as a directive. P1.1G you check yourself.

VERIFYING A DELEGATE
- DelegateCheck until it settles. Then check the commit from git
  (`git show --stat <commit>`), re-run the task's gate commands yourself —
  except heavy ones, where you read the delegate's recorded output and say you
  did not re-run — and only then settle. A gate that could not run is not a gate
  that passed.
- A defect you find is a retry (`retry_of`) or a new delegation, never your own
  edit: edits under src/, scripts/, packages/, tools/ are refused to you.

MEMORY (§0.2)
- At most two delegations in flight; at most ONE heavy task (SWEEP, P2.2, P3.1,
  P3.2, P3.3, P5, or any `make dst`). Before starting a heavy task,
  `cat /sys/fs/cgroup/memory.current` must be below 12884901888 (12 GiB).

BUDGET
- Each DelegateCheck costs one step and blocks about 45 s. At about step 1000
  start no new task: collect in-flight work, settle the graph, and write
  .agent/projects/013_core_architecture_for_dst/HANDOFF-<date>-plan004-<last task>.md
  naming the last commit, the in-flight delegate handles and the next ready task
  ids, and stating that the next session is this run's orchestrator and
  delegates.
```

## Notes for the operator

- `run.orchestrator` in `.dagr/run-plan004.json` is `{ pane: "w1:p18", mode: "delegate", max_in_flight: 2 }`.
  `.dagr/run-plan003.json` still names the same pane in delegate mode, so orchestrator mode will list both runs.
  Both plans have a task id `P4`; it is far from anything this session will touch, but do not ask Motoko to
  work on "P4" by bare id.
- `HERDR_ALLOWED_KINDS=claude,motoko` (set in `.devcontainer/agent_confined/docker-compose.yml:273`), so Codex
  reviews cannot be delegated by Motoko. Run them yourself if you want the Codex `gpt-5.6-sol` reviewer, and hand
  Motoko the document.
