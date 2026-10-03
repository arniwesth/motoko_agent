# REVIEW-002: Claude Fable 5.1 review of ADR-001 v0.2 (skills system)

Date: 2026-10-03
Reviewer: Claude Fable 5.1, launched with `--model claude-fable-5-1`; the terminal banner confirmed Fable 5.1.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `adr037-fable-r2`, pane `w7:p5`.
Reviewer session: `ee7bc6b1-fd66-42bb-ab15-c2e566df7e0a`.
Document reviewed: [ADR-001-skills-system.md](ADR-001-skills-system.md), v0.2.
Document SHA-256: `dab1a8fe7b416e86bf03154fe6cf55dd48b37b71de193c2c8dc522a045ecb879`.
Status: Addressed in ADR-001 v0.3; see the disposition table at the end.

## Scope

A changes-only review of ADR-001 v0.2, by a fresh session of the same model that reviewed v0.1.
The reviewer was given its own REVIEW-001 record, and told not to read the other reviewer's. It
was asked whether each earlier finding is actually resolved, to review what v0.2 added or
changed, and to say whether the ADR is ready for an implementation plan.

Read-only, as in REVIEW-001. The two probes allowed were `evidence/m1_sandbox_probe.sh` and
`evidence/m5_yaml_probe.sh`, which work in a temp dir.

The terminal could show only the end of the reply, so the reviewer was asked to save the same
reply, unchanged, to a temp file. The response below is that file.

## Reviewer response

**ready after changes**

SHA-256 matches (`dab1a8fe…ecb879`). HEAD is `10b1173a`, one commit past the ADR's `09cd5a5e`; that commit touches only `.agent/github/prs/origin-211/body.md`. I re-ran `m1_sandbox_probe.sh` and `m5_yaml_probe.sh`; both reproduce what the ADR reports.

## Earlier findings

1. **Workdir at registration: partly resolved.** D7 states a rule and A10 checks it, and the coordinates hold (`runtime-process.ts:327`, `:475`, `:526`; `rpc.ail:510`). It is unrun, as D7 says, and it introduces new finding 1.
2. **Root fails open: partly resolved.** R1, the sandbox condition and the two recipe changes are in D1 (`Makefile:2839` confirmed). A wrong base still fails open (new finding 2).
3. **Reload loop: resolved.** The 25% check sits under the compactor's 30% (`compaction_structural.ail:89`), `ProviderCtx.context_limit` exists (`types.ail:1016`), and A5 counts reloads.
4. **Index not recorded: resolved.** D4 matches 031 lines 404–420, and `ext_config_digest` still has no outside caller. One wording gap remains (new finding 5).
5. **ABI status of the key: resolved.** Amendment 5, two functions under rule 3, and the non-string case are all stated. The cost of the minor is not (new finding 3).
6. **Default-profile membership: resolved.** D11 decides it, and the default profile's nine extensions match.
7. **Call-time behaviour: resolved.** V7's wording, validation on every call, and the unreadable-file statement match `ports.ail:1393` and `ExtFileRead`.
8. **D9 edge cases: resolved by `std/yaml`.** The m5 run shows each listed case behaving as D9 says.
9. **D13 details: resolved.** All four omitted-list coordinates, `:211`, `Makefile:697` and 009 line 1287 check out.
10. **Ordering: resolved.** The prototype comes before any core change.

My earlier note about a record in project 025 was wrong: the tree has three, all in 031.

## New findings in v0.2

**1. D7 × D10: the directory line is a path the model's file tools refuse.**
- **Claim:** the result starts with the skill's directory "as the root in `config` spells it", which "lets the model resolve the bundled files".
- **Evidence:**
  - The TUI's workdir is `process.env.WORKDIR ?? process.cwd()` (`src/tui/src/index.ts:778`), so `MOTOKO_JOURNAL_WORKDIR` is absolute in an ordinary session, and so is the root.
  - `--workdir` reaches the core as `.` (`supervisorWorkdirArg`).
  - `validate_path_common` then rejects any absolute path with "absolute paths are not allowed" (`src/core/tool_runtime.ail:451-452`; `strip_workdir_prefix` returns the path unchanged when the workdir is `.`, `:420`).
  - The same happens when the workdir is a subdirectory of the TUI's directory.
- **Why it matters:** `ReadFile`, `Search` and `EditFile` fail on every bundled file in the default configuration. A9 and A10 would both pass.
- **Change:** spell the directory line relative to the workdir (`.motoko/skills/<name>`), separate from the spelling the port read uses. Add to A9 that `ReadFile` on a bundled file under that line succeeds, in both the default and the A10 layout.

**2. D1, D7: a wrong base still starts with zero skills and no refusal.**
- **Claim:** "a root that is simply absent is not a refusal".
- **Evidence:** in the m1 run, `isDir` on a path outside the sandbox returns `false` without error.
- **Why it matters:** D7's residual launcher, or a stale `MOTOKO_WORKDIR`, gives a base outside the sandbox, which reads as "no root". This is v0.1's failure, narrowed but not closed.
- **Change:** refuse when the base itself is not a directory as `std/fs` reports it.

**3. D2, §0, §4 step 2: the 8.1 minor is larger than "two functions".**
- **Evidence:**
  - `check_abi_pins` (`tools/profile_definition/check_fixtures.py:906`) requires every `abi_version` pin to equal the version in `packages/motoko-ext-abi/ailang.toml`.
  - 56 files carry a literal `"8.0"`, including every package manifest, every DST manifest and `conformance_abi_version()`.
  - Journal admission compares a recorded `abi_version` with the lock (`src/eval/journal/admission.ail:517`); I did not trace what that does to existing corpora.
  - 031's acceptance rule (ii) (line 1094) requires each amendment to attach an artifact. The ADR names none for Amendment 5.
  - The compatibility paragraph says depending on 8.1 keeps the extension off a host without the check. The dependency binds the ABI package; the check lives in `src/core`.
- **Change:** state the pin sweep and the corpus question as consequences, name the amendment's artifact (a fixture showing a refusing registration accepted at 8.0), and require the ABI functions and the host check to land in one change.

**4. D4 V8: the budget is not checked against provider limits on a tool description.**
- **Evidence:** M2 ran three models through OpenRouter, none from OpenAI (`m2_trigger_probe.py:29-33`). From memory, not verified here, OpenAI's API rejects a function description over 1,024 chars. Today's five descriptions total 2,223.
- **Why it matters:** if that holds, every request fails on such a model, not only skill calls.
- **Change:** in step 1, send one request with an index at budget size to each provider family the profiles use, and set V8 from the result.

**5. D4, A2: "a skill change is recorded" is true only of the index.**
- **Evidence:** `config` holds names and descriptions. D10 delivers body edits on the next call, and no digest covers the body.
- **Change:** say so in D4, and split A2's "rewording" into description (moves the config digest) and body (moves nothing).

**6. D8, A6b: "whole at any usage" is shown for one compactor.**
- **Evidence:** A6b tests `compact_for_pre_step` only. `compaction_ai` runs first in the default profile and, with `keep_recent_tokens` set, folds the newest message when it alone exceeds the budget (`compaction_ai.ail:264-271`). The default (`0`, six messages) and the three profiles at 20,000 are safe for a skill within V7; a smaller budget is not.
- **Also:** D8 measures "what it would return", while the compactor measures the JSON-encoded envelope (`:89`).
- **Change:** scope the claim, add a pure test on the `compaction_ai` split, and measure the encoded envelope as V7 does.

**7. D9, D4: two YAML consequences are unstated.**
- Folded and literal descriptions decode with newlines (m5 cases 12 and 14), which breaks "one line per skill"; collapse whitespace before building the index.
- A name like `123` satisfies V5's pattern but decodes as a number and refuses; say that such names must be quoted.

**8. A7, §4 step 2: `new_contract_policy` does not cover D2's functions.** It diffs `src/core` only (`tools/verify_classify/new_contract_policy.py:64`), and the two functions live in `packages/motoko-ext-abi`.

**9. §4 step 1.** "Wired locally" means editing `ailang.toml`, the lock and the generated registry, which other live sessions share; say it runs in a worktree. The `std/yaml` inventory check is cheap and decides whether D9 returns to the operator, so it belongs in step 1.

## What must change first

1. Finding 1: a plan written from the current D10 builds the wrong spelling.
2. Finding 2: one more rule in D1.
3. Finding 3: the plan cannot size step 2 without it.
4. Finding 4: one probe that can change V8.
5. Findings 5–9 are wording and scope.

## Not checked

- `m6_boot_sandbox_probe.sh`, `g0`, `g1`, `m2` and `m3` were not run; I read `m6`, `g0` and the head of `g1`, which defines 26 checks.
- How `std/fs` resolves a relative path when the process directory is not the sandbox root; m1 runs with the two equal. D7 depends on it.
- The OpenAI description limit (finding 4).
- How `std/yaml` on v0.47.2 handles timestamps, merge keys, or a `---` inside a block scalar. The only source I read was the old `ailang/` checkout.
- What the inventories make of a `std/yaml` import.
- What happens when `.motoko` is a symlink out of the workdir.
- Tool-call id uniqueness per provider.
- The specification's reference validator (D3).
- 033 beyond its ABI lines; 017 and 006.

## Follow-up qualifications from the delegating agent

Checked against the tree at `8dc2febf`, and with two probes run in response.

| Finding | Status |
| --- | --- |
| 1. The directory line is a path the file tools refuse | **Confirmed in source** (`src/core/tool_runtime.ail:420`, `:452`; `src/tui/src/index.ts:778`). The probe below shows the cause: v0.2's root rule was unnecessary. |
| 2. A wrong base still starts with no skills | True of v0.2's rule. With the bare relative root there is no base to be wrong under the sandbox. |
| 3. The 8.1 minor is larger than two functions | **Confirmed**: `check_abi_version` (`tools/profile_definition/check_fixtures.py:906`), twenty package manifests pinning `8.0`, `admission.ail:517`, and 031's acceptance rule (ii). |
| 4. The budget against provider limits | **Probed** (`evidence/m8_description_limit_probe.py`): Anthropic, Google, DeepSeek and Meta accept 16,000 chars. OpenAI could not be tested; this account's OpenAI key is rejected at any length. The 1,024-char claim stays unverified. |
| 5. Only the index is recorded | **Confirmed.** |
| 6. "Whole at any usage" is one compactor | **Confirmed** (`compaction_ai.ail:264`, `:273`; three profiles set `keep_recent_tokens` to 20,000). |
| 7. Two YAML consequences | **Confirmed** by the m5 run (cases 12, 14, 17). |
| 8. `new_contract_policy` does not cover the ABI package | **Confirmed** (`tools/verify_classify/new_contract_policy.py:64`). |
| 9. The prototype in a worktree; the YAML check in step 1 | Accepted. |

The item listed under "not checked", how `std/fs` resolves a relative path when the process's
directory is not the sandbox root, was then measured (`evidence/m7_fs_cwd_probe.sh`). A bare
relative path resolves against the sandbox root. That removes the premise of REVIEW-001's
finding 1 for sandboxed sessions, and with it the reason for v0.2's root rule.

## Disposition — 2026-10-03

Addressed in ADR-001 v0.3.

| Finding | Disposition |
| --- | --- |
| 1 | Accepted. D7 returns to the bare relative root, D10's directory line is `.motoko/skills/<name>`, and A9 requires `ReadFile` on a bundled file to succeed. Ruling 2 is replaced and needs the operator again. |
| 2 | Superseded by D7. For an unsandboxed launch with a foreign workdir, the handler returns an error instead of loading. |
| 3 | Accepted. D2: Amendment 5 with no version change, the reader in core, a test tying the two strings, and the amendment's artifact named. Ruling 6 is replaced and needs the operator again. |
| 4 | Accepted and partly settled. D4 records the probe; OpenAI is a named question for the plan's first step, and A5 includes it. |
| 5 | Accepted. D4 and A2. |
| 6 | Accepted. D8 scopes the claim and measures the envelope; A6b tests the `compaction_ai` split. |
| 7 | Accepted. D4 collapses whitespace; D9 says digit-only names must be quoted. |
| 8 | Accepted. Under D2 as revised the reader is in `src/core`, where the check applies. |
| 9 | Accepted. §4 step 1. |
