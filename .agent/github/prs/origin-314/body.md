---
repo: arniwesth/motoko_agent
pr: 314
branch: arniwesth/042-lean-harness-properties
ticket: null
title: "docs(043): proving harness properties in Lean, after Kiro, with the worked example run against the real code"
---

## Summary

A new research project, **043**, reads Kiro's 2026-11-02 post on proving properties of its own harness in Lean and maps its method (model, differential test, prove, reproduce) onto Motoko. The verdict is **adopt the method; there is no tooling to adopt**. Lean takes what Z3 reports as `blocked` or cannot state: folds, event sequences, and the rules implemented once in TypeScript and once in AILANG. The note ranks the targets and the order of work.

Its worked example is a Lean model of the journal fold's pairing check (`pair_step`) and its TypeScript twin (`updatePending`). In the session that wrote it, neither the Lean half nor the AILANG half could run. **Both have now run.** All 16 theorems check, and none uses an axiom beyond `propext` and `Quot.sound`. Over all 16,105 histories, the model matches the real `updatePending` and the real `fold_journal` with 0 mismatches, and the two real functions agree wherever the theorem's hypotheses hold. The shapes the note predicted all reproduce on the real fold: a duplicate result, a result after a user message, and a trailing empty call id. **This is still not a finding:** none of these shapes is shown reachable, so the note's "no finding" stands.

The worked example cannot settle whether Lean is worth its cost. Up to length 4, running the two real functions against each other shows everything the theorems state. So the PR also **pre-registers a trial** (`PLAN-001`). Two arms, Lean and executed checks on the real code, get equal budgets on six targets, with planted defects sealed from both and a decision rule fixed in advance. It is frozen by hash and has not started; the operator's approval is its next step.

A note, **NOTE-001**, asks whether Rocq would serve the method better than Lean, and answers by porting the worked example. **Keep Lean.** The proofs come out even: the same 16 theorems check, the port's output is byte-identical to the Lean model's, and it has 0 mismatches against the real fold. Rocq loses on the parts around the proof. Running the model needs extraction to OCaml. `Print Assumptions` does not show a proof checked by the VM, where Lean shows `native_decide`. And a same-typed field swap type-checks in Rocq; only the fold comparison and the theorems catch it, not the host comparison. The note does not touch PLAN-001: no hashed file is edited, and the trial tree is built from PLAN-001's own commit.

## Changes

- docs(042): research note on proving harness properties in Lean, after Kiro
- docs(042): record the Lean run of the pairing model (0 mismatches)
- docs(043): renumber the Lean project from 042, which #306 holds
- docs(043): the AILANG half — the pairing model against the real fold
- docs(043): pre-register the trial of Lean against differential checks (PLAN-001)
- docs(043): NOTE-001, Rocq compared with Lean on the worked example
- docs(043): §11, the method combined with DST, added to the research note

1. **The note and its evidence**, the first commit, applied unchanged from a patch written in another session: `RESEARCH-lean-harness-properties.md`, `evidence/PairingModel.lean`, and the differential test under `evidence/diff/`.
2. **The Lean run**, the second commit: recorded in `evidence/diff/README.md` with the toolchain, the hashes, the axiom report and a negative control on `updatePending`.
3. **The renumbering**, the third commit. The project was first numbered 042, which `042_improving_experimentation` (#306) already holds. The first two commits' subjects still say 042.
4. **The AILANG half**, the fourth commit (§10 item 2).
   - `evidence/diff/enumerate_fold.ail` writes each history as a journal with `journal_lines_of_records`, the way `journal.ail`'s tests build theirs, and folds it with the real `fold_journal`.
   - `compare_fold.awk` compares the model's fold with the real fold, and the real host with the real fold. `run_diff.sh` now runs all three halves and exits 0 only when all three ran clean.
   - The fold-side output lines now carry an id count, because joining `[""]` and `[]` both give `""`, and without the count §6.2's case was invisible to the comparison.
   - `src/core` is unchanged. This is a program beside the evidence, not an in-module test, so that no test pins the two admitted shapes as correct before §10 item 3 decides whether they are.

5. **The pre-registration**, the fifth commit: `PLAN-001-trial-lean-against-differential-checks.md`, with `trial/predictions.tsv` and `trial/sequence.log`, whose first lines hash both. It fixes the targets and their properties, the arms, the planted-defect classes and their sealing, blinding, the scoring procedure, the outcomes in 042's dimensions, the decision rule and its consequences, and the author's predictions (outcome D, differential checks suffice, about 60%). It also lists what is known before the trial: two items from reading the herdr failure vocabulary while writing it, one a candidate `means_agent_gone` twin disagreement (K7), which has not been run.

6. **The Rocq comparison**, the sixth commit: `NOTE-001-rocq-compared-2026-11-03.md` and `evidence/rocq/`. The port (`PairingModel.v`, `Enumerate.v`) runs against a fresh three-way run through `run_rocq.sh`. `audit/` shows what each prover's assumption report says about a proof by computation, and `install_rocq.sh` installs Rocq 9.3.0 without root. It answers the operator's question and changes nothing else. It edits no file of the trial, and the trial tree is built from PLAN-001's own commit (§7).

7. **The DST addendum**, §11 of the research note, at the operator's request and by reading only. DST supplies the method's steps 3, 5, 6 and 7: inputs at the driver's own lengths and shapes (every execution's journal lines, on the `JournalFold` path), reproduction as a corpus program, and reachability. The method supplies the for-every-length statement that `JournalFold` and `ToolPairing` sample. The dry run's K8-K10, all in the replacement path that neither the alphabet nor the model reaches, are its evidence that the shapes a model leaves out are the ones the driver writes. It names what does not combine (the transcription gap, the projection, 007's naming rule, cost) and a first step: the PR corpus's executions through the three halves. It edits no hashed file.

The note's §1-§10 and the model's header are as first written, each with a dated marker at the top; §11 is a dated addendum. That is the research-doc convention: the original states what was believed when it was written.

20 files in the project, plus this record.

## Governing docs

- `.agent/projects/043_lean_harness_properties/RESEARCH-lean-harness-properties.md`
- `.agent/projects/043_lean_harness_properties/evidence/diff/README.md`
- `.agent/projects/043_lean_harness_properties/PLAN-001-trial-lean-against-differential-checks.md`
- `.agent/projects/043_lean_harness_properties/NOTE-001-rocq-compared-2026-11-03.md`

## Predicted outcome

Nothing in the harness changes: no source file is touched. What changes is that the Lean tier has one model that a kernel has checked and that has been differentially tested against both real implementations. Anyone with `lean` 4.28.0, `bun` and `ailang` v0.54.14 on `PATH` can re-run it in about two minutes (`evidence/diff/run_diff.sh`). What is left of the note's §10:

- Whether ADR-003 D4 means to refuse the two shapes the fold admits (item 3). This is a person's decision. The README records what half the sketched fix does on the real code.
- Reachability of the three shapes, Kiro's steps 6 and 7.
- The other twins (item 4).
- The trial (`PLAN-001`): the operator approves it (W0.5), then a planter session plants and seals the defects (W1), and the trial starts.
- §11.6's exporter: the PR corpus's executions through the three halves, and whether any reaches §6.1's shapes, (H1), (H2) or K8-K10.

## Test evidence

**1. Files changed.** Only the new project directory and this record: `git diff --name-only origin/main...HEAD`

```
.agent/github/prs/origin-314/body.md
.agent/projects/043_lean_harness_properties/NOTE-001-rocq-compared-2026-11-03.md
.agent/projects/043_lean_harness_properties/PLAN-001-trial-lean-against-differential-checks.md
.agent/projects/043_lean_harness_properties/RESEARCH-lean-harness-properties.md
.agent/projects/043_lean_harness_properties/evidence/PairingModel.lean
.agent/projects/043_lean_harness_properties/evidence/diff/README.md
.agent/projects/043_lean_harness_properties/evidence/diff/compare_fold.awk
.agent/projects/043_lean_harness_properties/evidence/diff/enumerate.lean.tail
.agent/projects/043_lean_harness_properties/evidence/diff/enumerate.ts
.agent/projects/043_lean_harness_properties/evidence/diff/enumerate_fold.ail
.agent/projects/043_lean_harness_properties/evidence/diff/run_diff.sh
.agent/projects/043_lean_harness_properties/evidence/rocq/Enumerate.v
.agent/projects/043_lean_harness_properties/evidence/rocq/PairingModel.v
.agent/projects/043_lean_harness_properties/evidence/rocq/README.md
.agent/projects/043_lean_harness_properties/evidence/rocq/audit/Audit.lean
.agent/projects/043_lean_harness_properties/evidence/rocq/audit/Audit.v
.agent/projects/043_lean_harness_properties/evidence/rocq/install_rocq.sh
.agent/projects/043_lean_harness_properties/evidence/rocq/main.ml
.agent/projects/043_lean_harness_properties/evidence/rocq/run_rocq.sh
.agent/projects/043_lean_harness_properties/trial/predictions.tsv
.agent/projects/043_lean_harness_properties/trial/sequence.log
```

**2. The three-way run.** Lean 4.28.0 (elan 4.2.4, linux aarch64), bun 1.4.4 and ailang v0.54.14, at `origin/main` `43530c0a`, on the files as committed:

```
$ PATH=~/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH \
    .agent/projects/043_lean_harness_properties/evidence/diff/run_diff.sh <scratch>
ts: 16105 histories, sha256 6de0b5877d1ace2f
differential: 16105 histories, 0 mismatches
bounded: 449 accepted histories within H1/H2, 0 disagree; 222 outside H1/H2 disagree
ail: 16105 histories, sha256 953896c1a30e5ccc
  model / real fold: refuse / pairing          15272
  model / real fold: accept / other:transcript     83
  model / real fold: accept / accept             750
fold: 16105 histories, 0 mismatches between the model and the real fold
twin: 449 histories the real fold accepts within H1/H2, 0 where host and fold disagree; 213 disagree outside H1/H2
exit=0
```

**3. Axioms**, `#print axioms` over all 16 theorems: nothing beyond `propext` and `Quot.sound`. There is no `sorryAx`, no `Classical.choice` and no `Lean.ofReduceBool`.

**4. The note's predictions, on the real code:**

| History | Prediction | Real fold | Real host pending |
|---|---|---|---|
| `asst(a), tool(a), tool(a)` | `admits_duplicate_result` | accepts | none |
| `asst(a), tool(a), user, tool(a)` | `admits_result_after_user` | accepts | none |
| `asst(a, ""), tool(a)` | §6.2: the fold keeps the trailing empty id | accepts, `dangling = [""]` | none |
| `asst(a), tool{calls b, id a}` | `twin_disagrees_without_h2` | accepts, `dangling = []` | `b` |

**5. Negative controls.** One mutant at a time in the real code, re-run, and the file restored afterwards:

| Mutant | Caught by | Mismatches |
|---|---|---|
| `updatePending` keeps empty call ids | model and host | 2,252 of 16,105 |
| `updatePending`: a result never closes a call | model and host | 2,940 of 16,105 |
| `updatePending` ignores calls on a tool message | model and host | 1,842 of 16,105 |
| `pair_step` checks a result against `open_ids`, not `cur_ids` | model and fold | 173 of 16,105 |
| `pair_step`: a result never closes its call | model and fold; host and fold | 500; 86 of 327 within H1/H2 |

**6. Transcription, read against the source.** `pairStep` matches `pair_step` (`journal.ail:1634`) branch for branch. `call_ids` (`:1372`) does not filter empty ids, and `valid_message_transcript` (`phase_vocab.ail`) checks a tool message only for a non-empty `tool_call_id`.

**7. The Rocq port (NOTE-001).** Rocq 9.3.0 (`rocq-stdlib` 9.2.0, OCaml 4.14.2), against a fresh `run_diff.sh` run at this branch's `12672be8`. That run reproduced item 2 exactly, with `lean.out` sha256 `c729a3cb…` and `ail.out` `953896c1…`.

```
$ evidence/rocq/run_rocq.sh <run_diff scratch> <rocq scratch>
kernel: PairingModel.v checks; Print Assumptions: 8 of 8 theorems closed
rocq: 16105 histories, sha256 c729a3cb30df336a
rocq vs lean: byte-identical to lean.out
  model / real fold: refuse / pairing          15272
  model / real fold: accept / other:transcript     83
  model / real fold: accept / accept             750
fold: 16105 histories, 0 mismatches between the model and the real fold
twin: 449 histories the real fold accepts within H1/H2, 0 where host and fold disagree; 213 disagree outside H1/H2
exit=0
```

Negative control on the port: swapping `openIds` and `curIds` in `pairStep`'s record update type-checks. It gives 0 host mismatches, 517 fold mismatches of 16,105, and `admits_duplicate_result` no longer checks. On the assumption reports, Lean's `native_decide` shows `[Lean.ofReduceBool, Lean.trustCompiler]`, while Rocq's `vm_compute` and `<:` proofs both show "Closed under the global context".

🤖 Generated with [Claude Code](https://claude.com/claude-code)
