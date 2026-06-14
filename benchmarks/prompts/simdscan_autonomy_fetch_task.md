<!--
Phase 2(a) FETCH-AND-READ variant for the SIMD-scan autoresearch fixture. Unlike
benchmarks/prompts/simdscan_autonomy_task.md (which hands the agent the SIMD
technique inline), this prompt gives only the objective + a POINTER to the paper
and requires the agent to fetch and read it to derive the method itself — testing
the §4 literature pipeline (scout -> fetch -> extract -> implement -> validate).

Verified run (2026-06-01, model deepseek-v4-pro): the agent autonomously
  curl -L -o <worktree>/paper.html https://ar5iv.labs.arxiv.org/html/1902.08318
then grep/sed'd the relevant section, cited "Langdale & Lemire arXiv:1902.08318
§3.1.2 Vectorized Classification" in ar_notes, implemented the genuine simdjson
two-nibble-table lookup (vqtbl1q_u8), and the loop kept a correct ~6.3x speedup
that transferred to held-out TEST (~6.2x). (flash is the intended model but was
provider-degraded for multi-turn tool use at the time.)

Run recipe (same as simdscan_autonomy_task.md):
  git worktree add -b autoresearch/simdscan /workspaces/motoko_agent_simdscan_wt HEAD
  cp benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c \
     /workspaces/motoko_agent_simdscan_wt/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c
  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-pro WORKDIR=/workspaces/motoko_agent_simdscan_wt \
  CORE_EXT_ORDER=autoresearch AI_MAX_STEPS=44 MOTOKO_JSONL_OUTPUT=1 \
    ./scripts/run-agent.sh "$(cat benchmarks/prompts/simdscan_autonomy_fetch_task.md)"

Notes: the agent fetches via its own BashExec curl (HTTP egress is allowed; the
sandbox is filesystem-only, so the fetched file must be saved INSIDE the worktree).
The candidate scan.c itself stays pure (no I/O) — fetching is an optimizer-side step.
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

## Find the technique by reading the paper (REQUIRED — do this FIRST)
You do NOT already know the fast approach. The technique is described in the
simdjson paper, "Parsing Gigabytes of JSON per Second" (Langdale & Lemire,
arXiv:1902.08318). Fetch and READ the paper to derive the approach BEFORE writing
any code:
- Fetch it with BashExec + curl, saving the file INSIDE your working directory
  (the sandbox blocks writes outside the worktree). The full HTML text is at:
    https://ar5iv.labs.arxiv.org/html/1902.08318
  It is large (~580 KB), so do not read it whole — curl it to a local file, then
  grep/sed around the part describing how it uses SIMD to find/classify the special
  "structural" characters in a byte stream, and read just that.
- In your FIRST ar_notes call, record the specific technique you extracted from the
  paper and cite it, so your method is grounded in the literature rather than guessed.
Platform: Linux aarch64 (ARM), gcc -O2, with NEON available via <arm_neon.h>.
x86 intrinsics (SSE/AVX, <immintrin.h>) do NOT compile here.

## Hard rules
- Output of `scan_special` MUST match the scalar reference EXACTLY on every input,
  including buffers shorter than one vector block and lengths that are not a
  multiple of the vector width (do not drop the tail). The harness checks this and
  refuses to score a wrong candidate.
- Edit ONLY candidate/scan.c. Keep the exact signature. The candidate itself must be
  pure computation: no file I/O, no getenv; only <stddef.h>, <stdint.h>, <arm_neon.h>.
  (Fetching the paper is fine — that is your own research step, not part of scan.c.)

## Protocol (follow exactly)
1. Fetch + read the paper (above). Then call `ar_init` once with:
   - objective: "SIMD-optimize scan_special using the simdjson technique, preserve exact output"
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
2. `ar_run` once to capture the scalar baseline; then `ar_log` it with decision "keep".
3. Edit candidate/scan.c to implement the technique you read from the paper.
4. `ar_run` again. If `checks_passed` is true AND throughput_mbps clearly beats the
   best so far, `ar_log` "keep". Otherwise `ar_log` "discard", read why (e.g.
   CORRECTNESS_FAIL means you dropped the tail or mis-ordered indices), fix, re-run.
5. Stop once you have kept a correct candidate at least 3x faster than baseline.
   Report the baseline and final throughput_mbps.

Do not call `ar_run` twice without an `ar_log` in between.

## Journaling (REQUIRED)
- Immediately after ar_init (before your first ar_run), call `ar_notes` with a
  `body` (markdown) stating the objective, the technique you extracted from the
  paper (with citation), and your plan.
- After each kept improvement, call `ar_notes` again summarizing progress.
- Always pass session_dir "/workspaces/motoko_agent_simdscan_wt/.motoko/autoresearch_simdscan"
  on every ar_init / ar_run / ar_log / ar_notes call.
