---
doc_type: short
full_text: sources/2026-04-12-ailang-composition-subagent.md
---

# AILANG Composition Subagent — Extended Implementation Summary

This pass deepens the [[concepts/compose-subagent]] rollout with streaming transport, intent preservation, refined retry policies, output‑contract enforcement, telemetry, UI enhancements, hint policy changes, and anti‑fabrication guards.

## Key changes

- **Streaming transport** — Runtime‑side line‑by‑line `/compose` forwarding via `curl -N` provides live NDJSON events to the TUI, making author deltas, checks, and retries visible in‑flight ([[concepts/streaming-transport]]).
- **Intent preservation** — The raw user prompt is forwarded as the subagent’s primary objective, while the planner’s scaffold serves as non‑binding guidance, preventing scope narrowing.
- **Retry policy** — Default max attempts raised from 20 to 50. Non‑zero `ailang run` exits are now retryable within the compose loop, with failure context fed back to the author to avoid premature termination ([[concepts/retry-policy]]).
- **Output contract & stdout** — Structured expected‑output validators (`non_empty`, `contains_all`, `lines_regex`) can force `exit=2` when unsatisfied. Raw stdout is persisted, while returned stdout is elided above a configurable byte limit ([[concepts/output-contract]]).
- **Compose telemetry** — End‑to‑end tracking of attempts, failures, validations, and outcomes, surfaced in TUI cards and stored for analytics ([[concepts/telemetry]]).
- **UI improvements** — Live authoring draft rendered in compose cards; high‑contrast, width‑safe error boxes; cards remain expanded after successful compose (collapsible via env toggle).
- **Hint policy** — Hints are now optional and disabled by default; only forwarded when explicitly enabled ([[concepts/hint-policy]]).
- **Compose trigger fix** — System prompt guidance updated to prefer Compose for broad architecture‑reasoning tasks, countering de‑emphasis of hints.
- **Anti‑fabrication guard** — Snippets with fabricated analysis markers (e.g., “simulated analysis”) are rejected, and analysis‑intent prompts must include evidence‑read primitives like `readFile` or `exec` ([[concepts/anti-fabrication]]).

## Effective runtime defaults

- `AILANG_COMPOSITION_MODE=subagent`
- `AILANG_SUBAGENT_MAX_ATTEMPTS=50`
- hints disabled unless `AILANG_COMPOSE_ENABLE_HINTS=1`
- compose cards expanded after completion by default

## References

- Implementation spans `src/core/rpc.ail`, `env_client.ail`, `prompts.ail`, `types.ail` and TUI modules in `src/tui/src`.
- Build and test: all core checks pass, TUI tests pass (12 suites, 70 tests).
- Related documentation: [AILANG Compose subagent plan](.agent/plans/AILANG_Composition_Subagent.md), [AILANG composition language summary](.agent/summaries/2026-04-11-ailang-composition-language.md).