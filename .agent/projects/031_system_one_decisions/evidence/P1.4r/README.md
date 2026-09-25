# P1.4r evidence: truthful evidence defaults, and the decision state at decision sites

AILANG v0.33.0. Every AILANG check below ran in a throwaway workspace (P1.1's method, reused through
P1.3r's `p13r_check.sh`). No check ran in a clone, so the `ailang.lock` trap does not apply.
HEAD before: `f21e508d`.

## What changed

- **`src/core/ext/runtime.ail`, the cursor (line R).** Each `DecisionSolverJudge` / `DecisionToolPolicy`
  atom's `prepare` and `interpret` now receive `decision_view(base, ext_id, site, descriptor)`: the
  ordinary view with `decision_state = Some(decision_invocation_state(...))`, built from **that atom's
  own descriptor**. The next atom, declared or legacy, gets the ordinary view back. The fields:

  | field | value under R | why it is truthful |
  |---|---|---|
  | `invocation_id` | `"<owner>/<site>/<local_id>"`, e.g. `completion_guard#0/finalize/example.completion_guard` | D6's identity: registered owner, site, local ID. Line X adds the occurrence |
  | `mode` | `EnforcingDecision` | under R the cursor applies every vote through the family merge. Nothing is substituted for shadow and nothing is skipped as disabled |
  | `interventions_used` | `0` | no counter exists before line X's host state (D5) |
  | `intervention_limit` | descriptor `max_interventions` | there is no operator limit on R, so the lower of the two limits is the descriptor's |
  | `question_config`, `interpretation_config` | the descriptor's, byte for byte | D3's "two configuration values handed back" |
  | `allowance`, `known_spend`, `outstanding`, `run_cost` | `0` | no allowance is granted. The stub arm contacts no provider and reports zero usage |
  | `run_cap_millicents` | `None` | this is the Option's zero. D5 `:673` allows `Some(cap)` only for a metered run with `max_cost_millicents > 0`, so `Some(0)` is not a value this term can take. No cap is claimed |

- **`entry_base` (the ordinary view) now resets `decision_state` to `None`**, whatever the host's
  context carries. D3's rule that other hook sites receive `decision_state = None` is enforced in the
  runtime instead of being a promise each host literal has to keep.
- **`src/core/session.ail`**: one test at the end of the file, so no anchor moves. It builds
  `mk_v2_ext_ctx` and checks `NotReached`, the empty and incomplete window with an unknown omitted
  count, and `None`. `noop_ext_ports` is on the existing import line.
- The six host literals were already line-neutral from P1.1 and are unchanged. They are proved by the
  fixtures below.

## Fixtures (exit 2)

| variant | where | shows |
|---|---|---|
| ordinary | `runtime.ail` `ordinary_sites_see_truthful_defaults_test` | the host literal (`smoke_ctx`) and every ordinary view from it (prompt shaper, legacy tool policy, legacy judge `ProcessCtx`, work declarer `FsCtx`) show `not_reached \| empty:incomplete:unknown \| none` |
| ordinary | `ordinary_sites_see_none_whatever_the_host_carries_test` | with the host carrying a foreign `Some` (non-zero ledger), ordinary sites still see `None` |
| ordinary | `session.ail` `mk_v2_ext_ctx_carries_truthful_evidence_defaults_test` | the real per-turn host context |
| ordinary | `literal_defaults.py` (static) | all six host literals (session 2, rpc 3, runtime 1) and `empty_tool_evidence`. It covers the sites inside effectful drivers that no cheap test reaches |
| `DecisionSolverJudge` | `decision_solver_judge_sees_its_own_state_test` | two extensions with descriptors that differ in every field, and a foreign host state. Immediate path (`prepare`) and query path (`prepare` and `interpret`) each see their **own** identity, limit and byte-equal projections, with every ledger term zero. A legacy judge behind the declared atom in the same extension sees `None` |
| `DecisionToolPolicy` | `decision_tool_policy_sees_its_own_state_test` | the same checks, with the descriptors swapped between the extensions, so the state follows the atom and not its position |
| both | `both_families_in_one_extension_see_their_own_state_test` | each family's atom sees its own descriptor at its own site |

`RUNTIME-TEST.log`: runtime **36/36** (P1.3r's 31, plus 5). `SESSION-TEST.log`: session **41/41**.
`LITERAL-DEFAULTS.log`: ok.

## End to end, P0.6's consumers (exit 3), `E2E.log`

`cursor_e2e.ail` is P1.3r's runner changed so that the **host context carries `decision_state: None`**.
Every check goes through the dispatcher:

- The votes are unchanged from P1.3r. Dispatched alone: `NoDecision` / `NoOpinion`. With a legacy atom
  behind: `Accept` / `Pending(next atom ran)`. The successor world is untouched and the clock tripwire
  is never read.
- The state handed to each consumer: `Some(<owner>/<site>/<local_id>)`, `question_config` and
  `interpretation_config` byte-equal to the registration's disclosed config, limit its own, ledger
  zero, enforcing.
- The consumer's own `prepare`, dispatched, queries with the binding from its `question_config`:
  `JudgeQuery(completion-judge)` and `ToolQuery(repeat-failure-judge)`.
- The consumer's own `interpret`, dispatched with the stub's observation replaced by a scripted
  `Answered`, **reads `interpretation_config` from the state it is handed**. The default threshold
  intervenes (`ContinueWithFeedback` names "6000 bp"; `Deny`). A registration with a threshold on the
  other side of the answer abstains (`min_complete_bp 1000` gives `NoDecision`; `deny_min_bp 9500`
  gives `NoOpinion`).

P1.3r's own `p13r_check.sh e2e` still passes on this tree. Its host `Some` is now replaced by the
cursor's, and the two carry the same values.

## Anchors (exit 4)

`make anchors` exit 0 and `make driver_leaf_inventory` exit 0. Both outputs are **byte-identical** to
the run at `f21e508d` before any edit (`ANCHORS.log`, `DRIVER-LEAF-INVENTORY.log`). The runtime
changes sit below `:199`, and new import names are on line 25. The session test is at the end of the
file.

## mutgate (exit 5)

`p14r_mutgate.sh` is P1.3r's runner, re-pointed. It runs over `p14r_mutgate_spec.tsv` in a copy,
with repo-relative paths. The result is in `mutgate-result.tsv` (run log `MUTGATE.log`): **34/34 discriminate**. The brief's rows:

- default `verification = Passed`: tested in the runtime literal, the session literal and an rpc
  literal
- `complete_from_session_start = true`
- a decision site handed `None`: both families, unit and e2e
- a projection taken from another descriptor: both families, plus the crossed projections
- each of the five ledger terms non-zero, including `run_cap = Some(0)`

Further rows cover identity, mode, limit, counter, `entry_base` passing the host's state through, a
decision view leaking to the next atom, and the static rules. P1.3r's `judge_interpret_other_request`
row no longer matches, because the interpreter is now handed `dview`. It is carried forward here with
the new line.

## Core check (exit 1), `CORE-CHECK.log`

All tracked `src/core` modules: **71/72**. The one failure is `src/core/test/integration_tests.ail`.
It imports `pkg/sunholo/motoko_ext_compaction_structural`, a package the workspace does not include
(still 7.4 at HEAD). This is P1.1's and P1.3r's failure, unchanged.

## Not run

- `make check_core` and `make test` are R-G's and cannot pass on the red tree.
- `make dst`: the brief says not to run it.
