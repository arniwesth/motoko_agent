# M-MOTOKO-DP7-VERIFIER-GATE: Pre-Finalize AILANG Type-Check Gate

**Status**: Planned  
**Priority**: P1 — highest-leverage single change available  
**Estimate**: ~1 day (~200 LOC)  
**Target branch**: motoko-dx-compaction-pending  

---

## Problem

Autonomous agents can hallucinate stdlib names and claim `done` on broken code.
The canonical repro is `wire-mcp-subprocess` (GLM-5, run `20260507-003318-openrouter_zai_glm5`):

| # | File | Bug | Error |
|---|------|-----|-------|
| 1 | mcp.ail:4 | `import std/json (... stringify)` — non-existent symbol | `IMP010: symbol 'stringify' not exported by 'std/json'` |
| 2 | mcp.ail:7 | `import std/string (from_int)` — non-existent symbol | `IMP010: symbol 'from_int' not exported by 'std/string'` |
| 3 | mcp.ail:158 | `rest_encoded.drop(1)` + `"a" + "b"` — JS idioms | `type unification failed: cannot unify string with TRecordOpen` |

All three are caught by `ailang check`. None were caught before the agent declared `done`. This is not a GLM-5-specific issue — every model can hallucinate stdlib names.

The missing decision point is **DP7: pre-finalize verification**. The current decision-point chain (DP0 compaction → DP1 policy gate → DP3 ext handle → DP6 solver candidate) has no mechanical correctness check before `done` is emitted.

---

## Solution

Add a **builtin verifier gate** that runs before either `done` emission point in `loop_v2`. If `make check_core` fails, the loop synthesizes a feedback message containing the type errors and continues iterating — the agent must fix the errors before it can declare success.

This is the same design philosophy as DP0 (compaction) and the pending-policy gate: correctness invariants belong in the runtime, not in the extension system.

---

## Architecture

### New type: `FinalizeVerification`

```ailang
type FinalizeVerification
  = Approve
  | Reject(string)  -- error text to inject as feedback
```

Lives in `agent_loop_v2.ail` alongside the other builtin types.

### New function: `run_dp7_verifier`

```ailang
func run_dp7_verifier(workdir: string) -> FinalizeVerification ! {Process} {
  match exec("bash", ["-c", "cd \"$1\" && make check_core 2>&1", "_dp7", workdir]) {
    Err(_) => Approve,  -- fail-open: no check infrastructure
    Ok(out) => {
      if out.exitCode == 0 then Approve
      else Reject(toString(out.stdout))
    }
  }
}
```

**Fail-open policy**: if `make check_core` doesn't exist or errors due to infrastructure issues, `Approve` is returned. Only a non-zero exit (actual type errors) causes rejection. Projects without `check_core` are unaffected.

### New helper: `dp7_gate`

```ailang
func dp7_gate(workdir: string, step_idx: int) -> Option[Message] ! {Process, IO} {
  match run_dp7_verifier(workdir) {
    Approve => None,
    Reject(errors) => {
      let _ = emit_json(jo([
        kv("type", js("dp7_verifier_rejected")),
        kv("step", jnum(_int_to_float(step_idx))),
        kv("errors", js(errors))
      ]));
      Some({
        role: "user",
        content: "The code you just wrote does not type-check. Fix all errors before declaring done:\n\n${errors}",
        tool_calls: [],
        tool_call_id: ""
      })
    }
  }
}
```

Returns `None` (proceed to `done`) or `Some(msg)` (inject feedback and recurse).

### Wire-in at both `done` emission sites

Currently `loop_v2` has two `done` emission paths:

1. `Accept(output)` from `dispatch_solver_candidate` (ext solver accepted)
2. `NoDecision` (model's own content, no ext override)

Both change from:

```ailang
let _ = emit_json(jo([kv("type", js("done")), ...]));
Ok(msgs_with_assistant)
```

To:

```ailang
match dp7_gate(workdir, step_idx) {
  None => {
    let _ = emit_json(jo([kv("type", js("done")), ...]));
    Ok(msgs_with_assistant)
  },
  Some(retry_msg) => {
    let next_msgs = msgs_with_assistant ++ [retry_msg];
    loop_v2(rt, task, env_url, hybrid_tools, budget, model, next_msgs, workdir,
            step_idx + 1, step_budget - 1, ohmy_pi, max_cost_millicents,
            cost_rates, new_total_cost, new_warned_pct, next_provider)
  }
}
```

---

## New imports required in `agent_loop_v2.ail`

```ailang
import std/process (exec, ProcessError, ProcessOutput)
import std/bytes (toString)
```

---

## Files to modify

| File | Change | Estimated LOC |
|------|--------|---------------|
| `src/core/agent_loop_v2.ail` | Add type + two functions + wire at both done sites | ~60 LOC |

Total: **~60 LOC** (smaller than the message estimated because we reuse the existing `loop_v2` recursion pattern).

---

## New JSONL event

```json
{ "type": "dp7_verifier_rejected", "step": 7, "errors": "..." }
```

Consumers (dashboard, trace tools) can surface this event to show when the verifier gate fired.

---

## Iteration cost note

If the agent has been writing broken code for many steps, the verifier fires once at the end with all accumulated errors. Higher token cost than failing earlier. A future mid-stream verify hook (fire after every N WriteFile/EditFile calls) can mitigate this, but is deferred to v2.

---

## Touched-files tracking (v2)

v1 always runs `make check_core` over `src/core/*.ail` regardless of what changed. A future optimisation (option 1 in the original message) would track WriteFile/EditFile paths in the loop state and only re-check touched files. Deferred.

---

## Acceptance criteria

- [ ] `make check_core` failure before `done` injects feedback message and forces another iteration
- [ ] `make check_core` success → `done` emitted unchanged (no regression)
- [ ] Missing `make check_core` → `done` emitted (fail-open, no regression)
- [ ] `dp7_verifier_rejected` event emitted to JSONL on rejection
- [ ] Both `done` paths (ext Accept + NoDecision) are gated
- [ ] `make test` passes

---

## Related

- `msg_20260507_005040_06adbc32` (motoko-explore) — original proposal with GLM-5 repro
- DP0 compaction (`compact_step`) — the template: builtin gate, same loop recursion pattern
- `m-motoko-stub-step.md` — integration test infrastructure that can test this gate
