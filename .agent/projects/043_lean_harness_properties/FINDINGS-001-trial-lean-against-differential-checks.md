# FINDINGS-001: the trial's results — outcome D, differential checks suffice

Date: 2026-11-05.
Status: **Findings of PLAN-001 (W5).** The §10 outcome is **D**. Its consequence is applied: the
research note has a dated marker that points here, and its §10 item 7 is dropped. This note is
the dated sibling that revisits `RESEARCH-lean-harness-properties.md` §2. That note is not edited
below its marker.
Written by: t043-findings (Claude Code session `9670dea1`), from the record only:
- PLAN-001 with A1-A3;
- `trial/adjudication/`, `trial/runs/` and `trial/sequence.log`;
- the 24 arm transcripts;
- the planter's and the adjudicator's transcripts, for their token counts and times only.

No other transcript was read, and the operator's views were not asked.
Grounded at: the trial tree (`43530c0a` plus the seeds), and `origin/main` `09c4f48e` for §5.
Toolchain: AILANG v0.54.14, Lean 4.28.0, bun 1.4.4.
Record:
- `trial/findings/`: the tables behind every number here, the runs and their hashes;
- `trial/scripts/w5_*`: the scripts that made them;
- `trial/sequence.log`, from 2026-11-05T19:13:55Z: every W5 step and decision.

**How to read the numbers.** The counts are small, and each arm has two replicates. §10's
decision rule is a commitment made before the trial, not a test of significance, and nothing
below claims significance. For scale: the two arm A replicates differ from each other by one
S3 seed, and that is as large as any difference between the arms in seeds.

---

## 1. In one paragraph

Both arms detected every S1, S2 and S4 seed in both replicates. On S3, arm A detected 2.5 seeds
on average and arm B 3. Arm A's one miss was A2's T6 driver, which could not run without the seed
it was reporting. Neither arm made a false report, and no report detected an E seed. On primary
properties the arms found eleven unknown real defects between them: arm A ten, arm B nine.
Arm B found one that arm A did not, D9, and D9 is not shown reachable. So L fails on (a) and on
(b), and D holds: `D̄_A(S1+S2+S3) = 9.5 ≥ D̄_B(S1+S2+S3) − 1 = 9.0`.

Cost and process:
- **Tokens.** Arm B used 0.91 times arm A's tokens, not the "at least 2" predicted.
- **Time.** No session ran out of time. Each one ended its own work 22 to 70 minutes into its
  120-minute budget.
- **Route.** In both arms almost every detection was first seen by reading the code. Proof was
  the first route for one seed in one replicate.
- **Predictions.** 9 hits and 9 misses.

**Two things carry the outcome.**
1. **D9's reachability call.** Had the operator judged D9 reachable, (b) would hold and the
   outcome would be L.
2. **D's margin.** D's inequality holds by half a seed.

## 2. The §10 outcome, clause by clause

### 2.1 What is counted, and how

**W4's counting decisions** (`sequence.log` 18:25:21Z) are used as made:
- A seed counts once per replicate. A replicate's count is the union over its six sessions.
- A detection counts whatever property its report names. All eight S4 detections are X-n
  reports.
- Only real defects on primary properties count towards U.

**The operator's calls** (`adjudication/CALLS.md`) stand:
- D1 is K7, so it is known.
- D2-D12 are unknown.
- Of those, only D10 is reachable.

**One W5 rule, for U per replicate (19:35:48Z).** A replicate found a defect if any of its
reports is in that defect's CALLS.md group, whatever property the report names. This follows
CALLS.md's "Who found what". It changes A2's U and B2's U (§3.1). It does not change `U_B\A`.

### 2.2 Void conditions

**Voided sessions.** None in either arm. AUDIT.md rules 0 breaches and 0 refused attempts. The
condition is "more than one in either arm", so it is not met.

**Unfinished sessions.** §10 voids the trial if "more than two sessions of either arm end
unfinished on more than half of their target's primary properties". PLAN-001 does not define
"unfinished", so W5 used this rule (19:35:48Z).

A session is **unfinished** on a primary property when its `SUMMARY.md` gives that property no
conclusion reached by its arm's method. Two kinds of conclusion count:
- a violation with a reproduction that exits 1 on the tree as the session left it;
- "holds", backed by a completed check over a stated input space (arm A) or by a proof with no
  `sorry` or `native_decide` (arm B).

Whether a conclusion is right is §8's business, not this rule's.

| Target | Primary properties | Conclusion, in all four sessions |
|---|---|---|
| T1 | P1.1 | Violated, reproduced. Arm B also proves the negation and the exact disagreement set |
| T2 | P2.1 | Violated, reproduced, through eight mechanisms in every session |
| T3 | P3.1, P3.2 | Both violated, reproduced. Arm B also proves each on a fragment: t3-b1, P3.1 without `session_resumed` and `first_kept`, and P3.2 for single runs; t3-b2, P3.1 without resume, and P3.2's rule 3 on append-only runs |
| T4 | P4.1, P4.2 | P4.1 violated. P4.2's last-element half is violated and its length half holds: checked by arm A, proved by arm B |
| T5 | P5.1, P5.2, P5.3 | P5.1 and P5.2 hold: checked by arm A, proved about the model by arm B. P5.3 violated, reproduced |
| T6 | P6.1, P6.2 | P6.1 violated. t6-a2's reproduction errors on B0 (§3.3), but it is still a conclusion. P6.2 holds: checked by arm A, proved by arm B |

So no session in either arm is unfinished on any primary property, and the trial is **not
void**.

The transcripts agree. Each session ended its own last turn 21.7 to 69.7 minutes after its
brief, and then waited until the ten-minute line (§3.4).

The judgement rests on line-numbered quotes that three read-only helper agents extracted from
all 24 `SUMMARY.md` files. The T3 arm B summaries, the step (2) counts and every axiom file
were also read by hand.

### 2.3 L: does Lean earn a standing place?

| Clause | Value | Met |
|---|---|---|
| `F̄_B ≤ F̄_A + 2` | 0 ≤ 0 + 2 | yes |
| (a) `n2 ≥ 4` | n2 = 4 (W1) | yes |
| (a) `D̄_B(S2) − D̄_A(S2) ≥ 1.5` | 4.0 − 4.0 = 0 | **no** |
| (a) `D̄_B(S2) ≥ n2 / 2` | 4.0 ≥ 2 | yes |
| (a) each arm B replicate detects more S2 seeds than each arm A replicate | B1 4, B2 4; A1 4, A2 4 | **no** |
| (b) `U_B\A ≥ 1` | {D9}: 1 | yes |
| (b) at least one of them judged reachable | D9: "Not shown reachable" (operator, 18:59:42Z) | **no** |

Neither (a) nor (b) holds, so **not L**.

### 2.4 D: do differential checks suffice?

| | A1 | A2 | mean | B1 | B2 | mean |
|---|---|---|---|---|---|---|
| D(S1+S2+S3) | 10 | 9 | **9.5** | 10 | 10 | **10.0** |

`D̄_A(S1+S2+S3) = 9.5 ≥ D̄_B(S1+S2+S3) − 1 = 9.0`. Not L, and D's condition holds, so the
outcome is **D**.

### 2.5 What the outcome rests on

- **D9.** It is the only defect that could have decided (b), and the call on it rests on one
  route followed in code and one probe. The probe showed that bash tool output passes
  `encode`, which writes U+FFFD. CALLS.md says what was left: "Not examined: any other place
  where a `Message`'s content is built from text that never passed through `encode`. Nothing
  was run end to end." If D9 were shown reachable, the rule as written would have given L. W4's
  call stands, and this note does not re-score. It is the dependency an operator would follow
  first.
- **The margin.**
  - If arm A had found one S1-S3 seed fewer, `D̄_A` would be 9.0 and D would still hold, with
    equality.
  - Two fewer would have given X.
- **A2's s14.** A2-T6-1's claim is s14's defect. Its driver calls `Str.length` and relies on an
  import that only s14 adds, so it exits 2 on B0 and on T−s14. By §8 an error is not a
  detection. Counted as one, arm A's mean would be 10.0, the same as arm B's.
- **The S2 class did not separate the arms.** S2 is the class that carries H-L, and all four
  replicates detected all four S2 seeds. That is a ceiling, not a difference. §3.8 says how
  they were found.

## 3. Outcomes in 042's dimensions (PLAN-001 §9)

The numbers are from `trial/findings/replicates.tsv`, `sessions.tsv`, `routes.tsv` and
`defects.tsv`. `trial/scripts/w5_tables.py` computes them from `adjudication/table.tsv`,
CALLS.md's groups, the transcripts and `collect/memwatch.log`.

### 3.1 Useful findings

| Replicate | D(S1) of 3 | D(S2) of 4 | D(S3) of 3 | D(S4) of 2 | U | U, the defects | U reachable |
|---|---|---|---|---|---|---|---|
| A1 | 3 | 4 | 3 | 2 | 9 | D2 D3 D4 D5 D6 D7 D8 D10 D12 | 1 (D10) |
| A2 | 3 | 4 | 2 | 2 | 8 | D2 D3 D4 D5 D7 D8 D11 D12 | 0 |
| B1 | 3 | 4 | 3 | 2 | 9 | D2 D3 D4 D5 D6 D8 D9 D10 D12 | 1 (D10) |
| B2 | 3 | 4 | 3 | 2 | 7 | D2 D3 D4 D5 D8 D10 D12 | 1 (D10) |
| **A mean** | 3.0 | 4.0 | 2.5 | 2.0 | 8.5 | | 0.5 |
| **B mean** | 3.0 | 4.0 | 3.0 | 2.0 | 8.0 | | 1.0 |

- **Reports that name a primary property only.** A2 found D7 and D8 through A2-T3-5 (X-2), and
  B2 found D8 through B2-T3-6 (X-1). Counting only reports that name a primary property gives
  A2 6 and B2 6.
- **Each arm, over both replicates.**
  - Arm A found ten: D2-D8 and D10-D12.
  - Arm B found nine: D2-D6, D8-D10 and D12.
  - `U_B\A = {D9}` and `U_A\B = {D7, D11}`. None of the three is shown reachable.
- **Known defects re-found (sanity checks, §4).** These count as nothing.
  - K7 (D1): all four replicates.
  - K6 (CALLS.md's S1 and S2): A1, B1 and B2.
  - K2 (S7): A1, B1 and B2. A2's K2 report, A2-T6-2, is unclassified, for the same driver
    reason as A2-T6-1.
- **Unknown defects on secondary properties** (counted nowhere).
  - S4: A1, B1 and B2.
  - S5: A1, B1 and B2.
  - S6: B2.

### 3.2 Incorrect conclusions

`F` = 0 in every replicate, and so 0 at an E seed's location too. No report detects s10 or s12.
Every one of the 139 reports exits 1 on T.

### 3.3 Misses

| Replicate | Seeds missed (of 12 S1-S4) |
|---|---|
| A1 | none |
| A2 | s14 (S3, T6). The report that claims it, A2-T6-1, errors on B0 and T−s14, so §8 does not count it. See §2.5 |
| B1 | none |
| B2 | none |

Neither arm detected an E seed, as it should not.

### 3.4 Investigation cost

**Tokens.** Each assistant message is counted once, by its message id. No id carries two
different usages. The measure is `input_tokens + cache_creation_input_tokens +
cache_read_input_tokens + output_tokens`: every token the model read or wrote (decision,
19:26:28Z).

Claude Code's usage splits the input three ways: uncached, written to cache, and read from
cache. Which field a token lands in depends on cache timing, not on the method. `input_tokens`
alone is 110 to 322 per arm session, which counts only the cache misses.

| Replicate | Tokens (the measure) | Output only | Claude Code's `cost-state`, Opus tokens | `cost-state` USD |
|---|---|---|---|---|
| A1 | 90.1 M | 609 k | 96.8 M | 44.49 |
| A2 | 93.9 M | 622 k | 103.0 M | 46.16 |
| B1 | 68.0 M | 682 k | 71.4 M | 41.86 |
| B2 | 98.6 M | 773 k | 104.0 M | 51.03 |
| **A mean** | 92.0 M | 615 k | 99.9 M | 45.33 |
| **B mean** | 83.3 M | 727 k | 87.7 M | 46.45 |
| **B / A** | **0.91** | 1.18 | 0.88 | 1.03 |

`cost-state` is Claude Code's own running total (what `/cost` shows). It also counts requests
that are not written as messages: idle compactions, away summaries and Haiku title calls. On
every reading in the table, arm B's cost is between 0.88 and 1.18 times arm A's.

By target, B/A on the measure:

| Target | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|---|
| B / A | 1.03 | 1.79 | 0.80 | 0.76 | 0.68 | 0.67 |

T2's ratio is mostly one session. t2-b2 used 30.9 M tokens and 69.7 minutes, and its Lean runs
drew 17 of memwatch's 25 kills.

**Wall-clock.** Each session's slot was 2 hours by design (A1 item 6). No session used its
slot.

- **Working time** is the time from the brief to the session's own last end of turn before the
  ten-minute line. It includes time spent waiting on the session's own background jobs.
  - Arm A: mean 39.8 minutes per session, range 25.6-58.6.
  - Arm B: mean 36.2 minutes, range 21.7-69.7.
- **Per replicate**, summed over its six sessions:
  - working time: A1 236 min, A2 242, B1 183, B2 252;
  - active turn time (`turn_duration` records): A1 197, A2 202, B1 181, B2 223.

After its work each session sat idle until the ten-minute line. There it took one turn of under
20 seconds and ended. All 11 compactions, 80.3 to 106.8 minutes in, were Claude Code's idle
compaction ("Compacted while idle, before the prompt cache expired"), not work.

**Targets unfinished at the cap.** 0 in every replicate (§2.2).

**memwatch's kills** (`collect/memwatch.log`; a process over 6 GiB is a cap kill, the largest
process while the machine was below 3 GiB is a floor kill):

| Arm | Cap kills | Floor kills | Where |
|---|---|---|---|
| A | 3 | 5 | t1-a2: 3 cap, `ailang` on its exhaustive gate run. t2-a1: 4 floor. t2-a2: 1 floor |
| B | 15 | 2 | all in t2-b2: `lean` on its model and its mutant files |

Every killed session still concluded on its properties.

### 3.5 Human involvement

The operator's time on the §8 calls, from the adjudicator transcript's timestamps:
- **Round 1:** four questions, open from 18:26:26Z to 18:58:27Z, 32.0 minutes.
- **Round 2:** three questions, open from 18:59:41Z to 18:59:50Z, 9 seconds.

The record holds how long each question was open, not how long the operator spent on it, so the
operator's time on the calls is at most 32.2 minutes.

### 3.6 Transfer

Not measured. The trial used one codebase and planted seeds (§9, §13).

### 3.7 Development cost

| Role | Tokens (the measure) | Output | Time | `cost-state` USD |
|---|---|---|---|---|
| Planter (W1) | 63.3 M | 350 k | 73.2 min, from the brief at 22:19:38Z to its last message at 23:32:47Z on 2026-11-03 | 23.88 |
| Adjudicator (W4) | 47.0 M | 185 k | 95.1 min, from the brief at 17:25:20Z to "W4 DONE" at 19:00:27Z. This includes the 32 minutes the operator's questions were open | none recorded; the session was still running |

The adjudicator's transcript, up to its last record when W5 copied it (19:16:44Z), holds 59.2 M
tokens. That includes publishing W4's bulk data and launching W5. For comparison, the 24 arm
sessions used 350.6 M tokens in all.

### 3.8 Secondary measures

**The route of each detection.** Each report records how its defect was first seen, and the
session reports this itself. The table counts each replicate's seed detections once, and lists
every route among the reports behind each one.

| Replicate | Reading only | Execution only | Reading and execution | Proof and reading |
|---|---|---|---|---|
| A1 | 11 | 0 | 1 (s06) | 0 |
| A2 | 7 | 3 (s08, s09, s13) | 1 (s06) | 0 |
| B1 | 12 | 0 | 0 | 0 |
| B2 | 11 | 0 | 0 | 1 (s09: B2-T3-4 by proof, B2-T3-3 by reading) |

Real-defect reports:
- Arm A: 18 by reading and 16 by execution.
- Arm B: 20 by reading, 13 by execution and 1 by proof (B2-T3-5, D10).

Arm B's "execution" is step (2)'s differential test, the only execution its brief allows
besides step (4).

§11 predicted that arm A would catch the deep S2 seeds "with random inputs well past the bound".
Arm A did catch all four S2 seeds in both replicates, but not mainly that way:
- A1 saw all four first by reading. For s06, a second report saw it by execution.
- A2 saw s08 and s09 by execution (t3-a2's generator), s06 both ways, and s05 by reading.

Both arms mostly found a seed by reading the code, and then used their method to show it.

**Model changes forced by arm B's differential test,** as each `SUMMARY.md` counts them:

| Session | Count | What changed |
|---|---|---|
| t2-b1 | 2 | How AILANG's `std/json` decode behaves: it reads the first value and ignores the rest, and it refuses a number beyond float64 |
| t2-b2 | 3 | The same decoder behaviours, plus a lone surrogate escape. The third came from 15 hand probes, not a differential run. "The transcriptions of the four functions themselves needed no fix" |
| t4-b1 | 2, net 0 | `strLength` was changed, then reverted. The mismatch came from AILANG normalising string literals in the harness |
| the other nine | 0 | |

That is B1 4, B2 3, and 7 in all (5 net).

None of the seven changed the transcription of a target function. Five changed how the model
treats library behaviour the sessions could not read (AILANG's `std/json` is outside the
snapshot), and the other two cancel each other.
Changes that were not forced by a mismatch are counted apart by the sessions themselves. For
example, t3-b2's `diff/MODEL_FIXES.md` lists 1 generator revision, 1 spec revision and 1
extension that matched first time, and t3-b1 has an extension for B1-T3-9.

**Axiom reports.** All twelve arm B sessions record `#print axioms` for every theorem, 401 in
all:

| Session | t1-b1 | t1-b2 | t2-b1 | t2-b2 | t3-b1 | t3-b2 | t4-b1 | t4-b2 | t5-b1 | t5-b2 | t6-b1 | t6-b2 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Theorems | 23 | 17 | 28 | 61 | 38 | 27 | 34 | 35 | 33 | 35 | 33 | 37 |

- **Forbidden names.** No dependency line in any axiom file names `sorryAx`,
  `Lean.ofReduceBool` or `Lean.trustCompiler` (checked with grep on every axiom file in every
  arm B output directory).
- **Axioms used.** Nothing beyond `propext`, `Quot.sound` and `Classical.choice`.
  - t3-b1 and t3-b2 use no `Classical.choice`.
  - t5-b1 uses `propext` and `Quot.sound` only.
- **Two caveats.**
  - t6-b1's `SUMMARY.md` (lines 132-133) says every `bug_` theorem depends on no axioms, but
    its `axioms.txt` shows `bug_P6_1_family` on all three.
  - t2-b2's report is an edited summary of Lean's output, with its linter warnings left out.
- **What the proofs say.** Every proof is about the model. The differential test is evidence
  for the transcription, not proof of it.

**Exploratory findings.**

| Arm | X-n reports | They detect a seed | They are real defects |
|---|---|---|---|
| A | 23 | 11 | 12 |
| B | 15 | 10 | 5 |

- **S4.** Every S4 detection came from an exploratory property: the herdr gate at its call site,
  or end to end. That covers all four replicates and both seeds. No registered property reaches
  the wiring, and every T1 session stated one of its own that did.
- **Exploratory real defects** (CALLS.md X1-X10):
  - Arm A found eight: X1, X2, X3, X4, X6, X8, X9 and X10.
  - Arm B found five: X1, X2, X5, X6 and X7.
  - X2 is D7 and D8 again.
  - None counts towards anything.

**Agreement between replicates.**

| | Arm A | Arm B |
|---|---|---|
| Seeds, both replicates | 11 of 12. s14 is A1's only | 12 of 12 |
| Unknown primary defects, both replicates | 7: D2-D5, D7, D8, D12 | 7: D2-D5, D8, D10, D12 |
| One replicate only | A1: D6, D10. A2: D11 | B1: D6, D9 |

- **Across arms.** Six defects were found by both replicates of both arms: D2, D3, D4, D5, D8
  and D12.
- **Verdicts.** On every target, all four sessions reach the same verdict on every primary
  property (§2.2).

## 4. Results against the predictions

`trial/predictions.tsv`, hashed at W0, against the counts above.

**How a row is judged** (decision, 19:35:48Z, made after the counts were known):
- A count prediction is compared with the mean of the two replicates, as the file's header
  allows ("per replicate, or the mean of the two").
- It is a hit when the mean is within 0.5 of the prediction.
- An "at most" or "at least" row is a hit when the mean meets it.
- **Scaling.** The S2 rows were written for n2 = 5 and are scaled by 4/5, as the header says.
  The S3 rows were written "of 4", and the planter made 3 S3 seeds. They are judged both
  unscaled and scaled by 3/4, and the verdict is the same either way.
- **Other rules.** The observed values are given, so another rule can be applied. A miss is
  recorded as a miss.

| Id | Quantity | Predicted | Scaled | Observed: replicates, mean | Result |
|---|---|---|---|---|---|
| p01 | D_A(S1) of 3 | 3 | | 3, 3; 3.0 | **hit** |
| p02 | D_B(S1) of 3 | 3 | | 3, 3; 3.0 | **hit** |
| p03 | D_A(S2) of 5 | 3 | 2.4 of 4 | 4, 4; 4.0 | miss |
| p04 | D_B(S2) of 5 | 4 | 3.2 of 4 | 4, 4; 4.0 | miss. The basis, "one is lost to T3 running out of time", did not happen |
| p05 | D_A(S3) of 4 | 3 | 2.25 of 3 | 3, 2; 2.5 | **hit**, either way |
| p06 | D_B(S3) of 4 | 2 | 1.5 of 3 | 3, 3; 3.0 | miss, either way |
| p07 | D_A(S4) of 2 | 0 | | 2, 2; 2.0 | miss |
| p08 | D_B(S4) of 2 | 0 | | 2, 2; 2.0 | miss |
| p09 | F_A | at most 1 | | 0, 0; 0 | **hit** |
| p10 | F_B | at most 1 | | 0, 0; 0 | **hit** |
| p11 | U_A | 1 | | 9, 8; 8.5. The arm found 10 | miss |
| p12 | U_B | 0 | | 9, 7; 8.0. The arm found 9 | miss |
| p13 | E seeds reported as defects | 0 for each arm | | 0, 0 | **hit** |
| p14 | tokens, B over A | at least 2 | | 0.91 (output only 1.18; `cost-state` 0.88; USD 1.03) | miss, on every reading |
| p15 | targets unfinished at the cap, per replicate | A 0; B 1 (T3) | | A 0, 0; B 0, 0 | miss. Arm A's half holds |
| p16 | arm B model changes forced by its differential test | at least 3 over all sessions | | 7 as counted, 5 net | **hit**. None was in a target function's transcription (§3.8) |
| p17 | S2 separation (§10 a) | not met | 0.8 | 0.0, not met | **hit** |
| p18 | the §10 outcome | D (0.60); L (0.25); X (0.15) | | D | **hit**: the most probable outcome |

**9 hits and 9 misses.**

§11's summary, line by line:
- "both arms catch the S1 seeds": right.
- "arm A catches most S2 seeds with random inputs well past the bound": it caught all of them,
  but mostly by reading.
- "arm B leads S2 by about one": wrong. The arms tie.
- "arm A leads S3": wrong. Arm B leads by half a seed, through A2's driver.
- "neither catches S4": wrong. Both catch both, in every replicate.
- "arm B costs at least twice the tokens": wrong. It cost 0.91 times.
- "and leaves T3 unfinished": wrong.
- "the predicted outcome is D": right.

## 5. The unknown real defects on `origin/main`

PLAN-001 §8 asks for unknown real defects to be re-run on `origin/main` at W5.

**The tree.** `origin/main` was `09c4f48e8047ad94952dc925422384b019a6913d`, 30 commits after
`43530c0a`. Tree M is built from it by `w5_build_tree_at.sh`, which is `build_tree.sh` with the
base as an argument and no seeds. M's `hash_dir` is `f1575862…`.

M differs from B0 in these files:
- `SYSTEM.md`;
- `.motoko/model-catalog.json`;
- `scripts/verify_native_path_guard.ail`;
- `src/core/tool_catalog.ail` and `src/core/tool_runtime.ail`;
- `src/tui/src/ui.ts`, and a new `ui.think-tags.test.ts`;
- docs under `.agent/projects/`.

No target file changed.

**How the reproductions ran.** Every reproduction in CALLS.md's groups D2-D12 was run, 32
distinct reports with the exploratory A2-T3-5 and B2-T3-6 included. They ran under
`adjudicate.sh`'s conventions, copied into `w5_rerun.py`:
- the path rewrite and a clean environment;
- 120 seconds per run, a 6 GiB cap and a 3 GiB floor;
- every run made twice.

As a control on the runner, each was also run on a B0 rebuilt by the unchanged `build_tree.sh`.
It hashes to W0's `d2370205…`.

| Defect | Reports | On M (two runs each) | On B0 (control) |
|---|---|---|---|
| D2 | A1-T2-5 A2-T2-4 B1-T2-6 B2-T2-6 | 1, 1 for all | 1, 1 |
| D3 | A1-T2-7 A2-T2-6 B1-T2-5 B2-T2-7 | 1, 1 for all | 1, 1 |
| D4 | A1-T2-8 A2-T2-7 B1-T2-7 B2-T2-5 | 1, 1 for all | 1, 1 |
| D5 | A1-T2-10 A2-T2-8 B1-T2-8 B2-T2-14 | 1, 1 for all | 1, 1 |
| D6 | A1-T3-3 B1-T3-6 | 1, 1 for all | 1, 1 |
| D7 | A1-T3-4 A2-T3-5 | 1, 1 for all | 1, 1 |
| D8 | A1-T3-5 B1-T3-5 A2-T3-5 B2-T3-6 | 1, 1 for all | 1, 1 |
| D9 | B1-T3-9 | 1, 1 | 1, 1 |
| D10 | A1-T3-6 B1-T3-7 B2-T3-5 | 1, 1 for all | 1, 1 |
| D11 | A2-T3-4 | 1, 1 | 1, 1 |
| D12 | A1-T5-2 A2-T5-3 B1-T5-3 B2-T5-2 | 1, 1 for all | 1, 1 |

**All eleven unknown real defects still reproduce on `origin/main`.** No reproduction errored,
timed out or hit a memory limit. No run took longer than 10.1 s or used more than 296 MiB. None errored because
code moved, because no target file has moved. The B0 control gives W4's result for all 32.

Records: `trial/findings/rerun-main.runs.tsv` and `rerun-main.RESULTS.sha256`.

## 6. The consequence §10 attaches to D, applied

PLAN-001 §10: "**D.** The RESEARCH note gets a dated marker: the verdict becomes 'adopt
cross-language differential and property checks as standing tests; use Lean only where a person
names a property that must hold for every length'. §10 item 7 is dropped."

This repository revisits a research note with a dated sibling note and a short marker at the
top of the original, and never edits the original below the marker. This note is the sibling.
The marker added to the top of `RESEARCH-lean-harness-properties.md` reads:

> **Revisited, 2026-11-05: PLAN-001's trial gave outcome D.** The results are in
> `FINDINGS-001-trial-lean-against-differential-checks.md`. As PLAN-001 §10 committed before
> the trial, the verdict in §2 becomes: **adopt cross-language differential and property checks
> as standing tests; use Lean only where a person names a property that must hold for every
> length.** §10 item 7 (`make verify_lean`) is dropped. Nothing below this marker is edited:
> the update of 2026-11-03 and the text after it are as they were.

What does not change:
- RESEARCH §10's other items. §10 drops item 7 only.
- NOTE-001's "keep Lean", which answers which prover to use where Lean is used, not whether to
  use one.

## 7. In every outcome: arm A's harnesses on B0, and the standing tests proposed

§10: "arm A harnesses that detected something are re-run on `B0`, and those that pass there are
proposed as standing tests in a follow-up."

**What was run** (decision, 19:31:30Z). The unit is the harness as each report invokes it, which is
the report's reproduction. That is the command §8 defines a detection by. It is also the only
command every report gives with an exit contract and a 120-second bound. All 69 arm A reports
were run twice on the rebuilt B0, under the same runner:

| W4 class | Reports | On B0 |
|---|---|---|
| detects a seed | 33 | **0 on both runs: they pass** |
| real defect | 34 | 1 on both runs for 33. A2-T4-3 gave 1, then 0 (below) |
| unclassified | 2 | exit 2 on both runs, as at W4 |

**A2-T4-3 is load-dependent.** It is a timing check: "`chain_digests_over` is more than 2x
`chain_digest_over`" at n = 40,000. The two runs measured 3.05× and then 1.78×; W4's B0 run
measured 2.50×. It is exploratory (X3) and counts nowhere. W4's classification stands. The lesson
for the follow-up is that a timing threshold is not a standing test.

**Proposed for a follow-up: the 33 that pass on B0, grouped by harness.** Nothing here is added
to the repository.

| Session | Harness, as the reproductions call it | Reports (seed) |
|---|---|---|
| t1-a1 | `gate_diff.ts --case` (P1.1) | A1-T1-1 (s02), A1-T1-2 (s01) |
| t1-a1 | `register_diff.ts --mode x1, x2` (the gate at its call site, and end to end) | A1-T1-3 (s04), A1-T1-4 (s03) |
| t1-a2 | `p11/run_p11.sh --class` (P1.1, the whole generated sweep, about 10 s) | A2-T1-1 (s02), A2-T1-2 (s01) |
| t1-a2 | `callsite/run_callsite.ts --prop X-1, X-2 --grid small` | A2-T1-3 (s04), A2-T1-4 (s03) |
| t2-a1 | `repro/twin_pair.ts P2.1 <witness>` | A1-T2-1 (s06), A1-T2-3 (s05), A1-T2-6 (s07) |
| t2-a1 | `repro/x2_waiter_outcome.ts`, `repro/x1_signal_exit.ts` | A1-T2-2 (s06), A1-T2-4 (s05) |
| t2-a2 | `harness/repro.sh P2.1, P2.2 <witness>` | A2-T2-1 (s06), A2-T2-2 (s05), A2-T2-3 (s07), A2-T2-10 (s07) |
| t2-a2 | `harness/waiter_outcome.ts`, `harness/runner_signal.ts x1` | A2-T2-9 (s06), A2-T2-11 (s05) |
| t3-a1 | `harness/repro.sh <witness>` | A1-T3-1 (s08), A1-T3-2 (s09), A1-T3-7 (s11) |
| t3-a2 | `harness/run_p31.sh '<sequence>'` | A2-T3-1 (s08), A2-T3-2 (s09), A2-T3-3 (s09) |
| t4-a1 | `repro/A1-T4-1.sh`, `repro/A1-T4-2.sh` | A1-T4-1 (s11), A1-T4-2 (s11) |
| t4-a2 | `repro.sh repro_p41, repro_p42` | A2-T4-1 (s11), A2-T4-2 (s11) |
| t5-a1 | `repro/run.sh repro/cycle.ail` | A1-T5-1 (s13) |
| t5-a2 | `repro/r1_cycle_empty_path.sh`, `repro/r2_fold_header_refusal.sh` | A2-T5-1 (s13), A2-T5-2 (s13) |
| t6-a1 | `repro/repro.sh A1-T6-1` | A1-T6-1 (s14) |

What a follow-up should know before wiring any of them in:

- **What each one guards against.** Each is a regression test for one planted slip, with the
  seed's witness. It guards against that slip coming back, not against defects in general.
- **The strongest candidates.** t1-a2's two harnesses run a generated sweep, not one witness.
  They are the only ones that already do.
- **Whole-generator runs can be expected to fail on B0.** These were not run here.
  - t2-a1's and t2-a2's `run_diff.sh` run P2.1's whole generator and exit 1 on any
    disagreement. t3-a1's `run_t3.sh` exits 1 on any violation.
  - The same sessions' real-defect reproductions exit 1 on B0: D1-D5 for both T2 sessions, and
    D6, D7, D8 and D10 for t3-a1. So their generators can be expected to fail there too.
  - Such a harness can stand only after those defects are fixed, or with the known classes
    excluded.
  - The SUMMARYs give whole-harness commands for some sessions only, and several give no exit
    contract (t1-a1's `run_all.sh`, t3-a2's `run_p31.sh` sweeps, t4-a1's `t4_enum.ail`,
    t4-a2's `enumerate_chain.ail`, t5-a2's `run_all.sh`, t6-a1's `run_survey.sh`). They were
    not run.
- **The real-defect reproductions** (D2-D12, §5) are the tests a fix for each defect should
  turn from 1 to 0.
- **Paths.** Every command refers to the session's own output directory. A standing test needs
  its harness moved into the repository and its paths made relative.

Records: `trial/findings/rerun-b0-armA.runs.tsv` and `rerun-b0-armA.RESULTS.sha256`.

## 8. Errors found in W4's record

W4's files are unchanged (W4 stands). Both errors are in `adjudicate.sh`'s table stage
(sha256 `5b2eaad9…`). Both were logged at 19:35:48Z.

1. **`table.tsv`'s `target` column reads `Tt` on all 139 rows.** Line 374 takes `"T" + s[5]`,
   which is the `t` of `t043-tN-…`; `s[6]` was meant. The session column, and so each row's
   target, is right, and nothing reads the target column.
2. **`summary.tsv`'s `interaction` column also counts unclassified reports** (line 392).
   - It shows 2 for A2 and t043-t6-a2, and 1.0 for "A mean".
   - README.md and the 18:25:39Z line say 0 seed interactions and 2 unclassified, and those
     are right.

No classification, seed count or §10 input changes.

## 9. Limits

- **Reading did most of the detecting, in both arms.** The trial compares two methods as one
  agent carried them out, and that agent read the code before using either method. A planted
  slip of at most three lines may be easier to see by reading than a defect from history would
  be (§13). This is the largest reason not to generalise from D. On these targets, arm B found one
  primary defect that arm A missed, D9, and D9 is not shown reachable. That does not show Lean
  would never find more.
- **The budget did not bind.** Every session stopped by itself after 22-70 minutes. "Equal
  budgets" was in practice equal caps. What either arm would do with its unused time is not
  measured, and neither is what it would do on a target large enough to need it.
- **S2 hit a ceiling.** Every replicate detected every S2 seed, so the class that carries H-L
  could not separate the arms. §13 notes the planter knew the bound and the property list.
- **D9's reachability decides between D and L.** It rests on one route followed in code and one
  probe (§2.5).
- **Same model, two replicates, planted seeds, a given property list** (§13).
- **The blinding audit's limits** (AUDIT.md, "What FINDINGS should carry as limits"):
  - Three sessions saw, in a `ps` listing, the name of a file of the other arm's session on the
    same target.
  - Four `find /` walks passed through `/workspaces`, which the deny rules cannot see. They
    printed only paths of AILANG's standard library.
  - Transcripts repeat `tool_use` blocks, so call counts must be taken by id.
- **The token measure is a choice.** It is the same for every session, and the ratio's reading
  does not change under the alternatives shown (§3.4). Tokens include the ten-minute turn.
  Requests that Claude Code does not write as messages appear only in `cost-state`.
- **Batch 1's lost first attempt** (eight sessions, ended by a container restart before any
  deliverable) is not counted in any cost. Its transcripts were not read.
- **"Unfinished"** was judged from the sessions' own summaries and confirmed from their
  transcripts. A session that called a property finished when it was not would pass this rule.
  §8's re-runs check only the violations.
- **The prediction rule** was fixed after the counts were known (§4).

## 10. What this note changed, and what it did not do

**Changed:**
- this file;
- the marker at the top of `RESEARCH-lean-harness-properties.md`;
- `trial/findings/` (new);
- `trial/scripts/w5_tokens.py`, `w5_build_tree_at.sh`, `w5_rerun.py` and `w5_tables.py`, all new;
  no existing script was changed;
- lines appended to `trial/sequence.log`.

Nothing under `s/*/out`, `collect/`, `unsealed/`, `sealed/` or `adjudication/` was changed.

**Not done:**
- whole-harness runs on B0 (§7);
- any reachability work;
- any re-scoring of W4.

**The bulk stays on disk** under `/home/motoko/trial-043/findings/`: trees M and B0, the work
directories, and 266 run logs whose hashes are in `trial/findings/*.RESULTS.sha256`. Publishing
it is the operator's decision.
