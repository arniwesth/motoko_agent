#!/usr/bin/env python3
"""Build the ABI 8.0 candidate types.ail from the 7.4 file.

argv[1] = 7.4 source, argv[2] = output, argv[3] = preparation reading:
  adr      -- the ADR's literal names: Immediate/Query in BOTH sums
  distinct -- JudgeImmediate/JudgeQuery and ToolImmediate/ToolQuery
"""
import sys

src, out, reading = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(src).read()


def swap(old, new, count=1):
    global text
    n = text.count(old)
    if n != count:
        sys.exit(f"expected {count} occurrence(s), found {n}: {old[:70]!r}")
    text = text.replace(old, new)


# ---------------------------------------------------------------- header
swap(
    """-- Every motoko-ext-* package depends on this module and must export:
--   register_with_config(cfg: RuntimeConfig) -> [Capability] ! {...}   (6.0; was -> ExtensionHooks)
-- from a module named <package-name>/register.
--
-- Bumping `Capability` (a variant added, removed or re-rowed) is a major version
-- of motoko-ext-abi, exactly as bumping `ExtensionHooks` was through 5.0.
""",
    """-- Every motoko-ext-* package depends on this module and must export:
--   register_with_config(cfg: RuntimeConfig) -> ExtRegistration ! {...}
--     (8.0; was -> [Capability] from 6.0 to 7.4, -> ExtensionHooks before 6.0)
-- from a module named <package-name>/register.
--
-- Bumping `Capability` (a variant added, removed or re-rowed) is a major version
-- of motoko-ext-abi, exactly as bumping `ExtensionHooks` was through 5.0.
--
-- =========================================================================
-- THE 8.x STABILITY RULE (release scope 033 ADR-001 D1 item 2, gate G5d).
-- =========================================================================
--
-- 7.2 and 7.4 were MINORS that broke every `ExtCtx` literal in the tree,
-- because a record that gains a field breaks every literal of it. From 8.0 a
-- minor may not do that to a consumer that follows this rule:
--
--   1. An 8.x minor adds a field to a context view -- `PureCtx`, `ProcessCtx`,
--      `FsCtx`, `AiCtx`, `InterceptCtx`, `ProviderCtx` -- ONLY behind the
--      constructors this package exports (`pure_ctx`, `pure_ctx_of`,
--      `process_ctx`, `fs_ctx`, `ai_ctx`, `intercept_ctx`, `provider_ctx`),
--      each of which supplies the new field's default. A consumer that builds
--      every view through those constructors, adjusting fields by record
--      update (`{ pure_ctx(cfg) | task: "t" }`), keeps compiling across 8.x.
--      A consumer that writes a view LITERAL is outside the rule and may break
--      at any minor. A record this package exports no constructor for does
--      not gain a field within 8.x at all.
--   2. A `Capability` variant added, removed or re-signed, or a payload row
--      changed, waits for 9.0. That includes which ports a view carries: the
--      views are derived from the rows (below), so a port moving into or out
--      of a view IS a row change.
--   3. Everything else a minor may do is additive and non-breaking for a
--      consumer that follows 1: a new exported type, function or constructor.
--
-- The rule covers every exported view, not only `ExtCtx` (ADR-001 (031) D2).
-- `ExtCtx` itself is no longer what any callback receives: it is the host's
-- full context, the source the constructors project from.
""",
)

# ---------------------------------------------------------------- imports
swap("import std/option (Option)\nimport std/json (Json, jo)\n",
     "import std/option (Option, None)\nimport std/json (Json, jo, ja)\n")

# ---------------------------------------------------------------- D3 vocabulary, before ExtCtx
D3 = """-- =========================================================================
-- 8.0 (ADR-001 (031) D3): THE TYPED OBSERVATION VOCABULARY.
--
-- Provider-independent. Every probability, confidence and score is an integer
-- in basis points, 0..10000: the host adapter is the SOLE normalizer of raw
-- provider numbers and records the integer observation; the child's codec
-- validates it strictly and never renormalizes. Absence is explicit: a missing
-- optional distribution, confidence or usage figure is `None`, never a
-- manufactured certainty or a zero cost. No probability here is a claim of
-- calibration.
-- =========================================================================
export type NamedOption = { id: string, description: string }

-- A choice has at least two distinct options; a rubric at least two ordered
-- levels, and its score runs 0..10000 from the first level to the last.
export type QuestionKind
  = Binary
  | Choice([NamedOption])
  | Rubric([NamedOption])

export type NamedQuestion = { id: string, prompt: string, guidance: Json, kind: QuestionKind }

export type Probability = { option_id: string, probability: int }

export type Answer
  = BinaryAnswer(probability: int)
  | ChoiceAnswer(option_id: string, distribution: Option[[Probability]], confidence: Option[int])
  | RubricAnswer(score: int, distribution: Option[[Probability]])

export type DecisionAnswer = { question_id: string, answer: Answer }

export type DecisionResponse = { answers: [DecisionAnswer] }

-- Cancellation, codec corruption and strict-replay divergence are HOST CONTROL
-- FAILURES and never appear here: an `Unavailable` is something an interpreter
-- may turn into a vote, and those three must not be.
export type UnavailableReason
  = UnconfiguredBackend
  | UnsupportedRequest
  | InvalidRequest
  | InvalidResponse
  | BudgetExhausted
  | Timeout
  | ProviderFailure

export type DecisionResult
  = Answered(DecisionResponse)
  | Unavailable(UnavailableReason)

export type DecisionUsage = {
  input_tokens: Option[int],
  output_tokens: Option[int],
  cost_millicents: Option[int]
}

export type DecisionObservation = { result: DecisionResult, usage: DecisionUsage }

-- Verification EVIDENCE, separate from verification GATING (which is
-- unchanged). `VerificationUnavailable` is a HEURISTIC classification -- the
-- host's missing-infrastructure test is a substring match over verifier
-- output -- so a guard treats it as uncertain, never as a pass or a fail.
-- Evidence from an earlier invocation keeps its `occurrence` and is never
-- relabeled as current. `workspace_revision` is `None` unless an actual
-- recorded revision mechanism supplied it; `None` means freshness across edits
-- is unknown.
export type VerificationRun = {
  occurrence: string,
  step: int,
  command: string,
  exit_code: Option[int],
  output: string,
  truncated: bool,
  workspace_revision: Option[string]
}

export type VerificationEvidence
  = NotReached
  | Disabled
  | Passed(VerificationRun)
  | Failed(VerificationRun)
  | VerificationUnavailable(reason: string, run: Option[VerificationRun])

-- `CommandExit(n)` only from a recorded `ToolCompleted` whose exit code is `n`
-- and is not the `-1` sentinel (which maps to `ToolOutcomeUnknown`); textual
-- tool output and model claims cannot create it. `ToolSucceeded` means the
-- tool reported success, not that the user's task passed.
export type ObservedToolOutcome
  = CommandExit(int)
  | ToolSucceeded
  | ToolFailed(string)
  | ToolDenied(string)
  | ToolPending
  | ToolOutcomeUnknown

export type ToolEvidence = {
  call_id: string,
  step: int,
  tool_name: string,
  outcome: ObservedToolOutcome,
  output: string,
  truncated: bool,
  workspace_revision: Option[string]
}

-- Truncation sets `complete_from_session_start` false; an unknown omitted count
-- is `None`. A resumed session's window starts incomplete. Full transcript
-- access is not proof that this separate typed window is complete.
export type ToolEvidenceWindow = {
  records: [ToolEvidence],
  complete_from_session_start: bool,
  omitted_count: Option[int]
}

export type DecisionMode
  = DisabledDecision
  | ShadowDecision
  | EnforcingDecision

-- `Some` for decision callbacks, `None` at every other hook site. It hands back
-- the descriptor's TWO CONFIGURATION PROJECTIONS -- `question_config` and
-- `interpretation_config`, the data the host hashed for the identity layers --
-- and the FIVE LEDGER TERMS as of the last decision reply: the identity's
-- `allowance_millicents`, `known_spend_millicents` and `outstanding_millicents`
-- (host-owned, reaching the child through a mirror), and this run's
-- `run_cost_millicents` and `run_cap_millicents` (child-known; the cap is `None`
-- when the run is unmetered or the cap is disabled). The terms are
-- INFORMATIONAL -- they let `prepare` choose an immediate answer when the budget
-- is thin -- and are not the admission decision, which is the host's.
export type DecisionInvocationState = {
  invocation_id: string,
  mode: DecisionMode,
  interventions_used: int,
  intervention_limit: int,
  question_config: Json,
  interpretation_config: Json,
  allowance_millicents: int,
  known_spend_millicents: int,
  outstanding_millicents: int,
  run_cost_millicents: int,
  run_cap_millicents: Option[int]
}

export type ExtCtx = {"""
swap("export type ExtCtx = {", D3)

# ---------------------------------------------------------------- ExtCtx D3 fields
swap("""  artifacts: Json,
  telemetry: TokenTelemetry,
  -- WI-B2b: the INBOUND half""",
     """  artifacts: Json,
  telemetry: TokenTelemetry,
  -- 8.0 (ADR-001 (031) D3): the three typed-evidence fields, present in EVERY
  -- view below, `PureCtx` included. Defaults must not assert success: a
  -- context with nothing to report carries `NotReached`, an incomplete empty
  -- window, and `None` -- which is what `pure_ctx` supplies.
  verification: VerificationEvidence,
  tool_evidence: ToolEvidenceWindow,
  decision_state: Option[DecisionInvocationState],
  -- WI-B2b: the INBOUND half""")

# ---------------------------------------------------------------- views, after ExtCtx
CTX_FIELDS = """  task: string,
  step: int,
  model: string,
  cwd: string,
  hybrid_tools: bool,
  budget: BudgetPlan,
  mode: string,
  workdir: string,
  env_server_url: string,
  budget_remaining: int,
  history_slice: [Msg],
  state_key: string,
  context_limit: int,
  finish_reason: string,
  work_in_flight: [WorkItem],
  open_waits: Json,
  artifacts: Json,
  telemetry: TokenTelemetry,
  verification: VerificationEvidence,
  tool_evidence: ToolEvidenceWindow,
  decision_state: Option[DecisionInvocationState],
  ext_config: Json"""

COPY = lambda src: "\n".join(
    f"    {f.split(':')[0].strip()}: {src}.{f.split(':')[0].strip()},"
    for f in CTX_FIELDS.splitlines()
)

VIEWS = f"""  world: ExtWorld
}}

-- =========================================================================
-- 8.0 (ADR-001 (031) D2): THE SIX CONTEXT VIEWS.
--
-- Every `Capability` callback receives a context whose `ports` record holds
-- EXACTLY the `ExtPorts` fields whose declared rows are subsets of the slot's
-- declared row. A rowless slot receives `PureCtx`, which also drops `world`
-- because a rowless slot returns no successor state. The table, derived from
-- the 7.4 rows:
--
--   slot row                          slots                        view          ports
--   {{}}                                PromptShaper, BudgetShaper,  PureCtx       none; no world
--                                     ToolPolicy, both decision
--                                     callbacks
--   {{Process}}                         SolverJudge                  ProcessCtx    none (no port fits);
--                                                                                  keeps world
--   {{FS}}                              ExitIntent, WorkInFlight     FsCtx         the six FS ports
--   {{AI, IO, Trace}}                   Compactor                    AiCtx         ai_step
--   {{IO, Process, FS, Clock}}          ResponseInterceptor          InterceptCtx  six FS, tool_handle,
--                                                                                  clock_now
--   {{IO, Process, FS, AI, Env, Net,    ToolProvider                 ProviderCtx   all ten (ExtPorts)
--    SharedMem, Clock, Stream, Rand,
--    Trace}}  (Trace added in 8.0)
--
-- WHAT THIS GUARANTEES, stated exactly: restricted SUPPLIED AUTHORITY, not
-- compile-time purity. A view with no `ports` gives a callback no port to
-- invoke. On the pinned AILANG v0.33.0 an inline lambda can still name a field
-- its parameter type lacks and check green; the call then fails at invocation
-- with a missing-field error, which the host reports as a registration defect
-- (a host control failure), never as an `Unavailable` an interpreter may vote
-- on. The registration boundary -- named, unshadowed, directly bound top-level
-- functions -- is what closes the ambient-effect route; see ADR-001 (031) D2.
--
-- `ext_config` is the extension's own configuration, returned from
-- `register_with_config` in `ExtRegistration.config` and stamped by the host
-- on every view it builds for that extension. It is data (`Json` cannot hold a
-- function, so it cannot carry an effect), it is hashed as the extension's
-- config digest, and it carries NO credentials: environment-variable names,
-- never values.
--
-- AILANG records are closed, so a helper typed `ExtCtx` or `ExtPorts` does not
-- accept a narrower view. Shared helpers take `PureCtx` (the data projection
-- every view contains) or the smallest ports record they use. No dummy ports
-- to make an old helper compile.
-- =========================================================================

export type FsPorts = {{
  file_read: (ExtWorld, string) -> ExtFileRead ! {{FS}},
  file_write: (ExtWorld, string, string) -> ExtFileMutation ! {{FS}},
  file_remove: (ExtWorld, string) -> ExtFileMutation ! {{FS}},
  path_stat: (ExtWorld, string) -> ExtPathStat ! {{FS}},
  dir_list: (ExtWorld, string) -> ExtDirListing ! {{FS}},
  dir_make: (ExtWorld, string) -> ExtFileMutation ! {{FS}}
}}

export type AiPorts = {{
  ai_step: (ExtWorld, string, [Msg]) -> AiStepOutcome ! {{AI, IO, Trace}}
}}

export type InterceptPorts = {{
  tool_handle: (ExtWorld, string, string) -> ExtProcOutcome ! {{IO, Process, FS}},
  file_read: (ExtWorld, string) -> ExtFileRead ! {{FS}},
  file_write: (ExtWorld, string, string) -> ExtFileMutation ! {{FS}},
  file_remove: (ExtWorld, string) -> ExtFileMutation ! {{FS}},
  path_stat: (ExtWorld, string) -> ExtPathStat ! {{FS}},
  dir_list: (ExtWorld, string) -> ExtDirListing ! {{FS}},
  dir_make: (ExtWorld, string) -> ExtFileMutation ! {{FS}},
  clock_now: (ExtWorld) -> ExtClockReading ! {{Clock}}
}}

-- `ExtCtx` without `ports` and without `world`; every other field, the D3
-- additions included, plus `ext_config`.
export type PureCtx = {{
{CTX_FIELDS}
}}

export type ProcessCtx = {{
{CTX_FIELDS},
  world: ExtWorld
}}

export type FsCtx = {{
{CTX_FIELDS},
  ports: FsPorts,
  world: ExtWorld
}}

export type AiCtx = {{
{CTX_FIELDS},
  ports: AiPorts,
  world: ExtWorld
}}

export type InterceptCtx = {{
{CTX_FIELDS},
  ports: InterceptPorts,
  world: ExtWorld
}}

export type ProviderCtx = {{
{CTX_FIELDS},
  ports: ExtPorts,
  world: ExtWorld
}}

-- THE CONSTRUCTORS the 8.x rule is stated against. Build views through these;
-- a minor that adds a view field adds its default here and nowhere else.

-- A `PureCtx` carrying `ext_config` and truthful empty defaults: no task, no
-- history, verification `NotReached`, an EMPTY and INCOMPLETE tool-evidence
-- window with an unknown omitted count, and no decision state. Nothing here
-- asserts success. Adjust by record update: `{{ pure_ctx(cfg) | step: 3 }}`.
export pure func pure_ctx(ext_config: Json) -> PureCtx {{
  {{
    task: "",
    step: 0,
    model: "",
    cwd: "",
    hybrid_tools: false,
    budget: {{ total: 0, solver: 0, verifier: 0 }},
    mode: "",
    workdir: "",
    env_server_url: "",
    budget_remaining: 0,
    history_slice: [],
    state_key: "",
    context_limit: 0,
    finish_reason: "",
    work_in_flight: [],
    open_waits: ja([]),
    artifacts: jo([]),
    telemetry: {{ last_input_tokens: 0, last_output_tokens: 0, last_estimated_input_tokens: 0 }},
    verification: NotReached,
    tool_evidence: {{ records: [], complete_from_session_start: false, omitted_count: None }},
    decision_state: None,
    ext_config: ext_config
  }}
}}

-- The host's projection: the data of its full `ExtCtx`, stamped with one
-- extension's configuration. Drops `ports` and `world`.
export pure func pure_ctx_of(ctx: ExtCtx, ext_config: Json) -> PureCtx {{
  {{
{COPY("ctx").replace("    ext_config: ctx.ext_config,", "    ext_config: ext_config")}
  }}
}}

export pure func process_ctx(base: PureCtx, world: ExtWorld) -> ProcessCtx {{
  {{
{COPY("base")}
    world: world
  }}
}}

export pure func fs_ctx(base: PureCtx, ports: FsPorts, world: ExtWorld) -> FsCtx {{
  {{
{COPY("base")}
    ports: ports,
    world: world
  }}
}}

export pure func ai_ctx(base: PureCtx, ports: AiPorts, world: ExtWorld) -> AiCtx {{
  {{
{COPY("base")}
    ports: ports,
    world: world
  }}
}}

export pure func intercept_ctx(base: PureCtx, ports: InterceptPorts, world: ExtWorld) -> InterceptCtx {{
  {{
{COPY("base")}
    ports: ports,
    world: world
  }}
}}

export pure func provider_ctx(base: PureCtx, ports: ExtPorts, world: ExtWorld) -> ProviderCtx {{
  {{
{COPY("base")}
    ports: ports,
    world: world
  }}
}}

-- The ports projections: exactly the fields the table above assigns.
export pure func fs_ports(p: ExtPorts) -> FsPorts {{
  {{
    file_read: p.file_read,
    file_write: p.file_write,
    file_remove: p.file_remove,
    path_stat: p.path_stat,
    dir_list: p.dir_list,
    dir_make: p.dir_make
  }}
}}

export pure func ai_ports(p: ExtPorts) -> AiPorts {{ {{ ai_step: p.ai_step }} }}

export pure func intercept_ports(p: ExtPorts) -> InterceptPorts {{
  {{
    tool_handle: p.tool_handle,
    file_read: p.file_read,
    file_write: p.file_write,
    file_remove: p.file_remove,
    path_stat: p.path_stat,
    dir_list: p.dir_list,
    dir_make: p.dir_make,
    clock_now: p.clock_now
  }}
}}
"""
swap("  world: ExtWorld\n}\n\nexport type PromptPatch", VIEWS + "\nexport type PromptPatch")

# ---------------------------------------------------------------- nullary Accept
swap("""export type FinalizeDecision
  = Accept(string)""",
     """-- 8.0 (ADR-001 (031) D4): `Accept` IS NULLARY. It approves the candidate
-- supplied to the judges, and finalization always uses that original
-- candidate; 7.x's `Accept(string)` let a judge replace the output, which left
-- open which text had been judged. Migration: `Accept(c)` -> `Accept`.
export type FinalizeDecision
  = Accept""")

# ---------------------------------------------------------------- D2 decision types + Capability
if reading == "adr":
    jp = "Immediate(FinalizeDecision)\n  | Query(DecisionRequest)"
    tp = "Immediate(ToolPolicyDecision)\n  | Query(DecisionRequest)"
elif reading == "distinct":
    jp = "JudgeImmediate(FinalizeDecision)\n  | JudgeQuery(DecisionRequest)"
    tp = "ToolImmediate(ToolPolicyDecision)\n  | ToolQuery(DecisionRequest)"
else:
    sys.exit("reading: adr | distinct")

D2 = f"""-- =========================================================================
-- 8.0 (ADR-001 (031) D2): THE TWO DECLARED DECISION CAPABILITIES.
--
-- Declared preparation and interpretation, both PURE (`PureCtx`), both
-- positional constructor arguments. `prepare` either answers immediately or
-- asks ONE request holding every question for one state; the host executes
-- the query and hands `interpret` the exact prepared request and the
-- observation, over the same evidence snapshot. Neither callback sees a world
-- token, and `interpret` cannot ask again or mutate artifacts.
--
-- Multiplicity is by VOTE FAMILY: at most one of `SolverJudge` /
-- `DecisionSolverJudge` and at most one of `ToolPolicy` / `DecisionToolPolicy`
-- per extension. `local_id` is nonempty, unique within the extension, and
-- stable across resumes.
--
-- CONFORMANCE OBLIGATION, which `Json` typing cannot enforce: every
-- configuration value that influences evidence selection or question
-- construction is represented in `question_config`; every value that
-- influences thresholds, abstention or feedback in `interpretation_config`.
-- =========================================================================
export type DecisionPolicyDescriptor = {{
  local_id: string,
  question_version: string,
  question_config: Json,
  interpretation_version: string,
  interpretation_config: Json,
  max_interventions: int
}}

export type DecisionRequest = {{
  backend_binding: string,
  state: Json,
  questions: [NamedQuestion]
}}

export type JudgePreparation
  = {jp}

export type ToolPreparation
  = {tp}

-- Neutral hooks for record-update construction."""
swap("-- Neutral hooks for record-update construction.", D2)

swap("""export type Capability
  = DescribeTools(() -> [ToolSchema])
  | PromptShaper((ExtCtx) -> PromptPatch)
  | BudgetShaper((ExtCtx, BudgetPlan) -> BudgetPatch)
  | Compactor((ExtCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace})
  | ToolPolicy((ExtCtx, ToolCallEnvelope) -> ToolPolicyDecision)
  | ToolProvider(
      [string],
      (ExtCtx, ToolCallEnvelope)
        -> ToolHandleOutcome ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream, Rand}
    )
  | ResponseInterceptor(
      (ExtCtx, string) -> ResponseInterceptOutcome ! {IO, Process, FS, Clock}
    )
  | SolverJudge((ExtCtx, string) -> FinalizeOutcome ! {Process})""",
     """--
-- 8.0 RE-SIGNS EVERY VARIANT (ADR-001 (031) D2/D7): each callback takes its
-- row's view (table above `PureCtx`) instead of `ExtCtx`; `DescribeTools` takes
-- the extension's configuration and no context; `ToolProvider`'s row gains
-- `Trace`, so `ProviderCtx` carries all ten ports; and the two decision
-- variants are added. Every payload is a NAMED, UNSHADOWED, top-level function
-- bound directly in the `caps` list -- the registration boundary of D2.
export type Capability
  = DescribeTools((Json) -> [ToolSchema])
  | PromptShaper((PureCtx) -> PromptPatch)
  | BudgetShaper((PureCtx, BudgetPlan) -> BudgetPatch)
  | Compactor((AiCtx, [Msg]) -> PreStepOutcome ! {AI, IO, Trace})
  | ToolPolicy((PureCtx, ToolCallEnvelope) -> ToolPolicyDecision)
  | ToolProvider(
      [string],
      (ProviderCtx, ToolCallEnvelope)
        -> ToolHandleOutcome ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream, Rand, Trace}
    )
  | ResponseInterceptor(
      (InterceptCtx, string) -> ResponseInterceptOutcome ! {IO, Process, FS, Clock}
    )
  | SolverJudge((ProcessCtx, string) -> FinalizeOutcome ! {Process})""")

swap("  | ExitIntent(string, bool, (ExtCtx) -> ExitIntentOutcome ! {FS})",
     "  | ExitIntent(string, bool, (FsCtx) -> ExitIntentOutcome ! {FS})")
swap("""  | WorkInFlight(string, (ExtCtx) -> WorkOutcome ! {FS})

-- The registry entry: D5's owner-bearing shape. `id` is the host's install
-- stamp (`"${name}#${idx}"`), `caps` the registration list UNCHANGED in list
-- order (the invariant every dispatcher and B5's all-atoms witness read).
export type ExtEntry = { id: string, caps: [Capability] }""",
     """  | WorkInFlight(string, (FsCtx) -> WorkOutcome ! {FS})
  -- 8.0. The finalize-family decision capability: `prepare` sees the
  -- candidate, `interpret` the candidate, the exact prepared request and the
  -- observation, and returns the vote.
  | DecisionSolverJudge(
      DecisionPolicyDescriptor,
      (PureCtx, string) -> JudgePreparation,
      (PureCtx, string, DecisionRequest, DecisionObservation) -> FinalizeDecision
    )
  -- 8.0. The tool-policy-family decision capability, invoked per proposed
  -- tool call: may return an existing `Deny(feedback)` or `NoOpinion`.
  | DecisionToolPolicy(
      DecisionPolicyDescriptor,
      (PureCtx, ToolCallEnvelope) -> ToolPreparation,
      (PureCtx, ToolCallEnvelope, DecisionRequest, DecisionObservation) -> ToolPolicyDecision
    )

-- 8.0 (ADR-001 (031) D2): what `register_with_config` returns. `config` is the
-- extension's disclosed configuration -- data, no credentials -- which the
-- host keeps on the registry entry, stamps as `ext_config` on every view it
-- builds for the extension, and hashes as its config digest. `caps` is a
-- literal list of constructor applications or a delegated call to a named
-- function that, recursively, is one.
export type ExtRegistration = { config: Json, caps: [Capability] }

-- The registry entry: D5's owner-bearing shape. `id` is the host's install
-- stamp (`"${name}#${idx}"`), `caps` the registration list UNCHANGED in list
-- order (the invariant every dispatcher and B5's all-atoms witness read).
-- 8.0: `config` is the registration's `ExtRegistration.config`, unchanged.
export type ExtEntry = { id: string, config: Json, caps: [Capability] }""")

open(out, "w").write(text)
