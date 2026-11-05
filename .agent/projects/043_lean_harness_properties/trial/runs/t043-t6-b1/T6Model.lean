/-
T6Model.lean — a Lean model of compose's output clipping, and the properties registered for it.

SOURCE: `packages/motoko-ext-compose/store.ail`, `func truncate_utf8_by_bytes`, lines 20-30 of
this snapshot (`/home/motoko/trial-043/s/t043-t6-b1/tree`). The task names lines 19-29; in the
snapshot the `func` line is 20 and the closing `}` is 30, one line later than registered. The
body, verbatim:

    func truncate_utf8_by_bytes(s: string, max_bytes: int) -> string {
      let b = fromString(s);
      let n = Str.length(s);
      if n <= max_bytes then s
      else {
        match slice(b, 0, max_bytes) {
          Some(x) => toString(x),
          None => ""
        }
      }
    }

with `fromString, length, slice, toString` from `std/bytes` and `Str` = `std/string`, AILANG
v0.54.14 (e1ef33f).

Lean 4.28.0, core only: no Mathlib, no Lake, no `sorry`, no `native_decide`.
Check with `lean T6Model.lean`; the `#print axioms` lines at the end are the axiom report.

WHAT THE MODEL KEEPS AND WHAT IT ABSTRACTS

  * An AILANG `string` is a Go string: a sequence of bytes, not necessarily valid UTF-8. The
    model's `Bytes` is `List Nat`; the differential test only ever feeds values 0..255. The
    theorems below quantify over all `List Nat`, which contains every real input.
  * `fromString` and `toString` are the identity on bytes. (`std/bytes.toString`'s docs say
    "Convert bytes to a UTF-8 string"; RESEARCH §7 reads the Go source as `string(b)` with no
    repair. The model follows §7; the differential test checks it on invalid inputs.)
  * `Str.length` is Go's `utf8.RuneCountInString` (RESEARCH §7): one per decoded rune, and one
    per byte of any invalid or truncated sequence. `decode1` is Go's first-byte table and
    accept ranges, transcribed.
  * `std/bytes.slice(b, start, end)` is modelled as Go-style `b[start:end]` guarded to
    `Some` iff `0 ≤ start ≤ end ≤ len b`, `None` otherwise. Only `start = 0` is ever used.
  * `max_bytes : int` is `Int` (AILANG ints are 64-bit; overflow is out of scope, see SUMMARY).

STATUS: see SUMMARY.md for the differential-test record (how often step 2 changed this model).
-/

namespace T6

abbrev Bytes := List Nat

/-! ## UTF-8, as Go's `unicode/utf8` decodes it -/

/-- Go's `first` table, reduced to the sequence size a lead byte announces; 0 = invalid lead. -/
def seqSize (c : Nat) : Nat :=
  if c < 0x80 then 1
  else if c < 0xC2 then 0
  else if c < 0xE0 then 2
  else if c < 0xF0 then 3
  else if c < 0xF5 then 4
  else 0

/-- Go's `acceptRanges` for the second byte. -/
def acceptLo (c : Nat) : Nat := if c = 0xE0 then 0xA0 else if c = 0xF0 then 0x90 else 0x80
def acceptHi (c : Nat) : Nat := if c = 0xED then 0x9F else if c = 0xF4 then 0x8F else 0xBF

def isCont (b : Nat) : Bool := decide (0x80 ≤ b) && decide (b ≤ 0xBF)

/-- Decode the first rune: `(valid, bytes consumed)`. On an invalid or short sequence Go
consumes exactly one byte (`RuneError`, size 1). -/
def decode1 : Bytes → Bool × Nat
  | [] => (false, 0)
  | c :: t =>
    let sz := seqSize c
    if sz = 1 then (true, 1)
    else if sz = 0 then (false, 1)
    else if t.length + 1 < sz then (false, 1)
    else match t with
      | [] => (false, 1)
      | b1 :: t1 =>
        if ¬ (acceptLo c ≤ b1 ∧ b1 ≤ acceptHi c) then (false, 1)
        else if sz = 2 then (true, 2)
        else match t1 with
          | [] => (false, 1)
          | b2 :: t2 =>
            if isCont b2 = false then (false, 1)
            else if sz = 3 then (true, 3)
            else match t2 with
              | [] => (false, 1)
              | b3 :: _ => if isCont b3 = false then (false, 1) else (true, 4)

/-- `utf8.RuneCountInString`, with fuel (structural on the fuel, so the kernel can evaluate it).
The tail after a rune of size `d` is `t.drop (d - 1)`. -/
def runeCountF : Nat → Bytes → Nat
  | 0, _ => 0
  | _, [] => 0
  | k + 1, c :: t => 1 + runeCountF k (t.drop ((decode1 (c :: t)).2 - 1))

def runeCount (s : Bytes) : Nat := runeCountF s.length s

/-- `utf8.ValidString`. -/
def validF : Nat → Bytes → Bool
  | 0, _ => true
  | _, [] => true
  | k + 1, c :: t => (decode1 (c :: t)).1 && validF k (t.drop ((decode1 (c :: t)).2 - 1))

def valid (s : Bytes) : Bool := validF s.length s

/-! ## The builtins `truncate_utf8_by_bytes` calls -/

def fromString (s : Bytes) : Bytes := s          -- std/bytes.fromString: []byte(s)
def toString (b : Bytes) : Bytes := b            -- std/bytes.toString:   string(b), no repair
def strLength (s : Bytes) : Nat := runeCount s   -- std/string.length:    RuneCountInString

/-- std/bytes.slice(b, start, end). -/
def slice (b : Bytes) (st en : Int) : Option Bytes :=
  if 0 ≤ st ∧ st ≤ en ∧ en ≤ (b.length : Int) then
    some ((b.drop st.toNat).take (en - st).toNat)
  else none

/-! ## The function -/

/-- `truncate_utf8_by_bytes`, line for line. -/
def truncate (s : Bytes) (maxBytes : Int) : Bytes :=
  let b := fromString s
  let n := strLength s
  if (n : Int) ≤ maxBytes then s
  else
    match slice b 0 maxBytes with
    | some x => toString x
    | none => []

/-! ## Lemmas -/

theorem runeCountF_le (k : Nat) (s : Bytes) : runeCountF k s ≤ s.length := by
  induction k generalizing s with
  | zero => simp [runeCountF]
  | succ k ih =>
    cases s with
    | nil => simp [runeCountF]
    | cons c t =>
      simp only [runeCountF, List.length_cons]
      have h := ih (t.drop ((decode1 (c :: t)).2 - 1))
      simp only [List.length_drop] at h
      omega

theorem runeCount_le_length (s : Bytes) : runeCount s ≤ s.length :=
  runeCountF_le _ _

/-- When the rune count exceeds a non-negative cap, the else branch's `slice` succeeds and
returns the first `maxBytes` bytes. -/
theorem truncate_else {s : Bytes} {m : Int} (hm : 0 ≤ m) (h : ¬ ((runeCount s : Int) ≤ m)) :
    truncate s m = s.take m.toNat := by
  have hle := runeCount_le_length s
  unfold truncate
  simp only [strLength, fromString, toString, slice]
  rw [if_neg h, if_pos (by omega)]
  simp

theorem truncate_neg {s : Bytes} {m : Int} (hm : m < 0) : truncate s m = [] := by
  unfold truncate
  simp only [strLength, fromString, toString, slice]
  rw [if_neg (by omega), if_neg (by omega)]

/-! ## P6.1 — for `n ≥ 0`, the result's byte length is at most `n`. FALSE. -/

/-- P6.1 fails exactly when the cap lies between the rune count and the byte count: the
"fits" test counts runes (`Str.length`) and the cap is in bytes. -/
theorem p61_iff (s : Bytes) (m : Int) (hm : 0 ≤ m) :
    ((truncate s m).length : Int) ≤ m ↔ ((s.length : Int) ≤ m ∨ m < (runeCount s : Int)) := by
  by_cases h : (runeCount s : Int) ≤ m
  · have : truncate s m = s := by
      unfold truncate; simp only [strLength]; rw [if_pos h]
    rw [this]; omega
  · rw [truncate_else hm h]
    have hle := runeCount_le_length s
    simp only [List.length_take]
    omega

/-- Counterexample to P6.1: `"é"` (U+00E9, bytes C3 A9; one rune, two bytes) with cap 1 comes
back whole, two bytes. -/
theorem bug_P6_1_two_byte : truncate [0xC3, 0xA9] 1 = [0xC3, 0xA9] ∧
    ¬ (((truncate [0xC3, 0xA9] 1).length : Int) ≤ 1) := by
  decide

/-- The same at the call site's scale: `"€€€€"` (12 bytes, 4 runes) against cap 4. -/
theorem bug_P6_1_euro :
    ((truncate [0xE2,0x82,0xAC, 0xE2,0x82,0xAC, 0xE2,0x82,0xAC, 0xE2,0x82,0xAC] 4).length) = 12 := by
  decide

/-- A general witness family: for any non-empty `s` whose rune count is below its byte count,
cap `runeCount s` violates P6.1. -/
theorem bug_P6_1_family (s : Bytes) (h : runeCount s < s.length) :
    ¬ (((truncate s (runeCount s)).length : Int) ≤ (runeCount s : Int)) := by
  rw [p61_iff s _ (by omega)]
  omega

/-- P6.1 does hold where runes and bytes agree (e.g. ASCII), and on the else branch. -/
theorem p61_of_count_eq (s : Bytes) (m : Int) (hm : 0 ≤ m) (h : runeCount s = s.length) :
    ((truncate s m).length : Int) ≤ m := by
  rw [p61_iff s m hm]; omega

/-! ## P6.2 — the result is a byte prefix of the input, and the input is returned unchanged when
it fits. PROVED (for every `Int` cap, not only `n ≥ 0`). -/

theorem p62_prefix (s : Bytes) (m : Int) : truncate s m <+: s := by
  by_cases h : (runeCount s : Int) ≤ m
  · have : truncate s m = s := by
      unfold truncate; simp only [strLength]; rw [if_pos h]
    rw [this]; exact List.prefix_refl s
  · by_cases hm : 0 ≤ m
    · rw [truncate_else hm h]; exact List.take_prefix _ _
    · rw [truncate_neg (by omega)]; exact List.nil_prefix

theorem p62_fits (s : Bytes) (m : Int) (h : (s.length : Int) ≤ m) : truncate s m = s := by
  have hle := runeCount_le_length s
  unfold truncate; simp only [strLength]
  rw [if_pos (by omega)]

/-! ## P6.3 — valid UTF-8 in, valid UTF-8 out. FALSE (known, K2). -/

/-- `"éé"` (C3 A9 C3 A9) with cap 1: two runes exceed the cap, so the else branch slices one
byte, C3, a lead byte with no continuation. -/
theorem bug_P6_3 : valid [0xC3, 0xA9, 0xC3, 0xA9] = true ∧
    truncate [0xC3, 0xA9, 0xC3, 0xA9] 1 = [0xC3] ∧
    valid (truncate [0xC3, 0xA9, 0xC3, 0xA9] 1) = false := by
  decide

/-! ## Satisfiability witnesses for the proved theorems' hypotheses (none is vacuous) -/

theorem witness_p61_iff_hyp : (0 : Int) ≤ 1 ∧ runeCount [0xC3, 0xA9] = 1 := by decide
theorem witness_p62_fits_hyp : (([0x61, 0x62] : Bytes).length : Int) ≤ 2 ∧
    truncate [0x61, 0x62] 2 = [0x61, 0x62] := by decide
theorem witness_family_hyp : runeCount [0xC3, 0xA9] < ([0xC3, 0xA9] : Bytes).length := by decide

/-! ## Step 8: the fix, stated and proved in the model

Count the cap's own unit: compare the BYTE length, `length(b)` from `std/bytes` (already
imported by store.ail), instead of `Str.length(s)`. This restores P6.1 and keeps P6.2. It does
not address P6.3 (K2), which needs a cut on a rune boundary. -/

def truncateFix (s : Bytes) (maxBytes : Int) : Bytes :=
  let b := fromString s
  let n := b.length
  if (n : Int) ≤ maxBytes then s
  else
    match slice b 0 maxBytes with
    | some x => toString x
    | none => []

theorem fix_p61 (s : Bytes) (m : Int) (hm : 0 ≤ m) : ((truncateFix s m).length : Int) ≤ m := by
  unfold truncateFix
  simp only [fromString, toString, slice]
  by_cases h : (s.length : Int) ≤ m
  · rw [if_pos h]; exact h
  · rw [if_neg h, if_pos (by omega)]
    simp only [List.length_take]
    omega

theorem fix_p62_prefix (s : Bytes) (m : Int) : truncateFix s m <+: s := by
  unfold truncateFix
  simp only [fromString, toString, slice]
  by_cases h : (s.length : Int) ≤ m
  · rw [if_pos h]; exact List.prefix_refl s
  · rw [if_neg h]
    by_cases hm : 0 ≤ m
    · rw [if_pos (by omega)]; exact List.take_prefix _ _
    · rw [if_neg (by omega)]; exact List.nil_prefix

theorem fix_p62_fits (s : Bytes) (m : Int) (h : (s.length : Int) ≤ m) : truncateFix s m = s := by
  unfold truncateFix; simp only [fromString]; rw [if_pos h]

/-- The fix agrees with the original wherever the original already met P6.1. -/
theorem fix_agrees_when_p61 (s : Bytes) (m : Int) (hm : 0 ≤ m)
    (h : ((truncate s m).length : Int) ≤ m) : truncateFix s m = truncate s m := by
  have hle := runeCount_le_length s
  rw [p61_iff s m hm] at h
  by_cases hs : (s.length : Int) ≤ m
  · rw [fix_p62_fits s m hs, p62_fits s m hs]
  · have hr : ¬ ((runeCount s : Int) ≤ m) := by omega
    rw [truncate_else hm hr]
    unfold truncateFix
    simp only [fromString, toString, slice]
    rw [if_neg hs, if_pos (by omega)]
    simp

/-- The fix still breaks P6.3 on the same input (K2 is a separate defect). -/
theorem bug_fix_P6_3 : valid (truncateFix [0xC3, 0xA9, 0xC3, 0xA9] 1) = false := by decide

end T6

/-! ## Axiom report -/
#print axioms T6.runeCountF_le
#print axioms T6.runeCount_le_length
#print axioms T6.truncate_else
#print axioms T6.truncate_neg
#print axioms T6.p61_iff
#print axioms T6.bug_P6_1_two_byte
#print axioms T6.bug_P6_1_euro
#print axioms T6.bug_P6_1_family
#print axioms T6.p61_of_count_eq
#print axioms T6.p62_prefix
#print axioms T6.p62_fits
#print axioms T6.bug_P6_3
#print axioms T6.witness_p61_iff_hyp
#print axioms T6.witness_p62_fits_hyp
#print axioms T6.witness_family_hyp
#print axioms T6.fix_p61
#print axioms T6.fix_p62_prefix
#print axioms T6.fix_p62_fits
#print axioms T6.fix_agrees_when_p61
#print axioms T6.bug_fix_P6_3
