# P1.5r-a2 evidence: rule-1 profile prose and `herdr_abi_version()` at ABI 8.0

This is PLAN-001 (031) line R, the follow-up attempt on P1.5r (`3eb6b71a`). Brief: `LEG-P1.5r-a2.md`.
HEAD before: `73c1464f`. AILANG `v0.33.0`. Outputs are in `CHECKS.log`. The mutgate record is
`mutgate-result.tsv` and its spec is `mutgate_spec.tsv`.

## What changed

1. **Rule-1 prose.** Four profile-record `extension.abi` notes said `ABI 7.4`, and they now say `ABI 8.0`.
   Each one also gets a history entry in its parenthesis ("8.0 every callback on its row's context view
   and the two decision variants; 7.4 ExtCtx.open_waits; …"). The earlier entries are unchanged. The four
   sites are `src/core/dst_driver_only.ail:882`, `dst_driver_plus_compose.ail:734`,
   `dst_driver_plus_no_ops.ail:689` and `dst_driver_plus_herdr.ail:333`. Each edit stays on one line, so
   no line moves.
2. **`herdr_abi_version()`** now reads `"8.0"`, and **the sweep has learned to see it.** Rule 2 in
   `check_fixtures.py` has a third pin class: the body of any `func *abi_version() -> string { "x.y" }`.
   It is read at the definition, where the literal is, and not at each call site. **Why this and not a
   single source:** the only source of the version is `packages/motoko-ext-abi/ailang.toml`, and no
   AILANG module can read it. The ABI package does not export the version as a function, and adding
   that export would edit a package frozen at 8.0 (Amendments 1–4). Rule 2's own comment already says
   so. The function's comment block was rewritten to say it is now guarded directly. The block keeps
   the same line count, so `:137` and every later line stay where they were.
3. **Rule 1 standalone.** Rule 1 is now `check_abi_prose(live)`, called from `check_abi_version()` just
   before `check_abi_pins(live)`, so the full-run order is unchanged. A new `--abi-prose` flag runs it
   without `derive()`, the same way `--abi-pins` does. Nothing else in `check_fixtures.py` was touched.

## Exit checks

1. `--abi-prose`: ✓ 8.0 (4 sites in 7 files). `--abi-pins`: ✓ 8.0 (**33** pins, up from 31: the new
   class adds `herdr_abi_version()` and `conformance_abi_version()`). The A9b exemption still holds.
   Before the `src/core` edits, both flags went red on exactly the sites named in the brief.
2. `p11_core_check.sh`: all four touched modules pass `check` and `test` (6+9+7+3 tests, 0 failed).
   `make anchors` and `make driver_leaf_inventory` give byte-identical output before and after the
   diff, and both exit 0. Do these files carry pinned anchors? Neither target reads them. The
   attribution anchors that `anchors.sh` cascades are in `session.ail`, `tool_phase.ail` and the
   others, not in the profile modules. No line moved anyway.
3. **`make profile_definition` and `make driver_only` are still red (exit 2), for a reason this part
   does not own.** In both, the AILANG acceptance script passes (`driver_only_dst PASS`). Then
   `check_fixtures.py main()` calls `derive()`, and `tools/ext_call_inventory/derive.py --json` exits
   1 with **24 unresolved** sites:
   - 15 in `packages/motoko-ext-abi/types.ail:1240…` (the 8.0 view constructors take `ExtPorts` fields
     as values);
   - 8 in `packages/motoko-ext-compose/compose.ail` (6 value-escapes, and 2 `ctx.ports` resolving to
     `None`);
   - 1 in `packages/motoko-ext-agentcli/agentcli.ail` (`p : Provider`).
   `1cde3c8e` recorded P1.2 as complete, so this is **classifier 2 (`ext_call_inventory`) not yet taught
   the 8.0 view shapes**. It is not a P1.2 extension-site gap. As far as I can see nobody owns it, so it
   is the orchestrator's to assign. Behind it, rules 1 and 2 are now green, and this part has removed
   the red it was assigned.
4. mutgate: a fresh `git clone --shared` of `73c1464f` with this diff applied, **4/4 discriminate**:

| row | mutation | red because |
|---|---|---|
| `p15ra2_note_reverted_driver_only` | `dst_driver_only.ail` note → `ABI 7.4` | rule 1: "names 'ABI 7.4' and … declares 8.0" |
| `p15ra2_note_reverted_herdr` | `dst_driver_plus_herdr.ail` note → `ABI 7.4` | rule 1, same message, herdr file |
| `p15ra2_herdr_fn_reverted` | `herdr_abi_version()` → `"7.4"` | rule 2: `dst_driver_plus_herdr.ail:137: pinned '7.4'` |
| `p15ra2_sweep_blind_to_calls` | the new pattern disabled | the pin count falls to 31. A reverted function would then be invisible, which is the P1.5r finding |

No row compiles AILANG, so the `ailang.lock` trap does not apply. The red reasons come from
re-applying each sed by hand in the clone.

## Not done, on purpose

- **Profile versions were not bumped.** In earlier ABI moves the prose edit came with a version bump
  (`a2113e85`: driver_only 30→31, no_ops 19→20; PINDH herdr 1→2). This time I left them alone because
  `scripts/dst/herdr_graded_dst.ail:412,793` hard-codes `driver_plus_herdr/2`, and that file is in
  P1.6r's lane. A bump in `src/core` alone would turn `herdr_graded` red. It is the orchestrator's call
  whether R-G re-issues the four profiles for 8.0, together with the script's pin.

## Other version-bearing calls or prose (grepped by pattern class, not by file)

- **Calls** (`func *abi_version() -> string { "x.y" }` across all tracked `.ail` files): only
  `herdr_abi_version` (fixed) and `packages/motoko_ext_conformance/invariants.ail:20`
  `conformance_abi_version()`, which already reads `"8.0"` and is now inside the sweep. No other
  `*version()` function returns a bare `x.y` literal. The rest are profile, rule-set or schema versions.
- **Profile-record prose** (`note:` with `ABI x.y`, anywhere): only the four above.
- **Other `ABI 7.x` prose** (`progress_contract_guard.ail:203,226`, `phase_vocab.ail:567`,
  `session.ail:1924`, `Makefile:679`): all provenance ("when it landed"). Per rule 1's comment they are
  correct as written.
- **Outside `.ail` files:** `ailang.lock` at HEAD still records `sunholo/motoko_ext_abi` at `"7.4"`.
  That is not this part's, and P1.5r already reported it. There are also the frozen
  `evidence/plan004-v2/erecords/*.json` `"version": "7.4"`. These are evidence records, not pins.
