# ADR-002 Send-Gate Implementation Session

Date: 2026-07-06

## Goal

Implement `.agent/projects/004_phase_core_refactor/PLAN-adr-002-send-gate.md`: the ADR-002 `seal_compacted_payload` send-gate changes, including typed `SealError`, `system_prefix_chars`, `require_system_prompt`, and two Layer-1 scenarios.

## Grounding

- Read the plan, ADR, and `NOTE-ailang-run-exit-code-false-alarm.md`.
- Confirmed toolchain pin:
  - `ailang --version` => AILANG v0.26.0, commit `3b52a24`.
  - `ailang.lock` contains `"ailang_version": "v0.26.0"`.
- HEAD had advanced from the plan's `b76dd3e` to `33b0d80`, and the relevant files had changed, so anchors were re-established by fresh searches instead of trusted by line number.
- Baseline before edits was green:
  - `ailang check src/core/phase_vocab.ail`
  - `ailang check src/core/session.ail`
  - `ailang test src/core/phase_vocab.ail` => 25/25
  - `ailang test src/core/step_machine.ail` => 16/16
  - `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail` => 10/10 PASS

## Operator Decision

The handoff required confirmation for D-P1. The operator chose the plan-recommended runtime default:

```ailang
require_system_prompt: not headless
```

AILANG did not accept `!headless`, so the implemented syntax is `not headless`.

## Changes Made

### WI-1: system-prefix char observability

Files:
- `src/core/phase_vocab.ail`
- `src/core/session.ail`

Implemented:
- Added exported pure `system_prefix_chars(msgs: [Message]) -> int` using `Str.length`.
- Added `system_prefix_chars: int` to `ProviderCallInfo`.
- Added the field to provider-call JSON projection immediately after `system_prefix_count`.
- Updated `ProviderCallPrepared` construction sites and golden tests.
- Live `ProviderCallPrepared` now emits `system_prefix_chars: system_prefix_chars(compacted_msgs)`.

### WI-2: policy field

Files:
- `src/core/phase_vocab.ail`
- `src/core/session.ail`
- `src/core/step_machine.ail`
- `scripts/phase_c_l1_scenarios.ail`

Implemented:
- Added `require_system_prompt: bool` to `StepPolicy`.
- Origin default in `session_policy_init`: `require_system_prompt: not headless`.
- Derived policies inherit the field.
- Test/scenario policies use `true`.

### WI-3: atomic seal behavior

Files:
- `src/core/phase_vocab.ail`
- `src/core/session.ail`

Implemented:
- Added `SealError = SealExhausted(string) | SealSystemPromptEmpty(string)`.
- Changed `seal_compacted_payload` signature to accept `require_system_prompt: bool` and return `Result[ProviderPayload, SealError]`.
- Empty system prompt check runs before exhaustion.
- Exhaustion message remains byte-identical inside `SealExhausted`.
- Session live loop now matches typed seal errors:
  - `SealSystemPromptEmpty` emits `ErrorEvent({ source: "system_prompt", code: "SystemPromptEmpty", ... })`, run summary finish code `5`, and result `Err` code `SystemPromptEmpty`.
  - `SealExhausted` preserves the existing `CompactionExhausted` / `ContextExhausted` path.
- Updated three existing seal tests and added `test_seal_compacted_payload_rejects_empty_system_prompt`.

### WI-4: Layer-1 scenarios

File:
- `scripts/phase_c_l1_scenarios.ail`

Implemented:
- Added `empty_system_prompt_rejected`.
- Added `oversized_payload_rejected`.
- Registered both scenarios; harness now reports 12 scenarios.
- `oversized_payload_rejected` passes `require_system_prompt = false` so exhaustion is not masked by empty-prompt rejection.

### Post-plan drift fix

File:
- `scripts/phase_f_pipeline_wiring.ail`

HEAD had introduced a new `StepPolicy` literal after the plan was grounded. Added `require_system_prompt: true` as a compile-only fix so this script checks cleanly under the widened policy type.

## Verification

Final automated checks passed:

```text
ailang check src/core/phase_vocab.ail
ailang check src/core/session.ail
ailang check src/core/step_machine.ail
ailang check scripts/phase_f_pipeline_wiring.ail
ailang test src/core/phase_vocab.ail          # 26/26
ailang test src/core/step_machine.ail         # 16/16
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail   # 12/12 PASS
```

Teeth check:
- Temporarily flipped `empty_system_prompt_rejected` from `seal(..., true)` to `seal(..., false)`.
- Harness exited nonzero and reported:
  - `scenario=empty_system_prompt_rejected`
  - invariant `empty system prompt rejected with SystemPromptEmpty`
  - trace `expected=SystemPromptEmpty`, `actual=Ok`
- Restored `true`; harness returned to 12/12 PASS.

Static inspections:
- Live loop reject path emits an `error` event coded `SystemPromptEmpty` and does not emit `provider_call_prepared`.
- Proceeding calls still emit `provider_call_prepared` and now include `system_prefix_chars`.
- TUI parser tolerance checked by inspection: `parseAgentEventLine` JSON-parses any object with a string `type` and does not reject unknown fields, so additive `provider_call_prepared.system_prefix_chars` is tolerated.
- New scenarios do not use network or live provider ports; the only `registry` grep hits are the pre-existing registry-order scenario.

## Files Modified

- `src/core/phase_vocab.ail`
- `src/core/session.ail`
- `src/core/step_machine.ail`
- `scripts/phase_c_l1_scenarios.ail`
- `scripts/phase_f_pipeline_wiring.ail`

Pre-existing untracked files were observed and left untouched:
- `.agent/projects/004_phase_core_refactor/HANDOFF-implement-adr-002-send-gate.md`
- `.agent/projects/004_phase_core_refactor/NOTE-code-graph-dst-assessment.md`
