# P0.2b evidence: review 5's unquoted named-arm attacks, reconstructed from shape

PLAN-001 (031) §2 P0.2b, brief `LEG-P0.2b.md`. AILANG v0.33.0 (`ae36986`).

## The count is 18 + 1, not 16 + 1

Review 5 §A.3's table has **24** rows: 20 rejected attacks, the control `q_dec_prepare_named_ok`, and three
**escapes** (`q_named_shadow`, `q_named_paren_apply`, `q_named_partial`). Five cases are quoted in full. Three of
those five are the escapes, so only **two** of the 20 rejected attacks are quoted (`q_named_toplevel_apply`,
`q_named_recfield_named`). The brief's rule, "every row except the five quoted cases and the control", therefore
selects **18** attacks, not 16. The "16" in the plan and in the brief is 21 − 5, which assumes that all five quoted
cases are among the 21 non-escape rows. `adr001_boundary_reconstructed_provenance.py` derives the set from the
table and quote headings rather than from a number, and finds 18 + 1.

## Result: 17 of 18 attacks reconstructed, plus the control; 1 not reconstructed

| Case | Table reason | Compiler on the pin (`ailang check`) | Match |
|---|---|---|---|
| `q_named_mutual` | app | closed rows `[]` vs `[IO]`, param 0, at `Pure(body)` (`:9:28`) | ✓ ¹ |
| `q_named_generic` | app | same, at `Pure(body)` (`:9:28`) | ✓ |
| `q_named_pure_kw` | app | same, at `Pure(body)` (`:8:28`) | ✓ |
| `q_named_emptyrow` | app | same, at `Pure(body)` (`:8:28`) | ✓ |
| `q_named_letannot` | app | same, at `Pure(body)` (`:8:28`) | ✓ |
| `q_named_recfield_paren` | app | same, at `Pure(body)` (`:9:28`) | ✓ |
| `q_named_recfield_named_nolet` | app | same, at `Pure(body)` (`:9:28`) | ✓ |
| `q_named_recfield_xmod` | at the `let` annotation | `let annotation r` (`:8:34`), record field `f` | ✓ |
| `q_named_sumpayload_named` | eff(body) | `Effect checking failed for function 'body'`, Missing effects: IO | ✓ |
| `n_pure_named_applier` | eff(body) | `… function 'body'`, IO | ✓ |
| `q_named_toplevel_apply_paren` | eff(w) | `… function 'w'`, IO | ✓ |
| `q_named_toplevel_apply_unannot` | eff(w) | `… function 'w'`, IO | ✓ |
| `q_named_toplevel_noannot_let` | eff(w) | `… function 'w'`, IO | ✓ |
| `q_dec_prepare_toplevel_escape` | eff(w) | `… function 'w'`, IO | ✓ |
| `q_fs_named_toplevel_escape` | eff(w) | `… function 'w'`, IO | ✓ |
| `q_named_uppercase` | app | closed rows at `Pure(body)` (`:9:28`) | ✓ |
| `q_named_collision` | eff(body) | `… function 'body'`, IO | ✓ |
| `q_named_toplevel_xmod` | app | closed rows `[]` vs `[IO]`, but at **`apply(ctx, w)` param 1, record field `f`**, inside `body` | ✗ **not reconstructed** |
| `q_dec_prepare_named_ok` (control) | `q=1` | check 0, run 0, prints `q=1` | ✓ (group 2) |

Each row's `ok` branch in `run_declared_vs_performed.sh` (`adr_rg1`) matches the table reason and prints it next
to the compiler's line (`section-run.log`). An `app` row's regex is pinned to the line of `Pure(body)` in its
fixture, so the same closed-row labels at a different call site do not count as `app`.

¹ `q_named_mutual`: `helper` is declared `! {IO}`, and `body` is left rowless. With `helper` also rowless, every
variant tried on the pin rejects `eff(helper)`. That is mutgate row `p02b_app_to_eff`, which shows the row goes
red when that happens. The shape column ("effect in `helper`") does not say whether `helper` carries a row.

### `q_named_toplevel_xmod`: not forced

The shape is "same [as `q_named_toplevel_apply`], `W`/`apply` imported". Using P0.2's own imported `helpers.ail`
(`W`, `apply`), five builds were tried: annotated or unannotated module-level `let`, `! {}` or rowless stored
lambda, and `body` rowless or `! {IO}`. Every one rejects with the `app` **labels**, but at the `apply(ctx, w)`
application inside `body` (parameter 1, record field `f`), never at `Pure(body)`. Once the record type is
imported, its closed `{}` row meets `w`'s IO at the call into `apply`. `body` therefore never acquires IO for
`Pure(body)` to reject. Under the table preamble's definition of `app`, that is a different site, so the case is
listed in `NOT_RECONSTRUCTED` with its reason and gets no suite row. The attempt is
`q_named_toplevel_xmod.NOT-RECONSTRUCTED.ail`, and its compiler output is `q_named_toplevel_xmod.check.txt`. If
the operator rules that the labels alone are the recorded reason, this becomes one fixture plus one `adr_rg1` row
whose regex drops the site pin.

## Exit check 1: `make declared_vs_performed` is red before P0.2's section runs, and it was red before P0.2b

`make declared_vs_performed` exits 2 with **5 failures, all in producers 1 and 2** (compose's four slots, and
BudgetShaper's payload row missing from the ABI). The script runs under `set -euo pipefail` and aborts inside
producer 2, **before the P0.2 section is reached**. The result is identical (the same 5 ✗ lines) at `ab1616b2`
(`declared_vs_performed-at-ab1616b2.log`), at `857f778a`, at `0d085722`, and with P0.2b applied
(`declared_vs_performed-with-P0.2b.log`). The brief's "green at HEAD, 114/0" predates P0.4's move to ABI 8.0. The
repair belongs to whoever owns those producers, not to P0.2b.

The section itself is therefore scored by `run_adr001_section.sh`. It slices lines between P0.2's own marker
comments out of the **committed** `run_declared_vs_performed.sh` and runs them. Result: **72 passed, 0 failed**.
The groups are 2(a) 3/3, **group 1 44/44 (27 + 17)**, **group 2 6/6 (5 + 1)**, group 3 12/12, group 4 1/1, and
66 of 66 fixtures are scored. P0.2's `adr001_boundary_provenance.py` still re-derives its 52 files unchanged.

The suite still fails on an unscored fixture. With a stray `reconstructed/q_stray.ail`, three rows go red: the
reconstruction provenance check, `RECONSTRUCTION/ROW MISMATCH` (19 vs 18) and P0.2's own `FIXTURE/ROW MISMATCH`
(67 vs 66).

## Mutgate

Spec: `mutgate_spec.tsv` (repo-relative paths). The pre-commit dry run on a tree copy scored 8/8, and the red
reason for each mutated row is in `mutgate-dryrun-red-reasons.txt`: exactly one ✗ per mutation, each for its named
reason. The fresh-clone run happens after the commit, and its result is in the RESULT envelope.
