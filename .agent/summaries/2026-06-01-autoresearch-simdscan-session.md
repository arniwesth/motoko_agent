# 2026-05-31 / 06-01 Session — autoresearch validated on a planted-lever fixture; extension fixes; literature-fetch test

Branch `autoresearch-loop`. This session pivoted the autoresearch warm-up off
Polyglot onto a purpose-built SIMD-scan fixture, validated the loop as a
disciplined researcher (model-free and with a live model), fixed two extension
arg-parsing bugs, and tested the §4 literature-fetch pipeline. Companion:
`.agent/summaries/2026-05-31-autoresearch-simdscan-validated.md` (the fixture +
Phase 1/2 detail). This file is the full session narrative + the open question.

## 1. Polyglot dead-end (confirmed, recorded)
Picked up the Polyglot 0.5a continuation. Rebalanced the split for DeepSeek V4 Pro
(commits `cdd1caa`, `96a901e`) and ran the full loop (`2808d0c`). Conclusion:
**Polyglot can validate the loop *plumbing* but not *disciplined research*** —
on a strong model the only candidate surface (Motoko's own scaffolding) is flat:
the system prompt has no reliable headroom and the tool/extension surface
(omnigraph, ohmy_pi) is broken/deprecated. The primary metric's noise is degenerate
(timeout flicker). DoD #3 (a kept change that transfers) stayed unmet; the discarded
ReAct candidate even scored higher on held-out than TRAIN. Memory:
[[motoko-extensions-deprecated]].

## 2. SIMD-scan planted-lever fixture (the fix for #1)
Built `benchmarks/fixtures/autoresearch_simdscan/` (commit `0729bd4`): candidate is
a self-contained C function `scan_special` (find HTML special bytes `< & \r \0`);
the lever is a NEON/SWAR vectorized scan (simdjson, arXiv:1902.08318). Primary
metric `throughput_mbps` (maximize, **CPU-time** → stable under load yet mildly
noisy); correctness vs a trusted reference is a hard GATE; disjoint held-out TEST
corpus grades transfer. Driver: `scripts/ar_simdscan_harness.ail`.

**Validation (commit `86c1fa4`, detail in the 05-31 summary):**
- Phase 1 (model-free, hand-written levers): every keep/discard/transfer decision
  correct. Headline — the overfit decoy and the real lever were INDISTINGUISHABLE
  on TRAIN (~7000); only held-out separated them (634 vs 7714). Integrity gates
  (empty no-op, TEST-leak grep, immutable tamper, fast-but-wrong correctness)
  all block.
- Phase 2b (flash as candidate *generator*): correct NEON first try, TRAIN 7457 /
  TEST 7449 (~11.7×), kept, $0.0013.
- Phase 2a (full autonomy, flash drives ar_init/ar_run/ar_log itself): kept
  progressive correct gains to **9305 MB/s (14.65×)**, discarded a
  correctness-failing 4× unroll and a correct-but-slower fix; held-out ~14.4×.

Memory: [[autoresearch-validated-simdscan]].

## 3. Two extension bugs found + fixed (`packages/motoko-ext-autoresearch/`)
Both the same root cause: a few arg accessors read only the typed
`normalize_args` path and lacked the `raw_payload` fallback that ar_init/run/log use,
so values passed via a raw-object envelope (harness, and the live agent) were dropped.
- **`ar_notes` body** ignored → "requires body or append_idea". Fixed (`239f6b2`):
  added `parse_notes_body_arg` / `parse_notes_append_idea_arg` with the raw fallback.
- **`resolve_session_dir`** ignored an explicit `session_dir`, defaulting to a
  relative path joined onto the agent's worktree workdir. Fixed (`2620c01`):
  typed → `raw_str_field(raw_payload(args),"session_dir")` → default. Verified
  deterministically (an absolute session_dir is now honored).

After editing the package, run `make sync_packages` (mirrors into the runtime +
`ailang lock`) so the live agent picks up the change.

## 4. Prompts promoted into the repo (reproducibility)
- `benchmarks/prompts/simdscan_autonomy_task.md` (`26aa375`) — Phase 2a task,
  technique handed inline.
- `benchmarks/simdscan_flash_optimizer.py` (`26aa375`) — Phase 2b generator
  (embeds objective + simdjson-technique prompt; env-overridable model/paths).
- `benchmarks/prompts/simdscan_autonomy_fetch_task.md` (`3402417`) — fetch-and-read
  variant (objective + pointer to the paper, NO inline technique).

## 5. Literature-fetch test (§4 pipeline) — the agent really did fetch + read
Originally the paper technique was **spoon-fed inline** by me; the agent never
fetched anything. The fetch-and-read variant gives only the objective + a pointer
to arXiv:1902.08318. Verified run (pro): the agent autonomously
`curl`-ed the ar5iv HTML to `paper.html` (580 KB), `grep`/`sed`-extracted the
section, **cited "Langdale & Lemire §3.1.2 Vectorized Classification"** in ar_notes,
implemented the genuine simdjson **two-nibble-table lookup** (`vqtbl1q_u8`), kept a
correct **6.3×** result, and it transferred to held-out (~6.2×). So scout-pointer →
fetch → extract → cite → implement → measure → keep/discard → held-out transfer all
work autonomously.

Fetch mechanics that matter: the agent fetches via its own `BashExec` curl;
**HTTP egress is allowed** but the sandbox is **filesystem-only** (`AILANG_FS_SANDBOX
= workdir`), so the fetched file must be saved **inside the worktree**.

## 6. THE OPEN QUESTION (carry forward) — paper method ≠ best method
The fetch run reached only **6.3×**, while the inline-technique runs reached
**14.6×**. Head-to-head on this box (deterministic, CPU-time throughput):

| Implementation | TRAIN |
|---|---|
| scalar baseline | ~520–640 MB/s |
| **paper nibble-table** (`vqtbl1q_u8`×3 + `vtst`) — what the fetch agent built | **~3.6 GB/s (~7×)** |
| **4-way compare** (`vceqq_u8`×4 + `vmaxvq` skip) — earlier runs | **~7.4 GB/s (~14×)** |
| 4-way compare + 2× unroll (best observed) | ~9.3 GB/s (14.6×) |

Why the paper method is ~2× slower **for this task**:
1. The two-nibble-table `vpshufb`/`vqtbl1q` trick is designed to classify MANY
   categories at once (simdjson's ~10 structural+whitespace chars); for only **4**
   targets, `4× vceqq` is cheaper than `2 lookups + AND + vtst`, and `tbl` has
   higher latency on ARM.
2. It **missed the sparsity short-circuit**: our corpus has ~1 special / 200 bytes,
   so most 16-byte blocks are empty; the 4-way version does `vmaxvq==0 → skip 16`,
   the nibble version classifies+extracts every block. For sparse data that skip is
   most of the win.
3. No loop unrolling (the 14.6× run had 2×).

Interpretation (the finding to validate next): **faithfully reproducing a
literature method produced a correct, real ~7× speedup that is nonetheless
suboptimal for the simplified task**, and the fetch-run agent *anchored* on the
paper method — it spent its 6 iterations refining the nibble approach rather than
trying the simpler compare or the sparsity skip. "Discoverable from the paper" ≠
"the paper's method is optimal here." This is a genuine, realistic research outcome
and a good thing to study deliberately — see the handoff
`handoff-simdscan-paper-vs-best-method.md`.

## State / operational notes
- New commits this session (on `autoresearch-loop`): `cdd1caa 96a901e 2808d0c`
  (Polyglot), `0729bd4 86c1fa4` (fixture+validation), `239f6b2 2620c01` (extension
  fixes), `26aa375 3402417` (prompts).
- Worktree `/workspaces/motoko_agent_simdscan_wt` on branch `autoresearch/simdscan`
  (HEAD `daa41ee`) holds the agents' kept candidates + scratch (`paper.html`, session
  DBs under `.motoko/autoresearch_simdscan/`). Untracked scratch under
  `.motoko/ar_bench_scratch/` (run logs, task prompts, drivers).
- **flash is currently provider-degraded for multi-turn tool use** — reproduced
  directly against OpenRouter: a single-turn call works, but a follow-up call after a
  tool result returns an empty completion (0 tokens, finish=stop). The agent duds at
  step 2. Used `deepseek-v4-pro` for all live verification; rerun on flash when it
  recovers.
- Run knobs: `MODEL=…`, `WORKDIR=<worktree>`, `CORE_EXT_ORDER=autoresearch`,
  `AI_MAX_STEPS=40+`, `MOTOKO_JSONL_OUTPUT=1`, `ENV_PORT=<unique>`; session_dir must
  be inside the worktree.
- OpenRouter budget ~$16 remaining (of $60); each pro autonomy run ≈ $0.1–0.3,
  flash generator call ≈ $0.001.
- Unrelated dirty state (do not revert): `.motoko/config/default/config.json`, `.emsdk/`.
