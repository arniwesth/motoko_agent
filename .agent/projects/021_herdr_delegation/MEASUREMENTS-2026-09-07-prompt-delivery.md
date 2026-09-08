# `agent prompt` delivery semantics: what a refusal does and does not deliver

Date: 2026-09-07. Target: herdr **0.8.2**, live, in this container (`w1`).
Reason: [`DESIGN-prompt-retry.md`](DESIGN-prompt-retry.md) §3 rests on whether an `agent_not_ready`
refusal happens BEFORE or AFTER the prompt text reaches the pane. A retry is safe only if nothing
was delivered. §3.1 proposed a way to settle it without reproducing finding C; this is that run.

Method: a disposable pane per case, split off `w1:p1` with `--no-focus`, and closed again. The two
live sessions (`w1:p1` this Motoko, `w1:p3` a codex) were never prompted or touched. Every pane
created here was closed; `pane list` and `agent list` were confirmed back to their starting sets.

---

## The answer §3.1 asked for

**An `agent_not_ready` refusal delivers NOTHING.** Measured 4/4 against a self-reported agent: the
call returns `{"error":{"code":"agent_not_ready","message":"agent w1:p6 is not an active named
agent"}}`, and the pane's contents are **byte-identical** before and after — no sentinel, no
change in length, and the agent stays `idle`.

So `DESIGN-prompt-retry`'s central hazard does not apply to this code: **a retry on
`agent_not_ready` cannot double-deliver.** §5's design is licensed on the delivery axis.

## The finding it did not go looking for

**The extension's explanation of `agent_not_ready` is wrong**, and the measurement that exposed it
was the control case rather than the subject.

`types.ail` tells the model:

> The pane holds an agent herdr did not start, so it cannot be prompted. Only agents started with
> `agent start` are promptable.

Measured: a **detected** claude — running in a pane *this session* opened, never touched by
`agent start` — **accepted a prompt and executed it.** The call returned `agent_prompted`, the
sentinel appeared in the prompt box as `❯ SENTINEL-DO-NOT-ACT-B`, and the box was empty again
moments later, i.e. submitted.

So "who started the agent" is not the rule. herdr's own message names the real one: *"not an active
named agent"*.

| agent class | how herdr knows it | `agent prompt` | delivered? |
|---|---|---|---|
| **detected** (claude via screen rules) | the bundled rule manifest matched the screen (`live_prompt_box`, priority 950) | **succeeds** | yes — text typed and submitted |
| **self-reported** (motoko via the reporter API) | the process announced itself (020 D1) | **refused, `agent_not_ready`** | **no** — pane byte-identical |
| started by herdr (`agent start`) | herdr owns the lifecycle | succeeds (not re-measured here) | — |

This CONFIRMS [`DESIGN-motoko-as-delegate`](DESIGN-motoko-as-delegate.md) §1's reason for passing a
motoko delegate's task as argv[2]: self-reported agents genuinely are not promptable. It refutes the
generalisation the error text drew from it.

## What this says about finding C

Finding C is `agent_not_ready` on a claude that **`agent start` had just started**, with the
readiness gate passing in between. Against the table above that is now sharper than "a race":

- a claude herdr did NOT start is promptable;
- a claude herdr DID start is promptable by definition;
- yet the one herdr started was refused as *"not an active named agent"*.

So herdr lost, or never made, the NAME binding for an agent it had just started and reported as
started. That is a herdr-side defect with a precise description, and it is no longer a vague
timing suspicion. It remains not-reproducible here — nothing in this session reproduced the
started-then-refused sequence — so it stays a live-repro item, but an upstream report can now say
what to look for.

**Superseded in one part, 2026-09-08.** A search of herdr's tracker found this exact string
reported on 0.8.2 (#3397) and the mechanism behind it: `agent prompt` gates on identifying the
**pane foreground process**, and that check failing is what produces "not an active named agent".
So the name binding is probably intact and the check in front of it is what fails — a sharper
claim than "lost the binding". See
[`DECISION-2026-09-08-finding-c-upstream.md`](DECISION-2026-09-08-finding-c-upstream.md).

## Raw evidence

```
# control: a DETECTED claude, never started by herdr
$ herdr agent explain w1:p5 --json      → matched_rule live_prompt_box, state idle   (readiness PASSES)
$ herdr agent prompt w1:p5 "SENTINEL-DO-NOT-ACT-B"
  {"result":{"agent":{...,"agent_status":"idle"},"type":"agent_prompted"}}
$ herdr pane read w1:p5                 → "❯ SENTINEL-DO-NOT-ACT-B"      (DELIVERED)

# subject: a SELF-REPORTED motoko
$ herdr agent prompt w1:p6 "SENTINEL-DO-NOT-ACT-C"
  {"error":{"code":"agent_not_ready","message":"agent w1:p6 is not an active named agent"}}
$ herdr pane read w1:p6                 → 0 occurrences, diff vs before EMPTY   (NOT DELIVERED)
$ ... repeated 3x                       → agent_not_ready, 0 occurrences, each time
$ herdr agent list                      → w1:p6 still "idle"
```

## Not measured

- The started-then-refused sequence itself (finding C). It did not occur here.
- Whether `agent_prompt_stalled` and `timeout` deliver. Both are still assumed non-retryable in
  `DESIGN-prompt-retry` §2, and `timeout` is undecidable by construction rather than unmeasured.
- codex, and any kind other than claude and motoko.
