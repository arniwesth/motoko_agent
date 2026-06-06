<!--
ARM C — AUTONOMOUS-SCOUT variant for the integer-codec (autoresearch_intcodec) fixture.

This is the PRETRAINING-NOVEL re-test of the "does the literature scout add
value?" question. On autoresearch_simdscan the winning technique (simdjson
structural classification) was model-famous, so arm A (no scout) matched arm C
(scout) at N=4 — the scout was theater. This fixture's winning technique
(Stream VByte, Lemire & Kurz 2017, arXiv:1709.08990) is niche; the hypothesis is
that a cold model is much less likely to reach it than the famous SIMD-scan
trick, so retrieval may finally matter. Arm C is this prompt (scout enabled);
arm A is intcodec_autonomy_noscout_task.md (scout disabled).

NON-LEAKY BY DESIGN. This prompt deliberately does NOT name any technique, does
NOT reveal WHY the baseline is slow (data-dependent per-value length -> branch
misprediction), does NOT mention splitting the stream or a shuffle table, and
does NOT say the baseline is suboptimal. The agent must discover all of that
empirically or via its own literature scouting. Do not "fix" the prompt by
adding those hints — that destroys the test. (Stating the compression gate is
fine: it is a hard constraint, not a technique hint.)

NOVELTY IS PROVEN BY ARM A, NOT ASSUMED. Pre-register the headroom threshold
(real lever ~23 GB/s vs baseline ~0.68 GB/s on TEST). If arm A (no scout) also
reaches the ceiling, the technique was in the model's weights and the fixture is
contaminated — report that. The interesting result is arm A plateauing below the
ceiling while arm C breaks through.

Requires the exa_search extension: run with CORE_EXT_ORDER=autoresearch,exa_search
and EXA_API_KEY set (it is in .env). The agent fetches full text via its own
BashExec curl (HTTP egress allowed; sandbox is filesystem-only, so any fetched
file MUST live INSIDE the worktree). The candidate codec.c stays pure (no I/O);
searching/fetching are optimizer-side research steps, never part of codec.c.

Run recipe (deepseek-v4-pro — the only reliable multi-turn tool driver last session):
  WT=/workspaces/motoko_agent_intcodec_wt
  git worktree add -b autoresearch/intcodec-scout "$WT" HEAD   # if it doesn't exist
  cp benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c \
     "$WT/benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c"   # reset to baseline
  rm -rf "$WT/.motoko/autoresearch_intcodec_scout" "$WT"/*.html
  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-pro WORKDIR="$WT" \
  CORE_EXT_ORDER=autoresearch,exa_search MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8180 \
    timeout 2400 ./scripts/run-agent.sh "$(awk 'f{print} /^-->/{f=1}' benchmarks/prompts/intcodec_autonomy_scout_task.md)" \
    > .motoko/ar_bench_scratch/intcodec_scout_seed1.jsonl 2>&1
Grade the kept candidate on held-out TEST:
  INTCODEC_CANDIDATE="$WT/benchmarks/fixtures/autoresearch_intcodec/candidate/codec.c" \
    bash benchmarks/fixtures/autoresearch_intcodec/bench/grade_test.sh
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
benchmark. Use the literature as a STARTING POINT and a source of ideas, NOT a
prescription to copy:

1. **Scout (optional but encouraged).** You have an `exa_search` tool. If you
   think published work is relevant, search for it, then fetch and read the most
   relevant source(s) with BashExec + curl, saving any file INSIDE your working
   directory (the sandbox blocks writes outside the worktree). Large pages should
   be curl'd to a local file and grep/sed'd around the relevant section, never
   read whole. Cite anything you use in ar_notes.
2. **Characterize the actual workload.** You may READ (not edit) the corpus and
   harness under the fixture to understand what the inputs really look like.
   What is fast in theory is not always fast here.
3. **Do not assume any published method is optimal for this case.** If you adopt
   an idea from the literature, IMPLEMENT it, MEASURE it on the benchmark, and
   then EXPLORE alternative implementations of your own. Keep whichever variant
   the metric actually says is fastest. Comparing approaches empirically — and
   being willing to beat or adapt a published method — is the point.

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
  <arm_neon.h>. (Searching/fetching literature is your own research step, fine;
  it is never part of codec.c.)

## Protocol (follow exactly)
1. Do your scout + workload-characterization steps. Then call `ar_init` once with:
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
   - session_dir: "/workspaces/motoko_agent_intcodec_wt/.motoko/autoresearch_intcodec_scout"
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
  `body` (markdown) stating the objective, what (if anything) you found in the
  literature and how you intend to use it, and your plan.
- After EACH approach you measure, call `ar_notes` again recording: the approach,
  its measured throughput_mbps, and your keep/discard rationale — so the notes
  show an explicit comparison of approaches, not just the final winner.
- Always pass session_dir
  "/workspaces/motoko_agent_intcodec_wt/.motoko/autoresearch_intcodec_scout"
  on every ar_init / ar_run / ar_log / ar_notes call.
