# Handoff: execute WI-C4 — run the name-adoption gate, and expect it to say NO

Audience: a fresh session grounded against HEAD. This item **runs a gate and builds no evidence**; it
is the one item in the project where producing new machinery is a symptom that something went wrong.

**WI-C5 landed 2026-08-05** (~95 min): `ExtPorts.clock_now` widened and routed, `routing_violation_at`
given a production call site, and **D5's declared-versus-performed detector built** — the instrument
D5 names and records as unavailable. Verified at review: `make declared_vs_performed` 10 rows exit 0,
`make hook_guard` 4 rows exit 0, `make dst` exit 2 with the same two red targets since B4, and a
whole-tree sweep at **225 pass / 17 fail** with the failing set matching the expected seventeen member
for member. **Confirm tree state with `git status`**, not with this paragraph.

**Read first:** `NOTE-c5-execution-report-and-plan-corrections.md`, then **the ADR's
`## Acceptance test for the name`** (`ADR-001:2132-2155`) — eleven rows, and they are the entire
content of this item. Then the plan's `## Standing rules`; **S18 is new**.

## Mission

**Run the acceptance table row by row and record the verdict.** Only after every row holds does any
target adopt the "DST"/"simulation" name (D10). **Until then all new targets keep non-simulation
working names.**

Per the plan: every row's evidence is produced earlier — the latency pair in A14, corpus minimums in
A15, routing audit in A4/A5, hermeticity probes in A12, trace contract in A9, streaming parity in C3,
the detector in C5. **A row with no earlier producer is a planning defect to fix here rather than an
experiment to run at the gate.**

## The finding that reframes the item

**Everyone has been tracking the wrong blocker, including this plan and my last three handoffs.**

The question repeated since B4 is *"can any extension be installed?"* — and the answer is still no
(`on_budget_plan` is coverable under neither D5 criterion, and C5 measured that it performs neither
effect it declares). **That is not what stops the name.**

**Read the boundary-honesty row's last clause:** *"...and the result reports per-extension
covered/excluded hook **ids**, so a profile covering only ABI-pure no-op slots is visible as such."*
**The table anticipates a weak profile and asks that it be VISIBLE, not that it be strong.**
`driver_only` installs nothing, discloses that it installs nothing, and every "installed extension"
clause is vacuously satisfied because the set is empty. **That row is arguably passable today.**

**The row that is not passable is the oracle row**, and nothing in the project has been tracking it:

> **Is the oracle complete?** — Every enumerated `SystemRun` terminal path returns exactly one final
> `RunSummary`; **all logical ledger emissions appear in the returned trace**; and all D7 invariants
> pass.

`d64_gap_register` holds **thirteen Logical variants that do not reach the returned trace** —
`NativeToolCalls`, `NativeToolResults`, `ToolPending`, `ExtToolHandled`, `DelegatedToolDeferred`,
`CostExhausted`, `SessionSuspend`, `ThinkingStreamEnd` and five more. These are the tool-dispatch fold
and the terminal paths: **reachable in `driver_only`, which runs the real driver with tools.** C3
discharged D6.4's *named stream exception* and said in as many words that **the general obligation was
not discharged**. This row is that obligation.

**So the expected verdict is NO, and the binding work is closing the register — not the install.**
Say that plainly; it is the item's durable output and it redirects the next several items.

## The rule you will break by accident

**There are exactly two one-line edits that turn the oracle row green, and the codebase already names
both as wrong.**

1. **Reclassify the registered variants as display-only.** D6.4 excludes display-only telemetry, so a
   reclassification makes the obligation vacuous. `dst_invariants` already calls this out verbatim —
   *"reclassifying a Logical variant as DisplayOnly makes D6.4's parity obligation vacuous for it, so
   the set is pinned and moving it is a deliberate edit under D8's compatibility rule and a vocabulary
   version bump — **never a field flip that turns a red invariant green**"*. The pin exists because
   this is the tempting answer.
2. **Narrow "profile-reachable" until the gaps fall outside it.** `driver_only` already installs
   nothing; shrinking its declared reach until the tool-dispatch events are out of scope would pass
   the row by making the profile describe less than it runs. **That is the same move as reclassifying,
   one level up**, and no gate in this tree would catch it.

**A third, subtler one:** answering the gate by *building* something. This item builds no evidence. If
a row cannot be answered from existing gates, **the correct output is "this row has no producer",
recorded as a planning defect — not a new script written at the gate to answer its own question.**
That is S14/S16's failure mode arriving at the acceptance table: a gate that supplies its own evidence
tests nothing.

## Rows worth pre-reading, with their producers

| Row | Producer | Expect |
|---|---|---|
| Is the oracle complete? | `make invariants`, `d64_gap_register` | **RED — 13 registered gaps.** The item's finding |
| Do injected faults reach production recovery? | `make corpus_pr` / `corpus_rotating`, D11 counters | **4 recorded coverage gaps** at last run, incl. `provider_partial_stream_then_error` (`ScriptedStep` has no error channel for a partial stream) and `extension_effect_fault` (waived by an empty install list) |
| Does virtual time matter? | `make anchors`, `attribution_table`, `latency_pair` | Passable — **but note compose's 8 clock reads are still unrouted**, and they are outside `driver_only`'s reach only because it installs nothing |
| Is the tested boundary honest? | `driver_only`, `profile_coverage`, `hook_guard` | Arguably passable, on the visibility reading above. **Decide it explicitly** |
| Is hermeticity enforced? | A12's probes, `world_state` poison pairs | Passable |
| Are discovery and replay stable? | `discovery`, `strict_replay` | Passable |

**Two of these are "passable only because the profile is empty."** Note which, because a reviewer
reading the verdict needs to know the difference between *satisfied* and *vacuously satisfied* — and
D10 says additional profiles earn coverage separately, so a vacuous pass does not transfer.

## A stale count worth fixing in passing

`src/core/dst_event_vocabulary.ail:808` says the register carries *"the remaining **fourteen**"*. It
carries **thirteen** since C3 closed `StreamDelta`. The assertion beside it is correct and derives the
list; only the prose is stale. **S15's exact class** — a number in a comment that nothing checks —
and the third instance in three items.

## Definition of done

**A verdict, row by row, with the evidence that produced each answer.** Eleven rows, eleven answers.
**NO is a legitimate and expected outcome**, and a gate that reports NO with a work list is worth more
than one that reports YES.

**No target adopts the "DST" or "simulation" name** unless every row holds. Six consecutive items have
declined to; do not be the first to take it on a partial table.

**Vacuous passes marked as vacuous**, distinctly from real ones.

**Every failing row given a named producer for its missing evidence** — that is the work list the next
items read, and it is this item's real product.

**Per S13 — a whole-tree sweep cache-cold with `AILANG_RELAX_MODULES=1`**, failing set confirmed
member-for-member against the expected seventeen. **Note: `bfs` does not abort on a missing root**;
C5's report claimed it did and skipped the sweep entirely on that basis. The command in S13 is
correct as written now.

**Per S9 — clear EVERY live `.ailang/cache`**, and **leave `~/.ailang/cache/registry` alone**: it
holds installed registry packages, and deleting it uninstalls them. C5 lost fifteen minutes to that
plus an `ailang install` that appended a duplicate dependency key.

## Out of scope

- **Closing the D6.4 register.** Twelve of the thirteen are the tool-dispatch fold and the terminal
  paths, and appending them is a driver change with its own red surface. **This item identifies it;
  it does not do it.**
- **The `on_budget_plan` ABI change** and everything gated on it: compose's install, its eight clock
  reads, `proc_exec`/`env_get` widening.
- **Wiring the seeded runners through `execution_of`**; the extension bridge's emission channel; the
  `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.

## Stop and report rather than deciding inline

- **If a row can only be answered by changing what a profile claims to reach**, stop. That is a
  conformance decision and a profile version bump, and it is the shape of both wrong answers above.
- **If two rows disagree** — one gate says covered and another says gap — report the disagreement
  rather than picking the greener. This project has found five instruments that certified nothing;
  a disagreement is the cheapest evidence a sixth exists.
- **If the acceptance table itself names evidence no item was ever scheduled to produce**, that is a
  planning defect in the plan, not a gap to fill here. Name it and leave it.

## Report back

Twenty-fourth calibration run.

- **The git wall-clock window.**
- **The eleven answers**, with vacuous passes marked. This is the item's durable output.
- **The verdict on the name**, and the work list behind a NO.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **50 across
  twenty-three runs; determinism has caught none.** This item should add none — it writes no
  production code, and if it does, say why.
- **Whether `driver_only` still covers nothing provably.** It does. Say it once more, because it is
  the sentence a YES verdict would have to contradict.
