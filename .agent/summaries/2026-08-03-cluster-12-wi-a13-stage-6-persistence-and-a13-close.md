# 2026-08-03 Cluster 12: WI-A13 stage 6 — D8's persistence obligations, and the close of WI-A13

## Context

Branch: `arniwesth/mot-51-execute-wi-a13`

Session span: `58d2c20` → `e70d8f4`, **3 commits**, two of them production source. Input was
`HANDOFF-execute-a13-stage-6-persistence.md`, executed cold against HEAD. Twelfth code session of
project 009, following clusters 1, 4, 6, 3, 2, 5, 7, 8, 9, 10 and 11.

Re-grounding first, as the handoff instructed: `git diff --stat ad03ab5..HEAD -- src packages scripts
Makefile` was **empty**, so the handoff's verified-input table held without re-measurement. The
handoff's starting-position claim was also re-verified rather than trusted — `grep -rln
'writeFile\|readFile' src/core/dst_*.ail scripts/dst/*.ail` returned nothing, so the encoding and the
storage path were genuinely built from zero.

**Full completion of the stage, and of the item.**

| | |
|---|---|
| Stage 1 — types + pure structural validator | landed (cluster 7) |
| Stage 2 — discovery recording against `driver_only` | landed (cluster 8) |
| Stage 3 — strict replay | landed (cluster 9) |
| Stage 4 — the seeded generator | landed (cluster 10) |
| Stage 5 — regression replay + D8's generator canary | landed (cluster 11) |
| Stage 6 — **D8's persistence obligations** | **landed, green** |
| **WI-A13** | **COMPLETE. A14 and A15 unblocked.** |

## What landed

| Commit | Item | Gate |
|---|---|---|
| `6c4894e` | **D8's secret handling** — two detection axes, the redactors, `ReplayImpact` | `make program_persistence` (new) |
| `e01a978` | **the encoding, the compatibility policy, the store** — plus two frozen specimens | same target, extended |
| `e70d8f4` | execution report, plan corrections, an AILANG issue writeup | note + plan |

Three new files: `src/core/dst_secrets.ail` (768), `src/core/dst_persistence.ail` (1261),
`scripts/dst/program_persistence_dst.ail` (1399), plus
`scripts/dst/fixtures/execution-program-v{0,1}.artifact` (67 each). Modified: `Makefile` (+130),
`src/core/dst_generator.ail` (+12, comment only — a pointer from the site-22 pin to the stage-6
decision). 4336 insertions, 8 deletions.

**`make dst` exits 0** on the committed tree, read as an exit status per cluster 7's process
amendment — **466 checks, 63 of them new** (403 at stage 5; 427 after the first commit, so 24 and
39). The single `✗` in the log is the `✗ Failed: 0` summary label of a passing `ailang test` run,
checked rather than assumed. `make check_core` exits 0, 48 modules. A5 anchors verified intact at
start and end (`src/core/test/stub_step.ail:161`, `session.ail` 948/1053/2290/2400); `driver_only`
stays at **v3** — this stage touched neither file, so the handoff's rule held trivially, but
`sed -n '161p'` was run anyway because the cost of not running it is a profile re-issue.

## The order the work took

The handoff's two pieces are independent, so the ordering rule was S3's — take the one that converts
to a clean stop. Secret handling went first: it is a leaf module with no dependency on the encoder,
and the encoder's refusal path needs it.

1. **Primitive smoke test before any design.** `Str.foldChars` with a record accumulator,
   `Str.split` on tab and newline, `Str.stringToInt`'s `Option`, `sha256Hex`'s purity, and an
   escape/unescape round trip — all in one throwaway probe inside the repo, never `/tmp`. It cost
   three minutes and caught two of the session's four compiler round trips before they were embedded
   in real code: `++` is list-only for strings, and `Str.split("", "\t")` returns one element.
2. **`dst_secrets`, detectors first, then the acceptance suite**, then nine mutants against both.
3. **`dst_persistence`**, written whole against a design recorded as four numbered choices in its
   header, each admitting a second answer that type-checks.
4. **The specimens frozen with a temporary `freeze` entry point, which was then deleted** — stage 5's
   discipline for its canary pins, applied to an artifact. A Makefile guard now fails if anything in
   the tree writes to that directory.
5. **Seven more mutants against the encoding, the policy and the store.**

## The rule the handoff said would be broken by accident

> *A compatibility policy needs a frozen artifact from the past, or it tests nothing — and this
> project has no past, so you must manufacture one deliberately.*

It was not broken, but the handoff under-specified it in one way that mattered. **The frozen row must
assert DECODABILITY and not ENCODER STABILITY.** Asserting `encode(specimen) == frozen_bytes` is one
character cheaper to write and acquires exactly the regeneration target cluster 11's correction 1
warned about: any backward-compatible encoding change reddens it, and the natural response destroys
the specimen. The row asserts the frozen bytes still decode to the specimen field by field, and
reports an encoder difference as an informational line rather than a failure.

**And the specimen is CONSTRUCTED, not swept — a departure from stage 4's technique and from the
handoff's suggestion.** Sweep-and-filter cannot supply it, because the generator provably cannot
reach every shape the *schema* admits: the provider fault class is unreachable by a generated program
(cluster 10) and `approval_deadline_exceeded` is unreachable by a discovered, generated or replayed
one (stages 2–4). A swept specimen would freeze today's reachable set and leave the rest **absent**,
which reads identically to unchanged. **Sweep-and-filter selects among things that exist; it cannot
cover a space the producer does not reach.** That limit is now recorded against A15.

## The decision the stage owned: site 22

**Recorded, keyed around, `seed_state` left alone, the characterization test kept.**

The reasoning is not the cost argument the handoff anticipated:

> Fixing `seed_state` would not make `(generator_id, generator_version, seed)` a key. D8's own
> reproducibility promise is conditioned on the recorded execution manifest — the triple omits it —
> so two runs at one triple under two manifests are two different programs **today**, with or without
> site 22.

Two independent facts pointing the same way, so the store derives its **path** from the triple (a
stable path is what makes a diffable encoding worth having — content addressing puts every revision
at a new name and there is nothing to diff), its **identity** from `sha256Hex` of the exact bytes,
and refuses by name to overwrite a path whose existing artifact differs. The 260-seed re-sweep was
not performed; stage 4's seeds 9, 13 and 94 are untouched.

## Sites 23 and 24 — two type-checking answers, the wrong one silent

**Twenty-four across twelve clusters. Determinism has caught none of them.** Both of this stage's
were found by mutating the implementation and reading *why* a row went red, never by running a gate.

- **Site 23 — a negative control that cannot reach the clause it tests.** `has_jwt` requires an
  `eyJ` prefix *and* three plausible segments. Reducing it to `Str.contains(s, "eyJ")` left every row
  in the module and the acceptance suite green, because all four negative controls were strings that
  **do not contain `eyJ`**. They exercise the prefix clause and cannot reach the segment clause. The
  generalisation: **a control rejected by clause 1 certifies nothing about clause 2 and reads
  identically to one that exercises both.**
- **Site 24 — the diff count alone cannot distinguish diffable from single-line.** "A one-field
  change moves exactly two lines" is the right quantity and is green on the encoding it exists to
  forbid: joining the whole program with a non-newline separator produced a four-line file in which a
  one-field change still moved exactly two lines. Repaired with a floor **derived from the artifact**
  (four lines per interaction) rather than a chosen constant.

**Both are assertion weaknesses rather than implementation defects**, which is now the majority shape
in this project. The implementation was right both times; the evidence that it was right was not.

## What the mutation testing found that the gates did not

Twenty mutants across the two commits, twenty caught after the two repairs above. Three worth naming:

| Mutant | Caught by | Why nothing else could |
|---|---|---|
| a manifest field the codec silently drops | the field-by-field round trip **and** a Makefile guard counting `ExecutionManifest`'s declared fields against the codec's tags | every count balances and both halves type-check; only a NAMED per-field diff shows `manifest.abi_version ('abi-7' vs '')` |
| `persist_program` writes before the secret scan | reading the **file system** back | redact-after-write and redact-before-write are indistinguishable from the in-memory record |
| the single-line encoding | the derived line floor (site 24) | the diff count is 2 in both arrangements |

And one guard that worked because of *how* it was written: the thirteen decode mutation rows each
assert a **specific** refusal rule, so corrupting the body without recomputing the digest would have
turned eleven of them red rather than passing on the wrong evidence. Cluster 5's C5 discipline paying
for the fourth time, and the cheapest rule in the project.

## Sizing

**Ten recorded bindings — eight decided, two discovered.** Per piece: secrets 4 (3 decided, 1
discovered), encoding 6 (5 decided, 1 discovered).

**Cost: 41 minutes of implementation window (18:32 → 19:13), split 21 and 20.** The binding count
predicted the encoding at 1.5× the secrets; it cost 0.95×. Second consecutive over-prediction, and
the reason is legible: **a decided binding whose deciding artifact is already open is close to free**
— the encoding's five decided bindings were read off D8 and the standing rules with the ADR open, a
paragraph of comment each — **while a discovered one costs a round trip through running the thing.**
S6's second term is now weighted by discovered bindings.

**Round trips: 4 compiler, 2 gate, 2 silent.** The compiler four were `++` on strings, `[record] ::
list` in expression position, an invented `Str.contains_tab`, and the AILANG defect below, which was
three of the four's worth of time on its own.

**Judgement ratio (undetermined fraction), per piece:** secrets ~55% (D8 says "secret-shaped/live
credentials" and defines neither, nor the surface, nor what a redaction costs); the encoding **~70%,
the highest in the project** (the ADR's Non-goals delegates the encoding *and* the storage path
explicitly, and D8 fixes only four properties); the specimen ~30%, down from stage 4's ~85% by stage
5's mechanism — the coverage requirement is read off `all_interaction_kinds()` and the status set
rather than authored.

## A measurement correction that outlives the stage

All six A13 stages have now been read off git as **wall-clock windows** (handoff commit → last `feat`
commit): 34, 43, 35, 60, 36, 41 minutes → ratios 1.26×, 0.81×, 1.71×, 0.60×, 1.14×. **The
contemporaneous reports gave ~3×, ~1×, ~1.5×, ~0.9×.** They over-report by two to three times
wherever a stage's cost was **deliberation** rather than running things; stage 4, the only stage
dominated by sweeps and re-pins, is the only one where the two agree. Future reports should give the
git window, which is checkable, and may give a felt ratio beside it, which is not.

The same correction lands on the item: **WI-A13 was estimated at 1–2 weeks and took 249 minutes of
implementation windows.** The estimate's basis was right about shape ("each small, the set wide") and
wrong by two orders of magnitude about scale, because it priced artifacts rather than decisions.

## An AILANG defect, reproduced and written up

**A call in the field-value position of a record update is not registered as a dependency by
v0.26.0's declaration sorter.** `{ p | interactions: f(...) }` reports `undefined variable: f`
depending on a declaration ordering the author cannot see, and — this is what made it expensive —
**moving the callee earlier fixes it in some arrangements and not in others.** Five one-line variants
isolate the trigger; `let`-binding the call first is the workaround and is applied at the two sites
here that have the shape.

`.agent/issues/ailang-record-update-field-call-is-not-a-dependency.md`. **Not yet filed upstream.**
It fails in the good direction — refusing correct code rather than accepting wrong code — which is
the opposite of the unreachable-match-arm defect this project filed in cluster 9.

## WI-A13 in retrospect

**What the staging got right.** Every stage after the first landed against a seam the previous one
left, and the *"stage N left the exact seam"* claim held four clusters running. That is a consequence
of each stage moving types **down** into the std-only tier rather than importing up —
`dst_interaction` (stage 2), `GeneratorBounds` (stage 4), `dst_secrets` (stage 6) — because
`src/core/ports.ail` cannot name `ExecutionManifest` without dragging the whole `dst_profile` closure
into the production driver's import graph. **The tier discipline is what made the staging work, and
it is the most transferable thing in the item.**

**What it got wrong, twice, and both are the same mistake.** The item was cut as five stages and
re-cut to six mid-flight when the seeded generator was found to have fallen between stages 3 and 4 —
cheap, because it was caught before stage 4 started. Uncorrected: **stages 5 and 6 were each sized as
one stage and are each two independent pieces.** Sizing by obligations rather than by seams produced
two stages out of six that are really four.

**And the ordering fact no single stage report states: the six were ordered by what each stage could
ASSERT, not by what it could build.** Discovery had to precede replay because replay grades itself
against a recorded log; the generator had to precede the canary because the canary pins the
generator's stream; persistence had to be last because a frozen specimen must contain every shape and
the shapes were not all defined until stage 5. **An item staged by dependency alone would have put
persistence second, where its specimen would have certified a third of the schema and nobody would
have known.**

## Carried forward

**To A14** — the CI replay affordance (cheap now: `artifact_path` + `load_program` +
`persist_message`, but **it must not emit the digest alone**, which would reintroduce at the
reporting layer what the artifact refuses to represent); the three unreached fault classes are
unreached in three *different* ways and D11's counters must not merge them; `max_resource_size` is
now encoded, so deleting it is a schema change; check whether the latency/fault widening adds a
`StepProvider` **variant** before assuming it is free.

**To A15** — key the corpus on `artifact_identity`, not on D8's triple; a promoted counterexample is
bytes, never a digest reference; and it needs **both halves** of the selection technique — a derived
filter for the seeds it can sweep, and a derived coverage requirement for the three required fault
classes no sweep will reach.

**Unresolved, with a named owner** — site 22 is decided, not fixed. The store is safe; the version
axis stays decorative until `seed_state` mixes the identity through a Lehmer step instead of adding
it, and that remains a 260-seed census re-sweep through the real driver.
