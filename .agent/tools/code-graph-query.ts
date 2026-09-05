/**
 * code-graph-query — OpenCode Custom Tool
 *
 * Runs ClickHouse SQL against the code-level type dependency graph.
 * Auto-creates views over all CSVs in .code-graph/ so tables are
 * queryable by name (code_types, uses, inherits, implements, invokes,
 * channels, method_calls, throws, registers).
 */

import { tool } from "@opencode-ai/plugin";
import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";

const VIEW_TABLES = [
  "code_types",
  "uses",
  "inherits",
  "implements",
  "invokes",
  "channels",
  "method_calls",
  "throws",
  "registers",
] as const;

function buildViewPreamble(worktree: string): string {
  const codeGraphDir = path.join(worktree, ".code-graph");
  return (
    VIEW_TABLES.filter((t) =>
      fs.existsSync(path.join(codeGraphDir, `${t}.csv`))
    )
      .map(
        (t) =>
          `CREATE VIEW ${t} AS SELECT * FROM file('${codeGraphDir}/${t}.csv', CSVWithNames);`
      )
      .join("\n") + "\n"
  );
}

function execClickhouse(
  sql: string,
  opts: { cwd: string; env: NodeJS.ProcessEnv; timeout: number }
): Promise<{ exitCode: number; stdout: string; stderr: string }> {
  return new Promise((resolve) => {
    const child = spawn(
      "clickhouse",
      ["local", "--query", sql, "--output-format", "JSON"],
      {
        cwd: opts.cwd,
        detached: true,
        stdio: ["ignore", "pipe", "pipe"],
        env: opts.env,
      }
    );

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
    "Run ClickHouse SQL against the code-level type dependency graph. " +
    "Tables: code_types, uses, inherits, implements, invokes, channels, method_calls, throws, registers. " +
    "Always use LIMIT. If no data exists, call code_graph_refresh first.",
  args: {
    sql: tool.schema.string().describe("ClickHouse SQL query against the code graph"),
  },
  async execute(args, context) {
    const worktree = context.worktree;
    const csvPath = path.join(worktree, ".code-graph", "code_types.csv");

    if (!fs.existsSync(csvPath)) {
      return JSON.stringify({
        error: "No code graph data. Call code_graph_refresh first.",
      });
    }

    const fullSql = buildViewPreamble(worktree) + args.sql;

    const env: NodeJS.ProcessEnv = {
      ...process.env,
      PATH: `${path.join(worktree, "tools/code-graph/bin")}:${process.env.HOME}/.local/bin:${process.env.PATH}`,
    };

    const result = await execClickhouse(fullSql, {
      cwd: worktree,
      env,
      timeout: 30_000,
    });

    if (result.exitCode !== 0) {
      if (result.stderr.includes("ENOENT") || result.stdout.includes("ENOENT")) {
        return JSON.stringify({
          error: "clickhouse binary not found",
          detail: "Install: https://clickhouse.com/docs/en/install",
        });
      }
      return JSON.stringify({
        error: "Query failed",
        detail: result.stderr || "Unknown error",
      });
    }

    let parsed: { data: unknown[]; rows?: number };
    try {
      parsed = JSON.parse(result.stdout);
    } catch {
      return JSON.stringify({
        error: "Failed to parse clickhouse JSON output",
        detail: result.stdout.slice(0, 500),
      });
    }

    let data = parsed.data;
    let truncated = false;
    if (data.length > 200) {
      data = data.slice(0, 200);
      truncated = true;
    }

    const output: { data: unknown[]; note?: string } = { data };
    if (truncated) {
      output.note = `Truncated: showing 200 of ${parsed.data.length} rows. Add LIMIT.`;
    }

    return JSON.stringify(output);
  },
});
