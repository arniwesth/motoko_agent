/**
 * code-graph-refresh — OpenCode Custom Tool
 *
 * Re-extracts the legacy code graph.
 * Runs extract-only.sh (build extractor, extract CSVs, compute metrics).
 * Takes up to 2 minutes.
 */

import { tool } from "@opencode-ai/plugin";
import { spawn } from "node:child_process";
import * as path from "node:path";

function execScript(
  script: string,
  opts: { cwd: string; env: NodeJS.ProcessEnv; timeout: number }
): Promise<{ exitCode: number; stdout: string; stderr: string }> {
  return new Promise((resolve) => {
    const child = spawn("bash", [script], {
      cwd: opts.cwd,
      detached: true,
      stdio: ["ignore", "pipe", "pipe"],
      env: opts.env,
    });

    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];

    if (child.stdout) child.stdout.on("data", (d: Buffer) => stdoutChunks.push(d));
    if (child.stderr) child.stderr.on("data", (d: Buffer) => stderrChunks.push(d));

    const timer = setTimeout(() => {
      try {
        process.kill(-child.pid!, "SIGTERM");
      } catch {
        try { child.kill(); } catch { /* already dead */ }
      }
    }, opts.timeout);

    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({ exitCode: 1, stdout: "", stderr: err.message });
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({
        exitCode: code ?? 1,
        stdout: Buffer.concat(stdoutChunks).toString("utf-8"),
        stderr: Buffer.concat(stderrChunks).toString("utf-8"),
      });
    });
  });
}

export default tool({
  description:
    "Re-extract the legacy code graph. " +
    "Run when codebase has changed and you need updated graph data. Takes up to 2 minutes.",
  args: {},
  async execute(_args, context) {
    const worktree = context.worktree;
    const script = path.join(worktree, "tools/code-graph/extract-only.sh");

    const env: NodeJS.ProcessEnv = {
      ...process.env,
      PATH: `${path.join(worktree, "tools/code-graph/bin")}:${process.env.HOME}/.local/bin:${process.env.PATH}`,
    };

    const result = await execScript(script, {
      cwd: worktree,
      env,
      timeout: 120_000,
    });

    if (result.exitCode !== 0) {
      return JSON.stringify({
        error: "Code graph extraction failed",
        detail: result.stderr || result.stdout || "Unknown error",
      });
    }

    return result.stderr || result.stdout || "Extraction complete.";
  },
});
