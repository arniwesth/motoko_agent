# W0.9: the dry run of 2026-11-03

Registered by amendment A1 item 1. **Nothing here counts towards the trial.** This records what
the plumbing did and what had to change before W1, which amendment A3 registers.

| Session | Arm | Target | Started (UTC) | Stopped | Output sha256 (at the stop) | Audit |
|---|---|---|---|---|---|---|
| `t043-dry-a` | A | T0 | 21:55:53 | 22:15:58 | `500992327152b436…` | 28 calls; 0 breaches, 0 refused attempts, 3 notes |
| `t043-dry-b` | B | T0 | 21:56:25 | 22:16:33 | `f7181a1d6c0d4e89…` | 34 calls; 0 breaches, 0 refused attempts, 0 notes |

Both ran on the unseeded tree, sha256 `d23702050e5c4d24…` (`meta`), with Claude Opus 5.5 at
`xhigh`. Each directory here holds the brief as sent, the deny rules, `meta`, `reports.tsv`,
`SUMMARY.md` and the scripts and models the session wrote. `FILES.sha256` lists every output
file, including the bulk left out of the commit: arm B's `pkg/` shadow package (8 MB) and its
enumeration outputs (3 MB). `clock.log` is the clock's own record.

## What the plumbing did

- **Startup.** Claude Code asked once per new directory whether to trust it. The first session
  blocked on that prompt. `launch.sh` now answers it, and the second session started on its own.
- **Briefs, cap and stop.** Both briefs rendered from Appendices A and B, with T0 from A1. The
  reminder went out at 17 minutes and the Esc at 20. Both sessions had finished their
  deliverables early, at about 11 and 10 minutes.
- **Deny rules.** No call hit one. The audit found no breach once it treated a session's own
  Claude Code scratchpad, `/tmp/claude-1001/<its cwd key>/`, as the session's own (A3 item 3).
- **A gap.** Arm A ran `pgrep -af "ailang run"` to find its own background job, and the listing
  also showed another process's command line, with a path under `/workspaces`. A process listing
  can show other sessions' command lines, and nothing short of isolation prevents that (A3 item 4).
- **Background jobs.** Arm A left an enumeration running past its own deliverables. It ended by
  itself before the stop, but nothing would have stopped it at the cap. The stop now ends every
  process in the session's directory before hashing (A3 item 2).
- **AILANG imports** resolve only inside an `ailang.toml` package. Arm A generated its module
  under `<tree>/.p01tmp/` and deleted it after each run; arm B built a shadow package in its
  output directory. Each lost a few minutes, the same for both arms, so the briefs are unchanged.

## What the sessions found (recorded, not counted)

- **Arm A**, executed checks, built its own generator over appended messages, appends with
  `replaces_previous`, and `history_replaced` entries. It reported three defects. The operator
  re-ran each reproduction on the unseeded tree, and each exited 1:
  - `A1-T0-1`: a `replaces_previous` append runs `updatePending` on the new message without
    undoing the replaced one. Witness `1,100`: host `["a"]`, fold `dangling = []`.
  - `A1-T0-2`: a `history_replaced` entry resets the host's open set to `[]` without reading the
    replacement, and the fold reports the replacement's trailing calls dangling. Witness `201`:
    host `[]`, fold `["a"]`.
  - `A1-T0-3`: `strip_dangling` picks the message to strip by `seq`, and every message of one
    `history_replaced` entry shares a `seq`, so a reused dangling id is also stripped from an
    earlier, answered assistant, leaving an orphan tool result the transcript check accepts.
    Witness `300`.

  None is shown reachable. They are K8, K9 and K10 in A3.
- **Arm B**, Lean, began from `evidence/PairingModel.lean`, which already models T0, and
  extended it to the fold. P0.1 is proved for the model, with the axioms `propext` and
  `Quot.sound`. The differential test needed 0 model changes and gave 0 mismatches against the
  real code. Its three reports are K1 and RESEARCH §6.2, reproduced. Its model, like the worked
  example's, covers appended messages only, so it could not see A's three.

The difference is suggestive and is not evidence for either hypothesis. The dry run is
registered as not counting, T0's template gave arm B its model's scope, and there is one session
per arm. T1-T6 have no prior models.
