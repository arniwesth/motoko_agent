# PLAN-001 W4: the adjudication

You are the adjudicator of project 043's trial. The trial compares two ways of finding defects in
Motoko's code: arm A uses executed checks, arm B uses Lean models with differential tests. The
plan is `.agent/projects/043_lean_harness_properties/PLAN-001-trial-lean-against-differential-checks.md`
in this worktree; its amendments A1-A3 are at the end. Read all of it first.

Your work is the plan's W4 row (§12):

1. **The blinding audit** (§7, A2 item 3, A3 item 4). Rule on every breach, refused attempt and
   note that the audit found, and say what each ruling voids.
2. **§8's procedure as a script**, `trial/scripts/adjudicate.sh`. Run it, and commit its table.
3. **Drafts of the same-defect and reachability calls** (§8). The plan gives these calls to the
   operator: draft each one with its reason, then ask the operator in this session to decide.
   The operator answers here.

W5 (`FINDINGS-001`) is not part of this brief.

## Where things are

In this worktree, under `.agent/projects/043_lean_harness_properties/`:

- `trial/sequence.log`: the append-only record of the trial so far, including every deviation
  and the notes left for the adjudicator.
- `trial/predictions.tsv`: the predictions, hashed with the plan.
- `trial/scripts/`: the scripts that ran the trial. `common.sh` holds the paths and `hash_dir`.
  `build_tree.sh` builds a tree from the pinned commit, with or without a seeds patch. `audit.py`
  is the audit as it ran at W2.
- `trial/runs/`: the unsealed answer key (`planter/`) and one directory per arm session.
  `runs/README.md` explains the layout.
- `trial/dryrun/`: the dry run, which does not count.

On this machine, under `/home/motoko/trial-043/`:

- `s/<session>/tree` and `s/<session>/out`: each arm session's tree and output directory, as
  they were at the stop. The output hashes are in `sequence.log`.
- `sealed/tree.tar`: the seeded tree `T`, exactly as every arm session got it.
- `collect/<session>/`: the session's brief, its deny rules, and `meta`, which holds its
  `session_id`.
- `collect/audit/<session>.txt`: `audit.py`'s output at W2. Batch 1 also has `.v1.txt`, from
  the version before the logged change.
- `unsealed/planter/`: the planter's directory, decrypted at W3.
- The arm transcripts, at
  `/home/motoko/.claude/projects/-home-motoko-trial-043-s-<session>-tree/<session_id>.jsonl`.
  The planter's is in `/home/motoko/.claude/projects/-workspaces-motoko-agent-043-planter/`,
  under the `session_id` in `collect/t043-planter/meta`.

## Rules

- **Leave the evidence as it is.** Change nothing under `s/*/out`, `collect/`, `unsealed/` or
  `sealed/`, because their hashes are logged. A reproduction runs from a tree root and may refer
  to `../out/`, so run it on copies. Keep your trees and results under
  `/home/motoko/trial-043/adjudication/`.
- **Base your rulings on the record, not on the operator's views.** Read the arm transcripts and
  the planter's, but no other Claude Code transcript, and that includes the operator's session.
- **Log as you go.** `trial/sequence.log` is append-only: add lines with a UTC timestamp
  (`date -u +%Y-%m-%dT%H:%M:%SZ`), and never edit an existing line. Log when you start and when
  you finish, and the sha256 of `adjudicate.sh` as it ran. Changing an existing script is a
  deviation, logged when you make it.
- **Decide what the plan leaves open.** Write each decision and its reason in `sequence.log`,
  then go on. Ask the operator only for the calls the plan gives the operator.
- **Commit the small record, not the bulk.** Commit in this worktree, on branch
  `arniwesth/042-lean-harness-properties`. Before each push, with a clean tree, run
  `git fetch -q origin && git rebase -q origin/arniwesth/042-lean-harness-properties`. Never
  force-push. End each commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  You are the only session pushing to this branch until you finish. Bulk data stays out of git:
  keep it on disk, commit its hashes, and leave publishing it to the operator.
- **Stay off the multiplexer.** Do not use `herdr`, and do not restart the container.

## The machine

- **Memory is the limit.** The machine has 8 CPUs and 27 GB of RAM, and its swap is zram. On
  2026-11-04, eight memory-heavy sessions froze the container within minutes, and the kernel
  killed nothing. During W2, `trial/scripts/memwatch.py` killed arm processes over 6 GiB, and
  the largest one whenever available memory was under 3 GiB. It still runs, but it watches only
  arm sessions, not you. Guard your own runs: limit how many run at once, and how much memory
  each reproduction may use.
- **Expect heavy reproductions.** Each has 120 s (§8), and several of the arms' runs were
  memory-heavy.
- **`kill -0` cannot tell you a process has ended.** PID 1 is `sleep infinity`, so a detached
  process that exits stays a zombie, and `kill -0` keeps succeeding on it. Check
  `/proc/<pid>/status` for `State: Z` instead.
- **The tools are the arms' tools:** AILANG, Lean 4.28.0 under `~/.elan`, and bun. The arms'
  briefs say how they used them.

## When you are done

Commit and push `adjudicate.sh`, its table and your rulings. Then end with one line:
`W4 DONE <commit>`. If you cannot finish, end with `W4 STOPPED: <reason>`.
