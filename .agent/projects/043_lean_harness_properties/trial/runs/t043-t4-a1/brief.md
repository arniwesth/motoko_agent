You are working in a snapshot of the Motoko repository at `/home/motoko/trial-043/s/t043-t4-a1/tree`. Write all your output to
`/home/motoko/trial-043/s/t043-t4-a1/out`. Do not read anything outside those two directories, and do not run `git`.

Your target and its registered properties:

**T4. The digest chain** (`src/core/journal.ail:242-300`). Intent: the comments on
`chain_digest_over` and `chain_digests_over` ("the prefix chain, not just its last element").
`sha256Hex` is treated as an injective black box.
- **P4.1** (primary): `chain_digests_over(b, xs ++ ys)` equals `chain_digests_over(b, xs) ++
  chain_digests_over(chain_digest_over(b, xs), ys)`.
- **P4.2** (primary): `length(chain_digests_over(b, ms))` equals `length(ms)`, and for a
  non-empty `ms` its last element is `chain_digest_over(b, ms)`.

Find every violation of these properties that you can show on the real code, and any other
defect in these functions. The snapshot may contain defects, some introduced deliberately and
some not. It may also contain none.

Your method is **executed checks on the real code**. Write programs in TypeScript (bun) and
AILANG (`ailang run --relax-modules`) that call the real functions. Generate inputs any way you
choose, and compare twins with each other and other functions with an executable statement of
the property. Do not write Lean or any other model of these functions. The files under
`.agent/projects/043_lean_harness_properties/evidence/diff/` (`enumerate.ts`,
`enumerate_fold.ail`, `compare_fold.awk`) show the style.

You have 2 hours from your first tool call. Deliver to `/home/motoko/trial-043/s/t043-t4-a1/out`: `reports.tsv` in the format
below, every harness you wrote, and `SUMMARY.md`, saying what you checked, with which
generators, and up to what size. 

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
