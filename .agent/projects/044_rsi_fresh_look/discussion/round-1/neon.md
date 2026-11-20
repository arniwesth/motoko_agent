# neon — round 1

## 1. Current state as it bears on RSI

At HEAD `2eae0666` (AILANG `v0.60.4`, `563c6c9`; `ailang.toml:6`), Motoko has built heavy verification machinery but zero measurement of coding competence. Nearly half of `src/core/*.ail` (`25,508`/`51,552` LOC via `wc -l`) is `dst_*.ail`, beside `37,402` LOC in `scripts/dst/` and `15,083` LOC in `src/eval/journal/`. The positive base is real: 13 invariant families (`src/core/dst_invariants.ail:240-260`), `make corpus_pr` + `make corpus_judge` (16 bank runs + 6 two-channel checks; 14/14 table and 6/8 blind mutant kills at `ce9cb247`, `.agent/projects/011_improve_test_axises/evidence/judge-recoveries/acceptance-ce9cb247/README.md:17-24`), durable journals and cross-process resume (`src/core/journal.ail`; `Makefile:307-322`), park/wake (`src/core/step_machine.ail:124-131`), ABI 8.0 typed capabilities (`packages/motoko-ext-abi/types.ail:1942-1977`), headless JSONL mode (`src/tui/src/index.ts:742-744,764`), `motoko-ext-skills` (`packages/motoko-ext-skills/register.ail:1-15`), and a two-sided mutation discipline (`mutgate`, `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md:49-58`).

Four measured gaps block RSI today:

1. **No closed loop or competence oracle.** DST explicitly disclaims task quality (`README.md:165`; `.agent/projects/013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md:1114`). `tools/pr` stops at degree-1 manual approval (`Makefile:136-138`); `make demo_dst` is human-scripted (`docs/motoko-dst-demo-run-2026-10-04.md:47-53,138`); nightly promotion and shrinking are unbuilt (`README.md:101,162`). `benchmarks/` has only an outdated Python Exercism script (`benchmarks/README.md:5-20`, last touched `2f3ee4d1`), missing `polyglot-benchmark` and invoking `node src/tui/dist/index.js` (`benchmarks/motoko_rpc.py:21,82`) instead of `bun`. CI runs zero task benchmarks and no TUI Jest tests (`.github/workflows/verify-extensions.yml`; `.agent/projects/041_process_execution_timeouts/RECORD-session-W1-W5-2026-11-02.md:62`).
2. **Narrower coverage than headcounts imply.** Only 6 of 20 extensions (`ailang.toml:36-56`) appear in the four uncombined DST profiles (`src/core/dst_driver_*.ail`), while `default` loads 9 together — 5 uncovered, and `skills` omitted (`.motoko/config/default/config.json:42-52`). `declared_vs_performed` is broken on `v0.60.4` (`Makefile:662-676,717`); core runs no DP7 verifier (`src/core/session.ail:2908-2909`). Z3 reaches `285`/`1,542` `pure func`s (73 non-DST, `.agent/projects/027_z3_contracts/FINDINGS-implementation.md:256-266`); 38 of 82 `substantive` contracts (`tools/verify_classify/contracts.register:122`) are `ensures { result != "" }` on string literals (`src/core/tool_fault.ail:41-80`).
3. **Parked, non-recursive journal evaluator.** `scripts/eval/journal_replay.ail:238,292` refuses every `RealEntry`; `tools/eval_protected/manifest-A.json:3` is 872 commits stale (`protected.py check --tree HEAD` gives `20 findings -> REFUSED`); `scripts/eval/candidate.py:210` pins AILANG `ae36986c` (`v0.33.0`), restricts diffs to `"resource-only"` (`:165,185-205`, banning prompts, tools, extensions), and assumes cooperative trust (`ADR-004:1122-1130`).
4. **Severe self-edit friction.** `check_core` took `145.5 s`, cold `corpus_pr` `88 s` (`59 s` compile), and cold serial `make dst` `2,408–2,670 s` (`.agent/projects/028_verified_runtime_closing_the_loop/NOTE-010-sixth-session-long-demo-issues.md:17`; `evidence/D11-CEIL/RESULT.md:32,40,179-180`), yet `default` kills `BashExec` at `30 s` (`NOTE-010:69-77`), `session.ail` is `5,959` LOC, and Motoko failed 3/3 source-writing delegations in PLAN-001 (`.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md:28-32`), leaving `041` implementation to Claude Opus (`.agent/projects/041_process_execution_timeouts/HANDOFF-session-W6-W7-2026-11-02.md:4`).

## 2. The first closed loop

RSI means Motoko improving how it **finds** and **accepts** improvements. The shortest credible loop targets **Motoko's coding-and-verification harness** — how Motoko diagnoses failures, edits AILANG/TypeScript code, writes discriminating tests, and checks itself before hand-in — graded out-of-process on real Motoko-repo tasks.

- **What gets improved:** A bounded harness surface: `.motoko/config/rsi/config.json`, `SYSTEM.md`, `.motoko/skills/*/SKILL.md`, `src/core/prompts.ail`, `src/core/tool_runtime.ail`, `src/core/process_limits.ail`, and the guard/compaction extensions (`empty_stop_guard`, `progress_contract_guard`, `repetition_guard`, `compaction_structural`). Motoko's measurements show these levers dominate on fixed weights: flipping `ohmy_pi` gave 15× speed and 6× fewer output tokens (`CHANGELOG.md:11-16`), `repetition_guard` cut a 197-step runaway to 31 steps (`.agent/projects/028_verified_runtime_closing_the_loop/README.md:58-60`), and author-side `mutgate` with single-item batches turned a 60% defect rate into first-pass acceptance (`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md:38-58`).
- **What proposes the change:** **Motoko (`M_t`) itself**, run headlessly (`bun src/tui/src/index.ts --headless`) in an isolated worktree. After scoring `M_t` on a **dev split**, an orchestrator hands `M_t` failed dev journals, JSONL traces, and error/tool summaries (`benchmarks/error_breakdown.py`, `benchmarks/tool_failures.py`). Under a one-hypothesis-per-diff rule, `M_t` edits the allowed surface, runs local checks, and emits candidate commit `C` (`M_{t+1}`). This is strictly recursive: `M_{t+1}` becomes the proposer for `M_{t+2}`.
- **What accepts it:** An **external Evaluator Runner**, pinned outside the candidate tree, gating `C` conjunctively on:
  1. **Pinned Safety Floor:** Overlays immutable copies of `scripts/dst/`, `src/core/dst_*`, and `tools/verify_classify/` onto `C` (refusing edits to evaluator/oracle paths) and requires `check_core`, `corpus_pr`, `corpus_judge`, `strict_replay`, and `verify_core` green.
  2. **Sealed Holdout Benchmark:** Runs `M_{t+1}` on sealed tasks over `v0.60.4` base `2eae0666` spanning **both halves of RSI**:
     - *Patch-finding:* historical Motoko bugs re-injected cleanly onto `2eae0666` from Motoko's `123` `fix*` commits in `src/`/`packages/` (`git log --no-merges --grep='^fix' -- src/ packages/ | wc -l`; e.g., `fc546d68`, `d66085ab`, `5effef36`, `5cbd7c26`, `9720568a`, `794d470e`), calibrated two-sidedly (`V_i(buggy)=FAIL`, `V_i(HEAD)=PASS`).
     - *Oracle-authoring:* given an ADR rule and module (no mutant shown), write a test, contract, or invariant; sealed `V_i` runs two-sided `mutgate` against blind mutants (must kill) and clean HEAD plus valid refactorings (must survive).
     `M_{t+1}` promotes iff the safety floor passes, holdout solve rate beats `M_t` past the fixed margin with zero canary regressions, and proxy-metered cost stays within cap.
- **Why the evaluator is outside candidate influence:** Unlike ADR-004 D5's in-process cooperative model (`ADR-004:1122-1130`), isolation is structural:
  1. *Secret/history isolation:* Holdout prompts, verifiers `V_i`, and blind mutants never enter `M_t`'s container or dev logs; each task workspace `W_i` is one squashed commit (`git init`), blocking `git log` leaks.
  2. *Process/artifact separation:* `M_{t+1}` runs read-only against its own code in a disposable container writing only to `W_i`. After exit, the evaluator extracts **only** `Δ_i = git diff`, destroys the container, applies `Δ_i` to a fresh `W_i`, and runs sealed `V_i` in an evaluator container; candidate code never runs during scoring.
  3. *Evaluator-owned LLM proxy:* Calls traverse a loopback proxy (the `OPENAI_BASE_URL` pattern in `recorded_stream`, `Makefile:259-260`) pinning model ID/parameters and metering tokens/USD independently of `LoopTotals`.

## 3. The first experiment

**Setup.** Curate **30 tasks** on `2eae0666` (`v0.60.4`): **10 dev** (7 reverted fixes + 3 oracle-authoring) and **20 sealed holdout** (14 reverted fixes across `src/core/`, `packages/`, `src/tui/`, `tools/` + 6 oracle-authoring against blind mutants). Calibrate every `V_i` two-sidedly across 3 runs (`V_i(W_i)=FAIL`, `V_i(HEAD)=PASS`, 0% flake). Pin one mid-tier model via the proxy; cap each run at `40` steps, `$1.00`, and `8` minutes.

**Protocol.** (1) Score baseline `M_0` (`rsi` profile: `default` + `skills`, headless `bun`) on dev (10 runs) and holdout (2 repeats = 40 runs). (2) Score **control `K_0`** (comment-only `SYSTEM.md` edit) on holdout (40 runs) to measure noise and confirm rejection. (3) Run **3 closed iterations** (`M_0 → M_3`): `M_t` reads failed dev journals and proposes up to 2 single-scope diffs; candidates beating `M_t` on dev (`≥ +1` task, `0` regressions) and clearing the safety floor are scored on holdout (40 runs) and promoted if accepted.

**Fixed pass/fail criteria.**
- **PASS** iff: (1) `|score(K_0) - score(M_0)| ≤ 2/40` (`≤ 5 pp`) and `K_0` is rejected; (2) accepted `M_k` gains `≥ +6/40` runs (`+15 pp`) and `≥ +3` net distinct holdout tasks over `M_0` (paired bootstrap 95% CI > 0) with safety floor green; (3) `≥ 2` accepted transitions where the second win is proposed by an improved `M_t`, including `≥ 1` non-timeout logic change; (4) proxy-metered median USD/task `≤ 1.25×` `M_0`.
- **FAIL** if `K_0` false-accepts or exceeds `5 pp` noise; `< 2` transitions accept; holdout gain `< +10 pp` or CI spans 0 while dev rises; safety floor regresses; or `M_0` fails to emit compiling diffs in `≥ 2`/3 rounds.

**Rough cost.** **4–5 engineering days** (1 day evaluator + proxy; 2–3 days curating/calibrating 30 tasks; 1 day proposer + safety floor). Compute: `~200` holdout + `~60` dev + `~6` proposer runs ≈ **`$120–$250`** (`$300` proxy cap), **6–10 hours** at 4-way parallelism.

## 4. What makes the loop compound — and what breaks first

Config/prompt fixes saturate in 3–5 rounds once obvious traps (`30 s` `BashExec`, `Search` single-file bug, `NOTE-010:69-77,91-97`; missing `ailang check`) close. Compounding requires four mechanisms:

1. **Test-time search and verification speed.** Expand from Tier 0 (config/prompts/skills) to Tier 1 (tools, guards, compaction, `herdr`) and Tier 2 (multi-candidate search + author-side `mutgate`). Let `M_t` cut check latency via dependency-scoped checks (`tools/code-graph/`) before full gates and splitting `session.ail` (`5,959` LOC; `59 s` cold compile on `corpus_pr`, `evidence/D11-CEIL/RESULT.md:40`). Faster local checks multiply search depth per dollar.
2. **Co-evolving the acceptor (P1 + P2).** Add an oracle-strengthening lane where `M_t` turns surviving operator mutants (`ailang dev ast-edit replace`, `.agent/projects/039_systematic_mutation_testing/RESEARCH-systematic-mutation-testing.md:247`) and live failures into new `corpus_judge` checks and tests, accepted out-of-process by recall on sealed historical-bug reverts plus 100% survival on clean commits.
3. **Rolling holdout refresh.** Even 1-bit acceptance leaks holdout information across rounds (reusable holdout / adaptive data analysis, Dwork et al., recalled from memory). Graduate saturated tasks to the regression floor and mint fresh holdout tasks from new PRs, live issues (`NOTE-010`), and blind mutants.
4. **Anti-divergence stops.** Halt after 3 consecutive dev wins rejected on holdout (`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md:27-31`).

**What breaks first:** (1) *Bootstrap floor:* `M_0` may fail to edit AILANG cleanly past its `30 s` timeout and `145 s` `check_core` loop, requiring a stronger pinned model or tiny manual bootstrap. (2) *Compile latency:* `59–145 s` cycles choke retries inside an 8-minute cap. (3) *Holdout saturation* after ~5–10 rounds without task refresh and candidate search. (4) *Dev overfitting:* narrow heuristics keyed to dev filenames rather than general debugging procedures.

## 5. Is the DST-centred framing the right one?

**No — DST as the *centre* of RSI is wrong; DST as the *safety floor* is right.**

DST verifies state threading and structural invariants under synthetic logical faults, and explicitly says nothing about task competence (`README.md:165`; `ADR-004:1114`). Centring RSI on DST produced ~78k LOC of simulation, profile pins, line-number anchors (`tools/predicate-anchors/anchors.sh`), and cooperative-trust span manifests (`manifest-A.json`, 872 commits stale), while 14/20 extensions lack DST profiles, `declared_vs_performed` is red on `v0.60.4`, real-entry evaluation never landed on `main`, and line-number anchors penalize autonomous edits to `session.ail` and `ports.ail` (`ADR-004:235-243`).

Keep DST — specifically pinned `corpus_pr`, `corpus_judge`, `strict_replay`, and `verify_core` — as the **non-negotiable seatbelt** whenever autonomous edits touch core or extensions, and keep Motoko's epistemic discipline (`mutgate`, non-vacuity, two-channel checks). Put **sealed, out-of-process competence evaluation** at the centre so Motoko improves its engineering process while DST prevents it from breaking its own runtime.

```yaml
participant: neon
round: 1
position_changed: n/a
top_proposals:
  - id: P1
    title: "Closed-loop harness self-improvement on a sealed Motoko-repo benchmark"
    one_line: "Headless Motoko diagnoses dev failure journals and edits its own skills/config/prompts/tools/guards, accepted by an isolated out-of-process evaluator on sealed historical Motoko bugfix and oracle-authoring tasks plus a pinned DST safety floor."
  - id: P2
    title: "Mutation-guided oracle self-improvement (Stage 2 companion to P1)"
    one_line: "Motoko proposes new invariants, corpus_judge checks, and tests from surviving dev mutants, accepted out-of-process by recall on sealed historical-bug reverts paired with 100% survival on sealed clean commits."
  - id: P3
    title: "Re-ground ADR-004 journal evaluator for runtime allocation optimization"
    one_line: "Update manifest-A.json and AILANG v0.60.4 pins to enable RealEntry replay and optimize runtime allocations; ranked last because resource-only edits under cooperative trust are non-recursive and plateau quickly."
first_experiment:
  what: "Run 3 sequential closed iterations (M_0 -> M_3) plus baseline M_0 and comment-only control K_0 on a 30-task Motoko-repo suite (10 dev, 20 sealed holdout: 14 reverted real fixes + 6 oracle-authoring tasks against blind mutants) on base 2eae0666 under an evaluator-owned container runner and LLM metering proxy."
  pass_if: "K_0 delta <= 5 pp and rejected; M_k achieves >= +15 pp (>= +6/40 runs, >= +3 net distinct holdout tasks, paired bootstrap 95% CI > 0) over M_0 with safety floor 100% green; >= 2 accepted iterations with >= 1 non-timeout logic win proposed by an already-improved M_t; median proxy-metered USD/task <= 1.25x M_0."
  fail_if: "K_0 false-accepts or exceeds 5 pp noise; < 2 accepted iterations; holdout gain < +10 pp or CI spans 0 while dev rises; any safety-floor regression; or M_0 fails to produce compiling diffs in >= 2 of 3 iterations."
  cost: "4-5 engineering days to build evaluator, proxy, and 30 two-sided-calibrated tasks; $120-$250 API spend ($300 hard cap) and 6-10 hours wall-clock at 4-way container parallelism."
disagreements: []
would_change_my_mind_if: "Empirical measurement shows M_0 solves < 10% of dev tasks or cannot produce compiling AILANG diffs even after fixing the 30 s timeout (requiring an upstream AILANG or manual harness bootstrap first), OR a real-entry ADR-004 run demonstrates that compilation/allocation speedups alone unlock > 3x more autonomous task solves without touching harness logic."
embargo_notes: "None opened; respected the full round-1 embargo and did not open any other file whose main subject was a plan for Motoko's self-improvement."
```
