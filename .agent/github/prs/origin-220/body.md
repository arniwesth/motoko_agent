---
repo: arniwesth/motoko_agent
pr: 220
branch: fix/tool-catalog-unique-names
ticket: null
title: "fix(tool_catalog): send each tool name to the model once (#204)"
---

## Summary

An extension that wraps a native tool claims its name with a `ToolProvider`, and the catalog then
sent that name to the model twice: once with the native schema and once with a synthesised
name-only one. Anthropic, Gemini and xAI reject a request with duplicate tool names, so the shipped
`microrag` profile, and any profile that loads `ailang_tools`, failed on its first model step with
those providers. `tools_with_extensions` now keeps the first schema for each name, which for a
wrapped native tool is the native one.

This is the second ask of #204. The first, letting a profile hide native tools, is not in this PR.

#235 makes the same change to `tools_with_extensions`. It was written independently (its commit is
dated 2026-10-02, three days before this branch's first) and this PR supersedes it: the three
inline tests and the gate added here pass against #235's implementation, so the two behave the
same.

## Changes

- `src/core/tool_catalog.ail`: `tools_with_extensions` keeps one schema per tool name. The first
  occurrence wins: native schemas come before extension schemas, and an earlier registry entry
  comes before a later one, which is the entry `first_handle` consults first. Three inline tests
  cover the two registration shapes involved (`ailang_tools`: native names claimed, no
  `DescribeTools`; `microrag`: a native name claimed beside a `DescribeTools` that returns `[]`),
  an extension that declares its own schema under a native name, and two extensions declaring the
  same name.
- `scripts/dst/tool_catalog_registry_dst.ail` and `make tool_catalog_registry`: the catalog built
  from the real registrations. For `microrag` and `ailang_tools` in both orders, and for every
  installable extension at once, it checks that the wrapper is actually loaded, that every name
  appears once, and that each native schema is unchanged. The all-extensions list is derived from
  `src/core/ext/registry_generated.ail`.
- `Makefile`, `.github/workflows/verify-extensions.yml`: the new target is in `make dst` and in
  CI's "DST AILANG gates — rest" step.

4 files changed.

Not changed: what happens when an extension declares its own schema for a native name. The native
schema is kept and the extension's is dropped, as the comment on `tools_with_extensions` says.
Whether an extension may replace a native schema is a design question, not part of this fix.

## Governing docs

None on `main`. Issue #204 is the request. A proposed ADR for the issue's first ask (a native-tool
allowlist) is being drafted separately; this fix does not depend on it.

## Predicted outcome

- **A profile with `microrag` or `ailang_tools` runs on Claude, Gemini and Grok models.** Before,
  the first model step came back as `ProtocolError: Provider returned error`; upstream, the
  provider had answered 400 (`tools: Tool names must be unique.` from Anthropic,
  `Duplicate function declaration found: WriteFile` from Google,
  `Duplicate function definition provided: WriteFile` from xAI). Checked below with one live step
  per provider through `live_ports`' own `model_step`.
- **Nothing changes for a profile that loads no wrapper.** The request body for the default
  profile's extension order is byte-identical before and after (34 tools), and so is the
  no-extension request (7 tools). Checked below by capturing both on a loopback endpoint.
- **A change to what the catalog holds can fail a gate.** Until now none could: no scripted
  provider is sent the catalog, so with `tools_with_extensions` returning `[]`, `make check_core`
  stayed green and `make dst` went red only in `test_coverage`, through this module's own two
  count tests. `make tool_catalog_registry` is the check from here on.

## Test evidence

On this branch with `main` at `37f92741` merged in (2026-10-08), AILANG v0.47.2:

```
ailang test src/core/tool_catalog.ail     8 tests: 8 passed
make tool_catalog_registry                tool_catalog_registry PASS (20 extensions registered, 74 tools)
make check_core                           green, exit 0 (60 passed, 0 failed)
make dst                                  54 targets, all passed (3544 s wall, -j8)
make new_contract_policy                  2 in-scope new pure funcs, both justified; 17 more test-only
make verify_classify_check                OK, register agrees
make verify_core                          16 contracts proven, 1 blocked, 0 files failed
```

Both new checks fail without the fix. With the one line in `tools_with_extensions` put back:

```
ailang test src/core/tool_catalog.ail     8 tests: 5 passed, 3 failed (the three new tests)
make tool_catalog_registry                FAIL count=9
  order: microrag                         ✗ every name once (8 tools) — sent more than once: WriteFile
  order: ailang_tools                     ✗ every name once (10 tools) — sent more than once: ReadFile,WriteFile,EditFile
  all 20 extensions                       ✗ every name once (78 tools) — sent more than once: ReadFile,WriteFile,EditFile
```

`make tool_catalog_registry` also passes with the `HERDR_*` variables unset, as in CI (72 tools).

Inside the sweep, `test_coverage` reports `src/core/tool_catalog.ail: 8/8 passed` and
`tool_catalog_registry` passes. The six targets that were red when this PR was opened
(`declared_vs_performed`, `driver_plus_compose`, `driver_plus_no_ops`,
`ext_ambient_inventory_selftest`, `ext_hook_scope` and `ext_hook_scope_selftest`) were red on
`main` too and have since been fixed there; they pass in this sweep.

The merge with `main` had one conflict, in `.github/workflows/verify-extensions.yml`: `main` added
`ext_hook_scope` and `ext_hook_scope_selftest` to the "DST AILANG gates — rest" step on the line
where this branch added `tool_catalog_registry`. The step runs all three.

Against #235's implementation of `tools_with_extensions` (its two helpers in place of this
branch's): the inline tests go 9/9 (#235's one test plus this branch's three new ones) and
`make tool_catalog_registry` passes.

The live steps and the request-body capture below were run on 2026-10-05, before the merge, and
were not repeated after it.

Live, one model step each through `stub_step.live_ports(rt).model_step` via OpenRouter, asking the
model to write `hello` to `notes/a.txt`:

| `extensions.order` | Model | `main` | This branch |
|---|---|---|---|
| `microrag` | anthropic/claude-haiku-4.5 | `ProtocolError: Provider returned error` | ok, `WriteFile {"path": "notes/a.txt", "content": "hello"}` |
| `microrag` | google/gemini-2.5-flash-lite | `ProtocolError: Provider returned error` | ok, `WriteFile` with `path` and `content` |
| `ailang_tools,microrag` | anthropic/claude-haiku-4.5 | not run | ok, `WriteFile` with `path` and `content` |
| `ailang_tools,microrag` | x-ai/grok-4.3 | not run through `model_step`; the captured request replayed directly got a 400 | ok, `WriteFile` with `path` and `content` |

Providers that accepted the duplicate before (DeepSeek V4 Flash, Muse Spark 1.3, Qwen 3.7 Flash,
Mistral Small 3.2, and OpenAI models on Azure) were not re-run on this branch. OpenAI's own API was
not tested at all.

"Accepted" holds only for the routes sampled here. #235 reports that on
`deepseek/deepseek-v4-flash-0731` the outcome depended on which provider OpenRouter routed to:
Relace and Sail Research answered 400 (its author's measurement of 2026-10-02, from OpenRouter's
Broadcast traces), and six concurrent eval runs on that model went 6/6 with the same fix. Neither
figure was reproduced here.

Request bodies, captured on a loopback OpenAI-shaped endpoint with `src/core/tool_catalog.ail` from
`origin/main` and from this branch:

```
default profile's extension order    tools before=34 after=34    request bodies identical=True
no extensions                        tools before=7  after=7     request bodies identical=True
```

Not run: the TUI test suite. No TypeScript is touched.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
