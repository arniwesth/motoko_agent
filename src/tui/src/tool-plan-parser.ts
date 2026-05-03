import type { DelegatedCall } from "./runtime-process.js";

export interface ToolPlanSnapshot {
  calls: DelegatedCall[];
  truncatedForParse: boolean;
}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null;
}

function normalizeCall(raw: unknown): DelegatedCall | null {
  if (!isRecord(raw)) return null;
  const tool = typeof raw.tool === "string" ? raw.tool : "";
  if (!tool) return null;
  const call = raw as Record<string, unknown>;
  const execRaw = isRecord(call.exec) ? call.exec : null;
  return {
    id: typeof call.id === "string" ? call.id : "",
    tool,
    path: typeof call.path === "string" ? call.path : undefined,
    edits: Array.isArray(call.edits)
      ? call.edits.filter(
          (x): x is { old: string; new: string; replace_all?: boolean } =>
            isRecord(x) && typeof x.old === "string" && typeof x.new === "string",
        )
      : undefined,
    dry_run: typeof call.dry_run === "boolean" ? call.dry_run : undefined,
    expected_sha256: typeof call.expected_sha256 === "string" ? call.expected_sha256 : undefined,
    start: typeof call.start === "number" ? call.start : undefined,
    end: typeof call.end === "number" ? call.end : undefined,
    pattern: typeof call.pattern === "string" ? call.pattern : undefined,
    dir: typeof call.dir === "string" ? call.dir : undefined,
    context: typeof call.context === "number" ? call.context : undefined,
    content: typeof call.content === "string" ? call.content : undefined,
    exec: execRaw && typeof execRaw.cmd === "string"
      ? {
          cmd: execRaw.cmd,
          args: Array.isArray(execRaw.args) ? execRaw.args.filter((x): x is string => typeof x === "string") : undefined,
          cwd: typeof execRaw.cwd === "string" ? execRaw.cwd : undefined,
          streaming: typeof execRaw.streaming === "boolean" ? execRaw.streaming : undefined,
          needs_stderr_live: typeof execRaw.needs_stderr_live === "boolean" ? execRaw.needs_stderr_live : undefined,
          needs_hard_cancel: typeof execRaw.needs_hard_cancel === "boolean" ? execRaw.needs_hard_cancel : undefined,
        }
      : undefined,
  };
}

function parseToolCallsEnvelope(raw: unknown): DelegatedCall[] | null {
  if (!isRecord(raw) || !Array.isArray(raw.tool_calls)) return null;
  const calls: DelegatedCall[] = [];
  for (const item of raw.tool_calls) {
    const normalized = normalizeCall(item);
    if (!normalized) return null;
    calls.push(normalized);
  }
  return calls;
}

function extractFencedJsonBodies(text: string): string[] {
  const bodies: string[] = [];
  const re = /```json\s*([\s\S]*?)```/gi;
  for (;;) {
    const m = re.exec(text);
    if (!m) break;
    bodies.push((m[1] ?? "").trim());
  }
  return bodies;
}

function extractBalancedJsonObjects(text: string): string[] {
  const objs: string[] = [];
  let depth = 0;
  let inStr = false;
  let escaped = false;
  let start = -1;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]!;
    if (escaped) {
      escaped = false;
      continue;
    }
    if (inStr) {
      if (ch === "\\") escaped = true;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') {
      inStr = true;
      continue;
    }
    if (ch === "{") {
      if (depth === 0) start = i;
      depth += 1;
      continue;
    }
    if (ch === "}") {
      if (depth <= 0) continue;
      depth -= 1;
      if (depth === 0 && start >= 0) {
        objs.push(text.slice(start, i + 1));
        start = -1;
      }
    }
  }
  return objs;
}

export function stableCallArgsHash(call: DelegatedCall): string {
  const payload = {
    tool: call.tool,
    path: call.path ?? "",
    start: call.start ?? 0,
    end: call.end ?? 0,
    pattern: call.pattern ?? "",
    dir: call.dir ?? "",
    context: call.context ?? 0,
    content: call.content ?? "",
    exec: call.exec ? { cmd: call.exec.cmd, args: call.exec.args ?? [], cwd: call.exec.cwd ?? "" } : null,
    edits: call.edits ?? [],
    dry_run: call.dry_run ?? false,
    expected_sha256: call.expected_sha256 ?? "",
  };
  const raw = JSON.stringify(payload);
  let h = 2166136261;
  for (let i = 0; i < raw.length; i++) {
    h ^= raw.charCodeAt(i);
    h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
  }
  return (h >>> 0).toString(16);
}

export function canonicalToolIdentity(call: DelegatedCall, firstSeenIndex: number): string {
  if (call.id && call.id.trim().length > 0) return `id:${call.id}`;
  return `anon:${call.tool}:${stableCallArgsHash(call)}:${firstSeenIndex}`;
}

export function extractToolPlanSnapshot(text: string, maxBytes = 64 * 1024): ToolPlanSnapshot {
  const truncatedForParse = text.length > maxBytes;
  const hay = truncatedForParse ? text.slice(-maxBytes) : text;
  const candidates = [...extractFencedJsonBodies(hay), ...extractBalancedJsonObjects(hay)];
  for (let i = candidates.length - 1; i >= 0; i--) {
    const body = candidates[i]!;
    if (!body.includes("\"tool_calls\"")) continue;
    try {
      const parsed = JSON.parse(body) as unknown;
      const calls = parseToolCallsEnvelope(parsed);
      if (calls) return { calls, truncatedForParse };
    } catch {
      // keep scanning candidates
    }
  }
  return { calls: [], truncatedForParse };
}
