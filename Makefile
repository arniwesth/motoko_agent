PROFILE ?= $(if $(MOTOKO_CONFIG),$(MOTOKO_CONFIG),default)
QWEN36_COMPACTION_LIVE_TASK ?= Run a long tool-heavy compaction calibration task that repeatedly grows conversation history and continues after compaction.
QWEN36_COMPACTION_HEAVY_TASK ?= Run a compaction stress calibration. Do not stop early. Perform at least 1000 sequential tool-heavy phases. In each phase, read several large source files or documentation files in full, run broad searches over the repository, and keep a running phase log in your response. Prefer files under src/, packages/, .agent/projects/, scripts/, and design_docs/. After every 5 phases, restate the important accumulated findings so far. Continue until you have made at least 1000 model turns or until the runtime compacts. If context pressure or compaction occurs, continue the task and explicitly report that you continued after it. STEP-GATE (mandatory): After EVERY ordinary tool call you make (ReadFile, Search, WriteFile, EditFile, BashExec, RunTests, and any Ctx* or exa_* extension tool), you MUST immediately also call the MotokoRuntimeStatus tool in the same response/turn. Inspect its returned 'current_step' (number of steps executed so far) and 'step_budget'. If current_step is still below the target steps, you MUST continue: do NOT stop, do NOT emit a final-only prose answer, and do NOT declare the task complete. Instead, make further tool calls (read more files, run more searches, keep the running phase log) and advance to the next step. Only when current_step has reached the target of 1000 steps (or the runtime reports compaction) may you emit a final summary. Treat the MotokoRuntimeStatus step count as the authoritative progress indicator and keep calling it until the target is met; never assume you are finished based on a round count of phases alone.

codex:
	clear
	codex --yolo

claude:
	clear
	claude --dangerously-skip-permissions --model claude-opus-5

prune:
	docker system prune -a

# Mirror extension source packages into .packages/motoko_* for runtime extension loading.
sync_packages:
	@set -eu; \
	if [ "$(CI)" = "1" ]; then \
		version=$$(grep -E '^ailang\s*=' ailang.toml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1); \
		if [ -z "$$version" ]; then \
			echo "Could not parse ailang floor from ailang.toml" >&2; \
			exit 1; \
		fi; \
		ref="v$$version"; \
		script_ref=$$(grep -E '^AILANG_REF=' scripts/install-prerequisites.sh | head -n1 | cut -d'"' -f2); \
		if [ "$$script_ref" != "$$ref" ]; then \
			echo "Version mismatch: ailang.toml floor=$$ref but install-prerequisites.sh AILANG_REF=$$script_ref — bump them together." >&2; \
			exit 1; \
		fi; \
	fi
	./scripts/sync-extension-packages.sh
	ailang lock

# M-MOTOKO-OHMY-PI-DEFAULT-FLIP regression guard: assert every shipped config
# profile has tools.ohmy_pi=false. Until M-MOTOKO-M6.5 (env-server inbox-based
# delegation) lands, ohmy_pi=true is structurally a no-op that wastes 25-33%
# of tool calls — every shipped default must therefore stay at false.
# The matching code-side fail-fast lives in src/core/rpc.ail
# (reject_if_ohmy_pi_unsupported).
smoke_no_delegated_storm:
	@fail=0; \
	for f in .motoko/config/default/config.json \
	         .motoko/config/dogfood/config.json \
	         .motoko/config/local/config.json \
	         .motoko/config/openrouter/config.json; do \
		v=$$(jq -r '.tools.ohmy_pi' "$$f"); \
		if [ "$$v" = "false" ]; then \
			echo "  ✓ $$f tools.ohmy_pi=$$v"; \
		else \
			echo "  ✗ $$f tools.ohmy_pi=$$v (expected false; see design_docs/planned/m-motoko-ohmy-pi-default-flip.md)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	[ "$$fail" -eq 0 ] || { echo "smoke_no_delegated_storm FAILED — re-enabling ohmy_pi without M6.5 wired causes BashExec storms"; exit 1; }; \
	echo "smoke_no_delegated_storm: all 4 profiles have ohmy_pi=false ✓"

smoke_parity:
	@bash -euo pipefail -c '\
	if [ -n "$${PARITY_BASELINE:-}" ]; then \
		./scripts/dst/phase_a_event_parity.sh /tmp/phase_a_parity_after; \
		diff -r "$$PARITY_BASELINE" /tmp/phase_a_parity_after; \
	else \
		./scripts/dst/phase_a_event_parity.sh /tmp/phase_a_parity_a; \
		./scripts/dst/phase_a_event_parity.sh /tmp/phase_a_parity_b; \
		diff -r /tmp/phase_a_parity_a /tmp/phase_a_parity_b; \
	fi'

phase_c_l1: compaction_dst
	ailang run --caps IO --entry main scripts/dst/phase_c_l1_scenarios.ail
	ailang run --caps IO --entry main scripts/dst/phase_c_approval_protocol.ail
	ailang run --caps IO,Env,Clock,FS,Trace --entry main scripts/dst/phase_c2_wiring_scenarios.ail

.PHONY: dst
dst:
	+$(MAKE) --keep-going compaction_dst conformance phase_c_l1 terminal_trace world_state profile_coverage fault_catalogue event_vocabulary smoke_driver smoke_parity dst_l2 dst_seeded

# D5's coverage floor and per-extension hook disclosure (WI-A6). Two checks:
#
#   1. The fixture PROFILES. Every rejecting shape D5 names, asserted to be
#      rejected BY ITS RULE rather than merely rejected — a fixture that trips
#      an unrelated check is green while testing nothing. Plus the two shapes
#      that must load: driver_only's empty install list (vacuous, per P4) and a
#      profile excluding only the one GATED hook.
#
#   2. A STRUCTURAL GUARD that the eight-slot enumeration still matches the ABI.
#      `all_hook_slots()` is hand-written and AILANG has no constructor
#      enumeration on the pin, so a ninth ABI hook could be added and left out
#      of it while every check in the module still passed — an artifact that
#      validates while incomplete, which is the exact failure S1 names for
#      constructed artifacts. Counting the ABI record's `on_*` fields ties the
#      enumeration to the thing it enumerates instead of to itself.
#
# Note the ADR undercounts here and this target is where that shows: D5 says six
# of eight slots are unconditionally dispatched and one is gated, leaving the
# eighth unstated. It is `on_describe_tools`, dispatched by an unconditional
# fold in tool_catalog.ail:114 that live_ports reaches on every model step. So
# SEVEN are unconditional, and excluding `on_describe_tools` is a rejection.
# The `on_describe_tools excluded (the seventh)` fixture is that correction.
.PHONY: profile_coverage
profile_coverage:
	@set -eu; \
	ailang run --caps IO --entry main scripts/dst/profile_coverage_dst.ail < /dev/null; \
	n=$$(awk '/export type ExtensionHooks/,/^}/' packages/motoko-ext-abi/types.ail | grep -c '^  on_'); \
	if [ "$$n" -ne 8 ]; then \
		echo "FAIL: the ABI declares $$n hook slots, but src/core/dst_profile_coverage.ail"; \
		echo "      enumerates 8 in all_hook_slots(). A slot has been added or removed and"; \
		echo "      the coverage artifact does not know about it, so every profile would"; \
		echo "      validate while its disclosure was incomplete (D5)."; \
		awk '/export type ExtensionHooks/,/^}/' packages/motoko-ext-abi/types.ail | grep '^  on_'; \
		exit 1; \
	else \
		echo "  ✓ all_hook_slots() enumerates all $$n ABI hook slots"; \
	fi; \
	ailang test src/core/dst_profile_coverage.ail > /dev/null && echo "  ✓ src/core/dst_profile_coverage.ail"

# D3's fault catalogue (WI-A7). Three checks:
#
#   1. The acceptance script. Completeness of the SHIPPED catalogue against D3's
#      table, and the reconciliation of the three tool `fault_class` names
#      observed on the wire rather than read out of the source — the catalogue
#      adopted the strings tool_phase already emitted, so the only thing worth
#      asserting is that the two cannot drift apart again.
#
#   2. 007 D1.3's PHYSICAL-FAULT TRIPWIRE, made executable. D3 excludes
#      torn/partial physical writes from scope and binds that exclusion to
#      accepted 007 D1.3, carrying its five reopen triggers verbatim: a
#      crash-recovery, fsync, WAL, resume-from-ledger or replicated-state
#      correctness contract. Any one of those gives Motoko a physical durability
#      contract it does not have today, and the moment it has one the exclusion
#      stops being a scope decision and becomes an untested gap. The tree has
#      zero hits at baseline, so this fires on the first one.
#
#   3. The validator's own unit tests, including the set-completeness cases: an
#      empty catalogue must fail, and so must one whose every remaining row is
#      perfect but which omits a single required class.
.PHONY: fault_catalogue
fault_catalogue:
	@set -eu; \
	ailang run --caps IO --entry main scripts/dst/fault_catalogue_dst.ail < /dev/null; \
	hits=$$(grep -rniE 'fsync|write-ahead log|resume-from-ledger|replicated-state' \
	          src packages --include=*.ail | grep -v 'dst_fault_catalogue.ail' | wc -l); \
	if [ "$$hits" -ne 0 ]; then \
		echo "FAIL: $$hits site(s) suggest a physical durability contract. D3 excludes"; \
		echo "      torn/partial physical writes and binds that exclusion to accepted"; \
		echo "      007 D1.3, whose reopen triggers are crash-recovery, fsync, WAL,"; \
		echo "      resume-from-ledger and replicated-state. Reopen the scope decision"; \
		echo "      before adding one — the physical-fault exclusion has just become an"; \
		echo "      untested gap rather than a scope choice."; \
		grep -rniE 'fsync|write-ahead log|resume-from-ledger|replicated-state' \
		  src packages --include=*.ail | grep -v 'dst_fault_catalogue.ail'; \
		exit 1; \
	else \
		echo "  ✓ no physical durability contract in the tree (007 D1.3 tripwire clear)"; \
	fi; \
	ailang test src/core/dst_fault_catalogue.ail > /dev/null && echo "  ✓ src/core/dst_fault_catalogue.ail"

# D6's event vocabulary, the fifth recorded axis (WI-A8). Four checks:
#
#   1. The round trip. All 34 LedgerEvent variants — and BOTH StreamDelta
#      branches, since that is the one variant whose wire name is a function of
#      the payload — are projected through the live to_schema_v1 and compared
#      against the artifact's declared wire name AND payload schema. Checking
#      only the name would leave the payload schema decorative prose.
#
#   2. THREE STRUCTURAL GUARDS, because the artifact's completeness cannot be
#      made a compile error on the pin. AILANG has no constructor enumeration,
#      so a 35th LedgerEvent variant would force an arm in event_variant_id
#      (which is a total match) but could be left out of the row list AND out of
#      the sample list, and every check above would still pass — an artifact
#      that validates while incomplete. The guards tie all three lists to the
#      TYPE DECLARATION rather than to each other:
#
#        variants in `export type LedgerEvent`   == rows in event_vocabulary()
#        rows in event_vocabulary()              == variants with a golden
#
#      The second also keeps the BYTE-level pinning total: the goldens in
#      phase_vocab cover all 34 today, and this is what stops a new variant
#      entering the vocabulary without one.
#
#   3. The vocabulary's own unit tests and phase_vocab's goldens.
#
# NOTE for anyone editing src/core/dst_event_vocabulary.ail: guard 2 counts
# `variant: "` inside the body of `event_vocabulary()`. Writing that string in
# prose inside that function turns this gate red for no reason — the same shape
# as terminal_trace's `{ result:` counter over session.ail.
.PHONY: event_vocabulary
event_vocabulary:
	@set -eu; \
	ailang run --caps IO --entry main scripts/dst/event_vocabulary_dst.ail < /dev/null; \
	variants=$$(awk '/export type LedgerEvent/,/^$$/' src/core/phase_vocab.ail | grep -c '^  [|=]'); \
	rows=$$(awk '/^export pure func event_vocabulary\(\)/,/^}/' src/core/dst_event_vocabulary.ail | grep -c 'variant: "'); \
	goldens=$$(grep -oE 'golden\([A-Za-z0-9]+\(' src/core/phase_vocab.ail | sed 's/golden(//' | tr -d '(' | sort -u | wc -l); \
	if [ "$$variants" -ne "$$rows" ]; then \
		echo "FAIL: LedgerEvent declares $$variants variants but the vocabulary carries $$rows rows."; \
		echo "      A variant with no row is an artifact that validates while incomplete —"; \
		echo "      the wire name, payload schema and logical/display-only classification"; \
		echo "      of that event are undeclared, and D6 fails closed on exactly that."; \
		exit 1; \
	fi; \
	if [ "$$rows" -ne "$$goldens" ]; then \
		echo "FAIL: $$rows vocabulary rows but only $$goldens variants have a byte-level"; \
		echo "      golden in src/core/phase_vocab.ail. The wire projection is a"; \
		echo "      compatibility surface (project 007); a variant in the vocabulary with"; \
		echo "      no golden has its NAME pinned but not its BYTES."; \
		exit 1; \
	fi; \
	echo "  ✓ $$variants LedgerEvent variants == $$rows vocabulary rows == $$goldens golden-pinned variants"; \
	ailang test src/core/dst_event_vocabulary.ail > /dev/null && echo "  ✓ src/core/dst_event_vocabulary.ail"; \
	ailang test src/core/phase_vocab.ail > /dev/null && echo "  ✓ src/core/phase_vocab.ail (goldens)"

# WI-A12's advancement + trace-completeness gate, landed BEFORE the threading it
# watches — the plan's binding sequencing rule. The script header carries the
# full rationale; what belongs here is why it is a separate target and not one
# more line in compaction_dst: every effect class A12 threads adds its
# assertions to this one probe, so the gate is named after the thing it guards.
#
# Verified falsifiable rather than assumed, by reproducing cluster 1's exact
# mutation: flipping the six dispatch carry sites to the carry-forward form
# type-checks clean (`✓ No errors found!`) and turns SEVEN assertions here red.
# The instructive half is what stayed GREEN under that total freeze — the
# one-RunSummary invariant and both determinism axes. Each axis is blind to the
# others' defect class, which is why the probe asserts all three.
#
# The target also carries A12's per-class POISON PAIR, D4's F3-corrected
# per-run backstop. Each effect class contributes two runs:
#
#   deterministic + capability withheld  -> must EXIT 0 (nothing reads ambiently)
#   live          + capability withheld  -> must EXIT NON-ZERO (it is load-bearing)
#
# Both halves are required. The first alone passes vacuously — a probe that
# completes with AI withheld proves nothing if no path would have used AI. That
# vacuity is cluster 4's C1b defect: a green check implying absent coverage.
# The poison script drives the LIVE provider and is invoked ONLY in the
# withheld configuration, so it terminates before any network call.
#
# A denied ambient effect terminates evaluation on the pin — no typed result,
# no partial trace. That is D6.6 and it must stay a raw non-zero run rather
# than being unified into a typed HarnessFailure.
#
# THE ENV CLASS HAS NO POISON PAIR, DELIBERATELY, AND THIS IS THE REASON.
# All six of the driver's own env reads are routed (session.ail has zero
# getEnvOr calls). But withholding Env still kills a deterministic run, because
# `src/core/context_usage.ail` reads MOTOKO_MODELS_FILE / MOTOKO_REPO /
# MOTOKO_PROFILE_DIR / MOTOKO_CONFIG from `resolve_context_limit`, which the
# driver calls at six sites.
#
# Those reads are NOT routable on their own. `resolve_context_limit` is
# `! {Env, FS}` and every env read in it exists to compute a FILE PATH that it
# then reads. Threading the world through the env half would hand back a
# world-supplied path to an ambient file — a run that passes an Env poison probe
# while still depending on ambient state. That is a green check implying absent
# coverage, which is exactly cluster 4's C1b defect, so it is not done here.
# Completing it needs a filesystem class, which WI-A12's specified order does
# not contain. Reported as a plan finding rather than worked around.
#
# The env class's evidence is therefore PROVENANCE, not capability: the probe
# seeds MOTOKO_HEADLESS in the world and asserts the driver acted on the world's
# value, with a control run proving the two branches differ. CI's process
# environment does not set that variable, so the world cannot pass by agreeing
# with it.
.PHONY: world_state
world_state:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main scripts/dst/world_state_probe.ail < /dev/null; \
	echo "  -- provider class poison pair (AI withheld) --"; \
	if ailang run --caps IO,Env,FS,Process,Net,SharedMem,Clock,Stream,Trace --entry main \
	     scripts/dst/world_state_probe.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ deterministic world completes with AI withheld"; \
	else \
		echo "FAIL: the deterministic entry point needs AI — the provider class is not routed"; \
		exit 1; \
	fi; \
	if ailang run --caps IO,Env,FS,Process,Net,SharedMem,Clock,Stream,Trace --entry main \
	     scripts/dst/world_state_poison.ail < /dev/null > /dev/null 2>&1; then \
		echo "FAIL: the LIVE world completed with AI withheld — the capability is not load-bearing, so the check above is vacuous"; \
		exit 1; \
	else \
		echo "  ✓ live world dies with AI withheld"; \
	fi; \
	echo "  -- clock class poison pair (Clock withheld) --"; \
	if ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Stream,Trace --ai-stub --entry main \
	     scripts/dst/world_state_probe.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ deterministic world completes with Clock withheld (all 4 driver sites routed, P3)"; \
	else \
		echo "FAIL: the deterministic entry point still reads an ambient clock — a driver clock site is un-routed"; \
		exit 1; \
	fi; \
	if ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Stream,Trace --ai-stub --entry main \
	     scripts/dst/world_state_poison.ail < /dev/null > /dev/null 2>&1; then \
		echo "FAIL: the LIVE world completed with Clock withheld — the capability is not load-bearing"; \
		exit 1; \
	else \
		echo "  ✓ live world dies with Clock withheld"; \
	fi; \
	echo "  -- env class --"; \
	echo "  i Env-withheld pair DEFERRED, not skipped — see the note in the Makefile above"; \
	echo "  i the env class's evidence is the provenance assertion in world_state_probe"; \
	echo "  -- typed tool contract poison pair (Process withheld) --"; \
	if ailang run --caps IO,Env,FS,AI,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main \
	     scripts/dst/world_state_probe.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ fully-seeded world completes with Process withheld (no real dispatch)"; \
	else \
		echo "FAIL: a seeded tool world still reached the real dispatcher — tool_exec is not routed"; \
		exit 1; \
	fi; \
	if POISON_ARM=tools ailang run --caps IO,Env,FS,AI,Net,SharedMem,Clock,Stream,Trace --ai-stub \
	     --entry main scripts/dst/world_state_poison.ail < /dev/null > /dev/null 2>&1; then \
		echo "FAIL: an UNSEEDED tool world completed with Process withheld — it never reached the real"; \
		echo "      dispatcher, so the seeded check above is vacuous"; \
		exit 1; \
	else \
		echo "  ✓ unseeded tool world dies with Process withheld"; \
	fi; \
	echo "  -- randomness class (D1 request-surface item 5, \"runtime randomness, if any\") --"; \
	n=$$(grep -l 'std/rand' src/core/*.ail 2>/dev/null | wc -l); \
	if [ "$$n" -ne 0 ]; then \
		echo "FAIL: $$n driver module(s) reach std/rand. src/core/*.ail had none when WI-A12"; \
		echo "      routed its effect classes, so an ambient RNG has appeared and is un-routed."; \
		echo "      D1 names an ambient RNG as a prohibited hiding place for world state."; \
		echo "      (src/core/test/ is deliberately excluded: dst_gen.ail is a seeded GENERATOR,"; \
		echo "       which is explicit randomness outside the driver, not an ambient read in it.)"; \
		grep -l 'std/rand' src/core/*.ail; \
		exit 1; \
	else \
		echo "  ✓ no driver module (src/core/*.ail) reaches std/rand"; \
	fi; \
	echo "  ✓ every run above completed without the Rand capability ever being granted"

# D6's terminal-trace contract (WI-A9). Four checks, in order:
#
#   1. terminal_trace_dst asserts, over the trace the driver RETURNS, that every
#      drivable terminal path ends with exactly one RunSummary as its final
#      record and that the outcome agrees with it.
#   2. THE D6.6 DISTINCTION. A raw capability bypass must stay an expected
#      non-zero run — it must NOT become a typed HarnessFailure. A denied
#      ambient effect terminates evaluation on the pin, so no typed result and
#      no partial trace can exist. Withholding Env must therefore fail, and this
#      check fails if it ever starts succeeding, which is what would happen if
#      someone "unified" the two outcomes behind a catch-all.
#   3. A structural guard: every terminal return in the driver must go through
#      c2_finalize. c2_finalize holds the sole `{ result:` record literal, so
#      more than one means a terminal path has been added that appends no
#      RunSummary — the exact regression D6.1 exists to prevent, and one that no
#      per-path test can catch for a path nobody wrote a test for.
#   4. The typed reason's wire mapping and result-class unit tests. session.ail
#      and phase_vocab.ail carry inline tests that no target ran before this
#      one, including the RunSummary goldens that pin the wire strings.
.PHONY: terminal_trace
terminal_trace:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry main scripts/dst/terminal_trace_dst.ail < /dev/null; \
	if ailang run --caps IO --entry main scripts/dst/terminal_trace_dst.ail \
	     < /dev/null > /dev/null 2>&1; then \
		echo "FAIL: a run with capabilities withheld exited 0 — a raw capability bypass must remain a non-zero run (D6.6)"; \
		exit 1; \
	else \
		echo "  ✓ capability bypass remains a non-zero run (D6.6)"; \
	fi; \
	n=$$(grep -c '{ result:' src/core/session.ail); \
	if [ "$$n" -ne 1 ]; then \
		echo "FAIL: $$n terminal record literals in session.ail, expected 1 (c2_finalize). A terminal return is bypassing the finalizer — see D6.1."; \
		grep -n '{ result:' src/core/session.ail; \
		exit 1; \
	else \
		echo "  ✓ all terminal returns route through c2_finalize"; \
	fi; \
	ailang test src/core/dst_result.ail > /dev/null && echo "  ✓ src/core/dst_result.ail"; \
	ailang test src/core/phase_vocab.ail > /dev/null && echo "  ✓ src/core/phase_vocab.ail"; \
	ailang test src/core/session.ail > /dev/null && echo "  ✓ src/core/session.ail"

# Driver full-loop coverage (WI-A16). These eight smoke scripts exercise the v2
# driver loop end-to-end and, until this target existed, ran in no make target
# and no CI job — cluster 1 (WI-A2) changed the contract every one of them
# depends on and nothing in the repo would have run them. smoke_v2_dp7_gate is
# the ONLY executable coverage of c2_after_dp7. src/core/test/scripted_ports.ail
# is here for the same reason: check_core globs src/core/*.ail only, so its six
# unit tests were run by nothing.
#
# Every script runs even if an earlier one fails, so a driver change sees its
# whole blast radius in one pass rather than one failure at a time. The target
# still exits non-zero if any script or the unit tests fail.
#
# All eight need the full capability set and --ai-stub, and all eight read from
# /dev/null so a stub prompt cannot block CI. This mirrors compaction_dst.
.PHONY: smoke_driver
smoke_driver:
	@fail=0; \
	for f in scripts/smoke_v2_dp7_gate.ail \
	         scripts/smoke_v2_pending_full_loop.ail \
	         scripts/smoke_v2_compaction_full_loop.ail \
	         scripts/smoke_v2_stream_parity.ail \
	         scripts/smoke_v2_ext_fixture_parity.ail \
	         scripts/smoke_v2_cost_budget_full_loop.ail \
	         scripts/smoke_v2_compaction_chain.ail \
	         scripts/smoke_phase_a_tool_parity.ail; do \
		if ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
		     --ai-stub --entry main "$$f" < /dev/null > /dev/null 2>&1; then \
			echo "  ✓ $$f"; \
		else \
			echo "  ✗ $$f"; \
			ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
			  --ai-stub --entry main "$$f" < /dev/null 2>&1 | tail -15; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	if ailang test src/core/test/scripted_ports.ail > /dev/null 2>&1; then \
		echo "  ✓ src/core/test/scripted_ports.ail (6 unit tests)"; \
	else \
		echo "  ✗ src/core/test/scripted_ports.ail"; \
		ailang test src/core/test/scripted_ports.ail 2>&1 | tail -15; \
		fail=$$((fail + 1)); \
	fi; \
	echo "smoke_driver: $$fail failed"; \
	[ "$$fail" -eq 0 ] || exit 1

dst_seeded:
	ailang run --caps IO,Env,Rand --entry main scripts/dst/compaction_seeded_dst.ail
	ailang run --caps IO,Env,Rand --entry main scripts/dst/phase_c_seeded_dst.ail

compaction_dst:
	ailang run --caps IO --entry main scripts/dst/compaction_policy_dst.ail
	ailang run --caps IO,Env,FS --entry main scripts/dst/compaction_catalog_dst.ail
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main scripts/dst/runtime_status_tool_dst.ail < /dev/null
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main scripts/dst/scripted_cursor_probe.ail < /dev/null
	MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
	  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main \
	  scripts/dst/long_qwen_compaction_dst.ail < /dev/null

conformance:
	AILANG_RELAX_MODULES=1 ailang check packages/motoko_ext_conformance/invariants.ail
	AILANG_RELAX_MODULES=1 ailang check packages/motoko_ext_conformance/harness.ail
	ailang check scripts/dst/conformance_selftest.ail
	ailang check scripts/dst/conformance_registry_probe.ail
	ailang test packages/motoko_ext_conformance/invariants.ail
	ailang run --caps IO,Env,FS --entry main scripts/dst/conformance_selftest.ail
	ailang run --caps IO,Env,FS --entry main scripts/dst/conformance_registry_probe.ail

# Type-check every AILANG core runtime module in src/core/, then
# runtime-boot-probe every extension in the active profile's registry
# so DP7 can catch the class of bugs that pass type-check but crash
# at runtime (e.g. matching Result constructors against an Option
# value — see scripts/verify_extension_boot.ail header for full
# rationale + history).
check_core: verify_extensions
	@ok=0; fail=0; \
	for f in src/core/*.ail; do \
		if ailang check "$$f" >/dev/null 2>&1; then \
			echo "  ✓ $$f"; \
			ok=$$((ok + 1)); \
		else \
			echo "  ✗ $$f"; \
			ailang check "$$f" 2>&1 | tail -3; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo "src/core/ type-check: $$ok passed, $$fail failed"; \
	[ "$$fail" -eq 0 ] || exit 1

# Boot each extension in the active profile's [extensions.order] in an
# ISOLATED ailang process and assert it returns from register_with_config
# without panic. Catches the class of bugs that escape `ailang check`:
#   - Pattern matches against the wrong ADT (Result vs Option)
#   - readFile-style panics when defaults are absent
#   - Cross-package ADT shape drift (variants added/removed in deps)
# Process-per-extension isolation means a panic in one extension doesn't
# mask the status of the others. Set MOTOKO_CONFIG=<profile> to probe a
# different profile (default: current MOTOKO_CONFIG or "default").
verify_extensions:
	@profile=$${MOTOKO_CONFIG:-$(PROFILE)}; \
	cfg=".motoko/config/$$profile/config.json"; \
	if [ ! -f "$$cfg" ]; then \
		echo "verify_extensions: no config at $$cfg — skipping"; \
		exit 0; \
	fi; \
	exts=$$(jq -r '.extensions.order[]?' "$$cfg" 2>/dev/null); \
	if [ -z "$$exts" ]; then \
		echo "verify_extensions: profile '$$profile' has no extensions — skipping"; \
		exit 0; \
	fi; \
	ok=0; fail=0; failed_names=""; \
	for ext in $$exts; do \
		out=$$(MOTOKO_PROFILE_DIR="$$PWD/.motoko/config/$$profile" \
		      AILANG_RELAX_MODULES=1 \
		      ailang run --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream \
		        --ai-stub --entry main \
		        scripts/verify_extension_boot.ail -- "$$ext" 2>&1); \
		rc=$$?; \
		if [ $$rc -eq 0 ] && echo "$$out" | grep -q "^OK:"; then \
			echo "  ✓ $$ext register_with_config"; \
			ok=$$((ok + 1)); \
		else \
			echo "  ✗ $$ext"; \
			echo "$$out" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | grep -E "Error|UNKNOWN" | head -3 | sed 's/^/      /'; \
			fail=$$((fail + 1)); \
			failed_names="$$failed_names $$ext"; \
		fi; \
	done; \
	echo "verify_extensions ($$profile): $$ok booted, $$fail failed"; \
	[ "$$fail" -eq 0 ] || { echo "FAILED:$$failed_names"; exit 1; }

# Build the TypeScript frontend
build_tui:
	cd src/tui && bun install && bun run build

# Generate config profile from template
init-config:
	bun src/tui/src/init-config.ts --profile $(PROFILE) $(ARGS)

# Build everything
build: sync_packages check_core build_tui

# Run the agent
run: build
	clear
	MOTOKO_CONFIG=$(PROFILE) ./scripts/run-agent.sh

# Optional live calibration only; not part of compaction_dst or CI.
# Requires OPENROUTER_API_KEY and uses Qwen for both agent and compaction_ai.
live_qwen36_compaction_calibration: build
	clear
	MOTOKO_CONFIG=qwen36-compaction-live \
	  TASK="$(QWEN36_COMPACTION_LIVE_TASK)" \
	  ./scripts/run-agent.sh

live_qwen36_compaction_heavy: build
	clear
	MOTOKO_CONFIG=qwen36-compaction-live \
	  TASK="$(QWEN36_COMPACTION_HEAVY_TASK)" \
	  ./scripts/run-agent.sh

live_qwen36_compaction_heavy_headless: build
	clear
	MOTOKO_CONFIG=qwen36-compaction-live \
	  MOTOKO_HEADLESS=1 \
	  MOTOKO_CAPTURE_FAILED_PAYLOAD=1 \
	  TASK="$(QWEN36_COMPACTION_HEAVY_TASK)" \
	  ./scripts/run-agent.sh

live_hunyuan3_free_compaction_heavy_headless: build
	clear
	MOTOKO_CONFIG=hunyuan3-free-compaction-live \
	  MOTOKO_HEADLESS=1 \
	  MOTOKO_CAPTURE_FAILED_PAYLOAD=1 \
	  TASK="$(QWEN36_COMPACTION_HEAVY_TASK)" \
	  ./scripts/run-agent.sh

deepseekv4_flash_compaction_heavy_headless: build
	clear
	MOTOKO_CONFIG=deepseekv4-flash-compaction-live \
	  MOTOKO_HEADLESS=1 \
	  MOTOKO_CAPTURE_FAILED_PAYLOAD=1 \
	  TASK="$(QWEN36_COMPACTION_HEAVY_TASK)" \
	  ./scripts/run-agent.sh


# Install all prerequisites (Go, Bun, Node, context-mode, AILANG, TUI deps)
install:
	./scripts/install-prerequisites.sh	

.PHONY: dst_l2
dst_l2:
	cd src/tui && bun test src/harness-dst.test.ts

# Run all core runtime module tests
test_core:
	@echo "Running src/core/agents_md.ail tests..."
	@ailang test src/core/agents_md.ail || (echo "src/core/agents_md.ail tests failed" && exit 1)
	@echo "Running src/core/parse_test.ail tests..."
	@ailang test src/core/parse_test.ail || (echo "src/core/parse_test.ail tests failed" && exit 1)
	@printf "\nAll core runtime module tests passed!\n"

test_integration:
	@echo "Running src/core/test/integration_tests.ail tests..."
	@ailang test src/core/test/integration_tests.ail || (echo "src/core/test/integration_tests.ail tests failed" && exit 1)
	@printf "\nAll integration tests passed!\n"

test: test_core

# Z3 contract verification for pure core modules.
# VIOLATION or ERROR exits 1 (contracts written but broken).
# SKIPPED exits 0 (contracts aspirational or function outside Z3 fragment).
# Files with no contracts are noted but do not fail.
verify_core:
	@ok=0; fail=0; none=0; \
	for f in src/core/*.ail; do \
		case "$$f" in *_test.ail) continue ;; esac; \
		out="$$(ailang verify "$$f" 2>&1)"; \
		rc=$$?; \
		if [ $$rc -ne 0 ]; then \
			echo "  ✗ $$f"; \
			echo "$$out" | grep -E 'VIOLATION|ERROR' | head -3; \
			fail=$$((fail + 1)); \
		elif echo "$$out" | grep -q "no functions with contracts"; then \
			none=$$((none + 1)); \
		else \
			proven="$$(echo "$$out" | grep 'VERIFIED' | wc -l | tr -d ' ')"; \
			echo "  ✓ $$f ($$proven proven)"; \
			ok=$$((ok + 1)); \
		fi; \
	done; \
	echo "verify_core: $$ok with contracts, $$fail failed, $$none without contracts"; \
	[ "$$fail" -eq 0 ] || exit 1

# Z3 contract verification for extension modules.
verify_ext:
	@ok=0; fail=0; none=0; \
	for f in $$(find src/core/ext -name "*.ail" ! -name "*_test.ail"); do \
		out="$$(ailang verify "$$f" 2>&1)"; \
		rc=$$?; \
		if [ $$rc -ne 0 ]; then \
			echo "  ✗ $$f"; \
			echo "$$out" | grep -E 'VIOLATION|ERROR' | head -3; \
			fail=$$((fail + 1)); \
		elif echo "$$out" | grep -q "no functions with contracts"; then \
			none=$$((none + 1)); \
		else \
			proven="$$(echo "$$out" | grep 'VERIFIED' | wc -l | tr -d ' ')"; \
			echo "  ✓ $$f ($$proven proven)"; \
			ok=$$((ok + 1)); \
		fi; \
	done; \
	echo "verify_ext: $$ok with contracts, $$fail failed, $$none without contracts"; \
	[ "$$fail" -eq 0 ] || exit 1

# ---------------------------------------------------------------------------
# ADR-001 D5 obligation 2, classifier 1: the effect-bearing stdlib module set.
#
# Two derivations (builtin projection + parsed stdlib interfaces), unioned and
# reconciled against what src/ and packages/ actually import. Fails closed on any
# imported std/* module it cannot resolve.
#
# `effect_inventory_selftest` cross-validates the textual fallback against
# `ailang iface` on every file where both run. Run it after any toolchain repin;
# the derived set is toolchain-specific and the tool refuses to run when the scan
# root and the executing compiler disagree.
# ---------------------------------------------------------------------------
.PHONY: effect_inventory effect_inventory_selftest
effect_inventory:
	@python3 tools/effect-inventory/derive.py

effect_inventory_selftest:
	@python3 tools/effect-inventory/derive.py --self-test
