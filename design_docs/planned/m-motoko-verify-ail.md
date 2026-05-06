# M-MOTOKO-VERIFY-AIL

**Status**: Planned — blocked on AILANG `ailang verify <file.ail>` runtime mode (see Prerequisite)  
**Priority**: P2 — DX / dogfood quality, not on critical path  
**Estimated effort**: 5-7 days (4 motoko-side; +2 for AILANG-side `ailang verify` runtime mode if not already shipped)  
**Dependencies**: AILANG `ailang verify <module.ail>` as an agent-invocable runner; `motoko-verify` package or stdlib addition  
**Source**: motoko-explore inbox msg `5481bdc0` (2026-05-06)

---

## Problem

Every `motoko_explore` dogfood task ships with `seed/verify.sh` — a portable shell script that runs N independent post-condition checks against the agent's WORKDIR after motoko exits. Example from `wire-mcp-extension`:

```bash
[[ -f "src/core/ext/mcp/mcp.ail" ]]
check "src/core/ext/mcp/mcp.ail exists" $?

grep -qE "export[[:space:]]+func[[:space:]]+register_with_config" src/core/ext/mcp/mcp.ail
check "mcp.ail exports register_with_config" $?

make check_core >/tmp/check_core.log 2>&1
check "make check_core" $? "see /tmp/check_core.log"
```

This works, but is structurally weak:

- **Not type-checked.** A typo in a check predicate fails silently as "passed" or vice versa. We've already had a case where `grep -c '✓'` returned 0 for a fail because the verifier itself crashed before printing.
- **No structured output.** Just stdout we have to parse; the harness can't distinguish "setup failed" from "correctness failed".
- **Outside AILANG provenance.** Verify runs don't appear in `ailang chains view`. There's no way to ask "show me every verification stage of the wire-mcp dogfood across all model runs."
- **No replay.** Can't `ailang replay verify-trace.jsonl` to re-execute a verification against a snapshot.
- **No composition.** Each task copy-pastes its own `check()` function. Common checks (file-exists, grep-for-export, type-check-passes, no-regression) are reinvented per task.

---

## Prerequisite: AILANG `ailang verify <verify.ail>` runner

The proposed `verify.ail` modules require AILANG to run them in a "verifier" mode — i.e., execute a module whose `main()` returns a `Verifier` result rather than `()`. This is a new AILANG runtime mode, similar to how `ailang test <file.ail>` runs `tests [...]` blocks.

**Capability check** (to perform before starting motoko-side work):
- Does `ailang verify <file.ail>` exist as a CLI subcommand? 
- If not, is it in the AILANG roadmap (`design_docs/planned/v0_17_0/` or later)?
- Can the motoko-side `verify.ail` modules work today using `ailang run` with a structured exit code? (Fallback option.)

**Mitigation if not available**: implement `verify.ail` modules as standard `ailang run` programs that exit 0/1 and write structured JSON to stdout. `bin/run-task` reads the JSON. Less elegant but unblocked.

---

## Goals

1. Replace `seed/verify.sh` with `seed/verify.ail` — a type-checked, effect-bounded AILANG module
2. `bin/run-task` reads `VerifierResult` JSON instead of grepping stdout
3. Verify runs appear as chain stages in `ailang chains view`
4. Common check patterns extracted into a `motoko-verify` library package
5. Existing `verify.sh` kept as a generated fallback for non-AILANG environments

---

## Design

### `verify.ail` module shape

```ailang
module tasks/wire_mcp_extension/verify

import std/fs (exists, read)
import std/string (contains)
import std/process (exec)
import motoko/verify (Verifier, Check, pass, fail, run_all,
                      file_exists, exports_function, type_checks,
                      make_target_passes, grep_matches)

export func main() -> Verifier ! {FS, Process} =
  run_all([
    file_exists("src/core/ext/mcp/mcp.ail"),
    exports_function("src/core/ext/mcp/mcp.ail", "register_with_config"),
    type_checks("src/core/ext/mcp/mcp.ail"),
    type_checks("src/core/ext/exa_search/exa_search.ail"),  -- regression
    make_target_passes("check_core")
  ])
```

Run via:
```bash
ailang run tasks/wire_mcp_extension/verify.ail --workdir runs/<id>/motoko_agent
```

Returns a `Verifier { passed: int, failed: int, checks: [CheckResult] }` and writes structured JSONL trace. Type-checking catches typos at compile time. Effect row `{FS, Process}` declares exactly what the verifier touches — can't accidentally call out to a network.

### `motoko/verify` package — check library

A `motoko-verify` package exposes common check primitives. All return `Check ! {FS | Process | ...}` — pure descriptions that `run_all` executes:

| Function | Effect | Description |
|---|---|---|
| `file_exists(path)` | `FS` | Path exists (file or dir) |
| `file_contains(path, pattern)` | `FS` | File content matches regex |
| `exports_function(file, name)` | `FS` | `export func <name>` present |
| `type_checks(file)` | `Process` | `ailang check <file>` exits 0 |
| `make_target_passes(target)` | `Process` | `make <target>` exits 0 |
| `grep_count(path, pattern, op, n)` | `FS` | Match count satisfies `op n` |
| `json_field_present(path, field)` | `FS` | JSON file has named field |
| `no_regression(file)` | `FS, Process` | `ailang check <file>` still passes |

Each check is a lazy value (function taking a workdir) — `run_all` evaluates them sequentially, captures result, logs JSONL event per check.

### `VerifierResult` schema

```json
{
  "schema_version": 1,
  "passed": 4,
  "failed": 1,
  "checks": [
    { "label": "src/core/ext/mcp/mcp.ail exists", "status": "pass", "duration_ms": 2 },
    { "label": "mcp.ail exports register_with_config", "status": "pass", "duration_ms": 5 },
    { "label": "ailang check mcp.ail", "status": "fail", "reason": "TYPE027: ...", "duration_ms": 340 },
    { "label": "ailang check exa_search.ail", "status": "pass", "duration_ms": 310 },
    { "label": "make check_core", "status": "pass", "duration_ms": 2100 }
  ]
}
```

`bin/run-task` reads this JSON rather than parsing stdout, enabling machine-readable pass/fail per check.

### Chain integration

`run_all` emits a chain stage event on start and a stage-complete event on finish, using `MOTOKO_CHAIN_ID` / `MOTOKO_TASK_ID` if available (complements `m-motoko-chain-provenance.md`). The verify stage appears in `ailang chains view <chain-id>` alongside the agent stage.

### Migration path

1. Implement `motoko-verify` library package
2. Port one existing `verify.sh` to `verify.ail` as proof (wire-mcp-extension)
3. Update `bin/run-task` to prefer `verify.ail` if present, fall back to `verify.sh`
4. Port remaining `verify.sh` files incrementally
5. Generate `verify.sh` from `verify.ail` as optional fallback (AILANG → bash transpilation or manual port)

---

## Files

| File | Change |
|------|--------|
| New package: `motoko-verify` | `Check`, `Verifier`, `run_all`, check library — ~200 LOC |
| `tasks/*/verify.ail` | Replace `verify.sh` per task — ~30 LOC each |
| `motoko_explore/bin/run-task` | Read `VerifierResult` JSON; fall back to `verify.sh` |
| `ailang` CLI (AILANG repo) | `ailang verify <file.ail>` mode — or use `ailang run` with structured exit (see Prerequisite) |
| `CONTRIBUTING.md` | Document `verify.ail` convention for new tasks |

---

## Acceptance criteria

- [ ] `motoko-verify` package exports `file_exists`, `exports_function`, `type_checks`, `make_target_passes`, `run_all`
- [ ] `wire-mcp-extension/verify.ail` type-checks and runs against a valid motoko WORKDIR
- [ ] `VerifierResult` JSON written to stdout on completion
- [ ] `bin/run-task` reads `VerifierResult` JSON — no stdout parsing
- [ ] Verify stage appears in `ailang chains view <chain-id>` when `MOTOKO_CHAIN_ID` set
- [ ] `verify.sh` preserved as fallback; still works unchanged
- [ ] A newly written `verify.ail` with a typo (wrong function name) fails `ailang check` immediately

---

## Open questions

1. **`ailang verify` vs `ailang run`**: if the `ailang verify <file.ail>` runtime mode doesn't exist yet, does it need an AILANG design doc first? (Probably yes — tag as a prerequisite for the AILANG sprint.) Alternatively, `verify.ail` modules can work as plain `ailang run` programs that exit 0/1 + write JSON to stdout.
2. **`motoko-verify` placement**: core AILANG stdlib vs. separate package? Separate package ships faster and doesn't require AILANG version bump. But `ailang test` is in core — `ailang verify` as its runtime analog belongs in core too. Answer depends on whether `ailang verify` mode lands in AILANG.
3. **Effect-row for checks**: `type_checks` and `make_target_passes` need `{Process}`. `file_exists` needs `{FS}`. The combined `run_all([...])` signature needs `{FS, Process}`. This is fine but means `verify.ail` modules always declare both — slightly over-broad. Acceptable for v1.
4. **Backward compatibility with `verify.sh`**: generating a `verify.sh` from `verify.ail` is desirable but non-trivial. V1 keeps both in sync manually; generation is a follow-up.
