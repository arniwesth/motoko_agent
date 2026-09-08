# Handoff: cluster 8 — WI-A13 stage 2, discovery against `driver_only`

Audience: a fresh, source-grounded session. You are **executing**, not reviewing.

Parent handoff: `HANDOFF-execute-a13-discovery-and-replay.md` — its *Mission*, *Definition of done*,
*Out of scope* and *Traps* sections govern the whole item and are **not restated here**. Read it
first. This document scopes stage 2 of its five, carries what cluster 7 learned, and fixes the order.

Predecessor report: `NOTE-cluster-7-execution-report-and-plan-corrections.md`. Read its S1 result —
it changes how you should build this stage's assertions.

## Mission

**Stage 2: discovery against `driver_only`.** Record what the real driver actually requests, into the
interaction log, with causal identities and encounter ordinals.

Stage 1 landed the types and the pure structural validator (`src/core/dst_program.ail`,
`make execution_program`). Stages 3–5 — strict replay, regression replay, D8's persistence — are
**not** this session's. Finish stage 2, commit, report. Do not carry a half-built stage across a stop.

## Build the assertions before the recorder, and build them in both directions

Cluster 7's S1 result is the reason this section leads. It was the fifteenth site in this project
where two implementations type-check and the wrong one is silent, and it was caught by a **negative
control** — a fixture that had to *survive* — after passing all 18 mutation rows.

The generalisation now standing in
`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`:
**a one-sided assertion set cannot see failures in the other direction.** Determinism tests sameness,
so it cannot see that nothing moved. Mutation tests rejection, so it cannot see over-rejection.

**A recorder has exactly this two-sided exposure, and only one side is currently named:**

| Direction | Failure | Assertion |
|---|---|---|
| Under-recording | the recorder drops a class | **completeness** — named in the parent handoff |
| Over-recording | the recorder logs a request the driver never made | **nothing yet — you must name it** |

Decide this deliberately rather than discovering it in cluster 9. The obvious shape for the second is
the same witness comparison run the other way: every logged interaction must have a corresponding
driver-side witness, not merely every witness a logged interaction.

**Write the completeness assertion first and prove it red against a recorder that drops a class,
before the recorder exists.** This is the same discipline that caught four defects in A12 and it has
now paid seven times across seven clusters.

## The order, and why

Per S3 — route the cheap instance of a seam before the awkward one. Cluster 7 verified the witnesses;
all four re-verified at HEAD for this handoff.

1. **Provider.** `ProviderCallPrepared` at `src/core/session.ail:1958`, emitted by the driver
   *separately from* the `dispatch_step` call at `:1969`. Strong, cross-component.
2. **Tool.** `V2ToolDispatchStart` at `src/core/tool_phase.ail:332`, emitted before the port calls at
   `:342-343`. Strong, cross-component.
3. **Approval.** Cursor consumption — the `world.approvals` length delta. Medium: the
   response-producing mechanism versus the log-writing one.
4. **Clock.** `world.clock_ms` delta against the sum of recorded advances. Strong, and general across
   classes — useful as a cross-check on the others.
5. **Env — last, and its evidence is a different kind.** See below.

**Why the ledger trace is the load-bearing witness:** it is written by production driver code and
owned by D6, while the interaction log is written by the world adapter. Two authors, two records, one
execution. That is what makes it an oracle rather than the recorder grading itself.

## The env class has no runtime witness — do not manufacture one

`ports.env_get` is a keyed lookup, not a cursor (`src/core/ports.ail:97-101`: *"reads do not consume
it and the successor is the same world"*), and no ledger event is emitted for one. The only runtime
record that an env read happened would be the recorder's own log entry — the recorder-as-its-own-oracle
shape.

**Use a source-derived expected key set instead.** The driver's env reads are at statically known call
sites across `session.ail` and `tool_phase.ail`, seven distinct keys: `MOTOKO_SESSION_ID`,
`MOTOKO_PERSIST_RETRIES`, `MOTOKO_RETRY_STREAM_ERROR`, `OPENAI_BASE_URL`, `MOTOKO_HEADLESS`,
`MOTOKO_TOOL_TIMEOUT_MS` (`tool_phase.ail:343`), `MOTOKO_CAPTURE_FAILED_PAYLOAD`. Derive the set from
source, the way `tools/ext_call_inventory/derive.py` already does for classifier 2 — static rather
than dynamic, but genuinely independent of the recorder.

**Report it as a different kind of evidence.** A12 anticipated this and left the seam deliberately
(`ports.ail:100`); its Env-withheld poison pair is *DEFERRED, not skipped*, with its evidence recorded
as provenance rather than capability. A13's report and D11's counters must not present one uniform
completeness number across seven classes when one of them is established differently.

## Inputs, verified present at HEAD (`d2b8e4d`)

- `src/core/dst_program.ail` — stage 1's types and validator.
- `scripts/dst/execution_program_dst.ail`, `make execution_program`, wired into `make dst`.
- `src/core/dst_profile.ail` / `driver_only` v1 (A10) — the profile discovery runs against.
- `src/core/dst_fault_catalogue.ail` (A7) — class ids for causal identity.
- World-state threading complete across all six effect classes (A12).
- `make world_state`, `make terminal_trace`, `make dst` — all green; `make dst` **exit 0**.

Re-ground before building: `git diff d2b8e4d..HEAD -- src packages scripts Makefile` should be empty.
If it is not, re-verify the anchors above rather than inheriting them.

## Stop and report rather than deciding inline

- **A specification clause that admits two readings.** This is what consumed stage 1's entire risk
  budget, and S6's "recorded binding" term now generalises to *any fact that cannot be read and must
  be decided*. If D2 or D8 admits two readings for identity, ordinal semantics, or what counts as a
  recorded request — write both down, say which you took and why, and put a fixture on it.
- **Any need to change `Ports` shapes.** A12 fixed them; stage 2 records through them.
- **Any driver behaviour change.** Discovery observes; it does not alter what the driver requests.

## Traps

- **Do not extrapolate stage 1's cost.** It was the cheapest of the five — pure, no driver, no world.
  Stages 2 and 3 carry the driver wiring, which is where A12 overran on nominally identical scope.
- **Read `make dst`'s exit status, not its output.** It was exit 2 for two clusters while looking
  green, hidden by `--keep-going` among 233 passing lines.
- **Anchor any new structural guard to a syntactic form, not a bare token.** A guard that greps a bare
  string will eventually fire on the artifact documenting it — cluster 7's correction 1. Cluster 7
  also recommends a general audit pass over existing guards; if you touch the Makefile, that is a
  cheap thing to fold in.
- **Rebuild the parallel `ailang check` closure tool before editing.** 2.4 s over the 12-module DST
  closure; it is what has made site convergence linear across six clusters.
- Standing: clear stale `.ailang/cache` before believing a type error; do not run probes from `/tmp`
  (AILANG auto-relaxes `MOD010` there); PR #103 must not be merged.

## Report back

`NOTE-cluster-8-execution-report-and-plan-corrections.md`, following cluster 7's shape. It should
carry:

- **the aggregate gate's exit status**, not a scan of its output (cluster 7's process amendment);
- the sizing measurement — sites, judgement ratio split between machinery and content, round trips —
  and whether S6 still transfers with its generalised second term;
- **any site where two implementations type-checked and one was silently wrong**, with what caught it
  *and what did not*. Seven clusters running, this has been the most valuable line in every report;
- whether the over-recording assertion was buildable, and what it cost;
- plan corrections, filed rather than reconciled.
