// Smoke WS+HTTP server for the EFFECTFUL-DISPATCH-IN-HANDLER test (B' Phase 3 gate).
//
// This settles the load-bearing gap flagged in 02-design-b-prime: transmit-in-handler
// is proven, but a real `Net`/`AI`-effect dispatch INSIDE a live runEventLoop handler
// was "very likely, unverified".
//
// Protocol:
//   - One Bun process serves BOTH a WebSocket and a plain HTTP endpoint.
//   - On WS open: server sends the client a URL string (its own /api endpoint).
//   - Client must, INSIDE its onEvent handler, httpGet(url) (a Net effect) and
//     transmit the fetched body back on the SAME open socket.
//   - GET /api returns a distinctive TOKEN. The server records whatever the client
//     transmits back. If RESULT_FILE == TOKEN, the in-handler Net dispatch worked.
const RESULT_FILE = process.env.RESULT_FILE ?? "/tmp/ws_net_result.txt";
const PORT = Number(process.env.PORT ?? 8790);
const TOKEN = "net-in-handler-OK-7f3a";

const server = Bun.serve({
  port: PORT,
  hostname: "127.0.0.1",
  fetch(req, srv) {
    const u = new URL(req.url);
    if (u.pathname === "/api") {
      console.log("SERVER: /api hit (in-handler Net call landed)");
      return new Response(TOKEN, { status: 200, headers: { "content-type": "text/plain" } });
    }
    if (srv.upgrade(req)) return;
    return new Response("expected websocket upgrade", { status: 426 });
  },
  websocket: {
    open(ws) {
      console.log("SERVER: client connected, sending fetch URL");
      ws.send(`http://127.0.0.1:${PORT}/api`);
    },
    async message(ws, message) {
      const text = typeof message === "string" ? message : message.toString();
      console.log(`SERVER_RECEIVED: ${text}`);
      await Bun.write(RESULT_FILE, text);
      ws.close();
      setTimeout(() => server.stop(true), 100);
    },
  },
});

console.log(`SERVER: listening ws+http on 127.0.0.1:${PORT} (/api), expecting token ${TOKEN}`);
