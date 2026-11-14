// gate_ts.ts — the TypeScript half of the P1.1 differential test.
//
//   bun gate_ts.ts <tree root> <cases.json>
//
// Calls the REAL `readHerdrEnvironment` (src/tui/src/herdr-agent-state.ts) on every case.
// A null in cases.json is an UNSET variable: the key is left out of the env object, so the
// function sees `undefined`, exactly as it would from process.env. One line per case:
//
//   <case index>|<T or F>|<cp length HERDR_ENV>|<cp length HERDR_BIN_PATH>|<cp length HERDR_PANE_ID>
//
// T means the gate returned non-null. Unset counts as length 0, matching the AILANG side's "".
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const root = process.argv[2];
const file = process.argv[3];
if (!root || !file) throw new Error("usage: bun gate_ts.ts <tree root> <cases.json>");
const mod = await import(resolve(join(root, "src/tui/src/herdr-agent-state.ts")));
const readHerdrEnvironment = mod.readHerdrEnvironment as (env: NodeJS.ProcessEnv) => unknown;

const { cases } = JSON.parse(readFileSync(file, "utf8")) as { cases: (string | null)[][] };
const cp = (s: string | null) => (s === null ? 0 : [...s].length);
const lines: string[] = [];
cases.forEach(([e, b, p], i) => {
  const env: NodeJS.ProcessEnv = {};
  if (e !== null) env.HERDR_ENV = e;
  if (b !== null) env.HERDR_BIN_PATH = b;
  if (p !== null) env.HERDR_PANE_ID = p;
  const r = readHerdrEnvironment(env) !== null ? "T" : "F";
  lines.push(`${i}|${r}|${cp(e)}|${cp(b)}|${cp(p)}`);
});
process.stdout.write(lines.join("\n") + "\n");
