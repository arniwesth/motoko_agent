# AILANG V1 charter, front matter (lines 1-520) — survey notes

Source: `design_docs/v1-mission.md` at `2a1f3f295` (2026-10-03), sparse clone
`.../scratchpad/ailang-dev`. Citations `C:N` mean `design_docs/v1-mission.md:N`.
Every ledger row is one physical line, so `C:N` for a row is the whole row.

Tags: **[O]** = observed in the text (or by running a read-only command);
**[I]** = my inference. Quotes are verbatim.

Scale [O]: the file is 930,233 bytes / 4,908 lines. Lines 1-520 are 179,314
chars; the decision ledger (C:60-131) is 126,357 of those (70%). Companion files
on disk: `v1-mission-log.md` 230 KB, `v1-mission-log-archive.md` 2.77 MB,
`v1-mission-status-archive.md` 179 KB, `v1-mission-status-archive-old.md` 1.54 MB,
`v1-mission-index.md` 54 KB, `v1-mission-status-index.md` 51 KB,
`v1-mission-dashboard.md` 2.8 KB.

Liveness [O]: newest STATUS stamp and newest log entry are both iteration 354,
2026-09-14 (C:219; `design_docs/v1-mission-log.md:2462`). HEAD is 2026-10-03 and
its subject is a *fleet* mission record. Only C:415-418 mention a later date
(2026-09-16). [I] The V1 loop appears not to have recorded an iteration for ~19
days before this snapshot; I did not read anything that explains why. The clone
is shallow (1 commit), so file history could not be consulted.

---

## 0. Header and Repo Profile (C:1-48)

- [O] Type: "Long-running mission (peer of motoko-mission.md); advanced by a
  scheduled outer loop on the always-on rig" (C:3-5). North star: "a release
  whose bar is *written down, met, and verified*" (C:6-8).
- [O] Traces to `PROGRAM.md`; "every friction found here routes to a lane (skill
  fix / process fix / backlog item)" (C:9-10).
- [O] One skill run = ONE iteration; launchd job `dev.ailang.mission-control`,
  "CONTINUOUS since 2026-07-10 per Mark: StartInterval 2h + overlap guard";
  was 22:00 nightly "for the first supervised runs" (C:11-14).
- [O] Billing guard: "API keys are stripped from the environment
  (subscription-or-nothing by construction) and a cheap auth probe runs first"
  (C:14-19).
- [O] Rule born of a failed trial: Claude Code scheduled tasks "TESTED AND RULED
  OUT for this job (2026-07-10 canary)" — tasks landed on Mark's machine not the
  rig, "a probe task never dispatched even there (a June one-time task was also
  found a month overdue)" → "launchd is primary, not fallback" (C:19-23).
- [O] Log: `v1-mission-log.md`, "append-only, one entry per iteration" (C:24).
- [O] Human-facing reporting: GitHub issue #329 — "every iteration posts its
  morning report there as a comment (Mark follows by email via issue
  subscription, no Claude login needed); driver crashes post there too" (C:25-28).
- [O] Repo Profile: "The single source of truth for the values that differ per
  mission. The **one** `mission-control` skill reads this block (and the driver
  env it exports) instead of hardcoding — so the same skill, unforked, runs any
  mission" (C:32-35). Values: repo slug, mission doc path, mission name / state
  namespace, bookkeeping issue ("origin `#329`, rotates weekly; live number in
  `~/.ailang/state/mission-gh-issue` (this week `#422`), watermark in
  `~/.ailang/state/mission-329-last-seen`", C:41-42), CI workflows polled, verify
  profile `go-compiler` vs `ailang-code` (C:43-48).
- [O] Staleness: "this week `#422`" (C:42) while the live stamps cite #1072 and
  #1163 "new this week" (C:219). The profile prose is not kept current.

---

## 1. Human Decision Ledger (C:52-131)

### 1.1 What it is and what a row contains

- [O] Preamble (C:54-58): "This marked table—not STATUS prose and not the
  rolling GitHub thread—is the source of truth for which decisions are open.
  Validate with `scripts/mission_decisions.sh --check`; list the asks with
  `scripts/mission_decisions.sh --open`. Rows are append-only, IDs are never
  reused, and a human answer changes the row to `RESOLVED` in the same iteration
  that consumes the directive. Historical STATUS sentences such as "D-1–D-14
  stay parked" are snapshots and MUST NOT override this ledger."
- [O] Delimited by `<!-- decision-ledger:start -->` (C:60) and
  `<!-- decision-ledger:end -->` (C:131). Four columns:
  `| ID | Status | Decision / recorded answer | Evidence |` (C:61).
- [O] Status values in use: only `RESOLVED` at HEAD (63/63). `OPEN` is the other
  legal value (script, see §6).
- [O] Row anatomy, mature form (e.g. D-51 C:118, D-54 C:121, D-55 C:122):
  1. the question in bold, addressed to the human in second person;
  2. measured context (counts, commit SHAs, controls);
  3. lettered options (a)/(b)/(c)/(d);
  4. "**Loop's recommendation:**";
  5. "**Default if unanswered:**" — what the loop does if nobody answers;
  6. on resolution, "**ANSWERED — …**" appended *inside the same cell*, with who,
     channel, timestamp and often the verbatim words;
  7. Evidence cell: who filed it (iteration N, date), first-party measurements
     with positive/negative controls, then a provenance stamp.
- [O] "Default if unanswered" appears only from D-51 on (D-51..D-57, D-59, D-60;
  D-58 has "Default: HOLD immediately", C:125). Defaults are of three kinds:
  "nothing stalls" (D-51 C:118, D-53 C:120, D-54 C:121), "HOLD indefinitely"
  (D-57..D-60, C:124-127), and one proceed-anyway default: D-55 "Default if
  unanswered: (a), applied at the next iteration and recorded as a controller
  routing call rather than as a ruling" (C:122).
- [O] Early rows are one-liners: "D-3 | RESOLVED | Bound SessionStart brain
  lookup with timeout behavior. | Landed as commit `1239d9ec6`" (C:65).
- [O] Row sizes: median 1,571 chars; 33 of 63 rows exceed 1,500 and 10 are
  under 400. Largest: D-37 5,820 chars (C:104), D-54 5,772 (C:121), D-41 5,422
  (C:108).
- [O] Markdown breakage: the D-19 row is split across physical lines C:83-88 (a
  correction was inserted with hard line breaks). The validator still passes
  because it only looks at lines starting `| D-` (§6).

### 1.2 How rows are opened, and by whom

- [O] By the loop, when it parks something that needs judgment: "Filed
  2026-08-23 by iteration 256 under the decision-recording contract" (C:98);
  "Raised by iteration 252 from the landed plan" (C:91); "Filed iteration 349,
  first-party" (C:128).
- [O] The trigger most often cited is "Standing rule 2" (lives in the skill, not
  in these lines): "Held because Standing rule 2 forbids narrowing a
  quorum-cleared security boundary unattended" (C:63); "Two rounds are spent, so
  Standing rule 2 binds" (C:72); "Controller did **not** self-rule: the
  narrow-refinement carve-out requires a fix that needs no controller judgment"
  (C:97); "(a) and (b) are language-semantics rulings, and standing rule 2
  forbids forcing one" (C:104). Six rows cite it (D-1, D-10, D-30, D-37, D-38,
  D-39).
- [O] By an attended session, including rows that were never questions first:
  D-40 "Surfaced 2026-08-26 in an attended steering session while triaging the
  open decision ledger; it was not itself a ledger row, which is why 4
  iterations recorded it as a deviation and none escalated it" (C:107); D-48,
  D-62, D-63 are recorded as rulings directly (C:115, C:129, C:130).
- [O] The rule that an ask MUST be a row exists because asks written elsewhere
  never reached the human. Five recorded instances:
  - D-31: iterations 251 and 255 hit it, "and **neither filed a decision ID**,
    so the ask has never reached Mark. Iteration 256 is instance **4** and files
    it" (C:98). The stated principle: "a park-for-human with no ledger row can
    never be generated into a `DECISIONS FOR MARK` section, so it gets
    re-discovered every iteration and answered in none" (C:98).
  - D-37: parked as "Q1" on 2026-07-28, "**and it never became a ledger row**,
    so it has never actually reached you"; filed 2026-08-25 (C:104).
  - D-40: four iterations (278-281) recorded a deviation, none escalated (C:107).
  - D-43: a deferral that lived only in a commit message; "iteration 294 files
    it here rather than let it live only in a commit message" (C:110).
  - D-51: "that ask was written as charter prose and never as a ledger row, so
    `mission_decisions.sh --open` returned zero and no report ever surfaced it"
    (C:118). D-53 repeats the lesson (C:120).
- [O] The opposite failure is also recorded: D-45 "WITHDRAWN BY MEASUREMENT —
  this was never a human decision … a decision manufactured out of an unexamined
  premise, which Standing rule 8 exists to prevent — a park whose resume
  condition is 'a human answers' when nothing was in doubt" (C:112). Caught by
  the `sonnet` evaluator ("avoidance dressed as a design decision").

### 1.3 How rows are resolved, and by whom

- [O] By Mark (GitHub `MarkEdmondson1234`). Rule: the row flips to RESOLVED "in
  the same iteration that consumes the directive" (C:56-57); exercised e.g.
  "Applied at iteration 261 in the SAME iteration it was read, before the
  watermark moved, per the decision-recording contract" (C:102).
- [O] No inference from adjacent work: "The ruling is recorded verbatim; the
  controller did NOT infer a resolution from adjacent work" (C:96); "the
  decision-recording contract forbids inferring a resolution from adjacent work
  — so it is recorded as a pointer, not as an answer" (C:102); "the controller
  did NOT infer scope beyond the letter "C"" (C:108).
- [O] Follow-through rule (D-12): "a human ruling that unblocks a design doc
  MUST create or un-park its queue row in the same iteration that consumes the
  directive" (C:74).
- [O] The loop may not resolve its own asks: "The control is the charter rule
  that the UNATTENDED loop may not resolve a row on its own behalf" (C:122).
- [O] Exceptions to "resolved by the human":
  - D-45 resolved by measurement, no human (C:112).
  - D-55..D-60 (six rows, 2026-09-07): "Mark explicitly delegated these rulings
    in the attended 2026-09-07 session: "please make the rulings so we are all
    unblocked". Codex selected and recorded this scoped ruling under that
    delegation. Decisions authorize the stated next gates, not fabricated
    execution or evaluation results." (C:122-127). The answer cell still reads
    "(Mark Edmondson, attended 2026-09-07, recorded directly in this ledger.)".
  - D-54: answered "(b)", then "Twenty-one minutes after answering, Mark cleared
    the divergence himself, attended" by the other option (C:121).

### 1.4 Channels a human answers through

1. [O] **Comment on the weekly-rotating bookkeeping GitHub issue**, read by
   `scripts/mission_directives.sh --issue N --since <watermark>` with an author
   allowlist. Answers are terse: "body exactly `D-19 : B`" (C:83), "body exactly
   `C1 `" (C:89), "*"D-23: yes"*" (C:90), "directive `D-35 A`" (C:102),
   "*"D41 - C"*" (C:108), "*"D-54 b"*" (C:121). Issues seen: #745, #852, #972,
   then #1072, #1163 (C:219). "reported **1** directive of 73 comments — the
   allowlist instrument fires" (C:102).
2. [O] **Attended steering session** — the human at a terminal with an agent;
   recorded as "(Mark, attended 2026-08-19)" etc.
3. [O] **"Charter stamp"** — the attended session edits the charter directly
   because it cannot use channel 1: "recorded as a charter stamp because the
   session authenticated as the bot account, which `mission_directives.sh`'s
   self-direction guard rightly refuses as a directive principal" (C:100, "the
   D-33 precedent", reused in D-42..D-50, C:109-117).
4. [O] **`scripts/mission_answer.sh`** ("ATTENDED LEDGER EDITS contract") —
   "recorded in-session under the ATTENDED LEDGER EDITS contract, not via the
   bookkeeping issue" (C:118-120, C:122-127); nine rows (D-51..D-53, D-55..D-60).
5. [O] **Delegation to the attended agent** (see 1.3), six rows.
6. [O] Outbound side: the morning report on the bookkeeping issue carries a
   `DECISIONS FOR MARK` section generated from OPEN rows (C:98, C:101);
   escalation also goes via `ailang messages send controlplane` (C:445-446).

My tally of where each answer originated [I, derived from row text]:

| origin | rows | n |
|---|---|---|
| attended session (incl. charter stamps, mission_answer) | D-1, D-2, D-7..D-14, D-16, D-COV-1, D-ROUTE-1, D-18, D-24..D-28, D-30..D-34, D-36, D-37, D-39, D-40, D-42..D-44, D-46..D-48, D-51..D-53, D-61..D-63 | 40 |
| GitHub issue comment | D-19, D-22, D-23, D-29, D-35, D-38, D-41, D-49, D-50, D-54 | 10 |
| attended, delegated to an agent | D-55..D-60 | 6 |
| channel not stated ("Mark ratified", "Mark directive", `#635` thread) | D-3, D-4, D-5, D-6, D-15, D-17 | 6 |
| no human (withdrawn) | D-45 | 1 |

So 46 of 63 answers came in attended sessions and 10 through the asynchronous
issue channel. Attended sessions resolve in batches: 2026-08-19 (11 rows),
08-22 (5), 08-26 (7), 08-28 (6), 09-07 (6), 09-08 (3).

Recorded failures of the asynchronous channel [O]:
- D-49/D-50: Mark answered on #852 twice ("*"D-49: A"*" 2026-08-29 and
  "*"D49 - A"*" 2026-08-30) and "Gate-0 never consumed either comment:
  iteration 308's STATUS reads *"0 directives since watermark"* while both
  answers sat on the then-ACTIVE bookkeeping thread for 1–2 days. The weekend's
  rc=1 crash fires advanced the directive watermark without processing — the
  crash-swallows-directive class" (C:116).
- D-38: the cited comment "is NO LONGER RETRIEVABLE … Mark confirmed in the
  attended session that he posted the directive and then deleted it … the
  ledger cites a URL that now resolves to nothing" (C:105). A provenance note
  was added so the row is not re-opened.
- D-33/D-34: an attended session labelled two rulings D-31 and D-32, IDs already
  held by OPEN rows (C:100-101, see 1.7).
- STATUS 354: "`#1072` carries a self-authored rc=143 notice the directive read
  is blind to" → queued `m-gate0-self-crash-notice-read` (C:219).

Latency numbers the text gives [O]: D-29 "Answered after 5 iterations open"
(C:96); D-41 "Answered after 1 day open" (C:108); D-12's motivating case, a P0
doc "absent from the queue for **eight days**" after its ruling (C:74); D-37
unfiled from 2026-07-28 to 2026-08-25 (C:104); D-19's stale sentence "read as
live owed work for 17 iterations" (C:86).

### 1.5 Count and classification

[O] 63 rows, all RESOLVED (`scripts/mission_decisions.sh --check` → "decision
ledger valid: 63 rows"; `--open` → 0 lines; the stamps agree: "Ledger 63 rows,
**ZERO open**", C:219). IDs: D-1..D-19, D-COV-1, D-ROUTE-1, D-22..D-63. D-20 and
D-21 do not exist and nothing in lines 1-520 says why.

[I] Classification is mine; borderline rows noted.

| kind | n | rows |
|---|---|---|
| Technical / product design choice | 20 | D-1, D-2, D-3, D-4, D-14, D-15, D-17, D-COV-1, D-19, D-22, D-25, D-30, D-35, D-37, D-38, D-39, D-43, D-47, D-49, D-57 |
| Disposition of a blocked or capped item (split, hold, sequence, approve, re-scope) | 8 | D-5, D-9, D-10, D-50, D-55, D-58, D-59, D-60 |
| Standing authorization for an unattended git / rig action | 7 | D-8, D-16, D-23, D-42, D-46, D-54, D-61 |
| Loop process rule or loop-infrastructure fix | 6 | D-11, D-12, D-13, D-18, D-36, D-40 |
| Model routing / judge independence | 6 | D-ROUTE-1, D-31, D-48, D-56, D-62, D-63 |
| Scope of the bar / goal / estimate | 4 | D-24, D-27, D-51, D-53 |
| KPI definition / eval-data integrity | 4 | D-29, D-32, D-41, D-44 |
| Queue ordering | 2 | D-28, D-33 |
| Spending / resource allocation | 2 | D-26 ($20 cap run), D-52 (spend one iteration) |
| Release / scan cadence | 2 | D-7, D-34 |
| Ops / access | 1 | D-6 |
| Withdrawn, not a decision | 1 | D-45 |

Grouped: 38 product-facing (first, second, scope, KPI, release), 21 about the
loop itself (authorizations, process, routing, ordering), 4 other. Borderline:
D-16 (skill pin; D-23 says it "EXTENDS `D-16`", C:90, hence "authorization");
D-13 (driver write path; could be "technical"); D-COV-1 (coverage semantics;
could be "KPI"); D-55/D-60 (re-scoping a blocked design; could be "technical").

### 1.6 Rulings that changed how the loop itself works

- **D-12** (C:74): "a human ruling that unblocks a design doc MUST create or
  un-park its queue row in the same iteration that consumes the directive".
  Reason: "A resolved ruling previously left a P0 doc absent from the queue for
  **eight days**, and the same class recurred as 'a follow-up filed in another
  row's prose is not a backlog item' (iteration 197)."
- **D-11** (C:73): add a short-success guard. `mission-world` "logged `iteration
  complete (rc=0)` at **2m33s** … and NEITHER watchdog fired because a clean
  exit code reads as success … the load-bearing assertion is a worktree/output
  diff, not the exit code."
- **D-36** (C:103): evaluator rounds. "Continue past round 3 while each round's
  findings keep SHRINKING IN KIND; park `needs-human-review` the moment a round
  raises something the previous round did not anticipate in kind … Hard cap
  **5** rounds regardless." Land-and-flag declined because "*"the remaining
  findings are mechanical"* is assessed by the controller, who is also the party
  that wants to land, so ratifying it installs a self-judged escape hatch that
  widens under pressure. (c) puts the criterion in the JUDGE's output instead."
  Trigger: iteration 275 scored 63 / 45 / 38, all FAIL, and landed anyway.
- **D-40** (C:107): "The unattended loop had NO INDEPENDENT JUDGE for 4
  consecutive iterations, and the cause is a session-level instruction the loop
  cannot see. FIX THE DRIVER PROMPT". Carries a verification obligation: "If the
  routing block still reads `NOT spawned`, the escape-clause theory is REFUTED
  and this row re-opens". Lesson: "a defect in how the loop is INVOKED cannot be
  diagnosed from inside the loop, and the deviation line is the only evidence
  that reaches a human."
- **D-62** (C:129): "*"I don't really get the obsession with making sure all
  steps need to be on different models/vendors. its a nice to have, not a
  blocker."* `generator != judge` is now PREFERRED at vendor level, REQUIRED at
  model level." Evidence: "the docs canary evaluator failed 3/3 on the
  cross-vendor pi lane precisely because it had no methodology … A same-vendor
  judge WITH its rubric beats a cross-vendor judge without one."
- Also: **D-52** (C:119) — per-gate heartbeat, because "Of iterations 296–310,
  **six** … produced no record at all … a slot that dies exits `rc=0`, so
  neither watchdog fires"; "Recovery costs a whole later iteration each time".
  **D-63** (C:130) — retire a CI assertion that was red "for EIGHT consecutive
  runs — including the v0.35.3 release itself — while guarding a policy nobody
  intended to keep. A gate that is red for a policy you have abandoned stops
  carrying information about the ones you keep". **D-18** (C:82) — red-CI
  ownership per repo, after two loops "produced the same six files four minutes
  apart". **D-31** (C:98) — designer rotation split into authoring vs review
  lanes. **D-28**, **D-33** — ordering (see §5). **D-23/D-42/D-54/D-61** — each
  widens unattended git authority by one measured predicate (C:90, C:109,
  C:121, C:128); D-61 is "Scoped as a bridge, not a permanent grant".

### 1.7 Reversed, superseded, corrected — and how it is recorded

There is no "SUPERSEDED" status. Everything is recorded as text inside the row
or as a new row. [O] unless tagged.

- **ID collision repair** (D-33, D-34; C:100-101): an attended ruling was
  recorded under labels D-31/D-32 already held by OPEN rows. "Per the
  decision-recording contract (append-only, no ID reuse, ledger is
  authoritative), the pre-existing OPEN `D-31` keeps its ID and the attended
  ruling is re-filed here as `D-33`. No ruling is altered and no question is
  re-asked; only the label moves." Consequence avoided: the report "would have
  re-asked `D-31` and `D-32` hours after Mark ruled on two *different*
  questions bearing those labels, which reads as the loop ignoring him".
  - Residue: Backlog rule 2 still cites the ruling as "(`D-31`, Mark attended
    2026-08-23)" (C:508). The label was moved in the ledger and not in the
    policy that depends on it.
- **Discharged** (D-34; C:101): "**DISCHARGED by Mark 2026-08-24T23:35:48Z on
  `#852` ("D-34 is discharged"), actioned iteration 272** … This row must no
  longer generate a DECISIONS ask." Appended in the same cell.
- **Withdrawn** (D-45; C:112): status RESOLVED, text "WITHDRAWN BY MEASUREMENT".
- **In-row supersession banner** (D-19; C:83-88): "**⚠ SUPERSEDED — the owed
  revision was DISCHARGED at iteration 234** … The sentence that follows
  described the state at iteration 229 and was never updated, so it read as live
  owed work for 17 iterations — the transcription class this loop keeps closing,
  here in its own charter. Historical text follows:". The stale text is kept.
- **Superseded before answered** (D-18; C:82): "superseded in substance by
  `c2022c7fa` before the ask was answered".
- **Scope of an earlier ruling narrowed by a later one** (D-38 → D-39; C:106):
  "(a) ratifies the DIALECT … it does **NOT** ratify the LINE LAYOUT".
- **Supersedes an earlier fix** (D-48; C:115): "Supersedes the kimi half of the
  2026-08-26 rotation fix".
- **Self-correction inside a row** (D-41; C:108): "The controller's first draft
  of this row asserted that banked results live in a per-machine store … that
  was REFUTED by the controller's own measurement minutes later and is corrected
  here rather than shipped".
- **Historical ID reuse** (D-6; C:68): "ID reuse is retained only for history
  and forbidden going forward"; D-ROUTE-1 "unique ID avoids reusing historical
  D-7" (C:81).
- **KPI numbers are never restated**: D-29 publishes both arms "so no published
  number is silently restated and the 2026-07-27 ratification is not
  overturned" (C:96); D-44 "bank under a new metric name … no banked row is
  restated" (C:111).
- [I] **Unmarked reversal, D-56 → D-62.** D-56 (2026-09-07, chosen by Codex
  under delegation): "Exclude the entire origin vendor of the artifact author
  from its independent judges, not just the exact model … unavailable
  independent capacity is a recorded wait, never an absent-judge pass" (C:123).
  D-62 (2026-09-08, Mark's own words): vendor-level independence is "PREFERRED",
  model-level "REQUIRED"; "A different model from the same vendor is ALLOWED and
  FLAGGED" (C:129). [O] `D-56` appears nowhere in lines 1-520 except its own
  row; neither row references the other. STATUS 354 then shows the same-vendor
  substitution in use: "astra recused from its own quorum, `gpt5-6-sol`
  substituted" (C:219).
- [O] The attended script enforces the no-edit rule mechanically: "a resolved
  row is never re-answered; supersede it with a new ID instead"
  (`scripts/mission_answer.sh:137`).

---

## 2. The bar and the goal

### 2.1 The bar (C:239-271)

- [O] Heading: "The v1.0 bar — v2, PRODUCT-SHAPED (RATIFIED 2026-07-11, Mark;
  supersedes the 2026-07-10 hygiene bar)" (C:239). So the first bar lasted one
  day; it "is absorbed: its clauses are 1–2 below, both essentially done"
  (C:249).
- [O] The claim: "***the verified AI-orchestration language*** — an AI author
  gets a verified-correct program at the lowest cost, and AI orchestration is
  type-checked" (C:241-242), derived from `planned/m-fable-strategy-review.md`
  ("Design Freeze items 1+2 ratified by Mark 2026-07-11", C:243-245).
- [O] **Cutoff rule**: "a design doc gates v1.0 **only if it serves an open
  clause below.** Everything else ships on the normal v0.2x road or is post-v1 —
  regardless of folder history." (C:247-248).
- [O] Five clauses (C:251-271): 1 STABLE ✅ ("tier assignments RATIFIED by Mark
  2026-08-04, attended — clause 1 fully CLOSED"); 2 SOUND ("zero P0s ✅ … residue
  … m-bytecode-vm-parity-bugs (≤2d, queued)"); 3 ACCESSIBLE TO THE FLEET TIER
  (footgun list, "teaching prompt ≤1,500 lines with a rig-A/B showing no
  pass-rate loss", "**Gate = this finite work.**" — the sonnet-class outcome is
  "measured and published at release, NOT blocking"); 4 ORCHESTRATION FLAGSHIP;
  5 COST CREDIBILITY ("cost-per-verified-success vs Python, per tier"; the ≤3× /
  ≤1.5× targets are "NOT release gates").
- [O] Each clause separates a finite gate from a tracked, non-blocking outcome.
- [O] Amendments are made in place, inline: strikethrough plus landing tag
  ("~~m-check-strict-fallbacks~~ **[LANDED iter 101, PR #479]**", C:253-254);
  a pointer to the ruling ("RE-SCORED to v1.1 per **D-27**, Mark attended
  2026-08-22 — clause 4 requires sprints 1–3 only", C:264-265); "was:
  ratification parked for Mark" (C:252).
- [O] A second scope ruling is recorded only in a commit message: `6f1d1c7a1`
  (2026-07-12) "Mark chose FULL SCOPE: whole clause-3 footgun/DX/prompt cluster
  + both DX tooling investments + full clause-4 orchestration surface all IN;
  infra OUT." It had to be recovered from git history to answer D-53 (C:120;
  C:195-198).
- [O] The bar text is stale and is not corrected where it stands: clause 4 still
  says "(both verified absent …)" (C:267-268) while the Goal block records
  "**Correction of record — clause 4's own text is stale, and it moved N down by
  2** … **Both landed on 2026-07-11/12**" (C:176-182).

### 2.2 The goal — the countable unit (C:133-217)

- [O] Why it exists: "The 2026-08-31 comms contract requires every report to
  state **distance to the charter's finish line in the charter's own countable
  unit**" (C:135-136).
- [O] History: iteration 309 added a PROVISIONAL unit, open queue rows —
  "**68** `[NEXT]` + **1** `[PARKED]`" at iteration 311 (C:118). Rejected
  because it "was anti-correlated with good work — an iteration that landed a
  milestone and fixed a real defect moved it by 0, while an iteration filing
  five triage rows moved it backwards" (C:137-139). Ratified replacement:
  "RATIFIED 2026-09-01 by Mark, attended; ledger `D-51`" (C:133).
- [O] "**Unit: the number of DESIGN DOCS that remain before v1.0.0 can be
  declared.**" (C:141). Rules (C:146-159): a doc counts once however many
  milestones; sprint plans never count; a doc leaves when it "LANDS, is RULED
  OUT, or is re-scored off the bar"; "**Folder location is evidence, not
  truth.**"; a clause naming work with no doc contributes one "NEW-DOC" unit;
  "**This number is allowed to go UP, and that is the unit working rather than
  failing.**"; report as "`N remaining (was M, ±k this iteration, reason)`".
- [O] Unclassifiable items go to "a named UNCLASSIFIED bucket for Mark to rule
  on — never silently included or dropped" (C:118). Used once: four docs, ruled
  by D-53 (C:120), bucket retired (C:193-194).
- [O] Current value: "**N = 12** (iteration 333: was 13, **−1** …) — 9 existing
  design docs + 3 NEW-DOC units" (C:166-167); per clause 3 / 2 / 4 / 3
  (C:169-174). Baseline 10 at iteration 315, +2 by D-53 (C:215-217). The step
  from 12 to 13 is not explained in these lines.
- [O] All three live stamps report "N=12, goal unmoved (HARNESS)" (C:219, C:221,
  C:223). D-28 on 2026-08-22 estimated v1.0.0 "declarable in ~2 weeks of loop
  time" (C:95).

### 2.3 How queue items are tied to the bar [O]

- The cutoff rule itself (C:247-248): membership is decided against clause
  *text*, by a controller inventory using `test -d`, `find` and `grep -c` with
  controls (C:161-164). No script computes N.
- Queue section headings per clause ("`### Clause 4` … *"(Mark: full surface
  in)"*", C:202-203) and a queue tag "`**[GATING clause-4]**`" (C:205). The tag
  is explicitly not authoritative: "The tag is a queue annotation and `D-51`
  says the clause text governs" (C:207).
- Explicit OUT list with reasons (C:184-191), including a doc that
  "self-disclaims bar membership" and an umbrella doc excluded to avoid
  double-counting.
- Backlog rule 0, BAR-FIRST (C:503-505); guardrail: each report "should note
  when it CLOSES a bar clause" (C:431-433).
- Stamps and log headings tag each iteration's work as bar-moving or not
  ("(HARNESS)" in C:219; "[PRODUCT]" in `v1-mission-log.md:65`).

---

## 3. Guardrails (C:424-499) and the reason recorded for each

| # | guardrail | lines | recorded reason |
|---|---|---|---|
| 1 | **No releases** by the loop; rolling cadence, Mark snapshots releases; v1.0.0 "is a MILESTONE declared when all five bar clauses are satisfied — not a single big-bang release" | C:426-434 | A dated ruling (Mark, 2026-07-12); no incident. Consequence stated: "dev must stay release-ready at EVERY commit". Related: "Releases remain Mark's sole decision" (C:101). |
| 2 | **No pushes without account check** (`gh auth status` → `sunholo-voight-kampff`) | C:435 | None given. |
| 3 | **No work on a dirty main worktree**; sprints in coordinator-managed worktrees | C:436-437 | None given here. |
| 4 | **Budgeted**: "hard wall-clock kill in the driver (default 6h); one backlog item per iteration" | C:438 | None given. |
| 5 | **Kill switch**: `touch ~/.ailang/state/mission-control.disabled` or `launchctl unload …` | C:439-440 | None given. In use: "First fire in six days (kill switch lifted)" (C:221). |
| 6 | **Subscription billing only** (2026-07-10) | C:441-444 | Incident: "The first kickstarted run billed ~13 min of API credits before this was caught; never again." A second, related incident is in the routing section (C:309-319). |
| 7 | **Escalation**: on `needs-human-review`, merge conflicts or any guardrail trip → `ailang messages send controlplane`, park, pick the next; "never force through" | C:445-446 | None given. |
| 8 | **Skill edits**: "max one per iteration, ≥2 recorded frictions each, called out in the morning report (git history is the rollback)" | C:447-448 | None given. |
| 9 | **Dev stays GREEN** (2026-07-10, Mark): not `[LANDED]` until remote CI passes on the merge commit; red dev CI outranks the queue. "**V1 OWNS that red — it is not shared** (2026-08-17)" | C:449-461 | Measurement: "local gates miss fmt-check/govulncheck/file-sizes/docs build". Incident: two loops "produced #758 and #759 — same red, same six files, duplicated end-to-end"; "there is no cross-mission mutex". The named residual risk: "a red nobody picks up because each loop assumed the other owned it". |
| 10 | **Benchmark curation cycles run through the loop, not as attended side-sessions** (RATIFIED 2026-08-04, Mark: "*"Route curation through mission loop"*") | C:462-479 | Incident, iteration 140: `f574c4b58` "moved 12 benchmarks between tiers and updated **neither** of the two gates that pin the tier distribution … dev CI was red on every commit for ~2h, iteration 139 had already misfiled that red as a known runner flake, and v0.33.0 came within minutes of shipping on a red dev … 0.5s-reproducible … nothing about it was hard *except that nobody whose job it was ever saw it*". |
| 11 | **A positive result from ONE confirming instance is not a general claim** (process fix, iteration 122) | C:480-499 | Incident: "three misses of the opposite shape in one run". Test: "**"how many instances is this true of, and did I count them?"**". Marked "Watch-item, not yet a skill edit: needs one more independent instance before it earns the one-edit-per-iteration slot." |

[O] 4 of 11 carry a named incident (6, 9, 10, 11); 1 carries a dated ruling; 6
state no reason.

Other incident-born rules in lines 1-520, outside the Guardrails section [O]:
- PICK: "**Verify against repo reality first** (git log + code + tests), never
  trust a status header — stale-status docs are how we shipped M-EVAL-BENCH-UI
  twice (2026-07-10 lesson: doc said Planned, all 4 milestones were long done)"
  (C:276-278).
- DEMAND-EVIDENCE GATE (Mark 2026-07-23): "?-op, block-let-separator, and |> ALL
  failed it in one week … a 60-second corpus grep … is mandatory Gate-2
  evidence; zero-demand items go to EVIDENCE-GATED ICEBOX without spending a
  quorum round. Technical soundness is not the bar; observed need is." (C:322).
- FORUM RULE (Mark 2026-07-21): experiments do not ride full iterations; "The
  fmt A/B's 3-day design→park→greenlight→integrity→execute arc vs the 58-cent
  20-minute interactive demo is the canonical example" (C:324-331).
- Rig two-tier rule: `rig.lock` "is a **GPU mutex, nothing more** (Mark,
  2026-07-10)"; held "for **that step only**"; "the port-8080-zombie class"
  (C:400-411).
- Harness boundaries: "eval rows must not pool across these", with dated version
  steps; "the field that would have made them visible did not exist until
  2026-09-16" (C:413-422).
- RETRO lanes: friction goes to "exactly one lane: **skill fix** … **process
  fix** (edit this doc), or **backlog item**" (C:285-288).

---

## 4. Model routing policy (C:290-396)

Heading: "Model routing policy (evidence-updated, not vibes)" (C:290).

| role | assignment in the table | evidence cited | lines |
|---|---|---|---|
| Controller | Opus; "Fable = emergency fallback only" | Mark 2026-07-16: "Fable for real high cognition stuff not execution"; "The 07-14 Fable revert burned the weekly bucket at 2h cadence" | C:294 |
| Design docs | rotation `claude:claude-fable-5` ⇄ `codex:gpt-5.6-sol` (Mark 2026-07-17); gemini parked as designer because `CapRemoteSandbox` cannot edit a worktree | "Every design passes the QUORUM regardless of author — the quorum is the quality gate, so authorship diversity is free comparative signal" | C:295 |
| Sprint planning | Opus | "Plan quality determined execution success historically" | C:296 |
| Sprint execution | Opus, "per Mark 2026-07-10" | "Sonnet execution was a false economy (needed corrections); also `dev-cycle.md` had silently pinned sonnet" | C:297 |
| Sprint evaluation | Sonnet, pinned sub-agent (fable→sonnet 2026-07-16, Mark directive #399) | fable "was not" an Agent-tool alias, "so the fable default re-routed to sonnet every iteration anyway: 31, 36" | C:298 |
| Mechanical | Sonnet allowed | "Only with deterministic verification; promotion beyond this requires evidence" | C:320 |

- [O] **Evidence rule**: "every sprint's log entry records `(model, task class,
  evaluator round-1 score, rounds-to-pass, corrections)`. A routing change
  (either direction) requires ≥3 data points and is made in RETRO, recorded here
  with a dated stamp." (C:333-335).
- [O] **Enforcement note** (2026-07-15): "this table is no longer prose. The
  driver exports `$MISSION_PLANNER_MODEL` / `$MISSION_EXECUTOR_MODEL` /
  `$MISSION_EVALUATOR_MODEL` and mission-control Gate 3 spawns each heavy role
  as a model-PINNED sub-agent … **Before M1, every role inherited the single
  session model → 100% Fable burn**" (C:337-342).
- [O] **Recorded misdiagnosis** (2026-07-16): ""Fable quota-exhausted until
  2026-08-01" was a MISDIAGNOSIS … Root cause: `~/.zshenv` sources
  `secrets.env`, so every tool shell re-exports `ANTHROPIC_API_KEY`; nested
  `claude -p` calls … therefore billed the METERED API". Heuristic kept: "Any
  future "quota" error naming a reset date that is not a Monday = you are on the
  API key; fix the leak, don't fall back." (C:309-319).
- [O] **Evaluator independence**: gemini rejected as evaluator on two verified
  counts — architectural (`internal/executor/managed_agents/managed_agents.go:164`,
  no repo upload) and operational (probe timed out) (C:359-376).
- [O] **Right-sizing table** (C:378-396): a per-role tier *hypothesis* (e.g.
  planner "MID (down-tier) — kept at Opus until M3's ≥3-datapoint A/B"); "Where
  the two differ … the gap is a deliberate, evidence-gated decision".
- [O] Amendments are stacked as dated blockquotes with strikethrough
  (C:300-319, C:337-376), not rewritten.

Staleness [O facts, I conclusion]: the table no longer matches what runs.
- D-ROUTE-1: "executor remains Codex Sol primary with DeepSeek v4 Flash backup
  and Opus last" (C:81).
- Live stamps: planner `pi:ollama/kimi-k3:cloud`, executor
  `pi:ollama/deepseek-v4-flash:0731-cloud`, designers `codex:gpt-6-astra` and
  `claude:claude-fable-5-1`, judge `agent-tool sonnet` (C:219, C:221, C:223).
- D-63: "The driver moved the evaluator to
  `claude:claude-sonnet-4-6,claude:claude-haiku-4-5,opus`" (C:130).
- D-48: the rotation was changed in `mission-control/SKILL.md`, "fleet-wide by
  construction — every mission reads that list" (C:115).
- [I] The enforced routing lives in the driver env and the shared skill; the
  charter table is a stale copy. Human rulings (D-48, D-62, D-63) changed
  routing directly without the ≥3-datapoint rule. STATUS 351 mentions a
  different threshold: "deepseek's **second consecutive** `ok` with a non-empty
  diff, which meets the promotion bar" (C:223).

---

## 5. Backlog ordering policy and STATUS rotation rule

### 5.1 Backlog ordering (C:501-519)

0. [O] "**BAR-FIRST (D-28, Mark attended 2026-08-22 — TEMPORARY until all five
   v1.0 bar clauses close)**: items serving an open bar clause outrank
   everything below … Delete this rule when the bar closes." (C:503-505).
   Rationale in D-28: "remaining bar-gating work is roughly 8–12 sprint-days and
   clause 5 is a single funded run, so bar-first makes v1.0.0 declarable in ~2
   weeks of loop time instead of 4–6" (C:95).
1. [O] "Open **P0s** first … oldest-known-risk first." (C:506).
2. [O] "**Unblockers**"; cross-mission blockers rank here "and they outrank rule
   0's BAR-FIRST clause when a sibling mission's milestone is stopped by them."
   Rationale: "it never appeared in this queue at all … Measured at ruling time:
   **8 open**, and of the ten such asks ever filed, the only two that ever
   carried labels (`#662`, `#656`) are the only two that were ever picked."
   Bound: `cross-mission`-labelled issues "MAY NOT sit unrouted for more than
   one weekly sweep." (C:507-514).
3. [O] "**P1 by impact-per-day** … prefer ≤3-day items to keep iterations
   sprint-sized" (C:515-516).
4. [O] "**Strategic multi-week items enter only after decomposition** … (a
   decomposition is itself a valid iteration deliverable)" (C:517-518);
   exercised by D-19, whose iteration-229 deliverable "was the decomposition,
   not the implementation" (C:83).
5. [O] "Anything re-scored `post-v1` in iteration 0 leaves the queue." (C:519).

[O] Precedence is not purely positional: rule 2 overrides rule 0 by a sentence
inside rule 2; "a red dev CI outranks the queue at OBSERVE" lives in Guardrails
(C:450-451); D-26 "Outranks the queue next iteration under D-28" lives in the
ledger (C:93). [O] The Queue heading reads "top = next" (C:521).

### 5.2 STATUS rotation rule (C:227-236)

- [O] "Newest **3** STATUS stamps live here; older ones move to
  v1-mission-status-archive.md. **Loop: at Gate 4, after adding your stamp, move
  the now-4th stamp to the TOP of the archive file.**"
- [O] Added 2026-07-14 ("Fable-quota diet"). Rationale: "every iteration
  re-reads this charter — 30+ stamps were ~500 lines of history tax per read, on
  the scarcest model budget. The append-only history lives in the log +
  archive."
- [O] Self-heal clause, added because the rule failed twice: "**SELF-HEAL (added
  2026-07-22 iter-83, 2nd instance of drift after iters 77+82 hand-corrected an
  already-drifted N>4): if MORE than 3 stamps remain after adding yours, move
  ALL but the newest 3 to the archive top, newest-first — do not assume exactly
  one over-count.**"
- [O] Live stamps are for iterations 354, 353, 351 (C:219, C:221, C:223); 352
  and 350 died without a stamp and were "credited" by their successors.
- [O] Each stamp is a single line of 4,473 / 6,508 / 5,344 chars.
- [I] The read-cost the rule was written to cut has reappeared elsewhere: the
  ledger has no rotation, all 63 rows are resolved, and it is 126 KB of the
  179 KB an iteration reads before the queue.

---

## 6. Machine-checked versus prose only

### Machine-checked (named in lines 1-520; I confirmed each file exists at HEAD)

- **Ledger markers + `scripts/mission_decisions.sh`** (C:55-56, C:60, C:131).
  [O] 39 lines of bash/awk. `--check` enforces: exactly one start/end block,
  at least one row, no duplicate ID, status ∈ {OPEN, RESOLVED}, non-empty answer
  and evidence cells (`scripts/mission_decisions.sh:16-37`). `--open` lists OPEN
  rows. It does **not** check append-only, ID order or gaps, who resolved a row,
  that a resolution names a human or a date, or references from other sections.
  Run from `tools/launchd/test_mission_routing.sh:319-322`, which also asserts
  D-ROUTE-1 is not re-asked.
- **`scripts/mission_directives.sh`** (C:100, C:102, C:109, C:121). [O] Author
  allowlist enforced in code (default `MarkEdmondson1234`, `:49`); refuses if
  the allowlist contains the authenticated account ("that lets the loop direct
  itself", `:54-70`); `--since` filter; reports "N directive(s) … of M comments"
  (`:103`). Its header says why it exists: the allowlist was previously "written
  into the mission-control skill's prose — correct, but enforced only by the
  controller choosing to run that exact command" (`:8-12`). It deliberately does
  not write the watermark (`:14-15`) — yet D-49 records a crash that advanced
  the watermark anyway (C:116).
- **`scripts/mission_answer.sh`** (the "script" of C:122-127; "ATTENDED LEDGER
  EDITS contract"). [O] Rewrites exactly one row; refuses a non-OPEN row
  (`:136-139`); refuses a bot identity (`:110-111`); refuses a row that does not
  split into 6 fields (`:131-134`); re-runs the validator (`:172-174`).
  Self-documented weakness: "ATT_NAME/ATT_EMAIL below are DEFAULTS, not derived
  from whoever invokes the script … The real control is the charter rule, not
  this code." (`:44-48`); the old stamp was "FALSE BY CONSTRUCTION" because "git
  identity here is the fleet bot for every session including Mark's"
  (`:50-56`), and twice "an agent read that sentence as a control it had to
  protect, and handed a ruling Mark had already given back to Mark" (`:64-67`).
- **Driver controls** named in the charter: API keys stripped + auth probe
  (C:14-19, C:441-443); kill-switch file "checked in preflight" (C:439); hard
  wall-clock kill, default 6h (C:438); per-mission overlap guard
  (`mission-${MISSION_NAME}.pid`, C:454-455); role pins by env var (C:337-340);
  `MISSION_METERED_BUDGET_USD` (C:93; stamps report "$0.29 of $5", C:219);
  `PIN_DRIFT` / `PIN_AGE` (C:128, C:219).
- **CI**: Gate 3b, remote CI on the merge commit (C:449-450);
  `TestMissionDocHeadingsStayCanonical` (C:223) — [O] in
  `internal/mission/canonical_test.go:68-91`, a ratchet (`knownNonCanonical =
  11`, `:19`) over logs and status archives only; "Charters are excluded
  deliberately: they are curated prose" (`:21-22`). So a stamp is linted only
  after rotation into the archive. Fixer: `ailang mission normalize --apply`
  (`:85`). Also `internal/cihygiene/gate_wiring_test.go:43`, a registered
  exemption (C:104).
- **Quorum tooling**: `ailang design-quorum` with a default reviewer set
  (C:123); JSON artifacts under `.ailang/state/mission-quorum/` (C:122) with an
  `absent_reviewers` field (C:83, C:89); `Candidate.SameVendorAsAuthor` on the
  receipt (C:129).
- **GitHub label** `cross-mission`, "enumerated at Gate 0" (C:511-512).
- A machine check that was removed for going stale: the exact-chain routing
  assertion in `tools/launchd/test_mission_routing.sh`, red for eight runs;
  "Do NOT reinstate an exact-chain grep — it re-freezes a routing decision that
  is meant to move" (C:130).

### Prose only

- "Rows are append-only, IDs are never reused" (C:56) — only duplicate IDs are
  checked; the text itself records one historical reuse (C:68) and one collision
  (C:100-101).
- Same-iteration resolution (C:56-57) and D-12's un-park rule (C:74).
- "the UNATTENDED loop may not resolve a row on its own behalf" (C:122) — the
  charter and the script both say this prose rule is the actual control.
- The bar, the cutoff rule, the goal count N (hand-measured each time), the
  backlog ordering policy, the STATUS rotation rule (failed twice, still prose).
- Guardrails 1-4, 7, 8, 11; the ≥3-datapoint rule; the DEMAND-EVIDENCE gate;
  the FORUM rule; "Standing rules" 2, 7, 8 (defined in the skill).
- D-42's reconcile predicates (0 ahead, `comm -12` empty) are measured by the
  controller each time and written into the evidence row (C:109). [I] I saw no
  script named for them.
- The routing table and the Repo Profile's live values (both stale, §0, §4).

---

## 7. Against the "already known" list

- **"Design docs move from `planned/` to `implemented/vX_Y_Z/`"** — true as
  intent, unreliable in practice by the charter's own account: "**Folder
  location is evidence, not truth.**" (C:151); `m-bytecode-pattern-arity-fix`
  "LANDED … but never moved out of `planned/`, i.e. folder-as-evidence failing
  exactly as the unit's rules anticipate" (C:188-190); the cutoff rule applies
  "regardless of folder history" (C:248). The move is a later bookkeeping step
  ("docs moved to `implemented/v0_35_3/` with iteration 351's", C:221).
  `planned/` also has version subfolders (`planned/v1_0_0/`, `planned/v0_35_0/`)
  and holds sprint plans beside design docs ("**13** `.md` files = **6** sprint
  plans … + **7** design docs", C:163-164).
- **"A decision ledger" that is append-only** — the *row set* is append-only;
  row *content* is rewritten in place (answers, corrections, discharge notes,
  provenance notes). ID uniqueness failed twice. A day-old ruling was relaxed by
  a new row with no cross-reference (§1.7).
- **"A regenerated index"** — `v1-mission-index.md` and
  `v1-mission-status-index.md` exist on disk, but lines 1-520 never mention an
  index; the header links only the log (C:24) and the rotation rule only the
  archive (C:229-230). A dashboard is mentioned once ("overwrite-every-iteration",
  C:90).
- **"One skill, gates 0-5"** — consistent (Gate 0, 1, 2, 3b, 4, 5 appear in the
  stamps). The charter's own five-step summary still says "Max 3 evaluator
  rounds" (C:281), which D-36 replaced with a convergence rule capped at 5
  (C:103). `ailang-world`'s driver is "a hand-synced fork (different repo) and
  takes it only by port" (C:107).
- **"Rotating STATUS stamps"** — consistent; note the self-heal clause and that
  2 of the last 5 iterations left no stamp at all.

---

## 8. What I did not read

- `design_docs/v1-mission.md` lines 521-4908 (the Queue) — only line 521's
  heading and the first 200 chars of line 523, to confirm the boundary.
- `v1-mission-log.md`, the archives, the index and dashboard files — only the
  first four and last three `## ` headings of the log, for a liveness check.
- `.claude/skills/mission-control/SKILL.md` and its resources — not read. The
  "Standing rules", the "decision-recording contract", the "narrow-refinement
  carve-out", "ghost discipline" and "rule 3a/3f" are defined there; I report
  only how the charter cites them.
- `tools/launchd/mission-control.sh`, `tools/launchd/lib/pin-root.sh` — not
  read. `tools/launchd/test_mission_routing.sh` — lines 310-330 only.
- `scripts/test_mission_answer.sh`, `PROGRAM.md`, `mission-charter-TEMPLATE.md`,
  the other three charters, `.github/` workflows (not in the sparse checkout) —
  not read. I did not confirm which CI job runs `test_mission_routing.sh`.
- No GitHub issue, PR or commit cited by the charter was opened. Every incident
  above is the charter's own account.
- Read in full beyond the brief, because the charter names them as its
  validators: `scripts/mission_decisions.sh` (39 lines),
  `scripts/mission_directives.sh` (103 lines), `scripts/mission_answer.sh`
  (185 lines), `internal/mission/canonical_test.go` (149 lines).

Side effect to disclose: one `git grep … HEAD` I ran on the partial clone began
lazily fetching blobs and triggered repeated auto-packing. I stopped it after
about two minutes. The working tree, index and sparse-checkout settings are
unchanged and no lock files remain, but the clone's object store gained some
blobs. I used plain `grep` on on-disk files afterwards.
