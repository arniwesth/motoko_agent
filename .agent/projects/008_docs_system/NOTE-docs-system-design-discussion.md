# Note: formalized planning-documentation system for Motoko (design discussion opener)

Date: 2026-07-15
Status: Discussion in progress; the three forks below are **open** — no operator decision yet.
Provenance: authored in the session that opened this discussion, seeded by
`../../issues/docs-split-across-agent-and-design-docs.md` and a fresh survey of `.agent/`,
`design_docs/`, and `tools/code-graph/` at branch `arniwesth/mot-41-dts-consolidation` HEAD.
Updated same day with a survey of AILANG upstream's planning system
(`github.com/sunholo-data/ailang@dev`: `design_docs/README.md`, `design_docs/PROGRAM.md`,
`design_docs/v1-mission.md`, `.claude/skills/design-doc-creator/`).

## Why this project exists

`.agent/issues/docs-split-across-agent-and-design-docs.md` documents the problem: Motoko's
design/decision/plan documentation is split across `.agent/` (12 subdirs, ~420 files),
`design_docs/planned|implemented`, and root-level `*.md`, with overlapping document types, no
stated convention, no cross-linking, and no index. The proven failure: a decision recorded in one
tree ("compaction is ephemeral", `design_docs/planned/m-motoko-conversation-compaction.md:52`) was
nearly re-decided from the other tree, where all the related analysis lived. This project exists to
specify a formalized system that fixes that — and to decide how far
`tools/code-graph/` should be extended to serve it.

## What is already decided in practice (codify, don't redesign)

1. **The `projects/NNN_*/` convention works.** The lifecycle `RESEARCH → ADR → HANDOFF → PLAN →
   NOTE` with per-project directories is where all recent work (001–007) lives. The flat dirs
   (`plans/` 91, `summaries/` 89, `research/` 33) are pre-convention legacy.
2. **The meta-decisions are a planning methodology.** `author-each-artifact-in-the-session-whose-
   assets-it-consumes`, `re-ground-inherited-anchors-before-building`, and
   `compare-speculated-end-state-to-actual` are process rules the doc system should *mechanize*,
   not just record.
3. **The failure mode is specific:** decisions get re-litigated because nothing links the trees and
   nothing surfaces the governing doc at the moment of need (doc lookup *or* code change).

## Upstream comparison: how AILANG's planning system actually works (surveyed 2026-07-15)

AILANG at `dev` HEAD runs 1013 design docs (898 implemented / 110 planned / 5 rejected). The
mechanics differ from what this note initially assumed, in ways that bear on all three forks:

1. **Status is the directory, moved by scripts.** Tree: `planned/` → `implemented/vX_Y/`
   (version folders match CHANGELOG tags, underscored `v0_3_12`), plus `rejected/`, `deferred/`,
   `decisions/`, `archive/YYYY-MM/`. Transitions are mechanized (`create_planned_doc.sh`,
   `move_to_implemented.sh vX_Y`), and a move to `implemented/` must add an implementation report:
   What Was Built (incl. deviations from plan), Code Locations w/ LOC, Test Coverage, Metrics,
   Known Limitations. **No YAML frontmatter anywhere** — docs carry a bold-header metadata block
   (Status/Priority/Effort/Dependencies; Motoko's `m-motoko-conversation-compaction.md` is this
   exact template), and their MCP docs server derives state/version purely from path.
2. **Anti-re-litigation gates at doc *creation*, not lookup.** The `design-doc-creator` skill
   runs a mandatory Duplicate/Coverage Gate via SimHash + neural embeddings: ≥0.75 similarity to
   a planned doc → reject (already queued); ≥0.65 to an implemented doc → reject (already
   shipped); 0.45–0.65 → must read the related doc and document the distinction.
3. **Anti-stale-anchor is verification-at-use, stated as hard stops.** Any "AILANG does/does not
   support X" claim must be verified with live `ailang check` and the result quoted in the doc;
   cited regression fixtures must be confirmed to exist; the mission iteration template opens
   with "verify against repo reality first (git log + code + tests), never trust a status
   header." They assume drift and re-verify at point of use rather than detecting it continuously.
4. **A north-star layer sits above design docs.** `design_docs/PROGRAM.md` is the source all
   design docs must trace back to; `v1-mission.md` is an operational charter with a tagged queue
   (`[LANDED]`/`[NEXT]`/`[PARKED]`/`[RULED OUT]`), a rotating 3-stamp STATUS area overflowing to
   an archive file, and an append-only per-iteration mission log. There is **no `.agent/`
   analog** — AILANG's working record lives *inside* `design_docs/` as mission logs and queues.
5. **Mechanization is via ~43 skills** (design-doc-creator, sprint-planner/executor/evaluator,
   mission-control, design-spec-auditor, docs-sync), not a query index; machine-queryability
   comes from an MCP server over path conventions.

**Transferable core: AILANG prevents drift (mechanized transitions, creation-time gates,
close-out reports) where this note's Layer 2 only detects it.** Also: Motoko's `planned/` drift
is now explained — we copied AILANG's directory convention without the movement tooling and
close-out discipline that make it work.

## Proposed system (two layers)

### Layer 1 — Convention (cheap, no tooling)

- **One authority doc** (`DOCS.md` at root, or `.agent/README.md`) stating the boundary:
  `design_docs/` = durable feature-level design of the system as it should be;
  `.agent/projects/` = the working record of getting there; `issues/` = surfaced problems;
  `meta-decisions/` = process. Legacy flat dirs declared frozen (indexed, never added to).
- **Machine-readable frontmatter** on every planning doc — the load-bearing piece, because it is
  what code-graph consumes:

  ```yaml
  type: adr | plan | handoff | note | research | design | issue | summary
  status: draft | active | implemented | superseded
  topics: [compaction, dst]
  project: 007_dst_consolidation
  links: [design_docs/planned/m-motoko-conversation-compaction.md]
  code: [src/core/compaction]   # optional: modules/functions this doc governs
  ```

- **Status lives in frontmatter, not directory.** Fixes the `planned/` drift without a mass
  file-move — `m-motoko-conversation-compaction.md` gets `status: implemented` where it sits.

### Layer 2 — code-graph integration (ordered by value-per-effort)

Grounding: the source index is glob-driven (`HOST_FILE_GLOBS`,
`tools/code-graph/extractor/config.py:31`), already indexes some markdown (`AGENTS.md`,
`examples/**/*.md`), and has sha256-based staleness detection over `source_files`.

- **(a) A `docs` profile.** Add `PROFILES["docs"]` + globs for `.agent/**/*.md`,
  `design_docs/**/*.md`, root `*.md`. Existing `source_files`/`source_lines`/`source_chunks`
  machinery indexes them (`lang=md`), plus one new `docs` table parsed from frontmatter
  (path, type, status, topics, project). The compaction failure becomes one query spanning both
  trees: `SELECT path FROM docs WHERE has(topics, 'compaction')`.
- **(b) Stale-anchor detection.** A `doc_refs` pass parses `file:line` citations and function
  names out of markdown and joins them against `funcs` and `source_files.sha256`. Then
  `cgq.py q doc-anchors --stale` mechanically answers "which claims in this ADR no longer match
  HEAD" — turning the re-ground-anchors discipline into a runnable check. This is the piece that
  makes the system distinctly Motoko's rather than generic docs hygiene.
- **(c) Reverse query: docs-for-code.** Via the `code:` binding plus anchor extraction,
  `cgq.py q docs-for src/core/compaction` returns the design doc, ADRs, and open issues governing
  a module *before changing it* — preventing re-litigation at the point of code change.
- **(d) Generated index + planned-vs-actual diff.** A script emits `.agent/INDEX.md` (per-topic
  spine) from the `docs` table so the index cannot rot; the planned/actual `.mmd` comparison from
  the meta-decision gets a first-class command instead of being manual.
- **(e) Creation-time coverage gate** *(added after the upstream survey; validated same day)*.
  Before a new planning doc is authored, run a semantic overlap search and surface the governing
  docs — Motoko's version of AILANG's similarity gate. Prevents re-litigation at the moment it
  starts, instead of detecting it after the fact. **The hard part already exists**:
  `tools/code-graph/query/agent_semantic_poc.py` + `agent_semantic_benchmark.py` (project 002's
  experimental embedding layer, findings in
  `../002_code_graph/RESEARCH-project-memory-index.md`) do section-level markdown chunking with
  tiny-section merge and context prefixes, dual backends (local EmbeddingGemma via Ollama /
  hosted Gemini Embedding 2 via OpenRouter), sha256-keyed JSONL caching (= free incrementality),
  lexical boost, and a recall benchmark (recall@10 = 1.0 both backends; MRR@10 0.90 local /
  0.96 hosted on 12 queries).

  **Pilot on the documented failure case (2026-07-15).** A multi-glob driver over
  `.agent/**/*.md` + `design_docs/**/*.md` + root `*.md` (5,019 sections / 399 files; cold
  hosted index ≈ $0.27, warm queries free, ~11 s brute-force scoring) gave:
  - topic query "conversation compaction when context window fills up" → rank 1 =
    `design_docs/planned/m-motoko-conversation-compaction.md :: Problem`, ranks 2–10 = the
    `.agent` compaction cluster. One ranked list spanning both trees — the exact gap the issue
    documents.
  - differently-worded hypothetical new plan ("summarize old message history to keep the agent
    under the token limit") → top 10 all from the 006_compactor_strategy cluster + related
    issues; cross-wording overlap detection works.
  - "should compacted conversation state be persisted or ephemeral" → rank 1 =
    `006_compactor_strategy/ADR-001-compaction-persistence.md :: Context / the question` — the
    precise decided-once fact that was nearly re-litigated, surfaced at rank 1.

  Remaining work is packaging, not research: a `cgq.py` subcommand (or standalone gate script)
  with multi-glob corpus, a calibrated threshold (needs the graded-relevance labels the 002
  research already recommends), and — once (a) exists — a join against the `docs` table so hits
  carry `status`/`type` (an overlap with an *implemented* doc means "already shipped", with a
  *planned* doc "already queued", mirroring AILANG's two-threshold gate). Does not require (a)
  to be useful; (a) makes its output status-aware.
- **(f) Docs↔code provenance: derive, then verify** *(added 2026-07-15, operator-raised)*.
  Enforce that planning docs link to the code they result in — but as **derived attribution
  verified at the status transition**, not authored metadata checked by a linter. Grounding:
  the extractor has no git pass today, and current commit messages carry no doc references, so
  all linking machinery is net-new.
  - **Diff level is the ground truth.** A commit SHA is immutable, free to collect, and captures
    the *actual* end state — mechanizing `compare-speculated-end-state-to-actual`. Method-level
    links stored directly would churn with renames/splits (same staleness argument as mandatory
    `code:` in fork 2).
  - **Method level is a projection, not storage.** `doc → commits → hunks → funcs at that commit
    → funcs at HEAD` via existing sha256/slug machinery (or blame). Serves (c)'s docs-for-code
    query as a recomputable view over diff-level facts — never stale-by-storage.
  - **Attribution sources**: (i) going forward, one lightweight convention — a `Doc:` commit
    trailer, or the existing branch↔ticket↔project mapping (`arniwesth/mot-41-*`); (ii) for the
    backlog, heuristics — commits touching doc + code in one diff, commits within a project
    branch's lifetime, and semantic plan-section↔hunk matching classified
    `implemented/partial/unrelated` (already designed in 002's research; (e)'s validated
    embedding layer is the recall mechanism).
  - **Enforcement point: the status transition.** A doc cannot become `status: implemented` with
    an empty attribution set; the tool *presents* derived commits/functions, the author confirms
    or corrects — enforcing a review, not data entry (AILANG's implementation-report discipline,
    mechanized). A commit-time warning (diff touches paths an `active` doc governs, no trailer)
    is a follow-on and needs (c); do not start there — highest friction, lowest trust.
  - **Caveat**: (f) pays off only if the reverse query gets used at the moment of the next
    change. Sequence after (a)+(e). Lifecycle coverage: (e) prevents duplicates at creation,
    (f) closes docs with verified provenance at implementation, (b) detects drift in between —
    (f) alone is well-maintained metadata nobody queries.

### Migration stance

Do not move the ~420 legacy files. Index them; derive `type` from path/prefix where frontmatter is
absent (`summaries/2026-*.md` is unambiguously a summary). Add real frontmatter lazily, or in one
bulk pass for `status`/`topics` only. Pilot cross-linking on the compaction six-file cluster from
the issue, since it is the documented failure case.

## Open forks (operator input pending)

1. **Two trees or one?** Recommendation: keep `design_docs/` and `.agent/` separate — but note
   the upstream-symmetry argument is weaker than first stated: AILANG has no `.agent/` at all and
   keeps its working record (mission logs, queues) *inside* `design_docs/`. What actually matches
   upstream is the `planned/implemented` lifecycle and doc template, which Motoko already
   borrowed. The two-tree split stands on its own merits (durable design vs. working record),
   not on upstream parallelism. Alternative: fold `design_docs/` into `.agent/design/`.
2. **How much frontmatter?** Recommendation was minimal YAML (`type`/`status`/`topics`/`links`,
   `code:` optional). The survey adds a real alternative: **parse AILANG's bold-header metadata
   block instead** — upstream uses no YAML frontmatter, Motoko's `design_docs/` files already use
   the header-block template, and the block is nearly as machine-readable. Sub-fork: YAML on
   `.agent/` docs + header-block parsing on `design_docs/` (format follows tree), or YAML
   everywhere (format-inconsistent with upstream). Also: AILANG proves status-in-directory *can*
   work — but only with mechanized moves + close-out reports; if Motoko keeps status-in-
   frontmatter, it needs the equivalent close-out discipline or it just moves where the drift
   lives.
3. **Scope of first tooling iteration.** (a) alone is small and delivers the biggest single fix;
   (b) is the most novel and directly serves the meta-decisions; (c)/(d) are follow-ons. The
   survey adds (e), the creation-time coverage gate — and the 2026-07-15 pilot showed (e) is
   mostly *already built* (project 002's embedding layer) and works on the documented failure
   case, including surfacing the nearly-re-litigated persistence ADR at rank 1. That reorders
   the value-per-effort ranking: (e) is now the cheapest high-value increment, independent of
   (a). (f) is agreed to sequence after (a)+(e) — it completes the lifecycle but is not
   first-iteration material. Fork: first iteration = (e) packaged + (a), (a) + (d), or straight
   for (b)?

## Expected artifact sequence

Per `../../meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`:
the ADR (context-heavy — it synthesizes this discussion's decisions once the forks close) is
authored in this session's lineage; the implementation plan (source-heavy — code-graph extractor
seams, frontmatter parser, query surface) is authored fresh against HEAD from a HANDOFF written
here.

- `ADR-001-docs-system-convention-and-tooling.md` — after the forks close.
- `HANDOFF-write-docs-system-plan.md` — bridge to a fresh planning session.
- `PLAN-*` — per tooling increment, authored fresh.
