# Note: the "`ailang run` exits 0 on type errors" defect report was a false alarm

Date: 2026-07-03
Toolchain: AILANG v0.26.0 (commit `3b52a24`), HEAD `8227053`
Provenance: the Phase-A plan-review session (the same pass that produced finding G8 in
`PLAN-phase-a-pure-foundations.md`). Recorded because (a) the retraction must be as findable
as the claim was, and (b) the failure mode generalizes — this project's evidence-first
discipline caught a false substrate-defect report *minutes before it was headed upstream*.

## What was claimed

During the plan's self-review, `scripts/smoke_v2_pending_full_loop.ail` (type-broken at HEAD;
G8) appeared to run with **exit code 0** while printing its type error and producing no
output. Three separate observations "confirmed" it, and the claim — "`ailang run` prints
type errors but exits 0; an AILANG substrate defect, candidate for upstream filing" — was
written into the plan's G8 entry, the WI-0 harness rationale, and the ADR's dispositions log.

## The refutation (minimal repro)

A minimal repro was built before filing — a single module with a record-field type error:

```ailang
module repro_exit0
import std/io (println)
type R = { a: int }
func mk() -> R { { a: 1, b: 2 } }
export func main() -> () ! {IO} { println(show(mk().a)) }
```

Result: `ailang check` → error, **rc=1**. `ailang run --caps IO --entry main` → error on
stderr, **rc=1**. No defect. Both G8 smokes were then re-measured **without pipes**:

```
ailang run --caps … scripts/smoke_v2_pending_full_loop.ail </dev/null >/dev/null 2>&1 ; echo $?   # 1
ailang run --caps IO,Env,Clock --entry main scripts/smoke_v2_handle.ail >/dev/null 2>&1 ; echo $? # 1
```

`ailang run` exits 1 on type errors, exactly as it should.

## Root cause of the false reading: `$?` through a pipeline

Every rc=0 observation had the same shape:

```bash
ailang run … 2>/dev/null | sed 's/…/…/' > out.jsonl ; echo "rc=$?"   # sed's status: 0
ailang run … 2>&1 | tail -20 ; echo "rc=$?"                           # tail's status: 0
```

`$?` after a pipeline is the **last** command's exit status. `sed` and `tail` exit 0
regardless of what ailang did. The reading was consistent across three "independent"
checks because all three shared the same instrumentation bug — convergence of measurements
is worthless when the measurements share a flaw.

The observation that *felt* like corroboration — "zero output, yet exit 0" — was two true
facts wrongly joined: zero **stdout** output (the error goes to stderr, which was discarded
or merged downstream) and exit 0 (the pipe tail's, not ailang's).

## What survives the retraction

- **13 of 32 `scripts/*.ail` fail `ailang check` at HEAD** (G8) — measured directly with
  `&&`/`||` on the check command itself, no pipes; this is real and unaffected.
- Their invisibility is fully explained by **G6 alone**: no CI target checks or runs
  `scripts/`. Each broken file fails loudly the moment anything executes it; nothing does.
- The harness design lessons stand, re-justified: `ailang check` per smoke (fail fast,
  readable error), zero-event detection for full-loop smokes (a run that dies before the
  loop emits nothing), and — the actual lesson of this note — the harness itself **must
  `set -euo pipefail`**, or its own normalization pipe (`ailang run … | sed …`) reproduces
  exactly this masking in production use.

## Corrections applied (2026-07-03, same day as the claim)

- `PLAN-phase-a-pure-foundations.md`: WI-0 contract steps 1 and 6, the TL;DR G8 line, the
  G8 entry, the Addendum, the smoke-list annotation, and the review-pass verification table
  all corrected; the pipefail requirement added to the harness contract.
- `ADR-001-phase-oriented-core.md`: the G8 disposition bullet now records the sub-claim as
  **retracted** with the repro evidence.
- No upstream issue was filed. One piece of *optional* cosmetic feedback could still go to
  AILANG (not a defect): `ailang run` prints `✓ Running <file>` on stdout *before*
  module-load type checking has actually succeeded, which makes a load-time failure read as
  a mid-run failure. Harmless, but it contributed to the misreading.

## The generalized rules (added for reuse)

1. **A substrate-defect claim requires a minimal repro before it enters any document.** The
   repro is cheap (this one was six lines) and it is the only evidence that isolates the
   substrate from your instrumentation. This is the same discipline that caught the DST
   ADR-001 R5 staleness — applied, this time, against our own fresh finding rather than an
   inherited one. Fresh findings and inherited facts rot the same way: unverified.
2. **Never measure exit codes through a pipeline.** `$?` after `a | b` is `b`'s status.
   Capture rc adjacent to the command (`cmd; rc=$?`) with redirections instead of pipes, or
   run under `set -o pipefail`. Any test harness that pipes a gated command must set
   pipefail or it will convert failures into silent passes — the exact bug class the
   harness exists to catch.
3. **Independent-looking confirmations must have independent instrumentation.** Three
   observations through the same flawed pipe are one observation.
