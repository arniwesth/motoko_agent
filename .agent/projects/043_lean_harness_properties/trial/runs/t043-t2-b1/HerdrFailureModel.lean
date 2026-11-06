/-
HerdrFailureModel.lean — target T2, "the herdr failure vocabulary", a cross-language twin.

A Lean 4.28.0 model (core only: no Mathlib, no Lake) of two implementations of one rule,
in the snapshot at /home/motoko/trial-043/s/t043-t2-b1/tree:

  * `herdrFailureCode`      src/tui/src/wake-waiter.ts:129-140
    `herdrMeansAgentGone`   src/tui/src/wake-waiter.ts:142-144
    (header comment :124-126: "the TS twin of `types.ail`'s `failure_code` / `means_agent_gone`")
  * `failure_shape`         packages/motoko-ext-herdr/types.ail:1127-1143
    `json_error_field`      packages/motoko-ext-herdr/types.ail:1145-1156
    `failure_code`          packages/motoko-ext-herdr/types.ail:1160-1180
    `means_agent_gone`      packages/motoko-ext-herdr/types.ail:1198-1207
    (comment :1182-1197: "narrow on purpose")

What the model keeps and what it abstracts:

  * Strings are `List Char` (code points). Every comparison either function makes is on
    ASCII (`"nested herdr"`, `{"error"`, `_not_found`, `agent_not_found`), so UTF-16 (TS)
    against runes (AILANG) does not change a branch.
  * `JSON.parse` and AILANG's `std/json.decode` are modelled by one RFC 8259 parser,
    `parseJson`, below. Where the two runtimes differ, the difference is a named parameter of
    the model (`ailDecode`, `ailGet` against `jsGet`), so the differential test can correct it.
  * `HerdrResult.spawnError` is a `Bool`: `herdrFailureCode` only tests it for `undefined`.
    `stdout` is not read by either function and is dropped.
  * Literal strings in the model are written `L!"..."`, a macro that expands to a `List Char`
    literal at elaboration time, so no theorem depends on `String.toList` (whose definition
    pulls in `Classical.choice`).

Step (2) changed this model; every change is logged in the section "Model corrections"
below with the case that forced it.
-/

open Lean in
/-- `L!"abc"` is `['a', 'b', 'c']`, built at elaboration time. -/
macro:max "L!" s:str : term => do
  let elems ← s.getString.toList.mapM fun c => `(($(Lean.quote c) : Char))
  `([$(elems.toArray),*])

/-! ## Shared: list-of-char helpers -/

def isPrefixL : List Char → List Char → Bool
  | [], _ => true
  | _ :: _, [] => false
  | p :: ps, c :: cs => if p = c then isPrefixL ps cs else false

/-- AILANG `std/string.contains(s, pat)`: `pat` occurs somewhere in `s`. -/
def containsL (s pat : List Char) : Bool :=
  match s with
  | [] => isPrefixL pat []
  | c :: cs => isPrefixL pat (c :: cs) || containsL cs pat

/-- JS `String.prototype.endsWith`. -/
def endsWithL (s suf : List Char) : Bool := isPrefixL suf.reverse s.reverse

/-! ## JSON: one RFC 8259 parser for both runtimes -/

inductive J where
  | null
  | tru
  | fls
  | num (lexeme : List Char)
  | str (s : List Char)
  | arr (xs : List J)
  | obj (kvs : List (List Char × J))
  deriving Repr, Inhabited

def isJsonWs (c : Char) : Bool := c = ' ' || c = '\t' || c = '\n' || c = '\r'

def skipWs : List Char → List Char
  | [] => []
  | c :: cs => if isJsonWs c then skipWs cs else c :: cs

def hexVal (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

def hex4 (a b c d : Char) : Option Char := do
  let a ← hexVal a; let b ← hexVal b; let c ← hexVal c; let d ← hexVal d
  some (Char.ofNat (((a * 16 + b) * 16 + c) * 16 + d))

/-- The body of a string after its opening quote; returns the decoded string and the rest. -/
def pStr : List Char → List Char → Option (List Char × List Char)
  | [], _ => none
  | '"' :: rest, acc => some (acc.reverse, rest)
  | '\\' :: '"' :: rest, acc => pStr rest ('"' :: acc)
  | '\\' :: '\\' :: rest, acc => pStr rest ('\\' :: acc)
  | '\\' :: '/' :: rest, acc => pStr rest ('/' :: acc)
  | '\\' :: 'b' :: rest, acc => pStr rest (Char.ofNat 8 :: acc)
  | '\\' :: 'f' :: rest, acc => pStr rest (Char.ofNat 12 :: acc)
  | '\\' :: 'n' :: rest, acc => pStr rest ('\n' :: acc)
  | '\\' :: 'r' :: rest, acc => pStr rest ('\r' :: acc)
  | '\\' :: 't' :: rest, acc => pStr rest ('\t' :: acc)
  | '\\' :: 'u' :: a :: b :: c :: d :: rest, acc =>
      match hex4 a b c d with
      | some ch => pStr rest (ch :: acc)
      | none => none
  | '\\' :: _, _ => none
  | c :: rest, acc => if c.toNat < 32 then none else pStr rest (c :: acc)

def isDigitC (c : Char) : Bool := '0' ≤ c && c ≤ '9'

/-- Zero or more digits. -/
def digits : List Char → List Char × List Char
  | c :: cs => if isDigitC c then let (d, r) := digits cs; (c :: d, r) else ([], c :: cs)
  | [] => ([], [])

/-- RFC 8259 number: `-? (0 | [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?`. -/
def pNum (cs : List Char) : Option (J × List Char) :=
  let (sign, cs) := match cs with | '-' :: r => (L!"-", r) | r => ([], r)
  let intPart : Option (List Char × List Char) := match cs with
    | '0' :: r => some (L!"0", r)
    | c :: r => if isDigitC c then let (d, r') := digits r; some (c :: d, r') else none
    | [] => none
  match intPart with
  | none => none
  | some (ip, r) =>
    let fracPart : Option (List Char × List Char) := match r with
      | '.' :: r' => let (d, r'') := digits r'; if d.isEmpty then none else some ('.' :: d, r'')
      | _ => some ([], r)
    match fracPart with
    | none => none
    | some (fp, r) =>
      let expPart : Option (List Char × List Char) := match r with
        | e :: r' =>
          if e = 'e' ∨ e = 'E' then
            let (sg, r'') := match r' with
              | '+' :: x => (L!"+", x) | '-' :: x => (L!"-", x) | x => ([], x)
            let (d, r''') := digits r''
            if d.isEmpty then none else some (e :: sg ++ d, r''')
          else some ([], e :: r')
        | [] => some ([], [])
      match expPart with
      | none => none
      | some (ep, r) => some (.num (sign ++ ip ++ fp ++ ep), r)

mutual
/-- A value, after optional whitespace. `fuel` bounds the recursion; `parseJson` gives enough. -/
def pValue : Nat → List Char → Option (J × List Char)
  | 0, _ => none
  | n + 1, cs =>
    match skipWs cs with
    | '{' :: rest => pObj n (skipWs rest)
    | '[' :: rest => pArr n (skipWs rest)
    | '"' :: rest => (pStr rest []).map fun (s, r) => (.str s, r)
    | 't' :: 'r' :: 'u' :: 'e' :: rest => some (.tru, rest)
    | 'f' :: 'a' :: 'l' :: 's' :: 'e' :: rest => some (.fls, rest)
    | 'n' :: 'u' :: 'l' :: 'l' :: rest => some (.null, rest)
    | c :: rest => if c = '-' ∨ isDigitC c then pNum (c :: rest) else none
    | [] => none

/-- After `{` and whitespace. -/
def pObj : Nat → List Char → Option (J × List Char)
  | 0, _ => none
  | _ + 1, '}' :: rest => some (.obj [], rest)
  | n + 1, cs => pMembers n cs []

/-- At a member's key; `acc` is the members so far, in source order. -/
def pMembers : Nat → List Char → List (List Char × J) → Option (J × List Char)
  | 0, _, _ => none
  | n + 1, '"' :: rest, acc =>
    match pStr rest [] with
    | none => none
    | some (k, r) =>
      match skipWs r with
      | ':' :: r2 =>
        match pValue n r2 with
        | none => none
        | some (v, r3) =>
          match skipWs r3 with
          | ',' :: r4 => pMembers n (skipWs r4) (acc ++ [(k, v)])
          | '}' :: r4 => some (.obj (acc ++ [(k, v)]), r4)
          | _ => none
      | _ => none
  | _ + 1, _, _ => none

/-- After `[` and whitespace. -/
def pArr : Nat → List Char → Option (J × List Char)
  | 0, _ => none
  | _ + 1, ']' :: rest => some (.arr [], rest)
  | n + 1, cs => pElems n cs []

def pElems : Nat → List Char → List J → Option (J × List Char)
  | 0, _, _ => none
  | n + 1, cs, acc =>
    match pValue n cs with
    | none => none
    | some (v, r) =>
      match skipWs r with
      | ',' :: r2 => pElems n r2 (acc ++ [v])
      | ']' :: r2 => some (.arr (acc ++ [v]), r2)
      | _ => none
end

/-- A whole document: whitespace, one value, whitespace, end of input. -/
def parseJson (cs : List Char) : Option J :=
  match pValue (cs.length + 1) cs with
  | some (v, rest) => if skipWs rest = [] then some v else none
  | none => none

/-! ## The TypeScript side: `wake-waiter.ts:129-144` -/

/-- ECMAScript `WhiteSpace` and `LineTerminator`, which `String.prototype.trim` removes. -/
def isJsWs (c : Char) : Bool :=
  let n := c.toNat
  n = 0x09 || n = 0x0A || n = 0x0B || n = 0x0C || n = 0x0D || n = 0x20 || n = 0xA0 ||
  n = 0x1680 || (0x2000 ≤ n && n ≤ 0x200A) || n = 0x2028 || n = 0x2029 || n = 0x202F ||
  n = 0x205F || n = 0x3000 || n = 0xFEFF

/-- `s.trim()`. -/
def jsTrim (s : List Char) : List Char :=
  ((s.dropWhile isJsWs).reverse.dropWhile isJsWs).reverse

/-- Property read on a parsed JSON value. An object's own property; with duplicate keys
`JSON.parse` keeps the LAST one. Every other value (and `undefined`) has no `error`/`code`. -/
def jsGet : Option J → List Char → Option J
  | some (.obj kvs), k => (kvs.reverse.find? (fun kv => kv.1 == k)).map (·.2)
  | _, _ => none

structure HerdrResult where
  code : Int
  stderr : List Char
  spawnError : Bool   -- `r.spawnError !== undefined`

/-- `herdrFailureCode` (`wake-waiter.ts:129-140`). -/
def tsFailureCode (r : HerdrResult) : List Char :=
  if r.spawnError then L!"spawn_error"
  else if r.code ≤ 0 then []
  else if r.code = 2 then L!"cli_syntax"
  else
    match parseJson (jsTrim r.stderr) with      -- `JSON.parse(r.stderr.trim())`, throws → catch
    | none => L!"herdr_cli_rejected"
    | some parsed =>
      match jsGet (jsGet (some parsed) L!"error") L!"code" with   -- `parsed?.error?.code`
      | some (.str c) => if c ≠ [] then c else L!"herdr_json_undecodable"
      | _ => L!"herdr_json_undecodable"

/-- `herdrMeansAgentGone` (`wake-waiter.ts:142-144`). -/
def tsMeansAgentGone (r : HerdrResult) : Bool :=
  endsWithL (tsFailureCode r) L!"_not_found"

/-! ## The AILANG side: `types.ail:1127-1207` -/

/-! ### AILANG's `std/json.decode`, as corrected by step (2)

Initial model: `parseJson`, the same RFC 8259 parser as `JSON.parse`, on the untrimmed string
(`json_error_field` passes `stderr` as it is). Corrected twice (see "Model corrections"):
it reads the FIRST complete value and ignores whatever follows it (correction 1), and it
refuses a document holding a number whose magnitude rounds to infinity as a float64
(correction 2). -/

def natOfDigits (ds : List Char) : Nat := ds.foldl (fun n c => n * 10 + (c.toNat - '0'.toNat)) 0

/-- Number of digits of `n` in base 10, `0` for `0`, given `fuel` at least that many. (Not
`(toString n).length`: that pulls `Classical.choice` into every theorem through `String`.) -/
def numDigits : Nat → Nat → Nat
  | 0, _ => 0
  | fuel + 1, n => if n = 0 then 0 else 1 + numDigits fuel (n / 10)

/-- The float64 overflow threshold: values at or above `2^1024 - 2^970` round to infinity
(the halfway point rounds to even, which is up). -/
def f64Overflow : Nat := 2 ^ 1024 - 2 ^ 970

/-- A number lexeme (RFC 8259 grammar, already checked) as `M * 10^E`. -/
def lexemeValue (lex : List Char) : Nat × Int :=
  let body := match lex with | '-' :: r => r | r => r
  let (intDs, r) := digits body
  let (fracDs, r) := match r with | '.' :: r' => digits r' | r' => ([], r')
  let expV : Int := match r with
    | _ :: r' => match r' with
      | '-' :: ds => - (natOfDigits ds : Int)
      | '+' :: ds => (natOfDigits ds : Int)
      | ds => (natOfDigits ds : Int)
    | [] => 0
  (natOfDigits (intDs ++ fracDs), expV - fracDs.length)

/-- `true` when the lexeme's magnitude rounds to a finite float64. -/
def f64Finite (lex : List Char) : Bool :=
  let (m, e) := lexemeValue lex
  if m = 0 then true
  else
    let k : Int := numDigits (lex.length + 1) m + e   -- 10^(k-1) ≤ value < 10^k
    if k ≤ 308 then true
    else if k ≥ 310 then false
    else if e ≥ 0 then decide (m * 10 ^ e.toNat < f64Overflow)
    else decide (m < f64Overflow * 10 ^ (-e).toNat)

mutual
def J.finite : J → Bool
  | .num lex => f64Finite lex
  | .arr xs => J.finiteList xs
  | .obj kvs => J.finiteMembers kvs
  | _ => true
def J.finiteList : List J → Bool
  | [] => true
  | x :: xs => J.finite x && J.finiteList xs
def J.finiteMembers : List (List Char × J) → Bool
  | [] => true
  | (_, v) :: kvs => J.finite v && J.finiteMembers kvs
end

def ailDecode (s : List Char) : Option J :=
  match pValue (s.length + 1) s with
  | some (v, _) => if v.finite then some v else none     -- corrections 1 and 2
  | none => none

/-- AILANG `std/json.get`. Initial model: the FIRST member with that key; `None` on a
non-object. -/
def ailGet : J → List Char → Option J
  | .obj kvs, k => (kvs.find? (fun kv => kv.1 == k)).map (·.2)
  | _, _ => none

/-- `asString`. -/
def asStr : J → Option (List Char)
  | .str s => some s
  | _ => none

inductive Shape where
  | ok | cliSyntax | nestedHerdr | herdrJson | unknown | plainText
  deriving DecidableEq, Repr

/-- `failure_shape` (`types.ail:1127-1143`). -/
def failureShape (exitCode : Int) (stderr : List Char) : Shape :=
  if exitCode = 0 then .ok
  else if exitCode = 2 then .cliSyntax
  else if containsL stderr L!"nested herdr" then .nestedHerdr
  else if containsL stderr L!"{\"error\"" then .herdrJson
  else if stderr = [] then .unknown
  else .plainText

/-- `json_error_field` (`types.ail:1145-1156`). -/
def jsonErrorField (stderr field : List Char) : List Char :=
  match ailDecode stderr with
  | none => []
  | some obj =>
    match ailGet obj L!"error" with
    | none => []
    | some e =>
      match ailGet e field with
      | none => []
      | some v => match asStr v with | some s => s | none => []

/-- `failure_code` (`types.ail:1160-1180`). -/
def failureCode (exitCode : Int) (stderr : List Char) : List Char :=
  let shape := failureShape exitCode stderr
  if shape = .ok then []
  else if shape = .herdrJson then
    let c := jsonErrorField stderr L!"code"
    if c = [] then L!"herdr_json_undecodable" else c
  else if shape = .cliSyntax then L!"cli_syntax"
  else if shape = .nestedHerdr then L!"nested_herdr"
  else if shape = .unknown then L!"herdr_failed_silently"
  else L!"herdr_cli_rejected"

/-- `means_agent_gone` (`types.ail:1198-1207`). -/
def meansAgentGone (exitCode : Int) (stderr : List Char) : Bool :=
  failureCode exitCode stderr == L!"agent_not_found"

/-! ## Model corrections (step 2)

Each correction is a change to the model forced by a mismatch with the real code.

1. `ailDecode` (AILANG `std/json.decode`) reads the first complete value and ignores what
   follows it. Run 1: 196 mismatched cases, all with text after the closing `}`:
   `{"error":{"code":"agent_not_found"}}x`, `...}}}`, `...} {...}`, `...}\nkilled by SIGTERM`,
   `...}\u000c`, `...}\u2028`, `...}\u0000`. The real `failure_code` said `agent_not_found`,
   the model `herdr_json_undecodable`.
2. `ailDecode` refuses a document holding a number out of float64 range. Run 1: 16 mismatched
   cases, all `{"error":{"code":"agent_not_found","n":1e400}}` (4 stderr variants x exit codes
   -1, 1, 3, 127): the real `failure_code` said `herdr_json_undecodable`, the model
   `agent_not_found`. Boundary cases were added to the corpus to pin the threshold.

The TypeScript half matched on the first run (0 mismatches) and has not been changed.
-/

/-! ## Proved properties

`tsCodeField` is the TS side's view of `error.code` (`parsed?.error?.code`): `none` when
`JSON.parse(stderr.trim())` throws, `some c` with the string otherwise (`[]` when it is
absent, empty or not a string, since both sides then say `herdr_json_undecodable`). -/

def tsCodeField (s : List Char) : Option (List Char) :=
  match parseJson (jsTrim s) with
  | none => none
  | some p =>
    match jsGet (jsGet (some p) L!"error") L!"code" with
    | some (.str c) => some c
    | _ => some []

/-- The TS code, for a positive exit other than 2, is a function of `tsCodeField`. -/
theorem tsFailureCode_json (e : Int) (s c : List Char) (he : 0 < e) (h2 : e ≠ 2)
    (hts : tsCodeField s = some c) :
    tsFailureCode ⟨e, s, false⟩ = (if c = [] then L!"herdr_json_undecodable" else c) := by
  have hle : ¬ e ≤ 0 := by omega
  simp only [tsCodeField] at hts
  simp only [tsFailureCode, hle, h2, if_false, Bool.false_eq_true]
  split
  · rename_i h; rw [h] at hts; simp at hts
  · rename_i p h
    rw [h] at hts
    simp only at hts
    split
    · rename_i c' h'
      rw [h'] at hts; simp only [Option.some.injEq] at hts; subst hts
      rcases Decidable.em (c' = []) with hc | hc <;> simp [hc]
    · rename_i h'
      split at hts
      · rename_i c'' h''; exact absurd h'' (h' c'')
      · simp only [Option.some.injEq] at hts; subst hts; simp

/-- The AILANG code, on the `herdr_json` shape, is a function of `json_error_field`. -/
theorem failureCode_json (e : Int) (s : List Char) (he0 : e ≠ 0) (h2 : e ≠ 2)
    (hn : containsL s L!"nested herdr" = false) (hj : containsL s L!"{\"error\"" = true) :
    failureCode e s =
      (if jsonErrorField s L!"code" = [] then L!"herdr_json_undecodable"
       else jsonErrorField s L!"code") := by
  simp [failureCode, failureShape, he0, h2, hn, hj]

/-- **P2.1, where it holds.** On herdr's JSON shape (exit positive and not 2, the `{"error"`
sniff passes, no `nested herdr`), when `JSON.parse` and AILANG's `decode` read the same
`error.code` `c`, and `c` is not a `*_not_found` code other than `agent_not_found`, the two
twins agree. Each `bug_` theorem below breaks exactly one of these hypotheses, so none of
them can be dropped. -/
theorem p21_of_agreement (e : Int) (s c : List Char) (he : 0 < e) (h2 : e ≠ 2)
    (hn : containsL s L!"nested herdr" = false) (hj : containsL s L!"{\"error\"" = true)
    (hts : tsCodeField s = some c) (hail : jsonErrorField s L!"code" = c)
    (hnarrow : endsWithL c L!"_not_found" = true → c = L!"agent_not_found") :
    tsMeansAgentGone ⟨e, s, false⟩ = meansAgentGone e s := by
  have he0 : e ≠ 0 := by omega
  simp only [tsMeansAgentGone, meansAgentGone]
  rw [tsFailureCode_json e s c he h2 hts, failureCode_json e s he0 h2 hn hj, hail]
  rcases Decidable.em (c = []) with hc | hc
  · subst hc; decide
  · simp only [hc, if_false]
    cases hend : endsWithL c L!"_not_found"
    · -- TS says not gone; then `c` is not `agent_not_found` either
      have : c ≠ L!"agent_not_found" := by
        intro h; subst h; revert hend; decide
      simp [this]
    · have := hnarrow hend
      subst this; decide

/-- The hypotheses of `p21_of_agreement` are satisfiable: herdr's measured `agent_not_found`
envelope (`wake-waiter.test.ts:16`), where both twins say "gone". -/
theorem p21_of_agreement_witness :
    let s := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"},\"id\":\"cli:agent:get\"}"
    containsL s L!"nested herdr" = false ∧ containsL s L!"{\"error\"" = true ∧
    tsCodeField s = some L!"agent_not_found" ∧ jsonErrorField s L!"code" = L!"agent_not_found" ∧
    tsMeansAgentGone ⟨1, s, false⟩ = true ∧ meansAgentGone 1 s = true := by
  decide

/-- **P2.1 on the measured vocabulary** (`MEASUREMENTS-2026-08-31-failure-codes.md`, and the
test vectors of `types.ail:1199-1206`): every measured case agrees. -/
theorem p21_measured :
    let cases : List (Int × List Char) :=
      [ (1, L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"},\"id\":\"cli:agent:get\"}"),
        (1, L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}"),
        (1, L!"{\"error\":{\"code\":\"server_not_running\",\"message\":\"x\"}}"),
        (1, L!"{\"error\":{\"code\":\"timeout\",\"message\":\"x\"}}"),
        (2, L!"herdr agent commands:"),
        (1, L!"--current requires HERDR_PANE_ID"),
        (0, []) ]
    cases.all (fun (e, s) => tsMeansAgentGone ⟨e, s, false⟩ == meansAgentGone e s) = true := by
  decide

/-- The AILANG side is narrow, for every input: "gone" only on exactly `agent_not_found`. -/
theorem ail_gone_only_agent_not_found (e : Int) (s : List Char) :
    meansAgentGone e s = true → failureCode e s = L!"agent_not_found" := by
  simp [meansAgentGone]

/-- The TS side is not: "gone" on every code that ends in `_not_found`. -/
theorem ts_gone_iff_suffix (r : HerdrResult) :
    tsMeansAgentGone r = true ↔ endsWithL (tsFailureCode r) L!"_not_found" = true := Iff.rfl

/-- Neither twin calls exit 0 "gone", and neither calls exit 2 "gone", for every stderr. -/
theorem neither_gone_on_0_or_2 (s : List Char) :
    tsMeansAgentGone ⟨0, s, false⟩ = false ∧ meansAgentGone 0 s = false ∧
    tsMeansAgentGone ⟨2, s, false⟩ = false ∧ meansAgentGone 2 s = false := by
  exact ⟨rfl, rfl, rfl, rfl⟩

/-- A spawn error is never "gone" on the TS side (P2.1 excludes it; stated for completeness). -/
theorem ts_spawn_error_not_gone (e : Int) (s : List Char) :
    tsMeansAgentGone ⟨e, s, true⟩ = false := by
  simp [tsMeansAgentGone, tsFailureCode]; decide

/-! ### The rest of the case split

With `p21_of_agreement`, these cover every input with no spawn error: if the twins disagree,
then the exit code is negative (`ts_not_gone_nonpos`), or the extension's shape sniff sends
herdr's JSON elsewhere while the host reads it (`ail_not_gone_off_shape`), or `JSON.parse`
fails where AILANG's `decode` reads a code (`ts_not_gone_parse_fails`), or the two decoders
read different codes, or the code is a `*_not_found` other than `agent_not_found`. Those are
the mechanisms of B1-T2-1 to B1-T2-8. -/

/-- The host never says "gone" for a non-positive exit code. -/
theorem ts_not_gone_nonpos (e : Int) (s : List Char) (he : e ≤ 0) :
    tsMeansAgentGone ⟨e, s, false⟩ = false := by
  simp [tsMeansAgentGone, tsFailureCode, he]; decide

/-- The extension never says "gone" when `nested herdr` occurs or `{"error"` does not. -/
theorem ail_not_gone_off_shape (e : Int) (s : List Char)
    (h : containsL s L!"nested herdr" = true ∨ containsL s L!"{\"error\"" = false) :
    meansAgentGone e s = false := by
  simp only [meansAgentGone, failureCode, failureShape]
  rcases h with hn | hj
  · rcases Decidable.em (e = 0) with h0 | h0 <;> rcases Decidable.em (e = 2) with h2 | h2 <;> simp [h0, h2, hn] <;> decide
  · rcases Decidable.em (e = 0) with h0 | h0 <;> rcases Decidable.em (e = 2) with h2 | h2 <;> rcases Decidable.em (containsL s L!"nested herdr" = true) with hn | hn <;>
      rcases Decidable.em (s = []) with hs | hs <;> simp [h0, h2, hn, hj, hs] <;> decide

/-- When `JSON.parse(stderr.trim())` throws, the host never says "gone". -/
theorem ts_not_gone_parse_fails (e : Int) (s : List Char) (hts : tsCodeField s = none) :
    tsMeansAgentGone ⟨e, s, false⟩ = false := by
  simp only [tsCodeField] at hts
  simp only [tsMeansAgentGone, tsFailureCode, Bool.false_eq_true, if_false]
  split
  · decide
  · split
    · decide
    · split
      · rename_i h; rw [h] at hts; simp at hts; decide
      · rename_i p h; rw [h] at hts; simp only at hts; split at hts <;> simp at hts

/-- **P2.1, the complete case split.** For every exit code and stderr with no spawn error: if
the twins disagree, then one of five things is true of the input. (1) The exit code is
negative (B1-T2-2). (2) Exit is positive, not 2, and the extension's shape sniff sends the
text away from herdr's JSON (B1-T2-3, B1-T2-4). (3) `JSON.parse(stderr.trim())` throws
(B1-T2-6). (4) The two decoders read different `error.code` values (B1-T2-5 to B1-T2-8).
(5) The code is a `*_not_found` other than `agent_not_found` (B1-T2-1). Every case holds of
some disagreeing input (`p21_cases_inhabited`), so none of the five is vacuous. -/
theorem p21_disagreement_cases (e : Int) (s : List Char)
    (hd : tsMeansAgentGone ⟨e, s, false⟩ ≠ meansAgentGone e s) :
    e < 0 ∨
    (0 < e ∧ e ≠ 2 ∧ (containsL s L!"nested herdr" = true ∨ containsL s L!"{\"error\"" = false)) ∨
    tsCodeField s = none ∨
    (∃ c, tsCodeField s = some c ∧ jsonErrorField s L!"code" ≠ c) ∨
    (∃ c, tsCodeField s = some c ∧ endsWithL c L!"_not_found" = true ∧ c ≠ L!"agent_not_found") := by
  rcases Decidable.em (e < 0) with hneg | hneg
  · exact Or.inl hneg
  rcases Decidable.em (e = 0) with h0 | h0
  · subst h0; exact absurd ((neither_gone_on_0_or_2 s).1.trans (neither_gone_on_0_or_2 s).2.1.symm) hd
  rcases Decidable.em (e = 2) with h2 | h2
  · subst h2; exact absurd ((neither_gone_on_0_or_2 s).2.2.1.trans (neither_gone_on_0_or_2 s).2.2.2.symm) hd
  have hpos : 0 < e := by omega
  rcases Decidable.em (containsL s L!"nested herdr" = true ∨ containsL s L!"{\"error\"" = false) with hsh | hsh
  · exact Or.inr (Or.inl ⟨hpos, h2, hsh⟩)
  have hn : containsL s L!"nested herdr" = false := by
    cases h : containsL s L!"nested herdr"
    · rfl
    · exact absurd (Or.inl h) hsh
  have hj : containsL s L!"{\"error\"" = true := by
    cases h : containsL s L!"{\"error\""
    · exact absurd (Or.inr h) hsh
    · rfl
  cases hts : tsCodeField s with
  | none => exact Or.inr (Or.inr (Or.inl rfl))
  | some c =>
    rcases Decidable.em (jsonErrorField s L!"code" = c) with hail | hail
    · rcases Decidable.em (endsWithL c L!"_not_found" = true ∧ c ≠ L!"agent_not_found") with hsuf | hsuf
      · exact Or.inr (Or.inr (Or.inr (Or.inr ⟨c, rfl, hsuf.1, hsuf.2⟩)))
      · have hnarrow : endsWithL c L!"_not_found" = true → c = L!"agent_not_found" := by
          intro hend
          rcases Decidable.em (c = L!"agent_not_found") with hc | hc
          · exact hc
          · exact absurd ⟨hend, hc⟩ hsuf
        exact absurd (p21_of_agreement e s c hpos h2 hn hj hts hail hnarrow) hd
    · exact Or.inr (Or.inr (Or.inr (Or.inl ⟨c, rfl, hail⟩)))

/-- Each case of `p21_disagreement_cases` is inhabited by a disagreeing input: the witnesses of
B1-T2-2, B1-T2-3, B1-T2-6, B1-T2-5 and B1-T2-1, in the order of the cases. -/
theorem p21_cases_inhabited :
    (let s := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}"
     tsMeansAgentGone ⟨-1, s, false⟩ ≠ meansAgentGone (-1) s ∧ (-1 : Int) < 0) ∧
    (let s := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"nested herdr\"}}"
     tsMeansAgentGone ⟨1, s, false⟩ ≠ meansAgentGone 1 s ∧ containsL s L!"nested herdr" = true) ∧
    (let s := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}\nkilled by SIGTERM"
     tsMeansAgentGone ⟨1, s, false⟩ ≠ meansAgentGone 1 s ∧ tsCodeField s = none) ∧
    (let s := (Char.ofNat 0xA0) :: L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}"
     tsMeansAgentGone ⟨1, s, false⟩ ≠ meansAgentGone 1 s ∧
     tsCodeField s = some L!"agent_not_found" ∧ jsonErrorField s L!"code" ≠ L!"agent_not_found") ∧
    (let s := L!"{\"error\":{\"code\":\"pane_not_found\",\"message\":\"x\"}}"
     tsMeansAgentGone ⟨1, s, false⟩ ≠ meansAgentGone 1 s ∧
     tsCodeField s = some L!"pane_not_found" ∧ endsWithL L!"pane_not_found" L!"_not_found" = true ∧
     L!"pane_not_found" ≠ L!"agent_not_found") := by
  decide

/-! ## Counterexamples: P2.1 (`herdrMeansAgentGone` ≠ `means_agent_gone`)

Each is reproduced on the real code by the script named in reports.tsv. -/

/-- B1-T2-1. `endsWith("_not_found")` is wider than `== "agent_not_found"`: herdr's own
`pane_not_found` (`herdr.ail:818`) is "gone" to the host and not to the extension. -/
theorem bug_suffix_not_found :
    let s := L!"{\"error\":{\"code\":\"pane_not_found\",\"message\":\"x\"}}"
    tsMeansAgentGone ⟨1, s, false⟩ = true ∧ meansAgentGone 1 s = false := by decide

/-- B1-T2-2. A negative exit code is "success" (`""`) to the host: `code <= 0`, against the
extension's `exit_code == 0`. The second witness is the real runner's shape for a herdr child
killed by a signal after printing `agent_not_found` (`wake-waiter.ts:513-514`). -/
theorem bug_negative_exit :
    let s := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}"
    let s' := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}\nkilled by SIGTERM"
    tsMeansAgentGone ⟨-1, s, false⟩ = false ∧ meansAgentGone (-1) s = true ∧
    tsMeansAgentGone ⟨-1, s', false⟩ = false ∧ meansAgentGone (-1) s' = true := by decide

/-- B1-T2-3. `failure_shape` tests `contains(stderr, "nested herdr")` before it looks for
herdr's JSON, so an `agent_not_found` envelope whose message mentions it is `nested_herdr`. -/
theorem bug_nested_in_message :
    let s := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"nested herdr\"}}"
    tsMeansAgentGone ⟨1, s, false⟩ = true ∧ meansAgentGone 1 s = false := by decide

/-- B1-T2-4. `failure_shape` recognises herdr's JSON by the substring `{"error"`, so the same
envelope with another key first, or a space after the brace, is `plain_text`. -/
theorem bug_error_key_not_first :
    let s := L!"{\"id\":\"cli:agent:get\",\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}"
    let s' := L!"{ \"error\": {\"code\": \"agent_not_found\"}}"
    tsMeansAgentGone ⟨1, s, false⟩ = true ∧ meansAgentGone 1 s = false ∧
    tsMeansAgentGone ⟨1, s', false⟩ = true ∧ meansAgentGone 1 s' = false := by decide

/-- B1-T2-5. `trim()` removes Unicode whitespace JSON does not allow; AILANG's `decode` gets the
untrimmed text. Witness: a leading U+00A0 (also U+FEFF, U+000B, U+000C, U+3000 in the run). -/
theorem bug_js_trim :
    let s := (Char.ofNat 0xA0) :: L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}"
    tsMeansAgentGone ⟨1, s, false⟩ = true ∧ meansAgentGone 1 s = false := by decide

/-- B1-T2-6. AILANG's `decode` reads the first value and ignores the rest (model correction 1);
`JSON.parse` refuses trailing text. Here the extension says "gone" and the host does not. -/
theorem bug_trailing_text :
    let s := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}\nkilled by SIGTERM"
    tsMeansAgentGone ⟨1, s, false⟩ = false ∧ meansAgentGone 1 s = true := by decide

/-- B1-T2-7. Duplicate keys: AILANG's `get` takes the first, `JSON.parse` keeps the last. Both
directions. -/
theorem bug_duplicate_key :
    let s := L!"{\"error\":{\"code\":\"timeout\"},\"error\":{\"code\":\"agent_not_found\"}}"
    let s' := L!"{\"error\":{\"code\":\"agent_not_found\",\"code\":\"timeout\"}}"
    tsMeansAgentGone ⟨1, s, false⟩ = true ∧ meansAgentGone 1 s = false ∧
    tsMeansAgentGone ⟨1, s', false⟩ = false ∧ meansAgentGone 1 s' = true := by decide

/-- B1-T2-8. A number out of float64 range anywhere in the document makes AILANG's `decode`
fail (model correction 2); `JSON.parse` reads it as `Infinity`. -/
theorem bug_f64_overflow :
    let s := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\",\"n\":1e400}}"
    tsMeansAgentGone ⟨1, s, false⟩ = true ∧ meansAgentGone 1 s = false := by decide

/-! ## Counterexamples: P2.2 (`herdrFailureCode` ≠ `failure_code`) -/

/-- B1-T2-9. The real runner's result for a herdr child killed by a signal (`code: -1`, no
`spawnError`, stderr `killed by SIGTERM`, `wake-waiter.ts:513-514`) is `""`, the code the TS
doc comment reserves for success; the extension says `herdr_cli_rejected`. With herdr's JSON
on stderr the extension reads the code and the host still says `""`. -/
theorem bug_code_negative_exit :
    tsFailureCode ⟨-1, L!"killed by SIGTERM", false⟩ = [] ∧
    failureCode (-1) L!"killed by SIGTERM" = L!"herdr_cli_rejected" ∧
    tsFailureCode ⟨-1, L!"{\"error\":{\"code\":\"timeout\"}}", false⟩ = [] ∧
    failureCode (-1) L!"{\"error\":{\"code\":\"timeout\"}}" = L!"timeout" := by decide

/-- B1-T2-10. Inside herdr's JSON, the code differs wherever P2.1's shape mechanisms apply,
also for codes that are not `*_not_found`: `timeout` with `nested herdr` in its message, and
`timeout` with `id` first. -/
theorem bug_code_inside_json :
    tsFailureCode ⟨1, L!"{\"error\":{\"code\":\"timeout\",\"message\":\"nested herdr\"}}", false⟩ = L!"timeout" ∧
    failureCode 1 L!"{\"error\":{\"code\":\"timeout\",\"message\":\"nested herdr\"}}" = L!"nested_herdr" ∧
    tsFailureCode ⟨1, L!"{\"id\":\"cli:agent:wait\",\"error\":{\"code\":\"timeout\"}}", false⟩ = L!"timeout" ∧
    failureCode 1 L!"{\"id\":\"cli:agent:wait\",\"error\":{\"code\":\"timeout\"}}" = L!"herdr_cli_rejected" := by
  decide

/-- B1-T2-11. K6, outside herdr's JSON: the TS vocabulary has no `nested_herdr` and no
`herdr_failed_silently`, and calls any JSON that is not an envelope `herdr_json_undecodable`
where the extension says `herdr_cli_rejected`. -/
theorem bug_k6_outside_json :
    tsFailureCode ⟨1, [], false⟩ = L!"herdr_cli_rejected" ∧
    failureCode 1 [] = L!"herdr_failed_silently" ∧
    tsFailureCode ⟨1, L!"error: nested herdr is disabled by default.", false⟩ = L!"herdr_cli_rejected" ∧
    failureCode 1 L!"error: nested herdr is disabled by default." = L!"nested_herdr" ∧
    tsFailureCode ⟨1, L!"null", false⟩ = L!"herdr_json_undecodable" ∧
    failureCode 1 L!"null" = L!"herdr_cli_rejected" := by
  decide

/-- B1-T2-14. herdr's envelope cut short (no closing brace): the extension's sniff sees
`{"error"` and says `herdr_json_undecodable`; the host's `JSON.parse` throws and it says
`herdr_cli_rejected`, which its doc comment reserves for "stderr is not herdr JSON". -/
theorem bug_code_truncated_json :
    tsFailureCode ⟨1, L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}", false⟩ =
      L!"herdr_cli_rejected" ∧
    failureCode 1 L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}" =
      L!"herdr_json_undecodable" := by
  decide

/-! ## Step 8: the narrow fix to the TS twin

`herdrMeansAgentGone` with `=== "agent_not_found"` in place of `.endsWith("_not_found")`, and
`herdrFailureCode` with `r.code === 0` in place of `r.code <= 0`. Proved: on herdr's JSON shape
it agrees with `means_agent_gone` for EVERY exit code (negative ones included) whenever the
two decoders read the same `error.code`, with no hypothesis about which code that is. It does
not close B1-T2-3 to B1-T2-8: those are in the shape sniff and the decoders, which this fix
leaves as they are. -/

def tsFailureCodeFixed (r : HerdrResult) : List Char :=
  if r.spawnError then L!"spawn_error"
  else if r.code = 0 then []
  else if r.code = 2 then L!"cli_syntax"
  else
    match parseJson (jsTrim r.stderr) with
    | none => L!"herdr_cli_rejected"
    | some parsed =>
      match jsGet (jsGet (some parsed) L!"error") L!"code" with
      | some (.str c) => if c ≠ [] then c else L!"herdr_json_undecodable"
      | _ => L!"herdr_json_undecodable"

def tsMeansAgentGoneFixed (r : HerdrResult) : Bool :=
  tsFailureCodeFixed r == L!"agent_not_found"

theorem fix_p21_of_agreement (e : Int) (s c : List Char) (he0 : e ≠ 0) (h2 : e ≠ 2)
    (hn : containsL s L!"nested herdr" = false) (hj : containsL s L!"{\"error\"" = true)
    (hts : tsCodeField s = some c) (hail : jsonErrorField s L!"code" = c) :
    tsMeansAgentGoneFixed ⟨e, s, false⟩ = meansAgentGone e s := by
  simp only [tsMeansAgentGoneFixed, meansAgentGone]
  rw [failureCode_json e s he0 h2 hn hj, hail]
  simp only [tsCodeField] at hts
  simp only [tsFailureCodeFixed, he0, h2, if_false, Bool.false_eq_true]
  split
  · rename_i h; rw [h] at hts; simp at hts
  · rename_i p h
    rw [h] at hts
    simp only at hts
    split
    · rename_i c' h'
      rw [h'] at hts; simp only [Option.some.injEq] at hts; subst hts
      rcases Decidable.em (c' = []) with hc | hc <;> simp [hc]
    · rename_i h'
      split at hts
      · rename_i c'' h''; exact absurd h'' (h' c'')
      · simp only [Option.some.injEq] at hts; subst hts; simp

/-- The fix closes B1-T2-1 and B1-T2-2 on their witnesses, and keeps the measured cases. -/
theorem fix_closes_suffix_and_negative_exit :
    let s1 := L!"{\"error\":{\"code\":\"pane_not_found\",\"message\":\"x\"}}"
    let s2 := L!"{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}"
    tsMeansAgentGoneFixed ⟨1, s1, false⟩ = meansAgentGone 1 s1 ∧
    tsMeansAgentGoneFixed ⟨-1, s2, false⟩ = meansAgentGone (-1) s2 ∧
    tsMeansAgentGoneFixed ⟨1, s2, false⟩ = true := by decide

/-! ## Axiom report -/

#print axioms tsFailureCode_json
#print axioms failureCode_json
#print axioms p21_of_agreement
#print axioms p21_of_agreement_witness
#print axioms p21_measured
#print axioms ail_gone_only_agent_not_found
#print axioms ts_gone_iff_suffix
#print axioms neither_gone_on_0_or_2
#print axioms ts_not_gone_nonpos
#print axioms ail_not_gone_off_shape
#print axioms ts_not_gone_parse_fails
#print axioms p21_disagreement_cases
#print axioms p21_cases_inhabited
#print axioms ts_spawn_error_not_gone
#print axioms bug_suffix_not_found
#print axioms bug_negative_exit
#print axioms bug_nested_in_message
#print axioms bug_error_key_not_first
#print axioms bug_js_trim
#print axioms bug_trailing_text
#print axioms bug_duplicate_key
#print axioms bug_f64_overflow
#print axioms bug_code_negative_exit
#print axioms bug_code_inside_json
#print axioms bug_k6_outside_json
#print axioms bug_code_truncated_json
#print axioms fix_p21_of_agreement
#print axioms fix_closes_suffix_and_negative_exit
