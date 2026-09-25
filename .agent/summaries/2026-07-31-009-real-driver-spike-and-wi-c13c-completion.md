# 2026-07-31 project-009 real-driver spike, WI-C13c completion, upstream issue prep

## Context

Branch: `arniwesth/mot-44-motoko_dst_execution_primer`

HEAD at summary time: `c3ea44f docs(009): restructure the upstream issue to the repo's feature_request form`

The session started from a single instruction — implement
`.agent/projects/009_motoko_dst_execution/PLAN-spike-real-driver-vertical.md` — and then followed
the findings outward: into a code fix on the main working branch, into publishing the AILANG
prototype on a fork, and into preparing the upstream issue for filing.

Three branches ended up in play:

| Branch | Role | State |
|---|---|---|
| `arniwesth/mot-44-motoko_dst_execution_primer` | the durable work | 7 commits, pushed |
| `spike/009-real-driver-vertical` | throwaway spike code | 5 commits, pushed, **never merges** (draft PR #103) |
| `spike/motoko-009-prototype-v031` (AILANG clone) | the recorded-stream prototype | 2 commits, pushed to `arniwesth/ailang` |

## The spike: all five questions resolved

Executed the plan in full. Q1, Q2, Q4 and Q5 confirm; Q2's second clause falsifies; Q3 is measured.

**Q3 — the `Message` migration**: 14 minutes, 28 files, 69 sites given `images: []`, 47
over-applications reverted, **7 sites needing genuine judgement**. The finding that matters is not
the count: `Msg` is documented as "structurally identical to `std/ai.Message`", and the codebase
relies on it — `Message` values cross into `[Msg]` APIs implicitly in seven places, so widening
breaks the identity and each crossing needs a written conversion. A `messages_to_msgs` export had
to be *added* to `phase_vocab`. A grep-derived estimate counts the 69 and misses all 7.

**Q1 — world-state threading**: confirms. 17 successor literals updated; every existing scenario
still passes. The first attempt put the provider inside the adapter (`LiveWorld(StepProvider)`) —
the natural reading of D1 — which type-checked, kept `check_core` green, and silently failed 6 of
18 scenarios by freezing the `Scripted` cursor.

**Q2 — clock routing**: confirms on its criterion (deterministic run completes with `Clock`
withheld), falsifies on its second clause. The profile-reachable set is **14 reads, not 4**; nine
are extension-side, and `ExtPorts.clock_now` — the seam that would route them — exists in the ABI
with **zero call sites repo-wide**.

**Q4 — one canonical `RunSummary`**: confirms, after fixing what the question found. The starting
count was **zero on every terminal path** — all seven returns called `emit_run_summary`, which only
ever called `ledger_emit`, so the returned `LedgerTrace` never contained a `RunSummary`. Routing
them through one `c2_finalize` fixed it without restructuring the driver.

**Q5 — discovery→replay parity**: confirms, and produced the largest finding. Discovery initially
returned `program_non_empty=0` despite the prototype working standalone, because `ported_provider`
funnels every provider through `Ports.model_step` **before the loop starts**, and its
`Result[StepResult, AIError]` return type structurally cannot carry an emission log. The chunks die
one layer *above* `std/ai`, so no upstream change alone fixes it.

## Toolchain: the clone was wrong, then rebased onto released v0.31.0

The in-repo `ailang/` clone turned out to be **v0.28.0-dev**, carrying neither the
`stepWithStreamRecorded` prototype nor the v0.30.0 `Message` widening — both had been built on a
different machine. Repinning to it is a no-op. After the user clarified, the clone was fetched and
checked out at **released v0.31.0** (`1f6f7dd28`) and the prototype reimplemented there.

That surfaced an unplanned measurement worth more than the reimplementation: **the v0.26.0 →
v0.31.0 repin costs 381 effect-row edits across 71 files, plus three extension-ABI widenings**
(`ExtPorts.ai_step` gains `Trace`; all four `ExtensionHooks` rows gain `Rand` and `Trace`). Since
`packages/motoko-ext-abi/types.ail:7` states that bumping `ExtensionHooks` is a major version,
**repinning forces an extension-ABI major and a coordinated re-release** — a scheduling fact
independent of the upstream API, and a D1-gate prerequisite.

Two latent under-declarations that v0.26.0 accepted also surfaced: `agents_md.walk_agents` performs
`FS` undeclared, and `motoko_ext_omnigraph.register_with_config` performs `Process` undeclared.

The stale-compile-cache hazard already documented in `spike/README.md` **reproduced**, this time
across a compiler *version* change rather than a stdlib one: `rpc.ail` and `supervisor.ail`
reported a row mismatch against correct source until every `.ailang/cache` was cleared.

## Six findings, filed in a note

`NOTE-spike-findings-real-driver-vertical.md` carries them in the same Defect/Grounding/Action shape
the two prior ADR reviews used:

- **F1** — D1 does not say who owns the provider cursor once `world_state` exists; both answers
  compile and one silently freezes the script cursor.
- **F2** — D1's sequencing hides a mandatory, upstream-independent change (widening
  `Ports.model_step`) behind the upstream gate, and the obvious place to adopt the new API is
  **unreachable dead code**.
- **F3** — D4 mischaracterises the withheld-`Clock` backstop as build/profile-level; it is a
  run-time check, which is both stronger and weaker than the ADR assumes.
- **F4** — 14 profile-reachable clock reads, not 4; `ExtPorts.clock_now` has zero users.
- **F5** — D6's versioned event-vocabulary artifact does not exist, and `ledger_record_name` names
  3 of 34 variants, collapsing the rest to `"wire"` — too lossy to write a conformance check
  against.
- **F6** — a confirmed defect *in the code*, not the ADR (below).

## F2's dead branch, traced to an unfinished refactor

Investigating F2 produced the session's most consequential thread. `dispatch_step`'s `LiveAI` and
`Scripted` branches were **provably unreachable** from every session entry point: all entry points
call `ported_provider` first, and `dispatch_step`'s `Ported` branch returns `Ported(ports)`
unchanged, so `st.provider` is always `Ported(_)`.

That is not rot. Commit `f30f475` — *"WI-C13c Wire model dispatch through ports"* — added the
normalisation and left `dispatch_step` untouched. A **half-completed refactor**, invisible because
the tests kept passing through the new path.

Three consequences, all recorded:

1. **A decoy at the migration site.** `dispatch_step`'s `LiveAI` branch held the only
   `stepWithStream` call in the driver's call graph — exactly where a reader would adopt the
   recorded API, changing nothing.
2. **It defeats the audit D4/D5 depend on.** A grep-based routing audit reports `stepWithStream` as
   a live seam when it is not. D5 does not say the audit must be reachability-aware.
3. **Three scripted-provider implementations exist, and the only one that runs threads no cursor.**
   `dispatch_step`'s branch (ADT tail, dead), `scripted_ports_from_steps` (derived from
   `assistant_count`, live), and `ScriptedPortsState` (explicitly threaded, unit-tested, never
   wired in).

## F6: hypothesis raised, then tested, then confirmed

The third consequence produced a hypothesis — that a compactor removing assistant messages would
move the derived index backwards — recorded deliberately as *untested*. The user asked to test it.

`scripts/dst/spike_scripted_cursor_probe.ail` drives `run_v2_session_traced(..., Scripted(script))`
twice through the real driver, varying only the `on_pre_step` hook, with a fold reproducing
`compaction_ai`'s shape (`prefix ++ [summary] ++ recent_turns`) and no AI call:

```text
control: served=[s0,s1,s2,s3,done]                      advancing=true   outcome=ok
folding: served=[s0,s1,s2,s2,s2,s2,s2,s2,s2,s2,s2,s2]   advancing=false  outcome=err budget exhausted
```

**Confirmed, and worse than predicted: it is a pin, not a rewind.** The payload's assistant count
stops at the compaction floor while the real history keeps growing, so one scripted step is served
forever and the run dies of budget exhaustion — indistinguishable from an ordinary result.

Bounded honestly: structural compaction cannot trigger it (`elide_old_tool_results` shortens
content, never removes messages), and current scenarios sit below the context limit. But D2's
seeded generation of longer programs is exactly what makes it reachable.

Re-verified on the pinned v0.26.0 toolchain with byte-identical output, so the defect is the
driver's, not an artifact of the repin. The probe exits 1 by design and is **not** wired into any
Makefile target.

## WI-C13c completed on the working branch

`89a1d67` — the only production change of the session, and net **−8 lines**:

- `ported_provider` returns `Ports`; normalisation happens once, at each exported entry point.
- `C2LoopState.provider` is a `Ports`, so the loop cannot hold anything else.
- `dispatch_step` reduces to its single reachable branch, dropping `rt` and `next_provider`.
- `ext_ports_for_provider` collapses into `ext_ports_of`.

`StepProvider` is unchanged and remains the entry-point argument type — scenarios still pass
`Scripted(script)`. Verified against the repo's actual pin (v0.26.0): `check_core` 34/34, and every
DST gate unchanged (`phase_c2_wiring` 18, `phase_c_l1` 15, `phase_c_approval` 7,
`compaction_policy` 3, `compaction_catalog`, both seeded families, `runtime_status_tool` 2,
`long_qwen` 8, conformance 6/6).

One hypothesis was **wrong and caught before shipping**: I expected the dead `Scripted` branch's
`play_chunks` call to be what kept `dispatch_step`'s callback row at `{IO, Trace}`, and that
deleting it would break the driver's Trace-performing sink. Reducing the function in place compiled
clean, so that was false. It would have been written into the note as a fourth consequence.

## Publishing and disposal

- The AILANG clone was repointed to the user's fork: `origin` = `arniwesth/ailang`, `upstream` =
  `sunholo-data/ailang` with **its push URL disabled** so an upstream push cannot happen by
  accident. The prototype branch and the `v0.31.0` tag were both pushed, so the compare against the
  released base renders for anyone.
- The spike branch was rebased **13 commits → 5, code only**, after the user asked to strip the doc
  copies that had diverged from the canonical versions on `mot-44`. The four Q1–Q5 code commits kept
  their original hashes (they predate the first doc commit); only the mixed v0.31.0 commit was
  rebuilt, as `6382dc8`. Verified lossless — `git diff` against the pre-strip tag showed exactly the
  five doc artifacts and nothing else — tagged `spike-archive-pre-strip` for recovery, and
  force-pushed with `--force-with-lease` pinned to the expected SHA.
- Draft PR #103 (`spike/009-real-driver-vertical` → `mot-44`) **must not be merged**: a test-merge
  conflicts in six files and would revert `89a1d67`, a commit the branch predates. That constraint
  is recorded in the note, not only in the PR.

## Upstream issue prepared, not filed

`ISSUE-BODY-recorded-stream-api.md` was refreshed and then restructured:

- Re-anchored from an unfetchable dev commit on another machine to the **v0.31.0 tag**, with a
  verified-clean patch and a public compare link.
- The four Go tests the body *claimed* were written, since they only existed on the other machine.
  All nine pass. The error-path test needed a new fake — the existing `fakeStepHandler` returns
  before emitting anything, so "partial stream then failure" was previously untestable upstream.
- Duplicate check re-run 2026-07-31 (searches must include closed issues): **no duplicate**; #136
  remains the nearest neighbour.
- **Restructured to the repo's actual issue *form***. `.github/ISSUE_TEMPLATE/feature_request.yml`
  has five fields, so "paste the whole file" was wrong. Rebalanced per the form's own steer to lead
  with the use case; all implementation detail moved to Additional Context. The label note was also
  wrong — the form applies `enhancement`, not `feature`.

Filing remains with the user (no `gh` in this environment, and it is outward-facing). The MCP
`submit_feedback` route was checked and rejected: it queues an anonymous submission to a triage
inbox rather than creating a tracked issue, and its 10 KB body limit is under our 16 KB.

## Open items

1. **File the upstream issue** — the only item with third-party latency.
2. **F2's port widening** — highest-value code item, no upstream dependency; shrinks the eventual
   adoption to one closure in `live_ports` and unblocks the F6 cursor fix.
3. **ADR revision round** for F1–F6, which gates Track 0.
4. **Sequence M2** (the ABI major) into the plan before Track 1.
5. Retitle PR #103 so the merge hazard is visible at the button.

## Loose thread worth recording

AILANG issue **#386** — *"Effect-row inference regression: show() in effectful-lambda interpolation
collapses effect row"*, closed — is plausibly the same family as a row-unification oddity hit and
**sidestepped rather than diagnosed** during the WI-C13c work: moving the reduced dispatch into
`session.ail` as a new `provider_step` failed with a closed-row error, while the identical shape
compiled both in an isolated probe and in `stub_step.ail`. Keeping the function in its original
module was the smaller change and works, but the underlying module-sensitivity is not understood.
If it recurs during the D1 migration, #386 is the first place to look.
