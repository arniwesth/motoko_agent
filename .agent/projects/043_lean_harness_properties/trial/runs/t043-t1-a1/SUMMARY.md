# T1, the herdr environment gate (MOT-118): executed checks

Arm A, replicate 1. Target: `readHerdrEnvironment` (`src/tui/src/herdr-agent-state.ts:157`) and
`herdr_env_ready` (`packages/motoko-ext-herdr/types.ail:1425`). The code under test is the snapshot
at `../tree`, unchanged. Toolchain: bun 1.4.4 and ailang v0.54.14 (`e1ef33f`). Run 2026-11-04.

## Findings

Four reports in `reports.tsv`. Every one is reproduced by executing the real functions, and each has
a mutant that turns its repro from 1 to 0 (see Controls). All four were first seen by reading the
code; the harnesses then confirmed each and measured how far it reaches.

| Report | Property | What is wrong | Witness |
|---|---|---|---|
| A1-T1-1 | P1.1 | `herdr_env_ready` tests `herdr_env >= "1"`, a string ordering, where the TS twin tests `=== "1"`. AILANG accepts every HERDR_ENV that sorts at or after `"1"` byte-wise | `HERDR_ENV=2`, bin and pane set |
| A1-T1-2 | P1.1 | `readHerdrEnvironment` rejects the binary only when it is `undefined`, so `HERDR_BIN_PATH=""` passes in TS and fails in AILANG | `HERDR_ENV=1 HERDR_BIN_PATH= HERDR_PANE_ID=w1:p7` |
| A1-T1-3 | X-1 | The only caller, `register_with_config`, passes `getEnvOr("HERDR_BIN_PATH", "herdr")`, so with HERDR_BIN_PATH **unset** the extension advertises its tools while the TS gate is null | `HERDR_ENV=1`, HERDR_BIN_PATH unset, `HERDR_PANE_ID=w1:p7` |
| A1-T1-4 | X-2 | `buildChildEnv` drops blank HERDR_* values, so `HERDR_PANE_ID=" "` makes the TUI report while the runtime's extension sees no pane | `HERDR_ENV=1 HERDR_BIN_PATH=/usr/local/bin/herdr HERDR_PANE_ID=" "` |

Against the documented rule (HERDR_ENV is exactly `1` and both other variables are non-empty:
`herdr-agent-state.ts:158-160`, `types.ail:1407`, `types.ail:1290`), A1-T1-1 is the AILANG side's
departure and A1-T1-2 the TS side's. A1-T1-3 is outside both functions. It breaks the premise of
P1.1 that unset reaches `herdr_env_ready` as `""`, and it makes the inline test
`(("1", "", "w1:p7"), false)` unreachable from a real environment. A1-T1-4 is outside both
functions as well. It is in the forwarding step that the comment at `herdr-agent-state.ts:152-155`
names as "what stands between the two copies".

No other P1.1 mismatch exists in what was generated. With A1-T1-1 and A1-T1-2 both fixed in a
copy, the full 42,524-case sweep has 0 mismatches (Controls, row `fix-ail-env+ts-bin`).

## Exploratory properties

- **X-1** (the gate at its call site). For every environment E over the three variables, each
  unset or a string: `readHerdrEnvironment(E) !== null` iff the real `register_with_config`, run by
  `ailang` in a process whose environment holds E's three variables, advertises tools. This is
  P1.1 with unset left as the extension actually reads it rather than mapped to `""`.
- **X-2** (the gate end to end). The same, but the `ailang` process's environment is exactly
  what the real `buildChildEnv` (`runtime-process.ts:499`) returns with `process.env = E`, which is
  how the runtime child of the TUI gets its environment. This is the "THEY MUST MOVE TOGETHER" of
  `herdr-agent-state.ts:145` as the running system sees it.

## Harnesses

All run from the tree root (`cd ../tree`). Nothing restates either gate. The TS harnesses import the
real modules from the tree, and the AILANG harnesses import the real package through `ailang.toml`
and `ailang.lock` in this directory. Those two files are a path dependency on
`../tree/packages/motoko-ext-herdr` and `../tree/packages/motoko-ext-abi`, created with `ailang lock`.
A stale content hash in the lock does not stop a run on edited code: `mutants.sh` runs this same
lock against edited copies.

| File | What it is |
|---|---|
| `gate_diff.ts` | P1.1 driver. Generates cases, calls the real `readHerdrEnvironment`, runs `gate_ail.ail` on the same cases, and compares. `--case JSON` checks one triple. Exit 1 on any mismatch, 2 if it could not run |
| `gate_ail.ail` | AILANG half of P1.1. Reads JSON lines, maps unset (`null`) to `""`, calls the real `herdr_env_ready`, and prints the verdict together with the three strings it actually passed |
| `register_ail.ail` | Calls the real `register_with_config(())` and prints the tools its `ToolProvider` advertises |
| `register_diff.ts` | X-1 and X-2 driver. Real `readHerdrEnvironment`, real `buildChildEnv` (X-2), and one `register_ail.ail` process per environment |
| `mutants.sh` | Controls. Copies the code under test, makes one edit at a time, and runs every repro plus two sweeps against the copy |
| `run_all.sh` | Every check below, in order, with output in `runs/` |
| `runs/` | The outputs these numbers come from: `*.out` summaries, `*/cases.jsonl`, `*/mismatches.tsv`, `register/x{1,2}.disagree.txt`, `mutants.out`, and the repo's own test runs |

**Transport check.** `gate_ail.ail` echoes the strings it passed to `herdr_env_ready` as JSON.
`gate_diff.ts` checks that every echo equals what it sent (unset as `""`) and that every case got a
verdict, and exits 2 rather than 1 when either fails. Every run reported here passed both checks.

## What was checked, with which generators, up to what size

### P1.1: 442,524 cases on the two real functions

| Generator | Cases | What it covers | Mismatches | Classes |
|---|---|---|---|---|
| `exhaustive` | 21,952 | Every triple over 28 values: unset, `""`, `"1"`, `"0"`, `"2"`, `"9"`, `"10"`, `"01"`, `"1 "`, `" 1"`, `"1\n"`, `"true"`, `"yes"`, `"on"`, `"a"`, `"A"`, `":"`, `"/"`, `"!"`, `" "`, `"\t"`, `"\n"`, `"\u0000"`, `"１"` (U+FF11), `"é"`, `"/usr/local/bin/herdr"`, `"herdr"`, `"w1:p7"` | (in `all`) | |
| `env-order` | 344 | HERDR_ENV alone: unset plus every string of length 0 to 2 over 18 characters around `"1"` (`\0 \t ␠ ! / 0 1 2 9 : A a ~ DEL é € １ 𝟙`). Bin and pane fixed and realistic | 227 | all A1-T1-1 |
| `bin` | 114 | HERDR_BIN_PATH alone: unset plus every string of length 0 to 2 over 10 characters (`\0 \t \n ␠ / 0 1 a é 𝟙`), and two real paths | 1 | A1-T1-2 (`""`) |
| `pane` | 114 | HERDR_PANE_ID alone, same construction | **0** | |
| `random` (seed 43118) | 20,000 | Seeded mulberry32. Each slot is unset 15%, `""` 10%, a bias value 20%, a bias value plus a random suffix 15%, otherwise a random string. Random strings have length 0 to 6, drawn from digits, printable ASCII, controls (`\0 \t \n \r ESC DEL`), BMP without surrogates, and astral as valid pairs | (in `all`) | |
| `all` = the five above | 42,524 | | 14,914 | 14,728 A1-T1-1, 186 A1-T1-2, 0 other |
| `random`, seed 1 | 200,000 | as above | 44,158 | 42,474 A1-T1-1, 1,684 A1-T1-2, 0 other |
| `random`, seed 2 | 200,000 | as above | 44,454 | 42,757 A1-T1-1, 1,697 A1-T1-2, 0 other |

In the HERDR_ENV slice, AILANG accepts 228 of the 343 set values and rejects 115. The accepted
values are exactly those at or after `"1"` in byte order: the smallest is `"1"`, then `"1\u0000"`,
`"1\t"`, `"1 "`. The largest rejected is `"0𝟙"`. So `"10"`, `"1 "`, `"1\n"`, `"2"`, `":"`, `"true"`,
`"yes"`, and every value that starts with a non-ASCII character, open the AILANG gate. `""`, `"0"`,
`" 1"` and `"/"` do not. The five inline tests try HERDR_ENV only as `"1"`, `""` and `"0"`, so none
of them can tell `>=` from `==`.

Lone surrogates are left out of the random generator on purpose. An environment read from the OS
cannot carry one, and they do not survive JSON into Go, so they would test the transport rather
than the gate.

### X-1 and X-2: 512 environments each, on the real `register_with_config`

Every triple over 8 values: unset, `""`, `" "`, `"1"`, `"2"`, `"true"`, `"/usr/local/bin/herdr"`,
`"w1:p7"`. That is 1,024 `ailang` processes. The set is small because each case is a process.
`\0` is not in it because a real environment cannot carry one.
`HERDR_ORCHESTRATOR=off` and a scratch `MOTOKO_WORKDIR` are set so registration reads no files.
Neither enters the gate.

| Property | Disagreements | Split into disjoint classes |
|---|---|---|
| X-1 | 138 of 512 | 126 HERDR_ENV in {`"2"`, `"true"`, `"w1:p7"`} (A1-T1-1); 6 HERDR_ENV=1 with HERDR_BIN_PATH unset (A1-T1-3); 6 HERDR_ENV=1 with HERDR_BIN_PATH=`""` (A1-T1-2) |
| X-2 | 132 of 512 | 120 HERDR_ENV in {`"2"`, `"true"`, `"w1:p7"`} (A1-T1-1, through the pipeline); 7 HERDR_ENV=1 with HERDR_PANE_ID=`" "` and HERDR_BIN_PATH set (A1-T1-4); 5 HERDR_ENV=1 with HERDR_BIN_PATH unset and a non-blank pane id (A1-T1-3) |

Through the pipeline, A1-T1-2 disappears: `buildChildEnv` drops `HERDR_BIN_PATH=""`, and
`register.ail` then substitutes `"herdr"`, so both sides say "in herdr". They agree by accident,
through A1-T1-3. The same sweep run twice gave identical counts (`runs/register.out`).

### Controls (`mutants.sh`, `runs/mutants.out`)

Each row is one edit to a copy of the code under test. The columns are the exit codes of the four
repros against that copy, then the full P1.1 sweep (`all`) and the HERDR_PANE_ID slice (`pane`).
Every row matched its expectation.

| Mutant | Edit | A1-T1-1 | A1-T1-2 | A1-T1-3 | A1-T1-4 | all | pane |
|---|---|---|---|---|---|---|---|
| unmutated | | 1 | 1 | 1 | 1 | 1 | 0 |
| fix-ail-env | `herdr_env >= "1"` → `herdr_env == "1"` | **0** | 1 | 1 | 1 | 1 | 0 |
| fix-ts-bin | `bin === undefined` → `!bin` | 1 | **0** | 1 | 1 | 1 | 0 |
| fix-ail-env+ts-bin | both | 0 | 0 | 1 | 1 | **0** | 0 |
| fix-register-bin | `getEnvOr("HERDR_BIN_PATH", "herdr")` → `…, "")` | 1 | 1 | **0** | 1 | 1 | 0 |
| fix-ts-pane-blank | TS also rejects a blank pane id | 1 | 1 | 1 | **0** | 1 | **1** |
| fix-forward-verbatim | `buildChildEnv` forwards any set HERDR_* value | 1 | 1 | 1 | **0** | 1 | 0 |
| break-ts-pane | `!paneId` → `paneId === undefined` | 1 | 1 | 1 | 1 | 1 | **1** |
| break-ail-pane | `pane_id != ""` → `true` | 1 | 1 | 1 | 0 | 1 | **1** |

How to read it: each repro detects its own defect and nothing else. The pane slice, which is clean
on the real code, catches a broken pane check on either side. And the two P1.1 fixes together leave
the full sweep clean. `fix-ts-pane-blank` is there to show that a fix for A1-T1-4 in one twin
alone breaks P1.1. Under `break-ail-pane`, A1-T1-4's witness agrees, because an AILANG gate that
accepts an empty pane id also accepts the blank one that `buildChildEnv` dropped.

### The repository's own tests, on the unchanged tree

- `ailang test packages/motoko-ext-herdr/types.ail`: 327 of 327 pass, including the five
  `herdr_env_ready` tests (`runs/ailang-test-types.json`).
- `bun test src/tui/src/herdr-agent-state.test.ts`: 16 of 16 pass
  (`runs/bun-test-herdr-agent-state.out`).
- `verify_herdr_gate` (Makefile:2744) tries only all-unset and, inside a pane, all-set. Neither
  shape reaches any of the four reports.

## A bug in my own harness, found and fixed

The first 200,000-case random runs printed 4 and 9 "unclassified" mismatches. Each had
`ail=undefined`: the case had no AILANG verdict at all. Two harness bugs caused this:

- AILANG's JSON encoder writes U+2028 and U+2029 raw, and the JS regex that parsed its output used
  `.`, which does not match them.
- The guard meant to catch a missing verdict used `Array.reduce`, which skips the holes it was
  meant to count.

Both are fixed in `gate_diff.ts` (a `dotAll` regex, and a counted loop). The runs above are the
re-runs, with 0 unclassified cases and 0 missing verdicts. AILANG's verdicts were correct throughout.

## Not covered

- Reachability in a real herdr pane. No herdr was run. herdr injects `HERDR_ENV=1`, so A1-T1-1
  needs another value set by an operator or wrapper. A1-T1-2 needs a set-but-empty
  HERDR_BIN_PATH. A1-T1-3 needs a pane environment without HERDR_BIN_PATH, for example a herdr
  build that does not inject it, or a wrapper that strips it. A1-T1-4 needs a blank pane id.
- What happens downstream of the gate (reports actually sent, tools actually run), beyond what is
  noted in `reports.tsv`.
- X-1 and X-2 were checked over 8 values per variable only, against 28 values per variable plus
  400,000 random cases for P1.1.
- `buildChildEnv` was called with a scratch workdir, profile `default`, and empty base URL and
  options. It writes only an exit-manifest directory under that workdir.
