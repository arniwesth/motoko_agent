# Submission precondition: every test a fix adds or repairs must discriminate

Date: 2026-09-19. Status: **Proposed** — to be folded into PLAN-004 §0.8 by the plan owner.
Tooling: [`mutgate.sh`](mutgate.sh) (validated 2026-09-19; writes nothing into the evaluator tree,
the sweep clone, or A).

## The rule

For every test a fix adds or repairs, the fix must show, mechanically:

```
baseline GREEN  →  mutated RED  →  restored GREEN, bytes identical
```

where the mutation breaks *the behaviour the test names*. A submission lacking this record for any
new or repaired test is **refused at intake**, exactly as a Part-1 report without its receipts is.

Both halves are load-bearing:

- a test that cannot go **red** under that mutation is **vacuous** — it passes whatever the code does;
- a test that cannot go **green** on unmutated code is **red-by-construction** — it fails whatever
  the code does.

Passing is not evidence. Vacuous tests pass too. Discrimination is the evidence.

## Why this, and why now

PLAN-004 §0.8 already requires red-first/mutation records, and it works: P1 reported **14/14 mutations
caught** across MR1–MR14. But §0.8 governs mutations of *production* code caught by existing tests.
Nothing applied the same discipline to a fix's **own** tests, and that is precisely where round 4
failed.

The P2.3 round-4 basis review ([`answer-mot-dlg-1789810872424.md`](../../../.motoko/herdr-delegates/answer-mot-dlg-1789810872424.md))
found **3 of 5 authorized fixes defective**:

| fix | defect | this gate reports |
|---|---|---|
| mut4 | vacuous — passes on a clean tree regardless | `mutated: green` → FAIL |
| mut5 | red-by-construction — cannot pass as routed | `baseline: red` → FAIL |
| m12 | rename with no mechanical effect, hiding a regression | no red/green pair exists → FAIL |

A 60% per-item defect rate. At that rate a 5-item batch has roughly a `0.4⁵ ≈ 1%` chance of passing
clean, which is why four review rounds have not closed this part. Every one of those three defects is
detectable by the author in about two minutes. Detecting them in review costs a 30-minute round plus
a fix round plus the wall-clock of whatever ran on the bad basis.

**The point is not another gate. It is moving detection from the reviewer to the author**, where the
loop length is actually set.

## Spec format

TSV, one row per (fix, test, mutation); `#` comments allowed:

```
fix_id <TAB> target_file <TAB> sed_expr <TAB> test_cmd
```

- `target_file` — relative to the repo; the file the mutation edits
- `sed_expr` — a `sed -i` expression breaking the behaviour the test names
- `test_cmd` — run from the repo root; exit 0 green, non-zero red

```bash
bash mutgate.sh --spec fixes.tsv --repo /tmp/probe --clone-from "$C"
```

`--clone-from` makes a throw-away `git clone --shared`. **Never run this against a checkout another
delegate is using** — it mutates files in place before restoring them.

## What it checks

Four points per row, all mechanical:

1. baseline green — not red-by-construction
2. mutated red — not vacuous
3. the mutation actually changed bytes — not an inert `sed`
4. restore is byte-identical *and* green again — no residue

Output is `mutgate.tsv` plus the three run logs per row, suitable for attaching to the receipt.
Exit 0 = precondition met; exit 1 = **submission refused**.

## Limits — read before relying on it

- **It proves discrimination, not correctness.** A test can discriminate and still assert the wrong
  expected value. The X8 `test_m12_one_hit_per_component` change — expected position `1` → `0` —
  passes this gate either way. "Which value is right" is answered from the fixture, not from
  observed output, and stays a review question.
- **One mutation per test is a floor, not a ceiling.** It rules out vacuity; it does not establish
  coverage.
- **The author chooses the mutation**, so a weak mutation weakens the result. The mutation must break
  the behaviour the test *names* — the reviewer should still read the `sed_expr`.
- It says nothing about scope, authorization, or whether the fix was the one asked for. Round 4's
  sixth unauthorized change and gate-dirty checkout are outside it.

## Adoption

1. Fold the rule into §0.8 as the test-side dual of the existing production-side requirement.
2. Add to every fix-round brief: *"attach the mutgate record; a submission without it is refused at
   intake."*
3. Reviewers refuse at intake rather than reviewing and returning — that is the whole saving.
