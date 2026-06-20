import vm from "vm";
import type { ScratchpadCellResult, ScratchpadDisplayBundle } from "./frames.js";
import { bundleFromValue } from "./display.js";

export type JsLoopback = {
  read(path: string): string;
  write(path: string, content: string): string;
  append(path: string, content: string): string;
  search(pattern: string, path?: string): string;
  agent(prompt: string, model?: string): string;
};

export class JsKernel {
  private context: vm.Context;
  private executionCount = 0;

  constructor(loopback: JsLoopback) {
    const sandbox: Record<string, unknown> = {
      console: {
        log: (...xs: unknown[]) => this.writeStdout(xs.map((x) => typeof x === "string" ? x : JSON.stringify(x)).join(" ") + "\n"),
        error: (...xs: unknown[]) => this.writeStderr(xs.map((x) => typeof x === "string" ? x : JSON.stringify(x)).join(" ") + "\n"),
      },
      display: (value: unknown) => {
        this.displays.push(bundleFromValue(value));
        return undefined;
      },
      tool: loopback,
      agent: (prompt: string, model = "") => loopback.agent(prompt, model),
    };
    this.context = vm.createContext(sandbox);
  }

  private stdout = "";
  private stderr = "";
  private displays: ScratchpadDisplayBundle[] = [];

  private writeStdout(s: string): void { this.stdout += s; }
  private writeStderr(s: string): void { this.stderr += s; }

  async run(index: number, opts: { code: string; title: string; timeoutMs: number }): Promise<ScratchpadCellResult> {
    this.stdout = "";
    this.stderr = "";
    this.displays = [];
    this.executionCount += 1;
    let result: ScratchpadDisplayBundle | undefined;
    let error: ScratchpadCellResult["error"];
    let exit_code = 0;
    try {
      const script = new vm.Script(opts.code);
      const value = script.runInContext(this.context, { timeout: opts.timeoutMs });
      if (value !== undefined) result = bundleFromValue(value);
    } catch (e: any) {
      exit_code = 1;
      error = { ename: String(e?.name ?? "Error"), evalue: String(e?.message ?? e), traceback: String(e?.stack ?? "").split("\n") };
    }
    return {
      index,
      language: "js",
      title: opts.title,
      exit_code,
      stdout: this.stdout,
      stderr: this.stderr,
      displays: this.displays,
      result,
      error,
      executionCount: this.executionCount,
      cancelled: false,
      truncated: Buffer.byteLength(this.stdout + this.stderr, "utf8") > 50 * 1024,
    };
  }

  close(): void {
    this.context = vm.createContext({});
  }
}
