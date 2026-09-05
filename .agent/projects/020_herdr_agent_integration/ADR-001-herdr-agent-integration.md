# ADR-001: How does herdr come to recognise Motoko as an agent, rather than as an unidentified process in a pane?

Date: 2026-08-22
Status: **Accepted.** The owner approved building it in the same message that asked for this record;
D3 was put to them as the one open call and was not separately re-litigated, so it is recorded here
as decided-by-approval rather than as an adjudicated fork. Implemented in the same change:
`src/tui/src/herdr-agent-state.ts` (new), one call site in `src/tui/src/ui.ts`, three in
`src/tui/src/index.ts`, and `src/tui/src/herdr-agent-state.test.ts` (11 cases; 14 after the
M6 fix recorded below).
Grounded at: branch `arniwesth/mot-101-agentcli`, HEAD `d992d73`, against **herdr v0.8.2**.

Grounding verified 2026-08-22:
- herdr v0.8.2 is what `.devcontainer/agent_confined/versions.env` pins and what the image installs.
  Every quotation below is from that tag's documentation source, not from the rendered site.
- `src/tui/src/ui.ts:790` declares `RunState`; `setRunState` at `:2263` is the sole mutator of
  `waitState`, reached from 12 call sites. (Both line numbers are post-change: this change inserts an
  import at `:46` and shifts everything below it. Two drafts of this record cited stale numbers —
  first the pre-change ones, then ones invalidated by a later one-line comment edit in the same
  file. That is why the body below cites **symbols** and this block is the only place holding line
  numbers: a number is right for one revision, a symbol for as long as it exists.)
- D7's compile-time contract was **tested, not assumed**: adding a sixth `RunState` member and
  rebuilding fails with `src/ui.ts(2278,27): error TS2345: Argument of type 'RunState' is not
  assignable to parameter of type 'MotokoRunState'.` The member was then removed and the build
  re-verified clean.
- `bun run build` (tsc) passes. `herdr-agent-state.test.ts` passed 11/11 at the time of writing and
  passes **14/14** after the M6 fix below. The full suite is 220 passed / 0 failed, with 5 suites
  failing **to load** on a pre-existing bun-jest/`depd` incompatibility reached through `express`;
  none of the five import anything this change touches.
- **Measured inside herdr on 2026-08-22**, in `agent_confined` (image `ab3ed0fab4f6`), pane `w1:p5`
  of the same session this record was written from, against herdr v0.8.2 and Motoko started by
  `herdr pane run w1:p5 'make run'`. Five runs. See *Consequences → what was measured*, and the
  *Corrections* section for the three claims the measurements falsified. The measurements changed
  the code once: **M6**, a sequence-number defect that made every Motoko after the first invisible
  to herdr in a given pane.

Relates to:
- `../019_agent_confined/` and
  `.devcontainer/agent_confined/` — the container this runs in, and where herdr became the session
  layer. §5 of that research is the target state this is one layer of.
- `../018_agentcli_delegation/RESEARCH-agentcli-delegation-surface.md` — the consumer. D1 here is
  what makes `herdr agent wait --until idle` a usable primitive against a *Motoko* pane, not only
  against a delegate's.
- `../009_motoko_dst_execution/`, `src/core/dst_event_vocabulary.ail` — Motoko's own typed event
  vocabulary. Deliberately **not** the source of truth here; D2 explains why.

---

## Context / the question

Motoko now runs inside `agent_confined` with [herdr](https://herdr.dev) as the session layer. herdr's
whole proposition is the sidebar: several agents running at once, each rolled up to a state —
`working`, `idle`, `blocked`, `done` — so an operator can see which one needs a decision without
polling panes by hand.

Out of the box, Motoko is not in that picture. herdr sees an unrecognised foreground process — `bun`,
or the `make` above it, depending on how the pane was started; nobody has looked, and it does not
matter, because neither is an agent herdr knows — and treats the pane as an ordinary terminal.
Claude Code, Codex and OMP running in adjacent panes all get rows; Motoko, in its own repository's
container, does not.

The question is what it takes to change that, and — since there turn out to be two mechanisms with
very different properties — which one Motoko should use.

## What herdr actually does, measured

herdr assigns each pane exactly one **status authority**, by one of two routes.

**Screen manifests.** herdr identifies the foreground process, reads the live bottom-buffer
snapshot, and evaluates TOML rules against it to classify state. This is how Claude Code, Codex,
Cursor, Grok and most of the list work. Manifests are bundled in the binary, patched from
herdr.dev at runtime, and can be replaced locally at
`~/.config/herdr/agent-detection/<agent>.toml`.

**Lifecycle reports.** An integration reports semantic state over herdr's local socket. When one is
installed and actively reporting for a pane, herdr treats it as authoritative and **stops running
screen detection for that pane** — deliberately, to avoid two competing sources of truth. Six agents
have this today: Pi, OMP, Kimi Code CLI, OpenCode, Kilo Code CLI, MastraCode.

Two sentences in that documentation decide this ADR between them.

> Remote manifests patch detection rules for agents Herdr already knows how to identify. **Adding a
> completely new agent still requires a Herdr binary update** for process detection, labels, and
> integration behavior.

> Custom integrations can also report state that is not visible in the native terminal UI. **They do
> not need to be built into Herdr or use a recognized agent executable.**

The first closes the manifest route to Motoko. The second opens the other one, with no herdr change
at all.

## Options considered

**A. Do nothing.** Motoko's pane stays an ordinary terminal. The status line inside the pane already
shows `state: thinking | step 4 | elapsed 12s`, so the information exists — it is just invisible to
the sidebar, to rollups, and to `herdr agent wait`. Rejected once 018 is taken seriously: a
delegation surface where every delegate is observable except Motoko itself is the wrong asymmetry.

**B. A local agent-detection manifest** at `~/.config/herdr/agent-detection/motoko.toml`. This is the
obvious-looking answer and it does not work: local overrides *replace* the manifest for an agent
herdr already identifies. There is no `motoko` to override, and process detection and labels live in
the binary. Rejected as measured-impossible, not as undesirable.

**C. Masquerade — `HERDR_AGENT=claude motoko`.** herdr's documented escape hatch for sandbox
wrappers, which tells it to apply an existing agent's screen manifest to a hidden process. It would
produce a row, labelled `claude`, whose state came from pattern-matching Claude Code's UI against
Motoko's TUI. Rejected: it lies about which agent is running, and its state would be wrong in a way
that is difficult to notice.

**D. A custom lifecycle integration.** Motoko reports its own state with
`herdr pane report-agent`. No herdr change, and it lands in the *stronger* authority class.

**E. Upstream native support in herdr.** A binary change adding `motoko` to process detection, the
kind list and the integration installer. Not mutually exclusive with D — and D is its prerequisite
in practice, since it is what produces the operating experience to upstream. Deferred, not rejected.

---

## Decision

**D1 — Motoko reports its own lifecycle to herdr as a custom integration (option D).** It becomes a
herdr *lifecycle authority*, so herdr takes these reports as truth and runs no screen detection for
the pane. Worth stating because it is counter-intuitive: this puts Motoko in a **stronger** class
than Claude Code or Codex, which are screen-manifest agents whose integrations supply session
identity only. Motoko does not guess at its own state from pixels, so herdr should not either.

**D2 — state transitions are reported from exactly one place: `ui.ts`'s `setRunState`.** That
function is the single mutator of `waitState`, reached from all 12 transition sites, and it already
short-circuits no-ops. One call site there makes the sidebar's view of Motoko and the status line's
view *the same fact*, rather than two derivations that can drift.

Two further reports exist and are deliberately **not** transitions: `initHerdrReporter` emits an
initial `idle` at startup, and `index.ts` emits the D6 session path. The initial one is not redundant
with the funnel — Motoko *starts* in `idle` and `setRunState` returns early on an unchanged state, so
without it the pane would not become an agent row until the user's first task, which is exactly when
they are watching the sidebar to see that it started.

The alternative source was Motoko's typed DST event vocabulary in AILANG, which is richer and is the
repository's usual answer to "where does truth live". Rejected for this purpose: herdr has four
reportable states, the mapping needed is exactly the one the TUI already computes, and routing it
through the AILANG core would put a UI concern in the runtime and add a second place where run state
is decided.

**D3 — `error` maps to herdr's `blocked`.** This is the one genuine judgment call, and it is a
deliberate slight stretch of herdr's definition. herdr documents `blocked` as "recognized an
approval or question UI"; Motoko has no approval UI whatsoever — that absence is precisely why 018
runs delegates with permission bypass on. The candidates were:

- `blocked` — rolls up to the pane's tab and workspace (herdr: "a blocked agent makes its pane, tab,
  and workspace look blocked") and satisfies `agent wait --until blocked`. Semantically loose,
  behaviourally right: a failed run is what an operator scanning the sidebar most needs to be pulled
  towards.
- `unknown` — documented as "an agent is present but Herdr cannot classify its lifecycle
  confidently". Honest about the vocabulary, and wrong in effect: it makes a failed run
  indistinguishable from a detection gap, which is the opposite of surfacing it.
- `idle` — accurate in the narrow sense that Motoko is waiting for input, **but** it silently hides
  failures. Rejected outright.

Chosen: `blocked`, with the reason in `--message`.

**A limitation this decision does not fully deliver, found while reviewing it.** How long `blocked`
survives depends on which error path ran, and only one of the two behaves as the argument above
assumes:

- the **in-band `error` event** (`AgentUI.handleEvent`'s `case "error"`, runtime still alive) sets
  `error` and then only marks `taskDone` and focuses the input. Nothing re-idles it, so the row
  stays blocked until the user submits the next task. This is the case D3 is written for, and it
  works.
- the **runtime-exit recovery path** (`index.ts`'s `errorOccurred` branch) calls
  `ui.setAwaitingTask(true)`, which itself calls `setRunState("idle")`. The blocked report is
  therefore superseded by an idle one, possibly within the same second — the sidebar ends up
  showing the state option `idle` was rejected for showing.

That second path is not fixed here, because making `blocked` sticky in the reporter would lie about
Motoko's actual readiness for input, and changing Motoko's own recovery semantics is a product
decision this record should not smuggle in.

**Measured 2026-08-22 (M8): the blocked row survives that path for 92 ms.** The softener this record
originally offered — that herdr renders an unfocused idle row as `done`, so a failed background run
still reads as "something finished here" — is exactly the problem at that duration: a crashed run
presents as a *completed* one, which is the strongest form of what `idle` was rejected for. So the
limitation is not softened, it is sharpened, and "accept it" is no longer available. The first path
is unaffected and works as argued: `blocked` arrives 244 ms behind the state change and stays.
The surviving remedy is a change to Motoko's recovery semantics, escalated as **MOT-117**.

**Revisit the whole mapping if Motoko gains a real approval prompt** — at that point `blocked` has a
true occupant, and `error` needs its own treatment (a `report-metadata` display token over an `idle`
state is the likely shape).

**D4 — reporting is inert outside herdr and cannot break or stall the TUI.** Three properties, each
a requirement rather than a nicety, because this code now sits on Motoko's hot path:

- *inert* — reports happen only when herdr's injected `HERDR_ENV=1`, `HERDR_PANE_ID` and
  `HERDR_BIN_PATH` are all present. Ordinary terminals, the operator's devcontainer and CI take an
  early return;
- *non-blocking* — reports are fire-and-forget child processes with stdio discarded, unref'd, and
  with an `error` listener, because a spawn that fails asynchronously and unhandled would take the
  TUI down over a sidebar update;
- *bounded* — the one synchronous call is the release on exit, which must be synchronous (an async
  spawn started in an `exit` handler never runs) and therefore carries a 1 s timeout. A wedged herdr
  server costs a stale sidebar row, never a Motoko that cannot exit.

**D5 — `custom:motoko` and `motoko` are stable identifiers, not cosmetics.** herdr keys lifecycle
authority on the source string; changing it orphans authority a running pane already granted.

Both are held to a documented constraint, and being exact about *which* documentation matters,
because neither is documented against `pane report-agent` itself: `[a-z][a-z0-9_-]{0,31}` is
documented for **agent names** (the `agent rename` / `agent start` alias), and "80 characters or
fewer, ASCII letters, digits, colon, dot, underscore and hyphen" is documented for **`pane
report-metadata`'s** `--source`. Applying both here is deliberate conservatism against the adjacent,
almost certainly shared, validator rather than a quotation of this command's own rules. The reason to
bother: a rejected report is *rejected by the server rather than surfaced to the caller*, so a
violation fails silently in production — which is why both are asserted in the test suite instead of
being trusted.

**D6 — session identity is reported as a path, and restore is not attempted.** Motoko hands herdr
its `.motoko/logfile/<stem>.jsonl` transcript path via `pane report-agent-session`, which surfaces
in `agent get` / `agent list`. It goes no further: herdr's automatic session restore also requires
herdr to know how to *launch* the agent, and `agent start --kind` is a fixed list that Motoko is not
on. Reporting the path is nearly free and honestly labelled; claiming restore would not be.

**D7 — the run-state mapping is a compile-time contract.** `herdr-agent-state.ts` restates Motoko's
run-state union rather than importing it from `ui.ts` — which is required anyway, since `ui.ts`
imports this module — and `reportRunState` takes that union. A new `RunState` member added without
extending the mapping therefore fails to typecheck at the `ui.ts` call site. This is the mechanism
that keeps D3's decision from silently rotting the first time someone adds a state.

---

## Consequences

**What this buys.**

- Motoko appears in the herdr sidebar beside `claude`, `codex` and `omp`, with rollups to its tab
  and workspace, and with its state authored by Motoko rather than inferred.
- `herdr agent wait <pane> --until idle`, `agent read` and `agent get` become usable against Motoko
  itself. For 018 this closes an asymmetry: the orchestration primitives it wants for delegates now
  work on the orchestrator too. **Not** `agent prompt` or `agent send-keys` — herdr reserves those
  for agents it started, and input to a Motoko pane goes through `pane send-text`. **Not** by the
  reported label either: the target is the pane id, or a name set separately with `agent rename`.
  Both corrected from an earlier draft of this record — measured in M9, see Corrections C2.
- The blocked rollup means an errored run pulls the operator to the right pane, which is the whole
  reason to run several agents at once — subject to the path limitation in D3.
- **A finished run announces itself, for free.** herdr defines `done` as "the same underlying idle
  state after background work finishes, until that tab is focused". Motoko never reports `done` and
  cannot; it reports `idle`, and herdr presents that as `done` on an unfocused tab. So a run that
  completes while the operator is in another workspace shows as done rather than as merely idle,
  with no extra reporting.

**What it costs, and what it does not do.**

- **herdr still cannot launch Motoko.** `agent start --kind` is a fixed list. A Motoko pane is
  started with `herdr pane run <pane_id> 'make run'` and is recognised once it reports. Only option
  E changes that.
- Two files on Motoko's core path now carry a herdr concern: **two statements in `ui.ts`** (an
  import and the call in `setRunState`) and **four in `index.ts`** (an import, `initHerdrReporter`,
  and `reportSessionPath` at both `SessionLogger` sites). Every one is a call into a module that
  returns immediately outside herdr. `git diff --numstat` reads `7` and `10` against those two
  files; the difference is comment lines. Not zero, though: a future reader of `setRunState` will
  find a reference to a terminal multiplexer there.
- **A hard kill leaves a ghost row — measured, no longer inferred.** The release is registered on
  `exit`, `SIGINT` and `SIGTERM`; `SIGKILL`, a panic, or an OOM cannot run it. herdr does not expire
  the stale source on its own: after `kill -9` the pane returns to a shell prompt and the `motoko`
  row remains in its last reported state, unchanged 60 s later (M5). It is cleared by hand with
  `pane release-agent`. Accepted, as it was when this was an inference: the alternative is a
  heartbeat, which is a great deal of machinery for a cosmetic failure mode.
- D3 is a semantic stretch, and its second path delivers 92 ms of what it claims — see M8.
- **The herdr-environment detection will be duplicated, and nothing links the copies (MOT-118).**
  `readHerdrEnvironment` here is TypeScript in the TUI host. Project 021's proposed delegation
  extension needs the same gate (`HERDR_ENV`, plus `HERDR_BIN_PATH` to invoke) in **AILANG**, inside
  an extension process — so the rule cannot be shared, only restated. If herdr changes what it
  injects into a pane process, both copies have to move. Recorded here as well as in
  `../021_herdr_delegation/RESEARCH-herdr-delegation-surface.md` §4.4 so that whichever file a
  reader reaches first names the other. The actual cross-pointers wait on 021 landing; until then
  there is one copy and nothing to link.

**What was measured.** Taken 2026-08-22 in `agent_confined`, pane `w1:p5`, herdr v0.8.2, over five
runs of `herdr pane run w1:p5 'make run'`. Timestamps are epoch seconds from a 100 ms poller on
`herdr agent get w1:p5`; where a duration is quoted, the poller's resolution is the error bar.

**M1 — the row appears.** `herdr agent list` returns a `motoko` row for `w1:p5`, `agent_status:
idle`, beside the `claude` row on `w1:p1`. First observed 26 s after `make run` — the delay is
`check_core` and `tsc`, not the report; the row appears with Motoko's first frame. This is the
picture 019 §5 and 018 were aiming at, and it exists.

**M2 — lifecycle authority was granted, and screen detection produced nothing.** The instrument the
handoff named does not work the way it was expected to, and the answer had to be assembled from
three readings instead (see *Corrections* C1):

- `herdr agent explain w1:p5` **refuses**: `agent_explain_unavailable — "agent target w1:p5 does not
  have a detected agent label"`. The same command against the adjacent Claude Code pane returns the
  full detection story: `agent: claude / state: working / manifest: bundled 2026.08.13.1 / rule:
  osc_title_working (region=osc_title priority=1100) / evidence: "◐ Agent projects/020 handoff"`.
  So `explain` is a screen-detection instrument, and for Motoko's pane there is nothing for it to
  explain.
- `herdr pane process-info --pane w1:p5` lists the foreground processes as `make`, `sh`, `bun`.
  None is an agent herdr can identify, and `motoko` is in no bundled manifest — the label cannot
  have come from detection.
- Yet `herdr agent get w1:p5` returns `agent: motoko` with a live `agent_status`. And on release the
  row disappears **while the pane still renders Motoko's TUI**, which a screen rule would still be
  matching.

Taken together: the row's existence and its state are the report's, and nothing else is classifying
the pane. D1's central claim holds.

**M3 — states track a real run.** One task (`How many lines are in README.md?`) submitted to a live
Motoko:

| wall clock | herdr | Motoko's own status line |
|---|---|---|
| 17:23:14.319 | `idle` | `state: idle` (startup report) |
| 17:23:16.573 | — | task submitted |
| 17:23:36.121 | `working` | `state: thinking` at 17:23:38 |
| 17:24:18.013 | `done` | `state: idle` |

Two things worth naming. The sidebar and the status line move together — D2's "the same fact"
rather than two derivations — within the poller's resolution. And the intermediate transitions
(`thinking` → `tools_wait` → `tools_run` → `thinking`, all through `BashExec wc -l README.md`) all
map to `working`, so herdr's row does not flicker while Motoko works.

**M4 — `done` is free, as claimed.** The final row reads `done`, not `idle`. Motoko never reports
`done` and cannot; herdr presents a reported `idle` on an unfocused tab that way. Observed on every
run that ended idle.

**M5 — the release fires, on three exit paths out of four.** Measured from the moment the process
was signalled to the moment `agent get` stopped returning a row:

| exit path | how it was reached | result |
|---|---|---|
| `ui.onAbort` → `process.exit(0)` | `ctrl+c` at an idle prompt | released in ~193 ms |
| runtime exited cleanly → `closing.then(...)` → `process.exit(0)` | a run that ended by itself | released |
| `SIGTERM` handler → release → re-raise | `kill -TERM` on the `bun` pid | released in **80 ms** |
| `SIGKILL` | `kill -9` on the `bun` pid | **ghost row**, see below |

The ghost row was inferred in this record and is now measured: after `kill -9` the pane returns to
a bash prompt and `herdr agent list` still shows `motoko`, `agent_status: done`, unchanged 60 s
later. herdr does not expire a stale custom source — as the inference said, and for the reason it
gave. Still accepted: a heartbeat remains a great deal of machinery for a cosmetic failure that only
a `SIGKILL`, a panic or an OOM can cause. `herdr pane release-agent w1:p5 --source custom:motoko
--agent motoko --seq <n>` clears it by hand.

**M6 — the sequence number was seeded wrong, and it broke the integration outright.** This is the
measurement that earned its keep, because nothing short of a running server could have found it.

Symptom: the second Motoko started in the same pane produced **no row at all**. Not a wrong state —
no row, for the whole run.

Cause, established by probe: herdr accepts a report only when `--seq` is **strictly greater** than
the last it accepted for that `(pane, source)` pair, and that high-water mark **survives both
`release-agent` and the exit of the process that set it**. Reporting `--seq 1` and `--seq 2` against
a pane whose high-water was 2 changed nothing; `--seq 100` was accepted immediately. The original
counter started at 0 in each process, so run 2 spent its life below run 1's mark. And because a
rejected report is rejected by the server rather than surfaced to the caller, Motoko could not tell.

Fixed: `initHerdrReporter` seeds the counter from `Date.now()` before the first report. A run cannot
emit more reports than it lasts milliseconds, so the next process always outranks the previous run's
last report. Verified against the server — run 3 appeared in a pane whose high-water was an
epoch-millisecond value left by the probes above — and pinned by three new tests
(`herdr-agent-state.test.ts` is now 14 cases): the seed is applied at init, a restart outranks the
run before it, and the value is sent as a plain integer. A clock stepping backwards would reopen the
window for the width of the step; accepted, against persisting a counter per pane.

**M7 — `HERDR_BIN_PATH` reaches `bun`.** Read from `/proc/<bun pid>/environ` for a process started
by `pane run 'make run'` → `make` → `sh -c` → `scripts/run-agent.sh` → `exec bun`:
`HERDR_ENV=1`, `HERDR_PANE_ID=w1:p5`, `HERDR_BIN_PATH=/usr/local/bin/herdr`. Inheritance holds
across the whole chain, as expected — now looked at rather than assumed.

**M8 — D3's two paths, both timed.** The mapping is right on one path and defeated on the other,
exactly as this record said; what the measurement adds is *by how much*.

- **In-band `error`, runtime alive.** Provider failure (an invalid `OPENROUTER_API_KEY`) on a live
  run. `working` at 17:25:36.060, `blocked` at 17:25:36.304 — 244 ms behind the state change, with
  the message on the row. It then **stayed blocked**, through the 30 s it was watched, with the
  `ailang` runtime still running and Motoko's own status line reading `state: error`. D3 works here.
- **Runtime-exit recovery.** With the row blocked, the `ailang` runtime was killed — the branch's
  own case, "process crashed after emitting an error". `index.ts`'s `errorOccurred` branch called
  `ui.setAwaitingTask(true)` → `setRunState("idle")`, and the row left `blocked` **92 ms** later.
  Rendered on an unfocused tab, it does not even read as `idle`: it reads as `done`.

**92 ms settles the question this record left open.** "Accept it, and rely on herdr rendering an
unfocused idle row as `done`" is not defensible: at a tenth of a second the blocked row is a flash
nobody sees, and what replaces it presents a crashed run as a finished one — the strongest form of
the failure `idle` was rejected for. The 30 s the row survived above was the interval the operator
(here, the measuring session) chose before killing the runtime, not a property of the code; a
runtime that errors and exits together gives the 92 ms.

The other two ways out are now separable on evidence:

- **Sticky `blocked` in the reporter** — refuse to downgrade to `idle` without an intervening
  `working`. This record rejected it as lying about Motoko's readiness for input, and the
  measurements make the lie concrete rather than theoretical: `herdr agent wait <pane> --until idle`
  **works** (M9), so 018's orchestration primitive would hang forever against a Motoko that has
  crashed once and is sitting at a prompt ready for the next task. Rejected again, now for a
  measured reason.
- **Change Motoko's recovery semantics** so a crashed run does not present as ready — i.e. the
  `errorOccurred` branch stops calling `setAwaitingTask(true)`, or calls something that accepts
  input without clearing the error state. It is the only survivor, and it is a product decision
  about the TUI's error handling that this record should not smuggle in. Escalated as **MOT-117**
  with this measurement attached; not taken here.

**M9 — which herdr primitives actually work against a reported agent.** Tested one by one, because
this record claimed four of them and was wrong about two (see *Corrections* C2):

| primitive | target `w1:p5` | target `motoko` |
|---|---|---|
| `agent get` | works | `agent_not_found` |
| `agent read` | works | `agent_not_found` |
| `agent wait --until idle` | works | `agent_not_found` |
| `agent prompt` | `agent_not_ready` — *"not an active named agent"* | same |
| `agent send-keys` | `agent_not_ready` | same |

`--agent motoko` sets herdr's *kind label*, not an addressable *name*; the name is a separate field
that `agent rename` sets. After `herdr agent rename w1:p5 motoko`, `agent get motoko` resolves and
the name-targeted forms work — but `agent prompt` and `agent send-keys` still refuse, because they
are reserved for agents herdr itself started. Making the reporter call `agent rename` would deliver
the name-targeted forms; it is **MOT-120** rather than a line of code here, because herdr requires
the name to be unique among live agents and two Motokos is precisely what 018 and 021 are for. Input to a Motoko pane goes through the pane surface
(`pane send-text` + `pane send-keys enter`), which is what the measurements above used.

---

## Corrections

Recorded 2026-08-22 by the session that took the measurements above, following the convention in
`../016_github_ops/ADR-001-github-pr-ops-pipeline.md`. C1–C3 are **factual**: this record described
the world incorrectly and the body has been fixed in place. C4 is a **defect** the measurements
found in the implementation, fixed in the same change.

**C1 — `herdr agent explain` is not the instrument this record and its handoff said it was.**
Both described `explain` as naming the manifest source, *whether a lifecycle authority took over*,
and the matched rule — and item 2 of the owed measurements was written as "`explain` confirms screen
detection was skipped". In herdr v0.8.2 `explain` has no lifecycle-authority branch at all: it
reports screen detection, and for a pane with no *detected* label it returns
`agent_explain_unavailable` instead of an answer. The confirmation is still available, but as a
three-way contrast rather than as one command's output — M2 records how. The distinction the
handoff was protecting ("it works" versus "it looks like it works") survives intact; only the
instrument changed.

**C2 — `agent prompt` does not become usable against Motoko, and none of these primitives take the
label as a target. (Fixed inline: Consequences → what this buys.)** This record claimed
"`herdr agent wait motoko --until idle`, `agent prompt`, `agent read` and `agent attach` all become
usable against Motoko itself". Measured (M9): `agent prompt` and `agent send-keys` refuse a reported
agent outright — they are for agents herdr started — and the target is the pane id or a name set by
`agent rename`, never the reported label. `agent wait`, `agent read` and `agent get` do work, which
is what 018 actually needs from D1; `agent attach` was not exercised and is no longer claimed.

**C3 — the ghost row after `SIGKILL` is measured, not inferred. (Fixed inline: Consequences.)**
This record recorded the inference and flagged it as undocumented and unmeasured. It is now
measured, and the inference was right: the row survives the process by at least 60 s, unchanged.
The paragraph now says so rather than reasoning towards it.

**C4 — the sequence counter started at 0 in every process, which made every Motoko after the first
invisible to herdr.** Full account in M6. The claim that broke was not one of D1–D7 but the
implementation comment beneath them: reports were sequenced to survive *reordering within a run*,
and nothing considered the *next* run in the same pane. `initHerdrReporter` now seeds from the wall
clock. The comment on `buildReportArgs` was also wrong in a smaller way — herdr requires strictly
greater, not merely not-lower — and is corrected.

---

## Linear issues

Created 2026-08-22 as part of the verification handoff. They read as the API key's owner rather than
as `motoko-agent`; that is `../022_linear_integration/` F-1 and is not solved here.

- **MOT-115** — parent: verify the herdr agent-state reporter against a running herdr server.
- **MOT-116** — the five owed measurements. Closed by M1–M9 above.
- **MOT-117** — D3's second path. Measured (M8) and **left open**: the only surviving option is a
  change to Motoko's recovery semantics, which is the TUI owner's decision.
- **MOT-118** — candidate: link the two copies of the herdr-environment gate (TS host / AILANG
  extension). Blocked on `../021_herdr_delegation/` landing.
- **MOT-119** — candidate: display tokens via `pane report-metadata`. Argued against by D2.
- **MOT-120** — candidate: call `agent rename` so the name-targeted forms work, as C2's claim
  originally assumed. Held back on a naming question: herdr requires the name to be unique among
  live agents, and two Motokos is exactly what 018 and 021 are building towards.
