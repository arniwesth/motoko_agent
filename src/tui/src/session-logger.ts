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

    const ts = new Date().toISOString().replace(/[:.]/g, "-");
    this.filePath = path.join(dir, `session_${ts}.jsonl`);
    this.markdownPath = path.join(dir, `session_${ts}.md`);
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
