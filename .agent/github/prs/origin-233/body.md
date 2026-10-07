---
repo: arniwesth/motoko_agent
pr: 233
branch: docs/readme-unique-strengths
ticket: null
title: "docs(readme): lead with what is unique to Motoko, move the setup reference to docs/"
---

## Summary

Rewrites the README for harness builders and researchers. The old one pitched Motoko as a generic
coding agent: six of its seven highlights described any harness, and self-verification was the last
bullet. The new one opens on deterministic simulation testing, has six short sections on what is
different, and states the limits of the testing. The setup, usage and configuration reference moves
to three files under `docs/`.

## Changes

- docs(readme): lead with what is unique to Motoko, move the setup reference to docs/

4 files changed.

## Governing docs

None under `.agent/projects/`. The four choices that shape the rewrite were made by the operator in
the authoring session on 2026-10-07:

| Question | Decision |
|---|---|
| Audience | Harness builders and researchers |
| Lead story | DST, with the agent-built factory second |
| Puppet Master lore | Shrunk to one sentence under the pitch |
| "Things are going to break." | Removed: the point of the project is now that it does not break |
| Table of contents | Kept, rewritten for the new sections |
| Timing | Independent of the release in `033_release/ADR-001-release-scope.md` |

## What moved and what is new

| Content | Before | After |
|---|---|---|
| Pitch, "What makes Motoko different", "Status and limits" | not present | `README.md`, new text |
| Running Motoko (sandbox, dev container, native install), Usage, "How it works" | `README.md` | `docs/running.md` |
| Configuration and model identifiers | `README.md` | `docs/configuration.md` |
| Adding a new extension | `README.md` | `docs/extensions.md` |
| Extensions table, Development, Project structure, Contributing, Reference | `README.md` | `README.md` |
| Table of contents | `README.md` | `README.md`, rewritten for the new sections |
| Highlights list | `README.md` | removed |

The moved text is unchanged apart from heading levels and relative links. It was not re-checked for
currency. The extensions table gains `skills`, which is registered in `ailang.toml` and was missing.
The credits gain FoundationDB and Antithesis.

## Where the new claims come from

| Claim in the README | Source |
|---|---|
| Ports, `WorldState`, recorded programs, replay, the diagram | `papers/motoko-dst-report/DRAFT-current.md` §2 and §3, `src/core/ports.ail` |
| 13 invariant families | `InvariantFamily` in `src/core/dst_invariants.ail` |
| 53 sweep targets | `make dst_target_list` |
| PR corpus on every pull request, rotating corpus nightly | `.github/workflows/dst-corpora.yml` |
| Four profiles, vacuity accounting, withheld capabilities | the report, §7 |
| The demo's mutation and what catches it | the `demo_dst` comment in the `Makefile`, `docs/motoko-dst-demo-run-2026-10-04.md` |
| `corpus_judge` and its six checks | the header of `scripts/dst/corpus_judge_dst.ail` |
| 16 contracts, 14 substantive, 2 tautologies, 49 bare files | `make verify_core`, run for this PR |
| The `Capability` excerpt | `packages/motoko-ext-abi/types.ail` |
| Journal fold and park/wake | the report, §4 and §5 |
| Orchestrator mode and the 395 shell calls | the header of `packages/motoko-ext-herdr/orchestrator.ail` |
| Line and commit counts | `wc -l` over `src/core` and `packages`, `git rev-list --count` at `8fa5f92a` |

## Predicted outcome

- **A reader meets DST first.** The README goes from 366 to 212 lines.
- **No build, test or gate result changes.** The diff is four markdown files, and no Makefile
  target, workflow or script reads the root README.
- **Old section anchors are gone from the README**, for example `#agent-sandbox` and
  `#model-identifiers`. No file in the tree links to one. An outside link to one lands at the top
  of the README.
- **Some numbers will drift**: 53 sweep targets, 16 contracts, the line counts, about 1,800
  commits, 37 projects. They are correct at `8fa5f92a`.

## Test evidence

Run on 2026-10-07 in the branch's worktree, AILANG v0.47.2.

- [x] **Relative links and anchors.** Every relative link in the four files resolves to a file in
  the tree, and the three anchors used (`docs/running.md#agent-sandbox`,
  `docs/configuration.md#model-identifiers`, `README.md#extensions`) match a heading. The 14
  table-of-contents links each match a README heading.
- [x] **`make verify_core`**, on the tree before the documents changed:
  `16 contracts proven, 0 unstated, 1 blocked; 0 files failed, 49 bare` and
  `14 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified`.
- [x] **`make dst_target_list`** prints 53 targets.
- [x] **Nothing reads the root README.** A search of the `Makefile`, `.github/workflows`, `scripts`
  and `tools` finds no reference to it, and no file links to a README section anchor.
- [ ] **The diagram has not been seen rendered on GitHub.**
- [ ] **`make dst` and `make demo_dst` were not run.** "Tens of minutes" for the sweep is from an
  earlier measurement. The demo's description is from the Makefile and the run note of 2026-10-04.
- [ ] **CI was not awaited.** The change is documents only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
