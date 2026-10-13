---
repo: arniwesth/motoko_agent
pr: 265
branch: fix/compaction-status-from-folded-segment
ticket: null
title: "fix(compaction_ai): read the capsule's runtime status from the folded turns only"
---

## Summary

After a fold, `compaction_ai` re-applies its summary message on every request. #262 removed the
step number from that message, because it changed on every step and broke the provider's prompt
cache. One request-dependent part was left: the status section. It was read from the whole
history, verbatim tail included, so each new `MotokoRuntimeStatus` result rewrote the summary
message and cost one cache miss from the summary onward.

The status is now read from the folded turns only. A result in the tail is sent verbatim anyway.
The heading becomes `LATEST RUNTIME STATUS IN SUMMARIZED TURNS`, because a newer result can now
follow in the tail.

**Stacked on #262.** Until that merges, the diff shows its commits too. This pull request's own
change is the last two commits.

## Changes

- fix(compaction_ai): read the capsule's runtime status from the folded turns only
- chore: re-lock after the compaction_ai change

3 files changed by those two commits: `packages/motoko-ext-compaction-ai/compaction_ai.ail`,
`scripts/dst/long_qwen_compaction_dst.ail` and `ailang.lock`.

**One trade-off to rule on.** Before, the capsule carried an excerpt of the latest status wherever
that status was. Now a status result in the tail exists only as its own tail message. Structural
compaction cuts a tool result older than the last `keep_last` to its first 80 characters, so under
pressure the model can be left with a cut copy until the next fold moves the result into the
folded turns. I judged that acceptable: the result is small, its first 80 characters hold the
step, and the tool can be called again. Say if you would rather keep the mirror and accept the
cache miss.

## Governing docs

- `.agent/projects/006_compactor_strategy/PLAN-compaction-control-capsule.md`: the capsule's
  format. Its §2.2 says to find the latest status "in `msgs` before splitting"; this narrows that
  to the folded turns. The test it asks for, a status call and result outside the preserved tail
  that stay in the summary, still holds and is tested. The record is not edited here, and it still
  shows the step line that #262 removes.

## Predicted outcome

- A run that calls `MotokoRuntimeStatus` after a fold no longer loses the prompt cache on the
  request after each status call. This is not measured against a provider. What is checked is the
  cause: the summary message is identical before and after a status result arrives in the tail.
- A run that never calls the tool sends the same status section as before, "not observed in
  compacted segment", under the new heading.

## Test evidence

On `main` @ `15922ebf` merged with #262 @ `1ce24066`, AILANG v0.52.5:

```
ailang test packages/motoko-ext-compaction-ai/compaction_ai.ail   13 tests: 13 passed (two new)
make compaction_dst_long_qwen                                     long_qwen_compaction_dst PASS count=12
make compaction_dst_policy, _catalog, _runtime_status, _cursor_probe   exit 0 each
make verify_extensions                                            verify_extensions (default): 9 booted, 0 failed
```

With the old read put back (`latest_runtime_status_result(msgs)`):

```
ailang test ...                 ✗ test_status_result_in_tail_leaves_summary_unchanged (12 of 13 pass)
make compaction_dst_long_qwen   long_qwen_compaction_dst FAIL failed=1
  scenario=compaction.compaction_ai_artifact_cache_stable seed=fixed
    invariant=a status result in the tail leaves the re-applied summary unchanged
  trace decision=compaction_ai.output_not_relieving
```

The scenario fails through `output_not_relieving` and not through the comparison: at the
fixture's 100-token limit, the added excerpt makes the compacted request larger than the original.
The inline test fails on the comparison itself. CI runs the scenario and does not run the inline
tests.

`compaction_ai_hostile_summary_control_capsule`, which needs a status result from the folded turns
to appear in the capsule, still passes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
