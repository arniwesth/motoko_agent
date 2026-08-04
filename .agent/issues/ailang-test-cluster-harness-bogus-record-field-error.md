# AILANG: `ailang test`'s cluster harness fails a passing test NON-DETERMINISTICALLY with `record has no field: <name>`

**Status:** **Filed upstream 2026-08-04 — ticket `fb_2ad074d754cd2c25`, category `bug`.** Reproduced
against the pin, **non-deterministic**, workaround applied. Not minimised to a standalone module —
see "What did not reproduce".

**Independently re-reproduced before filing, at the same rate.** The workaround had removed the
trigger from the tree, so a reviewer re-created it: appended a one-line test with the same body to
`dst_invariants.ail`, ran `ailang test` ten times, and counted — **6 failures in 10**, matching this
note's measurement exactly, with the identical nested message
(`harness evaluation failed: harness evaluation failed: record has no field: site`). The source was
restored afterwards and `git diff` is clean. **Two independent 6-in-10 measurements is what made this
worth filing unminimised**: the rate itself is evidence, and the nested "harness evaluation failed"
gives whoever owns the harness a lead that does not require our closure.

Filed via the `ailang-feedback` skill's Channel 3, with the same trackability caveat as the other
tickets — see `ailang-no-warning-for-unreachable-match-arm.md`'s *How it was filed*.
**Pin:** AILANG v0.26.0 (`3b52a24`).
**Found:** WI-A14 piece 1, building `src/core/dst_invariants.ail`.
**Severity:** it fails in the good direction (a correct test is reported as failing), but it makes a
gate **flaky**, which is worse than a gate that is red — a flaky gate trains the reader to re-run
instead of to read.

## Symptom

An inline test whose entire body is one cross-module call fails with

```
✗ test_done_event_is_still_classified_logical_test_1
    harness evaluation failed: harness evaluation failed: record has no field: site
```

The body is:

```ailang
pure func test_done_event_is_still_classified_logical() -> bool
  tests [((), true)]
  {
    is_logical(event_vocabulary(), "DoneEvent")
  }
```

`site` is a field of no type this module declares, imports directly, or reaches from this call. It
belongs to `src/core/dst_profile`'s `CoreSite`, which is in the module's **transitive** closure
(`dst_invariants` → `dst_replay` → `dst_profile`).

`ailang check` is clean. Clearing `.ailang/cache` changes nothing. The failure is at evaluation time,
inside the test-cluster harness.

## It is non-deterministic, and that is the important part

Same source, same command, no cache change, ten consecutive runs:

```
$ for i in $(seq 10); do ailang test src/core/dst_invariants.ail </dev/null; done
```

**6 of 10 failed**, always the same test, always the same message. The other four passed with
`9 tests: 9 passed`.

Two controls, both stable over every trial:

| Command | Result |
|---|---|
| `ailang run --caps IO --entry main scripts/dst/invariants_dst.ail` — the *same* call, in a script | 6/6 pass |
| `ailang test src/core/dst_event_vocabulary.ail` — the callee's own module | 6/6 pass |

So it is not the expression, not the callee, and not `ailang` generally. It is `ailang test`'s
cluster harness on a module with this closure.

## Adjacent deterministic form, found first

Before the non-determinism was noticed, the same message appeared **deterministically** for a larger
conjunction in the same module, and the trigger looked like operand order:

| Test body | Result |
|---|---|
| `is_logical(rows, "DoneEvent")` alone | passes |
| `(not registered) && (not in_gap)` | passes |
| `is_logical(rows, "DoneEvent") && (not registered) && (not in_gap)` | **passes** |
| `(not registered) && is_logical(rows, "DoneEvent")` | **fails** |
| `(not in_gap) && is_logical(rows, "DoneEvent")` | **fails** |
| `(not registered) && (not in_gap) && is_logical(rows, "DoneEvent")` | **fails** |
| the same with the call `let`-bound first, then referenced | **fails** |

Given the non-determinism measured afterwards, "passes" in that table should be read as "passed on
the trials run", not as a stable classification. The one robust observation is that the failure
always names a record field from an unrelated module in the closure.

`let`-binding does not help, which distinguishes this from
[`ailang-record-update-field-call-is-not-a-dependency`](./ailang-record-update-field-call-is-not-a-dependency.md),
where `let`-binding is the fix.

## What did not reproduce

A reduced module — same imports (`dst_event_vocabulary`, `dst_replay`, `ports`, so the same
`dst_profile` in the closure), same test body, one test function — passed every trial. The trigger
needs something about the containing module, most likely how the harness groups multiple test
functions into an evaluation cluster; the error text says "harness evaluation failed" twice, nested,
which reads like a cluster wrapping a cluster.

Minimising that means bisecting nine test functions against a closure of fifteen modules **against a
6-in-10 failure rate**, where any single trial is uninformative. Not attempted; the workaround was
cheaper and is an improvement on its own terms.

## Workarounds applied

**1. Split conjunctions into one row per fact.** The original single test asserting three things
became three tests. Independently correct — cluster 12's rule is that a row should assert its own
fact so a red row names what broke — and it reduced the failure to one row.

**2. Move the surviving flaky assertion out of `tests` and into the acceptance script.** The
assertion is not weakened and not retried; it now runs under `ailang run` in
`scripts/dst/invariants_dst.ail`, where it is deterministic, and `make invariants` runs that. The
module carries a comment at the removal site pointing here and at the script row, so the assertion
cannot be assumed missing.

`make invariants` is now 5/5 green.

## Why it is worth filing despite not being minimal

The error text is actively misleading. The first fifteen minutes went into looking for a `site` field
that has nothing to do with the failure — it names an implementation detail of an unrelated module
in the closure. An error that said "internal harness error evaluating `<test name>`" would have been
routed correctly in one minute. That is a cheap fix upstream even if the underlying cause is not.
