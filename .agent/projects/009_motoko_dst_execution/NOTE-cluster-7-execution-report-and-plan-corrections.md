# Cluster 7 execution report — WI-A13 stage 1, and two corrections

Seventh calibration run. **Partial completion, at a clean stage boundary.** WI-A13 was handed off as
five stages; stage 1 is landed, green, and committed. Stages 2–5 are not started, and nothing
half-built is carried across the stop.

Commits:

- `7817fef` fix(dst): anchor the randomness guard to the import form, not the bare string
- `9c4d724` feat(A13): D2's execution program and its pure structural validator

`make dst`: **exit 0**. It was **exit 2 before this session** — see correction 1.

---

## What landed

**`src/core/dst_program.ail`** — D2's `ExecutionProgram`, `DiscoveryConfig`, `Interaction`,
`CausalIdentity`, `TimedOutcome`, `InitialWorld`, `GeneratorBounds`, the pure structural validator,
and the declared-bounds check. No generator, no driver, no replay loop.

**`scripts/dst/execution_program_dst.ail`** — the mutation-based acceptance suite: one valid
9-interaction program covering all seven D2 classes, 18 mutant rows, a negative control, and a
bounds pair.

**`make execution_program`**, wired into the `dst` aggregate.

Three guards were verified to go **red** under deliberate mutation, per cluster 5's C5: removing the
duplicate-ordinal guard, dropping one direction of the deadline rule, and rewriting the duplicate
rule to compare identity bodies.

---

## The S1 result — and it is the strongest one the project has produced

**Fifteenth site where two alternatives type-check and the wrong one is silent. Determinism still
catches none. This one was caught by the negative control, and by nothing else.**

D2 says the validator must reject *"duplicate interaction identities"*. Two paragraphs later it says
the encounter ordinal *"keeps repeated production call ids representable so an invariant can reject
them as system behavior rather than the program decoder rejecting the artifact."*

Both readings type-check:

- **Reject a repeated encounter ordinal.** The ordinal is the global position; sharing one is a
  malformed artifact.
- **Reject a repeated identity body.** The obvious reading of "duplicate identity", and wrong: it
  makes a production retry — same tool, same call id, second attempt — undecodable, which is exactly
  the artifact D2's second paragraph is protecting.

The wrong reading is silent in every way that matters. It **passes all 18 mutant rows**, because
every mutant still produces its own rule. It is perfectly deterministic. It is trace-complete. It
only shows up as a *valid* program being rejected — and a suite made of only-rejecting fixtures never
presents one.

What caught it was the negative control, and only because the base program contains interactions
**#1 and #8 carrying a byte-identical tool identity at different ordinals**. That row is in the base
fixture deliberately. Without it, the negative control passes under both readings and the wrong one
ships.

This is the discovery-side form of the handoff's argument, and it lands harder than expected: for a
**validator**, the completeness assertion *is* the negative control. A validator's failure mode is
not "it did nothing" but "it did too much", and only a fixture that must SURVIVE can see that. The
plan's C5 rule ("every structural guard is mutation-tested") is necessary and, on its own, would not
have caught this — all three mutation demonstrations were green under the wrong reading too.

**Recommended promotion to a standing rule:** *a rejecting artifact needs a fixture that must
survive, and that fixture must contain every shape the specification explicitly protects.* The
negative control is not a sanity check; it is the only assertion that can see an over-strict rule.

---

## Correction 1 — `make dst` has been red since cluster 5, and `--keep-going` hid it

Not a finding about A13. A finding about the gate, discovered by reading exit status as the handoff's
Traps section instructs.

- A12 (cluster 6, `ebf5788`) added the randomness-class guard: `grep -l 'std/rand' src/core/*.ail`.
- A10 (cluster 5, `dafe898`) landed **on top of it** with a `ForbiddenCapability` whose `instrument`
  prose reads *"make world_state — no module under src/core/\*.ail reaches std/rand, checked
  structurally…"*.

The artifact documenting the guard tripped the guard. `make world_state` exited 1, `make dst` exited
2, and with `--keep-going` the failure was one red line among 233 green ones.

Fixed by anchoring to `^import std/rand`. An import is the only way an AILANG module can reach the
package, so this loses no coverage; verified in both directions (green at HEAD, red when a real
`import std/rand (randInt)` is added to a `src/core` module). It is the same precision the
`fault_catalogue` tripwire already needed, so the pattern was already established in the file.

**The generalizable defect:** a structural guard that greps for a bare token will eventually fire on
the artifact that documents it, because these items are *required* to write prose naming what they
forbid. Every grep-based guard in the Makefile should anchor to a syntactic form. Worth an audit pass
in A14 or A15 — this is unlikely to be the only one.

**Process amendment:** clusters 5 and 6 landed out of dependency order (A12 first, A10 on top), and
each was green in isolation. The report convention should include the aggregate gate's **exit
status**, not a scan of its output.

---

## Correction 2 — the completeness assertion is writable for six of seven classes, not all seven

The handoff asked me to say so loudly if there is no way to know what the driver requested
independently of what the recorder recorded. **There is, for six classes. For environment reads there
is no runtime witness, and stage 2 must handle that differently.**

Verified against source:

| Class | Independent witness | Strength |
|---|---|---|
| Provider | `ProviderCallPrepared` in the ledger trace (`session.ail:1958`), emitted by the driver *separately from* the `dispatch_step` call at `:1969` | Strong — cross-component |
| Tool | `V2ToolDispatchStart` (`tool_phase.ail:332`), emitted before the port calls at `:342–343` | Strong — cross-component |
| Approval | Cursor consumption: `world.approvals` length delta | Medium — the response-producing mechanism vs. the log-writing one |
| Clock | `world.clock_ms` delta vs. the sum of recorded advances | Strong, and general across classes |
| Random draw | None needed: no driver site exists, and the guard fixed in correction 1 asserts that structurally | n/a |
| Extension effect | Vacuous under `driver_only`, which installs nothing | n/a for this profile |
| **Environment read** | **None at runtime** | **See below** |

The ledger trace is the load-bearing witness: it is written by production driver code and owned by
D6, while the interaction log is written by the world adapter. Two authors, two records, same
execution — that is what makes it an oracle rather than the recorder grading itself.

**Environment reads have neither.** `ports.env_get` is a keyed lookup, not a cursor —
`ports.ail:97–101` states it: *"reads do not consume it and the successor is the same world"* — and
no ledger event is emitted for one. So the only record that an env read happened would be the
recorder's own log entry. That is precisely the recorder-as-its-own-oracle shape.

A12 anticipated this. `ports.ail:100` already says *"A13's interaction log will want to record the
read (encounter ordinals) without changing this port's shape to do it"*, and A12's Env-withheld
poison pair is **DEFERRED, not skipped**, with its evidence recorded as *provenance, not capability*.
So the weakness is inherited, not introduced.

**The mitigation stage 2 should use, and it is a good one:** the driver's env reads happen at
**statically known call sites** — 6 sites, 7 distinct keys (`MOTOKO_SESSION_ID`,
`MOTOKO_PERSIST_RETRIES`, `MOTOKO_RETRY_STREAM_ERROR`, `OPENAI_BASE_URL`, `MOTOKO_HEADLESS`,
`MOTOKO_TOOL_TIMEOUT_MS`, `MOTOKO_CAPTURE_FAILED_PAYLOAD`). Completeness for the env class can
therefore be asserted against a **source-derived expected key set** rather than a runtime counter —
independent of the recorder because it is derived from the driver's source, and the same technique
classifier 2 already uses via `tools/ext_call_inventory/derive.py`. Static rather than dynamic, but
genuinely independent.

**This is a D2 finding, not a gap worked around**: the env class's completeness evidence is of a
different kind from the other six, and A13's report and D11's counters should say so rather than
presenting one uniform number.

---

## Sizing — S6 dominates, and it predicted the risk location exactly

**S6 (composition), with an S4 (constructed artifact) term that turned out to be nearly free.**

Rough split of the session: grounding — reading D2, D8, the plan's standing rules, and the exports of
six input artifacts — was **a little over half** of it, before a line could be written. That is S6's
first term (2–3 minutes per input artifact) behaving exactly as A10 measured. S4's artifact rows were
the cheap part: the validator's rules were **transcribed from D2's own five-item list**, which is S4's
"transcribed row, negligible" case, not its "discovered row, a minute each" case.

**Round trips: 1, loud.** One compiler error, `define-before-use` on a forward reference in the
script. The module type-checked on its first `ailang check`. Zero silent defects *in the code I
wrote*.

**S6's load-bearing second term is the finding.** S6 says a read binding is free and *"a recorded
binding is where the item's entire risk lives"*. For A10 the recorded bindings were an attribution
identity and two derived sets. **For a validator, the recorded binding is a specification clause that
admits two readings** — something that had to be *interpreted* rather than read from an artifact. A13
had exactly one, D2's duplicate-identity rule, and it consumed effectively all of the item's real
risk while twenty-odd read bindings from A7/A9/A10/A12 cost nothing measurable.

**So S6 transfers to this item unchanged, with its "recorded binding" term generalized:** it is not
only a value that must be copied, it is *any fact that cannot be read and must be decided.* No sixth
model is needed. Recommend the plan amend S6's wording rather than add S7.

**For scheduling A14/A15:** stage 1 was the cheapest of the five stages — pure, no driver, no world.
Stages 2 and 3 carry the driver wiring, which is where A12 overran on a *nominally identical* scope
(S3). The 1–2 week estimate for the whole item still looks right, and **the remaining four stages
hold nearly all of it.** Do not extrapolate stage 1's cost forward.

**Judgement ratio, split** (cluster 5's rule):

- **Machinery — the types and the validator: ~25%.** D2 fixes the semantics tightly and enumerates
  the five rejection families, so most rows were determined. Three decisions were not, and all three
  are documented in the module header: identity-as-a-sum, ordinal-as-the-duplicate-key, and keeping
  the world's cursors out of `InitialWorld`.
- **Content — the base fixture program: ~90%.** *Which* nine interactions a base program contains is
  discovered from what the classes require, not determined by D2. The single most consequential line
  in this commit is content: interaction #8, the retry, without which the wrong reading of D2 ships.

A combined figure would read as "the spec was vague". It was not — it was precise and admitted two
readings in exactly one place, and the fixture is what resolved it.

---

## Handoff state for stage 2

Unblocked. Every input verified present at HEAD; no drift (`git diff 777edbe..HEAD -- src packages
scripts Makefile` was empty at session start).

Stage 2 order, per S3 (route the cheap instance of a seam before the awkward one):

1. **Write the completeness assertion first** (S1), using the ledger-trace witness for provider and
   tool and the clock-delta witness as the general one. It must be red against a recorder that drops
   a class *before* the recorder exists.
2. **Provider first**, then tool — both have the strong cross-component witness.
3. **Approval** next, on the cursor witness.
4. **Env last**, on the source-derived key set, and report its evidence as a different kind.

`routing_violation_at`'s call site is stage 2/3 work and still unlanded; it remains a dead rider
until discovery establishes the profile, exactly as the plan says.

Tooling notes for the next session: the parallel `ailang check` closure tool runs in **2.4 s** over
the 12-module DST closure — rebuild it before editing, per five prior clusters. `make dst` takes
several minutes; **read its exit status, not its output** (correction 1).
