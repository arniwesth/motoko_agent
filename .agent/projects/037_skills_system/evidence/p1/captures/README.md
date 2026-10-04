# 037 P1 — archived session captures

`p1-captures.tar.gz` holds the raw per-session captures behind the P1 tables in the folder
above (`../README.md` is the index of those tables). It is a copy. Nothing was re-run to make it.

The originals were in the scratch worktree `/workspaces/motoko_agent-p1proto` (branch
`scratch/p1-prototype`, HEAD `e483c2a8`), under the gitignored `.motoko/herdr-delegates/`.
Paths inside the archive are relative to that directory.

## What the archive holds

3,187 files in 516 directories, 51,908,726 bytes unpacked. 1,425 of the files are empty
(start markers, and diffs of sessions that wrote nothing).

| Tree | Sessions | Files | Bytes | What it is |
|---|---|---|---|---|
| `p1.3/capture/` | 487 | 3,014 | 42,011,676 | Rows b, c, d and e. 486 sessions called a model; `e/dry` used the local recorder |
| `p1.3/dry/` | 6 | 115 | 9,381,034 | Free recorder sessions. No model was called |
| `p1.3a/capture/` | 6 | 51 | 437,239 | The two-layout sessions, all against the local recorder |
| `p1.2/capture/` | 1 | 7 | 78,777 | The P1.2 listing session, against the local recorder |

`p1.3/capture/` by row:

| Directory | Sessions | Scored | Contents |
|---|---|---|---|
| `b/<model>.tNN.rN/` | 459 | yes | Row b: 17 tasks, five trials (`r0`–`r4`) for three models and three (`r0`–`r2`) for the four added ones |
| `b-smoke/<model>.t02.smoke/` | 4 | no | One smoke session for each of the four added models |
| `b-errors/<label>.try1/` | 2 | no | Two sessions that ended with `Provider returned error` and were set aside |
| `b-voided/` | 2 | no | Two sessions run under the wrong step cap. `README.txt` there explains |
| `c/<compactor>.<model>/` | 6 | yes | Row c runs, each with `workdir_dagr/` and `dagr_check_run-atlas.json.txt` |
| `d/<pro\|reka>.rN/` | 6 | yes | Row d |
| `e/<family>/` | 8 | yes | Row e: seven provider families and one recorder session (`dry`) |

`p1.3/dry/` holds `cap-80000`, `limit-64000`, `limit-131472`, `dry-b`, `dry-b2` and
`structural.dry`.

## Layout of a session directory

Every session under `p1.3/` has the first six files. The rest appear when they apply.

| File | What it is |
|---|---|
| `session.txt` | The summary, one `key=value` per line (fields below) |
| `session.stdout.jsonl` | The runtime's event stream, one JSON event per line, plus a few plain-text lines |
| `session.stderr.log` | The runtime's stderr |
| `workdir_diff.txt` | What the session wrote into the workdir. Empty when it wrote nothing |
| `launch_restore.txt` | What the session wrote into the launch directory before that was undone. Empty in all but one session |
| `.start_marker` | Empty file, touched when the session started |
| `STAMP.workdir.txt` | The stamp file the session wrote, when it wrote one (57 sessions) |
| `stub_calls.log` | Calls to the `gh` and `herdr` stubs, when there were any (20 sessions) |
| `req-NN.json` | Recorder sessions only: each provider request, as `path`, `header_names` and `body` |
| `server.log` | Recorder sessions only: the recorder's own log |
| `workdir_dagr/run-atlas.json` | Row c only: the dagr run file the session left in the workdir |
| `dagr_check_run-atlas.json.txt` | Row c only: the output of `dagr check` on that file |

`session.txt` fields: `label`, `row`, `model`, `ai_arg`, `launch_dir`, `workdir`, `template`,
`dry_run_recorder`, `task`, `started`, `rc`, `killed`, `wall_s`, `steps`, `input_tokens`,
`output_tokens`, `cache_read_tokens`, `list_cost_usd`, `running_total_usd`, `finish_reason`,
`error`. `dry_run_recorder` is `<none: live model>` for a live session and the recorder script's
path otherwise.

The event stream opens with `session_start` (profile, loaded extensions, task). Each step then
has `provider_call_prepared`, `thinking`, `native_tool_calls` and `native_tool_results`, with
`ext_tool_handled` when an extension tool such as `Skill` ran. `run_summary` gives the finish
reason, steps, tokens and cost. `../p1.3/events.py` reads the stream.

The other two trees are older and laid out differently:

- `p1.3a/capture/<session>/` has `layout.txt` (launch directory, `--workdir` spelling, sandbox
  value), `summary.txt`, `session.stdout.jsonl`, `session.stderr.log`, `server.log` and
  `req-01.json` to `req-03.json`. Three sessions also have `skill_description.txt`. There is no
  `session.txt`.
- `p1.2/capture/` is one session: `session.stdout.jsonl`, `session.stderr.log`, `req-01.json` to
  `req-03.json`, `skill_description.txt` and `skill_tool.json`.

## Unpack and verify

From `evidence/p1/`:

```sh
grep ' ./captures/' SHA256SUMS | sha256sum -c              # the archive and this README
tar -tzf captures/p1-captures.tar.gz | grep -vc '/$'       # 3187 files
mkdir -p /tmp/p1-captures
tar -xzf captures/p1-captures.tar.gz -C /tmp/p1-captures   # p1.2/ p1.3/ p1.3a/ appear there
```

The archive was written with GNU tar 1.35 and gzip 1.12:

```sh
LC_ALL=C tar -C .motoko/herdr-delegates --format=gnu --sort=name \
    --owner=0 --group=0 --numeric-owner -cf - \
    p1.2/capture p1.3/capture p1.3/dry p1.3a/capture | gzip -n -9
```

Entries are sorted by name and owned by `0:0`, and the gzip header carries no name or time.
File modification times are kept, because they record when each session wrote each file. The
same command on the same tree gives the same bytes only while those times are intact.

## What was derived from it

| File in `evidence/p1/` | Derived from |
|---|---|
| `row_b_ext.tsv`, `row_b_ext_sessions.tsv`, `row_b_ext_notes.txt` | `p1.3/capture/b/`: 459 sessions, one line each in `row_b_ext_sessions.tsv` |
| `row_c.tsv`, `row_c_runs/*.txt` | `p1.3/capture/c/` |
| `row_d.tsv` | `p1.3/capture/d/` |
| `row_e.tsv`, `row_e_skill_description.txt` | `p1.3/capture/e/` |
| `spend/spend.tsv` | The `run_summary` of each live session |
| `dry/cap-80000/`, `dry/limit-64000/`, `dry/limit-131472/` | Copies of files in `p1.3/dry/` |
| `p1.3a/capture/<session>/layout.txt`, `summary.txt` | Copies of files in `p1.3a/capture/` |
| `p1.2_skill_description.txt`, `p1.2/skill_tool.json` | Copies of files in `p1.2/capture/` |

The scoring scripts are in `../p1.3/`. They expect the captures at
`.motoko/herdr-delegates/p1.3/capture/` of a worktree with the prototype wired, and will not run
from this folder.

## What is not in it

- `p1.3a/l2a/fixture/` (18 files, 62,600 bytes): a rebuilt copy of a fixture, not a capture.
- The scripts and result tables beside the captures. They are committed in the folder above.
- `p1.3/results/*.log`, the runner logs.
- The fixtures under `/tmp/motoko-037-p1.3/` and `/tmp/motoko-037-p1-fixture/`. Captures name
  these paths but do not contain them.

## Credentials

The four trees were scanned before packing and nothing credential-shaped was found: no
`sk-…`, `Bearer …`, GitHub, AWS, Google or Slack token, no private-key block, no JWT, and no
URL with a password in it. The recorder's `req-NN.json` files list header names, not values.
`live_session.py` forwarded the provider key to the runtime and scrubbed it from everything it
wrote.

The captures do contain absolute paths on the machine that ran them and the full text of every
prompt and model reply.
