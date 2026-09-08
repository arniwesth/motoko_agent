/**
 * state — read and write `state.yaml`, a deliberately narrow YAML subset.
 *
 * Shared by `pr-sync` (which may only append facts) and the review loop (which
 * owns every judgment field). It lives in one module because the invariant that
 * separates those two callers — sync only adds facts; only the loop changes
 * judgments, ADR-001 D3 — is enforceable only if they agree byte-for-byte on
 * what a record is.
 *
 * A dependency was considered and rejected: js-yaml exists only in src/tui's
 * tree, is not resolvable from tools/, and postCreateCommand would not install
 * it. The output is verified to round-trip through js-yaml with the right
 * types.
 */

import { existsSync, readFileSync } from "node:fs";

import { die, rel } from "./lib.ts";

// ---------------------------------------------------------------------------
// state.yaml — a deliberately narrow YAML subset
// ---------------------------------------------------------------------------

/**
 * Records are read as ordered key/value pairs rather than into a fixed struct.
 * The loop (WI-5) and a later 008-conforming migration will both add fields
 * this tool does not know about, and a sync that silently dropped them on
 * rewrite would destroy judgment — the one thing D3 forbids it from touching.
 */
export type Record = [string, string][];

export function get(rec: Record, key: string): string | null {
  const hit = rec.find(([k]) => k === key);
  return hit ? hit[1] : null;
}

export function set(rec: Record, key: string, value: string): void {
  const hit = rec.find(([k]) => k === key);
  if (hit) hit[1] = value;
  else rec.push([key, value]);
}

export function unquote(raw: string): string {
  const t = raw.trim();
  if (t.length >= 2 && ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'")))) {
    try {
      return t.startsWith('"') ? (JSON.parse(t) as string) : t.slice(1, -1);
    } catch {
      return t.slice(1, -1);
    }
  }
  return t;
}

/**
 * Quote unless the value is unambiguously safe bare. `#` and `: ` are the two
 * that bite: `reason: superseded by #154` would otherwise parse as the value
 * "superseded by" with a trailing comment, quietly truncating a dismissal
 * reason that D3 makes mandatory.
 */
export function scalar(value: string): string {
  if (value === "") return '""';
  if (/^-?\d+$/.test(value)) return value;
  if (/^\d{4}-\d{2}-\d{2}T[\d:]{8}Z$/.test(value)) return value;
  if (/^(true|false)$/.test(value)) return value;
  if (/^(null|yes|no|on|off|~|True|False|TRUE|FALSE)$/.test(value)) return JSON.stringify(value);
  if (/^[A-Za-z0-9.\/][A-Za-z0-9 _.\/@+-]*[A-Za-z0-9_.\/@+-]$/.test(value)) return value;
  if (/^[A-Za-z0-9]$/.test(value)) return value;
  return JSON.stringify(value);
}

const STATE_HEADER = [
  "# Per-comment processing state. Machine-maintained by `make pr_sync`; the",
  "# rank/test/respond loop owns every judgment field.",
  "#",
  "# Sync only adds facts; only the loop changes judgments (ADR-001 D3).",
  "# `dismissed` requires a `reason`; `responded` requires both `artifact` and",
  "# `response_comment_id`. Schema is provisional pending 008 fork 2.",
  "# Notes belong in a record's `reason:`, not in comments here — this file is",
  "# rewritten in place and free-standing comments do not survive.",
  "",
].join("\n");

export function readState(path: string): Record[] {
  if (!existsSync(path)) return [];
  const records: Record[] = [];
  let current: Record | null = null;

  const lines = readFileSync(path, "utf8").split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim() || line.trimStart().startsWith("#")) continue;

    const item = line.match(/^-\s+([A-Za-z0-9_]+):\s*(.*)$/);
    if (item) {
      current = [[item[1], unquote(item[2])]];
      records.push(current);
      continue;
    }
    const field = line.match(/^\s{2,}([A-Za-z0-9_]+):\s*(.*)$/);
    if (field && current) {
      set(current, field[1], unquote(field[2]));
      continue;
    }
    die(`${rel(path)}:${i + 1} is not a shape this tool understands — refusing to rewrite it.\n  ${line}`);
  }
  return records;
}

export function renderState(records: Record[]): string {
  const body = records
    .map((rec) => rec.map(([k, v], i) => `${i === 0 ? "- " : "  "}${k}: ${scalar(v)}`).join("\n"))
    .join("\n");
  return `${STATE_HEADER}${body}\n`;
}
