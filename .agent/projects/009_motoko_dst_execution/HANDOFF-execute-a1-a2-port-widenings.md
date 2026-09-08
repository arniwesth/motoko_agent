# Handoff: execute WI-A1 and WI-A2 — the two `Ports.model_step` widenings

Audience: a fresh session grounded against HEAD. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`,
implementation is source-heavy work and belongs in a session that just read HEAD. You are that
session.

This is **cluster 1 of Milestone A** — the first code this project writes. Everything upstream of it
is Accepted and reviewed: ADR-001 (Accepted 2026-08-02),
`PLAN-implementation-deterministic-test-world.md` (two independent reviews, all findings applied at
`043bf65`). The session cut is `NOTE-execution-clustering-and-handoff-generation.md`; landing this
cluster is what makes clusters 4 and 6 groundable.

## Mission

Land WI-A1 and WI-A2 from the plan **as two separate commits**, ending green.

The plan is your specification — read WI-A1, WI-A2, and decisions P1, P2, P5, P6 there and do not
make me restate them here. This handoff carries only what the plan cannot: current grounding, the
one rule a session will break by accident, and the definition of done.

## Reading order

1. `PLAN-implementation-deterministic-test-world.md` — WI-A1, WI-A2, P1, P2, P5, P6.
2. ADR-001 **D1** — specifically the cursor-ownership paragraphs and the loss-channel scoping rule.
   The two widenings rest on *different* grounds and D1 is where that is stated.
3. `NOTE-spike-findings-real-driver-vertical.md` — **F2** (why the port is where information is
   thrown away) and **F6** (the live defect you are fixing). Skip the rest.
4. `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md` — short, and it governs
   how you must treat every anchor below.

## The one rule you will break by accident

**A1 and A2 are two commits, not one edit.** They touch the same field and it is genuinely tempting
to do them together. Do not.

The ADR requires it: *"The two must be planned and reviewed as distinct changes even though they
touch one field."* The reason is that they differ in a property that matters at review time —
**A1 is behaviour-preserving and A2 is not.** A1 widens the *result* with an emission log,
`emissions: []` everywhere, no behaviour change. A2 widens the same field *bidirectionally*, taking
provider state in and returning its successor, and it changes every construction site's contract.

Concretely: commit A1, verify it green, then start A2. If A1's diff contains a state parameter, you
have merged them.

**A1 does not enable A2.** A successor cursor is not an emission. If you find yourself reasoning
that A1 got you most of the way to A2, re-read D1 — that inference is the trap the ADR names.

## Settled — do not re-derive or re-open

- **`ProviderState` is a record, not a sum** (P1). Build-backed: a reviewer's probe widened a
  `ProviderState` in a cross-module port signature and the port module came out byte-identical.
- **No approval or clock cursor rides along** (P2). Two independent probes established that
  `approval_read`/`clock_now` cannot consume it without a second bidirectional port widening —
  the closure-captured alternative compiles and *freezes*, reproducing F6 on a second port. If you
  hit a genuine need for non-constant approval inside A2, **stop and report it**: that is P2's named
  reopening trigger, not a decision to make inline.
- **`ScriptedStep` must relocate** to `ports.ail` or below. `scripted_ports.ail` imports `ports`,
  `stub_step` *and* `session`, so both required consumers close a module cycle (`LDR002`) where it
  sits today. Budgeted, not discovered.
- **`ScriptedPortsState`/`scripted_model_next` is a design precedent, not reusable code.** It has
  the right shape (`state -> {result, next}`) and cannot be wired in.
- **The interim cursor's sole home is one explicit `C2LoopState` field**, threaded by the driver —
  not a closure inside a `Ports` value, not a provider ADT payload, and never re-derived from
  message history. D1 prohibits the last one by name and F6 is why.

## Re-ground these before you rely on them

Mandatory, per the sibling discipline. All were verified at HEAD on 2026-08-02 and
`git diff a0d4edb..HEAD -- src packages scripts` was empty at that point — **re-run it; if it is no
longer empty, re-measure everything below before trusting it.**

| Anchor | Verified 2026-08-02 |
|---|---|
| `Ports` record | `src/core/ports.ail:17-24`, 6 fields |
| Sole constructor | `ports_shape_probe`, `ports.ail:36` |
| A1's construction sites | `stub_step.ail:154`, `:167`; `long_qwen_compaction_dst.ail:179`, `:250`, `:767` |
| A1's result consumers | `session.ail:662` (`ext_ai_step`), `stub_step.ail:198` (`dispatch_step`), `long_qwen:744` |
| The F6 defect | `scripted_ports_from_steps`, `stub_step.ail:157`, index derived at `:162-163` |
| Cursor's interim home | `C2LoopState`, `session.ail:338-357` (18 fields), `provider: Ports` at `:344` |
| Entry-point normaliser | `ported_provider`, `session.ail:695`, 6 call sites |
| P5's stale comment | `stub_step.ail:170-173` — delete in A2; line 173 is stale too (`rt` is no longer a `dispatch_step` parameter) |

Re-ground the ADR's anchors into `stub_step.ail` in the same change, per P5, and file that as a
normal ADR amendment — **not** a review round. The ADR is Accepted.

## Definition of done

**A1 green:** `make check_core` passes; `make dst` targets pass unchanged; a `Scripted`-provider
test asserts the emission log is present and empty. Behaviour identical — if any existing test
changes its output, you have done more than A1.

**A2 green:** `scripts/dst/spike_scripted_cursor_probe.ail` **prints PASS and exits 0**. It exits 1
by design today; it is the executable statement of F6 and becomes the regression test. Also:
`phase_c2_wiring_scenarios` passes at its full count, `check_core` green, and no
`assistant_count`-derived script index survives anywhere.

Promote the probe out of spike naming into the `make dst` aggregate as part of A2.

Baseline before you start, so you can tell a real failure from a pre-existing one:

```
$ ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub \
    --entry main scripts/dst/spike_scripted_cursor_probe.ail < /dev/null
  control: served=[s0,s1,s2,s3,done]                    advancing=true
  folding: served=[s0,s1,s2,s2,s2,s2,s2,s2,s2,s2,s2,s2] advancing=false
  spike_scripted_cursor_probe FAIL — control_ok=true folding_ok=false
```

## Out of scope — actively do not do these

- **The extension model path.** `ext_ai_step` (`session.ail:662`) reaches the same seam through an
  ABI that cannot return a successor. A2 fixes the main loop only; that is a decision, not an
  oversight. Widening `ExtPorts.ai_step` belongs to the ABI major in Milestone B.
- **Adopting the recorded-stream API.** It does not exist in any released AILANG. A1 exists partly
  to shrink that adoption to one closure later.
- **Approval and clock cursors** (P2, above).
- **Anything from WI-A12's world-state threading.** A2's `C2LoopState` field is interim by design
  and A12 deletes it.

## Traps

- **Clear every `.ailang/cache` before believing a type error that contradicts the source you are
  reading.** Reproduced twice on this project, including across a compiler version change.
- **The compiler reports one record-field mismatch at a time** across the whole module graph, so
  naive convergence costs one round-trip per site. M1's 14 minutes held *only* because a
  brace-balanced literal rewriter and a compiler-driven fix loop were written first. Write the
  tooling before the edits.
- **Do not run probes from `/tmp`** — AILANG auto-relaxes `MOD010` there and a stdlib walk reports
  clean when CI would not.
- **PR #103 must not be merged** — it conflicts in six files and reverts `89a1d67`, which is the
  commit that made `C2LoopState.provider` a `Ports`.
- **The spike branch is not HEAD state.** Cite its measurements; never its file contents.
- Pin is v0.26.0 (`ailang.toml`, `scripts/install-prerequisites.sh:39`), Makefile-guarded.

## Report back

This is the plan's **calibration run** — the first item with real cost data. When you finish, record:

- **actual time and files touched for each of A1 and A2**, against the plan's estimates (A1: half a
  day, 4 files; A2: 1–2 days) — both are *estimates by analogy*, and this is what converts them into
  measurements for everything downstream;
- **how many sites needed genuine judgement** versus mechanical edit — M1 found 7 of 69 and that
  ratio is the number the rest of Milestone A is scheduled against;
- **anything in the plan that was wrong**, which is the point of building first. File it as a plan
  correction; do not silently reconcile.

If A1 or A2 materially overruns, say so before starting A12 — the plan's later sizing depends on
this ratio holding.
