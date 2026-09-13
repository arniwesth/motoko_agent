// tui/src/index.ts
//
// Entry point. Wires together:
//   1. Embedded environment server (express on ENV_PORT, default 8080)
//   2. AILANG runtime subprocess (src/core/rpc.ail)
//   3. pi-tui UI (AgentUI)
//
// Usage:
//   node dist/index.js "Fix the off-by-one in parse_config"
//   MODEL=openai/gpt-4o WORKDIR=/path/to/repo node dist/index.js
//
// If no task argument is provided, the user is prompted interactively.
//
// Environment variables:
//   TASK     — task text (overridden by argv[2] if present)
//   MODEL    — initial model string (default: anthropic/claude-sonnet-4-6)
//   ENV_PORT — port for the embedded environment server (default: 8080)
//   WORKDIR   — working directory mounted in the environment server (default: cwd)
//   SYSTEM_MD — path to a SYSTEM.md file whose content replaces the built-in system prompt
import * as fs from "fs";
import * as path from "path";
import { systemPromptForWorkspace, materializeSystemPromptArg } from "./system-prompt.js";
import { execSync } from "child_process";
import { renderBanner } from "./banner-runtime.js";
import { startEnvServer } from "./env-server.js";
import { RuntimeProcess, resolveDelegatedExec } from "./runtime-process.js";
import { AgentUI, parseScratchpadCellsJson } from "./ui.js";
import { HeadlessOutcome, formatResumeViewLine } from "./headless-outcome.js";
import {
  ANSWER_UNPUBLISHED_EXIT_CODE,
  type AnswerPublication,
  finishOneShot,
  formatUnpublished,
  publishAnswer,
  unpublishedOnExit,
} from "./answer-file.js";
import { SessionLogger } from "./session-logger.js";
import { initHerdrReporter, reportSessionPath } from "./herdr-agent-state.js";
import { initExitActions } from "./exit-actions.js";
import { sessionIdentity, bumpSessionResumeCount } from "./session-identity.js";
import { SessionJournal } from "./session-journal.js";
import { acquireLease, registerLeaseHooks } from "./session-lease.js";
import { activeProfile } from "./config.js";
import { resolveRuntimeModel } from "./models.js";
import type { AgentEvent, DelegatedCall, ResumeSpawn } from "./runtime-process.js";
import type { ScratchpadCellResult } from "./scratchpad/frames.js";

// Like describeToolCall but also checks call.arguments for native dispatch
// events where path/content etc. are nested in the arguments JSON blob.
function describeNativeCall(call: DelegatedCall): string {
  const args = call.arguments ?? {};
  const path = typeof args.path === "string" ? args.path : call.path;
  const tool = call.tool ?? "?";
  const id = call.id ?? "?";
  if (tool === "ReadFile") {
    const start = (typeof args.start === "number" ? args.start : call.start) ?? 1;
    const end = (typeof args.end === "number" ? args.end : call.end) ?? 200;
    return `${id} ${tool} ${path ?? ""} lines ${start}-${end}`.trim();
  }
  if (tool === "Search") {
    const pattern = typeof args.pattern === "string" ? args.pattern : (call.pattern ?? "");
    const dir = typeof args.dir === "string" ? args.dir : (call.dir ?? ".");
    return `${id} ${tool} pattern="${pattern}" dir=${dir}`.trim();
  }
  if (path) return `${id} ${tool} ${path}`.trim();
  return `${id} ${tool}`;
}

function describeToolCall(call: DelegatedCall): string {
  const id = call.id ?? "unknown";
  const tool = call.tool ?? "unknown";
  if (tool === "ReadFile") {
    const start = call.start ?? 1;
    const end = call.end ?? 200;
    return `${id} ${tool} ${call.path ?? ""} lines ${start}-${end}`.trim();
  }
  if (tool === "Search") {
    return `${id} ${tool} pattern="${call.pattern ?? ""}" dir=${call.dir ?? "."}`.trim();
  }
  if (tool === "WriteFile") {
    return `${id} ${tool} ${call.path ?? ""}`.trim();
  }
  if (tool === "EditFile") {
    const edits = Array.isArray(call.edits) ? call.edits.length : 0;
    const flags = [call.dry_run ? "dry_run" : "", call.expected_sha256 ? "sha_guard" : ""]
      .filter((x) => x.length > 0)
      .join(",");
    const suffix = flags ? ` (${flags})` : "";
    return `${id} ${tool} ${call.path ?? ""} edits=${edits}${suffix}`.trim();
  }
  const exec = resolveDelegatedExec(call);
  if (exec) {
    const args = exec.args?.length ? " " + exec.args.join(" ") : "";
    return `${id} ${tool} ${exec.cmd}${args}`.trim();
  }
  return `${id} ${tool}`;
}

function isInternalComposeStream(streamId: string): boolean {
  const id = (streamId ?? "").trim();
  return id.startsWith("compose-");
}

function firstNonEmptyLine(text: string): string {
  return text.split(/\r?\n/).map((line) => line.trim()).find((line) => line.length > 0) ?? "";
}

function plural(n: number, word: string): string {
  return `${n} ${word}${n === 1 ? "" : "s"}`;
}

function plainScratchpadMetadata(cell: ScratchpadCellResult): string {
  const parts: string[] = [];
  const ailang = cell.metadata?.ailang;
  if (ailang) {
    parts.push(`check=${ailang.check}`);
    parts.push(`verify=${ailang.verify}${!ailang.verifyAvailable && ailang.check === "passed" ? " (Z3 unavailable)" : ""}`);
    parts.push(`committed=${ailang.committed ? "yes" : "no"}`);
    if (ailang.ran) parts.push("ran=yes");
  }
  const lean = cell.metadata?.lean;
  if (lean) {
    parts.push(`elaborated=${lean.elaborated}`);
    parts.push(`proof=${lean.proof}`);
    parts.push(`committed=${lean.committed ? "yes" : "no"}`);
    if (lean.unexpectedAxioms && lean.unexpectedAxioms.length > 0) {
      parts.push(`unexpected_axioms=${lean.unexpectedAxioms.join(",")}`);
    }
    if (typeof lean.sorries === "number" && lean.sorries > 0) parts.push(`sorries=${lean.sorries}`);
  }
  return parts.length > 0 ? ` ${parts.join(" ")}` : "";
}

export function formatPlainScratchpadResult(event: Extract<AgentEvent, { type: "scratchpad_result" }>): string {
  const cells = parseScratchpadCellsJson(event.cells_json);
  if (!cells) return `[scratchpad] ${event.tool_call_id} invalid cells_json`;
  const passed = cells.filter((cell) => cell.exit_code === 0 && !cell.error).length;
  const lines = [`[scratchpad] ${event.tool_call_id} ${plural(cells.length, "cell")} passed=${passed} failed=${cells.length - passed}`];
  for (const cell of cells) {
    const idx = cell.index + 1;
    const status = cell.exit_code === 0 && !cell.error ? "ok" : "failed";
    const duration = typeof cell.durationMs === "number" ? ` ${Math.max(0, Math.round(cell.durationMs))}ms` : "";
    const displays = cell.displays.length > 0 ? ` displays=${cell.displays.map((d) => d.type).join(",")}` : "";
    const result = cell.result ? ` result=${cell.result.type}` : "";
    lines.push(`  [${status}] ${idx}. ${cell.language} ${cell.title} exit=${cell.exit_code}${duration}${displays}${result}${plainScratchpadMetadata(cell)}`);
    const out = firstNonEmptyLine(cell.stdout);
    if (out) lines.push(`    stdout: ${out.slice(0, 180)}`);
    const err = firstNonEmptyLine(cell.stderr);
    if (err) lines.push(`    stderr: ${err.slice(0, 180)}`);
    if (cell.error) lines.push(`    error: ${cell.error.ename}: ${cell.error.evalue}`);
  }
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// loadDotEnv — parse a .env file and populate process.env
//
// Rules:
//   - Blank lines and lines starting with # are skipped
//   - KEY=value and KEY="value" and KEY='value' are all accepted
//   - Already-set env vars are NOT overridden (shell wins over .env)
// ---------------------------------------------------------------------------
function loadDotEnv(
  protectedKeys: Set<string> = new Set(Object.keys(process.env)),
  overrideableKeys: Set<string> = new Set(),
): void {
  const allowedKeys = new Set([
    "ANTHROPIC_API_KEY",
    "OPENAI_API_KEY",
    "OPENROUTER_API_KEY",
    "GOOGLE_API_KEY",
    "EXA_API_KEY",
    "CLICKSTACK_INGESTION_KEY",
    "OTEL_EXPORTER_OTLP_HEADERS",
  ]);
  // Look for .env in CWD (where run-agent.sh is invoked from) and, as a
  // fallback, two levels up from this script (project root when running from
  // tui/dist/).
  const candidates = [
    path.join(process.cwd(), ".env"),
    path.join(process.cwd(), ".export"),
    path.resolve(import.meta.dirname, "../../.env"),
    path.resolve(import.meta.dirname, "../../.export"),
  ];

  for (const envPath of candidates) {
    if (!fs.existsSync(envPath)) continue;
    try {
      const lines = fs.readFileSync(envPath, "utf8").split("\n");
      for (const raw of lines) {
        const line = raw.trim();
        if (!line || line.startsWith("#")) continue;
        // Support both "KEY=value" and "export KEY=value"
        const stripped = line.startsWith("export ") ? line.slice(7).trim() : line;
        const eq = stripped.indexOf("=");
        if (eq < 1) continue;
        const key = stripped.slice(0, eq).trim();
        if (!allowedKeys.has(key)) continue;
        let val = stripped.slice(eq + 1).trim();
        // Strip surrounding quotes (single or double)
        if (
          (val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))
        ) {
          val = val.slice(1, -1);
        }
        // Never override a non-empty value the shell already provided. Docker
        // Compose may inject blank provider keys via ${KEY:-}; those should
        // still fall back to .env.
        const existing = process.env[key];
        if (protectedKeys.has(key) && existing !== "") continue;
        if (existing === undefined || existing === "" || overrideableKeys.has(key)) {
          process.env[key] = val;
          overrideableKeys.delete(key);
        }
      }
    } catch {
      // Unreadable .env — ignore silently
    }
  }
}

function synthesizeClickStackOtelHeaders(): void {
  const key = (process.env.CLICKSTACK_INGESTION_KEY ?? "").trim();
  const headers = (process.env.OTEL_EXPORTER_OTLP_HEADERS ?? "").trim();
  if (key === "" || headers !== "") return;
  process.env.OTEL_EXPORTER_OTLP_HEADERS = `authorization=${key}`;
}

type ProfileAgentConfig = {
  model?: string;
  openaiBaseUrl?: string;
  aiOptionsJson?: string;
  extensions?: string[];
  scratchpadWsLoopback?: boolean;
  clickstack?: {
    enabled?: boolean;
    endpoint?: string;
    protocol?: string;
    serviceName?: string;
    trace?: string;
    traceMaxSpans?: number;
    metricsExporter?: string;
    timeoutMs?: number;
    logsEnabled?: boolean;
    logsSource?: string;
    logsStartAt?: string;
    logsExcludeOlderThan?: string;
  };
};

function nonEmptyString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() !== "" ? value : undefined;
}

function envOrProfileString(envKey: string, profileValue: string | undefined): string {
  return nonEmptyString(process.env[envKey]) ?? profileValue ?? "";
}

function positiveNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? value
    : undefined;
}

function setFromProfile(
  protectedKeys: Set<string>,
  envKey: string,
  value: string | number | undefined,
): void {
  if (value === undefined || protectedKeys.has(envKey)) return;
  process.env[envKey] = String(value);
}

function applyClickStackProfileConfig(
  clickstack: ProfileAgentConfig["clickstack"],
  protectedKeys: Set<string>,
): void {
  if (!clickstack?.enabled) {
    disableOtelExport();
    return;
  }
  // ClickStack/HyperDX rejects OTLP ingestion without an authorization header,
  // so without a key the AILANG runtime would emit `traces export: failed to
  // send ... 401 (missing or empty authorization header)` on every span. The
  // header is derived from CLICKSTACK_INGESTION_KEY by
  // synthesizeClickStackOtelHeaders() (already run by this point). If no key is
  // available we know export is doomed, so we skip it entirely and print a
  // single actionable hint instead of letting the runtime spam 401s.
  if (!clickStackAuthHeaderPresent()) {
    disableOtelExport();
    warnClickStackTracingDisabled(clickstack.endpoint);
    return;
  }
  setFromProfile(protectedKeys, "MOTOKO_OTEL", "1");
  setFromProfile(protectedKeys, "OTEL_EXPORTER_OTLP_ENDPOINT", clickstack.endpoint);
  setFromProfile(protectedKeys, "OTEL_EXPORTER_OTLP_PROTOCOL", clickstack.protocol);
  setFromProfile(protectedKeys, "OTEL_SERVICE_NAME", clickstack.serviceName);
  setFromProfile(protectedKeys, "AILANG_TRACE", clickstack.trace);
  setFromProfile(protectedKeys, "AILANG_TRACE_MAX_SPANS", clickstack.traceMaxSpans);
  setFromProfile(protectedKeys, "OTEL_METRICS_EXPORTER", clickstack.metricsExporter);
  setFromProfile(protectedKeys, "OTEL_EXPORTER_OTLP_TIMEOUT", clickstack.timeoutMs);
}

// True when an OTLP authorization header is configured (directly, or
// synthesized from CLICKSTACK_INGESTION_KEY by synthesizeClickStackOtelHeaders).
function clickStackAuthHeaderPresent(): boolean {
  const headers =
    process.env.OTEL_EXPORTER_OTLP_HEADERS ??
    process.env.OTEL_EXPORTER_OTLP_TRACES_HEADERS ??
    "";
  return /authorization\s*=/i.test(headers);
}

// Prevent AILANG children (the version probe and the agent runtime) from
// attempting trace export unless the selected profile explicitly enables
// ClickStack. AILANG initializes its OTLP exporter when
// OTEL_EXPORTER_OTLP_ENDPOINT is set, and AILANG_TRACE=off does not stop it.
// The endpoint can be inherited from docker-compose or the shell, so deleting
// it here is the only reliable way to keep normal runs quiet.
function disableOtelExport(): void {
  delete process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
  delete process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT;
  delete process.env.MOTOKO_OTEL;
}

// Emit a single, actionable line explaining that tracing is off for this run
// because no ingestion key was found — replacing the runtime's raw 401 spam.
function warnClickStackTracingDisabled(endpoint: string | undefined): void {
  const target = nonEmptyString(endpoint) ?? "the OTLP endpoint";
  process.stderr.write(
    `Motoko: ClickStack tracing is enabled but no ingestion key is set — tracing is disabled for this run (${target} would reject it with 401).\n` +
      `  Fix: add CLICKSTACK_INGESTION_KEY=<key> to .env (find it in the ClickStack UI → Team Settings → API Keys),\n` +
      `       or set OTEL_EXPORTER_OTLP_HEADERS='authorization=<key>' directly, or set clickstack.enabled=false to silence this.\n`,
  );
}

function applyToolProfileConfig(
  profile: ProfileAgentConfig,
  protectedKeys: Set<string>,
): void {
  setFromProfile(
    protectedKeys,
    "MOTOKO_SCRATCHPAD_WS_LOOPBACK",
    profile.scratchpadWsLoopback === undefined ? undefined : profile.scratchpadWsLoopback ? "1" : "0",
  );
}

function resolveProfileAgentConfig(workdir: string, profile: string): ProfileAgentConfig {
  const profileDir = path.isAbsolute(profile)
    ? profile
    : path.join(workdir, ".motoko", "config", profile);
  const configPath = path.join(profileDir, "config.json");
  if (!fs.existsSync(configPath)) return {};
  try {
    const parsed = JSON.parse(fs.readFileSync(configPath, "utf8")) as {
      agent?: {
        model?: unknown;
        openai_base_url?: unknown;
        ai_options_json?: unknown;
      };
      extensions?: {
        order?: unknown;
      };
      tools?: {
        scratchpad_ws_loopback?: unknown;
      };
      clickstack?: {
        enabled?: unknown;
        endpoint?: unknown;
        protocol?: unknown;
        service_name?: unknown;
        trace?: unknown;
        trace_max_spans?: unknown;
        metrics_exporter?: unknown;
        timeout_ms?: unknown;
        logs_enabled?: unknown;
        logs_source?: unknown;
        logs_start_at?: unknown;
        logs_exclude_older_than?: unknown;
      };
    };
    const extensions = Array.isArray(parsed.extensions?.order)
      ? parsed.extensions.order.filter((x): x is string => typeof x === "string" && x.trim() !== "")
      : undefined;
    return {
      model: typeof parsed.agent?.model === "string" && parsed.agent.model.trim() !== ""
        ? parsed.agent.model
        : undefined,
      openaiBaseUrl: typeof parsed.agent?.openai_base_url === "string" && parsed.agent.openai_base_url.trim() !== ""
        ? parsed.agent.openai_base_url
        : undefined,
      aiOptionsJson: typeof parsed.agent?.ai_options_json === "string" && parsed.agent.ai_options_json.trim() !== ""
        ? parsed.agent.ai_options_json
        : undefined,
      extensions,
      scratchpadWsLoopback: typeof parsed.tools?.scratchpad_ws_loopback === "boolean"
        ? parsed.tools.scratchpad_ws_loopback
        : undefined,
      clickstack: {
        enabled: typeof parsed.clickstack?.enabled === "boolean"
          ? parsed.clickstack.enabled
          : undefined,
        endpoint: nonEmptyString(parsed.clickstack?.endpoint),
        protocol: nonEmptyString(parsed.clickstack?.protocol),
        serviceName: nonEmptyString(parsed.clickstack?.service_name),
        trace: nonEmptyString(parsed.clickstack?.trace),
        traceMaxSpans: positiveNumber(parsed.clickstack?.trace_max_spans),
        metricsExporter: nonEmptyString(parsed.clickstack?.metrics_exporter),
        timeoutMs: positiveNumber(parsed.clickstack?.timeout_ms),
        logsEnabled: typeof parsed.clickstack?.logs_enabled === "boolean"
          ? parsed.clickstack.logs_enabled
          : undefined,
        logsSource: nonEmptyString(parsed.clickstack?.logs_source),
        logsStartAt: nonEmptyString(parsed.clickstack?.logs_start_at),
        logsExcludeOlderThan: nonEmptyString(parsed.clickstack?.logs_exclude_older_than),
      },
    };
  } catch {
    return {};
  }
}


// ---------------------------------------------------------------------------
// PlainLogger — used when stdout is not a TTY (CI, pipes, devcontainers).
// Writes human-readable lines; no ANSI, no stdin manipulation.
// ---------------------------------------------------------------------------

class PlainLogger {
  onModelChange?: (model: string) => void;
  onAbort?: () => void;
  onUserMessage?: (content: string) => void;
  private readonly streamSteps = new Set<number>();
  private readonly verboseStream: boolean;
  private readonly outcome = new HeadlessOutcome();

  constructor() {
    const v = (process.env.MOTOKO_PLAIN_VERBOSE_STREAM ?? "").trim().toLowerCase();
    this.verboseStream = v === "1" || v === "true" || v === "yes";
  }
  handleEvent(event: AgentEvent): void {
    switch (event.type) {
      case "session_start":
        process.stdout.write(`[session] task=${event.task} model=${event.model}\n`);
        if (Array.isArray(event.loaded_extensions)) {
          const extText = event.loaded_extensions.length > 0 ? event.loaded_extensions.join(", ") : "(none)";
          process.stdout.write(`[session] loaded_extensions=${extText}\n`);
        }
        break;
      case "thinking":
        if (this.streamSteps.has(event.step)) {
          process.stdout.write(`[step ${event.step}] thinking (streamed)\n`);
        } else {
          process.stdout.write(`[step ${event.step}] thinking\n${event.text}\n`);
        }
        break;
      case "thinking_stream_start":
        if (isInternalComposeStream(event.stream_id)) break;
        process.stdout.write(`[step ${event.step}] stream_start ${event.stream_id} model=${event.model}\n`);
        break;
      case "thinking_delta":
        if (isInternalComposeStream(event.stream_id)) break;
        if (this.verboseStream) process.stdout.write(event.text_delta);
        break;
      case "thinking_stream_error":
        if (isInternalComposeStream(event.stream_id)) break;
        process.stderr.write(`[step ${event.step}] stream_error ${event.message}\n`);
        break;
      case "thinking_stream_end":
        if (isInternalComposeStream(event.stream_id)) break;
        this.streamSteps.add(event.step);
        process.stdout.write(`${this.verboseStream ? "\n" : ""}[step ${event.step}] stream_end ${event.stream_id} status=${event.status}\n`);
        break;
      case "proposed_cmd":
        process.stdout.write(`[step ${event.step}] $ ${event.cmd}\n`);
        break;
      case "proposed_ailang":
        process.stdout.write(`[step ${event.step}] AILANG snippet (${event.code.split("\n").length} lines)\n`);
        break;
      case "ailang_check":
        if (event.passed) {
          process.stdout.write(`[step ${event.step}] AILANG type-check passed\n`);
        } else {
          process.stdout.write(`[step ${event.step}] AILANG type-check failed (${event.attempt}/${event.max_attempts}): ${event.errors.split("\n")[0]}\n`);
        }
        break;
      case "compose_start":
        process.stdout.write(`[step ${event.step}] [compose ${event.compose_id}] start model=${event.model} max_attempts=${event.max_attempts}\n`);
        break;
      case "compose_author_delta":
        process.stdout.write(`[step ${event.step}] [compose ${event.compose_id}] author attempt=${event.attempt}\n`);
        break;
      case "compose_author_error":
        process.stdout.write(
          `[step ${event.step}] [compose ${event.compose_id}] author_error attempt=${event.attempt} mode=${event.mode ?? "unknown"}: ${event.error}\n`,
        );
        break;
      case "compose_snippet":
        process.stdout.write(`[step ${event.step}] [compose ${event.compose_id}] snippet attempt=${event.attempt} (${event.code.split("\n").length} lines)\n`);
        break;
      case "compose_check":
        process.stdout.write(
          `[step ${event.step}] [compose ${event.compose_id}] check attempt=${event.attempt} ${event.passed ? "passed" : `failed: ${(event.errors ?? "").split("\n")[0]}`}\n`,
        );
        break;
      case "compose_retry":
        process.stdout.write(`[step ${event.step}] [compose ${event.compose_id}] retry attempt=${event.attempt}: ${event.reason}\n`);
        break;
      case "compose_exec":
        process.stdout.write(`[step ${event.step}] [compose ${event.compose_id}] exec exit=${event.exit_code}\n`);
        break;
      case "compose_summary_delta":
        process.stdout.write(`[step ${event.step}] [compose ${event.compose_id}] summary delta\n`);
        break;
      case "compose_result":
        process.stdout.write(`[step ${event.step}] [compose ${event.compose_id}] result attempts=${event.attempts} exit=${event.exit_code}\n`);
        break;
      case "scratchpad_result":
        process.stdout.write(formatPlainScratchpadResult(event) + "\n");
        break;
      case "obs":
        if (event.stdout) process.stdout.write(event.stdout + "\n");
        if (event.stderr) process.stderr.write(`[stderr] ${event.stderr}\n`);
        break;
      case "done":
        process.stdout.write(`[done] ${event.step} step(s)\n${event.output}\n`);
        process.exit(this.outcome.doneExitCode);
        break;
      case "error":
        process.stderr.write(`[error] ${event.message}\n`);
        process.exit(1);
        break;
      // PLAN-003 P3 Part 6. The reason goes to stderr and the non-zero exit is RECORDED, not taken:
      // headless still sends `run_summary` and the eval harness's `error` after a suspension, and
      // the `error` arm above exits on them. `stop()` exits if the runtime ends without one.
      case "run_suspended":
      case "session_resume_refused":
        process.stderr.write(this.outcome.observe(event) ?? "");
        break;
      case "session_resume_view":
        process.stdout.write(formatResumeViewLine(event));
        break;
      case "tool_calls":
        process.stdout.write(`[tools] ${event.request_id} queued (${event.tool_calls.length} call(s))\n`);
        for (const call of event.tool_calls) {
          process.stdout.write(`  [queued] ${describeToolCall(call)}\n`);
        }
        break;
      case "tool_results":
        if (event.phase === "running") {
          process.stdout.write(`[tools] ${event.request_id} running\n`);
        } else if (event.phase === "progress") {
          for (const r of event.results) {
            const status = r.exit_code === 0 ? "done" : "failed";
            process.stdout.write(`  [${status}] ${r.tool_call_id} exit=${r.exit_code}${r.truncated ? " truncated" : ""}\n`);
          }
        } else {
          process.stdout.write(`[tools] ${event.request_id} done\n`);
          for (const r of event.results) {
            const status = r.exit_code === 0 ? "done" : "failed";
            process.stdout.write(`  [${status}] ${r.tool_call_id} exit=${r.exit_code}${r.truncated ? " truncated" : ""}\n`);
          }
        }
        break;
      case "native_tool_calls":
        process.stdout.write(`[native] ${event.request_id} dispatching ${event.tool_calls.length} tool call(s)\n`);
        for (const call of event.tool_calls) {
          process.stdout.write(`  [dispatch] ${describeNativeCall(call)}\n`);
        }
        break;
      case "native_tool_results":
        for (const r of event.results) {
          const status = (r.exit_code ?? 0) === 0 ? "done" : "failed";
          process.stdout.write(`  [result] ${r.tool_call_id} exit=${r.exit_code ?? 0}${r.truncated ? " truncated" : ""}\n`);
        }
        break;
      case "v2_tool_dispatch_start":
        process.stdout.write(`[step ${event.step}] dispatch ${event.tool} id=${event.id}\n`);
        break;
      case "v2_tool_dispatch_complete":
        process.stdout.write(`[step ${event.step}] dispatch_done id=${event.id}\n`);
        break;
    }
  }

  // ADR-002 D1.2: an `--answer-file` one-shot that published nothing says why and exits non-zero.
  refuseAnswer(publication: Extract<AnswerPublication, { ok: false }>): void {
    process.stderr.write(formatUnpublished(publication));
    this.outcome.refuseAnswer();
  }

  // Called once the runtime has exited and the session log is drained. A run that suspended or
  // was refused a resume, and was not already ended by an `error`, exits non-zero here.
  stop(): void {
    if (this.outcome.exitCode !== 0) process.exit(this.outcome.exitCode);
  }
}

class JsonlLogger {
  onModelChange?: (model: string) => void;
  onAbort?: () => void;
  onUserMessage?: (content: string) => void;
  private readonly outcome = new HeadlessOutcome();

  handleEvent(event: AgentEvent): void {
    process.stdout.write(JSON.stringify(event) + "\n");
    // PLAN-003 P3 Part 6: stdout stays the unmodified wire; a suspension's or a refused resume's
    // reason goes to stderr, and its non-zero exit is taken on the `error` or in `stop()`.
    const reason = this.outcome.observe(event);
    if (reason !== null) process.stderr.write(reason);
    if (event.type === "done") process.exit(this.outcome.doneExitCode);
    if (event.type === "error") process.exit(1);
  }

  refuseAnswer(publication: Extract<AnswerPublication, { ok: false }>): void {
    process.stderr.write(formatUnpublished(publication));
    this.outcome.refuseAnswer();
  }

  stop(): void {
    if (this.outcome.exitCode !== 0) process.exit(this.outcome.exitCode);
  }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

// M-MOTOKO-EVAL-HARNESS-HARDENING M2b + M2c (gaps #7, #8): parse motoko-
// specific CLI flags before treating argv[2] as task text.
//   --headless       — force MOTOKO_HEADLESS=1 (more discoverable than env var)
//   --oneshot        — interactive one-shot: TTY display, exit after the first task's `done`
//   --answer-file P  — publish the final answer to P (ADR-002 D1.2); see answer-file.ts
//   --version, -v    — print structured version info to stdout and exit 0
// Recognized flags are removed from process.argv so downstream argv[2] reads
// still work for the task text. Unknown flags pass through to the task text
// (so "motoko --whatever ..." doesn't break).
function parseMotokoFlags(): {
  headless: boolean;
  oneshot: boolean;
  answerFile: string | null;
  printVersion: boolean;
  systemPrompt: string | null;
} {
  const flags: {
    headless: boolean;
    oneshot: boolean;
    answerFile: string | null;
    printVersion: boolean;
    systemPrompt: string | null;
  } = { headless: false, oneshot: false, answerFile: null, printVersion: false, systemPrompt: null };
  const remaining: string[] = [process.argv[0], process.argv[1]];
  for (let i = 2; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg === "--headless") {
      flags.headless = true;
    } else if (arg === "--oneshot") {
      // ADR-002 D1.3. `--headless` is the plain/JSONL one-shot and already exits on `done`; this is
      // the same one task with the TUI kept, which is what a delegate in a herdr pane wants.
      flags.oneshot = true;
    } else if (arg === "--answer-file") {
      flags.answerFile = process.argv[i + 1] ?? "";
      i++; // consume the value
    } else if (arg === "--version" || arg === "-v") {
      flags.printVersion = true;
    } else if (arg === "--system-prompt") {
      // --system-prompt <path>: let an external harness (e.g. the AILANG eval
      // adapter) inject a system-role prompt WITHOUT having to place a file
      // inside the workspace or set SYSTEM_MD. The value is a path (absolute or
      // relative to cwd); its CONTENT is materialized into a managed in-workspace
      // file in main() so the workdir-relative SYSTEM_MD contract is preserved.
      // Takes precedence over the SYSTEM_MD env var.
      flags.systemPrompt = process.argv[i + 1] ?? "";
      i++; // consume the value
    } else {
      remaining.push(arg);
    }
  }
  process.argv = remaining;
  return flags;
}

// printVersionInfo writes structured version info to stdout then exits 0.
// Format: line-oriented `key=value` pairs for easy parsing by the AILANG
// adapter's HealthCheck (M-MOTOKO-EXECUTOR-ADAPTER) and other tooling.
function printVersionInfo(pkgVersion: string, projectRoot: string): void {
  let gitRev = "unknown";
  try {
    gitRev = execSync("git rev-parse --short HEAD", {
      cwd: projectRoot,
      timeout: 2000,
    }).toString().trim();
  } catch {}
  let ailangBuilt = "unknown";
  try {
    const ailangBin = (process.env.AILANG_BIN && process.env.AILANG_BIN.trim() !== "")
      ? process.env.AILANG_BIN
      : "ailang";
    const raw = execSync(`${ailangBin} --version`, { timeout: 5000 }).toString().trim();
    const m = raw.match(/^Built:\s+(.*)$/m);
    if (m) ailangBuilt = m[1].trim();
  } catch {}
  process.stdout.write(`motoko ${pkgVersion}\n`);
  process.stdout.write(`tui_version=${pkgVersion}\n`);
  process.stdout.write(`git_rev=${gitRev}\n`);
  process.stdout.write(`ailang_built=${ailangBuilt}\n`);
  process.stdout.write(`motoko_repo=${projectRoot}\n`);
  process.exit(0);
}

async function main(): Promise<void> {
  const motokoFlags = parseMotokoFlags();
  if (motokoFlags.headless) {
    process.env.MOTOKO_HEADLESS = "1";
  }
  if (motokoFlags.printVersion) {
    const pkgPath = path.join(
      path.resolve(import.meta.dirname, ".."),
      "package.json",
    );
    const { version: pv } = JSON.parse(
      fs.readFileSync(pkgPath, "utf8"),
    ) as { version: string };
    const projectRoot = path.resolve(import.meta.dirname, "../../..");
    printVersionInfo(pv, projectRoot);
    return;
  }

  // Set the terminal/tab title to "motoko" so VS Code, iTerm2, etc. show
  // the agent name instead of the underlying runtime ("bun.exe" /
  // "node"). OSC 0 sets both icon and window title; ST is BEL (\x07) for
  // maximal compatibility (some terminals don't recognise ST = \x1b\\).
  // Skip in non-interactive output modes so we don't pollute log streams with
  // escape bytes.
  const headlessOutput = process.env.MOTOKO_HEADLESS === "1";
  if (process.stdout.isTTY && process.env.MOTOKO_JSONL_OUTPUT !== "1" && !headlessOutput) {
    process.stdout.write("\x1b]0;[λ] motoko\x07");
  }

  const shellEnvKeys = new Set(Object.keys(process.env));
  loadDotEnv(shellEnvKeys);
  synthesizeClickStackOtelHeaders();

  const jsonlOutput = process.env.MOTOKO_JSONL_OUTPUT === "1";
  // Read version FIRST so it appears before any other output.
  const pkgPath = path.join(
    path.resolve(import.meta.dirname, ".."),
    "package.json",
  );
  const { version: pkgVersion } = JSON.parse(
    fs.readFileSync(pkgPath, "utf8"),
  ) as { version: string };
  const projectRoot = path.resolve(import.meta.dirname, "../../..");
  const workdir = process.env.WORKDIR ?? process.cwd();
  // --system-prompt <path> (flag) takes precedence over the SYSTEM_MD env var.
  // Materialize the flag's file content into an in-workspace file and point
  // SYSTEM_MD at it so the existing systemPromptForWorkspace resolution delivers
  // it in the system role (the supervisor reads it via a workdir-relative path).
  if (motokoFlags.systemPrompt !== null) {
    const materialized = materializeSystemPromptArg(motokoFlags.systemPrompt, workdir);
    if (materialized !== null) {
      process.env.SYSTEM_MD = materialized;
    }
  }
  // ADR-002 D1.2. Resolved against the workdir, the same base a task's own relative paths use.
  if (motokoFlags.answerFile !== null && motokoFlags.answerFile.trim() === "") {
    process.stderr.write("--answer-file needs a path.\n");
    process.exit(2);
  }
  const answerFile = motokoFlags.answerFile !== null ? path.resolve(workdir, motokoFlags.answerFile) : null;
  // Set when the operator aborts or interrupts: an aborted run publishes nothing, and no runtime
  // event says it was aborted.
  let abortRequested = false;
  // M-MOTOKO-EVAL-HARNESS-HARDENING follow-up (2026-05-08): default
  // ENV_PORT to 0 = let the kernel pick a free port atomically when
  // startEnvServer binds. The wrapper used to do its own pick_free_port
  // probe via lsof, which raced when --agent-parallel >= 2 spawned
  // concurrent motoko sessions (both probes saw the same port free,
  // both tried to bind, second crashed). Setting 0 here means the bind
  // itself is the race-resolver — kernel returns EADDRINUSE only if
  // it actually IS in use right now, and with port=0 it picks one that
  // ISN'T. The actual port comes back from startEnvServer() below.
  // Operator override: explicit ENV_PORT=18080 still works for legacy
  // setups that need a fixed port (e.g. Docker port-forwarding).
  const envPort = Number(process.env.ENV_PORT ?? 0);
  let profile = activeProfile();
  const profileAgent = resolveProfileAgentConfig(workdir, profile);
  applyToolProfileConfig(profileAgent, shellEnvKeys);
  applyClickStackProfileConfig(profileAgent.clickstack, shellEnvKeys);
  const model = resolveRuntimeModel(process.env, profileAgent.model);
  // Publish the resolved runtime model once so helper paths (env-server,
  // scratchpad, subagents) observe the same default as the AILANG runtime.
  process.env.MODEL = model;
  const systemPrompt = systemPromptForWorkspace(projectRoot, workdir);
  const openaiBaseUrl = envOrProfileString("OPENAI_BASE_URL", profileAgent.openaiBaseUrl);
  const aiOptionsJson = envOrProfileString("MOTOKO_AI_OPTIONS_JSON", profileAgent.aiOptionsJson);

  let brainVersion = "unknown";
  try {
    brainVersion = execSync(
      "ailang run --entry print_version --caps IO src/core/version.ail | tail -1",
      // env: process.env is REQUIRED — bun's execSync does not propagate
      // runtime-mutated process.env to children, only the snapshot captured at
      // process start. synthesizeClickStackOtelHeaders() sets
      // OTEL_EXPORTER_OTLP_HEADERS at runtime, so without this the probe runs
      // the AILANG trace exporter with no auth header and ClickStack rejects it
      // with `401 ... missing or empty authorization header` on every launch.
      { cwd: projectRoot, timeout: 15000, env: process.env },
    ).toString().trim();
  } catch {
    // Runtime not available (ailang not on PATH, etc.) — banner shows "unknown".
  }

  // Get ailang build datetime from the binary itself.
  let ailangVersion = "unknown";
  try {
    const ailangBin = (process.env.AILANG_BIN && process.env.AILANG_BIN.trim() !== "")
      ? process.env.AILANG_BIN
      : "ailang";
    const raw = execSync(`${ailangBin} --version`, { timeout: 5000 }).toString().trim();
    // Look for "Built:  YYYY-MM-DD_HH:MM:SS"
    const m = raw.match(/^Built:\s+(.*)$/m);
    if (m) ailangVersion = m[1].trim();
  } catch {}

  // Future improvement: regenerate/reflow banner on terminal resize events.
  if (!jsonlOutput && !headlessOutput) {
    const bannerLines = renderBanner({ columns: process.stdout.columns });
    process.stdout.write(
      bannerLines.join("\n") +
      "\nMotoko (AILANG built " +
      ailangVersion +
      ") TUI v" +
      pkgVersion +
      " | Core Runtime v" +
      brainVersion +
      "\n\n"
    );
  }

  // Start environment server first; runtime process will call /exec against it.
  // CRITICAL: use the RETURNED port (not the requested envPort) — when
  // envPort=0, the kernel picks a port and we won't know it until bind
  // completes. boundPort == envPort when envPort > 0 (operator override).
  const boundPort = await startEnvServer(envPort, workdir);
  const envUrl = `http://localhost:${boundPort}`;

  // Determine whether we have a real terminal available for the TUI.
  // process.stdout.isTTY can be undefined in piped subprocess contexts
  // (e.g. oh-my-pi's session runner) even when the outer environment
  // has a real terminal. Use a multi-signal heuristic.
  //
  // CI is NOT treated as a TUI blocker — devcontainers and CI runners
  // often set CI=1 even when the user is running interactively.
  const isTTY =
    !headlessOutput &&
    !jsonlOutput &&
    (
      Boolean(process.stdout.isTTY) ||
      Boolean(process.stdout.columns) ||
      Boolean(process.env.FORCE_TTY)
    );

  // runtime process handle is declared mutable because abort()/setModel() fire from
  // callbacks, and spawnRuntimeProcess() may be called again on model switch.
  let runtimeProcess: RuntimeProcess | undefined;
  let sessionLogger: SessionLogger | undefined;
  // Set to true when the user presses ESC to interrupt a running task.
  // Prevents the normal process.exit(0) on runtime process exit so the user can
  // submit a new task instead.
  let interrupted = false;
  // Set to true when the runtime emits an error event. If the process then
  // exits (unexpected crash after an error), we recover by showing the task
  // prompt instead of exiting the TUI.
  let errorOccurred = false;
  // True while a runtime spawned only to warm the AILANG module graph is up and
  // no prompt has been submitted against it yet. Its exit must not be treated as
  // "the session ended".
  let preWarmIdle = false;

  // Announce Motoko to herdr, if this process was launched in a herdr pane. Everything about this
  // is a no-op outside one — see herdr-agent-state.ts — so it is unconditional here rather than
  // hidden behind a flag that would then need testing in both positions. It also registers the
  // exit hooks that give the lifecycle authority back, which is why it runs before anything can
  // call process.exit.
  // Perform whatever extensions asked to have done at session end (ABI 7.0's ExitIntent), read
  // from the manifest their runtimes published. Registered BEFORE the herdr reporter because Node
  // runs 'exit' listeners in registration order and handing lifecycle authority back should be the
  // last thing that happens — after whatever the session still owned has been dealt with. A no-op
  // when no runtime ever started or no extension declared an intent; see exit-actions.ts.
  initExitActions();

  // ADR-003 v6.1 D3: the session's JOURNAL and its LEASE, both host-lifetime, both created here —
  // after the exit-actions dispatcher and BEFORE the herdr reporter, which is the registration
  // order the release depends on. Node runs listeners in registration order, and the herdr
  // reporter's signal handler re-raises: anything registered after it never runs on a SIGINT.
  //
  // The lease is what makes D3's "one writer" checkable. A second Motoko on one session id would
  // append to the same `journal.jsonl` with its own `seq` and leaf, and the result is not a corrupt
  // file but a plausible one that folds to a history neither process ever had.
  //
  // A REFUSED LEASE ENDS THE SESSION, and nothing else can: the alternative is starting a Motoko
  // that silently writes into another one's journal. A STALE lease — the shape `kill -9` leaves —
  // is taken over, because resuming a crashed session is the second judging number.
  const sessionId = sessionIdentity();
  const journal = new SessionJournal(projectRoot, sessionId);
  const leaseOutcome = acquireLease(journal.dir, sessionId);
  if (leaseOutcome.kind === "refused") {
    process.stderr.write(
      `Session ${sessionId} is already held by pid ${leaseOutcome.heldBy.owner_pid} ` +
        `(lease ${path.join(journal.dir, "lease")}).\n` +
        `Motoko keeps one writer per session journal: two would interleave entries into one ` +
        `chain and fold to a history neither process had. Wait for that process to exit — a ` +
        `lease whose owner is gone is taken over automatically, including after a kill -9.\n`,
    );
    process.exit(3);
  }
  const lease = leaseOutcome.kind === "acquired" ? leaseOutcome.lease : null;

  // D1's `header`, written BEFORE the first spawn from the values the host has. The two digests and
  // the `boot` inputs are the child's and arrive on its first `v2_mode`; see `completeHeaderFrom`.
  journal.writeHeader({ sessionId, workdir, profile, model });

  // The lease's OWN listeners, which do not re-raise — see `session-lease.ts`. The journal's `exit`
  // entry rides with them, so it is written while the session is still this process's, and it is a
  // synchronous append because an async write started in an `exit` listener never runs.
  if (lease) registerLeaseHooks(process, lease, (reason) => journal.writeExit(reason));

  /**
   * Complete D1's header from the child's report — the design's ONE in-place rewrite.
   *
   * KEYED ON THE FIELDS, NOT ON THE EVENT NAME, and that is this part's one deliberate drift from
   * PLAN-003, which says the header is completed "on the first `session_start`". It cannot be.
   * `session_start` is emitted at `rpc.ail:282`, before the task is read and therefore before the
   * system prompt exists, so it cannot carry a system-prefix digest; and the header's `boot` — the
   * budget, the step budget, `ohmy_pi`, the cost rates — are profile-config values the HOST never
   * parses (`resolveProfileAgentConfig` reads the model, the extensions and the ClickStack block,
   * and nothing else). The plan names only the two digests as the child's; the boot inputs are in
   * the same position and the plan does not say so.
   *
   * So the child reports all of them together on `v2_mode` (`rpc.ail:379`), which is emitted once
   * per spawn at the exact point where every one of them is known, and this reads them off
   * whatever line carries a `header` object. When a later part moves them onto `session_start`
   * proper, nothing here changes.
   */
  const completeHeaderFrom = (event: AgentEvent): void => {
    if (journal.isHeaderCompleted) return;
    const rec = event as unknown as Record<string, unknown>;
    const h = rec.header;
    if (!h || typeof h !== "object" || Array.isArray(h)) return;
    const fields = h as Record<string, unknown>;
    const boot = fields.boot;
    if (!boot || typeof boot !== "object" || Array.isArray(boot)) return;
    journal.completeHeader({
      system_prefix_digest: typeof fields.system_prefix_digest === "string" ? fields.system_prefix_digest : "",
      ext_set_digest: typeof fields.ext_set_digest === "string" ? fields.ext_set_digest : "",
      boot: boot as Record<string, unknown>,
    });
  };

  initHerdrReporter();

  if (!isTTY) {
    // Non-TTY: prompt for task first, then run with PlainLogger.
    const task =
      process.argv[2] ??
      process.env.TASK ??
      (await promptForTask());
    // Non-TTY means one task, run to completion, then exit — the runtime never
    // reads a task from stdin in headless mode. An empty one has nothing to
    // run, so fail here instead of spawning a runtime that exits having done
    // nothing. Reachable with an empty argv[2] or TASK (`??` only falls through
    // on null/undefined) and when promptForTask() reads a closed stdin.
    if (task.trim() === "") {
      process.stderr.write(
        "No task given. Pass it as the first argument or set TASK=... (stdin is not a TTY, so there is nothing to prompt).\n",
      );
      process.exit(2);
    }
    const ui = jsonlOutput ? new JsonlLogger() : new PlainLogger();
    const logger = new SessionLogger(projectRoot, pkgVersion, journal);
    sessionLogger = logger;
    reportSessionPath(logger.filePath);
    logger.logUserInput(task);
    ui.onModelChange = (newModel) => {
      process.env.MODEL = newModel;
      // D1 names `model_change` a journal-class event and D3 lists it among the events `log()`
      // routes — but it is a HOST-TO-CHILD COMMAND (`runtime-process.ts`'s `setModel`), not
      // something the child ever says, so it never reaches a logger. The host is the only side
      // that knows, so the host writes the `settings` entry, through the same router: it is the
      // entry the fold reads `model` from (D4 rule 5), and a resume that missed it would rebuild
      // the session on the model the header was written with.
      journal.record({ type: "model_change", model: newModel });
      runtimeProcess!.setModel(newModel);
    };
    ui.onAbort = () => {
      abortRequested = true;
      runtimeProcess!.abort();
    };
    ui.onUserMessage = (content) => {
      logger.logUserInput(content);
      runtimeProcess!.sendUserMessage(content);
    };
    // Whether a `done`/`error` reached this callback, so an exit without one is known unpublished.
    let terminalSeen = false;
    runtimeProcess = new RuntimeProcess(
      task,
      envUrl,
      model,
      workdir,
      profile,
      boundPort,
      systemPrompt,
      openaiBaseUrl,
      aiOptionsJson,
      (event) => {
        completeHeaderFrom(event);
        logger.log(event);
        // For terminal events, drain the JSONL stream BEFORE letting the UI
        // handler call process.exit. Otherwise process.exit drops the
        // WriteStream's pending buffer — losing run_summary, done, and any
        // events emitted in the same flush window. See M-MOTOKO-EVAL-HARNESS-
        // HARDENING gap #1 / gap #10 for the bisection.
        if (event.type === "done" || event.type === "error") {
          terminalSeen = true;
          void logger.close().then(() => {
            // ADR-002 D1.2: publish after the drain and BEFORE the logger's exit, so the answer is
            // on disk before exit actions and the herdr reporter's release run.
            if (answerFile !== null) {
              const publication = publishAnswer(answerFile, event, abortRequested);
              if (!publication.ok) ui.refuseAnswer(publication);
            }
            ui.handleEvent(event);
          });
          return;
        }
        // ADR-003 v6.1 D2 / PLAN-003 P3 Part 6. `run_suspended` is NOT terminal and is handed
        // over synchronously, like any record that has more after it. P1 Part 6 drained it here
        // (flush, then hand over) against a `process.exit` that no logger takes on it: since P3
        // Part 6 the loggers only RECORD the suspension's non-zero exit, and the headless wire
        // goes on `run_summary`, `error` — the `error` is kept for the eval harness (PLAN-003 §5)
        // and is the record that closes and exits above. Deferring this one behind a flush would
        // let the synchronous `run_summary` reach the JSON logger's stdout BEFORE it, breaking the
        // `run_suspended`, `run_summary`, `error` order the harness and the probe read.
        ui.handleEvent(event);
      },
      () => {
        // D1's `exit` entry: the child is gone and the journal's last entry is whatever it had
        // flushed, so the boundary is recorded here — `child_exit` is what D1 calls this reason,
        // and `pending_tool_calls` is the trailing-pair rule over the entries the host holds.
        journal.writeExit("child_exit");
        const closing = logger.close();
        sessionLogger = undefined;
        // No terminal event reached the writer — killed, crashed, aborted: nothing was published.
        if (answerFile !== null && !terminalSeen) ui.refuseAnswer(unpublishedOnExit(answerFile, abortRequested));
        // After the drain: a logger whose run suspended without an `error` exits non-zero in
        // `stop()` (PLAN-003 P3 Part 6), and an exit before the drain loses the log's tail.
        void closing.then(() => ui.stop());
      },
    );
    return;
  }

  // TTY mode: start the TUI immediately so the footer is visible before the
  // runtime process starts (and even before the user types a task).
  // Make ailang build datetime available to the runtime via environment variable.
  process.env.AILANG_BUILT = ailangVersion;

  const ui = new AgentUI({ version: pkgVersion, model, profile, ailangVersion, extensions: profileAgent.extensions });
  const oneShot = motokoFlags.oneshot;
  // Set once a one-shot's terminal event is being finished, so the runtime's exit does not race it.
  let oneShotFinishing = false;
  if (answerFile !== null && !oneShot) {
    // PLAN-002 W1b: the TTY writer runs only in an `--answer-file` one-shot. An interactive session
    // has no single final answer to publish.
    process.stderr.write("--answer-file is ignored in an interactive session; add --oneshot.\n");
  }

  function spawnRuntimeProcess(task: string, logPrompt: boolean, resume?: ResumeSpawn): void {
    errorOccurred = false;
    const logger = new SessionLogger(projectRoot, pkgVersion, journal);
    sessionLogger = logger;
    reportSessionPath(logger.filePath);
    if (logPrompt) logger.logUserInput(task);
    runtimeProcess = new RuntimeProcess(
      task,
      envUrl,
      model,
      workdir,
      profile,
      boundPort,
      systemPrompt,
      openaiBaseUrl,
      aiOptionsJson,
      (event) => {
        // ADR-003 v6.1 D2 / PLAN-003 P1 Part 6: `run_suspended` must NOT set this. `errorOccurred`
        // is read only on runtime EXIT, where it means "the process died after saying why, so
        // recover into awaiting-a-task instead of ending the session". A suspended runtime has not
        // died — it is alive and holding the exhausted turn's continuation for the operator's next
        // line — and outside headless it emits no `error` at all (session.ail's outer loops match
        // `suspended` before `result`). Setting it here would arm the recovery branch for a
        // process that never took it, and would then fire on whatever unrelated exit came later.
        // The `=== "error"` test below is what keeps that true; a future `||` here would break it.
        if (event.type === "error") errorOccurred = true;
        // PLAN-003 P3 Part 5. A `--resume` child that refused the journal says which rule, then exits
        // 3. The reason is PERSISTED beside the journal (`markUnresumable`), so the next restart
        // spawns fresh instead of retrying a resume that will refuse again, and it recovers into
        // awaiting a task exactly as an exit after `error` does — the refusal is already on screen.
        if (event.type === "session_resume_refused") {
          journal.markUnresumable(`a --resume was refused (${event.refusal}): ${event.message}`);
          errorOccurred = true;
        }
        completeHeaderFrom(event);
        logger.log(event);
        // ADR-002 D1.3, the interactive one-shot. At HEAD the TTY path never exits on `done`; under
        // `--oneshot` it does, and only after the answer is published (D1.2) and the logger has
        // DRAINED (R4) — `logger.log` above is synchronous and is not a drain. See `finishOneShot`.
        if (oneShot && (event.type === "done" || event.type === "error")) {
          oneShotFinishing = true;
          void finishOneShot(event, answerFile, abortRequested || interrupted, {
            forward: (e) => ui.handleEvent(e),
            close: () => logger.close(),
            stopUi: () => ui.stop(),
            stderr: (line) => process.stderr.write(line),
            exit: (code) => process.exit(code),
          });
          return;
        }
        ui.handleEvent(event);
      },
      () => {
        // Drain JSONL stream BEFORE process.exit so the tail (run_summary,
        // done) reaches disk. See M-MOTOKO-EVAL-HARNESS-HARDENING gap #1.
        const closing = logger.close();
        sessionLogger = undefined;
        ui.runtimeProcess = undefined;
        const pendingRestart = runtimeProcess?.restartPending;
        // A one-shot whose runtime exited with no `done`/`error` to finish on (an ESC interrupt, a
        // kill, a crash) ends here too — non-zero, and never into awaiting another task. A `done` or
        // `error` already on its way through `finishOneShot` owns the exit.
        if (oneShot && !pendingRestart) {
          journal.writeExit(interrupted || abortRequested ? "abort" : "child_exit");
          if (oneShotFinishing) return;
          const unpublished = answerFile !== null ? unpublishedOnExit(answerFile, interrupted || abortRequested) : null;
          void closing.then(() => {
            ui.stop();
            if (unpublished !== null && !unpublished.ok) process.stderr.write(formatUnpublished(unpublished));
            else process.stderr.write("[oneshot] the runtime exited before its task finished\n");
            process.exit(unpublished !== null ? ANSWER_UNPUBLISHED_EXIT_CODE : 1);
          });
          return;
        }
        // D1's `exit`, with the reason this exit actually had. `abort` and `restart` are the SAME
        // entry with their reason — that is what replaced v4.1's two metadata rewrites — and the
        // three are distinguishable HERE and nowhere later: by the time the process hook runs, a
        // restart and a quit look identical. A restart respawns into the same session and the same
        // journal, so its boundary is followed by more entries, which is why more than one `exit`
        // per session is correct and only a CONSECUTIVE second one is suppressed.
        journal.writeExit(pendingRestart ? "restart" : interrupted ? "abort" : "child_exit");
        if (pendingRestart) {
          // Restart requested — respawn with optional new profile
          if (typeof pendingRestart === "string") {
            profile = pendingRestart;
            ui.setProfile(profile);
          }
          // Reset interrupted flag for clean restart
          interrupted = false;
          errorOccurred = false;
          // The respawn carries an empty task, which rpc.ail now treats as "no
          // opening turn" — it blocks on stdin instead of burning a model call on
          // a blank user message. So the UI has to go back to awaiting a task, or
          // shouldLockPlainInput would refuse the user's next prompt. A RESUMED
          // respawn (below) waits the same way: the child enters its conversation
          // loop between turns, or holding the suspended run, and reads stdin.
          ui.setAwaitingTask(true);
          preWarmIdle = true;
          // Small delay before respawn
          setTimeout(() => {
            // The user can submit a prompt inside this window; onInitialTask then
            // spawns a runtime for it because the old one is dead. Respawning here
            // too would overwrite `runtimeProcess` and orphan the one actually
            // running their task.
            if (runtimeProcess && !runtimeProcess.isDead) return;
            respawnForRestart();
          }, 100);
        } else if (interrupted) {
          // ESC was pressed — don't exit; let the user submit a new task.
          interrupted = false;
          preWarmIdle = false;
          errorOccurred = false;
          if (journal.canResume) ui.addHistoryText("Your next prompt resumes this session from its journal.", "cyan");
          ui.setAwaitingTask(true);
        } else if (errorOccurred) {
          // Process crashed after emitting an error (unexpected exit on the
          // normal error path).  Recover rather than exiting the TUI. The error
          // event has already been rendered, so there is nothing to add here.
          //
          // Ordered BEFORE the pre-warm branch: a boot pre-spawn that dies of
          // bad config is the cheapest failure signal the user ever gets, and
          // relabelling it "it will be restarted when you submit one" hides the
          // reason at exactly the moment it is most useful.
          errorOccurred = false;
          preWarmIdle = false;
          // Say what the next prompt will do, since it is not what a fresh start does: a session
          // with a history resumes from its journal (`onInitialTask`), crash included.
          if (journal.canResume) ui.addHistoryText("Your next prompt resumes this session from its journal.", "cyan");
          ui.setAwaitingTask(true);
        } else if (preWarmIdle) {
          // A pre-warm runtime exited before any prompt was submitted, without
          // saying why. Stay in the TUI and keep awaiting a task — exiting here
          // would look like Motoko refusing to start. The next prompt spawns a
          // fresh runtime through the onInitialTask fallback, which is where
          // the failure becomes visible.
          preWarmIdle = false;
          ui.addHistoryText("Runtime exited before the first prompt; it will be restarted when you submit one.", "red");
          ui.setAwaitingTask(true);
        } else {
          void closing.then(() => {
            ui.stop();
            process.exit(0);
          });
        }
      },
      resume,
    );
    ui.runtimeProcess = runtimeProcess;
  }

  /**
   * ADR-003 v6.1 D6: A RESTART RESUMES THE SESSION FROM ITS JOURNAL (PLAN-003 P3 Part 5).
   *
   * `/restart` (and a profile switch, which is a restart with `--profile`) used to respawn with an
   * empty task, and the new process began a history nobody had — which D1's third arm then refused
   * to splice into the journal, marking the session unresumable. Now the respawn passes
   * `--resume <journal>`: the child folds it, applies D5's compatibility rows against the runtime it
   * built for the (possibly new) profile, and continues the same conversation. The lease is already
   * this process's (D6 step 1); the resume count is bumped so the new runs are `r<n>.*`.
   *
   * It falls back to the old fresh respawn when there is nothing to resume — no history seeded yet —
   * or when the session is already known to be unresumable, and SAYS WHY in the latter case rather
   * than retrying a resume that will refuse.
   */
  function respawnForRestart(): void {
    if (journal.canResume) {
      bumpSessionResumeCount();
      spawnRuntimeProcess("", false, { journalPath: journal.filePath });
      return;
    }
    if (journal.unresumable) {
      ui.addHistoryText(`Not resuming this session: ${journal.unresumable}`, "red");
    }
    spawnRuntimeProcess("", false);
  }

  ui.onModelChange = (newModel) => {
    process.env.MODEL = newModel;
    // See the non-TTY arm above: `model_change` is a command the host sends, so the host is what
    // journals it.
    journal.record({ type: "model_change", model: newModel });
    runtimeProcess?.setModel(newModel);
  };
  ui.onUserMessage = (content) => {
    sessionLogger?.logUserInput(content);
    runtimeProcess?.sendUserMessage(content);
  };
  ui.onAbort = () => {
    // Ctrl+C quits unless a live runtime is actually working on a task. The
    // boot pre-spawn and a `/restart` respawn both leave a warm runtime in
    // `runtimeProcess` with no task attached (`preWarmIdle`): aborting that one
    // exits into the preWarmIdle branch above, which deliberately keeps the TUI
    // up, and the next Ctrl+C is then swallowed by RuntimeProcess.send()'s
    // dead-child guard — leaving no way out of the TUI at all.
    if (runtimeProcess && !runtimeProcess.isDead && !preWarmIdle) {
      abortRequested = true;
      runtimeProcess.abort();
      return;
    }
    runtimeProcess?.kill();
    ui.stop();
    process.exit(0);
  };
  ui.onInterrupt = () => { interrupted = true; runtimeProcess?.kill(); };

  // Restart handler — respawn the runtime process with optional new profile
  ui.onRestart = (newProfile) => {
    if (runtimeProcess) {
      runtimeProcess.restart(newProfile);
    } else {
      // No running process — start fresh
      profile = newProfile ?? profile;
      ui.setProfile(profile);
      respawnForRestart();
    }
  };

  // Hand the first prompt to the runtime. Normally the pre-spawn below has one
  // up and warm already, so this is a stdin write and the user sees output
  // almost immediately. The spawn is the fallback for when that process is gone
  // (startup failure, ESC interrupt, an error the runtime exited on, a kill).
  ui.onInitialTask = (task: string) => {
    preWarmIdle = false;
    if (runtimeProcess && !runtimeProcess.isDead) {
      sessionLogger?.logUserInput(task);
      runtimeProcess.sendUserMessage(task);
      return;
    }
    // A DEAD RUNTIME WITH A HISTORY IS RESUMED, NOT REPLACED. Since the host reports an unexplained
    // child death instead of exiting on it (the OOM kills of 2026-09-08/12), this TUI outlives its
    // child and keeps the lease — so no second Motoko can resume the session, and this prompt is
    // the only way on. A fresh spawn here would begin a history the journal never had: D1's third
    // arm compares the seed with the last `digest_after`, finds they diverge, and marks the session
    // unresumable — the step-budget issue's lost history, reached by typing. So the respawn is
    // `/restart`'s: `--resume <journal>` folds the crash (dangling calls stripped, steps carried)
    // and the child reads this prompt from stdin as the resumed conversation's next turn.
    if (journal.canResume) {
      respawnForRestart();
      sessionLogger?.logUserInput(task);
      runtimeProcess?.sendUserMessage(task);
      return;
    }
    spawnRuntimeProcess(task, true);
  };

  const taskFromArgs = process.argv[2] ?? process.env.TASK;
  if (taskFromArgs) {
    spawnRuntimeProcess(taskFromArgs, false);
  } else {
    // No task provided — let the user type it into the TUI input.
    ui.setAwaitingTask(true);
    // Pre-spawn the runtime now, with an empty task, so the AILANG module load
    // overlaps with the user typing their first prompt instead of landing after
    // they press Enter. Measured on this repo: ~1.2s with a warm compile cache,
    // ~15s after editing a widely-imported core module, ~20s fully cold (the
    // cache key includes the compiler commit, so rebuilding `ailang` invalidates
    // it). rpc.ail runs no opening turn for an empty task, so this costs no
    // model call — it only pays the compile early.
    //
    // ADR-003 v6.1 D6 (PLAN-003 P3 Part 5): A MOTOKO STARTED ON A SESSION THAT ALREADY HAS A
    // JOURNAL RESUMES IT. This is the crash half of the second judging number: after a `kill -9`
    // the next Motoko on that session id takes the stale lease over (P3 Part 4) and adopts the
    // journal — and a FRESH pre-spawn would then seed a history nobody had, which D1's third arm
    // refuses to splice in and marks the session unresumable. `respawnForRestart` resumes when the
    // adopted journal can be resumed and spawns fresh otherwise, which for a new session is always.
    respawnForRestart();
    preWarmIdle = true;
  }
}

async function promptForTask(): Promise<string> {
  process.stdout.write("> ");
  return new Promise((resolve) => {
    process.stdin.once("data", (d) => resolve(d.toString().trim()));
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
