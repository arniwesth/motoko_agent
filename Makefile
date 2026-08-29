PROFILE ?= $(if $(MOTOKO_CONFIG),$(MOTOKO_CONFIG),default)
QWEN36_COMPACTION_LIVE_TASK ?= Run a long tool-heavy compaction calibration task that repeatedly grows conversation history and continues after compaction.
QWEN36_COMPACTION_HEAVY_TASK ?= Run a compaction stress calibration. Do not stop early. Perform at least 1000 sequential tool-heavy phases. In each phase, read several large source files or documentation files in full, run broad searches over the repository, and keep a running phase log in your response. Prefer files under src/, packages/, .agent/projects/, scripts/, and design_docs/. After every 5 phases, restate the important accumulated findings so far. Continue until you have made at least 1000 model turns or until the runtime compacts. If context pressure or compaction occurs, continue the task and explicitly report that you continued after it. STEP-GATE (mandatory): After EVERY ordinary tool call you make (ReadFile, Search, WriteFile, EditFile, BashExec, RunTests, and any Ctx* or exa_* extension tool), you MUST immediately also call the MotokoRuntimeStatus tool in the same response/turn. Inspect its returned 'current_step' (number of steps executed so far) and 'step_budget'. If current_step is still below the target steps, you MUST continue: do NOT stop, do NOT emit a final-only prose answer, and do NOT declare the task complete. Instead, make further tool calls (read more files, run more searches, keep the running phase log) and advance to the next step. Only when current_step has reached the target of 1000 steps (or the runtime reports compaction) may you emit a final summary. Treat the MotokoRuntimeStatus step count as the authoritative progress indicator and keep calling it until the target is met; never assume you are finished based on a round count of phases alone.

codex:
	clear
	codex --yolo

claude:
	clear
	claude --dangerously-skip-permissions --model claude-opus-5

install_codex:
	curl -fsSL https://chatgpt.com/codex/install.sh | sh	

install_claude:
	curl -fsSL https://claude.ai/install.sh | bash

prune:
	docker system prune -a

# ---------------------------------------------------------------------------
# reMarkable 2 publishing (tools/rmsend): md -> pdf/epub -> cloud -> tablet.
#
# These targets are a thin front for the tool; `bun tools/rmsend/rmsend.ts
# --help` documents every flag, and RM_FLAGS forwards any of them.
#
# One-time setup in a fresh container:
#   make remarkable_install      # rmapi + pandoc + typst into ~/.local/bin
#   make remarkable_login        # paste the 8-char code from my.remarkable.com
#
# The device token lands in .remarkable/rmapi.conf (gitignored, inside the
# bind-mounted workspace) so a container rebuild does NOT re-pair.
#
# Send:
#   make remarkable FILE=notes.md
#   make remarkable FILE=notes.md DIR=/Motoko/Research FORMAT=epub
#   make remarkable FILE=.agent/research RM_FLAGS=--toc     # a whole directory
#   make remarkable_branch                                  # this branch's docs
# ---------------------------------------------------------------------------
RMSEND := bun tools/rmsend/rmsend.ts
DIR ?= /Motoko
FORMAT ?= pdf

.PHONY: remarkable_install remarkable_login remarkable remarkable_ls remarkable_branch
remarkable_install:
	@$(RMSEND) install $(RM_FLAGS)

remarkable_login:
	@$(RMSEND) login

remarkable:
	@test -n "$(FILE)" || { echo "usage: make remarkable FILE=path/to/notes.md [DIR=/Motoko] [FORMAT=pdf|epub]"; exit 1; }
	@$(RMSEND) send --dir "$(DIR)" --format "$(FORMAT)" $(RM_FLAGS) $(FILE)

remarkable_ls:
	@$(RMSEND) ls $(DIR)

remarkable_branch:
	@$(RMSEND) branch --dir "$(DIR)" --format "$(FORMAT)" $(RM_FLAGS)

# ---------------------------------------------------------------------------
# GitHub PR ops (tools/pr): template -> staged body -> gh pr create -> number
# written back into .agent/github/prs/<remote>-<n>/body.md.
#
# The artifact on disk is the source of truth; GitHub is transport. See
# .agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md D4.
#
#   make pr_draft     # stage a body, with Changes and Governing docs filled in
#   <edit it>         # Summary, Predicted outcome and Test evidence are yours
#   make pr           # publish and write the number back
#
# `make pr` drafts first if you skipped pr_draft, and refuses to publish while
# any <!-- TODO --> field is unfilled. It is safe to re-run: it adopts the PR
# already open for the branch rather than opening a second one.
#
# Identity: these act as YOU, via `gh auth login` (ADR-001 D1 — a human decided
# to open the PR). `make pr_whoami` reports which account that resolves to.
#
#   make pr BASE=develop REMOTE=sunholo PR_FLAGS=--dry-run
# ---------------------------------------------------------------------------
PR_CLI := bun tools/pr/pr.ts
BASE ?= main
REMOTE ?= origin

.PHONY: pr pr_draft pr_whoami
pr_draft:
	@$(PR_CLI) draft --base "$(BASE)" --remote "$(REMOTE)" $(PR_FLAGS)

pr:
	@$(PR_CLI) create --base "$(BASE)" --remote "$(REMOTE)" $(PR_FLAGS)

pr_whoami:
	@$(PR_CLI) whoami $(PR_FLAGS)

# File an issue as the bot, mirroring `pr` (ADR-001 C9 / D5). The draft in
# .agent/github/staging/issues/<slug>/body.md is the source of truth, GitHub is
# transport, and the issue number is written back into frontmatter on publish.
#
#   make issue_draft --title="Step budget wipes history"   # stage a body
#   make issue                                        # publish (as motoko-agent)
#   make issue --title="…"                             # draft-if-needed + publish
#   make issue PR_FLAGS="--dry-run"                   # preview, write nothing
#   make issue_whoami PR_FLAGS=--as-bot               # → motoko-agent
#   make issue REMOTE=sunholo PR_FLAGS=--as-operator  # bot cannot push to sunholo
ISSUE_CLI := bun tools/pr/issues.ts

.PHONY: issue issue_draft issue_whoami
issue_draft:
	@test -n "$(TITLE)" || { echo "usage: make issue_draft --title=\"what breaks and why\""; exit 1; }
	@$(ISSUE_CLI) draft --remote "$(REMOTE)" --title "$(TITLE)" $(PR_FLAGS)

issue:
	@$(ISSUE_CLI) create --remote "$(REMOTE)" $(if $(TITLE),--title "$(TITLE)") $(PR_FLAGS)

issue_whoami:
	@$(ISSUE_CLI) whoami $(PR_FLAGS)

# Fetch PR comments from every GitHub remote into the gitignored cache, then
# append a `pending` record for each one not seen before. Acts as the BOT
# (ADR-001 D1: the sync is an action the pipeline produces). It only adds
# facts -- it never rewrites a status, rank, reason or artifact link, and an
# edited comment is flagged `stale: true` alongside its disposition rather
# than reverting it. Safe to re-run; a run that finds nothing new is a no-op.
#
#   make pr_sync                                  # both remotes, open PRs
#   make pr_sync PR_FLAGS="--dry-run"             # fetch and report only
#   make pr_sync REMOTE=sunholo PR_FLAGS="--pr 3 --state all"
PR_SYNC := bun tools/pr/sync.ts

.PHONY: pr_sync
pr_sync:
	@$(PR_SYNC) $(if $(filter-out origin,$(REMOTE)),--remote "$(REMOTE)") $(PR_FLAGS)

# Work the queue pr_sync fills. This is the ONLY thing that changes a judgment
# (ADR-001 D3); sync may only add facts. Automation stays at degree 1 -- every
# rank, dismissal and response here is supplied by whoever runs it, and
# `pr_respond` will not publish without POST=1.
#
# Every target below takes ONE of these, whichever you have to hand -- they all
# resolve to the same comment, and the resolution is printed before anything acts:
#
#   PR=76                                             the PR number
#   FILE=.agent/github/prs/origin-76/response-*.md    the artifact path (tab-completes)
#   ID=5021529142                                     the comment id itself
#
# A PR holding more than one comment refuses and lists them rather than guessing.
#
#   make pr_list                                      # every PR: age, ticket, queue
#   make pr_list PR_FLAGS="--stale 60"                # quiet for 60+ days
#   make pr_queue                                     # what needs attention
#   make pr_show PR=76                                # the full comment
#   make pr_set PR=76 PR_FLAGS="--status ranked --rank high"
#   make pr_set PR=76 PR_FLAGS='--status dismissed --reason "superseded by #154"'
#   make pr_review PR=76                              # comment + reply in one file
#   make pr_respond PR=76                             # preview
#   make pr_respond PR=76 POST=1                      # publish, as the bot
PR_LOOP := bun tools/pr/loop.ts
# Whichever of PR= / FILE= / ID= was given; loop.ts resolves the form.
PR_TARGET = $(or $(ID),$(FILE),$(PR))

.PHONY: pr_list pr_queue pr_show pr_set pr_review pr_respond
pr_list:
	@$(PR_LOOP) list $(PR_FLAGS)

pr_queue:
	@$(PR_LOOP) queue $(PR_FLAGS)

pr_show:
	@test -n "$(PR_TARGET)" || { echo "usage: make pr_show PR=<n> | FILE=<path> | ID=<comment_id>"; exit 1; }
	@$(PR_LOOP) show "$(PR_TARGET)" $(PR_FLAGS)

pr_set:
	@test -n "$(PR_TARGET)" || { echo "usage: make pr_set PR=<n> PR_FLAGS=\"--status ranked --rank high\""; exit 1; }
	@$(PR_LOOP) set "$(PR_TARGET)" $(PR_FLAGS)

pr_review:
	@test -n "$(PR_TARGET)" || { echo "usage: make pr_review PR=<n> | FILE=<path> | ID=<comment_id>"; exit 1; }
	@$(PR_LOOP) review "$(PR_TARGET)" $(PR_FLAGS)

# POST must be exactly 1. `$(if $(POST),...)` tests non-empty, not truth, so
# POST=0 and POST=no both published -- a gate that reads as "off" and fires.
pr_respond:
	@test -n "$(PR_TARGET)" || { echo "usage: make pr_respond PR=<n> [POST=1]"; exit 1; }
	@if [ -n "$(POST)" ] && [ "$(POST)" != "1" ]; then \
		echo "pr_respond: POST must be exactly 1 to publish (got '$(POST)'). Omit POST to preview."; exit 1; \
	fi
	@$(PR_LOOP) respond "$(PR_TARGET)" $(if $(filter 1,$(POST)),--post) $(PR_FLAGS)

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

# ADR-001 D1's substrate gate (WI-C2), asserted clause by clause.
#
# D1 requires, before streaming trace parity can be claimed and therefore before
# the DST name is earned, that the recorded-stream API be PINNED and a direct
# positive version of the spike prove five properties: immediate projection,
# exact returned-log parity, success, partial-stream-then-error, and no
# duplicate delivery. Five clauses, five rows — a conjunction that passes says
# nothing about which clause held.
#
# WHY THIS TARGET CANNOT USE --ai-stub, which every other target here does.
# Measured, not assumed: the stub is a provider WITHOUT native streaming, so per
# std/ai's own contract it fires the callback exactly twice — one
# ContentDelta(full_text), one Usage — and it always returns Ok. On two chunks,
# ordering is barely exercised and duplication not at all; partial-
# stream-then-error cannot be produced at all. A stub-driven pass would look
# identical to a real one in the output, which is the shape this milestone
# exists to stop. The target therefore stands up a real native SSE endpoint on
# loopback and points AILANG's OpenAI provider at it via OPENAI_BASE_URL.
#
# It needs python3 and a free loopback port ($$PORT, default 8819). No network
# egress and no API key: OPENAI_API_KEY is a literal placeholder the fixture
# server ignores.
.PHONY: recorded_stream
recorded_stream:
	./scripts/dst/run_recorded_stream_probe.sh

# ADR-001 D6.4's stream-parity obligation (WI-C3), held on a RUN.
#
# TWO GATES, and they cover different halves — the split is measured rather than
# claimed, and it is the item's main finding.
#
#   1. `stream_parity_dst.ail`. The first thing in the tree that drives the real
#      driver, bridges what it returns into an `ExecutionUnderTest`
#      (`src/core/dst_execution.execution_of`), and evaluates all sixteen D7
#      families over it. Before WI-C3 the whole suite had ONE construction site,
#      a hand-authored fixture. Both sides of the parity comparison derive from
#      `ProviderExchange.emissions`, because that is the only in-process
#      observation of the stream, so what this proves is that the driver carries
#      the trace and the emission witness forward TOGETHER on every branch after
#      the provider call.
#   2. `run_stream_parity_wire.sh`. The wire against the trace. The wire is what
#      the CALLBACK projected during the call; the trace is what the driver
#      APPENDED from the log the provider returned. Different producers, so this
#      is the half D6.4 actually names — and it is the only one that can see a
#      projection which disagrees with the returned log.
#
# MEASURED: a de-duplication injected into `append_stream_delta` — the callback
# dropping adjacent repeats — leaves gate 1 fully GREEN and turns gate 2 red on
# count, order and fixture adequacy. Neither gate subsumes the other, and gate 1
# alone would ship a green check over the defect D6.4 exists to find.
.PHONY: stream_parity
stream_parity:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
	  --entry main scripts/dst/stream_parity_dst.ail < /dev/null | grep -v '^{'; \
	./scripts/dst/run_stream_parity_wire.sh

# WI-D2. D6.4's GENERAL obligation — acceptance row 7's third conjunct — as a
# wire-against-trace comparison over every Logical variant `d64_gap_register()`
# does not excuse.
#
# TWO PRODUCERS, named as S16 requires: the wire is written by `ledger_emit` at
# the site the event happened; the returned trace is written by `ledger_append`
# in the driver and printed after the run. In process both derive from one bound
# value, which is why the comparison is here and not in the .ail suite — WI-C3
# built `run_stream_parity_wire.sh` for exactly this reason on one variant, and
# WI-D1's M5 measured what an in-process-only parity check is worth: completely
# green over a wire that was leaking ten retries.
#
# THE COUPLING THAT MAKES THE REGISTER REAL: the required set is
# `event_vocabulary()` minus `d64_gap_register()`, read out of the run rather
# than restated here. Removing a name from the register is what makes this gate
# demand its append, so a register shrunk without the production change is red —
# which the two in-process pins cannot see, because both of them compare the
# register against the `reaches_trace_today` SURVEY and the survey is the claim.
.PHONY: ledger_parity
ledger_parity:
	./scripts/dst/run_ledger_parity_wire.sh

# The gate for motoko_agent#160. Two tiers, both using a deliberately LOW
# `--max-recursion-depth` as the instrument, because AILANG has no depth counter
# to read and no tail-call elimination: anything on the driver's per-step path
# that traverses accumulated state costs a frame per record and turns the
# maximum length of a session into a function of the ceiling.
#
# Tier 0 is a unit probe over 8,192 constructed records — precise and drift-free,
# guards one function. Tier 1 runs the REAL driver out of process at pinned
# per-seed ceilings — general, catches any new traversal, but the pins move when
# per-step frame cost legitimately changes. The script's header carries the pin
# table, the measured fault-present depths that justify the headroom, and the
# rule that bumping a pin is a deliberate act with a recorded reason.
#
# SHOWN TO FIRE, which is the house caveat this project puts on every guard:
# against the pre-fix driver all four rows go red; against HEAD all four are
# green. That is a measurement of a real regression, not a hypothetical.
.PHONY: depth_canary
depth_canary:
	./scripts/dst/run_depth_canary.sh

phase_c_l1: compaction_dst
	ailang run --caps IO --entry main scripts/dst/phase_c_l1_scenarios.ail
	ailang run --caps IO --entry main scripts/dst/phase_c_approval_protocol.ail
	ailang run --caps IO,Env,Clock,FS,Trace --entry main scripts/dst/phase_c2_wiring_scenarios.ail

# WI-C5. D5's declared-versus-performed detector, which D5 itself names and
# records as unavailable. Two producers, and S16 requires them named:
#
#   DECLARED   the effect row in packages/motoko-ext-abi/types.ail and on the
#              extension's binding site — a static annotation a human wrote,
#              read out of source by the runner's own grep.
#   PERFORMED  the exit status of `ailang run --caps <row minus X>`. AILANG
#              traps a capability only when an effect operation is actually
#              EVALUATED (src/core/ports.ail:406), so a completed run witnesses
#              that the operation was not evaluated. Out of process, produced by
#              the interpreter, and nothing in the extension can influence it.
#
# Neither derives from the other, which is the entire point: WI-C3's in-process
# parity gate stayed green through the exact defect it existed to find because
# both of its sides came from one channel.
#
# THE HEADLINE MEASUREMENT: compose's on_budget_plan declares ! {Env, FS} and
# performs NEITHER. That gap is why D5's declared-row rule blocks an install
# that the extension's behaviour does not require blocking.
#
# Every subject is paired with a control that must DIE on the named capability,
# because a subject completing with a capability withheld is otherwise
# indistinguishable from a harness that never reached the hook — cluster 4's
# C1b defect, and the same vacuity `make world_state` spends a second run to
# close.
.PHONY: declared_vs_performed
declared_vs_performed:
	./scripts/dst/run_declared_vs_performed.sh

# WI-C5. `routing_violation_at`'s production call site, driven through the
# guarded dispatch rather than called directly — an exclusion checked only at
# load time is an exclusion nothing enforces at dispatch.
#
# The fixture is SYNTHETIC and the script says so on every run: no profile in
# this tree can reach the guard today, because driver_only installs nothing and
# no extension is installable while ExtensionHooks.on_budget_plan carries the
# ABI's closed ! {Env, FS} row. These rows establish the mechanism, not that a
# shipping profile is protected by it.
# The recipe is bash for `pipefail`: without it the pipeline reports grep's
# status, and a type error in the script -- which `ailang run` prints AFTER
# its "✓ Running" preamble and exits 1 on -- went green here from B8 until it
# was noticed. `grep -v` exits 1 on no output, so `|| true` keeps only that.
.PHONY: hook_guard
hook_guard: SHELL := /bin/bash
hook_guard:
	@set -euo pipefail; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
	  --ai-stub --entry main scripts/dst/hook_guard_dst.ail < /dev/null \
	  | { grep -v 'STRICT_FALLBACK\|^  ' || true; }

# ---------------------------------------------------------------------------
# The sweep. Every target below is independent of every other -- the one
# exception is `phase_c_l1: compaction_dst`, which make resolves once -- so the
# list runs in parallel.
#
# ORDERED LONGEST-FIRST, and the order is load-bearing rather than cosmetic.
# make hands work out in listed order, so a long target listed late starts late
# and stretches the makespan past the point where the short ones have drained.
# Measured serially at v0.33.0 (seconds): test_coverage 214, declared_vs_
# performed 75, terminal_trace 74, smoke_parity 45, profile_definition 31,
# smoke_driver 26, corpus_pr 23, strict_replay 21, world_state 19; the remaining
# 32 are under 16 each and 30 of them are under 10. Four targets are 60% of the
# sweep. Re-derive after adding a target that lands near the top -- an
# out-of-place SHORT target costs nothing, an out-of-place LONG one costs its
# own runtime.
#
# THE CACHE LANES BELOW ARE WHAT MAKE THE PARALLELISM PAY. AILANG writes its
# compile cache to `<dir-of-root-source>/.ailang/cache/compile/`, so without
# them every `scripts/dst/*.ail` target shares ONE cache directory, and
# `CacheStore.Save()` (ailang internal/pipeline/cache_store.go) rewrites the
# WHOLE manifest with a plain os.WriteFile -- no lock, no temp+rename. N
# concurrent processes therefore erase each other's freshly-cached modules and
# the cache degrades toward cold as N rises. `AILANG_CACHE_DIR` is AILANG's own
# documented remedy for exactly this. Measured end to end on 8 cores: 688s
# serial, 329s at -j8 sharing the cache, 289s at -j8 with lanes, 196s once
# test_coverage's inner fan-out is unblocked too (3.5x).
#
# This is a THROUGHPUT change and never a verdict change: AILANG's cache key is
# content-addressed over (format version, compiler version, source hash, dep
# interface digests) with no compile flags, so concurrent writers write
# byte-identical artifacts and a torn read fails its decode and falls through to
# a recompile. The race has always cost time and never an answer.
#
# The lanes are disk, not memory: ~1.7G under .ailang/lane (gitignored). Delete
# it freely; it refills.
# ---------------------------------------------------------------------------
DST_JOBS ?= $(shell nproc 2>/dev/null || echo 4)
DST_LOG  ?= .ailang/dst-last.log

DST_TARGETS := test_coverage declared_vs_performed terminal_trace smoke_parity \
  profile_definition smoke_driver corpus_pr strict_replay world_state \
  corpus_rotating driver_plus_compose driver_only seeded_generator \
  event_vocabulary phase_c_l1 recorded_stream driver_plus_no_ops \
  ext_hook_scope_selftest invariants run_report discovery program_persistence \
  compaction_dst fault_catalogue ext_ambient_inventory_selftest \
  ext_ambient_inventory ext_call_inventory ext_call_inventory_selftest \
  conformance stream_parity latency_pair test_coverage_selftest \
  execution_program attribution_table profile_coverage compose_live_exec \
  ledger_parity dst_seeded hook_guard dst_l2 predicate_anchors depth_canary \
  registry_multiplicity

# corpus_pr IS NOT PARALLELISABLE, AND THE REASON IS ITS PASS CONDITION.
#
# Its final check reads the target's own WALL CLOCK and fails it against
# `pr_target_ceiling_ms()` (80 s), because D11 delegates seed counts to measured
# CI cost and the measurement needs a gate rather than a comment. A wall-clock
# gate measures the MACHINE'S LOAD as much as the target: run it alongside seven
# other AILANG processes and it reports 96 s, cold-cache 203 s, against a
# ceiling derived on a quiet machine. Neither number is a fact about the corpus.
#
# So it runs ALONE, before the fan-out, and on the DEFAULT cache rather than a
# lane -- which is exactly the condition the ceiling was measured under, and the
# only condition under which the check means what it says.
#
# Raising the ceiling to accommodate contention would be the wrong repair twice
# over: the target itself says to re-measure `measured_ms_per_seed()` and move
# the ceiling WITH it, since the seed minimums are arithmetic over that constant.
# Any future target that gates on elapsed time belongs on this line, not below.
DST_TIMED_TARGETS := corpus_pr
DST_PARALLEL_TARGETS := $(filter-out $(DST_TIMED_TARGETS),$(DST_TARGETS))

# Three targets are deliberately NOT given a lane.
#
#   ext_ambient_inventory{,_selftest} READ the compile cache rather than merely
#   writing it: tools/ext_ambient_inventory/derive.py walks src/, packages/ and
#   scripts/ for */cache/compile/modules/std__*/iface.json. Redirecting the
#   cache out of those trees leaves it nothing to read -- it fails loudly rather
#   than passing vacuously, but it fails. Its own fifteen `ailang check` calls
#   already write to per-extension directories, so it contends little anyway.
#
#   test_coverage runs its OWN per-worker lanes inside derive.py (see
#   TEST_COVERAGE_JOBS below) and must not also be pinned to one outer lane.
DST_LANE_TARGETS := $(filter-out ext_ambient_inventory ext_ambient_inventory_selftest test_coverage $(DST_TIMED_TARGETS),$(DST_TARGETS))
$(DST_LANE_TARGETS): export AILANG_CACHE_DIR = $(CURDIR)/.ailang/lane/$@

# Both phases run even if the first reports failures, and the exit status is the
# worse of the two -- `make dst` must still exit non-zero for CI, and a red
# target in the fan-out must not hide the timed one behind it.
# Targets known to be red, named here ONLY so the closing summary can say "no
# new failures" instead of leaving a reader to remember them. It waives
# nothing: the exit code is propagated untouched and a sweep with only these
# red still exits 2. scripts/dst/sweep_summary.sh also reports a target on this
# list that PASSES, so the list cannot outlive the failure it describes.
# Empty at HEAD: the D22 pair (test_coverage, test_coverage_selftest --
# `prompts_test.ail` 0/6 and a `stale_skip_record`) has passed since the skip
# record was brought current, and the summary's reverse check said to drop it.
DST_KNOWN_RED :=

# bash for `pipefail` alone: the phases are piped through `tee` so the run is
# both watchable and logged, and without pipefail the pipeline would report
# tee's status and every failure would exit 0.
.PHONY: dst
dst: SHELL := /bin/bash
dst:
	+@set -o pipefail; rc=0; start=$$(date +%s); \
	mkdir -p $$(dirname $(DST_LOG)); : > $(DST_LOG); \
	timed="$(strip $(DST_TIMED_TARGETS))"; par="$(strip $(DST_PARALLEL_TARGETS))"; \
	if [ -n "$$timed" ]; then \
		$(MAKE) --no-print-directory --keep-going $$timed 2>&1 | tee -a $(DST_LOG) || rc=$$?; \
	fi; \
	if [ -n "$$par" ]; then \
		$(MAKE) --no-print-directory -j$(DST_JOBS) --output-sync=target --keep-going $$par 2>&1 | tee -a $(DST_LOG) || rc=$$?; \
	fi; \
	DST_KNOWN_RED="$(DST_KNOWN_RED)" DST_REQUESTED="$$timed $$par" \
	  ./scripts/dst/sweep_summary.sh $(DST_LOG) $$rc $$(( $$(date +%s) - start )) $(DST_JOBS); \
	exit $$rc

# What `make dst` runs, expanded BY MAKE. tools/test_coverage/derive.py's
# reachability guard used to regex the `dst:` recipe for literal target names,
# which reported the target unreachable the moment the list moved into a
# variable -- blind rather than wrong, the same failure its own
# `make_invocations()` comment already records once. Asking make removes the
# guard's dependence on how the list happens to be spelled.
.PHONY: dst_target_list
dst_target_list:
	@echo $(DST_TIMED_TARGETS) $(DST_PARALLEL_TARGETS)

# D5's coverage floor and per-extension hook disclosure (WI-A6). Two checks:
#
#   1. The fixture PROFILES. Every rejecting shape D5 names, asserted to be
#      rejected BY ITS RULE rather than merely rejected — a fixture that trips
#      an unrelated check is green while testing nothing. Plus the two shapes
#      that must load: driver_only's empty install list (vacuous, per P4) and a
#      profile excluding only the one GATED hook.
#
#   2. A STRUCTURAL GUARD that the kind enumeration still matches the ABI.
#      `all_capability_kinds()` (B3; `all_hook_slots()` until B8) is
#      hand-written and AILANG has no constructor enumeration on the pin, so a
#      ninth ABI kind could be added and left out of it while every check in
#      the module still passed — an artifact that validates while incomplete,
#      which is the exact failure S1 names for constructed artifacts. The ABI
#      side is the `Capability` variant count once B8 lands, and the record's
#      `on_*` field count until then (both shapes are accepted during B3–B7);
#      the AIL side is PRINTED by `print_capability_kind_count`, because make
#      cannot evaluate AILANG and a second hand-written 8 would pin the
#      enumeration to itself. Portable: `[[:space:]]`, no `\s`.
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
	abi=packages/motoko-ext-abi/types.ail; \
	producer="type Capability variants"; \
	n=$$(awk '/^export type Capability/,/^[[:space:]]*$$/' $$abi | grep -cE '^[[:space:]]*[=|][[:space:]]*[A-Z][A-Za-z0-9_]*[[:space:]]*\('); \
	k=$$(ailang run --caps IO --entry print_capability_kind_count scripts/dst/profile_coverage_dst.ail < /dev/null | tail -1 | tr -d '[:space:]'); \
	if [ "$$n" -ne "$$k" ] || [ "$$k" -lt 1 ]; then \
		echo "FAIL: the ABI declares $$n capability kinds ($$producer), but"; \
		echo "      src/core/dst_profile_coverage.ail enumerates $$k in all_capability_kinds()."; \
		echo "      A kind has been added or removed and the coverage artifact does not know"; \
		echo "      about it, so every profile would validate while its disclosure was"; \
		echo "      incomplete (D5/D6). Count KINDS, not instances: the AIL side is printed by"; \
		echo "      print_capability_kind_count because make cannot evaluate AILANG."; \
		exit 1; \
	else \
		echo "  ✓ all_capability_kinds() enumerates all $$n ABI capability kinds ($$producer)"; \
	fi; \
	ailang test src/core/dst_profile_coverage.ail > /dev/null && echo "  ✓ src/core/dst_profile_coverage.ail"

# ADR-001 Phase B, B4: multiplicity validation at the registration boundary.
# `src/core/ext/registry_normalize.ail` is the ONE host-owned place the D3
# rules live (second ToolPolicy/SolverJudge rejected; ToolProvider names
# disjoint per extension), with D4 (fold-kind N>1) and D7 (empty registration)
# each behind a single named constant because both are OPEN. The fixtures are
# one mutation each from a clean registration, every rejection asserted BY
# RULE with id, variant and list position; the two open rows print which
# reading of the constant they measured. Since B8 the module imports the ABI's
# `Capability`, and the generated registry (make registry_gen) calls
# `normalize_registration` (D10).
.PHONY: registry_multiplicity registry_gen registry_gen_check
# ABI 6.0 registry generator (ADR-001 Phase C, D10). Project-local: the
# upstream `ailang generate-extension-registry` (v0.33.0) still emits the 5.x
# record shape, so it must not be run in this tree. `registry_gen` rewrites
# src/core/ext/registry_generated.ail from ailang.toml [extensions];
# `registry_gen_check` fails if the committed file drifts from the generator.
registry_gen:
	@python3 tools/ext_registry_gen/generate.py

registry_gen_check:
	@python3 tools/ext_registry_gen/generate.py --check

registry_multiplicity:
	@ailang run --caps IO --entry main scripts/dst/registry_multiplicity_dst.ail < /dev/null
	@ailang test src/core/ext/registry_normalize.ail > /dev/null && echo "  ✓ src/core/ext/registry_normalize.ail"

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
# WI-D26: the LIVE half of the routed subprocess seam, and it is a SEPARATE
# target from `discovery` on S14's grounds rather than for convenience.
#
# `discovery`'s `compose_check_scenario` drives compose's routed `check_snippet`
# against a scripted `ext_effects` entry. That establishes the ADOPTION — the
# branch on the typed code, the identity, the round trip — and establishes
# nothing about whether the seam can run a compiler at all, because in a
# scripted world it runs none. WI-D19 shipped exactly that gap in the other
# direction (its note claimed `tool_handle` could not reach `ailang`, which was
# true of the tool NAME it tried and false of the seam), and WI-D21 needed a
# separate measurement to find it.
#
# So this target runs one real `ailang check` through the production bridge over
# `live_ports` and asserts the COMPILER's own wording comes back. It is the row
# that cannot be satisfied by a stub, by a tool-error blob, or by a seam that
# returns "requires extension capability".
#
# It is NOT under `--ai-stub`: nothing here calls a provider. `--caps AI` is
# present only because `register_with_config`'s row declares it, and the runtime
# prints an advisory about the missing model that no code path reaches.
.PHONY: compose_live_exec
compose_live_exec:
	@set -eu; \
	out=$$(ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
	  --entry main scripts/dst/compose_live_exec.ail < /dev/null 2>&1) || { \
		printf '%s\n' "$$out"; \
		echo "FAIL: the live routed check did not complete"; exit 1; }; \
	printf '%s\n' "$$out" | grep -v '^Warning:\|^  No AI model\|^  Fix: ailang\|^  Or for testing:\|^→\|^✓ Running'; \
	printf '%s\n' "$$out" | grep -q 'compose_live_exec PASS'

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
	     src/core/session.ail src/core/tool_phase.ail src/core/context_usage.ail \
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
	ailang test src/core/dst_discovery.ail > /dev/null; echo "  ✓ src/core/dst_discovery.ail"; \
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
	ailang test src/core/ports.ail > /dev/null; echo "  ✓ src/core/ports.ail (recorded-outcome codec round trips)"; \
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
	         scripts/dst/fixtures/execution-program-v2.artifact \
	         scripts/dst/fixtures/execution-program-v3.artifact \
	         scripts/dst/fixtures/execution-program-v0.artifact; do \
		if [ ! -s "$$f" ]; then \
			echo "FAIL: the frozen specimen $$f is missing or empty."; \
			echo "      It is THE compatibility policy: encoder and decoder are written together and agree"; \
			echo "      by construction, so without a frozen artifact from before the current encoder the"; \
			echo "      policy is prose and the gate is green. It is not regenerable by design."; \
			exit 1; \
		fi; \
	done; \
	echo "  ✓ all four frozen specimens are present ($$(wc -l < scripts/dst/fixtures/execution-program-v1.artifact | tr -d ' ') lines of v1 bytes and $$(wc -l < scripts/dst/fixtures/execution-program-v2.artifact | tr -d ' ') of v2, both now predating this build's encoder, plus $$(wc -l < scripts/dst/fixtures/execution-program-v3.artifact | tr -d ' ') lines of v3 bytes carrying the byte-identity assertion at the version this build writes)"; \
	writers=$$(grep -rlE 'writeFile[A-Za-z]*\(\s*"?scripts/dst/fixtures|v1_fixture_path\(\)\s*,|v2_fixture_path\(\)\s*,|v3_fixture_path\(\)\s*,|v0_fixture_path\(\)\s*,' \
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
	ailang test src/core/dst_persistence.ail > /dev/null; echo "  ✓ src/core/dst_persistence.ail (the escape, the tag tables, and the path-vs-identity split site 22 forces)"; \
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

# `driver_plus_no_ops` v1 — the SECOND conformant profile (WI-D14), and the
# first that installs anything. Separate from `driver_only` for the same reason
# `driver_only` is separate from `profile_definition`: each profile earns its
# own coverage, and per D10 nothing transfers between them.
#
#   1. The load-time acceptance, plus ADR-001 row 3's four installed-extension
#      clauses. Each is asserted twice — as it stands, and against a MUTATION of
#      this same definition that the clause must reject — because a clause that
#      only ever passes cannot be told from one that does not run, and all four
#      of these have quantified over the empty set for the whole project.
#
#   2. The guard, which is what stops the profile agreeing with itself. It reads
#      the script's OUTPUT rather than its source (the classification entries are
#      computed, so the source does not contain them) and re-derives, from
#      producers the profile does not control: the zero-barrier install set, the
#      rowed/rowless split each classification rests on, every criterion-2
#      clause's vacuity, and the three CLAIM lines rows 4, 5 and 7 stand on.
#
#      The output is captured to a file so the run happens ONCE — piping it to
#      the guard would hide the script's own exit status behind the pipeline's.
#
#   3. The module's inline tests, which assert the shape no profile in this tree
#      has had before: a non-empty install list, stated three ways and agreeing.
.PHONY: driver_plus_no_ops
driver_plus_no_ops:
	@set -eu; \
	out=$$(mktemp); \
	if ! ailang run --caps IO --entry main scripts/dst/driver_plus_no_ops_dst.ail < /dev/null > $$out 2>&1; then \
		cat $$out; rm -f $$out; exit 1; \
	fi; \
	grep -v '^CLASSIFICATION \|^INSTALLED \|^OMITTED \|^DISCLOSURE \|^CLAIM \|^STATEMENT ' $$out; \
	python3 tools/profile_definition/check_no_op_profile.py $$out; \
	rm -f $$out; \
	ailang test src/core/dst_driver_plus_no_ops.ail > /dev/null && echo "  ✓ src/core/dst_driver_plus_no_ops.ail"

# `driver_plus_compose` v1 — the THIRD conformant profile (WI-D27), and the
# GOAL LINE'S CLAUSE 1. Separate from the other two for the same reason they are
# separate from each other: each profile earns its own coverage and per D10
# nothing transfers between them.
#
# WHAT IS DIFFERENT ABOUT THIS TARGET, AND IT IS NOT THE PROFILE — IT IS THE RUN.
# The other two acceptance scripts READ a record. This one reads a record AND
# RUNS THE SUBJECT: a full graded session through the real traced driver with
# compose installed through `register_with_config`, recorded, validated,
# reconstituted and strictly replayed. That is why it needs the whole capability
# set and `--ai-stub` where `driver_only` and `driver_plus_no_ops` need only IO.
#
# **THE CAPABILITIES ARE THE PROFILE'S OWN DISCLOSURE, NOT A CONVENIENCE.**
# compose's `register_with_config` reads Env and then FS before any hook is
# dispatched, and AILANG capabilities are per PROCESS — so this target cannot
# withhold them and the profile says so in D5 field 6. What carries the
# determinism claim instead is the record → strict-replay identity the script
# asserts.
#
#   1. The load-time acceptance, ADR-001 row 3's clauses (each asserted against a
#      MUTATION of this same definition that the clause must reject), and THE
#      DEMONSTRATION.
#
#   2. The guard, which is what stops the profile agreeing with itself. It reads
#      the script's OUTPUT rather than its source — the classification entries
#      are computed — and re-derives, from producers the profile does not
#      control: the install partition, classifier 3's still-AMBIENT verdict for
#      compose, the ABI's rowed/rowless split, the dispatch table's gated slot,
#      registration's disclosed sources, and the demonstration's own CLAIM line.
#
#      The output is captured to a file so the run happens ONCE — piping it to
#      the guard would hide the script's exit status behind the pipeline's.
#
#   3. The module's inline tests, which assert what no profile record in this
#      tree has carried before: a non-empty exclusion, and a non-zero
#      `world_mediating_hooks`.
.PHONY: driver_plus_compose
driver_plus_compose:
	@set -eu; \
	out=$$(mktemp); \
	if ! ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	     --ai-stub --entry main scripts/dst/driver_plus_compose_dst.ail < /dev/null > $$out 2>&1; then \
		cat $$out; rm -f $$out; exit 1; \
	fi; \
	grep -v '^CLASSIFICATION \|^INSTALLED \|^OMITTED \|^DISCLOSURE \|^DISCLOSED \|^CLAIM \|^STATEMENT \|^{"schema_version"' $$out; \
	python3 tools/profile_definition/check_compose_profile.py $$out; \
	rm -f $$out; \
	ailang test src/core/dst_driver_plus_compose.ail > /dev/null && echo "  ✓ src/core/dst_driver_plus_compose.ail"

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
# WI-C4 REPAIR, AND IT IS A GATE DEFECT RATHER THAN A CONTENT ONE. Six recipes
# in this file ran their unit suite as `ailang test X > /dev/null && echo "✓ X"`
# in NON-TERMINAL position. Under `set -e` a failure on the left of `&&` does
# not exit, and the status is discarded by the following `;` — so the target
# printed no tick for that file and exited 0. Terminal-position uses of the same
# form are safe (the recipe's status is the last command's), which is why this
# survived: eleven of seventeen sites were fine and the pattern read as uniform.
# Measured at WI-C4: of the six swallowing sites exactly one was masking a real
# failure — `dst_event_vocabulary`'s `test_logical_gap_is_recorded`, red since
# WI-C3 flipped `StreamDelta.reaches_trace_today` without updating its pinned
# literal. Two items reported "every target but two passes" over it. All six now
# run as checked commands.
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
	ailang test src/core/dst_event_vocabulary.ail > /dev/null; echo "  ✓ src/core/dst_event_vocabulary.ail"; \
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
	vio_t=0; missing=""; \
	sample=$$(awk '/^pure func sample_violations\(\)/,/^}/' src/core/dst_invariants.ail); \
	for c in $$(awk '/^export type Violation/,/^$$/' src/core/dst_invariants.ail | sed -n 's/^  [|=] \([A-Za-z_][A-Za-z0-9_]*\).*/\1/p'); do \
		vio_t=$$((vio_t + 1)); \
		printf '%s\n' "$$sample" | grep -qE "(^|[^A-Za-z0-9_])$$c\\(" || missing="$$missing $$c"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "FAIL: sample_violations() does not build:$$missing"; \
		echo "      violation_rule/_family/_message are total matches, so a new rule is a"; \
		echo "      compile error there — but one missing from sample_violations() is never"; \
		echo "      checked for a distinct rule id, a family, or a message naming it."; \
		echo "      Membership by NAME rather than by count, because a count is satisfied"; \
		echo "      by sampling one constructor twice and omitting another."; \
		exit 1; \
	fi; \
	echo "  ✓ $$fam_t InvariantFamily variants == $$fam_l in all_families(); all $$vio_t Violation constructors sampled by name"; \
	if ailang test src/core/dst_invariants.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ src/core/dst_invariants.ail"; \
	else \
		echo "  ✗ src/core/dst_invariants.ail"; \
		ailang test src/core/dst_invariants.ail < /dev/null 2>&1 | tail -20; \
		exit 1; \
	fi

# D11's run report and its counters (WI-A14 piece 3). Four checks.
#
#   1. THE SUITE. A complete report that must SURVIVE — a gate built only from
#      rejecting fixtures passes on a validator that rejects unconditionally —
#      then one single-field mutant per rejection rule, each asserting its own.
#
#   2. TWO STRUCTURAL GUARDS anchored to the syntactic form of the type
#      declarations:
#
#        variants in `export type ReachStatus`    == all_reach_ids()      (5)
#        variants in `export type ReportRejection` == sample_rejections() (13)
#
#      ReachStatus is the load-bearing one. Cluster 12's finding is that the
#      three unreached fault classes are unreached in three DIFFERENT ways and a
#      merged "unreached" number reports three facts as one — so the statuses
#      are a sum with a reason each, and a sixth added without an id would let a
#      fourth kind of gap be silently counted as one of the existing three.
#
#   3. THE ENTRY POINT THE REPLAY COMMAND NAMES MUST EXIST. `replay_command`
#      renders a copy-pasteable line into CI output (D8), and a command naming
#      an entry point nobody wrote satisfies every AILANG-side check while being
#      unpasteable — the same shape as D8's forbidden "digest without retained
#      bytes": a reference that looks like one and is not. The grep is anchored
#      to the syntactic form `export func <name>(` rather than to the bare name,
#      so a mention in a comment does not satisfy it.
#
#   4. AND THE COMMAND IS ACTUALLY RUN, against the frozen v1 specimen. Check 3
#      proves the entry point exists; only running it proves it loads retained
#      bytes. D8's clause is about replayability, and an affordance nobody
#      executes is exactly the kind of claim this project keeps finding green
#      and empty.
.PHONY: run_report
run_report:
	@set -eu; \
	ailang run --caps IO --entry main scripts/dst/run_report_dst.ail < /dev/null; \
	reach_t=$$(awk '/^export type ReachStatus/,/^$$/' src/core/dst_run_report.ail | grep -c '^  [|=]'); \
	reach_l=$$(awk '/^export pure func all_reach_ids\(\)/,/^}/' src/core/dst_run_report.ail | grep -c 'reach_id('); \
	if [ "$$reach_t" -ne "$$reach_l" ]; then \
		echo "FAIL: ReachStatus declares $$reach_t variants and all_reach_ids() lists $$reach_l."; \
		echo "      D11's counters distinguish four ways of not being reached plus a waiver;"; \
		echo "      a status with no id would let a new kind of gap be counted as an old one."; \
		exit 1; \
	fi; \
	rej_t=0; missing=""; \
	sample=$$(awk '/^pure func sample_rejections\(\)/,/^}/' src/core/dst_run_report.ail); \
	for c in $$(awk '/^export type ReportRejection/,/^$$/' src/core/dst_run_report.ail | sed -n 's/^  [|=] \([A-Za-z_][A-Za-z0-9_]*\).*/\1/p'); do \
		rej_t=$$((rej_t + 1)); \
		printf '%s\n' "$$sample" | grep -qE "(^|[^A-Za-z0-9_])$$c([^A-Za-z0-9_]|$$)" || missing="$$missing $$c"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "FAIL: sample_rejections() does not build:$$missing"; \
		echo "      report_rule/_message are total matches, so a new rule is a compile error"; \
		echo "      there — but one missing from sample_rejections() is never checked for a"; \
		echo "      distinct rule id or a message that names it. Membership is checked by"; \
		echo "      NAME and not by count, because SeedWindowEmpty is nullary — a count keyed"; \
		echo "      on '\''Constructor('\'' silently misses every constructor without arguments,"; \
		echo "      which is how this guard first went red."; \
		exit 1; \
	fi; \
	entry=$$(sed -n 's/^export pure func replay_entry_point() -> string { "\(.*\)" }$$/\1/p' src/core/dst_run_report.ail); \
	if [ -z "$$entry" ]; then \
		echo "FAIL: could not read replay_entry_point() out of src/core/dst_run_report.ail."; \
		exit 1; \
	fi; \
	if ! grep -q "^export func $$entry(" scripts/dst/run_report_dst.ail; then \
		echo "FAIL: replay_command names entry point '$$entry' and scripts/dst/run_report_dst.ail"; \
		echo "      declares no 'export func $$entry('. D8 requires CI output to carry a"; \
		echo "      copy-pasteable local replay command; a command naming an entry point"; \
		echo "      nobody wrote is unpasteable, which is the reporting-layer twin of the"; \
		echo "      digest-without-retained-bytes D8 forbids outright."; \
		exit 1; \
	fi; \
	echo "  ✓ $$reach_t ReachStatus variants == $$reach_l ids; all $$rej_t ReportRejection constructors sampled by name; entry point '$$entry' exists"; \
	out=$$(MOTOKO_DST_PROGRAM=scripts/dst/fixtures/execution-program-v1.artifact \
	  ailang run --caps IO,FS,Env --entry $$entry scripts/dst/run_report_dst.ail < /dev/null 2>&1); \
	if printf '%s\n' "$$out" | grep -q '✓ gen.specimen/gv-2 seed 23'; then \
		echo "  ✓ the rendered replay command runs and loads the frozen v1 specimen's retained bytes"; \
	else \
		echo "  ✗ the rendered replay command did not load the frozen specimen — the CI"; \
		echo "      replay affordance is decorative, which is what D8's retained-bytes"; \
		echo "      clause exists to prevent."; \
		printf '%s\n' "$$out" | tail -10; \
		exit 1; \
	fi; \
	if ailang test src/core/dst_run_report.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ src/core/dst_run_report.ail"; \
	else \
		echo "  ✗ src/core/dst_run_report.ail"; \
		ailang test src/core/dst_run_report.ail < /dev/null 2>&1 | tail -20; \
		exit 1; \
	fi

# D4's latency pair (WI-A14 piece 2). Two checks.
#
#   1. THE SUITE. Two worlds identical but for one integer, run through the REAL
#      driver, demonstrating completion versus timeout; the S8 control (same
#      latency, no declared deadline, must COMPLETE); both programs replaying
#      deterministically; and the two artifacts having different identities, so
#      the pair is two programs rather than one reported twice.
#
#   2. A WIRE WITNESS, and it is here for the same reason strict_replay's is.
#      Every assertion in the AILANG suite reads the INTERACTION LOG, which the
#      recorder wrote — so a recorder that stamped `ToolDeadlineExceeded` on
#      both halves would satisfy all of them. `native_tool_results` carries the
#      fault class to the wire from PRODUCTION code (tool_phase's
#      tool_outcome_message) that knows nothing about the interaction log, and
#      it must appear exactly as many times as the run has slow halves.
#
#      The suite runs the slow world THREE times (the pair, the replay pair, and
#      the identity check) and the fast world three times, so the wire carries
#      three deadline faults and no more. Counted rather than grepped for
#      presence: presence is satisfied by a recorder that faults everything.
.PHONY: latency_pair
latency_pair:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry main scripts/dst/latency_pair_dst.ail < /dev/null > /tmp/latency_pair.out 2>&1 || \
	  { tail -40 /tmp/latency_pair.out; exit 1; }; \
	grep -v '^{' /tmp/latency_pair.out; \
	late=$$(grep -c '"fault_class":"ToolDeadlineExceeded"' /tmp/latency_pair.out || true); \
	total=$$(grep -c '"type":"native_tool_results"' /tmp/latency_pair.out || true); \
	if [ "$$late" -eq 0 ]; then \
		echo "FAIL: the driver emitted no ToolDeadlineExceeded to the wire. Every"; \
		echo "      assertion in the suite reads the interaction log, which the recorder"; \
		echo "      wrote; the wire witness comes from production code that knows nothing"; \
		echo "      about that log, and without it the pair is graded by its own recorder."; \
		exit 1; \
	fi; \
	if [ "$$late" -eq "$$total" ]; then \
		echo "FAIL: every one of the $$total tool dispatches faulted with ToolDeadlineExceeded."; \
		echo "      The fast half must NOT fault — a recorder or a world that faults"; \
		echo "      everything satisfies a presence check and proves nothing about latency."; \
		exit 1; \
	fi; \
	echo "  ✓ wire witness: $$late of $$total native_tool_results carry ToolDeadlineExceeded (the slow halves, and only those)"

# D11's BLOCKING PR CORPUS (WI-A15 commit 1). Four checks.
#
#   1. THE SUITE. The twelve pinned seeds plus the constructed member, each
#      generated by the real driver, persisted, LOADED BACK off disk and keyed
#      on both corpus keys; the collective coverage obligation; the shrink-only
#      register asserted in both directions; and one single-field mutant per
#      rejection rule, each asserting ITS OWN rule.
#
#   2. THE BRANCH COUNTER, AND IT CANNOT LIVE IN THE SUITE. D11 keeps
#      class-reached and branch-reached as separate counters because reaching a
#      class is not evidence that the production branch ran. Every assertion in
#      the AILANG suite reads the INTERACTION LOG, which the recorder wrote — so
#      a recorder that stamped a class on everything would satisfy all of them.
#
#      The branch witness is the WIRE, and it is not reachable from inside the
#      process at all: `NativeToolDenied` and `NativeToolResults` are both in
#      `dst_invariants.d64_gap_register()`, so they never reach the returned
#      trace. Production code emits them knowing nothing about the interaction
#      log. Each of the five branches is COUNTED rather than grepped for
#      presence, because presence is satisfied by a driver that denies
#      everything.
#
#      `empty_stop_finalize` is the sharpest of the five: exactly ONE across the
#      whole target, emitted by the constructed member alone. A second one would
#      mean a generated seed had started reaching the class the construction
#      exists for, which is the register-closing event the suite's
#      `constructed-for-reachable-class` rule is about.
#
#   3. TWO STRUCTURAL GUARDS, anchored to the syntactic form of the type
#      declarations and checking membership BY NAME rather than by count —
#      cluster 13's finding, and it is why: `CorpusEmpty` and `WindowZero` are
#      NULLARY, and a regex keyed on `Constructor(` silently misses every
#      constructor without arguments.
#
#   4. THE MEASURED CI COST IS ITSELF GATED. D11 delegates seed counts to
#      measured cost and the plan selects them here; a measured constant nobody
#      re-measures is the stale number this project keeps finding. The target's
#      wall clock is compared against `pr_target_ceiling_ms()` read out of the
#      source, so the measurement that the minimums are derived from has a gate
#      behind it rather than a comment.
.PHONY: corpus_pr
corpus_pr:
	@set -eu; \
	rm -rf .ailang/dst-corpus; \
	start=$$(date +%s); \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry main scripts/dst/corpus_pr_dst.ail < /dev/null > /tmp/corpus_pr.out 2>&1 || \
	  { grep -v '^{' /tmp/corpus_pr.out | tail -40; exit 1; }; \
	grep -v '^{' /tmp/corpus_pr.out; \
	denied=$$(grep -c '"type":"native_tool_denied"' /tmp/corpus_pr.out || true); \
	empty=$$(grep -c '"type":"empty_stop_finalize"' /tmp/corpus_pr.out || true); \
	tf=$$(grep -c '"fault_class":"ToolFailed"' /tmp/corpus_pr.out || true); \
	tcm=$$(grep -c '"fault_class":"ToolCorrelationMismatch"' /tmp/corpus_pr.out || true); \
	tde=$$(grep -c '"fault_class":"ToolDeadlineExceeded"' /tmp/corpus_pr.out || true); \
	retry=$$(grep -c '"type":"stream_error_retry"' /tmp/corpus_pr.out || true); \
	pfail=$$(grep -o '"error":"generated E_PROVIDER_[A-Z_]*"' /tmp/corpus_pr.out | wc -l); \
	badargs=$$(grep -o '"arguments":{}' /tmp/corpus_pr.out | wc -l); \
	for pair in "session.c2_loop/approval_denied:$$denied" \
	            "session.c2_loop/empty_stop_finalize:$$empty" \
	            "tool_phase.tool_outcome_message/ToolFailed:$$tf" \
	            "tool_phase.tool_outcome_message/ToolCorrelationMismatch:$$tcm" \
	            "tool_phase.tool_outcome_message/ToolDeadlineExceeded:$$tde" \
	            "session.c2_loop/stream_error_retry:$$retry" \
	            "session.c2_loop/provider_failure_finalize:$$pfail" \
	            "tool_dispatch_adapter.tool_call_to_envelope/malformed_arguments:$$badargs"; do \
		branch=$${pair%:*}; n=$${pair##*:}; \
		if [ "$$n" -eq 0 ]; then \
			echo "FAIL: the fixed bank reached the fault class and the wire carries NO"; \
			echo "      record of the recovery branch '$$branch' executing."; \
			echo "      D11 keeps class-reached and branch-reached as separate counters for"; \
			echo "      exactly this: reaching a class is not evidence that the production"; \
			echo "      branch it targets ran, and only the second is the coverage the"; \
			echo "      acceptance test asks for. Every assertion in the AILANG suite reads"; \
			echo "      the interaction log, which the recorder wrote; this reads the wire,"; \
			echo "      which production code wrote knowing nothing about that log."; \
			exit 1; \
		fi; \
	done; \
	if [ "$$empty" -ne 1 ]; then \
		echo "FAIL: the wire carries $$empty empty_stop_finalize record(s) and exactly 1 is"; \
		echo "      expected — the CONSTRUCTED member is the only thing in this corpus that"; \
		echo "      can produce one. More than one means a generated seed has started"; \
		echo "      reaching provider_empty_terminal_response, which retires the"; \
		echo "      construction's justification and must be RECORDED rather than absorbed."; \
		exit 1; \
	fi; \
	served=$$(grep -c '"type":"native_tool_calls"' /tmp/corpus_pr.out || true); \
	if [ "$$served" -eq 0 ]; then \
		echo "FAIL: the wire carries $$denied approval denials and NOT ONE executed tool call."; \
		echo "      A bank in which the approval channel denied everything reaches"; \
		echo "      approval_denied on every member and exercises the ALLOW branch on none,"; \
		echo "      so the branch counter above is satisfied by a world that says no to"; \
		echo "      everything. Cluster 13: presence is satisfied by a world that faults"; \
		echo "      everything, which is why these are counted and why both sides of the"; \
		echo "      approval decision have to appear."; \
		exit 1; \
	fi; \
	echo "  ✓ wire witness, branch-reached: approval_denied×$$denied empty_stop_finalize×$$empty ToolFailed×$$tf ToolCorrelationMismatch×$$tcm ToolDeadlineExceeded×$$tde stream_error_retry×$$retry provider_failure_finalize×$$pfail malformed_arguments×$$badargs (against $$served executed dispatch batch(es), so neither side of the approval decision is unwalked)"; \
	nonretry_re=$$(awk '/^export pure func provider_error_codes_non_retryable/,/^}/' src/core/dst_fault_catalogue.ail | grep -o 'E_PROVIDER_[A-Z_]*' | paste -sd'|' -); \
	retry_re=$$(awk '/^export pure func provider_error_codes_retryable/,/^}/' src/core/dst_fault_catalogue.ail | grep -o 'E_PROVIDER_[A-Z_]*' | paste -sd'|' -); \
	if [ -z "$$nonretry_re" ] || [ -z "$$retry_re" ]; then \
		echo "FAIL: could not read the provider error code vocabulary out of"; \
		echo "      src/core/dst_fault_catalogue.ail. The two checks below are derived from"; \
		echo "      those lists rather than restating them, so an unreadable list must be a"; \
		echo "      red rather than an empty pattern that matches nothing and passes."; \
		exit 1; \
	fi; \
	leak=$$(grep '"type":"stream_error_retry"' /tmp/corpus_pr.out | grep -cE "$$nonretry_re" || true); \
	fin_nonretry=$$(grep '"type":"run_summary"' /tmp/corpus_pr.out | grep -oE "\"error\":\"generated ($$nonretry_re)\"" | wc -l); \
	retry_retryable=$$(grep '"type":"stream_error_retry"' /tmp/corpus_pr.out | grep -cE "$$retry_re" || true); \
	if [ "$$leak" -ne 0 ]; then \
		echo "FAIL: $$leak stream_error_retry record(s) on the wire carry a NON-RETRYABLE"; \
		echo "      provider error code. session.c2_loop branches on AIError.retryable through"; \
		echo "      should_retry_stream_error, and dst_fault_catalogue derives that bool from"; \
		echo "      the code — so a non-retryable code reaching the retry branch means the"; \
		echo "      derivation and the driver disagree, and the two provider error classes are"; \
		echo "      not the two branches D3 says they are."; \
		exit 1; \
	fi; \
	if [ "$$retry_retryable" -eq 0 ] || [ "$$fin_nonretry" -eq 0 ]; then \
		echo "FAIL: the two provider error classes did not reach DIFFERENT production"; \
		echo "      branches: retryable→retry×$$retry_retryable, non-retryable→finalize×$$fin_nonretry."; \
		echo "      This is the clause acceptance row 4 turns on and the reason WI-D1 could"; \
		echo "      not answer it with a counter. provider_error_retryable and"; \
		echo "      provider_error_non_retryable differ by exactly AIError.retryable; if both"; \
		echo "      reach the same branch they are ONE scenario recorded under two names, the"; \
		echo "      class-reached counter still reads 9 of 9, and the row is not closed."; \
		exit 1; \
	fi; \
	echo "  ✓ the two provider error classes reach DIFFERENT branches: retryable→stream_error_retry×$$retry_retryable, non-retryable→provider_failure_finalize×$$fin_nonretry, and NO retry carries a non-retryable code"; \
	rej_t=0; missing=""; \
	sample=$$(awk '/^pure func sample_rejections\(\)/,/^}/' src/core/dst_corpus.ail); \
	for c in $$(awk '/^export type CorpusRejection/,/^$$/' src/core/dst_corpus.ail | sed -n 's/^  [|=] \([A-Za-z_][A-Za-z0-9_]*\).*/\1/p'); do \
		rej_t=$$((rej_t + 1)); \
		printf '%s\n' "$$sample" | grep -qE "(^|[^A-Za-z0-9_])$$c([^A-Za-z0-9_]|$$)" || missing="$$missing $$c"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "FAIL: sample_rejections() does not build:$$missing"; \
		echo "      corpus_rule/_message are total matches, so a new rule is a compile error"; \
		echo "      there — but one missing from sample_rejections() is never checked for a"; \
		echo "      distinct rule id or a message that names it. Membership is checked BY"; \
		echo "      NAME and not by count: CorpusEmpty and WindowZero are nullary, and a"; \
		echo "      count keyed on 'Constructor(' silently misses every constructor without"; \
		echo "      arguments (cluster 13)."; \
		exit 1; \
	fi; \
	kind_t=0; kmissing=""; \
	kinds=$$(awk '/^export pure func all_member_kind_ids\(\)/,/^}/' src/core/dst_corpus.ail); \
	for c in $$(awk '/^export type MemberKind/,/^$$/' src/core/dst_corpus.ail | sed -n 's/^  [|=] \([A-Za-z_][A-Za-z0-9_]*\).*/\1/p'); do \
		kind_t=$$((kind_t + 1)); \
		printf '%s\n' "$$kinds" | grep -qE "(^|[^A-Za-z0-9_])$$c([^A-Za-z0-9_]|$$)" || kmissing="$$kmissing $$c"; \
	done; \
	if [ -n "$$kmissing" ]; then \
		echo "FAIL: all_member_kind_ids() does not name:$$kmissing"; \
		echo "      D11's bank is 'fixed seeds and exact promoted regression programs' and"; \
		echo "      cluster 12's limit forces the third kind. The S7 row asserts the bank"; \
		echo "      carries EVERY kind; a kind with no id would let that row pass while a"; \
		echo "      whole category of member went uncounted."; \
		exit 1; \
	fi; \
	echo "  ✓ all $$rej_t CorpusRejection constructors sampled by name; all $$kind_t MemberKind constructors have ids"; \
	if ailang test src/core/dst_corpus.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ src/core/dst_corpus.ail"; \
	else \
		echo "  ✗ src/core/dst_corpus.ail"; \
		ailang test src/core/dst_corpus.ail < /dev/null 2>&1 | tail -20; \
		exit 1; \
	fi; \
	elapsed=$$(( ($$(date +%s) - start) * 1000 )); \
	ceiling=$$(sed -n 's/^export pure func pr_target_ceiling_ms() -> int { \([0-9]*\) }$$/\1/p' src/core/dst_corpus.ail); \
	if [ -z "$$ceiling" ]; then \
		echo "FAIL: could not read pr_target_ceiling_ms() out of src/core/dst_corpus.ail."; \
		exit 1; \
	fi; \
	if [ "$$elapsed" -gt "$$ceiling" ]; then \
		echo "FAIL: the PR corpus target took $$elapsed ms against a declared ceiling of $$ceiling ms."; \
		echo "      D11 delegates seed counts to MEASURED CI cost and this plan selects them"; \
		echo "      from it, so the measurement needs a gate behind it and not a comment."; \
		echo "      Re-measure and move measured_ms_per_seed() with the ceiling rather than"; \
		echo "      raising the ceiling alone — the minimums are arithmetic over that"; \
		echo "      constant, and a stale constant makes them arithmetic over nothing."; \
		exit 1; \
	fi; \
	echo "  ✓ measured CI cost, WHOLE TARGET: $$elapsed ms against a declared ceiling of $$ceiling ms"

# D11's SCHEDULED ROTATING CORPUS (WI-A15 commit 2). Six checks.
#
#   1. THE SUITE. The rotation checked three non-redundant ways — position by
#      position, the wrap branch, and the epoch's route — plus the shard
#      partition and the demo scale's contract.
#
#   2. THE JOB IS RUN FOR REAL, at the demo scale, off a window derived from an
#      epoch. Everything in check 1 is pure arithmetic and would pass over a
#      window whose seeds no driver can execute.
#
#   3. AND THE FOUR FAILURES ARE FORCED, NOT ASSERTED. D11: "A zero, silently
#      truncated, or below-minimum window fails", plus the epoch's own
#      fail-closed. A gate asserting "no member failed" is green on a window
#      that ran NO members — zero failures out of zero runs — so each condition
#      is injected into the REAL JOB and the job must exit non-zero.
#
#      This is A16's clause earning its keep a second time: "verified by
#      breaking one deliberately" could not be satisfied there as written,
#      because four of eight scripts had no failing exit path at all and would
#      have been wired in green regardless of their assertions.
#
#   4. THE ENTRY POINT THE WORKFLOW NAMES MUST EXIST, anchored to the syntactic
#      form `export func <name>(` rather than the bare name, so a mention in a
#      comment does not satisfy it. Same guard as `make run_report`'s, and for
#      the same reason: a workflow naming an entry point nobody wrote passes
#      every AILANG-side check while never running.
#
#   5. THE WORKFLOW MUST NOT SELECT THE DEMO SCALE. The demo scale is why check
#      2 is affordable; a scheduled job that quietly selected it would report a
#      rotating corpus while searching four seeds. That is the frozen-window
#      failure wearing a smaller number, and nothing inside the AILANG process
#      can see it.
#
#   6. THE MATRIX WIDTH MUST EQUAL THE DECLARED SHARD COUNT, both read from
#      source. A matrix wider than `scheduled_job().shards` runs workers whose
#      shard index selects no seeds — a zero window per worker — and a narrower
#      one drops part of the window while every worker that did run passes.
.PHONY: corpus_rotating
corpus_rotating:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
	  --ai-stub --entry main scripts/dst/corpus_rotating_dst.ail < /dev/null > /tmp/corpus_rot.out 2>&1 || \
	  { grep -v '^{' /tmp/corpus_rot.out | tail -40; exit 1; }; \
	grep -v '^{' /tmp/corpus_rot.out; \
	job() { \
		env MOTOKO_DST_SCALE=demo "$$@" ailang run \
		  --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
		  --ai-stub --entry scheduled_run scripts/dst/corpus_rotating_dst.ail \
		  < /dev/null > /tmp/corpus_job.out 2>&1; \
	}; \
	if job MOTOKO_DST_EPOCH=5; then \
		echo "  ✓ the job runs a real window off epoch 5: $$(grep -o 'WINDOWROW.*' /tmp/corpus_job.out)"; \
	else \
		echo "FAIL: the scheduled job did not complete a clean window."; \
		grep -v '^{' /tmp/corpus_job.out | tail -30; exit 1; \
	fi; \
	first5=$$(grep -o 'WINDOWROW epoch=5 first=[0-9]*' /tmp/corpus_job.out | head -1); \
	if job MOTOKO_DST_EPOCH=6; then :; else \
		echo "FAIL: the scheduled job did not complete a clean window at epoch 6."; \
		grep -v '^{' /tmp/corpus_job.out | tail -30; exit 1; \
	fi; \
	first6=$$(grep -o 'WINDOWROW epoch=6 first=[0-9]*' /tmp/corpus_job.out | head -1); \
	if [ -z "$$first5" ] || [ -z "$$first6" ]; then \
		echo "FAIL: the job emitted no WINDOWROW to re-derive the rotation from."; \
		exit 1; \
	fi; \
	if [ "$${first5##*first=}" = "$${first6##*first=}" ]; then \
		echo "FAIL: two different epochs produced a window starting at the SAME seed."; \
		echo "      Re-derived OUTSIDE the AILANG process, which is the point: every"; \
		echo "      rotation check in the suite compares windows the same module"; \
		echo "      produced, and a comparison that silently became a tautology cannot"; \
		echo "      carry this gate on its own. D11 asks for a window that CHANGES"; \
		echo "      deterministically, and a frozen window satisfies 'deterministically'"; \
		echo "      perfectly — it is the property a frozen thing has in the highest"; \
		echo "      degree."; \
		exit 1; \
	fi; \
	echo "  ✓ re-derived outside the process: epoch 5 starts at $${first5##*first=}, epoch 6 at $${first6##*first=}"; \
	for forced in "no-epoch::" "zero:MOTOKO_DST_EPOCH=5:MOTOKO_DST_FORCE=zero" \
	              "below-minimum:MOTOKO_DST_EPOCH=5:MOTOKO_DST_FORCE=below-minimum" \
	              "truncated:MOTOKO_DST_EPOCH=5:MOTOKO_DST_FORCE=truncate"; do \
		name=$$(printf '%s' "$$forced" | cut -d: -f1); \
		a=$$(printf '%s' "$$forced" | cut -d: -f2); \
		b=$$(printf '%s' "$$forced" | cut -d: -f3); \
		set +e; \
		if [ -n "$$a" ] && [ -n "$$b" ]; then job "$$a" "$$b"; \
		elif [ -n "$$a" ]; then job "$$a"; \
		else job; fi; \
		rc=$$?; \
		set -e; \
		if [ "$$rc" -eq 0 ]; then \
			echo "FAIL: the scheduled job EXITED 0 on a '$$name' window."; \
			echo "      D11 fails a zero, silently truncated or below-minimum window, and"; \
			echo "      requires the epoch to resolve rather than default. Each of the four"; \
			echo "      is forced into the REAL JOB here rather than asserted against a"; \
			echo "      mutated validator, because the thing that has to fail is the job."; \
			grep -v '^{' /tmp/corpus_job.out | tail -20; \
			exit 1; \
		fi; \
		rule=$$(grep -o 'REJECTED: [a-z-]*' /tmp/corpus_job.out | head -1); \
		rule=$${rule:-$$(grep -o '\[epoch-not-resolved\]' /tmp/corpus_job.out | head -1)}; \
		echo "  ✓ forced '$$name': the job exited $$rc — $$rule"; \
	done; \
	entry=$$(grep -o 'entry scheduled_run' .github/workflows/dst-corpora.yml | head -1); \
	if [ -z "$$entry" ]; then \
		echo "FAIL: .github/workflows/dst-corpora.yml does not name --entry scheduled_run."; \
		exit 1; \
	fi; \
	if ! grep -q '^export func scheduled_run(' scripts/dst/corpus_rotating_dst.ail; then \
		echo "FAIL: the workflow runs '--entry scheduled_run' and"; \
		echo "      scripts/dst/corpus_rotating_dst.ail declares no 'export func"; \
		echo "      scheduled_run('. A workflow naming an entry point nobody wrote passes"; \
		echo "      every AILANG-side check while never running — the same shape as D8's"; \
		echo "      forbidden digest with no retained bytes."; \
		exit 1; \
	fi; \
	if grep -qE '^[[:space:]]*MOTOKO_DST_SCALE:[[:space:]]*.?demo' .github/workflows/dst-corpora.yml; then \
		echo "FAIL: the scheduled workflow selects MOTOKO_DST_SCALE=demo."; \
		echo "      The demo scale exists so that 'make dst' can run real seeds off a"; \
		echo "      rotating window cheaply — 4 seeds off a 26-seed space. A scheduled job"; \
		echo "      that selected it would report a rotating corpus while searching four"; \
		echo "      seeds: the frozen-window failure wearing a smaller number, and nothing"; \
		echo "      inside the AILANG process can see it."; \
		exit 1; \
	fi; \
	declared=$$(awk '/^export pure func scheduled_job\(\)/,/^}/' src/core/dst_corpus.ail | sed -n 's/^[[:space:]]*shards: \([0-9]*\),$$/\1/p'); \
	matrix=$$(sed -n 's/^        shard: \[\(.*\)\]$$/\1/p' .github/workflows/dst-corpora.yml | tr -cd ',' | wc -c); \
	matrix=$$((matrix + 1)); \
	if [ "$$declared" != "$$matrix" ]; then \
		echo "FAIL: scheduled_job() declares $$declared shard(s) and the workflow matrix has $$matrix."; \
		echo "      A matrix wider than the declared count runs workers whose shard index"; \
		echo "      selects NO seeds — a zero window per worker — and a narrower one drops"; \
		echo "      part of the window while every worker that did run passes. Neither is"; \
		echo "      visible from inside the process, which is why this is checked here."; \
		exit 1; \
	fi; \
	echo "  ✓ the workflow names an entry point that exists, does not select the demo scale, and its matrix is $$matrix against $$declared declared shard(s)"

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
# THE HOST-READ CLASSES HAVE A POISON PAIR AS OF WI-D3, and the note that used
# to stand here — explaining why the env class deliberately had none — is
# deleted rather than edited, because the thing it deferred exists.
#
# What it deferred: `src/core/context_usage.ail` read MOTOKO_MODELS_FILE /
# MOTOKO_REPO / MOTOKO_PROFILE_DIR / MOTOKO_CONFIG ambiently, and every one of
# those reads existed to compute a FILE PATH it then read ambiently too. Routing
# the env half alone would have handed back a world-supplied path to a HOST file
# — a run that passes an Env poison probe while still depending on ambient state,
# which is cluster 4's C1b defect. Completing it needed a filesystem class, and
# WI-A12's specified order did not contain one. WI-D3 added `Ports.file_read`,
# `WorldState.files` and `ContextReader`, and routed BOTH halves together.
#
# The note also undercounted: it said `resolve_context_limit` was called at six
# sites. It is EIGHT — six in session.ail and two in rpc.ail — and all eight are
# threaded now.
#
# TWO CLASSES, FOUR RUNS, and they share a subject on purpose. The deterministic
# half and the live half run the SAME session call; the only difference between
# them is which closures `ported_provider` bound. So a live run that dies where
# the scripted one completes locates the failure in the binding rather than
# somewhere in the driver, which is the argument the AI and Clock pairs make and
# the reason the pair is worth more than either half.
#
# MEASURED at WI-D3, both directions. At HEAD before the item, withholding
# either capability killed the DETERMINISTIC run, and short-circuiting
# `resolve_context_limit` alone made both pass — so it was the sole cause and
# the class is a point read rather than something wider. After the item, binding
# `live_ports.file_read` to `scripted_file` makes the FS-withheld LIVE run
# COMPLETE, which is what pins the live half's death to `ambient_file` instead
# of to anything incidental on the path.
#
# WHAT THE PAIR CANNOT SEE, MEASURED AT WI-D3 RATHER THAN ARGUED. Bind
# `scripted_file` so that it IGNORES `WorldState.files` entirely and ALL FOUR
# halves stay green: the deterministic runs still perform no ambient read, and
# the live runs still die on `ambient_file`. A poison pair is a statement about
# what a run does NOT read, and it is silent on whether the world is read at
# all. That is S16's shape — the two sides of the pair share no producer, and
# the property they establish is simply a different property. The
# world_state_probe assertions below are what catch it, and they went red on
# that mutant while every pair row stayed green.
#
# The env class ALSO keeps its provenance assertion in world_state_probe — the
# probe seeds MOTOKO_HEADLESS in the world and asserts the driver acted on the
# world's value, with a control run proving the two branches differ. That is a
# different claim from this pair and neither replaces the other: provenance says
# the driver read the world where it was asked to, and the pair says nothing
# else in the run reads the host. C4 ruled that provenance is not hermeticity,
# and it is still not.
#
# The poison entry point is `--entry main_host_class`, NOT a POISON_ARM value.
# `main` selects its arm with getEnvOr, which performs an Env read before it
# reaches any subject, so an Env-withheld run of `main` would die on the
# selector and report a non-zero exit that establishes nothing.
.PHONY: world_state
world_state:
	@set -eu; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main scripts/dst/world_state_probe.ail < /dev/null; \
	echo "  -- WI-D23 exit-code witness (full caps; NOT part of main — main must keep completing with Process withheld) --"; \
	ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry exit_code_witness scripts/dst/world_state_probe.ail < /dev/null; \
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
	echo "  -- host-env class poison pair (Env withheld) --"; \
	if ailang run --caps IO,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main \
	     scripts/dst/world_state_probe.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ deterministic world completes with Env withheld (WI-D3; all 8 resolve_context_limit sites routed)"; \
	else \
		echo "FAIL: the deterministic entry point needs Env — a driver env read or a context_usage read is un-routed"; \
		exit 1; \
	fi; \
	if ailang run --caps IO,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub \
	     --entry main_host_class scripts/dst/world_state_poison.ail < /dev/null > /dev/null 2>&1; then \
		echo "FAIL: the LIVE world completed with Env withheld — the capability is not load-bearing, so the check above is vacuous"; \
		exit 1; \
	else \
		echo "  ✓ live world dies with Env withheld"; \
	fi; \
	echo "  -- filesystem class poison pair (FS withheld) --"; \
	if ailang run --caps IO,Env,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub --entry main \
	     scripts/dst/world_state_probe.ail < /dev/null > /dev/null 2>&1; then \
		echo "  ✓ deterministic world completes with FS withheld (WI-D3's file class)"; \
	else \
		echo "FAIL: the deterministic entry point still reads an ambient file — a file_read seam is un-routed"; \
		exit 1; \
	fi; \
	if ailang run --caps IO,Env,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub \
	     --entry main_host_class scripts/dst/world_state_poison.ail < /dev/null > /dev/null 2>&1; then \
		echo "FAIL: the LIVE world completed with FS withheld — ambient_file is not load-bearing, so the check above is vacuous"; \
		exit 1; \
	else \
		echo "  ✓ live world dies with FS withheld"; \
	fi; \
	echo "  i the env class ALSO keeps its provenance assertion in world_state_probe — a different claim, not a replacement"; \
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
#
#      WI-B4 TIGHTENED IT A SECOND TIME, and for a different species. The
#      pattern is a PROXY for "a TracedSessionResult literal", and WI-B2b's
#      world token introduced a second record that also opens with `{ result:`
#      and is not one: `ExtAiStepResult` (its declaration, and the `ai_step`
#      bridge that builds one). The guard counted 3 and named a bypassing
#      terminal return that does not exist.
#
#      The discriminator is a FIELD, not a spelling: `TracedSessionResult` is
#      `{ result, trace, world }` and has no `next_state` field, while every
#      `{ result: … }` record B2b added has one. So lines carrying `next_state:`
#      — with the colon, which `world: reading.next_state` does not have — are
#      provably not terminal records and are excluded. This is a fidelity fix
#      rather than a silencing: it narrows on a property the terminal record
#      CANNOT have. Verified in both directions again, with the same two
#      plausible bypassing shapes: 1 at HEAD, 3 with them added.
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
	n=$$(grep '^[^-]*{ result:' src/core/session.ail | grep -vc 'next_state:'); \
	if [ "$$n" -ne 1 ]; then \
		echo "FAIL: $$n terminal record literals in session.ail, expected 1 (c2_finalize). A terminal return is bypassing the finalizer — see D6.1."; \
		grep -n '^[^-]*{ result:' src/core/session.ail | grep -v 'next_state:'; \
		exit 1; \
	else \
		echo "  ✓ all terminal returns route through c2_finalize"; \
	fi; \
	ailang test src/core/dst_result.ail > /dev/null; echo "  ✓ src/core/dst_result.ail"; \
	ailang test src/core/phase_vocab.ail > /dev/null; echo "  ✓ src/core/phase_vocab.ail"; \
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
#
# THE SETUP LINE IS PART OF THE TARGET, not a documented precondition.
# smoke_v2_dp7_gate needs three /tmp workdirs (always-fail, always-pass, and
# no-Makefile) to tell DP7's three outcomes apart. Only `smoke_parity` created
# them, via phase_a_event_parity.sh — and in CI that step runs AFTER this one,
# so smoke_driver failed on every PR from the day WI-A16 wired it in while
# passing on any developer machine where an earlier `make smoke_parity` had left
# the directories behind. A target whose result depends on what ran before it is
# not a gate, so it now makes its own fixtures.
.PHONY: smoke_driver
smoke_driver:
	@bash scripts/setup_dp7_smoke_workdirs.sh > /dev/null
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
		echo "  ✓ src/core/test/scripted_ports.ail (10 unit tests)"; \
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
check_core: verify_extensions verify_herdr_gate
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
# The one property motoko-ext-herdr must have and cannot get from a type check:
# it advertises NO tools when herdr is absent. The empty leg runs everywhere —
# with the three variables stripped, which is the operator's devcontainer — and
# is the one that matters, because a tool advertised outside a pane fails at
# call time and teaches the model nothing. The populated leg is only meaningful
# inside a pane, so it is skipped elsewhere rather than failed.
HERDR_GATE_CAPS = Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream

verify_herdr_gate:
	@env -u HERDR_ENV -u HERDR_BIN_PATH -u HERDR_PANE_ID \
		ailang run --caps $(HERDR_GATE_CAPS) --ai-stub --entry main \
		scripts/verify_herdr_gate.ail -- expect-empty 2>/dev/null | grep -E '^(OK|FAIL)' \
		|| (echo "verify_herdr_gate: the gate leaked tools outside a herdr pane" && exit 1)
	@if [ "$$HERDR_ENV" = "1" ]; then \
		ailang run --caps $(HERDR_GATE_CAPS) --ai-stub --entry main \
		  scripts/verify_herdr_gate.ail -- expect-tools 2>/dev/null | grep -E '^(OK|FAIL)' \
		  || (echo "verify_herdr_gate: the gate did not advertise its tools inside a herdr pane" && exit 1); \
	else \
		echo "  (skipping the in-pane leg: not running under herdr)"; \
	fi

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
#
# Every unticked file prints the reason `ailang verify` gave, and no file with zero
# VERIFIED contracts prints a tick. "Amber" is split by cause, because the two halves
# need opposite treatment (ADR-001 §3, .agent/projects/027_z3_contracts/):
#
#   unstated  requires with no ensures -- nobody ever wrote an obligation, and the
#             requires is never asserted against a caller either (verify.go:290-304),
#             so it is documentation that reads as a specification. EXITS 1.
#   blocked   an ensures exists and the Z3 fragment rejected it (NOT_PURE, RECURSIVE,
#             HIGHER_ORDER, UNENCODABLE_TYPE, unencodable builtin). Someone tried and
#             the solver could not. Reported, never fails -- failing here would punish
#             the attempt and make deleting the contract the cheapest route to green.
#
# VIOLATION or ERROR exits 1 (contracts written but broken).
# Files with no contracts at all are counted as bare and do not fail.
# Reasons, not rejection codes: verify.go:340-349 strips codes from the human message.
verify_core:
	@proven=0; unstated=0; blocked=0; fail=0; bare=0; \
	for f in src/core/*.ail; do \
		case "$$f" in *_test.ail) continue ;; esac; \
		out="$$(ailang verify "$$f" 2>&1)"; \
		rc=$$?; \
		if [ $$rc -ne 0 ]; then \
			echo "  ✗ $$f"; \
			echo "$$out" | grep -E 'VIOLATION|ERROR' | head -3; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		if echo "$$out" | grep -q "no functions with contracts"; then \
			bare=$$((bare + 1)); \
			continue; \
		fi; \
		v="$$(echo "$$out" | grep -c 'VERIFIED')"; \
		u="$$(echo "$$out" | grep 'Reason:' | grep -c 'no ensures clause')"; \
		b="$$(echo "$$out" | grep -c 'Reason:')"; b=$$((b - u)); \
		if [ $$v -eq 0 ] && [ $$u -eq 0 ] && [ $$b -eq 0 ]; then \
			echo "  ? $$f (contracts present but no verdict parsed -- gate cannot classify)"; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		desc=""; \
		[ $$v -gt 0 ] && desc="$$v proven"; \
		[ $$u -gt 0 ] && desc="$${desc:+$$desc, }$$u unstated"; \
		[ $$b -gt 0 ] && desc="$${desc:+$$desc, }$$b blocked"; \
		if [ $$u -gt 0 ]; then mark="!"; elif [ $$b -gt 0 ]; then mark="~"; else mark="✓"; fi; \
		echo "  $$mark $$f ($$desc)"; \
		echo "$$out" | awk '/SKIPPED/ { name = $$3 } /Reason:/ { sub(/^ *Reason: */, ""); print "      " name ": " $$0 }'; \
		proven=$$((proven + v)); unstated=$$((unstated + u)); blocked=$$((blocked + b)); \
	done; \
	echo "verify_core: $$proven contracts proven, $$unstated unstated, $$blocked blocked; $$fail files failed, $$bare bare"; \
	if [ "$$unstated" -ne 0 ]; then \
		echo "verify_core: FAIL -- $$unstated contract(s) declare requires with no ensures."; \
		echo "  An incomplete annotation reads as specified and is checked by nothing."; \
		echo "  Add an ensures, or drop the requires. If the fragment rejects the ensures"; \
		echo "  the file becomes 'blocked', which is reported and does not fail."; \
	fi; \
	[ "$$fail" -eq 0 ] && [ "$$unstated" -eq 0 ] || exit 1

verify_ext:
	@proven=0; unstated=0; blocked=0; fail=0; bare=0; \
	for f in $$(find src/core/ext -name "*.ail" ! -name "*_test.ail"); do \
		out="$$(ailang verify "$$f" 2>&1)"; \
		rc=$$?; \
		if [ $$rc -ne 0 ]; then \
			echo "  ✗ $$f"; \
			echo "$$out" | grep -E 'VIOLATION|ERROR' | head -3; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		if echo "$$out" | grep -q "no functions with contracts"; then \
			bare=$$((bare + 1)); \
			continue; \
		fi; \
		v="$$(echo "$$out" | grep -c 'VERIFIED')"; \
		u="$$(echo "$$out" | grep 'Reason:' | grep -c 'no ensures clause')"; \
		b="$$(echo "$$out" | grep -c 'Reason:')"; b=$$((b - u)); \
		if [ $$v -eq 0 ] && [ $$u -eq 0 ] && [ $$b -eq 0 ]; then \
			echo "  ? $$f (contracts present but no verdict parsed -- gate cannot classify)"; \
			fail=$$((fail + 1)); \
			continue; \
		fi; \
		desc=""; \
		[ $$v -gt 0 ] && desc="$$v proven"; \
		[ $$u -gt 0 ] && desc="$${desc:+$$desc, }$$u unstated"; \
		[ $$b -gt 0 ] && desc="$${desc:+$$desc, }$$b blocked"; \
		if [ $$u -gt 0 ]; then mark="!"; elif [ $$b -gt 0 ]; then mark="~"; else mark="✓"; fi; \
		echo "  $$mark $$f ($$desc)"; \
		echo "$$out" | awk '/SKIPPED/ { name = $$3 } /Reason:/ { sub(/^ *Reason: */, ""); print "      " name ": " $$0 }'; \
		proven=$$((proven + v)); unstated=$$((unstated + u)); blocked=$$((blocked + b)); \
	done; \
	echo "verify_ext: $$proven contracts proven, $$unstated unstated, $$blocked blocked; $$fail files failed, $$bare bare"; \
	if [ "$$unstated" -ne 0 ]; then \
		echo "verify_ext: FAIL -- $$unstated contract(s) declare requires with no ensures."; \
		echo "  An incomplete annotation reads as specified and is checked by nothing."; \
		echo "  Add an ensures, or drop the requires. If the fragment rejects the ensures"; \
		echo "  the file becomes 'blocked', which is reported and does not fail."; \
	fi; \
	[ "$$fail" -eq 0 ] && [ "$$unstated" -eq 0 ] || exit 1

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

.PHONY: anchors
# A5's ten attribution anchors, alone and without compiling anything. Split out
# at WI-B4 so a mechanical-edit loop can afford to run it every round: for the
# whole of Milestone B these anchors were only checked by `attribution_table`,
# deep inside `make dst`, which exited 2 before reaching it — and nine of the
# ten drifted unnoticed. `attribution_table` calls this, so there is one copy.
anchors:
	@tools/predicate-anchors/anchors.sh

.PHONY: attribution_table
attribution_table:
	@ailang run --caps IO --entry main scripts/dst/attribution_table_dst.ail < /dev/null
	@$(MAKE) --no-print-directory anchors
	@ailang test src/core/dst_attribution_table.ail > /dev/null && echo "  ✓ src/core/dst_attribution_table.ail"

.PHONY: ext_call_inventory ext_call_inventory_selftest
ext_call_inventory:
	@python3 tools/ext_call_inventory/derive.py

ext_call_inventory_selftest:
	@python3 tools/ext_call_inventory/derive.py --self-test

# ---------------------------------------------------------------------------
# ADR-001 Amendment A, WI-D12: CLASSIFIER 3 -- the extension-closure
# ambient-source inventory. The fourth deferred gate mechanism, admitted
# 2026-08-06 by both acceptance reviewers.
#
# Answers criterion 2 by MEASUREMENT rather than by reading a declared row:
# per extension, whether every effect it can perform arrives through a field
# call on an `ExtPorts`-typed value. A declared row cannot distinguish mediation
# from ambience at any width -- the effect checker gives a port-mediated body and
# a fully ambient one the identical verdict -- so no row-reading instrument can
# stand in for this one.
#
# BOTH TARGETS ARE IN `make dst`, DELIBERATELY, and this comment is the reason.
# Classifier 1's degradation was invisible for thirty-three items because
# neither of ITS targets is: its self-test went from comparing 43 stdlib modules
# to comparing 1, on an unchanged tree, and both targets stayed green. Per plan
# rule S13, a gate outside the aggregate target degrades invisibly whether it
# fails loudly or passes vacuously. Do not move these out.
#
# CACHE PRECONDITION -- stated here, where the target lives, and not only in
# derive.py's docstring:
#
#   The producer is the compiler's own cached per-symbol interface data,
#   .ailang/cache/compile/modules/std__*/iface.json (schema ailang.iface/v1).
#   Every std module an extension's closure imports must have one.
#
#   The tool ESTABLISHES that itself, before deriving, by running
#   `AILANG_RELAX_MODULES=1 ailang check <package>/register.ail` for each of the
#   fifteen extensions -- so neither target depends on the other having run, on
#   `make dst` ordering, or on cache state a reader would have to guess at.
#   `--no-provision` measures what a cold tree would have answered.
#
#   This is the one thing classifier 1 could not do. Its producer needs the
#   stdlib-adjacent cache at ~/.local/share/ailang/std/.ailang/cache/, and WI-D11
#   proved NO repository operation rebuilds it: a 243-file cache-cold sweep
#   leaves it at 0 and `make dst` in full leaves it at 52. Measured two-sided at
#   WI-D12, this producer's cache IS rebuilt by the project's own compilation --
#   from every repo-local `.ailang` removed, the tool's own provisioning restores
#   resolution to 19/19 and reproduces the warm answer exactly.
#
# RESOLUTION IS REPORTED AS A FRACTION AND ENFORCED. Anything short of total is
# exit 1. A green run here means "every extension resolved AND these were
# clean"; it can never mean "the tool found nothing to look at". That
# `agree=0 disagree=0` shape has cost this project two items.
#
# `ext_ambient_inventory_selftest` runs the fixture suite: one fixture per
# unresolvable shape the ADR's acceptance criterion names -- module alias, bare
# module, missing cached interface, symbol absent from the interface, and an
# effect-VARIABLE row -- plus a sixth for a compiler builtin of unknown effect,
# which needs no import and which an import-only inventory therefore never sees.
# `compaction_structural` calls `_list_length` directly, so that door is not
# hypothetical. Each shape is paired with a RESOLVING CONTROL: a rejection-only
# suite is passed by a classifier that resolves nothing. The suite also pins the
# 4-of-15 yield in BOTH directions and asserts the fifteen package directories
# member by member, per plan rule S22 -- `scratchpad` lives at
# `packages/motoko_scratchpad`, so a directory-name resolver silently returns 14.
# ---------------------------------------------------------------------------
.PHONY: ext_ambient_inventory ext_ambient_inventory_selftest
ext_ambient_inventory:
	@python3 tools/ext_ambient_inventory/derive.py

ext_ambient_inventory_selftest:
	@python3 tools/ext_ambient_inventory/derive.py --self-test

# ---------------------------------------------------------------------------
# WI-D15: the same criterion, quantified over HOOKS instead of over the whole
# closure. D5 (`ADR:1295-1300`) says "every hook reachable within that profile";
# Amendment A's property 2 says so too and then picks the transitive CLOSURE as
# the unit that makes the measurement total over hooks. The closure is a sound
# OVER-approximation, not an enlargement of the quantifier -- so registration's
# `std/env` and `std/fs` are inside the UNIT and outside the SCOPE.
#
# This REPORTS a second answer. It does not change `ext_ambient_inventory`'s
# verdict and no profile may rely on it: promoting it is an ADR-scope decision,
# drafted at WI-D15 and not applied.
#
# The split is REACHABILITY-granular, never file-granular, and the tree holds the
# proof that the difference matters: `microrag/register.ail` binds
# `on_tool_handle` to a named function that reaches `std/fs.writeFile` and
# `std/process.exec`, so dropping "the registration module" is FAIL-OPEN.
#
# The selftest pins BOTH yields in both directions -- 4 of 15 closure, 5 of 15
# hook scope -- and the two sets are NOT nested: hook scope adds `mcp` and
# `test_dummy` and DROPS `compaction_structural`, on a door (`show`, a language
# builtin no producer at HEAD can classify) that the closure tool does not watch.
# It also asserts the twin fixtures DISAGREE: same import, same call, different
# position. If they ever agree, the tool is measuring the file again.
# ---------------------------------------------------------------------------
.PHONY: ext_hook_scope ext_hook_scope_selftest
ext_hook_scope:
	@python3 tools/ext_ambient_inventory/derive.py --hook-scope

ext_hook_scope_selftest:
	@python3 tools/ext_ambient_inventory/derive.py --hook-scope-selftest

# ---------------------------------------------------------------------------
# WI-A17: the `ailang test` coverage axis.
#
# `check_core` type-checks src/core/*.ail and never RUNS their inline tests.
# `ailang check` coverage and `ailang test` coverage are SEPARATE AXES and only
# the first had a target -- cluster 4 found session.ail's 21 tests and
# phase_vocab.ail's 27 executed by nothing, and at the time this target landed
# fourteen more files carrying 74 tests were named by no make target at all.
#
# The enumeration is a RECURSIVE WALK, not a list of filenames. A list goes
# stale the first time a file gains tests and nobody edits it, and it goes
# stale silently; `check_core`'s own `src/core/*.ail` glob is the same bug one
# level down, which is why it never saw src/core/test/scripted_ports.ail or
# src/core/ext/runtime.ail. Every .ail file under src/core is discovered and
# run, so a new module is covered the moment it exists.
#
# EVERY RULE READS A COUNT, NEVER AN EXIT STATUS, and the reason is measured:
# `ailang test` prints "All tests passed!" and exits 0 when every test in the
# file was SKIPPED. src/core/prompts_test.ail is in that state at HEAD with six
# tests, and a target built on `ailang test X && echo ok` is green over it.
#
# Skips are tolerated by REASON -- read out of the runner's own JSON and
# recorded in tools/test_coverage/skip_reasons.json with a justification -- and
# never by filename, because a file list is the roster this target exists to
# avoid. A reason no record accounts for is red. Nothing here asserts an
# expected count for any file, so cluster 13's deliberate absence
# (fb_2ad074d754cd2c25 moved a flaky assertion out of a `tests` block on
# purpose) is structurally invisible to it rather than exempted by hand.
#
# It also wires scripts/probe_phase_vocab_sealed.ail WITH INVERTED POLARITY.
# That probe's FAILURE is its PASS: it imports phase_vocab's sealed
# constructors deliberately and the compiler refusing the import is the sealing
# assertion holding, recorded as such by project 004. The check requires IMP010
# NAMING A SEALED SYMBOL -- not merely a non-zero exit, which a syntax error
# would also produce while certifying nothing about sealing.
#
# `test_coverage_selftest` runs the fixture suite: one fixture per rule, each
# asserted BY ITS OWN RULE NAME, plus four survivors that must not be reported
# at all -- mutation testing proves a guard can fire and cannot see a guard
# that fires too much.
# ---------------------------------------------------------------------------
# The sweep's longest target by a factor of three, and therefore the ceiling on
# how fast `make dst` can finish however many cores it is given. Its workers
# each take a private compile-cache lane (see lane_env() in derive.py), which is
# what makes --jobs pay: 207s at --jobs 1, 93s at --jobs 6, findings identical.
TEST_COVERAGE_JOBS ?= 6

.PHONY: test_coverage test_coverage_selftest
test_coverage:
	@python3 tools/test_coverage/derive.py --jobs $(TEST_COVERAGE_JOBS)

test_coverage_selftest:
	@python3 tools/test_coverage/derive.py --self-test

# ---------------------------------------------------------------------------
# agent_confined — the boundary checks for .devcontainer/agent_confined/
#
# Wired here so the container's confinement is regression-tested rather than
# described. Both targets are HOST-SIDE: `agent_confined_check` shells out to
# agent.sh, which refuses to run inside a dev container precisely because the
# legs are statements about the container's definition that a compromised agent
# inside it would misreport. Running either from the devcontainer therefore
# fails with an explanation, which is the intended behaviour and not a bug.
#
# `agent_confined_r7` is the VERIFY leg only. Recording a baseline is a
# deliberate human act — a baseline taken over a planted directive approves it
# — so it is not a make target; the command is in the profile's README.
.PHONY: agent_confined_check agent_confined_r7
agent_confined_check:
	@.devcontainer/agent_confined/agent.sh check

R7_BASELINE ?= $(HOME)/r7-baseline.json
agent_confined_r7:
	@test -f "$(R7_BASELINE)" || { \
	  echo "no baseline at $(R7_BASELINE) — record one FROM A SANITISED TREE first:"; \
	  echo "  .devcontainer/agent_confined/checks/r7_git_audit.py --root \"$$PWD\" --record $(R7_BASELINE)"; \
	  echo "(set R7_BASELINE=<path> to use another location)"; \
	  exit 2; }
	@python3 .devcontainer/agent_confined/checks/r7_git_audit.py --root "$$PWD" --verify "$(R7_BASELINE)"
