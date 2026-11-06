You are working in a snapshot of the Motoko repository at `/home/motoko/trial-043/s/t043-t2-b2/tree`. Write all your output to
`/home/motoko/trial-043/s/t043-t2-b2/out`. Do not read anything outside those two directories, and do not run `git`.

Your target and its registered properties:

**T2. The herdr failure vocabulary**, a cross-language twin.
`herdrFailureCode` and `herdrMeansAgentGone` (`src/tui/src/wake-waiter.ts:129`, `:142`), and
`failure_code` and `means_agent_gone` (`packages/motoko-ext-herdr/types.ail:1160`, `:1198`, via
`failure_shape` `:1127`). Intent: the comment at `wake-waiter.ts:125` ("the TS twin of"), and
`means_agent_gone`'s comment ("narrow on purpose").
- **P2.1** (primary): for every exit code and stderr, with no spawn error,
  `herdrMeansAgentGone` equals `means_agent_gone`.
- **P2.2** (secondary): `herdrFailureCode` equals `failure_code`. The two vocabularies are
  known to differ outside herdr's JSON (K6), and whether they are meant to agree there is open.

Find every violation of these properties that you can show on the real code, and any other
defect in these functions. The snapshot may contain defects, some introduced deliberately and
some not. It may also contain none.

Your method is **Kiro's**, as `.agent/projects/043_lean_harness_properties/RESEARCH-lean-harness-properties.md`
§1 describes it:
(1) model the functions in Lean 4.28.0, core only, no Mathlib, no Lake, with a header naming the
source file and lines;
(2) test the model against the real code on generated inputs, and fix the model until they
agree, counting each fix;
(3) prove each property, or state a `bug_` theorem with a concrete counterexample;
(4) reproduce each counterexample on the real code with a script.
You may execute the real code **only** for (2) and (4). Nothing you report as proved may use
`sorry` or `native_decide`. Record `#print axioms` for every theorem. The files
`PairingModel.lean`, `diff/enumerate.lean.tail` and `diff/run_diff.sh` in that project show the
style.

You have 2 hours from your first tool call. Deliver to `/home/motoko/trial-043/s/t043-t2-b2/out`: `reports.tsv` in the format
below, every model, theorem and script you wrote, the axiom report, and `SUMMARY.md`, saying
what you proved, what you could not, and how many times step (2) changed the model.


Tab-separated, with a header row:

| Column | Content |
|---|---|
| `report_id` | `[arm][replicate]-[target]-[n]`, e.g. `A1-T4-2` |
| `property` | A registered id (`P4.1`) or an exploratory one (`X-1`, stated in `SUMMARY.md`) |
| `route` | `proof`, `execution` or `reading`: how the defect was first seen |
| `claim` | One sentence: what is wrong, on which input |
| `repro` | One command from the tree root. Exit 1 when the defect is present, 0 when absent, within 120 s |
| `witness` | The concrete input |
| `notes` | Anything else, such as reachability if known |
