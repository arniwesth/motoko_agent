XXX # Handoff: execute the throwaway vertical spike through the real driver

Audience: a fresh agent session with no context from the sessions that wrote the ADR or revised it.

**Your distance from the author is the point, and this time it is not about fresh eyes — it is about
stake.** The decisions you are about to test were revised on 2026-07-26 by an agent that then wrote
the plan you are executing. D4 in particular was rewritten from scratch after review found its
original mechanism did not exist, and the rewrite made it *stricter*. Nobody has tried to build it.
An agent carrying that authorship is measurably more likely to route around an awkward call site than
to report that the call site cannot be routed. You are not carrying it.

## Mission

Execute `PLAN-spike-real-driver-vertical.md` in this directory. It is the contract: five questions,
each with a falsification criterion fixed before the work started, plus a sequence, a scope boundary,
and a disposal rule. Read it first and treat it as binding.

**A falsification is a successful outcome.** The spike exists to find out whether the architecture
can be built, and "it cannot, here is exactly where" is worth more than a green run. Report it as a
result, not as a problem you failed to solve.

## The three failure modes, in order

1. **Suppressing a falsification by working around it.** This is the primary risk and the reason a
   fresh session is doing this. Build work pulls hard toward "make it compile." If threading
   `world_state` requires production code to branch on test mode, or requires hidden mutable state,
   D1 forbids both — and a workaround that gets you to a passing compile has converted a finding
   into silence. When you find yourself reaching for a workaround, that is the moment to stop and
   write it down instead.
2. **Scope drift into the migration.** The work looks like the production migration, which invites
   it to become the production migration. The plan's *Out of scope* section is deliberately explicit;
   re-read it when step 3 starts feeling open-ended.
3. **Treating green as the gate cleared.** D1 requires the upstream recorded-stream API to have
   *landed* and the toolchain to be repinned to a released version containing it. You will be
   building against a local, uncommitted patch. No result you produce clears that gate.

## Inputs (read in this order)

1. `PLAN-spike-real-driver-vertical.md` — the contract, including the falsification criteria.
2. `ADR-001-deterministic-test-world-architecture.md` — D1, D4, and D6 are what you are testing.
   **D4 was rewritten 2026-07-26 and is the least-tested decision in the document.**
3. `spike/README.md` — the existing probes, what they prove, and the toolchain traps below.
4. The ADR's two `## Review Comments` sections — twenty findings from two independent reviews. The
   twelve edits made in response are what your build exercises.
5. Source, as the work requires.

## Operational context — the traps

These cost real time and, in one case, nearly produced a false upstream bug report. None is in the
plan; all of them are here.

**The prototype toolchain is uncommitted and exists in exactly one place.**
`~/src/ailang`, branch `dev` at `24120ade2`, with uncommitted changes to `internal/builtins/ai.go`,
`internal/builtins/ai_step.go`, `internal/effects/ai_step.go`, `std/ai.ail`, plus an untracked test
file. Built binary at `~/src/ailang/bin/ailang`. **It is in no repository history.** Do not `git
clean`, `git checkout .`, or `git stash` in that tree without saving the diff first. If it is lost,
`ISSUE-BODY-recorded-stream-api.md` describes the change precisely enough to rebuild.

**A stale `.ailang/cache/compile` silently poisons type resolution.** A cache written by a different
compiler version is reused without a version check, and the resulting error *blames your source*. The
symptom is a type error that contradicts the stdlib you believe you are using — most memorably a
`Message` record-field mismatch. Delete the `.ailang` directory before believing any such error. A
wrong diagnosis of this nearly reached an upstream report.

**`--virtual-time` is a status banner.** It prints `⏰ Virtual time enabled`, then `std/clock.now`
returns real wall-clock epoch and `std/clock.sleep` blocks for real time. Verified on the pinned
toolchain, the prototype, with `--seed`, and with `AILANG_SEED`. This is why D4 was rewritten. Do not
spend time rediscovering it; if you want to confirm, a `now/sleep/now` probe takes two minutes.

**Module resolution follows the working directory, not the file.** A probe outside the toolchain
source root will not find the prototype's `std/ai`. Run from `~/src/ailang` with an absolute path to
the probe, and set `AILANG_RELAX_MODULES=1` so the module name need not match the path.

**`Message` gained an `images` field in v0.30+.** AILANG records are closed, so every literal needs
`images: []`. That is the Q3 migration. 67 of the 112 sites are single-line literals in a handful of
near-identical shapes; the rest are multi-line. The estimate that it is mechanical is exactly what
Q3 is measuring — do not assume it, count it.

**The existing probes are your harness sanity check.** `spike/run_integration_probe.sh` and
`spike/run_world_slice.sh` pass against the prototype and **fail with non-zero against the stock
v0.26.0 toolchain**. If either goes green against stock, your environment is wrong, not the finding.

## Method

Follow the plan's sequence. Two points deserve emphasis:

**Step 2 has a stop condition.** Measure the `Message` migration and report before continuing. If it
is materially worse than mechanical — sites needing judgement rather than a mechanical edit, or
breakage beyond the `images` field — stop and re-scope rather than pressing on. That is the point
where sunk cost starts driving the work.

**Q2 is the highest-value question.** D4 now requires that every profile-reachable `std/clock` read be
routed before conformance, with no virtualization layer beneath it. The review counted four reads.
Confirm that count independently, then find out whether routing them is tractable. If a reachable read
cannot be routed without changing production behaviour, that falsifies the strictest claim in the
newest decision, and it is the single most valuable thing this spike can produce.

## Output contract

Append a section to `spike/README.md`, alongside the existing probe records.

State your model id and the date. For **each** of Q1–Q5, report one of:

- **CONFIRMED** — with the exact command and output that establishes it;
- **FALSIFIED** — with the exact call site, error, or structural obstacle, stated as a finding; or
- **MEASURED** — for Q3, with real numbers: sites touched, files, elapsed time, and how many needed
  judgement rather than a mechanical edit.

Then:

- **ADR defects found** — numbered, each with grounding and a concrete action. File them as findings.
  **Do not edit the ADR**; it has been revised twice already and a third uncoordinated pass would
  make the audit trail unreadable.
- **What survives** — per the plan's disposal rule: results into `spike/README.md`, the Q3 number for
  the eventual implementation plan, defects as findings. The code dies with the branch.

## Constraints

- **Work on a branch that never merges.** Branch from the current branch; open no PR.
- **Do not modify the ADR.** Findings only.
- **Do not file anything upstream.** The recorded-stream issue is drafted, reviewed, and deliberately
  unfiled pending a human decision; the stale-cache and virtual-time bugs are separate reports that
  are also not yours to send.
- **Do not treat a green result as the D1 gate cleared.** Say so explicitly in your report.
- **Verify by execution.** A claim you did not run is a claim you cannot certify. Report the exact
  command for any failing or surprising result.
- If everything confirms and nothing falsifies, say so plainly — and record the residual risk, which
  is that a vertical slice through two request kinds does not prove the remaining five will thread as
  easily.
