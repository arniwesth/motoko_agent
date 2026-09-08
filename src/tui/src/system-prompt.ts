import * as fs from "fs";
import * as path from "path";

export function systemPromptForWorkspace(projectRoot: string, workdir: string): string {
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
export function materializeSystemPromptArg(flagValue: string, workdir: string): string | null {
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
