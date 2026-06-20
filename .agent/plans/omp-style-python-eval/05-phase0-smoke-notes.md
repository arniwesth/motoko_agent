# Phase 0 smoke notes — AILANG eval CLI verification

Date: 2026-06-17. Recorded during implementation of plan 05.

## CLI / environment facts (verified, not assumed)

- **Binary**: `ailang` at `/home/motoko/.local/bin/ailang`, **`v0.24.2`** (commit `f88ff4e`, built 2026-06-15).
- **Latest available**: `0.25.0` (per `ailang_versions` MCP). The repo `ailang.lock` pins `v0.24.2`
  (regenerated 2026-06-17). **Decision: implement against `v0.24.2`.** The 0.25.0 changelog is
  entirely eval-harness/nightly internals + type-soundness fixes + parser error quality (PAR020) —
  it does **not** change the `ai-check` / `verify` / `run` / `check` CLI surface this feature uses.
  Upgrading the global binary is a repo-wide action (would force a re-lock and could shift package
  hashes) and is **not required** to ship this feature. Flagged as an orthogonal ops follow-up.
- **Z3**: NOT bundled. `ailang verify` and the `verify` half of `ai-check` fail/return
  `available:false` without it. Installed via `apt-get install -y z3` (4.8.12). The env-server host
  must have `z3` on PATH (or `AILANG_Z3_PATH`) for verification; otherwise verify status is `skipped`
  with `available:false` and must be reported as such (never as "verified").

## Command decisions

- **`ailang ai-check <file>`** — the single combined check+verify command ("for AI"). Preferred over
  running `check` then `verify` separately. Flags: `-timeout` (per-fn Z3 timeout, default 5s),
  `-verify-recursive-depth` (default 2), `-relax-modules`. JSON is the default output (no `--json` flag).
- **`ailang verify --json <file>`** — verify only; same `verify` sub-shape as ai-check minus `available`.
- **`ailang run --caps <CAPS> --entry main <file>`** — executes; progress lines on stderr, program
  output on stdout. Verified `--caps IO --entry main` prints `7` for `abs_diff(10,3)`.
- **`ailang check <file> --json`** — type-check only (still available; ai-check supersedes for this feature).

## JSON shapes (captured live)

`ailang ai-check spike.ail` (Z3 present):
```json
{
  "file": "spike.ail",
  "check":  { "passed": true, "error_count": 0, "errors": [] },
  "verify": { "available": true, "verified": 1, "counterexample": 0, "skipped": 0, "errors": 0,
              "results": [ { "function": "abs_diff", "status": "verified", "duration": 21916469 } ] }
}
```
- `check.errors[]`: `{ code, message, file }`.
- `verify.available`: false when Z3 missing → verify must report `skipped`, never `verified`.
- `verify.results[].status` observed: `"verified"`, `"counterexample"`. Aggregate counters:
  `verified | counterexample | skipped | errors`. (No `unknown`/`timeout` status seen in the smoke,
  but the aggregate `errors`/per-fn duration + `-timeout` flag imply timeout surfaces as an error/
  non-verified result — map any non-`verified` status conservatively: counterexample→failed,
  errors→unknown, missing Z3→skipped, slow→timeout where detectable.)

`ailang verify --json broken.ail` (failing contract):
```json
{ "file": "broken.ail", "verified": 0, "counterexample": 1, "skipped": 0, "errors": 0,
  "results": [ { "function": "bad", "status": "counterexample",
                 "model": [ {"name":"$p_price","sort":"Int","value":"0"}, ... ], "duration": ... } ] }
```

## Contract syntax (verified working)

`requires` / `ensures` are **brace blocks placed between the signature and the body**, multiple
conditions comma-separated inside one block:
```ailang
export func abs_diff(a: int, b: int) -> int ! {}
requires { true }
ensures { result >= 0 }
{
  if a >= b then a - b else b - a
}
```

## Teaching-prompt source

- MCP `prompt_get(forVersion:"0.25.0", kind:"agent")` returns only a ~6KB **"slim seed"** that tells
  the agent to load the full guide — NOT the full guide itself.
- `ailang prompt` (full) works but is the **stale embedded v0.16.0** prompt with **no contract/verify
  content**.
- `ailang prompt --compact` is **broken** locally (tries `v0.16.1-compact`, not in versions.json).
- **`ailang agent-prompt`** works: 338-line "AILANG Agent Coding Guide" (minimal, iterative coding
  reference). **Decision: use `ailang agent-prompt` as the one-time teach-prompt payload**, cached
  per env-server process. (MCP full-prompt fetch can be a later enhancement.)

## Teach-prompt mechanism (MVP)

Using the handoff-permitted env-server fallback: track `teachPromptSeen` per session in the AILANG
source session; the first `ail` authoring cell of a session attaches the teaching guide via
`metadata.ailang.teachPrompt` (+ a notice), and sets `teachPromptSeen`. Subsequent cells omit it.
