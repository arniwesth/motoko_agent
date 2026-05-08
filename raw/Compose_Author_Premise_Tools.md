# Compose Author Premise Tools — Plan

**Date:** 2026-04-13
**Status:** Draft — depends on `Compose_As_Extension.md` landing first
**Suggested branch:** `Compose_Author_Premise_Tools`

**Related context:**
- `.agent/plans/Compose_As_Extension.md` — prerequisite; this plan assumes Compose lives as an extension under `src/core/ext/compose/`
- `.agent/summaries/2026-04-12-compose-semi-formal-evidence-guard-implementation.md` — SF1–SF5 current behavior

---

## Goal

Give the Compose author pass a read-only tool whitelist (`read_file`, `grep`, `list_dir`, `file_exists`, `stat`) that executes inside the extension host. Every tool result is appended to a **premise ledger**. The certificate validator (SF3) then enforces that every `PREMISES` line binds to a ledger entry or to a snippet-declared effect.

This turns PREMISES from "LLM-asserted" into "tool-witnessed."

## Motivation

Today the authoring LLM must either:
1. Guess file contents and hope the snippet's declared `FS` effect covers re-reading them at exec time, or
2. Fabricate premises that SF5 ClaimCheck might miss.

With premise tools:
- Reads happen under extension supervision (same sandbox as snippet exec).
- The snippet becomes a pure transform over witnessed inputs instead of redeclaring `FS`/`Process`.
- SF3 gains a concrete binding target — a premise is no longer a claim, it's a citation.
- SF5's comparator gets a sharper artifact (intent + certificate + ledger).

Net: smaller snippets, stronger evidence, less fabrication surface.

## Non-goals

- **Effectful author tools** (write, network, process spawn). Those stay in the snippet, where effect declarations and SF2 cover them.
- **Replacing the main agent's tool use.** Author tools are scoped to the Compose author pass only; main-agent bash remains the primary execution path.
- **Dropping the snippet requirement.** The AILANG snippet is still the execution record and must still be produced.
- **Caching across invocations.** Ledger is per-invocation in the MVP.

## Assumptions (please confirm before Phase 0)

1. **Prerequisite landed.** `Compose_As_Extension` is merged; `compose.ail` owns the author pass and can run a multi-turn author loop.
2. **In-band tool-call protocol via a `tool_call` fence** (see §Protocol). Not native OpenAI/Anthropic tool-calling API — keeps cross-provider neutrality and matches the existing fence-parsing pattern.
3. **Sandbox alignment.** Author tools resolve paths through `AILANG_FS_SANDBOX=<workdir>`; attempts to escape return an error visible to the author.
4. **Budget default:** 10 tool calls per Compose invocation, configurable via `AILANG_COMPOSE_AUTHOR_TOOLS_BUDGET`. Rollover across retries within one invocation shares the budget (to prevent retry-based bypass).
5. **Result size bound:** 16 KB per tool call by default, configurable via `AILANG_COMPOSE_AUTHOR_TOOLS_MAX_BYTES`; truncation uses the same marker format as `compose_stdout`.
6. **Default off** on first release (`AILANG_COMPOSE_AUTHOR_TOOLS=0`); flip to default-on in a follow-up after bake-in, matching the SF5 rollout pattern.
7. **Event names** (`compose_author_tool_call`, `compose_author_tool_result`, `compose_author_ledger_snapshot`) are contract from Phase 2 onward.
8. **Path denylist in effect by default** — default globs block common secret files (`.env*`, SSH keys, `.git/**`, etc.; full list in Phase 1.1). Operators can loosen via `AILANG_COMPOSE_AUTHOR_TOOLS_DENY_GLOBS` but the change is auditable.

---

## Protocol

**One action per turn.** The author LLM emits a complete turn ending in a fenced block; the extension parses the whole message after generation completes and acts on the first actionable fence (`tool_call` or `ailang`). Trailing content after the first actionable fence is ignored with `author_turn_discarded_bytes` telemetry.

A `tool_call` fence carries a JSON request:

````
I need to check what imports are declared in the entry.

```tool_call
{"tool": "read_file", "args": {"path": "src/tui/src/index.ts", "max_bytes": 4096}}
```
````

The extension parses the JSON, dispatches via the Phase 1 author-tools dispatcher, appends a ledger entry, and injects the result back into the author history as an assistant-observation turn:

```json
{"tool": "read_file", "ok": true, "result": {"path": "src/tui/src/index.ts", "bytes": 3812, "content": "..."}}
```

Authoring continues on the next turn. The loop terminates when the author emits an `ailang` fence (the final snippet) or when the budget is exhausted.

**Why fence + JSON, not native tool-calling API:** (a) provider-neutral — OpenRouter passes tool-calling support through inconsistently; (b) reuses the existing fence-parsing path; (c) transcript is fully inspectable as text, aiding SF5 comparator and debugging.

**Future optimization (not MVP):** if `std/ai.callStreamResult` gains reliable mid-stream interrupt (see Phase 0.5), the protocol can shift to streaming-detect-and-interrupt on fence-close. Out of scope for the MVP; one-action-per-turn is simpler, testable, and provider-neutral.

### Tool whitelist

| Tool | Args | Returns |
|---|---|---|
| `read_file` | `path: string, max_bytes?: int` | `{path, bytes, content, truncated}` |
| `grep` | `pattern: string, path_glob: string, max_matches?: int` | `{matches: [{path, line, text}], truncated}` |
| `list_dir` | `path: string` | `{path, entries: [{name, type}]}` |
| `file_exists` | `path: string` | `{path, exists, type}` |
| `stat` | `path: string` | `{path, size, type, mtime}` |

All pure reads. All paths sandboxed. `grep` uses literal string match in MVP (regex support piggybacks on Phase 5 of `Compose_As_Extension.md` if/when that lands).

---

## Target state

```
src/core/ext/compose/
  compose.ail             [MODIFIED]  author loop runs turns; tool_call fence detected
  author_tools.ail        [NEW]       dispatcher + whitelist + sandbox check + denylist + per-call timeout
  author_loop.ail         [NEW]       multi-turn state machine (generate → parse → dispatch → feed back)
  ledger.ail              [NEW]       PremiseLedger type + accumulator + query helpers
  prompts.ail             [MODIFIED]  author prompt documents the tool_call fence + whitelist
  validator.ail           [MODIFIED]  SF3 gains premise-ledger binding check
  telemetry.ail           [MODIFIED]  premise_binding, tool_call counts, budget_exhausted
  claimcheck.ail          [MODIFIED]  pass-1 input optionally includes ledger (see 4.2)
  *_test.ail              [NEW/MODIFIED]

src/tui/src/
  ui.ts                   [MODIFIED]  render compose_author_tool_* events in the Compose card
```

---

## Phase 0 — Protocol and spec freeze

- **0.1** Freeze the `tool_call` fence format (JSON schema for args; result schema per tool).
- **0.2** Freeze `PremiseLedger` record: `{entries: [{tool, args_hash, content_excerpt, ts}], budget_used, budget_cap}`. `args_hash` enables dedup of identical repeated reads within an invocation (optional optimization); `content_excerpt` is the substring-search target for Phase 3.1 binding checks. No separate `result_digest` — `content_excerpt` already is the authoritative record.
- **0.3** Update the author prompt in `prompts.ail` to document the whitelist, budget, and the PREMISES line grammar: `<path> | "<verbatim_quote>" | <paraphrase>` (three pipe-delimited fields). Include a concrete example and the rule: "the quoted substring must appear verbatim (whitespace-normalized) in the file you read via `read_file`/`grep`." The paraphrase is free text; only the quote is content-checked. **Ledger-bound vs snippet-bound distinction:** if the premise reflects a file the *author* read via a tool, the quote must be text the author already witnessed in the ledger entry (ledger-bound). If the premise reflects a file the *snippet* will read at runtime, the quote is drawn from the snippet's runtime-formatted certificate output — the validator checks the snippet's declared effect, not the quote content (snippet-bound). Both modes use the three-field form; the prompt must describe this split so the author doesn't confuse them.
- **0.4** Pin event shapes: `compose_author_tool_call = {step, tool, args, attempt_id}`, `compose_author_tool_result = {step, tool, ok, excerpt, bytes, truncated}`.
- **0.5** Verify `std/ai.callStreamResult` interrupt support. If mid-stream interruption on fence-close is reliably available, the streaming-interrupt protocol in §Protocol is viable. If not, adopt the **one-action-per-turn** fallback: author emits a complete turn to completion, extension parses the whole message after, acts on the *first* actionable fence (`tool_call` or `ailang`), ignores trailing content with `author_turn_discarded_bytes` telemetry. Recommendation: default to one-action-per-turn for MVP regardless — simpler to test, no runtime-capability gamble; revisit streaming interrupt as a latency optimization later.
- **0.6** Verify `std/fs` reads issued from an extension host honor `AILANG_FS_SANDBOX=<workdir>`. If not, implement the sandbox check in `author_tools.ail` dispatcher (Phase 1.1) before any read is dispatched.

---

## Phase 1 — Tool infrastructure (pure)

- **1.1** `author_tools.ail`: whitelist dispatcher with sandbox enforcement and **path denylist**. Returns `Result[ToolResult, string]`. Denylist defaults: `.env`, `.env.*`, `*.pem`, `*.key`, `*_rsa`, `*_rsa.pub`, `id_ed25519*`, `.git/**`, `.ssh/**`. Configurable via `AILANG_COMPOSE_AUTHOR_TOOLS_DENY_GLOBS` (colon-separated, replaces defaults; operators must re-include what they want to keep). Denied paths return a typed error citing the matched pattern — the file content is never opened. **Per-call timeout:** `AILANG_COMPOSE_AUTHOR_TOOLS_CALL_TIMEOUT_MS` default 5000. Tools exceeding the timeout return `{"ok": false, "error": "call_timeout"}` and count against the budget.
- **1.2** Per-tool implementations over `std/fs` and (for `grep`) `std/process.exec` calling `ripgrep`/`grep` if available, falling back to a pure AILANG line-scanner. **Glob expansion** for `grep.path_glob` lives in the extension (std/fs does not currently expand globs): minimal matcher supporting `*`, `**`, `?`; anything else returns a typed error. Max 500 files matched per call; truncate with marker.
- **1.3** `ledger.ail`: append, snapshot, query-by-path, query-by-substring. Pure; Z3 contracts on append-only monotonicity where tractable.
- **1.4** Budget + truncation helpers. Budget shared across retries within one Compose invocation. **Retry ↔ author-loop state rule:** retries wipe author conversation history but preserve the ledger. Each retry's initial author turn receives a compact "prior reads summary" built from the ledger (`[{tool, path, bytes, truncated}]`, no content), so the author knows what has already been read without re-consuming those tokens in its context. Binding check on subsequent attempts can still resolve against the preserved ledger entries. Matches current Compose retry semantics (history reset) without forcing redundant reads.
- **1.5** Inline tests for dispatch, sandbox rejection, truncation, budget-exhausted, and ledger query semantics.

### Exit criteria

- `ailang test src/core/ext/compose/author_tools_test.ail` and `ledger_test.ail` pass.
- No network, no writes, no process spawns outside the pinned whitelist.
- Sandbox-escape attempt (`../../../etc/passwd`) produces a typed error, not a crash.

---

## Phase 2 — Author loop integration

- **2.1** `author_loop.ail`: multi-turn state machine. Starts with the author system prompt + intent. Each turn: call `std/ai.callStreamResult` with current history **to completion** (one-action-per-turn, per Phase 0.5 fallback); parse the response, locate the first actionable fence (`tool_call` or `ailang`). If `tool_call`: parse JSON, dispatch via 1.1, append ledger entry, append observation to history, continue to next turn. If `ailang`: terminate loop, return snippet. Non-first actionable fences within a turn are ignored with `author_turn_discarded_bytes` telemetry.
  - **Failure modes:**
    - **Budget exhaustion:** on the turn that would exceed budget, dispatch is skipped; the would-be result is replaced with observation `{"ok": false, "error": "budget_exhausted", "remaining": 0}` and the author gets one final turn to emit a snippet with what it has. If that turn also produces a `tool_call`, loop terminates with retriable error `author_budget_exhausted_no_snippet`.
    - **Malformed `tool_call` JSON:** parse error fed back as `{"ok": false, "error": "malformed_tool_call", "detail": "<msg>"}`. Counts against the budget. Three malformed-in-a-row terminates the loop with retriable error `author_repeated_malformed_tool_call`.
    - **No fence produced (author chatted without acting):** counts as a wasted turn against a separate `wasted_turns` counter (cap 3); on cap-hit, loop terminates with retriable error `author_no_action`.
- **2.2** Emit `compose_author_tool_call` before dispatch and `compose_author_tool_result` after. Emit `compose_author_ledger_snapshot` once at snippet emission.
- **2.3** `ui.ts`: render tool events in the Compose card as a compact per-call line; expand on click/hotkey (existing card-expansion pattern).
- **2.4** Wire the loop into `compose.ail` behind `AILANG_COMPOSE_AUTHOR_TOOLS` (default `0`). When disabled, author pass runs single-turn exactly as today.

### Exit criteria

- With `AILANG_COMPOSE_AUTHOR_TOOLS=0`: behavior bit-identical to post-`Compose_As_Extension` baseline. Golden tests from the prior plan still pass.
- With `AILANG_COMPOSE_AUTHOR_TOOLS=1`: a controlled smoke task that requires reading `package.json` produces a ledger with at least one `read_file` entry and a snippet containing at least one **ledger-bound** PREMISES line in the three-field form citing that read.
- Budget-exhaustion test: a fixture that requests 11 tool calls with budget 10 confirms the 11th call returns a budget-exhausted error and the author either emits a snippet with what it has or terminates with a retriable error.

---

## Phase 3 — Premise-ledger binding in SF3

- **3.1** Extend the `certificate` validator in `validator.ail`:
  - Parse each `PREMISES` line under the **new three-field grammar**: `<path> | "<verbatim_quote>" | <paraphrase>` (pipes as delimiters; quote must be double-quoted; paraphrase is free text).
  - Classify each premise:
    - **Malformed:** line does not parse into three fields, or quote is not double-quoted, or quote is empty. High-confidence validator failure → retry with format hint.
    - **Ledger-bound:** path resolves to a `read_file`/`grep` ledger entry **and** the verbatim quote (whitespace-normalized) is a contiguous substring of that entry's content excerpt.
    - **Snippet-bound:** path is cited as an effect target inside the snippet AND the snippet declares the appropriate effect (`FS` for file reads, etc.). The quote and paraphrase are not content-checked — the snippet's own exec is the witness. Recorded for telemetry; does not fail validation.
    - **Unbound:** neither. High-confidence validator failure → retry.
- **3.2** Telemetry addition: `premise_binding = {ledger_bound: N, snippet_bound: N, unbound: N}` on each attempt.
- **3.3** Retry hint on unbound premises: "Premise `<line>` — the quoted substring was not found verbatim in any ledger entry for this path, and the snippet does not declare an effect that would read it. Either (a) issue a `read_file`/`grep` tool call and cite a quote drawn from the observed content, or (b) move the read into the snippet and declare the appropriate effect (`FS` for file reads)." Retry hint on malformed premises cites the three-field grammar and gives one example line.

### Exit criteria

- Golden fixture with a valid ledger-bound certificate passes validation.
- Golden fixture with a fabricated premise (quote not in ledger) fails validation with `unbound` classification.
- Golden fixture with a malformed premise (missing quote field, unquoted quote, or empty quote) fails validation with `malformed` classification.
- **Truncation-cutoff case:** fixture where author reads a 100 KB file truncated to 16 KB, then cites a quote that exists in the file beyond the 16 KB cutoff → classifies as `unbound` (author never witnessed it).
- Existing snippet-only (no tool calls) certificates still pass via snippet-bound path under the new grammar (they must emit the three-field form with quotes drawn from the snippet's own output).

---

## Phase 4 — SF2 / SF5 interaction

- **4.1** SF2 recalibration. Today SF2 requires `FS` or `Process` in declared effects for `analyze`/`summarize` intents. With author tools available, a snippet may legitimately declare *no* effects because reads happened at author time. Update SF2: accept an effectless snippet for `analyze`/`summarize` intent **iff the certificate contains at least one ledger-bound premise** (classification from Phase 3.1). An unrelated ledger entry with no cited quote does not satisfy SF2 — the check must reflect what the certificate actually uses, not merely what the author happened to read. Track `sf2_witness_source = {declared_effects | author_ledger | both}` in telemetry.
- **4.2** SF5 ClaimCheck pass-1 input. Currently the informalizer sees only certificate stdout. With a ledger, pass it alongside: `{certificate: ..., ledger_summary: [{tool, path, excerpt}]}`. The comparator then has a concrete baseline for premise fidelity. Gate on `AILANG_COMPOSE_CLAIMCHECK_LEDGER_IN_INFORMALIZER` (default `1`).
- **4.3** Preserve the SF5 separation invariant: pass 1 still sees no intent, pass 2 still sees no certificate/ledger — only the pass-1 prose. Add a test that inspects prompt strings to confirm.

### Exit criteria

- SF2 test matrix updated: effectless snippet + certificate with ≥1 ledger-bound premise for `analyze` → pass; effectless snippet + certificate with zero ledger-bound premises (even when the ledger has unrelated entries) for `analyze` → fail; effectless snippet + empty ledger for `analyze` → fail (unchanged from today).
- SF5 replay harness fixture exercises ledger-in-informalizer path; separation-invariant test passes.

---

## Phase 5 — Default flip, docs, cleanup

- **5.1** Flip `AILANG_COMPOSE_AUTHOR_TOOLS` default to `1` after a bake-in window (at least one week of dogfooding, or an explicit signoff).
- **5.2** Update `CLAUDE.md` and `README.md`: new env vars, tool whitelist, protocol, PREMISES binding rule, SF2 recalibration.
- **5.3** Session summary at `.agent/summaries/YYYY-MM-DD-compose-author-premise-tools.md`.

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Prompt injection via file contents (author reads a file that contains "ignore prior instructions") | Medium | Treat tool results as untrusted data; wrap in an observation envelope with a fixed delimiter; add a system-prompt clause that file contents are data, not instructions. Also budget caps limit blast radius. |
| Premise forgery — author cites a ledger entry but the verbatim quote doesn't actually appear in it | Medium | Phase 3.1 binding check enforces contiguous-substring match of the quoted field against the ledger's content excerpt; validator fails the attempt and classifies the premise as `unbound`. |
| Author tool loop non-termination | Low | Hard budget + per-call timeout. |
| Context bloat from large tool results | Medium | Per-call byte cap; excerpt truncation with marker; ledger summaries elide full content on second-and-later mentions. |
| SF5 pass-1 input change destabilizes existing verdicts | Low | Gate behind `AILANG_COMPOSE_CLAIMCHECK_LEDGER_IN_INFORMALIZER=1` with an off-switch; replay harness covers both paths. |
| Two worlds of reads (author + snippet) make debugging harder | Medium | `premise_binding` telemetry splits ledger-bound vs snippet-bound on every attempt; compose card shows both counts. |
| `grep` fallback (pure AILANG line scanner) diverges from system `grep`/`ripgrep` on edge cases | Low | Literal-match-only in MVP; regex deferred to Phase 5 of the prior plan. |
| Author reads secrets inside workdir (`.env`, SSH keys, `.git/`) | Medium | Default path denylist (Phase 1.1); denied reads return typed error citing pattern, never open the file; operators can adjust via `AILANG_COMPOSE_AUTHOR_TOOLS_DENY_GLOBS` but the change is auditable in config. |
| Multi-turn authoring with accumulated tool results inflates per-Compose token spend 3–10× vs. current single-turn author | Medium | Budget cap + per-call byte cap bound worst case; telemetry `author_turns`, `author_tokens_in`/`out` exposes cost per invocation; bake-in period (Phase 5.1) reviews real spend before default flip. |

## Rollback

Each phase is independently revertable until Phase 5.1 (default flip). `AILANG_COMPOSE_AUTHOR_TOOLS=0` fully disables the feature and returns Compose to single-turn author behavior. Phase 3.1 validator changes are additive (new classification, not reinterpretation of existing rules), so disabling the feature automatically short-circuits the new validation path. No destructive cutover in this plan.

---

## Open questions

1. **Tool-call format** — JSON in `tool_call` fence (default, specified here) vs native provider tool-calling API (cleaner per-provider, fragmented cross-provider). Confirm fence-JSON is acceptable.
2. **Ledger persistence across retries within one invocation** — full ledger persists across retries (not just the budget counter). A premise cited in attempt 3 may bind to a read made in attempt 1. Rationale: avoids redundant reads, keeps the budget usable across retry loops, matches the shared-budget intent. Tradeoff: a bad read (e.g., author misread or was confused by file contents) can influence later attempts. Mitigation: the paraphrase→quote discipline from Phase 3.1 means binding still requires a verbatim substring match, so a "bad read" can only produce bad paraphrases, not bad quotes. Confirm this default.
3. **Ledger visibility to the main agent** — main-agent scratchpad gets the certificate only; `PREMISES` is the interface. Full ledger rendered in the Compose card for the operator, persisted to `.motoko-store/compose/<attempt_id>.ledger.json` for eval (subject to the same 24h prune as snippets). SF5 pass-1 consumes the ledger per Phase 4.2. Aggregate counts are *not* inlined into the main agent's scratchpad (low value, multiplicative context cost across subsequent turns). If a need emerges from real use, add a scoped `compose_inspect(attempt_id, query)` tool in a follow-up rather than pre-building it. Confirm this default.
4. **`grep` implementation** — shell out to system `grep`/`ripgrep` (faster, depends on host) vs pure-AILANG scanner (slower, portable). Default: prefer system tool when available via `std/process.exec`, fall back to AILANG scanner.
5. **Per-tool-call author intent declaration** — should the author be required to emit a one-line "why I'm reading this" before each `tool_call`? Tightens auditability; adds tokens. Default: optional but encouraged in the system prompt.
6. **Intent-kind gating** — restrict author tools to `analyze`/`summarize`/`list` intents (where they're most useful), or enable across all kinds? Default: enable for all kinds; `transform`/`compute` will rarely use them but shouldn't be blocked.
