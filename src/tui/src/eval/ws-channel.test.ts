import { describe, it, expect, afterEach } from "@jest/globals";
import { createServer, type Server } from "http";
import WebSocket from "ws";
import { attachExecCellWebSocketServer } from "./ws-channel.js";
import type { LoopbackToolRequest, LoopbackToolResult } from "./frames.js";

function listen(server: Server): Promise<number> {
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const addr = server.address();
      if (!addr || typeof addr === "string") reject(new Error("server did not bind"));
      else resolve(addr.port);
    });
  });
}

describe("exec-cell WebSocket channel", () => {
  const servers: Server[] = [];

  afterEach(async () => {
    await Promise.all(servers.map((s) => new Promise<void>((resolve) => s.close(() => resolve()))));
    servers.length = 0;
  });

  it("correlates tool-request frames by reqId and returns the brain result", async () => {
    const server = createServer();
    servers.push(server);

    attachExecCellWebSocketServer(server, {
      normalizeCells: () => [{ language: "py", code: "tool.read('README.md')" }],
      runCells: async (_cells, _sessionId, _timeoutSecs, resolver) => {
        const frame: LoopbackToolRequest = {
          type: "tool-request",
          reqId: "req-1",
          tool: "read",
          arguments: { path: "README.md" },
        };
        const result = await resolver(frame);
        return {
          exit_code: result.exit_code,
          stdout: result.stdout,
          stderr: result.stderr,
          cells: [],
          images: [],
          jsonOutputs: [],
        };
      },
    });

    const port = await listen(server);
    const ws = new WebSocket(`ws://127.0.0.1:${port}/exec-cell-ws`);

    const final = await new Promise<any>((resolve, reject) => {
      ws.on("error", reject);
      ws.on("open", () => {
        ws.send(JSON.stringify({ type: "run", cells: [{ language: "py", code: "x" }], sessionId: "s", timeout: 5 }));
      });
      ws.on("message", (raw) => {
        const msg = JSON.parse(raw.toString("utf8"));
        if (msg.type === "tool-request") {
          const reply: LoopbackToolResult = {
            type: "tool-result",
            reqId: msg.reqId,
            exit_code: 0,
            stdout: "from-brain",
            stderr: "",
            metadata: { ok: true },
          };
          ws.send(JSON.stringify(reply));
        } else if (msg.type === "exec-result") {
          resolve(msg);
        }
      });
      ws.on("close", () => reject(new Error("closed before exec-result")));
    });

    expect(final.exit_code).toBe(0);
    expect(final.stdout).toBe("from-brain");
  });
});
