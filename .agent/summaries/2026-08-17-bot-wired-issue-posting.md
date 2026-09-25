# 2026-08-17 Bot-wired issue posting: the missing half of "everything lands as motoko-agent"

## Context

Started on `arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded`. Entry point was a question
prompted by GitHub's 503 outage: *"Github has serious issues. But how can we make sure future PRs
and issues are posted as motoko-agent?"*

The PR half was already designed and mostly built — `tools/pr/` (pr/sync/loop), governed by
`.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md`, whose rule is **identity follows
mechanism**: anything the pipeline emits is the bot (`motoko-agent`, credential
`MOTOKO_BOT_GH_TOKEN`); anything done by hand is the operator (`arniwesth` via `gh auth login`).
ADR-001 D5 explicitly names issues as a designed follow-on landing at `.agent/github/issues/`,
with the same identity mechanism.

The gap was that **issues had no wired path at all**: issue drafts live in `.agent/issues/`, but
every issue (e.g. #163) was hand-posted as the operator. This session closed that gap and, along
the way, proved the whole identity claim live.

## The correction that shaped the session

My first identity probe was **methodologically wrong and I reported the wrong conclusion from it**:
I ran `MOTOKO_BOT_GH_TOKEN=… gh api user` and read `arniwesth`. But the `gh` CLI reads
`GH_TOKEN`/`GITHUB_TOKEN`, **not** `MOTOKO_BOT_GH_TOKEN`, so that invocation silently fell back to
the stored `gh auth login` (arniwesth) and told us nothing about the bot token. The docs in
`tools/pr/lib.ts` exist precisely because of this trap — the token is deliberately renamed so
ambient `gh` cannot silently inherit it.

Redone correctly (`GH_TOKEN=<bot-token>`), the measurements were:

| Probe | Result |
|---|---|
| `gh api user` with the bot token | **`motoko-agent`** (id 317527041, created 2026-08-16, name "もとこ") |
| `user/repos` | `arniwesth/motoko_agent` |
| perms on `origin` | **push: true** (pull/triage true) |
| perms on `sunholo` remote | **push: false** (pull only) |

So `motoko-agent` exists, the `.env` token genuinely belongs to it, and the bot can write to
`origin`. The user was right to push back on my 404/arniwesth claims.

## What got built

**`tools/pr/issues.ts`** (373 lines) — the issue slimline of `pr.ts`, committed as `5e43cfe`:

- `draft` / `create` / `whoami` subcommands mirroring `pr.ts`'s shapes and options
  (`--remote`, `--title`, `--force`, `--dry-run`, `--as-operator`, `--as-bot`).
- Templates with **Summary / Context / Expected**, each load-bearing; `create` refuses to publish
  while any `<!-- TODO -->` remains (same gate as a PR's five fields).
- **Author → publish → write-back** (ADR-001 D4): drafts stage under
  `.agent/github/staging/issues/<slug>/body.md`; `gh issue create --body-file` publishes **as the
  bot** by default; the returned issue number is written back into frontmatter at
  `.agent/github/issues/<remote>-<n>/body.md`.
- **Crash-safe and re-runnable**: an issue has no branch to adopt by, so `create` re-resolves the
  title from `--title` or scans the staging dir, and adopts an existing issue by exact
  (case-insensitive) title match instead of opening a duplicate.
- Reuses `lib.ts`'s identity plumbing (`ghEnv`, `reportIdentity`, `botToken`, `setProgramName`),
  so the issue path cannot drift into inheriting a token.

**Makefile** — `issue`, `issue_draft`, `issue_whoami` targets alongside the `pr_*` family.

**`tools/pr/README.md`** — documents the command, the `issues/` tree, and the identity tables.

No changes to `lib.ts`, `pr.ts`, or the PR side — the issue driver is purely additive.

## Live verification (the whole point, done for real)

GitHub was flapping with 503s through most of the session, so every network call needed retries.
Through the noise:

1. `make issue_whoami PR_FLAGS=--as-bot` → **`bot: motoko-agent`**.
2. Full `make issue_draft` → fill → `make issue PR_FLAGS=--dry-run` → *"acting as motoko-agent
   (bot) on arniwesth/motoko_agent"* + correct would-file line.
3. Real publish: `make issue` → **`issue: created #164`**.
4. Verified authorship with the bot token:
   `{"author":"motoko-agent","number":164,"state":"OPEN",...}` — **physically authored by the bot**.
5. Write-back artifact `.agent/github/issues/origin-164/body.md` carried `issue: 164` in
   frontmatter as designed.
6. Probe issue **closed** (`gh issue close 164`) and the probe artifact removed — no spam left.

This is the first *live* confirmation that a post on `origin` is authored by `motoko-agent`, not
by the operator.

## Facts that were measured, not assumed

1. **`gh` ignores `MOTOKO_BOT_GH_TOKEN`.** The renamed credential channel is a real footgun:
   setting it and running `gh` falls back to stored login and reports nothing. The value of the
   rename is exactly that it *prevents* ambient inheritance — but the same rename made my first
   probe lie. Always resolve identity through `lib.ts`'s `reportIdentity`/`ghEnv`, never by
   exporting the bot token name manually.
2. **`motoko-agent` is a normal User** (id 317527041), not a bot/App account, with no public
   repos of its own. Its write capability comes from the collaborator invite on `origin`.
3. **The bot has no write on `sunholo`** (`sunholo-voight-kampff/motoko_agent`, push:false). It
   can read there — which is enough for `pr-sync` comment ingestion — but `pr`/`issue` against
   `sunholo` will fail until `motoko-agent` gets write access.
4. **GitHub's 503 outage was real and long.** The REST layer flapped for most of the session;
   retrying with backoff was required to get a single clean live run.

## Corrections made mid-session

- **"motoko-agent does not exist (404)" and "the bot token is arniwesth's" — both wrong.** Caused
  by the `MOTOKO_BOT_GH_TOKEN` vs `GH_TOKEN` test error above, plus a transient 404 on the public
  API. Corrected after the user pointed at `github.com/motoko-agent`; re-probed with the right
  env var and confirmed the account and the token's real owner.
- The first version of `cmdCreate` had a muddled staged-title resolution path
  (`deriveTitleFromStaged()` returning a hardcoded `"Issue"`); rewritten to resolve the title from
  `--title` or scan the staging dir, and to run the field gate before any network touch.
- Stray template-literal escaping (`\\\\\`` in staged messages) broke the first build; fixed to
  single-backslash backticks and verified by `bun build`.

## Owed / remaining

- **`sunholo` write access for the bot** — operator/repo-admin action outside the sandbox. Until
  granted, use `--as-operator` for anything against `sunholo`.
- **No retry inside the tool.** Every `gh` call is single-attempt; the session pushed through
  GitHub's 503s with shell-level retries. A small bounded-retry wrapper in `lib.ts` would make the
  CLI resilient — deliberately not added to keep scope tight.
- **No test harness** for `tools/pr/` (pre-existing known gap in the README): a fake `gh` on
  `PATH` via the `lib.ts` chokepoints would cover adoption, crash recovery, and the identity
  split without touching GitHub.
- The issue driver writes only `.agent/github/issues/` records; there is no issue-side state.yaml /
  comment-triage loop yet — issues were the named follow-on, comments/CI remain future follow-ons
  per ADR-001 D5.