# RESEARCH: The Harness Playbook (omp²) — what Motoko can take from "What omp² changes"

Date: 2026-09-14
Status: Research note (no decision taken; candidate follow-ons listed in §7)
Grounded at: branch `arniwesth/013-plan003-and-herdr`, HEAD `d5edebf`
Source:
- Can Bölük, *The Harness Playbook*, 2026-09-02 — stencil.so/blog/harness-playbook. Nine
  chapters and two appendices; each chapter pairs a "What omp taught us" postmortem with a
  "What omp² changes" section. This note is about the second half of each pair.

Relates to:
- `../013_core_architecture_for_dst/ADR-003-session-journal-and-resume.md` (v6.1) and
  `ADR-004-journal-as-evaluation-source.md` (v4) — Motoko's answer to the post's first
  requirement, one journaled authority. §3.1 below.
- `../013_core_architecture_for_dst/ADR-002-park-and-wake.md` (v4.2) and PLAN-002 W1b–W5
  (`957c91e`…`8004874`) — the closest thing Motoko has to the post's "one stdio-shaped job".
  §3.2, §4.1.
- `../013_core_architecture_for_dst/RESEARCH-core-architecture-for-dst.md` §2.D — commands +
  interpreter; the post's "execution is a state stream" is the same move at the tool seam.
- `../028_verified_runtime_closing_the_loop/VISION-001-path-to-10-of-10.md` Layer 2 — the
  verification asymmetry the post's runtime chapter lands on. §3.2.
- `../028_verified_runtime_closing_the_loop/README.md` items 10, 13, 14 — NOTE-005 finding 1
  (context limit 0 read as healthy), NOTE-008 (cache-read share), NOTE-009 (tool count 7).
- `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` D2 — "the transcript is
  the state; core adds no counter". §2 row 2, §3.3.
- `../017_extension_handling/ADR-001-extension-abi-evolution.md` Q2, Q3 — vote kinds and the
  compiler-enforced payload rows on the imported `Capability` sum. §2 rows 2 and 8.
- `../019_agent_confined/ADR-001-confined-agent-container.md` D2–D4 — the container as the
  capability boundary; herdr's observe frames as the off-screen protocol. §2 rows 14, 16.
- `../021_herdr_delegation/DESIGN-motoko-as-delegate.md` §3.4, §6 and
  `DESIGN-dagr-as-delegation-view.md` §2 — sandbox reach, budget propagation, and the one
  read-only projection Motoko already has. §2 rows 6, 14, 16.
- `../026_operational_ontology/RESEARCH-operational-ontology-implications.md` — the note whose
  shape this one follows; its §3.1 (refusal codes) is where the post's "structured refusal"
  ideas already have a home.
- `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` — decisions as data, ports, the
  ledger as the DST trace; the substrate every row below rests on.

---

## 0. TL;DR

The post's thesis: unavoidable complexity needs an owner; push it into the engine; make the
wrong state unrepresentable. It names five requirements — one authoritative journaled session,
a trusted control plane, bounded cancellable work, explicit model compatibility, views as
projections — and then, chapter by chapter, what omp² builds to meet them: a session DOM with a
patch-stream journal, a dumb execution stub behind a typed RPC, tool calls as state streams with
central limits, convars and Directors, a compiled compatibility taxonomy, a five-tool roster with
`dyn` behind it, a one-pass RichText renderer with a TLA+-checked transcript, Rust and Python.

Read against HEAD `d5edebf`:

1. **Motoko has already arrived at the first requirement by a different road.** ADR-003 makes
   the session a host-written journal and resume a strict fold; ADR-004 strict-replays that
   journal as an execution program under every candidate commit, which is the post's
   `replay(.dem) == original` used as a benchmark. Extension state cannot escape the tree because
   AILANG has no mutable bindings and the ABI hands extensions only a history slice, a state key
   and a world token. That is the post's "make non-replayable state unrepresentable", enforced by
   the language rather than by a DOM. §3.1.
2. **The runtime chapter is the sharpest critique and it lands on `env-server.ts`.** The post
   wants the host to decide and a stub to execute. Motoko decides in the verified AILANG child and
   executes on the unverified TypeScript host, which also calls models and runs scratchpad
   kernels. Output is bounded once but silently; a timeout kills the tool and not the make it
   started; there is no job primitive. 028 Layer 2 already names the asymmetry; the post gives it
   a shape. §3.2.
3. **Directors are the largest missing primitive.** Motoko's multi-turn behaviours — three guards,
   the persist nudge, the DP7 gate — each derive a budget from history (replay-honest, ahead of
   Pi's closures) but compose by fixed precedence and one hand-ordered pipeline. Nothing can push
   a child behaviour, receive the yield back, or say who owns the yield. §3.3.
4. **The control plane is the god-object case the post describes, and one of its lessons has
   already been paid for.** Nested config records, a separate subagent-model setting, no budget
   propagation to delegates. The KDL rule "no matching rule → unknown, not false" is NOTE-005
   finding 1, fixed in PLAN-001 P1B as a typed sum. §2 rows 6–7.
5. **The tool roster is small but the primitives are shallow**, `ToolCallEnvelope` carries no
   intent or version, and Bash policy sits at the string boundary the post calls the TSA screen.
   §2 rows 12–14.
6. **The TUI is on the wrong side of the post's 267 s → 90 ms story** and is built on the very
   library the post profiles; the post's "verification is part of the interface" is where Motoko
   is ahead. §2 rows 15–16.

Not transferable as written: the Python `@remote` extension model, the in-process Bash
interpreter as a near-term item, speculative compaction before the journal carries park/wake.
§5.

---

## 1. The source, compressed

### 1.1 The design envelope

Four operating modes as architecture tests — multiplexed workspace, remote driver, spectator,
factory ("Factorio": an SDK-driven software factory against untrusted input) — and five
consequences: one authoritative session; a trusted control plane; bounded work; explicit
compatibility; views as projections. Every later subsystem is justified as serving one of the
five.

### 1.2 What omp² changes, per chapter

| chapter | the change |
|---|---|
| State | The whole session materialises as one tree (XML chosen for inspectability). The journal stores property-change patches; the tree is the authority; runtime objects may cache but never become a second place truth lives. Rewind is a tree diff; prompts, replication and rendering are projections of the same tree. Controller and actor are separate: actors render a snapshot and a patch stream. Evidence for the rule: of 78 official Pi extension examples, 60 stateless, 17 stateful, **2 correct** (Appendix A). |
| Runtime | Host owns session state, inference, policy, tool routing, approval, limits and journaling; the sandbox owns execution through a small obedient stub, with every returning stream bounded. Subagents get a copy-on-write view of the workspace and return a diff. A tool call is an element with `<input>`, `<result>`, `<diag>`, `<usage>` children that the executor mutates while running; settling journals the final diff. Output and blocking time are bounded once, centrally, as opt-out. A backgrounded shell, a subagent, a daemon and an overrun call are one stdio-shaped job with signal, stdin, stdout and exit. Cancellation needs a kill boundary, not a cooperative signal. Python for extensions so `@remote` can ship a function to the other side of the boundary. |
| Control plane | Values are convars: typed variables with name, default, help and flags (`REPLICATED`, `ARCHIVE`, `CHEAT`, `SESSION`…) declared where the variable is born; a session-scoped convar is a journaled node. Children seed every variable from the parent, so inheritance needs no second setting. cfg files, binds and aliases stay in-band. Behaviours are **Directors**: one live subtree of the session tree, walked outside-in for `prepare_inference` and inside-out for `on_yield`; each may Pass, Continue, Yield, Push, Done or Fail. Plan mode is Plan pushing a `ForceTool` child and receiving the yield back. A hook edits one turn; a Director keeps control across turns. |
| Inference | Compatibility is a compiled taxonomy (`taxonomy/`, `classes/`, `providers/` in KDL): unknown directive → error; two equally specific rules → error; no matching rule → **unknown, not false**. A provider is more than a stream (token counting, search, discovery, OAuth refresh, retries). Forced tool calls: soft prompt always; native flag only when free; bounded retries then escalate. Schemas are model-facing protocols: strict on semantics, charitable on dialect. Strict sampling needs a budget and per-provider dialects. Corrective inference: JSON repair, repetition detection, dialect parsing into canonical `tool_call` blocks. Compaction is scheduled speculatively ~10% before the limit on a branch and spliced; entries in the prompt history are folds. Tiny local models for harness work. |
| Tool surface | Every permanent schema taxes every turn: 23 defs / 86.2 s median wall → 5 tools / 36.6 s, ahead of Codex (42.2 s) and Pi (37.0 s), prefix 25.1k → 15.1k tokens. Long tail behind `dyn`, a stable discovery surface inside Bash and Eval. Every tool gets an `i` intent argument and a version. Deep builtins: `Read` materialises directories, notebooks, PDFs, sqlite, archives, URLs, internal `artifact://`, `agent://`, `history://` schemes; `Bash` is an in-process interpreter so approval happens at `ln` or `git push`, not at the unreadable string. AutoQA gives agents a bug-report path. |
| Interface | Pi's `render(): string[]` contract measured at 267 s of render time in one session, 13% of CPU in one `.includes`; replaced by RichText runs pushed once into a sink, 90 ms. A typed component model (`<box>`, `<row>`, `<ico:new/>`, semantic colours) so tool authors describe structure and each surface lays it out. Verification is part of the interface: a non-destructive, off-screen, multi-instance debug protocol so the agent cannot redefine success. The transcript is a protocol — blocks active → finalized → committed, mutable vs append-only, width-independent logical history, three resize policies — modelled in TLA+ (Appendix B). |
| Stack | Language choice is architecture: TypeScript permits twenty equally normal local styles and agents pick one each; Rust for the core; Python for extensions because agents write decent Python, the runtime makes Eval dependable, and AST introspection makes `@remote` possible. |

### 1.3 What the post does not cover: testing the harness

The post never mentions deterministic simulation testing, scripted or simulated providers, fault
injection, property-based testing, seeded generation, shrinking, or record-and-replay as a test
technique, and it says nothing about how the agent loop itself is tested (checked by grep over the
full text for those terms and their neighbours, 2026-09-15). The nearest passages:

- **Replay is a product property, not an oracle.** The state chapter's argument is
  `replay(.dem) == original` against `replay(.jsonl) ≠ original` — rewind, fork, resume and
  replication being honest to the user. It is never turned around into "drive the engine from the
  journal in a test". It does state the precondition DST would want: "at any journal point, the
  harness can materialize — and therefore snapshot — the whole session".
- **The test harness is listed as one more consumer.** Twice: "the model, user, journal, remote
  client, and test harness observe different projections of the same state" (a running tool
  element), and "the TUI, web client, snapshot test, and remote inspector" (a component). That is
  004 ADR-001's "production telemetry and DST traces must be one artifact, not two", left as a
  list item.
- **Formal methods, scoped to the terminal.** The only verified artifact is the TLA+ model of the
  transcript protocol, checked with TLC. The stated motivation is a move *away* from fuzzing: "in
  the previous iteration, we had to write a fuzzer to get to a stable point, and this time I'd like
  to avoid that." Nothing formal touches the loop, the journal fold, tools or compaction.
- **"Verification is part of the interface"** is dev-loop verification of the product — a
  non-destructive, off-screen, multi-instance debug protocol so a coding agent cannot redefine
  success — not testing of the harness.
- **The compat compiler's checks are static** (unknown directive → error; ambiguous precedence →
  error; no rule → unknown), and the design envelope's four modes are "architecture tests" only
  in the sense of thought experiments.

Consequence for §2 and §3: the DST asymmetry is total. Motoko's harness (22,411 lines of
`src/core/dst_*.ail`, the world ordinal, strict replay, the fault catalogue, ADR-004's
journal-as-benchmark) has no counterpart in print, and the inverse holds too — the post's
single-authority journal is exactly the substrate that would make DST cheap, since every piece of
state a harness must script or check would already be in one replayable stream. ADR-003 and
ADR-004 are where the two lines meet.

---

## 2. Mapping onto Motoko

Each row: the omp² change, what Motoko does today with coordinates at `d5edebf`, and a reading.

| # | omp² change | Motoko today | Reading |
|---|---|---|---|
| 1 | One materialised session; state derivable from the journal alone | ADR-003 v6.1: the host writes `.motoko/sessions/<id>/journal.jsonl` from the wire (`src/tui/src/session-journal.ts`, one writer, child writes no file); resume is `fold_journal` (`src/core/journal.ail:1557`), a pure fold checked as a DST invariant over every run's own trace (D4). Entries carry `id` and `parent_id` (`journal.ail:641`) and the fold walks leaf to root (`:2018`); the fields were adopted from oh-my-pi and "it schedules no branching feature" (ADR-003 v4.1→v5 retraction 6). Header pins `system_prefix_digest`, `ext_set_digest` and the boot inputs — the post's "hash the template and store its variables". | Same destination. No rewind or fork; the tree is ready for them. |
| 2 | Extension state cannot escape the tree | `ExtCtx` gives an extension `history_slice` and `state_key` (`packages/motoko-ext-abi/types.ail:536–548`), a host-owned opaque `ExtWorld` token (`:100`) and `artifacts`. AILANG has no `var`/`let mut` (`ailang/llms.txt:1494–1500`), so a closure counter is unwritable. 005 ADR-001 D2: guards count their own marker messages in history; "the transcript is the state; core adds no counter". Payload effect rows on the imported `Capability` sum are compiler-enforced (017 Q3 as corrected at B8). | **Stronger than omp²**: the language enforces what the DOM only encourages. What still escapes: FS-backed extension state (`ExitIntent`/`WorkInFlight` render from files, `types.ail:1263`, `:1273`), dagr run files, herdr pane state. |
| 3 | Trusted host decides; a dumb stub executes; streams bounded before crossing back | Policy (`ToolPolicy` votes, `classify_candidate` at `session.ail:3255`, `decide` in `step_machine.ail`) runs in the AILANG child. Tools execute on the TS host: `POST /exec` at `src/tui/src/env-server.ts:1268` is `execSync(cmd)` at `:1304`. The same file holds `callSubagentModel` (`:653`), compose claim-check and the scratchpad kernels (`:18–24`), and the journal writer lives in the same process. Approval is a `readLine()` on the child's stdin (`src/core/test/stub_step.ail:209–213`); the TUI has no approval handler (ADR-002 v1→v2 retraction 3). | The boundary is drawn by **verification**, not by process placement: the deciding side is typed and Z3/DST-checked, the executing side is 17,058 lines of TypeScript outside any verifier. 028 VISION Layer 2 names exactly this. The post's stub is a target shape for it. |
| 4 | Execution is a bounded, cancellable state stream; output and blocking time bounded once, as opt-out, with structured diagnostics | Bounded once: stdout sliced to 8,000 chars and stderr to 2,000 at `env-server.ts:1311`, `:1321`, `maxBuffer` 8 MiB; no notice reaches the model (the post's opposite failure: central but silent). Blocking time: `timeout = 30` s default (`:1269`); on timeout the shell is killed and the work it spawned is not — the 2026-09-13 handoff's "`make dst` never in foreground; BashExec's ~35 s timeout kills the tool, not make (the 21:36 zombie sweep)". `ToolResultEnvelope` is `exit_code`, `stdout`, `stderr`, `metadata` (`types.ail:49–56`); truncation rides `metadata.truncated` (`tool_runtime.ail:251`), not a diagnostic the transcript projects. | The post's predicted bugs are in the handoffs. |
| 5 | One stdio-shaped job for backgrounded shells, subagents, daemons and overrun calls | ADR-002 (v4.2): waiting is a step-machine state served by a port. `WaitDescriptor = DelegateWait \| OperatorWait \| TimerWait` (`src/core/phase_vocab.ail:442–445`), `open_waits` on the loop state (`session.ail:583`), the live wake is one `wake_request` line and a stdin reply (`stub_step.ail:214–221`). Park and wake live since PLAN-002 W4 (`85ce0c7`); durable park as journal entries is PLAN-003 P4, unscheduled — `session-journal.ts:40–46` records that `park_entered`/`wake_received` do not yet exist. Long work otherwise goes to `nohup … &` plus polling, or to a herdr pane through `Delegate`/`DelegateCheck`. | The embryo of the post's job primitive, for delegates only. A backgrounded shell is not a wait. The `Delegate`/`DelegateCheck`/`herdr pane read` trio is the fragmentation the post draws for Claude's `Bash`/`Task`/`BashOutput`/`KillShell`. |
| 6 | Convars: flags declared with the value; children seed from the parent; cfgs and binds in-band | `src/core/config.ail:14–100` is nested records (`AgentConfig`, `ComposeConfig` with `authoring` and `claimcheck` inside); precedence defaults < profile JSON < CLI, keys from env; per-model quirks live as whole profiles (`.motoko/config/qwen36-compaction-live`, `deepseekv4-flash-…`, `hunyuan3-free-…`). `compose.subagent_model` is a separate setting (`config.ail:85`) — the post's `tier.subagent: inherit` anti-pattern verbatim; 021 `DESIGN-delegate-model-selection.md` exists because of it. "No budget propagation between parent and delegate" (`DESIGN-motoko-as-delegate.md` §6). Journaled settings: `model_change` and the resume `settings` entry (ADR-003 D5) — the post's "blessed ~3" tier. Delegate depth is an env var forwarded by prefix (`HERDR_DELEGATE_DEPTH`). | The god-object case. Inheritance is ad hoc per feature. |
| 7 | "No matching rule → unknown, not false" | NOTE-005 finding 1: a missing catalogue row resolved the context limit to 0 and every consumer read 0 as healthy; NOTE-008 measured it as steady state (`usage_pct: 0` at ~230k real tokens). PLAN-001 P1B (`ad558d0`) replaced the int with a typed sum whose arms are bounded, disabled and unknown, surfaced by `MotokoRuntimeStatus` (`tool_catalog.ail:68–72`). `ExtCtx.context_limit: int` with "0 means unknown" is still the v2.2.0 ABI text (`types.ail:549–554`). | Learned the hard way, then fixed the post's way — in one place. The ABI field is the remaining "false" reading. |
| 8 | Directors: a stack owning the candidate yield; Pass / Continue / Yield / Push / Done / Fail; plan mode as composition | Per-turn hooks are the `Capability` atoms (`types.ail:1238–1273`). Multi-turn control: `SolverJudge` is a vote — `merge_finalize_decisions` gives `ContinueWithFeedback` > `Accept` > `NoDecision` in registry order (`src/core/ext/runtime.ail:702–711`); N>1 per extension is rejected at registration (017 Q2). `empty_stop_guard`, `progress_contract_guard`, `repetition_guard` and the persist nudge (`recovery.ail:66`) each keep a budget derived from `history_slice`. ADR-002 D2 orders DP7, wait classification and solver/persist policy as one explicit pipeline in `classify_candidate`. The DP7 verifier is core code (`run_dp7_verifier`, `session.ail:2241`) and still `Err(_) => Approve` (`:2245`). `WorkInFlight` (7.3) replaced prose recognition with a typed declaration. | Hooks plus one reviewed, hand-ordered pipeline. Better than omp's six restated checks; still the loop-shaped hole — no push, no pop, no "who owns the yield". The post's plan-mode example is the DP7 gate almost line for line, and the post's rule is that it belongs on the public surface. |
| 9 | Compatibility as a compiled taxonomy with explicit precedence | Provider selected by model-string prefix (README table: `openrouter/` stripped, `openai/` stripped, bare `gemini-*` → Google, `ollama/` kept); `ai_compat.ail` reports `provider: "motoko-or"` always and maps status codes heuristically. `.motoko/model-catalog.json` holds `context_limits`. ADR-004 v2→v3 item 4 records the routing name and the API name separately with a pinned conversion. | Scattered, but in tables and profiles rather than branches. No precedence checker; no "unknown" for capability questions other than the context limit. |
| 10 | Forced tool call: soft prompt always, native flag when free, bounded escalation | Persist nudge is a soft prompt only (`recovery.ail:66`, "use the WriteFile tool"), disabled by default. No native `tool_choice` rung. Hybrid mode's fenced-bash extraction (SYSTEM.md) is dialect repair. `repetition_guard` (NOTE-007, rule B) is the post's loop detection but as a guard that denies at the finalize seam, not an inference-layer repair. Legacy text tool parsing removed; provider-native tool calls only. | First rung only. |
| 11 | Compaction scheduled speculatively on a branch; prompt entries are folds | `should_checkpoint` fires at `checkpoint_pct` (`step_machine.ail:91–100`); the model waits. ADR-003 v4.1→v5 retraction 4: compaction never rewrites history; the journal records a checkpoint as a pointer entry with its summary messages — the post's "UI history unchanged, request sees the fold". `compaction_structural` is the post's "Shake"; `compaction_ai` the summary. DST owns the `tool_call_id` pairing invariant and tiers (NOTE-006). | Naive trigger, fold-shaped journal. |
| 12 | Small roster; deep `Read`; long tail behind `dyn` | Seven native tools (`tool_catalog.ail:76`; NOTE-009). `ReadFile` is `path` + line range, default 200 lines. Every extension `DescribeTools` schema is concatenated into every request (`declared_schemas`, `:107`; `tools_with_extensions`, `:143`), and a `ToolProvider` name without a schema gets `"Extension tool: ${name}"` with empty `properties` (`ext_tool_schema`, `:91–97`). Cache pressure is already instrumented: `system_prefix_digest` stability in `MotokoRuntimeStatus`; ~96% cache reads on the NOTE-008 tour. | Roster small, primitives shallow, and the extension tail rides every turn. |
| 13 | Intent and version on every tool call; name, version, intent, input, output, diagnostics and usage as protocol data | `ToolCallEnvelope = { id, tool, arguments }` (`types.ail:48`). Motoko versions the harness vocabulary (`event_vocabulary_version`, profile versions, the attribution table) and not its tools. | Missing — and ADR-004 is about to grade recorded traces, which is the post's stated reason to stop guessing. |
| 14 | Bash as a policy-aware interpreter; approval at the capability, not the string | `ToolPolicy` votes over the envelope's command string (`Deny(string)`, `Pending(reason, default)`; 026 §3.1 proposes codes). The confined container removes sudo, ssh, the docker socket and host credentials and pins a bot identity (019 D2–D5). `AILANG_FS_SANDBOX` bounds Motoko's own `std/fs` and does not reach a subprocess (`DESIGN-motoko-as-delegate.md` §3.4). | The post's "TSA screen of Bash". Motoko's answer is to remove capabilities from the container rather than to see inside `bash -lc`. |
| 15 | One-pass RichText; typed components; TLA+ transcript protocol | `src/tui/src/ui.ts` (4,446 lines) on `@mariozechner/pi-tui ^0.64.0` (`package.json`) with chalk strings; the tool renderer contract is `renderCall: (call, ctx) => string` (`ui.ts:825`); `hardTruncateLine` (`:1127`); Kitty images cached per cell. No transcript protocol; no formal model of resize or scrollback (the stream-reconcile and wait-state jest files check cases by hand). | The exact contract the post profiles at 267 s — on the library the post's author first patched. |
| 16 | Verification is part of the interface; views are projections | `MotokoRuntimeStatus` (a machine-readable status tool), the answer-file gate ("never the agent state", `DESIGN-motoko-as-delegate.md` §3.2), herdr's `terminal session observe|control` NDJSON frames adopted as the off-screen protocol (019 D4), and dagr as a read-only projection whose producer is the extension because a model producer fabricated receipts under `--strict` (`DESIGN-dagr-as-delegation-view.md` §2). Views: TUI, headless logger, herdr pane and agent-state row, dagr. | **Ahead** on verification-as-interface. Not a pure view: the TUI process hosts the lease, the resume plan, the journal writer and the executor. |
| 17 | Rust core; Python extensions; language choice as architecture | AILANG core (45,358 lines under `src/core`, 22,411 of them `dst_*`), AILANG extensions scaffolded by `ailang init motoko-extension`, a generated registry (`src/core/ext/registry_generated.ail`, build-time; no hot reload), TypeScript host. | The strongest instance of the post's "language is architecture": the compiler bounds what an agent-written extension may do. The cost is the post's own: every deep builtin must be written from scratch in a young stdlib, and the TS host is the post's critique verbatim. |

---

## 3. Where the ideas land

### 3.1 Motoko and omp² are converging on the journal from opposite sides

The post gets correctness from **representation**: one tree, non-replayable state
unrepresentable, replay of the demo file equals the original. Motoko gets it from
**verification**: typed effect rows, Z3 contracts with a substantive/tautology register, strict
replay against a recorded world, fail-closed gates. The two meet at ADR-003. It reached the post's
position by the same route the post describes — the owner's challenge "why can't we just record
all events and replay them", then a reading of oh-my-pi's session manager, from which the
`id`/`parent_id` fields and the leaf pointer were taken (ADR-003 status paragraph and retraction 6).
ADR-004 goes one step past the post: a recorded session is an execution program, strict-replayed by
every candidate commit and graded by an evaluator the candidate does not own. That is the `.dem`
file used as a benchmark, which the post does not propose.

Two things follow.

- **The post's Appendix A cannot happen to Motoko extensions**, for a structural reason the post
  would recognise: AILANG has no mutable binding, and the ABI's only state carriers are the
  history slice, the state key, the world token and the artifacts. Every one of the nine Appendix A
  bugs is a closure or a registry surviving what the tree does not record. Motoko additionally
  *measures* extension honesty (`declared_vs_performed`, the profile-coverage artifact) where the
  post audited 78 examples by hand.
- **What is still outside Motoko's tree is the post's tier C almost exactly.** Delegate state in
  dagr run files and herdr panes; the extension world token's contents; park and wake until
  PLAN-003 P4; and the TUI's own state — lease, resume plan, journal writer. The post's rule
  "adding a stateful feature never adds a call site to rewind, fork, resume or replication" is met
  for the loop state and not yet for delegation. ADR-002's `open_waits` plus P4's park entries is
  the fix in flight; the row to watch is whether a `DelegateWait` in the journal is enough to
  re-derive the dagr graph, or whether the run file stays a second authority.

### 3.2 The runtime chapter is the sharpest critique, and it is aimed at the env-server

The post's boundary: the host owns session state, inference, policy, routing, approval, limits and
journaling; the sandbox owns execution through a small obedient stub; every stream is bounded
before it can exhaust the host. Motoko's placement is inverted in one respect and matches in
another. Policy, the step machine and the decision to call a tool are in the AILANG child, and
that side is the verified one. Execution, the journal writer, the lease and the model-calling
claim-check are in the TypeScript host, and that side is the unverified one. 028 VISION Layer 2
already states the asymmetry ("is there any code that can change agent behaviour which no verifier
ever sees? — the answer must be no"). The post supplies the shape the fix should take:

- an executor that does only `exec` and returns bounded streams, with truncation and timeout as
  **structured diagnostics** the model can see (today: a silent 8,000-char slice and an exit code
  of 1 that also means "the command failed");
- a kill boundary that reaches what the command spawned (today: the zombie sweep, and the standing
  rule that a full sweep never runs in the foreground);
- everything else — claim-check, subagent model calls, scratchpad kernels — moved out of the stub
  so the stub is small enough to reason about, and so a popped executor yields "a stub, python and
  grep" rather than the host's API keys.

The post's "subagents cross the same boundary" (copy-on-write views, child returns a diff) is the
`herdr worktree` question 019 ADR-001 option D left open, with the same trade-off the ADR
recorded: isolation of the tree against a human and an agent looking at the same working tree.

### 3.3 Directors are the largest missing primitive, and ADR-002 D2 is where they would start

Motoko's multi-turn behaviours are three guards, the persist nudge and the DP7 gate. Each keeps its
budget by counting its own marker messages in the history slice (005 D2). That derivation is
replay-honest — the same guard over the same journal gives the same budget — which puts Motoko ahead
of the post's `let turnCount = 0`. But composition is a fixed precedence (`ContinueWithFeedback` >
`Accept` > `NoDecision`, registry order) plus one reviewed pipeline in `classify_candidate`. The post's
missing operations are exactly the ones Motoko lacks:

- **Push**: DP7 cannot push a "force `EditFile` until check_core is green" child; it injects
  feedback and hopes.
- **Done, offering the yield back**: after the persist nudge's budget is spent it returns
  `NoDecision`, and the empty-stop floor catches the result; nothing hands the candidate back to the
  behaviour that was waiting.
- **Inspection**: `MotokoRuntimeStatus` reports steps, budget and compaction; it cannot say which
  behaviour currently owns the yield, because that is not a value anywhere.

The post's plan-mode listing is the DP7 gate almost line for line, and the post's position is that
such a behaviour belongs on the public extension surface so holes in that surface become impossible
to ignore. ADR-002 D2's explicit pipeline is the right seed: it already names the order; a Director
stack is that order made a value the journal can carry and the status tool can show.

### 3.4 Smaller landings

- **Row 7 is a finished instance of the inference chapter's central rule.** The post's compiler
  refuses to answer "false" when it has no rule. Motoko found the int-zero reading in its third
  logged session, confirmed it as steady state in the fourth, and fixed it as a sum. The remaining int with "0 means unknown" is `ExtCtx.context_limit`; it is
  the same bug waiting in the ABI.
- **Row 12's cache cost is already instrumented** (`system_prefix_digest`, cache-read share).
  Motoko can measure the post's roster experiment on its own tour without new tooling: run the
  NOTE-008 tour with and without the extension schemas and read the prefix size and wall clock.
- **Row 16 is the one place the post would learn from Motoko.** "The gate is the answer file,
  never the agent state" and "the producer is the extension, not the model, because the model
  fabricated under `--strict`" are the post's "verification is part of the interface" with
  measurements attached.

---

## 4. Concrete candidates

### 4.1 P4's park entries as the job primitive (ADR-002, PLAN-003 P4)

Add a fourth `WaitDescriptor` arm for a backgrounded command — pid or pane, a bounded output
artifact path, a kill handle — so a detached `make dst` and a herdr delegate are one surface with
one settle path and one kill path, and so the journal's park entry can carry both. The post's
argument is that otherwise every tool grows its own spawn, poll, message, kill and list; Motoko's
`Delegate` / `DelegateCheck` / `herdr pane read` / `nohup … &` is that growth already. Cost: one
sum arm, one adapter family, one `dst_fault_catalogue` class (`job_lost`), and P4's entry types.
Sequenced after P4's own gates, not before.

### 4.2 Shrink `env-server.ts` to the stub (028 Layer 2)

`/exec` plus bounded streams plus structured truncation and timeout diagnostics; claim-check and
`callSubagentModel` moved behind the child's `ports`; scratchpad kernels behind their own process.
The diagnostics half is the cheap part and is independently useful: a `ToolResultEnvelope`
`diagnostics: [Diag]` field beside `metadata`, projected into the tool message by
`handled_tool_message` rather than parsed out of `stdout`. This is the post's "bound output once,
as opt-out, with a notice the model can see" and it fixes the silent slice in row 4.

### 4.3 Intent and version on the tool envelope (ADR-004 consumer)

`ToolCallEnvelope` gains `intent: string` (model-supplied, optional, streamed early) and
`ToolSchema` gains `version`. ADR-004's evaluator reads recorded traces; the post's reason for
the fields is precisely that once traces are graded, guessing which contract produced a call is
debt. Cheapest change on the list: one ABI minor, one vocabulary row, one golden.

### 4.4 Refusal codes (already 026 §3.1)

The post's "structured, retryable error" for schema repair and its refusal-with-code for policy
are the same `Deny(Refusal)` change 026 priced. No new work; one more reason.

### 4.5 A roster experiment on the existing tour

Run the NOTE-008 read-only tour with the extension `DescribeTools` schemas present and absent and
record prefix tokens, cache-read share and wall clock. Half a day; decides whether a `dyn`-style
discovery surface is worth building before the primitives are deepened.

---

## 5. What does not transfer

- **Python `@remote` extensions.** The post chose Python for AST introspection and a dependable
  Eval. Motoko's extension language is AILANG by design and its boundary story is stronger: the
  compiler rejects an undeclared effect at the `Capability` constructor (017 Q3). Importing a second
  extension runtime would trade a static guarantee for ergonomics.
- **The in-process Bash interpreter as a near-term item.** It is the right end state for row 14
  and it is a coreutils reimplementation. Under the no-human-code rule and a young stdlib the
  container-shaped answer (019) is the honest one for now; the interpreter is a `RESEARCH` of its
  own, not a candidate here.
- **Speculative compaction before P4.** Branching the conversation to compact on the side needs a
  journal that can hold a branch and a tree-diff to splice it. The fields exist; the operations do
  not. Sequence after the journal carries park/wake.
- **The convar console as a user surface.** Binds, aliases and cfg files solve a TUI customisation
  problem Motoko does not have. The transferable part is the declaration site and the inheritance
  rule, not the console.
- **The renderer rewrite.** The TUI is on the wrong side of the 267 s story and the post's
  library is the one in `package.json`; the fix is a rewrite of `ui.ts`. Read the transcript
  protocol before any TUI work — its invariants are what the stream-reconcile tests check by hand —
  but do not start there.

---

## 6. Risks

- **Reading the post as a scorecard.** Its numbers are omp's on omp's workloads. The only two
  Motoko can reproduce cheaply are the roster cost (§4.5) and the truncation silence (row 4); the
  rest are shape arguments.
- **A Director stack is a second loop.** Done badly it moves `classify_candidate`'s order into a
  data structure and keeps the same hand-ordering, now harder to see. The test is the post's: can
  an extension push a child and receive the yield back without the core knowing its name.
- **Stub-shrinking the env-server reopens 028 PLAN-001's batch-skip path.** The executor's one
  known fail-open bug has zero tests; moving code across it without pinning that path first is the
  regression 028 Layer 4 exists to prevent.
- **Journal scope creep.** Row 1's strength is that the journal is a fold of history deltas and
  nothing else. Carrying delegate state and job state into it (§4.1) must keep the fold pure and
  the child write-free (PLAN-003 §0.8), or ADR-003's whole argument is spent.

---

## 7. Candidate follow-ons (none decided)

1. **EXPERIMENT** — §4.5, the roster cost on the NOTE-008 tour. Half a day. Independent.
2. **ABI minor** — §4.3, `intent` on `ToolCallEnvelope`, `version` on `ToolSchema`, and §4.2's
   `diagnostics` on `ToolResultEnvelope`. One vocabulary row and golden each. Independent; lands
   before ADR-004 P1 admits its first entry.
3. **ADR** — §4.1, a background-command wait as the fourth `WaitDescriptor` arm and its park entry.
   Depends on PLAN-003 P4 being scheduled.
4. **PLAN** — §4.2, the executor stub: exec-only `env-server`, claim-check and subagent calls behind
   `ports`. Depends on 028 PLAN-001's batch-semantics pin landing first.
5. **RESEARCH** — Directors over ADR-002 D2's pipeline: what a stack that the journal carries and
   the status tool reports would cost, measured against the three guards and DP7. Depends on
   nothing; decides whether 3 above should carry an `owner` field from the start.
