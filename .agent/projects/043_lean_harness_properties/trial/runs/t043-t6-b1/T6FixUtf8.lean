/-
T6FixUtf8.lean — step 8 for P6.3 (K2): a fix to `truncate_utf8_by_bytes` that cuts on a rune
boundary, proved in the model to satisfy P6.1, P6.2 and P6.3.

SOURCE: `packages/motoko-ext-compose/store.ail:20-30` (snapshot), modelled in T6Model.lean,
whose definitions this file repeats verbatim (no Lake, so no import) up to `truncate`.

The fix, in AILANG (applied to a scratch copy only; the tree is unchanged — see SUMMARY.md):

    func rune_cut(b: bytes, k: int) -> int {
      if k <= 0 then 0
      else match byteAt(b, k) {
        Some(c) => if c >= 128 && c < 192 then rune_cut(b, k - 1) else k,
        None => k
      }
    }
    ... let n = length(b); ... match slice(b, 0, rune_cut(b, max_bytes)) { ... }

i.e. compare BYTE length (P6.1), and move the cut back while the first byte left out is a
continuation byte (P6.3). Lean 4.28.0, core only, no `sorry`, no `native_decide`.
-/

namespace T6

abbrev Bytes := List Nat

def seqSize (c : Nat) : Nat :=
  if c < 0x80 then 1
  else if c < 0xC2 then 0
  else if c < 0xE0 then 2
  else if c < 0xF0 then 3
  else if c < 0xF5 then 4
  else 0

def acceptLo (c : Nat) : Nat := if c = 0xE0 then 0xA0 else if c = 0xF0 then 0x90 else 0x80
def acceptHi (c : Nat) : Nat := if c = 0xED then 0x9F else if c = 0xF4 then 0x8F else 0xBF

def isCont (b : Nat) : Bool := decide (0x80 ≤ b) && decide (b ≤ 0xBF)

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

def validF : Nat → Bytes → Bool
  | 0, _ => true
  | _, [] => true
  | k + 1, c :: t => (decode1 (c :: t)).1 && validF k (t.drop ((decode1 (c :: t)).2 - 1))

def valid (s : Bytes) : Bool := validF s.length s

def slice (b : Bytes) (st en : Int) : Option Bytes :=
  if 0 ≤ st ∧ st ≤ en ∧ en ≤ (b.length : Int) then
    some ((b.drop st.toNat).take (en - st).toNat)
  else none

/-! ## The fix -/

def runeCutN (b : Bytes) : Nat → Nat
  | 0 => 0
  | k + 1 =>
    match b[k + 1]? with
    | some c => if decide (128 ≤ c) && decide (c < 192) then runeCutN b k else k + 1
    | none => k + 1

/-- `rune_cut(b, k)`. -/
def runeCut (b : Bytes) (k : Int) : Int := if k ≤ 0 then 0 else (runeCutN b k.toNat : Int)

def truncateFix2 (s : Bytes) (maxBytes : Int) : Bytes :=
  let b := s
  let n := b.length
  if (n : Int) ≤ maxBytes then s
  else
    match slice b 0 (runeCut b maxBytes) with
    | some x => x
    | none => []

/-! ## Lemmas about UTF-8 decoding -/

/-- A valid first rune is the lead byte plus `d - 1` continuation bytes, and the decoder's
verdict on it does not depend on what follows. -/
theorem acceptLo_ge (c : Nat) : 0x80 ≤ acceptLo c := by
  unfold acceptLo; split <;> (try split) <;> omega

theorem acceptHi_le (c : Nat) : acceptHi c ≤ 0xBF := by
  unfold acceptHi; split <;> (try split) <;> omega

theorem decode1_shape {c : Nat} {t : Bytes} {d : Nat} (h : decode1 (c :: t) = (true, d)) :
    ∃ pre rest, t = pre ++ rest ∧ pre.length + 1 = d ∧
      (∀ x ∈ pre, isCont x = true) ∧
      ∀ rest', decode1 (c :: (pre ++ rest')) = (true, d) := by
  unfold decode1 at h
  simp only at h
  split at h
  · -- ASCII
    rename_i hs1
    simp at h; subst h
    refine ⟨[], t, rfl, rfl, by simp, ?_⟩
    intro rest'; unfold decode1; simp [hs1]
  rename_i h1
  split at h
  · simp at h
  rename_i h0
  split at h
  · simp at h
  rename_i hlen
  cases t with
  | nil => simp at h
  | cons b1 t1 =>
    simp only at h
    split at h
    · simp at h
    rename_i hacc
    have hacc' : acceptLo c ≤ b1 ∧ b1 ≤ acceptHi c := by
      apply Classical.byContradiction; intro hn; exact hacc hn
    have hb1 : isCont b1 = true := by
      have := acceptLo_ge c; have := acceptHi_le c
      simp only [isCont, Bool.and_eq_true, decide_eq_true_eq]; omega
    split at h
    · -- 2-byte
      rename_i hs2
      simp at h; subst h
      refine ⟨[b1], t1, rfl, rfl, by simpa using hb1, ?_⟩
      intro rest'; unfold decode1
      simp [hs2, hacc']
    rename_i h2
    cases t1 with
    | nil => simp at h
    | cons b2 t2 =>
      simp only at h
      split at h
      · simp at h
      rename_i hb2
      simp only [Bool.not_eq_false] at hb2
      split at h
      · -- 3-byte
        rename_i hs3
        simp at h; subst h
        refine ⟨[b1, b2], t2, rfl, rfl, ?_, ?_⟩
        · intro x hx; simp at hx; rcases hx with rfl | rfl
          · exact hb1
          · exact hb2
        · intro rest'; unfold decode1
          simp [hs3, hacc', hb2]
      rename_i h3
      cases t2 with
      | nil => simp at h
      | cons b3 t3 =>
        simp only at h
        split at h
        · simp at h
        rename_i hb3
        simp only [Bool.not_eq_false] at hb3
        simp at h; subst h
        have hs4 : seqSize c = 4 := by
          simp only [seqSize] at h1 h0 h2 h3 ⊢
          split <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;> simp_all
        refine ⟨[b1, b2, b3], t3, rfl, rfl, ?_, ?_⟩
        · intro x hx; simp at hx; rcases hx with rfl | rfl | rfl
          · exact hb1
          · exact hb2
          · exact hb3
        · intro rest'; unfold decode1
          simp [hs4, hacc', hb2, hb3]

theorem validF_nil (k : Nat) : validF k [] = true := by cases k <;> rfl

/-- Fuel beyond the length does not matter. -/
theorem validF_fuel (k k' : Nat) (s : Bytes) (hk : s.length ≤ k) (hk' : s.length ≤ k') :
    validF k s = validF k' s := by
  induction k generalizing k' s with
  | zero =>
    cases s with
    | nil => rw [validF_nil, validF_nil]
    | cons c t => simp at hk
  | succ k ih =>
    cases s with
    | nil => rw [validF_nil, validF_nil]
    | cons c t =>
      cases k' with
      | zero => simp at hk'
      | succ k'' =>
        simp only [validF]
        rw [ih k'' _ (by simp at hk ⊢; omega) (by simp at hk' ⊢; omega)]

/-- The prefix of a valid string up to a rune boundary is valid. A position `j` is a boundary
when it is 0, at or past the end, or the byte there is not a continuation byte. -/
theorem valid_take_boundary (k : Nat) (s : Bytes) (hk : s.length ≤ k) (hv : validF k s = true)
    (j : Nat) (hj : j = 0 ∨ s.length ≤ j ∨ ∃ c, s[j]? = some c ∧ isCont c = false) :
    validF k (s.take j) = true := by
  induction k generalizing s j with
  | zero =>
    cases s with
    | nil => simp [validF_nil]
    | cons c t => simp at hk
  | succ k ih =>
    cases s with
    | nil => simp [validF_nil]
    | cons c t =>
      cases j with
      | zero => simp [validF_nil]
      | succ j =>
        simp only [validF, Bool.and_eq_true] at hv
        obtain ⟨hd, hrest⟩ := hv
        obtain ⟨pre, rest, ht, hlen, hcont, hloc⟩ :=
          decode1_shape (d := (decode1 (c :: t)).2) (by rw [← hd])
        -- j + 1 must not fall inside the first rune
        have hjd : pre.length ≤ j := by
          rcases hj with h | h | ⟨x, hx, hxc⟩
          · omega
          · subst ht; simp at h; omega
          · rcases Nat.lt_or_ge j pre.length with hlt | hge
            · exfalso
              subst ht
              simp only [List.getElem?_cons_succ] at hx
              rw [List.getElem?_append_left hlt] at hx
              have hmem : x ∈ pre := List.mem_of_getElem? hx
              rw [hcont x hmem] at hxc
              cases hxc
            · exact hge
        subst ht
        rw [List.take_succ_cons]
        simp only [validF]
        have htake : (pre ++ rest).take j = pre ++ rest.take (j - pre.length) := by
          rw [List.take_append]; simp [List.take_of_length_le hjd]
        rw [htake, hloc (rest.take (j - pre.length))]
        simp only [Bool.true_and]
        have hd2 : (decode1 (c :: (pre ++ rest))).2 - 1 = pre.length := by
          rw [hloc rest]; simp; omega
        rw [hd2] at hrest
        rw [hd2]
        simp only [List.drop_left] at hrest ⊢
        apply ih rest (by simp at hk; omega) hrest
        rcases hj with h | h | ⟨x, hx, hxc⟩
        · omega
        · right; left; simp at h; omega
        · by_cases hz : j - pre.length = 0
          · left; exact hz
          · right; right; refine ⟨x, ?_, hxc⟩
            simp only [List.getElem?_cons_succ] at hx
            rw [List.getElem?_append_right (by omega)] at hx
            exact hx

/-! ## Properties of the fix -/

theorem runeCutN_le (b : Bytes) (k : Nat) : runeCutN b k ≤ k := by
  induction k with
  | zero => simp [runeCutN]
  | succ k ih =>
    simp only [runeCutN]
    split
    · split <;> omega
    · omega

theorem runeCutN_boundary (b : Bytes) (k : Nat) :
    runeCutN b k = 0 ∨ b.length ≤ runeCutN b k ∨
      ∃ c, b[runeCutN b k]? = some c ∧ isCont c = false := by
  induction k with
  | zero => simp [runeCutN]
  | succ k ih =>
    simp only [runeCutN]
    split
    · rename_i c hc
      split
      · exact ih
      · rename_i hnc
        right; right; refine ⟨c, hc, ?_⟩
        simp only [isCont, Bool.and_eq_false_iff, decide_eq_false_iff_not]
        simp only [Bool.and_eq_true, decide_eq_true_eq, not_and] at hnc
        omega
    · rename_i hn
      right; left
      exact List.getElem?_eq_none_iff.mp hn

theorem fix2_eq (s : Bytes) (m : Int) (h : ¬ ((s.length : Int) ≤ m)) :
    truncateFix2 s m = s.take (runeCut s m).toNat := by
  have hrc : 0 ≤ runeCut s m ∧ runeCut s m ≤ max m 0 := by
    unfold runeCut; split
    · omega
    · have := runeCutN_le s m.toNat; omega
  unfold truncateFix2
  simp only [slice]
  rw [if_neg h, if_pos (by omega)]
  simp

theorem fix2_p61 (s : Bytes) (m : Int) (hm : 0 ≤ m) : ((truncateFix2 s m).length : Int) ≤ m := by
  by_cases h : (s.length : Int) ≤ m
  · unfold truncateFix2; simp only; rw [if_pos h]; exact h
  · rw [fix2_eq s m h]
    have : runeCut s m ≤ m := by
      unfold runeCut; split
      · omega
      · have := runeCutN_le s m.toNat; omega
    simp only [List.length_take]; omega

theorem fix2_p62_prefix (s : Bytes) (m : Int) : truncateFix2 s m <+: s := by
  by_cases h : (s.length : Int) ≤ m
  · unfold truncateFix2; simp only; rw [if_pos h]; exact List.prefix_refl s
  · rw [fix2_eq s m h]; exact List.take_prefix _ _

theorem fix2_p62_fits (s : Bytes) (m : Int) (h : (s.length : Int) ≤ m) : truncateFix2 s m = s := by
  unfold truncateFix2; simp only; rw [if_pos h]

theorem fix2_p63 (s : Bytes) (m : Int) (hv : valid s = true) : valid (truncateFix2 s m) = true := by
  by_cases h : (s.length : Int) ≤ m
  · rw [fix2_p62_fits s m h]; exact hv
  · rw [fix2_eq s m h]
    unfold valid
    rw [validF_fuel _ s.length _ (Nat.le_refl _) (by simp only [List.length_take]; omega)]
    apply valid_take_boundary s.length s (Nat.le_refl _) hv
    unfold runeCut; split
    · left; simp
    · have hb := runeCutN_boundary s m.toNat
      simp only [Int.toNat_natCast]
      exact hb

/-- Witnesses: the fix on the P6.1 and P6.3 counterexamples. -/
theorem fix2_on_bug_inputs :
    truncateFix2 [0xC3, 0xA9] 1 = [] ∧ truncateFix2 [0xC3, 0xA9, 0xC3, 0xA9] 1 = [] ∧
    truncateFix2 [0xC3, 0xA9, 0xC3, 0xA9] 3 = [0xC3, 0xA9] ∧
    valid [0xC3, 0xA9, 0xC3, 0xA9] = true := by decide

end T6

#print axioms T6.acceptLo_ge
#print axioms T6.acceptHi_le
#print axioms T6.decode1_shape
#print axioms T6.validF_fuel
#print axioms T6.valid_take_boundary
#print axioms T6.runeCutN_le
#print axioms T6.runeCutN_boundary
#print axioms T6.fix2_eq
#print axioms T6.fix2_p61
#print axioms T6.fix2_p62_prefix
#print axioms T6.fix2_p62_fits
#print axioms T6.fix2_p63
#print axioms T6.fix2_on_bug_inputs
