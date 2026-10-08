# REVIEW-001: Codex (GPT-6-Astra) review of ADR-001 (skills system)

Date: 2026-10-03
Reviewer: Codex CLI 0.160.0, launched with `--yolo -m gpt-6-astra`; the terminal status line confirmed GPT-6-Astra, reasoning effort high.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `adr037-codex`, pane `w7:p2`.
Document reviewed: [ADR-001-skills-system.md](ADR-001-skills-system.md).
Document SHA-256: `da8e852b3d075fa6d4e9629ee1b06ccc27902ae94de0b5e39ee13081f0c9bbed`.
Status: Addressed in ADR-001 v0.2; see the disposition table at the end. The reviewed version's hash is preserved above. A second, independent review is in
`REVIEW-001-claude-fable-5.1.md`.

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

The response below was captured from the reviewer's completed Herdr terminal output. Terminal
indentation has been removed and the two box-drawn tables are kept as text; its claims and
recommendations are unchanged.

## Reviewer response

**sound with changes**

The SHA-256 matches da8e852b3d075fa6d4e9629ee1b06ccc27902ae94de0b5e39ee13081f0c9bbed, both before and
after review. Reviewed at HEAD da7e9e65ef329654b0d67a8d110af23a1a9834ec. The cited implementation
paths have no changes between the ADR’s grounding commit and HEAD, or uncommitted changes. No review
files were consulted.

The extension architecture is reasonable, but several accepted promises cannot be delivered by the
specified implementation.

Findings, most severe first

1. D10/D13, §0 — unreadable files cannot reliably become tool errors through the existing port.

   D10 promises that a file becoming unreadable produces a tool error. However, src/core/
   ports.ail:1393 implements the live read as isFile(path) followed by panicking readFile(path). A
   regular file can pass the first operation and fail the second through permissions, disappearance,
   or another filesystem error. The bridge at src/core/session.ail:1404 forwards the result without
   recovery.

   Moreover, packages/motoko-ext-abi/types.ail:239 gives ExtFileRead only present, content, and
   next_state: no error channel. Its record cannot simply gain one under the stated 8.x rule.

   Change: Resolve this before planning. Either change the core adapter to return a deliberately
   specified “unavailable” result through the existing shape, or narrow D10’s guarantee and record
   fatal read failures. A typed distinction between absent and failed reads needs separate ABI
   consideration. The “one core change” claim is insufficient if the tool-error guarantee remains.
   A6’s present/absent stubs cannot catch this defect.

2. D9 — the premise requiring a handwritten YAML parser is false on the installed toolchain.

   /home/motoko/.local/share/ailang/std/yaml.ail:5 declares std/yaml; lines 12 and 18 export
   yamlToJson and decode, returning Result. This command succeeded:

   AILANG_RELAX_MODULES=1 ailang check /home/motoko/.local/share/ailang/std/yaml.ail
   ✓ No errors found!

   That directly contradicts ADR line 192 and research §5.5. The failed search recorded in the
   research did not establish module absence.

   Change: Reconsider D9 using std/yaml.decode after extracting frontmatter. Check its behavior and
   inventory compatibility before committing to a custom parser. This could remove substantial
   implementation work and interoperability risk. I checked the existing module; I did not execute its
   decoder.

3. D1/D10 — startup validation does not protect loads after edits.

   D1 promises that a skill breaking after startup becomes a tool error. D10 explicitly rereads
   current content but specifies only missing/unreadable-file errors. It never requires rechecking
   frontmatter, directory/name agreement, description, or V7.

   Consequently, an initially valid file can become malformed, change its declared name, or grow
   beyond the delivery limit while still loading successfully. The current cap then truncates it.
   Evidence: ADR lines 81–83 versus 211–218, and src/core/phase_vocab.ail:1559.

   Change: Require validation of the actual bytes returned by every mediated read, including the
   delivery-size bound. Specify that metadata used for discovery remains frozen until respawn, even
   when valid edited text is loaded. Add post-registration mutation cases and exact-boundary cases to
   acceptance. Measure the complete serialized result, including the directory line and envelope,
   rather than relying solely on unspecified headroom.

4. D8/A5 — reloading can repeatedly return a skill that the model never receives intact.

   The structural compactor caps every tool result occupying at least 30% of the context limit,
   including the newest result: packages/motoko-ext-compaction-structural/
   compaction_structural.ail:85. It applies that cap before ordinary age-based elision at line 176.

   Thus, with sufficient other context, a successful reload is immediately capped before the next
   model request. Following the standing instruction can produce repeated reloads without recovering
   the instructions. Research M3 already identifies this case at lines 330 and 351–353, but D8’s
   remedy and A5 omit it.

   A5 also has no pass/fail criterion for useful behavior. Zero adherence and zero successful recovery
   can satisfy “reported, not gated.”

   Change: Add a deterministic acceptance requirement that a supported skill reaches the model intact
   on activation and recovery. Cover the newest-result 30% case and repeated reloads. Decide a
   supported size/context envelope or recovery mechanism. Keep stochastic model measurements advisory
   if desired, but require an explicit disposition of failed measurements before implementation is
   accepted.

5. D3/D9/V5 — “the format is unmodified” contradicts the proposed parser and current specification.

   D9 deliberately interprets  # as content. For example, name: observer # comment has different
   semantics under this parser and YAML. Other valid YAML forms are refused globally at startup.

   V5 also describes the specification as ASCII-only. The fetched specification permits Unicode
   lowercase alphanumeric characters; its reference validator applies Unicode normalization and
   isalnum(). See the specification (https://agentskills.io/specification) and reference validator
   (https://raw.githubusercontent.com/agentskills/agentskills/main/skills-ref/src/skills_ref/
   validator.py).

   Change: Either implement the adopted YAML semantics and naming rules, or explicitly call this a
   Motoko subset with documented deviations. Define whitespace-only descriptions, quoted escapes,
   block folding/chomping, comments, and line endings. A few invalid fixtures cannot establish parser
   compatibility; include valid examples that must survive parsing unchanged in meaning.

6. D1/D7/D12 — discovery has an unspecified failure boundary.

   V1–V7 classify entries beneath the root, but do not classify an invalid, inaccessible, or
   unlistable root. The allowed M1 probe reproduced:

   listDir(missing root)  exit=1
   isDir(outside root)   exit=0 ... false

   The installed /home/motoko/.local/share/ailang/std/fs.ail:70 exposes listDir without a Result
   variant. An isDir guard neither guarantees that a subsequent listing succeeds nor distinguishes a
   genuinely missing root from a sandbox-rejected root.

   This permits either silent zero-skill operation or a process failure outside D2’s host-owned JSONL
   refusal path.

   Change: Specify root-level errors and discovery races separately from skill validation. Decide
   which failures must be structured refusals and establish a feasible mechanism for them. Narrow the
   aggregation guarantee where the filesystem prevents discovering all entries. Add root-as-file,
   rejected-root-symlink, listing-failure, and genuinely absent-root cases.

7. §5 and §4 — ReadFile does not deliver raw text on the current native path.

   The claimed contrast with extension results is false. src/core/tool_dispatch_adapter.ail:97 places
   ReadFile content inside JSON, and line 208 encodes that object. src/core/ports.ail:1759 passes the
   encoded content into ToolCompleted; src/core/tool_phase.ail:279 forwards it to the model message.

   Change: Remove the raw-text comparison and the suggestion that becoming a core tool inherently
   solves escaping. Keep the real-harness adherence measurement, but base any architectural change on
   an actual output-format experiment.

8. D2/A4 — the new refusal convention needs a compatibility contract.

   A non-empty key works with the existing normalization boundary and requires no ABI type change.
   However, existing ABI-8 hosts ignore it: src/core/ext/registry_normalize.ail:330. Such a host would
   accept the extension’s normal capabilities despite its refusal.

   Conversely, reserving a previously unrestricted configuration key changes its meaning for consumers
   that already use it. Absence in this tree is useful evidence, but not a compatibility guarantee for
   every ABI consumer.

   Change: State the minimum supporting host version and resolve the currently deferred versioning
   question. Specify absent, empty, wrong-type, and non-empty key behavior, including precedence over
   existing rejections. Add acceptance controls proving ordinary registrations remain accepted. The
   general host-owned refusal approach is sound.

9. D13/A7/A8 — the DST disposition needs clearer verification and narrower factual claims.

   Omitting the extension in v1 is defensible and avoids pretending that mediation establishes replay
   coverage. Three details need correction:
    • “ToolProvider … the one kind a profile may exclude” overstates src/core/
      dst_profile_coverage.ail:225: ExitIntent is separately Lifecycle, and its exclusion is admitted,
      with a documented enforcement gap at lines 211–215.

    • D13 conflates non-refusing resume changes with unrecorded replay inputs. src/core/ext/
      registry_normalize.ail:543 already defines a digest covering config, which would include the
      index. Project 031’s ADR lines 414–420 explicitly separate continuing a resume from recording
      and comparing configuration epochs. Current missing persistence must be described as an
      implementation gap, not a necessary consequence of D4.

    • A8 names only profile_definition, whereas the three edited profiles have separate checks. A7
      does not explicitly require the non-CI registration-shape and related DST gates. Re-pinning
      constants is not verification. Also address project 009 D5’s profile-version rule at line 1287
      when changing omission declarations.

   Change: Name the required affected-profile, ext_hook_scope, registry_multiplicity, registry-
   generation, and inventory checks. Record a baseline disposition for pre-existing failures instead
   of treating changed pins as proof of correctness.

10. D4/D11 — the index has no aggregate capacity policy.

   V6 bounds each description, but nothing bounds the number of skills or total schema size. D4 sends
   the complete index on every request, and D11 offers no selection mechanism. Individually valid
   skills can therefore create a catalogue that leaves insufficient context or exceeds provider
   limits. Message compaction cannot remove the standing tool schema.

   Change: Define an aggregate supported budget or explicitly defer it as a known limitation with an
   oversized-index acceptance case. Require deterministic ordering. Five-skill measurements do not
   establish scalability.

11. Smaller factual and acceptance corrections.
    • D1/V7: “truncated without saying so” is false: src/core/phase_vocab.ail:1564 appends an explicit
      truncation marker. The lost instructions remain a valid reason for a limit.

    • §0: refusal occurs before the refused extension’s entry is accepted, not before any registry
      entry exists. src/core/ext/registry_generated.ail:80 carries previously accepted entries in acc.

    • D8: the MotokoRuntimeStatus precedent preserves a bounded excerpt, not an arbitrary whole
      result: packages/motoko-ext-compaction-ai/compaction_ai.ail:332 limits it to 1,200 characters.

    • D4/A5 evidence: M2 scores a matching Skill anywhere in the first response, not necessarily
      first. evidence/m2_results.tsv:155 is a hit whose first_tool is ReadFile. Use a distinct first-
      call metric for A5. The reported 139/150 triggering totals are correct.

    • D4 cost: 2,225 counts the raw descriptions including the two YAML quote delimiters around herdr;
      decoded descriptions total 2,223 characters. Neither number includes the fixed instruction and
      list formatting.

    • A1/D12: specify N > 0 for the enum assertion and a separate zero-skill assertion; D12
      deliberately removes the enum at zero.

    • A2/D1: qualify additions and edits as valid. An invalid change must refuse startup under D1
      despite unchanged resume digests.

Assessment of all decisions

```text
 Decision    Assessment
━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 D1          Fail-closed policy is coherent; root failures, post-start validation, and delivery
             bounds are incomplete.
 D2          Host-owned rejection is feasible; compatibility and key semantics need definition.
 D3          Standard-format adoption is sensible; “unmodified” is currently unsupported.
 D4          Tool-description placement is well motivated by resume behavior; capacity and
             measurement claims need qualification.
──────────  ──────────────────────────────────────────────────────────────────────────────────────────
 D5          Sound scope choice. A tool-policy gate cannot force a load when no tool is called.
──────────  ──────────────────────────────────────────────────────────────────────────────────────────
 D6          Sound scope choice; no implementation contradiction found.
 D7          Sound single-root choice; distinguish root failure from absence.
 D8          Insufficient recovery design for the deterministic large-result case.
──────────  ──────────────────────────────────────────────────────────────────────────────────────────
 D9          Reconsider: its central factual premise is false.
──────────  ──────────────────────────────────────────────────────────────────────────────────────────
 D10         Frozen discovery with live text is feasible; validation and failure semantics are
             incomplete.
──────────  ──────────────────────────────────────────────────────────────────────────────────────────
 D11         Sound opt-in and migration scope; combined with D4 it exposes aggregate-index costs.
──────────  ──────────────────────────────────────────────────────────────────────────────────────────
 D12         Feasible and supported by catalogue/boot behavior; test the zero-skill contract
             explicitly.
──────────  ──────────────────────────────────────────────────────────────────────────────────────────
 D13         Honest coverage deferral overall; fix the narrower factual and verification issues
             above.
```

ABI 8.0 supports the proposed DescribeTools/ToolProvider combination and disclosed configuration.
Named callbacks, the full provider effect row, literal registration structure, and appropriate package
effect ceilings have existing precedents. The obstacle is the promised filesystem-error behavior, not
the basic extension composition.

Assessment of all acceptance checks

```text
 Check    Decidable as written? What can still pass incorrectly?
━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 A1       Yes for positive N. Does not cover zero skills, duplicate installation, ordering, schema
          validity, or aggregate size.
 A2       Yes for controlled valid mutations. Does not test activation-time freshness or malformed
          edits.
 A3       Partly: V7’s limit and parser semantics remain unsettled. One fixture per numbered rule
          misses its multiple subcases and root failures.
 A4       Yes once key semantics are fixed. A reject-everything implementation needs positive
          controls; old-host behavior is uncovered.
 A5       Decidable only as “measurements were reported.” It cannot establish acceptable
          functionality, and “follows the skill” needs a scoring rubric.
───────  ─────────────────────────────────────────────────────────────────────────────────────────────
 A6       Yes structurally. Present/absent stubs miss live read panics and can miss discarded
          successor state unless the stub changes it.
───────  ─────────────────────────────────────────────────────────────────────────────────────────────
 A7       Observable for a pinned gate set, but insufficiently enumerated. Re-pinned expectations can
          hide incorrect behavior.
───────  ─────────────────────────────────────────────────────────────────────────────────────────────
 A8       Yes for textual inclusion. profile_definition alone does not verify all three changed
          profile declarations.
```

Before planning, I would settle findings 1–6, specify the refusal compatibility contract, and turn the
deterministic loading/recovery obligations into explicit acceptance checks. Preserve D5, D6, D7’s
single-root scope, D11, and the basic extension composition.

Coordinates checked and found correct

All explicit ADR file:line anchors resolve to the indicated implementation or explanatory passage.
None were numerically stale at the reviewed HEAD. Some surrounding claims overreach those passages, as
identified above.

• packages/motoko-ext-abi/types.ail: 27, 29, 1943, 1948, 2000.
• packages/motoko-ext-mcp/register.ail: 27.
• packages/motoko-ext-herdr/register.ail: 230.
• src/core/ext/registry_normalize.ail: 154, 164, 174, 330.
• src/core/ext/registry_generated.ail: 107.
• scripts/verify_extension_boot.ail: 60.
• src/core/ext/runtime.ail: 1327.
• src/core/journal.ail: 629, 631.
• src/tui/src/runtime-process.ts: 475.
• src/core/tool_contract.ail: 60.
• src/core/phase_vocab.ail: 365, 1559, 1629.
• packages/motoko-ext-compaction-ai/compaction_ai.ail: 284.
• src/core/tool_catalog.ail: 132.
• src/core/dst_profile.ail: 569.
• src/core/session.ail: 1404.
• src/core/ports.ail: 346, 1335.
• src/core/dst_driver_plus_no_ops.ail: 635.
• src/core/dst_driver_plus_compose.ail: 686.
• src/core/dst_driver_plus_herdr.ail: 25, 303.
• src/core/dst_profile_coverage.ail: 220, 225, 287, 292.
• src/core/dst_interaction.ail: 59.
• src/core/dst_replay.ail: 853 — explanatory comment; the actual assignment is at 863.
• src/core/dst_fault_catalogue.ail: 420.
• Project 009 ADR D5 begins at 1227.

I also confirmed the five existing skills, the largest file’s 23,258-byte size, the three project-031
references to the deleted design, M2’s recorded totals, the default compactor configuration, and M1’s
sandbox results.

What I did not check

I did not run make targets, tests, M2, M3, inventory scripts, or paid APIs; compile a prototype
extension; reproduce permission/race failures; execute YAML decoding; or measure model adherence,
provider schema limits, or live-session replay capture. I did not independently authenticate
historical operator rulings or the original probe executions.

The only executed probe was the permitted temporary-directory M1 script. I also type-checked the
existing installed YAML module. No repository files were created, edited, staged, or committed, and no
agents were delegated to or coordinated with.

## Follow-up qualifications from the delegating agent

Checked against the tree at `da7e9e65` after the review came back.

| Finding | Status |
| --- | --- |
| 1. An unreadable file cannot become a tool error | **Confirmed.** `ambient_file` is `isFile` then the panicking `readFile` (`src/core/ports.ail:1393`), and `ExtFileRead` has no error field (`packages/motoko-ext-abi/types.ail:239`). |
| 2. `std/yaml` exists | **Confirmed.** `~/.local/share/ailang/std/yaml.ail` exports `yamlToJson` and `decode`. The research's "no YAML module" came from a docs-server search and is wrong. The decoder was not run by either of us. |
| 3. No validation after startup | **Confirmed** as a gap in the ADR text. |
| 4. Reload can return a skill the model never receives | **Confirmed** (research §9 M3, the over-30% case, which the ADR left out). |
| 5. "Unmodified" against the parser and the specification | The ` #` difference is stated in D9. The claim about Unicode names in the reference validator was not checked. |
| 6. Discovery's failure boundary | **Confirmed** from M1: `listDir` has no `Result` form and ends the process, and `isDir` cannot tell a missing root from a rejected one. |
| 7. `ReadFile` does not deliver raw text | **Confirmed.** `tool_result_item_to_json` and `dispatch_one_typed` (`src/core/tool_dispatch_adapter.ail:95`, `:204`) encode native results as JSON. ADR §5's contrast, and the suggestion that a core tool would avoid escaping, are wrong. |
| 8. Compatibility contract for the refusal key | Reasoning accepted; nothing in the tree to check it against. |
| 9. D13 details | **Confirmed**: the Lifecycle note (`src/core/dst_profile_coverage.ail:211`) and 031 ADR-001 lines 404–420. |
| 10. No aggregate index budget | Accepted; the ADR has none. |
| 11. Smaller corrections | V7's "without saying so" is wrong (`src/core/phase_vocab.ail:1564`). The M2 point is right about the scoring: a matching `Skill` call anywhere in the first response counts as a hit, and `m2_results.tsv:155` is such a row. |

## Disposition — 2026-10-03

Addressed in ADR-001 v0.2 (Proposed). Items marked "ruling" await the operator; the numbers are
the rows of the ADR's §6.

| Finding | Disposition |
| --- | --- |
| 1. An unreadable file cannot become a tool error | Accepted. D10 now says such a file ends the runtime in v1 and raises the adapter as an issue for the port's owner; an error channel on the port is out of scope. The "one core change" claim is unaffected because the guarantee is narrowed, not kept. Ruling 8. |
| 2. `std/yaml` exists | Accepted. D9 is replaced: frontmatter is decoded by `std/yaml`. `evidence/m5_yaml_probe.sh` runs the decoder on the five skills and 26 edge cases. The inventories' verdict on the import is left to the PLAN, with v0.1's parser as the fallback. Ruling 3. |
| 3. No validation after startup | Accepted. D10: the handler applies V4–V7 and the size check to what it read, on every call; the index stays frozen until respawn. A9 covers it. Ruling 4. |
| 4. Reload can return a skill the model never receives | Accepted. D8's size check, and A6b as the deterministic check asked for. A5 stays advisory but the implementation is not accepted until the operator records a disposition of it. Ruling 1. |
| 5. "Unmodified" against the parser and the specification | Accepted. D3 now names two differences from the reference validator: ASCII names and ignored unknown keys. The ` #` difference is gone with the hand-written parser. The validator was fetched and reads as the review says. Ruling 7. |
| 6. Discovery's failure boundary | Accepted. D1 adds the root rule, and states what the guarantee does not cover: a tree that changes during the scan. A3 adds the root fixtures. Ruling 4. |
| 7. `ReadFile` does not deliver raw text | Accepted. §5 withdraws the contrast and the core-tool suggestion; §4's order is re-argued. |
| 8. Compatibility contract for the refusal key | Accepted. D2: semantics for absent, empty, wrong-type and non-empty; checked before the multiplicity walk; the package depends on ABI 8.1; A4 adds positive controls. Ruling 6. |
| 9. D13, A7 and A8 | Accepted. D13's three statements are corrected, A7 names the gates and requires a baseline, A8 names all four lists and the profile-version change. Ruling 10. |
| 10. No aggregate index budget | Accepted. V8, proposed at 16,000 chars, and a deterministic order. Ruling 5. |
| 11. Smaller corrections | Accepted: V7's wording, §0's wording, the 1,200-char excerpt, the M2 scoring note and a first-call metric in A5, the description count, A1's zero-skill case, A2's "valid". |
