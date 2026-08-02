# Handoff: scoped architecture-acceptance review of ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the authoring side. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

**This is not another delta review, and the difference is the point.** Read the scope section before
anything else. If you review this document the way the last eight rounds reviewed it, you will produce
twenty correct findings and make the artifact worse — that is a measured claim, not a figure of
speech, and the measurement is below.

## Mission

Answer one question: **should this ADR be accepted as an architecture decision?**

Not "is every mechanism it names buildable." Not "is every sentence propagated." Those questions were
asked eight times, and asking them a ninth is what this handoff exists to prevent.

## Why the scope is narrow — with the data, so you can judge the narrowing yourself

Between 2026-07-26 and 2026-08-02 this ADR received **19 review sections and 154 findings**: two full
reviews, three verifications, and eight rounds of paired delta review, each answered by a correction
pass. Findings per delta round:

| Round | 2nd pass | 3rd | 4th | 5th | 6th | 7th | 8th |
|---|---|---|---|---|---|---|---|
| Findings | 15 | 12 | 16 | 16 | 17 | 19 | 20 |

**Findings bottomed out at round two and rose monotonically after.** The loop was diverging: each
correction pass introduced defects at roughly the rate reviews retired them. The document is now 9,734
lines, of which 2,095 are body and 7,639 are review commentary. Across 24 commits, **no source
changed**.

The diagnosis and the standing discipline are in
`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`;
the project-specific record is `NOTE-review-loop-retrospective.md`. Read both — they are short, and
they explain why the scope below is what it is rather than fatigue.

**You are explicitly licensed to reject that reasoning.** If you think the narrowing is
goalpost-moving, say so as your first finding and argue it. That is A1.

## In scope

**The architecture: D1–D11, and whether the ADR is acceptable as a decision.**

- **D1** (`:284`) driver-owned, state-threaded world protocol
- **D2** (`:626`) seed-driven discovery, resolved-program replay
- **D3** (`:740`) logical faults as modeled outcomes
- **D4** (`:798`) one monotonic virtual clock
- **D5** (`:1075`) real traced driver under a named conformant profile
- **D6** (`:1490`) one complete terminal trace per run
- **D7** (`:1600`) whole-execution invariants
- **D8** (`:1629`) replay records the program, not the seed
- **D9** (`:1680`) sequential until the production contract changes
- **D10** (`:1692`) existing tests remain; naming changes at the gate
- **D11** (`:1705`) search as a first-class gate

Plus: the *Gate mechanisms: built, and deferred* section, the Status block's blocker framing, the
Alternatives, Consequences, Non-goals, and the acceptance table — insofar as they bear on whether the
decision is sound and internally coherent.

## Out of scope — deliberately, and stated so a "no findings" outcome is possible

- **The three deferred gate mechanisms' internal specification**: classifier 2's matcher, the
  site-to-hook attribution table's schema, the coverage-floor carve-out validation. They are named in
  *Gate mechanisms: built, and deferred* with acceptance criteria; whether each criterion is
  *sufficient* is in scope, whether the mechanism is fully specified is not.
- **Classifier 1's implementation.** It is built (`tools/effect-inventory/derive.py`). Run
  `make effect_inventory` and `make effect_inventory_selftest` if you want to check it does what the
  contract says — that is welcome. Reviewing the prose that used to specify it is not.
- **Wording propagation across sites**, phrase-count claims, and line-wrap. Three rounds were spent
  there. If you find a *substantive* contradiction between two decisions, that is in scope and
  important; if you find the same rule phrased two ways, it is not.
- **Anchor pedantry.** Anchors have been clean for three consecutive passes and re-verified by
  multiple reviewers. Spot-check if you like; do not audit.
- **The upstream API blocker.** External, unchanged, not clearable by anyone here.

## Attack list

### A1. Is the deferral legitimate, or is it moving the goalposts?

The ADR now says three gate mechanisms block *the DST name*, not *this ADR*. That reframing is what
makes acceptance possible, and it was made by the authoring side after eight rounds of not converging.

- Is the line drawn in the right place? A decision doc that names a gate but defers its detector is
  either correctly scoped or hollow, and which one depends on whether the *architecture* stands
  independently of the mechanisms.
- Test it directly: **if all three deferred mechanisms turned out to be unbuildable, would D1–D11 still
  be the right architecture?** If yes, deferral is sound. If no, the ADR is asserting an architecture
  that depends on undemonstrated machinery and should say so.
- Check the acceptance criteria in that section are actually sufficient to discharge each mechanism —
  that is the part of the mechanism layer that remains in scope.

### A2. Do the eleven decisions cohere as one architecture?

The individual decisions have each been reviewed many times. What has been reviewed *least* is whether
they still fit together after nine correction passes, because every round after the third was scoped
to a delta.

- Look for decisions that have drifted apart: D1's world protocol against D5's profile contract; D4's
  clock routing against D5's hermeticity gate; D6's trace parity against D7's invariants; D2's replay
  modes against D8's reproduction artifact.
- The specific seam most edited and least reviewed as a whole: **D1's interim provider-state widening
  and its interaction with D5's extension exclusion rule.** Both were rewritten repeatedly in
  isolation.

### A3. Is anything in D1–D11 unimplementable as stated?

Distinct from "is the detector built". A decision can be sound and still describe something the
substrate cannot do — which is exactly what happened with 004's stream-delta ledger handle, the defect
that motivated this ADR.

- The known substrate limits are recorded: the provider callback's closed effect row, the absent
  virtual clock, the module-cycle constraint on `ProviderState`, and the effect checker's failure to
  propagate through function-valued record fields. Are there decisions that assume something those
  limits forbid?
- `ProviderState`'s home and the bidirectional `model_step` widening were both probe-verified by prior
  reviewers; treat those as settled unless you find a new constraint.

### A4. Is the scope boundary right?

- Physical faults, durability, and concurrency are excluded (D9, Non-goals), bound to accepted 007
  D1.3 with its five reopening triggers carried verbatim. Is the exclusion still coherent given
  everything the ADR now requires?
- Does anything in D1–D11 quietly require a durability or concurrency contract Motoko does not have?

### A5. Does the Status block now describe the state honestly?

It was rewritten to carry one external blocker and to retire a second that regenerated on every edit.

- Is that framing accurate, or does it under-state something real?
- The measured loop data is quoted in the block. Verify the numbers if you want; they are derivable
  from the section headings.

## Settled — do not re-derive

Confirmed across 19 review sections, most by multiple independent reviewers, several by executed
probes:

- **F1–F6** (the vertical-spike findings) and their dispositions; **D6.1**'s zero-`RunSummary` claim;
  the **narrowed D1 blocking clause**; the **upstream return-shape ruling**; **M2**'s ABI-major
  measurement.
- **D4's repo-wide clock count of 13**, "nothing is routed at HEAD", and the pre/post-table
  `5 / 13 / 13` → `4 / 12 / 13` framing.
- **The extension-model-path exclusion** is the right disposition; the **coverage/rejection split's
  timing argument**; **classifier 2's cursor-loss membership criterion**.
- **`ProviderState` in `src/core/ports.ail` is buildable** (two independent three-module probes);
  **`ScriptedStep` must relocate**; the **module cycle** that forces it.
- **The ABI facts**: `ExtensionHooks` is closed, eight hooks, three rowless, `on_budget_plan` at
  `! {Env, FS}`, four at nine effects; a rowless row does **not** bound effects through field calls.
- **Configuration facts**: fourteen configs, all installing `compaction_ai`; `compose` in one;
  `test_dummy` in none; `motoko_ext_conformance` non-registrable.
- **Anchors**, clean for three consecutive passes.

## Leads already checked

- `ExtPorts.clock_now`: zero call sites repo-wide. `.ai_step(`: exactly two.
- `ailang builtins list -json` is byte-deterministic; its `name` is the internal builtin; its `pure`
  contradicts its `effects` on 12 `std/ai` exports.
- `ailang iface` fails `MOD010` on `std/secret.ail` outside a temp directory and auto-relaxes inside
  one — **do not run probes from `/tmp` and conclude the walk is clean**.
- `agents_md.walk_agents` performs `FS` undeclared; v0.26.0 accepts it.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- A stale `.ailang` cache produces phantom type errors; clear it before believing one.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`.

## Output contract

Append a **twentieth** `## Review Comments` section. There are nineteen — count them yourself at the
commit you review.

State your model id, the date, and the commit.

**Lead with the recommendation, not the findings**, because the question is acceptance:

- **Accept** — the architecture is sound and the ADR should move to Accepted, with the external
  upstream prerequisite tracked separately.
- **Accept with conditions** — sound, subject to a named, finite list of changes. State them.
- **Revise** — an architectural defect, incoherence, or unimplementable decision. Name it.

Then any findings, numbered `R1..Rn`, most severe first, each with a one-sentence defect, grounding
(command and output, or `file:line`), and a concrete action. **If you have no architectural findings,
say so plainly and stop.** A short review is a valid outcome here and is not evidence you missed
something — the mechanism layer that generated most prior findings is deliberately out of scope.

Then: what you re-ran and confirmed, and residual risk.

## Constraints

- **Findings only.** Do not modify source, scripts, the Makefile, the spike, other ADRs, or the ADR
  body.
- **Do not re-litigate accepted 007**, and do not re-argue the decision to request an upstream API.
- **Verify by execution** where a claim is checkable.
- **Do not treat the fork prototype as the gate cleared.**
- **Do not treat the throwaway spike branch as HEAD state.**
- **Do not expand scope to the deferred mechanisms.** If you believe the deferral itself is wrong,
  that belongs in A1 as a single argued finding — not as twenty findings against the mechanisms.
