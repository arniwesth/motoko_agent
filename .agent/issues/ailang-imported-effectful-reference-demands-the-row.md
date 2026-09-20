# An imported effectful function's row is demanded at the reference site

## Status

**Filed upstream 2026-09-08 — ticket `fb_0a8ab94817a74c3e`**, category `bug`, via the
`ailang-feedback` skill's MCP channel. Worked around in this tree by NOT sharing three helpers.

## Description

Storing an effectful function as a VALUE — never calling it — requires the enclosing function to
declare that effect, but only when the function is IMPORTED. The identical body with a local
definition type-checks with no row.

Three-file repro is in the ticket. `build`'s body is byte-identical in both cases:

```ail
export func build() -> { f: (int) -> int ! {Clock} } { { f: tick } }
```

local `tick` → `✓ No errors found!`; imported `tick` → `Missing effects: Clock`.

## What it cost here

`src/core/test/herdr_fixture.ail` was extracted from five gates that each hand-rolled the same
fixture. Ten pure helpers moved. Three did not — `fixed_clock` (`! {Clock}`), `ok_write` and
`ok_dir` (`! {FS}`) — because sharing them would have meant adding `! {Clock}` to five `ports*`
builders and then to whatever calls them, a row propagating outward through code that performs
nothing.

Those three remain duplicated across five files. That is the wrong outcome for a de-duplication
change and the only reason the duplication survives; the module header records it so the next reader
does not retry it.

## The ask, as filed

Make the two agree — preferably the LOCAL behaviour, since a reference that is not an application
performs nothing and the value's own type already carries the row. If the imported behaviour is
deliberate, document it and have the error name the reference site: it currently points at the
enclosing function and says "uses effects", which sends a reader looking for a call that is not
there.

## Not investigated

Whether passing such a function as an ARGUMENT, or re-exporting it, behaves the same.
