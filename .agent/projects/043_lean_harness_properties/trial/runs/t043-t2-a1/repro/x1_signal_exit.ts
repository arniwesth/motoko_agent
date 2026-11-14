// x1_signal_exit.ts — X-1: herdrFailureCode's doc contract (wake-waiter.ts:128) is `"" on
// success`. Executable statement: for every HerdrResult the REAL production runner returns,
// herdrFailureCode(r) === "" implies the call succeeded (no spawnError and exit code 0).
//
//   bun x1_signal_exit.ts          (from the tree root; exit 1 = the defect is present)
//
// The input is not hand-built: it is what the REAL `createHerdrRunner` (wake-waiter.ts) returns
// for a herdr child that dies by a signal (stub/herdr-killed-by-signal, `kill -KILL $$`). The
// runner's `close` handler maps a null exit code to -1 and sets no spawnError, so the result is a
// failure with code -1; `herdrFailureCode` then reports it with the success code "", because it
// tests `r.code <= 0` where the AILANG twin tests `exit_code == 0`.

import * as path from "path";

// A harness fault (failed import, crash) must not read as "defect present": exit 2, never 1.
process.on("uncaughtException", (e) => { console.error(`harness fault: ${e?.stack ?? e}`); process.exit(2); });
process.on("unhandledRejection", (e) => { console.error(`harness fault: ${(e as Error)?.stack ?? e}`); process.exit(2); });

const root = process.cwd();
const here = path.dirname(new URL(import.meta.url).pathname);
const ww = await import(path.join(root, "src/tui/src/wake-waiter.ts"));

const run = ww.createHerdrRunner(path.join(here, "stub/herdr-killed-by-signal"));
const r = await run(["agent", "get", "w1:p1"], new AbortController().signal);
const code: string = ww.herdrFailureCode(r);
const succeeded = r.spawnError === undefined && r.code === 0;
console.log(`runner result: ${JSON.stringify(r)}`);
console.log(`herdrFailureCode = ${JSON.stringify(code)}, herdrMeansAgentGone = ${ww.herdrMeansAgentGone(r)}`);
const violated = code === "" && !succeeded;

// Not part of the verdict: what the production waiter reports for the same herdr (its phase-1
// `agent get`), to show where the empty code surfaces. The waiter's callers test `r.code === 0`
// themselves, so the outcome is still host_error; only the detail carries the empty code.
process.env.HERDR_BIN_PATH = path.join(here, "stub/herdr-killed-by-signal");
const reply = await new Promise<{ outcome: string; detail: string }>((resolve) => {
  const h = ww.defaultWakeWaiterFactory(
    { type: "wake_request", request_id: "t2.x1", step: 1, attempt: 1,
      waits: [{ id: "d0", delegate_kind: "claude", locator: { pane: "w1:p1" }, answer_path: "/nonexistent/t2-x1/answer.md", run_key: "rk" }] },
    (rep: { outcome: string; detail: string }) => { h.cancel(); resolve(rep); },
  );
});
console.log(`waiter reply for the same herdr: outcome=${reply.outcome} detail=${JSON.stringify(reply.detail)}`);

console.log(`X-1 ("" only on success): ${violated ? "VIOLATED: a failed call is given the success code" : "holds"}`);
process.exit(violated ? 1 : 0);
