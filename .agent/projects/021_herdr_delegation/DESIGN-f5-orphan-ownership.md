# Design: F-5 — who owns an orphaned delegate

Date: 2026-08-31
Status: **Proposal, awaiting owner sign-off on the three decision points in §6.**
Closes (if accepted): `RESEARCH-herdr-delegation-surface.md` §5.1 / §6 F-5 — the last dependency of
[`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) §8.
Provenance: §2 measured this session (2026-08-31, live herdr `w5`); everything else cites
`MEASUREMENTS-2026-08-22.md` (P2-6, M-extra-4, M-extra-6) or code.

## 1. The problem, restated with its sharpest edge

A pane does not die with its caller. A delegate whose Motoko exited keeps working, keeps burning
subscription quota, and keeps write access to the tree — and P2-7's argv decision makes the leaked
object an **unattended, unsandboxed agent with full tree and credential access**
(`MEASUREMENTS-2026-08-22.md` §"One consequence"). The current code closes panes on terminal
outcomes (`do_check`, both paths, and every `do_delegate` setup-failure branch), so orphans arise in
exactly three ways:

- O1. Motoko exits (or crashes) with delegates still working;
- O2. the model calls `Delegate` and never polls (`DESIGN-dagr` §6's no-poll case);
- O3. a delegate is `blocked` forever — `do_check` reports it and deliberately leaves it open.

## 2. Measured this session (2026-08-31)

2.1 **`pane report-metadata --token` is a durable, readable ownership tag.**
`herdr pane report-metadata <pane> --source <id> --token k=v` persists; the token reads back in
`pane get` (`.metadata.tokens`), in `agent get`, and — decisively — in **`agent list`**, so a sweep
enumerates every candidate with its tokens in ONE call. `--ttl-ms` and `--clear-token` work.
*Not measured:* survival across a herdr server restart.

2.2 **`pane process-info` exposes argv/cwd** of a pane's processes — enough to *suspect* a delegate,
never to prove one. Heuristic only; P2-6 rules it out as a kill gate.

2.3 **The TUI already owns an exit seam.** `initHerdrReporter` registers `exit`, `SIGINT` and
`SIGTERM` handlers (`src/tui/src/herdr-agent-state.ts`, `releaseHerdrReporter`) — host-side
TypeScript, where the ABI's missing session-end slot does not matter. SIGKILL and power loss run no
handler; anything at-exit therefore needs a startup-time backstop.

## 3. The ownership rule (the part every option needs)

`owns_name`'s prefix proves "a Motoko delegate", not "**this session's** delegate" — two concurrent
Motokos both own `mot-dlg-*`, so names alone cannot gate a kill across sessions (P2-6's rule:
positive proof, not "not me"; self-exclusion by `$HERDR_PANE_ID` is necessary and insufficient).

**Proposal: tag at spawn.** After a successful `agent start`/`pane run`, `do_delegate` issues one
extra call (~ms, same `run_herdr` path):

    pane report-metadata <delegate-pane> --source motoko-delegate \
      --token mot-owner=<own HERDR_PANE_ID>:<session-start-ms>

- `own_pane` is already in `HerdrConfig`; the session-start ms distinguishes a restarted Motoko in
  the same pane (the same run-identity component `DESIGN-dagr` §5 uses).
- Ownership test, cross-session capable: a pane is *this session's* delegate iff its `mot-owner`
  token equals this session's value; it is *some* Motoko's delegate iff the token exists.
- Failure to tag is a `note`-worthy degradation, not a delegation failure — an untagged delegate is
  merely unsweepable, which is today's status quo.

## 4. The three options from §5.1, priced against the rule

| option | what it needs | what it buys | what it risks |
|---|---|---|---|
| leave running, make visible | tagging + reporting (already: `Delegate` stdout names pane and kind; dagr liveness when the producer lands) | zero destroyed work; operator decides | quota burn and unattended write access continue — the §1 edge, accepted explicitly |
| kill on exit (TUI exit seam, §2.3) | tagging + host-side enumeration (`agent list`, filter own token) + `pane close` per hit (M-extra-6: 1 ms, complete) | O1 closed for clean exits | kills in-flight work the operator may have wanted to keep; does nothing for SIGKILL |
| sweep at startup | tagging + a policy for *stale* owners (token present, owner pane/session gone) | the SIGKILL backstop; also catches O2 leftovers from prior sessions | the only option that can destroy another session's work if the ownership test is wrong — P2-6's scenario |

None excludes the others; they compose into a policy ladder.

## 5. Recommendation: visible by default, reaping opt-in, sweep never silent

1. **Always tag** (§3). Prerequisite for every rung; no behavior change by itself.
2. **Default policy: leave running, visible.** Matches the parity justification already on record
   (the orchestrator is equally unsandboxed) and destroys nothing. Visibility is the delegation
   stdout today plus the dagr pane once the producer lands — whose run file, note, stays honest
   *because* liveness only claims what was observed (`DESIGN-dagr` §3.4).
3. **`HERDR_REAP_ON_EXIT=1` (opt-in): on clean exit, close panes whose `mot-owner` equals this
   session.** Lives in the TUI exit seam beside `releaseHerdrReporter`; enumerate via `agent list`,
   close by explicit pane id only. Blocked delegates (O3) are closed too — an unattended approval
   prompt after the operator left is a liability, not work in flight.
4. **Startup sweep: report always, kill never by default.** At registration, list panes carrying a
   `mot-owner` token whose owner is not this session and whose owner pane no longer exists; say so
   in the first tool result (and, later, as dagr `note` events). `HERDR_SWEEP_STALE=1` upgrades
   reporting to closing, still gated on the token — never on name, kind, or argv (P2-6).
5. **dagr consequence, resolving `DESIGN-dagr` §8's sequencing:** with 1–4, a producer run file can
   no longer silently assert in-flight work across a crash — the next session's sweep *sees* the
   stale owner and can record it. The producer's task for a stale-owned pane is `lost`-adjacent but
   distinct: the pane is alive, the orchestrator is gone. Record it as a `note` on the old file (or
   leave the old file untouched and report only), never as a fabricated settlement — the old run
   file belongs to the dead session's writer, and §5's one-writer rule survives.

## 6. Decision points for the owner

- **D1.** Accept the tag format `mot-owner=<pane>:<session-ms>` and tagging-as-degradable (§3)?
- **D2.** Accept the default of *leave running, visible* with reaping opt-in via
  `HERDR_REAP_ON_EXIT` (§5.2–5.3)? The alternative — reap by default — is defensible on the §1
  edge; it just destroys in-flight work by default to get there.
- **D3.** Accept that the startup sweep reports by default and kills only under
  `HERDR_SWEEP_STALE=1` (§5.4)?

## 7. Explicitly out of scope

- Settle-on-exit for the *run file* (dagr §8 item 4) — same seam, different question.
- Token survival across herdr server restart (§2.1) — measure before relying on the sweep in
  long-lived servers.
- O2 (never-polled but caller still alive): not an orphan; the dagr producer's `note` covers it.
