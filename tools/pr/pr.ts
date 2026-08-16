#!/usr/bin/env bun
/**
 * pr — author a PR body as a file, publish it, and write the PR number back.
 *
 *   template ──draft──> staging/body.md ──gh pr create──> GitHub
 *                                              │
 *                            .agent/github/prs/<alias>-<n>/body.md <──write-back──┘
 *
 * The artifact on disk is the source of truth; GitHub is transport. That is
 * ADR-001 D4 (.agent/projects/016_github_ops/), and it is why the number comes
 * back into frontmatter: without a join key between the git tree and GitHub,
 * state cannot be linked to artifacts except by a human remembering.
 *
 * The body is staged outside its final home because the directory key
 * `<alias>-<n>` does not exist until the PR does. A crash between publish and
 * write-back therefore leaves a real PR with no local record, so `create` is
 * re-runnable: it adopts an existing PR for the branch rather than opening a
 * second one.
 *
 * Usage:
 *   pr draft [--base main] [--remote origin]   Stage a body from the template
 *   pr create [--base main] [--remote origin]  Draft if needed, publish, write back
 *   pr whoami [--as-bot]                       Report which account gh will act as
 *
 * Options:
 *   --base <branch>    Base branch for the PR and for the diff (default: main)
 *   --remote <name>    Git remote to open the PR against (default: origin)
 *   --title <text>     PR title (default: derived from the branch name)
 *   --force            Publish even with unfilled <!-- TODO --> placeholders
 *   --dry-run          Print what would be published; touch nothing on GitHub
 *
 * Identity (ADR-001 D1 — identity follows agency): a human decides to open a
 * PR, so this tool always acts as the *operator*, via the credential stored by
 * `gh auth login`. It strips GH_TOKEN/GITHUB_TOKEN from gh's environment to
 * guarantee that: gh silently prefers those over your stored login, so an
 * inherited one would publish your PR under the bot's name. The bot credential
 * arrives as MOTOKO_BOT_GH_TOKEN and is mapped into GH_TOKEN only where bot
 * agency is correct — `whoami --as-bot` here, and `pr-sync` next door.
 */

import { existsSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";

import {
  type Identity,
  REPO_ROOT,
  STAGING_DIR,
  currentBranch,
  die,
  gh,
  git,
  prDir,
  readFrontmatterField,
  rel,
  repoSlug,
  reportIdentity,
  splitDocument,
  ticketFromBranch,
  titleFromBranch,
  usageFrom,
  writeFileMkdir,
} from "./lib.ts";

/** Unfilled template fields carry this marker; `create` refuses to publish them. */
const TODO = "<!-- TODO";

interface Options {
  base: string;
  remote: string;
  title: string | null;
  force: boolean;
  dryRun: boolean;
  asBot: boolean;
}

// ---------------------------------------------------------------------------
// Template
// ---------------------------------------------------------------------------

/**
 * The five fields are load-bearing rather than cosmetic (ADR-001 D4).
 * Governing docs and Predicted outcome are what make a PR joinable to the
 * ledger; dropping them for brevity reduces this to an ordinary PR template.
 */
function renderTemplate(parts: { changes: string; governing: string }): string {
  return [
    "## Summary",
    "",
    `${TODO}: what this PR does and why, in two or three sentences. -->`,
    "",
    "## Changes",
    "",
    parts.changes,
    "",
    "## Governing docs",
    "",
    parts.governing,
    "",
    "## Predicted outcome",
    "",
    `${TODO}: what landing this should change, and how that will be checked. -->`,
    "",
    "## Test evidence",
    "",
    `${TODO}: commands run and their results. -->`,
    "",
  ].join("\n");
}

/**
 * Diff against the remote's base, not the local one. A local `main` that is
 * three weeks stale would list commits the PR does not actually contain, and
 * the Changes section would disagree with what a reviewer sees.
 */
function diffBase(remote: string, base: string): string {
  const tracked = `${remote}/${base}`;
  const r = spawnSync("git", ["-C", REPO_ROOT, "rev-parse", "--verify", "--quiet", `${tracked}^{commit}`], {
    encoding: "utf8",
  });
  return r.status === 0 ? tracked : base;
}

function changedFiles(base: string): string[] {
  const out = git(["diff", "--name-only", `${base}...HEAD`]);
  return out ? out.split("\n") : [];
}

function commitSubjects(base: string): string[] {
  const out = git(["log", "--reverse", "--format=%s", `${base}..HEAD`]);
  return out ? out.split("\n") : [];
}

function deriveChanges(base: string): string {
  const subjects = commitSubjects(base);
  const files = changedFiles(base);
  if (subjects.length === 0) die(`no commits on this branch vs ${base}`);
  const lines = subjects.map((s) => `- ${s}`);
  lines.push("", `${files.length} file${files.length === 1 ? "" : "s"} changed.`);
  return lines.join("\n");
}

/**
 * Governing docs are derived, not invented: every `.agent/projects/` document
 * this branch touches is a doc that governs it. An empty result is left as a
 * placeholder rather than an empty section — a PR with no governing doc is a
 * thing to state deliberately, not to omit silently.
 */
function deriveGoverningDocs(base: string): string {
  const docs = changedFiles(base)
    .filter((f) => f.startsWith(".agent/projects/") && f.endsWith(".md"))
    .sort();
  if (docs.length === 0) {
    return `${TODO}: link the .agent/projects/ documents that govern this change. -->`;
  }
  return docs.map((d) => `- \`${d}\``).join("\n");
}

// ---------------------------------------------------------------------------
// Frontmatter
// ---------------------------------------------------------------------------

interface Frontmatter {
  repo: string;
  pr: number | null;
  branch: string;
  ticket: string | null;
  title: string;
}

/**
 * Provisional and minimal on purpose: 008 fork 2 (how much frontmatter, in what
 * format) is still open, so this is the least that makes the write-back work.
 * Expect one conforming migration when 008 lands.
 */
function renderFrontmatter(fm: Frontmatter): string {
  const lines = [
    "---",
    `repo: ${fm.repo}`,
    `pr: ${fm.pr ?? "null"}`,
    `branch: ${fm.branch}`,
    `ticket: ${fm.ticket ?? "null"}`,
    `title: ${JSON.stringify(fm.title)}`,
    "---",
  ];
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

function slugForBranch(branch: string): string {
  return branch.replace(/[^A-Za-z0-9._-]+/g, "-");
}

function stagingPath(branch: string): string {
  return join(STAGING_DIR, slugForBranch(branch), "body.md");
}

function finalPath(remote: string, number: number): string {
  return join(prDir(remote, number), "body.md");
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

function cmdWhoami(opts: Options): void {
  const identity: Identity = opts.asBot ? "bot" : "operator";
  console.log(`${identity}: ${reportIdentity(identity)}`);
}

function cmdDraft(opts: Options): string {
  const branch = currentBranch();
  const path = stagingPath(branch);
  if (existsSync(path)) {
    console.log(`pr: staged body already exists at ${rel(path)} — edit it, then \`make pr\``);
    return path;
  }
  const fm: Frontmatter = {
    repo: repoSlug(opts.remote),
    pr: null,
    branch,
    ticket: ticketFromBranch(branch),
    title: opts.title ?? titleFromBranch(branch),
  };
  const against = diffBase(opts.remote, opts.base);
  const body = renderTemplate({
    changes: deriveChanges(against),
    governing: deriveGoverningDocs(against),
  });
  writeFileMkdir(path, `${renderFrontmatter(fm)}\n\n${body}`);
  console.log(`pr: staged ${rel(path)} — fill every ${TODO} --> field, then \`make pr\``);
  return path;
}

/** Any PR already open for this branch. Adoption is what makes `create` re-runnable. */
function findExistingPr(slug: string, branch: string): { number: number; url: string } | null {
  const r = gh([
    "pr", "list",
    "--repo", slug,
    "--head", branch,
    "--state", "all",
    "--json", "number,url,state",
    "--limit", "10",
  ]);
  if (!r.ok) die(`gh pr list failed:\n${r.stderr}`);
  const prs = JSON.parse(r.stdout || "[]") as { number: number; url: string; state: string }[];
  if (prs.length === 0) return null;
  // Prefer an open PR; a closed one still counts as "already created" for the
  // purpose of not opening a duplicate.
  return prs.find((p) => p.state === "OPEN") ?? prs[0];
}

/** Move the staged body into its final home and record the number. This is the write-back. */
function finalize(staged: string | null, remote: string, slug: string, branch: string, number: number): string {
  const dest = finalPath(remote, number);
  if (existsSync(dest)) return dest;

  let body: string;
  let title: string;
  if (staged && existsSync(staged)) {
    const doc = splitDocument(readFileSync(staged, "utf8"));
    body = doc.body;
    const staged_title = doc.frontmatter ? JSON.parse(readFrontmatterField(doc.frontmatter, "title") ?? '""') : "";
    title = staged_title || titleFromBranch(branch);
  } else {
    // Crash recovery: the PR exists but nothing was staged locally. GitHub is
    // transport, so the body can be pulled back to reconstruct the artifact.
    const r = gh(["pr", "view", String(number), "--repo", slug, "--json", "body,title"]);
    if (!r.ok) die(`gh pr view failed:\n${r.stderr}`);
    const view = JSON.parse(r.stdout) as { body: string; title: string };
    body = view.body ?? "";
    title = view.title ?? titleFromBranch(branch);
  }

  const fm: Frontmatter = { repo: slug, pr: number, branch, ticket: ticketFromBranch(branch), title };
  writeFileMkdir(dest, `${renderFrontmatter(fm)}\n\n${body}`);

  if (staged && existsSync(staged)) {
    rmSync(dirname(staged), { recursive: true, force: true });
    if (existsSync(STAGING_DIR) && readdirSync(STAGING_DIR).length === 0) rmSync(STAGING_DIR, { recursive: true });
  }
  return dest;
}

/** Local, network-free gate: refuse a body that still has load-bearing fields open. */
function checkStagedFields(staged: string, opts: Options): void {
  const doc = splitDocument(readFileSync(staged, "utf8"));
  if (!doc.frontmatter) die(`${rel(staged)} has no frontmatter — delete it and re-run \`make pr_draft\``);
  if (doc.body.includes(TODO) && !opts.force) {
    const open = doc.body.split("\n").filter((l) => l.includes(TODO)).length;
    die(
      `${rel(staged)} still has ${open} unfilled field${open === 1 ? "" : "s"}. ` +
        `Summary, Changes, Governing docs, Predicted outcome and Test evidence are all load-bearing ` +
        `(ADR-001 D4). Fill them, or pass --force.`,
    );
  }
}

function cmdCreate(opts: Options): void {
  const branch = currentBranch();
  const slug = repoSlug(opts.remote);

  // Cheap local checks before anything touches the network, so a half-filled
  // body fails in milliseconds rather than after two API round trips.
  if (existsSync(stagingPath(branch))) checkStagedFields(stagingPath(branch), opts);

  const login = reportIdentity("operator");
  console.log(`pr: acting as ${login} (operator) on ${slug}`);

  // Adopt before creating. D4: a crash between publish and write-back leaves a
  // real PR with no local record, and a second PR is not a recoverable state.
  const existing = findExistingPr(slug, branch);
  if (existing) {
    const dest = finalize(stagingPath(branch), opts.remote, slug, branch, existing.number);
    console.log(`pr: adopted existing #${existing.number} — ${existing.url}`);
    console.log(`pr: record at ${rel(dest)}`);
    return;
  }

  const staged = existsSync(stagingPath(branch)) ? stagingPath(branch) : cmdDraft(opts);
  checkStagedFields(staged, opts);
  const doc = splitDocument(readFileSync(staged, "utf8"));
  if (!doc.frontmatter) die(`${rel(staged)} has no frontmatter — delete it and re-run \`make pr_draft\``);

  const title = JSON.parse(readFrontmatterField(doc.frontmatter, "title") ?? '""') || titleFromBranch(branch);

  if (opts.dryRun) {
    console.log(`pr: --dry-run; would create "${title}" on ${slug} (base ${opts.base}, head ${branch})`);
    console.log(`pr: body from ${rel(staged)}`);
    return;
  }

  // Push first: `gh pr create` needs the head branch to exist on the remote.
  const pushed = spawnSync("git", ["-C", REPO_ROOT, "push", "-u", opts.remote, branch], { stdio: "inherit" });
  if (pushed.status !== 0) die(`git push to ${opts.remote} failed`);

  // The body goes as a file, not a flag: `gh pr create` applies web templates
  // only interactively, and a web template cannot be machine-filled (D4).
  const bodyFile = join(dirname(staged), ".body-published.md");
  writeFileSync(bodyFile, doc.body);
  const created = gh([
    "pr", "create",
    "--repo", slug,
    "--base", opts.base,
    "--head", branch,
    "--title", title,
    "--body-file", bodyFile,
  ]);
  rmSync(bodyFile, { force: true });
  if (!created.ok) die(`gh pr create failed:\n${created.stderr}`);

  const m = created.stdout.match(/\/pull\/(\d+)/);
  if (!m) die(`could not read a PR number out of gh's output:\n${created.stdout}`);
  const number = Number(m[1]);

  const dest = finalize(staged, opts.remote, slug, branch, number);
  console.log(`pr: created #${number} — ${created.stdout.split("\n").pop()}`);
  console.log(`pr: record at ${rel(dest)}`);
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function usage(): void {
  console.log(usageFrom(import.meta.url));
}

function main(argv: string[]): void {
  const opts: Options = { base: "main", remote: "origin", title: null, force: false, dryRun: false, asBot: false };
  const positional: string[] = [];

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "--base": opts.base = argv[++i] ?? die("--base needs a value"); break;
      case "--remote": opts.remote = argv[++i] ?? die("--remote needs a value"); break;
      case "--title": opts.title = argv[++i] ?? die("--title needs a value"); break;
      case "--force": opts.force = true; break;
      case "--dry-run": opts.dryRun = true; break;
      case "--as-bot": opts.asBot = true; break;
      case "--help": case "-h": usage(); return;
      default:
        if (a.startsWith("-")) die(`unknown option: ${a}`);
        positional.push(a);
    }
  }

  switch (positional[0] ?? "create") {
    case "draft": cmdDraft(opts); break;
    case "create": cmdCreate(opts); break;
    case "whoami": cmdWhoami(opts); break;
    default: die(`unknown command: ${positional[0]} (try draft, create, whoami)`);
  }
}

main(process.argv.slice(2));
