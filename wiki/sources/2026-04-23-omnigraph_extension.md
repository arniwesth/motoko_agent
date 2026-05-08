• Implemented the Omnigraph extension plan across core runtime, extension wiring, scaffold assets, and installer/docs.

  What Changed

  - Added full Omnigraph graph scaffold under omnigraph:
      - omnigraph/schema.pg, omnigraph/omnigraph.yaml, queries/mutations, seed data, agent catalog, validator.
  - Added new extension modules under src/core/ext/omnigraph:
      - src/core/ext/omnigraph/types.ail, src/core/ext/omnigraph/exec.ail, src/core/ext/omnigraph/guardrail.ail, src/core/ext/
        omnigraph/prompts.ail, src/core/ext/omnigraph/omnigraph.ail, src/core/ext/omnigraph/omnigraph_test.ail.
  - Wired Omnigraph into core types/dispatch/parser:
      - src/core/types.ail, src/core/parse.ail, src/core/ext/types.ail, src/core/ext/registry.ail, src/core/ext/runtime.ail,
        src/core/rpc.ail, src/core/prompts.ail, src/core/tool_runtime.ail, src/core/parse_test.ail.
  - Updated install/docs for optional Omnigraph source build:
      - scripts/install-prerequisites.sh now supports --with-omnigraph.

  - New tool request variants: OmnigraphRead, OmnigraphMutate, OmnigraphBranch, OmnigraphStatus.
  - New result variant: OmnigraphResult.
  - CORE_EXT_ORDER=omnigraph registration and runtime dispatch support.
  - on_build_system_prompt: injects cached omnigraph/AGENT_PROMPT.md content.
  - on_tool_policy: denies OmnigraphMutate when branch == "main".
  - on_tool_handle: executes Omnigraph CLI with fixed branch arg ordering and no positional repo.omni.

  Verification Run

  - Passed:
      - ailang check src/core/types.ail
      - ailang check src/core/ext/runtime.ail
      - ailang check src/core/rpc.ail
      - ailang check src/core/parse.ail
      - ailang check src/core/prompts.ail
      - ailang check src/core/tool_runtime.ail
      - ailang test src/core/parse_test.ail
      - ailang test src/core/ext/registry.ail
      - ailang test src/core/ext/omnigraph/omnigraph_test.ail
  - Not executable in current env:
      - omnigraph/validate.sh failed early with omnigraph binary not found on PATH.

  Next Steps

  1. Run ./scripts/install-prerequisites.sh --with-omnigraph.
  2. Run ./omnigraph/validate.sh.
  3. Smoke-run agent with CORE_EXT_ORDER=omnigraph and confirm tool round-trips in trace.jsonl.
