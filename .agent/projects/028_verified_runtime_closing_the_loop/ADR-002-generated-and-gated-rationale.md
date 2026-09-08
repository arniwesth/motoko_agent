# ADR-002 — Generated-and-gated rationale: conventions that carry weight become artifacts

Date: 2026-08-30
Status: Proposed
Context sessions: Motoko live assessments 2026-08-29 (NOTE-001) and 2026-08-30
(NOTE-002, NOTE-003)

## Context

The project already has one proven pattern for keeping artifacts truthful:
**generate them, then gate the generator.** `registry_generated.ail` ("Do not
edit. Regenerate: make registry_gen", verified by `make registry_gen_check`),
the event vocabulary's own validator (34 rows or none), and the DST
demo-scale leak check all follow it.

But the *rationale layer* — the part that makes a 56-module, 48-sprint-id core
comprehensible — is still hand-woven prose inside code comments, a 2,760-line
Makefile, and examples no gate runs. Measured consequence (NOTE-003): 861
WI-id mentions across 33 of 56 files that resolve to nothing greppable; 974
lines of top-level docs versus 1,116 comment lines in `session.ail` alone; a
teaching example that rotted silently (`discount_calculator.ail`); stale
verifier annotations that misdirected two sessions toward the wrong diagnosis
of the fold wall. Doc drift is the only finding class both independent
sessions share. The complexity is not in the algorithms — it is in
unindexed, ungated rationale.

## Decision

Apply the generate-and-gate pattern to the rationale layer itself:

1. **Taxonomy → glossary artifact.** Every `WI-…` / `M-MOTOKO-…` / `D#` / ADR
   id gets exactly one generated definition; `glossary_check` fails on any
   citation that does not resolve. Erasure of the history is out of scope;
   making it cheap is the point.
2. **Examples/tours → CI-run code.** Any file whose purpose is to teach
   (examples, tours) must stay `ailang check`-green in CI or be marked
   historical. No ungated teaching artifacts.
3. **Compatibility surfaces → enforceable deprecation.** Entry points whose
   comments say "until they are audited" get a surface check that fails on new
   callers, then are audited and deleted. Multi-positional-parameter entry
   points become closed option records.
4. **Failure modes → triage rule.** Toolchain and runtime failures must be
   either diagnostic-with-hint or skip-with-reason — never a hang
   (`PAR_INFINITE_LOOP`), never a silent success (batch veto, `exit_code: 0`).
   Amended (NOTE-004, from 026): refusals are domain data — carry
   `{code, reason, retry_hint}`, not prose; one refusal shape at the parser,
   the scratchpad, and the DP7 gate.

Explicitly rejected: prose-quality gates ("doc coverage" CI), file-count
targets, deleting WI history, big-bang Makefile migration. Gates enforce
existence, drift, and rot — never style.

## Consequences

- New ids, new examples, new compatibility shims become *impossible to add
  ungated* — the accretion problem stops at the gate, not in a future audit.
- Onboarding cost drops from archaeology to lookup: the 861 WI mentions gain
  one canonical resolution each; the tour gives every subsystem a runnable
  entry point that cannot rot.
- Blast radius around the hubs shrinks as `phase_vocab`/`session.ail` split
  along the seams their own headers already name (PLAN-002 item 3).
- Cost: four small generators/checks to maintain, and the discipline of
  updating the glossary when a sprint closes. Accepted: it is the same
  discipline `registry_gen_check` already imposes, which has worked.
- Work items: PLAN-002 (items 1-6); evidence: NOTE-003. This ADR is the
  comprehension-cost complement to ADR-001's enforcement-cost decision.
- Amended (NOTE-004, relation to 026): this ADR is an authority map over
  project knowledge in 026's vocabulary — sprint-id semantics ontology-owned,
  examples source-backed, prose claims derived and regenerable. VISION-001
  Layer 3's claim vocabulary (`verified/skipped/unbacked`) is the same
  three-way split 026 derives for external state; the convergence is
  independent evidence the shape is right. Glossary is a schema
  (objects/links/actions), not a list; references are symbol-anchored, not
  line-anchored (PLAN-002 item 6); refusal shape `{code, reason, retry_hint}`
  shared with 026 §3.1 and co-scheduled with the verifier ABI work (NOTE-002
  W1-W3).
