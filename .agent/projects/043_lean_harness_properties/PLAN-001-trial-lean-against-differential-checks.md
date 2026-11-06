# PLAN-001: a pre-registered trial — does the Lean method find what differential checks miss?

Date: 2026-11-03.
Status: **Pre-registered, not started.** This file and `trial/predictions.tsv` are frozen by the
hashes on the first lines of `trial/sequence.log`. The trial starts at W1 (§12).
Base: Motoko `43530c0a`. The target files are identical at `origin/main` `bb9883fb`. Toolchain
pins: AILANG `v0.54.14`, Lean `4.28.0` (core only), bun `1.4.4`. Foundation model: Claude Opus
5.5 at `xhigh` effort, in Claude Code, for every session in the trial.

Companion to: `RESEARCH-lean-harness-properties.md` §2 (the verdict this tests) and §10;
`evidence/diff/README.md`, "The three-way run" (the worked example and "what the proof added");
`042_improving_experimentation/RESEARCH-improving-experimentation.md` ("Keeping the evidence
credible", whose rules this plan follows); `034_ambiguous_tool_outcomes/evidence/acceptance-w2-8c996274/`
(the predictions-hashed-before-the-run pattern).

---

## 0. Rules of this document

- **Frozen.** After the hash lines in `trial/sequence.log` this file is not edited. Before W1, an
  amendment is a dated section appended at the end, with a new hash line. After W1, nothing in it
  changes: a departure is a **deviation**, logged in `sequence.log` when it happens and reported in
  FINDINGS.
- **Who may read it.** The operator, the planter and the adjudicator. **The arm sessions may not.**
  It is left out of the tree they work in (§7), and their briefs (Appendices A and B) are
  everything they are told.
- **Approval.** The operator approves this plan before W1. The approval is a line in
  `sequence.log`. The decision rule in §10 is the part that needs a person.

## 1. The question

The research note recommends adopting Kiro's method: model, differential test, prove, reproduce.
Its value over cheaper tools rests on one claim: **a proof about a model finds defects that
checks executed on the real code miss.** The worked example does not test that claim. Up to
length 4, a differential run of the two real functions showed everything the theorems state
(`evidence/diff/README.md`, "What the proof added"). The target files have no fix history to
replay: `journal.ail` has 8 commits and `session-journal.ts` 4, none of them a fix. So this trial
plants defects.

- **H-L** (the note's claim): with equal budgets and the same targets, arm B (Lean) detects
  defects that arm A (executed checks on the real code) misses, mainly defects whose smallest
  witness is larger than a small bound.
- **H-D** (the alternative): arm A detects about as much as arm B. The cross-language
  differential checks are what transfer, and Lean adds cost without detections.

## 2. Design at a glance

| Part | What |
|---|---|
| Arms | **A**: executed checks on the real code (twin against twin, property checks on generated inputs), no models. **B**: Kiro's steps 2-5 in Lean 4.28.0 |
| Targets | Six, T1-T6, each with registered properties (§3) |
| Replicates | Two independent sessions per arm per target: 24 sessions |
| Budget | 2 hours of session wall-clock per session, same model and effort for all |
| Defects | 16 planted by a separate planter session, sealed (§6), plus whatever is real |
| Blinding | Arms never see the seeds, this plan or each other's work (§7) |
| Scoring | Mechanical: a report detects a seed iff its reproduction fails with the seed and passes without it (§8) |
| Decision | §10, fixed now |

## 3. Targets and registered properties

All lines are at `43530c0a`. **Primary** properties count towards the decision. A secondary
property's intent is open or partly known to be violated, so results on it are reported but do
not count. Arms may add properties of their own, reported as exploratory (`X-n`).

**T1. The herdr environment gate**, a cross-language twin (MOT-118).
`readHerdrEnvironment` (`src/tui/src/herdr-agent-state.ts:157`) and `herdr_env_ready`
(`packages/motoko-ext-herdr/types.ail:1425`). Intent: the comment at `herdr-agent-state.ts:145`
("THEY MUST MOVE TOGETHER").
- **P1.1** (primary): for every value of `HERDR_ENV`, `HERDR_BIN_PATH` and `HERDR_PANE_ID`,
  each unset or any string, with unset passed to the AILANG side as `""`: the TypeScript gate is
  non-null iff `herdr_env_ready` is true.

**T2. The herdr failure vocabulary**, a cross-language twin.
`herdrFailureCode` and `herdrMeansAgentGone` (`src/tui/src/wake-waiter.ts:129`, `:142`), and
`failure_code` and `means_agent_gone` (`packages/motoko-ext-herdr/types.ail:1160`, `:1198`, via
`failure_shape` `:1127`). Intent: the comment at `wake-waiter.ts:125` ("the TS twin of"), and
`means_agent_gone`'s comment ("narrow on purpose").
- **P2.1** (primary): for every exit code and stderr, with no spawn error,
  `herdrMeansAgentGone` equals `means_agent_gone`.
- **P2.2** (secondary): `herdrFailureCode` equals `failure_code`. The two vocabularies are
  known to differ outside herdr's JSON (K6), and whether they are meant to agree there is open.

**T3. The journal writer twin and the round trip** (ADR-003 D1, D4).
`SessionJournal` (`src/tui/src/session-journal.ts:139`; "THE TWIN", `:21`) and
`journal_lines_of_records` (`src/core/journal.ail:2137`), judged by `fold_journal` (`:1677`).
Intent: `session-journal.ts:21-27` ("Where they disagree the FOLD is the judge").
- **P3.1** (primary): for every sequence of wire events a run can emit, the journal the host
  writes and the journal the twin writes fold alike. Either both are refused with the same
  refusal id, or both are accepted with equal `history` and `dangling`.
- **P3.2** (primary): `fold_journal(journal_lines_of_records(h, rs), leaf)` accepts every
  record list `rs` that a run can emit, and its `history` is the one the fold's rule 3 defines
  for `rs` (`journal.ail:1266-1270`). That is: the seed, then one message per appended entry,
  where an entry with `replaces_previous` takes the place of the message before it, and from the
  latest `history_replaced` onwards, that entry's messages and the entries after it.

**T4. The digest chain** (`src/core/journal.ail:242-300`). Intent: the comments on
`chain_digest_over` and `chain_digests_over` ("the prefix chain, not just its last element").
`sha256Hex` is treated as an injective black box.
- **P4.1** (primary): `chain_digests_over(b, xs ++ ys)` equals `chain_digests_over(b, xs) ++
  chain_digests_over(chain_digest_over(b, xs), ys)`.
- **P4.2** (primary): `length(chain_digests_over(b, ms))` equals `length(ms)`, and for a
  non-empty `ms` its last element is `chain_digest_over(b, ms)`.

**T5. The fold's path** (`path_up`, `src/core/journal.ail:1403`, and `find_entry` above it).
Intent: its comment and ADR-003 D4 rule 1 ("stopping at the first repeated id"; "ROOT FIRST").
- **P5.1** (primary): `path_up` terminates on every entry list, including parent cycles.
- **P5.2** (primary): no id occurs twice in the result.
- **P5.3** (primary): the result is a chain. Each entry's `parent_id` is the id of the entry
  before it, and if the start id names an entry, the last entry has that id.

**T6. Compose's output clipping** (`truncate_utf8_by_bytes`,
`packages/motoko-ext-compose/store.ail:19-29`). Intent: the function's name.
- **P6.1** (primary): for `n ≥ 0`, the result's byte length is at most `n`.
- **P6.2** (primary): the result's bytes are a prefix of the input's bytes, and the input is
  returned unchanged when it fits.
- **P6.3** (secondary): a valid UTF-8 input gives a valid UTF-8 result. Known violated (K2).

## 4. Known before the trial

These do not count as discoveries for either arm. Reproducing one is recorded as a sanity check.

| Id | What | Source |
|---|---|---|
| K1 | The fold's pairing check admits a duplicate result and a result after a user message | RESEARCH §6.1; reproduced, `evidence/diff/README.md` |
| K2 | `truncate_utf8_by_bytes` can split a multi-byte character | RESEARCH §7 |
| K3 | Compose's and core's `stdout_bytes` count runes while compose's cap counts bytes | RESEARCH §7 |
| K4 | The elided output exceeds `max_stdout_bytes` by the notice's length | RESEARCH §7 |
| K5 | `std/bytes.toString` does not repair invalid UTF-8, against its documentation | RESEARCH §7 |
| K6 | Outside herdr JSON, `failure_code` and `herdrFailureCode` use different codes: empty stderr is `herdr_failed_silently` against `herdr_cli_rejected`, and "nested herdr" text is `nested_herdr` against `herdr_cli_rejected` | Read while writing this plan |
| K7 | **Candidate, not run.** `failure_shape` tests for `nested herdr` before it tests for JSON, so a herdr JSON error whose text contains `nested herdr` is classified by that text in AILANG and by its code in TypeScript. With code `agent_not_found`, `means_agent_gone` and `herdrMeansAgentGone` would differ (P2.1) | Read while writing this plan; reachability unknown |

## 5. The arms

Both arms get the same tree, the same targets and properties, the same model and effort, the
same budget, and the worked example in `evidence/` as a template. They differ only in method.

**Arm A, executed checks.** Programs in TypeScript (bun) and AILANG (`ailang run`) that call the
real functions. The arm chooses its generators: exhaustive up to a bound, random, recorded
inputs, or a mix. Twins are compared with each other. Each other property is compared with an
executable statement of it. Lean and other models of the functions are not allowed. Templates:
`enumerate.ts`, `enumerate_fold.ail`, `compare_fold.awk`.

**Arm B, Kiro's method.** For each target, a Lean model with a header naming the source file
and lines (step 2). A differential test of the model against the real code (step 3). A proof of
each property, or a `bug_` theorem stating a concrete counterexample (step 4). A script
reproducing that counterexample on the real code (step 5). Arm B may execute the real code
**only** for steps 3 and 5. Nothing reported as proved may use `sorry` or `native_decide`.
`#print axioms` is recorded for every theorem. Templates: `PairingModel.lean`,
`enumerate.lean.tail`, `run_diff.sh`.

**Both.** Reading the code is allowed, and a detection by reading counts for the arm that made
it, with its route recorded (§8). The repository's own tests may be run. Each session runs once,
fresh, in its own copy of the trial tree. Its clock starts at its first tool call. Work after 2
hours does not count; work begun before the cap and unfinished is reported as unfinished.

## 6. The seeds

A **planter** session plants them. It runs no arm and never sees an arm's work.

| Class | Count | What |
|---|---|---|
| S1 | 3 | An ordinary slip whose smallest witness is within the small bound |
| S2 | 5 | A slip whose smallest witness is **beyond** the small bound. This class carries H-L |
| S3 | 4 | A slip at a boundary between two representations: bytes and runes, unset and empty, JSON text and value, `undefined` and `""` |
| S4 | 2 | A change outside the six targets' functions that breaks a registered property end to end, in the way MOT-118's third copy, `buildChildEnv`'s allowlist, did |
| E | 2 | A behaviour-preserving change inside a target function: a refactor, not a defect |

**The small bound** is 4 elements for lists (messages, records, entries) and 8 bytes for strings.

**Each seed must**:
1. be one plausible slip of at most 3 changed lines: a changed operator or comparison, an off-by-one,
   a wrong variable or argument order, a dropped case, or a unit confusion, in 039's operator
   vocabulary. It may not add a numeric constant that is not already in the function.
2. leave every existing gate green on the all-seeds tree: `make check_core`, `make test`,
   `make verify_core`, `cd src/tui && bun run test`, and `ailang test` on every edited AILANG
   module. A seed an existing gate catches tests nothing this trial asks about.
3. come with a witness: a concrete input that violates a registered property on the tree with
   only that seed applied, together with the witness's size. An S4 seed's witness is an end-to-end
   scenario instead. An E seed instead comes with a log showing that every registered property of
   its target gives the same results with and without it, over the alphabets in Appendix C.
4. for S2, come with a log showing that an exhaustive search up to the small bound finds **no**
   violation with only that seed applied, over the alphabets in Appendix C.

At most one seed per function. Every target gets at least one seed of S1-S3, except that the
planter may leave at most one target without any, chosen and sealed like the rest. If fewer than
4 valid S2 seeds can be made, the planter records how many, and §10 (a) becomes void.

**Sealing.** The manifest (`manifest.tsv`: id, class, target, file:line, patch, witness, witness
size, validation log) is encrypted with `openssl enc -aes-256-cbc -pbkdf2`, under a passphrase
the operator holds. The plaintext is deleted. Only the hashes are committed: the plaintext
manifest's, the encrypted file's and the seeded tree's.

## 7. Blinding and the trial tree

The trial tree is `43530c0a`'s tracked files, plus `.agent/projects/043_lean_harness_properties/`
from this plan's commit without `PLAN-001-*.md` and `trial/`, plus the seeds. It has no `.git`
and no `.agent/github/`. Each session gets a fresh copy. Its outputs go to a directory outside
every tree, named by arm, target and replicate.

Blinding is **by instruction, checked by audit**, not by isolation. The machine holds unseeded
checkouts. Each arm session is told not to read outside its copy and not to run `git`. At W4 the
adjudicator searches every arm transcript for paths outside the copy and for `git`. A breach
**voids that session's seed results**. More than one voided session in an arm voids the trial for
the decision (§10). Planted-fault metadata never enters an arm's context, as 042 requires.

## 8. Reports and adjudication

Each session ends with a `reports.tsv` (Appendix D), possibly empty. Every report carries a
reproduction: one command, run from the tree root, that exits 1 when the defect is present and
0 when it is absent, within 120 s. A report without one is counted as **unreproduced**: it is
neither a detection nor a false report, and it is listed. An arm B `bug_` theorem with no
real-code reproduction is unreproduced, as in Kiro's step 5.

The adjudicator builds, from the revealed manifest, the seeded tree `T`, and for each seed `s`
the tree `T−s` with that seed's patch reversed. It also builds the unseeded base `B0`. It runs
every reproduction on all of them. Exit codes other than 0 and 1, and timeouts, are recorded as
**errors**, not as detections.

- **Detects seed `s`**: the reproduction exits 1 on `T` and 0 on `T−s`.
- **Real defect**: it exits 1 on `T` and on `B0`, and detects no seed. A real defect not in §4 is
  **unknown**. Unknown real defects are re-run on `origin/main` at W5.
- **Seed interaction**: it exits 1 on `T` and 0 on `B0`, and detects no single seed. Pairs of
  seeds are then tried. If a pair explains it, it detects both seeds; otherwise it is a false
  report.
- **False report**: a report whose reproduction exits 0 on `T`.
- **Same defect, across reports or arms**: for seeds, the same seed. For real defects, the
  operator's judgement that one fix closes both, written down with its reason.
- **Reachability** of an unknown real defect (Kiro's steps 6 and 7): the operator's judgement,
  written down. It matters only for §10 (b).

## 9. Outcomes

They are reported in 042's dimensions, each per arm, per replicate, and as the mean of the two.

| 042 dimension | Measure here |
|---|---|
| Useful findings | `D(c)`: seeds of class c detected, for S1-S4; unknown real defects `U`, with the reachable ones |
| Incorrect conclusions | `F`: false reports, those at an E seed's location separately |
| Misses | Seeds not detected, by class |
| Investigation cost | Tokens (input + output, as Claude Code reports them, the same measure for both arms), wall-clock, targets unfinished at the cap |
| Human involvement | The operator's time on reachability and same-defect calls |
| Transfer | Not measured: one codebase, planted seeds. Stated as a limit |
| Development cost | Planter and adjudicator tokens and time, reported once |

Secondary measures: the route of each detection (proof, execution, reading); how many times
arm B's differential test forced a model change (the transcription gap, counted); the axiom
report; exploratory properties and what they found; agreement between the two replicates.

## 10. Decision rule

Write `D̄_X(c)` for arm X's mean number of class-c seeds detected over its two replicates,
`D_Xi(c)` for replicate i, `n2` for the number of valid S2 seeds, `U_B\A` for the unknown real
defects arm B found in either replicate and arm A found in neither, and `F̄_X` for mean false
reports.

- **L: Lean earns a standing place** if `F̄_B ≤ F̄_A + 2` and at least one of:
  - **(a)** `n2 ≥ 4`, `D̄_B(S2) − D̄_A(S2) ≥ 1.5`, `D̄_B(S2) ≥ n2 / 2`, and **each** arm B
    replicate detects more S2 seeds than **each** arm A replicate;
  - **(b)** `U_B\A ≥ 1`, with at least one of those defects judged reachable by the operator.
- **D: differential checks suffice** if not L and `D̄_A(S1+S2+S3) ≥ D̄_B(S1+S2+S3) − 1`.
- **X: mixed** otherwise.
- **Void** if more than one session of either arm is voided (§7), or more than two sessions of
  either arm end unfinished on more than half of their target's primary properties. The results
  are still written up; whether to re-run is the operator's decision.

The counts are small and there are two replicates. This rule is a commitment made in advance,
not a test of significance, and FINDINGS says so.

**Consequences.**
- **L.** The note's verdict stands. §10 item 7, `make verify_lean`, is scoped to the properties
  on which arm B detected what arm A did not.
- **D.** The RESEARCH note gets a dated marker: the verdict becomes "adopt cross-language
  differential and property checks as standing tests; use Lean only where a person names a
  property that must hold for every length". §10 item 7 is dropped.
- **X.** Nothing changes automatically. The operator decides with FINDINGS in hand.
- **In every outcome**, arm A harnesses that detected something are re-run on `B0`, and those
  that pass there are proposed as standing tests in a follow-up.

## 11. Predictions

`trial/predictions.tsv`, hashed with this file, is authoritative. In short: both arms catch the
S1 seeds; arm A catches most S2 seeds with random inputs well past the bound, so arm B leads S2
by about one; arm A leads S3; neither catches S4; arm B costs at least twice the tokens and
leaves T3 unfinished. The predicted outcome is **D** (about 60%), with L about 25% and X about
15%. A miss is recorded as a miss.

## 12. Sequence of work

| Step | Who | What is committed |
|---|---|---|
| W0 | This session | This plan and `predictions.tsv`, hashed in `sequence.log`. Amendments until W1, each with a new hash line |
| W0.5 | Operator | Approval line in `sequence.log` |
| W1 | Planter | Seeds planted, validated and sealed (Appendix C). `sequence.log`: the three hashes. **The trial starts here** |
| W2 | 24 arm sessions | They may run in parallel. As each ends, the sha256 of its output directory goes into `sequence.log` |
| W3 | Operator | Once all 24 have ended: the manifest decrypted, its hash checked against W1, then the manifest and every output directory committed under `trial/runs/` |
| W4 | Adjudicator | The blinding audit, then §8's procedure as a script, `trial/scripts/adjudicate.sh`, and its table. The operator's reachability and same-defect calls |
| W5 | Adjudicator, operator | `FINDINGS-001`: results against predictions, the §10 outcome, unknown real defects re-run on `origin/main`, and the consequence applied |

## 13. Threats and limits

- **Same model in both arms.** The trial compares two methods as this agent executes them, not
  in general. A later model is a separate comparison (042: "keep model changes separate").
- **Two replicates.** They give some sense of the variation in live behaviour, not a
  distribution.
- **Planted defects are not real defects.** The planter knows the property list and the bound,
  so its seeds may be easier or harder than history's. The realism constraints (§6) limit this
  and cannot remove it. No historical defects exist in these targets to use instead.
- **The property list is given.** This tests checking, not Kiro's step 1, finding what to state.
  Exploratory properties are reported but do not decide anything.
- **The budget is a choice.** Two hours may favour the cheaper arm on T3, where a Lean model of
  the writer and the fold is large. Unfinished targets are reported as such, and the void
  condition bounds how much they can decide.
- **S4 has two seeds.** It can show the blind spot exists; it cannot size it.
- **Blinding is audited, not enforced.** §7 voids what it catches; a read that leaves no trace in
  a transcript would not be caught.
- **K7 is now known.** Writing this plan removed one candidate discovery from T2.

---

## Appendix A. Arm A brief, verbatim except for the bracketed fields

> You are working in a snapshot of the Motoko repository at `[copy]`. Write all your output to
> `[out]`. Do not read anything outside those two directories, and do not run `git`.
>
> Target: `[Tn and its functions, from PLAN §3]`. Properties: `[its P-ids and statements, from
> PLAN §3]`.
>
> Find every violation of these properties that you can show on the real code, and any other
> defect in these functions. The snapshot may contain defects, some introduced deliberately and
> some not. It may also contain none.
>
> Your method is **executed checks on the real code**. Write programs in TypeScript (bun) and
> AILANG (`ailang run --relax-modules`) that call the real functions. Generate inputs any way you
> choose, and compare twins with each other and other functions with an executable statement of
> the property. Do not write Lean or any other model of these functions. The files under
> `.agent/projects/043_lean_harness_properties/evidence/diff/` (`enumerate.ts`,
> `enumerate_fold.ail`, `compare_fold.awk`) show the style.
>
> You have 2 hours from your first tool call. Deliver to `[out]`: `reports.tsv` in the format
> below, every harness you wrote, and `SUMMARY.md`, saying what you checked, with which
> generators, and up to what size. `[Appendix D, verbatim]`

## Appendix B. Arm B brief, verbatim except for the bracketed fields

> You are working in a snapshot of the Motoko repository at `[copy]`. Write all your output to
> `[out]`. Do not read anything outside those two directories, and do not run `git`.
>
> Target: `[Tn and its functions, from PLAN §3]`. Properties: `[its P-ids and statements, from
> PLAN §3]`.
>
> Find every violation of these properties that you can show on the real code, and any other
> defect in these functions. The snapshot may contain defects, some introduced deliberately and
> some not. It may also contain none.
>
> Your method is **Kiro's**, as `.agent/projects/043_lean_harness_properties/RESEARCH-lean-harness-properties.md`
> §1 describes it:
> (1) model the functions in Lean 4.28.0, core only, no Mathlib, no Lake, with a header naming the
> source file and lines;
> (2) test the model against the real code on generated inputs, and fix the model until they
> agree, counting each fix;
> (3) prove each property, or state a `bug_` theorem with a concrete counterexample;
> (4) reproduce each counterexample on the real code with a script.
> You may execute the real code **only** for (2) and (4). Nothing you report as proved may use
> `sorry` or `native_decide`. Record `#print axioms` for every theorem. The files
> `PairingModel.lean`, `diff/enumerate.lean.tail` and `diff/run_diff.sh` in that project show the
> style.
>
> You have 2 hours from your first tool call. Deliver to `[out]`: `reports.tsv` in the format
> below, every model, theorem and script you wrote, the axiom report, and `SUMMARY.md`, saying
> what you proved, what you could not, and how many times step (2) changed the model.
> `[Appendix D, verbatim]`

## Appendix C. Planter brief, in substance

Read §3 to §7 of this plan. Plant §6's seeds in a fresh worktree at `43530c0a`, applying each
rule there. Validate them, including the S2 exhaustive searches over these alphabets:

- **T3:** appended-message lists up to 4 over the eleven messages of `evidence/diff/enumerate.*`,
  with `enumerate_fold.ail`'s prologue and epilogue; for the host side, the same messages as
  wire events.
- **T4:** message lists `xs`, `ys` with `|xs| + |ys| ≤ 4`, over the same eleven messages.
- **T5:** entry lists up to 4, with ids from `{e1..e4}` and parent ids from `{"", e1..e4}`,
  started at every id.
- **Strings (T1, T2, T6):** every string up to 8 bytes over `{a, 1, space, ", é, €}`. For T2,
  exit codes `{-1, 0, 1, 2, 3}`. For T6, `n` from 0 to 9.

Build the trial tree (§7). Seal the manifest (§6). Hand the operator the three hashes and nothing
else. Do not keep a plaintext copy anywhere an arm session could read.

## Appendix D. `reports.tsv`

Tab-separated, with a header row:

| Column | Content |
|---|---|
| `report_id` | `[arm][replicate]-[target]-[n]`, e.g. `A1-T4-2` |
| `property` | A registered id (`P4.1`) or an exploratory one (`X-1`, stated in `SUMMARY.md`) |
| `route` | `proof`, `execution` or `reading`: how the defect was first seen |
| `claim` | One sentence: what is wrong, on which input |
| `repro` | One command from the tree root. Exit 1 when the defect is present, 0 when absent, within 120 s |
| `witness` | The concrete input |
| `notes` | Anything else, such as reachability if known |

---

## Amendment A1, 2026-11-03, before W1

Made after the operator's approval and before any seed exists. It changes how the trial is run,
not what it measures, and §10 is untouched.

1. **A dry run, W0.9, before W1.** One arm A session and one arm B session, 20 minutes each, run
   at the same time on an **unseeded** tree with target **T0**, the worked example:
   `pair_step` and `finish_fold` (`src/core/journal.ail:1634`, `:1715`) against `updatePending`
   (`src/tui/src/session-journal.ts:865`). Its property is **P0.1**: for every history the fold
   accepts in which no call id is empty and no tool message carries calls,
   `exit.pending_tool_calls` equals `SessionState.dangling`. The tree already holds a solution
   for T0 in `evidence/`; that does not matter, because the dry run tests the plumbing:
   - the tree builds;
   - AILANG imports resolve and bun and Lean run from the copy;
   - the cap and the stop work;
   - the deliverables appear;
   - the deny rules (item 4) hold, and the audit (§7) can be run.

   Nothing from it counts. Its record goes to `trial/dryrun/` and `sequence.log`. If it shows a
   fault in this plan's procedure, the fix is a further amendment before W1. A fault in how the
   arms performed is not a reason to change anything.
2. **Launch.** Every session is a fresh Claude Code session (`claude --model claude-opus-5-5
   --effort xhigh --permission-mode bypassPermissions`) in its own herdr pane, in a herdr tab
   kept for the trial. This orchestrating session launches the sessions and sends each brief as
   its first prompt. The trial's files live under `/home/motoko/trial-043/`, outside every
   checkout. For each session, its tree copy is the working directory, and its output
   directory is added with `--add-dir`.
3. **The trial tree also leaves out** `AGENTS.md`, `tools/code-graph/AGENTS.md` and `.claude/`.
   Claude Code loads them, and they tell a session to work through git worktrees, which the
   briefs forbid.
4. **Read-blinding is enforced where Claude Code can see it, and audited everywhere.** Each arm
   session runs with `--settings` deny rules on reads of `/workspaces/**`, `/tmp/claude-1001/**`,
   `/home/motoko/.claude/**`, the planter's directory and every other session's tree and output
   directory, and on `git`. A test before this amendment showed that these rules refuse the Read
   tool and any Bash command that names a denied path. They do not see a path a program opens at
   run time, and they do not restrict writes. So §7's transcript audit stands unchanged, and it
   also covers programs the session ran.
5. **Batches.** Eight sessions at a time: two targets per batch, with the A1, A2, B1 and B2
   sessions of each target running together, so that both arms share CPU load equally. The order
   is fixed: (T1, T4), then (T2, T5), then (T3, T6). The 8-core machine is the reason.
6. **The clock.** A session's 2 hours start when its brief is sent. At 1 h 50 min the
   orchestrator sends every session the same line: "Ten minutes left: write your deliverables to
   [out] now." At 2 h it interrupts the session (Esc) and hashes the output directory as it stands.
7. **The planter** works in a fresh git worktree at `43530c0a` and in
   `/home/motoko/trial-043/planter/`. **The operator runs the encryption step themselves** in the
   planter's pane (`! openssl enc -aes-256-cbc -pbkdf2 ...`, with the passphrase typed at the
   prompt), so the passphrase never enters any session's context. After sealing, the planter's
   worktree and plaintext files are deleted. Its transcript is kept as the record; it lives under
   `/home/motoko/.claude/`, which item 4 denies to the arms.

## Amendment A2, 2026-11-03, before W1

Found while building the trial tree, before the dry run. It changes how the trial is run, not
what it measures.

1. **The trial tree also leaves out `.mcp.json`.** It would ask each new session to approve
   project MCP servers, which stalls startup, and it would give arm sessions Linear and Obsidian
   access. Sessions also launch with `--strict-mcp-config` and no MCP configuration, so they have
   no MCP tools at all.
2. **The operator scripts are in `trial/scripts/`:** `build_tree.sh`, `settings.py`, `brief.py`,
   `launch.sh`, `clock.sh` and `audit.py`. They are how §7 and amendment A1 are carried out, and
   `brief.py` renders Appendices A and B verbatim. Changes to them before W1 are logged in
   `sequence.log`; after W1, any change is a deviation.
3. **A refused attempt is not a breach.** The audit (§7) counts a tool call that names a denied
   location, or runs `git`, as a breach only when the call was not refused by the deny rules. A
   refused call revealed nothing, so it is listed as a refused attempt and voids nothing.

## Amendment A3, 2026-11-03, after the dry run and before W1

The dry run (A1 item 1) is recorded in `trial/dryrun/README.md`. Nothing from it counts. This
amendment changes what it showed needs changing, and §10 is untouched.

1. **Known before the trial, added to §4.** The dry run's arm A found these on the unseeded
   code, and the operator's re-run of its reproductions exited 1 for each. Reachability is
   unknown. They sit in T3's files, so a T3 arm may meet them, and they do not count as
   discoveries.

   | Id | What |
   |---|---|
   | K8 | `SessionJournal.replaceLastHistoryMessage` runs `updatePending` on the replacement without undoing the replaced message, so after a `replaces_previous` append, `exit.pending_tool_calls` and the fold's `dangling` can differ in either direction |
   | K9 | `history_replaced` resets the host's open set to `[]` without reading the replacement messages, while the fold pairs them and can report their trailing calls as dangling |
   | K10 | `strip_dangling` selects the message to strip by `seq`, and every message of one `history_replaced` entry shares a `seq`, so a reused dangling id is also stripped from an earlier, answered assistant, leaving an orphan tool result that the transcript check accepts |
2. **The stop ends the session.** At the cap, after the Esc, every process whose working
   directory is in the session's directory is ended, Claude Code and its background jobs
   included. Then the output is hashed, and then the session's tab is closed (`clock.sh`).
3. **A session's own scratchpad is its own.** The audit treats
   `/tmp/claude-1001/<the session's cwd key>/` as part of the session (`audit.py`).
4. **A limit, named.** A process listing can show other sessions' command lines, and nothing
   short of isolation prevents that. The audit lists any tool result that shows another
   session's directory as a note, and the adjudicator judges it. A read of another session's
   directory is still a breach.
5. **Scripts.** `launch.sh` answers Claude Code's folder-trust prompt, which is the only prompt
   it answers. It builds an arm's tree from the planter's sealed tarball. Appendix C is made
   concrete as `trial/scripts/planter_brief.md`, which the planter is sent verbatim.
