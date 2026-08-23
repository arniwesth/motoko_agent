# ADR-001: How does herdr come to recognise Motoko as an agent, rather than as an unidentified process in a pane?

Date: 2026-08-22
Status: **Accepted.** The owner approved building it in the same message that asked for this record;
D3 was put to them as the one open call and was not separately re-litigated, so it is recorded here
as decided-by-approval rather than as an adjudicated fork. Implemented in the same change:
`src/tui/src/herdr-agent-state.ts` (new), one call site in `src/tui/src/ui.ts`, three in
`src/tui/src/index.ts`, and `src/tui/src/herdr-agent-state.test.ts` (11 cases).
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
- `bun run build` (tsc) passes. `herdr-agent-state.test.ts` passes 11/11. The full suite is
  220 passed / 0 failed, with 5 suites failing **to load** on a pre-existing bun-jest/`depd`
  incompatibility reached through `express`; none of the five import anything this change touches.
- **Not verified: any of it running inside herdr.** No `herdr agent list` has ever shown a `motoko`
  row. See *Consequences → what is asserted rather than measured*.

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
decision this record should not smuggle in. What softens it: herdr renders an unfocused idle row as
`done` rather than `idle` (see Consequences), so a failed background run still reads as
"something finished here" rather than as nothing. Recorded as owed work, not as solved.

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
- `herdr agent wait motoko --until idle`, `agent prompt`, `agent read` and `agent attach` all become
  usable against Motoko itself. For 018 this closes an asymmetry: the orchestration primitives it
  wants for delegates now work on the orchestrator too.
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
- **A hard kill probably leaves a ghost row.** The release is registered on `exit`, `SIGINT` and
  `SIGTERM`; `SIGKILL`, a panic, or an OOM cannot run it. Whether herdr then expires the stale
  source itself is **not documented and not measured** — the inference that it does not is drawn
  from `release-agent` existing at all and being described as the caller's job when its agent
  process exits, plus the fact that a custom source is by construction independent of process
  detection. If that inference holds, the pane keeps a `motoko` row in its last reported state
  until something else reports or the pane closes. Accepted either way: the alternative is a
  heartbeat, which is a great deal of machinery for a cosmetic failure mode.
- D3 is a semantic stretch, and its second path does not yet deliver what it claims.
- **The herdr-environment detection will be duplicated, and nothing links the copies.**
  `readHerdrEnvironment` here is TypeScript in the TUI host. Project 021's proposed delegation
  extension needs the same gate (`HERDR_ENV`, plus `HERDR_BIN_PATH` to invoke) in **AILANG**, inside
  an extension process — so the rule cannot be shared, only restated. If herdr changes what it
  injects into a pane process, both copies have to move. Recorded here as well as in
  `../021_herdr_delegation/RESEARCH-herdr-delegation-surface.md` §4.4 so that whichever file a
  reader reaches first names the other.

**What is asserted rather than measured.** The unit tests cover the mapping, the environment
detection, the argv herdr will receive, sequence monotonicity and release idempotence — everything
except the part where herdr answers. **Nothing here has been observed against a running herdr
server**, because the container's first attach has not happened yet. The specific claims still owed
a measurement:

1. a `motoko` row appears in the sidebar and in `herdr agent list`;
2. `herdr agent explain <target>` reports the source as this integration and confirms screen
   detection was skipped for the pane — i.e. that lifecycle authority was actually granted;
3. states track a real run — and specifically whether the blocked row survives long enough to be
   seen on each of D3's two error paths;
4. the release fires on each of Motoko's several `process.exit` paths, leaving no ghost row;
5. `HERDR_BIN_PATH` is in fact injected for a process started via
   `pane run 'make run'` → `scripts/run-agent.sh` → `bun` (inheritance says yes; nobody has looked).

`herdr agent explain` is the instrument for items 1-3 (4 is `herdr agent list` after each exit path,
5 is `env` inside the pane), and item 2 is the one that distinguishes
"it works" from "it looks like it works": a report that herdr ignores and a report herdr honours
produce the same sidebar row right up until the screen manifest disagrees.
