# P1.3r-a2 evidence: the conformance harness out of production core

AILANG v0.33.0. HEAD before: `e9212412` (then `d83b8d63` landed, which only adds briefs and leaves `src/core` untouched; the mutgate clone ran on it). Every AILANG check ran in a throwaway workspace
(P1.1's or P1.2c's method), never in a clone, so the `ailang.lock` trap does not apply.

## The change

- `src/core/ext/runtime.ail`: removed `import pkg/sunholo/motoko_ext_conformance/harness
  (neutral_registration)` at `:40`. The line is **blank again**, byte-identical to P1.3r's parent
  `a7aa68a8` at that line, so the `:199` anchor holds without a placeholder. The one test that
  used the import (`neutral_registration_is_neutral_through_the_cursor_test`) is removed and
  replaced by a three-line pointer comment. The older `motoko_ext_conformance/invariants` import
  (`validate_compactor_output`, used in production) is untouched.
- `src/core/test/ext_neutral_registration.ail` (new): the same test, with the same assertions
  (tool vote `noop;`, judge vote `noop;`, successor token == `clear_holder(w).token`). runtime.ail's
  test helpers are private, so the module carries copies of `smoke_ctx`, `stamp_rt`, `probe_call`
  and the two tag functions. Only tests import this module.

| file | what it is |
|---|---|
| `BASELINE-TEST.log` | HEAD `e9212412`: `ailang test runtime.ail`, **36/36** |
| `TEST.log` | after: runtime.ail **35/35**, ext_neutral_registration.ail **1/1** (36 = 35 + 1) |
| `CORE-CHECK.log` | `p11_core_check.sh check`, every tracked `src/core` module plus the new one: **72/73** |
| `PROBE.log` | the P1.2c collision probe on a cold cache: **clean** |
| `ANCHORS.log` | `make anchors`, `make driver_leaf_inventory`: exit 0, output byte-identical to a HEAD clone |
| `p13ra2_probe.sh` | the cold-cache probe runner (P1.2c's `p12c_core_check.sh` plus three marked changes) |
| `p13ra2_count.sh` | the count check: runtime.ail 35/35 and the new module 1/1, exactly |
| `p13ra2_mutgate_spec.tsv`, `p13ra2_mutgate.sh`, `mutgate-result.tsv`, `MUTGATE.log` | mutgate (013) from a fresh clone |

## Exit checks

1. **Cold-cache probe clean.** `p13ra2_probe.sh` builds P1.2c's workspace in a fresh `mktemp -d`
   directory, with src/core taken from the cwd. It copies `min_collision.ail` to
   `scripts/p12c/`, and **before the check it asserts that no `.ailang` compile-cache directory
   exists anywhere in the workspace**. The only one allowed is the empty run-artifact dir that the
   P1.2c script itself creates. `~/.ailang/cache` holds only the package registry cache
   (`registry/`), so nothing else is warm. Result: `check scripts/p12c/min_collision.ail ok`, rc 0.
   One earlier attempt ended with exit 143 (SIGTERM, no type error printed). It ran while the
   73-module core check was running in parallel. The rerun on its own passed. The regression
   itself is shown red by mutgate row `harness_import_readded`.
2. **src/core on 8.0: 72/73.** The one failure is `src/core/test/integration_tests.ail`: its 7.4
   `compaction_structural` import is not in P1.1's workspace, the same failure as P1.1 and P1.3r
   (71/72 there; +1 is the new module). **Tests: 36 before, 35 + 1 after.** All pass, and no
   assertion was changed.
3. **Anchors neutral.** Both targets exit 0, and their output is byte-identical (`cmp`) to the
   same targets run in a `git clone --shared` of HEAD.
4. **mutgate**: see `mutgate-result.tsv`.
   - `harness_import_readded`: the import is put back on line 40, and the cold-cache probe
     must go red.
   - `moved_test_dropped`: the moved test's `tests` clause is deleted, so `ailang test` no
     longer runs it, and the count check must go red.
   Run: `p13ra2_mutgate.sh --overlay` (a `git clone --shared` of HEAD plus this part's paths
   from the working tree). For intake after commit, use `p13ra2_mutgate.sh --clone-from <repo>`.
   `test_cmd`s log to files and grep the files. Nothing uses `cmd | grep -q` under pipefail.
