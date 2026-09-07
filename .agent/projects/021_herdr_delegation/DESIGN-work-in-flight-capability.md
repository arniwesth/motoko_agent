# Design: `WorkInFlight` — letting one extension tell another that work is outstanding

Date: 2026-09-07
Status: **Scope only. Nothing built. Needs an owner decision BEFORE the ABI freeze**, because both
halves of it are source-breaking additions that a freeze closes off.
Provenance: everything measured against the tree at `cc137f2` (ABI 7.2). The ripple figures in §5
are counted, not estimated, and the comparable in §5.1 is `cec2e25f`'s actual diffstat.

---

## TL;DR

`progress_contract_guard` needs to know whether another extension has work outstanding, so it does
not nudge a session that is legitimately waiting. Today it finds out by **reading English sentences
that `motoko-ext-herdr` wrote into tool-role messages** (`progress_contract_guard.ail:179`,
`has_open_delegate`). Re-wording one sentence in `herdr.ail` silently degrades the guard.

The obvious fix — a delegate count on `ExtCtx` — is wrong, and §2 says why. The right shape is a
capability: extensions **declare** outstanding work, the host **aggregates** it, and `ExtCtx`
carries the aggregate. That is two source-breaking ABI additions (a `Capability` variant and an
`ExtCtx` field), so it is now or never.

**It is not urgent on its own merits.** The workaround works today and fails in the safe direction
(a nudge, never a wrong allowance). The reason to decide now is the freeze, not the bug.

## 1. What the guard actually needs

Not "how many delegates". The question it asks is:

> Is there work outstanding that I should wait for, rather than telling the model to continue?

That question is not about delegation. A compose job, a long-running tool, a queued verification
and a delegate all answer it the same way. The herdr-shaped version is an accident of which
extension needed it first.

## 2. Why it must NOT be a plain `ExtCtx` field the host fills

`ExtCtx` is built by the core (`session.ail:1609`, four call sites, plus two in `rpc.ail` and one
at turn end). For the core to fill `open_delegates` it would have to know what a delegate is.

**That is precisely what ABI 7.0 removed.** `herdr-reap.ts` was deleted because it forced the host
to know the token key `mot-owner`, the token format, herdr's JSON shape and its opt-in variable —
and `exit-actions.ts`'s header now records the rule: *"Nothing here knows what a delegate is."*
Re-teaching the core about delegation to serve one guard would undo that in a single field.

## 3. Why the filesystem is not the answer either

The guard could read herdr's dagr run file directly — the data is real and already on disk. That
couples one extension to another extension's file path, file format and naming scheme, which is a
worse version of the coupling it replaces: today's prose coupling at least breaks loudly in a test,
where a silent format drift would just return "nothing in flight" for ever.

And there is no channel to use instead: **`ExtPorts` has exactly ten members** — `ai_step`,
`tool_handle`, `file_read`, `file_write`, `file_remove`, `path_stat`, `dir_list`, `dir_make`,
`clock_now`, `env_get`. No shared memory, no message bus. `ExtCtx.artifacts: Json` looks like a
candidate and is not: only a `Compactor` can write it (`Compacted(msgs, note, artifacts)`), so no
other extension can put anything there.

## 4. The proposed shape

Mirrors `ExitIntent` deliberately — it is the one capability in the ABI that already solves
"compute it while alive, consume it somewhere else".

```ail
-- What one extension tells the rest of the system it is waiting on.
export type WorkItem = {
  label: string,     -- the declaring extension's own name for the class of work
  detail: string     -- one line, for a diagnostic; never parsed
}

export type WorkOutcome = { items: [WorkItem], next_state: ExtWorld }

  | WorkInFlight(string, (ExtCtx) -> WorkOutcome ! {FS})
```

And on `ExtCtx`:

```ail
  -- 7.3: what OTHER extensions declared outstanding as of the previous turn
  -- end. Empty when nothing is, and empty on the first turn.
  work_in_flight: [WorkItem],
```

### 4.1 The ordering problem, and the precedent that solves it

**A render that needs an `ExtCtx` cannot run while the `ExtCtx` is being built.** That circularity
is the first thing that kills a naive version of this.

`ExitIntent` already answers it: the host renders at **turn end** — where a real `ExtCtx` exists —
and the value is consumed later. Here, "later" is the next turn's `ExtCtx`:

```
turn N   … post_ctx built → hooks run → dispatch_work_in_flight(rt, ctx) → [WorkItem]
                                                                              │ carried in C2LoopState
turn N+1 … mk_v2_ext_ctx(…, work_in_flight: carried, …) ──────────────────────┘
```

Consequence to state plainly: **the value is always one turn stale.** For "is a delegate open" that
is the same staleness the prose approach has, and the guard's decision tolerates it — a delegate
launched this turn is nudged once, at worst. A consumer needing fresher data than that should not
use this slot.

### 4.2 The effect row, and the constraint that is not negotiable

`! {FS}`, exactly as `ExitIntent` has it — herdr's answer comes from its run file.

`WorkOutcome` **must** carry `next_state`. This is not symmetry for its own sake: `ExitIntent`'s v1
returned a bare list and read `std/fs` ambiently, and `make driver_plus_no_ops` **rejected it** —
the barrier derivation classifies a slot by (rowed, dispatched unconditionally, returns explicit
world state), and a rowed unconditional slot returning no world state makes every extension in the
tree non-zero-barrier at a stroke. A `WorkInFlight` that forgets this fails the same gate the same
way, and the ABI already records the lesson.

## 5. The ripple, counted

| what | where | size |
|---|---|---|
| new types + variant | `packages/motoko-ext-abi/types.ail` | 1 file |
| `ExtCtx` field | **37 literals across 31 files** | mechanical; identical to 7.2's pass |
| registry arms | `src/core/ext/registry_normalize.ail` (3 match sites) | small |
| dispatcher | `src/core/ext/runtime.ail` (3 match sites + ~60 lines, mirroring `dispatch_exit_intents`) | moderate |
| turn-end render + carry | `src/core/session.ail`: one call site, one `C2LoopState` field, 4 `mk_v2_ext_ctx` sites | moderate |
| DST coverage vocabulary | `dst_profile_coverage.ail` (a `Kind`, its class, its id, the all-kinds list — 6 sites), `dst_profile.ail`, `dst_driver_plus_no_ops.ail` | moderate |
| profile tooling | `tools/ext_ambient_inventory/hook_scope.py` + its `expected.json` fixture, `tools/profile_definition/check_no_op_profile.py` | small, but the ambient inventory is **pinned at 18** and will move |
| producer | `motoko-ext-herdr` declares it from `open_task_ids` — the predicate already exists | small |
| consumer | `progress_contract_guard`: delete `has_open_delegate`'s prose reading, read the field | small |
| gates | new `scripts/verify_work_in_flight.ail`; the 6 `verify_*.ail` and every `Capability` fixture gain an arm | moderate |

**≈15–20 files, and no TypeScript at all.** The host executes nothing here, which is the whole
difference from `ExitIntent`.

### 5.1 The comparable, for calibration

`cec2e25f` (ABI 7.0's `ExitIntent`) touched **44 files, +2127/−741**. That included deleting the TUI
reaper, building `exit-actions.ts` from nothing and its test suite. This has no host executor, no
manifest, no TS, and reuses the dispatcher shape. Call it **a third of that**, with the same
proportion of it being fixture churn.

## 6. What this does NOT fix

- **It does not make the guard's other heuristics structural.** `candidate_self_reports_incomplete`
  and friends still read the model's prose, which is correct — those are claims about the model's
  own answer and there is nowhere else for them to come from.
- **It does not settle the run file**, and it is not a substitute for the startup sweep.
- **It is one turn stale** (§4.1), by construction.

## 7. The decision, stated as options

1. **Take it whole, before the freeze.** ~15–20 files. Producer and consumer both exist and land in
   the same change, so the surface ships with a reader — the thing `PublishFile` got wrong in 7.0.
2. **Freeze the surface, wire it after.** Add the variant, the types and the field; have the host
   dispatch and return `[]`. Cheaper now, and the freeze stays open on the shape. **The 7.0 review
   argued against exactly this** and dropped `PublishFile` for it ("no consumer"), so option 2 is
   the one this project has already decided it does not like.
3. **Decline it.** The guard keeps reading herdr's sentences. Then say so in
   `progress_contract_guard.ail` — the comment there currently calls a structured flag "the better
   long-term shape", and if the answer is no, that line should record that it was asked and
   refused, so the next session does not re-open it.

**Recommendation: 1, or 3 with the comment updated.** Not 2.

The honest case against 1: the only consumer today is one guard, whose workaround fails safely. If
the freeze is the only reason to build it, that is a real reason but a thin one — and option 3 is
not a failure, provided it is written down rather than left looking open.
