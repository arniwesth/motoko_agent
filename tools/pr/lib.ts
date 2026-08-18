/**
 * lib — the pieces `pr` (operator agency) and `pr-sync` (bot agency) share.
 *
 * Identity handling lives here rather than in either CLI on purpose. ADR-001 D1
 * makes identity a property of *who decided the action*, not of which file the
 * code sits in, so both entry points resolve it through the same two functions
 * and neither can drift into inheriting a token by accident.
 *
 * See .agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const LIB_DIR = dirname(fileURLToPath(import.meta.url));

export const REPO_ROOT = resolve(LIB_DIR, "..", "..");
export const GITHUB_DIR = join(REPO_ROOT, ".agent", "github");
export const PRS_DIR = join(GITHUB_DIR, "prs");
export const STAGING_DIR = join(GITHUB_DIR, "staging");
/** Immutable, regenerable, gitignored (D3). Deleting it must lose nothing. */
export const CACHE_DIR = join(GITHUB_DIR, "cache");

let programName = "pr";
export function setProgramName(name: string): void {
  programName = name;
}

export function die(msg: string): never {
  console.error(`${programName}: ${msg}`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

export type Identity = "operator" | "bot";

/**
 * The bot credential arrives by one of two channels: the container environment
 * (docker-compose passes MOTOKO_BOT_GH_TOKEN through from the host) or the
 * gitignored repo-root .env, which is where this repo already keeps its keys.
 *
 * .env is read explicitly rather than left to Bun's automatic loading. That
 * loading is real but implicit — it depends on the runtime and on the process's
 * working directory — and a credential lookup that silently stops working when
 * a caller runs from a subdirectory is exactly the failure this pipeline cannot
 * afford. The environment wins where both are set.
 */
export function botToken(): string | null {
  const fromEnv = process.env.MOTOKO_BOT_GH_TOKEN;
  if (fromEnv) return fromEnv;

  const dotenv = join(REPO_ROOT, ".env");
  if (!existsSync(dotenv)) return null;
  for (const line of readFileSync(dotenv, "utf8").split("\n")) {
    const m = line.match(/^\s*(?:export\s+)?MOTOKO_BOT_GH_TOKEN\s*=\s*(.*)$/);
    if (!m) continue;
    const value = m[1].trim().replace(/^(['"])(.*)\1$/, "$2");
    if (value) return value;
  }
  return null;
}

/**
 * gh resolves GH_TOKEN/GITHUB_TOKEN ahead of the credentials stored by
 * `gh auth login`, and reports nothing when it does. So the identity a command
 * acts under is decided here, explicitly, rather than inherited by accident.
 */
export function ghEnv(identity: Identity): NodeJS.ProcessEnv {
  const env = { ...process.env };
  delete env.GH_TOKEN;
  delete env.GITHUB_TOKEN;
  if (identity === "bot") {
    const token = botToken();
    if (!token) {
      die("MOTOKO_BOT_GH_TOKEN not found in the environment or repo-root .env — see .devcontainer/README.md");
    }
    if (token.startsWith("github_pat_")) {
      // ADR-001 Consequences: a fine-grained PAT cannot write outside its
      // resource-owner grant, so it is not a valid hardening for this design —
      // it silently breaks the upstream participation D1 was chosen to enable.
      console.error(
        `${programName}: warning — MOTOKO_BOT_GH_TOKEN is a fine-grained PAT. Reads work, but ` +
          "posting to either remote returns 403. ADR-001 WI-0 asks for a classic PAT with public_repo.",
      );
    }
    env.GH_TOKEN = token;
  }
  return env;
}

export function gh(args: string[], identity: Identity = "operator"): { ok: boolean; stdout: string; stderr: string } {
  const r = spawnSync("gh", args, { encoding: "utf8", env: ghEnv(identity), maxBuffer: 64 * 1024 * 1024 });
  if (r.error) die(`gh not found — run ./scripts/install-prerequisites.sh`);
  return { ok: r.status === 0, stdout: (r.stdout ?? "").trim(), stderr: (r.stderr ?? "").trim() };
}

/** A gh call whose output is JSON, with the parse failure reported against the command. */
export function ghJson<T>(args: string[], identity: Identity = "operator"): T {
  const r = gh(args, identity);
  if (!r.ok) die(`gh ${args.slice(0, 3).join(" ")} failed:\n${r.stderr}`);
  try {
    return JSON.parse(r.stdout || "null") as T;
  } catch {
    return die(`gh ${args.slice(0, 3).join(" ")} returned unparseable JSON`);
  }
}

export function reportIdentity(identity: Identity): string {
  const r = gh(["api", "user", "--jq", ".login"], identity);
  if (!r.ok) {
    const hint =
      identity === "operator"
        ? "run `gh auth login` inside the container"
        : "check MOTOKO_BOT_GH_TOKEN — see .devcontainer/README.md";
    die(`could not resolve the ${identity} identity (${hint}):\n${r.stderr}`);
  }
  return r.stdout;
}

// ---------------------------------------------------------------------------
// git
// ---------------------------------------------------------------------------

export function git(args: string[]): string {
  const r = spawnSync("git", ["-C", REPO_ROOT, ...args], { encoding: "utf8" });
  if (r.status !== 0) die(`git ${args.join(" ")} failed: ${(r.stderr ?? "").trim()}`);
  return (r.stdout ?? "").trim();
}

export function currentBranch(): string {
  const b = git(["branch", "--show-current"]);
  if (!b) die("detached HEAD — check out a branch first");
  if (b === "main" || b === "master") die(`refusing to open a PR from ${b}`);
  return b;
}

/** `arniwesth/mot-97-github-ops` -> `MOT-97`; null when the branch carries no ticket. */
export function ticketFromBranch(branch: string): string | null {
  const m = branch.match(/\bmot-(\d+)\b/i);
  return m ? `MOT-${m[1]}` : null;
}

/** `arniwesth/mot-97-github-ops` -> `MOT-97: github ops`. */
export function titleFromBranch(branch: string): string {
  const tail = branch.replace(/^[^/]+\//, "").replace(/^mot-\d+-/i, "").replace(/-\d{6,}$/, "");
  const words = tail.split("-").filter(Boolean).join(" ");
  const ticket = ticketFromBranch(branch);
  return ticket ? `${ticket}: ${words}` : words;
}

function slugFromUrl(url: string): string | null {
  const m = url.match(/github\.com[:/](.+?)(?:\.git)?$/);
  return m ? m[1] : null;
}

/** `https://github.com/arniwesth/motoko_agent.git` -> `arniwesth/motoko_agent`. */
export function repoSlug(remote: string): string {
  const slug = slugFromUrl(git(["remote", "get-url", remote]));
  if (!slug) die(`remote '${remote}' does not look like a GitHub remote`);
  return slug;
}

/** Every GitHub remote, as `{ name, slug }`. The sync walks these (D5: both remotes). */
export function githubRemotes(): { name: string; slug: string }[] {
  const out: { name: string; slug: string }[] = [];
  for (const name of git(["remote"]).split("\n").filter(Boolean)) {
    const slug = slugFromUrl(git(["remote", "get-url", name]));
    if (slug) out.push({ name, slug });
  }
  return out;
}

/**
 * D6: the tuple (repo, pr) is authoritative and carries the full owner/repo
 * slug, so nothing depends on local remote names. The alias is a human-facing
 * directory name so colliding PR numbers across remotes stay legible — and
 * because it is only a name, an unknown slug can fall back to the owner.
 */
export function aliasForSlug(slug: string): string {
  const match = githubRemotes().find((r) => r.slug.toLowerCase() === slug.toLowerCase());
  return match ? match.name : slug.split("/")[0];
}

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

export function prDir(alias: string, number: number): string {
  return join(PRS_DIR, `${alias}-${number}`);
}

export function cacheDir(alias: string, number: number): string {
  return join(CACHE_DIR, `${alias}-${number}`);
}

export function writeFileMkdir(path: string, content: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
}

export function rel(path: string): string {
  return path.startsWith(REPO_ROOT + "/") ? path.slice(REPO_ROOT.length + 1) : path;
}

// ---------------------------------------------------------------------------
// Frontmatter
// ---------------------------------------------------------------------------

export function splitDocument(text: string): { frontmatter: string | null; body: string } {
  if (!text.startsWith("---\n")) return { frontmatter: null, body: text };
  const end = text.indexOf("\n---\n", 4);
  if (end === -1) return { frontmatter: null, body: text };
  return { frontmatter: text.slice(0, end + 5), body: text.slice(end + 5).replace(/^\n/, "") };
}

export function readFrontmatterField(frontmatter: string, key: string): string | null {
  const m = frontmatter.match(new RegExp(`^${key}: (.*)$`, "m"));
  return m ? m[1].trim() : null;
}

/** Render the usage block from a module's own leading block comment. */
export function usageFrom(moduleUrl: string): string {
  const header = readFileSync(fileURLToPath(moduleUrl), "utf8").split("*/")[0];
  return header.replace(/^#!.*\n/, "").replace(/^\/\*\*\n/, "").replace(/^ \* ?/gm, "");
}
