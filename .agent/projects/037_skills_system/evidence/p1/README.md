# 037 P1 — evidence index

The result tables, scripts and small captures behind `../../NOTE-p1-prototype-results.md`.

**Every file here is a copy, made 2026-10-04 by the P1.N leg. Nothing was re-run.** The
originals are in the scratch worktree `/workspaces/motoko_agent-p1proto` (branch
`scratch/p1-prototype`, HEAD `e483c2a8` plus uncommitted prototype files), under the gitignored
`.motoko/herdr-delegates/p1.2/`, `p1.3a/` and `p1.3/`. PLAN-001 §3 G1 removes that worktree
after the gate, so this folder is what remains. `SHA256SUMS` lists every other file here; it was
written by `sha256sum`, and each of the 74 copies was compared with its original by `cmp`.

`src`, `packages`, `scripts`, `tools` and the `Makefile` are identical between `e483c2a8` and
`980f1aa3` (the HEAD of `feat/skills-extension` when this was written), by `git diff --stat`.

## The P0 baseline

Not copied; it is already committed beside this folder: `../baseline/BASELINE.tsv` and
`../baseline/logs/` (commit `fb2b9c87`, gates run at `501cd879`).

## Result tables

| File | What it is | Original |
|---|---|---|
| `row_b_ext.tsv` | Row b, seven models: per model and task set, then per expected skill | `p1.3/results/row_b_ext.tsv` |
| `row_b_ext_sessions.tsv` | Row b, one line per scored session (459) | `p1.3/results/row_b_ext_sessions.tsv` |
| `row_b_ext_notes.txt` | The counts behind the notes on the four added models | `p1.3/results/row_b_ext_notes.txt` |
| `row_c.tsv` | Row c, one line per run (six runs) | `p1.3/results/row_c.tsv` |
| `row_c_runs/row_c_<compactor>.<model>.txt` | Row c, one line per request, with each summariser refresh | `p1.3/results/` |
| `row_d.tsv` | Row d, one line per session (six) | `p1.3/results/row_d.tsv` |
| `row_e.tsv` | Row e, one line per provider family | `p1.3/results/row_e.tsv` |
| `row_e_skill_description.txt` | The `Skill` description row e sent: a 16,000-char index of 35 skills | `p1.3/results/row_e_skill_description.txt` |
| `p1.2_skill_description.txt` | The `Skill` description of the P1.2 listing session (four skills, 2,060 chars), from the provider request | `p1.2/capture/skill_description.txt` |

`row_b_ext.tsv` and `row_b_ext_sessions.tsv` hold the first three models' rows unchanged and
the four added models' rows after them. The three-model originals (`row_b.tsv`,
`row_b_sessions.tsv`) are not copied.

## P1.2 — the prototype (`p1.2/`)

| File | What it is |
|---|---|
| `skill_tool.json` | The whole `Skill` tool schema from the same request |
| `handler_probe.out` | The handler driven through a stub port: the 25% boundary, the call-time rules V4–V7, the unknown-name and missing-file errors |
| `skills_handler_probe.ail.txt` | The driver that printed it. Renamed from `.ail` so that scans of tracked `.ail` files do not pick it up |
| `gate_package_check.out`, `gate_registry_gen_check.out`, `gate_ext_ambient_inventory.out`, `gate_ext_hook_scope.out`, `gate_profile_definition.out` | The five gate runs with the prototype wired |
| `build_fixture.sh`, `run_listing_session.sh`, `capture_server.py` | The fixture builder, the headless launch, the local recorder |

## P1.3a — the two layouts (`p1.3a/`)

| File | What it is |
|---|---|
| `capture/<session>/layout.txt` | Launch directory, `--workdir` spelling and sandbox value of each of the six sessions |
| `capture/<session>/summary.txt` | What each session loaded, sent and got back |
| `run_layout_session.sh`, `capture_server.py`, `script_skill_readfile.json`, `summarise.py` | The launch, the recorder, its script, and the summariser |

The `Skill` description of `L1-sibling` is byte-identical to `p1.2_skill_description.txt`.

## P1.3b–e — the scripts (`p1.3/`)

`SCRATCH-README.md` is the scratch folder's own `README.md` and describes each script.

| File | What it is |
|---|---|
| `live_session.py` | One headless session of the real runtime under `skills_proto`, with a spend guard |
| `events.py` | Reads a session's event stream |
| `row_b.py`, `row_b_ext.py`, `row_b_ext_notes.py` | Row b: the three profile models, the four added ones, and the counts for the notes |
| `row_c.py`, `row_c_fixture.py` | Row c and its workload |
| `row_d.py`, `row_e.py` | Rows d and e |
| `build_launch.sh`, `build_fixture.sh`, `build_home.sh`, `stubs/gh`, `stubs/herdr` | The launch copy, the fixture templates, the scratch home, and the two stubs |
| `dry_script_b.json`, `dry_script_c.json`, `dry_script_cap.json`, `dry_script_e.json`, `dry_script_limit.json` | Scripts for the free recorder sessions |
| `key_usage.py` | Reads the key's own usage counter |

**These scripts are here for the record and will not run from this folder.** Each finds the
worktree root three directories above itself, expects the prototype package to be wired there,
and uses fixtures under `/tmp/motoko-037-p1.3/`. They were not run from here. `row_b.py` and
`row_d.py` import the task set from `evidence/m2_trigger_probe.py`, one level above this folder.

## The free recorder sessions (`dry/`)

No model was called in these.

| File | What it shows |
|---|---|
| `cap-80000/req-02.json`, `req-03.json`, `req-04.json` | Declared limit 80,000. Request 2 carries the `dagr-producer` skill whole (24,284 chars). Request 3 carries it capped. Request 4 carries the reloaded copy capped as the newest tool result |
| `cap-80000/session.txt`, `limit-64000/session.txt`, `limit-131472/session.txt` | Settings of the three sessions |

The event streams of `limit-64000` and `limit-131472` are 2.8 MB and 3.2 MB and are not copied.
Counted in the originals: `limit-64000` has no `compaction_extension` event, `limit-131472` has
five.

## Spend (`spend/`)

| File | What it is |
|---|---|
| `spend.tsv` | One line per live session: tokens from `run_summary`, list price, running total |
| `key_usage.tsv` | The key's own usage counter at twelve moments (numbers only; the key is shared with other sessions) |
| `prices.json`, `prices.before-ext.json` | OpenRouter list prices fetched 2026-10-04, after and before the four added models |
| `endpoints-2026-10-04.txt`, `endpoints-ext-2026-10-04.txt` | Per-provider prices for the measured models |

## Only in the scratch worktree

Not copied. All of it goes when the worktree and `/tmp` are cleaned.

| What | Where | Size |
|---|---|---|
| The prototype extension | `packages/motoko-ext-skills/` (`register.ail`, 374 lines, sha256 `e173e546…16b180`), untracked | 15 KB |
| The `std/yaml` probe extension | `packages/motoko-ext-yaml-probe/`, untracked | small |
| The profile | `.motoko/config/skills_proto/`, untracked | 1 KB |
| The wiring | uncommitted changes to `ailang.toml`, `ailang.lock`, `src/core/ext/registry_generated.ail` | 60 lines |
| Session captures | Archived as `./captures/p1-captures.tar.gz` (7.9 MB; unpacks to 55 MB: `p1.3/capture/`, `p1.3/dry/`, `p1.3a/capture/`, `p1.2/capture/` — see `./captures/README.md`). The live trees stay only in the scratch worktree until cleanup | 7.9 MB committed |
| Runner logs | `p1.3/results/*.log` | 69 KB |
| Fixtures | `/tmp/motoko-037-p1-fixture/`, `/tmp/motoko-037-p1.3a-l2/`, `/tmp/motoko-037-p1.3/` | 313 MB |
| The six delegate reports | `.motoko/herdr-delegates/answer-mot-dlg-*.md` there, and the same files in the shared checkout's mailbox | 100 KB |

A search of this folder for key-shaped strings (`sk-…`, `Bearer …`, `ghp_…`) finds nothing. The
copied request bodies record header names, not values.
