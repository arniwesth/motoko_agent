# PLAN-001 W5: the findings

You write `FINDINGS-001` for project 043's trial. The trial compares two ways of finding defects
in Motoko's code: arm A uses executed checks, arm B uses Lean models with differential tests.

Read these first, all of each:

- **The plan.** `.agent/projects/043_lean_harness_properties/PLAN-001-trial-lean-against-differential-checks.md`
  in this worktree, with its amendments A1-A3 at the end. §8-§10 and §12 bear on your work most.
- **The adjudication.** `trial/adjudication/README.md`, `AUDIT.md` and `CALLS.md`.
- **The record.** `trial/sequence.log`, the trial's append-only record. W4's lines start at
  2026-11-05T17:25:36Z.

## The task

Your work is the plan's W5 row (§12): "`FINDINGS-001`: results against predictions, the §10
outcome, unknown real defects re-run on `origin/main`, and the consequence applied".

1. **The §10 outcome.** Compute it from `trial/adjudication/summary.tsv` and `table.tsv`, and
   from the operator's same-defect and reachability calls at the end of `CALLS.md`.
   - Check both void conditions:
     - **Voided sessions.** W4 voided none.
     - **Unfinished sessions.** §10 voids the trial if "more than two sessions of either arm end
       unfinished on more than half of their target's primary properties". Judge this from each
       session's `SUMMARY.md`, and its transcript where that is unclear. State the rule you use
       for "unfinished".
   - Show each clause of §10 with its numbers.
   - The counting decisions W4 made are logged. A seed counts once per replicate, a detection
     counts whatever property its report names, and only primary-property real defects count
     towards U. Use them, or log why not.
2. **The outcomes in 042's dimensions (§9),** per arm, per replicate, and as the mean of the
   two. Include §9's secondary measures:
   - the route of each detection;
   - the model changes forced by arm B's differential test, counted from each arm B
     `SUMMARY.md`;
   - the axiom reports;
   - exploratory findings;
   - agreement between replicates.

   Investigation cost is tokens (input + output, as Claude Code reports them, the same measure
   for both arms), wall-clock, and targets unfinished at the cap. Report memwatch's kills per
   arm (`sequence.log`). Development cost is the planter's and the adjudicator's tokens and time.
   Human involvement is the operator's time on the §8 calls; `CALLS.md` gives what the record
   holds.
3. **Results against `trial/predictions.tsv`,** p01 to p18, each a hit or a miss. The S2 rows
   were written for n2 = 5 and scale to n2 = 4 (the file's header says so). A miss is recorded as
   a miss.
4. **The unknown real defects, D2-D12 in `CALLS.md`, re-run on `origin/main`.**
   - Build a tree from `origin/main` the way `build_tree.sh` builds one from `43530c0a`. Run each
     defect's reproductions on it, under `adjudicate.sh`'s conventions: the path rewrite, the
     clean environment, the 120 s and 6 GiB limits.
   - Record which still reproduce. A reproduction that errors because the code moved is
     recorded as that, not as fixed.
   - Log the `origin/main` commit you use.
5. **The consequence §10 attaches to the outcome, applied.**
   - **D:** the RESEARCH note's verdict gets a dated marker. This repo revisits a research note
     with a dated sibling note and a short marker at the top of the original, and never edits
     the original below the marker. FINDINGS-001 can be that sibling.
   - **L:** §10 item 7 is scoped as the plan says.
   - **X:** nothing changes automatically, and the operator decides with FINDINGS in hand.
6. **§10's "in every outcome".** Re-run on B0 every arm A harness that detected something. Those
   that pass there are proposed as standing tests in a follow-up. Propose them in FINDINGS; do
   not add them to the repository.

Write `FINDINGS-001` as `.agent/projects/043_lean_harness_properties/FINDINGS-001-<slug>.md`.
Follow §10: the counts are small, there are two replicates, and the decision rule is a
commitment made in advance, not a test of significance. Say so.

## Where things are

In this worktree, under `.agent/projects/043_lean_harness_properties/`:

- **`trial/adjudication/`:** W4's record.
  - `table.tsv`: one row per report, its outcome on T, B0 and each T−s, and its class.
  - `summary.tsv`: per session, replicate and arm.
  - `runs.tsv`: every run.
  - `CALLS.md`: the groups D1-D12, S1-S7, X1-X10 and the operator's decisions.
  - `AUDIT.md`.
- **`trial/scripts/`:**
  - `adjudicate.sh`: §8's procedure, with the run conventions in its header.
  - `build_tree.sh` and `common.sh`: `hash_dir`, and the trial's paths.
- **`trial/runs/`:** the answer key (`planter/manifest.tsv`) and each session's committed
  outputs, `reports.tsv` and `SUMMARY.md` among them.
- **`trial/predictions.tsv`, `RESEARCH-lean-harness-properties.md`.**

On this machine, under `/home/motoko/trial-043/`:

- `s/<session>/{tree,out}`: each arm session as it stopped.
- `collect/<session>/meta`: its `session_id`, and its start and stop times.
- `adjudication/`: W4's trees (`trees/B0`, `trees/T`, `trees/T-sNN`), work directories and run
  logs (`results/`).
- The transcripts:
  - **Arm sessions:** `/home/motoko/.claude/projects/-home-motoko-trial-043-s-<session>-tree/<session_id>.jsonl`.
  - **The planter:** `/home/motoko/.claude/projects/-workspaces-motoko-agent-043-planter/`, under
    the `session_id` in `collect/t043-planter/meta`.
  - **The adjudicator:** `/home/motoko/.claude/projects/-workspaces-motoko-agent-042-lean/e8baeaf2-ac74-4f18-b226-3eafdbb084e5.jsonl`.
    Read it only for its token counts and times, not its reasoning.

## Counting tokens

A transcript can record the same assistant message more than once: W4 found that `tool_use`
blocks repeat. Count each message once, by its id, before summing usage.

Decide, and log, which usage fields make "input + output as Claude Code reports them". The cache
fields are the question, and the measure must be the same for every session.

## Rules

- **Leave the evidence as it is.** Change nothing under `s/*/out`, `collect/`, `unsealed/`,
  `sealed/` or `adjudication/`. Their hashes are logged. Work on copies, under
  `/home/motoko/trial-043/findings/`.
- **W4 stands.** W4's rulings and the operator's calls stand. If you find an error in W4's table,
  audit or counts, log it in `sequence.log` and tell the operator; do not change W4's files.
- **Base your findings on the record, not on the operator's views.** Read the transcripts listed
  above, and no other Claude Code transcript, the operator's session included.
- **Log as you go.** `trial/sequence.log` is append-only. Add lines with a UTC timestamp
  (`date -u +%Y-%m-%dT%H:%M:%SZ`), and never edit an existing line; correct one with a new line.
  Log when you start and when you finish, and the sha256 of every script you run. Changing an
  existing script is a deviation, logged when you make it.
- **Decide what the plan leaves open.** Write each decision and its reason in `sequence.log`,
  then go on. Ask the operator only for what the plan gives the operator: the decision after an X
  outcome, or whether to re-run after a void. The operator answers in this session.
- **Commit the small record, not the bulk.**
  - Commit in this worktree, on branch `arniwesth/042-lean-harness-properties`.
  - Before each push, with a clean tree, run
    `git fetch -q origin && git rebase -q origin/arniwesth/042-lean-harness-properties`.
  - Never force-push.
  - End each commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - You are the only session pushing to this branch until you finish.
  - Keep bulk data on disk with its hashes committed. Ask the operator before publishing any.
- **Stay off the multiplexer.** Do not use `herdr`, and do not restart the container.

## The machine

- **Memory is the limit.** 8 CPUs and 27 GB of RAM, and the swap is zram. Eight memory-heavy
  sessions froze the container on 2026-11-04. Guard your own runs: limit how many run at once,
  and how much memory each may use. `adjudicate.sh`'s guard is one way.
- **`kill -0` cannot tell you a process has ended.** PID 1 is `sleep infinity`, so a detached
  process that exits stays a zombie. Check `/proc/<pid>/status` for `State: Z`.
- **The tools are the arms' tools:** AILANG v0.54.14, Lean 4.28.0 under `~/.elan`, and bun.

## When you are done

Commit and push `FINDINGS-001` and whatever the consequence changes. Then end with one line:
`W5 DONE <commit>`. If you cannot finish, end with `W5 STOPPED: <reason>`.
