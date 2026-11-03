# The pairing model, ported to Rocq

A port of `../PairingModel.lean` and `../diff/enumerate.lean.tail` to Rocq 9.3.0. It was made to
answer one question, whether Rocq would serve this project's method better than Lean, and it is
not a second model of the code: the Lean file is the one the research note and PLAN-001 use.
The answer, and what it rests on, is `../../NOTE-001-rocq-compared-2026-11-03.md`.

| File | What it is |
|---|---|
| `PairingModel.v` | The port: the same definitions, the same 16 theorems and lemmas, in the same order |
| `Enumerate.v` | The port of `enumerate.lean.tail`: the same 16,105 histories, the same five-field lines, extracted to OCaml |
| `main.ml` | Prints the extracted lines. Rocq has no counterpart to Lean's `#eval` that prints |
| `run_rocq.sh` | Checks `PairingModel.v` and its assumptions, extracts and runs `Enumerate.v`, and compares the output with `lean.out` and with the real fold's `ail.out` |
| `audit/Audit.v`, `audit/Audit.lean` | What each prover's assumption report says about a proof by computation |
| `install_rocq.sh` | Installs Rocq 9.3.0 under one directory without root |

## Running it

```sh
diff/run_diff.sh <scratch>                 # the three-way run; writes lean.out and ail.out
rocq/install_rocq.sh <dir>                 # once; then, as it prints:
export OPAMROOT=<dir>/opamroot PATH=<dir>/pfx/bin:$PATH
eval "$(opam env --switch=rocq)"
rocq/run_rocq.sh <scratch> [rocq scratch]  # exit 0 only if all four of its steps pass
```

## Installing Rocq here

The devcontainer has no sudo, no `pkg-config`, no GMP headers and no `m4`, and opam's Rocq
needs all of them through `zarith`. The first attempt, with opam alone, stopped at
`conf-pkg-config`: "depends on the unavailable system package 'pkg-config'". `install_rocq.sh`
therefore builds m4, GMP and pkgconf from source into its own prefix, then installs opam 2.6.1,
OCaml 4.14.2 and Rocq 9.3.0 with `--no-depexts`. Lean, by comparison, is one binary download
by elan, when `release.lean-lang.org` answers (RESEARCH §6.4).

## Runs

| Date | Commit | What | Result |
|---|---|---|---|
| 2026-11-03 | `12672be8` (code under test `43530c0a`, unchanged) | `run_rocq.sh` against a fresh `run_diff.sh` run on the same commit | Exit 0. Details below |
| 2026-11-03 | `12672be8` | The field-swap mutant, below | Caught by the fold comparison and by the theorems, not by the host comparison |
| 2026-11-03 | `12672be8` | `install_rocq.sh` into an empty directory, then `run_rocq.sh` with what it installed | Exit 0 in 330 s, 1.4 GB; `run_rocq.sh` exit 0 with the same `rocq.out` |

### The run of 2026-11-03

- **Toolchains.** Rocq 9.3.0 (`rocq-core` and `rocq-runtime` 9.3.0, `rocq-stdlib` 9.2.0), OCaml
  4.14.2, built by `install_rocq.sh`. For the halves it is compared with, Lean 4.28.0, bun 1.4.4
  and ailang v0.54.14, as in `../diff/README.md`. Linux aarch64, 8 cores.
- **The three-way run it reads** reproduced `../diff/README.md`'s exactly: exit 0, 0 mismatches
  in each comparison, `ts.out` sha256 `6de0b5877d1ace2f…`, `lean.out` `c729a3cb30df336a…`,
  `ail.out` `953896c1a30e5ccc…`.
- **Kernel.** `PairingModel.v` checks in about 0.35 s. `Print Assumptions` reports all eight
  theorems the Lean file prints, `host_twin_agrees` among them, as "Closed under the global
  context": no axioms. The Lean file's `host_twin_agrees` uses `propext` and `Quot.sound`, which
  `simp` brings in and which Motoko's audit allows, so this difference has no practical effect.
- **Differential.** `rocq.out` is byte-identical to `lean.out`: 16,105 lines, sha256
  `c729a3cb30df336a057c31fb99709d1de9deb2bbfb8661a487b8fa3eb4f3bdde`. So its first two fields
  match the real `updatePending`, and `compare_fold.awk` on `rocq.out` against `ail.out` finds 0
  mismatches between the Rocq model and the real fold (15,272 refused by `pairing` on both
  sides, 750 accepted on both with equal `dangling`, 83 accepted by the model and refused by the
  real fold's later `transcript` check).
- **Time.** All of `run_rocq.sh`, including the kernel check, extraction, `ocamlopt` and the run,
  takes about 0.7 s. For comparison, `lean` checks `PairingModel.lean` in about 0.6 s and prints
  the enumeration in about 2.4 s.

### Negative control: a field swap

Rocq's Stdlib has no record-update syntax, so `pairStep` restates all four fields of `PairAcc` by
position, and two of them, `openIds` and `curIds`, have the same type. The mutant swaps them in
the branch where a result closes its call:

```coq
then mkAcc (err acc) (curIds acc) (withoutString (openIds acc) (callId (snd h))) (curSeq acc)
```

It type-checks. What catches it:

| Check | Result |
|---|---|
| The theorems in `PairingModel.v` | `admits_duplicate_result` no longer checks |
| Host side against the real `updatePending` (fields 1-2) | 0 mismatches: `hostPending` does not use `pairStep` |
| `compare_fold.awk`, the definitions alone against the real fold | 517 mismatches of 16,105 |

Until the AILANG half existed (`eaec951a`), the host comparison was the only differential the
worked example had, and it cannot see this slip. Lean's `{ acc with openIds := … }` names the
field it changes, so this slip cannot be written as a reordering there.

### The assumption reports, side by side

`audit/` proves `2 ^ 10 = 1024` by computation in each prover.

| Proof | Report |
|---|---|
| Lean, `by decide` | does not depend on any axioms |
| Lean, `by native_decide` | `[Lean.ofReduceBool, Lean.trustCompiler]` |
| Rocq, `vm_compute; reflexivity` | Closed under the global context |
| Rocq, `exact (eq_refl 1024 <: 2 ^ 10 = 1024)` (a VM cast) | Closed under the global context |
| Rocq, `native_compute` and `<<:` | Not tested: this build has the native compiler disabled, and both fell back to the VM with a warning |
| Rocq, `Admitted` | `Axioms: by_admit : 1 = 2` |

In Rocq the VM is part of the kernel's conversion check by design, so a VM proof is not unsound.
But nothing in the report shows that a proof relied on it, while Lean's report shows
`native_decide` every time. Motoko's audit (`classifyTheoremAxioms`, 029 §3) depends on that.
