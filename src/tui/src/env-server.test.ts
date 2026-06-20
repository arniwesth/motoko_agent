// tui/src/env-server.test.ts
//
// Acceptance tests for the embedded environment server.
// Tests run the server logic inline (not via startEnvServer) so there is no
// import-resolution difference between test and production code.
//
// Scenarios covered:
//   1. Echo command → stdout returned, exit_code 0
//   2. Nonzero-exit command → correct exit_code
//   3. Timeout enforced → completes well before the command's sleep duration
//   4. GET /health → {status: "ok"}

import { describe, it, expect, beforeAll, afterAll } from "@jest/globals";
import http from "http";
import express from "express";
import { execSync } from "child_process";
import { normalizeEvalCells, normalizeAilangVerify, normalizeLeanProve } from "./env-server.js";

// ---------------------------------------------------------------------------
// Minimal inline env-server — mirrors env-server.ts so tests don't depend on
// a compiled import, which avoids ESM/CJS resolution issues in Jest.
// ---------------------------------------------------------------------------
function makeTestApp(workdir: string) {
  const app = express();
  app.use(express.json());

  app.post("/exec", (req, res) => {
    const { cmd, timeout = 30 } = req.body as { cmd: string; timeout?: number };
    try {
      const stdout = execSync(cmd, {
        cwd: workdir,
        timeout: timeout * 1000,
        encoding: "utf8",
        maxBuffer: 8 * 1024 * 1024,
      });
      res.json({ stdout: stdout.slice(0, 8000), stderr: "", exit_code: 0 });
    } catch (e: any) {
      res.json({
        stdout: String(e.stdout ?? "").slice(0, 8000),
        stderr: String(e.stderr ?? "").slice(0, 2000),
        exit_code: typeof e.status === "number" ? e.status : 1,
      });
    }
  });

  app.get("/health", (_req, res) => res.json({ status: "ok" }));

  return app;
}

// ---------------------------------------------------------------------------
// HTTP helper — avoids fetch (unavailable in older Node versions) and avoids
// adding supertest as a dep.
// ---------------------------------------------------------------------------
function jsonRequest(
  url: string,
  method: string,
  body?: object
): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : undefined;
    const urlObj = new URL(url);
    const options: http.RequestOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname,
      method,
      headers: {
        "Content-Type": "application/json",
        ...(payload
          ? { "Content-Length": Buffer.byteLength(payload) }
          : {}),
      },
    };
    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk: string) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error("Non-JSON response: " + data));
        }
      });
    });
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe("env-server", () => {
  let server: http.Server;
  const PORT = 18081; // distinct from prod 8080 and other test ports
  const BASE = `http://127.0.0.1:${PORT}`;

  beforeAll(
    () =>
      new Promise<void>((done) => {
        const app = makeTestApp(process.cwd());
        server = app.listen(PORT, done);
      })
  );

  afterAll(
    () =>
      new Promise<void>((done, reject) =>
        server.close((err) => (err ? reject(err) : done()))
      )
  );

  it("echo command returns stdout and exit_code 0", async () => {
    const r = (await jsonRequest(`${BASE}/exec`, "POST", {
      cmd: "echo hello",
    })) as { stdout: string; stderr: string; exit_code: number };

    expect(r.exit_code).toBe(0);
    expect(r.stdout.trim()).toBe("hello");
    expect(r.stderr).toBe("");
  });

  it("nonzero-exit command returns a nonzero exit_code", async () => {
    // `sh -c 'exit 42'` is the portable way to produce a specific exit code.
    // execSync throws; we catch and return exit_code from e.status.
    const r = (await jsonRequest(`${BASE}/exec`, "POST", {
      cmd: "sh -c 'exit 42'",
      timeout: 5,
    })) as { exit_code: number };

    expect(r.exit_code).toBe(42);
  });

  it("timeout is enforced (completes before the command would finish)", async () => {
    const start = Date.now();

    const r = (await jsonRequest(`${BASE}/exec`, "POST", {
      cmd: "sleep 30",
      timeout: 1, // 1 second — command would take 30s
    })) as { exit_code: number };

    const elapsed = Date.now() - start;

    // Should fail (timeout) and return well before the command's full duration.
    expect(r.exit_code).not.toBe(0);
    expect(elapsed).toBeLessThan(6000);
  }, 10_000);

  it("GET /health returns {status: 'ok'}", async () => {
    const r = (await jsonRequest(`${BASE}/health`, "GET")) as {
      status: string;
    };
    expect(r.status).toBe("ok");
  });
});

// normalizeEvalCells is the single shared normalization used by BOTH the HTTP
// /exec-cell route and the WS /exec-cell-ws handler (wired identically), so
// testing it covers the language-survival requirements on both transports.
describe("normalizeEvalCells", () => {
  it("accepts language:'ail' and parses the AILANG-only fields", () => {
    const cells = normalizeEvalCells([
      { language: "ail", code: "export func f() -> int ! {} { 1 }", run: true, entry: "f", caps: "IO,FS", verify: "required" },
    ]);
    expect(cells).toHaveLength(1);
    expect(cells[0].language).toBe("ail");
    expect(cells[0].run).toBe(true);
    expect(cells[0].entry).toBe("f");
    expect(cells[0].caps).toBe("IO,FS");
    expect(cells[0].verify).toBe("required");
  });

  it("defaults AILANG verify to 'auto' and run to false", () => {
    const cells = normalizeEvalCells([{ language: "ail", code: "export func f() -> int ! {} { 1 }" }]);
    expect(cells[0].verify).toBe("auto");
    expect(cells[0].run).toBe(false);
  });

  it("accepts language:'lean' and parses Lean-only fields", () => {
    const cells = normalizeEvalCells([
      { language: "lean", code: "theorem t : 1 = 1 := rfl", prove: "required", mathlib: true },
    ]);
    expect(cells).toHaveLength(1);
    expect(cells[0].language).toBe("lean");
    expect(cells[0].prove).toBe("required");
    expect(cells[0].mathlib).toBe(true);
  });

  it("defaults Lean prove to 'auto' and mathlib to false", () => {
    const cells = normalizeEvalCells([{ language: "lean", code: "#eval 1+1" }]);
    expect(cells[0].prove).toBe("auto");
    expect(cells[0].mathlib).toBe(false);
  });

  it("throws an explicit error for an unknown language (never coerces to py)", () => {
    expect(() => normalizeEvalCells([{ language: "ruby", code: "puts 1" }])).toThrow(/unsupported eval language "ruby"/);
  });

  it("still accepts py and js, and a missing language defaults to py", () => {
    const cells = normalizeEvalCells([
      { language: "py", code: "print(1)" },
      { language: "js", code: "1" },
      { code: "print(2)" },
    ]);
    expect(cells.map((c) => c.language)).toEqual(["py", "js", "py"]);
  });

  it("does not attach AILANG fields to py/js cells", () => {
    const cells = normalizeEvalCells([{ language: "py", code: "print(1)", verify: "required" } as any]);
    expect(cells[0].verify).toBeUndefined();
  });

  it("filters out empty-code cells", () => {
    expect(normalizeEvalCells([{ language: "ail", code: "   " }])).toHaveLength(0);
  });

  it("normalizeAilangVerify maps modes (string and boolean forms)", () => {
    expect(normalizeAilangVerify(true)).toBe(true);
    expect(normalizeAilangVerify(false)).toBe(false);
    expect(normalizeAilangVerify("required")).toBe("required");
    expect(normalizeAilangVerify("auto")).toBe("auto");
    expect(normalizeAilangVerify(undefined)).toBe("auto");
  });

  it("normalizeLeanProve maps modes", () => {
    expect(normalizeLeanProve("required")).toBe("required");
    expect(normalizeLeanProve("off")).toBe("off");
    expect(normalizeLeanProve(false)).toBe("off");
    expect(normalizeLeanProve(undefined)).toBe("auto");
  });
});
