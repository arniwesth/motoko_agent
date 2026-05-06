# M-MOTOKO-PATH-DOUBLING-V2 — Fix write-path doubling in ohMyPi + v2 loop routing

**Status**: Planned (regression confirmed 2026-05-06 smoke test)
**Priority**: P0 — blocks reliable smoke testing; causes agent output to land at wrong path
**Estimated effort**: 0.5 day (~3 hours)
**Dependencies**: None
**Precursor**: `f16421c` (2026-05-06) — fixed path doubling in AILANG-native `validate_path_common`
**Source**: `motoko_explore` run `20260506-190011-openrouter_zai_glm5` (2026-05-06)

---

## Problem

After `f16421c` landed the `wd_bare` check in `tool_runtime.ail`, a new smoke test of the `wire-mcp-extension` task still showed doubled-path writes:

```
# Files touched in WORKDIR after the run:
src/core/ext/mcp/mcp.ail                                                       ← correct
Users/mark/dev/.../motoko_agent/src/core/ext/mcp/mcp.ail                       ← doubled
Users/mark/dev/.../motoko_agent/src/core/ext/registry.ail                      ← doubled
```

The doubled registry.ail had **195 lines** (WriteFile content, fully wired mcp) while the correct-path registry.ail had **182 lines** (EditFile content, partial wiring). This means:
- `EditFile` routed through the AILANG-native path → `validate_path_common` ✓ → correct path
- `WriteFile` routed through the ohMyPi TS dispatcher → no `wd_bare` check → doubled path

**Root cause**: with `ohmy_pi: true` in the dogfood profile and `MOTOKO_AGENT_V2=1`, the v2 loop's `backend_for` routes `WriteFile` to the ohMyPi backend (`ohMyPi/dispatcher.ts`). The ohMyPi dispatcher's `resolvePath` only calls `path.isAbsolute(p)` — it does NOT have the `wd_bare` equivalent from `f16421c`:

```typescript
// ohMyPi/dispatcher.ts line 41-44
function resolvePath(session: OhMyPiSession, p: string): string {
  if (!p) return "";
  return path.isAbsolute(p) ? p : path.resolve(session.cwd, p);
}
```

If the model emits `p = "Users/mark/dev/.../motoko_agent/src/core/ext/registry.ail"` (no leading slash), `path.isAbsolute(p)` returns `false`, and `path.resolve(session.cwd, p)` = `$session.cwd/Users/mark/.../registry.ail` = doubled path. No error is raised.

**Secondary issue**: the v2 loop routing `WriteFile` through ohMyPi at all is questionable. The v2 loop's design doc explicitly says it does not include "Native vs ohmy_pi backend split" — but `backend_for` still reads the `ohmy_pi` config flag. Smoke tests with dogfood profile always have `ohmy_pi: true`.

---

## Fix

### Patch 1: Add `wd_bare` check to `ohMyPi/dispatcher.ts` (~10 LOC)

```typescript
function resolvePath(session: OhMyPiSession, p: string): string {
  if (!p) return "";
  // Reject absolute-without-leading-slash paths (e.g. "Users/mark/.../foo")
  // that would otherwise double the workdir after path.resolve().
  const cwd = session.cwd;
  const cwdBare = cwd.startsWith("/") ? cwd.slice(1) : cwd;
  if (cwdBare && p.startsWith(cwdBare + "/")) {
    throw new Error(`path appears absolute (missing leading slash): ${p}`);
  }
  if (path.isAbsolute(p)) {
    throw new Error(`absolute paths are not allowed: ${p}`);
  }
  return path.resolve(cwd, p);
}
```

This mirrors the AILANG-side logic from `f16421c` exactly. Errors are returned as tool results (the caller wraps thrown exceptions in `result(id, "", message, 1)`).

### Patch 2: Guard in `EditFile` and `BashExec` paths too (~5 LOC each)

The same `resolvePath` is called for `ReadFile`, `WriteFile`, and `EditFile` in `dispatcher.ts`. Since it's centralised, Patch 1 covers all three. But also apply the same check in `env-server.ts` for the native (non-ohMyPi) `WriteFile`/`EditFile` handlers if they have their own path resolution.

### Patch 3: v2 loop — disable ohMyPi backend routing (~5 LOC)

In `src/core/tool_runtime.ail`, `backend_for` checks `ohmy_pi` config. For the v2 loop, native tool dispatch is the intended path. Add an env-var override or a parameter to force AILANG-native routing when `MOTOKO_AGENT_V2=1`:

```ailang
func backend_for(tool: string, ohmy_pi: bool) -> ToolBackend {
  -- In v2 mode, always use native dispatch to avoid the unguarded
  -- ohMyPi TS dispatcher (which lacks the wd_bare path check).
  let v2_mode = getEnv("MOTOKO_AGENT_V2") == "1";
  if v2_mode then Native
  else if ohmy_pi then OhMyPi
  else Native
}
```

This is the cleanest fix: v2 loop + ohMyPi routing was never intentional. Once Patch 1 lands, this patch can be reverted if ohMyPi routing is needed in v2 — but for now it eliminates the routing ambiguity.

---

## Acceptance criteria

- [ ] `wire-mcp-extension` smoke run with `MOTOKO_AGENT_V2=1` dogfood profile produces NO files at doubled paths
- [ ] `ohMyPi/dispatcher.ts` `resolvePath` throws on `"Users/mark/..."`-style paths (unit test)
- [ ] `ohMyPi/dispatcher.ts` `resolvePath` correctly resolves `"src/core/ext/mcp/mcp.ail"` (unit test)
- [ ] `backend_for` with `MOTOKO_AGENT_V2=1` returns `Native` regardless of `ohmy_pi` config
- [ ] `make check_core` still passes

---

## Files

| File | Change |
|------|--------|
| `src/tui/src/ohMyPi/dispatcher.ts` | Add `wd_bare` check to `resolvePath` |
| `src/core/tool_runtime.ail` | `backend_for` returns `Native` when `MOTOKO_AGENT_V2=1` |
| `src/tui/src/ohMyPi/dispatcher.test.ts` (new or update) | Unit tests for path rejection |

---

## Cross-references

- Precursor fix: `f16421c` (AILANG-native `validate_path_common` wd_bare check)
- Source run: `motoko_explore/runs/20260506-190011-openrouter_zai_glm5/NOTES.md`
- Related: `m-motoko-rpc-loop-full-migration.md` (v2 loop feature parity)
