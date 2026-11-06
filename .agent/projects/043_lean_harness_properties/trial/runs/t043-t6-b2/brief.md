You are working in a snapshot of the Motoko repository at `/home/motoko/trial-043/s/t043-t6-b2/tree`. Write all your output to
`/home/motoko/trial-043/s/t043-t6-b2/out`. Do not read anything outside those two directories, and do not run `git`.

Your target and its registered properties:

**T6. Compose's output clipping** (`truncate_utf8_by_bytes`,
`packages/motoko-ext-compose/store.ail:19-29`). Intent: the function's name.
- **P6.1** (primary): for `n ≥ 0`, the result's byte length is at most `n`.
- **P6.2** (primary): the result's bytes are a prefix of the input's bytes, and the input is
  returned unchanged when it fits.
- **P6.3** (secondary): a valid UTF-8 input gives a valid UTF-8 result. Known violated (K2).

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

You have 2 hours from your first tool call. Deliver to `/home/motoko/trial-043/s/t043-t6-b2/out`: `reports.tsv` in the format
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
