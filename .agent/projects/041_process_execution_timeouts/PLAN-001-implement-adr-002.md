# PLAN-001: implement ADR-002, per-call process timeouts

Implements [ADR-002](ADR-002-per-call-process-timeouts.md) (this dir), **Accepted 2026-10-31 under R9, ninth
revision**, rulings R1-R11.

Date: 2026-10-31. Status: **Proposed, not started.**
Planned against: **`e3293edebfcfa2fc591fcb5ff16143f8f9118390`**. Every ADR line number below is from that commit.
Grounded at: `src`, `packages`, `scripts`, `tools` and the `Makefile` are identical in that commit and
`origin/main` `a393314b`, so every code `file:line` below holds on `main`.
Pinned toolchain: AILANG **v0.54.14** (`ailang.lock:2`, `ailang.toml:6`,
`scripts/install-prerequisites.sh:40-41`). Upstream state read with `gh` on 2026-10-31.
Structure: [`PLAN-001.dagr.json`](PLAN-001.dagr.json) holds the tasks and their dependencies, and is the only
place they are stated (008 ADR-001 D2 and D3). A task's address is `041/PLAN-001/<task id>`.
Naming: W1-W14 are work items, A1-A25 are the ADR's §6 criteria
(*Coverage*), Q1-Q10 and G1-G6 are resolved points the ADR now settles, H1 is the one point it leaves open, and C1-C5 are this plan's own choices.

---

## TL;DR

- **Fourteen work items, one pull request each.** W1-W7 can start now: the ADR is accepted under R9, so W4-W7
  no longer wait. W8-W14 wait on upstream.
- **W1 is the R6 admission test, first,** because R6 reopens if it fails. An early probe at this
  commit passes (*Experiments*, E1), but only the full test on the post-change code decides.
- **Nothing activates until W12.** Before it, the live world stays `Legacy`, the schema does not
  advertise `timeout_secs`, and the replaced catalog test stays in force. W12 is the only item that
  turns a limit on. It needs W8 (a pin with #2035 and #2036), W9 (the D6 fix) and W10-W11.
- **All four upstream issues are open,** with no comments and no linked pull request. At every wait
  the answer is R4 or R5: the session setting stays the only relief, and nobody forks AILANG or
  builds a second executor.
- **The ADR now settles Q1-Q10 and G1-G6.** One small point stays open (H1), and W11 confirms the startup route,
  which D7 says is read from the code and not built.

## Standing rules

1. **Re-ground before building** (`.agent/meta-decisions/re-ground-inherited-anchors-before-building.md`).
   Each item re-reads its anchors and records in its pull request what moved. An item that finds the
   ADR wrong stops and records the evidence. It does not build around it.
2. **One item, one worktree, one branch, one pull request** (`AGENTS.md`). Start with
   `tools/worktree/new.sh`, check overlap with `tools/worktree/status.sh <paths>`, and open through
   `tools/pr`. A worktree has no `.env` or `ailang/`, so `tools/pr` needs `MOTOKO_BOT_GH_TOKEN`.
3. **Mutation discipline** (`.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`).
   Each item names its mutants below, with the expected test. Only that test failing counts as a
   kill. The evidence is `mutants.tsv` and the commit it ran at, under `evidence/<item>/` in this dir.
4. **Heavy runs one at a time.** `make dst`, `make eval_matrix` and `make corpus_pr` never run
   together, or alongside another session's. `make eval_matrix` is under the 12 GiB rule.
5. **Green is a difference.** A heavy gate compares FAILED names and matrix rows with the item's base.
   Each item lists what it expects to move. Any other changed row is a finding.
6. **No `Limits` in a live world before W12.** W4-W11 test the new paths through scripted `Limits`
   programs and direct calls. Each of those items keeps the guard test from C2 green.

### Gates

`CONTRIBUTING.md`, "Local Motoko changes", sets the base. Every item names these sets:

| Set | Commands |
|---|---|
| **G-base** | `make check_core`, `make test`, `cd src/tui && bun run test` |
| **G-core** (any change to `src/core`) | G-base, `make test_coverage`, `make new_contract_policy BASE=origin/main`, `make verify_classify_check` |
| **G-dst** (world, program or dispatch change) | G-core, `make anchors attribution_table profile_definition execution_program program_persistence strict_replay seeded_generator world_state invariants corpus_judge corpus_pr fault_catalogue journal_resume` |
| **G-heavy** | `make dst`, then `make eval_matrix`, each compared with the base |

`make test` runs only `test_core`, and inline tests are picked up by `make test_coverage`, so that
target is the one that exercises new tests in `src/core`. Every new `pure func` in `src/core` carries
a contract or a comment saying what blocks one.

## What is true at `e3293ede`

The ninth revision did not change the ADR's §2. Its anchors hold where I checked them: `tool_phase.ail:291` and `:499-507`,
`ports.ail:1865`, `:1884` and `:2172`, `session.ail:1372` and `:1527`, `tool_runtime.ail:1040`,
`tool_envelope_dispatch.ail:47`. These further facts bear on the items.

**The path of one call.** `dispatch_tool_entries`' native arm (`tool_phase.ail:488-524`) emits
`V2ToolDispatchStart`, reads the clock (`:499`) and `MOTOKO_TOOL_TIMEOUT_MS`, builds the invocation
and calls `ports.tool_exec`. The live arm then runs `world_tool` (`ports.ail:1820`) →
`live_tool_outcome` (`:1865`) → `dispatch_one_typed` (`tool_dispatch_adapter.ail:276`) →
`run_native_batch` → `run_native_call` (`tool_runtime.ail:234`) → `run_process_result` (`:1017`).

**A new `WorldState` field does not cross the token by itself.** `world_json` and `world_of_json`
(`ext_world.ail:600`, `:642`) list fields one at a time. The extension bridge decodes the world from
the token (`session.ail:1357`). Loopback holds only `ctx.world`. D7, "The extension token", now covers this.

**What is protected.** `ToolInvocation`, `WorldState`, `world_tool`, `live_tool_outcome`,
`scripted_tool_outcome`, `world_ext_effect`, `recording_tool`, `empty_world_state`, `ported_provider`
and `Ports` are in `tools/eval_protected/starting_set.json`. `tool_runtime.ail`, `tool_catalog.ail`,
`ext_world.ail`, `dst_*.ail`, `src/core/test/**` and `src/eval/journal/**` are refused paths. So W5, W6
and W10 move `eval_matrix` rows, as 034 W1 did. Predict them with the pattern of
`034_ambiguous_tool_outcomes/evidence/W1.1/predict_matrix.sh`. R11 and the 034 arrangement it follows set what
happens to those rows (*Rulings*). `test_candidate.py`'s `test_m15_protected_region_comment_only_now_refused`
asserts 119 protected spans, and a new type named by a pinned type is pinned at the next `gen` if it is declared
in `ports.ail`, `session.ail` or `stub_step.ail`. C1's leaf module keeps the new types outside those files.

**What pins `tool_phase.ail`.** `tools/predicate-anchors/anchors.sh:112-113` and `:793` hold lines
`:403`, `:404` and `:499`. Moving them costs about eleven files and a version bump in each of the four
profiles (the list is at `anchors.sh:289-301`). See C3.

**Offers are not projected.** `tool_offer_projection` writes `""` for `AgentTools` (`ports.ail:971`), so
a new schema does not change a replay's request projection. This is what lets D1 ship without breaking
R6, and W1 and W12 check it.

**Only one v5 artifact is tracked:** `scripts/dst/fixtures/execution-program-v5.artifact`. Generated
programs are built at run time. The refresh D7 and §8 describe therefore costs less in tracked files
than "every generated artifact" would suggest, and W5 re-measures it. D7 and §8 now say the same (G6).

**Overlap.** Open #234 and #209 change `tool_runtime.ail` and the `Makefile`. Open #266 and #287 change
`src/tui/src/runtime-process.ts`, and #287 changes `session.ail`. W2, W10, W11 and W12 check these with
`status.sh` first.

### Experiments

Run in `/tmp/041-plan-Tn8U4o` with AILANG v0.54.14, on code unchanged in `e3293ede`. No tracked file changed. These are early signals,
not acceptance evidence.

**E1, the R6 inference, on today's code.** I took `fxw_m3_selector_end`, gave three calls a
`timeout_secs` (`0`, `600`, `"soon"`), and replaced their recorded results with post-change shapes:
limit fields on the clamped call, `fault` and `max_timeout_ms` on the two invalid ones. I recomputed
the digest chain, then ran `admit` and a second run from `world_state_of(program)`:

```
r6_probe: ran=true calls=3 expected=EndSuspended(3) observed=EndSuspended(3) interactions=22 preflight=[] findings=[]
R6PROBE report_ok=true
R6PROBE strict_mismatches=0 interactions=22
R6PROBE payloads_with_limit_fields=3 tool_projections_timeout0=4
R6PROBE control_strict_mismatches=6
```

The control, with the tool contents altered, produced 6 mismatches, so the comparison does see tool
content. This supports D7's reading, because `journal_tool` (`world.ail:88`) serves recorded content as
a completion and ignores the arguments. It does not prove R6: the fixture is hand-shaped and the code
has no `Legacy` field yet. W1 and W5 are the test.

**E2, `setsid`.** Under `--process-timeout 1s`, a descendant holding the pipes returned
`Timeout(3007)` at 3,008 ms. One with its pipes redirected returned `Timeout(1005)` at 1,007 ms. Both
wrote their markers. This matches D5, and W2 pins both cases.

**E3, JSON numbers.** `std/json` holds every number as a float.

| Input | Result |
|---|---|
| `60`, `60.0`, `1e3` | number, whole. `60.0` cannot be told from `60`, so it is valid |
| `1.5`, `0.0000001` | number, not whole |
| `null` | `JNull` |
| `"60"` | not a number |
| `10000000000000000` | number, round-trips |
| `1e400` | **the whole arguments object fails to decode**, so it reaches `undecodable_arguments_message` and never the resolver |

`encode` writes `31536000000` in full, not in exponent form. W4 and W7 carry these as test rows, with the
boolean, array and object forms D2's table now names.

## Choices this plan makes

**C1. One leaf module.** Types, resolver and display functions go in a new
`src/core/process_limits.ail` that imports nothing from `src/core`. `dst_program.ail` stays free of port
imports by design, and needs `LimitMode` for `InitialWorld`, and `ports`, `tool_runtime` and
`tool_dispatch_adapter` all need the types. `fs_node.ail` is the precedent.

**C2. One activation point.** `LiveAI` at `session.ail:1527` is the only switch. It reads
`empty_world_state()`, whose `process_limits` is `Legacy`, until W12. A guard test, added in W5 and
removed by W12, asserts that the live world is `Legacy` and that the schema has no `timeout_secs`. That
is the mechanical form of "D1, D2 and D4's limit metadata must not activate before a pin".

**C3. Keep `tool_phase.ail` and `session.ail` line-neutral above their anchors.** New logic goes below
`:499`, and signature changes stay on their lines. This repo already does it
(`tool_phase.ail:45` and `:462`, "joined onto this line"). If an item cannot, it prices the cascade in its pull
request and pays it once. W5-W12 expect no profile version bump. W7's new `ToolArgumentsInvalid` event may force one.

**C4. One rendering path, with no change to `ToolResultItem`.** The live and loopback paths render with
`tool_result_item_to_json(item)` plus D7's field function, `process_limit_fields(result, attempted)`, which
produces the fields that go after `tool` and `fault` and before `cmd`. Here `attempted` is true for `BashExecResult` or
`RunTestsResult`, and false for `ToolErrorResult`. This avoids a required field at the sixteen `ToolErrorResult` literals.
The scripted arm uses the same field function.

**C5. Header encoding of `process_limits`.** One tagged line: `legacy`, or
`limits<TAB><default><TAB><ceiling>`, where default is `none` or integer nanoseconds and ceiling is `same`
or integer nanoseconds, as D7 states. Add `version_has_process_limits`, written as the versions that lack it, as
`version_has_applied_faults` is (`dst_persistence.ail:464`).

---

## Sequence

`PLAN-001.dagr.json` holds the order. W1-W3 are independent of each other. W8 and W9 are independent and may land in either order. The same
pin may carry both.

## Upstream, and what happens at each wait

State on 2026-10-31. Upstream `main` is `ffabe327`, its latest release is v0.55.0, and its
`std/process.ail` exports `exec` with no per-call timeout. A search of upstream pull requests for
"process timeout" returned none.

| Issue | State | Needed by | While it waits | If it stalls or is declined |
|---|---|---|---|---|
| [#2034](https://github.com/sunholo-data/ailang/issues/2034), a killed runtime leaves the command running | Open, no labels, no comments | W9, and so W12 | W3 stays an expected failure. The defect stays on `main`, independently of this plan. **No longer limit activates.** | R10: if #2034 has no maintainer direction or date by **2026-11-14**, or upstream declines sooner, the TUI fix goes to the operator for a ruling. It is not built automatically. No TUI fix is designed here, and it is hard: the command leads its own process group, so the TUI holds only the runtime's pid |
| [#2035](https://github.com/sunholo-data/ailang/issues/2035), per-call timeout | Open, no labels, no comments | W8, W10, W12 | W1-W7 land. Operators use `tools.process_timeout`. No schema advertises the argument | R4: keep the session setting as the only relief and revisit. No fork, no second executor, no wrapper (034 ruling 6). A new ruling is required to do otherwise |
| [#2036](https://github.com/sunholo-data/ailang/issues/2036), read the configured limit | Open, no labels, no comments | W8, W11, W12 | As #2035. A pin with only one of the two does not unblock W10-W12 (D3) | As #2035 |
| [#1878](https://github.com/sunholo-data/ailang/issues/1878), output kept on timeout | Open, `priority:P1`, `area:runtime`, no comments | W14 only | W12 ships with absence stated explicitly | W14 stays unscheduled. The explicit absence stands, and W12 does not depend on it |

[#2037](https://github.com/sunholo-data/ailang/issues/2037) is not a dependency (D5). W2's probe is what
notices if it lands.

If R4 applies after W4-W7 have landed, they stay merged and dark. ADR §8 already accepts a schema field
that stays `legacy` until something uses it.

---

## Work items

### W1. The R6 admission test (now, first)

**Why first:** R6 holds "only if §6's admission test passes". If it fails, R6 reopens before anything
depends on it.

**Changes.**

- `src/eval/journal/testdata/gen_fixtures.py` and `world_fixtures.ail`: a fixture
  `fxw_r6_post_change_limits`, through the generator so that its chain digests are real. It holds a
  clamped call (`timeout_secs` above the ceiling, result with `timeout_ms`, `requested_timeout_ms` and
  `max_timeout_ms`), an invalid call (`timeout_secs: 0`, result with `fault` and `max_timeout_ms`), and a
  non-numeric one (`"soon"`). `admission_fixtures.ail` gets its row.
- `src/eval/journal/admission_live_test.ail`: a new check that admits it, then replays from
  `world_state_of(program)` and asserts `report_ok`, zero `strict_replay_findings`, recorded tool content
  served unchanged, and a control in which altered content is seen.

This item does not edit `MATRIX.expected.tsv`, as the 034 arrangement left that file alone (*Rulings*). If the
matrix reports the new check as unlisted, record the row in the pull request.

W5 tightens this test to assert `process_limits == Legacy`. W13 repeats it with a journal from a real
post-change live session.

**Acceptance.** A14d, first half: "a post-change journal containing a clamped and an invalid request
admits as `Legacy` and replays strictly".

**If it fails:** stop, record the evidence, and return R6 to the operator. W5-W13 do not start.

**Mutants.** `t1`: make `journal_tool` drop limit fields from content → the content check fails. `t2`:
make `journal_tool` read `timeout_secs` and refuse a value of `0` → the admission check fails.

**Gates.** G-base, the check itself (the header of `admission_live_test.ail` has the command), and `make
eval_matrix` compared with the base.

### W2. D5's probe and the operator note (now)

**Changes.**

- `scripts/verify_native_process_tree.ail`: `setsid` cases beside the existing one, run from `main` under
  its `--process-timeout 1s`.
  - Pipes held: `Err(Timeout)`, returned no earlier than the descendant's exit and no later than limit
    plus `WaitDelay`, marker written.
  - Pipes closed: `Err(Timeout)` near the limit, marker written after it.
- The probe's `sleep(2500)` window grows to cover the markers, and the existing `elapsed < 4000` row keeps
  its meaning.
- A SIGKILL row in the same probe (D5, R10), pinning today's behaviour: the command survives a SIGKILL of its runtime and
  writes its marker. The `.ail` program cannot kill its own runtime and report, so the row lives in the
  `verify_native_process_tree` recipe, which starts a small entry and sends the signal.
- `setsid` is not on a stock macOS host, and `check_core` runs this target. Where `command -v setsid`
  fails, print `NOT EVALUATED` and do not fail. Acceptance reads a Linux log with no such line.
- `docs/configuration.md`, beside `tools.process_timeout` (`:60-62`): state the detached-descendant limit and the SIGKILL
  limit, for operators only. It does not go in the model-facing result.

**Acceptance.** D5's probe, with its `setsid` and SIGKILL rows; A20 for the `setsid` rows (deadline and return latency asserted separately).

**Mutants.** `d1`: assert the marker is absent → red today, which shows the row reads the world. Hold the
new rows against a stubbed exit. If upstream #2037 lands, or #2034 also covers SIGKILL, the matching row goes red by design, and that item updates it.

**Gates.** G-base. `make check_core` runs the target.

### W3. The cancellation witness (now, expected to fail)

**Changes.**

- `src/tui/src/runtime-process.cancel.test.ts`: the ADR's experiment as a test. Real `RuntimeProcess`, real
  `interruptRuntime`, native `BashExec` of a command and an ordinary descendant that each write a marker
  later, signal once the command has started, assert no marker after the limit has passed.
- Marked as an expected failure with a comment naming #2034, so that the suite stays green and turns red
  when the behaviour changes. Confirm the marker Jest offers under this repo's runner
  (`src/tui/package.json:9`).
- A runtime-level twin in `scripts/verify_runtime_cancel_process_tree.sh`, the #2034 reproduction for
  SIGTERM and SIGINT, not wired into `check_core` until W9. `RuntimeProcess` sends SIGTERM alone, so SIGINT
  has its evidence only here.

**Acceptance.** None yet. A22 says that "a recorded failure alone does not satisfy this". W9 satisfies it.

**Mutant.** `c1`: have the test's command skip writing the marker → the expected failure stops failing,
which shows the test can see the world.

**Gates.** G-base, run as a non-root user with no other session's markers in its scratch directory.

### W4. The resolver module

**Files.** New `src/core/process_limits.ail`, with `make check_core`'s loop picking it up.

**Functions.**

- Types per D7, including `session_default`: `SessionLimit`, `Ceiling`, `ProcessLimits`, `LimitMode`,
  `ProcessBudget`, `ResolvedProcess`.
- `InvalidRequest = { requested_ms, session_default, effective_ceiling }`, per D7.
- A private `parse_timeout_request(args)`: D2's table, reading the raw `timeout_secs`. Only the resolver calls it. Every row of E3 is a test, as are a boolean, an array and an object.
  `requested_ms` is `Some` only for a positive whole-millisecond request within D2's bound (D4). The whole-millisecond
  test runs on a float, so it gets boundary rows such as `1.5` (reports 1500) and `0.0000001` (reports none).
- `resolve_process_limit(limits, request) -> ResolvedProcess | InvalidRequest`: D7's six rows, `NoDeadline` matched and
  never compared. It is the **only constructor of both results**, so a copied `session_default` cannot disagree with
  `process_limits`.
- `loopback_limits(limits)`: `ceiling` forced to `SameAsDefault` (R7). Loopback then calls the resolver with its request.
- `extension_process(limits)`: calls the resolver with `SameAsDefault` and no request (R8). It builds nothing itself.
- `display_timeout_ms`, `display_max_timeout_ms`: whole milliseconds, rounded up, `0` for any non-positive
  default, `None` for `NoDeadline`.
- `process_limit_fields(result, attempted)`: the rendered keys in order (C4). With `attempted` false, or for an
  `InvalidRequest`, there is no `timeout_ms`: `max_timeout_ms` alone, plus `requested_timeout_ms` when `requested_ms` is `Some`.
- `process_deadline_expires(carrier, t, legacy_timeout_ms)`: D7's expiry table.
- `projected_timeout_ms(carrier, legacy_timeout_ms)`: `ExplicitMs(m)` → `m`, everything else → today's.
- `parse_ceiling_ms(string)`: the strict `tools.process_timeout_max` domain. Go duration grammar, as
  `process_wall_ms` reads it (`packages/motoko-ext-herdr/types.ail:635`), but it must be positive and a
  whole number of milliseconds. `core` cannot import that package, so this is new. Used from W11.

**Acceptance.** All pure, each with table rows:

- A5's parsing half, including `10^16`.
- A8's fields, with `null` for `timeout_ms` under `SessionDefault` and `max_timeout_ms` under `SameAsDefault`.
- A9: every `SameAsDefault` row with a 30 s default, 60 s not extending, equality, fractional and
  non-positive defaults, omission, and the `timeout_ms` projection for each outcome.
- A10's predicate half: `Finite(0)` at `t = 0`, and `timeout_ms: 0` with no carrier.
- `t * 1_000_000` compared safely when `t` is large. A program's `t` has no D2 bound, so compare against
  `n / 1_000_000` rounded, with a boundary row.

**Contracts.** `clamp_ms` gets a substantive one for I1: the result is at most the ceiling, and it equals
the request when the request fits.

**Mutants.** One per row of each table. Named ones: `r1`, drop the clamp; `r2`, compare `NoDeadline`
numerically; `r3`, round down; `r4`, `Finite(0)` as no deadline; `r5`, accept `0`; `r6`, accept `1.5`
truncated; `r7`, `SameAsDefault` extends; `r8`, write `timeout_ms` with `attempted` false; `r9`, build a result outside the
resolver with a stale `session_default` → the agreement row and a check for a single construction site fail.

**Gates.** G-core, `make verify_mutations` if the module adds a guard contract.

### W5. `execution-program/6`, every writer `legacy`

**Files and functions.**

- `dst_program.ail`: `InitialWorld.process_limits` (`:214`), `program_schema_version` (`:163`), `/5` in
  `decodable_schema_versions` by name (`:183`), the pins at `:805-807`, version history, and a rejection for
  an invalid `CeilingMs`: not positive, not whole, too large to convert, or below a finite default.
- `dst_persistence.ail`: tag, `version_has_process_limits`, encode, decode, absent → `Legacy` before v6, and
  the contract and test beside `:1651`.
- World constructors, per D7's step 3 list:
  - `empty_world_state` (`ports.ail:890`) is `Legacy`.
  - `dst_replay.world_state_of` (record update at `:918`) copies the mode. **The compiler will not flag this:** a forgotten
    field silently replays a `Limits` program as `Legacy`, so the `Limits` specimen must assert it.
  - `journal_world_state` (`world.ail:105`) keeps the `Legacy` default, which is correct, with a test saying so.
- `dst_replay.ail`: the program literals at `:1300` and `:1469`.
- `ports.ail`: `WorldState.process_limits` (`:183`).
- `ext_world.ail`: per D7, "The extension token": `world_json` (`:600`), `world_of_json` (`:642`), absent decodes as
  `Legacy`, and `adopt_world` (`:705`) re-seats from `pre`. Round-trip rows go in its test (`:917` onward).
- Writers stamp `Legacy`: `admission.ail:727`, `:1188`, and every `InitialWorld` literal. Twenty lines in
  eighteen files match `extension_profile:` today, including `corpus_pr_dst`, `seeded_generator_dst`,
  `corpus_rotating_dst`, `discovery_dst`, `strict_replay_dst`, `park_wake_dst`, `latency_pair_dst`,
  `driver_plus_compose_dst`, `herdr_graded_dst`, `execution_program_dst`, `program_persistence_dst`,
  `candidate_checks.ail`, `scan_fixtures.ail` and `seams_live_test.ail`.
- Version pins, as D7's step 3 list: `dst_program.ail`, `dst_persistence.ail`, `scan.ail:1029`, `admission.ail:1249`, `admission_live_test.ail:127`, `program_persistence_dst.ail`.
- `program_persistence_dst.ail`: the "current encoder produces these bytes" check moves from v5 (`:1686-1696`)
  to v6, and v5 stays decode-only. Two frozen specimens, `execution-program-v6.artifact` (`legacy`, every
  identity class) and `execution-program-v6-limits.artifact` (`Limits`). Frozen v1-v5 stay untouched.
- The C2 guard test, in `world_state_probe.ail`.
- W1's test tightens to assert `Legacy`.

**Not touched:** the generator's draws, salts, the 20-90 ms draw and the 2,000 ms bound (D7).

**Acceptance.**

- A13: old recordings replay unchanged, including ones with `timeout_secs`. The transcode test decodes,
  encodes and decodes a legacy program containing `timeout_secs: 0`, and it stays `Legacy`.
- A15's decoder half.
- A18: for existing seeds, draws, salts and interactions are equal, and the pre-v6 artifact differs only in
  the version line, digest and `process_limits` line. Prove it by diffing a v5 and a v6 encoding of the
  same generated program. Journals recorded before the change fold and plan resume (`make journal_resume`).
- A14d: W1's test with the `Legacy` assertion.
- A25, the direct guard: the `ext_world` round trip (`:915`) with a `Limits` value distinct from the default, because
  `adopt_world` alone would hide a dropped encoder key. A hook cannot change the driver's value, and a token without the
  field decodes as `Legacy`. W6 and W10 add the behaviour checks through a real token.

**Mutants.** `p1`: infer the mode from the version → the transcode test fails. `p2`: decode absent as
`Limits` → a frozen v5 decode fails. `p3`: accept a missing line at v6 → the rejection row fails. `p4`: drop
the mode in `world_state_of` → the `Limits` specimen fails. `p5`: drop it in `world_of_json`, and separately in `world_json` → the
`ext_world` round trip fails on each. `p6`: drop the re-seat → the adoption row fails. `p7`: accept a ceiling below
the default → the decoder row fails. `p8`: decode an absent key as `Limits` → the token row fails.

**Gates.** G-heavy, with the predicted matrix rows written in the pull request before the run. Per R11 it leaves
`manifest-A` alone and records the rows it leaves red.

### W6. Scripted carrier, expiry and projection

**Files and functions.**

- `ports.ail`: `ToolInvocation.process` (`:675`). `scripted_tool_outcome` (`:1881`): the deadline check
  becomes `process_deadline_expires`, order unchanged. `ToolDeadlineExceeded.timeout_ms` carries the
  display value.
- `tool_phase.ail`, below `:499`: `Limits` mode with a process tool → resolve, build the carrier, set
  `timeout_ms` by `projected_timeout_ms`. `None` for other tools and all of `Legacy`. The env read stays
  once per dispatch in both modes.
- `session.ail:1369-1374` (literal at `:1372`): the extension invocation takes `extension_process(w0.process_limits)`, which goes through the resolver, for a
  process tool in `Limits` mode, on existing lines. It does not read `timeout_secs`. `timeout_ms: 0` stays.
- Literal fan-out, D7's step 3 list: `tool_phase.ail:504`, `ports.ail:2953`, `:3016`, `seams.ail:343`,
  `seams_live_test.ail:99`, `world_state_probe.ail:1222`, `strict_replay_dst.ail:1417`.
- **The live arm before the primitive exists (§6 step 3).** `world_tool`'s and `world_ext_effect`'s empty-queue arms (`ports.ail:1841`, `:1910`)
  can be reached by a `Limits` program. Until W10, `live_tool_outcome` given `Some(ExplicitMs)` returns
  `ToolFailed` before dispatch with a stated code, and runs nothing. It must not run a plain `exec` under a
  limit the result would then misreport.

**Acceptance.**

- A8: `NoDeadline`, with and without a ceiling.
- A9's scripted expiry and projection.
- A10: `Finite(0)` expires at `t = 0`, `timeout_ms: 0` with no carrier never does, and `ReadFile`, `Search`,
  `WriteFile` and `EditFile` keep today's scripted deadlines.
- A14a: a `Limits` program with a clamped request round-trips.
- A14c: a scripted extension `BashExec` expires against the program default, recording and replay included.
- A25: that extension check runs through a real token and asserts `Limits` behaviour. An extension that passes a token
  without the field runs its own effect as `Legacy`, which D7 accepts.
- A16, scripted half, for main dispatch and extension effects, with the same argument.

**Mutants.** `s1`: read `inv.timeout_ms` for a carried process tool → the 1000/3000/2000 row fails. `s2`:
give `ReadFile` a carrier → its deadline row fails. `s3`: extension reads `timeout_secs` → the R8 row fails.
`s4`: skip the env read in `Limits` → discovery's count fails. `s5`: project `30000` for `SessionDefault` →
the strict-replay row fails.

**Gates.** G-heavy. `make anchors` must not move (C3). Per R11 it records the rows it leaves red.

### W7. Argument errors and scripted metadata, dark

**Files and functions.**

- `tool_phase.ail`, below `:499`: an invalid request in `Limits` mode. Resolve **before**
  `V2ToolDispatchStart`, since the resolver is pure. If invalid, keep the clock and env reads, emit
  `ToolArgumentsInvalid` (D7), emit no Start or Complete, skip the port, and build the message with `fault`
  (`FaultRefused`, `effects: none`) and D4's no-attempt fields. Valid and `Legacy` order is unchanged.
- `tool_outcome_message` (`:289`) takes the carrier, on its existing lines (C3). A scripted `ToolFailed` or
  `ToolDeadlineExceeded` renders D4's fields. `ToolCompleted` stays byte for byte (D4). `Legacy` has no
  fields. Callers, D7's step 3 list: `:515`, the tests at `:753-786`, `fault_catalogue_dst.ail:72`,
  `invariants_dst.ail:1037-1046`.
- `session.ail:1150` `tool_outcome_text`, with its caller at `:1382`, per D4: it takes the carrier and uses the same field
  function for an extension effect's **faults**: `ToolFailed`, `ToolCorrelationMismatch` and `ToolDeadlineExceeded`. The
  deadline's existing top-level `timeout_ms` is replaced, not written twice.
- Every call passes `attempted`. An `InvalidRequest` has no attempt. For a scripted fault see H1.
- `dst_invariants.ail`: `refused_call_ids` (`:1649`) gains the event, and the builder list at `:1675-1686`
  gains the builder, as 034 W2.1 requires of a new fault builder.
- `dst_event_vocabulary.ail`, `phase_vocab.ail`, `event_vocabulary_dst.ail`: the new event.
- `tool_catalog.ail` is **not** touched. The old test stays.

**Acceptance.**

- A5, scripted half: every invalid form, including a `null` that behaves as no argument. Each reports no
  applied limit.
- A14b: an invalid request in a `Limits` program records no tool interaction and leaves the queue balanced,
  and `corpus_judge`'s `tool-dispatches-unbalanced` stays clean.
- A11, refused half (a refusal, no applied limit).
- A21, scripted half.
- A17, for the messages this item builds: a `ToolFailed` whose message passes 65,536 characters, cut by
  `cap_tool_message_content` (`phase_vocab.ail:1546`) through `tool_result_message`, keeps its fields. A 70,000-character
  string `timeout_secs` is echoed bounded, and its fields survive.
- A7, scripted half: authored completions are served byte for byte, under the cap.
- A16, an extension effect's scripted faults report `max_timeout_ms` through `tool_outcome_text`, and its deadline
  reports `timeout_ms` once.

**Mutants.** `e1`: emit Start on an invalid request → the judge row fails. `e2`: call the port → the
queue-balance row fails. `e3`: add metadata to `ToolCompleted` → the byte row fails. `e4`: render fields in
`Legacy` → a v5 replay fails. `e5`: omit the event → P1's presence check fails. `e6`: `effects: unknown` on an
invalid request → the disclosure row fails. `e7`: `tool_outcome_text` writes `timeout_ms` twice → its row fails. `e8`: leave its `ToolFailed` without fields → its row fails.

**Gates.** G-heavy.

### W8. The pin (waits on #2035 and #2036)

**Starts when** a released AILANG tag carries both. Not before, whatever else is available (D3).

**Changes.** `ailang.toml:6`, `ailang.lock`, `scripts/install-prerequisites.sh:40-41`, the version case in
`Makefile:2671` and CI's pinned install. A thin adapter in `src/core/process_limits_native.ail`, with
`exec_with_limit(cmd, args, ms)` and `native_session_limit() -> SessionLimit`, so that the upstream shapes
stay in one file. No behaviour changes: no caller yet.

**Re-ground at start.** Read the real API, and confirm it shares the group kill and `WaitDelay`, can exceed
`--process-timeout` while plain `exec` stays at the default, keeps sub-millisecond precision, and represents
`0` and `-1s`. If any fails, stop and comment upstream through the `ailang-feedback` skill.

**Acceptance.** Direct probes under `--process-timeout 1s`: `exec_with_limit` at 3 s outlives 1 s, a following
plain `exec` still stops at 1 s, and the query returns `1500us`, `0` and `-1s` faithfully. Precondition for A2,
A6 and A12.

**Mutant.** `n1`: the adapter returns milliseconds as nanoseconds → the `1500us` row fails.

**Gates.** G-heavy, because a pin move can move anything. FAILED names equal to the base's, or explained.

### W9. The D6 fix (waits on #2034)

**Starts when** a released tag carries #2034. It can share W8's pin. Under R10, if #2034 has no maintainer direction or
date by 2026-11-14, or upstream declines sooner, the TUI fix goes to the operator for a ruling. It is not built
automatically, and this item is re-planned around whatever is ruled. W12 keeps waiting either way.

**Changes.** The pin, if W8 has not moved it past the fix. Remove W3's expected-failure mark. Wire the runtime
twin into `check_core`, on the version gate pattern of `verify_native_process_tree`. W2 already pins and documents SIGKILL.

**Acceptance.** A22, by the passing test: cancelling a run with SIGTERM or SIGINT stops the command and its ordinary
descendants with no late effect. R10 says this satisfies D6, and SIGKILL stays disclosed.

**Mutant.** `c2`: run the test against the previous pin → it fails. That shows the pin is what fixed it.

**Gates.** G-base, then `make dst` if the pin moved.

### W10. Live executor and loopback, dark

**Files and functions.**

- `tool_runtime.ail`: `run_native_batch` and `run_native_call` take a per-call `Option[ResolvedProcess]`.
  `run_process_result` calls plain `exec` for `None` and `SessionDefault`, and `exec_with_limit` only for
  `ExplicitMs`. `ProcessExecReq` and `parse_exec_from_args` do not gain the field. Helpers at `:494`, `:632` and
  `:853-889` stay plain `exec` (I5).
- `tool_dispatch_adapter.ail`: `dispatch_one_typed` (`:276`) takes the value and renders through C4. `dispatch_one`
  (`:312`) keeps its signature, as D7's step 4 list says, and passes `None`.
- `ports.ail`: `live_tool_outcome` (`:1866`) passes `inv.process`, and W6's fail-closed arm goes.
- `tool_envelope_dispatch.ail:47`: in `Limits` mode, after `Delegate`, and for process tools only, read the mode
  from `token_to_world(ctx.world)`, resolve with `loopback_limits`, and pass the value. `error_result` (`:13`) has no `fault` or limit fields, so an
  `InvalidRequest` gets a result that carries them. Loopback has no `emit`, so it writes no `ToolArgumentsInvalid`, and D7
  records that as a known limit of what the invariants can see.
- Fan-out, D7's step 4 list: `tool_envelope_dispatch.ail:47`, `verify_native_process_tree.ail:38`, `ports.ail:1866`,
  `tool_dispatch_adapter.ail:312`, `world_state_probe.ail:1254` and `:1402`.
- `scripts/dst/fixtures/process-limit-completion.json`: the live helper's completion bytes, below the cap, for A7.

**Acceptance** (direct calls, since the live world is still `Legacy`).

- A3, executor half: `ExplicitMs` outlives the default. A clamped success and a clamped non-zero exit both
  report the clamp.
- A4: a shorter request stops early.
- A6: after an extended call, a default call and a helper in the same runtime stop at the default.
- A11: a non-timeout process error reports the attempt's limit, and a refusal does not.
- A12: `1500us`, `0` and `-1s` through `SessionDefault` behave as before.
- A16, loopback: with default 30 s and ceiling 300 s, a 60 s request runs at 30 s, says so, and reports
  `max_timeout_ms` as the default.
- A25: the loopback check runs through a real token from a `Limits` world and asserts that behaviour.
- A17: through `tool_result_message`, so through `cap_tool_message_content`'s 65,536-character cut
  (`phase_vocab.ail:1546`), every limit field survives on a `BashExec` and a `RunTests` whose output passes the cut, and on
  a `BashExec` whose `cmd` does. `RunTests` renders no `cmd`, so it has no second case. The output stays under
  `--process-max-output`, or the result is a fault with no output.
- A7, first half: the live helper's completion bytes equal the fixture.
- A20: timing rows separate the enforced deadline from return latency.
- A21: a live `BashExec` and `RunTests` timeout is `unknown`, and a `Search` timeout stays `none`.

**Mutants.** `l1`: pass a budget to a helper → the leak row fails. `l2`: use `exec_with_limit` for
`SessionDefault` → the `1500us` row fails. `l3`: loopback keeps the run's ceiling → the 30 s row fails. `l4`:
render fields after `cmd` → the oversized-`cmd` row fails. `l6`: render them after `stdout` → the oversized-output
row fails. `l5`: render an applied limit on a refusal → the A11 row
fails.

**Gates.** G-heavy. Per R11 it records the rows it leaves red.

### W11. Startup limits and TUI settings, dark

**Files and functions.**

- `process_limits_native.ail`: `startup_limit_mode(env)`, for D7's route: `ported_provider`'s `LiveAI` arm
  (`session.ail:1527`) sets `Limits` from it. The default always comes from the #2036 query, for TUI
  and direct launches alike, so there is one source and no duplicate duration parsing. The ceiling comes from
  `MOTOKO_PROCESS_TIMEOUT_MAX`, through `parse_ceiling_ms`. Unset gives `SameAsDefault`. A ceiling below a finite
  default is an error value. Nothing calls it from `LiveAI` yet.
- `src/tui/src/index.ts`: `processTimeoutMax` in the profile parse (`:375`, `:409`) and
  `applyToolProfileConfig` (`:344-356`).
- `src/tui/src/runtime-process.ts:527`: forward `MOTOKO_PROCESS_TIMEOUT_MAX` in `buildChildEnv`.
- `src/tui/src/index.ts:1253`: on a profile switch, re-resolve both settings from the new profile. A value the
  new profile does not set is cleared, unless it is in `shellEnvKeys`. I4 now lists this change.
- `herdr-child-env.test.ts`: the new key.
- `packages/motoko-ext-herdr/register.ail:166` stays sized from the default. A test pins this.

The runtime reads the ceiling from the environment only, as `--process-timeout` comes only from the TUI today. A
direct CLI launch sets `MOTOKO_PROCESS_TIMEOUT_MAX` itself.

**Confirm the startup route.** D7 says it is read from the code and not built, and that this item confirms it. On a
throwaway wiring of `LiveAI`, not merged, record in the pull request:

- The #2036 query's effects fit `ported_provider`'s row. `Env` and `Process` are there today (`session.ail:1524`).
- `LiveAI` is what the live launcher reaches through `rpc.run_with_config`, and the other arms stay `Legacy`.
- `ported_provider` has eight call sites. Each one that reaches `LiveAI` gets the same value, and a resume resolves again.
- `ported_provider` has no failure channel, and D2 raises a low ceiling at startup. So W12's check in `rpc.run_with_config`
  must call the same `startup_limit_mode`, ahead of it.

If any of these fails, stop and return the route to the operator with the evidence. W12 does not start.

**Acceptance.**

- A15's parse half.
- A16: a plain restart keeps the values, and a profile restart re-resolves them.
- A23: `MOTOKO_PROCESS_TIMEOUT=600s` with no new setting resolves and starts.
- A24: `grep` confirms that `tools.delegated_timeout_ms` gains no reader, and it stays as issue
  `bashexec-timeout-knobs-are-dead.md` left it.

**Mutants.** `u1`: do not forward the key → the child-env test fails. `u2`: keep the old profile's value → the
restart test fails. `u3`: profile beats shell → the protected-key row fails.

**Gates.** G-core, plus `cd src/tui && bun run test`.

### W12. Activation

**Starts only when** W9 is merged, and W8, W10 and W11 are. This is the item R5 and D3 hold back.

**Files and functions.**

- `session.ail:1527`: `LiveAI` world's `process_limits` from `startup_limit_mode`, on the existing line (C3), by the route W11
  confirmed. No change to `ExtRuntime`.
- `rpc.ail:274` `run_with_config`: refuse to start on the ceiling error, naming both values.
- `tool_catalog.ail`: `tools_for_mode(rt, mode)` (D1), with `tools_with_extensions` staying as the `Legacy` catalog. `test_bash_schema_does_not_advertise_ignored_timeout_secs` (`:199`) is
  replaced by a test that the argument appears exactly when the mode is `Limits`, with its ceiling.
- `src/core/test/stub_step.ail:190` and `offered_tools` (`:284-286`) pass `state`'s mode, without moving the anchor at `:203`.
- D4's explicit absence on a process timeout, until W14.
- Re-baseline: live-binding fixtures and recorded streams, with the diff limited to these fields, and
  historical messages untouched.
- `docs/configuration.md`: `tools.process_timeout_max`, `MOTOKO_PROCESS_TIMEOUT_MAX`, the shipped default of
  unset (R2).
- Removes the C2 guard test.

**Acceptance.**

- A1: no setting, a request above the default stops at the default and says so.
- A2: with a ceiling, a long request outlives the default, and a no-request call in the same session stops at it.
- A3: a request above the ceiling stops at it.
- A5, live half, with marker-file evidence that nothing launched.
- A15: the schema's ceiling is the configured one, and a low ceiling fails at startup.
- A16: a direct CLI launch reports the value on its command line. A journal resume re-resolves.
- A18's last clause, on the built change: pre-change journals fold and plan resume.

**Mutants.** `a1`: schema always advertises → the `Legacy` row fails. `a2`: hardcode 30 s in the schema → the
ceiling row fails. `a3`: skip the ceiling check → the startup row fails.

**Gates.** G-heavy, then `make compose_live_exec` and `make verify_native_path_guard`, which match on result
shapes. Herdr's and compose's readers go by key, and this confirms it. This is the last item that moves protected
symbols, so R11's regeneration follows it.

### W13. Parity and the entry-point matrix

**Changes.** Test-only.

- `make verify_process_limits_live`: real processes under finite limits.
- A paired `Limits` scripted program: same limits, same calls, and the completion twin.
- The entry-point matrix: one argument through main dispatch, loopback and an extension effect, in both
  worlds where the row exists.
- W1's check repeated on a journal from a real post-change session, with no provider cost: `--ai-stub`.

**Acceptance.**

- A7: extension, omission, shortening and clamping agree on enforcement and on the fields of a deadline and an
  invalid request. A scripted twin whose authored content is W10's fixture serves those bytes unchanged under the
  message cap.
- A14d, final form. A failure here reopens R6, as a failure in W1 would.
- A16, in full: every row of D7's table. *Coverage* lists them.
- A17, A20 and A21 across both worlds.

**Mutant.** `m1`: live reports `elapsed_ms` as `timeout_ms` → the parity row fails.

**Gates.** G-heavy. The result is the ADR's §6 sign-off, and the item records it against each criterion.

### W14. Partial output (waits on #1878)

**Starts when** a released tag carries #1878. **Re-ground at start:** the issue offers several shapes, including
`Timeout(ms, partial)`. A changed `ProcessError` is a compile error in `tool_fault.ail:184` and `tool_runtime.ail`
(`process_error_to_string`, `run_process_result`), and in the copies the 034 follow-ups list in herdr, compose,
extensions and eval code.

**Changes.** The pin, the arm in `run_process_result`, partial `stdout` and `stderr` in the result, and removal of
W12's absence marker. A partial stream is unbounded, so fields keep D4's order.

**Acceptance.** A19: partial output preserved on a timeout. The explicit absence was already W12's half.

**Mutant.** `o1`: drop partial on `RunTests` only → its row fails.

**Gates.** G-heavy.

---

## Coverage

### ADR §6 criteria

| # | Criterion (line in `e3293ede`) | Items |
|---|---|---|
| A1 | No new setting: a request above the default stops there, and says so (510) | W12, W13 |
| A2 | Ceiling set: long call outlives default, no-request call stops at it (512) | W8, W12, W13 |
| A3 | Above the ceiling stops there; clamp reported on success and non-zero (514) | W4, W10, W12 |
| A4 | Shorter request (516) | W4, W10, W13 |
| A5 | `null`, and invalid forms including 10^16, never launch, no applied limit (517) | W4, W7, W12 |
| A6 | Helpers and default calls after an extended call (519) | W8, W10 |
| A7 | DST and live agree on enforcement and on deadline and invalid-request fields; live helper's completion bytes equal a fixture, and a scripted twin serves that fixture unchanged under the cap (522) | W7, W10, W13 |
| A8 | `NoDeadline`, with and without ceiling, `null` fields (526) | W4, W6 |
| A9 | Every `SameAsDefault` row, and the projection (528) | W4, W6 |
| A10 | `Finite(0)`, `timeout_ms: 0`, other tools unchanged (531) | W4, W6 |
| A11 | Other process error reports the limit; refusal does not (533) | W7, W10 |
| A12 | `1500us`, `0`, `-1s` as today (535) | W8, W10 |
| A13 | Old recording; transcode stays `Legacy` (536) | W5 |
| A14a | `Limits` program round-trips with a clamp (539) | W6 |
| A14b | Invalid request: no interaction, queue balanced (539) | W7 |
| A14c | Scripted extension `BashExec` expires at the default (540) | W6 |
| A14d | Post-change journal admits `Legacy`, replays strictly (541) | **W1**, W5, W13 |
| A15 | Schema ceiling; startup failure; decoder refusal (543) | W5, W11, W12 |
| A16 | Every entry point; same argument three ways (545) | W6, W7, W10, W11, W12, W13 |
| A17 | Limit fields survive `cap_tool_message_content`'s 65,536-character cut, on oversized output and on an oversized `cmd` (548) | W7, W10, W13 |
| A25 | `process_limits` survives the token: `ext_world` round trip with a distinct `Limits` value as the direct guard; loopback and extension checks through a real token assert `Limits` behaviour; a hook cannot change the driver's value; a token without it is `Legacy` (550). Numbered last so that other ids stay stable | **W5**, W6, W10 |
| A18 | Draws and interactions kept; diff limited; old journals fold and resume (554) | W5, W12 |
| A19 | Partial output, or explicit absence (557) | W12, W14 |
| A20 | Deadline separated from return latency (559) | W2, W10, W13 |
| A21 | Timeout `unknown`; `Search` timeout `none` (560) | W7, W10, W13 |
| A22 | Cancelling with SIGTERM or SIGINT stops command and descendants (562) | W3, **W9** |
| A23 | Existing large `MOTOKO_PROCESS_TIMEOUT` still starts (564) | W11 |
| A24 | `tools.delegated_timeout_ms` gains no role (565) | W11 |

### D7 entry points

| Entry point | Items |
|---|---|
| `BashExec`, `RunTests` via main dispatch | W6, W7 (scripted), W10, W12, W13 (live) |
| Scratchpad loopback (R7) | W10, W13 |
| Extension effects (R8) | W6, W7 (scripted), W10 (live), W13 |
| Internal helpers | W10 (A6) |
| TUI launch | W11, W13 |
| Direct CLI launch | W11, W12, W13 |
| Profile restart | W11, W13 |
| Herdr's check wait | W11 |

### D7's named migrations

| Migration | Items |
|---|---|
| Program schema v6, `/5` by name, frozen specimen, writers stamp `legacy` | W5 |
| Generator stays `Legacy`; 20-90 ms draw, salts, 2,000 ms bound untouched | W5 (A18). Teaching it limits is its own later change, not scheduled here |
| Replay: old-recording and scripted `Limits` round trips | W5, W6 |
| Journal resume: old journals fold and plan resume | W5, W12 |
| Rendered results (D4 re-baseline) | W12 |
| Mechanical fan-out, step 3: `ToolInvocation` literals (W6), token and version pins (W5), `tool_outcome_message`'s callers (W7) | W5, W6, W7 |
| Mechanical fan-out, step 4: `run_native_batch`, `dispatch_one_typed`'s callers (W10), `tools_for_mode` at the offer (W12) | W10, W12 |

## ADR questions

All resolved in the ADR. G1-G6 and H1 below cover what the eighth revision still left.

| # | Question, and the evidence in short | Resolved by |
|---|---|---|
| Q1 | `ResolvedProcess` held no value for `SessionDefault` or `SameAsDefault`, and `scripted_tool_outcome` and `tool_outcome_message` are pure | D7, the types and "The carrier": `session_default: SessionLimit` |
| Q2 | The token lists fields one at a time (`ext_world.ail:600`, `:642`, `:705`), so limits would be lost, with no compile error | D7, "The extension token", and §6's new criterion (A25) |
| Q3 | §6 and D4 disagreed on where scripted metadata lands, and a `Limits` program with an empty queue reaches the live arm (`ports.ail:1841`) | §6 steps 3 and 4, and G1 |
| Q4 | A scripted extension's deadline renders through `tool_outcome_text` (`session.ail:1150`), not `tool_phase` | D4, and D7's extension row, and G2 |
| Q5 | D7's fan-out list was incomplete | D7, "Migrations", split into step 3 and step 4 lists, and G3 and G6 |
| Q6 | "No attempt" and "a number in range" were unclear for calls built before the resolver | D4, "A call the resolver saw" |
| Q7 | An invalid request had no event, so P1 could not see it, and a Start would unbalance `corpus_judge` | D7, "Where it runs": `ToolArgumentsInvalid`, and G5 |
| Q8 | Ceiling typed in milliseconds, written in nanoseconds | D7, "Program modes": nanoseconds on disk, and the decoder refuses a value that is not a whole millisecond |
| Q9 | A profile restart changes today's `tools.process_timeout` behaviour, unlisted in I4 | I4 (§3), and D7's restart row. I4 also now lists the schema change |
| Q10 | `bash_exec_schema()` is a constant, and `ExtRuntime` holds no limit | D1: `tools_for_mode(rt, mode)`, no ABI change |

## Points the ninth revision settled

| # | Point | Resolved by | Effect on this plan |
|---|---|---|---|
| G1 | D3 and the TL;DR said "ships" where §6 lands scripted work before the pin | TL;DR and D3: both now say "activates" | None: W6 and W7 stay dark behind C2 |
| G2 | `tool_outcome_text`'s scope and carrier | D4: it renders an extension effect's **faults** and takes the carrier, and the deadline's `timeout_ms` is replaced | **W7 changed:** the interim handling covered the deadline only |
| G3 | Step 4 fan-out, and `dispatch_one` | D7, step 4 list: adds `ports.ail:1866` and `world_state_probe.ail:1402`, and `dispatch_one` keeps its signature | None: matches W10 |
| G4 | Where SIGKILL is disclosed | D5: "a row in the same probe", and the operator documentation | **Moved from W9 to W2:** the interim handling put it in W3's twin |
| G5 | Loopback and the new event | D7, "The extension token": no event, tested through the result, a known limit | None: matches W10 |
| G6 | Artifact wording, `1e400`, "a few weeks" | D7 and §8 for artifacts, D4 for `1e400`, R11: four weeks | **Rulings changed:** the plan no longer asks the operator for a number |

## Still open

**H1. Whether a scripted fault that says it came before dispatch reports an applied limit.** D4 says "the test is the attempt", then
says that a call with no attempt "means" an invalid request and the refusal in `run_process_result`. A scripted `ToolFailed` with
`after_dispatch: false`, and W6's `ToolFailed` for `ExplicitMs` before W10, are neither, though the harness knows nothing ran. §6
line 533 says a call "refused before any attempt" reports no limit. *This plan:* `attempted` is `after_dispatch` for `ToolFailed`, and
true for the other two faults, following "the test is the attempt". Neither case reaches a live run.

## Rulings R9-R11

| Ruling | What this plan does |
|---|---|
| **R9, acceptance** | Met. The check confirmed `session_default` and the extension token with amendments, and the ninth revision is accepted. W1-W7 can start. The ADR notes that its last changes were not reviewed, by the operator's choice, and are left to this plan's tests |
| **R10, D6 and the stall** | Ending process groups on SIGTERM and SIGINT satisfies D6 (W9, A22), and SIGKILL stays disclosed (W2). If #2034 has no maintainer direction or date by 2026-11-14, or upstream declines sooner, the TUI fix goes to the operator for a ruling, and is not built automatically |
| **R11, `manifest-A`** | Work items leave it alone and record the rows they leave red. The operator directs one regeneration after the last item that moves protected symbols, which is W12. If that wait passes four weeks, one follows the scripted work (W7) and one the live wiring (W12). This plan counts the four weeks from W7's merge, which R11 does not state |

**R11 checked against 034.** 034's `PLAN-001` has no section 6 of its own. W1.1 (lines 559 and 583-585) points to
`RECORD-W1.1-regrounding-a94204aa.md`, whose §6 holds the arrangement, accepted on 2026-10-18 as Option A. R11 agrees with
it, and adds the two-regeneration fallback. Three things carry over:

- Work items also leave `tools/eval_protected/`, `scripts/eval/` and `MATRIX.expected.tsv` untouched. W1 changed to match.
  Each compares `make eval_matrix` with its predicted list, and records moved rows as a basis change, not re-pinned.
- The regeneration is its own worktree and pull request: move `A` in `test_candidate.py`, then `protected.py gen --at <merge>
  --symbols tools/eval_protected/starting_set.json --allow-flags`, review the closure against 119 spans, then `protected.py pins`,
  `selftest.py` and `make eval_matrix`.
- Edits to `src/eval/journal/**` that type and version changes force were allowed in 034, and W1, W5 and W6 make the same kind.

Protected symbols moved: W5 `WorldState`, `empty_world_state`; W6 `ToolInvocation`, `scripted_tool_outcome`, and `session.ail`'s
imports if added; W10 `live_tool_outcome`; W12 `ported_provider`, and `stub_step.ail`'s region if its imports change. Each
re-measures this list.

## Out of scope

ADR §5's alternatives. A background-job tool. Process containment (D5, #2037). A recorder or journal capture for these
limits (R6). Teaching the generator limits and `timeout_secs` (D7 gives it its own change). Removing
`tools.delegated_timeout_ms`, which stays with the issue. Measuring whether the TUI stays usable during a long wait,
which ADR §8 notes as unmeasured.

## Related records

- [ADR-002](ADR-002-per-call-process-timeouts.md) and its [diagram](mmd/adr-002-per-call-process-timeouts.mmd)
- [ADR-001](ADR-001-delegated-process-timeouts.md) (this dir)
- [034 PLAN-001](../034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md), the `applied_faults` precedent for W5 and
  the invariant rule for W7
- [BashExec timeout-knob issue](../../issues/bashexec-timeout-knobs-are-dead.md)
