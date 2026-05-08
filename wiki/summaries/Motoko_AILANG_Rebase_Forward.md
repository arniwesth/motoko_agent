---
doc_type: short
full_text: sources/Motoko_AILANG_Rebase_Forward.md
---

# Summary: Motoko AILANG Rebase-Forward

This document outlines a disciplined, phased plan to migrate Motoko’s AILANG runtime fork from the stale `dev_agent` (v0.9.0) onto the latest upstream release tag (v0.13.0) and to establish a permanent **rebase-forward** strategy. The core objective is to keep Motoko’s fork as close as possible to upstream AILANG, layering all custom extensions in strictly isolated `_motoko` files and minimal fenced edits, thereby making future AILANG releases simple rebases rather than painful cherry-pick triages.

## Key Principles

- **Upstream alignment** – The Motoko branch tracks a specific AILANG release tag, and all customizations are additive, never diverging edits to shared files.
- **Naming convention** – Every new file is suffixed `_motoko.{go,ail,ts}`; shared-file modifications are one‑liners bounded by `// motoko:begin` / `// motoko:end` comments.
- **Fork surface invariant** – `grep -r motoko ailang/` must return the complete fork surface, and `make verify-fork-surface` enforces constraints on fenced edits (≤5 lines, allowed patterns only).
- **Parallel-branch safety** – The existing `dev_agent` branch is retained and tagged until full end‑to‑end validation on the new `motoko` branch.

## Phases and Major Activities

1. **Phase 0** – Baseline the upstream v0.13.0 build, snapshot `dev_agent` diff, and read out the orphaned commit `c152a6d2` for test patches.
2. **Phase 0.5** – A critical [[concepts/phase_0_5_spike|spike]] to verify that streaming, new module `std/ai_motoko`, and runtime registration can be added additively without breaking the one‑line‑edit invariant. Findings are documented in [[reports/phase0_5_ai_interface_spike]].
3. **Phases 1–4** – Incremental ports of:
   - `_io_poll_stdin` (smallest patch, validates the convention)
   - OpenRouter provider routing ([[concepts/openrouter_integration|OpenRouter integration]])
   - Local OpenAI endpoint + error handling ([[concepts/local_openai_endpoint|Local endpoint]])
   - Streaming and Result‑based AI variants (largest phase), including detailed test acceptance criteria for ordering, budget, abort, and error propagation ([[concepts/streaming_support|Streaming support]])
4. **Phase 4b** – TUI protocol and renderer updates to make streaming visible to users, with new JSONL events and UI reconciliation.
5. **Phase 5** – Integration validation: update `core/rpc.ail`, audit effect annotations, run end‑to‑end Motoko tests, and diff the behavioral baseline trace.
6. **Phase 6** – Finalise [[reports/fork_md|FORK.md]] with full inventory, playbook, and hygiene tooling (`make verify-fork-surface`). A dry‑run rebase measures baseline conflict count for future releases.

## Conventions for Isolated Edits

- **`_motoko` files** contain all business logic, respecting upstream interface boundaries.
- **Fenced‑edit content rules**: only registration calls, single imports, or guard calls into `_motoko` files are allowed inside markers; no inline types or deep conditionals (see [[concepts/fenced_edit_convention|Fenced edits]]).
- **Module duality**: `std/ai_motoko.ail` is added as a new module alongside upstream `std/ai`, never shadowing it.

## Success Criteria

- Motoko runs on AILANG v0.13.0 with all custom features (streaming, OpenRouter, local endpoint, stdin polling) intact.
- `git diff` of non‑`_motoko` files shows only compliant fenced edits.
- `make verify-fork-surface` reports zero violations.
- Production continuity is maintained until cutover.

This document is a direct blueprint for implementing a sustainable fork management strategy, transforming a fragile cherry‑pick model into a predictable, repeatable rebase discipline.