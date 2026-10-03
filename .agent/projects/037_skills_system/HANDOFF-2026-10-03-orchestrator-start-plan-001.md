# HANDOFF 2026-10-03 — Orchestrator for PLAN-001 (037): the skills extension, up to gate G1

You are the **orchestrator** for the first half of `PLAN-001-implement-adr-001.md`: the
operator's preconditions, the baseline (P0), and the throwaway prototype with its measurements
(P1), ending at the operator's gate G1. You run in your own Herdr tab. You delegate every task
to a fresh agent in a pane you open, you are the **single writer** of the dagr run file that
shows the work, and you do not implement a task yourself. The operator supervises through the
graph and may attach an observer.

Parts P2 to P6 are **not yours yet**. The plan holds them in outline on purpose, because what
the prototype measures can change what they build. When G1 is reached you stop and wait.

## Why the work is shaped this way

The ADR has been through two rounds of independent review, and each round found that a
confident fix was wrong: twice because nobody had run the thing. P1 exists so that the three
decisions still resting on unrun assumptions are tested before any core or ABI change is made.
Treat a surprising result in P1 as the point of the exercise, not as an obstacle to get past.

## Read first, in this order

Paths under `.agent/projects/037_skills_system/` are in the branch's worktree,
`/workspaces/motoko_agent-skills`, where this project's documents are committed. The run file is
in the shared checkout, `/workspaces/motoko_agent/.dagr/`.

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §0 standing rules, §2 and
   §3 (your scope), §7 the open questions.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — Accepted v0.3. Read D7, D10,
   D4 and D9 closely: they are what P1 tests. §5 lists what earlier versions got wrong, so you
   do not repeat it.
3. `.dagr/run-037-plan001.json` — the graph. Twenty-one tasks, all queued. Each task's
   `criteria` is its acceptance, taken from the plan.
4. `.claude/skills/dagr-producer/SKILL.md` and `.claude/skills/herdr/SKILL.md` — you use both
   throughout. `dagr --skill` prints the first if you cannot load it as a skill.
5. `.agent/meta-decisions/sequence-implementation-handoffs-by-source-surface.md` and
   `re-ground-inherited-anchors-before-building.md`.
6. `.agent/projects/037_skills_system/evidence/` — the probes already written (`m1` to `m8`).
   P1's delegates should reuse them, not rewrite them. `m2_trigger_probe.py` holds the task set
   P1.3b runs through the real runtime.
7. `.agent/projects/031_system_one_decisions/HANDOFF-2026-09-20-orchestrator-release-line.md`
   and one `LEG-*.md` beside it — the house shape for an orchestrator's records and for a
   delegate's brief.

Grounding: the shared checkout is on `main` at `cf54dff9`. Every path the ADR and the plan cite
is unchanged since `21ba95c9`, where the research began. AILANG v0.47.2, extension ABI 8.0. Check
both again before you write a brief.

## The branch to use

**Use `feat/skills-extension` for this work.** The operator created it for the implementation
on 2026-10-03 and said it is the branch to use. It is cut from `main` at `cf54dff9` and checked
out in its own worktree at `/workspaces/motoko_agent-skills`. Its first commit is this project's
documents, together with the deletion of the design doc the ADR replaces.

- Everything this project commits goes on that branch, in that worktree: the project's
  documents, your briefs and records, the delegates' evidence, and from P2 onward the
  implementation.
- Do not create another branch for this work, do not commit any of it to `main`, and do not
  push unless the operator asks.
- Do not switch the shared checkout onto it. Other sessions use that checkout and move it
  between branches; a commit of theirs would land on this branch. Work on the branch through its
  worktree.
- The one exception is P1's prototype, which is throwaway. It gets a second worktree on a
  scratch branch cut from `feat/skills-extension`, so it builds on the same base and cannot be
  merged by accident. Its results (the scripts, the tables, the note) are committed on
  `feat/skills-extension`; its code is not. The scratch branch and its worktree are removed
  after G1.

## The state you inherit

No task has started. This project's documents are committed on `feat/skills-extension`, and
the copy in its worktree is the one of record: this file, the ADR, the plan, the research, the
four reviews and `evidence/`. Write your briefs and records there.

The run file stays in the shared checkout, `/workspaces/motoko_agent/.dagr/run-037-plan001.json`.
That checkout is shared with other live sessions, and nothing in its working tree is this
project's any more:

- **A separate, finished change to the code-graph tool:** `tools/code-graph/extractor/iface_pass.py`,
  `tools/code-graph/tests/test_iface_parallel.py`, and the tool's `README.md` and `AGENTS.md`.
  Which branch it gets is the operator's (`Q-CGRAPH`). It blocks nothing here; do not commit it.
- **Other sessions' changes, leave alone:** `Makefile`, `ailang.lock`, the 030 research file,
  and every other untracked path.

The worktree `/workspaces/motoko_agent-fix3` belongs to another session. Other sessions also
move the shared checkout between branches; do not switch it yourself.

## Your first acts

1. **Take the graph.** In one write, set `run.orchestrator.pane` to your `$HERDR_PANE_ID`,
   refresh `generated_at`, and append a `note` event saying you took the run and in which pane.
   Always write `run-037-plan001.json.tmp`, run `dagr check --strict --json` on it, and rename
   only when it prints `[]` with exit 0. The previous producer, in pane `w7:p1`, has stopped
   writing.
2. **Put the open questions to the operator** in one short message. They are the operator's to
   decide, not yours: `Q-OPENAI` and `Q5`, and `Q-CGRAPH`, which concerns the unrelated
   code-graph change and blocks nothing. `Q-BRANCH` is settled: the branch is
   `feat/skills-extension` and the documents are committed on it. None of the open questions
   blocks the baseline, so do not wait for the answers before starting.
3. **Write the briefs** for `P0` and `P1.1`, as files beside this one, and commit them on the
   branch.
4. **Open `P0`.** It is ready now.

## How you delegate

- **One delegate per task, fresh.** Split a pane in your own tab without taking focus, and start
  the agent with the permission bypass, which is this repository's default for delegates:
  `claude --dangerously-skip-permissions --model <model>` or `codex --yolo`. Use the model
  `make claude` launches unless the operator names another.
- **The brief is a file,** `LEG-<task>.md` in this folder, written from the plan's part and the
  task's `criteria`: what the task is for, the files and commands involved, the checks that end
  it, where its evidence goes, and what to send back. The prompt you send points at the file.
  A delegate that receives a pasted brief often asks whether it should start; look at the pane
  after half a minute and answer.
- **Write only the brief you can ground.** `P0` and `P1.1` now. `P1.2` after `P1.1` has an
  answer. The measurements after the prototype exists.
- **P1's delegates work in the prototype's own worktree,** on its scratch branch, never in the
  shared checkout. The root manifest, the lock and the generated registry are edited there and
  nowhere else.
- **Check before you settle.** Before an attempt is `done`, run its checks yourself or read the
  evidence file it produced. `verified` needs your own mechanical receipt; a delegate's report
  alone is `reported`. Work that fails the check is `rejected`, and the fix is a new attempt
  with `cause: sent_back`. Never rewrite an attempt or an event.
- **Keep the graph live.** A working attempt needs its `locator` and `liveness`; refresh
  `last_output_at` as delegates produce output, and `generated_at` on every write.

## What belongs to the operator

- The open questions (`Q-OPENAI`, `Q5`, `Q-SPEND`, `Q-CGRAPH`) and the gate `G1`. When one
  becomes ready, ask plainly and wait. Record the answer as the operator's attempt and a
  directive. Do not settle one yourself, and do not read silence as an answer.
- **Spend.** P1.3 b to e call models through OpenRouter. After the prototype is built, state a
  cost estimate and get the go-ahead (`Q-SPEND`) before any of them runs.
- **A decision that has to come back.** Three results end a line of work instead of continuing
  it: the inventories reject an extension that imports `std/yaml` (P1.1); OpenAI rejects the
  index (P1.3e); the bare relative root does not index the workdir's skills in a real session
  (P1.3a). In each case stop that line, record the evidence, and tell the operator which ADR
  decision it sends back. Do not design around it.
- If a delegate finds the ADR wrong in any other way, the same rule holds: stop, record,
  report.

## Rules that bind you

- Do not edit `src/`, `packages/`, `tools/` or `scripts/` yourself.
- Do not touch another session's panes, tabs or worktrees, or the paths listed above as not
  ours. Do not close a pane you did not open.
- Heavy runs one at a time. The DST targets in `P0` are slow and the machine is shared; do not
  run two delegates' heavy targets together.
- No credentials in a brief, a record or a commit. The OpenAI route for `P1.3e` is supplied by
  the operator.
- Report in the graph, and in one short message per settled task: what was established, what
  failed its check, what is ready next. Ask nothing the plan already answers.

## Things already measured, which a newcomer would get wrong

- Under the sandbox the TUI sets, a relative path resolves against the workdir, not against the
  directory the runtime was started in. The skill root is the bare path `.motoko/skills`.
  Deriving it from environment variables was tried and was wrong (ADR D7).
- The model does not see the text an extension returns. It sees a JSON envelope around it. A
  marker in the text does not survive compaction, and a directory shown to the model has to be
  relative to the workdir (ADR D8, D10).
- `P0` is expected to show red gates before any change: `driver_plus_herdr` is registered as
  known-red, and the research's survey reports others (unverified). Record them; they are the
  baseline, not failures of this project.
- This OpenRouter account's OpenAI key was rejected on 2026-10-03, which is why `Q-OPENAI`
  exists.
- The shared code-graph cache is stale and its whole-repository profile does not build. No task
  here needs it.

## Done, for this handoff

`G1` is open: every P1 task is settled with its evidence, `NOTE-p1-prototype-results.md` states
the answer to each of the plan's questions Q1 to Q4, the `promoted` event is appended, and the
operator has the note in front of them. Then stop. The worktree stays until the operator has
ruled, and nothing from it is merged.
