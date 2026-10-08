---
repo: arniwesth/motoko_agent
pr: 226
branch: docs/dst-report-pbmt-citation
ticket: null
title: "docs(dst-report): draft 3 cites property-based mutation testing for its kill criterion"
---

## Summary

Adds one paragraph to §7.5 of the DST report's third draft, and a fourth external reference. The
paragraph says that Motoko's mutation discipline counts a mutant as killed only when the check
written for the broken rule fails, that this is the kill criterion of Bartocci et al.,
*Property-Based Mutation Testing* (ICST 2023), and what Motoko does not yet do: compute a
property-based mutation score, or generate mutants by operator. The operator asked for the
sentence and the citation on 2026-10-06, after asking whether the paper adds value to the harness.

## Changes

- docs(dst-report): draft 3 cites property-based mutation testing for its kill criterion

1 file changed.

## Governing docs

No project document governs the report draft. What the paragraph describes and what the draft
asks of an edit:

- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`: the discipline
  the paragraph describes. Rule 3 is the kill criterion.
- `papers/motoko-dst-report/SCOPE-3.md`: the draft's editorial rules. "Keep immediate
  qualifications where omitting one would change a claim" is why the paragraph says the
  discipline was adopted after the report's snapshot.

The research behind the comparison is a separate pull request, #227.

## The text

In §7.5, after the paragraph that ends "a systematic study across all families remains separate
work":

> Motoko's mutation discipline, adopted after this report's snapshot, uses a property-based kill
> criterion in the sense of Bartocci et al. (2023): a mutant counts as killed only when the check
> written for the broken rule fails. It does not yet compute a property-based mutation score or
> generate mutants by operator.

In Appendix A: reference 4, and the sentence about what the external references support. It said
all of them support §2.1. It now says references 1 to 3 do, and reference 4 supports §7.5.

## Predicted outcome

- **The report names the kill criterion it uses and its published counterpart.** Checked by
  reading §7.5 and Appendix A.
- **The claim stays inside the draft's snapshot rule.** The draft describes `7e5ec5f9`, inspected
  on 2026-09-19. The discipline is dated 2026-10-04, and the paragraph says it came later.
- **Nothing a session does changes.** Checked: `git diff --name-only origin/main...HEAD` lists
  `papers/motoko-dst-report/DRAFT-3.md` and this pull request's own record, and nothing else.

## Test evidence

- [x] **The definition the paragraph relies on was read in the paper's TeX source.** A mutant is
  φ-killed when some test satisfies the property on the original program and violates it on the
  mutant (the paper's definition of a φ-killed mutant, section 3).
- [x] **The reference's title, authors and venue are as the arXiv listing gives them.**
- [x] **Both new link labels resolve.** `[pbmt]` is the arXiv page. `[mutationrule]` is a file
  that exists on `main`, checked with `ls` from the draft's directory.
- [x] **One file changed besides this record.** `git diff --name-only origin/main...HEAD`.
- [ ] `DRAFT-3.pdf` was not regenerated. It is behind the markdown by this paragraph.
- [ ] `SCOPE-3.md` was not edited. It still says the third draft adds references for
  FoundationDB, TigerBeetle and Antithesis.
- [ ] The reference was not compared with the IEEE version of the paper.
- [ ] No check renders the markdown.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
