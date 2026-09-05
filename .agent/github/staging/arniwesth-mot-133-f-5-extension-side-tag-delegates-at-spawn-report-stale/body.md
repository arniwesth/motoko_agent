---
repo: arniwesth/motoko_agent
pr: null
branch: arniwesth/mot-133-f-5-extension-side-tag-delegates-at-spawn-report-stale
ticket: MOT-133
title: "MOT-133: f 5 extension side tag delegates at spawn report stale"
---

## Summary

Herdr delegation integration: tag delegate panes at spawn (MOT-133), write the dagr run file from the extension (MOT-136), reap this session's panes on clean exit (MOT-134), auto-open the live dagr view (MOT-137) — plus a live-measured review round (elapsed wording, post-wait status, evidence-tier honesty, dagr-pane pin derivation) reviewed SHIP-WITH-NITS by a motoko delegate.

## Changes

- MOT-133: tag delegates at spawn, report stale orphans at first call
- MOT-136: the extension writes the dagr run file
- MOT-134: close this session's delegate panes on a clean exit, opt-in
- Handoff: record what landed and what the two stop-and-report triggers found
- F-5: ship the agent_confined reap-on-exit change as an appliable patch
- Docs updates
- Code updates

52 files changed.

## Governing docs

- `.agent/projects/021_herdr_delegation/DESIGN-dagr-as-delegation-view.md`
- `.agent/projects/021_herdr_delegation/DESIGN-f5-orphan-ownership.md`
- `.agent/projects/021_herdr_delegation/HANDOFF-2026-09-02-run-file-truth-view-and-loop-guard.md`
- `.agent/projects/021_herdr_delegation/HANDOFF-2026-09-03-patch-state-and-what-remains.md`
- `.agent/projects/021_herdr_delegation/HANDOFF-implement-f5-and-dagr-producer.md`
- `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-08-31-dagr-contract.md`
- `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-08-31-token-survival.md`
- `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-02-run-file-truthfulness.md`
- `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-03-first-live-dagr-run.md`
- `.agent/projects/021_herdr_delegation/NOTE-2026-09-03-herdr-under-dst.md`
- `.agent/projects/021_herdr_delegation/PATCH-agent-confined-allowed-kinds.md`
- `.agent/projects/021_herdr_delegation/PATCH-agent-confined-dagr-pane.md`
- `.agent/projects/021_herdr_delegation/PATCH-agent-confined-reap-on-exit.md`
- `.agent/projects/021_herdr_delegation/TESTPROMPT-integration-exercise.md`
- `.agent/projects/028_verified_runtime_closing_the_loop/NOTE-005-third-session-compaction-blind-spot-and-ungated-examples.md`
- `.agent/projects/028_verified_runtime_closing_the_loop/NOTE-006-harness-compaction-resilience-and-boundary-analysis.md`
- `.agent/projects/028_verified_runtime_closing_the_loop/NOTE-007-the-loop-that-would-not-stop.md`
- `.agent/projects/028_verified_runtime_closing_the_loop/NOTE-008-fourth-session-long-demo-uncatalogued-model.md`
- `.agent/projects/028_verified_runtime_closing_the_loop/README.md`
- `.agent/projects/029_cslib_proof_tier/RESEARCH-cslib-implications-for-motoko.md`

## Predicted outcome

Delegations are owned, visible, and reaped: panes carry `mot-owner`, the run file records what happened (contract-checked in CI), and exits close only this session's panes. Checked by `make check_core` (herdr/dagr gates + `dagr check --strict` contract leg) and the live alpha→delta delegation exercise.

## Test evidence

- `make check_core`: green (verify_herdr_gate/check_answer/owner_tag/dagr_pane, verify_dagr_producer incl. `dagr 0.3.1 check --strict` on every published doc)
- Live exercise 2026-09-04: alpha/beta/gamma settled `done·reported`, killed delta settled `lost·heuristic`, no false `lost`, live run file `dagr check --strict` clean (`[]`)
- Motoko review `mot-dlg-1788520987788`: SHIP-WITH-NITS, all 3 nits fixed and re-gated
