# T4, the digest chain (`src/core/journal.ail:242-300`), arm A1: summary

**Result.** One defect breaks both registered properties: `chain_digests_over` ignores its
`base` argument. A second, separate defect makes it quadratic in the history length. Every
finding was shown by running the real functions. The reports are in `reports.tsv`:

| Report | Property | What is wrong |
|---|---|---|
| A1-T4-1 | P4.1 | The chain does not split. It fails on every split where both halves are non-empty, even at the production base `chain_empty_base()` |
| A1-T4-2 | P4.2 | The last element is wrong for every base other than `chain_empty_base()`. The length half of P4.2 holds |
| A1-T4-3 | X-5 | `chain_digests_over` is O(n²) because of its `acc.out ++ [d]` accumulator |

**Root cause of A1-T4-1 and A1-T4-2.** Line 293 is
`List.foldl(chain_prefix_step, { last: chain_empty_base(), out: [] }, ms).out`. It should start
from `last: base`. So `chain_digests_over(b, ms) == chain_digests_over(chain_empty_base(), ms)`
for every `b`; diagnostic X-4 found this on every input checked. Changing that one token makes
both repros and both harnesses pass. That is the negative control, described below.

**How each defect was first seen.** I saw all three by reading, and that is what the `route`
column records:

- the base defect on line 293;
- the quadratic accumulator on line 289, against `std/list`'s own documentation.

Execution then confirmed each one and measured how far it reaches.

**Reachability of the base defect (A1-T4-1, A1-T4-2).** It affects nothing at HEAD. All seven
callers in the tree pass `chain_empty_base()` and the whole history:

- `session.ail:3871` and `session.ail:4809`
- `dst_invariants.ail:1186`
- `scripts/dst/invariants_dst.ail:1063`
- `journal.ail:2734`, `journal.ail:3408` and `journal.ail:3501`

None of them composes a suffix chain. The host's assumption at `session-journal.ts:620` ("`digest`
is `digests`' last element by construction") holds today only because the base is the empty
one. Two things would hit the bug:

- a caller that passes a re-based digest, for example after a checkpoint `history_replaced`
  re-bases the chain to `chain_digest_base(prefix ++ messages)`;
- a caller that emits digests for an appended suffix starting from the running digest.

Either would hand the host `digest_after` values that the fold refuses at the first entry. I
found these call sites by reading (grep over `*.ail` and `*.ts`), not by running anything.

**Reachability of the quadratic cost (A1-T4-3).** It is live at HEAD. Both emit sites run
`chain_digests_over` over the whole history at every run start and every resume. At realistic
history sizes it costs milliseconds; it only becomes significant beyond tens of thousands of
messages.

Nothing in the tree's own checks can catch this:

- The journal's own test (`journal.ail:3192`) exercises `chain_digest_over` with a non-empty
  base, but never `chain_digests_over`.
- The DST invariant at `dst_invariants.ail:1186` compares `chain_digests_over` with itself.

## Method

Everything ran on the real code. There is no model of the functions: each check is the
property's own statement, evaluated on what the real functions return.

- **Toolchain:** ailang v0.54.14 (`e1ef33f`) and bun 1.4.4, on linux. Times were measured on a
  shared machine (load average 13 to 18 on 8 cores, from other jobs), so absolute timings are
  inflated. Ratios taken within one run are what the conclusions rest on.
- **Reaching the real code without touching the tree.** `out/harness/` holds symlinks
  `ailang.toml`, `ailang.lock`, `src` and `packages` pointing into the tree, so it is a package
  root whose `src/core/journal` is the tree's file. The harness programs live beside them and run
  with `ailang run --relax-modules` from that directory. I did not modify the tree.
- **Negative control.** `harness/make_control.sh base|linear` builds `out/control-<variant>/`.
  It is the same kind of shadow root, but `src/core/journal.ail` there is a *patched copy*:
  - `base`: `last: base` on line 293;
  - `linear`: the same fix, plus the prefix list built with `List.mapAccumL`.

  Every harness and repro accepts `T4_ROOT=<root>` to run against a control. I used the controls
  only to show that each check can tell the defect from its absence.

### Properties checked

| Id | Statement (all on the real functions) |
|---|---|
| P4.1 | `chain_digests_over(b, xs ++ ys) == chain_digests_over(b, xs) ++ chain_digests_over(chain_digest_over(b, xs), ys)` |
| P4.2a | `length(chain_digests_over(b, ms)) == length(ms)` |
| P4.2b | `ms != []` ⇒ `last(chain_digests_over(b, ms)) == chain_digest_over(b, ms)` |
| X-1 | "The prefix chain": `chain_digests_over(b, ms)[i] == chain_digest_over(b, take(i+1, ms))` for every `i` |
| X-2 | Twin agreement: `journal.chain_digest_over(b, ms) == eval/journal/digests.eval_chain_digest_over(b, ms)`. The latter is the evaluator's pinned copy (frame, images frame and chain), fixed at commit A |
| X-3 | Injectivity from the empty base. Distinct messages give distinct `chain_digest_after(empty, m)`, and distinct lists give distinct `chain_digest_over(empty, ms)` |
| X-4 | Diagnostic only, never a failure: `chain_digests_over(b, ms) == chain_digests_over(chain_empty_base(), ms)`. A correct function makes this false whenever `b` is not the empty base and `ms` is non-empty |
| X-5 | Cost: `chain_digests_over` against `chain_digest_over` on the same history. Both make exactly `n` calls to `chain_digest_after` |
| X-6 | Exploratory: is `(previous, m) ↦ chain_digest_after(previous, m)` injective when `previous` is an arbitrary string? |
| wire | `decode(encode(chain_digests_json(ds)))` gives back `ds`, which is the form the host reads |

### Generators and sizes

1. **Bounded-exhaustive (`harness/t4_enum.ail`, AILANG).** The alphabet has 7 messages:
   - system;
   - user;
   - an assistant with one tool call;
   - a tool result;
   - two user messages identical except that one has an image;
   - an assistant whose content looks like a frame and contains non-ASCII
     (`m{role:4:user;}é;`).

   There are 5 bases:
   - `chain_empty_base()`;
   - a whole-list seed digest, `chain_digest_base([system, user])`;
   - a mid-chain digest;
   - `""`;
   - `"sha256:base"`.

   The run takes every list of length 0 to 4 (2,801 lists) and, for P4.1, every split
   (13,539 splits per base). It was then run at length ≤ 5: 19,608 lists and 114,381 splits per
base, 17.5 minutes wall on the loaded machine. Commands:
   `T4_MAXLEN=4 ailang run --relax-modules --caps IO,Env --entry main t4_enum.ail`.
   Outputs are in `harness/runs/t4_enum.len*.out`.
2. **Random (`harness/t4_rand.ts` with `harness/t4_rand_eval.ail`).**
   - bun generates the cases with a seeded mulberry32. The AILANG half decodes each case with
     the real `messages_of_json` and prints the real functions' outputs as JSON. bun then
     evaluates the properties.
   - Strings are built from 0 to 6 atoms drawn from:
     - the frame's own delimiters (`:` `;` `{` `}` `m{` `tc{` `im{` `tc-end;` `im-end;` `m-end;`
       `role:4:user;`);
     - digits;
     - `"`, `\` and `${x}`;
     - newline and tab;
     - `é`, `e`+U+0301, `ß`, `中`, `😀`, U+0000 and U+001F;
     - `make[3]` and `make[0]`.
   - Roles are drawn from {system, user, assistant, tool, "", x}. Each message has 0 to 3 tool
     calls and 0 to 2 images.
   - Bases are the empty base, a seed digest, a chain digest, or a literal (`""`, a random
     `sha256:<64 hex>`, or a random string).
   - `|xs|` and `|ys|` are each 0 to 12. In a third of the cases, `ys` is a "near miss" of `xs`:
     characters moved across a field boundary (content→tool_call_id, content→role,
     image source→mime), an image or call dropped or added, one atom appended, or content and
     tool_call_id swapped.
   - Size: seeds 11 to 20 with 1,000 cases each (10,000 cases, 120,143 messages), plus seed 2
     with 300 cases at `|xs|`, `|ys|` ≤ 8 (`runs/t4_rand.s2.out`, the same pattern).
   - Command: `bun t4_rand.ts <seed> <cases> <maxLen>`. Totals are in
     `harness/runs/t4_rand.sweep.totals`.
3. **Timing.**
   - `harness/t4_perf.ail` runs `n` from 1,000 to 64,000.
   - `harness/repro_perf.ail` (the A1-T4-3 repro) runs n = 16,000 and 64,000. An earlier run
     also reached n = 96,000.
   - Each message is short: alternating user and assistant, content `message <i>`.

### Results on the tree

| Check | Bounded-exhaustive, length ≤ 4 (per base) | Random, 10,000 cases |
|---|---|---|
| P4.1 | **7,938 of 13,539 violated at every base**, exactly the splits with both halves non-empty | **8,743 of 10,000 violated** |
| P4.2a | 0 of 2,801 violated | 0 of 10,000 violated |
| P4.2b | 0 of 2,800 at the empty base; **2,800 of 2,800 at each other base** | 0 of 3,207 at the empty base; **6,337 of 6,498 at other bases**. The 161 that pass are a "chain" or "seed" base built from an empty `xs`, which equals the empty base |
| X-1 | Same pattern as P4.2b: 0 at the empty base, all at the others | 0 at the empty base; 6,337 of 6,674 at the others |
| X-2 | 0 violated at every base | 0 violated |
| X-3 | 0 collisions among 2,801 lists | 0 collisions. Within each seed, every distinct message had its own step digest and every distinct list its own chain digest: 112,908 distinct messages and 9,715 distinct lists, summed over the 10 seeds |
| X-4 (diagnostic) | Output equals the empty-base chain on **every** list at **every** base | Same, on all 10,000 |

At length ≤ 5 (`runs/t4_enum.len5.tree.out`) the pattern is the same at every base:

- P4.1: 75,166 of 114,381 splits violated. That is exactly 7,938 + 16,807 × 4, the number of
  splits with both halves non-empty.
- P4.2a: 0 of 19,608 violated.
- P4.2b and X-1: 0 violated at the empty base; at every other base, all 19,607 (P4.2b) and all
  94,773 (X-1) are violated.
- X-2: 0 violated.
- X-3: 0 collisions among 19,608 lists.
- X-4: the output equals the empty-base chain everywhere.
| wire | (not run) | 0 violated |

X-5, measured within one run on the same history. These rows are saved in
`runs/t4_perf.harness.out`, `runs/t4_perf.control-linear.out` and `runs/A1-T4-3.*.out`; the
machine was shared, with load average 5 to 18:

| n | Tree: `chain_digest_over` | Tree: `chain_digests_over` | Tree ratio | `control-linear` ratio |
|---|---|---|---|---|
| 16,000 | 2,128 ms | 3,770 ms | 1.8× | 1.13× |
| 32,000 | 3,733 ms | 8,186 ms | 2.2× | 0.93× |
| 64,000 | 6,966 ms | 26,219 ms | 3.8× | 1.00× |
| 64,000 (A1-T4-3 repro run) | 6,092 ms | 28,235 ms | 4.6× | 1.07× |

A first, unsaved run on a quieter machine gave 1.7×, 1.9× and 3.5× at the same sizes, and a
loaded run at n = 96,000 gave 4.6× (13,584 ms against 62,803 ms). In every run the extra cost
grows faster than n, while the linear control stays at about 1×.

This growth is what `std/list`'s documentation predicts: "a foldl whose step conses onto (or
concatenates to) a list accumulator is O(n) per element, making the fold O(n^2)".

### Negative controls

These all ran on the patched copies, not on the tree.

- **`control-base`:**
  - `t4_enum.ail` at length ≤ 4 gives 0 violations on every property at every base, and X-4
    now differs from the empty base on 2,800 of 2,800 lists at each non-empty base.
    Output: `runs/t4_enum.len4.control-base.out`.
  - `t4_rand.ts` with seed 11 and 1,000 cases gives 0 violations and exits 0.
  - The A1-T4-1 and A1-T4-2 repros exit 0.
- **`control-linear`:** the same results, and the A1-T4-3 repro exits 0 (1.07×).

### A second twin: the evaluator's Python-pinned fixtures

`harness/x2_fixtures.ail` checks the real functions against the evaluator's message fixtures
(`src/eval/journal/testdata/digest_fixtures.ail`). Their `raw` digest is R, which the
independent Python generator `gen_fixtures.py` computes as the chain from the empty base. All
10 fixtures agree on three checks: `chain_digest_over(chain_empty_base(), msgs) == raw`,
`last(chain_digests_over(chain_empty_base(), msgs)) == raw`, and length. The fixtures include
images, an image swap, `make[N]` renumbering, and unicode and escapes. So at the production base
the chain matches an implementation in another language. Output: `runs/x2_fixtures.tree.out`.

## Observations not reported as defects

- **X-6, `chain_digest_after` is not injective in `previous`.** It hashes
  `previous ++ frame(m)` with no separator. `harness/x6_concat.ail` builds and runs a collision:
  - `m1` is a user message with
    `tool_call_id = "m{role:4:user;content:0:;tool_call_id:0:"`, and `m2` is an empty user
    message.
  - `chain_digest_after(b, m1) == chain_digest_after(b ++ "m{role:4:user;content:0:;tool_call_id:40:", m2)`;
    both are `sha256:808aa8b2…`.
  - It is not reachable. Every `previous` the tree produces or folds is a 71-character
    `sha256:<hex>`, and the frame's comment (`phase_vocab.ail:350-356`) relies on exactly that:
    "a frame is concatenated onto a previous digest". It matters only if a caller ever passes a
    variable-length base, which `chain_digest_over`'s `base: string` signature permits.
- **`chain_step` (journal.ail:260) is dead code.** `chain_digest_over` now folds
  `chain_digest_after` directly. The evaluator's pin (`digests.ail:183`) records
  `List.foldl(chain_step, …)` at commit A. The two are equivalent, and X-2 agrees on every input.
- **`chain_digest_base` is blind to images and to `make[N]` renumbering.** It is
  `digest_messages`, which normalises them. This is documented (`eval/journal/digests.ail`
  header, "D's blind spots"), it is outside P4.1 and P4.2, and I did not count it.

## Not done

- No end-to-end run of the host (`SessionJournal.recordSeed`) and the fold on child output. The
  reachability statements come from reading the call sites, as listed above.
- The exhaustive alphabet is small (7 messages). The random generator covers field contents;
  the exhaustive one covers list structure and splits.

## Files

| File | What it is |
|---|---|
| `reports.tsv` | The three reports |
| `repro/A1-T4-{1,2,3}.sh` | The repros. Each exits 1 when the defect is present, 0 when absent, 2 on a harness failure. `T4_ROOT=<root>` points one at a control |
| `harness/repro_p41.ail`, `repro_p42.ail`, `repro_perf.ail` | The witness programs the repros run |
| `harness/t4_enum.ail` | The bounded-exhaustive checker: P4.1, P4.2a, P4.2b, X-1, X-2, X-3 and the X-4 diagnostic |
| `harness/t4_rand.ts` and `harness/t4_rand_eval.ail` | The random checker: the TS generator and property statements, and the AILANG half that evaluates the real functions |
| `harness/t4_perf.ail` | The timing series |
| `harness/x6_concat.ail` | The X-6 collision |
| `harness/x2_fixtures.ail` | The real chain against the Python-pinned R fixtures |
| `harness/make_control.sh` | Builds the patched-copy negative controls |
| `harness/runs/` | Outputs of the runs cited above |
