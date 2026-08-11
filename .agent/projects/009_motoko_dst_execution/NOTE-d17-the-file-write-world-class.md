# WI-D17 — the core filesystem *write* world class

Grounded against HEAD `7c473e2`. Forty-first calibration run, and **the half WI-D16 decided and did
not build.**

**`Ports` went from six fields to eight and `IdentityBody` from seven constructors to nine.** A
filesystem write class and a filesystem *remove* class, each with a deterministic, an ambient and a
recording adapter; `ExtPorts` fronts both, so both derive `returns-it` rather than `unrouted`.

**The recording decision was taken and it is not the one the handoff's framing leads with either.**
Writes are recorded and reads stay unrecorded — which is what D16 chose — but **the reason D3 gave for
leaving reads out is wrong, and the right reason is a different fact about a different type.** §3.

**`removeFile` was BUILT, not deferred**, and the argument is that deferring it would have been
adopting D16's argument and refusing its conclusion. §4.

**Nothing was routed.** Compose is still part 2.

---

## 1. The git wall-clock window

| | |
|---|---|
| HEAD at session start | `7c473e2` — `2026-08-07T20:29:30+00:00` |
| first command | `2026-08-08T05:39Z` |
| work window | **~1h05m** |

**Against D16's ~1h39m for the same shape this was faster, and as at D16 the reason is not skill.**
Three things were bought and spent rather than re-derived: the `let w0` closure shape (S3, discovered
by B2b, prescribed by D16) was written correctly before `derive.py` ran; the anchor re-baseline was
performed as a known cost rather than diagnosed from a failing target; and the cache-cold sweep was
run cache-cold from the first attempt because D16 documented the dependents trap at the exact line
that causes it.

**Where the time actually went:** roughly a third to the three guards in §7b — none of which is a
target this item touched, and one of which (`program_persistence`) required resolving a contradiction
between two rows rather than editing a fixture.

## 2. What is on `Ports` now, and the property that made it hard

```ailang
file_write:  (WorldState, string, string) -> FileMutation ! {FS},
file_remove: (WorldState, string)         -> FileMutation ! {FS},
```

`FileMutation` is `{ ok: bool, error: string, next_state: WorldState }`, shared by both seams because
their answers have identical shape.

**The handoff's central claim held exactly.** Every adapter in `ports.ail` before this item consumed a
cursor, advanced a scalar, or returned `state` unchanged; the only append site was
`record_interaction`, which grows `log`. `scripted_file_write` is the first adapter that adds to a
table the driver later reads, so `WorldState.files` is now **both seeded input and produced output,
indistinguishable once written**.

**And `ambient_file_write` legitimately returns `next_state: state`** — a live run's reads go to the
real filesystem through `ambient_file` and never consult `state.files`, so growing the table there
would be a second home for a fact the live world already owns. **The two adapters therefore differ in
a way no type can see, one screen apart.** That is written at both sites rather than at one.

## 3. THE RECORDING DECISION — the item's durable output

**Writes recorded. Reads not. And D3's stated reason for leaving reads out does not survive contact
with this item, so it was replaced rather than inherited.**

### 3.1 What D3 actually recorded, and why it had to be re-opened

`stub_step.ail` carried this, verbatim, as the reason `recording_ports` omits the file class:

> Recorded runs read three paths per `resolve_context_limit` call against a table that every fixture
> in this tree leaves EMPTY … Logging them would change nothing that any replay observes today.
> **Until a fixture seeds `WorldState.files`, a replay cannot lose what no run put there.**

**This item is what makes a run seed `WorldState.files`.** The measurement named its own expiry
condition and this item creates it, so inheriting the conclusion was not available.

### 3.2 The reason that replaces it, and it is a fact about `InitialWorld`

> **`InitialWorld` carries `synthetic_environment` and has NO `files` counterpart.**

So an env read is a read of a value **the program supplies**, and a file read is a read of a value
**the program does not**. That is the whole difference between the two classes, and it is why the log
records one and not the other. D3's asymmetry was never "reads are unrecorded" — **it is that a
SEEDED read table cannot survive a round trip at all**, and that is true whether or not the reads are
logged, because there is nowhere in the program to put the table.

**Which means "record both, to close D3's asymmetry" — the obvious alternative — does not close it.**
It would produce a log describing observations whose source the artifact still cannot rebuild: the
two-homes shape, one level up, in the instrument.

### 3.3 Why the WRITE lands on the recorded side of that same line

`world_state_of` derives `script`, `approvals` and `tools` from the log because those are the world's
**supply** — values the driver cannot compute and a replay has to be handed. **A write is not supply.
It is the driver's own act, and a replayed driver performs it again through the same adapter.** So
`files` is rebuilt by the run rather than restored from the artifact, and `world_state_of` correctly
continues to reconstitute `files: []`.

**The write is therefore recorded for GRADING and not for reconstitution, which is a difference in
kind from the other four recorded classes.** Stated at `recording_ports` rather than left to be
inferred from the adapter list.

### 3.4 The second reason, which is a measurement and points the same way

**Recording reads re-baselines every recorded corpus in the tree; recording writes changes nothing.**
Three reads per `resolve_context_limit` call at eight driver call sites is a log that grows on every
profile at once, and WI-D4 already measured what a changed driver read count does to a fixed seed
bank. Nothing in the tree writes a file, so the write class's log growth today is **zero**.

### 3.5 What is owed, drafted and NOT taken

`InitialWorld.files`, a `world_state_of` that reads it, and `program_schema_version`
`"execution-program/1"` → `"/2"` with the old decode path kept. **That is a program-schema change and
a re-attestation, which the handoff scopes out of this item.** Named at the site.

### 3.6 The version question, answered against three candidates rather than one

The handoff asks whether `identity_kind`'s new strings move a schema version, and points at
`event_vocabulary_version`. **It does not move, and neither do the other two.** Measured:

| Candidate | Verdict |
|---|---|
| `event_vocabulary_version` `"event-vocabulary/1"` | Versions the **34 `LedgerEvent` variants** and their wire projection. Nothing to do with `IdentityBody`. Naming it would version the wrong artifact. |
| `program_schema_version` `"execution-program/1"` | Versions the persisted program's **shape**. A new constructor adds no field and removes none; no existing program's bytes change meaning. |
| The persistence codec's tag vocabulary | `dst_persistence.body_of` **refuses** an unknown kind (`UnknownInteractionKind`), so an old build handed a new artifact rejects it loudly. That is what D8's rule demands a bump in order to *guarantee* — already guaranteed structurally. |

**AND ONE DECODER IS NOT LOUD, WHICH IS REPORTED RATHER THAN FIXED.**
`ext_world.identity_body_of` falls through to `ClockAdvanceIdentity` for an unrecognised tag, **by its
own stated design** ("a total decoder is the right shape"). An old build reading a new `file_write`
interaction over that transport reads a clock advance. **That was already true for every constructor
this sum has ever gained**; it is named now because this is the first addition since the note was
written. Closing it is a change to a total decoder's contract, not to the kind list.

## 4. `removeFile`: BUILT, and why deferring it was not defensible

**D16's argument for mediating the write is `removeFile`'s argument verbatim.** `removeFile` changes
what `fileExists` returns and compose branches on exactly that — the same
`if not checked.ok then if fileExists(p) then removeFile(p)` arm D16 cited. **Five of compose's
eighteen write-side sites are removes**, so shipping the write alone would have left the two-homes
defect standing on all five and part 2 would have hit it.

Deferring it would have meant adopting an argument and refusing its conclusion.

**`mkdirAll` IS deferred, and on a different ground rather than on budget.** Directory existence is
observed only through `isDir` and `listDir`, neither of which has a core seam — `Ports` has no
directory class at all — so a mediated `mkdirAll` would mutate a table nothing can read. It belongs
with the directory seam D16 §6 priced, not here. **That leaves 6 of compose's 18 write-side sites
un-routable by this class, and the reason is the one D16 already recorded.**

**Two constructors and not one, measured against the cheap design.** A single
`FileMutationIdentity(op, path)` has to derive its kind from `op`, which makes
`FileMutationIdentity("bogus", p)` representable and reading as a write — the thing design note 1
("a kind that disagrees with its own payload cannot be written down") exists to forbid.
`test_identity_kind_is_injective_across_the_nine_classes` is what says so.

## 5. Ordering versus `lookup_file` — pinned, and the pin is not the shape the handoff predicted

`scripted_file_write` is **`remove_path` first, then prepend**. The handoff called prepend-vs-append
"a one-token difference with opposite semantics". **It is — but only conditionally, and the mutants
say which condition.**

| Mutant | Result |
|---|---|
| append **with** the dedupe | **PASS.** With one entry per path, prepend and append are observationally identical. There is no fixture that can distinguish them, because there is no difference. |
| prepend **without** the dedupe | RED on the map row only. Reads stay correct — first match wins. |
| append **without** the dedupe | RED on the ordering row *and* the map row: `content='ALPHA'` after writing `BRAVO`. **This is the stale-read-wins the handoff named.** |

So the honest statement is: **the ordering matters only if the dedupe is absent, and the dedupe is
what the map row pins.** The prepend is kept anyway as defence in depth — it is what makes the read
correct if the dedupe is ever dropped — and that is now written at the site instead of asserted as a
semantic difference it does not have on its own.

## 6. The mutants, and the one the item is shaped around

Nine assertion rows in `world_state_probe`, exercised at the adapter because **nothing routes a write,
so there is no run whose behaviour can branch on one.** That is a weaker instrument than the file
read's provenance pair and it is named as such rather than presented as coverage.

| # | Mutation | Result |
|---|---|---|
| 1 | **`scripted_file_write` returns `next_state: state`** | **RED, 6 rows.** The failure message is the point: `present=false content=''` — *the identical observation an unrouted write produces.* |
| 2 | append instead of prepend (dedupe kept) | PASS — §5 |
| 3 | prepend, no dedupe | RED, 2 rows |
| 4 | append, no dedupe | RED, 3 rows |
| 5 | `scripted_file_remove` reports `ok` for an absent path | RED, 1 row |
| 6 | `recording_file_write` logs but does not wrap the write | RED — `log=1 content=''` |
| 7 | `recording_file_write` wraps but records nothing | RED — `log=0 content='DELTA'` |

**Mutants 6 and 7 are a pair and neither is redundant.** They are the two halves of the recorder's
job, and each is green under the other's failure. A recorder that logs and does not write produces a
log that looks complete over a world that never changed — **the two-homes failure with the homes
swapped, and the census would report it as covered.**

Per S24, reachability is asserted separately from verdict: row 1 has a control proving the path is
**absent before** the write, because "present after a write" is satisfied by a world that was seeded
and never written.

## 7. The census fail-open, closed — and it is a tripwire for part 2

The handoff is right that **nothing asserted a census count was non-zero.** It is also true that
nothing asserted one was zero, for these classes. `census` iterates `all_interaction_kinds()`, so
`file_write=0` would have printed forever and read exactly like a class being counted.

**`dst_discovery.absent_classes` already had the mechanism** — it pins `expect_extension_effect` and
`runtime_random_draw` at zero in both directions — and the two new classes were added to it.

**So the moment part 2 routes a compose write through `Ports.file_write` on a graded profile,
`check_discovery` goes red with `file_write over-recorded: expected 0, got n`**, and the routing item
must either give the class a witness or move it out of the list, in both cases having said which.

Its negative control is separate and explicit: the two new rows fire, **and** the balanced log
containing neither still produces zero findings. `test_an_unrouted_filesystem_mutation_is_over_recorded`
is its own row rather than folded into the randomness one, because the randomness class is unreachable
for a *structural* reason and these two are unreachable only *for now*.

## 7b. THREE GUARDS FIRED WITHOUT ANYONE POINTING AT THEM, AND ONE OF THEM EXPOSED A CONTRADICTION

**Adding a constructor to `IdentityBody` reddened three targets that no part of this item touched**,
each because it derives its subject list from `all_interaction_kinds()` rather than writing it out.
That is the discipline `dst_interaction`'s header claims for that function, working:

| Target | What it said |
|---|---|
| `invariants` | `✗ all 9 D2 interaction classes appear — missing: file_write, file_remove` |
| `program_persistence` | `✗ the specimen omits 2 identity class(es): file_write, file_remove — their codec paths are frozen by nothing` |
| `ext_call_inventory --self-test` | D16's reachability rows — §10.1 |

### The contradiction, which is the item's second durable finding

**`program_persistence` holds two rows that became mutually unsatisfiable the moment `IdentityBody`
gained a constructor**, and neither is wrong:

- `scenario_specimen_covers_every_shape` — every identity class must be in the specimen, "or their
  codec paths are frozen by nothing", with the class list derived from `all_interaction_kinds()`.
- `scenario_the_frozen_v1_specimen_still_decodes` — the specimen must equal what
  `scripts/dst/fixtures/execution-program-v1.artifact` holds, and its own comment says regenerating
  that file **"is the response that is not available, because it destroys the evidence."**

They conflicted only because **one program was serving both.** The resolution is not a judgement about
which row matters more:

> **A class added after the freeze cannot be in the frozen bytes, by construction.**

So `frozen_v1_interactions()` is pinned forever at what v1 actually contained and
`scenario_the_frozen_v1_specimen_still_decodes` compares against `frozen_v1_program()`;
`specimen_interactions()` is `frozen_v1_interactions() ++ post_v1_interactions()` and everything else
— the round trip, the digest, the diffability floor, the store, the secret scanner — uses it.

**WHAT THAT COSTS, STATED RATHER THAN BURIED: the two new classes' codec paths are ROUND-TRIPPED, NOT
FROZEN.** Nothing in the tree can freeze them, because there are no historical bytes containing them.
The next encoding change is pinned for the original seven and unpinned for these two, and the only fix
is a future freeze at a future schema version. **That is the first time this project has had a
two-tier compatibility surface, and it will recur on every class added from here.**

The frozen bytes were not regenerated. `git status` on `scripts/dst/fixtures/` is clean.

## 7c. One validator rule was WIDENED, and the negative control that says how far

`dst_program.validate_outcome` rejected the specimen:

```
[program-outcome-status-disagrees-with-fault] interaction #9 is a file_remove with a 'missing'
status, which D2 defines only for an environment read and (WI-A13) an approval whose queue is
exhausted
```

**`OutcomeMissing` is now admitted for `file_remove` and for nothing else**, on WI-A13's own reading B
("missing means the world had no value to serve") rather than on a preference for a smaller diff. The
two alternatives are the two that reading A already lost to:

- **`OutcomeOk`** — indistinguishable from a remove that actually deleted something. `FileMutation.ok`
  exists to keep those apart at the seam (§9), so collapsing them in the log makes a class of run
  unreplayable in precisely the way `ApprovalInput.eof` was created to prevent.
- **`OutcomeFault`** — needs a `fault_class_id`, and A7's catalogue declares no filesystem class.
  Either manufacture a class the catalogue does not contain, or leave a fault uncountable by D11's
  counter — which the arm directly above rejects.

**`file_write` is NOT admitted**, because a write has no "the world had nothing to give" state. That
half is asserted rather than described: `execution_program_dst` mutant **12d** is a `file_write` with a
missing status and it must still be rejected. Without it, the widening reads identically to opening the
rule to both mutators, and the surviving fixture — which now legitimately carries a
`file_remove`/missing — would be the only evidence either way.

## 8. What the recorded interaction carries, and what it deliberately does not

**The content does not enter the log; its length does.** `file_write path=… bytes=N`, payload empty.
Three reasons, in decreasing weight:

1. **Secrets.** `dst_secrets.scan_interaction` scans payload and projection, but a file body is the
   single most likely place in this surface for a credential to appear, and the right answer to "will
   the scanner catch it" is to not put it there. A length cannot carry one. **This is also why the
   path gets `scan_text` and NOT the `name_axis` treatment an env key gets** — a key *name* is itself
   the evidence; a path name is not.
2. **D2 asks for a BOUNDED projection**, and the precedent is one class over: `recording_tool` projects
   call id, tool, workdir and timeout and does **not** project the tool's arguments.
3. Replay does not need it — §3.3.

**What the length buys over recording nothing**: a replay writing different content to the same path
differs in the projection, so `ProjectionDiffers` fires. Recording only the path would make that
replay indistinguishable from a faithful one.

**A remove of an absent path is recorded with `OutcomeMissing`, not `OutcomeFault`** — `recording_env`'s
distinction, not `recording_tool`'s. Compose issues exactly that call under a `fileExists` guard, so
it is a normal answer to a normal request; classifying it as a fault would manufacture a class the
catalogue does not contain.

**One declared gap, in `recording_approval`'s sense rather than as a solved problem:** a *rejected*
write records `OutcomeFault` with no `fault_class_id`, because the fault catalogue declares no
filesystem class. It cannot arise deterministically (`ok` is unconditionally true there), so the gap
is reachable only on the live path, which no gate in this tree grades.

## 9. D1's stop condition — checked, not assumed

The handoff's third stop condition is that the deterministic and ambient adapters must agree without
production code branching on test mode. **The one input where they could disagree is a remove of an
absent path, so it was probed on this pin rather than reasoned about:**

```
removeFileResult("<a path that does not exist>")
  = Err 'cannot remove file: remove …: no such file or directory'
writeFileResult("/proc/definitely/not/writable/x.txt", "x")
  = Err 'cannot write file: open …: no such file or directory'
```

`scripted_file_remove` returns `ok: false` for an absent path, so the pair agrees. **The second line
is why `FileMutation.error` is a real channel and not a field that is always `""`:** the host can and
does fail a write, and std/fs offers `writeFileResult` beside the unit-returning `writeFile`. Compose's
seven `writeFile` sites are all `let _ = writeFile(…)` — a discarded result on the live path — so a
port that also discarded it would have carried the drop across the boundary instead of closing it.
**WI-A1's ordering rule, applied before the routing item rather than after it.**

## 10. Recorded bindings: decided versus discovered

**Discovered — a tool, a compiler or a measurement forced it:**

1. **D16's reachability assertion earned itself on the first addition after it landed.** Adding the two
   fields produced, before the fixture was edited:
   ```
   FAIL REACHABILITY: ExtPorts.file_remove derives 'returns-it' but is not pinned in expected.json.
   FAIL REACHABILITY: ExtPorts.file_write  derives 'returns-it' but is not pinned in expected.json.
   ```
   **Two named failures where the pre-D16 suite would have printed five green membership rows and said
   nothing about the two new fields.** Recorded in the fixture's own header, because that is where the
   next person reads it.
2. **The prepend/append difference is conditional, and a mutant said so** — §5. The handoff's framing
   would have led to a fixture that pinned a distinction that does not exist.
3. **`InitialWorld` has no `files` field**, which is what makes §3's argument the argument it is. It
   was found by reading `world_state_of`, not predicted.
4. **The anchors move on every Route B surface item, and that is now written down.** `ext_ports_of`
   sits above all five `session.ail` anchors, so *every* seam added to `ExtPorts` re-baselines them and
   re-issues both profiles. Twice in two items is a pattern; it is recorded in `anchors.sh`, in
   `driver_only_attribution_ref` and in `no_ops_version` so a third item prices it in advance.
   **D16's extension of S22 held exactly**: `make anchors` and `make attribution_table` both went green
   with only `driver_only` re-issued, and `driver_plus_no_ops` then failed with
   *"the attribution table was corrected and this profile was not re-issued (D4)"*. Necessary, not
   sufficient, for the second item running.
5. **`program_persistence`'s two rows are mutually unsatisfiable on a new class** — §7b. Found by the
   guards, not predicted; the resolution is structural rather than a choice between them.
6. **`OutcomeMissing` is class-gated by an enumeration in `validate_outcome`** — §7c. The gate is right
   and it had to be widened, which is a rule change this item did not plan for.

**Decided — a judgement that could have gone the other way:**

1. **Reads stay unrecorded, on a replaced reason** — §3. The alternative, recording both, is what
   "close D3's asymmetry" leads to and it is defeated by the `InitialWorld` measurement.
2. **`removeFile` built, `mkdirAll` deferred** — §4. Two different answers on two different grounds,
   rather than one budget line drawn through both.
3. **`FileMutation` carries `error`.** A copy of `FileRead`'s discipline would have carried only `ok`.
   §9 is the reason it carries more.
4. **One component on the identity, the path, and no origin.** The `EnvironmentReadIdentity` shape
   rather than `ToolIdentity`'s. **The cost is stated at the site rather than discovered at part 2:**
   when compose's writes are routed, the producer becomes an *extension* and "which extension wrote
   this path" stops being derivable. Adding the component later is a constructor arity change reaching
   **nine sites**. It is not taken now because a component blank at every construction site in the tree
   is a field no fixture can distinguish from an absent one.
5. **`ExtPorts` gained both rows.** D16's ordering rule is what permits it: the core class exists, so
   both derive `returns-it`. A field fronting nothing derives `unrouted`, which is `derive.py`'s
   fail-open answer and looks cleaner than it is.
6. **No-op `ExtPorts` bindings report `ok: false`.** The same judgement `noop_file_read` makes with
   `present: false` — a no-op that claimed success would state something about the world that is not
   true.
7. **`OutcomeMissing` widened to `file_remove` and to nothing else** — §7c. The alternative readings
   are the two WI-A13's reading A already lost to, and mutant 12d is what says "and nothing else".
8. **The frozen v1 specimen was NOT regenerated** — §7b. The row's own comment forbids it; the split
   is what makes both rows satisfiable.
9. **The `invariants` fixture APPENDS rather than inserts** — §11 site 2. Not a style choice: three
   assertions in that file address interactions by ordinal literal.

## 11. Whether any site admitted two type-checking answers with a silent wrong one

**Yes — TWO. 72 across forty-one runs.**

**SITE 1 — `scripted_file_write` returning `next_state: state`.** The class's whole subject matter
rather than an incidental slip. It type-checks, it is what **five of the six other deterministic
adapters in the same file legitimately do**, it is what `ambient_file_write` legitimately does one
screen away, and it produces `present: false` on a later read — **byte-identical to the observation an
unrouted write produces.** It was not written wrong: the class was built fixture-first and mutant 1
confirms the fixture sees it. Counted because the criterion is "admitted two type-checking answers with
a silent wrong one", not "was written wrong". A12 and D3 each found one on this same surface.

**SITE 2 — and this one WAS written wrong, and it passed.** The `invariants` fixture was first extended
by inserting the two mutators at ordinals 15 and 16, pushing the terminal provider from 15 to 17. Three
checks in `scenario_fixture_carries_every_protected_shape` name an interaction **by ordinal**, and one
of them is:

```ailang
report("chunks appear on one provider interaction and not the other",
       total_chunks(log) == 8 && List.length(at_ord(log, 15).outcome.chunks) == 0, …)
```

**That row went on printing `✓` — because `at_ord(log, 15)` was now a `file_write`, which also has no
chunks.** The assertion was green while reading an interaction it was not written for, and nothing in
the file said so; the insertion was only caught because a *different* row (`count_status(log,
"missing") == 1`) happened to break. **A green row reading the wrong subject is worse than a red one**,
and an ordinal literal is a positional reference with no type behind it at all.

Fixed by appending after the provider instead of inserting before it, so every ordinal literal in the
file still points at what it was written for, with the reason recorded at the fixture.

**The near miss that is NOT counted**, for D16's reason: the eight `ExtPorts` construction sites are
closed records, so AILANG's *"records are closed — add the field(s)"* made every missing binding loud.
No second answer was available at any of them. Nine construction sites this time, all silent-proof.

## 12. The ABI changed-row count

**TWELVE rows now, up from ten, and this item added two.**

| | |
|---|---|
| B1, B2a, B2b, C5 | 4 |
| D6 (`on_budget_plan`) | 5 |
| D7 (`on_response_intercept`, `on_solver_candidate`) | 7 |
| D8 (`ExtPorts.ai_step`, `ExtensionHooks.on_pre_step`) | 8 |
| D16 (`ExtPorts.proc_exec` changed, `ExtPorts.file_read` added) | 10 |
| **D17 — `ExtPorts.file_write` ADDED** | **11** |
| **D17 — `ExtPorts.file_remove` ADDED** | **12** |

Plus **three added types** — `ExtProcOutcome`, `ExtFileRead` (D16) and `ExtFileMutation` (D17) — on D6's
convention of counting added types separately.

Of the twelve, **nine are changes to existing fields and three are additions** (`file_read` at D16,
`file_write` and `file_remove` here). D16 introduced the second kind with one row; this item makes
additions a third of the tally, so the breakdown is given rather than left to be guessed from a single
number.

**Nothing forces the major and this item did not cut it**, for D6's, D7's, D8's, D14's and D16's reason
unchanged: **cutting it is a release act.** `packages/motoko-ext-abi/ailang.toml` still declares 5.0 and
`check_fixtures.check_abi_version` re-derives that against six manifest sites across four files.

**C5's trap was checked and did not fire:** `git diff` over `*ailang.toml` is empty. `ailang.lock`
moved — six content hashes re-recorded by the normal build, exactly as D8 and D16 described — and no
version did.

## 13. The sweep

`make sync_packages` first (**fourteenth consecutive item**), then `AILANG_RELAX_MODULES=1 make dst`
cache-cold — every repo-local `.ailang/cache/compile` outside the vendored `ailang/` checkout removed
(37 directories), which S9-as-D16-extended requires: the sweep must clear the **dependents** of any
edited interface, not just the edited module.

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, and nothing else** — identical to the
inherited baseline at D14, D15 and D16, and unrelated to this item (`prompts_test.ail` 0/6 on
*"Named test blocks not yet implemented"*).

**Two sweeps, and the intermediate one is the interesting part** — every red was a guard catching this
item rather than a flake, and none of the three was a target this item touched:

| Sweep | New red | What it was |
|---|---|---|
| 1 | `invariants` | the S7 fixture must carry all 9 classes (§7b) |
| 1 | `program_persistence` | the specimen must carry all 9 — and then the frozen-bytes contradiction, and then `validate_outcome`'s `OutcomeMissing` gate (§7b, §7c) |
| 2 | — | inherited two only |
| 3 | — | inherited two only, re-run cache-cold after the last edit |

**A THIRD RED WAS NOT A SWEEP RED AND IS WORTH SEPARATING**, because it is the one that would have
been invisible: `make anchors` and `make attribution_table` both went green with only `driver_only`
re-issued, and `driver_plus_no_ops` then failed with *"the attribution table was corrected and this
profile was not re-issued (D4)"*. **D16 named that exact sequence one item ago and it reproduced
exactly.**

**The yields did not move, and that is the expected answer rather than a disappointment**: classifier 3
closure **4 of 15**, hook scope **5 of 15**, both identical to D15 and D16. **Nothing was routed, so
nothing could clear.** A yield that moved on an item that added no call site would mean the instrument
was reading the ABI's shape instead of an extension's behaviour.

Selftest evidence, read as membership rather than as an exit code (B4):

```
  ok  membership file_write   returns-it  seam=Ports.file_write
  ok  membership file_remove  returns-it  seam=Ports.file_remove
  ok  membership env_get      member      seam=Ports.env_get
  ok  reachability      7 ExtPorts field(s) derived, 7 pinned, sets identical
CLASSIFIER-2 SET (1): env_get
```

**The classifier-2 set is unchanged at `{env_get}`.** Both new rows front a core seam that threads a
successor and both return types carry it, so the criterion does not select either — the same reason it
stopped selecting `proc_exec` at D16, arrived at without a widening because these fields were born
wide.

## 14. What this item did NOT do

- **Routed nothing.** Zero call sites added. `file_write` and `file_remove` have no callers on either
  the core or the extension surface — the same state D16 left `file_read` and the widened `proc_exec`
  in, and D3 left `clock_now` in. Reported rather than presented as coverage.
- **Did not add a directory seam.** `mkdirAll`, `isDir`, `listDir` — §4 and D16 §6.
- **Did not touch `InitialWorld` or the program schema** — §3.5, drafted and stopped as the handoff
  directs.
- **Did not fix the eight stale classifier-2 literals.** Still `["ai_step", "env_get", "proc_exec"]` at
  seven test sites plus `src/core/dst_profile.ail:2074`, still unguarded, now four items stale.
- Did not promote the hook-scope verdict, remove unused imports, touch door 3's producer, or cut the
  release.

## 15. What the next item should know

1. **Part 2 is now blocked on two things, not three.** The write class exists. What remains is the
   **directory seam** (`isDir` ×2, `listDir` ×1 in compose, plus `mkdirAll` ×6 which needs it) and
   **door 3's producer**.
2. **`absent_classes` will go red the moment a write is routed** — §7. That is deliberate and the
   routing item owns the decision it forces.
3. **Every Route B surface item re-baselines five anchors and re-issues two profiles.** §10.4. Price it
   in the estimate rather than discovering it in the sweep.
4. **The origin component on `FileWriteIdentity`/`FileRemoveIdentity` is the one thing part 2 may wish
   this item had done** — §10.4. Nine sites if it is added later.
