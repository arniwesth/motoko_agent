# 037 P1.3b–e — scripts, captures and result tables

Gitignored (`.gitignore:105`). Kept for P1.N; a later task promotes results to
`evidence/p1/`. Run everything from the worktree root, one session at a time.

## Harness

| File | What it does |
|---|---|
| `live_session.py` | One headless session of the real runtime under `skills_proto`. P1.2's command line and `env -i` allowlist, with a real provider (`openrouter/...`), the key and proxy variables forwarded from the environment, key scrubbed from everything written, a spend guard and a per-session cap. `--recorder script.json` answers from the local recorder instead (free). |
| `build_launch.sh` | The disposable launch directory `/tmp/motoko-037-p1.3/launch`: a copy of the worktree without `.git`. |
| `build_home.sh` | The scratch `HOME` whose `.profile` keeps `stubs/` first on `PATH` under `bash -lc`. |
| `stubs/gh`, `stubs/herdr` | Log the call and exit 1. |
| `build_fixture.sh` | A fixture template: P1.2's builder, plus `herdr` and `observer`, plus profile edits (`max_steps`, `context_limit`, `order`). Only the fixture's copy of the profile is edited. |
| `events.py` | Reads a session's `session.stdout.jsonl`. |
| `prices.json` | OpenRouter list prices fetched 2026-10-04 (no key). |
| `spend.tsv` | One line per live session: tokens from `run_summary`, list price, running total. |
| `key_usage.py`, `key_usage.tsv` | The key's own usage counter (numbers only). Shared with other sessions on the key. |

## Rows

| Row | Driver | Captures | Tables |
|---|---|---|---|
| b | `row_b.py run 5` / `table` | `capture/b/<model>.tNN.rN/` (`capture/b-voided/` holds two mis-capped sessions) | `results/row_b.tsv`, `results/row_b_sessions.tsv` |
| c | `row_c.py build` / `run <structural\|ai> <model>` / `table`; workload from `row_c_fixture.py` | `capture/c/<compactor>.<model>/` (with `workdir_dagr/` and `dagr_check_*.txt`) | `results/row_c.tsv`, `results/row_c_<run>.txt` |
| d | `row_d.py run pro 3`, `row_d.py run reka 3` | `capture/d/` | `results/row_d.tsv` |
| e | `row_e.py dry` / `run` / `table` | `capture/e/<family>/` | `results/row_e.tsv`, `results/row_e_skill_description.txt` |

Free recorder sessions (no model called) are under `dry/`:
`limit-64000`, `limit-131472`, `cap-80000` (what limit the compactor and the Skill
handler each see), `dry-b`, `dry-b2`, `structural.dry`, and `capture/e/dry`.

A capture directory holds `session.stdout.jsonl` (the runtime's event stream),
`session.stderr.log`, `session.txt` (settings, tokens, cost), `workdir_diff.txt`
(what the session wrote into the workdir), `launch_restore.txt` (what it wrote into
the launch directory, then undone), `stub_calls.log` if a stub was called, and
`STAMP.workdir.txt` when a stamp was written. Recorder sessions also hold the request
bodies (`req-NN.json`, header names only).

## Outside the worktree

`/tmp/motoko-037-p1.3/`: `launch/`, `home/`, `work/fixture` (the workdir, rebuilt
from a template before every session) and the templates `tpl-*`.

## Row b extension — four more models (operator ruling 2026-10-04)

`deepseek/deepseek-v4.1-flash`, `z-ai/glm-5.3`, `xiaomi/mimo-v2.6-pro`, `tencent/hy4-preview`:
one smoke session each, then 3 trials × 17 tasks. Cap for the whole of P1.3: $7.00 at list price.

| File | What it is |
|---|---|
| `row_b_ext.py` | `smoke` / `run [trials] [first]` / `table`. Imports `row_b.py` for the tasks, templates, capture paths, `finished`, `set_aside` and `score_session`; adds the model list, the $7.00 cap, and a doubled per-session dollar guard for `glm-5.3` (never reached). |
| `row_b_ext_notes.py` | The counts behind the report's notes; writes `results/row_b_ext_notes.txt`. No model call. |
| `results/row_b_ext.tsv`, `results/row_b_ext_sessions.tsv` | Copies of row b's two tables with the new models' rows appended. `row_b.tsv` and `row_b_sessions.tsv` are not rewritten. |
| `results/row_b_ext_smoke.log`, `row_b_ext_trial0.log`, `row_b_ext_trials1-2.log` | Runner output. |
| `results/endpoints-ext-2026-10-04.txt` | Per-provider prices for the four models (no key). |
| `capture/b-smoke/<model>.t02.smoke/` | The four smoke sessions (not scored). |
| `capture/b/<model>.tNN.rN/` | The 204 scored sessions, trials r0–r2, beside row b's. |
| `prices.json` | Three prices added; `prices.before-ext.json` is the file as row b left it. |
