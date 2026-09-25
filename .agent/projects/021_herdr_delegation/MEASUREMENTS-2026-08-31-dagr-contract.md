# Measurements: what the v0.3.1 validator actually accepts from this producer

Date: 2026-08-31. `dagr 0.3.1 (contract v3; reads v1/v2)`, installed with the pinned command the
design requires (`herdr plugin install aemrebarut/herdr-dagr --ref v0.3.1 --yes`; the unpinned form
still fails without Cargo, §7.1) and resolved at
`~/.config/herdr/plugins/github/herdr-dagr-*/bin/dagr`.

Closes [`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) §3.1's one
unverified assumption, and pins four more shapes the producer emits before they were written into
AILANG. Method: hand-build the exact document the producer would publish, run
`dagr check <f> --strict --json`, record the finding.

## Results

| # | shape under test | verdict |
|---|---|---|
| 1 | task with **no `kind`** (§3.1's assumption) | **REJECTED — `E111 tasks[0].kind: task … missing kind`** |
| 2 | same document with `kind: "task"` (§3.1's named fallback) | clean, `[]` |
| 3 | `kind: "research"` — not in dagr's enumerated list, and the design's `task_kind` offers it | clean; the kind set really is open |
| 4 | attempt with **no `model`** (§3.1: nothing selects one) | clean |
| 5 | working attempt with `liveness` carrying **only `prompt_acknowledged`** (§3.4 omits the other two) | clean under `--strict` — no W204/W208 |
| 6 | `locator: {pane, agent}` (§7.4: emit both, the producer has both) | clean |
| 7 | terminal shapes: `done · reported` with the answer path as receipt; `settled_unverified · heuristic`; attempt `lost` → task `failed` | all clean |
| 8 | attempt `n: 2` with `cause {type: followup, ref: <a1>}` (§3.6's rework link) | clean |
| 9 | task `blocked` over a still-`working` attempt | **W205 — "blocked task … names no unblock owner — never just a red mark"** |
| 10 | same, plus `"unblock": "operator: answer the prompt on pane w1:pD"` | clean |
| 11 | attempt whose `ended_at` **equals** its `started_at` | clean — only ending *before* starting is E181 |

## Consequences, all of them now in the code

- **§3.1's fallback is the one in force.** The design guessed the binary would accept a kind-less
  task and named `task` as the fallback if not; result 1 says not, so the producer emits `task`
  whenever the model omitted `task_kind` or sent a value outside the enumeration. This is the
  handoff's "fall back to `task` and say so" branch, taken with the measurement behind it.
- **`unblock` is a field the design never mentioned.** Result 9 is not optional under `--strict`,
  and it is a good rule: the producer now writes
  `unblock: "operator: answer the prompt on pane <p>"` when a delegate reports `blocked` — which is
  who the unblocker always is on this path — and **clears it again** when the task moves on. A
  settled task still asking for an answer would be exactly the stale fact this producer exists not
  to publish.
- **The three refusals cost nothing at the gate.** No `model`, no `last_output_at`, no
  `queued_input`: results 4 and 5 confirm the honest document is also a valid one, so the design's
  omissions never have to be traded against passing CI.

## Field-name note

The task field is `unblock` (a string). It is absent from the shipped `dagr-producer` skill's prose
and from its examples; it was found in the binary's own struct table (`Task with 13 elements`) after
W205 fired, and confirmed by result 10.

## Not measured

- Whether the **pane redraws** on republish (§7 already lists this as untested).
- Any `projects`, `gate`, `policy`/`futures`, `directive` or `message_resolved` shape. The producer
  emits none of them, so they are outside what CI needs to hold.
