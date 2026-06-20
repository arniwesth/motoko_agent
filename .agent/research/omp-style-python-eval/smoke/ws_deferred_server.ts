// Smoke WS server for deferred dispatch.
// Protocol:
//   client -> {"type":"run"}
//   server -> {"type":"tool-request","reqId":"req-1",...}
//   client -> {"type":"tool-result","reqId":"req-1",...}
//   server -> {"type":"exec-result",...}
//
// The server writes the received tool-result to RESULT_FILE and exits after
// sending exec-result so shell harnesses unblock.
const RESULT_FILE = process.env.RESULT_FILE ?? "/tmp/ws_deferred_result.txt";
const PORT = Number(process.env.PORT ?? 8788);

const server = Bun.serve({
  port: PORT,
  hostname: "127.0.0.1",
  fetch(req, srv) {
    if (srv.upgrade(req)) return;
    return new Response("expected websocket upgrade", { status: 426 });
  },
  websocket: {
    open(ws) {
      console.log(`SERVER: client connected`);
      console.log("SERVER: sending tool-request");
      ws.send(JSON.stringify({
        type: "tool-request",
        reqId: "req-1",
        tool: "read",
        arguments: { path: "README.md" },
      }));
    },
    async message(ws, message) {
      const text = typeof message === "string" ? message : message.toString();
      console.log(`SERVER_RECEIVED: ${text}`);
      let frame: any;
      try {
        frame = JSON.parse(text);
      } catch {
        return;
      }
      if (frame.type === "run") return;
      if (frame.type === "tool-result") {
        await Bun.write(RESULT_FILE, text);
        ws.send(JSON.stringify({
          type: "exec-result",
          exit_code: Number(frame.exit_code ?? 1),
          stdout: String(frame.stdout ?? ""),
          stderr: String(frame.stderr ?? ""),
          cells: [],
          images: [],
          jsonOutputs: [],
        }));
        setTimeout(() => server.stop(true), 100);
      }
    },
  },
});

console.log(`SERVER: listening on ws://127.0.0.1:${PORT}`);
