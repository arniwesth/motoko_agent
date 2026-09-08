# AILANG: no tail-call optimization, and the error text advises a feature that does not exist

## Status

Found 2026-08-17 while diagnosing a production runtime abort in Motoko
([`per-step-trace-fold-exceeds-recursion-depth.md`](per-step-trace-fold-exceeds-recursion-depth.md),
[motoko_agent#160](https://github.com/arniwesth/motoko_agent/issues/160)). Measured against the pin,
**AILANG v0.33.0**, commit `ae36986`, built 2026-08-14.

Two claims, one measured and one structural, and they should be read separately because the second
is the cheaper fix:

1. **A tail call consumes a frame.** A textbook accumulator loop in tail position dies at the
   recursion ceiling. Depth over a list is the list's length.
2. **The diagnostic tells the reader to "enable tail recursion", and there is nothing to enable.**
   No flag, no pragma, no annotation, and no implementation anywhere in the tree.

(1) may well be a known and accepted property of a tree-walking evaluator. (2) is a defect
regardless of (1)'s status: a diagnostic that names a nonexistent remedy sends the reader looking
for a switch, and the time is spent before they conclude there isn't one.

## Not yet filed upstream

Not submitted to `sunholo-data/ailang` — filing is an outward-facing action and was not part of the
diagnosis this came out of. Worth routing through the `ailang-feedback` skill. Note the channel
caveat that applies to all six existing tickets, recorded verbatim in
`ailang-no-warning-for-unreachable-match-arm.md`'s *How it was filed* section: Channel 3 is
fire-and-forget with no URL and no status to poll.

## Symptom

```
Error: execution failed: RT_REC_003: max recursion depth 10000 exceeded.
Try smaller input, enable tail recursion, or increase with --max-recursion-depth
```

Three remedies offered. The first and third are real. **The second is not.**

## The rule, measured

Self-contained; no project imports.

```ailang
module tco

func loop(n: int, acc: int) -> int {
  if n == 0 then acc else loop(n - 1, acc + 1)
}

export func main() -> () ! {IO} {
  println(show(loop(N, 0)))
}
```

`loop` is in tail position by any definition — the recursive call is the whole `else` branch, the
result is returned unchanged, and there is no pending work in the frame.

| N | result |
|---|---|
| 9 998 | `9998` |
| 9 999 | `9999` |
| **10 000** | **RT_REC_003** |
| 10 001 | RT_REC_003 |

The boundary sits exactly at the declared ceiling, which is what "each call costs one frame" looks
like. The same shape over a list — `match xs { [] => acc, _ :: rest => f(rest, g(acc)) }`, the
idiom this codebase writes everywhere — fails at 10 000 elements.

Confirmed as a ceiling and not a stack limit: raising it works and the recursion completes.

```
$ ailang run --caps IO --entry main tco.ail                          # N = 50000
Error: execution failed: RT_REC_003: max recursion depth 10000 exceeded ...

$ ailang run --max-recursion-depth 60000 --caps IO --entry main tco.ail
50000
```

## Where it comes from

`internal/eval/eval_operations.go:53-60`, in the `*FunctionValue` arm of function application:

```go
case *FunctionValue:
    // Recursion depth guard
    e.recursionDepth++
    if e.recursionDepth > e.maxRecursionDepth {
        e.recursionDepth--
        return nil, fmt.Errorf("RT_REC_003: max recursion depth %d exceeded. Try smaller input, enable tail recursion, or increase with --max-recursion-depth", e.maxRecursionDepth)
    }
    defer func() { e.recursionDepth-- }()
```

Unconditional increment on every user-level application, decremented by `defer` on return. Tail
position is never consulted, and nothing rewrites a self-call into a loop.

Grepping the tree for `tail.call | tailcall | tail_call | tail position | TCO` across `internal/`
and `cmd/` returns only unrelated matches (regex identifiers, constructor helpers). The counter and
the default are declared at `internal/eval/eval_evaluator.go:122-123`, `:148`, `:160`; the flag is
`cmd/ailang/main_run.go:35`.

The guard itself is well-behaved — one increment site, `defer`ed decrement, and the early-error path
decrements before returning, so there is no leak. The issue is only that tail position gets no
special treatment.

## How it bit Motoko

Not through a runaway recursion — through an ordinary fold. Motoko's driver derives a status
payload by folding its accumulated event ledger once per tool step. The ledger legitimately reached
~9 900 records in a long session; the fold needed one frame per record; the process aborted
mid-session with a message about recursion depth, in code containing no unbounded recursion.

The consequence worth stating for anyone else building on AILANG: **with no TCO, the maximum size
of any list you fold recursively is a global resource shared with your call depth.** That is a
property most authors will assume they do not have to reason about, because in most functional
languages a tail-recursive fold is O(1) in stack. `std/list`'s own recursive helpers inherit the
same ceiling.

Motoko's own defect is real and is being fixed independently — the fold should not be O(|trace|) per
step regardless of the runtime. But on a runtime with TCO it would have been *slow*, not *fatal*,
and it would have shown up as a latency curve rather than as a process abort an hour into a session.

## Suggested upstream fix

In priority order, cheapest first:

1. **Fix the message.** Drop "enable tail recursion" unless and until it names something real. Two
   accurate remedies are better than three when one is a dead end. This is a one-line change and is
   worth doing even if (2) never happens.
2. **Say so in the docs.** A short note that the evaluator does not eliminate tail calls, and that
   recursion depth over a data structure is bounded by `--max-recursion-depth`, would let callers
   size their folds deliberately. Right now the only way to learn it is to hit it in production.
3. **Implement self-tail-call elimination**, if it is wanted. The narrow version — a direct
   self-call in tail position within one function body, rewritten to a loop over the parameter
   bindings — covers the accumulator idiom that this and `std/list` are built from, and does not
   require general TCO across mutual recursion or through closures.

## Workaround in this repo

None applied, and deliberately so. The Motoko-side fault this surfaced is a genuine per-step
O(|trace|) fold that should be removed on its own merits, so raising the ceiling would have hidden a
real defect behind a bigger number.

For the general case the options are: keep recursive folds bounded by construction, pass an explicit
`--max-recursion-depth` sized against the largest structure a run can build, or hand-write the loop
with an explicit worklist. Note that `src/tui/src/runtime-process.ts:474-491` passes no
`--max-recursion-depth`, so every Motoko session today runs at the inherited 10 000.

## Related

- [`per-step-trace-fold-exceeds-recursion-depth.md`](per-step-trace-fold-exceeds-recursion-depth.md)
  — the Motoko fault this enabled; carries the log evidence and the fix plan.
- `ailang-no-warning-for-unreachable-match-arm.md` — the filing-channel caveat, which applies here
  verbatim.
