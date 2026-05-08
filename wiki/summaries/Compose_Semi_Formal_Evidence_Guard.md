---
doc_type: short
full_text: sources/Compose_Semi_Formal_Evidence_Guard.md
---

# Compose Semi-Formal Evidence Guard Summary

This plan strengthens the Compose subagent's anti-fabrication guard by adopting the certificate pattern from the *Agentic Code Reasoning* paper. It replaces substring heuristics with structural, forge-resistant checks and couples them with the existing `expected_output` contract.

## Key Motivations
- The current guard (`composeSnippetGuard`) relies on fragile keyword detection and weak evidence witnesses (`readFile(` / `exec(`).
- The certificate approach (premises + trace + conclusion bound to explicit reads) lifts accuracy by 9–11pp in code reasoning (per [[papers/2603.01896v2]]).
- [[concepts/ClaimCheck]]'s round-trip informalization adds robust semantic verification without exposing intent to the content inspection step, beating end-to-end prompting by 27pp.

## Phased Delivery

The plan is split into five incremental phases (SF1–SF5), each gated by environment variables to preserve existing behavior by default.

### SF2 – Effect-Set Evidence Witness (ships first)
Replaces the substring check with inspection of the snippet's declared AILANG effects (`FS` / `Process`). Only analysis-kind intents that lack these effects are rejected. This leverages the type system's proven validity (`ailang check`) and eliminates false positives from ambiguous keywords. 

### SF1 – Certificate Template in Author Prompt
Injects a structured output template for `analyze` and `summarize` kinds (`PREMISES` / `TRACE` / `CONCLUSION`). Teaches the subagent to produce verifiable certificates rather than free-form reasoning. Unifies with SF2 by introducing `intent_kind` to replace the keyword-sniffing classifier.

### SF3 – Certificate Validator
Extends the existing `expected_output` validator to enforce the certificate structure (`kind: "certificate"`). Checks for section presence, required premise count, and arrow-separated citations. Non-conforming output triggers a retry via the same exit code=2 policy.

### SF4 – Citation-Binding Check
A cheap static pass that verifies every cited path in the certificate premises appears as a literal argument of a `readFile`, `listDir`, or `exec` call in the snippet source. Operates in a prefix-match or strict mode. Complements SF5 without LLM cost.

### SF5 – Round-Trip Informalization ([[concepts/ClaimCheck]] style)
Two LLM calls per attempt: an informalizer describes the certificate's demonstrated claims without seeing the intent, then a comparator judges whether that description matches the original intent. Catches tautological, off-target, and over-narrow certificates that structural checks alone cannot. Verdicts (`disputed`, `vacuous`, `surprising_restriction`) trigger retry with corrective hints. Budget capping and timeouts prevent runaway latency.

## Design Principles
1. Structural prevention over substring detection.
2. Effect annotations as forge-proof evidence witnesses.
3. Coupling with the existing `expected_output` contract.
4. All new behaviors gated behind env vars; defaults safe.
5. Main-agent surface unchanged unless phases opt in.

## Related Plans
- [[AILANG_Composition_Subagent]] – the subagent's governing plan; this extends its output-contract and anti-fabrication phases.
- [[Semi_Formal_Reasoning_Integration]] and [[Core_Extension_System_for_Semi_Formal]] – main-agent semi-formal verifier work, unaffected by this plan.

## Environment Variables
All features are controlled by env vars (`AILANG_COMPOSE_*`) with conservative defaults (mostly `0`), allowing gradual adoption and rollback.

## Testing & Success Criteria
Extensive unit/integration tests cover each phase's behavior, separation invariants, telemetry, and budget enforcement. SF5's default-enable depends on a planted-certificate benchmark achieving ≥80% precision on off-target verdicts and ≤5% false-positive rate.

## Open Issues
- Exact model choice for informalizer/comparator (default to same model, but ClaimCheck's gains may partially come from different tiers).
- `intent_kind` fallback when `SYSTEM_MD` overrides the main-agent prompt.
- Telemetry granularity for main agent feedback.