// AILANG persistent source session — the pure, CLI-free core of the AILANG
// eval kernel. This file holds NO process/exec logic so it can be unit-tested
// without the `ailang` binary installed.
//
// Persistence model (see plan 05): an AILANG eval cell is NOT a mutable REPL.
// Accepted top-level declarations and imports accumulate as *source* in a
// generated session module. A later cell may USE earlier declarations, but a
// failed candidate (check/verify gate not satisfied) never mutates the
// accepted state. Duplicate top-level names are rejected for MVP — there is no
// in-place replacement.
//
// Generated entrypoints / run wrappers (a `main`, or whatever `entry` names)
// are EPHEMERAL: they are included in the rendered module for the current run
// but never committed, so each run cell can carry its own `main` without
// colliding with a previous one.

import type {
  AilangCheckStatus,
  AilangFnVerify,
  AilangVerifyMode,
  AilangVerifyStatus,
} from "./frames.js";

export const SESSION_MODULE = "motoko/eval_session";
export const DEFAULT_ENTRY = "main";

export type ParsedDecl = {
  name: string | null; // top-level name (func/type), or null when unparseable
  kind: string; // "func" | "type" | "other"
  source: string; // verbatim declaration text
};

export type ParsedCell = {
  imports: string[]; // deduped, trimmed `import ...` lines (in first-seen order)
  decls: ParsedDecl[];
  hasAnnotations: boolean; // any requires/ensures contract present
};

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

function stripLineComment(line: string): string {
  // Naive: drop from the first `--` to end of line. Good enough for brace
  // counting on typical declarations; we do not attempt to honor `--` inside
  // string literals (rare in top-level signatures).
  const idx = line.indexOf("--");
  return idx >= 0 ? line.slice(0, idx) : line;
}

function braceDelta(line: string): number {
  const s = stripLineComment(line);
  let d = 0;
  for (const ch of s) {
    if (ch === "{") d += 1;
    else if (ch === "}") d -= 1;
  }
  return d;
}

const TOP_KEYWORD = /^(export\s+)?(pure\s+)?(func|type|let|letrec|test|instance|class)\b/;
const FUNC_NAME = /\b(?:func|letrec|let)\s+([A-Za-z_][A-Za-z0-9_]*)/;
const TYPE_NAME = /\btype\s+([A-Za-z_][A-Za-z0-9_]*)/;

function declName(source: string): { name: string | null; kind: string } {
  const head = source.split("\n")[0] ?? "";
  const t = TYPE_NAME.exec(head);
  if (t) return { name: t[1], kind: "type" };
  const f = FUNC_NAME.exec(head);
  if (f) return { name: f[1], kind: "func" };
  return { name: null, kind: "other" };
}

// Split a cell's raw code into imports and top-level declarations. A `module`
// line is stripped (we always render our own session module declaration).
export function parseCell(code: string): ParsedCell {
  const lines = code.replace(/\r\n/g, "\n").split("\n");
  const imports: string[] = [];
  const seenImports = new Set<string>();
  const decls: ParsedDecl[] = [];

  let buf: string[] = [];
  let depth = 0;

  const flush = () => {
    const source = buf.join("\n").replace(/\s+$/g, "");
    buf = [];
    if (source.trim() === "") return;
    const { name, kind } = declName(source);
    decls.push({ name, kind, source });
  };

  for (const raw of lines) {
    const line = raw;
    const trimmed = line.trim();

    if (depth === 0) {
      if (trimmed === "" ) {
        // Blank line at top level terminates the current declaration.
        if (buf.length > 0) flush();
        continue;
      }
      if (/^module\b/.test(trimmed)) {
        // Strip the caller's module declaration; we generate our own.
        continue;
      }
      if (/^import\b/.test(trimmed)) {
        if (buf.length > 0) flush();
        if (!seenImports.has(trimmed)) {
          seenImports.add(trimmed);
          imports.push(trimmed);
        }
        continue;
      }
      if (TOP_KEYWORD.test(trimmed) && buf.length > 0) {
        // A new top-level construct begins while the previous one already
        // closed all its braces — flush the previous decl first.
        flush();
      }
    }

    buf.push(line);
    depth += braceDelta(line);
    if (depth < 0) depth = 0; // defensive: never go negative on malformed input
  }
  if (buf.length > 0) flush();

  const hasAnnotations = /\b(requires|ensures)\b\s*\{/.test(code);
  return { imports, decls, hasAnnotations };
}

// ---------------------------------------------------------------------------
// Status mapping (from `ailang ai-check` JSON)
// ---------------------------------------------------------------------------

export type AiCheckJson = {
  file?: string;
  check?: {
    passed?: boolean;
    error_count?: number;
    errors?: Array<{ code?: string; message?: string; file?: string }>;
  };
  verify?: {
    available?: boolean;
    verified?: number;
    counterexample?: number;
    skipped?: number;
    errors?: number;
    results?: Array<{ function?: string; status?: string; duration?: number }>;
  };
};

export function mapCheckStatus(j: AiCheckJson): AilangCheckStatus {
  const c = j.check;
  if (!c) return "skipped";
  return c.passed === true ? "passed" : "failed";
}

// Map one per-function verifier status. Conservative: anything we are not sure
// proves the contract is NOT reported as `verified`.
export function mapFnVerify(status: string | undefined): AilangVerifyStatus {
  switch ((status ?? "").toLowerCase()) {
    case "verified":
      return "verified";
    case "counterexample":
    case "violated":
    case "failed":
      return "failed";
    case "timeout":
      return "timeout";
    case "skipped":
      return "skipped";
    case "unknown":
    case "error":
    default:
      return "unknown";
  }
}

export function fnVerifies(j: AiCheckJson): AilangFnVerify[] {
  const results = j.verify?.results ?? [];
  return results.map((r) => ({
    function: String(r.function ?? "<anon>"),
    status: mapFnVerify(r.status),
  }));
}

// Aggregate the per-function statuses into one cell-level verify status.
// `available` reflects whether Z3 was present at all.
export function aggregateVerify(j: AiCheckJson): { status: AilangVerifyStatus; available: boolean } {
  const available = j.verify?.available !== false;
  if (!available) return { status: "skipped", available: false };
  const fns = fnVerifies(j);
  if (fns.length === 0) return { status: "skipped", available };
  if (fns.some((f) => f.status === "failed")) return { status: "failed", available };
  if (fns.some((f) => f.status === "timeout")) return { status: "timeout", available };
  if (fns.some((f) => f.status === "unknown")) return { status: "unknown", available };
  return { status: "verified", available };
}

// ---------------------------------------------------------------------------
// Commit gate
// ---------------------------------------------------------------------------

export type CommitDecision = {
  commit: boolean;
  reason: string; // human-readable; empty when committing cleanly
};

export function normalizeVerifyMode(mode: AilangVerifyMode | undefined): "off" | "auto" | "required" {
  if (mode === true || mode === "required") return "required";
  if (mode === "auto") return "auto";
  return "off"; // false | undefined
}

// Decide whether a candidate's declarations should be committed to the session,
// given the check/verify outcomes and the requested verify mode.
export function decideCommit(args: {
  check: AilangCheckStatus;
  verify: AilangVerifyStatus;
  verifyAvailable: boolean;
  verifyMode: AilangVerifyMode | undefined;
  hasAnnotations: boolean;
}): CommitDecision {
  if (args.check !== "passed") {
    return { commit: false, reason: "type-check failed" };
  }
  const mode = normalizeVerifyMode(args.verifyMode);

  if (mode === "off") return { commit: true, reason: "" };

  if (mode === "auto") {
    // Only gate when there is something to prove. A provably-false contract
    // (counterexample → `failed`) is never committed; unknown/timeout/skipped
    // do not block (we could not prove, but we did not disprove).
    if (args.hasAnnotations && args.verify === "failed") {
      return { commit: false, reason: "verifier found a counterexample" };
    }
    return { commit: true, reason: "" };
  }

  // mode === "required"
  if (!args.hasAnnotations) {
    return { commit: false, reason: "verify required but no requires/ensures annotations found" };
  }
  if (!args.verifyAvailable) {
    return { commit: false, reason: "verify required but the Z3 solver is unavailable" };
  }
  if (args.verify !== "verified") {
    return { commit: false, reason: `verify required but verifier reported '${args.verify}'` };
  }
  return { commit: true, reason: "" };
}

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

export class AilangSession {
  private importLines: string[] = [];
  private seenImports = new Set<string>();
  private declOrder: string[] = [];
  private declByName = new Map<string, string>(); // name -> source
  lastGoodSource = "";
  teachPromptSeen = false;
  readonly createdAt = Date.now();
  lastUsed = Date.now();

  reset(): void {
    this.importLines = [];
    this.seenImports = new Set<string>();
    this.declOrder = [];
    this.declByName = new Map<string, string>();
    this.lastGoodSource = "";
    // teachPromptSeen intentionally preserved across reset — resetting the
    // source scratchpad should not re-trigger the (token-heavy) teach prompt.
  }

  get acceptedNames(): string[] {
    return [...this.declOrder];
  }

  get imports(): string[] {
    return [...this.importLines];
  }

  hasDecl(name: string): boolean {
    return this.declByName.has(name);
  }

  // Names in the candidate that are persistent (i.e. not the ephemeral entry
  // wrapper) and collide with an already-accepted declaration.
  duplicateNames(parsed: ParsedCell, entry: string): string[] {
    const dups: string[] = [];
    for (const d of parsed.decls) {
      if (d.name == null || d.name === entry) continue;
      if (this.declByName.has(d.name)) dups.push(d.name);
    }
    return dups;
  }

  // Render a complete, checkable module for a candidate cell. `entry`-named
  // declarations are included (so the module is runnable) but treated as
  // ephemeral by commit().
  renderModule(parsed: ParsedCell): string {
    const imports = [...this.importLines];
    const seen = new Set(this.seenImports);
    for (const imp of parsed.imports) {
      if (!seen.has(imp)) {
        seen.add(imp);
        imports.push(imp);
      }
    }
    const accepted = this.declOrder.map((n) => this.declByName.get(n)!).filter(Boolean);
    const candidate = parsed.decls.map((d) => d.source);

    const parts: string[] = [`module ${SESSION_MODULE}`, ""];
    if (imports.length > 0) {
      parts.push(imports.join("\n"), "");
    }
    for (const block of [...accepted, ...candidate]) {
      parts.push(block, "");
    }
    return parts.join("\n").replace(/\n{3,}/g, "\n\n").trimEnd() + "\n";
  }

  // Commit the persistent declarations + imports of a candidate. Ephemeral
  // entry-named decls are deliberately NOT persisted. Caller must have already
  // verified there are no duplicate persistent names.
  commit(parsed: ParsedCell, entry: string): void {
    for (const imp of parsed.imports) {
      if (!this.seenImports.has(imp)) {
        this.seenImports.add(imp);
        this.importLines.push(imp);
      }
    }
    for (const d of parsed.decls) {
      if (d.name == null || d.name === entry) continue; // skip ephemeral / unparseable
      if (!this.declByName.has(d.name)) this.declOrder.push(d.name);
      this.declByName.set(d.name, d.source);
    }
    this.lastGoodSource = this.renderAccepted();
  }

  // The committed module (accepted imports + decls only — no candidate, no
  // ephemeral entry).
  renderAccepted(): string {
    const parts: string[] = [`module ${SESSION_MODULE}`, ""];
    if (this.importLines.length > 0) parts.push(this.importLines.join("\n"), "");
    for (const n of this.declOrder) {
      const src = this.declByName.get(n);
      if (src) parts.push(src, "");
    }
    return parts.join("\n").replace(/\n{3,}/g, "\n\n").trimEnd() + "\n";
  }
}
