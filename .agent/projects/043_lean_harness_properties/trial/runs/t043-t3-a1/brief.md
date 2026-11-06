You are working in a snapshot of the Motoko repository at `/home/motoko/trial-043/s/t043-t3-a1/tree`. Write all your output to
`/home/motoko/trial-043/s/t043-t3-a1/out`. Do not read anything outside those two directories, and do not run `git`.

Your target and its registered properties:

**T3. The journal writer twin and the round trip** (ADR-003 D1, D4).
`SessionJournal` (`src/tui/src/session-journal.ts:139`; "THE TWIN", `:21`) and
`journal_lines_of_records` (`src/core/journal.ail:2137`), judged by `fold_journal` (`:1677`).
Intent: `session-journal.ts:21-27` ("Where they disagree the FOLD is the judge").
- **P3.1** (primary): for every sequence of wire events a run can emit, the journal the host
  writes and the journal the twin writes fold alike. Either both are refused with the same
  refusal id, or both are accepted with equal `history` and `dangling`.
- **P3.2** (primary): `fold_journal(journal_lines_of_records(h, rs), leaf)` accepts every
  record list `rs` that a run can emit, and its `history` is the one the fold's rule 3 defines
  for `rs` (`journal.ail:1266-1270`). That is: the seed, then one message per appended entry,
  where an entry with `replaces_previous` takes the place of the message before it, and from the
  latest `history_replaced` onwards, that entry's messages and the entries after it.

Find every violation of these properties that you can show on the real code, and any other
defect in these functions. The snapshot may contain defects, some introduced deliberately and
some not. It may also contain none.

Your method is **executed checks on the real code**. Write programs in TypeScript (bun) and
AILANG (`ailang run --relax-modules`) that call the real functions. Generate inputs any way you
choose, and compare twins with each other and other functions with an executable statement of
the property. Do not write Lean or any other model of these functions. The files under
`.agent/projects/043_lean_harness_properties/evidence/diff/` (`enumerate.ts`,
`enumerate_fold.ail`, `compare_fold.awk`) show the style.

You have 2 hours from your first tool call. Deliver to `/home/motoko/trial-043/s/t043-t3-a1/out`: `reports.tsv` in the format
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
