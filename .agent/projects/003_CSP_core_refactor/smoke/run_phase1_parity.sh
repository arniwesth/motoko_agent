#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SMOKE="$ROOT/.agent/projects/003_CSP_core_refactor/smoke"

cd "$ROOT"

ailang check src/core/agent_loop_v2.ail
ailang check src/core/tool_runtime.ail
ailang check src/core/tool_select_frames.ail
ailang test src/core/test/integration_tests.ail
ailang test src/core/agent_loop_v2.ail
ailang test src/core/tool_select_frames.ail

cd "$SMOKE"
ailang run --caps Stream,Process,IO smoke_async_exec_name_routing.ail
ailang run --caps Stream,Process,IO smoke_async_exec_stderr_exit.ail
