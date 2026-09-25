# WI-D18 — the directory seam, and the world's path key

Grounded against HEAD `cfedfd4`. Forty-second calibration run, and **the last of part 2's build
blockers.**

**`Ports` went from eight fields to eleven and `IdentityBody` from nine constructors to ten.** A
three-valued `path_stat`, a `dir_list`, and a `dir_make` — with the two reads unrecorded and the create
recorded, on WI-D17 §3's line rather than a new one.

**THE REPRESENTATION DECISION IS NEITHER OF THE TWO THE HANDOFF OFFERED.** `WorldState.files` is now
**one kinded table** — `[{ path, node }]` with `node = FsFile(content) | FsDir` — not prefix-derivation
and not a second `dirs` table. **An empty directory is distinguishable from an absent one**, and that
sentence is the item's whole point. §2.

**`mkdirAll` was MEDIATED, not declined.** WI-D17's ground for deferring it ("a mediated `mkdirAll`
would mutate a table nothing can read") expired the moment this item built the table's reader, exactly
the way D3's recording reason expired at D17. §4.

**THE PATH KEY IS RAW STRINGS AND THE WORLD DOES NOT NORMALISE**, written at
`WorldState.files` rather than in this report. §5. And the two decisions turn out to
**interact**, which is the finding neither was expected to produce: representing the empty directory is
what makes the path-key defect *observable* instead of silent. §5.3.

**Nothing was routed.** Compose is still part 2, and after this item part 2 is unblocked except for
door 3.

---

## 1. The git wall-clock window

| | |
|---|---|
| HEAD at session start | `cfedfd4` — `2026-08-08T07:30:26+00:00` |
| first command | `2026-08-08T07:34Z` |
| commit | `2026-08-08T08:36:47Z` |
| work window | **~1h03m** |

**Level with D17's ~1h05m, for an item with roughly twice D17's surface** — three seams with three
different return types against two seams sharing one, plus a change to the element type of an existing
world table that reached a JSON codec, its round-trip fixture and four seeding fixtures, plus the
repair of a live adapter disagreement that predated the item (§3.2).

**The flat number is the measurement, and the thing it measures is the cascade being priced rather
than discovered.** D17's §10.4 prediction — *every Route B surface item re-baselines five anchors and
re-issues both profiles* — was executed as a known sequence and **cost about five minutes**, including
the `driver_plus_no_ops` rejection that D17 warned would come after `make anchors` went green. Two
sweeps, not three; the `let w0` closure shape and the S18 import-widening discipline were applied
before the tools were run rather than after.

**Where the time actually went:** roughly a third to the `files` element-type change and its
fourteen downstream construction sites, and about fifteen minutes to a self-inflicted loss — §10.

## 2. THE REPRESENTATION DECISION — the item's durable output

The handoff put two designs on the table. **A third beats both, and the reason it wins is that it
removes a failure mode rather than trading one for another.**

| Design | Empty directory | Can the world contradict itself? |
|---|---|---|
| **1. Prefix-derived** — `is_dir(p)` iff something is under `p/` | **Unrepresentable.** Reads identically to absent. | No |
| **2. A second `dirs` table beside `files`** | Representable | **Yes** — nothing stops `"a/b"` appearing in both |
| **3. ONE KINDED TABLE** — what was built | **Representable** | **No, by construction** |

### 2.1 Why (1) loses, and it is this project's own counted shape

Under (1) an empty directory has no evidence, so it reads as absent. `list_dir_impl`
(`author_tools.ail:189-190`) turns that difference into **two different tool results** —
`entries: []` for an empty directory against a `not_found` error for an absent one — and a session can
branch on it. That is **absent reading identically to unchanged**, at C1, D6, D12, D13, D16, D17 and
here, appearing **in the world model itself** rather than in an adapter.

**The handoff's observability measurement is correct and is not sufficient.** All six `mkdirAll` sites
are immediately followed by a `writeFile` with no intervening read, so no compose session *today* can
observe a created-but-empty directory. Per S25 that claim is **conditional on compose's current text**,
and the handoff says so. What it does not say — because it could not have known until the path key was
settled — is that **the condition is already false in the world**, §5.3.

### 2.2 Why (2) loses, and it is the handoff's own third stop condition

A `dirs: [string]` beside `files` makes `"a/b"` representable in both, and then `path_stat` has to
pick. That is `ADR:340-341`'s "exactly one home, visibly threaded" broken **inside the world** — the
shape WI-D16 and WI-D17 each argued *from*. The handoff instructs: *"If the representation forces
`WorldState` to hold two filesystem tables that can disagree, say so before building it."* It does, so
it was not built.

### 2.3 Why (3) is not a compromise between them

One entry per path (the map invariant `remove_path` already enforced) and an entry is a file **or** a
directory. So **"this path is a file AND a directory" is not representable**, rather than representable
and forbidden by a rule someone has to remember. That is design note 1's rule — *a kind that disagrees
with its own payload cannot be written down* — applied to the world's table instead of to an identity.

**The sum was chosen over a `kind` field beside `content` for that reason and not for taste:**
`{ path, kind: "dir", content: "hello" }` is a directory carrying a file body, and something would then
have to forbid it. The content lives inside the constructor that has one.

**IMPLICIT PARENTS ARE STILL DERIVED**, and that is not residue of the losing design. A host cannot
hold `a/b/c.txt` without `a/b` being a directory, so `world_path_kind` is *an explicit `FsDir` entry
**OR** any entry beneath*. Both halves are load-bearing and **mutants 3 and 4 are what say so** — §7.

### 2.4 The answer the handoff asked for, stated plainly

> **An empty directory IS distinguishable from an absent one.** `dir_list` returns
> `present: true, entries: []` for the first and `present: false, entries: []` for the second.

`assert_directory_class` row 3 is the assertion, and **mutant 2 — deriving `present` from
`List.length(entries) > 0` — is what proves the row is doing work.** That mutant type-checks and passes
every other row in the function.

## 3. The directory-vs-file existence gap: closed, and it was LIVE

### 3.1 A third class, not a widening of `FileRead`

`FileRead.present` has two values; `normalize_type` needs three. **`FileRead` was not touched** — D17's
stop condition, unchanged — and the reason is not only obedience: D3's class has a live consumer in
`context_usage` and eight construction sites, and *"does this path hold bytes I can read"* is a
genuinely different question from *"what kind of thing is at this path"*. Two narrow classes, on WI-D3's
own "narrow by construction" ground.

`PathKind`'s three labels are deliberately the three strings `normalize_type` already returns
(`"dir"`/`"file"`/`"missing"`), so part 2 replaces that function's body with a call and writes no
mapping.

### 3.2 AND THE ADAPTER PAIR ALREADY DISAGREED, BEFORE THIS ITEM

The handoff says to look at the adapter pair first. **It was already broken.**

`ambient_file` guarded on `fileExists(path)`, which is **true for a directory**, and then called
`readFile` on it. `scripted_file` had no directories to find and reported absent. **Two adapters, one
screen apart, giving two different answers to the same question about the same input** — precisely
D1's stop condition, live at HEAD rather than introduced here.

The guard is now `isFile`. **Nothing in the tree changes behaviour** — every caller passes a path it
believes is a file — and what changes is that a caller who is wrong now gets `present: false` instead of
whatever `readFile` does to a directory. Repaired rather than reported, because the repair is one token
and the class that answers the real question now exists.

### 3.3 The disagreement this item could have introduced and did not

**Directory listing ORDER.** The host returns entries in its own order; the deterministic world returns
them in write order, which `scripted_file_write`'s prepend makes *reverse-chronological*. Leaving both
alone gives a pair that agrees on *what* is in a directory and disagrees on the string compose actually
renders (`show(entries)`).

**Both adapters sort.** No call site in this tree depends on host order, so sorting is not a semantic
change; it is the cheapest way to make the two answers *equal* rather than merely equivalent. The
deterministic side also dedupes, because two files in one subdirectory both yield that subdirectory's
name.

## 4. `mkdirAll`: MEDIATED, and the reason for deferring it expired

WI-D17 deferred it on a stated ground: *"directory existence is observed only through `isDir` and
`listDir`, neither of which has a core seam, so a mediated `mkdirAll` would mutate a table nothing can
read."* **`path_stat` and `dir_list` are that seam.** The ground named its own expiry condition and
this item creates it — the same shape as D3's recording reason at D17, one item earlier.

What remained was the observability measurement, and it does not carry the decision, for two reasons:

1. **It is conditional on compose's current text** and is falsified by any future site that creates a
   directory and lists it before writing. Mediating costs one adapter; the alternative is a guard that
   has to keep being true.
2. **It is already false in the world.** §5.3.

Leaving it ambient would also put one fact in two homes on all six sites: the directory on the host, the
file written into it in the world.

**Only the LEAF is recorded.** `world_path_kind` derives a directory from anything beneath it, so
materialising ancestors would put the same fact in an explicit entry *and* a derivation. **Idempotent**
over an existing directory and **refused** over an existing file, both of which the host does — and the
second is the one input where a bare table insertion would have invented a state the live world cannot
reach.

**So there is no guard, because there is no conditional claim left to guard.** That is the difference
between the two answers the handoff offered: declining buys a measurement that must keep being true;
mediating buys an adapter that cannot stop being true.

## 5. THE PATH KEY — decided, written at the seam, and it is live

### 5.1 The decision

> **The world keys on RAW STRINGS. It does not normalise. The caller supplies one spelling per path.**

Written at `WorldState.files`, not here.

### 5.2 Why not normalise, measured rather than dismissed

Normalising would fix `./tmp/x` and `tmp//x` — those are **lexical** and need no cwd — and would **not**
fix `/w/tmp/x` against `tmp/x`, which is the pair that actually occurs. Relating an absolute path to a
relative one requires a working directory; `WorldState` has none, and giving it one is a world-shape
change that reaches replay (the handoff's second stop condition, respected).

**A key that normalises the harmless half and leaves the harmful half is worse than one that normalises
nothing**, because it invites the belief that the world canonicalises paths.

### 5.3 THE TWO DECISIONS INTERACT, AND THAT IS THE FINDING

`compose.ail:769` creates `"${ctx.workdir}/tmp"`; `:771` writes `"tmp/${name}.ail"`. **Absolute mkdir,
relative write.** On disk they agree whenever the process runs in `workdir`. In a world keyed on strings
they never agree.

**Under the prefix-derived representation that state is INVISIBLE.** `"/w/tmp"` has no children, so it
reads as absent — *exactly as if the `mkdirAll` had never run*, which is byte-identical to the effect
never having been routed. **Under the kinded table it reads as an EMPTY DIRECTORY**, which is a state no
correct sequence produces.

So the handoff's observability measurement — "no compose session can observe a created-but-empty
directory" — **is already false for a routed compose**, and the thing that makes it false is the path
key rather than a future call site. `assert_directory_class` row 8 reproduces `compose.ail:769`/`:771`
exactly and pins both halves.

**Representing the empty directory is what makes the path-key defect observable instead of silent.**
Neither decision produces that on its own.

## 6. The recording decision: the create in, both reads out

**Inherited from WI-D17 §3 and re-stated at the site rather than assumed.** `world_state_of`
reconstitutes the world's *supply* — script, approvals, tools — because a replay cannot compute those. A
directory create is not supply; it is the driver's own act, and a replayed driver performs it again
through the same adapter. A `path_stat` or a `dir_list` observes a table `InitialWorld` has no field for,
so logging it would describe an observation the artifact still cannot rebuild.

**Recorded for GRADING, not reconstitution — the third class in that category.**

**`OutcomeMissing` is NOT admitted for `dir_make`,** and it reaches `validate_outcome`'s rejecting arm by
*falling through* rather than by being named — which is why it is stated there and asserted here.
`mkdirAll` is **idempotent**, so "the directory was already there" is an ordinary `ok`, and the class has
no reading-B state at all. **Mutant 12e** (`execution_program_dst`) is what says "and nothing else"; the
D17 widening stays at exactly one mutator.

**`dir_make` joins `dst_discovery.absent_classes`,** on D17's reason and with D17's consequence: pinned
at zero in both directions, so the moment part 2 routes a compose `mkdirAll` on a graded profile
`check_discovery` goes red by name. **The two reads are not there and could not be** — they write no
interaction, so there is no kind to balance. That asymmetry is the recording decision showing through
the census, which is where it should be visible.

## 7. The mutants

Ten run. Per S24, reachability is asserted separately from verdict throughout — every "after" row in
`assert_directory_class` has a "before" control, because *"present after mkdir"* is satisfied by a world
that always said present.

| # | Mutation | Result |
|---|---|---|
| 1 | **`scripted_dir_make` returns `next_state: state`** | **RED, 4 rows.** Message: `present=false n=0` — *the identical observation an absent path produces.* D17's trap, on a third adapter. |
| 2 | **`dir_list` derives `present` from `List.length(entries) > 0`** | **RED, 2 rows.** The empty-versus-absent collapse. Passes every other row in the function. |
| 3 | **`world_path_kind` loses the EXPLICIT half** (= the prefix-derived design) | **RED, 4 rows** — including `dir_make … entries 1 -> 2`, i.e. idempotence lost as well |
| 4 | `world_path_kind` loses the DERIVED half | RED, 4 rows |
| 5 | `dir_list` without the sort | **PASS first time** — see below |
| 5b | the same, against the repaired fixture | RED, 1 row |
| 6 | `dir_list` without the dedupe | RED, 1 row |
| 7 | `recording_dir_make` logs but does not wrap | RED — `log=1 kind=missing` |
| 8 | `recording_dir_make` wraps but records nothing | RED — `log=0 kind=dir` |
| 9 | the `files` codec drops the `kind` key | RED — `ext_world` round trip |
| 10 | `DirMakeIdentity` derives kind `"file_write"` | RED — injectivity, `dst_interaction` |
| 12 | `file_write` over a directory reports `ok` | RED, 1 row |

**Mutant 5 is the one worth reporting.** It PASSED, and the fixture was wrong rather than the code:
written `b/x`, `b/y`, `a.ail`, the prepend leaves `a.ail` at the head and the derived names come out
**already sorted**, so dropping the sort changed nothing and the word "SORTED" in the row's own label was
pinned by nothing. The writes were reordered so the unsorted answer is `[b, a.ail]`, and the reason is
recorded at the fixture. **D17 §5 found the same shape from the other side** — there, a distinction the
handoff predicted turned out not to exist; here, a distinction the label claimed turned out not to be
measured.

**Mutants 7 and 8 are a pair and neither is redundant**, for D17's reason verbatim: each is green under
the other's failure, and a recorder that logs without acting produces a log that looks complete over a
world that never changed.

**Mutant 9 is the transport half of §2.4.** A present-but-empty FILE and an empty DIRECTORY serialise to
the same `content: ""` and differ only in `kind`, so an encoder that dropped the key round-trips the
directory back as an empty file while every length, path and content check still passes.

**Two mutants were NOT run because nothing exercises their site**, and that is a gap rather than a
result: `ambient_dir_list` without the sort, and the `session.ail` bridge deriving `present` from the
entry count. No target in this tree calls an ambient directory read or an `ExtPorts.dir_list`. The bridge
is one expression from a silent wrong answer and is covered by comment and by nothing else — the same
status D16 left `ExtPorts.file_read`'s bridge in, and part 2 is what gives either a witness.

## 8. What fired without being pointed at

**Three guards, all deriving their subject list from something rather than writing it out.**

| Guard | What it said |
|---|---|
| `ext_world.test_every_identity_variant_round_trips_through_the_token` | The length check WI-D17 added *"so a tenth constructor that is added to the sum and forgotten HERE fails on the count"* — **it went red on the tenth constructor, one item after it was written for exactly that.** |
| `derive.py --self-test` reachability | `FAIL REACHABILITY: ExtPorts.dir_list / dir_make / path_stat derive 'returns-it' but are not pinned in expected.json` — **three named failures, third item running.** |
| `invariants` / `program_persistence` | Both derive their class list from `all_interaction_kinds()`; both reddened on the new class. |

**D17's contradiction did not recur**, and the reason is that D17 resolved it structurally:
`frozen_v1_interactions()` is pinned at what v1 contained and `post_v1_interactions()` grows. This item
appended one interaction to the second and touched neither the frozen bytes nor the row that reads them.
`git status` on `scripts/dst/fixtures/` is clean. **The two-tier compatibility surface D17 named has now
recurred exactly as predicted** — three classes round-tripped and not frozen, up from two.

## 9. Recorded bindings: decided versus discovered

**Discovered — a tool, a compiler or a measurement forced it:**

1. **The adapter pair already disagreed on a directory** — §3.2. Found by writing `ambient_path_stat`
   next to `ambient_file` and noticing the guard, not predicted by the handoff, which framed the gap as
   prospective.
2. **The ordering row was pinned by nothing** — mutant 5. A fixture whose write order accidentally
   produced the sorted answer.
3. **The path key falsifies the observability measurement** — §5.3. The handoff supplied both facts and
   they were not put together in it.
4. **D17's tenth-constructor length check earned itself on the tenth constructor**, one item after
   being written.
5. **`kv` returns a record, not a tuple**, so a `[(string, Json)]` field-list helper does not unify —
   the codec helper had to build the whole object. A compiler fact, cheap, recorded because it is the
   second time a JSON-shaped helper in this tree has been written the wrong way round.

**Decided — a judgement that could have gone the other way:**

1. **One kinded table, over both designs the handoff named** — §2. The alternative that most nearly won
   is (1)-with-a-guard, which the handoff calls cheap; it is, and it buys a claim that has to keep being
   true.
2. **`mkdirAll` mediated** — §4. Declining was available and would have been consistent with D17's
   letter; it is inconsistent with D17's reasoning, which is that an argument's conclusion cannot be
   refused once its premise is built.
3. **Raw string path keys** — §5. Lexical normalisation was available and is worse than none.
4. **`ambient_file`'s guard repaired rather than reported.** The handoff's stop conditions cover
   `FileRead`'s *type*; this is its *adapter*, and the repair is one token in the direction the new class
   makes correct.
5. **Both adapters sort the listing** — §3.3. The alternative is a declared gap, and a declared gap here
   is a pair that disagrees on the exact string compose renders.
6. **Two read seams and not one.** A combined `DirRead` would make every kind question pay for a
   listing and would have to call `listDir` on non-directories.
7. **`ExtPathKind` crosses the ABI as a SUM, not a string.** `ExtProcOutcome.output` is a rendered
   string because nothing matches on it; compose matches on this three ways. The bridge translation is an
   **exhaustive match**, so a fourth constructor on either sum is a compile error at the one place the two
   vocabularies meet.
8. **`dir_make` reuses `FileMutation`.** Its answer has the same shape as the other two mutators', which
   is that type's own stated reason for existing.
9. **The `dir_make` interaction appended to both shared fixtures, never inserted** — S26, and D17 paid
   for the lesson.

## 10. Whether any site admitted two type-checking answers with a silent wrong one

**Yes — TWO. 74 across forty-two runs.**

**SITE 1 — `ambient_file`'s `fileExists` guard, and it was already in the tree.** It type-checks, it is
the guard *"every call site in `context_usage` already carried"* (its own comment says so), and it is
**true for a directory** — so the live adapter read a directory while the deterministic one reported it
absent. The two answers were available at the same line for two items and neither was flagged. Counted
because the criterion is "admitted two type-checking answers with a silent wrong one", not "was
introduced by this item". **This is exactly where the handoff said to look first, and the shape it
predicted was there — one item earlier than predicted.**

**SITE 2 — the `dir_list` ordering fixture, and this one WAS written wrong and it passed.** Mutant 5.
The row's label says SORTED; the fixture's write order made sorted and unsorted the same answer, so the
sort was unpinned while the row printed `✓`. **A green row that measures less than its own label claims
is D17 site 2's shape with the subject correct and the property wrong** — and it was caught only because
the mutant was run, not by anything in the file.

**The near miss that is NOT counted**, for D16's reason: the eight `ExtPorts` construction sites and the
six `Ports` ones are closed records, so AILANG's *"records are closed — add the field(s)"* made every
missing binding loud. **Fourteen construction sites this time, all silent-proof.**

**The self-inflicted loss that is not a defect and is reported anyway:** `git checkout
src/core/dst_interaction.ail` was used to restore a mutant, which reverted the item's own work in that
file. Caught in the next `git status`, re-applied from the script that wrote it, verified identical by
diff size. **S17 says restore mutants by `cp` or `tar`, and the reason is exactly this**; a backup copy
existed for `ports.ail` and `ext_world.ail` and not for the file that was mutated last.

## 11. The ABI changed-row count

**FIFTEEN rows now, up from twelve, and this item added three.**

| | |
|---|---|
| B1, B2a, B2b, C5 | 4 |
| D6 (`on_budget_plan`) | 5 |
| D7 (`on_response_intercept`, `on_solver_candidate`) | 7 |
| D8 (`ExtPorts.ai_step`, `ExtensionHooks.on_pre_step`) | 8 |
| D16 (`proc_exec` changed, `file_read` added) | 10 |
| D17 (`file_write`, `file_remove` added) | 12 |
| **D18 — `ExtPorts.path_stat` ADDED** | **13** |
| **D18 — `ExtPorts.dir_list` ADDED** | **14** |
| **D18 — `ExtPorts.dir_make` ADDED** | **15** |

Plus **five added types** — `ExtProcOutcome`, `ExtFileRead` (D16), `ExtFileMutation` (D17),
`ExtPathStat` and `ExtDirListing` (D18) — on D6's convention. `ExtPathKind` is counted with
`ExtPathStat` rather than separately: it exists only as that record's field type and has no independent
surface.

Of the fifteen, **nine are changes to existing fields and six are additions.** Additions were a tenth of
the tally at D16 and are now **40%** of it; Route B's surface work is additive, and the breakdown is
given rather than left to be inferred from one number.

**Nothing forces the major and this item did not cut it**, for D6's, D7's, D8's, D14's, D16's and D17's
reason unchanged: **cutting it is a release act.** `packages/motoko-ext-abi/ailang.toml` still declares
5.0. **C5's trap was checked and did not fire:** `git diff` over `*ailang.toml` is empty; `ailang.lock`
moved by the normal build and no version did.

## 12. The sweep

`make sync_packages` first (**fifteenth consecutive item**), then `AILANG_RELAX_MODULES=1 make dst`
cache-cold — every repo-local `.ailang/cache/compile` outside the vendored `ailang/` checkout removed
(23 directories), which S9-as-D16-extended requires.

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, and nothing else** — identical to the
inherited baseline at D14, D15, D16 and D17, and unrelated to this item (`prompts_test.ail` 0/6 on
*"Named test blocks not yet implemented"*).

**The cascade was priced and it came in at the price.** Five `session.ail` anchors re-baselined
`931/1185/1291/2736/2846 -> 965/1224/1330/2775/2885`, verified character-identical against
`git show HEAD:` at all five. The table's identity hash moved to
`sha256:6b929328f5db…`; `driver_only` went **17** and `driver_plus_no_ops` went **4**. **D17's warning
reproduced exactly, third item running:** `make anchors` and `make attribution_table` both went green
with only `driver_only` re-issued, and `driver_plus_no_ops` then failed on its own hash. Necessary, not
sufficient.

`stub_step.ail:203` did not move — the three new symbols were widened onto **existing** import lines
(S18), and the anchor check confirms it.

**The yields did not move**, which is the expected answer for an item that added no call site:
classifier 3 closure **4 of 15**, hook scope **5 of 15**, identical to D15, D16 and D17.

Selftest evidence, read as membership rather than as an exit code (B4):

```
  ok  membership path_stat    returns-it  seam=Ports.path_stat
  ok  membership dir_list     returns-it  seam=Ports.dir_list
  ok  membership dir_make     returns-it  seam=Ports.dir_make
  ok  reachability     10 ExtPorts field(s) derived, 10 pinned, sets identical
CLASSIFIER-2 SET (1): env_get
```

**The classifier-2 set is unchanged at `{env_get}`.** All three new rows front a core seam that threads a
successor and all three return types carry it, so the criterion does not select any of them — born wide,
as at D17.

## 13. What this item did NOT do

- **Routed nothing.** Zero call sites added. `path_stat`, `dir_list` and `dir_make` have no callers on
  either surface, the state D16 left `file_read` in and D17 left the two mutators in.
- **Did not touch `InitialWorld` or the program schema** — still owed, still scoped out. **And it is now
  owed more loudly**: `InitialWorld.files` would have to carry the kind, so the drafted change grew a
  field before it was taken.
- **Did not widen `FileRead`** — D17's stop condition, respected. §3.1.
- **Did not give `WorldState` a working directory** — the handoff's second stop condition. §5.2.
- **Did not fix the eight stale classifier-2 literals.** Still `["ai_step", "env_get", "proc_exec"]` at
  seven test sites plus `src/core/dst_profile.ail:2074`, now **six items stale**.
- Did not touch door 3's producer, the hook-scope promotion, or the release.

## 14. What the next item should know

1. **Part 2 is blocked on ONE thing: door 3's producer.** The directory seam exists, and with it all
   three of compose's directory READ sites and all six `mkdirAll` sites — nine in total — are routable.
2. **THE ROUTING ITEM INHERITS A WRITTEN RULE IT MUST OBEY: one spelling per path.** `compose.ail:769`
   and `:771` violate it today. Routing them unchanged produces a run whose `list_dir` reports an empty
   directory where the file is — and the symptom is `entries: []`, which is a *plausible* answer, not a
   crash. **Fix the spelling at the call site; do not teach the world to guess.**
3. **`absent_classes` will go red the moment a `dir_make` is routed** — three classes now pinned at zero.
   Deliberate; the routing item owns the decision it forces.
4. **Every Route B surface item re-baselines five anchors and re-issues both profiles.** Four in a row.
5. **Two mutants have no site that exercises them** — §7. Part 2 gives the bridge and the ambient
   listing their first witnesses, and should assert them rather than assume the comments held.
