# Recursive Self-Improvement: Motoko + AutoGo

## Summary

The most interesting intersection between AutoGo and Motoko is the **recursive
self-improvement** angle. Both projects share a deep structural parallel: a
closed feedback loop where an agent modifies its own behavior based on measured
outcomes. AutoGo does this at the "train a Go network" level; Motoko can do
this at the "modify your own agent architecture" level.

## The Deep Structural Parallel

AutoGo's core loop: **train policy/value network → self-play → evaluate signal →
train better network.** The network improves its ability to play Go. But the
*meta-game* is: the Claude agent improves its ability to be a Go researcher.

Motoko maps to this exactly, shifted up one level of abstraction:

| AutoGo | Motoko |
|---|---|
| Policy/value network (PyTorch) | Extension hooks (`ExtensionHooks`) in AILANG |
| Self-play → game data | Run tasks → task outcomes / cost data |
| Training loop (`run_iteration.sh`) | Agent loop (`agent_loop_v2.ail`) |
| Loss curves, win rates | Task success rate, cost efficiency, step count |
| Modify model architecture / hyperparams | Modify extension code or hook behavior |
| MCTS evaluation | Verifier mode, tool contracts (`make check_core`) |

## The Key Seam: Motoko's Extension Hook System

Motoko's extension system (`src/core/ext/types.ail`) defines a set of hooks that
constitute the agent's **trainable substrate**. These are the "network weights"
of the agent's behavior:

```
ExtensionHooks = {
  id: string,
  provided_tools: [string],
  on_describe_tools: () -> [ToolSchema],
  on_build_system_prompt: (ExtCtx) -> PromptPatch,
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS},
  on_pre_step: (ExtCtx, [Msg]) -> PreStepDecision,
  on_tool_policy: (ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision,
  on_tool_handle: (ExtCtx, ToolCallEnvelope) -> ToolHandleDecision,
  on_response_intercept: (ExtCtx, string) -> ResponseInterceptDecision,
  on_solver_candidate: (ExtCtx, string) -> FinalizeDecision
}
```

Each hook is a **behavior-modifying function** that Motoko's own tools
(`WriteFile`, `EditFile`) can modify. The hooks control:

| Hook | What It Controls |
|---|---|
| `on_build_system_prompt` | What Motoko tells itself at startup — the "personality" of the agent |
| `on_budget_plan` | How many steps it allocates, solver vs verifier split |
| `on_pre_step` | Compaction — how much context to trim before each AI call |
| `on_tool_policy` | Security gate — which tool calls to allow, deny, or defer |
| `on_tool_handle` | Direct interception — handle a tool call without dispatching |
| `on_response_intercept` | Intercept the assistant's reply before returning to the loop |
| `on_solver_candidate` | Accept, reject, or give feedback on the final answer |

These hooks are loaded at startup from `registry_generated.ail`, which resolves
registered extensions from AILANG packages in `.packages/`. The source files are
regular files on disk. **Motoko already has the tools to read, edit, and write
them.**

## Three Layers of Recursive Improvement

### Layer 1: Motoko as the AutoGo Researcher (Direct Port)

**What it is**: Motoko drives the AutoGo training loop instead of Claude Code.
The task spec says "optimize Go model performance." Motoko runs `bash
experiments/XXXX/run_iteration.sh`, parses `report.md` and `data/*.csv`, and
decides next steps.

**Value**: This tests whether Motoko can sustain a multi-turn ML research
workflow — the same competence AutoGo was designed to study. It becomes a
**benchmark harness** for Motoko's agentic capability.

**Key questions it answers**:
- Does Motoko notice training instability?
- Does it adjust hyperparameters coherently across iterations?
- Does it write sensible analysis and plan the next experiment?
- Does it manage long-running GPU jobs without losing state?

**Status**: This is a behavioral/benchmarking layer. It requires running AutoGo
infrastructure (GPU workers, Docker) but doesn't require any changes to Motoko.

### Layer 2: Motoko Improves Its Own Hooks (The Core Recursive Layer)

**What it is**: Motoko modifies its own extension hooks based on performance
data collected across task runs.

**The loop**:
1. Motoko runs a task batch — say, 50 coding tasks
2. Context-mode indexes all outcomes: pass/fail, tokens burned, tool calls made
3. Motoko analyzes: "The `on_tool_policy` hook is too permissive — BashExec calls
   on large files waste budget. A compaction hook before step 10 would have saved
   tokens on 8/50 tasks."
4. Motoko uses `EditFile` to modify the extension's AILANG source in `.packages/`
5. Motoko runs the same task batch with the modified extension
6. Context-mode compares: did task success improve? Did cost per task drop?

**The mapping**:
- Hooks = network weights
- Task outcomes = training signal (win/loss)
- Edit → evaluate → compare = self-play loop
- The code being modified = Motoko's own runtime behavior

**Concrete example**: Suppose the `on_tool_policy` hook currently allows all
`BashExec` calls. After analysis, Motoko rewrites it to:
```
on_tool_policy(ctx, call):
  if call.tool == "BashExec" and ctx.step > 10 and call.args.cmd contains "find":
    return Deny("use Search tool instead")
  else:
    return Allow
```

This is genuine recursive self-improvement — the agent is changing its own
decision-making rules based on observed performance.

**What makes this tractable**:
- Signal is fast and measurable (success/failure, token count, step count)
- The search space is constrained (7 hooks, each with limited surface area)
- Results are comparable (same task batch before/after)
- The loop can be fully automated (no human in the loop needed for evaluation)
- Existing safeguards: `make check_core` verifies code compiles, verifier mode
  can validate contracts

### Layer 3: Motoko Designs New Extensions

**What it is**: Beyond tuning existing hooks, Motoko generates entirely new
extensions — new AILANG modules implementing `ExtensionHooks` — that encode
learned heuristics.

**The loop**:
1. Motoko identifies a pattern: "Tasks matching regex X always fail at step Y
   because tool Z is misused."
2. Motoko generates a new AILANG module implementing a hook that detects and
   handles pattern X
3. Motoko registers it by editing `registry_generated.ail` and `ailang.toml`
4. Motoko A/B tests old vs. new extension across task suites
5. Motoko iterates based on comparative performance

**AutoGo parallel**: In AutoGo, the Claude agent modifies model architecture
(transformer layers, channel counts, residual connections) and evaluates the
new architecture. Motoko would modify its own **cognitive architecture** —
adding new hooks, changing hook composition, introducing new tool policies.

**Challenges unique to this layer**:
- Generating correct AILANG from scratch is harder than editing existing code
- The extension must compile (`make check_core`) before it can be tested
- Registration requires editing generated file + TOML config — multiple files
- The space of possible extensions is larger and harder to search

## The Concrete Integration Path

```
┌──────────────────────────────────────────────────┐
│ Motoko (agent loop)                              │
│                                                  │
│  ┌──────────┐   ┌──────────┐   ┌─────────────┐  │
│  │ WriteFile │   │ BashExec │   │ CtxExecute  │  │
│  │ EditFile  │   │          │   │ CtxIndex    │  │
│  └─────┬─────┘   └────┬─────┘   └──────┬──────┘  │
│        │              │                │          │
└────────┼──────────────┼────────────────┼──────────┘
         │              │                │
         ▼              ▼                ▼
┌─────────────────────────────────────────────────┐
│ AutoGo harness (optional, for benchmarking)     │
│                                                 │
│  experiments/XXXX/run_iteration.sh              │
│  ├── collect (self-play on GPU workers)         │
│  ├── train (update network weights)             │
│  └── evaluate (win rate vs baseline)            │
│                                                 │
│  → report.md, data/*.csv, figures/*.png         │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│ Context-mode index                              │
│  ctx_index: experiment results                  │
│  ctx_index: hook performance metrics            │
│  ctx_search: "which extension config worked?"   │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
         Motoko analyzes, proposes,
         and edits its own extensions
```

## Why This Matters Beyond the Gimmick

AutoGo's README makes the case that Go is a good domain for studying automated
research because it's "computationally lightweight" while requiring "the core
competencies of AI researchers." The same logic applies to Motoko improving
itself, with additional advantages:

### 1. Signal is fast
Task success/failure, token cost, and step count are measurable on every run.
No need for human evaluation. Every task run produces scalar metrics that can
be compared across extension versions.

### 2. The search space is rich but tractable
Hook composition, tool policies, compaction strategies — there are real
decisions with measurable impact, but the space isn't unbounded. Seven hook
functions, each with a well-defined type signature and constrained side effects.

### 3. It's de-correlated from LLM training
Improving Motoko's agent loop via hook tuning tells us something about agent
architecture that's independent of "just use a better model." This is the same
argument AutoGo makes about Go vs. LLM research.

### 4. The loop genuinely closes
Motoko → edits AILANG → runs tasks → evaluates → edits AILANG → repeat.
This is genuine feedback, not just scripted automation. The agent's own decisions
change its future behavior.

### 5. It's philosophically interesting
The same questions AutoGo raises — "can function approximation replace
simulation?", "is P almost NP?" — have analogues in agent self-improvement:
can an agent with finite reasoning budget improve its own reasoning? Does
self-modification converge or diverge?

## The Hard Parts

### 1. Safe self-modification

If Motoko edits its own hooks and breaks the agent loop, it can't recover.
There needs to be a "known-good fallback" — the equivalent of a model checkpoint
in AutoGo.

**Existing protections**:
- `make check_core` — verifies AILANG compiles before the runtime loads it
- `EditFile.expected_sha256` — guards against stale edits
- Verifier mode — can validate tool contracts

**Gaps**:
- A broken `on_tool_policy` hook that denies all tool calls (including `EditFile`
  to fix itself) would strand the agent irreversibly
- No mechanism for "roll back to last known-good extension state"
- The TS TUI is a separate process; it can't detect a poisoned runtime

**Possible mitigations**:
- A "safe mode" bootstrap: if the runtime fails to start with the current
  extension set, fall back to a minimal built-in set
- Never self-modify all hooks simultaneously — change one at a time
- A watchdog that detects "no tool calls made in N steps" and reverts
- Git-based versioning of extensions with automatic rollback

### 2. Meaningful improvement signal

On AutoGo, the signal is win rate — unambiguous, monotonic (higher is better).

For Motoko, "better" is multi-dimensional:
- Lower cost per task (tokens burned / USD)
- Higher task success rate
- Fewer steps to completion
- Better report quality (subjective)
- Fewer tool call errors (measurable)

The `autoresearch` skill needs a clear scalar metric. Options:
- **Composite score**: weighted combination of success rate and cost
- **Pareto frontier**: optimize for "non-dominated" configurations
- **Task-specific thresholds**: "succeed within budget" as binary metric

### 3. Restart and state continuity

Changing extensions requires restarting the runtime (they're loaded once at
`init_runtime_with_config` in `rpc.ail`).

Context-mode partially bridges this — indexed results survive across sessions.
But:
- The agent identity across restarts needs careful design
- Session-level state (current task, progress) must be persisted
- The "which extension version produced which results" mapping must be tracked

### 4. The bootstrapping question

Who writes the first extension that enables self-improvement? This is the same
problem as "who labels the first batch of Go games" in AutoGo.

**AutoGo's answer**: start with a random policy. Self-play data from random moves
is good enough to bootstrap learning.

**Motoko's analogue**: start with a minimal extension (like the `test_dummy`
extension in `registry_generated.ail` — it exists but does nothing). Let the
agent extend it incrementally based on task performance data from a baseline run
(no extensions, vanilla tool policy).

### 5. Coverage of the hook surface

Not all hooks are equally amenable to self-improvement:

| Hook | Amenability | Reason |
|---|---|---|
| `on_tool_policy` | **High** | Decision is simple (Allow/Deny/NoOpinion/Pending). Impact is measurable (tool call denied = step saved or task broken). |
| `on_pre_step` (compaction) | **High** | Clear metric: tokens saved vs. context lost. Can A/B test compaction strategies. |
| `on_budget_plan` | **Medium** | Simple decision (number), but delayed feedback (entire task must complete). |
| `on_build_system_prompt` | **Low** | Prompt quality is hard to measure. Requires many runs to detect signal. |
| `on_tool_handle` | **Medium** | Direct interception is powerful but risky — can break tool chains. |
| `on_response_intercept` | **Low** | Intercepting model responses is hard to evaluate — what's the counterfactual? |
| `on_solver_candidate` | **Medium** | Accept/continue decision has clear downstream impact (task ends or continues). |

**Recommendation**: Start with `on_tool_policy` and `on_pre_step` — they have
the clearest feedback loops and the lowest risk of catastrophic failure.

## Suggested First Experiment

### Goal
Demonstrate that Motoko can improve its own `on_tool_policy` hook through
measured task performance.

### Setup
1. **Task suite**: 20 small coding tasks with known solutions (e.g., "add a
   function to X.ail and verify it compiles")
2. **Baseline run**: Motoko runs all 20 tasks with the default tool policy
   (Allow all). Record: steps per task, tokens per task, success rate.
3. **Analysis run**: Motoko reads the baseline results from context-mode index,
   identifies patterns (e.g., "ReadFile was called 3x per task when the file
   hadn't changed — Search would have been cheaper"), and proposes a modified
   `on_tool_policy` hook.
4. **Self-modification**: Motoko uses `EditFile` to modify the extension source.
5. **Verification**: Motoko runs `make check_core` to confirm the edit compiles.
6. **Comparison run**: Motoko runs the same 20 tasks with the modified extension.
   Same model, same task prompts.
7. **Analysis**: Compare metrics. Did the modification help? Quantify.

### Success criteria
- Modified hook compiles and doesn't break the agent
- At least one metric (steps, tokens, or success rate) improves measurably
- The improvement is attributable to the specific hook change (not noise)

### Extension
If the first experiment works, add a second iteration: Motoko evaluates the
modified hook's performance and proposes further refinements. This closes the
loop — the agent is now iteratively improving its own architecture.
