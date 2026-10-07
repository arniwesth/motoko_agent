---
repo: arniwesth/motoko_agent
pr: 231
branch: fix/dst-baseline-test-dummy-registration
ticket: null
title: "fix(ext): make dst is green again — test_dummy registers one literal list, and the strict check builds its own empty registration"
---

## Summary

`make dst` has been red on a clean `main` since 2026-10-01, on four targets with one cause:
`3159797d` (#206) gave the `test_dummy` extension an `if` that registers no capability atom when
`EXT_DUMMY_REGISTER_NOTHING=1`. The registration rule wants `caps` to be a literal list, the
registration-shape gate fails an installable extension that computes it, and two profile checks
read that gate's result. This restores the fixture and keeps the check the `if` was added for.

**Host startup code changes**, not only a fixture: the registry generator and the generated
`src/core/ext/registry_generated.ail`. It is an extraction with the same messages, exit codes and
conditions. The operator chose it over dropping the check's "registers nothing" case.

**A workflow file changes:** `.github/workflows/verify-extensions.yml`. The "DST gates (rest)" job
runs two more targets, so the gate that was red is one CI runs.

## Changes

- fix(ext): test_dummy registers one literal list again; the strict check builds its own empty registration
- chore(dst): empty DST_KNOWN_RED — both listed targets pass
- ci: run ext_hook_scope and its self-test in the "DST gates (rest)" job

6 files changed.

| file | what |
|---|---|
| `packages/motoko-ext-test-dummy/register.ail` | the `if` and its comment removed; byte for byte the file before `3159797d` |
| `tools/ext_registry_gen/generate.py` | the template moves the decision on one resolved registration out of `parse_tokens` into an exported `admit_registration(id, reg, cfg)` |
| `src/core/ext/registry_generated.ail` | regenerated from that template |
| `scripts/verify_strict_extensions.ail` | an `empty` mode: loads the probe profile and hands `admit_registration` an empty registration built in the script |
| `Makefile` | `verify_strict_extensions` has four arms where it had three; `DST_KNOWN_RED` is empty |
| `.github/workflows/verify-extensions.yml` | `ext_hook_scope ext_hook_scope_selftest` added to one step, and its timing comment |

## Governing docs

- `packages/motoko-ext-abi/types.ail`, "REGISTRATION RULE (B2)": the list is a literal list of
  constructor applications; a conditional element or a computed tail is not certifiable
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`, D2
  layer (a): the registration-shape result, one per installable extension, which
  `tools/ext_ambient_inventory/hook_scope.py` computes
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`: how the three
  mutants below were run and read

## The cause, and why the fixture changes and not the gate

On `main` the inventory reports:

```
test_dummy              None              fail    caps-computed, return-shape-unsupported
REGISTRATION SHAPE: pass 19 of 20; fail 1
```

- `ext_hook_scope` exits on that field alone.
- `ext_hook_scope_selftest` pins `test_dummy` as hook-port-mediated with its atom count, and four
  of its rows fail.
- `driver_plus_no_ops` and `driver_plus_compose` call `check_no_op_profile.hook_scope_atoms`,
  which fails for any extension not read as `config-caps`.

The gate enforces a decided rule, and a list selected by a condition is one of the shapes that
rule names as rejected. So the gate is right and the fixture was wrong. No CI job ran any of the
four targets, which is why `main` stayed red unnoticed.

## What keeps the "registers nothing" refusal tested

The `if` existed so `make verify_strict_extensions` could reach one refusal: under
`extensions.strict`, an extension that registers no capability atom must stop the start. With the
rule obeyed, no installable extension can produce an empty registration on demand.

- **Before:** `parse_tokens` normalised each resolved registration inline and decided to admit it,
  omit it with a warning when empty, or print an error and exit 2.
- **After:** that block is `admit_registration`, and `parse_tokens` calls it. The check calls it
  too, with an empty registration and the configuration a real probe profile loaded.

What this costs, stated plainly:

- **One new export from a host module.** It grants nothing `normalize_registration` did not
  already: that function is exported and builds the same entry.
- **The check is less end to end for this case.** It used to go profile, boot, resolve
  `test_dummy`, refusal. It now goes profile, configuration, `admit_registration`. The lines of
  `parse_tokens` that call it run on every boot, with non-empty registrations only.
- **One difference on paper.** After `exit(2)` the old code returned the entries so far; the new
  function returns "omit" and the loop would go on. Observable only if `exit` returned.

Not chosen: dropping the case (undoes the #205 review follow-up and leaves the refusal untested);
a test-only extension that always registers nothing (a 21st installable extension, with every
per-extension table and count that follows); letting the gate accept the `if` (amends D2).

## Predicted outcome

Written to `tmp/fix-dst-baseline/prediction.md` at 10:38 UTC on 2026-10-07, in the sweep's first
minutes and before any result of it was read:

1. `make dst` exits 0; the four targets pass and no other target changes. **Held.**
2. The closing summary carries two notes, `driver_plus_herdr` and `herdr_graded` listed in
   `DST_KNOWN_RED` but passed. **Held**, and the second commit empties the list.
3. `make check_core` exits 0 with four OK lines from `verify_strict_extensions`. **Held.**

After this lands, a sweep on a clean `main` should end "all targets passed" with no note, and a
conditional registration in any installable extension should turn the "DST gates (rest)" job red.
The second claim is checked by this pull request's own CI run only in the green direction.

## Test evidence

All on `bb47e33f` plus the first commit, in a worktree, AILANG v0.47.2.

| check | result |
|---|---|
| `make dst` | exit 0, "all targets passed", 2,307 s (clean `main` at `59d5cbb9`: exit 2, four red) |
| `make check_core` | exit 0, 224 s |
| `make verify_strict_extensions` | four OK lines |
| `make ext_hook_scope` | exit 0, "pass 20 of 20; fail 0" (before: exit 2, "pass 19 of 20; fail 1") |
| `make ext_hook_scope_selftest` | exit 0, 0 failures (before: 4 failing rows) |
| `make driver_plus_no_ops`, `make driver_plus_compose` | exit 0, 39 s and 89 s |
| `make registry_gen_check` | the generated file matches the generator |
| `make verify_classify_check`, `verify_ext`, `verify_core` | exit 0 each |
| `make new_contract_policy` | exit 0, "no pure func added under src/core/ since origin/main" |

Three mutants of `admit_registration`, applied to the generated file one at a time and restored
(`registry_gen_check` green afterwards). Each is a kill only by the arm that names its rule:

| mutant | arm that went red | its line |
|---|---|---|
| the strict refusal no longer exits | strict + empty | `FAIL strict/empty: rc=0` |
| `cfg.extensions.strict` replaced by `false` | strict + empty | `FAIL strict/empty: rc=0` |
| the lax side returns the entry | lax + empty | `FAIL an empty registration was admitted (strict=false)` |

The arms before the red one stayed green. The recipe stops at its first failing arm, so under
the first two mutants the fourth arm did not run.

For the known-red list: the summary re-rendered from the same sweep log with the list emptied
reads "all targets passed" with no note. `d5edebf2` had written the list's "REMOVED 2026-09-14"
note and left the variable unchanged.

For the workflow change: 15 s and 20 s from an empty cache lane; the longest line either target
prints is 287 characters, against the line guard's 16384. The edited file parses as YAML and the
job's timeout is unchanged. Whether the two targets pass on the runner is what this pull
request's CI run shows; it had not run when this was written.

## Not done here

- `tools/ext_registry_gen/fixtures/abi8/` was already out of date with the generator before this
  change (its `registry_gen_check` fails on `main`) and nothing runs it. Left as found.
- `driver_plus_no_ops` and `driver_plus_compose` are still in no CI job. They read the gate that
  now runs there.
- `src/core/dst_attribution_table.ail` cites line ranges of the generated registry in two
  comments; they were stale before this change and still are.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
