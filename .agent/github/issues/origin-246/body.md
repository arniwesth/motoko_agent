---
repo: arniwesth/motoko_agent
issue: 246
title: "The committed ailang.lock goes stale without anything noticing: every run in a fresh checkout warns that motoko_ext_herdr changed"
---

## Summary

`ailang.lock` on `main` records a content hash for `sunholo/motoko_ext_herdr` that no longer
matches `packages/motoko-ext-herdr`. Every `ailang` command in a checkout that has not run
`make sync_packages` prints a two-line warning, and since #239 a plain headless run shows both
lines as `[warning]` on stderr. The immediate fix is a re-lock; the reason to file it is that
nothing can notice when it happens again.

## Context

**Repro (`main` @ `21a8a96a`, AILANG v0.47.2), in a fresh checkout or worktree:**

```sh
ailang check src/core/config.ail
```

```
Warning: dependency sunholo/motoko_ext_herdr content changed (locked: sha256:e1e96240660e9c037..., current: sha256:6928b495ef76aff83...)
Run 'ailang lock' to update
```

**How it got stale.** `ailang.lock` last changed in `84ea6a71` (2026-10-05, "re-lock after
d7d9dea3"), on a branch that did not yet contain #194. #194 changes `packages/motoko-ext-herdr`
(two commits and its merge, `b863ee20`). Both are on `main` now, and the lock still has the
herdr hash from before #194: neither side re-locked for the other.

**Why nothing noticed.**

- `make sync_packages`, which `make build` runs, ends with `ailang lock`. So a developer who
  builds gets a correct lock locally, and a modified `ailang.lock` in their working tree that
  nobody is prompted to commit. One long-used checkout carries exactly that today, uncommitted:
  the new `content_hash` for herdr and a new `generated_at`, two lines.
- CI hydrates the packages and re-locks before it uses them (`.github/actions/dst-setup`), so it
  never sees the committed lock as it is.
- The lock records each `path` dependency as an absolute path
  (`.github/workflows/dst-corpora.yml` explains the cost of that), so the committed file is
  specific to `/workspaces/motoko_agent` and a plain "re-lock and diff" check would be red on any
  other machine for a reason that is not staleness.

**Who sees it.** Anything that runs `ailang` without building first: `make motoko`, a fresh
worktree, `scripts/run-agent.sh` called directly. Before #239 the headless host dropped these
lines; it now prints every runtime warning.

## Expected

- `main`'s `ailang.lock` matches its packages: the repro prints no warning. A re-lock run from
  `/workspaces/motoko_agent`, so the absolute paths stay the ones the file has, is the whole fix.
- A gate that fails when a committed `content_hash` differs from what the package's content
  hashes to, comparing hashes only and ignoring the absolute paths and `generated_at`. It has to
  read the committed file before anything re-locks it, which in CI means before `dst-setup`'s
  hydration or in a job that does not hydrate.
- Or, if a committed lock that is only correct after a local re-lock is the intended state, say so
  where `sync_packages` is defined, and stop the warning being the first thing a fresh checkout
  prints.
