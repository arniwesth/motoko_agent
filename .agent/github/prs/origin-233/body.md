---
repo: arniwesth/motoko_agent
pr: 233
branch: docs/readme-unique-strengths
ticket: null
title: "docs(readme): lead with what is unique to Motoko, move the setup reference to docs/"
---

## Summary

Rewrites the README for harness builders and researchers, in the layout of AILANG's own README.
The old one pitched Motoko as a generic coding agent: six of its seven highlights described any
harness, and self-verification was the last bullet. The new one opens on deterministic simulation
testing, recursive self-improvement and The Phoenix Architecture, then has a quick start, a
feature list, one section each on how DST and mutation testing are used, and the limits. The
setup, usage, configuration and extension reference moves to three files under `docs/`.

## Changes

The branch holds about twenty commits, because three alternative READMEs were written on it and compared
before one was chosen. The alternatives are deleted again. Net of that:

- `README.md` rewritten, 366 lines to 175.
- `docs/running.md`, `docs/configuration.md` and `docs/extensions.md` added.

4 files changed, and this record.

## Governing docs

None under `.agent/projects/`. The choices that shape the rewrite were made by the operator in the
authoring session on 2026-10-07:

| Question | Decision |
|---|---|
| Audience | Harness builders and researchers |
| Lead story | DST |
| Layout | After `github.com/sunholo-data/ailang`: image and title with a tagline, badges, a short definition, a link bar, then sections separated by rules, and a closing line for AI agents |
| Title | "Motoko: Agent Harness with Native Deterministic Simulation Testing" |
| FoundationDB and Antithesis | Named in the opening as what the approach draws on, not as an equal |
| Recursive self-improvement | Stated in the opening as what DST is a bet on, and as the destination |
| The Phoenix Architecture | Its own paragraph in the opening |
| Mutation testing | Its own section, describing the procedure and not past results |
| DST | Its own section above it, in the same form |
| Puppet Master lore | Its own Origin section before Quick Start, in the original README's two sentences |
| "Things are going to break." | Removed: the point of the project is now that it does not break |
| Credits | A Credits section at the end names Pi Coding Agent, pi-tui, Oh-My-Pi and little-coder. The context-mode credit is removed |
| Timing | Independent of the release in `033_release/ADR-001-release-scope.md` |

Not ruled on: the table of contents. It is not in this version. The operator had asked for it back
in an earlier draft on this branch.

## What moved and what is new

| Content | Before | After |
|---|---|---|
| Opening, Quick Start for the tests, the planted-mutant demo, Key Features, the DST and mutation sections, Limits | not present | `README.md`, new text |
| Running Motoko (sandbox, dev container, native install), Usage, "How it works" | `README.md` | `docs/running.md` |
| Configuration and model identifiers | `README.md` | `docs/configuration.md` |
| Extensions table, adding a new extension | `README.md` | `docs/extensions.md` |
| Development, Project structure | `README.md` | `README.md`, shortened |
| Contributing | `README.md`, a section | `README.md`, a link in the guide list |
| Reference | `README.md` | `README.md`, as Credits, without context-mode and with FoundationDB, Antithesis and The Phoenix Architecture moved to the opening |
| Highlights, table of contents | `README.md` | removed |

The text moved to `docs/` is unchanged apart from heading levels and relative links. It was not
re-checked for currency. The extensions table gains `skills`, which is registered in `ailang.toml`
and was missing.

## Where the new claims come from

| Claim in the README | Source |
|---|---|
| Ports, `WorldState`, the seeded generator, faults, recording, replay | `papers/motoko-dst-report/DRAFT-current.md` §2 and §3, `src/core/ports.ail` |
| 13 invariant families, each reporting whether it ran and on how much input | `InvariantFamily` in `src/core/dst_invariants.ail`; the report, §7.3 |
| Exact-program promotion of a nightly failure is policy and not built | `scripts/dst/corpus_pr_dst.ail` regenerates its one promoted member from a seed; `scripts/dst/corpus_rotating_dst.ail` keeps no program |
| Which runs get replay and the invariant set | `evaluate` is called from `scripts/dst/corpus_judge_dst.ail` only, among the corpus scripts |
| The two paths that bypass the ports | `capture_failing_payload` and `run_dp7_verifier` in `src/core/session.ail` |
| File reads are not logged; replay compares a projection | `src/core/test/stub_step.ail`, the recording adapter set and the provider identity |
| The fixed corpus on every pull request, a rotating corpus nightly, no API key | `.github/workflows/dst-corpora.yml`, which uses no secret |
| Execution profiles | the report, §7.1 |
| 53 sweep targets | `make dst_target_list` |
| The planted mutant, and what each check reports | `docs/motoko-dst-demo-run-2026-10-04.md` |
| Why `strict_replay` catches it | the run note, and the `discovery-env-read-under-recorded` message in `src/core/dst_discovery.ail` |
| The five mutation steps, and that it is not a CI gate | `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md` |
| `make verify_mutations` runs in CI | `.github/workflows/verify-extensions.yml` |
| Input mutation in the DST suites | the same meta-decision, "The principle" |
| Contract classes | `tools/verify_classify/classify.py`, `make verify_core` |
| The limits | the report, §8 |

Draft PR #227 was read for the mutation section. Nothing from project 039 is claimed or linked: it
is proposed work, and its files are not on `main`.

## Review

Reviewed on 2026-10-07 at `9c6f17c4` by Codex on GPT-6.1-Sol (high reasoning), in a detached
worktree, read-only, briefed to treat this description as a claim and check the repository. It
reported five verified errors and four opinions. The authoring session checked the five against
the source and fixed them in the commit after `9c6f17c4`:

| Finding | Fix |
|---|---|
| "Each run's trace is checked against 13 invariant families": only `corpus_judge` calls the evaluator, and nightly runs are not replayed | The DST section says which runs get which steps |
| Nightly failures "promoted as exact programs": the one promoted member is regenerated from a seed, and nothing retains a nightly program | Stated as policy that is not built; the step is removed |
| The core reaches the outside "only through ports": the failed-payload capture and the finalization verifier do not | "only" removed, and both paths are listed under Limits |
| Recording captures "every interaction" and replay checks "the same requests": file reads are not logged, and requests are compared by a projection | Both steps reworded, and a Limits line added |
| The install commands leave `ailang` and `bun` off `PATH` in the calling shell | A sentence in the README and in `docs/running.md`. The original README had the same gap |

Open, for the operator: say that a hook's signature *declares* its effects, since the ABI records
that a declared row does not bound effects through function-valued record fields; present the
mutation procedure as the prescribed discipline and add its control and baseline rule; flag on the
demo command that it calls a live model, edits `session.ail` and must run alone; and put the
simulation quick start before the agent quick start.

The reviewer found the moved text in `docs/` unchanged in meaning, the counts and CI schedule
correct, no broken links, and both badges returning "passing".

## Predicted outcome

- **A reader meets DST first**, then how it is used and how the tests are themselves tested.
- **No build, test or gate result changes.** The diff is four markdown files, and no Makefile
  target, workflow or script reads the root README.
- **Old section anchors are gone from the README**, for example `#agent-sandbox` and
  `#model-identifiers`. No file in the tree links to one. An outside link to one lands at the top
  of the README.
- **The two badges show live status.** A red run on `main` shows red on the README.
- **Some numbers will drift**: 13 invariant families and 53 sweep targets. They are correct at
  `8fa5f92a`.

## Test evidence

Run on 2026-10-07 in the branch's worktree, AILANG v0.47.2.

- [x] **Relative links and anchors.** Every relative link in the four files resolves to a file in
  the tree, and `docs/running.md#agent-sandbox` and `docs/configuration.md#model-identifiers`
  match a heading.
- [x] **`make dst_target_list`** prints 53 targets.
- [x] **Nothing reads the root README.** A search of the `Makefile`, `.github/workflows`, `scripts`
  and `tools` finds no reference to it, and no file links to a README section anchor.
- [x] **AILANG's README was read from GitHub** at its default branch `dev` on 2026-10-07.
- [ ] **The page has not been seen rendered on GitHub**: the two badges, and the image at 640 px.
- [ ] **The author of The Phoenix Architecture, Chad Fowler, is from a machine summary of the
  linked page**, and "the rigor sits in the evaluations" is read off its essay titles. The essays
  were not read.
- [ ] **`make dst` and `make demo_dst` were not run.** The demo's description is from the Makefile
  and the run note of 2026-10-04.
- [ ] **CI was not awaited.** The change is documents only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
