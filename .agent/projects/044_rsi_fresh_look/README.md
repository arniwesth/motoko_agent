# 044 — A fresh look at recursive self-improvement

Date: 2026-11-20

Status: Concluded 2026-11-20. A bounded, moderated three-model discussion, orchestrated through
herdr: three rounds, a moderator fact check after round 2, and a check round on the synthesis.
No decision is recorded here; the decisions are listed in `SYNTHESIS.md` §7.

## What this is

Motoko's stated destination is recursive self-improvement (`README.md:14`). Earlier work set a
DST-centred direction (`design_docs/planned/m-motoko-dst-recursive-self-improvement.md`, projects
014, 015, 032, 042). This project asks three models to look again from the current code, first
without those plans (round 1), then against them (round 2).

## Documents

- [BRIEF.md](BRIEF.md) — the question, the rules, the rounds and the turn format every participant
  receives.
- `discussion/round-{1,2,3}/<participant>.md` — the turns, one file each.
- [discussion/round-2/moderator-facts.md](discussion/round-2/moderator-facts.md) — the two factual
  disputes of round 2, settled at the code: fault supply and the compile-cache limit.
- `discussion/check/<participant>.md` — each participant's check of the synthesis.
- [SYNTHESIS.md](SYNTHESIS.md) — the outcome: what converged, Step 0, the three candidate first
  loops, the open disagreements with the observation that settles each, and the decisions for the
  human.

## Participants

| Name | Harness | Model |
|---|---|---|
| `fable` | Claude Code | Fable 5.2, effort xhigh |
| `astra` | Codex | GPT-6.2-Astra, reasoning xhigh, `-s danger-full-access -a never` (021 decision, 2026-08-23) |
| `neon` | Antigravity | Gemini 4 Neon (XHigh) |

Moderator: Claude Opus 5.5. It writes the prompts and the synthesis and takes no position.
