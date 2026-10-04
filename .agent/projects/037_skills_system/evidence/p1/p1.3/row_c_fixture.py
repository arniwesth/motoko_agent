#!/usr/bin/env python3
"""037 P1.3c: add the row-c workload to a fixture template.

  row_c_fixture.py <fixture-dir>

Writes PROJECT.md and reports/R01.md … R14.md. The workload is what drives the
run past the compaction thresholds: 14 delegate reports of about 10,000 chars
each, to be recorded one at a time in a dagr run file under the `dagr-producer`
skill. Each report needs a different recipe from that skill, so the skill's
text stays needed for the whole run. Deterministic (fixed seed): every run and
every model gets the same bytes.
"""
import hashlib, os, random, sys

PROJECT = """# Project atlas-release

The run to track is the 0.9 release of the Atlas service. One orchestrator hands work to
delegates; each delegate works in its own Herdr pane and reports back in writing.

## Tasks

| id | title | depends on | acceptance |
|---|---|---|---|
| T1 | schema-migration: add the `tenant_region` column and backfill it | - | migration log, row counts match |
| T2 | api-compat-shim: keep v1 clients working against the new schema | T1 | contract test suite green |
| T3 | load-test: the shimmed API under production-shaped load | T2 | p99 under 250 ms at the agreed rate |
| T4 | docs-update: operator guide for the region column | - | reviewer sign-off |
| T5 | release-notes: 0.9 notes, linked from the operator guide | T4 | reviewer sign-off |
| G1 | ship-readiness: a gate over T3 and T5 | T3, T5 | both inputs done with evidence |
| T6 | rollout: staged rollout to the three regions | G1 | - |

## How the record is kept

- The run file is `.dagr/run-atlas.json` in the working directory.
- The reports arrive in `reports/`, numbered in arrival order: `R01.md` … `R14.md`.
- A report is the only source for what happened. Record exactly what it says: who ran the
  attempt, in which pane, what evidence it names (path and sha256), and how the attempt ended.
- The verdict at the END of a report is what counts. Earlier lines in the work log may claim
  success before the reviewer has ruled.
"""

# (report id, title, task, facts written at the top, verdict written at the end)
REPORTS = [
    ("R01", "T1 attempt 1 started", "T1",
     ["Delegate `delegate-a` started attempt 1 of T1 in pane `w3:p2` at 2026-10-01T08:02:11Z.",
      "Runtime: a Motoko delegate on `openrouter/deepseek/deepseek-v4-pro`."],
     "VERDICT: none yet. The attempt is RUNNING. Record the task as opened with its first attempt in flight."),
    ("R02", "T4 attempt 1 started", "T4",
     ["Delegate `delegate-b` started attempt 1 of T4 in pane `w3:p3` at 2026-10-01T08:05:40Z.",
      "T4 has no dependency, so it runs beside T1."],
     "VERDICT: none yet. The attempt is RUNNING."),
    ("R03", "T1 attempt 1 reports done", "T1",
     ["`delegate-a` reports attempt 1 of T1 finished at 2026-10-01T09:14:03Z and claims success.",
      "Evidence it names: `evidence/t1-migration.log` (sha256 {d1}) and `evidence/t1-rowcounts.tsv` (sha256 {d2}).",
      "The backfill command exited 0; 4,118,224 rows before and after."],
     "VERDICT: the delegate CLAIMS done. No reviewer has ruled. Record the claim and its evidence; do not settle the task as accepted yet."),
    ("R04", "T1 reviewed and accepted", "T1",
     ["Reviewer `reviewer-1` checked attempt 1 of T1 at 2026-10-01T09:41:55Z.",
      "The reviewer re-computed both digests and they match the report: {d1} and {d2}.",
      "Row counts were re-derived independently from the replica."],
     "VERDICT: ACCEPTED by `reviewer-1`. Settle attempt 1 of T1 as done, with the two evidence files as proof."),
    ("R05", "T4 attempt 1 sent back", "T4",
     ["`delegate-b` reported attempt 1 of T4 finished at 2026-10-01T10:02:30Z with `docs/operator-guide.md` (sha256 {d3}).",
      "Reviewer `reviewer-2` read it at 2026-10-01T10:20:12Z.",
      "Finding: the guide has no section on rolling the column back, which the acceptance row requires."],
     "VERDICT: SENT BACK by `reviewer-2`. Attempt 1 of T4 ends as sent back with the finding above; the task re-enters and needs a second attempt."),
    ("R06", "T2 attempt 1 and T4 attempt 2 started", "T2",
     ["`delegate-c` started attempt 1 of T2 in pane `w3:p4` at 2026-10-01T10:31:07Z. T1 is done, so the dependency is met.",
      "`delegate-b` started attempt 2 of T4 in pane `w3:p3` at 2026-10-01T10:33:48Z, working from the reviewer's finding."],
     "VERDICT: none yet. Two attempts are RUNNING: T2 attempt 1 and T4 attempt 2."),
    ("R07", "T2 attempt 1 lost its runtime", "T2",
     ["At 2026-10-01T11:12:26Z pane `w3:p4` died: the container was OOM-killed while the contract suite ran.",
      "`delegate-c` produced no report and no evidence. Nothing it wrote can be trusted.",
      "The orchestrator started attempt 2 of T2 with `delegate-d` in pane `w3:p5` at 2026-10-01T11:20:00Z."],
     "VERDICT: attempt 1 of T2 is LOST (runtime gone, no result). Attempt 2 of T2 is RUNNING."),
    ("R08", "T4 attempt 2 accepted", "T4",
     ["`delegate-b` reported attempt 2 of T4 finished at 2026-10-01T11:48:19Z with `docs/operator-guide.md` (sha256 {d4}).",
      "Reviewer `reviewer-2` confirmed the new rollback section at 2026-10-01T12:05:02Z and re-computed the digest: {d4}."],
     "VERDICT: ACCEPTED by `reviewer-2`. Settle attempt 2 of T4 as done with the guide as proof."),
    ("R09", "Operator message about the load test", "T3",
     ["The operator wrote at 2026-10-01T12:30:44Z: \"The 10k rps target for the load test is not needed for 0.9. 5k rps is the agreed rate. Do not block the release on 10k.\"",
      "This changes T3's acceptance rate from 10,000 rps to 5,000 rps. It is a human decision, not a delegate result.",
      "No attempt of T3 has started yet."],
     "VERDICT: an OPERATOR MESSAGE to handle and a human decision to record against T3. No attempt changes state."),
    ("R10", "T2 attempt 2 accepted", "T2",
     ["`delegate-d` reported attempt 2 of T2 finished at 2026-10-01T13:15:27Z.",
      "Evidence: `evidence/t2-contract-suite.xml` (sha256 {d5}), 412 tests, 0 failures.",
      "Reviewer `reviewer-1` re-ran the suite at 2026-10-01T13:40:10Z and got the same digest."],
     "VERDICT: ACCEPTED by `reviewer-1`. Settle attempt 2 of T2 as done with the suite result as proof."),
    ("R11", "T3 and T5 attempts started", "T3",
     ["`delegate-e` started attempt 1 of T3 in pane `w3:p6` at 2026-10-01T13:52:00Z, at the operator's 5,000 rps rate.",
      "`delegate-b` started attempt 1 of T5 in pane `w3:p3` at 2026-10-01T13:55:31Z."],
     "VERDICT: none yet. Two attempts are RUNNING: T3 attempt 1 and T5 attempt 1."),
    ("R12", "T5 and T3 accepted", "T5",
     ["`delegate-b` reported attempt 1 of T5 finished at 2026-10-01T14:40:09Z with `docs/release-notes-0.9.md` (sha256 {d6}); `reviewer-2` accepted it at 2026-10-01T14:55:00Z.",
      "`delegate-e` reported attempt 1 of T3 finished at 2026-10-01T15:10:42Z with `evidence/t3-loadtest.json` (sha256 {d7}): p99 212 ms at 5,000 rps; `reviewer-1` accepted it at 2026-10-01T15:31:18Z."],
     "VERDICT: both ACCEPTED. Settle T5 attempt 1 and T3 attempt 1 as done, each with its evidence."),
    ("R13", "Gate G1 evaluated", "G1",
     ["With T3 and T5 done, the orchestrator evaluated the ship-readiness gate G1 at 2026-10-01T15:45:00Z.",
      "Both inputs carry reviewed evidence. No finding is open."],
     "VERDICT: gate G1 PASSES. Record the fan-in gate as satisfied by T3 and T5."),
    ("R14", "T6 cancelled by the operator", "T6",
     ["The operator wrote at 2026-10-01T16:02:37Z: \"Rollout is postponed to next week. Cancel T6 for this run; a new run will carry it.\"",
      "T6 never started. No attempt exists."],
     "VERDICT: T6 is CANCELLED by a human decision. Record the decision and cancel the planned work. This is the last report."),
]

VERBS = ["checked", "re-ran", "compared", "diffed", "sampled", "replayed", "tailed", "counted", "hashed", "queried"]
OBJECTS = ["the replica lag", "the migration journal", "the contract fixtures", "the canary pod logs", "the row-count snapshot",
           "the p99 histogram", "the docs build", "the link checker output", "the schema dump", "the shim's request trace",
           "the tenant sample", "the dashboard panel", "the alert history", "the rollback script", "the changelog draft"]
RESULTS = ["no difference from the baseline", "within the expected band", "one warning, already known and tracked",
           "clean on the second pass after a cache flush", "matches the figure in the summary above",
           "slower than yesterday but under the limit", "unchanged since the previous attempt", "as the runbook predicts"]


def work_log(rng, n, start_minute):
    lines = []
    minute = start_minute
    for i in range(n):
        minute += rng.randint(1, 3)
        hh, mm = 8 + minute // 60, minute % 60
        lines.append("- %02d:%02d:%02dZ step %03d: %s %s (shard %d, sample %d rows, %d ms): %s." % (
            hh % 24, mm, rng.randint(0, 59), i + 1, rng.choice(VERBS), rng.choice(OBJECTS), rng.randint(1, 12),
            rng.randint(200, 90000), rng.randint(12, 4800), rng.choice(RESULTS)))
    return lines


def main():
    fx = sys.argv[1]
    os.makedirs(os.path.join(fx, "reports"), exist_ok=True)
    open(os.path.join(fx, "PROJECT.md"), "w").write(PROJECT)
    digests = {"d%d" % i: hashlib.sha256(("atlas-evidence-%d" % i).encode()).hexdigest() for i in range(1, 8)}
    for n, (rid, title, task, facts, verdict) in enumerate(REPORTS):
        rng = random.Random(3700 + n)
        body = ["# Report %s: %s" % (rid, title), "",
                "Project: atlas-release. Concerns: %s. Report %d of %d, in arrival order." % (task, n + 1, len(REPORTS)), "",
                "## What happened", ""]
        body += ["- " + f.format(**digests) for f in facts]
        body += ["", "## Work log (for the record; nothing in it changes the verdict)", ""]
        body += work_log(rng, 78, 2 + n * 37)
        body += ["", "## Verdict", "", verdict.format(**digests), ""]
        open(os.path.join(fx, "reports", rid + ".md"), "w").write("\n".join(body))
    sizes = [os.path.getsize(os.path.join(fx, "reports", r[0] + ".md")) for r in REPORTS]
    print("row-c workload in %s: PROJECT.md and %d reports, %d-%d bytes each, %d bytes in all" % (
        fx, len(REPORTS), min(sizes), max(sizes), sum(sizes)))


if __name__ == "__main__":
    main()
