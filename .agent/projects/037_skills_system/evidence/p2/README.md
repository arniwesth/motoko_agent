# P2 evidence — Amendment 5 and the host rejection

037 PLAN-001 §4, run 2026-10-04 in `/workspaces/motoko_agent-skills` on `feat/skills-extension`.
Started at `18065e4a`; the gates below ran at `33ef3a25`. AILANG v0.47.2, extension ABI 8.0.

| Path | What it is |
| --- | --- |
| `pre/` | `ailang test src/core/ext/registry_normalize.ail` and `make registry_multiplicity` at `18065e4a`, before any change. Both exit 0. |
| `amendment-5/ARTIFACT.txt` | The artifact Amendment 5 cites: the fixture, and its three measurements. |
| `amendment-5/step1_host_as_it_stands.raw.log` | The fixture accepted by the host as it stood (`cfdf74c1`). Exit 0. |
| `amendment-5/step2_check_landed_fixture_red.raw.log` | The same row red once the check landed. Exit 2. |
| `mutgate.tsv` | Nine mutants of the reader, the order and the three arms; each is killed by a named inline test. |
| `gates/` | One log per gate at `33ef3a25`, each ending in `exit=<code>`. `HEAD.txt` is the commit. |
| `GATES.tsv` | Each gate against `../baseline/BASELINE.tsv`. No gate is newly red. |

**How the logs were compared with the baseline.** Line by line, after dropping the
`Warning: dependency … content changed` / `Run 'ailang lock' to update` pairs and the `exit=`
line, and after replacing colour codes and durations. "Identical" in `GATES.tsv` means identical
under that comparison.

**The lock warning changed its subject.** At the baseline every `ailang` run warned that
`sunholo/motoko_ext_test_dummy` had changed against the lock. From `5efa4294` (the comment beside
`ExtRegistration`) the warning names `sunholo/motoko_ext_abi` instead: `ailang.lock` records a
content hash for the ABI package and a comment is content. It is a warning, the gates do not read
it, and P2 did not touch the lock (PLAN-001 §0 item 2: not before P5).
