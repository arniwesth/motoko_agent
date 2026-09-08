# Handoff: WI-D17 — the core filesystem *write* world class

Audience: a fresh session grounded against HEAD. **The half WI-D16 decided and deliberately did not
build.** Route B part 2 cannot start until this exists.

**Read first:** `NOTE-d16-route-b-the-extports-surface.md` — its write/print decision and the compose
measurement behind it — then `Ports.file_read` and `scripted_file`/`ambient_file` in
`src/core/ports.ail` (D3's read class), which this copies.

## Why this and not part 2

D16 measured part 2 as blocked on three things: **this class**, a directory seam, and door 3's
producer. This is the one whose shape is already decided, so it is the one that can be built without
re-opening a decision.

**D16's decision, which this item implements rather than revisits:** file writes are **world-mediated
and recorded**; `println` is **not** — it is disclosed. What splits them is whether the session ever
observes the result. Verified at review in `compose.ail:502-521`: `writeFile(snippet_path, …)` →
`check_snippet(snippet_path)`, which **shells out to that path** → `if not checked.ok` →
`fileExists`/`removeFile` → `run_snippet` reads it again. **Control flow branches on it twice.**

The reconciliation with the ADR is worth stating because it is not obvious: **`ADR:303` scopes the
boundary to "external observations that can affect session control flow"**, and a write is not an
observation. **It is in scope derivatively** — leaving it ambient while its readers are mediated puts
one fact in two homes, which is `ADR:340-341`'s *"exactly one home, visibly threaded"*.

## Mission

**Add the filesystem write class to `Ports`**, on `file_read`'s shape, with a deterministic adapter, an
ambient adapter, and a recording adapter.

`Ports` at HEAD is **six fields**, verified: `model_step`, `approval_read`, `clock_now`, `env_get`,
`file_read`, `tool_exec`.

## The property no existing class has, and it is the whole difficulty

**Every adapter in `Ports` today either consumes from the world, advances a scalar, or passes state
through unchanged. None of them ADD to a table.** Measured — these are every state update in
`ports.ail`:

| Site | Update | Shape |
|---|---|---|
| `:519` `scripted_approval` | `{ state \| approvals: rest }` | **consumes** |
| `:541` `virtual_clock` | `{ state \| clock_ms: state.clock_ms + 1 }` | **advances a scalar** |
| `:619` `scripted_tool` | `{ state \| tools: rest, clock_ms: … }` | **consumes** |
| `:660` `record_interaction` | `log: state.log ++ [...]` | **appends — and it is the ONLY append site, deliberately** |
| `scripted_file:572-573` | `next_state: state` | **unchanged** |
| `ambient_file:595`, `scripted_env:547`, `ambient_env:604` | `next_state: state` | **unchanged** |

**A write is the first class where the driver puts something INTO the world.** `state.files` is
seeded-and-read-only today; this makes it live.

**And `lookup_file` (`:577-581`) is first-match on a list.** So *prepending* a written entry gives
write-then-read-sees-the-write for free, and *appending* gives stale-read-wins. **That is a one-token
difference with opposite semantics and no test currently distinguishes them.** Pin it.

## The trap, and it is this project's counted failure mode

**If the write adapter returns `next_state: state` — forgetting the update — a subsequent `file_read`
returns `present: false`, which is EXACTLY what it returns if the write was never routed at all.**

**Absent reads identically to unchanged.** This project has marked that shape at C1, D6, D12, D13 and
D16. Here it is structural rather than incidental: the read class's miss branch and the write class's
no-op branch produce byte-identical observations.

**So the fixture that matters is write-then-read-back asserting the CONTENT**, and the mutant that must
go red is dropping the state update — not a type error, not a missing field. **Per S24, assert
reachability separately from verdict.**

## The decision this item owns

**D3's read class is NOT recorded, and that is measured, not assumed.** There is no `FileReadIdentity`
constructor and no `recording_file` adapter. `IdentityBody` (`dst_interaction.ail:59-66`) has **seven**
constructors and the recording adapters are **four**: `recording_clock`, `recording_env`,
`recording_approval`, `recording_tool`.

**But `EnvironmentReadIdentity(string)` exists.** So the log records env reads and does not record file
reads. **D3 left an asymmetry and nothing has re-asked it.**

D16 chose *recorded* for writes. **That produces a log that contains the mutation and not the
observation that branches on it.** Decide explicitly whether that is coherent:

- **Record the write only** — the log's job is the world's *supply* of nondeterminism, and a write is
  the driver's own act. Then say why env reads are recorded and file reads are not.
- **Record both** — closes D3's asymmetry, and is a second class, so say so and price it.

**Do not pick by implementation convenience.** This is the item's durable output alongside the code.

### What a new `IdentityBody` constructor costs, measured

`identity_kind` (7 arms), `all_interaction_kinds()`, and **both directions of `ext_world.ail`'s
`identity_body_json` / `identity_body_of` with a round-trip**. The census (`dst_discovery.ail:453`)
picks it up automatically — *"a class added to `IdentityBody` appears in the census automatically
instead of being a class nobody counts."*

**But nothing asserts a census count is NON-ZERO.** I grepped for it; there is no such assertion. **A
new class with no recording adapter would sit at `=0` and the census would print it happily.** That is
the same fail-open shape S24 was promoted for.

**And `identity_kind`'s own comment says these strings *"are part of the artifact surface and change
only with a schema version."*** `event_vocabulary_version()` is `"event-vocabulary/1"`
(`dst_event_vocabulary.ail:111`). **If you add a class, say whether that string moves and what
re-attests if it does.**

## The scope question you must answer out loud, because two established rules disagree

**D3's rule is narrowness:** `file_read` is *"NARROW by construction: a path in, existence and contents
out"*, and D16's handoff said **copy that shape, do not generalise it.**

**D16's rule is two-homes:** anything that changes what a mediated read returns must be mediated too.

**These pull apart here, and the measurement shows by how much.** Compose's "write side" is *three*
builtins, not one — counted across `author_tools.ail`, `authoring/dispatcher.ail`, `compose.ail`,
`store.ail`:

| Builtin | Sites in compose |
|---|---|
| `writeFile` | **7** |
| `mkdirAll` | **6** |
| `removeFile` | **5** |

**`removeFile` changes what `fileExists` returns, and compose branches on exactly that** — it is the
`if not checked.ok then if fileExists(...) then removeFile(...)` arm D16 measured. **So a narrow
`file_write` alone leaves the two-homes defect standing on 5 of 18 sites**, and part 2 would hit it.

**Resolve it explicitly.** A defensible answer is *the file table's mutators* — write and remove —
with `mkdirAll` deferred to the directory seam, since directory existence is only observed through
`isDir`, which does not exist yet. **What is not defensible is building `file_write`, saying nothing,
and letting part 2 rediscover it.**

## Definition of done

**The class on `Ports`**, state-threaded, with the deterministic adapter **growing `state.files`** and
the ordering-versus-`lookup_file` question pinned by a fixture.

**The recording decision taken and recorded with its reasoning**, and if a new `IdentityBody`
constructor lands, all four of its dependents plus the JSON round-trip.

**The write-then-read-back fixture, and its mutant red.** The no-op adapter must not pass.

**The `removeFile` question answered**, either built or named as owed with the argument stated.

**`ExtPorts.file_write` is IN scope if and only if it fronts the core class.** D16's reason stands: a
field fronting nothing derives `unrouted` — mediation-shaped and reported as a bypass.
`session.ail:832`'s `ext_ports_of` is where it binds.

**Nothing in compose routed.** That is still part 2.

**Per S13/S9/S17** — targets in `make dst`; sweep cache-cold with `AILANG_RELAX_MODULES=1` including
the stdlib-adjacent cache **and the dependents of any interface you edit** (S9 as D16 extended it: a
stale 4-field `ExtPorts` reached a failing module through `compaction_ai`'s cached interface, and
clearing the ABI's own cache in all 29 directories did not fix it); `make sync_packages` first
(fourteenth consecutive item); restore mutants by `cp` or `tar`.

**Per S22/anchors as D16 extended it** — `make anchors` is necessary and **not** sufficient. It checks
anchors, not the set of profiles that recorded the table's hash. **Both profiles now exist**; re-issue
both.

## Out of scope

- **Routing compose.** Part 2. Its read side is `fileExists` 9, `readFile` 5, `isFile` 3 — **17 more
  sites** on top of the 18 write-side ones.
- **The directory seam.** `Ports` has none; compose calls `listDir` once and `isDir` twice.
- **Door 3's producer** (`show`), and **removing the now-unused imports** (part 3).
- **Promoting the hook-scope verdict.** ADR-scope, needs a review round, runs in parallel.
- **The eight stale classifier-2 literals** — see below. Real, unguarded, and not this item.
- Installing anything; the full eleven-row table for either profile; criterion 1's basis; repairing
  classifier 1; the stdlib cache's 52-file producer; the gate-table State column; F3.

## The stale set, so it stops being rediscovered

**Exactly eight sites carry `["ai_step", "env_get", "proc_exec"]`** — stale for `ai_step` since B2b and
for `proc_exec` since D16, when the true set became `["env_get"]`:

`execution_program_dst.ail:79`, `corpus_pr_dst.ail:369`, `strict_replay_dst.ail:605`,
`corpus_rotating_dst.ail:220`, `latency_pair_dst.ail:229`, `discovery_dst.ail:578`,
`seeded_generator_dst.ail:566` — and **`src/core/dst_profile.ail:2074`, which is not a test**, sitting
at `abi_version: "4.0"` beside it.

**Nothing compares any of them to the derived set.** Fixing them is cheap; the item that fixes them
should add the guard, or they go stale a third time.

## Stop and report rather than deciding inline

- **If recording the write requires a vocabulary-version bump**, draft and stop — that string is
  attested by profiles and a re-attestation is a broader act than this item.
- **If growing `state.files` forces a change to `file_read`, `lookup_file`'s semantics, or any settled
  class**, stop. D3's read class is Accepted-adjacent and a rewrite is a different item.
- **If the deterministic and ambient adapters cannot be made to agree without production code
  branching on test mode**, that falsifies D1 — B2b's stop condition, unchanged.

## Report back

Forty-first calibration run. **D16 ran 18:42 → 20:21 ≈ 1h39m** (the 18:42 commit was D15's leftover
work, not D16's start); the plan entry says ~1h25m and should be read as the lower figure being wrong.

- **The git wall-clock window.**
- **The recording decision, with its reasoning.** The durable output.
- **Whether `removeFile` was built or deferred**, and on what argument.
- **The mutant results** — specifically, did dropping the state update go red.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **70 across forty
  runs.** This is a record-shaped item on the core surface, which is where A12 and D3 each found one.
- **The ABI changed-row count** if `ExtPorts` moves. It stands at **ten rows plus two added types**,
  still not cut.
