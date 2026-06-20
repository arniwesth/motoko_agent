import { afterEach, describe, expect, test } from "@jest/globals";
import { mkdtempSync, rmSync, writeFileSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import { LeanKernel } from "./kernel-lean.js";

function makeFakeRepl(): { dir: string; script: string } {
  const dir = mkdtempSync(join(tmpdir(), "lean-kernel-test-"));
  const script = join(dir, "fake-repl.js");
  writeFileSync(script, `
let buf = "";
let env = 0;
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buf += chunk;
  while (true) {
    const idx = buf.indexOf("\\n\\n");
    if (idx < 0) break;
    const raw = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 2);
    if (!raw) continue;
    const req = JSON.parse(raw);
    if (req.cmd.includes("hang")) continue;
    if (req.cmd.includes("bad")) {
      process.stdout.write(JSON.stringify({ messages: [{ severity: "error", data: "bad proof" }], env: env++ }, null, 1) + "\\n\\n");
    } else if (req.cmd.startsWith("#print axioms")) {
      const name = req.cmd.replace("#print axioms", "").trim();
      process.stdout.write(JSON.stringify({ messages: [{ severity: "info", data: "'" + name + "' does not depend on any axioms" }], env: env++ }, null, 1) + "\\n\\n");
    } else {
      process.stdout.write(JSON.stringify({ env: env++ }, null, 1) + "\\n\\n");
    }
  }
});
`, "utf8");
  return { dir, script };
}

describe("LeanKernel with fake repl", () => {
  const dirs: string[] = [];
  afterEach(() => {
    for (const d of dirs.splice(0)) rmSync(d, { recursive: true, force: true });
  });

  test("surfaces teach prompt once and commits verified named theorem", async () => {
    const fake = makeFakeRepl();
    dirs.push(fake.dir);
    const k = new LeanKernel({ command: process.execPath, args: [fake.script], cwd: fake.dir, agentPrompt: () => "LEAN GUIDE" });
    const cell = { language: "lean" as const, code: "theorem t : 1 = 1 := rfl", prove: "required" as const };
    const first = await k.run(0, { cell, title: "t", timeoutMs: 1000, workdir: fake.dir });
    const second = await k.run(1, { cell: { ...cell, code: "theorem u : 1 = 1 := rfl" }, title: "u", timeoutMs: 1000, workdir: fake.dir });
    k.close();

    expect(first.exit_code).toBe(0);
    expect(first.metadata?.lean?.proof).toBe("verified");
    expect(first.metadata?.lean?.committed).toBe(true);
    expect(first.stdout).toContain("LEAN GUIDE");
    expect(second.exit_code).toBe(0);
    expect(second.metadata?.lean?.teachPrompt).toBeUndefined();
    expect(second.stdout).not.toContain("LEAN GUIDE");
  });

  test("timeout hard-kills and reports proof error", async () => {
    const fake = makeFakeRepl();
    dirs.push(fake.dir);
    const k = new LeanKernel({ command: process.execPath, args: [fake.script], cwd: fake.dir });
    const r = await k.run(0, {
      cell: { language: "lean", code: "theorem hang : 1 = 1 := rfl", prove: "required" },
      title: "hang",
      timeoutMs: 50,
      workdir: fake.dir,
    });
    k.close();
    expect(r.exit_code).toBe(1);
    expect(r.metadata?.lean?.elaborated).toBe("error");
    expect(r.metadata?.lean?.proof).toBe("error");
    expect(r.metadata?.lean?.committed).toBe(false);
  });
});
