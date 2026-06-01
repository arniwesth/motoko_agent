<!--
Phase 2(a) full-autonomy task prompt for the SIMD-scan autoresearch fixture
(benchmarks/fixtures/autoresearch_simdscan/). The Motoko agent drives the whole
loop itself: ar_init -> ar_run -> ar_log (+ ar_notes journaling), editing the
candidate C file until it keeps a correct, faster NEON scan.

How to reproduce (paths assume repo at /workspaces/motoko_agent and a linked
worktree at /workspaces/motoko_agent_simdscan_wt — adjust to your checkout):

  # one-time: a linked worktree the agent is sandboxed to (session_dir must live
  # INSIDE this worktree, or tool calls will "escape sandbox")
  git worktree add -b autoresearch/simdscan /workspaces/motoko_agent_simdscan_wt HEAD

  # reset the candidate to the scalar baseline before a run
  cp benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c \
     /workspaces/motoko_agent_simdscan_wt/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c

  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-pro \   # flash is the intended model but was
  WORKDIR=/workspaces/motoko_agent_simdscan_wt \ # provider-degraded for multi-turn
  CORE_EXT_ORDER=autoresearch AI_MAX_STEPS=40 MOTOKO_JSONL_OUTPUT=1 \
    ./scripts/run-agent.sh "$(cat benchmarks/prompts/simdscan_autonomy_task.md)"

Model-free discipline validation (Phase 1) and the harness-driven path use
scripts/ar_simdscan_harness.ail instead. The flash-as-candidate-generator variant
(Phase 2b) is benchmarks/simdscan_flash_optimizer.py.
-->

You are an autoresearch optimizer. Use the autoresearch tools (ar_init, ar_run,
ar_log) to improve a C function for speed while keeping it exactly correct, then
stop. Work autonomously; do not ask questions.

## Objective
Make `scan_special` faster. It records the index of every special byte
('<' 0x3C, '&' 0x26, '\r' 0x0D, '\0' 0x00) in buf[0..len) into out[] (increasing
order) and returns the count. The only file you may edit is:
  benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c
(relative to your working directory, which is the worktree
/workspaces/motoko_agent_simdscan_wt).

## The lever (from the literature)
The simdjson paper (Langdale & Lemire, arXiv:1902.08318) classifies special bytes
with SIMD: load a block of bytes into a vector register, compare in parallel
against the target bytes, combine into a mask, and find the matching lanes; handle
the leftover tail with scalar code. This machine is Linux **aarch64 (ARM)**, gcc
-O2, with **NEON** available via `<arm_neon.h>`. x86 intrinsics (SSE/AVX,
`<immintrin.h>`) do NOT compile here. A correct NEON scan runs ~10x faster than
the scalar baseline.

## Hard rules
- Output of `scan_special` MUST match the scalar reference EXACTLY on every input,
  including buffers shorter than one vector block and lengths that are not a
  multiple of the vector width (do not drop the tail). The harness checks this and
  refuses to score a wrong candidate.
- Edit ONLY candidate/scan.c. Keep the exact signature. No file I/O, no getenv;
  only <stddef.h>, <stdint.h>, <arm_neon.h>.

## Protocol (follow exactly)
1. Call `ar_init` once with these arguments:
   - objective: "SIMD-optimize scan_special, preserve exact output"
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
   - max_iterations: 6
   - patience: 3
   - new_segment: true
   - session_dir: "/workspaces/motoko_agent_simdscan_wt/.motoko/autoresearch_simdscan"
   - cwd: "/workspaces/motoko_agent_simdscan_wt"
2. `ar_run` once to capture the scalar baseline; then `ar_log` it with decision
   "keep" (it is the reference).
3. Edit candidate/scan.c to a correct NEON vectorized version.
4. `ar_run` again. Read the returned metadata:
   - If `checks_passed` is true AND throughput_mbps increased clearly over the
     best so far, `ar_log` the run with decision "keep".
   - Otherwise `ar_log` it "discard", read why (e.g. CORRECTNESS_FAIL in the
     stdout tail means you dropped the tail or mis-ordered indices), fix
     candidate/scan.c, and `ar_run` again.
5. Stop once you have kept a correct candidate that is at least 3x faster than the
   baseline. Report the baseline and final throughput_mbps.

Do not call `ar_run` twice without an `ar_log` in between.

## Journaling (REQUIRED)
- Immediately AFTER ar_init (before your first ar_run), call `ar_notes` with a
  `body` (markdown) that states the objective, your plan, and the lever you intend
  to use. This populates the session notes document.
- After each kept improvement, call `ar_notes` again with an updated `body`
  summarizing progress so far (baseline vs current throughput, what worked).
- Always pass session_dir "/workspaces/motoko_agent_simdscan_wt/.motoko/autoresearch_simdscan"
  on every ar_init / ar_run / ar_log / ar_notes call so all state lands in one place.
