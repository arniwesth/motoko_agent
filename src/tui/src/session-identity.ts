/**
 * This Motoko session's identity: one clock, minted here, forwarded to every runtime it spawns.
 *
 * WHY THE HOST MINTS IT AND NOT THE EXTENSION. The AILANG runtime is spawned per task, so a clock
 * read inside an extension would produce a different session id for every task in one Motoko
 * session — and anything keyed by it (a delegate ownership token, a dagr run file, an exit-action
 * manifest) would then be unrecognisable to the next task and to the exit path. This process
 * outlives every runtime it spawns, so it is the only place a stable run identity can come from.
 * `buildChildEnv` forwards it as MOTOKO_SESSION_MS.
 *
 * WHAT THIS FILE USED TO BE, and why the rest of it is gone. Through ABI 6.0 this was
 * `herdr-owner-token.ts`, and it carried a second copy of the delegate ownership token FORMAT
 * (`<pane>:<session ms>`) so that the TUI's exit-time reaper could rebuild the same string the
 * extension had written — a MOT-118-class duplication across a language boundary that nothing
 * linked. At 7.0 the reaper is gone: `packages/motoko-ext-herdr` declares an `ExitIntent` and the
 * host executes the actions it publishes (`exit-actions.ts`), so both sides of every token
 * comparison now come from the ONE definition in `packages/motoko-ext-herdr/types.ail`
 * (`owner_token_value`). The duplication is not pinned by a twin test any more; it does not exist.
 *
 * The clock stays, because that half was never duplication — it is the host doing the one thing
 * only the host can do.
 *
 * MEASURED LIMIT worth knowing before relying on anything keyed by this
 * (`.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-08-31-token-survival.md`): herdr pane
 * tokens do not survive a herdr SERVER restart — and neither do the delegates, which are killed
 * with it. So a session identity is good for one server lifetime, which is exactly as long as
 * there is anything to own.
 */

let sessionMs: number | null = null;

/**
 * This Motoko session's start, in epoch milliseconds. Memoized: the value must be identical for
 * every runtime this TUI process spawns, or work recorded by an earlier task in the same session
 * becomes unrecognisable to the later ones and to the exit path.
 */
export function sessionStartMs(): number {
  if (sessionMs === null) sessionMs = Date.now();
  return sessionMs;
}

/** Test seam: pins (or with null, releases) the session clock. */
export function __setSessionMsForTests(value: number | null): void {
  sessionMs = value;
}
