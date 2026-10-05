---
repo: arniwesth/motoko_agent
pr: 221
branch: feat/banner-ailang-version
ticket: null
title: "feat(tui): banner — show the AILANG release version beside the build time"
---

## Summary

The startup banner printed only the AILANG build time, which says nothing about which release is
running. It now also prints the release version that `ailang --version` reports on its first line:

```
Motoko 素子 (AILANG v0.47.2, built 2026-09-28_16:35:23) TUI v0.1.0 | Core Runtime v0.2.0
```

If the binary reports no version line, the banner keeps the old `AILANG built …` form.

## Changes

- feat(tui): banner — show the AILANG release version beside the build time

1 file changed.

## Governing docs

None. This is a one-file display change requested by the operator.

## Predicted outcome

The first line under the banner names the AILANG release as well as its build time. Checked by
starting Motoko (`make motoko`) and reading that line.

Not changed: the dim `AILANG built … | Core Runtime … | TUI …` line in the history pane and the
transcript. That value round-trips through the core runtime as `ailang_built`, so adding the
version there is a `src/core` change and is left out of this PR.

## Test evidence

```
cd src/tui && tsc --noEmit         clean
make build_tui                     builds
```

The banner expression was evaluated against the real `ailang --version` output (v0.47.2) and
produced the line in the Summary. The TUI itself was not launched and the jest suite was not run.
