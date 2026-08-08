# 2026-08-08 Cluster 43: WI-D17 — the core filesystem *write* world class

## Context

Branch: `arniwesth/mot-78-wi-d16-route-b-part-1`.

Session span: `7c473e2` → **`c86f357`**. Input was
`HANDOFF-execute-d17-the-file-write-world-class.md`, grounded against HEAD `7c473e2`
(`2026-08-07T20:29:30Z`). Pin **v0.33.0**. First command `05:39Z`, **~1h05m**.

**The half WI-D16 decided and deliberately did not build.** Twenty-eight files,
**1 653 insertions / 82 deletions**, of which **524** are the record.

```text
src/core/ports.ail                      292 +-   FileMutation, 6 adapters, 2 Ports fields
src/core/world_state_probe.ail          114 +-   9 assertion rows at the adapter
src/core/dst_interaction.ail             95 +-   2 constructors, 6 derivations, the version answer
src/core/ext_world.ail                   93 +-   the JSON codec both ways + an all-variant round trip
src/core/test/stub_step.ail              91 +-   live/recording/generating bindings + THE recording note
scripts/dst/program_persistence_dst.ail  81 +-   the frozen-specimen SPLIT
packages/motoko-ext-abi/types.ail        47 +    2 ExtPorts rows, 1 new type
src/core/dst_discovery.ail               44 +    absent_classes pinned at 0 — the part-2 tripwire
src/core/dst_program.ail                 39 +-   OutcomeMissing widened to file_remove ONLY
5 × attribution/profile artifacts       ~80 +-   the D4 cascade AGAIN, both profiles re-issued
6 × ExtPorts construction sites         ~96 +-   closed records, every one loud

NEW  .agent/.../NOTE-d17-the-file-write-world-class.md   524   the record
```

| Definition-of-done item | State |
|---|---|
| The class on `Ports`, state-threaded, deterministic adapter **growing** `state.files` | **met** — `file_write` + `file_remove`, `FileMutation` |
| Ordering versus `lookup_file` pinned by a fixture | **met, and the pin is not the predicted shape** — see below |
| The recording decision taken and recorded with its reasoning | **met** — and D3's stated reason was *replaced*, not inherited |
| A new `IdentityBody` constructor ⇒ all four dependents + JSON round trip | **met** — nine sites, not four; round trip over **every** variant |
| The write-then-read-back fixture, and its mutant red | **met** — 9 rows, 7 mutants, 6 red |
| The `removeFile` question answered | **met — BUILT**, on D16's own argument |
| `ExtPorts.file_write` iff it fronts the core class | **met** — both derive `returns-it`, not `unrouted` |
| Nothing in compose routed | **met** — zero new call sites tree-wide |
| Per S13/S9/S17, `make dst` cache-cold, `sync_packages` first | **met** — **fourteenth** consecutive |
| Per S22 as D16 extended it, re-issue **both** profiles | **met** — and D16's sequence reproduced exactly |
| Stop-and-report: recording needs a vocabulary-version bump | **did not fire** — three candidates measured, none moves |
| Stop-and-report: growing `files` forces a change to `file_read`/`lookup_file` | **did not fire** — both untouched |
| Stop-and-report: adapters cannot agree without test-mode branching | **did not fire** — *probed*, not assumed |

---

## The recording decision — the item's durable output, and D3's reason did not survive

The handoff asks whether "record the write, not the read" is coherent. **It is, but not for the reason
on offer.** D3 had recorded a *measurement* as the reason `recording_ports` omits the file class:

> Recorded runs read three paths per `resolve_context_limit` call against a table that every fixture
> leaves EMPTY … **Until a fixture seeds `WorldState.files`, a replay cannot lose what no run put
> there.**

**This item is what makes a run seed `WorldState.files`**, so the stated expiry condition fires and
inheriting the conclusion was not available.

**The reason that replaces it is a fact about a different type entirely:**

> **`InitialWorld` carries `synthetic_environment` and has NO `files` counterpart.**

An env read reads a value **the program supplies**; a file read reads one **the program does not**.
That is the whole difference between the two classes. And it means the obvious alternative — *record
both, to close D3's asymmetry* — **does not close it**: the gap is that a SEEDED read table cannot
round-trip at all, logged or not. Logging the reads would describe observations whose source the
artifact still cannot rebuild — two homes, one level up, in the instrument.

**The write lands on the recorded side of that same line** because it is not the world's *supply*:
`world_state_of` derives `script`/`approvals`/`tools` from the log because a replay has to be handed
them, whereas **a replayed driver performs the write again through the same adapter.** So `files` is
rebuilt by the run, `world_state_of` correctly keeps reconstituting `files: []`, and **the write is
recorded for GRADING and not for reconstitution** — a difference in kind from the other four recorded
classes, stated at `recording_ports` rather than left to be inferred.

Second, independent measurement pointing the same way: **recording reads re-baselines every recorded
corpus in the tree** (three reads × eight driver call sites, on every profile at once — WI-D4 measured
what that does to a fixed seed bank); **recording writes changes nothing**, because nothing writes yet.

**Owed and NOT taken:** `InitialWorld.files`, a `world_state_of` that reads it, and
`program_schema_version` `/1` → `/2` with the old decode path kept. A program-schema change and a
re-attestation, which the handoff scopes out.

### The version question, answered against three candidates rather than one

| Candidate | Verdict |
|---|---|
| `event_vocabulary_version` `"event-vocabulary/1"` | Versions the 34 `LedgerEvent` variants. **The wrong artifact** — nothing to do with `IdentityBody`. |
| `program_schema_version` `"execution-program/1"` | Versions the program's **shape**. A constructor adds no field; no existing bytes change meaning. |
| The persistence codec's tag vocabulary | `body_of` **refuses** an unknown kind by name — already the guarantee D8's rule demands a bump to obtain. |

**And one decoder is NOT loud, reported rather than fixed:** `ext_world.identity_body_of` falls through
to `ClockAdvanceIdentity`, **by its own stated design**. An old build reads a new `file_write` as a
clock advance. Already true of every constructor this sum has ever gained; named now because this is
the first addition since the note was written.

## `removeFile` — BUILT, on D16's own argument rather than a new one

`removeFile` changes what `fileExists` returns and compose branches on exactly that, at the same
`if not checked.ok then if fileExists(p) then removeFile(p)` arm D16 cited for the write. **Five of
compose's eighteen write-side sites are removes.** Deferring would have been adopting an argument and
refusing its conclusion.

**`mkdirAll` deferred on a DIFFERENT ground, not on budget:** directory existence is observed only
through `isDir`/`listDir`, neither of which has a core seam, so a mediated `mkdirAll` would mutate a
table nothing can read. **Two answers, two grounds** — not one budget line through both.

**Two constructors and not one**, measured against the cheap design: a single
`FileMutationIdentity(op, path)` must derive its kind from `op`, making `FileMutationIdentity("bogus")`
representable and reading as a write — exactly what design note 1 forbids.

## The mutants — and the ordering pin is not the shape the handoff predicted

Nine rows in `world_state_probe`, at the **adapter**, because nothing routes a write so no run's
behaviour can branch on one. Named as a weaker instrument than the read class's provenance pair rather
than presented as coverage.

| # | Mutation | Result |
|---|---|---|
| 1 | **`scripted_file_write` returns `next_state: state`** | **RED, 6 rows** — `present=false content=''`, *the identical observation an unrouted write produces* |
| 2 | append instead of prepend (dedupe kept) | **PASS** |
| 3 | prepend, no dedupe | RED, 2 rows |
| 4 | append, no dedupe | RED, 3 rows — `content='ALPHA'` after writing `BRAVO` |
| 5 | `file_remove` reports ok for an absent path | RED, 1 row |
| 6 | recorder logs but does not wrap the write | RED — `log=1 content=''` |
| 7 | recorder wraps but records nothing | RED — `log=0 content='DELTA'` |

**Mutant 2 passing is the finding.** The handoff calls prepend-vs-append "a one-token difference with
opposite semantics"; it is, **but only conditionally** — with `remove_path` in place the two are
observationally identical and no fixture can distinguish them, because there is no difference. The
stale-read-wins the handoff named is mutant **4**, and the dedupe is what the map row pins. The prepend
is kept as defence in depth and that is now written at the site instead of asserted as a semantic
difference it does not have on its own.

**Mutants 6 and 7 are a pair and neither is redundant** — each is green under the other's failure. A
recorder that logs and does not write produces a log that looks complete over a world that never
changed: **the two-homes failure with the homes swapped, which the census would report as covered.**

## Three guards fired that this item never pointed at — and one exposed a contradiction

All three derive their subject list from `all_interaction_kinds()` rather than writing it out. That is
the discipline `dst_interaction`'s header claims for that function, working:

| Target | What it said |
|---|---|
| `invariants` | `✗ all 9 D2 interaction classes appear — missing: file_write, file_remove` |
| `program_persistence` | `✗ the specimen omits 2 identity class(es) … their codec paths are frozen by nothing` |
| `ext_call_inventory --self-test` | D16's reachability rows, on the first addition after it landed |

**`program_persistence` holds two rows that became mutually unsatisfiable the moment `IdentityBody`
gained a constructor**, and neither is wrong: *cover every class* versus *equal what the frozen v1
bytes hold*, where the second says in its own comment that regenerating the file **"is the response
that is not available, because it destroys the evidence."** They conflicted only because one program
served both. The resolution is not a judgement about which matters more:

> **A class added after the freeze cannot be in the frozen bytes, by construction.**

`frozen_v1_interactions()` is pinned forever; `specimen_interactions()` grows;
`scenario_the_frozen_v1_specimen_still_decodes` compares against `frozen_v1_program()`. **The frozen
artifact was not regenerated** — `git status` on `scripts/dst/fixtures/` clean.

**What it costs, stated rather than buried: the two new codec paths are ROUND-TRIPPED, NOT FROZEN.**
Nothing in the tree can freeze them — there are no historical bytes containing them. **The project now
has a two-tier compatibility surface, and it will recur on every class added from here.**

## One validator rule widened, and the control that says how far

`validate_outcome` rejected the specimen: *"interaction #9 is a file_remove with a 'missing' status,
which D2 defines only for an environment read and (WI-A13) an approval whose queue is exhausted."*

**`OutcomeMissing` now admits `file_remove` and nothing else**, on WI-A13's own reading B rather than a
preference for a smaller diff. The alternatives are the two reading A already lost to: `OutcomeOk` makes
an absent remove indistinguishable from one that deleted something (the `ApprovalInput.eof` failure);
`OutcomeFault` needs a class id the catalogue does not have. **`file_write` is NOT admitted** — asserted,
not described: `execution_program_dst` mutant **12d** is a `file_write` with a missing status and must
still be rejected.

## Whether any site admitted two type-checking answers with a silent wrong one

**YES — TWO. The count goes 70 → 72 across forty-one runs.**

**Site 1 — `scripted_file_write` returning `next_state: state`.** The class's whole subject matter. It
type-checks, it is what **five of the six other deterministic adapters legitimately do**, it is what
`ambient_file_write` legitimately does one screen away, and it produces `present: false` — byte-identical
to an unrouted write. Not written wrong (built fixture-first); counted because the criterion is
"admitted two answers", not "was written wrong". A12 and D3 each found one on this same surface.

**Site 2 — WRITTEN WRONG, AND IT PASSED.** The `invariants` fixture was first extended by *inserting*
the mutators at ordinals 15/16, pushing the terminal provider to 17. Three checks in that file address
interactions **by ordinal literal**, and

```ailang
List.length(at_ord(log, 15).outcome.chunks) == 0
```

**kept printing `✓` — because `at_ord(log, 15)` was now a `file_write`, which also has no chunks.** The
row was green while reading an interaction it was not written for; it was caught only because an
unrelated row (`count_status(log, "missing") == 1`) happened to break. **A green row reading the wrong
subject is worse than a red one**, and an ordinal literal is a positional reference with no type behind
it. Fixed by appending after the provider, with the reason recorded at the fixture.

**Not counted**, for D16's reason: the nine `ExtPorts`/`Ports` construction sites are closed records, so
*"records are closed — add the field(s)"* made every missing binding loud. No second answer anywhere.

## The ABI

**TWELVE rows, up from ten** — `ExtPorts.file_write` (11th) and `ExtPorts.file_remove` (12th), both
**ADDITIONS**. Of the twelve, **nine are changes and three are additions**; D16 introduced the second
kind with one row and this item makes additions a third of the tally, so the breakdown is given rather
than left to a single number. Plus **three added types** (`ExtProcOutcome`, `ExtFileRead`,
`ExtFileMutation`) on D6's convention.

**Nothing forces the major and it was not cut**, for D6/D7/D8/D14/D16's reason unchanged: cutting it is
a release act. `ailang.toml` still declares 5.0 across six sites in four files. **C5's trap checked and
did not fire** — `git diff` over `*ailang.toml` empty; only `ailang.lock` moved, six content hashes
re-recorded by the normal build.

**The classifier-2 set is unchanged at `{env_get}`.** Both new rows front a seam that threads a
successor and both return types carry it, so the criterion does not select either — arrived at *without*
a widening, because these fields were born wide.

## Gate and sweep

`make sync_packages` (**fourteenth** consecutive), then `AILANG_RELAX_MODULES=1 make dst` **cache-cold**
— all 37 repo-local `.ailang/cache/compile` directories outside the vendored checkout removed, per S9 as
D16 extended it (the **dependents** of an edited interface, not just the edited module).

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, nothing else** — identical to D5, D10,
D11, D12, D13, D14, D15, D16; pre-existing since B2a (`prompts_test.ail` 0/6, *"Named test blocks not
yet implemented"*). **924 ✓ rows in 4 705 lines** (D16: 914 in 4 687).

**Three sweeps; the intermediate reds were all guards catching this item** — sweep 1 → `invariants` and
`program_persistence`; sweep 2 → clean; sweep 3 → clean, re-run cache-cold after the last edit.

**A fourth red was NOT a sweep red and is the one that would have been invisible:** `make anchors` and
`make attribution_table` both went green with only `driver_only` re-issued, and `driver_plus_no_ops` then
failed with *"the attribution table was corrected and this profile was not re-issued (D4)"*. **D16 named
that exact sequence one item ago and it reproduced exactly.** Anchors `911/1160/1266/2711/2821` →
`931/1185/1291/2736/2846`, verified character-identical against `git show HEAD:` at all five;
`driver_only` **15 → 16**, `driver_plus_no_ops` **2 → 3**.

**Yields did not move: closure 4 of 15, hook scope 5 of 15**, identical to D15 and D16. Expected —
nothing was routed, so nothing could clear; a yield that moved on an item adding no call site would mean
the instrument was reading the ABI's shape instead of an extension's behaviour.

## D1's stop condition — probed, not assumed

The one input where the deterministic and ambient adapters could disagree is a remove of an absent path,
so it was measured on this pin:

```
removeFileResult("<absent>")                = Err 'cannot remove file: … no such file or directory'
writeFileResult("/proc/…/x.txt", "x")       = Err 'cannot write file: … no such file or directory'
```

`scripted_file_remove` returns `ok: false` there, so the pair agrees. **The second line is why
`FileMutation.error` is a real channel rather than a field that is always `""`** — the host can and does
fail a write, and std/fs offers `writeFileResult` beside the unit-returning `writeFile`. Compose's seven
`writeFile` sites are all `let _ = writeFile(…)`; a port that also discarded it would have carried the
drop across the boundary. **WI-A1's ordering rule, applied before the routing item rather than after.**

## Recorded bindings

**Decided:** reads stay unrecorded on a *replaced* reason; `removeFile` built and `mkdirAll` deferred on
two different grounds; `FileMutation` carries `error`; **one component on the identity — the path, no
origin** (the `EnvironmentReadIdentity` shape, with the cost stated: when part 2 routes an extension's
write, "which extension wrote this path" stops being derivable, and adding the component later is a
constructor arity change reaching **nine sites**); both `ExtPorts` rows shipped because the core class
exists first; no-op `ExtPorts` bindings report `ok: false`; `OutcomeMissing` widened to `file_remove`
only; the frozen v1 specimen **not** regenerated; the `invariants` fixture appends rather than inserts.

**Discovered:** D16's reachability assertion earned itself on the first addition after it landed; the
prepend/append difference is conditional and a mutant said so; `InitialWorld` has no `files` field
(found by reading `world_state_of`, not predicted); the anchors move on **every** Route B surface item —
`ext_ports_of` sits above all five — so both profiles re-issue each time, now recorded in `anchors.sh`,
`driver_only_attribution_ref` and `no_ops_version` so a third item prices it in advance;
`program_persistence`'s two rows are mutually unsatisfiable on a new class; `OutcomeMissing` is
class-gated by an enumeration.

## Owed

**Part 2 is now blocked on two things, not three** — the write class exists. What remains is the
**directory seam** (`isDir` ×2, `listDir` ×1, plus the six deferred `mkdirAll`) and **door 3's producer**.
`absent_classes` will go red the moment a write is routed; that is deliberate, and the routing item owns
the decision it forces. `InitialWorld.files` + `execution-program/2`. The origin component, if part 2
wants it. The **eight stale `"4.0"` classifier-2 literals**, still unguarded, now four items stale.
`check_abi_version`'s subject list, four of eleven manifest-building files. Unchanged: promoting the
hook-scope verdict, the drafted `registration_effects` amendment's disposition, the full eleven-row
table, criterion 1's basis, classifier 1, the stdlib-adjacent cache's 52-file producer, the gate-table
State column, F3, the fourteen `register_with_config` rows — and the `motoko-ext-abi` major, now at
**twelve** rows.

---

*Follow-on commits by a separate session: `04b4a03` (plan-apply for D17) and `9c401e7`
(`HANDOFF-execute-d18-the-directory-seam-and-the-path-key.md`). D18 picks up the directory seam **and**
a finding this item did not make: `lookup_file`/`remove_path` are exact string equality while the
filesystem normalizes, so `tmp/x`, `./tmp/x` and `/w/tmp/x` are three world entries and one file on
disk — the two-homes shape produced by the world's KEY rather than by an unmediated effect, and already
reachable at `compose.ail:769/771`.*
