# NOTE — WI-D25: the successor audits, `on_pre_step` and `on_solver_candidate`

Item 3 of the goal line's critical path. Handoff commit `f548834` at `2026-08-09T12:54:57Z`;
work complete at ~`14:0xZ`. **~1h10m**, against the two-slot audit S29 requires before routing.

**The headline, and it is not the base rate.** Two slots audited, **seven arms enumerated, one
drop found, and the drop was the one the handoff named** — a documented deferral written at
WI-D4 whose scope arrived here. No unknown drop in either path. The audit's most durable outputs
are not the fix: they are the **four compiler verdicts** that bound each slot's reachable surface,
and the **first `on_pre_step` binding in this tree that performs**, which is what makes a dropped
pre-step successor observable at all.

---

## 1. THE ARM-BY-ARM AUDIT — measured at HEAD per S22, both halves of S29

### 1.1 `on_solver_candidate` — one production call site, four endpoints, all threaded

`dispatch_solver_candidate` is called from production **exactly once**, `session.ail:2800`
(census: `grep -rn 'dispatch_solver_candidate' --include=*.ail .` → 1 production site, 1 dispatcher
definition, 3 instrument/smoke sites, 1 ABI comment). `FinalizeDecision` has three variants
(`types.ail:604-608`) and **four** consuming endpoints, because `NoDecision` branches on the
persist-nudge policy:

| # | Arm | Anchor | Successor consumed | Verdict |
|---|---|---|---|---|
| 1 | `Accept(output)` | `session.ail:2803` | `c2_after_dp7(… token_to_world(finalized.next_state) …)` | **THREAD** |
| 2 | `ContinueWithFeedback(feedback)` | `session.ail:2814` | loop state `world_state:` | **THREAD** |
| 3 | `NoDecision` → persist-nudge | `session.ail:2846` | loop state `world_state:` | **THREAD** |
| 4 | `NoDecision` → else | `session.ail:2863` | `c2_after_dp7(…)` | **THREAD** |

**Read side (S29's second half), and it is clean on both counts.** The write-side re-seat is
D19's — `{ post_ctx | world: intercepted.next_state }` at `:2800`, so the ctx handed to the fold
carries the intercept's successor rather than the batch-start world. Inside the dispatcher,
`collect_finalize_decisions` (`ext/runtime.ail:457`) threads the world through the hook list with
an explicit `let` — deliberately not `decide_one(…) :: collect(…)`, whose evaluation order would
be a silent ordering assumption on a cursor — and `decide_one_finalize` (`:455`) re-seats per hook
via `{ ctx | world: stamp_holder(world, h.id) }`. The merge is a pure function of the decision
list and the returned successor is the **last** hook's, which is correct: every hook ran, so every
hook's effects happened, whichever decision won.

**`post_ctx.ports` is built from `st.world_state` and is therefore stale relative to
`exchange.next_state` (`session.ail:2679`).** Recorded rather than fixed, because at this slot it
is **unreachable**: §2 measures zero `ExtPorts` fields callable under `! {Process}`, so no port
call can observe the staleness. It is named here so a future row widening does not meet it as a
surprise — that is the barrier question and is out of scope (D7's three barriers stand).

**D19 already re-seated the write side in passing**, which is why this slot came back clean.

### 1.2 `on_pre_step` — one production call site, three arms, one drop

`dispatch_pre_step_chain` is called from production **exactly once**, `session.ail:2537`. The
successor `chain.next_state` has three consumers, one per arm of `seal_compacted_payload`
(`phase_vocab.ail:145`):

| # | Arm | Anchor | What it passed | Verdict |
|---|---|---|---|---|
| 1 | `Err(SealSystemPromptEmpty)` | `session.ail:2549` | `st.world_state` → `c2_finalize` | **DROP** (documented) |
| 2 | `Err(SealExhausted)` | `session.ail:2556` | `st.world_state` → `c2_finalize` | **DROP** (documented) |
| 3 | `Ok(payload)` | `session.ail:2581` | `token_to_world(chain.next_state)` → `dispatch_step` | **THREAD** (B2b) |

**Read side: clean, and one part of it was worth checking rather than assuming.** `pre_ctx`
(`:2536`) is built from `st.world_state`, and nothing in the `CallModel` arm advances the world
before it — WI-D4 deleted the only thing that did, which is what that arm's comment records. The
fold `fold_pre_step_chain_rec` (`ext/runtime.ail:253`) re-seats `{ ctx | world: … }` per stage and
carries `world1` through **every** arm including the rejected-output one.

**The `ctx.ports` question the tool-handle slot failed on does not arise here, and the reason is
structural rather than lucky.** `ext_ports_of`'s `ai_step` closure **takes the world as an
argument and returns the successor** — "this closure captures no world at all — which is the
point" (`session.ail:859`). The only closure in that bridge that still captures is `env_get`, the
last classifier-2 member, and `Env ∉ {AI, IO, Trace}`. So a stale `ctx.ports` cannot re-serve a
consumed cursor at this slot **for any binding**, not just for the ones in the tree today.

### 1.3 S34, re-verified on the two folds this item reads

Both folds stamp and clear the holder by **key-set**, never by world round trip:
`fold_pre_step_chain_rec` and `decide_one_finalize` call `stamp_holder(world, h.id)`;
`dispatch_pre_step_chain` and `dispatch_solver_candidate` call `clear_holder(out.next_state)`.
`stamp_holder`/`clear_holder` are `put_key` on the token's own JSON object
(`ext_world.ail:578`, `:582`) — no `token_to_world` → edit → `world_to_token` anywhere on either
path. **No new fold was added**, and the witness's `ai_step` call goes through the token the fold
already stamped, so the round trip S34 forbids is never constructed.

---

## 2. THE CAPABILITY BOUNDS — four compiler verdicts, verbatim

Both slots' reachable surfaces are now executable rather than prose, in
`scripts/dst/run_declared_vs_performed.sh` (`port_accepts` / `port_rejects`), which is the file
that already houses the effect checker as a third producer. The row algebra: a port call
type-checks in a hook body exactly when the port's row is **included** in the slot's row.

```
✓ on_pre_step -> ports.ai_step: ACCEPTED under ! {AI, IO, Trace} — the call is within the
  slot's declared surface
✓ on_pre_step -> ports.clock_now: REJECTED under ! {AI, IO, Trace} — the port's own row is
  not included in the slot's (Missing effects: Clock)
✓ on_solver_candidate -> ports.proc_exec: REJECTED under ! {Process} — the port's own row is
  not included in the slot's (Missing effects: FS, IO)
✓ on_solver_candidate -> AMBIENT std/process.exec: ACCEPTED under ! {Process} — the call is
  within the slot's declared surface
```

Each rejection carries its **widened control** — the same call under
`! {AI, IO, Trace, Clock}` and `! {Process, IO, FS}` is accepted — so the negative result is
attributable to the row and not to a malformed call. Six rows total; `declared_vs_performed`
runs **46 passed, 0 failed**.

**The disclosure-table entries these four settle:**

| Slot | Declared row | `ExtPorts` fields reachable | The only subprocess route |
|---|---|---|---|
| `on_pre_step` | `! {AI, IO, Trace}` (`types.ail:882`) | **1 of 10** — `ai_step` (`:293`) | none; no `Process` at all |
| `on_solver_candidate` | `! {Process}` (`types.ail:956`) | **0 of 10** | **ambient** `std/process.exec` |

### 2.1 The correction WI-D24 shipped into source, in three places

The plan's D24 milestone entry was corrected at the D25 handoff. **The source was not**, and it
carried the same false claim at three sites, all now re-tensed two-part per S15:

* `ext/runtime.ail:272` — *"Three of the seven slots can — `on_tool_handle`,
  `on_response_intercept` and `on_solver_candidate`"*. **Two can.**
* `ext/runtime.ail:394` — *"one of the three that can actually reach `ExtPorts.proc_exec`"*.
* `ext/runtime.ail:442` — *"`! {Process}`, so this slot reaches the seam too"*. **It does not.**

`first_intercept`'s claim (`! {IO, Process, FS}`, so this slot reaches the seam) is **true** and
was left alone — the whole row is included.

This is S33's shape in a reviewing role: "can" was inferred from the **presence** of `Process`,
not from row **inclusion**. The narrowed statement now in source is *ambient subprocess only*
rather than *no subprocess*, because `context_mode`'s binding does spawn a `node` bridge through
`std/process.exec` today — unmediated, and no `ExtPorts` widening involved.

---

## 3. THE SEAL-TERMINAL SEAM — resolved by threading, not by re-grounding

Both `Err` arms now take `token_to_world(chain.next_state)`; the argument swap is
line-count-neutral. **The D4-era ground did not survive re-measurement**, and the reason is
one line of reading: WI-D4's justification is entirely about *its own deleted resolution*
("the deleted resolution was the first thing this arm did to the world, so its successor was
`st`'s own") and says nothing whatever about the chain. The chain is dispatched **below** that
comment and **above** the match, so a pre-step hook's effects have already happened on all three
arms when the seal decides. Sealing failed; the effects did not.

The comment at `session.ail:2520` is re-tensed two-part: WI-D4's reasoning kept in the past tense,
the expired scope clause quoted verbatim before being answered, and the new argument stated with
its witness named.

**Nothing was load-bearing.** No gate's recorded hash or program bytes moved beyond the two
attribution anchors the cascade re-issues (§5) — the stop condition did not fire.

---

## 4. THE WITNESS — the first performing `on_pre_step` binding in the tree

`scripts/dst/world_state_probe.ail`, under `make world_state`. Six new rows, three per terminal.

**Why the instrument had to be built rather than found.** Both seal terminals were **already
driven** in this file — the env row drives `SealSystemPromptEmpty`, the files row drives
`SealExhausted` — and both were green **across the drop**, because every `on_pre_step` binding in
the tree returns `ctx.world` unchanged and a drop then produces a world byte-identical to a
thread. That is S29's invisibility clause, met in the file that would have caught it.

**`consume_steps` / `consuming_pre_step_2` / `consuming_pre_step_3`.** `ai_step` is the *only*
seam available at this slot (§2), and it threads the provider seam
(`ext_ports_of` → `ext_ai_step` → `Ports.model_step`), so under a scripted world each call takes
the head of `WorldState.script`. What is **left** in the terminal world is therefore a quantity the
driver's own bookkeeping never writes — which is what stops the row being an identity.

| Row | Script | Hook consumes | Terminal must hold | Measured |
|---|---|---|---|---|
| `seal(SystemPromptEmpty)` | 6 | 2 | **4** | `finish=error script left=4 of 6 (control 6)` |
| `seal(CompactionExhausted)` | 5 | 3 | **2** | `finish=compaction_exhausted script left=2 of 5 (control 5)` |

Per S7 no two quantities are equal — 6/2/4 and 5/3/2 — so a crossed wire cannot cancel out. Each
terminal also carries **two rows that are not the threading claim** (S24): a **reachability** row
asserting the run actually took its seal terminal (a run that sealed successfully would leave the
script whole too, which is byte-identical to the drop), and a **control** row running the same
world with `passthrough_pre_step`, which must leave the script whole — so the count is
attributable to the hook rather than to the driver.

### 4.1 The mutant

Revert both `c2_finalize` arguments to `st.world_state`; restore by file copy (S17).

```
seal: SystemPromptEmpty finish=error script left=6 of 6 (control 6)
  ✓ seal(SystemPromptEmpty): the run took the seal terminal
  ✗ seal(SystemPromptEmpty): the terminal world carries the pre-step chain's successor
      — the hook consumed 2 of 6 scripted steps, so the terminal world must hold 4 — got 6.
  ✓ seal(SystemPromptEmpty): a NON-performing hook leaves the script whole
seal: CompactionExhausted finish=compaction_exhausted script left=5 of 5 (control 5)
  ✓ seal(CompactionExhausted): the run took the seal terminal
  ✗ seal(CompactionExhausted): the terminal world carries the pre-step chain's successor
      — the hook consumed 3 of 5 scripted steps, so the terminal world must hold 2 — got 5.
  ✓ seal(CompactionExhausted): a NON-performing hook leaves the script whole
world_state_probe FAIL
```

**Exactly the two threading rows go red and the four reachability/control rows stay green**, which
is the discrimination the row set was built for: the mutant is the drop, not a broken fixture.

### 4.2 The solver slot gets the narrowed label, and does not get a fixture

**No threading witness was built for `on_solver_candidate`, and that is the finding rather than a
gap in the work.** With zero reachable ports (§2), a hook at this slot cannot change world
*content*; a threading fixture would have to hand the fold a fabricated token, and a fabricated
token dies at the next `token_to_world` — S34's total-decoder fact, met from the other side.
**A row that passes whether or not the threading is correct is worse than no row** (S33), so the
claim is labelled for what it is:

> The four `on_solver_candidate` arms are verified **by reading, source-anchored** (§1.1), not by
> fixture, and they will stay that way until a row widening gives the slot a port.

D20 §8.2 is the precedent and the wording is reused. This is deliberately **not** instance 8 of
instrument-weaker-than-claim: naming a fixture-less claim as fixture-less is what avoids the count.

---

## 5. THE CASCADE — two anchors, five files, and the six-file law narrows

`session.ail` grew **+21 lines** (the comment re-tense; the two argument swaps are neutral), all
inside `c2_loop`'s `CallModel` arm. That arm sits **below `:1476`** and **above** the two
`provider.ports.clock_now` sites, so:

* `session.ail:2921 → :2942` and `:3031 → :3052`, both +21, both compared to `git show HEAD:`
  character by character and **byte-identical** — pure offset drift.
* **`:1111`, `:1370`, `:1476` did not move.** The first re-issue in this project's history where
  the five session anchors move as a **proper subset**.
* `ext/runtime.ail` grew +20, **entirely below its `:199` anchor** (three comment corrections
  inside the dispatchers), so `ext/runtime.ail:199` and `tool_phase.ail:318` are both unmoved and
  the three discovered-site fixtures are untouched. WI-D24's corrected law, used in the direction
  it was written for.

**Files re-baselined — FIVE, not six:**

1. `src/core/session.ail` (the edit itself)
2. `tools/predicate-anchors/anchors.sh` — `for l in 1111 1370 1476 2942 3052`
3. `src/core/dst_attribution_table.ail` — the two `CoreSite` literals
4. `src/core/dst_driver_only.ail` — **v21 → v22**, `content_hash` re-recorded
5. `src/core/dst_driver_plus_no_ops.ail` — **v8 → v9**, `content_hash` re-recorded

`sha256:4339fef00fff65bcbdaa42374424ec375b4f4329d2f85db5ebaee41b23d44572`
→ `sha256:753839ba98b85c64d55fe18dc6062aaf2b8dbc541e58fbae8de77ba4122a34bc`
(derived by running `table_content_hash()`, not transcribed).

### 5.1 The law, corrected a second time

**`scripts/dst/attribution_table_dst.ail` needed no edit.** Its only session anchor is `:1476`
(in `omitted_site`), and its HEAD inventory is **derived** — `head_inventory()` calls
`unconditional_core_sites()` rather than copying it. So the six-file form is **the price of moving
an anchor that fixture pins**, not the price of moving a `session.ail` anchor at all.

Stated once for all three measurements, and recorded in `anchors.sh` where the enumeration lives:

> **The cascade's width is the set of files that PIN the anchors that moved**, derived by the
> widened grep, not read off which source file was edited. D21 read it off the edited file and was
> wrong twice — **nine** when `tool_phase` was untouched (D24), **six** when
> `attribution_table_dst` was untouched (here).

`make sync_packages` was **not** run and is not owed: `types.ail` is untouched and the probes live
outside the ABI package.

---

## 6. GREEN — run, not reported

| Gate | Result |
|---|---|
| `world_state` | **PASS** (incl. the six new seal rows and all five poison pairs) |
| `discovery` | PASS |
| `execution_program` | PASS |
| `program_persistence` | PASS |
| `declared_vs_performed` | PASS — **46 passed, 0 failed** |
| `conformance` | PASS |
| `anchors` | PASS — all ten anchors, two re-baselined |
| `predicate_anchors` | PASS |
| `attribution_table` | PASS — identity `(c0fbf10, sha256:7538…)` |
| `profile_definition`, `profile_coverage` | PASS |

**Yields and inventory re-run and unmoved — this item routes nothing:**

| Instrument | Before | After |
|---|---|---|
| `ext_hook_scope` — HOOK-PORT-MEDIATED | 5 of 15 | **5 of 15** |
| `ext_hook_scope_selftest` — shipped closure verdict | 4 of 15 | **4 of 15** |
| `ext_ambient_inventory` — PORT-MEDIATED | 4 of 15 | **4 of 15** |
| compose | 11 / 32 | **11 / 32** |
| `ext_call_inventory_selftest` reachability | 10 derived = 10 pinned | **identical** |

### 6.1 A THIRD standing red, pinned to HEAD by measurement

`make effect_inventory_selftest` is **RED**, and it is **red at HEAD with my changes stashed**:

```
FAIL: the self-test compared ZERO modules, so it certified nothing.
      `ailang iface` produced no parseable interface for any stdlib module
self-test: agree=0 disagree=0
```

Not mine, and **not one of the two reds the register carries** (`test_coverage` and
`test_coverage_selftest`, pinned since D22). It is a toolchain/environment condition — `ailang
iface` yields nothing in this checkout — and it is exactly the pass-shaped-absence class the gate
was written to refuse, refusing correctly. **It goes on the maintenance register**, not the queue:
it blocks neither clause of the goal line. Flagged because the register records two standing reds
and there are three.

---

## 7. THE BASE RATE, STATED HONESTLY FOR S29's RECORD

S29 reads *"Base rate 2 of 2. `on_pre_step` and `on_solver_candidate` are unaudited."* The record
after this item:

> **Four slots audited. Two audited LATE, after routing, and both dropped
> (`on_response_intercept` at D19, `on_tool_handle` at D20 — the second worse than the first).
> Two audited BEFORE routing, here: `on_solver_candidate` carries its successor on all four arms,
> `on_pre_step` on one arm of three, and the two drops were a DOCUMENTED deferral disclosed in a
> comment at the site rather than an unknown drop. No unknown drop was found in either path.**

**And the causal claim is qualified rather than asserted.** The solver slot came back clean
**largely because D19's intercept work re-seated it in passing** (`{ post_ctx | world:
intercepted.next_state }` is D19-tagged), not because the rule prevented a fresh drop. What the
standing rules can be credited with is the `on_pre_step` half: the drop was *written down at its
site* by the item that deferred it, which is the disclosure discipline working, and the audit
found it by reading the comment rather than by discovering the defect. **The rule changed the
observability, and D19 changed the code.** Both belong in the plan; neither is the other.

---

## 8. THE COUNTERS, KEPT APART

**Silent-wrong: 75, unchanged.** The seal-terminal drop is **not** a new site, on the counter's
own definition and on the handoff's stated default: it was **disclosed at its site** by the item
that deferred it, no performing `on_pre_step` hook exists in production at HEAD, so no run has
ever shipped the wrong answer from it. A documented deferral is owed work, not a silent defect.
**No undocumented drop was found anywhere in the two paths**, which is the condition the handoff
set for a count.

**Instrument-weaker-than-claim: 7, unchanged.** Deliberately: §4.2 exists precisely to avoid
becoming instance 8. A fixture-less solver threading claim labelled as fixture-backed would have
been one; labelled as fixture-less it is a disclosure.

**One ruling left for review rather than taken.** The three false seam claims (§2.1) shipped in
production source and were read by nothing that could contradict them. They are **prose, not a
value**, so I have not counted them under silent-wrong — the counter tracks wrong answers a
program produces. If review reads a shipped-and-wrong source claim as countable, this is the site.

---

## 9. WHAT ITEM 4 (ROUTING COMPOSE'S `exec` SITES) INHERITS

**Nothing in these two paths constrains where compose's routed `exec` calls may land, and the
reason is now a compiler verdict rather than a reading.**

* **`on_solver_candidate` cannot host a routed `exec` call at all.** Zero `ExtPorts` fields are
  callable under `! {Process}` (§2), so `ctx.ports.proc_exec` does not type-check there. Compose
  binds this slot (`compose.ail:1041`), and **any `exec` in that binding stays ambient** until the
  row widens — which is the barrier question, an ABI event, and not on the critical path.
* **`on_pre_step` cannot host one either.** No `Process` in the row at all.
* **The two slots that CAN are `on_tool_handle` and `on_response_intercept`**, and both are
  already routed and already audited (D19, D20). So item 4's landing sites are exactly the two
  it already has, and the identity work D24 shipped reaches both.
* **The seal-terminal fix is not on item 4's path** and cannot interact with it: it is a terminal
  arm, reached only when the seal fails, with no tool dispatch downstream.
* **The stale `post_ctx.ports` at `session.ail:2679`** (§1.1) is the one thing worth carrying
  forward. It is unreachable at the solver slot today. If item 4 or any later item ever widens
  `on_solver_candidate`'s row to give it a port, that staleness becomes live in the same motion —
  and it is D20's read-side defect, in a second place, waiting for its first caller.

**Owed and unchanged:** C5's compose-bearing profile (item 5) is still the debt every report since
D19 names; the solver slot's threading claim is fixture-less until then and beyond.
