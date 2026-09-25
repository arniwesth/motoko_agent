# Registry generator fixture tree, ABI 8.0 (031 PLAN-001 P0.5)

`make registry_gen_check` diffs the generator's output against the committed
`src/core/ext/registry_generated.ail`. From P0.5 the generator emits the 8.0
shape — `resolve` returns `ExtRegistration`, `normalize_registration` receives
`reg.config` — while the real registry and its 18 extensions stay on 7.4 until
P1.1/P1.2 (PLAN-001 §0 item 3: the tree is red between P0.4 and R-G). So the
real target is red by design, and this tree is where the template is shown
green:

- `ailang.toml` — an `[extensions]` table naming two synthetic 8.0 extensions
  (`exts/`), with the generator's keys pointed at `registry/`.
- `ailang.lock` — only the package names are read by the generator.
- `registry/registry_generated.ail` — the golden output, byte-for-byte what the
  generator writes for this table.
- `registry/normalize.ail` — a stub with the 8.0 boundary signature
  `normalize_registration(id, config, caps)` that P1.1 gives the real one.
- `tools/ext_registry_gen/generate.py` — a symlink to the real generator, so the
  unmodified make recipe runs here:
  `make -C tools/ext_registry_gen/fixtures/abi8 -f "$PWD/Makefile" registry_gen_check`.

`.agent/projects/031_system_one_decisions/evidence/P0.5/p05_registry_fixture_check.sh`
runs that target and then type-checks the golden file against the checkout's
8.0 ABI in a throwaway workspace (the repo lock pins path dependencies to the
primary checkout, so an in-place check inside a clone would read the wrong ABI).
Everything here is synthetic.
