PROFILE ?= $(if $(MOTOKO_CONFIG),$(MOTOKO_CONFIG),default)
QWEN36_COMPACTION_LIVE_TASK ?= Run a long tool-heavy compaction calibration task that repeatedly grows conversation history and continues after compaction.
QWEN36_COMPACTION_HEAVY_TASK ?= Run a compaction stress calibration. Do not stop early. Perform at least 1000 sequential tool-heavy phases. In each phase, read several large source files or documentation files in full, run broad searches over the repository, and keep a running phase log in your response. Prefer files under src/, packages/, .agent/projects/, scripts/, and design_docs/. After every 5 phases, restate the important accumulated findings so far. Continue until you have made at least 1000 model turns or until the runtime compacts. If context pressure or compaction occurs, continue the task and explicitly report that you continued after it. STEP-GATE (mandatory): After EVERY ordinary tool call you make (ReadFile, Search, WriteFile, EditFile, BashExec, RunTests, and any Ctx* or exa_* extension tool), you MUST immediately also call the MotokoRuntimeStatus tool in the same response/turn. Inspect its returned 'current_step' (number of steps executed so far) and 'step_budget'. If current_step is still below the target steps, you MUST continue: do NOT stop, do NOT emit a final-only prose answer, and do NOT declare the task complete. Instead, make further tool calls (read more files, run more searches, keep the running phase log) and advance to the next step. Only when current_step has reached the target of 1000 steps (or the runtime reports compaction) may you emit a final summary. Treat the MotokoRuntimeStatus step count as the authoritative progress indicator and keep calling it until the target is met; never assume you are finished based on a round count of phases alone.

codex:
	clear
	codex --yolo

claude:
	clear
	claude --dangerously-skip-permissions --model claude-opus-4-8

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
		./scripts/phase_a_event_parity.sh /tmp/phase_a_parity_after; \
		diff -r "$$PARITY_BASELINE" /tmp/phase_a_parity_after; \
	else \
		./scripts/phase_a_event_parity.sh /tmp/phase_a_parity_a; \
		./scripts/phase_a_event_parity.sh /tmp/phase_a_parity_b; \
		diff -r /tmp/phase_a_parity_a /tmp/phase_a_parity_b; \
	fi'

phase_c_l1: compaction_dst
	ailang run --caps IO --entry main scripts/dst/phase_c_l1_scenarios.ail
	ailang run --caps IO --entry main scripts/dst/phase_c_approval_protocol.ail
	ailang run --caps IO,Env,Clock,FS,Trace --entry main scripts/phase_c2_wiring_scenarios.ail

compaction_dst:
	ailang run --caps IO --entry main scripts/dst/compaction_policy_dst.ail
	ailang run --caps IO,Env,FS --entry main scripts/dst/compaction_catalog_dst.ail
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main scripts/dst/runtime_status_tool_dst.ail < /dev/null
	MOTOKO_MODELS_FILE=scripts/fixtures/qwen36-small-model-catalog.json \
	  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main \
	  scripts/dst/long_qwen_compaction_dst.ail < /dev/null

conformance:
	AILANG_RELAX_MODULES=1 ailang check packages/motoko_ext_conformance/invariants.ail
	AILANG_RELAX_MODULES=1 ailang check packages/motoko_ext_conformance/harness.ail
	ailang check scripts/conformance_selftest.ail
	ailang check scripts/conformance_registry_probe.ail
	ailang test packages/motoko_ext_conformance/invariants.ail
	ailang run --caps IO,Env,FS --entry main scripts/conformance_selftest.ail
	ailang run --caps IO,Env,FS --entry main scripts/conformance_registry_probe.ail

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
