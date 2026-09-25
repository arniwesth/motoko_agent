#!/usr/bin/env bun
/**
 * pr-sync — fetch PR comments from both remotes and record which ones exist.
 *
 *   GitHub ──fetch──> .agent/github/cache/<alias>-<n>/*.json   (gitignored, regenerable)
 *                                    │
 *                                    └──reconcile──> prs/<alias>-<n>/state.yaml  (git-versioned)
 *
 * The two halves are separated by an invariant, not by convenience (ADR-001 D3):
 *
 *     Sync only adds facts; only the loop changes judgments.
 *
 * So this tool appends a `pending` record for every comment it has never seen,
 * and otherwise touches nothing. It never rewrites a status, a rank, a reason
 * or an artifact link — including its own from a previous run. When a comment
 * has been edited since it was last seen it sets `stale: true` *alongside* the
 * existing disposition rather than rewinding it, leaving a triage queue for the
 * loop to adjudicate. Deleting the cache must lose nothing.
 *
 * Usage:
 *   pr-sync [--remote origin] [--pr 97] [--state open|all] [--dry-run]
 *
 * Options:
 *   --remote <name>   Only this remote (default: every GitHub remote — D5)
 *   --pr <n>          Only this PR number; requires --remote
 *   --state <s>       open (default) or all
 *   --ours <login>    Extra login to treat as ours, repeatable (default: origin's
 *                     owner and the bot — see ourLogins)
 *   --dry-run         Fetch and report; write neither cache nor state
 *   --quiet           Only print PRs where something changed
 *
 * Identity (ADR-001 D1): the sync is an action the pipeline produces, not one a
 * human decided, so it acts as the machine user via MOTOKO_BOT_GH_TOKEN. Read
 * access is all it needs; it never posts.
 *
 * Reviews (the approve / request-changes envelope) are cached but deliberately
 * get no state record. GitHub exposes `submitted_at` for them and no
 * `updated_at`, so an edited review body is undetectable — and a record whose
 * staleness cannot be computed is exactly the silently-stale judgment D3's
 * pairing rule exists to prevent. The count is reported so the gap is visible
 * rather than implied.
 */

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

import {
  type Record,
  get,
  readState,
  renderState,
  set,
} from "./state.ts";
import {
  CACHE_DIR,
  cacheDir,
  die,
  ghJson,
  githubRemotes,
  prDir,
  reportIdentity,
  rel,
  repoSlug,
  setProgramName,
  usageFrom,
  writeFileMkdir,
} from "./lib.ts";

setProgramName("pr-sync");

interface Options {
  remote: string | null;
  pr: number | null;
  state: "open" | "all";
  dryRun: boolean;
  quiet: boolean;
  ours: string[];
}

/** The comment kinds that can support the staleness rule. See the header. */
type Kind = "issue_comment" | "review_comment";

interface Comment {
  kind: Kind;
  id: number;
  updated_at: string;
  user: string;
}

// ---------------------------------------------------------------------------
// Fetch
// ---------------------------------------------------------------------------

function paginate<T>(path: string): T[] {
  return ghJson<T[][]>(["api", path, "--paginate", "--slurp"], "bot").flat();
}

interface RawComment {
  id: number;
  updated_at?: string;
  created_at?: string;
  user?: { login?: string };
}

/**
 * Our own writing is not an inbound claim, and queueing it for triage is how a
 * queue stops being worked (C5: 7 of 11 records were ours before this).
 *
 * "Ours" is the **owner of `origin`** plus the bot. `origin` is the operator's
 * own fork under this project's topology (D1, D5), so its owner is the operator
 * by construction — derivable, no login list to keep current.
 *
 * Note what this deliberately is NOT: "the PR's author". That heuristic looks
 * equivalent and is not. `sunholo-voight-kampff` both authors PRs on this fork
 * and reviews them, so keying on PR authorship drops the inbound review on #97
 * — the one record this whole project is motivated by — while keeping our own
 * response as a pending claim. Measured, not reasoned: it inverted 6 of 11.
 *
 * Nothing is lost either way; the cache still holds every comment, and D3 puts
 * facts there anyway.
 */
function ourLogins(botLogin: string, extra: string[]): Set<string> {
  const ours = new Set<string>([botLogin, ...extra].filter(Boolean));
  const origin = githubRemotes().find((r) => r.name === "origin");
  if (origin) ours.add(origin.slug.split("/")[0]);
  return ours;
}

function fetchComments(
  slug: string,
  n: number,
): { comments: Comment[]; raw: Map<string, unknown> } {
  const issue = paginate<RawComment>(`repos/${slug}/issues/${n}/comments?per_page=100`);
  const review = paginate<RawComment>(`repos/${slug}/pulls/${n}/comments?per_page=100`);
  const reviews = paginate<unknown>(`repos/${slug}/pulls/${n}/reviews?per_page=100`);
  const pr = ghJson<unknown>(["api", `repos/${slug}/pulls/${n}`], "bot");

  const toComment = (kind: Kind) => (c: RawComment): Comment => ({
    kind,
    id: c.id,
    updated_at: c.updated_at ?? c.created_at ?? "",
    user: c.user?.login ?? "",
  });

  return {
    comments: [...issue.map(toComment("issue_comment")), ...review.map(toComment("review_comment"))],
    raw: new Map<string, unknown>([
      ["pr.json", pr],
      ["issue-comments.json", issue],
      ["review-comments.json", review],
      ["reviews.json", reviews],
    ]),
  };
}

// ---------------------------------------------------------------------------
// Reconcile
// ---------------------------------------------------------------------------

interface Result {
  added: number;
  staled: number;
  reviewsSkipped: number;
  oursSkipped: number;
  warnings: string[];
}

/**
 * D6 says the tuple is authoritative and the directory name is for humans — so
 * the redundancy between them is checkable rather than trusted. A record that
 * disagrees with its own directory is reported, never silently corrected.
 */
function auditRecord(rec: Record, slug: string, n: number, where: string, warnings: string[]): void {
  const id = get(rec, "comment_id") ?? "(pr-level)";
  if (get(rec, "status") === "dismissed" && !get(rec, "reason")) {
    warnings.push(`${where}: comment ${id} is dismissed with no reason — invalid per D3`);
  }
  // D4: `responded` requires *both* the artifact link and the posted-comment
  // key. One without the other is a half-recorded response — the artifact with
  // no key cannot be reconciled against GitHub, the key with no artifact has
  // no authored source. See C4.
  if (get(rec, "status") === "responded") {
    const missing = ["artifact", "response_comment_id"].filter((f) => !get(rec, f));
    if (missing.length) {
      warnings.push(`${where}: comment ${id} is responded but missing ${missing.join(" and ")} — invalid per D4`);
    }
  }
  const recRepo = get(rec, "repo");
  if (recRepo && recRepo !== slug) warnings.push(`${where}: comment ${id} claims repo ${recRepo}, directory says ${slug}`);
  const recPr = get(rec, "pr");
  if (recPr && recPr !== String(n)) warnings.push(`${where}: comment ${id} claims pr ${recPr}, directory says ${n}`);
}

function syncPr(alias: string, slug: string, n: number, ours: Set<string>, opts: Options): Result {
  const { comments, raw } = fetchComments(slug, n);
  const result: Result = {
    added: 0,
    staled: 0,
    reviewsSkipped: (raw.get("reviews.json") as unknown[]).filter(Boolean).length,
    oursSkipped: 0,
    warnings: [],
  };

  if (!opts.dryRun) {
    for (const [name, value] of raw) writeFileMkdir(join(cacheDir(alias, n), name), `${JSON.stringify(value, null, 2)}\n`);
  }

  const statePath = join(prDir(alias, n), "state.yaml");
  const records = readState(statePath);
  const where = rel(statePath);
  for (const rec of records) auditRecord(rec, slug, n, where, result.warnings);

  for (const c of comments) {
    if (ours.has(c.user)) {
      result.oursSkipped++;
      continue;
    }
    const existing = records.find(
      (r) => get(r, "comment_id") === String(c.id) && (get(r, "kind") ?? "issue_comment") === c.kind,
    );

    if (!existing) {
      records.push([
        ["repo", slug],
        ["pr", String(n)],
        ["kind", c.kind],
        ["comment_id", String(c.id)],
        ["status", "pending"],
        ["seen_updated_at", c.updated_at],
      ]);
      result.added++;
      continue;
    }

    // Everything below this line must leave judgment fields untouched.
    const seen = get(existing, "seen_updated_at");
    if (seen && c.updated_at > seen && get(existing, "stale") !== "true") {
      set(existing, "stale", "true");
      result.staled++;
    }
  }

  if (records.length === 0) return result; // D2: a PR with no comments gets no state.yaml.

  const rendered = renderState(records);
  const unchanged = existsSync(statePath) && readFileSync(statePath, "utf8") === rendered;
  if (!opts.dryRun && !unchanged) writeFileMkdir(statePath, rendered);

  return result;
}

// ---------------------------------------------------------------------------
// Command
// ---------------------------------------------------------------------------

function cmdSync(opts: Options): void {
  // Recorded once so `pr-loop list` can say what its ages are relative to.
  const stampedAt = new Date().toISOString();
  const login = reportIdentity("bot");
  console.log(`pr-sync: acting as ${login} (bot)${opts.dryRun ? " — dry run, writing nothing" : ""}`);

  const ours = ourLogins(login, opts.ours);
  console.log(`pr-sync: treating as ours (not queued): ${[...ours].sort().join(", ")}`);

  const remotes = opts.remote ? [{ name: opts.remote, slug: repoSlug(opts.remote) }] : githubRemotes();
  if (remotes.length === 0) die("no GitHub remotes found");
  if (opts.pr !== null && !opts.remote) die("--pr requires --remote, since PR numbers collide across remotes");

  const totals = { prs: 0, added: 0, staled: 0, reviewsSkipped: 0, oursSkipped: 0 };
  const warnings: string[] = [];

  for (const { name, slug } of remotes) {
    const numbers =
      opts.pr !== null
        ? [opts.pr]
        : ghJson<{ number: number }[]>(
            ["api", `repos/${slug}/pulls?state=${opts.state}&per_page=100`, "--paginate", "--slurp"],
            "bot",
          )
            .flat()
            .map((p) => p.number)
            .sort((a, b) => a - b);

    console.log(`pr-sync: ${slug} (${name}) — ${numbers.length} ${opts.state} PR${numbers.length === 1 ? "" : "s"}`);

    for (const n of numbers) {
      const r = syncPr(name, slug, n, ours, opts);
      totals.prs++;
      totals.added += r.added;
      totals.staled += r.staled;
      totals.reviewsSkipped += r.reviewsSkipped;
      totals.oursSkipped += r.oursSkipped;
      warnings.push(...r.warnings);
      const changed = r.added || r.staled;
      if (changed || !opts.quiet) {
        const bits = [`${r.added} new`, `${r.staled} newly stale`];
        if (r.reviewsSkipped) bits.push(`${r.reviewsSkipped} review${r.reviewsSkipped === 1 ? "" : "s"} not recorded`);
        console.log(`  ${name}-${n}: ${bits.join(", ")}`);
      }
    }
  }

  if (!opts.dryRun) writeFileMkdir(join(CACHE_DIR, ".synced"), `${stampedAt}\n`);

  console.log(
    `pr-sync: ${totals.prs} PR${totals.prs === 1 ? "" : "s"}, ${totals.added} new record${totals.added === 1 ? "" : "s"}, ` +
      `${totals.staled} newly stale`,
  );
  if (totals.oursSkipped) {
    console.log(
      `pr-sync: ${totals.oursSkipped} comment${totals.oursSkipped === 1 ? "" : "s"} authored by us ` +
        `left out of the queue as ours — cached, not inbound claims (C5).`,
    );
  }
  if (totals.reviewsSkipped) {
    console.log(
      `pr-sync: ${totals.reviewsSkipped} review bodies cached but not recorded — GitHub exposes no updated_at ` +
        `for reviews, so their staleness cannot be computed (see the header).`,
    );
  }
  for (const w of warnings) console.error(`pr-sync: warning — ${w}`);
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function main(argv: string[]): void {
  const opts: Options = { remote: null, pr: null, state: "open", dryRun: false, quiet: false, ours: [] };

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "--remote": opts.remote = argv[++i] ?? die("--remote needs a value"); break;
      case "--pr": opts.pr = Number(argv[++i] ?? die("--pr needs a value")); break;
      case "--state": {
        const v = argv[++i];
        if (v !== "open" && v !== "all") die("--state must be open or all");
        opts.state = v;
        break;
      }
      case "--ours": opts.ours.push(argv[++i] ?? die("--ours needs a login")); break;
      case "--dry-run": opts.dryRun = true; break;
      case "--quiet": opts.quiet = true; break;
      case "--help": case "-h": console.log(usageFrom(import.meta.url)); return;
      default: die(`unknown option: ${a}`);
    }
  }

  if (opts.pr !== null && !Number.isInteger(opts.pr)) die("--pr must be a number");
  cmdSync(opts);
}

main(process.argv.slice(2));
