# Brief: follow-up review of PLAN-004 v1.1 (delta against your v1 review)

Same repo, branch and rules as `BRIEF-plan004-v1-review.md`: read-only except the one review document
you write; no commit; no `make dst`, replay, prototype, profiling or other heavy execution; no herdr
pane or agent operations; do not edit `.dagr/run-plan004.json` or the plan; no corpus content in the
review (counts, digests, indices, identities only). `ailang check`, `git show`, `dagr check`,
`dagr view --snapshot` and targeted Python reads are fine. Evidence under
`/tmp/claude-1001/-workspaces-motoko-agent/d8b1d53b-1a2d-4c49-b4ec-fc412754e86a/scratchpad/codex-review-plan004/`
(subdirectory `v1.1/`). Verify HEAD; the plan is grounded at `3920814`.

## Under review

- `.agent/projects/013_core_architecture_for_dst/PLAN-004-implement-adr-004.md`, **v1.1**, rewritten
  to apply your `REVIEW-plan004-v1-verdicts-codex.md` "Required changes for v1.1" (its §9 maps each).
- `.dagr/run-plan004.json`, restructured to match (the ids of never-started parts changed: P1.2, P1.4,
  P1.7, P1.9 were split; PLAN1G, REV2, P1.1G, P1R, PLAN2G added; P6 canceled). `REV2` in that graph is
  this review.
- New evidence the plan now relies on for §8: `packages/motoko-ext-herdr/dagr.ail:215–335`
  (`plan_task_of`, `seed_tasks`, `seed_from_plan`) and `DESIGN-dagr-as-delegation-view.md` §10.6.

## What the review must do

1. **Disposition of your eight required changes**, one row each: ADDRESSED / PARTIAL / NOT ADDRESSED,
   with evidence (plan line, graph task id, or command output).
2. **Re-verdict every part you returned in v1** (V5, QRET, PSYNC, PREV, P1.2, P1.4, P1.6, P1.7, P1.9,
   P1G, P2.2, P3.2, P4, P5, P6) as it now stands, including the split parts (P1.2a/b, P1.4a/b,
   P1.7a/b, P1.9a/b) and the new ones (PLAN1G, REV2, P1.1G, P1R, PLAN2G): ACCEPT / ACCEPT WITH
   CORRECTIONS / RETURN.
3. **The §8 protocol against the code.** Read `seed_tasks` and `plan_task_of`: is "one writer of the
   plan file at a time; a running session only settles existing tasks; structure changes go into a new
   plan file taken up by a fresh session" consistent with what the producer actually does and with
   §10.5–10.6? Is there a remaining hazard (e.g. settlements in the plan file versus the producer's own
   run file for the same task, or the `.plan-<pane>-<session>` marker) the protocol misses?
4. **§0.10 review/gate mechanics in dagr terms.** Is the RETURN path — review attempt `done`, reviewed
   attempt `rejected`, a `sent_back` attempt, a `followup` review attempt, the gate reading the latest
   verdict — expressible under the dagr v3 contract without a `dagr check` error at each step (task
   state as a projection over attempts; causes pointing backward)? Check the declared `policy` blocks
   (future node ids, `streak`, `loop_back`) for correctness and for colliding with ids a real round
   would use. Construct the intermediate documents in scratch and `dagr check` them if needed.
5. **The M1–M14 matrix** against D8 P1's list, your v1 §5 gaps and the v5 required changes 1–5, 8:
   remaining gaps, and whether §3's reading of "known-divergent and known-refused per refusal family"
   is a defensible interpretation of D8.
6. **The new contracts.** P1.4b's checker (lexer, spans, original-byte hash, manifest from `git show`,
   failure behaviour, self-test independence); P1.6's provenance table and A9b truth check against
   `dst_profile.ail` / `dst_driver_only.ail` / `strict_replay_dst.ail:631–633`; P1.9a's execution
   provenance (import closure from import lines; the `ailang` cache — check what the installed
   `ailang` actually does, read-only); P2.1's guard semantics; P2.2's selector and measurement; P3.2's
   four obligations.
7. **Graph ↔ plan audit again**: `dagr check .dagr/run-plan004.json --strict --json`; one task per part;
   deps equal each part's stated "Deps"; gate fan-ins; criteria agree with plan text; owners match the
   stated convention; the ready set (after `PLAN1G`: SWEEP, V5, P2.1; now: QRET, REV2); `P6` canceled;
   the §1 skeleton diagram agrees with the graph.
8. **New errors** v1.1 introduced — facts, numbers, estimates (§1/§7 sums), citations — with corrections.
9. **Verdict for `PLAN1G`**: may the operator settle it (ACCEPT / ACCEPT WITH CORRECTIONS, listing the
   corrections), or RETURN with "Required changes for v1.2".

## Output

Write `.agent/projects/013_core_architecture_for_dst/REVIEW-plan004-v1.1-delta-verdicts-codex.md`:
header (date, HEAD, branch, subject, inputs, method, what you did not do, evidence directory); overall
verdict; §1 the eight dispositions; §2 part re-verdicts; §3 the §8 protocol; §4 review/gate mechanics;
§5 matrix; §6 new contracts; §7 graph audit; §8 new errors; "Verdict for PLAN1G" with required changes
for v1.2 or None. Every claim carries a file:line at HEAD or a command and its output. When finished,
reply with only the review file's path.
