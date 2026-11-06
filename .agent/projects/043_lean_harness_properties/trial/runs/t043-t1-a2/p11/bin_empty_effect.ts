// bin_empty_effect.ts — what the TypeScript side DOES with HERDR_BIN_PATH="" (A2-T1-2).
//
//   bun bin_empty_effect.ts <tree root>
//
// Runs the real readHerdrEnvironment and initHerdrReporter on {HERDR_ENV=1,
// HERDR_PANE_ID=w1:p7, HERDR_BIN_PATH=""} and shows that the reporter is installed with an
// empty binary, which node's spawn refuses: every report and the release are then dropped by
// `fire`'s catch, while initHerdrReporter has answered "running inside a herdr pane".
// Exit 1 when the gate admits the empty binary, 0 when it refuses it.
import { spawn } from "node:child_process";
import { resolve, join } from "node:path";

const root = process.argv[2] ?? process.cwd();
const mod = await import(resolve(join(root, "src/tui/src/herdr-agent-state.ts")));
const env = { HERDR_ENV: "1", HERDR_PANE_ID: "w1:p7", HERDR_BIN_PATH: "" } as NodeJS.ProcessEnv;
const gate = mod.readHerdrEnvironment(env);
console.log(`readHerdrEnvironment -> ${JSON.stringify(gate)}`);
let spawnResult = "spawned";
try {
  const c = spawn("", ["pane", "report-agent", "w1:p7"], { stdio: "ignore" });
  c.on("error", (e) => console.log(`spawn("") async error: ${(e as NodeJS.ErrnoException).code}`));
} catch (e) {
  spawnResult = `throws ${(e as NodeJS.ErrnoException).code ?? String(e)}`;
}
console.log(`spawn("", ...) ${spawnResult}  (fire() swallows this)`);
const inPane = mod.initHerdrReporter(env);
console.log(`initHerdrReporter -> ${inPane}`);
process.exitCode = gate !== null && gate.bin === "" ? 1 : 0;
