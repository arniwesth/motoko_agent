# ADR-001 review verdicts + independent re-measurement

Date: 2026-08-29. Status: **review complete, ADR-001 rewritten as v2.**
Reviewers: two independent adversarial delegates (claude, codex), neither given the other's
output. Every load-bearing claim below was then re-measured locally by Motoko on HEAD
76178f86, ailang v0.33.0 (ae36986), Z3 4.8.12. **No source outside this directory was
modified** during review; probes live in `tmp/probe027/`.

## 1. Where the two reviewers agree (both high confidence)

| Claim | Verdict |
|---|---|
| False-green diagnosis of `verify_core` (rc==0 ⇒ ✓, `Makefile:2342-2361`) | confirmed by both |
| `isSome`, `is_native_backend` are tautologies | confirmed by both, by mutation probe |
| `is_absolute_path` restates its body | confirmed by both |
| `normalize_range` is the one real contract | confirmed by both |
| `compress.ail` `requires`-only, ticked with 0 proven | confirmed by both |
| `agents_md.ail:192,198` `@verify` predicates are never read | confirmed by both |
| **The ADR's Option 4 ("not an option today") is false** | **both, independently** |
| A hand-maintained register cannot validate its own labels | both, citing `dst_invariants.ail:72-84` |
| §5's DP7 rationale is inverted — DP7's rejection says *"does not type-check"* | both, independently |

The last three are fatal to ADR-001 as written. All three were re-measured below and all
three hold.

## 2. Independent re-measurement (Motoko, post-review)

### 2.1 Solver-computed classification works today — 0.25s for all four contracts

Probe: `tmp/probe027/probes_all.ail`. For contract `E` over `f(args) -> T` with body `B`:

- **TAUT**: `f_taut(args, r: T) -> T ensures { E } { r }` — VERIFIED ⇒ E holds for every
  result ⇒ tautology.
- **DETERMINE**: `f_det(args, r: T) -> T requires { E[result := r] } ensures { result == B(args) } { r }`
  — VERIFIED ⇒ E pins the body's answer ⇒ spec-equals-body.
- **substantive** ⇔ both VIOLATION.

Measured output (`ailang verify tmp/probe027/probes_all.ail`, real 0m0.251s):

```
✗ VIOLATION nr_taut      ✗ VIOLATION nr_det       → normalize_range: SUBSTANTIVE
✓ VERIFIED  isSome_taut  ✗ VIOLATION isSome_det   → isSome: TAUTOLOGY
✓ VERIFIED  inb_taut                              → is_native_backend: TAUTOLOGY
✗ VIOLATION iap_taut     ✓ VERIFIED  iap_det      → is_absolute_path: SPEC-EQUALS-BODY
```

7 functions: 3 verified, 4 violations. **The classification the ADR proposed to hand-maintain
is one mechanical probe pair and a quarter of a second.** ADR-001 §"Option 4 is not available
today" is retracted. P3's mechanism changes from a hand register to a generated, solver-pinned
one.

### 2.2 E4 is dead: string-producing functions are NOT out of fragment

This is my own error and it is worse than either reviewer found. Measured
(`tmp/probe027/e4d.ail`):

```
✓ VERIFIED suffix_len     ensures { length(result) == length(s) + 1 }  { concat_String(s, "!") }
✓ VERIFIED suffix_prefix  ensures { startsWith(result, s) }            { concat_String(s, "!") }
```

`concat_String` is surface-callable (used at `ailang/std/sem.ail:63`) and maps to `str.++`
(`ailang/internal/smt/types.go:303`). `std/string.length` → `_str_len` → `str.len` and
`std/string.startsWith` → `_str_startsWith` → `str.prefixof` are both mapped
(`types.go:386-391`).

**Root cause of the E4 error:** RESEARCH E2/E4 used a bare `str_length`, which does not exist
as surface syntax — `compilation failed: undefined variable: str_length`. The "unencodable"
verdicts were an artifact of a typo, not of the SMT fragment. RESEARCH §3 E4's conclusion
("no string-producing function can carry a contract") is **retracted in full**, and with it:

- **P2 (the upstream feedback item) is cancelled.** There is nothing to ask upstream for. The
  one map entry I proposed would also have been type-wrong: `std/string.concat` takes one
  `[string]` (`ailang/std/string.ail:74`) while `concat_String` takes two strings, so
  `"concat": "concat_String"` could not have worked as described.
- The string tier of P3 is **ungated**.

What *is* still true, narrowly: `std/string.concat` and `std/string.join` are unmapped
(`concat` → `⚠ SKIPPED: unencodable builtin: std/string.concat`), and string interpolation
lowers through `show`, also unmapped. So list-driven string building needs a rewrite to
`concat_String` to be provable — a mechanical source change, not an upstream one.

### 2.3 `compress.ail`'s `requires` clauses are not checked at call sites

`verify.go:290-304` short-circuits any function with no `ensures` clause to `skipped` before
the encodability gate, so `compress.ail:57`'s `requires { max_chars >= 0 }` is never asserted
against a caller. Amber must say "unchecked", not merely "unproven" — the ADR's framing
understates it.

### 2.4 `verify_core` costs 15.3s, not "seconds"

Measured `time make verify_core`: **real 0m15.313s**, against ~20s for `check_core`. RESEARCH
§4.5's "verify_core is seconds" is retracted. Folding it into DP7 today costs ≈ +75% per
finalize *before a single new contract exists*, and that ratio worsens as contracts land.
P4's precondition is a wall-clock budget, not register non-triviality.

### 2.5 Amber cannot print rejection codes

`verify.go:340-349` joins `r.Message` only; `Rejections[].Code` is never printed on the text
path. P0 must promise *reasons* (which do exist, e.g. `no ensures clause (nothing to verify)`,
`uses an unencodable builtin: std/string.concat`), not codes, unless we add JSON plumbing.

### 2.6 `is_absolute_path`'s "pins the body against silent edits" is wrong

The contract and body sit in the same declaration and are edited together; it pins nothing.
The concession is dropped in v2. Codex's counter-argument that a body-only edit *is* caught is
true only if someone edits the body without the contract — which is the case worth catching,
but it is a regression test, not a proof, and it should be counted as such.

## 3. Reviewer disagreements (resolved)

- **`spec-equals-body` value.** Claude: drop the concession, it pins nothing. Codex: it is a
  complete functional regression spec and catches body-only edits. **Resolution:** it is a
  regression *test*, not evidence; both are right about different things. v2 keeps the class,
  counts it as zero substantive, and names the one thing it does do.
- **P4 timing.** Claude: gate on wall-clock budget. Codex: roll out in dogfood first because
  of cost, and pin the identities that must stay VERIFIED. **Resolution:** adopt both —
  budget *and* dogfood-first *and* a pinned verified-set, since solver *disappearance*
  (VERIFIED → SKIPPED) is the regression a weak gate would otherwise miss.

## 4. Net effect on the plan

| Phase | v1 | v2 |
|---|---|---|
| P0 honest gate | amber bucket + reason codes | amber bucket + reasons (not codes) + "unchecked" wording |
| P1 dead predicates | land `is_root`, delete `dirname_shrinks` | unchanged; `is_root` reconfirmed VERIFIED 13.7ms |
| P2 upstream concat | file feedback item | **cancelled** — E4 was an artifact |
| P3 register | hand-maintained, 1d | generated + solver-pinned, cheaper, no judgment file |
| P4 DP7 oracle | blocked on register non-triviality | blocked on **wall-clock budget + message fix + pinned verified-set** |

ADR-001 v2 incorporates all of the above and supersedes v1.
