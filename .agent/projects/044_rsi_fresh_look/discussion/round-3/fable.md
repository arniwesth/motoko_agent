# fable — round 3

Correction: I withdraw round 1's compile-cache argument; the module caches today
(`discussion/round-2/moderator-facts.md` §2).

## 1. Step 0

Yes, it is shared. It runs no model and contains exactly:

1. **A named gate set at one pinned commit**: `check_core`, `corpus_judge`, `ledger_parity`,
   `corpus_pr`, `journal_resume`. Green on the unfaulted tree and byte-identical on a second run,
   with no wall-time verdict.
2. **A scorer that credits only a named check firing.** A crash or timeout is its own outcome
   (the m06 defect).
3. **Two-sided qualification of every item any loop will use**: 60 seeded sites, the 25–34
   cleanly reverting fixes, and astra's checker defects. A faulty item fails a named check that
   its reference passes; a clean control passes. Each item gets a class and a root-cause family
   with no human ruling.
4. **A demonstrated rejection**: one planted regression is refused, and a byte-identical rerun
   changes nothing.
5. **The measured cost per item**, and an audit of what a proposer session can read.

Three results would change the plan:

- The gate set is not green and identical: the work is then the gate.
- Fewer than six seeded families are closable non-detections: astra's loop runs first.
- Twelve or more historical faults qualify in independent families: neon's pilot is buildable.

## 2. Final proposals and the first loop

1. **P1, the oracle-set loop.**
2. **P2, Step 0**, without the sweep-cost claim.
3. **P3, the procedure rung**: astra's loop on P1's tasks.

The first loop after Step 0 is P1's Part B. Its verdict is deterministic, so noise sits in the
proposer and in what a conversion means. The criteria follow:

- The unit is the **family**, not the edit. Held-out edits that repeat a visible edit or its line
  are removed before any run.
- A family converts when every held-out non-detected edit in it becomes a kill by a named check.
- An item counts only when 2 of 3 sessions produce an accepted artefact.
- **Pass:** at least 4 families convert, from at least 2 classes; no earlier kill is lost; no red
  on the unfaulted tree or on 5 known-good commits; the byte-identical rerun and a comment-only
  source commit convert nothing.
- **Fail:** any of those is missed, or visible families convert and held-out ones do not.
- Wholly withheld families are a readout only: the claim is obligation coverage, not transfer.

## 3. The strongest argument against P1

It may measure, cleanly, something that does not matter. The pilot found no completed mutant that
changed the wire unnoticed, and most real behavioural fixes look to be in the TUI and extensions,
outside the simulated world `[unverified]`. No one has shown that killing seeded mutants predicts
catching real defects. The loop never makes the proposer better; recursion arrives only with P3.
And it asks Motoko to write AILANG corpus members and rules, the kind of edit its delegates
failed every time in September
(`.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md:28-32`).

## 4. Material disagreements, and what settles each

- **Where the headroom is (neon, astra).** Step 0's two counts: closable seeded families against
  qualified independent task families. The larger pool goes first.
- **Whether the oracle set sees real defects (neon).** Run the behavioural reverts against the
  gate set. If almost none is even reached, neon's surface is the right one.
- **Whether Motoko can write the artefact (all).** Three sessions on each of three visible items.
  If fewer than a third compile and pass the gate, astra's loop goes first.
- **Whether to wait for the parked journal plan (prior-docs).** If Step 0's judge tier refuses
  a planted regression, that plan is not a prerequisite.

```yaml
participant: fable
round: 3
position_changed: yes
top_proposals:
  - id: P1
    title: "Oracle-set loop on held-out seeded mutants, classification first"
    one_line: "Motoko classifies each visible non-detection and contributes the matching artefact (corpus member, fixture or rule); a pinned, deterministic evaluator accepts on held-out edits counted by family, with valid-case controls."
  - id: P2
    title: "Step 0: a mechanical gate and a qualified item pool, no model"
    one_line: "A named gate set that is green and byte-identical on rerun, a scorer that credits only a named check, two-sided qualification of every seeded, historical and checker item, one demonstrated rejection, and measured cost."
  - id: P3
    title: "Procedure rung on P1's tasks (astra's loop)"
    one_line: "Motoko revises the instruction paragraph its sessions ran under; the incumbent and promoted paragraphs each author a successor from the same parent, and the offspring are judged on fresh families at N >= 3 per cell."
first_experiment:
  what: "After Step 0: for up to 10 visible non-detections among 60 seeded driver sites, 3 Motoko sessions each write one oracle-set artefact under one fixed instruction paragraph; the pinned gate set judges each candidate on held-out edits, deduplicated against the visible ones and counted by family."
  pass_if: "At least 4 families convert (every held-out non-detected edit in the family becomes a kill by a named check), from at least 2 classes, each from an item that 2 of 3 sessions reproduced; no earlier kill is lost; zero reds on the unfaulted tree and on 5 known-good commits; the byte-identical rerun and a comment-only source commit convert nothing."
  fail_if: "Fewer than 4 families convert; or visible families convert and held-out ones do not; or a kill is lost; or a known-good commit turns red; or either null converts anything. If Step 0 is not green and identical on rerun, the loop does not start."
  cost: "Step 0: 3-5 agent-days plus a few hours of gate time; per-item cost is to be measured there (last record about 46 s for the judge tier). Loop: 2-3 agent-days for the oracle-only admission policy and the split; at most 30 proposer sessions [unverified]."
disagreements:
  - with: neon
    about: "Whether the first loop targets the oracle set or whole-harness competence. Settled by Step 0's counts (closable seeded families against qualified independent task families) and by how many behavioural reverts the gate set even reaches."
    material: yes
  - with: astra
    about: "Whether the procedure paragraph goes first or second. Settled by whether Motoko sessions can produce a compiling, gate-passing AILANG artefact on three visible items; if fewer than a third do, astra's loop goes first."
    material: yes
  - with: prior-docs
    about: "014's re-ranking puts finishing ADR-004 P2-P3 ahead of any automated editor. Settled by Step 0 item 4: if the judge tier refuses a planted regression, the parked plan is not a prerequisite."
    material: yes
would_change_my_mind_if: "Step 0 finds fewer than six closable seeded families, or the behavioural reverts are almost all unreached by the gate set, or Motoko cannot write a compiling oracle artefact in a third of attempts. Any one of these moves astra's loop ahead of mine; twelve or more qualified independent historical families would make neon's pilot buildable."
embargo_notes: "n/a in round 3. Read the two other round-2 turns and the moderator's fact note; opened no other discussion file."
```
