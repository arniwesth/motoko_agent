# Motoko DST technical report

Start with the [integrated third draft](DRAFT-3.md). It combines the first draft's
general explanation of deterministic simulation testing with the current
architecture, including journal-derived evaluation through the shared harness.
Conformance and honest coverage accounting remain major themes.

The report has three drafts:

- [Draft 3 — integrated report](DRAFT-3.md): the current working report, with a
  [PDF reading copy](DRAFT-3.pdf) and [scope and evidence notes](SCOPE-3.md).

- [Draft 2 — current-system account](DRAFT-current.md): an account of the implementation at
  `7e5ec5f9`, inspected on 2026-09-19, including project 013's world-state checks,
  park/wake protocol, session journal, and evaluation work.
- [Draft 1 — original report](DRAFT.md): the August account, grounded at `b3953a9`. Its
  [PDF](DRAFT.pdf), [scope](SCOPE.md), [review](REVIEW-round1.md), and two SVG figures
  belong to that version.

Drafts 2 and 3 describe source snapshot `7e5ec5f9`. Draft 3's status table separates
implemented machinery from completed validation. It does not claim a fresh
full-suite pass or completed real-entry validation of the journal-derived
evaluator. [Draft 2's notes](SCOPE-current.md) retain the earlier drafting record.
