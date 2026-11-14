-- M2_ts_exit_zero_only: target bug_p21_negative_exit must be false, control bug_p21_suffix true
/-
HerdrFailureModel.lean — target T2, the herdr failure vocabulary, a cross-language twin.

CHECKED 2026-11-04: Lean 4.28.0 (core only) accepts this file with no error; every theorem's
axioms are within `propext`, `Classical.choice`, `Quot.sound` (axiom_report.txt). The model
part (up to `## Theorems`) matched the real code on all 273,872 cases of diff/ (0 mismatches on
either side) after three model fixes, each marked "Model fix N" below and listed in
diff/README.md. Every `bug_` witness is reproduced on the real code by repro/.

Lean 4.28.0, core only (no Mathlib, no Lake): `lean HerdrFailureModel.lean`.

A Lean model of two implementations of one rule, in the snapshot at
/home/motoko/trial-043/s/t043-t2-b2/tree:

  * src/tui/src/wake-waiter.ts:128-144
      `herdrFailureCode` (:129-140) and `herdrMeansAgentGone` (:142-144), the host's
      "TS twin of `types.ail`'s `failure_code` / `means_agent_gone`" (:125).
  * packages/motoko-ext-herdr/types.ail:1127-1207
      `failure_shape` (:1127-1143), `json_error_field` (:1145-1155),
      `failure_code` (:1160-1180), `means_agent_gone` (:1198-1207).

What the model keeps and what it abstracts:

  * A string is `List Char` (Unicode scalar values). Real stderr reaches both sides as text
    decoded from UTF-8, so it never holds a lone surrogate; JS's UTF-16 units and AILANG's bytes
    only differ from code points in `length`, which neither function reads. `contains`,
    `endsWith`, `trim` and equality are the same on all three representations.
  * `JSON.parse` is modelled by `jsonParse`, a strict RFC 8259 / ECMA-404 parser over the whole
    input. Inside JSON strings a `\uD800`-style lone surrogate escape is kept by JS as a lone
    UTF-16 unit, which no `Char` can hold: the model writes unit u as the private-use code point
    U+F0000 + u (`loneSurrogate`; model fix 2), and the test inputs never contain those. AILANG's
    `decode` writes U+FFFD instead. (As first written, both sides wrote U+FFFD.)
  * `String.prototype.trim` is `jsTrim`, with ECMA-262's WhiteSpace and LineTerminator sets.
  * `parsed?.error?.code` is `jsErrorCode`: own data properties only (JSON.parse builds
    plain objects; neither "error" nor "code" exists on Object.prototype or String.prototype),
    LAST duplicate key wins (JSON.parse's CreateDataProperty overwrites).
  * AILANG's `std/json.decode` and `get` are opaque here: their source is outside the snapshot.
    `ailDecode` / `ailGet` are the model's guesses, and the differential test (diff/) is what
    pins them (model fixes 1 and 3; `get` keeping the FIRST duplicate key was guessed and
    confirmed). The history is in diff/README.md and SUMMARY.md.
  * `HerdrResult.stdout` is not read by either function and is dropped. `spawnError` is kept as
    an `Option`, though P2.1 and P2.2 only quantify over `none`.
  * Exit codes are `Int`. Node gives `-1` for a signal-killed child (wake-waiter.ts:514), and the
    AILANG side takes any `int`.
-/

abbrev Str := List Char

/-! ## String helpers (both sides) -/

def isPrefixL : Str → Str → Bool
  | [], _ => true
  | _ :: _, [] => false
  | a :: as, b :: bs => a == b && isPrefixL as bs

/-- `std/string.contains(s, pat)`: `pat` occurs in `s`. -/
def containsL : Str → Str → Bool
  | [], pat => isPrefixL pat []
  | c :: rest, pat => isPrefixL pat (c :: rest) || containsL rest pat

/-- `String.prototype.endsWith`. -/
def endsWithL (s suf : Str) : Bool := isPrefixL suf.reverse s.reverse

def dropWhileL (p : Char → Bool) : Str → Str
  | [] => []
  | c :: r => if p c then dropWhileL p r else c :: r

/-- ECMA-262 WhiteSpace ∪ LineTerminator: what `String.prototype.trim` strips. -/
def jsWs (c : Char) : Bool :=
  let n := c.toNat
  n == 0x09 || n == 0x0A || n == 0x0B || n == 0x0C || n == 0x0D || n == 0x20 || n == 0xA0 ||
  n == 0x1680 || (0x2000 ≤ n && n ≤ 0x200A) || n == 0x2028 || n == 0x2029 || n == 0x202F ||
  n == 0x205F || n == 0x3000 || n == 0xFEFF

/-- `String.prototype.trim`. -/
def jsTrim (s : Str) : Str := (dropWhileL jsWs (dropWhileL jsWs s).reverse).reverse

/-! ## JSON -/

inductive JVal where
  | null
  | bool (b : Bool)
  | num (raw : Str)
  | str (s : Str)
  | arr (xs : List JVal)
  | obj (kvs : List (Str × JVal))
  deriving Repr, Inhabited

/-- RFC 8259 insignificant whitespace. -/
def jsonWs (c : Char) : Bool := c == ' ' || c == '\t' || c == '\n' || c == '\r'

def skipWs : Str → Str := dropWhileL jsonWs

def hexVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n && n ≤ 57 then some (n - 48)
  else if 97 ≤ n && n ≤ 102 then some (n - 87)
  else if 65 ≤ n && n ≤ 70 then some (n - 55)
  else none

def hex4 : Str → Option (Nat × Str)
  | a :: b :: c :: d :: rest =>
    match hexVal a, hexVal b, hexVal c, hexVal d with
    | some a, some b, some c, some d => some (((a * 16 + b) * 16 + c) * 16 + d, rest)
    | _, _, _, _ => none
  | _ => none

def replacementChar : Char := Char.ofNat 0xFFFD

/-- How a parser represents a lone surrogate escape `u`. `JSON.parse` keeps the UTF-16 unit, which
no `Char` can hold, so the TS side stands it for the private-use code point U+F0000 + u (inputs
never contain those); AILANG's `decode` replaces it with U+FFFD (diff/, model fix 2). -/
def loneSurrogate (ts : Bool) (u : Nat) : Char :=
  if ts then Char.ofNat (0xF0000 + u) else replacementChar

/-- One `\u` escape, its four hex digits already read as `u`; joins a surrogate pair. -/
def unicodeEscape (ts : Bool) (u : Nat) (rest : Str) : Char × Str :=
  if 0xD800 ≤ u && u ≤ 0xDBFF then
    match rest with
    | '\\' :: 'u' :: r =>
      match hex4 r with
      | some (l, r') =>
        if 0xDC00 ≤ l && l ≤ 0xDFFF
        then (Char.ofNat (0x10000 + (u - 0xD800) * 0x400 + (l - 0xDC00)), r')
        else (loneSurrogate ts u, rest)
      | none => (loneSurrogate ts u, rest)
    | _ => (loneSurrogate ts u, rest)
  else if 0xDC00 ≤ u && u ≤ 0xDFFF then (loneSurrogate ts u, rest)
  else (Char.ofNat u, rest)

/-- The body of a JSON string after its opening quote. `acc` is reversed. -/
def parseStrBody (ts : Bool) : Nat → Str → Str → Option (Str × Str)
  | 0, _, _ => none
  | _ + 1, _, [] => none
  | fuel + 1, acc, c :: r =>
    if c == '"' then some (acc.reverse, r)
    else if c.toNat < 0x20 then none
    else if c == '\\' then
      match r with
      | '"' :: r' => parseStrBody ts fuel ('"' :: acc) r'
      | '\\' :: r' => parseStrBody ts fuel ('\\' :: acc) r'
      | '/' :: r' => parseStrBody ts fuel ('/' :: acc) r'
      | 'b' :: r' => parseStrBody ts fuel (Char.ofNat 8 :: acc) r'
      | 'f' :: r' => parseStrBody ts fuel (Char.ofNat 12 :: acc) r'
      | 'n' :: r' => parseStrBody ts fuel ('\n' :: acc) r'
      | 'r' :: r' => parseStrBody ts fuel ('\r' :: acc) r'
      | 't' :: r' => parseStrBody ts fuel ('\t' :: acc) r'
      | 'u' :: r' =>
        match hex4 r' with
        | some (u, r'') =>
          let (ch, r3) := unicodeEscape ts u r''
          parseStrBody ts fuel (ch :: acc) r3
        | none => none
      | _ => none
    else parseStrBody ts fuel (c :: acc) r

def isDigit (c : Char) : Bool := '0' ≤ c && c ≤ '9'

def spanDigits : Str → Str × Str
  | [] => ([], [])
  | c :: r => if isDigit c then let (d, r') := spanDigits r; (c :: d, r') else ([], c :: r)

/-- RFC 8259 `number`; the value is kept as its text, which neither side reads. -/
def parseNumber (s : Str) : Option (Str × Str) :=
  let (sign, s1) := match s with
    | '-' :: r => (['-'], r)
    | r => ([], r)
  let intPart : Option (Str × Str) := match s1 with
    | '0' :: r => some (['0'], r)
    | c :: r => if isDigit c then let (d, r') := spanDigits r; some (c :: d, r') else none
    | [] => none
  match intPart with
  | none => none
  | some (ip, s2) =>
    let frac : Option (Str × Str) := match s2 with
      | '.' :: r => let (d, r') := spanDigits r; if d.isEmpty then none else some ('.' :: d, r')
      | r => some ([], r)
    match frac with
    | none => none
    | some (fp, s3) =>
      let expo : Option (Str × Str) := match s3 with
        | e :: r =>
          if e == 'e' || e == 'E' then
            let (sg, r1) := match r with
              | '+' :: r1 => (['+'], r1)
              | '-' :: r1 => (['-'], r1)
              | r1 => ([], r1)
            let (d, r2) := spanDigits r1
            if d.isEmpty then none else some (e :: sg ++ d, r2)
          else some ([], e :: r)
        | [] => some ([], [])
      match expo with
      | none => none
      | some (ep, s4) => some (sign ++ ip ++ fp ++ ep, s4)

def digitsVal (ds : Str) : Nat := ds.foldl (fun n c => n * 10 + (c.toNat - 48)) 0

/-- Model fix 3 (diff/): AILANG's `decode` refuses a number whose magnitude rounds past the
largest float64, i.e. |x| ≥ 2^1024 - 2^970 (`1e999`, `2e308`); `JSON.parse` gives ±Infinity.
`raw` is a well-formed RFC 8259 number. -/
def numOverflows (raw : Str) : Bool :=
  let s := match raw with
    | '-' :: r => r
    | r => r
  let (ip, r1) := spanDigits s
  let (fp, r2) := match r1 with
    | '.' :: r => spanDigits r
    | r => ([], r)
  let e : Int := match r2 with
    | _ :: '-' :: d => - (digitsVal d : Int)
    | _ :: '+' :: d => digitsVal d
    | _ :: d => digitsVal d
    | [] => 0
  let mant := ip ++ fp
  let m := digitsVal mant
  let ex : Int := e - fp.length
  let nd := (dropWhileL (· == '0') mant).length
  let k : Int := nd - 1 + ex
  let t : Nat := 2 ^ 1024 - 2 ^ 970
  if m = 0 then false
  else if k ≥ 309 then true
  else if k ≤ 307 then false
  else if ex ≥ 0 then decide (m * 10 ^ ex.toNat ≥ t)
  else decide (m ≥ t * 10 ^ (-ex).toNat)

mutual
def parseValue (ts : Bool) : Nat → Str → Option (JVal × Str)
  | 0, _ => none
  | fuel + 1, s =>
    match skipWs s with
    | 'n' :: 'u' :: 'l' :: 'l' :: r => some (.null, r)
    | 't' :: 'r' :: 'u' :: 'e' :: r => some (.bool true, r)
    | 'f' :: 'a' :: 'l' :: 's' :: 'e' :: r => some (.bool false, r)
    | '"' :: r =>
      match parseStrBody ts (r.length + 1) [] r with
      | some (x, r') => some (.str x, r')
      | none => none
    | '[' :: r =>
      match skipWs r with
      | ']' :: r' => some (.arr [], r')
      | _ => parseElems ts fuel r []
    | '{' :: r =>
      match skipWs r with
      | '}' :: r' => some (.obj [], r')
      | _ => parseMembers ts fuel r []
    | r =>
      match parseNumber r with
      | some (n, r') => if !ts && numOverflows n then none else some (.num n, r')
      | none => none

def parseElems (ts : Bool) : Nat → Str → List JVal → Option (JVal × Str)
  | 0, _, _ => none
  | fuel + 1, s, acc =>
    match parseValue ts fuel s with
    | none => none
    | some (v, r) =>
      match skipWs r with
      | ',' :: r' => parseElems ts fuel r' (v :: acc)
      | ']' :: r' => some (.arr (v :: acc).reverse, r')
      | _ => none

def parseMembers (ts : Bool) : Nat → Str → List (Str × JVal) → Option (JVal × Str)
  | 0, _, _ => none
  | fuel + 1, s, acc =>
    match skipWs s with
    | '"' :: r =>
      match parseStrBody ts (r.length + 1) [] r with
      | none => none
      | some (k, r1) =>
        match skipWs r1 with
        | ':' :: r2 =>
          match parseValue ts fuel r2 with
          | none => none
          | some (v, r3) =>
            match skipWs r3 with
            | ',' :: r4 => parseMembers ts fuel r4 ((k, v) :: acc)
            | '}' :: r4 => some (.obj ((k, v) :: acc).reverse, r4)
            | _ => none
        | _ => none
    | _ => none
end

/-- `JSON.parse`: one value, then only whitespace. -/
def jsonParse (s : Str) : Option JVal :=
  match parseValue true (2 * s.length + 2) s with
  | some (v, r) => if skipWs r = [] then some v else none
  | none => none

def lookupFirst (k : Str) : List (Str × JVal) → Option JVal
  | [] => none
  | (k', v) :: rest => if k' = k then some v else lookupFirst k rest

/-- JS property read on a JSON.parse result: objects only, last duplicate wins. -/
def jsGet : JVal → Str → Option JVal
  | .obj kvs, k => lookupFirst k kvs.reverse
  | _, _ => none

def asStr : JVal → Option Str
  | .str s => some s
  | _ => none

/-- `parsed?.error?.code`, when it is a string. -/
def jsErrorCode (v : JVal) : Option Str :=
  match jsGet v "error".toList with
  | none => none
  | some e => match jsGet e "code".toList with
    | none => none
    | some c => asStr c

/-! ## The TypeScript side: wake-waiter.ts:128-144 -/

structure HerdrResult where
  code       : Int
  stderr     : Str
  spawnError : Option Str := none

/-- What the TS side reads from stderr: `JSON.parse(r.stderr.trim())`, then `?.error?.code`.
`none` = the parse threw; `some none` = parsed, `code` not a string. -/
def tsParsedCode (stderr : Str) : Option (Option Str) :=
  (jsonParse (jsTrim stderr)).map jsErrorCode

/-- `herdrFailureCode`, branch for branch. -/
def herdrFailureCode (r : HerdrResult) : Str :=
  if r.spawnError.isSome then "spawn_error".toList
  else if r.code = 0 then []   -- MUTANT
  else if r.code = 2 then "cli_syntax".toList
  else
    match tsParsedCode r.stderr with
    | none => "herdr_cli_rejected".toList                       -- catch
    | some (some c) => if c ≠ [] then c else "herdr_json_undecodable".toList
    | some none => "herdr_json_undecodable".toList

/-- `herdrMeansAgentGone`. -/
def herdrMeansAgentGone (r : HerdrResult) : Bool :=
  endsWithL (herdrFailureCode r) "_not_found".toList

/-! ## The AILANG side: types.ail:1127-1207 -/

/-- `std/json.decode`. MODEL OF AN OPAQUE BUILTIN; pinned by the differential test.
Model fix 1: the first JSON value after leading RFC whitespace; ANYTHING after it is ignored
(`{"error":{...}}killed by SIGTERM` decodes). -/
def ailDecode (s : Str) : Option JVal :=
  match parseValue false (2 * s.length + 2) s with
  | some (v, _) => some v
  | none => none

/-- `std/json.get`. MODEL OF AN OPAQUE BUILTIN; pinned by the differential test. -/
def ailGet : JVal → Str → Option JVal
  | .obj kvs, k => lookupFirst k kvs
  | _, _ => none

def nestedPat : Str := "nested herdr".toList
def errPat : Str := "{\"error\"".toList

/-- `failure_shape`, types.ail:1127. -/
def failureShape (exitCode : Int) (stderr : Str) : Str :=
  if exitCode = 0 then "ok".toList
  else if exitCode = 2 then "cli_syntax".toList
  else if containsL stderr nestedPat then "nested_herdr".toList
  else if containsL stderr errPat then "herdr_json".toList
  else if stderr = [] then "unknown".toList
  else "plain_text".toList

/-- `json_error_field`, types.ail:1145. -/
def jsonErrorField (stderr field : Str) : Str :=
  match ailDecode stderr with
  | none => []
  | some obj =>
    match ailGet obj "error".toList with
    | none => []
    | some e =>
      match ailGet e field with
      | none => []
      | some v => match asStr v with
        | some s => s
        | none => []

/-- `failure_code`, types.ail:1160. -/
def failureCode (exitCode : Int) (stderr : Str) : Str :=
  let shape := failureShape exitCode stderr
  if shape = "ok".toList then []
  else if shape = "herdr_json".toList then
    let c := jsonErrorField stderr "code".toList
    if c = [] then "herdr_json_undecodable".toList else c
  else if shape = "cli_syntax".toList then "cli_syntax".toList
  else if shape = "nested_herdr".toList then "nested_herdr".toList
  else if shape = "unknown".toList then "herdr_failed_silently".toList
  else "herdr_cli_rejected".toList

/-- `means_agent_gone`, types.ail:1198. -/
def meansAgentGone (exitCode : Int) (stderr : Str) : Bool :=
  failureCode exitCode stderr == "agent_not_found".toList


def notFound : Str := "_not_found".toList
def agentNotFound : Str := "agent_not_found".toList
def undecodable : Str := "herdr_json_undecodable".toList
def canonical : Str := "{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}".toList

def targetHolds : Bool := decide (
    herdrMeansAgentGone { code := -1, stderr := canonical } = false ∧
    meansAgentGone (-1) canonical = true ∧
    herdrFailureCode { code := -1, stderr := canonical } = [] ∧
    failureCode (-1) canonical = "agent_not_found".toList)

def controlHolds : Bool := decide (
    let s := "{\"error\":{\"code\":\"pane_not_found\",\"message\":\"x\"}}".toList
    herdrMeansAgentGone { code := 1, stderr := s } = true ∧ meansAgentGone 1 s = false ∧
    herdrFailureCode { code := 1, stderr := s } = failureCode 1 s)

#eval IO.println s!"TARGET bug_p21_negative_exit {targetHolds}"
#eval IO.println s!"CONTROL bug_p21_suffix {controlHolds}"
