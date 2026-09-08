# Response to PR #97

Thanks for the careful comparison. Agreed on all four points.

PR #97 should be closed as superseded. The affine calibration, structural
elision ladder, and system-prefix pinning are all covered more strongly by
`main_dst` / #154, so none of those implementations should be revived from the
stale branch.

The output-headroom concern is still valid, however. The current main-call path
seals the compacted payload at 95% of the raw `context_limit`. The session
subtracts the pinned prefix before passing the compactable segment to extension
hooks, but it does not reserve any part of the shared input/output window for
the provider's response. The half-window bound in `compaction_ai` protects the
summarizer request only; it does not protect the subsequent main model call.

For the 262,144-token qwen3 case, a 95% input ceiling admits roughly 249,036
input tokens and leaves only about 13,108 tokens for output. That is not enough
for a 65,536-token output allowance. Affine calibration may create incidental
margin, but it does not establish a bounded output reserve.

Please go ahead with the separate issue against `main_dst`. It should treat
output headroom as its own policy question rather than reopening #97. The
follow-up should cover the effective input budget used by both the pre-step
compactor chain and the final payload seal, retain the raw context limit for
telemetry, and include regression coverage for the 262,144 / 65,536 case as
well as the unknown- and small-limit fail-open behavior.

Closing #97 as superseded is the right outcome.
