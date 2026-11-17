# Operators, fixed before enumeration

Five operators. Each mutant is **one contiguous text edit inside the body of one population
function**. `scripts/mutator.py` is the executable form of this page; where the two disagree, the
script is what ran, and the disagreement is a finding.

**What is never touched.** The source is read through `scripts/ailsrc.py`'s tokenizer. A comment
(`--` to end of line) and a string literal (`"…"`, its `${…}` interpolations included) are each
one opaque token, so no operator can match inside either. A function's signature, effect row,
contract (`ensures`/`requires`) and `tests [...]` block lie outside its body and are never sites.

## 1. SR, statement removal

Three shapes. All three remove something the code does and keep what was there before it.

- **SR.stmt.** A statement of a block is deleted, from its first token through its `;`, when it is
  `let _ = E;`, or a bare expression statement `E;`, or `let x = E;` where `x` is already bound
  earlier in the same function (a parameter or an earlier `let`), so that later uses read the
  earlier binding. A `let` that binds a new name is not a site.
- **SR.record**, a dropped record. An expression that adds to an accumulated channel keeps only the
  accumulator:
  - a call to a function that returns `LedgerTrace` and takes exactly one `LedgerTrace` parameter
    (in this source: `ledger_append`, `c2_journal`, `c2_trace_wire_events`,
    `c2_trace_stage_records`, `c2_append_decision`, `witness_drain`) becomes the argument at that
    parameter's position;
  - `A ++ B` becomes `A`: `++` and its right operand are deleted, the operand ending at the first
    `,` `;` `)` `]` `}` `++` `then` `else` `&&` `||` `==` `!=` or `=>` at its own depth;
  - `H :: T` in an expression becomes `T`. A `::` inside a match pattern is not a site;
  - a list literal of two or more elements loses one element, one mutant per element. A list in a
    match pattern, and a `[T]` in a `let x: [T]` annotation, are not sites.
- **SR.world**, keep the predecessor at a world handoff. The successor at a handoff is replaced by
  the predecessor world.
  - *Handoff positions:* the value of a record field named `world_state`, `world` or `next_state`
    in a record literal or update; and an argument at a `WorldState` parameter position of a call,
    including the first argument of a `Ports` method whose first parameter is a `WorldState`
    (those methods are read from `src/core/ports.ail`).
  - *A callee's signature* is the one the calling file sees: its own definition of the name, else
    the definition in the module it imports the name from, else the definitions under `src/` when
    they all agree. A name none of these resolves is not a site.
  - *The predecessor:* `st.world_state` in a function with a parameter `st: C2LoopState`;
    otherwise the function's first `WorldState` parameter; otherwise `provider.world` for a
    `provider: PortedProvider` parameter. A function with none has no SR.world site.
  - A position whose text already is the predecessor is not a site.

## 2. CF, comparison flip

One comparison operator becomes its negation: `==`↔`!=`, `<`↔`>=`, `>`↔`<=`.

## 3. BF, boolean flip

One of: `&&`↔`||`; a `not` deleted; a `true`↔`false` literal.

## 4. MAS, match-arm swap

In a `match` with two or more arms, the bodies of two adjacent arms are exchanged and the patterns
kept. One mutant per adjacent pair. A pair whose bodies have the same text is not a site.
`if`/`else` is not a match and has no MAS site; its condition is reached by CF and BF.

## 5. OBO, off-by-one on a bound

One of:

- a boundary shift: `<`↔`<=`, `>`↔`>=`;
- an integer literal `k` that is an operand of a comparison, or the right operand of a binary `+`
  or `-`, becomes `k+1`; and, when `k ≥ 1`, a second mutant makes it `k-1`.

A literal anywhere else (an argument, a field value, a constant) is not a bound and not a site.

## Site, and what the draw picks

A **site** is a source line, `(file, line)`, as in the Google study's one mutant per line. A
mutant's line is the line of the first character its edit changes; for MAS it is the first arm's
pattern line. At a site, the **operators** are those with at least one mutant on that line, and
each operator's **candidates** are its mutants on that line. The draw (`draw.md`, fixed after the
enumeration) picks a site order, then one operator per site, then one candidate.

## What the script adds to this page, and was checked on planted cases

`python3 scripts/mutator.py selftest` builds a toy module with a comment, a string with an
interpolation, a shadowing `let`, a bare statement, a list, a cons in a pattern and in an
expression, a trace append, a world field, and a function name defined twice with different world
positions, one of them imported. It checks that each operator produces the expected edit, that
nothing inside the comment or the string and nothing in a pattern is a site, that a first binding is
not offered for removal, and that the import decides the ambiguous name. It passed (22 candidates)
before this page was hashed.

**One thing found while building it, recorded here because it touches step 2.** `ailsrc.imports`,
used by `population.py` for the call graph, matches `import` only at the start of a line, and this
source joins several imports onto one line. The three imports among the four files
(`session.ail` from `step_machine`, `recovery` and `tool_phase`) each start their own line, so the
call graph and the population are unaffected. `mutator.py` reads imports anywhere on a line.
