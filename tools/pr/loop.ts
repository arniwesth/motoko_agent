#!/usr/bin/env bun
/**
 * pr-loop — work the queue `pr-sync` fills: rank, dismiss, respond.
 *
 *   state.yaml (pending|stale) ──queue──> a session ranks and tests
 *                                              │
 *                        response-<id>.md ──respond──> GitHub, as the bot
 *                                              │
 *                        response_comment_id written back into state.yaml
 *
 * This is the other half of ADR-001 D3's pairing rule. `pr-sync` may only add
 * facts; this tool is the *only* thing that changes a judgment. It exists as a
 * tool rather than leaving a session to hand-edit YAML because the record
 * carries invariants a human editor silently breaks — D3 makes `reason`
 * mandatory on a dismissal, D4 makes the artifact and the posted-comment key
 * jointly mandatory on a response, and an unquoted `#` truncates a reason
 * outright (ADR correction C8, which is exactly how this document lost one).
 *
 * Automation stays at degree 1 (ADR-001 Consequences): every judgment here is
 * supplied by whoever runs it. Nothing is ranked, dismissed or posted on its
 * own, and `respond` will not publish without `--post`.
 *
 * Usage:
 *   pr-loop queue [--remote origin] [--pr 97]   What needs attention
 *   pr-loop show <comment_id>                   Full comment text from the cache
 *   pr-loop set <comment_id> --status ranked --rank high
 *   pr-loop set <comment_id> --status dismissed --reason "superseded by #154"
 *   pr-loop set <comment_id> --affirm           Re-affirm a stale record
 *   pr-loop review <comment_id>                  Write comment + reply to one file
 *   pr-loop respond <comment_id> [--artifact p] [--post]
 *
 * Options:
 *   --status <s>      pending | ranked | claim-tested | responded | dismissed
 *   --rank <r>        high | medium | low
 *   --reason <text>   Mandatory when dismissing
 *   --artifact <path> Response body (default: the PR dir's response-<id>.md)
 *   --affirm          Clear `stale` and bump seen_updated_at to what is cached
 *   --post            Actually publish. Without it, `respond` only shows.
 *   --force           Let `respond` post again over an existing response key
 *
 * Identity (ADR-001 D1): responses are actions the pipeline produces, so they
 * go out as the machine user. Ranking and dismissing touch only local files and
 * need no credential at all.
 */

import { existsSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { join } from "node:path";

import { type Record, get, readState, renderState, set } from "./state.ts";
import {
  PRS_DIR,
  cacheDir,
  die,
  gh,
  prDir,
  rel,
  reportIdentity,
  setProgramName,
  splitDocument,
  usageFrom,
  writeFileMkdir,
} from "./lib.ts";

setProgramName("pr-loop");

const STATUSES = ["pending", "ranked", "claim-tested", "responded", "dismissed"];
const RANKS = ["high", "medium", "low"];

interface Options {
  remote: string | null;
  pr: number | null;
  status: string | null;
  rank: string | null;
  reason: string | null;
  artifact: string | null;
  affirm: boolean;
  post: boolean;
  force: boolean;
}

// ---------------------------------------------------------------------------
// Locating records
// ---------------------------------------------------------------------------

interface Located {
  rec: Record;
  records: Record[];
  statePath: string;
  alias: string;
  slug: string;
  pr: number;
}

function prDirs(opts: Options): { alias: string; number: number; dir: string }[] {
  if (!existsSync(PRS_DIR)) return [];
  return readdirSync(PRS_DIR)
    .map((name) => {
      const m = name.match(/^(.+)-(\d+)$/);
      return m ? { alias: m[1], number: Number(m[2]), dir: join(PRS_DIR, name) } : null;
    })
    .filter((d): d is { alias: string; number: number; dir: string } => d !== null)
    .filter((d) => (opts.remote ? d.alias === opts.remote : true))
    .filter((d) => (opts.pr !== null ? d.number === opts.pr : true))
    .sort((a, b) => a.alias.localeCompare(b.alias) || a.number - b.number);
}

function locate(commentId: string, opts: Options): Located {
  const hits: Located[] = [];
  for (const d of prDirs(opts)) {
    const statePath = join(d.dir, "state.yaml");
    if (!existsSync(statePath)) continue;
    const records = readState(statePath);
    for (const rec of records) {
      if (get(rec, "comment_id") === commentId) {
        hits.push({ rec, records, statePath, alias: d.alias, slug: get(rec, "repo") ?? "", pr: d.number });
      }
    }
  }
  if (hits.length === 0) die(`no record for comment ${commentId} — run \`make pr_sync\` first`);
  // D6: the alias is a human-facing name and PR numbers collide across remotes,
  // so an id matching in two trees is ambiguous rather than merely surprising.
  if (hits.length > 1) {
    die(
      `comment ${commentId} matches ${hits.length} records ` +
        `(${hits.map((h) => `${h.alias}-${h.pr}`).join(", ")}) — narrow with --remote/--pr`,
    );
  }
  return hits[0];
}

/** Cached facts for a comment. Absent cache is a prompt to sync, not an error. */
function cached(alias: string, n: number, commentId: string): { user: string; updated_at: string; body: string; url: string } | null {
  for (const file of ["issue-comments.json", "review-comments.json"]) {
    const path = join(cacheDir(alias, n), file);
    if (!existsSync(path)) continue;
    const list = JSON.parse(readFileSync(path, "utf8")) as {
      id: number;
      user?: { login?: string };
      updated_at?: string;
      body?: string;
      html_url?: string;
    }[];
    const hit = list.find((c) => String(c.id) === commentId);
    if (hit) {
      return {
        user: hit.user?.login ?? "",
        updated_at: hit.updated_at ?? "",
        body: hit.body ?? "",
        url: hit.html_url ?? "",
      };
    }
  }
  return null;
}

function writeRecords(statePath: string, records: Record[]): void {
  writeFileMkdir(statePath, renderState(records));
}

// ---------------------------------------------------------------------------
// queue / show
// ---------------------------------------------------------------------------

function cmdQueue(opts: Options): void {
  let open = 0;
  let total = 0;

  for (const d of prDirs(opts)) {
    const statePath = join(d.dir, "state.yaml");
    if (!existsSync(statePath)) continue;
    const records = readState(statePath);
    const needing = records.filter((r) => get(r, "status") === "pending" || get(r, "stale") === "true");
    total += records.length;
    if (needing.length === 0) continue;

    console.log(`\n${d.alias}-${d.number}  (${rel(d.dir)})`);
    for (const rec of needing) {
      open++;
      const id = get(rec, "comment_id") ?? "?";
      const c = cached(d.alias, d.number, id);
      const flags = [get(rec, "status") ?? "?", get(rec, "stale") === "true" ? "STALE" : null]
        .filter(Boolean)
        .join(" ");
      console.log(`  ${id}  [${flags}]  ${c ? `${c.user}  ${c.updated_at.slice(0, 10)}` : "(not cached — run make pr_sync)"}`);
      if (c) {
        const first = c.body.split("\n").find((l) => l.trim()) ?? "";
        console.log(`      ${first.slice(0, 96)}${first.length > 96 ? "…" : ""}`);
      }
    }
  }

  console.log(
    open === 0
      ? `\npr-loop: nothing needs attention (${total} record${total === 1 ? "" : "s"} all dispositioned)`
      : `\npr-loop: ${open} of ${total} record${total === 1 ? "" : "s"} need attention`,
  );
}

function cmdShow(commentId: string, opts: Options): void {
  const found = locate(commentId, opts);
  const c = cached(found.alias, found.pr, commentId);
  console.log(`# ${found.alias}-${found.pr}  comment ${commentId}`);
  for (const [k, v] of found.rec) console.log(`${k}: ${v}`);
  if (!c) {
    console.log(`\n(not in the cache — run \`make pr_sync\`)`);
    return;
  }
  console.log(`\nauthor: ${c.user}\nupdated: ${c.updated_at}\nurl: ${c.url}\n\n---\n${c.body}`);
}

// ---------------------------------------------------------------------------
// set — the judgment write path
// ---------------------------------------------------------------------------

function cmdSet(commentId: string, opts: Options): void {
  const found = locate(commentId, opts);
  const { rec } = found;

  if (!opts.status && !opts.rank && !opts.affirm) {
    die("nothing to set — pass --status, --rank or --affirm");
  }
  if (opts.status === "responded") {
    die("use `pr-loop respond` — `responded` needs the posted-comment key, which only posting produces (D4)");
  }
  if (opts.status && !STATUSES.includes(opts.status)) die(`--status must be one of: ${STATUSES.join(", ")}`);
  if (opts.rank && !RANKS.includes(opts.rank)) die(`--rank must be one of: ${RANKS.join(", ")}`);

  const status = opts.status ?? get(rec, "status");
  if (status === "dismissed" && !opts.reason && !get(rec, "reason")) {
    // D3 / 015 §6 Q1: a dismissal without a reason is what lets a later session
    // re-litigate a comment someone already thought about.
    die("dismissing needs --reason — a dismissal without one is an invalid record (D3)");
  }

  if (opts.status) set(rec, "status", opts.status);
  if (opts.rank) set(rec, "rank", opts.rank);
  if (opts.reason) set(rec, "reason", opts.reason);

  if (opts.affirm) {
    // D3's stale rule: the loop diffs cached against current, then either
    // re-affirms (bump seen_updated_at, clear the flag) or genuinely reopens.
    const c = cached(found.alias, found.pr, commentId);
    if (!c) die("cannot affirm without the cached comment — run `make pr_sync` first");
    set(rec, "seen_updated_at", c.updated_at);
    const staleAt = rec.findIndex(([k]) => k === "stale");
    if (staleAt !== -1) rec.splice(staleAt, 1);
  }

  writeRecords(found.statePath, found.records);
  console.log(`pr-loop: ${rel(found.statePath)} — comment ${commentId} is now ${get(rec, "status")}`);
}

// ---------------------------------------------------------------------------
// respond — author -> publish -> write back the key (D4)
// ---------------------------------------------------------------------------

function cmdRespond(commentId: string, opts: Options): void {
  const found = locate(commentId, opts);
  const { rec } = found;

  const existing = get(rec, "response_comment_id");
  if (existing && !opts.force) {
    // C4's whole purpose. There is no natural query for "did I already post
    // this?", so the written-back key is the only thing standing between a
    // crash-and-retry and a duplicate comment on someone else's PR.
    die(`comment ${commentId} already has response_comment_id ${existing} — refusing to post twice (--force overrides)`);
  }

  const artifact = opts.artifact ?? join(prDir(found.alias, found.pr), `response-${commentId}.md`);
  if (!existsSync(artifact)) {
    die(`no response artifact at ${rel(artifact)} — author it first, or pass --artifact`);
  }
  const body = splitDocument(readFileSync(artifact, "utf8")).body.trim();
  if (!body) die(`${rel(artifact)} has no body`);

  const slug = get(rec, "repo") ?? die("record has no repo");

  if (!opts.post) {
    // This output *is* the review gate, so it shows the whole body — never an
    // excerpt, which would ask someone to approve text they have not seen — and
    // the comment being answered above it. A reply read without the thing it
    // replies to cannot actually be judged.
    const rule = "─".repeat(72);
    const inbound = cached(found.alias, found.pr, commentId);
    console.log(`pr-loop: would post as the bot to ${slug}#${found.pr}, replying to comment ${commentId}`);
    if (inbound) {
      console.log(`\nIN REPLY TO — ${inbound.user}, ${inbound.updated_at.slice(0, 10)}`);
      console.log(`${inbound.url}\n${rule}\n${inbound.body.trim()}\n${rule}`);
    }
    console.log(`\nRESPONSE — ${rel(artifact)}, ${body.split("\n").length} lines, ${body.length} chars`);
    console.log(`${rule}\n${body}\n${rule}`);
    console.log(`\npr-loop: nothing posted. Review options:`);
    console.log(`  open ${rel(artifact)}                    edit it directly`);
    console.log(`  make pr_review ID=${commentId}            write a side-by-side review file`);
    console.log(`  make pr_respond ID=${commentId} POST=1    publish, as the bot`);
    return;
  }


  const login = reportIdentity("bot");
  console.log(`pr-loop: posting as ${login} (bot) to ${slug}#${found.pr}`);

  const tmp = join(prDir(found.alias, found.pr), `.response-${commentId}.posting.md`);
  writeFileMkdir(tmp, body);
  const posted = gh(["pr", "comment", String(found.pr), "--repo", slug, "--body-file", tmp], "bot");
  rmSync(tmp, { force: true });
  if (!posted.ok) die(`posting failed:\n${posted.stderr}`);

  const m = posted.stdout.match(/#issuecomment-(\d+)/);
  if (!m) die(`posted, but could not read the comment id back from:\n${posted.stdout}`);
  const responseId = m[1];

  // The write-back. Until this lands, a real comment exists with no local
  // record — the same window `pr create` has, and the reason for the guard at
  // the top of this function.
  set(rec, "status", "responded");
  set(rec, "artifact", rel(artifact));
  set(rec, "response_comment_id", responseId);
  writeRecords(found.statePath, found.records);

  console.log(`pr-loop: posted comment ${responseId}; recorded in ${rel(found.statePath)}`);
}

/** Write comment + drafted reply to one file, for reading somewhere other than a terminal. */
function cmdReview(commentId: string, opts: Options): void {
  const found = locate(commentId, opts);
  const inbound = cached(found.alias, found.pr, commentId);
  const artifact = opts.artifact ?? join(prDir(found.alias, found.pr), `response-${commentId}.md`);
  if (!existsSync(artifact)) die(`no response artifact at ${rel(artifact)} — author it first`);
  const body = splitDocument(readFileSync(artifact, "utf8")).body.trim();

  const out = join(prDir(found.alias, found.pr), `review-${commentId}.md`);
  writeFileMkdir(
    out,
    [
      `# Review: reply to ${get(found.rec, "repo")}#${found.pr}, comment ${commentId}`,
      ``,
      `Nothing is posted until \`make pr_respond ID=${commentId} POST=1\`. This file is a`,
      `read-only rendering — edit \`${rel(artifact)}\` to change the reply.`,
      ``,
      `## The comment being answered`,
      ``,
      inbound ? `**${inbound.user}** · ${inbound.updated_at.slice(0, 10)} · <${inbound.url}>` : `(not cached)`,
      ``,
      inbound ? inbound.body.trim() : ``,
      ``,
      `## The drafted reply`,
      ``,
      `Posts as the **bot**, not as you.`,
      ``,
      body,
      ``,
    ].join("\n"),
  );
  console.log(`pr-loop: wrote ${rel(out)}`);
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function main(argv: string[]): void {
  const opts: Options = {
    remote: null, pr: null, status: null, rank: null,
    reason: null, artifact: null, affirm: false, post: false, force: false,
  };
  const positional: string[] = [];

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "--remote": opts.remote = argv[++i] ?? die("--remote needs a value"); break;
      case "--pr": opts.pr = Number(argv[++i] ?? die("--pr needs a value")); break;
      case "--status": opts.status = argv[++i] ?? die("--status needs a value"); break;
      case "--rank": opts.rank = argv[++i] ?? die("--rank needs a value"); break;
      case "--reason": opts.reason = argv[++i] ?? die("--reason needs a value"); break;
      case "--artifact": opts.artifact = argv[++i] ?? die("--artifact needs a value"); break;
      case "--affirm": opts.affirm = true; break;
      case "--post": opts.post = true; break;
      case "--force": opts.force = true; break;
      case "--help": case "-h": console.log(usageFrom(import.meta.url)); return;
      default:
        if (a.startsWith("-")) die(`unknown option: ${a}`);
        positional.push(a);
    }
  }

  const [cmd, arg] = positional;
  switch (cmd ?? "queue") {
    case "queue": cmdQueue(opts); break;
    case "show": cmdShow(arg ?? die("show needs a comment id"), opts); break;
    case "set": cmdSet(arg ?? die("set needs a comment id"), opts); break;
    case "respond": cmdRespond(arg ?? die("respond needs a comment id"), opts); break;
    case "review": cmdReview(arg ?? die("review needs a comment id"), opts); break;
    default: die(`unknown command: ${cmd} (try queue, show, set, review, respond)`);
  }
}

main(process.argv.slice(2));
