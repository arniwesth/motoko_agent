# REVIEW-001: Claude Fable 5.1 review of Antithesis-inspired testing research

Date: 2026-10-02
Reviewer: Claude Fable 5.1, launched with `--model claude-fable-5-1`; the terminal banner confirmed Fable 5.1.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `research-035-review`, pane `w3:p2`.
Reviewer session: `bfba28f6-61f9-4283-9271-f7c2b9313431`.
Document reviewed: [RESEARCH-antithesis-inspired-testing.md](RESEARCH-antithesis-inspired-testing.md).
Document SHA-256: `5cfce9eb95ddb882f9bf7dfdd1b26c563722d89b61697ed9c9304eee871fca72`.
Status: Assessed and addressed in the 2026-10-03 research revision; see the disposition table below. The reviewer response and reviewed-version hash are preserved.

## Scope

The reviewer was asked to verify factual claims against local source and pinned upstream
files, assess overlap with projects 009/011/013/031/032/034, examine the proposed experiment
and mutation methodology, and check lifecycle scope and the no-Antithesis-software constraint.
The delegated session had read-only tools and was instructed not to edit files, run tests
or mutation scripts, install software, or delegate further.

The response below was captured from the reviewer's completed Herdr terminal output.
Terminal indentation has been removed; its claims and recommendations are retained.
Line references identify the reviewed document version.

## Reviewer response

Verified against the working tree at HEAD 4023bf08 and the four upstream files at the pinned commit (all resolve). Factual claims about the
generator, invariant families, reach states, corpus jobs, mutation script, and lifecycle fixtures are accurate. The "no Antithesis software"
constraint is respected. Findings below are ordered by severity.

1. Confirmed methodological gap: the experiment never bounds its seed space (lines 189-197, 203-207).
Source: src/core/dst_corpus.ail:554 fixes the rotation at a 1024-seed space with a 240-seed window. The FoundationDB cross-check note, section
3.1, says the knob widening must land after the seed-space question because "a combinatorial knob space inside a 1024-seed rotation is a
search that reports movement while covering little." Arm B derives a policy vector from the same seed, so each policy configuration consumes
one seed of a finite space.
Correction: state whether the experiment draws from the corpus space or an independent seed range, how many distinct policy configurations the
window can realize, and cite the ordering constraint from 013 section 3.5.

2. Confirmed overlap: the retry-bound mutation already exists (line 177).
Source: scripts/verify_contract_mutations.sh:102-104 deletes && remaining_step_budget > 1 from should_retry_stream_error and asserts a Z3
VIOLATION. The candidate table presents this as new.
Correction: mark it as covered at the contract level. The incremental claim is execution-level detection by the BoundedProgress family at
src/core/dst_invariants.ail:234. Name that family as the intended detector and the contract check as the control.

3. Confirmed understatement: existing mutation evidence is already assembled (lines 143-145, 261-275).
Source: project 011 research, line 55, inventories inline mutant rows in about 19 DST gates, tools/test_coverage/mutants.py, and a 147-site
literal-mutation loop. Its section 3.3 designs the kill matrix, measures one sweep at 196 seconds, estimates 5.5 hours per 100 mutants, and
requires surviving controls (line 167). Project 009's note d23, section 4, records three production mutants applied and killed.
src/core/dst_generator.ail:689-697 records a real defect caught by mutating the generator.
Correction: cite these and reframe section 6.5 as executing 011's design with the new per-property evidence fields. Adopt the 196-second
figure for budget planning.

4. Question: the scheduled rotating corpus may never have run (line 82, line 195).
Source: .github/workflows/dst-corpora.yml:127-129 says the scheduled job "has never actually run" because the workflow was not on the default
branch. The workflow is now on main, so the comment may be stale, but I cannot see CI history.
Correction: before using scheduled-corpus output as the baseline for "rotation behavior and observed execution costs," confirm at least one
rotation window has completed, or state that the baseline must be produced locally.

5. Optional: policy persistence is for audit, not reproduction (lines 224-228).
Source: src/core/dst_generator.ail:395-405 derives the initial state from generator id, version, and seed. If arm B draws its policy from that
stream, the existing triple already reproduces it. The positional-serialization claim is correct (src/core/dst_persistence.ail:571, decoded
by index at :1180-1208), and chunk_draw_hi at :398-412 is the precedent for appending a field behind a version predicate.
Correction: say reproduction is already covered by generator identity. If settings are persisted for interpretability, follow the
append-at-end precedent. Note that program schema 5 is already claimed by both 031 P2.1 and 034 (034 ADR lines 207-208), which supports the
doc's choice to allocate no version.

6. Minor wording: "011's shrinking work" is a proposal, not an implementation (line 330, line 42).
Source: .agent/projects/011_improve_test_axises/ADR-001-adopt-program-shrinking.md is status Proposed, dated 2026-08-16. No ddmin
implementation exists in src/core or scripts; the only hits are comments.
Correction: write "011's proposed ddmin design, unimplemented" and link the ADR alongside the research note.

Overall assessment. The document is careful about distinguishing checked-in behavior from proposals and historical results. Every generator
claim in section 4.1 matches the source. The thirteen families, five reach states, two replay modes, and lifecycle scenarios are described
correctly. The constraint is respected: the mutation skill depends on snouty and Docker Compose, the feature-workload skill on the Antithesis
SDK, and the document adopts only their procedural structure. The main weaknesses are planning gaps rather than errors. Section 6 needs a
seed-space statement, and sections 4.3 and 6.5 should build on project 011's existing mutation inventory and cost measurements instead of
restating the need to assemble them.

Not verified. Whether the JournalFold family is currently green on real runs. The comment at src/core/dst_invariants.ail:1951-1955 says it is
red by construction until journal-class events are emitted, and session.ail now references them, so the comment may be stale. Whether the
scheduled corpus has run in CI. No tests, sweeps, or mutation scripts were executed.


## Follow-up qualifications from the delegating agent

These qualifications were recorded when the review was captured on 2026-10-02,
before the research document was revised.

- **Historical costs need remeasurement.** Project 011 does record the 196-second sweep
  and approximate 5.5-hour estimate cited in finding 3. Retain those as historical context;
  do not adopt them as the current experiment budget without measuring the chosen revision,
  runner, toolchain, and environment.
- **Count realized policies.** The 1024-seed rotation and 240-seed window cited in finding 1
  are present in `scheduled_rotation()`. Distinct seeds need not produce distinct policy
  configurations. An experiment should report the observed number and distribution of policies
  rather than assume one configuration per seed.
- **Keep the reproduction layers distinct.** Finding 5's suggestion concerns regenerating
  policy choices with the same generator and inputs. It does not replace the existing
  requirement to retain resolved execution programs and their interpretation metadata for
  durable replay across generator changes.
- **Validate the proposed detector.** The retry-bound mutation in finding 2 is present in
  `verify_contract_mutations.sh`. `bounded_progress_findings` checks decision and retry
  budgets plus repeated provider steps, but whether it detects that exact production mutation
  under the chosen runner still needs an execution-level experiment.

The research document's hash was unchanged at review capture on 2026-10-02. It was
subsequently revised on 2026-10-03 as recorded below. No review finding has been treated
as a new passing test result or a confirmed production defect.

## Disposition — 2026-10-03

Relevant local anchors were rechecked at HEAD
`21ba95c9f3d04bdb03846036a34269918922e979`. The research changes are responses to
the review, not a second reviewer verdict or a completed experiment.

| Finding | Assessment | Change in the research document |
| --- | --- | --- |
| 1. Seed space | Accepted. The original prerequisites acknowledged the issue without defining the experiment's sampling domain. One seed per distinct policy is not guaranteed. | Section 6.1 now proposes separate finite tuning/evaluation ranges, four 240-seed windows each, independent of scheduled rotation. It requires a declared policy support and records realized counts and frequencies. The budget still needs measurement and a frozen experiment plan. |
| 2. Existing retry mutation | Accepted as a clarification of prior work. Contract-level coverage does not establish execution-level detection. | Sections 4.3 and 5 name the existing edit and its contract check. `BoundedProgress` is the intended family to investigate; its detection remains unmeasured. Valid in-budget retries remain passing controls. |
| 3. Existing mutation inventory and timing | Accepted in part. The inventory and prior results should be cited. The wording that they had to be assembled understated existing work. The recommendation to adopt the historical 196-second timing as the current budget is not accepted. | Sections 4.3 and 6.5 now build on 011's matrix design, cite 009 D23's three detected production mutants and the generator-mutation example, and explicitly require remeasurement of costs and revalidation of mutation sites. |
| 4. Scheduled CI history | Accepted as an evidence prerequisite, not as a finding that CI has never run. A source comment cannot establish current execution history. | Section 6.1 makes a local measured baseline the default and requires an identified completed run and artifacts before using CI output. Current CI history remains unverified. |
| 5. Policy persistence | Accepted with qualification. Derived settings can be regenerated under the same full inputs and generator implementation; the id/version/seed triple alone does not specify every execution input. | Section 6.3 separates policy audit data, regeneration, and durable replay. It cites the version-aware append/decode precedent and retains the program-bytes requirement. No schema version is allocated or mandatory format extension assumed. |
| 6. Shrinking status | Accepted as a precision improvement. The earlier relationship table already called shrinking a proposal, but “reuse shrinking work” was ambiguous. | Sections 2 and 8 now link 011's proposed ddmin ADR and state that it remains unimplemented in the inspected core/scripts. |

Documentation references and formatting were checked. No tests, seed sweeps,
mutation scripts, or CI-history queries were run for this disposition.
