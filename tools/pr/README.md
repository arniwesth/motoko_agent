# pr

GitHub PR operations: author a PR body as a file and publish it, fetch review comments, and record
what was decided about each one.

```
                    ┌─ pr ──────> gh pr create ──> PR number written back
   .agent/github/ <─┼─ pr-sync ─< comments fetched into a disposable cache
                    └─ pr-loop ─> gh pr comment ──> comment id written back
```

The organising idea is that **the file on disk is the source of truth and GitHub is transport**.
Every publishing step is author → publish → write-back-the-key, so the git tree and GitHub can be
reconciled later without anyone having to remember which comment answered what.

Design record: [`.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md`](../../.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md).
Read its **Corrections** section before changing anything — several obvious-looking moves are
wrong there for measured reasons.

## Two identities

| Acting as | Who | Credential |
|---|---|---|
| `pr`, `pr-sync`, `pr-loop respond`, `issue` | **the bot** (`motoko-agent`) | `MOTOKO_BOT_GH_TOKEN` |
| `pr --as-operator`, `issue --as-operator` | **you** | `gh auth login` |

The rule is *identity follows mechanism*: **anything the pipeline emits is the bot; anything done
by hand in the web UI is you.** One rule, readable off a PR's author field without knowing which
command produced it.

Note what this does not cover. The branch is pushed with git's credentials and commits keep their
own authorship, so a PR reads as *"motoko-agent wants to merge N commits"* over commits authored by
whoever wrote them. And because both halves now carry the bot's name, identity no longer tells you
whether a human decided something — that has to come from the state record.

**Identity is never inherited.** `gh` prefers `GH_TOKEN`/`GITHUB_TOKEN` from the environment over
the credentials `gh auth login` stored, and says nothing when it does — so an ambient token would
silently decide who acts, in either direction. The bot credential therefore travels under a
distinct name and is mapped into `GH_TOKEN` only inside the subprocess of the command that wants
it; `--as-operator` strips both so it acts as you even if one is set.

Every command prints which account it resolved to before it writes anything, and you can ask
directly:

```sh
make pr_whoami                   # → arniwesth
make pr_whoami PR_FLAGS=--as-bot # → motoko-agent
make issue_whoami PR_FLAGS=--as-bot  # → motoko-agent (dedicated to issues/drafts)
```

## Setup

`gh` is installed into the image by `scripts/install-prerequisites.sh`. Beyond that:

1. `gh auth login`, once per container (`~/.config/gh` does not survive a rebuild).
2. `MOTOKO_BOT_GH_TOKEN` — either exported on the host, which
   `.devcontainer/docker-compose.yml` passes through, or in the gitignored repo-root `.env`.
   Tools read the environment first and fall back to `.env`.

The bot token must be a **classic** PAT (`ghp_…`) with `public_repo`, and the bot must have
*accepted* its collaborator invitation. A fine-grained PAT (`github_pat_…`) reads fine and returns
`403 Resource not accessible by personal access token` on every write; `pr` warns if it sees one.
`issue` shares the same token check via `lib.ts`.

## Creating a PR

```sh
make pr_draft                  # stage a body from the template
$EDITOR .agent/github/staging/<branch>/body.md
make pr                        # publish, write the number back
```

`pr_draft` fills **Changes** from the branch's commits and **Governing docs** from every
`.agent/projects/` file it touches, diffing against `<remote>/<base>` rather than the local ref so
a stale local `main` cannot list commits the PR does not contain. **Summary**, **Predicted
outcome** and **Test evidence** are yours; `pr` refuses to publish while any `<!-- TODO -->`
remains, because those five fields are what make a PR joinable to the ledger rather than an
ordinary PR template.

`make pr` drafts first if you skipped it, and is safe to re-run: it **adopts** the PR already open
for the branch instead of opening a second. If the local record is missing it reconstructs it from
GitHub — the recovery path for a crash between publishing and writing back.

| Variable | Default | |
|---|---|---|
| `BASE` | `main` | Base branch, and the diff base |
| `REMOTE` | `origin` | Which remote to open against |
| `PR_FLAGS` | — | Passed through, e.g. `--dry-run`, `--title`, `--force`, `--as-operator` |

`.github/PULL_REQUEST_TEMPLATE.md` mirrors the same five sections for PRs opened by hand in the web
UI. The driver's template is the source of truth — `gh pr create` applies a web template only
interactively, and a web template cannot be machine-filled. Change one, change both.

## Creating an issue

```sh
make issue_draft --title="Step budget wipes history"
$EDITOR .agent/github/staging/issues/step-budget-wipes-history/body.md
make issue                       # publish (as motoko-agent), write the number back
```

`issue` is the slimline of `pr` (see tools/pr/issues.ts, ADR-001 D5): the file on disk is the
source of truth, GitHub is transport, and the returned issue number is written back into the
frontmatter's `issue:` field. **Summary**, **Context** and **Expected** fill the same
load-bearing gate as a PR's five fields, and `issue` refuses to publish while any `<!-- TODO -->`
remains. `issue` acts as the **bot** unless `--as-operator`, and is re-runnable: it adopts an
existing issue whose title matches (issues have no branch to adopt by, so title is the
recovery key) instead of opening a duplicate.

An issue has no branch or diff, so `draft` takes the title explicitly
(`make issue_draft --title="…"`); `create` recovers a crash by reusing whatever body is already
staged. Final records land in `.agent/github/issues/<remote>-<n>/body.md`.

| Variable | Default | |
|---|---|---|
| `REMOTE` | `origin` | Which remote to file against |
| `TITLE` | — | Issue title (required for `issue_draft`) |
| `PR_FLAGS` | — | Passed through, e.g. `--dry-run`, `--force`, `--as-operator` |

## Syncing comments

```sh
make pr_sync                              # both remotes, open PRs
make pr_sync PR_FLAGS=--dry-run           # fetch and report, write nothing
make pr_sync REMOTE=sunholo PR_FLAGS="--pr 3 --state all"
```

Raw JSON lands in `.agent/github/cache/` — gitignored, immutable, regenerable. Deleting it must
lose nothing. A `pending` record is appended for every comment not seen before.

Comments authored by **the owner of `origin` or by the bot** are cached but not queued: they are
our own writing, not inbound claims, and a queue that is mostly your own comments is a queue nobody
works. Override with `--ours <login>`.

Reviews (the approve / request-changes envelope) are cached but get **no state record**. GitHub
exposes `submitted_at` and no `updated_at` for them, so an edited review body is undetectable, and
a record whose staleness cannot be computed is exactly the silently-stale judgment the design
exists to prevent. The skipped count is printed rather than implied.

## Working the queue

```sh
make pr_queue                                   # pending and stale records
make pr_show    PR=76                           # the full comment
make pr_set     PR=76 PR_FLAGS="--status ranked --rank high"
make pr_review  PR=76                           # comment + drafted reply, one file
make pr_respond PR=76                           # preview; posts nothing
make pr_respond PR=76 POST=1                    # publish, as the bot
```

Every `pr_*` target above takes whichever handle you have — they all resolve to the same comment
and print what they resolved to:

| | |
|---|---|
| `PR=76` | the PR number |
| `FILE=.agent/github/prs/origin-76/response-5021529142.md` | the artifact path; tab-completes |
| `ID=5021529142` | the comment id itself |

PR numbers and comment ids are told apart by width — ids are nine or ten digits, PR numbers four at
most. A PR holding more than one comment refuses and lists them rather than guessing.

To respond, author the artifact at `response-<inbound comment id>.md` first. It is named by the
comment you are **answering**, never by the one you are about to post: that id does not exist until
after publishing, so naming by it would force a rename afterwards.

`POST` must be exactly `1`. Anything else is refused rather than silently treated as off.

## The invariant

> **Sync only adds facts; only the loop changes judgments.**

`pr-sync` may append records and set `stale: true`. It never rewrites a `status`, `rank`, `reason`
or `artifact` — including its own from a previous run — and it never rewinds a disposition. When a
comment is edited it flags staleness *alongside* the existing judgment, leaving a triage queue;
`pr-loop set --affirm` clears the flag and bumps `seen_updated_at` once you have re-read it.

`pr-loop` is the only thing that writes judgment. It is a tool rather than "edit the YAML by hand"
because the record carries invariants an editor breaks silently: a dismissal needs a `reason`, a
response needs both `artifact` and `response_comment_id`, and an unquoted `#` truncates a reason
outright — `reason: superseded by #154` parses as `"superseded by"`. That is not hypothetical; it
is how the ADR's own example lost a reason.

## What gets written

```
.agent/github/
  cache/                       # gitignored, regenerable raw JSON
    origin-97/
      pr.json  issue-comments.json  review-comments.json  reviews.json
  prs/
    origin-97/
      body.md                  # authored PR body, number in frontmatter
      state.yaml               # per-comment records
      response-5257958760.md   # response artifacts, named by inbound comment id
  issues/
    origin-164/
      body.md                  # authored issue body, number in frontmatter
```

A record:

```yaml
- repo: arniwesth/motoko_agent   # the tuple is authoritative; the directory name is for humans
  pr: 97
  kind: issue_comment            # issue_comment | review_comment — ids collide across the two
  comment_id: 5257958760
  status: responded              # pending | ranked | claim-tested | responded | dismissed
  rank: high                     # high | medium | low
  artifact: .agent/prs/2026-08-13-pr-97-compaction-response.md   # repo-root-relative
  response_comment_id: 5284980557
  seen_updated_at: 2026-08-11T19:39:21Z
  stale: true                    # set by sync on edit; cleared by --affirm
```

`reason` is mandatory when `dismissed`. `artifact` **and** `response_comment_id` are both mandatory
when `responded`. `pr-sync` reports violations and records disagreeing with their own directory
name, but never corrects them.

The schema is **provisional** pending fork 2 of `008_docs_system`; expect one conforming migration.

## Layout

| | |
|---|---|
| `pr.ts` | PR creation, as you |
| `issues.ts` | Issue creation, as the bot (ADR-001 D5) |
| `sync.ts` | comment fetch + state append, as the bot |
| `loop.ts` | rank / dismiss / respond, the judgment write path |
| `lib.ts` | identity, `gh`/`git` wrappers, paths, frontmatter |
| `state.ts` | the `state.yaml` reader/writer |

Identity handling lives in `lib.ts` rather than in each entry point on purpose: a second copy is a
second place for it to drift into inheriting a token by accident. `state.ts` is shared for the
same reason — the sync/loop invariant is only enforceable if both agree byte-for-byte on what a
record is.

`.claude/skills/pr-review-loop/` carries the judgment half: how to rank, when to test a claim, and
what to do with a comment that makes several claims with different fates.

## Known gaps

- **No test harness.** Neither `tools/` nor `.agent/tools/` has one, and this tool did not invent
  one. `gh` and `git` are reached through single chokepoints in `lib.ts`, so injecting a fake
  binary via `PATH` would cover adoption, crash recovery and the identity split without touching
  GitHub. That is the shape a real check should take.
- **A response is always an issue comment.** Replying inline to a review comment needs a different
  endpoint and a `response_kind` field; neither exists yet.
- **One response per comment.** `response_comment_id` is a scalar. A second reply to the same
  comment has nowhere to go — deliberately, since that would be a new event worth noticing rather
  than a case to design around.
