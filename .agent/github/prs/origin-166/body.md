---
repo: arniwesth/motoko_agent
pr: 166
branch: arniwesth/mot-100-fix-output-headroom
ticket: MOT-100
title: "MOT-100: reserve provider output headroom"
---

## Summary

Fixes #165 by reserving the 65,536-token upper bound imposed by AILANG's current model-registry
policy when deriving the usable input budget. The effective budget is applied consistently to
pre-step compaction and the final payload seal, while the raw catalog context window remains
available for telemetry and unknown or undersized catalog limits retain the existing fail-open
behavior.

`std/ai` does not currently expose the resolved per-call output budget to Motoko, so the 65,536
reservation mirrors that external AILANG invariant. Models configured below the ceiling are
conservatively over-reserved; if AILANG permits a request budget above it, the resolved budget must
be plumbed into the compaction policy to preserve the admission guarantee.

The regression coverage includes the exact 262,144/65,536 boundary, all three real-driver arms,
and an opt-in bounded scripted provider that independently rejects requests whose estimated input
plus output allowance exceeds its configured context window.

## Changes

- fix(compaction): reserve provider output headroom

10 files changed.

## Governing docs

- [Issue #165](https://github.com/arniwesth/motoko_agent/issues/165) defines the scoped policy,
  boundary case, raw-telemetry requirement, and fail-open controls.
- [Issue #31](https://github.com/arniwesth/motoko_agent/issues/31) is the related upstream
  large-tool-result problem; this PR supplies downstream admission safety for AILANG's current
  output budgets of at most 65,536 tokens, but does not add tool-result truncation or recovery.

## Predicted outcome

- For a 262,144-token model window with a 65,536-token output allowance, compaction and the seal
  now use 196,608 tokens as the input limit. A payload beyond that limit terminates locally with
  `ContextExhausted` instead of preparing a provider call that the provider rejects.
- Safe requests and raw-window telemetry remain unchanged, and unknown (`limit == 0`) or smaller-
  than-reserve catalog limits remain fail-open rather than sealing immediately at 0%.
- Scripted DSTs can opt into provider-realistic capacity checks through
  `bounded_scripted_ports({ context_window, max_output_tokens })`; ordinary scripted ports keep
  their prior behavior.

## Test evidence

```
make compaction_dst  # 8/8 compaction tests; #165 driver/boundary/provider matrix passes
make smoke_driver    # full-loop smoke passes
make check_core      # 57/57 core tests
ailang test src/core/phase_vocab.ail          # 28/28
ailang test src/core/session.ail              # 23/23
ailang test src/core/test/scripted_ports.ail  # 10/10
git diff --check     # clean
```
