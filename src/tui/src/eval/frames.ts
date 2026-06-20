export type EvalLanguage = "py" | "js" | "ail" | "lean";

// AILANG verification gate for a cell:
//   "auto"     — run the verifier only when the candidate has requires/ensures
//                annotations; do not fail the cell on unproven/unknown.
//   true/"required" — verifier must report `verified` for every annotated
//                function or the candidate is rejected (not committed).
//   false      — never invoke the verifier (check-only).
export type AilangVerifyMode = boolean | "auto" | "required";
export type LeanProveMode = "auto" | "required" | "off";

export type EvalCell = {
  language: EvalLanguage;
  code: string;
  title?: string;
  timeout?: number;
  reset?: boolean;
  // AILANG-only fields (ignored for py/js).
  verify?: AilangVerifyMode;
  run?: boolean;        // execute --entry after a successful check/verify
  entry?: string;       // entrypoint for `run` (default "main")
  caps?: string;        // requested capabilities, comma-separated (intersected with policy)
  // Lean-only fields (ignored for py/js/ail).
  prove?: LeanProveMode;
  mathlib?: boolean;
};

export type EvalDisplayBundle = {
  type: "json" | "image" | "markdown" | "status" | "text";
  mime?: string;
  data: unknown;
  width?: number;
  height?: number;
};

export type CellRunFrame =
  | { type: "run"; id: string; code: string; silent?: boolean; cwd?: string; env?: Record<string, string> }
  | { type: "started"; id: string }
  | { type: "stdout"; id: string; text: string }
  | { type: "stderr"; id: string; text: string }
  | { type: "display"; id: string; bundle: EvalDisplayBundle }
  | { type: "result"; id: string; bundle: EvalDisplayBundle }
  | { type: "error"; id: string; ename: string; evalue: string; traceback: string[] }
  | { type: "done"; id: string; status: "ok" | "error" | "timeout"; executionCount: number; cancelled: boolean };

export type LoopbackToolRequest = {
  type: "tool-request";
  reqId: string;
  tool: "read" | "write" | "append" | "search" | "agent" | string;
  arguments: Record<string, unknown>;
};

export type LoopbackToolResult = {
  type: "tool-result";
  reqId: string;
  exit_code: number;
  stdout: string;
  stderr: string;
  metadata: Record<string, unknown>;
};

// check  — `ailang ai-check` type-check result.
// verify — Z3 contract proof result. `skipped` covers both "no annotations"
//          and "Z3 unavailable"; the two are distinguished by `verifyAvailable`.
//          A status is `verified` ONLY when the verifier actually proved every
//          annotated contract — `unknown`/`timeout`/`failed` are never coerced
//          to success.
export type AilangCheckStatus = "passed" | "failed" | "skipped";
export type AilangVerifyStatus = "verified" | "failed" | "unknown" | "timeout" | "skipped";

export type AilangFnVerify = {
  function: string;
  status: AilangVerifyStatus;
  detail?: string;
};

export type AilangCellMetadata = {
  check: AilangCheckStatus;
  verify: AilangVerifyStatus;
  verifyAvailable: boolean;   // false when Z3 is not installed
  committed: boolean;         // were this candidate's decls accepted into the session module
  ran: boolean;               // was the run wrapper executed
  functions?: AilangFnVerify[];
  // One-time teaching guide, attached only to the first AILANG authoring
  // attempt in a session (see teachPromptSeen).
  teachPrompt?: string;
  // Human-readable status/guidance line(s) for the transcript and TUI.
  notice?: string;
};

export type LeanElabStatus = "passed" | "failed" | "error";
export type LeanProofStatus = "verified" | "sorry" | "axiom_tainted" | "failed" | "skipped" | "error";

export type LeanTheoremProof = {
  name: string;
  status: LeanProofStatus;
  axioms?: string[];
};

export type LeanCellMetadata = {
  elaborated: LeanElabStatus;
  proof: LeanProofStatus;
  committed: boolean;
  theorems?: LeanTheoremProof[];
  sorries?: number;
  unexpectedAxioms?: string[];
  teachPrompt?: string;
  notice?: string;
};

export type EvalCellResult = {
  index: number;
  language: EvalLanguage;
  title: string;
  code?: string;
  durationMs?: number;
  exit_code: number;
  stdout: string;
  stderr: string;
  displays: EvalDisplayBundle[];
  result?: EvalDisplayBundle;
  error?: { ename: string; evalue: string; traceback: string[] };
  executionCount: number;
  cancelled: boolean;
  truncated: boolean;
  metadata?: { ailang?: AilangCellMetadata; lean?: LeanCellMetadata };
};

export type ExecCellResponse = {
  exit_code: number;
  stdout: string;
  stderr: string;
  cells: EvalCellResult[];
  images: Array<{ path: string; mime: string; width?: number; height?: number }>;
  jsonOutputs: unknown[];
  notice?: string;
};
