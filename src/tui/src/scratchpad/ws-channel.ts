import type { Server } from "http";
import { WebSocketServer, type RawData, type WebSocket } from "ws";
import type { ScratchpadCell, ScratchpadCellResponse, LoopbackToolRequest, LoopbackToolResult } from "./frames.js";

export type ScratchpadCellWsRequest = {
  type: "run";
  cells?: unknown;
  sessionId?: string;
  timeout?: number;
};

export type ScratchpadCellWsOptions = {
  path?: string;
  normalizeCells: (raw: unknown) => ScratchpadCell[];
  runCells: (
    cells: ScratchpadCell[],
    sessionId: string,
    timeoutSecs: number,
    resolver: (frame: LoopbackToolRequest) => Promise<LoopbackToolResult>,
  ) => Promise<ScratchpadCellResponse>;
};

type PendingRequest = {
  resolve: (frame: LoopbackToolResult) => void;
  reject: (err: Error) => void;
  timer: NodeJS.Timeout;
};

function send(ws: WebSocket, payload: unknown): void {
  if (ws.readyState !== ws.OPEN) throw new Error("scratchpad-cell WebSocket is not open");
  ws.send(JSON.stringify(payload));
}

function parseMessage(data: RawData): unknown {
  const text = typeof data === "string" ? data : data.toString("utf8");
  return JSON.parse(text);
}

function failPending(pending: Map<string, PendingRequest>, err: Error): void {
  for (const [, p] of pending) {
    clearTimeout(p.timer);
    p.reject(err);
  }
  pending.clear();
}

export function attachScratchpadCellWebSocketServer(server: Server, opts: ScratchpadCellWsOptions): WebSocketServer {
  const path = opts.path ?? "/scratchpad-cell-ws";
  const wss = new WebSocketServer({ server, path });

  wss.on("connection", (ws) => {
    const pending = new Map<string, PendingRequest>();
    let running = false;

    const resolveViaBrain = (frame: LoopbackToolRequest): Promise<LoopbackToolResult> => {
      return new Promise((resolve, reject) => {
        if (ws.readyState !== ws.OPEN) {
          reject(new Error("brain WebSocket disconnected before tool result"));
          return;
        }
        const timer = setTimeout(() => {
          pending.delete(frame.reqId);
          reject(new Error(`timed out waiting for tool-result ${frame.reqId}`));
        }, 65_000);
        pending.set(frame.reqId, { resolve, reject, timer });
        send(ws, frame);
      });
    };

    ws.on("message", async (data) => {
      let msg: any;
      try {
        msg = parseMessage(data);
      } catch (e: any) {
        send(ws, { type: "error", message: `invalid JSON frame: ${String(e?.message ?? e)}` });
        return;
      }

      if (msg?.type === "tool-result") {
        const reqId = String(msg.reqId ?? "");
        const p = pending.get(reqId);
        if (!p) return;
        pending.delete(reqId);
        clearTimeout(p.timer);
        p.resolve({
          type: "tool-result",
          reqId,
          exit_code: Number(msg.exit_code ?? 1),
          stdout: String(msg.stdout ?? ""),
          stderr: String(msg.stderr ?? ""),
          metadata: (msg.metadata && typeof msg.metadata === "object") ? msg.metadata : {},
        });
        return;
      }

      if (msg?.type !== "run") {
        send(ws, { type: "error", message: `unexpected frame type: ${String(msg?.type ?? "")}` });
        return;
      }
      if (running) {
        send(ws, { type: "error", message: "scratchpad-cell WebSocket run already in progress" });
        return;
      }

      running = true;
      try {
        const req = msg as ScratchpadCellWsRequest;
        const cells = opts.normalizeCells(req.cells);
        const sessionId = String(req.sessionId ?? "default");
        const timeoutSecs = Math.max(1, Number(req.timeout ?? 30));
        const response = await opts.runCells(cells, sessionId, timeoutSecs, resolveViaBrain);
        send(ws, { type: "exec-result", ...response });
      } catch (e: any) {
        send(ws, {
          type: "exec-result",
          exit_code: 1,
          stdout: "",
          stderr: String(e?.message ?? e),
          cells: [],
          images: [],
          jsonOutputs: [],
        });
      } finally {
        running = false;
        failPending(pending, new Error("scratchpad-cell WebSocket run finished"));
        if (ws.readyState === ws.OPEN) ws.close(1000, "done");
      }
    });

    ws.on("close", () => failPending(pending, new Error("brain WebSocket disconnected")));
    ws.on("error", (err) => failPending(pending, err instanceof Error ? err : new Error(String(err))));
  });

  return wss;
}
