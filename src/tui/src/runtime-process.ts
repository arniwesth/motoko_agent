import { spawn, ChildProcess } from "child_process";
import * as path from "path";
import * as readline from "readline";
import { createOhMyPiSession } from "./ohMyPi/session-adapter.js";
import { dispatchOhMyPiTool } from "./ohMyPi/dispatcher.js";

export interface DelegatedExecReq {
  cmd: string;
  args?: string[];
  cwd?: string;
  streaming?: boolean;
  needs_stderr_live?: boolean;
  needs_hard_cancel?: boolean;
}

export interface DelegatedCall {
  id: string;
  tool: string;
  intent?: string;
  intent_kind?: string;
  expected_output?: string;
  hints?: { read?: string[]; write?: string[]; avoid?: string[] };
  path?: string;
  edits?: Array<{ old: string; new: string; replace_all?: boolean }>;
  dry_run?: boolean;
  expected_sha256?: string;
  start?: number;
  end?: number;
  pattern?: string;
  dir?: string;
  context?: number;
  content?: string;
  exec?: DelegatedExecReq;
  arguments?: Record<string, unknown>;
}

export interface DelegatedResult {
  tool_call_id: string;
  stdout: string;
  stderr: string;
  exit_code: number;
  truncated: boolean;
}

export interface NativeToolResult {
  tool_call_id: string;
  exit_code: number;
  stdout?: string;
  stderr?: string;
  truncated?: boolean;
}

export type ToolResultsPhase = "running" | "progress" | "done";

export type AgentEvent =
  | { type: "session_start"; task: string; model: string; brainVersion: string; ailangBuilt: string; loaded_extensions?: string[] }
  | { type: "context_usage"; step: number; tokens_est: number; limit: number }
  | { type: "thinking_stream_start"; step: number; stream_id: string; model: string }
  | { type: "thinking_delta"; step: number; stream_id: string; seq: number; text_delta: string }
  | { type: "thinking_stream_end"; step: number; stream_id: string; status: "completed" | "aborted" | "errored" }
  | { type: "thinking_stream_error"; step: number; stream_id: string; message: string; retryable: boolean }
  | { type: "thinking"; step: number; text: string; think?: string; answer?: string }
  | { type: "proposed_cmd"; step: number; cmd: string }
  | { type: "proposed_ailang"; step: number; code: string }
  | { type: "ailang_check"; step: number; passed: boolean; errors: string; attempt: number; max_attempts: number }
  | { type: "compose_start"; step: number; compose_id: string; intent: string; intent_kind?: string; claimcheck_enabled?: boolean; model: string; max_attempts: number }
  | { type: "compose_author_delta"; step: number; compose_id: string; attempt: number; delta: string }
  | { type: "compose_author_error"; step: number; compose_id: string; attempt: number; mode?: string; error: string }
  | { type: "compose_author_tool_call"; step: number; compose_id: string; attempt: number; tool: string; args?: string }
  | { type: "compose_author_tool_result"; step: number; compose_id: string; attempt: number; tool: string; ok: boolean; excerpt?: string; bytes?: number; truncated?: boolean }
  | { type: "compose_author_ledger_snapshot"; step: number; compose_id: string; attempt: number; budget_used?: number; budget_cap?: number; entries?: number }
  | { type: "compose_snippet"; step: number; compose_id: string; attempt: number; code: string }
  | { type: "compose_check"; step: number; compose_id: string; attempt: number; passed: boolean; errors?: string }
  | { type: "compose_retry"; step: number; compose_id: string; attempt: number; reason: string }
  | { type: "compose_exec"; step: number; compose_id: string; stdout: string; stderr: string; exit_code: number }
  | { type: "compose_claimcheck_informalize_delta"; step: number; compose_id: string; attempt: number; delta: string }
  | { type: "compose_claimcheck_informalize_result"; step: number; compose_id: string; attempt: number; informalization: string }
  | { type: "compose_claimcheck_compare_delta"; step: number; compose_id: string; attempt: number; delta: string }
  | { type: "compose_claimcheck_compare_result"; step: number; compose_id: string; attempt: number; verdict: "confirmed" | "disputed" | "vacuous" | "surprising_restriction" | "inconclusive"; confidence: "high" | "low"; reason: string; informalization?: string }
  | { type: "compose_summary_delta"; step: number; compose_id: string; delta: string }
  | { type: "compose_result"; step: number; compose_id: string; attempts: number; summary: string; stdout: string; stderr: string; exit_code: number; truncated: boolean; telemetry_json?: string }
  | {
      type: "obs";
      step: number;
      cmd: string;
      stdout: string;
      stderr: string;
      exit_code: number;
    }
  | { type: "done"; step: number; output: string }
  | { type: "error"; message: string }
  | { type: "warning"; message: string }
  | { type: "tool_calls"; request_id: string; tool_calls: DelegatedCall[] }
  | { type: "tool_results"; request_id: string; phase: ToolResultsPhase; results: DelegatedResult[] }
  | { type: "native_tool_calls"; request_id: string; tool_calls: DelegatedCall[] }
  | { type: "native_tool_results"; request_id: string; results: NativeToolResult[] };

export function parseAgentEventLine(line: string): AgentEvent | null {
  const trimmed = line.trim();
  if (!trimmed) return null;
  try {
    const parsed = JSON.parse(trimmed) as unknown;
    if (!parsed || typeof parsed !== "object") return null;
    const rec = parsed as Record<string, unknown>;
    if (typeof rec.type !== "string") return null;
    return parsed as AgentEvent;
  } catch {
    return null;
  }
}

export function runDelegatedCallsSequential(
  calls: DelegatedCall[],
  runner: (call: DelegatedCall) => DelegatedResult,
  onProgress?: (result: DelegatedResult) => void,
): DelegatedResult[] {
  const results: DelegatedResult[] = [];
  for (const call of calls) {
    const result = runner(call);
    results.push(result);
    onProgress?.(result);
  }
  return results;
}

function asRecord(v: unknown): Record<string, unknown> | null {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : null;
}

function asStringArray(v: unknown): string[] | undefined {
  if (!Array.isArray(v)) return undefined;
  return v.filter((x): x is string => typeof x === "string");
}

function asBool(v: unknown): boolean | undefined {
  return typeof v === "boolean" ? v : undefined;
}

export function resolveDelegatedExec(call: DelegatedCall): DelegatedExecReq | null {
  if (call.exec?.cmd) return call.exec;
  const argsRoot = asRecord(call.arguments);
  if (!argsRoot) return null;
  const nestedExec = asRecord(argsRoot.exec);
  const src = nestedExec ?? argsRoot;
  if (typeof src.cmd !== "string" || src.cmd.trim() === "") return null;
  return {
    cmd: src.cmd,
    args: asStringArray(src.args),
    cwd: typeof src.cwd === "string" ? src.cwd : undefined,
    streaming: asBool(src.streaming),
    needs_stderr_live: asBool(src.needs_stderr_live),
    needs_hard_cancel: asBool(src.needs_hard_cancel),
  };
}

function needsShellForCmd(cmd: string): boolean {
  const t = cmd.trim();
  if (!t) return false;
  return /\s/.test(t) || /[|&;<>()$`]/.test(t);
}

function shellQuote(arg: string): string {
  return `'${arg.replace(/'/g, `'\"'\"'`)}'`;
}

export function resolveDelegatedSpawn(exec: DelegatedExecReq): { cmd: string; args: string[] } {
  if (needsShellForCmd(exec.cmd)) {
    const suffix = (exec.args ?? []).map(shellQuote).join(" ");
    const script = suffix.length > 0 ? `${exec.cmd} ${suffix}` : exec.cmd;
    return { cmd: "bash", args: ["-lc", script] };
  }
  return { cmd: exec.cmd, args: exec.args ?? [] };
}

function supervisorWorkdirArg(workdir: string): string {
  const absWorkdir = path.resolve(workdir);
  const rel = path.relative(process.cwd(), absWorkdir);
  if (rel === "") return ".";
  if (!rel.startsWith("..") && !path.isAbsolute(rel)) return rel;
  return workdir;
}

export class RuntimeProcess {
  private proc: ChildProcess;
  private dead = false;
  private readonly workdir: string;
  private readonly onEvent: (e: AgentEvent) => void;
  private readonly ohMyPiToolsEnabled: boolean;

  constructor(
    task: string,
    envUrl: string,
    model: string,
    workdir: string,
    profile: string,
    port: number,
    systemPrompt: string,
    openaiBaseUrl: string,
    aiOptionsJson: string,
    onEvent: (e: AgentEvent) => void,
    onExit: () => void
  ) {
    this.workdir = workdir;
    this.onEvent = onEvent;
    this.ohMyPiToolsEnabled = (process.env.OHMY_PI_TOOLS ?? "0") === "1";
    const aiModelArg = model;
    const ailangBin = (process.env.AILANG_BIN && process.env.AILANG_BIN.trim() !== "")
      ? process.env.AILANG_BIN
      : "ailang";
    const childEnv: NodeJS.ProcessEnv = {
      PATH: process.env.PATH,
      HOME: process.env.HOME,
      ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
      OPENAI_API_KEY: process.env.OPENAI_API_KEY,
      OPENROUTER_API_KEY: process.env.OPENROUTER_API_KEY,
      GOOGLE_API_KEY: process.env.GOOGLE_API_KEY,
      EXA_API_KEY: process.env.EXA_API_KEY,
      AILANG_FS_SANDBOX: workdir,
      MOTOKO_STREAM_EVENTS: process.env.MOTOKO_STREAM_EVENTS ?? "1",
    };
    if (openaiBaseUrl.trim() !== "") childEnv.OPENAI_BASE_URL = openaiBaseUrl;
    if (aiOptionsJson.trim() !== "") childEnv.MOTOKO_AI_OPTIONS_JSON = aiOptionsJson;

    const supervisorArgs = [
      "--profile",
      profile,
      "--model",
      model,
      "--workdir",
      supervisorWorkdirArg(workdir),
      "--port",
      String(port),
    ];
    if (systemPrompt.trim() !== "") {
      supervisorArgs.push("--system-prompt", systemPrompt);
    }
    supervisorArgs.push(task);

    this.proc = spawn(
      ailangBin,
      [
        "run",
        "--caps",
        "Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream",
        "--ai",
        aiModelArg,
        "--entry",
        "main",
        "--net-allow-http",
        "--net-allow-localhost",
        "src/core/supervisor.ail",
        "--",
        ...supervisorArgs
      ],
      {
        env: childEnv,
        stdio: ["pipe", "pipe", "inherit"],
      }
    );

    const rl = readline.createInterface({
      input: this.proc.stdout!,
      crlfDelay: Infinity,
    });

    rl.on("line", (line) => {
      const event = parseAgentEventLine(line);
      if (!event) return;
      this.onEvent(event);
      if (event.type === "tool_calls") {
        setImmediate(() => {
          void this.handleToolCalls(event);
        });
      }
    });

    this.proc.on("exit", () => {
      this.dead = true;
      onExit();
    });
  }

  private resolveCwd(cwd?: string): string {
    if (!cwd || cwd.trim() === "") return this.workdir;
    return path.isAbsolute(cwd) ? cwd : path.resolve(this.workdir, cwd);
  }

  private truncate(s: string, max: number): { text: string; truncated: boolean } {
    if (s.length <= max) return { text: s, truncated: false };
    return { text: s.slice(0, max), truncated: true };
  }

  private runDelegatedCall(call: DelegatedCall): Promise<DelegatedResult> {
    const id = call.id ?? "";
    const exec = resolveDelegatedExec(call);
    if (!exec || !exec.cmd) {
      return Promise.resolve({
        tool_call_id: id,
        stdout: "",
        stderr: "missing exec.cmd",
        exit_code: 1,
        truncated: false,
      });
    }

    return new Promise((resolve) => {
      const spawnSpec = resolveDelegatedSpawn(exec);
      const child = spawn(spawnSpec.cmd, spawnSpec.args, {
        cwd: this.resolveCwd(exec.cwd),
        stdio: ["ignore", "pipe", "pipe"],
      });

      let stdoutRaw = "";
      let stderrRaw = "";
      let settled = false;
      let timedOut = false;
      const timeoutMs = 30_000;
      const maxBytes = 8 * 1024 * 1024;

      const finalize = (exitCode: number): void => {
        if (settled) return;
        settled = true;
        const stdout = this.truncate(stdoutRaw, 8000);
        const stderr = this.truncate(stderrRaw, 2000);
        resolve({
          tool_call_id: id,
          stdout: stdout.text,
          stderr: stderr.text,
          exit_code: exitCode,
          truncated: stdout.truncated || stderr.truncated,
        });
      };

      const timer = setTimeout(() => {
        timedOut = true;
        child.kill("SIGKILL");
      }, timeoutMs);

      child.stdout?.on("data", (chunk: Buffer | string) => {
        if (Buffer.byteLength(stdoutRaw, "utf8") >= maxBytes) return;
        const next = typeof chunk === "string" ? chunk : chunk.toString("utf8");
        stdoutRaw += next;
      });

      child.stderr?.on("data", (chunk: Buffer | string) => {
        if (Buffer.byteLength(stderrRaw, "utf8") >= maxBytes) return;
        const next = typeof chunk === "string" ? chunk : chunk.toString("utf8");
        stderrRaw += next;
      });

      child.on("error", (err) => {
        clearTimeout(timer);
        stderrRaw = stderrRaw ? `${stderrRaw}\n${String(err.message ?? err)}` : String(err.message ?? err);
        finalize(1);
      });

      child.on("close", (code) => {
        clearTimeout(timer);
        if (timedOut) {
          const msg = `timed out after ${timeoutMs}ms`;
          stderrRaw = stderrRaw ? `${stderrRaw}\n${msg}` : msg;
          finalize(1);
          return;
        }
        finalize(typeof code === "number" ? code : 1);
      });
    });
  }

  private async handleToolCalls(event: Extract<AgentEvent, { type: "tool_calls" }>): Promise<void> {
    const calls = event.tool_calls ?? [];
    this.onEvent({
      type: "tool_results",
      request_id: event.request_id,
      phase: "running",
      results: [],
    });
    const results: DelegatedResult[] = [];
    const session = createOhMyPiSession(this.workdir);
    for (const call of calls) {
      const useOhMyPi =
        this.ohMyPiToolsEnabled &&
        (call.tool === "ReadFile" || call.tool === "WriteFile" || call.tool === "EditFile" || call.tool === "Search");
      const result = useOhMyPi
        ? await dispatchOhMyPiTool(session, call)
        : await this.runDelegatedCall(call);
      results.push(result);
      this.onEvent({
        type: "tool_results",
        request_id: event.request_id,
        phase: "progress",
        results: [result],
      });
    }
    this.send({ type: "tool_results", request_id: event.request_id, results });
    this.onEvent({
      type: "tool_results",
      request_id: event.request_id,
      phase: "done",
      results,
    });
  }

  send(cmd: object): void {
    if (this.dead) return;
    this.proc.stdin?.write(JSON.stringify(cmd) + "\n");
  }

  abort(): void {
    this.send({ type: "abort" });
  }

  kill(): void {
    if (this.dead) return;
    this.proc.kill("SIGTERM");
  }

  setModel(model: string): void {
    this.send({ type: "model_change", model });
  }

  sendUserMessage(content: string): void {
    this.send({ type: "user_message", content });
  }
}
