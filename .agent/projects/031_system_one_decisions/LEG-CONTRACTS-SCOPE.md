# LEG-CONTRACTS-SCOPE — §4's scope by reachability: test-only declarations out

You are a delegate of the 031 orchestrator (pane `w3:p5X`). This implements a **ruling already made** by the
operator on 027 ADR-001 §4 — see `.agent/projects/027_z3_contracts/QUESTION-2026-09-24-test-scaffolding-in-scope.md`,
section **ANSWERED**, committed at `f6c3768b`. **Read that section first; it contains the reasoning and the
measurements the ruling rests on, and it is the spec.** You do not re-open the decision. You do not write the
dagr run file, and you do not touch other panes or worktrees.

## The ruling, in one line

A `pure func` in `src/core/` that is **reachable ONLY from a `tests [...]` block** is out of §4's scope.
Everything else stays in scope, unchanged.

## Why it must be reachability, and not something cheaper

Measured on the 83 declarations currently held (do not re-derive unless you doubt it — `make
new_contract_policy BASE=origin/main_dst`):

| slice | count of 83 |
|---|---:|
| named `test_*` | **14** |
| under a `test/` path | **4** |
| inside production files (`ext/runtime.ail` 51, `ext/registry_normalize.ail` 22, `tool_catalog.ail` 4, `dst_profile_coverage.ail` 2) | **79** |

A naming convention catches 17%, a path rule 5%. **Neither is acceptable.** The scope has to come from the
call graph.

## What to build

`tools/verify_classify/new_contract_policy.py` (234 lines) already walks the diff and the declarations. Add
the reachability pass: a declaration is exempt iff every path that reaches it starts in a `tests [...]`
block. Reachable from production **at all** — even if also reachable from tests — means **in scope**.

Requirements, in order of how badly they can bite:

1. **Exempt means unreachable from production, not "looks like a test".** If your implementation can be
   fooled by a name, a prefix, a directory or a comment, it is the wrong implementation.
2. **Self-correcting by construction.** The day a fixture is called from production it must enter scope with
   nobody editing an annotation or a list. If your design needs a maintained exemption list, say so and stop
   — that is reading 3 wearing a disguise, and the operator rejected reading 3 for exactly that reason.
3. **Be honest about indirection.** Say plainly what your pass does with higher-order calls, aliases, or a
   function referenced but not applied. If the analysis cannot see through something, the safe default is
   **in scope** (fail toward requiring a contract), never exempt.
4. **The 83 are a prediction, not a target.** If the pass leaves some of them in scope because they really
   are reachable from production, that is a correct result and they need real contracts — report which and
   why. Do not tune the analysis until the number comes out at 83.

## Done means

1. The pass lands with the reasoning in the tool where the next reader finds it.
2. `make new_contract_policy BASE=origin/main_dst` reports its new figure, and you state the number with the
   list of anything still in scope and why.
3. **A mutation gate.** At minimum: (a) a test-only helper made reachable from production must become
   **in scope** and turn the gate red; (b) a production declaration must not become exempt by being named
   `test_*`, moved under a `test/` path, or commented as test-only; (c) restoring returns it to green. A
   gate that cannot be made to fail is not evidence.
4. A **draft amendment to §4's text** recording the scope, for 027 to adopt — draft it, do not adopt it
   yourself; §4 is 027's document.
5. CI green on the result, or red only for reasons that are not this.

## Constraints

- **Heavy runs one at a time**; the memory guard's `flock` is the rule. Check the box is quiet first — it is
  shared with other sessions and a contended walk produces misleading timings.
- **Never run `git stash`** — other sessions have uncommitted work in this tree.
- **No session content, credentials or host addresses** in a brief, a record, a fixture or a commit. This
  repo is **public**.
- You may push to `arniwesth/031-abi-8-0` and dispatch CI. Use `gh api` rather than the `gh pr`/`gh issue`
  porcelain: the token lacks `read:org`, which those subcommands demand for unrelated metadata.
- Do not touch `tools/test_coverage/`, `scripts/line_guard.sh` or `scripts/ci_guarded_shell.sh` — recently
  settled by other legs.

Report a typed envelope: the mechanism, the new count with anything still in scope, the mutation-gate
results, the draft §4 amendment, and anything you touched beyond the above.
