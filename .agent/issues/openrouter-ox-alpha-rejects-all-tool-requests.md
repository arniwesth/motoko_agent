# OpenRouter: `stealth/ox-alpha` fails every request carrying a non-empty `tools` array

## Status

Found 2026-08-23 while diagnosing what looked like a broken model in
`session_2026-08-23T17-06-45-426Z.jsonl` — three agent steps that each logged
`stream_end status=completed` with empty text and zero usage. Measured against the pin,
**AILANG v0.33.0**, commit `ae36986`.

**Not a Motoko or AILANG defect.** Reproduced with plain `curl`, no harness in the path. The
model is unusable for agent work until OpenRouter fixes it, because agent work is all tool calls.

Two AILANG-side issues came out of the same session and are filed separately:
[sunholo-data/ailang#839](https://github.com/sunholo-data/ailang/issues/839) (`std/net` ignores
proxy environment) and
[sunholo-data/ailang#842](https://github.com/sunholo-data/ailang/issues/842) (a provider failure
arriving as a successful empty completion — the reason *this* defect was invisible in our logs).

## Not yet reported to OpenRouter

Filing is outward-facing and against a third party, so it was left for the operator. The draft is
below, ready to paste. OpenRouter has no public issue tracker; their FAQ names Discord as the
channel for bug reports — <https://discord.gg/openrouter>, `#help` forum. `support@openrouter.ai`
is billing/account only.

## Symptom

An HTTP 200 with `finish_reason: "stop"`, `content: null`, `native_finish_reason: "network_error"`,
and **no `usage` key at all** — not a zeroed one:

```json
{"id":"gen-...","object":"chat.completion","model":"stealth/ox-alpha","provider":"Stealth",
 "choices":[{"index":0,"finish_reason":"stop","native_finish_reason":"network_error",
 "message":{"role":"assistant","content":null,"refusal":null,"reasoning":null}}]}
```

Identical in streaming: zero chunks carry a `usage` key, versus exactly one on a healthy call.

## What was measured

Same key, same hour, non-streaming. The `tool_calls` rows are the controls — they legitimately
return `content: null`, which is why the absent `usage` block rather than the null content is the
signal that separates a real response from a fabricated one.

| request | `finish_reason` | `native` | `usage` | content |
|---|---|---|---|---|
| `ox-alpha`, no `tools` key | `stop` | `stop` | present | `'pong'` |
| `ox-alpha`, `"tools": []` | `stop` | `stop` | present | `'pong'` |
| `ox-alpha`, one tool, no `parameters` | `stop` | `network_error` | **absent** | `None` |
| `ox-alpha`, tool + `"tool_choice": "none"` | `stop` | `network_error` | **absent** | `None` |
| `qwen/qwen3-32b` + same tool | `tool_calls` | `stop` | present | — |
| `anthropic/claude-sonnet-4.5` + same tool | `tool_calls` | `tool_use` | present | `None` |

**22/22 failures** on the tool-bearing request under strict classification, across ~1 hour.

Two facts narrow it to request-level plumbing rather than the model:

1. `"tools": []` succeeds; **one tool with no `parameters` at all** fails. Not schema validation.
2. `"tool_choice": "none"` — the model is forbidden from calling the tool — **still** fails. Not
   generation.

The controls show the request shape is valid: the byte-identical payload works on two other models.

### Counting artifact, recorded so it isn't rediscovered

An intermediate run appeared to show 1 success in 6. It was a bug in the ad-hoc `bash` classifier,
not OpenRouter behavior: it bucketed by `grep`, and an empty body from a `curl` timeout matched
neither `network_error` nor `"error"`, so it fell through to the success branch. A strict
classifier that names empty bodies explicitly showed 10/10 failures with zero exceptions. Any
re-test should classify empty bodies as their own outcome.

## The monitoring angle

`/api/v1/models/stealth/ox-alpha/endpoints` reported `status: 0` and `uptime_last_30m: 99.98`
during the window in which the 22 consecutive failures were sent. Single `Stealth` provider, and
`supported_parameters` advertises both `tools` and `tool_choice`.

The uptime figure appears to be derived only from traffic that never exercises the tools path, so
this class of failure is invisible in their monitoring — which would apply to any model, not just
this one. That is arguably worth more to OpenRouter than the model report itself.

The model also works fine in OpenRouter's own chat UI, because that sends no `tools` array. It
looks healthy from the obvious place to check, which is most of why this took a session to pin down.

## Caveat

Tested with a single API key on one account. Cannot distinguish a globally broken endpoint from
one broken for this account or tier. `stealth/ox-alpha` is a zero-priced preview model, so a
provider-side config flag is a plausible cause.

## Draft for OpenRouter Discord (`#help`)

2137 characters — just over Discord's 2000-char non-Nitro limit. Drop the last two paragraphs
(~250 chars) or split the monitoring note into a follow-up reply.

---

**`stealth/ox-alpha`: every request carrying a non-empty `tools` array fails with `native_finish_reason: network_error`**

The endpoint advertises `tools` and `tool_choice` in `supported_parameters`, but any non-empty tool list kills the request. Returns HTTP 200, `finish_reason: "stop"`, `content: null`, and **no `usage` block**. 22/22 over ~1 hour today.

Repro:
```bash
curl -sS https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"stealth/ox-alpha","messages":[{"role":"user","content":"say pong"}],
       "tools":[{"type":"function","function":{"name":"ping","description":"d"}}]}'
```
Drop the `tools` key and the same request returns `"pong"` with usage. Streaming behaves identically.

Two things that narrow it to request-level plumbing rather than the model:
• `"tools": []` succeeds. One tool with **no `parameters` at all** fails — so it isn't schema validation.
• `"tool_choice": "none"`, where the model is forbidden from calling the tool, **still** fails — so it isn't generation.

Control: the byte-identical tools payload returns `tool_calls` on `qwen/qwen3-32b` and `tool_use` on `anthropic/claude-sonnet-4.5`, so the request shape is fine.

One thing that may be worth more attention than the model itself: `/api/v1/models/stealth/ox-alpha/endpoints` currently reports `status: 0` and `uptime_last_30m: 99.98` — recorded during a window in which I sent 22 consecutive failing requests. The uptime figure appears to be computed only from traffic that doesn't exercise the tools path, so this class of failure looks invisible in your monitoring. That would apply to any model, not just this one.

Also worth noting the model works fine in the OpenRouter chat UI, since that sends no `tools` array — so it looks healthy from the obvious place to check.

Caveat: tested with a single API key on one account, so I can't rule out that it's tier- or account-specific rather than global.

Impact: unusable for agent work, since that's all tool calls. Happy to supply raw responses or run further tests if useful.

---

## Follow-up in this repo

`.motoko/config/default/config.json` still pins `openrouter/stealth/ox-alpha`. It cannot complete
an agent step. Switch it back before the next real run.
