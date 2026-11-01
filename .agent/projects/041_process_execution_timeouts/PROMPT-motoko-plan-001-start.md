# Prompt: start Motoko on 041 PLAN-001, by delegation

For a **fresh** Motoko session that orchestrates
[`PLAN-001-implement-adr-002.md`](PLAN-001-implement-adr-002.md) through its graph,
[`PLAN-001.dagr.json`](PLAN-001.dagr.json). Motoko delegates each task to a Claude delegate on
Claude Opus 5.5 through the herdr extension, checks the result, and moves on to the next.

**This prompt covers the first session only: W1, W2, W3 and W4, one worktree and one draft pull
request each.** They are the graph's tasks with no unmet dependency. W5 needs W1 and W4 merged, so
it and everything after it are later sessions (*Later sessions*, below).

Written 2026-11-01 against the plan at `04ad62ed`, the ADR at `e3293ede`. This file adapts 034's
[`PROMPT-motoko-plan-001-start.md`](../034_ambiguous_tool_outcomes/PROMPT-motoko-plan-001-start.md),
including that session's lesson: wait by ending the turn, not by polling.

## Before you start

Four steps.

1. **Merge #289, then #290, and pull the shared checkout.** The start script reads the graph from
   the shared checkout, and worktrees are cut from `origin/main`. The script refuses to start
   without the graph.
2. **Give delegates a permission mode.** The extension starts a Claude delegate with no flags, so
   it comes up in whatever `permissions.defaultMode` in `~/.claude/settings.json` says. **That
   setting was not there on 2026-11-01.** 034 set it to `auto`, but the file is outside the
   repository and does not survive a container rebuild. Without it, a delegate stops at its first
   shell command. The start script warns if it is missing.
3. **In the herdr pane Motoko is to run in, start it with the script, from the repository root,
   in place of `make motoko`:**

   ```sh
   cd /workspaces/motoko_agent
   bash .agent/projects/041_process_execution_timeouts/start-orchestrator.sh
   ```

   Arguments go on to `make motoko`, for example `PROFILE=dogfood`.
4. **Paste the prompt below.** Read *Notes for the operator* first: pasting the prompt accepts
   them.

**Why starting Motoko alone is not enough.** The herdr extension puts a session in orchestrator
mode only if a file under `.dagr/` names that session's own pane with `mode: "delegate"` when
Motoko starts. The committed graph names no pane (008 ADR-001 D5). So
[`start-orchestrator.sh`](start-orchestrator.sh) writes `.dagr/run-041-plan-001.json`, which is the
committed graph plus this pane's id, checks it with `dagr check --strict`, and then runs
`make motoko`. The file is local and gitignored.

## The prompt

Paste everything inside the fence.

```
Implement the first four work items of 041 PLAN-001 by delegation: you orchestrate,
Claude delegates implement.

Plan: .agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md
It implements ADR-002-per-call-process-timeouts.md in the same directory, accepted
under R9, ninth revision. The ADR's rulings R1-R11, its decisions, and the plan's
choices C1-C5 are settled. Do not reopen them.
Plan graph: .dagr/run-041-plan-001.json. You are its run.orchestrator (mode "delegate",
one delegation in flight). It is a local copy of the committed PLAN-001.dagr.json
beside the plan, plus this pane's id.

THIS SESSION
W1, then W2, W3 and W4, in that order. One worktree, one branch and one draft pull
request per task, each cut from origin/main. Nothing from W5 onward: W5 needs W1 and
W4 merged, and merging is mine. The tasks owned by "upstream" are waits: never delegate
them. When W4's pull request is open, report and stop.

W1 decides whether R6 holds. If W1's admission test fails on its merits, stop the
session and give me the evidence: R6 returns to me, and W2-W4 do not start in this
session.

STEP 0, before any delegation
1. Read AGENTS.md. In the plan, read the header, "TL;DR", "Standing rules", "Gates",
   "What is true at e3293ede", "Experiments", "Choices this plan makes" and W1-W4.
   In the ADR, read R6, D2, D5, D6 and D7's types.
2. `git fetch origin`, then `git log --oneline -3 origin/main`. If the plan or its graph
   is not in this checkout, stop and tell me.
3. `dagr check .dagr/run-041-plan-001.json --strict --json` must print [].
4. `git status --short` here, and keep the output. This checkout already has
   unrelated uncommitted files, and you will compare against this list after every
   task.
5. `mkdir -p tmp/041-orchestrator`. Your logs and any handoff go there. tmp/ is
   untracked.
6. `id -u`. If it prints 0, stop and tell me: W3 is accepted only as a non-root user,
   and delegates run as the same user as this pane.
7. For each task, run `tools/worktree/status.sh <paths>` with its paths, and keep the
   output:
   - W1: src/eval/journal/testdata/gen_fixtures.py src/eval/journal/admission_live_test.ail
   - W2: scripts/verify_native_process_tree.ail Makefile docs/configuration.md
   - W3: src/tui/src/runtime-process.cancel.test.ts scripts/verify_runtime_cancel_process_tree.sh
   - W4: src/core/process_limits.ail
   If an open pull request changes the same lines a task will change, put that in the
   task's brief. The plan lists #234, #209, #266 and #287. If it is the same work, stop
   and tell me.

WORKTREES: ONE PER TASK, NEVER THIS CHECKOUT
- This directory, /workspaces/motoko_agent, is the shared checkout. It stays on main.
  Nobody edits, commits or switches branches here: not you, not a delegate.
- Before each task, create its worktree yourself:
    W1: tools/worktree/new.sh 041-w1 arniwesth/041-w1-r6-admission
    W2: tools/worktree/new.sh 041-w2 arniwesth/041-w2-setsid-probe
    W3: tools/worktree/new.sh 041-w3 arniwesth/041-w3-cancel-witness
    W4: tools/worktree/new.sh 041-w4 arniwesth/041-w4-resolver
  Each appears as /workspaces/motoko_agent-041-w<n>. If the script refuses, stop and
  tell me. Do not pick another name.
- Your EditFile and WriteFile are rooted in this checkout. Tool policy refuses them,
  and shell writes, under src/, scripts/, packages/, tools/, .agent/, .github/,
  .motoko/config/, Makefile, SYSTEM.md and AGENTS.md. A path inside a worktree is
  not covered by that policy. It is still not yours to edit: a defect is a new
  delegation.
- Do not run `git stash`, `git apply`, `git restore` or `git checkout <path>`
  anywhere.

DELEGATE CALLS
- On your first Delegate pass dagr_plan: ".dagr/run-041-plan-001.json". Never name
  another dagr_plan in this session.
- On every Delegate pass dagr_task: "<task id>", kind: "claude",
  model: "claude-opus-5-5", cwd: "<that task's worktree>", and task_kind from the
  graph's kind (test or impl).
- Every delegate runs on Claude Opus 5.5. Each task's owner in the graph is
  "claude-opus-5-5", and plan.delegates names the kind and the model. Pass that model id
  exactly, on every call. Never leave model out and never pass another one.
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
1. The task id and title, the graph's criteria and note for it, and the plan's section
   for that task quoted in full, Gates line included. Also quote, in full:
   - the plan's "Standing rules" and "Gates";
   - for W1: experiment E1, and the paragraph of "Rulings R9-R11" on R11;
   - for W2: experiment E2, and D5 from the ADR;
   - for W3: D6 and R10 from the ADR;
   - for W4: choice C1, experiment E3, and the ADR's D7 types and resolver table.
   Also give what step 0 found for this task, and the path
   .agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md, to be
   read before the mutation run.
2. "You are in the worktree <path> on branch <branch>. Work only there.
   /workspaces/motoko_agent is the shared checkout: do not edit, commit or switch
   branches in it. A worktree has no .env and no ailang/ directory (AGENTS.md)."
3. "Your task file and your answer file are in
   /workspaces/motoko_agent/.motoko/herdr-delegates/, not in the worktree. Write the
   answer there."
4. "The plan is grounded at e3293ede, whose code equals main at a393314b. Re-read each
   anchor before building. Where a line number has moved, find the code by reading it,
   and list the drift in your pull request. If the ADR itself turns out to be wrong,
   stop and report the evidence. Do not build around it."
5. "Commit on this branch. Each subject has a conventional type and scope, says what
   changed, and ends with the task id, for example
   `test(journal): admit a post-change journal under R6 (041 W1)`. Commit messages end
   with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`."
6. "Mutation evidence goes in .agent/projects/041_process_execution_timeouts/evidence/<task>/:
   mutants.tsv and the commit it ran at. Only the named test failing counts as a kill."
7. "Run the task's gates before you ship: `env -u AILANG_FS_SANDBOX make <targets>`.
   Run `make dst` and `make eval_matrix` by themselves, never beside each other or
   another target: eval_matrix is under the 12 GiB memory rule. Green is a difference:
   compare FAILED names and matrix rows with this branch's base, and any row the task
   does not expect is a finding. A gate that could not run is not a gate that passed:
   say which did not run and why."
8. "Do not end your turn while a job you started in the background is still running.
   Keep checking it with tool calls until it finishes, then write the answer. A turn
   that ends before the answer file is written leaves your pane idle, and a check that
   finds a pane idle with no answer closes it, which kills the job."
9. For W1: "Do not edit MATRIX.expected.tsv, tools/eval_protected/ or scripts/eval/. If
   the matrix reports the new check as unlisted, record the row in the pull request. If
   the admission test fails on its merits, do not weaken it: stop and report."
10. For W2: "Acceptance reads a Linux log with no NOT EVALUATED line. Put that log's
    relevant lines in your answer."
11. For W3: "Run as a non-root user, and put the output of `id -u` in your answer. The
    test must be an expected failure that names sunholo-data/ailang#2034. Confirm the
    marker the runner offers before you use it. Do not wire the runtime twin into
    check_core."
12. For W4: "Do not import from src/core. Nothing calls this module yet, so no live or
    scripted behaviour may change."
13. "If a gate is red for a reason this task does not name, or the task cannot be done
    as written, stop and report. Do not widen the task, and do not change another
    task's files to get a green gate."
14. The ship steps below.
15. "Your answer: the pull request's number and pushed head; `git log --stat` of your
    commits; each gate command with its exit code and its last lines; what you did not
    do; every line reference that had moved."

SHIP STEPS, in each brief, after the gates are green
- Open the pull request as the bot, through tools/pr, as a draft, from the worktree:
  `make pr_draft`; fill Summary, Predicted outcome and Test evidence in
  .agent/github/staging/<branch>/body.md; push with an explicit refspec,
  `git push origin HEAD:refs/heads/<branch>` (.git/config cannot record tracking
  here); then
  `GH_TOKEN="$MOTOKO_BOT_GH_TOKEN" gh pr create --draft --repo arniwesth/motoko_agent
  --base main --head <branch> --title "<title>" --body-file <the staged body without
  its frontmatter>`; then `bun tools/pr/pr.ts create --base main --remote origin`,
  which adopts the open pull request and writes its record.
- Then commit the PR record as `chore(github): PR #<n> record — <what>`, and push again.
- The body names the task, the ADR criteria it satisfies, what the re-grounding found,
  and every changed matrix row with its cause. PR descriptions end with
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Test evidence lists what was run and what was not, with exit codes.
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
     does one that never starts. Call DelegateCheck once. If it reports the delegate
     still working or blocked, the wait is open again: end your turn. Otherwise follow
     WHEN SOMETHING IS WRONG.
   - If a DelegateCheck says the shell's time limit cut off one of its herdr calls
     (`timeout after …ms`), that says nothing about the delegate. When it also says the
     wait is open again, end your turn. When it is an error instead, no wait is open:
     follow WHEN SOMETHING IS WRONG.
2. From git: `git -C <worktree> log --oneline origin/main..HEAD` shows the task's
   commits; `git -C <worktree> status --short` is empty; `git status --short` here
   matches the list from step 0.
3. `git -C <worktree> diff --stat origin/main...HEAD`: the files are the ones the task
   names. A file outside the task is a finding.
4. Re-run the task's light gate yourself in the worktree: `make check_core`, and for W4
   `make test_coverage` too. Your shell tool has a wall-clock limit, 30 s unless I
   raised it, and it reports the limit as `timeout after …ms` with no output. That is
   the limit, not a red gate. So run every gate in the background and poll its log:
     cd <worktree> && nohup env -u AILANG_FS_SANDBOX sh -c 'make <targets>; echo GATE_EXIT=$?' > /workspaces/motoko_agent/tmp/041-orchestrator/<task>-<n>.log 2>&1 &
     tail -n 5 /workspaces/motoko_agent/tmp/041-orchestrator/<task>-<n>.log
   It has finished when the log ends with GATE_EXIT=. One gate at a time.
   Do not re-run `make dst` or `make eval_matrix`: read the delegate's recorded output
   and say that you did not re-run them.
5. Mutants: mutants.tsv exists, names the commit it ran at, and every mutant the plan
   names for this task is a kill or a survivor with a new test or a sentence. W3's c1
   and W2's d1 read as the plan describes them, not as ordinary kills.
6. `git ls-remote --heads origin <branch>` gives the worktree's HEAD, and the record
   .agent/github/prs/origin-<n>/body.md is in the worktree. You have no GitHub token,
   so you cannot query the pull request itself. Say so.
7. Then tell me in two or three lines: the task, the pull request, the head, the gates
   you re-ran with their exit codes, and anything you did not verify. Then the next
   task.
If DelegateCheck settles with no answer file, the commits and your own re-run are the
evidence. Say that the answer was missing.

WHEN SOMETHING IS WRONG
- A defect in a delegate's work: re-issue the same task with retry_of. At most twice
  per task. After the second failure stop and tell me.
- W1's admission test failing on its merits is not a defect: stop as THIS SESSION says.
  Do not re-issue it.
- A task that cannot be done as the plan words it, an ADR that turns out wrong, or a
  change needed to a criterion, a dependency or another task: stop and tell me. You do
  not change what a task is judged by.
- Anything I must decide: say what it is, the options, and which you recommend.

BUDGET AND HANDOFF
- At about step 900 start no new task. Collect what is in flight, then write
  tmp/041-orchestrator/HANDOFF-<date>.md: each worktree's branch, last commit and pull
  request, the tasks verified, the delegate handles in flight, the next ready task ids,
  and that the next session is this run's orchestrator and delegates.
- A response with no tool call ends the turn. End it to wait on a delegate (VERIFYING
  step 1), and otherwise only when W4's pull request is open and reported, or a rule
  above says stop, or the budget rule applies.
```

## Notes for the operator

- **What the run file grants.** `run.orchestrator` is `{ pane: <this pane>, mode: "delegate",
  max_in_flight: 1 }` with ten guarded paths, as in 005 and 034. The extension then adds a standing
  role note to the system prompt and refuses `EditFile`, `WriteFile` and the shell's write forms
  under those paths.
- **The guard does not reach a worktree.** A path outside the shared checkout matches no guarded
  prefix, so nothing but the prompt stops the orchestrator from editing a delegate's worktree.
  `git status` in the worktree after each task is the check.
- **One delegation at a time.** W1-W4 don't depend on each other and could overlap, but W1 and W2
  gates share one machine and the plan runs heavy targets one at a time. W1 goes first because a
  failure there stops the session.
- **Pushing and the pull requests are delegated.** A Motoko session has no GitHub token. A
  delegate's pane has both tokens. In auto mode a delegate may stop at the push or `gh pr create`;
  answer it in its pane.
- **Draft pull requests,** for you to review, mark ready and merge. W5 cannot start until you have
  merged W1 and W4.
- **The model.** Every delegated task's `owner` in the graph is `claude-opus-5-5`, and
  `plan.delegates` says so, as in 005's graph. `owner` does not select a model: it is the `model`
  argument that does, and the prompt sets it on every `Delegate`. If it were left out, the delegate
  would start on the `model` in `~/.claude/settings.json`. Look at the first delegate's status line,
  which should show Opus 5.5.
- **The long runs.** W1 runs `make eval_matrix`, about 14 minutes when 034 last measured it. The
  orchestrator parks while a delegate works, so the wait costs no steps. Do not start other heavy
  targets on the machine meanwhile.
- **The step budget.** "Step 900" assumes the `default` profile's 1200 steps. Change the number if
  you start Motoko on another profile.
- **The shell tool's limit.** A foreground command in a Motoko session is cut off after 30 seconds,
  the very limit this plan addresses. The prompt has the orchestrator run gates in the background.
  Setting `MOTOKO_PROCESS_TIMEOUT=600s` in the environment Motoko starts from raises it.
- **Old run files.** `.dagr/` holds run files that turn orchestrator mode on for other panes. If
  Motoko's pane is one of those, Motoko becomes the orchestrator of that run as well. The script
  warns. Use another pane, or move the old file away.
- **The delegate's mailbox.** The extension tells a delegate to read
  `./.motoko/herdr-delegates/task-….md`, a path that exists in the shared checkout and not in its
  worktree. If one cannot find its task, tell it in its pane:
  `/workspaces/motoko_agent/.motoko/herdr-delegates/`.
- **The plan's status line** still says "Proposed, not started". This session does not change it,
  because four parallel pull requests would conflict on that line. Change it when W1 merges.

### Later sessions

Each starts from `main` after the pull requests it needs have merged:

1. Pull the shared checkout.
2. Start with the script again, naming what has merged and which upstream issues a released tag
   carries: `MERGED="W1 W2 W3 W4" bash .agent/projects/041_process_execution_timeouts/start-orchestrator.sh`.
   They are seeded as done, so the tasks behind them are ready.
3. Use the prompt above with *THIS SESSION*, the worktree lines, the brief's quoted sections and
   its task-specific lines changed for those tasks.

| Session | Needs in `MERGED` | Scope, and where it stops |
|---|---|---|
| W5 | W1, W4 | W5. Predict matrix rows in the pull request before the run. Leaves `manifest-A` alone (R11). |
| W6 | W5 and its needs | W6. `make anchors` must not move. |
| W7 | W6 and its needs | W7. R11's four weeks start at its merge. |
| W8 | `U2035`, `U2036` | W8, once a released tag carries both. |
| W9 | W3, `U2034` | W9, once a released tag carries #2034. Under R10, a stall by 2026-11-14 comes to you first. |
| W10, W11 | W7, W8 and their needs | W10, then W11 after W10 merges. W11's route check failing stops the work, and W12 does not start. |
| W12 | W8, W9, W10, W11 and their needs | W12, the only item that turns a limit on. Then you direct `R11.regen`. |
| W13 | W12 and its needs | W13, the ADR's §6 sign-off. A failure on A14d reopens R6. |
| W14 | W12, `U1878` | W14, once a released tag carries #1878. |

The script re-seeds from the committed graph, so a task left out of `MERGED` comes back queued, and
`MERGED` has to list every finished task, not only the latest.

This file carries a prompt for W1-W4 only. Their findings may change what later sessions need.

## What was checked, and what was not

Checked on 2026-11-01, in a scratch copy of the repository layout with a made-up pane id
(`w9:p99`):

- **The start script does what it says.** It writes `.dagr/run-041-plan-001.json`, and
  `dagr check --strict` prints `[]`, with `MERGED="W1 W4"` as well. It sets the pane,
  `mode: "delegate"` and `max_in_flight` 1. It refuses an unknown `MERGED` id, a missing pane id, a
  missing graph and a start from outside the root, and it warns that no permission mode is set.
- **The run file turns the mode on for its own pane and for no other.** `mode_from_doc_str`
  (`packages/motoko-ext-herdr/orchestrator.ail`), run on the written file, gives
  `on:.dagr/run-041-plan-001.json:w9:p99:1:src/,scripts/,packages/,tools/,.agent/,.github/,.motoko/config/,Makefile,SYSTEM.md,AGENTS.md`
  for `w9:p99`, and `off` for `w9:p98`.
- **The run file seeds.** `seed_from_plan_str` (`packages/motoko-ext-herdr/dagr.ail`) gives 19 tasks,
  all `queued` with no attempts.
- **The graph assigns the model.** Fifteen tasks are owned by `claude-opus-5-5` and four by
  `upstream`.

Not checked:

- **No Motoko session has been started with this prompt.** It adapts 034's.
- **The start script's real launch.** Only `--no-start` was run, so `make motoko` did not start.
- **The permission mode in a delegate.** It is not set at this writing, and no `claude` was started.
