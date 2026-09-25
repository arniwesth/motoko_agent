# RESEARCH: EnvHarness (arXiv 2608.19880) — what Motoko can take from it

Date: 2026-08-24
Status: Research note (no decision taken; candidate ADR/PLAN listed in §7)
Grounded at: branch `arniwesth/mot-128-improve-dev-env`, HEAD `366193c`
Paper: Huang et al., *EnvHarness: Awakening Static Worlds for Agent Learning*,
Google Cloud AI Research / WashU / UNC, arXiv:2608.19880v1 (20 Aug 2026).
Code: github.com/google-research/envharness

Relates to:
- `../001_DST/` and `papers/motoko-dst-report/DRAFT.md` — the ports-swap world this note
  argues is already an EnvHarness instance (§3).
- `design_docs/planned/m-motoko-dp7-verifier-gate.md` — DP7 is one Contract (§4.1).
- `design_docs/planned/m-motoko-tool-policy-pending.md` — the seam Contracts would live at.
- `design_docs/planned/m-motoko-trajectory-memory.md` — the paper carries a negative result
  that bears directly on this deferred item (§4.4).
- `.agent/research/Gemma4_AILANG_GRPO_Reinforcement_Learning.md` — the paper's RL half; noted
  as out of scope for Motoko in §5.

---

## 0. TL;DR

EnvHarness wraps a frozen environment with plug-in components (Stage / Contract / Chain) at
its `reset`/`step` interface, and automates writing those components with an LLM loop
(EnvRigger: Observe → Diagnose → Write → Validate) that targets a specific policy's observed
weaknesses. Motoko's DST world (`src/core/ports.ail`) already instantiates every element of
the paper's formal model — but with the *harness* as the party under test and a *PRNG* as the
designer. The transferable gains, in order of confidence:

1. **Contracts as a production feature** — enforce interaction rules at the tool boundary
   (read-before-edit, duplicate-call breaker, observation windowing). Paper's best-evidenced
   effect: −10% steps on SWE-bench Verified. Directly cost/wall-clock for Motoko. ~1 day.
2. **Stage/Chain as an evaluation axis** — perturbed polyglot exercises (OOD) and concatenated
   exercises (premature-`done` probe). Runner-level change, no core code.
3. **Per-model rigging** — an automated Observe→Diagnose→Write→Validate loop emitting
   compose hooks / skill files per provider profile. The concrete shape of "self-evolving."
4. **A constraint on trajectory memory** — never inject unvalidated skills; the paper shows
   skills from unmodified environments can *degrade* performance.

Out of reach: the RL result (Motoko trains nothing). Honest caveat: the paper's SWE gains are
small (+2.7, within 1σ) and Gemini-only; only item 1 has a low-variance metric Motoko can
measure on its current benchmark.

---

## 1. The paper, compressed

### 1.1 Thesis

Agent environments are hand-built and static: they can't target a given agent's weaknesses and
have nothing left to teach once solved. Generated environments (SWE-smith, GenEnv, VeriEnv) are
domain-specific and rely on LLM-written verifiers that must be over-generated and filtered.
EnvHarness instead *wraps* an existing environment at the interface, leaving the simulator and
its human-built verifier untouched — the mirror image of an agent harness wrapping a frozen LLM
(the paper's Table 1 cites Anthropic/OpenAI agent-harness work explicitly).

### 1.2 Formal model

Environment `E = (S, A, O, T, R, s₀)`; a component is an interface-level rewrite
`E' = w(E)` that never touches the simulator backend. Components compose, non-commutatively.

| Component | Parameter | Overrides | Effect |
|---|---|---|---|
| **Stage** | action sequence δ | `reset()` | `s₀' = T(…T(s₀,a₁)…,aₖ)` — replay δ after reset; hide the object, or pre-complete subgoals |
| **Contract** | `(f_A, f_T, f_O)`, default identity | `step()` | mask actions; add preconditions / block transitions; truncate or augment observations |
| **Chain** | `(E_ext, g)` | both | concatenate environments; `R'` = conjunction of both original verifiers |

### 1.3 EnvRigger

Task-policy-conditioned map `H(E, t; π) = (w_k ∘ … ∘ w₁)(E)`. Policy is a black box.
- **Observe**: roll out π on task t; successes bound the flaw, failures expose it.
- **Diagnose**: root-cause from trajectories — repetitive action loops, mis-parsed long
  observations, misread tool constraints. Direction: scaffold if struggling, harden if at 100%.
- **Write**: synthesize one or more components (e.g. a Contract that blocks a shortcut).
- **Validate**: fresh rollouts on the wrapped env; accept / reject (unsolvable or trivial) /
  revise, until accepted or revision budget exhausted.
Assumes deterministic `reset`. Chain is **excluded** from the automated loop (rigger can't
observe joined internal state).

### 1.4 Results (skill-based learning; rigger and policy share a backbone)

| Benchmark | Metric | No skills | Skills from original env | Skills from EnvHarness env |
|---|---|---|---|---|
| ALFWorld OOD | SR | 60.7 | 61.4 | **70.4** (+9.0) |
| WebArena avg | SR | 38.7 | 38.5 | **41.6** |
| SWE-bench Verified | SR | 47.67±0.93 | 49.88±2.59 | **52.58±2.72** |
| SWE-bench Verified | avg steps ↓ | 53.58 | 55.01 (worse) | **49.61** |
| OfficeQA | EM | 54.23 | 54.40 | **56.20** |
| SpreadsheetBench | Pass@1 | 46.44 | 45.88 (**below no-skills**) | **49.15** |

Backbones: Gemini-3.1-Flash-Lite (ALFWorld, WebArena), Gemini-3.5-Flash (rest).
Skill extraction follows ReasoningBank. Scaling (Fig. 5): under a 300-environment budget on
SWE-bench, EnvHarness reaches 54.79 and is still climbing; original envs 52.13; SWE-smith 50.37
and flat. Chain-only skills cut SWE steps 53.58→41.96; Stage/Contract+Chain: SR 54.30, 43.12
steps. RL (GRPO, Qwen3-8B-base): ALFWorld in-dist 81.4→87.9; WebShop score 75.6→79.2.

### 1.5 Stated limitations

- Design-loop cost: each candidate needs real rollouts; weak designers need more iterations.
- Requires a resettable gym-style interface over *text* actions/observations — excludes live
  services and physical systems.
- Chain is purely sequential; composite verification only works as conjunction of leg verdicts.

---

## 2. Why this paper and not the others in `papers/README.md`

Meta-Harness (2603.28052) optimizes the *agent* harness end-to-end; EnvHarness optimizes the
*environment* side and treats the agent (model + harness) as a black box. For Motoko the
distinction matters: Meta-Harness would tune Motoko; EnvHarness would tune what Motoko is
*run against*, and would do so per model. The two are complementary, and the DST world is the
substrate both would need.

---

## 3. The structural claim: Motoko's DST world is an EnvHarness pointed at the wrong party

### 3.1 The isomorphism

| Paper | Motoko DST | Location |
|---|---|---|
| `S` | `WorldState` {script, clock_ms, approvals, env, files, tools, ext_effects, holder_ext_id, log, gen} | `src/core/ports.ail:183` |
| `A` | `ToolInvocation` (typed `ToolCallEnvelope` + workdir + timeout) | `ports.ail:548` |
| `O` | `ToolExecution.outcome` content, `FileRead`, `EnvRead`, `DirListing`, `PathStat` | `ports.ail:579–699` |
| `T` | the 11 non-model `Ports` slots (`tool_exec`, `file_write`, `dir_make`, `clock_now`, …) | `ports.ail:783` |
| `s₀` | seeded `WorldState` (synthetic FS + env map + scripted tool queue) | `empty_world_state`, profile worlds |
| `R` | 12 invariant families over the ledger | `src/core/dst_invariants.ail:205` |
| `reset` | a world is a pure value — reset is free | by construction |
| Stage | authoring `WorldState.files`/`env`/`tools` directly | (the paper must replay δ through `step()` because its envs are opaque objects) |
| Contract `f_T` | `ScriptedTool` queue → `scripted_tool_outcome` → `ToolCorrelationMismatch \| ToolDeadlineExceeded \| ToolFailed \| ToolCompleted` | `ports.ail:1465` |
| Contract `f_O` | `ScriptedTool.content`, synthetic FS contents | same |
| Contract `f_A` | **absent** — tool list built in `live_ports` via `tools_with_extensions(rt)`, never crosses a port | `src/core/test/stub_step.ail:186` |
| Chain | **absent** — sessions are single-task | (`dst_program` has an execution-program schema that could be concatenated) |
| EnvRigger | seeded discovery: `choose_provider`/`choose_tool`/`choose_approval` write the challenge; invariants diagnose; violations promote to regression members | `src/core/dst_generator.ail:612` |

Two places Motoko is *ahead* of the paper:
- Every fault-catalogue row declares a `logical_transition` (ADR D3: did the all-or-nothing
  update commit or not). EnvHarness's Contract never formalizes commit semantics.
- The ledger is a typed `Interaction` log with `CausalIdentity`, `fault_class_id`, virtual
  timestamps and commit facts — a far richer Diagnose input than the raw text trajectories
  EnvRigger reads.

### 3.2 "Wrong party", in two exact senses

**The party under test.** DST probes the *harness*; the model is part of the environment.
`choose_provider` draws a tool from `{"T","BashExec","Read"}`, args `{"n":N}` (malformed
1-in-8), terminates with p=¼, faults with p=2/12 — a random walker whose job is branch
reachability. This is Decision 4 of the origin ADR: *"assert reusable structural invariants
over the trace — never final model prose."* Accordingly `R` is harness-shaped (tool pairing,
budget monotonicity, checkpoint chain, replay equality); no family asks "was the task solved."

**The party writing the challenges.** EnvRigger is an LLM writing *targeted* components.
Motoko's rigger is a Lehmer PRNG (`prng_multiplier() = 48271`), uniform by design — the
seed-sensitivity and canary checks exist to prove it is *not* biased. For harness fuzzing
uniformity is the virtue; for policy improvement it is the vice (the paper's Fig. 5 is exactly
"unconditioned scaling flattens, diagnosed customization climbs").

Both choices are correct for what DST is for. The observation is only that a second purpose
is one adapter swap away.

### 3.3 What re-targeting would take (not proposed here; recorded for scoping)

1. A hybrid `StepProvider` variant — live `model_step` over scripted `file_*` / `world_tool` /
   `virtual_clock`. `Ports` is a plain record and `live_ports` already builds by record update;
   nothing but convention couples model and world. `world_tool`'s empty-queue arm already falls
   through to `dispatch_one_typed` (`ports.ail:1447`), so `RunTests` can stay real (= "inherit
   the original verifier").
2. Contract as request-conditioned *data*, not code: a rule table consulted before the PRNG in
   `choose_tool` (D2 already makes the choice a function of the bounded request projection).
   Rules serialize via the `dst_persistence` codec and validate against the fault catalogue
   (`validate_static_references`) — safer than the paper's LLM-written Python classes.
3. `f_A`: route the offered tool list through a port. Also closes a real coverage hole (no
   profile can currently observe what tool list the driver offered).
4. A task-shaped 13th oracle (terminal `files` table, or live `RunTests` exit code). The 12
   harness families keep running on the same ledger — every policy rollout is also a
   conformance run. EnvHarness has no equivalent.
5. Determinism: live model breaks `ReplayConsistency` for the live run — expected. Pattern is
   *roll out live once via `RecordingWorld`, replay deterministically forever*. Validate needs
   the live half; regression needs the recorded half; both exist.

Known gaps that carry over: 10/15 extensions in no profile, 14/15 with no dynamic evidence
(D28); the synthetic FS is a point-read map with no sandboxed shell, so "seed a broken build"
Stages need the real arm and reintroduce ambient state `HarnessHygiene` will flag.

---

## 4. What Motoko could actually gain

### 4.1 Contracts as a production feature — highest confidence

Today interaction rules are prose in `SYSTEM.md` ("prefer ReadFile before EditFile"). A
Contract enforces the same rule at the tool boundary. Three candidates, each mapping to a
diagnosis the paper reports as the source of its efficiency gain:

| Contract | Type | Rule | Paper diagnosis it targets |
|---|---|---|---|
| read-before-edit | `f_T` | reject `EditFile` on a path with no `ReadFile` this session; return a typed fault telling the model to read first | "misread tool constraints" |
| duplicate-call breaker | `f_T` | reject a `BashExec`/`Search` byte-identical to the previous call; fault message names the repetition | "repetitive action loops" |
| observation window | `f_O` | cap `ReadFile`/`BashExec` output at N lines with an explicit "call again with start/end" trailer | "failures in parsing long observations" |

Evidence: SWE-bench steps 53.58 → 49.61 (−7.4%) from Contracts alone; Contract+Chain skills
→ 43.12. Step count is low-variance, so this is measurable on the polyglot Python track
without seeds. DP7 (no `done` while `ailang check` fails) is the same shape applied to the
terminal action; `m-motoko-tool-policy-pending` is the seam. Cost is bounded: each Contract
is a predicate in `tool_phase` / an `on_tool_handle` hook.

Risk: a Contract that fires wrongly is a new way to loop. Each needs a per-session budget
and a ledger event (mirrors the `EmptyStopFinalize` floor from project 005).

### 4.2 Stage / Chain as an evaluation axis — cheapest, most informative

`benchmarks/aider_polyglot.py` measures in-distribution solve rate only. The paper's largest
gain (+9.0) is OOD. Stages are git states applied to the exercise copy in `_copy_exercise`:

- hide the stub behind a misleading filename; leave a decoy
- seed a stale `ailang.lock` / broken lockfile
- pre-solve half the task (does the agent notice and not redo it?)
- plant a failing *unrelated* test (does the agent fix the wrong thing?)

Chain = two exercises in one session, verifier = both test suites green. This is the cheapest
probe for premature `done`, the failure DP7 exists for. Both are runner-level; no core code.
Gain: distinguishes "solves Exercism" from "handles a repo that fights back," per model.

### 4.3 Per-model rigging — the concrete shape of "self-evolving"

Motoko is multi-provider and failure modes are model-specific: DP7's motivating bug is GLM-5
hallucinating `std/json.stringify`; Gemma has a thinking-mode knob; Claude needs different
guards. EnvRigger's loop, aimed at the policy with the same backbone as designer:

```
Observe   run polyglot track; collect polyglot_events_<run>.jsonl + per-exercise attempt logs
Diagnose  tool_failures.py / error_breakdown.py (+ the DST ledger if the hybrid world exists)
          → textual diagnosis by the same model
Write     emit a compose hook (Contract) or a skill file (ext_skills_import / agents_md)
Validate  fresh runs on held-out exercises; accept only if pass-rate or steps improve
```

Accepted components live under `.motoko/config/<provider>/`. This gives the skills-import and
`agents_md` machinery a *supply side* that is currently missing, and replaces one hand-written
design doc per model failure with a loop. Fits the Phoenix constraint (no human-written code).
Effort: medium — compose ext, profiles, runner and ledger exist; the loop script does not.

### 4.4 A constraint on trajectory memory — free

`m-motoko-trajectory-memory` (deferred, P3) is naive skill extraction from unmodified runs.
The paper's negative result: skills from *original* environments fell below no-skills on
SpreadsheetBench (45.88 vs 46.44) and lengthened SWE trajectories (55.01 vs 53.58), because
they "only allow the agent to practice behaviors it already executes." Adopting the concept
means one sentence added to that design doc: **no skill is injected without validation on
held-out tasks.** Without a rigger/validation gate the feature is more likely to hurt than help.

### 4.5 Harness-bug yield from policy rollouts — secondary

If §3.3's hybrid world existed, every rigger rollout would also evaluate the 12 invariant
families, producing the "what has DST actually found" evidence reviewer R1 asked for in
`papers/motoko-dst-report/REVIEW-round1.md` #4. Real, but a by-product; not worth doing alone.

---

## 5. What is *not* gained

- **No RL.** Motoko has no training loop and its policies are third-party APIs. Table 4 of
  the paper (GRPO) is out of scope; see the Gemma4 GRPO research note for the separate
  question of fine-tuning a local model.
- **Small effects, small N.** The SWE SR gain is +2.7 within 1σ. Motoko's Python track is
  small enough that a 3-point delta is noise without seeds. Step count (§4.1) is the one
  low-variance metric available today.
- **Rigger cost.** The paper's own limitation. With Gemma-class local models as both policy
  and designer, expect many rejected candidates per accepted one.
- **Chain is hand-authored** in the paper too; treat it as an eval, not a generator.
- **Text-only.** Irrelevant to Motoko (TUI, text tools) but noted for completeness.

---

## 6. Open questions

1. Does a Contract fault (typed tool-role message) reliably change model behavior across
   providers, or do weaker models loop on the fault itself? (Paper reports it works with
   Gemini Flash; unverified for GLM/Gemma.)
2. Where does the read-before-edit state live — `WorldState` (so it is world-mediated and
   DST-visible) or `C2LoopState`? The former is the D1-correct answer and makes the Contract
   testable under the existing profiles.
3. Is the observation window a Contract or is it `context_mode`'s job? They overlap; the
   Contract version is per-call and cheaper to reason about.
4. Is per-provider profile output (`.motoko/config/<provider>/`) the right home for rigger
   artifacts, or do they belong in the extension package format
   (`m-motoko-extensions-as-packages`)?

---

## 7. Recommended next steps

1. **PLAN-contracts-v0** (~1 day): implement the three Contracts of §4.1 behind a profile
   flag, with ledger events and per-session budgets. Measure avg steps and pass rate on the
   polyglot Python track, before/after, one model. This is the go/no-go for everything else.
2. **NOTE-stage-variants** (~½ day): add 3–4 Stage perturbations and one Chain pair to
   `aider_polyglot.py` as named variants; run once per configured model; record OOD delta.
3. Add one sentence to `m-motoko-trajectory-memory.md` (§4.4) now.
4. Add the paper to `papers/README.md` under *Agent Harnesses & Architectures*.
5. Only if (1) shows a step reduction: ADR on the hybrid live-model/deterministic-world
   profile (§3.3) and a rigger loop script (§4.3).

---

## Appendix — paper facts likely to be misquoted

- "Up to 9.0 points" is ALFWorld OOD only; SWE-bench is +2.70 SR.
- "9.8% fewer steps" is relative to *original-env skills* (55.01→49.61); relative to
  no-skills it is 7.4%.
- EnvRigger and policy use the **same** backbone; gains are not distillation.
- Chain is **excluded** from the automated EnvRigger loop.
- Deterministic `reset` is an explicit assumption, not a contribution.
