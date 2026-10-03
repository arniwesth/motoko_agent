# HANDOFF 2026-10-03 — Orchestrator for PLAN-001 (037): the skills extension, up to gate G1

You are a Motoko session and the **orchestrator** for the first half of
`PLAN-001-implement-adr-001.md`: the baseline (P0) and the throwaway prototype with its
measurements (P1), ending at the operator's gate G1. You route the work. Delegates do it. The
operator supervises through the dagr view.

Parts P2 to P6 are **not yours yet**. The plan holds them in outline on purpose, because what
the prototype measures can change what they build. When G1 is reached you stop and wait.

## Check this first

The plan file `.dagr/run-037-plan001.json` names pane `w8:p1` as this run's orchestrator with
`mode: "delegate"`. If you are running in that pane, the herdr extension has put you in
orchestrator mode, and your system prompt contains a section headed "Orchestrator mode" that
names that file.

If that section is not in your prompt, stop and tell the operator. The mode is decided when
Motoko starts, so the plan file has to name your pane before you are launched. Do not try to
work around it.

## Why the work is shaped this way

The ADR has been through two rounds of independent review, and each round found that a
confident fix was wrong: twice because nobody had run the thing. P1 exists so that the three
decisions still resting on unrun assumptions are tested before any core or ABI change is made.
Treat a surprising result in P1 as the point of the exercise, not as an obstacle to get past.

## Read first, in this order

Paths under `.agent/projects/037_skills_system/` are in the branch's worktree,
`/workspaces/motoko_agent-skills`, where this project's documents are committed.

1. `.agent/projects/037_skills_system/PLAN-001-implement-adr-001.md` — §0 standing rules, §2 and
   §3 (your scope), §7 the open questions.
2. `.agent/projects/037_skills_system/ADR-001-skills-system.md` — Accepted v0.3. Read D7, D10,
   D4 and D9 closely: they are what P1 tests. §5 lists what earlier versions got wrong.
3. `/workspaces/motoko_agent/.dagr/run-037-plan001.json` — the plan as a graph. Each task's
   `criteria` is its acceptance, taken from the plan. Read it. Never write it.
4. `.agent/meta-decisions/sequence-implementation-handoffs-by-source-surface.md` and
   `re-ground-inherited-anchors-before-building.md`.
5. `.agent/projects/037_skills_system/evidence/` — the probes already written (`m1` to `m8`).
   Delegates reuse them. `m2_trigger_probe.py` holds the task set P1.3b runs through the real
   runtime.

Grounding: the shared checkout is on `main` at `cf54dff9`. Every path the ADR and the plan cite
is unchanged since `21ba95c9`, where the research began. AILANG v0.47.2, extension ABI 8.0. Check
both again before you write a brief.

## How you delegate: the `Delegate` tool, and nothing else

Every delegation goes through the `Delegate` tool and is followed with `DelegateCheck`. Do not
split panes or start agents with the `herdr` command line, and do not write or edit any file
under `.dagr/`. The herdr extension does that part: it keeps its own run file, seeded from the
plan, records each attempt against the plan task you name, and opens the dagr view for the
operator on your first delegation.

Pass these on every `Delegate`:

| Parameter | Value |
| --- | --- |
| `kind` | `"claude"`. It is required here: two kinds are permitted and there is no default. |
| `model` | `"claude-opus-5-5"`. Always this, stated explicitly. |
| `dagr_plan` | `".dagr/run-037-plan001.json"` on your first call; it is remembered after that. |
| `dagr_task` | The plan task this work is, for example `"P0"` or `"P1.1"`. |
| `task_kind` | `test` for the baseline, the probe and the measurements; `impl` for the prototype; `docs` for the results note. |
| `cwd` | The worktree the task works in (see "The branch to use"). |
| `prompt` | The whole task, standing alone: the delegate shares none of your context. Point it at its brief file and state the checks that end the task and what to send back. |

- **One delegation in flight.** The plan file sets that limit, and the baseline's targets are
  heavy on a machine other sessions share.
- **A retry is `retry_of`,** naming the earlier delegation, so it is recorded as another attempt
  at the same task and not as new work.
- **If `Delegate` is refused,** report the refusal text to the operator. Do not fall back to the
  command line.

## Briefs and records

- **The brief is a file,** `LEG-<task>.md` in the project folder in the worktree, written from
  the plan's part and the task's `criteria`: what the task is for, the files and commands
  involved, the checks that end it, where its evidence goes, and what to send back. Commit it on
  the branch. Writing under `.agent/` is yours; edits under `src/`, `scripts/`, `packages/` and
  `tools/` are refused to you by policy and belong to delegates.
- **Write only the brief you can ground.** `P0` and `P1.1` now. `P1.2` after `P1.1` has an
  answer. The measurements after the prototype exists.
- **Check before you accept.** Read the evidence a delegate produced, or re-run its check
  yourself, before you treat a task as done. A defect you find is a retry of the task, not an
  edit of yours.
- **Evidence is committed on the branch** by the delegate that produced it, under
  `evidence/baseline/` for P0 and `evidence/p1/` for P1.

## The branch to use

**Use `feat/skills-extension` for this work.** The operator created it for the implementation
on 2026-10-03 and said it is the branch to use. It is cut from `main` at `cf54dff9` and checked
out in its own worktree at `/workspaces/motoko_agent-skills`.

- Everything this project commits goes on that branch, in that worktree: the project's
  documents, your briefs, the delegates' evidence, and from P2 onward the implementation.
- Do not create another branch for this work, do not commit any of it to `main`, and do not
  push unless the operator asks.
- Do not switch the shared checkout, `/workspaces/motoko_agent`, onto it. Other sessions use
  that checkout and move it between branches.
- The one exception is P1's prototype, which is throwaway. It has a second worktree,
  `/workspaces/motoko_agent-p1proto`, on the scratch branch `scratch/p1-prototype`, cut from
  `feat/skills-extension`. Its results (the scripts, the tables, the note) are committed on
  `feat/skills-extension`; its code is not. The scratch branch and worktree are removed after
  G1.

So `cwd` is `/workspaces/motoko_agent-skills` for P0, the results note and anything that only
reads the tree, and `/workspaces/motoko_agent-p1proto` for P1.1, P1.2 and the measurements.

## The state you inherit

A first orchestrator was started earlier today and stopped by the operator before any task
finished. It delegated through the `herdr` command line on the wrong model, edited the plan file
by hand, and never opened the dagr view. This handoff has been rewritten to rule those out. What
it left:

- **Commit `ecf7f48c` on the branch,** holding `LEG-P0.md` and `LEG-P1.1.md`. They were written
  for the other way of delegating: they name pane `w8:p1` as the place to report, ask for a
  typed envelope, and tell the delegate not to write evidence files. Read them, keep what is
  sound, and rewrite the rest before you use them.
- **The scratch worktree** described above, already created and at the same commit as the
  branch.
- **One lost attempt on `P0`** in the plan file. Its delegate's pane closed with no result. `P0`
  is queued again and nothing of it was recorded.

The shared checkout's working tree holds changes that are not this project's. Leave them alone:
a finished change to the code-graph tool (four files under `tools/code-graph/`, waiting for the
operator to name a branch), and other sessions' edits to `Makefile`, `ailang.lock` and other
paths. The worktree `/workspaces/motoko_agent-fix3` belongs to another session.

## Your first acts

1. **Confirm you are in orchestrator mode** (see "Check this first").
2. **Read** the material above.
3. **Bring the two briefs up to date** and commit them on the branch.
4. **Delegate `P0`.** It is ready: nothing it depends on is open. The dagr view should open by
   itself as you do. If it does not, say so in your next message to the operator.
5. **In your first message to the operator,** report what you delegated and put the open
   questions in the same message (next section). A message to the operator ends your turn, so
   send it when a delegation is in flight and you have nothing else to do, not before.

## What belongs to the operator

- **The open questions:** `Q-OPENAI` (a working route to an OpenAI model for P1.3e, or OpenAI
  ruled out of scope), `Q5` (Amendment 5 before or after the release tag; needed before P2),
  `Q-CGRAPH` (the branch for the unrelated code-graph change; blocks nothing), and later
  `Q-SPEND`. And the gate `G1`. Ask plainly. Do not answer one yourself, and do not read silence
  as an answer. You cannot record an answer in the plan file; state it in your report, and the
  plan's owner updates the file.
- **Spend.** P1.3 b to e call models through OpenRouter. After the prototype is built, state a
  cost estimate and get the operator's go-ahead before any of them runs.
- **A decision that has to come back.** Three results end a line of work instead of continuing
  it: the inventories reject an extension that imports `std/yaml` (P1.1); OpenAI rejects the
  index (P1.3e); the bare relative root does not index the workdir's skills in a real session
  (P1.3a). In each case stop that line, keep the evidence, and tell the operator which ADR
  decision it sends back. Do not design around it.
- If a delegate finds the ADR wrong in any other way, the same rule holds: stop, keep the
  evidence, report.

## Rules that bind you

- You do not implement. Edits under `src/`, `packages/`, `tools/` and `scripts/` are a
  delegate's.
- Do not touch another session's panes, tabs or worktrees, or the changes listed above as not
  this project's.
- Heavy runs one at a time.
- No credentials in a brief, a record or a commit. The OpenAI route for `P1.3e` is supplied by
  the operator.
- One short message to the operator per settled task: what was established, what failed its
  check, what is ready next. Ask nothing the plan already answers.
- A handoff you write for a later session must say that it is this run's orchestrator and that
  it delegates.

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
- The worktree is a fresh checkout with no installed dependencies or build output. A gate that
  is red there for want of a build is not a baseline red. The P0 brief should have the delegate
  tell the two apart.
- This OpenRouter account's OpenAI key was rejected on 2026-10-03, which is why `Q-OPENAI`
  exists.
- The shared code-graph cache is stale and its whole-repository profile does not build. No task
  here needs it.

## Done, for this handoff

`G1` is ready for the operator: every P1 task has been checked by you against its evidence,
`NOTE-p1-prototype-results.md` states the answer to each of the plan's questions Q1 to Q4, and
the operator has the note in front of them. Then stop. The scratch worktree stays until the
operator has ruled, and nothing from it is merged.
