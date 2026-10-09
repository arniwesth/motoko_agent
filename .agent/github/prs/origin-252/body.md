---
repo: arniwesth/motoko_agent
pr: 252
branch: chore/profiles-hybrid-off
ticket: null
title: "chore(profiles): hybrid mode is off in every profile"
---

## Summary

All sixteen tracked profiles set `tools.hybrid` to true. Each now sets it to false, so core no
longer turns a prose answer into a shell command on those profiles.

This is the operator's ruling of 2026-10-09: hybrid mode (the loop's "DP6") is to be removed.
This pull request switches it off where a profile can. Removing the mechanism from core is
planned in #249.

**What hybrid mode does.** When a response has no tool call and the session has not yet made a
native one, core searches the text (`extract_bash`, `src/core/parse.ail:118-135`). It takes the
first ` ```bash `, ` ```sh ` or ` ```shell ` fence, then a bare fence whose body looks like shell,
and failing those the first line of prose that starts with one of 21 prefixes such as `git `,
`make ` or `rm `. It runs what it finds as a `BashExec` call instead of treating the answer as
final.

**How it has been used.** Of 1,103 session logs on this machine, 28 contain a
`hybrid_bash_extracted` event.

- In 26 the model was also making typed tool calls. What was extracted was mostly an example or
  an instruction written for a person: a `docker compose` line, a `herdr plugin install`,
  `git apply tmp/bake-herdr-dagr.patch` 18 times in one session.
- In 2 it was the session's only way to run a tool: `ibm-granite/granite-4.1-8b` on the
  `default` profile on 2026-05-11, and a local `gemma-4-26B` on the `local` profile on
  2026-06-07.
- None since 2026-09-06, when extraction was limited to sessions that have made no native call.

**What is given up.** A model that writes a shell block instead of emitting a typed tool call
can no longer act on these profiles. The two sessions above are the only ones found that worked
that way.

**What this does not do.**

- **The code default is still true** (`src/core/config.ail:372`), and so is the TUI's profile
  template (`src/tui/src/config.ts:109`, `:167`). A profile that leaves the key out, or one made
  from the template, still has hybrid mode on.
- **`SYSTEM.md:92-97` is not edited.** It describes hybrid mode as "Optional, Off By Default".
  For the tracked profiles that is now true.
- **Nothing in core changes.** The extraction code, its wire event and the `hybrid_tools`
  parameter stay until the plan in #249 removes them.

## Changes

- chore(profiles): hybrid mode is off in every profile

16 files changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`, Amendment 2
  (proposed in #249).
- `.agent/issues/hybrid-bash-extracts-prose-examples-in-native-tool-mode.md`, whose non-goal "do
  not remove hybrid mode" the operator has now overruled.

## Predicted outcome

- **No session on a tracked profile has a `hybrid_bash_extracted` event.** Checked by any session
  log after this lands.
- **A prose answer is a final answer from the first response on.** Before, a session's first
  response could be executed if it held a fence or a shell-looking line.
- **CI is unchanged.** No gate reads `tools.hybrid` from a tracked profile. Checked by this pull
  request's checks.

## Test evidence

Run on 2026-10-09 at `38068013` and at this branch's `a4f74c34`, AILANG v0.52.5.

- [x] **The runtime's own loader reads the profiles as off.** `ailang run --entry
  print_config_json src/core/config.ail` with `MOTOKO_CONFIG` set to `default`, `local`, `ollama`
  and `demo_dst`: `tools.hybrid` is `true` on `main` and `false` on this branch for all four.
  That value is what the loop is started with (`src/core/rpc.ail:280`).
- [x] **Nothing else in the sixteen files changed.** Each was parsed before and after, and the
  two values are equal once `tools.hybrid` is set to false in the first.
- [x] **No tracked profile is left with hybrid on,** counting a missing key as on.
- [x] **`make verify_extensions smoke_no_delegated_storm` passes on this branch.**
- [x] **The usage figures were computed from the session logs** in the main checkout's
  `.motoko/logfile/`, which is gitignored: 1,103 logs scanned, 28 with the event, 2 of those with
  no `native_tool_calls` event at all.
- [ ] The 26 extractions called "mostly an example" were judged from the command text and the
  number of native calls in the same session, not by reading each session.
- [ ] No live session was run.
- [ ] `make check_core`, `make test` and `make dst` were not run. No code or script changed.
- [ ] CI had not finished when this was written.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
