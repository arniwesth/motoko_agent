// B1-T2-9 / B1-T2-2 through the REAL runner and the REAL waiter (wake-waiter.ts), no fakes in
// the code under test: `createHerdrRunner` spawns fake-herdr-killed.sh, which prints herdr's
// agent_not_found envelope and dies by SIGTERM. The runner reports `code: -1`, no spawnError,
// stderr + "killed by SIGTERM" (:513-514). `herdrFailureCode` then says "" (its doc comment:
// "on success"), and the wake_reply's detail reads "code )".
//
//   bun waiter_signal.ts <repo root>       exit 1 when the defect is present
import * as path from "path";
const repo = process.argv[2];
const ww = await import(path.resolve(repo, "src/tui/src/wake-waiter.ts"));
const bin = path.join(import.meta.dir, "fake-herdr-killed.sh");
const runner = ww.createHerdrRunner(bin);
const r = await runner(["agent", "get", "pane-d0"], new AbortController().signal);
console.log("runner result:", JSON.stringify(r));
console.log("herdrFailureCode:", JSON.stringify(ww.herdrFailureCode(r)), " herdrMeansAgentGone:", ww.herdrMeansAgentGone(r));
const reply: any = await new Promise((resolve) => {
  ww.startWakeWaiter(
    { type: "wake_request", request_id: "r", step: 1, attempt: 1,
      waits: [{ id: "d0", delegate_kind: "claude", locator: { pane: "pane-d0" }, answer_path: "/nonexistent/answer.md", run_key: "k" }] },
    { herdr: runner, readAnswer: () => null, watchAnswer: () => () => {}, now: () => 0,
      setTimer: (fn: () => void, ms: number) => { const t = setTimeout(fn, ms); return () => clearTimeout(t); },
      defer: (fn: () => void) => setImmediate(fn), pollMs: 1 },
    resolve,
  );
});
console.log("wake_reply:", JSON.stringify(reply));
const present = r.code === -1 && r.spawnError === undefined && ww.herdrFailureCode(r) === "" && /code \)/.test(reply.detail);
console.log(present ? "DEFECT PRESENT: a failed herdr call is classified with the success code \"\"" : "absent");
process.exit(present ? 1 : 0);
