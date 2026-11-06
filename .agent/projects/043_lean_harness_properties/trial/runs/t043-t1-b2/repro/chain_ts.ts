// chain_ts.ts — the host half of the end-to-end gate, on the REAL code, in this process's own
// environment (the "pane" environment the calling script sets up):
//
//   * `readHerdrEnvironment(process.env)`  src/tui/src/herdr-agent-state.ts:157, the TS gate,
//     exactly as `initHerdrReporter` calls it (:312);
//   * `buildChildEnv(...)`                 src/tui/src/runtime-process.ts:499, the allowlist
//     that decides which HERDR_* variables the AILANG runtime will see.
//
// Prints one JSON line: { ts: <gate result or null>, child: { HERDR_*: value, ... },
// env: <the whole child environment, undefined entries dropped> }.
//
//   bun chain_ts.ts <tree root> <workdir>

const [treeRoot, workdir] = process.argv.slice(2);
if (!treeRoot || !workdir) throw new Error("usage: bun chain_ts.ts <tree root> <workdir>");

const { readHerdrEnvironment } = await import(`${treeRoot}/src/tui/src/herdr-agent-state.ts`);
const { buildChildEnv } = await import(`${treeRoot}/src/tui/src/runtime-process.ts`);

const ts = readHerdrEnvironment(process.env);
const childEnv = buildChildEnv(workdir, "default", "", "{}");
const child: Record<string, string> = {};
const env: Record<string, string> = {};
for (const [k, v] of Object.entries(childEnv)) {
  if (v === undefined) continue;
  env[k] = v as string;
  if (k.startsWith("HERDR_")) child[k] = v as string;
}
process.stdout.write(JSON.stringify({ ts, child, env }) + "\n");
