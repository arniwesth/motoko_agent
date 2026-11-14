# T6 — `truncate_utf8_by_bytes`: executed checks on the real code

Target: `packages/motoko-ext-compose/store.ail:20-30` in this snapshot. The brief says 19-29,
and the function sits one line lower. Arm A, replicate 2. Every result below comes from running
the tree's own code. Nothing here models the function.

## Findings

| Report | Property | What | Status |
|---|---|---|---|
| A2-T6-1 | P6.1 | The fits test compares `Str.length` (a code-point count) with a byte budget, so an input with ≤ n code points but > n bytes is returned whole. `"é"` with n=1 gives 2 bytes; 2,000 × `中` at compose's default n=4000 gives 6,000 bytes | **New.** Reachable through the only caller |
| A2-T6-2 | P6.3 | A cut at byte n can split a character. `"éa"` with n=1 gives `C3` | Known (K2). Re-confirmed |
| A2-T6-3 | X-1 | The TypeScript twin `truncateUtf8ByBytes` (`compose-claimcheck.ts:104`) repairs the split character to U+FFFD. Its text is then not a prefix of the input and can exceed `maxBytes` by up to 2 bytes. `omittedBytes` is understated, and is 0 on the witness | Twin defect. Reachable via `env-server.ts:1810` |
| A2-T6-4 | X-2 | `store_stdout_and_elide`, the target's only caller, drops `dir_make`/`file_write` failures and still points at `raw_path` as holding the full output | Outside lines 19-29. Low severity |

**P6.2 held** on every case and route. The result is always a byte prefix of the input: 0 of
674,894 cases violated it, invalid UTF-8 inputs included. The input comes back unchanged
whenever it fits in bytes: 0 of 86,451 cases violated it. When the function cuts, the result is
exactly the first n bytes (0 exceptions in 415,596 cuts), because `std/bytes.toString` does not
repair. The function returns `""` for every
n < 0. That is outside the properties, which assume n ≥ 0, and is noted only.

Exploratory properties used in `reports.tsv`:

- **X-1**: P6.1 and P6.2 stated on the TypeScript twin's `text`. For n ≥ 1 and a valid UTF-8
  input b, `|text| ≤ n` and `text` is a byte prefix of b. The caller clamps n to ≥ 1, and a JS
  string can only hold valid input.
- **X-2**: when the port reports that the raw output could not be written, the result does not
  claim the full output is at `raw_path`, or it carries the failure.

## Method

**Two routes into the private AILANG function.** `truncate_utf8_by_bytes` is not exported.
AILANG refuses to import it, and also refuses `--entry` on it ("entrypoint … not found …
Available exports: [...]").

1. **Direct** (`harness/direct.sh`). The script builds a temporary file in `out/`:
   `store.ail` verbatim, five `import` lines inserted after the file's last import, and
   `direct_driver.ail.part` appended. It then checks that removing exactly those additions gives
   back `store.ail` byte for byte; otherwise it exits 2. The function under test is the tree's
   text, compiled with its own imports. The driver also prints the runtime's own
   `Str.length(input)` and `std/bytes.length(input)`. Failures are explained with those counts,
   so nothing re-implements them.
2. **Through the exported caller** (`harness/via_store.ail`). It calls
   `store_stdout_and_elide`, imported from the real package, with the conformance package's
   `canned_ports()`. That function calls the target only when the input is longer than n bytes.
   The checker strips the `"\n[stdout elided; full output at <raw_path>]"` suffix and checks
   the rest.

The two routes agreed on every case: `X-route: clip != direct` was 0. `out/ailang.toml` and
`out/ailang.lock` resolve the four packages by path to `../tree/packages/...`. That is how a
harness file in `out/` imports `pkg/sunholo/...`. Nothing in the tree was modified.

**The TypeScript twin.** `truncateUtf8ByBytes` in `src/tui/src/compose-claimcheck.ts` is
module-private. `check.ts` and `repro.ts` reach it through the exported `runClaimCheck`, using a
stub `callStream` that captures the informalizer prompt. That gives `text`, `truncated` (from
telemetry) and `omittedBytes` (from the `[truncated: N bytes omitted]` marker), all from the
real function. The second copy, `env-server.ts:377`, has an identical body and no callers. It
was read but not executed.

**Executable properties** (`harness/check.ts`). b is the input bytes, r the result bytes:

- P6.1: `n ≥ 0 ⇒ |r| ≤ n`
- P6.2a: r is a prefix of b
- P6.2b: `|b| ≤ n ⇒ r = b`
- P6.3: b valid UTF-8 ⇒ r valid UTF-8, using a strict `TextDecoder` with the BOM kept

Additional checks:

- `cut==b[0:n]`: whenever `Str.length(b) > n`, the result is exactly the first n bytes.
- `P6.1-explained`: every P6.1 failure has `Str.length(b) ≤ n < |b|` and r = b.
- `X-route`: the store route's `truncated` flag equals `|b| > n`, and its clip equals the direct
  result.
- The twin is checked against P6.1, P6.2 and P6.3, against the AILANG function, and on its flag
  and `omittedBytes`.

A side check (`harness/strlen_check.ts`, output in `results/strlen_check.txt`) confirmed that on
valid input, `Str.length` equals the code-point count: 0 mismatches in 104,747 valid cases for
seed 1 and 319,979 for seed 2. On the 125,084 invalid inputs it never exceeds the byte count. So "code-point count" in A2-T6-1 is measured, not assumed.

## Generators and sizes

`harness/gen_cases.ts` is deterministic per seed. Each case is (max_bytes, input bytes). Inputs
are built as raw bytes, so strings that are not valid UTF-8 are covered too.

| Generator | What | Seed 1 (units ≤ 5, random 5,000) | Seed 2 (units ≤ 6, random 20,000) |
|---|---|---|---|
| `units` | every string of 0..L units over `a`, `é`, `€`, `😀` (1-4 bytes), every n from −1 to \|b\|+1 | 1,365 strings, 20,025 cases | 5,461 strings, 93,753 cases |
| `bytes` | every byte string of length ≤ 3 over 17 bytes at the UTF-8 class boundaries (00 41 7F 80 8F BF C0 C2 DF E0 E2 ED EF F0 F4 F5 FF), every n from −1 to \|b\|+1 | 5,220 strings, 30,994 cases | same |
| `bytes1` | all 256 one-byte and all 65,536 two-byte strings, n ∈ {0, 1} | 131,584 cases | same |
| `random` | valid strings of 0-64 code points from weighted classes (ASCII, C0, Latin/2-byte, CJK, combining marks, other BMP, emoji, astral, NUL/ZWJ/U+FFFD/BOM/U+FFFF/U+10FFFF), n at 0, 1, runes±1, bytes±1 plus two random values | 47,187 cases | 188,691 cases |
| `big` | production-shaped, n around compose's default 4000: 2,000 × `中`, 1,000 × 😀, 3,999 × `a` + 😀, 4,000 × `é`, 4,001 × `x` | 16 cases | same |
| `extreme` | n = ±2³¹, 2³¹−1, ±2⁶² on five short inputs | 25 cases | same |
| **total** | | **229,831** | **445,063** |

The units grid is exhaustive: every string of up to 6 characters over the four UTF-8 widths,
with every n. The bytes grid is exhaustive over the chosen byte classes up to length 3, and over
all bytes up to length 2.

## Results, unmutated code

Results are from `results/1.check.txt` and `results/2.check.txt`.

| Check | Seed 1 violated / checked | Seed 2 violated / checked |
|---|---|---|
| P6.1 (direct) | 30,716 / 223,159 | 124,448 / 434,052 |
| P6.1 via store | 30,716 / 199,414 | 124,448 / 371,346 |
| P6.1-explained (failures with Str.length ≤ n < \|b\|, r = b) | 30,716 / 30,716 explained | 124,448 / 124,448 explained |
| P6.2a prefix | 0 / 229,831 | 0 / 445,063 |
| P6.2b unchanged when it fits | 0 / 23,745 | 0 / 62,706 |
| cut is exactly b[0:n] | 0 / 168,698 | 0 / 246,898 |
| P6.3 (K2) | 10,911 / 104,747 | 47,193 / 319,979 |
| n < 0 ⇒ "" | 0 / 6,672 | 0 / 11,011 |
| X-route (store route agrees with direct) | 0 / 229,831 | 0 / 445,063 |
| X-1 twin byte bound | 26,042 / 78,280 | 104,984 / 270,077 |
| X-1 twin prefix | 29,913 / 78,280 | 121,798 / 270,077 |
| twin P6.3 | 0 / 78,280 | 0 / 270,077 |
| twin == AILANG function | 41,346 differ / 78,280 | 171,075 differ / 270,077 |

Largest P6.1 overshoot: the result is 4 × n (n=1, one emoji), and 6,000 bytes for n=4000
(2,000 × `中`). The twin's overshoot is at most 2 bytes.

## Negative controls

`T6_MUTANT=<name>` makes `direct.sh` rewrite exactly one line of its generated copy, never the
tree. Under a mutant, `repro.ts` skips the store route, because that route always loads the
tree's package. Results below are for the direct route, seed 1 / seed 2:

| Mutant | Change | Result |
|---|---|---|
| `fix_len` | `let n = Str.length(s);` → `let n = length(b);` | P6.1 0 / 223,159 and 0 / 434,052. P6.2a and P6.2b 0. P6.3 rises to 30,465 and 123,994. The twin differs from the function on exactly those cases (30,465 and 123,994). `repro.ts P6.1 1 c3a9` and `P6.1 4000 e4b8ad*2000` exit 0 |
| `cut_from_1` | `slice(b, 0, max_bytes)` → `slice(b, 1, max_bytes)` | P6.2a fails on 90,702 and 149,691. `cut==b[0:n]` fails on the same counts |
| `over_by_1` | `slice(b, 0, max_bytes + 1)` | P6.1 fails on 199,414 and 371,346. 168,698 and 246,898 of those are unexplained by the Str.length rule, so the characterisation check sees a different cause |

So the checks tell the real function apart from each one-line change. With A2-T6-1 fixed, P6.1
holds on every generated case, and only K2 remains. Because the fixed function and the twin
then differ exactly where the AILANG result is invalid UTF-8, all of their remaining
disagreement is K2 against the twin's U+FFFD repair.

A side observation from `cut_from_1`: `std/bytes.slice` takes `(start, length)`, not
`(start, end)`. With start 0 the two agree, so the target is not affected.

## Reachability

- **A2-T6-1, A2-T6-2.** `compose.ail:723` calls
  `store_stdout_and_elide(…, ran.raw_stdout, max_stdout_bytes)`, with
  `max_stdout_bytes = clamp_positive(cfg.authoring.stdout_max_bytes, 4000)` (`:851`, always
  ≥ 1). The returned `stdout` and `truncated` become `ComposeResult.stdout` and `.truncated`
  (`:753`). For any process output with ≤ 4,000 code points but > 4,000 bytes (CJK, emoji,
  accented text), the main agent gets the whole output, up to 16,000 bytes. It also gets
  `truncated: true` and a notice saying the output was elided.
- **A2-T6-3.** `env-server.ts:1810` runs claimcheck on `ran.raw_stdout` with
  `AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES` (default 4000, clamped to ≥ 1).

## Not checked, and limits

- These are bounded checks on generated inputs, not proofs. The exhaustive parts are those in
  the generator table.
- Whether the elided output should include the notice inside the cap is an intent question
  (RESEARCH §7), so it is not reported. So is the units mismatch between compose's
  `stdout_bytes` metadata, which uses `_str_len` (`compose.ail:167`), and the byte cap.
- `src/tui/src/scratchpad/transcript.ts:76` clips the same way as the TypeScript twin, with
  `subarray(…).toString("utf8")`. It is a different function and was not exercised.
- `env-server.ts:377`, the dead twin, was read but not executed.

## Files

- `reports.tsv`: the four reports. Each `repro` is `bun …/out/harness/repro.ts <check> <n> <hex>`,
  run from the tree root. It exits 1 when the defect is present, 0 when absent and 2 on a harness
  error. Each took under 4 s here.
- `harness/repro.ts`: one witness, one check (P6.1, P6.2, P6.3, X-1, X-2), on both AILANG routes
  or the twin.
- `harness/direct.sh` and `harness/direct_driver.ail.part`: the direct route, with the
  `T6_MUTANT` negative controls.
- `harness/via_store.ail`: the exported-caller route.
- `harness/store_write.ail`: X-2. It asks the canned ports what they answer, then calls
  `store_stdout_and_elide`.
- `harness/gen_cases.ts`: the generators.
- `harness/check.ts`: the properties, the route comparison and the twin comparison.
- `harness/strlen_check.ts`: the side check on `Str.length`.
- `harness/run_all.sh <scratch> <results> [seed units bytes random]...`: the full sweep plus
  the mutants.
- `results/`: check outputs per seed and per mutant, and the sha256 of each run's cases and
  outputs. The case files themselves are regenerated from the seed.
- `ailang.toml` and `ailang.lock`: package resolution for the AILANG harnesses.

Full sweep, from the tree root:

```
/home/motoko/trial-043/s/t043-t6-a2/out/harness/run_all.sh <scratch dir> /home/motoko/trial-043/s/t043-t6-a2/out/results 1 5 3 5000 2 6 3 20000
```

Toolchain: ailang v0.54.14 (e1ef33f), bun 1.4.4, linux arm64.

## Run log

All runs were on 2026-11-04, on a shared machine that other jobs were also loading.

- **Seed 1** (229,831 cases): `direct.sh` 28 s, `via_store.ail` 24 s. **Seed 2** (445,063
  cases): 51 s and 92 s. `check.ts` takes a few seconds per sweep, twin included.
- `run_all.sh` exits 1 on the unmodified code, by design: P6.1 fails.
- **Determinism.** Seed 1 was re-run with the final `run_all.sh` into a scratch dir. The cases,
  tags and both route outputs had the same sha256 as `results/1.sha256`. `1.check.txt` and all
  three `1.mutant-*.check.txt` were byte-identical.
- **One transient failure.** An earlier re-run stopped at its first mutant: `direct.sh` failed
  once, and `run_all.sh` then threw its stderr away, so the cause is unknown. The same command
  succeeded when run alone, and on the next full re-run. `run_all.sh` now keeps the mutant's
  stderr, prints it on failure and retries once, writing `retry: mutant <name>` into
  `<seed>.gen.txt`. No retry happened in the delivered results or the final re-run.
- Every `repro` in `reports.tsv` was run from the tree root as written. Each exits 1, in 0.05 to
  3.4 s. `T6_MUTANT=fix_len` makes both P6.1 repro witnesses exit 0.
- `out/.ailang/` is ailang's compile cache, created by these runs.
