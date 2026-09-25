# Handoff: implement the Z3 contract adoption plan

Date: 2026-08-29
From: the session that authored `RESEARCH-contract-baseline.md`, the plan, and (with a second
session) ADR-001 v2
For: a fresh session implementing on a new Linear-linked branch cut from **`origin/main_dst`**
(the docs were authored at `6a915527` on `arniwesth/mot-129-extension-abi-phase-a`; see Step 0.4)
Deliverable: P0–P5 of `PLAN-z3-contract-adoption.md`, landed as independently-revertible
commits on a **new Linear-linked branch**, each gated.

**The PLAN is the spec and ADR-001 is the decision.** Where this handoff and the PLAN
disagree, the PLAN wins. Where the PLAN and ADR-001 disagree, ADR-001 wins. Where all three
are silent, the *Stop and report* list tells you whether to decide or escalate.

---

## Step 0 — Create the Linear issue and branch (do this first)

The work does not start on `arniwesth/mot-129-*`; that branch is extension-ABI work and this
is unrelated.

1. **Create the issue** with `mcp__linear__save_issue` on team `Motoko-agent`
   (`e07d912d-0220-402d-87de-7a79305be9a2`), mirroring MOT-129's shape:

   - **Title:** `Contract adoption for src/core — honest gate, computed classification, guard contracts`
   - **Description:**
     ```
     Implement PLAN-z3-contract-adoption.md P0–P5. Supersedes the phase plan in
     design_docs/planned/m-motoko-z3-contracts.md, which is stale (three targets deleted,
     Phase 1 already shipped, flagship example needs two local edits).

     ADR:      .agent/projects/027_z3_contracts/ADR-001-contract-classification-register.md
     Plan:     .agent/projects/027_z3_contracts/PLAN-z3-contract-adoption.md
     Baseline: .agent/projects/027_z3_contracts/RESEARCH-contract-baseline.md
     Review:   .agent/projects/027_z3_contracts/REVIEW-adr001-verdicts.md

     Base branch: main_dst. The 027 documents were authored at 6a915527 on
     arniwesth/mot-129-extension-abi-phase-a and must be seeded onto the branch
     (git checkout 6a915527 -- .agent/projects/027_z3_contracts/); the three source files
     the plan touches are byte-identical across the two lineages.

     Baseline: `make verify_core` reports 2 with contracts, 0 failed, 51 without. Of the
     4 verified contracts, 1 is substantive, 2 are tautologies, 1 restates its own body.

     Steps:
     * P0+P2 (one commit). verify_core splits amber into `unstated` / `blocked`; unstated
       fails. compress.ail gets its ensures via concat_String + pure func.
     * P1. is_root contract lands; the two dead @verify predicates in agents_md.ail go.
     * P5. Guard-predicate sweep — recall/precision contracts on has_shell_tokens and
       starts_with_root_dir. Highest real value in the plan.
     * P3. verify_classify + contracts.register pinned by hash, with per-contract solve time.
     * P4. Conditional: fold verify_core into DP7's oracle, dogfood profile first.

     Gate after each commit: make check_core && make verify_core && make test.
     make dst DST_JOBS=1 before the P5 commit (it touches production guards).
     ```
   - `assignee: "Arni Westh Hansen"` (the param is `assignee`, **not** `assigneeId` — it takes
     a name, email, ID or `"me"`), `state: "Backlog"`, `priority: 0`.

   Do not use `mcp__linear__save_issue` with an `id` — that updates an existing issue. Omit
   `id` to create.

2. **Read back `gitBranchName`** from the created issue — do not invent the slug. Linear
   generates it (MOT-129's is `arniwesth/mot-129-implement-adr-001-extension-abi-evolution-phase-a`).

3. **Branch from `origin/main_dst`** — that is the base for this work, not `main` (which is
   what `origin/HEAD` and the Makefile's `BASE ?= main` default point at) and not the current
   branch. Fetch first: local `main_dst` is **120 commits behind** the remote.
   ```bash
   git fetch origin && git switch -c "<gitBranchName>" origin/main_dst
   ```

4. **Seed the project directory — `main_dst` does not have it.** The four 027 documents were
   committed in `6a915527`, which is on `arniwesth/mot-129-extension-abi-phase-a` and is *not*
   an ancestor of `main_dst` (their merge-base is `a753ffe1`). Switching branches will make
   them vanish from your tree. Restore just the docs — do **not** cherry-pick `6a915527`, which
   is a mixed commit touching `src/core/rpc.ail`, `src/core/session.ail`, `src/tui/`, the smoke
   scripts and `.motoko/config/`:
   ```bash
   git checkout 6a915527 -- .agent/projects/027_z3_contracts/
   ```
   This handoff is untracked, so it follows you across `git switch` on its own. Commit all five
   documents as your first commit on the branch. `papers/README.md`'s new row is also in
   `6a915527`; take it or leave it, it is context and not a dependency.

5. Attach the PR to the issue when you open it, and set the base:
   ```bash
   make pr BASE=main_dst
   ```
   `BASE ?= main` is the Makefile default (`Makefile:83`), so passing it is required.
   See MOT-111 — the PR/issue link exists because it used to be done by hand.

---

## Read first, in this order

1. **`PLAN-z3-contract-adoption.md`** — your spec. Load-bearing: the phase-ordering block
   (P0+P2 ship together, and why), P0 steps 1 and 4 (the `unstated`/`blocked` split), P5 (the
   only phase that closes a real gap), and the three answered Open Questions, which record
   *why* the obvious alternatives were rejected.
2. **`ADR-001-contract-classification-register.md`** — the decision. §1 (the two probes and
   the classes they compute), §3 (the split gate), §5 (P4's real preconditions). Its
   *Retractions* section lists four claims from v1 that are false; do not resurrect them.
3. **`RESEARCH-contract-baseline.md` §3 (E1–E7)** — every mechanical fact you need, measured.
   Read E4 and E7 in full before touching source.
4. **`REVIEW-adr001-verdicts.md`** — the two adversarial reviews and the re-measurement.

Skim only: `design_docs/planned/m-motoko-z3-contracts.md` (the origin doc, stale by design —
kept as the record, not as a work list).

---

## Before you change anything: re-measure

The numbers above were taken at `76178f86`; HEAD has moved once already, and two sessions were
editing this directory concurrently. Spend five minutes confirming the baseline still holds:

```bash
make verify_core                      # expect: 2 with contracts, 0 failed, 51 without
ailang verify src/core/tool_runtime.ail   # expect: 4 verified
ailang verify src/core/compress.ail       # expect: 2 skipped, "no ensures clause"
ailang verify src/core/agents_md.ail      # expect: "0 functions: no functions with contracts"
```

Run this **after** switching to the new branch, not before — the measurements in these
documents were taken on a different lineage. Already checked across the two: `compress.ail`,
`agents_md.ail` and `tool_runtime.ail` are **byte-identical** on `origin/main_dst`, the
contract counts match (4 `ensures`, 2 `requires`), and the `verify_core` target is identical.
The only relevant difference is the surrounding `Makefile` (+26/−69), so P0's edit lands at
different line numbers: on `main_dst` it is `check_core:` at `:2139`, `verify_core:` at
`:2299`, `verify_ext:` at `:2321`. Anchor on the target names, not the line numbers quoted
elsewhere in these documents.

If any measurement differs, **stop and report** — the plan's phases are sized against these.

---

## Traps, all of them measured

Each of these cost this project a wrong turn. They are in RESEARCH §3; repeated here because
you will hit them in the first hour.

| Trap | What happens | Fix |
|---|---|---|
| Plain `func` | `SKIPPED — Function "f" has effects`, regardless of body | Promote to `pure func` first. This is step zero for every candidate (E1) |
| String interpolation | `SKIPPED — unencodable builtin: show` | `concat_String(a, b)` — ordinary surface syntax, `std/sem.ail:63` uses it (E4) |
| `a ++ b` on strings | Type error: ``` `++` is for lists only ``` | Same — `concat_String` |
| `concat([a, b])` | `SKIPPED — unencodable builtin: std/string.concat` | Same. `std/string.concat` is `[string] -> string` and unmapped; do **not** try to "fix" it upstream, it is type-different from `concat_String` |
| `@verify(depth: N)` alone | Function is invisible to `ailang verify` — zero contracts are dropped before depth is read (`verify.go:273`) | The annotation tunes unrolling for contracts that already exist. It is not a contract |
| Recursive callee | `... calls user function "find_last" that is not SMT-encodable in this context` | Out of fragment. Annotate with `-- contracts: SKIPPED — RECURSIVE (<callee>)`, do not contort the function (E3) |
| Expecting rejection codes in output | The human reason strips them (`verify.go:340-349`) and `no ensures` bypasses code generation (`:289-304`) | Print reasons, not codes (ADR §3) |

The fragment is defined by six rejection codes in `ailang/internal/smt/encodable.go:44`.

---

## The phases, with gates

Gate after **every** commit: `make check_core && make verify_core && make test`.

### P0 + P2 — one commit
`Makefile` and `src/core/compress.ail`. Split the unticked files into `unstated` (`requires`,
no `ensures`) and `blocked` (`ensures`, fragment-rejected); neither is ticked; `unstated`
exits non-zero. In the same commit, give `truncate_with_suffix` and `compress_output` their
length bounds via `pure func` + `concat_String`, so the only `unstated` file in the tree is
fixed by the commit that makes `unstated` fatal.

Verify the flip both ways: an `unstated` file must exit non-zero, a `blocked` file must not.

### P1 — small, independent, high signal
`src/core/agents_md.ail`. `is_root` → `pure func` with
`ensures { not result || str_length(path) <= 3 }` (measured: VERIFIED, 21ms). Delete
`is_root_length_bound`. Delete `dirname_shrinks` and replace the `Z3 / SMT verification
targets` banner with the `-- contracts: BLOCKED — RECURSIVE (find_last)` note the PLAN gives
verbatim. Do **not** de-recurse `find_last` — explicitly out of scope.

### P5 — take this before P3
`src/core/tool_runtime.ail`. The recall/precision contracts on `has_shell_tokens` and
`starts_with_root_dir`. Run `make dst DST_JOBS=1` before committing: these are production
guards on the tool path, and `pure func` promotion must be behaviour-preserving.

The mutation check is part of the deliverable, not a nicety: a test that the recall contract
**fails** when a token is removed from the list. Without it the contract is unfalsified in CI.

### P3 — the machinery
`verify_classify`, the probe generator, `contracts.register` pinned by contract-and-body hash,
per-contract solve time recorded. ~40 lines of generator; the two probe shapes are written out
in ADR §1 and RESEARCH E5.

### P4 — conditional, may not land
Read ADR §5 first. Its preconditions are touched-file scoping, an honest DP7 message, and a
pinned verified-set — **not** "wait until contracts stop being vacuous". If touched-file
scoping turns out to be a larger change than the rest of this plan put together, stop and
report rather than absorbing it.

---

## Scope fence

- Do not modify `src/core/` outside `compress.ail`, `agents_md.ail`, `tool_runtime.ail`, and
  (P4 only) `session.ail`.
- Do not rewrite the ADR, the PLAN or the RESEARCH note to match what you built. If
  implementation contradicts them, that is a finding — record it as a new section with the
  measurement, the way RESEARCH §3 E4 records its own correction.
- Do not file the upstream AILANG item. PLAN P2 downgraded it to optional ergonomics; if you
  think it is worth filing, use the `ailang-feedback` skill and say so first.
- Do not touch `design_docs/planned/m-motoko-z3-contracts.md`. It is the origin record.
- `REVIEW-adr001-verdicts.md` was written by a different session. Treat it as evidence, not as
  a document you own.

## Stop and report

1. The baseline re-measurement differs from the numbers above.
2. `pure func` promotion changes behaviour, or `make dst` goes red on P5.
3. A contract you expected to verify times out rather than failing. This is the tail PLAN Q2
   flags as genuinely unknown and it is the one result that changes P4's viability — record
   the solve time and the contract.
4. P4's touched-file scoping turns out to require restructuring `dp7_gate`.
5. You find a fifth false claim in the three documents. Four have already been retracted; a
   fifth means the review process missed a class, which is worth more than the fix.

## Commit discipline

One phase per commit, each independently revertible, each with its gate output in the message.
P0+P2 is deliberately one commit — see PLAN's ordering block. Reference the Linear issue in
every commit so the branch stays linked.

## If you only get one thing done

**P5's `has_shell_tokens` contract.** It is about an hour, and it is the only item in this
plan that closes a real gap rather than improving the accounting: that predicate decides
whether a model-authored command is wrapped in a shell (`tool_runtime.ail:20`, `:888`), and it
currently has no test, no property, and no contract. The contract is already measured to catch
the regression that matters, with `s = ";"` as the counterexample.
