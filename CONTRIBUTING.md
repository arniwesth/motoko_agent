# Contributing

Motoko's runtime is written in [AILANG](https://github.com/sunholo-data/ailang). When you hit a snag, the cause is almost always one of three layers — and each has a different reporting channel. Picking the right one gets you a fix faster.

## Where to file what

| Symptom | Layer | Channel |
|---|---|---|
| TUI rendering, keybindings, session state, JSONL framing | Motoko TUI | This repo: [open an issue](https://github.com/sunholo-data/motoko_agent/issues) |
| Agent loop behavior, prompts, extension wiring, tool dispatch logic | Motoko core (`src/core/*.ail`) | This repo: [open an issue](https://github.com/sunholo-data/motoko_agent/issues) |
| AILANG compiler error, parser bug, type/effect mismatch, stdlib gap, missing language feature | AILANG itself | See "Reporting AILANG bugs" below |

The split matters because Motoko is intentionally thin over AILANG. If `ailang check src/core/foo.ail` fails with a confusing message, that's an AILANG diagnostic problem and the AILANG team will fix it directly. If `make run` hangs after the first tool call, that's a Motoko runtime problem.

## Reporting AILANG bugs

AILANG core accepts feedback through three channels. Pick the one that matches what you have.

### 1. GitHub issues (best for bug reports with context)

```
https://github.com/sunholo-data/ailang/issues/new
```

Include:

- AILANG version: `ailang --version`
- Minimal reproduction: the smallest `.ail` snippet (or shell command) that triggers the issue
- Expected vs. actual behavior
- Whether you think it's a bug or a design limitation

Cross-link this Motoko repo if the bug surfaced inside Motoko's source tree — context like "rpc.ail line 1124, after EditFile retry" gives the AILANG team something concrete to attach a regression test to.

### 2. `ailang messages send --github` (one command, from inside Motoko's tree)

If you have the AILANG CLI configured with a GitHub token, this opens an issue programmatically with the right metadata:

```bash
ailang messages send ailang \
  "Effect row mismatch in test_dummy/dummy.ail — error didn't pinpoint the call site" \
  --title "Bug: TYP_EFFECT_ROW_MISMATCH lacks call-site pointer" \
  --from "motoko_agent" \
  --type bug \
  --github
```

The `--github` flag creates a real issue in `sunholo-data/ailang`. AILANG's side can reply via `ailang messages reply <id>`, which posts back as a comment you'll see on GitHub.

**One-time setup.** Config lives at `~/.ailang/config.yaml` (user-level, *not* repo-local — the AILANG CLI hardcodes this path so it can be shared across every project on your machine). Create the file:

```bash
mkdir -p ~/.ailang
cat > ~/.ailang/config.yaml <<EOF
github:
  expected_user: <your-gh-handle>
  default_repo: sunholo-data/ailang
EOF
```

Then verify:

```bash
gh auth status                              # must report your <your-gh-handle> as logged in
ailang messages send ailang "ping" --title "config-test" --from motoko_agent --type docs --github
```

A successful run prints the new GitHub issue URL. Delete the issue if you only meant to smoke-test.

### 3. MCP `submit_feedback` (best from inside an agent run)

AILANG hosts a public MCP server at `mcp.ailang.sunholo.com` exposing a `submit_feedback` tool. When the agent itself notices an AILANG limitation mid-task, registering this server in your MCP profile lets the agent file a structured report without leaving the loop. The agent can call:

```json
{
  "tool": "submit_feedback",
  "arguments": {
    "title": "Parser confused let/in inside a brace block",
    "body": "While editing src/core/parse.ail the AILANG parser …",
    "category": "bug",
    "ailang_version": "0.16.x",
    "snippet": "let x = 1 in { x + 1 }",
    "contact": ""
  }
}
```

Submissions land in AILANG's `public-feedback` inbox (Pub/Sub-backed). Categories accepted: `bug`, `feature`, `docs`, `limitation`. **No API key required — it's a public endpoint.** Verified end-to-end on 2026-05-04 (`fb_d3920906975b66e2`).

You can hit it directly from a shell to test connectivity:

```bash
curl -sS -X POST https://mcp.ailang.sunholo.com/mcp/ \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{
    "name":"submit_feedback",
    "arguments":{
      "title":"smoke test",
      "body":"connectivity check",
      "category":"docs",
      "ailang_version":"0.16.x"
    }}}'
```

A working response includes `"status": "queued"` and a `ticket_id`.

To wire it into Motoko's MCP extension, add the server to your profile's MCP servers list (see `src/core/ext/mcp/types.ail` for the `McpServerConfig` shape). The base URL is `https://mcp.ailang.sunholo.com`; set `auth_style` to `"none"`.

## What makes a good AILANG report

The single most useful thing you can include is a **minimal `.ail` reproduction**. Motoko's source tree is large; copying the smallest fragment that reproduces the error into a fresh `repro.ail` and confirming `ailang check repro.ail` reproduces the symptom takes the issue from "interesting" to "fixable in an afternoon."

Common AILANG-side bug patterns Motoko has surfaced (recorded in `.agent/learnings/`):

- Effect-row mismatches where the inferred row is narrower than expected — the diagnostic doesn't point at the call site responsible for the missing label.
- Module-prefix overlap between root and dependency packages causing wrong-package import resolution.
- `let`/`in` vs. `;` discipline inside brace blocks — AILANG's most common syntax footgun for LLM authors.

If your report fits one of these patterns, mention it — they're tracked upstream and your data point helps quantify priority.

## Local Motoko changes

Bug fixes and features for Motoko itself follow the standard fork → branch → PR flow against this repo. Tests live alongside source: `make test` for core runtime tests; `cd src/tui && bun run test` for TUI.

`make check_core` runs `ailang check` over every `.ail` file in `src/core/` — it should pass before you open a PR.
