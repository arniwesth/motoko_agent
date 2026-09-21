# PLAN-004 v2 and its v2 graph — adversarial review (`PREV`)

Date: 2026-09-16. Branch: `arniwesth/013-plan003-and-herdr`. HEAD at the start of the review:
`51978b56c48438871de1c8b19a9f347a62094d3c` (PLAN-004 v2, `PSYNC`'s commit). **HEAD moved during the
review** to `5bc6d5027f0acfcebdbd97b26ba267bb65388064` — `ADR-004 D8 P0: preserve the prototypes, ignore the
corpus` (`PRESERVE·a1`; `.gitignore` +8, `evidence/adr004-p0/MANIFEST.sha256` +176). The three reviewed files
are byte-identical at both commits (`git diff --stat 51978b5 5bc6d50 -- <plan> <ADR> <evidence graph>` →
empty; plan SHA-256 `65164b5dd8c8fd8df226c0e6fa7d4f18d0aeff1ee2a43f297c259d79c3ac7d00` at `51978b5`, at
`5bc6d50` and in the worktree), so this review holds for both. Code pin: `3920814`;
`git diff 3920814 5bc6d50 --stat -- src/ scripts/dst/ Makefile tools/ packages/` → **empty**.

**Reviewer: claude (Claude Fable 5.1), not Codex.** Codex is not available in this container. Per PLAN-004
§2 `PREV` and the delegate order `mot-dlg-1789544215759`, the round runs with claude and the file is named
`-claude-` so the provenance stays honest. The v01 graph's `PREV` receipt note (2026-09-16T07:36:51Z)
already records "Codex-unavailable-so-claude-per-orders".

Subject: `PLAN-004-implement-adr-004.md` **v2** (`P:<line>` below) and `.dagr/run-plan004-v2.json`
(`G2:<id>`; run `run-plan004-v02`, 40 tasks; SHA-256 `34e83f6df545fe9bf019658978cb914b6016ae0d6dbcb9ec43103728994261f7`,
**equal** to `evidence/plan004-v2/run-plan004-v2.json`). Inputs read in full: `ADR-004-journal-as-evaluation-source.md`
v5 Accepted (`ADR:<line>`), `REVIEW-adr004-v5-verdicts-claude.md` (`V5R:<line>`; SHA-256 `b53604f8a769097e…`),
`REVIEW-plan004-v1-verdicts-codex.md`, `REVIEW-plan004-v1.1-delta-verdicts-codex.md`,
`REVIEW-plan004-v1.2-delta-verdicts-codex.md` (SHA-256 `943a59d264ef770d…`), `BRIEF-plan004-v2-review.md`,
`.dagr/run-plan004.json` (`G1:<id>`, run `run-plan004-v01`, the `V5G` directive at 2026-09-16T06:30:00Z),
the producer run file `.dagr/run-w1-p30-1789501909410.json` (identities only), and **PLAN-004 v1.2**
(`v1.2:<line>`) — the plan file was first committed at `51978b5`, so v1.2 is not in git; a `cat -n` capture of
it from the `PSYNC` session was recovered, its line prefixes stripped, and its SHA-256
(`7d272108ab7fb0e2cf8481b878115b0bab2b78d0802774ed2c7a86440268c4ff`) **equals** the plan digest in
`PLAN1G·a1`'s receipt (`G1:PLAN1G`), so it is the accepted v1.2 text.

Method: `dagr check --strict --json` on the v2 file and its evidence copy; `dagr view --snapshot`; a Python
diff of every task's kind/owner/project/title/criteria/deps between v01 and v2 with the supersede map applied;
`git show 3920814:<path>` for every coordinate the plan names in §0.1–0.3, §0.9, P1.1–P1.9a, P3.2 and its
cross-references; the installed AILANG source at `/home/motoko/.local/share/ailang` (`ae36986`) for P1.9a's
coordinates; `git diff -U0 d5edebf 3920814` for the `derive.py` hunk; `sha256sum` for every digest quoted.
**Not done:** `make dst`, any replay, prototype, profiling, `ailang check`/`run`, commit, pane or agent
operation; no edit to either graph or to any file but this one. No corpus content was opened; the review holds
counts, digests, indices and identities only. Evidence directory:
`/tmp/claude-1001/-workspaces-motoko-agent/663a4725-b99c-424e-b1fd-43b09f6d4346/scratchpad/prev-v2/`
(`dagr-check-v2.json`, `dagr-view-v2.txt`, `graph_diff.txt`, `plan-v1.2.md`).

## Overall verdict — ACCEPT WITH CORRECTIONS

Every one of v1.2's thirty ⟨v5⟩ sites is replaced by the v5 decision §5 names for it (§1); every D1–D8
decision is carried, including the six V5R corrections and the `V5G` ruling on M15 (§2); the nine new ids
follow §9's rule and the kept ids are defensible (§3); every code coordinate resolves at `3920814` except
three in P1.6 inherited from v1.2 (§4); the v2 graph is strict-clean, byte-equal to its evidence copy,
carries exactly one task per part with deps equal to §1's skeleton, and is usable as a fresh session's
`dagr_plan` (§8). What remains is textual and administrative: three wrong line numbers, one attempt field
that disagrees between the two operator graphs, a doubled assignment of M15's near-miss rows, three small
matrix gaps, two wording slips about what v2 carries from v01, and the §0.7 commit rule not yet applied to the
v1–v1.2 review documents. None changes a mechanism, a dependency, a criterion's meaning or a gate; each is
listed under "Required changes for v2.1" with its replacement. `PLAN2G` may be settled once they are applied
and named in `PSYNC·a1`'s receipt (§0.10 (a)3), the graph re-checked strict and the evidence copy re-synced.

## §1 — ⟨v5⟩ closure

`grep -c "⟨v5⟩"` on v2 → **1** (`P:1083`, §9's history sentence). v1.2 held **30** marker lines
(`grep -c` on the recovered copy → 30), exactly the sites §9 enumerates (`P:1082–1085`). One row per site:

| v1.2 site | v2 replacement | Status |
|---|---|---|
| header `v1.2:27` ("where this plan cannot know v5's answer it says ⟨v5⟩") | `P:9–11`: v2 is `PSYNC`'s document, every marker replaced | REPLACED |
| §0.9 park row `v1.2:119` | `P:128`: withdrawn; `Parked` a cutoff before the call-free stop-class call k, `EndSuspended(k−1)` (C1); wake-opened run `Refused(ContinuationStart)`; stray `wake` `MalformedEntry` at `journal.ail:1603–1614` — equals `ADR:702,716,720` | REPLACED |
| §2 `V5` `v1.2:279` | `P:293–308`: the nine changes, `V5R` verdict, C1–C6, `V5G` ruling | REPLACED |
| §2 `PSYNC` `v1.2:295` | `P:312–323` | REPLACED |
| M1 park/wake `v1.2:357` | `P:382` (M1: stray `wake` → `MalformedEntry`), `P:383` (M2: wake-opened → `ContinuationStart`, `SeedParked`), `P:384` (M3: `Parked` cutoff) — `ADR:1526–1527` names exactly these moves | REPLACED |
| M15 park/wake `v1.2:393` | `P:425`: inapplicable, `ADR:1450–1451` | REPLACED |
| P1.2a decoders `v1.2:407` | `P:439–443`: copies, not imports, span hash recorded, drift reported — `ADR:1201–1208` | REPLACED |
| P1.3 item 1 `v1.2:420` | `P:465–470`: six-shape classification, four cutoffs, `HybridPredicate` — `ADR:634–671,698–722` | REPLACED |
| P1.3 item 2 `v1.2:421` | `P:471–475`: the T0 settings values — `ADR:608–624` | REPLACED |
| P1.4b closure `v1.2:459` | `P:513–524`: reviewed starting set incl. §3.8's transitive names (C5) — `ADR:1136–1167` | REPLACED |
| P1.5 files `v1.2:483` | `P:548–550`: env and the one `FsFile` as D2 builds them — `ADR:766–772` | REPLACED |
| P1.5 empty arms `v1.2:486` | `P:552–561`: the harness's exhausted record, the `ToolFailed` arm mirror, k = the seam's own `ProviderIdentity` count (C2) — `ADR:802–844` | REPLACED |
| P1.6 `abi_version` `v1.2:510` | `P:585`: no fresh interface recomputation; D5 adopts P1.9a's contract — `ADR:1221–1236` | REPLACED |
| P1.7a locations `v1.2:532` | `P:607–611`: four-variant `Location`, `AdmissionCheck(A1..A9, A9b, location)` — `ADR:1051–1057` | REPLACED |
| P1.7b bridge `v1.2:545` | `P:626–633`: `NoReplay`, `replay_metadata_of`, `2N + 1` / `2N`, retry 0, thirteen census rows — `ADR:984–1025` | REPLACED |
| P1.8 policy `v1.2:552` | `P:640–644`: v5 D6 verbatim — `ADR:1304–1326` | REPLACED |
| P1.9a lock refusal `v1.2:617` | `P:704–705`: "v5 D3 and D5 confirm" — `ADR:932,1232–1233` | REPLACED |
| P1.9b K3 `v1.2:629` | `P:715–720`: `witness_C` from C's run, then the three counts — `ADR:1039` | REPLACED |
| P3.2 control `v1.2:710` | `P:816–829`: same-basis primary, historical optional — `ADR:1249–1264,1405–1410` | REPLACED |
| §5 heading `v1.2:776` | `P:889` | REPLACED |
| §5 rows D8, 1–8, park/decoders `v1.2:781–790` (ten rows) | `P:894–903`: each row names the answering decision and where v2 applies it | REPLACED (10) |

No site is PARTIAL or LEFT OPEN. The only ⟨v5⟩ string left in the repository's plan-side artifacts is §9's;
the v2 graph's `V5` and `PSYNC` criteria were reworded to "v1.2's v5 questions"/"v1.2 marker" (`G2:V5`,
`G2:PSYNC`, `graph_diff.txt`), so a grep on the graph file also finds none.

## §2 — Fidelity to ADR-004 v5

| Decision | Where v2 carries it | Status |
|---|---|---|
| **D1** | P1.2a/P1.2b/P1.3 and M1–M5 (`P:382–386,434–478`): selector, seed with the leading user entry, ordered association, `thinking.tool_calls` = call count, canonical-JSON arguments, the six-shape procedure, all eighteen cutoffs of `ADR:698–712` present in M3 (`P:384`), the seven refusals of `ADR:714–722` across M1/M2/M4, the settings table values (`P:471–475` = `ADR:608–624`), both model names with the pinned `provider_api_model` copy, `expected.decisions`. `Parked` carries C1's wording (`P:128,384,468–469`). | CARRIED |
| **D2** | P1.1's five joins (`P:342–357` = `ADR:782–796`); P1.5's world and seams with the exact records and C2's count (`P:545–565` = `ADR:763–853`); P1.6's run, `step_budget = N`, `/4` program, `driver_only_manifest` with gathered provenance (`P:567–599` = `ADR:866–917`); §0.4 no schema/`Ports`/projection change (`P:75–76` = `ADR:1480–1482`). | CARRIED |
| **D3** | A1–A4 and `Location` (P1.7a), A7/A8 with the three-column env table and the thirteen-row census (P1.7b, `P:621–633` = `ADR:964–1025`), A5/A6/A9/A9b (P1.6), K0 and the refusals (P1.9a), K1–K7 and the typed verdict (P1.9b, `P:725–728` = `ADR:1056–1061`), comparands = the entry (`P:724–725` = `ADR:1045–1046`), the envelope's residual gap and marker N/A (`P:689–692,731–732` = `ADR:1234–1242`). | CARRIED |
| **D4** | P2.2's measurement scope with the fold inside the profiled process, warm-up, secondary metrics, prototype numbers excluded (`P:795–806` = `ADR:1109`). | CARRIED |
| **D5** | P1.4b's closure as the reviewed starting set with the C5 names and the C6 lexer (`P:488–541` = `ADR:1132–1197`); P1.9a's assembly, execution provenance and effective lock (`P:661–711` = `ADR:1216–1236`); E in `../motoko_agent-eval` (`P:77–84`); P3.2's same-basis control with the C3 span rule (`P:816–829` = `ADR:1249–1264`); a repin is a basis change (`P:853–854` = `ADR:1271–1276`). | CARRIED |
| **D6** | `PRESERVE`'s ignore-first rule, P1.8's entry layout and scan policy, §0.6 exposure rows, §0.11 retention **ruled** by `QRET·a1` (`P:177–185,234–239` = `ADR:1284–1285`), `SCAN0` as a heuristic that admits nothing (`P:276`), P4 held-out (`P:867–873` = `ADR:1350–1355`). | CARRIED |
| **D7** | P6 canceled, T1 needs its own plan (`P:883–885` = `ADR:1362`); the omissions travel in the envelope (P1.9b). | CARRIED |
| **D8** | P0→P1→P2→P3→P4/P5 (`P:191–199`); the P1 test contract restated clause by clause with the `V5G` ruling (`P:398–411` = `ADR:1421–1456`); P2's guard defaults and ≤100-call calibration (`P:763–806` = `ADR:1393–1400`); P3's gate with the same-basis control and pinned counts incl. decisions (`P:814–865` = `ADR:1401–1415`); `P1R-v2` checks the contract's coverage (`P:738–744`). | CARRIED |

**What v2 adds that v5 does not itself license**, all PLAN-004's and marked or bounded: the evaluator paths
and E worktree (`P:77`, "a plan default; overridable in review"); P2.1's margin 2 GiB, poll 1 s, unlimited-max
refusal and the 12 GiB preflight (`P:765–766`, "overridable in review"; `P:904`, "overridable in `PREV`" —
**accepted as written by this review**); P2.2's ≥ 20-call floor (`P:792`); P3.2's one calibrated escalation to
≤ 150 calls (`P:838–843`; consistent with `ADR:1414` "the segment length is fixed here, by calibration" and
accepted at `REV2·a2`); §0.10's review transaction; P3.3's repin needing an operator directive (`P:853–854`,
stricter than `ADR:1414–1415`). Nothing v2 decides that D8 leaves to a part is left unmarked.

## §3 — The id supersede map

`G2.supersedes.tasks` holds exactly the nine pairs of `P:1123–1133`; each renamed task carries `supersedes`
equal to the map and a `note` naming the v1.2 id (`graph_diff.txt`: "renamed tasks have note+supersedes:
True"; "supersedes field equals map: True"); the opening `note` event lists all nine. `dagr view --snapshot`
renders the nine `-v2` ids under P1/P3. Deps equal §1's skeleton for all 40 tasks with a renamed predecessor
treated as the same predecessor (`graph_diff.txt`: "deps vs §1 skeleton mismatches: none"; "dangling deps: []").

The Python diff of v01 → v2 (ids mapped) shows **every renamed task changed title and criteria** and, of the
kept ids, only `V5` (marker wording), `PSYNC` (the `V5G`-directed status flip and the map's three homes),
`P1.5` and `P1G` changed a criteria string; every other kept id is identical in kind, owner, project, title,
criteria and deps (`graph_diff.txt`).

| id | Ruling |
|---|---|
| `P1.2a-v2`, `P1.2b-v2`, `P1.3-v2`, `P1.7a-v2`, `P1.7b-v2`, `P1.9b-v2`, `P1R-v2`, `P3.2-v2`, `P3.3-v2` | **Rename justified**: each adds a case, a type, a comparator, a route or a review clause — compare `v1.2:357–369` with `P:382–396` (M1–M5, M11, M14), `v1.2:526–548,625–653,708–745` with `P:601–636,713–757,814–857`. |
| `P1.5` kept | **Accepted.** v1.2 already required complete failure records on both empty arms, no live effect, correlation mismatch and exactly-one-append (`v1.2:364,479–491`); v2 pins their bytes and C2's count (`P:389,552–564`). Values, not cases. |
| `P1.4b` kept | **Accepted.** v5 adopted P1.4b's contract (`ADR:1179`); C5 changes the `--symbols` input, C6 was already P1.4b's lexer (`v1.2:459`; `P:489–491,513–524`). |
| `P1.6` kept | **Accepted.** A9b adopts P1.6's table by reference (`ADR:949`, `V5R:144`); the `abi_version` row's answer is a value (`P:585`). |
| `P1.8`, `P1.9a`, `P1.4a` kept | **Accepted.** D6 confirms P1.8 verbatim (`ADR:1304–1326`); D5 adopts P1.9a's provenance contract (`ADR:1223`); P1.4a unchanged. |
| `P1G` kept | **Accepted.** An operator gate; its added words ("the closure review included", `P1R-v2`) name what `P1R-v2` now delivers. |
| `PSYNC` kept | **Accepted.** Its criteria grew by the `V5G` directive ("status flip tasked to PSYNC", `G1` event 2026-09-16T06:30:00Z), not by v5; it is settled in v01. |

One inconsistency of wording, not of substance: `P:315` says "a part whose scope, deps **or criteria**
changed got a new id", while §9 (`P:1116–1119`) states the rule actually applied ("what it must build or
test … kept when only values, coordinates or the marker changed"), and `P1.5`/`P1G` did change their criteria
strings. Correction 3.

## §4 — Code facts at `3920814` (= HEAD for code)

Everything named below was read with `git show 3920814:<path>`; line counts `wc -l`: `stub_step.ail` 915,
`session.ail` 6320, `ledger_parity_dst.ail` 642, `ports.ail` 2885 (`P:353` ✓).

| Plan claim | Finding |
|---|---|
| §0.9 table `P:124–130` | `stub_step.ail:69` sum ends in a `--` comment; `:478` `recording_model_step` **private**; `:635` `recording_ports` **exported**; `:561` `provider_calls_in` private; `:44` three import statements on one line; `:28–33` a multi-line import; `:488–490` the `[] =>` exhausted arm. `ports.ail:1723` `world_tool`, `:1827` `record_interaction`, `:2056` `recording_tool`, `:2133` `tool_outcome_record` (private — the v1.2 `:2126` is corrected ✓), `:2507`, `:2522`, `:2577` the three encoders; `d5edebf` positions 1677 / 2010 / 2087 (`git show d5edebf:src/core/ports.ail`) ✓. `session.ail:195` one-line import; `:272` `provider_api_model`, `:293` its brace; `:1532` `ported_provider` starts, `:1545` the `GeneratedWorld` arm, `:1546` `}`; `:2760`, `:3255`, `:4423` ✓. `ledger_parity_dst.ail:73` import, `:428` `frame_ordinal0`, `:435` `Ported(_)` arm, `:436` `}` ✓. `journal.ail:1179–1180` `ParkEntry`/`WakeEntry`; `:1253–1256` `all_entry_types` with twelve names; `:1603–1614` the `wake` arm; `:1679` `fold_journal` ✓. `derive.py` hunk: `git diff -U0 d5edebf 3920814 -- tools/driver_leaf_inventory/derive.py` → `@@ -644,0 +645,10 @@ TREE_MUTANTS`, i.e. `:645–654` as `P:129` says ✓; `BRIDGE_SPAN :154` ✓. |
| §0.1 `Makefile:697` | `DST_KNOWN_RED := driver_plus_herdr herdr_graded` ✓; `:350` `ledger_parity:`, `:1099` `strict_replay:`, `:1516` `event_vocabulary:`, `:3071` `anchors:`, `:3081–3082` `ext_call_inventory` runs `derive.py` without `--json`, `:3095` `driver_leaf_inventory:` ✓. |
| §0.3 anchors `P:70–73` | `anchors.sh:593` pins `stub_step.ail:203` `now()`; `:614–617` pin `session.ail` 1471/1730/1842/4302/4523 and `tool_phase.ail:484` `clock_now` ✓; `tool_phase.ail:484` is `ports.clock_now(handle_world)` ✓. |
| P1.1 five joins `P:344–350` | The five sites are the single-line structures the joins need (above); the bridge span `1085–1474` contains neither 195 nor 1545 (`V5R:177` re-verified the same) ✓. |
| P1.2b `session.ail:4271`, `:5531–5536`, `:5577` | `C2Seed … SeedParked`, `c2_state_from_parked`, the parked `run_v2_traced_from_seed` call ✓. |
| P1.4b examples `P:493–503` | `ports.ail:12–14` `as List`/`as Trace`; `fs_node.ail:69–70` `as List`; `ports.ail:60–67` multi-line import; `types.ail:62–70`, `:88–101` non-braced unions, `:81–86` `deriving (Eq)`; `dst_interaction.ail:59–95` union ✓. |
| P1.6 table `P:583–592` | `dst_profile.ail:1535` `validate_manifest`, `:1582–1588` `replay_metadata_of`; `dst_driver_only.ail:1065` `scan_roots: ["src", "packages"]`, `:1097–1123` `driver_only_manifest`; `strict_replay_dst.ail:631–633` `discovered_manifest` literals; `driver_leaf_inventory/derive.py:187–192` `SCAN_FILES`; `ailang.lock:71–77` the `sunholo/motoko_ext_abi` block with the absolute `path` at `:75`; `ailang.toml:1–3` ✓. **Three do not resolve:** `tools/profile_definition/check_fixtures.py:35–37` is the docstring's close and `import json`; `derive()` — which runs `tools/ext_call_inventory/derive.py --json` — is `:54–59`. `check_fixtures.py:25` is a docstring line ("EMPTY at HEAD"); the constant naming `scripts/dst/profile_definition_dst.ail` is `FIXTURE` at `:44`. `tools/ext_call_inventory/derive.py:480` is `--repo`; the `--roots` default `src,packages` is `:481`. All three are inherited verbatim from v1.2 (`v1.2:511–512,1010–1011`; the v1.2 review cited `:54–59`, `REVIEW-plan004-v1.2:69`). Correction 1. |
| P1.9a installed source `P:663–692` | `/home/motoko/.local/share/ailang` is at `ae36986` and `ailang --version` → `AILANG v0.33.0`. `loader.go:145` `pkg/`, `:157`, `:158` `std/`, `:177` embedded fallback, `:185`, `:292` `injectEntryPreludeImports`, `:320` `resolvePath`, `:468–475` the `DEBUG_LOADER=1` trace on failure; `pipeline_module.go:136` and `:506` MOD011, `:215–220` `if !cfg.NoCache`, `:267` SKIP, `:282` HIT-but-load-failed, `:287` MISS, `:405` `_ = cacheStore.Save()`, `:408` Summary; `cache_store.go:61` `NewCacheStore`, `:105` the manifest write; `stdlib_resolver.go:187` `Checking:`, `:274` `Search paths initialized`; `pkg/loader.go:44` `ResolveImport`, `:126–136` `packageDir`; `main_run_exec.go:239–240` `DebugCompile`, `AILANG_NO_CACHE` ✓. `ailang lock --help` prints "Resolve dependencies and generate ailang.lock" and takes no verify flag, so `P:585`'s "no verify mode" holds. |
| P3.2 `P:817–819` | `git show --stat de4b4f5` → `src/core/phase_vocab.ail | 17 ++++++++++-------` (10+/7−), one file; `git merge-base --is-ancestor de4b4f5 3920814` true; `a6abda4` and `686da16` are commits ✓. The two digests and their span rule are `V5R:171`'s, quoted with the rule (C3) ✓. |
| §0.9 `P:130` ignore rule | `git check-ignore .motoko/eval-corpus/example` exits **1** at `3920814`, `988a863` and `51978b5` (`.gitignore` there has no such line) — as stated — and exits **0** at `5bc6d50` (`.gitignore:43`, `PRESERVE`'s commit). Not an error; §8's "reconcile from `git log` first" covers it. |
| Digests quoted `P:17,246` | `sha256sum REVIEW-adr004-v5-verdicts-claude.md` → `b53604f8…`; `REVIEW-plan004-v1.2-delta-verdicts-codex.md` → `943a59d2…`; the recovered v1.2 → `7d272108…` ✓. |

## §5 — Per-part verdicts

ACCEPT WITH CORRECTIONS means the part may be delegated as one commit after the named text change; nothing
below is RETURN. Every part names one commit for one delegate; §0.8's red-first/mutation rule binds all
(`P:112–115`), and the -v2 graph criteria repeat it while the kept parts' criteria do not (`G2` criteria
inventory: `P1.2a-v2`, `P1.2b-v2`, `P1.3-v2`, `P1.9b-v2` carry it; `P1.4a`, `P1.4b`, `P1.5`, `P1.6`,
`P1.7a-v2`, `P1.7b-v2`, `P1.8`, `P1.9a` do not) — harmless, since §0.8 governs, noted under correction 8.

| Part | Verdict | Review |
|---|---|---|
| `P1.2a-v2` | **ACCEPT WITH CORRECTIONS** | Reader, copies with span hashes, fold equality against `fold_journal :1679` and `gen_fixtures.py`, M1 with entry positions and twins (`P:434–450`; `G2` criteria). One deliverable is mis-assigned: "M15's rows for M1" (`P:446`, `G2:P1.2a-v2`) expect `AdmissionCheck(A3)` at `Call(k+1)` (`P:415–418`), a check P1.7a-v2 lands four parts later; P1.7a-v2 also claims "M15's admission rows" (`P:613`, `G2:P1.7a-v2`). Split the row's obligations (correction 5). |
| `P1.2b-v2` | **ACCEPT WITH CORRECTIONS** | Excerpt reader, ordered association, canonical JSON, both `ContinuationStart` shapes with the `SeedParked` coordinates verified (`P:452–461`). Same M15 split (correction 5). |
| `P1.3-v2` | **ACCEPT** | Six shapes, all eighteen cutoffs, `HybridPredicate`, the settings table, `provider_api_model :272–293` copy, `expected.decisions` (`P:463–478`); M3/M4/M5 assert selector, N, end. "`ProfileMissed` refused by the witness" (`P:473`) is P1.7b-v2's assertion; say so (folded into correction 5). |
| `P1.4a` | **ACCEPT** (v1.2 verdict stands) | Unchanged (`graph_diff.txt`). |
| `P1.4b` | **ACCEPT** (stands) | C5's list and C6's lexer are in the text (`P:489–526`); the 22-item self-test list (`P:532–539`) is v5's (`ADR:1194–1197`) plus v1.2's corrections. |
| `P1.5` | **ACCEPT** (stands) | Exact records, C2's count, structurally equal prefix, the `FsFile` key (`P:545–565`); every exported name it needs exists at the cited lines (§4). |
| `P1.6` | **ACCEPT WITH CORRECTIONS** | Contract stands; three coordinates wrong (correction 1); add an A9 known-failing case (correction 6a). |
| `P1.7a-v2` | **ACCEPT** | A1 against the snapshot's recorded `digest_after`, typed `Location`, `AdmissionCheck` with A9b, A2 reused as K7 (`P:601–615`). |
| `P1.7b-v2` | **ACCEPT** | The witness fields and env table equal `ADR:951–977` key for key; the bridge call equals `ADR:947`; the thirteen census rows equal `ADR:1011–1025` (`P:617–636`). |
| `P1.8` | **ACCEPT** (stands) | D6 verbatim (`P:638–650`). |
| `P1.9a` | **ACCEPT** (stands) | Every installed-source coordinate resolves (§4); the effective-lock rule is D5's (`ADR:1230–1233`). |
| `P1.9b-v2` | **ACCEPT** | K3 two-step, K4 census comparand, the verdict type equals `ADR:1059–1061`, no score after any K failure, `regression_replay_findings` diagnostic only (`P:713–734`). Add the returned-value/count clauses of correction 6 where M14 is landed. |
| `P1R-v2` | **ACCEPT** | Coverage clause by clause, closure review, symbol inventory, §0.10 (b) on RETURN (`P:738–751`); owner `codex` with the claude fallback stated in the note (`G2:P1R-v2`). |
| `P1G` | **ACCEPT** (stands) | Latest-attempt rule, `P1R-v2` accepting incl. the closure review, E pinned after the collision check (`P:753–757`). |
| `P3.2-v2` | **ACCEPT** | (i)–(iv), the provisional tolerance, one calibrated escalation, the historical route by directive only (`P:814–845`); `de4b4f5` facts verified (§4). |
| `P3.3-v2` | **ACCEPT** | Guard-wrapped, pins incl. decisions, fail-closed arms, repin by directive, outside `make dst` (`P:847–857`). |
| `P1.1`, `P1.1R`, `P1.1G`, `P2.1`, `P2.2`, `P3.1`, `P3G`, `P4`, `P5`, `P6`, `QRET`, `PRESERVE`, `SWEEP`, `SCAN0`, `PLANW`, `REV1`, `REV2`, `PLAN1G`, `V5`, `V5R`, `V5G` | v1.2 / v1 verdicts **stand** | Identical in the graph (`graph_diff.txt`); text changes are status only. `PRESERVE` has since landed (`5bc6d50`; `G1:PRESERVE` `done`); the v01 graph shows `SWEEP` `queued` with no attempt, so `P:26,225`'s "in progress" is not a recorded attempt (§9). |
| `PSYNC`, `PREV`, `PLAN2G` | **ACCEPT WITH CORRECTIONS** | The fresh-session design is sound (§8); the `PSYNC·a1` mirror's `model` field disagrees with v01 (correction 2). |

## §6 — The D8 matrix against the revised contract

Clause by clause (`ADR:1426–1439`): per refusal family a refused case at a pinned position plus a twin — M1
(4), M2 (6), M4 (`HybridPredicate` true/false), M12 (`ScanRefusal`), M13 (6) ✓ with the header's "each
refused/divergent + clean twin" (`P:380`); per cutoff — M3 names all **18** of `ADR:698–712` ✓; per A1–A9,
A9b and K1–K7 a failing case with first finding and location plus a twin — A1–A4 (M10), A5/A6/A9b (M9),
A7/A8 (M11), K0 (M13), K1–K7 (M14) ✓; one per `ReplayMismatch` variant — seven named, `ProgramExhausted` and
`UnusedInteraction` by direct log-length mutation, the marker case's actual first finding ✓; per seam arm —
M8's two arms with the complete record and no live effect ✓; witness under/over-count and prepared ≠ recorded
(M11, M14) ✓; per census row zero-by-name plus a non-zero twin (M11) ✓; one vacuous family (M11) ✓; M15
carries every inapplicable row's reason and the `V5G` ruling (`P:398–432`). Expected values frozen in
`MATRIX.expected.tsv`, observed only in `MATRIX.tsv` (`P:367–373`).

Gaps, none blocking:
1. **A9** has no named known-failing case for the round trip itself: M9's only A9 case is "blank field →
   `validate_manifest`" (`P:390`). Add one failing `validate_program` / `world_state_of` /
   `reconstitution_balance` case with its pinned `Location` (P1.6).
2. **M8's returned value.** The contract asks each seam arm to assert "the complete record, the returned value
   and the absence of any live effect" (`ADR:1433–1434`). M8 names the provider's non-retryable `Err` but not
   the tool arm's returned `{ outcome: o, next_state }` with code `replay_unrecorded_invocation` and the clock
   unadvanced, which P1.5's text does state (`P:559–561`). Name it in the row.
3. **Exact-count clauses.** A2's "exact count" has a case (chain and count, `P:604`); A3's `msg_count`/count and
   A4's count mismatch (`ADR:942–943`) have none in M10 (`P:391`). One row each.

## §7 — Standing rules and safety

Sweep (`P:59–63`), memory with the guard's `flock` as the one enforceable exclusivity rule (`P:64–69`),
privacy and exposure rows (`P:85–95`), the commit rule with `PSYNC`'s one-commit exception (`P:96–106`; `git
show --stat 51978b5` shows exactly the five paths §2 names), tests and red-first (`P:107–115`), the review
transaction (`P:132–176`), and the `QRET` ruling copied into §6 (`P:177–185,920–925`) are all present and
match the v01 directive text (`G1:QRET`). `SWEEP` is heavy but not a guarded run, so its exclusivity against a
guarded replay remains a coordination rule, as the v1 review noted and v1.2 accepted (`REVIEW-plan004-v1:121`);
no change. **One rule is not yet applied:** §0.7 says review documents are "committed by the orchestrator with
the next plan or ADR commit" (`P:99–100`), yet after two later commits (`51978b5`, `5bc6d50`)
`REVIEW-plan004-v1-verdicts-codex.md`, `-v1.1-`, `-v1.2-` and `BRIEF-plan004-v1/-v1.1/-v1.2/-v2-review.md` are
untracked (`git status --porcelain` → `??`), while the plan's header, §9 and cross-references cite them.
Correction 7.

## §8 — The v2 graph

`dagr check .dagr/run-plan004-v2.json --strict --json` → `[]`, exit 0 (dagr 0.3.1); the same on the
evidence copy; SHA-256 equal (`34e83f6d…`). `dagr view --snapshot` renders 40 tasks under the seven projects,
`PRESERVE` and `SWEEP` ready, `PLAN2G` `waits PSYNC`, `P1.1` `waits SWEEP`, every other P1 part waiting on
`PLAN2G` or its predecessor, `P6` canceled (`dagr-view-v2.txt`). Inventory (`graph_diff.txt`): states done 9 /
review 1 / queued 29 / canceled 1 (= `P:915–917`); kinds and owners — impl·claude 17, review·codex 6,
test·claude 5, gate·operator 5, docs·claude 3, question·operator 1, gate·motoko 1 (`P1.1G`), docs·operator 1
(`P4`), impl·operator 1 (`P6`) — as §0.7 and §8 assign them; policies only on `PSYNC` and `P1.1`, each
`rounds_max 3` with pass → gate, fail → `·a2` loop-back, streak 3 → `<gate>·ask` (§0.10 (a)); no policy on
`PREV`, `P1.1R`, `P1R-v2` (§0.10 (b)); one `note` event; attempts only on the nine terminal tasks (one
`<task>·a1` each, receipt "summary of run-plan004-v01 …", actor and model from v01) and `PSYNC·a1` `queued`;
`run.orchestrator.pane` `w1:p18` as `P:995–996` says; `supersedes` present. Deps equal §1's skeleton for all
40 tasks; gate fan-ins `PLAN1G` ← 3, `V5G` ← 2, `PLAN2G` ← 2, `P1.1G` ← 2, `P1G` ← 14, `P3G` ← 3, `P2.2` ← 4.

**Usable as a fresh session's `dagr_plan`.** `plan_task_of` (`packages/motoko-ext-herdr/dagr.ail:215–246`,
unchanged since `3920814`) seeds id, title, kind, state, deps, unblock, owner, criteria, note and project, and
gives a terminal task one `operator`/`reported` attempt; `seed_tasks :256–266` skips existing ids;
`seed_from_plan :272–284` seeds nothing from an unreadable file — as `P:961–966,993` say. The file carries no
`attempt`, `event` or `policy` a producer would trip on. The extension does not gate `Delegate` on the plan's
deps (`dagr.ail` seeds deps as structure only; no refusal path reads them), so after the operator settles
`PLAN2G` in v2 the fresh session can delegate `P1.2a-v2` even though the producer's own `PLAN2G` copy stays
`queued` — the state difference §8 declares expected (`P:982–983`).

**The fresh-session / `PLAN2G` design is sound.** `PSYNC` and `PREV` settle in v01 (`G1:PSYNC` `review` with
`PSYNC·a1` `working` at `w1:p49`; `G1:PREV` opened by hand — this attempt); the fresh session mirrors both as
summary attempts in v2 before anything depends on them, delegates first to a task outside `PLAN2G`, writes the
two-file receipt, and the operator settles `PLAN2G` in v2 (`P:328–334,1023–1031`). `PLAN2G`'s criteria need
the first `Delegate`, which is why it cannot be settled in v01; every P1 part but `P1.1`/`P1.1R`/`P1.1G`
depends on it, and `P1.1`'s contract did not change (`graph_diff.txt`), so provisional work before `PLAN2G` is
what `PLAN1G` already licensed. Two findings:

- `G2:PSYNC` `PSYNC·a1` has `model: fable`; `G1:PSYNC` `PSYNC·a1` has `model: opus5` (locator `w1:p49`); the
  producer run file records the attempt with `actor: claude` and **no** model. The two operator graphs
  disagree about one attempt of the same task. Correction 2.
- `P:319` and `P:1140` say "no event, policy or attempt copied from v01", but the `PSYNC` and `P1.1` author
  policies are v01's verbatim and `PSYNC·a1` is the open author attempt mirrored `queued` — both correct under
  §0.10 (a)1 and `P:1140`'s own next clause. `P:25–26,37,970` and the graph's note say v01 "holds the settled
  history **through** `PLAN2G`" while `PLAN2G` itself is settled in v2 (`P:331–334`). Correction 4.

## §9 — Claim audit

| Claim | Finding |
|---|---|
| `P:583–592` P1.6 table: `check_fixtures.py:35–37` (`derive()`), `:25` (the fixture literals), `tools/ext_call_inventory/derive.py:480` (`--roots`); repeated at `P:1218–1219` | `:54–59`, `:44`, `:481` (§4). Inherited from `v1.2:511–512,1010–1011`. |
| `G2:PSYNC` attempt `model: fable` vs `G1:PSYNC` `model: opus5` | Producer file records no model; one graph is wrong (§8). |
| `P:315` "scope, deps or criteria changed got a new id" | `P1.5` and `P1G` kept ids with changed criteria strings; §9's rule (`P:1116–1119`) is the one applied (§3). |
| `P:319,1140` "no … policy or attempt copied from v01" | `PSYNC`/`P1.1` policies and `PSYNC·a1` are carried by design (§8). |
| `P:25–26,37,970`, `G2` note: v01 "the record through `PLAN2G`" | `PLAN2G` is settled in v2 (`P:331–334`); "up to" (§8). |
| `P:26,225,917` "`SWEEP` was in progress in the v1.2 session" | `G1:SWEEP` is `queued` with no attempt; no `attempt_started` event names `SWEEP`. Whatever ran was not recorded as an attempt; the fresh session must not take the sentence as a settlement (§8's "reconcile first" already says so). |
| `P:27,185,239` "`PRESERVE` … remain(s) ready" | True at `988a863`; `PRESERVE·a1` is `done` at `5bc6d50` (`G1` events 07:43:52Z). History, not error. |
| `P:130` ignore rule "still exits 1 at `988a863`" | True there and at `51978b5`; exits 0 at `5bc6d50` (§4). |
| `G2:V5` criteria "Two commits by explicit path" vs `P:104` "three" | Three commits are the fact (`9615bb4`, `21c1728`, `988a863`); the mirrored criteria string is v01's, already edited for the marker. Cosmetic. |
| `ADR:4` "implemented by PLAN-004 v2" | v2 is not yet accepted at this writing; "to be implemented by" is exact. Cosmetic; the ADR is not under review. |
| `P:8` "All three rounds Codex `gpt-5.6-sol` at HEAD `3920814`" | The three review headers say HEAD `3920814`; `G1` models `sol5.6·high` ✓. |
| `P:17,246,1082` digests and dates | `b53604f8…`, `943a59d2…`, `7d272108…` verified; `V5G` 06:30:00Z and `PLAN1G`/`QRET` 20:00:11Z equal `G1`'s directive events ✓. |
| `P:201–202,945–955` sums | 1½ + ½–1 + 4–6 + 18½–22 + 2½–3 + 3–4 = 30–37½; P1's fifteen part estimates sum to 18½–22; +1 escalation = 38½ ✓. |
| `P:1083` "thirty lines" | 30 ✓ (§1). |
| Everything in §0.9's table, P1.1, P1.2b, P1.4b, P1.9a, P3.2 | Resolves (§4). |

## Required changes for v2.1

Each is a text or field edit; none touches a mechanism, a dependency, a gate's meaning or a part's scope.
Apply them, re-run `dagr check .dagr/run-plan004-v2.json --strict --json` → `[]`, re-copy the graph to
`evidence/plan004-v2/` (byte-equal), and name each in `PSYNC·a1`'s receipt with this review's SHA-256; then
`PLAN2G` may be settled and the fresh session started.

1. **P1.6 coordinates** (`P:586–587`, `P:1218–1219`): `check_fixtures.py:35–37` → `:54–59` (`derive()` runs
   `tools/ext_call_inventory/derive.py --json`); `check_fixtures.py:25` → `:44` (`FIXTURE`, the pinned record
   `scripts/dst/profile_definition_dst.ail`); `tools/ext_call_inventory/derive.py:480` → `:481` (`--roots`).
2. **`PSYNC·a1`'s `model`** in `.dagr/run-plan004-v2.json`: make it equal v01's record, or correct v01 by a
   settlement-level edit of the running session if `fable` is the truth (the producer file names none); state
   which in the receipt.
3. **§2 `PSYNC` wording** (`P:315`): replace "a part whose scope, deps or criteria changed got a new id" with
   §9's rule — "a part got a new id when v5 changed what it must build or test; a criteria string that only
   pins values keeps the id" — so `P1.5`/`P1G` are consistent with the sentence.
4. **What v2 carries from v01** (`P:319`, `P:1140`): "no event, policy or attempt copied from v01 **for the
   nine terminal tasks**; the `PSYNC` and `P1.1` author policies and the open `PSYNC·a1` attempt are carried."
   `P:25–26`, `P:37`, `P:970` and `G2`'s note event: "the record **up to** `PLAN2G`" (`PLAN2G` is settled in v2).
5. **M15's near-miss assignment** (`P:396,413,446,460,613,732`; `G2:P1.2a-v2`, `G2:P1.2b-v2`,
   `G2:P1.7a-v2`, `G2:P1.9b-v2`): state the split — the family's part (P1.2a-v2, P1.2b-v2, P1.9a, …) lands
   the fixture, its `MATRIX.expected.tsv` row and the assertion that the input passes its own family's refusal;
   the catching check's part (P1.7a-v2 for A-rows, P1.9b-v2 for K-rows) lands the first-finding-and-location
   assertion. Likewise `P:473`: the `ProfileMissed` witness refusal is asserted by P1.7b-v2 (M11), P1.3-v2 only
   encodes the config.
6. **Matrix rows** (§6): (a) an A9 known-failing round-trip case with pinned `Location` in M9/P1.6; (b) M8
   names the tool arm's returned `{ outcome: o, next_state }` (code `replay_unrecorded_invocation`, clock
   unadvanced); (c) an A3 `msg_count`/count and an A4 count mismatch case in M10/P1.7a-v2. Mirror (a)–(c) in the
   affected graph criteria.
7. **§0.7 compliance**: commit `REVIEW-plan004-v1-verdicts-codex.md`, `REVIEW-plan004-v1.1-delta-verdicts-codex.md`,
   `REVIEW-plan004-v1.2-delta-verdicts-codex.md`, `BRIEF-plan004-v1-review.md`, `-v1.1-`, `-v1.2-`, `-v2-` and
   this review with the v2.1 correction commit, by explicit path.
8. **Cosmetic, optional**: `G2:V5` criteria "Two commits" → "three commits" (`P:104`); add "red-first or
   mutation record" to the kept P1 parts' graph criteria for symmetry with the -v2 parts (§0.8 already binds
   them); `ADR:4` "implemented by" → "to be implemented by" at the next ADR touch.

Retain everything else as written: the nine renames and the kept ids (§3), the §0.5 paths and P2.1's defaults
(§2, accepted here), the fresh-session design and the two-file receipt (§8).
