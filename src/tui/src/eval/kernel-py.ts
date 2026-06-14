import { spawn, type ChildProcessWithoutNullStreams } from "child_process";
import { createHash } from "crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { dirname, join, resolve } from "path";
import { fileURLToPath } from "url";
import type { CellRunFrame, EvalCellResult, EvalDisplayBundle } from "./frames.js";
import { normalizeBundle } from "./display.js";

export type KernelRunOptions = {
  code: string;
  title: string;
  cwd: string;
  timeoutMs: number;
};

function runnerSourcePath(): string {
  const here = dirname(fileURLToPath(import.meta.url));
  const direct = join(here, "runner.py");
  if (existsSync(direct)) return direct;
  const fromDist = resolve(here, "../src/eval/runner.py");
  if (existsSync(fromDist)) return fromDist;
  return resolve(process.cwd(), "src/tui/src/eval/runner.py");
}

function cachedRunnerPath(): string {
  const src = readFileSync(runnerSourcePath(), "utf8");
  const hash = createHash("sha256").update(src).digest("hex").slice(0, 16);
  const dir = "/tmp/motoko-eval";
  mkdirSync(dir, { recursive: true });
  const dst = join(dir, `runner-${hash}.py`);
  if (!existsSync(dst)) writeFileSync(dst, src, "utf8");
  return dst;
}

export class PythonKernel {
  private child: ChildProcessWithoutNullStreams | null = null;
  private seq = 0;
  private pending:
    | {
        id: string;
        resolve: (r: EvalCellResult) => void;
        frames: CellRunFrame[];
        stdout: string;
        stderr: string;
        displays: EvalDisplayBundle[];
        result?: EvalDisplayBundle;
        error?: { ename: string; evalue: string; traceback: string[] };
        timer: NodeJS.Timeout;
        index: number;
        title: string;
      }
    | null = null;

  constructor(private readonly env: Record<string, string>) {}

  start(): void {
    if (this.child) return;
    this.child = spawn("python3", [cachedRunnerPath()], {
      env: { ...process.env, ...this.env },
      stdio: ["pipe", "pipe", "pipe"],
    });
    let buf = "";
    this.child.stdout.setEncoding("utf8");
    this.child.stdout.on("data", (chunk: string) => {
      buf += chunk;
      while (true) {
        const at = buf.indexOf("\n");
        if (at < 0) break;
        const line = buf.slice(0, at);
        buf = buf.slice(at + 1);
        this.onLine(line);
      }
    });
    this.child.stderr.setEncoding("utf8");
    this.child.stderr.on("data", (chunk: string) => {
      if (this.pending) this.pending.stderr += chunk;
    });
    this.child.on("close", () => {
      this.child = null;
      if (this.pending) {
        const p = this.pending;
        clearTimeout(p.timer);
        this.pending = null;
        p.resolve({
          index: p.index,
          language: "py",
          title: p.title,
          exit_code: 1,
          stdout: p.stdout,
          stderr: p.stderr || "python kernel exited",
          displays: p.displays,
          result: p.result,
          error: p.error,
          executionCount: 0,
          cancelled: true,
          truncated: false,
        });
      }
    });
  }

  private onLine(line: string): void {
    if (!this.pending || line.trim() === "") return;
    let frame: CellRunFrame;
    try {
      frame = JSON.parse(line);
    } catch {
      this.pending.stderr += line + "\n";
      return;
    }
    const p = this.pending;
    p.frames.push(frame);
    if (frame.type === "stdout") p.stdout += frame.text;
    else if (frame.type === "stderr") p.stderr += frame.text;
    else if (frame.type === "display") p.displays.push(normalizeBundle(frame.bundle));
    else if (frame.type === "result") p.result = normalizeBundle(frame.bundle);
    else if (frame.type === "error") p.error = { ename: frame.ename, evalue: frame.evalue, traceback: frame.traceback };
    else if (frame.type === "done") {
      clearTimeout(p.timer);
      this.pending = null;
      p.resolve({
        index: p.index,
        language: "py",
        title: p.title,
        exit_code: frame.status === "ok" ? 0 : 1,
        stdout: p.stdout,
        stderr: p.stderr,
        displays: p.displays,
        result: p.result,
        error: p.error,
        executionCount: frame.executionCount,
        cancelled: frame.cancelled,
        truncated: Buffer.byteLength(p.stdout + p.stderr, "utf8") > 50 * 1024,
      });
    }
  }

  run(index: number, opts: KernelRunOptions): Promise<EvalCellResult> {
    this.start();
    const child = this.child;
    if (!child) throw new Error("python kernel failed to start");
    if (this.pending) throw new Error("python kernel is busy");
    const id = `py-${Date.now()}-${++this.seq}`;
    return new Promise((resolveRun) => {
      const timer = setTimeout(() => {
        if (this.pending?.id === id) {
          try { child.kill("SIGINT"); } catch { /* ignore */ }
          setTimeout(() => {
            if (this.pending?.id === id) {
              try { child.kill("SIGKILL"); } catch { /* ignore */ }
            }
          }, 1500).unref();
        }
      }, opts.timeoutMs);
      this.pending = {
        id,
        resolve: resolveRun,
        frames: [],
        stdout: "",
        stderr: "",
        displays: [],
        timer,
        index,
        title: opts.title,
      };
      child.stdin.write(JSON.stringify({ type: "run", id, code: opts.code, cwd: opts.cwd }) + "\n");
    });
  }

  close(): void {
    if (!this.child) return;
    try { this.child.stdin.write(JSON.stringify({ type: "exit" }) + "\n"); } catch { /* ignore */ }
    try { this.child.kill("SIGTERM"); } catch { /* ignore */ }
    this.child = null;
  }
}
