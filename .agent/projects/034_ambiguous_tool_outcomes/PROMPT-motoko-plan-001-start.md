# Prompt: start Motoko on 034 PLAN-001, by delegation

For a **fresh** Motoko session that orchestrates
[`PLAN-001-effect-disclosure.md`](PLAN-001-effect-disclosure.md). Motoko delegates each task to a
Claude delegate through the herdr extension, checks the result, and moves on to the next.

**This prompt covers the first session only: workstream W0 (Phase 0), W0.1 to W0.7, in one pull
request.** W0b, W1, W2 and W3 each start from `main` after the pull request before them has merged,
so each is a later session (*Later sessions*, below).

Written 2026-10-17 against plan v1.2, which merged in #273 (`main` `e9d2ff07`, 2026-10-18). The
plan's code anchors are at `e69aaad7`. This file adapts 005's
[`PROMPT-motoko-finalize-policy-migration-start.md`](../005_harness_policy_boundary/PROMPT-motoko-finalize-policy-migration-start.md),
whose W1 session shipped as #256. The herdr extension it was checked against has not changed
since (`a7c77571`, 2026-10-08).

Revised 2026-10-18, after the first session (`session_1792309035163`) busy-polled `DelegateCheck`
instead of parking: *VERIFYING A DELEGATE* step 1 and the end-of-turn rule now tell the
orchestrator to wait by ending its turn. The same pull request changes the herdr extension's
tool texts to say so, sizes `DelegateCheck`'s wait under the shell's 30 s limit, and bounds
the two waits that never woke on their own: a delegate that never registers (2 min) and one
idle with no answer file (60 min). `MOTOKO_WAKE_REGISTER_TIMEOUT_MS` and
`MOTOKO_WAKE_IDLE_NO_ANSWER_MS` change them.

## Before you start

Four steps.

1. **Pull the shared checkout.** It needs `main` with #273, which brought the plan and its graph,
   and with the pull request that added this file and the start script. The start script reads
   the graph from the shared checkout, and worktrees are cut from `origin/main`.
2. **Check that delegates have a permission mode.** The extension starts a Claude delegate with
   no flags, so it comes up in whatever `permissions.defaultMode` in `~/.claude/settings.json`
   says. Without it, a delegate stops at its first shell command. **It was set to `auto` on
   2026-10-18**, the mode 005's session ran with. The file is outside the repository and does not
   survive a container rebuild, so check it again after one; the start script warns if it is
   missing.
3. **In the herdr pane Motoko is to run in, start it with the script, from the repository root,
   in place of `make motoko`:**

   ```sh
   cd /workspaces/motoko_agent
   bash .agent/projects/034_ambiguous_tool_outcomes/start-orchestrator.sh
   ```

   Arguments go on to `make motoko`, for example `PROFILE=dogfood`. The script refuses to start
   from any other directory, because the dagr pane would then look for its run file in the wrong
   place (005, *What the first session showed*). It warns if no permission mode is set, and if
   another run file names the same pane.
4. **Paste the prompt below.** Read *Notes for the operator* first: pasting the prompt accepts
   them.

**Why starting Motoko alone is not enough.** The herdr extension puts a session in orchestrator
mode only if a file under `.dagr/` names that session's own pane with `mode: "delegate"` when
Motoko starts. The committed graph names no pane (008 ADR-001 D5). So
[`start-orchestrator.sh`](start-orchestrator.sh) writes `.dagr/run-034-plan-001.json`, which is the
committed graph plus this pane's id, checks it with `dagr check --strict`, and then runs
`make motoko`. The file is local and gitignored.

## The prompt

Paste everything inside the fence.

```
Implement Phase 0 of 034 PLAN-001 by delegation: you orchestrate, Claude delegates
implement.

Plan: .agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md
(status "Phase 0 ready to implement", v1.2, reviewed twice). It implements
ADR-001-effect-disclosure-for-tool-faults.md in the same directory, accepted as amended
on 2026-10-17. The ADR's rulings (its section 6), the plan's choices C1-C5, and C3's
wire vocabulary and two sentences are settled. Do not reopen them.
Plan graph: .dagr/run-034-plan-001.json. You are its run.orchestrator (mode
"delegate", one delegation in flight). It is a local copy of the committed graph
beside the plan, plus this pane's id.

THIS SESSION
W0 only: W0.1, W0.2, W0.3, W0.4, W0.5, W0.6, W0.7, in that order, in one worktree,
on one branch, as one pull request. Nothing from W0b, W1, W2 or W3: they start from
main after W0 has merged, and merging is mine. When W0's pull request is open, report
and stop.

STEP 0, before any delegation
1. Read AGENTS.md. In the plan, read the header, "Standing rules", "What is true at
   e69aaad7", "Choices this plan makes" and all of "Phase 0". In the ADR, read D2's
   table and section 6.
2. `git fetch origin`, then `git log --oneline -3 origin/main`. If the plan file is
   not in this checkout, stop and tell me.
3. `dagr check .dagr/run-034-plan-001.json --strict --json` must print [].
4. `git status --short` here, and keep the output. This checkout already has
   unrelated uncommitted files, and you will compare against this list after every
   task.
5. `mkdir -p tmp/034-orchestrator`. Your logs and any handoff go there. tmp/ is
   untracked.
6. `id -u`. If it prints 0, stop and tell me: W0.5 and W0.6 are accepted only on a
   run as a non-root user, and delegates run as the same user as this pane.
7. `tools/worktree/status.sh src/core/types.ail src/core/tool_runtime.ail
   src/core/tool_dispatch_adapter.ail src/core/tool_catalog.ail
   scripts/dst/world_state_probe.ail Makefile`, and keep the output. If an open pull
   request changes `validate_path_common` or `atomic_write` in tool_runtime.ail (#234
   and #209 did when the plan was written), put that in W0.2's brief. Do not stop for
   it.

WORKTREE: ONE, NEVER THIS CHECKOUT
- This directory, /workspaces/motoko_agent, is the shared checkout. It stays on main.
  Nobody edits, commits or switches branches here: not you, not a delegate.
- Before W0.1, create the worktree yourself:
    tools/worktree/new.sh 034-w0 arniwesth/034-w0-effect-disclosure
  It appears as /workspaces/motoko_agent-034-w0. If the script refuses, stop and tell
  me. Do not pick another name.
- Every W0 task runs in /workspaces/motoko_agent-034-w0, on that one branch, one
  commit per task, one task after another. Do not make a worktree per task.
- Your EditFile and WriteFile are rooted in this checkout. Tool policy refuses them,
  and shell writes, under src/, scripts/, packages/, tools/, .agent/, .github/,
  .motoko/config/, Makefile, SYSTEM.md and AGENTS.md. A path inside the worktree is
  not covered by that policy. It is still not yours to edit: a defect is a new
  delegation.
- Do not run `git stash`, `git apply`, `git restore` or `git checkout <path>`
  anywhere.

DELEGATE CALLS
- On your first Delegate pass dagr_plan: ".dagr/run-034-plan-001.json". Never name
  another dagr_plan in this session.
- On every Delegate pass dagr_task: "<task id>", kind: "claude",
  model: "claude-opus-5-5", cwd: "/workspaces/motoko_agent-034-w0", and task_kind
  from the graph's kind (impl, test or docs; for the gate W0.7 use test).
- Every delegate runs on Claude Opus 5.5. The graph names no owner, so this prompt is
  where the model is set. Pass that model id exactly, on every call. Never leave model
  out and never pass another one.
- Read the first result. If it says the plan was not recorded or could not be read,
  or that dagr_task was not linked, stop and tell me.
- retry_of only when you re-issue a task whose delegate failed or under-delivered.
- Do not start agents with the herdr CLI. Do not write, edit or move any file under
  .dagr/, and do not edit the plan or its graph. The extension records each attempt
  from what Delegate and DelegateCheck observe. To settle a task here means: you
  verified it as described below and told me.
- Before each Delegate, say in the same response which task it is and why it is next.

THE BRIEF YOU WRITE FOR EACH TASK
It must stand alone: the delegate has none of this conversation. Include, in this
order:
1. The task id and title, and the plan's section for that task quoted in full, Gate
   line included. Also quote, in full:
   - for W0.2 and W0.3: the plan's choice C3 (the JSON example, the two sentences,
     the kind table, the one-home paragraph), and the ADR's D2 table;
   - for W0.2: the "Overlap" paragraph of "What is true at e69aaad7", and what step 0
     found;
   - for W0.4: the proposed description, which is the wording to use;
   - for W0.1 and W0.7: standing rules 4 and 5;
   - for W0.6: the path .agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md,
     to be read before the run.
2. "You are in the worktree /workspaces/motoko_agent-034-w0 on branch
   arniwesth/034-w0-effect-disclosure. Work only there. /workspaces/motoko_agent is
   the shared checkout: do not edit, commit or switch branches in it. A worktree has
   no .env and no ailang/ directory (AGENTS.md)."
3. "Your task file and your answer file are in
   /workspaces/motoko_agent/.motoko/herdr-delegates/, not in the worktree. Write the
   answer there."
4. "The plan is grounded at e69aaad7. Where a line number has moved, find the code by
   reading it, and list the drift in your answer. Do not stop to ask."
5. "Exactly one commit for this task, on this branch. Its subject has a conventional
   type and scope, says what changed, and ends with the task id, for example
   `feat(core): tool faults carry a fault object with effects (034 W0.2)`. Do not
   push and do not open a pull request." Leave the last sentence out of W0.7's brief.
6. "Run the task's gate before you commit: `env -u AILANG_FS_SANDBOX make <targets>`.
   Run `make dst` and `make eval_matrix` by themselves, never beside each other or
   another target: eval_matrix is under the 12 GiB memory rule. A gate that could not
   run is not a gate that passed: say which did not run and why."
7. For W0.1: "Record the baseline at the commit the branch was cut from, before any
   source change: `make dst`, then `make eval_matrix`. Expect about 35 and 14 minutes.
   Commit the evidence directory the task names."
8. For W0.5 and W0.6: "Run as a non-root user, and put the output of `id -u` in your
   answer. Under root, rows e and f are not evaluated and the task is not done."
9. "If a gate is red for a reason this task does not name, or the task cannot be done
   as written, stop and report. Do not widen the task, and do not change another
   task's files to get a green gate."
10. "Your answer: the commit hash; `git show --stat` of it; each gate command with its
    exit code and its last lines; what you did not do; every line reference that had
    moved."

W0.7'S BRIEF also says: this is the gate. It changes nothing except what the gate and
the records require. Compare its baseline with W0.1's directory row by row. A changed
row outside the plan's expected list is a finding: record it in the baseline directory
with its cause, do not fix it, do not push, and report it. If the comparison has no
unexplained row and every target is green, or fails exactly as at the base, follow the
ship steps.

SHIP STEPS, in W0.7's brief only, after the gate is green
- Open the pull request as the bot, through tools/pr, as a draft, from the worktree:
  `make pr_draft`; fill Summary, Predicted outcome and Test evidence in
  .agent/github/staging/<branch>/body.md; push with an explicit refspec,
  `git push origin HEAD:refs/heads/<branch>` (.git/config cannot record tracking
  here); then
  `GH_TOKEN="$MOTOKO_BOT_GH_TOKEN" gh pr create --draft --repo arniwesth/motoko_agent
  --base main --head <branch> --title "<title>" --body-file <the staged body without
  its frontmatter>`; then `bun tools/pr/pr.ts create --base main --remote origin`,
  which adopts the open pull request and writes its record.
- Then the records, in one commit: the ADR's status line gains "Phase 0 implemented in
  #<n>", and the plan's status line says W0 is in review and W0b and W1 are next. Then
  commit the PR record as `chore(github): PR #<n> record — <what>`, and push again.
- The body says this moves the model-facing wire for every faulted tool result (ADR
  D5's cost). It says where the before and after baselines are, and lists every
  changed row with its cause.
- Test evidence lists what was run and what was not, with exit codes, and the `id -u`
  of the W0.5 and W0.6 runs.
- The answer names the pull request's number and the pushed head.
- Do not merge it, and do not wait for CI.

VERIFYING A DELEGATE, before the next delegation
1. Wait by ending your turn, not by polling. After a Delegate call, reply with one
   line, the task id, the handle and what it is running, and no tool call. The loop
   then parks on the delegate and wakes you when its answer file lands or its pane is
   gone. On the wake, call DelegateCheck once to collect the answer.
   - Do not call DelegateCheck before the wake. Each call costs a step, and one that
     finds a Claude delegate idle with no answer file closes its pane, which kills any
     job the delegate left running in the background.
   - If I write to you while you are parked, answer and end your turn again. The wait
     stays open.
   - A delegate blocked on a prompt does not wake you. I see it in herdr and answer it.
   - A delegate that sits idle for an hour with no answer file wakes you as `lost`, and so
     does one that never starts. Call DelegateCheck once, then follow WHEN SOMETHING IS
     WRONG.
   - If a DelegateCheck reports `herdr_cli_rejected` with `timeout after …ms`, the
     shell's limit cut off the check's wait. The delegate is still working: end your
     turn.
2. From git: `git -C <worktree> log --oneline origin/main..HEAD` shows one new commit
   for the task; `git -C <worktree> status --short` is empty; `git status --short`
   here matches the list from step 0.
3. `git -C <worktree> show --stat HEAD`: the files are the ones the task names. A file
   outside the task is a finding. W0's surface is in the plan's "Phase 0" heading.
4. Re-run the task's light gate yourself in the worktree: `make check_core`, and
   `make test_coverage` or `make world_state` where the task names them. Your shell
   tool has a wall-clock limit, 30 s unless I raised it, and it reports the limit as
   `timeout after …ms` with no output. That is the limit, not a red gate. So run every
   gate in the background and poll its log:
     cd <worktree> && nohup env -u AILANG_FS_SANDBOX sh -c 'make <targets>; echo GATE_EXIT=$?' > /workspaces/motoko_agent/tmp/034-orchestrator/<task>-<n>.log 2>&1 &
     tail -n 5 /workspaces/motoko_agent/tmp/034-orchestrator/<task>-<n>.log
   It has finished when the log ends with GATE_EXIT=. One gate at a time.
   Do not re-run `make dst` or `make eval_matrix`: read the delegate's recorded output
   and say that you did not re-run them.
5. For W0.6: mutants.tsv exists, names the commit it ran at, and every row is a kill
   or a survivor with a new test or a sentence. Count the rows against the plan's
   table, m01-m35.
6. For W0.7: `git ls-remote --heads origin <branch>` gives the worktree's HEAD, and the
   record .agent/github/prs/origin-<n>/body.md is in the worktree. You have no GitHub
   token, so you cannot query the pull request itself. Say so.
7. Then tell me in two or three lines: the task, the commit, the gates you re-ran with
   their exit codes, and anything you did not verify. Then the next task.
If DelegateCheck settles with no answer file, the commit and your own re-run are the
evidence. Say that the answer was missing.

WHEN SOMETHING IS WRONG
- A defect in a delegate's work: re-issue the same task with retry_of. At most twice
  per task. After the second failure stop and tell me.
- A red gate or an unexplained row at W0.7: re-issue the task whose files are at
  fault, with retry_of its handle, then W0.7 again with retry_of. If no task covers
  it, that is a gap in the plan: stop and tell me.
- A task that cannot be done as the plan words it, or that needs a change to a
  criterion, a dependency or another task: stop and tell me. You do not change what a
  task is judged by.
- Anything I must decide: say what it is, the options, and which you recommend.

BUDGET AND HANDOFF
- At about step 900 start no new task. Collect what is in flight, then write
  tmp/034-orchestrator/HANDOFF-<date>.md: the worktree's branch and last commit, the
  tasks verified, the delegate handles in flight, the next ready task ids, and that
  the next session is this run's orchestrator and delegates.
- A response with no tool call ends the turn. End it to wait on a delegate (VERIFYING
  step 1), and otherwise only when W0's pull request is open and reported, or a rule
  above says stop, or the budget rule applies.
```

## Notes for the operator

- **What the run file grants.** `run.orchestrator` is `{ pane: <this pane>, mode: "delegate",
  max_in_flight: 1 }` with ten guarded paths, as in 005. The extension then adds a standing role
  note to the system prompt and refuses `EditFile`, `WriteFile` and the shell's write forms under
  those paths.
- **The guard does not reach a worktree.** A path outside the shared checkout matches no guarded
  prefix, so nothing but the prompt stops the orchestrator from editing the delegate's worktree.
  `git status` in the worktree after each task is the check.
- **One delegation at a time.** All of W0 is one worktree and one branch, so its tasks cannot
  overlap anyway.
- **Pushing and the pull request are delegated.** A Motoko session has no GitHub token: the TUI
  passes neither `GH_TOKEN` nor `MOTOKO_BOT_GH_TOKEN` to the runtime. A delegate's pane has both.
  To open the pull request yourself, delete *SHIP STEPS* and the sentence in W0.7's brief that
  points to it; the branch then stays local.
- **A draft pull request,** for you to review and mark ready.
- **The model.** The committed graph gives no task an owner (the plan's header leaves it to the
  operator), so the dagr pane shows every task as `unassigned`. The prompt sets
  `claude-opus-5-5` on every `Delegate`. If the orchestrator left `model` out, the delegate would
  start on the `model` in `~/.claude/settings.json`, which is `opus`. To use another model, change
  the one id in *DELEGATE CALLS*.
- **The two long runs.** W0.1 and W0.7 each run `make dst` (2,085 s at `-j8` when last measured)
  and then `make eval_matrix` (821 s). Do not start other heavy targets on the machine while they
  run. The orchestrator parks while a delegate works and is woken when the answer lands, so the
  wait costs no steps. The first session, on 2026-10-18, was told to poll instead: one
  `DelegateCheck` step every ~35 s, each resending ~107k tokens of context, until the operator
  interrupted it.
- **The step budget.** "Step 900" assumes the `default` profile's 1200 steps. Change the number if
  you start Motoko on another profile.
- **The shell tool's limit.** A foreground command in a Motoko session is cut off after 30
  seconds. The prompt has the orchestrator run gates in the background. Setting
  `MOTOKO_PROCESS_TIMEOUT=600s` in the environment Motoko starts from raises the limit.
- **Non-root.** W0.5 and W0.6 are accepted only on a non-root run. This container's user is
  `motoko`, uid 1001. Step 0 stops the session if the pane runs as root.
- **Old run files.** On 2026-10-17, `.dagr/` holds seven run files that turn orchestrator mode on,
  for panes `w4:pK`, `w8:p1`, `w1:p18` and `w3:p1`. If Motoko's pane is one of those, Motoko
  becomes the orchestrator of that run as well. The script warns. Use another pane, or move the
  old file away.
- **Overlap.** When the plan was written, open #234 (stacked on #209) changed
  `validate_path_common` and `atomic_write` in `tool_runtime.ail`. W0.2 touches the lines next to
  them. Step 0 re-checks.
- **The delegate's mailbox.** The extension tells a delegate to read
  `./.motoko/herdr-delegates/task-….md`, a path that exists in the shared checkout and not in its
  worktree. 005's second delegate found it there unprompted. If one cannot find its task, tell it
  in its pane: `/workspaces/motoko_agent/.motoko/herdr-delegates/`.
- **Look at the first delegate's pane.** A delegate sometimes asks whether to carry out a pasted
  task before it starts. Answer it once and the rest follow the same path. Its status line shows
  the model, which should be Opus 5.5.
- **Codex.** `HERDR_ALLOWED_KINDS` is `claude,motoko`, so Motoko cannot delegate to Codex.

### Later sessions

Each starts from `main` after the pull request before it has merged:

1. Pull the shared checkout.
2. Start with the script again, naming the tasks that have merged. They are seeded as done, so
   the tasks behind them are ready.
3. Use the prompt above with *THIS SESSION*, the worktree lines, the brief's quoted sections and
   the ship steps changed for that workstream.

| Session | After | `MERGED` | Scope, and where it stops |
|---|---|---|---|
| W0b, part 1 | W0 merged | W0.1-W0.7 | W0b.1 only, the probe. Then stop and report: W0b.2 is the operator's question. |
| W0b, part 2 | the operator answers W0b.2 | W0.1-W0.7, W0b.1, W0b.2 | W0b.3 and W0b.4, as answered. Withdrawn: they are canceled and there is no session. |
| W1, part 1 | W0 merged | W0.1-W0.7 | W1.1 only. Then stop and report its three lists and the `manifest-A` arrangement, which needs 013 ADR-004's owner. |
| W1, part 2 | W1.1 reported and accepted | W0.1-W0.7, W1.1 | W1.2-W1.8, continuing part 1's worktree and branch, one pull request. Large: budget a handoff. W1.1 is named so the script seeds it done; the script re-seeds from the committed graph, so a task left out comes back queued. |
| W2 and W3 | W1 merged | W0.1-W0.7, W1.1-W1.8 | Two pull requests, two worktrees. With one delegation in flight they run one after the other. |

W0b and W1 do not depend on each other. One session could hold both, but with `max_in_flight: 1`
it would still run one task at a time. Separate sessions keep each pull request's evidence apart.

This file carries a prompt for W0 only. W0's own findings may change what the later sessions
need.

## What was checked, and what was not

Checked on 2026-10-17, in a scratch copy of the repository layout with a made-up pane id
(`w9:p99`):

- **The start script does what it says.**
  - It writes `.dagr/run-034-plan-001.json`, and `dagr check --strict` prints `[]`.
  - It sets the pane, `mode: "delegate"` and `max_in_flight` 1.
  - With `MERGED` naming W0's seven tasks, they become `done` and the file still passes.
  - It refuses an unknown `MERGED` id, a missing pane id, and a start from outside the root.
  - It warns that no permission mode is set.
- **The run file turns the mode on for its own pane and for no other.** `mode_from_doc_str`
  (`packages/motoko-ext-herdr/orchestrator.ail`), run on the written file, gives
  `on:.dagr/run-034-plan-001.json:w9:p99:1:src/,scripts/,packages/,tools/,.agent/,.github/,.motoko/config/,Makefile,SYSTEM.md,AGENTS.md`
  for `w9:p99`, and `off` for `w9:p98`.
- **The run file seeds.** `seed_from_plan_str` (`packages/motoko-ext-herdr/dagr.ail`) gives 26
  tasks, all `queued` with no attempts. With `MERGED` set to W0's tasks, it gives those seven
  `done` with one attempt each, and nineteen `queued`.
- **The extension is unchanged** since `a7c77571` (2026-10-08). 005's prompt checked the tool
  policy and a delegate's environment against that same version: the guarded paths, the
  background gate command, the tokens in a delegate's pane, and that a Motoko session cannot push.

Not checked:

- **No Motoko session has been started with this prompt.** Delegation, verification, the ship
  steps and the stop rules are exercised only by 005's session, which shipped W1 as #256.
- **005's ship steps** were written for a delegate's environment. Opening #273 on 2026-10-17
  confirmed only that `gh pr create` works with the bot token, and that pushing prints
  `.git/config` errors but succeeds. Those runs were from this session, not from a delegate.
- **The permission mode in a delegate.** `permissions.defaultMode` is `auto` since 2026-10-18,
  and the start script reads it back. No `claude` was started to confirm that it reports `auto`.
  In auto mode a delegate may show a one-time opt-in, and may stop at an action the classifier
  holds back, such as the push or `gh pr create` in the ship steps. *VERIFYING A DELEGATE*, step
  1, covers a delegate that stops: the orchestrator tells you the pane and you answer it.
