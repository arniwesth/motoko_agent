---
repo: arniwesth/motoko_agent
pr: 251
branch: chore/profiles-drop-finalize-verification
ticket: null
title: "chore(profiles): no profile runs make check_core at finalize"
---

## Summary

Eight profiles enabled the DP7 verifier with Motoko's own `make check_core`: `ailang`, `default`,
`demo_dst`, `dogfood`, `mark`, `observability`, `omnigraph` and `skills`. Each now has the empty
`verification` block the other eight profiles already had. The runtime's default is off, so no
command runs when a model gives its final answer.

This is the operator's ruling of 2026-10-09 on open question OQ-A6 of Amendment 1 to 005 ADR-001
(#249): there is no scenario in which this should be triggered automatically.

Why it was a problem:

- **It ran on every non-blank final answer**, whether or not the run had written any code.
- **It judged the whole repository.** `check_core` has 15 prerequisite targets and a type-check of
  every core module.
- **When the command could not pass, the session could not finish.** Two sessions looped on it:
  320 rejections on 2026-10-08 and 57 on 2026-10-09.

**What is given up.** DP7 was added in May after a model shipped three hallucinated stdlib names
and said it was done. On these profiles nothing now checks the tree before a run ends. A model
that should verify its work has to run the check itself.

**What this does not do.** The verifier's code stays in core, and a profile can still turn it on.
Removing it from core is what #249 proposes. #250 is still worth landing: it makes
`verify_native_path_guard` pass when a model runs it by hand inside a session.

**`mark` is a collaborator's profile.** It is changed with the other seven because the ruling
covers every profile. It is one line to put back.

**It goes against 028 ADR-001**, which is Proposed and says the gate should be fail-closed and
"non-configurable for shipped profiles". That record is not edited here. #249 lists it among the
text the amendment supersedes.

**A checkout with a local edit to one of these files will not fast-forward.** The operator's
shared checkout has an uncommitted model change in `.motoko/config/default/config.json`, which
this pull request also changes. Until it is pulled there, sessions started from that checkout
still run the verifier.

## Changes

- chore(profiles): no profile runs `make check_core` at finalize

8 files changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`, Amendment 1
  (proposed in #249), open question OQ-A6.
- `.agent/projects/028_verified_runtime_closing_the_loop/ADR-001-fail-closed-verification-everywhere.md`,
  which this goes against.

## Predicted outcome

- **A session on any tracked profile ends on the model's final answer without running a
  command.** Checked by a session log with a `done` event and no `dp7_verifier_rejected` event.
- **A final answer no longer waits for `make check_core`.** That was 164 s and 183 s on cold
  caches once the command could pass (#250).
- **No tracked profile enables verification.** Checked: the loader probe below, over all sixteen.

## Test evidence

Run on 2026-10-09 at `36a96b1e` and at this branch's `6e68b179`, AILANG v0.52.5.

- [x] **The runtime's own loader reads all eight as disabled.** A probe that calls
  `load_runtime_config()` from `src/core/config.ail` and prints `cfg.verification.enabled`, with
  `MOTOKO_CONFIG` set to each profile. That value is what `run_dp7_verifier` branches on
  (`src/core/session.ail:2242`).

  | | `main` | this branch |
  |---|---|---|
  | `ailang`, `default`, `demo_dst`, `dogfood`, `mark`, `observability`, `omnigraph`, `skills` | `true` | `false` |
  | `local` (control, already empty) | `false` | `false` |

- [x] **Nothing else in the eight files changed.** Each file was parsed before and after, and the
  two values are equal once `verification` is set to `{}` in the first.
- [x] **No tracked profile is left with verification enabled.** All sixteen were parsed.
- [x] **`make verify_extensions` on this branch:** `verify_extensions (default): 9 booted, 0
  failed`.
- [ ] **No live session was run.** The claim that no command runs rests on the loader's value and
  on reading `run_dp7_verifier`.
- [ ] `make check_core`, `make test` and `make dst` were not run. No code or script changed.
- [ ] CI had not finished when this was written.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
