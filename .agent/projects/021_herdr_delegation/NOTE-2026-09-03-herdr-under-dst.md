# Note: could the DST world test the herdr integration?

Date: 2026-09-03
Grounding: HEAD `47db38a` (2026-09-01) plus the UNCOMMITTED working tree on
`arniwesth/mot-133-f-5-extension-side-tag-delegates-at-spawn-report-stale` — the same tree
[`HANDOFF-2026-09-02-run-file-truth-view-and-loop-guard.md`](HANDOFF-2026-09-02-run-file-truth-view-and-loop-guard.md)
describes. Every number below came from a command run in this session and the command is quoted
beside it. Nothing here was built; this is an assessment and a priced recommendation.

The question, as asked: *could we use the DST system to test Motoko's herdr integration?*

## 0. The answer

**Yes, and herdr is the best-positioned extension in the tree for it — better positioned than
compose, the only effectful extension that has a DST profile today.** Two measured facts carry the
answer:

1. **herdr's hook body performs every effect through `ExtPorts`.** Classifier 3 finds exactly ONE
   ambient source in its closure, and it is the registration-time env read — the same class the
   compose profile already discloses rather than routes. (§2.1)
2. **The deterministic world already has every port herdr uses.** The scripted extension-effect
   queue, the in-memory filesystem, the world clock, recording and strict replay all landed for
   compose (project 009, WI-D16 → D27). Nothing new has to be built on the world side. (§2.3)

What is missing is the profile itself — a record module, an acceptance script, a make target — and
a shared scripted-herdr fake that the two existing verify scripts each hand-roll today.

## 1. The DST world at HEAD, in the parts that matter here

The spine is `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`; the closing note of
the build is `.agent/projects/009_motoko_dst_execution/NOTE-d28-the-final-acceptance-rerun.md`.
Four facts from them, each re-checked in code:

- **Three profiles exist**, versioned in their record modules:

  | profile | record | version | installs | mediates |
  |---|---|---:|---|---|
  | `driver_only` | `src/core/dst_driver_only.ail:512` | 24 | nothing | nothing |
  | `driver_plus_no_ops` | `src/core/dst_driver_plus_no_ops.ail:215` | 12 | four no-op extensions | nothing |
  | `driver_plus_compose` | `src/core/dst_driver_plus_compose.ail:220` | 4 | `compose` | ONE hook, `on_response_intercept` |

  Compose's tool path is **excluded** (`excluded_slot_ids` at `dst_driver_plus_compose.ail:336`)
  because it reaches ambient AI before anything routed.

- **The world's port set** (`src/core/ports.ail:783` onward) is: `model_step`, `approval_read`,
  `clock_now`, `env_get`, `file_read/write/remove`, `path_stat`, `dir_list`, `dir_make`,
  `tool_exec`, and `ext_effect_exec`. Determinism comes from queues on `WorldState`: `files`
  (`:352`, an in-memory filesystem of `FsNode`s), `tools` (`:366`), `ext_effects` (`:392`, a
  `[ScriptedTool]` queue for **extension-initiated** subprocess calls), and `clock_ms` (`:195`).
  `world_ext_effect` (`:1498`) pops the queue, advances the clock by the entry's `duration_ms`,
  and falls through to a REAL exec when the queue is empty. `ScriptedTool` (`:531`) has carried
  `exit_code` since WI-D22 and its fault fields (correlation, deadline, code) since A12.

- **Criterion 2** (ADR-001 D5) is what an effectful hook must satisfy to count as covered:
  effectful only through world-mediated ports, origin-tagged to the performing extension, explicit
  world state returned. Its three clauses are `Criterion2Clauses` at `src/core/dst_profile.ail:426`.
  A `WorldMediated` entry may rest on classifier 3 (universal) or on the `discovery` producer — a
  recorded, validated, strictly replayed run — and compose's one substantive entry rests on
  `discovery`.

- **Three register entries in D28 §9.1 bear directly on this:** entry 19 — *no run in this tree
  reaches an excluded hook dispatch … the graded session dispatches no tool*; the standing fact
  under row 4 — `extension_effect_fault` is waived by every profile in the tree; entry 14 — the
  fault catalogue's waiver condition names `driver_only` verbatim and every new profile is another
  consumer of that defect. D27 §10.3 prices `compaction_ai` as the next installable extension. herdr
  is not mentioned anywhere in project 009 (`grep -rn -i herdr .agent/projects/009_motoko_dst_execution/`
  returns nothing) — it is only in the shared omit list, see §6.

## 2. herdr measured against the world

### 2.1 Classifier 3 (the ambient inventory)

```
python3 tools/ext_ambient_inventory/derive.py --json      # extensions.herdr
  verdict:          AMBIENT
  closure_size:     5   (abi/types, dagr, herdr, register, types)
  ambient:          1   -> packages/motoko-ext-herdr/register.ail:26  std/env.getEnvOr  {Env}
  ext_ports_calls:  32
  unresolved_receivers: 0
```

For scale, compose — the extension that DID earn a profile — reports 8 ambient sources and 36 port
calls (`dst_driver_plus_compose.ail` header, §"WHAT A READER OF v1 MUST NOT CONCLUDE", point 1).
herdr's one source is registration, not a hook: `register_with_config` (`register.ail:40`)
declares `{Clock, Env, FS, IO, Process}` but its body is `getEnvOr` calls and a call to
`make_hooks`. The compose profile grants `Env`/`FS` across registration and discloses it
bidirectionally (`NOTE-d27` §6, `DISCLOSED` lines); herdr would take the same disclosure for a
strictly smaller grant, `Env` only.

### 2.2 The hook-scope classifier

```
python3 tools/ext_ambient_inventory/derive.py --hook-scope
  herdr   AMBIENT   HOOK-UNRESOLVED   1
  show    blocks 9 extension(s): ... herdr ...
  f       blocks 1 extension(s): herdr
  COUNTERFACTUAL (not a verdict): were these resolved effect-free,
    HOOK-PORT-MEDIATED would be 9 of 18 — adding compaction_ai, compaction_structural, herdr
```

Two doors: `show` (door 3, disclosed and filed upstream at D28 §5 as `fb_0f70d66af0fddb2c`) and
one unresolved receiver `f` — almost certainly the function-typed parameter of `dagr_record`
(`herdr.ail:297`, `f: (Json, int) -> DagrStep`). Neither blocks a profile: compose carries the
same `HOOK-UNRESOLVED` verdict and its profile closes the cell by disclosure plus dynamic evidence
(`NOTE-d27` §10.2 point 2). The classification line for herdr would read the same way.

### 2.3 The port census — every effect in the hook body is a port call

```
grep -ohE '\bp\.[a-z_]+' packages/motoko-ext-herdr/herdr.ail packages/motoko-ext-herdr/dagr.ail \
  | sort | uniq -c | sort -rn
     13 p.clock_now
      8 p.file_read
      4 p.file_write
      4 p.dir_make
      1 p.tool_handle
      1 p.file_remove
      1 p.dir_list
      1 p.key            (a record field, not a port)
```

The single `p.tool_handle` call is `run_cmd` (`herdr.ail:188`): every herdr CLI invocation —
`pane split`, `pane run`, `agent start/explain/prompt/get/wait`, `pane report-metadata`, `pane
list`, `pane close` — and the one `mv` in `publish` (`herdr.ail:264`) go through it as a
`BashExec` tool envelope, and every caller threads `r.next_state`. There is no tmux call and no
`std/process` call in the hook body. `dagr.ail` is entirely `pure func`.

**The world routes all of these today.** `session.ail:1068` binds `tool_handle` to the
extension-effect adapter that reads `WorldState.holder_ext_id` for the origin tag (WI-D24);
`session.ail:1171-1188` bind the file, directory and clock ports to their world arms. The scripted
arms exist for each: `scripted_file` (`ports.ail:1033`), `scripted_file_write` (`:1135`),
`scripted_file_remove` (`:1170`), `scripted_dir_list` (`:1304`), `scripted_dir_make` (`:1349`).

### 2.4 The hooks bound — one, and it is the gated slot

`make_hooks` (`herdr.ail:1113`) returns two atoms: `DescribeTools` and `ToolProvider(tools,
handle)`. It binds none of `on_pre_step`, `on_response_intercept`, `on_solver_candidate` — the
three unconditionally-dispatched barrier slots that keep most extensions out of a profile.
`ToolProviderKind` is the only `Gated` dispatch (`src/core/dst_profile_coverage.ail:177`). The
`handle` lambda's row at `herdr.ail:1115` is the ABI-mandated ten-effect row; the body it wraps,
`on_tool_handle` (`:1094`), is `{IO, Process, FS, Clock}`.

So where compose had to EXCLUDE its tool path, herdr's tool path is the whole extension, and it
could be **covered**.

## 3. What the existing gate already is, and is not

`make check_core` (`Makefile:2182`) runs four herdr targets, all under `--ai-stub` with scripted
ports, no herdr binary, no tmux:

| target | script | shape | printed this session |
|---|---|---|---|
| `verify_herdr_gate` | `scripts/verify_herdr_gate.ail` | empty-tools leg everywhere; in-pane leg only under `HERDR_ENV=1` | not re-run |
| `verify_herdr_check_answer` | `scripts/verify_mot131_early_answer.ail` | scripted ports | not re-run |
| `verify_herdr_owner_tag` | `scripts/verify_mot133_owner_tag.ail` | 6 cases; scripted `tool_handle` RECORDS each argv into the world token | `OK=7 FAIL=0` |
| `verify_dagr_producer` | `scripts/verify_mot136_dagr_producer.ail` | 10-step lifecycle; in-memory filesystem in the world token; `mv` really moves | `OK=17 FAIL=0`, 9 `DAGR_DOC` lines |

These ARE scripted-port tests, and good ones — the MOT-136 script's in-memory filesystem is the
same idea as `WorldState.files`, built by hand. What they are not:

- They call `on_tool_handle` **directly** with a hand-built `ExtPorts` literal. Registration, the
  env gate, the `ext/runtime` fold, `tool_phase`'s dispatch, world-token reseating, origin
  tagging, the ledger, and the tool result reaching the model on the next step are all bypassed.
- They are fixed scenarios outside `src/core/test/dst_harness.ail`: no dotted scenario ids, no
  `seed=`, no `trace` lines on failure, no recorded program, no replay.
- Each hand-rolls its own scripted herdr (~100 lines duplicated between the two scripts; there is
  no herdr-aware fixture in `src/core/test/ext_fixture.ail`).
- The one non-hermetic leg — `dagr check --strict` against the pinned 0.3.1 binary — skips in CI
  because no workflow installs the plugin (the 2026-09-02 handoff's "one gap").

## 4. What a `driver_plus_herdr` profile would add

1. **The integration surface, driven by the real driver.** A graded session through
   `Session` with herdr installed via `register_with_config`, the scripted model (`stub_step`'s
   `tool_step`) emitting a `Delegate` call and then `DelegateCheck` calls, and the herdr CLI
   transcript served from `WorldState.ext_effects`. This is the shape `driver_plus_compose_dst.ail`
   already runs for compose (its `ext_effects` block at lines 546-645 and the `RecordingWorld` run
   at 663).
2. **The first tool dispatch any DST run reaches** (register entry 19), and the first profile that
   can stop waiving `extension_effect_fault` — the class whose delivery seam is exactly the port
   herdr calls.
3. **Fault injection at the herdr CLI boundary**, reaching named recovery branches herdr already
   has: `pane split` fails → no task (`do_delegate`, `herdr.ail:620`); a spawn that fails after
   the split → task born failed (F3); tag fails → note, delegation still succeeds (`tag_owner`,
   `:481`, D1); `agent explain` not ready; envelope undecodable (`code == -1`, `:205`); deadline
   overrun on `agent wait` — the "4000ms wait returned at 4201ms; 25s bound overrun to 28.3s"
   measurement that `register.ail` cites, injectable through `ScriptedTool`'s deadline field.
4. **Virtual time.** `check_wait_ms` and `start_timeout_ms` sit under Motoko's 30s process wall by
   construction (021 §3.1). With `clock_ms` advancing by scripted `duration_ms`, that becomes an
   asserted invariant over the ledger instead of a measured margin in a comment.
5. **Seeded families**, invariants only, per the framework's two rules. Draw the interleaving of:
   answer file appears before/after a check; `agent wait` returns `working`/`idle`; `pane list`
   contains orphans whose owner pane is live or dead; `HERDR_SWEEP_STALE` set or not. Assert:
   every published run file decodes and its task states never move backwards; `DelegateCheck` is
   idempotent after settle (§3.5); the sweep runs at most once per session (`sweep_once`, `:565`);
   a `report-metadata` argv appears only after a successful `pane split`; no `pane close` argv
   appears without the opt-in or ownership of the delegate.
6. **`dagr.ail` at L0.** It is 100% pure, so its transitions (`open_task`, `open_retry`,
   `mark_blocked`, `settle`, `latch_ack`) are property-testable and Z3-provable without DST at all.
   The strict `dagr check` leg stays as the external contract oracle.
7. **Record and replay.** A recorded program for a delegation lifecycle becomes a regression
   artifact; the strict replay serves the herdr transcript from its own cursor.

## 5. What it cannot reach

- herdr itself, tmux, the herdr server, `pane split`'s real behaviour, the `dagr view` render, and
  the TypeScript reap-on-exit (`src/tui/src/herdr-reap.ts` is L2 territory, `bun test`).
- The handoff's open finding **C** (`agent_not_ready` on an agent herdr itself started, 2/2
  reproducible) is a herdr-side race. DST can only pin how the extension handles the observed
  sequence once a live repro has established what the sequence is.
- `dagr check --strict` needs the binary. It stays a CI leg; the profile does not replace it.
- The live [`TESTPROMPT-integration-exercise.md`](TESTPROMPT-integration-exercise.md) remains the
  only coverage for all of the above.

## 6. Costs and gotchas, measured

- **`ext_effects` is served in order, not matched by argv** (`world_ext_effect`, `ports.ail:1499`).
  Argv assertions therefore come from the recorded interactions — which is precisely what the
  MOT-133 script does through the world token today, so nothing is lost.
- **The gate reads real env at registration.** `herdr_env_ready` (`register.ail:121`) needs
  `HERDR_ENV`, `HERDR_BIN_PATH`, `HERDR_PANE_ID`; tagging needs `MOTOKO_SESSION_MS`. The make
  target sets them for the `ailang run` process; the profile discloses the `Env` grant across
  registration the way compose discloses `Env`/`FS`.
- **The shared omission string is wrong about herdr.** `barrier_reason()` at
  `dst_driver_plus_compose.ail:516` is applied wholesale to the list at `:535`, which includes
  `herdr`, and says *"Three barrier slots stand for it — on_pre_step, on_response_intercept and
  on_solver_candidate each declare a non-empty ABI effect row"*. herdr binds none of the three
  (§2.4). When herdr leaves the omit list this reason must be split, and it is a finding for
  project 009's register regardless.
- **A fourth profile is a fourth consumer of register entry 14** (the `driver_only`-verbatim waiver
  condition in the fault catalogue). Not a blocker, but the count moves.
- **Register entry 8** — the bridge hardcodes `workdir: "."` and `timeout_ms: 0` on the
  `ToolInvocation` (`session.ail:1072-1073`). Inert for herdr: the delegate's cwd travels
  explicitly in the `pane split --cwd` argv, not through the invocation's workdir.
- The `path_within` sandbox guard (`AILANG_FS_SANDBOX`) is a non-issue under the scripted
  filesystem arm; it matters only for the live arm, which a herdr profile would not use.

## 7. Recommendation — two steps, the first cheap

**Step 1 — move what exists into the harness.** Extract the scripted herdr that
`verify_mot133_owner_tag.ail` and `verify_mot136_dagr_producer.ail` each hand-roll into one
fixture (a builder that turns a herdr CLI transcript into `ScriptedTool` entries plus the
`ExtPorts` literal over an in-memory filesystem). Re-register their 16 cases as `dst_harness`
scenarios with dotted ids — `herdr.l1.owner_tag.*`, `herdr.l1.dagr_producer.*` — under one
`scripts/dst/herdr_l1_dst.ail`, give it a make target with the narrowest caps that pass, and
chain it into `DST_TARGETS` (`Makefile:436`). This buys `scenario=`/`seed=`/`trace` reporting and
the anti-silent-drop count for a few hours' work and changes no behaviour.

**Step 2 — the profile.** `src/core/dst_driver_plus_herdr.ail` v1 mirroring the compose record;
`scripts/dst/driver_plus_herdr_dst.ail` running the graded session (`Delegate` →
`DelegateCheck` working → `DelegateCheck` done) against a scripted transcript, then
`check_discovery`, `validate_program`, strict replay, and the `CLASSIFICATION`/`STATEMENT`/`CLAIM`
lines in the nine-field shape D27 §10.1 fixes; one seeded family from §4.5; the
`extension_effect_fault` waiver dropped and a fault row that injects a failing `pane split`. Then
the omit-list correction in the compose record, the make target, `DST_TARGETS`, and the CI
workflow's target list.

Step 1 is worth doing on this branch. Step 2 is a project-009-shaped item and belongs on that
register next to `compaction_ai`, with this note as its pricing.

## 8. Verified versus inferred

Verified by command or by reading the code this session: every line reference above; the
classifier outputs in §2.1 and §2.2; the port census in §2.3; the two verify-script counts in §3;
the three profile versions; the register entries quoted from `NOTE-d28` §9.1; the `barrier_reason`
list membership.

Inferred: that the unresolved receiver `f` is `dagr_record`'s parameter (its name and the fact it
is the only function-typed parameter in the module make this near-certain, but the classifier does
not print the site); that the graded session for herdr needs no world change beyond what compose
used (every port herdr calls has a scripted arm, but no run has yet exercised a `ToolProvider`
dispatch end to end — register entry 19 — so the first attempt may find a seam the compose run did
not).
