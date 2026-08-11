# 2026-08-03 Cluster 7: WI-A13 stage 1 — D2's execution program and its structural validator

## Context

Branch: `arniwesth/mot-51-execute-wi-a13`

Session span: `ec501ff` → `0765cee`, **3 commits**, two of them production source. Input was
`HANDOFF-execute-a13-discovery-and-replay.md`, executed cold against HEAD. Seventh code session of
project 009, following clusters 1, 4, 6, 3, 2 and 5.

Re-grounding first, as the handoff instructed: `git diff --stat 777edbe..HEAD -- src packages scripts
Makefile` was **empty**, so the handoff's verified-input table held without re-measurement.

**This is the largest remaining item and the critical path.** It was handed off as five stages with
partial completion explicitly blessed. **Stage 1 landed; stages 2–5 are not started.** Nothing
half-built was carried across the stop.

| | |
|---|---|
| Stage 1 — types + pure structural validator | **landed, green** |
| Stage 2 — discovery against `driver_only` | not started |
| Stage 3 — strict replay | not started |
| Stage 4 — regression replay + generator canary | not started |
| Stage 5 — D8 persistence obligations | not started |

## What landed

| Commit | Item | Gate |
|---|---|---|
| `7817fef` | **gate repair** — the randomness guard, red since cluster 5 | `make world_state` |
| `9c4d724` | **stage 1** — execution program + structural validator | `make execution_program` |
| `0765cee` | execution report + corrections | plan, ADR |

New files: `src/core/dst_program.ail` (725), `scripts/dst/execution_program_dst.ail` (408).

`make execution_program` is wired into the `dst` aggregate. **`make dst` exits 0.** It exited 2
before this session — see the gate repair below.

## The S1 result, and it is the strongest one the project has produced

**Fifteenth site across seven clusters where two alternatives type-check and the wrong one is silent.
Determinism has now caught none of the fifteen.** This one was caught by the negative control, and by
nothing else.

D2 requires the validator to reject *"duplicate interaction identities"*. Two paragraphs later it
requires that the encounter ordinal *"keeps repeated production call ids representable so an invariant
can reject them as system behavior rather than the program decoder rejecting the artifact."*

Both readings type-check:

- **Reject a repeated encounter ordinal.** The ordinal is the global position; sharing one is a
  malformed artifact. *Correct.*
- **Reject a repeated identity body.** The obvious reading of the phrase "duplicate identity" — and
  wrong. It makes a production retry (same tool, same call id, second attempt) undecodable, which is
  precisely the artifact D2's second paragraph exists to protect.

### Why every other check was blind to it

The wrong reading is silent in every axis the project currently carries:

- it **passes all 18 mutant rows**, because each mutant still produces its own rule;
- it is perfectly deterministic — same input, same rejection, twice;
- it is trace-complete;
- it only manifests as a **valid program being rejected**, and a suite of only-rejecting fixtures
  never presents one.

What caught it was the negative control, and only because the base fixture contains **interactions #1
and #8 carrying a byte-identical tool identity at different ordinals**. That row is in the base
program deliberately. Without it, the negative control passes under both readings and the wrong one
ships.

Verified by deliberate mutation: rewriting `duplicate_ordinals` to compare identity bodies turns the
negative control red while leaving all 18 mutant rows green.

### The generalization, recommended for promotion to a standing rule

**A rejecting artifact needs a fixture that must SURVIVE, and that fixture must contain every shape
the specification explicitly protects.**

For a **validator**, the completeness assertion *is* the negative control. A validator's failure mode
is not "it did nothing" but **"it did too much"**, and only a fixture that must survive can see that.
Cluster 5's C5 rule ("every structural guard is mutation-tested") is necessary and, alone, would not
have caught this — all three mutation demonstrations were green under the wrong reading too.

This is the discovery-side form of the handoff's argument, and it landed harder than the handoff
predicted: the handoff warned that a frozen thing is perfectly reproducible. The sharper version is
that **an over-strict thing is perfectly reproducible too**, and mutation testing cannot see it
either.

## The three design decisions

Documented in the module header, because each closes a class of defect rather than expressing a taste.

### 1. Causal identity is a SUM, not a flat record

D2 fixes different identity components per class — provider adds step and model, tool and approval add
call id and name, an extension effect adds the effect class id. A flat record holding all of them
makes "a provider identity carrying a call id" representable, and then asks the validator to forbid
what the type should never have allowed.

`identity_kind` and `identity_origin` are **derived** from the body, so a kind that disagrees with its
own payload cannot be written down. This deletes a whole family of would-be validator rules.

### 2. The ordinal is what "duplicate identity" means

See the S1 result above. `duplicate_ordinals` is deliberately blind to the identity body, and the
module header says so at length — this is the single most likely thing a future edit will "fix".

### 3. The program does not restate the world's cursors

`InitialWorld` carries the synthetic environment, clock epoch and normalized message/policy inputs —
but **not** the provider script, approval queue or tool queue. Those are projections of the
interaction list (stage 3 builds `world_state_of`).

If the program carried both, it could serve a response that no interaction records — which is exactly
the completeness defect this item exists to prevent, made structurally impossible instead of checked.

## Correction 1: `make dst` has been red since cluster 5, and `--keep-going` hid it

Not a finding about A13. A finding about the gate, discovered by reading exit status as the handoff's
Traps section instructs.

- A12 (cluster 6, `ebf5788`) added the randomness-class guard: `grep -l 'std/rand' src/core/*.ail`.
- A10 (cluster 5, `dafe898`) landed **on top of it** with a `ForbiddenCapability` whose `instrument`
  prose reads *"make world_state — no module under src/core/\*.ail reaches std/rand, checked
  structurally…"*.

**The artifact documenting the guard tripped the guard.** `make world_state` exited 1, `make dst`
exited 2, and with `--keep-going` the failure was one red line among 233 green ones.

Fixed by anchoring to `^import std/rand`. An import is the only way an AILANG module can reach the
package, so this loses no coverage. Verified in both directions: green at HEAD, red when a real
`import std/rand (randInt)` is added to a `src/core` module. Same precision the `fault_catalogue`
tripwire already needed, so the pattern was established in the file rather than new.

**The generalizable defect:** a structural guard that greps for a bare token will eventually fire on
the artifact that documents it, because these items are *required* to write prose naming what they
forbid. Every grep-based guard in the Makefile should anchor to a syntactic form. Worth an audit pass
in A14 or A15 — unlikely to be the only one.

**Process amendment:** clusters 5 and 6 landed out of dependency order (A12 first, A10 on top), and
each was green in isolation. The report convention should include the aggregate gate's **exit
status**, not a scan of its output.

## Correction 2: the completeness assertion is writable for six of seven classes

The handoff asked for a loud report if there is no way to know what the driver requested independently
of what the recorder recorded. **There is, for six classes. Environment reads are the exception.**

| Class | Independent witness | Strength |
|---|---|---|
| Provider | `ProviderCallPrepared` (`session.ail:1958`), emitted separately from `dispatch_step` at `:1969` | Strong — cross-component |
| Tool | `V2ToolDispatchStart` (`tool_phase.ail:332`), before the port calls at `:342–343` | Strong — cross-component |
| Approval | Cursor consumption: `world.approvals` length delta | Medium |
| Clock | `world.clock_ms` delta vs. sum of recorded advances | Strong, general |
| Random draw | None needed — no driver site exists; the guard fixed above asserts it structurally | n/a |
| Extension effect | Vacuous under `driver_only`, which installs nothing | n/a |
| **Environment read** | **None at runtime** | **see below** |

The ledger trace is the load-bearing witness: **written by production driver code and owned by D6,
while the interaction log is written by the world adapter.** Two authors, two records, one execution
— that is what makes it an oracle rather than the recorder grading itself.

**Environment reads have neither witness.** `ports.env_get` is a keyed lookup, not a cursor —
`ports.ail:97–101` states it: *"reads do not consume it and the successor is the same world"* — and no
ledger event fires. So the only record that an env read happened would be the recorder's own log
entry. That is precisely the recorder-as-its-own-oracle shape the handoff named.

**A12 anticipated this.** `ports.ail:100` already says *"A13's interaction log will want to record the
read (encounter ordinals) without changing this port's shape to do it"*, and A12's Env-withheld poison
pair is **DEFERRED, not skipped**, with its evidence recorded as *provenance, not capability*. The
weakness is inherited, not introduced.

**Mitigation for stage 2, and it is a good one:** the driver's env reads are at **statically known
call sites** — 6 sites, 7 distinct keys (`MOTOKO_SESSION_ID`, `MOTOKO_PERSIST_RETRIES`,
`MOTOKO_RETRY_STREAM_ERROR`, `OPENAI_BASE_URL`, `MOTOKO_HEADLESS`, `MOTOKO_TOOL_TIMEOUT_MS`,
`MOTOKO_CAPTURE_FAILED_PAYLOAD`). Completeness for the env class can be asserted against a
**source-derived expected key set** — independent of the recorder because it is derived from the
driver's source, and the same technique classifier 2 already uses via
`tools/ext_call_inventory/derive.py`. Static rather than dynamic, but genuinely independent.

Reported as a **D2 finding**, not worked around: the env class's completeness evidence is of a
different kind from the other six, and A13's report and D11's counters should say so rather than
presenting one uniform number.

## Sizing: S6 transfers unchanged, with its second term generalized

**S6 (composition) dominated, with an S4 (constructed artifact) term that was nearly free.** The
handoff speculated A13 might need a sixth model or be "all three at once". Stage 1 needed no new
model.

- **Grounding was a little over half the session** — reading D2, D8, the plan's standing rules, and
  the exports of six input artifacts before a line could be written. Exactly S6's first term
  (2–3 min per input artifact), behaving as A10 measured.
- **S4's artifact rows were the cheap case.** The validator's rules were *transcribed from D2's own
  five-item list* — S4's "transcribed row, negligible", not its "discovered row, a minute each".
- **Round trips: 1, loud.** A `define-before-use` forward reference in the script. The module
  type-checked on its first `ailang check`. Zero silent defects in the code written.

### The finding: what a "recorded binding" is for a validator

S6 says a read binding is free and *"a recorded binding is where the item's entire risk lives"*. For
A10 the recorded bindings were an attribution identity and two derived sets — values that had to be
copied.

**For a validator, the recorded binding is a specification clause that admits two readings** — a fact
that had to be *decided* rather than read from an artifact. A13 stage 1 had exactly one, D2's
duplicate-identity rule, and it consumed effectively all of the item's real risk, while twenty-odd
read bindings from A7/A9/A10/A12 cost nothing measurable.

**Recommendation: amend S6's wording rather than add S7.** Generalize "recorded binding" from *a value
that must be copied* to **any fact that cannot be read and must be decided.** The model then covers
both composition instances measured so far.

### Judgement ratio, split (cluster 5's rule)

- **Machinery — types and validator: ~25%.** D2 fixes the semantics tightly and enumerates the five
  rejection families, so most rows were determined. Three decisions were not, all documented above.
- **Content — the base fixture program: ~90%.** *Which* nine interactions a base program contains is
  discovered from what the classes require, not determined by D2.

The single most consequential line in the whole commit is content: **interaction #8, the retry**,
without which the wrong reading of D2 ships. A combined figure would read as "the spec was vague". It
was not — it was precise, and admitted two readings in exactly one place.

## For the next session (stage 2)

Unblocked. Every input verified present at HEAD.

Stage 2 order, per S3 (route the cheap instance of a seam before the awkward one):

1. **Write the completeness assertion first** (S1), on the ledger-trace witness for provider and tool
   and the clock-delta witness as the general one. It must be red against a recorder that drops a
   class **before** the recorder exists.
2. **Provider, then tool** — both have the strong cross-component witness.
3. **Approval** — on the cursor witness.
4. **Env last** — on the source-derived key set, reporting its evidence as a different kind.

**Do not extrapolate stage 1's cost forward.** It was the cheapest of the five — pure, no driver, no
world. Stages 2 and 3 carry the driver wiring, which is where A12 overran on nominally identical
scope (S3). The 1–2 week estimate for the whole item still looks right, and **the remaining four
stages hold nearly all of it.**

`routing_violation_at`'s call site is stage 2/3 work and still unlanded; it remains a dead rider until
discovery establishes the profile, exactly as the plan says.

## Traps confirmed

- The parallel `ailang check` closure tool was rebuilt before editing, per five prior clusters. It
  runs in **2.4 s** over the 12-module DST closure.
- `make dst` takes several minutes and uses `--keep-going`. **Read its exit status, not its output** —
  this is what surfaced correction 1, and it had been missed for two clusters.
- `scripts/dst/probe_phase_vocab_sealed.ail` still fails at baseline (`IMP010`, in no target, WI-A17
  owns it) — confirmed unchanged.
- Pin is v0.26.0, Makefile-guarded. No cache-clearing was needed this session; no contradicting type
  errors appeared.
