// runner_signal.ts — what the PRODUCTION runner (createHerdrRunner, wake-waiter.ts:476) hands the
// failure vocabulary when the herdr child dies by a signal, and what both twins make of it.
//
//   bun runner_signal.ts x1      exit 1 when herdrFailureCode returns "" (its "success" value,
//                                wake-waiter.ts:128) for a result that is a failure: non-zero
//                                exit, no spawnError. Witness: a child killed by SIGTERM.
//   bun runner_signal.ts emit    print the runner's real results as gen.ts cases (for ail_eval)
//
// The "herdr" binary is /bin/sh, so no herdr is needed: `sh -c 'kill -TERM $$'` is a child that
// dies by a signal, exactly as an OOM-killed or externally killed herdr would.

import type { HerdrResult } from "../../tree/src/tui/src/wake-waiter.ts";

// T2_TS_MODULE: a patched copy instead of the tree (fixcheck/ only).
const modPath = process.env.T2_TS_MODULE ?? new URL("../../tree/src/tui/src/wake-waiter.ts", import.meta.url).pathname;
const { createHerdrRunner, herdrFailureCode, herdrMeansAgentGone } = (await import(modPath)) as typeof import("../../tree/src/tui/src/wake-waiter.ts");

const NOT_FOUND = `{"error":{"code":"agent_not_found","message":"x"}}`;
const scripts: Array<[string, string]> = [
  ["killed, no output", "kill -TERM $$"],
  ["agent_not_found printed, then killed", `printf '%s\\n' '${NOT_FOUND}' >&2; kill -TERM $$`],
  ["agent_not_found printed, exit 1 (control)", `printf '%s\\n' '${NOT_FOUND}' >&2; exit 1`],
];

const run = createHerdrRunner("/bin/sh");
const results: Array<[string, HerdrResult]> = [];
for (const [name, script] of scripts) results.push([name, await run(["-c", script], new AbortController().signal)]);

const mode = process.argv[2] ?? "x1";
if (mode === "emit") {
  results.forEach(([, r], i) => console.log(`${i}\t${r.code}\t${Buffer.from(r.stderr, "utf8").toString("base64")}`));
  process.exit(0);
}
let bad = 0;
for (const [name, r] of results) {
  const code = herdrFailureCode(r);
  const failure = r.spawnError === undefined && r.code !== 0;
  console.log(`${name}: runner -> ${JSON.stringify(r)}; herdrFailureCode=${JSON.stringify(code)} herdrMeansAgentGone=${herdrMeansAgentGone(r)}`);
  if (failure && code === "") {
    bad++;
    console.log(`  DEFECT: a failed call (exit ${r.code}) is given the success code ""`);
  }
}
process.exit(bad > 0 ? 1 : 0);
