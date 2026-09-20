# Brief: is `MOTOKO_PUBLIC_RELEASE.md` legacy — delete, or update?

Raised by the operator 2026-09-20. Handed off from the observer session (`w3:pZ`), which is
scoped to the PLAN-004 P2.3/P2.2 run and has no standing here. **Nothing below is a decision.**

## The question

The operator's words: *"`MOTOKO_PUBLIC_RELEASE.md` is very old and should be considered legacy. We
should consider deleting it or updating it to avoid confusion."* A release is wanted soon.

## Why it surfaced

The operator asked whether Motoko could be released now with the remaining ADR-004 parts deferred
as follow-ups. Answering that meant finding the release scope, and
`.agent/plans/MOTOKO_PUBLIC_RELEASE.md` (369 lines) is the only release document in the repo. It
was then used to reason about scope — and the operator's reply is that it should not have been.
Treat the conclusions below as **derived from a document now declared legacy**.

## What the document says (for whoever re-reads it)

- **Goal:** extract mature components from the private `ailang_agent` repo into a clean public
  `motoko_agent` repo, with dev Docker, streamlined deps, public README.
- **Non-goals:** *"Changing runtime behavior, extension logic, or TUI implementation."*
- Seven phases: manifest → install script → `.devdocker/` → README → sanitize config → trim
  Makefile → verification.
- Excludes `tools/`, `docs/`, `.claude/`, `benchmarks/`, `training/`, vendored `ailang/`, and more.
- **Includes `.agent/` wholesale** — plans, summaries, research, specs, learnings, notes, reviews,
  **issues**.

Signals it is stale: it describes extraction *from* `ailang_agent` *into* `motoko_agent`, but this
repo already **is** `motoko_agent`. It references a `.devcontainer/` to be replaced, though one
exists. It predates `src/eval/**`, `scripts/eval/**`, `packages/motoko-ext-*` and the observer/dagr
apparatus — none of which appear in its manifest.

## What the observer session concluded from it (now suspect)

1. ADR-004 / PLAN-004 is eval-only — E `562acadc` touches **zero** files under `src/core/` or
   `packages/`, so it does not gate a release. **This one stands on its own evidence**, independent
   of the release doc.
2. ABI 8.0 (`031/ADR-001`) is out of scope because the doc's non-goals exclude extension changes.
   **This depends entirely on the legacy doc and should be re-decided.**
3. The `.agent/` archive would ship publicly, and has absorbed operational detail this week —
   pane ids, session ids, delegate handles, model strings, corpus paths. See `.agent/issues/` and
   `.agent/projects/013_core_architecture_for_dst/DIRECTIVE-*.md`. **Worth checking under whatever
   scope replaces the doc.**

## What to work out

- Delete, or rewrite? If rewritten: is the release still a public extraction, or a versioned release
  of this repo?
- Does `031/ADR-001`'s *"settle the extension interface before the upcoming major release"* refer to
  this release or a later one? It is **Proposed v0.2, not frozen, "Documentation only. None of the
  proposed ABI, runtime, or format changes is implemented."** Current ABI is **7.4**. If 8.0 is meant
  to land before a freeze, that is the one unlanded, release-gating item found in the scan.
- What is publication-clean? `.agent/` is included wholesale by the legacy manifest.
- Where do `src/eval/**`, `scripts/eval/**`, `packages/motoko-ext-*`, `.claude/skills/` land?

## Context worth having

- Core surface is **clean**: `git status --porcelain src/core packages` → empty.
- Recently landed on core: PLAN-002 W2–W5 (park-and-wake **activated**, `85ce0c7d`), PLAN-003 P4
  Parts 1–3 (durable park/resume). Both committed.
- In flight and *not* release-relevant: PLAN-004 P2.4 driver-fix part, in a detached worktree at a
  pinned E, under an operator grant. Its observer is `w3:pZ`; do not disturb `w3:p1`.
- The current run's own apparatus — `.claude/skills/observer/`, `.agent/issues/` (2 files),
  `021_herdr_delegation/ADR-001`, `GATE-*`, `mutgate.sh`, `LEG-TEMPLATE.sh`, `LEDGER-*` — is
  **untracked**. A clean loses it. Unrelated to the release question, but it is real and open.
