# T6 — Compose's output clipping: executed checks

Target: `truncate_utf8_by_bytes` in `packages/motoko-ext-compose/store.ail` (now at lines 20-30;
the brief's 19-29 is one line earlier). Twins: the two module-private TypeScript functions
`truncateUtf8ByBytes` in `src/tui/src/compose-claimcheck.ts:104-109` and
`src/tui/src/env-server.ts:377-381`. Toolchain: ailang v0.54.14 (`e1ef33f`), bun 1.4.4. The tree
was not modified. Everything here was run from the tree root on 2026-11-04.

## Findings (reports.tsv)

| id | property | function | input | what happens | reachable? |
|---|---|---|---|---|---|
| A1-T6-1 | P6.1 | `truncate_utf8_by_bytes` | `"éé"`, max 2 | returned whole, 4 bytes | yes, through `store_stdout_and_elide` at the default cap of 4000 |
| A1-T6-2 | P6.3 (K2, known) | `truncate_utf8_by_bytes` | `"éa"`, max 1 | `c3`, invalid UTF-8 | yes, same path |
| A1-T6-3 | X-4 | claimcheck twin | `"é"`, max 1 | `U+FFFD`, 3 bytes, not a byte prefix | yes, through `runClaimCheck` |
| A1-T6-4 | X-4 | env-server twin | `"é"`, max 1 | `U+FFFD`, 3 bytes | no: the function is never called |
| A1-T6-5 | X-2 | claimcheck twin | `"é"`, max 1 | `truncated`, `omittedBytes` 0 | yes, the informalizer prompt says "0 bytes omitted" |

**A1-T6-1 is the new defect in the target.** `store.ail:22` is `let n = Str.length(s);`, and
`Str.length` counts characters (runes). So the "it fits" branch is taken whenever the character
count is ≤ `max_bytes`, even when the byte length is larger. The result can be up to 4 × `max_bytes`.
The byte value `b` is computed on line 21 but is only used for the slice.

- **Negative control:** changing that one line to `let n = length(b);` gives 0 P6.1 violations
  over all 88,292 cases.
- **Reachable:** the only caller, `store_stdout_and_elide`, takes the truncation branch exactly
  when the byte length is over the cap. So every violation shows up in compose's returned stdout.
  For example, 1,400 × `漢` (4,200 bytes) at the default 4,000-byte cap comes back whole, followed
  by "[stdout elided; full output at …]", with `truncated: true` although nothing was elided.

**P6.2 holds** for the target on every case of every generator, including non-UTF-8 inputs.
`std/bytes.toString` does no repair, so the result is always a byte prefix, and an input that fits
is returned unchanged.

**K2 (P6.3) is confirmed on the real code. The rune gate hides part of it:** with the gate
changed to count bytes, P6.3 violations on chars ≤ 6 go from 16,348 to 46,422. Fixing A1-T6-1
alone would therefore make K2 more frequent. A control that also backs the cut off to a character
boundary (`T6_MUTANT=fixed`) satisfies P6.1, P6.2 and P6.3 on every case.

**The TS twins make the opposite trade-off.** `Buffer.toString("utf8")` replaces a split character
with U+FFFD (3 bytes). The result is therefore always valid UTF-8 (P6.3 holds), but it can be up
to 2 bytes over the cap and is not a byte prefix (A1-T6-3/4). `omittedBytes` is computed against
that expanded text, so it under-reports, down to 0 (A1-T6-5).

All 62,770 disagreements between the AILANG target and the TS twins on chars ≤ 6 (and all of them
on the other generators) are explained by A1-T6-1 or A1-T6-3: TWINX has 0 unexplained. The two TS
twins agree byte for byte everywhere (TWINTS 0).

Route: every defect was first noticed by reading (store.ail:22, `Buffer.toString`, the
`omittedBytes` arithmetic), then confirmed and measured by execution. That is why `route` says
`reading` in every row.

## How the real functions are called (no models)

| fn tag | What runs | How it is reached |
|---|---|---|
| `ail` | `truncate_utf8_by_bytes`, real `store.ail` | `harness/direct/run_direct.sh` copies store.ail into a scratch package and adds the word `export` to that one function. It refuses to run if `diff` shows any other change (exit 3). `t6_direct.ail` then imports it. |
| `ailcaller` | `store_stdout_and_elide`, unmodified, from the real compose package | `harness/caller/run_caller.sh` builds a driver package that depends on the real packages by path. The ports are the conformance package's `canned_ports()` (no-op FS). `check.ts` strips the elision notice to recover the clipped prefix. |
| `tsclaim`, `tsenv` | the two `truncateUtf8ByBytes` | `harness/twins.ts` cuts each function's text out of the real file at run time (from `function truncateUtf8ByBytes(` to the first line that is exactly `}`), transpiles it with `Bun.Transpiler` and evaluates it. |
| `tsrun` | the claimcheck twin, through the exported `runClaimCheck` | Called with a stub `callStream` that captures the informalizer prompt and then throws. The prompt ends with the twin's text, plus `[truncated: N bytes omitted]` when the twin truncated. Only max ≥ 1 is checked, because the caller clamps the cap with `Math.max(1, ·)`. |

AILANG inputs are built as `toString(fromInts(bytes))`, so the non-UTF-8 inputs of the `bytes`
generator are real AILANG strings. Results are read back with `toInts(fromString(r))`. The TS
twins only get the valid-UTF-8 cases, because a JS string cannot hold the others.

## Properties as executed (`harness/check.ts`)

Notation: `in` is the input bytes, `out` the result bytes, `n` is `max_bytes`.

- **P6.1:** n ≥ 0 ⇒ |out| ≤ n.
- **P6.2a:** out is a byte prefix of in.
- **P6.2b:** |in| ≤ n ⇒ out = in. P6.2 is P6.2a and P6.2b together.
- **P6.3:** in is valid UTF-8 ⇒ out is valid UTF-8. Validity is checked with
  `TextDecoder("utf-8", {fatal: true, ignoreBOM: true})`.

Exploratory properties:

- **X-1** (`ailcaller`): n ≥ 0 and `truncated` ⇒ |clipped| < |in|, i.e. something was actually
  elided. It fails on exactly the A1-T6-1 cases, so it is not a separate report.
- **X-2** (`tsclaim`, `tsrun`): if `truncated`, then `omittedBytes` = |in| − lcp(in, out), where
  lcp is the longest common byte prefix. This is the count of input bytes the text does not carry.
- **X-3** (`ailcaller`): the caller's clipped prefix equals the direct result on the same case.
  It held on every case.
- **X-4** (TS twins): P6.1 and P6.2a together, applied to the twins.
- **TWIN:** the TS twin's result equals the AILANG target's result.
- **TWINX:** every TWIN disagreement is explained by one of two things:
  - the AILANG target returned the whole input with |in| > n, and the TS result is
    lossy(in[0..n]);
  - or the AILANG result is in[0..n] and the TS result is lossy(that).
  
  Here lossy means WHATWG decoding with replacement, then re-encoding.
- **TWINTS:** the two TS twins return identical results.
- **TWINRUN** (n ≥ 1): `runClaimCheck`'s view of the twin (text, `truncated`, `omittedBytes`)
  equals the extracted twin's return value.

## Generators and sizes (`harness/gen.ts`, deterministic)

| generator | what | cases |
|---|---|---:|
| `chars 6` | every string of 0..6 characters over {`a`, `é`, `€`, `😀`} (1, 2, 3, 4 bytes) × every n in −1..len+1 | 93,753 |
| `bytes 3` | every byte string of length 0..3 over 12 bytes: `61 c3 a9 e2 82 ac f0 9f 98 80 ff bf` (whole and partial 2/3/4-byte encodings, `ff`, a lone continuation byte) × every n in −1..len+1. Mostly invalid UTF-8. | 11,139 |
| `random 20000` (seed 6) | 0..64 code points drawn from ASCII, U+0080–07FF, U+0800–FFFF (no surrogates), astral, CJK and the encoding-boundary code points U+007F/0080/07FF/0800/FFFD/FFFF/10000/10FFFF; n uniform in −2..len+2 | 20,000 |
| `random 500 7 2000` | the same, 0..2,000 code points (longest input in this run: 5,204 bytes) | 500 |
| `cjk 1400` | 1,400 × U+6F22 (4,200 bytes) × n ∈ {0, 1, 2, 1399, 1400, 1401, 2800, 4000, 4199, 4200, 4201} | 11 |

Largest exhaustive bound: all strings of up to 6 characters over a 4-letter alphabet with every
width, and all byte strings up to length 3 over a 12-byte alphabet. Largest single input:
5,204 bytes (random, long). Every case went through all five function tags (the TS ones on
valid UTF-8 only).

## Results (violations / cases checked; from `results/*.report` via `harness/tabulate.ts`)

| fn:property | chars_6 | bytes_3 | random_20000 | random_500_7_2000 | cjk_1400 |
|---|---:|---:|---:|---:|---:|
| `ail:P6.1` | 46422 / 88292 | 273 / 9254 | 10916 / 19112 | 300 / 498 | 5 / 11 |
| `ail:P6.2a` | 0 / 93753 | 0 / 11139 | 0 / 20000 | 0 / 500 | 0 / 11 |
| `ail:P6.2b` | 0 / 10922 | 0 / 3770 | 0 / 1336 | 0 / 4 | 0 / 2 |
| `ail:P6.3` | 16348 / 93753 | 7 / 431 | 4071 / 20000 | 121 / 500 | 3 / 11 |
| `ailcaller:P6.1` | 46422 / 88292 | 273 / 9254 | 10916 / 19112 | 300 / 498 | 5 / 11 |
| `ailcaller:P6.2a` | 0 / 82831 | 0 / 7369 | 0 / 18664 | 0 / 496 | 0 / 9 |
| `ailcaller:P6.2b` | 0 / 10922 | 0 / 3770 | 0 / 1336 | 0 / 4 | 0 / 2 |
| `ailcaller:P6.3` | 16348 / 82831 | 7 / 283 | 4071 / 18664 | 121 / 496 | 3 / 9 |
| `ailcaller:X-1` | 46422 / 77370 | 273 / 5484 | 10916 / 17776 | 300 / 494 | 5 / 9 |
| `ailcaller:X-3` | 0 / 82831 | 0 / 7369 | 0 / 18664 | 0 / 496 | 0 / 9 |
| `tsclaim:P6.1` | 38685 / 88292 | 119 / 357 | 9414 / 19112 | 261 / 498 | 7 / 11 |
| `tsclaim:P6.2a` | 46422 / 93753 | 119 / 431 | 10571 / 20000 | 291 / 500 | 7 / 11 |
| `tsclaim:P6.2b` | 0 / 10922 | 0 / 148 | 0 / 1336 | 0 / 4 | 0 / 2 |
| `tsclaim:P6.3` | 0 / 93753 | 0 / 431 | 0 / 20000 | 0 / 500 | 0 / 11 |
| `tsclaim:TWIN` | 62770 / 93753 | 126 / 431 | 14970 / 20000 | 421 / 500 | 8 / 11 |
| `tsclaim:TWINX` | 0 / 62770 | 0 / 126 | 0 / 14970 | 0 / 421 | 0 / 8 |
| `tsclaim:X-2` | 46422 / 82831 | 119 / 283 | 10571 / 18664 | 291 / 496 | 7 / 9 |
| `tsclaim:X-4` | 46422 / 93753 | 119 / 431 | 10847 / 20000 | 299 / 500 | 7 / 11 |
| `tsenv:P6.1` | 38685 / 88292 | 119 / 357 | 9414 / 19112 | 261 / 498 | 7 / 11 |
| `tsenv:P6.2a` | 46422 / 93753 | 119 / 431 | 10571 / 20000 | 291 / 500 | 7 / 11 |
| `tsenv:P6.2b` | 0 / 10922 | 0 / 148 | 0 / 1336 | 0 / 4 | 0 / 2 |
| `tsenv:P6.3` | 0 / 93753 | 0 / 431 | 0 / 20000 | 0 / 500 | 0 / 11 |
| `tsenv:TWIN` | 62770 / 93753 | 126 / 431 | 14970 / 20000 | 421 / 500 | 8 / 11 |
| `tsenv:TWINTS` | 0 / 93753 | 0 / 431 | 0 / 20000 | 0 / 500 | 0 / 11 |
| `tsenv:X-4` | 46422 / 93753 | 119 / 431 | 10847 / 20000 | 299 / 500 | 7 / 11 |
| `tsrun:P6.1` | 38685 / 82831 | 119 / 283 | 9414 / 18623 | 261 / 498 | 7 / 10 |
| `tsrun:P6.2a` | 46422 / 82831 | 119 / 283 | 10571 / 18623 | 291 / 498 | 7 / 10 |
| `tsrun:P6.2b` | 0 / 10921 | 0 / 147 | 0 / 1272 | 0 / 4 | 0 / 2 |
| `tsrun:P6.3` | 0 / 82831 | 0 / 283 | 0 / 18623 | 0 / 498 | 0 / 10 |
| `tsrun:TWINRUN` | 0 / 82831 | 0 / 283 | 0 / 18623 | 0 / 498 | 0 / 10 |
| `tsrun:X-2` | 46422 / 71910 | 119 / 136 | 10571 / 17351 | 291 / 494 | 7 / 8 |
| `tsrun:X-4` | 46422 / 82831 | 119 / 283 | 10847 / 18623 | 299 / 498 | 7 / 10 |

Read across a row: the AILANG target and its caller have identical counts on every property they
share (the caller sees only the cases with |in| > n on the truncation branch, so its denominators
are smaller). The three TS rows are identical to one another. `tsclaim:X-4` can exceed
`tsclaim:P6.2a` (random: 10,847 vs 10,571) because an input that contains U+FFFD can be cut and
re-expanded into a byte prefix that is still longer than n.

## Observations not filed as reports

- **The elided stdout exceeds the cap.** `store_stdout_and_elide` returns
  `clipped + "\n[stdout elided; full output at …]"`, so the returned stdout is larger than
  `max_stdout_bytes` by the notice's length on every truncation. RESEARCH §7 already raises this
  as a question of intent, and it is not about the target's properties.
- **A malformed cap drops the certificate.** env-server.ts:1507 reads the claimcheck cap as
  `Math.max(1, Number(env ?? 4000))`. `AILANG_COMPOSE_CLAIMCHECK_STDOUT_MAX_BYTES=4k` gives NaN,
  and the twin then returns `""` with `truncated: true`: the informalizer gets no certificate at
  all. An empty value gives a 1-byte cap. `harness/observations/nan_cap.ts` runs this through the
  real `runClaimCheck` and exits 1. This is in the config read, not in the twin, so it is not a
  row.
- **Negative max_bytes.** The target returns `""`, and `store_stdout_and_elide` reports
  `truncated: true` even for an empty stdout. This is outside P6.1's domain (n ≥ 0) and
  unreachable, because `clamp_positive` makes the cap ≥ 1 (compose.ail:420, :851).

## Negative controls (`harness/run_controls.sh`)

These show that the checks pass on correct code, so a reported violation belongs to the code and
not to the checker.

- `T6_MUTANT=bytegate`: the shim with `Str.length(s)` → `length(b)`. P6.1 holds everywhere.
- `T6_MUTANT=fixed`: bytegate, plus a cut that backs off over continuation bytes. P6.1, P6.2 and
  P6.3 all hold. `repro.sh A1-T6-1` and `A1-T6-2` exit 0 under it.
- `controls/make_fixed_twins.ts`: the TS twins with the same back-off. X-4, X-2, P6.1, P6.2 and
  P6.3 all hold. The A1-T6-3/4/5 witness check exits 0 against them.

Control reports (violations / cases):

- `fixed_twins_chars_6.report`: tsclaim:P6.1 0 / 88292, tsclaim:P6.2a 0 / 93753, tsclaim:P6.2b 0 / 10922, tsclaim:P6.3 0 / 93753, tsclaim:X-2 0 / 82831, tsclaim:X-4 0 / 93753, tsenv:P6.1 0 / 88292, tsenv:P6.2a 0 / 93753, tsenv:P6.2b 0 / 10922, tsenv:P6.3 0 / 93753, tsenv:TWINTS 0 / 93753, tsenv:X-4 0 / 93753, tsrun:P6.1 0 / 82831, tsrun:P6.2a 0 / 82831, tsrun:P6.2b 0 / 10921, tsrun:P6.3 0 / 82831, tsrun:TWINRUN 0 / 82831, tsrun:X-2 0 / 71910, tsrun:X-4 0 / 82831
- `mutant_bytegate_bytes_3.report`: ail:P6.1 0 / 9254, ail:P6.2a 0 / 11139, ail:P6.2b 0 / 3770, ail:P6.3 119 / 431
- `mutant_bytegate_chars_6.report`: ail:P6.1 0 / 88292, ail:P6.2a 0 / 93753, ail:P6.2b 0 / 10922, ail:P6.3 46422 / 93753
- `mutant_bytegate_cjk_1400.report`: ail:P6.1 0 / 11, ail:P6.2a 0 / 11, ail:P6.2b 0 / 2, ail:P6.3 7 / 11
- `mutant_bytegate_random_20000.report`: ail:P6.1 0 / 19112, ail:P6.2a 0 / 20000, ail:P6.2b 0 / 1336, ail:P6.3 10847 / 20000
- `mutant_fixed_chars_6.report`: ail:P6.1 0 / 88292, ail:P6.2a 0 / 93753, ail:P6.2b 0 / 10922, ail:P6.3 0 / 93753
- `results/survey_and_controls.log`:
  - `control: repro.sh A1-T6-1 under T6_MUTANT=fixed exits 0 (expected 0)`
  - `control: repro.sh A1-T6-2 under T6_MUTANT=fixed exits 0 (expected 0)`
  - `control: the A1-T6-3/4/5 witness against the fixed TS twins exits 0 (expected 0)`

## Reproducing

From the tree root:

```
bash /home/motoko/trial-043/s/t043-t6-a1/out/repro/repro.sh A1-T6-1      # also A1-T6-1-caller, -2 .. -5
bash /home/motoko/trial-043/s/t043-t6-a1/out/harness/run_survey.sh       # every generator: ~6 min idle, ~14 min on today's shared machine
bash /home/motoko/trial-043/s/t043-t6-a1/out/harness/run_controls.sh     # after the survey, ~1 min
```

Each repro takes 1–8 s. It exits 1 if the defect is present, 0 if absent, and 2 or 3 on a
harness error. The direct and caller harnesses write their scratch AILANG packages to `mktemp -d`.
Their `ailang.toml` files point at the tree's packages by absolute path, and each run regenerates
the shim from the current store.ail.

## Limits

- **Bounded evidence.** This is evidence on the inputs listed, not a proof. Exhaustive coverage
  stops at 6 characters and 3 raw bytes.
- **The direct harness depends on the export shim.** It is the real file plus one word, checked
  by diff on every run. The caller harness needs no shim and shows the same counts for every
  property it can see.
- **The TS extraction relies on formatting.** It assumes each twin ends at the first line that
  is exactly `}`. `tsrun` goes through the real exported caller and agrees with `tsclaim`
  field by field on every case both run (TWINRUN 0).
- **Not followed:** whether compose's elided stdout reaches message content or a journal raw
  (RESEARCH §7's open question), and how `ran.raw_stdout` is decoded upstream.

## Files

- `reports.tsv`: the five reports.
- `repro/repro.sh`: one witness per report id.
- `harness/gen.ts`: the generators.
- `harness/check.ts`: the executable properties.
- `harness/twins.ts`: loads the TS twins.
- `harness/direct/`: `t6_direct.ail` and `run_direct.sh`, the shim and its driver.
- `harness/caller/`: `t6_caller.ail` and `run_caller.sh`.
- `harness/run_survey.sh`, `harness/run_controls.sh`, `harness/controls/make_fixed_twins.ts`.
- `harness/tabulate.ts`: builds the results table.
- `harness/observations/nan_cap.ts`.
- `probe/`: the first exploratory runs (see its README).
- `results/`: the reports, the control reports and the run log. The cases and raw outputs are
  gzipped. `results/SHA256SUMS` lists the checksums of the uncompressed files, so verify with
  `gunzip -k *.gz && sha256sum -c SHA256SUMS`. `run_controls.sh` needs `chars_6.cases`
  uncompressed, which `run_survey.sh` writes.
