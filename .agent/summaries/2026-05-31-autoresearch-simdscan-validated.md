# 2026-05-31 Autoresearch validated on the SIMD-scan planted-lever fixture

After the Polyglot warm-up validated only the loop *plumbing* (no real lever on a
strong model + degenerate timeout noise; DoD #3 unmet), we built a controlled
**planted-lever fixture** with a real, literature-discoverable optimization lever
and proved the autoresearch loop works as a *disciplined researcher* — model-free
and with a live, cheap model (DeepSeek V4 Flash).

## Fixture (`benchmarks/fixtures/autoresearch_simdscan/`)
- Candidate `candidate/scan.c`: record indices of HTML special bytes
  (`<`, `&`, `\r`, `\0`). Baseline scalar ~0.6 GB/s on aarch64.
- Lever: NEON/SWAR vectorized scan (simdjson, arXiv:1902.08318) ~7-9+ GB/s.
- Primary metric `throughput_mbps` (maximize, **CPU-time** so it is stable under
  load but still mildly noisy); correctness vs a trusted reference is a hard GATE
  (fast-but-wrong emits no metric); held-out TEST corpus grades transfer.
- Corpora: synthetic HTML, sparse specials (~1/200 bytes), sizes incl. <16B and
  non-16-multiples so tail bugs / size-overfit are exposed on held-out.
- Scope = the single candidate file; harness/corpus/bench/levers are off-limits
  and hashed in `immutable.sha256`.

## Phase 1 — model-free discipline (hand-written levers, zero model spend)
Drove a known sequence through `ar_init`/`ar_run`/`ar_log`; all decisions correct:

| Run | Candidate | TRAIN | TEST | Loop decision |
|-----|-----------|-------|------|---------------|
| 1 | baseline | 633 | — | keep (ref) |
| 2 | noise (no-op) | 633 | — | not improved -> discard |
| 3 | overfit decoy (fast on TRAIN sizes only) | 7019 | 634 | kept on TRAIN; **held-out shows NO transfer** |
| 4 | real NEON | 6954 | 7714 | kept; **held-out confirms ~12x transfer** |
| 5 | tail-bug (fast but wrong) | — | — | CORRECTNESS_FAIL -> can't keep |

Headline: runs 3 and 4 are **indistinguishable on TRAIN (~7000)** — only the
out-of-loop held-out grade separates the overfit decoy (634) from the real lever
(7714). That is precisely why held-out discipline exists, and exactly what
Polyglot could never show. Integrity gates (`checks.sh`) also block empty-prompt,
I/O-cheat, and tampered-corpus candidates.

## Phase 2(b) — flash as candidate generator (harness drives the loop)
Given the objective + simdjson technique + current `scan.c`, DeepSeek V4 Flash
produced a correct NEON scan **on the first attempt** (movemask bit-pack + `ctz`,
correct tail handling): TRAIN **7457 MB/s** (~11.7x), held-out TEST **7449**
(transfers). Loop kept it. Cost **$0.0013**.

## Phase 2(a) — full autonomy (flash drives ar_init/ar_run/ar_log + edits code)
Launched the Motoko agent (model `openrouter/deepseek/deepseek-v4-flash`,
`CORE_EXT_ORDER=autoresearch`, workdir = the linked worktree, step cap 40). Flash
autonomously ran 6 iterations and did genuine *iterative* optimization research:

| Run | Version | TRAIN MB/s | Speedup | Correct | Decision |
|-----|---------|-----------|---------|---------|----------|
| 1 | scalar baseline | 635 | 1.00x | yes | keep (ref) |
| 2 | NEON v1 (per-lane extract) | 3463 | 5.45x | yes | keep |
| 3 | NEON v2 (bit-pack multiply movemask) | 7389 | 11.63x | yes | keep |
| 4 | NEON v3 (2x unroll) | 9305 | 14.65x | yes | keep (best) |
| 5 | NEON v4 (4x unroll) | — | — | NO (doc_009 305!=292) | discard |
| 6 | NEON v4-fix (4x unroll) | 4307 | 6.78x | yes | discard (slower than best) |

- Best kept = v3, committed `3808b0e` on branch `autoresearch/simdscan`.
- Held-out TEST on the kept v3: **9225 MB/s** (~14.4x), correct -> **transfers**.
- Disciplined throughout: kept only correct improvements; the correctness gate
  blocked the fast-but-wrong v4; the improvement test discarded the correct-but-
  slower v4-fix (it did not keep a worse candidate).
- Total autonomous run cost **~$0.035**.

## Verdict
The autoresearch loop is validated end-to-end as a disciplined researcher:
discovers a real literature lever, validates it under a noisy primary, keeps gains
that **transfer to held-out**, rejects overfits/cheats/correctness-regressions —
demonstrated both model-free and with a cheap live model driving the whole loop.
This is the warm-up evidence the ARC application depends on. Polyglot's DoD #3
(kept change transfers) is now satisfied on a fixture that actually has a lever.
