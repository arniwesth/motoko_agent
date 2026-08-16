# ADR-001: How does Motoko interact with GitHub — identity, PR creation, comment ingestion, and the processed-state record?

Date: 2026-08-16
Status: **Accepted** (forks closed by operator 2026-08-15/16; implementation not started)
Grounded at: branch `arniwesth/mot-96-project-and-research-ideas-140826`, HEAD `90e86c1`

Grounding verified at that HEAD, 2026-08-16:
- `RESEARCH-github-pr-ops-pipeline.md` still reads *design closed 2026-08-16*; no fork reopened.
- Remotes: `origin` = `arniwesth/motoko_agent`, `sunholo` = `sunholo-voight-kampff/motoko_agent`.
- `.agent/prs/` exists, 13 files, two genres, **not yet frozen**; `.agent/github/` does not exist.
  No implementation work has begun — every decision below is prospective.
- `../008_docs_system/NOTE-docs-system-design-discussion.md` fork 2 (*how much frontmatter, in
  what format*) is **still open**, so D3's schema is provisional (see Consequences).

Relates to:
- `RESEARCH-github-pr-ops-pipeline.md` — the design record this ADR synthesizes. It holds the
  measured §1 baseline, the full option tables, and *how* each fork closed; this ADR states
  **what** was decided and **why**. Read it for anything this record compresses away.
- `../../prs/2026-08-13-pr-97-compaction-response.md` — the manual worked example this pipeline
  mechanizes: comments read, ranked, one quantitative claim **tested**, a disposition recorded.
  Everything around that judgment was hand-run and left no durable trace. That gap is the
  motivation for D2–D4.
- `../008_docs_system/NOTE-docs-system-design-discussion.md` — **open dependency** (fork 2). The
  state and PR-body frontmatter defined here are instances of that fork; 016 is its third
  consumer.
- `../015_idea_factory/RESEARCH-idea-factory-and-idea-evaluation.md` — §3.1 provenance joins
  (a reviewer comment is recorded evidence of a weakness), §3.5 predictions (the PR is where a
  prediction is naturally stated and later settled), §5 one-ledger (the processed-state store is
  a *view* of that ledger, not a third format), §6 Q1 kill records (a dismissal must carry a
  reason).

---

## Context / the question

Three capabilities were requested, in pipeline order: PR creation should be templated and
mechanized rather than hand-assembled in the web UI; PR comments on **both** remotes should be
fetchable automatically so a session can rank importance and test claims made in review; and a
durable record should exist of which comments and PRs have been processed, so work is not
repeated and dismissals are not re-litigated.

The measured baseline (RESEARCH §1) is that the first and third already exist in degraded form.
`.agent/prs/` holds 13 files in two undeclared genres — hand-authored PR bodies and one PR
*response* — with no convention, no join key to GitHub, and no processed-state anywhere.
`.github/` holds workflows only: no PR template. `gh` is not installed in the devcontainer, and
headless use needs a `GH_TOKEN` passthrough rather than interactive `gh auth login`.

The design question underneath all three is not "which GitHub API calls" — it is **what is
authored versus derived, what is immutable cache versus mutable judgment, and where each
lives**. A secondary question, raised once the pipeline was understood to be posting comments
upstream, is **whose identity** those actions carry.

---

## Options considered

Compressed from the recorded comparisons; the full tables are in the RESEARCH doc.

**Identity (RESEARCH §2.5, fork §5.5).** Three candidates. *The operator's PAT* is zero-setup but
makes every automated action indistinguishable from a human decision, so GitHub's history can
never be reconciled with the §2.3 ledger — rejected on that alone. *A GitHub App* (`motoko[bot]`)
offers short-lived installation tokens, fine-grained permissions, a first-class `[bot]` badge,
and is the prerequisite for a hosted multi-repo bot — but Apps have **no ambient rights**: with
no installation in the `sunholo` org, no App token can touch the upstream repo, which is exactly
where review comments arrive. *A machine-user account* participates in any public repo on day one,
can be a requested reviewer and own a fork, and costs an email, 2FA, and a collaborator invite —
at the price of a classic PAT, since fine-grained PATs cannot write outside their resource-owner
grant.

**Storage home (forks §5.2–§5.4).** `.github/` is GitHub's platform-config namespace, where
tooling assigns meaning to filenames — the wrong home for Motoko's working record. Status quo
`.agent/prs/` is already the *de facto* home but its name is narrower than the designed scope and
its 13 files carry no convention to inherit. `.agent/github/` is a fresh tree whose name admits
the follow-ons (issues, CI) that are already designed.

**Staleness on an edited comment (§6 Q2).** Auto-revert (an edited comment returns to `pending`)
is simple and never leaves a stale judgment standing — but most edits are typo fixes, and it
erases the fact that judgment was rendered at all. Flag-for-triage keeps the disposition and adds
a `stale: true` marker for the loop to adjudicate.

---

## Decision

**D1 — The pipeline acts as a dedicated machine-user account, not as the operator and not as a
GitHub App.** The governing rule is **identity follows agency**: actions a human decides on (the
operator running `make pr`) go out as the operator via ordinary `gh auth`; actions the pipeline
produces (sync, agent-drafted responses once approved for posting) go out as the pipeline
identity. Routing human-authored PRs through the bot would corrupt review semantics — CODEOWNERS,
review requests, self-approval rules.

The machine user beat the App on the **ambient-rights argument**: a user account has public
participation rights on any public repo, so upstream commenting works without the `sunholo` org
installing anything, while an App without an installation there simply cannot act. Everything the
App adds is either mitigable or not a current need. The App is the **named upgrade path** for a
hosted, event-driven, or multi-org bot; because `gh` + REST are the transport under every option,
**migration changes only the credential behind `GH_TOKEN`** — no pipeline design changes.

**D2 — Storage lives in a new `.agent/github/` tree, one directory per PR.** `.agent/prs/` is
**frozen as legacy** per 008's migration stance: indexed and referenced, never added to, never
moved. The only pipeline file in `.github/` is the `PULL_REQUEST_TEMPLATE.md` mirror.

```
.agent/github/
  cache/                      # gitignored, regenerable raw JSON
  prs/
    origin-153/
      body.md                 # authored PR body, PR number in frontmatter
      state.yaml              # per-comment state records
      response-2331456789.md  # response artifacts, named by comment id
    sunholo-97/
      state.yaml
```

`github/` rather than `prs/` because the designed scope already exceeds PRs — `github/issues/`
and CI checks slot in as siblings (D5). A PR with no comments is a directory holding only
`body.md`; a one-file directory is the price of a single naming scheme.

**The freeze and the new tree must land in the same change.** A window in which both are writable
is a window in which the convention is ambiguous and new files land in the wrong place.

**D3 — Cache and state are separate by invariant, and only one of them holds judgment.** The
GitHub-fetched cache (`.agent/github/cache/`, gitignored) is **immutable and regenerable**:
deleting it must lose nothing, and it is never edited. Processing state is git-versioned — shared
across sessions by ordinary pulls, greppable, reviewable in a diff. The pairing rule:

> **Sync only adds facts; only the loop changes judgments.**

A state record keys on the cache's own ids and carries the disposition:

```yaml
repo: sunholo-voight-kampff/motoko_agent
pr: 97
comment_id: 2331456789        # absent for PR-level dispositions
status: pending | ranked | claim-tested | responded | dismissed
rank: high | medium | low
reason: superseded by #154    # mandatory when dismissed
artifact: ../../prs/2026-08-13-pr-97-compaction-response.md
seen_updated_at: 2026-08-13T09:12:00Z
```

**Dismissals carry reasons** (015 §6 Q1 applied to comments): `dismissed` without a `reason` is
an invalid record. This is what makes the processed-set auditable and stops a later session from
re-litigating a comment someone already thought about.

Staleness follows from the same rule. On `updated_at > seen_updated_at`, sync sets `stale: true`
**alongside** the existing status and never rewinds a disposition; the loop treats stale records
as a triage queue — diff cached against current, then re-affirm (bump `seen_updated_at`, clear
the flag) or genuinely reopen.

**D4 — Publishing always follows author → publish → write-back-the-key.** The artifact on disk is
the source of truth; GitHub is transport. PR creation writes the body from a template, runs
`gh pr create --body-file`, and **writes the returned PR number back into frontmatter**. A
response is authored as an artifact file (the PR-97-response genre), posted with
`gh pr comment --body-file` as the machine user, and the **returned comment id/url is written
back into the state record**. `status: responded` requires *both* the artifact link and the
posted-comment key. A hand-posted response is the documented exception, not a peer path.

The write-back is what makes the whole system mechanical rather than heroic: without a join key
between the git tree and GitHub, state cannot be linked to artifacts except by a human
remembering.

The driver template — not `.github/PULL_REQUEST_TEMPLATE.md` — is the source of truth, because
`gh pr create` applies web templates only interactively and a web template cannot be
machine-filled. The `.github/` file is a mirrored fallback for the human web path.

**D5 — Sync covers both remotes, PRs only.** Issues and CI checks are **designed follow-ons with
named slots**, not vague someday-work: issues land at `.agent/github/issues/`, and CI reuses this
state machine with `seen_updated_at` replaced by `seen_head_sha` (check results are superseded
per-commit, not edited in place). Both are excluded from iteration one solely to avoid coupling
to a second API surface on day one — a failing workflow run is otherwise exactly the kind of
rankable, testable claim this pipeline exists to process.

**D6 — Records key on `(repo, pr, comment_id)` in frontmatter; filenames carry a remote alias for
humans.** The frontmatter tuple is authoritative and spells out the alias→slug mapping, so nothing
depends on local remote names. The `origin-97` / `sunholo-97` filename prefix exists purely so a
human grepping the tree never confuses colliding PR numbers across the two repos.

---

## Consequences

**The schema is provisional until 008 fork 2 closes.** D3's state fields and D4's PR-body
frontmatter are both instances of that fork. 016 must not close it unilaterally — but 016 is now
its **third** consumer waiting (after 015's kill/prediction fields), which is itself evidence for
closing 008 soon. Implementation proceeds on minimal YAML, flagged provisional, and **one
conforming migration is expected** when 008 lands. Budget for it; do not treat the schema as
settled.

**Operator prerequisite blocks all implementation.** The machine account — email, 2FA,
collaborator invite on `origin`, classic PAT into `GH_TOKEN` — is operator-only work that cannot
be delegated to a session. Nothing in the appendix's sequence can start before it.

**Classic-PAT breadth is accepted, not solved.** A fine-grained PAT cannot write to upstream
repos, so it is **not a valid hardening** for this design — reaching for one would silently break
the upstream participation D1 was chosen to enable. The mitigation is **scope-by-identity**: the
bot account owns nothing, so the blast radius of a leaked token is the bot's world, not the
operator's. Anyone tightening credentials later should change the *identity mechanism* (the App
path), not the PAT type.

**Provenance becomes machine-checkable.** Because pipeline actions carry the bot's identity,
GitHub's history and the §2.3 ledger can be reconciled — which is precisely what the operator's
PAT would have made unrecoverable. This is the property being bought; it is worth the setup.

**GitHub review becomes an intake channel of the idea factory.** A reviewer comment is recorded
evidence of a weakness with provenance attached — what 015 §3.1 wants ideas to join against — and
the processed-state store is **a view of the shared ledger**, not a fourth store. PR #97 already
shows the full shape: one comment thread produced a tested claim, a kill (close as superseded),
and a new queued idea (output headroom). Accordingly the health metric is **not** how complete
the store is, but that **comments flow through it** — see the prediction in the appendix.

**Automation stays at degree 1.** Grounding is mechanized (fetch, key, record); selection and
judgment stay in-session. Auto-ranking and auto-posting without review are explicitly out of
scope until the manual-with-mechanized-bookkeeping loop has produced data to justify them.

**A one-file directory and a frozen legacy tree are accepted costs.** Both are consequences of
choosing one naming scheme and refusing a migration of 13 files that carry no convention worth
preserving.

---

## Appendix: implementation sequence (carried forward)

Becomes a separate implementation handoff now that this ADR has landed; each acceptance criterion
below needs expanding into testable form there.

- **WI-0** (operator-only, blocks everything): machine account + 2FA, collaborator invite on
  `origin`, classic PAT (`public_repo`) into `GH_TOKEN`.
- **WI-1**: `gh` CLI + `GH_TOKEN` passthrough in **all** devcontainer variants; the operator's
  interactive `gh auth` must be unaffected.
- **WI-2**: PR template (Summary / Changes / Governing docs / Predicted outcome / Test evidence)
  + creation driver with number write-back; `.github/PULL_REQUEST_TEMPLATE.md` mirror.
- **WI-3**: `make pr-sync` + state writer, landed **together** (a cache with no state is a slower
  web UI; state with no cache has nothing to key against); idempotent; stale-flags without
  reverting judgments.
- **WI-4**: backfill — register open PRs' comments as `pending`; the PR #97 response becomes the
  first `responded` entry, referencing the frozen legacy file in place.
- **WI-5** (follow-on): the rank/test/respond loop skill, posting as the bot.

**Prediction to settle at project close** (015 §3.5): (a) every new `origin` PR is driver-created
with a populated template; (b) at least one upstream comment reaches `responded` or
`dismissed`-with-reason **through the pipeline** within two weeks of WI-3; (c) no dispositioned
comment is re-litigated. If (b) fails, this was premature mechanization — record that honestly
rather than quietly extending the window.
