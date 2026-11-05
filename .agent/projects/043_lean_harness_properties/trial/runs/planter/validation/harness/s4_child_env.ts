// End to end, the TUI half: the host process has `scenario`'s environment; print what its gate
// decides (readHerdrEnvironment(process.env)) and the HERDR_* variables buildChildEnv hands the
// runtime it spawns, as `KEY=VALUE` lines (JSON-quoted values).
const [tree, scenario] = process.argv.slice(2);
for (const k of Object.keys(process.env)) if (k.startsWith("HERDR_")) delete process.env[k];
const scenarios: Record<string, Record<string, string>> = {
  "s03": { HERDR_ENV: "1", HERDR_BIN_PATH: "/usr/local/bin/herdr", HERDR_PANE_ID: " " },
  "s04": { HERDR_ENV: "1", HERDR_PANE_ID: "w1:p2" },
  "control": { HERDR_ENV: "1", HERDR_BIN_PATH: "/usr/local/bin/herdr", HERDR_PANE_ID: "w1:p2" },
};
Object.assign(process.env, scenarios[scenario]);
const { readHerdrEnvironment } = await import(`${tree}/src/tui/src/herdr-agent-state.ts`);
const { buildChildEnv } = await import(`${tree}/src/tui/src/runtime-process.ts`);
const child = buildChildEnv(process.cwd(), "dogfood", "", "");
console.log(`TUI_ENV ${JSON.stringify(scenarios[scenario])}`);
console.log(`TUI_GATE ${readHerdrEnvironment(process.env) ? "ready" : "closed"}`);
for (const [k, v] of Object.entries(child)) if (k.startsWith("HERDR_") && v !== undefined) console.log(`CHILD ${k}=${JSON.stringify(v)}`);
