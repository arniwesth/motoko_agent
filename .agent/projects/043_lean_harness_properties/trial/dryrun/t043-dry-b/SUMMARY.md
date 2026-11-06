# T0 dry run (arm B, replicate 1): `pair_step`/`finish_fold` vs `updatePending`

Snapshot: `/home/motoko/trial-043/s/t043-dry-b/tree`. Lean 4.28.0 (core only), bun, ailang.

## Result

- **P0.1 proved** for the model: `p01_fold` (fold level) via `host_twin_agrees` (pairing level),
  in `T0Model.lean`. No `sorry`, no `native_decide`; axioms `propext`, `Quot.sound` only
  (`axioms.txt`).
- **No P0.1 violation was found.** The differential run (below) also finds 0 host/fold
  disagreements, within H1 and H2, on the real code.
- **Three exploratory observations** (`reports.tsv`), each stated as a `bug_` theorem and
  reproduced on the real, unmodified code:
  - **X-1**: the fold accepts a second result for a call that was already answered (`1,4,4`).
  - **X-2**: the fold accepts a result for a closed batch after a user message (`1,4,7,4`).
    X-1 and X-2 have the same cause: `pair_step` checks a result against `cur_ids`, not
    `open_ids`.
  - **X-3**: with an empty call id in the last batch, the fold accepts with `dangling = [""]`
    and the host records `[]` (`10,4`). This is outside P0.1, because it breaks H1. It shows
    that H1 is needed.

  None of the three is shown reachable from a real writer or provider (Kiro steps 6–7 not
  done). So they are observations about ADR-003 D4's intent, not confirmed defects. The
  snapshot's code for these functions matches the project's earlier worked example branch for
  branch (`journal.ail:1364-1374, 1634-1672, 1715-1750`; `session-journal.ts:865-875`). I
  found no deliberately introduced change in them.

## Step (2): model changes

**0.** The model began as a transcription of `evidence/PairingModel.lean`. I re-read it
against this snapshot's source before the first run and it matched. The first differential
run gave 0 mismatches, so no fix was needed.

Two runner fixes changed the harness, not the model, so they are not counted:
- The AILANG half has to run inside an `ailang.toml` package. `pkg/` is a shadow package that
  copies `ailang.toml` and `ailang.lock` and symlinks `src` and `packages` to the tree, so
  nothing was written to the tree.
- `enumerate.ts` imports the tree by absolute path.

## Differential run (`diff/run_diff.sh`, log `diff/run2.log`)

16,105 histories, lengths 0–4, an 11-message alphabet:
- **Model host vs the real `updatePending`:** 0 mismatches.
- **Bounded check on the model:** of the 449 accepted histories within H1/H2, 0 disagree.
- **Model fold vs the real `fold_journal`:** 0 mismatches.

  | Model | Real fold | Histories |
  |---|---|---|
  | refuses | refuses (`pairing`) | 15,272 |
  | accepts | accepts, same `dangling` | 750 |
  | accepts | refuses on a later check (`transcript`) | 83 |
- **Real host vs real fold (P0.1 on the real code):** of the 449 histories the fold accepts
  within H1/H2, **0 disagree**. Outside them, 213 disagree; these are the H1 and H2 cases
  above.
- The script exited 0. `ail.out` sha256 `953896c1a30e5ccc…` and `ts.out` sha256
  `6de0b5877d1ace2f…` are identical to the project's recorded run at `43530c0`.

## Files

| File | What it is |
|---|---|
| `T0Model.lean` | The model, with a header giving the source lines, plus every theorem |
| `axioms.txt` | `#print axioms` for all 20 theorems |
| `diff/` | `run_diff.sh`, `enumerate.ts`, `enumerate.lean.tail`, `enumerate_fold.ail`, `compare_fold.awk`, and the run logs and outputs |
| `pkg/` | The shadow AILANG package; `harness/x{1,2,3}.ail` fold one history each |
| `repro/` | `x1.sh`, `x2.sh`, `x3.sh` (run from the tree root; exit 1 when the defect is present), `fold1.sh`, `host.ts` |
| `reports.tsv` | The three reports |

## What I could not do

- **Reachability (Kiro steps 6–7)** for X-1, X-2 and X-3.
- **H2's case**, a tool message that carries calls (`1,8`, `twin_disagrees_without_h2`). It is
  proved in the model and the enumerated run covers it, but I wrote no separate repro.
- **The `strip_dangling` model.** It strips by `seq == cur_seq`, so several messages that share
  a seq (a seed expansion) could have calls stripped from an earlier assistant whose id was
  reused. I did not model or test this.
- **Host-side `replaceLastHistoryMessage`.** It calls `updatePending` without undoing the
  replaced message's open set. I did not test this.
