---
repo: arniwesth/motoko_agent
pr: 170
branch: arniwesth/mot-111-attach-the-pr-to-its-linear-issue-from-toolspr-not-by-hand
ticket: MOT-111
title: "MOT-111: attach the pr to its linear issue from toolspr not by hand"
---

## Summary

`make pr` publishes a PR and writes a state record, but nothing linked the PR back to its Linear
issue — that was done by hand, and forgotten, which is how #168 was noticed unlinked. `finalize()`
in `tools/pr/pr.ts` now makes that link: it is the one function both the create and the adopt path
already pass through, and it already derives `MOT-<n>` from the branch for the frontmatter.

**A finding that changes MOT-111's premise, and does not change its answer.** The issue was filed on
the measurement that Linear's native GitHub integration does not fire for this repo (#168, a genuine
description edit, no linkback, MOT-102 untouched). Opening this very PR measured the opposite: the
integration attached #170 to MOT-111 by itself, within seconds of creation, and lost a race to this
code by doing so — the first run printed
`linear: Duplicate attachment for duplicate url`. So the integration is **intermittent**, not
absent. That still argues for doing it here: an intermittent link is the same problem as no link,
because nobody reading the issue can tell whether an absent attachment means anything. It did change
the code — a duplicate error is now read as success, since whoever created the link, the link
exists.

## Changes

- Added terminal settings
- pr: attach the PR to its Linear issue from finalize(), not by hand
- pr: treat a duplicate-URL error as already-linked, not as a failure

**`tools/pr/linear.ts`** (new) — one exported call, `attachToIssue(ticket, url, title)`, speaking
GraphQL to `https://api.linear.app/graphql` through `curl`. Two rules govern it:

- **Never fatal.** No `LINEAR_API_KEY`, no `mot-<n>` in the branch, an unreachable API, a GraphQL
  error or a missing `curl` each log one line and return. A PR that failed to publish because a
  tracker was down is strictly worse than one that published unlinked.
- **Idempotent, including against the integration.** `attachmentLinkURL` errors rather than no-ops
  on a URL already attached to the issue, so the issue's attachments are read first and a match
  short-circuits — and because the App can attach in the gap between that read and the write, a
  duplicate error is treated as success.

**`tools/pr/pr.ts`** — `finalize()` calls it on both paths. Notably it also calls it on the
record-already-exists path, so a run that lost the link to a missing key or a network failure
retries on the next `make pr` rather than being skipped forever.

**`tools/pr/lib.ts`** — `botToken()`'s `.env` reader generalised to `fromDotenv(name)` so the Linear
key resolves by the same environment-then-`.env` rule; `note()` added alongside `die()` so a
non-fatal aside carries the same program prefix.

**`tools/pr/README.md`** — the link, its two rules, the intermittency measurement, and the identity
caveat.

### Decisions taken, since MOT-111 left them open

- **GraphQL directly** (022 option B) rather than Linear's MCP server (option A). This is one
  mutation inside a synchronous pipeline, not an agent-facing tool surface, and MCP would add a Node
  bridge subprocess to a file that is `spawnSync` top to bottom.
- **Kept synchronous.** `curl` via `spawnSync`, matching `gh()` in `lib.ts`. `pr.ts`'s `main()` is
  called synchronously at the bottom of the file; making the publish path async to reach `fetch()`
  would be a refactor with no caller asking for it.
- **The key never enters argv**, where `ps` would show it to every process on the box. It goes to
  curl in a stdin config (`curl -K -`), and the request body rides in a `mkdtemp` directory because
  `-K -` has already claimed stdin — and because a JSON document embedded in curl's own config
  format is a second escaping layer with nothing to recommend it. A key containing a quote or a
  backslash would break out of that config line, so it is refused with a named reason rather than
  mangled.
- **Attachment title is `#<n> <PR title>`**, so the Linear card identifies the PR without opening it.
- **The variable stays `LINEAR_API_KEY`**, which is what `.env` and the container environment
  already carry. 022 §4 argues for `MOTOKO_BOT_LINEAR_KEY` if a dedicated Linear seat is ever
  bought; that is that decision's to make. Until then attachments read as the key's owner rather
  than as `motoko-agent` — the attribution collapse ADR-001 D1/C9 rejected for GitHub, recorded here
  rather than quietly accepted. This PR's own attachment is visible proof: its creator is
  `Arni Westh Hansen`.

`.devcontainer/agent_confined/` in the diff is the operator's own commit already on this branch, not
part of this work.

## Governing docs

- `.agent/projects/022_linear_integration/RESEARCH-linear-integration.md` — §2 option B is what this
  implements; §4 (whose Linear account an agent acts as) is the open question it declines to settle.
- `.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md` — D4 (the file on disk is the
  source of truth, the key is written back) is the pattern this extends to a second tracker; D1/C9
  is the identity rule it cannot yet honour.

Neither document is edited by this PR, so `pr_draft` could not derive them.

## Predicted outcome

Every `make pr` on a branch carrying a `mot-<n>` segment leaves the PR attached to that issue, with
no manual step, and nobody has to remember — whether or not Linear's integration happens to fire
that day. Re-running `make pr` prints `linear: MOT-111 already links …` and changes nothing, and
`make pr` with `LINEAR_API_KEY` unset still publishes.

Falsifiable failure: a later PR on a `mot-<n>` branch that lands with no attachment on its issue and
no line in the `make pr` output saying why.

## Test evidence

**End to end, on this PR.** #170 was published by `make pr`, and the attachment now on MOT-111 was
created by `tools/pr/linear.ts`:

```
$ make pr BASE=arniwesth/mot-102-…        # first run: the App won the race
pr: linear: Duplicate attachment for duplicate url
pr: linear: MOT-111 not linked to https://github.com/arniwesth/motoko_agent/pull/170
pr: created #170 — https://github.com/arniwesth/motoko_agent/pull/170

# the App's attachment deleted, so the driver's own path could be proven
$ make pr BASE=…
pr: linear: linked https://github.com/arniwesth/motoko_agent/pull/170 to MOT-111

$ make pr BASE=…                          # and again: idempotent, real API
pr: linear: MOT-111 already links https://github.com/arniwesth/motoko_agent/pull/170
```

MOT-111 then held exactly one attachment, titled
`#170 MOT-111: attach the pr to its linear issue from toolspr not by hand`. That first run is also
the whole reason the duplicate-error branch exists, and it is the honest reading of it: the
read-first check narrows the race but cannot close it.

**Against the real Linear API, before publishing, cleaning up after itself.**

```
$ bun t-linear.ts
--- 1. no ticket (branch without mot-<n>): expect silence
--- 2. first attach: expect 'linked'
pr: linear: linked https://github.com/arniwesth/motoko_agent/pull/999999 to MOT-111
--- 3. re-run, same URL: expect 'already links', no error
pr: linear: MOT-111 already links https://github.com/arniwesth/motoko_agent/pull/999999
--- 4. trailing slash variant: expect 'already links' (normalised)
pr: linear: MOT-111 already links https://github.com/arniwesth/motoko_agent/pull/999999/
--- 5. unknown ticket: expect one line, no throw
pr: linear: could not read MOT-999999 (Entity not found: Issue) — not linked to …/pull/999999
--- done, process still alive
exit=0
```

Both probe attachments were removed with `attachmentDelete`, and MOT-111's attachment list verified
back to `[]` before this PR was opened.

**Every non-fatal path, each exiting 0 with the process alive.**

| Path | Forced by | Output |
|---|---|---|
| No key at all | `.env` moved aside + `env -u LINEAR_API_KEY` | `linear: no LINEAR_API_KEY — MOT-111 not linked to …` |
| Bad key | `LINEAR_API_KEY=lin_api_definitelynotarealkey` | `linear: could not read MOT-111 (Authentication required, not authenticated) …` |
| Unsafe key | `LINEAR_API_KEY='ab"cd'` | `linear: … (LINEAR_API_KEY contains a quote or backslash — refusing …)` |
| Network down | `ALL_PROXY=http://127.0.0.1:9` | `linear: … (curl failed (curl: (7) Failed to connect …))` |
| No ticket | `attachToIssue(null, …)` | silent, as a branch without a ticket is an ordinary case |

`.env` was restored and verified in the same shell invocation that moved it.

**The race, and a non-duplicate error, both driven deterministically** by a fake `curl` on `PATH`
that answers the read with `nodes: []` and the write with an error:

```
write says "Duplicate attachment for duplicate url"
  → pr: linear: MOT-111 already links …/pull/170 (attached by something else while this ran)
write says "Some other Linear error"
  → pr: linear: MOT-111 not linked to …/pull/170 (Some other Linear error)
```

**The key does not reach argv.** The same fake `curl` captured its own argv and stdin:

```
ARGV: -sS -K - -X POST https://api.linear.app/graphql -H Content-Type: application/json
      --data-binary @/tmp/pr-linear-upUiLH/body.json --max-time 15
STDIN-CONFIG: header = "Authorization: <<<KEY>>>"
```

The key appears only in the stdin config. The redaction above is the harness substituting on the
real key's value, which is how it was verified rather than eyeballed.

**No regressions in the rest of the driver.** `bun tools/pr/{pr,issues,sync,loop}.ts --help` all
exit 0 after the `lib.ts` change, and `make pr_whoami PR_FLAGS=--as-bot` still reports
`bot: motoko-agent`.

## Not covered

- **No automated test.** `tools/` still has no harness (README "Known gaps"); everything above was
  run by hand. `linear.ts` reaches the network through a single `curl` call for the same reason
  `lib.ts` funnels `gh` and `git`, so the fake-binary-on-`PATH` trick that gap describes — already
  used twice above — is the shape a real check should take.
- **Why the integration is intermittent** is not diagnosed. It needs `admin:repo_hook`. Worth its
  own issue if the App's linkbacks are ever wanted for something this driver does not cover.
- **Attribution.** Attachments read as the key's owner, not as `motoko-agent`. 022 §4.
- **`--dry-run` does not exercise this**, deliberately: it returns before `finalize()`, and a dry run
  that wrote to a tracker would not be dry.
