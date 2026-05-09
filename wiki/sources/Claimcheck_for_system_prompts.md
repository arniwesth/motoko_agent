# Claimcheck for System Prompt Assembly

## Status: Research — Architecture Decision

## Origin

Claimcheck is a technique from [metareflection/claimcheck](https://github.com/metareflection/claimcheck) (midspiral.com, Feb 2026) that narrows the gap between formal proof and original intent via round-trip informalization: translate the formal artifact back to English, compare against the original spec, flag divergences.

Adapted here from Dafny lemmas to system prompt assembly for the AILANG SWE Agent.

## Problem

The agent's system prompt is assembled from multiple untrusted sources via string concatenation:

```
system  = base_system(cwd) || SYSTEM_MD        -- trusted or user-specified
        ++ with_agents_context(...)             -- AGENTS.md files from disk
        ++ with_cache_hint(...)                 -- SharedMem trajectory hint
```

**AGENTS.md files are untrusted.** They come from the target project's repository, written by different authors for different agents. They may:
- Introduce native file API instructions that contradict `base_system`'s "bash only" rule
- Override the submit sentinel (`COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`)
- Add 500+ lines of project context that bury critical rules under attention pressure

**Cache hints are unvalidated.** A trajectory from a previous run on a different project, or a run that used a different model with different capabilities, gets injected as-is.

**The failure mode is silent.** The agent doesn't crash. It just doesn't behave the way the operator expects. Symptoms look like model quality degradation:
- LLM uses `fs.read()` → the command fails, agent thinks "the environment is broken"
- LLM doesn't emit the submit sentinel → TUI hangs waiting for `done` event
- LLM emits multiple bash blocks → second block is silently discarded

There is currently no validation between assembly and use.

## Approach

Two LLM API calls at session startup, before entering `rpc_loop`:

### Call 1 — Back-translate (cheap model, e.g., Haiku)

```
Given this system prompt, extract every behavioral rule or 
instruction it gives to the model. List each instruction as 
a separate item. Do not add rules that aren't stated.
```

The model does **not** see the intended rules. It must independently derive what the prompt actually says.

### Call 2 — Compare (smarter model, e.g., Sonnet)

```
Intended core rules:
1. Use bash blocks only for commands; no native file API
2. At most one bash block per response
3. Submit with echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT

Rules extracted from the assembled prompt:
[extracted list from Call 1]

For each intended rule, check: PRESENT (explicitly stated), 
WEAKENED (present but softened), CONTRADICTED (some rule says 
the opposite), MISSING (not present).
Report any non-PRESENT matches.
```

Structural separation is critical: Call 1 never sees the intended rules. Call 2 never sees the original base_system — it only sees the extracted list and the intended rules side by side.

## What It Catches

| Scenario | Detection | Severity |
|---|---|---|
| AGENTS.md says "use fs.read() to read files" | CONTRADICTED (item 1) | High — agent will try non-existent APIs |
| Cache hint says "approach used sed -i and direct file writes" | WEAKENED (item 1) | Medium — implies native access is acceptable |
| AGENTS.md defines different submit sentinel ("Say DONE when finished") | CONTRADICTED (item 3) | High — TUI never receives `done` event |
| Multiple AGENTS.md files bury core rules under 10x context | MISSING (all items) | Medium — attention dilution, not explicit contradiction |
| AGENTS.md says "emit multiple bash blocks, one per tool" | CONTRADICTED (item 2) | Medium — silent truncation of extra blocks |

## What It Doesn't Catch

- **Quality.** A prompt can be internally consistent and still be bad. This only checks consistency against the intended core.
- **Unintended additions.** If AGENTS.md adds new instructions that don't contradict anything, they pass through. This is deliberate — we don't want to suppress valid project-specific guidance.
- **Model behavior.** The model can still ignore rules. This validates the prompt text, not the model's compliance.
- **Syntax-level issues.** Malformed prompts that confuse the checker LLM. These are best caught by structural validation (is it valid markdown? is it under the context window?).

## Cost

- **2 LLM API calls** per session startup (sequential)
- **~$0.006** with Haiku (~$0.001) + Sonnet (~$0.005)
- **~5-10 seconds** latency at session start (before rpc_loop)
- **Non-blocking failure.** If the checker times out or errors, the session proceeds unverified — same as today. Logging the failure is sufficient.

## Integration Point

```ailang
-- In swe/rpc.ail: main()

  let system = assemble(...);

  -- NEW: Validate prompt intent before first LLM call
  let violations = check_prompt_intent(system);
  if length(violations) > 0 {
    emit(encode(jo([
      kv("type", js("prompt_warning")),
      kv("violations", violations)
    ])));
  }

  -- Proceed regardless. This is advisory, not fatal.
  let init  = [{ role: "system", content: system },
                { role: "user",   content: task }];
  let state = { ..., msgs: init, ... };
  rpc_loop(state, ...)
```

### New Event Type

```typescript
// tui/src/brain.ts — extend AgentEvent union
type AgentEvent =
  | ...existing...
  | { type: "prompt_warning"; violations: string[] };
```

TUI renders this as a warning banner before session output:
```
⚠ System prompt inconsistencies detected:
  - Rule #1 (bash only): CONTRADICTED — AGENTS.md instructs native file access
  Proceeding anyway. Review AGENTS.md files before the next run.
```

## Implementation Artifacts

| File | Change | Effort |
|---|---|---|
| `swe/intent_check.ail` | **New module.** `check_prompt_intent(system, intended) -> [PromptViolation]`. Two LLM calls, JSON parse, diff. | ~50 lines |
| `swe/types.ail` | New `PromptViolation` type: `{ rule: string, status: string, detail: string }` | ~5 lines |
| `swe/prompts.ail` | New `intended_rules(workdir) -> string` function — returns the canonical directive list for the current workdir | ~15 lines |
| `swe/rpc.ail` | Call `check_prompt_intent` in `main()` after assembly, emit warning event | ~10 lines |
| `tui/src/brain.ts` | Add `prompt_warning` to `AgentEvent` union | ~3 lines |
| `tui/src/ui.ts` | Handle `prompt_warning` — render warning banner in history | ~15 lines |

## Design Decisions

### Advisory, Not Fatal

Violations emit warnings but don't block the session. Reasons:
- The system prompt may still work despite the detected contradiction (the model may ignore the conflicting instruction)
- A blocking failure makes the agent unusable against projects with imperfect AGENTS.md
- The goal is operator awareness, not enforcement

### Intended Rules Are Parameterized

The intended rules list isn't hard-coded — it's `intended_rules(workdir)`, which derives from the base prompt used:
- If `SYSTEM_MD` is set, the intended rules are extracted from that file (the user's own spec)
- If `base_system` is used, the intended rules are the canonical bash-only rules

This means the checker adapts to the context. If a project intentionally overrides the agent's default contract, the checker validates against that override, not against a fixed list.

### Checker Model Selection

The checker uses the same model as the session (or Haiku as fallback for Call 1). Using the session model means:
- No additional provider configuration needed
- The checker inherits the model's rate limits
- If the session model is cheap, the checker is cheap
- If the session model is expensive, the checker cost is justified by the session cost

### Idempotent

Runs once at session start. No per-step checking. The prompt doesn't change during the session (only the conversation history does), so re-checking is unnecessary.

## Alternatives Considered

### Structural Validation (Regex/AST on Prompt)

Check for specific directives using pattern matching rather than LLM back-translation. Cheaper, faster. But misses semantic contradictions (e.g., AGENTS.md says "use native file access" without using the word "file" near "bash"). The whole point of claimcheck is that natural-language comparison catches mismatches that regex patterns miss.

### Block If Violation Detected

Treat contradictions as fatal errors. This is the strictest approach but too aggressive — the operator may want to proceed (the contradiction may be benign in practice, or the operator may be debugging the agent's behavior and needs to observe it).

### Post-Hoc Analysis

Run the checker after the session completes, analyzing the prompt that was used. Catches the issue for next time, but not for the current session. The value is maximal when the operator sees the warning before the first LLM call.

## Future Work

- **Intent envelope extension.** Not just "does the prompt contradict" but "does the prompt cover everything it should?" — completeness checking alongside soundness checking. This would extract what the model is **not** told to do (e.g., "prompt doesn't mention git, but the task requires git operations").
- **Per-layer checksums.** Store hashes of base_system, AGENTS.md content, and cache hint separately. When a violation is detected, attribute it to the specific layer that introduced the conflict.
- **AGENTS.md Lint.** A standalone linter that projects can run in CI to validate their AGENTS.md doesn't contradict standard agent contracts. This is the preventive version — intent checking is reactive.
- **Structured intended rules.** Instead of a flat list of natural-language rules, use a structured format (YAML/JSON) with categories (file access, submission, safety, tool usage). Enables more targeted violation reports.
