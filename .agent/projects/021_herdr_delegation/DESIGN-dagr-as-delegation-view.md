# Design: `herdr-dagr` as the delegation view — the extension as producer, not the model

Date: 2026-08-26
Status: **Design. Not implemented. No Linear issue yet.** Depends on nothing in flight; see §8.
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
| §3.2 — the gate must be the answer file, never the agent state | `settled_unverified`: a terminal state for "nobody claimed anything" |
| P2-3 — `codex` reports success without delivering | `asserted`: a prose claim carrying no receipt |
| §3.3 — the delegate does not stop after answering | `liveness`, a field separate from attempt `state` |

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
("herdr is the state store") by introducing a second one, and because the answer-file gate (§3.2) is
not visible in herdr state at all — a sidecar would have to re-derive the one fact that matters and
would get it wrong in exactly the P2-3 way.

**(a) wins** because the extension already holds each fact at the moment it becomes true, needs no
model in the loop, and is deterministic and testable.

## 3. Lifecycle → contract mapping

`do_delegate` and `do_check` are the only two write points. Nothing else needs to touch the file.

| moment in `herdr.ail` | contract write |
|---|---|
| `do_delegate` spawns the pane | append task (`kind: "impl"`, `state: "working"`, `owner: <handle>`) + attempt `a1`, `cause: initial`; append `attempt_started` |
| `agent rename` to `mot-dlg-<ms>` (§3.1) | that handle is the task `owner`; the pane goes in `locator`, never in `id` |
| the model the delegate was started on | attempt `model`, as a short `model·effort` chip — **a guess today**; nothing selects or records one. See [`DESIGN-delegate-model-selection.md`](DESIGN-delegate-model-selection.md) |
| `do_check` — still running | refresh `liveness`; task stays `working` |
| `do_check` — terminal | settle the attempt per §4; append `attempt_settled` |
| reap via `pane close` (§3.3) | no state change; reaping is not a settlement |
| delegate never started (idle @ 869 ms, §3.2) | `working` with `liveness.prompt_acknowledged: false` — **never** a settle |

The last row is §3.2's trap expressed in the contract. `is_settled("idle")` returning true is exactly
the bug the contract's projection rule forbids: task state is a projection over *attempts*, and an
attempt that never produced an outcome cannot be terminal.

## 4. Evidence tiers, derived mechanically

This is the load-bearing table. Each row is a `DelegateCheck` observation; none requires judgment.

| what `do_check` observed | attempt `state` | `evidence` | note |
|---|---|---|---|
| answer file present, non-empty, parses | `done` | `reported` | a typed envelope: the delegate wrote the file it was told to |
| answer file present **and** independently checked | `done` | `verified` | only tier that may claim mechanical proof; see §4.1 |
| agent row settled, **no answer file** | `settled_unverified` | `heuristic` | P2-3. Not a soft `done` |
| completion claimed in prose only | `done` \| `failed` | `asserted` | e.g. codex's `# Unable to complete task` |
| pane vanished mid-work | attempt `lost` → task `failed` | — | M-extra-6; keep the attempt, it is the record |
| timeout with no answer and no settle | `settled_unverified` | `heuristic` | reason records the wall-clock bound |

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

## 5. File placement, sandbox, and recursion

**Location.** `${MOTOKO_WORKDIR}/.dagr/run.json`. `MOTOKO_WORKDIR` is already read in `register.ail`.

**Sandbox — safe, and for a reason this project already settled.** [`DESIGN`](DESIGN-motoko-as-delegate.md)
§3.4 established that Motoko's own `std/fs` writes are **fatal** outside `AILANG_FS_SANDBOX` and fine
inside. The workdir is inside, so the producer uses Motoko's own fs and needs no subprocess escape.

**Write discipline, and the one real friction point.** The contract requires validate-then-publish
via atomic rename: write `run.json.tmp`, then `mv` over `run.json`, so the pane never observes a
half-written or invalid document.

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
and draws the gate join as `⋈` where v0.3.1 renders `◎`.

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
   implements this.

Sequence it *after* the F-5 orphan story. A run file that records delegates which then outlive
Motoko produces a graph asserting work is in flight when nothing is running — the same class of
misreport this project has spent its measurements eliminating.

The honest summary of the benefit: this buys the operator a live, self-maintaining view of the
delegate tree at near-zero token cost, and buys the project a visible, continuously updated record
of how much delegate output is actually verified. It buys no new capability.
