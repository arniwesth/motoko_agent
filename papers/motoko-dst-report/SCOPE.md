# SCOPE — Motoko DST Technical Report

**Status**: Scope agreed 2026-08-10 (this session). No prose drafted yet.
**Decisions taken**: External / arXiv-style audience · architecture + light numbers (no new
experiments) · DST-centered with the harness as context · 8–12 pages.
**Working title candidates** (pick at draft time):

1. *Swap the Ports, Keep the Code, Read the Ledger: Deterministic Simulation Testing for an LLM Agent Harness*
2. *A Deterministic Test World for an LLM Agent Harness*
3. *Earning the Name: Deterministic Simulation Testing in the Motoko Agent Harness*

---

## Thesis

Three layered claims, in order of load-bearing weight:

1. **DST applied to a new domain.** The nondeterminism being tamed is not a network or a disk —
   it is a *model provider* plus tool execution, wall clock, and env. The architecture is a
   ports swap: production transition code runs unchanged against scripted fakes, emits a typed
   ledger trace, and reusable structural invariants are asserted over the trace — never over
   model prose. Seeded event-order generation, a logical-fault catalogue, a virtual clock, and
   exact-program strict replay complete the FDB-style bar.
2. **Epistemic discipline as methodology.** The project *reserved the word "DST"* behind a
   written conformance bar (007's taxonomy ADR), met it via an eleven-row acceptance table for
   one named profile, and mandates vacuity accounting in every claim (`driver_only`'s
   extension-model coverage is zero; `driver_plus_no_ops`'s is "non-zero and entirely of
   no-ops"). Coverage claims are computed, not asserted, and guarded by tooling
   (`check_no_op_profile.py`). This is the report's most novel material.
3. **The meta-point (discussion-level only, per scope decision).** Motoko is a
   Phoenix-architecture codebase — no human-written code — and DST is the trust mechanism that
   makes that tenable: caps-as-conformance, anti-silent-drop count oracles, the RNG canary.
   One discussion subsection, not the framing.

## Mandatory claims constraints (the repo's own rules bind this report)

Per D10 of `009/ADR-001` and the spine doc's naming block — an external report is exactly the
artifact these rules were written for. **(Updated 2026-08-10 after reconciling against the
WI-D27/D28 record at HEAD `b3953a9`; the spine doc, refreshed 2026-08-07, is stale on profile
coverage — the D27/D28 NOTEs are the authority.)**

- Every use of the unqualified "DST" label for the generated axis **must name the profile**.
  Three exist at HEAD: `driver_only` v22 (name earned on v10), `driver_plus_no_ops` v9,
  `driver_plus_compose` v1.
- Coverage claims must be stated as the profiles' own STATEMENT lines state them:
  `driver_only` — zero; `driver_plus_no_ops` — non-zero and entirely of no-ops (32 hooks /
  4 extensions, 16 vacuous under D5 criterion 2); `driver_plus_compose` — 7 covered + 1
  excluded, of which **one** hook mediates the world substantively. The tree-wide honest form
  is the computed vacuity register: **one of forty classification entries is measured and
  substantive**; hermeticity is enforced **per profile** (compose's registration gap is stated,
  not closed); `extension_effect_fault` is waived by every profile.
- The label covers the **generated axis only**; fixed scenarios are property-based testing over
  agent-loop state and must not be called DST unqualified.
- Scenario ids are the stable public contract; quote ids, not script paths.

## Section outline (8–12 pp)

| § | Title | Pages | Content | Primary sources |
|---|---|---|---|---|
| 0 | Abstract | ¼ | Domain, architecture sentence, conformance-bar result, vacuity discipline | — |
| 1 | Introduction | 1–1.5 | Agent-harness failures cluster at boundaries (provider telemetry shaping next step, compaction applied to send-payload but not history, hooks seeing wrong slice, env silently disabling behavior); why live-provider runs can't be the regression oracle; contributions list | spine doc §"What DST means"; `001/ADR-001` |
| 2 | Background & related work | 1–1.5 | DST lineage (FoundationDB, Antithesis, TigerBeetle VOPR); property-based testing; state of practice in agent-harness testing (evals ≠ regression oracles); **half-page harness context**: Motoko loop, extensions/hooks, ABI; **AILANG primer**: effect rows + capability flags, just enough for caps-as-conformance | `papers/README.md`; README/SYSTEM.md |
| 3 | Architecture | 2 | The five decisions (model contracts, real transition code, normalized trace, structural invariants, id/seed/trace failure contract); ports & fakes (`stub_step`, `scripted_ports`, `ext_fixture`); ledger-as-trace (`LedgerTrace` typed vocab → schema-v1 JSONL); caps-as-conformance **and its stated limit** (rejects a new effect class, not a new operation within a granted class — caps alone do not prove hermeticity) | spine doc §Architecture; `src/core/test/*`; `src/core/session.ail`, `step_machine.ail` |
| 4 | The layered test stack | 1.5–2 | L0–L3 table; shared scenario harness (`dst_harness.ail`, maximal-effect-row `Scenario` type, narrowest-caps-that-pass gates); scenario-id namespace + counts; anti-silent-drop count oracles; the seeded axis (5 families, `DST_SEEDS`/`DST_BASE_SEED`, invariants-only + one-sided decision rules, import-don't-hardcode rule); **RNG canary** as reproduction-key insurance | spine doc §Layers/§Seeded axis/§Namespace |
| 5 | The deterministic test world | 1.5 | What 007's bar demands (seed generates event *ordering*, logical faults, virtual clock, complete returned `LedgerTrace`); how 009 met it: effect-boundary widening, execution program, world-state threading, discovery + strict replay, seeded generator, fault catalogue (9 required classes, 9 named production recovery branches found by search), single world clock | `007/ADR-001`; `009/ADR-001`; 009 HANDOFFs (A12/A13/D1/D3/D4) |
| 6 | Earning the name: conformance & vacuity accounting | 1.5 | The naming gate (WI-D5, 11/11 rows, 2026-08-06); profiles as coverage-accounting units (`driver_only/11`, `driver_plus_no_ops/1`); which acceptance rows lean on emptiness and how vacuity is *computed* (guard tooling); the superseded-claims convention (true-when-written text kept, dated) as a methodological sidebar | spine doc naming block; `NOTE-d5-acceptance-table-rerun-and-name-decision.md`; D10/D14 records |
| 7 | Gates, CI, operations | 1 | `make dst` umbrella tree; CI blocks PRs on the full deterministic set; seed rotation (PR: 5 fixed seeds; nightly: 500 from date-derived base; manual promotion of failing seeds); reproduction contract (`scenario= seed= invariant=` + trace); parallelized sweep (`DST_JOBS`, sweep summary) with wall-clock numbers from the current branch | Makefile; `.github/workflows/verify-extensions.yml`; `scripts/dst/sweep_summary.sh` |
| 8 | Discussion & limitations | 0.5–1 | Single-actor / logical-fault scope (007's tripwires); caps ≠ hermeticity; world-mediation machinery uncovered by any profile; no shrinking or auto-promotion of failing seeds; live calibration outside the oracle; **Phoenix subsection**: DST as the trust mechanism for an AI-authored codebase | spine doc caveats; `007/ADR-001` |
| 9 | Future work & conclusion | 0.5 | Compose-bearing profile (WI-C5) → first substantive hook coverage; seed shrinking + promotion; `smoke_v2_*` subsumption audit; simulation visualization (project 010) | spine doc "Known deferred work" |

## Figures & tables

| # | Artifact | Source / plan |
|---|---|---|
| Fig 1 | Ports-swap architecture (production vs. DST wiring of the same driver) | Redraw from `.agent/projects/007_dst_consolidation/mmd/dst-as-built.svg` |
| Fig 2 | Gate dependency tree + CI topology (PR vs nightly seed rotation) | Makefile `dst` tree + workflow file |
| Tbl 1 | Layer stack L0–L3 (what/lives-in/runner) | Spine doc, condensed |
| Tbl 2 | Scenario-id namespace with counts (fixed + seeded families) | Spine doc, verify counts against gate output at draft time |
| Tbl 3 | Fault catalogue: 9 classes → 9 named recovery branches | WI-D1 record |
| App. A | The eleven-row acceptance table with per-row lean/vacuity annotations | `NOTE-d5-acceptance-table-rerun-and-name-decision.md` |
| App. B | `Scenario` type + failure contract listing | `dst_harness.ail` |

## Numbers to collect at draft time (all already recorded in-tree — no new experiments)

- Scenario counts per namespace (re-derive from gate `PASS count=N` lines, not the doc table).
- Seeded-axis config: families=5, default seeds=5, nightly=500.
- Fault catalogue: 9 classes, 9 recovery branches.
- Hook coverage numbers: 32 hooks / 4 extensions / 16 vacuous (driver_plus_no_ops/1).
- `make dst` wall-clock, serial vs `DST_JOBS=n` (from the mot-91 parallelization branch sweep
  summary) — the one number set that should be re-measured once that branch lands.
- CI job durations (main job, dst_l2 5-min job).

## Out of scope (explicit)

- Motoko harness features not needed to understand the tests (TUI, config profiles, extension
  catalogue, omnigraph, benchmarks).
- Z3 contracts beyond one paragraph in §3 (complementary-not-competing, per ADR-001).
- New empirical work: no bug-catch case-study mining, no fresh seed-search yield studies.
- The Phoenix/no-human-code story as *framing* (it appears only as a §8 subsection).
- Live-provider calibration targets (named once as explicitly outside the oracle).

## Open items (resolve during drafting, none block starting)

1. Title choice (candidates above).
2. Authorship/attribution for an external report from a pseudonymous project.
3. Format: LaTeX (arXiv) vs. markdown-first then convert — suggest markdown draft in this
   directory, convert late.
4. Whether the mot-91 parallel-sweep timings land in time for §7; fall back to serial numbers
   plus a footnote if not.
5. Verify at draft time that spine-doc counts still match HEAD (the doc warns ids/counts move).

## Drafting plan

1. **Skeleton pass** — headers + figure placeholders + per-section claim bullets (½ session).
2. **Sections 3–5** (architecture + stack + test world) — the technical core, sourced from the
   spine doc and 009 ADR.
3. **Section 6** (conformance & vacuity) — needs the most careful writing; every sentence must
   satisfy the claims constraints above.
4. **Sections 1–2, 7–9**, abstract last.
5. **Compliance pass** — check every "DST" occurrence names a profile; check both mandatory
   coverage caveats appear; re-derive all counts from gate output.

## Freeze checklist additions (adopted 2026-08-10 from Deli Chen's paper-writing skill,
`victorchen96.github.io/auto_research/skill/paper-writing.html` — the transferable subset only;
its survey-specific machinery (citation-count gates, LQS scoring, MECE taxonomy design,
experiment loop) deliberately NOT adopted for this systems report)

- **Multi-persona review pass with anti-inflation rules** before freeze: ≥3 independent
  reviewer lenses (DST practitioner / skeptical epistemologist / newcomer), independent
  scoring, median score, weaknesses labeled Major/Minor and routed to sections; first-round
  score capped at 7.0; at least one unresolved weakness must persist in the report's own
  limitations; regression-check previously fixed weaknesses on re-review.
- **Hedge-ladder pass**: audit every "demonstrates/shows/proves/suggests/may" against the
  actual evidence class behind it; claim strength must never exceed evidence strength.
- **Abstract–conclusion alignment check** and terminology-consistency sweep.
- **Caption rule**: every figure/table caption states the key finding, not a description.
- **Citation verification**: every external citation checked against arXiv/DBLP (title,
  authors, year, venue) before freeze.
- **Gap sharpening in §2.1**: differentiation must name what no existing DST writeup covers
  (provider-as-environment transplant; computed vacuity accounting) — "no one has written this
  up yet" alone is insufficient.
