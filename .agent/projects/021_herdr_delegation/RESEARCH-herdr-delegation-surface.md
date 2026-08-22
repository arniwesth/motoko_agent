# RESEARCH: `motoko-ext-herdr` — delegation as addressable sessions, and what that costs

Date: 2026-08-22
Status: Research — measured baseline + ranked comparison against 018. **No decisions taken, no code
written.** Every §6 fork is an owner decision.
**Implementation handoff: `HANDOFF-implement-motoko-ext-herdr.md` beside this file (2026-08-22).**
It closes F-1 — the container now runs, so §7's six measurements are executable and are Phase A of
that handoff. Nothing else here is superseded; the handoff defers to this document where they differ.
Grounded at: branch `arniwesth/mot-101-agentcli`, HEAD `d992d73`, against **herdr v0.8.2**.

Grounding verified 2026-08-22, in this repository's running devcontainer:
- Every 018 finding re-checked at HEAD. All eight still hold; one piece of its §1 baseline has
  drifted, see §1.
- herdr claims are read from the **v0.8.2 documentation source** at that tag
  (`docs/next/website/src/content/docs/*.mdx`), not the rendered site. herdr itself is **not
  installed here** — it exists only in `.devcontainer/agent_confined/`, which has never held a
  confirmed session. So nothing in §3 has been executed;
  it is a reading of a documented interface, and §7 is the list of things that turns into facts.

Relates to:
- `../018_agentcli_delegation/RESEARCH-agentcli-delegation-surface.md` — **the parent.** Its §2 is
  still binding, its §3 findings are the axis this document is organised along, and its fork F-6
  (*"does a delegate become a tmux session rather than a captured subprocess?"*) is the question
  this answers with a better mechanism than the one it names. Do not read this instead of that one.
- `packages/motoko-ext-agentcli/` — the extension this would sit beside, not replace. §4.
- `../019_agent_confined/` and `.devcontainer/agent_confined/` — where herdr runs. This
  extension is inert outside that container, which is a dependency 018 did not have.
- `../020_herdr_agent_integration/ADR-001-herdr-agent-integration.md` — the mirror image: that
  record makes Motoko *visible to* herdr as an agent; this one would make Motoko *drive* herdr to
  run other agents. They share the `HERDR_ENV` detection and nothing else.
- `../017_extension_handling/RESEARCH-extension-abi-evolution.md` — the 16-package price for a new
  ABI slot. §4.3 argues this design does not need one.
- `motoko_agent#158` — still open, still true; §3.1 records the precise condition under which this
  design could avoid it, which 018 could not.

---

## TL;DR

018 F-6 asked whether a delegate should be a detached session rather than a captured subprocess, and
sketched it with tmux. herdr is that idea with a typed state machine and a result channel attached,
and it is a **better answer than tmux**: it dissolves four of 018's eight findings instead of working
around them.

The single strongest idea is not the session model at all. It is that **the answer stops coming from
the transcript**. herdr's own guidance is to have the delegate write its result to a file and reply
with the path; do that and F3's truncation problem, 018 §2.2's per-provider decoder trap, and the whole
NDJSON-vs-JSON split disappear together, identically for all 22 agent kinds herdr knows.

What it costs: a hard dependency on a container that has never been started, a new failure mode
(delegates outliving Motoko and burning quota unattended), and an owner decision it forces rather
than permits — 018 §2.6's permission bypass is on partly because nothing could answer an approval
prompt, and in a herdr pane a human can.

---

## 1. Baseline, measured at HEAD

**018's findings all still hold.** Re-verified rather than assumed:

| claim | check | result |
|---|---|---|
| F1 wall | `ailang/cmd/ailang/main_run.go:81` | `--process-timeout` default `"30s"` |
| F1 wall | `grep -rn 'process-timeout' src/tui/src/` | **no hits** — the TUI never passes one |
| F1 misreport | `std/process.ail:24-31` | 7 `ProcessError` constructors, collapsed into one `Err(_)` arm |
| F2 inversion | `src/tui/src/runtime-process.ts:323-328` | forwards `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GOOGLE_API_KEY`, `EXA_API_KEY` |
| #158 | `src/core/tool_runtime.ail`, `shell_tokens_in_process` + the wrap | still drops `req.args`; exact trigger in §3.1 |

**One drift from 018 §1, worth recording because it changes what can be tested here.** That document
states *"Both CLIs are installed in this container (`/home/motoko/.local/bin/codex`,
`/home/motoko/.local/bin/claude`)"*. Measured today:

```
codex    ABSENT
claude   2.1.239 (Claude Code)
herdr    ABSENT
omp      ABSENT
```

So `CodexExec` cannot be exercised in this devcontainer at all right now, and neither can anything
herdr-shaped. All four are baked into the `agent_confined` image (019), which is where this work
would actually be tested — reinforcing §5.2's dependency point rather than being an aside.

**Transport is forced.** `ailang/std/` has 45 modules; `net.ail` is HTTP only (`httpGet`,
`httpPost`, `httpRequest`, …) and there is no unix-socket capability anywhere. herdr's socket API is
therefore unreachable from AILANG, and an extension must drive the **`herdr` CLI** through
`std/process.exec`. Not a real loss — herdr's own documentation says the CLI "talks to the running
server over the same local socket API used by integrations and agents" — but it means every
interaction is a process spawn, which is what §3.1 is about.

**herdr's relevant surface** (v0.8.2, documented):

| need | command | notes |
|---|---|---|
| a terminal to work in | `pane split [--cwd PATH] [--env K=V] [--no-focus]` | returns `.result.pane.pane_id`; **`--env` is a per-pane environment door** |
| isolate the checkout | `worktree create [--branch NAME] [--base REF]` | a git worktree as one command |
| launch a known agent | `agent start <name> --kind <k> --pane <id> [--timeout MS] -- <argv>` | 22 kinds; waits for detection, default 30 s, range 3 000–300 000 ms |
| give it work | `agent prompt <target> <text> [--wait] [--until STATUS] [--timeout MS]` | `--until` repeatable; defaults to idle/done/blocked |
| ask how it is | `agent get <target>` / `agent list` / `agent wait` | structured state, from the server |
| read the result | `agent read <target> --source recent-unwrapped --lines N` | tail-oriented; auto-scrolls alt-screen history for an idle agent |
| stop it | `agent send-keys <target> esc` / `pane close <id>` | |

Names must match `[a-z][a-z0-9_-]{0,31}` and are unique among live agents. CLI errors print JSON to
stderr and exit 1; invalid syntax exits 2.

---

## 2. Binding decisions from elsewhere

Not re-litigated here. Listed so this project does not spend cycles on them.

1. **018 §2.1 — dispatch by tool name, not a `provider` enum.** Models pick tools more reliably than
   they fill enums, and a wrong enum bills the wrong account silently. §4.1 honours this.
2. **018 §2.3 — no dollar figure is emitted.** An API-equivalent price is not spend.
3. **018 §2.6 — the permission bypass is ON by default** (owner, 2026-08-16). §5.3 explains why
   herdr reopens the *premise* without reopening the decision.
4. **018 §2.7 — there is no `on_model_call` seam.** This moves delegated work only, never Motoko's
   own driver loop. Unchanged.
5. **020 D4 — anything touching herdr must be inert outside it.** §4.4.

---

## 3. What herdr changes, per 018 finding

Ranked by how much a real delegated task gains.

### 3.1 — F1 (30 s wall) is dissolved; the misreport is not

**The wall stops being a wall.** Every herdr interaction is a short CLI call whose duration this
extension chooses:

- `pane split`, `agent get`, `agent read` — return immediately;
- `agent start --timeout 20000` — bounded below Motoko's 30 s by construction. **Note the trap:
  herdr's default here is 30 s**, exactly Motoko's own process timeout, so an explicit shorter value
  is mandatory rather than tidy;
- `agent prompt --wait --timeout 25000` — the only long one, and bounded by choice.

The delegate's own runtime becomes unbounded, because it lives in a pane rather than in the child
process Motoko is waiting on. A `--wait` timeout stops meaning *dead* and starts meaning *still
working*, which is a poll interval.

**The misreport is untouched and remains 018's to fix.** Collapsing seven `ProcessError`
constructors into one PATH-flavoured sentence is a defect in the extension, not in the transport,
and a herdr-shaped package would reproduce it exactly if written the same way. Worse: it now has a
second error channel to decode — herdr's own JSON-on-stderr — with its own vocabulary
(`agent_not_ready`, `agent_blocked`, `agent_prompt_stalled`, `agent_not_running`, `timeout`).
**A herdr extension needs a real error decoder on day one**, where 018 could defer it.

**#158 may become avoidable, under a precisely stated condition.** `shell_tokens_in_process` returns
true when the command is a shell, when `req.cmd` contains a space or a shell token, **or when any
element of `req.args` does**; and separately the wrap is entered when `req.cwd` is `Some`. The wrap
then builds its command from `req.cmd` alone and drops `req.args`. So the routed
`ExtPorts.proc_exec` path is safe only when **both** hold: no argv element carries a shell token,
and `cwd` is not passed through the port.

A herdr design can satisfy both, where 018 could not:

- the model-authored prompt — the argv element that carries backticks "as a matter of course" — can
  be written to a file and passed as a path, or sent with `agent prompt` reading from a file;
- working directory goes to `pane split --cwd` as an *ordinary argument*, so `req.cwd` stays `None`.

If that holds, this package could use `ExtPorts.proc_exec` and recover the WI-D24 holder stamping
that 018 §2.4 had to give up. **Unmeasured** — it depends on herdr's argv never tripping the token
test, which is plausible (ids, flags, paths) but has not been checked against a real prompt.

### 3.2 — F3 (truncation eats the answer) is eliminated, along with the decoder problem

018 F3's fix implies a per-provider transcript decoder, which 018 §2.2 warns is exactly where a shared
convention silently reports the wrong text. herdr's documentation offers a way out that needs no
decoder at all:

> If a full response is still unavailable, ask the agent to write it as Markdown in a temporary
> directory and reply only with the file path, then read the file directly.

Making that the *primary* channel rather than the fallback is the strongest idea in this document.
The extension appends a fixed instruction to every delegated prompt — *write your final answer to
`<path>`* — and reads the file. Consequences:

- no NDJSON decoder, no `--output-format json` parsing, **no per-provider convention at all**: it is
  identical for every one of herdr's 22 kinds, including ones nobody has tried;
- truncation becomes the extension's own decision over a file it controls, and can be tail-first
  with a marker, instead of head-first over a transcript;
- the transcript stays available for diagnosis via `agent read`, rather than being the result path.

The degraded path, when a delegate ignores the instruction, is `agent read --source
recent-unwrapped --lines N` — which is **tail-oriented by construction**, i.e. the opposite of the
current bug even when it falls back.

### 3.3 — F4 (the wedging lock) is dissolved

The lock exists because a captured subprocess has no other liveness signal. herdr has one:
`agent get <name>` returns state from the server, and herdr already enforces name uniqueness among
live agents. So the lock file, its unparseable `prov.id` content, and its staleness problem all go
away — not fixed, absent. Concurrency becomes a naming policy instead of a mutex.

### 3.4 — F5 (no cwd control) is solved, and F6 mostly evaporates

`pane split --cwd` scopes the delegate; `worktree create --branch` isolates it in its own checkout,
which is 019 F-5's option arriving as one command. The provider table collapses to a `--kind`
string, so "adding Gemini" stops being an AILANG edit — though a descriptor is still wanted for
defaults, so F6 is reduced rather than closed.

### 3.5 — F2 (billing guard) gets a real door, of unknown width

`pane split --env KEY=VALUE` sets environment **per pane**, which is precisely the thing
`std/process.exec` cannot do and which drove 018 F2 to argv-level `env -u`. Better in kind: it
applies to the pane and everything spawned in it, not to one command.

**But the documented semantics are "adds or replaces that variable in the new root shell" — that is
a set, not an unset.** Whether `--env OPENAI_API_KEY=` reads as absent to each CLI's credential
resolution is unmeasured, and it is the difference between a fix and a decoration. §7.1.

### 3.6 — F7 and F8 are unchanged obligations

F7 (`*_EXTRA_FLAGS` can carry only one token) is a Motoko-side defect that a new package would
simply not reproduce. F8 (no tests) applies here too, but more cheaply: argv construction, name
generation, error decoding and answer-file resolution are all pure.

---

## 4. The shape this suggests

Design sketch, not a decision. §6 holds what has to be settled first.

### 4.1 Two tools, optimistic-synchronous

Honouring 018 §2.1's dispatch-by-name:

- **`Delegate(kind, prompt, cwd?)`** — split a pane, start the agent, send the prompt with a bounded
  wait. A fast task completes in one tool call and returns the answer. A slow one returns
  `{name, pane_id, status: "working"}`.
- **`DelegateCheck(name)`** — `agent get` for state, plus the answer file if it has landed.

The common case stays one call; the slow case degrades to polling, and *the model decides when to
check back*, which is what an agent loop is for. Three tools (start/check/collect) were considered
and rejected: more surface for the model to get wrong, and it makes the leak in §5.1 easier.

### 4.2 herdr is the state store

No lock file, no `delegates.json`. `herdr agent list` **is** the registry: names are the handles,
uniqueness is enforced server-side, and state is authoritative. Motoko's tool envelopes stay
stateless, which is what the ABI wants.

### 4.3 No new ABI slot

`on_tool_handle` is still the seam and still one of only two slots carrying `{IO, Process, FS}`. So
017's 16-package price is not paid. What *is* wanted eventually — an env door on `ExtPorts` — is
made less urgent by §3.5, since herdr's `--env` sits at the pane instead.

### 4.4 Conditional registration

`register_with_config` already runs with `{Env, FS, IO, Process}` and `provided_tools` is computed
rather than literal (`agentcli.ail:222` builds it from config). So the package can read `HERDR_ENV`
and **return no tools at all when herdr is absent** — the model is never offered a tool that cannot
work, instead of being offered one that fails at call time.

**A standing obligation, stated because the obvious reading of the previous paragraph is wrong.**
020 already does this detection, in `src/tui/src/herdr-agent-state.ts`'s `readHerdrEnvironment` — and
the two **cannot share it**. 020's is TypeScript in the TUI host process; this one is AILANG inside
an extension. Same three variables (`HERDR_ENV=1`, `HERDR_PANE_ID`, `HERDR_BIN_PATH`), same rule,
necessarily duplicated across a language boundary. If herdr ever changes what it injects into a pane
process, **both** have to move, and nothing links them. Name that in whichever record lands second.

One asymmetry softens it: this package may not need `HERDR_PANE_ID` at all. `pane split --current`
resolves the calling pane from that variable itself, and the extension runs in a child of Motoko
which inherits the pane environment — so `--current` can do the work without the extension reading
the variable. That leaves `HERDR_ENV` (the gate) and `HERDR_BIN_PATH` (the binary) as the real
coupling.

### 4.5 A new package, beside `agentcli` rather than replacing it

The execution model differs enough that the *model* needs a different story about what the tools do:
one blocking call that returns an answer, versus a handle that may need chasing. And `agentcli`
keeps working where herdr is absent — which is this devcontainer, today. Per-profile enablement
already exists (018 §1: agentcli is listed in exactly one profile), so the two can coexist without a
switch.

### 4.6 What 020 and this produce together

Neither record says what the pair is worth, and it is more than the sum. With 020 shipped and this
built, one herdr session holds **Motoko as a row and its delegates as sibling rows**, and the two
halves get their state from different mechanisms by design:

- Motoko's own `working` / `idle` / `blocked` is **authored** by 020's reporter, as a lifecycle
  authority — herdr runs no screen detection for that pane;
- each delegate's state comes from herdr's **screen manifests**, because `claude` and `codex` are
  session-identity integrations rather than lifecycle authorities.

That is 019 §5's target picture actually assembled: the boundary (the container), the session model
(herdr), and delegates as panes — with the orchestrator visible in the same list as the things it
orchestrates, which is exactly the asymmetry 018 could not close.

**And one footgun that only exists once both are true.** `herdr agent list`, run from inside Motoko,
**includes Motoko** — label `motoko`, source `custom:motoko`. Any enumeration this package does
(counting live delegates, sweeping orphans per §5.1, resolving a name) must exclude its own row, or
it will count itself as a delegate and could in principle try to prompt itself. The exclusion is
trivial; discovering the need for it at runtime would not be.

---

## 5. What is new, and worse

### 5.1 Delegates outlive Motoko

This is herdr's entire point and it is a new failure mode: `agentcli`'s subprocess died with its
parent, and a pane does not. A delegate whose caller exited keeps working, keeps burning
subscription quota, and keeps write access to the tree — unattended. Nothing in 018 could leak this
way. An ownership convention is needed (name prefix, `report-metadata` token, or a sweep at
startup), and it should be designed rather than discovered.

### 5.2 A hard dependency on a container that has not yet held a session

The package is inert outside herdr, and herdr lives only in `agent_confined`. That image now
**builds**, but its first attach is still in progress and no session has been confirmed — three
wrapper and build defects were found and fixed on 2026-08-22 alone (019 `HISTORY.md`). So 018, 019
and 021 stop being separable projects: none of §7 can be measured until that container holds a
session.

### 5.3 It reopens a premise the owner already ruled on

018 §2.6's bypass is on partly because nothing could answer an approval prompt. In a herdr pane a
human can — `agent wait --until blocked`, then `agent send-keys`. So `codex --sandbox
workspace-write` with answerable prompts becomes a real option for the first time. **That is an
owner decision, and this document does not take it** (§6 F-4); it only records that the reason for
the default has weakened.

### 5.4 Two error vocabularies instead of one

§3.1: `ProcessError` from the spawn, and herdr's own JSON errors from the CLI. Handled well this is
a strict improvement over one opaque sentence. Handled the way 018 handles it today, it is twice the
silence.

---

## 6. Open forks — owner decisions

- **F-1. Does this get built at all before `agent_confined` has run a session?** Everything here is
  a reading of documentation. The honest order is: start the container, measure §7, then design.
- **F-2. Is the answer channel a file, or the transcript?** §3.2 argues strongly for the file. It
  costs a fixed instruction appended to every prompt — i.e. the extension becomes opinionated about
  what it asks the delegate to do, which 018 F-2 framed as a real question.
- **F-3. What happens to `agentcli`?** Coexist per-profile (§4.5), or is it eventually replaced once
  the container is the only way Motoko runs?
- **F-4. Does the permission bypass survive?** (§5.3.) Answerable prompts change the tradeoff;
  they do not make the decision.
- **F-5. Who owns an orphaned delegate?** (§5.1.) Sweep at startup, kill on exit, or leave running
  deliberately and make it visible?
- **F-6. One delegate at a time, or many?** herdr removes the mutex that made this a non-question.
  Several delegates in one tree is 019 §6's "two agents, one worktree" at higher multiplicity —
  `worktree create` is the answer if the answer is "many".

---

## 7. What must be measured before designing

Ordered by how much design turns on the answer. Every one needs `agent_confined` running.

1. **Does `pane split --env OPENAI_API_KEY=` read as *absent* to codex, and `ANTHROPIC_API_KEY=` to
   claude?** (§3.5.) Decides whether F2 has a real fix or a cosmetic one. Also settles 018 §5.1,
   which is still unmeasured: do the CLIs prefer an env key over stored subscription auth at all?
2. **Does `agent start --kind codex|claude` reliably detect in the `agent_confined` image?** Its
   screen manifests were written against upstream defaults; this image's terminal, locale and lack
   of a login could all matter. A failure here is fatal to the whole design.
3. **What does `agent prompt --wait` do on a slow start?** It returns `agent_prompt_stalled` if no
   lifecycle change is observed within 5 s. A delegate that thinks before printing could trip it
   routinely, which would make the optimistic path in §4.1 the wrong default.
4. **Does herdr's argv ever trip `shell_tokens_in_process`?** (§3.1.) Decides whether
   `ExtPorts.proc_exec` is reachable and #158 avoidable — i.e. whether holder stamping comes back.
5. **Do delegates comply with "write your answer to `<path>`"?** Per kind. Decides whether §3.2 is
   the primary channel or an optimisation over a fallback that has to exist anyway.
6. **What is the realistic wall-clock and answer size for a delegated task?** Still 018 §5.3, still
   unmeasured, and it sets the `--timeout` values that §3.1's whole argument depends on.
