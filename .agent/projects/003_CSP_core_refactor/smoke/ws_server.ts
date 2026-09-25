// Smoke WS server for the transmit-inside-onEvent test.
// On client connect: push one message ("ping-from-server").
// On any message from client: record it, print a marker, then close.
// Writes the received payload to RESULT_FILE so the harness can assert.
const RESULT_FILE = process.env.RESULT_FILE ?? "/tmp/ws_smoke_result.txt";
const PORT = Number(process.env.PORT ?? 8787);

const server = Bun.serve({
  port: PORT,
  hostname: "127.0.0.1",
  fetch(req, srv) {
    if (srv.upgrade(req)) return;
    return new Response("expected websocket upgrade", { status: 426 });
  },
  websocket: {
    open(ws) {
      console.log("SERVER: client connected, sending ping-from-server");
      ws.send("ping-from-server");
    },
    async message(ws, message) {
      const text = typeof message === "string" ? message : message.toString();
      console.log(`SERVER_RECEIVED: ${text}`);
      await Bun.write(RESULT_FILE, text);
      ws.close();
      // give the close frame a moment, then exit so the harness unblocks
      setTimeout(() => server.stop(true), 100);
    },
  },
});

console.log(`SERVER: listening on ws://127.0.0.1:${PORT}`);
