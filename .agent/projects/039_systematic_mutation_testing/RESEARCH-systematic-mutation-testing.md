# RESEARCH: Systematic mutation testing — what property-based mutation testing adds, and what a shared practice needs

Date: 2026-10-06. Updated 2026-10-07 with §4.6, the mutator for AILANG.
Status: Research. Proposes a pilot, a retrospective check and a possible steady state, and names what a project would own. No decision; nothing built or run.
Grounded at: Motoko `origin/main` `93fb002e`.
External sources, none compared with its published version:
- Bartocci, Mariani, Nickovic and Yadav, *Property-Based Mutation Testing*, ICST 2023, [arXiv:2301.13615][paper]. "The paper" below. Read from the arXiv TeX source, sections 2 to 7.
- Petrović, Ivanković, Fraser and Just, *Does mutation testing improve testing practices?*, ICSE 2021, [arXiv:2103.07189][google]. "The Google study". Read from the TeX source: introduction, system description, fault coupling, redundancy.
- Foster, Gulati, Harman, Harper, Mao, Ritchey, Robert and Sengupta, *Mutation-Guided LLM-based Test Generation at Meta*, FSE Companion 2025, [arXiv:2501.12862][meta]. "The Meta paper". Only the abstract, the totals of its mutant table and the passages quoted below were read, from the TeX source.
- Bo Henderson, *Mutation testing for the agentic era*, Trail of Bits, 2026-04-01, [post][tob]. Read through a fetch tool asked for verbatim passages; the quotes are as it returned them.
- The last three were found through a vendor guide, [*Mutation testing for AI-generated code*][guide] (Augment Code). Nothing below rests on the guide's own summaries.

Evidence level: source review of these and of this repository's documents and scripts. **No mutant was run for this note.** Every measured figure about Motoko is quoted from the [011 spike findings][spike] or the [ADR-003 plan][plan] and carries their caveats.

Relates to:
- [011 research note, §3.3][r011]: the kill matrix of fault classes against invariant families. This note takes that section over.
- [011 spike findings][spike]: the only measurements of source mutants against the driver.
- [011 ADR-003][adr003] and [its plan][plan]: the gate `corpus_judge` and WI-4's acceptance by named mutants.
- [035 research note][r035], §4.3, §5 and §6.5: evidence fields per property, mutation verdicts, the generator comparison.
- [The mutation discipline][rule]: one mutant per stated rule, and the kill rule.
- `papers/motoko-dst-report/DRAFT-3.md`, §7.5 and §9.2: the report's statement that a systematic study is separate work.
- [`NOTE-dst-and-mutation-testing-as-one-method.md`](NOTE-dst-and-mutation-testing-as-one-method.md): what is left of the thesis that simulation and mutation complete each other, after the literature review, and what publishing it would need. Kept apart from this survey.
- [`RESEARCH-prior-art-dst-and-mutation-testing.md`](RESEARCH-prior-art-dst-and-mutation-testing.md): the literature review of 2026-10-06, written after this note. It finds the classification in §4.2 in hardware verification since 2007, and the pairing with simulation published by Antithesis in September 2026.

## 1. Question and short answer

**Question.** Does the paper add anything to how Motoko mutates its own source, and what would it take to make that practice systematic?

**Short answer.**

- Motoko already uses the paper's kill criterion. It arrived at it independently, in the mutation discipline and in ADR-003 D6.
- It lacks four things the paper has: mutants nobody chose, a verdict per mutant and per property that includes "this property cannot see it", a score, and one runner.
- The paper's tooling does not transfer. Its definitions and its experiment design do.
- The recommended first step is a pilot: about 30 operator-generated mutants in the driver's recovery code, run on `corpus_judge` once that gate exists, with a stop rule (§8.1). That is about an hour of machine time. The larger cost is triage.
- One trap: the paper's score, taken literally, would hide the spike's main finding (§5.1).
- Industrial practice points away from a score and a periodic study, and towards a few mutants on the code a change touches, shown at review (§2.6, §8.2). The same source gives the best outside evidence that killing mutants prevents real bugs, and a way to measure that on Motoko's own history (§7, §8.3).
- Mutants written blind by an agent from a rule's prose are a third source beside hand-written and operator-generated ones. The ADR-003 plan already uses them, and there is an industrial precedent with measured yields (§2.7, §4.1).

## 2. What the sources say

§2.1 to §2.5 are the paper. §2.6 to §2.9 are the three sources found later and the guide that led to them.

### 2.1 Setting and definitions

The subjects are Simulink models of two control systems. A property φ is a temporal-logic formula over the model's signals, and a test is an input signal. Ordinary mutation testing counts a mutant as killed when a test observes any difference in the outputs. The paper's claim is that this is the wrong question when the software is validated against a stated property.

Its definitions, in its notation (`P` the program, `p` a mutant, `O(t, P)` the output of test `t` on `P`):

- **φ-killed.** A test suite kills `p` when it holds some `t` with `O(t, P) ⊨ φ` and `O(t, p) ⊭ φ`. The test passes on the original and violates the property on the mutant.
- **φ-trivially different.** `p` is φ-trivially different when no possible test has that pair of outcomes. The set includes equivalent mutants. The paper states that identifying it is undecidable.
- **Score.** `MS_φ = |φ-killed| / |not φ-trivially different|`.

The paper places this in the reach, infect, propagate, reveal model: a test must reach the mutated site, change the program state, carry the change to an output, and the oracle must check the part of the output that changed. Its kill condition requires all four, with the property as the oracle.

### 2.2 Results

From the paper's table "Results of Mutation Testing". ART is a test generator that spreads inputs evenly and ignores the property. FT searches for an input that makes the mutant violate the property.

| | ATCS (ART / FT) | AECS (ART / FT) |
|---|---|---|
| mutants | 60 | 100 |
| killable, and φ-killable | 47 | 83 |
| killed, ordinary | 47 / 46 | 74 / 70 |
| φ-killed | 25 / 27 | 39 / 35 |
| ordinary score | 100% / 97.87% | 89.15% / 84.33% |
| property-based score | 53.19% / 57.44% | 46.98% / 42.16% |

Four findings carry over:

1. **The same mutants give two very different scores.** 84 to 100 percent against 42 to 57 percent. The paper's reading: it is easy to reach a fault and hard to propagate it far enough to violate the property.
2. **The property-aware generator did not win.** FT "does not kill more mutants" than ART.
3. **Kills are redundant across tests.** Every mutant ART killed could be killed by a single test. Four searched tests cover all 47 φ-killable mutants of one model and twelve cover all 83 of the other.
4. **Operators are not equally useful.** One operator (`Absolute`) produced 30 mutants and all 30 were equivalent. Another (`ROR`) produced 10, and neither suite φ-killed any of them, though the search showed all ten were φ-killable.

### 2.3 How the denominator was obtained

- Equivalent mutants were found by inspecting the unkilled mutants by hand. The paper says the size of the experiment made that affordable.
- φ-killable mutants were found by a search per mutant: thirty runs, at most 1,000 iterations each.
- **Every φ-trivially different mutant turned out to be an equivalent one** (13 and 17, all `Absolute`). The category the paper introduces, a mutant that changes behaviour in a way the property cannot see, is empty in its own data.
- The paper says of this procedure that "nothing could be said about the mutants not killed" by it.

### 2.4 The search

For each mutant the search looks for a test where the property's robustness is positive on the original and negative on the mutant, and maximises the distance between the original and the mutated internal signal at the fault site. It uses the fault's location, so the paper says it "cannot be used to generate tests in a real situation". It is an instrument for the denominator, not a test generator.

### 2.5 Limits the authors state

Data-flow Simulink models only, and first-order mutants only.

### 2.6 Google: mutants as review findings on changed code

The Google study describes the company's mutation system and analyses six years of its use, almost 15 million mutants.

- **No score.** "The mutation score itself is difficult to act on by developers." The system does "not compute the mutation score but rather report mutants as test goals".
- **Changed code only, at review.** Live mutants in the lines a change touches are shown to the author and the reviewers, beside the other review findings. There is no project-wide run.
- **Four cost cuts.** Mutants only in lines a test covers, because missing coverage is reported separately. One mutant per line. Suppression rules for code that cannot yield a useful mutant, with logging statements as the example. No more than seven mutants reported per file.
- **Five operators**: arithmetic, logical and relational operator replacement, unary operator insertion, and statement block removal. The operator for a line is picked from the history of which mutants survived and which developers found useful.
- **One mutant per line is enough for that purpose.** Where every mutant was generated, "in more than 90% of cases, either all mutants in a line are killed, or none are."
- **Mutants track real bugs.** For 1,043 of 1,502 high-priority bugs (70 percent), the change that introduced the bug would have shown a live mutant that a test in the fix kills. Each of those changes was already covered by tests.

Its limits for this note: ordinary kills by unit tests, in one company's code. The bug study kept to fixes from the last six months so that the code could still be built.

### 2.7 Meta: mutants written by a language model for a stated concern

- **The mutant generator is a prompt.** The model rewrites a class so that each method "contains a typical bug that introduces a privacy violation" like a given example. The mutants are "relatively few, highly specific", aimed at one concern and not produced by rule. Tests are then generated to kill them.
- **Yield.** 31,677 candidate mutants from 10,795 classes. 9,095 (29 percent) built and passed the existing tests. 4,660 of those were judged non-equivalent. 571 tests resulted. Engineers accepted 73 percent of the tests shown to them and judged 36 percent relevant to the concern.
- **Model-written mutants are more often equivalent.** 25 percent of those that built and passed were syntactically equivalent to the original, against the 10 to 15 percent the paper cites as typical for rule-based operators.
- **A model judging equivalence** had precision 0.79 and recall 0.47. Stripping the comments the generator had added raised these to 0.95 and 0.96.
- **Coverage did not predict the kills.** Of the tests that killed a mutant nothing else killed, 49 percent added no line coverage.
- **The oracle is the current code.** The approach "cannot detect existing faults residing in the code base".

### 2.8 Trail of Bits: mutation campaigns run with agents

The post is about the firm's mutation tools for smart-contract languages.

- **Mutants in tiers.** Its earlier tool ranks them: "high-severity mutants replace statements with reverts (exposing unexecuted code paths), medium-severity mutants comment out lines (revealing unverified side effects), and low-severity mutants make subtle changes, such as swapping operators." It "skips lower-severity mutants when higher-severity ones already indicate missing coverage on the same line".
- **Two phases.** Campaigns "run fast targeted tests first and then retest uncaught mutants with the full suite".
- **A store.** Mutants and results are kept in a database, so "campaigns can be paused and resumed without losing progress".
- **The warning.** When an agent writes a test from a surviving mutant, "an uncritical agent doesn't know whether it's encoding correct behavior or propagating bugs into your test suite". The post's remedy is agents that "demand external validation before crystallizing behavior into tests".

### 2.9 The guide itself

The guide surveys mainstream tools. One of their conventions matters here: StrykerJS counts a timed-out mutant as detected, by [its own definitions][stryker]. The guide's other sources, on feeding survivors back into test generation and on the quality of model-written tests, were not read.

## 3. What Motoko already does

### 3.1 The kill criterion

| Paper | Motoko | Where |
|---|---|---|
| A kill counts only when the property is violated | "A different test failing, a compile error, a panic or a timeout is recorded as what it is, and is not a kill" | [Mutation discipline][rule], rule 3; ADR-003 D6 |
| The test passes on the original | "Pair it with survival": the unmutated corpus and a comment-only edit must stay green | Rule 5; D6's controls |
| An irrelevant mutant is set aside with a reason | A survivor gets a new test "or one sentence saying why no input can tell the two versions apart" | Rule 4 |

Motoko is stricter in two respects. The rule and the check expected to fail are written down before the run. And the property is the rule as the decision document states it, which matters in §5.1.

### 3.2 The spike reproduced the paper's main result without setting out to

The [spike][spike] ran eleven single-edit mutants of the driver's recovery branches.

- Nine of the eleven turned `make dst` red. That is the ordinary criterion: something noticed.
- The invariant set, run on all sixteen corpus members at the driver's own bounds, flagged none of the eleven. That is the property-based criterion for the families.
- `M2` is the paper's "killed but not φ-killed" case: the sweep went red on a record-count pin kept for a recursion-depth measurement.

The spike also measured the paper's four stages, without using its words:

| Stage | The spike's measure | Example |
|---|---|---|
| Reach | The corpus wire's record of each recovery branch; probes that panic when a handoff carries a request | `T2` was reached by none of the gates probed |
| Infect and propagate | Lines of the corpus wire that differ from the comment-only control's | `M3` changes 14 lines. `M4` changes none: the difference is only in the returned trace |
| Reveal | Which check went red, and whether it is about the broken rule | `M3`: none. `M2`: an unrelated pin. `M6`: `[discovery-under-recorded]` |

### 3.3 Mutation tooling at `93fb002e`

| Where | What it mutates | How a kill is decided |
|---|---|---|
| `scripts/verify_contract_mutations.sh` (`make verify_mutations`) | Guard predicates under Z3 contracts; one disjunct deleted | The solver returns a violation with the expected counterexample |
| `tools/test_coverage/mutants.py` | The coverage deriver, one guard per row | The self-test goes red naming the fixture that guard owns |
| `tools/explainer/tests/mutate.py` | The explainer tool, one reverted fix per row, in a copy | The self-test goes red |
| 037 evidence, `p3` and `p4` | The skills package's pure core; its registration and handler | Each script's own rule. The discipline records that both differ from it, and that `p3`'s counts a compile failure and a panic as kills |
| 037 evidence, `p5`, `p6` and `r3` | Later parts of the skills project | The table names the rule and the check expected to fail. How each script decides was not read for this note |
| 011 `evidence/mutation-spike/` | The driver's recovery branches and tool handoffs | A prediction before the run and a scorer per part. One scorer treats a timed-out gate as green (the findings note's correction 7) |
| Inline mutant rows; 14 `scripts/dst/*.ail` files mention one (by grep, not read) | Inputs and fixtures, to test validators and checkers | Per the discipline's account of the acceptance suites: the row must be rejected for its own rule |
| [ADR-003 plan][plan], WI-4 | Thirteen named driver mutants | The named rule is printed red. Not yet run |

These do not share a kill rule, a restore step or a table format. The discipline says so itself: "There is no shared runner", and "the runner is named here and not built".

The discipline's status line still reads "It has not yet been applied to a part". The `p5`, `p6` and `r3` tables in 037 name a rule and an expected check per mutant, so that line is out of date.

### 3.4 What the other sources describe that is already here

| Their practice | Motoko | Where |
|---|---|---|
| No score; each live mutant is a finding (Google) | Counts only, and "a survivor is a finding" | Discipline, rule 4; the spike's "No rate" |
| Mutants on the code a change touches (Google) | The mutant run happens once, at the commit a part hands in | Discipline, rule 6 |
| A statement replaced by an abort, to expose unexecuted paths (Trail of Bits) | Probes that panic when a handoff carries a request | Spike, part 3, `P1` to `P3` |
| Fast checks first, the full suite only for survivors (Trail of Bits) | The targeted set, then a sweep for its survivors | Spike, tiers T and S |
| Mutants written from a description of the concern, without sight of the tests (Meta) | A fresh agent given the rules as prose and told not to open the mutant table | ADR-003 plan, WI-4. The ADR reviewers' `R1` to `R6` were the same idea, not blind |

## 4. What is missing

### 4.1 Mutants nobody chose

Every source mutant in the repository was written by hand, by someone who had read the tests or the gates. The discipline names the consequence: "A perfect score on a list the test author picked is the expected result whether or not the tests are good." It also says a rule nobody wrote down gets no mutant.

The paper's mutants come from a tool that applies fixed operators at every applicable site. Motoko has no such tool. What exists towards one:

- The spike's thirteen rows were each one replacement of text that occurs once. All thirteen type-checked and ran.
- 011 §3.3 lists operators that need no framework: literal swaps, comparison and boolean flips, match-arm swaps, off-by-one on a bound.
- The spike suggests one operator of Motoko's own: keep the predecessor world at a handoff. It is the defect class behind `K1`, `M2`, `M6`, `M12`, `T1` to `T3` and `R4`.
- Statement removal belongs on the list. The Google study and the Trail of Bits post both keep it in a small operator set (§2.6, §2.8). Keep-the-predecessor is one case of it, and so are the spike's dropped records, `M4` and `M5`.

**A third source sits between the two:** mutants written by an agent from a rule's prose, without sight of the tests or the author's list. The Meta paper is the industrial precedent (§2.7), and the ADR-003 plan's WI-4 already asks for a round of them. They cost little here, because agents do the work, and they are aimed at a property by construction. They do not replace operators. An agent's mutants cluster where the prose points, and the Meta paper measured more equivalent mutants from a model than rule-based operators give.

### 4.2 A verdict per mutant and per family

The discipline fills one cell per mutant: the rule it was written to break. The kill matrix of 011 §3.3 needs every cell, and most cells are "this family cannot see this mutant". A relabelled fault message (`M7`) says nothing about `BoundedProgress`.

A cell needs three states and, when a mutant is not killed, the stage it stopped at:

- **Killed by this family**, on a named member, with the rule printed.
- **Cannot see**, with one sentence saying why no run could make this family's rule false. This is the paper's φ-trivially different, and rule 4's sentence, per family.
- **Not killed**, with the stage: not reached, reached with no difference on any observed channel, or different on an observed channel and not revealed. The last is a weak oracle.

These stages are not ours. Hardware verification calls them non-activated, non-propagated and non-detected, and has sold tools that sort injected faults this way since 2007; see the [literature review](RESEARCH-prior-art-dst-and-mutation-testing.md).

A fourth fact belongs beside the cell and not in it: which other check went red. [035 §6.5][r035] already lists these verdicts in prose.

### 4.3 A score

A score needs §4.1 and §4.2 first. The spike refuses to give one: "Nine of eleven is a count, not a mutation score." ADR-003's acceptance is a checklist in which every named mutant must go red.

### 4.4 One runner

A runner that implements the discipline's rules 2, 3 and 6 once: the expected check named before the run, only that check counting as a kill, the source restored and hash-checked after each mutant, private output paths, one mutant at a time. The spike's own scripts are the nearest thing and were written for a branch that never merges.

It should also keep mutants and results in a store that survives an interrupted run, as the Trail of Bits tool does (§2.8). A warm sweep here is half an hour, and every run in the spike was a long sequence of them.

### 4.5 A search for a killing input

When a mutant reaches its branch and no family kills it, the spike decided between "the corpus never reaches the distinguishing state" and "the rule cannot see it" by reading the rule's code. The paper decides by searching for an input. Motoko's counterpart would be to run more seeds against the mutant in the same process before calling it an oracle gap. Candidates: `R6` (the generator rewind, seen by nothing) and a dropped successor that carries only a file read, which the spike left open.

### 4.6 A mutator for AILANG, shaped like Stryker

Added 2026-10-07. Stryker is a mutation framework for JavaScript. Its outline fits the two gaps of §4.1 and §4.4, and the one feature of it that would matter most here does not transfer.

**What transfers.**

- **Operators applied to the source and filtered by the type checker.** `ailang check` is the filter. The spike's thirteen text-level edits all compiled, so a parser is not needed to start.
- **Per-test coverage**, so that a mutant runs only against the tests that reach it. Here that is per-member reach, the first of §4.2's three measurements.
- **Incremental mode**, reusing results for mutants whose code and tests have not changed. Here that is the run on changed code of §8.2.
- **Mutant states and a report.** Stryker excludes compile and runtime errors from its score, which agrees with the discipline's rule 3. It counts a timeout as detected, which does not (§5.5).
- **Disable annotations** become the recorded "cannot see" sentence per survivor.

**One mutator, three judges.** The same tool would serve the inline `tests [` and `property` blocks, judged by `ailang test`; the contract mutations that `scripts/verify_contract_mutations.sh` runs by hand, judged by `ailang verify` reporting a violation; and the corpus gate, judged by the invariant set with reach and difference per member. That is the shared runner the discipline names and does not build.

**What does not transfer: mutation switching.** StrykerJS compiles every mutant into one build and selects one at run time through a global; this is general knowledge, not read for this note. It would remove the compile per mutant that dominates the gate's cost (§6). Three things stop it here.

- Under AILANG's effect typing a pure function cannot read a mutable global, and threading a selector through the mutated functions is a change to production code.
- Production carries no test-only branches, by house rule. The Antithesis skill made the same choice, with "no runtime gate, no selector environment variable, and no dead mutant code in the baseline image" (quoted in the literature review's evidence).
- A compile-time constant that picks the mutant still changes the module, so the module still recompiles.

So one build per mutant stays unless the compiler helps, with function-level incremental compilation or a schemata mode in which the compiler binds the selector below the language's purity rules. Both are asks for AILANG's maintainers; the repository has a channel for them. Without them the lever is parallel builds, under the 12 GiB memory guard.

**What AILANG v0.47.2 offers today**, checked on 2026-10-07:

- `ailang dev ast-edit replace --file <f> --decl <name> --new <file> --in-place` replaces one top-level declaration by its parsed span and preserves the rest of the file. A clean way to apply a mutant.
- `ailang dev debug ast <file>` prints the Core AST in ANF, without source positions. It cannot locate operator sites; that takes text matching, as the spike did, or the compiler's parser.
- `ailang lsp` exists and was not examined.

**Two asks upstream:** a positioned surface AST as JSON, and either a larger cache blob limit (§6) or function-level incremental compilation.

**Order of work**, by what the pilot needs first: the operator tool over text, with `ailang check` as the filter and `ast-edit replace` to apply; the runner, with the discipline's rules 2, 3 and 6 and a resumable store; the three judges; incremental mode last.

**Naming.** A mutator for AILANG, whose documentation says "source mutants". In the fuzzing and simulation-testing literature "mutation" means mutating inputs.

## 5. Where the sources would mislead if adopted as written

§5.1 to §5.4 are about the paper. §5.5 and §5.6 are about mainstream practice.

### 5.1 The property must be the stated rule, not the checker

The paper holds φ fixed and grades the tests. The spike found the opposite fault: the corpus reached the branch, and the rule was too weak.

`M3` makes a provider failure finalize with the success reason. The outcome-agreement rule as shipped never reads the finish reason. If φ is that rule, no input can make it fire on `M3`, so `M3` is φ-trivially different and leaves the denominator. The score rises and the spike's main finding disappears.

The protection is already in the house rules: the mutant list is derived from the decision document, and 035 §6.5 has the verdict "observed violation missed by the checker". A matrix must keep both columns: what the stated rule says, and what the checker reports.

### 5.2 The denominator is a recorded judgement

The paper could not compute it either. It used a search and a manual inspection of 30 mutants. Any "cannot see" cell here is one sentence that a reviewer can dispute, not a measurement.

### 5.3 A score over chosen mutants carries no information

With one hand-written mutant per rule and acceptance requiring each to go red, the score is 100 percent by construction.

### 5.4 The search has no ready counterpart

The paper's search needs a number to climb: a distance between signals, and a robustness value whose sign is the verdict. The invariant families return findings over discrete traces. Two quantities already measured here could play those roles: the count of wire lines that differ from the control's, and the margin to a declared bound, such as steps of budget left. Neither has been tried as a search objective. This is an idea, not a result.

### 5.5 Two mainstream conventions are wrong here

- **A timeout is not a kill.** StrykerJS counts a timed-out mutant as detected (§2.9). Rule 3 says the opposite, and this repository has a reason of its own: `corpus_pr` goes red on its wall-clock ceiling, with every content check green, when it shares the machine. A tool's default would import the wrong convention.
- **Records and messages are not noise.** Google suppresses mutants in logging statements as unproductive (§2.6). Here the event ledger and the wire are what the oracle reads. `M5`, `M7` and `M8` each mutate a record or a message, and each was caught by a gate. A suppression list copied from mainstream practice would remove them.

### 5.6 A survivor is not yet a test

The Trail of Bits warning (§2.8) has more force where agents write both the code and the tests. Rule 4 says a survivor gets a new test. For a hand-written mutant that is safe, because the mutant was derived from a rule that a decision document states. An operator-generated mutant has no stated rule behind it. When one survives, the first question is whether the original behaviour is right, and a test written from the code would pin whatever the code does. The Meta paper states the same limit of its own oracle (§2.7).

So a survivor in code that no stated rule covers goes to a ruling first. Either a rule is written and then tested, or the mutant is recorded as outside every rule.

## 6. Cost

All per-mutant figures are from the spike or the plan. The totals for 100 mutants are arithmetic, except the last, which is the spike's own.

| Runner | What it answers | Per mutant | 100 mutants |
|---|---|---|---|
| The invariant set and gate checks on the bank (`corpus_judge`, not yet built) | Does a family or gate rule kill it on a real run? | 40 s for the spike's probe; 51 s for the plan reviewer's sibling script | 67 to 85 minutes |
| The targeted set: type check, `corpus_pr`, `strict_replay`, `discovery`, `stream_parity`, `ledger_parity` | Does one of the main gates kill it? | 3.7 minutes | about 6 hours |
| A full warm `make dst` sweep | Does anything kill it? | 1,770 to 1,875 s | about 51 hours |

- **The property-based verdict needs only the first row.** The full sweep answers the ordinary question, and is needed only for mutants the families miss.
- **Triage is the larger cost.** Each survivor needs one of §4.2's verdicts. In the spike, six survivors took most of the analysis.
- **Baselines are not green.** The plan measured `make dst` at `59d5cbb9`: 52 targets, four red, from one cause that is not mutation's. A gate that is red on the original can kill nothing, by the paper's first condition and by the spike's own reading.

## 7. Expected value

The repository's own results are the only base rate available.

- **The driver's recovery code is where gaps were found.** Of the spike's 20 hand-written mutants (`M1` to `M10`, `M12`, `T1` to `T3`, `R1` to `R6`), four were caught by nothing that was run on them, as the gates stood: `M1`, `M3`, `T2` and `R6`. A fifth, `M2`, was caught only by an unrelated pin. ADR-003's rules are written to catch `M1`, `M3` and `M2`.
- **Package code looks well covered.** 037's `p3` and `p4` killed 100 of 100, under a looser kill rule.
- **Mutants written blind found what the author's list did not.** The reviewers' `R1` and `R2` passed the first version of the ADR's rules, and `R6` is still seen by nothing.

So the likely return is a few new gaps from blind mutants in the driver and close to none elsewhere. No probability is offered; the pilot would measure the yield.

**Outside evidence for the premise.** The Google study found a fault-coupled mutant for 70 percent of 1,502 high-priority bugs, in changes that tests already covered (§2.6). That is the strongest published support for "a test that kills mutants would have caught real bugs". It is about ordinary kills by unit tests in other code, so the number does not transfer. The method does (§8.3).

The score itself would not drive a decision here. Each survivor is the finding, because it leads to a new rule or a new world. The ratio has two uses: it answers the DST report's stated gap, and a fixed mutant set gives 035's generator comparison something to count.

## 8. Proposed work

Proposals for a plan to fix, not a plan.

### 8.1 A pilot

**Precondition.** `corpus_judge` is merged and WI-4's acceptance run is done. Before that, the survivors would mostly be the gaps ADR-003 already names.

**Population.** The recovery branches and world handoffs of the driver: `src/core/session.ail`, `recovery.ail`, `step_machine.ail` and `tool_phase.ail`.

**Operators.** Statement removal, with keep-the-predecessor at a handoff as its main case; comparison and boolean flips; match-arm swaps; off-by-one on a bound. Text-level, one edit each.

**Selection.** Enumerate every site for each operator, then draw about 30 sites with a recorded seed, and one operator per site. Nobody chooses. One mutant per site follows the Google study's redundancy result (§2.6); whether that result holds for property-based verdicts is open (§11). Drawing the operator too means the pilot also says which operators pay, the paper's fourth finding.

**Procedure.**
1. Type-check. A mutant that does not compile is recorded as that.
2. Write the predicted verdict for each drawn mutant before any runs, as the spike did.
3. Run `corpus_judge` on each, one at a time, restoring and hash-checking the source.
4. Record §4.2's verdict per family.
5. For each survivor, run a reach probe at its site: the statement replaced by a panic. The Trail of Bits tool probes first (§2.8). Here the corpus reaches every named recovery branch, so probing only survivors costs fewer runs.
6. Run the targeted set on the survivors that were reached, and a full sweep only on what survives that.

**Controls.** A comment-only edit must stay green. WI-4's thirteen mutants are the known-bad rows.

**Stop rule.** If no drawn mutant exposes a gap that is not already on ADR-003's "known, and not seen" list, stop and record a yield of zero in N. If several do, draw a second batch. The threshold is set in the pilot's plan before the first run.

**Survivors.** Each goes through §5.6 before anyone writes a test for it.

### 8.2 If the pilot pays: mutants on changed code, at review

Google's end state is not a study (§2.6). If the pilot shows that drawn mutants find gaps, the steady state to consider has the same shape, at this repository's scale:

- When a part changes the driver's code under `src/core`, the operator tool mutates the lines the change touches, one mutant per line, up to a cap.
- Each runs on `corpus_judge`, at the gate's cost per run (§6).
- Survivors are shown to the part's reviewer as findings, each with §4.2's verdict.

This complements the discipline and does not replace it. The discipline covers each stated rule with a chosen mutant. This covers the changed code between the rules with drawn ones. Lines the corpus does not reach are left to the reach accounting, as Google leaves uncovered lines to its coverage report.

### 8.3 A retrospective coupling check

The Google study's method measures the premise directly. For a past bug, mutate the lines its fix touched, and ask whether a mutant is live before the fix and killed by the checks the fix added.

- **A candidate pool exists.** A rough grep finds 71 commits on `main` whose message has a line starting with "fix" and that touch `src/core`. 22 of them also touch a test or a DST script. This is a pool to read through, not a list of bugs.
- **Old commits may not build or pass with the current AILANG toolchain.** The Google study kept to six months of history for the same reason.
- **It answers the ordinary question**, whether anything kills the mutant, unless the fix added a family rule.

It could run before `corpus_judge` exists, which the pilot cannot.

## 9. What a project would own

Owns:
- The shared runner of §4.4.
- The operator tool of §4.1 and its site enumeration.
- Together, the mutator of §4.6, with its three judges.
- The verdict vocabulary of §4.2 and the kill matrix that 011 §3.3 proposed.
- The pilot, the coupling check, and the definition of a score if one is ever reported.
- The run on changed code of §8.2, if it is adopted.

Does not own:
- The invariant rules and the gate. Those are 011 ADR-003's.
- The generator policy. That is 035's; this project supplies its fixed mutant set.
- The discipline. The meta-decision stays where it is.
- Each part's own mutant list. Parts keep writing those.

## 10. What this note does not establish

- **No mutant was run.** Every Motoko figure is inherited.
- **No yield.** Twenty hand-written mutants by authors who had read the gates are not a sample.
- **No operator beyond the spike's thirteen text edits is shown to work.** Whether enumeration by text is too noisy, and the AST route is needed, is 011's open question 2 and is still open.
- **The gate's cost is a prototype's.** 40 and 51 seconds are a spike probe and a reviewer's script, not `corpus_judge`.
- **The cost of extra seeds per mutant is not measured at HEAD.**
- **The sources were read as the header says.** The Meta paper only in part, and the Trail of Bits post through a tool that summarises. The guide's other sources were not read.
- **The fix-commit count is a grep.** No commit in it was read.
- **Nothing here shows the Google or Meta results hold for this codebase.** Both are about unit tests on other code, and neither uses a property-based kill.

## 11. Open questions

1. **The unit of a property.** The stated rule, the invariant family, or the rule id the gate prints? Proposed: the rule id, grouped by family, with the stated rule beside it (§5.1).
2. **The test suite the score is relative to.** The sixteen-member bank alone, or the bank and the rotating corpus?
3. **Kill sets per corpus member.** The paper drops a test that adds no kill. The bank has a wall-clock ceiling, so a member that adds no kill is a candidate to drop, and a member that is the only killer of a mutant is one to keep. The spike's `M1` changes one member of sixteen, `seed-19`. Not examined further.
4. **Where the runner lives**, and whether 037's and the spike's scripts move to it.
5. **Whether to keep the paper under `papers/`**, as 023 does for its source paper.
6. **One mutant per site.** The Google result is for ordinary kills. Whether mutants at one site share a fate under property-based verdicts is not known, and the paper's operators differed widely on the same models.
7. **An agent as first judge of "cannot see".** The Meta paper's judge missed half the equivalent mutants unaided. Whether an agent's verdicts here are good enough to cut the triage cost is unmeasured.
8. **A compile per mutant.** Examined on 2026-10-07 (§4.6): no selector that pure code can read exists, and the house rule would forbid one, so a build per mutant stays unless AILANG gains function-level incremental compilation or a schemata mode. Open: whether its maintainers will add either, and whether parallel builds under the 12 GiB memory guard meet the pilot's budget without them.

[paper]: https://arxiv.org/abs/2301.13615
[google]: https://arxiv.org/abs/2103.07189
[meta]: https://arxiv.org/abs/2501.12862
[tob]: https://blog.trailofbits.com/2026/04/01/mutation-testing-for-the-agentic-era
[guide]: https://www.augmentcode.com/guides/mutation-testing-ai-generated-code
[stryker]: https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
[r011]: ../011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md
[spike]: ../011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md
[adr003]: ../011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md
[plan]: ../011_improve_test_axises/PLAN-judge-recoveries-on-real-runs.md
[r035]: ../035_antithesis_testing/RESEARCH-antithesis-inspired-testing.md
[rule]: ../../meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md
