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
  else if r.code ≤ 0 then []
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

/-! ## Theorems

Every theorem below is checked by Lean's kernel; none uses `sorry` or `native_decide`
(`decide +kernel` only skips the elaborator's pre-check; the kernel still evaluates the
`Decidable` instance). The axiom report is at the end of the file.

The P2.1 / P2.2 statements quantify over every exit code and every stderr, with no spawn
error (`spawnError := none` is `HerdrResult`'s default). The registered properties without
hypotheses are FALSE (the `bug_` theorems); `p21_holds_under_H` and `p22_holds_under_H` state
which hypotheses make them true, and each hypothesis has a `bug_` theorem whose witness breaks
it (and, by inspection, none of the others).
-/

def notFound : Str := "_not_found".toList
def agentNotFound : Str := "agent_not_found".toList
def undecodable : Str := "herdr_json_undecodable".toList

/-- The code the TS side reads, when it reads one: `JSON.parse(stderr.trim())` succeeded and
`error.code` is a non-empty string. -/
def tsCode (s : Str) : Option Str :=
  match tsParsedCode s with
  | some (some c) => if c = [] then none else some c
  | _ => none

/-- The code the AILANG side reads through `json_error_field`, when it is non-empty. -/
def ailCode (s : Str) : Option Str :=
  if jsonErrorField s "code".toList = [] then none else some (jsonErrorField s "code".toList)

/-! ### What each side computes, for a failed call -/

theorem ts_gone_pos (code : Int) (s : Str) (h0 : 0 < code) (h2 : code ≠ 2) :
    herdrMeansAgentGone { code := code, stderr := s } =
      (match tsCode s with | some c => endsWithL c notFound | none => false) := by
  have h0' : ¬ code ≤ 0 := by omega
  simp only [herdrMeansAgentGone, herdrFailureCode, tsCode, h0', h2, if_false,
    Option.isSome_none, Bool.false_eq_true]
  cases tsParsedCode s with
  | none => decide
  | some o =>
    cases o with
    | none => decide
    | some c =>
      by_cases hc : c = []
      · subst hc; decide
      · simp [hc, notFound]

theorem ts_code_parsed (code : Int) (s : Str) (h0 : 0 < code) (h2 : code ≠ 2)
    (hp : tsParsedCode s ≠ none) :
    herdrFailureCode { code := code, stderr := s } =
      (match tsCode s with | some c => c | none => undecodable) := by
  have h0' : ¬ code ≤ 0 := by omega
  simp only [herdrFailureCode, tsCode, h0', h2, if_false, Option.isSome_none, Bool.false_eq_true]
  cases h : tsParsedCode s with
  | none => exact absurd h hp
  | some o =>
    cases o with
    | none => rfl
    | some c =>
      by_cases hc : c = []
      · subst hc; rfl
      · simp [hc]

theorem ail_gone_pos (code : Int) (s : Str) (h0 : code ≠ 0) (h2 : code ≠ 2)
    (hn : containsL s nestedPat = false) :
    meansAgentGone code s = (containsL s errPat && (ailCode s == some agentNotFound)) := by
  simp only [meansAgentGone, failureCode, failureShape, ailCode, h0, h2, hn, if_false,
    Bool.false_eq_true]
  cases he : containsL s errPat
  · simp only [Bool.false_eq_true, if_false, Bool.false_and]
    by_cases hs : s = []
    · subst hs; decide
    · simp +decide only [hs, if_false]
  · by_cases hc : jsonErrorField s "code".toList = []
    · simp +decide only [hc, if_true]
    · simp +decide [hc, agentNotFound]

theorem ail_code_json (code : Int) (s : Str) (h0 : code ≠ 0) (h2 : code ≠ 2)
    (hn : containsL s nestedPat = false) (he : containsL s errPat = true) :
    failureCode code s = (match ailCode s with | some c => c | none => undecodable) := by
  simp only [failureCode, failureShape, ailCode, h0, h2, hn, he, if_false, if_true,
    Bool.false_eq_true]
  by_cases hc : jsonErrorField s "code".toList = []
  · simp +decide [hc, undecodable]
  · simp +decide [hc]

theorem both_cli_syntax (s : Str) :
    herdrFailureCode { code := 2, stderr := s } = "cli_syntax".toList ∧
    failureCode 2 s = "cli_syntax".toList := by
  constructor
  · simp +decide [herdrFailureCode]
  · simp +decide [failureCode, failureShape]

/-! ### P2.1, proved under hypotheses -/

/-- **P2.1 holds exactly where these five hypotheses hold** (each is shown necessary below):
  * `hexit`   the exit code is positive (`bug_p21_negative_exit`);
  * `hnest`   stderr does not mention "nested herdr" (`bug_p21_nested_in_message`);
  * `hgate`   whenever TS reads a code, stderr contains `{"error"` (`bug_p21_key_order`,
              `bug_p21_spaced_json`);
  * `hagree`  on `{"error"`-gated stderr, `JSON.parse(trim)` and AILANG's `decode` read the same
              code (`bug_p21_duplicate_code_*`, `bug_p21_trailing_text`, `bug_p21_unicode_space`);
  * `hnarrow` a code ending in `_not_found` is `agent_not_found` (`bug_p21_suffix`). -/
theorem p21_holds_under_H (code : Int) (s : Str)
    (hexit : 0 < code)
    (hnest : containsL s nestedPat = false)
    (hgate : tsCode s ≠ none → containsL s errPat = true)
    (hagree : containsL s errPat = true → tsCode s = ailCode s)
    (hnarrow : ∀ c, tsCode s = some c → endsWithL c notFound = true → c = agentNotFound) :
    herdrMeansAgentGone { code := code, stderr := s } = meansAgentGone code s := by
  by_cases h2 : code = 2
  · subst h2
    simp +decide [herdrMeansAgentGone, herdrFailureCode, meansAgentGone, failureCode, failureShape]
  · rw [ts_gone_pos code s hexit h2, ail_gone_pos code s (by omega) h2 hnest]
    cases he : containsL s errPat
    · have ht : tsCode s = none := by
        cases h : tsCode s with
        | none => rfl
        | some c =>
          have := hgate (by simp [h])
          rw [he] at this
          exact absurd this (by decide)
      simp [ht]
    · have ha := hagree he
      cases ht : tsCode s with
      | none =>
        rw [ht] at ha
        simp [← ha]
      | some c =>
        rw [ht] at ha
        simp only [Bool.true_and, ← ha]
        by_cases hc : c = agentNotFound
        · subst hc; decide
        · have hf : endsWithL c notFound = false := by
            cases hh : endsWithL c notFound
            · rfl
            · exact absurd (hnarrow c ht hh) hc
          simp [hf, hc]

/-! ### P2.2, proved under hypotheses -/

/-- **P2.2 holds on herdr's JSON**: positive exit, no "nested herdr", stderr gated by
`{"error"`, `JSON.parse(trim)` succeeds, and the two decoders read the same code. -/
theorem p22_holds_under_H (code : Int) (s : Str)
    (hexit : 0 < code)
    (hnest : containsL s nestedPat = false)
    (hgate : containsL s errPat = true)
    (hparse : tsParsedCode s ≠ none)
    (hagree : tsCode s = ailCode s) :
    herdrFailureCode { code := code, stderr := s } = failureCode code s := by
  by_cases h2 : code = 2
  · subst h2
    rw [(both_cli_syntax s).1, (both_cli_syntax s).2]
  · rw [ts_code_parsed code s hexit h2 hparse, ail_code_json code s (by omega) h2 hnest hgate,
      hagree]

/-- Outside herdr's JSON, the two agree on non-empty plain text that is not JSON and does not
mention "nested herdr" (both `herdr_cli_rejected`). K6's divergences are the other cases. -/
theorem p22_plain_text_agrees (code : Int) (s : Str)
    (hexit : 0 < code) (h2 : code ≠ 2)
    (hnest : containsL s nestedPat = false)
    (hgate : containsL s errPat = false)
    (hne : s ≠ [])
    (hparse : tsParsedCode s = none) :
    herdrFailureCode { code := code, stderr := s } = failureCode code s := by
  have h0' : ¬ code ≤ 0 := by omega
  have h0 : code ≠ 0 := by omega
  simp +decide only [herdrFailureCode, failureCode, failureShape, h0', h0, h2, hnest, hgate, hne,
    hparse, if_false, Option.isSome_none, Bool.false_eq_true]

/-! ### P2.1 and P2.2 on herdr's own envelope, at the string level

The theorems above take the decoders' agreement (`hagree`, `hgate`) as hypotheses. Here the
stderr is herdr's envelope `{"error":{"code":"C"}}` (the shape of types.ail's and
wake-waiter.test.ts's vectors) for EVERY code string `C` without `"`, `\` or control
characters, and those hypotheses are discharged by proving what both parsers do on it. -/
def isPlain (C : Str) : Prop := ∀ ch ∈ C, ch ≠ '"' ∧ ch ≠ '\\' ∧ 0x20 ≤ ch.toNat

theorem parseStrBody_plain (ts : Bool) (C rest acc : Str) (fuel : Nat)
    (hC : isPlain C) (hf : C.length < fuel) :
    parseStrBody ts fuel acc (C ++ '"' :: rest) = some (acc.reverse ++ C, rest) := by
  induction C generalizing fuel acc with
  | nil =>
    cases fuel with
    | zero => simp at hf
    | succ n => simp [parseStrBody]
  | cons ch C ih =>
    cases fuel with
    | zero => simp at hf
    | succ n =>
      obtain ⟨h1, h2, h3⟩ := hC ch (by simp)
      have hC' : isPlain C := fun x hx => hC x (by simp [hx])
      have hf' : C.length < n := by simp at hf; omega
      have e1 : ¬ ((ch == '"') = true) := by simpa using h1
      have e2 : ¬ (ch.toNat < 0x20) := by omega
      have e3 : ¬ ((ch == '\\') = true) := by simpa using h2
      simp only [List.cons_append, parseStrBody, e1, e2, e3, if_false]
      rw [ih (ch :: acc) n hC' hf']
      simp

def envPrefix : Str := ['{', '"', 'e', 'r', 'r', 'o', 'r', '"', ':', '{', '"', 'c', 'o', 'd', 'e', '"', ':', '"']
def envSuffix : Str := ['"', '}', '}']
def kError : Str := ['e', 'r', 'r', 'o', 'r']
def kCode : Str := ['c', 'o', 'd', 'e']

/-- herdr's error envelope with code `C`, the shape `types.ail`'s and wake-waiter.test.ts's vectors use. -/
def envelope (C : Str) : Str := envPrefix ++ C ++ envSuffix

theorem envelope_eq (C : Str) :
    envelope C = "{\"error\":{\"code\":\"".toList ++ C ++ "\"}}".toList := by
  simp only [envelope]; congr 2

theorem dw_ne (c : Char) (r : Str) (h : jsonWs c = false) : dropWhileL jsonWs (c :: r) = c :: r := by
  simp [dropWhileL, h]

theorem parseValue_str (ts : Bool) (n : Nat) (C rest : Str) (hC : isPlain C) :
    parseValue ts (n + 1) ('"' :: (C ++ '"' :: rest)) = some (.str C, rest) := by
  simp only [parseValue, skipWs, dw_ne '"' _ (by decide)]
  rw [parseStrBody_plain ts C rest [] _ hC (by simp only [List.length_append, List.length_cons]; omega)]
  simp

theorem parseValue_obj (ts : Bool) (n : Nat) (rest : Str) :
    parseValue ts (n + 1) ('{' :: '"' :: rest) = parseMembers ts n ('"' :: rest) [] := by
  simp only [parseValue, skipWs, dw_ne '{' _ (by decide), dw_ne '"' _ (by decide)]
  split
  · rename_i h; injection h with h1; exact absurd h1 (by decide)
  · rfl

theorem parseMembers_one (ts : Bool) (n : Nat) (K s r : Str) (v : JVal) (hK : isPlain K)
    (hv : parseValue ts n s = some (v, '}' :: r)) :
    parseMembers ts (n + 1) ('"' :: (K ++ '"' :: ':' :: s)) [] = some (.obj [(K, v)], r) := by
  simp only [parseMembers, skipWs, dw_ne '"' _ (by decide)]
  rw [parseStrBody_plain ts K (':' :: s) [] _ hK (by simp only [List.length_append, List.length_cons]; omega)]
  simp only [List.reverse_nil, List.nil_append, dw_ne ':' _ (by decide), hv, dw_ne '}' _ (by decide)]
  rfl

theorem isPlain_kError : isPlain kError := by
  intro ch h; simp only [kError] at h; revert ch; decide
theorem isPlain_kCode : isPlain kCode := by
  intro ch h; simp only [kCode] at h; revert ch; decide

theorem envelope_cons (C : Str) : envelope C =
    '{' :: '"' :: (kError ++ '"' :: ':' :: '{' :: '"' :: (kCode ++ '"' :: ':' :: '"' :: (C ++ '"' :: '}' :: '}' :: []))) := by
  simp [envelope, envPrefix, envSuffix, kError, kCode]

theorem parseValue_envelope (ts : Bool) (C : Str) (hC : isPlain C) (fuel : Nat)
    (hf : 6 ≤ fuel) :
    parseValue ts fuel (envelope C) =
      some (.obj [(kError, .obj [(kCode, .str C)])], []) := by
  obtain ⟨n, rfl⟩ : ∃ n, fuel = n + 6 := ⟨fuel - 6, by omega⟩
  have h1 : parseValue ts (n + 2) ('"' :: (C ++ '"' :: '}' :: '}' :: [])) = some (.str C, '}' :: '}' :: []) :=
    parseValue_str ts (n + 1) C _ hC
  have h2 := parseMembers_one ts (n + 2) kCode ('"' :: (C ++ '"' :: '}' :: '}' :: [])) ['}'] (.str C) isPlain_kCode h1
  have h3 : parseValue ts (n + 4) ('{' :: '"' :: (kCode ++ '"' :: ':' :: '"' :: (C ++ '"' :: '}' :: '}' :: []))) =
      some (.obj [(kCode, .str C)], '}' :: []) := by
    rw [parseValue_obj]; exact h2
  have h4 := parseMembers_one ts (n + 4) kError _ [] _ isPlain_kError h3
  rw [envelope_cons, parseValue_obj]; exact h4

theorem jsTrim_envelope (C : Str) : jsTrim (envelope C) = envelope C := by
  simp +decide [jsTrim, envelope, envPrefix, envSuffix, dropWhileL, jsWs, List.reverse_append]

theorem tsParsedCode_envelope (C : Str) (hC : isPlain C) :
    tsParsedCode (envelope C) = some (some C) := by
  have hp := parseValue_envelope true C hC (2 * (envelope C).length + 2)
    (by simp [envelope, envPrefix, envSuffix]; omega)
  simp only [tsParsedCode, jsTrim_envelope, jsonParse, hp]
  simp +decide [skipWs, dropWhileL, jsErrorCode, jsGet, lookupFirst, kError, kCode, asStr]

theorem jsonErrorField_envelope (C : Str) (hC : isPlain C) :
    jsonErrorField (envelope C) "code".toList = C := by
  have hp := parseValue_envelope false C hC (2 * (envelope C).length + 2)
    (by simp [envelope, envPrefix, envSuffix]; omega)
  simp only [jsonErrorField, ailDecode, hp]
  simp +decide [ailGet, lookupFirst, kError, kCode, asStr]

theorem errPat_envelope (C : Str) : containsL (envelope C) errPat = true := by
  have he : errPat = ['{', '"', 'e', 'r', 'r', 'o', 'r', '"'] := by decide
  rw [envelope_cons, he]
  simp +decide [containsL, isPrefixL, kError]

theorem tsCode_ailCode_envelope (C : Str) (hC : isPlain C) :
    tsCode (envelope C) = ailCode (envelope C) := by
  simp only [tsCode, ailCode, tsParsedCode_envelope C hC, jsonErrorField_envelope C hC]

/-- **P2.1 on herdr's envelope, exactly.** For every exit code other than 0 and 2 that is
positive, and every plain code string `C` (no `"`, `\`, or control character) whose envelope
does not mention "nested herdr", the twins agree iff a `C` ending in `_not_found` is
`agent_not_found`. (Exit 2 is `cli_syntax` on both sides: `both_cli_syntax`.) -/
theorem p21_envelope_iff (code : Int) (C : Str) (hexit : 0 < code) (h2 : code ≠ 2)
    (hC : isPlain C) (hnest : containsL (envelope C) nestedPat = false) :
    herdrMeansAgentGone { code := code, stderr := envelope C } = meansAgentGone code (envelope C) ↔
      (endsWithL C notFound = true → C = agentNotFound) := by
  rw [ts_gone_pos code _ hexit h2, ail_gone_pos code _ (by omega) h2 hnest, errPat_envelope]
  have htc : tsCode (envelope C) = if C = [] then none else some C := by
    simp [tsCode, tsParsedCode_envelope C hC]
  have hac : ailCode (envelope C) = if C = [] then none else some C := by
    simp [ailCode, jsonErrorField_envelope C hC]
  rw [htc, hac]
  by_cases hc0 : C = []
  · subst hc0; simp +decide [notFound]
  · simp only [hc0, if_false, Bool.true_and]
    by_cases ha : C = agentNotFound
    · subst ha; decide
    · have hb : (some C == some agentNotFound) = false := by simp [ha]
      rw [hb]
      cases endsWithL C notFound <;> simp [ha]

/-- **P2.2 on herdr's envelope.** For every positive exit code and every plain code string
whose envelope does not mention "nested herdr", the failure codes are equal. -/
theorem p22_envelope (code : Int) (C : Str) (hexit : 0 < code) (hC : isPlain C)
    (hnest : containsL (envelope C) nestedPat = false) :
    herdrFailureCode { code := code, stderr := envelope C } = failureCode code (envelope C) :=
  p22_holds_under_H code (envelope C) hexit hnest (errPat_envelope C)
    (by rw [tsParsedCode_envelope C hC]; simp) (tsCode_ailCode_envelope C hC)

/-- Non-vacuity of both: herdr's own measured codes satisfy every hypothesis. -/
theorem envelope_nonvacuous :
    isPlain agentNotFound ∧ containsL (envelope agentNotFound) nestedPat = false ∧
    herdrMeansAgentGone { code := 1, stderr := envelope agentNotFound } = true ∧
    meansAgentGone 1 (envelope agentNotFound) = true := by
  refine ⟨?_, by decide +kernel, by decide +kernel, by decide +kernel⟩
  intro ch h
  simp only [agentNotFound] at h
  revert ch; decide

/-! ### The same, on herdr's full envelope `{"error":{"code":"C","message":"M"},"id":"I"}`

The shape herdr actually prints (MEASUREMENTS-2026-08-31-failure-codes.md; wake-waiter.test.ts's
`NOT_FOUND`; types.ail's `failure_code` vectors), for every plain `C`, `M` and `I`. -/
theorem parseMembers_last (ts : Bool) (n : Nat) (K s r : Str) (v : JVal) (acc : List (Str × JVal))
    (hK : isPlain K) (hv : parseValue ts n s = some (v, '}' :: r)) :
    parseMembers ts (n + 1) ('"' :: (K ++ '"' :: ':' :: s)) acc = some (.obj ((K, v) :: acc).reverse, r) := by
  simp only [parseMembers, skipWs, dw_ne '"' _ (by decide)]
  rw [parseStrBody_plain ts K (':' :: s) [] _ hK (by simp only [List.length_append, List.length_cons]; omega)]
  simp only [List.reverse_nil, List.nil_append, dw_ne ':' _ (by decide), hv, dw_ne '}' _ (by decide)]

theorem parseMembers_more (ts : Bool) (n : Nat) (K s r : Str) (v : JVal) (acc : List (Str × JVal))
    (hK : isPlain K) (hv : parseValue ts n s = some (v, ',' :: r)) :
    parseMembers ts (n + 1) ('"' :: (K ++ '"' :: ':' :: s)) acc = parseMembers ts n r ((K, v) :: acc) := by
  simp only [parseMembers, skipWs, dw_ne '"' _ (by decide)]
  rw [parseStrBody_plain ts K (':' :: s) [] _ hK (by simp only [List.length_append, List.length_cons]; omega)]
  simp only [List.reverse_nil, List.nil_append, dw_ne ':' _ (by decide), hv, dw_ne ',' _ (by decide)]

def kMessage : Str := ['m', 'e', 's', 's', 'a', 'g', 'e']
def kId : Str := ['i', 'd']

theorem isPlain_kMessage : isPlain kMessage := by
  intro ch h; simp only [kMessage] at h; revert ch; decide
theorem isPlain_kId : isPlain kId := by
  intro ch h; simp only [kId] at h; revert ch; decide

/-- `"id":"I"}` -/
def tId (I : Str) : Str := '"' :: (kId ++ '"' :: ':' :: '"' :: (I ++ '"' :: '}' :: []))
/-- `"message":"M"},"id":"I"}` -/
def tMsg (M I : Str) : Str := '"' :: (kMessage ++ '"' :: ':' :: '"' :: (M ++ '"' :: '}' :: ',' :: tId I))
/-- `"code":"C","message":"M"},"id":"I"}` -/
def tCode (C M I : Str) : Str := '"' :: (kCode ++ '"' :: ':' :: '"' :: (C ++ '"' :: ',' :: tMsg M I))

/-- herdr's full error envelope, as measured (MEASUREMENTS-2026-08-31-failure-codes.md) and as
wake-waiter.test.ts's `NOT_FOUND` and types.ail's vectors have it:
`{"error":{"code":"C","message":"M"},"id":"I"}`. -/
def herdrEnvelope (C M I : Str) : Str := '{' :: '"' :: (kError ++ '"' :: ':' :: '{' :: tCode C M I)

theorem herdrEnvelope_eq (C M I : Str) : herdrEnvelope C M I =
    "{\"error\":{\"code\":\"".toList ++ C ++ "\",\"message\":\"".toList ++ M ++
      "\"},\"id\":\"".toList ++ I ++ "\"}".toList := by
  simp only [herdrEnvelope, tCode, tMsg, tId, List.append_assoc, List.cons_append]
  rfl

def herdrEnvelopeValue (C M I : Str) : JVal :=
  .obj [(kError, .obj [(kCode, .str C), (kMessage, .str M)]), (kId, .str I)]

theorem parseValue_inner (ts : Bool) (C M I : Str) (hC : isPlain C) (hM : isPlain M) (n : Nat) :
    parseValue ts (n + 6) ('{' :: tCode C M I) =
      some (.obj [(kCode, .str C), (kMessage, .str M)], ',' :: tId I) := by
  have hc := parseValue_str ts (n + 3) C (',' :: tMsg M I) hC
  have hm := parseValue_str ts (n + 2) M ('}' :: ',' :: tId I) hM
  simp only [tCode]
  rw [parseValue_obj, parseMembers_more ts (n + 4) kCode _ _ (.str C) [] isPlain_kCode hc]
  simp only [tMsg]
  rw [parseMembers_last ts (n + 3) kMessage _ _ (.str M) _ isPlain_kMessage hm]
  rfl

theorem parseValue_herdrEnvelope (ts : Bool) (C M I : Str) (hC : isPlain C) (hM : isPlain M)
    (hI : isPlain I) (n : Nat) :
    parseValue ts (n + 8) (herdrEnvelope C M I) = some (herdrEnvelopeValue C M I, []) := by
  have hin := parseValue_inner ts C M I hC hM n
  have hi := parseValue_str ts (n + 4) I ('}' :: []) hI
  simp only [herdrEnvelope]
  rw [parseValue_obj, parseMembers_more ts (n + 6) kError _ _ _ [] isPlain_kError hin]
  simp only [tId]
  rw [parseMembers_last ts (n + 5) kId _ _ (.str I) _ isPlain_kId hi]
  rfl

theorem jsTrim_braced (s rest : Str) (h1 : s = '{' :: rest) (h2 : s.getLast? = some '}') :
    jsTrim s = s := by
  unfold jsTrim
  have e1 : dropWhileL jsWs s = s := by
    rw [h1]; simp only [dropWhileL]; rw [if_neg (by decide)]
  rw [e1]
  have h3 : s.reverse.head? = some '}' := by rw [List.head?_reverse]; exact h2
  cases hr : s.reverse with
  | nil => rw [hr] at h3; simp at h3
  | cons x w =>
    rw [hr] at h3
    simp only [List.head?_cons, Option.some.injEq] at h3
    subst h3
    have e2 : dropWhileL jsWs ('}' :: w) = '}' :: w := by
      simp only [dropWhileL]; rw [if_neg (by decide)]
    rw [e2, ← hr, List.reverse_reverse]

theorem herdrEnvelope_len (C M I : Str) : 8 ≤ (herdrEnvelope C M I).length := by
  simp [herdrEnvelope, kError]

def tIdInit (I : Str) : Str := '"' :: (kId ++ '"' :: ':' :: '"' :: (I ++ ['"']))
def tMsgInit (M I : Str) : Str :=
  '"' :: (kMessage ++ '"' :: ':' :: '"' :: (M ++ '"' :: '}' :: ',' :: tIdInit I))
def tCodeInit (C M I : Str) : Str := '"' :: (kCode ++ '"' :: ':' :: '"' :: (C ++ '"' :: ',' :: tMsgInit M I))
def envInit (C M I : Str) : Str := '{' :: '"' :: (kError ++ '"' :: ':' :: '{' :: tCodeInit C M I)

theorem herdrEnvelope_snoc (C M I : Str) : herdrEnvelope C M I = envInit C M I ++ ['}'] := by
  simp [herdrEnvelope, envInit, tCode, tCodeInit, tMsg, tMsgInit, tId, tIdInit]

theorem jsTrim_herdrEnvelope (C M I : Str) : jsTrim (herdrEnvelope C M I) = herdrEnvelope C M I :=
  jsTrim_braced _ _ rfl (by rw [herdrEnvelope_snoc]; simp)

theorem tsParsedCode_herdrEnvelope (C M I : Str) (hC : isPlain C) (hM : isPlain M) (hI : isPlain I) :
    tsParsedCode (herdrEnvelope C M I) = some (some C) := by
  obtain ⟨n, hn⟩ : ∃ n, 2 * (herdrEnvelope C M I).length + 2 = n + 8 :=
    ⟨2 * (herdrEnvelope C M I).length - 6, by have := herdrEnvelope_len C M I; omega⟩
  simp only [tsParsedCode, jsTrim_herdrEnvelope, jsonParse, hn, parseValue_herdrEnvelope true C M I hC hM hI n]
  simp +decide [skipWs, dropWhileL, jsErrorCode, jsGet, lookupFirst, herdrEnvelopeValue, kError, kCode,
    kMessage, kId, asStr]

theorem jsonErrorField_herdrEnvelope (C M I : Str) (hC : isPlain C) (hM : isPlain M) (hI : isPlain I) :
    jsonErrorField (herdrEnvelope C M I) "code".toList = C := by
  obtain ⟨n, hn⟩ : ∃ n, 2 * (herdrEnvelope C M I).length + 2 = n + 8 :=
    ⟨2 * (herdrEnvelope C M I).length - 6, by have := herdrEnvelope_len C M I; omega⟩
  simp only [jsonErrorField, ailDecode, hn, parseValue_herdrEnvelope false C M I hC hM hI n]
  simp +decide [ailGet, lookupFirst, herdrEnvelopeValue, kError, kCode, kMessage, kId, asStr]

theorem errPat_herdrEnvelope (C M I : Str) : containsL (herdrEnvelope C M I) errPat = true := by
  have he : errPat = ['{', '"', 'e', 'r', 'r', 'o', 'r', '"'] := by decide
  rw [he]
  simp +decide [herdrEnvelope, containsL, isPrefixL, kError]

/-- **P2.1 on herdr's full envelope, exactly.** `{"error":{"code":"C","message":"M"},"id":"I"}`
for every plain `C`, `M`, `I` with no "nested herdr" in it, and every positive exit code but 2:
the twins agree iff a `C` ending in `_not_found` is `agent_not_found`. -/
theorem p21_herdrEnvelope_iff (code : Int) (C M I : Str) (hexit : 0 < code) (h2 : code ≠ 2)
    (hC : isPlain C) (hM : isPlain M) (hI : isPlain I)
    (hnest : containsL (herdrEnvelope C M I) nestedPat = false) :
    herdrMeansAgentGone { code := code, stderr := herdrEnvelope C M I } =
        meansAgentGone code (herdrEnvelope C M I) ↔
      (endsWithL C notFound = true → C = agentNotFound) := by
  rw [ts_gone_pos code _ hexit h2, ail_gone_pos code _ (by omega) h2 hnest, errPat_herdrEnvelope]
  have htc : tsCode (herdrEnvelope C M I) = if C = [] then none else some C := by
    simp [tsCode, tsParsedCode_herdrEnvelope C M I hC hM hI]
  have hac : ailCode (herdrEnvelope C M I) = if C = [] then none else some C := by
    simp [ailCode, jsonErrorField_herdrEnvelope C M I hC hM hI]
  rw [htc, hac]
  by_cases hc0 : C = []
  · subst hc0; simp +decide [notFound]
  · simp only [hc0, if_false, Bool.true_and]
    by_cases ha : C = agentNotFound
    · subst ha; decide
    · have hb : (some C == some agentNotFound) = false := by simp [ha]
      rw [hb]
      cases endsWithL C notFound <;> simp [ha]

/-- **P2.2 on herdr's full envelope.** -/
theorem p22_herdrEnvelope (code : Int) (C M I : Str) (hexit : 0 < code)
    (hC : isPlain C) (hM : isPlain M) (hI : isPlain I)
    (hnest : containsL (herdrEnvelope C M I) nestedPat = false) :
    herdrFailureCode { code := code, stderr := herdrEnvelope C M I } =
      failureCode code (herdrEnvelope C M I) := by
  have htc : tsCode (herdrEnvelope C M I) = ailCode (herdrEnvelope C M I) := by
    simp only [tsCode, ailCode, tsParsedCode_herdrEnvelope C M I hC hM hI,
      jsonErrorField_herdrEnvelope C M I hC hM hI]
  exact p22_holds_under_H code _ hexit hnest (errPat_herdrEnvelope C M I)
    (by rw [tsParsedCode_herdrEnvelope C M I hC hM hI]; simp) htc

/-- Non-vacuity: wake-waiter.test.ts's `NOT_FOUND` stderr is this envelope and meets every
hypothesis. -/
theorem herdrEnvelope_nonvacuous :
    herdrEnvelope agentNotFound ['x'] ("cli:agent:get".toList) =
      "{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"},\"id\":\"cli:agent:get\"}".toList ∧
    isPlain agentNotFound ∧ isPlain ['x'] ∧ isPlain ("cli:agent:get".toList) ∧
    containsL (herdrEnvelope agentNotFound ['x'] ("cli:agent:get".toList)) nestedPat = false := by
  refine ⟨by decide +kernel, ?_, ?_, ?_, by decide +kernel⟩ <;>
  · intro ch h; revert ch; (try simp only [agentNotFound]); decide

/-! ### Non-vacuity: a concrete input satisfying every hypothesis -/

def canonical : Str := "{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}".toList
def canonicalTimeout : Str := "{\"error\":{\"code\":\"timeout\",\"message\":\"timed out\"}}".toList

theorem p21_nonvacuous :
    (0 : Int) < 1 ∧ containsL canonical nestedPat = false ∧
    (tsCode canonical ≠ none → containsL canonical errPat = true) ∧
    (containsL canonical errPat = true → tsCode canonical = ailCode canonical) ∧
    (∀ c, tsCode canonical = some c → endsWithL c notFound = true → c = agentNotFound) ∧
    herdrMeansAgentGone { code := 1, stderr := canonical } = true ∧
    meansAgentGone 1 canonical = true := by
  have ht : tsCode canonical = some agentNotFound := by decide +kernel
  refine ⟨by decide, by decide +kernel, fun _ => by decide +kernel, fun _ => by decide +kernel,
    ?_, by decide +kernel, by decide +kernel⟩
  intro c h _
  rw [ht] at h
  exact (Option.some.inj h).symm

theorem p22_nonvacuous :
    containsL canonicalTimeout nestedPat = false ∧ containsL canonicalTimeout errPat = true ∧
    tsParsedCode canonicalTimeout ≠ none ∧ tsCode canonicalTimeout = ailCode canonicalTimeout ∧
    herdrFailureCode { code := 1, stderr := canonicalTimeout } = "timeout".toList ∧
    failureCode 1 canonicalTimeout = "timeout".toList := by
  refine ⟨by decide +kernel, by decide +kernel, ?_, by decide +kernel, by decide +kernel,
    by decide +kernel⟩
  have : tsParsedCode canonicalTimeout = some (some "timeout".toList) := by decide +kernel
  rw [this]; simp

/-! ### Counterexamples (`bug_`), each reproduced on the real code by repro/ -/

/-- B2-T2-1. P2.1, `hnarrow`: TS's `endsWith("_not_found")` is wider than AILANG's
`== "agent_not_found"`. The failure codes agree (P2.2 holds here); only the verdict differs. -/
theorem bug_p21_suffix :
    let s := "{\"error\":{\"code\":\"pane_not_found\",\"message\":\"x\"}}".toList
    herdrMeansAgentGone { code := 1, stderr := s } = true ∧ meansAgentGone 1 s = false ∧
    herdrFailureCode { code := 1, stderr := s } = failureCode 1 s := by
  decide +kernel

/-- B2-T2-2. P2.1 and P2.2, `hnest`: herdr JSON whose message mentions "nested herdr". -/
theorem bug_p21_nested_in_message :
    let s := "{\"error\":{\"code\":\"agent_not_found\",\"message\":\"error: nested herdr is disabled by default.\"}}".toList
    herdrMeansAgentGone { code := 1, stderr := s } = true ∧ meansAgentGone 1 s = false ∧
    herdrFailureCode { code := 1, stderr := s } = "agent_not_found".toList ∧
    failureCode 1 s = "nested_herdr".toList := by
  decide +kernel

/-- B2-T2-3. P2.1 and P2.2, `hgate`: valid herdr JSON whose text does not contain `{"error"`. -/
theorem bug_p21_key_order :
    let s := "{\"id\":\"cli:agent:get\",\"error\":{\"code\":\"agent_not_found\"}}".toList
    herdrMeansAgentGone { code := 1, stderr := s } = true ∧ meansAgentGone 1 s = false ∧
    herdrFailureCode { code := 1, stderr := s } = "agent_not_found".toList ∧
    failureCode 1 s = "herdr_cli_rejected".toList := by
  decide +kernel

theorem bug_p21_spaced_json :
    let s := "{ \"error\": { \"code\": \"agent_not_found\" } }".toList
    herdrMeansAgentGone { code := 1, stderr := s } = true ∧ meansAgentGone 1 s = false ∧
    failureCode 1 s = "herdr_cli_rejected".toList := by
  decide +kernel

/-- B2-T2-4. P2.1 and P2.2, `hexit`: a negative exit code is "" (success) on the TS side and a
failure on the AILANG side. -/
theorem bug_p21_negative_exit :
    herdrMeansAgentGone { code := -1, stderr := canonical } = false ∧
    meansAgentGone (-1) canonical = true ∧
    herdrFailureCode { code := -1, stderr := canonical } = [] ∧
    failureCode (-1) canonical = "agent_not_found".toList := by
  decide +kernel

/-- B2-T2-5. P2.1 and P2.2, `hagree`: a duplicated `code` key; JSON.parse keeps the last,
AILANG's `get` the first. Both directions. -/
theorem bug_p21_duplicate_code_last :
    let s := "{\"error\":{\"code\":\"timeout\",\"code\":\"agent_not_found\"}}".toList
    herdrMeansAgentGone { code := 1, stderr := s } = true ∧ meansAgentGone 1 s = false ∧
    failureCode 1 s = "timeout".toList := by
  decide +kernel

theorem bug_p21_duplicate_code_first :
    let s := "{\"error\":{\"code\":\"agent_not_found\",\"code\":\"timeout\"}}".toList
    herdrMeansAgentGone { code := 1, stderr := s } = false ∧ meansAgentGone 1 s = true ∧
    herdrFailureCode { code := 1, stderr := s } = "timeout".toList := by
  decide +kernel

/-- B2-T2-6. P2.1 and P2.2, `hagree`: text after the JSON. AILANG's `decode` ignores it,
`JSON.parse` throws. -/
theorem bug_p21_trailing_text :
    let s := "{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"}}\nkilled by SIGTERM".toList
    herdrMeansAgentGone { code := 1, stderr := s } = false ∧ meansAgentGone 1 s = true ∧
    herdrFailureCode { code := 1, stderr := s } = "herdr_cli_rejected".toList ∧
    failureCode 1 s = "agent_not_found".toList := by
  decide +kernel

/-- B2-T2-7. P2.1 and P2.2, `hagree`: leading whitespace that `trim` strips and JSON does not
allow (U+00A0; U+FEFF, U+000B, U+000C, U+2028 and U+3000 behave the same). -/
theorem bug_p21_unicode_space :
    let s := (Char.ofNat 0xA0) :: canonical
    herdrMeansAgentGone { code := 1, stderr := s } = true ∧ meansAgentGone 1 s = false ∧
    failureCode 1 s = "herdr_json_undecodable".toList := by
  decide +kernel

/-- B2-T2-8. P2.2 only: a lone surrogate escape. JSON.parse keeps the UTF-16 unit (modelled as
U+F0000 + 0xD800), AILANG's `decode` writes U+FFFD. -/
theorem bug_p22_lone_surrogate :
    let s := "{\"error\":{\"code\":\"\\ud800\",\"message\":\"x\"}}".toList
    herdrFailureCode { code := 1, stderr := s } = [Char.ofNat (0xF0000 + 0xD800)] ∧
    failureCode 1 s = [Char.ofNat 0xFFFD] ∧
    herdrMeansAgentGone { code := 1, stderr := s } = meansAgentGone 1 s := by
  decide +kernel

/-- B2-T2-14. P2.1 and P2.2, `hagree`: a JSON number outside float64's range. JSON.parse reads
Infinity; AILANG's `decode` fails, so the code is lost. -/
theorem bug_p21_float_overflow :
    let s := "{\"error\":{\"code\":\"agent_not_found\",\"message\":\"x\"},\"n\":1e999}".toList
    herdrMeansAgentGone { code := 1, stderr := s } = true ∧ meansAgentGone 1 s = false ∧
    failureCode 1 s = "herdr_json_undecodable".toList := by
  decide +kernel

/-! K6: outside herdr's JSON the vocabularies differ (known; whether they should agree is open). -/

theorem bug_p22_k6_empty :
    herdrFailureCode { code := 1, stderr := [] } = "herdr_cli_rejected".toList ∧
    failureCode 1 [] = "herdr_failed_silently".toList := by
  decide +kernel

theorem bug_p22_k6_nested_plain :
    let s := "error: nested herdr is disabled by default.".toList
    herdrFailureCode { code := 1, stderr := s } = "herdr_cli_rejected".toList ∧
    failureCode 1 s = "nested_herdr".toList := by
  decide +kernel

theorem bug_p22_k6_bare_json :
    let s := "null".toList
    herdrFailureCode { code := 1, stderr := s } = "herdr_json_undecodable".toList ∧
    failureCode 1 s = "herdr_cli_rejected".toList := by
  decide +kernel

theorem bug_p22_k6_broken_json :
    let s := "{\"error\":".toList
    herdrFailureCode { code := 1, stderr := s } = "herdr_cli_rejected".toList ∧
    failureCode 1 s = "herdr_json_undecodable".toList := by
  decide +kernel

/-- X-1. `herdrFailureCode` is documented as `""` on success, yet a herdr child killed by a
signal (createHerdrRunner gives `code: -1`, wake-waiter.ts:514) gets the same `""`. -/
theorem bug_x1_killed_reads_as_success :
    herdrFailureCode { code := -1, stderr := "killed by SIGTERM".toList } = [] ∧
    herdrFailureCode { code := 0, stderr := [] } = [] ∧
    failureCode (-1) "killed by SIGTERM".toList = "herdr_cli_rejected".toList := by
  decide +kernel

/-! ## Axiom report -/

#print axioms ts_gone_pos
#print axioms ts_code_parsed
#print axioms ail_gone_pos
#print axioms ail_code_json
#print axioms both_cli_syntax
#print axioms p21_holds_under_H
#print axioms p22_holds_under_H
#print axioms p22_plain_text_agrees
#print axioms parseStrBody_plain
#print axioms envelope_eq
#print axioms dw_ne
#print axioms parseValue_str
#print axioms parseValue_obj
#print axioms parseMembers_one
#print axioms isPlain_kError
#print axioms isPlain_kCode
#print axioms envelope_cons
#print axioms parseValue_envelope
#print axioms jsTrim_envelope
#print axioms tsParsedCode_envelope
#print axioms jsonErrorField_envelope
#print axioms errPat_envelope
#print axioms tsCode_ailCode_envelope
#print axioms p21_envelope_iff
#print axioms p22_envelope
#print axioms envelope_nonvacuous
#print axioms parseMembers_last
#print axioms parseMembers_more
#print axioms isPlain_kMessage
#print axioms isPlain_kId
#print axioms herdrEnvelope_eq
#print axioms parseValue_inner
#print axioms parseValue_herdrEnvelope
#print axioms jsTrim_braced
#print axioms herdrEnvelope_len
#print axioms herdrEnvelope_snoc
#print axioms jsTrim_herdrEnvelope
#print axioms tsParsedCode_herdrEnvelope
#print axioms jsonErrorField_herdrEnvelope
#print axioms errPat_herdrEnvelope
#print axioms p21_herdrEnvelope_iff
#print axioms p22_herdrEnvelope
#print axioms herdrEnvelope_nonvacuous
#print axioms p21_nonvacuous
#print axioms p22_nonvacuous
#print axioms bug_p21_suffix
#print axioms bug_p21_nested_in_message
#print axioms bug_p21_key_order
#print axioms bug_p21_spaced_json
#print axioms bug_p21_negative_exit
#print axioms bug_p21_duplicate_code_last
#print axioms bug_p21_duplicate_code_first
#print axioms bug_p21_trailing_text
#print axioms bug_p21_unicode_space
#print axioms bug_p22_lone_surrogate
#print axioms bug_p21_float_overflow
#print axioms bug_p22_k6_empty
#print axioms bug_p22_k6_nested_plain
#print axioms bug_p22_k6_bare_json
#print axioms bug_p22_k6_broken_json
#print axioms bug_x1_killed_reads_as_success
