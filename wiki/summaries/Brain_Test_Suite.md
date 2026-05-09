---
doc_type: short
full_text: sources/Brain_Test_Suite.md
---

# Brain Test Suite Summary

This document presents a multi-layered testing strategy for the pure `swe/` brain modules (`parse.ail`, `prompts.ail`, `agents_md.ail`) that must be validated before any self-modification proceeds. It complements the type-checking and smoke tests in [[Self_Modifying_Brain_Safe_Cutover]] by ensuring that critical parsing and formatting logic (like `extract_bash`, `is_done`, `parse_cwd`) remains semantically correct across candidate upgrades.

## Testing Layers

The plan combines three complementary techniques:

- **Inline Tests** – Concrete oracle cases attached directly to function definitions, using real LLM output patterns for `swe/parse.ail` functions.
- **Property Tests** – Algebraic invariants checked against 100 random inputs, suitable for `swe/prompts.ail` formatting functions and path functions in `swe/agents_md.ail`.
- **Z3 / SMT Formal Verification** – Selected proofs for simple string properties in `agents_md.ail` (e.g., `dirname_shrinks`) to guarantee termination without recursion blow-up.

The document explicitly excludes mutation-heavy functions (`split`-based) from Z3, reserving it for length and prefix constraints that Z3’s string theory can handle.

## Module Focus

- **`swe/parse.ail`**: Inline tests on `is_done`, `looks_like_shell`, `extract_fence`, `extract_bash`, `first_shell_line`, `parse_cwd`. Values are drawn from real LLM responses (```bash fences, sentinel checks). Properties act as no-crash smoke tests.
- **`swe/prompts.ail`**: Inline tests for `with_cache_hint` and `fmt_obs`; properties include identity laws and sentinel inclusion in `base_system`.
- **`swe/agents_md.ail`**: Inline tests for `dirname`/`is_root`; Z3 verification of `is_root_length_bound` and `dirname_shrinks` (guaranteeing termination of `walk_agents`).

## Integration with Safe Cutover

Phase 5 wires the test suite into the upgrade gate. The `UpgradeManager.runCandidateValidation()` calls `ailang test` on each module; any failure blocks the candidate exactly like a type-check failure. This ensures semantic drift is detected or must be deliberate (by updating the inline tests).

## Future: Mutation Testing

The document sketches how mutation testing could measure test sensitivity by automatically injecting faults into the AST and checking if existing tests catch them. A mutation score baseline for `parse.ail` would guard against LLM-generated candidates silently weakening test coverage.

## Related Concepts
- [[Self_Modifying_Brain_Safe_Cutover]] defines the overall self-modification pipeline.
- [[concepts/property-testing]] and [[concepts/Z3-verification]] for deeper discussion of these verification techniques.
- [[concepts/mutation-testing]] for fault-injection evaluation.