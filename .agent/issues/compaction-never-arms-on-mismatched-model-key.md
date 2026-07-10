# Compaction silently disabled when the model key misses the catalog → context-limit resolves to 0 → unbounded prompt growth → overflow + verbatim-retry spin

## Status
partially fixed — layers 1–2 fixed on this branch via a per-profile config override; layers 3–4 open

## Branch
arniwesth/mot-38-progress-contract-finalize-guard-extension

## Description
A `make deepseekv4_flash_compaction_heavy_headless` run (model `openai/deepseek-v4-flash`, profile
`local`, a local OpenAI-compatible server configured at **100,000** tokens) grew its prompt without
bound, **never compacted once**, overflowed the server context at step 24, then **retried the
identical oversized prompt 175 times** (steps 24→199) before dying.

The step-24 error (`Prompt has 102268 tokens, but the configured context size is 100000 tokens`) is
the *symptom*. The cause is a chain of four independent defects, the first of which silently
disables compaction entirely.

## Evidence
Log: `.motoko/logfile/session_2026-07-10T14-36-01-580Z.jsonl`
(`finish_reason:"error"`, `steps_executed:199`, input_tokens 1,375,894).

- **0 `compaction_extension` events** for the whole run — compaction never fired.
- Window grew monotonically until the wall, then froze on the failed call:

  | step | msg_count | est_input (harness) |
  |---|---|---|
  | 18 | 90 | 67,053 |
  | 23 | 115 | 75,647 |
  | 24 | 120 | 77,745 |
  | 25–199 | 120 (frozen) | 77,745 (frozen) |

- **175 × `stream_error_retry`**, every one identical, step 24 onward — the same 120-message
  payload re-sent until the step budget ran out.
- Harness estimate **77,745** vs provider's real tokenization **102,268** → ratio **1.315**
  (~32% underestimate).

## Root cause (layer 1 — FIXED): model key misses the catalog, context_limit resolves to 0
The runtime context limit comes solely from `catalog_context_limit_for(model)`
(`src/core/context_usage.ail:50`), keyed by the **exact** model string.

- Session model = `openai/deepseek-v4-flash`.
- `.motoko/model-catalog.json` had **no** `openai/deepseek-v4-flash` key — only
  `deepseek/deepseek-v4-flash` (a different provider prefix).
- `lookup_context_limit` (`context_usage.ail:35`) falls back **only** by stripping an
  `openrouter/` prefix, not `openai/`, so no second lookup happened → `None` → **0**.
- `context_limit = 0` means "unknown," which the compaction extensions treat as *skip
  context-aware behaviour* (`packages/motoko-ext-abi/types.ail:96`). So compaction never armed,
  and the history grew until the provider rejected it.

**Fix applied (layers 1 + 2 together): a per-profile context-limit override.** Context size is a
property of the *endpoint*, not the model name — the same `deepseek-v4-flash` serves 100K on the
local `127.0.0.1:8000` server and 1M on the cloud API — so it now lives in the deployment's config,
not the shared catalog:
- New `resolve_context_limit(model)` in `src/core/context_usage.ail` prefers the active profile's
  `agent.context_limit`, else the per-model catalog, else 0. All live call sites
  (`session.ail` ×6 incl. `session_policy_init`, `rpc.ail` ×2) now call `resolve_context_limit`
  instead of `catalog_context_limit_for` directly.
- `.motoko/config/local/config.json` declares `agent.context_limit: 100000`.
- Verified: under `MOTOKO_CONFIG=local`, `resolve_context_limit("openai/deepseek-v4-flash") ==
  100000`; other profiles fall back to the catalog (e.g. qwen → 262144) unchanged. With the 75%
  threshold this arms compaction at est 75,000 — i.e. at step 23 (est 75,647), *before* the step-24
  overflow.
- The exploratory `"openai/deepseek-v4-flash": 100000` catalog entry was **reverted**: baking a
  deployment's serving context into the shared, model-keyed catalog is the exact fragility this
  issue is about (it only "works" because `openai/…` happens to mean local, and it would break the
  moment two deployments shared a model string).

> **Trap — do NOT "fix" this with generic prefix stripping.** Stripping `openai/` yields
> `deepseek-v4-flash`, which is still not a catalog key; and a family/suffix match against
> `deepseek/deepseek-v4-flash` would resolve to **1,000,000** — the cloud value — 10× the local
> server's real 100K, overflowing anyway. Context size must be resolved per deployment, which is
> what the config override does.

## Not a defect: token "underestimation" (calibration was inert, not wrong)
An earlier draft listed the ~32% gap between the logged raw estimate (77,745, `chars/4`) and the
provider's real count (102,268) as a separate defect. It is **not**. The compaction gate does not
trigger on raw `chars/4` — `compaction_ai.usage_percent` (`compaction_ai.ail:32`) calls
`calibrated_usage_percent_anchored` (`compaction.ail:76`), which affine-calibrates the estimate
against provider truth: `calibrated = anchor_real + density × (raw_est − anchor_est)`, anchored on
the last **real** `input_tokens` from `ctx.telemetry`. So the threshold already fires at real
usage, not the ~23%-low raw estimate (the code comment says exactly this).

The reason it didn't help here is the **same** root cause: `calibrated_usage_percent_anchored`
returns **0 when `limit == 0`** (`compaction.ail:77`). With `context_limit = 0` the usage percent
was 0 every step → `0 < 75` → `PassThrough`, so calibration never even ran. The 77,745 figure is
merely what `provider_call_prepared` *logs*; the calibrated value the gate would use was never
computed. Fixing the limit (above) re-arms calibration — from step 1 it anchors on the growing real
token count and fires compaction at real ~75% (~75K), well before the 102K wall. No calibration or
threshold change is needed.

## Remaining defect (open)
3. **A context-overflow error is misclassified as retryable and retried verbatim.**
   `should_retry_stream_error` (`src/core/recovery.ail:12`) is
   `retry_enabled && remaining_step_budget > 1` — it never inspects the error. A "prompt too long"
   400 is *deterministic*: re-sending the same payload can never succeed. With compaction disabled
   the history never shrank, so the loop spun 175 identical retries, burning the entire step budget
   to no effect before erroring out. It should detect context-overflow and either force emergency
   compaction or fail fast, not blind-retry.

## Location
- `src/core/context_usage.ail:50` — `catalog_context_limit_for`; `:35` `lookup_context_limit`
  (only strips `openrouter/`); `:12` `estimate_tokens` (chars/4).
- `src/core/context_usage.ail` — **`resolve_context_limit`** (new): profile `agent.context_limit`
  override → catalog → 0.
- `.motoko/config/local/config.json` — `agent.context_limit: 100000` (deployment override).
- `packages/motoko-ext-abi/types.ail:96` — `context_limit == 0` ⇒ "unknown ⇒ skip context-aware".
- `src/core/session.ail` (×6, incl. `session_policy_init`) & `src/core/rpc.ail` (×2) — now call
  `resolve_context_limit(model)`; feeds the pre-step compaction gate and `seal_compacted_payload`.
- `src/core/recovery.ail:12` — `should_retry_stream_error` (content-blind retry).

## Fix (priority order)
1. **[done]** `resolve_context_limit` with a per-profile `agent.context_limit` override, so serving
   context is declared by the deployment instead of smuggled through the model name; falls back to
   catalog, then 0. `local` profile set to 100000.
2. **Make context-overflow non-retryable** — detect it in the stream-error path and route to
   emergency compaction (or abort) instead of `should_retry_stream_error`'s blind retry.
3. *Consider:* when `context_limit` resolves to 0 for a model that is actively being sent, emit a
   one-time warning event ("compaction disabled: unknown context limit for <model>") so this fails
   loudly instead of silently. (This would have surfaced the real bug immediately instead of a
   102K-token overflow 24 steps later.)

## Notes
- Distinct from `ephemeral-compaction-and-ai-noop-thrash.md` (compaction *thrashing*) and
  `compaction-rederive-cost-dominates-after-strategy-fixes.md` (compaction *re-deriving*): here
  compaction **never armed at all**.
- Guards were not involved (correctly): every step ended in tool calls or stream errors, never a
  bare stop candidate, so `on_solver_candidate` was never consulted (`ext_solver_feedback=0`). No
  regression from the empty-stop / progress-contract guard work.
