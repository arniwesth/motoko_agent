# Task: implement the fixes from the PLAN-001 live-run findings

Repo: /workspaces/motoko_agent, branch `arniwesth/013-dst-architecture-adr`. Do not switch branches.

Read first, in this order:
1. `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md` — the evidence.
2. The five issue files below. Each has Location and Fix sections; the Fix section is the spec.

## Concurrency warning

Another agent (a motoko worker on pane w3:pQ) is editing `src/core/*.ail` in this same working
tree right now, and the tree has pre-existing uncommitted changes (`.agent/`, `docs/`,
`little-coder/`, `ailang.lock`, `tools/ext_ambient_inventory/fixtures/expected.json`,
`.agent/projects/028_*/PLAN-002-*.md`). Rules:
- Run `git status --short` before you start and note every dirty path. Never stage, revert, or
  edit a file that was already dirty and is not yours, except where a fix below requires it.
- Commit only the files you changed, one commit per fix, message prefixed `PLAN-001 live-run fix N:`.
- If a file you must edit is already dirty from someone else, stop on that fix, note it in your
  report, and continue with the others.

## The fixes, in priority order

**Fix 1 — `.agent/issues/delegate-worker-output-budget-exhausted-and-empty-tool-arguments.md`**
Repo-side parts only (the upstream max-output-tokens ask is NOT yours):
- `src/core/session.ail:900` `decode_or_empty` and its consumer at `:1073`: when a native tool
  call's arguments fail to decode, emit a ledger event (add the variant to
  `src/core/phase_vocab.ail` and `src/core/dst_event_vocabulary.ail` following the existing
  `HybridBashExtracted` pattern, including the golden test) and return a tool result telling the
  model its arguments were truncated, not `missing path`.
- `packages/motoko-ext-empty-stop-guard`: when the step that produced the empty response ended
  `finish_reason: length` with zero tool calls, the nudge text must say the output was cut at the
  token limit and to emit the tool call first. Check how the guard sees finish_reason via `ctx`
  before assuming it can; if it cannot, say so in the report and leave the guard alone.

**Fix 2 — `.agent/issues/hybrid-bash-extracts-prose-examples-in-native-tool-mode.md`**
Option 1 from that file: once a v2 session has produced a native `tool_calls` finish, do not run
`extract_bash` on later prose responses. `src/core/session.ail:2853`. Add the deterministic test
the issue describes.

**Fix 3 — `DESIGN-delegate-model-selection.md` status paragraph (2026-09-06)**
`packages/motoko-ext-herdr/herdr.ail` around line 758–772 and `register.ail:61`: when
`allowed_kinds` contains more than one kind and the `Delegate` call carries no `kind`, refuse
with an error result listing the allowed kinds. When exactly one kind is allowed, keep defaulting
to it. Update the extension's tests (find them with `grep -rn "Delegate" packages/motoko-ext-herdr/*test*`).

**Fix 4 — `.agent/issues/herdr-extension-run-file-drifts-from-operator-plan-file.md`, option B only**
`packages/motoko-ext-herdr/herdr.ail:559` `ensure_dagr_pane`: yield (return an empty note, open
nothing) when an operator dagr view is already open. Detect it via the `.dagr/.pane` marker
and/or the marker `scripts/dagr-pane.sh` writes — read that script to learn the exact marker.
Do NOT attempt option A.

**Fix 5 — `.agent/issues/progress-guard-prose-heuristics-permit-premature-stop.md`, the
"Second occurrence" section only**
`packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail`: a stop while the
session has an open delegate is an allowed stop. Find the cheapest truthful signal: the
`Delegate` tool result text in the history slice ("this call did not wait for it") is acceptable
if nothing structured exists. Add the two deterministic tests the section names. Do not touch
the pre-existing compaction-related fix items in that issue.

**Fix 6 — `.agent/issues/session-logger-prints-undefined-version-on-conversational-turns.md`**
`src/tui/src/session-logger.ts:275`: same guard as `src/tui/src/ui.ts:2325`.

## Gates

- `ailang check` on every `.ail` you touch; run the relevant `make` targets (look in the Makefile
  for `check_core`, the herdr extension gate, and the guard gates — `grep -n "^[a-z_]*:" Makefile`).
  Report exact commands and exit codes. Do not claim green without output.
- For each issue file you fully fix, change its `## Status` to `resolved` and add a line naming
  the commit. Partial: leave `open`, add a `## Progress (2026-09-06)` section.

## Report

When finished, write `<scratchpad>/REPORT-plan001-live-run-fixes.md`
with: per fix — done/partial/skipped, commit hash, gate commands and exit codes, anything you
had to decide that the issue file did not settle. Then reply with only that path.
