# M-MOTOKO-Z3-CONTRACTS

**Status**: Planned  
**Priority**: P2 — quality/trust, not on critical path  
**Estimated effort**: 2-3 days  
**Dependencies**: None (Z3 4.15.4 ships with AILANG distribution; `ailang verify` runs today)  
**Source**: motoko-explore inbox msg `3719d2dd` (2026-05-06)

---

## Problem

motoko's pure-core modules have zero AILANG formal contracts. Running `ailang verify` on any `src/core/*.ail` today returns:

```
0 functions: no functions with contracts
```

The Z3 solver is available and wired up. The gap is that no `requires { ... }` / `ensures { ... }` blocks have been authored for the existing pure functions. This is a missed opportunity: the pure-core / effectful-edges architecture motoko already has is primed for Z3 verification, but the contract annotations don't exist.

This matters now because:

1. **Compaction** (`m-motoko-conversation-compaction.md`) adds `elide_old_tool_results` and `compact_step` — pure functions with provable length-preservation and content-bound properties. Writing these with contracts means shipping them with a Z3 *proof*, not just unit-test examples.

2. **Extensions-as-packages** (`m-motoko-extensions-as-packages.md`): once extensions are independently distributed, contracts become the formal interface contract. An ext declaring `ensures { result.tool_calls.length >= 1 }` on its hook gives the runtime a machine-auditable promise.

3. **Self-modification dogfood**: requiring contracts on new pure code drives the agent toward writing provably-correct code from the start.

---

## Goals

1. Add `make verify_core` as a first-class CI target (mirrors `check_core`; stays green today with 0 contracts)
2. Annotate the easy-win pure functions with `requires`/`ensures` blocks
3. Establish a per-PR policy: every new `pure func` in `src/core/` needs a contract or a justification comment
4. Integrate `verify_core` into `make build` gate

---

## Design

### Phase 1: `make verify_core` target (~0.5 days)

Add to `Makefile`:

```make
verify_core:
	@ok=0; fail=0; skipped=0; \
	for f in src/core/*.ail; do \
		case "$$f" in \
			*_test.ail) continue ;; \
		esac; \
		out="$$(ailang verify "$$f" 2>&1)"; \
		case "$$out" in \
			*"no functions with contracts"*) \
				echo "  - $$f (no contracts yet)"; \
				skipped=$$((skipped + 1)) ;; \
			*"FAIL"*|*"unverified"*) \
				echo "  ✗ $$f"; \
				echo "$$out" | tail -5; \
				fail=$$((fail + 1)) ;; \
			*) \
				echo "  ✓ $$f"; \
				ok=$$((ok + 1)) ;; \
		esac; \
	done; \
	echo "verify_core: $$ok proven, $$fail failed, $$skipped without contracts"; \
	[ "$$fail" -eq 0 ] || exit 1
```

CI stays green on day 0 (all skipped). As contracts are added, `proven` rises and `skipped` falls — the metric tracks progress without blocking existing work.

Also add `make verify_ext` covering `src/core/ext/**.ail` using the same pattern.

### Phase 2: Contract sweep — easy wins (~1.5 days)

All properties listed below are already implemented by the function body; the contract just makes the claim machine-checkable.

**`src/core/compress.ail`**

| Function | Contracts |
|---|---|
| `truncate_with_suffix(text, max_chars)` | `requires { max_chars >= 0 }` · `ensures { length(result) <= max_chars + length("... (truncated)") }` |
| `compress_output(text, max_chars)` | Same shape — the bound is the load-bearing claim |
| `collapse_spaces(text)` | `ensures { length(result) <= length(text) }` (spaces only shrink) |
| `trim_non_empty_lines(lines)` | `ensures { _list_length(result) <= _list_length(lines) }` |

**`src/core/context_usage.ail`**

| Function | Contracts |
|---|---|
| `estimate_tokens(msgs, system)` | `ensures { result >= 0 }` |
| `context_limit_for(model)` | `ensures { result >= 0 }` |

The `context_limit_for` table (expanded per msg `c4da6d7`) can also prove specific non-zero bounds for known model strings — Z3 can verify the dispatch table exhaustively.

**`src/core/compaction.ail`** (new, landed in branch)

| Function | Contracts |
|---|---|
| `estimate_tokens_messages(msgs)` | `ensures { result >= 0 }` |
| `usage_percent(msgs, model)` | `ensures { result >= 0 && result <= 100 }` — load-bearing for the threshold logic |
| `count_tool_msgs(msgs)` | `ensures { result >= 0 && result <= _list_length(msgs) }` |
| `elide_old_tool_results(msgs, k)` | `requires { k >= 0 }` · `ensures { _list_length(result) == _list_length(msgs) }` (length preserved) |

**`src/core/agents_md.ail`**

| Function | Contracts |
|---|---|
| `dirname(path)` | `ensures { length(result) <= length(path) }` |
| `is_root(path)` | No non-trivial contract; justify with `-- trivial: returns bool` |

**`src/core/parse.ail`** (legacy, being phased out post-M9)

| Function | Contracts |
|---|---|
| `extract_bash(text)` | `ensures { result == None || (match result { Some(s) => length(s) <= length(text), None => true }) }` — extracted content never exceeds input |

### Phase 3: Policy + lint check (~0.5 days)

Add to `CONTRIBUTING.md`:

> Every new `pure func` in `src/core/` MUST have:
> - `requires { ... }` / `ensures { ... }` contracts, OR
> - A comment: `-- contracts: N/A — trivial boolean / wrapper / too complex for Z3`

Add a lint rule to CI: scan for `pure func` declarations lacking both a contract block and the justification comment. A simple `grep` gate suffices until a proper linter target exists.

---

## Files

| File | Change |
|------|--------|
| `Makefile` | Add `verify_core`, `verify_ext` targets |
| `src/core/compress.ail` | Add `requires`/`ensures` to `truncate_with_suffix`, `compress_output`, `collapse_spaces`, `trim_non_empty_lines` |
| `src/core/context_usage.ail` | Add `ensures` to `estimate_tokens`, `context_limit_for` |
| `src/core/compaction.ail` | Add contracts on `usage_percent`, `count_tool_msgs`, `elide_old_tool_results` |
| `src/core/agents_md.ail` | Add `ensures` to `dirname`; justify others |
| `CONTRIBUTING.md` | Pure-func contract policy |
| `.github/workflows/` or `Makefile` | `verify_core` in CI gate |

---

## Acceptance criteria

- [ ] `make verify_core` runs without failure (0 contracts today → 0 failures)
- [ ] `compress.ail` contracts: Z3 proves `truncate_with_suffix` and `compress_output` length bounds
- [ ] `context_usage.ail` contracts: Z3 proves `estimate_tokens >= 0` and `context_limit_for >= 0`
- [ ] `compaction.ail` contracts: Z3 proves `usage_percent` in `[0, 100]` and `elide_old_tool_results` length-preserving
- [ ] `make verify_core` reports `>= 5 proven, 0 failed`
- [ ] CONTRIBUTING.md updated with pure-func policy
- [ ] CI gate added

---

## Open questions

1. **When does `verify_core` block CI?** Today it can be advisory (fails only on `FAIL`, not on `skipped`). As coverage rises, we can tighten to "all functions must have contracts" — but that's a future ratchet.
2. **Z3 timeout tuning**: the default timeout may be too short for the `context_limit_for` table (large dispatch tree). Can set `ailang verify --timeout 60` per-module.
3. **Extension contracts**: `src/core/ext/*.ail` contains effectful hooks — Z3 can't verify those. Restricting contracts to `pure func` only is the correct boundary.
