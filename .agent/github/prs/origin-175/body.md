---
repo: arniwesth/motoko_agent
pr: 175
branch: arniwesth/mot-127-motoko-as-a-delegate-kind-self-delegation-via-pane-run-gated
ticket: MOT-127
title: "MOT-127: motoko as a delegate — a second lifecycle, gated on the answer file"
---

## Summary

Motoko can now delegate to Motoko. From the operator's validated prototype; spec is
`.agent/projects/021_herdr_delegation/DESIGN-motoko-as-delegate.md`.

It is **the fastest delegate available** — a live `motoko` row ~0.8 s after `pane run`, against
3.9 s for `agent start --kind claude`.

**Stacked on `mot-121` (PR #174), not on mot-102**, and the stacking is forced rather than stylistic:
recursion control needs #174's `HERDR_` prefix forwarding for `HERDR_DELEGATE_DEPTH` to reach a
delegate's own extension, and the readiness story needs `a8320ea` — a second motoko delegate in a
reused pane never reports a row under the old sequence counter.

## Not a 23rd kind

`agent start --kind` takes a fixed list of 22 baked into the herdr binary and `motoko` is not on it
and cannot be (020 ADR-001 option B, closed). It doesn't need to be: Motoko is a lifecycle
**authority** (020 D1), so it announces itself. The task arrives as **argv[2]**, the only channel
available — `agent prompt` refuses reported agents, and `pane send-text` is screen-driving the
handoff forbids.

Three of six lifecycle steps differ, so this is a branch rather than a table entry:

| step | claude/codex | motoko |
|---|---|---|
| spawn | `agent start --kind` | `pane run './scripts/run-agent.sh <task>'` |
| readiness | `agent explain --json` rule match | none needed |
| completion | `agent wait` + answer file | **answer file only** |
| reaping | close on settle | **close on the file** |

## The three load-bearing behaviours

**Completion is the answer file and nothing else.** Motoko reports `idle` **at startup** — 020 D2's
deliberate initial report, measured at 869 ms with the task not begun. Through the normal path that
hits `is_settled("idle")`, takes the settled branch, finds no answer file, and reports P2-3's
*"finished but never wrote"* against a delegate that hasn't started. State is used only to pick which
transition to wait on; it is never evidence of completion.

**Reaping is an explicit close on the file.** It does not stop after answering — measured `working`
18 s+ later — so waiting for a settle would wait forever.

**Recursion is off by default**, depth 1, via `HERDR_DELEGATE_DEPTH`. Raise with
`HERDR_MAX_DELEGATE_DEPTH`.

## A shell payload needs its own predicate

`argv_is_safe` is not it. That guard stops #158 mangling a herdr argv; a `pane run` payload is *meant*
to reach a shell, so the eight-token test would refuse a correct command — and widening it would
disable the #158 guard everywhere. The applicable rule is exact rather than heuristic: inside POSIX
single quotes every character is literal except `'`, so the payload is safe iff nothing interpolated
into it contains one. Checked on the **parts**, not the assembled string — an early version checked
the whole payload and was always false, which its own test caught.

## A measured correction to the design

The design proposed `agent rename` to give the self-reported agent an addressable name, and **rename
does work**. It is unusable here: the row appears ~0.8 s *after* `pane run` returns, and `agent wait`
does not block for an agent that doesn't exist — it fails with `agent_not_found` in **2 ms**. With no
sleep primitive on `ExtPorts` there is nothing to wait on, so at `Delegate` time there is no agent to
rename.

The handle carries the pane instead — `mot-dlg-<ms>@<pane>` — which solves the same three problems
with no extra call and no race: ownership stays provable by the prefix, the pane is addressable, the
start time is still recoverable, and it doubles as the discriminator for which lifecycle
`DelegateCheck` uses. `argv_rename` is kept: it is the answer to MOT-120 for anything that *can* wait
for the row.

## F-5 is not closed

Stated explicitly because the scope fence requires it. The narrowest behaviour that works shipped:
`Delegate` closes the pane it created on any failure, `DelegateCheck` closes it once the file lands,
**nothing sweeps**, and ownership is positive — by the `mot-dlg-` prefix, never "everything that is
not me".

What makes that sufficient rather than merely narrow is the depth limit. The reason for deferring
this feature was that a motoko orphan is an **orchestrator** — orphans that beget orphans. At the
depth limit an orphaned motoko delegate cannot spawn anything, so it is exactly as inert as an
orphaned claude: it burns more quota, and it cannot multiply. That converts an unbounded failure mode
into the one F-5 already describes, without deciding F-5.

## Verification

- **Motoko delegated to Motoko** — 3 steps, answer file written, correct answer (65, agreeing with an
  independent count).
- **Depth gate** at depth 1 — refused in **1 step with nothing spent**: no pane, no task file.
- **claude path unregressed** — 2 steps, correct answer, after `argv_split`'s signature changed.
- 197 inline tests, 17 TUI tests, `check_core` 56/56, gate both ways.
- `make dst` unchanged at its one pre-existing failure (`declared_vs_performed`, byte-identical at
  base).

## Review notes

- Read `DESIGN-motoko-as-delegate.md` first; it carries the measurements this is built to.
- The base is #174. Review that first, or read this diff against `mot-121`.
- `.devcontainer/agent_confined/{Dockerfile,herdr.toml}` show modified in `git status` — the
  read-only-mount artefact, nothing staged.

Closes MOT-127.
