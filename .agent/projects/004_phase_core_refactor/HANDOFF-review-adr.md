# Handoff: independently review ADR-001-phase-oriented-core.md

Audience: a fresh agent session with no context from the authoring session. Your distance from
the author is the point — you are the check the author cannot perform on themselves.

## Mission

Adversarially review `.agent/projects/004_phase_core_refactor/ADR-001-phase-oriented-core.md`
in the style of the R1–R15 review appended to
`.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md` (read that
review first — it is the quality bar: grounded, numbered, each finding names a concrete defect
and a concrete action).

## Inputs (read in this order)

1. The ADR under review (above).
2. `.agent/projects/004_phase_core_refactor/RESEARCH-phase-core-dst-design.md` — the evidence
   base the ADR cites as §N.
3. `.agent/projects/004_phase_core_refactor/sketch/README.md` + the sketch/probe files.
4. `.agent/projects/003_CSP_core_refactor/NOTE-why-not-csp-now.md`.
5. `.agent/projects/001_DST/ADR-001-...md` including its Review Comments section.
6. Source as needed: `src/core/agent_loop_v2.ail`, `src/core/compaction.ail`,
   `src/core/rpc.ail`, `src/core/ext/runtime.ail`, `src/core/test/stub_step.ail`,
   `~/.ailang/cache/registry/sunholo/motoko_ext_abi/2.2.0/types.ail`,
   `~/.ailang/cache/registry/sunholo/motoko_ext_compaction_ai/0.2.0/compaction_ai.ail`.

## Review method (all four passes required)

1. **Citation audit.** Verify EVERY `file:line` reference in the ADR against current source.
   Wrong line numbers, paraphrases that misstate what the code does, and claims attributed to
   files that don't contain them are findings (this is how DST-R1/R2 class bugs happen).
2. **Claim attack.** For every claim not backed by a checked artifact, try to refute it. Run
   the artifacts yourself:
   `ailang check`/`run`/`test` on `sketch/sketch_vocabulary.ail`, the opacity probes (the
   forge probes MUST fail with IMP010), and `scripts/smoke_ports_record.ail` (fakes entry must
   run under `--caps IO` only). An artifact that no longer reproduces is a top-severity
   finding.
3. **Consistency pass.** The ADR vs. the research doc vs. the why-not-CSP note vs. DST ADR-001:
   find contradictions, silent scope changes, and places where the ADR asserts something the
   research doc marks as open (or vice versa). Check the 28-event inventory claim against
   actual `emit_event` sites. Check that the ADR's acceptance criteria are *verifiable* (no
   dangling references, no phantom targets — DST-R1/R12 class).
4. **Design attack.** Steelman at least: (a) the co-location consequence (is a single large
   vocabulary module actually acceptable? is there a way around IMP010 the probes missed?);
   (b) the 28-event byte-compatibility gate (is byte-parity achievable while moving emission
   points?); (c) `AwaitApproval` as a decision (does inverting the mid-dispatch `readLine`
   break the TUI's approval protocol timing?); (d) checkpoint digest-chain enforcement (what
   forges or bypasses remain?).

## Output contract

Append a `## Review Comments` section to the ADR itself (do not rewrite the body). Numbered
findings `R1..Rn`, most severe first, each with: the defect in one sentence, the grounding
(file:line or reproduced command output), and a concrete **Action:**. Close with a short
"What is accurate" paragraph and a "Recommended pre-implementation actions" list, mirroring
the DST review's shape. State your model/date at the top of the section.

## Constraints

- Do NOT re-litigate decisions D1–D8 without new evidence; the decision log records operator
  sign-off. Attacking the *justification* of a settled decision with contrary code/substrate
  evidence is in scope; re-arguing taste is not.
- Do NOT modify the research doc, the sketch, or source code. Findings only.
- If an artifact fails to reproduce, report the exact command and output — do not fix it.
