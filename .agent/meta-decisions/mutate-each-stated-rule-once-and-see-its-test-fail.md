# Meta-decision: a test covers a rule only when breaking that rule makes the test fail

*Mutate each stated rule once, name the test that should notice, and count only that test failing.*

Date: 2026-10-04
Status: Standing discipline. The operator said on 2026-10-04 that mutation testing should be the
rule; the extent and the wording below were proposed in the same exchange and accepted for writing
up. It has not yet been applied to a part.
Scope: any session that implements a part whose acceptance says tests cover stated rules, and any
session that writes the plan or the brief for one.

## The principle

A test that has never failed has not been shown to detect anything. **For each rule a decision
document states and a test claims to cover, change the source so that it breaks that rule and
nothing else, and see the test that is about that rule fail.** The unit is the rule, not the line
of code. This is not mutation coverage of a file: it is one deliberate break per thing the ADR
says must hold.

"Mutation" already has a meaning in this repository. The DST acceptance suites mutate an *input*:
one valid artifact, one field changed per row, and the validator must reject the row for its own
rule (`Makefile`, the suite described from line 1601). That tests the validator. This discipline
mutates the *source* and tests the tests. Both use the word, and both have the same sharp edge:
a row counts only when it fails for its own reason.

## The instance that motivates it

Project 037, the skills extension, 2026-10-04. Two delegates ran mutation checks that nobody had
asked for.

| | P3, the package's pure core | P4, registration and the handler |
|---|---|---|
| Mutants | 55 | 45 (31 against the tests, 14 against a discovery probe) |
| Killed | 55 | 45 |
| Time | not recorded | 21 minutes, one at a time, on a loaded machine |
| Asked for by | nothing | nothing |

The ADR, the plan, the orchestrator's handoff, the two briefs and the two task prompts do not
contain the word. The delegates wrote the mutants themselves, each with its own Python script, and
committed the table as evidence. That is good work, and it leaves three things open that a rule
has to close.

1. **The author chose the mutants after writing the tests.** A perfect score on a list the test
   author picked is the expected result whether or not the tests are good. Most of the mutants do
   name a rule in their description (`m01 V7 limit is >= instead of >`), but nothing says that
   every rule has one.
2. **A kill was not always a test noticing.** One of P3's 55, `m06`, was counted as killed because
   the mutant divided by zero and the test run aborted with a panic and no summary. The script
   also counts a mutant that does not compile as killed. Neither shows that a test covers the
   rule.
3. **It was optional.** The next part may not do it, and nobody would know it had been skipped.

## The rule

1. **One mutant per stated rule.** The list is derived from the decision document's rules and
   acceptance clauses, not from the tests. Each rule a test claims to cover gets at least one
   source change that breaks that rule and nothing else. A rule with several cases gets one per
   case.
2. **Name the test before the run.** The table has a row per mutant: the rule, the change, and
   the test expected to fail. The mutant is killed when that test fails.
3. **Only that counts.** A different test failing, a compile error, a panic or a timeout is
   recorded as what it is, and is not a kill. The DST suites learned the same thing about input
   mutation: a row asserting "some finding" was green on the wrong evidence (`Makefile:1602`).
4. **A survivor is a finding.** It gets a new test, or one sentence saying why no input can tell
   the two versions apart.
5. **Pair it with survival.** Mutation tests rejection, so it cannot see that something valid is
   also rejected. Anything that rejects needs a valid case that must pass. This is rule 5 of
   [the detector discipline](measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md),
   restated here because a green mutant table makes it easy to forget.
6. **Run it once, at the commit handed in.** The tests are green on the unmutated source first.
   The source is restored after every mutant, and the tree is clean when the run ends. The script,
   the table and the commit it ran at go into the part's evidence. One mutant at a time.

## Where it applies

| Applies | Does not apply |
|---|---|
| Validators, policies, parsers and decoders | Documents and evidence |
| Handlers and their error paths | A throwaway prototype |
| Registration and wiring, where a stated rule says what must be registered or refused | Measurements that are reported and not gated |
| A probe or a gate used as a detector: it must be shown to change on a broken source | Generated files |

A part with no stated rule covered by a test has nothing to mutate, and says so in one line.

## What it costs, and what it does not claim

- **Time.** A mutant here is a recompile and a test run. P4 measured 45 in 21 minutes on a loaded
  machine. That is why the unit is the rule, why the run happens once per part, and why this is
  not a CI gate.
- **It is not coverage.** A rule nobody wrote down gets no mutant. The table says the stated
  rules are tested, and nothing about the code between them.
- **The author still writes the list.** Deriving it from the rules narrows the bias and does not
  remove it. At an operator gate a reviewer can add a handful of mutants of its own without
  seeing the author's list. If those survive, the list was shaped by the tests. That is an
  option for a gate, not part of the rule.
- **There is no shared runner.** P3 and P4 each wrote their own script, and the two decide a kill
  differently from this rule. Until one runner exists, each part's script has to implement rules 2
  and 3 itself. The runner is named here and not built.

## How it is carried

- **In the plan.** A plan's standing rules name this discipline beside the others, and each
  part whose acceptance rests on tests lists the rules it will mutate.
- **In the brief.** The brief for such a part says that the mutant table is part of what ends it.
- **In the evidence.** `mutants.tsv` with the columns of rule 2 and the outcome, the script, and
  the commit.

It applies to parts briefed after it is adopted. Parts already under way finish as they were
briefed.

## Relationship to the sibling disciplines

- [Measure movement, not comfort](measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md)
  says a detector must be built and placed with the author, and that an assertion tests one
  direction. This is the author-side check that a built detector detects, with that document's
  warning about direction carried in rule 5.
- [Re-ground inherited anchors](re-ground-inherited-anchors-before-building.md) is why the list
  comes from the decision document as it stands at the part's own HEAD, and not from an earlier
  part's table.

## Evidence

On branch `feat/skills-extension` (draft PR #213), not on `main` when this was written:

- P3: `.agent/projects/037_skills_system/evidence/p3/mutants.tsv`, `mutate.py` and `README.md`,
  committed at `bbad5b59`, run at `928009c4`.
- P4: `.agent/projects/037_skills_system/evidence/p4/mutants.tsv` and `mutate_p4.py`, in the
  worktree and not yet committed; the run started at 18:31 UTC and ended at 18:52.
