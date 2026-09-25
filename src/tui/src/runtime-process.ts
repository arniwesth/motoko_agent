import { spawn, ChildProcess } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as readline from "readline";
import { createOhMyPiSession } from "./ohMyPi/session-adapter.js";
import { dispatchOhMyPiTool } from "./ohMyPi/dispatcher.js";
import { sessionStartMs, sessionIdentity, sessionResumeCount } from "./session-identity.js";
import { exitManifestPath, rememberExitManifestPath } from "./exit-actions.js";
import {
  defaultWakeWaiterFactory,
  type WaitDescriptor,
  type WakeReply,
  type WakeRequest,
  type WakeWaiterFactory,
  type WakeWaiterHandle,
} from "./wake-waiter.js";

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
  // ADR-003 v6.1 D2. A run that reached its step budget now reports this
  // INSTEAD OF `error` (except under MOTOKO_HEADLESS, where the child still
  // emits both until P3 switches the plain and JSON loggers). It arrives
  // immediately before `run_summary`. The consumers — ui.ts, index.ts,
  // session-logger.ts, herdr-agent-state.ts — are PLAN-003 P1 Part 6's; this
  // part lands the wire type so the event is not an unknown one.
  | { type: "run_suspended"; session_id: string; run_id: string; reason: string; step: number }
  // ADR-003 v6.1 D1's JOURNAL-CLASS EVENTS, on the wire since P3 Part 3 (`phase_vocab.ail`'s
  // `to_schema_v1_kvs`). They are typed HERE, in P3 Part 4, because this is the part that routes
  // them: `SessionLogger.log` sends them to the journal and writes a digest to the JSONL log, and
  // a router that read them through `as never` would be deciding the file format off untyped
  // field names. `messages` / `message` are `unknown` on purpose — the [Message] codec is
  // `journal.ail`'s and the host copies the payload through without a second definition of it.
  | { type: "history_seeded"; run_id: string; messages: unknown[]; digest: string }
  | { type: "history_appended"; run_id: string; step: number; message: unknown; replaces_previous: boolean; digest_after: string }
  | { type: "history_replaced"; run_id: string; step: number; reason: string; first_kept?: number; messages: unknown[]; digest_after: string }
  | { type: "state_delta"; run_id: string; step: number; cumulative: Record<string, number>; telemetry: Record<string, number>; ext_artifacts_digest: string; ext_artifacts?: unknown }
  | { type: "session_resumed"; resume_count: number; from_id: string; from_ordinal: number; profile_from: string; profile_to: string; prompt_digest_from: string; prompt_digest_to: string; forced: boolean }
  // PLAN-003 P3 Part 5, both from a `--resume` child and NEITHER journal-class. `session_resume_view`
  // is the marker line the TUI prints under the resume seed's history (`journal.resume_view_json`):
  // it carries no messages, so the JSONL log gains no second copy of the conversation.
  // `session_resume_refused` is the child saying which compatibility or fold rule refused the
  // journal, immediately before it exits 3.
  | { type: "session_resume_view"; resume_count: number; from_id: string; boundary: string; boundary_detail: string; suspended: boolean; profile_from: string; profile_to: string; head_replaced: boolean; forced: boolean; dangling: string[]; ext_artifacts_digest: string; ext_artifacts_empty: boolean; messages: number; provider_calls_started: number; provider_calls_completed: number }
  | { type: "session_resume_refused"; journal: string; refusal: string; message: string }
  | { type: "error"; message: string }
  | { type: "warning"; message: string }
  | { type: "tool_calls"; request_id: string; tool_calls: DelegatedCall[] }
  | { type: "tool_results"; request_id: string; phase: ToolResultsPhase; results: DelegatedResult[] }
  | { type: "native_tool_calls"; request_id: string; tool_calls: DelegatedCall[] }
  | { type: "native_tool_results"; request_id: string; results: NativeToolResult[] }
  | { type: "v2_tool_dispatch_start"; step: number; stream_id: string; tool: string; id: string }
  | { type: "v2_tool_dispatch_complete"; step: number; stream_id: string; id: string }
  // ADR-002 D2 / PLAN-002 W4 Part 5. `wake_request` is the core asking the host which of its open
  // waits is ready (a protocol line, not a ledger event); `park_entered` and `wake_received` are the
  // ledger events either side of it. `wake_received` also means the request is resolved.
  | { type: "wake_request"; request_id: string; step: number; attempt: number; waits: WaitDescriptor[] }
  | { type: "park_entered"; request_id: string; step: number; waits: WaitDescriptor[] }
  | { type: "wake_received"; request_id: string; wait_id: string; outcome: string; detail: string };

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

/**
 * What to tell the operator when the runtime child exits WITHOUT a terminal event before it, or
 * null when the exit is clean. `.agent/issues/a-killed-motoko-process-exits-silently.md`: the
 * container's OOM killer SIGKILLs the child mid tool-phase (2026-09-08, 2026-09-12), the child can
 * say nothing, and an exit callback that ignores `(code, signal)` turns that death into a finish.
 */
export function describeUnexplainedExit(code: number | null, signal: NodeJS.Signals | null): string | null {
  const unsaid = "before it reported done or an error";
  if (signal === "SIGKILL") {
    return `The AILANG runtime was killed (SIGKILL) ${unsaid}. This is usually the out-of-memory killer: ` +
      "a rise in oom_kill in /sys/fs/cgroup/memory.events confirms it.";
  }
  if (signal) return `The AILANG runtime was killed by ${signal} ${unsaid}.`;
  if (code !== null && code !== 0) return `The AILANG runtime exited with code ${code} ${unsaid}.`;
  return null;
}

/** Events after which the child's exit is already explained on the wire (refusal: `rpc.ail` exits 3). */
const EXIT_EXPLAINING_EVENTS = new Set(["done", "error", "session_resume_refused"]);

/**
 * Events that end an outstanding park without a matching `wake_received`: the run ended (`done`,
 * `error`, a suspend on the step budget — the `Park` arm's own guard) or the session suspended for a
 * restart. `run_suspended` is not in PLAN-002's list; it is here because a re-issue that exhausts
 * the step budget suspends the run with no wake, and the park would otherwise stay open for ever.
 */
const PARK_ENDING_EVENTS = new Set(["done", "error", "session_suspend", "run_suspended"]);

/**
 * What ESC does to the runtime: abort a parked run over stdin (W4 Part 5); cancel a suspended-child's
 * park in the journal (PLAN-003 P4 Part 6, the ESC row); kill anything else.
 *
 * The suspended-child row comes FIRST because it is the only one with no live child: the owner
 * holds the park after the child's exit, so ESC writes the `wake(aborted)` the live child would have
 * emitted (`wait_id "abort"`, W4 Part 5's table) and respawns NOTHING — the TUI goes back to awaiting
 * a task, and the next prompt resumes the session through `onInitialTask` (`--resume`), where the
 * child folds `Open("wake:aborted")` and reads that prompt as its next turn. `"wake_aborted"` says the
 * wake is on disk; `"none"` that the park was already answered or closed, so nothing was written.
 */
export function interruptRuntime(
  rp: Pick<RuntimeProcess, "isParked" | "abort" | "kill"> | undefined,
  suspended: { owner: SuspendedChild; journal: WakeJournal } | null = null,
): "abort" | "kill" | "none" | "wake_aborted" {
  if (suspended !== null) {
    return abortSuspendedChild(suspended.owner, suspended.journal, "abort") ? "wake_aborted" : "none";
  }
  if (!rp) return "none";
  if (rp.isParked) {
    rp.abort();
    return "abort";
  }
  rp.kill();
  return "kill";
}

/** The journal `exit` entry's reason for a TTY runtime exit (index.ts's exit handler). */
export function journalExitReason(
  pendingRestart: string | boolean | undefined,
  interrupted: boolean,
): "restart" | "abort" | "child_exit" {
  return pendingRestart ? "restart" : interrupted ? "abort" : "child_exit";
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

/**
 * Name this session's exit manifest, create its directory, and remember it for the exit handler.
 *
 * The directory has to exist before the first publish: the runtime writes through
 * `writeFileResult`, which does not create parents, and a manifest that silently fails to be
 * written looks exactly like an install where no extension declared an exit intent.
 */
function exitManifestPathFor(workdir: string): string {
  const p = exitManifestPath(workdir);
  try {
    fs.mkdirSync(path.dirname(p), { recursive: true });
  } catch {
    // A manifest that cannot be written costs the exit-time courtesy, never the run.
  }
  rememberExitManifestPath(p);
  return p;
}

export function buildChildEnv(
  workdir: string,
  profile: string,
  openaiBaseUrl: string,
  aiOptionsJson: string,
): NodeJS.ProcessEnv {
  const childEnv: NodeJS.ProcessEnv = {
    PATH: process.env.PATH,
    HOME: process.env.HOME,
    ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY,
    OPENAI_API_KEY: process.env.OPENAI_API_KEY,
    OPENROUTER_API_KEY: process.env.OPENROUTER_API_KEY,
    GOOGLE_API_KEY: process.env.GOOGLE_API_KEY,
    EXA_API_KEY: process.env.EXA_API_KEY,
    CLICKSTACK_INGESTION_KEY: process.env.CLICKSTACK_INGESTION_KEY,
    AILANG_FS_SANDBOX: workdir,
    AILANG_NO_VERSION_WARNINGS: process.env.AILANG_NO_VERSION_WARNINGS ?? "1",
    MOTOKO_STREAM_EVENTS: process.env.MOTOKO_STREAM_EVENTS ?? "1",
    MOTOKO_HEADLESS:
      process.env.MOTOKO_HEADLESS ??
      (process.stdin.isTTY ? "" : "1"),
    MOTOKO_PERSIST_RETRIES: process.env.MOTOKO_PERSIST_RETRIES ?? "",
    MOTOKO_REPO: process.env.MOTOKO_REPO ?? "",
    MOTOKO_CAPTURE_FAILED_PAYLOAD: process.env.MOTOKO_CAPTURE_FAILED_PAYLOAD ?? "",
    MOTOKO_PROFILE_DIR: path.resolve(workdir, ".motoko", "config", profile),
    // THE RUN IDENTITY FOR F-5 OWNERSHIP, minted here and nowhere else.
    //
    // `motoko-ext-herdr` tags every delegate pane it spawns with `<pane>:<session ms>` so that an
    // orphan can be recognised as THIS session's without falling back to a name prefix that two
    // concurrent Motokos would both match. The clock cannot live in the extension: the runtime is
    // spawned per task, so it would mint a new identity for every task and nothing keyed by it
    // would survive to the next one. This process outlives every runtime it spawns, so
    // `sessionStartMs()` memoizes one value for the whole session. The token FORMAT is the
    // extension's and has one definition (`packages/motoko-ext-herdr/types.ail`); this side
    // supplies only the clock. Reasoning: `session-identity.ts`.
    MOTOKO_SESSION_MS: String(sessionStartMs()),
    // ONE SESSION ID, ADR-003 v6.1 D5, and the repair of the issue's two ids.
    //
    // `derive_session_id` (`session.ail:1677-1684`) returns this value when it is non-empty and
    // otherwise mints its own from a clock read — so before this line the host named the JSONL log
    // one thing and the child called the session another, and every wire event of a follow-up turn
    // carried the child's. The journal cannot live with that: its directory, its header and its
    // `run_id`s are all keyed by the session, and a resume looks the session up by name.
    //
    // `sessionIdentity()` honours an inherited MOTOKO_SESSION_ID, which is what the eval-harness
    // adapter sets and what a `--resume` of an existing session needs.
    MOTOKO_SESSION_ID: sessionIdentity(),
    // THE RESUME COUNT, D5 again: `0` on a fresh spawn, incremented on every `--resume` spawn. The
    // child reads it AMBIENTLY in `rpc.run_with_config` (`rpc.ail:217`) rather than through a
    // `ports.env_get`, because five DST fixtures pin the exact key set the policy init reads and a
    // sixth key would make all five red (PLAN-003 §0.8). It is the middle field of
    // `run_id = <session_id>.r<resume_count>.<run_ordinal>`.
    MOTOKO_RESUME_COUNT: String(sessionResumeCount()),
    // THE WORKDIR THE HEADER RECORDS, D5's canonical-workdir row (PLAN-003 P3 Part 5). The header
    // is written from this exact string (`index.ts`), while `--workdir` reaches the child in
    // `supervisorWorkdirArg`'s relative form — "." for the common case — so a child comparing its
    // flag with the header would refuse every ordinary resume. Forwarding the same string makes
    // the row compare like with like; the child reads it ambiently (`rpc.invoked_workdir`).
    //
    // NOT `MOTOKO_WORKDIR`, which is what this first shipped as (845239c) and what broke every
    // `Delegate`. Five extensions already read MOTOKO_WORKDIR with "." as the default (herdr,
    // omnigraph, exa-search, context-mode, ailang-docs); herdr derives its delegate and dagr
    // directories from it and checks them with `path_within(ctx.workdir, …)`, where `ctx.workdir`
    // is the relative `--workdir`. An absolute directory is never lexically under ".", so every
    // delegation was refused as "outside Motoko's filesystem sandbox" (measured live 2026-09-12).
    // A name of its own keeps D5's row and leaves the extensions where they were.
    MOTOKO_JOURNAL_WORKDIR: workdir,
    // WHERE THIS TURN'S EXIT ACTIONS GET PUBLISHED (ABI 7.0).
    //
    // The host names the file and the runtime reads the name — never the other way round, and
    // never both. A path derived on both sides of the language boundary is the MOT-118 shape this
    // project has already paid for twice; here the parent owns the session clock the name is keyed
    // by, so it owns the name.
    //
    // `rememberExitManifestPath` is what lets the exit handler find it: this process reads at exit
    // what its children wrote at every turn end.
    MOTOKO_EXIT_MANIFEST: exitManifestPathFor(workdir),
    AILANG_OLLAMA_MAX_TOKENS: process.env.AILANG_OLLAMA_MAX_TOKENS ?? "",
    AILANG_OLLAMA_HTTP_TIMEOUT_SEC: process.env.AILANG_OLLAMA_HTTP_TIMEOUT_SEC ?? "",
    MOTOKO_COST_INPUT_PER_1M_MILLICENTS:
      process.env.MOTOKO_COST_INPUT_PER_1M_MILLICENTS ?? "",
    MOTOKO_COST_OUTPUT_PER_1M_MILLICENTS:
      process.env.MOTOKO_COST_OUTPUT_PER_1M_MILLICENTS ?? "",
  };
  // Egress proxy environment, forwarded only when actually present.
  //
  // The agent container sits on an `internal: true` docker network with no
  // NAT and no external DNS — a squid sidecar is the single exit, addressed
  // through HTTP_PROXY/HTTPS_PROXY/NO_PROXY. `buildChildEnv` is an explicit
  // allowlist, so without these lines the AILANG runtime child never sees the
  // proxy, dials the provider host directly, and every step dies on
  // `lookup openrouter.ai on 127.0.0.11:53: server misbehaving`. Measured
  // 2026-08-23: 134 consecutive stream_error_retry, zero bytes on the wire.
  for (const key of [
    "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY",
    "http_proxy", "https_proxy", "no_proxy",
  ]) {
    const value = process.env[key];
    if (value && value.trim() !== "") {
      childEnv[key] = value;
    }
  }
  // The herdr pane environment, forwarded only when it is actually present.
  //
  // WHY THIS IS NEEDED AT ALL, because the obvious reading of 021 §4.4 is
  // wrong: `motoko-ext-herdr` gates itself on HERDR_ENV / HERDR_BIN_PATH /
  // HERDR_PANE_ID read through `std/env` inside `register_with_config`. But
  // that runs in the AILANG runtime, which is a GRANDCHILD of the pane — the
  // pane starts this TUI, and this function decides what the TUI's own child
  // sees. `buildChildEnv` is an explicit allowlist, so without these three
  // lines the variables are dropped, the gate correctly closes, and the
  // extension silently advertises no tools INSIDE a herdr pane. Measured
  // 2026-08-23: the extension loaded and offered nothing, and the model
  // reported that Delegate did not exist.
  //
  // THE WHOLE HERDR_ PREFIX, not a named list — corrected 2026-08-23 after
  // enumerating bit twice. The first version forwarded exactly HERDR_ENV,
  // HERDR_BIN_PATH and HERDR_PANE_ID, which made the gate work and silently
  // left every one of the extension's operator knobs unreachable:
  // HERDR_ALLOWED_KINDS, HERDR_DELEGATE_KIND, HERDR_DELEGATE_DIR,
  // HERDR_START_TIMEOUT_MS, HERDR_CHECK_WAIT_MS, HERDR_MAX_OUTPUT_CHARS. The
  // operator could set them and nothing happened — measured, with
  // HERDR_ALLOWED_KINDS=claude,codex still refusing codex.
  //
  // A prefix is still bounded: herdr injects HERDR_* into the pane and the
  // extension reads HERDR_*, so the family is the unit. Enumerating members of
  // a family that grows is the fragility, not the allowlist itself.
  for (const [key, value] of Object.entries(process.env)) {
    if (key.startsWith("HERDR_") && value) {
      childEnv[key] = value;
    }
  }
  if (process.env.AILANG_STDLIB_PATH) {
    childEnv.AILANG_STDLIB_PATH = process.env.AILANG_STDLIB_PATH;
  }
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
  if (openaiBaseUrl.trim() !== "") childEnv.OPENAI_BASE_URL = openaiBaseUrl;
  if (aiOptionsJson.trim() !== "") childEnv.MOTOKO_AI_OPTIONS_JSON = aiOptionsJson;
  return childEnv;
}

/**
 * ADR-003 v6.1 D6's `--resume` (PLAN-003 P3 Part 5): the journal a respawned child folds, and
 * `--resume-force`, which overrides the extension-set and prompt compatibility rows and neither
 * the workdir nor the lease.
 */
export interface ResumeSpawn {
  journalPath: string;
  force?: boolean;
}

export function buildSupervisorArgs(
  resolvedProfile: string,
  model: string,
  workdir: string,
  port: number,
  systemPrompt: string,
  task: string,
  resume?: ResumeSpawn,
): string[] {
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
  // BEFORE the task, which stays last: `config.parse_cli_args` reads the final positional as the
  // task, and `--resume-force` is a BARE flag there precisely so it cannot eat it.
  if (resume && resume.journalPath.trim() !== "") {
    supervisorArgs.push("--resume", resume.journalPath);
    if (resume.force) supervisorArgs.push("--resume-force");
  }
  supervisorArgs.push(task);
  return supervisorArgs;
}

/**
 * PLAN-003 P4 Part 4 (ADR-003 D7): the host-lifetime owner of a park whose child has exited.
 *
 * Under `--park-exits` the child is ended on its first `wake_request`, once the `park` entry is on
 * disk (P4-Q3). The park outlives the child: the exit handler hands the outstanding request and the
 * RUNNING waiter here instead of cancelling them, and the TTY exit callback writes no `exit` entry,
 * so the journal's leaf stays the `park` — which is what lets the `wake` be written as its child
 * (row 6: `parent_id` is the leaf, and no operation moves it).
 *
 * The owner outlives the `RuntimeProcess` that made it. It holds ONE reply, by `request_id` —
 * `sendWakeReply`'s late-and-duplicate rule, moved here with the request — and hands it to the
 * consumer Part 5 installs (the `wake` entry, the `--resume` respawn). Until then the reply is
 * held, not lost.
 */
export class SuspendedChild {
  private held: WakeReply | null = null;
  private consumer: ((reply: WakeReply) => void) | null = null;
  private closed = false;

  constructor(
    /** The request whose `park` entry is the journal's leaf. */
    readonly request: WakeRequest,
    /** The waiter, still running: its reply is one of the things that wakes the session. */
    readonly waiter: WakeWaiterHandle,
  ) {}

  /** The reply accepted so far, or null. */
  get reply(): WakeReply | null {
    return this.held;
  }

  /**
   * Accept one reply for this request. A reply for another request, or a second one, is dropped —
   * and so is any reply after `close()`: the park was cancelled from the host's side.
   */
  deliver(reply: WakeReply): boolean {
    if (this.closed || this.held !== null || reply.request_id !== this.request.request_id) return false;
    this.held = reply;
    this.consumer?.(reply);
    return true;
  }

  /** True once `close()` cancelled the park: no reply is accepted after it. */
  get isClosed(): boolean {
    return this.closed;
  }

  /**
   * PLAN-003 P4 Part 6: END THE PARK FROM THE HOST'S SIDE — the ESC, `restart`, quit and host-death
   * rows. Stops the waiter (the delegates are no longer observed for this request; a resumed run
   * parks on them again with a waiter of its own) and refuses every later reply. Returns false, and
   * does nothing, when the owner already accepted a reply — the park is answered, and Part 5's
   * consumer owns what follows — or was already closed. Cancelling a waiter twice is harmless
   * (`startWakeWaiter`'s cancel is idempotent), so the returned value is about the PARK, not the waiter.
   */
  close(): boolean {
    if (this.closed || this.held !== null) return false;
    this.closed = true;
    this.waiter.cancel();
    return true;
  }

  /** Install the consumer (Part 5). A reply held before it was installed is handed over at once. */
  onReply(consumer: (reply: WakeReply) => void): void {
    this.consumer = consumer;
    if (this.held !== null) consumer(this.held);
  }
}

/**
 * What the suspended-child wake writes through: `SessionJournal.record`, narrowed to its shape.
 * `record` routes a `wake_received` to Part 1's `wake` entry and returns the number of entries it
 * appended — one, or zero when the append failed and `onError` has already said so.
 */
export interface WakeJournal {
  record(event: Record<string, unknown>): number;
}

/** PLAN-003 P4 Part 5: what the consumer of a suspended-child's reply needs from the host. */
export interface SuspendedWakeDeps {
  /**
   * True while the owner is still the session's suspended-child. A later spawn ends that (index.ts
   * clears `suspendedChild` on every spawn), and a reply that arrives after it is LATE: a `wake`
   * written then would follow the new child's entries — a wake answering no open park, which the
   * fold refuses at `request_id` — so nothing is written and nothing respawned.
   */
  stillCurrent: () => boolean;
  journal: WakeJournal;
  /**
   * index.ts's `respawnForRestart` (PLAN-003 P3 Part 5): it checks `canResume`, bumps the resume
   * count, and spawns with `--resume <journal>`. Called AFTER the `wake` is on disk, so the child
   * folds `Parked(p, Some(w))` and the resumer (Part 3) consumes the wake as `<R'>.p0`.
   */
  respawn: () => void;
  /** Told the reply and whether its `wake` entry was written, before the respawn. */
  notify?: (reply: WakeReply, written: boolean) => void;
}

/**
 * PLAN-003 P4 Part 5 (ADR-003 D7, row 6): THE WAKE ENTRY AS THE PARK'S CHILD, AND THE RESPAWN.
 *
 * Installs the owner's consumer (the attachment point Part 4 left, `SuspendedChild.onReply`). On
 * the one reply the owner accepts — the waiter's outcome, or the operator's line from the parked
 * input route — the host:
 *
 *   1. records `{ type: "wake_received", request_id, wait_id, outcome, detail }`. Part 1's routing
 *      appends a `wake` whose `parent_id` is the journal's leaf, and the leaf IS the `park`: the
 *      suspended-child branch wrote no `exit` after it (row 6), and no operation moves the leaf;
 *   2. respawns through `respawnForRestart`, which passes `--resume <journal>`.
 *
 * Late and duplicate replies are dropped by `request_id`. That is `sendWakeReply`'s rule, and it
 * moved with the request to the owner: `SuspendedChild.deliver` accepts one reply for its request
 * and no other, so this consumer runs at most once. A reply held before the consumer was installed
 * is handed over at install, and consumed the same way.
 *
 * The waiter is stopped on consumption, as `sendWakeReply` stops it on a live child: the park is
 * answered, and the resumed run parks on its delegates again — `.p1` onward — with a waiter of its
 * own. Cancel is idempotent on a waiter that has already delivered (`startWakeWaiter`'s `flush`
 * cancels before `onReady`).
 *
 * A `wake` the journal could not append (`record` returned 0; `onError` reported it) still
 * respawns: the resumed child then folds `Parked(p, None)` and re-observes the park (row 5) — the
 * reply is lost, the session is not.
 */
export function installSuspendedWake(owner: SuspendedChild, deps: SuspendedWakeDeps): void {
  owner.onReply((reply) => {
    if (!deps.stillCurrent()) return;
    owner.waiter.cancel();
    const written =
      deps.journal.record({
        type: "wake_received",
        request_id: reply.request_id,
        wait_id: reply.wait_id,
        outcome: reply.outcome,
        detail: reply.detail,
      }) === 1;
    deps.notify?.(reply, written);
    deps.respawn();
  });
}

/**
 * PLAN-003 P4 Part 6 (ADR-003 D7, row 4): THE NAMED STATES OF A DURABLE PARK, AND THEIR EXITS.
 *
 * v4.1's D7 named these states and is not in the tree; this table is transcribed from its reviews
 * (REVIEW-adr003-verdicts-fable.md §8, REVIEW-adr003-v3-verdicts-fable.md:94–96) and from W4 Part 5's
 * command table (PLAN-002 §8.7), and signed off as P4-Q5. The TUI shows the same three names in its
 * footer (`RunState`: `parked`, `suspended_child`, `resuming`; ui.ts) and reports them to herdr.
 *
 * | state             | entered on                                        | left on                                                            | journal            | then       |
 * |-------------------|---------------------------------------------------|--------------------------------------------------------------------|--------------------|------------|
 * | `parked`          | `wake_request` while the child is alive           | `wake_received`; a park-ending event (`PARK_ENDING_EVENTS`); exit  | the child's events | —          |
 * | `suspended-child` | the exit handler's first branch (Part 4)          | a waiter reply; operator input; ESC; `restart`; quit; host death   | nothing on entry   | per row    |
 * | `resuming`        | a `wake` entry is written (Part 5)                | the resumed child's `session_resumed`                              | `wake`             | `--resume` |
 *
 * While `suspended-child` (P4-Q5, the dead-child column of W4 Part 5's table):
 *
 * | command                                                  | wake written                          | then                                                                                    |
 * |----------------------------------------------------------|---------------------------------------|-----------------------------------------------------------------------------------------|
 * | the waiter replies `settled`/`lost`/`timed_out`/`host_error` | that outcome (`installSuspendedWake`) | respawn with `--resume` (Part 5)                                                    |
 * | operator input, the parked input route                   | `operator_input(content)`             | respawn (Part 5)                                                                        |
 * | ESC (`interruptRuntime`)                                 | `aborted`, `wait_id "abort"`          | NO respawn; the TUI awaits a task; the next prompt resumes through `onInitialTask` into `Open("wake:aborted")` |
 * | `restart` (profile p)                                    | `aborted`, `wait_id "restart:<p>"`    | respawn with the new profile (`--resume`); the child opens no run and idles on stdin    |
 * | quit (Ctrl+C)                                            | NONE                                  | the lease hook writes `exit(host_exit)`; the exit actions run; a later resume re-observes the park, and wakes `lost` if the delegates were reaped |
 * | host death (SIGINT / SIGTERM)                            | NONE                                  | the lease hook writes `exit(abort)` / `exit(host_exit)`; as quit                       |
 *
 * The two typed-input rows differ by entry condition alone: a line at the parked prompt answers the
 * park (`operator_input`, then respawn); ESC cancels it (`aborted`, no respawn). And the dead-child
 * quit differs from the live-child one: `exit` sent to a LIVE parked child is an `Aborted` cancel
 * (W4 Part 5), while quitting during suspended-child writes no wake at all — the park stays open in
 * the journal for the resume to re-observe (row 5), which is what lets a delegate that answered
 * meanwhile still be collected.
 */
export type SuspendedChildAbort = "abort" | `restart:${string}`;

/**
 * The suspended-child's CANCELLING exits — the ESC row (`wait_id "abort"`) and the `restart` row
 * (`wait_id "restart:<p>"`). Sent to a LIVE parked child these commands come back on the wire as
 * `WakeReceived(Aborted)` with the command in the wake's free `wait_id`; here the child is gone, so
 * the host writes that same wake itself, as the park's child (row 6: the leaf is still the `park`).
 * The fold closes the park on it — `park, wake(aborted)` → `Open("wake:aborted")` (P4-Q4) — and the
 * resumed child opens no run: it is idle, between turns, reading stdin.
 *
 * Nothing is respawned HERE. The ESC row leaves the session for the operator's next prompt, which
 * `onInitialTask` turns into a `--resume` respawn; the `restart` row's caller respawns on the new
 * profile at once. Both first END the owner (`close()`: the waiter stopped, later replies refused),
 * and the caller clears its `suspendedChild` so Part 5's consumer is no longer current.
 *
 * Returns whether the `wake(aborted)` is on disk: false when the owner had already accepted a
 * reply or was already closed (nothing written), or when the append failed (`onError` said so).
 * Quit and host death take neither of these rows: they write NO wake (P4-Q5) — the lease hook
 * writes the `exit`, and the park is re-observed on the next resume (row 5).
 */
export function abortSuspendedChild(owner: SuspendedChild, journal: WakeJournal, waitId: SuspendedChildAbort): boolean {
  if (!owner.close()) return false;
  return (
    journal.record({
      type: "wake_received",
      request_id: owner.request.request_id,
      wait_id: waitId,
      outcome: "aborted",
      detail: "",
    }) === 1
  );
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
    onExit: () => void,
    resume?: ResumeSpawn,
    wakeWaiterFactory: WakeWaiterFactory = defaultWakeWaiterFactory,
    parkExits = false,
  ) {
    this.workdir = workdir;
    this.onEvent = onEvent;
    this.wakeWaiterFactory = wakeWaiterFactory;
    this.parkExits = parkExits;
    const aiModelArg = providerSelectionModel(model, openaiBaseUrl);
    const ailangBin = (process.env.AILANG_BIN && process.env.AILANG_BIN.trim() !== "")
      ? process.env.AILANG_BIN
      : "ailang";
    const childEnv = buildChildEnv(workdir, profile, openaiBaseUrl, aiOptionsJson);

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

    const supervisorArgs = buildSupervisorArgs(resolvedProfile, model, workdir, port, systemPrompt, task, resume);

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
      // The LAST event, not any: a TTY runtime says `done` and then serves the next turn, and the
      // 2026-09-12 OOM kill landed 650 steps into such a session.
      this.exitExplained = EXIT_EXPLAINING_EVENTS.has(event.type);
      if (event.type === "wake_request") {
        this.onWakeRequest(event as WakeRequest);
        return;
      }
      const resolved =
        (event.type === "wake_received" && this.parkRequestId !== null && event.request_id === this.parkRequestId) ||
        (PARK_ENDING_EVENTS.has(event.type) && this.parkRequestId !== null);
      if (resolved) this.resolvePark();
      this.onEvent(event);
      if (resolved) this.flushDeferredModel();
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

    this.proc.on("exit", (code, signal) => {
      this.dead = true;
      stderrRl.close();
      if (this.suspending !== null && this.waiter !== null) {
        // PLAN-003 P4 Part 4 (ADR-003 D7): SUSPENDED-CHILD, the branch BEFORE `restartPending`. The
        // child was ended by `onWakeRequest` under `--park-exits`; its `park` entry is the journal's
        // leaf, and the park did NOT die with it. The request and the waiter — still running, not
        // cancelled — move to the host-lifetime owner the TTY exit callback takes (`suspendedChild`)
        // and on which it writes no `exit` (row 6: the `wake` must be the `park`'s child). What the
        // owner receives from here on is Part 5's.
        this._suspendedChild = new SuspendedChild(this.suspending, this.waiter);
        this.suspending = null;
        this.waiter = null;
        this.outstandingWake = null;
        this.parkRequestId = null;
      } else {
        // The runtime is gone: its park with it. Losing waiters are cancelled and a queued model
        // change is dropped (there is no child to send it to).
        this.resolvePark();
      }
      this.deferredModel = null;
      // A killed child cannot say it was killed, so the host says it — as an `error`, which is what
      // makes the TTY recover into awaiting a task and the headless loggers exit 1, where a silent
      // `onExit()` would have exited 0 as if the run had finished. A mid-park cancel (R3) ends with
      // neither `done` nor `error` on the wire, and is an exit the host asked for.
      const unexplained = this.exitExplained || this.killRequested || this.cancelRequested
        ? null
        : describeUnexplainedExit(code, signal);
      if (unexplained) this.onEvent({ type: "error", message: unexplained });
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

  /**
   * True once the child has exited. The TUI pre-spawns a runtime at boot to warm
   * the AILANG module graph; the first-prompt path reads this to decide between
   * writing to that process and spawning a replacement.
   */
  get isDead(): boolean {
    return this.dead;
  }

  /** The AILANG child's pid while it is alive — the footer samples its memory (`process-memory.ts`). */
  get pid(): number | undefined {
    return this.dead ? undefined : this.proc.pid;
  }

  abort(): void {
    this.cancelPark();
    this.send({ type: "abort" });
  }

  /**
   * Quit a parked session over stdin (W4 Part 5): the core turns `exit` into `Aborted` and ends the
   * run with neither `done` nor `error`, then the child exits.
   */
  exit(): void {
    if (this.dead) return;
    this.cancelPark();
    this.send({ type: "exit" });
  }

  /** True while the last wire event (`done`, `error`, a resume refusal) already accounts for an exit. */
  private exitExplained = false;
  /** Set by `kill()`: a death the host asked for (quit, ESC) is not reported as one. */
  private killRequested = false;
  /**
   * Set by `abort()`, `exit()` and `restart()` while a park is open (PLAN-002 W4 Part 5, R3). A
   * cancelled park ends the run with no `done` and no `error`, so without this the child's exit
   * would be unexplained and a non-zero code would synthesize an `error` the host itself caused.
   */
  private cancelRequested = false;

  kill(): void {
    if (this.dead) return;
    this.killRequested = true;
    this.proc.kill("SIGTERM");
  }

  setModel(model: string): void {
    // The core drops `model_change` while parked (with a warning), so it waits for the park to resolve.
    if (this.parkRequestId !== null) {
      this.deferredModel = model;
      return;
    }
    this.send({ type: "model_change", model });
  }

  // ------------------------------------------------------------------------------------------------
  // Park and wake (ADR-002 D2, PLAN-002 W4 Part 5)
  // ------------------------------------------------------------------------------------------------

  private readonly wakeWaiterFactory: WakeWaiterFactory;
  /** The request awaiting a host reply; null once a reply is sent or the park ends. */
  private outstandingWake: WakeRequest | null = null;
  /** The park not yet resolved by the core (`wake_received`, a run end, or the child's exit). */
  private parkRequestId: string | null = null;
  private waiter: WakeWaiterHandle | null = null;
  private deferredModel: string | null = null;
  /**
   * PLAN-003 P4 Part 4: `--park-exits`. Off by default; on, a FIRST issue of a `wake_request` ends
   * the child (P4-Q3: `kill()` once the `park` entry is on disk; every first-issue park; TTY only —
   * the non-TTY spawn never passes it). With it off nothing in this part runs.
   */
  private readonly parkExits: boolean;
  /**
   * The request the child is dying on: set by `onWakeRequest` between its `kill()` and the exit.
   * A reply in that window is DROPPED (R5): it writes no `wake` and starts no respawn — the request
   * died with the child, and the park is re-observed on the next resume (row 5).
   */
  private suspending: WakeRequest | null = null;
  private _suspendedChild: SuspendedChild | null = null;

  /**
   * What the exit handler handed over, or null. The TTY exit callback reads this FIRST, above
   * `restartPending`: on it the callback writes no `exit` entry and keeps the session open.
   */
  get suspendedChild(): SuspendedChild | null {
    return this._suspendedChild;
  }

  /** The outstanding `wake_request`, or null. The TUI's parked input route reads this. */
  get wakeRequest(): WakeRequest | null {
    return this.outstandingWake;
  }

  /** True while a `wake_request` awaits a reply from the host. */
  get isParked(): boolean {
    return this.outstandingWake !== null;
  }

  private onWakeRequest(req: WakeRequest): void {
    const reissue = this.parkRequestId === req.request_id;
    this.parkRequestId = req.request_id;
    if (reissue && this.outstandingWake !== null && this.waiter !== null && !this.waiter.finished) {
      // Same park, next attempt, observers still running: keep them, track the attempt.
      this.outstandingWake = req;
    } else {
      this.stopWaiter();
      this.outstandingWake = req;
      // Waiters report asynchronously, so none can reply before the event below is forwarded.
      if (!this.dead) this.waiter = this.wakeWaiterFactory(req, (reply) => this.onWaiterReply(reply));
    }
    // Forwarded LAST: a consumer that aborts from inside onEvent must find the park already tracked.
    this.onEvent(req);
    // PLAN-003 P4 Part 4 (P4-Q3): a first issue under `--park-exits` ends the child. The `park`
    // entry is already on disk — the child emits `park_entered` before `wake_request`
    // (`session.ail:3530`, then `stub_step.ail:220`) and the host appended it synchronously from the
    // line before this one. `kill()` sets `killRequested`, so the exit is not reported as an
    // `error`. Guarded on the park still being tracked: a consumer that aborted from inside onEvent
    // above has already cancelled it, and that exit is the ordinary one.
    if (this.parkExits && !reissue && this.outstandingWake === req && this.waiter !== null && !this.dead) {
      this.suspending = req;
      this.kill();
    }
  }

  /** The waiter's reply: down stdin while the child lives; to the owner after the exit; dropped between (R5). */
  private onWaiterReply(reply: WakeReply): void {
    if (this._suspendedChild !== null) {
      this._suspendedChild.deliver(reply);
      return;
    }
    if (this.suspending !== null) return;
    this.sendWakeReply(reply);
  }

  /**
   * Send one `wake_reply`. Dropped — never sent — when no request is outstanding or its `request_id`
   * is not the outstanding one (a late reply). Returns whether it was sent.
   */
  sendWakeReply(reply: WakeReply): boolean {
    if (this.dead) return false;
    // P4 Part 4, R5: between `kill()` and the exit the request is dying with the child. Nothing is
    // sent and nothing is written; the owner (`suspendedChild`) receives replies only after the exit.
    if (this.suspending !== null) return false;
    const req = this.outstandingWake;
    if (req === null || reply.request_id !== req.request_id) return false;
    this.outstandingWake = null;
    this.stopWaiter();
    this.send({
      type: "wake_reply",
      request_id: reply.request_id,
      wait_id: reply.wait_id,
      outcome: reply.outcome,
      detail: reply.detail,
    });
    return true;
  }

  private stopWaiter(): void {
    const w = this.waiter;
    this.waiter = null;
    w?.cancel();
  }

  /** The park ended on the wire or with the child. */
  private resolvePark(): void {
    this.outstandingWake = null;
    this.parkRequestId = null;
    this.stopWaiter();
  }

  /** A cancelling command is about to go down stdin. */
  private cancelPark(): void {
    if (this.parkRequestId === null && this.outstandingWake === null) return;
    this.cancelRequested = true;
    this.outstandingWake = null;
    this.stopWaiter();
  }

  private flushDeferredModel(): void {
    const model = this.deferredModel;
    if (model === null || this.parkRequestId !== null) return;
    this.deferredModel = null;
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
    this.cancelPark();
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
