import * as fs from "fs";
import * as path from "path";
import type { AgentEvent } from "./runtime-process.js";

type TranscriptState = "idle" | "thinking" | "tools_wait" | "tools_run" | "error";

function formatTimestamp(now: Date = new Date()): string {
  const hh = String(now.getHours()).padStart(2, "0");
  const mm = String(now.getMinutes()).padStart(2, "0");
  const ss = String(now.getSeconds()).padStart(2, "0");
  const mmm = String(now.getMilliseconds()).padStart(3, "0");
  return `${hh}:${mm}:${ss}.${mmm}`;
}

function isInternalComposeStream(streamId: string): boolean {
  const id = (streamId ?? "").trim();
  return id.startsWith("compose-");
}

// sanitizeSessionID strips characters that would break filesystem paths or
// allow path traversal. Defensive against hostile MOTOKO_SESSION_ID values
// — the env var is set by the AILANG adapter from a uuid which is already
// safe, but a misconfigured operator or future caller could pass arbitrary
// text. Rules:
//   1. Replace any char outside [a-zA-Z0-9_-] with underscore.
//   2. Collapse any sequence of dots (..) to a single underscore — kills
//      path-traversal attempts while preserving ordinary names.
//   3. Reject results that are empty, all-dots, all-underscores, or "." /
//      ".." — fall back to a session_<timestamp> sentinel so the run
//      still produces a JSONL (rather than failing inside spawn).
function sanitizeSessionID(raw: string): string {
  // Step 1: replace forbidden chars with underscore.
  let safe = raw.replace(/[^a-zA-Z0-9_.-]/g, "_");
  // Step 2: collapse any run of dots — defends against ".." and ".../...".
  safe = safe.replace(/\.\.+/g, "_");
  // Step 3: cap length (FS path limit safety).
  safe = safe.slice(0, 200);
  // Step 4: reject degenerate results that can't be safe filenames.
  if (
    safe === "" ||
    safe === "." ||
    safe === ".." ||
    /^[._]+$/.test(safe)
  ) {
    return `session_${Date.now()}`;
  }
  return safe;
}

function stripLikelyInlineToolBlob(text: string): string {
  const m = text.match(/^\s*json\s*\{/i);
  if (!m || m.index === undefined) return text;
  const start = m.index + m[0].toLowerCase().indexOf("json");
  const tail = text.slice(start);
  const looksLikeToolBlob =
    tail.includes("\"tool_calls\"") &&
    tail.includes("\"tool\"") &&
    tail.includes("\"id\"") &&
    tail.length >= 400;
  if (!looksLikeToolBlob) return text;
  return text.slice(0, start).trimEnd();
}

function recordValue(v: unknown): Record<string, unknown> | null {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : null;
}

function stringValue(v: unknown, fallback = ""): string {
  return typeof v === "string" ? v : fallback;
}

function numberValue(v: unknown, fallback = 0): number {
  return typeof v === "number" && Number.isFinite(v) ? v : fallback;
}

function boolValue(v: unknown, fallback = false): boolean {
  return typeof v === "boolean" ? v : fallback;
}

function splitOutputLines(text: string): string[] {
  const trimmed = text.replace(/\s+$/g, "");
  return trimmed === "" ? [] : trimmed.split(/\r?\n/);
}

function scratchpadMetadataLines(metadata: unknown): string[] {
  const rec = recordValue(metadata);
  if (!rec) return [];
  const lines: string[] = [];
  const ailang = recordValue(rec.ailang);
  if (ailang) {
    const check = stringValue(ailang.check, "skipped");
    const verify = stringValue(ailang.verify, "skipped");
    const verifyAvailable = boolValue(ailang.verifyAvailable, false);
    const parts = [
      `check ${check}`,
      `verify ${verify}${!verifyAvailable && check === "passed" ? " (Z3 unavailable)" : ""}`,
      `committed ${boolValue(ailang.committed, false) ? "yes" : "no"}`,
    ];
    if (boolValue(ailang.ran, false)) parts.push("ran yes");
    lines.push(`  ailang: ${parts.join(" | ")}`);
    const fns = Array.isArray(ailang.functions)
      ? ailang.functions.map(recordValue).filter((f): f is Record<string, unknown> => f !== null)
      : [];
    for (const f of fns) {
      lines.push(`    ${stringValue(f.function, "<anon>")}: ${stringValue(f.status, "unknown")}`);
    }
    const notice = stringValue(ailang.notice, "");
    if (notice) lines.push(...splitOutputLines(notice).map((line) => `    ${line}`));
  }
  const lean = recordValue(rec.lean);
  if (lean) {
    const parts = [
      `elaboration ${stringValue(lean.elaborated, "error")}`,
      `proof ${stringValue(lean.proof, "error")}`,
      `committed ${boolValue(lean.committed, false) ? "yes" : "no"}`,
    ];
    lines.push(`  lean: ${parts.join(" | ")}`);
    const theorems = Array.isArray(lean.theorems)
      ? lean.theorems.map(recordValue).filter((t): t is Record<string, unknown> => t !== null)
      : [];
    for (const t of theorems) {
      const axioms = Array.isArray(t.axioms) ? t.axioms.filter((x): x is string => typeof x === "string") : [];
      lines.push(`    ${stringValue(t.name, "<anon>")}: ${stringValue(t.status, "error")}${axioms.length > 0 ? ` axioms=[${axioms.join(", ")}]` : ""}`);
    }
    const unexpected = Array.isArray(lean.unexpectedAxioms)
      ? lean.unexpectedAxioms.filter((x): x is string => typeof x === "string")
      : [];
    if (unexpected.length > 0) lines.push(`    unexpected axioms: ${unexpected.join(", ")}`);
    const sorries = numberValue(lean.sorries, 0);
    if (sorries > 0) lines.push(`    sorries: ${sorries}`);
    const notice = stringValue(lean.notice, "");
    if (notice) lines.push(...splitOutputLines(notice).map((line) => `    ${line}`));
  }
  return lines;
}

function displayBundleLines(display: unknown): string[] {
  const rec = recordValue(display);
  if (!rec) return [];
  const type = stringValue(rec.type, "text");
  if (type === "status" || type === "text" || type === "markdown") {
    return splitOutputLines(String(rec.data ?? ""));
  }
  if (type === "json") {
    return splitOutputLines(JSON.stringify(rec.data, null, 2));
  }
  if (type === "image") {
    const dataRec = recordValue(rec.data);
    const path = stringValue(dataRec?.path, typeof rec.data === "string" ? "<inline>" : "<image>");
    const mime = stringValue(rec.mime ?? dataRec?.mime, "image/*");
    const width = numberValue(rec.width ?? dataRec?.width, 0);
    const height = numberValue(rec.height ?? dataRec?.height, 0);
    const dims = width > 0 && height > 0 ? ` (${width}x${height} ${mime})` : ` (${mime})`;
    return [`[image: ${path}${dims}]`];
  }
  return [];
}

function formatScratchpadResultForTranscript(event: Extract<AgentEvent, { type: "scratchpad_result" }>): string {
  let parsed: unknown;
  try {
    parsed = JSON.parse(event.cells_json);
  } catch {
    return `[scratchpad] ${event.tool_call_id} invalid cells_json`;
  }
  if (!Array.isArray(parsed)) return `[scratchpad] ${event.tool_call_id} invalid cells_json`;
  const cells = parsed.map(recordValue).filter((cell): cell is Record<string, unknown> => cell !== null);
  if (cells.length !== parsed.length) return `[scratchpad] ${event.tool_call_id} invalid cells_json`;

  const passed = cells.filter((cell) => numberValue(cell.exit_code ?? cell.exitCode, 0) === 0 && recordValue(cell.error) === null).length;
  const totalDuration = cells.reduce((sum, cell) => sum + (typeof cell.durationMs === "number" ? cell.durationMs : 0), 0);
  const duration = totalDuration > 0 ? ` | ${Math.round(totalDuration)}ms` : "";
  const lines = [`SCRATCHPAD | ${cells.length} cell${cells.length === 1 ? "" : "s"} | ok ${passed} failed ${cells.length - passed}${duration}`];
  for (const cell of cells) {
    const index = numberValue(cell.index, 0) + 1;
    const language = stringValue(cell.language, "unknown");
    const title = stringValue(cell.title, `${language} cell ${index}`);
    const exitCode = numberValue(cell.exit_code ?? cell.exitCode, 0);
    const ok = exitCode === 0 && recordValue(cell.error) === null;
    const cellDuration = typeof cell.durationMs === "number" ? ` (${Math.max(0, Math.round(cell.durationMs))}ms)` : "";
    lines.push(`${ok ? "OK" : "FAIL"} [${index}/${cells.length}] ${title}${cellDuration}`);
    lines.push(...scratchpadMetadataLines(cell.metadata));
    const code = stringValue(cell.code, "");
    if (code.trim() !== "") {
      for (const line of splitOutputLines(code)) lines.push(`  ${line}`);
    }
    lines.push("  - Output");
    for (const line of splitOutputLines(stringValue(cell.stdout, ""))) lines.push(`  ${line}`);
    for (const line of splitOutputLines(stringValue(cell.stderr, ""))) lines.push(`  [stderr] ${line}`);
    const displays = Array.isArray(cell.displays)
      ? cell.displays
      : Array.isArray(cell.display)
        ? cell.display
        : [];
    for (const display of displays) {
      for (const line of displayBundleLines(display)) lines.push(`  ${line}`);
    }
    const resultLines = displayBundleLines(cell.result);
    if (resultLines.length > 0) {
      lines.push("  [result]");
      for (const line of resultLines) lines.push(`  ${line}`);
    }
    const error = recordValue(cell.error);
    if (error) lines.push(`    error: ${stringValue(error.ename, "Error")}: ${stringValue(error.evalue, "")}`);
    if (boolValue(cell.truncated, false)) lines.push("  [truncated]");
  }
  return lines.join("\n");
}

export class SessionLogger {
  private jsonlStream: fs.WriteStream;
  private markdownStream: fs.WriteStream;
  private closed = false;
  private transcriptState: TranscriptState = "idle";
  private readonly streamBuffers = new Map<string, string>();
  private readonly streamedSteps = new Set<number>();
  private readonly tuiVersion: string;
  readonly filePath: string;
  readonly markdownPath: string;

  constructor(projectRoot: string, tuiVersion: string) {
    const dir = path.join(projectRoot, ".motoko", "logfile");
    fs.mkdirSync(dir, { recursive: true });

    // M-MOTOKO-EVAL-HARNESS-HARDENING M4a (gap #4): when MOTOKO_SESSION_ID
    // is set (the AILANG eval harness adapter sets it before spawning), use
    // it as the filename stem so the JSONL filename matches what the
    // adapter searches for AND what AILANG-side derive_session_id() returns.
    // Pre-M4a, three session_ids coexisted: (a) adapter env var, (b) this
    // ISO-timestamp filename, (c) AILANG-side derive_session_id — only (a)
    // and (c) matched. Now all three converge on the env var when set.
    // ISO timestamp remains the fallback for interactive runs (no env var).
    const envID = (process.env.MOTOKO_SESSION_ID ?? "").trim();
    const stem = envID !== ""
      ? sanitizeSessionID(envID)
      : `session_${new Date().toISOString().replace(/[:.]/g, "-")}`;
    this.filePath = path.join(dir, `${stem}.jsonl`);
    this.markdownPath = path.join(dir, `${stem}.md`);
    this.jsonlStream = fs.createWriteStream(this.filePath, { flags: "a" });
    this.markdownStream = fs.createWriteStream(this.markdownPath, { flags: "a" });
    this.tuiVersion = tuiVersion;
  }

  logUserInput(content: string): void {
    const msg = content.trim();
    if (!msg || this.closed) return;
    this.writeTranscriptLine(`> ${msg}`);
  }

  private writeTranscriptLine(message: string): void {
    if (this.closed) return;
    this.markdownStream.write(`[${formatTimestamp()}] ${message}\n`);
  }

  private writeTranscriptMarkdown(message: string): void {
    if (this.closed) return;
    this.markdownStream.write(`[${formatTimestamp()}] ${message}\n`);
  }

  private setState(next: TranscriptState): void {
    this.transcriptState = next;
  }

  private ensureThinkingLine(): void {
    if (this.transcriptState !== "thinking") {
      this.writeTranscriptLine("Runtime is reasoning...");
      this.setState("thinking");
    }
  }

  private logTranscriptEvent(event: AgentEvent): void {
    switch (event.type) {
      case "session_start":
        this.ensureThinkingLine();
        this.writeTranscriptLine(`AILANG built ${event.ailangBuilt} | Core Runtime v${event.brainVersion} | TUI v${this.tuiVersion}`);
        if (Array.isArray(event.loaded_extensions)) {
          const extText = event.loaded_extensions.length > 0 ? event.loaded_extensions.join(", ") : "(none)";
          this.writeTranscriptLine(`Loaded extensions: ${extText}`);
        }
        break;
      case "session_resume":
        this.setState("idle");
        this.writeTranscriptLine(`Resumed ${event.restored_messages} messages`);
        break;
      case "thinking":
        this.ensureThinkingLine();
        {
          if (this.streamedSteps.has(event.step)) break;
          const answer = (event.answer ?? event.text ?? "").trim();
          const visible = stripLikelyInlineToolBlob(answer).trim();
          if (visible) this.writeTranscriptMarkdown(visible);
        }
        break;
      case "thinking_stream_start":
        if (isInternalComposeStream(event.stream_id)) break;
        this.ensureThinkingLine();
        this.streamedSteps.add(event.step);
        this.streamBuffers.set(event.stream_id, "");
        break;
      case "thinking_delta":
        if (isInternalComposeStream(event.stream_id)) break;
        this.streamBuffers.set(event.stream_id, (this.streamBuffers.get(event.stream_id) ?? "") + event.text_delta);
        break;
      case "thinking_stream_end":
        if (isInternalComposeStream(event.stream_id)) break;
        {
          const text = stripLikelyInlineToolBlob(this.streamBuffers.get(event.stream_id) ?? "").trim();
          if (text) this.writeTranscriptMarkdown(text);
          this.streamBuffers.delete(event.stream_id);
          if (event.status === "errored") {
            this.setState("error");
            this.writeTranscriptLine("Stream ended with error");
          } else if (event.status === "aborted") {
            this.writeTranscriptLine("Stream aborted");
          }
        }
        break;
      case "tool_calls":
        this.setState("tools_wait");
        this.writeTranscriptLine("Waiting for delegated tool results...");
        break;
      case "tool_results":
        if (event.phase === "done") {
          this.setState("thinking");
          this.writeTranscriptLine("Tool results received. Continuing reasoning...");
        } else {
          this.setState("tools_run");
        }
        break;
      case "obs":
        if (event.stdout) this.writeTranscriptMarkdown(event.stdout);
        if (event.stderr) this.writeTranscriptLine(`[stderr] ${event.stderr}`);
        break;
      case "scratchpad_result":
        this.writeTranscriptMarkdown(formatScratchpadResultForTranscript(event));
        break;
      case "warning":
        this.writeTranscriptLine(`Warning: ${event.message}`);
        break;
      case "error":
        this.setState("error");
        this.writeTranscriptLine(`Error: ${event.message}`);
        break;
      case "done":
        this.setState("idle");
        break;
      default:
        break;
    }
  }

  log(event: AgentEvent): void {
    if (this.closed) return;
    this.jsonlStream.write(`${JSON.stringify(event)}\n`);
    this.logTranscriptEvent(event);
  }

  close(): Promise<void> {
    if (this.closed) return Promise.resolve();
    this.closed = true;
    return Promise.all([
      new Promise<void>((resolve) => this.jsonlStream.end(() => resolve())),
      new Promise<void>((resolve) => this.markdownStream.end(() => resolve())),
    ]).then(() => undefined);
  }
}
