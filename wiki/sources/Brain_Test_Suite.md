# Brain Test Suite: Pre-MVP Testing Plan

## Goal

Establish a solid, layered test suite for the existing `swe/` brain modules before
any self-modification machinery is built. Tests written here become the validation
gate that the Self-Modifying Brain Safe Cutover plan runs against candidate upgrades.

---

## Why This Comes First

The Safe Cutover plan (`Self_Modifying_Brain_Safe_Cutover.md`) requires:
- Phase 1: isolated candidate validation via `ailang check swe/rpc.ail`
- Phase 2: a mandatory smoke test
- Phase 5: `cd tui && npm test` as the upgrade gate

None of those gates test the *semantics* of the brain's pure parsing and formatting
logic. A candidate that passes type-checking and smoke can still silently change the
behaviour of `extract_bash`, `is_done`, or `parse_cwd` — the functions that determine
whether the brain executes commands correctly and knows when it's done.

This plan closes that gap.

---

## Scope

Three pure modules are directly testable without any capability flags:

| Module | Functions | Testing approach |
|---|---|---|
| `swe/parse.ail` | `extract_bash`, `is_done`, `parse_cwd`, `looks_like_shell`, `first_shell_line`, `extract_fence` | Inline tests + properties |
| `swe/prompts.ail` | `with_cache_hint`, `fmt_msgs`, `fmt_obs`, `base_system` | Inline tests + properties + Z3 |
| `swe/agents_md.ail` | `dirname`, `is_root`, `find_last` | Inline tests + Z3 |

`swe/cache.ail` requires `SharedMem` — excluded from this plan.
`swe/env_client.ail` requires `Net` — excluded from this plan.
`swe/rpc.ail` requires `AI`, `Net`, `IO`, `SharedMem` — runtime integration covered
by the `smoke_main` gate in `Self_Modifying_Brain_Safe_Cutover.md` Phase 2. Pure
parsing and formatting logic is tested indirectly via the pure-module tests in
Phases 1–4.

---

## Testing Layers

### Layer 1 — Inline Tests (concrete, high-value)

Inline tests are attached directly to function definitions with `tests [...]`. They
survive any self-modification attempt unchanged — the new code must pass the same
oracle.

**When to use:** Functions with a small, well-understood input domain where the
interesting cases can be enumerated. All parse.ail functions qualify. Use real
LLM output patterns as test inputs — these are the cases that actually matter.

**Limitation:** The string generator in property tests uses only `a-zA-Z0-9` and
will never spontaneously produce `` ```bash `` or `COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`.
Inline tests are therefore the primary tool for `parse.ail`.

### Layer 2 — Property Tests (algebraic laws)

Properties are universally-quantified invariants checked against 100 random inputs
with automatic shrinking to minimal counterexamples. Best suited to algebraic laws
that hold for all inputs rather than specific patterns.

**When to use:** `prompts.ail` formatting functions (identity laws, monotonicity,
containment), `agents_md.ail` path functions (idempotency, monotonicity).

**Limitation:** Random string inputs won't hit sentinel strings, so properties
complement but don't replace inline tests for `parse.ail`.

### Layer 3 — Z3 / SMT Verification (formal, selective)

Z3 proves that a property holds for *all* inputs — not just 100 random samples.
Activated via `ailang ai-check` or `ailang eval-suite --verify`.

**Use where:** The function is simple enough that Z3's string theory terminates
(no recursive string splitting, no `split` calls). Ideal targets are functions
whose correctness is a direct logical identity or a simple boolean invariant.

**Do not use where:** Functions that call `split`, `join`, or recurse over lists
of strings — Z3's string theory is decidable but slow and will time out on these.

---

## Phase 1 — `swe/parse.ail` Inline Tests

Add `tests [...]` directly to each function definition. Test cases are drawn from
actual LLM response patterns observed in production runs.

### `is_done`

Simple containment check. Every test case should be self-documenting.

```ailang
export func is_done(stdout: string) -> bool
  tests [
    -- positive cases
    ("COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT",               true),
    ("some output\nCOMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT\n", true),
    ("prefix COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT suffix", true),
    -- negative cases
    ("",                                                    false),
    ("complete_task_and_submit_final_output",               false),  -- case sensitive
    ("COMPLETE_TASK",                                       false),  -- partial match
    ("no sentinel here",                                    false)
  ]
  = contains(stdout, "COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT")
```

### `looks_like_shell`

Cover every `startsWith` branch plus the false case. One test per prefix token.

```ailang
func looks_like_shell(cmd: string) -> bool
  tests [
    ("cd /tmp",            true),
    ("git status",         true),
    ("ls -la",             true),
    ("ls\nmore",           true),
    ("cat file.txt",       true),
    ("echo hello",         true),
    ("grep foo bar",       true),
    ("find . -name x",     true),
    ("mkdir -p /tmp/x",    true),
    ("curl https://x",     true),
    ("pip install foo",    true),
    ("python script.py",   true),
    ("npm install",        true),
    ("make build",         true),
    ("#!/bin/bash",        true),
    ("export FOO=bar",     true),
    ("source ~/.bashrc",   true),
    ("chmod +x file",      true),
    ("cp a b",             true),
    ("mv a b",             true),
    ("rm -rf /tmp/x",      true),
    -- false cases
    ("",                   false),
    ("  ",                 false),  -- whitespace only, trims to ""
    ("This is prose.",     false),
    ("TODO: fix this",     false),
    ("The result is 42",   false)
  ]
{ ... }
```

### `extract_fence`

Internal helper — test both the matching and non-matching paths, plus the case
where the closing fence is absent.

```ailang
func extract_fence(text: string, fence: string) -> Option[string]
  tests [
    -- basic extraction
    (("```bash\necho hello\n```", "```bash"),      Some("echo hello")),
    -- whitespace trimmed
    (("```bash\n  echo hello  \n```", "```bash"),  Some("echo hello")),
    -- wrong fence: no match
    (("```python\nprint(1)\n```", "```bash"),       None),
    -- no closing fence
    (("```bash\necho hello", "```bash"),            None),
    -- empty content
    (("```bash\n```", "```bash"),                   Some("")),
    -- empty string
    (("", "```bash"),                               None)
  ]
{ ... }
```

### `extract_bash`

Cover all four fence priority levels plus the bare-line fallback. Use realistic
multi-line LLM responses as inputs.

```ailang
export func extract_bash(text: string) -> Option[string]
  tests [
    -- ```bash fence (highest priority)
    ("Here is the fix:\n```bash\necho hello\n```\nDone.",        Some("echo hello")),
    -- ```sh fence
    ("```sh\ngit status\n```",                                   Some("git status")),
    -- ```shell fence
    ("```shell\nls -la\n```",                                    Some("ls -la")),
    -- plain ``` with shell content
    ("```\ncd /tmp\n```",                                        Some("cd /tmp")),
    -- plain ``` with non-shell content: rejected
    ("```\nThis is prose.\n```",                                 None),
    -- bare-line fallback
    ("Let me check:\ngit log --oneline",                         Some("git log --oneline")),
    -- no bash at all
    ("The answer is 42.",                                        None),
    -- empty string
    ("",                                                          None),
    -- ```bash takes priority over ```sh when both present
    ("```bash\necho first\n```\n```sh\necho second\n```",        Some("echo first")),
    -- multiline command
    ("```bash\ncd /tmp && ls -la\n```",                         Some("cd /tmp && ls -la"))
  ]
{ ... }
```

### `first_shell_line`

Recursive scan: returns the first trimmed line that passes `looks_like_shell`.

```ailang
func first_shell_line(lines: [string]) -> Option[string]
  tests [
    -- empty list
    ([],                                      None),
    -- single shell line
    (["echo hello"],                          Some("echo hello")),
    -- trims whitespace before checking
    (["  ls -la  "],                          Some("ls -la")),
    -- skips prose, returns first shell line
    (["The answer is 42", "git status"],      Some("git status")),
    -- returns first match, not last
    (["git status", "ls -la"],                Some("git status")),
    -- no shell lines anywhere
    (["This is prose", "So is this"],         None)
  ]
{ ... }
```

### `parse_cwd`

Test absolute `cd` extraction, compound commands, and all non-matching forms
that must return `current_cwd` unchanged.

```ailang
export func parse_cwd(cmd: string, current_cwd: string) -> string
  tests [
    -- absolute cd: extracts new path
    (("cd /tmp", "/testbed"),                            "/tmp"),
    (("cd /home/user/project", "/testbed"),              "/home/user/project"),
    -- compound: takes the cd target, ignores trailing tokens
    (("cd /testbed && git status", "/old"),              "/testbed"),
    -- relative cd: not handled, returns current
    (("cd ..", "/testbed"),                              "/testbed"),
    (("cd subdir", "/testbed"),                         "/testbed"),
    -- no cd: returns current unchanged
    (("git status", "/testbed"),                        "/testbed"),
    (("ls -la", "/testbed"),                            "/testbed"),
    (("echo hello", "/testbed"),                        "/testbed"),
    -- empty command
    (("", "/testbed"),                                   "/testbed"),
    -- whitespace only
    (("  ", "/testbed"),                                 "/testbed")
  ]
{ ... }
```

---

## Phase 2 — `swe/parse.ail` Property Tests

Properties capture the algebraic laws that must hold regardless of the specific
input. Written in a companion file `swe/parse_test.ail` to avoid cluttering the
implementation.

With the `a-zA-Z0-9` generator, these are no-crash smoke checks; correctness
coverage comes from the inline tests in Phase 1.

```ailang
module swe/parse_test

import swe/parse (extract_bash, is_done, parse_cwd, looks_like_shell)
import std/string (contains)

-- no-crash smoke: is_done does not throw on any alphanumeric input
-- The sentinel is never generated; correctness is covered by inline tests.
property "is_done no-crash on random input" (s: string) =
  match is_done(s) { true => true, false => true }

-- parse_cwd without "cd /" leaves cwd unchanged
property "parse_cwd identity on non-cd input" (s: string, cwd: string) =
  contains(s, "cd /") || parse_cwd(s, cwd) == cwd

-- parse_cwd result always starts with "/" when it changes
property "parse_cwd result is absolute" (s: string, cwd: string) =
  let result = parse_cwd(s, cwd) in
  result == cwd || startsWith(result, "/")

-- no-crash smoke: extract_bash does not throw on any alphanumeric input
property "extract_bash no-crash on random input" (s: string) =
  match extract_bash(s) {
    Some(_) => true,
    None    => true
  }
```

---

## Phase 3 — `swe/prompts.ail` Inline Tests + Properties

### Inline tests

```ailang
export func with_cache_hint(system: string, hint: string) -> string
  tests [
    -- empty hint: identity
    (("sys", ""),
     "sys"),
    -- non-empty hint: exact format (from prompts.ail:58–64)
    (("sys", "use grep"),
     "sys\n## A similar issue was previously resolved\nThe following approach succeeded on a related task. Use it as a starting point:\n\nuse grep\n")
  ]
```

```ailang
export func fmt_obs(cmd: string, r: ExecResult) -> string
  tests [
    -- always prefixed with "$ cmd"
    (("echo hi", {stdout: "hi\n", stderr: "", exit_code: 0}),
     "$ echo hi\n[exit 0]\nhi\n"),
    -- stderr included when non-empty
    (("bad", {stdout: "", stderr: "not found", exit_code: 127}),
     "$ bad\n[exit 127]\n\n[stderr]\nnot found"),
    -- stderr omitted when empty
    (("ls", {stdout: "file\n", stderr: "", exit_code: 0}),
     "$ ls\n[exit 0]\nfile\n")
  ]
```

### Properties for `prompts.ail`

```ailang
module swe/prompts_test

import swe/prompts  (with_cache_hint, fmt_msgs, fmt_obs, base_system)
import swe/types    (Msg, ExecResult)
import std/string   (contains, startsWith)

-- empty hint is identity
property "with_cache_hint empty hint identity" (system: string) =
  with_cache_hint(system, "") == system

-- non-empty hint strictly extends the system string
property "with_cache_hint non-empty extends" (system: string, hint: string) =
  hint == "" || startsWith(with_cache_hint(system, hint), system)

-- fmt_msgs: empty, single, two messages (role ordering preserved)
test "fmt_msgs empty"  = fmt_msgs([]) == ""
test "fmt_msgs single" = fmt_msgs([{role: "user", content: "hello"}]) == "[user]\nhello\n\n"
test "fmt_msgs two"    = fmt_msgs([{role: "user", content: "hi"}, {role: "assistant", content: "hello"}]) ==
                         "[user]\nhi\n\n[assistant]\nhello\n\n"

-- fmt_obs always starts with "$ "
property "fmt_obs has dollar prefix" (cmd: string) =
  startsWith(fmt_obs(cmd, {stdout: "", stderr: "", exit_code: 0}), "$ ")

-- base_system always contains the sentinel instruction
property "base_system contains sentinel" (workdir: string) =
  contains(base_system(workdir), "COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT")

-- base_system contains the workdir
property "base_system contains workdir" (workdir: string) =
  contains(base_system(workdir), workdir)
```

---

## Phase 4 — `swe/agents_md.ail` Inline Tests + Z3

`agents_md.ail` contains pure string-path functions with clean invariants. These
are the best Z3 candidates in the entire brain because they operate on simple
string predicates without `split` loops.

### Inline tests for `dirname` and `is_root`

```ailang
func dirname(path: string) -> string
  tests [
    ("/home/user/file.txt",  "/home/user"),
    ("/home/user/",          "/home/user"),
    ("/file.txt",            "/"),
    ("file.txt",             "."),
    ("/",                    "/")
  ]

func is_root(path: string) -> bool
  tests [
    ("/",        true),
    ("/home",    false),
    ("",         false),
    ("C:",       true),
    ("C:\\",     true),
    ("C:\\foo",  false)
  ]
```

### Z3 targets

These invariants are simple boolean predicates with no string splitting — Z3's
string theory can handle them:

```ailang
-- is_root only holds for short paths: "/" "X:" "X:\"
-- (ensures we never mistake /home or longer paths for root)
@verify
func is_root_length_bound(path: string) -> bool =
  !is_root(path) || str_length(path) <= 3

-- dirname result is always strictly shorter than input (termination guarantee)
-- This is the key property that ensures walk_agents terminates
@verify
func dirname_shrinks(path: string) -> bool =
  path == "/" || str_length(dirname(path)) < str_length(path)
```

**Why these and not `parse.ail`:** `dirname` and `is_root` operate on simple
string length/prefix checks. `is_root` has no loops. `dirname` makes one
`find_last` call but the Z3 string theory handles length comparisons cleanly.
The `dirname_shrinks` property is exactly the termination guarantee for the
recursive `walk_agents` function — formally proving it means the brain can
never hang in an infinite loop during AGENTS.md discovery.

**Do not attempt Z3 on:** `extract_bash`, `extract_fence`, `parse_cwd` — all
use `split` which expands into unbounded string list reasoning that Z3 times out on.

---

## Phase 5 — Wire Into the Upgrade Gate

Once phases 1–4 are in place, add test execution to the upgrade validation pipeline
in `Self_Modifying_Brain_Safe_Cutover.md` Phase 1 (isolated candidate validation):

```
# In UpgradeManager.runCandidateValidation(), after ailang check:
ailang test ${workspace}/swe/parse.ail
ailang test ${workspace}/swe/parse_test.ail
ailang test ${workspace}/swe/prompts_test.ail
ailang test ${workspace}/swe/agents_md.ail
```

**Exit code contract:** `ailang test` exits non-zero when any test fails. The
upgrade manager treats any non-zero exit as a hard failure, identical to how it
treats a failed `ailang check`.

**TypeScript change required:** Add a loop over the four commands above in
`UpgradeManager.runCandidateValidation()` using the existing `spawnWithTimeout`
helper, after the `ailang check` call. The exact file path is not fixed yet —
locate it before implementing, as `Self_Modifying_Brain_Safe_Cutover.md` may not
have been built when this phase runs.

**UI surface:** Failed test output (stdout/stderr from `ailang test`) is included
verbatim in the validation failure message shown in the TUI upgrade log, same as
type-check failures today.

**Semantic drift signal:** A candidate that changes `extract_bash` behaviour must
update the inline tests to match. If the tests are not updated, validation fails.
If they are updated, the reviewer sees exactly which test cases changed — a clear
signal of intentional vs. accidental semantic drift.

Formal verification tiers (Dafny, Lean 4) that sit above this pipeline are
specified in `Brain_Formal_Verification.md`.

---

## Implementation Order

| Phase | Files changed | Effort |
|---|---|---|
| 1 | `swe/parse.ail` — add `tests [...]` to 5 functions | ~2h |
| 2 | `swe/parse_test.ail` — new file, 4 properties | ~1h |
| 3 | `swe/prompts.ail` + `swe/prompts_test.ail` | ~2h |
| 4 | `swe/agents_md.ail` inline tests + Z3 annotations | ~2h |
| 5 | Wire `ailang test` into UpgradeManager validation | ~1h |

Phases 1–5: approximately one day total. Formal verification tiers (Phases 6–7 in
`Brain_Formal_Verification.md`) are independently addable after self-modification
machinery is built.

---

## Future Option: Mutation Testing

### What it is and why it complements property testing

Property testing checks that your invariants hold for randomly-generated inputs.
Mutation testing inverts the question: given your existing tests, are there small
bugs they would *fail to catch*?

A mutation tester automatically introduces targeted faults into the source — flips
`>` to `>=`, changes `"```bash"` to `""`, negates an `if` condition — then runs
the test suite against each mutant. A mutant that survives (all tests still pass)
reveals a gap in the tests.

This is particularly valuable for the self-modification use case. When the brain
generates a new version of `parse.ail`, it might introduce a subtle change that:
- Passes `ailang check` (type-correct)
- Passes the smoke test (process starts, emits events)
- Passes all 100 random property-test cases (no generated input triggers it)
- Silently changes behaviour on `"```sh\n"` fence detection

A mutation test would have caught this by showing that the original test suite
can't distinguish the correct `"```sh\n"` from `"```sh"` — and forcing the test
author to add a case that kills the mutant before the suite is considered adequate.

### Implementation estimate

The AILANG AST is well-suited. The key integration point already exists:

```go
// runner.go — already callable with any *ast.File
func RunTestsFromFile(filePath string, ast *ast.File) (*SuiteResult, error)
```

A mutation tester is a loop over (clone AST → apply one mutation → call
`RunTestsFromFile` → check if any test fails). The pieces needed:

| Component | Difficulty | Notes |
|---|---|---|
| AST deep copy | Medium | ~200 lines; no `Clone()` exists yet |
| Mutation operators (BinaryOp, Literal, If) | Easy | Change one field per mutation |
| String literal mutations | Easy | `"```bash"` → `""`, `"cd /"` → `"cd "` |
| Mutation site collector | Easy | Walk `FuncDecl.Body`, exclude `FuncDecl.Tests` |
| Reporter (survived / killed counts) | Easy | Reuse `SuiteResult` |
| Parallel execution | Medium | Each mutant needs its own evaluator instance |

**Estimated effort:** 1–2 days for a targeted implementation covering the brain
modules (`BinaryOp`, `Literal`, `If` condition negation, string constant mutations).

### How the two techniques divide the work

| Technique | Finds | Misses |
|---|---|---|
| Inline tests | Known-bad inputs; LLM output patterns | Unknown edge cases |
| Property tests | Algebraic violations for any random input | Inputs outside generator charset |
| Z3 verification | Proves invariant for *all* inputs | Complex string ops (times out) |
| Mutation testing | Gaps in test sensitivity | Equivalent mutations; type-incorrect mutations |

The four techniques are almost perfectly complementary. Inline tests provide the
oracle; properties catch structural violations; Z3 gives formal guarantees on simple
invariants; mutation testing measures how well the tests would detect a LLM-generated
subtle bug.

### Recommended integration point

After the test suite is written (phases 1–4), run the mutation tester once to
establish a **mutation score baseline** for `parse.ail`. Require that self-modification
candidates achieve at least the same score. A candidate that weakens the tests
(removes cases to make its own mutations survive) would be caught by a score
regression check.
