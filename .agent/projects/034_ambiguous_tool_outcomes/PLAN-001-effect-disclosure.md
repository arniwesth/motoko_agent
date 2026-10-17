# PLAN-001: effect disclosure for tool faults

Implements [ADR-001](ADR-001-effect-disclosure-for-tool-faults.md) (this dir), accepted as amended
by the operator on 2026-10-17 (its §6, rulings 1 to 5).

Status: **Phase 0 ready to implement.** Phases 0b, 1, 2 and 3 are planned to the task. Each opens
with a re-grounding step, because each starts after the one before it has merged.
Revised 2026-10-17 after an independent review by Codex Sol (`gpt-6.1-sol`), which found one
blocking defect and seven others. All eight were reproduced and are addressed (*Review*, at the
end).
Pinned toolchain: AILANG **v0.52.5** (`ailang.lock`; `ailang.toml` requires `>=0.52.5`).
Grounded at: `origin/main` **`e69aaad7`**. Every `file:line` below was read at that commit. ADR
§7 lists what moved since the ADR's own grounding.
Structure: [`PLAN-001.dagr.json`](PLAN-001.dagr.json) holds the tasks and their dependencies, and
is the only place they are stated (008 ADR-001 D2 and D3). A task's address is
`034/PLAN-001/<task id>`.
Naming: workstreams are W0, W0b, W1, W2 and W3, one per ADR phase (0, 0b, 1, 2, 3), and task ids
are `W<phase>.<n>`. P1, P2 and P3 always mean the ADR's three properties (§2), never a phase.
Who does the work: not assigned. Tasks carry no `owner`, so dagr shows them as unassigned until
the operator names one. The two operator decisions are tasks of kind `question` owned by
`operator`.

---

## TL;DR

- **Phase 0 (W0) is the live change.** Every tool fault the harness reports to the model gains a
  `fault` object whose `effects` is `none` or `unknown`. The value comes from what the harness
  observed, by ADR D2's table. It also corrects the `BashExec` description, which promises
  truncation where the model in fact gets nothing. One pull request. It touches `types.ail`,
  `tool_runtime.ail`, `tool_dispatch_adapter.ail`, `tool_catalog.ail` and one DST probe script,
  and none of the DST world.
- **Phase 0b (W0b) is the deadline wrapper.** An operator question sits in front of it, because
  upstream may make it unnecessary (#1878) and because GNU `timeout` is not on a stock macOS
  host.
- **Phase 1 (W1) builds the world side.** `ScriptedTool.applied` and a dispatch stage, a world
  effect log, catalogue `/3` with two world-only rows, the typed renderer's `fault`, and the
  generator cascade.
- **Phase 2 (W2)** adds the three properties, each accepted only once its mutant has been seen
  red. **Phase 3 (W3)** adds the report's counters for the new rows and the duplicate-effect-key
  metric.
- The graph holds the order. Two things in it are not obvious and are argued below: Phase 0
  leaves `tool_phase.ail` alone (*Choices this plan makes*, C1), and Phase 3 runs beside Phase 2
  (C4).

## Standing rules

These apply to every task.

1. **Re-ground before building** (`.agent/meta-decisions/re-ground-inherited-anchors-before-building.md`).
   The first task of each workstream re-reads every anchor it inherits, against the commit it
   branches from, and records what moved in its pull request.
2. **One workstream, one worktree, one pull request** (`AGENTS.md`). A workstream's tasks share
   its branch. Workstreams are cut by source surface
   (`.agent/meta-decisions/sequence-implementation-handoffs-by-source-surface.md`).
3. **Mutation discipline** (`.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`).
   Each workstream's mutation task runs the mutants this plan names, with the expected test named
   before the run. Only that test failing counts as a kill. Each mutant is paired with a survival
   case. The evidence is `mutants.tsv`, the script and the commit it ran at. There is no shared
   runner. Use `013_core_architecture_for_dst/mutgate.sh`, or a script on the pattern of
   `011…/evidence/judge-recoveries/acceptance-ce9cb247/scripts/`.
4. **Heavy runs one at a time.** `make dst`, `make eval_matrix` and `make corpus_pr` are never run
   concurrently with each other or with another session's. `make eval_matrix` is under the 12 GiB
   memory rule (`Makefile:3526`).
5. **Green is a difference** (ruling 5). Phase 0's before and after baselines are compared row by
   row. Each workstream's gate lists the rows it expects to change. Any other changed row is a
   finding, recorded with its cause, not re-pinned silently.
6. **A world-only class id never reaches the wire** (ADR D4). From W1 onward no projected tool
   message may contain one. W1.5 adds the guard.

## What is true at `e69aaad7`

The ADR's anchors hold; its §7 has the drift. The facts below are the ones the tasks depend on
and the ADR does not state.

**Where the live bytes come from.** `live_tool_outcome` (`ports.ail:1759-1762`) calls
`dispatch_one_typed`, which renders with `tool_result_item_to_json`
(`tool_dispatch_adapter.ail:95-160`, called at `:204-213`). The result goes into
`ToolCompleted.content`. Scripted DST tools pass `ScriptedTool.content` through
(`ports.ail:1787`), and only the three typed faults reach `tool_fault_message`
(`tool_phase.ail:277-304`). DST reaches the live renderer only when the tool queue is empty
(`ports.ail:1744`), which fixtures and `generating_tool` (`:2269-2299`) prevent. The exception is
the live witnesses `make world_state` runs (`exit_code_witness`), which compare two live
renderings and pin no bytes. So a change confined to the live renderer moves no DST pin. That is
why Phase 0 is cheap to check.

**What a change to `tool_phase.ail` costs.** `tools/predicate-anchors/anchors.sh:110-111` and
`:764` anchor `tool_phase.ail:388`, `:389` and `:484`, mirrored in `dst_attribution_table.ail:221`
and `:249`. An edit that changes the net line count above `:388` moves them. Re-baselining them
changes `table_content_hash` (`dst_attribution_table.ail:292`), which by design is copied by hand
into all four profiles with a version bump (`Makefile:952-959`). The four profile versions are:

| Profile | Version | Version line | Hash line |
|---|---|---|---|
| `driver_only` | "37" | `dst_driver_only.ail:549` | `:919` |
| `no_ops` | "26" | `dst_driver_plus_no_ops.ail:238` | `:451` |
| `compose` | "18" | `dst_driver_plus_compose.ail:243` | `:420` |
| `herdr` | "7" | `dst_driver_plus_herdr.ail:163` | `:199` |

**No test covers the three functions Phase 0 changes.** `run_process_result`
(`tool_runtime.ail:974`), `tool_result_item_to_json` (whose file has no tests) and
`tool_fault_message` have no inline tests. `make test` runs only `agents_md.ail`
(`Makefile:3193-3203`). `make test_coverage` (`Makefile:3693`) runs `ailang test` over `src/core`,
and is the target that picks up new inline tests. The live witness precedent is
`exit_code_witness` (`scripts/dst/world_state_probe.ail:1128-1179`). It is run as its own
`--entry` with full caps by `make world_state` (`Makefile:2278-2282`), which `make dst` includes.

**Every other reader of the result JSON reads by key.** These are compose's `decode_bash_result`
(`packages/motoko-ext-compose/proc.ail:153-162`), herdr's `bash_field` and `bash_exit`
(`packages/motoko-ext-herdr/types.ail:1801-1835`), the session normaliser
(`session.ail:2018-2047`), the TUI (`runtime-process.ts:57-63`), `benchmarks/tool_failures.py` and
`motoko_rpc.py`. An extra key breaks none of them.

**Overlap.** Open #234, stacked on #209, rewrites the bodies of `validate_path_common`
(`tool_runtime.ail:465-480`) and `atomic_write` (`:824-855`). Phase 0 edits `path_error` (`:404`)
and the call site of `atomic_write` (`:899`), not those bodies. If either pull request adds a
`ToolErrorResult` construction, the one that lands second must give it a `fault`, because W0.2
makes the field required. W0.2's re-grounding checks which has landed.

## Choices this plan makes

These are not in the ADR. Each can be changed before the task it governs starts.

**C1. Phase 0 does not touch `tool_phase.ail`.** D2 maps policy denials and undecodable arguments
to `none`, and property P1's second half needs every harness-reported fault message to carry `effects`. The
builders for those messages (`denial_message`, `tool_phase.ail:108`;
`undecodable_arguments_message`, `:347`) and the typed renderer (`:297`) all sit above the anchor
at `:388`. Changing them in Phase 0 would pull the anchor and profile-hash cascade into a phase
that otherwise touches no DST file. Phase 1 bumps all four profiles anyway (catalogue `/3`), so
W1.4 changes all three builders and pays the cascade once. The cost is that the live wire moves
twice for messages: once in W0 for tool results, once in W1 for denials and undecodable arguments.
Both of those messages already tell the model the tool was not run (`denied_by_policy: true`; "the
tool was NOT run", `:353`).

**C2. The typed renderer's `fault` is Phase 1 work.** ADR §4 puts only "the D3 object in the live
renderer" in Phase 0. `ToolFailed`'s dispatch stage, which decides `none` against `unknown` on the
typed path, has no producer until `ScriptedTool` gains one (W1.2). So W1.4 adds the object to
`tool_fault_message`. Programs recorded before W1 decode as after dispatch (W1.2's legacy default),
so they render `unknown`.

**C3. The wire vocabulary and the two sentences.** ADR D3 leaves the sentences' wording to the plan.
Proposed:

```json
{"tool":"BashExec",
 "fault":{"kind":"output_limit","effects":"unknown","bytes":1000,
          "note":"The harness cannot confirm whether this tool's effects happened. They may have happened in full, not at all, or may still be happening. Check the current state before running it again."},
 "cmd":"make build","exit_code":1,"stdout":"","stderr":"output limit exceeded: 1000 bytes","truncated":false}
```

| `effects` | `note` |
|---|---|
| `none` | "No change was made: the tool failed before it could write or change anything." |
| `unknown` | "The harness cannot confirm whether this tool's effects happened. They may have happened in full, not at all, or may still be happening. Check the current state before running it again." |

The sentences say only what the harness knows. `none` covers read-only failures, where a
read-only process such as `rg` may have run but could change nothing (D2 row 4). So it speaks of
change, not of whether anything ran. `unknown` covers `PermissionDenied`, where the target program
almost certainly never ran (ruling 3). So it does not claim the tool started. *(Revised after
review finding 3.)*

`kind` names the observation, never the world's truth:

| `kind` | From | Extra fields |
|---|---|---|
| `not_allowed`, `not_found`, `permission_denied`, `spawn_failed` | the `ProcessError` arm of the same name | — |
| `deadline` | `Timeout(ms)`; in W1, `ToolDeadlineExceeded` | `elapsed_ms` |
| `output_limit` | `OutputLimitExceeded(n)` | `bytes` |
| `signal` | `AbnormalExit(sig, name)` | `signal`, `signal_name` |
| `refused` | a validation refusal before the effect (D2 row 3) | — |
| `io_error` | a filesystem call that returned `Err` | — |
| `failed`, `correlation_mismatch` | W1: `ToolFailed`, `ToolCorrelationMismatch` | — |
| `denied`, `arguments_undecodable` | W1: policy or approval denial; undecodable arguments | — |

The key name, the two values, the kinds and the two sentences come from one home, imported by
every renderer, as the `fault_class_*` names do (`dst_fault_catalogue.ail:61-63`). The existing
`stderr` prose stays as it is.

**C4. Phase 3 runs beside Phase 2.** Both need W1's effect log. Neither needs the other. W2's
surface is `dst_invariants.ail`, `invariants_dst.ail` and `corpus_judge_dst.ail`. W3's is
`dst_run_report.ail`, `run_report_dst.ail` and `corpus_pr_dst.ail`'s class observer. Both edit the
`Makefile`, in different targets.

**C5. Deterministic baselines only, as ruled (ruling 5).** Phase 0's before and after are `make dst`
and `make eval_matrix`. No model-in-the-loop run is a gate. One is listed under *Follow-ups*.

---

## Phase 0 — live disclosure

One worktree, one pull request. Surface: `src/core/types.ail`, `src/core/tool_runtime.ail`,
`src/core/tool_dispatch_adapter.ail`, `src/core/tool_catalog.ail`,
`scripts/dst/world_state_probe.ail`, and the baseline evidence directory.

### W0.1 — baseline before

At the commit the branch is cut from, before any source change: `make dst`, then
`make eval_matrix`, one after the other. They go in
`evidence/baseline-<sha>/` on the pattern of
`011_improve_test_axises/evidence/judge-recoveries/baseline-59d5cbb9/`:

- `README.md` saying what was run, where and how long it took;
- `run_baseline.sh`;
- the `make dst` log's list of FAILED target names;
- `MATRIX.tsv`;
- a compare script (copy `compare_matrix.py`) that W0.7 runs.

Costs recorded at `59d5cbb9`: `make dst` 2,085 s at `-j8`, `make eval_matrix` 821 s. A target
that already fails at the base is recorded as failing at the base. It is not W0's to fix.

**Gate:** the directory exists and the script reproduces it.

### W0.2 — the types, the two mappings, and every construction site

One commit, because a required record field does not compile until every literal states it.

- **Types.** In `types.ail`, add a two-arm sum for the disclosure and a fault record: kind,
  disclosure, and the kind's numbers per C3. `ToolErrorResult` (`:173-177`) gains the record as a
  required field. `BashExecResult` and `RunTestsResult` (`:154-172`) gain it as an `Option`,
  `None` on the `Ok` arm.
- **The one home** for the key, values, kinds and sentences (C3). Put it where the renderers can
  import it without a cycle, and record where.
- **Two pure mappings over `ProcessError`**, each one exhaustive `match` with no wildcard and one
  inline test row per arm. One gives the kind, the other the disclosure. The disclosure table is
  ADR D2 as ruled: `NotFound` and `NotAllowed` are `none`; `PermissionDenied`, `SpawnFailed`,
  `Timeout`, `OutputLimitExceeded` and `AbnormalExit` are `unknown`. A new upstream arm is then a
  compile error in both.
- **Every construction site states its value** (D2), all in `tool_runtime.ail`:

| Line | Site | `effects` | `kind` |
|---|---|---|---|
| 248 | unknown tool | `none` | `refused` |
| 404 | `path_error` (7 callers, `:444-475`) | `none` | `refused` |
| 529 | ReadFile `readFileResult` `Err` | `none` | `io_error` |
| 590 | Search "missing pattern" | `none` | `refused` |
| 596 | Search `rg` `ProcessError` | `none`: no update to apply | from the process mapping |
| 701 | WriteFile `mkdirAllResult` `Err` | `unknown` | `io_error` |
| 703 | WriteFile `writeFileResult` `Err` | `unknown` | `io_error` |
| 870, 872, 877, 880 | EditFile: no file, no edits, sha256 mismatch, edits do not apply | `none` | `refused` |
| 899 | EditFile `atomic_write` `Err` | `unknown` | `io_error` |
| 987 | delegated-backend refusal | `none` | `refused` |
| 1000, 1012 | `run_process_result` `Err` arm, RunTests and BashExec | from the process mapping | from the process mapping |
| 946, 961 | `to_bash_result`, `to_test_result` (the `Ok` arm) | absent | — |

`exit_code` stays `1` on every faulted result (D3).

**Gate:** `make check_core` and `make test_coverage`, with the two mappings' rows among the tests
it runs.

### W0.3 — the live renderer emits `fault`

`tool_result_item_to_json` (`tool_dispatch_adapter.ail:95-160`):

- **On every faulted arm, `fault` comes immediately after `tool`**, before every field whose size
  is not bounded, `cmd` included. `BashExecResult` and `RunTestsResult` emit it when it is `Some`.
  `ToolErrorResult` always emits it. Tool messages are cut from the end
  (`cap_tool_message_content`, `phase_vocab.ail:1546-1555`, applied at `:1588-1591`; the cap counts
  code points). So only a field ahead of `fault` can push it out of the message, and today
  `BashExecResult` renders an unbounded `cmd` before `exit_code` (`:136-142`). A command of 70,000
  code points that passes the output cap would otherwise reach the model with no `fault` at all.
  ADR D3 asked for `fault` before `stdout` and `stderr` for this reason; this applies the same
  reason to `cmd`. *(Revised after review finding 2.)*
- The `Ok` arm's JSON is byte-identical to today's. Hand-copied `Ok` shapes used as scripted
  content in `discovery_dst.ail`, `driver_plus_compose_dst.ail` and `herdr_graded_dst.ail` stay
  valid.

The file has no tests. Add inline tests:

- a faulted `BashExecResult` with key order asserted;
- a `ToolErrorResult`;
- an `Ok` result asserted byte-equal to its rendering before W0;
- **the long-command case:** a faulted `BashExecResult` whose `cmd` is longer than the cap, passed
  through the same cap the tool message gets. The complete `fault` object survives it;
- the two `note` sentences, asserted verbatim from the one home, so a wording change is a visible
  test change.

**Gate:** `make check_core`, `make test_coverage`, and `make world_state`. Its existing
`exit_code_witness` compares `dispatch_one` with `dispatch_one_typed` byte for byte, and both read
this renderer.

### W0.4 — the `BashExec` description says what happens

`tool_catalog.ail:54` promises "truncation past a configured byte cap". Past the cap the model gets
no output and exit 1 (NOTE §6.2, case 4). Proposed:

> Run a shell command in the workdir with capability gating. Output is captured to stdout/stderr.
> If the command passes the runtime's output cap or time limit, its output is not returned and the
> result carries a `fault` whose `effects` is `unknown`: the command may still have done its work.

`timeout_secs` stays in the schema, and nothing reads it until W0b. The description is not part of
`system_prefix_digest` (`phase_vocab.ail:369`, system messages only; inferred from the code, so
W0.4 confirms). Resuming a journal recorded before W0 is then unaffected.

**Gate:** `make check_core`. `grep` finds no other copy of the old sentence outside 037's recorded
evidence, which stays as recorded.

### W0.5 — live witness rows

ADR §2 requires a live witness through `run_process_result` that reads the rendered message, for
one `unknown` arm and one `none` arm. Add an entry beside `exit_code_witness`, with the same full
caps, run by `make world_state`. It has one row per case:

| Row | Call | Expected `fault` |
|---|---|---|
| a | `BashExec` `kill -9 $$` (shell tokens, so wrapped) | `kind: signal`, `effects: unknown` |
| b | `BashExec` of a command that does not exist, no shell tokens (direct exec) | `kind: not_found`, `effects: none` |
| c | `BashExec` `exit 3` | no `fault` key; `exit_code: 3` (survival) |
| d | `WriteFile` whose parent path is a regular file (`mkdirAllResult` fails) | `io_error`, `unknown` |
| e | `WriteFile` into a directory with mode 555 (`writeFileResult` fails) | `io_error`, `unknown` |
| f | `EditFile` of a file in a directory with mode 555 (`atomic_write` fails) | `io_error`, `unknown` |
| g | `EditFile` with a wrong `expected_sha256` | `refused`, `none` |
| h | `ReadFile` of a directory | `io_error`, `none` |
| i | an unknown tool name (`:248`) | `refused`, `none` |
| j | `ReadFile` of a path that escapes the workspace (`path_error`, `:404`) | `refused`, `none` |
| k | `Search` with an empty pattern (`:590`) | `refused`, `none` |
| l | `EditFile` of a path that does not exist (`:870`) | `refused`, `none` |
| m | `EditFile` with no edits (`:872`) | `refused`, `none` |
| n | `EditFile` whose edit does not apply (`:880`) | `refused`, `none` |
| o | `BashExec` with `streaming: true` (`:987`) | `refused`, `none` |

Rows i to o give each refusal site its own row, so each has a mutant in W0.6 *(added after review
finding 4)*. Row o's site may be unreachable from native dispatch: `needs_delegation_for_process`
routes such a call away first (`tool_runtime.ail:215`). If so, the row records that, with the
coordinate, and m29 is a survivor by that sentence.

**Rows e and f depend on permissions, which root ignores.** Nothing makes `mktemp`, `chmod` or `mv`
fail for root, and a directory target is no substitute: `run_write_file` calls `readFile` on it,
not `readFileResult` (`:690`). Run as root, the entry reports those two rows as not evaluated,
never as passed. **That does not satisfy this gate or W0.6's m09 and m10. Merge acceptance needs a
run as a non-root user.** *(Revised after review finding 7.)* Row d fails the same way for root.

**Gate:** `make world_state` run as a non-root user, with every row green (row o green or recorded
unreachable).

### W0.6 — mutation run

Each row below is one change to source, and the named test must fail. The table is fixed here,
before the code exists. The implementer may add rows, and must not drop one.

| # | Rule (ADR) | Mutant | Expected to fail |
|---|---|---|---|
| m01 | D2 `SpawnFailed` → `unknown` | map it to `none` | its row in the disclosure mapping's tests |
| m02 | D2 `PermissionDenied` → `unknown` (ruling 3) | map it to `none` | its row |
| m03 | D2 `Timeout` → `unknown` | `none` | its row |
| m04 | D2 `OutputLimitExceeded` → `unknown` | `none` | its row |
| m05 | D2 `AbnormalExit` → `unknown` | `none` | its row, and W0.5 row a |
| m06 | D2 `NotFound` → `none` | `unknown` | its row, and W0.5 row b |
| m07 | D2 `NotAllowed` → `none` (ruling 2) | `unknown` | its row |
| m08 | D2 WriteFile after `mkdirAllResult` → `unknown` | `none` at `:701` | W0.5 row d |
| m09 | D2 WriteFile after `writeFileResult` → `unknown` | `none` at `:703` | W0.5 row e |
| m10 | D2 EditFile after `atomic_write` → `unknown` | `none` at `:899` | W0.5 row f |
| m11 | D2 a refusal before the effect → `none` | `unknown` at `:877` | W0.5 row g |
| m12 | D2 read-only failure → `none` | `unknown` at `:529` | W0.5 row h |
| m13 | D1 a call that ran to its own exit carries no disclosure | emit `fault` on the `Ok` arm | W0.5 row c, and W0.3's byte-equal `Ok` test |
| m14 | D3, as tightened in W0.3: `fault` precedes every unbounded field | emit it after `cmd` | W0.3's long-command test |
| m15 | D3 every harness-reported fault carries `effects` | drop `fault` from the `ToolErrorResult` rendering | W0.3's `ToolErrorResult` test |
| m16-m22 | C3 the kind of each `ProcessError` arm, one mutant per arm | change that arm's kind to another kind | that arm's row in the kind mapping's tests |
| m23 | D2 refusal → `none`, unknown tool | `unknown` at `:248` | W0.5 row i |
| m24 | D2 refusal → `none`, `path_error` | `unknown` at `:404` | W0.5 row j |
| m25 | D2 refusal → `none`, Search missing pattern | `unknown` at `:590` | W0.5 row k |
| m26 | D2 refusal → `none`, EditFile no file | `unknown` at `:870` | W0.5 row l |
| m27 | D2 refusal → `none`, EditFile no edits | `unknown` at `:872` | W0.5 row m |
| m28 | D2 refusal → `none`, EditFile edits do not apply | `unknown` at `:880` | W0.5 row n |
| m29 | D2 refusal → `none`, delegated backend | `unknown` at `:987` | W0.5 row o, or a survivor if row o is unreachable |

No mutant is possible for "a new upstream arm is a compile error": the property is that no
wildcard exists, and that is checked by reading the code. The table records it as a survivor with
that sentence. Search's `rg` failure (`:596`) has no row: it is `Err` only when `rg` itself
cannot be launched, which no portable fixture arranges. It is recorded as a survivor with that
sentence. Survival cases: W0.5 rows b, c, g, h and i to n must stay green on unmutated source.

The table was widened after review finding 4: kinds m16-m22, the refusal sites m23-m29, and m14
moved to the stricter order.

**Gate:** `mutants.tsv`, run as a non-root user, with every row a kill or a survivor carrying a new
test or a sentence saying why no input tells the two versions apart.

### W0.7 — baseline after, and records

At the pull request's head, `make dst` then `make eval_matrix`, compared row by row with W0.1.

- **Expected differences:**
  - `make world_state` gains W0.5's rows;
  - `make test_coverage` gains W0.2's and W0.3's tests.
- **Expected no difference:**
  - every other DST target, because DST does not reach the live renderer (*What is true*);
  - every `eval_matrix` row, because journals replay recorded tool content verbatim
    (`world.ail:88-89`). That is inferred, and this run is what tests it.

Any other row that differs is a finding: record it in the baseline directory with its cause.

Also run `make compose_live_exec` and `make verify_native_path_guard`, which match
`"error":true` and "escapes workspace", both still present. Run `cd src/tui && bun run test`.

Records:
- the ADR's status line gains "Phase 0 implemented in #N";
- this plan's status moves to W0b;
- the PR record carries the task addresses.

**Gate:** the comparison has no unexplained row, and every target above is green or failing
exactly as at the base.

---

## Phase 0b — the deadline wrapper

Own worktree and pull request, after W0 merges. Surface: `run_process_result`
(`tool_runtime.ail:974-1025`), `tool_catalog.ail` (`timeout_secs`), and
`runtime-process.ts:1009-1022` if the wall needs to be known.

### W0b.1 — probe through `run_process_result`

NOTE §6.3's probes called `exec` directly. This one goes through `run_process_result` with
`timeout -k <grace> <deadline>` around the effective command, and reads the rendered message. It
answers the open points:

- **Exit 124.** It is also a legal exit for the command itself, and GNU `timeout` passes a
  command's own 124 through unchanged. What tells a wrapper deadline apart? Elapsed time against
  the deadline is one candidate; `--verbose` stderr is another, and fragile.
- **Availability.** GNU `timeout` is not on a stock macOS host, where it is `gtimeout` from
  coreutils if installed at all. Other worktrees of this repository live on a macOS host. What
  does `run_process_result` do where neither exists?
- **The direct-exec arm.** The wrapper is needed when there are no shell tokens too.
- **Case A** (exit 0 with a held pipe). Untested under a wrapper (ADR D6).
- **The pin.** Under AILANG `>=0.54.14` the runtime kills the group itself (`RESULTS-v0.52.5.md`).
  Does the wrapper still add anything apart from partial output and a meaning for `timeout_secs`?

Output: `evidence/wrapper_probe.sh` and a results file.

### W0b.2 — the operator decides whether W0b goes ahead

A `question` task. The inputs are W0b.1's results, the state of sunholo-data/ailang#1878 (partial
output upstream would remove the wrapper's main reason), and whether the pin has moved to
`>=0.54.14` (012). The answers: go ahead as planned; go ahead re-scoped; or withdraw W0b, in which
case W0b.3 and W0b.4 are canceled.

### W0b.3 — the wrapper

As W0b.2 decides. The planned shape:

- every `run_process_result` call is wrapped;
- the deadline is `timeout_secs` when given, clamped below the wall, and otherwise just under the
  wall;
- a wrapper deadline renders `kind: deadline`, `effects: unknown`, with the captured output
  intact;
- where no `timeout` exists, the call is not wrapped and behaves as W0 left it;
- the dropped `req.args` on the `bash -lc` arm (ADR §7) is fixed here, because these are the lines
  W0b.3 rewrites. If that turns out not to be a defect, W0b.3 says why.

### W0b.4 — mutation run, baseline pass, records

Mutants:

| # | Rule | Mutant |
|---|---|---|
| w1 | the clamp | the deadline is not clamped below the wall |
| w2 | 124 classification | a command's own 124 is rendered as a deadline |
| w3 | the absent-`timeout` fallback | the fallback is dropped |
| w4 | a wrapper deadline is `unknown` | it renders `none` |
| w5 | a wrapper deadline keeps the captured output (W0b.3) | drop `stdout` and `stderr` on that arm |

w5 was added after review finding 4. Each expects the W0b.1-derived witness row for its case. W0.7's baseline procedure is repeated
against W0's head.

---

## Phase 1 — the world and the catalogue

Own worktree and pull request. Surface: `ports.ail`, `dst_program.ail`, `dst_persistence.ail`,
`dst_replay.ail`, `dst_fault_catalogue.ail`, `dst_generator.ail`, `tool_phase.ail`, the four
profile modules, `dst_attribution_table.ail`, `tools/predicate-anchors/anchors.sh`, and
`scripts/dst/*`. It is the largest workstream. WI-D1's cost note applies: "a generator change is a
five-artifact cascade … budgets wrong by about an hour", and that session took about 2 h
(`009_motoko_dst_execution/NOTE-d1-fault-reachability-rows-4-and-11.md:8`, `:325-330`). Budget one
`make dst` (260-367 s) per commit.

### W1.1 — re-ground, and settle the program schema version

Re-read every anchor below at the branch point. Check 031 `PLAN-001` P2.1. At `e69aaad7` it claims
`execution-program/5` (`031…/PLAN-001-implement-adr-001-abi-8.md:434`), is unlanded and has no
date, and #272 adds a second dependant. W1 takes the next version free when it lands. If that is
`/5`, W1.1 adds a note to 031's plan that its P2.1 renumbers. The same check applies to
`fault-catalogue/3`, `invariant-set/3` (W2) and the profile versions.

### W1.2 — `ScriptedTool` gains `applied` and a dispatch stage, and a program carries both

- `ScriptedTool` (`ports.ail:599-606`) gains `applied: bool` and a stage: before or after dispatch.
- **The two travel by different routes, because one is an observation and one is not.**
  - **The stage is an observation.** It goes in the served outcome payload, through
    `encode_tool_outcome` (`ports.ail:2577-2601`) and `decode_tool_outcome` (`:2608`), and is
    replayed as `code` and `exit_code` are. `decode_tool_outcome` never sees the version, so use
    either a presence read with the stated default (the `exit_code` precedent, `:2638-2648`) or the
    version threaded through. Record which.
  - **`applied` is world truth and never enters the served payload.** Replay rebuilds every
    `ScriptedTool` from served outcome payloads alone (`tools_of`, `dst_replay.ail:761-772`). So a
    payload carrying the bit would be a carrier D4 forbids. It would also make property P2's
    comparison, which keys on the payload (`dst_invariants.ail:2242-2244`), differ for every twin
    by construction.
- **`ExecutionProgram` (`dst_program.ail:243-252`) gains a world-truth field beside
  `interactions`:** the ordinals of the tool interactions whose effect applied.
  - *Recording.* The program builders that copy `w.log` (`corpus_pr_dst.ail:428-447`,
    `seeded_generator_dst.ail:600-619`, and any other found at W1.1) also fill it, from W1.3's
    effect log mapped to ordinals by call id.
  - *Replay.* `tools_of` decodes outcomes as today, then sets `applied` on each `ScriptedTool`
    whose ordinal is listed.
  - *Twins.* Property P2's twin is the same program with one ordinal added to or removed from the
    list. The served interactions are untouched.
- **Versions.** Program schema to the next version (`dst_program.ail:132`, history `:63-131`,
  decodable versions `:151-153`, pin test `:700-718`).
  - *Legacy.* Older versions decode with the list empty and every stage **after dispatch**. "Not
    applied" is the recorded meaning of every existing tool fault row ("did NOT occur",
    `dst_fault_catalogue.ail:346`), so it is a default the S32 rule allows
    (`009…/PLAN-implementation-deterministic-test-world.md:654`, `:715`).
  - *Malformed new version.* A program at the new version must carry the field, though it may be
    empty. A listed ordinal that is not a tool interaction, or whose outcome is completed or before
    dispatch, is rejected. So is `applied` on a before-dispatch fault (ADR D4).
- **A frozen fixture** of the new version, as `43bafa7c` added
  `scripts/dst/fixtures/execution-program-v3.artifact`. It holds at least one applied call.
- **Acceptance.**
  - (a) A program with one applied call round-trips through persistence, decode and replay, and
    replay reproduces the effect log.
  - (b) Two programs that differ only in the world-truth list serve identical interactions,
    payload and advance alike. Property P2 depends on this precondition.
  - (c) Each rejection above has its own row.
- Closest precedent: `ba272abc` (`/1` → `/2`, added `ScriptedTool.exit_code`, 21 files). It
  carried an observation, so it needed only the codec. This change also needs the world-truth
  field.

### W1.3 — the effect log, and `ToolFailed`'s stage

- `WorldState` (`ports.ail:183`) gains an append-only effect log of `{call_id, effect_key}`, where
  `effect_key` is a digest of tool and arguments. Only `world_tool`'s scripted arm
  (`ports.ail:1723-1749`) appends, when `applied` is set. `scripted_tool_outcome` (`:1775-1788`)
  stays a function of the observation fields: it reads neither `applied` nor the log.
- `ToolFailed` (`ports.ail:649`) gains the dispatch stage, copied from `ScriptedTool`'s. It is an
  observation (D3). `ToolDeadlineExceeded` and `ToolCorrelationMismatch` gain nothing.
- The served-interaction log `WorldState.log` (`:444-459`) is unchanged. W2's oracles read both
  logs. The effect log is the source W1.2's recording step fills the program's world-truth field
  from.

### W1.4 — the typed renderer and the harness's own fault messages emit `fault`

All three builders are in `tool_phase.ail` (C1, C2):

- `tool_fault_message` (`:297-304`) gains the object.
  - `ToolFailed` before dispatch → `none`; after dispatch → `unknown`.
  - `ToolDeadlineExceeded` and `ToolCorrelationMismatch` → `unknown`, by construction.
  - `kind` per C3.
- `denial_message` (`:108`) and `undecodable_arguments_message` (`:347`) gain `none`. The latter's
  existing sentence stays.

Then the cascade:
- re-baseline the anchors at `tool_phase.ail:388`, `:389` and `:484`, and the attribution table
  rows;
- copy the new `table_content_hash` into the four profiles, and bump their versions with a dated
  history paragraph. Precedent: `072bb05a`, driver_only 3 → 4.

Also moved:
- the exact-bytes test of `denial_message` (`tool_phase.ail:670-678`);
- the corpus_pr wire hash recorded in 011's evidence, which is not a make target.

**Journals.** Journals recorded before W1 hold the old denial and undecodable-argument bytes.
Journal admission A2 (`src/eval/journal/source_checks.ail:285`, `MessageDiffers`) would reject
them at replay. W1.4 states the remedy before it changes the bytes. Either replay rebuilds those
messages at the version they were recorded under, or A2 compares them under a stated
normalisation. Whichever it is must keep `make eval_matrix`'s rows explained, under standing
rule 5.

### W1.5 — catalogue `/3`: a visibility field and two world-only rows

- **A visibility field on every row**, either a wire name or world-only with a twin id. A field
  on one row alone would change that row's shape only, and D4 rejects that.
- **Two rows:** `tool_effect_applied_then_failed` (twin `ToolFailed`) and
  `tool_effect_applied_then_deadline` (twin `ToolDeadlineExceeded`). Each copies its twin's
  delivery constructor and recovery branch, and its logical transition says the update did occur
  and the delivered outcome is byte-identical to the twin's.
- **`validate_catalogue`** (`:565-570`) rejects a world-only row whose twin is missing, is itself
  world-only, or differs in constructor or branch.
- **Counts and versions:** `fault-catalogue/2` → `/3` (`:55`); `== 11` → `== 13` (`:795`). The
  hand literal `scripts/dst/profile_definition_dst.ail:207` moves.
- **Coverage.** Two `AlwaysApplicable` rows enter `expected_bank_coverage`
  (`dst_corpus.ail:1156`), which wants two witnesses for each, so `corpus_pr` is red until the
  bank reaches them. The class observer `observed_classes` (`corpus_pr_dst.ail:545-563`) reads
  `fault_class_id` from the typed outcome, where a world-only row never appears. It gains an arm
  that reads the effect log. This is W1's half of the counter work. W3 does the report.
- **The lexical guard** (standing rule 6): a check, in a target that runs the bank, that no
  projected tool message contains either world-only id.

### W1.6 — the generator draws `applied`, and the cascade

- `choose_tool` (`dst_generator.ail:740-777`) draws `applied` for the after-dispatch `Failed` and
  `Late` arms, under its own salt. `draw` threads `g.rng` (`:433`), so the added draw re-phases
  every later choice. Property P2's twin is built by flipping one field of a program, not by the
  generator, so the re-phasing does not touch it.
- **The `generator_version` literal `"1"` → `"2"`.** At `e69aaad7`, 17 lines match
  `generator_version: "1"` or define `generator_version()`: 15 under `scripts/dst` (e.g.
  `corpus_pr_dst.ail:299`, `:675`; `seeded_generator_dst.ail:255`, `:597`), plus
  `dst_generator.ail:15` and `dst_replay.ail:1135`. W1.1 re-derives the list and separates
  producer versions from fixture literals; only producers move. Axis K's equality check
  (`seeded_generator_dst.ail:1135-1137`) moves with them. The literal has never been bumped
  before, so check every reader `seed_state` (`dst_generator.ail:395`) and
  `dst_persistence.ail:346`, `:550` and `:1247-1255` feed.
- **The seeded suite's version contrast keeps a different version.** The row named `versioned`
  (`seeded_generator_dst.ail:1228`) hard-codes `"2"` as the version that differs from the current
  one. After the bump it would be a same-version repeat, and the run-level version witness would be
  lost silently. It moves to a version unequal to the new current one, and the suite asserts the
  inequality, so the next bump cannot repeat this. *(Added after review finding 5.)*
- **The rich fixture and the equal-count pair are re-swept** under the new generator: seed 110, and
  132 against 12, in both `main` and `wire_witness` (`:1177-1180`, `:1224-1228`). The added draw
  re-phases them, and `Makefile:1277-1281` refuses a pair that has lost its equal count. Keep each
  one's stated property (richness; equal count with different contents) and re-pin.
- **The canary is re-pinned by hand** (`pinned_canary_v1` and `_v2`, `dst_generator.ail:1274-1284`).
  Use a throwaway sweep of seeds 1..260 at both versions, keep pairwise-distinct rows, and delete
  the script (`:1248-1273`). There is no `--update`, by design.
- **The PR bank is re-derived** (`fixed_bank()`, `corpus_pr_dst.ail:628`). It is the union of five
  selections from a 260-seed sweep, now required to reach both world-only rows twice. Re-measure
  the cost constants (`dst_corpus.ail:347`, `:487`) if the median moves.
- Any profile not already bumped in W1.4 is bumped here.
- Cost: WI-D1's five artifacts, plus the two seeded fixtures above.

### W1.7 — mutation run

*(Added after review finding 4: W1 states rules that need detectors, and the plan had no mutation
task for them.)* One mutant per rule, with the expected test named before the run, as in W0.6:

| # | Rule | Mutant | Expected to fail |
|---|---|---|---|
| v01 | W1.2 a legacy program decodes with an empty world-truth list | decode it as all applied | W1.2's legacy-fixture row |
| v02 | W1.2 a new-version program must carry the field | accept its absence as empty | W1.2's missing-field rejection row |
| v03 | W1.2 a listed ordinal must be an after-dispatch fault | accept a completed outcome's ordinal | W1.2's listed-ordinal rejection row |
| v04 | D4 `applied` on a before-dispatch fault is rejected | accept it | W1.2's before-dispatch rejection row |
| v05 | W1.2 replay sets `applied` from the list | ignore the list | W1.2 acceptance (a), the round trip |
| v06 | W1.2 `applied` never enters the served payload | encode it in the outcome payload | W1.2 acceptance (b), equal served interactions |
| v07 | W1.3 the effect log is appended only when `applied` | append on every scripted fault | W1.2 acceptance (a), the reproduced effect log |
| v08 | D4 a world-only row's twin must exist | accept a missing twin | its `validate_catalogue` row |
| v09 | D4 the twin must not be world-only | accept a world-only twin | its row |
| v10 | D4 the twin's delivery constructor must match | accept a different constructor | its row |
| v11 | D4 the twin's recovery branch must match | accept a different branch | its row |
| v12 | D4 the lexical guard | disable it, then render a world-only id into one projected message | the guard's target |
| v13 | W1.4 before-dispatch `ToolFailed` → `none` | `unknown` | its renderer test |
| v14 | W1.4 after-dispatch `ToolFailed` → `unknown` | `none` | its renderer test |
| v15 | W1.4 deadline and mismatch → `unknown` | `none` for the deadline | its renderer test |
| v16 | W1.4 denial and undecodable arguments → `none` | `unknown` for the denial | the updated `denial_message` test |

Survival: the unmutated bank, the legacy fixtures and the new frozen fixture all decode and replay
clean.

**Gate:** `mutants.tsv` with every row a kill, or a survivor with a new test or a sentence.

### W1.8 — gate and records

**Gate:**
- the targets: `make check_core test_coverage seeded_generator fault_catalogue corpus_pr
  run_report world_state invariants anchors attribution_table`, then `make dst`, then
  `make eval_matrix`;
- `make dst`'s FAILED names equal the base's;
- every changed `eval_matrix` row is explained.

**Records:** the ADR's status line, and this plan's status.

---

## Phase 2 — the three properties

Own worktree and pull request, after W1. Surface: `dst_invariants.ail`,
`scripts/dst/invariants_dst.ail`, `scripts/dst/corpus_judge_dst.ail`,
`tools/verify_classify/contracts.register`, a new pair-relation runner, and the `Makefile`.
Precedent: `c0f7eb02` (3 files, two rules).

### W2.1 — properties P1 and P3 as rules

- `EffectDisclosureUnsound(ordinal, call_id)` and `ToolCallRedispatched(call_id)`, both under
  `ToolPairing` (`dst_invariants.ail:337-341`). Each needs a constructor on one line
  (`Makefile:1652-1656` counts them), a family arm (`:389`), a rule id (`:436`), a message
  (`:483`), a check appended to `tool_pairing_findings` (`:1460-1464`), and an entry in
  `sample_violations()` (`:2417-2436`).
- `== 42` → `== 44` (`:2401`); `invariant-set/2` → `/3` (`:228`).
- **Independent oracle** (ADR §2). P1 reads `x.world.log` and the effect log against the ledger's
  projected message. P3 reads the world-served log, as `dispatched_after_denial` does
  (`:1445-1458`). Neither calls `tool_outcome_message` or anything it calls.
- P1 is one-sided: `effects = none` ⇒ no effect-log entry for that call. Its second half: every
  harness-reported fault message carries `effects`.
- Fixtures in `invariants_dst.ail` with survival and rejection rows, as `c0f7eb02` did.
- `evaluate` also runs in the journal eval (`bridge.ail:43-46`, `candidate_checks.ail:131-134`).
  The new rules therefore apply there, and `make eval_matrix` is in this gate.

### W2.2 — property P2 as a pair relation

- A pair relation beside `discovery_contract_findings` (`:2265-2279`), not a family, for the
  reason at `:2189-2195`.
- Its runner takes real programs from the bank. For each tool call drawn after dispatch it builds
  the twin with that call's `applied` flipped, runs both, and compares traces, outcomes and served
  interactions.
- The only existing caller of the discovery relation is a fixture (`invariants_dst.ail:1290-1313`),
  so this needs its own runner and target.
- **It compares message contents, not record variants.** The discovery relation's
  `trace_positions` compares only `record_variant` (`dst_invariants.ail:2251-2259`). Copied
  unchanged, it would miss mutant p2, which leaks the bit into a message and changes nothing else.
- Its twins come from W1.2's world-truth list, so their served interactions are equal by
  construction (W1.2 acceptance b). Any difference the relation finds is the harness's.

### W2.3 — acceptance by mutant

A property is accepted only once its mutant has been seen red (ADR §2):

| # | Property | Mutant | Expected red |
|---|---|---|---|
| p1a | P1 | render `none` for an after-dispatch `ToolFailed` | `EffectDisclosureUnsound` on a bank member that draws one |
| p1b | P1, second half | drop `effects` from `tool_fault_message` | P1's presence check |
| p2 | P2 | read `applied` from `next_state` into the message | the pair relation, on a twin pair |
| p3 | P3 | the driver retries a call on `ToolDeadlineExceeded` | `ToolCallRedispatched` |

Hold the two rules against `make corpus_judge`'s members and controls too. 011 ADR-003 names
034's P1 and P3 as rules its gate exists for (`:39`, `:387`). Survival: the unmutated bank is
clean on all three. The evidence follows `011…/acceptance-ce9cb247/`: `predictions.tsv` hashed
before the run, and `mutants.tsv` scored on the named rule's red row, not on exit status.

### W2.4 — gate and records

**Gate:** `make invariants corpus_judge verify_classify_check`, the pair runner's target, then
`make dst` with FAILED names equal to the base's, then `make eval_matrix` with every changed row
explained.

---

## Phase 3 — the report

Own worktree and pull request, after W1, beside W2 (C4). Surface: `dst_run_report.ail`,
`scripts/dst/run_report_dst.ail`, and the `Makefile`'s `run_report` target.

### W3.1 — counters for world-only rows, and the duplicate-effect-key metric

- **What already picks the rows up:** `coverage_pair` and the row lists built from
  `fault_catalogue()` (`dst_run_report.ail:227`, `:241`, `:303-307`).
- **What does not:**
  - the branch counts are wire greps (`Makefile:1877-1895`), which would count a twin and its
    world-only row together;
  - `documented_coverage()` (`run_report_dst.ail:280-292`) is a hand list of reached classes.
- **What stays as it is.** Both new rows are `AlwaysApplicable`, so these are not touched by adding
  them:
  - `conditional == 2` (`dst_run_report.ail:895`) counts conditional classes;
  - `the_surviving_gaps` (`run_report_dst.ail:329-331`) names those two conditional classes;
  - `all_reach_ids() == 5` (`:520`) counts reach statuses, not rows;
  - the awk at `Makefile:1726-1745` counts reach-status and rejection constructors.

  *(Corrected after review finding 6.)*
- **A count of duplicate effect keys**, from the effect log. It is labelled as describing the
  generator in DST, because the scripted model is the generator. Over live or journal-derived
  sessions it is Havoc's `DESTRUCTIVE` measure (NOTE §1).

### W3.2 — mutation run

*(Added after review finding 4.)*

| # | Rule | Mutant | Expected to fail |
|---|---|---|---|
| r1 | a world-only row is counted from the effect log | count it from the typed outcome | the report test for a bank member that reaches it |
| r2 | a twin and its world-only row are not counted together | count the world-only row's interaction under its twin too | the branch-count test on the same member |
| r3 | duplicate effect keys are counted | count distinct keys | the metric's test on a fixture with one repeated key |

Survival: a fixture with no repeated key reports 0.

### W3.3 — gate and records

**Gate:** `make run_report corpus_pr`, `ailang test src/core/dst_run_report.ail`, then `make dst`.

---

## Out of scope

As ADR §3:
- measuring model honesty;
- torn or partial effects;
- the extension effect seam (`session.ail:1372`, `timeout_ms: 0`);
- delegation (`WakeOutcome`, `ports.ail:788`);
- harness-side resolution (read-back, idempotency keys);
- reclassifying live faults into typed variants;
- changing `exit_code` on a faulted result;
- extension-handled tools' `metadata` (030).

## Follow-ups this plan does not schedule

- **The AILANG pin to `>=0.54.14`**, for the process-group kill. That is 012's. W0b.2 reads its
  state.
- **The session normaliser** derives the normalised `exit_code` only from `"error":true`
  (`session.ail:2036-2039`). A faulted live `BashExec` has no `error` key, so the TUI shows it as
  done, and `tool_failures.py` counts it as exit 0. This predates the ADR. After W0, the normaliser
  could read `fault` instead. That changes the `native_tool_results` payload on the wire, so it is
  its own change.
- **The herdr extension's copy of the error mapping** calls every `ProcessError` "a spawn that
  never reached a process". Case A contradicts that. Four more copies exist in extensions and eval
  code (ADR §7).
- **A model-in-the-loop measurement** of whether `effects: unknown` changes retry behaviour. That is
  Havoc's question (NOTE §4), not a gate (ruling 5). It belongs after W0, with the operator's go
  ahead on cost. Running Havoc itself against Motoko's tool surface may be cheaper than rebuilding
  it.
- **The upstream answers.** If #1880 states that `PermissionDenied` is start-only, ruling 3 is
  revisited. If #1879 makes case A return `Ok`, the case leaves the `SpawnFailed` arm, and the
  mapping stays `unknown` for whatever remains there.

## Review

An independent review by Codex Sol (`gpt-6.1-sol`, reasoning effort xhigh) on 2026-10-17, of head
`2cf82955`. It ran in its own detached worktree, read-only, and was given none of the author's
conclusions: [`REVIEW-001-plan-001-codex-gpt-6.1-sol.md`](REVIEW-001-plan-001-codex-gpt-6.1-sol.md).
Its verdict: **merge after the listed fixes.** It re-ran both probe scripts and every result
matched.

It records one limitation of its own. The brief told it to read the diff first, and that diff
contained the PR record, so it saw the PR description before drafting. Its findings do not cite
the description. The brief's error was the author's.

| # | Finding | Reproduced by the author | Disposition |
|---|---|---|---|
| 1 | **Blocking.** W1 gave no route by which `applied` survives persistence and replay without entering the served payload. Replay rebuilds tools only from served outcome payloads, and property P2's comparison keys on the payload. | Yes. `ExecutionProgram` holds only `interactions` (`dst_program.ail:243-252`). `tools_of` decodes payloads (`dst_replay.ail:761-772`). `log_positions` keys on `outcome.payload` (`dst_invariants.ail:2242-2244`). | **Fixed in W1.2.** The stage travels in the payload. `applied` goes in a world-truth field of the program, with recording, replay, twin and version rules, and three acceptance rows. W1.3 and W2.2 follow it. |
| 2 | **Should fix.** `fault` after `exit_code` can be cut from the message by a long `cmd`, which renders first. | Yes. `cmd` precedes `exit_code` (`tool_dispatch_adapter.ail:136-142`), and the cap keeps the head. | **Fixed in W0.3.** `fault` comes right after `tool` on every faulted arm. A long-command test is added, and m14 moves to it. |
| 3 | **Should fix.** The `none` sentence said nothing ran, though read-only failures (`rg`) may have run. The `unknown` sentence said the tool started, though `PermissionDenied` almost certainly did not. | Yes, against D2 rows 4 and the `PermissionDenied` row, and `start_probe.sh` cases 15-17 and 20-21. | **Fixed in C3.** `none` now speaks of change. `unknown` no longer claims a launch. Both are pinned verbatim in W0.3's tests. |
| 4 | **Should fix.** Several stated rules had no mutant: all of W1's validators and guard, W3's counting rules, W0's kind mapping and refusal sites, and W0b's output preservation. | Yes. The graph had no W1 or W3 mutation task. | **Fixed.** W0.6 gains m16-m29, with W0.5 rows i-o to catch them. W0b.4 gains w5. There are new tasks W1.7 (v01-v16) and W3.2 (r1-r3). The gates move to W1.8 and W3.3. |
| 5 | **Should fix.** The generator cascade missed the seeded suite's `versioned` row, which hard-codes `"2"`, and the rich and equal-count fixtures. | Yes, `seeded_generator_dst.ail:1228`, `:1177-1180`, `:1224-1228`, and `Makefile:1277-1281`. | **Fixed in W1.6.** The contrast moves to a version unequal to the current one, with an asserted inequality. Both fixtures are re-swept. |
| 6 | **Minor.** W3.1 listed `conditional == 2`, the reach-status count and the awk as moving. The new rows are `AlwaysApplicable`, so none of them moves. | Yes. | **Fixed in W3.1**: those are listed as staying. |
| 7 | **Minor.** Rows e and f under root: the prose and the graph disagreed on whether an unevaluated row blocks the gate. | Yes. Nothing fails for root in `atomic_write`'s `mktemp`, `chmod` or `mv`. The directory alternative hits a non-`Result` `readFile` (`tool_runtime.ail:690`). | **Fixed in W0.5 and W0.6.** Merge acceptance needs a run as a non-root user. |
| 8 | **Minor.** ADR §7 said 31 literal `generator_version` sites, and the plan said 15. | Yes. 17 lines match: 15 in `scripts/dst`, plus `dst_generator.ail:15` and `dst_replay.ail:1135`. | **Fixed** in ADR §7 and W1.6. W1.1 separates producers from fixture literals. |

The review also confirmed that `run_process_result` drops `req.args` on its `bash -lc` arm (W0b.3
takes it up). It noted that the existing discovery relation compares record variants only, which
W2.2 now addresses.
