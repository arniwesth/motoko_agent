# 037 — two live sessions on the final code

Run on 2026-10-05 by the session that ran the implementation review, at the operator's request.
The code under test was `a74bdcc2` (the PR's head, `2ffced7a`, adds only documents to it).
AILANG v0.47.2.

## Why

Until this, no model had used a skill through the code in this PR. The loading figures in
`NOTE-p1-prototype-results.md` came from the throwaway prototype, whose code was not merged. The
final package was checked by stub tests and by one `Skill` call dispatched without a model
(`scripts/verify_skills_call.ail`). The repository itself has no `.motoko/skills/`, so nothing a
session does here by default exercises it.

## What ran

One headless session of the real runtime per model: `src/core/supervisor.ail` with the committed
`skills` profile, the sandbox set to the workdir as the TUI sets it, and a real provider. The
command line and the `env -i` allowlist are those of `evidence/p1/p1.3/live_session.py`.

- **The workdir** is outside the directory the session is started in (the layout D7 is stated
  for) and holds four skills: `workdir-stamp` and copies of `ailang-feedback`, `dagr-producer` and
  `pr-review-loop`. It is P1.2's fixture, built by P1.2's builder.
- **`workdir-stamp`** tells the model to read `stamp-format.txt` in the skill's directory and to
  write `STAMP.txt` in the working directory from the one line it holds,
  `motoko-skill-stamp-7f3a :: <reason>`.
- **The task**, one of P1.3's two stamp tasks: *"Stamp the working directory. We are freezing
  this workspace for the 0.9 release."*
- **The profile** is the committed one with `agent.max_steps` set to 8, as P1.3's stamp sessions
  had it. Nothing else was changed.

## Result

| | `deepseek/deepseek-v4-pro` | `meta/muse-spark-1.3-contributor` |
|---|---|---|
| Exit, wall time | 0, 62 s | 0, 74 s |
| Extensions loaded | all seven of the profile, `skills` among them | the same |
| Provider responses | 4 | 4 |
| First call | `Skill {"name": "workdir-stamp"}` | the same |
| Second call | `ReadFile .motoko/skills/workdir-stamp/stamp-format.txt` | the same |
| Third call | `WriteFile STAMP.txt` | the same |
| `STAMP.txt` | `motoko-skill-stamp-7f3a :: freezing workspace for 0.9 release` | the same |
| Error events | none | none |
| Finish | `stop` | `stop` |
| Other changes in the workdir | none | none |
| Tokens in, out | 20,124 and 429 | 21,584 and 2,297 |
| List price | $0.0044 | $0.0026 |

In both sessions the `Skill` result's `stdout` began with the directory line
`.motoko/skills/workdir-stamp`, and the path the model then read is that line plus the file's
name. That is A9's last clause, and the stub tests could not show it.

## What this does and does not show

It shows that the final code works end to end with a real model, on two models and one task: the
extension loads from the committed profile, the index reaches the model, the model calls `Skill`
first, the result carries the directory, a bundled file under it can be read, and the instruction
is carried out.

It is two sessions. It does not re-measure how often models load a skill; those rates are still
the prototype's. It says nothing about compaction, reloading, or a workdir that is a subdirectory
of the launch directory.

## How it was contained

- The session was started in a disposable copy of the code, without `.git`. After both sessions
  the copy held no changed file.
- The environment was built from nothing: `PATH`, a scratch `HOME`, the sandbox and session
  variables, the provider key and the proxy variables. No GitHub or other token was in it.
- `gh` and `herdr` on `PATH` were P1.3's stubs. Neither was called.
- The key was replaced in everything written to disk. It is in none of these files.

## Files

| File | What it is |
|---|---|
| `build.sh` | The commands that built the launch copy, the scratch home and the fixture, collected into a script. They were run by hand; the script was not re-run |
| `run_live.py` | The runner, as run: one session, then the summary this README's table is from |
| `out/pro/`, `out/muse/` | Each session's event stream (`session.stdout.jsonl`) and stderr |
