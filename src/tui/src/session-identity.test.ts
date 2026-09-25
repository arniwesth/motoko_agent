import { describe, it, expect, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import {
  sessionStartMs,
  sessionIdentity,
  sessionResumeCount,
  bumpSessionResumeCount,
  __setSessionMsForTests,
  __setSessionIdentityForTests,
} from "./session-identity.js";
import { buildChildEnv } from "./runtime-process.js";
import { exitManifestPath, currentExitManifestPath, __setSessionNonceForTests } from "./exit-actions.js";

// WHAT THIS FILE STOPPED TESTING, and why that is the point.
//
// Through ABI 6.0 this was `herdr-owner-token.test.ts`, and most of it pinned a TypeScript copy of
// the delegate ownership token FORMAT against its AILANG twin — a duplication the two compilers
// could not see across, asserted by hand in both places. At 7.0 the TUI no longer builds that
// token: `packages/motoko-ext-herdr` publishes exit actions carrying the key and value it wrote,
// and `exit-actions.ts` only compares strings it was handed. There is one definition of the format
// again, so there is nothing left to pin.
//
// What remains is the half that was never duplication: the host mints the session clock, because
// only the host can.

afterEach(() => {
  __setSessionMsForTests(null);
  __setSessionNonceForTests(null);
  __setSessionIdentityForTests(null);
});

describe("the session clock is minted once per TUI process", () => {
  // The runtime is spawned per task. A clock read inside an extension would mint a new identity
  // for every task in one session, and anything keyed by it — the ownership token, the dagr run
  // file, the exit manifest — would be unrecognisable to the next task. The failure is invisible,
  // because "nothing of mine" is also what a clean session looks like.
  it("returns the same value across calls", () => {
    const first = sessionStartMs();
    expect(sessionStartMs()).toBe(first);
    expect(sessionStartMs()).toBe(first);
  });

  it("reaches the AILANG runtime as MOTOKO_SESSION_MS", () => {
    __setSessionMsForTests(1756000000000);
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-session-identity-"));
    try {
      const childEnv = buildChildEnv(workdir, "someprofile", "", "");
      expect(childEnv.MOTOKO_SESSION_MS).toBe("1756000000000");
    } finally {
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });

  // The manifest the exit dispatcher reads is keyed by the same clock, and the runtime is told
  // where it is rather than deriving it. Both halves are asserted here because the pair is the
  // contract: a child writing one path while the parent reads another fails silently and looks
  // exactly like "no extension declared an intent".
  // REVIEW FINDING 10. Two Motokos started in the same millisecond in one checkout used to share
  // both the manifest and its `.tmp`, so one could publish over the other, execute the other's
  // actions, or break the write-tmp-then-rename atomicity by sharing the temporary inode.
  it("distinguishes two sessions that started in the same millisecond", () => {
    const workdir = "/w";
    __setSessionNonceForTests("aaaaaaaaaaaaaaaa");
    const first = exitManifestPath(workdir, 1756000000000);
    __setSessionNonceForTests("bbbbbbbbbbbbbbbb");
    const second = exitManifestPath(workdir, 1756000000000);

    expect(first).not.toBe(second);
    expect(`${first}.tmp`).not.toBe(`${second}.tmp`);
  });

  it("names one exit manifest per session, and hands the runtime that name", () => {
    // Both pinned BEFORE buildChildEnv, because it is buildChildEnv that mints them: setting the
    // nonce afterwards would compare a pinned expectation against a name already memoized at
    // random, which is a test that fails for the wrong reason.
    __setSessionMsForTests(1756000000000);
    __setSessionNonceForTests("deadbeefdeadbeef");
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-session-identity-"));
    try {
      const childEnv = buildChildEnv(workdir, "someprofile", "", "");
      const expected = exitManifestPath(workdir, 1756000000000);

      expect(childEnv.MOTOKO_EXIT_MANIFEST).toBe(expected);
      expect(currentExitManifestPath()).toBe(expected);
      expect(expected.endsWith(path.join(".motoko", "exit", "manifest-1756000000000-deadbeefdeadbeef.json"))).toBe(true);
      // The runtime writes through AILANG_FS_SANDBOX, which is pinned to the workdir: a manifest
      // outside it is a fatal execution failure rather than a recoverable error.
      expect(expected.startsWith(path.resolve(workdir))).toBe(true);
      // `writeFileResult` does not create parents, so the directory has to exist before the first
      // publish or every turn's manifest silently fails to be written.
      expect(fs.existsSync(path.dirname(expected))).toBe(true);
    } finally {
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });
});

// ADR-003 v6.1 D5 — ONE SESSION ID, and the repair of the issue's two ids.
//
// Before this, the host named the JSONL log after MOTOKO_SESSION_ID when the eval-harness adapter
// happened to set one and after an ISO timestamp otherwise, while the child minted its own from a
// clock read it could not share (`session.ail`'s `derive_session_id`). Interactively those two
// never matched. The journal cannot live with that: its directory, its header and every `run_id`
// in it are keyed by the session, and a resume looks the session up by name.
describe("the session id is minted once and reaches the child", () => {
  it("returns the same value across calls", () => {
    __setSessionIdentityForTests(null);
    delete process.env.MOTOKO_SESSION_ID;
    const first = sessionIdentity();
    expect(sessionIdentity()).toBe(first);
    expect(first).toMatch(/^session_\d+-[0-9a-f]{16}$/);
  });

  // An id supplied from outside WINS: it is the whole point of the variable, and minting over it
  // would orphan the journal the caller named. That is the adapter's case and, from P3 Part 5, a
  // `--resume` of an existing session.
  it("honours an inherited MOTOKO_SESSION_ID", () => {
    __setSessionIdentityForTests(null);
    process.env.MOTOKO_SESSION_ID = "session_from_the_adapter";
    try {
      expect(sessionIdentity()).toBe("session_from_the_adapter");
    } finally {
      delete process.env.MOTOKO_SESSION_ID;
    }
  });

  // `derive_session_id` returns the environment value when it is non-empty, so this line is what
  // makes both sides read one string.
  it("reaches the AILANG runtime as MOTOKO_SESSION_ID", () => {
    __setSessionIdentityForTests("session_pinned-0123456789abcdef");
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-session-identity-"));
    try {
      expect(buildChildEnv(workdir, "p", "", "").MOTOKO_SESSION_ID).toBe("session_pinned-0123456789abcdef");
    } finally {
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });

  // D5's `resume_count`: the host's counter, 0 on a fresh spawn and incremented on every `--resume`
  // spawn. The child reads it AMBIENTLY (`rpc.ail`'s `resume_count_env`) rather than through a
  // `ports.env_get`, because five DST fixtures pin the exact key set the policy init reads and a
  // sixth key would make all five red (PLAN-003 §0.8). It is the middle field of
  // `run_id = <session_id>.r<resume_count>.<run_ordinal>`.
  it("forwards a resume count that starts at zero and the host increments", () => {
    __setSessionIdentityForTests("session_pinned-0123456789abcdef", null);
    delete process.env.MOTOKO_RESUME_COUNT;
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-session-identity-"));
    try {
      expect(sessionResumeCount()).toBe(0);
      expect(buildChildEnv(workdir, "p", "", "").MOTOKO_RESUME_COUNT).toBe("0");
      expect(bumpSessionResumeCount()).toBe(1);
      expect(buildChildEnv(workdir, "p", "", "").MOTOKO_RESUME_COUNT).toBe("1");
    } finally {
      __setSessionIdentityForTests(null);
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });

  // An inherited count is a resume that a supervising process already counted. Nonsense is 0 rather
  // than a throw: a bad environment must not be able to stop a session from starting.
  it("reads an inherited resume count and refuses nonsense", () => {
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-session-identity-"));
    try {
      __setSessionIdentityForTests("s", null);
      process.env.MOTOKO_RESUME_COUNT = "4";
      expect(sessionResumeCount()).toBe(4);
      __setSessionIdentityForTests("s", null);
      process.env.MOTOKO_RESUME_COUNT = "not a number";
      expect(sessionResumeCount()).toBe(0);
    } finally {
      delete process.env.MOTOKO_RESUME_COUNT;
      __setSessionIdentityForTests(null);
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });
});
