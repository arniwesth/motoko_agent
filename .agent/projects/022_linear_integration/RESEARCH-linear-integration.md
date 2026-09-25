# RESEARCH: giving Motoko autonomous Linear access — which of the four MCP surfaces actually works

Date: 2026-08-22
Status: Research — measured baseline. **One decision taken by the owner** (Motoko should create and
update issues autonomously); everything about *how* and *as whom* is open. No code written.
Grounded at: branch `arniwesth/mot-101-agentcli`, HEAD `d992d73`.

Grounding verified 2026-08-22, by reading the packages rather than the docs:
- `packages/motoko-ext-mcp/` holds **two independent things** that are easy to confuse, and the
  confusion is the whole reason this document exists — see §1. Both were read at this HEAD.
- `packages/motoko-ext-exa-search/` is a **working precedent**: a remote HTTPS MCP server, reached
  from Motoko, enabled in three profiles including `default`. Verified in
  `.motoko/config/default/config.json`.
- Linear's endpoint and auth are from `linear.app/docs/mcp` and `linear.app/developers/graphql`,
  read today. **Nothing has been executed against Linear** — there is no `LINEAR_API_KEY` in `.env`
  and no Linear workspace has been contacted from this tree.

Relates to:
- `../016_github_ops/ADR-001-github-pr-ops-pipeline.md` **D1 as amended by C9** — *identity follows
  mechanism*: anything the pipeline emits is the bot, anything done by hand is you. §4 is the same
  question for a second tracker, and answering it differently here would be a deliberate
  inconsistency rather than an oversight.
- `packages/motoko-ext-exa-search/` — the shape to copy. §3.
- `../019_agent_confined/` — the confined agent reaches `mcp.linear.app` (public HTTPS)
  but not the obsidian MCP, which is addressed by a hostname that profile does not define. §5.2.
- `../021_herdr_delegation/` — a delegate in a herdr pane is a second, indirect route to Linear, and
  the one that needs no Motoko work at all. §2 option D.

---

## TL;DR

The obvious reading of `packages/motoko-ext-mcp/mcp.ail` is that Motoko cannot use MCP: its
`on_tool_handle` handles nothing, and `mcp-http` returns *"not yet available"*. **That reading is
wrong, and this document exists because it was made.** The working client is a different module in
the same package — `exec.ail`'s `run_mcp_tool`, which spawns a bundled Node bridge that speaks to
remote HTTP MCP servers — and `motoko-ext-exa-search` has been using it against
`https://mcp.exa.ai/mcp` all along, in the default profile.

So Linear is reachable, cheaply, by copying a 215-line extension. The config that does it is six
fields, and only three differ from Exa's.

What is *not* settled is whose account Motoko acts as. Linear personal API keys are personal, so the
default outcome is that every issue Motoko files reads as its key's owner — which inverts the rule
016 established for GitHub.

---

## 1. The measured baseline, and the trap in it

`packages/motoko-ext-mcp/` contains two things that share a name and do not share a purpose.

**The stub.** `mcp.ail`'s `make_hooks` builds an extension whose `on_tool_handle` has exactly two
branches (`:158-165`, the `mcp-http` arm at `:162`): that transport returns
*"mcp-http transport requires AILANG M-SERVE-API-LIVE-TOOL-REGISTRY (not yet available)"*, and
everything else returns `Delegate` — i.e. handles nothing. Its config is read from
`${MOTOKO_PROFILE_DIR}/mcp.json` (`mcp.ail:106`), whose schema is
`{servers:[{name, command, args, transport, tool_mappings, …}]}` — note: **no `url`, no `headers`**.
Measured: **no profile enables this extension, and no `mcp.json` exists in any profile.** It is
dormant, and it is the file a reader opens first.

**The client.** `exec.ail`'s `run_mcp_tool` resolves a bundled `assets/mcp-call.mjs`, spawns it with
`node`, and returns a `ToolResultEnvelope`. That script is a real remote MCP client: it takes
`--base-url`, applies an auth style, and `fetch`es. Extensions import `run_mcp_tool` **directly**;
they do not go through the stub.

The bridge's auth styles, read from `mcp-call.mjs:73-90,155-158`:

| `auth_style` | effect |
|---|---|
| `query:<param>` | appends the key as a URL query parameter (Exa uses `query:exaApiKey`) |
| `header:Bearer` | sets `Authorization: Bearer <key>` — the only header mode accepted |
| `none` or empty | no auth; both `auth_env_var` and `auth_style` must then be omitted together |

**The precedent.** `motoko-ext-exa-search` is 215 lines across four modules, and the entire
server-specific part is one function:

```ailang
export func mcp_config(timeout_ms: int, max_output_chars: int) -> McpServerConfig {
  { base_url: "https://mcp.exa.ai/mcp", auth_env_var: "EXA_API_KEY",
    auth_style: "query:exaApiKey", tool_filter: tool_filter(),
    timeout_ms: timeout_ms, max_output_chars: max_output_chars }
}
```

It is enabled in `default`, `deepseekv4-flash-compaction-live` and `hunyuan3-free-compaction-live`.

**Two client namespaces, not one.** Worth stating because it caused a wasted step today: the
repository-root `.mcp.json` is read by **Claude Code**, not by Motoko. Motoko's own MCP surface is
the profile file above (dormant) plus `run_mcp_tool` (live). Adding a server to `.mcp.json` gives it
to the operator's tooling and to nothing else. `linear` was added there on 2026-08-22 and is
correct for that purpose; it does not reach Motoko.

---

## 2. Options

**A. Copy `exa-search` and point it at Linear's MCP server.** Reuses `run_mcp_tool` and the bundled
bridge unchanged. Linear's endpoint is `https://mcp.linear.app/mcp` (Streamable HTTP) and it accepts
`Authorization: Bearer <api-key>`, which is exactly the bridge's `header:Bearer` mode. The whole
server-specific surface is:

```ailang
{ base_url: "https://mcp.linear.app/mcp", auth_env_var: "LINEAR_API_KEY",
  auth_style: "header:Bearer", tool_filter: [ … ], … }
```

plus a `tool_mappings` table naming the Linear tools Motoko is allowed to call. **Recommended**, and
§3 is its detail.

**B. Linear's GraphQL API directly, over `std/net`.** `httpRequest` takes custom headers, the
extension hook row already carries `Net`, and the domain gate is open (§5.1) — so
`https://api.linear.app/graphql` with `Authorization: <key>` (Linear's personal-key form takes **no**
`Bearer` prefix, unlike the MCP server) is buildable. More code than A, more control over exactly
which mutations exist, and no dependency on Linear's MCP tool surface changing under us. Keep as the
fallback if A's tool set turns out to be wrong-shaped. `motoko-ext-a2a` is the precedent for a
Net-using extension.

**C. Revive the `mcp.ail` stub and the profile `mcp.json`.** Blocked on AILANG's
`M-SERVE-API-LIVE-TOOL-REGISTRY`, and unnecessary given A. Its remaining value is that a profile file
would let servers be configured without publishing a package — the same complaint 018 F6 makes about
`agentcli`. Not this project's problem to solve.

**D. Delegate Linear work to a CLI that has Linear MCP**, in a herdr pane (021). Needs no Motoko
work at all, and inherits 021's open forks. Worth remembering as the zero-effort path if A is
deferred, not as the answer.

---

## 3. What option A actually costs

Four modules, ~200 lines, mirroring `exa-search` one-for-one:

| module | content |
|---|---|
| `types.ail` | `mcp_config()` (six fields, three of them Linear-specific) + `tool_mappings()` + `tool_filter()` |
| `linear.ail` | `provided_tools`, `on_tool_handle` delegating to `run_mcp_tool`, the eight hook slots |
| `prompts.ail` | the agent-facing description of when to file an issue rather than merely mention one |
| `register.ail` | `LINEAR_API_KEY` resolution, timeout and output caps |

**`tool_filter` and `tool_mappings` are where the owner's decision is enforced.** Motoko does not
get
"Linear"; it gets the exact tools named in that table. "Create and update issues autonomously" is
three or four entries — create, update, search, comment — and deliberately *not* the ones that
delete, archive, or touch cycles and projects. Two constraints on the canonical names, learned the hard
way
by exa-search (`types.ail:9-15`): they are advertised to the model, and they must match Bedrock's
`^[a-zA-Z0-9_-]{1,128}$` — **no dots**.

---

## 4. The open question: whose Linear account is this?

016 ADR-001 D1, as amended by C9, settled the equivalent question for GitHub: a **machine user**, so
that "anything the pipeline emits is the bot; anything done by hand in the web UI is you" — one rule
checkable from an author field. `MOTOKO_BOT_GH_TOKEN` is deliberately *not* named `GH_TOKEN` so the
operator's own `gh` never silently becomes the bot.

Linear personal API keys are personal. So the default outcome of option A is that **every issue
Motoko files, and every issue it updates, reads as the key's owner** — the operator. That is the
exact state 016 rejected for GitHub, arrived at by not deciding rather than by choosing.

Three ways out, none free:

1. **A dedicated Linear user for the bot**, with its own key. Consistent with 016; costs a seat,
   and that cost is a real input the operator has and this document does not.
2. **A Linear OAuth application with `actor=app`.** Linear supports acting as an application rather
   than a user, which is the closest analogue to a GitHub App. It is more setup than a key, and
   whether the MCP server path supports app actors is **unverified**.
3. **Accept attribution collapse deliberately, and write it down** — Linear is a planning surface
   rather than a code-review surface, so the argument that carried for GitHub may simply be weaker
   here. Legitimate, but it should be a recorded decision that names the inconsistency with 016.

**Naming, whichever wins.** If a bot key is adopted, call the variable `MOTOKO_BOT_LINEAR_KEY`, not
`LINEAR_API_KEY`, for exactly the reason 016 gives: a generically-named key in a shared `.env` gets
picked up by whatever else reads that name.

---

## 5. Gates checked, so nobody re-checks them

### 5.1 The `Net` domain allowlist is open, and this is load-bearing for option B

`isAllowedDomain` (`ailang/internal/effects/net.go`) returns **true** on an empty allowlist, and the
TUI passes `--net-allow-http` and `--net-allow-localhost` but **no `--net-allow-domains`**
(`src/tui/src/runtime-process.ts:484-485`). So any host is reachable by the `Net` effect today.

Two consequences, and the second is uncomfortable: option B needs no allowlist change; and *nothing
constrains where a `Net`-using extension can send data*. That is not this project's finding to act
on, but it belongs next to 019's boundary work, which spent its effort on the container while this
sits open in the runtime.

### 5.2 The confined agent can reach Linear

`mcp.linear.app` and `api.linear.app` are public HTTPS, so both options work from `agent_confined` —
unlike the obsidian MCP, which is addressed by the `host.docker.internal` name that profile does not
define — a name, not a route: see 019's `HISTORY.md` correction of 2026-08-22. Linear would be
the **first MCP server the confined agent can actually use**. It needs the key in that profile's
compose `environment:` block, which is 019's curated list.

### 5.3 `node` is required and present

`run_mcp_tool` spawns `node`. Present in both images via `scripts/install-prerequisites.sh`. The
bridge degrades honestly: `looks_like_missing_node` returns `None` rather than a false error.

---

## 6. Open forks — owner decisions

- **F-1. Whose account?** (§4.) Bot user, app actor, or recorded attribution collapse. Everything
  else can proceed once this is answered; nothing should ship before it is.
- **F-2. Option A or B?** MCP-via-bridge is far less code; GraphQL is immune to Linear changing its
  MCP tool surface and gives exact control over which mutations exist.
- **F-3. Which tools, exactly?** (§3.) "Create and update issues" is the stated decision; whether
  that includes commenting, state transitions, assignment, and search is not.
- **F-4. Is Linear the source of truth for planning, or a view?** `.agent/github/` already records
  issue and PR state in-tree, and `.agent/projects/` holds the design records. Two trackers that
  each believe they are authoritative is a worse outcome than either alone. This is the fork most
  likely to matter in six months and the one least likely to be noticed now.
- **F-5. Which workspace and team?** Unknown to this document. `teamId` is required by `issueCreate`.

---

## 7. What must be measured before building

1. **Does the bundled bridge work against `mcp.linear.app`?** It is exercised only against Exa
   today, with `query:` auth. Linear needs `header:Bearer`, which is implemented but — as far as this
   tree shows — never used. One `node assets/mcp-call.mjs --base-url … --auth-style header:Bearer`
   run settles it.
2. **What tools does Linear's MCP server actually expose, and under what names?** `tool_filter` and
   `tool_mappings` cannot be written without the list. The bridge takes a `--tools` CSV, so listing
   is likely already reachable.
3. **Does a personal API key work against the MCP server**, or does that endpoint require OAuth?
   Linear's docs say a key may be passed as a bearer token; that is the sentence option A rests on.
4. **Does Linear's MCP server honour `actor=app`** if F-1 picks the OAuth route? (§4.2.)
5. **Rate limits.** Linear documents that they exist without stating them here. An agent filing
   issues autonomously is exactly the client that finds them.
