# M-MOTOKO-TUI-INTERACTIVE-ENHANCEMENTS

## Summary

Three TUI enhancements to improve interactive control and observability:
1. **Shell escape** - Execute shell commands from the prompt box with `!` prefix
2. **Mid-conversation steering** - Send user prompts that interrupt/steer the agent during execution
3. **Cost indicator** - Real-time token/cost display in the status bar

## Motivation

### Shell Escape (`!command`)

Currently, checking a file or running a quick shell command requires:
1. Wait for agent to finish current task
2. Type a new message asking agent to run the command
3. Wait for agent response

This is friction-heavy for quick lookups like:
- `!git status` - check current branch/state
- `!ls src/` - explore directory structure
- `!cat package.json` - peek at a file
- `!gh pr view 16` - check PR status

Claude Code supports this pattern and it's proven useful for developer flow.

### Mid-Conversation Steering

Currently, users must wait for the agent to complete each turn before providing input. This prevents:
- Correcting a wrong assumption mid-execution
- Providing additional context that occurred to the user
- Steering the agent away from a bad path before it wastes tokens
- Answering clarification questions immediately

Claude Code and other interactive agents support "streaming input" where the user can type while the agent is working, and the input is queued/processed at the next decision point.

### Cost Indicator

Motoko can spend significant tokens on long tasks. Users need visibility into:
- How many tokens have been consumed
- Estimated cost in dollars/cents
- Rate of consumption (tokens/step)

This enables informed decisions about:
- Whether to continue or abort a task
- Whether to switch to a cheaper model
- Budget tracking for client work

## Current Architecture

### Input Flow (Blocking)

```
src/tui/src/index.ts:
  userInput = await ui.getInput()  // BLOCKS until user submits
  runtimeProcess.send(userInput)
  // ... wait for agent response ...
  userInput = await ui.getInput()  // Next input only after response
```

The `getInput()` call blocks on `readline` or UI event, and the agent runs to completion before the next input is accepted.

### Status Bar

```
src/tui/src/ui.ts:
  renderStatusBar(model, step) {
    // Shows: model name, step count
    // No token/cost display
  }
```

### Message Flow

```
User Input → TUI (stdin) → AILANG Runtime → Tool Calls → Response
     ↑                                                      ↓
     └────────────── Only after response complete ──────────┘
```

## Proposed Design

### 1. Shell Escape (`!command`)

**Mechanism:**
1. User types `!ls -la src/` in prompt box
2. TUI detects `!` prefix before sending to runtime
3. TUI executes command locally via `child_process.execSync()`
4. Output displayed in a dedicated pane or inline
5. No message sent to AILANG runtime (purely local)

**Implementation:**

```typescript
// src/tui/src/commands.ts
export function parseShellEscape(input: string): { isShell: boolean, command: string | null } {
  if (input.startsWith('!')) {
    const command = input.slice(1).trim();
    return { isShell: true, command };
  }
  return { isShell: false, command: null };
}

export async function executeShellCommand(command: string): Promise<ShellResult> {
  const { exec } = require('child_process');
  return new Promise((resolve) => {
    exec(command, { cwd: process.cwd() }, (error, stdout, stderr) => {
      resolve({
        command,
        stdout: stdout.toString(),
        stderr: stderr.toString(),
        exitCode: error ? 1 : 0
      });
    });
  });
}
```

**UI Integration:**

```typescript
// src/tui/src/index.ts
async function handleUserInput(input: string) {
  const shellEscape = parseShellEscape(input);
  
  if (shellEscape.isShell && shellEscape.command) {
    // Execute locally, don't send to runtime
    const result = await executeShellCommand(shellEscape.command);
    ui.showShellResult(result);  // Display in pane or inline
    return;  // Don't send to agent
  }
  
  // Normal message to agent
  runtimeProcess.send({ type: 'user_message', content: input });
}
```

**Display Options:**

Option A: Inline output (like Claude Code)
```
User: !ls src/
> src/
  core/
  tui/
  scripts/
  
User: [continue typing next prompt]
```

Option B: Dedicated shell pane
```
┌─────────────────────────────────┐
│ [Chat Pane]                     │
│ Agent: I'll help you with...    │
│                                 │
├─────────────────────────────────┤
│ [Shell Output]                  │
│ $ ls src/                       │
│ core/  tui/  scripts/           │
│ (exit: 0)                       │
├─────────────────────────────────┤
│ > [input box]                   │
└─────────────────────────────────┘
```

**Security Considerations:**
- Commands run in the same environment as the TUI process
- User has same permissions as the TUI process
- No additional sandboxing needed (user is in control)
- Consider: Add confirmation for destructive commands (`!rm -rf`)

### 2. Mid-Conversation Steering

**Mechanism:**
1. While agent is streaming/working, user types in input box
2. Input is NOT blocked - user can type anytime
3. On Enter, message is queued to a "pending inputs" buffer
4. Agent checks for pending inputs at decision points:
   - After each tool call result
   - Before next step
   - On streaming pause
5. If pending inputs exist, agent processes them before continuing

**Implementation:**

```typescript
// src/tui/src/runtime-process.ts
export class RuntimeProcess {
  private pendingInputs: string[] = [];
  
  // Called from UI thread anytime
  queueInput(input: string): void {
    this.pendingInputs.push(input);
    // Send to runtime as "steering" message
    this.send({ 
      type: 'steering_message', 
      content: input,
      timestamp: Date.now()
    });
  }
  
  // Called by runtime when checking for steering
  getPendingInputs(): string[] {
    const inputs = [...this.pendingInputs];
    this.pendingInputs = [];
    return inputs;
  }
}
```

**AILANG Runtime Integration:**

```ailang
// src/core/agent_loop_v2.ail

-- In conversation_loop_v2, check for steering messages between steps
func check_steering_messages() -> Option[string] {
  -- Poll stdin for any queued steering messages
  match try_read_steering() {
    None => None,
    Some(msg) => Some(msg)
  }
}

-- In the main loop
let steering = check_steering_messages();
match steering {
  Some(user_input) => {
    -- Inject as user message, continue conversation
    let updated_history = history ++ [User(user_input)];
    conversation_loop_v2(updated_history, ...)
  },
  None => {
    -- Normal step continuation
    let result = step(model, messages, tools);
    ...
  }
}
```

**UI Patterns:**

Pattern A: Immediate interrupt
- User input immediately stops current streaming
- Agent state is preserved
- New input injected as user message
- Agent continues with updated context

Pattern B: Queued steering (safer)
- User input queued while agent works
- Agent checks queue at safe points
- Less disruptive to agent state

**Recommended: Pattern B (Queued Steering)**

This is safer because:
- Agent finishes current tool call
- State is consistent
- No risk of interrupting file writes
- Easier to implement

**Display:**

```
┌─────────────────────────────────┐
│ [Chat Pane]                     │
│ Agent: Let me read that file... │
│ [reading src/config.ts...]      │
│                                 │
│ User (steering): actually,      │
│   check src/config.prod.ts      │
│                                 │
│ [⚡ Steering message queued]    │
│                                 │
├─────────────────────────────────┤
│ > [input box - always active]   │
└─────────────────────────────────┘
```

### 3. Cost Indicator

**Data Sources:**

AILANG runtime already tracks:
- Input/output tokens per step
- Cost per model (from `ailang.toml` `[ai_provider].cost`)
- Cumulative session totals

These are emitted in JSONL events:
```json
{"type": "step_complete", "tokens": {"input": 1234, "output": 567}, "cost_usd": 0.0234}
{"type": "run_summary", "total_tokens": {"input": 50000, "output": 12000}, "total_cost_usd": 1.50}
```

**Implementation:**

```typescript
// src/tui/src/ui.ts
interface CostState {
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
  currentModel: string;
  stepNumber: number;
}

export class UI {
  private costState: CostState = { ... };
  
  updateCost(event: StepCompleteEvent): void {
    this.costState.inputTokens += event.tokens.input;
    this.costState.outputTokens += event.tokens.output;
    this.costState.costUsd += event.cost_usd;
    this.costState.stepNumber++;
    this.renderStatusBar();
  }
  
  renderStatusBar(): void {
    const { inputTokens, outputTokens, costUsd, currentModel, stepNumber } = this.costState;
    
    // Format cost
    const costStr = costUsd >= 1.0 
      ? `$${costUsd.toFixed(2)}`
      : costUsd >= 0.01
        ? `$${costUsd.toFixed(3)}`
        : `${(costUsd * 100).toFixed(1)}¢`;
    
    // Format tokens
    const tokensStr = formatTokens(inputTokens + outputTokens);
    
    // Status bar line
    const status = `Model: ${currentModel} | Step: ${stepNumber} | Tokens: ${tokensStr} | Cost: ${costStr}`;
    
    // Render at bottom of screen
    this.writeToStatusBar(status);
  }
}

function formatTokens(n: number): string {
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
  return `${n}`;
}
```

**Display Layout:**

```
┌─────────────────────────────────────────────────────────┐
│ [Chat Pane]                                             │
│                                                         │
│ Agent: I've completed the task...                       │
│                                                         │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ Model: claude-sonnet-4.5 | Step: 12 | Tokens: 45.2K | Cost: $0.34 │
├─────────────────────────────────────────────────────────┤
│ > [input box]                                           │
└─────────────────────────────────────────────────────────┘
```

**Cost Calculation:**

```typescript
// Cost from ailang.toml [ai_provider].cost
interface ModelCost {
  inputPer1M: number;   // USD per 1M input tokens
  outputPer1M: number;  // USD per 1M output tokens
}

const MODEL_COSTS: Record<string, ModelCost> = {
  'claude-sonnet-4.5': { inputPer1M: 3.00, outputPer1M: 15.00 },
  'claude-opus-4': { inputPer1M: 15.00, outputPer1M: 75.00 },
  'gpt-4o': { inputPer1M: 2.50, outputPer1M: 10.00 },
  'gpt-4-turbo': { inputPer1M: 10.00, outputPer1M: 30.00 },
  'openrouter/meta-llama/llama-3.1-8b-instruct': { inputPer1M: 0.06, outputPer1M: 0.21 },
  // ... loaded from ailang.toml at startup
};

function calculateCost(inputTokens: number, outputTokens: number, model: string): number {
  const rates = MODEL_COSTS[model] || DEFAULT_RATES;
  return (inputTokens / 1_000_000) * rates.inputPer1M 
       + (outputTokens / 1_000_000) * rates.outputPer1M;
}
```

**Additional Features:**

1. **Budget warning**: Flash status bar when cost exceeds threshold
   ```
   ⚠️ Cost: $2.50 (over $2.00 budget)
   ```

2. **Step rate**: Show tokens/step to identify expensive operations
   ```
   Tokens: 45.2K (3.8K/step)
   ```

3. **Model comparison**: Show what this would cost on other models
   ```
   Cost: $0.34 (would be $1.70 on claude-opus)
   ```

## Implementation Phases

### Phase 1: Shell Escape (M1)
- Add `!` prefix detection in input handler
- Implement `executeShellCommand()` with child_process
- Display output inline or in pane
- Handle errors gracefully

**Estimated effort:** 1 day

### Phase 2: Cost Indicator (M2)
- Parse cost data from JSONL events
- Add `CostState` tracking in UI
- Update status bar rendering
- Load model cost rates from `ailang.toml`

**Estimated effort:** 0.5 day

### Phase 3: Mid-Conversation Steering (M3)
- Make input box non-blocking
- Add pending input queue in `RuntimeProcess`
- Add `steering_message` type to protocol
- Implement queue checking in AILANG loop
- Display steering indicator in UI

**Estimated effort:** 2 days

## Testing

### Shell Escape Tests
```
!ls                    → lists current directory
!pwd                   → shows working directory
!git status            → shows git status
!invalid_command       → shows error message
!rm -rf /              → confirm before executing (safety)
```

### Steering Tests
```
1. Agent starts long task (read 10 files)
2. User types steering message after file 3
3. Agent receives steering before file 4
4. Agent incorporates steering into next action
```

### Cost Indicator Tests
```
1. Start session, verify cost = $0.00
2. Complete one step, verify cost updated
3. Switch models, verify different rates applied
4. Complete 10 steps, verify cumulative cost
5. Test cost display formatting (cents, dollars, thousands)
```

## Security Considerations

### Shell Escape
- Commands run with TUI process permissions
- User explicitly types `!` - opt-in
- Consider confirmation for destructive commands
- Log all shell commands to session log

### Steering
- Steering messages are user-originated (trusted)
- No additional security concerns

### Cost Tracking
- Cost data is local, not sensitive
- No security concerns

## Related

- Claude Code shell escape pattern
- Anthropic Console cost tracking
- AILANG JSONL event schema (run_summary, step_complete)
