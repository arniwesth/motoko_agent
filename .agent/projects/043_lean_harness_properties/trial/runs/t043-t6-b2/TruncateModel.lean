/-
TruncateModel.lean — T6, compose's output clipping.

Source modelled (snapshot at /home/motoko/trial-043/s/t043-t6-b2/tree):

  * `truncate_utf8_by_bytes`   packages/motoko-ext-compose/store.ail:20-30
      (registered as :19-29; the snapshot's body starts one line later, at :20)
  * `store_stdout_and_elide`   packages/motoko-ext-compose/store.ail:32-49
      (its only caller; only the parts that decide the returned `stdout` and
      `truncated` are modelled: the ports' writes do not reach either field)

Lean 4.28.0, core only: no Mathlib, no Lake. `lean TruncateModel.lean`.
No `sorry`, no `native_decide`. `#print axioms` for every theorem at the end.

What the model keeps and what it abstracts:

  * An AILANG `string` is a Go string: a sequence of BYTES, not necessarily valid
    UTF-8 (RESEARCH §7: `std/bytes.toString` is `string(b)` with no repair, and
    process output enters this way). So a string is modelled as `List Nat`, one
    element per byte. Lean's own `String` cannot hold invalid UTF-8 and is not used.
  * `std/bytes.fromString` is the identity on that representation; `toString` is the
    identity too (no U+FFFD repair).
  * `std/string.length` (`Str.length`) is `_str_len`, i.e. Go's
    `utf8.RuneCountInString` (RESEARCH §7, `internal/eval/builtins_string.go:77-86`):
    one per decoded rune, one per invalid byte. Modelled by `runeCount`, which follows
    Go's `DecodeRuneInString` acceptance table.
  * `std/bytes.slice(b, lo, hi)` returns `Some(b[lo:hi])` when 0 <= lo <= hi <= len,
    else `None` (assumed; the differential test checks it on this call shape).
  * `int` is modelled as `Int` (unbounded): the source's ints are 64-bit; overflow is
    out of scope (no arithmetic on `max_bytes` happens in these functions).
  * `store_stdout_and_elide`'s notice is a parameter: the bytes of
    "\n[stdout elided; full output at ${raw_path}]".

HISTORY OF STEP (2): ZERO model changes. This model was written before any execution
(history/TruncateModel.v0.lean). Its first comparison with the real code (diff/run_diff.sh,
30,375 cases, two routes) gave 0 mismatches, and the decoder, `bytesSlice`, `truncate` and
`storeElide` are byte-identical to v0. Five mutants of this model are each caught by the
same test (diff/mutants/). Checked 2026-11-04 with Lean 4.28.0: 37 theorems, axioms in
../axioms.txt, none on `sorryAx` or `Lean.ofReduceBool`.
-/

namespace T6

abbrev Bytes := List Nat

/-! ## Go's UTF-8 decoder, as `RuneCountInString` and `ValidString` use it -/

/-- Number of bytes in the sequence a lead byte announces (0 if it is not a lead byte). -/
def seqLen (b0 : Nat) : Nat :=
  if b0 < 0x80 then 1
  else if 0xC2 ≤ b0 ∧ b0 ≤ 0xDF then 2
  else if 0xE0 ≤ b0 ∧ b0 ≤ 0xEF then 3
  else if 0xF0 ≤ b0 ∧ b0 ≤ 0xF4 then 4
  else 0

/-- Allowed range of the FIRST continuation byte after `b0` (Go's `acceptRanges`). -/
def firstLo (b0 : Nat) : Nat :=
  if b0 = 0xE0 then 0xA0 else if b0 = 0xF0 then 0x90 else 0x80
def firstHi (b0 : Nat) : Nat :=
  if b0 = 0xED then 0x9F else if b0 = 0xF4 then 0x8F else 0xBF

def isCont (b : Nat) : Bool := 0x80 ≤ b && b ≤ 0xBF

/-- Do the `k` bytes after the lead form a valid tail? `k` = seqLen - 1. -/
def tailOk (b0 : Nat) : Nat → Bytes → Bool
  | 0, _ => true
  | _ + 1, [] => false
  | k + 1, b1 :: rest =>
      (firstLo b0 ≤ b1 && b1 ≤ firstHi b0) && (rest.take k).length == k && (rest.take k).all isCont

/-- Is the head of `b0 :: rest` a full, valid UTF-8 sequence? -/
def decodeOk (b0 : Nat) (rest : Bytes) : Bool :=
  match seqLen b0 with
  | 0 => false
  | 1 => true
  | n + 1 => tailOk b0 n rest

/-- Width Go's decoder consumes at the head: the sequence length if valid, else 1. -/
def width (b0 : Nat) (rest : Bytes) : Nat :=
  if decodeOk b0 rest then seqLen b0 else 1

def runeCountAux : Nat → Bytes → Nat
  | 0, _ => 0
  | _ + 1, [] => 0
  | f + 1, b :: rest => 1 + runeCountAux f ((b :: rest).drop (width b rest))

/-- `_str_len` = `utf8.RuneCountInString`. Fuel = length suffices: each step eats >= 1 byte. -/
def runeCount (s : Bytes) : Nat := runeCountAux s.length s

def validAux : Nat → Bytes → Bool
  | 0, l => l.isEmpty
  | _ + 1, [] => true
  | f + 1, b :: rest => decodeOk b rest && validAux f ((b :: rest).drop (width b rest))

/-- `utf8.ValidString`. -/
def valid (s : Bytes) : Bool := validAux s.length s

/-! ## `std/bytes` -/

def bytesSlice (b : Bytes) (lo hi : Int) : Option Bytes :=
  if 0 ≤ lo ∧ lo ≤ hi ∧ hi ≤ (b.length : Int) then
    some ((b.drop lo.toNat).take (hi - lo).toNat)
  else none

/-! ## The functions under test -/

/-- `truncate_utf8_by_bytes`, store.ail:20-30, line for line. -/
def truncate (s : Bytes) (maxBytes : Int) : Bytes :=
  let b := s                          -- let b = fromString(s);
  let n : Int := runeCount s          -- let n = Str.length(s);
  if n ≤ maxBytes then s              -- if n <= max_bytes then s
  else
    match bytesSlice b 0 maxBytes with
    | some x => x                     -- Some(x) => toString(x)
    | none => []                      -- None => ""

/-- The two fields of `store_stdout_and_elide`'s result that the clipping decides,
store.ail:37-48. `notice` is the bytes of "\n[stdout elided; full output at ${raw_path}]". -/
def storeElide (stdout : Bytes) (maxStdoutBytes : Int) (notice : Bytes) : Bytes × Bool :=
  let outBytes : Int := stdout.length
  if outBytes > maxStdoutBytes then (truncate stdout maxStdoutBytes ++ notice, true)
  else (stdout, false)

/-! ## Lemmas -/

theorem seqLen_pos_of_decodeOk (b : Nat) (rest : Bytes) (h : decodeOk b rest = true) :
    1 ≤ seqLen b := by
  unfold decodeOk at h
  cases hs : seqLen b with
  | zero => simp [hs] at h
  | succ n => omega

theorem width_pos (b : Nat) (rest : Bytes) : 1 ≤ width b rest := by
  unfold width
  split
  · exact seqLen_pos_of_decodeOk b rest ‹_›
  · exact Nat.le_refl 1

theorem runeCountAux_le (f : Nat) (l : Bytes) : runeCountAux f l ≤ l.length := by
  induction f generalizing l with
  | zero => simp [runeCountAux]
  | succ f ih =>
    cases l with
    | nil => simp [runeCountAux]
    | cons b rest =>
      simp only [runeCountAux]
      have h1 := ih ((b :: rest).drop (width b rest))
      have h2 := width_pos b rest
      simp only [List.length_drop, List.length_cons] at h1 ⊢
      omega

theorem runeCount_le_length (s : Bytes) : runeCount s ≤ s.length :=
  runeCountAux_le _ _

/-! ## P6.2 — prefix, and unchanged when it fits: PROVED -/

theorem take_prefix (l : Bytes) (k : Nat) : l.take k <+: l := List.take_prefix k l

/-- P6.2, first half: the result's bytes are a prefix of the input's bytes, for every
input (valid UTF-8 or not) and every `max_bytes` (negative included). -/
theorem p6_2_prefix (s : Bytes) (n : Int) : truncate s n <+: s := by
  unfold truncate bytesSlice
  simp only
  split
  · exact List.prefix_refl s
  · split
    · rename_i x hx
      split at hx
      · simp only [Option.some.injEq] at hx
        subst hx
        simp only [Int.toNat_zero, List.drop_zero]
        exact List.take_prefix _ _
      · simp at hx
    · exact List.nil_prefix

/-- P6.2, second half: an input whose byte length is at most `n` is returned unchanged. -/
theorem p6_2_fits (s : Bytes) (n : Int) (h : (s.length : Int) ≤ n) : truncate s n = s := by
  unfold truncate
  have := runeCount_le_length s
  simp only
  rw [if_pos (by omega)]

/-! ## P6.1 — byte length at most n: FALSE -/

/-- Where P6.1 does hold: whenever the rune count exceeds `n >= 0`, the slice is taken
and the result has exactly `n` bytes. -/
theorem p6_1_when_runes_exceed (s : Bytes) (n : Int) (hn : 0 ≤ n)
    (h : n < (runeCount s : Int)) : (truncate s n).length = n.toNat := by
  have hle := runeCount_le_length s
  unfold truncate bytesSlice
  simp only
  rw [if_neg (by omega)]
  rw [if_pos (by omega)]
  simp only [Int.toNat_zero, List.drop_zero, List.length_take, Int.sub_zero]
  omega

/-- The exact failure set of P6.1: for `n >= 0`, the result is over budget iff the rune
count fits `n` but the byte length does not. -/
theorem p6_1_fails_iff (s : Bytes) (n : Int) (hn : 0 ≤ n) :
    n < ((truncate s n).length : Int) ↔ ((runeCount s : Int) ≤ n ∧ n < (s.length : Int)) := by
  constructor
  · intro h
    by_cases hr : (runeCount s : Int) ≤ n
    · refine ⟨hr, ?_⟩
      unfold truncate at h
      simp only at h
      rw [if_pos hr] at h
      exact h
    · have := p6_1_when_runes_exceed s n hn (by omega)
      omega
  · rintro ⟨hr, hl⟩
    unfold truncate
    simp only
    rw [if_pos hr]
    exact hl

/-- Counterexample to P6.1: "é" (C3 A9, one rune, two bytes) with `max_bytes = 1` comes
back whole, two bytes. -/
theorem bug_p6_1_e_acute : truncate [0xC3, 0xA9] 1 = [0xC3, 0xA9] ∧
    ¬ (((truncate [0xC3, 0xA9] 1).length : Int) ≤ 1) := by decide

/-- The same at compose's default cap. A family: k copies of "é" (2k bytes, k runes) come
back whole for every `max_bytes` with k <= max_bytes < 2k; k = 2001 and the default
`max_stdout_bytes = 4000` (compose.ail:851) is one member. -/
def eAcutes : Nat → Bytes
  | 0 => []
  | k + 1 => 0xC3 :: 0xA9 :: eAcutes k

theorem eAcutes_length (k : Nat) : (eAcutes k).length = 2 * k := by
  induction k with
  | zero => rfl
  | succ k ih => simp [eAcutes, ih]; omega

theorem runeCountAux_eAcutes (k f : Nat) (hf : k ≤ f) : runeCountAux f (eAcutes k) = k := by
  induction k generalizing f with
  | zero => cases f <;> rfl
  | succ k ih =>
    cases f with
    | zero => omega
    | succ f =>
      have hw : width 0xC3 (0xA9 :: eAcutes k) = 2 := by
        simp [width, decodeOk, seqLen, tailOk, firstLo, firstHi]
      simp only [eAcutes, runeCountAux, hw, List.drop_succ_cons, List.drop_zero]
      rw [ih f (by omega)]
      omega

theorem runeCount_eAcutes (k : Nat) : runeCount (eAcutes k) = k := by
  unfold runeCount
  rw [eAcutes_length]
  exact runeCountAux_eAcutes k (2 * k) (by omega)

theorem bug_p6_1_family (k : Nat) (m : Int) (h1 : (k : Int) ≤ m) (h2 : m < 2 * (k : Int)) :
    truncate (eAcutes k) m = eAcutes k ∧ m < ((truncate (eAcutes k) m).length : Int) := by
  have hr := runeCount_eAcutes k
  have hl := eAcutes_length k
  have heq : truncate (eAcutes k) m = eAcutes k := by
    unfold truncate; simp only; rw [if_pos (by omega)]
  refine ⟨heq, ?_⟩
  rw [heq, hl]; omega

theorem bug_p6_1_default_cap :
    truncate (eAcutes 2001) 4000 = eAcutes 2001 ∧
    (4000 : Int) < ((truncate (eAcutes 2001) 4000).length : Int) :=
  bug_p6_1_family 2001 4000 (by omega) (by omega)

/-- At the caller: `store_stdout_and_elide` reports `truncated = true` and puts the notice
on, but the "clipped" part is the whole output. "éé" (4 bytes, 2 runes), cap 3. -/
theorem bug_store_elide_keeps_whole_output (notice : Bytes) :
    storeElide [0xC3, 0xA9, 0xC3, 0xA9] 3 notice = ([0xC3, 0xA9, 0xC3, 0xA9] ++ notice, true) := by
  simp only [storeElide]
  rw [if_pos (by decide)]
  have : truncate [0xC3, 0xA9, 0xC3, 0xA9] 3 = [0xC3, 0xA9, 0xC3, 0xA9] := by decide
  rw [this]

/-- P6.1 does hold on input whose every byte is ASCII (rune count = byte length). -/
def asciiOnly (s : Bytes) : Bool := s.all (· < 0x80)

theorem runeCountAux_ascii (f : Nat) (s : Bytes) (h : asciiOnly s = true) (hf : s.length ≤ f) :
    runeCountAux f s = s.length := by
  induction f generalizing s with
  | zero => cases s <;> simp_all [runeCountAux]
  | succ f ih =>
    cases s with
    | nil => rfl
    | cons b rest =>
      simp only [asciiOnly, List.all_cons, Bool.and_eq_true, decide_eq_true_eq] at h
      have hw : width b rest = 1 := by simp [width, decodeOk, seqLen, h.1]
      simp only [runeCountAux, hw, List.drop_succ_cons, List.drop_zero, List.length_cons]
      rw [ih rest (by simpa [asciiOnly] using h.2) (by simp at hf; omega)]
      omega

theorem p6_1_ascii (s : Bytes) (n : Int) (hn : 0 ≤ n) (h : asciiOnly s = true) :
    ((truncate s n).length : Int) ≤ n := by
  have hr : runeCount s = s.length := runeCountAux_ascii _ s h (Nat.le_refl _)
  have := (p6_1_fails_iff s n hn)
  by_cases hc : n < ((truncate s n).length : Int)
  · have := this.mp hc; omega
  · omega

/-! ### How far over: at most four times the cap, and four times is reached -/

theorem seqLen_le_four (b : Nat) : seqLen b ≤ 4 := by
  unfold seqLen; split <;> (try split) <;> (try split) <;> (try split) <;> omega

theorem width_le_four (b : Nat) (rest : Bytes) : width b rest ≤ 4 := by
  unfold width; split
  · exact seqLen_le_four b
  · omega

theorem length_le_four_runeCountAux (f : Nat) (l : Bytes) (hf : l.length ≤ f) :
    l.length ≤ 4 * runeCountAux f l := by
  induction f generalizing l with
  | zero => cases l <;> simp_all [runeCountAux]
  | succ f ih =>
    cases l with
    | nil => simp [runeCountAux]
    | cons b rest =>
      simp only [runeCountAux]
      have hw1 := width_pos b rest
      have hw4 := width_le_four b rest
      have hd : ((b :: rest).drop (width b rest)).length ≤ f := by
        simp only [List.length_drop, List.length_cons] at hf ⊢; omega
      have h1 := ih _ hd
      simp only [List.length_drop, List.length_cons] at h1 ⊢
      omega

/-- The overshoot is bounded: for `n >= 0` the result is never more than `4 * n` bytes. -/
theorem p6_1_overshoot_le_four (s : Bytes) (n : Int) (hn : 0 ≤ n) :
    ((truncate s n).length : Int) ≤ 4 * n := by
  have h4 : s.length ≤ 4 * runeCount s := length_le_four_runeCountAux _ s (Nat.le_refl _)
  by_cases hr : (runeCount s : Int) ≤ n
  · unfold truncate; simp only; rw [if_pos hr]; omega
  · have := p6_1_when_runes_exceed s n hn (by omega); omega

/-- ... and the bound is reached: one emoji (F0 9F 98 80) under a cap of 1 comes back whole. -/
theorem bug_p6_1_fourfold :
    truncate [0xF0, 0x9F, 0x98, 0x80] 1 = [0xF0, 0x9F, 0x98, 0x80] := by decide

/-! ## P6.3 — valid UTF-8 in, valid UTF-8 out: FALSE (registered as known, K2) -/

/-- "éa" (C3 A9 61) is valid; with `max_bytes = 1` the result is the lone lead byte C3. -/
theorem bug_p6_3_split_char :
    valid [0xC3, 0xA9, 0x61] = true ∧
    truncate [0xC3, 0xA9, 0x61] 1 = [0xC3] ∧
    valid (truncate [0xC3, 0xA9, 0x61] 1) = false := by decide

/-! ## Non-vacuity: every hypothesis above is satisfiable -/

/-- One concrete input per hypothesised theorem, meeting all its hypotheses:
`p6_1_when_runes_exceed` ("éa", 1: two runes > 1), `p6_2_fits` ("é", 2: two bytes <= 2),
`p6_1_ascii` ("abcd", 2), `p6_1_fails_iff`'s right side ("é", 1), `bug_p6_1_family`
(k = 2001, m = 4000: see `bug_p6_1_default_cap`). -/
theorem hyps_satisfiable :
    ((1 : Int) < (runeCount [0xC3, 0xA9, 0x61] : Int)) ∧
    (([0xC3, 0xA9] : Bytes).length : Int) ≤ 2 ∧
    asciiOnly [0x61, 0x62, 0x63, 0x64] = true ∧
    ((runeCount [0xC3, 0xA9] : Int) ≤ 1 ∧ (1 : Int) < (([0xC3, 0xA9] : Bytes).length : Int)) ∧
    ((2001 : Int) ≤ 4000 ∧ (4000 : Int) < 2 * 2001) := by decide

/-! ## The one-line fix: compare BYTE length (`length(b)`, already imported, as the caller
does at store.ail:37). It closes P6.1 and keeps P6.2; P6.3 stays open (K2). -/

def truncateByteCap (s : Bytes) (maxBytes : Int) : Bytes :=
  if (s.length : Int) ≤ maxBytes then s
  else match bytesSlice s 0 maxBytes with
    | some x => x
    | none => []

theorem byteCap_p6_1 (s : Bytes) (n : Int) (hn : 0 ≤ n) :
    ((truncateByteCap s n).length : Int) ≤ n := by
  unfold truncateByteCap
  by_cases h : (s.length : Int) ≤ n
  · rw [if_pos h]; exact h
  · rw [if_neg h]; unfold bytesSlice; rw [if_pos (by omega)]
    simp only [Int.toNat_zero, List.drop_zero, Int.sub_zero, List.length_take]
    omega

theorem byteCap_p6_2_prefix (s : Bytes) (n : Int) : truncateByteCap s n <+: s := by
  unfold truncateByteCap bytesSlice
  split
  · exact List.prefix_refl s
  · split
    · rename_i x hx
      split at hx
      · simp only [Option.some.injEq] at hx
        subst hx
        simp only [Int.toNat_zero, List.drop_zero]
        exact List.take_prefix _ _
      · simp at hx
    · exact List.nil_prefix

theorem byteCap_p6_2_fits (s : Bytes) (n : Int) (h : (s.length : Int) ≤ n) :
    truncateByteCap s n = s := by
  unfold truncateByteCap; rw [if_pos h]

/-- The real function and the one-line fix differ exactly on P6.1's failure set. -/
theorem truncate_ne_byteCap_iff (s : Bytes) (n : Int) (hn : 0 ≤ n) :
    truncate s n ≠ truncateByteCap s n ↔ ((runeCount s : Int) ≤ n ∧ n < (s.length : Int)) := by
  have hle := runeCount_le_length s
  unfold truncate truncateByteCap
  simp only
  constructor
  · intro h
    by_cases hr : (runeCount s : Int) ≤ n
    · refine ⟨hr, ?_⟩
      by_cases hl : (s.length : Int) ≤ n
      · rw [if_pos hr, if_pos hl] at h; exact absurd rfl h
      · omega
    · by_cases hl : (s.length : Int) ≤ n
      · omega
      · rw [if_neg hr, if_neg hl] at h; exact absurd rfl h
  · rintro ⟨hr, hl⟩
    rw [if_pos hr, if_neg (by omega), bytesSlice, if_pos (by omega)]
    simp only [Int.toNat_zero, List.drop_zero, Int.sub_zero]
    intro heq
    have := congrArg List.length heq
    simp only [List.length_take] at this
    omega

theorem bug_byteCap_p6_3 :
    valid [0xC3, 0xA9, 0x61] = true ∧ truncateByteCap [0xC3, 0xA9, 0x61] 1 = [0xC3] ∧
    valid (truncateByteCap [0xC3, 0xA9, 0x61] 1) = false := by decide

/-! ## The full fix, stated and proved: compare BYTE length, then back off to a rune boundary -/

/-- Largest k <= n such that the first k bytes are valid... the simple, total form: drop
trailing bytes until the prefix is valid (at most 3 for valid input, by UTF-8 structure;
for invalid input it may go further). -/
def backoff : Nat → Bytes → Bytes
  | 0, p => if valid p then p else []
  | f + 1, p => if valid p then p else backoff f p.dropLast

def truncateFixed (s : Bytes) (maxBytes : Int) : Bytes :=
  if (s.length : Int) ≤ maxBytes then s
  else match bytesSlice s 0 maxBytes with
    | some x => backoff x.length x
    | none => []

theorem backoff_prefix (f : Nat) (p : Bytes) : backoff f p <+: p := by
  induction f generalizing p with
  | zero => simp only [backoff]; split
            · exact List.prefix_refl p
            · exact List.nil_prefix
  | succ f ih =>
    simp only [backoff]; split
    · exact List.prefix_refl p
    · exact (ih p.dropLast).trans (List.dropLast_prefix p)

theorem backoff_valid (f : Nat) (p : Bytes) : valid (backoff f p) = true := by
  induction f generalizing p with
  | zero => simp only [backoff]; split
            · assumption
            · rfl
  | succ f ih => simp only [backoff]; split
                 · assumption
                 · exact ih _

theorem fixed_p6_2_prefix (s : Bytes) (n : Int) : truncateFixed s n <+: s := by
  unfold truncateFixed bytesSlice
  split
  · exact List.prefix_refl s
  · split
    · rename_i x hx
      split at hx
      · simp only [Option.some.injEq] at hx
        subst hx
        simp only [Int.toNat_zero, List.drop_zero]
        exact (backoff_prefix _ _).trans (List.take_prefix _ _)
      · simp at hx
    · exact List.nil_prefix

theorem fixed_p6_2_fits (s : Bytes) (n : Int) (h : (s.length : Int) ≤ n) :
    truncateFixed s n = s := by
  unfold truncateFixed; rw [if_pos h]

theorem fixed_p6_1 (s : Bytes) (n : Int) (hn : 0 ≤ n) :
    ((truncateFixed s n).length : Int) ≤ n := by
  by_cases h : (s.length : Int) ≤ n
  · rw [fixed_p6_2_fits s n h]; exact h
  · unfold truncateFixed bytesSlice
    rw [if_neg h, if_pos (by omega)]
    simp only [Int.toNat_zero, List.drop_zero, Int.sub_zero]
    generalize hx : s.take n.toNat = x
    have hxl : x.length ≤ n.toNat := by rw [← hx, List.length_take]; omega
    have hp := (backoff_prefix x.length x).length_le
    omega

theorem fixed_p6_3 (s : Bytes) (n : Int) (hv : valid s = true) :
    valid (truncateFixed s n) = true := by
  unfold truncateFixed
  split
  · exact hv
  · split
    · exact backoff_valid _ _
    · rfl

/-- The fix keeps the intended behaviour on the counterexamples: "é" with cap 1 gives "",
"éa" with cap 1 gives "", "éa" with cap 2 gives "é". -/
theorem fixed_on_witnesses :
    truncateFixed [0xC3, 0xA9] 1 = [] ∧
    truncateFixed [0xC3, 0xA9, 0x61] 1 = [] ∧
    truncateFixed [0xC3, 0xA9, 0x61] 2 = [0xC3, 0xA9] ∧
    truncateFixed [0x61, 0x62, 0x63] 2 = [0x61, 0x62] := by decide

end T6

/-! ## Axiom report -/
#print axioms T6.seqLen_pos_of_decodeOk
#print axioms T6.width_pos
#print axioms T6.runeCountAux_le
#print axioms T6.runeCount_le_length
#print axioms T6.take_prefix
#print axioms T6.p6_2_prefix
#print axioms T6.p6_2_fits
#print axioms T6.p6_1_when_runes_exceed
#print axioms T6.p6_1_fails_iff
#print axioms T6.bug_p6_1_e_acute
#print axioms T6.eAcutes_length
#print axioms T6.runeCountAux_eAcutes
#print axioms T6.runeCount_eAcutes
#print axioms T6.bug_p6_1_family
#print axioms T6.bug_p6_1_default_cap
#print axioms T6.bug_store_elide_keeps_whole_output
#print axioms T6.runeCountAux_ascii
#print axioms T6.p6_1_ascii
#print axioms T6.seqLen_le_four
#print axioms T6.width_le_four
#print axioms T6.length_le_four_runeCountAux
#print axioms T6.p6_1_overshoot_le_four
#print axioms T6.bug_p6_1_fourfold
#print axioms T6.bug_p6_3_split_char
#print axioms T6.hyps_satisfiable
#print axioms T6.byteCap_p6_1
#print axioms T6.byteCap_p6_2_prefix
#print axioms T6.byteCap_p6_2_fits
#print axioms T6.truncate_ne_byteCap_iff
#print axioms T6.bug_byteCap_p6_3
#print axioms T6.backoff_prefix
#print axioms T6.backoff_valid
#print axioms T6.fixed_p6_2_prefix
#print axioms T6.fixed_p6_2_fits
#print axioms T6.fixed_p6_1
#print axioms T6.fixed_p6_3
#print axioms T6.fixed_on_witnesses
