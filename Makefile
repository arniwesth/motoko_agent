PROFILE ?= default

SOKOL_REV ?= 453c71214fbb55d782683d20ea7e6c07314e3e9b
IMGUI_REV ?= 85b2fe8486190fa9326565a2fb5fccb6caea4396
EMSDK_VERSION ?= latest
EMSDK_DIR ?= .emsdk
EMSDK_ENV := $(EMSDK_DIR)/emsdk_env.sh
EMSDK_STAMP := $(EMSDK_DIR)/.motoko-emsdk-$(EMSDK_VERSION).stamp
WEB_DIST := web/dist
WEB_ASSETS := web/assets
WEB_SOURCES := src/main.cpp \
	ext/imgui/imgui.cpp \
	ext/imgui/imgui_draw.cpp \
	ext/imgui/imgui_tables.cpp \
	ext/imgui/imgui_widgets.cpp

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
# mask the status of the others. Set MOTOKO_CONFIG=<profile> to probe a
# different profile (default: current MOTOKO_CONFIG or "default").
verify_extensions:
	@profile=$${MOTOKO_CONFIG:-default}; \
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
	./scripts/install-prerequisites.sh --with-omnigraph

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

test: test_core test_integration

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

.PHONY: check_emcc emsdk deps web web-debug clean-web serve

check_emcc:
	@if [ -f "$(EMSDK_ENV)" ]; then cd "$(EMSDK_DIR)" && export EMSDK_QUIET=1 && . ./emsdk_env.sh >/dev/null && cd "$(CURDIR)"; fi; \
	command -v emcc >/dev/null 2>&1 || { echo "emcc not found. Run 'make emsdk' or install and activate Emscripten 3.1.x or newer."; exit 1; }; \
	ver="$$(emcc --version | head -1)"; \
	echo "$$ver"; \
	nums="$$(printf '%s\n' "$$ver" | sed -E 's/.*[^0-9]([0-9]+)\.([0-9]+)\.[0-9]+.*/\1 \2/')"; \
	set -- $$nums; \
	major="$$1"; minor="$$2"; \
	if [ -z "$$major" ] || [ "$$major" -lt 3 ] || { [ "$$major" -eq 3 ] && [ "$$minor" -lt 1 ]; }; then \
		echo "Emscripten 3.1.x or newer is required."; \
		exit 1; \
	fi

$(EMSDK_STAMP):
	@if [ ! -d "$(EMSDK_DIR)/.git" ]; then \
		rm -rf "$(EMSDK_DIR)"; \
		git clone https://github.com/emscripten-core/emsdk.git "$(EMSDK_DIR)"; \
	fi
	cd "$(EMSDK_DIR)" && ./emsdk install $(EMSDK_VERSION) && ./emsdk activate $(EMSDK_VERSION)
	@touch "$@"

emsdk: $(EMSDK_STAMP)
	@cd "$(EMSDK_DIR)" && export EMSDK_QUIET=1 && . ./emsdk_env.sh >/dev/null && emcc --version | head -1

deps:
	@mkdir -p ext/sokol ext/imgui
	curl -fsSL https://raw.githubusercontent.com/floooh/sokol/$(SOKOL_REV)/sokol_app.h -o ext/sokol/sokol_app.h
	curl -fsSL https://raw.githubusercontent.com/floooh/sokol/$(SOKOL_REV)/sokol_gfx.h -o ext/sokol/sokol_gfx.h
	curl -fsSL https://raw.githubusercontent.com/floooh/sokol/$(SOKOL_REV)/sokol_glue.h -o ext/sokol/sokol_glue.h
	curl -fsSL https://raw.githubusercontent.com/floooh/sokol/$(SOKOL_REV)/sokol_time.h -o ext/sokol/sokol_time.h
	curl -fsSL https://raw.githubusercontent.com/floooh/sokol/$(SOKOL_REV)/util/sokol_imgui.h -o ext/sokol/sokol_imgui.h
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imconfig.h -o ext/imgui/imconfig.h
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imgui.h -o ext/imgui/imgui.h
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imgui_internal.h -o ext/imgui/imgui_internal.h
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imgui.cpp -o ext/imgui/imgui.cpp
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imgui_draw.cpp -o ext/imgui/imgui_draw.cpp
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imgui_tables.cpp -o ext/imgui/imgui_tables.cpp
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imgui_widgets.cpp -o ext/imgui/imgui_widgets.cpp
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imstb_rectpack.h -o ext/imgui/imstb_rectpack.h
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imstb_textedit.h -o ext/imgui/imstb_textedit.h
	curl -fsSL https://raw.githubusercontent.com/ocornut/imgui/$(IMGUI_REV)/imstb_truetype.h -o ext/imgui/imstb_truetype.h

web: emsdk check_emcc deps
	@mkdir -p $(WEB_DIST)
	cd "$(EMSDK_DIR)" && export EMSDK_QUIET=1 && . ./emsdk_env.sh >/dev/null && cd "$(CURDIR)" && emcc $(WEB_SOURCES) \
		-Iext/sokol -Iext/imgui \
		-std=c++17 -O2 \
		-sUSE_WEBGL2=1 \
		-sMIN_WEBGL_VERSION=2 \
		-sMAX_WEBGL_VERSION=2 \
		-sALLOW_MEMORY_GROWTH=1 \
		-sNO_EXIT_RUNTIME=1 \
		--preload-file $(WEB_ASSETS)/motoko.log@/assets/motoko.log \
		-o $(WEB_DIST)/motoko.js

web-debug: emsdk check_emcc deps
	@mkdir -p $(WEB_DIST)
	cd "$(EMSDK_DIR)" && export EMSDK_QUIET=1 && . ./emsdk_env.sh >/dev/null && cd "$(CURDIR)" && emcc $(WEB_SOURCES) \
		-Iext/sokol -Iext/imgui \
		-std=c++17 -O0 -gsource-map \
		-sASSERTIONS=1 \
		-sUSE_WEBGL2=1 \
		-sMIN_WEBGL_VERSION=2 \
		-sMAX_WEBGL_VERSION=2 \
		-sALLOW_MEMORY_GROWTH=1 \
		-sNO_EXIT_RUNTIME=1 \
		--preload-file $(WEB_ASSETS)/motoko.log@/assets/motoko.log \
		-o $(WEB_DIST)/motoko.js

clean-web:
	rm -rf $(WEB_DIST)

serve: web
	@echo "Serving Motoko site at http://127.0.0.1:$${PORT:-8080}"
	python3 -m http.server $${PORT:-8080} --bind 127.0.0.1 --directory web
