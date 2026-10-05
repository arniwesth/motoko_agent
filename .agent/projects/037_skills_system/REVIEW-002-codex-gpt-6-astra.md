# REVIEW-002: Codex (GPT-6-Astra) review of ADR-001 v0.2 (skills system)

Date: 2026-10-03
Reviewer: Codex CLI 0.160.0, launched with `--yolo -m gpt-6-astra`; the terminal status line confirmed GPT-6-Astra, reasoning effort high.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `adr037-codex-r2`, pane `w7:p4`.
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

The response below was captured from the reviewer's completed Herdr terminal output. Terminal
indentation has been removed; its claims and recommendations are unchanged.

## Reviewer response

**ready after changes**

SHA-256 matched dab1a8fe7b416e86bf03154fe6cf55dd48b37b71de193c2c8dc522a045ecb879 before and after
review. I read only the Codex review. HEAD moved during this review; the cited implementation surfaces
remained unchanged from 09cd5a5e.

The architecture is ready to develop further, but the path contract, host compatibility guarantee, and
remaining failure boundaries need correction before writing the implementation plan.

Earlier findings, in their original order:

1. Resolved — D10 explicitly accepts fatal live-read failures; this matches src/core/ports.ail:1393
   and the error-free ExtFileRead shape at packages/motoko-ext-abi/types.ail:239.

2. Resolved — D9 uses std/yaml; the permitted M5 probe reproduced all five successful skill decodes
   and the reported edge-case results.

3. Resolved — D10 requires V4–V7 validation on each read and freezes discovery metadata until respawn;
   A9 covers post-registration edits.

4. Resolved — D8 adds a size bound below the structural compactor’s 30% cutoff, A6b requires newest-
   result preservation, and A5 requires an operator disposition. compaction_structural.ail:85 and :189
   support this approach.

5. Partly resolved — ASCII naming and YAML semantics are now explicit, but D3’s claim of exactly two
   differences from the reference validator remains inaccurate; see finding 5 below.

6. Partly resolved — R1 addresses rejected root entries and D1 excludes scan races, but stable
   listing/access failures remain unspecified; see finding 3.

7. Resolved — §5 withdraws the raw-text distinction, consistent with src/core/
   tool_dispatch_adapter.ail:97 and :208.

8. Partly resolved — D2 defines key semantics and rejection precedence, but ABI 8.1 alone does not
   guarantee host enforcement; see finding 2.

9. Partly resolved — D13 corrects Lifecycle exclusion, config-recording status, all four omissions,
   and profile versions. A7 still omits the affected herdr profile gate; see finding 6.

10. Resolved — D4/V8 bounds aggregate index lines and requires name ordering; installed std/fs.ail:66
   documents sorted directory listings.

11. Resolved — The truncation wording, registration timing, bounded compaction excerpt, M2 metric,
   description count, zero-skill case, and valid-mutation qualification are corrected.

New or remaining findings in v0.2, most important first:

1. D7/D10/A10: the advertised directory can be unusable by native file tools.

   Claim: D10 returns the directory using the root’s config spelling so the model can resolve bundled
   files (ADR:347). D7 normally obtains an absolute root from MOTOKO_JOURNAL_WORKDIR.

   Evidence: The TUI defaults its workdir to process.cwd() (src/tui/src/index.ts:778), exports that
   string (runtime-process.ts:526), but passes --workdir "." when launched there (:327, :661). Native
   ReadFile preserves absolute paths when workdir is "." and then rejects them (src/core/
   tool_runtime.ail:419, :452, :520).

   Thus, in an ordinary launch, Skill can successfully read through its port and advertise /
   repo/.motoko/skills/example, while ReadFile("/repo/.motoko/skills/example/references/foo.md")
   fails. This is a source-derived counterexample, not a live reproduction.

   Change: Keep the resolved port lookup path in config, but advertise a workdir-relative directory
   suitable for native tools. Extend A10 to read a bundled file using the advertised directory,
   covering both the ordinary launch and a different workdir.

2. D2/A4: depending on ABI 8.1 does not establish the promised minimum host behavior.

   Claim: The dependency means skills “cannot be loaded by a host without the check” (ADR:162).

   Evidence: The proposed functions live in the ABI package, while enforcement lives separately in
   core. Existing normalize_registration accepts config without examining its contents (src/core/ext/
   registry_normalize.ail:330). The root host dependency is a package path (ailang.toml:11), and the
   ABI explicitly permits additive exported functions (types.ail:33). Updating that package does not
   update the host’s normalization implementation.

   An older host source tree using the new ABI can therefore resolve the extension’s new symbols while
   still ignoring its refusal. The dependency establishes symbol availability, not enforcement.

   Change: Specify the supporting host release/revision and require coordinated delivery of the ABI
   and normalization change. If “cannot load” is a hard requirement, define an enforceable host-
   support check. Add a compatibility control distinguishing an old normalizer using ABI 8.1 from a
   supporting host.

3. D1/R1/A3: stable root-listing failures still fall outside the stated contract.

   Claim: Broken roots receive structured refusals; the filesystem exception names a tree changing
   during scanning (ADR:111).

   Evidence: Installed /home/motoko/.local/share/ailang/std/fs.ail:70 exposes listDir without a
   Result. The permitted M1 probe again produced exit 1 for failed listings. A directory can also
   remain present and satisfy isDir while its permissions prevent listing; no concurrent mutation is
   required. R1 only covers an entry that is not a directory.

   Consequently, an existing but unlistable root or parent can fail outside the promised JSONL/exit-2
   path. The revision fixes the symlink-versus-absence ambiguity but does not finish defining
   discovery’s failure boundary.

   Change: Explicitly classify stable access/listing failures, including the parent directory. Either
   provide a feasible structured-error mechanism or extend the documented fatal-error exception beyond
   races. Align A3 with that narrower contract and include genuinely absent-root and listing-failure
   controls.

4. D4/A2: the config digest claim is broader than the specified captured data.

   Claim: Rewording a valid skill moves ext_config_digest, and a skill change is recorded and visible
   to replay (ADR:202, :464).

   Evidence: The ADR specifies an index and root in config, while D10 reads current body text
   separately. ext_config_digest hashes config and capability data only (src/core/ext/
   registry_normalize.ail:441, :543). Nothing specifies a body digest or captured body in config.

   Rewording only the Markdown instructions can therefore leave all specified digest inputs unchanged.
   An edit during a process also leaves registration config frozen. Implementing the deferred epoch
   recording would not itself make those edits visible through this digest.

   Change: Restrict A2 and D4 to index/config changes and explicitly exclude body-only edits, or
   specify the additional content identity to capture. Keep that distinction separate from D13’s
   unresolved recording of live read results.

5. D3/D9: “two stated differences” still overclaims compatibility.

   Claim: Against the reference validator, Motoko differs only in ASCII names and ignored unknown keys
   (ADR:178).

   Evidence: Motoko ignores all fields except name and description (ADR:175). The reference validator
   additionally checks the known compatibility field’s type and maximum length. Motoko would accept
   compatibility: 123, while that validator rejects it. See the reference validator (https://
   raw.githubusercontent.com/agentskills/agentskills/main/skills-ref/src/skills_ref/validator.py),
   _validate_compatibility and validate_metadata.

   Separately, D9’s “Everything else is YAML’s” needs the decoder’s documented qualification:
   installed std/yaml.ail:10 rejects YAML values that cannot be represented as JSON, including non-
   string mapping keys and NaN/Inf. Ignored fields still pass through that conversion.

   Change: Describe the actual validation boundary instead of claiming exactly two differences:
   required fields are validated, optional fields are not validated, and frontmatter must be decodable
   by this YAML-to-JSON implementation. Add representative acceptance cases for those boundaries.

6. D13/A7/§4: verification coverage and baseline ordering remain inconsistent.

   Claim: All four profiles change, affected gates are named, and the baseline is recorded before
   changes.

   Evidence: A7 names driver_only, driver_plus_no_ops, and driver_plus_compose, but omits
   driver_plus_herdr. Its dedicated target executes the graded scenario and profile inline tests
   (Makefile:597, :613). Being listed in DST_KNOWN_RED (:697) does not establish that later changes
   introduce no additional failures.

   Also, §4 puts “Baseline, then re-pin” at step 6, after ABI/core changes and registry wiring,
   contradicting A7’s “before the change” requirement and D13’s statement that existing profile
   discrepancies are handled first.

   Change: Capture the baseline before production changes, or explicitly against a preserved pre-
   change revision. Include driver_plus_herdr with an exact expected-failure disposition and require
   no new failures. Sequence existing profile-list repairs before adding skills to those lists.

What I did not check:

I did not run make targets, tests, inventory tools, graph extraction/query scripts, the boot-sandbox
probe, model measurements, paid APIs, or a prototype. I executed only the permitted M1 and M5 probes.
I did not reproduce permission failures or the native-path counterexample live, establish YAML
inventory compatibility, or verify live-session replay capture. I inspected the graph evidence scripts
but did not independently reproduce their historical outputs.

No repository files were written, no Git state was changed, and no other reviewer or agent was
consulted.

## Follow-up qualifications from the delegating agent

Checked against the tree at `8dc2febf`, and with two probes run in response.

| Finding | Status |
| --- | --- |
| 1. The advertised directory is unusable by native file tools | **Confirmed in source** (`src/core/tool_runtime.ail:420`, `:452`; `src/tui/src/index.ts:778`). `evidence/m7_fs_cwd_probe.sh` then showed that v0.2's root rule, which caused it, was unnecessary: a bare relative path resolves against the sandbox root. |
| 2. Depending on ABI 8.1 does not establish host behaviour | **Confirmed** by the dependency structure: the check is in core. |
| 3. Stable listing failures are outside the contract | **Confirmed** from M1: `listDir` has no `Result` form. |
| 4. The config digest claim is broader than what is captured | **Confirmed.** `config` holds the index, not the bodies. |
| 5. "Two stated differences" overclaims | **Confirmed.** The validator's field set was fetched earlier and rejects unknown keys; `std/yaml.ail:10` states the JSON-representability limit. Its `compatibility` check was not fetched. |
| 6. Gate coverage and baseline order | **Confirmed** (`Makefile:597`, `:613`, `:697`; §4 of v0.2). |

## Disposition — 2026-10-03

Addressed in ADR-001 v0.3.

| Finding | Disposition |
| --- | --- |
| 1 | Accepted. D7 returns to the bare relative root, D10's directory line is `.motoko/skills/<name>`, and A9 requires `ReadFile` on a bundled file to succeed. Ruling 2 is replaced and needs the operator again. |
| 2 | Accepted. D2 withdraws the claim; the host check and the extension land in one change; and the extension fails safe where the key is ignored, which A4 tests. With no version change there is no dependency to lean on. |
| 3 | Accepted. D1's stated limit now covers a directory that cannot be listed, with or without a race. A `Result` form of `listDir` is noted as an upstream request. |
| 4 | Accepted. D4 says the digest covers the index only; A2 splits description from body. |
| 5 | Accepted. D3 states what is and is not validated instead of counting differences; D9 carries the JSON-representability limit; A3 adds a control with a malformed optional field. |
| 6 | Accepted. §4 gains a step 0 baseline before any production change and repairs the existing lists before adding to them; A7 names `driver_plus_herdr` and requires no new failure in a gate that is already red. |
