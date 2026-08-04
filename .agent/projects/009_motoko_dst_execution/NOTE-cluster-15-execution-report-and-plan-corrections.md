# Cluster 15 — WI-A17, the `ailang test` coverage axis

**Milestone A is complete.** Ten cluster rows, seventeen work items, and the last one is this.
`make dst` exit 0 at **762 checks**, from 700 at the item's start. The project is now externally blocked on the upstream recorded-stream API.

Handoff: `HANDOFF-execute-a17-test-coverage-axis.md`. Pin v0.26.0.

---

## Correction 0 — the handoff's stated vacuity trap is inverted, and the real one is worse

The handoff says:

> **`ailang test` exits 0 on a file with zero tests.** Verified: `ailang test src/core/version.ail`
> prints a results banner and exits 0.

**It exits 1.** On v0.26.0, `total_tests: 0` sets `"success": false`:

```
$ ailang test src/core/version.ail ; echo $?
No tests found
  ✓ Passed: 0
  ✗ Failed: 0
1
```

That matters in the opposite direction from the one the handoff drew: a universal runner must
**recognise a zero-test file and pass over it**, because otherwise all 21 test-free modules under
`src/core` turn the target red.

**But the trap the handoff was reaching for is real, and it is sharper than the one it described.**

```
$ ailang test src/core/prompts_test.ail ; echo $?
✓ All tests passed!
6 tests: 0 passed, 0 failed, 6 skipped
0
```

**Six tests, none of them run, "All tests passed!", exit 0.** The skip reason is
`Named test blocks not yet implemented` — v0.26.0 parses `test "name" { ... }` and skips every one.
`src/core/prompts_test.ail`'s six assertions have been dead for as long as the file has existed, and
nothing could see it, because the runner calls the file green.

So the handoff's *prescription* — assert the count, not the exit status — is correct and is what the
deliverable does. Its *justification* was the wrong instance. **Both instances are only visible by
running the tool and reading the numbers** — cluster 14's observation that building an instrument and
reading its output is cheaper than the deliberation it replaces, holding again and harder.

---

## Correction 1 — the handoff's own measurement has the hole it warns about

The handoff's mission says a grep-based derivation can drop a file silently, and then derives its
own table from one:

```bash
grep -rlE "^\s+tests \[" src/core --include=*.ail
```

**`src/core/prompts_test.ail` matches that pattern zero times and carries six tests.** It is in
neither the handoff's "38 files carry inline tests" nor its fourteen-row table. The measured truth at
HEAD is **39 files and 370 tests**, not 38.

Two forms escape the pattern, and both are in production use:

| Form | Where | Tests it produces |
|---|---|---|
| `test "name" { ... }` | `prompts_test.ail` | 6, all skipped |
| `requires { ... }` contracts | `compress.ail`, `tool_runtime.ail` | 4 auto-generated properties |

A `requires` clause makes AILANG generate a property test. Nothing shaped like `tests [` can see it.

**This is S8's complement landing on the item that was commissioned to guard against it**, and the
remedy is the one the handoff asked for: the syntactic derivation is kept, the runner's JSON is
authoritative, and **the two are cross-checked per file every run**. A form the pattern misses is now
`undetected` and red, instead of absent and indistinguishable from a file that never had tests.

---

## Correction 2 — a third skip class, found by the instrument after it was built

Neither the handoff nor correction 0 knew about this one. The first clean inventory run reported it:

```
✗ [unrecorded_skip] src/core/tool_runtime.ail::isSome_property_1
    no generator for parameter opt: Option[string]
✗ [unrecorded_skip] src/core/tool_runtime.ail::is_native_backend_property_1
    no generator for parameter b: ToolBackend
```

AILANG's property generator covers primitives only, so a `requires` contract on a function taking an
`Option[string]` or a user ADT generates a property it cannot then feed. **`tool_runtime.ail` reads
`12 passed, 0 failed` and exits 0 with two properties that never ran.**

**Ten tests under `src/core` are skipped at HEAD and every file carrying them is green:**

| File | Skipped | Reason | Class |
|---|---|---|---|
| `prompts_test.ail` | 6 | `Named test blocks not yet implemented` | upstream, deterministic |
| `tool_runtime.ail` | 2 | `no generator for parameter` | upstream, deterministic |
| `compress.ail` | 2 | `requires not satisfied by random input` | project, non-deterministic |

All three are recorded in `tools/test_coverage/skip_reasons.json` with a justification and a
disposition. **None is fixed here** — per the item's scope, a test this exposes is a finding to
report, not to repair inside it.

---

## The decision this item owned — how "carries inline tests" is derived

**By running `ailang test --format json` over every file and reading `total_tests`.** The syntactic
grep is retained only as a second opinion that must agree.

The handoff framed the deliverable as an inventory that fails when a file with tests is *unreferenced
by a target*. **That framing preserves the defect one level up:** a target still has to name each
file, so the roster is still hand-maintained — merely enforced. The enumeration here is
`Path("src/core").rglob("*.ail")`, so a new module is covered the moment it exists and the
"unreferenced" state cannot occur.

`check_core`'s own `src/core/*.ail` glob is the same bug one level down: one directory, no recursion,
which is exactly why it never saw `src/core/test/scripted_ports.ail` or `src/core/ext/runtime.ail`.
`fixtures/nested/` exists to keep the recursion asserted rather than assumed.

**What could not be derived away is one reference, and it moved up a level.** A target that nothing
invokes is as blind as a file that no target names, and `make dst` and the CI workflow are different
sets — `program_persistence`, `invariants`, `strict_replay` and six others run locally and are absent
from the workflow's gate list. So the inventory checks **its own reachability**: `ci_unreachable` if
no workflow runs `make test_coverage`, `dst_unreachable` if the `dst` recipe does not. Sixty file
references became one target reference, and that one is checked.

### How a deliberate absence is expressed without a list of exceptions

The handoff flagged this as possibly unresolvable and offered "record the reason in the file". **The
reason turned out to already exist in the runner's own output**, so nothing needed to be recorded in
any file:

- **Nothing asserts an expected count for any file.** Cluster 13's `fb_2ad074d754cd2c25` workaround —
  moving a flaky assertion out of a `tests` block into an acceptance script — changes both
  derivations identically and is *structurally* invisible to the inventory rather than exempted.
- **Skips are tolerated by REASON, never by filename.** The table is keyed on the string
  `ailang test` puts in the skipped test's `error` field. Any file may hit any reason; no file list
  needs editing when one does.
- **The table has teeth in both directions.** A reason no record accounts for is red. A record marked
  `expected: always` that matches *nothing* in the run is also red — either upstream implemented the
  feature and the tests should be switched back on, or they were deleted. A record marked
  `expected: sometimes` (compress.ail's, which depends on drawn input) is reported and never failed
  on, because a flaky gate gets relaxed and a relaxed gate stops being read.

**The boundary is stated rather than papered over.** A file that had tests and lost all of them fires
nothing: both derivations agree on zero. Distinguishing that from a legitimate deletion needs an
expected count per file, which is the hand-maintained roster again.

---

## The sealing probe — wired with inverted polarity

`scripts/probe_phase_vocab_sealed.ail` is not broken, and the plan's current text already says so
(the "fix or retire" wording and the `scripts/dst/` path were a superseded revision; the handoff's
warning was about that revision, not about HEAD). Its failure is its pass condition.

**The check is on the error code and the symbol, not on a non-zero exit.** A probe that started
failing for an unrelated reason — a syntax error, a renamed module — satisfies "exit != 0" while
asserting nothing about sealing. Three clauses: exit status, `IMP010`, and a sealed constructor name.

---

## Sites where both answers type-check and the wrong one is silent

**Three, all in this item's own guards, and all caught by C5 mutation testing.** Determinism caught
none, the compiler caught none, and the fixture suite as first written caught none.

**Site 32 — a survivor that was never discovered reads identically to one that survived.** The
self-test asserted that `fixtures/nested/nested_has_tests.ail` produced no findings. Changing
`rglob` to `glob` drops the file from the walk entirely and **every row still passed**: absent and
correct are the same observation. The remedy is structural — the walk's output is now asserted by
name against the fixture set — and it is S8's complement arriving on the fixture suite itself rather
than on a digest.

**Sites 33 and 34 — two negative controls rejected by the wrong clause.** `judge_sealing` has three
clauses in sequence. The control for "a probe that COMPILES" passed `(returncode=0, output="")`,
which clause 2 also rejects for containing no `IMP010`; deleting clause 1 left the row green. The
control for "the wrong error code" passed a parse error naming no sealed symbol, which clause 3 also
rejects; deleting clause 2 left that row green. **Both are site 23's rule verbatim — a control
rejected by clause 1 certifies nothing about clause 2 — committed by the session that had just read
it.** Each control now satisfies the two clauses it does not target.

**Running total: 34 sites across fifteen clusters. Determinism has caught none.**

A fourth observation, on the mutation harness rather than on the artifact: the M5 mutant first went
red by **crashing** (`None` dereferenced) rather than by the guard failing to fire. A mutant that
breaks the harness proves nothing about the rule. Every mutant row now requires the self-test to name
the fixture that owns the guard, not merely to exit non-zero.

---

## What the deliverable is

| Path | What |
|---|---|
| `tools/test_coverage/derive.py` | the inventory; ten named rules, a fixture self-test, and constructed rows for what no fixture can express |
| `tools/test_coverage/skip_reasons.json` | the three tolerated skip reasons, each with a justification and a disposition |
| `tools/test_coverage/fixtures/` | ten `.ail` fixtures — five that must fire a named rule, five that must survive |
| `tools/test_coverage/mutants.py` | the C5 harness; run by hand, mutates `derive.py` in place |
| `Makefile` | `test_coverage`, `test_coverage_selftest`; both in `dst` |
| `.github/workflows/verify-extensions.yml` | a step of its own, so a coverage regression is its own red check |

### Demonstrated, not asserted

Both breaks were made at once and one run reported both, each under its own rule and subject:

```
✗ src/core/newly_added/added_module.ail: 0/1 passed
✗ src/core/step_machine.ail: 16/17 passed

✗ [failing] src/core/newly_added/added_module.ail
    1 of 1 failed: add_one_test_1 at src/core/newly_added/added_module.ail:5:5
✗ [failing] src/core/step_machine.ail
    1 of 17 failed: test_decide_step_budget_test_1 at src/core/step_machine.ail:246:10
✗ [untracked] src/core/newly_added/added_module.ail

test_coverage: 4 finding(s) across 3 rule(s)
MAKE_EXIT=2
```

- **Breaking one inline test turns the target red.** `src/core/step_machine.ail:246` — a file in no
  target this morning, holding the max-steps discrimination cluster 4 filed — flipped `((), true)`
  to `((), false)`. Named to the line.
- **A module in a new location fails closed.** `src/core/newly_added/added_module.ail`, in a
  directory that did not exist, with one wrong test: found by the walk, reported `[failing]` *and*
  `[untracked]`. The second is the CI-invisibility direction — the file ran on this machine and was
  not in the repository.
- **`ci_unreachable` and `dst_unreachable` fired for real** on the first run, before the target was
  wired, and `dst_unreachable` then caught its own blind spot (`$(MAKE)`, above).
- **14 of 14 C5 mutants caught, zero escapes**, including one over-firing mutant that only the
  survivors can catch (S7). The first attempt was 11 of 14: two escaped outright (sites 33, 34) and
  one went red for the wrong reason (the M5 crash).

Clean run at HEAD: **60 files discovered, 39 carry tests, 370 tests, 360 passed, 10 skipped**, exit 0.
The target costs **3m40** of the CI job's 20-minute budget.

---

## Sizing — S6, and the discovered count predicts a fifth time

**Recorded bindings: sixteen — seven decided, nine discovered.**

**Decided** — resolvable from the handoff, the plan and the standing rules before running anything:

1. The enumeration is a recursive walk, not a roster.
2. Every rule reads a count or a per-test status; none reads an exit code.
3. The sealing probe is wired on `IMP010` plus a symbol, not on a non-zero exit.
4. Skips are keyed on reason, never on filename.
5. Two derivations, cross-checked per file (S8, asked for explicitly).
6. Reachability moves up a level: check the target's one reference instead of sixty file references.
7. Its own CI step rather than another name in the DST gates list.

**Discovered** — only visible after running something:

1. **`ailang test` exits 1 on a zero-test file** (correction 0), so zero-test files must be
   recognised rather than failed.
2. **It exits 0 with "All tests passed!" when every test is skipped** (correction 0) — the reason the
   skip machinery exists at all.
3. **A third skip class**, found by the instrument after it was built (correction 2).
4. **`requires` contracts generate property tests**, and `test "..."` blocks are unimplemented
   (correction 1) — this fixes the shape of the syntactic derivation.
5. **`property "..."` appears in zero files**, so a pattern for it would be a regex no fixture can
   assert; deliberately excluded, and a file using it trips `undetected`.
6. **Parallelism is slower.** `--jobs 1` takes 3m40; `--jobs 4` takes 4m10 while burning 9m08 of CPU
   against 4m27. Concurrent `ailang test` processes contend on the shared compile cache and lose more
   to recompilation than they gain from cores. Default is serial, measured rather than assumed.
7. **Site 32** — the undiscovered survivor.
8. **Sites 33 and 34** — the two mis-clauses controls.

**The ninth is a different species worth naming: a guard that was BLIND rather than wrong.**
`dst_unreachable` matched the literal word `make` and the `dst` recipe invokes `$(MAKE)`, so it
reported that `make dst` does not run this target on a tree where line 76 plainly does. No fixture
asked the question — every constructed row used a workflow's `run: make …` form — and **only running
the finished guard against the real tree found it.** The rule was right, its matcher saw one of the
two invocation forms that exist, and a rule that is silent about a form it cannot recognise is
indistinguishable from a rule that is satisfied. It now matches both forms and a self-test row holds
each.

### Cost, as the git wall-clock window

| Piece | Window |
|---|---|
| Grounding, and the sweep over all 60 files that produced corrections 0, 1 and 2 | **~17 min** (09:55 → 10:12) |
| The deriver, the ten fixtures, the skip table, and the wiring | **~11 min** (10:12 → 10:24) |
| C5 mutation, the three it caught in my own guards, and the two live demonstrations | **~25 min** (10:24 → 10:49) |

**Whole item: 54 minutes** on the clock, handoff `af1db7e` (09:55:15) to `7e721f6`, against the
plan's estimate of **"under a day, at 27%"**. Roughly twenty of the 54 were spent waiting on
`ailang test`: the full sweep is 3m40 and it was run four times.

**The discovered count OVER-predicts for the first time in five measurements, and the total is the
better estimator here.** Nine discovered against cluster 14's seven predicts 75 minutes; sixteen
total against sixteen predicts 58; the measured window is **54**. Cost per discovered binding fell
from 8.3 min to 6.0.

**The explanation is not that S6's second term is wrong — it is that this item's discoveries were
unusually cheap, and the reason is legible.** Six of the nine came out of a single three-minute sweep
that was written in five. A discovered binding normally costs what it costs because finding it
*is* the work; here one instrument surfaced six at once and the marginal cost of the sixth was zero.
**S6's second term counts discoveries as if they arrive independently, and they do not when one
measurement covers a whole axis.** Cluster 14 observed that building an instrument is cheaper than
the deliberation it replaces; this is that observation showing up in the estimator as an error, which
is worth more than a fifth confirmation would have been.

### Judgement ratio, split

(The figure is the *undetermined* fraction.)

- **Machinery, the deriver: ~70%.** The plan fixes one clause — "verified by an inventory that fails
  when a file with tests is unreferenced — not a hand-maintained list" — and specifies nothing else.
  What a file "carrying tests" is, what the universe is, what happens to a skip, what the rule set is,
  and what "CI-invoked" means were all undetermined, and the last two are where the risk was.
- **Content, the skip-reason table: ~25%.** The reasons are read out of the runner and are not a
  choice. What is judged is each one's `always`/`sometimes` disposition, and that judgement is the
  difference between a gate that goes stale loudly and one that goes flaky.
- **Machinery, the fixture suite: ~35%.** S7 and C5 fix the shape — a fixture per rule, asserted by
  name, plus survivors. What was undetermined is which syntactic forms are *real*, and that was
  measured rather than invented: every fixture reproduces a shape that exists in `src/core`.
- **Machinery, the Makefile and CI wiring: ~15%.** Conventional, except for the decision to make it
  a separate CI step, which costs 3m40 of a 20-minute job.

### Round trips

**5 compiler, 4 gate, 3 silent.**

- **Compiler (5).** `export pure func f(...) -> T { body }` does not parse with the brace on the
  signature line — the block must start on its own line; `not b` in that position was a red herring.
  Four more were fixture syntax converging on the same rule.
- **Gate (4).** The M5 mutant crashing instead of firing; the first self-test run, where
  `skip_unrecorded.ail` fired two rules and so could not show which caught it; `property "` having no
  fixture; `$(MAKE)` unrecognised by `dst_unreachable`.
- **Silent (3).** Sites 32, 33, 34.

---

## Corrections to the plan and the cluster map

**C1. WI-A17's acceptance evidence is met, with one clause reinterpreted.** The plan says "every
`.ail` file carrying inline tests is in a target CI invokes, verified by an inventory that fails when
a file with tests is unreferenced". The inventory makes "unreferenced" unreachable for files and
checks the one reference that remains — the target's own. This is stronger than the clause and does
not satisfy it literally; recorded here rather than silently.

**C2. The handoff's measured gap is short by one file, and two of its per-file counts are low.**
39 files carry tests, not 38 — `prompts_test.ail` (6) is in neither its count nor its table. Within
the table, `tool_runtime.ail` is 14 rather than 12 and `compress.ail` is 5 rather than 3; both
undercount by exactly their `requires`-derived properties, which is the same blindness in a second
place. Authoritative total at HEAD: **370 tests across 39 files**. See correction 1.

**C3. WI-A3 has no row in the cluster map, and it is not a gap.** The map covers ten clusters and
sixteen work items; A1–A17 is seventeen. **A3 is "file the two upstream reports", done 2026-08-02
with the plan itself** — it has no source surface and never needed a cluster. Checked because cluster
14's correction 0 established that the completion sentence does not read the cluster map; this time
the map was read row by row and the one item it does not carry was run down. It is complete.

**C4. Milestone A is complete.** Ten cluster rows, all DONE; seventeen work items, all closed. Update
the map's row 10.

---

## Standing rules — nothing new, and one sharpened

**No new standing rule.** S7 and S8 covered this item's whole risk surface, exactly as the handoff
predicted, and both fired.

**S8's complement, sharpened by sites 32–34, and the sharpening is about SEQUENCED clauses.** The
rule as written concerns a *trajectory* that does not enter a branch. Three sites here are the same
failure in a guard made of **ordered clauses**: an input that a later clause also rejects cannot
certify an earlier one, and deleting the earlier clause leaves the row green. Site 23 recorded this
for `has_jwt`'s two conjuncts; sites 33 and 34 are the same shape in a three-clause `if/elif` chain,
committed by a session that had read site 23 that morning. **Site 32 is its dual: a control that must
SURVIVE certifies nothing if the mechanism never reached it.**

The operational form, and it is cheap: **for a guard of N sequenced clauses, each control must be
rejected by its own clause and ACCEPTED by all the others** — and for a surviving control, assert
that the mechanism *saw* it, not merely that it produced no finding.

---

## What is next

**Nothing in Milestone A.** The project is externally blocked on the upstream recorded-stream API;
`HANDOFF-post-upstream-recorded-stream-landing.md` holds the triggered graph.

The register the Milestone B wave inherits is unchanged by this item, plus one new entry:

1. **`max_resource_size`** — a one-draw item. Owner: the first item that touches the generator.
2. **`seed_state`'s version axis** (site 22).
3. **The two `ScriptedStep` widenings** — the fault half and the latency half.
4. **Shrinking** — deferred past the first name-adoption gate.
5. **NEW: the ten skipped tests**, written up in
   `.agent/issues/ailang-test-reports-all-passed-when-every-test-skipped.md`. `compress.ail`'s two
   properties are a project defect with a named fix (tighten the generators or narrow the input
   type). The other eight are upstream limitations whose records are marked `always`, so the
   inventory goes red on the day either is implemented and the tests can be switched back on.
   **None is silent any more.**

**One thing this item deliberately did not do: file upstream.** The reporting defect —
"All tests passed!" and exit 0 over a fully-skipped file — is an AILANG bug and belongs in
`sunholo-data/ailang` via the `ailang-feedback` skill, as WI-A3 did for its two reports. Filing is
outward-facing and outside this item's scope, so it is written up locally and left for a decision.

`.agent/issues/ailang-test-coverage-has-no-target-and-a-probe-is-broken.md` is marked resolved, and
its "second, smaller finding" — the origin of the six-times-inherited claim that the sealing probe is
broken — is corrected in place. The filename is left alone so existing links resolve.
