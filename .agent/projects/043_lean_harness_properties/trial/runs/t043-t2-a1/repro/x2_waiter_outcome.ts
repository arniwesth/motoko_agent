// x2_waiter_outcome.ts — X-2: wake-waiter.ts's header (:22-24): "A herdr transport failure
// (spawn error, non-zero exit other than `agent_not_found`, unparseable output) is `host_error`,
// NEVER `lost`". Executable statement: for a herdr failure whose code is not `agent_not_found`, the
// REAL waiter's reply outcome is `host_error`.
//
//   bun x2_waiter_outcome.ts [herdr error code, default pane_not_found]
//                                         (from the tree root; exit 1 = the defect is present)
//
// Everything is production code — `defaultWakeWaiterFactory`, i.e. `defaultWaiterDeps()` with the
// real `createHerdrRunner`, `readAnswerFile`, `watchAnswerFile` and clock — except the herdr binary,
// replaced through HERDR_BIN_PATH by stub/herdr-row-then-error: `agent get` reports the row,
// `agent wait` fails with exit 1 and herdr's JSON envelope carrying the given code. The delegate is
// claude, so the waiter reaches phase 2's `agent wait`. No answer file exists.
//
// Controls: `server_not_running` gives host_error (holds), `agent_not_found` is excluded by the
// property (it is the one code that means gone).

import * as fs from "fs";
import * as os from "os";
import * as path from "path";

// A harness fault (failed import, crash) must not read as "defect present": exit 2, never 1.
process.on("uncaughtException", (e) => { console.error(`harness fault: ${e?.stack ?? e}`); process.exit(2); });
process.on("unhandledRejection", (e) => { console.error(`harness fault: ${(e as Error)?.stack ?? e}`); process.exit(2); });

const errCode = process.argv[2] ?? "pane_not_found";
const root = process.cwd();
const here = path.dirname(new URL(import.meta.url).pathname);
process.env.HERDR_BIN_PATH = path.join(here, "stub/herdr-row-then-error");
process.env.HERDR_STUB_CODE = errCode;
const ww = await import(path.join(root, "src/tui/src/wake-waiter.ts"));

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "t2-x2-"));
const req = {
  type: "wake_request",
  request_id: "t2.x2",
  step: 1,
  attempt: 1,
  waits: [{ id: "d0", delegate_kind: "claude", locator: { pane: "w1:p1" }, answer_path: path.join(dir, "answer.md"), run_key: "rk" }],
};
const reply = await new Promise<{ outcome: string; detail: string }>((resolve, reject) => {
  const t = setTimeout(() => reject(new Error("no reply within 30 s")), 30_000);
  const h = ww.defaultWakeWaiterFactory(req, (rep: { outcome: string; detail: string }) => {
    clearTimeout(t);
    h.cancel();
    resolve(rep);
  });
});
fs.rmSync(dir, { recursive: true, force: true });
console.log(`herdr agent wait fails with exit 1, error.code ${JSON.stringify(errCode)}`);
console.log(`waiter reply: outcome=${reply.outcome} detail=${JSON.stringify(reply.detail)}`);
if (errCode === "agent_not_found") {
  console.log("X-2: not applicable (agent_not_found is the code that means gone)");
  process.exit(0);
}
const violated = reply.outcome !== "host_error";
console.log(`X-2 (non-agent_not_found failure is host_error, never lost): ${violated ? "VIOLATED" : "holds"}`);
process.exit(violated ? 1 : 0);
