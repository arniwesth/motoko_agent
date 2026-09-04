# Research: CSLib (arXiv 2602.04846) and its implications for Motoko's proof tier

Date: 2026-09-02. Status: research note. No code changes proposed beyond the ranked
follow-ups at the bottom; one **live defect found while checking a claim** is recorded in §4
and needs chasing independently of this note. Source paper: Barrett, Chaudhuri, Montesi,
Grundy, Kohli, de Moura, Rademaker, Yingchareonthawornchai, *CSLib: The Lean Computer Science
Library*, arXiv:2602.04846v1 [cs.LO], 04 Feb 2026. CC BY 4.0. Read from the arXiv HTML
rendering; no artifact exists to evaluate.

Companion to: `.agent/projects/023_hybrid_verification_cris/` (same reading pattern; its §8
verification-stack layering is the frame this note extends), `.agent/projects/027_z3_contracts/`
(ADR-001, the contract classification register), `.agent/projects/028_verified_runtime_closing_the_loop/`
(NOTE-002's fold wall, NOTE-005 finding 6), `src/tui/src/scratchpad/lean-session.ts`,
`src/tui/src/scratchpad/kernel-lean.ts`, `Makefile:2404` (`verify_core`).

_Written because the obvious reading — "a white paper announcing a Lean library, nothing to
adopt" — is only half right. There is nothing to adopt: CSLib is a few months old, ships a
prototype, and its 2027 claims are intentions. But Motoko **already runs a Lean 4 kernel with
a Mathlib mode and an axiom-audited commit gate**, and that tier is dark. The paper's value is
not its library; it is that its **Pillar-2 architecture is the named fix for the exact failure
mode 028 spent three sessions characterising** — a verifier that cannot distinguish "your code
is wrong" from "I could not decide". Checking that claim against the live tree turned up an
instance of it in `make verify_core` itself._

## 1. What the paper is

A white paper, not a results paper. CSLib is "for computer science what Mathlib is for
mathematics", on two pillars:

- **Pillar 1 — formalise CS in Lean.** Models of computation (deterministic, nondeterministic,
  probabilistic, quantum), operational semantics, program equivalences, automata, linear logic,
  concurrency, and specification notations (temporal, Hoare, separation, linear logic). The
  paper's two concrete artefacts are Fig. 2 — `structure LTS (State) (Label)` plus
  `LTS.IsBisimulation` and a theorem that bisimulation inverses are bisimulations — and Fig. 3-4,
  a `TimeM` cost monad that carries `⟨ret, time⟩`, sums cost through `bind`, and lets
  `mergeSort` be given both `mergeSort_correct` and `mergeSort_time ≤ n * clog2 n`.
  Complexity as a *computational effect*, so correctness and cost analysis stay orthogonal.
- **Pillar 2 — Boole.** A Boogie-style intermediate verification language, deeply embedded in
  Lean via Strata, with `requires` / loop `invariant` / named `assert`. `# prove_vcs` generates
  **Lean goals**, discharged by "hammers" — today the `smt` tactic (Lean-SMT translates the
  goal, calls a solver, gets a certificate, **replays it step-by-step in Lean**), tomorrow
  AI-based ones. The long game is formalising the semantics of Rust/C++/Python in Lean and
  translating real code into Boole (the Aeneas pipeline as the model).

Stated design principles worth quoting because they are what transfers: Boole should read like
pseudocode; transpilation and VC generation minimise the trusted computing base; **VCs are Lean
goals, human-readable and traceable to the code they came from**.

§3 is the AI section: CSLib as training data for provers, provers bottlenecked by available
abstractions, and — the sentence that matters here — the mitigation for AI-generated
formalisations being buggy or incomprehensible is that "AI tools play only an advisory role"
and everything committed goes through "a manual, Github-based code review process."

Roadmap: end-2026, undergraduate-level Pillar 1 plus a Boole that robustly generates Lean VCs
and drives SMT hammers. End-2027, complexity/concurrency/secure compilation, separation logic
in Boole, "at least one substantially sized real-world system" verified end-to-end.

## 2. Verdict

**Nothing to adopt today; one architectural idea that lands on an open 028 problem; and a
precondition Motoko should fix regardless of this paper.**

This is the inverse of the CRIS reading (023: "near-zero direct adoptability, high structural
relevance"). CSLib's *structure* is unremarkable — Boogie has done VC generation since 2005.
What makes it worth a note is that Motoko is one of the few agent harnesses that has already
built the consumer side: a Lean 4 REPL kernel, a Mathlib mode, `sorry` detection, an axiom
audit, and a commit gate that refuses to admit a cell whose proof did not verify. Motoko does
not need CSLib to use that tier. It needs the tier to be *switched on*, and CSLib is a reason
to expect the tier's ceiling to rise over the next 18 months.

## 3. The thing this repo already has (and is not running)

`src/tui/src/scratchpad/` contains a full Lean rung, and it is more disciplined than the
paper's own governance answer:

| Mechanism | Location |
|---|---|
| Lean REPL kernel, per-session env commit | `kernel-lean.ts`, `lean-session.ts:196` (`LeanSession`) |
| Mathlib as a separate Lake project + per-cell flag | `env-server.ts:818-845`, `mathlib: true` per cell |
| Declaration parsing; anonymous `example` cannot be audited | `parseLeanCell`, `hasAnonymousExample` |
| `sorry` detection (REPL sorries *and* message text) | `hasSorry` |
| Axiom audit against a pinned allowlist | `STANDARD_LEAN_AXIOMS = {propext, Classical.choice, Quot.sound}`, `classifyTheoremAxioms`, `unexpectedAxioms` |
| Fail-closed admission | `decideLeanCommit` — `prove: "required"` refuses to commit unless a **named** theorem reaches `proof === "verified"` |
| The agent-facing contract | `lean4-teach.md`: no `sorry`, `admit`, custom `axiom`, or `native_decide`; "proved only when `metadata.lean.proof` is exactly `verified`" |

**Status today: dark.** `which lean lake elan` returns nothing in this container, and
`~/.local/share/motoko-lean-mathlib` does not exist. This is the third independent
confirmation: NOTE-002 defect 3 (`[x-confirm]`, two sessions) recorded "Lean/Lake unavailable;
cells were skipped", and the consequence it named — "proof-tier claims must degrade to
model-checking" — is exactly NOTE-005's governing disease: **absence renders as health**. A
skipped Lean cell is not a red mark anywhere; it is silence.

So the first-order implication of CSLib for Motoko has nothing to do with CSLib. Motoko's
highest verification rung is a tier that reports nothing when it is missing, and no gate
counts its absence. `verify_core` learned this lesson for contracts — `unstated` **fails**
because "an incomplete annotation reads as specified and is checked by nothing"
(`Makefile:2470`). The Lean tier has not learned it.

## 4. Boole vs. `ailang verify`: the failure mode is the whole finding

This is the transferable idea, and it is one sentence:

> **AILANG's verifier's failure mode is *no obligation*. Boole's failure mode is *an
> unproved obligation*.**

`verify_core`'s taxonomy already names the problem it cannot solve (`Makefile:2404-2418`).
A contract whose `ensures` the Z3 fragment rejects — `NOT_PURE`, `RECURSIVE`, `HIGHER_ORDER`,
`UNENCODABLE_TYPE`, unencodable builtin — becomes `blocked`: "Reported, never fails — failing
here would punish the attempt and make deleting the contract the cheapest route to green."
That policy is correct *given the architecture*. It is also an admission that when the solver
declines, the specification evaporates. Live, this run:

```
~ src/core/compress.ail (1 proven, 1 blocked)
    compress_output: uses an unencodable builtin: std/string.split
verify_core: 11 contracts proven, 0 unstated, 1 blocked; 0 files failed, 48 bare
verify_core: pinned classification -- 9 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified
```

Under a VC-generating architecture, `compress_output`'s `ensures` would not evaporate; it
would be a Lean goal that `smt` fails to close and that sits there, open, as a `sorry` — the
difference between *nothing was checked* and *something is outstanding*. Two places where this
distinction is load-bearing in the current tree:

1. **The fold wall (NOTE-002).** `compaction.ail:16,24,100,106` still carry
   `-- contracts: SKIPPED — uses foldl (Z3 fragment requires non-higher-order)`. NOTE-002
   proved that annotation stale — the real cause is gate ordering (`verify.go` runs the
   callee-sort gate before `InlineHOFCalls` can specialize), and the fix W1-W4 is re-wiring.
   Fine. But the *residue* after W1-W4 — genuinely recursive specifications over lists — is
   permanent for an SMT-only path, and it is the core's own idiom. That residue is a Lean
   goal by induction, and Motoko has a Lean kernel to adjudicate it in.
2. **NOTE-005 finding 6.** "A recursive function with a **true** contract rejected as
   'verifier found a counterexample', where `verify_core` would call the same condition merely
   `blocked`." NOTE-005's own prescription — "fail-closed... has to be able to say 'I could
   not decide' as loudly as 'this is broken'" — is a *three-valued verdict*, and in the
   paper's design that is structural rather than a policy bolt-on: VC generation and VC
   discharge are different steps, so an undischarged goal is never attributed to the code.

**A live instance, found while checking the numbers above.** `make verify_core` is
**nondeterministic**. On the first of three consecutive runs, same tree, no edits between
runs:

```
run 1:  ✗ src/core/agents_md.ail (verifier ERROR)      -> 10 proven, 1 files failed, exit 1
            ! ERROR is_root
run 2:  ✓ src/core/agents_md.ail (1 proven)            -> 11 proven, 0 files failed, exit 0
run 3:  ✓ src/core/agents_md.ail (1 proven)            -> 11 proven, 0 files failed, exit 0
```

Run directly, `ailang verify src/core/agents_md.ail` returns `✓ VERIFIED is_root [14.4ms]`,
rc=0, and 20 consecutive standalone runs are clean. `is_root`'s contract
(`agents_md.ail:79-91`) is fine. Extended to nine `make verify_core` runs: 1 red, 8 green.

The non-determinism itself is still undiagnosed. **The mechanism that turns it into a red
build is not.** `ailang/cmd/ailang/verify_print.go:57-58` prints `error` and `unknown` through
the same branch:

```go
case "error", "unknown":
    fmt.Printf("  %s %s\n", red("! ERROR"), bold(r.Function))
```

Z3's `unknown` — *I could not decide* — is rendered identically to a genuine solver failure,
and `verify.go:432-436` folds it into the same `errCount`. `verify_core` greps the human text
for `ERROR`, so it cannot tell them apart, and exits 1. The observed failure printed
`! ERROR is_root` with **no reason line**, while both real error paths always set one
(`verify.go:395,407`) — which points at `unknown` rather than `error`, though it does not
prove it. (The obvious "5s per-function Z3 timeout" explanation, `verify.go:25`, is *not*
supported: `ailang verify --timeout 1ms` still returns `✓ VERIFIED`.)

So: **a solver shrug is surfaced to the operator as a red build attributed to a file whose
contract verifies** — finding 6's conflation, on the AILANG side, in a gate, one level above
where 028 observed it, and with the line of Go that does it now identified. Fixable on the
Motoko side without ever reproducing the flake: `ailang verify --json` keeps `unknown` and
`error` as distinct per-function `status` values. Filed as **MOT-138**; not a CSLib matter.

## 5. Cost semantics: `TimeM` and `cost_phase.ail`

Fig. 3's `TimeM` and `src/core/cost_phase.ail` are the same idea in different currency —
Motoko counts millicents and tokens where CSLib counts comparisons — and the paper's honesty
about its own limitation is the part worth importing:

> "it relies on manual tick annotations that a user could accidentally get wrong rather than
> automated verification of execution costs."

That is Motoko's disease verbatim, with the annotation living in a model catalogue rather than
a `tick`. NOTE-005 finding 1: a missing catalogue row resolves the context limit to 0 and
every consumer reads 0 as healthy. The cost layer has the same shape one door down —
`cost_cap_exceeded` (`cost_phase.ail:16`) returns false unless
`rates.input_per_1m_millicents > 0`, so a model with no rates row cannot trip its own cost cap.
That is very likely deliberate (do not cap on a number you do not have) and is **not** claimed
here as a defect; it is flagged as the same "absent datum reads as healthy" pattern, in the
subsystem whose annotations nothing validates, and worth one deliberate look.

The genuinely transferable move is the *orthogonality*: `TimeM` keeps `mergeSort_correct` and
`mergeSort_time` as separate theorems over one artefact. If the Lean tier comes back, the
first cost-shaped propositions worth stating are Motoko's own unchecked ones — that compaction
strictly reduces history length, that the step machine terminates within `max_steps`. 027's
ADR-001 recorded two `@verify(depth: 1)` predicates under a banner no tool read, "one claiming
a termination guarantee nothing has checked"; those annotations are gone from the tree now
(`grep -rn "@verify" src/` is empty), which is the right outcome — but the *claim* they made
was never adjudicated, only deleted.

## 6. Pillar 1 and the 023 admission obligation

CSLib's first concrete formalisation is `LTS` + `IsBisimulation`. Motoko's core is a labelled
transition system: `step_machine.decide : StepState → StepDecision`, pure, and NOTE-002 drove
it offline through `RunTools → CallModel → Finalize(model_stop)` with a sealed `History` type
enforcing the system-head-prefix invariant by construction.

023's one named gap is a refinement statement — `Beh(RealWorld at the port boundary) ⊆
Beh(ModelWorld)` — and refinement/simulation is precisely what Pillar 1 sets out to make
generically available. The honest reading: **CSLib does not change 023's answer.** The
admission suite is still the right instrument, because it is cheap and it runs. What CSLib
changes is the long-run price of the expensive answer, and it supplies vocabulary
(`IsBisimulation` and its inverse theorem) for stating the obligation precisely if anyone ever
wants to.

## 7. Where Motoko is ahead of the paper

Worth recording, because it is a contribution *out*, not in.

CSLib's §3 mitigation for AI-generated formalisations — "AI tools play only an advisory role"
plus manual GitHub review — is unavailable to Motoko by construction: the README's Phoenix
Architecture rule is *no human written code allowed*. Motoko therefore had to build mechanical
substitutes for review, and it has two the paper does not discuss:

1. **The axiom audit.** `classifyTheoremAxioms` against `STANDARD_LEAN_AXIOMS` catches exactly
   the class CSLib worries about — a proof that is sound-looking but leans on `sorry`,
   `native_decide` (which pulls `Lean.ofReduceBool`), or a fresh `axiom`. A reviewer reading
   Lean tactic soup catches this unreliably; `#print axioms` catches it every time. If CSLib's
   flywheel works, its own review process is the bottleneck that binds, and this is the cheap
   mechanical filter.
2. **The computed classification register** (027 ADR-001). Its finding is directly adverse to
   CSLib's governance answer: a hand-maintained register "cannot validate its own labels" —
   "an editor changes the contract and the label together, which is not even an attack, it is
   the normal workflow" — so the class of every contract is *computed by Z3* (two mutation
   probes: is the contract a tautology on the real domain; does it merely restate the body)
   and pinned, with `verify_classify_check` failing on disagreement in either direction. That
   is a working answer to "how do you tell whether an AI-written specification says anything",
   at 0.25s per contract, and it does not depend on a human reading the proof. Live today:
   11 proven, of which only **9 substantive** — the gap between those two numbers is the whole
   point, and a proven-count metric would have hidden it.

## 8. The ceiling, stated plainly

The seductive misreading is "CSLib means we could prove `session.ail` correct." No.

Pillar 2's pipeline is: formalise a language's semantics in Lean → translate its code into
Boole → verify. The paper names Rust, C++, Python, and cites Aeneas. **AILANG has no Lean
semantics and no plausible route to one** — it is a research language whose ecosystem is this
repository. Motoko's source is structurally outside CSLib's Pillar-2 scope, permanently, and
no amount of CSLib maturity changes that.

What the Lean tier can therefore ever adjudicate is a **hand-transcribed model** of an AILANG
function, not the function. The transcription is unverified, and that gap must be recorded
wherever a Lean verdict is cited, or the tier becomes exactly the kind of verification-shaped
surface whose green is not evidence that 027 ADR-001 was written about. It is the same
abstraction obligation CRIS names, discharged by inspection rather than by proof — acceptable,
provided it is *named*, and dishonest if it is not.

There is one route that would change this, and it belongs upstream rather than here: **have
`ailang verify` lower contracts to a VC generator with a fallback goal, instead of an SMT-only
path.** Same Z3 hammer for the easy cases; every fragment rejection becomes an open obligation
rather than a skip. That is a large ask of a small language and is recorded as a direction for
the `ailang-feedback` channel, not as a bug and not as a plan.

## 9. Ranked follow-ups

1. **Make the Lean tier's absence a counted state, not silence.** — filed as **MOT-137**
   (`arniwesth/mot-137-lean-proof-tier-report-unavailable-as-a-counted-state-not`). Today `which lean` is empty
   and nothing is red. Mirror `verify_core`'s unstated/blocked split: a `verify_lean_tier`
   target that runs one `theorem t : 1 = 1 := rfl` at `prove: "required"` and reports
   `verified` / `refused` / **`unavailable`** as three distinct outcomes, with `unavailable`
   named in a `KNOWN_RED`-style declaration rather than absent from the output. Independent of
   CSLib; it is NOTE-002 defect 3 and NOTE-005's governing pattern, and it is the precondition
   for items 2-4.
2. **Stop `verify_core` failing on an undecided verdict (§4).** — filed as **MOT-138**,
   priority High. One red in nine identical runs, resolving in the direction of accusing
   correct code; the flake is unreproduced but the conflation that weaponises it is in
   `verify_print.go:57` and the fix (`--json`, branch on per-function `status`) is ours to
   make. A gate that intermittently says "your code is wrong" when the solver shrugged is
   worse than a missing gate, because it teaches the loop to rewrite what was right. Not a
   CSLib item; listed here because this note is where it was found.
3. **Adopt the three-valued verdict at the verification surface.** `decided-true` /
   `decided-false` / `undecided-at-this-rung`, distinct in the exit code and in the text an
   agent reads. This is NOTE-005 finding 6's fix; CSLib is the reference for why the split is
   structural rather than cosmetic. Needs no CSLib and no new machinery.
4. **Route the `blocked` residue to the Lean rung, once (1) holds.** Start with one contract —
   the `compaction.ail` fold residue that survives W1-W4, or `compress_output`'s
   `std/string.split` obligation — hand-transcribe it as a named Lean theorem, let the
   axiom-audited kernel adjudicate, and record the transcription gap (§8) in the same artefact.
   One worked example is worth more than a policy; if it costs more than an afternoon per
   contract, the answer is that this rung stays reserved for the few obligations that carry
   real weight.
5. **Register the paper and set a re-read trigger.** Row added to `papers/README.md` under
   Formal Verification. Re-read when Boole's VC generator ships against the paper's own
   end-2026 milestone ("robust capabilities for generating Lean-language verification
   conditions and interacting with SMT-based hammers"), and when CSLib's Mathlib-dependency
   story is stable enough to be a Lake dependency in `motoko-lean-mathlib`. Until then, CSLib
   is a plan, and a plan is not evidence.

## 10. What deliberately does not transfer

Recorded so it is not re-litigated. **Boole as it stands** — a prototype; Fig. 7's generated
VCs for a four-line loop sum are nested `if`-conditions that already violate the paper's own
design principle (iii) that VCs be "intuitive for humans to read". **Pillar 1's algorithm
library** — Motoko orchestrates code, it does not implement mergesort; the models-and-logics
half is the relevant half. **The community and governance model** — a steering committee and
Zulip channel are not a mechanism this repo can use, and §7 argues Motoko's mechanical
substitutes are the stronger form for an autonomous loop anyway. **The roadmap claims** — "at
least one important foundational discovery by end-2027" is an intention in a white paper, and
citing it as evidence would be the exact vacuity 027 ADR-001 was written to prevent.
