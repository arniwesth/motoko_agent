# Design: `herdr-dagr` as the delegation view — the extension as producer, not the model

Date: 2026-08-26. Revised 2026-08-30 twice (§3–§4 rewritten against the code, §5–§8 extended; then
a delegated codex review, 18 findings, folded in; see §9).
Status: **Design. Not implemented. No Linear issue yet.** **Depends on F-5 (the orphan story),
which is open** — see §8; the first draft said "depends on nothing in flight" and was wrong.
Provenance: `herdr-dagr` v0.3.1 installed and probed this session (§7 is measured). The mapping in
§3–§4 is design, derived from findings already in this project's
[`MEASUREMENTS-2026-08-22.md`](MEASUREMENTS-2026-08-22.md) and
[`DESIGN-motoko-as-delegate.md`](DESIGN-motoko-as-delegate.md). Everything §5 rests on is measured
in §7; what remains untested is listed explicitly at the end of §7.

---

## TL;DR

`herdr-dagr` renders a run graph from a JSON file that someone else must write. That writer — the
*producer* — should be **`motoko-ext-herdr` itself**, not the Motoko model.

The reason is specific, not stylistic. dagr's `evidence` tier is the field that distinguishes "the
delegate said done" from "something checked it", and **the validator does not enforce it** (§7.3). A
model-authored producer can stamp `verified` on nothing and pass `dagr check --strict` clean. An
extension-authored producer derives the tier mechanically from what `DelegateCheck` actually
observed, so the distinction survives. The unenforced field stops mattering when no model gets to
choose it.

The fit is not decorative. Three findings this project paid to discover are already contract
primitives:

| this project found | dagr already models it as |
|---|---|
| `DESIGN` §3.2 — the gate must be the answer file, never the agent state | `settled_unverified`: a terminal state for "nobody claimed anything" |
| P2-3 — `codex` reports success without delivering | `settled_unverified` at tier `heuristic`: the agent settled, no envelope arrived |
| `DESIGN` §3.3 — the delegate does not stop after answering | `liveness`, a field separate from attempt `state` |

## 1. What dagr is, stated so it cannot be oversold

A **representation kernel**. It watches a JSON file and draws it. It never writes run state, never
schedules, never retries, and cannot repair a wrong fact. Its own README: *"whoever produces the data
owns it."*

Consequences that bear on this design:

- It adds **no** orchestration capability. Everything it shows, Motoko already knew.
- Its value is entirely operator-facing: seeing a delegate tree without asking the orchestrator.
- Its honesty is exactly the producer's honesty. A wrong producer yields a confidently wrong graph,
  which is worse than no graph.

That last point is why §2 is a decision and not a formality.

## 2. Who writes the run file

| producer | how it works | verdict |
|---|---|---|
| **(a) `motoko-ext-herdr`** | `Delegate` / `DelegateCheck` write the file as a side effect | **recommended** |
| (b) the Motoko model, via the shipped `dagr-producer` skill | the LLM maintains the file each turn | rejected |
| (c) a sidecar tailing herdr state | separate process reconstructs the graph | rejected |

**(b) is rejected on measured grounds.** The tier is unenforced (§7.3), and a model producer will
fabricate under ordinary pressure — demonstrated this session: a hand-authored run file carried four
invented receipts, three stamped `◆ verified`, and `dagr check --strict` reported it clean. It also
costs tokens on every turn to restate facts the extension already holds exactly.

**(c) is rejected** because it contradicts [`RESEARCH`](RESEARCH-herdr-delegation-surface.md) §4.2
("herdr is the state store") by introducing a second one, and because the answer-file gate (`DESIGN` §3.2) is
not visible in herdr state at all — a sidecar would have to re-derive the one fact that matters and
would get it wrong in exactly the P2-3 way.

**(a) wins** because the extension already holds each fact at the moment it becomes true, needs no
model in the loop, and is deterministic and testable.

## 3. Lifecycle → contract mapping

`do_delegate` and `do_check` are the only two write points. Nothing else needs to touch the file.

The tables are organised by **what the code actually observes**, not by what dagr can express. The
2026-08-26 draft did it the other way round and produced rows the extension has no observation for
and one that would have fabricated a terminal state; the first revision then described one
`do_check` where the code has **two** (§9). There are two lifecycles, dispatched on the handle:

- **claude/codex** (`do_check`): `agent wait` → `agent get` → read answer file → four branches.
- **motoko** (`do_check_motoko`): read answer file **first** → `agent get` → `agent wait --until` →
  read answer file again. No `blocked` branch, no `is_settled` branch; the answer file is the only
  terminal signal, by design (`DESIGN` §3.2).

### 3.1 Identity

| fact | claude/codex | motoko |
|---|---|---|
| handle returned to the model | `mot-dlg-<ms>` (name given at `agent start`, never renamed) | `mot-dlg-<ms>@<pane>` (`types.motoko_handle`; there is no row to rename when the handle is minted) |
| dagr task `id` | the handle | `handle_name(handle)` — the pane-free half. The full handle is kept as `owner` |
| `locator` | `{pane: <split pane>, agent: <handle>}` | `{pane: <split pane>, agent: "motoko"}` — the row self-reports as `motoko` (MOT-120) |

The first draft said every delegate is renamed with `agent rename`; the recipe in `DESIGN` §3.1
was superseded by `types.motoko_handle` and the code renames nothing. The contract rule the draft
was protecting — pane ids never in `id` — still holds via `handle_name`.

Fields **not** emitted, and why:

- `kind`: `Delegate` has no task-category parameter (`herdr.ail`, `delegate_params`), so a review or
  a research task would be stamped `impl`. Omit it if the contract allows; otherwise emit the
  most neutral kind the v0.3.1 validator accepts. Adding a `task_kind` parameter is a schema change
  for the owner (§8).
- `model`: nothing selects or records one (`DESIGN-delegate-model-selection.md`). A guessed chip is
  a fabrication; omit until selection lands.

### 3.2 Write points, claude/codex

| moment in `herdr.ail` | contract write |
|---|---|
| `do_delegate`: after `pane split` but before `agent prompt` succeeds | **nothing.** Four failure branches follow the split (`agent start` fails, readiness gate fails, `agent prompt` fails — each closes the pane). A task appended at the split would survive as a phantom `working` row |
| `do_delegate`: `agent prompt` returned 0 | append task (`state: working`, `owner`) + attempt `a1`, `cause: initial`, `locator`, `liveness.prompt_acknowledged: false`; append `attempt_started` |
| `do_check`: `agent wait` fails, not `timeout` | classify the code (§4): `agent_not_found` → `lost`; anything else → no write |
| `do_check`: `agent get` fails | same classification |
| `do_check` branch 1: answer present and non-empty | settle `done` per §4 |
| `do_check` branch 2: `blocked` | task `blocked`; attempt stays `working`; latch `prompt_acknowledged: true` |
| `do_check` branch 3: `is_settled(status)`, no answer | settle `settled_unverified` per §4 |
| `do_check` branch 4: anything else, incl. wait `timeout` | refresh liveness (§3.4); task stays `working`. **A wait timeout observes nothing terminal** and never settles |
| reap via `pane close` | no state change. The close result is currently ignored on both success paths; the producer should read it and append a `note` event when the close failed rather than assert the locator is stale |

### 3.3 Write points, motoko

| moment | contract write |
|---|---|
| `do_delegate`: `pane run` returned 0 | append task + attempt as above. `prompt_acknowledged: false` — the row does not exist yet (~0.8 s) |
| `do_check_motoko`: early read, answer present | settle `done` per §4 — **only if the attempt is not already terminal** (§3.5) |
| `do_check_motoko`: `agent get` fails | classify (§4) |
| `do_check_motoko`: after `agent wait --until`, answer present | settle `done` |
| `do_check_motoko`: after wait, no answer | refresh liveness; stays `working`. The wait result is **not inspected** by the code today, so an `agent_not_found` from the wait is invisible — the producer must inspect it or issue a fresh `agent get` before writing liveness |
| startup `idle` (869 ms, `DESIGN` §3.2) | `working`, `prompt_acknowledged: false` — **never** a settle. This exception is motoko-only; for claude/codex `idle` *is* settled (`types.is_settled`) and the two must not share a table |

### 3.4 `liveness`, field by field

The contract's `liveness` block has three fields. dagr renders `last_output_at` as staleness
(`14m silent`), so a value the producer did not observe is a misreport, not a placeholder.

| field | source | emitted? |
|---|---|---|
| `prompt_acknowledged` | **latched**: initialised `false`, set `true` on the first observed `working`, `blocked` or `done`, never reset. (`status != idle` is wrong: `idle` is also the resting state after a completed turn, and a refresh would flip a live attempt back to unacknowledged) | yes |
| `last_output_at` | nothing — the extension never reads pane output | **omitted** |
| `queued_input` | nothing — the extension never reads the composer | **omitted** |

Liveness is written only from a **recognised, non-empty** status. `agent_status_of` and
`agent_pane_of` return `""` for missing or undecodable output, and `do_check`'s final branch
accepts that today; the producer must not turn a decode failure into `working`. On `""` leave the
graph unchanged and surface the decode error to the model.

Two consequences the operator should know. First, liveness moves only when the **model** calls
`DelegateCheck`; between polls the graph is frozen. Second, the field's type disagrees between
sources: the shipped `dagr-producer` skill says `queued_input` is a **count**; `CONTRACT.md` on
`main` says free text. Omitting it sidesteps the question; if ever emitted, match what the
**v0.3.1 binary** accepts.

### 3.5 Terminal writes are idempotent

`do_check_motoko`'s early read succeeds on **every** call once the answer exists; nothing consumes
the file. A second `DelegateCheck` on a finished delegate must not append a second
`attempt_settled`. Rule: the producer reads the current document, and settles an attempt only on
the transition non-terminal → terminal; a check against an already-terminal attempt writes nothing.

### 3.6 Re-delegation is a new task, not a retry — and that loses dagr's best signal

dagr's rework rendering (§7.5: a `✗` row with the retry beneath it) depends on attempt *n* carrying
`cause: sent_back | followup` with a `ref` to attempt *n−1*. The extension cannot produce that
today: a re-delegate is a fresh `Delegate` call with a fresh handle, so it becomes a new independent
task with its own `a1`. Every retry looks like new work; the rework count, which is arguably the one
thing the pane shows that the transcript does not, is always zero.

The fix is a tool-schema change, not a producer change: an optional `retry_of: <handle>` parameter
on `Delegate`. When present, the producer appends attempt *n+1* to the **existing** task with
`cause: followup, ref: <prev attempt>` instead of opening a new task. The model chooses whether to
pass it; the extension records it mechanically. Not required for a first landing; §8 lists it.

## 4. Evidence tiers, derived mechanically

This is the load-bearing table. Each row is keyed to an observation the code already makes; none
requires judgment.

| what was observed | attempt `state` | `evidence` | note |
|---|---|---|---|
| answer file present and non-empty (either lifecycle) | `done` | `reported` | see §4.2 for why not `asserted`, why not `verified`, and the caveat that the file may itself report failure |
| answer file present **and** independently checked | `done` | `verified` | only tier that may claim mechanical proof; no code path produces it — §4.1 |
| claude/codex: agent settled, **no answer file** | `settled_unverified` | `heuristic` | P2-3. Not a soft `done`, and not `failed`: nothing observed says the work failed, only that no envelope arrived |
| `agent wait` **or** `agent get` fails with `agent_not_found` | attempt `lost` → task `failed` | — | M-extra-6; keep the attempt, it is the record. `types.ail` documents that a gone agent surfaces from the *wait* (2 ms), so classifying only `agent get` misses the primary path |
| `agent wait` / `agent get` fails with any other code (socket, timeout-that-is-not-`timeout`, unknown) | — | — | a herdr error, not a delegate outcome: **write nothing** |

Rows deliberately **absent**, with the reason:

- *Completion claimed in prose only → `asserted`.* Reading a prose claim requires reading the
  pane screen, which neither check path does. If a screen read is ever added, it earns the row
  back; until then nothing in this producer emits `asserted`, and the TL;DR row for P2-3 says
  `settled_unverified`, not `asserted`, for that reason.
- *Wait timeout with no answer and no settle → `settled_unverified`.* This would have stamped a
  terminal `≈` on a delegate that finishes ten seconds later, contradicting the code (a timeout
  falls to the working branch, "check again rather than assuming it is stuck") and §3.3's last
  row. A timeout is a liveness refresh, nothing more.

### 4.1 Motoko cannot honestly emit `verified` today, and the graph should say so

Nothing in the current path independently checks a delegate's answer. The answer file's *existence*
is a claim by the delegate, not proof of its content. So every successful delegation settles at
`reported` (`◇`) and the pane will be visibly short of `◆`.

That is the correct and useful result. A wall of `◇` is an accurate statement that **Motoko does not
verify delegate output** — which is precisely the gap
[`023_hybrid_verification_cris`](../023_hybrid_verification_cris/) exists to close. When a
verification step lands, it earns `verified` and the pane changes on its own. The view becomes a
progress indicator for that project rather than decoration for this one.

Resist any temptation to map answer-file-present to `verified`. It would erase the one distinction
that motivated adopting dagr.

### 4.2 Why the answer file rates `reported` and not `asserted`

`CONTRACT.md` defines `reported` as "the actor asserted it through a typed envelope" and `asserted`
as "bare claim, no structure". The answer file is free text — the code checks
`rd.present && rd.content != ""` and parses nothing (the first draft said "parses"; it does not).
It is nevertheless more than a bare claim: the delegate had to perform a specific structural act —
write a file at a path it was given — rather than say a sentence, and P2-3 measured that this act
is exactly what an unattended `codex` fails to perform while *saying* it succeeded. The
file-at-path is the envelope; its contents are the payload. `reported` is the honest tier, and the
`receipt` should be the answer path so a reader can tell which envelope was meant.

**The caveat, which is a real trade-off and not settled here.** The answer protocol asks for
arbitrary Markdown (`types.task_wrapper_prompt`), and a delegate can write a file that *says* "I
could not do this". The code cannot tell that from success, so the producer would write `done ·
reported` over a delivered failure report. Two honest ways out: (a) a typed answer envelope with an
explicit `outcome: done|failed` line that the extension parses — a delegate-protocol change that
touches the wrapper prompt, both check paths and every existing measurement; or (b) keep the
free-text file and accept that `reported` means "delivered an answer", not "succeeded". (b) is
the first landing; (a) is for the owner (§8), and is also what would let a delegate's own
`failed` be recorded at all.

## 5. File placement, sandbox, and recursion

**Location.** One canonical path, used everywhere below: `<dagr_dir>/run-<own_pane>-<session>.json`,
with `dagr_dir = ${MOTOKO_WORKDIR}/.dagr` and its `.tmp` sibling in the same directory. `own_pane`
is `HERDR_PANE_ID` (already in `HerdrConfig`); `<session>` is the clock at registration, because
`own_pane` alone is not a run identity — restarting Motoko in the same pane would otherwise reopen
and append to the previous run's file. The dagr pane reads it via `DAGR_RUN`. The plain
`.dagr/run.json` the first draft named is **not** used; see the multi-writer paragraph below.

**Initialisation, and the guard the delegate path already has.** `MOTOKO_WORKDIR` being readable
does not prove it lies inside `ctx.workdir`, and `do_delegate` already refuses before its first
`dir_make` when `path_within(ctx.workdir, cfg.work_dir)` fails, because a write outside
`AILANG_FS_SANDBOX` terminates the run rather than erroring. The producer gets the same treatment:
`dagr_dir` is a `HerdrConfig` field, checked with `path_within` at first use, created with
`p.dir_make`. First write of a session creates the file with an empty task list; a file that
exists but does not parse is **not** overwritten — the producer stops writing for the session and
tells the model once, because silently replacing a document is the failure §1 warns about.

**Sandbox — safe, and for a reason this project already settled.** [`DESIGN`](DESIGN-motoko-as-delegate.md)
§3.4 established that Motoko's own `std/fs` writes are **fatal** outside `AILANG_FS_SANDBOX` and fine
inside. The workdir is inside, so the producer uses Motoko's own fs and needs no subprocess escape.

**Write discipline, and the one real friction point.** The shipped skill's loop is
validate-then-publish: check the candidate with `dagr check`, then atomically rename it over the
live file. This producer's transaction is **encode-then-atomically-publish**: it writes the
`.tmp`, then `mv`s it, and runs **no schema validation at runtime** — the document is produced by
deterministic code, and its validity is established once, in CI (§6), not per write. The atomic
rename is what keeps the pane from observing a half-written document; it does not, on its own,
keep it from observing a wrong one. If `mv` fails (`exec` returns `Err`): the delegation itself
has already succeeded and is **not** failed on the view's account; the live file stays at its
previous version; the `.tmp` is removed; and the tool result carries one line saying the view is
stale. The next successful publish catches up because every publish rewrites the whole document.

**`std/fs` has no rename or move** — verified four ways in §7.6, including by compiler rejection.
`writeFile` truncates in place, so writing `run.json` directly is a torn-read risk on every update:
dagr reloads on mtime and would render, or reject, a partial document.

Three ways out, in preference order:

1. **`mv` via the `Process` effect — verified working, and cheap.** `register_with_config` already
   declares `Process` and `run_herdr` already shells out, so no new effect is needed.
   `writeFile(tmp)` then `exec("mv", [tmp, live])` was run for real from AILANG and publishes
   correctly, including with `AILANG_FS_SANDBOX` set and both paths inside it (§7.7). Measured cost
   **≈0.8 ms per publish** — negligible beside a `DelegateCheck` poll. Adds a dependency on `mv`
   being on `PATH`; `exec` returns `Result`, so handle `Err` rather than assuming it.
2. **Accept torn reads.** Cheapest, and wrong — it reintroduces exactly the "confidently wrong view"
   failure this design exists to avoid.
3. **Ask AILANG for `renameFile`.** The correct long-term fix; a stdlib gap, not a Motoko bug.
   **Filed: [sunholo-data/ailang#897](https://github.com/sunholo-data/ailang/issues/897)** (message
   `msg_20260826_071324_a929a782`). Note it needs runtime work, not just an export — the binary
   carries no `_fs_rename` builtin. Until it lands, (1) is the design; if it lands, (1) collapses to
   a single call and the `Process` effect drops out of the publish path.

With (1) measured, this is a known small cost rather than the open risk the first draft of this
section described.

**One writer per file is not only a recursion question.** Two operator Motoko sessions in the same
checkout — two panes, one repo, which is an ordinary way to use herdr — both resolve
`${MOTOKO_WORKDIR}/.dagr/run.json` and clobber each other with no recursion involved. Keying the
file by the producer's own pane, `.dagr/run-<HERDR_PANE_ID>.json`, makes every writer unique by
construction; `HerdrConfig.own_pane` already carries the id. The dagr pane then needs `DAGR_RUN`
pointed at the right file, which is one line in the plugin action's environment. This is why the
canonical path above is keyed by pane and session, with no plain `run.json` fallback.

**Recursion.** dagr's recursive `projects` map onto delegation depth cleanly, but the contract wants
**one writer per file**. With recursion defaulted off at depth 1 (§6 of `DESIGN`), there is exactly
one writer and the question does not arise. Above depth 1 the honest options are:

- one file per orchestrator pane (`.dagr/run-<pane>.json`) — single-writer safe, but N partial graphs;
- one merged file — one unified graph, but concurrent writers, which the contract forbids.

There is no third option without a merge step that does not exist. **Do not close this here** — the
handoff's *Stop and report* list reserves recursion depth for the owner, and this design must not
close it by implementation.

## 6. Costs and failure modes

- **Whole-file rewrite per event.** The document is append-only in content and rewritten entire on
  each write, so a run with *n* settlements writes O(n²) bytes. Fine for a dozen delegates; not fine
  for a long-lived orchestrator. Needs a cap or rotation before it runs unattended.
- **dagr absent must be a no-op.** Producing the file costs nothing when nobody reads it, so the
  producer should always write and never require the binary — mirroring `register.ail`'s existing
  gate philosophy (compute `provided_tools`; offer nothing rather than something that fails).
  This deliberately overrides the shipped skill's rule "no validator, no writing": that rule guards
  against a model improvising a document, and this producer is deterministic. The guarantee moves
  to CI instead — a test that runs the producer over a scripted lifecycle for **both** check paths,
  including a repeated check on a finished delegate (§3.5) and each post-split setup failure
  (§3.2), and checks every published document with `dagr check --strict --json` against a
  pinned v0.3.1 binary. CI already installs Z3
  for the contract gate; a pinned dagr download is the same shape.
- **A task the model stops polling never settles.** `do_check` is the only terminal write point.
  A model that calls `Delegate` and moves on — which the tool description permits — leaves the task
  `working` for ever, with no `attempt_settled` and no stale-liveness signal (§3.1). This is a
  *different* misreport from the F-5 orphan: there the pane outlives Motoko; here Motoko may still
  be running and simply not asking. Neither Motoko exit nor a later session writes anything, and
  there is no ABI slot for "session ended" — 017 prices adding one at 16 packages. The first landing
  should accept this and say so in the pane's own words (a `note` event on `Delegate`: "settles only
  on `DelegateCheck`"); a settle-on-exit hook is an ABI decision for the owner, not for this design.
- **Per-check cost.** Every `DelegateCheck` becomes read → modify → `writeFile(tmp)` → `mv`. Measured
  ≈0.8 ms for the publish (§7.7) plus one file read, inside a call that already blocks up to
  `check_wait_ms` (20 s) of the 30 s process wall. Negligible, but it is inside that wall.
- **Pinned install.** `herdr plugin install aemrebarut/herdr-dagr` **fails** on a machine without
  Cargo whenever `main` is ahead of the release tag. `--ref v0.3.1` is required (§7.1).
- **Contract drift.** Emit `"dagr": 3`. The v0.3.1 binary reads v1/v2 and writes v3; its README is
  from `main` and documents flags the binary rejects (§7.4).

## 7. Measured this session (2026-08-26)

7.1 **Install.** Unpinned install fails: `checkout 52991f9a95a2 does not match v0.3.1 release
revision c0f8b333a92d, and Cargo is not installed`. `--ref v0.3.1` succeeds; prebuilt
`aarch64-unknown-linux-musl` binary, no Rust needed.

7.2 **Structural invariants hold.** 9 adversarial mutations of a valid document; 8 rejected under
`--strict` — claiming `done` on a working attempt (`E150`), deleting a send-back to clean up history
(`E171`), a cause referencing a nonexistent attempt (`E134`), a dependency cycle (`E122`), a bool
where a count belongs (`E001`), outcome/state mismatch (`E141`), an attempt ending before it starts
(`E181`), a working attempt with no locator or liveness (`W204`/`W208`).

7.3 **The evidence tier is not enforced.** The one mutation that passed. `evidence: "verified"` with
an absent receipt, an empty receipt, and the receipt `"trust me bro"` all exit 0 under `--strict`.
The tier is producer-asserted and never validated. This is the finding §2 turns on.

7.4 **README/binary drift.** `dagr view --compact` → `unexpected argument`; the README documents it,
and draws the gate join as `⋈` where v0.3.1 renders `◎`. Re-checked 2026-08-30: v0.3.1 (2026-08-21)
is still the newest tag, so the pin stands. `CONTRACT.md` on `main` and the shipped `dagr-producer`
skill also disagree on `queued_input` (string vs count) and on `locator` (`{pane, agent}` both
required vs `{pane}` alone). Neither was tested against the binary; §3.1 omits `queued_input`, and
the producer should emit both locator fields since it has both.

7.4a **The unenforced tier is by design, not an oversight.** `CONTRACT.md` says outright that dagr is
"a representation kernel, not an enforcement kernel" and that `receipt` is optional. §7.3 stands as a
measurement, but §2's argument does not rest on dagr having a bug: it rests on the tier being
producer-asserted, which the contract states as policy.

7.5 **Renderer.** Snapshots at widths 72/100/150: widest display column equals the budget exactly,
zero overflow lines. Send-back history renders as a `✗` row with the retry appended beneath it —
nothing repaints.

7.6 **`std/fs` cannot rename — verified four ways.** AILANG v0.33.0.

| method | result |
|---|---|
| stdlib source on disk, both copies (`~/.local/share/ailang/std/fs.ail`, `ailang/std/fs.ail`) | identical, 136 lines, 18 exports, no rename/move |
| every `std/*` module grepped for `rename`/`move` | only `removeFile` matches |
| `_fs_*` builtins in the `ailang` binary (`strings`) | 21 builtins, **no `_fs_rename`** — the runtime has no primitive to expose |
| compiling `import std/fs (X)` for X in rename, renameResult, renameFile, renameFileResult, renamePath, moveFile, move, mv | all 7 rejected: `IMP010: symbol 'X' not exported by 'std/fs'` |

The docs MCP was *not* treated as authoritative here: it answered `unknown_version` for v0.33.0 and
served `latest` instead, so it cannot speak to the installed version. The on-disk source, the
binary's symbol table, and the compiler can, and they agree.

The full export set is `appendFile`, `appendFileBytes`, `appendFileResult`, `fileExists`, `isDir`,
`isFile`, `listDir`, `mkdir`, `mkdirAll`, `mkdirAllResult`, `readFile`, `readFileBytes`,
`readFileResult`, `removeFile`, `removeFileResult`, `writeFile`, `writeFileBytes`,
`writeFileResult`.

7.7 **The `mv` publish transaction works from AILANG, and costs ~0.8 ms.** `writeFile(tmp)` +
`exec("mv", [tmp, live])` executed for real: tmp consumed, live contains the payload. Repeated with
`AILANG_FS_SANDBOX` set and both paths inside it — still fine, consistent with `DESIGN` §3.4.
Timings (`ailang run`, best of two): startup-only 15–19 ms; 20 publish cycles 34 ms; 200 cycles
168–181 ms — i.e. **≈0.8 ms per publish** net of startup.

**Not measured:** whether the pane redraws on republish (observed only that it waits for a missing
file); the `m` composer round-trip to `run.orchestrator`; behaviour when `run.json` and its `.tmp`
straddle a filesystem boundary (`mv` stops being atomic there — keep both in `.dagr/`).

## 8. Recommendation

Adopt (a). Land it as its own change, with two things settled first:

1. **Publish via `mv` through the `Process` effect** (§5). `std/fs` cannot rename (§7.6), and
   writing `run.json` in place is a torn-read risk. The workaround is measured and cheap
   (§7.7), so this is settled, not open. The stdlib gap is filed upstream as
   [ailang#897](https://github.com/sunholo-data/ailang/issues/897); do not block on it.
2. **Leave recursion to the owner** (§5). Depth-1 default makes the producer trivially
   single-writer; the merged-graph question should be answered by the owner, not by whoever
   implements this. Same-workdir concurrent sessions are *not* left open: key the file by own
   pane (§5).

And three items the implementer should hand back rather than decide:

3. **`retry_of` on `Delegate`** (§3.2). Without it the pane never shows rework. It is a tool-schema
   change visible to the model, so it is a product decision, not a producer detail.
4. **Settle-on-exit** (§6). Whether a task the model stopped polling should be settled by something
   other than `DelegateCheck` is an ABI-slot question; the first landing writes a `note` and stops.
5. **`lost` classification** (§4). Which `failure_code` values mean "the pane is gone" versus "herdr
   is unwell" must be measured before the `lost` row is wired, or the graph will bury transient
   socket errors as dead attempts. Until measured, a non-zero `agent wait`/`agent get` writes
   nothing.
6. **Typed answer envelope** (§4.2). Whether the delegate protocol should carry an explicit
   `done|failed` outcome. Without it a delivered failure report renders as `done · reported`.
7. **`task_kind` on `Delegate`** (§3.1). Without it no task kind can be emitted honestly.

And one code fix that stands on its own, independent of dagr: `do_check` (claude/codex) calls
`agent wait` and `agent get` **before** reading the answer file, so a delegate that wrote its
answer and whose pane was then closed — by the operator, by a crash, by M-extra-6 reaping from
another session — returns `agent_not_found` and the answer is never read. `do_check_motoko`
already does the early read. Filed as its own Linear issue; the producer's §3.2 table assumes it
is fixed.

Sequence it *after* the F-5 orphan story — which makes F-5 a **dependency**, and the status
block now says so. A run file that records delegates which then outlive
Motoko produces a graph asserting work is in flight when nothing is running — the same class of
misreport this project has spent its measurements eliminating.

The honest summary of the benefit: this buys the operator a live, self-maintaining view of the
delegate tree at near-zero token cost, and buys the project a visible, continuously updated record
of how much delegate output is actually verified. It buys no new capability.

## 9. Revision note (2026-08-30)

The 2026-08-26 draft was reviewed against `herdr.ail`, `types.ail`, `CONTRACT.md` and the
installed toolchain. §1, §2, §5's publish transaction, §7 and §8's ordering survived unchanged.
What did not:

- §4 had an `asserted` row ("completion claimed in prose") that no code path can observe, and a
  timeout row that would have written a terminal `settled_unverified` for a delegate still working.
  Both removed, with the reason recorded in §4.
- §4's `reported` row claimed the answer "parses"; the code checks non-emptiness only. §4.2 now
  gives the actual argument for the tier.
- §3 said "refresh `liveness`" as if all three fields were available; two are not (§3.1).
- §3 never said what the task `id` is; it is the handle.
- `lost` was mapped from any `agent get` failure; now gated on classification (§4, §8 item 5).
- Re-delegation was unmapped; it silently loses dagr's rework signal (§3.2, §8 item 3).
- The no-poll case was conflated with F-5; it is separate and Motoko-side (§6, §8 item 4).
- Multi-writer was treated as a recursion-only concern; it is not (§5).
- `std/fs` rename re-verified absent at v0.33.0; ailang#897 not landed.

Second pass, same day, from a codex review delegated through `motoko-ext-herdr` itself (18
findings, all checked against the code before adoption):

- The revised §3 described one `do_check`; there are two, with different terminal signals
  (§3.2 vs §3.3). The startup-idle exception is motoko-only.
- Nothing is renamed; the `agent rename` recipe is superseded by `types.motoko_handle`. Task id
  is `handle_name` (§3.1).
- Task creation moved from "pane spawned" to "prompt/run succeeded" — four failure branches sit
  between them (§3.2).
- `prompt_acknowledged` is latched, not recomputed (§3.4). Liveness requires a decoded status.
- `kind` and `model` are omitted rather than guessed (§3.1).
- `lost` is classified from `agent wait` as well as `agent get`; the motoko path's ignored wait
  result is called out (§3.3, §4).
- Terminal writes made idempotent (§3.5). `pane close` result to be read, not assumed (§3.2).
- TL;DR row for P2-3 corrected from `asserted` to `settled_unverified` (it contradicted §4).
- One canonical path, keyed by pane **and** session; `path_within` guard and init/parse-failure
  policy added (§5). "Validate-then-publish" renamed to what the transaction actually is, with
  `mv` failure semantics (§5).
- F-5 promoted from "sequence after" to a stated dependency (header, §8).
- Answer-file-means-`done` caveat and the typed-envelope trade-off recorded, left to the owner
  (§4.2, §8 item 6).
