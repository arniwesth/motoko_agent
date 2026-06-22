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
import { execSync } from "child_process";
import { renderBanner } from "./banner-runtime.js";
import { startEnvServer } from "./env-server.js";
import { RuntimeProcess, resolveDelegatedExec } from "./runtime-process.js";
import { AgentUI, parseScratchpadCellsJson } from "./ui.js";
import { SessionLogger } from "./session-logger.js";
import { activeProfile } from "./config.js";
import { resolveRuntimeModel } from "./models.js";
import type { AgentEvent, DelegatedCall } from "./runtime-process.js";
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

function systemPromptForWorkspace(projectRoot: string, workdir: string): string {
  const configured = (process.env.SYSTEM_MD ?? "").trim();
  const candidate = configured !== ""
    ? (path.isAbsolute(configured) ? configured : path.resolve(workdir, configured))
    : path.join(projectRoot, "SYSTEM.md");
  if (!fs.existsSync(candidate)) return "";

  const absWorkdir = path.resolve(workdir);
  const rel = path.relative(absWorkdir, path.resolve(candidate));
  if (rel === "") return ".";
  if (rel.startsWith("..") || path.isAbsolute(rel)) return "";
  return rel;
}

// materializeSystemPromptArg copies the CONTENT of an external --system-prompt
// file into a managed in-workspace file and returns its absolute path. This lets
// a headless caller inject a system prompt from ANY path (absolute or outside the
// workspace) — motoko copies it in, so systemPromptForWorkspace's workdir-relative
// contract (the supervisor reads the prompt via a path relative to workdir) stays
// intact. Returns null if the source path is empty, missing, or unreadable, in
// which case the caller falls back to SYSTEM_MD / the default SYSTEM.md.
function materializeSystemPromptArg(flagValue: string, workdir: string): string | null {
  const src = flagValue.trim();
  if (src === "") return null;
  const srcAbs = path.isAbsolute(src) ? src : path.resolve(process.cwd(), src);
  let content: string;
  try {
    content = fs.readFileSync(srcAbs, "utf8");
  } catch (err) {
    console.error(`[motoko] --system-prompt: cannot read ${srcAbs}: ${String(err)}`);
    return null;
  }
  const dest = path.join(path.resolve(workdir), ".motoko-system-prompt.md");
  try {
    fs.writeFileSync(dest, content, "utf8");
  } catch (err) {
    console.error(`[motoko] --system-prompt: cannot write ${dest}: ${String(err)}`);
    return null;
  }
  return dest;
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
        process.exit(0);
        break;
      case "error":
        process.stderr.write(`[error] ${event.message}\n`);
        process.exit(1);
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

  stop(): void {}
}

class JsonlLogger {
  onModelChange?: (model: string) => void;
  onAbort?: () => void;
  onUserMessage?: (content: string) => void;

  handleEvent(event: AgentEvent): void {
    process.stdout.write(JSON.stringify(event) + "\n");
    if (event.type === "done") process.exit(0);
    if (event.type === "error") process.exit(1);
  }

  stop(): void {}
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

// M-MOTOKO-EVAL-HARNESS-HARDENING M2b + M2c (gaps #7, #8): parse motoko-
// specific CLI flags before treating argv[2] as task text.
//   --headless       — force MOTOKO_HEADLESS=1 (more discoverable than env var)
//   --version, -v    — print structured version info to stdout and exit 0
// Recognized flags are removed from process.argv so downstream argv[2] reads
// still work for the task text. Unknown flags pass through to the task text
// (so "motoko --whatever ..." doesn't break).
function parseMotokoFlags(): {
  headless: boolean;
  printVersion: boolean;
  systemPrompt: string | null;
} {
  const flags: {
    headless: boolean;
    printVersion: boolean;
    systemPrompt: string | null;
  } = { headless: false, printVersion: false, systemPrompt: null };
  const remaining: string[] = [process.argv[0], process.argv[1]];
  for (let i = 2; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg === "--headless") {
      flags.headless = true;
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

  const shellEnvKeys = new Set(Object.keys(process.env));
  loadDotEnv(shellEnvKeys);
  synthesizeClickStackOtelHeaders();

  const jsonlOutput = process.env.MOTOKO_JSONL_OUTPUT === "1";
  const headlessOutput = process.env.MOTOKO_HEADLESS === "1";
  // process.stdout.isTTY can be undefined in piped subprocess contexts
  // (e.g. oh-my-pi's session runner) even when the outer environment has a
  // real terminal. Use a multi-signal heuristic, but keep MOTOKO_HEADLESS as a
  // hard opt-out from TUI-only output such as the bitmap banner.
  //
  // CI is NOT treated as a TUI blocker — devcontainers and CI runners often
  // set CI=1 even when the user is running interactively.
  const isTTY =
    Boolean(process.stdout.isTTY) ||
    Boolean(process.stdout.columns) ||
    Boolean(process.env.FORCE_TTY);

  // Set the terminal/tab title to "motoko" so VS Code, iTerm2, etc. show
  // the agent name instead of the underlying runtime ("bun.exe" / "node").
  // Skip in headless/plain/jsonl output so log streams stay text-only.
  if (isTTY && !headlessOutput && !jsonlOutput) {
    process.stdout.write("\x1b]0;[λ] motoko\x07");
  }
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
  const openaiBaseUrl = process.env.OPENAI_BASE_URL ?? profileAgent.openaiBaseUrl ?? "";
  const aiOptionsJson = process.env.MOTOKO_AI_OPTIONS_JSON ?? profileAgent.aiOptionsJson ?? "";

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
  if (isTTY && !headlessOutput && !jsonlOutput) {
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

  if (!isTTY) {
    // Non-TTY: prompt for task first, then run with PlainLogger.
    const task =
      process.argv[2] ??
      process.env.TASK ??
      (await promptForTask());
    const ui = jsonlOutput ? new JsonlLogger() : new PlainLogger();
    const logger = new SessionLogger(projectRoot, pkgVersion);
    sessionLogger = logger;
    logger.logUserInput(task);
    ui.onModelChange = (newModel) => {
      process.env.MODEL = newModel;
      runtimeProcess!.setModel(newModel);
    };
    ui.onAbort = () => runtimeProcess!.abort();
    ui.onUserMessage = (content) => {
      logger.logUserInput(content);
      runtimeProcess!.sendUserMessage(content);
    };
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
        logger.log(event);
        // For terminal events, drain the JSONL stream BEFORE letting the UI
        // handler call process.exit. Otherwise process.exit drops the
        // WriteStream's pending buffer — losing run_summary, done, and any
        // events emitted in the same flush window. See M-MOTOKO-EVAL-HARNESS-
        // HARDENING gap #1 / gap #10 for the bisection.
        if (event.type === "done" || event.type === "error") {
          void logger.close().then(() => {
            ui.handleEvent(event);
          });
          return;
        }
        ui.handleEvent(event);
      },
      () => {
        void logger.close();
        sessionLogger = undefined;
        ui.stop();
      },
    );
    return;
  }

  // TTY mode: start the TUI immediately so the footer is visible before the
  // runtime process starts (and even before the user types a task).
  // Make ailang build datetime available to the runtime via environment variable.
  process.env.AILANG_BUILT = ailangVersion;

  const ui = new AgentUI({ version: pkgVersion, model, profile, ailangVersion, extensions: profileAgent.extensions });

  function spawnRuntimeProcess(task: string, logPrompt: boolean): void {
    errorOccurred = false;
    const logger = new SessionLogger(projectRoot, pkgVersion);
    sessionLogger = logger;
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
        if (event.type === "error") errorOccurred = true;
        logger.log(event);
        ui.handleEvent(event);
      },
      () => {
        // Drain JSONL stream BEFORE process.exit so the tail (run_summary,
        // done) reaches disk. See M-MOTOKO-EVAL-HARNESS-HARDENING gap #1.
        const closing = logger.close();
        sessionLogger = undefined;
        ui.runtimeProcess = undefined;
        const pendingRestart = runtimeProcess?.restartPending;
        if (pendingRestart) {
          // Restart requested — respawn with optional new profile
          if (typeof pendingRestart === "string") {
            profile = pendingRestart;
            ui.setProfile(profile);
          }
          // Reset interrupted flag for clean restart
          interrupted = false;
          errorOccurred = false;
          // Small delay before respawn
          setTimeout(() => spawnRuntimeProcess("", false), 100);
        } else if (interrupted) {
          // ESC was pressed — don't exit; let the user submit a new task.
          interrupted = false;
          ui.setAwaitingTask(true);
        } else if (errorOccurred) {
          // Process crashed after emitting an error (unexpected exit on the
          // normal error path).  Recover rather than exiting the TUI.
          errorOccurred = false;
          ui.setAwaitingTask(true);
        } else {
          void closing.then(() => {
            ui.stop();
            process.exit(0);
          });
        }
      },
    );
    ui.runtimeProcess = runtimeProcess;
  }

  ui.onModelChange = (newModel) => {
    process.env.MODEL = newModel;
    runtimeProcess?.setModel(newModel);
  };
  ui.onUserMessage = (content) => {
    sessionLogger?.logUserInput(content);
    runtimeProcess?.sendUserMessage(content);
  };
  ui.onAbort = () => { if (runtimeProcess) { runtimeProcess.abort(); } else { ui.stop(); process.exit(0); } };
  ui.onInterrupt = () => { interrupted = true; runtimeProcess?.kill(); };

  // Restart handler — respawn the runtime process with optional new profile
  ui.onRestart = (newProfile) => {
    if (runtimeProcess) {
      runtimeProcess.restart(newProfile);
    } else {
      // No running process — start fresh
      profile = newProfile ?? profile;
      ui.setProfile(profile);
      spawnRuntimeProcess("", false);
    }
  };

  const taskFromArgs = process.argv[2] ?? process.env.TASK;
  if (taskFromArgs) {
    spawnRuntimeProcess(taskFromArgs, false);
  } else {
    // No task provided — let the user type it into the TUI input.
    ui.setAwaitingTask(true);
    ui.onInitialTask = (task) => spawnRuntimeProcess(task, true);
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
