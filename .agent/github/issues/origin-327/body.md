---
repo: arniwesth/motoko_agent
issue: 327
title: "declared_vs_performed needs re-measuring on AILANG v0.60.4: 17 of ADR-001's 18 escapes are closed upstream"
---

## Summary

`make declared_vs_performed` holds the evidence for 031 ADR-001, and it does not pass on AILANG
v0.60.4. The pin to v0.60.4, #328, lists it in `DST_KNOWN_RED`. That
names the failure in the sweep summary and waives nothing, so `make dst` still exits 2. Most of
the red is good news: v0.60.4 rejects 17 of the 18 escapes the gate pins as LIMITATIONs. The gate
needs the re-measurement Amendment 6 made at the v0.52.5 pin, and this issue holds the inventory.

The gate was red on `main` before the pin as well. On v0.54.14 it reports 126 passed, 11 failed.
No CI workflow runs it.

## Context

**Why the probe does not compile on v0.60.4.** `scripts/dst/declared_vs_performed.ail` builds two
vacuity controls, `control_env` and `control_fs`. They show that withholding Env or FS really
kills a hook that performs it. Both perform from `PureCtx` callbacks through limitation 1's door, a
lambda in a record field whose effect row the compiler did not check. v0.60.4 checks that row, so
the module no longer compiles, and every runtime row reports that its hook died.

**How the inventory was measured.** To see the rest of the gate, I removed the two performing
calls from the control bodies, `getEnvOr("PATH", "")` in `env_control_body` and
`readFile("ailang.toml")` in `fs_control_body`, so that the probe compiles. Then I ran
`scripts/dst/run_declared_vs_performed.sh` with the v0.60.4 release binary and its own `std/`, from
a worktree under `/workspaces`, because AILANG relaxes MOD010 under `/tmp`. The result was 91
passed, 46 failed. The stub is not committed.

| Rows | What the gate reports | Also red on v0.54.14 |
|---|---|---|
| 17 | LIMITATION 1–6 and 8–18: "IS FIXED UPSTREAM" | 0 |
| 1 | UPDATE POSITION (a) CHANGED: an inline lambda in record-update position is now checked against its row | 0 |
| 2 | IMPORTED SUM (unannot) is rejected in a different place; IMPORTED SUM (smuggle) is now rejected | 0 |
| 12 | GROUP 1: still rejected, "but NOT by its own mechanism". The error text changed | 1 (`n_pure_passthru_xmod`) |
| 11 | GROUP 1 RECONSTRUCTED: still rejected, "but NOT for its table reason" | 8 |
| 2 | `control_env`, `control_fs` COMPLETED. These rows come from the stub | 0 |
| 1 | `on_budget_plan` binding site at `src/core/test/ext_fixture.ail:148` | 1 |

Ten of the 11 rows that are red on v0.54.14 are still red. The eleventh, RECONSTRUCTED
`q_named_recfield_xmod`, passes on v0.60.4.

**LIMITATION 7 still holds.** The gate's row reads: "the same pass-through with the stored lambda
UNANNOTATED escapes too (fifth review N44, correcting the fourth review's table)", ticket
`fb_30e82f6bdc5fc8c3`. A stored lambda without an annotation, passed through a named pass-through,
can still perform from a `PureCtx` callback. So D2's registration-boundary rule, that callbacks
are named top-level functions, is still load-bearing.

**What each closed limitation asks to re-read**, from the gate's own messages:

| Limitation | ADR-001 reasoning to re-read |
|---|---|
| 1, 17 | Record-field lambda rows. Every "the compiler is the enforcer" claim in WI-D6, D7 and D8 now holds at more sites, and the two controls were built through that door |
| 2 | WI-D6's `on_budget_plan` narrowing, which now buys strictly more |
| 3, 4, 5 | Fact 1 and the 2(a) evidence: the compile-time check now catches a lambda calling a port its view lacks |
| 6 | Fact 4, and D2's reason for having no pass-through arm |
| 8 | D2's residual for narrow slots |
| 9 | The prepare arity. The gate asks for a re-measure on an imported sum before recording it as closed |
| 10 | D2 layer (c)'s limits |
| 11 | The shape rule's partial-application clause, now belt and braces |
| 12 | D2's locals-first resolution |
| 13 | N51, and the per-hop scope chain |
| 14 | N63. The gate's `fx_param_shadow` fixture becomes redundant |
| 15 | The per-hop (module, parameters, lets) chain |
| 16 | N52 and the totality criterion |
| 18 | Amendment 6's measurement. `fx_import_shadow` and `fx_delegate_import_shadow`, which pin `compiler: clean`, go red with it |

**Where the controls can go.** In `packages/motoko-ext-abi/types.ail`, the `ToolProvider` row
carries both Env and FS, and the `ExitIntent` and `WorkInFlight` rows carry FS. A control there
performs legitimately rather than through a hole. Whether the gate's withholding regimes can drive
those slots the way they drive the current controls is part of the work.

## Expected

- `make declared_vs_performed` passes on the pinned AILANG, and its `DST_KNOWN_RED` entry is
  dropped. `scripts/dst/sweep_summary.sh` reports a listed target that passes, so the entry cannot
  outlive the failure.
- ADR-001 gets an Amendment 8 that records what v0.60.4 closed, with the gate run attached as its
  artifact, as the ADR requires for any change to it. `NOTE-001-effect-inference-gap.md` says which
  of its cases are closed upstream.
- The registration-boundary rule stays for as long as LIMITATION 7 holds.
- The 10 rows that were red before the pin are either fixed in the same pass or listed with a
  reason.
