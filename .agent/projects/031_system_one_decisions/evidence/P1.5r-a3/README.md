# P1.5r-a3 evidence: the last ABI-text readers and the absorption re-pins

PLAN-001 (031) line R, third follow-up on P1.5r. Brief: `LEG-P1.5r-a3.md`. HEAD before: `c11bb106`
(the R-G pre-gate record at `12a8ecd9`). AILANG `v0.33.0`. Outputs are in `CHECKS.log`. The mutgate
spec is `p15ra3_mutgate_spec.tsv`, the runner is `p15ra3_mutgate.sh`, the test harness is
`p15ra3_test.sh`, the verdicts are in `mutgate-result.tsv`, and each mutated run's red reason is in
`MUTGATE-red-reasons.txt`.

## 1. `check_fixtures.py` — the omission-basis reader (`profile_definition`, `driver_only`)

`check_omission_basis()` read `BudgetShaper\(\(ExtCtx,\s*BudgetPlan\)…`. At 8.0 the payload is
`BudgetShaper((PureCtx, BudgetPlan) -> BudgetPatch)` (`types.ail:1945`), so the function failed with
"could not read `Capability.BudgetShaper`'s payload". The pattern now names `PureCtx`
(`check_fixtures.py:166`), which is how P1.5r re-pointed `run_declared_vs_performed.sh:128`. **What it
asserts is unchanged.** It still captures the return type and requires `BudgetPatch` to carry no
`next_state`. It still captures the row and requires it to be absent (WI-B4's omission basis). The
unconditional-dispatch and `compaction_ai`-omitted clauses were not touched. The context is matched
exactly, not as `\w+Ctx`: a re-signed context is a changed payload and a major bump, so it should turn
this red.

## 2. The ABI-text readers: the full sweep of `tools/`, `scripts/` and the `Makefile`

I swept every file that reads `packages/motoko-ext-abi/types.ail` (`Makefile`,
`run_declared_vs_performed.sh`, `ext_ambient_inventory/{derive,hook_scope}.py`,
`ext_call_inventory/derive.py`, `profile_definition/{check_fixtures,check_compose_profile,check_no_op_profile}.py`)
for regex, `grep` and `awk` patterns over the ABI text. I also grepped every string or regex literal
in `tools/` and `scripts/` for a `*Ctx` name next to a `Capability` payload form, and every `.ail`
file for a runtime read of the ABI text (there is none).

**Readers that name a context inside a `Capability` payload.** There are three, and they are all of them:

| reader | pattern | matches at 8.0 |
|---|---|---|
| `tools/profile_definition/check_fixtures.py:166` | `BudgetShaper\(\(PureCtx,\s*BudgetPlan\)\s*->\s*(\w+)\s*(!\s*\{([^}]*)\})?` | `types.ail:1945`: ret `BudgetPatch`, no row. **Fixed here** (was `ExtCtx`) |
| `scripts/dst/run_declared_vs_performed.sh:128` | `grep -n 'BudgetShaper((PureCtx, BudgetPlan)'` | `types.ail:1945`, no `!`. P1.5r, already 8.0 |
| `scripts/dst/run_declared_vs_performed.sh:720` | `grep -qF "Compactor((AiCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace})"` | `types.ail:1946`. P1.5r, already 8.0 |

**ABI readers that name no context** (swept; not affected by the 8.0 re-sign):

| reader | pattern | reads |
|---|---|---|
| `check_fixtures.py:592` | `^export type Capability\b(.*?)(?:\n\s*\n\|\Z)`, then `(?:=\|\\\|)\s*([A-Z]\w*)\s*\(` | all 12 variants' payloads (row reader), by constructor name |
| `ext_ambient_inventory/hook_scope.py:214` | `^export type Capability\b\s*=(.*?)(?=^export\s)` | variant arity and binding positions |
| `Makefile:760` (`profile_coverage`) | `awk '/^export type Capability/,…'` + `grep -cE '^…[=\|]…[A-Z]…\('` | the variant count (12) |
| `run_declared_vs_performed.sh:647` | `grep -A3 "^  \| $kind("` | the WI-D7 slot rows, by kind name |
| `run_declared_vs_performed.sh:712` | `grep -qF "ai_step: (ExtWorld, string, [Msg]) -> AiStepOutcome ! {AI, IO, Trace}"` | a port signature, not a payload |
| `run_declared_vs_performed.sh:153`, `:685` | `BudgetPatch ! {`, `(ResponseInterceptOutcome\|FinalizeOutcome) ! \{…\}` | staleness greps over the tree, return type plus row |

`ExtCtx` still occurs in `tools/` and `scripts/` outside these readers. None of those occurrences is an ABI-text regex:

- `tools/eval_protected/manifest-A.json:2248,2875`: a protected-file manifest (import lists), not a reader.
- `tools/ext_ambient_inventory/hook_scope.py:557,809` and `tools/ext_call_inventory/fixtures/expected.json:58`: docstrings and a fixture's prose.
- `run_declared_vs_performed.sh`, AILANG **probes**, not readers. See §3 for the ones that bind into the imported ABI sum. The other three are left on `ExtCtx` on purpose, because none of them binds into `Capability`:
  - `write_upd` measures a LOCAL `ExtensionHooks` record that mirrors the 5.x slots, and its comment says so.
  - `write_slot_mutant` and `write_port_probe` are named functions checked against their OWN row, never bound into a slot. Their comment says the parameter list "takes no part" in the check.

  `ExtCtx` is still an exported ABI type at 8.0 (the host's context), so all three compile as written.

## 3. The B8 block and its siblings (`declared_vs_performed`)

**`IMPORTED SUM (named-wide)`** was rejected with "record field mismatch: expected 24 fields, got 23".
That is the context (`ExtCtx` into an `AiCtx` slot), not the row, so the row reported that it "establishes nothing". On `AiCtx` it is rejected with
`incompatible closed rows: r1 has extra labels [], r2 has extra labels [Env]`, which is exactly the Env label the row measures. The
row now requires that exact message and no longer accepts any closed-row failure.

**The siblings. Measuring them found something the brief could not have known.** On v0.33.0, an inline
lambda's PARAMETER annotation in constructor-argument position is **not unified with the payload at
all**. `Compactor(func(ctx: int, …) …)`, `ctx: Bogus` and an unimported `ExtCtx` all `ailang check` clean,
and the verdicts below were byte-identical on `ExtCtx` and on `AiCtx`. This is the gap LIMITATION 3 already pins
(`ctx.ports` on a `PureCtx` accepted; fb_30e82f6bdc5fc8c3), seen from the parameter side, so it is
not a new upstream report. Consequences, per row:

| row | on `ExtCtx` (before) | on `AiCtx` (now) | change |
|---|---|---|---|
| named-wide | rejected on the CONTEXT (red) | rejected on `[Env]` alone | re-pointed; message pinned exactly |
| **named-exact** (new) | would be rejected on the context | accepted | **added**: the two-sided control named-wide lacked. A named impl at exactly the row and context compiles, so named-wide's rejection is the label |
| unannot | rejected on `[Env]` (passed, but it accepted ANY rejection) | same | re-pointed; **tightened** to require `incompatible closed rows` + `r2 has extra labels [Env]`. It had been the one sibling that would have passed on the wrong reason |
| annot | rejected at its own annotation | same | re-pointed (already required `uses effects not declared in its`) |
| exact-ctl | accepted | accepted | re-pointed; context-independent, as measured |
| smuggle | accepted | accepted | re-pointed; context-independent |
| **8.0 context** (new) | would be red | green | **added**: the probes' own text may name no context but `AiCtx`. The compiler cannot see a stale context in an inline probe, so this row does |

The same class outside the block: `mutant_register`'s inline Compactor now uses `AiCtx`, and
`mutant_budget` (the BudgetShaper mirror) now uses `PureCtx`. Neither verdict moved, for the same
reasons (inline lambda; named function never bound). Row count: 135 → **137** (named-exact and 8.0 context).

## 4. The four absorption re-pins, and what they mean

These are measured by hand from the rows, `packages/*/**.ail` `func register_with_config.*!`, at
HEAD, against `bff0948f` (the P0G tree, 7.4):

| | 7.4 (`bff0948f`) | 8.0 (HEAD) | what moved it |
|---|--:|--:|---|
| rows (denominator) | 17 | **16** | `compose.ail`'s real registration is rowless now: it writes `{ config, caps: compose_caps() }`, and `compose_caps()` is a rowless list of named payloads |
| Env | 17 | **16** of 16 | only the row that vanished. Every registration reads Env for its `config` |
| FS | 15 | **13** of 16 | `compose.ail` (rowless) and `agentcli` (`! {Env, FS, IO, Process}` → `! {Env}`) |
| Process | 9 | **3** of 16 | out of `agentcli`, `ailang-docs`, `compaction-ai`, `context-mode`, `exa-search`, `compose.ail`. Left: `herdr`, `omnigraph`, `compose/register.ail` |

**Why.** 8.0 (P1.2b-d) moved every effectful payload out of the registration function into a NAMED
top-level function carrying its slot's row, bound directly. A registration's row now covers only what
it reads to build `config`. The pinned denominator stays arithmetic: `N_EXTS - 3 rowless + 1`
(compose's second function). The comment names the third rowless registration.

**What it means for how much the WI-D6/D7/D8 slot narrowings actually enforce.** The counts measure one
door, and at 8.0 it is the smaller one:

1. **An atom bound straight into the imported `Capability`**, named or inline without the smuggle, is
   checked by the compiler against the payload row (§3's named-wide/unannot/annot rows). Every extension atom
   is now named (`make ext_hook_scope`: 0 binding rejections), so the narrowed slot rows are compiler-enforced for every
   binding that exists, and no registration row takes part. This is the larger change, and the
   absorption counts do not see it.
2. **The record-field smuggle** (limitation 1, the `smuggle` row) is the one form that still bypasses
   the payload row. Its bound is the enclosing registration row, and the counts say where the compiler
   alone would let a smuggled effect through:
   - **Process in 3 of 16, down from 9.** All three rows are over-declared: by their callees' own rows,
     the bodies of `herdr` (`orchestrator_mode ! {Env, FS}`, `read_run_docs ! {FS}`, the rest pure or
     rowless), `omnigraph` (`enabled_in`/`load_agent_prompt ! {FS}`) and `compose/register.ail`
     (`read_compose_host_config ! {FS}`) perform only Env and FS. No registration needs the door open
     for Process. I recorded this and did not fix it: narrowing those rows belongs to those packages.
   - **FS in 13, down from 15.**
   - **Env in all 16, as before.** The narrowings enforce nothing against a smuggled Env read through this
     door.
3. **And the door is shut one level up, by a check that is not the compiler.** The 8.0 shape rule
   (`hook_scope.py:1266`, ADR-001 D2) passes a payload only when it is a bare name resolving to a
   top-level `func`. `w.f` and an inline lambda are shape rejections, so `ext_hook_scope` refuses a
   smuggled atom before any row is consulted. The counts are therefore what the compiler alone would
   allow, which is also the upper bound on what a shape-rule regression would re-open. They are an upper bound for
   delegating registrations too (`compose_caps`, `herdr_caps` are rowless helpers, and a smuggle there is
   bounded by the helper's row).

This explanation is in the runner, above the `absorb` calls, and in `declared_vs_performed.ail`'s
absorption note (a new block after the WI-D8 counts). I inserted it after line 450, so the runner's
`declared_vs_performed.ail:410-420` reference still points at the same text. The `absorb` pass
message no longer says "an inline hook … compiles silently", which stopped being true at 6.0/8.0. It
now says a record-field-smuggled atom compiles there and the shape rule refuses it.

## 5. Exit checks

1. **Green in the primary checkout** (`CHECKS.log`, run on the bytes this commit carries; nothing else
   was writing): `make profile_definition` exit 0 and `make driver_only` exit 0 (both print "✓ omission
   basis intact: … declares NO effect row … returns BudgetPatch (no successor)"), `make
   declared_vs_performed` exit 0 at **137 passed, 0 failed** (it was 130/5), and, as a check on §4's
   shape-rule claim, `make ext_hook_scope` exit 0. The P0.2/P0.2b ADR section was not touched.
2. The ABI-text regexes are listed in §2.
3. The re-pins are explained in §4.
4. **mutgate, 7/7 discriminate** (`p15ra3_mutgate.sh --overlay`: a fresh `git clone --shared` of
   `c11bb106` with this part's four paths copied over it, lock regenerated in the throwaway; `start
   2026-09-21T21:33:26Z`). Every row went baseline GREEN → mutated RED → restored GREEN, bytes `same`.
   The red reasons below are from `MUTGATE-red-reasons.txt`:

| row | mutation | red because |
|---|---|---|
| `p15ra3_fixture_pattern_reverted_pd` | `check_fixtures.py` pattern → `ExtCtx` | `profile_definition`: "could not read `Capability.BudgetShaper`'s payload" |
| `p15ra3_fixture_pattern_reverted_do` | same | `driver_only`: same message |
| `p15ra3_b8_block_reverted_to_extctx` | every `AiCtx` in the B8 block → `ExtCtx` | named-wide "**establishes nothing**" (the 24/23 field mismatch), named-exact rejected, 8.0 context red; 134/3 |
| `p15ra3_b8_inline_probe_reverted` | only the exact-ctl inline probe → `ExtCtx` | 8.0 context row only ("names [ExtCtx]"); 136/1. The compiler alone would have stayed green here |
| `p15ra3_absorb_process_off_by_one` | `absorb Process 3` → `4` | "absorption of 'Process' moved from 4 to 3"; 136/1 |
| `p15ra3_absorb_fs_off_by_one` | `absorb FS 13` → `12` | "absorption of 'FS' moved from 12 to 13"; 136/1 |
| `p15ra3_denominator_arith_reverted` | `N_EXTS - 3 + 1` → `- 2 + 1` | "rows moved from 17 to 16"; 136/1 |

(In the block-revert row the 8.0-context message reads "slot takes ExtCtx", because the mutation also
rewrote `AiCtx` in that message's text. The row is red for the reason it names; only the wording was
mutated.)

## Not done, on purpose

- The TUI red (`env-server.test.ts` Jest teardown) is pre-existing at `2f3ee4d1`, and the brief leaves it to the operator.
- The three over-declared Process rows (`herdr`, `omnigraph`, `compose/register.ail`) are recorded, not
  narrowed. That is package work, and narrowing them would move the Process pin 3 → 0 by a measurement.
- No upstream report was filed. The inline-parameter laxity is the known gap fb_30e82f6bdc5fc8c3. It
  is worth adding the parameter-side reproduction (`ctx: int` accepted) to that ticket at the next AILANG
  bump re-test.
