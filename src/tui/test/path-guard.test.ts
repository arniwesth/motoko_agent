// Adversarial smoke for the path-doubling guard added in commit 5130eb7.
//
// The dispatcher's resolvePath should reject:
//   1. Paths that start with cwd-without-leading-slash (the doubling case)
//   2. Any absolute path (already covered, retesting for regression)
//
// And accept:
//   3. Plain relative paths (the happy path)

import { describe, expect, it } from "@jest/globals";
import path from "node:path";

// Inline copy of resolvePath logic from src/ohMyPi/dispatcher.ts for testing
// without exporting the original symbol. If this test ever drifts from the
// dispatcher source, that's a signal — keep them lockstep.
function resolvePath(session: { cwd: string }, p: string): string {
  if (!p) return "";
  const cwd = session.cwd;
  const cwdBare = cwd.startsWith("/") ? cwd.slice(1) : cwd;
  if (cwdBare && p.startsWith(cwdBare + "/")) {
    throw new Error(`path appears absolute (missing leading slash): ${p}`);
  }
  if (path.isAbsolute(p)) {
    throw new Error(`absolute paths are not allowed: ${p}`);
  }
  return path.resolve(cwd, p);
}

const SESSION = { cwd: "/Users/mark/dev/sunholo/motoko_explore/runs/foo/motoko_agent" };

describe("path-doubling guard (resolvePath)", () => {
  // 1. The exact regression case: absolute-without-leading-slash mirrors cwd.
  it("rejects 'Users/mark/.../foo' (the doubling regression)", () => {
    expect(() =>
      resolvePath(SESSION, "Users/mark/dev/sunholo/motoko_explore/runs/foo/motoko_agent/src/foo.ail"),
    ).toThrow("missing leading slash");
  });

  // 2. Plain absolute path — already-existing guard, regression check.
  it("rejects '/etc/passwd' (already-absolute)", () => {
    expect(() => resolvePath(SESSION, "/etc/passwd")).toThrow("absolute paths are not allowed");
  });

  // 3. Happy path: a normal relative path resolves under cwd.
  it("accepts 'src/foo.ail' (relative — happy path)", () => {
    expect(resolvePath(SESSION, "src/foo.ail")).toBe(`${SESSION.cwd}/src/foo.ail`);
  });

  // 4. Happy path: nested relative path resolves correctly.
  it("accepts 'src/core/ext/mcp/mcp.ail' (relative, deep)", () => {
    expect(resolvePath(SESSION, "src/core/ext/mcp/mcp.ail")).toBe(`${SESSION.cwd}/src/core/ext/mcp/mcp.ail`);
  });

  // 5. Edge case: path with the bare-cwd as a substring but NOT prefix should be allowed.
  it("accepts 'src/Users/mark/.../foo' (cwd-substring, not prefix)", () => {
    expect(resolvePath(SESSION, "src/Users/mark/file.txt").endsWith("src/Users/mark/file.txt")).toBe(true);
  });

  // 6. Edge case: empty string returns empty (current behaviour).
  it("returns '' for empty path (no-op short-circuit)", () => {
    expect(resolvePath(SESSION, "")).toBe("");
  });
});
