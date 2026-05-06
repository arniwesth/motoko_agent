PROFILE ?= default

codex:
	codex --yolo

claude:
	claude --dangerously-skip-permissions --model claude-opus-4-6

# Mirror extension source packages into .packages/motoko_* for runtime extension loading.
sync_packages:
	./scripts/sync-extension-packages.sh
	ailang lock

# Type-check every AILANG core runtime module in src/core/
check_core:
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
	#./scripts/install-prerequisites.sh --with-omnigraph
	./scripts/install-prerequisites.sh

# Run all core runtime module tests
test_core:
	@echo "Running src/core/agents_md.ail tests..."
	@ailang test src/core/agents_md.ail || (echo "src/core/agents_md.ail tests failed" && exit 1)
	@echo "Running src/core/parse_test.ail tests..."
	@ailang test src/core/parse_test.ail || (echo "src/core/parse_test.ail tests failed" && exit 1)
	@echo "Running src/core/ext/compose/compose_test.ail tests..."
	@ailang test src/core/ext/compose/compose_test.ail || (echo "src/core/ext/compose/compose_test.ail tests failed" && exit 1)
	@echo "Running src/core/ext/compose/claimcheck_test.ail tests..."
	@ailang test src/core/ext/compose/claimcheck_test.ail || (echo "src/core/ext/compose/claimcheck_test.ail tests failed" && exit 1)
	@printf "\nAll core runtime module tests passed!\n"

test: test_core
