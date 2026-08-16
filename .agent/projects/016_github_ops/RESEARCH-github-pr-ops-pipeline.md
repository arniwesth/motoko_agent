# RESEARCH: GitHub PR ops — templated creation, comment ingestion, processed-state ledger

Date: 2026-08-15
Status: Research — **design closed 2026-08-16.** §1 is measured at 2026-08-15 HEAD; §2–§4
are the design; all forks (§5.1–§5.5) and questions (§6.1–§6.5) are closed with decisions
recorded in place. Next artifact: `ADR-001-github-pr-ops-pipeline.md`, authored from
`HANDOFF-write-adr-github-pr-ops.md` (same directory); implementation handoff and PLAN
follow the ADR, per
`../../meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`.
Relates to:
- `../008_docs_system/NOTE-docs-system-design-discussion.md` — the frontmatter/keying schema
  this pipeline's state records must be consistent with (its fork 2 is a dependency of §4)
- `../015_idea_factory/RESEARCH-idea-factory-and-idea-evaluation.md` — §3.1 provenance joins
  (a reviewer comment is recorded evidence of a weakness), §3.5 predictions (the PR is where a
  prediction naturally gets stated), §5 one-ledger (the processed-state store is another view),
  §6 Q1 kill records (a dismissed comment must carry a reason)
- `../../prs/2026-08-13-pr-97-compaction-response.md` — the worked example this design
  mechanizes (see §1.4)

---

## 0. The question

Three capabilities were requested, in pipeline order:

1. **PR creation is templated and mechanized** — a PR is defined by a template and created
   via `gh`, not hand-assembled in the web UI.
2. **PR comments and upstream PRs are fetchable automatically**, so an agent session can rank
   importance and test claims made in review.
3. **A durable record exists of which comments and PRs have been processed**, so work is not
   repeated and dismissals are not re-litigated.

The design question underneath all three: what is authored vs derived, what is immutable
cache vs mutable state, and where does each live.

---

## 1. Ground truth at HEAD (measured 2026-08-15)

### 1.1 `.agent/prs/` is already a proto-system

13 files, two genres, no stated convention:

- **Hand-authored PR bodies** (`mot-7` … `mot-26`, plus dated entries): base branch, Summary,
  Changes — drafted in-session, presumably pasted into GitHub manually. The branch naming
  convention `arniwesth/mot-NN-slug` already encodes the ticket key.
- **PR responses** (`2026-08-13-pr-97-compaction-response.md`): a full manual run of the
  requested pipeline — see §1.4.

### 1.2 No PR template

`.github/` contains only `workflows/` (`dst-corpora.yml`, `verify-extensions.yml`).
No `PULL_REQUEST_TEMPLATE.md`, no issue templates.

### 1.3 Two remotes; `gh` not installed

```
origin   https://github.com/arniwesth/motoko_agent.git
sunholo  https://github.com/sunholo-voight-kampff/motoko_agent.git
```

"Upstream PRs" therefore means the sync must cover both repos. `gh` is **not installed in the
devcontainer** (`gh: command not found`) — blocker zero for every stage below. Headless/agent
use additionally needs a `GH_TOKEN` passthrough, not interactive `gh auth login`.

### 1.4 The worked example: the PR #97 response

`../../prs/2026-08-13-pr-97-compaction-response.md` is the target workflow executed by hand:
comments on an upstream PR were read, ranked (four points agreed, one concern isolated as
still-valid), a quantitative claim was **tested** (95% input ceiling on a 262,144-token
context admits ~249,036 input tokens, leaving ~13,108 for output — insufficient for a
65,536-token allowance), and a disposition was recorded (close #97 as superseded by #154;
spin off output-headroom as its own issue). What is missing is everything around it: the
comments were fetched by hand, nothing records that #97's comments are now processed, and the
disposition lives only as prose.

---

## 2. Proposed design: four stages, strict cache/state separation

Two design rules hold across all stages:

- **Cache and state never mix.** The GitHub-fetched cache is immutable and regenerable;
  deleting it must lose nothing. Processing state is the work record and lives in git.
- **Dismissals carry reasons** (015 §6 Q1 applied to comments): "dismissed: superseded by
  #154" makes the processed-set auditable and prevents re-litigating the same comment in a
  later session.

### 2.1 Creation: template as source, `.agent/prs/` as artifact, `gh` as transport

Formalize the existing practice: the PR body is authored as
`.agent/github/prs/<alias>-<n>/body.md` (§2.3 layout) from a template, then published with
`gh pr create --body-file`. The directory key (repo-alias + PR number) exists only after
creation, so the driver stages the body pre-creation and finalizes the directory as part of
the number write-back step. Do **not** rely on `.github/PULL_REQUEST_TEMPLATE.md` alone —
`gh pr create` only applies templates interactively, and a web template cannot be
machine-filled.

A small driver (`make pr` or `.agent/tools/pr-create.ts`):

1. derives ticket/project from the branch name (`arniwesth/mot-96-…` → `mot-96`);
2. fills the template: Summary, Changes, **Governing docs** (links into `.agent/projects/` —
   008's cross-linking applied at the PR boundary), **Predicted outcome** (015 §3.5: the PR
   states what landing it is expected to change and how that will be checked), Test evidence;
3. writes `.agent/prs/<ticket>.md`, runs `gh pr create --body-file`, and **writes the
   returned PR number back into the file's frontmatter** — the join key between the git tree
   and GitHub. Without it, stage 2.3 cannot link state to artifacts mechanically.

### 2.2 Ingestion: an idempotent sync, not ad-hoc fetches

One command (`make pr-sync`) pulls, for both remotes:

- `gh pr list --state all --json …` (PR-level metadata),
- per-PR review comments, issue-style comments, and reviews
  (`gh api repos/{owner}/{repo}/pulls/{n}/comments`, `…/issues/{n}/comments`,
  `…/pulls/{n}/reviews`),

into an **immutable local cache** at `.agent/github/cache/` (gitignored): raw JSON keyed by
`(repo, pr, comment_id)`. GitHub's `id` + `updated_at` give the same staleness semantics
code-graph gets from sha256 — sync is a cheap upsert, re-runnable anytime, and "what changed
since last sync" falls out for free. The cache is derived data, never edited; keeping it
adjacent to (but ignored beside) the state tree makes the cache/state rule legible in the
tree itself.

### 2.3 Processing state: git-versioned, keyed by the cache's ids

Per comment/PR, a state record:

```yaml
repo: sunholo-voight-kampff/motoko_agent
pr: 97
comment_id: 2331456789        # absent for PR-level dispositions
status: pending | ranked | claim-tested | responded | dismissed
rank: high | medium | low     # once ranked
reason: superseded by #154    # mandatory when dismissed
artifact: ../../prs/2026-08-13-pr-97-compaction-response.md   # what discharged it
seen_updated_at: 2026-08-13T09:12:00Z   # staleness guard: comment edited after processing?
```

Lives in git (shared across sessions via normal pulls, greppable, reviewable). The field
schema must land inside whatever closes 008 fork 2 — the processed-set is another view of
015 §5's ledger, **not a third invented format**.

**Layout (decided 2026-08-16, closes fork §5.2; home decided same day, `.agent/github/`):**
one directory per PR, keyed by remote alias + number:

```
.agent/github/
  cache/                      # gitignored, regenerable raw JSON (§2.2)
  prs/
    origin-153/
      body.md                 # authored PR body (§2.1), PR number in frontmatter
      state.yaml              # per-comment state records (this section)
      response-2331456789.md  # response artifacts, named by comment id (§6 Q1)
    sunholo-97/
      state.yaml
```

Rationale for `.agent/github/` over the alternatives: `.github/` is GitHub's platform-config
namespace (workflows, templates, CODEOWNERS) — tooling assigns meaning to files there, and
this material is Motoko's *working record*, which 008's boundary places in `.agent/`; the
only pipeline file in `.github/` is the `PULL_REQUEST_TEMPLATE.md` mirror (fork §5.3). The
existing `.agent/prs/` is **frozen as legacy** per 008's migration stance (indexed, never
added to); the §3 backfill references its files (e.g. the PR-97 response) without moving
them. `github/` rather than `prs/` because the designed scope already exceeds PRs — issues
(fork §5.1 follow-on) and CI checks (§6 Q4) slot in as sibling subdirectories. A PR with no
comments is a directory containing only `body.md` — a one-file directory is the price of a
single naming scheme.

### 2.4 The agent loop on top: no new infrastructure

A session (or skill) reads `status: pending` records, does what the PR #97 response did —
rank, test claims against the codebase, draft responses — and writes state transitions plus
response artifacts back. Posting responses via `gh pr comment` can be mechanized too, but the
judgment stays in-session: this is deliberately degree-1 automation in 015 §2's terms
(grounding mechanized, selection human/Claude). Anything further (auto-ranking without
review, auto-posting) is out of scope (§7).

### 2.5 Identity and auth: a separate pipeline identity under `gh`
*(added 2026-08-15; reworked 2026-08-16 after the machine-user alternative was raised)*

Two decisions here, one settled and one forked.

**Settled: the pipeline does not act as the operator.** Pipeline actions authenticate as a
dedicated identity so GitHub's own history agrees with the §2.3 ledger about who did what;
with the operator's PAT every automated action impersonates the operator and the distinction
is unrecoverable. `gh` + REST remain the transport either way — only the token in `GH_TOKEN`
differs — so §2.1–§2.2 commands are identical under any option.

**Identity rule: identity follows agency.** Actions a human decides on (the operator's
`make pr`) go out as the operator via normal `gh auth`; actions produced by the pipeline
(sync, agent-drafted responses once approved for posting) go out as the pipeline identity.
Routing human-authored PRs through the bot would muddy review semantics (CODEOWNERS,
review-requests, self-approval rules).

**Decided (2026-08-16, operator): the pipeline identity is a machine-user account**
(`motoko-bot` or similar), not a GitHub App — fork §5.5. The comparison that closed it,
measured against this project's actual needs:

| Dimension | GitHub App (`motoko[bot]`) | Machine user (`motoko-bot`) |
|---|---|---|
| Upstream participation | Requires the sunholo org to install the App; Apps have **no ambient rights** — no installation, no token that covers their repo | **Works day one** — a user has ambient public-participation rights (comment, fork, PR) on any public repo |
| Credentials | ~1 h installation tokens minted from a private key; fine-grained permissions | A PAT. Gotcha: fine-grained PATs cannot write outside their resource-owner grant, so upstream commenting needs a **classic PAT** (`public_repo`) — broad by construction. Mitigation is scope-by-identity: the bot account owns nothing, so the blast radius is the bot's world, not the operator's |
| Provenance rendering | `[bot]` badge, first-class | Ordinary user; naming convention carries the signal |
| User-shaped abilities | Cannot be assigned as PR reviewer, no fork ownership | Can be requested as reviewer, own a fork, be @-mentioned naturally |
| Event-driven future | App registration is the prerequisite for a hosted multi-repo bot | Plain repo webhooks on `origin` need no App, so own-repo event-driven ingestion stays available; only the multi-org hosted-bot path is closed |
| Rate limits | Per-installation | Standard 5,000/h per user — irrelevant at this scale |
| Setup/ops | App registration + private-key secret + JWT→token minting helper | Email + 2FA + collaborator invite to `origin`; GitHub ToS permits one free machine account per person |

**Rationale for the close:** the machine user buys the two properties this project needs now
(identity separation, upstream participation) at the lowest operational cost; everything the
App adds is either mitigable (credential hygiene via scope-by-identity) or not a current
need (per-installation limits, multi-org hosted bot). The App remains the upgrade path if a
hosted/event-driven or multi-org bot emerges — the migration changes only the credential
behind `GH_TOKEN`, no pipeline design.

### 2.6 Factory framing

This makes GitHub review a **new intake channel for the idea factory**: a reviewer comment is
recorded evidence of a weakness with provenance attached — exactly what 015 §3.1 wants ideas
to join against. The PR #97 case already shows the shape: one comment thread produced a
tested claim, a kill (close as superseded), and a new queued idea (the output-headroom
issue). The pipeline's value is making that trace mechanical instead of heroic.

---

## 3. Sequencing (value per effort)

1. **Blocker zero:** `gh` in the devcontainer, plus the machine-user account (§5.5, closed):
   create the account (own email + 2FA), invite it as collaborator on `origin`, mint a
   classic PAT (`public_repo`) into `GH_TOKEN`. Operator's own `gh auth` stays interactive
   per §2.5's identity rule. (`.devcontainer/` files are already modified on the current
   branch — convenient timing.)
2. **Template + creation driver (§2.1).** Smallest piece, immediately useful on every PR,
   and establishes the frontmatter join key everything else needs.
3. **Sync (§2.2) + state store (§2.3).** Land together — a cache with no processed-state is
   just a slower web UI; state with no cache has nothing to key against.
4. **Backfill:** one pass to register existing open PRs' comments as `pending`, and record
   the PR #97 case retroactively as the first `responded` entry (it is already written).
5. **Loop skill (§2.4)** once 3 exists and has real pending rows to chew on.

---

## 4. Dependency on 008

The state schema (§2.3) and the PR-body frontmatter (§2.1) are both instances of 008 fork 2
("how much frontmatter, in what format"). This project should not close that fork
unilaterally — but it is now the second consumer waiting on it (015's kill/prediction fields
being the first), which is itself evidence for closing 008's forks soon. If 008 stalls
further, the pragmatic move is: use minimal YAML here, flag it as provisional, and conform
when 008 closes.

---

## 5. Open forks (operator input pending)

1. **Scope of sync. CLOSED 2026-08-16 (operator): both remotes, PRs only.** Issues are a
   follow-on once the state mechanics are proven; they slot in as
   `.agent/github/issues/` per §2.3's layout.
2. **State granularity and layout. CLOSED 2026-08-16: per-comment records, one
   `state.yaml` per PR directory under `.agent/github/prs/<alias>-<n>/`** (full layout and
   rationale in §2.3). Claims live at comment level — the PR #97 headroom claim was one
   comment among four — grouped per-PR for diff locality. `.agent/prs/` frozen as legacy.
3. **Template location. CLOSED 2026-08-16: both.** Driver template is the source of truth;
   `.github/PULL_REQUEST_TEMPLATE.md` is a mirrored human-path fallback for the web UI —
   and the only pipeline file that lives in `.github/` (§2.3 rationale).
4. **Where the cache lives. CLOSED 2026-08-16: gitignored `.agent/github/cache/`.** The
   state file already records everything decision-bearing; committed snapshots would be a
   second source of truth with noisy diffs.
5. **Pipeline identity mechanism** (§2.5 comparison): GitHub App vs machine-user account.
   **CLOSED 2026-08-16 (operator): machine user.** Upstream participation works without the
   sunholo org's involvement and setup is minimal; App kept as the later upgrade path if a
   hosted/multi-org bot emerges. Migration cost between the two is only the credential
   behind `GH_TOKEN`.

---

## 6. Open questions

1. **Response posting. CLOSED 2026-08-16 (operator): artifact = source of truth.**
   A response is authored as an artifact file (the PR-97-response genre), posted via
   `gh pr comment --body-file` as the machine user, and the returned comment id/url is
   written back into the §2.3 state record — the same author → publish → write-back-the-key
   shape as §2.1's PR creation. `status: responded` requires both the artifact link and the
   posted-comment key; a hand-posted response is the documented exception, not a peer path.
2. **Staleness semantics. CLOSED 2026-08-16: flag for triage, never auto-revert.** On
   `updated_at > seen_updated_at`, sync sets `stale: true` *alongside* the existing status —
   it never rewinds a disposition (most edits are typo fixes; auto-revert would erase the
   fact that judgment was rendered). The agent loop treats stale records as a triage queue:
   diff cached vs current body, then re-affirm (bump `seen_updated_at`, clear flag) or
   genuinely reopen. Rule of thumb: **sync only adds facts; only the loop changes
   judgments.**
3. **Cross-repo identity. CLOSED 2026-08-16: frontmatter authoritative, filename for
   humans.** Every record keys on the full `(repo, pr, comment_id)` in frontmatter; state
   files carry a remote-alias prefix (`origin-97`, `sunholo-97`) purely so humans grepping
   never confuse colliding PR numbers. The alias→slug mapping is spelled out in frontmatter,
   so nothing depends on local remote names.
4. **CI as a claim source. CLOSED 2026-08-16: deferred, but as a *designed* follow-on.**
   A failing workflow run is a rankable, testable claim and fits the same state machine; what
   differs is the fetch surface (checks/actions API) and staleness (results are superseded
   per-commit — `seen_updated_at` becomes `seen_head_sha`). Excluded from iteration one only
   to avoid coupling to a second API surface; the state schema already generalizes.
5. ~~**Upstream response identity**~~ — *dissolved by fork §5.5 closing on the machine
   user*: the bot has ambient public-participation rights and posts upstream directly. (Had
   the App been chosen, this would have required a sunholo installation or an
   operator-identity fallback.)

---

## 7. Explicitly out of scope for now

- **Auto-ranking or auto-responding without in-session judgment** — degree-2 automation;
  belongs after the manual-with-mechanized-bookkeeping loop produces data (same ordering
  argument as 015 §7).
- **Indexing the cache/state in code-graph.** The 008 `docs` profile can index the state
  files later exactly like other `.agent/` artifacts; do not couple the sync to the index on
  day one.
- **Issue ingestion and CI ingestion** — pending fork §5.1 and question §6.4.
