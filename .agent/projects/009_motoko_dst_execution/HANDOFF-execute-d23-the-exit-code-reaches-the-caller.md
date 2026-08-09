# Handoff: WI-D23 — the typed exit code reaches the caller

Audience: a fresh session grounded against HEAD. **The build WI-D21 drafted and stopped, resumed now
that WI-D22 removed the stop.** D21 priced the discrimination at seven links and stopped at link 6
(the persisted codec, which needed a schema bump); D22 shipped the bump. What remains is the three
links on the live side — and one link nobody numbered.

**Read first:** `NOTE-d21-…` §3 (the seven links) and §5 (the identity-class decision), then
`NOTE-d22-…` §11 (which names this item and its remaining obstacle).

## Where the seven links stand at HEAD — every row re-measured, not inherited

| # | Link | State at HEAD |
|---|---|---|
| 1 | `ExtProcOutcome` +`exit_code` | **OPEN.** `types.ail:180` is `{ output, next_state }` |
| 2 | `ToolCompleted` +`exit_code` | **SHIPPED (D22).** `ports.ail:513` |
| 3 | `world_tool` derives the code on both arms | **HALF-OPEN.** Scripted arm carries `t.exit_code` (`ports.ail:1367`); live arm stamps `-1` with the reason at the site (`ports.ail:1336-1350`) |
| 4 | `dispatch_one`'s `(workdir, ToolCall) -> string` contract | **OPEN, and it is the blocking link now.** `tool_dispatch_adapter.ail:174` |
| 5 | `ScriptedTool` +`exit_code` | **SHIPPED (D22).** `ports.ail:464-470` |
| 6 | the persisted codec | **SHIPPED (D22).** Encode unconditional (`ports.ail:2087`), decode by presence with S32 refusal (`:2139-2141`) |
| 7 | `dst_replay.tools_of` | **SHIPPED (D22), by construction** — `tools_of` (`dst_replay.ail:710`) goes through `decode_tool_outcome`, so it inherited the field with the codec |

**And the link D21's table did not number: the ABI bridge itself.** `session.ail`'s `proc_exec`
closure (`:975-984`) projects the outcome through `tool_outcome_text` (`session.ail:819`), whose
`ToolCompleted` arm is `c.content` — **it drops the `exit_code` D22 added.** At HEAD the typed field
travels from the script through `world_tool` and dies one seam short of the only caller the seam
exists for. Link 1 without this projection is a field the bridge never fills.

## The shape of the fix, measured end to end

**Link 4.** `dispatch_one` exists in its string shape to satisfy upstream `runTools` — that contract
must not move. But its own body already holds the typed value: `run_native_batch` returns
`[ToolResultItem]`, and the string is `encode(tool_result_item_to_json(r))`. **Give it a typed
sibling** (say `dispatch_one_typed -> { content: string, exit_code: int }`, or return the
`ToolResultItem` and project at the caller) **and make `dispatch_one` a projection of the sibling**,
so the two cannot disagree. The defensive zero-or-many arm (`:179-182`) is an error surface: its
sibling form needs a non-success code, not `0`.

**Link 3.** `world_tool`'s live arm (`ports.ail:1347-1350`) binds the sibling's two fields where it
now writes `content: dispatch_one(…)` and `exit_code: -1`. The site's own comment already states
why `0` there would be S30's failure in its purest form; that comment then needs re-tensing, because
its "OUT OF THIS ITEM'S SCOPE" clause is this item.

**Link 1.** `ExtProcOutcome` gains `exit_code: int` with `ScriptedTool.exit_code`'s domain (`-1` =
"no subprocess, or a seam that cannot say"; see `ports.ail:424`). **The construction census at HEAD
is SEVEN sites, not the four D21's link table priced** — derived by grep over `output:` constructions
returning `ExtProcOutcome`, and per S22 the item must re-derive it rather than trust this list:

- `src/core/session.ail:984` — the bridge (the one that changes meaningfully)
- `src/core/ext/ctx_defaults.ail:17`
- `packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:154`
- `packages/motoko_ext_conformance/harness.ail:50`
- `packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail:70`
- `scripts/dst/declared_vs_performed.ail:162` — the probe
- `scripts/dst/long_qwen_compaction_dst.ail:250`

The six noops write `exit_code: -1` — a no-op executes nothing, and `-1` is exactly the "no
subprocess" value. Writing `0` in a noop asserts a success no process produced.

**The bridge.** A second projection beside `tool_outcome_text` — `ToolCompleted(c) => c.exit_code`,
the other three variants `-1`. Do not fold it into `tool_outcome_text`; the string rendering is the
model-facing message and is unchanged.

## Two facts that must keep one home

**The per-variant mapping.** Which `ToolResultItem` variant carries which exit code currently lives
in exactly one place: `tool_result_item_to_json` (`tool_dispatch_adapter.ail:66-131` — four literal
`0.0`s at `:75/:82/:91/:104`, the real field at `:110/:118`, a literal `1.0` at `:128`). A typed
sibling is a **second consumer of that mapping** — S23's threshold. Either the JSON encoding and the
typed path read one accessor, or an assertion holds them equal. Two independent statements of
"`ToolErrorResult` is 1" is how they drift.

**The content/field pair in artifacts.** After this item, a recorded `BashExec` interaction carries
the exit code twice: typed in `ScriptedTool.exit_code`, and as text inside the content JSON. In
recorded runs both derive from one `ToolResultItem`, so they agree by construction; **a hand-written
artifact can make them disagree**, and nothing at HEAD compares them. Decide the authority and write
it at the codec (`ports.ail:1954` region). The honest answer is probably that the typed field is
authoritative and content is an opaque rendering — but do not resolve the divergence by parsing
content's JSON in a validator; recovering typed facts from that string is the defect this whole item
exists to remove. If you find yourself writing that parser, stop and report.

## The row that matters is the live one

Every in-process fixture can be green while the live arm still stamps `-1` — the scripted arm
already works and the fixtures exercise it. **The mutant to beat: revert the live arm's binding to
`exit_code: -1` after the sibling exists.** Only a row that drives a real subprocess to a chosen
exit code can see it. Two subjects, per S14:

1. **The live arm**: a real `BashExec` through `world_tool`'s `[]` arm (or `dispatch_one_typed`
   directly) running a command that exits **7**, asserting the typed field is `7` — not `-1`, not
   `0`, not `1`.
2. **The adoption**: `ext_ports_of`'s own `proc_exec` closure — not a substrate probe — against a
   scripted world whose `ScriptedTool` carries exit code **5**, asserting `ExtProcOutcome.exit_code`
   is `5`. This is the row that catches the bridge projection being dropped or wired to the wrong
   variant.

Per S7, keep the quantities pairwise distinct and distinct from the values already in the suite:
`-1`, `0`, `1` are semantically loaded and `137` is taken by D22's round-trip row. `5` and `7` are
free. A third row worth its cost: the sibling and `dispatch_one` on the same call produce content
that is byte-identical (the projection claim, asserted rather than described).

## What this item does NOT do, and the sequencing fact behind it

**It routes nothing.** Compose's `std/process.exec` remains ambient at three import sites carrying
four call sites (`compose.ail:277`, `:292` — which already branch on `out.exitCode` and are the
consumers this discrimination is for — plus `author_tools.ail:430` and `authoring/dispatcher.ail:244`;
the inventory's "three exec" counts import sites, the producer's unit).

The reason is an S27 interaction, and it is load-bearing: `recording_tool` (`ports.ail:1619`)
records every `tool_exec` invocation as `ToolIdentity("loop_v2", inv.call.id, inv.call.tool)`
(`:1626`), and the bridge sets `call.id = ""` — so **the first `proc_exec` call in a recorded run
emits a program the validator rejects** (`IdentityComponentMissing`, asserted at
`dst_program.ail:697` since D21). Typing the exit code does not touch that. **Routing compose's
`exec` sites is therefore blocked on the eighth recording adapter and `ExtCtx.ext_id`** (D21 §5, the
next item's work), not on anything in this one. This consequence is conditional on the recording
adapter's identity construction staying as it is; if that changes first, re-derive.

The yields (4 of 15, 5 of 15) and the ambient inventory (compose 11 sources, 32 field calls)
**must not move** — assert that they did not, since this item adds no seam and routes no caller.

## Reasons that expired when D22 landed — re-tense them, two-part per S15

1. **`types.ail:170-179`** — the ABI row's "WHICH IS WHY THE SECOND WIDENING IS STILL NOT TAKEN
   HERE… That requires a `program_schema_version` bump." The bump shipped; this paragraph's reason
   is gone and this item takes the widening. Restate as was/is; the adjacent measurement paragraph
   (`:161-169`) is still exactly right.
2. **`ports.ail:1336-1349`** — the live arm's "WI-D21 named this as link 4 and it is OUT OF THIS
   ITEM'S SCOPE."
3. **`src/core/ext/ctx_defaults.ail:16`** — still `(_cmd, _cwd)`: **a sixth binding D21's rename
   census missed** (its five were the bridge, three packages, and the ABI row). Same for the probe
   at `declared_vs_performed.ail:162` (`_cmd, _args`) and `long_qwen_compaction_dst.ail:250`
   (`_name, _args`). Parameter-name-only edits; the three packages' comment block is the template.

## The ABI question, answered by precedent rather than reopened

Adding `exit_code` to `ExtProcOutcome` breaks in-tree constructions (records are closed) and is
invisible to extensions that only read the record — which in production is all of them, since the
harness constructs it. D16/D17/D18 added whole `ExtPorts` fields under `5.0` on exactly this
reasoning, updating in-tree noops in the same commit. **Follow the precedent: stay `5.0`.** This is
categorically unlike the `proc_exec` rename (unconstructable at `register_with_config`, forces
`6.0`, stays deferred). If review of `ailang.toml` policy says otherwise, that is a stop-and-report,
not a judgement call.

## The anchor cascade will fire, and it is priced

The bridge edit adds lines inside `ext_ports_of`, above all five `session.ail` anchors
(`tools/predicate-anchors/anchors.sh`; D21's law — any edit to `ext_ports_of` re-baselines). Budget
the re-baseline and re-issue **both** profiles: `driver_only` 19 → 20, `driver_plus_no_ops` 6 → 7.
This item does not touch `tool_phase.ail`, so the cascade is the six-file `session.ail`-only form,
not the nine-file form (D21 §11.1). Per S18, finish every comment re-tensing **before** computing
anchors.

## Definition of done

1. `ailang check` clean; `make sync_packages` re-run **after** the `types.ail` edit (D22's process
   rule: a stale `ailang.lock` produces a false "field not found" against a correct source line).
2. Green: `execution_program`, `program_persistence`, `world_state`, `discovery`,
   `declared_vs_performed`, `conformance`, `anchors`, `predicate_anchors`, `attribution_table`.
3. The live-arm row (exit 7), the adoption row (exit 5), and the projection-agreement row exist and
   are red under their named mutants: live arm reverted to `-1`; sibling hardwired to `0`; bridge
   projection dropped. Restore by file copy per S17.
4. `ext_ambient_inventory` unchanged: compose 11 sources, 32 field calls; yields unmoved.
5. Both profiles re-issued if (when) the cascade fires; `make dst` sweep with no tracked file
   touched while it runs.
6. Counters: this closes the gap the fault catalogue's coverage-gap entry has named since C5
   (*"an extension can observe that a tool failed and not which fault class it was"* — the entry at
   `dst_fault_catalogue` :442 region should be re-tensed if its claim no longer holds). Count
   nothing into silent-wrong for defects authored and closed in this item.

## Out of scope

- Routing compose's `exec` sites (blocked on the identity work, above).
- The eighth recording adapter, `ExtCtx.ext_id`, `absent_classes` — untouched, D21 §5's plan.
- The `proc_exec` rename (`6.0`, release decision).
- The bridge's hardcoded `workdir: "."` and `timeout_ms: 0` (D21 §8: the seam cannot produce
  `ToolDeadlineExceeded`) — a real gap, named, not this item.
- `on_pre_step` / `on_solver_candidate` audits; C5's compose-bearing profile.

## Stop and report rather than deciding inline

- If the typed sibling cannot exist without changing `dispatch_one`'s signature or behaviour as seen
  by upstream `runTools`.
- If keeping the per-variant mapping in one home forces a restructuring of
  `tool_result_item_to_json` larger than an accessor extraction.
- If the content/field authority question turns out to need a content parser (see above).
- If anything forces a `6.0` or another schema version move.

## Report back

`NOTE-d23-…` in the established form: what shipped per link, the construction census as executed
(against this handoff's seven), each mutant and its named row, what the cascade cost, what was
re-tensed, and what the next item (the identity work) inherits. State explicitly whether the
adoption row drove the closure (S14's two subjects), and whether any seam needed changing on contact
— four items built this surface on measurements taken with no caller at all, and this is the item
that finally supplies one.
