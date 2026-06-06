<!--
ARM A — NO-SCOUT ablation for the integer-codec (autoresearch_intcodec) fixture.

Control for the arm-C "literature-as-starting-point" experiment
(benchmarks/prompts/intcodec_autonomy_scout_task.md). IDENTICAL to arm C except it
removes the exa_search scout option and any mention of literature, so the agent
must derive its approach from its own knowledge.

THIS IS THE NOVELTY PROOF AND THE EXPERIMENT IN ONE. Pre-register the headroom:
baseline ~0.68 GB/s, real lever (Stream VByte) ~23 GB/s on held-out TEST. If arm
A reaches the ceiling cold, the technique was in the model's weights and the
fixture is contaminated like simdscan was — report that as the (null) result. If
arm A plateaus well below the ceiling while arm C (scout) breaks through, the
literature phase has demonstrable value on a pretraining-novel technique. Plan
for more seeds than simdscan's N=4 (which had near-zero power); pre-register the
comparison before running.

IMPORTANT — disabling exa_search is NOT done via CORE_EXT_ORDER. The agent loads
config_profile=default from the WORKTREE (.motoko/config/default), and exa_search
is in THAT profile's extensions.order. CORE_EXT_ORDER only ADDS extensions, it does
not subtract. To get a clean no-scout ablation you must remove "exa_search" from the
worktree default profile's extensions.order (and re-apply after any git reset, which
restores the tracked config). Verify via the session_start `loaded_extensions` event
that exa_search is absent. (See .motoko/ar_bench_scratch/arm_a_seeds.sh from the
simdscan run for the driver pattern that does this.)

NON-LEAKY BY DESIGN (same as arm C): never names a technique, never reveals WHY
the baseline is slow (data-dependent per-value length -> branch misprediction),
never mentions splitting the stream or a shuffle table, never hints the baseline
is suboptimal. The agent must discover all of that empirically. Do not "fix" the
prompt by adding those hints.

Run recipe (deepseek-v4-pro; no exa_search extension):
  WT=/workspaces/motoko_agent_intcodec_wt
  cp benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c \
     "$WT/benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c"   # reset baseline
  rm -rf "$WT/.motoko/autoresearch_intcodec_noscout"
  # strip exa_search from $WT/.motoko/config/default/config.json extensions.order
  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-pro WORKDIR="$WT" \
  CORE_EXT_ORDER=autoresearch MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8180 \
    timeout 2400 ./scripts/run-agent.sh "$(awk 'f{print} /^-->/{f=1}' benchmarks/prompts/intcodec_autonomy_noscout_task.md)"
-->

You are an autoresearch optimizer. Use the autoresearch tools (ar_init, ar_run,
ar_log, ar_notes) to make a C function faster while keeping it exactly correct,
then stop. Work autonomously; do not ask questions.

## Objective
Make `codec_decode` faster. The file implements an integer-array codec:
  size_t codec_encode(const uint32_t *in, size_t n, uint8_t *out);  // returns bytes written
  void   codec_decode(const uint8_t *in, size_t n, uint32_t *out);  // decodes n values
You choose the on-wire byte format; `codec_decode` is told the value count `n`
out-of-band. The only file you may edit is:
  benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c
(relative to your working directory, the worktree /workspaces/motoko_agent_intcodec_wt).

Platform: Linux aarch64 (ARM), gcc -O2, with NEON available via <arm_neon.h>.
x86 intrinsics (SSE/AVX, <immintrin.h>) do NOT compile here.

## How to approach this (read carefully)
You are optimizing for THIS specific codec and THIS workload — not a general
benchmark:

1. **Characterize the actual workload.** You may READ (not edit) the corpus and
   harness under the fixture to understand what the inputs really look like.
   What is fast in theory is not always fast here.
2. **Implement, measure, and explore.** Try an approach, IMPLEMENT it, MEASURE it
   on the benchmark, then EXPLORE meaningfully different alternative
   implementations and keep whichever variant the metric actually says is fastest.
   Comparing approaches empirically — rather than stopping at the first thing that
   works — is the point.

## Hard rules
- `codec_decode(codec_encode(values))` MUST round-trip the exact input array on
  every input, including value counts that are not a multiple of any group width
  and tiny inputs (do not drop the tail). The harness checks this and refuses to
  score a wrong candidate (CORRECTNESS_FAIL).
- The total encoded size over the corpus must be at most 7/8 of the raw size
  (4 bytes/value), or the harness refuses to score it (COMPRESSION_FAIL). You
  cannot win by storing values uncompressed.
- Edit ONLY candidate/codec.c. Keep the exact signatures. The candidate itself
  must be pure computation: no file I/O, no getenv; only <stddef.h>, <stdint.h>,
  <arm_neon.h>.

## Protocol (follow exactly)
1. Do your workload-characterization step. Then call `ar_init` once with:
   - objective: "Speed up codec_decode for this workload, preserve exact round-trip and compression"
   - metrics: [{"name":"throughput_mbps","direction":"maximize","noisy":true},
               {"name":"wall_ms","direction":"minimize","noisy":true}]
   - benchmark_script:
     "set -eu\nexport INTCODEC_CANDIDATE=/workspaces/motoko_agent_intcodec_wt/benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c\nbash /workspaces/motoko_agent/benchmarks/fixtures/autoresearch_intcodec/bench/benchmark.sh"
   - checks_script:
     "set -eu\nexport INTCODEC_CANDIDATE=/workspaces/motoko_agent_intcodec_wt/benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c\nbash /workspaces/motoko_agent/benchmarks/fixtures/autoresearch_intcodec/bench/checks.sh"
   - scope_paths: ["benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c"]
   - off_limits: ["benchmarks/fixtures/autoresearch_intcodec/harness/","benchmarks/fixtures/autoresearch_intcodec/corpus/","benchmarks/fixtures/autoresearch_intcodec/bench/","benchmarks/fixtures/autoresearch_intcodec/levers/"]
   - samples: 5
   - timeout_ms: 120000
   - max_iterations: 10
   - patience: 4
   - new_segment: true
   - session_dir: "/workspaces/motoko_agent_intcodec_wt/.motoko/autoresearch_intcodec_noscout"
   - cwd: "/workspaces/motoko_agent_intcodec_wt"
2. `ar_run` once to capture the baseline; then `ar_log` it with decision "keep".
3. Edit candidate/codec.c to implement your first approach. `ar_run`. If
   `checks_passed` is true AND throughput_mbps clearly beats the best so far,
   `ar_log` "keep". Otherwise `ar_log` "discard", read why (CORRECTNESS_FAIL =
   wrong round-trip / dropped tail; COMPRESSION_FAIL = encoding too large), fix,
   re-run.
4. Then TRY AT LEAST ONE MEANINGFULLY DIFFERENT approach and measure it the same
   way, so you are choosing the fastest empirically rather than stopping at the
   first thing that works. Keep iterating until the metric stops improving
   (patience) or you hit max_iterations.
5. Stop once improvements have plateaued and you are keeping the fastest correct
   candidate found. Report the baseline and final throughput_mbps, and which
   approach won.

Do not call `ar_run` twice without an `ar_log` in between.

## Journaling (REQUIRED — this is graded)
- Immediately after ar_init (before your first ar_run), call `ar_notes` with a
  `body` (markdown) stating the objective and your plan.
- After EACH approach you measure, call `ar_notes` again recording: the approach,
  its measured throughput_mbps, and your keep/discard rationale — so the notes
  show an explicit comparison of approaches, not just the final winner.
- Always pass session_dir
  "/workspaces/motoko_agent_intcodec_wt/.motoko/autoresearch_intcodec_noscout"
  on every ar_init / ar_run / ar_log / ar_notes call.
