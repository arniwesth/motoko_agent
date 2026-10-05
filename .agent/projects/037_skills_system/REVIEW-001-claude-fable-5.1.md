# REVIEW-001: Claude Fable 5.1 review of ADR-001 (skills system)

Date: 2026-10-03
Reviewer: Claude Fable 5.1, launched with `--model claude-fable-5-1`; the terminal banner confirmed Fable 5.1.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `adr037-fable`, pane `w7:p3`.
Reviewer session: `67ef4222-69c9-4c60-aaa5-b2cae895f0c0`.
Document reviewed: [ADR-001-skills-system.md](ADR-001-skills-system.md).
Document SHA-256: `da8e852b3d075fa6d4e9629ee1b06ccc27902ae94de0b5e39ee13081f0c9bbed`.
Status: Addressed in ADR-001 v0.2; see the disposition table at the end. The reviewed version's hash is preserved above. A second, independent review is in
`REVIEW-001-codex-gpt-6-astra.md`.

## Scope

Both reviewers received the same brief and worked separately; neither was told what the other
found. The brief asked each to verify the ADR's factual claims and every file:line coordinate
against the working tree, assess D1–D13 and the acceptance checks A1–A8, assess feasibility
against extension ABI 8.0 and the repository's gates, and say what to change before a plan is
written. It gave them the documents and not the delegating agent's conclusions, and said the
ADR's Accepted status was no reason to agree with it.

The session was read-only: no edits, commits, branch changes, make targets, tests, paid APIs or
further delegation. The one script allowed was `evidence/m1_sandbox_probe.sh`, which works in a
temp dir.

The terminal could show only the end of the reply, so the reviewer was asked to save the same
reply, unchanged, to a temp file. The response below is that file.

## Reviewer response

**sound with changes**

SHA-256 matches (`da8e852b…c9bbed`). HEAD is `da7e9e65`, not the `8e0c1426` the ADR names; the one commit between them touches only `.agent/github/prs/origin-211/body.md`, and every cited source file is unchanged since `21ba95c9`.

The shape (one extension, one `Skill` tool, index in the description, host-owned refusal) holds up against the tree. The problems are in how the skill root is located, two fail-open paths in a fail-closed design, and D8's reload instruction.

## Findings, most severe first

**1. D7, D13, table in §0: registration cannot learn the workdir. (Feasibility)**
- **Claim:** the root is "relative to the workdir, fixed", and the handler uses the one spelling `.motoko/skills/<name>/SKILL.md`.
- **Evidence:**
  - Every `register_with_config` takes `_cfg: a`, an opaque value (20 packages, e.g. `packages/motoko-ext-mcp/register.ail:27`).
  - The only workdir input at registration is `getEnvOr("MOTOKO_WORKDIR", ".")` (`packages/motoko-ext-herdr/register.ail:44`), and the TUI deliberately leaves it unset (`src/tui/src/runtime-process.ts:519-525`, asserted at `src/tui/src/harness-dst.test.ts:154`).
  - `supervisorWorkdirArg` (`runtime-process.ts:327`) passes a non-`.` workdir whenever it differs from the process cwd.
  - The live read adapter takes the path as given, relative to the process (`ambient_file`, `src/core/ports.ail:1393`).
- **Why it matters:** when the workdir is not the cwd, discovery looks in the cwd. Under the sandbox that path is outside it, `isDir` answers `false`, D1 reads that as "no root", and the session starts with zero skills and no refusal. Without the sandbox it indexes the cwd's skills for a session working elsewhere. A3 and A5 both use "a fixture workdir", so they hit this first.
- **Change:** state how registration resolves the root, put the resolved root in `config`, and have the handler build its path from that so both halves use one spelling. Add an acceptance check with `--workdir` other than `.`.

**2. D1 (V2, "not refused"), D2: the root itself fails open, and verdicts depend on the sandbox.**
- **Claim:** a root that does not exist is not refused; a broken skill committed to the repository fails CI.
- **Evidence:** I re-ran `m1_sandbox_probe.sh` and it reproduces. `isDir` is `false` for a symlink leaving the workdir and for any absolute-target symlink. V2 covers entries under the root, not the root. `verify_extensions` (`Makefile:2814-2846`) does not set `AILANG_FS_SANDBOX`.
- **Why it matters:**
  - `.motoko/skills` as an absolute-target symlink to `.claude/skills`, the obvious way to bridge D11, looks like a missing root and silently gives zero skills.
  - A symlinked skill is followed in CI and refused in the TUI, so the two disagree on the same tree.
  - When CI does fail, the path and rule are swallowed: `Makefile:2839` prints only lines matching `Error|UNKNOWN`, and the JSONL line is `"type":"error"` in lower case.
- **Change:** add a rule for the root. `listDir(".motoko")` lists symlinks by name, so "named `skills` but not a directory" is detectable. State the sandbox condition in A3, and decide whether `verify_extensions` runs sandboxed.

**3. D8: the standing instruction can loop, and A5 would not show it.**
- **Claim:** if the result is elided, call `Skill` again.
- **Evidence:** `cap_oversized_tool_results` (`packages/motoko-ext-compaction-structural/compaction_structural.ail:85-91`) cuts any tool result of 30% or more of the context limit, at any position, once usage reaches 70%. It appends "use grep or offset+limit instead of re-reading in full". Research §9 M3 recorded this; the ADR dropped it.
- **Why it matters:**
  - A reloaded skill of that size is cut before the model reads it, and the model is told to load it again.
  - The repetition guard will not stop it: it counts byte-identical call/result pairs (`worst_repeat`, `packages/motoko-ext-repetition-guard/repetition_guard.ail`), and each envelope embeds a fresh call id.
  - V7's limit of about 60,000 chars (roughly 15k tokens) admits a skill that is 30% of any context limit up to about 50k tokens.
  - Above 70% with a normal-sized skill, tier 1 keeps the newest 10 results, so the model reloads about every ten tool calls. A5 asks only whether it reloads once.
- **Smaller point:** the `compaction_ai` precedent at `:284` carries a 1,200-char excerpt (`:332-335`), not the result.
- **Change:** have the handler compare the skill's size with `ctx.context_limit` (`ProviderCtx` carries it) and return an error instead of a doomed load. Add a small-context case and a reloads-per-run count to A5.

**4. D13 "the index is not recorded", D4, A2: inconsistent with 031 D2.**
- **Claim:** no digest covers tool schemas, so a replay with different skills is not noticed.
- **Evidence:** the index lives in `config`. 031 ADR-001 D2 (lines 404-420) makes the per-extension config digest cover `config` plus `ToolProvider` names. It is recorded per policy epoch, a change on resume "appends a snapshot and continues", and "strict whole-run replay compares the full config epoch". The function exists (`src/core/ext/registry_normalize.ail:441`, `:543`) but has no caller outside its module at HEAD.
- **Why it matters:** the claim is true of the code today and false of the accepted design. D4's conclusion (no resume refusal) survives. 031 D2 also says the plan bounds retained config size, and this ADR puts up to 1,024 chars per skill into `config` and every request with no cap on the number of skills.
- **Change:** reword D13, add "the config digest moves and the resume continues" to A2, and add a total index budget.

**5. D2: the ABI status of the reserved key is left open.**
- **Claim:** "documented … as an 8.x convention. No type changes."
- **Evidence:** 031 ADR-001 line 6 says the ABI is frozen at 8.0 and "further changes are numbered amendments". Rule 3 in `packages/motoko-ext-abi/types.ail` lets a minor add an exported type, function or constructor. A reserved key is none of these. The ADR's own Related records say 033 "bears on whether the reserved key is an 8.1 minor".
- **Change:** record it as Amendment 5 to 031 and decide the version. Prefer exporting the key from the ABI as a function that both the extension and `normalize_registration` use, which rule 3 allows. Say that a present key of any non-string type also refuses.

**6. D11, D2: default-profile membership is not decided.**
- **Evidence:** D2 says "once `skills` is in that profile", D11 says profiles opt in, and §4 step 5 says "a test profile".
- **Why it matters:** three things hinge on it:
  - whether CI enforces D1 at all (vacuous anyway while `.motoko/skills` does not exist, which D11 ensures);
  - the one-time `ExtSet` resume refusal for every in-flight session on that profile (`src/core/journal.ail:629`);
  - the per-request index cost.
- **Change:** decide it in the ADR.

**7. D10, V7: call-time behaviour claims more than the source supports.**
- **Truncation:** V7 says a larger skill "would load truncated without saying so". `cap_tool_message_content` appends `...[truncated; original N bytes]` (`src/core/phase_vocab.ail:1559-1567`), though it cuts mid-JSON.
- **Unreadable file:** D10 says this is a tool error. `ambient_file` calls `isFile` then the non-`Result` `readFile`, which M1 shows ends the process on failure. I did not test a permission failure specifically.
- **Re-validation:** D1 says a skill that breaks after startup is a tool error, but D10 specifies that only for a missing file. A file edited past the V7 limit is delivered cut.
- **Change:** have the handler re-measure size at call time, and correct both sentences.

**8. D9: edge cases unspecified, where V4 turns ambiguity into refusal or a silent misread.**
- **Missing:** `>-` and `|-` chomping, an indented continuation after a plain `description:`, blank and comment lines, CRLF, BOM, quoted-scalar escapes, and whether 1,024 is measured after folding.
- **Evidence for D9:** in the 77 `SKILL.md` files of the gitignored `ailang/` checkout, 75 have plain single-line descriptions and 2 have no frontmatter at all.
- **Change:** enumerate each case as accept or refuse.

**9. D13 details.**
- "The one kind a profile may exclude" overstates: `Lifecycle` exclusion is also admitted (`src/core/dst_profile_coverage.ail:211-217`).
- There is a fourth omitted list, in `src/core/dst_driver_only.ail:957`, which D13 and A8 do not mention.
- `driver_plus_herdr`, the precedent, is in `DST_KNOWN_RED` (`Makefile:697`).
- The "stale by one" drift is real: `ailang.toml` lists 19 packages, the count tests pin 14, 17 and 17 (`dst_driver_plus_no_ops.ail:974`, `dst_driver_plus_compose.ail:1045`, `dst_driver_plus_herdr.ail:463`), and `ailang_tools` is in none of the lists.

**10. §4 ordering.** The ADR says `Skill` "may have to become a core tool" if JSON-escaped delivery works poorly, yet step 1 lands the core rejection variant before that is measured. A core tool would not need the config-key path. Measure first with a throwaway extension.

## Decisions

| Decision | Assessment |
| --- | --- |
| D1 | Sound as a rule; findings 2 and 7. |
| D2 | Mechanism is feasible as described; finding 5. |
| D3 | Matches the specification as fetched today. |
| D4 | Sound; add the config digest (finding 4). |
| D5 | Supported: 12 of 16 non-hits on the weakest model were no tool call. Across all models, 9 of 22 were another tool first, which a gate could catch. |
| D6 | Nothing to add. |
| D7 | Finding 1. |
| D8 | Finding 3. |
| D9 | Finding 8. |
| D10 | Finding 7. |
| D11 | Finding 6. |
| D12 | Sound, and stronger than stated: without it, going between zero and one skill would change the capability kinds and so `ext_set_digest`. |
| D13 | Findings 4 and 9. Omitting on the ambient verdict is consistent with `tools/profile_definition/check_fixtures.py:694`. |

## Acceptance checks

| Check | Decidable? | Gap |
| --- | --- | --- |
| A1 | Yes | No zero-skill case (D12). |
| A2 | Yes | The `ext_set_digest` half is already proven by the test at `src/core/ext/runtime.ail:1555`. Add 0↔1 transitions and the config digest. |
| A3 | Only with the sandbox stated | V2 and V3 fixtures need the sandbox to exist at all; V4 has several sub-cases behind one fixture. |
| A4 | Yes | `registry_multiplicity` is not in the CI workflow, only `make dst`. |
| A5 | No pass condition, by design | "Follows the skill" has no rubric; no loop or cost measure. |
| A6 | Yes | — |
| A7 | No | It points at research §10, which is an unverified survey. |
| A8 | Yes | Passes with `ailang_tools` still missing and `driver_only` unmentioned. |

Nothing checks D10 (unknown name, edit picked up, directory line), D12, or a workdir other than the cwd.

## Coordinates checked and correct

- `packages/motoko-ext-abi/types.ail`: `:27`, `:29`, `:1943`, `:1948`, `:2000`.
- `packages/motoko-ext-mcp/register.ail:27`; `packages/motoko-ext-herdr/register.ail:230`; `packages/motoko-ext-compaction-ai/compaction_ai.ail:284`.
- `src/core/ext/registry_normalize.ail`: `:154`, `:164`, `:174`, `:330`; `src/core/ext/registry_generated.ail:107`; `scripts/verify_extension_boot.ail:60`.
- `src/core/phase_vocab.ail`: `:365`, `:1559`, `:1629`; `src/core/tool_contract.ail:60`; `src/core/tool_catalog.ail:132`.
- `src/core/ext/runtime.ail:1327`; `src/core/journal.ail:629`, `:631`; `src/tui/src/runtime-process.ts:475`.
- `src/core/dst_profile.ail:569`; `src/core/session.ail:1404`; `src/core/ports.ail:346`, `:1335`.
- `not_installed` at `dst_driver_plus_no_ops.ail:635`, `dst_driver_plus_compose.ail:686`, `dst_driver_plus_herdr.ail:303`; `dst_driver_plus_herdr.ail:25`.
- `src/core/dst_profile_coverage.ail`: `:220`, `:225`, `:287`, `:292`.
- `src/core/dst_interaction.ail:59`; `src/core/dst_replay.ail:853`; `src/core/dst_fault_catalogue.ail:420`; `scripts/dst/registry_multiplicity_dst.ail` exists.
- 009 ADR-001 D5 is at line 1226.
- Facts: the 58-char envelope offset; the 70% and 75% thresholds; 23,258 bytes for the largest tracked skill; 2,225 description chars; four plain descriptions and one double-quoted; `registration_refusal` unused in the tree; three 031 records naming the deleted doc (a fourth is in project 025); the M2 tallies of 139/150 per placement and 150 clean controls, recomputed from `m2_results.tsv`.

## Not checked

- `m3_compaction_probe.sh` and `m2_trigger_probe.py` were not run. The D8 elision example shows 12,861 chars where research case H records 12,836; the 25-char difference matches the marker line of case I, but I could not confirm it.
- No make target, test or gate was run, so "`driver_plus_no_ops` is red at HEAD" is inferred from source.
- How the TUI treats a refused respawn at a wake boundary, where the `wake` entry is already written.
- Whether tool call ids are unique on every provider, which the repetition-guard argument in finding 3 depends on.
- `readFile` on a permission failure.
- The `skills-ref` validator's behaviour on non-ASCII names.
- The research §10 survey items it marks unverified.
- 017 ADR-001 and 006 ADR-001.

## Follow-up qualifications from the delegating agent

Checked against the tree at `da7e9e65` after the review came back.

| Finding | Status |
| --- | --- |
| 1. Registration cannot learn the workdir | **Confirmed in source.** `supervisorWorkdirArg` (`src/tui/src/runtime-process.ts:326`), the comment on why `MOTOKO_WORKDIR` is left unset (`:517`–`:526`), and `getEnvOr("MOTOKO_WORKDIR", ".")` (`packages/motoko-ext-herdr/register.ail:44`) read as described. The end-to-end behaviour with a workdir other than the cwd was not run. |
| 2. The root fails open; verdicts depend on the sandbox | **Confirmed.** M1 shows `isDir` is `false` for an absolute-target or outside symlink, and V2 covers entries, not the root. The `verify_extensions` recipe sets no `AILANG_FS_SANDBOX` and prints only lines matching `Error|UNKNOWN`. |
| 3. The standing instruction can loop | **Cap confirmed** (research §9 M3, the over-30% case, which the ADR left out). The repetition-guard argument was not checked. |
| 4. "The index is not recorded" against 031 D2 | **Confirmed.** 031 ADR-001 lines 404–420 read as quoted. True of the code today, false of the accepted design. |
| 5. ABI status of the reserved key | **Confirmed.** 031 ADR-001 lines 6–7: the ABI is frozen at 8.0 and further changes are numbered amendments. |
| 6. Default-profile membership undecided | **Confirmed** as a gap in the ADR text. An operator decision. |
| 7. Call-time behaviour overstated | **Confirmed.** The truncation note is at `src/core/phase_vocab.ail:1564`; `ambient_file` is `isFile` then the panicking `readFile` (`src/core/ports.ail:1393`). |
| 8. D9 edge cases | The cases are unspecified in the ADR. The 77-file count was not checked. See also the Codex review's finding 2, which removes D9's premise. |
| 9. D13 details | **Confirmed**, all four: the Lifecycle note at `src/core/dst_profile_coverage.ail:211`, an omitted list in `dst_driver_only.ail`, `DST_KNOWN_RED` at `Makefile:697`, and the 14/17/17 pins with `ailang_tools` in none of the four files. |
| 10. Ordering | The premise it responds to is itself wrong: the Codex review's finding 7 shows native tool results are JSON-wrapped too. |

## Disposition — 2026-10-03

Addressed in ADR-001 v0.2 (Proposed). Items marked "ruling" await the operator; the numbers are
the rows of the ADR's §6.

| Finding | Disposition |
| --- | --- |
| 1. Registration cannot learn the workdir | Accepted. D7 now states how the root is located (`MOTOKO_WORKDIR`, then `MOTOKO_JOURNAL_WORKDIR`, then `.`), stores the resolved root in `config`, and has the handler build its path from it. A10 is the acceptance check. Not yet run; the prototype tests it. Ruling 2. |
| 2. The root fails open; verdicts depend on the sandbox | Accepted. D1 adds rule R1 for the root, states the rules against the sandbox, and requires `verify_extensions` to set the sandbox and print the rejection. `evidence/m6_boot_sandbox_probe.sh` shows the nine default-profile extensions boot under it. Ruling 4. |
| 3. The standing instruction can loop | Accepted. D8 adds a size check against `ctx.context_limit` at 25%, a deterministic check (A6b), and a reloads-per-run and small-context case in A5. Ruling 1. |
| 4. "The index is not recorded" against 031 D2 | Accepted. D4 states the config digest as the designed record and that it is not built at HEAD; A2 adds it; D4 adds a total index budget (V8). Ruling 5. |
| 5. ABI status of the reserved key | Accepted. D2 makes it Amendment 5 to 031 ADR-001 and an 8.1 minor exporting the key and its reader, and defines the non-string case. Ruling 6. |
| 6. Default-profile membership | Accepted. D11 decides: not in v1, ruled after A5, with the three consequences stated. Ruling 9. |
| 7. Call-time behaviour overstated | Accepted. V7's wording is corrected, D10 validates on every call, and D10 now says an unreadable file ends the runtime. Rulings 4 and 8. |
| 8. D9 edge cases | Superseded. D9 now decodes with `std/yaml`, so the cases are YAML's; `evidence/m5_yaml_probe.sh` runs them. Ruling 3. |
| 9. D13 details | Accepted, all four: the Lifecycle wording, the fourth omitted list, the known-red precedent, and the stale pins as a baseline the PLAN settles first. Ruling 10. |
| 10. Ordering | Accepted in substance. §4 now starts with a throwaway prototype and A5, before any core or ABI change. The reason changed: a core tool would not avoid JSON escaping (Codex finding 7). |

Not taken up: the note that one of the records naming the deleted design doc is in project 025.
A search of the tree finds three, all in project 031.
