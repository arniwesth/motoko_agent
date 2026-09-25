# 2026-07-03 Phase B plan authoring, review, dispositions, and Phase C handoff

Fresh plan-authoring session per `HANDOFF-write-phase-b-plan.md` (the second application of
the fresh-session ADR-completeness test). Produced the Phase B plan from the committed
documents plus the five Phase A commits, reviewed it iteratively to convergence, resolved
its substrate risks by probe, dispositioned its ADR gaps with operator sign-off, and wrote
the two bridging handoffs. No production code was written or modified.

## Artifacts produced (`.agent/projects/004_phase_core_refactor/`)

- `PLAN-phase-b-phase-results.md` — the Phase B implementation plan: WI-0…WI-8, plan-level
  decisions D-B1–D-B10, per-WI expected-diff tables, gate checklist, gaps G-B1–G-B7,
  anchor re-verification log. Committed as `6225bad`/`068bfbe`/`0d6e10a`/`340b6e1`.
- `HANDOFF-implement-phase-b.md` — implementer bridge (committed `eb2ff7e`); consumed by
  the implementation session that landed `fd933b6..a9616ad`.
- `HANDOFF-write-phase-c-plan.md` — Phase C plan-authoring bridge, written after the
  implementation landed (**untracked at session end — commit before the Phase C session**).
- ADR + research amendments (committed `340b6e1`): Phase-B Plan-Authoring Findings &
  Dispositions log (G-B1–G-B7), stage-recording wire scope (G-B1), result-level relocation
  wording (G-B3), G7 intercept arm (G-B4), inventory scope (G-B6), Open Question 4 remnant
  closed (D-B5), research §7.5 note.

## Grounding highlights

- All anchors re-read at post-Phase-A HEAD `d0d5b7e`; toolchain pin held
  (v0.26.0/`3b52a24`); `ailang test phase_vocab` (12 pass), sealing probe (`IMP010`), and
  `make smoke_parity` self-diff re-run green before being relied on.
- First read of `src/tui` in this project: unknown event types tolerated everywhere
  (no default arms, no exhaustiveness guards, `parseAgentEventLine` passes any object with
  string `type`, session logger writes them verbatim) — basis for [NEW]-name admission.
- Phase A as-built deviations recorded: harness normalizes more than its plan said; the
  as-built `to_schema_v1` [prod] arms were **not** byte-compatible (made WI-1 real work).
- Emission census corrected: ADR's 39/7/2/4 are grep hits including definitions; call-site
  truth is 38+6+1(+3 collapsing into the emitter).

## Review passes (three, to convergence) — the load-bearing fixes

- **Gate predicate made relative-to-input**: absolute pairing validity would have rejected
  legal transcripts containing intercept-synthesized orphan tool messages — the fixture
  smoke itself would have tripped it. (The implementation later hit and fixed a further
  bug in this predicate — see its findings note.)
- **Chain composition is unobservable in the loop's return** (compaction is per-step
  ephemeral) — chain smoke redesigned: direct `dispatch_pre_step_chain` section + JSONL
  event section.
- **Effective-limit convention**: compactors see only the segment post-WI-5, so the
  pre-step `ExtCtx.context_limit` is reduced by the pinned-prefix estimate; residual band
  documented in G-B3.
- **PassThrough-when-unchanged** for the relocated ladder, after discovering the
  compaction full-loop smoke's single-tool-message histories never actually elide — the
  original expected-diff table was wrong.
- Parity protocol hardened: strip mode transient, side files in a sibling dir, blessed
  baselines include [NEW] lines, strict diffs everywhere else.

## Probes (run in-session, operator-approved; artifacts deleted after)

- **G-B7 dependency shape** — passed with three discovered mechanics: path target must be
  the `.packages/motoko_core` mirror (not `src/core`); `[exports]` gates cross-package
  imports; transitively imported modules must also be exported.
  **Partially overturned by implementation**: root registration hit a MOD011 namespace
  collision, so the structural package vendors its measurement helper
  (`NOTE-phase-b-implementation-findings.md` supersedes the ADR's G-B7 entry in part —
  carried explicitly into the Phase C handoff).
- **29-constructor `LedgerEvent` arity** — clean on v0.26.0.
- Near-miss recorded: the probe session almost re-committed the `$?`-through-a-pipeline
  footgun from `NOTE-ailang-run-exit-code-false-alarm.md`; re-measured pipe-free.

## Dispositions (operator delegated: "I will follow your recommendations")

G-B1 accepted/doc-fix (wire records applied+rejected stages only; pass-through awaits
Phase C's in-memory ledger); G-B2 accepted/no-change; G-B3 accepted/doc-fix (result-level
preservation); G-B4 accepted/doc-fix (InterceptHandled arm); G-B5 deferred to ABI v3
(`history_slice` visibility); G-B6 accepted/doc-fix (inventory scope); G-B7 resolved by
probe. Also closed: OQ4's remnant — emergency path moves to the extension; core keeps
`exhaustion_pct()=95` on the re-pinned full list, fail-open at limit 0.

## Residuals for the Phase C session (encoded in its handoff)

- D-B1's deferral is Phase C's core work: `AwaitApproval` inversion unblocks tool-phase
  `PhaseResult` batching (tool_pending-before-readLine is the blocker).
- No in-memory ledger exists yet; L1 invariants and `StagePassed` records need it.
- `run_v2_with_stub` supersession must not orphan the parity harness (strangler adapter).
- Checkpoint content-hash comes due (scenarios consume digests); replaces both labeled
  placeholder digests; likely needs a hash-primitive substrate probe.
- Known TUI residual from the implementation session: `npm test` in `src/tui` fails
  pre-execution with a pre-existing Bun/Jest error — the WI-0 tolerance test exists but
  the suite runner is broken independently of Phase B.

## Worktree at session end

Untracked: `HANDOFF-write-phase-c-plan.md`, this summary, the implementer's summary
(`2026-07-03-phase-b-phase-results-implementation.md`), and the pre-existing `oh-my-pi/`.
The first three should be committed before the Phase C plan-authoring session starts — a
fresh session sees only committed files.
