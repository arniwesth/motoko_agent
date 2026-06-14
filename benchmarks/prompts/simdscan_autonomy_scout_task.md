<!--
ARM C — AUTONOMOUS-SCOUT variant for the SIMD-scan autoresearch fixture.

This is the "literature as a starting point, not a prescription" experiment.
Contrast with the two existing prompts:
  - simdscan_autonomy_task.md       (arm A flavor: hands the agent the technique inline)
  - simdscan_autonomy_fetch_task.md (arm B: POINTS at one specific paper, forces faithful repro)

Arm C gives the agent NEITHER. It may use the `exa_search` tool to discover
relevant literature itself, may fetch/read what it finds, and is told to treat
any published method as EVIDENCE, not a recipe — to verify empirically and keep
whatever is fastest for THIS workload. The question under test: given freedom +
literature access, does the loop get past a published-but-suboptimal method and
find the faster variant, while still grounding its reasoning?

NON-LEAKY BY DESIGN. This prompt deliberately does NOT name any technique, does
NOT reveal the workload's exploitable properties (e.g. match density), and does
NOT say the published method is suboptimal. The agent must discover all of that
empirically. Do not "fix" the prompt by adding those hints — that destroys the test.

Requires the exa_search extension: run with CORE_EXT_ORDER=autoresearch,exa_search
and EXA_API_KEY set (it is in .env). exa_search self-describes its usage in the
system prompt when enabled. The agent fetches full text via its own BashExec curl
(HTTP egress is allowed; the sandbox is filesystem-only, so any fetched/saved file
MUST live INSIDE the worktree). The candidate scan.c stays pure (no I/O); searching
and fetching are optimizer-side research steps, never part of scan.c.

Run recipe (note: flash is the intended low-cost model but has been provider-degraded
for multi-turn tool use; probe a 2-message tool exchange via curl before a full run):
  WT=/workspaces/motoko_agent_simdscan_wt
  git worktree add -b autoresearch/simdscan-scout "$WT" HEAD   # if it doesn't exist
  cp benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c \
     "$WT/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c"   # reset to baseline
  rm -rf "$WT/.motoko/autoresearch_simdscan_scout" "$WT"/paper*.html "$WT"/*.html
  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-flash WORKDIR="$WT" \
  CORE_EXT_ORDER=autoresearch,exa_search AI_MAX_STEPS=60 MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8180 \
    timeout 1800 ./scripts/run-agent.sh "$(cat benchmarks/prompts/simdscan_autonomy_scout_task.md)" \
    > .motoko/ar_bench_scratch/scout_flash_run1.jsonl 2>&1
Grade the kept candidate on held-out TEST:
  SIMDSCAN_CANDIDATE="$WT/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c" \
    bash benchmarks/fixtures/autoresearch_simdscan/bench/grade_test.sh
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
general benchmark. Use the literature as a STARTING POINT and a source of ideas,
NOT as a prescription to copy:

1. **Scout (optional but encouraged).** You have an `exa_search` tool. If you
   think published work is relevant, search for it, then fetch and read the most
   relevant source(s) with BashExec + curl, saving any file INSIDE your working
   directory (the sandbox blocks writes outside the worktree). Large HTML pages
   (hundreds of KB) should be curl'd to a local file and grep/sed'd around the
   relevant section, never read whole. Cite anything you use in ar_notes.
2. **Characterize the actual workload.** You may READ (not edit) the corpus and
   harness under the fixture to understand what the inputs really look like.
   What is fast in theory is not always fast here.
3. **Do not assume any published method is optimal for this case.** If you adopt
   an idea from the literature, IMPLEMENT it, MEASURE it on the benchmark, and
   then EXPLORE alternative implementations of your own. Keep whichever variant
   the metric actually says is fastest. Comparing approaches empirically — and
   being willing to beat or adapt the published method — is the point.

## Hard rules
- Output of `scan_special` MUST match the scalar reference EXACTLY on every input,
  including buffers shorter than one vector block and lengths that are not a
  multiple of the vector width (do not drop the tail). The harness checks this and
  refuses to score a wrong candidate.
- Edit ONLY candidate/scan.c. Keep the exact signature. The candidate itself must
  be pure computation: no file I/O, no getenv; only <stddef.h>, <stdint.h>,
  <arm_neon.h>. (Searching/fetching literature is your own research step, fine;
  it is never part of scan.c.)

## Protocol (follow exactly)
1. Do your scout + workload-characterization steps. Then call `ar_init` once with:
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
   - session_dir: "/workspaces/motoko_agent_simdscan_wt/.motoko/autoresearch_simdscan_scout"
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
  `body` (markdown) stating the objective, what (if anything) you found in the
  literature and how you intend to use it, and your plan.
- After EACH approach you measure, call `ar_notes` again recording: the approach,
  its measured throughput_mbps, and your keep/discard rationale — so the notes
  show an explicit comparison of approaches, not just the final winner.
- Always pass session_dir
  "/workspaces/motoko_agent_simdscan_wt/.motoko/autoresearch_simdscan_scout"
  on every ar_init / ar_run / ar_log / ar_notes call.
