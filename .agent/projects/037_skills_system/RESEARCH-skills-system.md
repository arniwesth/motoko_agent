# RESEARCH: a skills system for Motoko

Date: 2026-10-03
Status: Closed. D1–D8 were decided by the operator on 2026-10-03 and are recorded in §7. D8's
premise failed a re-check the same day (§9 M3, cases H–J) and was ruled again in
`ADR-001-skills-system.md`, which is the decision record: Accepted v0.3 after two rounds of
independent review. Where the two differ, the ADR governs; its §5 lists the differences.
`PLAN-001-implement-adr-001.md` is the plan. No code yet.
Grounded at: working tree at HEAD `12589464` on `feat/explainer-tool`, AILANG v0.47.2, extension
ABI 8.0. The session began at `21ba95c9` on `main`; `git diff --stat` between the two is empty for
`src`, `packages`, `design_docs`, `.claude`, `scripts`, `.motoko/config`, `SYSTEM.md` and
`ailang.toml`. `Makefile` anchors are the working tree's, which carries an uncommitted change.
Evidence level: source inspection; the [Agent Skills specification][spec] fetched 2026-10-03; three
probes run 2026-10-03 (`evidence/`, §9); and a read-only survey of the extension gates by a
delegated agent (§10), of which only the items marked "verified" were re-read here. No prototype
extension exists, so nothing was measured inside the harness.
Supersedes: `design_docs/planned/m-motoko-ext-skills-import.md` (§2 says why), deleted in the
change that adds `ADR-001`.

## 1. Question and position

How should Motoko let an agent pick up task-specific instructions (a "skill") only when a task
needs them, register many of them, and load different ones during a session?

Position: adopt the Agent Skills format unmodified and implement it as **one extension package**
(`packages/motoko-ext-skills`) that treats skills as data. The extension scans `.motoko/skills`
at registration, advertises one `Skill` tool whose description carries the index, and returns a
skill's body as a tool result when called. ABI 8.0 already has the atoms for this. The operator's
decision that a broken or duplicate skill refuses startup (D1) is the one part that needs a small
core change, under the mechanism chosen in D2 (§6.2).

## 2. What exists

| Thing | Observed state | Implication |
| --- | --- | --- |
| `design_docs/planned/m-motoko-ext-skills-import.md` | Describes a format that does not exist: `skill.md` with `inputs`/`outputs` YAML and a `tools.json` (`:46`, `:50`, `:99`), `{{param}}` templating, one tool per skill, each run as a sub-agent. Written against the pre-6.0 `ExtensionHooks` record (`:163`). | Do not implement. This document replaces it. |
| `.claude/skills/` | Five tracked skills in the real format: `ailang-feedback`, `dagr-producer`, `herdr`, `observer`, `pr-review-loop`. Each frontmatter has exactly `name` and `description`; every `name` matches its directory. Descriptions are 309–585 chars (2,225 total); bodies are 132–498 lines. `observer` bundles `apply-grant.sh` and `examples/`; `dagr-producer` bundles `examples/`. | A working corpus on day one. All five pass the spec's naming rules. |
| `Capability` (`packages/motoko-ext-abi/types.ail:1942`) | `DescribeTools((Json) -> [ToolSchema])` `:1943`, `PromptShaper((PureCtx) -> PromptPatch)` `:1944`, `ToolPolicy` `:1947`, `ToolProvider` `:1948`. | Index, loader and optional gate all map to existing atoms. |
| `ExtPorts.file_read`, `path_stat`, `dir_list` (`types.ail:458`, `:501`, `:502`) | World-threaded FS seams available to a `ToolProvider` through `ProviderCtx`. | A skill load at call time is world-mediated. Not, as first written here, "journaled": a file read is not a recorded interaction (ADR-001 D13). |
| `packages/motoko-ext-mcp/register.ail:27` | Reads `mcp.json` at registration, puts the discovered server list in `config`, handler reads it back from `ctx.ext_config`. | The direct precedent for "one extension, N discovered things". |
| `packages/motoko-ext-herdr/register.ail:230` | `orchestrator_mode` runs at registration: `isDir`, then `listDir`, then `readFileResult` per entry, guarded by `path_within` the workdir (`:233`). | The precedent for scanning a directory at registration. Verified. |
| `packages/motoko-ext-ailang-docs/prompts.ail:46` | `task_signals_ailang` gates a prompt block on the task text. | Precedent for task-conditioned context, but only at session start (§5.4). |
| `src/tui/src/commands.ts` | Declarative slash-command registry; commands can be appended at runtime. | A `/skill-name` path has somewhere to land. |

## 3. The format

From the [specification][spec], fetched 2026-10-03:

- A skill is a directory containing `SKILL.md`: YAML frontmatter, then a Markdown body.
- `name` (required): 1–64 chars, `a-z`, `0-9` and hyphens, no leading, trailing or consecutive
  hyphens, and it **must match the parent directory name**.
- `description` (required): 1–1024 chars, says what the skill does and when to use it.
- Optional: `license`, `compatibility` (max 500 chars), `metadata` (a map from string keys to
  string values, for client-specific properties), `allowed-tools` (space-separated, experimental).
- Optional directories `scripts/`, `references/`, `assets/`; files are referenced by paths
  relative to the skill root.
- Progressive disclosure in three levels: metadata for all skills at startup (about 100 tokens
  each), the full body on activation (under 5,000 tokens recommended, under 500 lines), bundled
  files only when needed.

Two consequences for Motoko:

- `metadata` is where Motoko-specific keys (for example tool-call triggers, §4.2) can live
  without leaving the standard format.
- Claude Code skills carry extra frontmatter keys the spec does not list. Unknown keys must be
  ignored, not treated as broken, or reading `.claude/skills/` stops being possible.

## 4. Proposed shape

### 4.1 Registering many skills: one extension, skills as data

`register_with_config ! {Env, FS}` walks the skill root, `.motoko/skills` in the workdir (D7), for
`*/SKILL.md`, parses and validates the frontmatter, and returns:

- `config`: the list of `{ name, description, path, root }`, plus any validation failures (§6).
- `caps`: `DescribeTools` rendering **one** `Skill` schema, whose description lists every skill
  and whose `name` parameter is an enum of the discovered names; and
  `ToolProvider(["Skill"], handler)`.

Adding a skill is dropping a folder into the root. No rebuild and no `make registry_gen`.

One tool rather than one per skill, for two reasons. `ToolProvider` rejects duplicate tool names
within an extension (`src/core/ext/registry_normalize.ail:40`, `DuplicateToolName` `:150`), so
skill names would become a tool-namespace problem. And every skill would add a full schema to
every model call instead of one line in one description.

The handler must be declared in `register.ail` itself: an imported effectful function used as a
constructor argument charges its row to `register_with_config`
(`packages/motoko-ext-mcp/register.ail:13`).

A dedicated tool rather than "the model reads `SKILL.md` with `ReadFile`": `ReadFile` defaults to
200 lines (`src/core/tool_catalog.ail:36`) and `dagr-producer` is 498.

### 4.2 Loading on the fly: who decides

| Decider | Mechanism | Status in ABI 8.0 |
| --- | --- | --- |
| The model | Sees the index, calls `Skill(name)`; the handler reads the file through `ctx.ports.file_read` and returns the body. Bundled files are a third level: the result states the skill's base directory and the model reads or runs them. | Works today with `ToolProvider`. |
| The harness | A `ToolPolicy` denies a matching tool call with "load skill X first" until `history_slice` shows the load. Triggers come from `metadata` keys. | Works today; costs one step per forced load. The policy context carries history with its tool calls (`messages_to_msgs`, `src/core/session.ail:1964`; dispatched at `src/core/tool_phase.ail:567`). It cannot act when the model answers without calling any tool (§9 M2). |
| The user | `/name` in the TUI sends a turn naming the skill, or inlines the body. | Needs the runtime to emit the skill list as an event. |

### 4.3 Skills that appear mid-session

The index is captured at registration and frozen for the life of the runtime process. Two things
keep it usable:

- The handler resolves `name` against the filesystem when called, so a skill written after
  startup loads by name before it is in the index. A `Skill` call with no name can rescan and
  return the current list.
- Every respawn re-registers. The runtime is respawned with `--resume` on `/restart` and on wake
  after a parked wait (`src/tui/src/runtime-process.ts:837`, `:840`), and on crash resume.

## 5. Constraints found in the code

### 5.1 Compaction elides a loaded skill

Structural compaction acts when calibrated usage reaches 70%
(`packages/motoko-ext-compaction-structural/compaction_structural.ail:16`, `:173`). It elides
tool results older than the newest 10, and escalates to the newest 5, 3 and 1 (`:22`–`:28`). An
elided result keeps its first 80 chars plus `...[elided N chars]` (`:75`). §9 M3 measures this on
a real skill body, and shows three things the constants alone do not: being among the newest 10
is not protection, a skill that is 30% of the context limit is cut wherever it sits, and the 80
chars that remain are the start of the harness's JSON envelope, not of the skill text.

A skill body is a tool result, so the skill in use disappears mid-task on a long run. This also
unloads finished skills for free.

The default profile runs `compaction_ai` ahead of the structural compactor, at 75% with
`keep_recent: 10` (`.motoko/config/default/compaction_ai.json`). It replaces older turns with a
model-written summary (prompt at `packages/motoko-ext-compaction-ai/compaction_ai.ail:80`), so a
skill body in those turns survives only as whatever the summarizer keeps. It carries one tool's
latest result through the summary by name, `MotokoRuntimeStatus` (`:284`–`:344`), which is the
in-tree precedent for pinning. Its effect on a skill body was not probed.

### 5.2 The system-prefix digest and resume

The system prompt is built once, at session start (`src/core/rpc.ail:385`), and its digest goes in
the journal header (`:414`). A same-profile resume whose rebuilt prompt has a different digest is
refused unless `--resume-force` (`src/core/journal.ail:631`). `ext_set_digest` covers extension
ids and capability kinds only, not `config` (`src/core/ext/runtime.ail:1327`, test `:1555`).

So an index in the system prompt makes every added or reworded skill a resume refusal, including
at the routine respawns in §4.3. An index in the `Skill` tool's description does not.

### 5.3 The filesystem sandbox

The TUI launches the runtime with `AILANG_FS_SANDBOX` set to the workdir
(`src/tui/src/runtime-process.ts:475`). §9 M1 measures what `std/fs` does under it. In short: a
skill root outside the workdir cannot be read, a symlink does not get around that, and two of the
calls discovery needs (`listDir`, `readFile`) end the process instead of returning an error.

### 5.4 No push capability in 8.x

No hook can append a message before a model step. `PromptShaper` runs once with
`history_slice: []` and the first task (`src/core/rpc.ail:364`). `Compactor` can rewrite the
message list but would journal a skill load as a compaction. A real "inject context" capability
is a new `Capability` variant, and that waits for 9.0 (`packages/motoko-ext-abi/types.ail:29`).

### 5.5 No YAML in the standard library

**Wrong, corrected 2026-10-03.** This section said AILANG has no YAML module, because
`stdlib_search("yaml")` on the documentation server returned only incidental matches. One empty
search does not show absence. `std/yaml` is in the installed standard library
(`~/.local/share/ailang/std/yaml.ail`) and decodes all five existing skills
(`evidence/m5_yaml_probe.sh`). Found by the Codex review of ADR-001; ADR-001 D9 now uses it.

## 6. What "refuse at startup" requires

### 6.1 What counts as broken (proposed, to be fixed in the ADR)

Refuse:

1. A directory directly under a skill root with no `SKILL.md` (exact case). This catches the
   `skill.md` typo, which is the superseded design doc's own mistake.
2. An entry under a skill root that is neither a regular file nor a directory. Under the sandbox
   that is what a symlink to outside the workdir, or any absolute-target symlink, looks like
   (§9 M1). Ignoring it would drop a skill silently.
3. `SKILL.md` unreadable.
4. No frontmatter block at the top, or frontmatter outside the parser's supported subset.
5. `name` missing, empty, outside the spec's charset or length, or not equal to the directory
   name.
6. `description` missing, empty, or over 1024 chars.
7. The same `name` in two roots. Cannot occur under D7: there is one root, and rule 5 ties each
   name to its directory. The rule stands for the day a second root is added.
8. A configured root that is absolute or contains `..`. Checked on the string, because `isDir`
   answers `false` for "outside the sandbox" and "does not exist" alike. Not reachable under D7,
   where the root is fixed; it applies if the root ever becomes configurable.

Do not refuse: a root that does not exist; regular files in a root (`.DS_Store`);
unknown frontmatter keys (§3); bodies over the spec's recommended size. `dagr-producer` is 498
lines and about 5,800 tokens at char/4, already over the 5,000-token recommendation.

The refusal should report every violation in one message, each naming its file and rule, so
fixing skills is not a restart loop.

### 6.2 How an extension refuses

`ExtRegistration` is `{ config, caps }` (`types.ail:2000`) with no error channel, and it cannot
gain a field within 8.x (`types.ail:27`). No `register_with_config` in the tree calls `println`
or `exit`. The host's refusal site is `parse_tokens`, which prints a JSONL `error` event and
exits 2 when `normalize_registration` rejects (`src/core/ext/registry_generated.ail:107`).

| Option | What changes | Cost |
| --- | --- | --- |
| R1. The extension emits the error event and calls `exit(2)` itself | Nothing in core; `IO` joins the registration row | First extension to end the process. Refusal logic and message format live outside the host boundary. Adds an ambient `IO` source at registration. |
| R2. The extension reports violations in a reserved `config` key; `normalize_registration` rejects on it | A sixth `RegistrationRejection` variant in hand-written `registry_normalize.ail`: three matches to extend (`rejection_rule`, `rejection_extension`, `rejection_message`, `:154`–`:186`) and one check in `normalize_registration` (`:330`, pure, so the rule gets inline tests). The generated registry is untouched: it prints `rejection_message(e)` generically. | A small core change, and a reserved key is a convention the ABI comments must state. New `pure func`s under `src/core/ext` fall under `new_contract_policy` in CI (§10). |
| R3. A typed refusal in the registration result | ABI 9.0 | Out of proportion for one extension. |

Decided (D2): R2. The question D1 answered was whether a bad skill should refuse startup the way a
mis-registered extension does, and that refusal is host-owned and enforced at one site. R2 also
fits the registration-shape gate, which wants a literal `{ config, caps }` at the tail of
`register_with_config` with no `if` or `match` (§10): the refusal travels as data.

Either option makes CI enforce skill validity once `skills` is in the default profile.
`verify_extensions`, a prerequisite of `check_core`, boots every extension in that profile's
order through `parse_core_ext_order` (`scripts/verify_extension_boot.ail:60`, verified), so a
broken skill in the repository fails the build.

### 6.3 Consequences of D1 (recorded, not reopened)

- The refusal is unconditional. It does not depend on `extensions.strict`, which is `false` in
  the default profile (`.motoko/config/default/config.json:53`).
- A broken skill arriving by `git pull` or a branch switch blocks every session in that workdir,
  including the resume of a session already in flight, since each respawn re-registers.
- A skill the agent is halfway through writing blocks its own next respawn. If agent-authored
  skills are wanted later, they need a staging location outside the scanned roots.
- A skill that breaks after startup cannot refuse startup. The call-time path (§4.3) returns a
  tool error for it, and the next respawn refuses.
- Duplicates refuse, so there is no precedence order and no way for one root to override another.
  With the single root of D7 a duplicate cannot arise.

## 7. Decisions

All decided by the operator on 2026-10-03.

| # | Decision | Decided | Evidence and notes |
| --- | --- | --- | --- |
| D1 | A broken or duplicate skill | **Refuse at startup.** | Consequences in §6.3. |
| D2 | Refusal mechanism | **The host rejects (R2).** The extension reports violations as data in a reserved `config` key; `registry_normalize.ail` gains one rejection variant. | §6.2. The validity rules are §6.1. Parser subset proposed, not yet confirmed: single-line scalars, quoted strings, `>` and `\|` block scalars, and a one-level `metadata` map. |
| D3 | Format | **Adopt `SKILL.md` unmodified.** | The five existing skills validate unchanged (§2). |
| D4 | Where the index lives | **In the `Skill` tool description.** A skill-set change does not refuse resume. | M2 found no difference in triggering (139/150 each), so §5.2 decides it. |
| D5 | Harness-forced loading through `ToolPolicy` | **Not in v1.** | In M2 most misses on the weakest model were answers with no tool call, which a tool-call gate cannot catch. |
| D6 | `/skill-name` in the TUI | **Not in v1.** | Needs the runtime to emit the skill list first. |
| D7 | Skill roots | **`.motoko/skills` only.** The recommendation was to read `.claude/skills` as well; the operator chose one root. | M1: roots outside the workdir are unreadable. Consequence: the five skills in `.claude/skills` are not visible to Motoko until they are copied, moved, or reached by a relative symlink, which M1 shows is followed. |
| D8 | Keeping the active skill through compaction | **Reload marker**, as put to the operator: the tool result begins with a `[skill <name> loaded]` line, and the `Skill` description says to call again when a result shows as elided. **Premise failed, needs a new ruling.** | The decision was taken on M3 case F. Cases H–J, run afterwards with the message the harness really builds, show the marker line does not survive. What does survive is the assistant message's own `Skill({"name": ...})` call. The reload instruction in the tool description still stands; the marker adds nothing. |

Smaller items for the ADR:

- How the five existing skills reach `.motoko/skills` (copy, move, or relative symlink), and
  whether that is part of this project at all.
- A per-profile allow or deny list, so a skill such as `observer` loads only where it applies.

- Zero skills found: always register the `Skill` tool. Returning no capability fails
  `verify_extensions` when the extension is in the default profile (§10), and the shape gate
  wants a literal `caps` list.
- Whether the tool result should map Claude Code tool names to Motoko's, since the existing
  bodies were written for Claude Code. Not measured.
- Whether `allowed-tools` is honoured, ignored or refused.
- A model calling a tool named after a skill instead of `Skill` (seen once in M2). The handler
  for unknown tools decides what the model is told.

## 8. Not in v1

- Running a skill as a sub-agent. The herdr and agentcli delegation paths exist if this is wanted.
- A push capability (§5.4).
- Harness-forced loading (D5) and `/skill-name` in the TUI (D6).
- A second skill root, including `.claude/skills` (D7).
- User-global or remote skill sources, a marketplace, versioning.
- Agent-authored skills as a supported workflow (§6.3).

## 9. Measurements, run 2026-10-03

Scripts and data are in `evidence/`. All ran on AILANG v0.47.2.

### M1. `std/fs` under the sandbox (`m1_sandbox_probe.sh`)

One process per call, `AILANG_FS_SANDBOX` set to a temporary workdir.

| Call | Path inside the workdir | Path outside, `..` escape, or symlink to outside |
| --- | --- | --- |
| `isDir`, `isFile`, `fileExists` | `true` | `false`, no error |
| `readFileResult` | `Ok` | `Err("... escapes sandbox ...")` |
| `readFile` | not run | process ends, exit 1 |
| `listDir` | sorted names, including files and symlinks | process ends, exit 1 |

- `listDir` on a root that does not exist also ends the process. There is no `Result` variant of
  it, so discovery must call `isDir` first.
- A symlink with a relative target inside the workdir is followed, for files and directories.
- A symlink with an absolute target is refused even when the target is inside the workdir, and
  `isFile`/`isDir` report `false` for it.
- Without the variable, the same outside read returns `Ok` (control).

### M2. Does the model call `Skill`, and does index placement matter (`m2_trigger_probe.py`)

A proxy, not the harness: one chat-completions request per case to OpenRouter, with `SYSTEM.md`
as the system message, the seven native tool schemas, and one `Skill` tool built from the five
skills. Ten tasks that match a skill (two per skill) and five that match none, five trials each,
three profile models, 450 requests. Only the first response is scored. Data: `m2_results.tsv`.

| Model | Index in tool description | Index in system prompt |
| --- | --- | --- |
| `meta/muse-spark-1.3-contributor` (default profile) | 43/50 | 41/50 |
| `deepseek/deepseek-v4-pro` | 49/50 | 50/50 |
| `deepseek/deepseek-v4-flash` | 47/50 | 48/50 |
| Total | 139/150 | 139/150 |

- No control task produced a `Skill` call: 150/150 under both placements.
- On the two DeepSeek models every miss was an `ailang-feedback` task where the model called
  `ReadFile` first. A model that investigates and loads the skill on its second step is counted
  as a miss here.
- On `muse-spark`, 12 of 16 non-hits were answers with no tool call at all, 3 searched first, and
  1 called `Skill` with `{}`.
- An earlier 5-trial run of the same script, before the scoring was refined, gave 137/150 for
  both placements. Its data file was overwritten. It included one case of `deepseek-v4-flash`
  calling a tool named `pr-review-loop` directly.

Limits: the profile's extension tools and prompt patches were absent, no skill body was ever
returned, and five skills is a short index. Roughly 3.75M prompt tokens across all runs, about
$0.50.

### M3. Structural compaction on a loaded skill (`m3_compaction_probe.sh`)

Calls the real `compact_for_pre_step` on a synthetic history: the `observer` `SKILL.md` (12,450
chars) as one tool result, followed by other tool results. No model.

Cases A–G put the skill text in the tool message as-is, which isolates the compactor:

| Case | Result |
| --- | --- |
| 50% usage, 20 later tool results | Untouched. |
| 72% usage, skill is the 11th newest tool result or older | Elided at tier 1: 12,450 → 103 chars. |
| 72% usage, skill is the 10th newest | Tier 1 changes nothing, so the compactor escalates to keep-last-5 and elides it. |
| 72% usage, skill alone is over 30% of the limit (tried as 4th and 3rd newest) | Cut regardless of position, with `[large tool result capped; use grep or offset+limit instead of re-reading in full]` appended. |
| As the second case, with a marker as the first line of the text | The marker is inside the first 80 chars, so it survives. |

Cases H–J use the message the harness really builds for an extension tool result. It is not the
text the extension returns: `handled_tool_message` (`src/core/phase_vocab.ail:1629`) encodes the
whole envelope as JSON, in the field order `tool_call_id`, `tool`, `exit_code`, `stdout`,
`stderr`, `metadata` (`src/core/tool_contract.ail:60`). The skill text is the `stdout` value, and
it starts 58 chars plus the length of the tool-call id into the message. The ids in recent
session journals are 37 chars (`call_` and 32 hex digits), which puts it at char 95.

| Case | What is left after elision |
| --- | --- |
| H. Envelope, 37-char id | `{"tool_call_id":"call_0123456789abcdef0123456789abcdef","tool":"Skill","exit_cod...[elided 12836 chars]` |
| I. As H, `stdout` starts with the marker line | The same. The marker is past char 80. |
| J. As I, with a 6-char id | `{"tool_call_id":"call_1","tool":"Skill","exit_code":0,"stdout":"[skill observer ...[elided 12830 chars]` |

- **A marker in the skill text does not survive.** Case F's result does not carry over to the
  real message, and D8 was decided on case F.
- **The call survives.** Elision rewrites only `tool` messages, so the assistant message that
  made the call still reads `Skill({"name":"observer"})`. After elision the model sees that it
  loaded `observer` and that the result is elided, without any marker.
- The 30% cap's appended advice tells the model not to re-read in full, which is the opposite of
  what a skill needs. It applies when the context limit is small relative to the skill: under
  about 10,400 tokens for `observer`, 19,400 for `dagr-producer`.
- Tool message content is capped at 65,536 chars with a truncation note
  (`src/core/phase_vocab.ail:1559`). A `SKILL.md` whose encoded envelope is longer would be
  loaded cut short.
- Not measured: `compaction_ai` (§5.1), and whether a model reloads a skill on seeing an elided
  result.

## 10. Cost of adding the package (M4)

From a read-only survey by a delegated agent. Items marked "verified" were re-read for this
document; the rest are that survey's reading and the PLAN must re-ground them.

**Files.** The last extension added (`ailang_tools`, commit `140dde9e`) touched seven: the root
`ailang.toml` (a `[dependencies]` path line and an `[extensions].packages` entry), the root
`ailang.lock`, `src/core/ext/registry_generated.ail` through `make registry_gen`, and the package
directory (`ailang.toml`, `register.ail`, its modules, `ailang.lock`). A profile enables it by
naming `skills` in `extensions.order`.

**Gates in CI.**

- `check_core` runs `verify_extensions`, which boots every extension in the default profile and
  requires at least one registry entry (verified, `Makefile:2814`). A registration that returns
  no capability fails it.
- `profile_definition` and `ext_call_inventory` go red on unresolved shapes: `import std/x as X`,
  a helper whose name starts with `_`, the `*E` functions of `std/list`, a port called through an
  untyped receiver, or `ports.env_get`.
- `new_contract_policy` requires a contract or a recorded excuse for each new `pure func` under
  `src/core`, which applies to R2.

**Registration shape** (`ext_hook_scope`, not in CI): the tail of `register_with_config` is the
literal `{ config, caps }`, `caps` a literal list, each payload a named top-level function in
`register.ail`. Conditionality goes in data.

**Pins outside CI** (`make dst` only) that a new extension moves: the two `expected.json`
fixtures under `tools/ext_ambient_inventory/fixtures/`, a `reg_skills`/`budget_skills` pair and
the `absorb Env`/`absorb FS` counts in `scripts/dst/declared_vs_performed.ail` and its runner,
and the `not_installed()` lists in `dst_driver_plus_no_ops.ail` and `dst_driver_plus_compose.ail`
with their count tests (the count tests do run in CI).

**Handler style.** Calls through `ctx.ports.file_read`, `dir_list` and `path_stat` are recorded
by `ext_call_inventory` and not gated. Direct `std/fs` in the handler is not rejected by any
gate, but reads as ambient in the hook-scope report.

**Not needed.** The conformance package covers only `Compactor` atoms. The registration-effects
amendment in project 009 is still a draft.

**Pre-existing drift, not this project's.** The survey reports the extension-count pins already
stale by one since `ailang_tools` was added, and `ext_hook_scope` exiting 1 on `test_dummy`'s
registration shape. If so, the re-pin for this package is +2. Not verified here.

## 11. Expected artifact sequence

`RESEARCH` (this, closed) → `ADR-001` (Accepted v0.3) → `PLAN-001` (Proposed) → implementation in
`packages/motoko-ext-skills`.

## Related records

- `design_docs/planned/m-motoko-ext-skills-import.md` (superseded by this document)
- `.agent/projects/017_extension_handling/ADR-001-extension-abi-evolution.md`
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`
  (ABI 8.0 views and the stability rule)
- `.agent/projects/033_release/ADR-001-release-scope.md` (ABI stability after the release)
- `.agent/projects/009_motoko_dst_execution/DRAFT-amendment-adr-001-registration-effects.md`

[spec]: https://agentskills.io/specification
