# ADR-001: Single-authorship of the run file, and correspondence as a second pass

Date: 2026-09-19
Status: **Proposed, v0.1 — drafted from one observed run; not reviewed, not frozen.**
Grounded at: HEAD `2062605`, `dagr 0.3.1 (contract v3)`, extension set including `herdr`.
Implementation status: Documentation only. Nothing proposed here is implemented. D1 restates a
decision that *is* implemented (MOT-136) and is being bypassed in practice.

## Context and established direction

[`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) settled the producer
question on 2026-08-26 and was implemented 2026-08-31 (MOT-136). Its argument was specific:

> dagr's `evidence` tier is the field that distinguishes "the delegate said done" from "something
> checked it", and **the validator does not enforce it** (§7.3). A model-authored producer can stamp
> `verified` on nothing and pass `dagr check --strict` clean. An extension-authored producer derives
> the tier mechanically from what `DelegateCheck` actually observed. **The unenforced field stops
> mattering when no model gets to choose it.**

§7.4a records that the non-enforcement is deliberate — `CONTRACT.md` calls dagr "a representation
kernel, not an enforcement kernel", and its Non-goals say outright:

> No herdr-derived work state: herdr tells us *where* things are running and *whether pixels moved*,
> never *what is true*.

The established direction is therefore already correct. This ADR exists because the guarantee it
rests on — that no model writes the file — did not hold in the PLAN-004 v2 P2.3 run
(`.dagr/run-w3-p1-1789663745618.json`, 2026-09-17 → 2026-09-19), and every failure observed in that
run is one the design predicted.

## Current behavior and observed evidence

All rows observed in the run above. Session journals under `.motoko/sessions/`; pane scrollback via
`herdr pane read`.

| Surface | Observed behavior |
|---|---|
| [`motoko-ext-herdr`](../../../packages/motoko-ext-herdr/herdr.ail) | Ships the full producer surface — `dagr_open:735`, `dagr_record:605`, `dagr_settle:678`, `dagr_alive:699`, `dagr_blocked:712`, `dagr_failed:819` — and `herdr` is loaded in every session of this run. |
| Orchestrator pane `w3:p1` | The **model** also writes the file directly: `BashExec python3 - <<'EOF' … json.dump(g, open(p,"w"), indent=1)` at 08:36:26 and 09:34:48 on 2026-09-19, mutating `state`, `cause`, `actor`, `locator`, and `t.pop("unblock")`. Mixed authorship, not extension authorship. |
| Same | Its own narration names the overwrite: *"the auto-seeded `delegated again` row replaced"*. The extension seeds mechanically; the model edits on top. |
| Task `P2.2` | Twelve attempts, `a2`–`a12`, every `cause.reason` byte-identical: `"delegated again against the operator's plan"`. Nine were P2.3/P2.3R work filed against P2.2 because `dagr_task: P2.2` was passed at Delegate time. |
| Attempts `P2.2·a7`, `·a11` | Settled `lost`, `evidence: heuristic`, reason *"herdr reports agent_not_found … no answer file"*. Journals show both reached a blank finalize with `run_finished finish_reason=stop` after `empty_stop_guard` spent its full budget of 2. Model failures recorded as transport failures — the exact inference the Non-goals forbid. |
| Attempt `P2.3·a5` | Recorded as *"empty-stop at ~3.6h"*. Its journal ends on a tool call, `provider_calls_started: 686` vs `completed: 685`, `exit` with **no `run_finished`**: an external kill, never a stop. |
| Task `P2.3` | Projected `done` twice (after `a14`, after `a18`) while eleven of eighteen Part-1 rows were open and no round-4 review had run. Corrected to `blocked` by hand both times. |
| All 68 attempts | `progress` field present on **zero**. `chain_key`: unused. |
| `dagr stats` | Reports `P2.2 blocked 12 att` — the ring, in a column, available since 2026-09-17. Never run. |
| Receipts | Two prose digest corruptions survived three adversarial review rounds: `collect-x6.log` reported as 96 hex chars (two digests spliced), and a log file's own sha256 reported where the ref digest belonged. |

## D1. The run file has exactly one writer, and it is not the model

The extension is the sole producer. The model never mutates the run file — not to fix a cause, not
to correct a state, not to annotate a locator.

This is not a new decision; it is MOT-136 restated because it is being bypassed. The bypass voids
the whole argument: `evidence` is unenforced *by design*, and the only thing standing between that
and a fabricated `verified` is that no model gets to choose it. A model with `json.dump` has the
pen.

**Corollary.** When the model needs to express something the extension cannot, that is an extension
gap to be filed and fixed, not a licence to hand-edit. Every hand-edit observed in this run —
re-homing attempts, correcting a cause, dropping an `unblock` — names a real missing capability.
Those are the backlog D1 generates, not exceptions to it.

*Applies to supervisors too.* The four corrections published from the supervising session
(`P2.3` `done → blocked` twice, two `P2.2` blocker edges, four backfilled `directive` events) were
each individually defensible and each a violation of D1. A supervisor that writes to the record it
audits is no longer only auditing it. D5 gives that work a different home.

## D2. `progress` is mandatory for any attempt expected to outlive one delegate turn

`{done, total, note}` is already in the contract (`CONTRACT.md:294`). `CONTRACT.md:107–109` gives
its rationale as, verbatim, the failure this run reproduced: *"a 35-minute stall was invisible
because 'working' was one opaque state with no intra-node progress at all."* Zero of 68 attempts
carry it.

With it populated, both false-greens are a one-line check (D4b). Without it they are unfindable
except by a human reading receipts.

## D3. A task whose work is unfinished but unattended is `blocked`, not `done`

Task state projects from the latest attempt, so when an attempt settles `done` and nothing opens,
the task must read `done`. There is no legal way to say *work continues, nobody is on it* — which is
the true state after every incremental publish in this run.

**Decision:** `blocked` with an `unblock` naming what must happen is the canonical encoding, and
producers must emit it at settle-time whenever the row table still has open items. It is
contract-legal today (verified: `dagr check --strict` returns `[]`).

**Not decided:** whether to ask upstream for a distinct state. `blocked` conflates "waiting on an
operator" with "mid-flight between attempts", and the `unblock` string is the only thing
distinguishing them. Deferred to review.

## D4. Three new `dagr check` findings — no schema change, no world access

All three are pure document analysis and fit the existing W-series:

- **(a)** N consecutive attempts on one task with byte-identical `cause.reason`. Would have fired at
  `P2.2·a4` on 2026-09-17, two days before the ring was noticed by eye.
- **(b)** Task `done` while its latest attempt has `progress.done < progress.total`. Requires D2.
- **(c)** A terminal outcome at `heuristic` tier on a task that other tasks depend on, surfaced
  rather than merely stored. The tier system worked perfectly here — `lost` was correctly graded
  `heuristic` — and nothing consumed the grade.

## D5. Correspondence is a separate pass that never enters dagr

`dagr check` validates the document against itself. Nothing validates the document against the
world. That second pass is where receipt existence, digest equality, locator resolution and journal
agreement belong — and it must stay **outside** dagr.

The reason is dagr's own Non-goals. A hermetic validator is deterministic and machine-independent;
one with filesystem and herdr access fails differently per machine and stops being a contract
validator. The correspondence pass needs no dagr change whatsoever, because the run file is plain
JSON.

Minimum invariant set, all drawn from failures in this run:

| # | Invariant | Would have caught |
|---|---|---|
| C1 | every `outcome.receipt` path exists | — (held here) |
| C2 | every digest quoted in a receipt matches the file | the spliced `collect-x6.log` digest |
| C3 | a `done` task names an artifact that exists on disk | both `P2.3` false-greens |
| C4 | every `lost`/`settled_unverified` attempt has a journal with no `run_finished` | `a7`, `a11` misfiled as transport loss |
| C5 | `provider_calls_started == completed` or the attempt is recorded as externally killed | `a5` misfiled as an empty stop |

[`LEDGER-p23-part1-rows.sh`](../013_core_architecture_for_dst/LEDGER-p23-part1-rows.sh) is a crude
first instance of C2 and found the corruption on first run.

## D6. The supervising layer is a role with an observation surface, not a smarter agent

Motoko and the supervising session are the same class of agent. What differs is which artifacts each
reads: the orchestrator observes its **control plane** (what it delegated, what herdr's API returns,
what answer files come back); the supervisor reads the **exhaust** (session journals, pane
scrollback, file mtimes, git blob ids). Every failure in the table above lived in that gap — *the
record says X, the world says Y*, with nothing in the loop comparing the two.

The corollary is the uncomfortable one: **the supervisor is not privileged and not immune.** In this
run the supervising session misread an `Expected` column as results and reported a pending row as
green; what corrected it was the orchestrator's own contradicting statement. Reconciliation ran
upward. A supervisor treated as an oracle would not have caught it.

D6 therefore claims only this: the correspondence pass of D5 is the supervisor's *mechanical*
work and should be automated out of the role entirely. What remains — reading a fix set for
circularity, deciding a basis review should precede expensive runs, recognising a ring as a filing
artifact — is judgment, and this ADR does not claim it can be specified.

## What this ADR does not decide

- Whether `outcome.receipt` should gain an optional `{path, sha256}` shape upstream. It would make
  C2 free, but it is a contract change and belongs to dagr's owners.
- Whether the empty-stop misfiling is better fixed at its source; filed separately as
  [`empty-stop-floor-event-never-reaches-the-session-journal.md`](../../issues/empty-stop-floor-event-never-reaches-the-session-journal.md),
  whose core finding is that `session.ail:3378` emits `EmptyStopFinalize` to the trace but it never
  reaches `journal.jsonl`. C4 is a workaround for that gap, not a substitute.
- Delegation brief sizing. The measured pattern — short, single-row delegates deliver; long
  exploratory ones stall — is real but is a separate concern from run-file truthfulness.
- Where the correspondence pass should live (project script, herdr plugin, or a `dagr-verify`
  sibling binary).

## Evidence

Run graph `.dagr/run-w3-p1-1789663745618.json`. Session journals
`.motoko/sessions/session_{1789676556624,1789711644363,1789720567530,1789805052077}-*/journal.jsonl`.
Row ledger and state file under
[`013_core_architecture_for_dst/`](../013_core_architecture_for_dst/). Prior art:
[`DESIGN-dagr-as-delegation-view.md`](DESIGN-dagr-as-delegation-view.md) §2, §7.3, §7.4a and
[`MEASUREMENTS-2026-09-02-run-file-truthfulness.md`](MEASUREMENTS-2026-09-02-run-file-truthfulness.md).
