# Prompt: start Motoko on the finalize-policy migration, by delegation

For a **fresh** Motoko session that orchestrates
[`PLAN-finalize-policy-migration.md`](PLAN-finalize-policy-migration.md). Motoko delegates each
task to a Claude delegate through the herdr extension, verifies it, and goes on to the next.

This prompt covers the first session: work item W3-7, then workstream W1. W2 and the rest of W3
each start from `main` after the pull request before them has merged, so each is a later
session (*Later sessions*, below).

Written 2026-10-10 against `main` `38068013` and the herdr extension as it is there.

## Before you start

Three steps.

1. **Pull the shared checkout.** It needs `main` with #249, which brought the plan, its graph
   and this file, and with the pull request that added the start script. Worktrees are cut from
   `origin/main`.
2. **In the herdr pane Motoko is to run in, start it with the script, from the repository
   root, in place of `make motoko`:**

   ```sh
   cd /workspaces/motoko_agent
   bash .agent/projects/005_harness_policy_boundary/start-orchestrator.sh
   ```

   Arguments go on to `make motoko`, for example `PROFILE=dogfood`. The script refuses to
   start from any other directory (*What the first session showed*, below).
3. **Paste the prompt below.** Read *Overlap* in the notes first: pasting the prompt accepts it.

What the script does, and why starting Motoko alone is not enough: the herdr extension puts a
session in orchestrator mode only if, when Motoko starts, a file under `.dagr/` names that
session's own pane with `mode: "delegate"`. The committed graph names no pane (008 ADR-001 D5).
So [`start-orchestrator.sh`](start-orchestrator.sh) writes
`.dagr/run-005-finalize-policy-migration.json`, which is the committed graph plus this pane's id,
checks it with `dagr check --strict`, and then runs `make motoko`. The file is local and
gitignored.

The script also warns about two things that would trip the run:

- **No permission mode for delegates.** The extension starts a Claude delegate with no flags, so
  it comes up in whatever `permissions.defaultMode` in `~/.claude/settings.json` says. The first
  session ran with `auto`. The file is outside the repository and does not survive a container
  rebuild. With no mode set, a delegate stops at its first shell command.
- **Another run file that names the same pane.** Motoko would be the orchestrator of that run
  as well. `.dagr/` holds six older run files that turn the mode on, for panes `w1:p18`, `w3:p1`
  and `w8:p1`. Use another pane, or move the old file away.

## The prompt

Paste everything inside the fence.

```
Implement part of the finalize-policy migration by delegation: you orchestrate, Claude
delegates implement.

Plan: .agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.md
(status "Ready to implement"). It implements Amendments 1 and 2 of
ADR-001-harness-policy-boundary.md in the same directory, both accepted on 2026-10-10.
Its eight decisions are settled. Do not reopen them, and do not propose a replacement
for anything the plan removes.
Plan graph: .dagr/run-005-finalize-policy-migration.json. You are its run.orchestrator
(mode "delegate", one delegation in flight). It is a local copy of the committed graph
beside the plan, plus this pane's id.

THIS SESSION, IN THIS ORDER
1. W3-7, alone, as its own pull request. It depends on nothing, and it proves the whole
   path (launch, mailbox, commit, push, pull request) on a small task.
2. W1: WI-7, WI-8, WI-1, WI-2, WI-3, WI-4, WI-5, WI-9, WI-10. One pull request.
WI-6 is canceled: never delegate it. Nothing else from W2 or W3: they start from main
after W1 has merged, and merging is mine. When W1's pull request is open, report and stop.

STEP 0, before any delegation
1. Read AGENTS.md. Read the plan's decision table, "W1", "Why the order is what it is",
   "Blast radius (W1)", "The order, checked", and the W3-7 item under "W3".
2. `git fetch origin`, then `git log --oneline -3 origin/main`. If the plan file is not
   in this checkout, stop and tell me.
3. `dagr check .dagr/run-005-finalize-policy-migration.json --strict --json` must print [].
4. `git status --short` here, and keep the output. This checkout already has unrelated
   uncommitted files, and you will compare against this list after every task.
5. `mkdir -p tmp/005-orchestrator`. Your logs and any handoff go there. tmp/ is untracked.

WORKTREES: ONE PER PULL REQUEST, NEVER THIS CHECKOUT
- This directory, /workspaces/motoko_agent, is the shared checkout. It stays on main.
  Nobody edits, commits or switches branches here: not you, not a delegate.
- Before the first task of a pull request, create its worktree yourself:
    tools/worktree/new.sh 005-w3-7 arniwesth/005-w3-7-compose-ignores-hybrid-flag
    tools/worktree/new.sh 005-w1 arniwesth/005-w1-remove-dp7-verifier
  They appear as /workspaces/motoko_agent-005-w3-7 and /workspaces/motoko_agent-005-w1.
  If the script refuses, stop and tell me. Do not pick another name.
- Every W1 task runs in /workspaces/motoko_agent-005-w1, on that one branch, one commit
  per task, one task after another. Do not make a worktree per task.
- Your EditFile and WriteFile are rooted in this checkout. Tool policy refuses them, and
  shell writes, under src/, scripts/, packages/, tools/, .agent/, .github/,
  .motoko/config/, Makefile, SYSTEM.md and AGENTS.md. A path inside a worktree is not
  covered by that policy. It is still not yours to edit: a defect is a new delegation.
- Do not run `git stash`, `git apply`, `git restore` or `git checkout <path>` anywhere.

DELEGATE CALLS
- On your first Delegate pass dagr_plan: ".dagr/run-005-finalize-policy-migration.json".
  Never name another dagr_plan in this session.
- On every Delegate pass dagr_task: "<task id>", kind: "claude",
  model: "claude-opus-5-5", cwd: "<that pull request's worktree>", and task_kind from the
  graph's kind (impl, test or docs; for the gate WI-10 use test).
- Every delegate runs on Claude Opus 5.5. The graph says so: each task's owner is
  "claude-opus-5-5", and plan.delegates names the kind and the model. Pass that model id
  exactly, on every call. Never leave model out and never pass another one.
- Read the first result. If it says the plan was not recorded or could not be read, or
  that dagr_task was not linked, stop and tell me.
- retry_of only when you re-issue a task whose delegate failed or under-delivered.
- Do not start agents with the herdr CLI. Do not write, edit or move any file under
  .dagr/, and do not edit the plan or its graph. The extension records each attempt from
  what Delegate and DelegateCheck observe. To settle a task here means: you verified it
  as described below and told me.
- Before each Delegate, say in the same response which task it is and why it is next.

THE BRIEF YOU WRITE FOR EACH TASK
It must stand alone: the delegate has none of this conversation. Include, in this order:
1. The task id and title, and the plan's section for that item quoted in full, Gate line
   included. For WI-7 and WI-8 add the two "tests go first" items of "Why the order is
   what it is". For WI-9 add the item about `make anchors`.
2. "You are in the worktree <path> on branch <branch>. Work only there.
   /workspaces/motoko_agent is the shared checkout: do not edit, commit or switch
   branches in it. A worktree has no .env and no ailang/ directory (AGENTS.md)."
3. "Your task file and your answer file are in
   /workspaces/motoko_agent/.motoko/herdr-delegates/, not in the worktree. Write the
   answer there."
4. "The plan is grounded at 36a96b1e. Where a line number has moved, find the code by
   reading it, and list the drift in your answer. Do not stop to ask."
5. "Exactly one commit for this task, on this branch. Its subject has a conventional
   type and scope, says what changed, and ends with the task id, for example
   `refactor(core): classify_candidate loses its verification stages (005 WI-1)`.
   Do not push and do not open a pull request." Leave the last sentence out of the two
   briefs that ship (below).
6. "Run the task's gate before you commit: `env -u AILANG_FS_SANDBOX make <targets>`.
   Run corpus_pr by itself, never beside another target. A gate that could not run is
   not a gate that passed: say which did not run and why."
7. For WI-1, WI-2, WI-3 and WI-4: "`make anchors` and `make attribution_table` are red
   from WI-1 until WI-9, by design. Do not re-baseline the anchors."
8. "If a gate is red for a reason this task does not name, or the task cannot be done as
   written, stop and report. Do not widen the task, and do not change another task's
   files to get a green gate."
9. "Your answer: the commit hash; `git show --stat` of it; each gate command with its
   exit code and its last lines; what you did not do; every line reference that had
   moved."

WI-10'S BRIEF also says: this is the gate. It changes nothing except what the gate
itself requires. If anything is red, do not fix it and do not push: report what is red
and which work item's files it is in. If everything is green, follow the ship steps.

SHIP STEPS, in the brief of W3-7 and of WI-10 only, after the gate is green
- Open the pull request as the bot, through tools/pr, as a draft, from the worktree:
  `make pr_draft`; fill Summary, Predicted outcome and Test evidence in
  .agent/github/staging/<branch>/body.md; push with an explicit refspec,
  `git push origin HEAD:refs/heads/<branch>` (.git/config is read-only here, so -u
  cannot record tracking); then
  `GH_TOKEN="$MOTOKO_BOT_GH_TOKEN" gh pr create --draft --repo arniwesth/motoko_agent
  --base main --head <branch> --title "<title>" --body-file <the staged body without its
  frontmatter>`; then `bun tools/pr/pr.ts create --base main --remote origin`, which
  adopts the open pull request and writes its record; commit the record as
  `chore(github): PR #<n> record — <what>` and push again.
- Test evidence lists what was run and what was not, with exit codes.
- W1's body says that editing SYSTEM.md changes the prompt digest, so a session started
  before the merge and resumed after it under the same profile is refused unless the
  resume is forced (the plan, WI-5).
- The answer names the pull request's number and the pushed head.
- Do not merge it, and do not wait for CI.

VERIFYING A DELEGATE, before the next delegation
1. DelegateCheck until it settles. Each call costs a step and blocks for about 45 s.
   A delegate can show as blocked for a few seconds and then go on by itself. So if
   DelegateCheck reports it blocked or waiting for input, check three more times. Only
   if it is still blocked then, tell me the pane and what it is asking, and end your turn.
   I will answer it.
2. From git: `git -C <worktree> log --oneline origin/main..HEAD` shows one new commit
   for the task; `git -C <worktree> status --short` is empty; `git status --short` here
   matches the list from step 0.
3. `git -C <worktree> show --stat HEAD`: the files are the ones the task names. A file
   outside the task is a finding.
4. Re-run the task's gate yourself in the worktree. Your shell tool has a wall-clock
   limit, 30 s unless I raised it, and it reports the limit as `timeout after …ms` with
   no output. That is the limit, not a red gate. So run every gate in the background
   and poll its log:
     cd <worktree> && nohup env -u AILANG_FS_SANDBOX sh -c 'make <targets>; echo GATE_EXIT=$?' > /workspaces/motoko_agent/tmp/005-orchestrator/<task>-<n>.log 2>&1 &
     tail -n 5 /workspaces/motoko_agent/tmp/005-orchestrator/<task>-<n>.log
   It has finished when the log ends with GATE_EXIT=. One gate at a time.
   Do not re-run `make dst` or `make corpus_pr`: read the delegate's recorded output and
   say that you did not re-run them.
5. For a task that shipped: `git ls-remote --heads origin <branch>` gives the worktree's
   HEAD, and the record .agent/github/prs/origin-<n>/body.md is in the worktree. You
   have no GitHub token, so you cannot query the pull request itself. Say so.
6. Then tell me in two or three lines: the task, the commit, the gates you re-ran with
   their exit codes, and anything you did not verify. Then the next task.
If DelegateCheck settles with no answer file, the commit and your own re-run are the
evidence. Say that the answer was missing.

WHEN SOMETHING IS WRONG
- A defect in a delegate's work: re-issue the same task with retry_of. At most twice per
  task. After the second failure stop and tell me.
- A red gate at WI-10: re-issue the work item whose files are at fault, with retry_of
  its handle, then WI-10 again with retry_of. If no work item covers it, that is a gap
  in the plan: stop and tell me.
- A task that cannot be done as the plan words it, or that needs a change to a
  criterion, a dependency or another task: stop and tell me. You do not change what a
  task is judged by.
- Anything I must decide: say what it is, the options, and which you recommend.

BUDGET AND HANDOFF
- At about step 900 start no new task. Collect what is in flight, then write
  tmp/005-orchestrator/HANDOFF-<date>.md: each worktree's branch and last commit, the
  tasks verified, the delegate handles in flight, the next ready task ids, and that the
  next session is this run's orchestrator and delegates.
- End your turn only when W1's pull request is open and reported, or a rule above says
  stop, or the budget rule applies. A response with no tool call ends the turn.
```

## Notes for the operator

- **What the run file grants.** `run.orchestrator` is `{ pane: <this pane>, mode: "delegate",
  max_in_flight: 1 }` with ten guarded paths. The extension then adds a standing role note to
  the system prompt and refuses `EditFile`, `WriteFile` and the shell's write forms under those
  paths. The default guards four (`src/`, `scripts/`, `packages/`, `tools/`). The six added here
  are the other places this plan's tasks edit, because Motoko's file tools are rooted at the
  shared checkout and an edit there lands in `main`'s working tree. Remove the `guarded_paths`
  key in the script to get the default back.
- **The guard does not reach a worktree.** A path outside the shared checkout matches no
  guarded prefix, so nothing stops the orchestrator editing a delegate's worktree except the
  prompt. `git status` in the worktree after each task is the check.
- **One delegation at a time.** All of W1 is one worktree and one branch, so its tasks cannot
  overlap. With `max_in_flight: 1` W3-7 cannot run beside W1 either, which is why it goes first.
- **Pushing and pull requests are delegated.** A Motoko session has no GitHub token: the TUI
  passes neither `GH_TOKEN` nor `MOTOKO_BOT_GH_TOKEN` to the runtime. A delegate's pane has
  both. To open the pull requests yourself, delete *SHIP STEPS* and the two sentences that
  point to it; the branches then stay local.
- **Draft pull requests.** Both are opened as drafts, for you to review and mark ready.
- **Overlap, as of 2026-10-10.** `tools/worktree/status.sh` over the files W1 and W3-7 name
  finds open pull requests on one of them only, the `Makefile`: #234 and #209 (the hunk #250
  merged), and five older ones (#77, #56, #35, #21, #11). No open pull request changes
  `src/core/session.ail` or any other file the plan names. Uncommitted elsewhere: a `Makefile`
  change in `motoko_agent-spike-mut`, and three untracked files in the shared checkout
  (`scripts/dst/mem_canonical_bench.ail`, `scripts/dst/mem_growth_probe.ail`,
  `src/eval/journal/testdata/MATRIX.tsv`), none of which W1 touches.
- **The delegate's mailbox.** The extension tells a delegate to read
  `./.motoko/herdr-delegates/task-….md`, a path that exists in the shared checkout and not in
  its worktree. Claude delegates here start with this project's memory index, which says where
  the file is. If one cannot find its task, tell it in its pane:
  `/workspaces/motoko_agent/.motoko/herdr-delegates/`.
- **Look at the first delegate's pane.** A delegate sometimes asks whether to carry out a
  pasted task before it starts. Answer it once and the rest follow the same path. Its status
  line also shows the model, which should be Opus 5.5.
- **The model.** The graph gives every task the owner `claude-opus-5-5`, which the dagr pane
  shows beside each queued task, and the prompt has the orchestrator pass it as `model` on
  every `Delegate`. The extension turns that into `--model claude-opus-5-5` for the delegate
  and records the request on the attempt. Nothing reads the model from the graph by itself:
  if the orchestrator leaves `model` out, the delegate starts on the `model` in
  `~/.claude/settings.json`, which is `opus` and resolves to Opus 5.5 today.
- **The shell tool's limit.** A foreground command in a Motoko session is cut off after 30
  seconds. The prompt has the orchestrator run gates in the background, so nothing depends on
  the limit. `MOTOKO_PROCESS_TIMEOUT=600s` in the environment Motoko starts from raises it.
- **The step budget.** "Step 900" assumes the `default` profile's 1200 steps. Change the number
  if you start Motoko on another profile.
- **Codex.** `HERDR_ALLOWED_KINDS` is `claude,motoko`, so Motoko cannot delegate a review to
  Codex. Run one yourself if you want it.
- **Hybrid mode** is still on in the `default` profile until #252 merges. It is inert after a
  session's first typed tool call, which step 0 makes.

### Later sessions

W2 starts when W1's pull request has merged, and W3 when W2's has. For each:

1. Pull the shared checkout.
2. Start with the script again, naming the tasks that have merged. They are seeded as done, so
   the tasks behind them are ready. For W2:

   ```sh
   MERGED="W3-7 WI-7 WI-8 WI-1 WI-2 WI-3 WI-4 WI-5 WI-9 WI-10" \
     bash .agent/projects/005_harness_policy_boundary/start-orchestrator.sh
   ```
3. Use the same prompt with *THIS SESSION* and the worktree lines changed. W2-1 and W3-1 are
   probes: each ends with a report, and the plan says what is reported before the next item
   starts. Those reports come to you.

This file does not carry a prompt for W2 or W3. W2-1's findings may change W2 first.

## What the first session showed

The first session was started on 2026-10-10 with this prompt. Three things, in its first ten
minutes:

- **The dagr pane could not find its run file.** The script had been started from inside this
  directory. Motoko ran from the repository root, because the script changes directory for it,
  but herdr reports the shell's directory as the pane's. The extension gives the dagr view a
  relative path (`DAGR_RUN=./.dagr/run-<pane>-<session>.json`), and the view resolves it against
  the pane's directory. It waited for a file under `.agent/projects/005_harness_policy_boundary/`.
  The script now refuses to start from anywhere but the root. The relative path is the
  extension's, in `packages/motoko-ext-herdr`, and is not changed here.
- **The orchestrator parked on a block that had already cleared.** One `DelegateCheck`, eight
  seconds into a delegate's run, reported it blocked. The orchestrator told the operator and
  ended its turn, as the prompt said. The delegate was working by then and stayed so. The
  prompt now has it check three more times first.
- **The first delegate never got its task.** It came up, showed the notice that auto mode is
  on, settled idle after eleven seconds with no prompt in its transcript, and was recorded as
  `settled_unverified`. The orchestrator re-issued the task and the second delegate got it.
  Why the first prompt did not arrive was not determined.

Also seen: the second delegate looked for its task file in the worktree, did not find it, and
read it from the shared checkout two seconds later without being told.

## What was checked, and what was not

Checked on 2026-10-10:

- **The start script does what it says.** Run in a copy of the layout with a made-up pane id
  and a stand-in for `make motoko`: it writes the run file, `dagr check --strict` prints `[]`,
  and it runs `make motoko` in the shared checkout with its arguments passed on. It refuses
  without a pane id, from a worktree, and when `MERGED` names no task. It warns when another run
  file names the pane and when no permission mode is set. When `dagr check` rejects the file it
  starts nothing and leaves the earlier run file as it was.
- **The run file turns the mode on for its own pane and for no other.** `mode_from_doc_str` in
  `packages/motoko-ext-herdr/orchestrator.ail`, on the file the script wrote, gives `on` with
  `max_in_flight` 1 and the ten guarded paths for that pane, and `off` for another.
- **The policy does what the prompt says.** `tool_violation` on that mode refuses `EditFile` on
  `SYSTEM.md` and `Makefile`, `WriteFile` under `.agent/`, and `sed -i` under `src/`. It allows
  a file under `tmp/`, `tools/worktree/new.sh`, the background gate command as written, and
  `git -C <worktree> log`. It allows `EditFile` on a path in a worktree, which is the gap named
  above.
- **The run file seeds.** `seed_from_plan` in `packages/motoko-ext-herdr/dagr.ail` gives 24
  tasks under three projects, 23 `queued` and one `canceled`. With `MERGED` set to the ten
  tasks above it gives ten `done` and thirteen `queued`. Both results, and both run files, pass
  `dagr check --strict`.
- **A delegate starts in bypass mode, on Opus 5.5.** With `permissions.defaultMode` set, a
  `claude` started with no permission flag reports `permissionMode: bypassPermissions`. With
  `--model claude-opus-5-5` it reports that model, and with no `--model` it reports the same
  one. Claude Code 2.1.296.
- **The owner reaches the run.** `seed_from_plan` carries each task's `owner` into the run it
  seeds, and `dagr view` shows `claude-opus-5-5` beside each queued task where it showed
  `unassigned`.
- **A delegate's pane has the tokens.** A pane split through herdr from a process with no
  GitHub token had `GH_TOKEN`, `MOTOKO_BOT_GH_TOKEN` and the proxy variables, and no
  `AILANG_FS_SANDBOX`.
- **A Motoko session can read `origin` and cannot push.** `git ls-remote origin` works with
  the proxy variables and no credential, and the TUI forwards the proxy variables. In the
  2026-10-09 session `git push` hung until the tool's limit and `gh` was not logged in.
- **`make check_core` passes in a worktree** when run with `AILANG_FS_SANDBOX` pinned to the
  shared checkout, which is how an orchestrator would run it without `env -u`.

Not checked:

- The first session is described above. It had not finished a task when this was written, so
  verification, the ship steps and the stop rules are still unexercised. What it did show
  working: orchestrator mode came on, the plan was recorded and W3-7 linked, the dagr pane
  opened, the orchestrator made the worktree with `tools/worktree/new.sh`, and the delegate ran
  on `claude-opus-5-5`.
- The ship steps were not exercised. The permission mode was `auto` in the first session, not
  the `bypassPermissions` this file was checked with.
- A background command started from the shell tool was not shown to outlive the call that
  started it. Earlier Motoko sessions ran their sweeps that way.
- The changed rule for a blocked delegate was not tried in a session.
- The `MERGED` form was written by the script, seeded and validated. It was not used in a
  session.
