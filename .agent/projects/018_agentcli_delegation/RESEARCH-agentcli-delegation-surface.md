# RESEARCH: `motoko-ext-agentcli` — what it is, and where it does not hold

Date: 2026-08-20
Status: Research — measured baseline + ranked problem statement. **No decisions taken.**
**F-6 has a successor: `../021_herdr_delegation/RESEARCH-herdr-delegation-surface.md` (2026-08-22)**
answers it with herdr rather than tmux, and re-verifies every finding below at the same HEAD. One
piece of §1 has drifted since this was written — `codex` is no longer installed in this devcontainer;
021 §1 has the measurement. Read this document first: 021 is organised along these findings and does
not restate them.
Grounded at: branch `arniwesth/mot-101-agentcli`, HEAD `d992d73`. Every anchor below was read at
that HEAD; the two external anchors (`ailang/`, `src/tui/`) were read in the same tree.

Relates to:
- `packages/motoko-ext-agentcli/` — the subject: `providers.ail` (126), `agentcli.ail` (234),
  `register.ail` (58), plus `ailang.toml` / `ailang.lock`.
- `.agent/summaries/2026-08-17-subscription-billed-delegation-and-three-broken-seams.md` — the
  build record. It holds the measurements this doc treats as settled (which stream carries a
  failure, `--bare` and OAuth, `gpt-5-codex` on ChatGPT auth, the vendor table). Read it before
  re-measuring anything in §2.
- `.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md` §Fix.3 and §Related — where the
  30 s `--process-timeout` default was already named as an inherited default nobody chose.
- motoko_agent#158 (`BashExec` wrap drops `req.args`) — still open, still true at
  `src/core/tool_runtime.ail:888-894`; it is why this extension uses ambient `exec`.
- motoko_agent#159 (registry regeneration widens the effect row) — closed at `8916b16`; the
  narrow row now lives in `ailang.toml [extensions] effects`.
- `.agent/projects/017_extension_handling/RESEARCH-extension-abi-evolution.md` — any fix here that
  wants a new ABI slot or a new `ExtPorts` door pays that doc's 16-package price.
- `../019_agent_confined/` and `.devcontainer/agent_confined/` — **the container this extension's
  delegates run inside.** It carries the measured state of that container, and it is
  where §2.6's "externally sandboxed" premise and F2's billing guard are actually decided. Read it
  before designing either.
- `tools/tmux-web/` and `.devcontainer/agent_confined/` — copied in from another project on
  2026-08-20; inventoried and translated in 019. Relevant here because a delegate launched as a
  named tmux session is visible, interactive, and outlives the exec call — see fork F-6.
- `design_docs/planned/m-motoko-acp-integration.md` Phase 3 (`ext/acp-subagent`) — the same
  problem one protocol up. Whatever this project decides about transcript decoding and session
  resume is the thing ACP would standardise.

---

## TL;DR

The extension is small, well-reasoned, and its documented decisions are sound. What is not sound is
everything it **inherits** from the process it runs inside. Two of those inherited defaults defeat
its two purposes:

1. **It cannot outlive 30 seconds.** `std/process.exec` takes AILANG's `--process-timeout`, default
   `30s` (`ailang/cmd/ailang/main_run.go:81`), and the TUI passes no value
   (`src/tui/src/runtime-process.ts:474-491`). Every delegated run longer than that returns
   `Err(Timeout)` — which `agentcli.ail:141` reports as *"could not be spawned; is the CLI installed
   and on PATH?"*. The tool is unusable for real tasks and lies about why.
2. **The subscription lane is not true by construction.** The module header
   (`agentcli.ail:29-35`) says the API-key unset "belongs in whatever launches motoko". The launcher
   does the opposite: `src/tui/src/runtime-process.ts:326-327` explicitly forwards
   `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` into the runtime child, and ambient `exec` inherits that
   env. If either key is set, the delegate plausibly bills metered dollars while the envelope
   states `"billing":"subscription-quota"`.

Below that: head-first truncation drops the delegate's answer (§3 F3), the advisory lock can wedge a
provider permanently (F4), and the package carries no tests (F8).

---

## 1. What exists today, measured

**Shape.** One extension, two tools, three modules, one dependency (`motoko-ext-abi` 5.0).

| Module | Holds |
|---|---|
| `providers.ail` | `Provider` record + `codex_provider()` / `claude_provider()` + `argv_for` + `failure_text`. Everything provider-specific is data. |
| `agentcli.ail` | Provider-agnostic: dispatch, lock, exec, truncate, envelope, billing metadata. Seven of eight hook slots are explicit no-ops. |
| `register.ail` | Env resolution — `CODEX_MODEL` / `CLAUDE_MODEL`, `CODEX_EXTRA_FLAGS` / `CLAUDE_EXTRA_FLAGS`, `AGENTCLI_MAX_OUTPUT_CHARS`, `MOTOKO_PROFILE_DIR`. |

**Wiring.** Declared in root `ailang.toml` (dependency + `[extensions] packages` at `@0.1.0`),
resolved at `src/core/ext/registry_generated.ail:45`, and enabled in exactly **one** profile:
`.motoko/config/default/config.json:37`. No other profile lists `agentcli`.

**Seam.** `on_tool_handle`. The host gates it on `provided_tools` (`src/core/ext/runtime.ail:404`),
and `src/core/tool_phase.ail:368` renders `Handled(envelope)` into the model's tool message via
`result_env_model_content` (`src/core/phase_vocab.ail:891`), which JSON-encodes the whole envelope
and caps it at 64 KiB with a visible truncation marker.

**Runtime path.** `std/process.exec(bin, argv)` — ambient, not `ExtPorts.proc_exec`. Both CLIs are
installed in this container (`/home/motoko/.local/bin/codex`, `/home/motoko/.local/bin/claude`).

---

## 2. Decisions already taken — do not re-litigate without new measurement

Each of these is documented at its call site and was paid for once. They are listed so this project
spends its cycles on §3 instead.

1. **Dispatch by tool name, not a `provider` enum** (`providers.ail:106-115`). A wrong enum value
   bills the wrong account silently; models pick tools more reliably than they fill enums.
2. **`failure_on_stdout` is a per-provider field, not a shared convention** (`providers.ail:11-24`).
   codex reports failure on stdout NDJSON, claude on stderr — exact mirrors, both measured
   2026-08-16 with a deliberately bad `--model`. A decoder written to either convention silently
   reports the wrong text for the other.
3. **No dollar figure is emitted for either provider** (`agentcli.ail:96-110`). Claude Code returns
   a populated `total_cost_usd` even under plan auth (0.144036 on a measured one-word run); that is
   an API-equivalent price, not spend. Critical Principle 2.
4. **Ambient `exec`, not `ExtPorts.proc_exec`** (`agentcli.ail:20-27`), because of #158. What is
   given up is WI-D24 holder stamping. Reversing this requires #158 to close first.
5. **`-p` pinned without `--bare`** (`providers.ail:70-76`): `--bare` does not read
   `CLAUDE_CODE_OAUTH_TOKEN`, and it is scheduled to become `-p`'s default. Re-check on Claude Code
   upgrades — this is a standing obligation, not a settled fact.
6. **The permission bypass is ON by default for both providers** (owner, 2026-08-16). The delegate
   runs unsandboxed in motoko's own worktree. `CODEX_EXTRA_FLAGS=` / `CLAUDE_EXTRA_FLAGS=` take it
   back per provider.
   *Added 2026-08-20 — the decision stands; its PREMISE has moved and is being examined in 019.*
   `codex --help` says of this flag: *"EXTREMELY DANGEROUS. Intended solely for running in
   environments that are externally sandboxed."* Project 019 §2 measures that motoko's container is
   not one today. Separately, the flag is on partly because nothing can answer an approval prompt —
   and `tools/tmux-web` is an interactive pane, so that constraint is no longer forced either. Both
   are inputs to a future re-decision by the owner, not a re-litigation by this doc.
7. **There is no `on_model_call` seam**, so this moves *delegated* work onto plan quota and cannot
   move motoko's own driver loop. `src/core/model_phase.ail` dispatches no hook.

---

## 3. Findings, ranked

Ranking is by *how much it costs a real delegated task today*, not by how hard it is to fix.

### F1 — Delegation dies at 30 s, and reports it as "not installed"

**Symptom.** Any `CodexExec` / `ClaudeExec` run longer than 30 seconds — i.e. every non-trivial
task — returns exit code `-1` with *"codex could not be spawned; is the CLI installed and on PATH?"*.

**Evidence.**
- `ailang/cmd/ailang/main_run.go:81` — `--process-timeout` default `"30s"`.
- `src/tui/src/runtime-process.ts:474-491` — the `ailang run` argv passes neither
  `--process-timeout` nor `--process-max-output`.
- `packages/motoko-ext-agentcli/agentcli.ail:138-142` — a single `Err(_)` arm collapses
  `Timeout(ms)`, `OutputLimitExceeded(bytes)`, `NotFound`, `PermissionDenied`, `NotAllowed`,
  `AbnormalExit` and `SpawnFailed` into one PATH-flavoured sentence. `std/process.ail:24-31` names
  all seven constructors.
- Already recorded from the other side in
  `.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md` §Related.

**Two independent defects.** The wall (an inherited default nobody chose) and the misreport (this
module's `Err(_)`). Fixing only the wall leaves the next `OutputLimitExceeded` equally mysterious;
fixing only the message leaves the tool useless. The second is entirely inside this package.

**Also unowned:** `--process-max-output` defaults to 10 MB. A long codex transcript is a plausible
hit, and it currently lands in the same misleading sentence.

### F2 — The subscription guard is inverted in the shipped launch path

**Symptom.** The one thing this extension exists for — *runs bill plan quota, not dollars* — is not
guaranteed under the TUI, and the envelope asserts it anyway.

**Evidence.**
- `agentcli.ail:29-35` — the module states the unset "belongs in whatever launches motoko", citing
  `mission-control.sh:76`'s subscription-or-nothing-by-construction argument.
- `src/tui/src/runtime-process.ts:323-328` — `childEnv` explicitly forwards `ANTHROPIC_API_KEY`,
  `OPENAI_API_KEY` (and `OPENROUTER_API_KEY`) into the runtime process.
- `agentcli.ail:103-110` — the envelope metadata states `"billing":"subscription-quota"`
  unconditionally.

**Why the obvious fix is wrong.** The TUI forwards those keys because motoko's *own* `AI` effect
needs them for `agent.model`. Unsetting them in the launcher breaks the driver loop. The scrub has
to be per-child, at the delegate's exec — and `std/process.exec` (`std/process.ail:59-64`) takes no
env parameter, so AILANG cannot unset for a child. The only in-reach shape is argv-level
(`env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY <bin> …`), which is a one-line change to `argv_for`
and worth pricing against an `ExtPorts` env door.

**Where this is decided.** The scrub is a property of whatever launches the delegate, so the fix
lives with the container as much as with this package — `.devcontainer/agent_confined/docker-compose.yml`'s environment block
holds the env-surface decision, and this finding is why that item is not merely hygiene.

**Unmeasured, and it decides the severity.** *Does* each CLI prefer the env key over its stored
subscription credential when both are present? The build summary asserts it for both; it is stated
there without a measurement, unlike everything else in that document. Measure before designing.

### F3 — Head-first truncation removes the delegate's answer

**Symptom.** For any transcript over `AGENTCLI_MAX_OUTPUT_CHARS` (default 8000), the model receives
the delegate's *preamble* and never its result — with no marker saying so.

**Evidence.**
- `agentcli.ail:92-94` — `truncate` keeps `substring(s, 0, limit)`. No ellipsis, no
  original-length note. Contrast `src/core/phase_vocab.ail`'s `cap_tool_message_content`, which
  appends `"...[truncated; original …"`.
- codex `exec --json` emits NDJSON where the agent's reply is an `item.completed` event with
  `item.type == "agent_message"`, and the terminal `turn.completed` (carrying usage) is **last** —
  see AILANG's own decoder, `ailang/internal/executor/codex/events.go:24-28` and
  `codex.go:286-316`.
- claude `-p --output-format json` returns one object whose answer is a single field.
- Nothing in the package parses either format; `run_delegate` (`agentcli.ail:145-158`) passes raw
  stdout through.

**Consequence.** Every extra step the delegate takes makes its answer *less* likely to reach the
model. Cost scales with transcript length while usefulness falls — the wrong direction.

**Note.** A decoder is exactly what §2.2 warns about if written to one provider's convention, so
this is per-provider work, and `events.go` is a usable reference for the codex half.

### F4 — The advisory lock can wedge codex permanently

**Symptom.** If motoko dies mid-delegate, `${MOTOKO_PROFILE_DIR}/agentcli-exec.lock` survives and
every subsequent `CodexExec` returns *"already running for this profile"* forever. Nothing clears it
and nothing tells the user to.

**Evidence.** `agentcli.ail:84-90` (`lock_held` — existence is the whole test),
`:137`/`:144` (write/remove around the exec), `:112-121` (the busy envelope). The file's content is
`prov.id` — no pid, no timestamp, so staleness is not even *derivable*, let alone checked.

**Already acknowledged:** stat-then-write is not atomic (`agentcli.ail:80-83`); the header argues it
serialises the sequential case and fails closed otherwise. Staleness is a different failure from
raciness and is not covered by that argument.

### F5 — No working-directory control

`ExtCtx` carries both `cwd` and `workdir` (`packages/motoko-ext-abi/types.ail:539,543`); neither is
read. The delegate inherits motoko's process cwd, with the permission bypass on (§2.6). Delegating
"fix the tests in `packages/foo`" cannot be scoped, and `codex --cd` / `claude --add-dir` are not
reachable — see also F7, which blocks passing them by hand.

### F6 — Configuration is env-only; `RuntimeConfig` is ignored; providers are hardcoded

`register_with_config(_cfg: a)` (`register.ail:50`) discards the config it is handed. There is no
`${MOTOKO_PROFILE_DIR}/agentcli.json`, unlike `motoko-ext-mcp` (`register.ail:8-10`) and
`motoko-ext-a2a` (`config.ail:38-46`), which read exactly that. Consequences: per-profile provider
sets are impossible (agentcli is all-or-nothing per profile), and adding Gemini / Qwen / Copilot
means editing AILANG and republishing the package rather than writing a descriptor.

### F7 — `*_EXTRA_FLAGS` can only ever carry one argv element

`flags_of` (`register.ail:33-35`) returns `[raw]`, so `CODEX_EXTRA_FLAGS="--cd /x --foo"` reaches
the CLI as the single argument `"--cd /x --foo"` and is rejected. The header documents the knob as
deliberately un-parsed ("one knob per provider rather than a parsed list") but does not state that
the value must therefore be exactly one token — and the failure surfaces as an opaque CLI usage
error. This is the reason F5 has no workaround.

### F8 — No tests, no probe

No inline `tests [...]` anywhere in the package, against 12 sibling extension packages that carry
them. The `ClaudeExec`-shaped `live_probe.ail` was deleted with the old `motoko-ext-codex` package,
so there is no standalone way to exercise a provider without a full loop run. Pure and testable
today with no restructuring: `argv_for`, `failure_text`, `provider_for_tool`, `tool_names`,
`flags_of`, `truncate`, `parse_int_or`, `arg_str`.

---

## 4. Open forks — owner decisions this project needs

- **F-1. What is delegation *for*?** Long autonomous sub-tasks (then F1 needs a real timeout budget,
  and progress/heartbeat becomes a question) or short bounded fan-out (then a modest timeout plus
  an honest error is nearly the whole fix)?
- **F-2. Does the extension become opinionated about transcripts?** Decode per provider and return
  the answer plus a usage summary (F3), or keep passing raw text and fix only the truncation
  direction and marker?
- **F-3. Is the billing guard this module's job after all?** F2 shows the launcher does the
  opposite of what the header assumes. Argv-level `env -u`, an `ExtPorts` env door, or a TUI change?
- **F-4. Does the provider table become data?** (F6) That is also the question of whether this is
  "the codex/claude extension" or "the delegated-CLI extension".
- **F-5. Relationship to ACP Phase 3** (`ext/acp-subagent`). Does this package become the ACP
  client's local-CLI fallback, or is it superseded?
- **F-6. Does a delegate become a tmux session rather than a captured subprocess?** *(added
  2026-08-20; **answered in 021**, with herdr in place of tmux — it supplies the typed state and the
  result channel this sketch had to leave to `--json` + `-o last-message.txt`)* `tmux new-session -d -s codex-<id> …` returns in milliseconds, so the 30 s
  `--process-timeout` (F1) stops applying to the delegate; liveness becomes `tmux has-session`
  instead of a lock file that carries nothing to check staleness against (F4); and the run is
  visible and typeable in `tools/tmux-web` with no integration code, because its session list is
  discovered from `tmux list-sessions`. The answer still has to come from `--json` +
  `-o last-message.txt` (F3) — the pane is not a result channel and has no scrollback replay.
  **This fork is upstream of F-1**, because a detached session cannot return synchronously. Requires
  `tmux` in the image — 019 §4.2.

## 5. What must be measured before designing

1. Does `codex` prefer `OPENAI_API_KEY` over `~/.codex/auth.json`, and `claude` prefer
   `ANTHROPIC_API_KEY` over its stored login, when both are present? (Decides F2's severity.)
2. Does `env -u KEY codex exec …` through ambient `exec` actually reach subscription auth? (Decides
   F2's cheapest fix.)
3. What is a realistic delegated-task wall-clock and transcript size for each provider? (Sets the
   timeout budget in F1 and the truncation limit in F3.)
4. Does `--process-timeout` on the `ailang run` argv actually govern `std/process.exec` inside a
   deep extension call, and does `Err(Timeout(ms))` carry the elapsed value? (Confirms F1's fix.)
5. Does `AbnormalExit` fire when a delegate is killed, and does the lock get released on that path?
   (Confirms F4's blast radius.)
