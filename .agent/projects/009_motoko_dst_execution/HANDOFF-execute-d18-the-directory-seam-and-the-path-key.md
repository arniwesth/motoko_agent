# Handoff: WI-D18 — the directory seam, and the world's path key

Audience: a fresh session grounded against HEAD. **The last of part 2's build blockers**, and it
carries a defect that is live today rather than a design choice.

**Read first:** `NOTE-d17-the-file-write-world-class.md` §3.2 (the `InitialWorld` measurement — it is
load-bearing here for a second reason) and §4 (why `mkdirAll` was deferred).

## Why this and not door 3

Part 2 is blocked on **two** things: this seam and door 3's producer. **D16's rule decides the order —
a blocked verdict is not a blocked build.** Door 3 gates whether compose's coverage *counts*; this
gates whether compose can be *routed at all*. Build first.

## Mission

**Give `Ports` the directory class part 2 needs**, and settle how the deterministic world represents a
directory at all. `Ports` is eight fields after D17.

Compose's directory surface, verified — **three call sites, all in `author_tools.ail`**:

| Site | Call | What it feeds |
|---|---|---|
| `:140` | `isDir(path)` | `normalize_type` — returns **`"dir"` / `"file"` / `"missing"`, three-valued** |
| `:189` | `not isDir(path)` | `list_dir_impl`'s `not_a_directory` error arm |
| `:192` | `listDir(path)` | the `list_dir` author tool's `entries` payload |

Plus **six `mkdirAll` sites** D17 deferred: `store.ail:21,39,48`, `compose.ail:502,769`,
`authoring/dispatcher.ail:216`.

## The representation question — the item's durable output

**`WorldState.files` is `[{ path: string, content: string }]`. There are no directories in the world at
all.** Two answers, and they differ on exactly one thing:

1. **Prefix-derived** — `is_dir(p)` is true iff some entry's path is under `p/`; `list_dir(p)` is the
   distinct next segments. No new table. **An empty directory is unrepresentable.**
2. **An explicit `dirs` table** — `mkdirAll` becomes mediatable, empty directories exist, and
   `WorldState` grows a second filesystem field that must stay consistent with the first.

**Under (1), an empty directory reads identically to an absent one.** That is this project's counted
failure mode appearing *in the world model itself* rather than in an adapter — and `list_dir` on an
empty directory returns `entries: []` where an absent one returns `not_found`, which
`list_dir_impl:189` turns into two different tool results. **A session can branch on the difference.**

### The measurement that bears on it, and I made it rather than leaving it to be argued

**All six `mkdirAll` sites are immediately followed by a `writeFile` into that directory, with no
intervening read.** Verified at each: `store.ail:21→24`, `39→42`, `48→52`, `compose.ail:502→503`,
`769→771`, `dispatcher.ail:216→219`.

**So no compose session can observe a created-but-empty directory today.**

**And D17's `InitialWorld` finding tightens it further, in a direction that item did not need.**
`InitialWorld` has no `files` counterpart, so **a deterministic run's filesystem starts empty and
contains only what that run wrote.** A directory therefore exists *iff* something wrote into it — with
`mkdirAll` as the single exception, and the measurement above says that exception is never observed.

**Per S25, here is what that claim is conditional on**, because the rule was earned by me stating one
that was not: it holds **for compose as it is written today**, and it is falsified by any site that
creates a directory and lists it before writing, or by any future `InitialWorld.files` that can seed an
empty one. **Decide whether the item is buying (1) permanently or buying it with the condition
written down and a guard on it.** The second is available and cheap; the first is not obviously wrong.

## The read seam cannot answer for a directory, and part 2 needs it to

**This is not a design question. It is a gap in what D3 built, and routing will hit it.**

`list_dir_impl` guards `fileExists(path)` **then** `isDir(path)` — so `author_tools.ail:189` asks
`fileExists` about a **directory**. Route that through `Ports.file_read` and the two adapters give two
different wrong answers:

- `scripted_file` → `lookup_file` finds no flat entry for a directory → **`present: false`**.
- `ambient_file` → `fileExists(dir)` is **true**, so it proceeds to `readFile(dir)`.

**And `normalize_type:140` needs three values — dir, file, missing — where `FileRead.present` has
two.** Compose has **nine `fileExists` sites**; at least `author_tools.ail:189` and `:250`
(`file_exists_impl`, whose path comes from the model) can be handed a directory.

**Decide whether the answer is a third class (`path_stat`) or a widening of `FileRead`**, and note that
a widening touches a settled class — the handoff's third stop condition at D17, still in force.

## THE PATH KEY — and this one is live, not prospective

**`lookup_file` and `remove_path` are exact string equality** — `e.path == path`, both verified — and
**nothing in `ports.ail` normalizes a path.** The real filesystem does.

So `tmp/x.ail`, `./tmp/x.ail` and `/w/tmp/x.ail` are **three entries in the world and one file on
disk**. That is **two homes for one fact, created by the world's key rather than by an unmediated
effect** — a different producer for the shape D16 and D17 both argued from, and one no existing rule
covers.

**It is already reachable in compose.** `compose.ail:769` creates `"${ctx.workdir}/tmp"` and `:771`
writes `path = "tmp/${name}.ail"` — **absolute mkdir, relative write.** On disk those agree whenever
the process runs in `workdir`; **in a world keyed on strings they never agree**, and the directory the
run created is not the directory the write lands under.

**This is the item's second decision.** Either the world normalizes on the way in — and then says what
"normalize" means without a cwd, which the world does not have — or it keys on raw strings and the
routing item is told, in writing, that **the caller must supply one spelling per file**. Both are
defensible; silence is not, because the symptom is a read returning `present: false` for a path that
was just written, which is indistinguishable from the write never having been routed.

## Definition of done

**The directory class on `Ports`**, with the representation decided and the reasoning recorded, plus
deterministic, ambient and (if recorded) recording adapters on D17's shape.

**`mkdirAll` answered** — mediated, or declined with the observability measurement above as the reason
and a guard that fails if a future site breaks it.

**The directory-vs-file existence gap closed**, so part 2 can route `author_tools.ail:189` without
choosing between two wrong answers.

**The path-key decision taken and written at the seam**, not in a report.

**Mutants, and per S24 reachability asserted separately from verdict.** The one that matters:
**`list_dir` on a path with no entries must be distinguishable from `list_dir` on a path that was never
created** — if the chosen representation cannot distinguish them, that is the finding, and it should be
stated rather than tested around.

**If a recorded class is added, decide whether it joins `dst_discovery.absent_classes`.** D17 pinned
`file_write` and `file_remove` at zero deliberately, as a tripwire for part 2. A third class that is
recorded and unrouted has the same choice and the same reason.

**Nothing in compose routed.** Still part 2.

**Per S13/S9/S17/S26** — targets in `make dst`; sweep cache-cold with `AILANG_RELAX_MODULES=1`,
clearing the **dependents** of any edited interface; `make sync_packages` first (fifteenth consecutive
item); restore mutants by `cp` or `tar`; and **extend shared fixtures by APPENDING** — D17 lost a row
to an ordinal insertion that stayed green while reading the wrong subject.

**Per D17 §10.4, price the cascade in advance rather than discovering it:** every Route B surface item
re-baselines five `session.ail` anchors and **re-issues both profiles**. `make anchors` is necessary
and not sufficient.

## Out of scope

- **Routing compose.** Still part 2, and after this item it is unblocked except for door 3.
- **Door 3's producer** (`show`), and the hook-scope promotion. Both parallel.
- **`InitialWorld.files` and the program-schema bump** — D17 drafted and stopped; still owed, still
  not this.
- **The eight stale classifier-2 literals**, now five items stale.
- Installing anything; the eleven-row table for either profile; criterion 1's basis; classifier 1's
  repair; the stdlib cache's producer; the gate-table State column; F3; the ABI major at twelve rows.

## Stop and report rather than deciding inline

- **If closing the directory-vs-file gap requires changing `FileRead`**, stop and say so. D3's class is
  settled and a widening of it is a different item — D17's stop condition, unchanged.
- **If path normalization cannot be defined without giving the world a cwd**, stop. Giving `WorldState`
  a working directory is a world-shape change and it reaches replay.
- **If the representation forces `WorldState` to hold two filesystem tables that can disagree**, that
  is the two-homes shape in the world itself — say so before building it.

## Report back

Forty-second calibration run.

- **The git wall-clock window.** D17 ran ~1h05m against D16's ~1h39m.
- **The representation decision and the path-key decision, with reasoning.** The durable outputs.
- **Whether an empty directory is distinguishable from an absent one** under what you built, stated
  plainly either way.
- **Whether `mkdirAll` was mediated or declined**, and what guards the reason.
- **The mutant results.**
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **72 across
  forty-one runs**, and D17 contributed two — one of them on its own subject matter. This item's
  equivalent is the adapter pair: a directory answer that is right in one adapter and wrong in the
  other **is the shape you are building**, so look there first.
- **The ABI changed-row count** if `ExtPorts` moves. **Twelve rows plus three added types**, still not
  cut.
