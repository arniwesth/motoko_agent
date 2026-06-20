# M-MOTOKO-ACP-INTEGRATION — make motoko an Agent Client Protocol agent

**Status**: Planned
**Priority**: P2 — strategic positioning, not a blocker
**Estimated effort**: 2–3 days (~16–24 hours) for a minimal ACP-agent adapter; ~1 week for full registry submission + production polish
**Dependencies**: Stable motoko loop_v2 (✅); profile/config system handling sessions (✅); compaction merged (gates long-context use cases — see `m-motoko-conversation-compaction.md`)
**Source**: 2026-05-23 conversation about agent standardization. Surfaced from a question about whether AILANG could standardize its monitoring on ACP — answer was "no, monitoring is OTEL's lane", but the conversation surfaced that motoko *itself* is a natural ACP agent.
**Companion doc**: [AILANG's rejection of ACP](https://github.com/sunholo-data/ailang/blob/dev/design_docs/rejected/m-acp-evaluation.md) — re-confirms why ACP is the wrong layer for the AILANG language but the right layer for an agent harness like motoko.

---

## Problem

motoko is an agent harness. Today it ships as a standalone TUI plus a programmatic API consumed by AILANG packages. To work inside someone's editor or IDE — Zed, JetBrains, marimo, etc. — motoko would need a bespoke integration per editor. Nobody has shipped one. The integration cost is high enough that "use motoko inside Zed" is currently impractical.

The **Agent Client Protocol** (ACP) standardizes this exact problem: it's the LSP-style protocol that connects coding agents to editors. As of 2026-05-23 it has:

- **Stable v1 wire protocol** (JSON-RPC over stdio for local; HTTP/WebSocket WIP for remote)
- **25+ agents** in the registry: GitHub Copilot CLI, Codex, Gemini CLI, Claude Agent, Qwen, OpenCode, Auggie, Factory Droid, Mistral Vibe, etc.
- **Editor adoption**: Zed (origin), JetBrains (since Oct 2025), marimo, Eclipse prototype, Toad terminal
- **ACP Registry** live since Jan 2026 — automatic agent discovery from `https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json`
- **Active development**: 3.2k stars, 1,419 commits, v0.13.3 released 2026-05-22

The standardized session-update notification format (`plan`, `agent_message_chunk`, `tool_call`, `tool_call_update`, `request_permission`) maps cleanly onto motoko's loop_v2 stage hooks (DP0/DP3/DP6/DP7).

**Strategic question:** Should motoko speak ACP?

Two distinct concerns flow from this:

1. **motoko AS an ACP agent** — editors spawn motoko as their AI agent. Motoko gets free distribution into Zed/JetBrains/marimo/etc. Users get to keep their editor while running motoko's autonomous Phoenix-architecture loop.
2. **motoko AS an ACP client** (consuming other ACP agents) — motoko could spawn Copilot/Codex/Qwen as sub-agents in multi-agent compose flows. Currently it's CLI-shelling specific tools; ACP would let it consume any registry-listed agent uniformly.

Concern (1) is the strong case. Concern (2) is interesting but less urgent and can be layered on later.

---

## Goals

### Primary (concern 1: motoko as ACP agent)

- Stand up a `motoko serve --acp` mode that implements the ACP server contract over stdio
- Translate ACP `session/prompt` requests into motoko loop_v2 invocations with the existing profile/config system
- Map loop_v2's DP hooks onto ACP's `session/update` notifications (`plan`, `agent_message_chunk`, `tool_call`, `tool_call_update`)
- Honour `session/cancel`, `session/resume`, `session/close` against motoko's chain-provenance store
- Implement `session/request_permission` flow for tool-use approval — motoko already has pending-policy infrastructure for this
- Submit to the ACP Registry so motoko shows up in Zed's "add agent" picker and JetBrains' ACP Agent Registry

### Stretch (concern 2: motoko as ACP client)

- Add an `ext/acp-subagent` extension that lets a motoko loop spawn an ACP-listed agent as a sub-loop
- Reuse the multi-agent-compose pattern that's already in place for AILANG-tool sub-agents

### Non-goals

- Replacing motoko's TUI. The TUI continues to be the canonical interactive surface. ACP mode is additive.
- Replacing motoko's profile system with ACP's session model. Profiles continue to drive model/extension selection; ACP sessions wrap a motoko run.
- Making ACP a hard dependency for any existing motoko feature. ACP mode is opt-in (`--acp` flag or `serve-acp` subcommand).

---

## Why this fits motoko better than AILANG

The 2026-05-23 conversation surfaced this clearly. AILANG is a *language* — its job is to be the syntax and runtime that agents are *written in*. Asking AILANG to speak ACP is the wrong layer: it's like asking the Go language to speak gRPC. AILANG's [rejected ACP design doc](https://github.com/sunholo-data/ailang/blob/dev/design_docs/rejected/m-acp-evaluation.md) explains the architectural mismatch and the ~5,000 LOC migration cost.

motoko is the *agent*. ACP is the protocol that connects editors to *agents*. The fit is direct:

| motoko concept | ACP concept |
|---|---|
| `motoko run TASK="…"` interactive loop | An ACP `session/prompt` turn |
| Profile-selected model + extensions | The ACP agent's capability advertisement |
| loop_v2 DP0 (pre-step) emits plan | `session/update: plan` |
| LLM streaming output | `session/update: agent_message_chunk` |
| Tool invocation (DP3) | `session/update: tool_call` |
| Tool completion (DP6) | `session/update: tool_call_update` (status: completed) |
| Pending-policy approval gate | `session/request_permission` |
| Compaction event | `session/update: plan` (refresh) |
| Chain-provenance record | ACP session ID + `session/resume` |
| `max_cost_usd` / `max_steps` trip | ACP stop reason: `max_tokens` / custom |
| Conversation cancelled by user | `session/cancel` → `cancelled` stop reason |

Most of this mapping is mechanical. The novel work is the JSON-RPC plumbing and the registration manifest.

---

## Proposed approach

### Phase 1 — minimal viable ACP agent (~2–3 days)

A single new subcommand `motoko serve-acp` (or `motoko --acp`) that:

1. Reads from stdin / writes to stdout in JSON-RPC line-delimited format (the ACP local transport).
2. Implements the **initialize** handshake — advertises motoko's capabilities (streaming, tool-use, permission-gating, multi-turn).
3. Implements `session/prompt`:
   - Construct a fresh motoko loop_v2 invocation with the active profile.
   - Wire DP hooks to ACP `session/update` notifications. DP0 → plan; LLM stream → agent_message_chunk; DP3 → tool_call; DP6 → tool_call_update.
   - On loop completion, respond with a stop reason derived from the loop's exit cause (`end_turn` for natural completion, `max_tokens` for compaction-failed-context-overflow, `cancelled` for user abort, `refusal` for a tool that refused).
4. Implements `session/cancel` — abort the current loop_v2 turn, emit the cancellation event motoko already has.
5. Implements `session/request_permission` for tool calls when motoko's pending-policy requires human approval. The ACP client (the editor) renders the approval prompt; motoko blocks until the response.

What's deliberately out of scope for Phase 1:

- `session/list`, `session/resume`, `session/close` — these stub-implement against motoko's chain-provenance store but require care for the resume semantics; defer to Phase 2.
- Remote transport (HTTP/WebSocket). Local stdio only.
- ACP Registry submission. Phase 1 ships behind an `--acp` opt-in flag; users wire motoko into Zed by editing their config directly.

**Deliverable:** a developer with motoko installed can add it to Zed's external agents config and have it work end-to-end on a one-turn task.

### Phase 2 — session lifecycle + registry submission (~3–4 days)

- Implement `session/list`, `session/resume`, `session/close` against the chain-provenance store. Sessions persist across CLI invocations.
- Map ACP session IDs to motoko chain IDs bidirectionally.
- Write the ACP manifest (`acp.toml` or equivalent) describing motoko's capabilities, invocation command, and config schema.
- Submit a PR to the [ACP Registry](https://github.com/agentclientprotocol/registry) listing motoko as a community agent.
- Update motoko's README with "Run motoko in Zed / JetBrains / marimo" sections.

### Phase 3 — ACP-as-client (~3–5 days, future)

- Add `ext/acp-subagent` extension. Given an ACP-listed agent ID, spawn it via JSON-RPC and drive it as a multi-agent sub-loop. Tool-call results from the sub-agent flow back into motoko's chain.
- Use case: motoko's multi-agent compose extension could now consume Copilot for codegen, Qwen for refactor planning, motoko for verification — orchestrated as a single chain in the provenance store.

---

## Trade-offs and risks

### Wins

- **Distribution**: motoko shows up in Zed's and JetBrains' agent pickers automatically once registry-listed. Acquisition cost approaches zero.
- **Validation**: the Phoenix-architecture loop runs against a much broader user base than the current TUI-only audience.
- **Standardisation**: tool-call approval, plan reporting, message streaming all use the same wire format as Claude Agent / Gemini CLI / Copilot. Easier to reason about parity gaps.
- **Compositional**: phase 3's ACP-client capability removes per-agent integration code in extensions.

### Risks

- **Surface-area growth**: a new long-lived JSON-RPC server inside motoko, plus session-resume edge cases. Test coverage for protocol-level errors needs deliberate investment.
- **Protocol churn**: wire protocol is v1-stable but the crate (v0.13.x) is still active. Breaking changes possible. Mitigation: pin to a specific protocol version, version-gate features, lag behind by one minor release.
- **Permission model friction**: ACP's `session/request_permission` is *synchronous* — the agent blocks until the editor responds. motoko's pending-policy is more sophisticated (timeouts, auto-approve rules, batch decisions). Need to map cleanly without losing motoko's semantics.
- **TUI/ACP confusion**: two ways to drive motoko — through its own TUI or through an editor's UI. Need clear docs on which one wins which session.
- **Authentication**: ACP has no opinion on how the spawned agent authenticates to its model provider. motoko's profile system handles this, but documentation should be explicit about the env-var flow.

### Why not "wait and see"

Same reason AILANG can revisit at 2026-08-01: ACP momentum is real and accelerating (25+ agents, JetBrains adoption, GitHub Copilot inclusion). The cost of building a motoko ACP adapter when *every* editor already speaks ACP is much lower than the cost of building per-editor integrations later. The Phoenix-architecture autonomy story is also a fundamentally better fit for an "agent that lives in your editor" pitch than for a "standalone TUI you launch in a terminal".

---

## Acceptance criteria (Phase 1)

- [ ] `motoko serve-acp` subcommand exists, reads JSON-RPC from stdin, writes to stdout
- [ ] Initialize handshake completes against Zed's ACP client
- [ ] A one-turn task (`"refactor this function"`) executed via Zed produces correct plan / message / tool-call notifications visible in Zed's panel
- [ ] Tool-use approval flow works for at least one tool that motoko's pending-policy gates
- [ ] `session/cancel` mid-turn correctly aborts motoko's loop and returns the `cancelled` stop reason
- [ ] Smoke test against the JetBrains ACP plugin shows the same one-turn task succeeding
- [ ] README has a "Use motoko in Zed" section with the Zed config snippet
- [ ] CI runs a JSON-RPC golden test against motoko's ACP server (no editor required)

## Acceptance criteria (Phase 2)

- [ ] `session/list`, `session/resume`, `session/close` work end-to-end against chain-provenance
- [ ] motoko listed in the [ACP Registry](https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json)
- [ ] Zed users can install motoko via the in-editor agent picker without editing config

---

## References

- [Agent Client Protocol — introduction](https://agentclientprotocol.com/get-started/introduction)
- [ACP protocol reference (prompt-turn lifecycle)](https://agentclientprotocol.com/protocol/prompt-turn.md)
- [agentclientprotocol/agent-client-protocol (GitHub)](https://github.com/agentclientprotocol/agent-client-protocol)
- [Zed — Agent Client Protocol](https://zed.dev/acp)
- [JetBrains × Zed: Open interoperability for AI coding agents (Oct 2025)](https://blog.jetbrains.com/ai/2025/10/jetbrains-zed-open-interoperability-for-ai-coding-agents-in-your-ide/)
- [ACP Agent Registry Is Live (Jan 2026)](https://blog.jetbrains.com/ai/2026/01/acp-agent-registry/)
- [How the Community is Driving ACP Forward (Zed blog)](https://zed.dev/blog/acp-progress-report)
- [AILANG's rejection of ACP — companion design doc](https://github.com/sunholo-data/ailang/blob/dev/design_docs/rejected/m-acp-evaluation.md) — explains why AILANG (the language) declined ACP and why motoko (the agent harness, one layer up) is a better fit
