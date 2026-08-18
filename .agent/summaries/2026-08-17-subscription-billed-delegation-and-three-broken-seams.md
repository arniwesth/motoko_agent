# 2026-08-17 Subscription-billed delegation, and three seams that did not hold

## Context

Started on `arniwesth/mot-97-github-ops`. Entry point was a question, not a task: *"Motoko is
written in AILANG. Figure out if AILANG support OpenAI subscription models"*. Every subsequent piece
arrived as a follow-on ask — verify it, file it, what about Grok, what about OpenRouter, could an
extension do it, sketch it, wire it, make yolo the default, what about Claude Code, merge the
providers, file the bugs.

**The work landed as `97e7248a "Added agentcli extension v1"` on
`arniwesth/mot-98-add-agentcli-extension`** — the whole package plus its wiring, 565 insertions
across 10 files. That commit was made by a concurrent session in this repo, not by this one; this
session never committed. Worth knowing for anyone reading the history: the branch name and commit
message are not this session's, and `97e7248a` also swept in an unrelated `ADR-001` and a
`compaction_ai.json` change. HEAD has since moved on to
`arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded`.

Shipped: a working two-provider delegation extension, both providers live-verified on subscription
auth; 3 AILANG feedback tickets; 2 motoko issues ([#158](https://github.com/arniwesth/motoko_agent/issues/158),
[#159](https://github.com/arniwesth/motoko_agent/issues/159)); the vendored `ailang` binary rebuilt
from a 3-week-old dev build.

## The question, answered

AILANG has **two model paths with two billing models**, and only one can run on a subscription:

| Path | Auth | Bills |
|---|---|---|
| `AI` effect (`internal/ai/`) — what motoko's `agent.model` uses | env-var API keys only | metered $ |
| Executor layer (`internal/executor/codex/`) — shells out to `codex exec` | API key **or** `codex login` OAuth | metered $ **or** plan quota |

`internal/ai/config.go:104-153` maps each provider to exactly one env var; the three OpenAI request
builders hard-code `Authorization: Bearer <apiKey>`; `internal/ai/configdriven/auth.go:46-71` offers
only bearer / x-api-key / query-param shapes resolved from env. No OAuth shape, no refresh, no
credential-file source.

The mission loop already exploits the other path deliberately — `mission-control.sh:76-84` unsets
`OPENAI_API_KEY` so codex's only auth is `~/.codex/auth.json` (`auth_mode=chatgpt`) — but nothing
reachable from `.ail` code can get there.

**There is no `on_model_call` seam.** `src/core/model_phase.ail` dispatches no hook. So an extension
can move *delegated* work onto plan quota and cannot move the driver loop. That constraint shaped
everything after it.

## What got built

`packages/motoko-ext-agentcli/` — one extension, one handler, a provider table, two tools.

```text
providers.ail    Provider record + codex/claude descriptors + argv builder + failure-stream selector
agentcli.ail     provider-agnostic handler: dispatch, lock, truncation, envelope, billing metadata
register.ail     per-provider env resolution (CODEX_MODEL / CLAUDE_MODEL, *_EXTRA_FLAGS)
```

Dispatch is **by tool name** (`CodexExec`, `ClaudeExec`) rather than a `provider` argument: models
select tools more reliably than they fill enums, and a wrong enum here bills the wrong account
silently. `ExtensionHooks.provided_tools` is a list precisely so one extension can offer several.

Live-verified through the real loop, both providers in one run:

```text
CodexExec  → "codex-ok"   gpt-5.6-sol,    ChatGPT subscription
ClaudeExec → "claude-ok"  claude-fable-5, Claude subscription
```

## Facts that were measured, not assumed

Each of these was wrong or unknown in my first draft, and each cost a cycle to find.

1. **`gpt-5-codex` cannot run on ChatGPT auth.** AILANG's executor hardcodes it
   (`codex.go:43-45`, `factory.go:65`) and prices it (`codex.go:677-687`). On `auth_mode=chatgpt` it
   returns `400 "The 'gpt-5-codex' model is not supported when using Codex with a ChatGPT account."`
   `gpt-5.6-sol` succeeds on the same credential. **The executor's default only works on the metered
   lane its own billing guard forbids.** Filed as `fb_15bb9f87bcb7859b`.

2. **The two CLIs report failures on opposite streams.** Measured both with a deliberately bad
   `--model`:
   - codex → stdout NDJSON `{"type":"error"}` + `{"type":"turn.failed"}`; stderr carries only
     `"Reading additional input from stdin..."`, printed on *every* run including successes.
   - claude → stderr `[claude-code:unrecognized_model] {...}`; stdout has `"is_error":true` and no
     reason.

   Exact mirrors. This is why `failure_on_stdout` is a table field and not a shared convention: a
   decoder written to either one silently reports the wrong text for the other. My first version
   copied compose's stderr-first order and would have reported the stdin banner as the reason for
   every codex failure.

3. **Claude Code reports `total_cost_usd` even under subscription auth** — `0.144036` on a measured
   one-word run. That is an API-equivalent price, not spend. Codex reports tokens only. Both are
   suppressed in the envelope; the metadata says why. Passing either through would put invented
   spend in the cost record (Critical Principle 2).

4. **`--bare` does not read `CLAUDE_CODE_OAUTH_TOKEN`.** Claude Code's docs call `--bare` "the
   recommended mode for scripted and SDK calls" and say it "will become the default for `-p` in a
   future release". Accepting that future default silently moves the Claude lane off plan quota onto
   a metered key. `-p` is pinned explicitly with a comment to re-check on upgrades.

5. **`codex login --device-auth` exists** for headless boxes, and OpenAI's CI/CD guidance requires
   *"only one machine or serialized job stream will use a given `auth.json` copy"* — which is why
   `needs_lock` is true for codex and false for claude. Anthropic documents no equivalent; its
   constraint is the weekly cap, which a lock does not address.

## Three broken seams

### #158 — the BashExec wrap silently drops `req.args`

`tool_runtime.ail:888` builds `wrapped_cmd = "${prefix}${req.cmd}"` — from `req.cmd` **alone** — and
execs `bash -lc <that>`. `req.args` is never referenced again. The wrap triggers when
`shell_tokens_in_process` (`:50`) sees any of `| > < && || ; $( `` ` in **any** argv element
(`:32-40`).

Found through the real loop: the model's first `CodexExec` prompt said *"write a file called
\`hello_codex.py\`"*, the backticks tripped it, `bash -lc "codex"` ran, and the argument-less binary
entered interactive mode and died with `Error: stdin is not a terminal`. Both the agent and I chased
PTY allocation first — three layers from the cause.

Worse: both result paths report `cmd_string(req.cmd, req.args)` (`:900`, `:912`), so **the transcript
shows the command that did not run**.

The fix in this extension was to use ambient `std/process.exec`, which consults no such predicate.
What that gives up is WI-D24's holder stamping. The invariant `proc.ail`'s header describes — free
text is safe as one argv element because there is no shell — holds for compose's own sites
(`ailang check <path>`) and **does not survive a model-authored argument**.

### #159 — regenerating the registry breaks 9 core modules

`ailang generate-extension-registry` writes the effect row from `[effects] max` (`ailang.toml:56`),
which includes `SharedIndex`. The committed `registry_generated.ail` carries a narrower,
alphabetically-sorted row without it. Regenerating — mandatory when adding an extension — widens
three sites (`resolve`, `parse_tokens`, `parse_core_ext_order`) and breaks `agent_loop_v2`,
`dst_execution`, `dst_hook_guard`, `hook_phase`, `rpc`, `session`, `supervisor`,
`tool_envelope_dispatch`, `tool_phase`, plus `scripts/verify_extension_boot.ail`.

`SharedIndex` is not needed by anything: `grep -rln "SharedIndex" packages/*/[a-z]*.ail` returns
nothing. It is over-declared purely because it sits in the project *ceiling*.

Hit **twice** in one session. The workaround both times was to hand-edit a file whose header says
"Do not edit. Regenerate."

### AILANG — same-named exported types collide across sibling packages

`fb_59eff5532a7df542`. A locally-defined, non-imported `ProcStreams` (2 fields) unified against
`motoko_ext_compose/proc`'s exported `ProcStreams` (3 fields) whenever both were in one build graph.
Standalone `ailang check` passed; the whole-graph check failed with a type that appears nowhere in
the failing module or its imports.

Bisect was decisive — renaming *either* definition clears it. **Minimisation failed**: two
hand-built 2-package graphs both checked clean, including one where both packages also exported a
same-named function returning their respective types. Reported as un-minimised with the two failed
attempts listed, so triage does not repeat them.

## Corrections made mid-session

Recorded because each was a wrong claim that reached the user before it was caught.

- **"The `verify_extension_boot` failure is pre-existing."** It was not. Stashing my changes gave
  8/8 booting. The error names the verifier and fires identically for all extensions, which reads as
  harness breakage rather than a consequence of regeneration — the diagnostic trap now written into
  #159.
- **Nearly corrected the user on SpaceX/Grok.** I was about to explain that Grok is xAI's, not
  SpaceX's. Checked first: SpaceX acquired xAI 2026-02-02 and the rebrand to SpaceXAI landed
  2026-07-06 — both after my training cutoff. The premise was right and mine was stale.
- **"There is no shell to be safe from"** in my own module header — false the moment a model authors
  an argv element. Rewritten with the measurement.
- The first extension sketch routed through `ExtPorts.proc_exec` on the strength of compose's
  reasoning. Reversed after the live run, with the reversal documented at the call site rather than
  silently corrected.

## The vendor table

The same architecture gets three different answers, which is the durable finding:

| Vendor | Own CLI on subscription | Third-party client on subscription |
|---|---|---|
| OpenAI | documented, but *"the right way is an API key"* | undocumented, unsanctioned |
| SpaceXAI | supported | **actively blessed** — official integration pages |
| Anthropic | **explicitly documented** for CI (`claude setup-token`) | prohibited, blocked since 2026-04-04 |

OpenRouter cannot bridge any of them: BYOK takes provider API keys and cloud credentials, never
subscription OAuth, and charges 5% on top. Subscriptions are sold to agent products, not to gateways
— which is why the executor layer is the only lane that works, for every vendor.

## Owed

- **No PR.** The extension is committed on `mot-98` (`97e7248a`) but nothing is opened against
  `main`, and `mot-98` is not the branch HEAD sits on.
- `ailang.lock` records `ailang_version: v0.33.0` while `ailang/bin/ailang` is now
  `v0.33.1-84-g127c1443e` (rebuilt from a 2026-07-29 dirty dev build that was failing on
  `Int vs int` in `std/list`). Checks print an advisory. Re-locking would record a dev build as the
  project toolchain — deliberately left to the owner.
- The advisory lock is **stat-then-write, not atomic**. It serialises the sequential case this
  extension produces and fails closed otherwise. An atomic create needs an `ExtPorts` door that does
  not exist.
- Holder stamping is given up wherever ambient `exec` is used. The fix that would restore it is an
  argv-preserving mode on the bridge — a core change, filed rather than worked around.
- The permission bypass is **on by default** for both providers (owner's call, 2026-08-16), so the
  delegate runs unsandboxed in motoko's own working tree. `CODEX_EXTRA_FLAGS=` / `CLAUDE_EXTRA_FLAGS=`
  take it back per provider.
- A `ClaudeExec`-shaped `live_probe.ail` was deleted with the old `motoko-ext-codex` package. The
  real-loop test replaced it, but there is no longer a standalone probe.
