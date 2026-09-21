# Review: ADR-001 Extension-owned structured decisions (v0.2)

Reviewer: Claude Fable 5.1 (`claude-fable-5-1`), second independent review, taking over the task
from Codex. Read-only against the working tree at HEAD `2062605`
(`20626054e8015ebd8623459789d8de8bb6c260d2`), extension ABI `7.4`, pinned toolchain AILANG
`v0.33.0` (matches `ailang.lock`). Reviewed ADR: 491 lines, SHA-256
`53956e5d25e8282b1f94d23f2f9f1ae4d9433ef90e0d482d165b7b5b1ce3258a`, verified at the start and
unchanged at the end of the review. No implementation file was modified; the only files written
are this review and the twelve compiler probes in the session scratchpad (Appendix A).

## 1. Architectural verdict

**Direction: sound, and v0.2 resolves the first review's thirteen items on paper.** Every row of
the "Current behavior" table re-checks against source except one qualifier, discussed under N14.
The per-atom two-phase cursor (D4), vote-family multiplicity (D2), typed evidence with explicit
absence (D3), nullary `Accept` (D4), the query-identity / policy-manifest split (D6) and the
strict-replay / offline-reinterpretation separation (D6) are the right resolutions and each is
now stated as a decision rather than an alternative. The precedence rules the ADR promises to
preserve are exactly what `merge_finalize_decisions` (`ext/runtime.ail:710-719`) and
`merge_tool_decisions` (`:402-416`) implement today: first `ContinueWithFeedback`, else first
`Accept`, else `NoDecision`; first `Deny`, else *last* `Pending`, else `Allow` if any, else
`NoOpinion`. The tool-policy site is per proposed call (`tool_phase.ail:567`) and `tool_phase.ail`
already receives core `Ports` and a `WorldState` (`:358`, `:516`) and is a leaf-inventory scan
root (`derive.py:44-45`, `:188-191`), so the second query leaf lands where the ADR says.

**Freeze readiness: not ready, for one new reason that is measured rather than argued.** The
ADR's D2 rests on the claim that a pure positional callback "admits no port effects even though
`ExtCtx` contains ports." On the pinned compiler that claim is false for the two most natural
registration shapes. An unannotated anonymous function placed directly in the `ToolPolicy` slot,
or bound with `let` and then placed there, may call `ctx.ports.ai_step` and `ailang check` accepts
it (Appendix A, probes p1 and p6). The same call in a named top-level function is rejected (p3,
p5, p12), a direct `std/*` effect in the same anonymous function is rejected (p7, p8, p10), and an
annotated anonymous function is rejected at its annotation (p9). The hole is therefore specific:
**effects of applying a function stored in a record field of the anonymous function's own
parameter are not inferred into that function's row.** `ExtCtx.ports` is precisely such a field.
017 ADR-001's B8 matrix and the pinned `run_declared_vs_performed.sh` IMPORTED-SUM rows measured
`std/env` and so read green while this door is open. This is N14 below, it is ABI-relevant
because the remedy is the callbacks' context type, and it must be settled before the freeze.

A second finding is not ABI but is an internal inconsistency the ADR must fix before acceptance:
D5's "durably record before dispatch" and "one recoverable journal transaction before advancing"
are written as if the AILANG child could write the journal. Under ADR-003 D3 it cannot
(`journal.ail:28-31`: "THE CHILD NEVER WRITES … one writer: the host"). That is N15.

Everything else is either resolved, or a sharpening that belongs in the implementation plan.

## 2. Remaining freeze blockers

| # | Blocker | Decision needed | Where |
|---|---|---|---|
| F1 | **N14.** Compiler does not enforce purity of an anonymous callback against `ctx.ports` calls. D2's enforcement claim and freeze-evidence item 2 fail on the pinned toolchain. | Give `prepare`/`interpret` a **ports-free context type** (an `ExtCtx` projection without `ports`, and without `world` since a pure callback cannot use it). Purity then holds by construction, independent of inference. Keep the compiler probe as a secondary gate and add the ports-door row to `run_declared_vs_performed.sh`. File the inference gap upstream. | D2, D3, freeze item 2 |
| F2 | **N15.** D5's durability ordering contradicts ADR-003 D3's one-writer model. | Choose the transport: (a) host-mediated over the wire, wake-style (`ports.wake_read` is the precedent: child emits request, blocks on the reply), which puts reservation → call → observation in the host's single write order and makes the durability claims true; or (b) child-side `Net` adapter with the weaker semantics "emitted before dispatch; the host's write order is the durability order; the crash window between emission and host write is accepted and named." (a) is recommended. The choice fixes `Ports.decision_query`'s effect row and where credentials live. | D5, D6, D7 |

F2 is not an ABI-surface change under either resolution, but the ADR as written promises what
the architecture cannot deliver, and the freeze evidence (items 5 and 6) would be measuring the
wrong thing. It should be corrected in the same revision.

## 3. New findings (N14 onward)

Ordered by severity. Each gives the consequence and the decision needed.

**N14. Purity of anonymous callbacks is not compiler-enforced against the ports door.** Measured
(Appendix A). Consequences: (i) the D2 sentence "The pure contract admits no port effects even
though `ExtCtx` contains ports" is false on v0.33.0 for inline and `let`-bound anonymous
functions; (ii) the "Current behavior" row "`ToolPolicy` is pure. Neither can call the current AI
port" holds only for named bindings — the in-tree registrations are mostly named
(`context-mode`, `omnigraph`, `microrag`, `repetition-guard`, `empty-stop-guard`), but
`progress-contract-guard/register.ail:20` and `compose.ail:1110` already register inline
functions, so the shape is in use; (iii) `tools/ext_ambient_inventory/hook_scope.py` cannot catch
it either: its enumerated doors are `std/*` symbols, builtins, interpolations and unresolvable
bindings, and a port call is classified `HOOK-PORT-MEDIATED`, which is the *good* verdict — for a
slot that must be port-free the instrument has no rule; (iv) D2's argument that pure slots are
"eligible for the pure-slot coverage criterion with zero barriers" therefore rests on a property
the toolchain does not check. Decision: a ports-free callback context (F1). Note the ADR's own D2
already says the interpreter "cannot execute against" the refreshed world token — with no ports
in scope that sentence becomes structural rather than aspirational.

**N15. D5's durable-before-dispatch ordering cannot be produced by the child.** `journal.ail:28-31`
and ADR-003 D3: the journal is host-written from wire events; the child emits and continues. So
"Before dispatch, durably record invocation identity and its reservation" and "Persist vote
application … as one recoverable journal transaction before advancing the session" have no
implementation in the child without a host acknowledgement barrier that does not exist today.
Provider calls are child-side (`session.ail:28` imports `std/ai (step, …)`), and the ADR leaves
the decision adapter's home open ("Endpoint and provider details remain adapter concerns"), but
the durability claims depend on it. Decision: F2. If (a), the child's `Ports.decision_query` live
arm is a wire exchange with row `{IO}` and the reservation/observation records are host entries
in host order — the ADR's language becomes literally true. If (b), rewrite D5's four durability
sentences to emission-order semantics and add the crash window to the freeze evidence.

**N16. Preflight is only replay-deterministic if its inputs are recorded.** D6: "Strict replay
re-executes deterministic preflight." Preflight depends on the operator's backend binding
(`UnconfiguredBackend`), the configured maximum charge (D5), and the effective limits. None of
these is currently a recorded input; profile configuration reaches the child through `config.ail`
and ambient env. If a replaying host has a different binding, admission diverges — which D6
correctly calls a replay failure, but ADR-004's admission run would then need the binding in its
"recorded configuration" (D1) or routed through the `env_get` port. Decision: state that
backend-binding resolution and query limits are recorded configuration inputs to the program, not
ambient reads. Settle before the plan; not ABI.

**N17. Live resume with a changed descriptor is undefined.** D6 says strict *whole-run replay*
rejects a changed interpretation policy; D7 says a *kind* change (`SolverJudge` →
`DecisionSolverJudge`) trips the existing `ExtSet` refusal (`journal.ail:632`). Neither says what
a live `--resume` does when the descriptor's `interpretation_config` changed under the same kind:
`ext_set_digest` is kind-only (`runtime.ail:1113`), so the refusal does not fire. Either the
descriptor snapshot enters the resume header comparison (refuse, `--resume-force` overrides, like
`Prompt`) or a resume writes a new policy snapshot entry and continues, with the journal showing
the change. Decision: pick one and say it. Settle before the plan.

**N18. Three sharpenings of D3's evidence types.** (i) `ToolCompleted.exit_code` uses `-1` for "no
subprocess, or a seam that cannot say" (`ports.ail:645-646`); `CommandExit(int)` must exclude that
sentinel and map it to `ToolOutcomeUnknown`. (ii) The typed `ToolOutcome` is consumed at dispatch
today and only its text survives in `st.msgs`; a `ToolEvidenceWindow` needs new accumulation on
`C2LoopState` and, on resume, is `complete_from_session_start = false` unless journal schema 2
carries typed outcomes — say which. (iii) `VerificationEvidence` requires `run_dp7_verifier`
(`session.ail:2241-2254`) to return more than `Approve | Reject`; the ADR says "preserve today's
gate behavior while distinguishing" — good, but note `is_missing_infrastructure` is a substring
heuristic over output (`:2231-2239`), so `VerificationUnavailable(reason, …)` carries a heuristic
classification and the guard should treat it as uncertain, which D3's prose already implies.

**N19. Wire request identifiers.** The OpenRouter request type carries optional `sessionId`,
`user` and `trace` fields (verified, Appendix B). D6 excludes credentials from the record but says
nothing about what identifiers the adapter *sends*. Decision: the adapter sends no session or user
identifier unless the ADR records it as part of the canonical request; the corpus-privacy line
(ADR-004 D6) argues for sending none.

**N20. Schema-1 live-resume refusal is stricter than truth requires.** D7 refuses a schema-1 live
resume "rather than fabricate historical evidence, spending, or counters." A pre-upgrade journal
contains no decision queries because the feature did not exist; zero spend and zero counters are
the truth, not a fabrication, and an evidence window starting incomplete is truthful under D3.
The refusal is a legitimate choice, but its cost is that every existing session becomes
non-resumable at the major. Recommendation: define the schema-2 fold as a strict superset that
reads a schema-1 body with empty decision state, and reserve refusal for a schema-2 journal read
by a schema-1 runner. Not ABI; settle in the plan.

**N21. `/5`'s stated reason.** The tree's own rule (`dst_interaction.ail:99-108`, WI-D17) is that
adding an `IdentityBody` constructor does *not* force a program-schema bump; `/4` was forced by
the wake class's *observation payload* (`dst_program.ail:119-131`). D7 lists "identity,
request/observation codecs, scripts, cursor" together, which is fine, but the bump should be
attributed to the observation payload and scripts so the rule is not misread later.

**N22. N1's witness extraction is optional.** `witness` is private to `session.ail` (`:4572`), but
`tool_phase.ail` does not witness today: it advances the world at its leaves (`:484-501`) and
`session.ail` witnesses the returned trace with the returned world (`:3623`). A tool-policy
decision leaf can follow that pattern unchanged. Extracting `witness` is harmless; it is not
required for the inventory to see the leaf.

## 4. N1–N13 resolution table

| # | First-review item | v0.2 claim | Verified against | Status |
|---|---|---|---|---|
| N1 | Execution site | Per-atom two-phase cursor; leaves in `session.ail` / `tool_phase.ail`; no `ExtPorts` field | `tool_phase.ail:358,516,567`; `derive.py:44-45,188-191`; `session.ail:516` (`provider: Ports`) | **Resolved.** See N22 on the witness helper. |
| N2 | Multiplicity | One vote per family; legacy/new cross-kind rejected | `registry_normalize.ail:168-174,231`; `runtime.ail:1139` | **Resolved** as a decision; encoding is implementation. |
| N3 | Typed evidence | `verification`, `tool_evidence`, `decision_state` on `ExtCtx`; no file snapshot | `session.ail:2241-2254`; `ports.ail:645-651`; `types.ail:536-619` | **Resolved**, with N18's three sharpenings. |
| N4 | Hidden config | Descriptor with versions/configs; host cannot inspect closures, says so | `runtime.ail:1108-1112` | **Resolved** honestly. Disclosure is a conformance obligation, stated as such. |
| N5 | Version split | Question identity vs interpretation metadata; strict whole-run checks both; offline experiment labelled | — (design) | **Resolved.** The offline experiment's "cannot be presumed applicable once votes branch" caveat is correct. |
| N6 | Replacing `Accept` | Nullary at 8.0; synthetic test must change | `session.ail:3281`; `runtime.ail:794` (`Accept("accepted")`); `repetition_guard.ail:309`; `test-dummy/register.ail:80` | **Resolved.** The ADR's characterisation of in-tree acceptors is accurate. |
| N7 | Accounting | New propagation path; optional usage; reservation ledger | `session.ail:1094-1110,449-456,1549` | **Resolved.** Add one sentence: conservatively-charged decision spend enters `totals.cost_millicents` so `call_model_or_fail`'s `BudgetExceeded` (`step_machine.ail:114`) sees it. |
| N8 | Durable state | Host-owned counters keyed by owner/site/local ID; atomic application | `runtime.ail:343-347`; `journal.ail:28-31` | **Resolved in design; N15 in mechanism.** |
| N9 | Cancellation / resume | Timeout vs process death; reservations persisted | `session.ail:4809`; ADR-002 | **Resolved**, subject to N15. |
| N10 | Every atom runs | Full ordered collection, paid losers | `runtime.ail:721-728` | **Resolved.** |
| N11 | Compatibility | ABI 8.0, `/5`, journal 2, vocabulary 2; unknown-tag rejection | `ext_world.ail:405-429`; `dst_program.ail:132`; `journal.ail:635`; `dst_event_vocabulary.ail:121` | **Resolved**, with N20 (refusal breadth) and N21 (bump rationale). |
| N12 | Events | Immediate/skip/losing/shadow/applied records | — (design) | **Resolved.** |
| N13 | Provider claims | Attributed to drafting agent; dated | Appendix B | **Partially confirmed by this review.** SDK endpoint `POST /api/alpha/decisions` and the optional `confidence`/`probabilities` fields verified. The route `typesafe/jev-1.13` was **not** confirmed: the model page returned 404 and the models API fetch was truncated. |

## 5. Q1–Q7 status

| Q | v0.2 choice | Status |
|---|---|---|
| Q1 | Declared prepare/interpret | **Accepted, amended by F1.** The declared shape is right; the callback context must drop `ports` (and `world`) for the purity argument to hold. |
| Q2 | Both variants in 8.0, shared vocabulary | **Accepted.** Shared `DecisionRequest`/`DecisionObservation`/answer types are site-independent as recommended. |
| Q3 | Three `ExtCtx` additions plus host state | **Accepted**, plus the F1 context-type decision, which is the fourth ABI-relevant item under this Q. |
| Q4 | Basis-point ints, `Option` in ABI types, closed `UnavailableReason` excluding control failures, optional usage | **Accepted.** The largest-remainder apportionment and `1e-6` tolerance are adapter rules, correctly kept off the ABI. |
| Q5 | Nullary `Accept` | **Accepted.** |
| Q6 | Admission, reservation, counters, timeout, crash recovery | **Accepted in intent; F2 must be resolved for the text to be true.** |
| Q7 | Separate migrations; schema-1 refusal | **Accepted**, with N20 as a recommendation and N17 as a gap. |

## 6. D1–D7 assessment

| Decision | Verdict | Note |
|---|---|---|
| D1 Extension owns judgment; host owns execution | **Accept** | Unchanged from v0.1; matches 005 ADR-001. |
| D2 Two pure declared capabilities | **Accept with F1** | The signatures and vote-family rule are right. The purity *enforcement* claim is falsified by probe; fix the context type, not the shape. |
| D3 Typed observations, absence, evidence | **Accept with N18, N19** | Well specified. Add the `-1` sentinel rule and the identifier rule. |
| D4 Per-atom two-phase execution at scanned leaves | **Accept** | Verified against both dispatchers and the scan roots. Precedence statements are exact. |
| D5 Bounded cost and interventions | **Accept in design; F2 in mechanism** | The reservation ledger and host-owned counters are right; the durability sentences must match ADR-003 D3. |
| D6 Recorded queries and identity split | **Accept with N16, N17** | Query identity vs policy manifest is correct. Name the recorded-configuration inputs and the live-resume rule. |
| D7 Explicit migrations | **Accept with N20, N21** | Inventory is honest about being point-in-time. |

## 7. What must be settled before the freeze versus after

**Before the ABI freezes:** F1 (the callback context type — this is the one ABI change this review
adds); the rest of the freeze list in the ADR's "Freeze evidence" §1–3, with item 2 rewritten to
name the ports door and to include a runtime probe, since a compile-time green on v0.33.0 is now
known to be insufficient for anonymous callbacks.

**Before the implementation plan, not before the freeze:** F2, N16, N17, N18, N19, N20.

**After both:** N21, N22, adapter rounding rules, limits, first-guard wording, shadow-mode
measurement.

## 8. Method and limitations

Read in full: the ADR v0.2, the v0.1 review, both research notes, `packages/motoko-ext-abi/types.ail`
(the `Capability` sum, `ExtCtx`, `ExtPorts`, the four decision types), `ext/runtime.ail` (both
dispatchers, both merges, `ext_set_digest`), `registry_normalize.ail` (vote kinds), the relevant
regions of `session.ail` (`classify_candidate`, `run_dp7_verifier`, `ext_ai_step`, `witness`,
`C2LoopState`, `RuntimeLoopTotals`, `CandidateClass`, the finalize history construction), the
tool-policy boundary in `tool_phase.ail`, `ext_world.identity_body_of`, `dst_interaction.ail`'s
identity notes, `dst_program.ail`'s version history, `journal.ail`'s header and refusal messages,
`dst_event_vocabulary.ail`'s version, `dst_profile_coverage.ail`'s kind classification,
`derive.py`'s scan roots, `hook_scope.py`'s door enumeration, `run_declared_vs_performed.sh`'s
IMPORTED-SUM rows, and 017 ADR-001's B8 section.

Run: `ailang check` (v0.33.0, the pinned build) on twelve probe modules against the real imported
ABI, from the repository root so `pkg/sunholo/motoko_ext_abi` resolved from `ailang.toml`
(Appendix A). No other build, test, or `make` target was run. No implementation file was edited.
Three web fetches for N13 (Appendix B).

Not done: a **runtime** proof that the smuggled `ai_step` call in p1 executes (017's B8 did this
with `ailang run --caps` for the `std/env` door; the compile-time acceptance alone falsifies the
ADR's "compiler probes" claim, which is what was under test). I did not re-probe the local-sum
matrix or the `smuggle` record-field row. I did not read `dst_replay.ail`, `dst_persistence.ail`
or `world_ordinal.ail` this pass; their citations are carried from the first review. Line numbers
are working-tree at review time and will drift. The OpenRouter model listing check is
inconclusive, not negative.

## Appendix A — Compiler probe matrix (D2 purity, imported ABI sum, v0.33.0)

All probes register into the real `Capability` sum imported from `pkg/sunholo/motoko_ext_abi/types`.
"Slot" is the payload row of the constructor used. "Body" is the effect the callback performs.
Files are in the session scratchpad under `probe/`; sources for the two decisive cases follow.

| Probe | Slot (row) | Callback shape | Body | Expected | **Measured** |
|---|---|---|---|---|---|
| p1 | `ToolPolicy` (`{}`) | inline `func`, unannotated | `ctx.ports.ai_step` (`{AI,IO,Trace}`) | rejected | **ACCEPTED** — `✓ No errors found!` |
| p2 | `ToolPolicy` (`{}`) | inline `func`, unannotated | pure (`ctx.task == ""`) | accepted | accepted (control) |
| p3 | `ToolPolicy` (`{}`) | named top-level, declared `! {AI,IO,Trace}` | `ctx.ports.ai_step` | rejected | rejected: `incompatible closed rows: r1 has extra labels [], r2 has extra labels [AI IO Trace]` |
| p4 | `ToolPolicy` (`{}`) | `let`-bound `func` annotated `! {AI,IO,Trace}`, via helper | `ctx.ports.ai_step` | rejected | rejected (same message) |
| p5 | `ToolPolicy` (`{}`) | named top-level, **unannotated** | `ctx.ports.ai_step` | rejected | rejected (same message) — named bindings infer the row |
| p6 | `ToolPolicy` (`{}`) | `let`-bound inline `func`, unannotated | `ctx.ports.ai_step` | rejected | **ACCEPTED** |
| p7 | `Compactor` (`{AI,IO,Trace}`) | inline `func`, unannotated | `std/process.exec` | rejected | rejected: `r1 has extra labels [AI IO Trace], r2 has extra labels [Process]` |
| p8 | `ToolPolicy` (`{}`) | inline `func`, unannotated | `std/io.println` | rejected | rejected: `r2 has extra labels [IO]` — direct std effects **are** inferred |
| p9 | `ToolPolicy` (`{}`) | inline `func`, annotated `! {AI,IO,Trace}` | `ctx.ports.ai_step` | rejected | rejected at the annotation (B8's "(i-annot)" reproduced) |
| p10 | `ToolPolicy` (`{}`) | inline `func`; applies a captured `let g = println` | `g("…")` | — | rejected: `r2 has extra labels [IO]` — a captured function value **is** inferred |
| p11 | `SolverJudge` (`{Process}`) | inline `func`, unannotated | `ctx.ports.ai_step` | — | rejected, but only as `Missing effects: Process` on the enclosing `caps` (5.x absorption); `AI/IO/Trace` from the port call are **not** reported |
| p12 | `ToolPolicy` (`{}`) | inline `func` calling a named helper `run_port(p: ExtPorts, w)` that calls `p.ai_step` | via helper | rejected | rejected: `r2 has extra labels [AI IO Trace]` — the named helper infers the row |

**Reading:** the checker infers a lambda's row from direct `std/*` calls (p7, p8), from captured
function values (p10), and from called named functions (p12); it does **not** infer it from
applying a function stored in a record field of the lambda's own parameter (p1, p6, p11). Named
top-level functions infer that case correctly (p5). The gap is an AILANG inference defect and
should be filed upstream via the `ailang-feedback` route; until fixed, no compile-time gate can
enforce D2's purity for anonymous callbacks that receive `ExtCtx`.

p1 source (`probe/p1_direct_effectful.ail`):

```
module probe/p1_direct_effectful

import pkg/sunholo/motoko_ext_abi/types (Capability, ToolPolicy, ExtCtx, ToolCallEnvelope, ToolPolicyDecision, Allow)

export func caps() -> [Capability] {
  [ToolPolicy(func(ctx: ExtCtx, call: ToolCallEnvelope) -> ToolPolicyDecision {
    let _ = ctx.ports.ai_step(ctx.world, "m", []);
    Allow
  })]
}
```

p8 source, the control that shows the checker *does* see a direct effect in the same shape
(`probe/p8_empty_row_io_only.ail`):

```
module probe/p8_empty_row_io_only

import std/io (println)
import pkg/sunholo/motoko_ext_abi/types (Capability, ToolPolicy, ExtCtx, ToolCallEnvelope, ToolPolicyDecision, Allow)

export func caps() -> [Capability] {
  [ToolPolicy(func(ctx: ExtCtx, call: ToolCallEnvelope) -> ToolPolicyDecision {
    let _ = println("smuggled");
    Allow
  })]
}
```

Command, from the repository root: `ailang check <probe file>`. Each run printed the
`sunholo/motoko_core content changed` lock warning and a `MOD010 (temp-path)` relaxation
warning; neither affects the verdicts.

## Appendix B — N13 external checks (2026-09-18)

| Claim in ADR | Source fetched | Result |
|---|---|---|
| SDK exposes `POST /api/alpha/decisions` | `github.com/OpenRouterTeam/typescript-sdk/blob/main/src/funcs/alphaDecisionsCreate.ts` | **Confirmed.** Function `alphaDecisionsCreate`, `"POST"` to `"/api/alpha/decisions"`, request `operations.CreateApiAlphaDecisionsRequest`, response `models.DecisionsResponse`. |
| Choice answer allows absent probabilities and confidence | `…/src/models/decisionschoiceanswer.ts` | **Confirmed.** `{ choice: string; confidence?: number; probabilities?: {[k]: number}; type: "choice" }`. |
| Request shape: model, state, named questions | `…/src/models/decisionsrequest.ts` | **Confirmed**, with detail the ADR should absorb: `state: string \| object \| array`; `questions` is a **map keyed by name** with kinds `Choice`, `Noul`, `Score`; optional `provider`, `sessionId`, `trace`, `user` (see N19). The ADR's ordered `[NamedQuestion]` with `Binary \| Choice \| Rubric` is a fine canonical projection; the adapter owns the array→map and `Binary`→`Noul`, `Rubric`→`Score` mapping. |
| Model `typesafe/jev-1.13` on OpenRouter | `openrouter.ai/typesafe/jev-1.13` | **Not confirmed:** HTTP 404 from the fetch (may be an SPA route the fetcher cannot render). |
| Same | `openrouter.ai/api/v1/models` | **Inconclusive:** the fetch returned a 10-entry list with no `typesafe`/`jev` id, which is clearly truncated. |

## Review provenance

- Reviewer: Claude Fable 5.1, `claude-fable-5-1`, taking over from a Codex session at the
  operator's request.
- Reviewed ADR: `ADR-001-extension-owned-structured-decisions.md`, v0.2, 491 lines, SHA-256
  `53956e5d25e8282b1f94d23f2f9f1ae4d9433ef90e0d482d165b7b5b1ce3258a`, verified before reading and
  after writing this review.
- Git HEAD: `20626054e8015ebd8623459789d8de8bb6c260d2`, branch `arniwesth/013-plan003-and-herdr`;
  the ADR and this review are untracked working-tree files.
- Toolchain: `ailang` v0.33.0 (`/home/motoko/.local/bin/ailang`, commit `ae36986`), equal to the
  `ailang.lock` pin.
- Tools used: `Read`, `Bash` (grep/sed over the tree; `ailang check` on scratchpad probes),
  `WebFetch` (three GitHub files, two OpenRouter URLs). No `Edit`/`Write` outside this review
  and the scratchpad.
