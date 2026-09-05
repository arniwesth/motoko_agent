import { describe, it, expect, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { sessionStartMs, __setSessionMsForTests } from "./session-identity.js";
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
