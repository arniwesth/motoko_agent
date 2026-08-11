# 2026-08-04 Cluster 15: WI-A17 — the `ailang test` coverage axis, and the end of Milestone A

## Context

Branch: `arniwesth/mot-54-execute-wi-a17`

Session span: `af1db7e` → `ac5cf4a`, **2 commits**, one of them production tooling. Input was
`HANDOFF-execute-a17-test-coverage-axis.md`, executed cold against HEAD. Fifteenth code session of
project 009, following clusters 1–14. Pin v0.26.0.

**MILESTONE A IS COMPLETE.** Ten cluster rows, seventeen work items, and this was the last. The
project is now externally blocked on the upstream recorded-stream API.

| | |
|---|---|
| The inventory (`make test_coverage`) | **landed, green** |
| The sealing probe, wired with inverted polarity | **landed, green** |
| CI wiring (`make dst` + its own workflow step) | **landed, green** |
| Fixing any test the item exposed | **not taken** — out of scope by the handoff, and ten were found |
| Filing the AILANG defect upstream | **not taken** — outward-facing, written up locally instead |

## What landed

| Commit | Item |
|---|---|
| `26f2a4d` | the inventory, ten fixtures, the skip-reason table, the C5 harness, Makefile + CI wiring, cluster report, two issue files, plan and cluster-map updates |
| `ac5cf4a` | hash record and a wording correction in the cluster map |

**20 files, 1736 insertions, 45 deletions.** New: `tools/test_coverage/derive.py` (712),
`skip_reasons.json` (97), `mutants.py` (101), ten `.ail` fixtures (160 total).
Modified: `Makefile` (+50, two targets), `.github/workflows/verify-extensions.yml` (+7, one step).

**Not one line of `src/core`, `src/tui`, `packages/` or `scripts/` changed.** The A5 anchors
(`stub_step.ail:161`, `session.ail` 948/1053/2290/2400) and `driver_only` v3 were never at risk;
the sixth consecutive item to pay zero on that cascade, and this one could not have paid.

**`make dst` exits 0** on the committed tree, read as an exit status — **762 checks** against 700 at
the item's start. `make check_core` was **not re-run**: no file it globs changed, verified by
diffstat rather than assumed.

## The order the work took

1. **Grounding**, ~17 minutes: the plan's S7/S8, cluster 14's correction 0, the Makefile's existing
   `ailang test` invocations, the CI workflow's actual target list.
2. **A full sweep before writing anything** — `ailang test` over all 60 `.ail` files under
   `src/core`, 3m08. **This produced three of the session's four corrections** and is the single
   highest-value thing done.
3. **Ten fixtures, each verified to produce the shape it claims**, before the deriver existed.
4. **The deriver**, ten named rules, then the skip table.
5. **C5 mutation** — 14 mutants. First pass 11/14. The three failures were defects in *my own*
   guards, not in the mutants.
6. **Wiring**, then the two live demonstrations, then `make dst`.

## The decision this item owned — and I did not build what the handoff described

The handoff's deliverable: "an inventory that fails when a file carrying inline tests is not run by
any CI-invoked target."

**That shape keeps the defect one level up.** For a file to be "referenced by a target", a target has
to name it — so the roster is still hand-maintained, merely enforced. The enumeration here is
`Path("src/core").rglob("*.ail")`: a new module is covered the moment it exists and the
"unreferenced" state cannot occur.

`check_core`'s own `src/core/*.ail` glob is the same bug one level down — one directory, no
recursion, which is exactly why it never saw `src/core/test/scripted_ports.ail` or
`src/core/ext/runtime.ail`. `fixtures/nested/` keeps the recursion asserted.

**What could not be derived away is one reference, and it moved up a level.** `make dst` and the CI
workflow are different sets — `program_persistence`, `invariants`, `strict_replay` and six others run
locally and are absent from the workflow's gate list — so the inventory checks **its own
reachability** (`ci_unreachable`, `dst_unreachable`). Sixty file references became one, and that one
is checked. Recorded as C1: stronger than the plan's clause, and not a literal satisfaction of it.

### How a deliberate absence is expressed without a list of exceptions

The handoff flagged this as possibly unresolvable. **The reason already existed in the runner's own
output**, so nothing had to be recorded in any source file:

- **Nothing asserts an expected count for any file.** Cluster 13's `fb_2ad074d754cd2c25` workaround
  changes both derivations identically and is *structurally* invisible rather than exempted.
- **Skips are tolerated by REASON** — the string `ailang test` puts in the skipped test's `error`
  field — **never by filename.** Any file may hit any reason; no list needs editing when one does.
- **Teeth in both directions.** An unrecorded reason is red. A record marked `expected: always` that
  matches nothing is *also* red (upstream fixed it, or the tests are gone). `expected: sometimes` is
  reported and never failed on, because a flaky gate gets relaxed and a relaxed gate stops being read.

**The boundary is stated, not papered over:** a file that had tests and lost all of them fires
nothing. Catching that needs an expected count per file, which is the roster again.

## Three corrections the handoff could not have made

**Correction 0 — the stated vacuity trap is inverted, and the real one is worse.** The handoff says
`ailang test` exits 0 on a zero-test file. **It exits 1** (`total_tests: 0` → `"success": false`).
What it actually does is print `✓ All tests passed!` and **exit 0 when every test was SKIPPED**:

```
$ ailang test src/core/prompts_test.ail ; echo $?
✓ All tests passed!
6 tests: 0 passed, 0 failed, 6 skipped
0
```

Six assertions dead for as long as the file has existed. The handoff's *prescription* — read counts,
not `$?` — was right; its *justification* was the wrong instance.

**Correction 1 — the handoff's own measurement has the hole it warns about.** Its
`^\s+tests \[` grep cannot see `test "..."` blocks, so `prompts_test.ail` is in neither its "38
files" nor its fourteen-row table; and `requires` contracts auto-generate property tests, so
`tool_runtime.ail` is 14 not 12 and `compress.ail` is 5 not 3. **39 files, 370 tests.** The remedy is
the one the handoff asked for: keep the grep, make the JSON authoritative, cross-check per file, go
red on disagreement.

**Correction 2 — a third skip class, found by the instrument after it was built.**
`no generator for parameter opt: Option[string]` — AILANG's property generator is primitives-only, so
`tool_runtime.ail` reads `12 passed, 0 failed`, exits 0, and two properties never ran.

**Ten tests under `src/core` are skipped and green at HEAD, in three classes:**

| File | Skipped | Reason | Class |
|---|---|---|---|
| `prompts_test.ail` | 6 | `Named test blocks not yet implemented` | upstream, deterministic |
| `tool_runtime.ail` | 2 | `no generator for parameter` | upstream, deterministic |
| `compress.ail` | 2 | `requires not satisfied by random input` | project, non-deterministic |

## The probe the plan told an earlier revision to break

`scripts/probe_phase_vocab_sealed.ail` is **not broken**. Its failure is its pass condition — it
imports `MkHistory` and `MkPayload` deliberately, and the compiler refusing that import is the
sealing assertion holding, recorded as such by project 004. It is wired with **inverted polarity**,
and the check is on `IMP010` **naming a sealed symbol**, not on a non-zero exit: a probe failing for
a syntax error would satisfy "exit != 0" while certifying nothing.

The plan's current A17 text was already corrected; the handoff's warning was about a superseded
revision. **The origin of the wrong claim was
`.agent/issues/ailang-test-coverage-has-no-target-and-a-probe-is-broken.md`**, which recorded the
probe as broken and recommended "repair or delete". That file is now corrected in place — the
filename is left alone so existing links resolve, with a banner at the top saying the title is wrong.
Six cluster reports inherited that claim without anyone reading the probe's own first line.

## Sites 32–34 — three type-checking answers with a silent wrong one, all in my own guards

All three caught by **C5 mutation testing**. Determinism caught none, the compiler caught none, the
fixture suite as first written caught none. **Running total: 34 across fifteen clusters, determinism
0-for-34.**

**Site 32 — a survivor that was never discovered reads identically to one that survived.** The
self-test asserted `fixtures/nested/nested_has_tests.ail` produced no findings. Changing `rglob` to
`glob` drops it from the walk and **every row still passed**. The walk's output is now asserted by
name against the fixture set.

**Sites 33 and 34 — two negative controls rejected by the wrong clause.** `judge_sealing` has three
sequenced clauses. The "probe COMPILES" control passed `(0, "")`, which clause 2 also rejects for
containing no `IMP010`; deleting clause 1 left it green. The "wrong error code" control passed a
parse error naming no sealed symbol, which clause 3 also rejects. **This is site 23's rule verbatim —
a control rejected by clause 1 certifies nothing about clause 2 — committed by the session that read
it that morning.**

**A fourth observation, on the harness rather than the artifact:** the M5 mutant first went red by
*crashing* (`None` dereferenced), not by the guard failing to fire. A mutant that breaks the harness
proves nothing. Every mutant row now requires the self-test to **name the fixture that owns the
guard**, not merely to exit non-zero.

**And a fifth, a different species: a guard that was BLIND rather than wrong.** `dst_unreachable`
matched the literal word `make`; the `dst` recipe invokes `$(MAKE)`. It reported that `make dst` does
not run this target on a tree where line 76 plainly does. No fixture asked — every constructed row
used a workflow's `run: make …` form — and **only running the finished guard against the real tree
found it.**

## What the mutation testing found that the gates did not

14 mutants, **14 caught, zero escapes** — after two rounds. The first round was 11/14, and every one
of the three misses was a defect in the guards rather than a gap in the mutants. Mutants include one
**over-firing** row (`if r.failed:` → `if True:`), which mutation testing structurally cannot catch
on its own and only the four surviving fixtures can (S7).

## Demonstrated, not asserted

Both breaks were made at once; one run reported both, each under its own rule and subject:

```
✗ [failing] src/core/newly_added/added_module.ail
    1 of 1 failed: add_one_test_1 at src/core/newly_added/added_module.ail:5:5
✗ [failing] src/core/step_machine.ail
    1 of 17 failed: test_decide_step_budget_test_1 at src/core/step_machine.ail:246:10
✗ [untracked] src/core/newly_added/added_module.ail
MAKE_EXIT=2
```

- **Breaking one inline test turns the target red** — `step_machine.ail:246`, a file in no target
  that morning, named to the line.
- **A module in a directory that did not exist fails closed** — found by the walk, `failing` *and*
  `untracked`. The second is the CI-invisibility direction.
- **`ci_unreachable` and `dst_unreachable` fired for real** before the target was wired.

Both breaks reverted; working tree clean and verified.

## Sizing

**16 bindings — 7 decided, 9 discovered.** Window **54 minutes**, `af1db7e` (09:55:15) → `26f2a4d`,
against the plan's "under a day, at 27%". Roughly twenty of the 54 were spent waiting on
`ailang test`; the full sweep is 3m40 and was run four times.

**The discovered count OVER-predicts for the first time in five measurements, and the total is the
better estimator here.** Nine discovered against cluster 14's seven predicts 75 min; sixteen total
against sixteen predicts 58; measured **54**. Cost per discovered binding fell 8.3 → 6.0 min.

**The explanation is legible and is worth more than a fifth confirmation would have been.** Six of
the nine discoveries came out of a **single three-minute sweep that took five to write**. S6's second
term counts discoveries as if they arrive independently, and they do not when one measurement covers
a whole axis — the marginal cost of the sixth discovery was zero.

**Judgement ratio (undetermined fraction), split:** deriver **~70%** (the plan fixes one clause and
specifies nothing else); fixture suite **~35%**; skip-reason table **~25%** (the reasons are read out
of the runner; the `always`/`sometimes` disposition is the judgement); wiring **~15%**.

**Round trips: 5 compiler, 4 gate, 3 silent.**

## AILANG notes

**One new defect written up, not filed:**
`.agent/issues/ailang-test-reports-all-passed-when-every-test-skipped.md`. `ailang test` prints
"All tests passed!" and exits 0 when every test was skipped, and `--format json` sets
`"success": true`. Suggested fixes: a `--fail-on-skip` flag, or at minimum stop claiming a pass when
`passed_tests == 0 && skipped_tests > 0`. **Filing is outward-facing and outside this item's scope**
— worth routing through the `ailang-feedback` skill as WI-A3 did.

Two further pin limitations, both recorded in `skip_reasons.json` with `expected: always` so the
inventory goes red the day either is implemented: `test "name" { ... }` blocks are parsed and skipped
wholesale; the property generator has no coverage for `Option` or user-declared ADTs.

**New compiler friction:** `export pure func f(...) -> T { body }` does **not** parse with the brace
on the signature line — the block must begin on its own line. Cost four fixture round trips before
the rule was clear.

**Toolchain measurement:** `ailang test --format json` is stable and much better than scraping the
ANSI report. **Parallelism is counterproductive** — `--jobs 1` is 3m40, `--jobs 4` is 4m10 on twice
the CPU (9m08 user vs 4m27). Concurrent processes contend on the shared compile cache and lose more
to recompilation than they gain from cores.

`fb_2ad074d754cd2c25` (the flaky cluster harness) did **not** reproduce across roughly a dozen runs.

## State at session end

- **`make dst` exit 0, 762 checks.** Working tree clean, both deliberate breaks reverted.
- **Milestone A is complete.** All ten cluster rows DONE, all seventeen work items closed. **WI-A3
  has no cluster-map row and needed none** — "file the two upstream reports", done 2026-08-02 with
  the plan, no source surface. Checked by reading the rows, per cluster 14's correction 0, rather
  than by trusting the completion sentence.
- Milestones B and C remain externally blocked on the upstream recorded-stream API;
  `HANDOFF-post-upstream-recorded-stream-landing.md` holds the triggered graph.
- The full report is
  `.agent/projects/009_motoko_dst_execution/NOTE-cluster-15-execution-report-and-plan-corrections.md`.

**One cost to accept or revisit:** the new CI step is **3m40** of a 20-minute job, and parallelising
it is slower. That is structural on this pin.

**The most useful thing carried forward.** Cluster 14's parting note was that determinism caught 0 of
31 silent-wrong sites and Milestone B should budget mutation loops as the cost of the wave. This
session adds three more sites, all of them in guards written *by a session that had just read the
rule they violated*, and sharpens S8's complement into an operational form worth carrying into B:

> **For a guard of N sequenced clauses, each control must be rejected by its own clause and ACCEPTED
> by all the others** — and for a control that must SURVIVE, assert that the mechanism *saw* it, not
> merely that it produced no finding.

Site 23 stated the first half for two conjuncts and it was violated anyway, twice, within hours of
being read. **A rule that is known and still violated is a rule that needs a check, not a re-reading**
— which is the whole thesis of this work item, arriving on the work item itself.
