import { spawnSync } from "child_process";
import { OWNER_TOKEN_KEY, ownerTokenValue, sessionStartMs } from "./herdr-owner-token.js";

/**
 * Close this session's delegate panes on the way out — opt-in, and token-gated.
 *
 * A herdr pane does not die with its caller. Motoko exits, its delegates keep working, keep
 * burning subscription quota, and keep unsandboxed write access to the tree. `motoko-ext-herdr`
 * closes a pane on every terminal outcome it observes, so the leak is exactly the delegates nobody
 * came back for: the model called `Delegate` and moved on, the operator quit mid-flight, or the
 * delegate is `blocked` on a prompt and `DelegateCheck` deliberately left it open.
 *
 * WHY THIS IS OFF BY DEFAULT (design D2). Reaping destroys in-flight work on every clean exit,
 * including the case the answer-file gate exists to honour — quit Motoko, the delegate finishes
 * anyway, the answer lands on disk and the next session reads it. The risk it mitigates is one the
 * parity record shows the operator has already accepted for the orchestrator itself. So the default
 * is "leave running, visible" and this runs only under `HERDR_REAP_ON_EXIT=1` — which
 * `agent_confined` sets for itself, because in a disposable container quota burn dominates and no
 * operator work lives in a pane.
 *
 * WHY IT CANNOT BE A NAME RULE. `mot-dlg-*` proves "a Motoko delegate", not "THIS Motoko's
 * delegate" — two concurrent sessions both spawn that prefix, and closing on the prefix would kill
 * the other one's work. The gate is the `mot-owner` token written at spawn by
 * `packages/motoko-ext-herdr` and nothing else: not the name, not the agent kind, not the argv.
 *
 * WHY IT ENUMERATES PANES AND NOT AGENTS. Measured 2026-08-31: a tokened pane with no agent row —
 * a motoko delegate whose inner run released its agent authority — is invisible to `agent list` and
 * visible in `pane list`, at the same one-call cost.
 *
 * WHAT IT CANNOT REACH, measured the same day: tokens do not survive a herdr SERVER restart. That
 * costs nothing here, because the same restart kills the delegates — there is no orphan left to
 * reap, only a fresh shell in a restored pane.
 */

/** How many panes one exit may close, so a wedged server cannot hold the process open indefinitely. */
export const REAP_LIMIT = 32;

/** Milliseconds any single herdr call at exit may take. Synchronous by necessity — see `reapOwnedPanes`. */
const CALL_TIMEOUT_MS = 1000;

export function buildPaneListArgs(): string[] {
  return ["pane", "list"];
}

export function buildPaneCloseArgs(paneId: string): string[] {
  return ["pane", "close", paneId];
}

interface PaneRow {
  pane_id?: string;
  tokens?: Record<string, string>;
}

/**
 * The pane ids this session owns, from `herdr pane list` output.
 *
 * Pure, and the whole ownership decision lives here: a pane qualifies only when its `mot-owner`
 * token equals THIS session's value exactly. Own pane excluded — Motoko is not its own delegate —
 * and unparseable output yields nothing rather than something.
 *
 * herdr writes its own tokens too (the sidebar pane carries `herdr-sidebar-explorer`), so the key
 * filter is not optional: "has tokens" was never the test.
 */
export function ownedPaneIds(
  listJson: string,
  ownPaneId: string,
  sessionMs: number | string = sessionStartMs(),
): string[] {
  const mine = ownerTokenValue(ownPaneId, sessionMs);
  let rows: PaneRow[];
  try {
    const parsed = JSON.parse(listJson) as { result?: { panes?: PaneRow[] } };
    rows = parsed?.result?.panes ?? [];
  } catch {
    return [];
  }
  if (!Array.isArray(rows)) return [];
  const ids: string[] = [];
  for (const row of rows) {
    const id = row?.pane_id;
    if (!id || id === ownPaneId) continue;
    if (row?.tokens?.[OWNER_TOKEN_KEY] === mine) ids.push(id);
  }
  return ids;
}

/** Test seam: replaces the two herdr calls. Returns stdout for a list, "" for a close. */
let runner: ((bin: string, args: string[]) => string) | null = null;

export function __setRunnerForTests(fn: ((bin: string, args: string[]) => string) | null): void {
  runner = fn;
}

function run(bin: string, args: string[]): string {
  if (runner) return runner(bin, args);
  try {
    // SYNCHRONOUS, like `releaseHerdrReporter` and for the same reason: an async spawn started
    // inside an 'exit' handler never runs, because the event loop is already closed. The timeout is
    // what keeps that from turning into a hang on a wedged herdr server.
    const out = spawnSync(bin, args, { encoding: "utf8", timeout: CALL_TIMEOUT_MS });
    return out.stdout ?? "";
  } catch {
    // Best-effort by construction: a surviving delegate pane is a smaller problem than a Motoko
    // that cannot exit.
    return "";
  }
}

/**
 * Close every pane carrying this session's ownership token. Returns the ids closed.
 *
 * A no-op unless `HERDR_REAP_ON_EXIT=1`. Safe to call more than once — the panes are gone after the
 * first pass, so the second finds nothing.
 */
export function reapOwnedPanes(
  env: NodeJS.ProcessEnv,
  bin: string,
  ownPaneId: string,
): string[] {
  if (env.HERDR_REAP_ON_EXIT !== "1") return [];
  if (!bin || !ownPaneId) return [];

  const ids = ownedPaneIds(run(bin, buildPaneListArgs()), ownPaneId);
  // Bounded, and the cap is announced rather than silent: a truncated sweep that reads as a
  // complete one is the failure mode worth avoiding.
  const targets = ids.slice(0, REAP_LIMIT);
  for (const id of targets) run(bin, buildPaneCloseArgs(id));
  if (ids.length > targets.length) {
    process.stderr.write(
      `motoko: closed ${targets.length} delegate panes at exit; ${ids.length - targets.length} left open (reap limit ${REAP_LIMIT})\n`,
    );
  }
  return targets;
}
