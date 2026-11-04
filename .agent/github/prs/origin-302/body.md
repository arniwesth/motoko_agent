---
repo: arniwesth/motoko_agent
pr: 302
branch: docs/014-revisit-godel-lineage
ticket: null
title: "docs(014): re-read the Gödel-machine lineage research against today's Motoko and AILANG"
---

## Summary

Project 014's research note (2026-08-13) is 81 days and 1,053 commits old, and the pinned
AILANG moved from v0.33.0 to v0.54.14. This adds `NOTE-001-re-read-2026-11-02.md`, a dated
sibling note on the 013 NOTE-002 pattern: the Mendel GM numbers verified from the paper (they
are the 60-task subsets), the §2 baseline re-measured at `e49a3ec3`, what 013 ADR-004, 027,
011 ADR-003 and the mutation discipline changed, the gap table re-ranked with three new gaps,
and three ADR candidates. The research document gains a three-line marker and is otherwise
unchanged, per 027's convention.

## Changes

- docs(014): re-read the Gödel-machine lineage research against today's Motoko and AILANG

2 files changed.

## Governing docs

- `.agent/projects/014_comparative_self_evolution/NOTE-001-re-read-2026-11-02.md`
- `.agent/projects/014_comparative_self_evolution/RESEARCH-godel-machine-lineage-for-motoko.md`

## Predicted outcome

A reader of 014 gets a current baseline and adoption order instead of August's. No code,
gate, lock, CI or ADR status changes. The note cites 039's 30-site mutation pilot and 011's
reassessment from branch `docs/011-current-test-axes` at `023b0f02`, with the caveat that they
were not on `main` when written; when that branch lands the citations resolve on `main`.
Checked by: the two files on `main`, the marker at the top of the research document.

## Test evidence

Docs only. Numbers in the note were measured in-session at `e49a3ec3`:

- `make verify_core` — `75 contracts proven, 0 unstated, 1 blocked; 0 files failed, 44 bare`;
  pinned classification `73 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified`.
- `wc -l src/core/*.ail` (50,335), `wc -l src/core/dst_*.ail` (25,158), `DST_TARGETS` (55),
  `Ports` fields (13) and `recording_ports` bindings (10 recorded), `ls benchmarks/results`
  in the shared checkout (newest 2026-05-31).
- `make dst` was not run; the note says so in its §9.

`git diff --stat e49a3ec3..HEAD`: 2 files, the note and a 3-line marker.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
