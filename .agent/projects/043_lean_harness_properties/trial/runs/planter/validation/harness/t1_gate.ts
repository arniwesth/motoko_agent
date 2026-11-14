// P1.1, the TypeScript side: readHerdrEnvironment over the same cases as t1_gate.ail.
const tree = process.argv[2];
const { readHerdrEnvironment } = await import(`${tree}/src/tui/src/herdr-agent-state.ts`);
const g = (env: Record<string, string | undefined>) => (readHerdrEnvironment(env as NodeJS.ProcessEnv) ? "ready" : "closed");
console.log(`s01-witness ENV=1 BIN=<set,empty> PANE=a -> ${g({ HERDR_ENV: "1", HERDR_BIN_PATH: "", HERDR_PANE_ID: "a" })}`);
console.log(`s02-witness ENV=2 BIN=a PANE=a -> ${g({ HERDR_ENV: "2", HERDR_BIN_PATH: "a", HERDR_PANE_ID: "a" })}`);
console.log(`s02-witness' ENV=a BIN=a PANE=a -> ${g({ HERDR_ENV: "a", HERDR_BIN_PATH: "a", HERDR_PANE_ID: "a" })}`);
console.log(`control ENV=1 BIN=a PANE=a -> ${g({ HERDR_ENV: "1", HERDR_BIN_PATH: "a", HERDR_PANE_ID: "a" })}`);
console.log(`control ENV=<unset> BIN=a PANE=a -> ${g({ HERDR_BIN_PATH: "a", HERDR_PANE_ID: "a" })}`);
