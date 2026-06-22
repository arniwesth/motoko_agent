# Known Issues — Motoko autoresearch

Running log of known issues / constraints affecting the autoresearch loop and its
experiments. Each entry: what it is, why it matters, evidence, and possible fixes.

---

## KI-1 — `max_output_tokens` is capped by a compiled-in ailang model registry

**Status:** Open. Found 2026-06-03 (`.agent/summaries/2026-06-03-stronger-model.md`).

**What it is.** The `ailang` runtime sets each model's per-completion
`max_output_tokens` from a **compiled-in model registry**, not from config/env. In
v0.19.1:
- Registry-**known** reasoners (`deepseek-v4-pro`, `glm-5`, `kimi-k2.6`,
  `minimax-m2.7`) get generous caps.
- Registry-**unknown** models (`xiaomi/mimo-v2.5-pro`, `qwen3-max`) fall back to a
  **low default cap** and truncate much faster.

**Why it matters (impact on the loop).** On hard derivation tasks, capable-but-verbose
models spiral into runaway reasoning (thousands of `reasoning_delta` events in one
step), hit the per-completion cap, return `finish_reason=length`, and the agent loop
**dies mid-derivation**. This confounds experiments:
- `glm-5` and `kimi-k2.6` truncated before exhausting their step budget on the CRC
  fold, so we cannot cleanly claim "full budget, still no fold" for them.
- `mimo`/`qwen3-max` truncate even faster (unknown → low cap), so the genuinely
  "stronger model with scout at full budget" test we wanted could not be run.
- Net effect: the binding-constraint conclusion (implementation capability, not
  literature access) is currently demonstrated cleanly only for `deepseek-v4-pro`,
  the one model that runs the loop stably.

**Evidence.** Per-model truncation matrix and the `length` finish_reason traces in
`.agent/summaries/2026-06-03-stronger-model.md`. Related memory:
`autoresearch-model-registry-maxtokens.md`.

**Possible fixes (decision left to operator).**
1. **Upgrade `ailang` v0.19.1 → v0.22.0** — may also add `mimo`/`qwen3-max` to the
   registry (unverified). Ties to the open `ailang.lock` v0.19.1-vs-v0.22.0 decision.
2. **Patch the registry** to raise the cap / add the missing models.
3. After raising the cap, the priority re-run is **mimo or qwen3-max, arm C (scout)**
   at full budget — the genuinely-stronger-model test the CRC thread wanted.

**Notes.**
- The harness sends `"include_reasoning":true` (hence the `reasoning_delta` events).
- Reasoning effort (`think`) is unset → OpenRouter provider default; for adaptive
  reasoners like deepseek-v4-pro the effort knob has weak effect, so this is a *cap*
  problem, not an *effort* problem.
- Observability gap: `run_summary` tracks total/output tokens but not
  `reasoning_tokens` separately, making truncation harder to attribute.
