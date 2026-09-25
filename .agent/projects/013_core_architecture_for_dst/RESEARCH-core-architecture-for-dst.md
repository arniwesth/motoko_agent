# RESEARCH: Can the core architecture be improved to facilitate DST better?

Date: 2026-08-13
Status: Research — architecture survey + prioritization (no decision yet)
Pinned binary: AILANG **v0.33.0** (`ailang.lock`)
Relates to:
- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md` (the complementary question — see §0)
- `.agent/projects/012_continuous_ailang_adoption/RESEARCH-continuous-ailang-feature-adoption.md` (§3 below is a registry entry generator)
- `papers/motoko-dst-report/DRAFT.md` (§3 architecture, §6.3 coverage accounting, §8 limitations)
- `.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` (the seven-pillar bar)
- AILANG local checkout: `ailang/design_docs/planned/v1_1_0/m-effect-handlers.md`,
  `ailang/design_docs/planned/v1_0_0/m-effect-{refinement,scope-params,clock-net-fs-modes}.md`

---

## 0. The question this note asks, and how it differs from 011

011 asks **"which testing axes should we add?"** and treats the production architecture as
fixed — every axis in it (shrinking, mutation, `property`, fuzzing, metamorphic, exhaustive
enumeration) is an instrument bolted onto the system as built.

This note asks the inverse: **which properties of the core now cap what DST can reach, and
what would uncap them?** The two questions have different answers and different costs, and
011's open question 5 (which axes get WI-numbered plans) cannot be settled without this one —
because two of 011's highest-ranked axes (§3.2 shrinking, §3.3 mutation) get materially
cheaper or more valuable after the changes below, and one (§3.6 metamorphic no-op extension)
is partly *subsumed* by them.

**TL;DR — five caps, ranked by leverage-per-effort:**

1. **The generic profile runner (§2.C).** Three profiles cost 2,668 lines of bespoke driver.
   Making a profile a manifest converts DRAFT §8's two worst numbers (10-of-15 extensions
   installed in no profile; 14-of-15 with no dynamic evidence) mechanically, with no
   production change.
2. **The world-ordinal invariant (§2.B1).** ~1 day. Turns "a dropped world successor" from a
   657-execution measurement into a red gate.
3. **Defunctionalize the world boundary (§2.A).** 12 port fields × 4 adapter families becomes
   one `handle`. Unlocks FS/env fault classes (currently zero of eleven), makes the
   interaction log total by construction, and gives shrinking one representation to shrink.
4. **Commands + interpreter (§2.D).** The big one. Makes sole emission a type property,
   makes the Row 7 interpretive reading decidable, and makes multi-actor an interpreter
   change rather than a second driver.
5. **Registration as a driven phase (§2.E).** Closes the one hermeticity gap that today is
   papered over with replay-identity.

Plus an upstream leg (§3): a substantial fraction of `src/core/dst_*.ail` (**20,037 lines**)
is a userland implementation of AILANG features that are *already designed and unshipped*.

---

## 1. Baseline: the architecture as built, measured at HEAD

| Property | Measured | Source |
|---|---|---|
| `Ports` boundary | **12 closure fields** | `src/core/ports.ail:783` |
| Adapter implementations | **29 functions** across `scripted_`/`ambient_`/`recording_`/`generating_`/`world_`/`virtual_` | `ports.ail` (2,573 lines) |
| `WorldState` | **10 fields**, of which **4 independent cursors** (`script`, `approvals`, `tools`, `ext_effects`) | `ports.ail:183` |
| Manual world threading | **196 `next_state` sites** (session 88, ports 64, context_usage 18, tool_phase 13) | `grep -rn next_state src/core/*.ail` |
| Driver | `c2_loop` **662 lines** (`session.ail:2240–2902`); file 3,624 lines | — |
| Profile drivers | **2,668 lines** for three profiles (1,025 / 796 / 847) | `dst_driver_{only,plus_no_ops,plus_compose}.ail` |
| Profile *framework* | already data-driven: `ProfileDefinition` + validators | `dst_profile.ail:568` (2,268 lines) |
| Fault catalogue | **11 classes**: 5 provider, 3 tool, 2 approval, 1 extension-effect | `dst_fault_catalogue.ail` |
| DST surface | **20,037 lines** of `src/core/dst_*.ail` | `wc -l src/core/dst_*.ail` |

Two properties are genuinely strong and should be preserved by every change below, because
they are what the whole oracle rests on:

- **`ledger_emit` is private to `session.ail`** — no other module calls it. Sole emission is
  real, not aspirational (see §2.D for the caveat about *how* it is enforced).
- **`ProfileDefinition` is already data with validators**, not code. §2.C is finishing a job
  that is 70% done, not starting one.

---

## 2. The five caps

### A. The world boundary is 12 fields × 4 adapter families, not one `handle`

DRAFT §5.2 presents the world as one boundary function:

```text
handle(world_state, world_request) -> Result({ …, response, next_world_state, … }, HarnessError)
```

**That type does not exist.** What exists is a 12-field record of closures, each with up to
four hand-written implementations. The conceptual claim is accurate — every observation does
cross one boundary — but the *representation* is a matrix, and three consequences follow that
a reader of §5.2 would not predict.

**A1. Faults are wired per adapter, so whole effect classes have no faults.** Eleven fault
classes: five provider, three tool, two approval, one extension-effect. **Zero filesystem
faults, zero env faults, zero clock faults** — even though WI-D17/D18 gave the world a
*writable* filesystem (`file_write`, `file_remove`, `dir_make`, `path_stat`, `dir_list`). The
world can model a file; it cannot model a failing file. Nothing conceptual blocks
`file_write_denied` or `dir_missing`; what blocks it is that each new class means new adapter
code in each family.

**A2. Recording is a per-adapter obligation, and three classes do not discharge it.**
`record_interaction` (`ports.ail:1525`) is called at **8 sites, all inside `recording_*`
adapters**. `recording_ports` (`test/stub_step.ail:501`) binds nine classes;
**`file_read`, `path_stat` and `dir_list` are deliberately not recorded** — the stated reason
(`stub_step.ail:508–512`) is that `InitialWorld` cannot carry the table those reads observe,
so a log entry would describe an observation the artifact cannot rebuild.

That reasoning is sound *given the current representation*, and it must be reported fairly: it
is a recorded decision, not an oversight. But it bounds a claim the paper makes. DRAFT §5.2
says what limits over-normalization in strict replay is that "replay compares interaction logs
and world-request censuses member-for-member, not digests alone" — and that comparison ranges
over **9 of 12 port classes**. Under a unified request/response vocabulary the artifact's
initial world and the request log are the *same* vocabulary, so "the artifact cannot carry it"
stops being a reason and the census becomes total.

**A3. Every mode is a parallel family rather than a composition.** With one `handle`, modes
become combinators — `recording(faulting(catalogue, scripted(w)))` — and a new effect class
costs one constructor instead of one field plus up to four adapters plus `stub_step` plus
`ports_shape_probe` plus profile validators.

**The change:** a `WorldRequest` sum and a `WorldResponse` sum; `Ports` collapses to one
`handle`; the existing adapters become one `match` each.

**Cost:** large but mechanical, and the DST sweep is the safety net — this is precisely the
class of refactor the system was built to make safe. **Prerequisite for** 011 §3.2 (shrinking
gets one sequence to shrink instead of four cursors) and cheap FS/env fault classes.

### B. World state is threaded by hand, and the correctness argument lives in comments

196 `next_state` sites, 88 of them in `session.ail`. The instructive artifact is
`session.ail:2262–2290`: justifying that four sites may reuse `st.world_state` rather than a
fresh resolution required running a temporary assertion **over the whole of `make dst`**,
reporting 657 executions and zero mismatches. Excellent engineering — and a symptom.
Dropped-successor safety is established by measurement and preserved by a comment. DRAFT §5.2
already narrates the frozen-cursor variant that "type-checked, kept every gate green, and
silently replayed step 0 forever."

Three fixes, cheapest first:

- **B1 (do this regardless):** a monotone request ordinal in `WorldState`, plus a finalization
  invariant that the returned world's ordinal equals the recorded request count. A dropped
  successor becomes a red gate instead of a study. ~1 day; no production restructuring; it
  also gives the interaction-log census (A2) a cardinality check it currently lacks.
- **B2:** a `WorldM` bind combinator (`(WorldState) -> (a, WorldState)`), which removes most
  of the 196 sites and makes "drop the successor" unwriteable on the common path.
- **B3:** linear/affine world token, or effect handlers — both upstream (§3).

### C. Coverage thinness is an architecture cost, not an effort cost

Three profiles cost **2,668 lines** of bespoke driver — ~890 lines each. Fifteen extensions at
that rate is ~13k lines. *That* is why DRAFT §8 reports ten of fifteen extensions installed in
no profile; it is not neglect.

`dst_profile.ail` already made the profile a validated data type. The missing piece is **one
generic profile runner** so a profile is a manifest and "one profile per extension in the
tree" is a generated sweep dimension. Both of §8's worst coverage numbers then move
mechanically, with **no production change** — which is why this ranks first despite being
less intellectually interesting than A or D.

**The half that will not yield to it:** criterion 1 ("hooks claimed effect-free," 20 of the
40 entries) rests on the *declared* effect row because the world can only observe what is
routed to it. **"Zero routed effects" ≠ "zero effects"** — an ambient effect is invisible to a
positive-observation instrument. Measuring effect-freedom requires a *negative* observation,
and the only mechanism the project already trusts for that is caps-as-conformance (DRAFT
§3.4), which AILANG grants **per process**.

- **Upstream fix:** per-hook capability narrowing → §3, `m-effect-scope-params.md`. This
  converts 20 assumed entries to measured using the exact mechanism §3.4 already defends.
- **Userland fallback:** dispatch hooks in a subprocess under narrowed `--caps` (the RPC
  machinery exists). Expensive; gives a *measured sample* rather than a declared row, which
  is still strictly stronger than today.
- **What does not work:** a static effect-row audit over extension source. That is a better
  assumption, not a measurement.

### D. Sole emission is real but structural only by module privacy

`ledger_emit` is private to `session.ail`, so the property holds. But it holds because one
662-line function is disciplined, and because *emission* and *trace append* are two hand-paired
operations — which is exactly why the wire-vs-returned-trace parity families
(`ledger_parity_dst`, `terminal_trace_dst`, and D6.4's "an external `ledger_emit` call is not
appended", `dst_invariants.ail:65`) have to exist as tests at all.

The codebase is already **halfway** to the fix: `decide` is pure (`step_machine.ail:114`),
`result_delta` / `phase_from_result` are pure (`model_phase.ail:17,29`), and the phases are
mostly pure with a few effectful dispatchers. What is missing is turning the phase *effects*
into values:

```text
step : (StepState, WorldResponse) -> (StepState, [Command], [LedgerEvent])
```

with a small interpreter that executes commands against the world and emits. Payoff, in order
of how directly it answers a stated limitation:

- **Sole emission becomes a type property** — only the interpreter carries `IO`/`Trace`. The
  parity families become tautological instead of tested.
- **Row 7's stated reading becomes decidable.** DRAFT §6.1 flags this as the single
  interpretive load-bearing point in the whole conformance verdict ("if a reviewer rejects
  this reading the row is red and the verdict is NO"). With events derived from commands, an
  unreachable vocabulary constructor is a build error rather than an enumerated footnote.
- **Multi-actor becomes an interpreter change, not a production change** — interleave two
  command streams. This is exactly the tripwire DRAFT §5.3/§8 records; on the current
  architecture, tripping it means writing a second driver, which breaks ADR decision 2
  ("drive the real production transition code") in the one place it matters most.
- **L1 scenarios can assert over command sequences with no effects at all** — much faster, and
  it widens 011 §3.7's exhaustive enumeration well beyond `decide`.
- **Shrinking gets a second, finer granularity** (drop commands, not only program steps).

**Cost:** the largest item here. Incremental route: tool phase first (most self-contained),
then model phase, then hooks. **Sequence after the paper freezes**, and after the §3 asks are
filed — if AILANG's Phase 1 handlers land, D should be shaped to *meet* them, not duplicate
them.

### E. Extension registration sits outside both the world and the ledger

DRAFT §3.3 and §8: registration runs ambient, before the driver dispatches anything, and the
determinism claim there rides record-to-strict-replay identity — "a documented substitution,
not an oversight," but a substitution. Routing `ExtRuntime` construction through the boundary
and emitting registration records would make hermeticity uniform, put the install set inside
the recorded program (so replay covers it), and enable a fault class that does not exist:
`extension_registration_failure`. Naturally sequenced with C (a generic runner has to
construct install sets programmatically anyway).

---

## 3. The upstream leg — and what it means for project 012

A substantial fraction of the 20,037 lines of `src/core/dst_*.ail` is a **userland
implementation of AILANG features that are already designed and unshipped**:

| AILANG doc | Status | Effect on Motoko |
|---|---|---|
| `planned/v1_1_0/m-effect-handlers.md` | Planned. Priority line: *"strategic language feature, **unblocks deterministic testing story**"*. Phase 1 targeted **v0.21.0**; we are on **v0.33.0** | Deletes the ports-swap mechanism outright. §2.A, §2.B and §2.D collapse into `handle … with …` |
| `planned/v1_0_0/m-effect-scope-params.md` | Planned, ~2.5d (sprint 4 of the refinement track) | Per-hook capability narrowing → §2.C's 20 assumed entries become measured; closes §2.E's registration gap |
| `planned/v1_0_0/m-effect-clock-net-fs-modes.md` | Planned, ~3d | `Clock[mode=pinned]`, `FS[mode=fixture]` — Motoko's virtual clock and synthetic FS, in the language |
| `m-effect-refinement.md` P3 (replay contracts) | Planned | A per-effect replay taxonomy — the contract DRAFT §5.2 states in prose |

**This inverts 012's framing in a useful way.** 012 models Motoko as a *consumer* holding a
registry of debt and waiting on releases. But `m-effect-handlers.md` has been Planned across
twelve minor versions, and Motoko is the strongest available evidence that it should be
funded: a 20k-line userland proof of exactly that feature, with a paper attached. 012's
mechanism should be able to emit that argument, not only wait for the changelog. Each row
above is a registry entry; the handlers row is also an upstream *sponsorship* case via the
`ailang-feedback` channel.

Note the ordering constraint: **file the asks before starting §2.D**, not after.

---

## 4. Proposed sequencing

| # | Item | Depends on | Production change? | Notes |
|---|---|---|---|---|
| 1 | World-ordinal invariant (§2.B1) | — | no | ~1 day; also gives A2's census a cardinality check |
| 1 | Standing one-of-forty aggregator | — | no | DRAFT §8 already names it "the one piece of mechanisation worth building" |
| 1 | `driver_only`'s missing coverage statement | — | no | Register defect, DRAFT §6.3 |
| 2 | Generic profile runner (§2.C) | — | no | Moves §8's two worst numbers; highest leverage-per-effort here |
| 3 | File the four AILANG asks (§3) | — | no | Before item 5 |
| 4 | Defunctionalize the boundary (§2.A) | 1 | yes (ports) | Then FS/env fault classes are table entries |
| 5 | Commands + interpreter (§2.D) | 4, 3 | yes (session) | **After the paper freezes** |
| 6 | Registration as a driven phase (§2.E) | 2, 4 | yes | — |
| 7 | `WorldM` combinator (§2.B2) | 4 | yes | Or dropped entirely if handlers land |

Interaction with 011: item 4 makes 011 §3.2 (shrinking) simpler; item 5 makes 011 §3.3
(mutation) more meaningful — a kill matrix over an oracle whose emission is structural means
more than one over an oracle whose emission is disciplined. Item 2 partly subsumes 011 §3.6's
no-op-extension metamorphic relation, since per-extension profiles produce the same evidence
as a standing sweep dimension rather than as one relation.

---

## 5. Explicitly not now

- **Multi-actor / concurrent-scheduling DST.** The DRAFT §5.3 exclusion is correctly reasoned
  and the tripwire is the right instrument. Attempting it before §2.D means a second driver,
  which breaks the one ADR decision that the entire "production logic is under test" claim
  depends on. After §2.D it is an interpreter feature.
- **Rewriting `ports.ail` in place without the request/response vocabulary.** Splitting the
  file or deduplicating adapter families buys tidiness and none of §2.A's four consequences.
- **Chasing criterion-1 measurement in userland before the scope-params ask is answered**,
  beyond the subprocess sample described in §2.C.

---

## 6. Open questions

1. **§2.A granularity:** does `WorldRequest` mirror the current 12 classes one-for-one, or
   does the FS family collapse (`FsRequest(Read | Stat | List | Write | Remove | MkDir)`)?
   The census and the fault catalogue want different answers.
2. **§2.A vs the recorded artifact:** unifying the vocabulary makes `InitialWorld` and the
   request log one vocabulary — but does that change the `ExecutionProgram` wire schema, and
   therefore invalidate the banked corpus? (If yes, the corpus needs a migration or a
   version-2 lane before item 4, not after.)
3. **§2.B1:** should the ordinal live in `WorldState` (simplest) or in a wrapper type that
   makes the world un-duplicable by construction (stronger, more invasive)?
4. **§2.C:** does a generic runner keep per-profile *validators* pluggable, or does making
   profiles uniform lose the per-profile rejection rules `dst_profile.ail` currently encodes?
5. **§2.D:** which phase is the honest pilot — tool phase (most self-contained) or model
   phase (where the parity families concentrate)?
6. **§3:** is sponsoring `m-effect-handlers.md` Phase 1 upstream faster than §2.A + §2.D in
   userland? The estimate there is 30–40h for Phase 1; §2.A + §2.D is plausibly larger. If so,
   the sequencing in §4 inverts.
7. Which of these deserve WI-numbered execution plans — proposal: items 1–2 go straight to a
   PLAN document; item 4 needs a vocabulary-design spike first (question 1 and 2 gate it).
