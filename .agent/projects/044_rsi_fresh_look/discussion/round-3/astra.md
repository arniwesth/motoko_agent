# astra — round 3

## Step 0

Yes. All three proposals require a zero-model demonstration that someone else can decide whether the candidate succeeded. The common requirement applies to the checks used for promotion. (See `../round-2/fable.md:89–94`, `../round-2/neon.md:27–34`, `../round-2/astra.md:24–30`.)

Pin the snapshots, toolchain, named checks, resource limits and decision rule. Run each reference pair twice. Require the same named wrong verdict on the defective version, the intended verdict on the known fix and green results on valid neighbors. Record crashes, timeouts and unsupported cases separately. A crash once counted as a kill. Keep the scorer, answer keys, meter and promotion authority outside the worker. Give it a history-free snapshot and accept only a permitted patch and a data witness for independent replay. (`../round-2/moderator-facts.md:40–48`)

For my trial, seal four historical checker defects on their original parents, eight planted defects from different families and four clean controls. Keep all twelve causes out of development. An unstable verdict or promotion of a byte-identical candidate in the dry run sends us back to the referee. If too few independent families qualify, stop before spending model tokens. Of 123 historical leads, 34 reverse cleanly with paths restricted, 25 as whole patches and only two of Fable’s 25 driver fixes reverse cleanly. The independent family count is [unverified]. Time the chosen gates during qualification. The artifact limit is now 64 MiB, and `session.ail` checks in 1.7 s warm. Per-mutant cost is still unmeasured. (`../round-2/moderator-facts.md:8–38`, checker leads `4bad256e`, `3fe71b06`, `0cabdf41`, `a8b3ab03`)

## Ranked proposals and first loop

1. **Improve the checker-repair procedure.** Run the incumbent three times on each of eight development tasks. Require both a majority repair and a majority miss. From those histories Motoko writes one replacement paragraph of at most 300 words.
2. **Test whether the winner becomes a better author.** Give incumbent and promoted authors the same starting paragraph, new development failures and budget. Score their offspring on fresh families. This distinguishes inheriting a good instruction from learning to write a better one. (`.agent/projects/042_improving_experimentation/RESEARCH-improving-experimentation.md:168–179`)

Run proposal 1 first. Freeze one challenger. Randomize run order, reset source and hold model, tools and budget fixed. Run each arm three times per sealed task. A repair must correct the reproduced error and pass hidden controls. A family majority requires at least two successes in three runs. Promote on a single blind look with at least five challenger-only wins, including one historical and one planted, zero incumbent-only wins and all twelve challenger control runs leaving valid code untouched. Load the winner to author the next revision. A missed threshold retains the incumbent. With independent, exchangeable family signs, five wins and zero losses has one-sided probability 1/32 under the null. A miss leaves smaller gains unresolved.

## Strongest objection

A fixed instruction to reproduce the wrong verdict and check a valid neighbor might exhaust what a paragraph can teach. Even a clean first win could reward one good checklist. Equal offspring performance on fresh families would leave the recursive claim unsupported.

## Remaining decisions

- **Fable, checks first.** I would switch on one transfer result. Using the incumbent procedure, Motoko’s checks or fixtures gain four named detections on withheld edits spanning two classes and unseen root causes while five known-good commits stay green. (`../round-2/fable.md:121–128`)
- **Neon, harness first.** I would widen the edit scope if the pinned tool repeatedly prevents applying a known-correct development repair within budget. (`../round-2/neon.md:10–13`)
- **014, journal admission first.** I would move it ahead if the isolated referee falsely accepts a known-bad repair because only journal evidence reveals the failure. (`.agent/projects/014_comparative_self_evolution/NOTE-001-re-read-2026-11-02.md:435–445`)

```yaml
participant: astra
round: 3
position_changed: no
top_proposals:
  - id: P1
    title: "A self-written procedure for repairing acceptance checkers"
    one_line: "Promote one paragraph when an independent referee measures a replicated advantage across unseen checker fault families."
  - id: P2
    title: "Compare successor authors on a shared starting paragraph"
    one_line: "Give both authors identical evidence, parent and budget, then compare their offspring on fresh families."
first_experiment:
  what: "After zero-model qualification, collect 24 incumbent development runs, freeze one self-revision, and compare three runs per arm on each of 12 sealed fault families and four clean controls."
  pass_if: "Development has both a majority repair and a majority miss. On one blind look require at least five challenger-only majority wins including a historical and a planted case, no incumbent-only majority wins, and all 12 challenger clean runs untouched. Verify the promoted paragraph is loaded and produces a successor proposal."
  fail_if: "Stop before model spend if qualification fails. Stop before blind scoring if development lacks either outcome. Retain the incumbent on a missed promotion threshold. If the winner cannot produce a successor, report the transfer result and the loop-closure failure separately."
  cost: "Estimate of 3–5 engineer-days and at most 122 live sessions including both writing sessions. At 25,000 cumulative tokens and ten minutes per session, caps are 3.05M tokens and 20 h 20 min serial worker time. Measure referee cost in Step 0."
disagreements:
  - with: fable
    about: "Checks first if the incumbent procedure produces artifacts meeting the held-out detection and clean-commit thresholds across unseen causes."
    material: yes
  - with: neon
    about: "Broaden beyond a paragraph if the tool repeatedly blocks an already-correct repair in development."
    material: yes
  - with: prior-docs
    about: "Bring journal admission forward if missing journal evidence causes a demonstrated false acceptance by the local referee."
    material: yes
would_change_my_mind_if: "The bank cannot qualify, or the promoted author has no offspring advantage on fresh cases when both authors start from the same paragraph."
embargo_notes: ""
```
