// Adversarial smoke for the path-doubling guard added in commit 5130eb7.
// Run: bun test/path-guard.test.ts
//
// The dispatcher's resolvePath should reject:
//   1. Paths that start with cwd-without-leading-slash (the doubling case)
//   2. Any absolute path (already covered, retesting for regression)
//
// And accept:
//   3. Plain relative paths (the happy path)

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

let pass = 0;
let fail = 0;

function check(name: string, fn: () => void) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
    pass++;
  } catch (e: any) {
    console.log(`  ✗ ${name}: ${e?.message ?? e}`);
    fail++;
  }
}

const SESSION = { cwd: "/Users/mark/dev/sunholo/motoko_explore/runs/foo/motoko_agent" };

// 1. The exact regression case: absolute-without-leading-slash mirrors cwd.
check("rejects 'Users/mark/.../foo' (the doubling regression)", () => {
  let threw = false;
  try {
    resolvePath(SESSION, "Users/mark/dev/sunholo/motoko_explore/runs/foo/motoko_agent/src/foo.ail");
  } catch (e: any) {
    if (!e.message.includes("missing leading slash")) {
      throw new Error(`wrong error message: ${e.message}`);
    }
    threw = true;
  }
  if (!threw) throw new Error("expected rejection, got silent acceptance");
});

// 2. Plain absolute path — already-existing guard, regression check.
check("rejects '/etc/passwd' (already-absolute)", () => {
  let threw = false;
  try {
    resolvePath(SESSION, "/etc/passwd");
  } catch (e: any) {
    if (!e.message.includes("absolute paths are not allowed")) {
      throw new Error(`wrong error message: ${e.message}`);
    }
    threw = true;
  }
  if (!threw) throw new Error("expected rejection, got silent acceptance");
});

// 3. Happy path: a normal relative path resolves under cwd.
check("accepts 'src/foo.ail' (relative — happy path)", () => {
  const out = resolvePath(SESSION, "src/foo.ail");
  if (out !== `${SESSION.cwd}/src/foo.ail`) {
    throw new Error(`unexpected resolution: ${out}`);
  }
});

// 4. Happy path: nested relative path resolves correctly.
check("accepts 'src/core/ext/mcp/mcp.ail' (relative, deep)", () => {
  const out = resolvePath(SESSION, "src/core/ext/mcp/mcp.ail");
  if (out !== `${SESSION.cwd}/src/core/ext/mcp/mcp.ail`) {
    throw new Error(`unexpected resolution: ${out}`);
  }
});

// 5. Edge case: path with the bare-cwd as a substring but NOT prefix should be allowed.
check("accepts 'src/Users/mark/.../foo' (cwd-substring, not prefix)", () => {
  // Path containing "Users/mark/..." but not starting with the bare cwd.
  const out = resolvePath(SESSION, "src/Users/mark/file.txt");
  if (!out.endsWith("src/Users/mark/file.txt")) {
    throw new Error(`unexpected resolution: ${out}`);
  }
});

// 6. Edge case: empty string returns empty (current behaviour).
check("returns '' for empty path (no-op short-circuit)", () => {
  const out = resolvePath(SESSION, "");
  if (out !== "") throw new Error(`expected '', got '${out}'`);
});

console.log(`\nResult: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
