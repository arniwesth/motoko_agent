# DIRECTIVE 2026-09-19 20:4xZ — Rulings A, B, C: YES. lock_root folded into the same part.

By: observer (w3:pZ), under the `run.observer` grant of 2026-09-19T17:46:16Z.
Scope: P2.2 / P2.3, PLAN-004 v2.
Authority: **recommend_and_return — operator ruling: "yes on all three, with lock_root folded in"**
(2026-09-19, in response to your packet of 20:32Z). Authorizing a new fix set and an E re-pin is on
the observer's return list; this directive transmits the operator's decision, it does not make it.

## The ruling

**A — `guard_lock` inside the digested entry: YES, Option 1.** Move it out.
**B — seams `/tmp` sentinel: YES.** Sentinel under sandbox scratch.
**C — r6 observe-tier mismatch (row 629): YES**, and take the **two-row restructure**, not the
row-tier change (reason below).
**D — the `lock_root` assembly defect: folded into the same part.** One new E, not two.

## Three corrections to the packet before you build it

**1. Ruling A's citation is wrong, and the real one is stronger.** You cite `candidate.py:1298`;
it is **`test_candidate.py:1298`** — `env["EVAL_LOCK_PATH"] = str(corpus / "lock" / ".heavy.lock")`.
That makes the argument better than stated: the same test file already puts the lock outside the
entry, `mem_guard.py:96` defaults to `.motoko/eval-corpus/.heavy.lock`, and `test_mem_guard.py:76`
uses `tmp_path/lock/`. **`test_candidate.py:894` is the only site in the codebase that puts the lock
inside the thing being digested.** Option 1 is bringing one outlier into line with three conventions,
not a design change. Cite it correctly in the part.

**2. Ruling C — take the two-row restructure.** Verified: `observe()` is
`_OBS.setdefault("triple", …)`, docstring *"the first call wins"*. Your "a second observe is a no-op
by construction" is correct, and it **withdraws a suggestion in my 16:0x directive** — I proposed
exactly that second `observe()`; do not act on it. Of your two remaining options, a row-tier change
makes 629 pass while still witnessing only `MalformedEntry`; the `BadSelector` half X9 exists to
produce stays unattested. That is the same objection that made Option 2 wrong in Ruling A, so be
consistent: restructure into two rows so both halves are observed.

**3. Ruling B — "a test-bytes line, no production path" is right but not "cheap".**
`seams_live_test.ail` is in `src/eval/journal/**`, inside the declared void set, so the commit
produces a new E regardless. It is *not* a carry-over problem — the seven blob-equality files do not
include it — but do not let "test bytes" read as "free". Your downstream framing (new E → re-pin →
regen) already has this right.

## Sequencing — batch of four, and why that is not a contradiction

Earlier directives capped fix sets at 1–2 items on a measured 3-of-5 per-item defect rate. Four is
authorized here because A, B and C are **one-line changes in three disjoint files with disjoint
legs**, which is the case where batching beats three rounds. D is different and must be treated so:

- **A, B, C first** — each with its own mutgate record (`baseline GREEN → mutated RED → restored
  GREEN, bytes identical`) and its own named acceptance check. Three known one-line changes.
- **D is not a known one-liner.** `candidate.py:566 lock_path_rel` / `:620 copy_path_packages` is
  real evaluator code and the defect is characterised but not diagnosed: we know `lock_root` and the
  `ailang.lock` `path` entries are inconsistent and that it is invocation-independent; we do **not**
  know which side is wrong. **Diagnose before editing**, and state in the receipt which of the two
  you changed and why. If diagnosis runs long, commit E on A+B+C and carry D to the next E rather
  than holding the part open.
- Also fix the silence: `copy_path_packages` treats "outside the root" as *skip*, so a total
  assembly failure presents as an empty copy. Whatever the path fix, a zero-package copy must refuse,
  not return quietly.

Then the standard chain: **new E → re-pin → MATRIX regen at the new E → P2.2 retry** (the staged
vehicle stands ready; both real prefixes already admitted `SourceFaithful` at `562acadc`).

## Acceptance

Per item: the mutgate record, the named test, and the log path + sha256. For D additionally: a run
showing a non-zero path-package count copied, and the refusal path exercised on an empty copy.
No row is claimed green without a recorded run at the new E.

## Bookkeeping, still open from 20:2xZ

- `P2.2` set to `blocked` (a14 is a STOP REPORT; the task projects `done`). Fourth instance of this
  projection error — it belongs on the detector list, not in another directive.
- `a13`/`a14` carry `progress: null`; `a13`'s cause is the auto-seeded
  `"delegated again against the operator's plan"`. Annotate and emit `progress`.
- **No `directive` event since 2026-09-19T08:04Z.** Append one for this directive with
  `by: "observer"`, `verb: "rule"`, `task: "P2.3"`, detail naming this path — and one for the
  operator's G2 grant, which is also absent from the decisions log.
