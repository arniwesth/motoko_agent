# Handoff: implement F-5 (orphan ownership) and the dagr producer

Date: 2026-08-31
Status: **Worked 2026-08-31. MOT-133, MOT-136 and MOT-134 are implemented on branch
`arniwesth/mot-133-f-5-extension-side-tag-delegates-at-spawn-report-stale`; MOT-135 (tolerant
envelope) is untouched, as intended. Two of the three "stop and report" triggers fired and are
recorded below. One line of D2 could not be applied from inside the agent container —
[`PATCH-agent-confined-reap-on-exit.md`](PATCH-agent-confined-reap-on-exit.md).**

## What the build-order measurements found

1. **Tokens do NOT survive a herdr server restart** — and neither do the delegates, which are killed
   with it. The sweep is therefore same-server-lifetime, which is the whole of its population; no
   name-based fallback was substituted.
   [`MEASUREMENTS-2026-08-31-token-survival.md`](MEASUREMENTS-2026-08-31-token-survival.md).
2. **The v0.3.1 validator rejects a kind-less task** (`E111`), so the `task` fallback this handoff
   named is the one in force — and it found a second requirement the design never mentioned, `W205`
   on a blocked task with no unblock owner.
   [`MEASUREMENTS-2026-08-31-dagr-contract.md`](MEASUREMENTS-2026-08-31-dagr-contract.md).
3. `agent list` output size never became a question: the sweep enumerates `pane list` instead, which
   is a strict superset at the same one-call cost.

Everything below is the brief as it was written, kept for the record.
Specs (read in this order — they ARE the spec, this page only sequences them):
1. [`DESIGN-f5-orphan-ownership.md`](DESIGN-f5-orphan-ownership.md) — accepted 2026-08-31, §6 has
   the decisions.
2. [`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) — three revision
   passes, §9 is the change log; §3–§5 are the load-bearing tables.
3. [`MEASUREMENTS-2026-08-31-failure-codes.md`](MEASUREMENTS-2026-08-31-failure-codes.md) — the
   `lost` classification.

## Linear

| issue | what | blocked by |
|---|---|---|
| **MOT-133** | extension: tag at spawn + startup sweep (report-only default) | — |
| **MOT-134** | TUI: `HERDR_REAP_ON_EXIT` reap on clean exit; `agent_confined` sets it to 1 | shares the `mot-owner` value with MOT-133 — coordinate, either order |
| **MOT-136** | dagr producer + the one-shot `retry_of`/`task_kind` schema migration | MOT-133 (same `do_delegate` seam; tag-first or together) |
| **MOT-135** | tolerant answer envelope (follow-up, low) | independent; needs its own compliance measurement |

## Build order

1. **MOT-133 first.** Before relying on the sweep, take the one outstanding measurement: does a
   `report-metadata` token survive a herdr **server** restart? (2026-08-31 measured persistence
   within a running server only.) Record it in a MEASUREMENTS file either way; if tokens do not
   survive, the sweep degrades to same-server-lifetime and the doc must say so.
2. **MOT-136 second** (or in the same change as MOT-133). The producer's `attempt_started` write
   and the tag call sit in the same post-success branch of `do_delegate`.
3. **MOT-134 any time after the `mot-owner` value is fixed.** The session-start-ms must be one
   clock shared across the TS/AILANG boundary (suggest: TUI mints it, exports `MOTOKO_SESSION_MS`;
   this is a MOT-118-class duplicated rule — name it in both files).

## Facts the implementer must not rediscover

- **Effects/ports:** everything goes through `ExtPorts` (`file_read`/`file_write`/`dir_make`/
  `clock_now`/`tool_handle`); `run_herdr` wraps `tool_handle` with the argv-safety guard. No new
  ABI slot (017 prices one at 16 packages). `std/fs` has no rename (ailang#897): publish is
  `writeFile(tmp)` + `mv` via `tool_handle`, ≈0.8 ms.
- **Two check lifecycles**, not one: `do_check` (wait→get→read, four branches, `idle` IS settled)
  and `do_check_motoko` (read-first, answer file is the only terminal signal, startup-`idle` never
  settles). MOT-131's early read is merged; both paths now read the file before failing on a gone
  agent. Producer tables: dagr design §3.2/§3.3.
- **`lost` gate:** `agent_not_found` from `agent wait` OR `agent get` ⇔ gone → attempt `lost`.
  `server_not_running` ⇔ herdr unwell → write nothing. Unlisted codes → write nothing.
- **Run file:** `.dagr/run-<own_pane>-<session>.json`, `"dagr": 3`, one writer, `path_within`
  guard before the first `dir_make`, existing-but-unparseable file is never overwritten.
- **Tokens:** readable back via `pane get`, `agent get`, and `agent list` (one-call sweep
  enumeration). TTL and `--clear-token` work.
- **Testing:** scripted-ports fixed-scenario tests, template `scripts/verify_mot131_early_answer.ail`
  + `make verify_herdr_check_answer` (gate on the script's exit code, not on grep matching a line).
  CI needs a pinned dagr: `herdr plugin install aemrebarut/herdr-dagr --ref v0.3.1` or the release
  binary — unpinned install fails without Cargo. Producer CI: every published fixture document
  through `dagr check --strict --json`.
- **Worktree trap:** `ailang.lock` pins path deps by ABSOLUTE path — in a secondary git worktree,
  `ailang run` loads the PRIMARY checkout's package sources. Verify package edits from the primary
  checkout, or re-point the lock locally (do not commit that).

## Scope fence

- **Do not reopen the §6 / §8 decisions** (tag format, visible-by-default, report-only sweep,
  `retry_of`+`task_kind` in one migration, free-text envelope). They are owner-signed, 2026-08-31.
- **Do not kill any pane without the `mot-owner` token matching** — never on name, kind, or argv
  (P2-6), and never outside `HERDR_REAP_ON_EXIT`/`HERDR_SWEEP_STALE`.
- **Do not emit `verified`, `asserted`, `model`, `last_output_at`, or `queued_input`** from the
  producer. Every one is a documented refusal (dagr design §3.1, §3.4, §4).
- **Do not add an ABI slot**; settle-on-exit (dagr §8 item 4) stays open and stays the owner's.
- **Do not validate the run file at runtime**; validity is CI's job (dagr §5's transaction note).

## Stop and report — do not decide inline

- Tokens do NOT survive a herdr server restart (build-order item 1) and the sweep therefore cannot
  meet its design: report with the measurement, do not substitute a name-based rule.
- The v0.3.1 validator rejects a kind-less task (dagr §3.1's one unverified assumption): fall back
  to `task` and say so in the commit; if it rejects that too, stop.
- `agent list` output exceeds what a sweep can parse in one `run_herdr` call (output caps): report;
  do not page silently.
