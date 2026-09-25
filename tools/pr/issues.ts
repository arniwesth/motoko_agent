#!/usr/bin/env bun
/**
 * issue — author an issue body as a file, publish it as the bot, and write the
 * issue number back.
 *
 *   draft ──────────> staging/issues/<slug>/body.md
 *             ──gh issue create──> GitHub
 *                                            │
 *   .agent/github/issues/<alias>-<n>/body.md <──write-back──┘
 *
 * The issue slimline of the PR driver (tools/pr/pr.ts), and the designed
 * follow-on ADR-001 D5 names: issues land at `.agent/github/issues/`, reusing
 * the same identity mechanism and the same author → publish → write-back rule
 * (D4). The artifact on disk is the source of truth; GitHub is transport.
 *
 * Identity follows mechanism (ADR-001 C9): everything this driver publishes
 * goes out as the bot unless `--as-operator`. `whoami` prints what a command
 * would resolve to before it acts, the same way `pr` does.
 *
 * Usage:
 *   issue draft [--remote origin] [--title "…"]   Stage a body from the template
 *   issue create [--remote origin] [--title "…"]  Draft if needed, publish, write back
 *   issue whoami [--as-bot]                       Report which account gh will act as
 *
 * Options:
 *   --remote <name>   Git remote to file the issue against (default: origin)
 *   --title <text>    Issue title (default: from the staged frontmatter)
 *   --force           Publish even with unfilled <!-- TODO --> placeholders
 *   --dry-run         Print what would be published; touch nothing on GitHub
 *   --as-operator     File the issue as you rather than as the bot
 *
 * Unlike a PR, an issue has no branch to adopt by, so crash recovery keys on
 * the title: `create` is re-runnable and adopts an existing issue whose title
 * matches rather than opening a duplicate.
 */

import { existsSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

import {
  type Identity,
  STAGING_DIR,
  GITHUB_DIR,
  aliasForSlug,
  die,
  gh,
  readFrontmatterField,
  rel,
  repoSlug,
  reportIdentity,
  setProgramName,
  splitDocument,
  usageFrom,
  writeFileMkdir,
} from "./lib.ts";

setProgramName("issue");

/** Unfilled template fields carry this marker; `create` refuses to publish them. */
const TODO = "<!-- TODO";

const ISSUES_DIR = join(GITHUB_DIR, "issues");

let AGENCY: Identity = "bot";

interface Options {
  remote: string;
  title: string | null;
  force: boolean;
  dryRun: boolean;
  asBot: boolean;
  asOperator: boolean;
}

// ---------------------------------------------------------------------------
// Template
// ---------------------------------------------------------------------------

/**
 * Fields are load-bearing rather than cosmetic for the same reason as a PR's:
 * a filled Summary / Context / Expected is what makes the issue joinable to the
 * ledger instead of an ordinary ticket. A single Summary is not enough — the
 * two other TODO fields are what keep the gate meaningful, mirroring the PR's
 * refusal to publish while any load-bearing field is open.
 */
function renderTemplate(): string {
  return [
    "## Summary",
    "",
    `${TODO}: what this issue is about, in two or three sentences. -->`,
    "",
    "## Context",
    "",
    `${TODO}: repro steps, evidence, and any links that ground the report. -->`,
    "",
    "## Expected",
    "",
    `${TODO}: what should happen once this is addressed, and how that can be checked. -->`,
    "",
  ].join("\n");
}

// ---------------------------------------------------------------------------
// Frontmatter
// ---------------------------------------------------------------------------

interface Frontmatter {
  repo: string;
  issue: number | null;
  title: string;
}

/**
 * Minimal on purpose (ADR-001 Consequences — the schema is provisional pending
 * 008 fork 2). The `issue` field is the write-back join key between the git
 * tree and GitHub.
 */
function renderFrontmatter(fm: Frontmatter): string {
  const lines = [
    "---",
    `repo: ${fm.repo}`,
    `issue: ${fm.issue ?? "null"}`,
    `title: ${JSON.stringify(fm.title)}`,
    "---",
  ];
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

/** `Hitting the step budget starts a FRESH session` -> lowercase slug. */
function slugForTitle(title: string): string {
  const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").trim();
  return slug || "issue";
}

/** The issue has no branch to key staging on, so the title slug keys it. */
function stagingPath(title: string): string {
  return join(STAGING_DIR, "issues", slugForTitle(title), "body.md");
}

function finalPath(remote: string, slug: string, number: number): string {
  return join(ISSUES_DIR, `${aliasForSlug(slug)}-${number}`, "body.md");
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

function cmdWhoami(opts: Options): void {
  const identity: Identity = opts.asBot ? "bot" : "operator";
  console.log(`${identity}: ${reportIdentity(identity)}`);
}

function cmdDraft(opts: Options): string {
  const slug = repoSlug(opts.remote);
  const title = opts.title;
  if (!title) die(`no title — pass --title (e.g. \`make issue_draft --title="what breaks and why"\`)`);
  const path = stagingPath(title);
  if (existsSync(path)) {
    console.log(`issue: staged body already exists at ${rel(path)} — edit it, then \`make issue\``);
    return path;
  }
  const fm: Frontmatter = { repo: slug, issue: null, title };
  writeFileMkdir(path, `${renderFrontmatter(fm)}\n\n${renderTemplate()}`);
  console.log(`issue: staged ${rel(path)} — fill every ${TODO} --> field, then \`make issue\``);
  return path;
}

/** The staged body's title, or null when nothing is staged / it has no frontmatter. */
function stagedTitle(title: string): string | null {
  const path = stagingPath(title);
  if (!existsSync(path)) return null;
  const doc = splitDocument(readFileSync(path, "utf8"));
  if (!doc.frontmatter) return null;
  const t = readFrontmatterField(doc.frontmatter, "title");
  return t ? (JSON.parse(t) as string) : null;
}

/**
 * Scan the staging dir for an already-staged issue body. An issue has no
 * branch to key on, so `create` recovers from a crash by reusing whatever body
 * is staged. Returns its frontmatter title, or null when nothing is staged.
 */
function findStagedTitle(): string | null {
  const dir = join(STAGING_DIR, "issues");
  if (!existsSync(dir)) return null;
  const found: string[] = [];
  for (const slug of readdirSync(dir)) {
    const p = join(dir, slug, "body.md");
    if (!existsSync(p)) continue;
    const t = stagedTitle(slug);
    if (t) found.push(t);
  }
  return found.length === 1 ? found[0] : null;
}

/** Any issue already open with the same title. Adoption is what makes `create` re-runnable. */
function findExistingIssue(slug: string, title: string): { number: number; url: string } | null {
  const r = gh([
    "issue", "list",
    "--repo", slug,
    "--state", "all",
    "--search", `"${title}" in:title`,
    "--json", "number,url,state,title",
    "--limit", "10",
  ], AGENCY);
  if (!r.ok) die(`gh issue list failed:\n${r.stderr}`);
  const issues = JSON.parse(r.stdout || "[]") as { number: number; url: string; state: string; title: string }[];
  if (issues.length === 0) return null;
  // Only adopt an exact (case-insensitive) title match; a partial fuzzy match
  // would attach the write-back to the wrong issue.
  const exact = issues.find((i) => i.title.toLowerCase() === title.toLowerCase());
  return exact ?? null;
}

/** Local, network-free gate: refuse a body that still has load-bearing fields open. */
function checkStagedFields(staged: string, opts: Options): void {
  const doc = splitDocument(readFileSync(staged, "utf8"));
  if (!doc.frontmatter) die(`${rel(staged)} has no frontmatter — delete it and re-run \`make issue_draft\``);
  if (doc.body.includes(TODO) && !opts.force) {
    const open = doc.body.split("\n").filter((l) => l.includes(TODO)).length;
    die(
      `${rel(staged)} still has ${open} unfilled field${open === 1 ? "" : "s"}. ` +
        `Summary, Context and Expected are load-bearing (ADR-001 D4). Fill them, or pass --force.`,
    );
  }
}

/** Move the staged body into its final home and record the number. This is the write-back. */
function finalize(
  staged: string | null,
  remote: string,
  slug: string,
  number: number,
): string {
  const dest = finalPath(remote, slug, number);
  if (existsSync(dest)) return dest;

  let body: string;
  let title: string;
  if (staged && existsSync(staged)) {
    const doc = splitDocument(readFileSync(staged, "utf8"));
    body = doc.body;
    title = doc.frontmatter
      ? JSON.parse(readFrontmatterField(doc.frontmatter, "title") ?? '"Issue"')
      : "Issue";
  } else {
    // Crash recovery: the issue exists but nothing was staged locally. GitHub
    // is transport, so the body can be pulled back to reconstruct the artifact.
    const r = gh(["issue", "view", String(number), "--repo", slug, "--json", "body,title"], AGENCY);
    if (!r.ok) die(`gh issue view failed:\n${r.stderr}`);
    const view = JSON.parse(r.stdout) as { body: string; title: string };
    body = view.body ?? "";
    title = view.title ?? "Issue";
  }

  const fm: Frontmatter = { repo: slug, issue: number, title };
  writeFileMkdir(dest, `${renderFrontmatter(fm)}\n\n${body}`);

  if (staged && existsSync(staged)) {
    rmSync(dirname(staged), { recursive: true, force: true });
    const parent = join(STAGING_DIR, "issues");
    if (existsSync(parent) && readdirSync(parent).length === 0) {
      rmSync(parent, { recursive: true, force: true });
      if (existsSync(STAGING_DIR) && readdirSync(STAGING_DIR).length === 0) rmSync(STAGING_DIR, { recursive: true });
    }
  }
  return dest;
}

function cmdCreate(opts: Options): void {
  const slug = repoSlug(opts.remote);

  // Resolve the title from --title, otherwise recover it from whatever is
  // already staged (crash recovery). An issue has no branch to derive one from.
  const title = opts.title ?? findStagedTitle();
  if (!title) die(`no title — pass --title or stage a body first (\`make issue_draft --title="…"\`)`);

  // Stage a template if nothing is staged yet, then run the local gate before
  // anything touches the network (same flow as `pr create`).
  const stagedPath_ = stagingPath(title);
  if (!existsSync(stagedPath_)) {
    cmdDraft({ ...opts, title });
  }
  const staged = stagingPath(title);
  if (!existsSync(staged)) die(`could not stage a body for '${title}'`);
  checkStagedFields(staged, opts);
  const doc = splitDocument(readFileSync(staged, "utf8"));
  if (!doc.frontmatter) die(`${rel(staged)} has no frontmatter — delete it and re-run \`make issue_draft\``);
  const effectiveTitle = stagedTitle(title) ?? title;

  const login = reportIdentity(AGENCY);
  console.log(`issue: acting as ${login} (${AGENCY}) on ${slug}`);

  // Adopt before creating. D4: a crash between publish and write-back leaves a
  // real issue with no local record, and a second issue is not a recoverable state.
  const existing = findExistingIssue(slug, effectiveTitle);
  if (existing) {
    const dest = finalize(staged, opts.remote, slug, existing.number);
    console.log(`issue: adopted existing #${existing.number} — ${existing.url}`);
    console.log(`issue: record at ${rel(dest)}`);
    return;
  }

  if (opts.dryRun) {
    console.log(`issue: --dry-run; would file "${effectiveTitle}" on ${slug}`);
    console.log(`issue: body from ${rel(staged)}`);
    return;
  }

  // The body goes as a file, not a flag — same rationale as PRs (D4).
  const bodyFile = join(dirname(staged), ".body-published.md");
  writeFileSync(bodyFile, doc.body);
  const created = gh([
    "issue", "create",
    "--repo", slug,
    "--title", effectiveTitle,
    "--body-file", bodyFile,
  ], AGENCY);
  rmSync(bodyFile, { force: true });
  if (!created.ok) die(`gh issue create failed:\n${created.stderr}`);

  const m = created.stdout.match(/\/(?:issues|pull)\/(\d+)/);
  if (!m) die(`could not read an issue number out of gh's output:\n${created.stdout}`);
  const number = Number(m[1]);

  const dest = finalize(staged, opts.remote, slug, number);
  console.log(`issue: created #${number} — ${created.stdout.split("\n").pop()}`);
  console.log(`issue: record at ${rel(dest)}`);
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function usage(): void {
  console.log(usageFrom(import.meta.url));
}

function main(argv: string[]): void {
  const opts: Options = { remote: "origin", title: null, force: false, dryRun: false, asBot: false, asOperator: false };
  const positional: string[] = [];

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "--remote": opts.remote = argv[++i] ?? die("--remote needs a value"); break;
      case "--title": opts.title = argv[++i] ?? die("--title needs a value"); break;
      case "--force": opts.force = true; break;
      case "--dry-run": opts.dryRun = true; break;
      case "--as-bot": opts.asBot = true; break;
      case "--as-operator": opts.asOperator = true; break;
      case "--help": case "-h": usage(); return;
      default:
        if (a.startsWith("-")) die(`unknown option: ${a}`);
        positional.push(a);
    }
  }

  if (opts.asOperator) AGENCY = "operator";

  switch (positional[0] ?? "create") {
    case "draft": cmdDraft(opts); break;
    case "create": cmdCreate(opts); break;
    case "whoami": cmdWhoami(opts); break;
    default: die(`unknown command: ${positional[0]} (try draft, create, whoami)`);
  }
}

main(process.argv.slice(2));
