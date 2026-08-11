import express from "express";
import { appendFileSync, readFileSync, writeFileSync } from "fs";
import { createServer, type Server } from "http";
import { randomBytes } from "crypto";
import { dirname, relative, resolve } from "path";
import { mkdirSync } from "fs";
import { execFileSync } from "child_process";
import type { LoopbackToolRequest, LoopbackToolResult } from "./frames.js";

export type LoopbackResolverOptions = {
  workdir: string;
  defaultModel: string;
  callAgent: (model: string, prompt: string) => string;
};

export type LoopbackServer = {
  url: string;
  token: string;
  withBrainResolver: <T>(
    resolver: (frame: LoopbackToolRequest) => Promise<LoopbackToolResult>,
    fn: () => Promise<T>,
  ) => Promise<T>;
  close: () => Promise<void>;
};

function result(reqId: string, exit_code: number, stdout: string, stderr = "", metadata: Record<string, unknown> = {}): LoopbackToolResult {
  return { type: "tool-result", reqId, exit_code, stdout, stderr, metadata };
}

function parseRipgrepMatches(workdir: string, pattern: string, stdout: string): string {
  const matches = stdout
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map((line) => {
      const first = line.indexOf(":");
      const second = first < 0 ? -1 : line.indexOf(":", first + 1);
      if (first < 0 || second < 0) return undefined;
      const rawPath = line.slice(0, first);
      const lineNo = Number(line.slice(first + 1, second));
      const path = relative(workdir, rawPath);
      return {
        path: path.startsWith("..") ? rawPath : path,
        line_number: Number.isFinite(lineNo) ? lineNo : 0,
        line_text: line.slice(second + 1),
        context: [],
      };
    })
    .filter((match): match is { path: string; line_number: number; line_text: string; context: never[] } => match !== undefined);
  return JSON.stringify({ tool: "Search", pattern, matches, exit_code: 0 });
}

function confined(workdir: string, userPath: string): string {
  const root = resolve(workdir);
  const target = resolve(root, userPath || ".");
  if (target !== root && !target.startsWith(root + "/")) {
    throw new Error(`path escapes workdir: ${userPath}`);
  }
  return target;
}

export async function startLoopbackServer(opts: LoopbackResolverOptions): Promise<LoopbackServer> {
  const app = express();
  app.use(express.json({ limit: "2mb" }));
  const token = randomBytes(24).toString("hex");
  let brainResolver: ((frame: LoopbackToolRequest) => Promise<LoopbackToolResult>) | null = null;

  async function resolveLocal(frame: LoopbackToolRequest): Promise<LoopbackToolResult> {
    const reqId = String(frame.reqId ?? "");
    const args = frame.arguments ?? {};
    try {
      if (frame.tool === "read") {
        const p = confined(opts.workdir, String(args.path ?? ""));
        return result(reqId, 0, readFileSync(p, "utf8"), "", { path: p });
      }
      if (frame.tool === "write" || frame.tool === "append") {
        const p = confined(opts.workdir, String(args.path ?? ""));
        mkdirSync(dirname(p), { recursive: true });
        const content = String(args.content ?? "");
        if (frame.tool === "write") writeFileSync(p, content, "utf8");
        else appendFileSync(p, content, "utf8");
        return result(reqId, 0, "", "", { path: p, bytes: Buffer.byteLength(content) });
      }
      if (frame.tool === "search") {
        const p = confined(opts.workdir, String(args.path ?? "."));
        const pattern = String(args.pattern ?? "");
        if (pattern.trim() === "") return result(reqId, 1, "", "search pattern is required");
        try {
          const out = execFileSync("rg", ["-n", "--no-heading", "--color", "never", pattern, p], {
            cwd: opts.workdir,
            encoding: "utf8",
            timeout: 15_000,
            maxBuffer: 1024 * 1024,
          });
          return result(reqId, 0, parseRipgrepMatches(opts.workdir, pattern, out).slice(0, 50 * 1024));
        } catch (e: any) {
          // rg exits 1 when it ran successfully but found no matches — treat
          // that as a success with an empty match set. A spawn failure
          // (notably ENOENT when ripgrep isn't installed) has no numeric
          // status; surface it as an error instead of silently reporting
          // "0 matches", which would mask a missing-ripgrep environment.
          const status = typeof e.status === "number" ? e.status : null;
          const stdout = String(e.stdout ?? "");
          if (status === null) {
            return result(reqId, 127, "", `ripgrep (rg) could not be run: ${String(e.code ?? e.message ?? e)}`);
          }
          return result(
            reqId,
            status === 1 ? 0 : status,
            status === 1 ? parseRipgrepMatches(opts.workdir, pattern, stdout).slice(0, 50 * 1024) : stdout.slice(0, 50 * 1024),
            String(e.stderr ?? "").slice(0, 4000),
          );
        }
      }
      if (frame.tool === "agent") {
        const prompt = String(args.prompt ?? "");
        const model = String(args.model ?? "") || opts.defaultModel;
        if (prompt.trim() === "") return result(reqId, 1, "", "agent prompt is required");
        return result(reqId, 0, opts.callAgent(model, prompt));
      }
      return result(reqId, 1, "", `loopback tool not allowed: ${frame.tool}`);
    } catch (e: any) {
      return result(reqId, 1, "", String(e?.message ?? e));
    }
  }

  app.post("/loopback", async (req, res) => {
    const auth = String(req.headers.authorization ?? "");
    if (auth !== `Bearer ${token}`) {
      res.status(401).json(result("", 1, "", "unauthorized"));
      return;
    }
    const frame = req.body as LoopbackToolRequest;
    try {
      const active = brainResolver;
      res.json(active ? await active(frame) : await resolveLocal(frame));
    } catch (e: any) {
      res.json(result(String(frame.reqId ?? ""), 1, "", String(e?.message ?? e)));
    }
  });

  const server = createServer(app);
  await new Promise<void>((resolveListen) => server.listen(0, "127.0.0.1", () => resolveListen()));
  const address = server.address();
  if (!address || typeof address === "string") throw new Error("failed to bind loopback server");
  return {
    url: `http://127.0.0.1:${address.port}/loopback`,
    token,
    withBrainResolver: async <T>(resolver: (frame: LoopbackToolRequest) => Promise<LoopbackToolResult>, fn: () => Promise<T>): Promise<T> => {
      if (brainResolver) throw new Error("scratchpad loopback brain resolver is already active");
      brainResolver = resolver;
      try {
        return await fn();
      } finally {
        if (brainResolver === resolver) brainResolver = null;
      }
    },
    close: () => new Promise<void>((resolveClose) => server.close(() => resolveClose())),
  };
}
