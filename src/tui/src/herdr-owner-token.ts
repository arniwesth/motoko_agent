/**
 * The F-5 ownership token: who spawned a delegate pane.
 *
 * A herdr pane does not die with its caller, so a delegate whose Motoko exited keeps working,
 * keeps burning quota, and keeps write access to the tree. Closing one safely needs POSITIVE proof
 * of ownership — never "it is not mine", and never a name prefix, because two concurrent Motokos
 * both spawn `mot-dlg-*` panes. The proof is a herdr pane token written at spawn time:
 *
 *     pane report-metadata <pane> --source motoko-delegate --token mot-owner=<paneId>:<sessionMs>
 *
 * THIS FILE IS ONE OF TWO COPIES OF THAT FORMAT, and they must move together (a MOT-118-class
 * duplication). The other is `owner_token_value` in `packages/motoko-ext-herdr/types.ail`, which
 * WRITES the token from inside the AILANG runtime when `Delegate` spawns a pane; this copy READS
 * it back at exit to decide what this session may close. They cannot share an implementation —
 * different languages, different processes — so the seam is the string, and the string is here.
 *
 * WHY THE SESSION CLOCK IS MINTED IN TYPESCRIPT AND NOT IN AILANG. The runtime is spawned per
 * task, so a clock read inside the extension would produce a different session id for every task
 * in one Motoko session, and the exit-time reaper would then match none of its own delegates. The
 * TUI process outlives every runtime it spawns, so it is the only place a stable run identity can
 * come from. `buildChildEnv` forwards it as MOTOKO_SESSION_MS.
 *
 * MEASURED LIMIT, worth knowing before relying on any of this
 * (`.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-08-31-token-survival.md`): tokens do not
 * survive a herdr SERVER restart — and neither do the delegates, which are killed with it. So
 * ownership is good for one server lifetime, which is exactly as long as there is anything to own.
 */

/** herdr token key. The sweep filters on this and nothing else — herdr writes its own tokens too. */
export const OWNER_TOKEN_KEY = "mot-owner";

/** `--source` on the report. Display-only provenance; herdr keys the token by its own name. */
export const OWNER_TOKEN_SOURCE = "motoko-delegate";

let sessionMs: number | null = null;

/**
 * This Motoko session's start, in epoch milliseconds. Memoized: the value must be identical for
 * every runtime this TUI process spawns, or delegates from an earlier task in the same session
 * become unrecognisable to the reaper.
 */
export function sessionStartMs(): number {
  if (sessionMs === null) sessionMs = Date.now();
  return sessionMs;
}

/** Test seam: pins (or with null, releases) the session clock. */
export function __setSessionMsForTests(value: number | null): void {
  sessionMs = value;
}

/** The token VALUE: `<owner pane id>:<session start ms>`. Mirrors `types.owner_token_value`. */
export function ownerTokenValue(paneId: string, sessionMs: number | string): string {
  return `${paneId}:${sessionMs}`;
}

/** The `--token` ARGUMENT: `mot-owner=<value>`. Mirrors `types.owner_token_arg`. */
export function ownerTokenArg(paneId: string, sessionMs: number | string): string {
  return `${OWNER_TOKEN_KEY}=${ownerTokenValue(paneId, sessionMs)}`;
}

/**
 * The pane half of a token value.
 *
 * Pane ids contain a colon (`w1:p1`), so this is everything before the LAST colon, not the first
 * field. Returns "" for a value with no colon at all — which the caller must treat as "no proof",
 * not as "pane ''".
 */
export function ownerPaneOf(tokenValue: string): string {
  const cut = tokenValue.lastIndexOf(":");
  return cut <= 0 ? "" : tokenValue.slice(0, cut);
}
