# STATE — P2.3 round 4 half (i)

**One read replaces the six that each delegate currently spends rediscovering this.**
Measured: sessions open by `cat`-ing the predecessor's 20 KB answer file plus ~5 git/sha
calls — ~36 KB and 6 tool calls before any work. Point the brief here instead.

Last updated 2026-09-19 after P2.3·a18. Regenerate the row table with
`bash LEDGER-p23-part1-rows.sh > LEDGER-p23-part1-rows.tsv`.

## Identity

| | value |
|---|---|
| A (eval worktree) | `/workspaces/motoko_agent-eval`, HEAD `20626054e8015ebd8623459789d8de8bb6c260d2`, detached |
| A working tree | 14 files changed, +1804/−205, + `entry_config.py` and `p23_collector.py` untracked |
| $T (sweep root) | `/workspaces/p23-sweep-r4` |
| C (sweep clone) | `$T/clone` |
| X6 | `20a78579e5eaef34bfdad10cc81d9f2f2e61d753` / tree `ec46735ce9715b1eba59f0d04de15679066296c9` |
| **X7 (current)** | `9ed0d3895d541738fb205e970dc1848b32a12a84` / tree `f75099f9af2137096ebef983f5f9b268d77d6086` |
| E record | `$T/erecord-x7.json` (X6-era: `$T/erecord-x6.json`) |
| Toolchain | AILANG v0.33.0 `ae36986c…`, binary `bfd1c3db…`, archived at `/workspaces/ailang-pins/` |

Rebuilding the binary invalidates the freeze — restart if you do.

## Environment, verbatim

```bash
# One assignment per line: `export T=… C=$T/clone` expands $T BEFORE it is set,
# so C becomes /clone and every `git -C $C` fails with
# `fatal: cannot change to '/clone'`. Found by P2.3R·a5 on the way in.
export T=/workspaces/p23-sweep-r4
export C=$T/clone
export A=/workspaces/motoko_agent-eval
export PATH=/workspaces/ailang-pins:$PATH
export AILANG_FS_SANDBOX=/workspaces
export TMPDIR=$T/tmp
export EVAL_LOCK_PATH=$T/tmp/heavy.lock   # absolute, on every guarded run
# --evaluator takes a COMMIT, never a directory
```

## Rows

See `LEDGER-p23-part1-rows.tsv` — one line per artifact, digests computed not typed.
Summary at X7: **1.7 is the row round 4 exists to turn green**; the X7 fix set is
in place but **the deltas have not run**.

- Carried by blob-equality (X6 receipts stand): 1.3, 1.4, 1.5, 1.6, 1.8-shell, 1.9
- Must re-run at X7: 1.7, 1.10 R1d leg, 1.11 MUT-4/MUT-5 legs, 1.12 ×2, 1.13, 1.14, 1.15, 1.18
- 1.16 teardown: **operator only** — live session roots under `/workspaces`

The carry-over is an operator ruling on amendment 0.1, recorded as a `directive`
event at `2026-09-19T08:04:00Z` in `.dagr/run-w3-p1-1789663745618.json`. Cite it;
it is the one part of the evidence chain a reviewer can challenge.

## X7 fix set — the 5 authorized items

Two files only: `scripts/eval/test_candidate.py`, `src/eval/journal/testdata/MATRIX.expected.tsv`.

1. 1.7 helper — `build_entry_from_fixture` wraps `normalized_configuration` + `read_world`
   in `try/except WorldRefused` → sentinel `t0_settings.json` + `expected_end.txt`
2. mut4 test — self-seeding dirt, restored in `finally`; RED iff MUT-4 applied
3. mut5 test — clean-clone routing so the provenance gate passes
4. m13 test — evaluator as a commit, `synthetic=False`
5. m12 flake — 12 `M12.component.*` rows renamed `*.quarantined`; `scan.ail` untouched

All 7 evaluator files verify byte-identical X6→X7 (`candidate.py`, `journal_replay.ail`,
`journal_replay.sh`, `entry_config.py`, `p23_collector.py`, `scan.ail`, `admission.ail`).
Re-verified mechanically 2026-09-19; the ledger's `carry` rows recompute it.

## Hazards

- **Never commit in A.** X7 lives in the sweep clone only. Nothing staged in A, zero A byte edits.
- **Never move the clone checkout mid-run** — `rev-parse` only; tests self-restore.
- **Stray files in $T are not free.** Blocker B2 counted 58 untracked files into an
  assembled-tree digest and refused admission. Generated artifacts belong in this
  project directory, not $T.
- **R5 / selectors are out of scope** for half (i). Do not touch selector bytes.
- **Long runs kill sessions.** a5 (3.6 h), a11 (76 min) and a7 (52 min) all ended with no
  answer file; a15 and a16 (10–13 min, one row each) delivered clean. Launch heavy work
  detached with `setsid`/`nohup`, record pid + log path, and let a short poller report.
  See `.agent/issues/empty-stop-floor-event-never-reaches-the-session-journal.md`.
- **Privacy §0.6** binds every brief: counts, digests, indices, identities — never corpus content.

## Next

P2.3 is `blocked` in the graph pending **the round-4 review**, which has never run —
P2.3R's four attempts cover rounds 1–3 and the decisions review, none has seen X7.
The two reviewable-now claims are the 2-file scope and the carry-over; both are frozen
and checkable without any delta result.
