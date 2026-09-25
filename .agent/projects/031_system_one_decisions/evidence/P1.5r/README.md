# P1.5r evidence — manifest ABI pins to 8.0, the named fixture exemption, two ABI text probes

PLAN-001 (031) line R. HEAD before: `031c0f16`. AILANG `v0.33.0`. Outputs: `CHECKS.log`; mutgate record:
`mutgate-result.tsv`.

## What changed

1. **Pins.** Recounted at HEAD with the sweep's own two regexes: **32 pins in 25 tracked `.ail` files**:
   31 at `7.4`, and one `7.3`. All **31 moved to `8.0`**, each at the regex's match position, nothing else on
   the line. One coupled literal the sweep cannot see was moved with them: `admission.ail:1058`
   `m.abi_version == "7.4"` asserts `manifest_of(tx_ids())` carries `tx_ids()`'s pin (`:937`), so it follows
   that pin. Left as they were: the JSON decoder inputs at `admission.ail:1068-1070`, which
   `test_m9_decoders` never compares with an ABI version.
2. **The exemption.** `tools/profile_definition/check_fixtures.py`: rule 2 (the pin sweep) is now
   `check_abi_pins(live)`, still called from `check_abi_version()` as before, and it reads a named list,
   `ABI_PIN_EXEMPTIONS`, of `(file, anchor, reason)`. Its one entry is `admission.ail` plus the anchor
   `A9b:AbiVersionDiffers`, which is text on the literal's own line (the finding the fixture expects), not a
   line number. Two guards keep it from loosening the sweep: each entry must match **exactly one** pin, and
   that pin must **still differ** from the live version. Either failure is red. The `pins == 0` and
   `< 50 files` guards are unchanged. The drift message now says a manifest pin is repaired by setting it to
   the live version and a literal built to differ must not be. The output names the exempted site.
   `--abi-pins` is a new flag that runs rule 2 alone, without `derive()`.
3. **Probes.** `scripts/dst/run_declared_vs_performed.sh`, BudgetShaper's payload row (was `:124`, now
   `:128`) greps `BudgetShaper((PureCtx, BudgetPlan)`, and Compactor's slot row (was `:707`, now `:715`) greps
   `Compactor((AiCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace})`. What each one asserts is unchanged: the
   first requires no `!` on the row, and the second requires the row to be exactly `{AI, IO, Trace}`. Each
   block now sits between `>>> / <<< P1.5r probe:` marker comments, so `run_abi_probes.sh` can slice it out
   and run it.

## Which checks compile AILANG (the `ailang.lock` trap)

- The pin sweep is Python and the probes are `grep`. Neither compiles AILANG.
- The A9b test is `ailang test src/eval/journal/admission.ail`, and it does compile AILANG. In mutgate it runs
  through P1.1's committed `evidence/P1.1/p11_core_check.sh`, which builds a throwaway workspace from the
  cwd's `src/` and ABI package and never reads `ailang.lock`. A clone therefore compiles its own tree.

## mutgate — 7/7

The spec is `mutgate_spec.tsv` (repo-relative paths). It was run with
`.agent/projects/013_core_architecture_for_dst/mutgate.sh --spec … --repo <clone>`. The clone was a fresh
`git clone --shared` of HEAD `031c0f16` with the P1.5r diff applied (only this part's paths, and these
evidence files). This part's commit did not exist yet, because committing is its last act. Rows:

| row | mutation | red because |
|---|---|---|
| `p15r_exemption_removed` | delete the exemption entry | the sweep flags `admission.ail:993: pinned '7.3'` |
| `p15r_exemption_stale` | anchor → `A9b:NoSuchFinding` | "matched 0 pin(s), not exactly one" |
| `p15r_fixture_equal_guard` | `:993` `7.3` → `8.0` | vacuity guard: "Equal, the fixture asserts nothing" |
| `p15r_fixture_equal_a9b` | `:993` `7.3` → `8.0` | `test_m9_a9b_each_identity_false` fails (11/12) |
| `p15r_pin_reverted` | `driver_only_dst.ail` pin → `7.4` | the sweep flags `driver_only_dst.ail:287: pinned '7.4'` |
| `p15r_budgetshaper_widened` | the BudgetShaper payload gains `! {Env, FS}` | "the ABI row carries an effect row again" |
| `p15r_compactor_widened` | the Compactor row gains `Env` | "Capability.Compactor is no longer at ! {AI, IO, Trace}" |

Every row went GREEN → RED → GREEN with identical bytes. The red reasons above come from re-applying the same
seds by hand in that clone, because each row's own `/tmp` log is overwritten by its restored run.

## Full targets: still red, and whose each red is

- **`make profile_definition` and `make driver_only`** exit 2 at `tools/ext_call_inventory/derive.py --json`
  (exit 1 on the red tree, before the ABI check runs). That red belongs to P1.2 and turns green at R-G.
  **Behind it is a second red that nobody owns yet.** `check_abi_version()`'s **rule 1** (profile-record
  prose, a different set from this part's rule-2 pins) fails at 8.0 on `ABI 7.4` in four profile-record
  `note:` strings:
  `src/core/dst_driver_only.ail:882`, `src/core/dst_driver_plus_compose.ail:734`,
  `src/core/dst_driver_plus_no_ops.ail:689` and `src/core/dst_driver_plus_herdr.ail:333`. None of these is in
  this brief, and the fourth file is outside the 25. Until someone owns them, the two targets stay red at
  R-G even after `derive.py` is green.
- **`make declared_vs_performed`** exit 2. BudgetShaper's payload row (`:128`) is now `✓`. The run aborts on
  the four `compose_*` rows (the 7.4 compose extension, P1.2d) before it reaches Compactor's slot row
  (`:715`), so that row was verified by `run_abi_probes.sh`.

## Found, not in scope, reported to the orchestrator

- `src/core/dst_driver_plus_herdr.ail:137` `herdr_abi_version() -> string { "7.4" }` feeds
  `herdr_graded_dst.ail`'s `record_manifest(…)`. That is a manifest ABI pin in substance. The sweep misses it
  because it arrives through a function call, not a literal.
- `ailang.lock` still records `sunholo/motoko_ext_abi` at `"version": "7.4"`, while the package's
  `ailang.toml` says `8.0`. A real A9b run compares against the lock's version.
