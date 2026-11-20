# fable — round 2

Short names: DIRECTION = `design_docs/planned/m-motoko-dst-recursive-self-improvement.md`;
REREAD = `.agent/projects/014_comparative_self_evolution/NOTE-001-re-read-2026-11-02.md`;
042 = `.agent/projects/042_improving_experimentation/`. Commands and their output are under the
prose, above the YAML.

## A. Cross-examination

**astra.** Weakness: at one run per arm per task, the decision rule cannot separate a 300-word
paragraph from live-model variance. If the incumbent solves four tasks that either paragraph
solves 70% of the time, the challenger keeps all four about one time in four, so "no incumbent
success lost" fails by chance and a real, modest effect is missed. This repository's own record is
that a single-trial delta is noise and a cell needs N ≥ 3 (REREAD `:372-378`).
*Take:* the recursion test, in which two authors start from the same paragraph and their
offspring are judged. Only it tests "better at improving", and 042 asks for it
(`RESEARCH-improving-experimentation.md:176-178`).
*Fact check, held:* m06 is `KILLED` on "exit 2: NO SUMMARY (does not compile or run)"
(`.agent/projects/037_skills_system/evidence/p3/mutants.tsv:6`), and the scorer is
`killed = any(rc != 0 …)` (`…/p3/mutate.py:100`).

**neon.** Weakness: the 21 cleanly re-injected fixes it needs do not exist. Of the 123, 34
reverse-apply at HEAD. About 14 of those are
toolchain-migration compile fixes, where the compiler's message is the answer, and about 6 are
register housekeeping. About 14 are behavioural, in about 9 scopes. Hand-porting the other 89
makes the curator the bug's author.
*Take:* the comment-only control that must be rejected.
*Fact checks:* the stale-manifest claim held exactly (872 commits; "20 findings … REFUSED").
"123" is right only with `--oneline`; the command as printed returns 4,163.

## B. The case for DST at the centre

The earlier plans' strongest case has three parts. A selection loop compounds only if each accept
decision is reliable and cheap, and only a deterministic world decides in one run without
sampling error (DIRECTION `:17`); a live-scored loop pays N ≥ 3 per cell for every candidate or
selects on noise (REREAD `:372-378`).
Failures accumulate as "durable experimental material" (DIRECTION `:19`). And the world is a
function of a seed, so evaluation material can be regenerated and widened, which recorded live
runs cannot (`.agent/projects/032_dream_rsi/RESEARCH-dream-rsi-implications.md:72-79`).

It survives better than I allowed. DIRECTION never says DST supplies the improvement signal: it
separates reproducibility, scoped correctness and improvement, gives DST the first two, and
requires an independent objective, withheld fault families and live transfer (`:45-53`, `:78`).
All three round-1 turns rejected the README's one-sentence version (`README.md:14`), not the
plan. What fails is the cost premise, which the project's re-read retracts (REREAD `:384-390`),
and there is still no deterministic task-quality signal (REREAD `:426`). DST is the centre of the
verification-level loop, where my P1 sits, and a floor for the execution level.

What the earlier plans had and I missed:

1. **The pilot** (REREAD `:215-244`, inherited, on a branch). Of 30 seeded mutants, named judge
   rules killed 5, sibling gates 5 more, and 16 showed no wire difference. No completed mutant
   changed the wire unnoticed.
   The gaps are reach and one off-world write, which a new invariant rule does not close: my
   round-1 loop aimed at the smallest class. The judge tier costs about 46 s per mutant, not 3.7
   minutes. The authors mispredicted four of five kills, so a proposal must be run, not reasoned
   about.
2. **The gate is a set of oracles**, to be named before anything is ranked by it
   (REREAD `:228-233`, `:437`).
3. **The third arm**, a repair without the method change (DIRECTION `:76`). None of our designs
   had it.

## C. The moderator's axes

1. **First thing to improve.** The checks, widened from rules to whatever closes a non-detection:
   a corpus member for reach, a fixture for an off-world effect, or a rule, with classification
   first. That work product is 042's "why did the tests miss it" investigation, so astra's
   procedure is the second rung on the same tasks. Whole-harness competence is third: it lacks
   tasks and a noise budget.
2. **Mechanical verdict.** A prerequisite, but only for the tier the loop uses (`corpus_judge`
   and three sibling gates), not for `make dst`. The
   journal evaluator cannot be the gate yet: it refuses HEAD.
3. **Fault supply.** Too small for any round-1 number. Of my 25 driver fixes, 2 reverse-apply.
   Across `src/` and `packages/` there are about 14 behavioural reverts in about 9 families,
   almost none in the driver the simulated world observes. Reverts are a one-shot transfer probe.
   The renewable sources are seeded sites (87 eligible, REREAD `:216`) and live defects captured
   before their fix is visible.
4. **Noise.** Mine: the verdict is deterministic but the proposer is not, and "+2 kills" from
   five sessions cannot tell a method from a lucky session. neon: if runs are independent, 40
   per arm at a solve rate near 0.3 has a standard deviation near 2.9, so identical arms differ
   by more than 2/40 about half the time, and +6/40 is about 1.5 standard deviations. Rule: deterministic verdicts where the object allows;
   elsewhere N ≥ 3 per cell and a null control.

## D. Revised proposals and first experiment

P1 changes: reverts are report-only; artefacts are classified first; the judge tier is the
evaluator; a null control and three sessions per item are added.

**Part A, no model.** At a pinned commit, draw 60 sites by seed and split them by hash. Held out:
different edits in the same branch families, plus whole families as a transfer readout. Run the
oracle set twice on each and classify.

**Part B.** For up to ten visible non-detections, three Motoko sessions each, one artefact per
candidate, under one fixed instruction paragraph.

The split of the 34 by kind is read from commit subjects, not built: `[unverified]`.

```
$ git log --no-merges --grep='^fix' -- src/ packages/ | wc -l            -> 4163
$ git log --no-merges --grep='^fix' --oneline -- src/ packages/ | wc -l  -> 123
$ for c in <those 123>; do git show --format= $c -- src/ packages/ | git apply --check -R -; done
                                                    -> clean=34 conflict=89
$ same check over the 25 driver-file fix commits of round 1, paths src/core
                                                    -> clean=2 conflict=23
$ git rev-list --count 65003110ff5a..HEAD                                -> 872
$ python3 tools/eval_protected/protected.py check --manifest tools/eval_protected/manifest-A.json --tree HEAD
  eval_protected check: 119 spans, 20 findings, 0 pin drift reports -> REFUSED
```

```yaml
participant: fable
round: 2
position_changed: yes
top_proposals:
  - id: P1
    title: "Oracle-set loop on held-out seeded mutants, classification first"
    one_line: "Motoko classifies each visible non-detection (not reached, not propagated, off-world, not detected) and contributes the matching artefact (corpus member, fixture or rule); a pinned evaluator accepts on held-out edits it never saw, with a clean tree, a comment-only control and known-good commits as valid cases."
  - id: P2
    title: "Make the judge tier a usable gate"
    one_line: "Name the oracle set (corpus_judge, ledger_parity, corpus_pr, journal_resume), get it green and identical on rerun at about 46 s per mutant, and point the eval_protected mechanism at the oracle surface; this is P1's Part A and its only prerequisite."
  - id: P3
    title: "Procedure rung on P1's tasks (astra's loop, 042's design)"
    one_line: "Once P1 has accepted artefacts, let Motoko revise the instruction paragraph its sessions ran under and compare improvement campaigns from the incumbent and the promoted paragraph, with a repair-only arm and N >= 3 per cell."
first_experiment:
  what: "Part A: 60 seeded single-site mutants in session, step_machine, recovery and tool_phase at a pinned commit, split by hash into visible and held-out (different edits in the same branch families, plus withheld families as a readout), each run twice against the named oracle set and classified; the cleanly reverting behavioural fixes run once, report only. Part B: up to 10 visible non-detections x 3 Motoko sessions each, one oracle-set artefact per candidate, judged by the pinned evaluator, with a comment-only candidate as the null."
  pass_if: "Part A classifies every mutant with no human ruling and identical results on the rerun, on a green unfaulted tree; the comment-only candidate is rejected; accepted candidates turn at least 4 held-out non-detections, from at least 2 classes or modules, into kills by a named check, with zero reds on the unfaulted tree and on 5 known-good commits; for at least half of the attempted items, 2 of 3 sessions produce an accepted artefact."
  fail_if: "The baseline needs a ruling or differs on rerun; or the comment-only candidate is accepted; or visible non-detections close and held-out ones do not; or an accepted candidate turns a known-good commit red; or fewer than half of the items are reproduced by 2 of 3 sessions."
  cost: "Build 4-6 agent-days (site sampler, split and mount, oracle-only intent on the candidate runner, classifier). Compute: 60 mutants at 46 s to 4 min each is 1-4 h per pass, about ten passes. Model: at most 30 proposer sessions [unverified]."
disagreements:
  - with: neon
    about: "Starting with whole-harness competence on reverted-fix tasks. Only 34 of the 123 fix commits reverse-apply at HEAD and about 14 of those are behavioural, in about 9 families, against 21 needed; and the pass margins sit inside live-run noise at 2 repeats."
    material: yes
  - with: astra
    about: "Starting with the procedure paragraph before there is a task family with a deterministic verdict. I would run it as the second rung on P1's tasks, at N >= 3 per cell, not first on 16 single-run tasks."
    material: yes
  - with: prior-docs
    about: "REREAD's re-ranking defers any automated editor until ADR-004 P2-P3 finish (:445). The oracle loop does not need journal replay; it needs the judge tier and the protected-span mechanism pointed at the oracle, so I would not wait for the parked plan."
    material: yes
  - with: prior-docs
    about: "README.md:14 presents DST as the evidence that a change is an improvement; DIRECTION itself does not. My round-1 objection was to the README sentence."
    material: no
would_change_my_mind_if: "Part A at 60 sites again finds no mutant that changes the wire unnoticed, and Motoko's reach and fixture artefacts do not transfer to held-out edits: then the oracle set is saturated for mechanical faults, and the first loop should be astra's procedure rung on checker defects. Or if someone shows 20 or more behavioural historical faults in independent families that inject cleanly at one commit, which would make neon's holdout buildable."
embargo_notes: "Embargo lifted. Read DIRECTION in full, 042 README and RESEARCH in full, 042 NOTE-001 sections 'What running it taught' and 'Where it falls short', REREAD sections 3.1-3.3, 3.6, 3.9, 4, 5 and 6, and the 032 TL;DR. Did not read 015 or the docs/ retrospectives."
```
