# Review: execution safety of `PLAN-implementation-deterministic-test-world.md`

Date: 2026-08-02. Reviewer: fresh verification session.
Target: `PLAN-implementation-deterministic-test-world.md` at convergence commit `a339629` (unchanged
at source-ground HEAD `414c868`). Toolchain: pinned AILANG v0.26.0, commit `3b52a24`.

**Recommendation: Revise.** The A1 → A2 → A12 → A13 → A14 spine is directionally sound and A1 can
start, but the plan as a whole is not yet safe to hand to a scheduler. A plan-owned risk closure is
false on the pin; the externally triggered branch lacks dependencies and a buildable integration
point; several acceptance statements can pass while omitting an ADR-required row, field, or class;
and four ADR obligations still have no implementation home.

I accepted the review framing. None of the findings below asks the plan to specify a detector's
decision procedure. They ask it to schedule an obligation or make the detector's stated evidence
capable of failing when that obligation is absent.

## Findings

### R1. P2's structural risk closure is false even though the immediate no-rider choice remains viable

**Defect.** P2 says a later approval or clock cursor changes no port signature because the state
parameter remains `ProviderState` (`PLAN:55-64`). That state parameter exists only on the proposed
`model_step` widening. HEAD's `approval_read` and `clock_now` have no state parameter
(`src/core/ports.ail:17-20`). Adding a record field therefore does not make either port able to consume
it; a stateful approval adapter forces another input/result widening. The decision not to carry dead
interim state can stand, but its risk is deferred rather than structurally closed.

**Grounding.** A three-module probe was run from the repository root on v0.26.0. Its shared
`ProviderState` already contains both `scripted_cursor` and `approval_cursor`, isolating the port
shape from record construction. Assigning the state-threaded adapter to HEAD-shaped
`approval_read: (string) -> string` fails:

```text
$ ailang check probe009/p2/current_port_shape_rejects_state.ail
... failed to unify record field 'approval_read': function arity mismatch: 2 vs 1
```

Changing the port to
`approval_read: (ProviderState, string) -> ApprovalTransition` passes with `✓ No errors found!`.
The sources are in `probe009/p2/`.

**Action.** Ground P2 only in the observed absence of an interim consumer. State that a pre-A12 need
for non-constant approval, or for a clock value read from the interim state, reopens the affected port
shape. No work item needs to move while A12 remains fixed in order.

### R2. WI-A5's evidence can validate a partial attribution artifact

**Defect.** A5's acceptance checks malformed rows, unknown hook ids, stale bindings, and the
empty-intersection rule (`PLAN:156-166`). It never demonstrates the producer-side completeness that
makes the table safe: every classifier-discovered core effect site must be accounted for as attributed
or unconditional core. A syntactically valid table that silently omits a discovered site can satisfy
all listed tests.

**Grounding.** D4 requires profile load to fail closed on a site that is neither in the table nor
unconditional core (`ADR:1032-1042`) and requires the table to be produced with the classifiers because
they enumerate what it must account for (`ADR:1072-1079`). A5 says it is built in the same change as
A4, but its evidence never joins the two outputs.

**Action.** Add an acceptance fixture in which a classifier-discovered core effect site is absent from
both the attribution rows and the explicit unconditional-core set; profile load must reject it. This
tests completeness without specifying how the table is built.

### R3. WI-A7 validates catalogue rows but not the required catalogue

**Defect.** A7's evidence proves that an existing row has all fields and names a known constructor,
but does not prove the catalogue contains every minimum D3 class (`PLAN:176-183`). An empty catalogue,
or one omitting partial-stream error and deadline completion, can pass every stated A7 check. Later
counters read their ids from that same artifact, so they cannot discover a class the artifact omitted.

**Grounding.** D3 fixes the minimum provider, tool, approval, and conditional extension-effect classes
at `ADR:760-783`. A7's only completeness-adjacent statement is prose saying those classes are fixed;
its acceptance evidence tests row shape, two conditional rows, and downstream counter integration.

**Action.** Make catalogue-set completeness acceptance evidence: validation must reject a fixture
missing any required D3 class id, in addition to rejecting malformed rows. A14 should continue to test
class-reached and branch-reached separately.

### R4. WI-A11 is red on the unmodified ADR by construction

**Defect.** A11 asks for one canonical predicate sentence and a list of six normative anchors that
must contain it (`PLAN:214-220`). The ADR explicitly says those six sites are substantively aligned
but not word-identical and use six formulations (`ADR:447-465`). A literal containment check therefore
fails before any mutation, while A11's sole negative fixture can still pass.

**Grounding.** The Status block (`ADR:56-59`), D1 (`:401-407`), D5 exclusion (`:1287-1294`), D5
validation (`:1341-1343`), acceptance row (`:1839`), and handoff (`:2002-2009`) do not contain one
identical sentence.

**Action.** Either make A11 an anchor-set/content-drift check with a named semantic review, or budget
canonicalising the six ADR anchors. In either case, require the check to be green on the unmodified
ADR at HEAD before the scratch mutation is applied.

### R5. WI-C5 violates D4's scheduling prohibition and lacks the world/profile dependencies it uses

**Defect.** C5's only dependency is B2, yet it defines a second profile, routes extension clocks into
the world clock, and claims the 12-site routed set (`PLAN:305-314`). It therefore also requires A10
(profile machinery), A12 (world clock), and A5 (the attribution that makes the set 12 rather than 13).

**Grounding.** D4 says the split is 5/13/13 before the table and 4/12/13 afterward, and forbids a
routing-completeness claim before table validation (`ADR:898-907`, `:1075-1079`). The plan claims no
such assertion precedes A5 (`PLAN:162-166`), but B may interleave with A (`PLAN:100-102`) and C5 has no
all-A dependency like C4.

**Action.** Make C5 depend on B2, A5, A10, and A12. Mark 12 as the post-table claim and 13 as the
fail-closed fallback.

### R6. The externally triggered B/C branch is not a buildable dependency chain

**Defect.** Milestone B deliberately starts whenever the release appears and interleaves with A, but
its items have no dependency clauses or terminal integration gate. B2 needs A12's world token; B4
needs classifier 2 and manifest machinery; C1 relies on A1's widened loss channel; and C2 is the
positive proof of C1's adoption. Those relations are only partly implied by item order. Worse, a bare
B1 repin is not a green intermediate state: M1/M2 show that the new pin simultaneously exposes the
Message migration and effect/ABI repairs assigned to B2/B3.

**Grounding.** `PLAN:100-105,258-285,289-295`; M1/M2 at
`NOTE-spike-findings-real-driver-vertical.md:369-435`. B4 currently says only to rerun both classifiers
and reissue the manifest, although those artifacts do not exist until A4/A10 and the new ABI/source
set is not final until B2/B3.

**Action.** State the triggered graph explicitly: B2 depends on A12 and the repin worktree; B3 on the
new pin; B4 on B1-B3, A4, and A10 and serves as the green integration gate; C1 depends on A1 and that
integrated repin; C2 depends on C1. If B1 is allowed to be temporarily red, label it preparation-only
rather than a completed build item and give B4 the full compile/test acceptance evidence.

### R7. WI-A10 does not make the profile-definition contract falsifiable

**Defect.** A10 enumerates the execution-manifest fields but not D5's separate profile-definition
fields (`PLAN:204-212`). P4 names only the empty install list, waivers, attribution reference, and
reachable clock set. For `driver_only`, adapter/parser boundaries, logical resource models, permitted
diagnostic projections, forbidden capabilities, and omissions with reasons are not vacuous. A profile
schema that lacks any of them can still "load clean" under the stated evidence.

The same load boundary has no evidence for D5's scan-root rule: an installed AILANG package outside
`src` + `packages` must extend the roots through the resolved lock graph or fail closed.

**Grounding.** D5's definition list is `ADR:1109-1128`; the scan-root rule and live registry example
are `ADR:1476-1488` and `ailang.toml:9`. A4 fixes its current scan to `src` + `packages`
(`PLAN:147-154`); A10 supplies no out-of-root fixture.

**Action.** Enumerate all D5 profile-definition fields in A10 and reject a fixture missing each field.
Require `driver_only` to name at least the `compaction_ai` omission and reason. Add a load fixture for
an installed package whose source is outside the recorded roots.

### R8. WI-A12 schedules the typed tool request but drops the typed result/error half

**Defect.** A12 says the `ToolCallEnvelope` plus deadline replaces stringly `tool_exec`, but never
requires a typed tool result/error (`PLAN:222-236`). A request-only widening can meet its listed poison
probes while leaving the return value as today's undifferentiated string, which is weaker than D1's
tool-boundary obligation and D3's typed tool fault classes.

**Grounding.** D1 requires "a typed `ToolCallEnvelope`, timeout/deadline information, and a typed
result/error rather than `tool_exec(string, string) -> string`" (`ADR:601-609`). HEAD remains
`tool_exec: (string, string) -> string` (`src/core/ports.ail:22`), as the plan survey records at `:30`.

**Action.** Add the typed result/error to A12's contents and acceptance evidence. Exercise ordinary
success, typed execution/non-zero error, wrong correlation, and completion-after-deadline through the
same production adapter contract.

### R9. The D6 result contract and dispatch-time exclusion failure have no complete implementation home

**Defect.** The plan mentions a typed `HarnessFailure` only for A13's mismatch fixture, with position
and projection (`PLAN:243-247`). It does not schedule the complete `SystemRun`/`HarnessFailure` result
shapes, setup failure, partial trace/replay metadata, or the runtime rule that dispatching an excluded
hook returns an in-runner `HarnessFailure`. Load-time rejection and capability poison probes do not
implement that path.

**Grounding.** D6 fixes both result classes and their fields at `ADR:1532-1551`, distinguishes typed
in-runner violations from raw capability termination at `:1589-1600`, and the name gate explicitly
requires mismatch and routing/exclusion probes with partial evidence (`ADR:1844`). D5 requires an
excluded hook reached at dispatch to fail closed (`ADR:1145-1147`). No plan item mentions this runtime
enforcement.

**Action.** Assign the result types and failure plumbing to A9/A13 (or a new item), and runtime
exclusion enforcement to A10 or C5. Acceptance must cover mismatch, setup failure, and reached
exclusion as typed failures with the required evidence, while retaining non-zero process failure for a
raw capability bypass.

### R10. Three D8 persistence/replay obligations remain unscheduled

**Defect.** A13 includes program types, a generator, validator, two replay modes, and the canary, but
omits: (1) rejecting/redacting secret-shaped or live credentials before persistence; (2) selecting a
deterministic diffable encoding and compatibility policy, including old-schema decoding or a pinned
runner; and (3) a copy-pasteable replay command or retained artifact reference in CI output.

**Grounding.** `ADR:1692-1698,1710-1715`; `PLAN:238-247`. The plan records the allowed shrinking
deferral at `:351-353`, so silence on these mandatory D8 clauses cannot be read as another deferral.

**Action.** Put persistence safety and encoding/compatibility into A13 with secret and old-schema
fixtures. Put the replay command/artifact reference into A14's failure-report evidence.

### R11. WI-A14 reports corpora that no item builds

**Defect.** A14 implements "D11 corpus reporting" and chooses minimum counts, but no item constructs
the blocking PR corpus, deterministic rotating scheduled corpus, or their CI jobs. It also does not
select rotation, retention, and sharding from measured CI cost. C4 cannot later run a corpus-minimum
gate against jobs that were never scheduled.

**Grounding.** D11 requires both corpora and delegates counts, rotation, retention, and sharding to the
plan (`ADR:1747-1773`). `PLAN:249-256` covers reports and minimum counts only. Survey row 9
(`PLAN:34`) and `rg --files .github/workflows` show the sole current workflow is
`.github/workflows/verify-extensions.yml` and there is no generated-trajectory axis.

**Action.** Extend A14 or add A15 to define both corpora, wire the blocking and scheduled jobs, measure
their cost, select rotation/retention/sharding, and test exact-count failure and retained-program-plus-
manifest promotion.

### R12. WI-A8 assumes one wire name per variant, which is false at HEAD

**Defect.** A8 describes each vocabulary row as `(variant, wire name, payload schema,
classification)` and prefers deriving the wire name from the type (`PLAN:185-192`). `StreamDelta` has
two payload-dependent wire names. The unclassified-variant fixture does not test whether the artifact
represents or reproduces the current wire projection.

**Grounding.** `src/core/phase_vocab.ail:631` documents
`thinking_delta | reasoning_delta`; `to_schema_v1_kvs` selects between them from `i.kind` at `:713`;
goldens pin both at `:1139-1140`.

**Action.** Record the payload-dependent case in A8's construction scope and choose a representation
that admits it (for example a total projection or allowed-name set). Add a round-trip/golden check for
all 34 variants and every admitted wire-name branch.

### R13. Sizing omits the schedule-dominating items and blurs estimates with measurements

**Defect.** A1, A2, A4, A12, B1, and B3 carry figures; A13 (discovery plus two replay modes), A14
(all invariants plus CI corpora), and B2 (the larger world-token ABI change plus lockstep package
release) carry none. Those are plausibly the three largest schedule risks. B1 cites all 381 M2 effect
edits even though three ABI edits and the coordinated major sit in B2, so the measurement's allocation
between work items is also unclear. A1/A2/A4/A12 figures are estimates by analogy but are not labelled
as such, unlike B1/B3's measured values.

**Grounding.** `PLAN:109-151,222-285`; M1/M2 at
`NOTE-spike-findings-real-driver-vertical.md:369-435`. The stated A1 and A4 analogies are conservative
and otherwise sound; the defect is schedule coverage and labelling, not their numeric direction.

**Action.** Give A13, A14, and B2 coarse ranges with explicit bases; allocate M2 between B1/B2 or
state that they are one inseparable measured wave; label A1/A2/A4/A12 "estimate by analogy" and
B1/B3 "measured".

### R14. Milestone A's boundary overclaims what is delivered before C

**Defect.** Milestone A says it delivers everything except streaming parity and extension-model
coverage (`PLAN:328-333`). The plan itself schedules D4's required latency-pair demonstration only in
C4 (`PLAN:300-303`), despite the `ToolCallEnvelope`, clock, generator, and replay machinery all being
A work. R11 also leaves D11's two corpora unbuilt. Milestone A therefore does not end at the boundary
it claims.

**Grounding.** D4's name-gate evidence is two replayable programs differing only in latency/clock
movement and producing different deadline behavior (`ADR:942-959`, acceptance row `:1841`). No A item
states that pair as acceptance evidence; A14 promises every D7 bullet, but this D4 pair is not a D7
bullet.

**Action.** Either move the latency-pair test and both corpora into A (the work is upstream-independent)
or narrow the Milestone A boundary statement to name them as remaining name-gate work in addition to
streaming parity and extension-model coverage.

## Checked and clean

- Survey spot-checks agree at HEAD: 13 real `now()` call sites (4 driver, 1 core extension runtime,
  8 compose), exactly 2 `.ai_step(` calls, and 0 `.clock_now(` calls. `make effect_inventory` reports
  0 unresolved modules; `make effect_inventory_selftest` reports `agree=43 disagree=0`.
- P1 is a plan-level inference rather than an M1 measurement of record-versus-sum, but the inference is
  stated as such and the record choice is buildable. P4's coverage floor and per-extension disclosure
  are genuinely vacuous over an empty install list; R7 concerns the non-vacuous definition fields.
- P5's stale-comment anchor is exact. P6 changes `ports_shape_probe`, but all its construction sites are
  already in A1's edit wave and the normal compile/test gates expose the signature change.
- A9 does not need A8: its terminal checks can match the existing `RunSummary` ADT variant without the
  logical/display-only vocabulary. The 32 `provider:` count is conservative in the direction in which
  the plan uses it.
- A1 → A2 is the correct two-widening order. No false dependency or cycle was found in the A spine;
  the defects are missing edges and incomplete evidence above.

## Findings per pass

**One pass: 14 findings.** I did not run a second pass. HEAD already contains an earlier independent
10-finding review of the unchanged target; the higher count here is a cross-review warning, so the
standing convergence discipline says to stop rather than iterate on prose. Four findings here are
additional acceptance/completeness defects (R2, R3, R8, and the expanded D6 result-contract portion of
R9), not re-openings of D1-D11.

## Probe result

One focused probe was built and retained under `probe009/p2/`, outside `/tmp`.

- **Negative:** a `ProviderState` that already contains an approval cursor cannot make HEAD-shaped
  `approval_read` state-threaded; compilation fails with arity 2 versus 1.
- **Positive:** widening the approval port to take `ProviderState` and return `ApprovalTransition`
  compiles cleanly.

The probe confirms that P2's immediate deferral may be chosen on sequencing grounds, but its claim
that record shape alone prevents another port widening is false.

## Recommendation

**Revise.** It is safe to begin the upstream-independent A1 implementation, but it is not safe to
execute or schedule the plan as a complete build order until R1, R5-R6, and R13 repair the plan-owned
risk/dependency/sizing claims and R2-R4, R7-R12, and R14 make every named gate obligation buildable and
falsifiable.
