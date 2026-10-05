# 037 P5 — evidence index

Evidence for PLAN-001 §5 P5: the registry wiring, the named profile, the two
`verify_extensions` recipe changes, the refusal fixtures (ADR A3), A1 and A2, and the
same-key row. Produced on 2026-10-05 in `/workspaces/motoko_agent-skills` on
`feat/skills-extension`, with AILANG v0.47.2. P5 started at `32c02cd8`; everything here ran
at `3b8494a5`, the last commit that changes code. The commit after it adds this folder only.

## Gates (`GATES.tsv`, `gates/`)

`run_gates.sh` ran each as `make <gate>` from the worktree root, one at a time, with the
eleven credential variables removed from the environment. Each log ends in `exit=<code>`;
`gates/HEAD.txt` is the commit.

- **No gate is newly red against P2's `GATES.tsv`.** The seventeen gates of ADR A7 exit as
  they did at P2: thirteen exit 0, and `ext_hook_scope`, `declared_vs_performed`,
  `driver_plus_no_ops` and `driver_plus_compose` exit 2, as in the P0 baseline.
- **Three of the four red gates now name `skills` in the failure they already had.**
  `driver_plus_no_ops` and `driver_plus_compose` fail because an installed extension is in
  neither list of the profile; the list was `['ailang_tools']` and is `['ailang_tools',
  'skills']`. `declared_vs_performed` fails because the probe's arm pairs lack an installed
  extension; it lacked `ailang_tools` and now lacks `skills` too. Nothing else in those
  three logs differs from P2's. Wiring the package causes this, and PLAN-001 gives the
  repair to P6 (the four profile lists, the arms and the counts).
- `ext_hook_scope` is red on `test_dummy` alone, as before; `skills` passes its row.
- `gates/ci_verify/` holds three targets that are not in A7 and that CI runs:
  `verify_core`, `verify_classify_check` and `smoke_no_delegated_storm`. All exit 0.

The logs were compared with P2's as P2 compared with the baseline: line by line, after
dropping the lock-warning pairs and the `exit=` line and replacing colour codes and
durations. The four inventory logs were also compared with P4's wired-clone logs
(`../p4/gates/wired/`); they differ only in the source revision, a Makefile line number,
the tracked-file count and, in `ext_call_inventory`, the position of one line.

## The fixture suite (`gates/verify_skills_refusal.log`)

`make verify_skills_refusal` runs `scripts/verify_skills_refusal.sh`: 41 checks, 41 pass.
Each case is one process with `AILANG_FS_SANDBOX` set to a fixture workdir, running
`scripts/verify_skills_startup.ail`, which makes the two calls the runtime makes before
`session_start`.

| Rows | What they check |
|---|---|
| 22 `refused` | Exit 2, exactly one JSONL `error` event, the host's `[registration-refused]` for the skills extension, the expected violations by rule and path and no further one. R1 four ways (the ADR's three and a dangling symlink), V1 two ways, V2, V3 three ways, V4's four cases, V5, V6, V7, V8, two violations (also under `extensions.strict`), the committed profile on a broken tree, and A2's invalid change |
| 5 `started` | Exit 0, no `error` event, one `Skill` schema: no root, an empty root, nine valid skills, a relative symlink inside the workdir, the committed profile on a valid tree |
| 5 `A1` | With none: the D12 text and no `enum`. With nine: every name in name order, one line each; the instruction, then the index, and nothing else; the `enum` is the names |
| 7 `A2` and 2 controls | Adding, removing or rewording a description moves `ext_config_digest` and neither other digest, and the journal's resume row continues; a body edit moves none. The controls: the resume row refuses another `ext_set_digest`, and that digest differs under another extension set |

The valid set has one skill per scalar style of ADR D9: plain with a trailing comment,
single-quoted, double-quoted, folded, folded with a chomping indicator, literal, a
continuation line, an anchor with an alias and a tag, and CRLF with a byte-order mark.
`quoted` carries the malformed optional fields.

The last line of the log is a note, not a check: a skill directory that cannot be listed
ends the process with exit 1 and no event, the limit ADR D1 states.

## The runtime's own entry (`logs/real_entry.out`, `real_entry.sh`)

The suite does not run `src/core/supervisor.ail`: it recompiles on every run, about 40
seconds each. `real_entry.sh` runs it six times, headless and with `--ai-stub`, to show the
suite and the runtime agree.

- On a tree with two violations: exit 2, one JSONL `error` event, no `session_start`. The
  message is the one `make verify_extensions` prints for the same two violations
  (`logs/verify_extensions_rejection.log`).
- Across A2's edits (a skill added; a description reworded; a body reworded; no root): the
  `system_prefix_digest` and `ext_set_digest` in the runtime's `v2_mode` header are the
  same in all five runs. The `ext_set_digest` is the value the suite's driver prints
  (`logs/startup_driver_sample.out`).

`ext_config_digest` has no caller in the runtime (ADR D4), so only the suite shows it move.

## The recipe changes (`logs/verify_extensions_*.log`)

- `verify_extensions_skills_profile.log`: `MOTOKO_CONFIG=skills make verify_extensions`
  boots the seven extensions of the profile, exit 0.
- `verify_extensions_rejection.log`, three runs, each on a skill tree placed at the
  worktree root for that run only and removed afterwards:
  1. Two violations. The recipe prints the rejection under `✗ skills` and exits 2.
  2. The same boot through the old filter prints `✗ skills` and no reason.
  3. One skill that is a symlink to a valid skill outside the repository. Without the
     sandbox the boot exits 0; under the recipe it is refused as V2.

## The wiring (`logs/wiring_vs_p4.txt`)

The four changed lines of the root manifest and the generated registry are P4's
`WIRING.diff`, and the lock's new entry has the content and interface hashes P4's clone
recorded. `ailang lock` also refreshed two content hashes that were stale against
committed package content: `motoko_ext_abi` (P2's comment, `5efa4294`) and
`motoko_ext_test_dummy` (stale on `main`; the baseline's logs carry its warning). With the root lock fresh, the lock warning P2
described is gone from every gate log but `conformance`'s: a package module is checked
against the package's own lock, and all twenty package locks still hold the older ABI hash.

`logs/test_package.log`: the package's 91 tests pass on the wired tree. No file under
`packages/` changed in P5.

## The same-key row (`logs/same_key_mutant.log`)

With the package's `registration_refusal_key()` changed to `registration-refusal` for one
run, `registry_multiplicity`'s row fails: `equal: false; the host refuses the extension's
spelling: false`. The file was restored.

## Mutation check (`mutants.tsv`, `mutate_p5.py`)

Twelve mutants, twelve killed by the fixture suite. Each is one change to a tracked file,
restored after the run.

- Five break the chain for every refusal and are killed by all 22 `refused` rows: the host
  reads another key, the rejection exits 3, it is printed twice, it is printed as a bare
  line, and the extension never writes the refusal.
- Seven are narrower and are killed by the rows that should notice: the three R1 symlink
  rows; the V2 row; the five rows with a directory that has no `SKILL.md`; the `enum` row;
  the three A1 rows and four A2 rows when the index is not in `config`; the four A2 rows
  where the digest must move; the two rows of the committed profile.

The last column is the expectation as written before the run. For `e04` it says "the two
V1 rows"; five rows fail, every one whose fixture has such a directory. Rows `e05` and
`e06` were rerun after the first pass to record the A1 rows' full labels; the first pass
recorded each only as `A1`. Their results were the same.

## Notes

- No model or network service was called and no file here holds a credential. The check_core
  log names the herdr pane it ran in, as P2's does.
- The recipe prints the rejection with `echo`, as it printed every failure line before.
  Under `dash` that would turn a JSON `\n` into a line break and cut the printed event
  there. No refusal the skills extension writes contains one: P3's messages collapse
  whitespace.
