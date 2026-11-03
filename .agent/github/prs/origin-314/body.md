---
repo: arniwesth/motoko_agent
pr: 314
branch: arniwesth/042-lean-harness-properties
ticket: null
title: "docs(042): proving harness properties in Lean, after Kiro, with the pairing model's Lean run"
---

## Summary

A new research project, **042**, reads Kiro's 2026-11-02 post on proving properties of its own harness in Lean and maps its method (model, differential test, prove, reproduce) onto Motoko. The verdict is **adopt the method; there is no tooling to adopt**. Lean takes what Z3 reports as `blocked` or cannot state: folds, event sequences, and the rules implemented once in TypeScript and once in AILANG. The note ranks the targets and the order of work.

Its worked example is a Lean model of the journal fold's pairing check (`pair_step`) and its TypeScript twin (`updatePending`). In the session that wrote it, the Lean half could not run (`release.lean-lang.org` answered 403). **It has now run.** All 16 theorems check, none uses an axiom beyond `propext` and `Quot.sound`, and the model's host side matches the real `updatePending` on all 16,105 histories. **This is still not a finding.** The model's fold side has not been compared with AILANG, so the note's "no finding" stands.

## Changes

- docs(042): research note on proving harness properties in Lean, after Kiro
- docs(042): record the Lean run of the pairing model (0 mismatches)

1. **The note and its evidence**, the first commit, applied unchanged from a patch written in another session: `RESEARCH-lean-harness-properties.md`, `evidence/PairingModel.lean`, and the differential test under `evidence/diff/`.
2. **The run**, the second commit. It is recorded in `evidence/diff/README.md`'s runs table, with the toolchain, the hashes, the axiom report and a negative control. The note and the model's header each get a dated marker at the top and are not otherwise edited, per the research-doc convention: the original states what was believed when it was written. The model now also prints axioms for its two controls and its witness theorem.

6 files changed.

## Governing docs

- `.agent/projects/042_lean_harness_properties/RESEARCH-lean-harness-properties.md`
- `.agent/projects/042_lean_harness_properties/evidence/diff/README.md`

## Predicted outcome

Nothing in the harness changes: no source file is touched. What changes is that the Lean tier has one model that a kernel has checked and that has been differentially tested against real code, and that anyone with `lean` 4.28.0 and `bun` on `PATH` can re-run it (`evidence/diff/run_diff.sh`, exit 0 only on a full, clean comparison). The note's next steps are in its §10: the AILANG half of the example (item 2; `ailang` v0.54.14 is installed on the machine that ran this), and a person's decision on whether ADR-003 D4 means to refuse the two shapes the fold admits (item 3).

## Test evidence

**1. Files changed.** Only the new project directory: `git diff --name-only origin/main...HEAD`

```
.agent/projects/042_lean_harness_properties/RESEARCH-lean-harness-properties.md
.agent/projects/042_lean_harness_properties/evidence/PairingModel.lean
.agent/projects/042_lean_harness_properties/evidence/diff/README.md
.agent/projects/042_lean_harness_properties/evidence/diff/enumerate.lean.tail
.agent/projects/042_lean_harness_properties/evidence/diff/enumerate.ts
.agent/projects/042_lean_harness_properties/evidence/diff/run_diff.sh
```

**2. The full differential run.** Lean 4.28.0 (elan 4.2.4, linux aarch64) and bun 1.4.4, at `origin/main` `43530c0a`:

```
$ PATH=~/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH \
    .agent/projects/042_lean_harness_properties/evidence/diff/run_diff.sh <scratch>
ts: 16105 histories, sha256 6de0b5877d1ace2f
differential: 16105 histories, 0 mismatches
bounded: 449 accepted histories within H1/H2, 0 disagree; 222 outside H1/H2 disagree
exit=0
```

The bun output is byte-identical to the earlier `--ts-only` run. It was run twice: once on the first commit's model, and again after the second commit added three `#print axioms` lines, with the same result and the same `lean.out` (sha256 `b890f15f6e5b6f10…`).

**3. Axioms**, `#print axioms` over all 16 theorems: nothing beyond `propext` and `Quot.sound`. There is no `sorryAx`, no `Classical.choice` and no `Lean.ofReduceBool`. `host_twin_agrees` uses `[propext, Quot.sound]`; the counterexample theorems, the controls and the witness use none.

**4. Negative control.** One mutant at a time in the real `updatePending`, compared with the unmutated run, and the file restored afterwards:

| Mutant | Mismatches of 16,105 |
|---|---|
| keep empty call ids | 2,252 |
| a result never closes a call | 2,940 |
| ignore calls on a tool message | 1,842 |

**5. Transcription, read against the source.** `pairStep` matches `pair_step` (`journal.ail:1634`) branch for branch. `call_ids` (`:1372`) does not filter empty ids, and `valid_message_transcript` (`phase_vocab.ail`) checks a tool message only for a non-empty `tool_call_id`. Both are premises of the note's §6.2 and of (H2).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
