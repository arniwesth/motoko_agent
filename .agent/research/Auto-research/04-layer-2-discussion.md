# Proposal: Motoko Layer-2 Recursive Self-Improvement

**Status**: RFC — for discussion  
**Scope**: Motoko agent loop, extension hooks, self-modification  
**Related**: [ericjang/autogo](https://github.com/ericjang/autogo), [.agent/research/Auto-research/](./)

---

## TL;DR

Motoko can already edit its own source code. Its extension hooks are the
"network weights" of the agent — pure functions that control tool policy,
compaction, budget allocation, and response handling. These hooks are regular
AILANG files on disk, and Motoko has the tools to read, edit, and verify them.

This document proposes closing the loop: **Motoko runs tasks → analyzes
performance → edits its own hooks → verifies the changes → runs again → compares.**
The architecture supports this today. The question is whether we should pursue it,
and what safety rails we need first.

---

## 1. The Structural Insight

AutoGo, Eric Jang's experimental codebase, trains Go-playing neural networks
through a self-play loop. But the README is clear: *"This repo is not really
about Go. It is about automating the Go researcher."* The Claude agent driving
AutoGo is the real subject — modifying model architectures, running experiments,
interpreting loss curves, and deciding what to try next.

Motoko has a cleaner version of the same structure, shifted up one level:

| AutoGo trains... | Motoko can train... |
|---|---|
| Policy/value network (PyTorch) | Extension hooks (AILANG) |
| Self-play → game outcomes | Task runs → success/failure + cost |
| `run_iteration.sh` | `agent_loop_v2.ail` |
| Modify model architecture | Modify hook behavior |
| Loss curves, win rate | Task success rate, cost per task |

The key difference: AutoGo's network weights are opaque floating-point numbers.
Motoko's "weights" are **readable AILANG functions** that control the agent's
own decision-making. This makes the feedback loop dramatically faster — you
don't need gradient descent to improve a tool policy; you can literally read
the performance data and rewrite the function.

---

## 2. The Trainable Substrate: Seven Hooks

Motoko's extension system (`src/core/ext/types.ail`) exposes seven hooks. Each
one is a function that the agent loop calls at a specific point. Each one is a
candidate for self-modification:

| Hook | What it controls | Self-improvement amenability |
|---|---|---|
| `on_tool_policy` | Allow/deny/defer individual tool calls | **High** — decisions are simple, impact is immediate and measurable |
| `on_pre_step` | Compaction — trim context before each AI call | **High** — clear metric: tokens saved vs. context lost |
| `on_budget_plan` | How many steps to allocate | Medium — simple decision, delayed feedback |
| `on_tool_handle` | Intercept and directly handle tool calls | Medium — powerful but risky |
| `on_solver_candidate` | Accept/reject/feedback on final answer | Medium — clear downstream impact |
| `on_build_system_prompt` | What Motoko tells itself at startup | Low — prompt quality is hard to measure |
| `on_response_intercept` | Intercept model output mid-stream | Low — no clear counterfactual for evaluation |

The dispatch is already wired. Every step of the agent loop calls these hooks
in order (see `agent_loop_v2.ail`). The hooks are loaded at startup from
`registry_generated.ail`, which resolves them from AILANG packages in
`.packages/`. Those are regular files. Motoko can read them, edit them, and
verify them with `make check_core`.

---

## 3. The Proposed Loop (Layer 2)

### Step by step

1. **Baseline**: Motoko runs a batch of N tasks (say, 20 small coding tasks with
   known solutions). All hooks are in their default state. Context-mode indexes
   outcome data: success/fail, steps taken, tokens burned, which tools were
   called and when.

2. **Analysis**: In a separate session, Motoko reads the baseline data from
   context-mode's index. It identifies patterns — e.g., "ReadFile was called
   3× per task when the file hadn't changed since the last read," or "BashExec
   `find` calls in steps 8+ always waste budget compared to using Search."

3. **Proposal**: Motoko proposes a targeted edit to one hook. For example,
   modifying `on_tool_policy` to deny redundant `ReadFile` calls when the file's
   SHA-256 hasn't changed, or to redirect `find` invocations to the `Search`
   tool after step 10.

4. **Self-modification**: Motoko uses `EditFile` to apply the change to the
   extension's AILANG source in `.packages/`.

5. **Verification**: Motoko runs `make check_core`. If the edit doesn't compile,
   the loop stops here — the agent doesn't load broken code.

6. **Comparison**: Motoko runs the same N tasks with the modified hook. Same
   model, same task prompts. Context-mode indexes the new results alongside the
   baseline.

7. **Evaluation**: Motoko compares metrics. Did the change improve anything?
   Steps per task? Tokens per task? Success rate? If yes, the change is kept.
   If no, it's reverted. Either way, the evidence is indexed for future
   reference.

### Concrete example

**Before** (default `on_tool_policy` — always returns `Allow`):
```
Task: "Find where ErrorCode is defined in the codebase"
  Step 1: BashExec find . -name "*.ail" | xargs grep ErrorCode  →  847 tokens
  Step 2: ReadFile src/errors.ail  →  312 tokens
  Total: 2 steps, 1,159 tokens
```

**After** (modified `on_tool_policy` — redirects `find` + `grep` to `Search`):
```
Task: "Find where ErrorCode is defined in the codebase"
  Step 1: Search pattern="ErrorCode"  →  89 tokens
  Total: 1 step, 89 tokens
```

The modified hook saved 1 step and 1,070 tokens. Over 20 tasks with similar
patterns, that's real savings — and the agent discovered the optimization
itself by analyzing its own behavior.

### What makes this "recursive"

This isn't just automation. The agent is modifying the code that controls how
the agent makes decisions. Tomorrow's Motoko behaves differently because today's
Motoko observed itself and changed its own rules. The feedback is genuine: task
outcomes are the training signal, hook edits are the parameter updates, and the
AILANG type-checker is the gradient guard.

---

## 4. Why This Is Tractable

### Signal is fast and cheap

Task success/failure, token cost, and step count are scalar metrics available
after every run. No human evaluator needed. No multi-GPU training run needed.
A batch of 20 coding tasks runs in minutes and produces clean before/after data.

### The search space is constrained

Seven hooks. Each with a well-defined type signature. The decisions are
structurally simple: Allow/Deny/NoOpinion for tool policy, Compacted/PassThrough
for pre-step, integer adjustments for budget. This isn't searching the space of
all possible Python programs — it's tuning a small set of discrete parameters
with clear semantics.

### The architecture already supports it

This isn't a "first we need to build X" proposal. The hooks exist, the dispatch
exists, the tool surface for self-modification exists (ReadFile, EditFile,
WriteFile, BashExec for `make check_core`). Context-mode persists data across
sessions. The loop can be demonstrated today.

### It's de-correlated from model capability

Better hooks help regardless of the underlying model. A tool policy that
redirects `find | grep` to `Search` saves tokens whether the model is
Claude Opus or a small open-weight model. This means improvements found through
self-modification are *architectural* improvements to the agent, not just
reflections of a better LLM.

---

## 5. The Hard Parts (Honest Assessment)

### 5.1 Safe self-modification

**The problem**: If Motoko writes a broken `on_tool_policy` that denies all tool
calls — including `EditFile` to fix itself — the agent is stranded. There is
currently no rollback, no watchdog, and no "safe mode" bootstrap.

**Mitigations**:
- **Git checkpointing**: `git stash` before any self-modification. If the agent
  breaks, manual recovery is `git stash pop`.
- **Tool-policy escape hatch**: Never deny `ReadFile`, `EditFile`, `WriteFile`,
  or `BashExec` unconditionally. Always leave a path for self-repair.
- **Bootstrap extension**: A minimal extension loaded first in the chain that
  guarantees core tools are always available — the "recovery partition."
- **`make check_core` as gate**: Type-check before loading. The AILANG compiler
  catches many classes of errors before the runtime ever loads the code.

### 5.2 Meaningful improvement signal

**The problem**: "Better" is multi-dimensional. Lower cost? Higher success rate?
Fewer steps? These can trade off against each other.

**Proposed approach for initial experiments**: Use a **composite score**:
`success_rate × 100 - cost_per_task_millicents / 1000`. This rewards succeeding
more often and penalizes expensive runs. It's crude, but it's scalar and
unambiguous — exactly what a first experiment needs. More sophisticated metrics
can evolve once the basic loop works.

### 5.3 Restart and state continuity

**The problem**: Changing hooks requires restarting the runtime (hooks are loaded
at init). Session-level state is lost across restarts.

**Mitigation**: Context-mode already persists indexed data across sessions. The
"which extension version produced which results" mapping must be tracked
explicitly — either through a naming convention on indexed sources, or through
a lightweight experiment manifest file that Motoko writes before each run.

### 5.4 The bootstrapping question

**The problem**: Who writes the first hook that Motoko can improve?

**Answer**: Start from the default state — `test_dummy`, which is a no-op
extension that always returns neutral decisions (NoOpinion, NoIntercept,
NoDecision). The baseline run uses no policy modifications. The analysis step
identifies *opportunities* to add policy — things the agent currently does that
waste steps or tokens. The first edit is additive: "I notice I keep doing X,
so I'll add a rule to stop doing X."

This is exactly AutoGo's bootstrapping strategy: start with a random policy
and let self-play generate the signal that drives improvement.

---

## 6. Proposed First Experiment

### Goal

Demonstrate that Motoko can improve a single hook (`on_tool_policy`) through
measured task performance, and that the improvement is measurable and
attributable.

### Design

1. **Task suite**: 20 small, self-contained coding tasks (e.g., "add a function
   to X.ail," "find all callers of Y," "fix the type error in Z"). Each has a
   clear, verifiable success criterion.
2. **Baseline**: Run all 20 with neutral hooks. Record steps, tokens, success.
   Index everything in context-mode.
3. **Analysis session**: Motoko reads the baseline index, identifies at least one
   pattern where a policy rule could improve efficiency.
4. **Edit session**: Motoko applies the edit, verifies with `make check_core`.
5. **Comparison**: Run the same 20 tasks with the modified hook.
6. **Report**: Motoko writes a comparison report (steps saved, tokens saved,
   success rate delta) and indexes it.

### Success criteria

- The modified hook compiles (`make check_core` passes)
- The agent completes all 20 tasks without hitting a policy-induced deadlock
- At least one of {mean steps, mean tokens, success rate} improves measurably
  relative to baseline
- The improvement direction is correct — no metric regresses severely

### What we learn

If this works, we've demonstrated the core loop. The next step is iteration:
Motoko evaluates the modified hook's performance and proposes further
refinements. If it doesn't work, we learn which part of the loop is the
bottleneck — the analysis quality, the edit precision, the metric, or the
safety constraints.

---

## 7. Open Questions for Discussion

1. **Safety first?** Should we build the git-checkpointing + bootstrap-extension
   safety rails before attempting any self-modification, or is `make check_core`
   + manual recovery enough for a first experiment?

2. **Which hook first?** `on_tool_policy` has the clearest feedback loop and
   lowest risk. But `on_pre_step` (compaction) could have larger token savings.
   Which should the first experiment target?

3. **Metric design**: Is the composite score (`success_rate × 100 - cost / 1000`)
   good enough for iteration 1, or should we think harder about the objective
   function before starting?

4. **Human in the loop?** Should the first experiment have a human gate between
   "Motoko proposes an edit" and "Motoko applies the edit"? This would slow the
   loop but eliminate the stranded-agent risk.

5. **Extension scope**: Should self-improvement be scoped to a dedicated
   `self_improve` extension that is the *only* hook the agent modifies, keeping
   production extensions untouched? This would contain blast radius.

6. **Benchmarking**: Could we use AutoGo itself as one of the tasks in the task
   suite? Motoko driving the AutoGo training loop would be a strong signal that
   the agent can sustain multi-turn ML research.

---

## References

- [AutoGo repository](https://github.com/ericjang/autogo)
- [01-autogo-analysis.md](./01-autogo-analysis.md) — Full AutoGo analysis
- [02-recursive-self-improvement.md](./02-recursive-self-improvement.md) — Full three-layer analysis
- [03-hook-reference.md](./03-hook-reference.md) — Technical hook reference
- `src/core/ext/types.ail` — ExtensionHooks type definition
- `src/core/ext/runtime.ail` — Hook dispatch and merge logic
- `src/core/agent_loop_v2.ail` — Agent loop calling dispatch functions
