# Handoff: SIMD-scan autoresearch — paper-method vs best-method exploration

You are continuing the autoresearch warm-up on the **SIMD-scan planted-lever
fixture**. The loop is already validated as a disciplined researcher (model-free +
live, including autonomous literature fetch). Your job is the **open question**
below. Read first:
- `.agent/summaries/2026-06-01-autoresearch-simdscan-session.md` (full session)
- `.agent/summaries/2026-05-31-autoresearch-simdscan-validated.md` (fixture detail)
- `benchmarks/fixtures/autoresearch_simdscan/README.md` + `manifest.txt`

## The open question
When the agent **fetched and read** the simdjson paper (arXiv:1902.08318) and
faithfully implemented its technique, it built the **two-nibble-table lookup**
(`vqtbl1q_u8`) and reached only **~6.3×** (≈3.6 GB/s). When earlier runs were told
"use NEON" without the paper, they built a plain **4-way compare** (`vceqq_u8`×4 +
`vmaxvq` empty-block skip) and reached **~14× (9.3 GB/s with 2× unroll)**.

So **the paper's method is ~2× slower than the simpler approach for this task**
(4 targets, sparse matches), because the nibble trick is built to classify *many*
categories at once and it skips the sparsity short-circuit + unrolling. The
fetch-run agent **anchored** on the paper method and never explored the faster
alternative within its 6 iterations.

This is the thing to study: **does the autoresearch loop, given the literature as a
*starting point* rather than a prescription, discover that the paper method is
suboptimal here and find the faster non-paper variant — while still grounding its
reasoning in the paper?** That is the realistic research behavior we ultimately want
(reproduce → then beat / adapt), and it's a stronger test than pure reproduction.

## Concrete next steps
1. **Exploration-nudge rerun.** Add to the fetch task prompt (a copy of
   `benchmarks/prompts/simdscan_autonomy_fetch_task.md`) an instruction like:
   "Use the paper as a starting point, but you are optimizing for THIS task (only 4
   target bytes, sparse matches). After reproducing the paper's method and measuring
   it, also try simpler/faster variants — e.g. direct per-target SIMD compares,
   skipping blocks with no match, and loop unrolling — and keep whichever the metric
   says is fastest." Give it more room: `max_iterations: 10`, `AI_MAX_STEPS=60`.
   Grade whether it gets past the nibble approach toward ~14×, and whether held-out
   transfer holds. Journal (ar_notes) should show it comparing approaches.
2. **Record it as a §4 finding in `papers/ledger.md`**: claim (paper technique) vs
   measured (correct but ~7×, beaten by a non-paper 4-way compare at ~14×). This is
   a *partial reproduction + improvement-over-paper* result — the most interesting
   ledger entry type.
3. Optional: tighten the fixture so the paper method isn't a trap by accident — e.g.
   add a second harder corpus with *denser* specials where the nibble classification
   might actually win, to see if the loop picks the right technique per regime.

## How to run (verified recipe)
```bash
WT=/workspaces/motoko_agent_simdscan_wt
# worktree already exists (branch autoresearch/simdscan); if not:
#   git worktree add -b autoresearch/simdscan "$WT" HEAD
cp benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c \
   "$WT/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c"   # reset to baseline
rm -rf "$WT/.motoko/autoresearch" "$WT/.motoko/autoresearch_simdscan" "$WT"/paper*.html
set -a; . .env; set +a
MODEL=openrouter/deepseek/deepseek-v4-pro WORKDIR="$WT" \
CORE_EXT_ORDER=autoresearch AI_MAX_STEPS=60 MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8180 \
  timeout 1800 ./scripts/run-agent.sh "$(cat <your task prompt>.md)" \
  > .motoko/ar_bench_scratch/<run>.jsonl 2>&1
```
Then grade the kept candidate on held-out TEST:
```bash
SIMDSCAN_CANDIDATE="$WT/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c" \
  bash benchmarks/fixtures/autoresearch_simdscan/bench/grade_test.sh
```
Deterministic head-to-head of two candidate files (no model):
```bash
FIX=benchmarks/fixtures/autoresearch_simdscan
gcc -O2 -o /tmp/b harness/main.c <candidate.c> && /tmp/b "$FIX/corpus/train" 400 9
```

## Gotchas (all learned the hard way this session)
- **flash is provider-degraded for multi-turn tool use right now** (empty completion
  after a tool result; the agent duds at step 2). Reproduce with a 2-message
  tool-exchange curl before blaming the harness. Use **pro** until flash recovers;
  flash is the intended model for the experiment.
- **session_dir MUST be inside the worktree.** The agent is FS-sandboxed to its
  WORKDIR (the worktree); a main-repo session_dir now (post-fix) actually gets
  honored and then "escapes sandbox" → the run stalls. Keep session_dir under
  `$WT/.motoko/...`.
- The agent **fetches via its own `BashExec` curl**; HTTP egress works, but save the
  file **inside** the worktree (FS sandbox). ar5iv full text is ~580 KB — instruct
  grep/sed extraction, not whole-file reads.
- If you edit `packages/motoko-ext-autoresearch/`, run `make sync_packages` so the
  runtime picks it up.
- The candidate `scan.c` must stay pure (no I/O) — fetching is an optimizer-side step.
- Notes/learnings land in the session DB (`<session_dir>/autoresearch.db`, `runs`
  table) and the notes doc (`autoresearch.md`) only if `ar_notes` is called.

## Guardrails (unchanged)
- No Docker; offline benchmark/checks (fetching is optimizer-side only, never in
  benchmark.sh/checks.sh).
- Don't edit the fixture harness/corpus/bench/levels as *candidate* changes (they're
  off_limits + hashed in `immutable.sha256`); editing them as *infra* requires
  re-hashing.
- Commit only when the work warrants it; leave `.motoko/config/default/config.json`
  and `.emsdk/` dirty.
