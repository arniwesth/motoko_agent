# NOTE-002 — `ailang test` re-elaborates the whole module twice per inline test case (2026-09-24)

Status: Measured. Filed upstream as AILANG public-feedback ticket **`fb_380d25d641a428b6`**
(queued 2026-09-24T17:27:11Z, category limitation, via `mcp.ailang.sunholo.com` `submit_feedback`).
Grounded at: HEAD `8a5b9a72`, AILANG `v0.33.0` (commit `ae36986`), equal to the `ailang.toml` floor.
Found by: LEG-CI-COVERAGE-CAP — `make test_coverage` red on 9 of 11 CI runs of the 031 branch, every
time `src/core/session.ail` over the 300 s per-file cap. This note carries the AILANG half of that
finding so the tool's cap derivation (`tools/test_coverage/derive.py`, `--timeout`) and the upstream
ticket can cite one place.

## 0. TL;DR

For every inline test **case**, `ailang test` runs the compile pipeline over the **entire module**
twice — once in `ExtractFunctionBinding` (`internal/testing/runner.go:67`, `executor.go:380`) and
once in `ExtractPureClusterForFunction` (`runner.go:78`, `executor.go:587`) — and discards both
results. `collector.go:125` makes each tuple of a `tests [...]` block its own case. A file therefore
costs **cases × its module's elaboration time**, and the largest module with the most tests hits
any flat time limit first, whether or not anything is wrong with it. Named `test "..."` blocks do not
escape it: `EvaluateNamedTestBodyExprs` (`executor.go:184`) re-runs the pipeline on the stripped
module per test as well.

## 1. Minimal reproduction (no dependencies)

`ailang.toml` with `module_prefix = "repro"` and no dependencies, then a generator for a module of
N trivial pure functions and M one-case tests:

```python
import sys
n, m = int(sys.argv[1]), int(sys.argv[2])
out = [f"module repro/m_{n}_{m}", ""]
for i in range(n):
    out += [f"pure func f{i}(x: int) -> int {{", f"  if x > {i} then x - {i} else x + {i}", "}", ""]
for j in range(m):
    out += [f"pure func t{j}() -> bool", "  tests [((), true)]", "{", f"  f0({j}) == {j}", "}", ""]
open(f"repro/m_{n}_{m}.ail", "w").write("\n".join(out))
```

`ailang test --format json repro/m_N_M.ail`, wall seconds, dev box (aarch64, 8 cores):

| N functions | M = 1 | M = 16 | per extra case |
|---|---|---|---|
| 800 | 1.0 | 2.4 | 0.09 |
| 2,000 | 5.2 | 9.4 | 0.28 |
| 4,000 | 22.3 | 33.9 | 0.77 |

Every test passes and each touches only `f0`, so the per-case cost should be independent of N. It
grows with N instead, and faster than N. (Separately: a cold `ailang check` of the N = 4,000 module is
20.8 s, so the M = 1 column is dominated by one ~N² elaboration; that is not this note's claim.)

## 2. In Motoko

`src/core/session.ail`: 6,339 lines, the largest module in `src/core`, 41 cases.

- CI, 4 vCPU EPYC 7763, alone, cold cache, three runners (probe run `36029843520`): **262–267 s
  wall, 392–410 CPU-s**. The first case costs 67–71 s (the cold import closure); each of the other 40
  costs 4.9–5.0 s. A warm `ailang check` of the same file is 2.7 s here.
- Dev box, `--jobs 1` walk of all 73 files: session.ail is **418 of 1,046 CPU-s (40%)**, 10.2 CPU-s
  per case; the next file is 104 CPU-s.
- **A companion test module does not help.** Six cases moved into a module that imports
  session.ail cost 7.3 CPU-s each warm, against 8.1 inline: the imported module is elaborated per
  case too. Splitting session.ail's tests out would move the cost under the per-file cap without
  reducing it, and would need 45 of its private functions exported. Not done.

What was done instead is in `derive.py` (the cap, 300 → 600 s, with its two bounds) and in the
`Makefile` (`TEST_COVERAGE_JOBS` fitted to the core count). Both cite this note.

## 3. What an upstream fix would buy

The executor already keeps the pipeline's modules (`e.modules = result.Modules`) and the Core
program is the same for every case of a file. Elaborating once per file and reusing both across
cases would take session.ail from ~263 s to roughly the one cold compile plus 41 evaluations —
on the order of 70–80 s on the same runner — and would make a test file's cost linear in its tests
rather than in tests × module size.

## 4. Re-test procedure

At each AILANG bump: regenerate §1 at N = 4,000 with M = 1 and M = 16. **Fixed** when the per-case
increment no longer grows with N (M = 16 within a few seconds of M = 1 at N = 4,000 as at N = 800).
Then re-measure session.ail alone (`tools/test_coverage/derive.py` prints its wall and CPU in the
"slowest against the … cap" line of every run) and re-derive the cap's lower bound from it.

## 5. Provenance

Repro and probes were run in the session scratchpad with the PATH `ailang`
(`/home/motoko/.local/bin/ailang`, v0.33.0); source citations are from the v0.33.0 tag checked out
at `~/.local/share/ailang`. CI figures are from the tc-probe workflow on a throwaway branch
(`arniwesth/ci-probe-test-coverage`, deleted after), per-file JSON uploaded as its artifacts.

## 6. Upstream

Filed via `mcp.ailang.sunholo.com` `submit_feedback`, category `limitation`: ticket
**`fb_380d25d641a428b6`**, queued 2026-09-24T17:27:11Z. Body = §0, §1, §2 (numbers only) and §3;
snippet = the §1 generator plus three timing commands. No GitHub mirror.
