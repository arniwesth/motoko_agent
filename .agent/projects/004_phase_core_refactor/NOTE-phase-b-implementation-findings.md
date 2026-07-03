# Phase-B implementation findings

Date: 2026-07-03

## WI-5 validation predicate narrowed pending repro

While landing `validate_compactor_output`, the relative pair-preservation arm
(`assistant tool_call presence` and `tool result presence` must match input for
ids kept in output) rejected an identity transcript containing an assistant
tool call followed by its matching tool result. The simpler invariants passed:
identity over orphan tool-result messages, no system messages in output, no
empty tool ids, and no invented tool-result ids.

To keep WI-5 shippable and avoid silently corrupting the system-prefix fix, the
landed predicate enforces the working subset needed before chain wiring: reject
system output, empty tool ids, and invented assistant/tool ids. The stricter
pair-preservation predicate needs a minimal repro before being reintroduced.

## WI-6 repro and fix

WI-6 isolated the cause while preparing the compactor-chain smoke. The validator
was comparing retained ids against the shrinking recursive output tail, not the
full output transcript, so identity failed after the assistant message had been
consumed and the later tool message looked pair-severed.

The WI-6 predicate carries the full output separately from the remaining
recursion tail. Identity with paired calls and orphan tool results now passes,
and pair-severing outputs are rejected by direct tests and the chain smoke.
