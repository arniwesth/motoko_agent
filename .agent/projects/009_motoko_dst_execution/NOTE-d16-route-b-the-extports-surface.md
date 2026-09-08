# WI-D16 — Route B part 1: the `ExtPorts` effect surface

Grounded against HEAD `e08bfd5`. Fortieth calibration run, and **the first Route B build item.**

**`ExtPorts` went from four fields to five and from two classifier-2 members to one.** `proc_exec` was
widened to thread the world token and **left the classifier-2 set**; a new `file_read` point-read seam
was added and derives `returns-it` off `Ports.file_read`; `env_get` was deliberately not widened and
is now the sole member.

**The write/print decision was taken and it is not the one the handoff's framing leads with.** File
WRITES belong in the world — **option 2, world-mediated and recorded** — and the reason is a
measurement, not a reading of D1's boundary sentence in the abstract. **`println` does not — option 3,
disclosed.** The two split, and the thing that splits them is whether the session ever observes the
result.

**Nothing was routed.** Compose is part 2, and no `ExtPorts` field has a call site outside the two
pre-existing `ai_step` ones.

---

## 1. The git wall-clock window

| | |
|---|---|
| HEAD at session start | `e08bfd5` — `2026-08-07T18:42:01+00:00` |
| first command | `2026-08-07T18:43Z` |
| work window | **~1h25m** |

**Against B2b's ~2h05m for the same shape, this was faster, and the reason is worth recording because
it is not skill.** B2b widened one field and paid for the *first* widening of its kind: it discovered
`derive.py`'s two fail-open parsing traps (nested parens in an argument list, anonymous record return
types) by hitting them. Both are now documented at the exact lines that cause them, and this item
wrote both new closures in the prescribed `let w0` shape **before** running the tool rather than after.
**The precedent was worth roughly forty minutes, and it was spent as documentation rather than
re-derived.**

**About twenty-five minutes of the window went to one confound that had nothing to do with the
mission** — see §7.

## 2. The write/print decision, with its reasoning — the item's durable output

The handoff frames this as a question about D1's boundary sentence:

> Motoko will have one semantic boundary for **external observations that can affect session control
> flow or the ledger** (`ADR:303-304`).

and observes, correctly, that **a file write is not an observation and neither is `println`.** Read
that way both belong outside the world and option 3 takes both. **That reading is right about the
write and wrong about what the write causes**, and the difference is measurable in compose rather than
arguable from the sentence.

### 2.1 The measurement that decides it — `compose.ail:502-521`

```ailang
let _  = mkdirAll("${ctx.workdir}/tmp");
let _  = writeFile(snippet_path, full_source);          -- (1) the write
let checked = check_snippet(snippet_path);              -- (2) exec READS the path
if not checked.ok then {                                -- (3) control flow branches on it
  let _ = if fileExists(snippet_path) then removeFile(snippet_path) else ();  -- (4) reads it back
  ...
} else {
  let ran = run_snippet(snippet_path, caps);            -- (5) exec reads it again
  ...
  if ran.exit_code != 0 then ...                        -- (6) control flow branches again
```

`compose.ail:769-785` repeats the same five-step shape for the module path.

**The write is never observed by a `readFile`. It is observed by a `proc_exec`** — `check_snippet` and
`run_snippet` both shell out to a path that exists only because step (1) put it there — **and by a
`fileExists`.** Steps (3) and (6) are session control flow in D1's literal sense: they decide whether
compose retries, what prior error it feeds back, and what lands in the ledger.

### 2.2 So the argument is not about observations, it is about ONE HOME

D1's prohibition is not only the boundary sentence. It is also:

> The implementation must not hide the program cursor or clock in `SharedMem`, **process-global
> mutation**, an ambient RNG, or a mutable test singleton (`ADR:317-319`) … **exactly one home,
> visibly threaded** (`ADR:340-341`).

A file written to the real filesystem and then read by a **mediated** seam is **a second home for a
fact the world claims to own.** Concretely, if `proc_exec` and `file_read` are world-mediated and
`writeFile` is not, then in a deterministic run:

- step (1) performs a **real, unmediated** filesystem mutation into `${ctx.workdir}/tmp`;
- step (2) asks the **world** what that path contains, and the world's answer has no relationship to
  what step (1) wrote;
- step (4) asks the **world** whether the path exists, and gets an answer the live filesystem
  contradicts.

**That is not a gap in coverage; it is two homes disagreeing, which is the F6 shape this whole project
exists to remove.** It is also why the answer cannot be "writes are emissions, disclose them": a
disclosed emission that a mediated read later observes is not disclosed, it is unmediated input
wearing an output's label.

### 2.3 The decision, stated

**Writes: option 2 — world-mediated, recorded, NOT replayed.**

Precisely what that means, because option 1 and option 2 are one clause apart:

- The world **sees** the write and records it as an interaction, so a recorded run's log is complete.
- The write **updates the world's own file state**, so a subsequent mediated `file_read` or
  `proc_exec` in the same run is consistent with it. *This is the part that discharges §2.2, and it is
  world state, not a performed effect.*
- **Replay does not perform it against the real filesystem.** A deterministic run mutates nothing on
  disk.
- Live runs perform it, because the world has no opinion queued — **the same "data, not a code path"
  arrangement `world_tool` already uses** (`ports.ail:611-617`), so no production code branches on
  test mode and D1's prohibition is not touched.

**`println`: option 3 — out of the world, and disclosed.**

The §2.2 argument **does not carry** to it, and that is the whole reason the two split. Nothing in a
session can observe stdout: there is no read-back, no `fileExists` analogue, no exec that consumes it.
It cannot become a second home for anything because it has no second reader. It is a pure emission to
the operator's console, exactly as D1's boundary sentence says. Three further supports, in decreasing
weight:

1. **The ledger already has an emission channel and this is not it.** WI-C3 gave the run a real
   emission witness — `ProviderExchange.emissions` → `stream_chunk_events` →
   `TracedSessionResult.emissions`. An extension's `println` is not a `StreamChunk` and putting it in
   that channel would mean inventing a second kind of emission to make the parity gate meaningless.
2. **Recording it would put terminal chatter in the interaction log**, where every entry gets a global
   ordinal (`record_interaction`, `ports.ail:651-667`). Ordinals are how replay correlates; spending
   them on prose makes every recorded run's correlation fragile against a changed log line.
3. **`Ports` has no stdout seam**, so an `ExtPorts.print` would front nothing and `derive.py` would
   classify it `unrouted` — a field that looks like mediation and is reported as a bypass.

**Where the disclosure goes:** the same mechanism WI-D15 drafted for registration effects
(`DRAFT-amendment-adr-001-registration-effects.md` §3) — a per-extension profile field naming
`(module, symbol)` pairs, on `HookClassificationEntry`'s basis discipline. compose has **two**
hook-reachable `println` sources, `claimcheck.ail:10` and `author_loop.ail:35`, plus a third at
`compose.ail:109`; both holding modules are inside D15's six.

### 2.4 What this decision COSTS, stated rather than buried

**Option 2 for writes is a new CORE world class, and this item did not build it.** `Ports` has no
`file_write`. Building one means a `WorldState` write table, five or six adapters (scripted, ambient,
world, recording, generating, strict replay), an `IdentityBody` variant, a fault-catalogue row and a
profile row — **which is WI-D3's shape exactly, and WI-D3 was a whole item for the READ half alone.**

**This item deliberately did not add an `ExtPorts.file_write` in advance of it.** A field fronting no
core seam derives `unrouted`, and shipping one would mean the ABI grew a row that looks like mediation
while mediating nothing — the same objection §2.3(3) makes against `ExtPorts.print`. **The core class
has to exist before the extension seam can front it.** That ordering is not a preference; it is what
`derive.py` measures.

**So the decision is taken and half of it is owed.** Named as its own item rather than folded into
part 2, because part 2 is a routing item and this is a world-class item.

## 3. Which field left the classifier-2 set, and every artifact that encodes it

**`proc_exec` left. The set went `{env_get, proc_exec}` → `{env_get}`.**

The criterion, verbatim: *"a field whose call is the extension-side entry to a core seam that D1
requires to thread successor state, **and which cannot return it**"*. `proc_exec` now returns
`ExtProcOutcome`, which carries `next_state`. **The criterion no longer selects it** — the same
transition B2b made for `ai_step` and C5 for `clock_now`, and the seam is unchanged at
`Ports.tool_exec`.

**The pin went red on the widening, which is the pin working:**

```
self-test: 1 failure(s)
  FAIL membership proc_exec: expected member, derived returns-it
```

**Read from the derived membership and not from the exit code**, per B4:

```
proc_exec    returns-it  fronts Ports.tool_exec and ExtPorts.proc_exec's ExtProcOutcome
                         carries next_state -- nothing dropped
file_read    returns-it  fronts Ports.file_read and ExtPorts.file_read's ExtFileRead
                         carries next_state -- nothing dropped
env_get      member      fronts Ports.env_get, whose EnvRead threads next_state;
                         ExtPorts.env_get returns string and cannot carry it
CLASSIFIER-2 SET (1): env_get
```

`returns-it` and not `unrouted` is the load-bearing half: it says the bridge was still followed to a
core seam. `unrouted` is `derive.py`'s fail-open answer and would have looked like a cleaner result.

**Every artifact that encodes the set, and its state:**

| Artifact | Was | Now |
|---|---|---|
| `tools/ext_call_inventory/fixtures/expected.json` | `proc_exec: member/tool_exec` | `returns-it/tool_exec`; `file_read: returns-it/file_read` added |
| `scripts/dst/profile_definition_dst.ail:175` | `["env_get", "proc_exec"]` | `["env_get"]` — re-derived by `check_fixtures.py`, which is what went red |
| `scripts/dst/driver_only_dst.ail:286` | `["env_get", "proc_exec"]` | `["env_get"]` |
| `scripts/dst/driver_plus_no_ops_dst.ail:479` | `["env_get", "proc_exec"]` | `["env_get"]` |
| `src/core/dst_driver_plus_no_ops.ail:714` | `["env_get", "proc_exec"]` | `["env_get"]` |
| `scripts/dst/driver_only_dst.ail:85` (prose) | "the derived set is {env_get, proc_exec}" | updated |
| `packages/motoko-ext-abi/types.ail` | row + its note | superseded in the past tense per S15 |

**EIGHT FIXTURES WERE LEFT ALONE AND THAT IS A PRE-EXISTING FINDING, NOT THIS ITEM'S CHOICE.**
`execution_program`, `discovery`, `corpus_rotating`, `strict_replay`, `seeded_generator`,
`latency_pair` and `corpus_pr` each build a manifest with `["ai_step", "env_get", "proc_exec"]` and
`["clock_now"]`, and `dst_profile.ail:2074` carries the same. **Those sets have been wrong since
WI-B2b and WI-C5** — `ai_step` left at B2b, `clock_now` at C5 — and four items passed over them. They
are pinned at `abi_version: "4.0"` and are structural fixtures for the validator, so leaving them is
consistent with what B2b, C5, D6 and D8 each did. **But nothing guards them**: `check_fixtures.py`'s
re-derivation covers `profile_definition_dst.ail` only, and its `check_abi_version` guard covers four
files that do not include these seven. **A ninth item will find them exactly as stale.**

## 4. `env_get` explicitly not widened, and why

**Widening it is motion without progress, and the measurement is WI-D15's.** compose's one
registration-only ambient source is `register.ail:3 — import std/env (getEnvOr)`. **Registration runs
before the world exists**: `register_with_config` receives no `ExtCtx`, so it has no `ports` field to
call however wide that field's signature gets. **A wider `env_get` would route zero additional
sources** and would cost another ABI row plus eight construction sites.

Symmetry is not a reason, and the three widened rows each had something this one does not: `ai_step`
and `proc_exec` had a **demonstrated drop** (`ProviderExchange.next_state` and
`ToolExecution.next_state`, both read and discarded at the bridge); `clock_now` had a **shape
obstacle** (`() -> int` admits no world capture on the pin). `env_get` has neither on any reachable
caller — the reads that matter are unreachable from any seam.

**What those registration reads need is disclosure, not mediation** — WI-D15's `registration_effects`
field. **That draft is not applied**, so this row's justification currently rests on the measurement
and not on ADR text, and the ABI comment says so rather than implying otherwise.

## 5. Recorded bindings: decided versus discovered

**Discovered — a tool, the compiler or a measurement forced it:**

1. **The classifier-2 self-test could not see a NEW `ExtPorts` field at all.** Its membership loop
   iterates `expected.json`'s block, so adding `file_read` produced **four green pinned rows and total
   silence on the fifth**. The `fixtures` block already closes this with a `missing` check; membership
   had no counterpart. **This is the fail-open shape `derive.py`'s own docstring is written against,
   reappearing one level up in the harness.** Closed with a two-directional REACHABILITY assertion
   (S24: reachability is a separate question from any verdict), and **both directions were
   mutation-tested — dropping `file_read` from the pin and pinning a `http_get` that does not exist
   each produce a named failure, and the pin was restored by `cp`.**
2. **The `ExtPorts` widening reached five `attribution_table` anchors and the fixture coupled to
   them.** The 30 lines added inside `ext_ports_of` pushed `session.ail` 881/1126/1232/2677/2787 to
   911/1160/1266/2711/2821. Re-baselined as **mechanical drift, not a D4 judgement**: each anchored
   expression was compared character-for-character against `git show HEAD:` before and after, and none
   changed identity, routing or attribution. Per D4's precedent this re-issues the profile —
   `driver_only_version` 14 → **15** and `driver_only_attribution_ref.content_hash` re-recorded
   (`ccfc1e34…` → `d3bf3ae5…`), `source_revision` unchanged. **A second, coupled fixture had to move
   with it**: `attribution_table_dst.ail:123`'s completeness fixture names a site that must BE in
   `unconditional_core_sites()` for the third entry to be the only unaccounted one, and leaving it at
   1232 made it fire two rules — *"the completeness fixture fires other rules too — it proves the wrong
   thing"*, which is the target catching itself.

   **And the blast radius was one profile larger than the anchors target reports.** `make anchors`
   and `make attribution_table` both went green with only `driver_only` re-issued; the sweep then
   failed `driver_plus_no_ops` with *"the attribution table was corrected and this profile was not
   re-issued (D4)"*. **`driver_plus_no_ops` binds the same table at the same identity** — the
   two-profile case D4's rule was written for, and its own comment says so — so it went **v1 → v2**
   with the same hash. **The lesson is that `make anchors` is necessary and not sufficient**: it
   checks the anchors, not the set of profiles that recorded the table's hash, and there is now more
   than one. A third profile would extend the list again with nothing naming it in advance.
3. **`Ports` has no directory seam, and that caps the file seam's shape** — see §6.

**Decided — a judgement that could have gone the other way:**

1. **Writes into the world, `println` out of it.** §2. The alternative — both out, on the
   observation reading — is defensible from D1's boundary sentence alone and is what the handoff's
   framing leads to; the compose measurement is what defeats it.
2. **`ExtProcOutcome.output` stays a `string`.** `Ports.tool_exec` returns a four-variant typed
   `ToolOutcome` that the bridge renders down (`tool_outcome_text`). Carrying the discrimination
   through the ABI is a **second widening on a second ground** — D1's part-3 typed-fault argument, not
   state threading — exactly as WI-A2's `next_state` was a second widening of `model_step` beside
   WI-A1's emission log. Doing both in one edit makes it impossible to say which ground moved the pin.
   Faults stay rendered rather than dropped, so nothing is silently lost; what is lost is the ability
   to *match* on them.
3. **`ExtFileRead` copies `FileRead` field for field, including explicit `present`.** compose branches
   on the empty-versus-missing distinction at `config.ail:39`, `author_tools.ail:160-163` and
   `author_tools.ail:250-252`. Inferring absence from `content == ""` would turn an empty config into a
   missing one — one field away from a silent wrong answer at three sites.
4. **The eight stale `"4.0"` fixtures left as they are** — §3, consistent with four prior items, and
   named rather than quietly fixed or quietly ignored.

## 6. What the file seam deliberately does NOT cover

The read side is a **point read** — a path in, existence and contents out — because it fronts
`Ports.file_read` and that seam is narrow by construction. **Copied, not generalised**, as the handoff
required, but the reason is structural rather than obedient:

compose's read side also calls **`listDir`** (`author_tools.ail:192`), **`isDir`** (`:140`, `:190`) and
**`isFile`** (`:141`, `:161`, `:250`). `fileExists`/`isFile` collapse onto `present` for a path the
caller already believes is a file. **`isDir` and `listDir` do not**: a directory listing is not a point
read, and `present && content == ""` cannot tell a directory from an empty file.

**`Ports` HAS NO DIRECTORY SEAM.** An `ExtPorts.list_dir` would front no core seam at all and
`derive.py` would classify it `unrouted`. **Priced for part 2, which is where it will bite** — three of
compose's `author_tools` read sites are not routable by this seam, and that is on top of the write
class §2.4 owes.

## 7. Whether any site admitted two type-checking answers with a silent wrong one

**No — and the near miss ran the other way, which is worth recording because it cost ~25 minutes.**

**70 across forty runs — unchanged**, and this run contributes none: the widening's eight construction sites are
all closed records, so AILANG's *"records are closed — add the field(s)"* error made every missing
`file_read` binding loud. **There was no second type-checking answer available at any of them.**

**What did happen is the inverse failure mode, and it is a genuine finding about the toolchain.**
`long_qwen_compaction_dst.ail` failed with:

```
failed to unify record field 'ports': record field mismatch: expected 5 fields, got 4
  expected fields: {ai_step, clock_now, env_get, file_read, proc_exec}
  actual fields:   {ai_step, clock_now, env_get, proc_exec}
  missing fields:  file_read
    Hint: this record is missing required field(s): file_read
```

**pointing at a record literal that had all five fields, and it named the line I had just correctly
edited.** Two properties made it expensive:

- **`expected` is the LITERAL and `actual` is the ANNOTATION'S type** — the reverse of the natural
  reading of that message and of its `Hint:`, which tells you to add a field that is already there.
  Confirmed by marker probe: renaming a field in the literal changed the *expected* set and left
  *actual* fixed.
- **The stale type was NOT in the ABI's own cache.** Each directory carries its own
  `.ailang/cache/compile/modules/`, and the 4-field `ExtPorts` reached this module **structurally
  embedded inside `compaction_ai`'s cached interface**. Deleting the ABI's cache entry in every
  directory (24 of 29 were stale) did not fix it; only a sweep of the dependents' caches did.

**A session that trusted the message would have edited correct source.** It fails loud rather than
silent, so it is not one of the 71 — but the message's subject is wrong, and the fix is in a directory
the message never mentions. Filed as the item's one toolchain finding; **the standing instruction to
sweep cache-cold (S9/S17) is what resolved it, and it should be read as covering the DEPENDENTS of an
edited interface, not just the edited module.**

## 8. The ABI changed-row count, and whether anything now forces the major

**TEN rows now, up from eight, and this item moved two of them.**

| | |
|---|---|
| B1, B2a, B2b, C5 | 4 |
| D6 (`on_budget_plan`) | 5 |
| D7 (`on_response_intercept`, `on_solver_candidate`) | 7 |
| D8 (`ExtPorts.ai_step`, `ExtensionHooks.on_pre_step` — two rows moving a second time) | 8 |
| **D16 — `ExtPorts.proc_exec` CHANGED** | **9** |
| **D16 — `ExtPorts.file_read` ADDED** | **10** |

Plus **two added types**, `ExtProcOutcome` and `ExtFileRead`, on D6's convention of counting added
types separately (it recorded "five changed rows and one added type").

**`proc_exec` is the ninth row and the first to move for the first time since D7** — the four before it
were re-moves. **`file_read` is the first ADDED field in the tally**; every prior row was a change to
an existing one, so "changed rows" now covers two kinds and the breakdown is given rather than left to
be guessed.

**Nothing forces the major and this item did not cut it**, for D6's, D7's, D8's and D14's reason
unchanged: **cutting it is a release act.** `packages/motoko-ext-abi/ailang.toml` still declares 5.0
and `check_fixtures.check_abi_version` re-derives that against six manifest sites across four files.

**C5's trap was checked and did not fire**: `git diff` over `*ailang.toml` is empty. `ailang.lock`
moved — content hashes re-recorded by the normal build, exactly as D8 described — and no version
did.

## 9. The sweep

`make sync_packages` first (**thirteenth consecutive item**), then `AILANG_RELAX_MODULES=1 make dst`
**cache-cold** — every repo-local `.ailang/cache/compile` outside the vendored `ailang/` checkout
removed, which §7 turned out to require rather than merely prefer.

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, and nothing else** — identical to the
inherited baseline at D14 and D15, and unrelated to this item (`prompts_test.ail` 0/6 on *"Named test
blocks not yet implemented"*).

**It took three sweeps and the two intermediate ones are the interesting part**, because each red was
a guard catching this item rather than a flake:

| Sweep | New red | What it was |
|---|---|---|
| 1 | `anchors` / `attribution_table` | the five `session.ail` anchors, pushed down by the widening |
| 2 | `driver_plus_no_ops` | the SECOND profile binding the same table — `make anchors` cannot see it |
| 3 | — | inherited two only |

**The yields did not move, and that is the expected answer rather than a disappointment**: classifier 3
closure **4 of 15**, hook scope **5 of 15**, both identical to WI-D15. **Nothing was routed, so nothing
could clear.** A yield that moved on an item that added no call site would have meant the instrument
was reading the ABI's shape instead of an extension's behaviour.

Selftest evidence, read as membership rather than as an exit code:

```
  ok  membership proc_exec    returns-it  seam=Ports.tool_exec
  ok  membership file_read    returns-it  seam=Ports.file_read
  ok  membership env_get      member      seam=Ports.env_get
  ok  reachability      5 ExtPorts field(s) derived, 5 pinned, sets identical
```

## 10. What this item did NOT do

- **Routed nothing.** Zero `ExtPorts` call sites were added; the only two in the tree are the
  pre-existing `ai_step` ones in `compaction_ai.ail:111` and `reject_fixtures.ail:107`. `file_read`
  and the widened `proc_exec` have **no callers at all** — the "first exercise of a seam with no
  callers" state D3 hit with `clock_now`, reported rather than presented as coverage.
- **Did not build the write class** — §2.4. The decision is taken; the core `Ports.file_write` world
  class is its own item.
- **Did not add a directory seam** — §6.
- **Did not promote the hook-scope verdict**, remove now-unused imports, touch door 3's producer, or
  cut the release.

## 11. What the next item should know

1. **Part 2 is blocked on more than it looks.** Routing compose needs the write class (§2.4) **and** a
   directory seam (§6) **and** door 3's producer. Route B part 1 shipped the surface for
   `proc_exec` and the file read side; **it did not ship a surface sufficient for compose's six
   modules**, and D15's "≥23 hook-reachable sources" is still a lower bound.
2. **The eight stale `"4.0"` manifest fixtures** (§3) are unguarded and three items stale.
3. **`check_abi_version`'s subject list covers four files.** It found D14's defect in the one artifact
   class nothing was pointed at; seven more manifest-building files are still in that state.
