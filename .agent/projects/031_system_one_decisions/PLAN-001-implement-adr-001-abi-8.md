# PLAN-001: implement ADR-001 v0.8 — extension ABI 8.0 and the structured-decision capabilities

Date: 2026-09-20. Status: **proposed (v1.1), the release line ready to start after `SWEEP`.** v1.1 splits the
plan into a **release line R** (ABI 8.0 closed: 14–18 delegate-days) and a **post-release line X** (the live
decision runtime: additive, not ABI), after the operator's question on v1's total. Grounded at HEAD
`2f3ee4d1` on `arniwesth/031-abi-8-0`; `src/core`, `packages`, `tools`, `scripts` and the Makefile are
byte-identical to `2062605`, the commit every review since the second was grounded at, so every file:line
anchor below was verified by one of the seven reviews today and none has moved. ADR-001 is **v0.8**, 1209
lines, SHA-256 `42b326d67b61f6d7…`; its acceptance rule makes this plan's artifacts the acceptance criterion.
Extension ABI `7.4`; AILANG `v0.33.0`, the pinned build. Release gate: [033/ADR-001](../033_release/ADR-001-release-scope.md)
G5 — G5a is satisfied by this plan's P0 artifacts, G5b by this plan, G5e by its make targets, G5d by P0.4.

This plan is written under three standing disciplines and says where each bites: **sequence by source
surface** (`.agent/meta-decisions/sequence-implementation-handoffs-by-source-surface.md`) — every part owns
one surface and ends in one green state, and handoffs are written only for the next cluster that can be
grounded; **batch size** (`measure-review-loop-convergence…` rule 4) — the package migration is cut into
batches whose size is set by the measured per-item defect rate of the previous batch; **detector placement**
(rule 5) — every check is an author-side submission precondition (`mutgate.sh`, the make targets), not a
review finding. There is **one review**, of the evidence, at the end (ADR acceptance rule iv).

## 0. Preconditions and standing rules

1. **The ADR is frozen as text.** Changes to ADR-001 land only as numbered amendments citing a failing
   fixture, a compile error or a measured probe (acceptance rule ii). A part that finds the ADR wrong
   **stops, writes the amendment with the artifact attached, and continues under the amendment**; it
   does not reopen a review round. Questions this plan cannot settle on paper are §7's, each with the
   fixture that settles it.
2. **The sweep.** 013 ADR-001 D6: `make dst DST_JOBS=1` before any boundary edit; the ABI major is one, so
   `SWEEP` is P0.1. `Makefile` `DST_KNOWN_RED` is a register, not evidence. A red not explained by the
   register **blocks P0.4 until the operator rules.** Memory rule: heavy runs one at a time; the guard's
   `flock` is the exclusivity rule (PLAN-004 §0 item 2).
3. **The tree goes red in the middle, on purpose, and this plan says exactly where.** An ABI major that
   changes every `Capability` signature cannot be landed with the tree green between parts: `ExtCtx`
   literals (37 in 28 files), `ExtEntry` literals (8 in 3 files, plus the generator template), and all
   45 registration sites change type together. So P0 lands the **types and the freeze artifacts** against
   the ABI package alone, where a consumer can be compiled without core; P1 migrates core and packages
   **by surface**, and the whole-tree `make check_core` is green again only at `P1G`. Each P1 part's own
   green state is `ailang check` of the modules it touched against the 8.0 ABI plus the shape gate on the
   packages it migrated. No part outside P1 lands while the tree is red.
4. **Anchors.** P0 and P1.1–P1.2 are line-neutral for `make anchors` and `make driver_leaf_inventory`.
   P1.3 adds two leaves (`session.ail`, `tool_phase.ail`) and **re-baselines deliberately**, recording the
   pin diff and the reason in its commit; no other part moves an anchor.
5. **Formats.** `execution-program/4`, journal schema 1 and `event-vocabulary/1` stay until their own P2
   parts. P0.7 builds the schema-2 **fold** as a pure module that reads both schemas; it writes nothing and
   bumps no constant — the writer bump is P3.2.
6. **Where things live** (plan defaults; a part may move one with the reason recorded):
   probe suite and gate fixtures `scripts/dst/fixtures/adr001-boundary/` (ADR N48: "named by the plan"), rows
   in `scripts/dst/run_declared_vs_performed.sh` via `write_abi_ctor` (`:945-1000`); shape gate in
   `tools/ext_ambient_inventory/hook_scope.py` and `derive.py`; ABI in `packages/motoko-ext-abi/types.ail`;
   scripted consumers and the `DescribeTools` example in `packages/motoko_ext_conformance/`; decision
   codecs beside `src/core/dst_interaction.ail` and `dst_program.ail`; the fold in `src/core/journal.ail`;
   the host decision service `src/tui/src/decision-service.ts` beside `session-journal.ts` and
   `runtime-process.ts`. None of the new files exists at HEAD.
7. **Tests, red first.** Per part: `ailang check` on touched modules; `ailang test` where a module has one;
   the make targets named in the part. When a test can run before the implementation, the failing run is
   recorded in the commit message; when it cannot, the **two-sided mutation check** (`mutgate.sh`:
   baseline green → mutated red → restored green, bytes identical) is the **submission precondition**, refused
   at intake (013 `GATE-mutation-red-submission-precondition.md`). An asserted ordering with no recorded
   failure is not credited. Make targets named here that do not exist are created by the part that
   introduces them.
8. **Commits.** One commit per code part, written by the delegate as its last act, named
   `ADR-001 (031) <part>: …`. `SWEEP` and measurement parts produce a §6 record, no commit. Gates are
   operator decisions, no commit. The review document is committed by the orchestrator with the gate.
9. **Privacy.** Probe fixtures are synthetic. No session content, no credentials, no tailnet or host
   addresses enter a fixture, a brief or a §6 record. The ABI's "no credentials in `config`" rule is
   checked by review of each migrated `register_with_config`, since `Json` typing cannot enforce it.
10. **The pin.** AILANG stays at v0.33.0 for the whole plan. The probe suite is re-run at any bump
    (NOTE-001 §7); the import-precedence fact (ADR fact 6, N62) is as much a property of the pin as the
    inference gap. A bump mid-plan is a §7 event, not a silent upgrade.
11. **Registry-only packages** (release D5): `motoko-ext-fmt` is still on ABI 2.2.0's hooks record and gets
    a **legacy-only disposition** in the registry, not an 8.0 migration; `motoko-ext-typefix-agent` has no
    ABI dependency and needs none. Publishing 8.0 and the migrated packages is release work after `P1G`
    (033 G8), not this plan's.
12. **Batch size is measured, not assumed.** After each P1.2 batch the orchestrator records, in §6, the
    number of items and how many came back defective at intake; the next batch is capped so that the
    whole set has a plausible chance of passing (rule 4: at a 60% per-item defect rate a five-item batch
    passes with probability ≈1%). Batch A is the calibration.

## 1. Phases (by source surface; freeze artifacts first)

### 1a. The release line R — what "ABI 8.0 closed" needs, and nothing else

Release scope 033 D1 asks for the ABI at 8.0 before the tag so that it changes little afterwards. That is
the **type contract, its consumers compiling and gated, and a runtime that dispatches the new variants
deterministically**. It is not the live decision runtime: the host service, the wire arm, host admission,
the adapter, `execution-program/5`, journal schema 2, the event vocabulary and the shadow guard are
persisted-format and host work, none of it ABI, and the ADR already places "persistence and adapter
implementation" in separate release work. So the plan runs in two lines:

| line | parts | ends at | delegate-days |
|---|---|---|---|
| **R — release** | `SWEEP`; P0.2, P0.3 (suite, gate); P0.4, P0.5 (types, conformance/kind maps); P0.6 **trimmed** to one scripted consumer per variant plus the `DescribeTools` example; P1.1, P1.2 (core views/config, the 45 sites); **P1.3r** (the dispatch cursor with a **stub adapter arm** that answers every `Query` with `Unavailable(UnconfiguredBackend)` — no host service, no wire, no `Ports.decision_query` leaf yet); **P1.4r** (the three evidence fields populated truthfully as `NotReached`, an incomplete window, and `None`) | **R-G** = `P1G`: tree green, gate green on the migrated tree, 8.0 landed, 033 D1 met, the tag may proceed | **14–18** (batches of P1.2 on parallel delegates: about two weeks wall-clock) |
| **X — post-release, additive** | P0.7 (schema-2 fold); P1.3x (live wire arm, mirror, accounting propagation, the two leaves, anchors re-baselined); P1.4x (real evidence construction); P2; P3; P4; REV | `PLANG` | 27–37 |

Under R an extension that registers a decision capability gets a deterministic `Unavailable` and votes on it
through its own interpreter — the ADR's abstention path — so the variants are exercised end to end without a
provider. Freeze evidence 1, 2 and 8 are R's; evidence 3 (the fold's mismatch fixtures) moves to X with P0.7,
because it is journal schema 2, not ABI. **The residual risk, accepted and stated:** the host service (P3.1)
may want a type the frozen contract lacks; seven reviews of the D3 vocabulary and P0.6's consumers exercising
the full type surface are the mitigation, and under the 8.x rule a missing field is a minor behind a
constructor — only a variant or row change would be a 9.0. `P0G` stays as the ADR-acceptance checkpoint inside
R; it no longer waits for P0.7.

### 1b. Both lines, by surface

| phase | surface | produces | ADR freeze evidence | effort (delegate-days) |
|---|---|---|---|---|
| **P0** | tooling (anchor-independent), then the ABI package alone, then pure modules | the probe suite in its home; the shape gate red/green on fixtures; ABI 8.0 types; conformance/no-op profiles; scripted consumers + the `DescribeTools` example (R); the schema-2 fold with its mismatch fixtures (**X**, P0.7) | **1, 2(a)(b)(c), 8** in R → `P0G` = ADR accepted, ABI frozen at 8.0; 3 in X | R: 7–9; X: 2–2½ |
| **P1** | `src/core/ext/*`, `tool_catalog`, fixtures, generator; then `packages/*` in four batches; then `session.ail` / `tool_phase.ail` / `ports.ail` | core builds views and stamps config; 45 sites migrated; dispatch cursor with the stub arm and truthful evidence defaults (R); the live leaves, mirror, accounting and real evidence (**X**, P1.3x/P1.4x); tree green at `P1G` | 4 and 6 in X | R: 7–10½; X: 4–5½ |
| **P2** | `dst_*` codecs, `journal.ail` resume path, `session.ail` resume, event vocabulary | `execution-program/5`; vocabulary 2; epoch fold wired into resume with `Descriptor`/`Identity`/dry-`prepare`; strict replay of decision atoms | 3 (executed live), 5 (crash matrix, epochs), 7 (format migrations) | 8–10 |
| **P3** | `src/tui/src/*` | decision service: wire discriminator, success-returning append, host admission, adapter with fixture vectors, retries off, deadline, reply with ledger terms; writer schema 2 + `schema_promotion`; catalog config | 4 (live/recorded parity), 5 (journal write failure), 7 (promotion) | 6–9 |
| **P4** | consumers, documents | first completion guard on a scripted backend, then shadow; ADR-003 amendment; ADR-004 basis refresh coordination; measurements | 6 (shadow), evaluation section | 5–7 |
| **REV** | — | one review of the evidence, by a reviewer other than the implementer; `PLANG` | — | 1 round |

**To `R-G` (ABI 8.0 closed): 14–18 delegate-days. To `PLANG`: 41–55**, one review round. Each P1.2 batch that fails intake adds its re-run.

**Dependency skeleton** (an arrow is "must be green first"; gates are the operator's):

```
SWEEP ─┬─ P0.2 (suite) ─ P0.3 (gate) ──────────────────────────┐
       └─ P0.4 (ABI types) ─┬─ P0.5 (conformance, kind maps) ──┼─ P0G ─ P1.1 ─ P1.2a ─ P1.2b ─ P1.2c ─ P1.2d ─ P1.3 ─ P1.4 ─ P1G
                            ├─ P0.6 (scripted consumers) ──────┤                                                              │
                            └─ P0.7 (schema-2 fold, pure) ─────┘                         P1G ─┬─ P2.1 ─ P2.2 ─ P2.3 ─ P2G ─┐  │
                                                                                              └─ P3.1 ─ P3.2 ─ P3.3 ─ P3G ─┴─ P4.1 ─ P4.2 ─ P4.3 ─ REV ─ PLANG
```

P0.2/P0.3 read the tree and are anchor-independent: they can run in parallel with P0.4–P0.7 and are the
first artifacts. P2 and P3 are on disjoint surfaces (core formats vs host) and run in parallel after `P1G`;
P3.1's admission needs P2.1's codecs only at the wire boundary, which P3.1 stubs until P2.1 lands.

## 2. P0 — the freeze artifacts

### SWEEP (½ day, heavy, record)

`make dst DST_JOBS=1` at HEAD before any edit. Every target's result recorded with exit code and closing
summary; reds compared with `DST_KNOWN_RED`; an unexplained red blocks P0.4. No commit.

### P0.2 — the probe suite in its home (1 day, `scripts/dst`, anchor-independent)

**What.** Commit the boundary probe suite as fixtures and rows. Sources: the third review's 21 cases
(A.2), the fourth's escape set (A.2, with the unannotated variant moved to the escapes), the fifth's 20
attacks + 1 control + 3 recognizer escapes (A.3), the sixth's `delegate_shadow`, `computed_list`,
`registration_record`, `named_static_constant`, `config_projection` (A.3, with `repro/helpers.ail` and
`repro/boundary_types.ail` from its A.1), the seventh's `v7_*` set (A.3, with `repro/v7_mkmod.ail`). Every
source is quoted in a review appendix; the drafter re-ran the decisive ones today with identical results.
**Where.** `scripts/dst/fixtures/adr001-boundary/<case>.ail` plus the shared `types.ail`, `helpers.ail`,
`boundary_types.ail`, `v7_mkmod.ail`; rows appended to `run_declared_vs_performed.sh` through
`write_abi_ctor` (`:945-1000`), **not** `write_lim`, in the script's two-sided idiom (`:751-771`): `ok
"LIMITATION n still holds …"` naming `fb_30e82f6bdc5fc8c3` when the pinned compiler accepts, `bad "… FIXED
UPSTREAM …"` when it rejects. **Four groups, each with its own expected result** (ADR freeze 2(b)):
compiler-rejected controls; compiler-accepted ordinary controls; compiler-accepted escapes (boundary must
reject); compiler-clean boundary-rejected rows (the import shadows). New cases are new rows.
**Exit.** `make declared_vs_performed` green on the pin with every group scored; `mutgate`: flip one
limitation row's expectation → red → restore → green, bytes identical. Red-first is natural here: run the
rows before the boundary exists and record that the escapes are *accepted* — that is the documented state.

### P0.3 — the shape gate (2–2½ days, `tools/ext_ambient_inventory`, anchor-independent)

**What.** The registration-shape result of ADR D2 (facts 5–6, N42, N43, N51, N52, N62, N63), as a **separate
per-extension field** with its own rejection shapes, and a failing exit. Changes, all in `hook_scope.py`
unless noted: `func_body` (`:371`) and `_body_at` (`:415`) return the signature's parameter names beside the
body; `_resolve_func` (`:763`) takes the per-hop scope chain and consults locals and parameters, then the
**home module's** imports, then the home module's declarations — never the closure-wide table (`:557-558`,
`:773-777`); `Scope.locate` (`:626-663`) records `(module, parameters, lets)` per hop instead of overwriting
`producing_body` (`:659`), recognizes the `{ config, caps }` head (P0.4's grammar) with a literal or
delegated `caps`, and fails on a computed, `match`-selected or unknown list; `_binding_text` (`:910-942`)
accepts only a bare name resolving through the chain to a top-level `func` or import and rejects inline
lambdas, `let`-bound lambdas and partial applications; `registration_shape_result: pass | fail(reason)` is
computed from `locate` and the binding pass, **not** from `sc.rejections` (the walk emits
`hook-binding-unresolvable` too, `:882-886`); `emit_hook_scope` (`:1122`) returns nonzero from that field
alone; `derive.py` returns it (`:888`) without touching the default mode's closure verdict; `Makefile`
adds `ext_hook_scope` to `DST_TARGETS` (`:507-519`) beside `ext_hook_scope_selftest`; the self-test's
`capability_list_atoms` and `registration_shape` pins are re-pinned by hand for the new head, and
`closure_port_mediated` is asserted unmoved (`:1230-1240`).
**Fixtures** (`scripts/dst/fixtures/adr001-boundary/gate/`): `fx_named_ok` (pass); `fx_empty` (pass);
`fx_residue` (named callback with `show` in its walk: **pass**); `fx_shadow`, `fx_delegate_shadow`,
`fx_param_shadow`, `fx_delegate_param`, `fx_partial`, `fx_computed`, `fx_match`, `fx_unknown` (**fail**);
`fx_import_shadow`, `fx_delegate_import_shadow` (**fail**, compiler-clean); one fixture per in-tree
registration form (P1.2 will flip these from fail to pass).
**Exit.** The gate is red on every fail fixture and green on every pass fixture; on the unmigrated tree it
is **red by 35 bindings** — record that number in §6 as the expected state ("green on the migrated tree"
means those 35 moved). `make ext_hook_scope_selftest` green with the re-pinned yields. `mutgate` on the
result field: break the shadow rejection → `fx_shadow` passes → restore.

### P0.4 — ABI 8.0 types (1½ days, `packages/motoko-ext-abi` only)

**What.** `types.ail` and `ailang.toml` at **8.0**, nothing else compiled against it yet. The D2/D3/D7 contract:
`PureCtx`, `ProcessCtx`, `FsCtx`, `AiCtx`, `InterceptCtx`, `ProviderCtx` with the ports views of D2's table and
an exported constructor for each; `ext_config: Json` on every view; `Capability` re-signed on every variant,
`DescribeTools((Json) -> [ToolSchema])`, `ToolProvider`'s row gains `Trace`, `DecisionSolverJudge` and
`DecisionToolPolicy` with `DecisionPolicyDescriptor`, `JudgePreparation`, `ToolPreparation`; the D3
vocabulary (`NamedQuestion` … `DecisionUsage`), `VerificationEvidence`, `ToolEvidenceWindow`,
`DecisionInvocationState` with the two config projections and the five ledger terms; nullary `Accept`;
`ExtRegistration = { config: Json, caps }` as `register_with_config`'s return; `ExtEntry.config`. The header
carries the **8.x stability rule** (033 G5d): minors add fields only behind the exported constructors;
`Capability` variant or row changes wait for 9.0. `ai_summary` rewritten for 8.0.
**Exit.** `ailang check packages/motoko-ext-abi/types.ail` green; the package's own `ailang.toml` at `8.0`.
The tree is now red (item 3) and stays red until `P1G`. Red-first: a scratch consumer using a 7.4
signature must fail to check against 8.0 — record it.

### P0.5 — conformance, no-op profiles, kind and arity maps (1–1½ days, tooling that reads the ABI)

`packages/motoko_ext_conformance/` (`invariants.ail`, `harness.ail`) against 8.0; the no-op constructors
(`DescribeTools(\\_cfg . [])`, neutral decision callbacks); `tools/ext_registry_gen/generate.py`'s
`ExtEntry` template (`:154-165`); `hook_scope.py`'s arity table; `tools/profile_definition/check_fixtures.py`'s
kind list; `dst_profile_coverage.ail`'s capability maps and its classification of the two new pure slots
(views plus boundary, ADR D2 residual). `CAPABILITY_KINDS` gains two kinds. **Exit.** `make conformance`,
`make registry_gen_check` (against a fixture tree, since the real registry is red until P1) and
`ext_hook_scope_selftest` green.

### P0.6 — two scripted consumers and the `DescribeTools` example (1½ days, conformance package)

**What.** Freeze evidence 2(c): compiled ABI-8 examples of both consumers, **registered as named top-level
functions reading `ext_config`**, against a scripted backend: a finalize consumer (the completion-guard
skeleton: evidence selection from `verification`/`tool_evidence`, one request, `NoDecision` or bounded
`ContinueWithFeedback` from its own templates, thresholds from `interpretation_config`) and a tool-policy
consumer (compare a proposed call with recent typed outcomes; `Deny` or `NoOpinion`); plus a
`DescribeTools` example whose catalog differs between a configured and an empty tool set (`configured=1
empty=0`, the seventh review's `v7_describe_config`). Each passes P0.3's gate.
**Exit.** `ailang check` and the conformance harness green for both; the gate green on the example
package; `mutgate`: make a consumer read a value not in `ext_config` → the gate or the compiler rejects.

### P0.7 — the schema-2 fold, pure, with the mismatch fixtures (2–2½ days, `src/core/journal.ail`) — **line X**

**What.** Freeze evidence 3 as executable fixtures, without host or core wiring: the fold reads schema 1 and
schema 2 (`header_of_entry` widened to `1 | 2`, `:813-818`), folds the **effective policy epoch** from the
header snapshot and later policy-snapshot entries, and implements the resume rows and entries of ADR D6/D7:
`Descriptor` (question/limit refuses; interpretation-only appends), `Identity` (fires on **orphaning** of
retained state only), first registration, `schema_promotion` as the fold boundary, the config-digest
snapshot (`config` plus constructor data positions), orphan acknowledgment (ended on reappearance),
registry-migration (moves allowance and limit, activates), operator grant (money and limit separately;
active identity = recorded limit change; absent = refused), the inactive marker, the recorded dry-`prepare`
refusal, and the decision records (reservation, observation, vote application). `resume_refusal`
(`:1796-1806`) compares `Descriptor` and `Identity` across profile switches. The fold is pure; nothing here
writes.
**Fixtures** (journal JSONL, synthetic): every pinned case in ADR D6 — P0 → forced P1 → ordinary P1;
rollback; limit change after force; interpretation-only change; config-digest change; first schema-2
resume of a pre-feature journal; additive profile switch; reorder/removal/reinstall with and without retained
state; forced `Identity` then a paid query, then an `Immediate` vote, then a grant, then a migration;
removal with no replacement; acknowledged → reappears → accrues → removed again (**refuses**); grant to an
active and to an absent identity; promoted and native schema-2 journals read by a schema-1 fold (the two
refusal messages, `journal.ail:634` and `Entry(seq, "type=schema_promotion")`); a schema-2 journal with an
unknown entry (refused, `:3282-3288`'s rule); strict query mismatch and interpretation-only mismatch; the
offline re-interpretation experiment labelled and distinct.
**Exit.** `ailang test src/core/journal.ail` green with every fixture; every existing schema-1 test untouched
and green; `mutgate` on the orphan predicate. This is the artifact freeze item 3 names, executed.

### P0G — the operator gate: ADR-001 accepted, ABI frozen at 8.0

Checklist, all artifacts, no prose: P0.2 rows green in four groups; P0.3 gate red/green on its fixtures and
red-by-35 on the tree; P0.4 types at 8.0 with the stability rule; P0.5 tooling green; P0.6 consumers
compiled and gated. (P0.7's fold fixtures are line X and are not waited for.) The release scope's G5a is met here; 033's D1 ("8.0 before
the tag") becomes "8.0 landed" at `P1G`.

## 3. P1 — core and packages to 8.0 (tree red until `P1G`)

### P1.1 — views, config, catalog, registry (2–2½ days, `src/core/ext/*`, `tool_catalog.ail`, fixtures, generator)

The host builds the full context once and projects each view (the exported constructors); stamps
`ext_config` from `ExtEntry.config`; `register_with_config` consumers read `ExtRegistration`; the 37 `ExtCtx`
literals (28 files) and 8 `ExtEntry` literals (`runtime.ail:829,1067-1068`; `registry_normalize.ail:264,389-391`;
`ext_fixture.ail:188`) and `generate.py`'s template move; `tool_catalog.ail:107-110` passes `e.config` to
`DescribeTools`; `registry_normalize.ail` rejects a legacy and a new variant in one vote family (`:168-174,231`)
and computes the per-epoch **config digest over `config` plus data positions** where `capability_kind`
already reads them (`runtime.ail:1139-1151`); `ext_set_digest` (`:1107-1122`) stays kind-only. Dispatchers
(`runtime.ail:402-416`, `:710-719`) unchanged in precedence, re-typed to views. **Exit.** `ailang check` on
every touched module; the ext fixtures green; line-neutral for anchors.

### P1.2 — the 45 registration sites, in four batches (4–6 days total, `packages/*`)

Site list: the sixth review's 45-row ledger (`REVIEW-adr001-v0.6-verdicts-codex.md` §Q-1), verified by the
seventh (A.5). Every site becomes a **named top-level function bound directly**; every captured value goes
through `config` (all 30 are data; none is a function). A captured registration value used by several
callbacks is encoded once. Per batch: the gate green on the batch's packages (P0.3 fixtures flip
fail → pass), `ailang check` on each package, the package's own tests, and the **intake count** for §0
item 12.

| batch | packages | sites | captures | why this order |
|---|---|---|---|---|
| **A** (calibration) | compaction-structural, decision-framework, empty-stop-guard, microrag, omnigraph, progress-contract-guard | 9 | 1 (omnigraph's cached prompt) | already named or trivially so; sets the per-item defect rate |
| **B** | repetition-guard, test-dummy, scratchpad, exa-search, context-mode | 14 | ints, strings, one config record | `let`-bound and inline forms with simple data |
| **C** | a2a, agentcli, ailang-docs, mcp, compaction-ai | 11 | records, lists, four `DescribeTools` | the configuration channel and `DescribeTools(config)` under load |
| **D** | compose, herdr | 11 | `runtime_cfg`, `snippet_caps`, `composition_mode`; `cfg`, `tools`, `orch` | largest cross-view helper migration (compose's three `ExtPorts` helpers, `:312,326,921,1018`) and the FS renderers; **measure per-call decode cost here** (ADR D2 "cost") |

Batch D also records the ADR's cost expectation as a measurement: hook latency before/after for compose's
interceptor and herdr's prompt shaper, and the retained `config` size per extension. A result the ADR's
sentence does not survive is an amendment with the numbers attached.

### P1.3r — the dispatch cursor with a stub adapter arm (1–1½ days, `ext/runtime.ail`) — **line R**

The per-atom two-phase cursor of D4 in `ext/runtime.ail`: prepare → `Query` → the caller answers →
interpret → next atom; every atom runs; vote families enforced in normalization; precedence preserved
(`:402-416`, `:710-719`). Under R the caller's answer is a **stub arm** inside the dispatcher: every `Query` is
answered with `Unavailable(UnconfiguredBackend)` and zero usage, no port is read, no ordinal advances, no
world token is threaded through a leaf. No leaf lands in `session.ail` or `tool_phase.ail`; no `Ports` field
is added; **anchors stay neutral**. `Immediate` votes are applied through the existing merges. **Exit.**
`make check_core`, `make test`, `make driver_plus_no_ops` with a neutral decision atom in the no-op profile;
`make profile_coverage` classifying the two pure slots; mutation: make the stub return `Answered` → the
conformance consumer's interpreter must not be reachable with fabricated answers → red.

### P1.3x — the live leaves, the mirror, accounting (3–4 days, `session.ail`, `tool_phase.ail`, `ports.ail`) — **line X**

The per-atom two-phase cursor in `ext/runtime.ail` (D4): prepare → `Query` → caller executes → interpret →
next atom with the successor world; every atom runs; vote families; precedence preserved. `Ports.decision_query`
with scripted, recording and strict-replay arms child-side and the live arm as a **wire exchange** (`{IO}`,
the `wake_read` shape: emit, block, correlated reply); the finalize leaf in `session.ail` after the existing
gates (`classify_candidate`), the tool-policy leaf in `tool_phase.ail` per proposed call (`:567`), both
advancing the world at the leaf and witnessed as `tool_exec` is (`session.ail:3623`; extraction of the
private `witness` optional, N22); the request carries `run_cost`/`run_cap` (`Some` only when metered and
`max_cost_millicents > 0`, `step_machine.ail:112-114`); the reply carries the observation and the ledger
terms, which update the child's **mirror**; `decision_vote_applied` emitted on selected application,
including `Immediate`, and counters advanced locally; accounting propagation through `CandidateClass` and the
tool-phase results into `totals`; `C2LoopState` gains the typed tool-evidence window (incomplete on
resume) and the mirror. **Anchors re-baselined here**, diff recorded. **Exit.** `make check_core`,
`make test`, `make test_integration`, `make driver_plus_no_ops` with neutral decision atoms, `make anchors`
on the new baseline, `make driver_leaf_inventory` knowing the new request class; mutation: drop a losing
vote's successor world → strict parity red.

### P1.4r — truthful evidence defaults (½ day, `session.ail`) — **line R**

Every context view carries `verification = NotReached`, `tool_evidence = { records: [], complete_from_session_start: false, omitted_count: None }`
and `decision_state = None` at ordinary sites, `Some` with identity, limits, the two config projections and
zeroed ledger terms at decision sites. Truthful, never asserting success (D3). **Exit.** fixtures; mutation:
default `Passed` → red.

### P1.5r — manifest ABI pins 7.4 → 8.0, and the fixture-literal exemption (½ day, 25 tracked `.ail` files, `tools/profile_definition/check_fixtures.py`) — **line R**, added 2026-09-20 by the operator's ruling on `Q-SWEEP`

**Why this part exists.** `SWEEP` (§9) found that the ABI-version pin sweep in `check_fixtures.py`
(`:912-943`) regexes every `abi_version: "X.Y"` and `_manifest(… "X.Y")` literal across **all tracked
`.ail` files** and compares it with the version `packages/motoko-ext-abi/ailang.toml` declares live. At
HEAD that is **31 pins at `7.4` in 25 files**, plus one `7.3`. When P0.4 sets 8.0, all 31 drift and
`make profile_definition` and `make driver_only` go red on 31 sites. No other part owns those files:
G5b's "19 package pins" are `ailang.toml` path pins, a different set, and P1.1 covers `src/core/ext/*`
and `tool_catalog`, not `dst_profile`, `dst_replay` or `dst_driver_*`. Neither target is in `R-G`'s
checklist, so without this part nothing would force the pins and the drift would ship.
**What.** Every one of the 31 pins reads `8.0`. The one exception is deliberate:
`src/eval/journal/admission.ail:993` builds an entry with `abi_version: "7.3"` so that `a9b_abi` fires
`A9b:AbiVersionDiffers` — setting it equal to the lock makes that fixture assert nothing, which is a
vacuous test and is refused at intake. So the sweep gains an **explicit, named exemption** for fixture
literals built to differ, rather than being loosened; its `pins == 0` and `< 50 files` guards must still
fire. The checker's current message ("the repair is to set each to" the live version) is corrected so it
stops recommending the vacuous repair.
**Exit.** `make profile_definition` and `make driver_only` green on the tree at 8.0; `mutgate`: remove
the exemption → the `7.3` fixture is swept again → red → restore → green, bytes identical.

### P1.4x — evidence construction and the invocation state (1½–2 days, `session.ail`) — **line X**

`VerificationEvidence` from `run_dp7_verifier` (`:2241-2254`), `VerificationUnavailable` marked heuristic
(`is_missing_infrastructure`, `:2231-2239`); `ToolEvidence` from recorded `ToolCompleted`/`ToolFailed`
outcomes with the `-1` sentinel mapped to `ToolOutcomeUnknown` (`ports.ail:645-646`); `decision_state = None`
at ordinary hook sites, `Some` with identity, limits, the two config projections and the mirror's terms at
decision sites. **Exit.** Fixtures for each variant; mutation: label a stale verification run as current →
red.

### P1G = R-G — the operator gate: 8.0 landed, tree green, the release line complete

`make check_core`, `make test`, `make test_integration`, `make conformance`, `make declared_vs_performed`,
`make ext_hook_scope` **green on the migrated tree**, `make profile_coverage`, `make driver_plus_no_ops`,
`make registry_gen_check`, `make anchors`, `make driver_leaf_inventory`, `make event_vocabulary` (still 1),
`cd src/tui && bun run test`; both CI workflows green on the commit. 033's D1 is met; the release doc's G5
row records it. Registry publication (033 G8) may start from here.

## 4. P2 — persisted formats (`P1G` first; parallel with P3)

### P2.1 — `execution-program/5` (3–3½ days, `dst_interaction.ail`, `dst_program.ail`, `dst_replay`, `dst_persistence`, `world_ordinal`)

The decision interaction class: identity (a new `IdentityBody` constructor — which alone would move no
version, `dst_interaction.ail:96-110`), the **observation payload** and scripts that force `/5`
(`dst_program.ail:117-133` is the precedent), request/observation codecs over the D3 integer vocabulary,
reservation and admission-refusal records a scripted run replays, cursor, reconstruction, projections,
catalogue class; unknown identity tags **fail validation** rather than defaulting (`ext_world.ail:405-429`);
v4 fixture bytes untouched and decoded as v4. **Exit.** `make strict_replay`, `make ledger_parity`,
`make world_state`, `make fault_catalogue`, `make program_persistence`, `make seeded_generator` green with
decision atoms in the generator; the v4 byte-identity assertion moves to v5 exactly as it moved to v4.

### P2.2 — event vocabulary 2 (1 day, `dst_event_vocabulary.ail`)

Invocation/preparation, skip (disabled, exhausted, inactive), admission refusal, query start/reservation,
observation, proposed/effective vote, selected application, dry-`prepare` refusal, immediate and shadow
paths. **Exit.** `make event_vocabulary` at 2; every event mapped to a journal record (P0.7) and a program
projection (P2.1).

### P2.3 — resume with the epoch (2½–3 days, `session.ail` resume, `journal.ail` wiring)

P0.7's fold wired into `--resume`: the epoch, the mirror seeded from the fold, first registrations at
configured allowance, the `Descriptor`/`Identity` rows in the header comparison, `--resume-force` appending
the snapshot (acknowledgments, inactive registrations, descriptors), the **dry `prepare`** at a config epoch
boundary on the last recorded evidence snapshot (pure, no exchange, no ordinal), in-process suspension
reading the same retained state (`c2_state_from_continuation`, `:2607-2652`, resets per-run totals only).
**Exit.** Every P0.7 fixture reproduced end-to-end through a resume; `make journal_resume`, `make park_resume`
green; mutation: skip the dry `prepare` → the config-change fixture passes when it must refuse.

### P2G — formats landed

P2.1–P2.3 green together; freeze evidence 3 executed live (dry-`prepare` refusal and acceptance), 5's
epoch and cross-run cases, 7's format migrations. Operator gate.

## 5. P3 — the host (`P1G` first; parallel with P2)

### P3.1 — the decision service (3–4 days, `src/tui/src/decision-service.ts`, `runtime-process.ts`, `session-journal.ts`)

A request/reply discriminator distinct from wake (`runtime-process.ts` wake routing; not the consume-user-
input semantics); active-invocation tracking, duplicate refusal, late-reply drop (the `outstandingWake`
single-slot precedent); **stdin ownership** with user/model-change commands queued during a decision read;
**host admission** from the recorded per-binding maximum-charge table and limits against the host ledger and
the request's run terms, with `run_cap = None` when unmetered or disabled; a **success-returning append** on
the leased `SessionJournal` (today `append` returns `null` on failure, `:367`, and `SessionLogger.log` drops the
count, `:404`): failed reservation append → refuse, no dispatch; failed observation append → no reply,
reservation retained; failed application append → run stops; **the adapter**: one attempt, SDK retries
**disabled explicitly**, end-to-end deadline, the sole float normalizer (domains, tolerance, largest-remainder
apportionment, half-up rounding) producing the integer observation; outbound request as a projection with
no session/user/trace identifiers; reply carries the observation and the updated ledger terms.
**Fixture vectors** shared with the child codec (P2.1) as versioned JSON: finite/non-finite numbers, negative
usage, missing optionals, duplicate/extra/missing answers, half rounding at the boundary, distribution
tolerance, remainder ties. **Exit.** jest suites for each failure arm and each vector; a scripted provider
double; `mutgate` on the reservation-before-call order.

### P3.2 — writer at schema 2, promotion on adopt, catalog config (1–1½ days, `session-journal.ts`, `index.ts`)

`JOURNAL_SCHEMA_VERSION = 2` for new sessions (`:34`); `adopt` (`:288`) of a schema-1 file appends
`schema_promotion` before any decision entry and never rewrites the header (`writeHeader` stays a no-op on a
nonempty file, `:403`); the config-digest snapshot and policy-snapshot entries written in host order; the
catalog receives `config`. **Exit.** jest: promoted and native journals, resumed twice, read by the P0.7 fold
(via a fixture exchange); mutation: promote twice → second write refused.

### P3.3 — live/recorded/scripted parity (1½–2 days, both sides)

Freeze evidence 4: the same decision exchange recorded live (against the double) and replayed scripted and
strict; losing votes' successor worlds retained; distinct identical-content occurrences; no network under
strict; an interrupted exchange recovered as charged-and-unapplied; the emission→write window recovered.
**Exit.** `make recorded_stream`, `make stream_parity`, `make strict_replay` with decision atoms; a §6 record of
the crash matrix (freeze 5) with each point exercised.

### P3G — host landed

P3.1–P3.3 green; evidence 4 and the journal-failure and promotion rows of 5 and 7. Operator gate.

## 6. P4 — the first consumer, the documents, the measurements (`P2G` and `P3G` first)

### P4.1 — the completion guard, scripted then shadow (2–3 days, a new package)

The P0.6 finalize consumer becomes `motoko-ext-completion-guard` (or lands in an existing guard package by
operator choice): registered as named functions, configuration through `config`, `question_config` holding
every evidence-selection and question value, `interpretation_config` the thresholds and templates; scripted
backend first; **shadow mode** (charged, neutral effective vote, no counter) against the configured live
backend only after `P3G`. Freeze evidence 6: composition with DP7, open waits, permissions, all-atom
ordering, tie behavior; compaction, profile change and resume cannot reset allowances. **Exit.** conformance
green; a §6 record of the shadow run: queries, refusals, cost, latency; no intervention applied.

### P4.2 — ADR-003 amendment and ADR-004 basis refresh (1 day, documents; authored in the P2.3 session that holds the fold)

ADR-003 D5 gains the `Descriptor` and `Identity` rows, the epoch, the acknowledgment/migration/grant
entries, the inactive marker, header `schema_version: 2` and `schema_promotion` — as an amendment citing
P0.7's fixtures. ADR-004: the new port, world, program shape and journal schema change its evaluation basis;
its D5 requires refreshed evidence, coordinated with that project and **never by editing its evaluator
worktree** (`/workspaces/motoko_agent-eval`).

### P4.3 — measurements (1 day, record)

The ADR's evaluation section: correct stops, premature stops, honest blocked reports, repeated tool calls,
missing infrastructure, truncated/stale evidence, outstanding waits against the deterministic guards; false
objections, missed bad completions, added steps, cost, latency — measured separately from replay fidelity. The
per-call decode cost from P1.2 batch D and the retained config sizes, against the ADR's stated expectation.

## 7. Open questions, each with the fixture that settles it

1. **Where the replay admission validator runs** (sixth review Q-3): host-side in the decision service, or a
   shared admission reducer callable from the child's strict-replay arm. Settled in P2.1/P3.1 by the fixture
   "strict replay with the provider unreachable and one corrupted recorded admission input" — whichever
   placement makes it pass without a live service wins; the ADR's D5/D6 text names the winner as an amendment.
2. **Per-call decode cost** (ADR D2, N50 cost): P1.2 batch D's measurement. Threshold for an amendment: hook
   latency growth above what the ADR's "cheap against a hook's cost" can carry, stated as a number in §6.
3. **The mirror's update rule** (N47, sixth review Q-3): every reply carries the terms; `Immediate`
   applications advance local counts. Settled by P1.3's fixture "mirror understates money → `prepare`
   abstains → the useful query is lost" versus "overstates → host refuses safely"; the ADR keeps
   "informational" unless the first case proves common in P4.3.
4. **Whether the first guard lands in a new package or an existing one**: operator choice at P4.1.
5. **An AILANG bump mid-plan**: re-run P0.2 and P0.3; if the inference gap (`fb_30e82f6bdc5fc8c3`) is fixed,
   the limitation rows go red by design and the controls are re-read (NOTE-001 §7); if import precedence
   changes, fact 6's fourth class is re-scored.

## 8. Non-goals

Live provider inference before P4.1's shadow run; registry publication (033 G8, after `P1G`); the
`ext_ai_step` usage loss (separately disclosed debt); a fix to the upstream compiler; a general
information-flow guarantee for extension code (the ADR states what the boundary proves); a TUI surface for
decision interventions beyond the recorded events; power-loss durability (process-crash only, ADR D5).

## 9. Results

*(one entry per part: HEAD, command, exit code, output excerpt, what could not run, intake count for P1.2
batches; appended by the orchestrator as parts land)*

### SWEEP — 2026-09-20, record, no commit

| | |
|---|---|
| HEAD | `75fefdcb` (documents-only over `2f3ee4d1`; `src/`, `packages/`, `tools/`, `scripts/`, `Makefile` empty diff vs `2062605`) |
| Command | `make dst DST_JOBS=1` |
| Exit code | **2** |
| Duration | 1686 s (28 min) |
| Targets | 51 — **49 passed, 2 failed**, 0 skipped |
| AILANG | `v0.33.0` (`ae36986`), the pin |
| Memory | peak `memory.current` 9.09 GiB against the 12 GiB rule; 112 samples at 15 s; no trip, no monitor gap |
| Record | `RECORD-SWEEP.md` (per-target table) |
| Log | `evidence/SWEEP-2026-09-20.log` (3.9 MB, uncommitted pending the operator's evidence-retention call) |
| Could not run | nothing |

**The two reds, and they are one cause.**

```
make[1]: *** [Makefile:833: profile_definition] Error 1
make[1]: *** [Makefile:1344: driver_only] Error 1
FAIL: packages/motoko-ext-abi/ailang.toml declares ABI 7.4, and these pin something else:
  src/eval/journal/admission.ail: pinned '7.3'
```

Both targets run the same ABI-version check and fail it identically; every other assertion in both
targets passed (`profile_definition_dst PASS`, `driver_only_dst PASS` precede the failure in each).
Orchestrator intake (rule 5, own mechanical receipt, not the delegate's envelope): the log holds
**exactly two** make-level errors, and `src/eval/journal/admission.ail:993` reads

```
(tx_first(RealEntry, { i | abi_version: "7.3" }, c), "A9b:AbiVersionDiffers@aggregate:provenance:abi_version"),
```

— a **test fixture** that constructs an entry with a deliberately differing ABI version to exercise the
`A9b:AbiVersionDiffers` admission finding. The checker cannot distinguish that literal from a stale
manifest pin. `git log 2062605..HEAD` on `admission.ail` and on `packages/motoko-ext-abi/ailang.toml` is
empty, so the red is **pre-existing at the grounding commit** and sits on 013/PLAN-004's evaluator
surface, not on 031's.

**Neither red is explained by `DST_KNOWN_RED`**, so §0 item 2 applies: **P0.4 is blocked until the
operator rules** (graph: `Q-SWEEP`, `P0.4` blocked, unblock = operator).

**The register is also stale in the other direction.** `DST_KNOWN_RED := driver_plus_herdr herdr_graded`
(`Makefile:697`) — **both PASSED** this run (`HERDR-GRADED: PASS`; `dst_driver_plus_herdr.ail 3/3
passed`). The register's own comment says to drop both entries when the summary reports them passed.
That edit is not this line's to make; it is recorded here for the owner of `Makefile:697`.

**Operator ruling (`Q-SWEEP`, 2026-09-20), adopting the orchestrator's recommendation in full.** (a) The
`admission.ail:993` red is a **known false positive**; P0.4 is unblocked. (b) The checker's own
suggested repair is refused for that site — it would make the `A9b` fixture vacuous — and a new part,
**P1.5r**, owns the 31 manifest pins `7.4 → 8.0` and an explicit fixture-literal exemption, landing
before `R-G`. (c) The `DST_KNOWN_RED` edit stays with the owner of `Makefile:697`.

## 10. Estimates

| phase | delegate-days |
|---|---|
| **R** | **14½–18½** (SWEEP ½, P0.2 1, P0.3 2–2½, P0.4 1½, P0.5 1–1½, P0.6 1, P1.1 2–2½, P1.2 4–6, P1.3r 1–1½, P1.4r ½, **P1.5r ½**, gate ½) — P1.5r added by the `Q-SWEEP` ruling |
| P0 (X part) | 2–2½ (P0.7) |
| P1 (X part) | 4–5½ (P1.3x 3–4, P1.4x 1½–2) |
| P2 | 8–10 |
| P3 | 6–9 |
| P4 | 5–7 |
| **total to `PLANG`** | **41–55**, one review round |

## Cross-references

- [ADR-001 v0.8](ADR-001-extension-owned-structured-decisions.md) — D2–D7, the freeze evidence and the acceptance rule
- The seven reviews (`REVIEW-adr001-v0.1…v0.7-*.md`) — their appendices are the probe suite P0.2 commits
- [NOTE-001](NOTE-001-effect-inference-gap.md) — the inference gap and its re-test procedure
- [033/ADR-001 Release scope](../033_release/ADR-001-release-scope.md) — G5, G5b, G5e, G8
- [013 PLAN-004](../013_core_architecture_for_dst/PLAN-004-implement-adr-004.md) — the conventions this plan mirrors (§0, §6 records, gates)
- [013 GATE-mutation-red-submission-precondition](../013_core_architecture_for_dst/GATE-mutation-red-submission-precondition.md), `mutgate.sh`
- `.agent/meta-decisions/`: sequence-by-source-surface; author-each-artifact; measure-review-loop-convergence (rules 4 and 5); re-ground-inherited-anchors
