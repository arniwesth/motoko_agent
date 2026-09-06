# The herdr extension's run file and the operator's plan file describe the same work and disagree

## Status

open

## Branch

`arniwesth/013-dst-architecture-adr` (surfaced during the PLAN-001 live run, 2026-09-05/06)

## Description

Two dagr run files were live for the same work:

- `.dagr/run-plan001.json` — the operator's plan, 11 tasks with deps, maintained by the
  orchestrating session by hand (edit a copy, `dagr check --strict --json`, `mv`). A dagr pane was
  open on it before the session started.
- `.dagr/run-w3-p5-1788624394725.json` — written by `motoko-ext-herdr` per
  `DESIGN-dagr-as-delegation-view.md` §2, one task per `Delegate` call, keyed by the extension's
  own pane and session. Under `HERDR_DAGR_PANE=1` the extension opened a second dagr pane (w3:pG)
  on it at the first delegation. That is the "yet another dagr view" the user objected to.

They drift because they are updated from different observations. The orchestrator settles a task
in the plan file when it decides the task is done, including when it takes the work over itself.
The extension settles its row only when `DelegateCheck` observes the answer file or a dead pane.
After a takeover nobody calls `DelegateCheck` again, so the extension's row stays `working`
forever.

## Evidence

At 2026-09-06 08:35 the extension's file records as `working`:

| extension task | plan file says | pane |
|---|---|---|
| `mot-dlg-1788625724912` (P0, claude kind) | P0·a1 `failed`, P0 `done` via a2 | w3:pH, gone since 16:31 the previous day |
| `mot-dlg-1788637404283` (INV write phase) | INV·a2 `failed`, INV `done` via orchestrator a3 | w3:pN, gone |
| `mot-dlg-1788639194281` (P1A) | P1A·a1 `failed`, P1A `done` via orchestrator a2 | w3:pP, gone |
| `mot-dlg-1788683105871` (P1B) | P1B·a1 `working` | w3:pQ, live |

Only the last is true. Also in the first `Delegate` result of the session: a "stale delegation
record" note listing 11 tasks across five older `run-w1-*.json` files still recorded in flight on
panes that no longer exist. `.dagr/` holds 15 such files. Context:
`.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md` finding 4.

## Location

- `packages/motoko-ext-herdr/herdr.ail:559` `ensure_dagr_pane` — opens the view on
  `run_file(cfg.dagr_dir, cfg.own_pane, cfg.session_ms)`; the only suppression is the per-session
  marker file. It does not know an operator pane is already open on a different run file.
- `packages/motoko-ext-herdr/register.ail:122` — `dagr_pane` from `HERDR_DAGR_PANE`.
- `packages/motoko-ext-herdr/herdr.ail:996`–`1065` — the only place a motoko delegate's row is
  settled, and only when `DelegateCheck` is called.

## Fix

This needs the owner's decision first; the question is recorded in
`DESIGN-dagr-as-delegation-view.md` §10. The two candidate shapes:

1. **The extension writes into the plan file.** `Delegate` takes an optional `dagr_task` naming a
   task id in an operator-supplied run file; the extension opens the attempt there instead of in
   its own file, and `DelegateCheck` settles it there. One file, one view, the plan's deps and
   owners intact. Larger change, and the extension must respect the plan file's contract
   (attempt numbering, `cause.followup`, `retry_of`).
2. **The extension keeps its file but stops opening a view when an operator view exists.** Detect
   an operator-owned dagr pane (the `.dagr/.pane` marker or `scripts/dagr-pane.sh`'s marker) and
   skip `ensure_dagr_pane`. Smaller change; the two files still drift, but only one is on screen.

Independent of that choice: **settle-on-exit** (already open as dagr design §8 item 4) would have
closed three of the four stale rows here, and an orphan sweep that also marks rows `lost` when the
pane is gone would close the older 11.

## Non-goals

- Do not have the orchestrating model edit the extension's run file. That is the model-as-producer
  path the dagr design rejected.

## Progress (2026-09-06)

Status stays **open**. **Option B is implemented; the drift is not fixed** — the
two run files still describe the same work and still disagree. What changed is
that only one of them is on screen, which is the half the operator objected to.
Option A (the extension writing attempts into an operator-supplied plan file) is
still the answer to the drift and still needs the owner's decision in
`DESIGN-dagr-as-delegation-view.md` §10. Settle-on-exit and the orphan sweep for
the older 11 rows are likewise untouched.

Commit `PLAN-001 live-run fix 4: yield the dagr view to the operator's` on
`arniwesth/013-dst-architecture-adr`.

`herdr.ail:ensure_dagr_pane` now consults `operator_view_open` before it opens
anything: if `.dagr/.pane` — the sentinel `scripts/dagr-pane.sh` writes when the
operator opens a view by hand — names a pane, the id goes through `herdr pane
get` and must still answer `"label":"dagr"`. If it does, the extension yields:
nothing opened, nothing said, **and no marker written**.

Three judgements the issue did not settle:

- **The marker is probed, not trusted.** A present `.dagr/.pane` says a view was
  opened once, not that it is still up, and pane ids are reused. A stale marker
  taken at face value would suppress the extension's view for the rest of the run
  with nothing on screen and nothing said — the more expensive failure of the
  two. The probe is the same test that script's own `close_marked` makes.
- **No marker is written on the yield branch**, so the decision is re-taken on the
  next `Delegate`: close the operator's view and the extension opens its own.
  This is the one path through `ensure_dagr_pane` where at-most-once does not
  apply, because nothing was opened to be once about.
- **It yields silently**, per the task spec — including dropping the
  `scripts/dagr-pane.sh` fallback sentence, which would be strange advice to
  someone already looking at a dagr view.

Cost: one `herdr pane get` per `Delegate`, and only until this session opens its
own view (after which the existing `pane_marker` short-circuit fires first) or the
operator's view is found gone.

Gate: `make verify_herdr_dagr_pane` grew case 6 — an operator view present, the
extension yields, `plugin pane open` absent from the call log and `pane get
w1:pOP` present in it. Asserting the probe and not merely the absence of the open
is deliberate: the silent-stale-suppression failure is invisible to a case that
only checks that no pane appeared.
