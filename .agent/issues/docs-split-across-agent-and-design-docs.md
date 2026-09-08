# Motoko docs are fragmented across `.agent/`, `design_docs/`, and the repo root with no convention or index

## Status
open

## Branch
arniwesth/mot-35-fix-context-size-estimation

## Description
Motoko's design/decision/plan documentation is split across multiple trees with **overlapping
document types, no stated convention for what goes where, and no cross-linking or index**. The
practical result is that a decision recorded in one tree is easily missed when working in the other.

### The two (three) trees
- **`.agent/`** — 12 subdirectories, e.g. `issues/` (4), `learnings/` (6), `meta-decisions/` (3),
  `notes/` (3), `plans/` (92), `projects/` (249 — each holds its own `ADR-*`, `PLAN-*`, `HANDOFF-*`,
  `NOTE-*`, `RESEARCH-*`), `prs/` (11), `research/` (108), `reviews/` (2), `specs/` (3),
  `summaries/` (87), `tools/` (2).
- **`design_docs/`** — `planned/` (24 `m-motoko-*.md` design docs) and `implemented/motoko_agent/` (3).
- **repo root** — `AGENTS.md`, `README.md`, `SYSTEM.md`, `CHANGELOG.md`, `CONTRIBUTING.md`,
  `phase_log.md`, `v0.12.1.md`.

### Overlapping document *types* across the trees
The same *kind* of artifact exists in several places, with no rule for which to use:
- **Design/decisions:** `design_docs/planned/` (design intent) **and** `.agent/projects/*/ADR-*.md`
  **and** `.agent/meta-decisions/`.
- **Plans:** `.agent/plans/` (92) **and** `.agent/projects/*/PLAN-*.md`.
- **Notes:** `.agent/notes/` **and** `.agent/projects/*/NOTE-*.md`.
- **Research:** `.agent/research/` (108) **and** `.agent/projects/*/RESEARCH-*.md`.
- **Learnings:** `.agent/learnings/` **and** memory (`~/.claude/.../memory/`, outside the repo).

### Concrete failure this caused (this session)
Investigating compaction, the design decision that **compaction is ephemeral** ("the returned `msgs`
replaces the input for this step only — the session log is unchanged") lives in
`design_docs/planned/m-motoko-conversation-compaction.md:52`, while all the related analysis lived in
`.agent/` (`issues/ephemeral-compaction-and-ai-noop-thrash.md`, `projects/001_DST/ADR-002-*`,
`research/DST/*compaction*`, `summaries/*compaction*`). A "compaction persistence" decision was almost
proposed as an *open fork* and nearly written as a new ADR — i.e. re-deciding something already
documented — precisely because the decision sat in the tree one was **not** looking at. A single
topic, "compaction," currently spans at least six files across `design_docs/planned/`,
`.agent/issues/`, `.agent/projects/001_DST/`, `.agent/research/DST/`, and `.agent/summaries/`, with no
link between them.

### Why it persists
- **No convention.** Nothing states the `.agent/` ↔ `design_docs/` boundary or when to use which.
  `README.md:204` calls `.agent/` a "Design archive (plans, summaries)" — vague and incomplete (it is
  far more than that), and says nothing about `design_docs/`. `CONTRIBUTING.md:113` mentions only
  `.agent/learnings/` for AILANG bug patterns.
- **No index / cross-linking.** Neither `.agent/` nor `design_docs/` has a `README`/index, and
  documents rarely link a design doc ⇄ its ADR ⇄ its issue, so there is no navigable spine per topic.
- **`planned/` vs `implemented/` drift.** `m-motoko-conversation-compaction.md` is under
  `design_docs/planned/` yet describes behavior that shipped — so "planned" is not a reliable signal
  of status, compounding the "is this decided?" ambiguity.

## Location
- `.agent/` (12 subdirs; ~570 files), `design_docs/planned/` + `design_docs/implemented/`, and
  root-level `*.md`.
- `README.md:204`, `CONTRIBUTING.md:113` — the only (partial, vague) location guidance.

## Fix (options — not yet decided; this issue is to surface the problem, not prescribe)
- **Document the convention (minimum).** One authoritative doc (e.g. `DOCS.md` or an `.agent/README`)
  stating the `.agent/` ↔ `design_docs/` boundary and what each subdir is for: e.g. `design_docs/` =
  durable, published design of shipped/planned features; `.agent/` = the working record (projects with
  ADR/PLAN/HANDOFF/NOTE, research, summaries, issues). Include the rule already emerging in
  `.agent/projects/`: *decision → ADR, execution → PLAN, bridge → HANDOFF* (see
  `004_phase_core_refactor/NOTE-plan-authoring-session-choice.md`).
- **Cross-link, don't necessarily move.** Cheapest high-value fix: when an ADR/issue/PLAN concerns a
  `design_docs/` feature, link the design doc, and vice-versa — so any entry point reaches the others.
  A per-topic spine beats a reorg.
- **Add indexes.** A short `design_docs/README.md` and `.agent/README.md` mapping subdir → purpose;
  optionally a topic index (compaction, harness-boundary, DST, …) listing the files per topic.
- **Fix the status signal.** Move design docs describing shipped behavior from `planned/` to
  `implemented/` (e.g. `m-motoko-conversation-compaction.md`), or add an explicit `Status:` header to
  each `m-motoko-*.md`, so `planned/` actually means planned.
- **Consolidation (larger, optional).** Merge overlapping type-dirs (`.agent/plans` vs
  `projects/*/PLAN`, `.agent/notes` vs `projects/*/NOTE`, `.agent/research` vs `projects/*/RESEARCH`)
  onto one location per type. High churn; do only if the convention doc + cross-linking prove
  insufficient.

## Notes
- **Project opened (2026-07-15):** `.agent/projects/008_docs_system/` — specifying a formalized
  planning-documentation system (convention + frontmatter + code-graph integration). Discussion
  state: `projects/008_docs_system/NOTE-docs-system-design-discussion.md`.
- Process guard added to memory this session (`check-design-docs-before-proposing-adr.md`): grep
  `design_docs/` + `.agent/projects/*/ADR-*.md` before calling a decision "open." That mitigates the
  symptom for an agent with memory, but does not fix the underlying fragmentation for humans or fresh
  sessions — hence this issue.
