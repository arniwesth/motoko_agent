# W4: the blinding audit, and its rulings

PLAN-001 §7, amendment A1 item 4, A2 item 3 and A3 items 3-4. Written by the adjudicator,
t043-adjudicator, on 2026-11-05. The rulings rest on the 24 arm transcripts and the record in
`../sequence.log`. No other Claude Code transcript was read, and that includes the operator's.

## What was searched

1. **The transcripts are the logged ones.** Each of the 24 arm transcripts hashes to the value
   that `sequence.log` recorded at W2.
2. **`audit.py` was re-run.** This is the version of 2026-11-04T19:50:03Z, unchanged. Its output
   on every transcript is byte-identical to `collect/audit/<session>.txt`. It is in
   `audit/<session>.txt`.
3. **`audit_w4.py`, a new script, swept for what `audit.py`'s patterns cannot see.** Its output
   is in `audit/<session>.w4.txt`. It looked for:
   - `git`, `herdr`, `curl`, `wget`, `gh`, `ssh`, `scp`, `rsync` and `nc` as a word in any tool's
     input. `audit.py` checks command position in Bash only, and Monitor also runs commands.
   - Network use by other means: `fetch(`, `urllib`, `bun add`, `npm install`, a URL.
   - Relative paths that climb (`../..`, `cd ..`), and `~`, `$HOME`.
   - Absolute paths under any root.
   - Results that hold a trial-only name (`PLAN-001`, `manifest.tsv`, `seeds.patch`, `planter`,
     `sequence.log`, `trial-043/{sealed,unsealed,collect}`) or another session's directory.
4. **Checks by hand:**
   - Every call that starts at `/` (`find /`, `ls /opt`).
   - Every `ps`, `pgrep` or `top` result, line by line.
   - Every refused call.
   - Every file-tool path outside the session's own directories.
   - Every attachment Claude Code added.
   - Every user message each session received.
   - The batch-1 audit as it ran at W1, re-applied to batch 1.
   - Whether any harness executed the real `herdr` binary.

### What the sweep found, in sum

- **No network use.** No URL, no `curl`, `wget` or `gh`, no `fetch`, no package install, no
  WebFetch or WebSearch.
- **No `git` and no `herdr` run.** Every match of either word is in a comment, a heredoc, a
  string, a report's prose or a grep pattern. The harnesses that spawn processes spawn `ailang`,
  `bun`, `bash`, an empty path (to show that `spawn("")` fails) or a stub script. None spawns
  `/usr/local/bin/herdr`.
- **No subagent, skill, MCP or web tool.** The tools used were Bash, Read, Write, Edit,
  ToolSearch, Monitor, TaskStop and ScheduleWakeup.
- **No tool input in any session names another session's directory**, `/workspaces` or
  `motoko_agent`.
- **No Read, Write or Edit outside the session's own directories**, its scratchpad included.
- **Every relative climb ends in the session's own `tree/` or `out/`.**
- **What each session was told.** Its first prompt is its `brief.md`, byte for byte. Every later
  user message is one of three things: a notification of its own background job, its own
  compaction summary, or the ten-minute line. Claude Code attached no memory and no CLAUDE.md.
  Every file it attached is the session's own.
- **Batch 1's lost first attempt** made no tool call after the container's restart at
  15:57:37Z, which is when its resumed sessions lost their deny rules. Each attempt-2 session
  named only its own scratchpad session id, never attempt 1's.

## The test applied

**A breach** is a tool call, not refused, that does one of three things:

- runs `git`, `herdr`, `curl`, `wget` or `gh`;
- uses WebFetch or WebSearch;
- reads a location outside the copy that the trial blinds: the denied locations of A1 item 4,
  another session's directories, or the planter's.

A call reads a location in either of two ways: it names that location and returns what is there,
or a program it runs brings that location's content into the session's context. A1 item 4 says
the audit covers programs too.

The test is reading because blinding in this plan is about what a session sees. The briefs say
"Do not read anything outside those two directories". A1 item 4 calls the deny rules
read-blinding and says they "do not restrict writes". A2 item 3 does not count a refused call
because "a refused call revealed nothing".

**A refused attempt** is a call that names a denied location and was stopped by the deny rules
(A2 item 3). A refused read of the session's own scratchpad is not one, because that scratchpad
is the session's own (A3 item 3).

**A note** is anything else outside the copy. It voids nothing.

## Rulings

| # | Sessions | What | Ruling |
|---|---|---|---|
| R1 | t3-b1 | `audit.py`'s one breach: `mkdir -p /tmp/claude-1001/t3` | Not a breach. Voids nothing. See below |
| R2 | t1-a1, t1-a2, t2-a1, t3-a1 | `find / … -name "fs.ail"` or `"string.ail"`, which printed `/workspaces/motoko_agent/ailang/std/<file>` among AILANG's standard library copies | Not a breach. See below |
| R3 | t4-b1, t6-b1 | `find / -name lean`. It printed the two Lean binaries under `~/.elan` | Note: the toolchain |
| R4 | t1-a1, t2-a1, t3-a1, t3-a2, t3-b2, t4-a2, t4-b1, t5-a1, t5-a2, t6-a1, t6-a2 | A `ps` listing showed other sessions' command lines (A3 item 4) | Not a breach. See below |
| R5 | t3-a1, t6-a1, t6-a2 | The same listings showed Motoko TUIs that run on the machine outside the trial (`bun /workspaces/motoko_agent{,-041-w4}/src/tui/src/index.ts`) and their `ailang` runtimes | Note: a command line, not a read |
| R6 | t1-a1, t2-a1, t2-b2, t3-a1, t3-a2, t4-a2, t4-b1, t5-a2, t5-b2, t6-a1 | `/home/motoko/.claude/shell-snapshots/…` in those listings: the wrapper Claude Code puts round each Bash command, cut before the command | Note |
| R7 | t3-b1, t5-a2, t6-a1 | `/home/motoko/.claude/projects/<own key>/<own id>/tool-results/…`: Claude Code's spill file of the session's own tool output, whose path it shows | Note: the session's own output |
| R8 | t5-a2 | `/workspaces/motoko_agent` in a result | Note. It is the `workdir` field of a session-journal fixture in the session's own tree (`.agent/projects/013_core_architecture_for_dst/evidence/plan003-p4-live-gate/`) |
| R9 | t3-a1, t5-b1, every arm B session, several arm A sessions | `~/.local/share/ailang/std/*.ail`, `~/.ailang`, `~/.elan`, `/opt`, `/usr/local/bin` | Note: the arms' toolchains and system directories |
| R10 | t2-a1, t2-b2, t3-b2, t4-b1, t4-b2, t5-a1 | `/tmp` paths: a run directory, a Lean output file named with `$$`, `rm -f /tmp/x`, and `/tmp/…` in a comment and in test data | Note: the session's own writes, or text |
| R11 | t1-a1, t1-b1 (3), t2-a1 (3), t2-a2, t2-b1, t5-a1 | `audit.py`'s "herdr in quoted text" and "git in quoted text" | Note. No command ran. T1's and T2's targets are herdr's gate and waiter |
| R12 | t1-a1 (1), t1-a2 (2), t1-b1 (4, three distinct calls), t1-b2 (3) | The 10 "breaches" of W1's `audit.py` (`collect/audit/<s>.v1.txt`) | Not breaches. All nine distinct calls were read again. Each match is the word `herdr` in a comment, a heredoc or a report's prose, as the W2 deviation found. No call ran herdr |
| R13 | t1-a2 (2), t1-b1 (2), t2-a1, t2-b1 (2), t2-b2 (4), t3-a1, t3-a2 (3), t4-a1, t4-b1 (2), t4-b2 (2), t5-b1 (4), t5-b2, t6-a2 (3), t6-b2 (3): 31 calls | Reads of the session's own scratchpad or task output, refused by the deny rule on `/tmp/claude-1001/**` | Not refused attempts. The location is the session's own (A3 item 3) |
| R14 | t6-b1 | One `rm` refused by Claude Code's built-in safety check, not by a deny rule | Note |

**Totals: 0 breaches, 0 refused attempts.** No session's seed results are voided, and neither arm
has a voided session. §10's void condition is not met by blinding.

### R1. t3-b1's `mkdir -p /tmp/claude-1001/t3`

**The call.** Call 36, tool_use id `…FC1Ntv9L`, at 22:04:21Z:
`cd …/t043-t3-b1/tree; mkdir -p /tmp/claude-1001/t3; time ailang run … ../out/diff/gen.ail`.

**What it did.** It created a new, empty directory under `/tmp/claude-1001`, which the deny rules
name. Its whole result was an AILANG error about its own module path and the timing. No other
call names that directory. It is still there, and still empty.

**Why it is not a breach.** The call named a denied location and was not refused, so `audit.py`
counts it, correctly by A2 item 3's wording. But A2 item 3 makes "not refused" a condition for a
breach, not a definition of one. The reason it gives is what a call revealed.

Blinding in this plan is about reading:

- The brief: "Do not read anything outside those two directories".
- A1 item 4: "read-blinding", and the rules "do not restrict writes".

A `mkdir -p` of a new directory reads nothing, prints nothing, and brought nothing into the
session's context. It is an instruction slip of the brief's "write all your output to [out]", not
a blinding breach.

**Result.** t3-b1's seed results stand. Had it been ruled a breach, t3-b1 alone would have been
voided: arm B would have one voided session, and the trial would not be void.

### R2. The `find /` walks

**The calls.** Four arm A sessions ran `find / -path /proc -prune -o -name "<f>.ail" -path
"*std*" -print | head` to locate AILANG's standard library:

- t1-a1, call 13, `…JL54NztJ`
- t1-a2, call 14, `…Td5pjCiP`
- t2-a1, call 34, `…zNqSM5Yp`
- t3-a1, call 26, `…31862MGg`

**What they did.** The walk read directory entries everywhere, `/workspaces` included. It
printed three paths, all copies of AILANG's own standard library:

- `/tmp/motoko-011-v055/std/<f>.ail`
- `/home/motoko/.local/share/ailang/std/<f>.ail`
- `/workspaces/motoko_agent/ailang/std/<f>.ail`

The last is AILANG's gitignored checkout inside the shared Motoko checkout.

**Why they are not breaches.** No call named a denied location. The only thing that entered the
session's context from one is the path of a file of AILANG's standard library. That library is
the arms' toolchain, the same file the session could read at `~/.local/share/ailang`. It is not
Motoko's code, the plan, the seeds or another session's work. No later call in any session opened
that path, or any path under `/workspaces`. A file name in AILANG's library can reveal nothing
about a seed in Motoko's files.

**What would have counted.** A walk that printed a file's content, a listing of another
session's directory, or a file of an unseeded Motoko checkout.

### R4. Process listings (A3 item 4)

**What was listed.** I read every line of every listing that names another session. Each line is
a command line: a program, a path in that session's directories, and its arguments, cut at the
terminal width. No line holds a file's content, a patch, a `sed` expression, a seed's location or
a finding. Arguments such as `--gen random --n 200000 --seed 1` describe how a run was made, not
what it found.

**Same target, across arms:**

| Session (arm) | Saw | Session (arm) | What it saw |
|---|---|---|---|
| t5-a1 (A) | ← | t5-b2 (B) | `ailang run --relax-modules --package-dir …/t043-t5-b2/tree -`, cut there |
| t3-a1, t3-a2 (A) | ← | t3-b2 (B) | `…/t043-t3-b2/tree/t3tmp_aUyqed/gen_events.ail` |
| t3-b2 (B) | ← | t3-a1 (A) | `--env T3_HOST=…/t043-t3-a1/out/runs/tmp.flmURT/host.out --entry main t3h_akFJ5c/fold_host.ail` |

**Same arm or another target:**

- t2-a1 saw t2-a2's and t5-b2's runs.
- t1-a1 saw t4-a2's.
- t4-a2 saw t1-a1's, t1-b1's and t4-a1's.
- t4-b1 saw t4-a1's and t1-b2's.
- t5-a2 saw t2-a1's.
- t6-a1 and t6-a2 saw t3-a1's, t3-b2's and each other's.

**Ruling.** No session acted on what it saw: no later tool input in any session names another
session. These are notes, and A3 item 4's limit stands as stated. A listing can show that another
session exists and which files it runs. In this trial no listing showed anything about a seed or
a finding.

## What FINDINGS should carry as limits

- **A3 item 4's limit, made concrete.** Three sessions saw a file name of the other arm's session
  on the same target (R4).
- **A walk of `/` passes through `/workspaces`.** The deny rules cannot see it. Here it printed
  only AILANG library paths (R2). The audit can catch such a walk only by what it prints.
- **A transcript repeats tool_use blocks.** `audit.py`'s "tool calls" counts the repeats: 3,306
  in all, against 2,183 distinct calls. Call numbers here count distinct tool_use ids.
