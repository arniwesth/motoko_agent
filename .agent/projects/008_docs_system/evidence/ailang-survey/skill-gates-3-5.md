# AILANG mission-control: gates 3, 3b, 4, 5 and the verification protocol

Source: sparse clone of `sunholo-data/ailang` `dev` at `2a1f3f295` (2026-10-03).
All paths below are relative to `.claude/skills/mission-control/resources/` unless prefixed.
Abbreviations: `g3` = `gate-3-route.md`, `g3b` = `gate-3b-ci-green.md`, `g4` = `gate-4-record.md`,
`g5` = `gate-5-retro.md`, `vp` = `verification-protocol.md`, `SKILL` = `../SKILL.md`.

Convention in these notes: **OBS** = stated in the text at the cited line. **INF** = my inference.
Quotes are verbatim. "Iteration N" is the mission's own iteration counter (mostly the "V1" mission).

---

## 0. Shape of the source files (OBS)

- Every gate in SKILL.md is a stub that points at a resource file: "THE FULL RULES FOR THIS GATE ARE
  NOT IN THIS FILE ... this stub is an index entry, not a summary you may act on. Skipping the read
  is how a gate's rules silently stop applying." (SKILL:239-242, repeated per gate 248-296).
- The resource files are not structured specs. They are accreted incident notes: a short base rule,
  then bolded `⚠ ...` paragraphs each stamped "(added YYYY-MM-DD <mission> iteration N; instance
  count)", each ending "Mission-independent: ..." and "The tell: ...". Line 17 of g3 is a single
  table cell of 2,189 words (14,291 characters, my measurement) carrying six dated amendments of
  one routing row (2026-08-26, 08-28, 09-05, 09-22, 09-25, 09-30) plus two dated incident notes
  (08-13, 08-22), newest first, each older one kept "as history".
- Dated amendment stamps per file (my grep count of "(added|fixed|generalised|amended|stamped
  YYYY-MM-DD"): g3 14, g3b 9, g4 7, g5 1, vp 41. Lower bounds: stamps phrased differently are not
  counted.

---

## 1. Gate 3 — ROUTE + EXECUTE (g3, 857 lines, read in full)

### 1.1 What the file is mostly about (OBS)

About 80% of g3 is routing: which model runs which role, spawn recipes per provider, fallback
chains, sandbox recipes, metering. The stage-to-stage contract is a small part (g3:521-746).

### 1.2 Roles and the independence rule (OBS)

- Four heavy roles, each spawned as a model-pinned sub-agent, "never inline": designer, planner,
  executor, evaluator; the controller session does triage/pick/judge/retro (g3:5-12, table 14-20).
- Origin: "Running every role on the controller's single session model is the
  routing-never-enforced bug: with the driver on Fable, 100% of every iteration billed Fable (fixed
  2026-07-15 ...)" (g3:5-8).
- Role-to-spawn mapping is by script, not judgement: `tools/launchd/resolve-role-spawn.sh <role>`
  prints one line `<path> <value> <reason-token>`; "do not second-guess it" (g3:57-61). `refuse`
  outcomes are "a routing FAILURE, not a FLAG: record the reason token VERBATIM and continue the
  iteration without the role" (g3:63-64).
- Every role prompt must begin `MISSION-ROLE: <designer|planner|executor|evaluator>`; "that token
  is the ONLY input the spawn-pin hook uses ... an unlabelled Agent/Task call is DENIED at the tool
  boundary" (g3:78-82). This is hook-enforced.
- generator != judge is "a PREFERENCE, never a blocker" (g3:242-254), restated by the owner
  2026-10-01: "its a nice to have, not to wet our pants if we dont have different operators
  available". Step-down is same model in a fresh context, FLAGGED with
  `judge-independence: cross-vendor | same-model-fresh-context` (g3:246-248). "No step blocks a
  landing." (g3:251-252).
  - But: "the evaluator role never falls back to bare `$MODEL`" — compare the resolved evaluator
    model against what the executor actually ran on; if equal, re-route. "A degraded-but-independent
    judge beats a same-model judge." (g3:509-514).
- Designer must not also be a quorum reviewer of its own doc: rule (c) "Never route a designer to a
  model that is also one of this doc's quorum reviewers" (g3:17). Origin: `codex:gpt-5.6-sol` was
  both rotation designer and quorum reviewer `gpt5-6-sol`, "so a codex-authored doc was judged by
  its own author" (g3:17, the 2026-08-26 entry). Since 2026-09-25 `design-quorum --author` benches
  the author's vendor (g3:17).

### 1.3 The inner-loop contract, stage by stage (OBS)

Dispatch is by what already exists (g3:521, 586, 588, 683):

| State | Stage run | Hand-off required |
|---|---|---|
| No design doc | design-doc-creator on the rotation designer | a design doc that passes the quorum (Gate 2); `(designer, quorum outcome)` recorded in the evidence row (g3:17). First `grep -ri "<item-id>" design_docs/` — "a NEW-DOC queue tag is a claim, not a fact" (g3:525-529; "2 of 2 recent NEW-DOC tags were wrong", iters 25, 26). |
| Doc, no plan | sprint-planner | "sprint JSON + handoff" (g3:586-587). For a codex planner the controller asserts both artifacts exist and are well-formed (`jq -e . sprint_<id>.json`; "plan non-empty and names the design doc"), and rejects "placeholder vacuous-passes (`MILESTONE_ID` or `auto-parse failed`)" (g3:235-237). |
| Plan exists | sprint-executor in an isolated worktree | An UNCOMMITTED worktree diff. The sandboxed executor cannot commit; the controller reads `git diff`/`git status`, verifies, and builds the commits itself, crediting the executor (g3:192-198). Multi-milestone: executor snapshots each milestone into `.snap/M<k>/`; controller rebuilds one commit per milestone, runs the package tests at every boundary, and proves byte-identity with a sha256 manifest (g3:199-213). |
| Execution complete | sprint-evaluator, own worktree | a verdict; see 1.4 |

What the designer must hand over (the hardest-won part):
- "THE DESIGNER DIRECTIVE MUST DEMAND A VERIFICATION ROW PER CODEBASE CLAIM — a cross-provider
  designer CANNOT READ THIS REPO'S SKILLS, so any gate you leave implicit does not exist for it"
  (g3:530-532, added 2026-07-31 iteration 126). The doc was blocked at quorum twice on unverified
  "the codebase currently does X" sentences; one measured better than assumed, one measured false
  ("zero matches, known-positive control firing") (g3:535-541).
  - (a) every such sentence "needs a Verification Log row with the command AND its observed
    output", and "an empty or negative result is a CLAIM, not a fact, so it needs a known-positive
    control in the same call" (g3:543-546).
  - (b) on an "unverified premise" objection the controller runs the check itself and "hands the
    designer the measurement rather than the objection — otherwise the designer re-asserts and you
    buy a third round" (g3:547-549).
  - (c) "if two rounds block on this same class, name the PATTERN in the revision directive";
    doing so on round 3 "got 21 verification rows" (g3:550-551).
  - "for them the directive IS the gate" (g3:553).
- Design docs for a tool that parses another tool's output must require generated fixtures
  (g3:555-584; see false-green catalogue, FG-G3-1).

What the planner must hand over: milestones sized so they fit the executor lane. "a planner that
sizes a milestone above ~250 LOC should cut it" (g3:413-414). Multi-week items are not executed:
"the iteration's deliverable is DECOMPOSITION into sprint-sized design docs (≤3–4 days each)"
(g3:856-857).

What the executor's report is worth: nothing on its own.
- "a gate verdict from inside the sandbox is not evidence — it invents failures AND hides real
  ones" (g3:179-180).
- "`rc=0` FROM pi IS NOT A CLAIM THAT ANY WORK HAPPENED — AND NEITHER IS `stopReason`" (g3:381-382).
  "The load-bearing assertion is the worktree diff" (g3:442-443). `stopReason` "fired on 0 of 4
  real failures" (g3:441-442).
- "It also does not make executor-reported greens bankable — the controller re-runs the gates
  (generator≠judge)." (g3:365-367).
- Directive delivery is asserted before spawn: file exists, >= 200 bytes, non-empty, else `exit 64`
  (g3:154-160). Reason: an absent directive "makes the prompt expand to "", codex asks "What would
  you like me to work on?" and exits rc=0 — success reported for work never requested" (g3:154-156).

### 1.4 The evaluator (OBS)

- Base rule, complete text: "Execution complete → sprint-evaluator as a
  `$MISSION_EVALUATOR_MODEL`-pinned Agent sub-agent (distinct from the executor model →
  generator≠judge). Max 3 rounds; on round-3 fail → `needs-human-review`, park, message
  controlplane." (g3:683-685).
- **Rounds: maximum 3.** On a round-3 FAIL: mark `needs-human-review`, park the item, message the
  controlplane inbox. g3 does not say what happens on a round-1 or round-2 FAIL beyond implying a
  fix and a re-spawn ("the thing the controller writes *between* rounds", g3:714-715). INF: the
  controller (not a re-run executor) often applies the fix between rounds — g3:721 says "a 3-line
  production hunk the controller had itself shipped in round 1".
- **What the evaluator judges against** — g3 does not define a rubric. It names the inputs the
  directive carries: "task-specific design and plan paths, reviewed commit, isolated evaluator
  worktree, verification commands, mutation matrix, and report path" (g3:496-497) and classifies the
  task as "independent evaluation under the supplied approved design and sprint plan" (g3:489).
  The judge is told to re-run named mutations (rules 3h(c), 3i, 3j of the verification protocol;
  g3:691-692). The rubric itself lives in the `sprint-evaluator` skill, which I did not read.
- Non-vacuity is per milestone: "non-vacuity is measured against the MILESTONE's own production
  diff, never the sprint's ... Put it in the evaluator directive; a judge handed the whole sprint's
  diff will measure against the whole sprint's diff." (g3:746; rule 3o, added 2026-09-06). This
  sentence is duplicated verbatim in the file — an editing artifact.
- **The judge gets its own worktree** (g3:686-707, added 2026-08-14 iteration 199). A good
  evaluator mutates source. Two failure modes: "(a) The controller misreads the judge" — iteration
  198's evaluator mutated a file mid-run and "the controller's gate surfaced a transient FAIL it
  nearly attributed to the code"; "(b) The judge destroys the work. Sprint output is uncommitted by
  construction, so one `git checkout --` in the judge's restore step deletes the milestone".
  "neither instance produced a wrong VERDICT, which is why this survived two iterations". While any
  judge runs: "never `git add -A`: stage named files, because the tree is not yours alone."
- **Round 2+ directive is itself an instrument** (g3:709-746, added 2026-09-01 iteration 316).
  "the round-N directive is written *about a tree you have just changed*". Two measured cases: an
  omitted 3-line hunk in the "what changed" list; a mutation red set quoted as two tests when the
  tree now had three ("STALE, not wrong"). Rules: (a) re-run every measurement the new directive
  quotes on the tree the judge will see; (b) "Derive the "what changed" list from `git diff`, never
  from memory"; (c) date any measurement that cannot be re-taken and name its tree; (d) "A judge
  that contradicts a number in your directive is the loop WORKING"; (e) carry forward the previous
  round's findings by name — "a finding silently dropped between rounds looks identical to one that
  was fixed."
- A pi evaluator whose handshake fails "stops the attempt and enters the existing fallback chain;
  it never becomes PASS or FAIL" (g3:497-499). Transport failure is kept distinct from a verdict.

### 1.5 Bounded-ness rules inside gate 3 (OBS)

- Every run is wall-clock bounded: 30-minute cap on executor runs (g3:161), 120 s on probes
  (g3:132). Cap is "a per-run parameter, not a constant": `--max-seconds 3600` for a milestone
  estimated above ~150 LOC or carrying a mutation drill; "Never `0`, never unbounded" (g3:405-409).
  Origin: three `wall_timeout` instances, iterations 347 and 354, where the fallback chain was
  handed "the SAME milestone under the SAME cap" (g3:393-404).
- Fable (the expensive model) budget: "one design DOC per iteration: the initial authoring run plus
  at most one protocol-mandated revision run" (g3:45-47). Changed from one *run* after three
  iterations (228, 229, 255) each recorded a violation: "An apology repeated three times is a rule
  that is wrong, not a controller that is careless." (g3:44).
- Metered spend: per-iteration tally, default ceiling `$MISSION_METERED_BUDGET_USD` = $5; "BEFORE
  each metered call: if tally + estimated-cost > [budget], do NOT make the call" (g3:748-753).
  Quorum cap $0.10 per reviewer (g3:753). A tight directive is "~12× vs exploratory ($0.07 vs
  $0.87)" (g3:755-756).
- Worktrees: never under `/tmp` (g3:634-651, iterations 127 and 133: two tests fail from `/tmp`
  and pass elsewhere, "the only variable is location"); never a bare `git worktree add` (g3:615-616,
  652-682: 23,796 files, ~2 minutes, exceeds the foreground tool limit; an interrupted add shows
  23,835 staged deletions). Iteration 234 "ran `pgrep`, which printed the owning `git worktree add`
  alive with its PID, wrote "owner process confirmed dead", and removed the lock anyway"
  (g3:666-668). Docs iteration 17 (2026-10-01) "read 25,786 staged deletions from a tree git was
  still checking out" (g3:624-626). Now wrapped in `mission-worktree.sh add|wait`, "park, never
  repair" (g3:615-621).
- Worktree base is re-measured before creation; a sibling's fetch can move `origin/dev` silently
  (g3:591-632; detail in `ref-drift.md`, not read).

### 1.6 Who can change routing (OBS)

- "Do not "upgrade" a role to Fable ad hoc; that is a routing-policy change requiring the charter's
  evidence rule." (g3:26-27).
- "a routing-policy change needs ≥3 evidence rows (Gate 5 step 2)" (g3:17). The loop recorded two
  instances and explicitly did not change the rotation: "it records the measurement so the third is
  recognisable rather than rediscovered" (g3:17).
- "The ≥3-evidence-rows rule in Gate 5 step 2 binds the LOOP changing policy on its own, not an
  attended human ruling — two flagged instances plus Mark's decision close it." (g3:17).
- Some changes need a human regardless: the rotation fix "needs a human, because it is a
  routing-policy change on a shared file" (g3:52-53). A spend-policy change "is its own attended
  ruling, not a side effect of a model swap" (g3:17).

### 1.7 Telemetry written during gate 3 (OBS)

- One chain per iteration: `ailang chains post-iteration` with an `IterationPost` JSON, `|| true` —
  "telemetry NEVER blocks the loop" (g3:760-780). Every stage carries a real `status`. "Do NOT
  blanket-post `completed` ... the CLI has a regression test whose entire job is to block that
  shortcut." (g3:826-828).
- Measured defect that produced the rule: on `mission:v1/iter-190` four stages all read `pending`,
  two quorum stages recorded "$0.0570/$0.0507 at ZERO tokens", chain total "$0.0000 against $0.1077
  actually spent" (g3:797-801).
- Quota lanes post `quota_tokens`, not `tokens_in/out`. "4,979 quota stages recorded zero tokens by
  design", so nobody could answer how much of the codex bucket was spent, "the reason half a codex
  bucket went in a single day" (g3:790-793).
- Spool is bounded: "≤100 entries / 1 MiB, drop-oldest, stderr-LOUD" (g3:838).
- Dead lanes are recorded with `mission-lane-dead.sh <role> <lane> "<evidence>"`; "The helper
  refuses undeclared lanes and empty evidence" (g3:71-76).

### 1.8 False greens named in gate 3 (OBS) — carried into the catalogue in section 5

- Five codex-lane false greens, one line each at g3:177-184; full text moved to
  `codex-lane-false-greens.md` on 2026-09-04.
- Secret leak via `${VAR:+YES}${VAR:-NO}` (g3:186-189): "World leaked `OPENAI_API_KEY` into a
  transcript this way."
- Billing masquerade (g3:279-291): a nested bare `claude -p` billed the metered API; the monthly-cap
  error "MASQUERADES as OAuth-Fable exhaustion" — the 2026-07-16 "Fable quota-exhausted until
  2026-08-01" finding was this.
- pi lane: NDJSON size guard killed runs at ~7,000 reasoning tokens; 7,130 reasoning tokens made
  330 MB (g3:424-431). "The runs did not fail on their own — WE killed them".
- `tool_hang` misread as `stream_dead` (g3:454-458): every World iter-208 "deepseek stream_dead" was
  `ailang messages list` hanging inside the sandbox.
- Hand-typed parser fixtures (g3:555-584).

---

## 2. Gate 3b — CI GREEN (g3b, 430 lines, read in full)

### 2.1 What LANDED requires (OBS)

- Title: "an item is not LANDED until remote CI passes on its merge" (g3b:1).
- The operative sentence: "Only an OBSERVED green run upgrades the queue tag to [LANDED]."
  (g3b:303).
- Conditions, assembled from the file:
  1. A remote CI run **for the exact SHA that was pushed**. The poll target is the full 40-char SHA
     from a recorded read (`mission-base.sh record gate3b`), "never `--limit 1`" (g3b:16-18).
  2. The run has **completed** with success — observed, not predicted. "a timed-out wait is NOT
     green" (g3b:300). "an armed auto-merge is a *prediction*, and Gate 3b's whole discipline is
     that a prediction is not an observation" (g3b:329-330).
  3. The check **set is complete**: every workflow EXPECTED for this diff is PRESENT, else print
     `INSTRUMENT INCOMPLETE — no verdict` (g3b:117-119). "a count of what you found is not a count
     of what exists" (g3b:119-120).
  4. The counts that are compared are **numbers**: a non-numeric reading is "`INSTRUMENT FAILURE —
     not a verdict`, never ... a value" (g3b:146-147).
  5. The run came from the **right event**. A `workflow_dispatch` green "does NOT clear a
     conflicting PR and must never be quoted as the item's CI evidence" (g3b:422-423); branch
     protection is gated on the PR's `pull_request` check suite (g3b:245-246).
  6. `mergeable` read "on the head you are polling, at the moment you are polling it" (g3b:417-418).
  7. Confirmed by a direct per-workflow read after the poll: "the poll's output is a HINT, never
     the verdict" (g3b:285-287).
  8. Local greens do not substitute: "Local `make test`/`make lint` do NOT cover the remote-only
     gates (fmt-check, govulncheck, check-file-sizes, docs build)." (g3b:300-301).
- Wait is bounded: 30-minute cap; "CI is ~15-20m — never open-ended" (g3b:32). On timeout "do NOT
  keep waiting: park the item `needs-human-review` with the last status and report" (g3b:299-300).
- On red: "fix-forward immediately if small; otherwise revert the merge and park the item with the
  CI log excerpt." (g3b:302-303).
- Path-filtered workflow with no run is "N/A, record it as such — not pending" (g3b:352).
- A red must be attributed with a negative control before fixing: "the same check red on your PR
  and green on the last N `dev` commits is yours; red on both is inherited and is a queue row, not
  a blocker" (g3b:72-74).
- During a declared provider incident, a green is unattributable too: "A green during an incident
  licenses a code inference ... and never an infrastructure one" (g3b:270-271). "Close an incident
  on the provider's status API, not on one of your own runs" (g3b:271-272).

INF: LANDED is entirely observation-based and the observation is hand-run shell. Apart from
`mission-base.sh` (records/compares the SHA) nothing in g3b is a script that decides LANDED; the
verdict is the controller's, and the file's length is the cost of that.

### 2.2 Recorded cases where LANDED / green / parked was called wrongly (OBS)

Each of these is an incident the file cites as the origin of a rule.

| # | When | What was reported | What was true | Mechanism | Line |
|---|---|---|---|---|---|
| 1 | iter 13, 2026-07-12 | (nothing — hung) | wedged 4h until the 6h driver watchdog | unbounded `until COND; do sleep 30; done` | g3b:7-9 |
| 2 | World iter 33 | `completed failure` | landing was green ("a red verdict for a green landing") | `--limit 1` watched the previous commit's run | g3b:89-90 |
| 3 | V1 iter 115 | TIMEOUT | landing was green | sibling merge outran the unpinned poll | g3b:90-91 |
| 4 | iter 107 | `TIMEOUT ... — PARK` | own last line read `completed success <target-sha>` | hand-rolled `set -- $res` multi-workflow poll | g3b:280-282 |
| 5 | iter 107 | `INCOMPLETE` for two jobs | both had reported | associative-array tracker whose writes did not persist | g3b:278-280 |
| 6 | iter 153 | "0 failures observed" | 1, then 2 within minutes | aggregate over an in-flight run | g3b:110-111 |
| 7 | iter 154 | `pending=0 failures=0 SETTLED` | list of ONE row where 18 existed minutes earlier; all four workflows queued | `rerun-failed-jobs` empties the `check-runs` collection | g3b:112-116 |
| 8 | iter 233, 2026-08-20 | `ALL COMPLETE` | three runs still `in_progress` | local `jq` died on a control character; both counts empty; `[ "" = "" ]` is true | g3b:137-141 |
| 9 | iter 155 | `total=0` runs | 5 runs existed | 9-char SHA passed to `head_sha=`; endpoint returns empty set, HTTP 200 | g3b:170-174 |
| 10 | iter 243, 2026-08-21 | control agreed: "platform-wide outage" | control SHA was hand-typed and matched no commit; real value 3 | fabricated 40-char control SHA | g3b:180-198 |
| 11 | iter 155/156 | PR "unblocked" via `workflow_dispatch` | 4 required contexts green on the SHA, PR still `BLOCKED` | dispatch checks do not satisfy branch protection | g3b:242-248 |
| 12 | iter 155 | run "created" | `queued` with `jobs=0` seven hours later | created run is not a running run | g3b:234-237 |
| 13 | motoko iter 9/10, 2026-08-18 | iteration ended looking successful; auto-merge armed | PR #760 never merged; `test=failure` 12h13m later | auto-merge over a base-inherited red; GitHub does not re-run checks when the base advances | g3b:305-327 |
| 14 | same | PR body blamed step "Check changelog index hygiene" | that step was `skipped`; real failure was step 14 | read the check name, not the failing step | g3b:336-343 |
| 15 | iter 30 | (burned the full 35-min cap) | conflict-skipped PR suite could never complete | polling a check that cannot complete | g3b:347-348 |
| 16 | iter 31 | poll demanded a Docs-Deploy run | path filter guaranteed none | same class | g3b:348-349 |
| 17 | iter 198, 2026-08-14 | diagnosed dropped webhook, ~15 minutes | PR was `CONFLICTING`/`DIRTY` | loudest rule in the file biased the diagnosis | g3b:369-377 |
| 18 | iter 347, 2026-09-07 | clean 8-job green from `workflow_dispatch` | PR was `CONFLICTING`; the `MERGEABLE` reading was taken at 14:00Z and relied on at the 15:05Z push | banked `mergeable` reading expired after a sibling merge at 14:15Z | g3b:407-416 |
| 19 | iter 351, 2026-09-08 | all local gates green | `golangci-lint unused` red on PR; SonarCloud `new_coverage` 78.8% vs 80 | local sweep was package-scoped; coverage gate is a GitHub App | g3b:51-67 |

Case 13 is the cleanest "called landed and was not": "success reported for work that never
shipped" (g3b:320-321); "the iteration ends looking successful and the mission's memory simply
skips a number" (g3b:319). The stated real failure was the record, not the PR: "the failure here was
not the unmerged PR, it was that the charter's newest stamp read one iteration behind with nothing
explaining why" (g3b:335-336).

### 2.3 Rules worth lifting (OBS)

- "a remedy is an instrument too, so when this file prescribes a comparison, the comparison's own
  failure modes become the rulebook's problem" (g3b:158-160).
- "an instrument that takes an identifier can be voided by the identifier's FORMAT" (g3b:225-226).
- "When a control returns the SAME reading as the thing it is controlling for, treat that as
  *suspect before it is corroborating* — a control exists to DIFFER" (g3b:204-205).
- On the rulebook itself: "when a gate accumulates a long, vivid war story about an uncommon cause,
  the common cause needs re-promoting, or the documentation itself becomes the bias" (g3b:391-393).
  Measured: "`workflow_dispatch` now appears 6 times in this file against one operative mention of
  `CONFLICTING`" (g3b:364-365). "Prominence is not evidence, but it is what you reach for first."
  (g3b:367-368).
- Iteration 347 is "the first time the rule existed and was still missed" (g3b:400). INF: this is
  direct evidence, from the project's own record, that adding prose rules to a gate file does not
  reliably change behaviour; the fix proposed is "in code, not in memory" (g3b:420).

---

## 3. Gate 4 — RECORD (g4, 332 lines, read in full)

Title: "append-only; the log is the mission's memory" (g4:1).

### 3.1 Every write at the end of an iteration (OBS unless marked)

| # | Artifact | Path | Required format | Mode | Checked by a script? |
|---|---|---|---|---|---|
| 1 | Heartbeat stamp | via `tools/launchd/mission-heartbeat.sh stamp gate-4` (g4:61) | n/a | script | **Script** writes it. |
| 2 | Dashboard | `design_docs/${MISSION_NAME}-mission-dashboard.md` (g4:63) | "Keep it ≤40 lines, OVERWRITE never append: latest release · in-flight/next picks · loop cadence+routing · parked-on-Mark · quota posture. It is a snapshot, not a record" (g4:65-67). Written FIRST. | overwrite | **Trusted.** No checker named in g4. Measured in the clone: v1 39 lines, docs 19, fleet 14, **motoko 58** (over the cap). |
| 3 | Log entry | `design_docs/<name>-mission-log.md` ("`v1-mission-log.md`" hardcoded at g4:94) | "its fixed template — every section, "none" over omission" (g4:94-95). Template (read from `design_docs/v1-mission-log.md:6-21`, outside my assigned files): headline `## N — YYYY-MM-DD — <headline>` then `**Picked**`, `**Reality check**`, `**Shipped**`, `**Routing evidence**`, `**Ruled out**`, `**Retro lane**`, `**Next**`. Gate 5 adds a trailing `[CLASS]` tag on the headline and a `**Progress**:` line (g5:128-131). | append | **Partly.** `tools/mission-weekly-report.py` parses `[CLASS]`, `**Progress**` and `**Next**` (g5:129-130) — a parser, not a validator. No template validator named. |
| 4 | Routing-evidence row (inside the log entry) | same | Must carry: actual `(role, model)` per role (g3:515-517); per-role token count, "`(tok: not reported)` rather than omitting the role" (g4:5-16); `base=<sha>@<iso>` with "the full 40-character SHA" from `mission-base.sh record gate4` (g4:200-201); `metered=$X.XX` (g3:758); `(designer, quorum outcome)` (g3:17); reason tokens "VERBATIM" (g3:63-64, 104); `judge-independence:` flag (g3:247-248). | append | **Mostly trusted.** `mission-base.sh` produces the base value; whether the row contains it is not checked by anything named here. |
| 5 | Ruled-out ledger (inside the log entry) | same | "hypotheses/approaches refuted this iteration — the anti-re-chase ledger" (log template line 18) | append | Trusted. |
| 6 | Log rotation | `<name>-mission-log-archive.md` | `ailang mission rotate-log ${MISSION_NAME} --keep 20` when the log "PASSES ~40 ENTRIES"; "keeps the newest 20 full entries live, appends the rest ... with their FULL bodies" (g4:30-39) | move | **Script (Go CLI).** "Nothing is deleted; the command is verified lossless by test." (g4:39) |
| 7 | Index | `<name>-mission-index.md` | "one line per iteration across live + archive, which is what Gate 2 greps before picking" (g4:38-39). "Regenerated, never appended" (g4:41). Rows are `| N | date | headline (truncated) |` (observed in `design_docs/v1-mission-index.md`). | regenerate | **Script** (same command). Fallback when the fleet CLI is unreachable: "add the index row BY HAND in the same commit as the log entry, and record it as a pin-version gap" (g4:54-56). |
| 8 | Queue tags | in the charter `design_docs/<name>-mission.md` | "[LANDED], [PARKED], etc." (g4:96-97). `[LANDED]` only after an observed green (g3b:303). | edit in place | **Trusted.** |
| 9 | STATUS stamp | top of the charter | "a single line followed by one blank" (g4:293). Exactly three live: "`grep -c "^## STATUS 2026"` must equal 3" (g4:280). Format per mission: V1 `## STATUS 2026-08-07 — ITERATION 156:`, World `## STATUS 2026-08-07 (iteration 60)` (g4:231-232). Newest added, 4th rotated out to the status archive. | edit + move | **Asserted by hand-run checks**, not a named script: line arithmetic `after == before + 2 - 2*len(moved)` (g4:295); grep for a known queue row (g4:296-299); `git diff --stat` before `git add` (g4:299-301); grep the ARCHIVE for the moved stamp, ≥1, with a known-present control (g4:324-327). INF: `ailang mission rotate-log` has a `--status` flag in its usage string (`cmd/ailang/mission_cmd.go:336`), so this may now be scripted, but g4 does not say so. |
| 10 | STATUS archive | `<name>-mission-status-archive.md` | receives rotated stamps | append | Same hand assertions as 9. |
| 11 | Base record | via `mission-base.sh record gate4` (g4:193) | full SHA + ISO time | script | **Script.** |
| 12 | Commit / PR for the record | git | No closing keyword near `#N` unless the commit ships the fix (g4:127-129). Stage named files. | commit | **Hand-run scan** with a known-bad control string (g4:123-126). Not a hook as described. |
| 13 | Cost chain | `ailang chains post-iteration` (g3:760-780) | `IterationPost` JSON, one per iteration, every stage with real `status` | post | **Script (Go CLI)**: rejects `quota_tokens` without `quota_bucket` (g3:787-788); warns on stages with no status (g3:824-825); has "a regression test whose entire job is to block" blanket `completed` (g3:826-828). Fail-soft. |
| 14 | Quota ledger | `~/.ailang/state/quota-ledger.json` | fed by `quota_tokens` (g3:793) | derived | Script. |
| 15 | Approval request | `ailang messages send approvals ...` for any stage recorded `awaiting_approval` (g3:806-817) | title `Approval Required: <mission>/iter-<N> <stage role>: <short subject>` | post | Trusted; must be acked when the decision lands (g3:819-820). |
| 16 | Dead-lane ledger | `mission-lane-dead.sh` (g3:71-76) | role, lane, evidence | append | **Script**, "refuses undeclared lanes and empty evidence". |
| 17 | Designer rotation pointer | `~/.ailang/state/mission-${MISSION_NAME}-designer-rotation` (g3:17) | last-used value | overwrite | Trusted. |
| 18 | Sprint state JSON | `.ailang/state/sprints/` | g4 says nothing on its format. | — | See note below. |

Written in Gate 5, not Gate 4 (see section 4): controlplane message, GitHub issue comment, weekly
thread rotation, issue-number state files, final heartbeat `stamp complete`.

**On sprint JSON and the GitHub issue comment** (the two the brief asked about by name):
- g4 does not instruct any write to the sprint JSON. Its only mention is an incident: "`.gitignore:77`
  ignores `.ailang/` with no negation, so a NEW sprint JSON was skipped by `git add -A` silently — 0
  staged, empty output — and one milestone's state artifact was orphaned" (g4:154-156). INF: sprint
  JSON is written by the planner/executor skills in Gate 3 (g3:586-587, 236), not by Gate 4, and it
  lives under an ignored directory, so it is not durably in git unless force-added.
- The GitHub issue comment is a Gate 5 write (g5:79), not Gate 4.

### 3.2 Rules that exist because a record write went wrong (OBS)

1. **STATUS rotation deleted the queue** (g4:284-303, iteration 127, 2026-08-01; "third failure of
   this same step" after iters 83 and 123). The script scanned to the next `## STATUS` header; for the
   last stamp there was none, "so the scan ran to EOF and moved the whole 1,571-line queue into the
   archive. It exited 0 and printed a plausible `archived: [...]` line." "The charter is ~1,600 lines
   of which the STATUS block is ~4, so a rotation bug is a mass-deletion bug, and it lands in the one
   file every future iteration reads as ground truth." Lesson: "you are an instrument too, and a
   destructive edit reports success exactly like a correct one."
2. **Rotated stamps deleted, not moved** (g4:305-332, iteration 190, 2026-08-13). All assertions were
   charter-side, "so all of them pass identically whether the rotated stamp was *moved* to the
   archive or simply *deleted*". Stamps 171 and 186 were "added to the charter and later removed with
   no archive commit ever touching them". 159/160/165 "were never written at all" (reaped slots).
   The audit's strict header pattern "manufactured two false gaps beside the two real ones" (163,
   184). 186 was recovered from git; "171's is still recoverable and was not."
3. **Stale base** (g4:174-211, iteration 129). Local `dev` "1 ahead / 8 behind"; the working-tree
   charter carried stamps 123/125/126 while origin carried 126/127/128; rotating in place "would have
   committed a charter with iterations 127 and 128 deleted, and the line-count assertion below would
   have *passed*". Rule: write in a worktree off `origin/dev` and land by PR. Cheap tell: grep for the
   previous iteration's stamp.
4. **The tell itself broke** (g4:213-224, iteration 134): `grep -c "Iteration 133"` returned 0 on a
   healthy charter because stamps are uppercase. Then the fix broke the sibling mission (g4:226-246,
   iteration 157): World's format is lower-case and parenthesised; "the remedy iteration 134 wrote to
   stop a healthy charter reading as stale did exactly that on the sibling mission."
   "anything this skill tells you to grep for is a claim about ONE mission's file format".
5. **Spent controls** (g4:248-282, iteration 232). A known-absent literal written into a record stops
   being absent: `ITERATION 999` "coming back 1 within the same iteration, because the STATUS stamp it
   had just written documents the control"; World's `#9999 → 0` read 1 next iteration. "rotation does
   not un-spend a control." Rule: publish the control's result, not its identifier; prefer structural
   checks "immune to prose".
6. **Shared dashboard path** (g4:69-92, iteration 216, 2026-08-17). The unnamespaced
   `mission-dashboard.md` was overwritten by every mission; V1 iterations 212-215 each skipped the
   refresh, "so V1 had no current dashboard for four consecutive iterations".
7. **A record closed live issues** (g4:99-141, iteration 240, 2026-08-21). `#676`, a live
   user-reported OOM, "was closed `COMPLETED` by `dedf3b91f` — a docs-only record, 7 files, zero code —
   1h46m after our own comment said it was real and unfixed. The repo is public". `#612` closed by a
   commit that "shipped one 636-line sprint plan". "a record is not inert — writing about a system can
   mutate it ... the record is an *actuator*, and Gate 4 has been treating it as a notebook."
8. **`git add` silently skips ignored paths** (g4:143-172, iteration 253, 2026-08-22; instance 1 iter
   195). "the artifact is absent in exactly the voice of an artifact that landed." An acceptance
   criterion of the form "archive/bank/record X" is "vacuous unless it names a path a reviewer can
   open" (g4:167-169).
9. **Missing index row** (g4:44-59). A mission pinning an older compiler ran the pinned binary, which
   had no `mission` command: "iteration 171 had a full log entry and no index row ... a missing row
   does not error, it answers "nothing like this has been tried" confidently and wrongly."
10. **Token cost was unrecorded** (g4:18-28): "Measured on iteration 338: one token report for a
    five-hour iteration that ran four codex roles."

### 3.3 Measured state of the records in the clone (my own measurements, not from the skill text)

Run 2026-10-04 against the clone; commands were `wc`, `grep -c`, `awk` over `design_docs/`.

- `v1-mission-log.md`: 230,226 bytes, 2,664 lines, 20 entries. Lines per entry: mean 130, min 56,
  max 208. The template is 14 lines.
- `v1-mission-log-archive.md`: 2,771,733 bytes. The index header says "the log (2.8 MB, ~715k
  tokens) has not been [read in full] for a long time" (`design_docs/v1-mission-index.md:5-7`).
- `v1-mission.md` (charter): 930,233 bytes, 4,908 lines, longest single line 19,540 chars. Three
  live STATUS stamps, each one line of 4,522 / 6,568 / 5,382 chars.
- `v1-mission-status-archive.md` 179 KB plus `v1-mission-status-archive-old.md` 1.54 MB.
- `v1-mission-index.md`: 342 rows, 54 KB.
- The "Older entries are ARCHIVED" banner appears 8 times at the head of `v1-mission-log.md`
  (lines 25-63). INF: `rotate-log` re-inserts its banner on each run rather than replacing it.

INF: the "single line" STATUS rule bounds line *count*, not size; a stamp is in practice a
4-7 KB paragraph. The charter is nearly 1 MB, so "Gate 1 reads the charter head" is a necessity,
not a preference.

---

## 4. Gate 5 — RETRO + REPORT (g5, 202 lines, read in full)

### 4.1 How a lesson becomes a change (OBS)

Step 1 (g5:7-12): scan "this iteration's friction (evaluator feedback, executor corrections, your own
dead ends) plus unread `docs/sprint-retros/` material. Route each item to exactly ONE lane":

| Lane | What changes | Gate on the change |
|---|---|---|
| skill fix | "edit the offending SKILL.md" | "Max ONE skill edit per iteration; requires ≥2 recorded frictions pointing at the same gap; state both in the commit message." (g5:9-10) |
| process fix | "edit the mission doc (guardrails/ordering/routing policy per its rules)" | the charter's own rules (g5:11) |
| backlog | "new design doc via design-doc-creator, or re-prioritize the queue" | goes through the normal loop (g5:12) |

Step 2 (g5:13): "Routing-policy change? Only with ≥3 evidence rows; stamp it in the mission doc."

So the thresholds are: **2 recorded frictions for a skill edit, 3 evidence rows for a routing-policy
change, 1 skill edit per iteration.** The retro lane taken is recorded in the log entry's
`**Retro lane**` field (log template line 19).

How the thresholds are used in practice (OBS, from the other files):
- Notes pre-register a remedy at instance 1 and execute it at instance 2: "executing the remedy
  iteration 127 pre-committed to on a second instance: "If a second iteration hits it, the fix is to
  standardise the worktree location off `/tmp`."" (g3:635-637).
- Notes decline to change policy below the bar and say so: "This note deliberately does NOT change
  the rotation, because a routing-policy change needs ≥3 evidence rows (Gate 5 step 2) and there are
  two — it records the measurement so the third is recognisable rather than rediscovered" (g3:17).
- Each added note carries its instance count in its header, e.g. "(added 2026-08-14 V1 iteration
  199; instance 1 was iteration 198, instance 2 is this iteration)" (g3:687-688).
- A same-mechanism third instance does not earn a new note unless the mechanism is new: "a new
  mechanism, which is why it earns a note rather than a louder restatement" (g3b:132-133).

### 4.2 Who may change the loop (OBS)

- **The unattended loop**: one skill edit per iteration at ≥2 frictions; routing policy at ≥3 rows.
  "The inner-loop skills are the contract — improve them via Gate 5, don't bypass them mid-iteration
  because one is annoying. If a skill blocks you, that IS the retro finding." (SKILL:304-305).
- **The human owner (Mark), attended**: not bound by the counts. "The ≥3-evidence-rows rule in Gate
  5 step 2 binds the LOOP changing policy on its own, not an attended human ruling" (g3:17). Many
  rules are stamped "(Mark, attended YYYY-MM-DD)" with a quoted directive.
- **Human-only changes**: a routing-policy change on a shared file "needs a human" (g3:52-53); a
  spend-policy change "is its own attended ruling" (g3:17).
- **Sibling missions** share the skill but "cannot edit it": they *propose*, and the owning mission
  adopts only after corroborating first-party — "proposed by `mission-world` iter-60, which shares
  this skill but cannot edit it, and corroborated first-party in BOTH repos before adoption —
  sibling-claim ghost discipline" (g4:228-230; also g4:250-251, g3b:263-264).
- **Harness work is attended-only** as of the text: "Under the attended-only rule (Gate 2) this
  share should now trend to ZERO for loop-authored work" (g5:22-23). INF: this means the loop's own
  Gate-5 skill-fix lane is now largely closed to unattended iterations except by recorded escalation;
  the governing rule is in Gate 2 (not my file).

### 4.3 The two alarms on self-repair (OBS) — the main "something went wrong" rule in Gate 5

- **2b, harness share** (g5:14-29): count `[HARNESS]` rows in the index over the last 20 iterations,
  "one figure, every time". "A rising share is a signal to STOP AND ASK MARK, never to work harder —
  it means the mission is repairing itself instead of working, which is the condition that took the
  fleet to 55% and cost it two weeks (iterations 309–348: 16 lines of compiler and stdlib)."
  Threshold: over one third in 20 iterations gets its own heading with the rows named.
- **2c, drift alarm** (g5:30-37, 2026-09-26): for each of the last 3 landings record which UNMET
  charter clause it moved, or "none". If all 3 read "none" while a routable unmet-clause row exists,
  "the digest LEADS with a `DRIFT` line".
- Work-class tags: PRODUCT / HARNESS / ADMIN / REFUTATION, "tag honestly — ... "everything is
  HARNESS" is itself the signal Mark is watching for" (g5:123-127).
- If the charter has no measurable finish line: write "Progress: charter has no finish line" — "a
  standing Gate-5 process-fix trigger to add one ... outranking other retro lanes" (g5:131-133).

INF: 2b and 2c are the project's own verdict on its retro mechanism. The per-iteration skill-fix lane
worked as designed and the aggregate result was a loop that spent 40 iterations on itself. The
correction was a counter read by the human, plus moving harness work to attended sessions; it was
not a tighter per-edit rule.

### 4.4 The report (OBS)

- Two channels, both required (g5:38): `ailang messages send controlplane` (g5:43-44) and
  `gh issue comment "$MISSION_GH_ISSUE"` (g5:79).
- "The issue thread is a COMMUNICATION channel, not loop memory — the loop never re-reads its own
  reports (Gate 0 filters for Mark's comments only); the full record lives in the charter STATUS +
  mission log ... Do NOT mirror the STATUS entry into the issue." (g5:40-42).
- **Digest hard cap: "≤26 lines / ≤2,200 chars, exactly these sections, nothing else"** (g5:100).
  Sections: headline, Pick, Outcome, Progress, Up next (banked), Key find (optional, ≤2 sentences),
  Cost, DECISIONS FOR MARK, link to full record (g5:103-122). "No gate-by-gate narration, no
  routing-evidence dump, no war stories" (g5:135).
- A decision ask must be complete inline: question, options with consequences, recommendation,
  default-if-unanswered. "An ask Mark must research before answering is not an ask; it is homework,
  and it will sit unanswered." (g5:116-120). Model case "answered in 21 characters BECAUSE the ask
  was complete."
- Controlplane title carries `[urgent]`/`[normal]`/`[fyi]` for a triage agent (g5:83-99). Origin:
  "measured 2026-09-28, all 150 digests in Daneel's ledger were `fyi · NOTE`, so decision asks were
  counted and never shown."
- Weekly thread rotation (g5:139-202): rotate when past Monday 07:00 local or >80 comments. Origin:
  "#329 hit 120KB/53 comments in 6 days".
- Checked vs trusted: the digest cap is **trusted** (no checker named). `ailang messages read <id>`
  after sending is a hand assertion (g5:70-71). Heartbeat `stamp complete` is a script (g5:4-5).

### 4.5 Incidents behind Gate 5 rules (OBS)

- `ailang messages send` has no `--body-file`; it "silently accepts the literal string `--body-file
  /path` as the message body, exits 0" (g5:45-47, iteration 252; World iter-110). Two missions made
  the same substitution because the adjacent `gh` rule says "always `--body-file`": "a flag
  vocabulary is per-tool, and an emphatic rule about one tool becomes a bug in the tool beside it."
  (g5:76-78).
- Iteration 149 "lost its evidence out of a `gh issue close --comment` when unescaped backticks
  triggered zsh command substitution — `gh` reported `✓ Closed` on a comment whose evidence had been
  surgically removed." (g5:188-191).
- Timezone in the rotation rule: iterations 111/112/113 each flagged the omission (g5:144-149).
- Weekly-report script lookup checks capability, not existence: a checkout "existed and was two
  commits stale" (g5:181-187). The driver copy was "233 lines adrift as of 2026-08-12" (g5:179-180).

---

## 5. The verification protocol (vp, 1,433 lines, read in full)

Also read in full for this section because g3 points at it as the moved text of its false-green
list: `codex-lane-false-greens.md` (`cf`, 158 lines).

### 5.1 What the file is (OBS)

- Self-description: "The 18 rules the mission loop verifies against, in full. Each one is an
  epistemics failure **this loop actually committed**, with the measurement that caught it, the
  commands that discriminate, and the tell that says you are about to repeat it." (vp:3-5).
- Read at Gate 2. "It lives outside `SKILL.md` because it is 1,378 lines the other five gates do not
  need in context — not because it is optional." (vp:7-9).
- The header is stale against the file: it says 18 rules and 1,378 lines; the file has 1,433 lines
  and 20 labelled rules (1, 2, 3, 3a-3n, **two different rules both labelled 3o** at vp:1346 and
  vp:1421, and 4). The second 3o is one 2,285-character line.
- 41 dated "(added/fixed YYYY-MM-DD ...)" amendments; dates span 2026-07-10 to 2026-09-24 (my count
  by grep). "The tell" appears at least 35 times.
- Every rule has the same anatomy: the claim shape, instance list with iteration numbers and
  measured values, "Rules. (a)...(d)", "Mission-independent: ...", "The tell: ...".

### 5.2 What counts as verified (OBS for each bullet; the assembly into one list is mine)

The file never defines "verified" in one place. It defines it by exclusion: every result is a
*claim* until a named condition holds. The word "claim" is the organising term —
"A parked test is a claim" (vp:92), "A search that found nothing is a claim" (vp:138), "A passing
check is a claim too" (vp:421), "A reviewer's objection is a claim too" (vp:762), "An executor's
deviation from the plan is a claim in both directions" (vp:825), "A test-plan row's 'kills which
mutation' column is a claim" (vp:860), ""Environmental" is a claim" (vp:1225), ""unreachable" is a
claim about a platform" (vp:974).

A result becomes evidence when:

1. **The instrument is fresh and identifiable.** Rebuild before any live check; "Confirm `--version`
   matches `git describe` before trusting output" (vp:20-24). State the binary's provenance wherever
   a green is quoted (vp:86-89).
2. **The exit code was read without a pipe.** `cmd > /tmp/out 2>&1; echo "rc=$?"` (vp:95-96).
3. **An empty result is paired with a known-positive control in the same call and the same scope.**
   "prove the instrument can see a positive, in the SAME call" (vp:167); "run the control against
   the SAME directory/file-set as the check" (vp:362-363).
4. **A green result's scope matches the sentence it is cited for.** "name the sentence it supports,
   then check the command's scope actually covers that sentence" (vp:439-440). Any narrowing
   (`-run`, `-skip`, `--version`, single package, `| head`, host platform, sandbox) "is PART of the
   finding and travels with it" (vp:441-443).
5. **A red in the predicted direction is paired with a negative control.** "run it once with the
   mechanism REMOVED ... and require the outcomes to DIFFER. Same outcome means you measured the
   environment, not the mechanism, and the size of the difference is the size of your evidence"
   (vp:673-675).
6. **The base is pristine and is the lane that will execute.** (vp:688-690, 750-752).
7. **Quantities and identifiers were produced by a command in this session.** "anything a downstream
   role will treat as ground truth — especially a SHA, a count, a line number, or a file path — is
   re-derived by command at the moment you write it" (vp:465-467). The tell: "you are quoting a
   *quantity* or an *identifier* and cannot name the command that produced it in this session"
   (vp:468-469).
8. **A count carries its scope in the sentence.** "five getters on the daemon read path" (vp:612-614).
9. **A mutation result has four preconditions**: the mutant LANDED (sha256 differs) (vp:206-208);
   it BUILDS (vp:295-297); it changed the *named* thing, asserted "with a query against the system's
   own view ... never against the file's bytes" (vp:226-228); and the assertion that failed is the
   one the mutant targets (vp:230-232).
10. **The check ran in the tree you think it ran in.** Assert `pwd` in the same call (vp:1421).

### 5.3 Classes of evidence (OBS for each label; the grouping is mine)

By **shape of result** — the file's own framing of rules 3a-3d:
- empty (3a) — needs a positive control;
- green (3b) — needs scope and version matched to the claim;
- specific, non-empty and about the wrong object (3c): "a probe identifies the endpoint you REACHED,
  never the service you NAMED" (vp:619-620);
- red as predicted (3d) — "the most seductive claim of all" (vp:647-648); "co-occurrence read as
  causation" (vp:654-655).

By **provenance** (defined in `gate-2-pick.md:486-488`, of which I read only lines 482-507):
- "`VERIFIED BY ME (<command/file:line>)`" versus "`UNVERIFIED, inherited from <role> — re-check
  before relying`". vp treats mislabelling under a VERIFIED-BY-ME heading as "the exact laundering
  Gate 2 forbids" (vp:453-454).
- **First-party versus sibling claim.** A rule proposed by another mission is adopted only after
  being reproduced locally: "corroborated first-party ... before adoption — sibling-claim ghost
  discipline" (vp:262-263 and six other places).
- A judge's finding is a claim to reproduce "before acting on it" and "before DISMISSING it too"
  (`gate-2-pick.md:504-507`).

By **non-verdict states** — outcomes the text requires to be labelled rather than counted:
- `UNINFORMATIVE` / `UNINFORMATIVE UNDER SANDBOX` (vp:444, 577, 719, 748; cf:38-39): a denial, skip
  or flake that forced a narrowing; a control without a pristine base; a single-platform green for
  per-OS behaviour.
- `INSTRUMENT FAILURE — not a verdict` (g3b:147; vp:254): a non-numeric reading.
- `INSTRUMENT INCOMPLETE — no verdict` (g3b:119): a check set shorter than expected.
- `PROVISIONAL until the matrix has run` (vp:1001, 1039): a platform-scoped property declared from
  one host.
- "consistent with" rather than "caused by" (vp:678-679) when alternatives are not ruled out by
  command.
- "grep found no X" is not "there is no X" (vp:417-418).
- "N/A ... not pending" for a path-filtered workflow (g3b:352).
- Declared residual / declared limitation: an unpinned or unreachable hunk is acceptable "when
  declared in the code and in the AC" (vp:971-973); "a named gap is cheap, an assumed one is not"
  (vp:893).
- "sole killer" reported separately from "set membership" / "some killer" (vp:1103-1104, 1337).

### 5.4 The role of negative assertions (OBS)

1. **Negative control for a red** (3d): mechanism removed, outcomes must differ (vp:673-675).
   "attribution must match on MECHANISM, not on timing — same failing test AND same platform AND
   same layer" (vp:680-681).
2. **Negative framing as the acceptance test for a green**: "what would this command still pass
   under, if the thing I am claiming were false?" (vp:445-446).
3. **Anti-vacuity floor**: "an empty result set must FAIL LOUDLY (`t.Fatal("instrument failure")`),
   never pass" (vp:170-171). "any enumerator-fed gate needs an anti-vacuity floor: an empty set must
   FAIL LOUDLY, never print a checkmark" (vp:1141-1143). For parsers: "a parser that extracts zero
   records from non-empty input must fail LOUDLY" (g3:579-581).
4. **Mutation as the negative assertion on a test**: "a guard is not a gate until something reds
   when you remove it" (vp:1063). One neutering mutation per refusal branch (vp:941-943).
5. **Removal is not enough**: "a removal proves the check FIRES; only an addition proves it LOOKS"
   (vp:410-411). Add a member the enumerator might miss; "Require the count to MOVE, not merely the
   verdict to flip" (vp:402).
6. **Mutate the setup, not only the code**: "neuter the test's PRECONDITION, not the production
   code, and require the arm to die" (vp:914-915). "A control that cannot fail is not a control"
   (vp:928-929).
7. **Asserting an absence is weak**: an assertion that a log line is absent is satisfied equally by
   "the filter suppressed it" and "nothing was ever emitted" (vp:903-904). Prefer "an observable
   whose value is *unique* to the mechanism" (vp:922-924).
8. **Known-absent literals are consumable** (g4:248-282): writing the control's identifier into a
   record makes it present. "publish the control's RESULT and not its IDENTIFIER" (g4:277-279).
9. **Agreement between control and finding is suspect**: "a control exists to DIFFER" (g3b:204-205);
   "when two arms agree, ask what they SHARE before concluding the variable does not matter"
   (vp:716-718); the shared thing "is often the READER, not the tree" (vp:116-117).
10. **Guards specified as observations, not seeded writes** (cf:99-102): "Sha and line-count the
    artifact on both sides, with `absent` a legitimate reading".
11. **Refuted hypotheses are recorded** in the log's Ruled-out field; "a reviewer refuted by
    measurement is the loop working" (vp:797-798).

### 5.5 Catalogue of false greens (and false reds), with the incident behind each

All OBS. "FG" = a pass/clean/complete reading that was not true. "FR" = a fail/absent/park reading
that was not true. Iteration numbers are V1 unless prefixed. Dates are the "added" stamp.

#### A. The instrument was stale, wrong or unidentifiable

| ID | Pattern | Incident and numbers | Line |
|---|---|---|---|
| A1 | Stale installed binary shows pre-fix behaviour (FG/FR) | "1a: stale installed binary showed pre-fix behavior; 1b-eval: Jun-26 `bin/ailang` v0.26.0 broke `make test` with a phantom `_io_flush` error" | vp:20-24 |
| A2 | A test shells out to a stale binary on PATH; red looks like a code defect (FR) | iter 237, 2026-08-20. `TestGoldenCompile/string_charat` failed `undefined: CharCode`; "stale PATH `rc=1`, fresh binary `rc=0`" on the identical tree. Instance 1: iter 235's quorum on a binary 35 commits adrift; instance 2 at 37. Structural: the loop must not `make quick-install` on a shared rig, so the PATH copy "drifts, without bound, forever" | vp:25-49 |
| A3 | Binary cannot say what it is: `go build` in a linked worktree stamps `"dev"` (FG on provenance) | iter 256, 2026-08-23; iter 253's frozen manifest recorded `ailang_version:"dev"`. `-buildvcs=true` "exits rc=0, produces the binary, emits 0 vcs lines and does not error". Three consumers silently accept `"dev"` | vp:50-80 |
| A4 | Tool invoked with an old `--version` cited for the current target (FG) | iter 124. Example verified with `ailang prompt --version v0.16.2`, cited for v0.31.0: "fifteen minor versions stale" | vp:434-438 |
| A5 | Probe answered for a different instance of the service (FG) | iter 130, 2026-08-01. `127.0.0.1:11434` → 0.31.2, `[::1]:11434` → 0.32.1; "the CLI reported an idle GPU while a 37 GB model was resident on the other". iter 129's proposed restart "would have restarted the wrong server" | vp:619-646 |
| A6 | Check ran in a different tree than named (FG) | World iter 180: gate sweep "in the worktree" ran in the main checkout, "a plausible 19-green result until `pwd` was asserted". World iter 181: `git add`+`commit` ran in main; harmless "which is luck, not design" | vp:1421 |
| A7 | Persisted `cd` made a main-tree check read the worktree (FG) | iter 4, 2026-07-10: reported a sibling's merge "cleared when it wasn't" | vp:1423-1427 |
| A8 | Parked/skipped test read as "still broken" (FR) | M-TYPEENV-SUB "open P0" "was already fixed; only un-skipping revealed it" | vp:92-94 |
| A9 | Worktree under `/tmp` reds tests for the location (FR) | iters 127, 133: `TestIsTempPath`, `TestSolve_HardTimeout_FakeSolverIgnoringT`; "from a non-`/tmp` checkout are rc=0, from `/tmp` rc=1" | g3:634-651 |
| A10 | Half-built worktree reports the whole tree deleted (FR) | iter 234, 2026-08-20: `git status --porcelain | wc -l` → 23,835. Controller read a live PID as dead and removed the lock, killing a checkout "54% done". Docs iter 17 (2026-10-01): 25,786 staged deletions | g3:652-682, 624-626 |

#### B. The reader lost or rewrote the reading (shell and pipe)

| ID | Pattern | Incident and numbers | Line |
|---|---|---|---|
| B1 | `cmd | tail; echo $?` reports the last command's status | base rule | vp:95-96 |
| B2 | The remedy for B1 printed nothing: `${PIPESTATUS[0]}` is empty in zsh | iter 120, 2026-07-29: `false | true; echo "[${PIPESTATUS[0]}]"` prints `[]`. "voiding the very gate it was added to protect"; "went four-plus iterations without anyone noticing" | vp:97-103, 162-164 |
| B3 | Pipe makes both arms of a control agree ("false symmetry") | iter 236, 2026-08-20: `go build ... 2>&1 | head -5; echo "rc=$?"` printed rc=0 for both arms, true codes 1 and 0 | vp:104-137 |
| B4 | Unquoted glob flag aborts the command before it runs; caller reads 0 hits | World iter 120: `--include=*.go`; "nearly shipped a fabricated "zero callers anywhere" fact ... the real answer was 11 call sites" | vp:154-158, 172-173 |
| B5 | zsh history modifiers rewrite `"$rev:path"` | iter 123, 2026-07-30: `"$c:host/x"` → `.ost/x`. World "read `total_tables=0` for the commit that CREATED the schema". Gate 1 prescribes that exact shape | vp:174-188 |
| B6 | `echo` interprets backslashes; hid the bug under test | iter 123: `#541`'s defect was a literal `\n`; `od -c` showed `5c 6e` | vp:189-195 |
| B7 | zsh does not word-split; mutation never applied; gate "passes" | iter 140, 2026-08-04: `sed -i '' … $FILES` got one argument; "both gates returned rc=0"; control `git diff --name-only | wc -l` "expected 4, got 1". "the first to produce a vacuous pass in a MUTATION TEST" | vp:195-208 |
| B8 | `set -- $var` leaves `$2`/`$3` empty; poll misreports | iter 239, 2026-08-20 (instances: iter 107, 236, 239). `st="3 1 0"` → `$1='3 1 0'`. "three iterations paid for one construct" | vp:236-257 |
| B9 | `|| echo 0` inside `$(...)` yields `0\n0` | iter 244, 2026-08-21; World iter-105. `[ "$done" != "0" ]` true on first tick: "the loop printed WRAPPER FINISHED while the executor was six minutes from done". Not caught by the numeric floor because it is compared as a string. V1 iter 244 "greened a worktree-creation poll early" via `grep -q .` on a log git was still writing | vp:258-295 |
| B10 | zsh arrays are 1-indexed; table columns shift, last element dropped | motoko iter 8, 2026-08-17: an 8-file sweep table "rendered every count under the WRONG file's header and never printed the 8th file". A correct total sat beside a broken table: "the total certifies the table" | vp:298-330 |
| B11 | Two empty strings compare equal; poll prints ALL COMPLETE | iter 233, 2026-08-20: `jq` parse error on a control character; "three runs still `in_progress`" | g3b:128-162 |
| B12 | Unquoted `'parents[]'` glob-expands; commit never created | iter 156 | g3b:260-262 |
| B13 | `--body-file` taken as the literal message body, exit 0 | iter 252, 2026-08-22; World iter-110 | g5:45-78 |
| B14 | Unescaped backticks in an inline `--body` executed as command substitution; `gh` reported `✓ Closed` with the evidence removed | iter 149 | g5:188-191 |
| B15 | `${VAR:+YES}${VAR:-NO}` prints the secret | World leaked `OPENAI_API_KEY` into a transcript | g3:186-189 |

#### C. Empty or negative result believed

| ID | Pattern | Incident and numbers | Line |
|---|---|---|---|
| C1 | grep of the wrong files: "runs nowhere in CI" | iter 119, 2026-07-29: told its planner "under an explicit VERIFIED-BY-ME label" that a 603-line suite runs nowhere in CI; `make/test.mk:19` defines it and `ci.yml:133-144` runs it. "the planner had to refute it and delete a fabricated milestone" | vp:143-147 |
| C2 | Pattern could not match the quoting in the file | iter 119: grepped `PASSES -lt` against `"$PASSES" -lt 45` | vp:147-149 |
| C3 | A call-site hit read as reachability | iter 105: `RunAICheck(` hit in `RunAgentBenchmark`, whose only reference is a comment saying not to use it (`gate-2-pick.md:482-486`: would have "bank[ed] a zero denominator") | vp:149-150 |
| C4 | Command fataled to stderr, printed nothing | iters 55-58: `rev-parse --short`, "wearing the all-clear's clothes for four iterations" | vp:150-152 |
| C5 | Empty protocol handshake read as "no tools" | iter 120: MCP `tools/list` empty for all five flag combinations; actually `rc=1`, `server is closing: EOF` | vp:158-162 |
| C6 | Control ran in a different scope from the check | iter 181, 2026-08-12: `grep -ril 'flatmap' stdlib/` → 0; `stdlib/` "has never existed in this repo" (real path `std/`). iter 170 recorded "grep 0, control firing" and wrote into the charter that stdlib has no `flatMap`; false (`std/list.ail:202`). "sat in the queue row for eleven iterations" and misdirected `#617` | vp:345-374 |
| C7 | Enumeration is short; every removal mutant reds, an added member is invisible | iter 242, 2026-08-21: builtin gate parsed `Name:` string literals; evaluator added one registered as an identifier; "the gate stayed GREEN at an unchanged "31 registered"". Commit message had claimed "a new builtin cannot slip past". iter 170: four orphaned issues invisible. Neither live registry was complete alone (18 and 26, union 31) | vp:375-412 |
| C8 | `head_sha=` with a truncated SHA returns `total=0` | iter 155 | g3b:170-179 |
| C9 | Hand-typed control SHA agrees with the finding | iter 243 | g3b:180-209 |
| C10 | Case-sensitive grep for the stamp returns 0 on a healthy charter | iter 134; then the fix broke World (iter 157) | g4:213-246 |
| C11 | `git add` of an ignored path stages nothing, exits 0 | iters 195, 253 | g4:143-172 |
| C12 | "NEW-DOC" queue tag when a design doc already exists | iters 25, 26: "2 of 2 recent NEW-DOC tags were wrong" | g3:525-529 |

#### D. A real green over-read

| ID | Pattern | Incident and numbers | Line |
|---|---|---|---|
| D1 | Narrowed run cited for a wider claim | iter 124, 2026-07-31: `-run 'Recorded|StreamRecorded'` 4/4 cited while routing; reviewer rejected; the right command gave "658 PASS" | vp:427-433 |
| D2 | `| head -N` truncated an enumeration | iter 137, 2026-08-04: `go list ./... | grep -v /internal/ | head -20` → "exactly ONE importable library package. There are two" | vp:454-460 |
| D3 | Value transcribed from a document | iter 137: SHA `a81d66983` was a different PR's Lane A (`aa02f0d9f` correct); "16 fields where the listing ... showed 15". "three instances in ONE spawn directive, all three caught by the DESIGNER" | vp:460-471 |
| D4 | A doc's own verification log refutes its acceptance criterion | iter 138, 2026-08-04: row V18 recorded that the boundary gate does not cover `apiserver`; AC was still "`make check-boundaries` passes". "Two reviewers cleared that doc across two full quorum rounds and neither caught it" | vp:472-493 |
| D5 | Freshness sweep from the newest base gives a false all-clear | iter 141, World: `<NEWER>..HEAD` → 0 files; `<OLDER>..HEAD` → 8. "five rounds and two reviewers missed all three rows" | vp:494-518 |
| D6 | Design doc and sprint plan diverge after a human directive | iter 146, 2026-08-05: doc gained AC10(d); plan still listed (a)-(c); "would have shipped without the tripwire". Doc said "5 CI legs" in 6 places despite its own V34 measuring 6 | vp:519-547 |
| D7 | Host platform is an untyped narrowing | iter 195, 2026-08-13: `t.Setenv("HOME")` to drive `os.UserHomeDir()`, which reads `USERPROFILE` on Windows. PR body had claimed "Gates (all outside the sandbox) … rc=0" | vp:548-587 |
| D8 | A count copied into a wider sentence | iter 202, 2026-08-14; World iter-86: "four context-free read getters" missed a fifth; the correction "all five" was wrong against six. V1: a mutation table of 8 rows covering 9 test functions | vp:588-618 |
| D9 | Local gate sweep assembled from memory | iter 152, 2026-08-06: seven local gates rc=0; `make check-changelog` "was simply not in the habit" and reddened the required context. iter 151 had caught the same thing by hand. "a lesson recorded but not wired in is what produced instance 2" | vp:800-824 |
| D10 | Checks not runnable locally by construction | iter 351, 2026-09-08: `golangci-lint unused` after a subtractive edit; SonarCloud `new_coverage` 78.8% vs 80, 7 of 33 new lines uncovered | g3b:41-81 |
| D11 | Acceptance command already red on the base | iter 145: `go build ./...` fails on untouched dev. iter 147: `actionlint` rc=1 at base on 5 pre-existing findings | vp:693-701 |
| D12 | Control contaminated by an earlier step of the change | iter 147, 2026-08-05: `go mod download all` wrote `go.sum`; both arms skipped identically; recorded as environmental; "CI red-lighted the milestone's own acceptance step ~40 minutes later" | vp:702-723 |
| D13 | Gate list baselined in the controller's shell, executed in a sandbox | iter 270, 2026-08-24; World iter-119: gate G4 rc=0 outside, rc=1 inside on a denied `httptest.NewServer` bind, in a directive stating "every one rc=0 there" | vp:724-761 |
| D14 | The controller's own directive gate list is never baselined | iter 245, 2026-08-21: `go build ./...` as the mutant-BUILDS assertion, rc=1 on pristine dev. Rule 3e(a) "can be documented, cited, and still bought a third time" | cf:43-66 |
| D15 | "N/N green under load" certifies only the axis varied | iter 248, 2026-08-22; World iter-107: 23/23 green under CPU spinners; `GOMAXPROCS=1` → "10/10 FAIL on unmutated, sha256-identical code". Stimulus 53 ms on laptop, 2.63 s on runner (49×). V1: 51 test files with a hardcoded millisecond bound; zero vary `GOMAXPROCS` | vp:1262-1306 |
| D16 | "Unreachable" declared from one host | iter 318, 2026-09-02: executor, independent judge and controller all certified a branch unreachable; Windows CI reddened both jobs on first push. "independence in the *reviewer* does not buy independence in the *platform*" | vp:974-1012 |
| D17 | "Unnecessary" declared from one host, then deleted | iter 319, 2026-09-02: two stabilizers deleted after 8 local green runs; CI red on first push. Committed "after reading 318's rule at Gate 1 the same iteration". "The executor had been right, and two independent reviewers on the same platform had overruled it" | vp:1013-1048 |
| D18 | A green during a provider incident read as "incident over" | CI on dev `success` 17:32Z, `failure` 20:03Z, `success` 21:57Z | g3b:263-273 |

#### E. A red credited to the wrong cause

| ID | Pattern | Incident and numbers | Line |
|---|---|---|---|
| E1 | Co-occurrence read as causation | iter 140: a deterministic regression attributed to flake `#587`; "Wrong platform *and* wrong failing test; the real regression sat on `dev` for ~2h and was reported to the human as a flake" | vp:658-662 |
| E2 | A single arm "refuted" a correct prediction | iter 141: poisoned-proxy check returned rc=1; iter 142 measured "the poison never touched the request"; error page came from `httpbin.org`. Poisoned `rc=0 ok 0.767s`, unpoisoned `rc=0 ok 0.724s`. A vacuous AC shipped into a sprint plan | vp:663-671 |
| E3 | "Environmental" diagnosis from two failing missions | motoko iter 5, 2026-08-15: refusals per fire v1 47/186, motoko 6/11, world 0/89. Cause was a SessionStart hook in the shared repo. "four months of refusals were read as quota pressure that was never present"; the quota arm "had never fired once" | vp:1225-1261 |
| E4 | Exit code banked without reading which test failed | World: rc=1 "in exactly the predicted direction and its only FAIL was a pre-existing load flake (measured 2/5)" | vp:1066-1070 |
| E5 | Sandbox denial read as a regression, and the reverse | iters 110, 111, 113: `make test` exit 2 inside the sandbox, "rc=0 with zero FAIL" outside. World: a sandbox panic "masked a genuine `io.Pipe` startup deadlock" | cf:31-42 |
| E6 | Reviewer objection forwarded instead of measured | iter 126 (two quorum rounds lost); iter 150, 2026-08-06: audit returned 0 / 0 / 0 with a control of 29 | vp:762-799 |
| E7 | Metered-API cap error read as subscription quota exhaustion | 2026-07-16 "Fable quota-exhausted until 2026-08-01" | g3:279-291 |
| E8 | Our own size guard killed runs that were working | pi lane: 7,130 reasoning tokens → 330 MB of NDJSON; guard "silently capped the lane at roughly 7,000 reasoning tokens"; iterations 172 and 173 "both failed after adding anti-runaway instructions" | g3:424-431 |
| E9 | `tool_hang` logged as `stream_dead` | World iter-208, 2026-09-29: every "deepseek stream_dead" was `ailang messages list` hanging in the sandbox; codex was then run over ration | g3:454-458, 76-77 |
| E10 | Missing CI runs blamed on dropped webhooks | iters 198, 347 | g3b:357-430 |
| E11 | Wrong failing step named | motoko `#760` | g3b:336-343 |
| E12 | Coverage red inherited as the previous iteration's "duplication, benign" | iter 250 "nearly inherited that reading for a red that was in fact *coverage*" | vp:1339-1343 |

#### F. Tests and mutation drills that could not fail for the stated reason

| ID | Pattern | Incident and numbers | Line |
|---|---|---|---|
| F1 | Mutant did not build; red is a compile error | iter 160, 2026-08-07; World iter-62, three instances: "two reds, zero information" | vp:295-297, 331-344 |
| F2 | Mutant landed in the wrong place | iter 274, 2026-08-25: greedy `sed` stripped two other targets; another mutant landed inside a trailing comment; "the arm redded on a *different* assertion" | vp:209-235 |
| F3 | Observable set *alongside* the mechanism | iter 162, 2026-08-07: row S11 claimed to kill a missed call site; replacing `newRNG(...)` with a constant "left the entire seed suite green". "Two of three swept sites were unguarded" | vp:860-894 |
| F4 | Observable written by other mechanisms too | iter 200, 2026-08-14: `TestA2AExitNonzeroFails` asserted state `"failed"`; with the precondition neutered "5 of the 6 exit arms correctly failed and that one PASSED". The positive control fixture also "passed with or without the grant". Instance 1 (iter 199): an absence-only assertion | vp:895-931 |
| F5 | Refusal branches with no pin | iter 164, 2026-08-08; World iter-63: one refusal term "satisfiable by nothing an operator can mint (two quorum rounds read past it)"; replacement left the whole package green under `if false && …`; ended at 20 negative arms | vp:932-943, 1049-1053 |
| F6 | Guard covered only by a one-shot acceptance command in the plan | `--seed`/`--random-seed` exclusion: wired into no make target, no CI job, zero test files; neutered, "the entire rest of `cmd/ailang` is rc=0 with the defect present" | vp:1054-1065 |
| F7 | The prescribed enumerator of refusals was blind | iter 178, 2026-08-11: `grep -c 'return .*fmt.Errorf(.*%w'` saw 22 of ~55 (World); V1 repo-wide 1781 vs 4273 + 20: "hides ~2,500 refusal returns" | vp:944-962 |
| F8 | Audit scoped to the design doc's decision list, not the diff | World: branches the milestone itself wrote were outside "by construction" | vp:963-969 |
| F9 | `-skip <arm>` rc=0 criterion applied to a broad-blast mutant | iter 227, 2026-08-19; World iter-94. iter 225: "4 of 12 mutants fail ... read at first as "4 vacuous arms"" (M1 killed 5 arms, M7 6). iter 227: 5 of 10 broad-blast. A doc *stated* a two-test red set; measured four — "would have rejected a working mutation" | vp:1075-1109 |
| F10 | Every branch pinned, enumerator blind | iter 187, 2026-08-12; World iter-77: allowlist gate, "ten mutations, evaluator 93/100 — defeated by `SNEAKY.AIL`" (`find -name` is case-sensitive; 4 vs 5 files). V1: `make fmt-check-ail` enumerates non-existent `stdlib/` with `2>/dev/null`; 400 files vs 446; "46 stdlib `.ail` files sit outside a gate that still prints `✓ All .ail files are canonical`" | vp:1110-1144 |
| F11 | One of several enumerations floored | iter 271, 2026-08-24: roots call cut from 10 to 0 with deps at 224 "left the violator loop iterating zero times and the gate printing its green checkmark at rc=0". iter 269: `make lint` scan list widened, verdict list not. iter 268 | vp:1145-1181 |
| F12 | Test rebuilds the user-facing command instead of running the emitted one | iter 166, 2026-08-08: `ailang test` printed `replay: ailang test --seed 0 All Tests` — unrunnable; "broken since the milestone before, through a quorum, a sprint plan, an evaluator PASS and a Gate-3b green". iter 111: guide taught a function name absent from the example file | vp:1182-1212 |
| F13 | Mutation set derived from the bug, not the diff | iters 249, 250 (2026-08-22): supporting hunks — one reds only its own unit test, one "reds nothing at all". Found by the judge and independently by SonarCloud new-code coverage | vp:1307-1345 |
| F14 | Headline test filed under the wrong milestone | iter 333, 2026-09-06 (instance 1: iter 330, "recorded and then dropped"): with M4's production hunk reverted, T12 "stays PASS (`ok cmd/ailang 8.062s`)" because M1's hash check catches everything first | vp:1346-1384; g3:746 |
| F15 | Intermittent kill "fixed" by enlarging the fixture | iter 314, 2026-09-01: mutant killed ~1 in 15; controller wrote a `1/6! = 1/720` bound into a code comment; re-measured "4 kills in 8 runs". "The probability model was simply false" | vp:1385-1419 |
| F16 | Hand-typed parser fixtures | iter 348, 2026-09-07: parser anchored on `^ok\t`; real `go test` output pads; "the tool matched zero records against real output and reddened a passing build on both CI legs". Then `.gitattributes` CRLF: LF "128 records / 105 cached vs CRLF 23 / 0" | g3:555-584 |
| F17 | `git checkout -- <file>` as the mutation restore step deletes uncommitted sprint work | iter 166: the sha256 check "reports MISMATCH *after* the loss" | vp:1213-1224 |
| F18 | Judge mutating the shared tree produces a transient FAIL | iter 198 | g3:693-696 |

#### G. A run or a write that never happened, reported as success

| ID | Pattern | Incident and numbers | Line |
|---|---|---|---|
| G1 | stdin not redirected: backgrounded `codex exec` blocks until the cap | World: "39-byte log, zero diff, 6 minutes". iter 111's own log shows the line; "survived only because stdin happened to EOF" | cf:19-23 |
| G2 | Directive not delivered: rc=0 for work never requested | iter 112 near miss: the `Write` of the directive file failed on a pre-existing file. Named class: "an exit code reporting success for work never requested" (earlier instances: silent z3 skip, silent `t.Skip`) | cf:24-30; g3:154-160 |
| G3 | rc=0 / `stopReason` from pi with no work | `stopReason` "fired on 0 of 4 real failures". OpenRouter corpus 08-18..08-22: "3 of 173 generations had no `finish_reason`", all with `completion: ""` | g3:381-382, 417-443 |
| G4 | Sandbox-denied destructive write passes inside, destroys outside | iter 327, 2026-09-04: an AC worded as a seeded write to the real `autopush.log`; first out-of-sandbox re-run "truncated that log from 92 lines to 1"; "the evidence is gone". Instance 1 (iter 326): four synthetic rows written into the real shared log. "it passed under the sandbox is not evidence of safety — only of confinement" | cf:68-112 |
| G5 | Auto-merge armed; PR never merged | motoko `#760`, 12h13m | g3b:305-344 |
| G6 | STATUS rotation deleted instead of moved | iters 171, 186 | g4:305-332 |
| G7 | STATUS rotation moved the whole queue | iter 127: 1,571 lines; exit 0 | g4:284-303 |
| G8 | Record committed over a stale base | iter 129 | g4:174-211 |
| G9 | Telemetry posted zeros | iter 190: chain total $0.0000 vs $0.1077 spent | g3:797-801 |
| G10 | Planner placeholders accepted | `MILESTONE_ID`, `auto-parse failed` | g3:236-237 |
| G11 | Message sent with body lost | iter 252 | g5:45-78 |
| G12 | A record's prose closed a live issue | iter 240: `#676`, `#612` | g4:99-141 |
| G13 | Designer rotation pointer silently overwritten by a sibling | iters 187, 188 (2026-08-13) | g3:17 |

#### H. Named general forms the text itself draws (OBS)

- "an exit code reporting success for work never requested" (cf:25-26) — the "vacuous-pass class".
- "guard the helper, miss the call site" — "this loop's own named recurring shape" (g4:264-265; also
  vp:107-108, 243-244, 409-410, 739; cf:50-51).
- "A remedy is an instrument and inherits the same burden of proof as the thing it verifies"
  (vp:162-163). Variants: "a mutation is an instrument too" (vp:234), "a default is an instrument
  too" (vp:292-293), "a criterion is an instrument too" (vp:1106), "a long document is an instrument
  too" (vp:491-492), "you are an instrument too" (g4:302).
- "a document is only as fresh as its OLDEST measurement" (vp:513-514).
- "an environmental explanation is always available for a symptom you caused" (vp:721-722).
- "when a shape has burned this loop twice in war stories, it belongs in the remedy list, not in the
  anecdote" (vp:256-257).

### 5.6 Who caught these (OBS; listed only where the text names the catcher)

| Caught by | Cases | Line |
|---|---|---|
| Independent judge / evaluator | C7 ("The evaluator then **added** a builtin"); D7 ("filed as BLOCKING by the evaluator against the controller's PR"); D15 instance 1 ("found by its own evaluator"); F13 ("in BOTH the gap was found by the judge rather than by the controller who wrote the mutants"); F14 (V1 log headline 333: "the judge proved the milestone's own headline test was measuring the milestone before it"); both round-N directive errors ("both caught by the judge rather than by the controller who wrote them") | vp:391, 560-561, 1274, 1309-1310; `design_docs/v1-mission-log.md:499`; g3:711-712 |
| Quorum reviewer | D1 (`gemini-3-1-pro` rejected the narrowed run) | vp:429 |
| Designer | D2, D3 ("all three caught by the DESIGNER rather than by the controller who wrote them") | vp:450-451 |
| Planner | C1 ("the planner had to refute it"); C3 (planner "re-checked on its own initiative", `gate-2-pick.md:483-484`); the third stale row in D5 | vp:146-147, 506-507 |
| Executor | D14 (stopped rather than assert a mutant built: "the correct call"); D17 (self-reported the need for the stabilizers and was overruled) | cf:55-56; vp:1024-1034 |
| Remote CI | D9, D10, D12, D15 instance 2, D16, D17, F16 | vp:811-812, 711, 1279, 990, 1029; g3b:51-67; g3:558-559 |
| Second independent instrument (SonarCloud new-code coverage) | F13 | vp:1328-1331 |
| A control the controller had paired with the check | B7, B11, C6 (on the second hit), B8 | vp:203-204, 254-255; g3b:153-154 |

Cases where independent review is recorded as having **failed**:
- D4: "Two reviewers cleared that doc across two full quorum rounds and neither caught it"
  (vp:481-482). Stated limit: quorum "reads for design soundness, not for internal consistency
  between a doc's evidence and its claims" (vp:482-483).
- D5: "five rounds and two reviewers missed all three rows" (vp:517-518); quorum reads "not for
  freshness against HEAD" (vp:516-517).
- D16: executor, judge and controller all certified a branch unreachable. "Adding reviewers did not
  help and could not have: independence in the *reviewer* does not buy independence in the
  *platform*" (vp:993-994).
- D17: judge and controller overruled a correct executor (vp:1031-1034).
- F12: broken "through a quorum, a sprint plan, an evaluator PASS and a Gate-3b green"
  (vp:1194-1195).
- F10 (World): "ten mutations, evaluator 93/100" on a gate with a blind enumerator (vp:1119-1120).
- F5 (World): "two quorum rounds read past it" (vp:1050).
- World iter-58: an executor deviation that was better than the plan — "the judge scored it −5
  anyway" (vp:834-835).

INF: in the cases the text attributes to a judge, the judge *ran something* (added a member,
reverted a hunk, varied `GOMAXPROCS`). In the cases where review is recorded as failing, the
reviewers read a document, or shared the author's platform. The text states the second half
directly (vp:482-483, 993-994); the first half is my reading of the instances.

### 5.7 Evidence that a written rule did not prevent recurrence (OBS)

- "the first time the rule existed and was still missed" (g3b:400), iteration 347.
- Iteration 319 "committed the mirror-image error after reading 318's rule at Gate 1 the same
  iteration" (vp:1016-1017).
- V1 iteration 252's message "failed identically in the same iteration that had just read World's"
  (g5:50-51).
- Rule 3e(a) "can be documented, cited, and still bought a third time" (cf:51-52).
- "a lesson recorded but not wired in is what produced instance 2" (vp:821).
- `set -- $res` "appears twice in this file already — both times as a *war story* ... neither time
  in THIS list" (vp:241-243).
- The stale-check remedy "stayed pointed at the file that shrank while the rules moved into files it
  does not cover" (SKILL:78-82) — a consequence of the split into resource files.

---

## 6. Rules about how much is written, and keeping records bounded

### 6.1 Explicit bounds (OBS)

| Record | Bound | Enforced by | Line |
|---|---|---|---|
| Dashboard | "≤40 lines, OVERWRITE never append"; "a snapshot, not a record" | nothing named | g4:65-67 |
| Gate-5 digest | "≤26 lines / ≤2,200 chars, exactly these sections, nothing else"; "HARD-CAPPED" | nothing named | g5:38-39, 100 |
| Key find (digest) | "≤2 sentences, ONLY if it should change Mark's priorities — else omit the row" | — | g5:112 |
| Live log | rotate when it "PASSES ~40 ENTRIES"; keep newest 20 | `ailang mission rotate-log --keep 20`, "verified lossless by test" | g4:30-39 |
| Index | one line per iteration, regenerated | same command | g4:38-42 |
| STATUS block | exactly 3 live stamps, each "a single line" | hand assertions (`grep -c "^## STATUS 2026"` = 3) | g4:280, 293 |
| Issue thread | weekly rotation, or >80 comments | hand | g5:139-144 |
| Skill edits | "Max ONE skill edit per iteration; requires ≥2 recorded frictions" | nothing named | g5:9-10 |
| Routing-policy change | "≥3 evidence rows" | nothing named | g5:13 |
| Work per iteration | "One backlog item per iteration" | — | SKILL:300 |
| Telemetry spool | "≤100 entries / 1 MiB, drop-oldest" | Go CLI | g3:838 |
| Always-loaded docs | 300 lines `CLAUDE.md`, 200 per rule, 500 per `SKILL.md` | `make check-context-docs` (`scripts/check_context_docs.sh`), with a shrink-only baseline | `.claude/rules/context-docs.md:60-67` |

Stated reasons, each from an incident:
- Dashboard: the owner's "long-lived thread was burning 14%/week of quota as cache-rebuild"
  (g4:63-65).
- Digest: owner directive 2026-07-31, "the github progress issues are very verbose" (g5:38-39);
  2026-08-31, "the report exists so Mark can PRIORITIZE" (g5:100-102).
- Thread rotation: "#329 hit 120KB/53 comments in 6 days" (g5:141).
- Context-doc caps: "`mission-control/SKILL.md` reached 4,201 lines with zero reference files — ~96k
  tokens before the skill does anything" (`.claude/rules/context-docs.md:69-70`).
- Index: the log "(2.8 MB, ~715k tokens) has not been [read in full] for a long time"
  (`design_docs/v1-mission-index.md:5-7`).

### 6.2 The stated principle for what goes where (OBS)

From `.claude/rules/context-docs.md` (91 lines, read in full; outside my assigned files but it is
the rule cf:4-5 cites):
- Three tiers: always-on, path-scoped, on-demand. "Default to on-demand." (:20-26).
- "Write the pointer, not the payload" (:47); "One home per fact" (:53).
- When a skill outgrows the cap "the fix is layering, not brevity" (:63).
- Split test: "if the agent needs it to take the next action, it stays; if it needs it to *justify
  or debug* an action, it splits. Move it verbatim, and diff the result: a split is a move, not a
  rewrite." (:74-77).
- "A pointer you cannot follow is worse than no pointer." (:79). `parser-developer` "advertised five
  `resources/*.md` files that were never written" (:83-85).
- A `paths:` glob that matches nothing "never loads, and never fails": the AILANG syntax rule was
  scoped to `stdlib/**` while the tree had `std/` (:37-39).

From the gate files:
- The issue thread "is a COMMUNICATION channel, not loop memory ... Do NOT mirror the STATUS entry
  into the issue." (g5:40-42).
- "No gate-by-gate narration, no routing-evidence dump, no war stories (those belong in Gate 4's
  charter/log record)." (g5:135-136).
- Log template: every section, "none" over omission (g4:94-95). A silent gap "reads as zero and is
  worse than a stated unknown" (g4:14-16).
- Do not write known-absent control literals into any record the loop later greps (g4:275-279).
- Closing keywords near `#N` only in the commit that ships the fix (g4:127-129).
- A third instance of a known mechanism gets no new note: "a new mechanism, which is why it earns a
  note rather than a louder restatement" (g3b:132-133).

### 6.3 What is not bounded (my measurements, plus OBS where cited)

- **No cap on a log entry.** Template is 14 lines; the 20 live V1 entries average 130 lines
  (min 56, max 208); the live log is 230 KB.
- **No cap on a STATUS stamp's size.** "Single line" is a line count. The three live V1 stamps are
  4,522, 6,568 and 5,382 characters.
- **No cap on the charter.** `v1-mission.md` is 930 KB / 4,908 lines; longest line 19,540 chars.
- **No cap on resource files.** The checker's size arm covers `CLAUDE.md`, rules and `SKILL.md`
  only (`scripts/check_context_docs.sh:38-40, 135-152`; its only mention of `resources` is the dead
  link arm). g3 is 857 lines / 88 KB with one 14,291-character line of 2,189 words (g3:17); vp is
  1,433 lines / 136 KB.
- **The baseline entry is far above the current size.** `scripts/context_docs_baseline.txt:19`
  lists `mission-control/SKILL.md 2781`; the file is now 620 lines (cap 500). INF: since the gate
  fails only on growth past the baseline number, the skill could re-grow to 2,781 lines without a
  red unless someone ratchets the number down; the baseline comment shows that is done by hand
  ("RATCHETED DOWN 2790 -> 2781 by V1 iteration 329", :14).
- **Caps are line counts, so long lines evade them.** INF from g3:17 and the STATUS stamps.
- **Dashboards are not checked.** Motoko's is 58 lines against the 40-line rule.
- **Appending is the default failure mode, and the project says so**:
  `scripts/check_context_docs.sh:18` lists "A SKILL.md grows without bound because appending is
  easier than filing."

### 6.4 Side effects of the accretion model that the text itself records (OBS)

- Duplication from moves: the rule 3o sentence is duplicated verbatim at g3:746; false-green (5) is
  written twice in cf (68-112 and 114-158) with small wording differences, although the header says
  "Nothing was reworded in the move"; the archive banner is written 8 times in the V1 log.
- Numbering collision: two rules labelled 3o (vp:1346, vp:1421).
- Contradictory rules that are each true for one harness: rule 4(a) "Bash cwd persists across calls"
  (vp:1427) versus the second 3o, "every bash invocation starts in the session's fixed CWD"
  (vp:1421). The second is "scoped by measurement rather than asserted universally".
- Stale self-description: vp header says 18 rules / 1,378 lines.
- Documentation as bias: "when a gate accumulates a long, vivid war story about an uncommon cause,
  the common cause needs re-promoting, or the documentation itself becomes the bias" (g3b:391-393).
- Layout as a bug source: "an emphatic rule about one tool becomes a bug in the tool beside it"
  (g5:76-78).
- Shared skill, per-mission formats: "anything this skill tells you to grep for is a claim about
  ONE mission's file format" (g4:244-245); bare literal paths are "fleet-global" (g4:72-74).
- The aggregate cost: harness share reached 55% and "cost it two weeks (iterations 309–348: 16 lines
  of compiler and stdlib)" (g5:26-27).

---

## 7. What I did not read

- `SKILL.md` except lines 225-309 (gate stubs, standing rules 1-6 head) and a grep of 78-84.
- `gate-0-preflight.md`, `gate-1-observe.md`: not read.
- `gate-2-pick.md`: only lines 482-507 (the provenance-label rule) plus grep hits. The quorum
  protocol, the "attended-only" harness rule and the "CRITICAL-PATH CHECK" that g5 depends on are
  there and unread.
- `role-spawn-routing.md`, `ref-drift.md`, `ci-health.md`: not read (g3/g3b/g4 point at the first
  two for detail on the spawn-pin hook and the shared-ref drift protocol).
- The inner-loop skills themselves (`design-doc-creator`, `sprint-planner`, `sprint-executor`,
  `sprint-evaluator`): not read. The evaluator's rubric, its scoring scale, the sprint JSON schema
  and the handoff format are defined there, not in g3.
- No script source was read except greps of `scripts/check_context_docs.sh` and the usage string in
  `cmd/ailang/mission_cmd.go`. Claims that a script "refuses" or "is verified by test" are the
  skill text's, not checked against code.
- Mission records: only the head of `design_docs/v1-mission-log.md` (lines 1-64), the head of the
  index, and size/count measurements. No log entry body or charter content was read, so I did not
  check whether real entries follow the template or whether real digests meet the 26-line cap.
- Nothing outside the sparse checkout; no GitHub issues or CI runs were consulted.

---

## 8. Consolidated inferences (all INF — mine, not the text's)

1. **The contract between stages is "the receiver re-measures", not "the sender certifies".** No
   stage's report is accepted: the controller re-runs the executor's gates outside the sandbox, the
   judge re-runs the controller's mutations, the controller reproduces the judge's findings, and the
   controller measures a reviewer's premise objection before forwarding it. The hand-off artifact is
   the thing itself (a diff, a doc with a verification log), never a summary of it.
2. **Almost all enforcement is prose addressed to the controller.** Script-enforced points I could
   identify from the text: the spawn-pin hook on `MISSION-ROLE`, `resolve-role-spawn.sh`,
   `derive-planner-lane.sh`, `mission-worktree.sh`, `mission-base.sh`, `mission_pi_run.sh`'s typed
   verdict, `mission-lane-dead.sh`, `ailang mission rotate-log`, `ailang chains post-iteration`,
   `make check-context-docs`. Everything in the false-green catalogue is a rule the controller is
   asked to remember, and section 5.7 lists seven places where the text records it not being
   remembered. Where the text names a durable fix it is usually "in the TOOL, not here" (g3:120) or
   "in code, not in memory" (g3b:420).
3. **The rulebook is itself subject to its own failure classes, and says so.** Remedies that printed
   nothing (PIPESTATUS), a fix that broke the sibling mission (stamp casing), a recommended endpoint
   that returns short (`check-runs`), a prescribed enumerator that hid ~2,500 cases (`%w` grep), a
   loud rule that leaked into the adjacent command (`--body-file`). The text's own summary is "a
   remedy is an instrument too".
4. **Bounds exist only where the owner complained or a tool enforces them.** Human-facing outputs
   (digest, dashboard, issue thread) have hard caps set by dated owner directives. Loop-facing memory
   (log entries, STATUS stamps, charter, resource files) has rotation but no per-item size cap, and
   the measured sizes are large (section 3.3). Rotation moves bulk out of the read path; it does not
   reduce what is written.
5. **Retro changes are rate-limited per iteration but not in aggregate, and the aggregate is what
   failed.** One skill edit per iteration at two frictions still produced iterations 309-348. The
   correction was an aggregate counter (harness share over 20 iterations, drift over 3 landings)
   reported to the human, and a move of harness work to attended sessions.
6. **Progressive disclosure fixed context cost and created a staleness hole.** Moving rules into
   `resources/` took `SKILL.md` from 4,201 lines to 620, and the text records that the existing
   stale-skill check then covered only the file that shrank (SKILL:78-82).
7. **Multi-mission sharing of one skill is a recurring source of defects**: bare literal paths
   (dashboard, rotation pointer, gh-issue pointer), per-mission stamp formats, a pinned older CLI,
   harness-dependent shell behaviour (cwd persistence). The mitigation is a proposal protocol
   (siblings propose, the owner corroborates first-party) and namespacing by `${MISSION_NAME}`.
