export type EvalLanguage = "py" | "js";

export type EvalCell = {
  language: EvalLanguage;
  code: string;
  title?: string;
  timeout?: number;
  reset?: boolean;
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

export type EvalCellResult = {
  index: number;
  language: EvalLanguage;
  title: string;
  exit_code: number;
  stdout: string;
  stderr: string;
  displays: EvalDisplayBundle[];
  result?: EvalDisplayBundle;
  error?: { ename: string; evalue: string; traceback: string[] };
  executionCount: number;
  cancelled: boolean;
  truncated: boolean;
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
