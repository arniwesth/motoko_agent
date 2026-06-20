// AILANG scratchpad kernel — drives the `ailang` CLI (ai-check / verify / run) over a
// persistent source session. See ailang-session.ts for the (CLI-free) source
// accumulation + gate logic; this file owns process execution and result
// shaping only.

import { execFileSync } from "child_process";
import { mkdirSync, writeFileSync } from "fs";
import { join } from "path";
import type {
  AilangCellMetadata,
  ScratchpadCell,
  ScratchpadCellResult,
  ScratchpadDisplayBundle,
} from "./frames.js";
import {
  AilangSession,
  DEFAULT_ENTRY,
  type AiCheckJson,
  aggregateVerify,
  decideCommit,
  fnVerifies,
  mapCheckStatus,
  normalizeVerifyMode,
  parseCell,
} from "./ailang-session.js";

export type AilangKernelConfig = {
  ailangBin?: string;
  tmpDir?: string;
  // Capability ceiling enforced by the host. Requested caps are intersected
  // with this set; nothing outside it can ever be granted.
  capsCeiling?: string[];
  // Lazily-cached provider of the one-time teaching prompt (e.g. wrapping
  // `ailang agent-prompt`). Returns "" if unavailable.
  agentPrompt?: () => string;
};

function intersectCaps(requested: string, ceiling: string[]): { caps: string[]; dropped: string[] } {
  const ceil = new Set(ceiling.map((c) => c.trim()).filter(Boolean));
  const req = requested.split(",").map((c) => c.trim()).filter(Boolean);
  const caps: string[] = [];
  const dropped: string[] = [];
  for (const c of req) {
    if (ceil.has(c)) caps.push(c);
    else dropped.push(c);
  }
  return { caps, dropped };
}

function parseAiCheck(stdout: string): AiCheckJson | null {
  const trimmed = stdout.trim();
  if (trimmed === "") return null;
  // ai-check emits a single JSON object; be tolerant of leading progress noise
  // by slicing from the first `{`.
  const start = trimmed.indexOf("{");
  if (start < 0) return null;
  try {
    return JSON.parse(trimmed.slice(start)) as AiCheckJson;
  } catch {
    return null;
  }
}

function checkErrorsText(j: AiCheckJson): string {
  const errs = j.check?.errors ?? [];
  return errs.map((e) => (e.code ? `${e.code}: ${e.message ?? ""}` : String(e.message ?? ""))).join("\n").trim();
}

function statusSummary(meta: AilangCellMetadata): string {
  const parts = [`check: ${meta.check}`];
  // Only attribute a skipped verify to a missing Z3 when the check actually
  // passed — when check fails, ai-check never attempts verification, so
  // "Z3 unavailable" would be misleading.
  const v = (!meta.verifyAvailable && meta.check === "passed") ? `${meta.verify} (Z3 unavailable)` : meta.verify;
  parts.push(`verify: ${v}`);
  parts.push(`committed: ${meta.committed ? "yes" : "no"}`);
  if (meta.ran) parts.push("ran: yes");
  let line = `[ailang] ${parts.join(" | ")}`;
  if (meta.functions && meta.functions.length > 0) {
    line += "\n" + meta.functions.map((f) => `  - ${f.function}: ${f.status}`).join("\n");
  }
  if (meta.notice) line += `\n${meta.notice}`;
  return line;
}

export class AilangKernel {
  readonly session = new AilangSession();
  private seq = 0;
  executionCount = 0;

  constructor(private readonly config: AilangKernelConfig = {}) {}

  private bin(): string {
    return this.config.ailangBin ?? "ailang";
  }

  private writeModule(source: string): string {
    const dir = this.config.tmpDir ?? "/tmp/motoko-ailang-scratchpad";
    mkdirSync(dir, { recursive: true });
    this.seq += 1;
    const path = join(dir, `scratchpad_session_${process.pid}_${Date.now()}_${this.seq}.ail`);
    writeFileSync(path, source, "utf8");
    return path;
  }

  private runAiCheck(path: string, timeoutMs: number): { json: AiCheckJson | null; stderr: string } {
    try {
      const out = execFileSync(this.bin(), ["ai-check", "-relax-modules", path], {
        timeout: timeoutMs,
        encoding: "utf8",
        maxBuffer: 8 * 1024 * 1024,
      });
      return { json: parseAiCheck(out), stderr: "" };
    } catch (e: any) {
      // ai-check exits non-zero when the check fails, but still prints JSON on
      // stdout — prefer that over the raw error.
      const out = String(e?.stdout ?? "");
      const json = parseAiCheck(out);
      return { json, stderr: json ? "" : String(e?.stderr ?? e?.message ?? e) };
    }
  }

  private runEntry(path: string, entry: string, caps: string[], timeoutMs: number): { stdout: string; stderr: string; exit_code: number } {
    const args = ["run", "--quiet", "--relax-modules"];
    if (caps.length > 0) args.push("--caps", caps.join(","));
    args.push("--entry", entry, path);
    try {
      const out = execFileSync(this.bin(), args, { timeout: timeoutMs, encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
      return { stdout: out, stderr: "", exit_code: 0 };
    } catch (e: any) {
      return {
        stdout: String(e?.stdout ?? ""),
        stderr: String(e?.stderr ?? e?.message ?? e),
        exit_code: typeof e?.status === "number" ? e.status : 1,
      };
    }
  }

  run(index: number, opts: { cell: ScratchpadCell; timeoutMs: number }): ScratchpadCellResult {
    this.executionCount += 1;
    const { cell, timeoutMs } = opts;
    const title = String(cell.title ?? `ail cell ${index + 1}`);
    const entry = String(cell.entry ?? DEFAULT_ENTRY);

    if (cell.reset) this.session.reset();

    // One-time teaching prompt: attached to the first AILANG authoring attempt
    // in this session, regardless of outcome.
    let teachPrompt: string | undefined;
    if (!this.session.teachPromptSeen) {
      const p = this.config.agentPrompt?.() ?? "";
      if (p.trim() !== "") teachPrompt = p;
      this.session.teachPromptSeen = true;
    }

    const finish = (
      meta: AilangCellMetadata,
      exit_code: number,
      programStdout: string,
      stderr: string,
    ): ScratchpadCellResult => {
      const displays: ScratchpadDisplayBundle[] = [
        { type: "status", mime: "text/plain", data: statusSummary(meta) },
      ];
      // Surface the one-time teaching guide in the VISIBLE output (stdout), not
      // just in nested metadata — that is what the model reads back. Without
      // this the model never sees the AILANG syntax reference and keeps failing
      // `check` by guessing. Shown once per session (teachPrompt is only set on
      // the first authoring attempt).
      const visibleStdout = teachPrompt
        ? `===== AILANG teaching guide — read before authoring (shown once per session) =====\n${teachPrompt}\n===== end AILANG teaching guide =====\n${programStdout}`
        : programStdout;
      return {
        index,
        language: "ail",
        title,
        exit_code,
        stdout: visibleStdout,
        stderr,
        displays,
        executionCount: this.executionCount,
        cancelled: false,
        truncated: Buffer.byteLength(visibleStdout + stderr, "utf8") > 64 * 1024,
        metadata: { ailang: { ...meta, teachPrompt } },
      };
    };

    const parsed = parseCell(cell.code);

    // Reject duplicate top-level declarations (MVP: no in-place replacement).
    const dups = this.session.duplicateNames(parsed, entry);
    if (dups.length > 0) {
      const meta: AilangCellMetadata = {
        check: "skipped",
        verify: "skipped",
        verifyAvailable: true,
        committed: false,
        ran: false,
        notice: `duplicate top-level declaration(s) already accepted: ${dups.join(", ")}. AILANG scratchpad does not replace declarations in place; use reset:true to start a fresh session.`,
      };
      return finish(meta, 1, "", meta.notice ?? "");
    }

    const source = this.session.renderModule(parsed);
    const modPath = this.writeModule(source);

    const { json, stderr: checkStderr } = this.runAiCheck(modPath, timeoutMs);
    if (!json) {
      const meta: AilangCellMetadata = {
        check: "failed",
        verify: "skipped",
        verifyAvailable: false,
        committed: false,
        ran: false,
        notice: "ailang ai-check produced no parseable output",
      };
      return finish(meta, 1, "", checkStderr || (meta.notice ?? ""));
    }

    const check = mapCheckStatus(json);
    const { status: verify, available: verifyAvailable } = aggregateVerify(json);
    const functions = fnVerifies(json);

    const decision = decideCommit({
      check,
      verify,
      verifyAvailable,
      verifyMode: cell.verify,
      hasAnnotations: parsed.hasAnnotations,
    });

    const noticeParts: string[] = [];
    if (check === "failed") noticeParts.push(checkErrorsText(json) || "type-check failed");
    if (!decision.commit && check === "passed") noticeParts.push(`not committed: ${decision.reason}`);

    if (decision.commit) this.session.commit(parsed, entry);

    // Run only when explicitly requested AND the module type-checks (we never
    // execute code that failed `check`). Run uses the rendered candidate module
    // so the just-authored entry is available.
    let ran = false;
    let programStdout = "";
    let runStderr = "";
    let runExit = 0;
    const verifyMode = normalizeVerifyMode(cell.verify);
    const runGateOk = check === "passed" && (verifyMode !== "required" || decision.commit);
    if (cell.run === true && runGateOk) {
      const { caps, dropped } = intersectCaps(cell.caps ?? "", this.config.capsCeiling ?? []);
      if (dropped.length > 0) noticeParts.push(`capabilities denied by policy: ${dropped.join(", ")}`);
      const r = this.runEntry(modPath, entry, caps, timeoutMs);
      ran = true;
      programStdout = r.stdout;
      runStderr = r.stderr;
      runExit = r.exit_code;
    } else if (cell.run === true && !runGateOk) {
      noticeParts.push("run skipped: check/verify gate not satisfied");
    }

    const meta: AilangCellMetadata = {
      check,
      verify,
      verifyAvailable,
      committed: decision.commit,
      ran,
      functions: functions.length > 0 ? functions : undefined,
      notice: noticeParts.length > 0 ? noticeParts.join("; ") : undefined,
    };

    const exit_code = check === "passed" && decision.commit && runExit === 0 ? 0 : 1;
    return finish(meta, exit_code, programStdout, runStderr);
  }

  close(): void {
    /* no long-lived process to tear down */
  }
}
