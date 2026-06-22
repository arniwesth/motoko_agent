# Operator notes: autoresearch_intcodec (pretraining-novel fixture)

> **STATUS 2026-06-02: CONTAMINATED — do NOT run the A/B as-is.** The cold
> novelty pre-check (below) shows DeepSeek V4 Pro derives Stream VByte cold, in
> one shot, with no hints — including a NEON decode (`vqtbl4q_u8` + `vst4q_u8`,
> 16 values/iter) faster than the `fast_decode.c` ceiling lever. By the
> pre-registered rule, arm A will reach the ceiling cold and the scout A/B will
> reproduce the null. The fixture is sound and reusable; the *technique choice*
> failed novelty. Screen the next technique with the cold-check BEFORE building.

## Cold pre-check result (2026-06-02)

- Tool: `.motoko/ar_bench_scratch/intcodec_coldcheck.py` (one-shot OpenRouter
  completion, no tools, no fixture context). Outputs:
  `intcodec_coldcheck.out` (v1, mild "avoid branching" nudge) and
  `intcodec_coldcheck_v2.out` (v2, nudge removed).
- Both runs reconstructed Stream VByte exactly (2-bit length-code control stream
  + packed data stream + table-driven NEON gather decode). v2 (clean prompt)
  produced a *better* decoder than our reference lever. Cost ~$0.13 total.
- Conclusion: Stream VByte is in-weights for deepseek-v4-pro, like simdjson was.
  "Niche 2017 paper" was not novel enough — the model has ingested Lemire's
  corpus and the lemire/streamvbyte reference implementation.
- Process lesson: **the cold-check is a cheap novelty GATE. Run it on a candidate
  technique BEFORE building a fixture**, not after. Build only if the model
  cannot derive the technique cold across a few samples.


**Operator-only. Do NOT copy any of this into the fixture tree** — the fixture
(`benchmarks/fixtures/autoresearch_intcodec/`) is deliberately non-leaky: nothing
in-tree names the technique or explains why the baseline is slow, so an agent
optimizing `candidate/codec.c` cannot read the answer. This file holds the answer.

## What this fixture tests

The open question from `handoff-pretraining-novel-fixture.md`: **does the
literature-scout phase add value when the winning technique is NOT already in the
model's weights?** On `autoresearch_simdscan` the winner (simdjson structural
classification) was model-famous and the scout was theater (arm A == arm C,
N=4, Mann-Whitney U=7). This fixture picks a *niche* winner so retrieval has a
chance to matter.

## The technique (the answer)

- **Winner: Stream VByte** — Lemire & Kurz, "Stream VByte: Faster Byte-Oriented
  Integer Compression", 2017, arXiv:1709.08990. Reference repo: lemire/streamvbyte.
- Mechanism: split the encoding into a **control stream** (one byte per 4 values,
  four 2-bit length codes) and a **data stream** (packed significant bytes), so
  all four lengths in a group are known from one control byte and decode is
  **branchless** via a per-control-byte shuffle table (`vqtbl1q_u8` on NEON). The
  baseline (LEB128 continuation-bit varint) has a data-dependent per-value byte
  count, so its decode loop mispredicts on the mixed-magnitude workload.
- **Why it's the unique path here**: the mixed 1–4 byte distribution defeats
  every fixed-width and fixed-width-with-exceptions scheme (they fail the
  correctness or the ⅞ compression gate), and standard LEB128's interleaved
  length+data layout resists SIMD. So the format change (control/data split) is
  the only route to the ceiling — which is exactly the property that should make
  arm A plateau below it if the technique is genuinely not in weights.

## Measured numbers (pre-registration baseline)

`gcc -O2`, this aarch64 core, decoded-payload MB/s, median of 7 rounds:

| Lever (`levers/…`) | TRAIN | TEST | meaning |
|---|---|---|---|
| baseline `candidate/codec.c` (LEB128) | ~680 | ~680 | reference / model-known floor |
| `noise.c` (LEB128 rewrite) | ~700 | ~700 | within noise → discard |
| `fast_decode.c` (**Stream VByte**) | ~23200 | ~23800 | **the ceiling, ~34×, transfers** |
| `decoy_overfit.c` (SVB, fast only n%4==0) | ~23200 | ~730 | TRAIN-only, no transfer |
| `decoy_tailbug.c` (SVB, drops n%4 tail) | FAIL | FAIL | correctness-blocked |

**Headroom ≈ 34× (≈680 → ≈23000 MB/s).** Pre-register this before runs.

## Pre-registered experiment

- **Novelty proof == the experiment.** Run **arm A** (no scout,
  `intcodec_autonomy_noscout_task.md`) first. If arm A reaches ~the ceiling cold,
  the technique was in weights → fixture contaminated like simdscan → report the
  null. If arm A plateaus well below the ceiling (e.g. ≤ a few × baseline) AND
  arm C (scout, `intcodec_autonomy_scout_task.md`) breaks through, the literature
  phase has demonstrable value on a pretraining-novel technique.
- **Decision rule (pre-register before peeking):** "scout adds value" iff the
  arm-C median TEST throughput exceeds the arm-A median by a margin larger than
  the within-arm spread, on a one-sided Mann-Whitney at α=0.05.
- **Seeds / power.** N=4 had near-zero power on simdscan (crit U=0 at n=m=4). If
  the effect is large (arm A stuck near baseline, arm C at ceiling) N≈6 suffices
  (crit U=5 at n=m=6). If arm A partially derives SVB, the effect is modest →
  plan N≈10. Budget: ~40 min/seed × 2 arms × N (N=6 ≈ 8 h; N=10 ≈ 13 h+).
- **Optional cold pre-check** (cheap sanity, not a substitute for arm A): ask the
  model cold to design a fast integer-codec decode for a mixed-magnitude uint32
  workload; if it names/derives the control/data split unprompted, expect a null.

## Residual leak surface (decide before running)

The fixture is non-leaky in *names and prose*, but — matching the simdscan
posture — the lever **source still implements the technique** and is readable
in-worktree (`levers/fast_decode.c`), and the prompt invites reading the harness
and corpus. The realistic threat model is low (the agent is told to optimize
`codec.c` and characterize the workload, not to hunt for a reference impl it
isn't told exists), and simdscan produced interpretable results under the same
posture. If you want zero residual leak, delete/relocate `levers/` from the
agent's run worktree and re-hash `immutable.sha256` there (the levers are only
needed for the operator-side Phase-1 discipline test, not for the agent run).

## Run mechanics (carried from last session)

- Model: `openrouter/deepseek/deepseek-v4-pro` (the only reliable multi-turn tool
  driver last session; flash provider-degraded, MiniMax-M3 flaky).
- Config profile is the **worktree `default` profile** (max_steps=50), NOT the
  openrouter profile; `MODEL=…` only sets the model string. Governing file:
  `<WT>/.motoko/config/default/config.json`.
- Disabling `exa_search` for arm A is done by stripping it from the worktree
  default profile's `extensions.order` (CORE_EXT_ORDER only *adds*), re-applied
  after every `git reset`. Verify via the `session_start` `loaded_extensions`.
- `duckdb` required by `ar_init`; confirm `which duckdb` on a fresh worktree.
- Strip the design comment before passing a prompt to the agent:
  `awk 'f{print} /^-->/{f=1}' <prompt>.md`.
- Grade kept candidate on held-out TEST:
  `INTCODEC_CANDIDATE=<WT>/…/candidate/codec.c bash …/bench/grade_test.sh`.
