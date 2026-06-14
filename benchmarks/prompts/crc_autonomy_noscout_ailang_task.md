<!--
ARM A — NO-SCOUT ablation for the checksum (autoresearch_crc) fixture.

Control for the arm-C scout experiment (crc_autonomy_scout_task.md). IDENTICAL to
arm C except it removes the exa_search scout option and any mention of literature,
so the agent must derive its approach from its own knowledge.

THIS IS THE NOVELTY PROOF AND THE EXPERIMENT IN ONE. Pre-register the headroom:
baseline ~0.38 GB/s, slice-by-8 plateau ~0.9-2.1 GB/s, carry-less-multiply ceiling
several× higher (measured on TEST). The cold screen (3/3 samples, compile-verified)
showed deepseek-v4-pro cannot produce a correct fast CRC for this custom polynomial
cold — it reaches for PMULL folding, gets the constants wrong, and even botches the
fallback table. The open question: does arm A, given ITERATION (≤10 iters) and the
sharp correctness gate's feedback, still get to the folding ceiling without
literature, or does it plateau (likely at slice-by-8)? If arm A plateaus and arm C
(scout) breaks through, the literature phase has demonstrable value. If arm A
reaches the ceiling cold, report the null. Plan for more seeds than simdscan's N=4
(near-zero power); pre-register the comparison.

IMPORTANT — disabling exa_search is NOT done via CORE_EXT_ORDER. The agent loads
config_profile=default from the WORKTREE (.motoko/config/default), and exa_search
is in THAT profile's extensions.order. CORE_EXT_ORDER only ADDS, it does not
subtract. Strip "exa_search" from the worktree default profile's extensions.order
(and re-apply after any git reset, which restores tracked config). Verify via the
session_start `loaded_extensions` event that exa_search is absent.

NON-LEAKY BY DESIGN (same as arm C): never names the fast method (folding/Barrett),
never says the baseline is slow, never reveals how to derive the constants.
Platform info (NEON + carry-less-multiply available) is honest environment context
the cold screen shows the model already acts on unprompted; it is not the barrier.

Run recipe (deepseek-v4-pro; no exa_search):
  WT=/workspaces/motoko_agent_crc_wt
  cp benchmarks/fixtures/autoresearch_crc/candidate/crc.c \
     "$WT/benchmarks/fixtures/autoresearch_crc/candidate/crc.c"   # reset baseline
  rm -rf "$WT/.motoko/autoresearch_crc_noscout"
  # strip exa_search from $WT/.motoko/config/default/config.json extensions.order
  set -a; . .env; set +a
  MODEL=openrouter/deepseek/deepseek-v4-pro WORKDIR="$WT" \
  CORE_EXT_ORDER=autoresearch MOTOKO_JSONL_OUTPUT=1 ENV_PORT=8180 \
    timeout 2400 ./scripts/run-agent.sh "$(awk 'f{print} /^-->/{f=1}' benchmarks/prompts/crc_autonomy_noscout_task.md)"
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
You are optimizing for THIS checksum and THIS workload (large buffers):

1. **Characterize the actual workload.** You may READ (not edit) the corpus and
   harness under the fixture to understand the inputs and the exact checksum
   definition. What is fast in theory is not always fast here.
2. **Implement, measure, and explore.** Try an approach, IMPLEMENT it, MEASURE it,
   and verify it stays EXACTLY correct (the harness rejects any mismatch), then
   EXPLORE meaningfully different alternatives and keep whichever correct variant
   the metric says is fastest. Comparing approaches empirically — rather than
   stopping at the first thing that works — is the point.

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
  <arm_neon.h>.

## Protocol (follow exactly)
1. Do your workload-characterization step. Then call `ar_init` once with:
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
   - session_dir: "/workspaces/motoko_agent_crc_wt/.motoko/autoresearch_crc_noscout"
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
  `body` (markdown) stating the objective and your plan.
- After EACH approach you measure, call `ar_notes` again recording: the approach,
  its measured throughput_mbps, and your keep/discard rationale.
- Always pass session_dir
  "/workspaces/motoko_agent_crc_wt/.motoko/autoresearch_crc_noscout"
  on every ar_init / ar_run / ar_log / ar_notes call.
