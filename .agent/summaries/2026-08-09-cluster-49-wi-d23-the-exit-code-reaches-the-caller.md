# 2026-08-09 Cluster 49: WI-D23 — the typed exit code reaches the caller

## Context

Branch: `arniwesth/mot-85-wi-d23-the-typed-exit-code-reaches-the-caller`.

Session span: `338156c` → **`e42b5c1`**. Input was
`HANDOFF-execute-d23-the-exit-code-reaches-the-caller.md`, grounded against HEAD `338156c`
(`2026-08-09T08:39:56Z`). Pin **v0.33.0**. Closing commit `e42b5c1` at `09:21:52Z`, **~42m** —
the shortest of the D19–D23 run, and the reason is recorded in the NOTE: every one of the
handoff's re-measured claims survived re-derivation, so the time went to building rather than
correcting.

**The build WI-D21 drafted and stopped, finished.** 22 files, **666 insertions / 117 deletions**:

```text
.agent/.../NOTE-d23-the-exit-code-reaches-the-caller.md  269 +  the record
src/core/tool_dispatch_adapter.ail                       104 +- tool_result_exit_code (the one home),
                                                                dispatch_one_typed, dispatch_one → projection
scripts/dst/world_state_probe.ail                         80 +- the exit_code_witness entry: three rows
src/core/ports.ail                                        67 +- the live arm binds both sibling fields,
                                                                the codec authority statement, S15 re-tenses
src/core/session.ail                                      61 +- tool_outcome_exit_code, the bridge's third
                                                                field, ext_ports_of exported, S15 re-tenses
packages/motoko-ext-abi/types.ail                         36 +- ExtProcOutcome.exit_code at 5.0, the expired
                                                                "second widening" paragraph re-tensed
compose.ail / author_tools.ail                            49 +- the two D19/D21 notes re-tensed: typing is
                                                                closed, IDENTITY is the named blocker
the anchor cascade (6 files)                              56 +- five anchors +35, driver_only 19→20, no_ops
                                                                6→7, hash re-derived by running it
the census tail (4 files)                                 22 +- six noops write -1; three straggler
                                                                parameter renames (ctx_defaults + 2 probes)
```

## What shipped

The four remaining links of D21's seven-link chain, on D22's schema bump:

1. **Link 4** — `dispatch_one_typed -> { content, exit_code }`; `dispatch_one` is its one-line
   projection, so the string a model reads and the code a caller branches on cannot come from
   different dispatches. The per-variant mapping (S23's second consumer) lives once, in
   `tool_result_exit_code`, read by both the JSON encoder and the typed path. The defensive
   zero-or-many arm carries **1** — the error mapping's code, not 0 and not -1.
2. **Link 3** — `world_tool`'s live arm binds both of the sibling's fields.
3. **Link 1** — `ExtProcOutcome.exit_code` at **ABI 5.0** per the D16–D18 additive precedent;
   seven construction sites (census re-derived per S22, matched the handoff exactly); the six
   noops write **-1** with the reason at each site.
4. **The unnumbered link** — `tool_outcome_exit_code` beside `tool_outcome_text`, deliberately
   not folded in; `ToolCompleted => c.exit_code`, the three fault variants **-1**. Content/field
   authority decided at the codec: the typed field is authoritative, `content` is an opaque
   rendering, and no validator parses it.

## The witness and the mutants

Three rows in `world_state_probe`'s new `exit_code_witness` entry (`make world_state`, full
caps): live arm exit **7**, adoption exit **5** through the real `ext_ports_of`, projection
agreement at exit **3**. Three mutants, each killed exactly its named row, restored by file copy
per S17 and verified byte-identical. **The adoption row drove the closure per S14** — it is the
only row that can see the bridge, and it went red only under the dropped-projection mutant.

## The four findings worth carrying

1. **First contact cost one `export` and zero shape changes.** Four items built this seam with
   no caller; its first caller worked on the first run. `ext_ports_of` is now exported so tests
   can reach the real bridge instead of a substrate probe.
2. **The fault-catalogue gap is NARROWED, not closed** — the handoff said this item closes the
   entry C5 wrote; measured, only the exit-code half closed. Which *fault class* a non-completed
   outcome was still crosses the ABI as rendered text. The entry now says "NARROWED A THIRD
   TIME" and states the residue precisely.
3. **`ailang test` grants no capabilities and has no `--caps` flag** (its own error hint
   suggests one) — and `world_state_probe.main` must keep completing with Process withheld. Both
   facts forced the witness into its own `ailang run` entry point; any future effect-performing
   row has the same constraint.
4. **The anchor cascade fired exactly as priced**: +35 on all five session.ail anchors,
   byte-identical expressions, the six-file session.ail-only form, both profiles re-issued with
   the hash derived by running `table_content_hash()` rather than transcribed.

## Counters and sweep

Silent-wrong **75 unchanged** (forty-five runs) — the three straggler renames are instances of
the site D21 already counted. Instrument-weaker-than-its-claim **7 unchanged**. Yields and
ambient inventory asserted unmoved: 4/15, 5/15, compose 11 sources / 32 field calls. `make dst`
red only on `test_coverage`/`test_coverage_selftest`, byte-identical to the failures D22
stash-confirmed at its HEAD; nothing names a file this item touched.

## Post-commit

`make run` was reported failing and could not be reproduced at `e42b5c1` — build clean, TUI
reaches its prompt, and a headless task completes end-to-end against the live model (the run
that produced `session_2026-08-09T09-32-36-435Z.jsonl`). Reporter confirmed it was a temporary
error. One real residue from that check: the committed `ailang.lock` was stale for
`motoko_core` — the anchor-cascade edits to `src/core/dst_*` landed after the last
`sync_packages` — re-synced and committed with this summary. D22's process rule ("sync after any
edit a package can see") has now bitten in its third distinct form.

## What the next item (the identity work) inherits

The typed surface is complete end to end with witnesses at every joint; routing a compose `exec`
site now needs no type work, only identity — the eighth recording adapter and `ExtCtx.ext_id`
(D21 §5). The `absent_classes` pin is untouched. The rg byte-stdout shape residue and the
bridge's `workdir: "."` / `timeout_ms: 0` constants remain, named at their sites.
