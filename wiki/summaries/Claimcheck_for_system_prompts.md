---
doc_type: short
full_text: sources/Claimcheck_for_system_prompts.md
---

# Claimcheck for System Prompt Assembly

## Overview
Adapts the [[concepts/claimcheck]] technique—originally from formal verification of Dafny lemmas—to validate the system prompt of the AILANG SWE Agent. By performing a round-trip informalization (back-translating the assembled prompt into extracted rules, then comparing against intended core rules), the check catches silent contradictions introduced by untrusted project-specific files ([[concepts/system-prompt-assembly]]). The process is advisory, non-fatal, and adds minimal latency/cost before the agent enters its main loop.

## Problem

The agent’s system prompt is assembled from multiple untrusted sources: `base_system`, `SYSTEM_MD`, `AGENTS.md` files, and cache hints. These sources may contain conflicting instructions (e.g., native file API vs. bash‑only, different submission sentinel) that degrade model behavior silently—no crash, just incorrect outcomes. Existing validation is absent, leading to [[concepts/silent-failure]] and operator confusion.

## Approach: Intent Check via Claimcheck

Two sequential LLM API calls at session startup (before `rpc_loop`):

1. **Back‑translate (cheap model, e.g., Haiku):** Extract every behavioral rule from the fully assembled prompt, listed separately, with no knowledge of the intended rules.
2. **Compare (smarter model, e.g., Sonnet):** Take the extracted list and the canonical intended core rules, then classify each intended rule as PRESENT, WEAKENED, CONTRADICTED, or MISSING.

Structural separation ensures the checker cannot cheat by seeing the intended rules during extraction.

## What It Catches

- Direct contradictions (e.g., `fs.read()` instructions vs. bash‑only rule) → CONTRADICTED
- Soft undermining (e.g., cache hints implying native access is acceptable) → WEAKENED
- Overriding the submission sentinel → CONTRADICTED
- Context burying critical rules under excessive project guidance → MISSING
- Multiple bash blocks per response → CONTRADICTED

## What It Doesn’t Catch

- Subjective prompt quality (it only checks consistency against the intended contract)
- Unintended but non‑contradicting additions (project‑specific guidance is allowed)
- Model compliance with the prompt
- Syntax‑level issues (malformed Markdown, context window limits)

## Cost & Latency

- Two LLM calls per session (~$0.006 using Haiku + Sonnet)
- ~5–10 seconds startup delay
- Non‑blocking: if the checker fails, session proceeds unverified with a log message

## Integration

The check runs in `main()` right after prompt assembly. Violations are emitted as a `prompt_warning` event, displayed as a banner in the TUI. The session continues regardless—the warning is advisory.

## Design Decisions

- **Advisory, not fatal:** Avoids breaking the agent against projects with imperfect AGENTS.md files.
- **Parameterized intended rules:** Derived from `SYSTEM_MD` or `base_system`, so the checker adapts to the user’s chosen contract.
- **Model selection:** Reuses the session model (or Haiku fallback) to avoid extra provider configuration.
- **Idempotent:** One‑time check at startup, as the prompt does not change during the session.

## Future Directions

- **Intent envelope extension:** Check completeness (what rules are missing) alongside soundness.
- **Per‑layer checksums:** Attribute violations to specific input sources.
- **Standalone AGENTS.md lint:** A CI tool to validate project files before they reach the agent.

## Related Concepts

[[concepts/claimcheck]] · [[concepts/system-prompt-assembly]] · [[concepts/silent-failure]] · [[concepts/intent-check]] · [[concepts/agent-trust]]