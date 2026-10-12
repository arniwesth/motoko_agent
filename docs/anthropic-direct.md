# Running on direct Anthropic models

Read this before running motoko on an `anthropic/...` model with `ANTHROPIC_API_KEY`. Two AILANG
behaviours decide whether the run works as configured and what it costs. Both are fixed in
**AILANG v0.54.6**, so use that version or later.

| AILANG | System prompt reaches the model | Conversation cached between turns |
|---|---|---|
| ≤ v0.54.5 | **No**: dropped on direct Anthropic and Gemini | No |
| ≥ v0.54.6 | Yes | Yes, automatically for requests that carry tools |

Check yours with `ailang --version`.

## The system prompt

Anthropic takes the system prompt as one top-level `system` field. motoko sends its system prompt
as a `role: "system"` message: the base prompt, `SYSTEM_MD`, and every `PromptShaper`
prepend/append. AILANG ≤ v0.54.5 dropped those messages on direct Anthropic and Gemini, so the
model never saw them. OpenRouter, OpenAI and ollama keep system messages inline and were not
affected.

How to tell from a session log: `provider_call_prepared` reports `system_prefix_chars`. If the
provider's `input_tokens` for the first call is far smaller than that size (about 4 characters per
token), the system prompt is not being sent. Measured on `anthropic/claude-haiku-5-5`:
`system_prefix_chars` was 102,251, but each call billed about 3.2k input tokens, roughly the size
of the tool schemas.

## Prompt caching

motoko resends the whole conversation on every turn. On AILANG ≥ v0.54.6, a request that carries
tools also sends Anthropic's request-level `cache_control: {"type": "ephemeral"}` marker. The cache
point then moves to the latest message on every call, so each turn reads the earlier history from
cache at 0.1× the input price. New tokens are written to the cache at 1.25× the input price, and
the cache expires after 5 minutes without a hit. Nothing needs configuring in motoko.

### Measured

Haiku 5.5, six real tasks (bug fixes in AILANG repositories, each graded by an acceptance check that
fails before the fix), motoko through its `ailang_only` profile, 2026-10-12. Cost is computed from
the token counts the provider returned, at $0.10/M input, $0.50/M output, $0.01/M cache read and
$0.125/M cache write.

| AILANG build | Tasks passed | Cost (6 tasks) | Uncached input tokens |
|---|---|---|---|
| v0.54.5 | 6/6 | $0.754 | 6.9M |
| system-prompt fix only | 6/6 | $0.870 | 7.4M |
| **v0.54.6** (system prompt + conversation caching) | 6/6 | **$0.262** | 234 |

Per task, with v0.54.6:

| Task | Cost before | Cost with caching | Uncached input before → after |
|---|---|---|---|
| 28addec0 | $0.081 | $0.029 | 608,671 → 30 |
| 305ba100 | $0.284 | $0.066 | 2,592,087 → 50 |
| 503c588e | $0.026 | $0.017 | 112,397 → 26 |
| 706e3cd1 | $0.039 | $0.027 | 246,532 → 28 |
| c8e0d2c7 | $0.040 | $0.029 | 213,273 → 34 |
| e0a711f0 | $0.400 | $0.094 | 3,639,007 → 66 |

"Before" is the system-prompt-fix-only build, so these columns differ only in caching. Each task
was run once.

The system-prompt fix on its own raises the cost a little: the prompt is now actually sent (about
48k tokens here), and only that prompt is cached, not the history. Conversation caching is what
cuts the cost.

## Cost reporting under caching

motoko's own cost meter (`step_cost_millicents` in `src/core/cost_phase.ail`) prices input and
output tokens only. Anthropic reports cached tokens separately (`cache_read_input_tokens`,
`cache_creation_input_tokens`), so once most input is cached, `total_cost_usd` and the
`max_cost_usd_cents` cap read low. Across the six runs above, motoko reported $0.051 for $0.262 of
actual spend. Until the meter prices cache tokens, budget from the provider's usage figures, not
from `total_cost_usd`.
