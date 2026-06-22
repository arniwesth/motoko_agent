# AILANG Syntax Gotchas (2026-05-30)

Collected while editing `packages/motoko-ext-autoresearch/*.ail` (the `cwd`
support fix, a `derive_state` optimization, and a JSON arg-parser fix) and
authoring a standalone benchmark harness. Each of these produced a `ailang
check` parse/type error that cost an edit→check round-trip.

## 1. Comments are `--`, not `#`

`#` is not a comment marker. A `#`-prefixed line fails with:

```
PAR_UNEXPECTED_TOKEN at <file>:<line>: expected next token to be ..., got IDENT instead
```

Use `--` for line comments (matches the rest of the codebase).

## 2. `++` is list-only — strings use interpolation

`++` concatenates lists. On strings it is a type error:

```
`++` operator at <file>:<line>: `++` is for lists only. For strings use
"${expr}" interpolation, concat([parts]), or join(sep, parts).
```

```ailang
-- wrong
acc ++ c
-- right
"${acc}${c}"          -- or concat([acc, c]) / join("", [acc, c])
```

Note the asymmetry: list accumulators in the same file legitimately use
`acc ++ [item]`, so it's easy to reach for `++` on a string by habit.

## 3. No tuple destructuring in `let`

```ailang
let (a, b) = some_call();   -- PARSE ERROR: expected IDENT, got (
```

Options that work:
- Return a **record** and read fields (used in the fix):
  ```ailang
  let ss = match DB.current_session_fields(sd) { Ok(t) => t, Err(_) => { segment: 0, status: "" } };
  let segment = ss.segment;
  ```
- Or destructure a tuple **inside a `match` arm** (not via `let`).

## 4. `substring` end is exclusive; index chars with `i, i+1`

`substring(s, start, end)` — end exclusive. `substring(s, i, i + 1)` returns the
single char at `i`. Char comparisons against escape literals work:
`c == "\\"`, `c == "\""`. Useful for hand-rolled scanners (e.g. JSON string
parsing that must respect `\"`).

## 5. Module path must match `module` decl — or relax it

A file whose `module X` declaration doesn't match its filesystem path fails:

```
MOD010: module 'X' doesn't match file path '<path>'
```

Use `--relax-modules` (CLI flag) or `AILANG_RELAX_MODULES=1` (env). Required for
standalone/throwaway harnesses placed under a subdir (e.g. a `bench/foo.ail`
whose module name can't match the canonical package path). `ailang check
--package <dir>` already relaxes for the package's own files.

## 6. Running a file that imports a package module

To run a harness that imports sibling package modules:

```bash
cd <package-root>
AILANG_RELAX_MODULES=1 ailang run --caps IO,Process,FS,Clock,Env file.ail
```

From the package root, `import pkg/<pkg-name>/<mod>` resolves to that package's
own modules. Caps must cover everything transitively used (e.g. `insert_session`
pulls in `Clock` via `now()`; reading env needs `Env`). Per-char recursive
scanning of a ~300-char string is fine for one-shot parsing.

## Aside: pre-existing `_smoke.ail` failure

`packages/motoko-ext-autoresearch/_smoke.ail` fails `ailang check` with an
unrelated `No instance for Num[...config record...]` type error. It is the lone
failure in `ailang check --package` and is **not** caused by edits to the other
modules — don't chase it when validating a change.
