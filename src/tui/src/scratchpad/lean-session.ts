import type {
  LeanElabStatus,
  LeanProofStatus,
  LeanProveMode,
  LeanTheoremProof,
} from "./frames.js";

export const STANDARD_LEAN_AXIOMS = new Set(["propext", "Classical.choice", "Quot.sound"]);

export type LeanDeclKind = "theorem" | "lemma" | "def" | "abbrev" | "instance" | "example" | "axiom" | "other";

export type ParsedLeanDecl = {
  name: string | null;
  kind: LeanDeclKind;
  source: string;
};

export type ParsedLeanCell = {
  imports: string[];
  decls: ParsedLeanDecl[];
  namedTheorems: string[];
  hasAnonymousExample: boolean;
};

export type LeanReplMessage = {
  severity?: string;
  data?: string;
};

export type LeanReplResponse = {
  messages?: LeanReplMessage[];
  sorries?: unknown[];
  env?: number;
};

export type LeanAxiomInfo = {
  name: string;
  axioms: string[];
};

const TOP_DECL = /^\s*(?:private\s+|protected\s+|noncomputable\s+|unsafe\s+|partial\s+|mutual\s+|scoped\s+)*(theorem|lemma|def|abbrev|instance|example|axiom)\b\s*([A-Za-z_][A-Za-z0-9_'.]*)?/;

function stripLineComment(line: string): string {
  const idx = line.indexOf("--");
  return idx >= 0 ? line.slice(0, idx) : line;
}

function looksTopLevel(line: string): boolean {
  return /^\s*(?:private\s+|protected\s+|noncomputable\s+|unsafe\s+|partial\s+|mutual\s+|scoped\s+)*(theorem|lemma|def|abbrev|instance|example|axiom)\b/.test(line);
}

function parseDeclHead(source: string): { name: string | null; kind: LeanDeclKind } {
  const head = source.split("\n").find((line) => line.trim() !== "") ?? "";
  const m = TOP_DECL.exec(head);
  if (!m) return { name: null, kind: "other" };
  const kind = m[1] as LeanDeclKind;
  if (kind === "example") return { name: null, kind };
  const name = m[2] ?? null;
  return { name, kind };
}

export function parseLeanCell(code: string): ParsedLeanCell {
  const lines = code.replace(/\r\n/g, "\n").split("\n");
  const imports: string[] = [];
  const decls: ParsedLeanDecl[] = [];
  const seenImports = new Set<string>();
  let buf: string[] = [];

  const flush = () => {
    const source = buf.join("\n").replace(/\s+$/g, "");
    buf = [];
    if (source.trim() === "") return;
    const { name, kind } = parseDeclHead(source);
    decls.push({ name, kind, source });
  };

  for (const raw of lines) {
    const line = raw;
    const trimmed = line.trim();
    if (trimmed === "") {
      if (buf.length > 0) flush();
      continue;
    }
    if (buf.length === 0 && /^import\b/.test(trimmed)) {
      if (!seenImports.has(trimmed)) {
        seenImports.add(trimmed);
        imports.push(trimmed);
      }
      continue;
    }
    if (buf.length > 0 && looksTopLevel(stripLineComment(line))) flush();
    buf.push(line);
  }
  if (buf.length > 0) flush();

  const namedTheorems = decls
    .filter((d) => (d.kind === "theorem" || d.kind === "lemma") && d.name != null)
    .map((d) => d.name!);
  return {
    imports,
    decls,
    namedTheorems,
    hasAnonymousExample: decls.some((d) => d.kind === "example"),
  };
}

export function mapElaboration(resp: LeanReplResponse | null | undefined): LeanElabStatus {
  if (!resp) return "error";
  const messages = resp.messages ?? [];
  return messages.some((m) => String(m.severity ?? "").toLowerCase() === "error") ? "failed" : "passed";
}

export function hasSorry(resp: LeanReplResponse | null | undefined): boolean {
  if (!resp) return false;
  if ((resp.sorries ?? []).length > 0) return true;
  return (resp.messages ?? []).some((m) => /declaration uses [`']sorry[`']/.test(String(m.data ?? "")));
}

export function parseAxiomInfos(messages: LeanReplMessage[] | undefined): LeanAxiomInfo[] {
  const infos: LeanAxiomInfo[] = [];
  for (const msg of messages ?? []) {
    if (String(msg.severity ?? "").toLowerCase() !== "info") continue;
    const data = String(msg.data ?? "");
    const none = /^'([^']+)'\s+does not depend on any axioms/.exec(data);
    if (none) {
      infos.push({ name: none[1], axioms: [] });
      continue;
    }
    const deps = /^'([^']+)'\s+depends on axioms:\s+\[([^\]]*)\]/.exec(data);
    if (!deps) continue;
    const axioms = deps[2]
      .split(",")
      .map((x) => x.trim())
      .filter(Boolean);
    infos.push({ name: deps[1], axioms });
  }
  return infos;
}

export function classifyTheoremAxioms(name: string, axioms: string[], sorrySeen: boolean): LeanTheoremProof {
  if (sorrySeen || axioms.includes("sorryAx")) return { name, status: "sorry", axioms };
  const unexpected = axioms.filter((a) => !STANDARD_LEAN_AXIOMS.has(a));
  if (unexpected.length > 0) return { name, status: "axiom_tainted", axioms };
  return { name, status: "verified", axioms };
}

export function aggregateProof(args: {
  elaborated: LeanElabStatus;
  parsed: ParsedLeanCell;
  theoremProofs: LeanTheoremProof[];
  sorrySeen: boolean;
  axiomAuditError?: boolean;
}): LeanProofStatus {
  if (args.elaborated === "error") return "error";
  if (args.elaborated === "failed") return "failed";
  if (args.sorrySeen) return "sorry";
  if (args.axiomAuditError) return "error";
  if (args.theoremProofs.some((t) => t.status === "sorry")) return "sorry";
  if (args.theoremProofs.some((t) => t.status === "axiom_tainted")) return "axiom_tainted";
  if (args.theoremProofs.some((t) => t.status === "error" || t.status === "failed")) return "error";
  if (args.parsed.namedTheorems.length > 0 && args.theoremProofs.every((t) => t.status === "verified")) return "verified";
  return "skipped";
}

export type LeanCommitDecision = {
  commit: boolean;
  reason: string;
};

export function normalizeLeanProve(mode: unknown): LeanProveMode {
  if (mode === "required") return "required";
  if (mode === "off" || mode === false || mode === "false") return "off";
  return "auto";
}

export function decideLeanCommit(args: {
  elaborated: LeanElabStatus;
  proof: LeanProofStatus;
  proveMode: LeanProveMode | undefined;
  hasNamedTheorems: boolean;
}): LeanCommitDecision {
  if (args.elaborated !== "passed") {
    return { commit: false, reason: args.elaborated === "error" ? "repl error" : "elaboration failed" };
  }
  const mode = normalizeLeanProve(args.proveMode);
  if (mode === "off" || mode === "auto") return { commit: true, reason: "" };
  if (!args.hasNamedTheorems) {
    return { commit: false, reason: "proof required but no named theorem/lemma was found" };
  }
  if (args.proof !== "verified") {
    return { commit: false, reason: `proof required but proof status is '${args.proof}'` };
  }
  return { commit: true, reason: "" };
}

export class LeanSession {
  committedEnv: number | null = null;
  teachPromptSeen = false;
  readonly createdAt = Date.now();
  lastUsed = Date.now();
  private declOrder: string[] = [];

  constructor(public mathlib = false) {}

  reset(mathlib = this.mathlib): void {
    this.committedEnv = null;
    this.declOrder = [];
    this.mathlib = mathlib;
    this.lastUsed = Date.now();
    // teachPromptSeen is intentionally preserved across source resets.
  }

  get acceptedNames(): string[] {
    return [...this.declOrder];
  }

  commit(env: number, parsed: ParsedLeanCell): void {
    this.committedEnv = env;
    for (const d of parsed.decls) {
      if (!d.name) continue;
      if (!this.declOrder.includes(d.name)) this.declOrder.push(d.name);
    }
    this.lastUsed = Date.now();
  }
}
