import { spawn, ChildProcess } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as readline from "readline";
import { createOhMyPiSession } from "./ohMyPi/session-adapter.js";
import { dispatchOhMyPiTool } from "./ohMyPi/dispatcher.js";
import { CORE_MAP, EXTENSION_MAPS } from "./config.js";

// autoForwardedEnvKeys — the SINGLE source of truth for which parent env vars reach the
// AILANG runtime subprocess. The childEnv allowlist below scrubs everything not listed,
// which has silently broken at least FIVE env-gated features whose var was forgotten:
// SYSTEM_MD, MOTOKO_REPO, MOTOKO_PERSIST_RETRIES, AILANG_OLLAMA_MAX_TOKENS, AILANG_STDLIB_PATH
// (AILANG_OLLAMA_MAX_TOKENS was even hand-added twice). Root cause: the allowlist was a second
// source of truth that drifts from config.ts's CORE_MAP. Instead, derive forwarding from
// CORE_MAP/EXTENSION_MAPS plus the motoko/ailang namespaces, so a new env-gated feature reaches
// the .ail BY DEFAULT instead of failing silently. Exported for the drift-guard test.
export function autoForwardedEnvKeys(env: NodeJS.ProcessEnv): string[] {
  const keys = new Set<string>([
    ...Object.values(CORE_MAP).map((e) => e.env),
    ...Object.values(EXTENSION_MAPS).flatMap((m) => Object.values(m).map((e) => e.env)),
  ]);
  for (const k of Object.keys(env)) {
    if (k.startsWith("MOTOKO_") || k.startsWith("AILANG_") || k === "SYSTEM_MD") keys.add(k);
  }
  return [...keys];
}

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
  | { type: "session_start"; task: string; model: string; brainVersion: string; ailangBuilt: string; config_profile?: string; config_dir?: string; loaded_extensions?: string[] }
  | { type: "context_usage"; step: number; tokens_est: number; limit: number }
  | { type: "thinking_stream_start"; step: number; stream_id: string; model: string }
  | { type: "thinking_delta"; step: number; stream_id: string; seq: number; text_delta: string }
  | { type: "reasoning_delta"; step: number; stream_id: string; seq: number; text_delta: string }
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
  | { type: "scratchpad_result"; tool_call_id: string; request_id: string; step: number; cells_json: string }
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
  | { type: "native_tool_results"; request_id: string; results: NativeToolResult[] }
  | { type: "v2_tool_dispatch_start"; step: number; stream_id: string; tool: string; id: string }
  | { type: "v2_tool_dispatch_complete"; step: number; stream_id: string; id: string };

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

export function providerSelectionModel(model: string, openaiBaseUrl: string): string {
  const trimmed = model.trim();
  if (trimmed === "openrouter/auto") return trimmed;
  if (trimmed.startsWith("openrouter/")) return trimmed;
  if (trimmed.startsWith("ollama/") || trimmed.startsWith("ollama:")) return trimmed;

  // For local OpenAI-compatible endpoints, unknown model ids like
  // "deepseek-v4-flash" do not let AILANG infer the OpenAI provider. Use a
  // configured OpenAI selector for --ai; stepWithStream still sends the real
  // local model id. Use the AILANG model alias ("gpt5"), not the provider API
  // id ("gpt-5"), so AILANG takes the configured-model path that honors
  // OPENAI_BASE_URL.
  if (openaiBaseUrl.trim() !== "") return "gpt5";

  // AILANG's --ai provider guessing treats vendor/model strings such as
  // "openai/..." and "anthropic/..." as OpenRouter vendor ids. Motoko uses
  // those prefixes as direct-provider UI/profile routing ids, so strip them
  // before provider selection. The step call separately receives the same
  // stripped API model id from provider_api_model().
  for (const prefix of ["openai/", "anthropic/", "google/"]) {
    if (trimmed.startsWith(prefix)) {
      const bare = trimmed.slice(prefix.length);
      return bare.length > 0 ? bare : trimmed;
    }
  }

  return trimmed;
}

export function normalizeRuntimeWarning(line: string): string | null {
  let message = line.trim();
  if (!message) return null;

  while (message.toLowerCase().startsWith("warning:")) {
    message = message.slice("warning:".length).trim();
  }

  if (message.includes("stdlib version mismatch:")) return null;
  if (message.includes("cache_hint_ignored_")) return null;

  return message.length > 0 ? message : null;
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

// M-MOTOKO-EVAL-HARNESS-HARDENING gap #6: when WORKDIR is a per-task scratch
// dir (e.g. AILANG eval harness), the AILANG runtime's FS effect is sandboxed
// to that dir — so it CANNOT read profile config from the fork at
// MOTOKO_REPO/.motoko/config/<profile>/. This mirror copies the profile dir
// into <workdir>/.motoko/config/<profile>/ so the runtime's profile lookup
// succeeds inside the sandbox. No-op when (a) MOTOKO_REPO unset, (b) workdir
// is the fork itself, or (c) workdir already has a profile dir.
function mirrorProfileFromRepo(
  workdir: string,
  profile: string,
  repoPath: string,
): void {
  const repo = repoPath.trim();
  if (repo === "") return;
  const absWorkdir = path.resolve(workdir);
  const absRepo = path.resolve(repo);
  if (absWorkdir === absRepo) return;
  const dst = path.join(absWorkdir, ".motoko", "config", profile);
  if (fs.existsSync(path.join(dst, "config.json"))) return;
  const src = path.join(absRepo, ".motoko", "config", profile);
  if (!fs.existsSync(path.join(src, "config.json"))) return;
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src)) {
    const srcFile = path.join(src, entry);
    const dstFile = path.join(dst, entry);
    if (fs.statSync(srcFile).isFile()) {
      fs.copyFileSync(srcFile, dstFile);
    }
  }
}

// 2026-05-14: if MOTOKO_CONFIG points to an absolute path OUTSIDE the workdir
// (e.g. ~/.motoko/config/mark — a personal profile that shouldn't live in
// motoko_agent's tree), the AILANG runtime can't read it: FS_SANDBOX is
// pinned to <workdir>, so absolute reads outside that tree silently fail
// and the agent ships with extensions.order=[].
//
// Mirror the absolute profile into <workdir>/.motoko/config/<basename>/
// and rewrite the supervisor arg to the basename, so config.ail's
// resolve_profile_dir finds it via the workdir-local branch (sandbox-safe).
//
// Returns the (possibly-rewritten) profile string to use as --profile.
// No-op (returns original) when profile isn't absolute.
function mirrorAbsoluteProfile(workdir: string, profile: string): string {
  if (!path.isAbsolute(profile)) return profile;
  if (!fs.existsSync(path.join(profile, "config.json"))) return profile;
  const basename = path.basename(profile);
  if (basename === "") return profile;
  const absWorkdir = path.resolve(workdir);
  const dst = path.join(absWorkdir, ".motoko", "config", basename);
  // Marker file at <dst>/.source records which absolute path this mirror
  // was made from. Used to detect basename collisions: if two different
  // absolute MOTOKO_CONFIG paths share a basename (e.g. ~/.motoko/config/mark
  // vs /opt/shared/mark), the second one should NOT silently overwrite the
  // first one's mirror.
  //
  // No marker present + existing dst → treated as "in-tree default profile
  // with no ownership claim"; the personal mirror takes over freely. This
  // lets us keep an in-tree fallback profile checked into git AND have a
  // personal override mirror into the same name without conflict.
  const markerPath = path.join(dst, ".source");
  const currentSource = fs.existsSync(markerPath)
    ? fs.readFileSync(markerPath, "utf-8").trim()
    : "";
  if (
    fs.existsSync(path.join(dst, "config.json")) &&
    currentSource !== "" &&
    currentSource !== profile
  ) {
    // Genuine collision: another personal profile already mirrored here.
    // Fall back to the absolute path — will fail under FS_SANDBOX but
    // surfaces the conflict rather than corrupting the other user's mirror.
    return profile;
  }
  fs.mkdirSync(dst, { recursive: true });
  fs.writeFileSync(markerPath, profile + "\n", "utf-8");
  for (const entry of fs.readdirSync(profile)) {
    const srcFile = path.join(profile, entry);
    const dstFile = path.join(dst, entry);
    if (fs.statSync(srcFile).isFile()) {
      fs.copyFileSync(srcFile, dstFile);
    }
  }
  return basename;
}

export class RuntimeProcess {
  private proc: ChildProcess;
  private dead = false;
  private readonly workdir: string;
  private readonly onEvent: (e: AgentEvent) => void;

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
    const aiModelArg = providerSelectionModel(model, openaiBaseUrl);
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
      CLICKSTACK_INGESTION_KEY: process.env.CLICKSTACK_INGESTION_KEY,
      // SYSTEM_MD — path to the system-prompt file (for AILANG tasks, the language
      // reference). rpc.ail reads it via getEnvOr("SYSTEM_MD"). Without forwarding it
      // here the explicit allowlist scrubs it (same gotcha as MOTOKO_PERSIST_RETRIES /
      // MOTOKO_REPO above), so the model runs with NO system prompt — silently, chars=0.
      // This was invisible for days until the system_prompt_built event surfaced it.
      SYSTEM_MD: process.env.SYSTEM_MD ?? "",
      AILANG_FS_SANDBOX: workdir,
      AILANG_NO_VERSION_WARNINGS: process.env.AILANG_NO_VERSION_WARNINGS ?? "1",
      MOTOKO_STREAM_EVENTS: process.env.MOTOKO_STREAM_EVENTS ?? "1",
      // M-MOTOKO-HEADLESS (2026-05-08): when stdin is not a TTY, set
      // MOTOKO_HEADLESS=1 so the AILANG runtime's conversation_loop_v2
      // skips its readLine() drain (which blocks indefinitely on non-TTY
      // stdin instead of returning EOF) and exits cleanly after the first
      // task completes. Manual override: set MOTOKO_HEADLESS in the parent
      // env to force either mode regardless of TTY state.
      // See agent_loop_v2.ail conversation_loop_v2 for the AILANG-side gate.
      MOTOKO_HEADLESS:
        process.env.MOTOKO_HEADLESS ??
        (process.stdin.isTTY ? "" : "1"),
      // M-MOTOKO-PERSIST-NUDGE: forward the loop-persistence retry budget so
      // agent_loop_v2.ail's NoDecision branch can read it. Without this the
      // explicit env allowlist scrubs it and the feature is silently off —
      // same gotcha as MOTOKO_REPO / the pricing vars below. Empty = off.
      MOTOKO_PERSIST_RETRIES: process.env.MOTOKO_PERSIST_RETRIES ?? "",
      // M-MOTOKO-EVAL-HARNESS-HARDENING gap #6 (2026-05-08): forward
      // MOTOKO_REPO so the AILANG runtime can fall back to the fork's
      // bundled profile (.motoko/config/<profile>) when WORKDIR is a
      // per-task scratch dir without its own .motoko/config. Without
      // this, eval-harness runs see extensions.order=[] and other
      // profile defaults silently mask user-configured behavior.
      MOTOKO_REPO: process.env.MOTOKO_REPO ?? "",
      // MOTOKO_PROFILE_DIR — absolute path to the active profile's config
      // directory. Standalone AILANG extension packages (motoko-ext-*) read
      // their own JSON config here (e.g. motoko-ext-compaction-ai reads
      // ${MOTOKO_PROFILE_DIR}/compaction_ai.json). Without this var, the
      // packages fall back to "." which resolves to the AILANG runtime's
      // CWD (motoko_agent root) → "no such file or directory" panics on
      // first turn. The original src/core/config.ail path-built the same
      // location internally; the env-var split happened when extensions
      // moved out into separate packages without a corresponding launcher
      // wiring.
      MOTOKO_PROFILE_DIR: path.resolve(workdir, ".motoko", "config", profile),
      // M-OLLAMA-PER-MODEL-MAX-TOKENS: forward the per-model output budget so the
      // AILANG runtime's ollama /v1 path (resolveOllamaMaxTokens) uses the model's
      // declared max_output_tokens instead of the 4096 std/ai default. Qwen3.6
      // reasons thousands of tokens before the tool call and truncates
      // (finish_reason=length) at 4096 → 0 tool calls (disengagement). Without this
      // allowlist entry the explicit childEnv whitelist drops it — same gotcha as
      // MOTOKO_REPO / the pricing vars. Empty = the AILANG-side 16384 floor applies.
      AILANG_OLLAMA_MAX_TOKENS: process.env.AILANG_OLLAMA_MAX_TOKENS ?? "",
      // Forward the ollama /v1 HTTP timeout (AILANG default 300s). Large-context tasks
      // accumulate a big prompt; a single qwen request can exceed 5 min on a local GPU and
      // the AILANG runtime aborts with `context deadline exceeded`, killing the run mid-task.
      // Without this allowlist entry the var set by the launcher is dropped — same gotcha as
      // AILANG_OLLAMA_MAX_TOKENS above.
      AILANG_OLLAMA_HTTP_TIMEOUT_SEC: process.env.AILANG_OLLAMA_HTTP_TIMEOUT_SEC ?? "",
      // M-MOTOKO-EVAL-HARNESS-HARDENING M5 follow-up (2026-05-08): forward
      // pricing env vars set by the AILANG adapter from Task.Budget. Without
      // this, the AILANG-side fix (load_cost_rates reads these env vars) is
      // a no-op because the explicit whitelist drops them — same gotcha as
      // MOTOKO_REPO above (gap #6). Empty string falls through to motoko's
      // profile config fallback inside load_cost_rates.
      MOTOKO_COST_INPUT_PER_1M_MILLICENTS:
        process.env.MOTOKO_COST_INPUT_PER_1M_MILLICENTS ?? "",
      MOTOKO_COST_OUTPUT_PER_1M_MILLICENTS:
        process.env.MOTOKO_COST_OUTPUT_PER_1M_MILLICENTS ?? "",
    };
    // AILANG v0.15.x migration: forward AILANG_STDLIB_PATH if set in the
    // parent env so callers can point the runtime at an upstream stdlib
    // checkout (e.g. /Users/mark/dev/sunholo/ailang/std). Without this,
    // the agent fails with "stdlib module not found: std/ai/streaming"
    // because it falls back to system paths that don't have the new modules.
    if (process.env.AILANG_STDLIB_PATH) {
      childEnv.AILANG_STDLIB_PATH = process.env.AILANG_STDLIB_PATH;
    }
    // ClickStack/OTLP handoff: the launcher uses an explicit env whitelist,
    // so tracing variables must be copied deliberately. Keep export gated so
    // default dev runs do not attempt OTLP delivery when the opt-in sidecar is
    // down.
    if (process.env.MOTOKO_OTEL && process.env.MOTOKO_OTEL.trim() !== "") {
      childEnv.MOTOKO_OTEL = process.env.MOTOKO_OTEL;
      childEnv.OTEL_EXPORTER_OTLP_ENDPOINT =
        process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? "http://clickstack:4318";
      childEnv.OTEL_EXPORTER_OTLP_PROTOCOL =
        process.env.OTEL_EXPORTER_OTLP_PROTOCOL ?? "http/protobuf";
      childEnv.OTEL_SERVICE_NAME =
        process.env.OTEL_SERVICE_NAME ?? "motoko-agent";
      childEnv.AILANG_TRACE = process.env.AILANG_TRACE ?? "standard";
      childEnv.AILANG_TRACE_MAX_SPANS =
        process.env.AILANG_TRACE_MAX_SPANS ?? "100";
      if (process.env.OTEL_EXPORTER_OTLP_HEADERS) {
        childEnv.OTEL_EXPORTER_OTLP_HEADERS =
          process.env.OTEL_EXPORTER_OTLP_HEADERS;
      }
      if (process.env.OTEL_RESOURCE_ATTRIBUTES) {
        childEnv.OTEL_RESOURCE_ATTRIBUTES =
          process.env.OTEL_RESOURCE_ATTRIBUTES;
      }
      for (const key of [
        "OTEL_TRACES_EXPORTER",
        "OTEL_METRICS_EXPORTER",
        "OTEL_EXPORTER_OTLP_TIMEOUT",
        "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
        "OTEL_EXPORTER_OTLP_TRACES_HEADERS",
        "OTEL_EXPORTER_OTLP_TRACES_TIMEOUT",
        "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT",
        "OTEL_EXPORTER_OTLP_METRICS_HEADERS",
        "OTEL_EXPORTER_OTLP_METRICS_TIMEOUT",
      ]) {
        const value = process.env[key];
        if (value && value.trim() !== "") {
          childEnv[key] = value;
        }
      }
    }
    // M-MOTOKO-RPC-LOOP-FULL-MIGRATION M10 cutover (2026-05-06): the
    // upstream std/ai.step() typed-tool-use loop is now the default and
    // only loop. The MOTOKO_AGENT_V2 env var is no longer consulted by
    // the runtime — forwarding has been removed. All 6 legacy decision
    // points (extension intercept, tool gating, tool-handle routing,
    // ohmy_pi backend split, hybrid mode, multi-turn conversation_loop)
    // are migrated and validated by the M9 25/25 provider matrix.
    if (openaiBaseUrl.trim() !== "") childEnv.OPENAI_BASE_URL = openaiBaseUrl;
    if (aiOptionsJson.trim() !== "") childEnv.MOTOKO_AI_OPTIONS_JSON = aiOptionsJson;

    // SYSTEMIC ENV-FORWARD GUARD: auto-forward every config-mapped (CORE_MAP) and
    // motoko/ailang-namespaced var that wasn't already set explicitly above. This is
    // what kills the recurring "forgot to add the var to the allowlist → feature silently
    // off" bug class (SYSTEM_MD, MOTOKO_REPO, MOTOKO_PERSIST_RETRIES, AILANG_OLLAMA_*,
    // AILANG_STDLIB_PATH …). Explicit entries above win (they carry computed values /
    // defaults); everything else now reaches the .ail by default instead of vanishing.
    for (const k of autoForwardedEnvKeys(process.env)) {
      if (!(k in childEnv) && process.env[k] !== undefined) {
        childEnv[k] = process.env[k];
      }
    }

    // M-MOTOKO-EVAL-HARNESS-HARDENING gap #6 (2026-05-08): mirror the
     // requested profile dir from MOTOKO_REPO into <workdir>/.motoko/config
     // when the workdir doesn't already have one. AILANG_FS_SANDBOX
     // restricts the runtime's FS effect to <workdir>; without this mirror,
     // the agent silently falls back to default config (extensions=[],
     // no cost_rates) because reading the fork's profile would escape the
     // sandbox. Mirror runs at most once per spawn and is a no-op when
     // workdir is already the fork itself.
    mirrorProfileFromRepo(workdir, profile, childEnv.MOTOKO_REPO ?? "");

    // 2026-05-14: If MOTOKO_CONFIG was an absolute out-of-tree path
    // (e.g. ~/.motoko/config/mark), mirror it into workdir and use the
    // basename so the AILANG runtime can read it through FS_SANDBOX.
    // Returns the original profile unchanged when not applicable.
    const resolvedProfile = mirrorAbsoluteProfile(workdir, profile);
    // Update MOTOKO_PROFILE_DIR to the mirrored location too, so
    // standalone extension packages reading ${MOTOKO_PROFILE_DIR}/<ext>.json
    // find the right files.
    if (resolvedProfile !== profile) {
      childEnv.MOTOKO_PROFILE_DIR = path.resolve(
        workdir,
        ".motoko",
        "config",
        resolvedProfile,
      );
    }

    const supervisorArgs = [
      "--profile",
      resolvedProfile,
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
        "Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace",
        "--ai",
        aiModelArg,
        "--entry",
        "main",
        "--net-allow-http",
        "--net-allow-localhost",
        "--stream-allow-http",
        "--stream-allow-localhost",
        "src/core/supervisor.ail",
        "--",
        ...supervisorArgs
      ],
      {
        env: childEnv,
        stdio: ["pipe", "pipe", "pipe"],
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

    const stderrRl = readline.createInterface({
      input: this.proc.stderr!,
      crlfDelay: Infinity,
    });
    stderrRl.on("line", (line) => {
      const message = normalizeRuntimeWarning(line);
      if (!message) return;
      this.onEvent({ type: "warning", message });
    });

    this.proc.on("exit", () => {
      this.dead = true;
      stderrRl.close();
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
      const isFileTool =
        call.tool === "ReadFile" || call.tool === "WriteFile" || call.tool === "EditFile" || call.tool === "Search";
      const result = isFileTool
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

  /**
   * Request a session restart with optional profile change.
   * The AILANG runtime will emit a session_suspend event and exit.
   * The TUI is expected to respawn the process.
   */
  restart(newProfile?: string): void {
    if (this.dead) return;
    this.send({ type: "restart", profile: newProfile });
    // Set a flag so the exit handler knows to respawn
    this._restartPending = newProfile ?? true;
  }

  /** Check if restart was requested (string = new profile, true = same profile) */
  get restartPending(): string | boolean | undefined {
    return this._restartPending;
  }

  private _restartPending?: string | boolean;
}
