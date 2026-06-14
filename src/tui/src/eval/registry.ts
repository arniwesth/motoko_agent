import type { EvalCell, EvalCellResult } from "./frames.js";
import { PythonKernel } from "./kernel-py.js";
import { JsKernel, type JsLoopback } from "./kernel-js.js";

type RegistryEntry =
  | { language: "py"; kernel: PythonKernel; lastUsed: number }
  | { language: "js"; kernel: JsKernel; lastUsed: number };

export class EvalKernelRegistry {
  private entries = new Map<string, RegistryEntry>();
  private cleanupTimer: NodeJS.Timeout;

  constructor(
    private readonly idleMs: number,
    private readonly makePythonEnv: () => Record<string, string>,
    private readonly makeJsLoopback: () => JsLoopback,
  ) {
    this.cleanupTimer = setInterval(() => this.evictIdle(), Math.max(30_000, Math.min(idleMs, 60_000)));
    this.cleanupTimer.unref();
  }

  private key(language: "py" | "js", sessionId: string): string {
    return `${language}:${sessionId}`;
  }

  private evictIdle(): void {
    const now = Date.now();
    for (const [key, entry] of this.entries) {
      if (now - entry.lastUsed > this.idleMs) {
        entry.kernel.close();
        this.entries.delete(key);
      }
    }
  }

  reset(language: "py" | "js", sessionId: string): void {
    const key = this.key(language, sessionId);
    const existing = this.entries.get(key);
    if (existing) existing.kernel.close();
    this.entries.delete(key);
  }

  private get(language: "py" | "js", sessionId: string): RegistryEntry {
    const key = this.key(language, sessionId);
    const existing = this.entries.get(key);
    if (existing) {
      existing.lastUsed = Date.now();
      return existing;
    }
    const entry: RegistryEntry = language === "py"
      ? { language, kernel: new PythonKernel(this.makePythonEnv()), lastUsed: Date.now() }
      : { language, kernel: new JsKernel(this.makeJsLoopback()), lastUsed: Date.now() };
    this.entries.set(key, entry);
    return entry;
  }

  async runCell(index: number, sessionId: string, cell: EvalCell, workdir: string, defaultTimeoutSecs: number): Promise<EvalCellResult> {
    if (cell.reset) this.reset(cell.language, sessionId);
    const entry = this.get(cell.language, sessionId);
    const timeoutMs = Math.max(1, Number(cell.timeout ?? defaultTimeoutSecs)) * 1000;
    const title = String(cell.title ?? `${cell.language} cell ${index + 1}`);
    if (entry.language === "py") return entry.kernel.run(index, { code: cell.code, title, cwd: workdir, timeoutMs });
    return entry.kernel.run(index, { code: cell.code, title, timeoutMs });
  }

  close(): void {
    clearInterval(this.cleanupTimer);
    for (const entry of this.entries.values()) entry.kernel.close();
    this.entries.clear();
  }
}
