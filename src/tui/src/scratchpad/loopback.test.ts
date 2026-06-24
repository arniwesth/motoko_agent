import { afterEach, describe, expect, it } from "@jest/globals";
import { execFileSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { startLoopbackServer, type LoopbackServer } from "./loopback.js";

// The search path shells out to ripgrep. Skip the integration test in
// environments where `rg` is not a spawnable binary (e.g. CI images without
// ripgrep installed) so the suite stays green there while still exercising
// the real path wherever ripgrep is available.
function ripgrepAvailable(): boolean {
  try {
    execFileSync("rg", ["--version"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}
const itWithRg = ripgrepAvailable() ? it : it.skip;

describe("scratchpad loopback server", () => {
  let tempDir = "";
  let server: LoopbackServer | undefined;

  afterEach(async () => {
    if (server) await server.close();
    server = undefined;
    if (tempDir) fs.rmSync(tempDir, { recursive: true, force: true });
    tempDir = "";
  });

  itWithRg("returns structured JSON for tool.search", async () => {
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
