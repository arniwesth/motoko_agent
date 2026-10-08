# Evidence: the literature review of 2026-10-06

The working notes behind [`RESEARCH-prior-art-dst-and-mutation-testing.md`](../../RESEARCH-prior-art-dst-and-mutation-testing.md).

## What is here

`notes/` holds one file per research strand, written by the agent that searched it, and one file
by the coordinating session.

| File | Strand |
|---|---|
| `dst_practice.md` | How DST practitioners check that their simulation tests would notice a defect; LLM-agent testing |
| `distributed_concurrency_testing.md` | How tools that control scheduling are evaluated; mutation of concurrent and distributed code |
| `oracle_strength_by_mutation.md` | Measures of oracle quality; classifying surviving mutants; flakiness |
| `mutants_as_generator_ground_truth.md` | Mutants used to compare generators and property sets: property-based testing, fuzzing |
| `hardware_formal_mutation_coverage.md` | Fault simulation, functional qualification, mutation coverage and vacuity in model checking |
| `simulation_based_testing_mutation.md` | Mutation in simulation-based testing of cyber-physical systems; what followed from *Property-Based Mutation Testing* |
| `coordinator_check_antithesis_skill.md` | A first-hand check of the Antithesis mutation-testing skill, in two passes; the second read all eight markdown files in full |

## How to read them

- **Every source carries a reading-depth tag**: full text, keyword passages, abstract, or machine
  summary only. A claim that rests on a summary is a lead, not a finding.
- **Each file ends with its query log**, including the queries that found nothing.
- **Exa's machine summaries were wrong repeatedly.** The notes say where a summary was checked and
  found wrong.
- **The notes are as the agents wrote them.** They were not edited afterwards, so they may
  disagree with the report where the report corrects them.

## What is not here

- **The raw search responses.** 214 JSON files, about 12 MB, kept under the main checkout's
  git-ignored `tmp/research/exa_raw/` and not committed.
- **A citation-index pass.** All searching went through Exa's semantic search.
