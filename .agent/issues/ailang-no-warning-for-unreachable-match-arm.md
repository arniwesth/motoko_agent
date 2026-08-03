# AILANG: an out-of-scope constructor name binds as a fresh variable, silently, with no unreachable-arm warning

## Status

Filed upstream 2026-08-03 — public feedback ticket **`fb_b39697480a4e8bbc`**, category `limitation`.
Open. No Motoko-side fix is needed or possible; this is a missing diagnostic in the toolchain.

Related upstream tickets from this project: `fb_74f53de3ae65854c` (effect propagation through
function-valued record fields), `fb_d230853828108783` and `fb_6c81854baf59b316` (`ailang iface`).

## Branch

`arniwesth/mot-51-execute-wi-a13` — surfaced while executing WI-A13 stage 3 (cluster 9), in the
recorded-outcome codecs.

## Description

In pattern position a name is either a **constructor pattern** or a **variable binding**, and the
disambiguation is whether that name resolves to a constructor in scope. If it does not, it is a
binder — and a binder is **irrefutable**, matching every value.

So in a module that has not imported `std/option`:

```ailang
match get(obj, key) {
  None    => fallback,
  Some(j) => decode(j)
}
```

does not mean what it appears to. `None` is not a constructor here, so it binds the scrutinee to a
fresh variable named `None` and returns `fallback` **unconditionally**. The `Some(j)` arm is
unreachable dead code. The module type-checks clean, because binding a variable to a value of any
type is legal.

## Reproduction

Minimal probe, run from the repository root (not a temp directory — `MOD010` auto-relaxes there):

```ailang
module probe_tmp/none_binding

import std/io (println)

export type Box = Empty | Full(int)

func good(b: Box) -> int { match b { Empty   => -1, Full(n) => n } }  -- constructors in scope
func trap(b: Box) -> int { match b { Nothing => -1, Full(n) => n } }  -- `Nothing` binds as a variable

export func main() -> () ! {IO} {
  let _ = println("good(Full(42)) = ${show(good(Full(42)))}");
  println("trap(Full(42)) = ${show(trap(Full(42)))}")
}
```

```text
$ ailang check probe_tmp/none_binding.ail
✓ No errors found!

$ ailang run --caps IO --entry main probe_tmp/none_binding.ail
good(Full(42)) = 42
trap(Full(42)) = -1        <- the irrefutable first arm swallowed a Full(42)
```

The two functions differ only in whether the first pattern head is an in-scope constructor.

## How it bit Motoko

WI-A13 stage 3's recorded-outcome codecs in `src/core/ports.ail` decode with `std/json` accessors,
which return `Option`. The module did not import `std/option`. Every
`match get(obj, key) { None => …, Some(j) => … }` therefore took the fallback branch every time, and
**every field of the decoder read back as its fallback**. The encoder was correct throughout.

## Why nothing caught it except one specific shape of test

This is the operationally important part, and it is why the issue is worth recording locally rather
than only upstream:

| Check | Verdict against the defect |
|---|---|
| `ailang check` | clean, no warning |
| the type system | content — a variable binding of any type is legal |
| **determinism / reproducibility** | **green — a decoder returning fallbacks is perfectly reproducible** |
| count-based and two-sided balance checks | green — the right *number* of entries, wrong contents |
| the codec round-trip tests | **red, 3 of 4 rows, on first run** |

The round trip caught it because it asserts **field by field with a distinct value in every field**.
That is now standing rule **S7**'s record-level form in
`PLAN-implementation-deterministic-test-world.md`: *a codec's guard is a round trip asserted field by
field, with every field holding a distinct value.* A codec's failure mode is a field the encoder
writes and the decoder ignores; both halves type-check and the loss is silent until something serves
a different response while every count still balances.

## What was asked for upstream, and why it is a limitation rather than a bug

The semantics are standard and defensible — Haskell, OCaml and Rust all treat an unbound identifier
in pattern position as a binder. The difference is that all three **warn**: Rust's
`unreachable_pattern`, OCaml's *"this match case is unused"*, Haskell's `-Woverlapping-patterns`.
The defect is the silence, not the rule.

The filing asks for a diagnostic on either:

1. an **irrefutable pattern followed by further arms**, or
2. an **unreachable match arm**.

Either catches the whole class. It also proposes a third, more precise and AILANG-specific option:
warn when a **capitalised** pattern head resolves to no in-scope constructor. AILANG's naming
convention already distinguishes `Some` from `x` visually, so a capitalised binder is essentially
never intentional — that catches this exactly, with no false positives on genuine lowercase binders.

## Why it is worth a local note as well

Nineteen-odd sites in project 009 have now admitted two type-checking readings where the wrong one is
silent. **Almost every other one came from a *specification* admitting two readings. This one comes
from the *language* admitting two readings of the same token**, which means it can recur in any
module, for any author, with no specification to blame — and it is worst precisely where this project
spends its time: codecs, decoders and validators, where a fallback that looks like data is far more
dangerous than one that crashes.

## Guidance for future sessions, until a diagnostic exists

- **Check the import before writing the match.** If a module pattern-matches `Option`, `Result` or
  any ADT it did not define, confirm the constructors are imported.
- **Round-trip every codec field by field, with distinct values per field** (S7).
- Treat a capitalised pattern head as suspicious in review: if it is not obviously an imported or
  locally-declared constructor, it is a binder.
- It is noted in-source at the import in `src/core/ports.ail`, because the next reader of that file
  will hit it first.
