# AILANG v0.15.0 Migration — pointer

**Status**: Draft PR, awaiting arni's input on provider configuration before code lands
**Branch**: `ailang-v0.15.0-migration` (this branch)
**Upstream design doc** (canonical, lives in AILANG repo):
[design_docs/planned/motoko-agent-v0.15.0-migration.md](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/motoko-agent-v0.15.0-migration.md)

## Why this is in AILANG's repo, not motoko_agent's

The migration plan is co-authored with the AILANG release that makes it possible (v0.15.0). Keeping the canonical doc in `sunholo-data/ailang` means:

- It evolves alongside the upstream features it consumes (M-AI-PROVIDER-CONFIG, M-AI-STREAMING-HELPER)
- Cross-references to upstream design docs (e.g. `m-ai-provider-config.md`) stay relative-path-stable
- Linked from [motoko-integration-sequence.md](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/motoko-integration-sequence.md) Phase 3

This file is just a marker — read the upstream doc for the full plan.

## Headline

motoko_agent currently clones a **fork of AILANG** at install time (`scripts/install-prerequisites.sh:363`: `git clone --branch motoko https://github.com/sunholo-data/ailang`). The fork existed to add OpenRouter routing, custom OpenAI base-URL routing, and token streaming — all three are now obsolete in upstream AILANG v0.15.0:

- **OpenRouter routing** → built-in `openrouter` provider in upstream
- **Custom OpenAI base-URL** → `[[ai_provider]]` block in `ailang.toml` (M-AI-PROVIDER-CONFIG)
- **Token streaming** → `std/ai/streaming.openaiCompatStream` + event loop (M-AI-STREAMING-HELPER)

This branch implements the migration. **No code changes in this draft commit** — only this plan pointer. Code lands after arni's team answers the questions in the upstream doc's [Questions for arni](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/motoko-agent-v0.15.0-migration.md#questions-for-arni) section.

## Files that will change (8 total, see upstream doc for detail)

| File | Type |
|------|------|
| `scripts/install-prerequisites.sh:363` | 1-line clone target swap |
| `ailang.toml` | Add `ailang = ">=0.15.0"` + `[[ai_provider]]` blocks |
| `src/core/rpc.ail` | API call-site rewrite (`callStreamResult` → event loop) |
| `src/core/ext/compose/compose.ail` | Same |
| `src/core/ext/compose/claimcheck.ail` | Same |
| `src/core/ext/compose/author_loop.ail` | Same |
| `src/tui/src/env-server.ts:642` | Update embedded AILANG codegen string |
| `ailang.toml` (continued) | Provider config blocks per arni's input |

Estimated work: **~4–5 hours** post-arni-ack, four milestones.

## Is the new code "better" or just different?

Honest answer in the upstream doc's [Is the new code better](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/motoko-agent-v0.15.0-migration.md#is-the-new-code-better--or-just-different) section. tl;dr: better in fundamentals (AI cap gating, budget tracking, trace span uniformity, declarative providers), more boilerplate at call sites until v1.1 ships a `callStream` accumulator helper.

## Smoke-test plan (Tier 1 + Tier 2)

Detailed in the upstream doc's [Smoke test plan](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/motoko-agent-v0.15.0-migration.md#smoke-test-plan-before-sending-pr) section. Every commit: `make test` + `ailang check` + TS compile. Pre-PR: real-provider end-to-end run with arni's API key.

---

**Last updated**: 2026-05-05
**Next action**: arni's team reviews the upstream design doc and answers the 7 questions; this branch then receives the migration commits.
