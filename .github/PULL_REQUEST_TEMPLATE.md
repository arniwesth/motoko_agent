<!--
Mirror of the `tools/pr/pr.ts` template, for PRs opened by hand in the web UI.

The driver's template is the source of truth: `gh pr create` applies a web
template only interactively, and a web template cannot be machine-filled. If you
change the sections here, change them there too — see ADR-001 D4 in
.agent/projects/016_github_ops/.

Prefer `make pr`, which fills Changes and Governing docs from the branch and
writes the PR number back into .agent/github/prs/.
-->

## Summary

<!-- What this PR does and why, in two or three sentences. -->

## Changes

<!-- The commits, and what they touch. -->

## Governing docs

<!-- Links to the .agent/projects/ documents that govern this change. This is
     what joins the PR to the ledger; do not drop it for brevity. -->

## Predicted outcome

<!-- What landing this should change, and how that will be checked. -->

## Test evidence

<!-- Commands run and their results. -->
