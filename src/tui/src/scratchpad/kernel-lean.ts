import { spawn, type ChildProcessWithoutNullStreams } from "child_process";
import type {
  ScratchpadCell,
  ScratchpadCellResult,
  ScratchpadDisplayBundle,
  LeanCellMetadata,
  LeanProofStatus,
} from "./frames.js";
import {
  LeanSession,
  aggregateProof,
  classifyTheoremAxioms,
  decideLeanCommit,
  hasSorry,
  mapElaboration,
  normalizeLeanProve,
  parseAxiomInfos,
  parseLeanCell,
  type LeanReplResponse,
} from "./lean-session.js";

export type LeanKernelConfig = {
  command?: string;
  args?: string[];
  cwd?: string;
  env?: Record<string, string>;
  mathlibCommand?: string;
  mathlibArgs?: string[];
  mathlibCwd?: string;
  agentPrompt?: () => string;
};

type Pending = {
  resolve: (r: LeanReplResponse) => void;
  reject: (e: Error) => void;
  timer: NodeJS.Timeout;
};

function stripTopImports(code: string): string {
  const out: string[] = [];
  let atTop = true;
  for (const line of code.replace(/\r\n/g, "\n").split("\n")) {
    const trimmed = line.trim();
    if (atTop && (trimmed === "" || /^import\b/.test(trimmed))) continue;
    atTop = false;
    out.push(line);
  }
  return out.join("\n").trim();
}

function statusSummary(meta: LeanCellMetadata): string {
  const parts = [
    `elaboration: ${meta.elaborated}`,
    `proof: ${meta.proof}`,
    `committed: ${meta.committed ? "yes" : "no"}`,
  ];
  let line = `[lean] ${parts.join(" | ")}`;
  if (meta.theorems && meta.theorems.length > 0) {
    line += "\n" + meta.theorems.map((t) => {
      const ax = t.axioms && t.axioms.length > 0 ? ` axioms=[${t.axioms.join(", ")}]` : "";
      return `  - ${t.name}: ${t.status}${ax}`;
    }).join("\n");
  }
  if (meta.unexpectedAxioms && meta.unexpectedAxioms.length > 0) {
    line += `\n  unexpected axioms: ${meta.unexpectedAxioms.join(", ")}`;
  }
  if (meta.notice) line += `\n${meta.notice}`;
  return line;
}

function messageText(resp: LeanReplResponse | null | undefined, severity?: string): string {
  const want = severity?.toLowerCase();
  return (resp?.messages ?? [])
    .filter((m) => !want || String(m.severity ?? "").toLowerCase() === want)
    .map((m) => String(m.data ?? ""))
    .filter(Boolean)
    .join("\n")
    .trim();
}

export class LeanKernel {
  readonly session = new LeanSession(false);
  private child: ChildProcessWithoutNullStreams | null = null;
  private pending: Pending | null = null;
  private stdoutBuf = "";
  private stderrBuf = "";
  private executionCount = 0;

  constructor(private readonly config: LeanKernelConfig = {}) {}

  private launchSpec(mathlib: boolean): { command: string; args: string[]; cwd?: string } {
    if (mathlib) {
      return {
        command: this.config.mathlibCommand ?? this.config.command ?? "lake",
        args: this.config.mathlibArgs ?? this.config.args ?? ["exe", "repl"],
        cwd: this.config.mathlibCwd ?? this.config.cwd,
      };
    }
    return {
      command: this.config.command ?? "lake",
      args: this.config.args ?? ["exe", "repl"],
      cwd: this.config.cwd,
    };
  }

  private start(workdir: string, mathlib: boolean): void {
    if (this.child) return;
    const spec = this.launchSpec(mathlib);
    this.stderrBuf = "";
    this.stdoutBuf = "";
    this.child = spawn(spec.command, spec.args, {
      cwd: spec.cwd ?? workdir,
      env: {
        ...process.env,
        ...this.config.env,
        AILANG_FS_SANDBOX: workdir,
        MOTOKO_SCRATCHPAD_NETWORK: String(process.env.MOTOKO_SCRATCHPAD_NETWORK ?? "0"),
      },
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.child.stdout.setEncoding("utf8");
    this.child.stdout.on("data", (chunk: string) => {
      this.stdoutBuf += chunk;
      this.drainStdout();
    });
    this.child.stderr.setEncoding("utf8");
    this.child.stderr.on("data", (chunk: string) => {
      this.stderrBuf += chunk;
    });
    this.child.on("error", (e) => this.failPending(new Error(`lean repl spawn failed: ${String((e as any)?.message ?? e)}`)));
    this.child.on("close", () => {
      this.child = null;
      this.failPending(new Error(this.stderrBuf.trim() || "lean repl exited"));
      this.session.reset(this.session.mathlib);
    });
  }

  private drainStdout(): void {
    while (true) {
      const idx = this.stdoutBuf.indexOf("\n\n");
      if (idx < 0) break;
      const raw = this.stdoutBuf.slice(0, idx).trim();
      this.stdoutBuf = this.stdoutBuf.slice(idx + 2);
      if (!raw || !this.pending) continue;
      const p = this.pending;
      clearTimeout(p.timer);
      this.pending = null;
      try {
        p.resolve(JSON.parse(raw) as LeanReplResponse);
      } catch (e: any) {
        p.reject(new Error(`lean repl returned unparseable JSON: ${String(e?.message ?? e)}; raw=${raw.slice(0, 500)}`));
      }
    }
  }

  private failPending(e: Error): void {
    if (!this.pending) return;
    const p = this.pending;
    clearTimeout(p.timer);
    this.pending = null;
    p.reject(e);
  }

  private kill(): void {
    if (!this.child) return;
    try { this.child.kill("SIGKILL"); } catch { /* ignore */ }
    this.child = null;
  }

  private request(cmd: string, env: number | null, timeoutMs: number): Promise<LeanReplResponse> {
    const child = this.child;
    if (!child) return Promise.reject(new Error("lean repl is not running"));
    if (this.pending) return Promise.reject(new Error("lean repl is busy"));
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (this.pending) this.pending = null;
        this.kill();
        reject(new Error(`lean cell timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending = { resolve, reject, timer };
      const payload: Record<string, unknown> = { cmd };
      if (env !== null) payload.env = env;
      child.stdin.write(JSON.stringify(payload) + "\n\n");
    });
  }

  private finish(
    index: number,
    title: string,
    code: string,
    meta: LeanCellMetadata,
    exit_code: number,
    stdout: string,
    stderr: string,
    teachPrompt?: string,
  ): ScratchpadCellResult {
    const displays: ScratchpadDisplayBundle[] = [{ type: "status", mime: "text/plain", data: statusSummary(meta) }];
    const visibleStdout = teachPrompt
      ? `===== Lean 4 teaching guide - read before authoring (shown once per session) =====\n${teachPrompt}\n===== end Lean 4 teaching guide =====\n${stdout}`
      : stdout;
    return {
      index,
      language: "lean",
      title,
      code,
      exit_code,
      stdout: visibleStdout,
      stderr,
      displays,
      executionCount: this.executionCount,
      cancelled: false,
      truncated: Buffer.byteLength(visibleStdout + stderr, "utf8") > 64 * 1024,
      metadata: { lean: { ...meta, teachPrompt } },
    };
  }

  async run(index: number, opts: { cell: ScratchpadCell; title: string; timeoutMs: number; workdir: string }): Promise<ScratchpadCellResult> {
    this.executionCount += 1;
    const { cell, title, timeoutMs, workdir } = opts;
    const mathlib = cell.mathlib === true;
    if (cell.reset || this.session.mathlib !== mathlib) {
      this.close();
      this.session.reset(mathlib);
    }

    let teachPrompt: string | undefined;
    if (!this.session.teachPromptSeen) {
      const p = this.config.agentPrompt?.() ?? "";
      if (p.trim() !== "") teachPrompt = p;
      this.session.teachPromptSeen = true;
    }

    const parsed = parseLeanCell(cell.code);
    const proveMode = normalizeLeanProve(cell.prove);
    const noticeParts: string[] = [];

    if (parsed.imports.length > 0 && this.session.committedEnv !== null) {
      const meta: LeanCellMetadata = {
        elaborated: "failed",
        proof: "failed",
        committed: false,
        sorries: 0,
        notice: "imports are only allowed at the start of a fresh Lean session; use reset:true before importing",
      };
      return this.finish(index, title, cell.code, meta, 1, "", meta.notice ?? "", teachPrompt);
    }

    try {
      this.start(workdir, mathlib);
      let baseEnv = this.session.committedEnv;
      if (parsed.imports.length > 0 && baseEnv === null) {
        const importResp = await this.request(parsed.imports.join("\n"), null, timeoutMs);
        if (mapElaboration(importResp) !== "passed" || typeof importResp.env !== "number") {
          const meta: LeanCellMetadata = {
            elaborated: mapElaboration(importResp),
            proof: "failed",
            committed: false,
            sorries: importResp.sorries?.length ?? 0,
            notice: messageText(importResp) || "Lean import command failed",
          };
          return this.finish(index, title, cell.code, meta, 1, "", meta.notice ?? "", teachPrompt);
        }
        baseEnv = importResp.env;
        if (stripTopImports(cell.code) === "") {
          this.session.commit(baseEnv, parsed);
          const meta: LeanCellMetadata = {
            elaborated: "passed",
            proof: "skipped",
            committed: true,
            sorries: 0,
          };
          return this.finish(index, title, cell.code, meta, 0, "", "", teachPrompt);
        }
      }

      const cmd = parsed.imports.length > 0 ? stripTopImports(cell.code) : cell.code;
      const resp = await this.request(cmd, baseEnv, timeoutMs);
      const elaborated = mapElaboration(resp);
      const sorrySeen = hasSorry(resp);
      const sorries = resp.sorries?.length ?? 0;
      let theoremProofs = [] as NonNullable<LeanCellMetadata["theorems"]>;
      let axiomAuditError = false;

      if (elaborated === "passed" && parsed.namedTheorems.length > 0 && typeof resp.env === "number") {
        const auditCmd = parsed.namedTheorems.map((name) => `#print axioms ${name}`).join("\n");
        const auditResp = await this.request(auditCmd, resp.env, timeoutMs);
        if (mapElaboration(auditResp) !== "passed") {
          axiomAuditError = true;
          noticeParts.push(messageText(auditResp) || "axiom audit failed");
        } else {
          const infos = parseAxiomInfos(auditResp.messages);
          const byName = new Map(infos.map((i) => [i.name, i.axioms]));
          theoremProofs = parsed.namedTheorems.map((name) => {
            const axioms = byName.get(name);
            if (!axioms) return { name, status: "error" as LeanProofStatus, axioms: [] };
            return classifyTheoremAxioms(name, axioms, sorrySeen);
          });
        }
      }

      const proof = aggregateProof({ elaborated, parsed, theoremProofs, sorrySeen, axiomAuditError });
      const decision = decideLeanCommit({
        elaborated,
        proof,
        proveMode,
        hasNamedTheorems: parsed.namedTheorems.length > 0,
      });
      if (!decision.commit && decision.reason) noticeParts.push(`not committed: ${decision.reason}`);
      if (elaborated === "failed") noticeParts.push(messageText(resp, "error") || "Lean elaboration failed");
      if (parsed.hasAnonymousExample && proof === "skipped") {
        noticeParts.push("anonymous examples cannot be axiom-audited; use a named theorem or lemma for a verified proof verdict");
      }

      if (decision.commit && typeof resp.env === "number") this.session.commit(resp.env, parsed);
      const unexpectedAxioms = theoremProofs
        .flatMap((t) => t.axioms ?? [])
        .filter((a) => !["propext", "Classical.choice", "Quot.sound"].includes(a));
      const meta: LeanCellMetadata = {
        elaborated,
        proof,
        committed: decision.commit,
        theorems: theoremProofs.length > 0 ? theoremProofs : undefined,
        sorries,
        unexpectedAxioms: unexpectedAxioms.length > 0 ? [...new Set(unexpectedAxioms)] : undefined,
        notice: noticeParts.length > 0 ? noticeParts.join("; ") : undefined,
      };
      const stdout = messageText(resp, "info");
      const stderr = [messageText(resp, "warning"), meta.notice].filter(Boolean).join("\n");
      const exit_code = decision.commit && elaborated === "passed" ? 0 : 1;
      return this.finish(index, title, cell.code, meta, exit_code, stdout, stderr, teachPrompt);
    } catch (e: any) {
      this.kill();
      this.session.reset(mathlib);
      const msg = String(e?.message ?? e);
      const meta: LeanCellMetadata = {
        elaborated: "error",
        proof: "error",
        committed: false,
        sorries: 0,
        notice: msg,
      };
      return this.finish(index, title, cell.code, meta, 1, "", msg, teachPrompt);
    }
  }

  close(): void {
    if (!this.child) return;
    try { this.child.stdin.end(); } catch { /* ignore */ }
    try { this.child.kill("SIGTERM"); } catch { /* ignore */ }
    this.child = null;
  }
}
