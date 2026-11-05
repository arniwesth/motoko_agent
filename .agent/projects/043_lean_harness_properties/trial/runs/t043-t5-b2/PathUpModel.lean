/-
PathUpModel.lean — a Lean 4.28.0 model of D4 rule 1, "the path", as the journal fold
computes it. Core only: no Mathlib, no Lake. `lean PathUpModel.lean`.

Source (Motoko snapshot at /home/motoko/trial-043/s/t043-t5-b2/tree):

  * `contains_string`   src/core/journal.ail:1364-1366
  * `find_entry`        src/core/journal.ail:1392-1397
  * `path_up`           src/core/journal.ail:1403-1410
  * the one call site   src/core/journal.ail:1684  `path_up(all, leaf, [], [])`
  * the envelope        src/core/journal.ail:659-666 `JournalEntry`, :712-733 its decoder

Intent: the comment at journal.ail:1399-1402 ("Leaf to root, prepending as it climbs, so the
result comes out ROOT FIRST"; "`seen` is D4 rule 1's 'stopping at the first repeated id'")
and ADR-003 D4 rule 1 ("From `leaf` to the root by `parent_id`, stopping at the first
repeated id; reversed.").

What the model keeps and what it abstracts:

  * An entry is its `id`, its `parent_id` and its `seq`. `find_entry` and `path_up` read only
    `id` and `parent_id`; `seq` is kept because it names WHICH entry was found when two
    entries share an id, and the differential test prints it.  `at_ms`, `kind`, `raw` are
    never read by these functions.
  * Ids are `String`, compared with `=`; the source compares them with `==` and tests `""`.
  * The structure of each function is the source's, line for line: the same three guards in
    the same order in `pathUp`, the same first-match recursion in `findEntry`.
  * `pathUp` is defined by well-founded recursion; Lean only accepts the definition with the
    termination proof below (`fresh` decreases). `pathUpFuel` is the same recursion with one
    unit of fuel per call, so that P5.1 can be stated as a theorem about the number of calls.

CHECKED 2026-11-04: Lean 4.28.0 (7e01a1bf5c70) accepts this file with no error. No `sorry`,
no `native_decide`; every theorem's `#print axioms` is at the end (../axioms.txt): nothing
beyond `propext`, `Quot.sound`, `Classical.choice`.
DIFFERENTIAL (diff/run_diff.sh): on 29,004 generated cases `pathUp` printed byte-identical
output to the real `path_up` (ailang v0.54.14), on the first run; step 2 changed the model
0 times. The real side runs the three source bodies copied verbatim at run time (they are not
exported), with their sha256 printed; see diff/README.md.

Results (../SUMMARY.md):
  * P5.1 PROVED (`P5_1_terminates`): at most `es.length + 1` calls, cycles included.
  * P5.2 PROVED (`P5_2_nodup`).
  * P5.3 FALSE: `bug_P5_3_cycle`, `bug_P5_3_header_cycle` (a parent cycle gives `[]`) and
    `bug_P5_3_empty_id` (start `""` naming an entry gives `[]`). What holds is
    `P5_3_chain_part`: the result is a chain and, if non-empty, ends at the start id.
  * The fix `pathUpFix` (`[]` -> `acc`, D4 rule 1's "stopping"): `fix_P5_2`, `fix_P5_3`
    (start ≠ ""), `fix_P5_3_no_empty_ids`, `fix_conservative`.
-/

structure Entry where
  id       : String
  parentId : String
  seq      : Int
  deriving DecidableEq, Repr

/-! ## The model: journal.ail:1364-1366, 1392-1397, 1403-1410 -/

-- `contains_string` (journal.ail:1364-1366)
def containsString : List String → String → Bool
  | [], _ => false
  | x :: rest, t => if x = t then true else containsString rest t

-- `find_entry` (journal.ail:1392-1397)
def findEntry : List Entry → String → Option Entry
  | [], _ => none
  | e :: rest, id => if e.id = id then some e else findEntry rest id

/-- The termination measure: how many entries of `es` have an id not yet in `seen`. -/
def fresh (seen : List String) : List Entry → Nat
  | [] => 0
  | e :: rest => (if containsString seen e.id = true then 0 else 1) + fresh seen rest

theorem containsString_cons (x t : String) (s : List String) :
    containsString (x :: s) t = (decide (x = t) || containsString s t) := by
  simp only [containsString]
  by_cases h : x = t <;> simp [h]

theorem containsString_iff (s : List String) (t : String) :
    containsString s t = true ↔ t ∈ s := by
  induction s with
  | nil => simp [containsString]
  | cons x rest ih =>
    rw [containsString_cons]
    by_cases h : x = t
    · subst h; simp
    · simp [h, ih]
      intro hh; exact absurd hh.symm h

theorem findEntry_some {es : List Entry} {id : String} {e : Entry}
    (h : findEntry es id = some e) : e ∈ es ∧ e.id = id := by
  induction es with
  | nil => simp [findEntry] at h
  | cons x rest ih =>
    simp only [findEntry] at h
    by_cases hx : x.id = id
    · simp [hx] at h; subst h; exact ⟨List.mem_cons_self, hx⟩
    · simp [hx] at h
      have := ih h
      exact ⟨List.mem_cons_of_mem _ this.1, this.2⟩

theorem findEntry_none {es : List Entry} {id : String}
    (h : findEntry es id = none) : ∀ e ∈ es, e.id ≠ id := by
  induction es with
  | nil => simp
  | cons x rest ih =>
    simp only [findEntry] at h
    by_cases hx : x.id = id
    · simp [hx] at h
    · simp [hx] at h
      intro e he
      cases List.mem_cons.mp he with
      | inl e1 => subst e1; exact hx
      | inr e2 => exact ih h e e2

theorem fresh_cons_le (x : String) (seen : List String) (es : List Entry) :
    fresh (x :: seen) es ≤ fresh seen es := by
  induction es with
  | nil => simp [fresh]
  | cons e rest ih =>
    simp only [fresh]
    have hc : (if containsString (x :: seen) e.id = true then 0 else 1)
        ≤ (if containsString seen e.id = true then 0 else 1) := by
      rw [containsString_cons]
      by_cases h1 : containsString seen e.id = true <;> by_cases h2 : x = e.id <;> simp [h1, h2]
    omega

theorem fresh_cons_lt (x : String) (seen : List String) (es : List Entry) (e : Entry)
    (he : e ∈ es) (hid : e.id = x) (hs : ¬ containsString seen x = true) :
    fresh (x :: seen) es < fresh seen es := by
  induction es with
  | nil => simp at he
  | cons y rest ih =>
    simp only [fresh]
    cases List.mem_cons.mp he with
    | inl hy =>
      have hyid : y.id = x := by rw [← hy]; exact hid
      have hle := fresh_cons_le x seen rest
      have h1 : containsString (x :: seen) y.id = true := by
        rw [containsString_cons]; simp [hyid]
      have h2 : ¬ containsString seen y.id = true := by rw [hyid]; exact hs
      rw [if_pos h1, if_neg h2]; omega
    | inr hr =>
      have hlt := ih hr
      have hc : (if containsString (x :: seen) y.id = true then 0 else 1)
          ≤ (if containsString seen y.id = true then 0 else 1) := by
        rw [containsString_cons]
        by_cases h1 : containsString seen y.id = true <;> by_cases h2 : x = y.id <;> simp [h1, h2]
      omega

-- `path_up` (journal.ail:1403-1410)
def pathUp (es : List Entry) (id : String) (seen : List String) (acc : List Entry) :
    List Entry :=
  if id = "" then acc
  else if hs : containsString seen id = true then []
  else match hf : findEntry es id with
    | none => acc
    | some e => pathUp es e.parentId (id :: seen) (e :: acc)
termination_by fresh seen es
decreasing_by
  have ⟨hm, hid⟩ := findEntry_some hf
  exact fresh_cons_lt id seen es e hm hid hs

/-- The same recursion with one unit of fuel per call; `none` = out of fuel. -/
def pathUpFuel : Nat → List Entry → String → List String → List Entry → Option (List Entry)
  | 0, _, _, _, _ => none
  | n + 1, es, id, seen, acc =>
    if id = "" then some acc
    else if containsString seen id = true then some []
    else match findEntry es id with
      | none => some acc
      | some e => pathUpFuel n es e.parentId (id :: seen) (e :: acc)

/-- D4 rule 1 as the ADR and the comment state it: STOP at the first repeated id, keeping
the path climbed so far. The only change from `pathUp` is `[]` → `acc` on the second guard
(and it is what src/eval/journal/reader.ail:1225-1233 pins as journal.ail's `path_up`). -/
def pathUpFix (es : List Entry) (id : String) (seen : List String) (acc : List Entry) :
    List Entry :=
  if id = "" then acc
  else if hs : containsString seen id = true then acc
  else match hf : findEntry es id with
    | none => acc
    | some e => pathUpFix es e.parentId (id :: seen) (e :: acc)
termination_by fresh seen es
decreasing_by
  have ⟨hm, hid⟩ := findEntry_some hf
  exact fresh_cons_lt id seen es e hm hid hs

/-! ## One-step equations (both versions) -/

theorem pathUp_empty (es : List Entry) (seen : List String) (acc : List Entry) :
    pathUp es "" seen acc = acc := by
  rw [pathUp]; simp

theorem pathUp_seen {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    (h : id ≠ "") (hs : containsString seen id = true) : pathUp es id seen acc = [] := by
  rw [pathUp]; simp [h, hs]

theorem pathUp_none {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    (h : id ≠ "") (hs : ¬ containsString seen id = true) (hf : findEntry es id = none) :
    pathUp es id seen acc = acc := by
  rw [pathUp, if_neg h, dif_neg hs]
  split
  · rfl
  · next e he => rw [hf] at he; cases he

theorem pathUp_some {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    {e : Entry} (h : id ≠ "") (hs : ¬ containsString seen id = true)
    (hf : findEntry es id = some e) :
    pathUp es id seen acc = pathUp es e.parentId (id :: seen) (e :: acc) := by
  rw [pathUp, if_neg h, dif_neg hs]
  split
  · next he => rw [hf] at he; cases he
  · next e' he => rw [hf] at he; cases he; rfl

theorem pathUpFix_empty (es : List Entry) (seen : List String) (acc : List Entry) :
    pathUpFix es "" seen acc = acc := by
  rw [pathUpFix]; simp

theorem pathUpFix_seen {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    (h : id ≠ "") (hs : containsString seen id = true) : pathUpFix es id seen acc = acc := by
  rw [pathUpFix]; simp [h, hs]

theorem pathUpFix_none {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    (h : id ≠ "") (hs : ¬ containsString seen id = true) (hf : findEntry es id = none) :
    pathUpFix es id seen acc = acc := by
  rw [pathUpFix, if_neg h, dif_neg hs]
  split
  · rfl
  · next e he => rw [hf] at he; cases he

theorem pathUpFix_some {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    {e : Entry} (h : id ≠ "") (hs : ¬ containsString seen id = true)
    (hf : findEntry es id = some e) :
    pathUpFix es id seen acc = pathUpFix es e.parentId (id :: seen) (e :: acc) := by
  rw [pathUpFix, if_neg h, dif_neg hs]
  split
  · next he => rw [hf] at he; cases he
  · next e' he => rw [hf] at he; cases he; rfl

/-! ## P5.1 — `path_up` terminates on every entry list, cycles included

`pathUp` being accepted at all is Lean's termination proof (`fresh` decreases). The theorem
below says the same about the SOURCE's recursion, call by call: the fuelled copy, one unit per
call, reaches a base case within `es.length + 1` calls, for every `es`, start id, `seen` and
`acc`, and returns `pathUp`'s answer. -/

theorem fresh_le_length (seen : List String) (es : List Entry) : fresh seen es ≤ es.length := by
  induction es with
  | nil => simp [fresh]
  | cons e rest ih => simp only [fresh, List.length_cons]; split <;> omega

theorem pathUpFuel_eq (es : List Entry) : ∀ (n : Nat) (id : String) (seen : List String)
    (acc : List Entry), fresh seen es < n → pathUpFuel n es id seen acc = some (pathUp es id seen acc) := by
  intro n
  induction n with
  | zero => intro id seen acc h; omega
  | succ n ih =>
    intro id seen acc hlt
    by_cases h : id = ""
    · subst h; simp [pathUpFuel, pathUp_empty]
    · by_cases hs : containsString seen id = true
      · simp [pathUpFuel, h, hs, pathUp_seen h hs]
      · cases hf : findEntry es id with
        | none => simp [pathUpFuel, h, hs, hf, pathUp_none h hs hf]
        | some e =>
          have ⟨hm, hid⟩ := findEntry_some hf
          have := fresh_cons_lt id seen es e hm hid hs
          simp only [pathUpFuel, h, hs, hf, if_false, Bool.false_eq_true]
          rw [pathUp_some h hs hf]
          exact ih _ _ _ (by omega)

theorem P5_1_terminates (es : List Entry) (id : String) (seen : List String) (acc : List Entry) :
    pathUpFuel (es.length + 1) es id seen acc = some (pathUp es id seen acc) :=
  pathUpFuel_eq es _ id seen acc (by have := fresh_le_length seen es; omega)

/-! ## The invariant the climb keeps -/

def ids (xs : List Entry) : List String := xs.map Entry.id

/-- Each entry's `parent_id` is the id of the entry before it. -/
def Chain : List Entry → Prop
  | a :: b :: rest => b.parentId = a.id ∧ Chain (b :: rest)
  | _ => True

/-- What holds of `(id, seen, acc)` at every call, for a climb that began at `start`. -/
structure ClimbInv (start id : String) (seen : List String) (acc : List Entry) : Prop where
  nodup  : (ids acc).Nodup
  inSeen : ∀ x ∈ ids acc, x ∈ seen
  chain  : Chain acc
  link   : ∀ a, acc.head? = some a → a.parentId = id
  last   : ∀ l, acc.getLast? = some l → l.id = start
  empty  : acc = [] → id = start

theorem inv_init (start : String) : ClimbInv start start [] [] :=
  ⟨List.nodup_nil, by simp [ids], trivial, by simp, by simp, fun _ => rfl⟩

theorem inv_step {start id : String} {seen : List String} {acc : List Entry} {e : Entry}
    (hI : ClimbInv start id seen acc) (hs : ¬ containsString seen id = true) (hid : e.id = id) :
    ClimbInv start e.parentId (id :: seen) (e :: acc) := by
  have hns : id ∉ seen := fun hm => hs ((containsString_iff seen id).mpr hm)
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · simp only [ids, List.map_cons]
    refine List.nodup_cons.mpr ⟨?_, hI.nodup⟩
    intro hm; exact hns (hid ▸ hI.inSeen _ hm)
  · intro x hx
    simp only [ids, List.map_cons, List.mem_cons] at hx
    cases hx with
    | inl h1 => rw [h1, hid]; exact List.mem_cons_self
    | inr h2 => exact List.mem_cons_of_mem _ (hI.inSeen x h2)
  · cases hacc : acc with
    | nil => simp [Chain]
    | cons a rest =>
      have hl := hI.link a (by simp [hacc])
      have hc := hI.chain
      rw [hacc] at hc
      exact ⟨by rw [hl, hid], hc⟩
  · intro a ha; simp at ha; rw [← ha]
  · intro l hl
    cases hacc : acc with
    | nil =>
      rw [hacc] at hl; simp at hl; rw [← hl, hid]; exact hI.empty hacc
    | cons a rest =>
      rw [hacc] at hl
      have : (e :: a :: rest).getLast? = (a :: rest).getLast? := by simp [List.getLast?_cons]
      rw [this] at hl
      exact hI.last l (by rw [hacc]; exact hl)
  · intro h; cases h

theorem inv_result {start id : String} {seen : List String} {acc : List Entry}
    (hI : ClimbInv start id seen acc) :
    (ids acc).Nodup ∧ Chain acc ∧ ∀ l, acc.getLast? = some l → l.id = start :=
  ⟨hI.nodup, hI.chain, hI.last⟩

/-- Whatever `pathUp` returns, from any state satisfying `ClimbInv`, is repeat-free, a chain, and
ends (if non-empty) at `start`. The `[]` it returns on a repeat satisfies all three
vacuously, which is exactly why P5.2 holds and P5.3 does not. -/
theorem pathUp_sound (es : List Entry) (start : String) : ∀ (n : Nat) (id : String)
    (seen : List String) (acc : List Entry), fresh seen es < n → ClimbInv start id seen acc →
    let r := pathUp es id seen acc
    (ids r).Nodup ∧ Chain r ∧ ∀ l, r.getLast? = some l → l.id = start := by
  intro n
  induction n with
  | zero => intro id seen acc h; omega
  | succ n ih =>
    intro id seen acc hlt hI
    by_cases h : id = ""
    · subst h; rw [pathUp_empty]; exact inv_result hI
    · by_cases hs : containsString seen id = true
      · rw [pathUp_seen h hs]; exact ⟨List.nodup_nil, trivial, by simp⟩
      · cases hf : findEntry es id with
        | none => rw [pathUp_none h hs hf]; exact inv_result hI
        | some e =>
          have ⟨hm, hid⟩ := findEntry_some hf
          have := fresh_cons_lt id seen es e hm hid hs
          rw [pathUp_some h hs hf]
          exact ih _ _ _ (by omega) (inv_step hI hs hid)

theorem pathUpFix_sound (es : List Entry) (start : String) : ∀ (n : Nat) (id : String)
    (seen : List String) (acc : List Entry), fresh seen es < n → ClimbInv start id seen acc →
    let r := pathUpFix es id seen acc
    (ids r).Nodup ∧ Chain r ∧ ∀ l, r.getLast? = some l → l.id = start := by
  intro n
  induction n with
  | zero => intro id seen acc h; omega
  | succ n ih =>
    intro id seen acc hlt hI
    by_cases h : id = ""
    · subst h; rw [pathUpFix_empty]; exact inv_result hI
    · by_cases hs : containsString seen id = true
      · rw [pathUpFix_seen h hs]; exact inv_result hI
      · cases hf : findEntry es id with
        | none => rw [pathUpFix_none h hs hf]; exact inv_result hI
        | some e =>
          have ⟨hm, hid⟩ := findEntry_some hf
          have := fresh_cons_lt id seen es e hm hid hs
          rw [pathUpFix_some h hs hf]
          exact ih _ _ _ (by omega) (inv_step hI hs hid)

/-- `pathUpFix` only ever prepends to `acc`. -/
theorem pathUpFix_ext (es : List Entry) : ∀ (n : Nat) (id : String) (seen : List String)
    (acc : List Entry), fresh seen es < n → ∃ pre, pathUpFix es id seen acc = pre ++ acc := by
  intro n
  induction n with
  | zero => intro id seen acc h; omega
  | succ n ih =>
    intro id seen acc hlt
    by_cases h : id = ""
    · subst h; exact ⟨[], by rw [pathUpFix_empty]; rfl⟩
    · by_cases hs : containsString seen id = true
      · exact ⟨[], by rw [pathUpFix_seen h hs]; rfl⟩
      · cases hf : findEntry es id with
        | none => exact ⟨[], by rw [pathUpFix_none h hs hf]; rfl⟩
        | some e =>
          have ⟨hm, hid⟩ := findEntry_some hf
          have := fresh_cons_lt id seen es e hm hid hs
          rw [pathUpFix_some h hs hf]
          have ⟨pre, hpre⟩ := ih e.parentId (id :: seen) (e :: acc) (by omega)
          exact ⟨pre ++ [e], by rw [hpre]; simp⟩

/-- The real function and the fix differ only where the real one returns `[]`. -/
theorem pathUp_or_fix (es : List Entry) : ∀ (n : Nat) (id : String) (seen : List String)
    (acc : List Entry), fresh seen es < n →
    pathUp es id seen acc = [] ∨ pathUp es id seen acc = pathUpFix es id seen acc := by
  intro n
  induction n with
  | zero => intro id seen acc h; omega
  | succ n ih =>
    intro id seen acc hlt
    by_cases h : id = ""
    · subst h; right; rw [pathUp_empty, pathUpFix_empty]
    · by_cases hs : containsString seen id = true
      · left; exact pathUp_seen h hs
      · cases hf : findEntry es id with
        | none => right; rw [pathUp_none h hs hf, pathUpFix_none h hs hf]
        | some e =>
          have ⟨hm, hid⟩ := findEntry_some hf
          have := fresh_cons_lt id seen es e hm hid hs
          rw [pathUp_some h hs hf, pathUpFix_some h hs hf]
          exact ih _ _ _ (by omega)

/-! ## The registered properties, at the one call site `path_up(all, leaf, [], [])` -/

/-- P5.3, as registered: the result is a chain, and if the start id names an entry, the
result is non-empty and its last entry has that id. -/
def P53 (es : List Entry) (start : String) (r : List Entry) : Prop :=
  Chain r ∧ ((∃ e ∈ es, e.id = start) → ∃ l, r.getLast? = some l ∧ l.id = start)

/-- **P5.2 holds**: no id occurs twice in the result, for every entry list and start id. -/
theorem P5_2_nodup (es : List Entry) (start : String) : (ids (pathUp es start [] [])).Nodup :=
  (pathUp_sound es start (fresh [] es + 1) start [] [] (by omega) (inv_init start)).1

/-- **The part of P5.3 that holds**: the result is a chain, and IF it is non-empty its last
entry has the start id. What fails is non-emptiness (`bug_P5_3_*` below). -/
theorem P5_3_chain_part (es : List Entry) (start : String) :
    Chain (pathUp es start [] []) ∧
    ∀ l, (pathUp es start [] []).getLast? = some l → l.id = start :=
  (pathUp_sound es start (fresh [] es + 1) start [] [] (by omega) (inv_init start)).2

/-- **P5.3 FAILS: a parent cycle.** A one-entry journal whose entry is its own parent. The
start id names that entry, and `path_up` returns `[]` instead of stopping at the repeat. -/
theorem bug_P5_3_cycle :
    let es : List Entry := [⟨"a", "a", 0⟩]
    (∃ e ∈ es, e.id = "a") ∧ pathUp es "a" [] [] = [] ∧ ¬ P53 es "a" (pathUp es "a" [] []) := by
  intro es
  have f1 : findEntry es "a" = some ⟨"a", "a", 0⟩ := by simp [es, findEntry]
  have c0 : ¬ containsString [] "a" = true := by simp [containsString]
  have c1 : containsString ["a"] "a" = true := by simp [containsString]
  have hr : pathUp es "a" [] [] = [] := by
    rw [pathUp_some (by decide) c0 f1]; exact pathUp_seen (by decide) c1
  refine ⟨⟨⟨"a", "a", 0⟩, by simp [es], rfl⟩, hr, ?_⟩
  intro hp
  have ⟨l, hl, _⟩ := hp.2 ⟨⟨"a", "a", 0⟩, by simp [es], rfl⟩
  rw [hr] at hl; simp at hl

/-- **P5.3 FAILS: a two-entry cycle through a header.** `h`'s parent is `m` and `m`'s parent
is `h`. Climbing from `m`: `m`, `h`, then `m` again. D4 rule 1 stops there with the path
`[h, m]`, root (the header) first; `path_up` returns `[]`. This is the shape reproduced on the
real `fold_journal` (repro/repro_cycle_fold.sh). -/
theorem bug_P5_3_header_cycle :
    let es : List Entry := [⟨"h", "m", 0⟩, ⟨"m", "h", 1⟩]
    pathUp es "m" [] [] = [] ∧ pathUpFix es "m" [] [] = [⟨"h", "m", 0⟩, ⟨"m", "h", 1⟩] ∧
    ¬ P53 es "m" (pathUp es "m" [] []) := by
  intro es
  have f1 : findEntry es "m" = some ⟨"m", "h", 1⟩ := by simp [es, findEntry]
  have f2 : findEntry es "h" = some ⟨"h", "m", 0⟩ := by simp [es, findEntry]
  have c0 : ¬ containsString [] "m" = true := by simp [containsString]
  have c1 : ¬ containsString ["m"] "h" = true := by simp [containsString]
  have c2 : containsString ["h", "m"] "m" = true := by simp [containsString]
  have hr : pathUp es "m" [] [] = [] := by
    rw [pathUp_some (by decide) c0 f1, pathUp_some (by decide) c1 f2]
    exact pathUp_seen (by decide) c2
  refine ⟨hr, ?_, ?_⟩
  · rw [pathUpFix_some (by decide) c0 f1, pathUpFix_some (by decide) c1 f2]
    exact pathUpFix_seen (by decide) c2
  · intro hp
    have ⟨l, hl, _⟩ := hp.2 ⟨⟨"m", "h", 1⟩, by simp [es], rfl⟩
    rw [hr] at hl; simp at hl

/-- **P5.3 FAILS: the empty start id names an entry.** `journal_entry_of_json` accepts
`"id": ""` (journal.ail:712-733), and `""` is also `path_up`'s "no parent" sentinel, tested
first. An entry with id `""` is named by the start id `""`, and the result is `[]`. The fix
below does not change this case: P5.3 needs `start ≠ ""` there (`fix_P5_3`). -/
theorem bug_P5_3_empty_id :
    let es : List Entry := [⟨"", "", 0⟩]
    (∃ e ∈ es, e.id = "") ∧ pathUp es "" [] [] = [] ∧ pathUpFix es "" [] [] = [] ∧
    ¬ P53 es "" (pathUp es "" [] []) := by
  intro es
  refine ⟨⟨⟨"", "", 0⟩, by simp [es], rfl⟩, pathUp_empty _ _ _, pathUpFix_empty _ _ _, ?_⟩
  intro hp
  have ⟨l, hl, _⟩ := hp.2 ⟨⟨"", "", 0⟩, by simp [es], rfl⟩
  rw [pathUp_empty] at hl; simp at hl

/-- Non-vacuity of `P5_2_nodup` / `P5_3_chain_part`: a two-entry journal whose path is
non-empty, root first. -/
theorem witness_linear :
    pathUp [⟨"h", "", 0⟩, ⟨"a", "h", 1⟩] "a" [] [] = [⟨"h", "", 0⟩, ⟨"a", "h", 1⟩] := by
  have f1 : findEntry [⟨"h", "", 0⟩, ⟨"a", "h", 1⟩] "a" = some ⟨"a", "h", 1⟩ := by simp [findEntry]
  have f2 : findEntry [⟨"h", "", 0⟩, ⟨"a", "h", 1⟩] "h" = some ⟨"h", "", 0⟩ := by simp [findEntry]
  have c0 : ¬ containsString [] "a" = true := by simp [containsString]
  have c1 : ¬ containsString ["a"] "h" = true := by simp [containsString]
  rw [pathUp_some (by decide) c0 f1, pathUp_some (by decide) c1 f2]
  exact pathUp_empty _ _ _

/-! ## The fix: stop at the first repeated id, as D4 rule 1 says -/

theorem fix_P5_2 (es : List Entry) (start : String) : (ids (pathUpFix es start [] [])).Nodup :=
  (pathUpFix_sound es start (fresh [] es + 1) start [] [] (by omega) (inv_init start)).1

theorem fix_P5_3 (es : List Entry) (start : String) (hne : start ≠ "") :
    P53 es start (pathUpFix es start [] []) := by
  have hs := pathUpFix_sound es start (fresh [] es + 1) start [] [] (by omega) (inv_init start)
  refine ⟨hs.2.1, ?_⟩
  intro ⟨e0, he0, hid0⟩
  have c0 : ¬ containsString [] start = true := by simp [containsString]
  cases hf : findEntry es start with
  | none => exact absurd hid0 (findEntry_none hf e0 he0)
  | some e =>
    have ⟨hm, hid⟩ := findEntry_some hf
    rw [pathUpFix_some hne c0 hf]
    have ⟨pre, hpre⟩ := pathUpFix_ext es (fresh [start] es + 1) e.parentId [start] [e] (by omega)
    have hl : (pathUpFix es e.parentId [start] [e]).getLast? = some e := by rw [hpre]; simp
    exact ⟨e, hl, hid⟩

/-- With the fix AND a decoder that refuses an empty `id` (so no entry has id `""`), P5.3
holds for every start id, `""` included. The decoder half is not in the code today
(journal.ail:712-733 accepts `"id": ""`); this states what it would buy. -/
theorem fix_P5_3_no_empty_ids (es : List Entry) (start : String)
    (hids : ∀ e ∈ es, e.id ≠ "") : P53 es start (pathUpFix es start [] []) := by
  by_cases hne : start = ""
  · subst hne
    rw [pathUpFix_empty]
    exact ⟨trivial, fun ⟨e, he, hid⟩ => absurd hid (hids e he)⟩
  · exact fix_P5_3 es start hne

/-- The fix keeps every answer the real function gives that is not `[]`. -/
theorem fix_conservative (es : List Entry) (start : String) :
    pathUp es start [] [] = [] ∨ pathUp es start [] [] = pathUpFix es start [] [] :=
  pathUp_or_fix es (fresh [] es + 1) start [] [] (by omega)

/-! ## Observation X-1: duplicate ids — the FIRST entry with the leaf's id is the one climbed

`find_entry` returns the first match in file order; `journal_leaf` (journal.ail:2151-2157)
is the id of the LAST line. With a repeated id the path starts at the earlier entry. -/
theorem obs_duplicate_id_first_wins :
    pathUp [⟨"a", "", 0⟩, ⟨"a", "", 1⟩] "a" [] [] = [⟨"a", "", 0⟩] := by
  have f1 : findEntry [⟨"a", "", 0⟩, ⟨"a", "", 1⟩] "a" = some ⟨"a", "", 0⟩ := by simp [findEntry]
  have c0 : ¬ containsString [] "a" = true := by simp [containsString]
  rw [pathUp_some (by decide) c0 f1]
  exact pathUp_empty _ _ _

/-! ## Axiom report -/
#print axioms pathUp
#print axioms pathUpFix
#print axioms P5_1_terminates
#print axioms P5_2_nodup
#print axioms P5_3_chain_part
#print axioms bug_P5_3_cycle
#print axioms bug_P5_3_header_cycle
#print axioms bug_P5_3_empty_id
#print axioms witness_linear
#print axioms fix_P5_2
#print axioms fix_P5_3
#print axioms fix_conservative
#print axioms fix_P5_3_no_empty_ids
#print axioms obs_duplicate_id_first_wins
#print axioms pathUp_sound
#print axioms pathUpFix_sound
#print axioms pathUpFuel_eq
#print axioms pathUp_or_fix
#print axioms pathUpFix_ext
#print axioms inv_step
#print axioms fresh_cons_lt
#print axioms containsString_cons
#print axioms containsString_iff
#print axioms findEntry_some
#print axioms findEntry_none
#print axioms fresh_cons_le
#print axioms pathUp_empty
#print axioms pathUp_seen
#print axioms pathUp_none
#print axioms pathUp_some
#print axioms pathUpFix_empty
#print axioms pathUpFix_seen
#print axioms pathUpFix_none
#print axioms pathUpFix_some
#print axioms fresh_le_length
#print axioms inv_init
#print axioms inv_result
