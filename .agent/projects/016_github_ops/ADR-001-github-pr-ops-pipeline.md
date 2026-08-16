# ADR-001: How does Motoko interact with GitHub — identity, PR creation, comment ingestion, and the processed-state record?

Date: 2026-08-16
Status: **Accepted** (forks closed by operator 2026-08-15/16). WI-0–WI-3 landed 2026-08-16 on
`arniwesth/mot-97-github-ops`; see **Corrections** below for what implementation measured wrong.
Grounded at: branch `arniwesth/mot-96-project-and-research-ideas-140826`, HEAD `90e86c1`

Grounding verified at that HEAD, 2026-08-16:
- `RESEARCH-github-pr-ops-pipeline.md` still reads *design closed 2026-08-16*; no fork reopened.
- Remotes: `origin` = `arniwesth/motoko_agent`, `sunholo` = `sunholo-voight-kampff/motoko_agent`.
- `.agent/prs/` exists, 13 files, two genres, **not yet frozen**; `.agent/github/` does not exist.
  No implementation work has begun — every decision below is prospective.
  *(Point-in-time record, left as written. Superseded by Corrections, 2026-08-16.)*
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
  D3 state schema and D4 PR-body frontmatter defined here are two more instances of that fork,
  after 015's kill/prediction fields.
- `../015_idea_factory/RESEARCH-idea-factory-and-idea-evaluation.md` — §3.1 provenance joins
  (a reviewer comment is recorded evidence of a weakness), §3.5 predictions (the PR is where a
  prediction is naturally stated and later settled), §5 one-ledger (the processed-state store is
  a *view* of that ledger, not a third format), §6 Q1 kill records (a dismissal must carry a
  reason).

---

## Corrections

Recorded 2026-08-16, after WI-0–WI-3 landed. C1–C3 and C8 are **factual**: this document described
the world incorrectly and the body below has been fixed in place. C4–C7 were **open questions**
implementation surfaced that this ADR never decided; the operator closed them the same day, and
each now records its resolution. All eight remain provisional against 008 fork 2, which is
still open.

**C1 — PR #97 is on `origin`, not `sunholo`. (Fixed inline: D2, D3, Consequences, WI-4.)**
`sunholo-voight-kampff/motoko_agent` has exactly three PRs, #1–#3. The worked example this whole
ADR is motivated by — *"fix(compaction): calibrated estimate + output headroom + system-message
pinning (replaces #75)"* — is `arniwesth/motoko_agent#97`, still open. The error mattered more
than a name: WI-4 instructs a session to write the first real record from D3's example, and a
record filed under `sunholo-97/` is **silently orphaned**. `pr-sync` enumerates PRs from the API,
so it would never visit that directory, the D6 redundancy audit would never fire, and
`origin-97/state.yaml` would keep both comments `pending` forever — re-litigating a comment
already dispositioned, which is prediction (c) failing by construction.

**C2 — the response was posted, so the first backfilled record is `responded`, not `dismissed`.**
Measured: comment `5257958760` (2026-08-11T19:39:21Z, by `sunholo-voight-kampff`) is the inbound
review; comment `5284980557` (2026-08-13T18:45:54Z, by `arniwesth`) carries the text of
`.agent/prs/2026-08-13-pr-97-compaction-response.md` verbatim. It was hand-posted as the operator,
before the bot existed — D4's documented exception, not a peer path.

**C3 — "one comment among four" was wrong, and it weakens D3's granularity argument.**
D3 justified per-comment records by saying claims live at comment level, citing the headroom claim
as *"one comment among four"*. It is one of **four legs inside a single comment**: three superseded,
one live. So a comment is not the unit a claim lives at — this one carries four, with different
fates, and a single `status` cannot express *"three dismissed, one survives"*. Per-comment records
are still the right **storage** grain, and D3's decision stands: it survives on a reason the false
premise never supplied — a comment is the only stable key GitHub offers. The argument is replaced,
not the decision. C6 is the consequence.

**C4 — `status: responded` had no posted-comment key. (RESOLVED 2026-08-16: scalar `response_comment_id`.)**
D4 requires *both* the artifact link and the posted-comment key, and calls that key the thing that
makes the system "mechanical rather than heroic". D3's field list has `artifact` — which joins the
record to the **git tree** — and nothing that joins it to the **posted GitHub comment**. So the one
join key D4 names as load-bearing is the one D3 forgot to define. For `origin`#97 that is comment
`5284980557`, and there is nowhere to put it.

Three things break without it. **Posting is not idempotent**: WI-5 re-running cannot distinguish
"already responded" from "not yet", and unlike WI-2 — where `gh pr list --head <branch>` gives a
natural query key for adopting an existing PR — there is no equivalent query for "did I already
post this response?" short of fuzzy-matching body text. **Reconciliation is not possible**: the
Consequences claim GitHub's history and the state record "can be reconciled", and name that as *the
property being bought* by D1's identity split; reconciling means resolving each `responded` record
to its posted comment, which needs the key. **The genre cannot be traversed**: `response-<id>.md`
artifacts and their posted comments have no link.

**Resolved**: one scalar `response_comment_id`, parallel to `comment_id`. A `response:` submap or
a `responses:` list is more general, but D3's schema is flat today, `pr-sync`'s reader is flat, and
nesting pre-empts exactly what 008 fork 2 exists to decide. One response per inbound comment is the
loop's actual shape; a second is a new event and evidence for revisiting, not something to design
for now. `pr-sync` now enforces D4's pairing: `responded` without both `artifact` and
`response_comment_id` is reported as invalid, the same way `dismissed` without `reason` is.

Two adjacent details, neither needing a field. A response posted with `gh pr comment` is always an
`issue_comment`, so no `response_kind` is needed until WI-5 replies inline to a review comment —
which uses a different endpoint and would need one. And D4's **hand-posted exception** (which #97
is — `5284980557` was posted by `arniwesth`, not the bot) needs no marker: the author is a fact,
recoverable from the cache, and D3 already says facts live in the cache and judgments in the state.

Note the naming asymmetry this exposes. `response-<id>.md` is named by the **inbound** comment id,
never the posted one — the posted id does not exist until after publishing, so naming by it would
recreate the stage-then-rename dance D4 already solved for PR bodies. The same ordering is why the
key must be written back rather than known in advance.

**C5 — our own comments were queued as inbound. (RESOLVED 2026-08-16: skip them.)**
Measured across the 11 comments `pr-sync` records on `origin`: **7 by `arniwesth`, 4 by
`sunholo-voight-kampff`**. Sync files all of them `pending`, so the loop's triage queue is 64% our
own writing — including, on #97, the response itself queued as though someone else had raised it.
**Resolved**: skip them. C4 dissolves the alternative — once the outbound comment is referenced
from the inbound record via `response_comment_id`, it needs no record of its own, so giving it a
distinct status buys nothing. "Ours" is **the owner of `origin`, plus the bot**: `origin` is the
operator's own fork under this project's topology, so its owner is the operator by construction.
Derivable, no login list to keep current, and `--ours <login>` exists for anything else.

Recorded because it was nearly got wrong: the first implementation used *"the PR's own author,
plus the bot"*, which reads as equivalent and is not. `sunholo-voight-kampff` both authors PRs on
this fork and reviews them, so keying on PR authorship **dropped the inbound review on #97 — the
one record this project is motivated by — and kept our own response as a pending claim.** It
inverted 6 of 11 records. The origin-owner rule splits the real data exactly: 4 inbound reviews
kept, 7 of ours dropped. Nothing is lost either way; the cache holds every comment. The cost of
getting this wrong is not cosmetic — a queue that is 64% our own writing is a queue nobody works,
and degree-1 automation depends entirely on a human working it.

**C6 — a multi-claim comment has no representation. (DEFERRED to WI-5, with a stated preference.)**
Follows from C3. Either the loop decomposes a comment into per-claim records keyed under the
comment id, or a surviving leg leaves the comment record entirely and becomes an idea in 015's
ledger with provenance pointing back — leaving the comment `responded`. **Take the second**: it is
cheaper, it matches what actually happened to the headroom concern, and the mechanism already
exists. Do not decompose comments into per-claim records. Either way, a naive WI-4 that writes
`dismissed` loses the live leg.

**C7 — two schema fields were added by implementation. (CONFIRMED 2026-08-16: keep both.)**
`kind` (`issue_comment | review_comment`) is on every record `pr-sync` writes: GitHub draws issue
comment and review comment ids from separate sequences, so `comment_id` alone is **not a unique
key**, and WI-5 needs the kind to know which endpoint replies. Separately, **reviews get no state
record at all** — GitHub exposes `submitted_at` and no `updated_at` for the review envelope, so an
edited review body is undetectable, and a record whose staleness cannot be computed is exactly the
silently-stale judgment D3's pairing rule exists to prevent. Reviews are cached; the skipped count
is printed. There is no review traffic in either repo today, so nothing is lost yet. Both rest on
measured facts rather than preference, and both stand.

**C8 — this ADR's own example destroyed the reason it was demonstrating. (Fixed inline: D3.)**
`reason: superseded by #154`, written unquoted, parses as `"superseded by"` — YAML reads ` #` as a
trailing comment. Verified against js-yaml. The one example in this document of the field D3 makes
**mandatory** was silently truncating it, and any record hand-written from that example would lose
the audit trail that stops a comment being re-litigated. `pr-sync`'s emitter quotes defensively for
this reason; hand-written records get no such protection, which is an argument for the loop writing
them rather than a human.

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
never be reconciled with the state record (D3) — rejected on that alone. *A GitHub App* (`motoko[bot]`)
offers short-lived installation tokens, fine-grained permissions, a first-class `[bot]` badge,
and is the prerequisite for a hosted multi-repo bot — but Apps have **no ambient rights**: with
no installation in the `sunholo` org, no App token can touch the upstream repo, which is exactly
where review comments arrive. *A machine-user account* participates in any public repo on day one,
can be a requested reviewer and own a fork, and costs an email, 2FA, and a collaborator invite —
at the price of a classic PAT, since fine-grained PATs cannot write outside their resource-owner
grant.

**Storage home (RESEARCH forks §5.2–§5.4).** `.github/` is GitHub's platform-config namespace, where
tooling assigns meaning to filenames — the wrong home for Motoko's working record. Status quo
`.agent/prs/` is already the *de facto* home but its name is narrower than the designed scope and
its 13 files carry no convention to inherit. `.agent/github/` is a fresh tree whose name admits
the follow-ons (issues, CI) that are already designed.

**Staleness on an edited comment (RESEARCH §6 Q2).** Auto-revert (an edited comment returns to `pending`)
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
    origin-97/
      body.md                 # authored PR body, PR number in frontmatter
      state.yaml              # per-comment state records
      response-5257958760.md  # response artifacts, named by the INBOUND comment id
    sunholo-3/
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

Each record keys on the cache's own ids and carries the disposition. One `state.yaml` per PR
directory holds a list of them — per-comment, because a comment is what GitHub gives an id to
(**not** because claims live at comment level: the PR #97 headroom claim turned out to be one of
four legs *inside* a single comment — see C3/C6), grouped per PR for diff locality. The first
block is the real PR #97 record WI-4 backfills; the second is illustrative:

```yaml
# .agent/github/prs/origin-97/state.yaml
- repo: arniwesth/motoko_agent
  pr: 97
  kind: issue_comment           # C7: comment_id alone is not unique across kinds
  comment_id: 5257958760        # absent for PR-level dispositions
  status: responded
  rank: high
  artifact: .agent/prs/2026-08-13-pr-97-compaction-response.md   # repo-root-relative
  seen_updated_at: 2026-08-11T19:39:21Z
  # `responded` also requires the posted-comment key (D4) — comment 5284980557.
  # No field holds it yet; see Correction C4. This record cannot be written
  # completely until that is decided.
- repo: arniwesth/motoko_agent
  pr: 97
  kind: issue_comment
  comment_id: 5284980557        # our own posted response — see C5, currently queued as `pending`
  status: pending

# .agent/github/prs/sunholo-3/state.yaml  (illustrative — dismissals carry reasons)
- repo: sunholo-voight-kampff/motoko_agent
  pr: 3
  kind: issue_comment
  comment_id: 2331456812
  status: dismissed
  reason: "superseded by #154"  # mandatory when dismissed; quoted — see C8
  seen_updated_at: 2026-08-13T09:12:00Z
```

`status` ranges over `pending | ranked | claim-tested | responded | dismissed` and `rank` over
`high | medium | low`; both, and the field set generally, are provisional pending 008 fork 2.

Every record repeats the full `(repo, pr, comment_id)` tuple even though the directory implies the
first two — D6's keying rule is what makes a record portable and greppable on its own, and the
redundancy is checkable against the directory name rather than trusted.

`artifact` paths are **repo-root-relative**, not relative to the state file. RESEARCH §2.3
sketched this field as `../../prs/…` before the dir-per-PR layout closed; at the layout this ADR
adopts, that string resolves inside `.agent/github/prs/` rather than to the legacy tree — and the
first record WI-4 writes points at exactly such a legacy file. Root-relative removes the
depth-coupling entirely.

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

D2 and D4 interact in one place that constrains the driver: the directory key `<alias>-<n>`
**does not exist until the PR does**. So the driver stages the body outside its final home,
creates the PR, and then finalizes the directory as part of the same write-back step that records
the number. A crash between publish and write-back leaves a real PR with no local record — the
driver must therefore be re-runnable against an already-created PR, adopting it rather than
creating a second one.

The template's fields are load-bearing rather than cosmetic: **Summary**, **Changes**,
**Governing docs** (links into `.agent/projects/` — 008's cross-linking applied at the PR
boundary), **Predicted outcome** (015 §3.5: the PR states what landing it should change and how
that will be checked), **Test evidence**. Governing-docs and Predicted-outcome are the fields
that make a PR joinable to the ledger; dropping them for brevity would reduce this to an ordinary
PR template.

The driver template — not `.github/PULL_REQUEST_TEMPLATE.md` — is the source of truth, because
`gh pr create` applies web templates only interactively and a web template cannot be
machine-filled. The `.github/` file is a mirrored fallback for the human web path.

**D5 — Sync covers both remotes, PRs only.** Issues and CI checks are **designed follow-ons with
named slots**, not vague someday-work: issues land at `.agent/github/issues/`, and CI reuses this
state machine with `seen_updated_at` replaced by `seen_head_sha` (check results are superseded
per-commit, not edited in place). Both are excluded from iteration one solely to avoid coupling
to a second API surface on day one — a failing workflow run is otherwise exactly the kind of
rankable, testable claim this pipeline exists to process.

**D6 — Records key on `(repo, pr, comment_id)`; the remote alias appears in path names for
humans only.** The tuple is authoritative wherever a record lives — the YAML body of a
`state.yaml`, the frontmatter of a `body.md` or response artifact — and it carries the full
`owner/repo` slug, so **nothing depends on local remote names**: a clone that calls `sunholo`
something else still resolves every record correctly. A hypothetical `origin-97` / `sunholo-97`
pair shows why the **directory** name exists: purely so a human grepping the tree never confuses
colliding PR numbers across the two repos. (Only `origin-97` is real — see C1. RESEARCH §6 Q3 says
"filename prefix" because it was written before the dir-per-PR layout closed in §5.2; the alias
moved up to the directory, the purpose is unchanged.)

C7 amends the key itself: issue comments and review comments draw ids from separate sequences, so
the authoritative tuple is `(repo, pr, kind, comment_id)`. Pending a decision, `pr-sync` writes
`kind` on every record.

---

## Consequences

**The schema is provisional until 008 fork 2 closes.** D3's state fields and D4's PR-body
frontmatter are both instances of that fork, and 016 must not close it unilaterally. The fork now
blocks concrete work in two projects — 015's kill/prediction fields came first — which is itself
evidence for closing 008 soon. Implementation proceeds on minimal YAML, flagged provisional, and
**one conforming migration is expected** when 008 lands. Budget for it; do not treat the schema
as settled.

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
GitHub's history and the D3 state record can be reconciled — which is precisely what the
operator's PAT would have made unrecoverable. This is the property being bought, and it is what
justifies the WI-0 setup cost.

**GitHub review becomes an intake channel of the idea factory.** A reviewer comment is recorded
evidence of a weakness with provenance attached — what 015 §3.1 wants ideas to join against — and
the processed-state store is **a view of the shared ledger**, not a third invented format.
`origin`#97 already shows the full shape: a **single** reviewer comment produced a tested claim, a
kill (close as superseded), and a new queued idea (output headroom) — which is also why C6 is
open. Accordingly the health metric is **not** how complete
the store is, but that **comments flow through it** — see the prediction in the appendix.

**Automation stays at degree 1.** Grounding is mechanized (fetch, key, record); selection and
judgment stay in-session. Auto-ranking and auto-posting without review are explicitly out of
scope until the manual-with-mechanized-bookkeeping loop has produced data to justify them.

**The sync is not coupled to code-graph on day one.** The 008 `docs` profile can index the state
tree later, exactly like any other `.agent/` artifact; making the sync write an index is a
separate, deferrable decision and must not become a hidden prerequisite of WI-3.

**A one-file directory and a frozen legacy tree are accepted costs.** Both are consequences of
choosing one naming scheme and refusing a migration of 13 files that carry no convention worth
preserving.

---

## Appendix: implementation sequence (carried forward)

Becomes a separate implementation handoff now that this ADR has landed; each acceptance criterion
below needs expanding into testable form there.

- **WI-0** (operator-only, blocks everything): machine account + 2FA, collaborator invite on
  `origin`, classic PAT (`public_repo`) into `GH_TOKEN`.
- **WI-1**: `gh` CLI in the devcontainer + bot-credential passthrough; the operator's interactive
  `gh auth` must be unaffected. The token is supplied from the host environment and never
  committed — where the operator keeps it on the host is out of scope, but "somewhere in the repo"
  is not an option. **The credential must not be passed through as `GH_TOKEN` itself**: `gh`
  prefers `GH_TOKEN`/`GITHUB_TOKEN` over stored `gh auth` credentials, so a global export would
  make the operator's own `make pr` run as the bot and silently invert D1. Pass it under a distinct
  name and map it to `GH_TOKEN` only in the subprocess environment of pipeline commands. (Both
  devcontainer variants share `.devcontainer/docker-compose.yml`, so this is one line in one file;
  `.devcontainer/otel/` is not a variant. Grounding in
  `HANDOFF-implement-github-ops-wi0-wi2.md`.)
- **WI-2**: PR template (Summary / Changes / Governing docs / Predicted outcome / Test evidence)
  + creation driver with number write-back; `.github/PULL_REQUEST_TEMPLATE.md` mirror.
- **WI-3**: `make pr_sync` + state writer, landed **together** (a cache with no state is a slower
  web UI; state with no cache has nothing to key against), with the `.agent/github/cache/`
  `.gitignore` entry in the same change — D3's invariant is only real once the cache cannot be
  committed. Idempotent; stale-flags without reverting judgments.
- **WI-4**: backfill — register open PRs' comments as `pending`; `origin`#97's inbound review
  (comment `5257958760`) becomes the first `responded` entry, referencing the frozen legacy file in
  place. **Blocked on C4**: `responded` requires the posted-comment key (`5284980557`) and no field
  holds it. **Shaped by C5**: 7 of the 11 comments `pr-sync` currently records are our own.
  Running `make pr_sync` produces the `pending` half already; committing its output is this
  work item.
- **WI-5** (follow-on): the rank/test/respond loop skill, posting as the bot. See C6 — a comment
  carrying several claims with different fates has no representation yet.

**Prediction to settle at project close** (015 §3.5): (a) every new `origin` PR is driver-created
with a populated template; (b) at least one upstream comment reaches `responded` or
`dismissed`-with-reason **through the pipeline** within two weeks of WI-3; (c) no dispositioned
comment is re-litigated. If (b) fails, this was premature mechanization — record that honestly
rather than quietly extending the window.
