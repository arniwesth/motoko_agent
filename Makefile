PROFILE ?= $(if $(MOTOKO_CONFIG),$(MOTOKO_CONFIG),default)

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
# mask the status of the others.
#
# Profile selection keys off the Make $(PROFILE) variable, which resolves to:
# command-line `PROFILE=<x>` override, else $(MOTOKO_CONFIG), else "default"
# (see the PROFILE assignment at the top of this file). This is the SAME
# profile the run recipe boots (`MOTOKO_CONFIG=$(PROFILE) run-agent.sh`), so
# `PROFILE=bedrock make run` verifies bedrock even when the outer shell has a
# different MOTOKO_CONFIG exported. Earlier this recipe read $$MOTOKO_CONFIG
# straight from the shell and silently verified the wrong profile when only
# PROFILE was passed. To probe another profile ad hoc: `PROFILE=foo make
# verify_extensions` (or `MOTOKO_CONFIG=foo`, which feeds the same default).
verify_extensions:
	@profile=$(PROFILE); \
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

# Install all prerequisites (Go, Bun, Node, context-mode, AILANG, TUI deps)
install:
	./scripts/install-prerequisites.sh	

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
# Amazon Bedrock via LiteLLM (bearer-token-only auth)
#
# Architecture:
#   Motoko -> AILANG OpenAI-compatible provider
#          -> OPENAI_BASE_URL=http://127.0.0.1:4000/v1
#          -> LiteLLM  (AWS_BEARER_TOKEN_BEDROCK + AWS_REGION)
#          -> Amazon Bedrock
#
# Bedrock auth is bearer-token ONLY — AWS_PROFILE / AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY / ~/.aws are NOT used. Motoko/AILANG only ever see a
# dummy OpenAI key (motoko-litellm-local); a real OPENAI_API_KEY is never
# forwarded to the local proxy. See README "Bedrock through LiteLLM".
#
# Smoke layers run in order and stop at the first failure, so a Bedrock
# model/profile/auth problem stays separate from an AILANG routing problem
# and a Motoko tool-loop problem:
#   smoke_bedrock_litellm -> smoke_bedrock_ailang
#                         -> smoke_bedrock_motoko -> smoke_bedrock_tools
# ---------------------------------------------------------------------------

# Patched local AILANG binary (carries the OPENAI_BASE_URL direct-fallback fix)
# when present; otherwise whatever `ailang` is on PATH.
BEDROCK_AILANG_BIN := $(if $(wildcard ailang/.bin/ailang),ailang/.bin/ailang,ailang)
# Dummy local proxy key. NEVER a real OpenAI key.
BEDROCK_OPENAI_KEY ?= motoko-litellm-local

# Start the LiteLLM proxy in the foreground (Ctrl-C to stop). Loads .env,
# requires AWS_REGION + AWS_BEARER_TOKEN_BEDROCK, strips AWS credential-chain
# vars from the subprocess, serves http://127.0.0.1:4000/v1.
bedrock_proxy:
	@./scripts/bedrock-proxy.sh

# Layer 1: LiteLLM proxy direct (assumes the proxy is already running).
smoke_bedrock_litellm:
	@./scripts/smoke_bedrock_litellm.sh

# Layer 2: AILANG std/ai.stepWithStream preflight through the proxy.
smoke_bedrock_ailang: smoke_bedrock_litellm
	@echo "smoke[ailang]: $(BEDROCK_AILANG_BIN) --ai gpt-bedrock-claude-sonnet-4-5"
	@mkdir -p tmp
	@OPENAI_BASE_URL=http://127.0.0.1:4000/v1 \
	 OPENAI_API_KEY=$(BEDROCK_OPENAI_KEY) \
	 $(BEDROCK_AILANG_BIN) run --caps AI,IO --ai gpt-bedrock-claude-sonnet-4-5 \
	   --entry main scripts/smoke_bedrock_litellm.ail \
	   > tmp/smoke_bedrock_ailang.log 2>&1; rc=$$?; \
	sed -E 's/(Bearer )[A-Za-z0-9._-]+/\1***REDACTED***/g' tmp/smoke_bedrock_ailang.log | tail -20; \
	[ $$rc -eq 0 ] || { echo "smoke[ailang]: FAIL (rc=$$rc) — see tmp/smoke_bedrock_ailang.log"; exit 1; }; \
	if grep -q '^ERR ' tmp/smoke_bedrock_ailang.log; then \
		echo "smoke[ailang]: FAIL — std/ai returned an error (see tmp/smoke_bedrock_ailang.log)"; exit 1; \
	fi; \
	grep -q 'finish_reason=' tmp/smoke_bedrock_ailang.log \
	  || { echo "smoke[ailang]: FAIL — no finish_reason marker (did it reach LiteLLM?)"; exit 1; }; \
	echo "smoke[ailang]: ✓"

# Layer 3: Motoko minimal task on the bedrock profile.
smoke_bedrock_motoko: smoke_bedrock_ailang
	@echo "smoke[motoko]: minimal PROFILE=bedrock task"
	@mkdir -p tmp
	@OPENAI_API_KEY=$(BEDROCK_OPENAI_KEY) PROFILE=bedrock MOTOKO_CONFIG=bedrock \
	 $(MAKE) --no-print-directory run TASK="Reply with exactly: bedrock smoke ok" \
	   > tmp/smoke_bedrock_motoko.log 2>&1; rc=$$?; \
	sed -E 's/(Bearer )[A-Za-z0-9._-]+/\1***REDACTED***/g' tmp/smoke_bedrock_motoko.log | tail -25; \
	[ $$rc -eq 0 ] || { echo "smoke[motoko]: FAIL (rc=$$rc) — see tmp/smoke_bedrock_motoko.log"; exit 1; }; \
	grep -qi "bedrock smoke ok" tmp/smoke_bedrock_motoko.log \
	  || { echo "smoke[motoko]: FAIL — expected reply not found"; exit 1; }; \
	echo "smoke[motoko]: ✓"

# Layer 4: native tool-use smoke (forces one BashExec round-trip).
smoke_bedrock_tools: smoke_bedrock_motoko
	@echo "smoke[tools]: PROFILE=bedrock tool-use task"
	@mkdir -p tmp
	@OPENAI_API_KEY=$(BEDROCK_OPENAI_KEY) PROFILE=bedrock MOTOKO_CONFIG=bedrock \
	 $(MAKE) --no-print-directory run TASK="Use bash to print the current working directory, then summarize it in one sentence." \
	   > tmp/smoke_bedrock_tools.log 2>&1; rc=$$?; \
	sed -E 's/(Bearer )[A-Za-z0-9._-]+/\1***REDACTED***/g' tmp/smoke_bedrock_tools.log | tail -25; \
	[ $$rc -eq 0 ] || { echo "smoke[tools]: FAIL (rc=$$rc) — see tmp/smoke_bedrock_tools.log"; exit 1; }; \
	echo "smoke[tools]: ✓"

# Run all bedrock smokes layer by layer (stops at the first failure).
smoke_bedrock: smoke_bedrock_tools
	@echo "smoke_bedrock: all layers passed ✓"
