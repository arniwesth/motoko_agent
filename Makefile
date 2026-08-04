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
	+$(MAKE) --keep-going compaction_dst conformance phase_c_l1 terminal_trace world_state profile_coverage profile_definition driver_only fault_catalogue event_vocabulary invariants attribution_table execution_program discovery strict_replay seeded_generator program_persistence predicate_anchors ext_call_inventory ext_call_inventory_selftest smoke_driver smoke_parity dst_l2 dst_seeded

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

# D5's profile-DEFINITION and EXECUTION-MANIFEST machinery (WI-A10). Three
# checks, and the third exists because this is composition work:
#
#   1. The fixture DEFINITIONS. Every rejecting shape D5 names, asserted to be
#      rejected BY ITS RULE, each one mutated a single field away from a
#      definition that loads clean — so an unrelated rule firing means the
#      mutation did something other than what the label says. Plus the NEGATIVE
#      CONTROL, which is load-bearing rather than decorative: a validator that
#      only ever rejects passes a suite of only-rejecting fixtures.
#
#   2. A STRUCTURAL GUARD that the definition still carries all ten D5 fields.
#      The record is hand-written and dropping a field is a compile error only
#      at construction sites — so a field could be removed together with its
#      check and every fixture would still pass, which is an artifact that
#      validates while incomplete.
#
#   3. THE ANTI-TRANSCRIPTION GUARD. Classifier 2's sets are derived from the
#      SOURCE by a Python tool, so they enter the AILANG fixtures as literals,
#      and a literal is what goes stale silently. check_fixtures.py re-derives
#      them and fails if the AILANG side disagrees — including the check that
#      every installable extension the tool found calling a classifier-2 field
#      is named in the fixture, and (once the profile lands) omitted by name.
#
# Everything else this machinery needs is READ at runtime from the artifact that
# computed it — the seven/one dispatch split from A6, the table identity from
# A5, each waiver's condition from A7, the vocabulary version from A8 — because
# the characteristic defect of composition is re-deriving a fact an input
# already computed, where both answers type-check and the stale one is silent.
# D5's own prose is the live example: it says SIX slots are unconditionally
# dispatched and it is SEVEN.
.PHONY: profile_definition
profile_definition:
	@set -eu; \
	ailang run --caps IO --entry main scripts/dst/profile_definition_dst.ail < /dev/null; \
	n=$$(awk '/^export type ProfileDefinition/,/^}/' src/core/dst_profile.ail | grep -c '^  [a-z_]*:'); \
	if [ "$$n" -ne 15 ]; then \
		echo "FAIL: ProfileDefinition declares $$n record fields, expected 15."; \
		echo "      D5's TEN definition fields are 12 record fields here: id and version are"; \
		echo "      one D5 field and two records, and D5 field 2 (extension ids AND per-hook"; \
		echo "      classifications) is installed_packages plus hook_classifications, with"; \
		echo "      disclosures separate again as D5 field 9. A10's decisions add three more:"; \
		echo "      unrouted_reachable_sites, scan_roots, exercised_fault_classes."; \
		echo "      A field has been added or removed and its"; \
		echo "      presence check in validate_required_fields may not have moved with it,"; \
		echo "      so a definition could omit it and load clean (D5)."; \
		awk '/^export type ProfileDefinition/,/^}/' src/core/dst_profile.ail | grep '^  [a-z_]*:'; \
		exit 1; \
	else \
		echo "  ✓ ProfileDefinition declares all $$n fields (D5's ten as 12, plus A10's three)"; \
	fi; \
	python3 tools/profile_definition/check_fixtures.py; \
	ailang test src/core/dst_profile.ail > /dev/null && echo "  ✓ src/core/dst_profile.ail"

# `driver_only` v1 — the first conformant simulation profile (WI-A10, plan P4).
# Separate from `profile_definition` because the machinery is reusable and this
# is one instance of it: the validator must be seen to REJECT before the
# definition that passes it is seen at all.
#
#   1. The load-time acceptance. The same `validate_definition_at_load` a runner
#      calls, at the table's bound revision, against the measured inventory and
#      the derived classifier-2 call set — asserting it loads CLEAN, names its
#      `compaction_ai` omission, takes its waivers from A7's stable ids with
#      each condition read back from the catalogue, and computes its routed-set
#      claim rather than recording one.
#
#   2. THE ANTI-TRANSCRIPTION GUARD, again, and here it does its real work: it
#      checks that every installable extension the call inventory finds calling
#      a classifier-2 field is OMITTED BY NAME in the profile. The day a second
#      extension calls a state-threading seam, this goes red instead of the
#      profile quietly claiming coverage it does not have.
#
# NOTE the intended failure mode: the attribution reference is recorded as
# LITERALS, so correcting the attribution table turns this target RED until
# `driver_only` is re-issued with a version bump. That is D4's rule — a table
# correction re-issues every referring profile — and it is only mechanically
# true if the profile records the content hash and something compares it. If
# this goes red after a table edit, bump `driver_only_version` and re-record the
# pair; do not make the profile call `table_identity()`, which would turn the
# comparison into a tautology.
# D2's execution program and its pure structural validator (WI-A13, stage 1).
#
# The acceptance script is MUTATION-BASED: one valid program, one change each,
# and every row asserts the specific RULE its change violates rather than merely
# a non-empty rejection list. A guard that is deleted or weakened in one
# direction turns exactly its own row red — verified by deliberately removing
# the duplicate-ordinal guard, by dropping one direction of the deadline rule,
# and by rewriting the duplicate rule to compare identity BODIES.
#
# The last of those is why the base program contains a RETRY: interactions #1
# and #8 carry a byte-identical tool identity at different ordinals. D2 requires
# a repeated production call id to stay representable "so an invariant can
# reject them as system behavior rather than the program decoder rejecting the
# artifact". Rejecting duplicate bodies type-checks, passes every mutant row,
# and silently makes the retry artifact undecodable — the NEGATIVE CONTROL is
# the only thing that catches it. If you tighten the duplicate rule and this
# goes red, the rule is what is wrong, not the fixture.
.PHONY: execution_program
execution_program:
	@set -eu; \
	ailang run --caps IO --entry main scripts/dst/execution_program_dst.ail < /dev/null; \
	ailang test src/core/dst_program.ail > /dev/null && echo "  ✓ src/core/dst_program.ail"

# WI-A13 stage 2: discovery against `driver_only`. Four checks, in order.
#
#   1. The acceptance script. Two scenarios (`approve`, `deny`), each carrying
#      the two-sided balance, the identity-CONTENT comparisons, seven mutation
#      rows, the vacuity control, determinism, and stage 1's structural
#      validator run over the recorded log.
#
#   2. THE WIRE WITNESS, and it is the strongest evidence in this stage. The
#      driver emits `provider_call_prepared` (session.ail, before the
#      dispatch_step call) and `v2_tool_dispatch_start` (tool_phase.ail, before
#      the port calls) to the wire through ledger_emit. Neither is appended to
#      the returned ledger trace, so no AILANG assertion can read them —
#      cluster 4 measured that same emit/append imbalance. This step captures
#      the JSONL and compares it against the census the recorder printed. Two
#      authors, two records, one execution: it is what makes the tool class's
#      completeness an oracle rather than the recorder grading itself.
#
#      `--entry wire_witness` performs exactly ONE run so the comparison is
#      exact equality with nothing to keep in sync.
#
#   3. THE ENV CLASS'S SOURCE DERIVATION. The env class has no runtime witness
#      at all — `ports.env_get` is a keyed lookup and emits no ledger event — so
#      its completeness is asserted against the keys the DRIVER'S SOURCE can
#      read. This step re-derives that set from the `ports.env_get(` call sites
#      and diffs it against `driver_env_keys()`. The literal is checked, never
#      trusted: a source-derived set nobody re-derives is a stale literal, and
#      then the env class's only evidence is the recorder's own word.
#
#      This is PROVENANCE evidence, not capability evidence. A13's report and
#      D11's counters must not add it into one completeness number with the six
#      classes that have runtime witnesses.
#
#   4. The checker's own unit tests, including its negative control and both
#      over-recording directions.
#
# The env grep is anchored to the SYNTACTIC FORM `.env_get(<world>, "KEY"` and
# not to a bare key name — cluster 7's correction 1. A guard that greps a bare
# token eventually fires on the artifact documenting it, because these items are
# required to write prose naming what they check.
#
# The receiver is deliberately unanchored. The first version of this grep
# required `ports.env_get(`, and it silently missed session.ail's
# MOTOKO_CAPTURE_FAILED_PAYLOAD read, which goes through `st.provider.env_get(`.
# The derivation caught that itself on its first run — which is the argument for
# deriving rather than declaring, made by the derivation. A key literal is
# required, so session.ail's extension-bridge closure (whose key is a variable
# supplied by an extension) correctly does not match.
.PHONY: discovery
discovery:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry main scripts/dst/discovery_dst.ail < /dev/null; \
	wire=$$(ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry wire_witness scripts/dst/discovery_dst.ail < /dev/null 2>/dev/null); \
	w_prov=$$(printf '%s\n' "$$wire" | grep -c '"type":"provider_call_prepared"' || true); \
	w_tool=$$(printf '%s\n' "$$wire" | grep -c '"type":"v2_tool_dispatch_start"' || true); \
	c_prov=$$(printf '%s\n' "$$wire" | sed -n 's/.*CENSUS wire .*expect_provider=\([0-9]*\).*/\1/p'); \
	c_tool=$$(printf '%s\n' "$$wire" | sed -n 's/.*CENSUS wire .*expect_tool=\([0-9]*\).*/\1/p'); \
	if [ -z "$$c_prov" ] || [ -z "$$c_tool" ]; then \
		echo "FAIL: the wire_witness run printed no census line — the comparison below would be vacuous"; \
		exit 1; \
	fi; \
	if [ "$$w_prov" -eq 0 ] || [ "$$w_tool" -eq 0 ]; then \
		echo "FAIL: the driver emitted no provider_call_prepared/v2_tool_dispatch_start to the wire (prov=$$w_prov tool=$$w_tool) — the witness is absent, so a match would prove nothing"; \
		exit 1; \
	fi; \
	if [ "$$w_prov" -ne "$$c_prov" ] || [ "$$w_tool" -ne "$$c_tool" ]; then \
		echo "FAIL: the interaction log disagrees with the driver's own wire emissions."; \
		echo "      provider: wire=$$w_prov log=$$c_prov"; \
		echo "      tool:     wire=$$w_tool log=$$c_tool"; \
		echo "      These are written by different components. The wire is emitted by production driver code BEFORE the port is called; the log is written by the port. A disagreement is a recorder defect, not a flaky count."; \
		exit 1; \
	else \
		echo "  ✓ the interaction log matches the driver's own wire emissions (provider=$$w_prov, tool=$$w_tool)"; \
	fi; \
	derived=$$(grep -ohE '\.env_get\(\s*[a-zA-Z_][a-zA-Z0-9_.]*\s*,\s*"[A-Z_]+"' \
	     src/core/session.ail src/core/tool_phase.ail \
	   | sed -E 's/.*"([A-Z_]+)"/\1/' | sort -u); \
	declared=$$(sed -n '/^export pure func driver_env_keys/,/^}/p' src/core/dst_discovery.ail \
	   | grep -oE '"[A-Z_]+"' | tr -d '"' | sort -u); \
	if [ -z "$$derived" ]; then \
		echo "FAIL: no ports.env_get call sites found in the driver — the derivation is broken, so the diff below would pass vacuously"; \
		exit 1; \
	fi; \
	if [ "$$derived" != "$$declared" ]; then \
		echo "FAIL: driver_env_keys() disagrees with the ports.env_get call sites in the driver."; \
		echo "      derived from source:"; printf '%s\n' "$$derived" | sed 's/^/        /'; \
		echo "      declared in src/core/dst_discovery.ail:"; printf '%s\n' "$$declared" | sed 's/^/        /'; \
		echo "      The env class has NO runtime witness. This set is its only independent evidence, so a stale literal leaves the recorder grading itself."; \
		exit 1; \
	else \
		echo "  ✓ driver_env_keys() re-derived from the driver's ports.env_get call sites ($$(printf '%s\n' "$$derived" | wc -l | tr -d ' ') keys)"; \
	fi; \
	ailang test src/core/dst_discovery.ail > /dev/null && echo "  ✓ src/core/dst_discovery.ail"; \
	ailang test src/core/dst_interaction.ail > /dev/null && echo "  ✓ src/core/dst_interaction.ail"

# WI-A13 stage 3: strict replay against `driver_only`. Four checks, in order.
#
#   1. The acceptance script. Two scenarios — `rich`, which is the fixture that
#      must SURVIVE and carries every shape D2 protects with no two of its
#      quantities equal (S7), and `maxsteps`, which ends in `Err` so the
#      Err-surviving witnesses are exercised on the path where the returned
#      message list is empty. Each carries the refusal rules, the manifest
#      check, the two-sided reconstitution balance, the replay comparison, seven
#      single-position mutation rows, the typed HarnessFailure, determinism, and
#      — the axis that makes this stage more than a restatement of itself — the
#      replayed run graded against witnesses the recorder did not write, plus
#      the tautology control that proves the grading is load-bearing.
#
#      Stage 5 adds axis J: D2's REGRESSION mode over those same five mutated
#      logs, which must record two of them and stay fatal on the other five.
#      Both modes read one set of inputs on purpose — a regression mode given
#      its own quietly different fixtures could disagree with strict mode for
#      reasons that have nothing to do with the demotion set.
#
#   2. THE WIRE WITNESS. `v2_tool_dispatch_start` (tool_phase.ail) is emitted
#      BEFORE the port calls and `provider_call_prepared` (session.ail) is
#      emitted separately from the dispatch call. Neither is appended to the
#      returned trace — session.ail hands tool_phase a bare
#      `\event. ledger_emit(...)` — so no AILANG assertion can read them.
#      `--entry wire_witness` performs exactly ONE discovery run and ONE replay
#      of its program, and this step compares the wire's totals against the sum
#      of the two censuses. NO MULTIPLIER: a sum over the runs that actually
#      happened cannot go stale when a scenario is added elsewhere.
#
#      It also asserts the two censuses are EQUAL, which is strict replay's own
#      claim restated on the wire's terms — by production code that knows
#      nothing about the interaction log.
#
#   3. THE CODEC TESTS. `world_state_of` reconstitutes the provider script and
#      the tool queue from recorded payloads, so a codec whose encoder and
#      decoder disagree about a field produces a replay that serves a different
#      response while every count still balances. The round trips are in
#      ports.ail because that is where both halves live.
#
#   4. dst_replay's own units: the walk, the outcome projection and the
#      reconstitution balance, each shown to fire AND to stay quiet.
.PHONY: strict_replay
strict_replay:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry main scripts/dst/strict_replay_dst.ail < /dev/null; \
	wire=$$(ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry wire_witness scripts/dst/strict_replay_dst.ail < /dev/null 2>/dev/null); \
	w_prov=$$(printf '%s\n' "$$wire" | grep -c '"type":"provider_call_prepared"' || true); \
	w_tool=$$(printf '%s\n' "$$wire" | grep -c '"type":"v2_tool_dispatch_start"' || true); \
	d_prov=$$(printf '%s\n' "$$wire" | sed -n 's/.*CENSUS discovery .*expect_provider=\([0-9]*\).*/\1/p'); \
	d_tool=$$(printf '%s\n' "$$wire" | sed -n 's/.*CENSUS discovery .*expect_tool=\([0-9]*\).*/\1/p'); \
	r_prov=$$(printf '%s\n' "$$wire" | sed -n 's/.*CENSUS replay .*expect_provider=\([0-9]*\).*/\1/p'); \
	r_tool=$$(printf '%s\n' "$$wire" | sed -n 's/.*CENSUS replay .*expect_tool=\([0-9]*\).*/\1/p'); \
	if [ -z "$$d_prov" ] || [ -z "$$r_prov" ] || [ -z "$$d_tool" ] || [ -z "$$r_tool" ]; then \
		echo "FAIL: the wire_witness run printed no discovery/replay census pair — the program was refused, or the entry point changed, and every comparison below would be vacuous"; \
		printf '%s\n' "$$wire" | grep -E 'CENSUS|REFUSED' || true; \
		exit 1; \
	fi; \
	if [ "$$w_prov" -eq 0 ] || [ "$$w_tool" -eq 0 ]; then \
		echo "FAIL: the driver emitted no provider_call_prepared/v2_tool_dispatch_start to the wire (prov=$$w_prov tool=$$w_tool) — the witness is absent, so a match would prove nothing"; \
		exit 1; \
	fi; \
	if [ "$$d_prov" -ne "$$r_prov" ] || [ "$$d_tool" -ne "$$r_tool" ]; then \
		echo "FAIL: the replay did not reproduce the discovered run's per-class counts."; \
		echo "      provider: discovery=$$d_prov replay=$$r_prov"; \
		echo "      tool:     discovery=$$d_tool replay=$$r_tool"; \
		exit 1; \
	fi; \
	if [ "$$w_prov" -ne "$$((d_prov + r_prov))" ] || [ "$$w_tool" -ne "$$((d_tool + r_tool))" ]; then \
		echo "FAIL: the interaction logs disagree with the driver's own wire emissions across the discovery/replay pair."; \
		echo "      provider: wire=$$w_prov logs=$$((d_prov + r_prov))"; \
		echo "      tool:     wire=$$w_tool logs=$$((d_tool + r_tool))"; \
		echo "      These are written by different components. The wire is emitted by production driver code BEFORE the port is called; the logs are written by the port. A disagreement is a recorder or replay defect, not a flaky count."; \
		exit 1; \
	else \
		echo "  ✓ discovery and replay agree with the driver's own wire emissions (provider=$$w_prov, tool=$$w_tool over the pair)"; \
	fi; \
	ailang test src/core/ports.ail > /dev/null && echo "  ✓ src/core/ports.ail (recorded-outcome codec round trips)"; \
	ailang test src/core/dst_replay.ail > /dev/null && echo "  ✓ src/core/dst_replay.ail"

# D2's SEEDED GENERATOR (WI-A13 stage 4). Three checks:
#
#   1. The acceptance script. Ten axes over five honest generated runs and three
#      seed-ignoring mutant runs — seed sensitivity, the mutant, the generator
#      actually being consulted, the declared bounds in both directions, stage
#      1's validator and stage 3's strict replay over generated programs, S7's
#      two obligations, the C5 mutations and determinism.
#
#   2. dst_generator's own units, which are where the seed-sensitivity RULE is
#      asserted against hand-built row sets — including a seed-ignoring one that
#      must go red, written and run before a line of the generator existed (S1).
#      Stage 5 adds D8's GENERATOR CANARY here: pinned rows per generator id and
#      version that go red if the seed-to-choices mapping moves without a
#      version bump. The pins are hand-written literals and there is NO target
#      that refreshes them — that is the point, not an omission. A red canary is
#      a decision: bump `generator_version` and re-pin by hand so a reviewer
#      reads the diff, or fix the generator.
#
#   3. THE SEEDROW COMPARISON, out of process. The one result this stage exists
#      to produce — different seeds produce different programs — is re-derived
#      HERE from the script's own emitted rows, by a second author that cannot
#      share a defect with the in-process comparison. Three things are checked
#      and each is a different way for the claim to be hollow:
#
#        * two rows with DIFFERENT seeds have different digests (the claim);
#        * two rows with the SAME seed have the SAME digest (reproducibility,
#          without which "different" is just noise);
#        * the equal-count pair really does have equal interaction counts, so
#          the difference above cannot be a difference in program LENGTH. A
#          count is blind to two programs of equal length and different
#          contents, which is how cluster 9's site 19 stayed hidden through
#          every count-shaped gate in this suite.
#
#      The greps below are anchored to the emitted line's syntactic form
#      (`^SEEDROW <label> seed=`), not to a bare token. A bare-token guard
#      eventually fires on the artifact that documents it, which is what kept
#      `make world_state` red for two clusters.
.PHONY: seeded_generator
seeded_generator:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry main scripts/dst/seeded_generator_dst.ail < /dev/null; \
	rows=$$(ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry wire_witness scripts/dst/seeded_generator_dst.ail < /dev/null 2>/dev/null); \
	get() { printf '%s\n' "$$rows" | sed -n "s/^SEEDROW $$1 seed=[0-9]* version=[0-9]* n=\([0-9]*\) outcomes_len=[0-9]* digest=\(-*[0-9]*\)$$/\1 \2/p"; }; \
	rich=$$(get rich); a=$$(get pairA); b=$$(get pairB); \
	if [ -z "$$rich" ] || [ -z "$$a" ] || [ -z "$$b" ]; then \
		echo "FAIL: the wire_witness run emitted no SEEDROW triple — the entry point changed or a run died, and every comparison below would be vacuous"; \
		printf '%s\n' "$$rows" | grep -E '^SEEDROW' || true; \
		exit 1; \
	fi; \
	n_a=$${a% *}; d_a=$${a#* }; n_b=$${b% *}; d_b=$${b#* }; d_rich=$${rich#* }; \
	if [ "$$d_a" = "$$d_b" ]; then \
		echo "FAIL: seeds 9 and 13 produced the SAME outcome digest ($$d_a)."; \
		echo "      The generator is not reading its seed. D2 makes the seed an input to every"; \
		echo "      discovery choice; a generator that ignores it produces one program for every"; \
		echo "      seed — deterministic, structurally valid, strictly replayable, certifying nothing."; \
		exit 1; \
	fi; \
	if [ "$$n_a" -ne "$$n_b" ]; then \
		echo "FAIL: seeds 9 and 13 no longer have equal interaction counts ($$n_a vs $$n_b)."; \
		echo "      The difference above could then be a difference in program LENGTH, and a count"; \
		echo "      is blind to two programs of equal length and different contents. Re-sweep for"; \
		echo "      an equal-count pair and re-pin it; do not delete this check."; \
		exit 1; \
	fi; \
	if [ "$$d_rich" = "$$d_a" ]; then \
		echo "FAIL: the rich fixture and seed 9 produced the same outcome digest — the rows are not distinct runs"; \
		exit 1; \
	fi; \
	echo "  ✓ different seeds produce different programs at EQUAL interaction count (n=$$n_a, digests $$d_a vs $$d_b)"; \
	ailang test src/core/dst_generator.ail > /dev/null && echo "  ✓ src/core/dst_generator.ail (the seed-sensitivity rule, and the PRNG's two silent failure modes)"

# D8's PERSISTENCE OBLIGATIONS (WI-A13 stage 6). Six checks.
#
#   1. The acceptance script. The negative control first — an honest synthetic
#      program survives the detector and redaction of it is the identity — then
#      the driver's own environment surface, the per-shape mutation rows, the
#      rule-coverage row, the interaction sites, and D8's reject-or-redact
#      tension reported rather than decided silently. Then the encoding: the
#      specimen's shape coverage, the field-by-field round trip, determinism and
#      diffability as NUMBERS, the frozen v1 artifact, the fail-closed unknown
#      schema, thirteen decode mutation rows, the ordering obligation read off
#      the file system, the store's collision refusal, and regression replay
#      over the program decoded from the frozen bytes.
#
#   2. dst_secrets's own units. This is where the detectors' FALSE-POSITIVE
#      controls live, and they are the load-bearing half: every manifest this
#      project persists carries a git revision and every artifact carries a
#      sha256 digest, both of which are long unbroken runs in the credential
#      alphabet. A detector that scores them refuses every honest program while
#      looking like it is working.
#
#   3. THE STD-ONLY TIER GUARD, below. `dst_secrets` may import std and
#      `dst_interaction` and nothing else, and that is a structural property
#      rather than a tidiness preference: WI-A14 records interaction artifacts
#      at the port seam, and `src/core/ports.ail` cannot import a module that
#      names `ExecutionManifest` without dragging the whole 1559-line
#      `dst_profile` closure into the PRODUCTION driver's import graph. Stage 2
#      moved `Interaction` down for exactly this reason; an import added here
#      makes the redactor unreachable from the place it is needed, and nothing
#      else in the build would notice until A14 tried.
#
#      The grep is anchored to the syntactic form `^import ` rather than to a
#      module name, so it cannot be satisfied by renaming and cannot fire on
#      prose that mentions a module (cluster 7's correction 1).
#   4. THE MANIFEST ARITY GUARD. `ExecutionManifest` has sixteen fields and the
#      codec must write and read all sixteen. A field added in `dst_profile` and
#      forgotten in `required_header_tags()`/`repeatable_header_tags()` would be
#      silently absent from every artifact: the encoder would not write it, the
#      decoder would not miss it, and both halves type-check. That is S7's
#      record-level form, and it is the defect this whole stage exists to
#      prevent — so it is counted from `dst_profile`'s own declaration rather
#      than trusted to a literal, exactly as the ProfileDefinition guard above
#      counts A10's.
#
#   5. THE FROZEN SPECIMEN GUARD. `scripts/dst/fixtures/execution-program-v1.artifact`
#      is the compatibility policy. There is deliberately NO target that
#      regenerates it — no --update, no ACCEPT=1 — because the encoder and the
#      decoder were written in the same commit and agree by construction, so
#      every round-trip row would pass against a policy that exists only as
#      prose. This guard checks the file is present and non-trivial, so that
#      deleting it turns the gate red instead of turning the frozen row vacuous.
#      If the acceptance row goes red, the two permitted responses are to keep a
#      v1 decode path or to bump the schema version and pin a runner. Rewriting
#      the file is the one response that is not available.
#
#   6. THE NO-REGENERATION GUARD. Nothing in the tree may write to the fixtures
#      directory. This is the guard that keeps check 5 honest: a convenience
#      entry point that refreshes the specimen becomes a habit, and the first
#      person to hit a red compatibility row will use it. The one that produced
#      these bytes was deleted after use, which is stage 5's discipline for its
#      canary pins applied to an artifact instead of a table.
.PHONY: program_persistence
program_persistence:
	@set -eu; \
	ailang run --caps IO,FS --entry main scripts/dst/program_persistence_dst.ail < /dev/null; \
	declared=$$(awk '/^export type ExecutionManifest/,/^}/' src/core/dst_profile.ail \
	   | grep -c '^  [a-z_0-9]*:'); \
	coded=$$(sed -n '/^export pure func required_header_tags/,/^}/p;/^export pure func repeatable_header_tags/,/^}/p' \
	     src/core/dst_persistence.ail | grep -c 'tag: "manifest\.'); \
	if [ "$$declared" -eq 0 ] || [ "$$coded" -eq 0 ]; then \
		echo "FAIL: counted $$declared manifest fields and $$coded codec tags — one of the two derivations is broken, so the comparison below would pass vacuously"; \
		exit 1; \
	fi; \
	if [ "$$declared" -ne "$$coded" ]; then \
		echo "FAIL: ExecutionManifest declares $$declared fields but the program codec names $$coded of them."; \
		echo "      declared in src/core/dst_profile.ail:"; \
		awk '/^export type ExecutionManifest/,/^}/' src/core/dst_profile.ail | grep '^  [a-z_0-9]*:' | sed 's/^/        /'; \
		echo "      A manifest field the codec does not name is silently absent from every persisted"; \
		echo "      artifact: the encoder never writes it, the decoder never misses it, and both halves"; \
		echo "      type-check. D8 conditions its whole reproducibility promise on the recorded manifest,"; \
		echo "      and D11 says a program promoted without one is not a reproduction unit. Add the field"; \
		echo "      to encode_body, to required_header_tags (or repeatable_header_tags), and to project."; \
		exit 1; \
	fi; \
	echo "  ✓ the program codec names all $$declared ExecutionManifest fields (re-counted from dst_profile's own declaration)"; \
	for f in scripts/dst/fixtures/execution-program-v1.artifact \
	         scripts/dst/fixtures/execution-program-v0.artifact; do \
		if [ ! -s "$$f" ]; then \
			echo "FAIL: the frozen specimen $$f is missing or empty."; \
			echo "      It is THE compatibility policy: encoder and decoder are written together and agree"; \
			echo "      by construction, so without a frozen artifact from before the current encoder the"; \
			echo "      policy is prose and the gate is green. It is not regenerable by design."; \
			exit 1; \
		fi; \
	done; \
	echo "  ✓ both frozen specimens are present ($$(wc -l < scripts/dst/fixtures/execution-program-v1.artifact | tr -d ' ') lines of v1 bytes, predating no encoder change yet)"; \
	writers=$$(grep -rlE 'writeFile[A-Za-z]*\(\s*"?scripts/dst/fixtures|v1_fixture_path\(\)\s*,|v0_fixture_path\(\)\s*,' \
	     src scripts --include=*.ail || true); \
	if [ -n "$$writers" ]; then \
		echo "FAIL: something in the tree writes to the frozen fixtures:"; \
		printf '%s\n' "$$writers" | sed 's/^/        /'; \
		echo "      There must be no regeneration target. A convenience that refreshes the specimen"; \
		echo "      becomes the first thing anyone reaches for when the compatibility row goes red,"; \
		echo "      and using it destroys the only artifact in this project that predates the current"; \
		echo "      encoder. Add a v1 decode path, or bump the schema version and pin a runner."; \
		exit 1; \
	fi; \
	echo "  ✓ nothing in the tree writes to scripts/dst/fixtures — the specimen has no regeneration target"; \
	ailang test src/core/dst_persistence.ail > /dev/null && echo "  ✓ src/core/dst_persistence.ail (the escape, the tag tables, and the path-vs-identity split site 22 forces)"; \
	imports=$$(grep -E '^import ' src/core/dst_secrets.ail \
	   | sed -E 's/^import +([a-zA-Z0-9_/]+).*/\1/' | sort -u); \
	if [ -z "$$imports" ]; then \
		echo "FAIL: no import lines found in src/core/dst_secrets.ail — the tier guard below would pass vacuously"; \
		exit 1; \
	fi; \
	foreign=$$(printf '%s\n' "$$imports" | grep -v '^std/' | grep -v '^src/core/dst_interaction$$' || true); \
	if [ -n "$$foreign" ]; then \
		echo "FAIL: src/core/dst_secrets.ail imports outside the std-only tier:"; \
		printf '%s\n' "$$foreign" | sed 's/^/        /'; \
		echo "      It may import std/* and src/core/dst_interaction and nothing else."; \
		echo "      WI-A14 redacts interaction artifacts AT THE PORT SEAM, and src/core/ports.ail"; \
		echo "      cannot import a module naming ExecutionManifest without pulling the whole"; \
		echo "      dst_profile closure into the production driver's import graph. Stage 2 moved"; \
		echo "      Interaction down for this reason. Move what you need down, do not import up."; \
		exit 1; \
	fi; \
	echo "  ✓ src/core/dst_secrets.ail stays in the std-only tier ($$(printf '%s\n' "$$imports" | wc -l | tr -d ' ') imports, all std/* or dst_interaction)"; \
	ailang test src/core/dst_secrets.ail > /dev/null && echo "  ✓ src/core/dst_secrets.ail (the detectors, and the false-positive controls that keep honest artifacts persistable)"

.PHONY: driver_only
driver_only:
	@set -eu; \
	ailang run --caps IO --entry main scripts/dst/driver_only_dst.ail < /dev/null; \
	python3 tools/profile_definition/check_fixtures.py; \
	ailang test src/core/dst_driver_only.ail > /dev/null && echo "  ✓ src/core/dst_driver_only.ail"

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

# D7's whole-execution invariant set (WI-A14 piece 1). Three checks, and the
# structural ones exist for the reason every hand-written set in this project
# has one: AILANG has no constructor enumeration on the pin, so a set can grow
# a member that no list knows about and every check still passes — an artifact
# that validates while incomplete.
#
#   1. THE SUITE. One fixture that must SURVIVE (S7, both halves executable),
#      then a single-field mutation per rule, each asserting ITS OWN rule rather
#      than a non-empty finding list. Cluster 12 measured why that matters: a
#      row asserting "some finding" is green on the wrong evidence, and two
#      rows here caught exactly that during construction — a stream-parity
#      check that compared tags and not content, and a retry mutant that was
#      tripping `record-after-terminal` instead.
#
#   2. TWO STRUCTURAL GUARDS, both anchored to a SYNTACTIC form (the `= X` /
#      `| X` constructor lines of the type declaration itself) rather than to a
#      count written down somewhere:
#
#        variants in `export type InvariantFamily` == all_families()      (12)
#        variants in `export type Violation`       == sample_violations() (37)
#
#      The second is the load-bearing one. `violation_rule`, `violation_family`
#      and `violation_message` are total matches, so a new rule is a compile
#      error in all three — but a new rule left out of `sample_violations()`
#      would never be checked for a distinct id, a family, or a message that
#      names it, and the suite would be green while the artifact was incomplete.
#
#   3. The module's own unit tests, which carry the parity pins: the register
#      equals the vocabulary's gap in both directions, and the display-only set
#      is the pinned six. Those two are what make D6.4's one-line wrong answer
#      — reclassify the gap as DisplayOnly — loud instead of merely discouraged.
#
# NOTE for anyone editing src/core/dst_invariants.ail: the guards count lines
# matching `^  [|=]` between the type header and the following blank line. A
# constructor wrapped onto a continuation line, or a blank line inside the
# declaration, changes the count without changing the type — the same shape as
# event_vocabulary's `variant: "` counter.
.PHONY: invariants
invariants:
	@set -eu; \
	ailang run --caps IO --entry main scripts/dst/invariants_dst.ail < /dev/null; \
	fam_t=$$(awk '/^export type InvariantFamily/,/^$$/' src/core/dst_invariants.ail | grep -c '^  [|=]'); \
	fam_l=$$(awk '/^export pure func all_families\(\)/,/^}/' src/core/dst_invariants.ail | grep -oE '[A-Z][A-Za-z]+' | grep -v '^InvariantFamily$$' | wc -l); \
	if [ "$$fam_t" -ne "$$fam_l" ]; then \
		echo "FAIL: InvariantFamily declares $$fam_t variants and all_families() lists $$fam_l."; \
		echo "      A family with no entry in all_families() is a D7 obligation that no"; \
		echo "      coverage check iterates — the suite would report full family coverage"; \
		echo "      while one obligation had no instrument behind it."; \
		exit 1; \
	fi; \
	vio_t=$$(awk '/^export type Violation/,/^$$/' src/core/dst_invariants.ail | grep -c '^  [|=]'); \
	vio_s=$$(awk '/^pure func sample_violations\(\)/,/^}/' src/core/dst_invariants.ail | grep -oE '[A-Z][A-Za-z]+\(' | wc -l); \
	if [ "$$vio_t" -ne "$$vio_s" ]; then \
		echo "FAIL: Violation declares $$vio_t constructors and sample_violations() builds $$vio_s."; \
		echo "      violation_rule/_family/_message are total matches, so a new rule is a"; \
		echo "      compile error there — but one missing from sample_violations() is never"; \
		echo "      checked for a distinct rule id, a family, or a message naming it."; \
		exit 1; \
	fi; \
	echo "  ✓ $$fam_t InvariantFamily variants == $$fam_l in all_families(); $$vio_t Violation constructors == $$vio_s sampled"; \
	if ailang test src/core/dst_invariants.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ src/core/dst_invariants.ail"; \
	else \
		echo "  ✗ src/core/dst_invariants.ail"; \
		ailang test src/core/dst_invariants.ail < /dev/null 2>&1 | tail -20; \
		exit 1; \
	fi

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
	: "The pattern is anchored to the IMPORT FORM, not the bare string 'std/rand'."; \
	: "WI-A13 found this red at baseline: A12 (cluster 6) wrote the bare-string"; \
	: "grep, then A10 (cluster 5) landed on top of it with a ForbiddenCapability"; \
	: "whose instrument PROSE names std/rand while describing this very check, so"; \
	: "the artifact documenting the guard tripped the guard. --keep-going hid it."; \
	: "An import is the only way an AILANG module can reach std/rand, so anchoring"; \
	: "to '^import std/rand' loses no coverage and stops the guard firing on text"; \
	: "that merely mentions it. This is the same precision the fault_catalogue"; \
	: "target already needed for its own tripwire."; \
	n=$$(grep -l '^import std/rand' src/core/*.ail 2>/dev/null | wc -l); \
	if [ "$$n" -ne 0 ]; then \
		echo "FAIL: $$n driver module(s) reach std/rand. src/core/*.ail had none when WI-A12"; \
		echo "      routed its effect classes, so an ambient RNG has appeared and is un-routed."; \
		echo "      D1 names an ambient RNG as a prohibited hiding place for world state."; \
		echo "      (src/core/test/ is deliberately excluded: dst_gen.ail is a seeded GENERATOR,"; \
		echo "       which is explicit randomness outside the driver, not an ambient read in it.)"; \
		grep -l '^import std/rand' src/core/*.ail; \
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
#      c2_finalize. c2_finalize holds the sole terminal record literal, so more
#      than one means a terminal path has been added that appends no RunSummary
#      — the exact regression D6.1 exists to prevent, and one that no per-path
#      test can catch for a path nobody wrote a test for.
#
#      WI-A13 stage 2 ANCHORED THIS GUARD, per cluster 7's correction 1. It was
#      a bare-token `grep -c` that counted comment lines too, so session.ail
#      carried a standing obligation to circumlocute around its own guard's
#      pattern in prose — the same landmine that turned `make world_state` red
#      for two clusters when A10 documented the randomness guard it tripped.
#      The pattern is now anchored to a line whose record literal is not
#      preceded by a dash, which no AILANG comment line can satisfy. Verified in
#      both directions: 1 at HEAD, and 3 against a file with two deliberately
#      added bypassing terminal returns in both plausible shapes, so the
#      tightening costs no coverage.
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
	n=$$(grep -c '^[^-]*{ result:' src/core/session.ail); \
	if [ "$$n" -ne 1 ]; then \
		echo "FAIL: $$n terminal record literals in session.ail, expected 1 (c2_finalize). A terminal return is bypassing the finalizer — see D6.1."; \
		grep -n '^[^-]*{ result:' src/core/session.ail; \
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

# ---------------------------------------------------------------------------
# ADR-001 D5 obligation 2, classifier 2: ExtPorts fields that drop a cursor D1
# requires threaded, and their call sites.
#
# Membership is DERIVED from D5's criterion on every run -- from the ExtPorts
# record, the core Ports record, and the extension-side bridge -- and never read
# from a list. D5's own enumeration named `ai_step` alone; WI-A12 falsified that
# by state-threading `Ports.tool_exec` and `Ports.env_get`, and a classifier
# built to the list would have reported a clean routing audit over two dropped
# cursors. Re-derive after any change to either port record or to the bridge.
#
# `ext_call_inventory_selftest` runs the fixture suite: one fixture per
# indirection form the ADR places outside the matcher boundary, each of which
# must be reported unresolved, plus a control that must resolve. All five
# type-check, so the forms are real rather than illustrative.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# ADR-001 D4 clause 3, WI-A5: the site-to-hook attribution table.
#
# Two checks, because the fixtures and the artifact fail differently:
#
#   1. the fixture suite (scripts/dst/attribution_table_dst.ail) — every
#      rejecting shape, both directions of the empty-intersection rule, and the
#      set-completeness fixture that a row-shape validator would accept;
#   2. an ANCHOR check tying each row to the source it describes.
#
# (2) is not redundant with the staleness rule. Staleness compares recorded
# revisions and can only say "something changed"; this says WHICH row no longer
# describes its site. It deliberately does NOT compare `table_source_revision()`
# against git HEAD — the table is bound to the revision its rows were MEASURED
# at, and every later commit that touches nothing it cites leaves it valid.
# Comparing to HEAD would make the artifact stale on every unrelated commit,
# which trains people to bump the field without re-measuring.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# ADR-001 D1, WI-A11: the classifier-2 predicate documentation check.
#
# An anchor-set DRIFT check, not a containment check, and the choice is forced.
# The ADR records that its normative statements of the rule are "substantively
# aligned, not word-identical -- the six use six formulations", so a check
# requiring one canonical sentence at all six is RED ON THE UNMUTATED ADR by
# construction. Canonicalising them is six amendments this project does not
# budget and would destroy what each formulation carries.
#
# Every mention in the ADR's normative region is recorded with a paragraph hash,
# a classification (anchor = states the rule, reference = applies it) and a named
# reviewer. It fails when a recorded passage's text changes without a re-accepted
# hash, or when a mention appears that no record accounts for.
#
# Passages are matched BY HASH; the recorded line is a hint and a stale hint is
# reported, never failed on. A line-keyed check would go red on every unrelated
# ADR edit, which trains people to re-baseline it without reading.
# ---------------------------------------------------------------------------
.PHONY: predicate_anchors
predicate_anchors:
	@python3 tools/predicate-anchors/check.py

.PHONY: attribution_table
attribution_table:
	@ailang run --caps IO --entry main scripts/dst/attribution_table_dst.ail < /dev/null
	@fail=0; \
	check() { \
	  if sed -n "$$2p" "$$1" | grep -q -- "$$3"; then \
	    echo "  ✓ $$1:$$2 still $$4"; \
	  else \
	    echo "  ✗ $$1:$$2 no longer $$4 — the attribution table describes a site that moved"; \
	    echo "      expected to find: $$3"; \
	    echo "      actual line:      $$(sed -n "$$2p" "$$1")"; \
	    fail=1; \
	  fi; \
	}; \
	echo "attribution anchors:"; \
	check src/core/ext/runtime.ail 190 'now()' "the ambient clock read attributed to test_dummy"; \
	check src/core/tool_phase.ail 286 'is_scratchpad_tool_name' "the mixed guard"; \
	check src/core/tool_phase.ail 287 'exec_scratchpad_cell_ws' "the call attributed to scratchpad"; \
	check src/core/session.ail 807 'now()' "the S2 un-routed ext clock (declared UNROUTED core)"; \
	check src/core/test/stub_step.ail 161 'now()' "live_ports' real clock (declared UNROUTED core)"; \
	for l in 948 1053 2290 2400; do \
	  check src/core/session.ail $$l 'clock_now' "a routed core clock site"; \
	done; \
	check src/core/tool_phase.ail 342 'clock_now' "the FIFTH routed core clock site (D4's table says four)"; \
	[ "$$fail" -eq 0 ] || exit 1
	@ailang test src/core/dst_attribution_table.ail > /dev/null && echo "  ✓ src/core/dst_attribution_table.ail"

.PHONY: ext_call_inventory ext_call_inventory_selftest
ext_call_inventory:
	@python3 tools/ext_call_inventory/derive.py

ext_call_inventory_selftest:
	@python3 tools/ext_call_inventory/derive.py --self-test
