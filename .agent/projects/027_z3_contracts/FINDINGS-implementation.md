# Findings from implementing the plan

Date: 2026-08-29. Branch: `arniwesth/mot-130-contract-adoption-for-srccore-honest-gate-computed`
(MOT-130), cut from `origin/main_dst` at `8298370`.

A separate file rather than edits to the ADR, the PLAN or the RESEARCH note: those record what
was decided and what was measured beforehand, and rewriting them to match what shipped would
destroy the only record of where the plan was wrong. Each finding below is a measurement taken
during implementation, in the order it was hit. The convention is RESEARCH §3 E4's — record the
correction, keep the original.

Baseline re-measured before any edit and matching the plan exactly: `make verify_core` reported
`2 with contracts, 0 failed, 51 without`; `tool_runtime.ail` 4 verified; `compress.ail` 2 skipped
with `no ensures clause`; `agents_md.ail` `no functions with contracts`.

---

## F1 — The 027 documents were already on `main_dst`; the handoff's seeding step is void

HANDOFF Step 0.4 says the four documents live only on `arniwesth/mot-129-extension-abi-phase-a`,
that `6a915527` is not an ancestor of `main_dst`, and that they must be restored with
`git checkout 6a915527 -- .agent/projects/027_z3_contracts/`. PR #177 merged that branch in the
interval, so at `8298370` all five documents are tracked on `main_dst` and `6a915527` *is* an
ancestor. Local `main_dst` was also in sync with the remote, not 120 commits behind. Nothing was
seeded and nothing was cherry-picked.

## F2 — `compress_output` cannot carry its bound: `std/string.split` is unencodable

PLAN P2 says "Do the same sweep for `compress_output`'s bound" and its *Done when* is
`compress.ail (2 proven)`. That does not hold, and the reason is mechanical:

```
⚠ SKIPPED compress_output
  Reason: Function "compress_output" uses an unencodable builtin: std/string.split
```

`compress_output` reaches `split` and `join` before it reaches `truncate_with_suffix`, so the
whole body is out of fragment. The `pure func` promotion and the `ensures` are kept anyway: the
contract lands in P0's `blocked` bucket, which is reported and does not fail, and it is not inert
(see F4). `compress.ail` therefore reports `1 proven, 1 blocked`.

This is the same failure mode E4 retracted about itself — generalising from one measured case to
a second, unmeasured one. E4 measured `truncate_with_suffix`; the plan extended the verdict to
`compress_output` without running it. Recorded here rather than in RESEARCH because the
measurement is new, not because the earlier one was wrong.

## F3 — The provable bound is `<= max_chars`, tighter than the planned `max_chars + 15`

PLAN P2 and RESEARCH E4 both carry `ensures { _str_len(result) <= max_chars + 15 }`, which was
the scratch experiment's form. The body's actual invariant is stronger: the longest branch is
`_str_slice(text, 0, max_chars - 24)` followed by a 16-character suffix, so the result never
exceeds `max_chars - 8`. What shipped:

```ailang
ensures { _str_len(result) <= max_chars }        -- ✓ VERIFIED truncate_with_suffix [17.9ms]
```

This is the bound callers actually rely on and the one `compress_truncates`'s test already
asserted by example (`_str_len(out) <= 30` for `max_chars = 30`). The looser form would have
verified while permitting a result longer than the caller asked for.

## F4 — An `ensures` also becomes a generated property test, which changes what `blocked` costs

Not recorded in any of the three documents, and it matters for ADR §3's argument. `ailang test`
derives a property test from each contract and runs it against generated inputs:

```
✓ truncate_with_suffix_property_2  (100 cases)
✓ compress_output_property_2       (100 cases)
✓ is_root_property_1               (100 cases)
✓ has_shell_tokens_property_1      (100 cases)
✓ is_absolute_path_property_1      (100 cases)
✓ starts_with_root_dir_property_1  (100 cases)
```

So a `blocked` contract is not dead weight awaiting a solver: it is randomly checked at test
time, just not proved. That strengthens ADR §3's decision that `blocked` must never fail the
build — writing a contract the fragment rejects still buys checking — and it is why
`compress_output` and `shell_tokens_in_process` keep contracts they cannot prove.

Two contracts get no generator and are skipped rather than run (`isSome`, `is_native_backend`,
and now `shell_tokens_in_process`, whose argument is a record). `make test_coverage` already
accounts for that class of skip, so the count moved from 2 to 3 without going red.

## F5 — `is_absolute_path` does have a substantive contract; the restatement was not the ceiling

PLAN P5 step 3 allowed for either outcome: "Replace `is_absolute_path`'s restatement with a
substantive contract if one exists; if it does not, leave the restatement." One exists.

```ailang
ensures { (not startsWith(path, "/") || result)      -- recall
       && (not result || contains(path, "/")) }      -- precision
```

The pair does not reconstruct the body, which is the trap a recall/precision split invites: a
body of `contains(path, "/")` satisfies both and is a different function, so the contract admits
answers the body would not give. Confirmed with ADR §1's two probes rather than by argument —
`taut_is_absolute_path` VIOLATION, `det_is_absolute_path` VIOLATION, so **substantive**. The
recall half still catches E6's row-4 regression (body edited to `startsWith(path, "\\")`) with
counterexample `path = "/"`, so nothing that made the restatement worth keeping was given up.

This retires the last `spec-equals-body` entry in `src/core/`. ADR §1's "waypoint, not a resting
place" now has no occupants.

## F6 — New worst-case solve time: 80.6ms, and still no tail

RESEARCH E7 and PLAN Q2 record 73ms (`root_implies_slash`) as the worst contract measured
anywhere, and PLAN Q2 flags the unmeasured tail as the one result that would change P4's
viability. Measured on the contracts that shipped:

| Contract | Solve time |
|---|---|
| `starts_with_root_dir` (9 prefixes + precision) | **80.6ms** |
| `truncate_with_suffix` (string slice arithmetic) | 17.9ms |
| `is_root` | 15.6ms |
| `normalize_range` | 15.7ms |
| `has_shell_tokens` (8 tokens, recall) | 9.9ms |
| `is_absolute_path` | 10.9ms |
| `isSome`, `is_native_backend` | ~10ms |

The 80.6ms case is the same shape as E7's 73ms one and is the new ceiling. Nothing timed out, and
`truncate_with_suffix` — the `_str_slice` arithmetic PLAN Q2 named as the plausible tail — solves
in 17.9ms. Eight contracts total ~0.17s of solving, so the per-module fixed overhead conclusion
from Q2 is unchanged. This is not proof that no tail exists; it is the tail still not having
appeared after doubling the contract count.

## F7 — `verify_core` was advisory in CI, so P0's ratchet read nothing

Not mentioned in the ADR, the PLAN or the RESEARCH note. `.github/workflows/verify-extensions.yml`
ran the target under `continue-on-error: true`:

```yaml
- name: verify_core (advisory)
  continue-on-error: true
  run: make verify_core
```

ADR §3 decides that the `unstated` half "fails the build" and PLAN P0 step 4 makes flipping it a
same-commit ratchet. Neither is true of anything if the only consumer discards the exit code. The
flag came off in its own commit, separable from the rest of the plan, in the change that also gave
the target something true to report. `blocked` never fails, so the enforcing gate is green on the
tree as it stands.

## F8 — Where the plan's phases landed

| Phase | Status | Note |
|---|---|---|
| P0 | done | `unstated` / `blocked` split, reasons printed, flip verified both ways (exit 2 vs exit 0) |
| P1 | done | `is_root` VERIFIED; both dead `@verify` predicates deleted |
| P2 | done, one deviation | F2: `compress_output` is `blocked`, not proven |
| P5 | done, better than planned | F5: `is_absolute_path` upgraded rather than left as a restatement |
| P3 | done | register generated and pinned; check tested in all four directions |
| P4 | **does not land** | F9: precondition 1 is out of reach, precondition 2 targets dead code |

## F9 — P4 does not land: touched-file scoping needs the loop state the codebase refuses to add

ADR-001 §5 makes touched-file scoping a precondition, and PLAN P4 says to stop and report
rather than absorb it if it is larger than the rest of the plan. It is. Measured rather than
estimated:

- DP7 runs `rt.verification.command` as an opaque shell string
  (`session.ail:1803`: `exec("bash", ["-c", "cd \"$1\" && ${rt.verification.command} 2>&1", ...])`).
  There is no file list anywhere on that path -- nothing in `session.ail`, `step_machine.ail`
  or `types.ail` tracks touched, changed, or written files.
- The design doc says where the list would have to live:
  `m-motoko-dp7-verifier-gate.md` §"Touched-files tracking (v2)" -- "track WriteFile/EditFile
  paths **in the loop state** and only re-check touched files. Deferred."
- `c2_loop` has **16 recursive call sites**, and the codebase already declines to add loop
  state for exactly that reason: the persist-nudge helpers count markers out of the message
  history rather than thread a counter, "no new loop_v2 state to thread through its 16
  recursive call sites" (`session.ail`, above `persist_nudge_marker`).

So scoping means a new field on `C2LoopState` threaded through 16 call sites, write-path
plumbing to populate it, and a changed contract for `verification.command` so a file list can
be passed to `make`. That is larger than P0, P1, P2, P3 and P5 combined, and it reaches well
outside this branch's fence. Reported, not absorbed.

## F10 — ADR §5's second precondition targets dead code

ADR-001 §5 and RESEARCH §4.7 both name `session.ail:1825-1826` -- "The code you just wrote
does not type-check" -- as the message that would misdiagnose a Z3 violation or timeout as a
type error, and require fixing it before `verify_core` rides along.

That string is in `dp7_gate`, which **has no call sites**:

```
$ grep -n "dp7_gate" src/core/*.ail src/core/**/*.ail
src/core/session.ail:1816:func dp7_gate(...)          <- the definition, and nothing else
```

The live path is `dp7_rejection_errors` -> `c2_after_dp7` (`session.ail:2222`), which puts the
verifier's output into `last_response_text` and a `Dp7VerifierRejected` ledger event. It never
constructs the "does not type-check" sentence.

The precondition is therefore not satisfiable as written -- editing a string nothing reads
changes nothing, and deleting dead code is a different change from this one. Whoever picks P4
up should re-aim it: establish where the live path surfaces the rejection to the model, and
make *that* distinguish a type error from a contract failure. Left untouched here rather than
"fixed" in a way that would look done and check nothing, which is the failure mode this whole
project is named after.

## F11 — ADR §5's third precondition is already satisfied by the register

"A contract silently dropping from VERIFIED to SKIPPED must be red, or the gate can weaken
without failing." It is red. A contract that stops verifying computes `unclassified` instead
of `substantive`, and `verify_classify_check` fails on the difference: as a *relabel* if the
contract and body text are unchanged (the mechanism demonstrated directly -- hand-editing
`isSome`'s pinned class produces "pinned as substantive but the solver computes tautology"),
or as a *stale pin* if the text moved. Both exit 1.

Stated as reasoning from the demonstrated mechanism rather than as its own measurement: the
relabel direction was tested by editing the register, not by engineering a real
VERIFIED-to-SKIPPED regression.

## F12 — What the honest report looks like now

ADR-001 predicted the first honest report would look *worse* than the false green it replaced:
"2 files with contracts and 4 proven becomes roughly 1 substantive, 1 unstated, 2 tautologies
and 1 restatement". It did, and then the work moved it:

| | before | after |
|---|---|---|
| gate line | `2 with contracts, 0 failed, 51 without` | `8 contracts proven, 0 unstated, 2 blocked; 0 files failed, 50 bare` |
| substantive | 1 | **6** |
| tautology | 2 | 2 |
| spec-equals-body | 1 | 0 |
| unclassified | 0 | 2 |
| falsified by a mutation test | 0 | 2 |
| enforced in CI | no (`continue-on-error: true`) | yes |

The two tautologies are `isSome` and `is_native_backend`, both `result == true || result ==
false` over a `bool` -- they share a contract hash in the register, which is the clearest
possible statement of what they are worth. They are permitted, registered, and counted as
zero.
