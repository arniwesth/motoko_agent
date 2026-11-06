// b_consequence.ts — what witness B (HERDR_BIN_PATH set to "") does downstream in the host,
// on the REAL module: `initHerdrReporter` accepts the environment and returns true ("running
// inside a herdr pane"), and every report it then fires spawns the empty path.
//
//   bun b_consequence.ts <tree root>
//
// Prints the return value, and what `child_process.spawn("")` does in this runtime (the call
// `fire` makes, herdr-agent-state.ts:291), outside the module's own try/catch.
import { spawn } from "child_process";
const [treeRoot] = process.argv.slice(2);
const m = await import(`${treeRoot}/src/tui/src/herdr-agent-state.ts`);
const ok = m.initHerdrReporter({ HERDR_ENV: "1", HERDR_PANE_ID: "w1:p7", HERDR_BIN_PATH: "" });
console.log(`initHerdrReporter -> ${ok}`);
try {
  const c = spawn("", ["pane", "report-agent"], { stdio: "ignore" });
  c.on("error", (e) => console.log(`spawn("") emitted error: ${e.message}`));
} catch (e) {
  console.log(`spawn("") threw: ${(e as Error).message}`);
}
