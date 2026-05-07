// tui/src/env-server.ts
//
// Embedded environment server. Runs inside the TypeScript process.
// The AILANG runtime process calls this over HTTP to execute shell commands, take
// snapshots of the working tree, and restore them.
//
// All endpoints return 200 with a JSON body regardless of command outcome —
// the exit_code field communicates failure. This keeps the runtime process's
// env_client.ail simple (no HTTP error handling needed).

import express from "express";
import { execSync, spawn } from "child_process";
import { randomBytes } from "crypto";
import { mkdirSync, writeFileSync, unlinkSync, rmSync } from "fs";
import { join, resolve } from "path";
import { fileURLToPath } from "url";
import { createClaimCheckTelemetry, runClaimCheck } from "./compose-claimcheck.js";

export interface ExecResult {
  stdout: string;
  stderr: string;
  exit_code: number;
}

export interface AilangExecResult extends ExecResult {
  check_passed: boolean;
  check_errors: string;
}

export type ComposeIntentKind = "analyze" | "list" | "transform" | "compute" | "fetch" | "summarize";

export type ExpectedOutputSpec =
  | { kind: "non_empty" }
  | { kind: "contains_all"; tokens: string[]; case_sensitive?: boolean }
  | { kind: "lines_regex"; pattern: string; flags?: string; min_lines?: number; max_lines?: number }
  | { kind: "certificate"; min_premises?: number; require_trace?: boolean; require_conclusion?: boolean };

export type ExpectedOutputValidation = {
  decided: boolean;
  satisfied: boolean;
  confidence: "high" | "low";
  reason: string;
};

const ANALYZE_OR_SUMMARIZE = new Set<ComposeIntentKind>(["analyze", "summarize"]);

export function normalizeIntentKind(raw: string): ComposeIntentKind | null {
  const v = (raw ?? "").trim().toLowerCase();
  if (v === "analyze" || v === "list" || v === "transform" || v === "compute" || v === "fetch" || v === "summarize") {
    return v;
  }
  return null;
}

export function deriveIntentKind(intent: string): ComposeIntentKind {
  const i = (intent ?? "").toLowerCase();
  if (i.includes("summarize") || i.includes("summary") || i.includes("tldr") || i.includes("overview")) return "summarize";
  if (
    i.includes("reason about") ||
    i.includes("analy") ||
    i.includes("architect") ||
    i.includes("trace") ||
    i.includes("understand") ||
    i.includes("inspect")
  ) return "analyze";
  if (i.includes("list ") || i.includes("enumerat") || i.includes("find files") || i.includes("show files")) return "list";
  if (i.includes("fetch") || i.includes("download") || i.includes("url") || i.includes("http") || i.includes("api")) return "fetch";
  if (i.includes("transform") || i.includes("rewrite") || i.includes("convert") || i.includes("normalize") || i.includes("format")) {
    return "transform";
  }
  return "compute";
}

export function parseDeclaredEffects(snippet: string): Set<string> {
  const m = (snippet ?? "").match(/export\s+func\s+main[\s\S]*?!\s*\{([^}]*)\}/m);
  if (!m) return new Set<string>();
  const raw = m[1] ?? "";
  return new Set(
    raw
      .split(",")
      .map((x) => x.trim())
      .filter((x) => /^[A-Za-z][A-Za-z0-9_]*$/.test(x))
  );
}

export function composeSnippetGuard(_intent: string, snippet: string, intentKind: ComposeIntentKind): string {
  const modeRaw = String(process.env.AILANG_COMPOSE_EFFECT_GUARD ?? "1").trim().toLowerCase();
  if (modeRaw === "0") return "";

  const s = (snippet ?? "").toLowerCase();
  const markers = [
    "simulated analysis",
    "in a real execution",
    "would read files",
    "based on structural inspection",
    "hypothetical",
  ];
  if (markers.some((m) => s.includes(m))) {
    return "compose guard: fabricated-analysis marker detected";
  }

  if (!ANALYZE_OR_SUMMARIZE.has(intentKind)) return "";

  if (modeRaw === "legacy") {
    const hasReadEvidence = s.includes("readfile(") || s.includes("exec(");
    if (!hasReadEvidence) return "compose guard: analysis intent requires evidence reads (missing readFile/exec usage)";
    return "";
  }

  const declaredEffects = parseDeclaredEffects(snippet);
  if (!declaredEffects.has("FS") && !declaredEffects.has("Process")) {
    return "compose guard: analysis intent requires FS or Process effect";
  }
  return "";
}

function parseExpectedOutputSpec(raw: string): ExpectedOutputSpec | null {
  const text = (raw ?? "").trim();
  if (!text) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  const rec = parsed as Record<string, unknown>;
  if (rec.kind === "non_empty") return { kind: "non_empty" };
  if (rec.kind === "contains_all") {
    const tokensRaw = rec.tokens;
    if (!Array.isArray(tokensRaw)) return null;
    const tokens = tokensRaw.map((x) => String(x)).filter((x) => x.trim() !== "");
    return { kind: "contains_all", tokens, case_sensitive: rec.case_sensitive === true };
  }
  if (rec.kind === "lines_regex") {
    const pattern = typeof rec.pattern === "string" ? rec.pattern : "";
    if (!pattern) return null;
    const flags = typeof rec.flags === "string" ? rec.flags : "";
    const min_lines = Number.isFinite(rec.min_lines) ? Number(rec.min_lines) : undefined;
    const max_lines = Number.isFinite(rec.max_lines) ? Number(rec.max_lines) : undefined;
    return { kind: "lines_regex", pattern, flags, min_lines, max_lines };
  }
  if (rec.kind === "certificate") {
    const min_premises = Number.isFinite(rec.min_premises) ? Number(rec.min_premises) : undefined;
    const require_trace = rec.require_trace === false ? false : true;
    const require_conclusion = rec.require_conclusion === false ? false : true;
    return { kind: "certificate", min_premises, require_trace, require_conclusion };
  }
  return null;
}

type ParsedCertificate = {
  premises: Array<{ path: string; text: string }>;
  trace: string;
  conclusion: string;
  hasPremises: boolean;
  hasTrace: boolean;
  hasConclusion: boolean;
  badPremiseLine?: string;
};

function parseCertificate(stdout: string): ParsedCertificate {
  const lines = (stdout ?? "").split(/\r?\n/);
  const sections: Record<"premises" | "trace" | "conclusion", string[]> = {
    premises: [],
    trace: [],
    conclusion: [],
  };
  let current: "premises" | "trace" | "conclusion" | null = null;
  let hasPremises = false;
  let hasTrace = false;
  let hasConclusion = false;

  for (const line of lines) {
    const t = line.trim();
    if (/^premises:?$/i.test(t)) {
      current = "premises";
      hasPremises = true;
      continue;
    }
    if (/^trace:?$/i.test(t)) {
      current = "trace";
      hasTrace = true;
      continue;
    }
    if (/^conclusion:?$/i.test(t)) {
      current = "conclusion";
      hasConclusion = true;
      continue;
    }
    if (current) sections[current].push(line);
  }

  const premises: Array<{ path: string; text: string }> = [];
  let badPremiseLine: string | undefined;
  for (const raw of sections.premises) {
    const line = raw.trim();
    if (line === "") continue;
    const asciiAt = line.indexOf("->");
    const unicodeAt = line.indexOf("→");
    let arrowAt = -1;
    let arrowLen = 0;
    if (asciiAt >= 0 && unicodeAt >= 0) {
      if (asciiAt <= unicodeAt) {
        arrowAt = asciiAt;
        arrowLen = 2;
      } else {
        arrowAt = unicodeAt;
        arrowLen = 1;
      }
    } else if (asciiAt >= 0) {
      arrowAt = asciiAt;
      arrowLen = 2;
    } else if (unicodeAt >= 0) {
      arrowAt = unicodeAt;
      arrowLen = 1;
    }
    if (arrowAt < 0) {
      badPremiseLine = line;
      break;
    }
    const path = line.slice(0, arrowAt).trim();
    const text = line.slice(arrowAt + arrowLen).trim();
    if (path === "" || text === "") {
      badPremiseLine = line;
      break;
    }
    premises.push({ path, text });
  }

  return {
    premises,
    trace: sections.trace.join("\n").trim(),
    conclusion: sections.conclusion.join("\n").trim(),
    hasPremises,
    hasTrace,
    hasConclusion,
    badPremiseLine,
  };
}

export function validateExpectedOutput(rawExpectedOutput: string, stdout: string): ExpectedOutputValidation {
  const spec = parseExpectedOutputSpec(rawExpectedOutput);
  if (!rawExpectedOutput || rawExpectedOutput.trim() === "") {
    return { decided: false, satisfied: true, confidence: "low", reason: "no expected_output provided" };
  }
  if (!spec) {
    return {
      decided: false,
      satisfied: true,
      confidence: "low",
      reason: "expected_output is free-text; no deterministic validator applied",
    };
  }

  if (spec.kind === "non_empty") {
    const ok = stdout.trim() !== "";
    return {
      decided: true,
      satisfied: ok,
      confidence: "high",
      reason: ok ? "stdout is non-empty" : "stdout is empty",
    };
  }

  if (spec.kind === "contains_all") {
    const hay = spec.case_sensitive ? stdout : stdout.toLowerCase();
    const missing: string[] = [];
    for (const token of spec.tokens) {
      const needle = spec.case_sensitive ? token : token.toLowerCase();
      if (!hay.includes(needle)) missing.push(token);
    }
    return {
      decided: true,
      satisfied: missing.length === 0,
      confidence: "high",
      reason: missing.length === 0 ? "all expected tokens found" : `missing expected tokens: ${missing.join(", ")}`,
    };
  }

  if (spec.kind === "certificate") {
    const minPremises = typeof spec.min_premises === "number" ? spec.min_premises : 1;
    if (!Number.isFinite(minPremises) || minPremises < 1) {
      return {
        decided: false,
        satisfied: true,
        confidence: "low",
        reason: "invalid certificate spec: min_premises must be >= 1",
      };
    }
    const requireTrace = spec.require_trace !== false;
    const requireConclusion = spec.require_conclusion !== false;
    const parsed = parseCertificate(stdout);
    if (!parsed.hasPremises) {
      return { decided: true, satisfied: false, confidence: "high", reason: "certificate missing PREMISES section" };
    }
    if (requireTrace && !parsed.hasTrace) {
      return { decided: true, satisfied: false, confidence: "high", reason: "certificate missing TRACE section" };
    }
    if (requireConclusion && !parsed.hasConclusion) {
      return { decided: true, satisfied: false, confidence: "high", reason: "certificate missing CONCLUSION section" };
    }
    if (parsed.badPremiseLine) {
      return {
        decided: true,
        satisfied: false,
        confidence: "high",
        reason: `certificate premise line must be '<path> -> <text>' or '<path> → <text>': ${parsed.badPremiseLine}`,
      };
    }
    if (parsed.premises.length < minPremises) {
      return {
        decided: true,
        satisfied: false,
        confidence: "high",
        reason: `certificate has ${parsed.premises.length} premises; requires at least ${minPremises}`,
      };
    }
    if (requireTrace && parsed.trace === "") {
      return { decided: true, satisfied: false, confidence: "high", reason: "certificate TRACE section is empty" };
    }
    if (requireConclusion && parsed.conclusion === "") {
      return { decided: true, satisfied: false, confidence: "high", reason: "certificate CONCLUSION section is empty" };
    }
    return {
      decided: true,
      satisfied: true,
      confidence: "high",
      reason: "certificate structure satisfied",
    };
  }

  const lines = stdout.split("\n").filter((l) => l.length > 0);
  if (typeof spec.min_lines === "number" && lines.length < spec.min_lines) {
    return {
      decided: true,
      satisfied: false,
      confidence: "high",
      reason: `line count ${lines.length} is below min_lines ${spec.min_lines}`,
    };
  }
  if (typeof spec.max_lines === "number" && lines.length > spec.max_lines) {
    return {
      decided: true,
      satisfied: false,
      confidence: "high",
      reason: `line count ${lines.length} exceeds max_lines ${spec.max_lines}`,
    };
  }
  let re: RegExp;
  try {
    re = new RegExp(spec.pattern, spec.flags ?? "");
  } catch (e: any) {
    return {
      decided: false,
      satisfied: true,
      confidence: "low",
      reason: `invalid regex in expected_output spec: ${String(e?.message ?? e)}`,
    };
  }
  const bad = lines.find((l) => !re.test(l));
  return {
    decided: true,
    satisfied: bad === undefined,
    confidence: "high",
    reason: bad === undefined ? "all lines satisfy regex" : `line failed regex: ${bad}`,
  };
}

function truncateUtf8ByBytes(s: string, maxBytes: number): string {
  const b = Buffer.from(s, "utf8");
  if (b.byteLength <= maxBytes) return s;
  return b.subarray(0, Math.max(0, maxBytes)).toString("utf8");
}

function classifyAilangError(errors: string): string {
  const e = errors.toLowerCase();
  if (e.includes("missing effect") || e.includes("effect checking")) return "effect";
  if (e.includes("expected next token") || e.includes("unexpected token")) return "parse";
  if (e.includes("undefined") || e.includes("not found")) return "import_or_symbol";
  if (e.includes("type mismatch") || e.includes("cannot unify")) return "type";
  return "other";
}

type ComposeRequest = {
  id: string;
  step?: number;
  intent: string;
  intent_kind?: string;
  trigger_prompt?: string;
  expected_output?: string;
  hints_read?: string[];
  hints_write?: string[];
  hints_avoid?: string[];
  caps?: string;
  model?: string;
  max_attempts?: number;
  system_prompt?: string;
};

export function startEnvServer(port: number, workdir: string): void {
  const app = express();
  app.use(express.json({ limit: "2mb" }));
  const tbExecProxy = (process.env.TB_EXEC_PROXY ?? "").trim();

  // snapshot_id -> git stash ref; populated by POST /snapshot
  const snapshots = new Map<string, string>();

  // Session-scoped result store directory
  const motokoStore = join(workdir, ".motoko-store");
  try { mkdirSync(motokoStore, { recursive: true }); } catch { /* ignore */ }

  // Temp directory for AILANG snippet execution
  const snippetDir = "/tmp/motoko-snippets/tmp";
  try { mkdirSync(snippetDir, { recursive: true }); } catch { /* ignore */ }

  // Permanent store for snippets — in the agent repo's src/snippets/ so they
  // can be used for fine-tuning analysis.  Derived from this file's location:
  //   tui/dist/env-server.js  →  ../../src/snippets
  const agentRoot = resolve(fileURLToPath(new URL(".", import.meta.url)), "../..");
  const permanentSnippetDir = join(agentRoot, "src", "snippets");
  try { mkdirSync(permanentSnippetDir, { recursive: true }); } catch { /* ignore */ }

  // Track snippet counter for unique filenames
  let snippetCounter = 0;

  function stripModuleDecl(code: string): string {
    return code
      .split("\n")
      .filter((line) => !line.trim().startsWith("module "))
      .join("\n");
  }

  function makeSnippetFile(code: string): { snippetName: string; snippetPath: string; cleanCode: string } {
    snippetCounter++;
    const snippetName = `snippet_${snippetCounter}_${Date.now()}`;
    const snippetPath = join(snippetDir, `${snippetName}.ail`);
    const cleanCode = stripModuleDecl(code);
    const fullCode = `module tmp/${snippetName}\n\n${cleanCode}`;
    writeFileSync(snippetPath, fullCode, "utf8");
    return { snippetName, snippetPath, cleanCode };
  }

  function runAilangCheck(snippetPath: string): { ok: true } | { ok: false; errors: string; exit_code: number } {
    try {
      execSync(`ailang check ${snippetPath}`, {
        cwd: workdir,
        timeout: 10_000,
        encoding: "utf8",
        maxBuffer: 1 * 1024 * 1024,
      });
      return { ok: true };
    } catch (e: any) {
      return {
        ok: false,
        errors: String(e.stderr ?? e.stdout ?? e.message).slice(0, 4000),
        exit_code: typeof e.status === "number" ? e.status : 1,
      };
    }
  }

  function runAilangSnippet(
    snippetPath: string,
    caps: string,
    timeout: number,
  ): { stdout: string; stderr: string; exit_code: number; truncated: boolean; raw_stdout: string } {
    try {
      const stdoutRaw = execSync(
        `ailang run --caps ${caps} --entry main ${snippetPath}`,
        {
          cwd: workdir,
          timeout: timeout * 1000,
          encoding: "utf8",
          maxBuffer: 8 * 1024 * 1024,
          env: {
            ...process.env,
            AILANG_FS_SANDBOX: workdir,
          },
        }
      );
      const stdout = stdoutRaw.slice(0, 8000);
      return { stdout, stderr: "", exit_code: 0, truncated: stdoutRaw.length > stdout.length, raw_stdout: stdoutRaw };
    } catch (e: any) {
      const stdoutRaw = String(e.stdout ?? "");
      const stderrRaw = String(e.stderr ?? "");
      const stdout = stdoutRaw.slice(0, 8000);
      const stderr = stderrRaw.slice(0, 2000);
      return {
        stdout,
        stderr,
        exit_code: typeof e.status === "number" ? e.status : 1,
        truncated: stdoutRaw.length > stdout.length || stderrRaw.length > stderr.length,
        raw_stdout: stdoutRaw,
      };
    }
  }

  function stripCodeFenceDelimiters(text: string): string {
    return text.replace(/^```[^\n]*\n?/, "").replace(/\n?```$/, "").trim();
  }

  function looksLikeAilangSnippet(text: string): boolean {
    const t = text.trim();
    if (t === "") return false;
    if (/\bexport\s+func\s+main\b/.test(t)) return true;
    const hasImport = /(^|\n)\s*import\s+\S+\s*\(/.test(t);
    const hasCodeSignal =
      /(^|\n)\s*(module\s+\S+|let\s+\w+\s*=|match\s+|if\s+.+\s+then\s+.+\s+else\s+.+|println\s*\(|readFile\s*\(|listDir\s*\()/m.test(t);
    return hasImport && hasCodeSignal;
  }

  function extractAilangFence(text: string): string {
    const raw = (text ?? "").trim();
    if (!raw) return "";

    const ailangFence = raw.match(/```(?:\s*ailang)\s*\n?([\s\S]*?)```/i);
    if (ailangFence && ailangFence[1]) return ailangFence[1].trim();

    const genericFence = raw.match(/```[^\n]*\n?([\s\S]*?)```/);
    if (genericFence && genericFence[1] && looksLikeAilangSnippet(genericFence[1])) {
      return stripCodeFenceDelimiters(genericFence[0]);
    }

    const mainAt = raw.search(/\bexport\s+func\s+main\b/);
    if (mainAt >= 0) {
      let start = mainAt;
      const before = raw.slice(0, mainAt);
      const moduleStarts = [...before.matchAll(/(^|\n)\s*module\s+\S+/g)];
      const importStarts = [...before.matchAll(/(^|\n)\s*import\s+\S+\s*\(/g)];
      const bestModule = moduleStarts.length > 0 ? (moduleStarts[moduleStarts.length - 1].index ?? -1) : -1;
      const bestImport = importStarts.length > 0 ? (importStarts[0].index ?? -1) : -1;
      if (bestModule >= 0) start = bestModule;
      else if (bestImport >= 0) start = bestImport;
      const tail = raw.slice(start);
      const lastBrace = tail.lastIndexOf("}");
      const candidate = (lastBrace >= 0 ? tail.slice(0, lastBrace + 1) : tail).trim();
      if (looksLikeAilangSnippet(candidate)) return candidate;
    }

    if (looksLikeAilangSnippet(raw)) return raw;
    return "";
  }

  function sanitizeSubagentOutput(text: string): string {
    const lines = text.split("\n");
    const kept = lines.filter((line) => {
      const t = line.trim();
      if (t.startsWith("WARNING MOD010")) return false;
      if (t.startsWith("Auto-relaxed for temporary directory")) return false;
      return true;
    });
    return kept.join("\n").trim();
  }

  function ailangTargetedHint(errors: string): string {
    const e = errors.toLowerCase();
    if (e.includes("missing ```ailang fence") || e.includes("empty snippet returned by subagent")) {
      return "Hint: return code only. Emit one complete snippet containing export func main() and no prose before/after.";
    }
    if (e.includes("compose guard:")) {
      return "Hint: do not fabricate analysis. Read real files with readFile(...) and derive findings from observed content only.";
    }
    if (e.includes("missing effect") || e.includes("effect checking")) {
      return "Hint: add missing effects in main signature, usually ! {IO, FS}.";
    }
    if (e.includes("=>") || e.includes("expected next token")) {
      return "Hint: AILANG uses match arms with => and lambdas as \\x. expr, not (x) => expr.";
    }
    if (e.includes("then") || e.includes("got {")) {
      return "Hint: if syntax is `if cond then a else b` with no braces or parentheses.";
    }
    if (e.includes("unexpected token") && e.includes(";")) {
      return "Hint: do not end import lines with semicolons.";
    }
    if (e.includes("undefined") || e.includes("not found")) {
      return "Hint: import every used function explicitly from std/* modules.";
    }
    return "Hint: emit a complete fresh snippet that strictly follows the AILANG skeleton and syntax rules.";
  }

  function capsMinusAvoid(baseCaps: string, avoid: string[]): string {
    const deny = new Set((avoid ?? []).map((x) => String(x).trim()).filter(Boolean));
    const parts = baseCaps.split(",").map((x) => x.trim()).filter(Boolean);
    return parts.filter((p) => !deny.has(p)).join(",");
  }

  function callSubagentModel(model: string, prompt: string, timeoutMs = 45_000): string {
    snippetCounter++;
    const name = `subagent_${snippetCounter}_${Date.now()}`;
    const path = join(snippetDir, `${name}.ail`);
    const code = [
      `module tmp/${name}`,
      "",
      "import std/ai (call)",
      "import std/io (println)",
      "import std/env (getEnvOr)",
      "",
      "export func main() -> () ! {IO, AI, Env} {",
      "  let prompt = getEnvOr(\"MOTOKO_SUBAGENT_PROMPT\", \"\");",
      "  println(call(prompt))",
      "}",
      "",
    ].join("\n");
    writeFileSync(path, code, "utf8");
    try {
      return String(
        execSync(`ailang run --caps IO,AI,Env --ai ${model} --entry main ${path}`, {
          cwd: workdir,
          timeout: timeoutMs,
          encoding: "utf8",
          maxBuffer: 4 * 1024 * 1024,
          env: { ...process.env, MOTOKO_SUBAGENT_PROMPT: prompt },
        })
      ).trim();
    } finally {
      try { unlinkSync(path); } catch { /* ignore */ }
    }
  }

  type StreamAuthorResult = {
    output: string;
    streamed: boolean;
  };

  function compactErr(err: unknown, maxLen = 320): string {
    const msg = String((err as any)?.message ?? err ?? "").trim().replace(/\s+/g, " ");
    return msg.length > maxLen ? `${msg.slice(0, maxLen)}...` : msg;
  }

  function callSubagentModelStream(
    model: string,
    prompt: string,
    onDelta: (delta: string) => void,
    timeoutMs = 45_000,
  ): Promise<StreamAuthorResult> {
    snippetCounter++;
    const name = `subagent_stream_${snippetCounter}_${Date.now()}`;
    const path = join(snippetDir, `${name}.ail`);
    // AILANG v0.15.1 migration: previously this template imported
    // `std/ai_motoko.callStreamResult` (fork-only API). Upstream replaces
    // it with `std/ai/streaming.callStream` which routes through the
    // [[ai_provider]] block named "motoko-or" in the project's ailang.toml.
    // The generated subagent runs from a temp dir so it cannot import
    // motoko_agent's src/core/ai_compat shim — it talks to upstream
    // callStream directly and constructs the OpenAI-shape messages JSON
    // inline.
    const code = [
      `module tmp/${name}`,
      "",
      "import std/ai/streaming (callStream)",
      "import std/io (println)",
      "import std/env (getEnvOr)",
      "import std/json (encode, jo, ja, kv, js, jb)",
      "import std/result (Ok, Err)",
      "",
      "export func main() -> () ! {IO, AI, Stream, Net, Env} {",
      "  let prompt = getEnvOr(\"MOTOKO_SUBAGENT_PROMPT\", \"\");",
      "  let model = getEnvOr(\"MOTOKO_SUBAGENT_MODEL\", \"\");",
      "  let streamId = getEnvOr(\"MOTOKO_SUBAGENT_STREAM_ID\", \"compose-author\");",
      "  let userMsg = jo([kv(\"role\", js(\"user\")), kv(\"content\", js(prompt))]);",
      "  let messages = encode(ja([userMsg]));",
      "  match callStream(\"motoko-or\", model, messages) {",
      "    Ok(text) => println(\"__SUBAGENT_RESULT_JSON__${encode(jo([",
      "      kv(\"ok\", jb(true)),",
      "      kv(\"output\", js(text)),",
      "      kv(\"error_message\", js(\"\"))",
      "    ]))}\"),",
      "    Err(e) => println(\"__SUBAGENT_RESULT_JSON__${encode(jo([",
      "      kv(\"ok\", jb(false)),",
      "      kv(\"output\", js(\"\")),",
      "      kv(\"error_message\", js(e.message))",
      "    ]))}\")",
      "  }",
      "}",
      "",
    ].join("\n");
    writeFileSync(path, code, "utf8");
    const streamId = `compose-author-${Date.now()}-${Math.floor(Math.random() * 1_000_000)}`;

    return new Promise<StreamAuthorResult>((resolve, reject) => {
      let timedOut = false;
      let stdoutBuf = "";
      let stderrAll = "";
      let streamed = false;
      let deltaFallback = "";
      let finalResult: { ok: boolean; output: string; error_message: string } | null = null;

      const child = spawn(
        "ailang",
        ["run", "--caps", "IO,AI,Env", "--ai", model, "--entry", "main", path],
        {
          cwd: workdir,
          env: {
            ...process.env,
            MOTOKO_SUBAGENT_PROMPT: prompt,
            MOTOKO_SUBAGENT_MODEL: model,
            MOTOKO_SUBAGENT_STREAM_ID: streamId,
            MOTOKO_STREAM_EVENTS: "1",
          },
          stdio: ["ignore", "pipe", "pipe"],
        },
      );

      const finish = (err?: Error): void => {
        try { unlinkSync(path); } catch { /* ignore */ }
        if (err) reject(err);
      };

      const timer = setTimeout(() => {
        timedOut = true;
        try { child.kill("SIGKILL"); } catch { /* ignore */ }
      }, timeoutMs);

      const handleLine = (line: string): void => {
        if (!line) return;
        const marker = "__SUBAGENT_RESULT_JSON__";
        if (line.startsWith(marker)) {
          const payload = line.slice(marker.length);
          try {
            const obj = JSON.parse(payload) as { ok?: boolean; output?: string; error_message?: string };
            finalResult = {
              ok: obj.ok === true,
              output: String(obj.output ?? ""),
              error_message: String(obj.error_message ?? ""),
            };
          } catch {
            // ignore malformed marker payload; close handler will fall back.
          }
          return;
        }
        try {
          const evt = JSON.parse(line) as Record<string, unknown>;
          const t = String(evt.type ?? "");
          const isDeltaEvent = t === "thinking_delta" || t === "assistant_delta" || t === "text_delta";
          const rawDelta =
            typeof evt.text_delta === "string" ? evt.text_delta :
            typeof evt.delta === "string" ? evt.delta :
            typeof evt.text === "string" ? evt.text :
            "";
          if (isDeltaEvent && rawDelta !== "") {
            const delta = String(rawDelta);
            streamed = true;
            deltaFallback += delta;
            onDelta(delta);
            return;
          }
        } catch {
          // non-JSON runtime/progress lines are ignored for delta purposes.
        }
      };

      child.stdout.setEncoding("utf8");
      child.stdout.on("data", (chunk: string) => {
        stdoutBuf += chunk;
        while (true) {
          const idx = stdoutBuf.indexOf("\n");
          if (idx === -1) break;
          const line = stdoutBuf.slice(0, idx).trim();
          stdoutBuf = stdoutBuf.slice(idx + 1);
          handleLine(line);
        }
      });

      child.stderr.setEncoding("utf8");
      child.stderr.on("data", (chunk: string) => {
        stderrAll += chunk;
      });

      child.on("error", (e) => {
        clearTimeout(timer);
        finish(new Error(`subagent stream spawn failed: ${String((e as any)?.message ?? e)}`));
      });

      child.on("close", (code) => {
        clearTimeout(timer);
        if (stdoutBuf.trim() !== "") handleLine(stdoutBuf.trim());
        if (timedOut) {
          finish(new Error(`subagent authoring timed out after ${timeoutMs}ms`));
          return;
        }
        if (code !== 0) {
          const detail = stderrAll.trim() === "" ? `exit ${code}` : stderrAll.trim();
          finish(new Error(`subagent stream process failed: ${detail}`));
          return;
        }
        if (finalResult && finalResult.ok) {
          try { unlinkSync(path); } catch { /* ignore */ }
          resolve({ output: finalResult.output, streamed });
          return;
        }
        if (finalResult && !finalResult.ok) {
          finish(new Error(`subagent stream AI error: ${finalResult.error_message}`));
          return;
        }
        if (deltaFallback.trim() !== "") {
          try { unlinkSync(path); } catch { /* ignore */ }
          resolve({ output: deltaFallback, streamed: true });
          return;
        }
        finish(new Error("subagent stream process returned no output"));
      });
    });
  }

  function buildAuthorPrompt(
    systemPrompt: string,
    triggerPrompt: string,
    intent: string,
    intentKind: ComposeIntentKind,
    expectedOutput: string,
    hintsRead: string[],
    hintsWrite: string[],
    priorErrors: string[],
  ): string {
    const errors = priorErrors.length === 0 ? "" : `\nPrevious type-check errors:\n${priorErrors.join("\n\n")}\n`;
    const primaryObjective = triggerPrompt.trim() !== "" ? triggerPrompt : intent;
    const hintLines = [
      hintsRead.length > 0 ? `Hints read paths: ${JSON.stringify(hintsRead)}` : "",
      hintsWrite.length > 0 ? `Hints write paths: ${JSON.stringify(hintsWrite)}` : "",
    ].filter((x) => x !== "");
    const hintSection = hintLines.length > 0 ? `${hintLines.join("\n")}\n` : "";
    const certTemplateEnabled = String(process.env.AILANG_COMPOSE_CERTIFICATE_TEMPLATE ?? "0").trim() === "1";
    const certificateSection = (() => {
      if (!certTemplateEnabled) return "";
      if (intentKind === "analyze") {
        return (
          "Certificate contract for this intent:\n" +
          "Your snippet's stdout MUST be a certificate in this exact form:\n\n" +
          "  PREMISES\n" +
          "    <path_1> -> <observed fact from that file>\n" +
          "    <path_2> -> <observed fact from that file>\n" +
          "    ...\n" +
          "  TRACE\n" +
          "    <how premises compose into the conclusion>\n" +
          "  CONCLUSION\n" +
          "    <single-line answer to the intent>\n\n" +
          "Each <path_N> must appear literally as the argument of a readFile or listDir call in your snippet.\n" +
          "Do not invent paths. If you cannot read a file, omit its premise.\n" +
          "Use ASCII \"->\" as the separator. Both \"->\" and \"→\" are accepted by validation.\n\n"
        );
      }
      if (intentKind === "summarize") {
        return (
          "Output structure for summarize intent:\n" +
          "  INPUT\n" +
          "    <description of what is being summarized>\n" +
          "  KEY_POINTS\n" +
          "    - <point 1>\n" +
          "    - <point 2>\n" +
          "    ...\n" +
          "  SUMMARY\n" +
          "    <single-paragraph summary>\n\n"
        );
      }
      if (intentKind === "list") {
        return (
          "Output structure for list intent:\n" +
          "  SOURCE\n" +
          "    <where items were gathered>\n" +
          "  FILTER\n" +
          "    <selection criteria>\n" +
          "  ITEMS\n" +
          "    <one item per line>\n\n"
        );
      }
      if (intentKind === "fetch") {
        return (
          "Output structure for fetch intent:\n" +
          "  URL\n" +
          "    <requested URL>\n" +
          "  STATUS\n" +
          "    <status/result>\n" +
          "  EXCERPT\n" +
          "    <key extracted lines>\n" +
          "  DERIVED\n" +
          "    <concise derived answer>\n\n"
        );
      }
      return "";
    })();
    return (
      `${systemPrompt}\n\n` +
      "Primary objective (verbatim user request):\n" +
      `${primaryObjective}\n\n` +
      "Compose guidance (non-binding scaffold from planner):\n" +
      `${intent}\n\n` +
      `Intent kind: ${intentKind}\n\n` +
      `Expected output:\n${expectedOutput}\n\n` +
      certificateSection +
      hintSection +
      "Scope guardrails:\n" +
      "- Preserve the full breadth of the primary objective.\n" +
      "- The guidance scaffold may help execution, but must not narrow scope to a strict subset.\n" +
      "- If uncertain, include additional likely modules/files rather than fewer.\n" +
      errors +
      "\nReturn exactly one ```ailang fenced block."
    );
  }

  function buildSummaryPrompt(
    primaryObjective: string,
    intent: string,
    expectedOutput: string,
    stdout: string,
    stderr: string,
    exitCode: number,
    validation: ExpectedOutputValidation,
  ): string {
    return [
      "Summarize this compose execution in 1-3 sentences for a software agent.",
      "State whether expected_output appears satisfied.",
      `Primary objective: ${primaryObjective}`,
      `Intent: ${intent}`,
      `Expected output: ${expectedOutput}`,
      `Exit code: ${exitCode}`,
      `Validator: decided=${validation.decided} satisfied=${validation.satisfied} confidence=${validation.confidence} reason=${validation.reason}`,
      "Stdout:",
      stdout,
      "Stderr:",
      stderr,
      "Return plain text only.",
    ].join("\n");
  }

  // POST /exec — run a shell command in workdir
  // Body: { cmd: string, timeout?: number }  (timeout in seconds, default 30)
  // Response: ExecResult (always 200)
  app.post("/exec", async (req, res) => {
    const { cmd, timeout = 30 } = req.body as { cmd: string; timeout?: number };
    if (tbExecProxy) {
      try {
        const resp = await fetch(`${tbExecProxy.replace(/\/+$/, "")}/exec`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ command: cmd, timeout }),
        });
        if (!resp.ok) {
          const result: ExecResult = {
            stdout: "",
            stderr: `TB exec proxy HTTP ${resp.status}`,
            exit_code: 1,
          };
          res.json(result);
          return;
        }
        const data = await resp.json() as Partial<ExecResult>;
        const result: ExecResult = {
          stdout: String(data.stdout ?? "").slice(0, 8000),
          stderr: String(data.stderr ?? "").slice(0, 2000),
          exit_code: typeof data.exit_code === "number" ? data.exit_code : 1,
        };
        res.json(result);
      } catch (e: any) {
        const result: ExecResult = {
          stdout: "",
          stderr: `TB exec proxy error: ${String(e?.message ?? e)}`.slice(0, 2000),
          exit_code: 1,
        };
        res.json(result);
      }
      return;
    }
    try {
      const stdout = execSync(cmd, {
        cwd: workdir,
        timeout: timeout * 1000,
        encoding: "utf8",
        maxBuffer: 8 * 1024 * 1024,
      });
      const result: ExecResult = {
        stdout: stdout.slice(0, 8000),
        stderr: "",
        exit_code: 0,
      };
      res.json(result);
    } catch (e: any) {
      // execSync throws when the command exits non-zero or times out.
      // e.stdout / e.stderr may be Buffer or string depending on encoding.
      const result: ExecResult = {
        stdout: String(e.stdout ?? "").slice(0, 8000),
        stderr: String(e.stderr ?? "").slice(0, 2000),
        // e.status is null on signal/timeout; fall back to 1.
        exit_code: typeof e.status === "number" ? e.status : 1,
      };
      res.json(result);
    }
  });

  // Persist a snippet and its metadata to the permanent store.
  // `cleanCode`  — the LLM-authored AILANG code with no module declaration
  // `outcome`    — "success" | "check_failed" | "run_failed"
  function saveSnippet(
    snippetName: string,
    cleanCode: string,
    caps: string,
    task: string,
    prompt: string,
    outcome: "success" | "check_failed" | "run_failed",
    checkErrors: string,
    exitCode: number,
  ): void {
    try {
      const ts = new Date().toISOString();
      const meta = {
        timestamp: ts,
        model: process.env.MODEL ?? "",
        task,
        prompt,
        caps,
        outcome,
        check_errors: checkErrors,
        exit_code: exitCode,
      };
      const datePrefix = ts.slice(0, 19).replace(/:/g, "-"); // YYYY-MM-DDTHH-MM-SS
      const base = `${datePrefix}_${snippetName}`;
      writeFileSync(join(permanentSnippetDir, `${base}.ail`), cleanCode, "utf8");
      writeFileSync(join(permanentSnippetDir, `${base}.meta.json`), JSON.stringify(meta, null, 2) + "\n", "utf8");
    } catch { /* best-effort — never fail the caller */ }
  }

  // POST /exec-ailang — type-check and run an AILANG snippet
  // Body: { code: string, caps?: string, timeout?: number }
  // Response: AilangExecResult (always 200)
  app.post("/exec-ailang", (req, res) => {
    const { code, caps = "IO,FS,Process", timeout = 30, task = "", prompt = "" } = req.body as {
      code: string;
      caps?: string;
      timeout?: number;
      task?: string;
      prompt?: string;
    };

    snippetCounter++;
    const snippetName = `snippet_${snippetCounter}_${Date.now()}`;
    const snippetPath = join(snippetDir, `${snippetName}.ail`);

    // Strip any module declaration the LLM may have included, then prepend
    // the correct one matching the temp file path.
    const codeLines = code.split("\n");
    const filteredLines = codeLines.filter(
      (line) => !line.trim().startsWith("module ")
    );
    const cleanCode = filteredLines.join("\n");
    const fullCode = `module tmp/${snippetName}\n\n${cleanCode}`;

    try {
      writeFileSync(snippetPath, fullCode, "utf8");
    } catch (e: any) {
      const msg = `Failed to write snippet: ${e.message}`;
      const result: AilangExecResult = {
        stdout: "",
        stderr: msg,
        exit_code: 1,
        check_passed: false,
        check_errors: msg,
      };
      res.json(result);
      return;
    }

    // Step 1: Type-check with ailang check
    let checkErrors = "";
    try {
      execSync(`ailang check ${snippetPath}`, {
        cwd: workdir,
        timeout: 10_000,
        encoding: "utf8",
        maxBuffer: 1 * 1024 * 1024,
      });
    } catch (e: any) {
      checkErrors = String(e.stderr ?? e.stdout ?? e.message).slice(0, 4000);
      const result: AilangExecResult = {
        stdout: "",
        stderr: checkErrors,
        exit_code: typeof e.status === "number" ? e.status : 1,
        check_passed: false,
        check_errors: checkErrors,
      };
      saveSnippet(snippetName, cleanCode, caps, task, prompt, "check_failed", checkErrors, result.exit_code);
      res.json(result);
      try { unlinkSync(snippetPath); } catch { /* ignore */ }
      return;
    }

    // Step 2: Run the snippet
    let runResult: AilangExecResult;
    try {
      const stdout = execSync(
        `ailang run --caps ${caps} --entry main ${snippetPath}`,
        {
          cwd: workdir,
          timeout: timeout * 1000,
          encoding: "utf8",
          maxBuffer: 8 * 1024 * 1024,
          env: {
            ...process.env,
            AILANG_FS_SANDBOX: workdir,
          },
        }
      );
      runResult = {
        stdout: stdout.slice(0, 8000),
        stderr: "",
        exit_code: 0,
        check_passed: true,
        check_errors: "",
      };
    } catch (e: any) {
      runResult = {
        stdout: String(e.stdout ?? "").slice(0, 8000),
        stderr: String(e.stderr ?? "").slice(0, 2000),
        exit_code: typeof e.status === "number" ? e.status : 1,
        check_passed: true,
        check_errors: "",
      };
    } finally {
      try { unlinkSync(snippetPath); } catch { /* ignore */ }
    }
    const outcome = runResult!.exit_code === 0 ? "success" : "run_failed";
    saveSnippet(snippetName, cleanCode, caps, task, prompt, outcome, "", runResult!.exit_code);
    res.json(runResult!);
  });

  // POST /compose — composition subagent loop.
  // Returns NDJSON compose_* events; final line is compose_result.
  app.post("/compose", async (req, res) => {
    const body = req.body as ComposeRequest;
    const composeId = body.id ?? "";
    const step = Number.isFinite(body.step) ? Number(body.step) : 0;
    const intent = String(body.intent ?? "");
    const explicitIntentKind = normalizeIntentKind(String(body.intent_kind ?? ""));
    const intentKind = explicitIntentKind ?? deriveIntentKind(intent);
    const triggerPrompt = String(body.trigger_prompt ?? "");
    const primaryObjective = triggerPrompt.trim() !== "" ? triggerPrompt : intent;
    const expectedOutput = String(body.expected_output ?? "");
    const hintsRead = Array.isArray(body.hints_read) ? body.hints_read.map(String) : [];
    const hintsWrite = Array.isArray(body.hints_write) ? body.hints_write.map(String) : [];
    const hintsAvoid = Array.isArray(body.hints_avoid) ? body.hints_avoid.map(String) : [];
    const capsBase = String(body.caps ?? process.env.AILANG_SNIPPET_CAPS ?? "IO,FS,Process");
    const caps = capsMinusAvoid(capsBase, hintsAvoid);
    const model = String(body.model ?? process.env.AILANG_SUBAGENT_MODEL ?? process.env.MODEL ?? "anthropic/claude-sonnet-4-6");
    const maxAttempts = Math.max(1, Number(body.max_attempts ?? process.env.AILANG_SUBAGENT_MAX_ATTEMPTS ?? 50));
    const systemPrompt = String(body.system_prompt ?? "");
    const claimCheckEnabled = String(process.env.AILANG_COMPOSE_CLAIMCHECK ?? "1").trim() === "1";
    const claimCheckInformalizerModel = String(process.env.AILANG_COMPOSE_CLAIMCHECK_INFORMALIZER_MODEL ?? model);
    const claimCheckComparatorModel = String(process.env.AILANG_COMPOSE_CLAIMCHECK_COMPARATOR_MODEL ?? model);
    const claimCheckTimeoutMs = Math.max(1000, Number(process.env.AILANG_COMPOSE_CLAIMCHECK_TIMEOUT_MS ?? 30000));
    const claimCheckMaxInvocations = Math.max(1, Number(process.env.AILANG_COMPOSE_CLAIMCHECK_MAX_INVOCATIONS ?? 10));
    const claimCheckStdoutMaxBytes = Math.max(1, Number(process.env.AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES ?? 4000));

    res.status(200);
    res.setHeader("Content-Type", "application/x-ndjson; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("X-Accel-Buffering", "no");

    const emitCompose = (event: Record<string, unknown>): void => {
      res.write(JSON.stringify(event) + "\n");
    };

    emitCompose({
      type: "compose_start",
      step,
      compose_id: composeId,
      intent,
      intent_kind: intentKind,
      claimcheck_enabled: claimCheckEnabled && intentKind === "analyze",
      model,
      max_attempts: maxAttempts,
    });

    const priorErrors: string[] = [];
    let lastError = "";
    let consecutiveEmptySnippet = 0;
    let lastEmptySignature = "";
    const telemetry: Record<string, unknown> = {
      compose_id: composeId,
      max_attempts: maxAttempts,
      attempts_started: 0,
      attempts_completed: 0,
      author_failures: 0,
      missing_fence_or_empty: 0,
      check_failures: 0,
      check_error_parse: 0,
      check_error_effect: 0,
      check_error_type: 0,
      check_error_import_or_symbol: 0,
      check_error_other: 0,
      run_failures: 0,
      validator_unsatisfied: 0,
      validator_inconclusive: 0,
      summary_failures: 0,
      succeeded: false,
      exhausted: false,
      final_exit_code: 0,
      duration_ms: 0,
      intent_kind: intentKind,
      guard_mode: String(process.env.AILANG_COMPOSE_EFFECT_GUARD ?? "1"),
      validator_certificate_structure_failures: 0,
      validator_content_failures: 0,
      declared_effects_by_attempt: [] as Array<{ attempt: number; effects: string[] }>,
      sf5: createClaimCheckTelemetry(),
    };
    const t0 = Date.now();

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      telemetry.attempts_started = Number(telemetry.attempts_started ?? 0) + 1;
      const authorPrompt = buildAuthorPrompt(
        systemPrompt,
        triggerPrompt,
        intent,
        intentKind,
        expectedOutput,
        hintsRead,
        hintsWrite,
        priorErrors,
      );
      let rawAuthor = "";
      let sawAuthorDelta = false;
      let authorFailureDetail = "";
      try {
        const streamed = await callSubagentModelStream(
          model,
          authorPrompt,
          (delta) => {
            sawAuthorDelta = true;
            emitCompose({
              type: "compose_author_delta",
              step,
              compose_id: composeId,
              attempt,
              delta,
            });
          },
        );
        rawAuthor = sanitizeSubagentOutput(streamed.output);
        if (rawAuthor && !sawAuthorDelta) {
          emitCompose({
            type: "compose_author_delta",
            step,
            compose_id: composeId,
            attempt,
            delta: rawAuthor,
          });
        }
      } catch (e: any) {
        authorFailureDetail = compactErr(e);
        lastError = `subagent streaming authoring failed: ${authorFailureDetail}`;
        telemetry.author_failures = Number(telemetry.author_failures ?? 0) + 1;
        emitCompose({
          type: "compose_author_error",
          step,
          compose_id: composeId,
          attempt,
          mode: "stream",
          error: lastError,
        });
        try {
          const fallbackAuthor = callSubagentModel(model, authorPrompt);
          rawAuthor = sanitizeSubagentOutput(fallbackAuthor);
          if (rawAuthor !== "") {
            emitCompose({
              type: "compose_author_delta",
              step,
              compose_id: composeId,
              attempt,
              delta: rawAuthor,
              author_mode: "fallback_non_stream",
            });
          }
        } catch (fallbackErr: any) {
          rawAuthor = "";
          const fallbackDetail = compactErr(fallbackErr);
          lastError = `${lastError}; fallback failed: ${fallbackDetail}`;
          emitCompose({
            type: "compose_author_error",
            step,
            compose_id: composeId,
            attempt,
            mode: "fallback_non_stream",
            error: fallbackDetail,
          });
        }
      }

      const snippet = extractAilangFence(rawAuthor);
      emitCompose({
        type: "compose_snippet",
        step,
        compose_id: composeId,
        attempt,
        code: snippet,
      });

      if (!snippet) {
        const sig = rawAuthor.trim().slice(0, 600);
        consecutiveEmptySnippet = sig === lastEmptySignature ? consecutiveEmptySnippet + 1 : 1;
        lastEmptySignature = sig;
        const excerpt = rawAuthor.trim().replace(/\s+/g, " ").slice(0, 220);
        const baseEmpty = "empty snippet returned by subagent (missing ```ailang fence or empty body)";
        lastError = authorFailureDetail ? `${baseEmpty}; ${lastError}` : baseEmpty;
        telemetry.missing_fence_or_empty = Number(telemetry.missing_fence_or_empty ?? 0) + 1;
        emitCompose({
          type: "compose_check",
          step,
          compose_id: composeId,
          attempt,
          passed: false,
          errors: excerpt ? `${lastError}; author_excerpt=${excerpt}` : lastError,
        });
        priorErrors.push(lastError + "\n" + ailangTargetedHint(lastError));
        if (consecutiveEmptySnippet >= 3) {
          lastError = `${lastError}; repeated ${consecutiveEmptySnippet} times`;
          break;
        }
        if (attempt < maxAttempts) {
          emitCompose({ type: "compose_retry", step, compose_id: composeId, attempt: attempt + 1, reason: lastError });
          continue;
        }
        break;
      }

      consecutiveEmptySnippet = 0;
      lastEmptySignature = "";

      const declaredEffects = Array.from(parseDeclaredEffects(snippet)).sort();
      (telemetry.declared_effects_by_attempt as Array<{ attempt: number; effects: string[] }>).push({
        attempt,
        effects: declaredEffects,
      });
      const guardErr = composeSnippetGuard(intent, snippet, intentKind);
      if (guardErr !== "") {
        lastError = guardErr;
        telemetry.check_failures = Number(telemetry.check_failures ?? 0) + 1;
        telemetry.check_error_other = Number(telemetry.check_error_other ?? 0) + 1;
        emitCompose({
          type: "compose_check",
          step,
          compose_id: composeId,
          attempt,
          passed: false,
          errors: guardErr,
        });
        priorErrors.push(guardErr + "\n" + ailangTargetedHint(guardErr));
        if (attempt < maxAttempts) {
          emitCompose({ type: "compose_retry", step, compose_id: composeId, attempt: attempt + 1, reason: guardErr });
          continue;
        }
        break;
      }

      snippetCounter++;
      const snippetName = `snippet_${step}_${Date.now()}_${attempt}`;
      const snippetPath = join(snippetDir, `${snippetName}.ail`);
      const codeLines = snippet.split("\n");
      const filteredLines = codeLines.filter((line) => !line.trim().startsWith("module "));
      const cleanCode = filteredLines.join("\n");
      const fullCode = `module tmp/${snippetName}\n\n${cleanCode}`;

      try {
        writeFileSync(snippetPath, fullCode, "utf8");
      } catch (e: any) {
        lastError = `failed to write snippet: ${String(e?.message ?? e)}`;
        telemetry.check_failures = Number(telemetry.check_failures ?? 0) + 1;
        telemetry.check_error_other = Number(telemetry.check_error_other ?? 0) + 1;
        emitCompose({
          type: "compose_check",
          step,
          compose_id: composeId,
          attempt,
          passed: false,
          errors: lastError,
        });
        priorErrors.push(lastError + "\n" + ailangTargetedHint(lastError));
        if (attempt < maxAttempts) {
          emitCompose({ type: "compose_retry", step, compose_id: composeId, attempt: attempt + 1, reason: lastError });
          continue;
        }
        break;
      }

      const checked = runAilangCheck(snippetPath);
      if (!checked.ok) {
        const kind = classifyAilangError(checked.errors);
        telemetry.check_failures = Number(telemetry.check_failures ?? 0) + 1;
        if (kind === "parse") telemetry.check_error_parse = Number(telemetry.check_error_parse ?? 0) + 1;
        else if (kind === "effect") telemetry.check_error_effect = Number(telemetry.check_error_effect ?? 0) + 1;
        else if (kind === "type") telemetry.check_error_type = Number(telemetry.check_error_type ?? 0) + 1;
        else if (kind === "import_or_symbol") telemetry.check_error_import_or_symbol = Number(telemetry.check_error_import_or_symbol ?? 0) + 1;
        else telemetry.check_error_other = Number(telemetry.check_error_other ?? 0) + 1;
        saveSnippet(snippetName, cleanCode, caps, intent, authorPrompt, "check_failed", checked.errors, checked.exit_code);
        try { unlinkSync(snippetPath); } catch { /* ignore */ }
        lastError = checked.errors;
        emitCompose({
          type: "compose_check",
          step,
          compose_id: composeId,
          attempt,
          passed: false,
          errors: checked.errors,
        });
        priorErrors.push(checked.errors + "\n" + ailangTargetedHint(checked.errors));
        if (attempt < maxAttempts) {
          emitCompose({ type: "compose_retry", step, compose_id: composeId, attempt: attempt + 1, reason: checked.errors });
          continue;
        }
        break;
      }

      emitCompose({ type: "compose_check", step, compose_id: composeId, attempt, passed: true, errors: "" });
      const ran = runAilangSnippet(snippetPath, caps, 30);
      emitCompose({
        type: "compose_exec",
        step,
        compose_id: composeId,
        stdout: ran.stdout,
        stderr: ran.stderr,
        exit_code: ran.exit_code,
      });

      if (ran.exit_code !== 0) {
        telemetry.run_failures = Number(telemetry.run_failures ?? 0) + 1;
        saveSnippet(snippetName, cleanCode, caps, intent, authorPrompt, "run_failed", "", ran.exit_code);
        try { unlinkSync(snippetPath); } catch { /* ignore */ }
        lastError = `snippet runtime failed (exit ${ran.exit_code})`;
        priorErrors.push(lastError + "\nstderr:\n" + ran.stderr + "\nstdout:\n" + ran.stdout);
        if (attempt < maxAttempts) {
          emitCompose({ type: "compose_retry", step, compose_id: composeId, attempt: attempt + 1, reason: lastError });
          continue;
        }
        break;
      }

      const observed = ran.raw_stdout;
      const validation = validateExpectedOutput(expectedOutput, observed);
      if (validation.decided && !validation.satisfied) {
        telemetry.validator_unsatisfied = Number(telemetry.validator_unsatisfied ?? 0) + 1;
        telemetry.validator_content_failures = Number(telemetry.validator_content_failures ?? 0) + 1;
        lastError = `expected_output unsatisfied: ${validation.reason}`;
        saveSnippet(snippetName, cleanCode, caps, intent, authorPrompt, "run_failed", lastError, 2);
        try { unlinkSync(snippetPath); } catch { /* ignore */ }
        priorErrors.push(lastError + "\n" + ailangTargetedHint(lastError));
        if (attempt < maxAttempts) {
          emitCompose({ type: "compose_retry", step, compose_id: composeId, attempt: attempt + 1, reason: lastError });
          continue;
        }
        break;
      }
      if (!validation.decided) {
        telemetry.validator_inconclusive = Number(telemetry.validator_inconclusive ?? 0) + 1;
      }

      const claim = await runClaimCheck({
        enabled: claimCheckEnabled,
        intentKind,
        intent: primaryObjective,
        certificateStdout: observed,
        informalizerModel: claimCheckInformalizerModel,
        comparatorModel: claimCheckComparatorModel,
        timeoutMs: claimCheckTimeoutMs,
        maxInvocations: claimCheckMaxInvocations,
        stdoutMaxBytes: claimCheckStdoutMaxBytes,
        telemetry: telemetry.sf5 as ReturnType<typeof createClaimCheckTelemetry>,
        callStream: callSubagentModelStream,
        emitEvent: (evt) => emitCompose({ ...evt, step }),
        step,
        composeId,
        attempt,
      });

      if (claim.shouldRetry) {
        lastError = `claimcheck ${claim.verdict}: ${claim.reason}`;
        priorErrors.push(claim.correctiveHint);
        if (attempt < maxAttempts) {
          emitCompose({ type: "compose_retry", step, compose_id: composeId, attempt: attempt + 1, reason: lastError });
          continue;
        }
      }

      let summary = "";
      try {
        const summaryPrompt = buildSummaryPrompt(
          primaryObjective,
          intent,
          expectedOutput,
          ran.stdout,
          ran.stderr,
          ran.exit_code,
          validation,
        );
        const summaryResp = await callSubagentModelStream(model, summaryPrompt, () => { /* summary delta handled below */ });
        const summaryBase = sanitizeSubagentOutput(summaryResp.output);
        if (validation.decided && validation.confidence === "high") {
          summary = `${summaryBase}\nValidator: ${validation.satisfied ? "satisfied" : "unsatisfied"} (${validation.reason})`;
        } else if (expectedOutput.trim() !== "") {
          summary = `${summaryBase}\nValidator: inconclusive (${validation.reason})`;
        } else {
          summary = summaryBase;
        }
        emitCompose({ type: "compose_summary_delta", step, compose_id: composeId, delta: summary });
      } catch {
        telemetry.summary_failures = Number(telemetry.summary_failures ?? 0) + 1;
        summary = `Compose run completed (exit ${ran.exit_code}). Expected output check: ${validation.decided ? (validation.satisfied ? "satisfied" : "unsatisfied") : "inconclusive"}.`;
      }

      telemetry.attempts_completed = attempt;
      telemetry.succeeded = true;
      telemetry.exhausted = false;
      telemetry.final_exit_code = 0;
      telemetry.duration_ms = Date.now() - t0;
      saveSnippet(snippetName, cleanCode, caps, intent, authorPrompt, "success", "", 0);
      try { unlinkSync(snippetPath); } catch { /* ignore */ }
      emitCompose({
        type: "compose_result",
        step,
        compose_id: composeId,
        attempts: attempt,
        summary,
        stdout: ran.stdout,
        stderr: ran.stderr,
        exit_code: 0,
        truncated: ran.truncated,
        telemetry_json: JSON.stringify(telemetry),
      });
      res.end();
      return;
    }

    telemetry.exhausted = true;
    telemetry.succeeded = false;
    telemetry.final_exit_code = 3;
    telemetry.duration_ms = Date.now() - t0;
    telemetry.attempts_completed = Number(telemetry.attempts_started ?? 0);
    const summary = `subagent exhausted attempts; last error: ${lastError}`;
    emitCompose({
      type: "compose_result",
      step,
      compose_id: composeId,
      attempts: maxAttempts,
      summary,
      stdout: "",
      stderr: lastError,
      exit_code: 3,
      truncated: false,
      telemetry_json: JSON.stringify(telemetry),
    });
    res.end();
  });

  // POST /snapshot — stash current working tree changes
  // Response: { snapshot_id: string }
  // If there is nothing to stash (clean tree), snapshot_id is "none".
  app.post("/snapshot", (_req, res) => {
    try {
      execSync("git stash", { cwd: workdir });
      const id = randomBytes(4).toString("hex");
      snapshots.set(id, "stash@{0}");
      res.json({ snapshot_id: id });
    } catch {
      // git stash fails when the repo is clean or not a git repo; treat as no-op
      res.json({ snapshot_id: "none" });
    }
  });

  // POST /restore — pop a previously taken snapshot
  // Body: { snapshot_id: string }
  // Response: { ok: true }  (best-effort; errors are swallowed)
  app.post("/restore", (req, res) => {
    const { snapshot_id } = req.body as { snapshot_id: string };
    const ref = snapshots.get(snapshot_id) ?? "stash@{0}";
    try {
      execSync(`git stash pop ${ref}`, { cwd: workdir });
    } catch {
      // best-effort — caller should not rely on this succeeding
    }
    res.json({ ok: true });
  });

  // GET /health — liveness probe used by runtime startup check
  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  const server = app.listen(port);

  // Cleanup .motoko-store on process exit
  const cleanup = () => {
    try { rmSync(motokoStore, { recursive: true, force: true }); } catch { /* ignore */ }
  };
  process.on("exit", cleanup);
  process.on("SIGINT", () => { cleanup(); process.exit(0); });
  process.on("SIGTERM", () => { cleanup(); process.exit(0); });
}
