---
repo: arniwesth/motoko_agent
pr: 276
branch: docs/009-ailang-world-overlap-update
ticket: null
title: "docs(009): revise the AILANG World overlap note to World v1.0.0-rc.1"
---

## Summary

The July note reviewed `sunholo-data/ailang-world` at `03efeef`, before its store, daemon, effect broker and protocol boundary existed, and World's own REFERENCES.md now says the note's first revisit trigger has fired and a boundary review is due on both sides. This revision is the Motoko-side half of that review. It reviews World's `dev` at `a0c73053` (2026-10-17), the state behind the `v1.0.0-rc.1` pre-release, keeps the layer ruling that World adopted on 2026-07-31, and records what changed on both sides since July. Docs only; no source changes.

## Changes

- docs(009): revise the AILANG World overlap note to World v1.0.0-rc.1

1 file changed.

- **Conclusion**: the ruling stands; three consequences of World now existing are stated up front.
- **What changed since July** (new): a table for World (AILANG surface, store and daemon, broker with the exact `EffectRecord` fields, handler set, effect journal and indeterminate receipts, replay engine, interpreter pin, MCP/A2A sessions and episodes, Motoko's demotion to an optional floor arm, the 2026-10-15 floor verdict, rc.1) and a list for Motoko (recorded-stream adoption on 2026-08-05, the version-string `toolchain` manifest field, the AILANG pin mismatch, the `mcp` extension's HTTP bridge).
- **Comparison**: World column updated from plans to what exists; a receipts row added.
- **Integration shapes**: the July "candidate shape" becomes Route A (Motoko as a World resident through the existing `mcp` extension, possible on paper, untested, with four preconditions) and Route B (the `AilangWorldLiveAdapter`, blocked on World recording ordered emissions, a gap World's REFERENCES.md names).
- **Reuse opportunities**: the July typed-envelope field list checked field by field against World's record objects; the artifact-identity recommendation kept, now with World's `host/replay` as the worked precedent; a receipts section pointing at project 034.
- **The replay primitive, revisited**: `ailang replay` still ships in v0.52.5; World does not use it; neither provides the DST contract.
- **Terminology**: World adopted the July rule; "session" and "replay" added as collisions.
- **Revisit triggers**: triggers 1 and 3 marked fired, 2 and 4 not; six new triggers.
- **Sources** (new): every World link pinned to `a0c73053`.

## Governing docs

- `.agent/projects/009_motoko_dst_execution/NOTE-ailang-world-overlap.md`
- `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` (the note is its informational companion; its cross-reference to the note is unchanged and still accurate)
- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md` (the note asks that its disclosure classes be checked against World's four receipt states)

## Predicted outcome

- Nothing executable changes.
- A reader of ADR-001 gets a current description of World's broker contract, replay engine and interpreter pin instead of a July description of plans, and two integration routes with their blockers named.
- **How that will be checked:** at the next revisit, against the ten triggers at the end of the note. Trigger 5, ordered intermediate emissions in World's effect records, is the one that unblocks Route B. Trigger 7, unattended session minting, is the one that makes Route A automatable.

## Test evidence

Run on 2026-10-18 from the worktree:

- Every GitHub link in the note pinned to `a0c73053` returns HTTP 200: 13 raw file URLs (README, DESIGN.md, REFERENCES.md, world-mission.md, the two broker design docs, `record.go`, `broker.go`, `handlers_model.go`, `replay.go`, `types.ail`, `pins/ailang-releases.json`, the floor FINAL README). The 4 docs-site pages and the upstream `motoko-mission.md` also return 200.
- Every local path the note cites exists in the worktree (9 paths).
- Claims about World were read from those fetched sources, not from memory: `EffectRecord` fields from `host/broker/record.go`; the effect names from `host/broker/handlers*.go`; `Model.Infer` returning one result from `host/broker/handlers_model.go`; the replay engine's steps from the `host/replay/replay.go` package comment; pins from `pins/ailang-releases.json`; the floor numbers from the FINAL README.
- Claims about Motoko: `ailang --version` prints v0.52.5 and `ailang replay --help` lists `-caps`, `-entry`, `-file`, `-json`, `-quiet`; `packages/motoko-ext-mcp/assets/mcp-call.mjs` builds a JSON-RPC `tools/call` body, sends `Accept: application/json, text/event-stream` and a `Bearer` header, and parses SSE or plain JSON; `src/core/dst_profile.ail` carries `toolchain` as a string; the D1 gate rows are in `NOTE-c1-c2-execution-report-and-plan-corrections.md`.
- No trailing whitespace in the file. No `.ail` source is touched, so `make check_core` was not run.

Not run: no World daemon was started. The Route A compatibility claim is read from source on both sides, and the note says so.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
