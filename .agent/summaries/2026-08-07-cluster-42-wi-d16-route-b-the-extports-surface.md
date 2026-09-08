# 2026-08-07 Cluster 42: WI-D16 — Route B part 1, the `ExtPorts` effect surface

## Context

Branch: `arniwesth/mot-77-wi-d15-does-criterion-2-quantify-over-hooks-or-over`.

Session span: `e08bfd5` → **`5488e7d`** (`51295ec` docs-apply, then `5488e7d`). Input was
`HANDOFF-execute-d16-route-b-the-extports-surface.md`, grounded against HEAD `e08bfd5`
(`2026-08-07T18:42:01Z`). Pin **v0.33.0**. First command `18:43Z`, **~1h25m**.

**The first Route B BUILD item after nine consecutive reports naming and deferring it.** Twenty-one
files, **874 insertions / 67 deletions**, of which **413** are the record and **63** are plan
corrections extending three rules.

```text
packages/motoko-ext-abi/types.ail       122 +-   proc_exec widened, file_read added, 2 new types
src/core/session.ail                     62 +-   the two bridge closures
tools/ext_call_inventory/fixtures/…json  50 +-   the pin, moved deliberately
tools/ext_call_inventory/derive.py       34 +    the reachability assertion (S24)
8 × ExtPorts construction sites          ~90 +-  closed records, every one loud
5 × attribution/profile artifacts        ~60 +-  the D4 cascade, two profiles re-issued

NEW  .agent/.../NOTE-d16-route-b-the-extports-surface.md   413   the record
     .agent/.../PLAN-implementation-…-world.md              63   S24, S22/anchors, S9 extended
```

| Definition-of-done item | State |
|---|---|
| `proc_exec` world-threading on `AiStepOutcome`/`ExtClockReading`'s shape | **met** — `ExtProcOutcome`, a record per P1 |
| A file seam on `ExtPorts`, read side copying `Ports.file_read`'s point read | **met** — `ExtFileRead`, copied not generalised |
| The write/print decision taken and recorded with its reasoning | **met** — and it split; §"The decision" |
| The classifier-2 pin moved deliberately, membership read not exit code | **met** — `returns-it`, not the fail-open `unrouted` |
| `env_get` explicitly not widened, with the reason | **met** — on the row, from D15's measurement |
| Nothing routed | **met** — zero new call sites tree-wide |
| Per S24, assert reachability separately from verdict | **met** — and it found a live fail-open hole |
| Per S13/S9/S17, `make dst`, cache-cold, `sync_packages` first | **met** — **thirteenth** consecutive |
| Expect the ABI major to move; state the count; do not cut it | **met** — 8 → **10**; not cut |
| Stop-and-report: the decision needs an ADR reading | **did not fire** — D1's own text plus a measurement settles it |
| Stop-and-report: widening forces production test-mode branching | **did not fire** — `world_tool`'s data-not-code-path shape holds |
| Stop-and-report: the file seam forces a change to `ai_step`/`clock_now` | **did not fire** — both untouched |

---

## The decision — the item's durable output, and the handoff's framing was the wrong question

The handoff frames it on D1's boundary sentence — *"external **observations** that can affect session
control flow or the ledger"* (`ADR:303-304`) — and observes that **a file write is not an observation
and neither is `println`.** True, and it leads to option 3 for both. **It is the wrong question.**

**`compose.ail:502-521` is what decides it**, measured rather than argued:

```ailang
let _ = writeFile(snippet_path, full_source);   -- (1) the write
let checked = check_snippet(snippet_path);      -- (2) exec SHELLS OUT to that path
if not checked.ok then {                        -- (3) control flow branches
  let _ = if fileExists(snippet_path) then removeFile(snippet_path) else ();  -- (4) reads it back
} else {
  let ran = run_snippet(snippet_path, caps);    -- (5) exec reads it again
  if ran.exit_code != 0 then …                  -- (6) control flow branches again
```

`compose.ail:769-785` repeats the shape. **The write is never observed by a `readFile` — it is
observed by a `proc_exec` and a `fileExists`, both of which are the seams already being mediated**, and
session control flow branches on the result twice.

**So the governing text is not the boundary sentence but the one-home rule** (`ADR:317-319`,
`ADR:340-341`). A mediated read plus an unmediated write is **two homes for one fact**: the write
mutates the real filesystem, and the world then answers a question about a path it does not know
exists. That is F6's shape. And it is why "writes are emissions, disclose them" fails — *a disclosed
emission that a mediated read later observes is not disclosed; it is unmediated input wearing an
output's label.*

| | Verdict | Why |
|---|---|---|
| **File writes** | **Option 2** — world-mediated, recorded, **not replayed** | the one-home argument above; live runs perform because the world has no opinion queued, which is `world_tool`'s existing data-not-a-code-path shape, so D1's test-mode prohibition is untouched |
| **`println`** | **Option 3** — out of the world, **disclosed** | the argument does not carry: nothing can observe stdout, so it cannot be a second home. Supported by C3's emission witness already owning that channel, by ordinal churn in the interaction log, and by `Ports` having no stdout seam |

**Half of the write decision is owed and named as such.** Option 2 needs a core `Ports.file_write`
world class — `WorldState` table, five or six adapters, an `IdentityBody` variant, catalogue and
profile rows. **That is WI-D3's shape, and D3 was a whole item for the READ half alone.** No dangling
`ExtPorts.file_write` was shipped in advance: a field fronting no core seam derives `unrouted` —
mediation-shaped, mediating nothing. **The core class must exist before the extension seam can front
it**, which is what `derive.py` measures rather than a preference.

## The pin moved, and it is the point rather than a cost

**`proc_exec` LEFT the set: `{env_get, proc_exec}` → `{env_get}`.** The criterion selects a field
*because it cannot return successor state*; `ExtProcOutcome` carries `next_state`, so it no longer
selects it — B2b's transition for `ai_step` and C5's for `clock_now`, repeated.

```text
FAIL membership proc_exec: expected member, derived returns-it     ← the pin working
…
proc_exec  returns-it  fronts Ports.tool_exec …  nothing dropped   ← read as membership, per B4
file_read  returns-it  fronts Ports.file_read …  nothing dropped
env_get    member      … cannot carry it
CLASSIFIER-2 SET (1): env_get
```

`returns-it` and not `unrouted` is the load-bearing half — `unrouted` is the fail-open answer and
would have looked cleaner. **Seven artifacts encode the set; all seven moved.**

**`env_get` deliberately not widened.** Its problematic callers are in `register_with_config`, which
runs before the world exists and receives no `ExtCtx`, so a wider seam routes **zero** additional
sources. Symmetry is not a reason: the three widened rows each had a demonstrated drop or a shape
obstacle; this one has neither on any reachable caller.

**Eight fixtures carry `["ai_step", "env_get", "proc_exec"]` and were left alone** — stale since B2b
and C5, `"4.0"`-pinned, structural, and consistent with what four prior items did. **Nothing guards
them**: `check_fixtures.py` re-derives one file and `check_abi_version` covers four. A ninth item will
find them identically stale.

## Three rules extended, each earned by a live failure in this item

- **S24 — a pin that iterates itself cannot report an absence.** The membership selftest loops over
  `expected.json`'s block, so **adding `file_read` produced four green pinned rows and total silence on
  the fifth.** The `fixtures` block already had a `missing` check; membership had no counterpart —
  `derive.py`'s own documented fail-open shape, reappearing in the harness that guards it. Closed with
  a two-directional reachability assertion; **both directions mutation-tested** and the pin restored by
  `cp`.
- **S22/anchors — `make anchors` is necessary and not sufficient.** It checks the anchors, not the set
  of profiles that recorded the table's hash. Five `session.ail` anchors drifted (881/1126/1232/2677/
  2787 → 911/1160/1266/2711/2821, expressions verified character-identical against `git show HEAD:`);
  `anchors` and `attribution_table` both went green with `driver_only` re-issued **14 → 15**, and the
  sweep then failed `driver_plus_no_ops` — **v1 → v2**. A coupled fixture had to move too
  (`attribution_table_dst.ail:123`), caught by the target's own *"the completeness fixture fires other
  rules too — it proves the wrong thing"*.
- **S9 — the sweep must cover the DEPENDENTS of an edited interface.** ~25 minutes lost to a
  record-field error wrong in two ways at once: *"expected 5 fields, got 4 … missing: file_read"*
  pointing at a literal that had all five, because **`expected` is the LITERAL and `actual` is the
  ANNOTATION** (the reverse of the natural reading, and its `Hint:` says to add a field already there);
  and the stale 4-field `ExtPorts` was **embedded structurally inside `compaction_ai`'s cached
  interface**, so clearing the ABI's own cache in all 29 directories did not fix it. It fails loud, but
  its subject is wrong and the fix is in a directory it never mentions.

## Whether any site admitted two type-checking answers with a silent wrong one

**NO. The count stays at 70 across forty runs.** The eight `ExtPorts` construction sites are all closed
records, so AILANG's *"records are closed — add the field(s)"* made every missing binding loud;
**there was no second answer available at any of them.** The §S9 confound above is the inverse failure
mode — loud with a wrong subject — and is recorded as a toolchain finding rather than counted here.

## The ABI

**TEN rows, up from eight** — `proc_exec` CHANGED (9th, the first row to move for the first time since
D7; the four before were re-moves) and `file_read` ADDED (10th, **the first added field in the
tally**), plus two new types on D6's convention. **Nothing forces the major and it was not cut**, for
D6/D7/D8/D14's reason unchanged: cutting it is a release act. `ailang.toml` still declares 5.0 across
six sites in four files. **C5's trap checked and did not fire** — `git diff` over `*ailang.toml` empty;
only `ailang.lock` moved, content hashes re-recorded by the normal build.

## Gate and sweep

`make sync_packages` (**thirteenth** consecutive), then `AILANG_RELAX_MODULES=1 make dst` **cache-cold**
— every repo-local `.ailang/cache/compile` outside the vendored `ailang/` checkout removed, which the
S9 finding turned out to require rather than merely prefer.

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, nothing else** — identical to D5, D10,
D11, D12, D13, D14, D15; pre-existing since B2a. **914 ✓ rows in 4 687 lines** (D15: 914 in 4 684).

**Three sweeps, and the two intermediate reds are the interesting part** — each a guard catching this
item, not a flake: sweep 1 → `anchors`/`attribution_table`; sweep 2 → `driver_plus_no_ops`; sweep 3 →
inherited two only.

**Yields did not move: closure 4 of 15, hook scope 5 of 15, both identical to D15.** That is the
expected answer — nothing was routed, so nothing could clear, and a yield that moved on an item adding
no call site would have meant the instrument was reading the ABI's shape instead of an extension's
behaviour.

## Recorded bindings

**Decided:** writes in, `println` out; `ExtProcOutcome.output` stays a `string` (typing the four-variant
fault surface is a **second widening on a second ground** — D1's part-3 argument, not state threading —
and doing both at once makes it impossible to say which moved the pin); `ExtFileRead` copies `FileRead`
field for field including explicit `present` (compose branches on empty-versus-missing at three sites);
the eight stale `"4.0"` fixtures left and named; no `ExtPorts.file_write` or `.print` shipped ahead of a
core seam.

**Discovered:** the membership pin could not see a new field; the D4 cascade has two consumers and
`make anchors` names one; a dependent's cached interface carries the stale type; `Ports` has **no
directory seam**, so `isDir`/`listDir` are unroutable and three `author_tools` read sites are not
covered by this seam.

## Owed

**The core `Ports.file_write` world class** — new, and the decision's other half. **A directory seam** —
new, and part 2 needs it. **Part 2 itself is blocked on more than it looked**: routing compose needs the
write class *and* the directory seam *and* door 3's producer, and D15's "≥23 hook-reachable sources"
remains a lower bound. The eight unguarded `"4.0"` fixtures. `check_abi_version`'s subject list, which
covers four of eleven manifest-building files. Unchanged from D15: door 3's producer, the drafted
`registration_effects` amendment's disposition, promoting the hook-scope verdict, the full eleven-row
table, criterion 1's basis, classifier 1, the stdlib-adjacent cache's 52-file producer, the gate-table
State column, F3, the fourteen `register_with_config` rows — and the `motoko-ext-abi` major, now at
**ten** rows.
