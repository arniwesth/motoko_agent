# Compaction Stress Calibration — Phase Log

## Phase 1
- Mapped repo structure; began broad reads.

## Phase 1 (turn 1)
- Created phase_log.md; Search(rg) unavailable (no ripgrep). Fallback to grep.
- Read src/core/rpc.ail (header): thin entry point post M-MOTOKO-RPC-LOOP-FULL-MIGRATION (2026-05-06). Imports agent_loop_v2, context_usage, config, cache, prompts, ext/runtime. compute_budget_plan clamps max_steps. reject_if_ohmy_pi_unsupported (M65) emits session_start_error and exit(2) if tools.ohmy_pi=true (inbox delegation pipeline deleted at M10b).

## Phase 2 (turn 2)
- Mapped repo. Top-level: ailang/ fork (vendored), src/ (core AILANG + tui TS), packages/ (many motoko-ext-* + motoko_ext_conformance), scripts/ (probe/smoke/*.ail, *.sh), design_docs/{implemented,planned}, .agent/{research,plans,prs}.
- Identified compaction-relevant dirs: packages/motoko-ext-compaction-ai, packages/motoko-ext-compaction-structural, design_docs/planned/m-motoko-conversation-compaction.md, scripts/*compaction*.ail, scripts/*catalog*.ail.

## Phase 3 (turn 3)
- src/core listing: keyctl files include compaction.ail, compress.ail, context_usage.ail, session.ail (100KB), step_machine.ail, phase_vocab.ail (54KB), tool_runtime.ail, tool_phase.ail, config.ail (21KB), agent_loop_v2.ail, ext/runtime.ail.
- compaction grep hits across core, packages (compaction-ai, compaction-structural), scripts (*compaction*), design_docs/planned/m-motoko-conversation-compaction.md, .agent research DST.

## Phase 4 (turn 4)
- src/core/compaction.ail: measurement surface only. estimate_tokens_messages (sum content len /4). usage_percent_with_limit; fails open (0) if limit==0. exhaustion_pct()=95. Explicitly notes structural elision ladder moved to pkg motoko_ext_compaction_structural.
- src/core/compress.ail: output-level compression (compress_output): strip ANSI, normalize newlines, collapse spaces, collapse repeated lines (>=4 -> "(repeated Nx)"), truncate_with_suffix. Has requires-clauses (Z3 contracts) on truncate helpers.
- src/core/context_usage.ail: estimate_tokens(system+msgs len/4). catalog_context_limit_for(model) reads .motoko/model-catalog.json context_limits; handles openrouter/ prefix stripping; returns 0 if unknown/err (fail open).
- design_docs/planned/m-motoko-conversation-compaction.md: STATUS Planned (P1). Problem: no conversation compaction; ceiling ~40-80 steps on <2M windows. Design: DP0 dispatch_pre_step hook before each LLM call; 3-tier policy (70% elide old tool_results>10 turns, 85% drop bodies>5 turns, 95% refuse w/ compaction_exhausted). Structural elider elide_old_tool_results. AI summarisation via motoko-ext-compaction-ai optional. 250-350 LOC. Acceptance criteria listed but planned.

## ===== 5-PHASE SUMMARY (Phases 1-5) =====
Repo: AILANG fork + src/core (runtime) + src/tui (TS) + packages/motoko-ext-* + scripts/*.ail + design_docs + .agent. ripgrep missing -> grep -rn.
runtime: rpc.ail thin entry -> agent_loop_v2 -> session.ail (sole loop). budget clamps max_steps(default 50). ohmy_pi hard-reject (exit 2).
measurement: estimate_tokens=(system+sum len)/4; catalog_context_limit_for reads .motoko/model-catalog.json (openrouter/ strip, fail-open 0). exhaustion_pct=95.
compaction design (planned): DP0 dispatch_pre_step + 3-tier 70/85/95. impl split: structural elider -> motoko-ext-compaction-structural; AI -> motoko-ext-compaction-ai; core compaction.ail = measurement only.
structural: keep last N tool msgs, elide older >80 chars. emergency keep_last 3 then 1 else compaction_exhausted.
session.ail imports dispatch_pre_step_chain, CompactionApplied/Exhausted, split_for_compaction, segment_messages, system_prefix_digest_for.

## Phase 6 (turn 6)
- agent_loop_v2.ail: pure facade re-exporting Session entrypoints (run_v2, run_v2_with_conversation, conversation_loop_v2). Compat surface stable.
- step_machine.ail (pure decide): StepPolicy.compaction{context_limit,elide_tier_pct:70,elide_hard_tier_pct:85,emergency_pct:95}. should_checkpoint uses history_usage_percent>=checkpoint_pct && checkpoint_would_relieve. project(history,telemetry,compaction) -> Err(ContextExhausted) gates CallModel. decide routes finish_reasons: hybrid_bash/RunTools, await_approval, dp7_rejected->InjectUserMessage, stop->Finalize, stream_error/intercept_handled/tools_complete/user_injected->call_model_or_fail.
- session.ail compaction wiring: imports dispatch_pre_step_chain, CompactionApplied/Exhausted, ExtCompactionRejected, split_for_compaction, segment_messages, system_prefix_digest_for, exhaustion_pct. Lines 1601-1636: split_for_compaction -> segment_messages -> dispatch_pre_step_chain(pre_ctx, msgs); on Err(SealExhausted) emit CompactionExhausted + Err(ContextExhausted). Tracks compaction_ai_applied counts & system_prefix digest stability.
- CONFIRMED: DP0 pre-step compaction fully implemented in live loop (design doc says "Planned" but actually shipped).

## Phase 7-9 (turns 7-9)
- ext/runtime.ail dispatch_pre_step_chain: folds (h.on_pre_step)(ctx,msgs) over registry hooks. Compacted -> validate_compactor_output(msgs,compacted); Ok->StageApplied(next store next_artifacts); Err->StageRejected (skip, keep prior msgs). PassThrough->StagePassed. Records PreStepStage{ext_id,outcome}.
- phase_vocab.ail compaction: PinnedSplit{pinned,segment}. split_for_compaction pins leading system msgs, segment=non-system tail. seal_compacted_payload: payload=pinned++chain_msgs; require_system_prompt && pinned chars==0 -> SealSystemPromptEmpty; pct>=exhaustion_pct(95) -> SealExhausted("compaction_exhausted..."). CompactionPolicy{context_limit,elide_tier_pct:70,elide_hard_tier_pct:85,emergency_pct:95}. project() -> ProviderCallPrepared event (step 0). system_prefix_digest_for = sha256 canonical_messages_raw (content NOT digested). payload_digest = sha256 canonical_messages (content IS digested via digest_content make[N]->make[0]). checkpoint() pins system + [CHECKPOINT] summary.
- motoko_ext_conformance/invariants.ail validate_compactor_output: rejects system msg in output, tool msg w/ empty tool_call_id, invented assistant tool_call id, severed tool_result pair. conformance_abi_version="3.0".
- ext/registry_generated.ail: parse_core_ext_order -> ids "name#idx" in config order. compaction_ai and compaction_structural both registered; structural order in ailang.toml [extensions] determines pre-step chain order.

## ===== 10-PHASE SUMMARY (Phases 1-10) =====
Two compaction extensions both register on_pre_step:
- compaction_structural -> compact_for_pre_step: pure 3-tier elider (70/85/95 keep_last 10/5/3 then1), no AI.
- compaction_ai -> compact_with_ai: AI summary above threshold_pct (config MOTOKO_PROFILE_DIR/compaction_ai.json, default_config()), keep_recent verbatim, halve at >=90%, sha256 cache summaries.
Pre-step chain order = registry order (name#idx from ailang.toml [extensions]). Each Compacted validated by validate_compactor_output (no system msgs, non-empty tool_call_ids, no invented ids, no severed pairs). Invalid->StageRejected(skip); valid->StageApplied. Recorded as CompactionStageRecord/CompactionApplied/ExtCompactionRejected.
Live loop session.ail CallModel branch (~1600): split_for_compaction -> segment_messages -> dispatch_pre_step_chain(pre_ctx, segment) -> seal_compacted_payload(pinned+chain.msgs). seal pins system prefix, requires non-empty system prompt (SealSystemPromptEmpty), rejects pct>=95 (SealExhausted -> CompactionExhausted + Err ContextExhausted). OK -> ProviderCallPrepared w/ system_prefix_digest + payload_digest, then provider call.
Digest: system_prefix_digest = sha256 raw system msgs (content NOT normalized); payload_digest = sha256 all msgs content normalized (make[1..20]->make[0]).
Compaction design doc says Planned but is ACTUALLY SHIPPED in live loop + extensions + conformance.

## Phase 11 (turn 11)
- motoko-ext-abi/types.ail: ABI contract. Msg{role,content,tool_calls,tool_call_id} (v2.1.0 wire parity; without tool_call_id providers reject 422). PreStepDecision=PassThrough|Compacted(msgs,note,artifacts). ExtCtx.context_limit (v2.2.0; 0=unknown->skip, eliminates duplicate model tables in compaction_ai). ExtensionHooks.on_pre_step:(ExtCtx,[Msg])->PreStepDecision !{...}. ExtensionHooks bump = major ABI version.

---
# Run 2 (fresh session) — compaction stress calibration

## 5-PHASE SUMMARY (1-5)
- rpc.ail thin entry -> agent_loop_v2 (facade) -> session.ail (sole loop). budget clamps max_steps default 50; ohmy_pi=true -> session_start_error + exit(2).
- step_machine.decide pure; StepPolicy.compaction{elide_tier_pct:70,elide_hard_tier_pct:85,emergency_pct:95}. project()->Err(ContextExhausted) gates CallModel.
- compaction.ail = measurement only (estimate_tokens_messages sum(len)/4 rounds up; usage_percent_with_limit fails open 0 on limit 0; exhaustion_pct=95). context_usage reads .motoko/model-catalog.json context_limits; openrouter/ strip; fail open 0.
- ext/runtime.dispatch_pre_step_chain folds on_pre_step over registry order; validate_compactor_output -> StageApplied/Rejected/Passed. registry_generated maps ailang.toml [extensions] order -> ids name#idx. compaction_ai(#11) + compaction_structural(#13) register.
- ABI v2.2.0 ExtCtx.context_limit (0=unknown->skip). Msg carries tool_calls+tool_call_id. PreStepDecision = PassThrough | Compacted(msgs,note,artifacts).
- phase_vocab.seal_compacted_payload pins system prefix, requires non-empty (SealSystemPromptEmpty), rejects pct>=95 (SealExhausted). system_prefix_digest=sha256 raw; payload_digest=sha256 content-normalized.

## 10-PHASE SUMMARY (1-10)
- tool_catalog=7 native schemas + MotokoRuntimeStatus + ext. tool_dispatch_adapter bridges runTools (ToolCall)->string to run_native_batch (ToolCallEnvelope -> [ToolResultItem]); malformed args -> empty obj. tool_runtime: backend_for routes file tools Native (Delegated iff ohmy_pi), BashExec/RunTests Native unless shell tokens/cwd/streaming. path-traversal guards (.., bare Users/home/tmp). ports = function-valued seams. types.Msg 4-field (v2.1.0).
- Extension chain order from ROOT ailang.toml [extensions]: compaction_ai=#10, compaction_structural=#13 (last). AI summarizes first; structural elider final safety net.
- model-catalog context_limits: gemini-2.5-pro=2M, opus-4-7=1M, gpt-5=400k, gpt-4o=128k, z-ai/glm-5=128k, test/tiny=100.
- Runtime@step14/100: input 569K (452K cache_read), output 11.5K, compaction NOT triggered yet, system_prefix digest stable.

## 15-PHASE SUMMARY (1-15)
- Loop/config/measurement (1-5): rpc.ail thin -> session.ail sole loop; budget clamps max_steps=50; step_machine.decide pure compaction{70,85,95}; compaction.ail measurement only; context_usage reads .motoko/model-catalog.json (fail open 0).
- Extension chain + seal (4-8,11,14): dispatch_pre_step_chain folds on_pre_step over registry (root ailang.toml order: compaction_ai=#10, compaction_structural=#13 LAST); each Compacted validated by validate_compactor_output -> StageApplied/Rejected/Passed; seal_compacted_payload pins system prefix, requires non-empty, rejects pct>=95 (SealExhausted -> CompactionExhausted). AI summarizes first; structural elider final safety net.
- Tool layer (9-10,16): tool_catalog 7 native + MotokoRuntimeStatus; tool_dispatch_adapter bridges runTools -> run_native_batch; tool_runtime exec + path-traversal guards; ports function-valued seams; types.Msg 4-field. Makefile = calibration harness; check_core/compaction_dst/conformance/verify_extensions.
- Recovery/cost (11): should_retry_stream_error(retry, remaining>1); persist_nudge when no WriteFile; cost_phase cap at 50/75/90% warnings.
- Docs (12-15): CSP ADR-001 = run_tool_select/selectEvents, compaction/hooks untouched. Phase-Core ADR-001 (live) = phase-oriented core; D9 compaction policy extension-resident, core scaffold only; compactor chain replaces first-Compacted-wins; 70/85/95 ladder -> bundled compaction_structural; ABI v3 adds telemetry. design_docs/planned/m-motoko-conversation-compaction.md STALE (says Planned) - feature shipped. long_qwen_compaction_dst.ail = DST compaction harness.
- Conformance/DST (17-18): harness scenarios system_prefix_preserved, tool_pairing_preserved, deterministic_replay, artifact_cache_effective; registry_probe runs all 13 hooks; compaction_policy_dst tiers ladder + emergency recover/defer.
- phase_vocab (19): sealed History/ProviderPayload; LedgerEvent 29-type union ([prod] + [NEW] additive); ProviderCallPrepared carries system_prefix_digest+payload_digest; checkpoint chain validated via content digests; hook_phase.stage_record converts PreStepStage -> CompactionStageRecord.
