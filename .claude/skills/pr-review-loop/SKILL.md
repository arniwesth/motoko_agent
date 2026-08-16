---
name: pr-review-loop
description: Work the GitHub PR comment queue for this repo — rank inbound review comments, test the quantitative claims in them, respond as the bot, and record the disposition so nothing is re-litigated. Use when the user asks to check PR comments, triage review feedback, respond to a reviewer, work the PR queue, or asks "what's outstanding on the PRs", "did anyone comment", "is there review feedback to deal with". Also use after `make pr_sync` reports new records.
---

# PR review loop

The pipeline in `.agent/github/` mechanizes the *bookkeeping* around review comments — fetching
them, keying them, recording what was decided. It deliberately does not mechanize the deciding.
That split is ADR-001's "automation stays at degree 1", and this skill is the half that stays in
session: **you rank, you test, you write; the tools record.**

Governing document: `.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md`. Read its
Corrections section before doing anything unusual — several obvious-looking moves are wrong there
for measured reasons.

## The one rule

> **Sync only adds facts; only the loop changes judgments.**

`make pr_sync` may add records and flag staleness. Everything else — a rank, a dismissal, a
response — comes from here. Never hand-edit `state.yaml`: the record carries invariants an editor
breaks silently, and an unquoted `#` truncates a dismissal reason outright. Use `make pr_set`.

## Loop

### 1. Refresh, then look

```bash
make pr_sync        # adds any new comments as `pending`, flags edited ones `stale`
make pr_queue       # what needs attention
```

`pr_queue` shows only `pending` and `stale` records. An empty queue is the normal state.

### 2. Read the comment in full

```bash
make pr_show PR=76        # or FILE=<response path>, or ID=<comment_id>
```

Every `pr_*` target takes whichever of `PR=` / `FILE=` / `ID=` you have to hand. They resolve to
the same comment and print what they resolved to. A PR holding more than one comment refuses and
lists them rather than guessing — never disambiguate by picking one at random.

Never rank from the one-line preview. Read the whole comment and enough of the PR to know what it
is claiming.

### 3. Rank

```bash
make pr_set PR=76 PR_FLAGS="--status ranked --rank high"
```

`high` / `medium` / `low`. Rank by **what it would cost to be wrong**, not by how much work the
comment implies. A one-line comment asserting a number is high if the number governs a decision.

### 4. Test the claim, when there is one

This is the part that justifies the whole pipeline, and the part only a session can do. If the
comment makes a **quantitative or behavioural claim** — a limit, a ratio, a "this doesn't cover
that" — reproduce it before agreeing or disagreeing. Run the code, measure, and put the numbers in
the response.

The worked example is `.agent/prs/2026-08-13-pr-97-compaction-response.md`: a reviewer claimed the
compaction path left too little output headroom, and the response tested it — 262,144-token window,
95% input ceiling, ~249,036 in, ~13,108 left for output against a 65,536 allowance. That arithmetic
is why the response could concede one leg while dismissing three.

Record that you did it:

```bash
make pr_set PR=76 PR_FLAGS="--status claim-tested"
```

### 5. Decide

**Dismiss** when the comment is superseded, already handled, or wrong. A reason is mandatory —
that is what stops a later session re-opening it:

```bash
make pr_set PR=76 PR_FLAGS='--status dismissed --reason "superseded by #154"'
```

**Respond** when it deserves a reply. Author the artifact first, at
`.agent/github/prs/<alias>-<n>/response-<inbound comment id>.md` — named by the comment you are
answering, never by the one you are about to post, because that id does not exist yet.

Write it like the PR-97 response: concede what is right, state the test and its numbers, and be
explicit about what you are *not* accepting and why.

Then preview, get the user's approval, and only then post:

```bash
make pr_review  PR=76        # comment + drafted reply in one file, for reading elsewhere
make pr_respond PR=76        # prints the comment, then the full reply; posts nothing
make pr_respond PR=76 POST=1 # publishes as the bot, writes the key back
```

**Always show the user the preview and get an explicit go-ahead before `POST=1`.** `POST` must be exactly `1`; anything else is refused rather than silently treated as off. It publishes
under the machine account to a repo other people read; it is not undoable from here.

### 6. Stale records

A `stale` flag means the comment was edited after it was last seen. The disposition is kept — sync
never rewinds one. Diff what the cache holds against the current text, then either re-affirm:

```bash
make pr_set PR=76 PR_FLAGS=--affirm    # clears stale, bumps seen_updated_at
```

or, if the edit genuinely changed the claim, re-rank and work it again.

## Surviving claims go to the idea ledger, not into the record

A comment often carries several claims with different fates — PR #97's carried four, three
superseded and one live. `status` holds one value, so do not try to encode "three dismissed, one
survives" in it. Mark the comment `responded` and file the surviving claim as an idea in
`015_idea_factory`'s ledger, with provenance pointing back at `(repo, pr, comment_id)`. The
comment record is a disposition, not a claim tracker.

## Do not

- Rank, dismiss or post without the user's involvement. Degree 1 is the point.
- Hand-edit `state.yaml`, or set `status: responded` by hand — it needs the posted-comment key,
  which only posting produces.
- Re-open a comment already `dismissed` with a reason without saying why the reason no longer
  holds.
- Respond as the operator. Responses are pipeline output and go out as the bot; `make pr` is the
  only thing that acts as the operator.
- Post twice. `pr_respond` refuses when `response_comment_id` is already set; if you find yourself
  reaching for `--force`, something upstream is wrong.
