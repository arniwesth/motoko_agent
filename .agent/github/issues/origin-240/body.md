---
repo: arniwesth/motoko_agent
issue: 240
title: "compaction_ai: a fixed token threshold beside threshold_pct, so a 1M-window model compacts before 737k tokens"
---

## Summary

`compaction_ai` triggers on a percentage of the context window (`threshold_pct`, 75 in all 14
profiles that carry a `compaction_ai.json`). On a 1M-window model that is about 737k tokens, far past the point where a
long session's cost hurts. This asks for an optional fixed threshold in tokens beside the
percentage, so a cost-sensitive profile can say "compact at 150k" without lying about the window.

It is suggestion 3 of #237, split out because it is a different problem from that issue's title:
it applies to models whose limit is known.

## Context

**Where 75% falls.** A compactor does not see the raw window. `session.ail` hands it
`working_budget_for_ext(limit, pinned_tokens)`, which is the window minus the 65,536-token output
reservation minus the pinned system prefix. So for the windows in `.motoko/model-catalog.json`:

| raw window | working budget (before the pinned prefix) | `threshold_pct: 75` fires at |
|---|---|---|
| 262,144 | 196,608 | 147,456 |
| 1,048,576 | 983,040 | 737,280 |
| 2,000,000 | 1,934,464 | 1,450,848 |

**The measured run** (#237, 2026-10-08, `z-ai/glm-5.3-flash`, one 3-file bug fix): 157 steps,
context from 3k to 260k tokens, 26.3M input tokens in total, 98% of them cache reads, about $0.92.
That run had no window at all. #238 has since catalogued the model at 1,048,576, and #239 (a
draft) makes an unknown window visible. Neither changes this run's cost: at 260k it is still 477k
tokens short of the 737k trigger.

**The workaround, and what it costs.** The reporter's fleet sets `agent.context_limit: 262144` in
its profiles. That moves the trigger to about 147k, and it also moves everything else that reads
the window:

- the payload seal (`phase_vocab.seal_compacted_payload`) fails the run with
  `compaction_exhausted` when the compactor chain cannot bring the payload under 95% of the
  declared window minus the reservation. That is about 187k tokens here, on a model that has 1M,
  so a run the real window would have carried can be ended;
- the status tool's percentages and `compaction_structural`'s fixed tiers (70 / 85 / 95%) are all
  taken against the false window.

So the only cost knob there is today is a wrong statement about the endpoint.

**Why it is more than one config key.** `compaction_ai` reads the window in five places, all in
`packages/motoko-ext-compaction-ai/compaction_ai.ail`:

| where | what it does with the window |
|---|---|
| `compact_with_ai` | the trigger: `usage_percent(...) < cfg.threshold_pct` passes through |
| `fresh_compaction` | skips the summarizer when the projected relief is under `min_relief_pct` |
| `finalize_compaction` | rejects a summary that leaves the percentage higher than before |
| `max_fold_tokens` | caps one fold at half the working budget |
| `compact_with_ai`, cached branch | forces a refresh at `hard_override_pct` of the window |

With a known window, only the first needs to change: the other four keep working in percent.
With an unknown window every one of them reads 0, so a token trigger alone would fire and then
stop at "insufficient relief" (0 − 0 < 5). Making compaction work without a window is a larger
change, and it is the "behaviour under `Unknown`" that 013 ADR-001 leaves undecided.

**Config surface.** `compaction_ai.json` per profile, decoded by `types.config_of_json`, where
every key is optional and a missing one takes the default. A new key is additive: a profile that
does not set it decodes to the same record as today.

## Expected

- **A new optional key**, for example `threshold_tokens` (0 or absent: off). With a known window,
  `compaction_ai` compacts when the calibrated input estimate reaches `threshold_tokens` or
  `threshold_pct` of the working budget, whichever comes first.
- **No change for a profile that does not set it.** The compaction DST targets and their goldens
  do not move.
- **Check:** a fixture on a 1M window with `threshold_tokens: 150000` compacts at the first step
  whose calibrated estimate is at or above 150k, and passes through below it. The same fixture
  without the key first compacts at 737k. `long_qwen_compaction_dst` already drives
  `compact_with_ai` with its own config and is the natural home.
- **Decide, and say in the docs, what the key does when the window is unknown.** The two honest
  answers are "nothing, and the #239 warning says compaction cannot run" and "compaction runs on
  tokens alone", which needs token forms of the other four reads above and a decision under
  ADR-001. The first is the smaller change.
- **Say whether `compaction_structural` gets the same key.** Its tiers are constants today, not
  config. Leaving it percentage-only is defensible: it is the safety net, and `compaction_ai` runs
  before it in the chain.
- `docs/configuration.md` documents the key next to `agent.context_limit`, and says that the
  window is for describing the endpoint and the threshold is for controlling cost.
