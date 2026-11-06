# T4 — the digest chain (`src/core/journal.ail:242-300`): executed checks

## Findings (`reports.tsv`)

| id | property | what | reachable today? |
|---|---|---|---|
| A2-T4-1 | P4.1 | `chain_digests_over` ignores `base` and folds from `chain_empty_base()` (line 293), so the split law fails for every list of length ≥ 2 at every base, **including `chain_empty_base()`** | no (no caller composes two calls) |
| A2-T4-2 | P4.2 | same root cause: for a base ≠ `chain_empty_base()`, `last(chain_digests_over(b, ms)) ≠ chain_digest_over(b, ms)`. The length half holds | no (every caller passes `chain_empty_base()`) |
| A2-T4-3 | X-1 | `chain_digests_over` is O(n²): `acc.out ++ [d]` copies the accumulator every step; 3.7× `chain_digest_over` at n = 40,000 | yes, but it costs little at realistic sizes |
| A2-T4-4 | X-9 | `chain_digest_after` hashes `previous ++ frame(m)` undelimited, so distinct (previous, m) pairs collide when `previous` isn't a fixed-width digest | no (every base in the tree is 71 chars) |

A2-T4-1 and A2-T4-2 are one defect, a single token (`chain_empty_base()` → `base`, `fix_base.diff`),
seen through the two registered properties. With that token changed, every check below passes at the
same sizes, so at those sizes nothing else in these functions violates P4.1 or P4.2.

All four were first seen by reading. Each one was then shown and characterised by execution on the
real code, and each repro was checked against a control copy of the tree with the defect removed
(exit 0 there, exit 1 on the real tree).

## Exploratory properties

- **X-1**: `chain_digests_over(b, ms)` costs O(length(ms)) chain steps plus O(1) per step, like
  `chain_digest_over`. Measured as their time ratio as n doubles.
- **X-2**: the "prefix chain" of the comment: `chain_digests_over(b, ms)[i] == chain_digest_over(b, take(i+1, ms))`
  for every i (implies P4.2). Fails on exactly the P4.2 cases. Not filed separately.
- **X-3**: twin: `chain_digest_over(b, ms) == eval_chain_digest_over(b, ms)`, the evaluator's pinned
  copy in `src/eval/journal/digests.ail`. 0 failures.
- **X-4**: `chain_digest_over(b, xs ++ ys) == chain_digest_over(chain_digest_over(b, xs), ys)`. 0 failures.
- **X-5**: `encode(chain_digests_json(ds))` parses back (in TypeScript) to exactly `ds`, in order. 0 failures.
- **X-6**: every chain value is `sha256:` + 64 lowercase hex (or the base itself for `[]`). 0 failures.
- **X-7**: harness integrity: the messages AILANG hashed (`messages_json`) are the ones TypeScript
  generated. 0 failures.
- **X-9**: `chain_digest_after` is injective in (previous, m). Fails for non-fixed-width previous (A2-T4-4).
  For each fixed base, distinct lists give distinct `chain_digest_over` / `chain_digests_over` values:
  0 duplicates (X-10, `collide_chain.ail`).
- **X-11**: the evaluator's `SOURCE` pins against the current source (`pin_drift.ts`). See observations.

## What was run, with which generators, up to what size

All harnesses call the real functions: `src/core/journal.ail` is imported, never copied or modelled.
AILANG harnesses run as `ailang run --relax-modules` (AILANG v0.54.14) from a package root under
`out/pkg/` whose `src`, `packages`, `ailang.toml` and `ailang.lock` are symlinks to the tree's.
`ailang` resolves imports only inside a package, and this keeps every file under `out/`. Bun is 1.4.4.

| harness | generator | size | real tree | control (`pkg_fixed`) |
|---|---|---|---|---|
| `pkg/t4/enumerate_chain.ail` (properties stated in AILANG: P4.1 at every split, P4.2, X-2, X-3, X-4) | exhaustive: every list over an 8-message alphabet (empty content, tool call, tool result, system, unicode + image, frame-lookalike content, same content under two roles) × 6 bases (`chain_empty_base()`, `""`, `"x"`, `"sha256:"+0⁶⁴`, a real chain digest, `"ü;m{"`) | lengths 0..4: 4,681 lists × 6 = **28,086 cases**, 136,422 splits | P4.1 28,032 fail; P4.2-last 23,400 fail; X-2 23,400; X-3/X-4 0 (`runs/enumerate.pkg.a8.len4.out`) | all 0 (`runs/enumerate.pkg_fixed.a8.len4.out`) |
| same, `T4_ALPHA=2 T4_MAXLEN=9` | exhaustive, first 2 messages × 6 bases | lengths 0..9: 1,023 lists × 6 = **6,138 cases**, 55,302 splits | P4.1 6,120 fail (every list of length ≥ 2); P4.2-last 5,110 (every non-empty list at the 5 non-empty bases); X-2 5,110; X-3/X-4 0 (`runs/enumerate.pkg.a2.len9.out`) | all 0 (`runs/enumerate.pkg_fixed.a2.len9.out`) |
| `random_chain.ts` → generated `pkg/t4/gen/random_cases_<pkg>.ail` (properties stated in TypeScript over the printed outputs: P4.1 at every split, P4.2, X-2, X-5, X-6, X-7) | seeded mulberry32. Messages: role from {user, assistant, tool, system} or random; content/ids/args/image fields from 0–6 atoms drawn from 26 (unicode, `\n`, `\t`, `"`, `\`, `$`, `${x}`, `m{`, `im-end;`, `role:4:user;`, …); 0–3 tool calls; 0–2 images. Bases: 40% `chain_empty_base()`, else `""`, random `sha256:<hex>`, or a random atom string | seeds 1–4 × 60 cases, lengths ≤ 24; seed 11 × 12 cases, lengths ≤ 64 (longest drawn 49): **252 cases, 2,486 splits** per package | every run exits 1. Failure counts equal the base-ignored prediction printed in each file: P4.1 53/51/50/49/12, P4.2-last and X-2 30/32/32/29/5; X-5/6/7 0 (`runs/random.pkg.*`) | every run exits 0 (`runs/random.pkg_fixed.*`) |
| `pkg/t4/collide_chain.ail` (X-10, X-9 within a base) | the same 8 × 6 enumeration, lengths 0..4 | 56,172 values | 0 duplicates within a base; across bases, all 4,680 non-empty lists share one `chain_digests_over` value at all 6 bases (the A2-T4-2 defect) | — |
| `pkg/t4/perf_chain.ail` (X-1) | n messages `user "message <i>"` | n = 1k … 64k (doubling) | gap 0.47 / 2.1 / 6.3 / 22 s at 8k / 16k / 32k / 64k (`runs/perf_chain.pkg.out`) | `pkg_fixed_perf` (mapAccumL): ratio flat 0.5–1.45×, 1.09× at 64k (`runs/perf_chain.pkg_fixed_perf.out`) |
| `pkg/t4/repro_*.ail` + `repro.sh` | the single witnesses in `reports.tsv` | — | exit 1 (all four) | exit 0 on the matching control |
| `pin_drift.ts` (X-11) | the evaluator's 5 `SOURCE` pins for journal.ail | — | 1 drift, see below | — |

The 8×4 enumeration outputs were produced before `T4_ALPHA`/`T4_MAXLEN` were added to
`enumerate_chain.ail`. The defaults (8 / 4) are that same run. `pkg/t4/smoke.ail` was the first
import check, kept for completeness.

### Control copies

`pkg_fixed`, `pkg_fixed_perf` and `pkg_fixed_x9` are package roots whose `src/` is a symlink tree of
the real `src/`, except `src/core/journal.ail`, which is a copy with one change (`fix_base.diff`,
`fix_base_and_perf.diff`, `fix_x9_control.diff`). They exist only to show that each check is
discriminating: it exits 0 once its defect is removed, and with the base fix the whole suite goes quiet.
They are not models: every line except the patched one is the real code.

### Running things (from the tree root)

```
bash ../out/repro.sh repro_p41             # A2-T4-1   (~5 s)
bash ../out/repro.sh repro_p42             # A2-T4-2   (~5 s)
bash ../out/repro.sh repro_x1 IO,Clock     # A2-T4-3   (~35 s, timing-based)
bash ../out/repro.sh repro_x9              # A2-T4-4   (~5 s)
ailang run --relax-modules --caps IO,Env --chdir ../out/pkg --entry main t4/enumerate_chain.ail   # 2–8 min
T4_ALPHA=2 T4_MAXLEN=9 ailang run --relax-modules --caps IO,Env --chdir ../out/pkg --entry main t4/enumerate_chain.ail
bun ../out/random_chain.ts <seed> <cases> <maxlen>        # T4_PKG=../out/pkg_fixed for the control
bash ../out/run_random.sh                                  # the batch above, both packages
ailang run --relax-modules --caps IO,Clock --chdir ../out/pkg --entry main t4/perf_chain.ail
bun ../out/pin_drift.ts
```

`repro.sh` builds a throwaway package root (`out/.run.XXXXXX`, removed on exit) from the directory it
is run in. So a repro always tests the tree you are standing in, and you can point it at a patched
tree to see the 0 exit. It exits 1 only if the harness prints its defect marker, 0 only on its
absent marker, and 2 otherwise, so a harness that fails to compile never reads as a finding.

## Reachability (read from the tree, not executed end to end)

`chain_digests_over` has three callers: `session.ail:3871` (the traced entry's `HistorySeeded.digests`),
`session.ail:4809` (the resume path's) and `dst_invariants.ail:1186` (the seed.digests invariant). All three
pass `chain_empty_base()`, the one base at which the defective code returns the right list. The host
(`src/tui/src/session-journal.ts:591-617`) copies these digests verbatim into `history_appended` entries,
and they are correct today. A2-T4-1/2 therefore corrupts nothing now. It is a trap for the first caller
that continues a prefix chain from a re-based digest, which is what the function's signature and
comments offer. The DST rule at `dst_invariants.ail:1186` recomputes with the same function, so it
cannot detect the defect.

## Observations not filed as defects

- **Pin drift on `chain_digest_over` (X-11)**. The evaluator's pinned copy hashes the body
  `List.foldl(chain_step, base, ms)`; the current body is `List.foldl(chain_digest_after, base, ms)`
  (`pin_drift.ts` confirms the old body hashes to the pin). Behaviour is identical (X-3 and X-4: 0
  failures over the 28,086 + 6,138 enumerated cases), but `chain_step` (journal.ail:260) is now dead code, and the
  evaluator's P1.4b drift tool will report this function as drifted. The other four pins match byte for
  byte, shifted 2 lines up.
- `chain_digest_base` (whole-list `digest_messages`) and the chain functions are different quantities
  by design (comment at journal.ail:302-321), so no relation between them was tested.

## Limits

- Message alphabet coverage: the enumeration covers every `Message` field the frame reads (role, content,
  tool_call_id, tool_calls with id/name/arguments, images with source/mime), but only through 8 fixed
  messages. The random generator varies every field independently, at much lower density.
- The longest lists P4.1 was checked on: 9 (exhaustive, 2 messages) and 49 (random). X-1 went to 64,000 messages.
- `sha256Hex` was treated as a black box, as instructed. X-9's collision is a collision of the hashed
  preimages, not of SHA-256.
- Timing numbers come from a shared 8-core host with load average 8–16. Ratios between the two
  functions within one process are what the X-1 repro relies on, not absolute times.
