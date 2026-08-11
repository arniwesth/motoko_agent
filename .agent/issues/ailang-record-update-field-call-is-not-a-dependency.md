# AILANG: a call in the field-value position of a record update is not a dependency, so type-checking depends on invisible declaration order

## Status

Found 2026-08-03 during WI-A13 stage 6 (`.agent/projects/009_motoko_dst_execution`). **Filed upstream
2026-08-03 — public feedback ticket `fb_e44ba922db1c42be`, category `bug`.** Reproduced minimally
against the pin, **AILANG v0.26.0** (commit `3b52a24`).

**Re-reduced to a self-contained repro before filing**, since this note's version imports project
modules. Three files differing by one line, over a two-field `Box` record and a `doubled` helper —
no project imports:

| Form | Result |
|---|---|
| `{ b \| items: doubled(b.items) }` — record **update** | **fails**, `undefined variable: doubled` |
| `let ys = doubled(b.items); { b \| items: ys }` | passes |
| `{ items: doubled(b.items), tag: b.tag }` — record **literal** | passes |

`doubled` is a top-level `pure func` in all three, defined immediately below its caller. That
isolates the trigger to the **update** form specifically — not to ordering, not to the types, not to
the call.

Filed via the `ailang-feedback` skill's Channel 3 (public MCP `submit_feedback`), the same channel
and with the same trackability caveat as the other five tickets — see
`ailang-no-warning-for-unreachable-match-arm.md`'s *How it was filed* section, which applies verbatim.

A Motoko-side workaround is in the tree and is one line per site — see *Workaround* below — so this
is not blocking. It is worth filing because the failure mode is a **bogus error message on correct
code**, and the thing a reader will try first (reordering declarations) sometimes works and
sometimes does not, which costs more than the fix.

## Symptom

```
Error: type error in <module> (decl N): undefined variable: <callee> at <file>:<line>:<col>
```

...pointing at a `pure func` that **is** defined in the same module, at top level, with no typo.

## The rule, measured

`{ record | field: f(args) }` — a call in the **field-value position of a record-update
expression** — is not registered as a dependency of the enclosing declaration. Whether the module
type-checks then depends on where the declaration sorter happens to place it, which the author
cannot see and which any unrelated forward reference elsewhere in the module perturbs.

Five variants, one differing line each, all against v0.26.0:

| Variant | Callee defined | Caller reached by | Result |
|---|---|---|---|
| A | before the caller | a forward reference from an earlier decl | **fails** |
| D | after the caller | strict definition-before-use elsewhere | **fails** |
| E | before the caller | strict definition-before-use throughout | passes |
| B | after the caller | forward reference | passes — the call is `let`-bound |
| C | after the caller | forward reference | passes — no record update |

A and D together are the useful pair: **moving the callee earlier does not reliably fix it**, which
is why this cost more than it should. B and C isolate the trigger to the record update, not to
ordering and not to the types.

## Minimal reproduction

```ailang
module fwd

import std/io (println)
import std/list as List (length)
import src/core/dst_interaction (Interaction)
import src/core/dst_program (ExecutionProgram)

export func main() -> () ! {IO} {
  let p = with_payload_at(base(), 0, "v");
  println("n=${show(List.length(p.interactions))}")
}

pure func base() -> ExecutionProgram { ... }

-- FAILS: `payload_at_ordinal` reported undefined, though it is right below.
pure func with_payload_at(p: ExecutionProgram, ord: int, v: string) -> ExecutionProgram {
  { p | interactions: payload_at_ordinal(p.interactions, ord, v) }
}

pure func payload_at_ordinal(xs: [Interaction], ord: int, v: string) -> [Interaction] {
  match xs {
    [] => [],
    i :: rest =>
      (if i.identity.ordinal == ord then [{ i | outcome: { i.outcome | payload: v } }] else [i])
        ++ payload_at_ordinal(rest, ord, v)
  }
}
```

The nested update in `payload_at_ordinal` is incidental; the trigger is the outer
`{ p | interactions: <call> }`.

## Workaround

Bind the call before the update. One line, and it holds regardless of declaration order:

```ailang
pure func with_payload_at(p: ExecutionProgram, ord: int, v: string) -> ExecutionProgram {
  let xs = payload_at_ordinal(p.interactions, ord, v);
  { p | interactions: xs }
}
```

A `let` body **is** scanned for dependencies, which is what variant B shows.

Applied at `scripts/dst/program_persistence_dst.ail`'s `with_payload_at` and `with_env_value`, with
a comment at the first pointing here. Anyone writing `{ r | f: g(...) }` in this repo should do the
same rather than discovering it.

## Why it cost what it did

The message names a variable that is visibly present, so the first three hypotheses are all wrong
ones: a typo, a missing import, and a stale `.ailang/cache` (cleared; no change). The fourth —
declaration order — is right in outline and wrong in detail, because moving the callee earlier
fixes it in some arrangements and not in others (A versus E). Roughly fifteen minutes, all of it
loud, none of it silent: the compiler was refusing correct code rather than accepting wrong code,
which is the good direction for a defect to fail in.

## Related

- `ailang-no-warning-for-unreachable-match-arm.md` — the other v0.26.0 diagnostic gap this project
  has hit, and the opposite direction: that one **accepts** wrong code silently.
