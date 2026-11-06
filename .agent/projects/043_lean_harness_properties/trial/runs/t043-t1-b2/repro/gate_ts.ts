// gate_ts.ts — calls the REAL `readHerdrEnvironment` (src/tui/src/herdr-agent-state.ts:157)
// once, on an environment whose HERDR_ENV, HERDR_BIN_PATH and HERDR_PANE_ID are copied from
// T1_HERDR_ENV, T1_HERDR_BIN_PATH and T1_HERDR_PANE_ID (absent stays absent, so "unset" and
// "set to empty" stay distinct), and prints the result as JSON (`null` when the gate is shut).
//
//   bun gate_ts.ts <tree root>

const [treeRoot] = process.argv.slice(2);
if (!treeRoot) throw new Error("usage: bun gate_ts.ts <tree root>");
const { readHerdrEnvironment } = await import(`${treeRoot}/src/tui/src/herdr-agent-state.ts`);

const env: Record<string, string> = {};
for (const k of ["HERDR_ENV", "HERDR_BIN_PATH", "HERDR_PANE_ID"]) {
  const v = process.env[`T1_${k}`];
  if (v !== undefined) env[k] = v;
}
process.stdout.write(JSON.stringify(readHerdrEnvironment(env)) + "\n");
