# Design: retrying a refused `agent prompt` — scope for finding C's mitigation

Date: 2026-09-07
Status: **Scope only. Nothing built.** Blocked on ONE cheap measurement (§3.1) that does not
require reproducing finding C.
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

The blocker is not cost. It is a single unverified assumption about whether the refused prompt was
**delivered** (§3), and §3.1 is a way to settle that in one command without reproducing the race.

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
| `agent_not_ready` | *"the pane holds an agent herdr did not start, so it cannot be prompted"* | **candidate** — a ROUTING refusal: herdr declines to route the prompt at all, so nothing was delivered |
| `agent_prompt_stalled` | *"the delegate accepted input but its state never changed"* | **no** — it says ACCEPTED. A retry is a second delivery |
| `timeout` | the herdr CLI itself did not return | **no** — genuinely undecidable; the prompt may be in flight |
| `agent_not_found` | no agent with that name or pane is live | **no** — retrying cannot summon it |
| `agent_blocked` | waiting on an approval prompt | **no** — a thing to report, not to repeat |
| `server_not_running` | herdr is unwell | **no** — nothing in this call will fix it |

So the retry set is **`{agent_not_ready}`** — one code, chosen because it is the only one whose own
wording asserts non-delivery.

## 3. The assumption this rests on, stated plainly

**`agent_not_ready` claims herdr never routed the prompt. Finding C is herdr's state disagreeing
with reality — so herdr's self-description is exactly the thing in doubt.** Reasoning from the
message alone would be reasoning from the component that is misbehaving.

If the refusal is in fact *post*-delivery, a retry sends the task twice, and a delegate that
receives its prompt twice is worse than one that fails cleanly: it may do the work twice, write the
answer file twice, or interleave two runs in one pane. Today's close-on-failure is what makes the
current behaviour safe, and any retry gives that up.

### 3.1 How to settle it in one command, without reproducing finding C

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

## 5. The shape, if §3.1 clears it

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
