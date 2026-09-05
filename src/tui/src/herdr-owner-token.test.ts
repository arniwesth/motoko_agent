import { describe, it, expect, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import {
  OWNER_TOKEN_KEY,
  ownerTokenValue,
  ownerTokenArg,
  ownerPaneOf,
  sessionStartMs,
  __setSessionMsForTests,
} from "./herdr-owner-token.js";
import { buildChildEnv } from "./runtime-process.js";

// The F-5 ownership token exists in two languages and neither compiler can see the other.
//
// `owner_token_value` in `packages/motoko-ext-herdr/types.ail` WRITES the token when a delegate
// pane is spawned; this module READS it back at exit to decide what may be closed. A drift between
// them is silent in the worst direction: the reaper simply matches nothing, every delegate looks
// foreign, and the orphans it exists to catch survive. So the format is asserted here against the
// literal strings the AILANG side's own `tests [...]` block asserts, and those two lists must be
// edited together (a MOT-118-class duplication).

afterEach(() => __setSessionMsForTests(null));

describe("the ownership token format matches its AILANG twin", () => {
  it("builds `<pane>:<session ms>`, the same value types.ail asserts", () => {
    expect(ownerTokenValue("w1:p1", "1756000000000")).toBe("w1:p1:1756000000000");
    expect(ownerTokenValue("w1:p1", 1756000000000)).toBe("w1:p1:1756000000000");
  });

  it("builds the --token argument with the key herdr indexes it by", () => {
    expect(OWNER_TOKEN_KEY).toBe("mot-owner");
    expect(ownerTokenArg("w1:p1", 1756000000000)).toBe("mot-owner=w1:p1:1756000000000");
  });

  // Pane ids contain a colon, so "the first field" is the wrong split and would
  // read `w1` as the owner pane of every delegate in the workspace.
  it("reads the pane half back from the LAST colon, not the first", () => {
    expect(ownerPaneOf("w1:p1:1756000000000")).toBe("w1:p1");
    expect(ownerPaneOf("w12:p3:1")).toBe("w12:p3");
  });

  // A token whose pane half cannot be read is not proof of anything, and the caller must be able
  // to tell that apart from a real pane id. Empty is that signal.
  it("returns empty for a value with no colon, rather than guessing", () => {
    expect(ownerPaneOf("nocolons")).toBe("");
    expect(ownerPaneOf("")).toBe("");
  });
});

describe("the session clock is minted once per TUI process", () => {
  // The runtime is spawned per task. A clock read inside the extension would mint a new identity
  // for every task in one session, and the exit-time reaper would then match none of its own
  // delegates — the failure is invisible, because "no delegates of mine" is also what a clean
  // session looks like.
  it("returns the same value across calls", () => {
    const first = sessionStartMs();
    expect(sessionStartMs()).toBe(first);
    expect(sessionStartMs()).toBe(first);
  });

  it("reaches the AILANG runtime as MOTOKO_SESSION_MS", () => {
    __setSessionMsForTests(1756000000000);
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "herdr-owner-token-"));
    try {
      const childEnv = buildChildEnv(workdir, "someprofile", "", "");
      expect(childEnv.MOTOKO_SESSION_MS).toBe("1756000000000");
    } finally {
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });
});
