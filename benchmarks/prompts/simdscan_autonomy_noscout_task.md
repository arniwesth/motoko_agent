<!--
ARM A — NO-SCOUT ablation for the SIMD-scan autoresearch fixture.

This is the control for the arm-C "literature-as-starting-point" experiment
(benchmarks/prompts/simdscan_autonomy_scout_task.md). It is IDENTICAL to arm C
except it removes the exa_search scout option and any mention of literature, so
the agent must derive its approach from its own knowledge.

IMPORTANT — disabling exa_search is NOT done via CORE_EXT_ORDER. The agent loads
config_profile=default from the WORKTREE (.motoko/config/default), and exa_search
is in THAT profile's extensions.order. CORE_EXT_ORDER only ADDS extensions, it does
not subtract. To get a clean no-scout ablation you must remove "exa_search" from the
worktree default profile's extensions.order (and re-apply after any git reset, which
restores the tracked config). Verify via the session_start `loaded_extensions` event
that exa_search is absent. See .motoko/ar_bench_scratch/arm_a_seeds.sh for the driver
that does this.

Question under test: does removing the scout phase change the outcome? Arm C
(N=4) reached ~18x-42x (mean ~30x) but barely used the scout — the seeds recalled
the simdjson nibble technique from training and exa only returned a confirmatory
blog. If arm A matches arm C's distribution, the scout phase adds little here.

NON-LEAKY BY DESIGN (same as arm C): never names a technique, never states the
workload is sparse, never hints any published method is suboptimal. The agent must
discover all of that empirically. Do not "fix" the prompt by adding those hints.

Run recipe (deepseek-v4-pro; no exa_search extension):
  WT=/workspaces/motoko_agent_simdscan_wt
  cp benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c \
     "$WT/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c"   # reset baseline
  rm -rf "$WT/.motoko/autoresearch_simdscan_noscout"
  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-pro WORKDIR="$WT" \
  CORE_EXT_ORDER=autoresearch MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8180 \
    timeout 2400 ./scripts/run-agent.sh "$(cat benchmarks/prompts/simdscan_autonomy_noscout_task.md)"
-->

You are an autoresearch optimizer. Use the autoresearch tools (ar_init, ar_run,
ar_log, ar_notes) to improve a C function for speed while keeping it exactly
correct, then stop. Work autonomously; do not ask questions.

## Objective
Make `scan_special` faster. It records the index of every special byte
('<' 0x3C, '&' 0x26, '\r' 0x0D, '\0' 0x00) in buf[0..len) into out[] (increasing
order) and returns the count. The only file you may edit is:
  benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c
(relative to your working directory, which is the worktree
/workspaces/motoko_agent_simdscan_wt).

Platform: Linux aarch64 (ARM), gcc -O2, with NEON available via <arm_neon.h>.
x86 intrinsics (SSE/AVX, <immintrin.h>) do NOT compile here.

## How to approach this (read carefully)
You are optimizing for THIS specific function and THIS workload — not for a
general benchmark:

1. **Characterize the actual workload.** You may READ (not edit) the corpus and
   harness under the fixture to understand what the inputs really look like.
   What is fast in theory is not always fast here.
2. **Implement, measure, and explore.** Try an approach, IMPLEMENT it, MEASURE it
   on the benchmark, then EXPLORE meaningfully different alternative
   implementations and keep whichever variant the metric actually says is fastest.
   Comparing approaches empirically — rather than stopping at the first thing that
   works — is the point.

## Hard rules
- Output of `scan_special` MUST match the scalar reference EXACTLY on every input,
  including buffers shorter than one vector block and lengths that are not a
  multiple of the vector width (do not drop the tail). The harness checks this and
  refuses to score a wrong candidate.
- Edit ONLY candidate/scan.c. Keep the exact signature. The candidate itself must
  be pure computation: no file I/O, no getenv; only <stddef.h>, <stdint.h>,
  <arm_neon.h>.

## Protocol (follow exactly)
1. Do your workload-characterization step. Then call `ar_init` once with:
   - objective: "SIMD-optimize scan_special for this workload, preserve exact output"
   - metrics: [{"name":"throughput_mbps","direction":"maximize","noisy":true},
               {"name":"wall_ms","direction":"minimize","noisy":true}]
   - benchmark_script:
     "set -eu\nexport SIMDSCAN_CANDIDATE=/workspaces/motoko_agent_simdscan_wt/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c\nbash /workspaces/motoko_agent/benchmarks/fixtures/autoresearch_simdscan/bench/benchmark.sh"
   - checks_script:
     "set -eu\nexport SIMDSCAN_CANDIDATE=/workspaces/motoko_agent_simdscan_wt/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c\nbash /workspaces/motoko_agent/benchmarks/fixtures/autoresearch_simdscan/bench/checks.sh"
   - scope_paths: ["benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c"]
   - off_limits: ["benchmarks/fixtures/autoresearch_simdscan/harness/","benchmarks/fixtures/autoresearch_simdscan/corpus/","benchmarks/fixtures/autoresearch_simdscan/bench/"]
   - samples: 5
   - timeout_ms: 120000
   - max_iterations: 10
   - patience: 4
   - new_segment: true
   - session_dir: "/workspaces/motoko_agent_simdscan_wt/.motoko/autoresearch_simdscan_noscout"
   - cwd: "/workspaces/motoko_agent_simdscan_wt"
2. `ar_run` once to capture the scalar baseline; then `ar_log` it with decision "keep".
3. Edit candidate/scan.c to implement your first approach. `ar_run`. If
   `checks_passed` is true AND throughput_mbps clearly beats the best so far,
   `ar_log` "keep". Otherwise `ar_log` "discard", read why (e.g. CORRECTNESS_FAIL
   means you dropped the tail or mis-ordered indices), fix, re-run.
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
  "/workspaces/motoko_agent_simdscan_wt/.motoko/autoresearch_simdscan_noscout"
  on every ar_init / ar_run / ar_log / ar_notes call.
