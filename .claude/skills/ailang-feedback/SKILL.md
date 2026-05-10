---
name: ailang-feedback
description: Route AILANG-side bugs and limitations encountered while working on Motoko (the agent harness in this repo) to AILANG core via the right channel. Use when the user mentions an AILANG compiler error, parser bug, type/effect mismatch, stdlib gap, or missing language feature — anything where the symptom is in `ailang check` / `ailang run` output, not in Motoko's TUI or runtime logic. Also use when the user asks "should this be filed upstream?", "is this an AILANG bug?", or wants to send feedback / file an issue against `sunholo-data/ailang`.
---

# AILANG Feedback (Motoko)

Motoko's runtime is written in AILANG. When something goes wrong, the cause is in one of three layers — and each has its own bug tracker. This skill is for the third layer: bugs in **AILANG itself**.

If you're not sure which layer the bug is in, the rule is:

| Symptom | Layer | Tracker |
|---|---|---|
| TUI rendering, keybindings, JSONL framing | Motoko TUI | This repo |
| Agent loop, prompts, extension wiring | Motoko core (`.ail` modules in `src/core/`) | This repo |
| `ailang check` error, `PAR_*` / `TYP_*` / `MOD*` codes, stdlib missing a function | AILANG itself | `sunholo-data/ailang` |

Anything where the user can copy a small `.ail` snippet that reproduces the error standalone is almost certainly an AILANG-layer issue.

## Three Channels (pick by what you have)

### Channel 1: GitHub issue (fallback if config not set up)

```
https://github.com/sunholo-data/ailang/issues/new
```

Always works, no config required. Best for bugs you can describe in detail. Include `ailang --version`, a minimal `.ail` reproduction, expected vs actual.

### Channel 2: `ailang messages send --github` (best for one-off CLI use)

```bash
ailang messages send ailang \
  "<one-line summary>" \
  --title "Bug: <code> <short description>" \
  --from "motoko_agent" \
  --type bug \
  --github
```

Creates a GitHub issue in `sunholo-data/ailang` programmatically, with envelope metadata that the AILANG team's intake skills auto-triage. Replies posted via `ailang messages reply <id>` show up as comments on the issue.

**Pre-flight check before using this channel:**

```bash
test -f ~/.ailang/config.yaml && grep -q "default_repo" ~/.ailang/config.yaml || echo "NEEDS SETUP"
gh auth status
```

If pre-flight reports `NEEDS SETUP`, run:

```bash
mkdir -p ~/.ailang
cat > ~/.ailang/config.yaml <<EOF
github:
  expected_user: $(gh api user --jq .login)
  default_repo: sunholo-data/ailang
EOF
```

Then retry. Note: the config is **always** at `~/.ailang/config.yaml` (user-level). The CLI does not look in the repo or accept an env override.

### Channel 3: MCP `submit_feedback` (best when an agent is running and notices a limitation mid-task)

The public AILANG MCP server at `https://mcp.ailang.sunholo.com/mcp/` exposes a `submit_feedback` tool. **No API key — it's a public endpoint.** Submissions land in AILANG's `public-feedback` inbox where humans triage them.

Direct `curl` form (works from any shell, useful inside agent prompts):

```bash
curl -sS -X POST https://mcp.ailang.sunholo.com/mcp/ \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{
    "name":"submit_feedback",
    "arguments":{
      "title":"<short title>",
      "body":"<full description with reproduction>",
      "category":"<bug|feature|docs|limitation>",
      "ailang_version":"<output of ailang --version>",
      "snippet":"<≤4KB code or error excerpt>",
      "contact":"<optional follow-up address>"
    }}}'
```

A successful response is one SSE `event: message` line containing `"status": "queued"` and a `ticket_id` like `fb_d3920906975b66e2`.

When invoking this from an MCP-aware agent, register the server first (in your motoko profile's MCP server list — see `src/core/ext/mcp/types.ail` for the `McpServerConfig` shape) and call `submit_feedback` as a tool. The base URL is `https://mcp.ailang.sunholo.com`; `auth_style` is `"none"`.

## Choosing a Channel

| Situation | Channel |
|---|---|
| User asks "file an issue" or wants a tracked URL | 1 (direct GitHub) |
| User has CLI configured and wants concise command | 2 (`messages send --github`) |
| Mid-agent-run, agent itself notices the limitation | 3 (MCP `submit_feedback`) |
| Quick anonymous report, no GitHub account context | 3 (MCP, public) |

## What Makes a Good Report

Always include:

- **`ailang --version`** output verbatim
- **Minimal reproduction**: smallest `.ail` snippet (or shell command) that reproduces the symptom. Copy it out of the Motoko source tree into a fresh `repro.ail` and confirm `ailang check repro.ail` shows the same error.
- **Expected vs actual** behavior in one sentence each.
- **Category** (`bug` / `feature` / `docs` / `limitation`) — affects routing.

If the bug surfaced in Motoko, mention which file (`src/core/<file>.ail`) and which workflow (rpc loop, EditFile retry, MCP bridge, etc.) — it gives the AILANG team something concrete to attach a regression test to.

## Patterns Already Recorded

When you spot one of these, mention the pattern by name in the report — the AILANG team is tracking them:

| Pattern | Symptom | Likely root |
|---|---|---|
| **Effect row narrowing** | inferred `! {Env}` rejected against expected `! {Env, FS}`; error names the slot but not the call site that contributes the missing label | needs provenance pointer in `TYP_EFFECT_ROW_MISMATCH` |
| **module_prefix overlap** | imports from a project whose root and a dep share `module_prefix` resolve to wrong package; no clear diagnostic | `MOD012` (planned) |
| **let/in vs `;` confusion** | parser error inside `{ ... }` after `let x = expr in`; documented but easy to hit | docs / structured tool-call authoring (planned) |

These appeared in motoko's own `.agent/learnings/` early in development. New patterns belong here too — when you find one, file it as `category: limitation` and quote the section in the report.

## Verifying a Channel After Setup

For Channel 2:

```bash
ailang messages send ailang "ping" \
  --title "config-test from motoko_agent" \
  --from motoko_agent --type docs --github
```

A successful run prints the issue URL. Close the issue if it was a smoke test.

For Channel 3:

```bash
curl -sS -X POST https://mcp.ailang.sunholo.com/mcp/ \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"submit_feedback","arguments":{"title":"smoke test","body":"connectivity check","category":"docs","ailang_version":"dev"}}}'
```

Look for `"status": "queued"` in the SSE response. If you get a 404, the URL path is wrong — `/mcp/` (with trailing slash) is required. If you get a connection error, the server may be down (rare); fall back to Channel 1.

## Related: Reading Replies

When AILANG core responds to a Motoko issue, the reply lands in two places:

- As a **GitHub comment** on the original issue (always, for Channels 1 and 2)
- As a **message in the local inbox** under the agent name `ailang` (only if the local CLI is configured and `gh auth` is set; then `ailang messages list --inbox motoko_agent` shows it)

`ailang messages list --unread` at session start surfaces these without needing to refresh GitHub.
