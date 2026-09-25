# RECORD-SWEEP — `make dst DST_JOBS=1` at HEAD (PLAN-001 (031) §2 `SWEEP`)

Date: 2026-09-20. Task: `SWEEP`, PLAN-001 (031) v1.1 §2, release line R. Kind: heavy run, record only.
No commit, no source edit. Brief: `LEG-SWEEP.md`.

## Grounding

| item | value |
|---|---|
| branch | `arniwesth/031-abi-8-0` |
| HEAD | `75fefdcb1e2ef0197e64b39047ab2ae31147e31c` |
| `git diff --stat 2062605 HEAD -- src/ packages/ tools/ scripts/ Makefile` | empty (code tree byte-identical) |
| working-tree modifications under `src/ packages/ tools/ scripts/ Makefile` | none tracked; three untracked files present (below) |
| AILANG | `v0.33.0`, commit `ae36986c5c0a1e8ad4f0fc1e607efddefbbae46a` (the pin) |
| extension ABI | `7.4` (`packages/motoko-ext-abi/ailang.toml`) |
| command | `make dst DST_JOBS=1` (repo root, one invocation, unmodified `DST_TARGETS`) |
| started / ended (UTC) | `2026-09-20T18:23:21Z` / `2026-09-20T18:51:27Z` |
| wall clock | `1686s` (`sweep_summary.sh`: `1686s wall, -j1, load 4.20 3.59 3.00`) |
| `DST_JOBS` | `1` |
| run exit code | `2` (`make: *** [Makefile:705: dst] Error 2`) |
| log | `.agent/projects/031_system_one_decisions/evidence/SWEEP-2026-09-20.log` (3,920,391 bytes, copied from `.ailang/dst-last.log`) |

Untracked files present during the run, none of them tracked code:
`scripts/dst/mem_canonical_bench.ail`, `scripts/dst/mem_growth_probe.ail`,
`src/eval/journal/testdata/MATRIX.tsv`. No `DST_TARGETS` member globs `scripts/dst/*.ail`;
`test_coverage` walks `--root src/core` only (`tools/test_coverage/derive.py:732`, `:481`).

## Concurrency during the run — the branch tip moved, the sweep did not

**This sweep is a snapshot at `75fefdcb`.** The branch tip moved while it was running: commit
`9e8722566b5b1d44857805162e74fe35fc4debef` ("ADR-001 (031) P0.2: boundary probe suite …") was made at
`2026-09-20T18:45:09Z`, inside the run window (`18:23:21Z`–`18:51:27Z`), by another delegate. It added 55
files (54 under `scripts/dst/fixtures/adr001_boundary/`) and grew
`scripts/dst/run_declared_vs_performed.sh` from 1299 to 1689 lines.

Recorded because a heavy run over a moving tree is not comparable. Evidence that this one was not
affected:

1. The only `DST_TARGETS` member that reads either changed path is `declared_vs_performed`. Its output
   sits at log lines `319`–`472` — the first 5% of a 9878-line log, minutes before `18:45:09Z` — and it
   ran against the **pre-P0.2** script: `declared_vs_performed: 63 passed, 0 failed` (`:472`), with
   **zero** occurrences of `adr001` or `fb_30e82f6bdc5fc8c3` anywhere in the log. P0.2's rows are absent,
   so the old 1299-line script is what executed.
2. The new fixtures are consumed only by `run_declared_vs_performed.sh` and by P0.2's own
   `adr001_boundary_provenance.py` / `adr001_boundary_mutgate_spec.tsv`, none of which is a
   `DST_TARGETS` member.
3. Both unexplained reds are at log lines `1218` and `2959` of `9878` — the first third of the run, well
   before the commit landed.

So the `head:` this sweep reports is `75fefdcb`, the tree it actually ran, and the two reds below are
properties of that tree. **A reader comparing this record against the branch tip must re-ground:**
`git diff --stat 2062605 9e872256 -- scripts/` is no longer empty.

## Exclusivity and memory (PLAN-004 §0 item 2)

No other heavy run was in flight at start (`pgrep` showed only agent-session launchers
`make claude`, `make codex`, `make motoko` and the supervisor process; no `make dst`).
`memory.current` sampled every 15 s for the run, 112 samples:

| | bytes | GiB |
|---|---|---|
| at start (baseline, shared cgroup) | 7,165,898,752 | 6.67 |
| peak during the run | 9,764,143,104 | 9.09 |
| cgroup `memory.max` | 25,769,803,776 | 24.0 |

Peak stayed under the 12 GiB `memory.current` rule. No cgroup trip, no monitor gap.

## Per-target results (all 51 requested targets, passes included)

Exit code is make's own verdict: a target with a `make[1]: *** [Makefile:<line>: <target>] Error <n>`
line in the log failed with `<n>`; a requested target without one completed `0`. The log contains no
`not remade because of errors`, no `Nothing to be done` and no `No rule to make target`, so every
requested target was attempted — `skipped: 0`.

The fourth column is the line `scripts/dst/sweep_summary.sh` prints for that target. It prints
per-target lines only for failures and for `DST_KNOWN_RED` members that passed; `—` means the script
printed no line for that target.

| target | exit | result | `sweep_summary.sh` line |
|---|---|---|---|
| `corpus_pr` | 0 | pass | — |
| `test_coverage` | 0 | pass | — |
| `declared_vs_performed` | 0 | pass | — |
| `terminal_trace` | 0 | pass | — |
| `smoke_parity` | 0 | pass | — |
| `profile_definition` | 1 | **FAIL** | `profile_definition    NEW — this one is yours` |
| `smoke_driver` | 0 | pass | — |
| `strict_replay` | 0 | pass | — |
| `world_state` | 0 | pass | — |
| `corpus_rotating` | 0 | pass | — |
| `driver_plus_compose` | 0 | pass | — |
| `driver_plus_herdr` | 0 | pass | `NOTE: driver_plus_herdr is listed in DST_KNOWN_RED but PASSED.` |
| `driver_only` | 1 | **FAIL** | `driver_only    NEW — this one is yours` |
| `seeded_generator` | 0 | pass | — |
| `event_vocabulary` | 0 | pass | — |
| `phase_c_l1` | 0 | pass | — |
| `recorded_stream` | 0 | pass | — |
| `driver_plus_no_ops` | 0 | pass | — |
| `ext_hook_scope_selftest` | 0 | pass | — |
| `invariants` | 0 | pass | — |
| `run_report` | 0 | pass | — |
| `discovery` | 0 | pass | — |
| `program_persistence` | 0 | pass | — |
| `compaction_dst` | 0 | pass | — |
| `fault_catalogue` | 0 | pass | — |
| `ext_ambient_inventory_selftest` | 0 | pass | — |
| `ext_ambient_inventory` | 0 | pass | — |
| `ext_call_inventory` | 0 | pass | — |
| `ext_call_inventory_selftest` | 0 | pass | — |
| `conformance` | 0 | pass | — |
| `stream_parity` | 0 | pass | — |
| `latency_pair` | 0 | pass | — |
| `test_coverage_selftest` | 0 | pass | — |
| `execution_program` | 0 | pass | — |
| `attribution_table` | 0 | pass | — |
| `profile_coverage` | 0 | pass | — |
| `compose_live_exec` | 0 | pass | — |
| `ledger_parity` | 0 | pass | — |
| `dst_seeded` | 0 | pass | — |
| `hook_guard` | 0 | pass | — |
| `dst_l2` | 0 | pass | — |
| `predicate_anchors` | 0 | pass | — |
| `depth_canary` | 0 | pass | — |
| `registry_multiplicity` | 0 | pass | — |
| `driver_leaf_inventory` | 0 | pass | — |
| `driver_leaf_inventory_selftest` | 0 | pass | — |
| `herdr_graded` | 0 | pass | `NOTE: herdr_graded is listed in DST_KNOWN_RED but PASSED.` |
| `journal_resume` | 0 | pass | — |
| `world_framed_wire` | 0 | pass | — |
| `park_wake` | 0 | pass | — |
| `park_resume` | 0 | pass | — |

**Totals: requested 51, passed 49, failed 2, skipped 0.**

## Closing summary, verbatim

```
─── make dst ──────────────────────────────────────────────────────────
  1686s wall, -j1, load 4.20 3.59 3.00
  full log: .ailang/dst-last.log

  FAILED (2):
    driver_only                  NEW — this one is yours
    profile_definition           NEW — this one is yours

  NOTE: driver_plus_herdr is listed in DST_KNOWN_RED but PASSED.
        Drop it from that list in the Makefile — an expected-failure
        list that outlives the failure teaches the next reader to
        ignore a real one.

  NOTE: herdr_graded is listed in DST_KNOWN_RED but PASSED.
        Drop it from that list in the Makefile — an expected-failure
        list that outlives the failure teaches the next reader to
        ignore a real one.

  exit 2 — make's "errors were encountered". See the NEW rows above.
───────────────────────────────────────────────────────────────────────
make: *** [Makefile:705: dst] Error 2
```

## Register comparison

Register: `DST_KNOWN_RED := driver_plus_herdr herdr_graded` (`Makefile:697`).
Per PLAN-001 §0 item 2 and PLAN-004 §0 item 1 the register is a register, not evidence of this sweep's reds.

| red this run | in register? | verdict |
|---|---|---|
| `profile_definition` | no | **NOT explained by the register** |
| `driver_only` | no | **NOT explained by the register** |

Reverse direction, as `sweep_summary.sh` reports it (both were requested this run, so the check is on
evidence and not on absence):

| register entry | this run | note |
|---|---|---|
| `driver_plus_herdr` | **passed** | script instructs: drop from `DST_KNOWN_RED`. Not this task's edit. |
| `herdr_graded` | **passed** | script instructs: drop from `DST_KNOWN_RED`. Not this task's edit. |

Separately: `sweep_summary.sh`'s header comment (point 3) states that `test_coverage` and
`test_coverage_selftest` "have been red since D22". Both **passed** this run (exit `0`, no make error
line). The comment is stale as of this HEAD. Recorded, not edited.

## The two unexplained reds

Not diagnosed here and not repaired here (`LEG-SWEEP.md`: a red not explained by the register blocks
P0.4 until the operator rules). Both targets terminated on the same assertion, quoted verbatim from
the log.

### `profile_definition` — exit 1, `Makefile:833`

Log `.agent/.../SWEEP-2026-09-20.log:1218-1222`:

```
  ✓ the ABI version every profile record's prose names is the one the package declares: 7.4 (4 site(s) across 7 file(s))
FAIL: packages/motoko-ext-abi/ailang.toml declares ABI 7.4, and these pin something else:
  src/eval/journal/admission.ail: pinned '7.3'

A manifest whose whole job is exact reproducibility pins a contract this tree does not have. These are inert metadata strings — no assertion reads them and no digest covers them (`trajectory_key` digests interactions only) — so the repair is to set each to 7.4.
make[1]: *** [Makefile:833: profile_definition] Error 1
```

The target's own inner harness line printed `profile_definition_dst PASS` earlier in the same block
(`:1191`); the failing assertion is the later ABI-pin scan, not the DST harness.

### `driver_only` — exit 1, `Makefile:1344`

Log `:2959-2963` — the identical assertion and the identical named site:

```
  ✓ the ABI version every profile record's prose names is the one the package declares: 7.4 (4 site(s) across 7 file(s))
FAIL: packages/motoko-ext-abi/ailang.toml declares ABI 7.4, and these pin something else:
  src/eval/journal/admission.ail: pinned '7.3'
...
make[1]: *** [Makefile:1344: driver_only] Error 1
```

`driver_only_dst PASS` likewise precedes it (`:2933`).

The named site, quoted uninterpreted, for the operator's ruling. `src/eval/journal/admission.ail` is
tracked and unmodified in the working tree, and is byte-identical to `2062605`, so the condition is
pre-existing at this HEAD and was not introduced by this branch's document commits:

```
src/eval/journal/admission.ail:993
      (tx_first(RealEntry, { i | abi_version: "7.3" }, c), "A9b:AbiVersionDiffers@aggregate:provenance:abi_version"),
```

No further analysis is offered and no repair was attempted: `SWEEP` records, the operator rules.

## Could not run

Nothing. All 51 requested targets were attempted; the full `DST_TARGETS` list was used unmodified; no
`-k`/`-j` override and no subset substitution.

## Verdict

**P0.4 is BLOCKED.** Two reds — `profile_definition` and `driver_only` — are not explained by
`DST_KNOWN_RED`. Per PLAN-001 §0 item 2 they block P0.4 until the operator rules.

The register additionally needs the operator's attention in the reverse direction: both of its entries
passed this run, and `sweep_summary.sh` asks for them to be dropped.
