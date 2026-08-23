import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { buildChildEnv } from "./runtime-process.js";

// The herdr pane environment has to reach the AILANG runtime, and nothing else
// in the tree would notice if it stopped.
//
// `packages/motoko-ext-herdr` gates itself on HERDR_ENV / HERDR_BIN_PATH /
// HERDR_PANE_ID read through `std/env` inside `register_with_config`. That runs
// in the AILANG runtime, which is a GRANDCHILD of the herdr pane — the pane
// starts the TUI, and `buildChildEnv` decides what the TUI's child sees. It is
// an explicit allowlist, so a variable that is not named there is dropped.
//
// The failure this guards is silent in both directions: the extension loads,
// reports itself loaded, and advertises no tools, so the model is simply never
// offered Delegate and says it does not exist. Measured exactly that way on
// 2026-08-23 before the three variables were forwarded.

let workdir: string;
const KEYS = ["HERDR_ENV", "HERDR_BIN_PATH", "HERDR_PANE_ID"] as const;
const saved: Record<string, string | undefined> = {};

beforeEach(() => {
  workdir = fs.mkdtempSync(path.join(os.tmpdir(), "herdr-child-env-"));
  for (const k of KEYS) saved[k] = process.env[k];
});

afterEach(() => {
  for (const k of KEYS) {
    if (saved[k] === undefined) delete process.env[k];
    else process.env[k] = saved[k];
  }
  fs.rmSync(workdir, { recursive: true, force: true });
});

describe("buildChildEnv forwards the herdr pane environment", () => {
  it("carries all three variables when the TUI is running inside a pane", () => {
    process.env.HERDR_ENV = "1";
    process.env.HERDR_BIN_PATH = "/usr/local/bin/herdr";
    process.env.HERDR_PANE_ID = "w1:pA";

    const childEnv = buildChildEnv(workdir, "someprofile", "", "");

    expect(childEnv.HERDR_ENV).toBe("1");
    expect(childEnv.HERDR_BIN_PATH).toBe("/usr/local/bin/herdr");
    expect(childEnv.HERDR_PANE_ID).toBe("w1:pA");
  });

  // Absent, not empty. The extension's gate tests `HERDR_ENV == "1"`, so an
  // empty string would also close it — but forwarding empties would make the
  // child env lie about what the pane provided, and `--current requires
  // HERDR_PANE_ID` is a plain-text herdr failure rather than a clean one.
  it("omits them entirely outside a pane rather than forwarding empties", () => {
    for (const k of KEYS) delete process.env[k];

    const childEnv = buildChildEnv(workdir, "someprofile", "", "");

    for (const k of KEYS) expect(k in childEnv).toBe(false);
  });
});
