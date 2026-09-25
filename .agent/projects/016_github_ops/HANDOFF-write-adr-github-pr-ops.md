# HANDOFF: write the ADR for the GitHub PR ops pipeline

Date: 2026-08-16
From: the design-discussion session that authored `RESEARCH-github-pr-ops-pipeline.md`
To: a fresh session whose deliverable is `ADR-001-github-pr-ops-pipeline.md` in this
directory.
Status: design fully closed — all §5 forks and §6 questions in the RESEARCH doc are decided
with dates and rationale recorded in place. Your job is to synthesize those decisions into
a durable decision record. Implementation comes after the ADR; its sequencing is carried
forward in the appendix here and becomes a separate implementation handoff once the ADR
lands.

A note on `../../meta-decisions/author-each-artifact-in-the-session-whose-assets-it-
consumes.md`: ADRs are context-heavy, but this one's assets are **on disk** — every
decision in the RESEARCH doc carries its rationale, date, and the comparison that closed
it. Read the RESEARCH doc in full before writing anything; it is the source you are
synthesizing, not background.

## Re-ground before writing

Per `../../meta-decisions/re-ground-inherited-anchors-before-building.md`, verify at your
HEAD (all true 2026-08-15/16):

- `RESEARCH-github-pr-ops-pipeline.md` status header still says design closed and no fork
  has been reopened since.
- Remotes: `origin` = arniwesth/motoko_agent, `sunholo` = sunholo-voight-kampff/motoko_agent.
- `.agent/prs/` (13 files, two genres) still exists un-frozen; `.agent/github/` does not
  exist yet. If implementation has started in the meantime, say so in the ADR's grounding
  header rather than assuming.
- 008 fork 2 (frontmatter schema, `../008_docs_system/NOTE-docs-system-design-discussion.md`)
  still open. If it has closed, the ADR's schema section must conform to it instead of
  marking the schema provisional.

## The ADR to write

**File:** `ADR-001-github-pr-ops-pipeline.md`, this directory.
**Format:** house precedent — read `../006_compactor_strategy/ADR-001-compaction-persistence.md`
for the shape: title-as-question, `Date / Status / Grounded at (branch + HEAD)` header,
annotated `Relates to:` block, then Context → Options considered → Decision → Consequences.
**Status field:** **Accepted** (decided by operator, 2026-08-15/16) — this is not a stub;
the forks are closed.

**Title-as-question, roughly:** "How does Motoko interact with GitHub — identity, PR
creation, comment ingestion, and the processed-state record?"

### Decisions the ADR must record (each with its rationale, compressed from RESEARCH)

1. **Pipeline identity: machine-user account, not a GitHub App; not the operator's PAT**
   (RESEARCH §2.5, fork §5.5). Include the identity-follows-agency rule and the
   ambient-public-rights argument that closed App vs user. The App is the named upgrade
   path; migration cost = the credential behind `GH_TOKEN` only.
2. **Storage: `.agent/github/` with dir-per-PR layout; `.agent/prs/` frozen legacy;
   `.github/` carries only the PR-template mirror** (RESEARCH §2.3, forks §5.2–§5.4).
   Reproduce the layout block; the freeze must land in the same change that creates the
   new tree.
3. **Cache/state separation as an invariant pair**: immutable regenerable cache
   (`cache/`, gitignored) vs git-versioned judgment records; **sync only adds facts, only
   the loop changes judgments**; dismissals carry reasons (RESEARCH §2.2–§2.3, §6 Q2).
4. **Author → publish → write-back-the-key** as the universal publish shape: PR creation
   writes back the PR number, responses write back the comment id; artifact = source of
   truth, GitHub = transport (RESEARCH §2.1, §6 Q1).
5. **Sync scope: both remotes, PRs only**; issues and CI checks are designed follow-ons
   with named slots (`github/issues/`, `seen_head_sha` variant) (fork §5.1, §6 Q4).
6. **Cross-repo keying**: `(repo, pr, comment_id)` authoritative in frontmatter,
   alias-prefixed filenames for humans (§6 Q3).

### Options-considered section

Do not re-argue from scratch — compress the recorded comparisons: operator-PAT vs App vs
machine user (the §2.5 table), `.github/` vs `.agent/github/` vs status-quo `.agent/prs/`,
auto-revert vs flag-for-triage staleness. Link the RESEARCH doc for the full tables and
the measured §1 baseline; the ADR states *what* and *why*, the RESEARCH doc keeps *how we
got there*.

### Consequences section — at minimum

- **Dependency:** the state/frontmatter schema is provisional until 008 fork 2 closes;
  016 is now the third consumer waiting on it (with 015's kill/prediction fields).
  One conforming migration is expected.
- **Operator prerequisite:** the machine account (email, 2FA, collaborator invite on
  origin, classic PAT) is operator-only work and blocks all implementation (WI-0 below).
- **Classic-PAT breadth** is accepted, mitigated by scope-by-identity (the bot owns
  nothing); a fine-grained PAT is *not* a valid hardening because it cannot write to
  upstream repos.
- **Factory framing:** GitHub review becomes an intake channel of the idea factory
  (`../015_idea_factory/RESEARCH-idea-factory-and-idea-evaluation.md` §3.1, §5); the
  processed-state store is a view of the shared ledger, and its health metric is that
  comments *flow through it* (see prediction in the appendix).

### Relates-to block for the ADR

- `RESEARCH-github-pr-ops-pipeline.md` — the design record this ADR synthesizes.
- `../../prs/2026-08-13-pr-97-compaction-response.md` — the manual worked example the
  pipeline mechanizes.
- `../008_docs_system/NOTE-docs-system-design-discussion.md` — open schema dependency
  (fork 2).
- `../015_idea_factory/RESEARCH-idea-factory-and-idea-evaluation.md` — ledger/intake
  framing, kill-record and prediction disciplines.

---

## Appendix: implementation sequence (carried forward; becomes the implementation
handoff after the ADR lands)

Each item's acceptance criterion is stated inline; the implementation handoff should
expand these into testable form:

- **WI-0** (operator-only, blocks all): create machine account + 2FA, collaborator invite
  on origin, classic PAT (`public_repo`) into `GH_TOKEN`.
- **WI-1**: `gh` CLI + `GH_TOKEN` passthrough in all devcontainer variants; operator
  interactive `gh auth` unaffected.
- **WI-2**: PR template (Summary / Changes / Governing docs / Predicted outcome / Test
  evidence) + creation driver with number write-back; `.github/PULL_REQUEST_TEMPLATE.md`
  mirror.
- **WI-3**: `make pr-sync` + state writer, landed together; idempotent; stale-flags
  without reverting judgments.
- **WI-4**: backfill — register open PRs' comments as `pending`; PR #97 response becomes
  the first `responded` entry, referencing the frozen legacy file.
- **WI-5** (follow-on): the rank/test/respond loop skill, posting as the bot.

**Prediction to settle at project close** (015 §3.5): (a) every new origin PR is
driver-created with a populated template; (b) at least one upstream comment reaches
`responded` or `dismissed`-with-reason through the pipeline within two weeks of WI-3;
(c) no dispositioned comment is re-litigated. If (b) fails, the pipeline was premature
mechanization — record that honestly.
