# M-MOTOKO-TOOL-POLICY-PENDING

**Status**: Planned  
**Priority**: P1 — prerequisite for plan-mode extension  
**Estimated effort**: 2-3 days  
**Dependencies**: agent_loop_v2 (✅ already in use)  
**Source**: motoko-explore inbox msg `711493bc` (2026-05-06)

---

## Problem

motoko's tool-policy hook (`ToolPolicyDecision`) has three variants today:

```ailang
type ToolPolicyDecision
  = Allow
  | Deny(reason: string)
  | NoOpinion
```

There is no `Pending` — no way to pause the loop, surface a tool call to a human, wait for approval/rejection, then continue. Every loop is fully autonomous up to `max_steps`.

This is intentional for the Phoenix-architecture default but blocks:
- **Plan-mode**: approve/reject before destructive actions (rm, git reset, network egress)
- **Cost-gating**: humans approving batches of expensive tool calls
- **Mixed-trust environments**: auto-approve ReadFile but pause-on-WriteFile-outside-cwd

---

## Goals

1. Add `Pending(reason, default)` as a fourth `ToolPolicyDecision` variant
2. Loop blocks on stdin approval; timeout applies the `default` policy
3. Zero behaviour change when no extension returns `Pending` (existing autonomous profile unchanged)
4. Approval events recorded in session JSONL for audit

---

## Design

### Updated type

```ailang
type PolicyDefault = AllowAfterTimeout | DenyAfterTimeout

type ToolPolicyDecision
  = Allow
  | Deny(reason: string)
  | NoOpinion
  | Pending(reason: string, default: PolicyDefault)
```

This is a **breaking ABI change** to `ToolPolicyDecision`. All pattern matches on the type need a new case. The change is small but affects:
- `apply_tool_policy` in `src/core/agent_loop_v2.ail` 
- Any extension that returns `ToolPolicyDecision` (currently: none in core; all in `src/core/ext/`)
- The `motoko-ext-abi` package if extensions-as-packages lands first

### Loop changes (`agent_loop_v2.ail`)

When `dispatch_tool_policy` returns `Pending`:

1. Emit `tool_pending` event on JSONL channel: `{"type":"tool_pending","call_id":"...","reason":"...","timeout_s":30}`
2. Write `pending_approvals.json` to the RPC stdout channel for the wrapper to surface
3. Block reading stdin for `{"type":"approve","id":"..."}` or `{"type":"deny","id":"...","reason":"..."}`
4. On timeout: apply `default` (`Allow` or `Deny`) and log `tool_approved_by_timeout` / `tool_denied_by_timeout`
5. On response: log `tool_approved` or `tool_denied` to session JSONL

Timeout is configurable per-profile: `approval_timeout_s: 30` (default). For unattended runs (CI, benchmarks): set `approval_timeout_s: 0` and the extension should return `Pending(..., AllowAfterTimeout)` — effectively a no-op.

### TUI affordance

The wrapper (`cmd/motoko` or equivalent) gains two commands:
- `/approve [call_id]` — approves the pending call (or all if no ID given)
- `/deny [reason]` — denies the pending call

These write to the loop's stdin channel. For non-interactive wrappers (glue script, CI), the timeout + default handles it automatically.

### Benchmark / eval compatibility

The eval matrix must not be broken. The `eval_runner` policy: return `NoOpinion` from all policy hooks (existing behaviour). No `Pending` is ever returned in eval runs. Tests that use `AllowAfterTimeout` with `timeout_s: 0` effectively skip the pause.

---

## Files

| File | Change |
|------|--------|
| `src/core/types.ail` | Add `Pending` variant + `PolicyDefault` type |
| `src/core/agent_loop_v2.ail` | Handle `Pending` in `apply_tool_policy`; block/timeout logic |
| `src/core/ext/types.ail` | `ToolPolicyDecision` re-exported — update to 4-variant |
| `cmd/` or wrapper | `/approve` and `/deny` stdin commands |
| `src/core/session_log.ail` | New event types: `tool_pending`, `tool_approved`, `tool_denied` |

~150-200 LOC new code, ~50 LOC loop changes.

---

## Acceptance criteria

- [ ] `ToolPolicyDecision` compiles with 4 variants; all existing pattern matches updated
- [ ] Extension returning `Pending("destructive command", DenyAfterTimeout)` causes loop to pause
- [ ] Loop resumes with `Allow` after `/approve` on stdin
- [ ] Loop resumes with `Deny` after `/deny` on stdin
- [ ] Loop applies `default=DenyAfterTimeout` after timeout expires
- [ ] Approval/denial events appear in session JSONL
- [ ] Eval runs with `NoOpinion` policy: zero behaviour change
- [ ] Verified interactively in motoko_explore with a plan-mode stub extension

---

## Plan-mode extension becomes trivial once Pending ships

A `motoko-ext-plan` extension registers at DP3 (tool policy) and returns:
```ailang
Pending("plan not surfaced — ratify before proceeding", DenyAfterTimeout)
```
when `max_steps > 1` and the model produced tool_calls without a `[plan]` tag in the last assistant turn. The human approves the plan. This requires zero core changes beyond `Pending` landing.

---

## Open questions

1. **Single pending call vs multiple**: if a model batches 3 tool_calls and the extension returns `Pending` for all three, does the loop wait for 3 approvals or one "approve all"? Simplest: wait for one approval that covers all pending calls in the same step.
2. **Extension ABI versioning**: adding `Pending` is a breaking change. If extensions-as-packages lands first, `motoko-ext-abi` needs a version bump. If extensions-as-packages lands after, the vendored `src/core/ext/types.ail` is updated in-place (simpler).
