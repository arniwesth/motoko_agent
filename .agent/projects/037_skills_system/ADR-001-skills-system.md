# ADR-001: A skills system for Motoko — one extension, skills as data

Date: 2026-10-03. Status: **Accepted v0.3 — v0.2 was accepted by the operator (all ten rulings
of §6); a second review (REVIEW-002) found that two of those rulings rested on things that do
not hold; D2 and D7 were revised and the operator ruled on both again the same day. Implemented
by `PLAN-001-implement-adr-001.md`. Nothing is executed.** Grounded at HEAD
`8dc2febf` on `feat/explainer-tool`, installed AILANG v0.47.2, extension ABI 8.0. The cited paths
are unchanged since `21ba95c9` on `main`, where the research began.

Asked for by `RESEARCH-skills-system.md` §11 (this folder). Its analysis and probes (§9,
`evidence/`) are the evidence and are not restated. Every coordinate below was re-checked at
`8dc2febf`, and the structural claims were checked against a code graph built at `09cd5a5e`
(§7); the cited paths do not differ between the two.

Reviewed twice, by Claude Fable 5.1 and Codex GPT-6-Astra working separately: `REVIEW-001-*`
against v0.1 ("sound with changes") and `REVIEW-002-*` against v0.2 ("ready after changes").
Each file ends with how every finding was handled. §5 lists what each version got wrong.

Replaces `design_docs/planned/m-motoko-ext-skills-import.md`, deleted in the change that adds
this file. It described a skill format that does not exist and the pre-6.0 extension ABI
(research §2). Three point-in-time records in project 031 still name it.

**v0.2 changes.** The frontmatter is decoded by `std/yaml`, which exists; v0.1 said it did not
(D9). The skill root is located by a stated rule, because registration cannot see the workdir
(D7). The root itself has refusal rules, and the rules are stated against the filesystem sandbox
(D1). A skill too large for the model's context is a tool error, not a load (D8). The handler
validates what it reads on every call (D10). The refusal key is an amendment to the ABI ADR with
defined semantics (D2). The index has a total budget and a stated relation to the config digest
(D4). Default-profile membership is decided (D11). D13's facts are corrected. The plan measures
with a throwaway prototype before any core change (§4).

**v0.3 changes.** The skill root is the bare relative path again, with a measurement of why
that is right; v0.2's environment-variable rule is withdrawn (D7). The directory shown to the
model is relative to the workdir, which is the only form its file tools accept (D10). The
refusal key needs no ABI version change, and the extension fails safe on a host that ignores it
(D2). What Motoko validates is stated instead of counted (D3). The config-digest claim is
limited to the index, and the budget is checked against providers (D4). The size check measures
what the compactor measures (D8). Directories that cannot be listed join the stated limits (D1).
The gate baseline moves to the front of the plan (§4).

## TL;DR

- **Problem.** Motoko has no way to give an agent task-specific instructions only when a task
  needs them. Everything is either in the system prompt for the whole session or absent.
- **Decision.** One extension package, `motoko-ext-skills`. A skill is a folder under
  `.motoko/skills` holding a standard `SKILL.md`. The extension advertises one tool, `Skill`,
  whose description lists every skill's name and description, and returns a skill's text as the
  tool result when the model calls it. (D3, D4, D7)
- **Fail closed.** A broken skill, or a broken skill root, refuses startup. The host does the
  refusing, through one new rejection variant at the registration boundary; the extension
  reports violations as data. That needs an amendment to the ABI ADR. (D1, D2)
- **Not in v1.** Harness-forced loading, `/skill-name` in the TUI, any second skill root,
  per-profile selection, and membership of the default profile. (D5, D6, D7, D11)
- **Compaction.** A loaded skill can be elided once usage reaches 70%. v1 relies on a standing
  instruction to call `Skill` again, refuses to load a skill the context cannot hold, and
  measures in the harness how often models reload. (D8)
- **DST.** Loading goes through a world-mediated port; discovery runs before any world exists
  and is disclosed, not mediated. In v1 the extension is installed in no DST profile. (D13)

## 0. The decision in brief

| Piece | Where it runs | Mechanism |
| --- | --- | --- |
| Discovery and validation | `register_with_config ! {Env, FS}`, once per runtime process | `std/fs` and `std/yaml` on the skill root; the result goes into `config` |
| The index | Every model request | `DescribeTools`, one `Skill` schema rendered from `config` |
| Loading a skill | When the model calls `Skill` | `ToolProvider(["Skill"], handler)`; the handler reads through `ctx.ports.file_read` and validates what it read |
| Refusing a broken skill | Runtime start, when this extension's registration is normalised | `normalize_registration` in the host |

No `PromptShaper`, so the system prompt and its digest are untouched. No new `Capability`
variant, no ABI type change and no ABI version change. One core change, the rejection variant of
D2, and one amendment to the ABI ADR's text.

The atoms are `packages/motoko-ext-abi/types.ail:1943` (`DescribeTools`) and `:1948`
(`ToolProvider`). The precedents are `packages/motoko-ext-mcp/register.ail:27` (one extension,
many discovered things, carried in `config`) and `packages/motoko-ext-herdr/register.ail:230`
(a directory scanned at registration).

## 1. Decisions

### D1. A broken skill or a broken root refuses startup — ruled 2026-10-03; v0.2 rules accepted (ruling 4)

**The conditions are stated as `std/fs` reports them under `AILANG_FS_SANDBOX` set to the
workdir**, which is how the TUI runs the runtime (`src/tui/src/runtime-process.ts:475`). Without
the sandbox a symlinked skill is followed and accepted, so an unsandboxed launch and a session
can disagree about the same tree (research §9 M1).

The root (located by D7):

- **R1.** The directory that should hold the root has an entry named `skills` that is not a
  directory. That is a file of that name, a symlink leaving the workdir, or any absolute-target
  symlink. v0.1 read all three as "no root" and started with no skills.
- A root that is simply absent is not a refusal: there are no skills.

An entry directly under the root:

- **V1.** It is a directory with no `SKILL.md` (exact case).
- **V2.** It is neither a regular file nor a directory.
- **V3.** Its `SKILL.md` cannot be read.
- **V4.** Its `SKILL.md` has no frontmatter block, the block is not terminated, the block does
  not decode as YAML, or it decodes to something other than a mapping (D9).
- **V5.** `name` is missing, is not a string, breaks the naming rule (1–64 chars of `a-z`, `0-9`
  and hyphens; no leading, trailing or doubled hyphen), or differs from the directory name.
- **V6.** `description` is missing, is not a string, is empty after trimming, or is over 1024
  chars after decoding.
- **V7.** Its `SKILL.md` is too large to deliver whole. Tool message content is cut at 65,536
  chars, mid-JSON, with a truncation note appended (`src/core/phase_vocab.ail:1559`). The
  extension measures the JSON-encoded length of what it would return and refuses above a limit
  just under the cap. The PLAN fixes the number, about 60,000. The largest skill in the
  repository today is 23,258 bytes.

The set as a whole:

- **V8.** The index is over budget (D4).

Not refused: regular files in the root; frontmatter keys other than `name` and `description`; a
body over the specification's recommended size (`dagr-producer` is already over it).

The refusal does not depend on `extensions.strict`. It reports every violation it found in one
message, each with its path and rule.

**What the guarantee does not cover.**

- A directory that `std/fs` cannot list. `listDir` has no `Result` form and ends the process
  when it fails (research §9 M1). That happens when a root or entry is removed mid-scan, and
  also, with no race at all, when a directory exists but may not be listed. In both cases the
  runtime ends with an AILANG error instead of the structured refusal. A `Result` form of
  `listDir` is a request for AILANG upstream.
- `.motoko` itself being a symlink out of the workdir. The runtime's own profile configuration
  lives there, so that tree is broken before skills are reached.

**CI.** `verify_extensions` boots each extension of the default profile through the same
registration path (`scripts/verify_extension_boot.ail:60`), but it runs without the sandbox and
prints only output lines matching `Error|UNKNOWN` (`Makefile:2839`), which hides the lower-case
JSONL `error` event. Two changes to that recipe are part of this decision: it sets
`AILANG_FS_SANDBOX` to the repository root, and it prints the rejection. All nine extensions of
the default profile boot under the sandbox today (`evidence/m6_boot_sandbox_probe.sh`). Whether
CI then enforces D1 depends on D11.

Accepted consequences (research §6.3): a broken skill arriving by `git pull` blocks every session
in the workdir, including the resume of one in flight, because each respawn re-registers.

"Duplicate" in the operator's ruling has no case under D7: with one root, V5 ties each name to
its directory.

### D2. The host refuses; the extension reports — ruled 2026-10-03; ABI route revised in v0.3 and ruled again (§6)

`ExtRegistration` is `{ config, caps }` with no error channel and gains no field within 8.x
(`types.ail:2000`, `:27`). The refusal therefore travels in `config`.

- The extension sets a reserved key, `registration_refusal`, to a non-empty string listing every
  violation. It still returns its normal literal `caps`. The key is unused in the tree today.
- **Semantics.** Key absent, or an empty string: no refusal. A non-empty string: refuse, with
  that string as the message. Present with any other JSON type: refuse, as a malformed refusal.
- **Order.** `normalize_registration` (`src/core/ext/registry_normalize.ail:330`) checks it
  before the multiplicity walk and returns a sixth `RegistrationRejection`,
  `RegistrationRefused(id, message)`. `rejection_rule`, `rejection_extension` and
  `rejection_message` (`:154`, `:164`, `:174`) each gain an arm.
- Placing the check there covers every path to the boundary. The code graph finds three callers:
  `parse_tokens`, `normalize_registry` in the same module, and the registration-boundary DST
  script. Two modules import `registry_normalize` at all: the generated registry and that
  script (§7).
- `parse_tokens` is unchanged. It already prints `rejection_message(e)` as a JSONL `error` event
  and exits 2 (`src/core/ext/registry_generated.ail:107`), so the generated registry is not
  regenerated for this.
- The host knows nothing about skills: it reads one string.

**The ABI: an amendment, and no version change.** The ABI is frozen at 8.0, and a change to it
is a numbered amendment that cites an artifact (031 ADR-001, lines 6–7 and its acceptance rule
(ii), line 1094). Reserving a key constrains what an extension may put in `config`, so this is
Amendment 5. Its artifact is a fixture: a registration carrying the key, accepted by the host as
it stands today.

v0.2 made it an 8.1 minor that exported the key and its reader from the ABI package, so that the
string had one owner. The second review priced that. The version in the ABI's manifest is
re-derived and compared by `check_abi_version`
(`tools/profile_definition/check_fixtures.py:906`); twenty package manifests and the DST
manifests pin `8.0`; and journal admission compares a recorded ABI version with the lock's
(`src/eval/journal/admission.ail:517`), so corpora recorded at 8.0 would stop being admitted.
That is a repository-wide sweep to share one string.

So the amendment changes no code in the ABI package:

- The key's name and semantics are stated in the comment beside `ExtRegistration`.
- The reader lives in `registry_normalize.ail`, where `new_contract_policy` applies; that check
  covers `src/core` only (`tools/verify_classify/new_contract_policy.py:64`).
- The extension writes the same literal. One row in `scripts/dst/registry_multiplicity_dst.ail`,
  which can import both sides, asserts that the two strings are equal.

**What a dependency does not give.** v0.2 said that depending on the newer ABI keeps the
extension off a host without the check. It does not: the check is in core, and a package version
says nothing about core. Two things replace that claim.

- The host check and the extension land in one change in this tree.
- **The extension fails safe where the key is ignored.** When it has recorded a refusal, its
  catalogue lists no skills and every `Skill` call returns the refusal as a tool error. A host
  without the check starts, and serves no skill.

Rejected: the extension printing the event and calling `exit(2)` itself. It would be the first
registration in the tree to end the process, and it would put the refusal and its message format
outside the one host-owned boundary.

### D3. The format is the standard `SKILL.md`; what Motoko checks is narrower — ruled 2026-10-03

The [Agent Skills specification][spec] as fetched 2026-10-03: a directory with a `SKILL.md`,
YAML frontmatter with required `name` and `description`, a Markdown body, and optional bundled
files referenced by paths relative to the skill directory. Motoko reads `name` and `description`
and ignores every other key.

v0.1 called this "unmodified" and v0.2 counted two differences from the specification's
reference validator. Neither is exact. What Motoko checks:

- **The two required fields**, by V5 and V6, with one narrowing: names are ASCII. The validator
  accepts any Unicode alphanumeric after NFKC normalisation. Motoko accepts `a-z`, `0-9` and
  hyphens only, because the name is also a directory name, an `enum` value in the tool schema,
  and part of the path the world's file table is keyed on. (Accepted, ruling 7.)
- **No optional field.** The validator checks `compatibility`'s type and length and rejects keys
  outside its six. Motoko ignores every key but the two it reads, so that a skill written for
  another agent, with that agent's extra keys, loads.
- **That the block decodes** with `std/yaml` (D9). That decoder rejects YAML which JSON cannot
  represent, such as a non-string mapping key, anywhere in the block, including in fields Motoko
  then ignores.

So a skill can pass the reference validator and refuse here, and pass here and fail the
validator.

### D4. The index lives in the `Skill` tool's description — ruled 2026-10-03; v0.2 budget accepted (ruling 5)

- One tool, `Skill`, with one required parameter, `name`, whose `enum` is the discovered names.
  The name is free in the tree.
- The description is a fixed instruction followed by one line per skill, `- <name>:
  <description>`, in name order. `listDir` returns names sorted, so the order is deterministic.
  A description's whitespace is collapsed to single spaces first, because a folded or literal
  YAML scalar decodes with newlines in it.
- **Budget (V8).** The index lines together may not exceed a total, proposed at 16,000 chars
  (about 4,000 tokens). Above it, startup refuses. V6 bounds one description; nothing in v0.1
  bounded the set, and the index is sent with every request and cannot be compacted away. Five
  skills today come to about 2,200 chars of descriptions.
- **Providers.** A description of 16,000 chars is accepted by Anthropic, Google, DeepSeek and
  Meta models through OpenRouter (`evidence/m8_description_limit_probe.py`). OpenAI could not
  be tested: this account's OpenAI key is rejected at any length. OpenAI is reported to cap a
  function description at 1,024 chars. If that holds, this decision does not work on OpenAI
  models for more than two or three skills, and it returns to the operator. The plan's first
  step settles it.
- Adding, removing or rewording a skill changes neither `system_prefix_digest` nor
  `ext_set_digest` (`src/core/ext/runtime.ail:1327` hashes ids and capability kinds only), so it
  never refuses a resume (`src/core/journal.ail:629`, `:631`). Enabling the extension in a
  profile does change `ext_set_digest`, as enabling any extension does.
- **The config digest.** The index is in `config`. 031 ADR-001 D2 (lines 404–420) gives every
  extension a config digest covering `config` and the constructors' data positions, recorded per
  policy epoch; a change on resume appends a snapshot and continues, and strict whole-run replay
  compares it. So under the accepted design a change to the index is recorded and visible to
  replay, without refusing resume. At HEAD that recording is not built: `ext_config_digest`
  (`src/core/ext/registry_normalize.ail:543`) has no caller outside its module. Until it is, no
  digest notices a changed index.
- **The digest covers the index only.** `config` holds names, descriptions and paths. An edit to
  a skill's body changes none of them, so it moves no digest, now or when the recording is
  built.

Evidence: placement made no measurable difference to triggering, 139/150 for each, with no false
positive in 150 control tasks (research §9 M2, a proxy outside the harness). A hit there is a
matching `Skill` call anywhere in the first response, not necessarily the first call. With
triggering equal, the resume behaviour decides.

### D5. No harness-forced loading in v1 — ruled 2026-10-03

A `ToolPolicy` gate cannot act on a model that answers without calling a tool, and that was 12
of the weakest model's 16 misses in M2. Across all three models, 9 of 22 misses were another
tool called first, which a gate could catch; that is the case for revisiting this after v1.

### D6. No `/skill-name` command in v1 — ruled 2026-10-03

### D7. One skill root, the relative path `.motoko/skills` — ruled 2026-10-03; location revised in v0.3 and ruled again (§6)

The recommendation was to read `.claude/skills` as well; the operator chose one root. A root
outside the workdir cannot be read under the sandbox (research §9 M1).

**The root is written as the bare relative path `.motoko/skills`, everywhere:** for discovery,
for the handler's read, as the key in a deterministic world's file table (D13), and in the
directory line the model is shown (D10). One spelling.

That is right because of how the sandbox resolves paths. `evidence/m7_fs_cwd_probe.sh` runs
`std/fs` with the process's directory and the sandbox root deliberately different:

| Path given to `std/fs` | Result |
| --- | --- |
| A bare relative path | Resolved against the sandbox root, not the process's directory. |
| An absolute path into the sandbox | Accepted. |
| A path relative to the process's directory | Not found. |

The TUI sets the sandbox root to the workdir (`src/tui/src/runtime-process.ts:475`), so in a
session `.motoko/skills` is the workdir's, wherever the TUI was started. It is also why the five
extensions that read `MOTOKO_WORKDIR` with `.` as its default work in sessions that leave it
unset (§7).

**How two versions got this wrong.** v0.1 used the bare path, and was right. The first review
argued that registration cannot see the workdir, so the path would resolve against the
process's directory. That is true without the sandbox and false with it. v0.2 accepted the
argument unmeasured and derived the root from `MOTOKO_WORKDIR`, then `MOTOKO_JOURNAL_WORKDIR`.
In an ordinary session that gives an absolute root, and the directory line built from it was a
path the model's own file tools refuse: they reject an absolute path when the workdir is `.`
(`validate_path_common`, `src/core/tool_runtime.ail:443`, `:452`). Both second reviews found
that. Neither rule had been run; the probe was the first measurement of either.

**Without the sandbox** a relative path resolves against the process's directory. A launch that
is not sandboxed and passes a `--workdir` other than its own directory indexes the wrong tree,
and nothing at registration can see the workdir to correct it. Registration records in `config`
whether the sandbox variable was set. When it was not, and `ctx.workdir` is not `.`, the handler
returns a tool error saying so instead of loading.

### D8. Compaction: a standing instruction, a size check, and a measurement — ruled 2026-10-03 (ruling 1)

A first ruling on 2026-10-03 chose a reload marker, a `[skill <name> loaded]` line meant to
survive elision. It cannot: the harness encodes the whole result envelope as JSON, and the skill
text starts 58 chars plus the tool-call id into it (`src/core/tool_contract.ail:60`,
`src/core/phase_vocab.ail:1629`). With the 37-char ids seen in recent sessions, an elided skill
result reads

    {"tool_call_id":"call_0123456789abcdef0123456789abcdef","tool":"Skill","exit_cod...[elided 12836 chars]

with or without a marker (research §9 M3, cases H and I). What survives is the assistant
message that made the call, `Skill({"name":"observer"})`, since structural elision rewrites only
`tool` messages. A second ruling the same day therefore chose a standing instruction in the
tool description: if a `Skill` result shows as elided, call `Skill` again.

Both reviews showed that instruction can loop. The structural compactor cuts any tool result
that is 30% or more of the context limit, wherever it sits, once usage reaches 70%
(`cap_oversized_tool_results`,
`packages/motoko-ext-compaction-structural/compaction_structural.ail:85`), and appends advice not
to re-read it in full. A skill that large is cut straight after a reload, and the model is told
to load it again. The repetition guard does not stop that, because it counts byte-identical
call-and-result pairs (`packages/motoko-ext-repetition-guard/repetition_guard.ail:224`) and
every envelope carries a new call id. The research measured the cap (M3, case G); v0.1 left it
out.

Decided for v1:

- **No marker.**
- **A size check at call time.** When `ctx.context_limit` is known, the handler estimates the
  tokens of the message the harness will build from its result, which is the JSON-encoded
  envelope and is what the compactor measures, with the compactor's own arithmetic (chars over
  four). It returns a tool error instead of the text if that is 25% of the limit or more. The error says
  the skill does not fit this model's context. With the limit unknown (0)
  the skill loads.

  The check compares against the declared window, which is what the handler is given
  (`raw_window_of`, `src/core/session.ail:3601`, `:3645`). The structural compactor caps a
  tool result at 30% of a smaller working limit — the declared window less 65,536 tokens
  of output allowance and less the system prefix, floored at 0 (`working_budget_for_ext`,
  `src/core/context_limit.ail:91`). So a skill the handler returns can still be capped:
  the 25% threshold sits under the compactor's 30% only when the two limits are close.
  Shown in P1 (`NOTE-p1-prototype-results.md` §6.1, recorder session `dry/cap-80000`,
  archived in `evidence/p1/captures/`): at a declared 80,000 (working limit 12,528)
  `dagr-producer` loaded at 7.6% of the declared window and was capped in the next
  request at 48% of the working limit, with a reload capped again as the newest tool
  result. By the arithmetic of the two rules, the affected declared windows are about
  67,500 to 87,700 for a skill that size, and up to about 117,500 for a skill at V7's
  60,000-char limit. (Operator ruling 2026-10-04: keep the declared-window check; the
  alternative — handing the handler the working limit — is a core change that would
  switch the check off at declared windows of about 67,500 or less, where P1.3d showed
  it working.)
- **The standing instruction**, as before.
- **A deterministic check** (A6b) that a skill within both size bounds, loaded as the newest
  tool result, is whole in the next request at any usage. Each side is tested with the
  limit it is actually given — the handler with the declared window, the compactor with
  the working limit — so the split above is documented, not hidden. That holds for the structural
  compactor only where the two limits are close (see the size check). `compaction_ai` can fold even the newest message when it alone exceeds the tail
  budget (`keep_recent_tokens`; `compaction_ai.ail:264`, `:273`). At the default, and at the
  20,000 that three profiles set, a skill within V7 is safe; under a smaller budget it is not.
  A6b tests that split as well.
- **A measurement** (A5) of what the instruction costs. Above 70% usage, tier 1 keeps the newest
  ten tool results, so a skill in use is reloaded about every ten tool calls, each time at its
  full size. A5 counts reloads per run and the tokens they spend, under both compactors.
  `compaction_ai`, which the default profile runs at 75%, replaces older turns with a
  model-written summary, so the call record goes with them.
- If reloading is too costly or does not happen, pinning becomes a follow-up decision.

Considered and not adopted for v1:

- Exempting `Skill` results inside the compactors. `compaction_ai` carries a 1,200-char excerpt
  of one tool's latest result through its summary by name (`compaction_ai.ail:284`, `:332`). That
  is a precedent for naming a tool in a compactor, not for carrying a whole result, and it
  couples two other extensions to this one.
- Putting the skill name in the envelope's `tool` field so it lands in the preview. Other
  consumers read that field and were not surveyed.

### D9. The frontmatter is decoded by `std/yaml` — ruled 2026-10-03 (ruling 3)

v0.1 specified a hand-written parser for a subset of YAML, on the premise that AILANG has no
YAML module. The premise was false. `std/yaml` is in the installed standard library with
`decode(s: string) -> Result[Json, string]`, backed by Go's `yaml.v3`. The research had searched
the documentation server and concluded absence from one empty result.

- The frontmatter block is the text between a first line `---` and the next line `---`. One
  leading byte-order mark is ignored, and a delimiter line may end in a carriage return.
- The block is decoded by `std/yaml.decode`. A decode error is V4. The result must be a mapping
  whose `name` and `description` are strings (V5, V6).
- Everything else is YAML's, within what JSON can represent (D3): comments, quoting, block
  scalars and their chomping, continuation lines, anchors, tags. Limits are measured on the
  decoded value.
- A name made only of digits, such as `123`, fits V5's pattern but decodes as a number and
  refuses. It has to be quoted.

Run on the installed toolchain (`evidence/m5_yaml_probe.sh`): all five skills in
`.claude/skills` decode; a trailing ` # comment` is a comment; quoted, folded, literal and
continued scalars decode as YAML defines; a duplicate key, a tab indent and `key: a: b` in a
plain scalar are decode errors; `name: 123` and `name: true` decode but are not strings; CRLF and
a byte-order mark are accepted.

Not established: what the inventories make of `import std/yaml (decode)` in an extension's
closure. There is no precedent to read it from: no module under `src/core`, `scripts` or
`packages` imports `std/yaml` (§7). The PLAN checks that before building on it. If it cannot be made to pass, the fallback
is v0.1's subset parser, and this decision returns to the operator.

### D10. The index is fixed at registration; the text is validated on every call — ruled 2026-10-03 (ruling 4)

- `Skill` accepts only names in the index. Any other name is a tool error that lists the valid
  names. A model that calls a tool named after a skill gets the dispatcher's existing
  unknown-tool error (`src/core/tool_runtime.ail:248`).
- The file is read when the tool is called. A new skill appears at the next respawn.
- **The handler validates what it read**, with the same per-file rules as startup (V4–V7), then
  applies D8's size check. Any failure is a tool error naming the rule, and nothing is
  delivered. v0.1 specified an error only for a missing file, so a skill edited into a broken
  or oversized state after startup would have loaded, cut short.
- The index entry stays what registration captured. An edit to the text is delivered on the
  next call; an edit to the description shows at the next respawn; an edit that changes `name`
  fails V5 and is a tool error.
- The result is one line giving the skill's directory, `.motoko/skills/<name>`, then the whole
  `SKILL.md`. That path is relative to the workdir, which is the form the native file tools
  accept (D7), so the model can read the bundled files the text refers to.
- A file that has gone since startup is a tool error.
- **A file that is there but cannot be read ends the runtime.** v0.1 called this a tool error.
  The live read adapter checks `isFile` and then calls the panicking `readFile`
  (`ambient_file`, `src/core/ports.ail:1393`), and `ExtFileRead` has no error field
  (`types.ail:239`), so the port cannot report a failed read. v1 accepts that, states it, and
  raises the adapter as an issue for the port's owner, since every `file_read` caller has it.
  The alternative was a second core change in this project; the operator accepted the
  narrower promise (ruling 8).

This narrows research §4.3, which proposed loading names not yet in the index. An `enum`
parameter and unlisted names contradict each other, and agent-authored skills are out of v1.

### D11. Not in the default profile in v1; no per-profile selection — ruled 2026-10-03 (ruling 9)

A profile opts in by naming `skills` in `extensions.order`, and then sees every skill in the
root. There is no allow or deny list.

v0.1 left open whether the default profile is one of them, while relying on it in D2. Decided
here: **not in v1.** The extension is enabled in a named profile for the measurement, and
default membership is ruled after A5. Three things follow from that and are accepted:

- CI's `verify_extensions` boots only the default profile, so CI does not enforce D1 until the
  extension joins it. D1's recipe changes still land, so that enforcement is correct on the day
  it does.
- Joining a profile later changes its `ext_set_digest`, which refuses the resume of every
  session in flight on that profile once (`src/core/journal.ail:629`).
- A profile with the extension and no skills pays for a `Skill` tool that does nothing (D12).

The five skills in `.claude/skills` are not moved by this project. They are Claude Code skills,
written against Claude Code's tool names, and which of them Motoko should have is chosen per
skill later. They are not symlinked wholesale either: `observer` is written to supervise a
Motoko run from outside it and does not belong inside one. The measurement in A5 uses fixture
copies in a test workdir.

### D12. With no skills, the tool is still registered — ruled 2026-10-03

Returning no capability fails `verify_extensions`, and returning no schema does not hide the
tool, because the catalogue then synthesises one from the provider's name
(`src/core/tool_catalog.ail:132`). So the extension always registers `Skill`; with nothing
installed its description says so and `name` has no `enum`.

A further reason, from review: if the capability list depended on whether any skill exists,
going between zero and one skill would change the capability kinds, and so `ext_set_digest`,
and refuse resume.

### D13. DST: outside every profile in v1, built so a later profile can cover it — ruled 2026-10-03 (ruling 10)

A DST profile is the versioned statement of what is in the system under test: which extensions
are installed, how each of their hooks is covered, and which extensions are omitted and why
(009 ADR-001 D5; `ProfileDefinition`, `src/core/dst_profile.ail:569`). It is not a configuration
profile under `.motoko/config/`, which is what D11 means by "profile".

**Loading is inside the world.** The handler performs one effect, a read through
`ctx.ports.file_read`, which bridges to the core seam (`src/core/session.ail:1404`). In a live
run that reads the disk. In a deterministic run it is served from the world's own file table,
and a path the table does not carry is absent (`scripted_file`, `src/core/ports.ail:1335`). The
handler calls no `std/fs` function and returns the world the port handed back. Two extensions
already read through this port, `herdr` and `compose` (§7), so the handler follows an existing
shape.

**Discovery is outside it.** Registration runs before any world exists and has no ports, so it
reads the real disk. DST does not mediate that; it is disclosed, through `config` and through
the inventories' registration-only listing. `compose` and `herdr` stand the same way.

**Position in v1.** The extension is installed in no conformant profile. It is named, with its
measured reason, in the omitted list of all four: `driver_only`
(`src/core/dst_driver_only.ail:957`), `driver_plus_no_ops` (`dst_driver_plus_no_ops.ail:635`),
`driver_plus_compose` (`dst_driver_plus_compose.ail:686`) and `driver_plus_herdr`
(`dst_driver_plus_herdr.ail:303`). Changing a profile's omitted list is a change to a semantic
scope field, so each profile's version changes with it (009 ADR-001, line 1287).

The lists are not clean today, and the PLAN deals with that first, separately. `ailang.toml`
registers 19 extensions, the count tests pin 14, 17 and 17, and `ailang_tools` is in none of the
four files. `driver_plus_herdr` and its graded run are in `DST_KNOWN_RED` (`Makefile:697`).

| Atom | Dispatch | Purity basis | What covering it would take |
| --- | --- | --- | --- |
| `DescribeTools` | Unconditional (`src/core/dst_profile_coverage.ail:220`) | Declared empty row (`:287`) | Nothing more: it renders from `config`. |
| `ToolProvider` | Gated (`:225`): a call may never name it, so a profile may exclude it | Effect row (`:292`) | A recorded, validated, strictly replayed run. The classifier cannot clear it, because its verdict is closure-wide and a registration read taints every hook (`src/core/dst_driver_plus_herdr.ail:25`). |

`ToolProvider` is not the only kind a profile may exclude, as v0.1 said: a `Lifecycle` atom's
exclusion is also admitted, unchecked (`dst_profile_coverage.ail:211`).

A `driver_plus_skills` profile with its own graded run is the later step. `driver_plus_herdr` is
the design precedent, the first profile to cover a tool dispatch, with the caveat above that its
run is red at HEAD.

**What the design accepts.**

- **One fact in two homes.** In a deterministic scenario the index comes from files on disk and
  the text from the world's table. A scenario seeds the skill in both. The table is keyed on the
  path string (`src/core/ports.ail:346`), which is why there is one spelling of the path (D7).
- **What records the index.** See D4: the config digest of 031 D2 is the designed record, and
  it is not built at HEAD.
- **A file read is not a recorded interaction.** The identity classes carry file writes,
  removes and directory creation, and no read (`src/core/dst_interaction.ail:59`). A replay
  reproduces a read because the program's initial world carries the seeded file table
  (`src/core/dst_replay.ail:863`). Whether a recorded live session carries the text its skill
  reads returned was not established, and is the first question a `driver_plus_skills` profile
  has to answer.
- **Faults.** DST can exercise a skill that has gone (absent from the table). It cannot inject a
  failed read: the catalogue's one extension class delivers through `ai_step` and lists every
  other port as a coverage gap (`src/core/dst_fault_catalogue.ail:420`).

**The refusal is the DST-friendly part.** `normalize_registration` is pure, so D2's variant gets
inline tests and a row in the registration-boundary script,
`scripts/dst/registry_multiplicity_dst.ail`. That script runs under `make dst`, not in CI.

## 2. Acceptance

- **A1. One tool, one index.** With N > 0 valid skills, the catalogue holds exactly one `Skill`
  schema whose description names all N in name order, one line each, and whose `enum` is their
  names. With none, it holds one `Skill` schema that says so and has no `enum`.
- **A2. Digests.** Adding or removing a valid skill, or rewording its description, leaves
  `system_prefix_digest` and `ext_set_digest` unchanged, moves `ext_config_digest`, and a session
  started before the change resumes after it. Rewording only a skill's body moves none of the
  three. An invalid change refuses startup whatever the digests say.
- **A3. Every rule refuses.** Run with the sandbox set. For R1 and each of V1–V8, a fixture
  workdir violating only that rule makes the runtime exit 2 with one JSONL `error` event naming
  the path and the rule. V4 has a fixture for each of its four cases, and R1 for each of its
  three. A fixture with two violations names both. Controls that must start: no root at all; a
  set of valid skills including one in each scalar style D9 lists and one with a malformed
  optional field.
- **A4. The rejection is the host's, and the extension is safe without it.** As pure tests of
  `normalize_registration`: a non-empty string refuses; a non-string value refuses; an absent
  key, an empty string and an ordinary registration are accepted. `registry_multiplicity` has a
  row for the new variant and a row asserting the extension and the host use the same key. With
  a refusal recorded, the extension's catalogue lists no skill and its handler returns the
  refusal. No `register_with_config` calls `exit`.
- **A5. Measured in the harness**, with fixture skills in a test workdir, one of which instructs
  an action that can be checked afterwards:
  - the M2 task set through the real runtime: how often `Skill` is the first call, how often it
    is called at all in the first response, and whether the checkable action was done;
  - a run driven past 70% usage under the structural compactor: reloads per run and the tokens
    they cost;
  - the same under `compaction_ai` at its 75% threshold;
  - a model whose context is small enough that D8's size check must answer with its error;
  - one request with an index at budget size to each provider family the profiles use,
    OpenAI included.

  These are reported, not gated. The implementation is not accepted until the operator has
  recorded a disposition of the results.
- **A6. The load is mediated.** The handler reads through `ctx.ports.file_read` and calls no
  `std/fs` function; `ext_call_inventory` records the call and stays green. Inline tests drive
  the handler with a stub port for a present file, an absent file, and a port that changes the
  world, to show the changed world is what the handler returns.
- **A6b. A loaded skill arrives whole.** As pure tests: a skill within V7 and D8's bounds, as
  the newest tool result, is unchanged by `compact_for_pre_step` at 72% and at 96% usage, and is
  kept in the recent part by `compaction_ai`'s split at the default and at a tail budget of
  20,000 tokens.
- **A7. The gates, named.** A baseline of which of these are red is recorded before any
  production change; a pin that moves is checked, not just re-pinned; and a gate that is red in
  the baseline must show no new failure.
  - In CI (`.github/workflows/verify-extensions.yml:99`, `:164`): `check_core`,
    `profile_definition`, `driver_only`, `profile_coverage`, `conformance`, `ext_call_inventory`,
    `ext_call_inventory_selftest`, `test_coverage`, and `new_contract_policy` for D2's reader.
  - Outside CI: `registry_gen_check`, `registry_multiplicity`, `ext_hook_scope`,
    `ext_ambient_inventory`, `declared_vs_performed`, `driver_plus_no_ops`,
    `driver_plus_compose`, and `driver_plus_herdr`, which is in `DST_KNOWN_RED` today
    (`Makefile:597`, `:697`).
- **A8. The DST position is stated.** `skills` is named in all four omitted lists of D13 with
  its measured reason, and each profile's version is changed.
- **A9. Call-time behaviour.** A name not in the index is an error listing the names. An edit
  to an indexed skill's text is in the next result. An edit that breaks a V-rule, or grows the
  file past V7, is a tool error naming the rule. The result begins with the directory line, and
  `ReadFile` on a bundled file under that directory succeeds.
- **A10. A workdir that is not the process's directory.** With the TUI started elsewhere and
  pointed at a fixture workdir, the skills indexed and loaded are that workdir's.

## 3. Out of scope

- Harness-forced loading, `/skill-name`, a second root, per-profile selection, default-profile
  membership.
- Honouring `allowed-tools`, or translating Claude Code tool names in a skill's text.
- Running a skill as a sub-agent.
- A capability that pushes context into the conversation; that is a new `Capability` variant
  and waits for ABI 9.0 (`types.ail:29`).
- Pinning a skill through compaction (D8's follow-up).
- A `driver_plus_skills` DST profile (D13's later step).
- An error channel on the file-read port (D10).
- Agent-authored skills, user-global or remote sources, versioning.

## 4. What a plan would sequence

The order puts the cheapest test of the idea first. Nothing in steps 2 to 6 is worth doing if
models do not load, follow and reload skills delivered this way.

0. **Baseline.** Before any production change, record which of A7's gates are red. Read-only.
1. **A throwaway prototype, and A5.** In a git worktree, because wiring it means editing the
   root manifest, the lock and the generated registry, which other live sessions share. The
   extension with discovery, the catalogue and the handler, no refusal path, valid fixtures
   only, not merged. It answers A5 and A10, and three questions that can send a decision back
   to the operator: whether the inventories accept `std/yaml` (D9), whether OpenAI accepts the
   index (D4), and whether the bare relative root behaves in a real session as it does in the
   probe (D7). If the results are poor the project stops here, before any core or ABI change.
2. **Amendment 5 and the host rejection.** The reader and `RegistrationRefused` in
   `registry_normalize.ail`, their tests, the ABI comment, and the amendment's artifact.
3. **The package, pure parts.** Frontmatter extraction, the rules R1 and V1–V8, the size
   estimate, with inline tests.
4. **The package, wiring.** `register.ail` with discovery, the catalogue and the handler. The
   research's M4 survey lists the shapes the inventories reject; re-ground it first, since only
   part of it was verified.
5. **Registry wiring and the CI recipe.** Root `ailang.toml`, lock, `make registry_gen`; the two
   changes to `verify_extensions` (D1).
6. **Repair, then re-pin.** Settle `ailang_tools`'s place in the profile lists as its own
   change, then add `skills`, change the profile versions and move the pins.

## 5. What earlier text got wrong

From the research, corrected in v0.1:

- **D8's marker.** The research reported that a first-line marker survives elision. Its probe
  put the text in the tool message directly; the harness wraps it in a JSON envelope.
- **Loading unlisted names** (research §4.3) contradicts an `enum` parameter.
- **"Journaled and replayable"** (research §2) overstated: the load is world-mediated, but a
  file read is not a recorded interaction.

From v0.1, found by REVIEW-001 and corrected here:

- **No YAML module.** There is one (D9). Found by the Codex review.
- **`.motoko/skills` "relative to the workdir".** Registration cannot see the workdir (D7).
  Found by the Fable review.
- **An unreadable file is a tool error.** It ends the runtime (D10). Both reviews.
- **A missing root is the only root case.** A root that is a symlink out reads as missing, and
  started with no skills (D1 R1). Both reviews.
- **The reload instruction is enough.** It loops on a skill the compactor always cuts (D8). Both
  reviews; the research had measured the cut and v0.1 dropped it.
- **`ReadFile` delivers raw text, so a core tool would avoid JSON escaping.** Native tool results
  are JSON-encoded too (`tool_result_item_to_json` and `dispatch_one_typed`,
  `src/core/tool_dispatch_adapter.ail:95`, `:204`). A skill arrives the way every file a model
  reads in Motoko arrives. The suggestion that `Skill` might have to become a core tool is
  withdrawn, and with it v0.1's reason for its plan order. Found by the Codex review.
- **"The index is not recorded", as a property of the design.** It is a gap in the code against
  031 D2 (D4). Both reviews.
- **The reserved key is "an 8.x convention".** The ABI is frozen and it is an amendment (D2).
  Both reviews.
- **"Truncated without saying so"** (V7). The cap appends a note; it also cuts mid-JSON.
- **"Before any registry entry exists"** (§0). Earlier extensions' entries are already accepted
  when a later one is refused; the process then exits.
- **`ToolProvider` is "the one kind a profile may exclude"**, three omitted lists, and
  `driver_plus_herdr` as a clean precedent (D13).

From v0.2, found by REVIEW-002 and corrected here:

- **The root derived from environment variables.** It fixed a problem the sandbox does not
  have, and it made the directory shown to the model a path the model's file tools refuse (D7,
  D10). Both reviews found the second half; the probe run in response found the first.
- **"Depending on ABI 8.1 keeps the extension off a host without the check."** A package version
  says nothing about core (D2). Both reviews.
- **"Two functions" as the cost of the minor.** It is a pin sweep and a corpus question (D2).
  Found by the Fable review.
- **"A skill change is recorded."** Only an index change is; a body edit moves no digest (D4).
  Both reviews.
- **"Two stated differences" from the reference validator.** Optional fields are not validated
  at all, and the decoder rejects what JSON cannot represent (D3). Found by the Codex review.
- **The budget, unchecked against providers** (D4). Found by the Fable review.
- **"Whole at any usage"**, shown for one compactor and measured on the wrong string (D8).
  Found by the Fable review.
- **Listing failures as races only** (D1). Found by the Codex review.
- **The baseline at step 6**, after the changes it was meant to precede, and `driver_plus_herdr`
  missing from the gates (§4, A7). Found by the Codex review.

One finding of REVIEW-001 did not hold. Its premise, that the live read adapter resolves a
relative path against the process's directory, is false under the sandbox (D7).

## Related records

- `RESEARCH-skills-system.md` and `evidence/` (this folder)
- `REVIEW-001-claude-fable-5.1.md`, `REVIEW-001-codex-gpt-6-astra.md`,
  `REVIEW-002-claude-fable-5.1.md`, `REVIEW-002-codex-gpt-6-astra.md` (this folder)
- `../031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md` (ABI 8.0, the
  8.x stability rule, its acceptance rule, D2's config digest; D2 here needs its Amendment 5)
- `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` (D5: conformant
  profiles and the coverage criteria D13 is stated against)
- `../017_extension_handling/ADR-001-extension-abi-evolution.md` (the registration boundary)
- `../033_release/ADR-001-release-scope.md` (ABI stability after the release)
- `../006_compactor_strategy/ADR-001-compaction-persistence.md` (the open question of whether
  compaction is send-only or written back to the history)

## 6. Rulings

**On v0.2, all accepted by the operator on 2026-10-03.** D3, D5, D6, D7's single root and D12
were not reopened.

| # | Ruling |
| --- | --- |
| 1 | D8: a size check at 25% of the context limit, on top of the standing instruction. |
| 2 | D7: the root is located from `MOTOKO_WORKDIR`, then `MOTOKO_JOURNAL_WORKDIR`, then `.`, subject to the prototype confirming it. |
| 3 | D9: frontmatter is decoded with `std/yaml`, with the subset parser as the fallback if the inventories reject the import. |
| 4 | D1 and D10: the root rule R1, the sandbox as the stated condition, validation on every call, and the two `verify_extensions` changes. |
| 5 | D4: a total index budget of 16,000 chars. |
| 6 | D2: Amendment 5 to 031 ADR-001 and an 8.1 minor adding two functions. |
| 7 | D3: names restricted to ASCII. |
| 8 | D10: an unreadable file ends the runtime in v1, and the adapter is raised as an issue. |
| 9 | D11: not in the default profile in v1; membership is ruled after A5. |
| 10 | D13 and §4: all four omitted lists with profile versions changed; prototype and measure before any core change. |

**Two of these were replaced in v0.3, and the operator ruled on both again on 2026-10-03,
accepting the replacement.** New evidence had taken away what each rested on.

| # | Was | Ruled in v0.3 | Why |
| --- | --- | --- | --- |
| 2 | The root located from `MOTOKO_WORKDIR`, then `MOTOKO_JOURNAL_WORKDIR`, then `.` | The bare relative path `.motoko/skills` (D7) | Under the sandbox a relative path already resolves against the workdir, and the derived root broke the model's access to bundled files. |
| 6 | Amendment 5 and an 8.1 minor adding two functions | Amendment 5 with no version change; the reader in core; a test tying the two strings (D2) | A version change is a repository-wide pin sweep and stops existing corpora being admitted. |

The other changes in v0.3 refine accepted rulings and do not reopen them: the fail-safe and the
host-side claim (D2), the validation boundary (D3), the digest's scope and the provider check
(D4), what the size check measures (D8), the listing limit (D1), and the plan's order (§4).

**Still open for the plan.** With no version change, the release in project 033 no longer has
to be ordered against an ABI minor. Amendment 5 still changes the frozen ABI ADR's text, and
whether it lands before or after the release tag is the operator's.

**Earlier rulings, all 2026-10-03.** D1–D7 in the research discussion (research §7). Six on v0.1:
D8 after the marker failed, V7, D9's subset parser, D10, D11 and D12, and deleting the replaced
design doc. Of those six, the D9 ruling is overtaken by ruling 3 above and the D8 ruling is
extended by ruling 1.

## 7. Grounding against the code graph

The structural claims were also checked with `tools/code-graph`, as a second method beside
reading the source. It confirmed them and found no error. The defects in v0.1 were found by the
two reviews, not by the graph.

- **What was queried.** A graph built 2026-10-03 at `09cd5a5e` on AILANG v0.47.2 over
  `src/core`, `scripts` and `packages`, in a private directory
  (`evidence/g0_code_graph_private.py`). The shared cache dates from 2026-08-08 and was not
  used, and the stock whole-repo extraction fails at HEAD on
  `src/eval/journal/candidate_checks`. The 26 checks are `evidence/g1_code_graph_grounding.py`.
- **What it confirmed.** The claims in D1, D2, D4, D8, D10, D12, D13 and §5 about what calls
  what in `src/core`: the refusal site, the envelope path, the two caps, the read adapters, the
  two sites that build the system prompt, the catalogue's fallback, the four omitted lists.
- **What it added.** Four facts, each cited where it is used: the three callers of
  `normalize_registration` and its two importing modules (D2); the five extensions that read
  `MOTOKO_WORKDIR` (D7), and `src/core/rpc.ail` as the only reader of `MOTOKO_JOURNAL_WORKDIR`;
  that nothing imports `std/yaml` (D9); that `herdr` and `compose` already read through the
  `file_read` port (D13).
- **Its limits.** Imports are exact; calls are parsed from source and are approximations. It
  has no types or effects for 92 of the 93 `packages` modules: `ailang iface` rejects a module
  whose declared path differs from its file path, and on v0.47.2 that subcommand accepts neither
  the flag nor the environment variable its own error message suggests. So no extension's effect
  row is grounded by the graph; those were read from source. It says nothing about the TUI, the
  `Makefile`, CI, or behaviour, which rest on the probes in `evidence/`.

[spec]: https://agentskills.io/specification
