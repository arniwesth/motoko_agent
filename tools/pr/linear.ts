/**
 * linear — attach a published PR to the Linear issue its branch names.
 *
 * `pr` already writes `ticket: MOT-<n>` into the record's frontmatter, but that
 * only makes the link findable from the git tree. The other direction — standing
 * on the issue and seeing the PR — was done by hand, and forgotten, which is how
 * #168 was noticed unlinked.
 *
 * Linear's native GitHub integration is installed, and what it does is *not*
 * dependable. Measured 2026-08-22, both directions: on #168 a genuine PR
 * description edit moved the PR's `updated_at` and produced no linkback and no
 * change to MOT-102; on #170, minutes later, the integration attached the PR to
 * MOT-111 on its own within seconds of creation. Diagnosing why it fires for one
 * and not the other needs `admin:repo_hook`, which the bot deliberately does not
 * hold. An intermittent link is the same problem as no link: nobody can tell,
 * from the issue, whether the absence means anything. So the link is also made
 * here, where it depends on nothing but the branch name.
 *
 * Two rules govern everything here:
 *
 * **Nothing is fatal.** A tracker link is a nice-to-have on top of a published
 * PR; a PR that failed to publish because Linear was unreachable is strictly
 * worse than one that published unlinked. Every failure path logs one line and
 * returns.
 *
 * **Everything is idempotent, including against the integration.**
 * `attachmentLinkURL` errors rather than no-ops on a URL already attached to the
 * issue, so the existing attachments are read first and a match short-circuits —
 * and because the App can attach in the gap between that read and the write, the
 * duplicate error is treated as success rather than as a failure. Re-running
 * `make pr` therefore neither duplicates the link nor gives up on retrying one
 * an earlier run lost.
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
 * One GraphQL round trip. Exactly one of `data` and `error` is set; the caller
 * decides what to say, because one caller has an error it does not mind.
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
function graphql(
  key: string,
  query: string,
  variables: Record<string, unknown>,
): { data: any | null; error: string | null } {
  // A key carrying a quote or a backslash would break out of the config line
  // and mangle the request in a way whose error message names neither cause.
  if (/["\\\r\n]/.test(key)) {
    return { data: null, error: "LINEAR_API_KEY contains a quote or backslash — refusing to build a curl config from it" };
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
      return { data: null, error: `curl failed (${(r.stderr ?? "").trim() || r.error?.message || `exit ${r.status}`})` };
    }
    const parsed = JSON.parse(r.stdout || "null");
    if (parsed?.errors?.length) {
      return { data: null, error: parsed.errors[0].message ?? "GraphQL error" };
    }
    return { data: parsed?.data ?? null, error: null };
  } catch (e) {
    return { data: null, error: (e as Error).message };
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
  const nodes: { url: string }[] | null = existing.data?.issue?.attachments?.nodes ?? null;
  if (!nodes) {
    note(`linear: could not read ${ticket} (${existing.error ?? "no issue in the response"}) — not linked to ${url}`);
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
  if (created.data?.attachmentLinkURL?.success) {
    note(`linear: linked ${url} to ${ticket}`);
    return;
  }
  // The read above narrows the duplicate case but cannot close it: measured on
  // #170, Linear's own GitHub integration attached the PR in the seconds between
  // the read and the write. The duplicate error is therefore the authoritative
  // "already linked", not a failure — whoever created it, the link exists.
  if (created.error && /duplicate/i.test(created.error)) {
    note(`linear: ${ticket} already links ${url} (attached by something else while this ran)`);
    return;
  }
  note(`linear: ${ticket} not linked to ${url}${created.error ? ` (${created.error})` : ""}`);
}
