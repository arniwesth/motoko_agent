# SYNTHESIS — a fresh look at recursive self-improvement in Motoko

Date: 2026-11-20. Repository HEAD: `2eae0666`. AILANG v0.60.4.
Moderator: Claude Opus 5.5. It wrote the prompts and this synthesis and took no position.
Participants: `fable` (Claude Code, Fable 5.2), `astra` (Codex, GPT-6.2-Astra), `neon`
(Antigravity, Gemini 4 Neon). Protocol: [BRIEF.md](BRIEF.md). Turns: `discussion/round-{1,2,3}/`.

## 0. Summary

1. **DST is not the centre of RSI as a whole.** All three reached this independently in round
   1, without reading the earlier plans. After reading them in round 2, all three narrowed the
   claim: the direction document never said DST supplies the signal that a change is *better*.
   The one-sentence version in `README.md:14` overstates it (fable R2 §B). All three keep DST as
   the guard against breakage. It cannot grade prompt, tool or competence changes. Their
   positions differ in detail:
   - fable holds that DST is the centre of the verification-level loop, where its first loop
     sits, and a floor only for the execution level (fable R2 §B).
   - astra makes no general cost ranking and notes that checker verdicts can use recorded data
     directly (astra R1 §5, R2 §B).
2. **A shared, zero-model Step 0 comes first.** All three put it first, and their specifications
   overlap closely (§2). Its results are also meant to decide which loop runs first.
3. **Which loop runs first remains open.** The candidates are the **oracle set** (fable), the
   **checker-repair procedure** (astra), and the **whole harness scored on competence** (neon).
   Each participant named the Step 0 observation that would make it switch to another's loop
   (§4), so you can pick the loop from data.
4. **Recursion needs its own test.** All three hold that the incumbent and the promoted method
   must each edit the *same* parent, and that their offspring are judged on fresh families. astra
   proposed this independently in blind round 1 (astra R1 §4); 042 already required it; fable
   and neon adopted it in round 2. A sequence of wins `M_0 → M_3` does not show that improving got
   better; it may only show a better starting point.
5. **History is a thin source of faults.** 25–34 fix commits revert cleanly at HEAD, probably
   about 14 of them behavioural (moderator fact note). Renewable sources are seeded mutants,
   planted defects, and live defects captured before their fix is visible.
6. **Noise discipline is agreed.** Count by root-cause family, not by edit. Use N ≥ 3 runs per
   cell for anything live. Use a byte-identical rerun as the null control; a comment-only prompt
   edit is not null, because the model reads it (astra R2).

## 1. How the discussion ran

| Round | fable | astra | neon | Early stop? |
|---|---|---|---|---|
| R1 blind | 6 min | 9 min (after a restart) | 19 min | — |
| R2 cross-examine | changed position | changed position | changed position | No: all changed, all listed material disagreements |
| R3 final | changed position | position unchanged | changed position | — |

Moderator interventions, all recorded:

- astra was restarted with `-s danger-full-access -a never`, the owner's 2026-08-23 decision for
  unattended Codex (`021/MEASUREMENTS-2026-08-22.md:561`), because the Codex sandbox cannot start
  in this container.
- The R2 timeout was raised from 20 to 30 minutes before R2 was sent.
- After R2 the moderator settled two factual disputes at the code
  ([discussion/round-2/moderator-facts.md](discussion/round-2/moderator-facts.md)):
  - **Fault supply:** 123 fix commits; 34 revert cleanly with paths limited to `src/` and
    `packages/`, 25 as whole patches; 2 of fable's 25 driver fixes revert cleanly.
  - **Compile cache:** the limit is now 64 MiB, and `session.ail` caches (24.8 s cold, 1.7 s
    rerun). fable withdrew its sweep-cost argument in R3.

## 2. Step 0, the shared first step

None of the three runs a model in Step 0. The requirements, with who stated each:

| Requirement | fable | astra | neon |
|---|---|---|---|
| Named gate set at one pinned commit, green on the unfaulted tree and identical on a second run | `check_core`, `corpus_judge`, `ledger_parity`, `corpus_pr`, `journal_resume`; no wall-time verdict | only the promotion checks must qualify, pinned with toolchain and limits; historical cases run on their original parents | `check_core`, `corpus_judge`, `ledger_parity`, `journal_resume`, `verify_core`, plus a native-FS fixture for off-world writes; **omits `corpus_pr`'s wall-clock check** and `declared_vs_performed` |
| Scorer credits only a named check firing; crash and timeout are separate outcomes (the m06 defect) | yes | yes | implied by two-sided qualification |
| Two-sided qualification of every item: the faulty item fails a named check, its fix passes, a clean control passes | 60 seeded sites, the 25–34 clean reverts, astra's checker defects | 4 historical checker defects, 8 planted, 4 clean controls | clean reverts, 60 seeded mutants, 4 clean controls, 5 known-good commits |
| Each item gets a root-cause family, with no human ruling | yes | families are curated, then scored mechanically | yes |
| A demonstrated rejection or null | one planted regression refused; byte-identical rerun changes nothing | a byte-identical candidate is not promoted in the dry run | one unseeded dry run; hashes recorded in `sequence.log` |
| Isolation of the evaluator | an audit of what a proposer session can read | scorer, answer keys, meter and promotion authority outside the worker; history-free snapshot; only a patch and a data witness come back | disposable container, `git diff` extraction, a loopback LLM proxy that meters tokens and USD, and 042's RAM watchdog (6 GiB, 2–3 workers) |
| Measured cost per item | yes | yes | yes |
| Estimate | 3–5 agent-days | within its 3–5 engineer-days | 2–3 engineer-days |

Two differences in the gate set are unresolved. Should `corpus_pr` be in, with its wall-time
verdict removed, or out? Should `verify_core` be in? Everything else is a union the three can
share.

## 3. The three first loops, as stated in round 3

| | fable: oracle-set loop | astra: checker-repair procedure | neon: whole-harness competence |
|---|---|---|---|
| What Motoko edits | One oracle artefact per candidate: a corpus member, fixture or rule, matched to the class of the non-detection | One instruction paragraph of at most 300 words | Config, skills, prompts, tools and guards |
| Items | Up to 10 visible non-detections among 60 seeded driver sites; held-out edits deduplicated against the visible ones and counted by family | 8 dev tasks; 12 sealed fault families (4 historical, 8 planted) plus 4 clean controls | 6 dev families; 18 untouched holdout families (6–8 clean reverts, 6–8 planted, 4 clean controls) |
| Replication | 3 sessions per item; an item counts if 2 of 3 produce an accepted artefact | Incumbent only: 3 runs on each of 8 dev tasks, which must yield a majority repair and a majority miss. Both arms: 3 runs on each of the 16 sealed tasks; a family is won with at least 2 of 3 | k = 3 runs per arm per task (54 per arm), plus a byte-identical `M_0`-vs-`M_0` null |
| Evaluator | The pinned gate set. Deterministic. | An external referee: it reproduces the wrong verdict, checks the correction, and runs hidden checks | An isolated container and proxy, with Step 0's gate set as a safety floor |
| Pass | At least 4 families convert, from at least 2 classes; no kill lost; no red on the unfaulted tree or 5 known-good commits; both nulls convert nothing | At least 5 challenger-only family wins, including 1 historical and 1 planted; 0 incumbent-only wins; 12/12 clean runs untouched; the winner then writes a successor | Null within 1 family; `M_1` beats `M_0` across 14 fault families with a one-sided paired permutation test at p < 0.05; 12/12 clean runs untouched; floor green; USD per task at most 1.25× |
| Recursion test | Its P3, the procedure rung (astra's loop on fable's tasks), which fable places second; whole-harness competence is its third rung | Its P2: authors compared on the same parent | Built in: `M_0` vs `M_1` editing parent `M_1` on 12 fresh families |
| Cost after Step 0 | 2–3 agent-days; at most 30 sessions | at most 122 sessions; caps of 3.05M tokens at 25k per session and 20 h 20 min serial | 2–3 engineer-days; 160–220 sessions; $250–400 |
| Strongest argument against itself | Killing seeded mutants has not been shown to predict catching real defects. The loop never improves the proposer; recursion arrives only with P3. And Motoko's delegates failed 3 of 3 source-writing tasks in September. | A paragraph may hold one good checklist and nothing more. A clean win would then leave the recursive claim unsupported. | It pays for live-model variance and curation up front, edits AILANG, and may spend more to find a limit the narrower loops expose more cheaply. |

All three loops share one thread. Each inherits Step 0's scorer, where a crash is no longer a
kill, keeps the evaluator out of the candidate's reach, and counts by family.

## 4. Open disagreements, and the observation that settles each

| Disagreement | Settling observation | Stated by |
|---|---|---|
| Oracle set or checker procedure first | fable switches to astra first if Step 0 finds **fewer than 6 closable seeded families**, or if Motoko **compiles and passes the gate in fewer than a third** of 3 sessions on each of 3 visible items. astra switches to fable first if, under the incumbent procedure, Motoko's artefacts gain **4 named detections on withheld edits** across 2 classes and unseen causes, with 5 known-good commits green. | fable R3 §4, astra R3 |
| Oracle set or whole harness first | Compare Step 0's count of closable seeded families with the number of qualified, independent task families. fable: if the gate set barely reaches the behavioural reverts, neon's surface is right. neon: if historical plus planted tasks give **fewer than 12 families**, or `M_0` cannot compile `.ail` edits, switch to fable. | fable R3 §4, neon R3 §1, §4 |
| A narrow paragraph or a wide harness, and a 25k or ≥150k token cap | Step 0's dry-run token trace and its breakdown of dev failures. neon: sessions **over 25k tokens**, or **over 50% tool-trap failures**, falsify the prompt-only scope. astra: widen the scope if the pinned tool **repeatedly blocks a known-correct repair**. | neon R3 §4, astra R3 |
| Wait for the parked journal plan (014 re-ranking, ADR-004 P2–P3) | All three say no. fable: if the judge tier refuses a planted regression, that plan is not a prerequisite. astra: bring it forward only if the referee **falsely accepts a known-bad repair** that only journal evidence would reveal. | all, R2–R3 |

The moderator notes that fable's and astra's switching conditions both concern whether Motoko
can write a check artefact, but they measure different things. fable's is narrower: whether
sessions on visible items compile and pass the gate, a claim about covering an obligation, not
about transfer. astra's requires detections on withheld edits. fable's probe of 3 items × 3
sessions spends model tokens, so it runs after Step 0, not inside it; all three keep Step 0
free of model spend.

## 5. Where the earlier plans stand

- **`design_docs/planned/m-motoko-dst-recursive-self-improvement.md`** stands as a framework.
  It separates reproducibility, scoped correctness and improvement, and it requires a repair-only
  "third arm" that none of the round-1 designs had (fable R2 §B; astra R2 §B).
- **014 `NOTE-001` re-ranking.** It defers any automated editor until ADR-004 P2–P3 land. All
  three disagree, and call the disagreement material. Step 0's standalone evaluator is offered
  instead.
- **042.** Its author-versus-author recursion test matches what astra proposed blind in round 1;
  fable and neon adopted it in round 2. astra also adopted its
  pre-registered protocol and diagnosis categories, and neon its operational limits (RAM
  watchdog, 2–3 workers, side-channel audit). fable notes that 042's "why did the tests miss it" investigation is exactly the oracle
  loop's work product.
- **`README.md:14`** presents DST as the evidence that a change is an improvement. fable calls
  this a non-material wording issue.

## 6. Facts established during the discussion

Settled by the moderator at the code:

- Fault supply and the compile cache: see §1 and `discussion/round-2/moderator-facts.md`.

Checked by at least two participants:

- m06 was scored `KILLED` on a crash (`037/evidence/p3/mutants.tsv:6`, `mutate.py:100`).
- `manifest-A.json` is 872 commits stale and its check is `REFUSED`.
- At HEAD the journal evaluator refuses every real entry.
- `scripts/eval/candidate.py` admits only `resource-only` changes, so an oracle or prompt loop
  needs a new admission policy.

Cited by participants but not re-checked by the moderator:

- Motoko's delegates failed 3 of 3 source-writing tasks
  (`021/MEASUREMENTS-2026-09-05-plan001-live-run.md:28-32`).
- The 039 pilot found 16 of 30 seeded mutants with no wire difference, and one off-world write
  (`014/NOTE-001:215-238`).
- A single-trial flip rate of 7 in 26 (`014/NOTE-001:136`).
- The judge tier costs about 46 s per mutant.

## 7. Decisions for you

1. **Build Step 0.** All three agree, there is no model spend, and the estimates are 2–5
   agent-days. Its output also decides the first loop.
2. **Settle the gate set.** Include `corpus_pr` (without its wall-time verdict) or not, and
   `verify_core` or not.
3. **Fix the selection rule before Step 0 runs.** Adopt §4's thresholds as the rule that picks
   the first loop, so the choice is mechanical. Decide whether fable's 3 × 3 probe of whether
   Motoko can write a check runs right after Step 0; it is the only selector that spends model
   tokens.
4. **Token budget per session.** 25k (astra) or ≥150k (neon). Step 0's dry run measures it.
5. **`README.md:14`.** Optionally reword it so that DST guards change rather than proves
   improvement.

## 8. Corrections from the check round

Each participant checked this synthesis for misstatements of its own position
(`discussion/check/`). neon reported none. fable's three corrections and astra's six were applied
as stated:

- fable: the label of its P3; its view that DST is the centre of the verification-level loop; its
  switching condition being narrower than transfer.
- astra: a moderator suggestion that put a model-run probe inside Step 0, which spends no model
  tokens; its gate set and family curation; its replication counts; that it proposed the
  same-parent test independently; its time cap; that it made no cost ranking of DST.

## 9. What this synthesis did not do

It ran no experiment. It did not verify the participants' behavioural and family
classifications, their cost estimates, or the findings cited in §6 as not re-checked. Where the
participants' numbers differ, the table in §3 gives each participant's own.
