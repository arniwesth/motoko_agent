# charter-queue-b — AILANG `design_docs/v1-mission.md`, Queue second half (lines 2701-4908)

Source: `/tmp/claude-1001/-workspaces-motoko-agent/5c0ae771-b88d-496a-8866-321245c5b41a/scratchpad/ailang-dev/design_docs/v1-mission.md`
at commit 2a1f3f295 (dev, 2026-10-03). All `:N` references below are line numbers in that file.
Clone is depth-1 (`git rev-parse --is-shallow-repository` = true), so no blame/history was available; all dating is from dates and iteration numbers written in the text.

Conventions in these notes: **OBS** = observed in the text or measured by script. **INF** = my inference. **JUDGEMENT** = opinion.

## 0. What I actually read

- Read in full, every character printed (Python loop, no truncation, each chunk ended with its own "NEXT START" trailer): **501-530** and **2701-4908**.
  Chunks: 2701-2947, 2948-3068, 3069-3184, 3185-3188, 3189-3191, 3192 (one 19,351-char line), 3193-3199, 3200-3207, 3208-3312, 3313-3587, 3588-3739, 3740-3995, 3996-4169, 4170-4442, 4443-4714, 4715-4908.
- Outside my range, spot-read only, truncated, for cross-checks: 52-61 and selected ledger rows 63-127 (first 420 chars each); 133-145 and 160-189 (first 520 chars); 2016-2024, 2084-2090, 2296-2346 (first 330 chars); plus whole-file grep hits for specific ids. I did not read 521-2700.
- Scripts: `scratchpad/qb/rd.py` (reader), `scratchpad/qb/measure.py` (row table + stats; row start lines are hand-curated from the read, lengths/tags are computed), output `scratchpad/qb/rows.json`.

Range size (script): 2,208 lines, 383,835 characters excluding newlines; 32 lines over 2,000 chars, 9 over 5,000; longest line 19,351 chars (:3192).

## 1. What a queue item is

**OBS — there is no fixed schema.** An item ("row" is the charter's own word, e.g. :3184 "THIS ROW WAS MISSING") is a block of prose whose first bold run usually opens with a bracketed status. Fields that recur, none mandatory:

| Field | Typical form | Example |
|---|---|---|
| status bracket | `[TAG date (iter-N) — PR → squash sha; CI gate result; evaluator score …]` | :3210 `[LANDED 2026-08-15 iter-206, PR #726 → \`640bab054\`]` |
| demand / origin tag | `[world-DEMAND]`, `[cli-DEMAND]`, `[email-parse-DEMAND]`, `[NEW-DOC]`, `[SWEEP-BATCH iter-145]`, `[FINDINGS-BATCH iter-151]`, `[ORPHAN-PR iter-150]` | :3062, :3204, :3208, :3185, :3186, :3187, :3189 |
| id | `m-kebab-slug` (about 96 of 119 rows), or `#NNN` issue number only (15), or a prose title (8) | :4844 `m-string-search-offset`; :3205 `` `#691` ``; :3215 "SonarCloud new-code-coverage triage" |
| headline claim | one bold sentence stating the defect | :3025 |
| parenthetical | issue ref; doc-needed marker (`NEW-DOC needed + quorum` / `no design doc` / `direct-fix lane`); priority `P0`-`P3`; estimate; bar membership | :3202 "(`#539`; **NEW-DOC needed + quorum** … P2 — not a v1.0 bar item; ~1–2d)" |
| narrative | measurements with controls, quorum rounds, refuted premises, decisions `D-nn`, follow-up issues filed, next step | everywhere |
| history | `Was:`, `[was: …]`, `Original row:`, `Superseded row text below`, `Historical park:` | :3185, :2739-2753, :3203 |

Representative items, quoted briefly:

1. Open, full-ish fields — :3025-3026: "- **[NEXT — filed 2026-08-23 (iter-257), first-party measured; ~1–2d, P1]** `m-module-cache-identity-not-compiler-bytes` — **the module cache keys on a git commit and calls it a compiler identity; a commit identifies SOURCE state, not bytes.**" … ends :3048-3050 "Needs a design doc and a quorum; do NOT fold it back into `m-cohort-manifest-build-provenance`".
2. Open, bare — :4844: "**[NEXT] m-string-search-offset — `find` has no offset, so "find the next X after i" copies the tail on every search** (`ailang#688` claim 2, accepted at iter-223 and deliberately NOT bundled …" … :4851 "so it needs a design doc (NEW-DOC, quorum at creation), not a controller-inline fix." No date, estimate, or priority.
3. Landed, short — :3210: "- **[LANDED 2026-08-15 iter-206, PR #726 → `640bab054`] `#717` — module-only govulncheck allowlist entries skipped expiry and malformed-date validation.**"
4. Older name-first form — :3735-3744: "- **m-eval-kimi-k3-agentic** ([planned/v0_31_0](planned/v0_31_0/m-eval-kimi-k3-agentic.md), Mark 2026-07-19: "Kimi K3 did very well …") … ~0.5–1d, metered-cheap, no GPU. **HARD-SEQUENCED AFTER m-eval-reasoning-model-fairness** … Expect quorum-at-pick."
5. Stacked history in one physical line — :3185 (13,013 chars): `[LANDED 2026-08-20 (iter-235) … Superseded row text below.] [M1 IMPLEMENTED + HELD 2026-08-07 (iter-156) … Was:] [NEXT — SPRINT-PLANNED, READY FOR M1 2026-08-06 (iter-155) … Was: PARKED needs-human-review 2026-08-06 (iter-150) … Was:] **[NEXT] [NEW-DOC] m-net-effect-proxy-boundary — \`D5\` OPTION B, queued by Mark's directive 2026-08-05**`.

**Tags.** Heading legend at :521 is `[NEXT] [IN-SPRINT] [PARKED] [LANDED] [RULED OUT]`. OBS (script, first bracket of each of 119 rows): LANDED 45; NEXT 32; no status bracket first 10; NEW 4; `LC-n` 4; LANDED-LANE-A 2; DOC LANDED 2; and one each of READY, M1 LANDED, CLOSED, PARKED, IN-SPRINT, LANDED-M1, RESOLVED, DESIGN DOC LANDED, SUPERSEDED, MECHANISM REFUTED, UNPARKED, S1 LANDED, GATE MET, QUORUM-BLOCKED, M1+M2a LANDED, PROGRAMME, PARTIALLY LANDED, IN-SPRINT-PARTIAL, M1+M2+M3 LANDED, BLOCKED ON. That is 27 distinct leading forms. Only **13 of 119** rows have a first bracket that is exactly one legend tag with nothing else. `[RULED OUT]` appears **0** times in 2701-4908. The status bracket itself (balanced `[…]` from row start, n=93) has median 74 chars, p90 2,541, max 15,913; 21 exceed 1,000 chars.

**Clause tags against the bar.** OBS: in this half the clause is conveyed mainly by position under a `### Clause N` heading (:2768 Clause 5, :3058 Clause 2), plus prose in the row: :2789 "P0 for the clause-5 KPI"; :3062 "P1 for clause-4/5 credibility"; :3754 "P1½ — the clause-5 KPI's data substrate". Rows also disclaim the heading they sit under: :3063 "**not a v1.0 bar item**, filed in this section beside its sibling World filing for discoverability, NOT because it is a soundness row". After :3308 there is no clause heading at all. Script: 18 of 119 rows carry any clause/bar statement. (Outside my range a different, explicit form exists: :2321 `**[GATING clause-4]**`; and the Goal section :169-174 keeps a per-clause table of gating design docs by id.)

**Estimates and priority.** OBS (script): 52 of 119 rows carry an effort estimate; 40 carry a `P0`-`P3`. Among the 62 rows I read as not landed, 26 have an estimate and 16 a priority. Forms: "~1–2d" (:3025), "~0.5d for the safe subset" (:2830), "(3/4, 3d — BLOCKED behind sprint-2 …)" (:2705, sprint k-of-n plus days), "26h ≈ 4.5d, revised up from the doc's 3–4d" (:3184), "~2–3h" (:3346), "~3 lines / <0.5h" (:3199), "was ~0.5d, actually 9h" (:3197), "Estimate unknown until the differential runs" (:4288).

**Links.** OBS (script):
- design docs / sprint plans: 30 rows carry a markdown link into `planned/` or `implemented/`; others cite the path in backticks (:4093). Sprint plans are `<doc>-sprint-plan.md` beside the doc (:4383 "plans travel with their doc"); sprint state is `.ailang/state/sprints/sprint_*.json`, gitignored and needing `git add -f` (:3201 end, :4095).
- **link rot, measured against this commit's tree**: 36 markdown doc links in the range, **11 targets do not exist** (:2754, :3191, :3193, :3359, :3362, :3657, :3658, :3660, :3667, :3753, :3780 — all `planned/…` links on rows whose work moved or landed); 4 of 17 backticked doc paths are also missing.
- GitHub: 88 rows cite at least one `#NNN`; 62 cite a PR; form "PR [#690](url) → squash `7bad0e609`" (:3204). 26 rows cite a `D-nn` ledger decision.

## 2. Measurements (script `qb/measure.py`)

Row = a top-level block whose start line I identified by reading (119 starts), ending at the next row start, heading, or non-row label paragraph. Not counted as rows: 2 `###` headings; the HUMAN-LED lanes block (:3308-3319); release-gate audit list (:3321-3336); v1.1 arc (:3338-3343); the "Mission-infrastructure backlog" label (:3345); :4147-4152; "Not gating"/"Post-v1" (:4893-4897); the two closing sections. Lines 2701-2705 are the tail of a row that starts in the other agent's half.

- **Rows: 119.** Sub-entries inside rows that are not separate rows: 5 inline items in the `Flagship + surface` group bullet (:2706-2766), 2 in the :2701-2705 tail, 15 issues in the 08-17 sweep row (:3903-4067), 8 in the 08-24 sweep (:3875), 4 issues in :3192, 3 in :3186, 6 in :3203, 12 in :3628, three ids on one numbered line (:4128), and `m-evaluator-gemini-review-lane` as "(2)" inside :3442-3530.
- **Length (chars per row): median 2,204; mean 3,203; p90 7,087; max 19,351 (:3192); min 292. Rows over 5,000 chars: 18. Over 10,000: 5.** 41 rows are a single physical line (median 2,849 chars).
- Largest: :3192 batch `#618/#619/#616/#617` 19,351; :3903 sweep 17,743; :3185 13,013; :3193 12,001; :3064 11,946; :3191 9,860; :2918 9,787.
- **Per leading tag**: see section 1 (LANDED 45, NEXT 32, 25 other forms).
- **Status by my reading (INF, hand-labelled)**: landed/closed/resolved 55; open 45; mixed/partial 8; parked on a human decision 5; held/blocked 4; superseded/refuted 2. Landed rows hold 201,756 of 381,144 row characters = **53%**.
- Physical layout: 56 col-0 bullets tag-first; 18 col-0 bullets name-first; 39 bold paragraphs tag-first; 6 numbered-list entries.
- Literal counts in range: `[NEXT` 45, `[LANDED` 59, `[IN-SPRINT` 3, `[PARKED` 3, `[RULED OUT` 0, `needs-human-review` 11, `Was:` 19, `Original row` 7, `~~` 32, "row above/below" 17.

## 3. Does the queue change toward the bottom?

**OBS — three regions with different character** (script, by row start):

| Region | Lines | Rows | Landed / open / other (my reading) | Median chars | Dates in row headers |
|---|---|---|---|---|---|
| A. Clause sections (tail of 4, then 5, then 2) | 2706-3307 | 51 | 37 / 6 / 8 | 2,951 | 2026-07-22 … 2026-08-26 |
| B. "Mission-infrastructure backlog" | 3346-3822 | 23 | 8 / 10 / 5 | 1,302 | 2026-07-11 … 2026-08-13 |
| C. Appended bold-paragraph rows | 3823-4892 | 45 | 10 / 29 / 6 | 1,821 | iterations 216-267; 26 of 45 have no date in the row header |

- **OBS — the half is frozen in time.** The highest iteration number referenced anywhere in 2701-4908 is **267** (:3875, :3891); the latest date is 2026-08-31 (:2853) apart from an allowlist expiry date. Lines 523-1861 of the first half reference iterations 268-354. The file's STATUS header is at iteration 354, 2026-09-14 (:219), and the commit is 2026-10-03. INF: new rows are inserted near the top; nothing in the bottom 2,200 lines has been edited to reflect anything after iteration 267.
- **OBS — it is not ordered by age or priority.** Clause headings run 3 (:2474), 4 (:2659), 5 (:2768), 2 (:3058). Region C (August) sits below region B (July). Within C the 2026-08-24 sweep (:3875) sits above the 2026-08-17 sweep (:3903). LANDED and NEXT rows interleave throughout; sequence by my reading starts `M L O H O O O L O L L L L L L L L L P L L M …`.
- **OBS — region B is where rows go quiet.** Rows with no status and no text later than July: `m-eval-reasoning-model-fairness` (:3678, "QUEUED by Mark 2026-07-19, P1"), `m-comments-for-ai-authors` (:3690, 2026-07-20), `m-eval-kimi-k3-agentic` (:3735, 2026-07-19), `m-mission-loop-heartbeat` (:3745, "[NEW, 2026-07-21 …]"), `m-mem-budget-runtime` (:3782, 2026-07-21, "P1 — host-safety, DOC-READY"), `m-decision-entropy-monitor` (:3796, parked iter 84 2026-07-22), `m-outage-triage-lane` (:3641, 2026-07-29), `m-vuln-allowlist-expiry-warning` (:3346, 2026-07-31), `m-github-issue-triage-batch` (:3628, 2026-08-03). The ids `m-outage-triage-lane`, `m-vuln-allowlist-expiry-warning`, `m-github-issue-triage-batch` and issues `#572`-`#576` appear nowhere else in the 930 KB file (whole-file grep). INF: these look abandoned in this document; they may be tracked in the log or on GitHub, which I did not check.

**Rows contradicted by later text (OBS, with dates):**

| Row | Says | Contradicted by |
|---|---|---|
| :3780 `m-public-feedback-delivery-audit` | open P1, link `planned/v0_30_0/…`, "prioritize" (2026-07-12) | :2019-2021 "**[LANDED 2026-07-13, iteration 24 …]** m-public-feedback-delivery-audit ([implemented/v0_30_0]…" |
| :3660 `m-mission-quorum-agentic-verify` | unstarted, "Precondition: confirm Tier-1 has fired LIVE (no artifacts found yet)" (2026-07-14) | :2088 "[CORE LANDED 2026-07-16 iter 36 (M1-M3) — PR #400"; :2308 "header was stale-PARKED" |
| :3188 `#604`, :3202 `#539`, :3216 `-coverpkg`, :3531 `m-driver-pin-rollout` | leading tags "PARKED needs-human-review … ONE DECISION OWED (`D-2`)", "PARKED … on `D-14`", "SPRINT PARKED on `D-COV-1`", "PARKED … on `D-13`" (2026-08-07 … 08-15) | block :3848-3869 "UNPARKED BY MARK'S ATTENDED RULINGS, 2026-08-19"; ledger :64, :75, :76, :80 all `RESOLVED` 2026-08-19. The rows themselves were not edited. `m-driver-pin-rollout` appears only inside its own row; `m-named-test-body-check-semantics` only in its row and the :3860 table (whole-file grep). |
| :3614 `#616` | "[QUORUM-BLOCKED 2026-08-11 (iter-179) … Needs ONE revision + ONE re-quorum; NO human input required" | :3192 "UPDATE 2026-08-12 (iter-180): `#616` REVISED AND PARKED `needs-human-review` AT ROUND 2 — `D-10`"; :3863 "`D-10` \| **B — hold and route next.** No third revision"; :4005 "`#616`, which is HELD by `D-10`" |
| :4644 `m-eval-tail-calls` | "[BLOCKED ON `D-19`]" | :4070 "Mark ruled **B** on `#745` at `2026-08-19T10:58:40Z`"; ledger :83 `D-19 \| RESOLVED` |
| :3063 Lane A | "**LANE B STILL OPEN — see the [NEXT] row below**" (2026-07-29) | :3152 "**LANE B IS COMPLETE.**" (2026-08-06); the row below no longer carries [NEXT] |
| :3183 Lane A | "**LANE B1 STILL OPEN — see the [NEXT] row below**" (2026-07-30) | the row below is now `m-ci-flake-systemic-fix` (:3184); Lane B1 is :3191, tagged LANDED 2026-08-11 |
| :3051 `m-cost-per-success-kpi` | tag "M4 parked-for-Mark"; "Doc stays in `planned/` until M4b lands" | same line: "**M4b DECIDED by Mark 2026-07-27**"; link is already `implemented/v1_0_0/…`; :2770 "M4b FIRED" 2026-08-22 |
| :2853 `m-contract-verification-coverage` | header: "D-30 was ANSWERED (b) same-binary 2026-08-26 … tag un-parked 2026-08-31" | body :2888 "`D-30` remains its sole blocker"; :2912 "Parked rather than force-passed" |
| :3064 Lane B; :3184 ci-flake; :3192 batch | leading tags "DOC LANDED + QUORUM-CLEARED 2026-08-04", "M1 LANDED 2026-08-05", "IN-SPRINT 2026-08-10" | same rows: :3152 complete; :3184 "⚠ THE SPRINT IS COMPLETE"; :3192 "M4 LANDED — the sprint's REPO work is COMPLETE" (2026-08-11) |
| :3903 sweep 08-17 | header "12 of 15 dispositioned; 3 remain" | :4053 "The in-repo half of this sweep is CLOSED at iteration 232: both remaining orphans"; :4057 "remaining 3 (`#672`, `#694`, `#656`)" though :4038 marks `#694` LANDED; :4059 "Three of fifteen are now dispositioned"; :4066 "7 real of 8" vs :4054 "9 real of 10" |
| :2727-2766 `m-ai-reasoning-effort` | LANDED 2026-07-22 (iter 83) at the top | :2760 "REALITY-CHECK (iter 66, log entry 71): STILL PARKED" kept beneath, link :2754 still `planned/v0_29_0/…` (target missing) |

The charter records the same staleness about itself: :4058 "(The header counter read "7 of 15 / 8 remain" through iteration 230 while the enumeration below listed 11 dispositioned and 4 remaining; corrected at iteration 231 by counting the rows.)"

## 4. How LANDED, PARKED, RULED OUT are recorded; pruning; the two closing sections

- **LANDED (OBS):** recorded in place by prepending a new bracket to the row and keeping the old text behind `Was:` / `Original row:` (19 rows carry such markers, 34 markers). Rows are not moved. Partial landings get ad-hoc tags (`LANDED-LANE-A`, `LANDED-M1`, `S1 LANDED`, `M1+M2+M3 LANDED … M4 [NEXT]`, `PARTIALLY LANDED`, `IN-SPRINT-PARTIAL`). The bracket holds the whole landing record: PR, squash SHA, check counts, evaluator score, mutation drills, findings.
- **Not pruned (OBS):** 55 of 119 rows read as landed/closed and hold 53% of row characters. Landed items from 2026-07-20 … 07-28 are still present (:3659, :3655-3657, :3061). Policy rule 5 (:519) says "Anything re-scored `post-v1` in iteration 0 leaves the queue", yet :2705 keeps `m-effect-scope-params` "(**RE-SCORED to v1.1, D-27 … leaves the v1.0 bar**)" in the queue text.
- **PARKED (OBS):** "PARKED `needs-human-review`" plus a `D-nn` id, options (A)/(B)/(C) and a "one word" ask (:3202, :3566). A second kind, `PARKED-ON-LANE`, is for waits on an external lane (:2971, :3024, :4079). Un-parking is recorded either by prefixing the row ("UNPARKED 2026-08-22 — D-25" :3276; "tag un-parked 2026-08-31" :2853) or in a separate block (:3848-3873) that leaves the rows' own tags unchanged.
- **RULED OUT (OBS):** the legend tag is unused in this half. Equivalents: `[SUPERSEDED BY THE ROW ABOVE — kept for the refuted premises]` (:3217); `[MECHANISM REFUTED iter-209; issue remains workload evidence]` (:3218); `[CLOSED …]` (:3186); `[RESOLVED …]` (:3203); `[DISPOSITIONED …]` (:3997, :4007); strikethrough (`~~` ×32); and in-row sentences "**Ruled out at triage**" (:3197), "**RULED OUT by measurement**" (:3215), "Ruled out:" (:4006, :4018).
- **"Ruled out / resolved" (:4899-4904)** holds exactly two bullets, both mission-setup policy choices: "**Sonnet as default executor** — ruled out 2026-07-10 (Mark: corrections needed; false economy). Re-entry only via the evidence rule." and "**Scheduling via cron / scheduled-tasks MCP** — ruled out; this rig's substrate is launchd".
- **"Done / superseded" (:4906-4908)** holds one line: "*(nothing yet — mission initialized 2026-07-10)*".
- INF: both closing sections are initialization placeholders that were never used again; every outcome since 2026-07-10 was recorded inside the Queue.

## 5. Sub-structure, numbering, cross-references, dependencies

- **Sections (OBS):** `### Clause 5` (:2768), `### Clause 2` (:3058). Then bold labels acting as headings: "**HUMAN-LED lanes (Mark, 2026-07-14 — the loop keeps HANDS OFF …)**" (:3308); "**v1.0 RELEASE-GATE AUDIT …**" with a numbered list 1-5 of human decisions (:3321-3336); "**The v1.1 arc**" (:3338); "**Mission-infrastructure backlog** (improves HOW the loop runs; not a v1.0 gate)" (:3345); "**Not gating**" (:4893); "**Post-v1**: everything in `planned/v1_1_0/`." (:4897). Region C (:3823-4892) sits under the mission-infrastructure label by position but is mostly language/stdlib/codegen follow-ups.
- **Sub-queues (OBS):**
  - group bullet with inline items separated by " · " (:2706-2766);
  - batch rows: weekly external-issue sweeps (:3186, :3203, :3875, :3903), findings batch (:3187), issue batch (:3192), triage batch (:3628). The 08-17 sweep uses col-0 sub-bullets by lane (:3910, :3936, :3996) with per-issue strikethrough + status;
  - a **programme** with a numbered list of eight pieces coded LC-0 … LC-5 (:4069-4146): :4077 "take them in order, LC-1 first"; :4083 "nothing else may be routed before it lands"; one numbered paragraph carries pieces 3, 4 and 5 (:4128);
  - a ruling table mapping `D-id` → disposition → "Row it unblocks" (:3857-3869), where the row is named loosely ("the short-success guard row", "filler disposition row", "coverage doc").
- **Numbering schemes (OBS):** iteration numbers (`iter-NNN`); ledger decisions `D-nn`, `D-COV-1`; milestones `M1…`, sprints `S1/S2`, lanes `A/B/B1/B2`, work items `W8/W9`, `LC-n`; verification rows `V-nn`; `AC-n`; quorum rounds `R1/R2`; skill rules `3a…3m`; `Gate 0…5`; "Standing rule N"; "log entry N" (:2725, :2747, :2759, :3258). Collisions: `D-1` is a ledger decision at :3185 and a plan-discrepancy label at :3201 ("`D-1` the doc teaches into **frozen** `prompts/v0.16.2.md`"); `D5` at :3184 is a sprint decision; :4075 "⚠ **Letter collision**".
- **Cross-references (OBS):** by slug, by `#issue`, and by position — 17 uses of "row above/below" (e.g. :2786 "see the row below"; :4328 "the set the row above enumerates"; :4342 "the two rows above"). Two positional references are now wrong (:3063, :3183, see section 3).
- **Dependencies (OBS):** prose only; 55 phrase hits. Examples: :2828 "Depends on nothing; blocks the useful half of `m-benchmark-ensures-coverage`."; :2830 tag "BLOCKED on `m-verify-bounded-unrolling-false-counterexample` for 4 of its 5 candidates"; :3193 "P0 prerequisite for LANE B1 above"; :3743 "**HARD-SEQUENCED AFTER m-eval-reasoning-model-fairness**"; :3779 "**Sequence BEFORE m-cost-per-success-kpi.**"; :4147 "**Two already-queued rows are load-bearing for this programme and must NOT be duplicated into it**"; :4890 "Sequence AFTER the sweep-orphan lane".
- **Machine-readable? (OBS):** no dependency or status in the queue is in a structured field. The nearest thing is a dependency written as a command to re-run: :4792-4794 "**Predicate to re-read at Gate 1**: has `#662` gained a comment carrying per-module `typeCheckSteps`? — `gh issue view 662 --json comments`, run as a command with its control, never inferred from the row's own text." Structured artefacts exist beside the queue and are cited from rows: sprint JSON validated by `validate_sprint_json.sh` (:3084, :3464); quorum artifacts JSON (:3192, :4695); a doc-header field `**Planner-Lane**:` parsed by `derive-planner-lane.sh` (:3203, :3455); and the decision ledger, delimited by `<!-- decision-ledger:start -->` and checked by `scripts/mission_decisions.sh --check` (:55-60, outside my range).

## 6. Rediscovery, re-planning, re-litigation — and text written against it

**OBS — work that was invisible because no row existed:**
- :3184 "**⚠ THIS ROW WAS MISSING UNTIL ITER-142.** Iteration 141 landed the design doc … and recorded it **only in its STATUS stamp**; a grep of the queue for the item returned **zero** rows … *a doc that lands without a queue row is invisible to every later Gate-2 pick*".
- :3262-3266 "**⚠ THIS ROW DID NOT EXIST UNTIL IT LANDED** — the ruling created an unblocked, ready-to-sprint doc and nothing wrote it into the queue, so a P0 soundness bug was invisible here for 8 days while iterations declared the still-PARKED parent as Next … That gap is `D-12`."
- :3205 "⚠ **PROCESS FINDING — this item never had a queue row.** It was filed inside iteration 192's `m-batch-exit-panic` row as prose, so it was invisible to every `[NEXT]` scan … **a follow-up filed in another row's prose is not a backlog item.**"
- :3212 "it never had a queue row, which is why the charter could not see that iteration 193 had finished it."
- :3213 "**A task with no acceptance criterion is invisible to the gate**".
- :3882 "`#847` … already triaged on-issue by iter 266 … needs a charter row so it stops re-orphaning"; :3636 "**#495** (contract/test trio — THIRD surfacing, repeatedly slipping triage)".
- INF, same class still live: `m-evaluator-gemini-review-lane` exists only as "(2)" inside a row whose leading tag is LANDED (:3524); no other mention in the file.

**OBS — iterations that died and whose work had to be found again:** :3184 "M5 was written by an UNRECORDED iteration 148 … leaving zero charter/log/STATUS trace"; :3183 a doc "on an UNMERGED branch (invisible to a `design_docs/` grep and to Gate 2's origin/merged-PR checks"; :3193 iteration 160's work "left **uncommitted** when that iteration died", and iteration 163 "died before Gate 3b, writing no charter row and no log entry; iteration 164 verified rather than redid it"; :3189 PR `#545` "with **zero** mentions in the charter … invisible to every existing surface"; :3191 "M1 had been recorded as landed while PR #637 sat OPEN".

**OBS — already-done work rediscovered:** :3192 "THE DISCOVERY: issue resolution (1) — a fused `takeFlatMap` — ALREADY SHIPPED in v0.10.0 … and has been unreachable since"; :3203 "`#609` CLOSED — fixed-since-filing", "`#611` CLOSED: the driver half was ALREADY LANDED"; :3765 "the doc's Defect-A headline … is STALE".

**OBS — false premises that persisted in rows:** :3192 "RETRACTED at iteration 181 … The false row stood for 11 iterations"; :3185 "THE "ACCEPTANCE SIGNAL ALREADY BUILT AND WAITING" WAS FALSE, AND THIS ROW ASSERTED IT FOR THREE ITERATIONS"; :3190 "the ⚠ above is REFUTED, kept here as the evidence … three iterations deferred this item on it"; :3209 "the row's own premise was FALSE and that was the find"; :4200 "THE ROW'S SCOPE BELOW IS WRONG AND WAS FALSIFIED AT GATE 2"; :4608.

**OBS — re-litigation:** `m-cohort-manifest-build-provenance` "FIVE quorum rounds" (:2918) ending in "**RESUME — SPLIT, do not revise again**" (:3016); `#616` "THE FIX SITE MOVED A FOURTH TIME" (:3192); :4706-4710 "Followed literally here, that spends real money re-litigating a doc whose every objection is already answered — and worse, a fresh quorum on a revised doc can raise new objections and re-park an item the human has just unblocked."

**OBS — one item recorded in two places:** `m-public-feedback-delivery-audit` (:2019 and :3780), `m-mission-quorum-agentic-verify` (:2088 and :3660), `m-check-strict-fallbacks` (:2321 and :3244), `-coverpkg` (:3216 and :3217, the second kept on purpose).

**INF — one need planned twice under different ids:** `m-mission-loop-heartbeat` (:3745, "[NEW, 2026-07-21 — born from the 18h reboot outage]", a second launchd agent that watches the loop) was never updated, while :3547 shows a `dev.ailang.mission-recovery.plist` already firing every 240 s, and the first half carries a later, separately-designed `m-mission-slot-heartbeat` sprint (:735, iter-315; ledger :119 "write a per-gate heartbeat artifact"). Nothing in either place points at the other.

**OBS — text written to prevent it:**
- "ghost discipline": live-reproduce at HEAD before a report earns a row (:3060, :3062, :3063, :3183); :3186 "**verify against HEAD before filing** — motoko_agent reports pin a stale `ailang_version` and have twice been already-fixed or superseded"; :4064 "guessing is not ghost-disciplining".
- negative results kept in place: :3208 "**One half of the report is REFUTED and must not be re-chased**"; :3217 "kept for the refuted premises"; :3657 "this row's own prior text was WRONG … Do not design a fix for it."; :4266 "records the crash and the deferral reason verbatim so the next reader does not re-derive either"; :4436 "**Do NOT re-inherit VL-9's "7 silent sites": it is 5.**"; :4441 "**This row's own stated blocker is REFUTED — do not re-inherit it.**"
- scope fences: :3048 "do NOT fold it back into"; :4179 "Do NOT bundle"; :4594.
- process rules: `D-12` (:3852) "a human ruling that unblocks a design doc MUST create or un-park its queue row in the iteration that consumes the directive"; the weekly sweep "greps every open issue's `#N` against this charter" (:3203); the died-mid-flight check for open PRs authored by the loop (:3189); :3843 "a follow-up which never gets written is how a closed PR's work is actually lost".

## 7. Items about the planning and documentation system itself (ids, one line each)

| Line | Id | One line |
|---|---|---|
| :3186, :3203, :3875, :3903 | SWEEP-BATCH iter-145; SWEEP iter-158; `m-sweep-orphans-2026-08-24`; `m-sweep-orphans-2026-08-17` | Weekly sweep finds open issues with zero charter mentions and batches them into one row. |
| :3189 | ORPHAN-PR `#545` | Open PR by the loop with zero charter/log mentions, found by the new died-mid-flight check. |
| :3212 | M-MISSION-LOOP-UNIFIED-TELEMETRY M2+M3 | Mission stages report status/tokens into chains; sprint had no queue row. |
| :3213 | `#698` fast-follow | Restores an orphaned sprint JSON; names `.gitignore` silently dropping new sprint JSONs. |
| :3214 | `#698` part 1 | Opt-in remote read of chain telemetry. |
| :3259 | `m-bytecode-pattern-arity-fix` | Carries the "row did not exist until it landed" finding that became `D-12`. |
| :3442 | `m-planner-codex-lane` | Moves the planner role to codex; doc field `**Planner-Lane**`; notes a third drifted skill copy. |
| :3524 | `m-evaluator-gemini-review-lane` | Evaluator-as-reviewer over a pre-merge branch; exists only inside the row above. |
| :3531 | `m-driver-pin-rollout` (`#558`) | Pin drivers to committed origin/dev because driver, skill and charter "go stale *together*" (:3578). |
| :3628 | `m-github-issue-triage-batch` | 12 open issues with zero charter mentions; triage-lite each. |
| :3641 | `m-outage-triage-lane` | Fallback iteration on a second provider when the controller provider is down. |
| :3655 | `codex-spawn-recipe-false-greens` | The one skill edit of that iteration: two false-greens in the shared spawn recipe. |
| :3656 | `m-docs-gate-not-required` | Docs build made a required check. |
| :3658 | `m-mission-adaptive-multiprovider-routing` | Model fleet and design-doc quorum (`design-review`/`design-quorum`). |
| :3660 | `m-mission-quorum-agentic-verify` | Quorum reviewers become tool-using so they can verify premises. |
| :3662 | `m-mission-portability` | Loop extracted to a template: charter template, `## Repo Profile`, "ONE skill parameterized, never forked". |
| :3745 | `m-mission-loop-heartbeat` | Second launchd agent that alarms and restarts a silent loop. |
| :3753 | `m-mission-cost-chains` | One cost chain per iteration; `chains stats --by-mission`. |
| :3796 | `m-decision-entropy-monitor` | Grade agent steps by decision weight; parked since 2026-07-22. |
| :3823 | `m-changelog-gate-deltas` | Adds arms to the "CHANGELOG.md is index-only" gate; a row so a closed PR's follow-up is not lost. |
| :3848 | the decision-gated rows block | Un-parks rows after ledger-only rulings; states `D-12`. |
| :3910-3929 | `#708` (inside sweep) | `design-quorum` recorded no per-reviewer token usage. |
| :4154 | `m-commit-autoclose-guard` | The loop's own record commits auto-closed two unfinished issues via "fixes #N" phrasing. |
| :4673 | `m-mission-log-entry-numbering` | Mission log has two entries numbered 232 and out-of-order numbers; "Gate 4 appends by "highest existing number", which a duplicate silently corrupts". |
| :4693 | `m-quorum-artifact-path-is-cwd-relative` | Quorum artifacts land in a CWD-relative gitignored dir, so a four-times-reviewed doc reads as unreviewed. |

OBS: no row in 2701-4908 concerns the charter's own size, pruning, rotation, or context cost (grep for prun/archiv/rotat/context window/token budget returned no relevant hit).

## 8. JUDGEMENT — can a program extract the ordered list of open work?

Not reliably from this text. What it could do, and what breaks:

1. **Row boundaries.** Four physical forms; col-0 bullets are both rows and sub-bullets of a bold-paragraph row (:3910); numbered lists are both programme pieces (:4085) and human decisions (:3323); one numbered line holds three items (:4128); some row bodies are col-0 paragraphs, some indented, some blockquotes.
2. **Status.** Only 13 of 119 first brackets are a bare legend tag; 27 leading forms; brackets up to 15,913 chars with nested brackets. A filter on leading NEXT/NEW/READY/IN-SPRINT finds **39 of the 62** rows I read as not landed and misses 23 (name-first July rows, PARKED/UNPARKED rows, programme pieces, partial landings).
3. **Tag ≠ state.** Section 3 lists 12 contradictions covering 17 rows; the authoritative state for decisions is the ledger, not the row.
4. **Open work inside closed rows.** :3358 "**S2 REMAINS (~1.5–2d)**" under an "S1 LANDED" tag; :3524; :3062 "⚠ **Follow-up owed**"; :3186 `#589` "deliberately left OPEN" under `[CLOSED]`.
5. **Order.** File position is not pick order: :3854 "listed in ruling order, not priority order, and a later iteration should order them normally"; :3192 "its ordering vs Lane B1 M4–M6 is the controller's normal call at next pick"; :4794-4795 "When it flips, this row is the pick regardless of position." Policy rules 0-5 (:503-519) decide order at pick time.
6. **Identity.** 23 rows have no slug; one landed row has no id at all (:4606-4624, the id fell off between "] " and "— `ailang test` cannot resolve"); `D-n` label collisions.
7. **References.** 11 of 36 doc links are dead; positional "row above/below" references break when rows move.

A program could reliably get: issue/PR numbers, SHAs, dates, iteration numbers, and slugs. The charter's own tooling points the same way: the things it validates by script are the ledger, sprint JSON and quorum artifacts, not the queue; and its countable progress unit was moved off "open queue rows" (:136-139, outside my range: "that unit was anti-correlated with good work").
