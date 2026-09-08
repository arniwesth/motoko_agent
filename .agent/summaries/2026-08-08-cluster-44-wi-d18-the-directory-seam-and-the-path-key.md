# 2026-08-08 Cluster 44: WI-D18 — the directory seam, and the world's path key

## Context

Branch: `arniwesth/mot-80-wi-d18-the-directory-seam-and-the-worlds-path-key`.

Session span: `cfedfd4` → **`bbf348a`** (+ `dda862a`, a correction to the record's own
wall-clock section). Input was
`HANDOFF-execute-d18-the-directory-seam-and-the-path-key.md`, grounded against HEAD
`cfedfd4` (`2026-08-08T07:30:26Z`). Pin **v0.33.0**. First command `07:34Z`, commit
`08:36Z`, **~1h03m**.

**The last of Route B part 2's build blockers.** Twenty-nine files,
**1 615 insertions / 85 deletions**, of which **458** are the record.

```text
src/core/ports.ail                      495 +-   FsNode, PathKind, PathStat, DirListing,
                                                 6 derivations, 7 adapters, 3 Ports fields
scripts/dst/world_state_probe.ail       156 +-   10 assertion rows at the adapter
src/core/ext_world.ail                   75 +-   the kinded files codec + the tenth identity variant
packages/motoko-ext-abi/types.ail        43 +    3 ExtPorts rows, 2 new types (+1 field sum)
src/core/session.ail                     41 +-   3 bridges; the PathKind↔ExtPathKind exhaustive match
src/core/dst_interaction.ail             39 +-   DirMakeIdentity, 6 derivations, injectivity at ten
src/core/test/stub_step.ail              27 +-   live/recording/generating, S18 import widening only
src/core/dst_discovery.ail               20 +-   dir_make pinned at 0 — part 2's tripwire
6 × ExtPorts/Ports construction sites   ~90 +-   closed records, every one loud
5 × attribution/profile artifacts       ~70 +-   the D4 cascade a FOURTH time, both profiles re-issued

NEW  .agent/.../NOTE-d18-the-directory-seam-and-the-path-key.md   458   the record
```

| Definition-of-done item | State |
|---|---|
| The directory class on `Ports`, representation decided and reasoning recorded | **met** — `path_stat` / `dir_list` / `dir_make`, and the representation is a **third** design |
| Deterministic, ambient and recording adapters on D17's shape | **met** — 2 reads × 2 adapters, the create × 3 |
| `mkdirAll` answered | **met — MEDIATED.** D17's ground for deferring it expired |
| The directory-vs-file existence gap closed | **met** — and it was **live**, not prospective (§ below) |
| The path-key decision taken and written **at the seam** | **met** — at `WorldState.files`, not in a report |
| Mutants, S24 reachability separate from verdict | **met** — 10 run, **one PASSED and the fixture was wrong** |
| Empty directory distinguishable from an absent one | **met, and it is the item's point** |
| A recorded class ⇒ decide `absent_classes` membership | **met** — `dir_make` in at zero; the reads cannot be |
| Nothing in compose routed | **met** — zero new call sites tree-wide |
| Per S13/S9/S17/S26 — cache-cold, `sync_packages` first, append-only fixtures | **met** — **fifteenth** consecutive |
| Per D17 §10.4, price the anchor/profile cascade in advance | **met** — cost ~5 min, sequence reproduced exactly |
| Stop-and-report: closing the gap needs a change to `FileRead` | **did not fire** — a third class instead |
| Stop-and-report: normalisation needs a cwd on `WorldState` | **did not fire** — normalisation declined, not attempted |
| Stop-and-report: representation forces two disagreeing tables | **did not fire** — *that is why design (2) lost* |

---

## The representation decision — the item's durable output, and it is a third design

The handoff put **two** designs on the table and asked which. **A third beats both**, and it wins by
removing a failure mode rather than trading one for another.

| Design | Empty directory | Can the world contradict itself? |
|---|---|---|
| **1. Prefix-derived** — `is_dir(p)` iff something is under `p/` | **Unrepresentable** — reads identically to absent | No |
| **2. A second `dirs` table beside `files`** | Representable | **Yes** — nothing stops `"a/b"` in both |
| **3. ONE KINDED TABLE** — built | **Representable** | **No, by construction** |

`WorldState.files` went from `[{ path, content }]` to `[{ path, node }]` with
`node = FsFile(string) | FsDir`.

**Why (1) loses:** an empty directory has no evidence, so it reads as absent, and `list_dir_impl`
(`author_tools.ail:189-190`) turns that difference into **two different tool results** —
`entries: []` against a `not_found` error. That is **absent reading identically to unchanged** — C1,
D6, D12, D13, D16, D17 and here — appearing **in the world model** rather than in an adapter.

**Why (2) loses:** it is the handoff's own third stop condition. Two tables that can disagree about one
path is `ADR:340-341`'s "exactly one home" broken **inside the world** — the shape D16 and D17 each
argued *from*.

**Why (3) is not a compromise:** one entry per path (the map invariant `remove_path` already enforced)
and an entry is a file **or** a directory, so **"this path is a file AND a directory" is not
representable**, rather than representable and forbidden by a rule somebody has to remember. Design
note 1's rule — *a kind that disagrees with its own payload cannot be written down* — applied to the
world's table instead of to an identity. **The sum beat a `kind` field beside `content`** for the same
reason: `{ path, kind: "dir", content: "hello" }` is a directory carrying a file body.

**Implicit parents are still derived** and that is not residue of the losing design: a host cannot hold
`a/b/c.txt` without `a/b` being a directory, so `world_path_kind` is *an explicit `FsDir` entry **OR**
any entry beneath*. **Mutants 3 and 4 are what say both halves are load-bearing.**

> **An empty directory IS distinguishable from an absent one.** `dir_list` returns
> `present: true, entries: []` for the first and `present: false, entries: []` for the second.

## THE PATH KEY — decided, written at the seam, and it is live

> **The world keys on RAW STRINGS. It does not normalise. The caller supplies one spelling per path.**

Normalising would fix `./tmp/x` and `tmp//x` — those are **lexical** and need no cwd — and would **not**
fix `/w/tmp/x` against `tmp/x`, which is the pair that actually occurs. Relating an absolute path to a
relative one needs a working directory `WorldState` does not have, and giving it one is a world-shape
change reaching replay (the handoff's second stop condition, respected). **A key that normalises the
harmless half and leaves the harmful half is worse than one that normalises nothing**, because it
invites the belief that the world canonicalises paths.

### The two decisions interact — the finding neither produced alone

`compose.ail:769` creates `"${ctx.workdir}/tmp"`; `:771` writes `"tmp/${name}.ail"`. **Absolute mkdir,
relative write.** On disk they agree whenever the process runs in `workdir`; in a world keyed on strings
they never do.

**Under design (1) that state is INVISIBLE** — `"/w/tmp"` has no children, so it reads as absent,
*exactly as if the `mkdirAll` had never run*, which is byte-identical to the effect never having been
routed. **Under the kinded table it reads as an EMPTY DIRECTORY**, a state no correct sequence produces.

So **the handoff's observability measurement — "no compose session can observe a created-but-empty
directory" — is already false for a routed compose**, and what falsifies it is the path key rather than
a future call site. `assert_directory_class` row 8 reproduces `compose.ail:769/771` and pins both halves.

**Representing the empty directory is what makes the path-key defect observable instead of silent.**

## `mkdirAll` — MEDIATED, and D17's ground expired

D17 deferred it on a stated ground: *"directory existence is observed only through `isDir`/`listDir`,
neither of which has a core seam, so a mediated `mkdirAll` would mutate a table nothing can read."*
**`path_stat` and `dir_list` are that seam.** The ground named its own expiry condition and this item
creates it — the same shape as D3's recording reason expiring at D17, one item earlier.

What remained was the observability measurement, and it does not carry the decision: it is conditional
on compose's current text, **and it is already false in the world** (above). Leaving the effect ambient
would also put one fact in two homes on all six sites — the directory on the host, the file written into
it in the world.

**Only the LEAF is recorded** (ancestors are derived, so materialising them is two homes in miniature);
**idempotent** over an existing directory; **refused** over an existing file, which is the one input
where a bare table insertion would invent a state the live world cannot reach.

**There is no guard, because there is no conditional claim left to guard.** That is the whole difference
between the handoff's two permitted answers: declining buys a measurement that must keep being true,
mediating buys an adapter that cannot stop being true.

## The existence gap — closed with a third class, and it was LIVE

`FileRead.present` has two values; `normalize_type` needs three. **`FileRead` was not touched** (D17's
stop condition), and not only out of obedience: D3's class has a live consumer in `context_usage` and
eight construction sites, and *"does this path hold bytes I can read"* is a different question from
*"what kind of thing is at this path"*. `PathKind`'s labels are deliberately the three strings
`normalize_type` already returns, so part 2 writes no mapping.

**AND THE ADAPTER PAIR ALREADY DISAGREED.** The handoff says to look there first; it was **already
broken at HEAD**. `ambient_file` guarded on `fileExists`, which is **true for a directory**, and then
called `readFile` on it, while `scripted_file` reported it absent. Two adapters, one screen apart, two
answers to one question about one input — D1's stop condition, live. The guard is now `isFile`; nothing
in the tree changes behaviour, because every caller passes a path it believes is a file.

**The disagreement this item could have introduced and did not: listing ORDER.** The host returns its
order, the world returns write order (which the prepend makes reverse-chronological). **Both adapters
sort**, so the pair's answers are *equal* and not merely equivalent; the deterministic side also dedupes,
because two files in one subdirectory both yield that subdirectory's name.

## The recording decision — the create in, both reads out

Inherited from D17 §3 and **re-stated at the site rather than assumed**. `world_state_of` reconstitutes
the world's *supply*; a directory create is not supply but the driver's own act, and a replayed driver
performs it again. A `path_stat`/`dir_list` observes a table `InitialWorld` has no field for. **Recorded
for GRADING, not reconstitution — the third class in that category.**

**`OutcomeMissing` is NOT admitted for `dir_make`**, and it reaches `validate_outcome`'s rejecting arm by
*falling through* rather than by being named — so it is stated there and **asserted by mutant 12e**.
`mkdirAll` is idempotent, so "already there" is an ordinary `ok`; the class has no reading-B state. D17's
widening stays at exactly one mutator.

**`dir_make` joins `absent_classes`** at zero in both directions, on D17's reason and with D17's
consequence. **The two reads cannot** — they write no interaction, so there is no kind to balance. That
asymmetry is the recording decision showing through the census, which is where it should be visible.

## The mutants — ten, and one PASSED

| # | Mutation | Result |
|---|---|---|
| 1 | **`scripted_dir_make` returns `next_state: state`** | **RED, 4 rows** — `present=false n=0`, *the identical observation an absent path produces* |
| 2 | **`dir_list` derives `present` from `List.length(entries) > 0`** | **RED, 2 rows** — the empty-vs-absent collapse; passes every other row |
| 3 | **`world_path_kind` loses the EXPLICIT half** (= design 1) | **RED, 4 rows**, including `entries 1 -> 2` — idempotence lost too |
| 4 | `world_path_kind` loses the DERIVED half | RED, 4 rows |
| 5 | `dir_list` without the sort | **PASS** — see below |
| 5b | the same, against the repaired fixture | RED, 1 row |
| 6 | `dir_list` without the dedupe | RED, 1 row |
| 7 | `recording_dir_make` logs but does not wrap | RED — `log=1 kind=missing` |
| 8 | `recording_dir_make` wraps but records nothing | RED — `log=0 kind=dir` |
| 9 | the `files` codec drops the `kind` key | RED — `ext_world` round trip |
| 10 | `DirMakeIdentity` derives kind `"file_write"` | RED — injectivity at ten |
| 12 | `file_write` over a directory reports `ok` | RED, 1 row |

**Mutant 5 is the finding.** It passed, and **the fixture was wrong rather than the code**: written
`b/x`, `b/y`, `a.ail`, the prepend leaves `a.ail` at the head and the derived names come out **already
sorted**, so dropping the sort changed nothing and the word "SORTED" in the row's own label was pinned by
nothing. The writes were reordered so the unsorted answer is `[b, a.ail]`. **D17 §5 found the same shape
from the other side** — there a predicted distinction did not exist; here a claimed property was not
measured.

**Mutants 7 and 8 are a pair and neither is redundant**, for D17's reason verbatim: each is green under
the other's failure, and a recorder that logs without acting produces a log that looks complete over a
world that never changed.

**Two mutants were NOT run because nothing exercises their site**, and that is a gap rather than a
result: `ambient_dir_list` without the sort, and the `session.ail` bridge deriving `present` from the
entry count. No target calls an ambient directory read or an `ExtPorts.dir_list`. **The bridge is one
expression from a silent wrong answer and is covered by comment and by nothing else** — the status D16
left `ExtPorts.file_read`'s bridge in. Part 2 gives either its first witness.

## Guards that fired without being pointed at

| Guard | What it said |
|---|---|
| `ext_world.test_every_identity_variant_round_trips_through_the_token` | D17 added a length check *"so a tenth constructor added to the sum and forgotten HERE fails on the count"* — **it went red on the tenth constructor, one item later** |
| `derive.py --self-test` reachability | `FAIL REACHABILITY: ExtPorts.dir_list / dir_make / path_stat derive 'returns-it' but are not pinned` — **three named failures, third item running** |
| `invariants` / `program_persistence` | Both derive their class list from `all_interaction_kinds()`; both reddened |

**D17's frozen-specimen contradiction did not recur**, because D17 resolved it structurally:
`frozen_v1_interactions()` is pinned and `post_v1_interactions()` grows. One interaction appended to the
second; the frozen bytes and the row reading them untouched, `git status` on `scripts/dst/fixtures/`
clean. **The two-tier compatibility surface D17 named recurred exactly as predicted** — three classes
round-tripped and not frozen, up from two.

## Whether any site admitted two type-checking answers with a silent wrong one

**YES — TWO. The count goes 72 → 74 across forty-two runs.**

**Site 1 — `ambient_file`'s `fileExists` guard, and it was ALREADY IN THE TREE.** It type-checks, it is
*"the guard every call site in `context_usage` already carried"* by its own comment, and it is **true
for a directory** — so the live adapter read a directory while the deterministic one reported absent.
Two answers available at one line for two items, flagged by nothing. Counted because the criterion is
"admitted two type-checking answers", not "was introduced by this item". **The handoff said to look at
the adapter pair first and the shape it predicted was there — one item earlier than predicted.**

**Site 2 — the `dir_list` ordering fixture, WRITTEN WRONG AND IT PASSED.** Mutant 5. **A green row
measuring less than its own label claims** is D17 site 2's shape with the subject correct and the
property wrong, and it was caught only because the mutant was run.

**Not counted**, for D16's reason: the eight `ExtPorts` and six `Ports` construction sites are closed
records, so *"records are closed — add the field(s)"* made every missing binding loud. **Fourteen sites,
all silent-proof.**

**A self-inflicted loss, reported because the rule it broke exists for exactly it:** `git checkout
src/core/dst_interaction.ail` was used to restore a mutant and reverted the item's own work in that
file. Caught in the next `git status`, re-applied from the script that wrote it, verified by diff size.
**S17 says restore mutants by `cp` or `tar`** — a backup existed for the two files mutated first and not
for the one mutated last.

## The ABI

**FIFTEEN rows, up from twelve** — `path_stat` (13th), `dir_list` (14th), `dir_make` (15th), all
**ADDITIONS**. Of the fifteen, **nine are changes and six are additions**: additions were a tenth of the
tally at D16 and are **40%** now, so the breakdown is given rather than inferred from one number. Plus
**five added types** (`ExtProcOutcome`, `ExtFileRead`, `ExtFileMutation`, `ExtPathStat`,
`ExtDirListing`); `ExtPathKind` is counted with `ExtPathStat`, having no independent surface.

**`ExtPathKind` crosses as a SUM, not a string.** `ExtProcOutcome.output` is rendered because nothing
matches on it; compose matches on this three ways. **The bridge translation is an exhaustive match**, so
a fourth constructor on either sum is a compile error at the one place the two vocabularies meet.

**Nothing forces the major and it was not cut**, for D6/D7/D8/D14/D16/D17's reason: cutting it is a
release act. **C5's trap checked and did not fire** — `git diff` over `*ailang.toml` empty; only
`ailang.lock` moved.

**The classifier-2 set is unchanged at `{env_get}`.** All three new rows front a seam that threads a
successor and all three return types carry it — born wide, as at D17.

## Gate and sweep

`make sync_packages` (**fifteenth** consecutive), then `AILANG_RELAX_MODULES=1 make dst` **cache-cold** —
all 23 repo-local `.ailang/cache/compile` directories outside the vendored checkout removed, per S9 as
D16 extended it.

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, nothing else** — identical to D5 and
every item since; pre-existing since B2a (`prompts_test.ail` 0/6, *"Named test blocks not yet
implemented"*). **935 ✓ rows in 4 722 lines** (D17: 924 in 4 705).

**Two sweeps, not three.** Anchors `931/1185/1291/2736/2846` → `965/1224/1330/2775/2885`, verified
character-identical against `git show HEAD:` at all five; `driver_only` **16 → 17**,
`driver_plus_no_ops` **3 → 4**; table hash → `sha256:6b929328f5db…`. **D17's warning reproduced exactly,
third item running:** `make anchors` and `make attribution_table` both green with only `driver_only`
re-issued, then `driver_plus_no_ops` failed on its own hash. Necessary, not sufficient.
`stub_step.ail:203` did **not** move — the three new symbols were widened onto existing import lines (S18).

**Yields did not move: closure 4 of 15, hook scope 5 of 15**, identical to D15, D16 and D17. Expected —
nothing was routed.

## Recorded bindings

**Decided:** one kinded table over both designs the handoff named; `mkdirAll` **mediated**; raw string
path keys; `ambient_file`'s guard **repaired rather than reported**; both adapters sort the listing; two
read seams rather than one combined `DirRead`; `ExtPathKind` as a sum with an exhaustive bridge match;
`dir_make` reusing `FileMutation`; the `dir_make` interaction **appended** to both shared fixtures (S26,
and D17 paid for the lesson).

**Discovered:** the adapter pair already disagreed on a directory (§ above) — found by writing
`ambient_path_stat` next to `ambient_file`, not predicted; the ordering row was pinned by nothing
(mutant 5); the path key falsifies the observability measurement — the handoff supplied both facts and
did not join them; D17's tenth-constructor length check earned itself on the tenth constructor; `kv`
returns a record and not a tuple, so a `[(string, Json)]` field-list helper does not unify.

## Owed

**Part 2 is now blocked on ONE thing: door 3's producer.** All three of compose's directory read sites
and all six `mkdirAll` sites are routable.

**The routing item inherits a written rule it must obey — one spelling per path.** `compose.ail:769` and
`:771` violate it today; routing them unchanged produces a run whose `list_dir` reports an empty
directory where the file is, and the symptom is `entries: []`, a *plausible* answer rather than a crash.
**Fix the spelling at the call site; do not teach the world to guess.**

`absent_classes` now pins **three** classes at zero and goes red on the first routed mutation — deliberate.
`InitialWorld.files` + `execution-program/2`, still owed and **now owed more loudly**: the field would
have to carry the kind, so the drafted change grew a field before it was taken. The two unwitnessed
mutants (§ above). The **eight stale classifier-2 literals**, still unguarded, now **six** items stale.
Unchanged: the hook-scope verdict's promotion, the full eleven-row table, criterion 1's basis,
classifier 1, the stdlib-adjacent cache's producer, the gate-table State column, F3 — and the
`motoko-ext-abi` major, now at **fifteen** rows.
