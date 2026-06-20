import { afterEach, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { startLoopbackServer, type LoopbackServer } from "./loopback.js";

describe("scratchpad loopback server", () => {
  let tempDir = "";
  let server: LoopbackServer | undefined;

  afterEach(async () => {
    if (server) await server.close();
    server = undefined;
    if (tempDir) fs.rmSync(tempDir, { recursive: true, force: true });
    tempDir = "";
  });

  it("returns structured JSON for tool.search", async () => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-loopback-"));
    fs.mkdirSync(path.join(tempDir, "src"), { recursive: true });
    fs.writeFileSync(path.join(tempDir, "src", "sample.ts"), "const x = 'WebSocket';\n", "utf8");

    server = await startLoopbackServer({
      workdir: tempDir,
      defaultModel: "test/model",
      callAgent: () => "",
    });

    const res = await fetch(server.url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${server.token}`,
      },
      body: JSON.stringify({
        type: "tool-request",
        reqId: "req-1",
        tool: "search",
        arguments: { pattern: "WebSocket", path: "src" },
      }),
    });
    const frame = await res.json() as { exit_code: number; stdout: string };
    const payload = JSON.parse(frame.stdout) as { matches: Array<{ path: string; line_number: number; line_text: string }> };

    expect(frame.exit_code).toBe(0);
    expect(payload.matches).toHaveLength(1);
    expect(payload.matches[0]).toMatchObject({
      path: "src/sample.ts",
      line_number: 1,
      line_text: "const x = 'WebSocket';",
    });
  });
});
