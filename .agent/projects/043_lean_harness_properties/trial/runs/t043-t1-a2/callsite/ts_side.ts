// ts_side.ts — the TypeScript call sites, run under a REAL process environment.
//
//   bun ts_side.ts <tree root>         (run with the environment under test)
//
// Prints one JSON line:
//   gate   readHerdrEnvironment(process.env) !== null — exactly the decision initHerdrReporter
//          makes (herdr-agent-state.ts:312), without its side effects (no spawn, no hooks)
//   child  the HERDR_* entries of the REAL buildChildEnv (runtime-process.ts:499), i.e. what
//          the AILANG runtime child of this TUI process would see
import { resolve, join } from "node:path";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";

const root = process.argv[2];
if (!root) throw new Error("usage: bun ts_side.ts <tree root>");
const gateMod = await import(resolve(join(root, "src/tui/src/herdr-agent-state.ts")));
const rpMod = await import(resolve(join(root, "src/tui/src/runtime-process.ts")));
const gate = gateMod.readHerdrEnvironment(process.env) !== null;
// A throwaway workdir: buildChildEnv creates <workdir>/.motoko/exit for the exit manifest, and
// the tree must not be written. The workdir does not affect the HERDR_* entries, which are read
// from process.env alone (runtime-process.ts:630-634).
const workdir = mkdtempSync(join(tmpdir(), "t1-workdir-"));
const childEnv = rpMod.buildChildEnv(workdir, "p", "", "") as NodeJS.ProcessEnv;
rmSync(workdir, { recursive: true, force: true });
const child = Object.fromEntries(Object.entries(childEnv).filter(([k, v]) => k.startsWith("HERDR_") && v !== undefined));
console.log(JSON.stringify({ gate, child }));
