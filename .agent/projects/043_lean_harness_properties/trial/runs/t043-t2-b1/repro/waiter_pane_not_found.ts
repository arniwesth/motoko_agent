// B1-T2-1 through the REAL waiter: herdr answers `agent get` with exit 1 and herdr's
// `pane_not_found` envelope. The header (wake-waiter.ts:22-24) says a non-zero exit other than
// `agent_not_found` is `host_error`, NEVER `lost`, as `means_agent_gone` decides; the waiter
// reports `lost` instead, with a detail that says "agent_not_found".
//
//   bun waiter_pane_not_found.ts <repo root>     exit 1 when the defect is present
import * as path from "path";
const repo = process.argv[2];
const ww = await import(path.resolve(repo, "src/tui/src/wake-waiter.ts"));
const PANE_NOT_FOUND = { code: 1, stdout: "", stderr: '{"error":{"code":"pane_not_found","message":"x"}}' };
// The row is seen first (wake-waiter.test.ts:18-22's ROW), then `agent get` fails.
const ROW = { code: 0, stderr: "", stdout: '{"id":"cli:agent:get","result":{"agent":{"agent_status":"working","pane_id":"w1:p1"},"type":"agent_info"}}' };
let calls = 0;
const reply: any = await new Promise((resolve) => {
  ww.startWakeWaiter(
    { type: "wake_request", request_id: "r", step: 1, attempt: 1,
      waits: [{ id: "d0", delegate_kind: "motoko", locator: { pane: "w1:p1" }, answer_path: "/nonexistent/answer.md", run_key: "k" }] },
    { herdr: async () => (++calls === 1 ? ROW : PANE_NOT_FOUND), readAnswer: () => null, watchAnswer: () => () => {}, now: () => 0,
      setTimer: (fn: () => void, ms: number) => { const t = setTimeout(fn, ms); return () => clearTimeout(t); },
      defer: (fn: () => void) => setImmediate(fn), pollMs: 1 },
    resolve,
  );
});
console.log("wake_reply:", JSON.stringify(reply));
const present = reply.outcome === "lost";
console.log(present ? "DEFECT PRESENT: pane_not_found buried as lost (means_agent_gone says not gone -> host_error)" : "absent: " + reply.outcome);
process.exit(present ? 1 : 0);
