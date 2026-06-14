<!--
ARM C — AUTONOMOUS-SCOUT variant for the checksum (autoresearch_crc) fixture.

Third pretraining-novelty re-test of "does the literature scout add value?".
simdscan (simdjson) and intcodec (Stream VByte) were both in-weights -> scout was
theater. Here the fast method (carry-less-multiply / PMULL "folding" CRC for a
CUSTOM polynomial) is one the model knows OF but, per the pre-build cold screen
(3/3 cold samples, compile-verified), CANNOT implement correctly cold: it reaches
for PMULL folding, fabricates/derives wrong folding constants for the custom
polynomial, and even botches the fallback table. So retrieval (fetching the
constant-derivation method / a reference) may finally matter. Arm C = this prompt
(scout enabled); arm A = crc_autonomy_noscout_task.md (scout disabled).

NON-LEAKY BY DESIGN. Does NOT name the fast method (folding/Barrett), does NOT
say the baseline is slow, does NOT reveal how to derive the constants. Platform
info (NEON + carry-less-multiply available) is honest environment context, NOT a
technique hint — the cold screen shows the model reaches for PMULL unprompted;
the BARRIER is getting the custom-polynomial constants right, which this prompt
does not help with. Do not add hints.

NOVELTY IS PROVEN BY ARM A. Pre-register the headroom: baseline ~0.38 GB/s,
slice-by-8 plateau ~0.9-2.1 GB/s, carry-less-multiply ceiling several× higher.
The interesting result is arm A plateauing (likely at slice-by-8, failing to get
a correct folding implementation) while arm C breaks through with retrieval. If
arm A reaches the folding ceiling cold, the technique was in-weights after all —
report that null. NOTE the realistic risk: arm A is iterative (≤10 iters + the
sharp correctness gate) and may grind to folding without literature; that is the
open question the experiment answers.

Requires exa_search: CORE_EXT_ORDER=autoresearch,exa_search and EXA_API_KEY (in
.env). Fetches via the agent's own BashExec curl into the worktree. The candidate
crc.c stays pure (no I/O); searching/fetching are optimizer-side research steps.

Run recipe (deepseek-v4-pro):
  WT=/workspaces/motoko_agent_crc_wt
  git worktree add -b autoresearch/crc-scout "$WT" HEAD   # if it doesn't exist
  cp benchmarks/fixtures/autoresearch_crc/candidate/crc.c \
     "$WT/benchmarks/fixtures/autoresearch_crc/candidate/crc.c"   # reset to baseline
  rm -rf "$WT/.motoko/autoresearch_crc_scout" "$WT"/*.html
  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-pro WORKDIR="$WT" \
  CORE_EXT_ORDER=autoresearch,exa_search MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8180 \
    timeout 2400 ./scripts/run-agent.sh "$(awk 'f{print} /^-->/{f=1}' benchmarks/prompts/crc_autonomy_scout_task.md)" \
    > .motoko/ar_bench_scratch/crc_scout_seed1.jsonl 2>&1
Grade the kept candidate on held-out TEST:
  CRC_CANDIDATE="$WT/benchmarks/fixtures/autoresearch_crc/candidate/crc.c" \
    bash benchmarks/fixtures/autoresearch_crc/bench/grade_test.sh
-->

You are an autoresearch optimizer. Use the autoresearch tools (ar_init, ar_run,
ar_log, ar_notes) to make a C function faster while keeping it exactly correct,
then stop. Work autonomously; do not ask questions.

## Objective
Make `crc_fast` faster. It computes a checksum and must return EXACTLY the same
32-bit value as the trusted bit-by-bit reference for every input (a reflected
CRC, custom polynomial 0xB2A8D703, init 0xFFFFFFFF, final xor 0xFFFFFFFF; the
reference is in the fixture's harness). The only file you may edit is:
  benchmarks/fixtures/autoresearch_crc/candidate/crc.c
(relative to your working directory, the worktree /workspaces/motoko_agent_crc_wt).

Platform: Linux aarch64 (ARM). The build is gcc -O2 -march=armv8-a+crypto, so
NEON and the full ARMv8 crypto extensions are available via <arm_neon.h> (use
whatever intrinsics you find useful). x86 intrinsics do NOT compile here.

## How to approach this (read carefully)
You are optimizing for THIS checksum and THIS workload (large buffers). Use the
literature as a STARTING POINT and a source of ideas, NOT a prescription to copy:

1. **Scout (optional but encouraged).** You have an `exa_search` tool. If you
   think published work is relevant, search for it, then fetch and read the most
   relevant source(s) with BashExec + curl, saving any file INSIDE your working
   directory (the sandbox blocks writes outside the worktree). Large pages should
   be curl'd to a local file and grep/sed'd around the relevant section, never
   read whole. Cite anything you use in ar_notes.
2. **Characterize the actual workload.** You may READ (not edit) the corpus and
   harness under the fixture to understand the inputs and the exact checksum
   definition. What is fast in theory is not always fast here.
3. **Do not assume any published method is optimal as-is.** If you adopt an idea,
   IMPLEMENT it, MEASURE it, and verify it stays EXACTLY correct (the harness
   rejects any mismatch). Keep whichever correct variant the metric says is
   fastest. Comparing approaches empirically is the point.

## Computing exact values in AILANG (use this — it is the in-stack tool)
Any integer/bitwise value your approach needs can and should be computed EXACTLY
rather than guessed or derived by hand. Use AILANG — the language this harness runs
on — via BashExec, then VERIFY each value against the reference checksum before
trusting it. A value you have checked against the reference is reliable in a way a
by-hand derivation is not.

AILANG primer (enough to compute with; run `ailang prompt` for the full language
reference and `ailang builtins list` for all builtins):
- A program is a module with an EXPORTED entry function. Run it with:
    ailang run --caps IO --entry main yourfile.ail
  (flags BEFORE the filename).
- Everything is immutable: no mutable variables or loops — use recursion or fold to
  accumulate. `if` must have `then`/`else`. The last expression is the return value.
- Integer bitwise builtins (no import needed): bitwiseXor_Int(a,b),
  bitwiseAnd_Int(a,b), bitwiseOr_Int(a,b), bitwiseNot_Int(a), shiftLeft_Int(a,n),
  shiftRight_Int(a,n). `show(x)` stringifies any value; `println(s)` prints.
- Minimal working example (verified to run):
    module calc
    export func main() -> () ! {IO} {
      let a = bitwiseXor_Int(255, 16);
      let b = shiftLeft_Int(1, 8);
      println("xor=${show(a)} shl=${show(b)}")
    }
  prints: xor=239 shl=256

When an approach looks promising but you are not certain it is exactly correct,
COMMIT it as a candidate and use the harness's correctness feedback to debug it,
rather than retreating to a safer approach you already know works. A wrong attempt
you iterate on against the oracle is more valuable than stopping early at a plateau.

## Hard rules
- `crc_fast` MUST return the reference value EXACTLY on every input, including
  empty/tiny buffers and lengths that are not a multiple of any block width (do
  not drop the head/tail). The harness checks this and refuses to score a wrong
  candidate (CORRECTNESS_FAIL).
- Edit ONLY candidate/crc.c. Keep the exact signature. The candidate itself must
  be pure computation: no file I/O, no getenv; only <stddef.h>, <stdint.h>,
  <arm_neon.h>. (Searching/fetching literature is your own research step, fine;
  it is never part of crc.c.)

## Protocol (follow exactly)
1. Do your scout + workload-characterization steps. Then call `ar_init` once with:
   - objective: "Speed up crc_fast for this workload, preserve exact correctness"
   - metrics: [{"name":"throughput_mbps","direction":"maximize","noisy":true},
               {"name":"wall_ms","direction":"minimize","noisy":true}]
   - benchmark_script:
     "set -eu\nexport CRC_CANDIDATE=/workspaces/motoko_agent_crc_wt/benchmarks/fixtures/autoresearch_crc/candidate/crc.c\nbash /workspaces/motoko_agent/benchmarks/fixtures/autoresearch_crc/bench/benchmark.sh"
   - checks_script:
     "set -eu\nexport CRC_CANDIDATE=/workspaces/motoko_agent_crc_wt/benchmarks/fixtures/autoresearch_crc/candidate/crc.c\nbash /workspaces/motoko_agent/benchmarks/fixtures/autoresearch_crc/bench/checks.sh"
   - scope_paths: ["benchmarks/fixtures/autoresearch_crc/candidate/crc.c"]
   - off_limits: ["benchmarks/fixtures/autoresearch_crc/harness/","benchmarks/fixtures/autoresearch_crc/corpus/","benchmarks/fixtures/autoresearch_crc/bench/","benchmarks/fixtures/autoresearch_crc/levers/"]
   - samples: 5
   - timeout_ms: 120000
   - max_iterations: 10
   - patience: 4
   - new_segment: true
   - session_dir: "/workspaces/motoko_agent_crc_wt/.motoko/autoresearch_crc_scout"
   - cwd: "/workspaces/motoko_agent_crc_wt"
2. `ar_run` once to capture the baseline; then `ar_log` it with decision "keep".
3. Edit candidate/crc.c to implement your first approach. `ar_run`. If
   `checks_passed` is true AND throughput_mbps clearly beats the best so far,
   `ar_log` "keep". Otherwise `ar_log` "discard", read why (CORRECTNESS_FAIL =
   wrong output / dropped tail), fix, re-run.
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
  its measured throughput_mbps, and your keep/discard rationale.
- Always pass session_dir
  "/workspaces/motoko_agent_crc_wt/.motoko/autoresearch_crc_scout"
  on every ar_init / ar_run / ar_log / ar_notes call.
