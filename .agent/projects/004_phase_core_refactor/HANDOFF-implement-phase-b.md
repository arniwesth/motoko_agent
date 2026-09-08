# Handoff: implement Phase B

Audience: a fresh implementer session. The plan was authored fresh against post-Phase-A
HEAD `d0d5b7e` (2026-07-03), reviewed iteratively in the same session (three adversarial
passes; the fixes are already in the plan), and its two substrate risks were resolved by
probe before this handoff was written. Keep it short: **the plan is the spec — this file
only tells you how to hold it.**

## Mission

Execute `PLAN-phase-b-phase-results.md` in this directory, WI-0 → WI-8, in order. One
commit per WI (WI-2 is three: 2a/2b/2c; WI-7's 7c+7d must share a commit — registering the
ladder extension while the core shim still runs would elide twice per step). Each WI lands
with the system shippable and its verification block green. Done = the WI-8 gate checklist
passes as a block: strict parity diff vs. the final blessed baseline, the projection-subset
gate script, the streaming sequence assertion, and the fixture smoke's `sys=0`. Do NOT
start Phase C (no `decide`, no module split, no approval inversion) and do NOT touch the
ABI (the structural package ships against 2.2.0) — the plan's out-of-scope list is a fence,
not a suggestion.

## Reading order

1. `PLAN-phase-b-phase-results.md` — normative for everything you do. Its survey is the
   work list; its D-B1–D-B10 decisions are settled; its per-WI expected-diff tables are the
   only license to see a parity diff; its WI-8 checklist is your exit.
2. `ADR-001-phase-oriented-core.md` — Phase B section + Decision details 3/4 as amended
   2026-07-03, and **both** dispositions logs (G1–G8, G-B1–G-B7) so you don't re-report
   settled findings.
3. `scripts/phase_a_event_parity.sh` + the `smoke_parity` Make target — the inherited
   instrument WI-0 extends. Run `make smoke_parity` (self-diff) once before touching
   anything, so you know green.
4. `NOTE-ailang-run-exit-code-false-alarm.md` — mandatory before editing the harness or
   measuring any exit code. The plan-authoring session nearly repeated the exact footgun
   (`$?` after a pipe) during the G-B7 probe; assume you will too.

## Verified-at, and when to re-verify

Every `file:line` in the plan was read at HEAD `d0d5b7e` on AILANG v0.26.0 (`3b52a24`).
Before editing:

- `ailang --version` must be v0.26.0/`3b52a24`; if not, STOP and flag.
- `git log --oneline -10` — commits after `d0d5b7e` under `src/`, `scripts/`, or
  `packages/` make every plan anchor suspect; re-grep before each edit. (Doc commits — the
  plan itself, the ADR amendments, this handoff — are expected and harmless.)
- Re-grep line numbers before every edit regardless; `agent_loop_v2.ail` moves under your
  own WIs — WI-2 alone touches ~44 call sites, so anchors rot *within* the phase.

## The parity protocol is the whole game (D-B7 — hold it exactly)

- Baselines are blessed **including** [NEW] lines; strip mode
  (`PARITY_STRIP_TYPES`) is transient, used only at WI-4 and WI-6 to prove additions are
  allowlisted before re-blessing. Everything else is a **strict** byte diff.
- Only WI-5 and WI-7 may show [prod]-byte diffs, and only the lines their expected-diff
  tables name (WI-5: the `sys=1 → sys=0` note flip; WI-7: the exhaustion-reason wording +
  the new case-5 block). Check the diff line-for-line against the table, record it in the
  commit message, then re-bless. If the diff shows anything else, stop and understand —
  never "fix" the baseline to make a diff go away.
- WI-1's golden byte tests are the projection's equivalence evidence; if a WI-2 migration
  needs a projection change, the golden test must fail *first* (that is the signal you
  transcribed a layout wrong, not that the test is stale).

## Residuals the plan defers to you

- **WI-0 determinism**: the two new smokes (fixture, stream) are yours to make
  deterministic before blessing the baseline — run the harness twice, self-diff, fix or
  simplify before any production edit. Both must seed `[system, user]` histories (WI-4/5
  assertions depend on it).
- **"Enumerate at implementation" rows** (`dp7_verifier_rejected`, `hybrid_bash_extracted`
  field layouts): copy the site's kv list verbatim; the golden test self-verifies the copy.
- **WI-7a re-verification**: the dependency shape is proven (ADR G-B7) but re-run the
  sequence exactly as written — mirror path target, both exports (`compaction` +
  `context_usage` until 7d drops the `:29` import), `make sync_packages`, then
  `ailang lock` in the package dir. If any step behaves differently than the plan records,
  that is a finding, not an obstacle to improvise around.
- **Fixture hooks**: match `ExtensionHooks` field-for-field against the ABI 2.2.0
  `types.ail` in the registry cache, not memory (the G8 lesson — stale literals were the
  fleet-wide failure class).

## Discipline

- D1–D9, G1–G8, G-B1–G-B7, and the plan's D-B1–D-B10 are settled. New contradictions with
  HEAD are findings for a note (`NOTE-phase-b-implementation-findings.md`) or the ADR log —
  never silent divergence, never license to redesign.
- A substrate-defect claim requires a minimal repro before it enters any document; never
  read `$?` through a pipeline (capture rc adjacent to the command).
- Run the WI's verification block at every WI boundary, not just at the end. Expected side
  effects are asserted in the plan (e.g. `emit_event` count reaching 0 after WI-2c,
  `emit_json` callers = 2 after WI-3); a differing number is a finding.
