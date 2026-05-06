import * as fs from "fs";
import * as path from "path";
import { spawn } from "child_process";
import type { DelegatedCall, DelegatedResult } from "../runtime-process.js";
import type { OhMyPiSession } from "./session-adapter.js";

function result(id: string, stdout: string, stderr: string, exit_code: number): DelegatedResult {
  return { tool_call_id: id, stdout, stderr, exit_code, truncated: false };
}

function asObj(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

function argString(call: DelegatedCall, key: string, fallback = ""): string {
  const root = asObj(call.arguments);
  const v = (call as unknown as Record<string, unknown>)[key] ?? root[key];
  return typeof v === "string" ? v : fallback;
}

function argNumber(call: DelegatedCall, key: string, fallback: number): number {
  const root = asObj(call.arguments);
  const v = (call as unknown as Record<string, unknown>)[key] ?? root[key];
  return typeof v === "number" && Number.isFinite(v) ? Math.floor(v) : fallback;
}

function argEdits(call: DelegatedCall): Array<{ old: string; new: string; replace_all?: boolean }> {
  const root = asObj(call.arguments);
  const raw = (call as unknown as Record<string, unknown>).edits ?? root.edits;
  if (!Array.isArray(raw)) return [];
  return raw
    .map((e) => asObj(e))
    .map((e) => ({
      old: typeof e.old === "string" ? e.old : "",
      new: typeof e.new === "string" ? e.new : "",
      replace_all: e.replace_all === true,
    }))
    .filter((e) => e.old.length > 0);
}

function resolvePath(session: OhMyPiSession, p: string): string {
  if (!p) return "";
  // Reject absolute-without-leading-slash paths (e.g. "Users/mark/.../foo")
  // that path.resolve would otherwise silently double past the workdir.
  // Mirrors the wd_bare check in AILANG validate_path_common (commit f16421c).
  const cwd = session.cwd;
  const cwdBare = cwd.startsWith("/") ? cwd.slice(1) : cwd;
  if (cwdBare && p.startsWith(cwdBare + "/")) {
    throw new Error(`path appears absolute (missing leading slash): ${p}`);
  }
  if (path.isAbsolute(p)) {
    throw new Error(`absolute paths are not allowed: ${p}`);
  }
  return path.resolve(cwd, p);
}

function normalizeRange(start: number, end: number): { start: number; end: number } {
  const s = start <= 0 ? 1 : start;
  const e = end < s ? s : end;
  return { start: s, end: e };
}

function readWithLines(absPath: string, start: number, end: number): string {
  const content = fs.readFileSync(absPath, "utf8");
  const lines = content.split("\n");
  const { start: s, end: e } = normalizeRange(start, end);
  const picked = lines.slice(s - 1, e);
  return picked.join("\n");
}

function applyEditOps(
  before: string,
  edits: Array<{ old: string; new: string; replace_all?: boolean }>,
): { after: string; applied: number } | { error: string } {
  let next = before;
  let applied = 0;
  for (const op of edits) {
    if (op.replace_all) {
      if (!next.includes(op.old)) return { error: `edit ${applied + 1}: old text not found` };
      const parts = next.split(op.old);
      next = parts.join(op.new);
      applied += Math.max(0, parts.length - 1);
      continue;
    }
    const idx = next.indexOf(op.old);
    if (idx < 0) return { error: `edit ${applied + 1}: old text not found` };
    next = `${next.slice(0, idx)}${op.new}${next.slice(idx + op.old.length)}`;
    applied += 1;
  }
  return { after: next, applied };
}

async function runSearch(session: OhMyPiSession, call: DelegatedCall): Promise<DelegatedResult> {
  const id = call.id ?? "";
  const pattern = argString(call, "pattern", argString(call, "query", ""));
  if (!pattern) return result(id, "", "missing pattern/query", 1);
  const dir = argString(call, "dir", argString(call, "path", "."));
  const include = argString(call, "glob", argString(call, "include", ""));
  const args = ["-n", "--no-heading", pattern];
  if (include) args.push("-g", include);
  args.push(dir);

  return await new Promise((resolve) => {
    const child = spawn("rg", args, { cwd: session.cwd, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout?.on("data", (c: Buffer | string) => (stdout += typeof c === "string" ? c : c.toString("utf8")));
    child.stderr?.on("data", (c: Buffer | string) => (stderr += typeof c === "string" ? c : c.toString("utf8")));
    child.on("error", (err) => resolve(result(id, "", String(err.message ?? err), 1)));
    child.on("close", (code) => resolve(result(id, stdout, stderr, typeof code === "number" ? code : 1)));
  });
}

export async function dispatchOhMyPiTool(session: OhMyPiSession, call: DelegatedCall): Promise<DelegatedResult> {
  const id = call.id ?? "";
  const tool = call.tool ?? "";
  try {
    if (tool === "ReadFile") {
      const p = argString(call, "path", "");
      if (!p) return result(id, "", "missing path", 1);
      const abs = resolvePath(session, p);
      const start = argNumber(call, "start", argNumber(call, "start_line", 1));
      const end = argNumber(call, "end", argNumber(call, "end_line", 200));
      return result(id, readWithLines(abs, start, end), "", 0);
    }
    if (tool === "WriteFile") {
      const p = argString(call, "path", "");
      if (!p) return result(id, "", "missing path", 1);
      const abs = resolvePath(session, p);
      const content = argString(call, "content", "");
      fs.mkdirSync(path.dirname(abs), { recursive: true });
      fs.writeFileSync(abs, content, "utf8");
      return result(id, `wrote ${p}`, "", 0);
    }
    if (tool === "EditFile") {
      const p = argString(call, "path", "");
      if (!p) return result(id, "", "missing path", 1);
      const edits = argEdits(call);
      if (edits.length === 0) return result(id, "", "missing edits", 1);
      const abs = resolvePath(session, p);
      const before = fs.readFileSync(abs, "utf8");
      const applied = applyEditOps(before, edits);
      if ("error" in applied) return result(id, "", applied.error, 1);
      const dryRun = (asObj(call.arguments).dry_run === true) || (call.dry_run === true);
      if (!dryRun) fs.writeFileSync(abs, applied.after, "utf8");
      return result(id, `applied_edits=${applied.applied} dry_run=${dryRun ? "true" : "false"}`, "", 0);
    }
    if (tool === "Search") return runSearch(session, call);
    return result(id, "", `unsupported oh-my-pi tool: ${tool}`, 1);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return result(id, "", message, 1);
  }
}
