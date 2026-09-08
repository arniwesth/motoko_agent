# Design: retrying a refused `agent prompt` — scope for finding C's mitigation

Date: 2026-09-07
Status: **BUILT 2026-09-07.** §5 as written, with one addition §5 did not anticipate — see the
note at the end of §5. Was: scope only, then unblocked by §3.1. §3.1 was run on 2026-09-07 against
live herdr 0.8.2 and the answer is in
[`MEASUREMENTS-2026-09-07-prompt-delivery.md`](MEASUREMENTS-2026-09-07-prompt-delivery.md):
**an `agent_not_ready` refusal delivers nothing** (4/4, pane byte-identical), so §3's hazard does
not apply to this code and §5 is licensed on the delivery axis. The same run also proved §2's
description of the code WRONG in a way that sharpens finding C — see §3.2.
Relates to: finding C in [`HANDOFF-2026-09-03-patch-state-and-what-remains.md`](HANDOFF-2026-09-03-patch-state-and-what-remains.md)
(`agent_not_ready` on an agent herdr itself started, 2/2 reproducible);
[`MEASUREMENTS-2026-09-02-run-file-truthfulness.md`](MEASUREMENTS-2026-09-02-run-file-truthfulness.md)
F3 for the recorded occurrence; [`NOTE-2026-09-03-herdr-under-dst.md`](NOTE-2026-09-03-herdr-under-dst.md)
§5 for why DST cannot diagnose it.
Provenance: every timing figure below is quoted from a measurement already in this project;
the code references were re-read at `1bcbbc1`.

---

## TL;DR

The extension's response to a refused `agent prompt` is: close the pane, record the task `failed`
with a `verified` receipt, tell the model. **There is no retry, and the readiness gate is a single
`agent explain`, not a wait.**

If finding C is a race, a bounded retry is the mitigation, and it is *extension* logic — testable
under DST without ever reproducing the herdr-side fault. Two things make it narrower than it
sounds: only **one** failure code is a candidate (§2), and the time budget is not an obstacle (§4).

The blocker was not cost but a single assumption about whether the refused prompt was **delivered**
(§3). It was measured on 2026-09-07 and cleared: nothing is delivered (§3.2).

## 1. What happens today

`herdr.ail`'s claude/codex branch, in order:

```
pane split → agent start → agent explain (readiness) → agent prompt
                                                          │ code != 0
                                                          ▼
                            pane close → dagr_failed(evidence "verified") → err_result
```

The failure is recorded honestly and the pane is not leaked. Nothing about today's behaviour is
wrong; it is simply final on the first refusal.

## 2. Which codes may be retried — and it is one

`types.ail`'s failure vocabulary, each judged by what the code says about DELIVERY:

| code | meaning | retry? |
|---|---|---|
| `agent_not_ready` | herdr: *"not an active named agent"*. (This row first quoted the extension's own gloss, "the pane holds an agent herdr did not start" — §3.2 measured that false and it is corrected in `types.ail`.) | **YES, measured** — the refusal delivers nothing, 4/4 |
| `agent_prompt_stalled` | *"the delegate accepted input but its state never changed"* | **no** — it says ACCEPTED. A retry is a second delivery |
| `timeout` | the herdr CLI itself did not return | **no** — genuinely undecidable; the prompt may be in flight |
| `agent_not_found` | no agent with that name or pane is live | **no** — retrying cannot summon it |
| `agent_blocked` | waiting on an approval prompt | **no** — a thing to report, not to repeat |
| `server_not_running` | herdr is unwell | **no** — nothing in this call will fix it |

So the retry set is **`{agent_not_ready}`** — one code, and since 2026-09-07 the only one whose
non-delivery is MEASURED rather than inferred from its own wording. The other five keep their
verdicts on reasoning alone, and `timeout` is undecidable by construction rather than unmeasured.

## 3. The assumption this rests on, stated plainly

**`agent_not_ready` claims herdr never routed the prompt. Finding C is herdr's state disagreeing
with reality — so herdr's self-description is exactly the thing in doubt.** Reasoning from the
message alone would be reasoning from the component that is misbehaving.

If the refusal is in fact *post*-delivery, a retry sends the task twice, and a delegate that
receives its prompt twice is worse than one that fails cleanly: it may do the work twice, write the
answer file twice, or interleave two runs in one pane. Today's close-on-failure is what makes the
current behaviour safe, and any retry gives that up.

### 3.2 ANSWERED 2026-09-07, and the control case was the surprise

The subject behaved as hoped: a self-reported motoko refused with `agent_not_ready` and the pane
was byte-identical afterwards, four times out of four. Retry is safe here.

The CONTROL did not. A **detected** claude — in a pane nothing had `agent start`ed — **accepted the
prompt and executed it**. So this design's §2 reasoning ("a routing refusal because herdr did not
start it") had the right conclusion for the wrong reason, and the extension's error text, which
said the same thing, was simply false. herdr's rule is the NAME binding, not provenance. The text
is corrected in `types.ail`; the table of who is promptable is in the measurement.

That also sharpens finding C rather than explaining it: a claude herdr did NOT start is promptable,
and one it DID start must be — yet finding C's was refused as "not an active named agent". herdr
lost a name binding for an agent it had just started. Still not reproduced here, still a live-repro
item, but an upstream report can now say precisely what to look for.

### 3.1 How it was settled, in one command, without reproducing finding C

`agent prompt` **refuses reported agents** — that is why the motoko lifecycle passes its task as
argv[2] instead (`DESIGN-motoko-as-delegate` §1). So `agent_not_ready` can be produced *on demand*
rather than waited for:

```sh
herdr pane run <pane> "./scripts/run-agent.sh 'noop'"   # a reported motoko agent
herdr agent prompt <that agent> "SENTINEL-DO-NOT-ACT"    # expect exit 1, agent_not_ready
herdr pane read <pane> | grep SENTINEL                   # ← the whole question
```

A hit means the text reached the pane and **the retry design is dead as written**. A miss across a
few repetitions is the evidence the retry needs. This costs one pane and about a minute, needs no
race, and is the first thing to do.

The result also belongs in `MEASUREMENTS-2026-08-31-failure-codes.md`, which classifies
`agent_not_found` and `server_not_running` but says nothing about delivery semantics for any code.

## 4. Cost, which is not the obstacle

The expensive work is already done by the time the prompt is refused:

| step | measured | source |
|---|---|---|
| `agent start --kind claude` | **3.9 s** | `herdr.ail:1033`, MEASUREMENTS-2026-08-22 |
| `agent prompt` without `--wait` | **3–5 ms** | `herdr.ail:12` |
| `agent get` | **4 ms** | `herdr.ail:12` |

Two extra attempts with a probe between them is single-digit *milliseconds* of work plus whatever
backoff is chosen, against a **30 s** process wall of which ~4 s is already spent. Budget does not
constrain this design; §3 does.

## 5. The shape, now that §3.1 has cleared it

- **Bounded and small**: at most 2 extra attempts. A refusal that survives three attempts is not a
  race and should fail exactly as it does today.
- **Probe between attempts, never blind.** Re-run `agent get`; if the agent's status has moved off
  what it was when the prompt was refused, treat the prompt as possibly delivered and STOP — report
  rather than retry. This is what keeps §3's hazard bounded even if the assumption is wrong.
- **`agent wait --until` is the wrong primitive here**, though `types.argv_wait_until` already
  exists and the module prefers server-side blocking. It waits on an agent *status* transition, and
  the fault is herdr not treating the pane as promptable at all — which is not a status this can
  wait for. Named because it is the obvious first idea.
- **The receipt must carry the attempt count.** The `verified` evidence tier on this row grades a
  claim about the spawn, and "herdr exit 1, code `agent_not_ready`" would become a claim about the
  last of three attempts while reading as a claim about one.
- **No new knob.** A retry policy an operator can turn off is a policy nobody will have on when the
  race bites.

**AS BUILT, and the one thing this section did not anticipate.** Building it exposed a defect in the
GATE rather than in the design: `verify_mot136_dagr_producer` threads one world through every case,
so a shared attempt counter accumulated across them — case 9's three refusals were still on the
tally by the time the retry cases ran. The effect was not cosmetic: the refuse-once-then-succeed
case passed by never refusing at all, which is the exact opposite of what it claims to test. The
counter is now keyed per case by its own `ms`. Two assertions had the same shape of error — a
document-wide `contains(doc, "attempts")` matches EARLIER tasks that were legitimately retried — and
are now scoped to the receipt they are about.

## 6. Ripple

| what | where | size |
|---|---|---|
| bounded retry helper | `herdr.ail`'s prompt branch → a recursive helper | ~30 lines |
| the retry predicate | `types.ail`, one pure func over the failure code, with tests | small |
| receipt wording | `spawn_receipt` gains the attempt count | small |
| gate | `verify_mot136_dagr_producer`: `fail_at: "prompt"` becomes a COUNT, so "refuse once then succeed" is expressible | moderate |
| new cases | refuse-once-then-succeed (task `done`, one delegate); refuse-always (fails exactly as today, receipt says 3 attempts); `agent_prompt_stalled` refuses ONCE and is never retried | moderate |

No ABI change, no host change, no new knob. The shared fixture from `1bcbbc1` already provides the
wire format these cases need.

## 7. What this does NOT do

**It does not diagnose finding C.** If the cause is something other than a race — `agent start`
reporting success for an agent it did not register, say — the retry loops twice and fails
identically, a few milliseconds later. That is an acceptable failure mode and it is not a fix.
The diagnosis still needs herdr server logs or an upstream question, exactly as
`NOTE-2026-09-03` §5 says.

## 8. Recommendation

Do §3.1 first — it is one command and it either kills this design or licenses it. If it licenses
it, §5 is a half-day and its riskiest part is the gate's `fail_at` becoming a count.

If §3.1 shows the prompt WAS delivered, the finding changes shape entirely: the bug is then that
herdr reports a routing refusal for a prompt it routed, which is an upstream report with a
one-command reproduction attached — a better outcome than the retry.
