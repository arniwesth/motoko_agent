# 2026-08-09 Cluster 52: WI-D26 — routing compose's `exec` sites

## Context

Branch: `arniwesth/mot-88-wi-d26-route-composes-exec-sites`.

Session span: `560322c` → **working tree, uncommitted**. Input was
`HANDOFF-execute-d26-route-composes-exec-sites.md`, grounded against HEAD `560322c`
(`2026-08-09T14:09:11Z`). Pin **v0.33.0**. Work complete at ~`15:35Z`, **~1h25m**.

**Item 4 of the goal line's six-item critical path — the change every item since D16 has been
preparing.** Compose's last hook-reachable ambient effects now go through the world. 11 files,
**1783 insertions / 233 deletions** (three are new files, 918 lines):

```text
.agent/.../NOTE-d26-route-composes-exec-sites.md        554 +  the record (new)
scripts/dst/discovery_dst.ail                           431 +- two compose scenarios: the check path
                                                               served from ext_effects, and the quiet
                                                               ripgrep row
packages/motoko-ext-compose/proc.ail                    199 +  the argv encoder + stream decoder,
                                                               one home for four sites (new)
packages/motoko-ext-compose/author_tools.ail            166 +- grep_impl routed; the branch preserved;
                                                       -113    the two exec arms merged
scripts/dst/compose_live_exec.ail                       165 +  the live half of S14's two subjects
                                                               (new)
packages/motoko-ext-compose/compose.ail                 127 +- check_snippet + run_snippet widened to
                                                        -52    (p, w, …); four caller re-basings
scripts/dst/run_declared_vs_performed.sh                 61 +- the must_die_on row inverted, two-part
                                                        -40    per S15
packages/motoko-ext-compose/authoring/dispatcher.ail      43 +- the fifth of five effects routed
                                                        -22
Makefile                                                 31 +- compose_live_exec target + sweep entry
ailang.lock / compose ailang.toml                         6 +- the new module, lock refreshed per D22
```

**The tree is left uncommitted.** Nothing was committed or pushed this session.

## The headline — the handoff's central safety trap was built on a false premise

The handoff priced the argv conversion as a **quoting boundary**: *"each `exec(cmd, argv)` becomes
`p.proc_exec(w, "BashExec", encode(jo([kv("cmd", js(<shell string>))])))`"*, safe "BY MEASUREMENT OF
THE GENERATORS", with a stop-and-report if any argument could ever carry user text. The premise
under it was *"the seam's only subprocess door is `BashExec` → `bash -lc`"*.

**That is not what the seam does.** `tool_runtime.ail:888` wraps in `bash -lc` only when
`shell_tokens_in_process(req)` fires — `cmd` literally `bash`/`sh`/`zsh`, `cmd` containing a
**space**, or a shell metacharacter in `cmd` or any `args` element. A request whose `cmd` is a bare
program name and whose `args` are a list reaches `exec(cmd, args)`: the same `std/process.exec`
call, with the same argv, that the ambient sites made. Measured through the production dispatcher
**before writing any routing**:

```text
{"cmd":"ailang","args":["check","tmp/d26/probe_argv.ail"]}  -> exit 0, real compiler output
{"cmd":"echo","args":["a b","c"]}                           -> stdout "a b c\n"  (argv preserved)
```

**Why it matters rather than being a tidier spelling.** The fourth routed site is
`author_tools.grep_impl`, whose `pattern` comes out of a **model-authored tool call** — the one
argument in the package that carries free text, and exactly the case trap 2 said to stop and report
on. Under the prescribed shell-string form, `rg -F <pattern>` interpolated into a `bash -lc` string
is a command-injection site reachable by anything the model writes. Under the argv form there is no
shell on the path — not a mitigation, the **absence of the boundary that creates the risk**. All of
trap 2 dissolves and no site needs the charset argument.

Conditional per S25, stated at `proc.bash_exec_args`: this holds while `cmd` stays a bare program
name. Put a space in it and `shell_tokens_in_process` flips, and every argument becomes shell text
in the same motion. `cmd` and `argv` are separate parameters so a caller has to work at getting it
wrong.

**Four items of preparation predicted the type work, the identity work and the landing sites
correctly. None had looked at the dispatcher's own branch, one function below the seam they were
all describing.**

## The four sites, and the fifth trap measured wrong

| # | site | branch | successor |
|---|---|---|---|
| 1 | `compose.ail:313` `check_snippet` | `out.exit_code == 0` | helper widened; both callers re-based to `checked.next_state` |
| 2 | `compose.ail:331` `run_snippet` | streams via `decode_bash_result` | both `remove_if_file` re-based to `ran.next_state` |
| 3 | `author_tools.ail:481` `grep_impl` | **`text == ""`; exit code NOT read** | non-scanning branch `w` → `out.next_state` |
| 4 | `authoring/dispatcher.ail:268` `check_snippet` | `checked.exit_code == 0` | `file_remove` re-based to `checked.next_state` |

Three `std/process` imports gone with `ProcessError`/`process_error_to_string`, plus **two dead
`std/bytes (toString)` imports** the handoff did not list — WI-D20's classifier-3 mechanism at two
more sites (a symbol left on an import counts as an ambient source for an effect the extension can
no longer perform).

**Trap 5 was predicted wrong and measured right.** The handoff expected a spawn failure to arrive as
`ToolErrorResult`. Measured against a command that does not exist: `run_process_result` catches
`ProcessError` **itself** and renders a well-formed `BashExecResult` with the reason on **stderr**,
exit 1. So `stderr-else-stdout-else-message` preserves the old `Err(ProcessError)` arm exactly, by a
different road.

**Trap 3's unnamed consequence:** `one_attempt` reads `ran.exit_code != 0` as "snippet runtime
failed", so a `-1` becomes a **retry** rather than a false success — fail-closed in the same
direction as `check_snippet`'s `ok`.

## The one field the routing forced a choice on — and the counter it moved

`grep_impl` had two `mk_ok` constructions, one per `exec` arm, agreeing on every field but
`matches`: the `Ok`-empty arm reported `cap_text(text)` = `""`, the `Err` arm the fallback's lines.
Both now arrive as `text == ""` — a no-match search and a spawn failure are the **same value** at
this seam, which is precisely what trap 1 says is *correct* for the branch. `out.exit_code` cannot
recover the distinction either: ripgrep answers 1 for "no matches" and `run_process_result` writes 1
for a spawn failure.

**`raw` wins** — the `Err` arm's answer. It is the arm this checkout actually took at every call
(`rg` is not installed here), and it is the arm that does not lie: the old `Ok`-empty answer
reported `matches: ""` beside an `excerpt` full of fallback hits, in a `payload_json` that goes back
to the model. **A consumer reading the structured field was told "no results" for a search that had
them.** Stated at the site as a behaviour change per WI-D19's rule.

**Silent-wrong 75 → 76**, discovered not authored — with the ruling left visible: its reachability is
**environment-conditional** (unreachable in this checkout, produced on any machine with ripgrep). It
is counted as produced-in-principle; if review reads the counter as observation-only, that is the
site to strike. **Instrument-weaker-than-claim 7, unchanged.**

## The witness — the first deterministic compose authoring loop in the project

Two scenarios in `discovery_dst.ail`, both installing **`motoko_ext_compose` itself** through
`register_with_config` with a literal config (S14: our closure, not a replica). Every scenario above
them drives a hook that file wrote to compose's shape; these drive compose's real bodies.

**A deviation from the handoff, with its reason.** It asked for the `handle_compose_tool` chain.
That chain is **not deterministically reachable**: `one_attempt` calls `callStreamResult` — ambient
AI, a disclosed class explicitly out of scope — before it reaches a snippet to check, and no branch
through it authors nothing. `on_response_intercept` is the **AI-free half of the same code**: same
`check_snippet`, same `run_snippet`, the same two routed sites, reached from a fenced response. The
deviation is in the entry point, not the subject.

**The fixture's two exit codes disagree on purpose, and that is the whole row.** `ScriptedTool`
carries `exit_code` typed and `content` as the string the ABI renders into `ExtProcOutcome.output`.
Live they cannot disagree — both come from one `run_process_result`. Scripted they are independent:
**typed 71, embedded 0**. This is S33's distinguishing input and one of the cases S33 names as not
having *existed* until the project built it — WI-D22 added `ScriptedTool.exit_code` and the
divergence became constructible in the same edit. A site reading the typed field fails the check;
one parsing `output` (the pre-D23 shape, natural for anyone who remembers the code "is in the JSON")
passes it. Both compile; both green on every live input.

Quantities S7-distinct across the file: durations 43/47, codes **71** served and **73** slack
(driver tools -1, D24's effects 41/43/47/53/59/61, grep 1). Two entries against one dispatch —
WI-D24's load-bearing slack, since an empty `ext_effects` queue **delegates** and would put a live
`ailang check` inside a deterministic gate.

Nine rows green: terminator, **reachability before verdict** (S24), origin = `"compose"` off the
transport, **the failure branch on the typed code**, the diagnostic surviving the decode, VALIDATES,
the reconstituted queue serving 71, REPLAYS identically, and the replay taking the same branch. The
verdict is read off the run's **message list**, so the witness is neither the recorder's nor
compose's.

`compose_grep_quiet_scenario` is trap 1's divergent input: exit 1, empty stdout, haystack in the
world's `files` table. The scan's own reads are **not recorded** (D18 §6), so the verdict is carried
out by a `file_write` — D20's `routing_tool_handle` shape. It reads `excerpt` and not `ok`, because
`grep_impl` answers `ok: true` on both branches.

## The mutants — 2 applied, restore by file copy (S17)

**Mutant 1** (`ok: contains(out.output, "\"exit_code\":0")` — recover the code from the rendering)
killed its named branch row plus four others. **What stayed green is the finding**: `VALIDATES`,
`serves the same TYPED code`, and `REPLAYS to an identical interaction log`. The mutant changes
**what** is recorded, not whether it round-trips — a wrong compose replays as faithfully as a right
one. **A suite carrying only the round trip would have shipped this mutant green.**

**Mutant 2** (`grep_impl` gated on the exit code) killed **exactly** its named row
(`verdict=SKIPPED`) and nothing else — S33's mechanism as a measurement: the proxy and the truth
agree on every search that finds something.

## The live half — S14's second subject, which had no home

`scripts/dst/compose_live_exec.ail` (new target, in the sweep). The scripted scenario proves the
**adoption** and nothing about whether the seam can run a compiler, because in it none runs. **WI-D19
shipped a routing claim false in exactly that direction and it took WI-D21 to measure it.**

It drives `dispatch_response_intercept` — not a session, since one needs a provider and `--ai-stub`
cannot emit a chosen fence — with `Session.ext_ports_of` over `live_ports`: real
`ambient_file_write` (compose writes to the real disk) and `world_ext_effect` over an **empty**
`ext_effects` queue, whose `[]` arm delegates to the real dispatcher.

```text
✓ the FAILURE branch ran — a real `ailang check` returned non-zero through the routed seam
✓ the diagnostic is the COMPILER's, so the seam really ran one
  stderr: Error: type error in tmp/inline_… : undefined variable: undefined_symbol_xyz
```

`undefined variable` is `ailang check`'s wording and nothing in Motoko generates it, so a green
cannot come from a stub, a tool-error blob, or the `"requires extension capability"` string
`proc_exec(w, "ailang", …)` would have returned. **The handoff said "the existing smoke targets
exercise this — cite which". None do**: no smoke target installs compose (C5's outstanding debt), so
the live half had no home and this file is it.

## `declared_vs_performed` DID move, and its own instrument predicted it

The handoff listed it among the verdicts that **must not** move. The row count did not change
(**46/0**). One **row** did, red on the first run after routing:

```text
✗ compose_intercept_inline COMPLETED — the inline branch no longer reaches a subprocess …
```

`must_die_on compose_intercept_inline Process` asserted compose's inline branch still reached an
**ambient** capability; routing is precisely the removal of that. The runner's own D19-era comment
had written the prediction down: *"the day `proc_exec` grows an exit code and compose routes through
it, this arm stops dying and says so."* D23 grew the code, D26 routed the seam, the arm stopped
dying, and the gate said so. **A re-tensing on schedule, not a repair** — kept two-part per S15,
because a reader finding a `must_die_on` turned into a completion, in the diff of the item that made
it complete, is otherwise entitled to think the gate was weakened to pass.

**The replacement is the stronger claim**: completes with Env, FS **and** Process all withheld — none
ambient, rather than one still reachable. D19's FS-axis row is kept for a **diagnostic** reason
though strictly subsumed: the capability check names whichever effect the branch reaches first, so a
Process-side regression would mask an FS-side one.

**One lesson lost its executable home and is reported rather than dropped.** "Performed is a property
of a hook AND ITS INPUTS" needed a hook with two inputs and two performed answers; compose's
intercept no longer has two because it no longer has one. The limit is still stated in the file's
header; the demonstration is gone. It blocks neither goal-line clause → **maintenance register**.

## Inventory, verdicts and sweep

**`ext_ambient_inventory`: compose 11 → 8 ambient sources, 32 → 36 field calls** — the first
yield-adjacent movement since D15. 36 derived as `32 + 4`, one per routed site, enumerated. **The 8
remaining are exactly the three disclosed classes and nothing else:** four `println`
(`ai_compat:45`, `author_loop:4`, `claimcheck:4`, `compose:31`), registration's three
(`config:3` ×2, `register:3`), one AI (`ai_compat:44`).

Consumers re-derived per S22: the tool pins nothing; the selftest's pins are the 4-of-15 yield and
the fifteen package directories, both green. `11/32` survives only in PLAN prose at `:3680`,
`:3860`, `:3864` — reviewer-side records, **corrected at apply**.

Unmoved and asserted: HOOK-PORT-MEDIATED **5/15** (compose still HOOK-UNRESOLVED on door 3's
`show`), ambient PORT-MEDIATED **4/15**, AMBIENT **11**, `declared_vs_performed` **46/0**.

**No cascade.** Every source edit is package-side plus two instruments and the Makefile;
`session.ail`, `ext/runtime.ail` and `tool_phase.ail` untouched, so neither the six-file nor the
D25-corrected WIDE form fires. `anchors` and `predicate_anchors` green unchanged. No `types.ail`
edit; `sync_packages` run anyway after the signature widenings and `ailang lock` refreshed per D22.

Green by run: `discovery` (92 ✓), `compose_live_exec`, `world_state`, `execution_program`,
`program_persistence`, `declared_vs_performed`, `conformance`, `ext_ambient_inventory` + selftest,
`ext_call_inventory` + selftest, `ext_hook_scope_selftest`, `anchors`, `predicate_anchors`. Full
`make dst` red on **exactly the three standing reds** — the `test_coverage` pair (pinned D22) and
`effect_inventory_selftest` (pinned D25, run separately as it is not in the aggregate) — and
**nothing new**.

## What item 5 (C5's compose-bearing profile) inherits

1. **Compose has no `{Process}` ambient source and no ambient FS or Clock in any hook path.** Its
   whole remainder is 8 sources in three disclosed classes. Nothing on the mediation side of clause
   1 is owed by compose's *code* any more.
2. **A template for driving it.** `compose_check_scenario` installs compose in a graded run and
   carries record → validate → replay. What it is **not** is a profile — it lives in
   `discovery_dst`'s registry, so `absent_classes`' pins and the profile machinery are untouched.
3. **`handle_compose_tool` is not deterministically reachable, and this is the profile's first
   obstacle.** A profile exercising the *tool* rather than the *intercept* performs a live provider
   call or needs the AI disclosed at that boundary.
4. **No compose row in `declared_vs_performed` dies on anything now** — a mediation regression is
   caught by a COMPLETES row, and the new diagnostic arms are what tell D19's sites from D26's.
5. **The `matches` behaviour change** is on the author-tools path a profile with
   `author_tools: true` would exercise; annotated, with no fixture beyond the quiet-scan row.
6. **The bridge's `workdir: "."` / `timeout_ms: 0`** confirmed **inert for this tool** —
   `run_process_result` never receives `workdir` — so a routed call runs where the process started,
   exactly as ambient `exec` did. Still on the register, now with the measurement attached.
7. **Door 3 untouched.** Compose stays HOOK-UNRESOLVED on `show`; it closes by disclosure plus an
   upstream filing, not by this item or the next.
