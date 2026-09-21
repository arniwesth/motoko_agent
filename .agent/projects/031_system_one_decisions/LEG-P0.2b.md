# LEG-P0.2b — the sixteen named-arm attacks, reconstructed from shape (PLAN-001 (031), line R)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). You own exactly this task. You do not edit
the ADR or the plan, you do not write the dagr run file, and you do not touch other panes or worktrees.

## What this is

`P0.2b` in `PLAN-001-implement-adr-001-abi-8.md` §2, added by the operator's P0G ruling. ADR freeze
2(b) names "the 20 named-arm attacks reject at the compiler". Review 5's §A.3 records **21 rows**
(20 attacks + 1 control) as a **table of shapes** and quotes full source for only **five**, which P0.2
committed. The other sixteen were measured by that review but are not re-runnable, so they cannot go
red on a compiler bump. You rebuild them as regression rows. **A reconstruction is new authorship, not
the review's evidence**, so the whole part is built to make that visible and checkable.

## Ground truth to read first, in this order

1. `PLAN-001-implement-adr-001-abi-8.md` — §2 **P0.2b** and **P0.2**; §9's **P0.2** record (its
   "Carried to P0G" paragraph).
2. `REVIEW-adr001-v0.5-verdicts-claude-fable-5-1.md` **§A.3** (`:689-821`): the table (read its preamble
   defining "rejected: app" and "rejected: eff(x)") and the five `####` quoted cases — they show you the
   exact idiom each table row abbreviates.
3. `ADR-001-extension-owned-structured-decisions.md` — the **acceptance rule**, freeze 2(b), D2 facts 1–6.
4. P0.2's work: `scripts/dst/fixtures/adr001_boundary/` (especially the five `q_named_*.ail` and
   `types.ail`), `scripts/dst/adr001_boundary_provenance.py`, the P0.2 rows in
   `scripts/dst/run_declared_vs_performed.sh`, `scripts/dst/adr001_boundary_mutgate_spec.tsv`.
5. `GATE-mutation-red-submission-precondition.md` and `mutgate.sh` (013).

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `ab1616b2`. The fixtures use P0.2's **local** capability
sum (`adr001_boundary/types.ail`), not the ABI package, so the red tree (ABI 8.0 since P0.4) does not
affect them — `make declared_vs_performed` is green at HEAD, 114/0. AILANG `v0.33.0`, the pin. P0.6 is
running beside you in `packages/motoko_ext_conformance/examples/`; your files do not overlap.

## What you build

For **each of the sixteen unquoted rows** of review 5 §A.3 — every row except the five quoted cases and
the control `q_dec_prepare_named_ok`:
- one fixture in a **separate subdirectory**, `scripts/dst/fixtures/adr001_boundary/reconstructed/`,
  named from the row's case name, whose header comment quotes the table row **verbatim** (case, shape,
  result) and states `reconstructed from shape, not quoted source`;
- one **group-1** row in `run_declared_vs_performed.sh`, same two-sided idiom and imported-sum mechanism
  as P0.2's group-1 rows, labelled `RECONSTRUCTED`.

Also the **control** `q_dec_prepare_named_ok` as a reconstructed **group-2** row (the table: `q=1`, runs).

**Fidelity is the check, not rejection.** Each reconstruction must reject **for the reason its row
records** — `app` (closed-row unification at the `Pure(body)` application: `r1 has extra labels …`),
`eff(x)` (`Effect checking failed for function 'x' … Missing effects: IO`, naming the same function), or
"rejected at the `let` annotation" for `q_named_recfield_xmod`. The row's `ok` branch must **match that
reason in the compiler output**, and a rejection for any other reason is `bad` with the error quoted —
exactly as P0.2's rows do. A reconstruction that rejects for the wrong reason is not the review's case.
If you cannot make a row reject for its recorded reason, **do not force it**: report the row, what you
built, and what the compiler said.

Keep P0.2's provenance exact: `adr001_boundary_provenance.py` must still re-derive P0.2's 52 files
unchanged; either leave `reconstructed/` outside its scope or give it a separate, clearly named check
that each reconstruction's header quotes its table row byte-for-byte from the review.

## Exit checks — run them yourself, record the output

1. `make declared_vs_performed` **green**: group 1 **27 + 16**, group 2 **5 + 1**, every other group
   unchanged; the suite still fails on an unscored fixture.
2. For each reconstructed row: its table reason and the compiler's actual rejection, side by side.
3. **mutgate** from a fresh clone, after your commit, spec **committed in the repo** with repo-relative
   paths:
   ```
   bash .agent/projects/013_core_architecture_for_dst/mutgate.sh --spec <repo path> \
     --clone-from /workspaces/motoko_agent --repo /workspaces/mutgate-031-p02b
   ```
   At least: make one reconstruction clean (drop its effect) → its row goes red → restore; and make one
   reject for the *wrong* reason (e.g. an `app` case turned into an `eff` case) → its row goes red.
   Known trap: `cmd | grep -q X` under `set -o pipefail` scores baseline red (exit 141).

Do not run `make dst`.

## Your last act: the commit, then the envelope

```
ADR-001 (031) P0.2b: review 5's sixteen named-arm attacks, reconstructed from shape as group-1 rows
```

Then:

```
RESULT P0.2b
head_before: <sha>
commit: <sha>
files_touched: [<paths>]
reconstructed: <n>/16 group 1, <n>/1 group 2
reason_match: <n>/<n> (table reason == compiler reason)
not_reconstructed: [<case>: <why>, ...]
commands:
  - make declared_vs_performed -> exit <n> (<passed>/<failed>)
  - mutgate.sh ... -> exit <n> (<pass>/<rows>)
mutgate_spec: <repo path>
could_not_run: [<what>: <why>, ...]
```

## Rules that bind you

- `scripts/dst/fixtures/adr001_boundary/reconstructed/`, the rows you add to
  `run_declared_vs_performed.sh`, a provenance check for the reconstructions, and `evidence/P0.2b/`.
  Do **not** change P0.2's existing fixtures, rows or groups.
- One commit, named as above, as your last act. Leave every unrelated modified or untracked path alone,
  and **never run `git stash`** — two unrelated files in this checkout belong to another session.
- Do not edit `PLAN-001-implement-adr-001-abi-8.md`, the ADR, or `.dagr/`.
- Fixtures are synthetic. Do not touch Herdr pane `w3:p1`, tab `w3:t1`, pane `w3:pZ`, or
  `/workspaces/motoko_agent-eval`.
