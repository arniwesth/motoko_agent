// waiter_outcome.ts — what finding A (the `_not_found` suffix rule) does to a REAL wake: the
// real startWakeWaiter, with only herdr injected (as wake-waiter.test.ts does).
//
// The module's own contract (wake-waiter.ts:22-24): "A herdr transport failure (spawn error,
// non-zero exit other than `agent_not_found`, unparseable output) is `host_error`, NEVER `lost`
// — the extension separates these at herdr.ail's `means_agent_gone`, and the host does too."
//
// Scenario per code X: a motoko one-shot delegate whose row is seen once (`agent get` ok), then
// `agent get` fails with exit 1 and herdr JSON `{"error":{"code":X}}`; and a claude delegate
// whose `agent wait` fails that way. No answer file. Expected by the contract: `lost` for
// agent_not_found only, `host_error` for every other code.
//
//   bun waiter_outcome.ts      exit 1 when any code other than agent_not_found yields `lost`

import type { HerdrResult, WaiterDeps, WakeReply } from "../../tree/src/tui/src/wake-waiter.ts";

const modPath = process.env.T2_TS_MODULE ?? new URL("../../tree/src/tui/src/wake-waiter.ts", import.meta.url).pathname;
const { startWakeWaiter } = (await import(modPath)) as typeof import("../../tree/src/tui/src/wake-waiter.ts");

const ROW: HerdrResult = {
  code: 0,
  stdout: '{"id":"cli:agent:get","result":{"agent":{"agent_status":"working","pane_id":"w1:p1"},"type":"agent_info"}}',
  stderr: "",
};
const fail = (code: string): HerdrResult => ({ code: 1, stdout: "", stderr: `{"error":{"code":"${code}","message":"x"},"id":"cli:agent:get"}\n` });

async function outcome(kind: string, code: string): Promise<WakeReply> {
  let gets = 0;
  const deps: WaiterDeps = {
    herdr: async (argv) => (argv[1] === "get" ? (++gets === 1 ? ROW : fail(code)) : fail(code)),
    readAnswer: () => null,
    watchAnswer: () => () => {},
    now: () => 1_000_000,
    setTimer: (fn, ms) => {
      const t = setTimeout(fn, ms);
      return () => clearTimeout(t);
    },
    defer: (fn) => setImmediate(fn),
    pollMs: 1,
  };
  return await new Promise<WakeReply>((resolve) => {
    const h = startWakeWaiter(
      { type: "wake_request", request_id: "r", step: 1, attempt: 1, waits: [{ id: "d0", delegate_kind: kind, locator: { pane: "w1:p1" }, answer_path: "/nonexistent/answer.md", run_key: "rk" }] },
      deps,
      (reply) => {
        h.cancel();
        resolve(reply);
      },
    );
  });
}

let bad = 0;
for (const kind of ["motoko", "claude"]) {
  for (const code of ["agent_not_found", "pane_not_found", "workspace_not_found", "session_not_found", "server_not_running"]) {
    const r = await outcome(kind, code);
    const expected = code === "agent_not_found" ? "lost" : "host_error";
    const ok = r.outcome === expected;
    if (!ok) bad++;
    console.log(`${ok ? "ok  " : "BAD "} ${kind.padEnd(6)} ${code.padEnd(20)} -> ${r.outcome} (contract: ${expected})${ok ? "" : `: ${r.detail}`}`);
  }
}
process.exit(bad > 0 ? 1 : 0);
