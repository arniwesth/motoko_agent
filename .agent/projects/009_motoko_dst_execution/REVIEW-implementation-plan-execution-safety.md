# Review: is `PLAN-implementation-deterministic-test-world.md` safe to execute?

Date: 2026-08-02. Reviewer: independent session, no authoring context.
Target: `PLAN-implementation-deterministic-test-world.md` at `a23acff` (plan committed `1a18f65`,
reviewed to convergence `a339629`). Source ground: HEAD, pinned AILANG v0.26.0 (`ailang --version` →
v0.26.0, commit `3b52a24`).
Scope: the six plan-owned decisions, the dependency graph, acceptance evidence, sizing, milestone
boundaries, and completeness against ADR-001. **The architecture (D1–D11) was not re-derived.**

**Recommendation: Accept with conditions.** The build order is sound and nothing here blocks starting
WI-A1/A2/A4/A5. Ten findings follow; one is probe-backed and material (R1), three are missing or
mis-scoped dependencies (R2, R3, R5), five are ADR obligations with no home (R4, R6, R8, R9), one is
sizing (R7), one is an artifact fact that falsifies a stated build form (R10).

I did **not** reject the review framing. Scheduling builds instead of refining detector prose is the
right treatment, and I found no place where the plan hides a decision behind that scoping.

---

## Findings

### R1. P2's "closed structurally, not by guessing" is false for both cursors it defers, and the probe reproduces F6 on the second port

**Defect.** P2 (`:55-64`) defers the approval and clock cursors and closes the ADR's
bidirectional-widening warning with this: *"because of P1, adding a cursor later changes no port
signature; the state parameter stays `ProviderState` and the addition is an M1-class additive edit."*
That holds only for a cursor consumed at `model_step`. The approval and clock cursors are consumed at
`approval_read` and `clock_now`, which have **no state parameter at all** (`src/core/ports.ail:19-20`:
`approval_read: (ApprovalRequest) -> ApprovalResolution ! {IO}`, `clock_now: () -> int ! {Clock}`).
Adding a field to `ProviderState` does not make either cursor reachable. Threading it requires
widening a *second* port bidirectionally — precisely the change D1 marks as not behaviour-preserving
and the ADR warns against reproducing.

**Grounding — probe built on the pin, run from the repo root (not `/tmp`).** Three modules,
`ProviderState` record + a `Ports` record holding a state-threaded `model_step` and a HEAD-shaped
`approval_read`; source in the appendix.

| Stage | What was done | Result |
|---|---|---|
| 1 | State-threaded `model_step`, HEAD-shaped `approval_read` | `✓ No errors found`; cursor advances (`m0, m1, m2`) |
| 2 | Widen `ProviderState` with `approvals: [string]`, **touch nothing else** | Fails at the *construction* site only (`record field mismatch: expected 1 fields, got 2`); after adding the field there, `✓ No errors` and **`ports.ail` is byte-identical** |
| 3b | Add the approval cursor while keeping `approval_read`'s signature | Only available shape is a closure-captured cursor — the arrangement D1 prohibits by name. It **compiles clean** and **freezes**: `served: approval=allow / allow / allow`, advancing=false. **F6 reproduced on a second port.** |
| 3a | Make it actually thread | Requires `approval_read: (ProviderState, string) -> {resolution, next}` — a second bidirectional **port-signature change** |

So: P1's additive-record claim is now build-backed (stage 2 — this is stronger grounding than the M1
citation, which measured additive-field cost inside a record and never measured the sum alternative;
the citation can be retired in favour of this). P2's *decision* — don't ride along now — also survives:
neither cursor has an interim consumer, and stage 3b shows what the cheap workaround would cost. What
does **not** survive is P2's stated ground. The risk is not closed structurally; it is deferred, and it
lands on a different port if it lands.

**Action.** Restate P2's ground honestly: the deferral rests on *no interim consumer*, and the
structural closure covers only cursors consumed at `model_step`. Name the residual — a pre-`world_state`
approval or clock cursor forces a bidirectional widening of `approval_read`/`clock_now` — and state the
trigger that would reopen it (any interim need for a non-constant approval or a pre-`world_state`
virtual clock). One paragraph; no work item moves.

### R2. WI-A11's check cannot pass at HEAD, because the ADR records that its six anchors are deliberately *not* word-identical

**Defect.** WI-A11 (`:214-220`) schedules "a canonical classifier-2 predicate sentence … plus the
explicit list of normative anchors that must contain it, failing when an anchor drifts." The ADR states
the opposite property of those anchors: *"six normative sites, substantively aligned, **not
word-identical** … the six use six formulations"* (ADR `:462-465`). A containment check therefore fails
on at least four of the six the moment it is written — or forces six unbudgeted ADR edits to make them
word-identical, which is an amendment the plan does not schedule.

**Grounding.** The six sites, verified verbatim: Status block `:57` ("must have **every hook it
registers**"); D1 `:406` ("at extension granularity"); D5 exclusion `:1288` ("while any hook it
registers is **not** excluded"); D5 validation bullet `:1343` (same clause, different sentence frame);
acceptance row `:1839` ("while **registering** an un-excluded hook"); Implementation handoff item 2
`:2004-2009`, which does not use the phrase "classifier-2 field" at all ("an `ai_step`-calling
extension"). A11's acceptance evidence — "mutating one anchor in a scratch copy fails the check" —
passes trivially while the check is red on the unmutated artifact, so it does not detect this.

**Action.** Decide which of the two the item is, and say so: (a) an *anchor-set* check (each of six
named anchors states the predicate; drift detected by content hash per anchor + a named reviewer), or
(b) a canonicalisation, in which case budget the six ADR amendments in A11. Add to A11's acceptance
evidence: **the check is green on the unmutated ADR at HEAD.** That is the falsifiable half.

### R3. WI-C5 claims a 12-site routed set with no dependency on WI-A5 — the same correction round 1 applied to WI-A12, unpropagated

**Defect.** WI-C5 (`:305-314`) ends "and claim the 12-site routed set", and its only stated dependency
is B2. The 12-versus-13 split **exists only after the attribution table validates**: pre-table the split
is 5/13/13 and post-table 4/12/13 (ADR `:899-907`, `:1075-1079`). C5's claim is therefore a
routing-completeness claim gated on WI-A5, exactly as WI-A12's 4-site claim is — and A12 carries that
gate explicitly (`:234-236`), applied in the author's round 1. It did not propagate to C5. C5 also
needs A12 (there is no world clock to route `ExtPorts.clock_now` into before it exists).

This matters because the plan's own interleaving rule makes milestone order insufficient as an implicit
dependency: Milestone B "interleaves with whatever A-item is in flight" (`:100-102`) and C depends on B,
so C5 is not guaranteed to follow all of A. WI-C4 guards itself with "all of Milestone A" (`:300-302`);
C5 does not. The plan's blanket assertion at `:166` — "no routing-completeness claim anywhere in this
plan precedes this item" — is falsified by C5 under the plan's own scheduling rules.

**Action.** Add "Depends on B2, A5, A12" to WI-C5, and mark the routed-set figure as post-table
(12 with the table, 13 without), the same way A12 does.

### R4. WI-A10 enumerates the *manifest* field list and never the *profile-definition* field list; three required definition fields are not vacuous for `driver_only`

**Defect.** D5 requires a profile definition to record ten things (`:1109-1128`). WI-A10's acceptance
evidence (`:208-212`) enumerates D5's **manifest** fields — correctly and completely — and for the
definition offers only "`driver_only` loads clean" plus a fixture rejection. P4 (`:75-87`) lists four
things the definition records. Neither list contains:

- **included and excluded provider/tool adapter and parser boundaries** — not vacuous: `driver_only`
  runs the real provider path, and D3 (`:791-795`) makes the adapter/parser boundary a fault-catalogue
  scoping question ("must not claim wire-parser coverage from a typed post-parse result"). The
  acceptance row for profile honesty requires these be **listed** (`:1839`);
- **permitted diagnostic projections** — not vacuous: D1's collecting/no-op sink and D5's "bounded
  `IO`/`Trace` projection … not the oracle" (`:635-639`, `:1303`);
- **forbidden ambient effects/capabilities during execution** — not vacuous: this is the declared set
  A12's poison probes are supposed to test against.

"Loads clean" cannot falsify the absence of a field the validator was never told to require, so the
evidence is unfalsifiable for exactly the fields the plan omits. Related and also homeless: D5's rule
that a profile must **either extend the classifier scan roots through the resolved lock graph for every
installed AILANG package, or fail validation closed** when an installed package's source lies outside
`src` + `packages` (`:1483-1488`, live case `ailang.toml:9 sunholo/logging`). WI-A4's contract
(`:147-151`) fixes the roots at `src` + `packages` and says nothing about it. Exposure is nil today —
every installable package is in-tree — which is why it will be discovered rather than planned.

**Action.** In WI-A10, enumerate D5's ten definition fields the way the manifest list is enumerated, and
make the acceptance evidence falsifiable: a fixture definition missing any required field is rejected
at load, naming the field. Add the scan-root rule to A10's load validation (one clause: reject an
installed package whose source is outside the recorded roots).

### R5. Milestone B carries no dependency clauses, in the one milestone whose start time the plan cannot control

**Defect.** Every Milestone A item states its dependencies. No Milestone B item does — yet:

- **WI-B2** (`:267-275`) contains "the world-token widening of `ExtPorts.ai_step` plus the hook results
  and core dispatch results". The world token is `world_state`, built in WI-A12. If the trigger fires
  early, B2's larger half has no token to pass.
- **WI-B4** (`:284-285`) re-derives **both** classifiers and re-issues `driver_only`'s manifest —
  requiring WI-A4 (classifier 2 exists) and WI-A10 (a manifest to re-issue). Neither is stated, and B4
  is described as "a required step of every repin", so a repin landing before A4/A10 silently degrades
  to re-running classifier 1 alone.
- **WI-C1** (`:289-290`) names A1 in prose ("the blast radius A1 bought") but its `Depends on` clause
  says B1 only.

The plan explicitly makes this reachable rather than hypothetical: Milestone B "is **triggered**, not
queued … and interleaves with whatever A-item is in flight" (`:100-102`).

**Action.** Add explicit `Depends on` clauses to B2 (A2, A12), B4 (A4, A10, B1), C1 (A1, B1). If the
trigger fires before those land, the plan should say which part of the B item can proceed and which
waits — that is the scheduling information this milestone exists to provide.

### R6. Three D8 obligations have no home

**Defect.** WI-A13 (`:238-247`) builds "`ExecutionProgram`/`DiscoveryConfig` types, the seeded generator
with declared bounds, the pure structural validator, strict and regression replay modes, the interaction
log". D8 additionally requires, normatively, and no work item or out-of-scope line carries any of them:

1. **Secret handling**: "Programs contain synthetic values only. Environment maps and interaction
   artifacts must reject or redact secret-shaped/live credentials before persistence" (ADR `:1713-1715`).
   A fail-closed obligation on a persisted artifact, unscheduled.
2. **Encoding and compatibility policy**: "deterministic, diffable encoding with an explicit
   compatibility policy"; "a schema migration must either preserve old-program decoding or provide a
   pinned runner/artifact; silently reinterpreting an old program is forbidden" (`:1692-1694`,
   `:1710-1711`). D6 binds the event vocabulary to this same rule (`:1638-1640`), so it is load-bearing
   twice. Note ADR Non-goals explicitly delegates encoding selection to the implementation plan
   (`:1973-1974`).
3. **CI replay affordance**: "CI output must provide a copy-pasteable local replay command or artifact
   reference" (`:1693-1694`).

The author's self-review found two D8 gaps (canary, shrinking deferral) and scheduled both; these three
are in the same decision and were not swept.

**Action.** Add (1) and (2) to WI-A13's contents and acceptance evidence (a secret-shaped fixture is
rejected/redacted before persistence; an old-schema program either decodes or fails closed with a pinned-runner
pointer). Add (3) to WI-A14, where the failure report is produced.

### R7. Sizing is present on the six most mechanical items and absent on the three largest

**Defect.** Six of the twenty-two open work items carry a size: A1 (half a day), A2 (1–2 days), A4 (an
afternoon), A12 (several days), B1 (M2, measured), B3 (M1, measured). The sixteen with none include
**WI-A13** (build discovery and replay — program types, seeded generator, structural validator, two
replay modes, interaction log, generator canary: plausibly the largest single item in the plan),
**WI-A14** (the full D7 invariant set plus D11 corpus reporting), and **WI-B2** (the ABI major, which
the ADR calls "the larger of the two" changes and which requires lockstep re-release of every extension
package). The asymmetry is what misleads: a reader scheduling this sees four figures, all on small
mechanical items, and no signal at all where the schedule risk actually concentrates.

The analogies that *are* present are sound and conservatively directed — A1 at half a day for 4 files
against M1's 14 minutes for 28 is slower per file, which is the safe direction; A4 against classifier 1
is like-for-like. They are not, however, marked as estimates rather than measurements, where B1/B3 are
explicitly marked "measured".

**Action.** Size A13, A14 and B2 to the same standard as the rest — a range plus the basis, even a
coarse one — and label A1/A2/A4/A12 figures **estimate (by analogy)** so they read differently from
B1/B3's **measured**.

### R8. Runtime fail-closed exclusion, and the in-runner routing/exclusion probe, have no work item

**Defect.** D5 requires an excluded hook to "cause a fail-closed `HarnessFailure` if dispatch reaches
it" (`:1145-1147`), and D6.6 requires that violation to return a typed value with partial trace
(`:1589-1598`). The acceptance table requires the corresponding evidence: "Deliberate mismatch **and
in-runner routing/exclusion probes** return typed `HarnessFailure` with partial evidence" (`:1844`). The
plan schedules the *load-time* half everywhere (A5, A6, A10) and the *capability-bypass* half in A12's
poison probes, and WI-A13 covers the mismatch fixture — but nothing builds dispatch-time exclusion
enforcement or its probe. It is vacuous for `driver_only` (no extensions) and becomes required at
WI-C5, whose acceptance is WI-C4's row-by-row table.

**Action.** Give it a home — either a clause in WI-A10 (runtime routing installs the exclusion check)
or an explicit line in WI-C5 — with the probe as acceptance evidence. If the judgement is that it is
genuinely deferrable to C5, say that in C5 rather than leaving it unstated.

### R9. D11's two corpora are reported but never built

**Defect.** D11 requires two corpora — "a blocking PR corpus containing fixed seeds and exact promoted
regression programs" and "a scheduled rotating corpus whose seed window changes deterministically and is
reported" (`:1749-1752`) — each declaring an operator-accepted minimum the gate asserts. WI-A14 is
titled "the D7 invariant set and **D11 corpus reporting**" and its evidence covers the run report,
counters and promotion rule; WI-C4 then requires "D11's corpus minimums" as gate evidence. Nothing
schedules the two corpora or their CI jobs, and survey row 9 records that the only workflow at HEAD is
`verify-extensions.yml` with no generated-trajectory axis. The scheduled rotating job in particular is
new CI construction, not reporting.

**Action.** Either extend WI-A14's scope explicitly ("define both corpora and wire the PR-blocking and
scheduled jobs; the minimums are measured here") or add a WI-A15. The measurement clause at `:251-252`
already implies the jobs must run; make that a deliverable rather than a by-product.

### R10. WI-A8's preferred form — wire name derived from the type — is falsified by a variant at HEAD

**Defect.** WI-A8 (`:185-192`) says "preferred form derives the wire name from the type so drift is a
compile error", binding one wire name per variant. One of the 34 variants has a **payload-dependent**
wire name: `StreamDelta(StreamDeltaInfo)` projects to `reasoning_delta` or `thinking_delta` depending on
`i.kind` (`src/core/phase_vocab.ail:713`), and both are pinned by golden tests
(`phase_vocab.ail:1139-1140`); the variant's own trailing comment records the pair
(`phase_vocab.ail:631`: `-- [prod] thinking_delta | reasoning_delta`). The survey (`:33`) records "34
variants … wire names live in trailing comments" and does not record that one comment holds two names.
So the artifact's schema is `wire name = f(variant, payload)`, not `f(variant)` — a schema decision, not
a detector refinement, and one better made before A8 starts than inside it. A8's acceptance evidence
(fails closed on an unclassified variant) does not detect it.

**Action.** Record the fact in A8's scope and decide the schema there: either a per-variant wire-name
*set* with a total projection function, or split `StreamDelta` into two variants. Add to A8's acceptance
evidence: every one of the 34 variants round-trips to the wire name the current projection produces —
which the existing golden tests already make cheap.

---

## Checked and clean — no finding

Recorded because this project has under-recorded confirmations.

- **Survey spot-checks, all confirmed at HEAD**: clock inventory 13 real sites (14 grep hits, one is a
  comment at `session.ail:785`) split 4 driver / 1 `ext/runtime.ail:190` / 8 `motoko-ext-compose` ✓;
  `.ai_step(` call sites exactly 2 ✓; `.clock_now(` zero ✓; `Ports` 6 fields at `ports.ail:17-24` ✓;
  `deny_approval` `:26-28` wired at `:42` ✓; `ports_shape_probe` `:36` ✓; `C2LoopState` 18 fields at
  `session.ail:338-357` ✓; `emit_run_summary` `:833` with five call sites `1325/1554/1704/1711/1762` ✓;
  34 `LedgerEvent` variants at `phase_vocab.ail:597` ✓; `ledger_record_name` `:561` names 3, collapses 31
  to `"wire"` ✓; `finish_reason_str(r: int)` `:820` ✓; 37 `ledger_emit` vs 15 `ledger_append` ✓; 14
  configs, all 14 installing `compaction_ai` ✓; `make dst` aggregate as described ✓; `live_ports`
  `stub_step.ail:148`, `scripted_ports_from_steps` `:157`, the `assistant_count`-derived index at
  `:162-163` ✓; the P5 stale comment at `:170-173` ✓ (line 173 is stale too — `rt` is no longer a
  `dispatch_step` parameter); the three `.model_step(` consumers are exactly `session.ail:662`,
  `stub_step.ail:198`, `long_qwen:744`, matching WI-A1's edit surface ✓.
- **Classifier 1 re-run**: `make effect_inventory` → exit 0, 0 unresolved, `std/secret` resolved by the
  textual fallback as documented.
- **P6 is safe.** `hooks_runtime` has zero call sites; removal touches `ports.ail:23,38,46`,
  `stub_step.ail:144/154/167` and `long_qwen:186,257` — all sites WI-A1 already opens, and it also drops
  `ports.ail`'s only nine-effect row and its `ExtRuntime` import. The signature change to
  `ports_shape_probe` is real and co-located, as P5/P6 say.
- **P4's vacuity holds.** With an empty install list, D5's coverage floor, per-extension disclosure, and
  disjoint/exhaustive hook-set rules quantify over installed extensions and are vacuously true
  (`:1122-1124`, `:1218-1220`). The first profile can pass its own gate. (What is *not* vacuous for an
  empty install list is R4's three definition fields.)
- **WI-A9 does not need WI-A8** — the author's judgement is right. D6's prohibition is scoped to "any D7
  parity invariant or acceptance row that depends on the **logical/display-only classification**"
  (`:1628-1630`). A9's three checks — one final `RunSummary` on each terminal path, outcome/`DoneEvent`/
  `RunSummary` agreement, no integer code at a terminal call site — are structural over the returned
  trace's ADT, decidable against `LedgerEvent`'s `RunSummary` variant as it exists today. The spike's
  bespoke matcher is the existence proof. No dependency is missing.
- **The 32 `provider:` figure is honest as used.** `grep -c` = `grep -o | wc -l` = 32 at
  `session.ail`, and it over-approximates (it catches `st_provider:` at `:1452` and parameter
  declarations, not only loop-state literals). It is used to *bound* an edit surface, which is the
  conservative direction, and the plan says "bound". No change needed.
- **The D6 scheduling prohibition is honoured where claimed**: A14 splits its dependency on A8 for the
  parity-classification invariants (`:249-251`). The D4 prohibition is honoured at A12 (`:234-236`) and
  A5 (`:166`) — see R3 for the one site it is not.
- **The A1 → A2 → A12 → A13 → A14 spine is right**, matching D1's two-widening order and the ADR's
  handoff item ordering; I found no cycle and no false edge in Milestone A.
- **Milestone A's boundary claim holds** (`:330-333`), subject to R9: everything except streaming parity
  and extension-model coverage is inside it.

## Findings per pass

**One pass, ten findings.** No second pass was run: the plan is 357 lines with four author passes
already converged (11 → 9 → 1 → 0), and per the standing discipline a second reviewer pass over the same
artifact by the same reviewer is the shape that diverged on the ADR. Of the ten, **zero** re-find a
defect the author's `a339629` corrections addressed except R3, which is a *propagation* failure of round
1's A12 correction into C5 — reported for that reason.

Distribution: 1 probe-backed decision defect (R1), 3 dependency/scheduling (R2, R3, R5), 4 ADR
obligations with no home (R4, R6, R8, R9), 1 sizing (R7), 1 artifact fact vs stated build form (R10).
None reopens D1–D11.

## Probe result

Built one probe, three modules on pinned v0.26.0, run from the repo root (not `/tmp`; `MOD010`
auto-relaxation trap avoided). Both a positive and a negative result:

- **Positive (P1 confirmed).** Widening a `ProviderState` record used in a cross-module port signature
  is construction-site-only: `ports.ail` came out **byte-identical** across the widening, and the
  compiler pointed at every site that needed the new field. This is stronger evidence for P1 than the M1
  citation, which measured additive-field cost inside a record and never measured the sum alternative.
- **Negative (P2's ground broken).** With the same mechanism, an approval cursor cannot be threaded:
  keeping `approval_read`'s HEAD signature admits only a closure-captured cursor, which compiles clean
  and **freezes** — `served=[allow, allow, allow]`, advancing=false, F6's exact signature on a second
  port. Making it thread requires changing `approval_read`'s signature bidirectionally.

Appendix, the load-bearing part (stage 3b):

```ailang
-- probe_p2/state.ail
export type ProviderState = { script: [string], approvals: [string] }

-- probe_p2/ports.ail   (unchanged across the ProviderState widening)
export type Ports = {
  model_step: (ProviderState, string) -> { result: string, next: ProviderState },
  approval_read: (string) -> string          -- HEAD shape: src/core/ports.ail:19
}

-- probe_p2/driver.ail
func closure_approval(script: [string]) -> ((string) -> string) {
  func(_req: string) -> string {
    match script { [] => "exhausted", a :: _rest => a }   -- no successor: frozen
  }
}
```

```text
$ ailang check probe_p2/driver.ail        → ✓ No errors found!
$ ailang run --caps IO --entry main probe_p2/driver.ail
  served: model=m0 approval=allow
  served: model=m1 approval=allow
  served: model=m2 approval=allow
  model cursor advanced: remaining=0   (threaded, correct)
  approval cursor: served 'allow' three times   (frozen -- F6 on a second port)
```

The probe directory was removed; the tree is clean. Reproducing it costs about fifteen minutes and it is
worth promoting into `scripts/dst/` alongside `spike_scripted_cursor_probe.ail` if P2 is ever revisited.

## Conditions on acceptance

Blocking before the item concerned is executed, not before work starts:

1. **R1** — restate P2's ground and name the residual (before WI-A2 is designed, since it fixes the
   `ProviderState` shape).
2. **R3, R5** — add the missing dependency clauses (C5, B2, B4, C1). Cheap, and R3 is a live violation of
   a prohibition the plan asserts it honours.
3. **R2** — decide what WI-A11 checks; as written it cannot pass.
4. **R4, R6, R8, R9** — schedule the homeless obligations, or record each as a deliberate deferral the way
   the shrinking deferral is recorded. Both are acceptable; silence is not.
5. **R7, R10** — apply before the affected items are scheduled (A13/A14/B2 sizing; A8's schema).

Nothing above requires re-opening ADR-001, and nothing above blocks WI-A1, WI-A2, WI-A4 or WI-A5, which
are the four items the plan wants started now.
