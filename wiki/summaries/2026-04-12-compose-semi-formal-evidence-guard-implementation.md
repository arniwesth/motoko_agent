---
doc_type: short
full_text: sources/2026-04-12-compose-semi-formal-evidence-guard-implementation.md
---

# Summary: Compose Semi-Formal Evidence Guard Implementation

This document describes the implementation of a multi-phase **semi-formal evidence guard** ([[concepts/semi-formal-evidence-guard]]) in the Compose subagent path. The guard combines effect-set witnesses, certificate templates, structural validation, and round-trip semantic verification to detect and mitigate generated content fabrication.

## Phases implemented

- **SF2 – Effect-set witness** ([[concepts/effect-set-witness]]): Parses declared effects, rejects `analyze`/`summarize` intents lacking `FS` or `Process` markers, replacing older heuristic checks.
- **SF1 – Certificate template & intent kind** ([[concepts/intent-kind]], [[concepts/certificate-template]]): Injects structured output shapes (`PREMISES/TRACE/CONCLUSION` etc.) into author prompts based on derived intent kind; propagates `intent_kind` across core transport.
- **SF3 – Certificate validator** ([[concepts/certificate-validator]]): Enforces required sections, premise line syntax, and presence constraints; triggers exit code escalation on strict failures.
- **SF5 – ClaimCheck round-trip** ([[concepts/claimcheck-verification]]): Per-attempt informalization of the certificate and comparison with the original intent using two separate LLM models; high-confidence `disputed` or `vacuous` verdicts force retries with hint.

## UI & defaults

- New runtime events and TUI rendering surface SF5 live deltas, verdict, confidence, and retry reasons ([[concepts/tui-visibility]]).
- `AILANG_COMPOSE_CLAIMCHECK` enabled by default, with budget caps and graceful inconclusive-accept fallback.

## Testing & Validation

- Unit tests for effect parsing, ClaimCheck separation invariants, retry triggers, and certificate validator cases.
- Build and all runtime type checks pass.

## Result

The Compose subagent now runs a thorough anti-fabrication pipeline: capability-level evidence, structured certification, and semantic consistency verification, all visible in the TUI and active by default.