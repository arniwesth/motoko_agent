# Compose Semi-Formal Evidence Guard

Date: 2026-04-12
Status: Proposed
Scope: Compose subagent guard in `src/tui/src/env-server.ts`,
subagent author prompt, `expected_output` validator, minor core types

## Relationship to existing semi-formal plans

This plan is **not** a rewrite of the main-agent semi-formal verifier work.
It is scoped to the **Compose subagent** (`/compose` endpoint + author
prompt) and strengthens the existing anti-fabrication guard by adopting
the certificate pattern from *Agentic Code Reasoning* (`papers/2603.01896v2.md`).

- `Semi_Formal_Reasoning_Integration.md` — main agent verifier pass;
  unaffected by this plan.
- `Core_Extension_System_for_Semi_Formal.md` — extension substrate for
  main-agent semi-formal logic; unaffected.
- `AILANG_Composition_Subagent.md` — governing plan for the Compose
  subagent itself. This plan is an extension of its Phase 3b
  (output-contract enforcement) and Phase 5c (anti-fabrication guard).

Use the extension substrate from `Core_Extension_System_for_Semi_Formal.md`
**only if** that substrate is already adopted; otherwise keep this plan
self-contained inside env-server + author prompt.

## Motivation

Current guard (`composeSnippetGuard` at `src/tui/src/env-server.ts:311`)
detects fabrication by substring match on snippet source:

1. Marker blacklist (`"simulated analysis"`, `"hypothetical"`, `"assume"`, …)
2. If intent contains analysis keywords (`"reason about"`, `"analy"`,
   `"architect"`, `"trace"`, `"understand"`, `"inspect"`), require
   literal `readFile(` or `exec(` in snippet source.

Weaknesses:

- Keyword-based intent detection — false positives on `"assume"`;
  false negatives on any phrasing outside the keyword set.
- `readFile(` / `exec(` presence is a weak evidence witness —
  `exec("echo hi")` satisfies it without producing relevant evidence.
- `expected_output` contract (`non_empty` / `contains_all` / `lines_regex`)
  is decoupled: it validates stdout after execution but does not feed
  back into the guard.

(`hints.read` enforcement was considered and dropped from scope —
hints are disabled by default after the 2026-04-12 policy change,
so enforcing them would codify a deprecated mechanism. If hints are
re-enabled as a first-class signal in a future phase, revisit.)

Two external references shape this plan:

1. **Meta paper** (`papers/2603.01896v2.md`, Ugare & Chandra, 2026) —
   moving from unstructured reasoning to a structured **certificate**
   (premises + trace + conclusion, each claim bound to an explicit
   evidence-read) lifts agentic code-reasoning accuracy by 9–11
   percentage points on code QA and patch equivalence. This motivates
   SF1–SF4: require snippet stdout to be a certificate whose claims
   structurally cannot be fabricated without a real evidence-read.

2. **ClaimCheck** (metareflection/claimcheck,
   midspiral.com/blog/claimcheck-narrowing-the-gap-between-proof-and-intent) —
   to verify that a formal artifact actually captures an informal intent,
   use **round-trip informalization**: (a) one model describes the
   artifact in plain language *without seeing the intent*, (b) a second
   model compares that cold description against the original intent.
   Structural separation prevents the model from anchoring on the intent
   and rationalizing a mismatch. Empirically beat end-to-end prompting
   by 27pp (96.3% vs 69.4%) at 6× lower cost. This motivates SF5:
   catches the "technically true but off-target" failure mode that no
   amount of premise-structure enforcement can prevent.

## Design principles

1. Prefer structural prevention over substring detection.
2. Use AILANG's effect annotations as the primary evidence witness
   (forge-proof, type-system-backed).
3. Couple the guard with the existing `expected_output` contract
   rather than adding a parallel mechanism.
4. All new behavior gated behind env vars; defaults preserve current
   behavior unless an analysis-kind intent is explicitly declared.
5. The main agent's surface does not change unless a phase explicitly
   opts in (see SF3).

## Planned file changes

Expected to be modified:

1. `src/tui/src/env-server.ts` — effect-set inspection, certificate
   validator kind, certificate-prompt injection, citation-binding check
2. `src/core/prompts.ail` — Compose tool contract updates when a new
   `intent_kind` or `expected_output.kind=certificate` is supported
3. `src/core/types.ail` — (SF3) extend `expected_output` contract
   encoding if certificate kind is added
4. `src/core/rpc.ail` — (SF5, optional) critic-pass plumbing
5. `.agent/plans/AILANG_Composition_Subagent.md` — cross-reference

Expected to be added:

1. `src/tui/src/compose-claimcheck.ts` — SF5 two-pass orchestration
   (subprocess spawner, event bridging, verdict parsing)
2. `src/tui/src/__tests__/compose_guard_semiformal.test.ts` — guard tests
3. `src/tui/src/__tests__/compose_certificate_validator.test.ts` —
   validator tests
4. `src/tui/src/__tests__/compose_claimcheck.test.ts` — SF5 tests
   including separation invariant, timeout handling, per-attempt
   invocation

## Environment variables

| Var | Default | Purpose |
|---|---|---|
| `AILANG_COMPOSE_EFFECT_GUARD` | `1` | SF2: require `FS`/`Process` effect for analysis intents |
| `AILANG_COMPOSE_CERTIFICATE_TEMPLATE` | `0` | SF1: inject certificate template into author prompt |
| `AILANG_COMPOSE_CERTIFICATE_VALIDATOR` | `0` | SF3: enable `expected_output.kind=certificate` |
| `AILANG_COMPOSE_CITATION_BINDING` | `0` | SF4: require cited paths appear as read-call arguments |
| `AILANG_COMPOSE_CLAIMCHECK` | `0` | SF5: enable round-trip informalization check |
| `AILANG_COMPOSE_CLAIMCHECK_INFORMALIZER_MODEL` | `AILANG_SUBAGENT_MODEL` | SF5: model for the cold informalization pass |
| `AILANG_COMPOSE_CLAIMCHECK_COMPARATOR_MODEL` | `AILANG_SUBAGENT_MODEL` | SF5: model for the intent-vs-informalization comparison |
| `AILANG_COMPOSE_CLAIMCHECK_TIMEOUT_MS` | `30000` | SF5: per-subprocess timeout (informalizer + comparator each) |
| `AILANG_COMPOSE_CLAIMCHECK_MAX_INVOCATIONS` | `10` | SF5: cap on SF5 pairs per compose session; further attempts skip SF5 and log `sf5_budget_exhausted` |
| `AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES` | `4000` | SF5: truncate certificate stdout passed to informalizer; reuses Phase 3b bound by default |

Phase defaults flip to `1` only after the phase has been exercised on
real tasks. SF2 ships on by default because it replaces an existing
heuristic that is already on by default.

## Phased delivery

### SF2 — Effect-set evidence witness (first; replaces current heuristic)

Smallest diff, highest immediate value. Replaces the `readFile(` / `exec(`
substring heuristic with an inspection of the snippet's declared effect
set — which AILANG's type system has already validated by the time the
guard runs (`ailang check` passes before the guard fires).

Effect taxonomy is confirmed distinct in `ailang-v0.9.0-docs.md`
(lines 380, 445, 476): `FS` covers `readFile`/`listDir`, `Process`
covers both `exec` (`std/process`) and `asyncExecProcess`
(`std/stream`). A snippet that declares neither cannot physically
read the filesystem or spawn a subprocess. Note: `CLAUDE.md`'s effect
list is stale and references only `{IO, Net, AI, SharedMem}`; treat
the v0.9 docs as authoritative and update `CLAUDE.md` as a
side-errand during SF2 implementation.

Files:

- `src/tui/src/env-server.ts`

Changes:

1. Add `parseDeclaredEffects(snippet: string): Set<string>` — extract
   the effect list from the snippet's `main` signature
   (`! {IO, FS}` style). Reuses the existing AILANG regex surface;
   `ailang check` has already validated the annotation is consistent
   with actual effect use, so the declared set is authoritative.
2. Modify `composeSnippetGuard`:
   - Keep existing marker blacklist (narrowed — drop `"assume"` and
     `"assumption"`, retain `"simulated analysis"`,
     `"in a real execution"`, `"would read files"`,
     `"based on structural inspection"`, `"hypothetical"`).
   - Replace the analysis-intent evidence check with:
     ```
     if isAnalysisIntent(intent) && !declaredEffects.has("FS")
        && !declaredEffects.has("Process") {
       return "compose guard: analysis intent requires FS or Process effect"
     }
     ```
   - `isAnalysisIntent` keeps the current keyword list; can be
     superseded by SF1's `intent_kind` later.
3. Log the declared effect set in `telemetry_json` so retry
   patterns on effect-mismatch are measurable.

Validation:

1. Snippet with `! {IO}` only + analysis intent → rejected.
2. Snippet with `! {IO, FS}` + analysis intent + no actual
   `readFile` call → accepted (deliberate: `ailang check` guarantees
   the effect is genuinely used somewhere in the call graph).
3. Non-analysis intent unaffected.
4. False-positive on `"assume"` is gone.
5. Regression: all existing Phase 5c guard tests continue to pass.

Env var values:

| Value | Behavior |
|---|---|
| `1` (default) | Effect-set check active; marker blacklist also applied |
| `legacy` | Old substring-based evidence path (pre-SF2 behavior); marker blacklist retained |
| `0` | Guard disabled entirely (marker blacklist off too); for benchmarking only, not a supported production mode |

Exit criteria: `AILANG_COMPOSE_EFFECT_GUARD=1` is the new default.
Keep `legacy` mode available for at least one phase after the
default flip; remove only after a round of real-task validation
confirms no regression. No fallback at all is a recipe for a
production hang with no rollback lever.

Deliberate constraint: if the main agent sends `hints.avoid` containing
`FS` and `Process` together with an analysis intent, the snippet
cannot declare either effect and SF2 will reject unconditionally. This
is intentional — a caller cannot simultaneously demand analysis and
deny all evidence capabilities. Document this in the main-agent prompt
guidance so the model understands the constraint rather than hitting
it blind.

### SF1 — Certificate template in author prompt

Teaches the subagent to structure analysis-snippet stdout as a
certificate with explicit premises, trace, and conclusion. This is the
paper's core mechanism and the highest-leverage behavioral win.

Files:

- `src/tui/src/env-server.ts` (author prompt assembly)
- `src/core/prompts.ail` (main agent guidance update, if `intent_kind`
  is surfaced in the tool contract)

Changes:

1. Add `intent_kind` field to the Compose tool schema in the main
   agent prompt with values `analyze | list | transform | compute | fetch | summarize`.
   Optional; default inferred from intent text using the keyword
   classifier. **Classifier fallback rule:** when no keyword matches,
   default to `compute` (SF5 skips, conservative non-firing). This
   errs toward not spending LLM budget on under-classified intents;
   a user who wants certificate enforcement should set `intent_kind`
   explicitly or phrase the intent with a recognized keyword.
2. **Unify with SF2:** once `intent_kind` is available, SF2's
   `isAnalysisIntent(intent)` predicate switches to
   `intent_kind == "analyze" || intent_kind == "summarize"`. Remove
   the keyword list from SF2 at the same time SF1 lands. Document the
   change in SF2's code comment and the migration note in
   `AILANG_Composition_Subagent.md`.
3. In the subagent author prompt assembler, when
   `AILANG_COMPOSE_CERTIFICATE_TEMPLATE=1`, append a contract block
   keyed on the derived kind:

   **`analyze` kind** — premises/trace/conclusion:
   ```
   Your snippet's stdout MUST be a certificate in this exact form:

     PREMISES
       <path_1> -> <observed fact from that file>
       <path_2> -> <observed fact from that file>
       ...
     TRACE
       <how premises compose into the conclusion>
     CONCLUSION
       <single-line answer to the intent>

   Each <path_N> must appear literally as the argument of a readFile
   or listDir call in your snippet. Do not invent paths. If you cannot
   read a file, omit its premise — do not fabricate.

   Use ASCII "->" as the separator. Both "->" and "→" are accepted
   by the validator; prefer ASCII for consistency.
   ```

   **`summarize` kind** — input/key-points/summary (different shape:
   summarization compresses known input, it does not derive claims
   from evidence):
   ```
     INPUT
       <description of what is being summarized>
     KEY_POINTS
       - <point 1>
       - <point 2>
       ...
     SUMMARY
       <single-paragraph summary>
   ```

4. For `list` / `fetch` kinds, provide a thinner variant (SOURCE ->
   FILTER -> ITEMS for list; URL -> STATUS -> EXCERPT -> DERIVED for
   fetch). ASCII arrows for consistency with SF3's validator.
5. For `transform` / `compute`, no template is injected (no external
   evidence needed).
6. Update few-shot examples in the author prompt to include one
   analyze certificate, one summarize block, and one list block.

Validation:

1. Given an analyze intent, the subagent produces stdout with
   `PREMISES`/`TRACE`/`CONCLUSION` section markers.
2. Given a compute intent, no certificate structure is required or
   imposed.
3. Snapshot tests on the assembled author prompt for each kind
   (template present / absent).

Exit criteria: certificate-shaped stdout is the default output for
analyze and summarize intents in live runs.

### SF3 — `expected_output.kind=certificate` validator

Closes the SF1 loop by making certificate structure enforceable,
not just advisory. Extends the existing Phase 3b validator.

Pre-work: pin the current validator's location in `env-server.ts` and
confirm the Phase 3b exit-code=2 policy is wired as the plan assumes.
The 2026-04-12 summary says the validator is implemented; verify before
extending.

Files:

- `src/tui/src/env-server.ts` (validator extension)
- `src/core/types.ail` (if `expected_output` is decoded server-side in
  a typed way; otherwise pure env-server change)

Changes:

1. Extend validator to recognize:
   ```json
   {
     "kind": "certificate",
     "min_premises": 2,
     "require_trace": true,
     "require_conclusion": true
   }
   ```
   Defaults when fields are omitted: `min_premises: 1`,
   `require_trace: true`, `require_conclusion: true`. `min_premises: 0`
   is explicitly rejected — a certificate with no premises is
   indistinguishable from free-text stdout and should use a different
   validator kind.
2. Validator logic:
   - Parse stdout for `PREMISES`, `TRACE`, `CONCLUSION` sections.
     Section headers match case-insensitively and tolerate leading
     whitespace; indentation of entries is not enforced.
   - Count premise lines; require ≥ `min_premises`.
   - Each premise line must match a `<path> <arrow> <text>` shape
     where `<arrow>` is either ASCII `->` or Unicode `→` (U+2192).
     Split on the *first* occurrence of the arrow so path/text can
     contain the other token freely.
   - `TRACE` and `CONCLUSION` must be non-empty when required.
   - Result shape unchanged: `{ decided, satisfied, confidence, reason }`.
3. Integration with existing Phase 3b exit-code policy:
   - `decided=true, satisfied=false, confidence=high` → force
     `exit_code=2` as today.
4. `contains_all` and `lines_regex` kinds unchanged.
5. Telemetry: count certificate-structure failures separately from
   content-token failures for retry-pattern analysis.

Validation:

1. Certificate-shaped stdout with 3 premises + trace + conclusion → pass.
2. Stdout missing `TRACE` section → fail with reason naming the
   missing section.
3. Premise line without `<path> →` arrow → fail.
4. Legacy `contains_all` / `lines_regex` / free-text contracts
   unaffected.

Exit criteria: analyze-kind compose calls that specify a certificate
contract reject unstructured stdout via the existing exit_code=2 path.

### SF4 — Citation-binding check (optional, cheap pre-filter)

Static answer to "does every premise cite a path that was actually
read?" — cheap enough to run before SF5's LLM calls, catches the
cheapest class of fabrication without paying for model calls.
Complementary to SF5, not replaced by it: SF4 catches "cited path
never read"; SF5 catches "cited paths read but conclusion off-target".

Files:

- `src/tui/src/env-server.ts` (post-exec binding check)

Changes:

1. After `ailang run` succeeds and the certificate validator has
   parsed the premise lines, extract the set of cited paths `C`.
2. Parse the snippet source for literal string arguments to
   `readFile(...)`, `listDir(...)`, `_zip_readEntry(...)`, and
   `exec(...)` — call this set `R`.
3. For each `p ∈ C`, require `∃ r ∈ R` such that `r == p` or `r`
   is a prefix of `p` (allows `listDir("src/")` + per-entry premise
   citation like `"src/foo.ts"`).
4. On violation, emit `compose_check` failure (even though the snippet
   ran cleanly) with reason `"cited path <p> has no backing read in
   snippet source"` and trigger retry.
5. Do not enforce the reverse direction — snippets may read files
   without citing them (e.g. config reads for loop driving).

Known limitations (accepted):

- **Concatenated paths bypass the literal check.** A snippet that
  builds paths via `readFile(base ++ "/" ++ name)` has no literal
  argument to match against. The guard treats these as absent from
  `R` and will flag citations that depend on them. This is the
  intended conservative stance: if the snippet cannot show the
  model where the path came from, neither can the guard.
- **Prefix-match is loose.** `listDir("src/")` + `readFile(entry)` in
  a loop lets the snippet cite any path under `src/`. Strict mode
  (`AILANG_COMPOSE_CITATION_BINDING=strict`) requires per-file
  `readFile(<literal>)` instead of prefix-match — useful when SF5 is
  disabled and SF4 is the only semantic check, too strict when both
  are enabled.
- **`exec` citations are parsed from the exec argument string.** A
  shell command containing path literals is matched token-by-token;
  dynamically built shell strings bypass this check the same way
  concatenated paths do.

Modes:

| Env value | Behavior |
|---|---|
| `0` | Disabled (default) |
| `1` | Prefix-match acceptance |
| `strict` | Literal-only; no prefix-match |

Validation:

1. Snippet reads `a.ts`, cites only `a.ts` → accept.
2. Snippet reads `a.ts`, cites `a.ts` and `b.ts` → reject (`b.ts`
   unbound).
3. Snippet does `listDir("src/")` + cites `"src/x.ts"` with prefix
   match → accept.
4. `exec`-driven snippet (e.g. `exec("grep ...")`) — citation must
   match a path literal appearing in the exec argument; conservative
   acceptance.

Exit criteria: SF1-templated snippets run through SF3 and SF4 in
sequence; a fabricated premise line fails SF4 and retries with a
targeted hint.

### SF5 — Round-trip informalization (ClaimCheck-style two-pass)

Two LLM calls that verify the certificate actually captures the intent,
using the structural separation that ClaimCheck showed beats end-to-end
prompting by 27pp. Catches the "technically true but off-target" /
tautological / vacuous / over-narrow failure modes that SF1–SF4 cannot.

Files:

- `src/tui/src/compose-claimcheck.ts` (new: two-pass orchestration)
- `src/tui/src/env-server.ts` (wire SF5 into the post-exec path)
- `src/tui/src/ui.ts` (render the four new `compose_claimcheck_*`
  events: a dedicated ClaimCheck row inside the Compose card with
  live informalization text during Pass 1 and a verdict chip
  (`confirmed`/`disputed`/`vacuous`/`surprising_restriction`/
  `inconclusive`) after Pass 2; use the same width-safe red-box
  treatment as existing error blocks for non-confirmed verdicts)
- `src/tui/src/runtime-process.ts` (extend the event type union and
  the `compose_result.meta.sf5` telemetry shape; mirror the existing
  compose telemetry plumbing pattern)
- `src/core/rpc.ail` (if verdict must reach main-agent msgs;
  otherwise env-server-local)

Implementation mechanism:

Reuse the existing author-streaming subprocess pattern. Phase 5c
already spawns an AILANG subprocess with
`std/ai.callStreamResult` and `MOTOKO_STREAM_EVENTS=1` to stream
author deltas; SF5 spawns two more subprocesses per attempt using the
same harness. This keeps auth, provider selection, and streaming
infrastructure consistent across author/informalizer/comparator and
avoids a separate Node-side LLM client. Cost is two subprocess
spawns per attempt (~100ms each on cold start); acceptable given SF5
fires only for analysis-kind compose calls. A Node-side client is a
future optimization, not on this plan's critical path.

Changes:

1. When `AILANG_COMPOSE_CLAIMCHECK=1` and the snippet passed SF3
   (and SF4 if enabled), run the two-pass verification **per attempt**
   (not batched across attempts — retries are sequential, so each
   candidate certificate must be judged before the next attempt is
   authored). **Critical invariant:** the informalizer must not see
   the intent, and the comparator must not see the snippet source or
   certificate stdout. The two calls happen in separate subprocesses
   with separate prompt payloads.

2. **Pass 1 — Informalization** (no intent visible):
   - Model: `AILANG_COMPOSE_CLAIMCHECK_INFORMALIZER_MODEL`
     (default `AILANG_SUBAGENT_MODEL` — in most deployments only one
     model is configured, so use it; a cheaper-tier override is
     available when a second model is reachable).
   - Input: certificate stdout only. Not the intent. Not the snippet
     source. Stdout is truncated at
     `AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES` (default 4000,
     matches Phase 3b's stdout elision bound) with a
     `[truncated: <N> bytes omitted]` marker appended; if the raw
     stdout fit within the bound, no marker is added.
   - **Streamed**: spawn with `MOTOKO_STREAM_EVENTS=1`; bridge
     `thinking_delta` events to `compose_claimcheck_informalize_delta`
     so the TUI renders the informalization live.
   - Prompt skeleton (cached prefix):
     ```
     Read the certificate below. In ≤40 words, describe what it
     demonstrates, based only on its PREMISES, TRACE, and CONCLUSION
     lines. Do not speculate about the author's goal; describe only
     what the certificate's own text says was shown.

     Certificate:
     <stdout>
     ```
   - Output: short natural-language description `D`, captured from
     the final stream event and emitted as
     `compose_claimcheck_informalize_result`.
   - **Empty `D` handling:** if the informalizer returns empty or
     whitespace-only text (stream closed with no content), skip Pass 2
     and record `sf5_informalizer_empty`. Verdict → `inconclusive` →
     accept. The comparator cannot usefully judge intent-vs-nothing,
     and paying for the call is wasteful.

3. **Pass 2 — Comparison** (no snippet source or certificate visible):
   - Model: `AILANG_COMPOSE_CLAIMCHECK_COMPARATOR_MODEL`
     (default `AILANG_SUBAGENT_MODEL`).
   - Input: original intent `I`, informalization `D` from Pass 1.
   - **Streamed**: same mechanism as Pass 1, bridging to
     `compose_claimcheck_compare_delta`. Streaming is particularly
     valuable here because the comparator's JSON output is short
     enough that a non-streamed call makes the TUI look frozen for
     the entire LLM round-trip.
   - Prompt skeleton (cached prefix):
     ```
     Original request: <I>
     Observed summary:  <D>

     Does the observed summary describe the same conclusion the
     request was asking for? Respond with JSON:
     {
       "verdict": "confirmed" | "disputed" | "vacuous"
                | "surprising_restriction" | "inconclusive",
       "confidence": "high" | "low",
       "reason": "<one sentence>"
     }
     ```
   - Verdict semantics:
     - `confirmed` — `D` is a reasonable rephrasing of `I`.
     - `disputed` — `D` describes a different conclusion than `I` asked.
     - `vacuous` — `D` describes something trivially true that does
       not engage with `I` (e.g. "file exists", "field has expected
       type").
     - `surprising_restriction` — `D` answers a strictly narrower
       question than `I` asked (the Phase 5b planner-narrowing
       failure mode, surfaced explicitly).
     - `inconclusive` — comparator cannot decide.
   - Final verdict emitted as `compose_claimcheck_compare_result`.

4. **Retry / exit policy**:
   - `disputed` / `vacuous` / `surprising_restriction` with
     `confidence=high` → force `exit_code=2` and retry.
   - The retry's corrective hint includes **only the most recent `D`**
     (not an accumulated history across attempts). Prevents prompt
     bloat; the author needs to react to the last rejection, not
     every prior one. Telemetry retains the full history.
   - `inconclusive` → accept but record in telemetry.
   - `confirmed` → accept.

5. **Timeout and error handling:**
   - Per-subprocess timeout defaults to 30s (override via
     `AILANG_COMPOSE_CLAIMCHECK_TIMEOUT_MS`).
   - Informalizer timeout/error → treat as inconclusive → accept +
     telemetry flag `sf5_informalizer_timeout` or
     `sf5_informalizer_error`.
   - Comparator timeout/error → same policy: inconclusive → accept +
     telemetry flag.
   - Malformed comparator JSON → single repair attempt (re-spawn
     comparator with the raw output echoed back and a "repair your
     JSON" prompt); second failure → inconclusive + accept.
   - **SF5 must never block a compose call permanently.** A provider
     outage on the informalizer/comparator degrades SF5 to a no-op,
     not to a hang.

6. **Same-model caveat** (default deployment): when both passes use
   the same model, the structural separation alone provides most of
   the value — the informalizer still cannot echo intent text it never
   saw, and the comparator still judges a text-to-text match rather
   than synthesizing a novel judgment. ClaimCheck's 27pp gap was
   across different-model pairs, but its authors attribute the gain
   primarily to the separation of contexts, not to model diversity.
   Document this assumption; if a cheaper informalizer tier is
   configured later, the env var is already there.

7. **Non-analysis intents**: SF5 does not fire for `compute`,
   `transform`, `list`, or `fetch` kinds. The certificate-shape
   informalization does not apply outside `analyze` (and optionally
   `summarize`). Verify this is enforced in the dispatch, not relied
   on by convention.

8. Enable provider prompt caching on both prompt prefixes (static
   across calls).

9. **Invocation budget:** skip SF5 once per-session invocations
   reach `AILANG_COMPOSE_CLAIMCHECK_MAX_INVOCATIONS` (default 10).
   Further attempts in the same compose session proceed without
   SF5 and emit `sf5_budget_exhausted` once. Rationale: with
   `AILANG_SUBAGENT_MAX_ATTEMPTS=50`, an unbounded per-attempt SF5
   can add ~100 calls and minutes of latency on pathological
   sessions. 10 paired calls is enough for SF5 to catch the common
   author-drift failure modes; beyond that, the author isn't
   converging and further SF5 judgments are unlikely to change the
   outcome.

10. **SF5 telemetry schema** (merged into `compose_result.meta.sf5`):

    | Field | Type | Meaning |
    |---|---|---|
    | `invocations` | int | Number of `(informalize, compare)` pairs actually run |
    | `verdicts` | `{confirmed, disputed, vacuous, surprising_restriction, inconclusive}` counts | Per-verdict tally across attempts |
    | `informalizer_ms` | int[] | Per-call latency |
    | `comparator_ms` | int[] | Per-call latency |
    | `informalizer_timeouts` | int | Count |
    | `informalizer_errors` | int | Non-timeout error count |
    | `informalizer_empty` | int | Count of empty-`D` cases |
    | `comparator_timeouts` | int | Count |
    | `comparator_errors` | int | Count |
    | `comparator_json_repair_attempts` | int | Total repair calls fired |
    | `comparator_json_repair_failures` | int | Repair attempts that still produced malformed JSON |
    | `budget_exhausted` | bool | True if cap hit mid-session |
    | `truncated_stdout_cases` | int | Count of informalizer calls where stdout was truncated |

    All fields are cumulative over the compose session.

Success threshold for default-flip:

- ≥80% precision on `disputed` / `vacuous` / `surprising_restriction`
  verdicts against the planted-certificate benchmark (see Testing).
- ≤5% false-positive rate on confirmed on-target certificates.
- Median total SF5 latency per attempt ≤3s at the default model tier.

If any threshold is missed, SF5 stays opt-in. The numbers are starting
targets, not commitments — revisit after the first benchmark run.

Validation:

1. Fabricated-but-tautological certificate (the ClaimCheck planted
   example: certificate proves `Count(...) >= 0` when intent asked
   about ballot effects) → comparator returns `vacuous`, retry
   triggered.
2. On-target certificate → `confirmed`, no retry.
3. Narrower-scope certificate (asks "explain TUI", answers "explain
   ComposeCard subset") → `surprising_restriction`, retry triggered.
4. Informalizer must not reproduce intent wording when run on a
   generic certificate template — snapshot test on a fixed
   certificate.
5. Separation invariant: no informalizer call receives intent text;
   no comparator call receives snippet source or certificate stdout.
   Assert via test harness that inspects prompt payloads.
6. Per-attempt invocation: 3-attempt session with a stub comparator
   returning well-formed JSON → exactly 6 SF5 LLM calls (2 per
   attempt — one informalize, one compare — not batched across
   attempts). Each attempt's certificate is judged before the next
   attempt is authored. JSON repair variance is covered by a
   separate test.
7. Cost tracking: `compose_result.meta.sf5` carries the telemetry
   schema above (invocation count, per-call latency, verdict tally,
   failure-mode counters).

Exit criteria: SF5 runs on a representative set of analyze-intent
compose calls; precision/recall of `disputed`/`vacuous`/
`surprising_restriction` vs actual off-intent certificates is
measured before flipping default to `1`. Default-enable only if the
success thresholds above hold; the 2-calls-per-attempt cost is
acceptable because SF5 fires only for analyze-kind intents and only
after a snippet has already passed SF2/SF3/SF4.

## Ordering constraint

SF2 is independent and ships first. SF1 → SF3 form the backbone;
SF4 depends on SF3's premise parsing but is optional. SF5 depends on
SF1 (certificate must exist to be informalized) and is independent of
SF3/SF4 — you could ship SF5 without SF3's structural validator, though
SF3 gives the informalizer a cleaner text to work from. Recommended
order: SF2 → SF1 → SF3 → SF5 → SF4.

## Caveats from the paper

The paper's agents had 100-step interactive exploration budgets. The
Compose subagent writes **one snippet per attempt**, no interactive
exploration. Implications:

1. Certificate templates must be breadth-first friendly: favor
   `listDir` + per-file `readFile` loops over deep interprocedural
   traces.
2. Premise counts should be modest (2–5), not the 10+ often seen in
   the paper's patch-equivalence certificates.
3. The TRACE section is the weakest link — a single snippet cannot
   trace across function calls the way the paper's agents do. Accept
   this and scope `TRACE` to "how these premises combine
   arithmetically or logically," not interprocedural reasoning.

## Open questions

1. Should `intent_kind` be a dedicated field on the Compose tool call,
   or derived server-side from `intent` text? (Leaning dedicated — it
   makes the main-agent prompt contract explicit and eliminates
   keyword-sniffing ambiguity.)
2. Should SF4's citation-binding check block on prefix-match
   `listDir`, or require per-file `readFile` citations? (Leaning
   prefix-match; stricter variant can be opt-in.)
3. SF5 model choice — informalizer and comparator default to
   `AILANG_SUBAGENT_MODEL` because most deployments only configure one
   model. ClaimCheck's 27pp gap came from a weaker-model informalizer
   paired with a stronger-model comparator (cited from memory as
   Haiku + Sonnet; verify against
   https://midspiral.com/blog/claimcheck-narrowing-the-gap-between-proof-and-intent
   before circulating the plan externally — the pairing name in this
   doc is a placeholder until confirmed). Residual accuracy may be
   left on the table when both passes share a model; measure against
   a fixed benchmark before assuming parity.
4. Same-model structural separation — ClaimCheck's authors attribute
   the win primarily to context separation, not model diversity. This
   is our working assumption, but validate on a small fabrication
   benchmark (tautological / off-target / over-narrow certificates)
   before default-enabling SF5.
5. Should telemetry distinguish "SF3 certificate-structure failed"
   from "SF5 verdict=disputed" from "content-token failed" at the
   `compose_result` level for the main agent, or only in TUI
   diagnostics? (Leaning TUI-only; the main agent should continue
   seeing a single summary.)
6. ~~Should the batched SF5 pass happen per-attempt or end-of-session?~~
   **Resolved: per-attempt.** Retries are sequential, so each
   candidate certificate must be judged before the next attempt is
   authored; an end-of-session batch would accept snippets that
   should have been rejected mid-session and would waste retry
   budget on author attempts that react to no feedback. The higher
   call count (2 per analyze-intent attempt) is the price of
   correctness.
7. `SYSTEM_MD` interaction with `intent_kind`. The main agent's tool
   contract is declared in `core/prompts.ail`; when a user supplies
   `SYSTEM_MD`, that override replaces the built-in system prompt and
   may not surface the `intent_kind` field. The Compose tool handler
   must fall back to keyword-derived `intent_kind` when the field is
   absent on the incoming call. SF1/SF3/SF5 must therefore treat
   `intent_kind` as optional-with-fallback, not required.

## Testing strategy

- Unit tests on `parseDeclaredEffects`, certificate validator,
  citation-binding check.
- Integration test: stub LLM provider → certificate-shaped snippet →
  end-to-end SF2+SF3+SF4 acceptance.
- Integration test: stub LLM provider → fabricated premise → SF4
  rejection + retry.
- **SF5 separation invariant**: test harness captures every LLM
  prompt payload in a session and asserts:
  - No informalizer prompt contains the intent string.
  - No comparator prompt contains the snippet source or certificate
    stdout.
- **SF5 verdict tests** (stub comparator): each of `confirmed`,
  `disputed`, `vacuous`, `surprising_restriction`, `inconclusive`
  triggers the correct exit code and retry path.
- **SF5 per-attempt invocation test**: 3-attempt analyze session
  with a stub comparator that returns well-formed JSON on the first
  call → exactly 6 SF5 LLM calls (2 per attempt, one informalize +
  one compare), *not* batched across attempts. Assert exact call
  count. A separate test covers JSON repair variance (below) so this
  test can assert a fixed count rather than a range.
- **SF5 streaming test**: assert that `compose_claimcheck_informalize_delta`
  and `compose_claimcheck_compare_delta` events are emitted during
  each pass, not just the terminal `_result` events.
- **SF5 timeout test**: stub informalizer that sleeps > timeout →
  treated as inconclusive → accept + `sf5_informalizer_timeout`
  telemetry flag set. Same for comparator.
- **SF5 JSON repair test**: stub comparator returns malformed JSON on
  first call, valid JSON on second → single repair attempt fires,
  verdict captured; two consecutive malformed responses → accept +
  telemetry flag, no third call.
- **SF5 non-analysis dispatch test**: `compute` / `transform` / `list`
  / `fetch` intents do not trigger SF5 regardless of
  `AILANG_COMPOSE_CLAIMCHECK=1`.
- **SYSTEM_MD fallback test**: override `SYSTEM_MD` so the main
  agent's prompt lacks `intent_kind`; compose tool call arrives
  without the field → keyword derivation supplies a kind, SF1/SF3/SF5
  behave as if the field were present.
- **SF5 fabrication benchmark**: small fixture set of planted
  certificates (tautological, off-target, over-narrow, on-target)
  with expected verdicts; measure precision/recall to decide default.
- Regression: existing Phase 5c anti-fabrication tests pass with
  SF2's narrowed marker list and effect-set check.

## Non-goals

- Main agent semi-formal verifier pass (covered by
  `Semi_Formal_Reasoning_Integration.md`).
- Fault localization or patch equivalence tasks.
- Formal Z3 verification of certificate claims (possible future work
  where premise values are `int`/`bool`/`string`).
- Multi-turn subagent exploration budgets (would require restructuring
  `/compose` and is out of scope).
