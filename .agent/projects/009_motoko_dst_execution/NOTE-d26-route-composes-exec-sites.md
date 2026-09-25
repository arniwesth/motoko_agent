# NOTE-d26 — routing compose's `exec` sites

Item 1 of the goal line's remaining critical path (the plan's item 4 of six). Ground: HEAD
`560322c` (`docs(009): WI-D26 handoff — route compose's exec sites`), clean tree at start.

---

## 0. THE HEADLINE

**The handoff's central safety trap was built on a false premise, and taking its prescribed form
would have authored a shell injection into the one routed argument that carries model-written
text.**

The handoff priced the argv conversion as a quoting boundary — *"each `exec(cmd, argv)` becomes
`p.proc_exec(w, "BashExec", encode(jo([kv("cmd", js(<shell string>))])))`"* — safe "BY MEASUREMENT
OF THE GENERATORS", conditional on every path being machine-generated hex and underscores, with a
stop-and-report if any argument could ever carry user text. The premise under it was
*"the seam's only subprocess door is `BashExec` → `bash -lc`"*.

That is not what the seam does. `tool_runtime.ail:888`:

```ail
let effective = if shell_tokens_in_process(req) || isSome(req.cwd) then
                  { cmd: "bash", args: ["-lc", wrapped_cmd], … }
                else req;
match exec(effective.cmd, effective.args) { … }
```

`bash -lc` is the **fallback for a request that needs a shell**, not the door.
`shell_tokens_in_process` (`tool_runtime.ail:50`) fires only when `cmd` is literally `bash`/`sh`/`zsh`,
when `cmd` contains a **space**, or when `cmd` or any element of `args` contains one of
`| > < && || ; $( ` `. A request whose `cmd` is a bare program name and whose `args` are a list
reaches `exec(cmd, args)` — **the same `std/process.exec` call, with the same argv, that the
ambient sites made before this item routed them.**

Measured before a line of routing was written, through the production dispatcher:

| request | result |
|---|---|
| `{"cmd":"ailang","args":["check","tmp/d26/probe_argv.ail"]}` | exit 0, real compiler output |
| `{"cmd":"echo","args":["a b","c"]}` | stdout `a b c\n` — argv preserved; a shell would have split it |

**Why it matters rather than being a tidier spelling.** The fourth routed site is
`author_tools.grep_impl`, whose `pattern` argument comes out of a **model-authored tool call**. It
is the one argument in the package that carries free text, and the handoff's own trap 2 says to
*stop and report rather than hand-roll shell quoting* if that is ever true. Under the prescribed
shell-string form, `grep -F <pattern>` interpolated into a `bash -lc` string is a command-injection
site reachable by anything the model writes. Under the argv form there is no shell on the path and
nothing to quote against — not as a mitigation, but as the absence of the boundary that creates the
risk. The whole of trap 2 dissolves, and the charset argument the handoff asked each site to state
is not needed at any of the four.

**What stays conditional, per S25:** this holds while `cmd` is a bare program name. Put a space in
it — `"ailang check"` — and `shell_tokens_in_process` flips, the request is re-wrapped as
`bash -lc`, and every argument becomes shell text in the same motion. `proc.bash_exec_args` takes
`cmd` and `argv` as separate parameters so a caller has to work at getting this wrong, and the
paragraph saying so is at the function.

Four items of preparation predicted the type work, the identity work and the landing sites
correctly. What none of them had looked at was the dispatcher's own branch, one function below the
seam they were all describing.

---

## 1. THE GIT WALL-CLOCK WINDOW

| | |
|---|---|
| first commit of the item | this note's commit |
| HEAD at start | `560322c` |
| tree at start | clean |
| files changed | 6 modified, 2 added |

---

## 2. WHAT SHIPPED, PER SITE — the handoff's table, closed out

| # | Site | What the call became | What threads where |
|---|---|---|---|
| 1 | `compose.ail:313` `check_snippet` | `p.proc_exec(w, bash_exec_tool(), bash_exec_args("ailang", ["check", path]))`; `ok: out.exit_code == 0`; `errors` via `message_of` | helper widened to `(p, w, path)`, returns `next_state`. `one_attempt`: `stored_pending.next_state` → `checked.next_state`, both branches. `on_response_intercept`: `written.next_state` → `checked.next_state`, both branches |
| 2 | `compose.ail:331` `run_snippet` | `bash_exec_args("ailang", ["run","--caps",caps,"--entry","main",path])`; streams via `decode_bash_result` | helper widened to `(p, w, path, caps)`. Both callers' `remove_if_file` re-based from `stored_pending`/`written` to `ran.next_state` |
| 3 | `author_tools.ail:481` `grep_impl` | `bash_exec_args("rg", ["-n","--no-heading","-F",pattern,path_glob])`; **exit code not read** | ports already in place; the non-scanning branch's successor moved from `w` to `out.next_state` (it was true before, because nothing had been observed; something has now) |
| 4 | `authoring/dispatcher.ail:268` `check_snippet` | `bash_exec_args("ailang", ["check", path])`; `ok: checked.exit_code == 0` | ports already in place; `file_remove` re-based from `written.next_state` to `checked.next_state` |

**Three `std/process` imports removed** (`compose.ail`, `author_tools.ail`,
`authoring/dispatcher.ail`), with `ProcessError` and `process_error_to_string`.

**Two `std/bytes (toString)` imports removed with them**, and this was not on the handoff's list. Its
only calls in both modules were on `ProcessOutput`'s byte streams; left in place they would have
kept counting as ambient sources for an effect the extension can no longer perform — WI-D20's
classifier-3 mechanism, at two more sites. Both removals are annotated with that reason.

**One module added: `packages/motoko-ext-compose/proc.ail`.** Three modules needed the same request
encoder and the same answer decoder, which is S23's threshold, and the rule bites harder here than
usual because the two halves must **agree**: an encoder that shipped the argv one way and a decoder
that read the answer the other would compile at all four sites and be wrong at all four. It also
gives the argv measurement above one home instead of four copies. Added to the package's
`[exports] modules`; `ailang.lock` refreshed per D22.

---

## 2.1 The construction census, as executed

| | count |
|---|---|
| `p.proc_exec` call sites added | 4 |
| ambient `exec` call sites removed | 4 |
| `std/process` imports removed | 3 |
| `std/bytes` imports removed | 2 |
| helper signatures widened `(…) → (p, w, …)` | 2 |
| caller successor re-basings | 6 |
| effect rows widened with `IO` (the `proc_exec` row carries it) | 5 |
| modules added | 1 |

---

## 3. THE FIVE TRAPS, EACH MEASURED

**Trap 1 — `rg` exit 1 means NO MATCHES.** Held. `grep_impl` branches on `text == ""` and the routed
form branches on `text == ""`; `out.exit_code` is never read there, and the site says why in its own
block. The typed code is *available* and deliberately *not load-bearing* — the one place in the
package where that sentence is true.

**Trap 2 — the quoting boundary.** Dissolved. See §0.

**Trap 3 — `exit_code == -1` lands in the failure branch.** Held, stated once per module that owns an
`ok` (both `check_snippet`s), not per site. Recorded consequence at `run_snippet`'s caller, which the
handoff did not name: `one_attempt` reads `ran.exit_code != 0` as "snippet runtime failed", so a -1
becomes a **retry** rather than a false success — fail-closed in the same direction.

**Trap 4 — double truncation.** Both flags OR-ed, which is what the ambient form already did; only
the source of the seam's flag moved (`ProcessOutput.truncated` → `BashExecResult.meta.truncated`,
decoded). Compose's 8000/2000 caps kept. Annotated at the site because there are now two truncators
in the chain rather than one.

**Trap 5 — the spawn-failure arm.** **The handoff predicted the wrong shape**, and it was measured
rather than reasoned about, as the handoff itself demanded. It predicted `ToolErrorResult` /
`dispatch_one_typed`'s defensive arm. Measured against a command that does not exist:

```
{"cmd":"definitely_not_a_command_xyz","args":["--v"]}
  -> exit_code 1, output {"tool":"BashExec","cmd":"…","exit_code":1,
                          "stdout":"","stderr":"not found: …","truncated":false}
```

`run_process_result` catches `ProcessError` **itself** and renders it as a well-formed
`BashExecResult` with the reason on **stderr**. So `errors: stderr-else-stdout-else-message`
preserves the old `Err(ProcessError)` arm's semantics exactly, arriving by a different road. The
`message` fallback is retained for the `ToolErrorResult` shape, which the seam can still produce on
other paths.

---

## 4. THE ONE FIELD THE ROUTING FORCED A CHOICE ON — and it is a silent-wrong site

`grep_impl` had **two** `mk_ok` constructions, one per `exec` arm, and they agreed on every field
but `matches`:

| input | old `matches` | old `excerpt` |
|---|---|---|
| `Ok`, ripgrep matched nothing | `cap_text(text)` = `""` | the fallback scan's lines |
| `Err`, ripgrep failed to spawn | `cap_text(fallback)` | the same lines |

Both now arrive as `text == ""` — a no-match search and a spawn failure are the same value at this
seam, which is exactly what trap 1 says is **correct** for the branch, and is what makes this a
forced choice rather than a preserved behaviour. Reading `out.exit_code` would not recover the
distinction either: ripgrep answers 1 for "no matches" and `run_process_result` writes 1 for a spawn
failure.

**`raw` wins** — the `Err` arm's answer — for two measured reasons. It is the arm this checkout
actually took at every call (`rg` is not installed here, so ambient `exec("rg", …)` answered
`Err(NotFound)` every time). And it is the arm that does not lie: the old `Ok`-empty answer reported
`matches: ""` beside an `excerpt` full of fallback hits, in a `payload_json` that goes back to the
model. **A consumer reading the structured field was told "no results" for a search that had them.**
Stated at the site as a behaviour change per WI-D19's rule, rather than folded in silently.

This is a **pre-existing** defect surfaced by the merge, not one authored here — see §9.

---

## 5. THE WITNESS — the first deterministic compose authoring loop in the project

Two new scenarios in `discovery_dst.ail`. Both install **`motoko_ext_compose` itself**, through
`register_with_config` with a literal config — the same entry point the host uses and the one
`declared_vs_performed` uses, per S14's "our closure, not a replica". Every scenario above them in
that file drives a hook the file wrote to compose's shape; these drive compose's real bodies.

### 5.1 `compose_check_scenario` — the headline row

Compose's real `on_response_intercept` chain: `dir_make` → `clock_now` → `file_write` →
**`check_snippet`** → branch → `file_remove`, with the `ailang check` served from
`WorldState.ext_effects` instead of run.

**A deviation from the handoff, with its reason.** The handoff asked for the `handle_compose_tool`
chain. That chain is **not reachable deterministically**: `one_attempt` calls `callStreamResult` —
compose's ambient AI, a disclosed class and explicitly out of this item's scope — before it ever
reaches a snippet to check, and there is no branch through `handle_compose_tool` that authors
nothing. The intercept chain is the **AI-free half of the same code**: same `check_snippet`, same
`run_snippet`, the same two call sites this item routed, reached from a fenced response instead of
an authored one. The deviation is in the entry point, not the subject.

**The fixture's two exit codes disagree on purpose, and that is the whole row.** `ScriptedTool`
carries `exit_code` as a typed field and `content` as the string the ABI renders into
`ExtProcOutcome.output`. Live they cannot disagree — both come out of one `run_process_result`. In a
scripted world they are independent, and the fixture sets them apart: **typed 71, embedded 0**.

That is S33's distinguishing input, and it is one of the cases S33 names as not having *existed*
until the project built it — WI-D22 added `ScriptedTool.exit_code`, and the divergence became
constructible in the same edit. A `check_snippet` reading the typed field sees 71 and fails the
check; one recovering a code by parsing `output` — the pre-WI-D23 shape, and the natural thing to
write for anyone who remembers the exit code "is in the JSON" — sees 0 and passes it. Both compile;
both are green on every live input and every fixture whose codes agree. The fixture is an oracle and
is not a claim about production; the note saying so is at the fixture.

The stderr text is a **real** diagnostic, measured by running `ailang check` on a module with an
undefined variable through the production dispatcher.

**Quantities (S7 — no two equal, and distinct from every other queue in the file):** durations
43/47; typed exit codes 71 (served) and 73 (unconsumed slack). The driver's own tools carry -1,
D24's extension effects 41/43/47/53/59/61, the grep scenario 1. Two entries against one dispatch,
and the slack is WI-D24's load-bearing kind: an empty `ext_effects` queue does not fail, it
**delegates**, so a fixture sized exactly to its expectation turns any future off-by-one into a live
`ailang check` inside a deterministic gate.

**Nine rows, all green:**

```
✓ compose: the scenario reached its terminator
✓ compose: the routed check RAN — compose's own seam reached the recorder     (S24, before verdict)
✓ compose: the recorded effect names compose as the performer                  (origin = "compose")
✓ compose: the FAILURE branch was taken, on the typed exit code and not on the rendered one
✓ compose: the diagnostic came back through the decode, not lost with the rendering
✓ compose: the recorded program VALIDATES
✓ compose: the reconstituted queue serves the same TYPED code the recording did
✓ compose: the authoring loop REPLAYS to an identical interaction log
✓ compose: the REPLAY takes the same failure branch
   recorded: expect_extension_effect=1 origin=[compose]
```

The origin row is the other half of D24's pair. D24 deliberately used an id no production registry
contains, to kill an adapter that hardcoded `"compose"`; this one asserts `"compose"` **because
compose is the subject**, and it comes off the transport the fold stamped.

The verdict is read off the run's **message list** — `InterceptHandled` becomes a tool message the
driver appends and the driver's return value is that list — so the witness is neither the recorder's
nor compose's.

### 5.2 `compose_grep_quiet_scenario` — the divergent input trap 1 needs

A search with **no hits**: seeded answer exit 1, empty stdout, which is exactly what ripgrep
produces for one. Correct behaviour is to run `grep_fallback_scan`, which reads the file through
`ExtPorts` and finds the pattern the subprocess did not report. The haystack is in the world's
`files` table and not on disk, so this row also witnesses that WI-D20's FS routing of the scan is
real.

The scan's own reads are **not recorded** (WI-D18 §6 — reads are not, since `InitialWorld` cannot
rebuild them), so the census structurally cannot see this. The verdict is carried out of the hook by
a `file_write`, which is recorded and lands in the final world — WI-D20's `routing_tool_handle`
shape. It reads `excerpt` and **not** `ok`, because `grep_impl` answers `ok: true` on both branches
and a verdict read off `ok` would be satisfied by a grep that found nothing.

```
✓ grep: the scenario reached its terminator
✓ grep: the routed search RAN — the seam reached the recorder
✓ grep: a no-match search still runs the fallback scan — the exit code is NOT the gate
   verdict=SCANNED (expect_extension_effect=1)
```

---

## 6. THE MUTANTS: 2 applied, each killed its named row

Save and restore by **file copy** (S17). Both files verified byte-clean after restore, and
`make discovery` re-run green.

### Mutant 1 — the routed site recovers the code from the rendered output

```ail
let mut_ok = contains(out.output, "\"exit_code\":0");
{ ok: mut_ok, … }
```

**Named row: `compose: the FAILURE branch was taken, on the typed exit code and not on the rendered
one` — RED.** Four others went with it:

```
✗ compose: the routed check RAN — expect_extension_effect=2, expected 1
✗ compose: the recorded effect names compose as the performer — origins=[compose,compose]
✗ compose: the FAILURE branch was taken … — no ComposeInline tool message
✗ compose: the diagnostic came back through the decode … — carries no diagnostic text
✗ compose: the REPLAY takes the same failure branch
```

**What stayed green is the finding worth recording**: `the recorded program VALIDATES`, `the
reconstituted queue serves the same TYPED code`, and `the authoring loop REPLAYS to an identical
interaction log`. The mutant changes **what** is recorded, not whether it round-trips — a wrong
compose replays as faithfully as a right one. The round-trip rows are not the mutant-killers here;
the branch rows are, and a suite carrying only the round trip would have shipped this mutant green.

### Mutant 2 — `grep_impl` gated on the exit code

```ail
let text = if out.exit_code == 0 then decode_bash_result(out.output).stdout else "";
let scanned = if text == "" && mut_gate then grep_fallback_scan(…) else { lines: [], next_state: … };
```

**Named row: `grep: a no-match search still runs the fallback scan` — RED**
(`verdict=SKIPPED`), and **nothing else moved** — the precision the row was built for. Every other
row in the file, including both compose check rows, stayed green, which is S33's mechanism stated as
a measurement: the proxy and the truth agree on every search that finds something.

---

## 7. THE LIVE HALF — S14's second subject

`scripts/dst/compose_live_exec.ail`, new, with its own make target and in the sweep aggregate.

The scripted scenario proves the **adoption** and proves nothing about whether the seam can run a
compiler, because in it no compiler runs. WI-D19 shipped a routing claim false in exactly that
direction and it took WI-D21 to measure it; this is the row that would have caught it.

It drives `dispatch_response_intercept` — not a session, because a session needs a provider and
`--ai-stub` cannot be made to emit a chosen fence — with `Session.ext_ports_of` over `live_ports`:
real `ambient_file_write`, so compose writes the snippet to the **real** filesystem, and
`world_ext_effect` over an **empty** `ext_effects` queue, whose `[]` arm delegates to
`dispatch_one_typed` and the real `run_process_result`.

```
✓ the FAILURE branch ran — a real `ailang check` returned non-zero through the routed seam
✓ the diagnostic is the COMPILER's, so the seam really ran one
  stderr: Error: type error in tmp/inline_1786286570545 (decl 0): undefined variable:
          undefined_symbol_xyz at tmp/inline_1786286570545.ail:3:35
```

The text assertion is what makes it unfakeable: `undefined variable` is `ailang check`'s wording and
nothing in Motoko generates it, so a green cannot be produced by a stub, by a tool-error blob, or by
the `"requires extension capability"` string `proc_exec(w, "ailang", …)` would have returned. The
temp file is written and removed on the real disk — `tmp/` is empty afterwards.

The handoff said "the existing smoke targets exercise this — cite which". **None do**: no smoke
target installs compose, which is C5's outstanding debt, so the live half had no home and this file
is it.

---

## 8. THE YIELDS AND THE AMBIENT INVENTORY — derived, not predicted

**`ext_ambient_inventory`: compose 11 → 8 ambient sources, 32 → 36 `ExtPorts` field calls.** The
first yield-adjacent movement since D15.

Derivation of 36: `32 + 4`, one per routed call site, enumerated —
`compose.ail:313`, `compose.ail:331`, `author_tools.ail:481`, `authoring/dispatcher.ail:268`.
Derivation of 8: the three `std/process` imports leave; the two dead `std/bytes` imports were never
counted (their symbols are pure).

**The 8 that remain are exactly the three disclosed classes the goal line names, and nothing else:**

| source | class |
|---|---|
| `ai_compat.ail:44` `std/ai.stepWithStream` | the ambient AI (1) |
| `ai_compat.ail:45`, `author_loop.ail:4`, `claimcheck.ail:4`, `compose.ail:31` `std/io.println` | the four `println` (4) |
| `config.ail:3` `std/fs.fileExists`, `config.ail:3` `std/fs.readFile`, `register.ail:3` `std/env.getEnvOr` | registration's three (3) |

**Consumers of the old numbers, re-derived per S22:** the inventory tool pins nothing (it computes);
`ext_ambient_inventory_selftest` is green unchanged (its pins are the 4-of-15 yield and the fifteen
package directories). The `11 ambient sources / 32 field calls` figures appear only in the PLAN's
historical prose at `:3680`, `:3860` and `:3864`, which are reviewer-side records of what was true at
those items — **corrected at apply, not here**, per the handoff.

**Verdicts that did NOT move, asserted rather than assumed:**

| verdict | value | status |
|---|---|---|
| `ext_hook_scope` HOOK-PORT-MEDIATED | 5 of 15 | unmoved; compose still HOOK-UNRESOLVED (door 3's `show`) |
| `ext_ambient_inventory` PORT-MEDIATED | 4 of 15 | unmoved |
| `ext_ambient_inventory` AMBIENT | 11 | unmoved — compose is still AMBIENT, on `println`/AI/registration |
| `declared_vs_performed` | 46 / 0 | count unmoved; **one row inverted — see §8.1** |

### 8.1 `declared_vs_performed` DID move, and its own instrument predicted it

The handoff said *"Verdicts that must NOT move: … `declared_vs_performed` (46/0 — the declared rows
do not change; the same effects are performed through the port)"*. The row count did not change. One
**row** did, and it went red on the first run after the routing landed:

```
✗ compose_intercept_inline COMPLETED — the inline branch no longer reaches a subprocess …
```

`must_die_on compose_intercept_inline Process` asserted that compose's inline branch still reached an
**ambient** capability. Routing is precisely the removal of that. And the runner's own WI-D19-era
comment had written the prediction down:

> *"So this row is now also the standing witness for that unrouted seam: the day `proc_exec` grows an
> exit code and compose routes through it, this arm stops dying and says so."*

WI-D23 grew the code, WI-D26 routed the seam, the arm stopped dying, and the gate said so. That is a
**re-tensing on schedule**, not a repair, and the block is kept two-part per S15 — a reader who found
a `must_die_on` turned into a completion, in a diff belonging to the item that made it complete, is
otherwise entitled to think the gate was weakened to make the item pass.

**What replaced it is the stronger claim.** The old row asserted that one ambient capability was still
reachable; the new one asserts that **none** is — `compose_intercept_inline` runs under the base
withheld set (Env, FS **and** Process all withheld) and must COMPLETE. It is the row that goes red if
any of the six routed sites is put back, and its failure arms discriminate a Process-side regression
from an FS-side one by name.

D19's FS-axis row is **kept** even though the new row strictly subsumes it, for a diagnostic reason
rather than a logical one: the capability check reports whichever ambient effect the branch reaches
first, so a Process-side regression would mask an FS-side one entirely. Granting Process puts the FS
sites in front of the compiler on their own.

```
✓ compose_intercept_inline COMPLETES with Env, FS AND Process all withheld — the inline branch
  performs NO ambient effect; through WI-D25 this arm died on Process
✓ compose_intercept_inline COMPLETES with FS withheld and Process granted — the FS axis alone
declared_vs_performed: 46 passed, 0 failed
```

**One lesson lost its executable home, and it is reported rather than dropped.** "Performed is a
property of a hook AND ITS INPUTS" needed a hook with two inputs and two different performed
answers. Compose's intercept no longer has two, because it no longer has one. The limit itself — that
this detector witnesses exercised paths, not all inputs — is unchanged and still stated in the file's
header; what is gone is the demonstration of it. Finding a second home does not block goal-line
clause 1 or clause 2, so per the endgame scope rule it goes to the **maintenance register**, priced
but not scheduled.

---

## 9. THE COUNTERS, KEPT APART

**Silent-wrong: 75 → 76.** One site, and it is **discovered, not authored**: `grep_impl`'s `Ok`-arm
`matches: ""` beside a populated `excerpt` on a search that ripgrep ran and that matched nothing
(§4). It shipped, it is in `payload_json`, and the consumer is the model. Two notes for review, both
against the count rather than for it:

* **Its reachability is environment-conditional.** In this checkout `rg` is not installed, so every
  call took the `Err` arm and the wrong answer was never produced *here*. On a machine with ripgrep
  a quiet search produces it. The counter's definition is "a wrong answer a program produces", and I
  have counted it as produced-in-principle rather than observed; if review reads the counter as
  observation-only, this is the site to strike.
* It was closed in the same edit that found it, which the handoff's counter rule permits for
  *discovered* defects and forbids for authored-and-closed ones. Nothing authored by this item is
  counted.

**Instrument-weaker-than-claim: 7, unchanged.** Nothing here overstated an instrument. The
`declared_vs_performed` row (§8.1) is the opposite case — an instrument that stated exactly what it
measured and then correctly reported its own subject changing.

**Not counted, and named so the ruling is visible:** the handoff's trap-2 premise (§0) was wrong in
shipped *prose* in a handoff, and the round-trip-green-under-mutant-1 observation (§6) is a property
of the suite rather than a defect in it. Neither is a wrong answer a program produced. This is the
same class D25 left for review under "shipped-and-wrong source claim"; the ruling there governs here.

---

## 10. THE CASCADE: none, and why

**No anchors moved.** Every source edit is package-side (`packages/motoko-ext-compose/**`) plus two
instrument files (`scripts/dst/discovery_dst.ail`, `scripts/dst/run_declared_vs_performed.sh`) and
the `Makefile`. `session.ail`, `src/core/ext/runtime.ail` and `tool_phase.ail` were **not touched**,
so neither the six-file nor the D25-corrected WIDE form fires. `make anchors` and
`make predicate_anchors` both green, unchanged.

**No `types.ail` edit, no `sync_packages`-sensitive type change.** `make sync_packages` was run
anyway after the signature widenings, and `ailang lock` refreshed compose's entry per D22's rule.

---

## 11. WHAT WAS RE-TENSED, all two-part per S15

| site | what expired |
|---|---|
| `compose.ail:19` import block | *"`std/process` STAYS and is still used, by `check_snippet` and `run_snippet`. That asymmetry is the honest residue…"* |
| `compose.ail` `on_response_intercept` header | *"Seven of this hook's nine effect sites now go through `ctx.ports`; the two `exec` sites do NOT"* → all nine |
| `compose.ail` same block, closing paragraph | *"SO WHAT REMAINS AT THESE SITES IS THE ORIGINAL PARAGRAPH'S POINT AND NOTHING ELSE… it is what the routing item has to solve"* — solved, with the note that the shape question had **already** been answered by D23 and the paragraph had not noticed |
| `author_tools.ail:11` import block | *"`std/process` REMAINS… `rg` is not one of them, exactly as `ailang` is not"* — right about the tool name, and it was never about the seam |
| `author_tools.ail` `grep_impl` header | three items' worth of obstacle, each real when written; replaced by the rule the site must keep (exit 1 = no matches) and the history behind it |
| `authoring/dispatcher.ail:227` | *"the `exec` does not, for the reason given at `compose.check_snippet`"* |
| `run_declared_vs_performed.sh` | the `must_die_on` block, §8.1 |

Every one states what it said, who said it, and what measurement expired it. No comment was edited
in place without its predecessor being preserved.

---

## 12. GREEN — run, not reported

Named gates, each run individually:

```
discovery                        PASS   (92 ✓, 0 ✗)
compose_live_exec                PASS   (new)
world_state                      PASS
execution_program                PASS
program_persistence              PASS
declared_vs_performed            PASS   46/0
conformance                      PASS
ext_ambient_inventory            PASS   15/15 resolved
ext_ambient_inventory_selftest   PASS   0 failures
ext_call_inventory               PASS
ext_call_inventory_selftest      PASS
ext_hook_scope_selftest          PASS
anchors                          PASS
predicate_anchors                PASS
```

### 12.1 The full sweep

`make dst`, logged to a file rather than piped, with no tracked file touched while it ran.
**Exactly the three standing reds, all pinned to HEAD before this item, and nothing new:**

| target | finding | pinned since |
|---|---|---|
| `test_coverage` | `prompts_test.ail` 6 of 6 failed; `stale_skip_record` "Named test blocks not yet implemented" | D22 |
| `test_coverage_selftest` | 2 failures — `stale_skip_record` on an unexpected subject; `named_only.ail` also fired `failing` | D22 |
| `effect_inventory_selftest` | `agree=0 disagree=0` — *"compared ZERO modules… a pass-shaped absence, not a pass"* (`ailang iface` yields no parseable interface in this checkout) | D25 |

`effect_inventory_selftest` is **not** in the `dst` aggregate at `Makefile:199`; it was run
separately to confirm it is unchanged. Its red is the gate correctly refusing a pass-shaped absence,
exactly as D25 recorded.

Both new targets appear green inside the sweep: `discovery_dst PASS` and `compose_live_exec PASS`,
with `declared_vs_performed: 46 passed, 0 failed`.

---

## 13. WHAT ITEM 2 (C5's COMPOSE-BEARING PROFILE) INHERITS

1. **Compose has no `{Process}` ambient source and no ambient FS or Clock in any hook path.** Its
   entire ambient remainder is 8 sources in three disclosed classes (§8) — four `println`,
   registration's three, one AI. Nothing on the mediation side of clause 1 is owed by compose's
   *code* any more.
2. **The demonstration's subject is fully mediated, and there is now a template for driving it.**
   `compose_check_scenario` installs compose through `register_with_config` in a graded run,
   records, validates and replays. What it is not is a **profile** — it is a scenario in
   `discovery_dst`'s registry, so `absent_classes`' pins and the profile machinery are untouched.
   The profile is item 2's, and the wiring it needs is 30 lines of this scenario.
3. **`handle_compose_tool` is NOT deterministically reachable, and this is the profile's first
   obstacle** (§5.1). Compose's tool path calls `callStreamResult` — ambient AI — before it reaches
   anything routed. A profile that installs compose and exercises the *tool* rather than the
   *intercept* will perform a live provider call or need the AI disclosed at that boundary. The
   intercept path is the one with a deterministic loop today.
4. **`declared_vs_performed` no longer has a compose row that dies on anything**, so a future
   regression in compose's mediation is caught by a COMPLETES row rather than a dies-on row —
   the diagnostic arms in §8.1 are what tell the two site classes apart.
5. **The `matches` behaviour change (§4)** is in `author_tools`, on the author-tools path a profile
   with `author_tools: true` would exercise. It is annotated but has no fixture beyond the quiet-scan
   row; a profile that turns author tools on inherits the first real coverage of it.
6. **The bridge's `workdir: "."` / `timeout_ms: 0`** remain, and this item confirms they are inert
   for this tool: `run_native_call` passes `workdir` to the file tools and `run_process_result` never
   receives it, so a routed call runs where the process started, exactly as ambient `exec` did. Still
   on the maintenance register, now with the measurement attached.
7. **Door 3 is untouched** — compose stays HOOK-UNRESOLVED on `show`, and closes by disclosure plus
   an upstream filing, not by this item or by item 2.
