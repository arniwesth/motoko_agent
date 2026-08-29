# Research: CRIS (PLDI 2026) and its implications for Motoko's verification story

Date: 2026-08-23. Status: research note, no code changes proposed yet beyond the ranked
follow-ups at the bottom. Source paper: `papers/3808317.pdf` — Kim et al., *CRIS: The Power
of Imagination in Hybrid Verification*, Proc. ACM Program. Lang. 10 (PLDI), Article 239,
June 2026. doi:10.1145/3808317. Rocq artifact: doi:10.5281/zenodo.19491861.

Companion to: `design_docs/planned/m-motoko-verify-ail.md` (the `verify.ail` plan — see
"Relation to m-motoko-verify-ail" below), `.agent/projects/011_improve_test_axises/`
(the substrate-versus-oracle finding this note leans on), `src/core/dst_invariants.ail`,
`src/core/dst_replay.ail`.

_Written because the obvious reading — "a Rocq separation-logic paper, irrelevant to an
agent harness" — is wrong in an instructive way: the paper formalizes exactly the setting
Motoko lives in, its machinery does not transfer, and its **soundness arguments** do. The
useful output is one named gap in the DST framework and two design decisions the paper
retroactively justifies._

## 1. What the paper is

CRIS is a Rocq-mechanized framework for **hybrid verification**: formally verify a critical
module, *abstract it away*, and leave a simplified top-level program in which the rest of the
system — unverified code with arbitrary side effects (I/O, divergence, reentrancy into the
verified module, crashes) — is tested or model-checked instead of proved. The end-to-end
statement is behavioral refinement:

```
Beh(I_Main ∘ I_Cell ∘ I_Ctx) ⊆ Beh(T_Main ∘ I_Ctx)
```

where `I_Cell` is the verified module (abstracted away entirely on the right), and `I_Ctx` is
arbitrary unverified context. Testing then happens against the *simplified* right-hand side.

Its technical novelty is the **imaginary specification**: a spec that is itself an executable
program, freely mixing code with ownership assertions. Four primitives: `take`/`choose`
(angelic/demonic nondeterminism — intersection/union of behaviors) and `Assume`/`Guarantee`
(acquire/release ownership of separation-logic resources against a single global resource
repository). The motivating problem: a verified library takes a callback that will never be
verified, only tested. Pre/postconditions cannot say "the stored value is whatever the
callback returned" without *assuming* a spec for the callback — which is undischargeable when
the callback is only tested. An imaginary spec embeds the call to the callback inside the
specification itself and quantifies over all its possible returns.

Three secondary results worth naming because they map onto Motoko decisions:

- **§4.3 sandboxing**: module-local state is protected by scope checks *baked into function
  bodies at translation time*, so inlining a spec into another module cannot bypass them.
  Contextual refinement quantifies over context code *before* the sandboxing pass, so the
  sandbox binds arbitrary unverified context too.
- **§6 counterexample**: module-local invariants are **unsound** the moment unverified
  context can touch the module's private state. Their exact sentence: "in a hybrid setting
  where context code is unverified, any unprotected state can be arbitrarily modified by the
  context, invalidating the abstraction." Physical protection is a *precondition* for logical
  reasoning, not hygiene.
- **§5.3 cancellation theorem side condition**: eliminating the imaginary layer requires that
  context functions "invoke no function with a non-trivial precondition" — unverified code
  must not be able to call entrypoints whose correctness assumes a disciplined caller.
- **§7 hybrid memory spec** (`H_Mem`): one module can carry both a declarative
  ownership-based spec and a concrete operational model, with the client choosing per call
  via a `take` branch — and the two are provably consistent because they live in one artifact.

## 2. Verdict

**Near-zero direct adoptability, high structural relevance.** CRIS assumes a proof assistant
(interaction trees, Paco coinduction, Iris resource algebras) and expert users; angelic
nondeterminism is explicitly not implementable (the paper restricts `take` to the imaginary
layer for exactly this reason). There is no "integrate CRIS" story for AILANG.

But Motoko's premise — a harness aiming at self-verifying software while orchestrating
LLM-generated, fundamentally unverifiable code performing arbitrary I/O — *is* the hybrid
verification setting. The unverified callback `cb` in the paper's Cell example is a tool call
or an LLM invocation, literally. And on inspection, the DST framework already implements most
of the CRIS architecture informally, which makes the mapping worth writing down precisely:
it identifies the one edge the current setup does not check.

## 3. The mapping: Motoko already has the CRIS shape

| CRIS concept | Motoko artifact |
|---|---|
| Pure abstraction `A` of a module | `step_machine.decide` — pure `StepState → StepDecision` |
| Implementation `I` wrapping it | `session.ail` — imperative shell owning the real effect row |
| Unverified context `I_Ctx` | The LLM, tools, filesystem, extensions — everything behind ports |
| Executable model of the environment | The DST scripted world: `dst_generator` draws + `dst_fault_catalogue` + recorded outcomes served through port adapters (`ports.ail`) |
| Dual nondeterminism (`choose` over outcomes) | `draw`/`bounded_draw` in `dst_generator.ail` — seeded choice over the fault space |
| Behavioral properties over `Beh(A ∘ M)` | The twelve invariant families in `dst_invariants.ail`, judged over (outcome, complete trace) |
| Pre/postcondition layer on pure code | AILANG `requires`/`ensures` + Z3 (`make verify_core`) |
| Module-local invariant | "session.ail is the sole emitter of ledger events" (`session.ail` header) |
| CRIS scope-based sandboxing | AILANG effect rows + the curated `ExtPorts` surface (`ext_ports_of`) |
| Cancellation side condition | The ext ABI exposing only entrypoints safe for arbitrary callers |

Two places where the codebase does what the paper argues for, by different means:

- The pure-core/effectful-shell split discharges CRIS's `I ⊑ A` obligation **by
  construction** (the shell calls `decide`; there is no second implementation to relate)
  rather than by simulation proof. Cheaper, and adequate for this architecture.
- DST tests the abstracted composition with injected faults — exactly the paper's "test the
  simplified top-level program, because testing at this level is more efficient than testing
  against the original implementation."

## 4. The gap: the refinement edge nobody checks

Every DST conclusion is a statement about `harness ∘ ModelWorld`. For those conclusions to
transfer to production, the CRIS-style side condition must hold:

> **Beh(RealWorld at the port boundary) ⊆ Beh(ModelWorld).** The scripted world must
> *over-approximate* reality: every outcome shape the real environment can serve must be
> expressible by the fault catalogue and generator bounds.

This is the classic DST failure mode — the mock is narrower than reality, so the tested
universe silently excludes real behaviors — and it is **not** what strict replay checks.
`dst_replay.ail`'s own header says it precisely: program-vs-log agreement is "the recorder
grading itself, one level up." Replay certifies *determinism of the recorded universe*; the
discovery witnesses and balance checks catch *dropped classes*. Neither catches *outcome
shapes reality produces that the catalogue cannot express*. The replay header's three
self-identified blind spots are all instances of this second question.

The paper's general move — discharge by testing what you cannot prove — gives the obligation
a cheap concrete form, and `Interaction` (`dst_interaction.ail`) is already the right
currency for it.

### Proposed: a "model admits reality" invariant family (admission suite)

For each interaction class, a total admission function from a recorded **live** outcome to a
verdict: could the scripted world, under *some* generator choice within declared bounds, have
served this outcome?

```ailang
-- src/core/dst_admission.ail (sketch)
export pure func admits_provider(bounds: GeneratorBounds, o: TimedOutcome) -> AdmissionVerdict
export pure func admits_tool(bounds: GeneratorBounds, o: TimedOutcome) -> AdmissionVerdict
-- ... one per Interaction identity class, mirroring dst_interaction's vocabulary
```

Driver shape: record a live run through the existing recording adapters, then fold
`admits_*` over the interaction log. Any `Inadmissible` is a **model-completeness bug** —
reality produced something DST's universe excludes — and becomes a fault-catalogue extension,
with its own named rule per the one-constructor-per-rule discipline `dst_invariants.ail`
already enforces (cluster 12's lesson applies here unchanged).

Notes on shape, all load-bearing:

- **Direction matters.** It is a membership check ("could the model have served this?"),
  never equality. The model is *allowed* to be more nondeterministic than reality — that is
  the point of a model. Reality ⊆ model is the obligation; model ⊆ reality is not.
- **It is sampled, not proved.** Pointwise admission of recorded live traces is the testable
  shadow of the refinement side condition. That is the hybrid stance, stated honestly.
- **It separates two questions the current setup fuses.** Strict replay answers "is the
  recorded universe deterministic?"; admission answers "is the modeled universe big enough?".
  Different failure modes, different rules, different fixes.

## 5. The imaginary-spec lesson: the only sound spec for the LLM is "any value"

CRIS's central argument — you cannot assume pre/postconditions for a callback that will only
ever be tested — applies to the LLM in Motoko's loop verbatim. The consequence in their
framework: the spec embeds the call and quantifies over *all* possible returns; properties
must survive arbitrary callback behavior.

Applied here: the generator's fault choices (`ToolChoiceOk/Failed/Mismatch/Late`, bounded
chunk draws) model the *envelope* of provider behavior — timing, failure, chunking. The open
question is whether the **payloads** (message content, tool-call structure) are drawn
adversarially or only from recorded/plausible shapes. The CRIS lens yields a crisp
classification rule for the twelve invariant families:

- An invariant that holds for **all** provider outputs — malformed tool calls, tool names not
  in the catalog, injection-shaped content, empty/huge payloads — is a real harness property.
- An invariant that holds only for well-behaved provider output is a **specification bug**:
  it smuggles an undischargeable precondition about the LLM into the harness spec, the exact
  move the paper shows is unsound in hybrid settings.

Executable form: an "adversarial payload" generator mode, then run the invariant suite and
sort the twelve families into the two buckets by what goes red. Anything in the second bucket
either gets weakened or gets a runtime guard promoted into the shell — the latter being the
correct fix, since if a property needs its input well-formed, the shell must *make* it
well-formed.

## 6. Module-local invariants and the ledger: §6 applies verbatim

All twelve invariant families are judgments over the ledger trace, and replay depends on it
too. So **"the ledger trace faithfully reflects execution"** is the invariant under the
invariants — and it is module-local to `session.ail` ("sole emitter of ledger events"). By
the paper's §6 argument, its soundness condition is that nothing reachable by extensions or
tools can emit or mutate ledger events. That is a property of effect rows and the
export/import graph, not of any test, and today it lives as prose in a module header.

Executable form, in the same spirit as `display_only_baseline()` pinning variants by name:
pin, by name, the set of modules that can reach ledger emission, and fail loudly when the set
grows. `ExtPorts` (`ext_ports_of` in `session.ail`) is the choke point to assert this at —
it is the Motoko analog of CRIS's translation-time scope checks, and the audit is that
nothing leaks around it.

Same argument, one level up, for the cancellation-theorem side condition: extensions must not
be able to invoke shell-internal entrypoints whose correctness assumes shell-only invocation.
The curated ABI surface *is* that proof obligation, so it deserves its own pinned-set check.

## 7. Hybrid specs: keep the mock and the contract from drifting

The paper's `H_Mem` shows one artifact carrying both a declarative spec and an operational
model, consistent by construction. The Motoko analog is modest but real: where a port class
has both a scripted adapter (DST) and a declarative contract (`requires`/`ensures`, or a
future `verify.ail` check), derive both from one shared validity predicate. The standard
failure mode of simulation testing is the mock and the contract evolving independently until
the mock validates what the contract forbids; a shared predicate makes that drift a type
error instead of a latent bug.

## 8. Relation to m-motoko-verify-ail

`design_docs/planned/m-motoko-verify-ail.md` proposes replacing `seed/verify.sh` with
type-checked, effect-bounded `verify.ail` modules returning structured `VerifierResult`s.
This note is complementary, not competing, and supplies the missing "why" for its position in
the verification stack:

- `verify.ail` checks are **post-condition checks on an artifact** (the WORKDIR after a run)
  — the pre/postcondition layer of the hybrid story.
- DST invariants are **behavioral properties of the harness against a model world** — the
  refinement layer.
- The admission suite (§4) is the **edge between the model world and the real one** — the
  side condition that makes the refinement layer's conclusions transfer.

All three are needed; CRIS is the framework in which their composition is sound. Two concrete
touchpoints for when M-MOTOKO-VERIFY-AIL is picked up:

1. The proposed `motoko/verify` library's common checks (`file_exists`, `type_checks`,
   `make_target_passes`) should grow an `admission_holds(recorded_run)` check so dogfood
   tasks can assert model completeness as a first-class verification stage.
2. The design doc's goal 3 ("verify runs appear as chain stages in `ailang chains view`")
   applies unchanged to admission runs: an inadmissible live outcome is exactly the kind of
   finding whose provenance is worth querying across model runs.

## 9. Ranked follow-ups

1. **Admission suite** — `src/core/dst_admission.ail` plus a `make` target that grades a
   recorded live run. Closes the one genuinely unchecked edge; everything it needs
   (recording adapters, `Interaction`, `GeneratorBounds`, the named-rule discipline) exists.
2. **Adversarial-payload generator mode** plus triage of the twelve invariant families into
   "holds for arbitrary LLM output" vs. "assumes well-formed output." Cheap to run; every
   finding is either a weakened invariant or a promoted runtime guard.
3. **Pinned emitter-set invariants** for ledger emission and shell-internal entrypoints —
   turns the two load-bearing soundness assumptions from module-header prose into red/green
   checks.

None of this requires Rocq, new AILANG features, or blocking on the `ailang verify` runtime
mode. It is all expressible in the existing DST idiom.

## 10. What deliberately does not transfer

Recorded so it is not re-litigated: Rocq mechanization and simulation proofs (no proof
assistant in the loop); angelic nondeterminism at runtime (not implementable, per the paper
itself); Iris resource algebras as a capability mechanism (AILANG effect rows + curated ABI
surfaces are the working analog); imaginary specifications as a user-facing artifact (the
executable-model *stance* transfers; the `Assume`/`Guarantee` machinery does not). The
paper's Rocq artifact is worth a skim only as a reference for what executable-spec style
looks like in practice — ITrees extract to runnable OCaml, the closest existing thing to
"specs you can run tests against."
