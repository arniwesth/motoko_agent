import { randomBytes } from "crypto";

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

/**
 * THIS SESSION'S ID, minted once, and the one the child agrees with (ADR-003 v6.1 D5).
 *
 * The issue this closes is "two ids": the host named the JSONL log after `MOTOKO_SESSION_ID` when
 * the eval-harness adapter happened to set one (`session-logger.ts`), and otherwise after an ISO
 * timestamp, while the child minted its OWN from a clock read it could not share
 * (`session.ail:1677-1684`, `derive_session_id`). Interactively those two never matched, so the
 * journal — whose path, header and every entry are keyed by the session — would have been written
 * under one id and reported under another.
 *
 * `buildChildEnv` forwards this as MOTOKO_SESSION_ID, and `derive_session_id` returns the
 * environment value when it is non-empty, so both sides now read ONE string. An id supplied from
 * outside (the adapter, a `--resume` of an existing session) wins: it is the whole point of the
 * variable, and minting over it would orphan the journal the caller named.
 *
 * WHY THE NONCE. The clock alone is not an identity — two Motokos started in the same millisecond
 * in one checkout would share a session directory, a journal and a lease, which is exactly the
 * collision `exitManifestPath` already carries a nonce for. Kept local rather than imported from
 * `exit-actions.ts` because that module imports THIS one; a shared nonce would be a cycle.
 */
let sessionId: string | null = null;

export function sessionIdentity(): string {
  if (sessionId === null) {
    const fromEnv = (process.env.MOTOKO_SESSION_ID ?? "").trim();
    sessionId =
      fromEnv !== ""
        ? fromEnv
        : `session_${sessionStartMs()}-${randomBytes(8).toString("hex")}`;
  }
  return sessionId;
}

/**
 * How many times this session has been resumed from its journal. ADR-003 D5: the host's counter,
 * `0` on a fresh spawn and incremented on every `--resume` spawn, forwarded as MOTOKO_RESUME_COUNT
 * and read ambiently by `rpc.run_with_config` (`rpc.ail:217`). It is the middle field of
 * `run_id = <session_id>.r<resume_count>.<run_ordinal>`, which is why the host owns it: the child
 * cannot count spawns it does not outlive.
 *
 * It replaces v4.1's `generation`, which counted snapshot writes that no longer exist.
 */
let resumeCount: number | null = null;

export function sessionResumeCount(): number {
  if (resumeCount === null) {
    const raw = Number.parseInt((process.env.MOTOKO_RESUME_COUNT ?? "").trim(), 10);
    resumeCount = Number.isFinite(raw) && raw >= 0 ? raw : 0;
  }
  return resumeCount;
}

/** Count a `--resume` spawn. PLAN-003 P3 Part 5 is the caller; Part 4 lands the counter it moves. */
export function bumpSessionResumeCount(): number {
  const next = sessionResumeCount() + 1;
  resumeCount = next;
  return next;
}

/** Test seam: pins (or with null, releases) the session id and the resume count. */
export function __setSessionIdentityForTests(id: string | null, count: number | null = null): void {
  sessionId = id;
  resumeCount = count;
}
