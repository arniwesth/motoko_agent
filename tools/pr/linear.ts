/**
 * linear — attach a published PR to the Linear issue its branch names.
 *
 * `pr` already writes `ticket: MOT-<n>` into the record's frontmatter, but that
 * only makes the link findable from the git tree. The other direction — standing
 * on the issue and seeing the PR — was done by hand, and forgotten, which is how
 * #168 was noticed unlinked. Linear's native GitHub integration is installed and
 * does not fire for this repo (measured 2026-08-22 on #168: a genuine PR
 * description edit moved `updated_at` and produced no linkback and no change to
 * the issue), and diagnosing further needs `admin:repo_hook`, which the bot
 * deliberately does not hold. So the link is made in the pipeline, where it does
 * not depend on an App installation or on branch-name matching.
 *
 * Two rules govern everything here:
 *
 * **Nothing is fatal.** A tracker link is a nice-to-have on top of a published
 * PR; a PR that failed to publish because Linear was unreachable is strictly
 * worse than one that published unlinked. Every failure path logs one line and
 * returns.
 *
 * **Everything is idempotent.** `attachmentLinkURL` errors rather than no-ops on
 * a URL already attached to the issue, so the existing attachments are read
 * first and a match short-circuits. That is what makes re-running `make pr`
 * safe, and it also lets a run that failed to link retry on the next one.
 *
 * Design record: .agent/projects/022_linear_integration/ (option B — GraphQL
 * directly, rather than through Linear's MCP server, because this is one
 * mutation inside a synchronous pipeline, not an agent-facing tool surface).
 */

import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { fromDotenv, note } from "./lib.ts";

const ENDPOINT = "https://api.linear.app/graphql";

/** Linear is a courtesy call inside a publish, so it gets a short leash. */
const TIMEOUT_SECONDS = 15;

/**
 * Still the operator's personal key. 022 §4 — whose Linear account an agent acts
 * as — is open, and the GitHub answer (a machine user, ADR-001 D1/C9) has no
 * free analogue here because a Linear seat costs money. So attachments read as
 * the key's owner, which is the attribution collapse 016 rejected for GitHub,
 * and adopting `MOTOKO_BOT_LINEAR_KEY` is that decision's to make, not this
 * file's. The environment wins over .env, as it does for the bot token.
 */
function linearKey(): string | null {
  return process.env.LINEAR_API_KEY || fromDotenv("LINEAR_API_KEY");
}

/**
 * One GraphQL round trip, or null on any failure.
 *
 * The key goes to curl through a stdin config rather than argv, where `ps` would
 * show it to every process on the box. The request body rides in a temp file for
 * the same reason plus quoting: `-K -` has already claimed stdin, and a JSON
 * document embedded in curl's own config format is a second escaping layer with
 * nothing to recommend it.
 *
 * Linear reports application-level errors as a 200 with an `errors` array at
 * least as often as it uses a status code, so the body is parsed either way and
 * `--fail` is deliberately absent.
 */
function graphql(key: string, query: string, variables: Record<string, unknown>): any | null {
  // A key carrying a quote or a backslash would break out of the config line
  // and mangle the request in a way whose error message names neither cause.
  if (/["\\\r\n]/.test(key)) {
    note("linear: LINEAR_API_KEY contains a quote or backslash — refusing to build a curl config from it");
    return null;
  }

  const dir = mkdtempSync(join(tmpdir(), "pr-linear-"));
  const bodyFile = join(dir, "body.json");
  try {
    writeFileSync(bodyFile, JSON.stringify({ query, variables }));
    const r = spawnSync(
      "curl",
      [
        "-sS",
        "-K", "-",
        "-X", "POST", ENDPOINT,
        "-H", "Content-Type: application/json",
        "--data-binary", `@${bodyFile}`,
        "--max-time", String(TIMEOUT_SECONDS),
      ],
      { encoding: "utf8", input: `header = "Authorization: ${key}"\n` },
    );
    if (r.error || r.status !== 0) {
      note(`linear: curl failed (${(r.stderr ?? "").trim() || r.error?.message || `exit ${r.status}`})`);
      return null;
    }
    const parsed = JSON.parse(r.stdout || "null");
    if (parsed?.errors?.length) {
      note(`linear: ${parsed.errors[0].message ?? "GraphQL error"}`);
      return null;
    }
    return parsed?.data ?? null;
  } catch (e) {
    note(`linear: ${(e as Error).message}`);
    return null;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/** Trailing slashes are the one difference that is never a different PR. */
function sameUrl(a: string, b: string): boolean {
  return a.replace(/\/+$/, "") === b.replace(/\/+$/, "");
}

/**
 * Attach `url` to the Linear issue `ticket`, unless it is attached already.
 *
 * `ticket` is what `ticketFromBranch` returned, so null — a branch with no
 * `mot-<n>` segment — is an ordinary case and passes silently. Everything else
 * that goes wrong says so in one line and returns.
 */
export function attachToIssue(ticket: string | null, url: string, title: string): void {
  if (!ticket) return;

  const key = linearKey();
  if (!key) {
    note(`linear: no LINEAR_API_KEY — ${ticket} not linked to ${url}`);
    return;
  }

  // `issue(id:)` takes the human identifier, so no UUID lookup is needed. The
  // read is not merely an optimisation: attachmentLinkURL errors on a duplicate.
  const existing = graphql(key, "query($id: String!) { issue(id: $id) { attachments { nodes { url } } } }", {
    id: ticket,
  });
  const nodes: { url: string }[] | null = existing?.issue?.attachments?.nodes ?? null;
  if (!nodes) {
    note(`linear: could not read ${ticket} — not linked to ${url}`);
    return;
  }
  if (nodes.some((n) => sameUrl(n.url ?? "", url))) {
    note(`linear: ${ticket} already links ${url}`);
    return;
  }

  const created = graphql(
    key,
    "mutation($issueId: String!, $url: String!, $title: String!) " +
      "{ attachmentLinkURL(issueId: $issueId, url: $url, title: $title) { success } }",
    { issueId: ticket, url, title },
  );
  if (!created?.attachmentLinkURL?.success) {
    note(`linear: ${ticket} not linked to ${url}`);
    return;
  }
  note(`linear: linked ${url} to ${ticket}`);
}
