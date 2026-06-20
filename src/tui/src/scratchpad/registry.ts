import type { ScratchpadCell, ScratchpadCellResult, ScratchpadLanguage } from "./frames.js";
import { PythonKernel } from "./kernel-py.js";
import { JsKernel, type JsLoopback } from "./kernel-js.js";
import { AilangKernel, type AilangKernelConfig } from "./kernel-ailang.js";
import { LeanKernel, type LeanKernelConfig } from "./kernel-lean.js";

type RegistryEntry =
  | { language: "py"; kernel: PythonKernel; lastUsed: number }
  | { language: "js"; kernel: JsKernel; lastUsed: number }
  | { language: "ail"; kernel: AilangKernel; lastUsed: number }
  | { language: "lean"; kernel: LeanKernel; lastUsed: number };

export class ScratchpadKernelRegistry {
  private entries = new Map<string, RegistryEntry>();
  private cleanupTimer: NodeJS.Timeout;

  constructor(
    private readonly idleMs: number,
    private readonly makePythonEnv: () => Record<string, string>,
    private readonly makeJsLoopback: () => JsLoopback,
    private readonly makeAilangConfig: () => AilangKernelConfig = () => ({}),
    private readonly makeLeanConfig: () => LeanKernelConfig = () => ({}),
  ) {
    this.cleanupTimer = setInterval(() => this.evictIdle(), Math.max(30_000, Math.min(idleMs, 60_000)));
    this.cleanupTimer.unref();
  }

  private key(language: ScratchpadLanguage, sessionId: string): string {
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

  reset(language: ScratchpadLanguage, sessionId: string): void {
    const key = this.key(language, sessionId);
    const existing = this.entries.get(key);
    if (existing) existing.kernel.close();
    this.entries.delete(key);
  }

  private get(language: ScratchpadLanguage, sessionId: string): RegistryEntry {
    const key = this.key(language, sessionId);
    const existing = this.entries.get(key);
    if (existing) {
      existing.lastUsed = Date.now();
      return existing;
    }
    let entry: RegistryEntry;
    if (language === "py") {
      entry = { language, kernel: new PythonKernel(this.makePythonEnv()), lastUsed: Date.now() };
    } else if (language === "js") {
      entry = { language, kernel: new JsKernel(this.makeJsLoopback()), lastUsed: Date.now() };
    } else if (language === "ail") {
      entry = { language, kernel: new AilangKernel(this.makeAilangConfig()), lastUsed: Date.now() };
    } else {
      entry = { language, kernel: new LeanKernel(this.makeLeanConfig()), lastUsed: Date.now() };
    }
    this.entries.set(key, entry);
    return entry;
  }

  async runCell(index: number, sessionId: string, cell: ScratchpadCell, workdir: string, defaultTimeoutSecs: number): Promise<ScratchpadCellResult> {
    // AILANG/Lean reset is handled inside the kernel (session.reset) so that the
    // one-time teach-prompt marker survives a source reset; py/js reset
    // destroys the kernel process.
    if (cell.reset && cell.language !== "ail" && cell.language !== "lean") this.reset(cell.language, sessionId);
    const entry = this.get(cell.language, sessionId);
    const timeoutMs = Math.max(1, Number(cell.timeout ?? defaultTimeoutSecs)) * 1000;
    const title = String(cell.title ?? `${cell.language} cell ${index + 1}`);
    const started = Date.now();
    let result: ScratchpadCellResult;
    if (entry.language === "py") {
      result = await entry.kernel.run(index, { code: cell.code, title, cwd: workdir, timeoutMs });
    } else if (entry.language === "js") {
      result = await entry.kernel.run(index, { code: cell.code, title, timeoutMs });
    } else if (entry.language === "ail") {
      result = entry.kernel.run(index, { cell, timeoutMs });
    } else {
      result = await entry.kernel.run(index, { cell, title, timeoutMs, workdir });
    }
    return { ...result, code: cell.code, durationMs: Date.now() - started };
  }

  close(): void {
    clearInterval(this.cleanupTimer);
    for (const entry of this.entries.values()) entry.kernel.close();
    this.entries.clear();
  }
}
