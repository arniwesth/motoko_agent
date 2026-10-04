# AILANG `design_docs/v1-mission.md` Queue, first half (lines 521-2700)

Source: sparse clone of `dev` at 2a1f3f295 (2026-10-03). File is 4,908 lines / 930,233 bytes.
All `:N` references are `design_docs/v1-mission.md:N` unless another path is given.
Quotes are verbatim except that the file's HTML entities (`&mdash;`, `&rarr;`, `&ndash;`) are shown as the characters they render to.

## What was read, and how

- Read IN FULL, every line printed untruncated by a Python loop (no `Read` tool, no line cap), in 14 chunks: **:501-520** (ordering policy) and **:521-2700** (the assigned range). 2,180 lines, 355,333 characters (357,446 bytes); 63 lines exceed 1,000 chars, 9 exceed 2,000, longest 7,236 (:616).
- Outside the range I looked only at: :74 (ledger D-12), :118 (ledger D-51), :133-160 (Goal block), :227-236 (STATUS rotation rule), :273-289 (How the mission runs), :4899-4908 (the two tail sections), plus whole-file `grep -c` counts. These are flagged "outside range" where used. Lines 2701-4898 were NOT read.
- Git history is not available (shallow clone, one commit), so "how an item changed over time" is inferred from dated stamps inside the text, not from diffs.
- Scripts used for the measurements are in `ailang-survey/qa-tmp/` (`items.py`, `stats.py`, `grep2.py`, `xref.py`).
- Newest dated content in the range is 2026-09-14 (iteration 354, :555-566); the file's commit is 2026-10-03. Oldest LANDED row is 2026-07-10 (:1895).

## 0. Shape of the range (observed)

The "Queue" is not one list. It is five different notations laid down in different months, never converted:

| lines | chars | what it is |
|---|---|---|
| 521-1804 | 271,099 | Dated bold-bracket rows, iterations 270-354 (late Aug to 14 Sep). 133 rows. One bold header line plus 1-6 prose paragraphs each. |
| 1805-1859 | 4,421 | Three `**RATIFIED (attended, …)**` blocks: human rulings stamped into the queue, not work items (:1805, :1814, :1834). |
| 1861-1891 | 3,505 | `**0a. [LANDED — SPRINT COMPLETE …] #764 — …**`, a row numbered ahead of item 1. |
| 1893-2049 | 14,086 | `**Required-for-v1 (the bar's critical path):**` numbered list 1-16, July, all LANDED. |
| 2051-2216 | 16,171 | Human-pinned sub-queues: `[NEXT-FIRST, Mark 2026-07-16 — FLEET ROLLOUT]` with steps (a) (b) (c) (c0) (c1) (d), and `[GAP CLOSURE PRIORITY — Mark 2026-07-17]` with (G1)-(G5). |
| 2218-2429 | 20,258 | A landed "HARD PIN" row and the `[completed … FULL BACKLOG RE-TRIAGE]` block: three batches classifying 52 + 30 + 35 design docs inline. |
| 2431-2472 | 3,607 | `**[NEXT]** clause-3 accessibility cluster …`: a group header followed by iteration narrative. |
| 2474-2658 | 18,988 | `### Clause 3`: seven bullets (:2475, :2504, :2509, :2515, :2548, :2562, :2656), each a ` · `-separated run of inline entries, most struck through. One bullet (DX tooling, :2562-2655) is 94 lines. |
| 2659-2700 | 5,372 | `### Clause 4` (continues past 2700). |

Headings inside the Queue section (whole file): `### Clause 3` :2474, `### Clause 4` :2659, `### Clause 5` :2768, `### Clause 2` :3058; then `## Ruled out / resolved` :4899 and `## Done / superseded` :4906.

## 1. What a queue item is

### 1a. Modern form (:521-1804), observed

Header, one physical line, bold:

```
**[STATUS …] [PROVENANCE …] `id` — one-sentence defect statement.**
```

followed by unindented prose paragraphs. Fields, all free text:

- **Status bracket.** Starts with a tag word, then for closed rows a packed record: date, iteration, PR link, merge commit link, judge model and score, check count, where docs moved, what was NOT delivered. Example :523: `**[LANDED 2026-09-07 (iter-345) — PR [#1074](…/pull/1074) → [`16f0cb741`](…/commit/16f0cb74…); judge `sonnet` PASS 91/100, zero blocking; 20 checks on the merge SHA with only the parked D-60 red left] `ci-red-execgo-file-size` — the REQUIRED `test` context was red on `dev`, …**`. The status bracket alone can run past 1,000 chars (1,274 at :555, 1,285 at :618, 1,177 at :675); header lines have median 180 chars, p90 951, max 2,085.
- **Provenance bracket** (second `[...]`): which iteration filed it, who found it (judge / quorum reviewer / controller / sibling mission / public feedback), and whether it predates the sprint. Example :572: `[iter-351, measured by the independent judge in round 2 and disclosed by the design doc itself as O2c; PRE-EXISTING at HEAD, not introduced by the sprint that surfaced it]`. Demand markers: `[WORLD-DEMAND — …]` :599, :684; `[AITANA-DEMAND]` :1046; `[cross-mission, rule 2]` :1011. Up to four brackets stack (:1066).
- **Id**: a backticked slug, usually `m-…`; also `ci-red-…` (:523, :615), `note-…` (:564, :586), `sweep-…` (:655), `m1b-nolint-suppression-owed` (:694), `sonarcloud-new-code-gate-red` (:913), an issue number as id (`ailang#885` :1011). From :782 downward ids are NOT backticked. 10 of 157 rows have no id at all (:735 "Four PRE-EXISTING driver defects …" holding sub-items (R7)-(R10); :966 "external-issue orphan batch"; :1181, :1295, :1763 superseded stubs; :2067, :2139, :2218, :2220, :2431 containers). Two use an issue number in place of a slug (:1011, :1861). Two put the id outside the header pattern (:2019 has it on the next line, :2051 in a separate bold span).
- **Body**: "Measured …" evidence with file:line, counts, positive and negative controls; then "Fix shape" / "Scope when picked" / "Deliverable"; often an explicit "deliberately NOT fixed in-flight" rationale and a "Distinct from `other-id`" clause.

Representative NEXT row, :561-562:

> `**[NEXT] [iter-354, first-party; pre-existing at base `fd44be9ee`, NOT from this iteration's sprint] `m-codex-quota-admission-test-reads-live-ledger` — `tools/launchd/test_codex_quota_admission.sh` reads the rig's LIVE `~/.ailang/state/quota-ledger.json` … so `make test-launchd-drivers` is red on the rig whenever the live ollama bucket is blocked while the identical CI job is green.**`
> `Measured: … Fix shape (small): the admission arms must run under a synthetic `STATE_DIR`/`HOME` like every other launchd suite …`

Representative PARKED row, :621-622:

> `**[PARKED — needs-human-review, D-58, iteration337] `m-pi-runner-worktree-assertion-vacuous-on-revision` — …**` … `**Resume: D-58 ruling → fresh designer/quorum gate → planner → executor → independent evaluator.** No implementation or sprint plan exists. Design: `planned/v0_35_2/m-pi-runner-worktree-assertion-vacuous-on-revision.md`; rejected prose is retained with authoritative controller corrections.`

### 1b. July forms (:1861-2700), observed

- Numbered row, :1895: `1. [LANDED 2026-07-10] m-named-test-blocks closeout (iteration 1a; deontic criterion deferred, package absent locally)`.
- Clause-section inline entry, :2485-2488: `~~m-arity-style-diagnostic (R4c, 1–2d)~~ **[LANDED iter 21 → implemented/v0_30_0; `TC_ARITY_001` … eval PASS 97/100 round 1, PR #363 → `5b54509d1`]**`. Strikethrough = closed; estimate in parentheses after the id; group label at the bullet start (`**Parser/type footgun fixes** (NEW-DOC, Conflict Surface mandatory):` :2475).
- The stated rule for that era, :1932-1933: `*(Queue re-derived 2026-07-11 from bar v2 — clause tag on every open item. NEW-DOC items start with design-doc-creator; existing-doc items start at reality-check.)*`

### 1c. Tags (measured, first bracket of each of 157 top-level rows)

Declared at :521: `[NEXT] [IN-SPRINT] [PARKED] [LANDED] [RULED OUT]`. Observed leading tags:

| tag | rows |
|---|---|
| NEXT (incl. `[NEXT — …]`, `[NEXT &mdash; …]`) | 77 |
| LANDED | 53 |
| partial-landed variants: `LANDED (M1+M2 of 4)` :527, `PARTIALLY LANDED` :853, `2 of 3 LANDED` :864, `M1 LANDED …` :920, `LANDED-IN-PART … \| REMAINDER DECOMPOSED` :1500 | 5 |
| `superseded` / `SUPERSEDED …` (:1181, :1209, :1295, :1705, :1763) | 5 |
| PARKED (:621, :624, :630, :1435) | 4 |
| `CLOSED ON ARRIVAL` :532, `RESOLVED BY ATTENDED ACTION` :544, `RESOLVED` :615, `completed` :2220 | 4 |
| `PROCESS FINDING` (:564, :586) | 2 |
| `BLOCKED on D-39` :1637, `APPROVED by D-50 BUT BLOCKED ON A PREREQUISITE …` :881 | 2 |
| IN-SPRINT :746 | 1 |
| `ABSORBED into PARKED …` :660 | 1 |
| `was NEXT` :930 | 1 |
| `NEXT-FIRST, Mark …` :2067 | 1 |
| `GAP CLOSURE PRIORITY — Mark …` :2139 | 1 |
| **RULED OUT** | **0** |

135 of 157 rows lead with one of the five declared tags; 22 lead with something else. `[RULED OUT]` is never used as a row tag anywhere in the 4,908-line file (`grep -cE '^\*\*\[RULED OUT'` = 0; the string occurs only at :521 and in prose at :20, :118, :149, :3215).

Other tag vocabularies in use: second-bracket qualifiers `[PRE-REGISTERED — instance 1 of 2 recorded …]` :681, `[DEBT WITH A NAMED OWNER …]` :678, `[JUDGE-FOUND iter-274]` :1755, `[DOC READY iter-284]` :1209; re-triage tags defined at :2231-2234 (`[GATING clause-N]`, `[CYCLE]`, `[POST-V1]`, `[GHOST/SUPERSEDED → …]`, `[FOLD-INTO <doc>]`) plus `[EVIDENCE-PARKED iter 91 …]` :2315, `UNSURE` :2295; `[NEXT-FIRST]` / `HARD PIN` for human pins (:2019, :2218).

### 1d. Clause tags, priorities, estimates (measured)

- Clause tags exist only in the July material: `· clause-6 ·` :1875; `**[GATING clause-3]**` :2363; `**[GATING clause-4]**` :2278, :2373; section headings :2474, :2659. `clause N` occurs 30 times in the range, 21 of them in :1805-2473 and only 6 in :521-1804 (none of those 6 is a tag; they are prose at :924, :1017, :1025).
- Of the 76 NEXT rows in :521-1804: **1** mentions a clause, **3** carry a time estimate, **0** cite a `planned/` or `implemented/` path, 12 mention any `.md` file, 23 cite an issue or PR number, 7 cite a `D-nn` decision, 69 name the filing iteration in the header, 52 contain "measured", 20 use a size word ("cheap", "small").
- Priorities are rare and prose: "`#764` TO THE QUEUE HEAD as P1" :1854; "mission-infra P0" :2052; "P0, ~2.5–3d, **4** milestones" :2667.
- Estimate forms: `(R4c, 1–2d)` :2485; `~2d`, `~6–8h` :2365-2366; `Phase 1 ~38h` :2374; `LARGE ~2–3wk` :2383; `M1 2d / M2 0.75d / M3 0.5d / M4 0.75d` :619; `sized at <0.5d` :767; `~0.5–1d total` :735; "9 days, not the doc's 4" :757.

### 1e. Links (measured over the whole range)

50 PR URLs, 14 issue URLs, 23 commit URLs; 272 bare `#NNN` references on 188 lines; 78 `D-nn` references; 83 `planned/` or `implemented/` paths; 52 "sprint plan" mentions; 12 relative markdown links to `.md` files; 11 "Log entry N" pointers to the companion log (e.g. `Log entry 59` :2561). LANDED rows in :521-1804 (38): 31 cite a PR, 32 a commit SHA, 26 a judge score.

Inference: in the modern zone a queue item is a *finding record* (defect + evidence + suggested fix), filed before any design doc exists. The design-doc / sprint-plan / PR links accumulate on the row only after it is picked. The July "clause tag on every open item" discipline did not survive into August-September.

## 2. Measurements

Item detector (stated so it can be challenged): a top-level row starts at a line matching `^\*\*\[`, `^\*\*0a\. \[` or `^\d+\. \[`, and runs to the line before the next such start or a structural boundary (heading, `**RATIFIED`, `**Required-for-v1`, `*(` note). This yields **157 top-level rows** = 140 bold-bracket + 1 `0a.` + 16 numbered. 133 are in :521-1804, 24 in :1805-2700.

Not counted as top-level rows but item-like: 11 lettered sub-steps ((a) (b) (c) (c0) (c1) (d), (G1)-(G5)) inside :2067-2216; 117 design-doc classifications inside :2253-2429; 29 inline entries in the seven `### Clause 3` bullets, hand-counted: 22 ids struck through; 7 not struck, of which five are LANDED but left unstruck (the `m-ailang-fmt*` family and `m-fmt-properties-printer-roundtrip`, :2563-2633), one is PARKED (:2499) and one is GATED (:2657). Strikethrough is therefore not a reliable closed marker either.

Length in characters, header through last non-blank line:

| set | n | median | p90 | max | > 5,000 |
|---|---|---|---|---|---|
| all top-level rows | 157 | 1,530 | 3,548 | 19,377 | 8 |
| :521-1804 rows | 133 | 1,599 | 3,494 | 16,041 | 5 |
| NEXT rows | 77 | 1,495 | 2,756 | 6,139 | 2 |
| LANDED rows | 53 | 1,520 | 3,591 | 8,654 | 1 |

Mean 2,085; p95 5,041; 46 rows exceed 2,000 chars. The eight over 5,000: :615 (6,379), :618 (8,654), :746 (16,041), :782 (5,406), :1574 (6,139), :2067 (7,157), :2139 (7,569), :2220 (19,377; the re-triage container). The largest single work item is :746 `m-registry-interface-hash-blind-to-signatures` at 16,041 chars.

Share of text by status: NEXT rows 126,434 chars (39% of row text); LANDED plus partial/resolved/closed/completed/superseded rows about 151,000 chars (46%).

The charter's own counting method, quoted at :118 (outside range): "Measured at iteration 311 with `grep -cE '^\*\*\[<TAG>' design_docs/v1-mission.md`". Replicated: whole file NEXT 104, IN-SPRINT 2, PARKED 4, LANDED 46, RULED OUT 0; in :521-2700 NEXT 78, IN-SPRINT 1, PARKED 4, LANDED 38.

## 3. How an item changes over time

Observed: rows are not rewritten. They grow by three mechanisms, often combined.

**(a) The status bracket is rewritten/prepended; the body is kept.** Closed rows keep the full original filing under markers: "The original row text follows." (:840, :854, :865, :905), "Original row text follows." :928, "ORIGINAL BELOW" (:1126, :1143), "ORIGINAL FRAMING BELOW." (:1116, :1207), "ORIGINAL ROW BELOW." :1293, "original row text kept for provenance" :1763.

**(b) Dated addenda are appended inside the row.** "**UPDATE, iteration 332 — re-measured, and the disposition changed.**" :616; "**INSTANCE 2 — iter-328 …**" :670, "**INSTANCE 3 — iter-329 …**" :671, "**INSTANCE 2, iteration 310 — the bar is now MET.**" :773; "**PREMISE REFUTED, iteration 281 — …**" :1611; "**UNGATED iteration 282:** …" :1703; "⚠ **CORRECTION (this row's own prior text was WRONG …)**" :2688; "Was: …" (:2581, :2594, :2632, :2685); "Prior: …" :2178.

**(c) The old row is demoted to a separate row beneath.** `**[superseded by the row above]**` :1181 and :1209; `**[superseded]**` :1295; `**[SUPERSEDED by the four rows above, iter-277] … (original filing)**` :1705; `**[was NEXT] …**` :930.

Example of growth: `m-compile-cache-unverified-artifacts`, :618-619, 8,654 chars in two physical lines. The body is the original iteration-328/329 filing with one segment appended per iteration: "**Iteration 329: the pre-registered default fired.**", "**M1 LANDED (iter-330).**", "**M2 LANDED (iter-331).**", "**M3 LANDED (iter-332).**", each with commits, gate output and judge findings. The header was then rewritten to "LANDED COMPLETE 2026-09-06 (iter-333) — ALL FOUR MILESTONES … issue #1046 CLOSED". The body was not reconciled: it still says "Issue #1046 stays OPEN: M3 is three of four. **Resume predicate: execute M4** … the last milestone; `#1046` closes with it."

Second example: `m-registry-interface-hash-blind-to-signatures`, :746-758. Block order in the file is M5 (:747), M3 (:749), M2 (:751), M1 (:753), Design (:754), M4 (:755), Sprint plan (:757), original defect statement (:758): newest-first prepending with M4 out of sequence. :755 still ends "**M5 is [NEXT]**" while the header and :747 say M5 landed.

Third example: `m-fmt-printer-no-line-width-limit` occupies three rows: the live LANDED row :1066-1116 (which still contains "**REMAINING WORK, and the ordering is load-bearing: M2 … THEN M3**" and "the doc **stays in `design_docs/planned/`**" at :1106-1108 below a header saying SPRINT COMPLETE and :1093 saying the doc moved to `implemented/`), then two `[superseded by the row above]` rows at :1181 and :1209.

Structural damage from in-place growth (observed):

- :669-673: INSTANCE 2 and 3 paragraphs were inserted between the id and the rest of the bold title, so the header opens on :669 and its title text finishes on :672.
- :918 says "Iteration 293's superseded text follows." What follows (:920) is a different row inserted later; the superseded text now sits at :934-941, at the tail of the `[was NEXT] m-git-binary-resolution-sweep` row.
- :784 "do not re-route this row until that decision lands" survives under a header (:782) that says the row is UN-PARKED.

## 4. LANDED, PARKED, RULED OUT

**LANDED (observed).** Recorded in place by rewriting the status bracket (section 1a). Typical content: date, iteration, PR, merge SHA, judge model/score/rounds, check count, doc destination (`implemented/vX_Y_Z/`), residual work. Not pruned: the fifteen `[LANDED 2026-07-10 …]` to `[LANDED 2026-07-13]` rows at :1895-2018 are still in the file at the 2026-10-03 commit, and the first eight rows of the queue (:523-556) are all closed. The designated destination was never used: `## Done / superseded` reads "*(nothing yet — mission initialized 2026-07-10)*" (:4906-4908, outside range). The only removal rule in :501-2700 is ordering rule 5, "Anything re-scored `post-v1` in iteration 0 leaves the queue." (:519); nothing says what happens to a LANDED row. The only rotation rule seen is for STATUS stamps (:229-236, outside range: "every iteration re-reads this charter — 30+ stamps were ~500 lines of history tax per read").

A LANDED tag does not mean no open work. Five LANDED-tagged rows in :521-1804 carry open work in their text: :527-530 ("**NOT delivered — M3 … and M4**"), :590 ("**M4 is still owed** … This row stays open for M4."), :618-619 (stale "Resume predicate: execute M4"), :920 ("**M2, M3 and M4 are [NEXT] — 89 sites remain**"), :1066 (stale "REMAINING WORK").

**PARKED (observed).** Tag plus reason class, decision-ledger id, iteration: `[PARKED — needs-human-review, D-58, iteration337]` :621; `[PARKED — needs-human-review, D-57, iteration336]` :624; `[PARKED — DECISION-GATED `D-37`, adjudicated iteration 276]` :1435. Body carries a resume clause: "**Resume: human D-57 ruling → design gate → planner resynchronizes blocked plan and snapshot → M1. No runtime copy while blocked.**" :624. One parked row has no ledger id (:630, "Resume only after human disposition at the three-round cap"). Parks also live inside other rows: "PARKED for human: haiku causal re-run, API-billed" :1910; "⚠ PARKED for Mark: daemon reload + 2 live prod test-sends" :2028-2029; `[PARKED needs-human-review iter 88 — …]` :2407.

**RULED OUT (observed).** No row carries the tag. Rejections are recorded in other forms:

- Inline in a row: "**Ruled out while filing this:** … **REFUTED by timestamp**: that run finished `2026-09-07T19:59:50Z` and #1104 merged at `20:36:26Z`" :647; "Ruled out: bash 3.2 empty-array/`set -u` (`declare -a arr=(); echo "${#arr[@]}"` → `0`, no error)" :775; "**Two obvious explanations were measured and BOTH REFUTED.**" :885.
- GHOST closes with a regression guard: "~~m-dx-match-hof (R4a)~~ **[GHOST iter 25 — retired `match … with` syntax was the real culprit, … guard `examples/match_hof_lambda.ail`, PR #379 → `ea8116f83`]**" :2479-2482. Contents: reason, the probe that showed it, the guard test or example, PR/commit, iteration. Who ruled: the iteration (controller), not a named person.
- Evidence parks: "**[EVIDENCE-PARKED iter 91 2026-07-23]** `m-parser-block-let-separator` (bug REAL at HEAD but evidence gate MEASURED NEGLIGIBLE — 0 decisive occurrences in 27,359 eval files; … stays parked, do NOT route a core parser change; re-open only on a decisive rotation case)" :2315-2318. Reason, measurement, re-open condition.
- Human scope cuts, with name and date: "~~(G5)~~ **REMOVED from the gap path (Mark 2026-07-17): the qwen3-6 lane is a NICE-TO-HAVE, not a gap.**" :2204; "M-TOOLING-DETERMINISTIC **CLOSED-SUPERSEDED** by Mark" :2562.
- Bulk POST-V1 lists with a parenthetical reason each (:2291-2294, :2340, :2393-2401).
- The dedicated section `## Ruled out / resolved` (:4899-4904, outside range) holds two bullets, both July, e.g. "**Sonnet as default executor** — ruled out 2026-07-10 (Mark: corrections needed; false economy). Re-entry only via the evidence rule."
- :284 (outside range) says each log entry carries "ruled-out ledger additions", so the ruled-out ledger proper lives in the companion log, which I did not read.

## 5. Sub-structure, numbering, cross-references, dependencies

Numbering schemes coexisting in the range (observed): list numbers 1-16 plus `0a.` (:1861-2049); lettered steps (a)-(d), (c0), (c1) (:2070-2209); (G1)-(G5) (:2141-2204); R4a/R4b/R4c from an earlier strategy review (:2035-2037, :2479-2485); (R7)-(R10) (:737-740); milestones M0-M9, M1a, M1b, M1r; decision ids `D-nn`; skill rule numbers 3a-3n; clause numbers; foreign row numbers from a sibling mission ("row 39 → row 40 → item 5 → clause 4" :1025; "(row 73)" :558); legacy park labels `(0-subsum-ai)`, `(0a)`, `(a)`-`(g)` (:1485-1488); "Log entry N".

Id collisions (observed): the decision-ledger ids were reused once: "This block was written using the labels `D-31` and `D-32`, both of which were **already in use** by OPEN rows" :1839-1849. Four slug ids appear on more than one header: `m-prompt-version-freeze-on-first-bank` (three rows, one per milestone: :817, :980, :993), `m-git-binary-resolution-sweep` (:920, :930), `m-fmt-printer-no-line-width-limit` (:1066, :1209), `m-fmt-check-ail-broken-and-red` (:1500, :1705).

Cross-references (measured): only 22 of 157 rows mention the id of another row in this half (26 mentions). 126 distinct `m-…` ids are mentioned that are not a row header in :521-2700; 21 of those occur somewhere in :2701-4898. Relative pointers are common and fragile: "the row below" (:882, :913), "the row above" (:1181), "the three rows below" :1512, "the four rows above" :1705, "see queue item 16" :2441-2442, "queued below" :530.

Dependency statements (observed, all prose):

- "Do not pick this before `m-compile-cache-unverified-artifacts` lands" :661
- "**Note M3 depends on M1's migration having written BOTH registries**" :989-990
- "**Do this BEFORE M6 wires any producer that emits `U`**" :732
- "`D-39` sequences the fmt gate freeze explicitly BEHIND the width work" :1037-1038
- "`m-parmap-effectful` … M0 `EffContext.Clone()` fork-safety `22e4c11b7` is a HARD prerequisite" :2325-2326
- "**M1 and M1r are therefore inseparable and must land as ONE commit**" :882
- Chains drawn with arrows: "`#764` → world item 5 `w-mcp-projection` [BLOCKED] → world item 6 `w-agent-floor-m4` [PARKED] → World DESIGN.md M4" :1878-1879
- Tag-level: `[BLOCKED on D-39]` :1637, `[ABSORBED into PARKED `m-cache-module-id-encoding`, D-57, iteration336]` :660

Machine-readable dependencies: **none found** in :521-2700. No `depends:`/`blocked-by:` field, no table, no front matter. The nearest things: (i) the decision id inside a PARKED/BLOCKED tag; (ii) one resume predicate written as a runnable command, "Resume predicate: `gh pr view 1055 --json state` is `MERGED`, then re-read `commits/<dev-head>/check-runs` and close this row; if #1055 is still open after 2026-09-08, ask motoko" :616; (iii) a per-sprint JSON that is explicitly not the record: "the machine-readable companion is `.ailang/state/sprints/sprint_M-COMPILE-CACHE-UNVERIFIED-ARTIFACTS.json`, which is deliberately UNTRACKED because `.gitignore:82` ignores `.ailang/` — the markdown is the decision-bearing artifact" :619. The one structured store the queue points at is the decision ledger: `scripts/mission_decisions.sh --open` (:783) reads a marked `decision-ledger` block (:1841), under the rule "the marked block is state, prose is only evidence" (:1460).

Ordering (observed). Position is not priority. The first eight rows are closed; the first `[NEXT]` is :558. First-tag sequence in document order (N NEXT, L LANDED, P PARKED, S IN-SPRINT, x other):
`LxxLxLLLNNxNNNNNNxLLNNNNNxLPPLPLLNNNNNNNxNNNLNNNLNNLNLLNNNNNSNNNNNNNNLLLxxxNLNxxLNNNNNNNNLLLNNxxLNNNNNLxLLLLLLNPNNxLNNNNxNNNxNNNNxNNNLLLLLLLLLLLLLLLLLLLxxLxN`.
Filing iterations run roughly newest-first (354 at :555, 270 at :1797) with local reversals (333-340 at :615-635 after 345-354; ascending 270-275 at :1313-1402; 349 rows at :643-653 between 328 and 327). Rows themselves disclaim positional meaning: "Not prioritised above anything." :644; "Positioned by normal ordering; a sweep never outranks an existing pick." :780; "Ordering is the controller's call and reversible." :814. Inference: the reader is expected to apply the :501-519 policy to the whole set each time; "top = next" (:521) describes the July list, not the current file.

## 6. Rediscovery, re-planning, re-litigation

Observed instances:

- Stale park: "`D-47` was answered on 2026-08-28 and the queue row was never updated" :782; "iterations 305–309 all ran and none applied it, because nothing in the loop reconciles a queue row's PARK tag against the ledger row it cites" :783.
- Park lost in prose for four weeks: "**AND IT WAS ALREADY PARKED FOR MARK — IN PROSE, WHERE NOTHING READS IT.**" :1456; of 12 prose-parked decisions "**11 have ZERO representation in the ledger**" :1484; "**nothing detects a park that exists only in prose**" :1497.
- Human ruling named a queue head that was not a row: "Mark ruled this the queue head in `D-39` and it was never entered as a queue row … a ruling's *sequencing clause* can name a queue head that is not a queue row, so the ordering silently does not change" :1209-1214. Ledger D-12 (:74, outside range) records the same class: "A resolved ruling previously left a P0 doc absent from the queue for **eight days**".
- Pick-order miss: "⚠ PICK-ORDER MISS recorded: Mark's [NEXT-FIRST] below (added 13:04, pre-session) should have outranked this pick; Gate-2 read the queue head + prior log's Next but not the fresh directive." :2016-2018.
- Same defect filed twice 90 iterations apart: "Iteration 187 measured this same defect and it survived 90 iterations." :1506; "Iteration 187 measured the identical defect (400 vs 446) and filed it; it is still here" :1710.
- Same fix written three times: "the private fix had been written three times" :696.
- Work already shipped under a stale status: "M1–M3 found pre-shipped 2026-07-09 under a stale "Planned" status" :1906-1907; "mislabeled NEW-DOC — full design doc existed at planned/v0_29_0" :2040; "the NEW-DOC tag was wrong, full doc existed at planned/v0_29_0" :2494-2495; "statuses LIE" :2230. Outside range, :277-278: "stale-status docs are how we shipped M-EVAL-BENCH-UI twice".
- Queue rows that were never real: "R4a `m-dx-match-hof` and R4b `m-poly-arith-lambda` are BOTH GHOSTS" :2436; "4 of 7 historical survey-sourced rows were ghosts" :727.
- Rows whose premise a later iteration refuted: `[NEXT] [iter-294 — PREMISE REFUTED AND RE-MEASURED; the row below it is iteration 293's superseded text]` :913; "**The filed row's framing was inverted**" :1342-1343; "**The row's framing was wrong in both directions**" :1377; "**THE ROW OFFERED TWO DISPOSITIONS AND BOTH ARE REFUTED BY MEASUREMENT.**" :1445.
- Issues invisible to the queue: "Filed with **0 labels and 0 comments**, it was invisible to every sweep for six days while this loop ran eleven iterations (245–256)." :1887-1888; weekly sweeps keep finding orphans: 18 of 92 (:1233-1234), 7 of 85 (:966, :976), 5 of 90 (:780), 14 of 100 (:656), 7 of 85 (:566).
- Lookup index stale: `v1-mission-index.md` "stops at iteration 340, so the file Gate 2 calls "the cheapest way to find out whether something has already been tried" is blind to 341–346" :609.
- Lost iterations re-found from side traces: iteration 286 left "**0** charter rows, **0** log entries" :1113; iteration 352 "left zero charter rows, zero log entries and no slot verdict" :552.

Text written to prevent it (observed):

- "**GHOST DISCIPLINE ATTEMPTED AND IT DOES NOT REPRODUCE IN THE TWO OBVIOUS SHAPES** — recorded so the next iteration does not re-buy the easy half." :727
- "**The row's REMAINING plan is REFUTED and must not be re-run as written.**" :1507
- "do NOT re-quorum — the two rounds + resolved authorial decision ARE the quorum outcome" :2101-2102
- "Stop re-asking." :1809
- "**THIS IS NOT `#498` RE-OPENED, AND THAT DISTINCTION IS THE WHOLE ROW.**" :1881; "**This is NOT `m-message-watcher-windows-wallclock-flake`** (landed iter-318)" :540; "Distinct from `m-ratelimit-window-default-unpinned`: …" :570
- "No implementation has landed; do not pick this separately." :660; "**Verify, do not adopt.**" :592
- "Left uncorrected, this would have made the loop re-ask `D-31`/`D-32` hours after Mark answered two different questions wearing those labels." :1848-1849
- Evidence thresholds that stop premature policy edits: "Two instances is below the ≥3-evidence bar for a policy change, so this row records the measurement rather than proposing a guard" :525; `[PRE-REGISTERED — instance 1 of 2 recorded; the SECOND instance is the Gate-5 skill-edit trigger, do not spend the budget before then]` :681.
- Standing procedures referenced: "ghost discipline" (live repro at HEAD before routing; :558, :727, :780, :968); the weekly orphan sweep (:566, :655); Gate 2 grepping the index (:609).

## 7. Items about the planning and documentation system itself

Charter, queue, ledger, log, index:

- `m-mission-index-stale-since-340` [NEXT] :609: the iteration index stops at 340; it is regenerated wholesale by `ailang mission rotate-log` and "must never be hand-appended".
- `m-prose-parked-decisions-orphaned` [NEXT] :1480: 11 of 12 pre-ledger prose parks have no ledger row; nothing detects a prose-only park.
- `m-openrouter-session-chain-registration` [NEXT — UN-PARKED] :782: carried here because its header documents the unreconciled PARK tag vs ledger.
- `m-make-ci-red-ai-modes` [PARKED D-37] :1435: a decision parked in prose "WHERE NOTHING READS IT" for four weeks.
- Weekly orphan-issue sweep rows: `m-weekly-sweep-orphans-2026-09-14` :566, `sweep-2026-09-07-orphan-issues` :655, `m-weekly-sweep-orphans-2026-08-31` :780, (no id) external-issue orphan batch :966, `m-weekly-sweep-orphans-2026-08-26` :1233. Each lists open issues with zero mentions in charter, log, archives and dashboard.
- FULL BACKLOG RE-TRIAGE [completed iters 85-87] :2220: sweep of all `planned/` folders (about 114 docs), each tagged GATING / CYCLE / POST-V1 / GHOST / FOLD-INTO.
- PORTABILITY M2+M3 [LANDED iter-92] :2218: `## Repo Profile` block, charter header, `design_docs/mission-charter-TEMPLATE.md`, public bootstrap guide.
- LABEL CORRECTION block :1839-1849: decision ids reused; ledger declared authoritative.

Skills and rulebook:

- `m-quorum-absent-reviewers-key-does-not-exist` [NEXT] :772: the mission-control skill tells controllers to read a JSON key the artifact never writes.
- `m-acceptance-criterion-green-at-base` [NEXT, pre-registered] :681: rule 3e(a) is silent on a criterion green before and after.
- `m-resolver-hook-disagree-on-docless-pick` [NEXT] :669: the lane resolver requires a `planner_lane` field "only **2** design docs in the entire repo carry".
- `m-spawn-pin-enforcement` [LANDED] :687: model-pin enforcement moved from skill prose to a hook because "advisory text gets skipped — this has been measured".
- `m-skills-parity-no-ci-gate` [NEXT] :1274: `.claude/skills/` and `.agents/skills/` diverge while `make check-skills` stays green.
- `m-sonar-vs-gocognit-instrument-mismatch` [NEXT] :606: proposes that every metric written into a doc, plan or log name its instrument inline.
- `note-pi-executor-30-min-cap-vs-milestone-size` [PROCESS FINDING] :564: executor wall clock smaller than a plan-sized milestone, three instances; skill edit landed.
- `note-attended-landing-collided-with-a-live-mission-item` [PROCESS FINDING] :586: a human session landed a competing fix mid-iteration.

Context size:

- `m-release-manager-skill-split` [NEXT] :678: a SKILL.md grew 596 → 625 lines past its `check-context-docs` baseline and turned `dev` red; owes a split and a down-ratchet.
- `m-gate1-shared-clone-ref-drift` [LANDED iter-338] :627: records that the mission-control `SKILL.md` baseline "is **2781**, exactly its current size, so any addition must first pay for its space by restructuring".
- `m-fleet-sha-pin-freezes-every-driver-fix` [RESOLVED] :544-547: `SKILL.md` and its twelve `resources/*.md` resolved from different checkouts, so the loop "nearly followed stale rules"; one resource file measured 78,390 B.

Loop machinery (driver, notices, lanes; adjacent to the above):

- `m-gate0-self-crash-notice-read` [NEXT] :558: a slot killed mid-flight leaves a notice no gate reads.
- (no id) four driver defects (R7)-(R10) [NEXT] :735: R7 = the driver's late-kill record detector reads the mission log from a worktree that never updates.
- `m-pin-root-redirects-de-forked-mission` [NEXT] :599: driver relocates a sibling mission into the wrong repo; its mission doc is not found.
- `m-v1-lane-degraded-notices-never-deliver` [NEXT] :649; `m-drain-deferred-counter-overcounts` [NEXT] :652; `m-launchd-drain-aggregate-budget` [LANDED, M4 owed] :590; `m-launchd-notify-subshell-observation` [LANDED M1+M2 of 4] :527; `m-pin-drift-blind-under-sha-pin` [LANDED] :555.
- `m-pi-runner-worktree-assertion-vacuous-on-revision` [PARKED D-58] :621; `m-pi-runner-shell-suite-coverage` [PARKED] :630; `m-pi-evaluator-session-handshake` [LANDED] :632.
- `m-mission-agentic-provider-routing` [LANDED / M3 parked] :2051; FLEET ROLLOUT sub-queue :2067 including `m-mission-quorum-agentic-verify` (design-quorum reviewers become tool-using agents) :2088; GAP CLOSURE sub-queue :2139.

Observed remark worth carrying, :658: "Eight of the eleven are defects in the mission loop's OWN machinery … They are exactly the class this loop is best placed to fix and worst placed to notice, because they arrive as issues rather than as reds and nothing routes them into the charter."

## 8. JUDGEMENT: can a program extract the ordered list of open work?

Labelled as judgement throughout.

**No, not reliably.** A regex can produce a list of row headers and their first tag, and for the :521-1804 zone that list is a fair approximation of the *set* of open rows (the charter itself counts this way, :118). It cannot recover the *order*, and the set has errors in both directions. What breaks it, each observed in this range:

1. **Order is not encoded.** Document position is filing locality, not priority (section 5). Priority comes from applying the six-rule policy at :501-519, whose inputs (bar clause served, P-level, what an item unblocks, impact-per-day, estimate) are present on almost no modern row (1/76 clause, 3/76 estimate). A program has nothing to sort on.
2. **Tag vocabulary is open.** 22 of 157 rows lead with an undeclared tag; one declared tag is never used. `[APPROVED by D-50 BUT BLOCKED …]` :881, `[BLOCKED on D-39]` :1637, `[LANDED-IN-PART … | REMAINDER DECOMPOSED]` :1500 need reading to classify.
3. **LANDED rows contain open work** (:527, :590, :920) and **closed rows contain stale "next" text** (:619 "Resume predicate: execute M4", :755 "M5 is [NEXT]", :1106 "REMAINING WORK"). Header and body disagree; neither is safely authoritative.
4. **Tags go stale against the ledger.** :782-783 is the charter's own proof. :1637 is tagged `[BLOCKED on D-39]` while :1218-1219 says "`D-39` also UNBLOCKS `m-fmt-typedecl-printer-needs-multiline-emit`" and the body (:1651) names `D-38`; I could not determine its true state from the text.
5. **`[NEXT]` appears where it does not mean an open item.** :1209 is `**[superseded by the row above]** **[NEXT] …**`; :2431 `**[NEXT]**` is a group header over narrative; :2067 `[NEXT-FIRST …]` heads a sub-queue whose steps are mostly struck through. The charter's `^\*\*\[NEXT` grep counts the last two as open rows; a looser `\[NEXT\]` match counts the first.
6. **Open work lives below row level:** lettered sub-steps, unfinished milestones (M4 at :590, M2-M4 at :920, Sprint 2 M6-M9 at :746), inline clause-section entries (e.g. the PARKED `m-parser-block-let-separator` at :2499 and the GATED prompt-diet entry at :2656-2657 are bullets, not rows), and "PARKED for human" clauses inside LANDED rows (:1910, :2028).
7. **Ids are not a key.** 10 rows have none, 2 use an issue number, 2 carry the id outside the header pattern; 4 ids head several rows; ids are backticked in one zone and bare in another; brackets mention other ids before the row's own (:660 names `m-cache-module-id-encoding` before its own id; :694 names `M-COMPLETION-PATH-PARITY`). My first id extractor picked the wrong id on :694 and invented one for :735.
8. **Row boundaries are damaged:** split header at :669-673; displaced "superseded text follows" at :918/:934; rows with a blank line inside the body (:760-764); rulings interleaved with rows (:1805-1859).
9. **Encoding drift:** `&mdash;` (439 occurrences) and `—` (492) are both in use as the tag/title separator; ids with and without backticks; three header syntaxes.
10. **Size.** This half alone is 355K characters; a reader, human or model, cannot hold the whole queue while picking, which is the condition under which items 3-5 arise.

The project reached the same conclusion about itself. Ledger D-51 (:118, outside range) replaced "open queue rows" as the progress unit because it "is anti-correlated with good work", and declined to record a starting number "because clauses 3 and 4 are prose with strikethrough history and need the classification pass this row asks for".

What did work, and is the contrast to draw (inference): the decision ledger. It is a marked block with one row per id, a status column and a script (`mission_decisions.sh --open`), under the rule "the marked block is state, prose is only evidence" (:1460). Every failure listed in section 6 that involves a decision was caught by comparing queue prose against that block. The queue has no equivalent block, so the same class of drift in the queue is found only by an iteration happening to re-read the right row.
