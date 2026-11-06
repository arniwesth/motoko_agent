// P2.1 witnesses, the TypeScript side: the same cases as t2_witness.ail.
const tree = process.argv[2];
const { herdrMeansAgentGone, herdrFailureCode } = await import(`${tree}/src/tui/src/wake-waiter.ts`);
const line = (name: string, code: number, stderr: string) => {
  const r = { code, stdout: "", stderr };
  console.log(`${name} -> ${herdrMeansAgentGone(r) ? "gone" : "kept"} (${herdrFailureCode(r)})`);
};
line("s05-witness exit=-1 compact-json agent_not_found", -1, '{"error":{"code":"agent_not_found","message":"x"}}');
line("s06-witness exit=1 compact-json pane_not_found", 1, '{"error":{"code":"pane_not_found","message":"x"}}');
line("s07-witness exit=1 spaced-json agent_not_found", 1, '{ "error": {"code": "agent_not_found", "message": "x"}}');
line("control exit=1 compact-json agent_not_found", 1, '{"error":{"code":"agent_not_found","message":"x"}}');
line("control exit=1 compact-json server_not_running", 1, '{"error":{"code":"server_not_running","message":"x"}}');
