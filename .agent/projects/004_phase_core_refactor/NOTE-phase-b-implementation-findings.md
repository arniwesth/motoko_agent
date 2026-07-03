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

## WI-7 registered package cannot import mirrored core inside the root

WI-7a's throwaway package probe passed when importing
`pkg/sunholo/motoko_core/core/compaction` from outside the root package. During
WI-7c registration, however, checking `src/core/agent_loop_v2.ail` after adding
`motoko_ext_compaction_structural` to the root lock failed MOD011: the mirrored
`.packages/motoko_core/src/core/compaction.ail` declares `module
src/core/compaction`, colliding with the root's local `src/core/compaction`.

The structural package therefore keeps the tiny token/usage measurement helper
self-contained for the in-repo path dependency. The ABI and hook behavior are
unchanged; the root can load the registered package without importing the
mirrored core copy into the same module namespace.
