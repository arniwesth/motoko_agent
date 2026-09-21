# DIRECTIVE 2026-09-20 08:0xZ — 1.16 gains a preservation precondition; evidence retained under `evidence/plan004-v2/`

By: observer (w3:pZ), under the `run.observer` grant of 2026-09-19T17:46:16Z.
Scope: P2.3, PLAN-004 v2.
Authority: **recommend_and_return — operator ruling: "I will follow the recommendations"**
(2026-09-20). Committing to the repo and 1.16 are both on the observer's return list; this directive
transmits the operator's decision.

## Not an ADR amendment — a row amendment

ADR-004 v5 decides what the evaluator is and what makes a verdict admissible. This is the ordering
of two operational steps inside the plan that implements it, and the relevant decisions **already
exist**:

- **QRET** (done) — corpus retention: 90 days after `P3G` or supersession, then delete by default or
  migrate under reviewed re-admission; covers `_archive/`, `_scan0/`, entries + `runs/`, *"scratchpad
  `/tmp` evidence with real content"*, backups. Ruling in PLAN-004 §6.
- **§0.6** — what may be recorded: counts, digests, indices, identities; never corpus content.
- **`evidence/<part>/` + `MANIFEST.sha256`** — the established pattern, already used by
  `adr004-p0`, `plan002-w5-probe`, `plan003-p4-live-gate`.

Only the link between them is missing. Precedent for the smaller instrument: round 3 already issued
*"Amendments to round-2 §c Part 1"*, changing 1.1/1.3/1.4/1.5/1.7/1.8/1.9 and adding 1.17/1.18.

## The amendment — carry this into the P2.3R packet

> **1.16 — Remove `$T` and the synthetic corpus.** *Precondition:* the §0.6-permissible evidence
> that the Part-1 receipts cite — the matrix at E and its suite logs, the freeze chain, the
> E-records, the mutgate records, and the row logs named in the ledger — is committed under
> `evidence/plan004-v2/` with a `MANIFEST.sha256`, and the manifest's digests match the digests
> quoted in the receipts. Content-bearing trees are **not** preserved: they are deleted here and
> under QRET.

## Why 1.16 is not in tension with preservation

They are the same rule's two halves. §0.6 already draws the line:

| preserve — commit to `evidence/plan004-v2/` | delete — 1.16 and QRET |
|---|---|
| `MATRIX.tsv` at E `562acadc` (sha256 `933f8de4…`) + its 34 suite logs | the sweep clone (`$T/clone`, ~1.4 GB) |
| freeze chain: `freeze.txt`, `freeze-x7.txt`, `freeze-x8.txt`, `X.log`, `Xtree.log` | `/workspaces/p22-corpus` — the two admitted **real** prefixes |
| E-records: `erecord-x6/x7/x8/x9.json`, `_g2/e-record-562acadc.json` | `_out/`, staging, tmp trees, `$T/tmp` |
| mutgate records (`x9mutgate/mutgate.tsv` + the three run logs) | anything carrying corpus content |
| the Part-1 row logs the ledger cites (`x9-1*.log`, `tail/t1*.log`, `.rc` files) | |

Digest-and-count artifacts are exactly what §0.6 permits recording. Content-bearing trees are
exactly what QRET orders deleted. **Committing the sweep tree wholesale would violate QRET**; that is
why the precondition names the receipts' cited set, not `$T`.

## Sequencing — and one thing to raise, not assume

`/workspaces/motoko_agent` (main) has been **untouched all round** — a14 recorded *"Main checkout
HEAD `7e5ec5f9…` untouched"*, and the standing discipline has been no commits, nothing staged.
A commit into `evidence/plan004-v2/` is therefore the first write to main this round.

Do **not** perform it as part of a delegate's run. Assemble the retained set and the manifest, verify
every digest against the receipts, and **report the manifest for the operator to commit** — or ask
explicitly for authorization to commit, naming the paths. The evidence dir is in main, not `A`, so
none of the `A`/freeze discipline covers it and nothing should be inferred as permitted.

1.16 stays deferred until the commit exists. Per round 3 it *"never blocks a code verdict"*, so the
P2.3R review of X9 proceeds regardless.

## Acceptance

- `evidence/plan004-v2/MANIFEST.sha256` in the `adr004-p0` shape: one `<digest>  <path>` per line.
- Every digest quoted in a Part-1 receipt resolves to a line in that manifest, or the receipt is
  amended to say the artifact was not retained and why.
- `find` over `$T` and the synthetic corpus shows them gone **after** the commit, and nothing under
  main's `.motoko/eval-corpus/` was created — 1.16's original criterion, unchanged.
