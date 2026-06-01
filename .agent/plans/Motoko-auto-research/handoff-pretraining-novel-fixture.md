# Handoff: design a PRETRAINING-NOVEL fixture (does the scout phase ever help?)

You are continuing the autoresearch "does the literature scout add value?" thread.
This session is meant to be a **design discussion first**, then a build — do not
just start coding a fixture; the hard part is the design, and several choices are
genuinely open (see "Open questions").

## What's already established (read these first)
- `papers/ledger.md` — the three 2026-06-01 SIMD-scan entries:
  - arm-C "literature-as-starting-point" (N=4): reproduce -> adapt -> beat,
    ~18x-42x on held-out TEST, robust.
  - the "recalled, not learned from the paper" clarification.
  - arm-A no-scout ABLATION (N=4): **scout phase adds nothing** — arm A (~19x-33x)
    vs arm C (~19x-42x) are statistically indistinguishable (Mann-Whitney U=7).
- Run logs: `.motoko/ar_bench_scratch/scout_pro_*.jsonl` (arm C),
  `noscout_pro_seed*.jsonl` (arm A); drivers `arm_c_seeds.sh`, `arm_a_seeds.sh`.
- Prompts: `benchmarks/prompts/simdscan_autonomy_{scout,noscout,fetch}_task.md`.
- Fixture: `benchmarks/fixtures/autoresearch_simdscan/`.

## The open question
The SIMD-scan result is conclusive but **confounded by pretraining**: simdjson's
NEON nibble trick is famous, so the model already knew it — the scout never even
needed to fetch the paper (its `exa_search` query literally named the answer). So
"scout adds nothing" only holds **when the winning technique is already in the
model's weights.**

The unresolved question: **does the scout/literature phase add value when the
winning technique is genuinely NOT in pretraining?** This is the only regime where
retrieval *could* matter, and it's the realistic one for actual research. We need a
fixture where:
1. the naive/model-known approach plateaus well below the ceiling, AND
2. the better technique is discoverable from a fetchable source but NOT derivable
   cold by the model.
If arm C (scout) then beats arm A (no scout) on such a fixture, retrieval has
demonstrable value. If it still doesn't, that's a strong (and surprising) result
about the limits of tool-use scouting.

## Design requirements for a pretraining-novel fixture
- **Same skeleton as autoresearch_simdscan** (it works well): a pure candidate file
  the optimizer edits; a hard correctness gate vs a reference; a noisy primary
  metric to maximize; separate TRAIN and held-out TEST corpora; decoy levers
  (overfit/tailbug) in `levers/`; `immutable.sha256` over harness/corpus/bench.
- **A real lever with a big gap.** The novel technique must materially beat what the
  model produces cold — otherwise there's no headroom for the scout to reveal.
- **Genuinely novel to the model (cutoff Jan 2026).** Options to discuss:
  - a technique from a *post-cutoff* (2026) paper;
  - an obscure/niche algorithm unlikely to be well-represented in pretraining;
  - **(most controllable) a planted technique**: invent a non-obvious method and
    document it only in a fetchable artifact (a local "tech note" the agent must
    `curl`/read, or a URL we control). The task is constructed so the model won't
    derive it cold, but CAN find it. This makes "novel" a property we control
    rather than bet on.
- **Fetchable, for the scout arm.** Arm C must have a real source to retrieve
  (exa_search hit or a cur-lable doc). Arm A must not. Keep the optimizer-side fetch
  out of benchmark.sh/checks.sh (fetching is a research step, never scored).
- **Non-leaky prompt** (this mattered a lot): the task prompt must NOT name the
  technique, NOT state the exploitable property, NOT hint the naive method is
  suboptimal. The model has to discover/retrieve it.

## Open questions to resolve in discussion (before building)
1. Planted-novel vs genuinely-novel (post-cutoff paper)? Planted is controllable and
   reproducible; genuinely-novel is more honest but risky (might still be in weights,
   or the source might be unfetchable/low-quality).
2. What domain/kernel gives a big, measurable, correctness-gated lever that ISN'T
   simdjson-famous? (e.g., a specific compression/codec trick, a niche string
   algorithm, a numeric kernel with a non-obvious reformulation.)
3. How to *prove* novelty? Suggest a pre-check: ask the model cold (no scout) to
   describe/derive the technique; if it can, the fixture is contaminated.
4. How many seeds / what statistical bar? N=4 had near-zero power here; if we expect
   a real but modest effect, plan for more seeds and pre-register the comparison.

## How to run (VERIFIED recipe + this session's hard-won gotchas)
- **Model: use `openrouter/deepseek/deepseek-v4-pro`.** This session: flash is
  provider-degraded (empty completion after a tool result, duds at step 2);
  MiniMax-M3 is flaky in this harness (reasoning truncation at finish_reason=length
  + malformed/duplicated tool args). Pro was the only reliable multi-turn tool driver.
- **Config profile is the WORKTREE `default` profile**, NOT openrouter:
  `MODEL=openrouter/...` only sets the model string; the profile is `default` unless
  `MOTOKO_CONFIG` is set. The governing file is
  `<WORKTREE>/.motoko/config/default/config.json` (max_steps=50; editing the repo
  openrouter profile or `AI_MAX_STEPS` env has NO effect on this run path).
- **Disabling exa_search (for the no-scout arm) is NOT done via CORE_EXT_ORDER**
  (which only ADDS). `exa_search` lives in the worktree default profile's
  `extensions.order`; strip it there, and re-apply after every `git reset` (which
  restores the tracked config). Verify via the `session_start` `loaded_extensions`
  event. See `.motoko/ar_bench_scratch/arm_a_seeds.sh`.
- **duckdb** is required by autoresearch (`ar_init` shells out to it) and is now
  installed by `scripts/install-prerequisites.sh` (official CLI release into
  ~/.local/bin). On a fresh worktree, confirm `which duckdb` before running.
- **The seed drivers `git reset --hard <baseline>` between seeds**, which WIPES the
  agent's keep-commits. To inspect a non-last seed's winning candidate, reconstruct
  it from the JSONL `WriteFile` tool calls (structure: `tc['tool']=='WriteFile'`,
  `tc['arguments']['content']`), not from git. Grade the best-keep on held-out TEST.
- Verified per-seed recipe (adapt paths/prompt for the new fixture):
  ```bash
  WT=/workspaces/motoko_agent_simdscan_wt   # or a new worktree for the new fixture
  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-pro WORKDIR="$WT" \
  CORE_EXT_ORDER=autoresearch,exa_search MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8180 \
    timeout 2400 ./scripts/run-agent.sh "$(cat <prompt>.md)" > <log>.jsonl 2>&1
  ```
  Grade: `SIMDSCAN_CANDIDATE=... bash <fixture>/bench/grade_test.sh` (clone the
  grade harness for the new fixture).

## Guardrails (unchanged)
- No Docker; offline benchmark/checks (fetching is optimizer-side only, never in
  benchmark.sh/checks.sh).
- Don't edit a fixture's harness/corpus/bench/levels as *candidate* changes
  (off_limits + hashed in `immutable.sha256`); editing them as *infra* requires
  re-hashing.
- Non-leaky prompts only. Strip the `<!-- ... -->` design comment before passing a
  prompt to the agent (it leaks the experiment intent) — use
  `awk 'f{print} /^-->/{f=1}' <prompt>.md`.
- Commit only when work warrants. Leave `.motoko/config/default/config.json` and
  `.emsdk/` dirty. `ailang.lock` (v0.19.1 vs committed v0.22.0) is an open decision
  from last session — confirm with the user before committing/reverting it.
