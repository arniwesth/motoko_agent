# NOTE-001: Would Rocq serve this method better than Lean? A port of the worked example

Date: 2026-11-03.
Status: Note. It answers one question the research note did not ask, and changes nothing else.
**Verdict: keep Lean.**
Grounded at: this branch at `12672be8`, code under test at `43530c0a`. Toolchains: Lean 4.28.0;
Rocq 9.3.0 (`rocq-stdlib` 9.2.0, OCaml 4.14.2); bun 1.4.4; ailang v0.54.14. Linux aarch64.
Evidence: `evidence/rocq/` (its `README.md` records the runs).
Companion to: `RESEARCH-lean-harness-properties.md` (§2, §4, §9), `evidence/diff/README.md`
("The three-way run"), `029_cslib_proof_tier/RESEARCH-cslib-implications-for-motoko.md` (§3, the
axiom audit; §9 item 1, MOT-137).

_Written because the operator asked whether Rocq would be a better choice than Lean for this
kind of use. Neither the research note nor Kiro's post compares provers: the post states no
reason for choosing Lean, and the note takes it from the post. This note answers by measurement
where it can. It ports the worked example to Rocq and runs the port through the same
differential test, and it uses the literature only for what one port cannot show._

**This note does not touch PLAN-001.** PLAN-001 compares Lean with executed checks, not with
another prover. Its trial tree is built from its own commit (PLAN-001 §7), so this note and
`evidence/rocq/` are not part of it. No hashed file is edited.

---

## 1. The method, and what it asks of a prover

The research note's method has four steps (§1, §4): a model that follows the source, a
differential test of the model against the real code, a proof or a `bug_` theorem, and a
reproduction on the real code. Around them sit the axiom audit and the people who review
theorem statements. So a prover is judged here on six things:

1. **Proof.** Can it state and prove the properties? Kiro's results suggest induction over lists
   and folds, and closed computations for counterexamples.
2. **Running the model.** The differential test needs the model to run as a program.
3. **The audit.** Can a mechanical check tell a kernel proof from one that trusts something more?
4. **Fidelity.** How closely can a model follow the AILANG it transcribes? A person reads the two
   side by side, and the differential test catches only what its inputs reach.
5. **Agent fluency.** Every model and proof here is written by an agent.
6. **Fit with what Motoko has.** The toolchain, the scratchpad's Lean tier, and the audit.

## 2. Measured: the worked example in both provers

`evidence/rocq/PairingModel.v` ports `evidence/PairingModel.lean`: the same definitions, the same
16 theorems and lemmas, in the same order. `Enumerate.v` ports `enumerate.lean.tail`.
`run_rocq.sh` runs the port against a fresh three-way run of `diff/run_diff.sh`.

| Measure | Lean 4.28.0 | Rocq 9.3.0 | Reproduce |
|---|---|---|---|
| All 16 theorems and lemmas check | yes, about 0.6 s | yes, about 0.35 s | `lean PairingModel.lean`; `run_rocq.sh`, step 1 |
| Axioms of the 8 printed theorems | none, except `host_twin_agrees`: `propext`, `Quot.sound` | none: "Closed under the global context" for all 8 | `#print axioms`; `Print Assumptions` |
| Proof of `host_twin_agrees`, from `err_sticky` on | 108 non-blank lines | 92 non-blank lines | count the files |
| Running the model | `#eval` in the proof file, about 2.4 s | extraction to OCaml, `ocamlopt` and a one-line driver, under 0.5 s | `run_diff.sh`; `run_rocq.sh`, step 2 |
| Its output | `lean.out`, sha256 `c729a3cb…` | `rocq.out`: byte-identical to `lean.out` | `run_rocq.sh`, step 3 |
| Against the real fold | 0 mismatches of 16,105 | 0 mismatches of 16,105 | `compare_fold.awk`; `run_rocq.sh`, step 4 |
| A same-typed field swap in `pairStep` | cannot be written as a reordering: `{ acc with openIds := … }` names the field | type-checks. 517 fold mismatches; 0 host mismatches; the theorems fail | `evidence/rocq/README.md`, negative control |
| A proof by computation, in the assumption report | `native_decide` shows `Lean.ofReduceBool`, `Lean.trustCompiler` | a VM proof is "Closed under the global context" | `evidence/rocq/audit/` |
| Installing without root on this machine | elan downloads a binary; 2.6 GB | m4, GMP and pkgconf built from source first, then opam, OCaml and Rocq: 330 s on 8 cores, 1.4 GB | `install_rocq.sh` |
| Failed compiles writing the port | not known: written in another session | 6 before both files passed | this session |

**The proofs come out even.** The port needed the same lemmas, about as many lines and no
different idea, and both checks take under a second. Rocq's proof of `host_twin_agrees` uses no
axioms where Lean's uses two, but `simp` brings those two in and Motoko's audit allows them
(`STANDARD_LEAN_AXIOMS`), so the difference has no practical effect.

**The caveat on that row.** The port was written with the Lean proofs open beside it. It measures
transcribing a proof from one prover to the other, not finding one from scratch. The six failed
compiles say something about writing Rocq, though. Three of them were `<?` read as string
comparison because `string_scope` was open. Rocq reported each one as `0` not being a `string`.
Two came from the way the Stdlib unfolds `In` (`x = c`, not `c = x`), one of them a wrong fix of
the other. One was `auto` failing to close a premise that needed `right`.

## 3. What decides it

In order of weight.

**3.1 Running the model is the method, and Lean does it in place.** Kiro's step 3 and this
project's `run_diff.sh` depend on the model being a program. In Lean it is: the proof file
appended with a tail of `#eval` prints the lines. In Rocq the same lines take extraction, a
string mapping (`ExtrOcamlNativeString`), an OCaml driver and a compiler. The trust is about
equal, since Lean's `#eval` trusts its compiler and the Rocq route trusts extraction and
`ocamlopt`. The difference is in steps, and it recurs for every model and every change to one.

**3.2 The audit Motoko built needs a report that shows trust.** 029 §7 counts the axiom audit as
one of Motoko's two mechanical substitutes for human review: `#print axioms` catches
`native_decide` every time, because Lean reports it as `Lean.ofReduceBool`. Rocq's
`Print Assumptions` reports a proof checked by the VM, whether through `vm_compute` or a `<:`
cast, exactly as it reports a proof by plain reduction. That is a design choice, not a soundness
problem: Rocq's VM is part of its kernel's conversion check. But a Rocq tier could keep the
equivalent of the `native_decide` ban only by scanning proof text for tactics and casts. That is
the kind of check 029 §7 prefers to replace with a computed one.

**3.3 Fidelity to the source.** AILANG updates records by field (`{acc | open_ids: …}`), and so
does Lean (`{ acc with openIds := … }`). Rocq's Stdlib has no record-update syntax, so each update
restates every field by position. The planted swap of `openIds` and `curIds` type-checked, and the
host-side comparison, the only differential test the worked example had before `eaec951a`, did
not see it. The fold comparison and the theorems did. So the risk is caught, but later and more
expensively than a slip Lean cannot express. Strings lean the same way. §7's targets count bytes
against runes, which is the class of most of Kiro's findings. Lean's core `String` is Unicode text
with `utf8ByteSize`, while Rocq's Stdlib `string` is a list of 8-bit `ascii`, so a model in Rocq
builds the character layer itself. Invalid UTF-8 needs a byte model in either prover.

**3.4 Agent fluency: no evidence that Rocq is better, some that it is behind.** Kiro's results
were produced by Claude Opus 5.5, the model Motoko runs, writing Lean. The specialised provers
all target Lean, and a 2026 Rocq study calls Rocq "a proof assistant that has received far less
attention from the LLM community than Lean". The same study argues that general frontier models
narrow the gap. With MCP tools for Rocq, Claude Opus 4.6 proved 10 of the 12 Putnam 2025
problems, where a Lean agent built on Claude proved all 12. The setups differ, and there is no
controlled comparison. With only the compiler, it proved 81% of miniF2F-Rocq. A benchmark that
states the same 46 problems in both provers (Lean-Rocq-bench) has no results yet. None of this is
about program models of the kind written here.

**3.5 What Motoko already has is Lean-shaped.** That includes:
- the scratchpad's Lean kernel and its tests: `kernel-lean.ts`, `lean-session.ts`, about 780
  lines with their tests;
- `STANDARD_LEAN_AXIOMS` and `classifyTheoremAxioms`;
- `lean4-teach.md`;
- 029's and this project's records, and MOT-137;
- the devcontainer's 4.28.0 toolchain.

Moving would mean rebuilding the tier around `Print Assumptions` (§3.2) and re-running this
project's evidence. Nothing above repays that.

**3.6 Rocq does not make the tier less often dark.** The Lean tier has been unavailable where
`release.lean-lang.org` answers 403 (RESEARCH §6.4; MOT-137). Rocq needs `opam.ocaml.org`,
GitHub and the GNU mirrors. On this machine it also needed m4, GMP and pkgconf built from source,
because there is no sudo and no GMP headers. That is more network and more steps, not fewer.
One option for MOT-137, **not tested** where the 403 occurred: Lean's release tarballs are also
on GitHub (`github.com/leanprover/lean4/releases`), which answered 200 from this machine.

## 4. Where Rocq would be the better choice

Each of these would reopen the question. None holds today:

- **Proofs about concurrent code sharing state.** Iris, Rocq's separation-logic framework, has no
  mature Lean counterpart. Kiro's findings about orders of concurrent events came from Lean core
  models, with no separation logic. This becomes relevant only if a target needs shared
  mutable state across interleavings that a pure transition-system model cannot express.
- **A long-lived, pinned proof set.** Rocq releases about twice a year, while Lean releases
  monthly, and `simp`'s lemma set moves with it. If RESEARCH §10 item 7 (`make verify_lean`,
  proofs pinned by source hash) lands and re-pinning becomes a real cost, measure it then.
- **Property checks inside the prover.** Rocq has QuickChick. Lean's Plausible needs Lake, which
  this project avoids. The method uses `decide` and the differential test for this, so it has not
  been needed.
- **The model as the implementation.** Rocq's extraction is the mature route for that. This
  method models code that exists, so it does not apply.
- **AILANG emitting either prover.** Its documentation mentions neither today (searched for
  "lean", "rocq" and "proof assistant" on 2026-11-03). A translator to Rocq would reverse this note: it would remove step 2's
  hand-writing, the gap RESEARCH §9 names.

## 5. What this note did not verify

- **Writing proofs from scratch in Rocq.** §2's line counts and failed compiles come from
  transcription, with the Lean proofs at hand.
- **A larger model.** The worked example's Lean file is about 300 lines, with comments. Larger
  targets (PLAN-001's T3 is the largest) could separate the provers on automation: Lean's `grind`
  and `omega` against Rocq's `lia` and its external hammers. Not measured.
- **`native_compute` in the assumption report.** This build has the native compiler disabled, so
  only the VM was tested.
- **Agent fluency.** §3.4 rests on published, uncontrolled comparisons, on mathematics rather
  than program models.
- **The GitHub route around the 403.** Reachable from this machine; not tried from a sandbox that
  got the 403.
- **One machine.** The timings and the install are from one linux aarch64 container with 8
  cores.

## Sources

- Kiro, *Kiro proves properties of its own harness in Lean*, 2026-11-02: https://kiro.dev/blog/harness-properties-in-lean/
- *Putnam 2025 Problems in Rocq using Opus 4.6 and Rocq-MCP*, arXiv 2603.20405: https://arxiv.org/abs/2603.20405
- Lean-Rocq-bench: https://github.com/LLM4Rocq/lean-rocq-bench
- Rocq 9.3.0 release: https://github.com/rocq-prover/rocq/releases/tag/V9.3.0
