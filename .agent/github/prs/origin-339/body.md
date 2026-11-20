---
repo: arniwesth/motoko_agent
pr: 339
branch: arniwesth/044-rsi-fresh-look
ticket: null
title: "docs(044): a fresh look at recursive self-improvement, three models and a synthesis"
---

## Summary

Records a bounded, moderated discussion of how Motoko could reach recursive self-improvement, taking a fresh look from the current code. The participants were Fable 5.2 (Claude Code), GPT-6.2-Astra (Codex) and Gemini 4 Neon (Antigravity), and herdr ran the discussion. Round 1 was blind to the earlier RSI plans; round 2 revealed them and cross-examined; round 3 gave final positions; a check round let each participant correct the synthesis on its own position.

Outcome (`SYNTHESIS.md` §0):
- DST is not the centre of RSI as a whole.
- A shared, zero-model Step 0 comes first: a mechanical, deterministic gate and a qualified item pool.
- Which loop runs first stays open: the oracle set, the checker-repair procedure, or whole-harness competence. Each participant named the Step 0 observation that would settle it.

No decision is recorded; the decisions are listed in §7.

## Changes

- docs(044): a fresh look at recursive self-improvement — three-model discussion and synthesis

16 files changed.

## Governing docs

- `.agent/projects/044_rsi_fresh_look/BRIEF.md`
- `.agent/projects/044_rsi_fresh_look/README.md`
- `.agent/projects/044_rsi_fresh_look/SYNTHESIS.md`
- `.agent/projects/044_rsi_fresh_look/discussion/check/astra.md`
- `.agent/projects/044_rsi_fresh_look/discussion/check/fable.md`
- `.agent/projects/044_rsi_fresh_look/discussion/check/neon.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-1/astra.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-1/fable.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-1/neon.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-2/astra.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-2/fable.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-2/moderator-facts.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-2/neon.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-3/astra.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-3/fable.md`
- `.agent/projects/044_rsi_fresh_look/discussion/round-3/neon.md`

## Predicted outcome

Documentation only. Landing it gives the next RSI step a decision surface, not a plan. The next work item would be Step 0 (`SYNTHESIS.md` §2), with the loop-selection thresholds of §4 fixed before it runs. Two facts in the record correct earlier documents: the AILANG compile-cache limit is now 64 MiB and `src/core/session.ail` caches; and 25–34 historical fix commits revert cleanly at HEAD (`discussion/round-2/moderator-facts.md`).

## Test evidence

No code changed. The moderator's fact checks, at `2eae0666` with AILANG v0.60.4:

```
$ git log --no-merges --grep='^fix' --format=%h -- src/ packages/ | wc -l    -> 123
  clean reverse at HEAD, src/ and packages/ paths only                      -> 34
  clean reverse at HEAD, whole patch                                        -> 25
$ ailang check src/core/session.ail     -> No errors found; 24.8 s cold, 1.7 s rerun, no ARTIFACT_TOO_LARGE
$ grep -n maxArtifactBlobBytes ~/.local/share/ailang/internal/pipeline/cache_artifacts.go -> :38 64 << 20
```

🤖 Generated with [Claude Code](https://claude.com/claude-code)
