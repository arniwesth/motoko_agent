/-
PathUpModel.lean — model of the journal fold's path, ADR-003 D4 rule 1 (target T5).

Source (snapshot at /home/motoko/trial-043/s/t043-t5-b1/tree):

  * `contains_string`  src/core/journal.ail:1364-1366
  * `find_entry`       src/core/journal.ail:1392-1397
  * `path_up`          src/core/journal.ail:1403-1410, its comment :1399-1402
  * the one caller     src/core/journal.ail:1684, `path_up(all, leaf, [], [])` in `fold_journal`

Intent: the comment ("Leaf to root, prepending as it climbs, so the result comes out ROOT
FIRST"; "`seen` is D4 rule 1's 'stopping at the first repeated id'") and ADR-003 D4 rule 1
("From `leaf` to the root by `parent_id`, stopping at the first repeated id; reversed").

What the model keeps and what it abstracts:

  * An entry is its `id`, its `parent_id` and its `seq`. `path_up` and `find_entry` read only
    `id` and `parent_id`; `seq` is kept so that the differential test can tell WHICH entry a
    lookup returned when two entries share an id (`find_entry` returns the first).
    `at_ms`, `kind` and `raw` are never read by these functions and are dropped.
  * Ids are `String`; the source only compares them with `==` and with `""`.
  * `path_up` keeps the source's branch order exactly. Lean needs the termination argument
    written down: the measure is the number of entries whose id is not yet in `seen`
    (`unseen`), which each recursive call lowers by at least one, because the entry it
    prepends was found by its id and that id was not in `seen`.

Differential test: diff/run_diff.sh, against the real functions through an export-only copy
of journal.ail (diff/make_root.sh). On 2026-11-04: 50,704 inputs, 0 mismatches, the two
outputs byte-identical (sha256 113d33e4e882a2ad...). `pathUpFixed` against the real code with
the fix planted: 0 mismatches. Model fixes made in step (2): none (SUMMARY.md).

CHECKED 2026-11-04: Lean 4.28.0 accepts this file with no error; no theorem uses an axiom
beyond `propext` and `Quot.sound` (axioms.txt). What is proved is about this model; the
differential test ties the model to the code only on the inputs it ran.

Lean 4.28.0, core only (no Mathlib, no Lake): `lean PathUpModel.lean`. No `sorry`, no
`native_decide`. `#print axioms` for every theorem is at the end of the file.
-/

structure Entry where
  id       : String
  parentId : String
  seq      : Nat
  deriving DecidableEq, Repr

/-! ## The model, branch for branch -/

-- `contains_string`, journal.ail:1364-1366.
def containsString : List String → String → Bool
  | [], _ => false
  | x :: rest, t => if x = t then true else containsString rest t

-- `find_entry`, journal.ail:1392-1397.
def findEntry : List Entry → String → Option Entry
  | [], _ => none
  | e :: rest, id => if e.id = id then some e else findEntry rest id

/-- The termination measure: entries whose id is not yet in `seen`. -/
def unseen (es : List Entry) (seen : List String) : Nat :=
  (es.filter (fun e => !containsString seen e.id)).length

theorem containsString_iff (xs : List String) (t : String) :
    containsString xs t = true ↔ t ∈ xs := by
  induction xs with
  | nil => simp [containsString]
  | cons x rest ih =>
    by_cases h : x = t
    · subst h; simp [containsString]
    · simp only [containsString, h, if_false, ih, List.mem_cons]
      constructor
      · intro h'; exact Or.inr h'
      · intro h'; rcases h' with h' | h'
        · exact absurd h'.symm h
        · exact h'

theorem findEntry_spec {es : List Entry} {id : String} {e : Entry}
    (h : findEntry es id = some e) : e ∈ es ∧ e.id = id := by
  induction es with
  | nil => simp [findEntry] at h
  | cons x rest ih =>
    by_cases hx : x.id = id
    · simp [findEntry, hx] at h; subst h; exact ⟨by simp, hx⟩
    · simp [findEntry, hx] at h
      obtain ⟨hm, hid⟩ := ih h
      exact ⟨List.mem_cons_of_mem _ hm, hid⟩

theorem findEntry_none {es : List Entry} {id : String}
    (h : findEntry es id = none) : ∀ e ∈ es, e.id ≠ id := by
  induction es with
  | nil => simp
  | cons x rest ih =>
    by_cases hx : x.id = id
    · simp [findEntry, hx] at h
    · simp [findEntry, hx] at h
      intro e he
      rcases List.mem_cons.mp he with he | he
      · subst he; exact hx
      · exact ih h e he

theorem filter_length_lt {α : Type} (p q : α → Bool) (l : List α)
    (hqp : ∀ x ∈ l, q x = true → p x = true)
    (x : α) (hx : x ∈ l) (hp : p x = true) (hq : q x = false) :
    (l.filter q).length < (l.filter p).length := by
  induction l with
  | nil => simp at hx
  | cons y ys ih =>
    have hle : (ys.filter q).length ≤ (ys.filter p).length := by
      clear ih hx
      induction ys with
      | nil => simp
      | cons z zs ih2 =>
        have hz := hqp z (by simp)
        have ih2' := ih2 (fun w hw hqw => hqp w (by
          rcases List.mem_cons.mp hw with hw | hw
          · exact List.mem_cons.mpr (Or.inl hw)
          · exact List.mem_cons.mpr (Or.inr (List.mem_cons_of_mem _ hw))) hqw)
        cases hqz : q z <;> cases hpz : p z <;> simp [List.filter, hqz, hpz] at hz ⊢ <;> omega
    rcases List.mem_cons.mp hx with hx | hx
    · subst hx; simp [List.filter, hp, hq]; omega
    · have ih' := ih (fun w hw hqw => hqp w (List.mem_cons_of_mem _ hw) hqw) hx
      have hy := hqp y (by simp)
      cases hqy : q y <;> cases hpy : p y <;> simp [List.filter, hqy, hpy] at hy ⊢ <;> omega

theorem unseen_lt {es : List Entry} {seen : List String} {id : String} {e : Entry}
    (hfind : findEntry es id = some e) (hnot : containsString seen id = false) :
    unseen es (id :: seen) < unseen es seen := by
  obtain ⟨hmem, hid⟩ := findEntry_spec hfind
  unfold unseen
  apply filter_length_lt _ _ es _ e hmem
  · subst hid; simp [hnot]
  · subst hid; simp [containsString]
  · intro x _ hq
    simp [containsString] at hq
    by_cases h : id = x.id
    · simp [h] at hq
    · simp [h] at hq; simp [hq]

-- `path_up`, journal.ail:1403-1410: the snapshot as it stands.
def pathUp (es : List Entry) (id : String) (seen : List String) (acc : List Entry) :
    List Entry :=
  if id = "" then acc
  else if hs : containsString seen id = true then []
  else match hf : findEntry es id with
    | none => acc
    | some e => pathUp es e.parentId (id :: seen) (e :: acc)
termination_by unseen es seen
decreasing_by exact unseen_lt hf (by simpa using hs)

-- The same function with D4 rule 1's "stopping at the first repeated id" read as STOP, i.e.
-- `acc` on a repeated id. This is also the body that the eval twin `ev_path_up`
-- (src/eval/journal/reader.ail:1226-1233) carries, and whose sha256 its SOURCE pin records.
def pathUpFixed (es : List Entry) (id : String) (seen : List String) (acc : List Entry) :
    List Entry :=
  if id = "" then acc
  else if hs : containsString seen id = true then acc
  else match hf : findEntry es id with
    | none => acc
    | some e => pathUpFixed es e.parentId (id :: seen) (e :: acc)
termination_by unseen es seen
decreasing_by exact unseen_lt hf (by simpa using hs)

/-! ## One unfolding lemma per branch

`path_up` has four branches; each lemma says which one runs and what it returns. They are
the only way the proofs below look inside the definition. -/

theorem pathUp_empty (es : List Entry) (seen : List String) (acc : List Entry) :
    pathUp es "" seen acc = acc := by
  rw [pathUp]; simp

theorem pathUp_seen {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    (h1 : ¬id = "") (h2 : containsString seen id = true) : pathUp es id seen acc = [] := by
  rw [pathUp, if_neg h1, dif_pos h2]

theorem pathUp_none {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    (h1 : ¬id = "") (h2 : ¬containsString seen id = true) (hf : findEntry es id = none) :
    pathUp es id seen acc = acc := by
  rw [pathUp, if_neg h1, dif_neg h2]
  split
  · rfl
  · rename_i e h; rw [hf] at h; cases h

theorem pathUp_some {es : List Entry} {id : String} {seen : List String} {acc : List Entry}
    {e : Entry} (h1 : ¬id = "") (h2 : ¬containsString seen id = true)
    (hf : findEntry es id = some e) :
    pathUp es id seen acc = pathUp es e.parentId (id :: seen) (e :: acc) := by
  rw [pathUp, if_neg h1, dif_neg h2]
  split
  · rename_i h; rw [hf] at h; cases h
  · rename_i e' h; rw [hf] at h; cases h; rfl

theorem pathUpFixed_empty (es : List Entry) (seen : List String) (acc : List Entry) :
    pathUpFixed es "" seen acc = acc := by
  rw [pathUpFixed]; simp

theorem pathUpFixed_seen {es : List Entry} {id : String} {seen : List String}
    {acc : List Entry} (h1 : ¬id = "") (h2 : containsString seen id = true) :
    pathUpFixed es id seen acc = acc := by
  rw [pathUpFixed, if_neg h1, dif_pos h2]

theorem pathUpFixed_none {es : List Entry} {id : String} {seen : List String}
    {acc : List Entry} (h1 : ¬id = "") (h2 : ¬containsString seen id = true)
    (hf : findEntry es id = none) : pathUpFixed es id seen acc = acc := by
  rw [pathUpFixed, if_neg h1, dif_neg h2]
  split
  · rfl
  · rename_i e h; rw [hf] at h; cases h

theorem pathUpFixed_some {es : List Entry} {id : String} {seen : List String}
    {acc : List Entry} {e : Entry} (h1 : ¬id = "") (h2 : ¬containsString seen id = true)
    (hf : findEntry es id = some e) :
    pathUpFixed es id seen acc = pathUpFixed es e.parentId (id :: seen) (e :: acc) := by
  rw [pathUpFixed, if_neg h1, dif_neg h2]
  split
  · rename_i h; rw [hf] at h; cases h
  · rename_i e' h; rw [hf] at h; cases h; rfl

/-! ## Properties

P5.1 `path_up` terminates on every entry list, including parent cycles.
P5.2 No id occurs twice in the result.
P5.3 The result is a chain: each entry's `parent_id` is the id of the entry before it, and if
     the start id names an entry, the last entry has that id.

All three are stated for the caller's form, `path_up(es, id, [], [])` (journal.ail:1684). -/

/-- P5.3's first half, as a computable predicate. -/
def chainB : List Entry → Bool
  | [] => true
  | [_] => true
  | a :: b :: rest => b.parentId == a.id && chainB (b :: rest)

/-- P5.3's second half: if the start id names an entry, the last entry has that id. -/
def endsAtB (es : List Entry) (id : String) (r : List Entry) : Bool :=
  match findEntry es id with
  | none => true
  | some _ => r.getLast?.map Entry.id == some id

/-! ### P5.1: termination, with an explicit bound

The definition of `pathUp` is accepted by Lean without `partial`, so the model terminates on
every input; the measure is `unseen`. The theorem below makes the bound explicit: the
recursion makes at most `es.length + 1` calls, cycles or not. `pathUpFuel` is the same body
with a fuel counter, structurally recursive, returning `none` when the fuel runs out. -/

def pathUpFuel : Nat → List Entry → String → List String → List Entry → Option (List Entry)
  | 0, _, _, _, _ => none
  | n + 1, es, id, seen, acc =>
    if id = "" then some acc
    else if containsString seen id = true then some []
    else match findEntry es id with
      | none => some acc
      | some e => pathUpFuel n es e.parentId (id :: seen) (e :: acc)

theorem unseen_le_length (es : List Entry) (seen : List String) :
    unseen es seen ≤ es.length := by
  unfold unseen; exact List.length_filter_le _ _

theorem pathUpFuel_eq (es : List Entry) (id : String) (seen : List String) (acc : List Entry) :
    ∀ n, unseen es seen < n → pathUpFuel n es id seen acc = some (pathUp es id seen acc) := by
  induction id, seen, acc using pathUp.induct es with
  | case1 seen acc =>
    intro n hn
    cases n with
    | zero => omega
    | succ n => rw [pathUp_empty]; simp [pathUpFuel]
  | case2 id seen acc hid hs =>
    intro n hn
    cases n with
    | zero => omega
    | succ n => rw [pathUp_seen hid hs]; simp [pathUpFuel, hid, hs]
  | case3 id seen acc hid hs hf =>
    intro n hn
    cases n with
    | zero => omega
    | succ n => rw [pathUp_none hid hs hf]; simp [pathUpFuel, hid, hs, hf]
  | case4 id seen acc hid hs e hf ih =>
    intro n hn
    cases n with
    | zero => omega
    | succ n =>
      have hlt := unseen_lt hf (by simpa using hs)
      rw [pathUp_some hid hs hf]
      simp only [pathUpFuel, hid, hs, if_false, hf]
      exact ih n (by omega)

/-- **P5.1.** On every entry list, cycles included, `path_up(es, id, [], [])` returns within
`es.length + 1` calls, and what it returns is `pathUp`'s value. -/
theorem p5_1_terminates (es : List Entry) (id : String) :
    pathUpFuel (es.length + 1) es id [] [] = some (pathUp es id [] []) :=
  pathUpFuel_eq es id [] [] _ (by have := unseen_le_length es []; omega)

/-! ### P5.2: no id occurs twice -/

theorem pathUp_ids_nodup (es : List Entry) (id : String) (seen : List String)
    (acc : List Entry) :
    acc.map Entry.id = seen → seen.Nodup → ((pathUp es id seen acc).map Entry.id).Nodup := by
  induction id, seen, acc using pathUp.induct es with
  | case1 seen acc =>
    intro hacc hnd; rw [pathUp_empty, hacc]; exact hnd
  | case2 id seen acc hid hs =>
    intro _ _; rw [pathUp_seen hid hs]; simp
  | case3 id seen acc hid hs hf =>
    intro hacc hnd; rw [pathUp_none hid hs hf, hacc]; exact hnd
  | case4 id seen acc hid hs e hf ih =>
    intro hacc hnd
    rw [pathUp_some hid hs hf]
    apply ih
    · simp [hacc, (findEntry_spec hf).2]
    · refine List.nodup_cons.mpr ⟨?_, hnd⟩
      intro hm; exact hs ((containsString_iff _ _).mpr hm)

/-- **P5.2.** No id occurs twice in `path_up(es, id, [], [])`. -/
theorem p5_2_no_repeated_id (es : List Entry) (id : String) :
    ((pathUp es id [] []).map Entry.id).Nodup :=
  pathUp_ids_nodup es id [] [] rfl List.nodup_nil

/-! ### P5.3, first half: the result is a chain -/

/-- The head of `acc`, if any, names `id` as its parent. -/
def headParentIs (acc : List Entry) (id : String) : Prop :=
  match acc with
  | [] => True
  | a :: _ => a.parentId = id

theorem chainB_cons {e : Entry} {acc : List Entry} {id : String}
    (hc : chainB acc = true) (hh : headParentIs acc id) (hid : e.id = id) :
    chainB (e :: acc) = true := by
  cases acc with
  | nil => rfl
  | cons a rest =>
    have hh' : a.parentId = id := hh
    have h1 : (a.parentId == e.id) = true := by
      rw [hh', hid]; exact decide_eq_true rfl  -- not `beq_self_eq_true`: that uses Classical.choice
    show (a.parentId == e.id && chainB (a :: rest)) = true
    rw [h1, hc]; rfl

theorem pathUp_chain (es : List Entry) (id : String) (seen : List String) (acc : List Entry) :
    chainB acc = true → headParentIs acc id → chainB (pathUp es id seen acc) = true := by
  induction id, seen, acc using pathUp.induct es with
  | case1 seen acc =>
    intro hc _; rw [pathUp_empty]; exact hc
  | case2 id seen acc hid hs =>
    intro _ _; rw [pathUp_seen hid hs]; rfl
  | case3 id seen acc hid hs hf =>
    intro hc _; rw [pathUp_none hid hs hf]; exact hc
  | case4 id seen acc hid hs e hf ih =>
    intro hc hh
    rw [pathUp_some hid hs hf]
    exact ih (chainB_cons hc hh (findEntry_spec hf).2) rfl

/-- **P5.3, first half.** `path_up(es, id, [], [])` is a chain: each entry's `parent_id` is
the id of the entry before it. -/
theorem p5_3_chain (es : List Entry) (id : String) :
    chainB (pathUp es id [] []) = true :=
  pathUp_chain es id [] [] rfl trivial

/-! ### P5.3, second half: FALSE on the snapshot

The registered statement: if the start id names an entry, the last entry has that id. -/

/-- **Counterexample to P5.3 (cycle).** A single entry whose parent is itself. The start id
names it, `find_entry` finds it, and the snapshot returns `[]`: the climb reaches `a` a second
time, and the repeated-id branch discards the whole accumulated path instead of stopping. -/
theorem bug_p5_3_cycle_returns_empty :
    let es := [{ id := "a", parentId := "a", seq := 0 : Entry }]
    findEntry es "a" = some { id := "a", parentId := "a", seq := 0 } ∧
    pathUp es "a" [] [] = [] ∧
    endsAtB es "a" (pathUp es "a" [] []) = false := by
  have h : pathUp [{ id := "a", parentId := "a", seq := 0 : Entry }] "a" [] [] = [] := by
    rw [pathUp_some (by decide) (by decide) (by decide : findEntry
        [{ id := "a", parentId := "a", seq := 0 : Entry }] "a"
        = some { id := "a", parentId := "a", seq := 0 })]
    exact pathUp_seen (by decide) (by decide)
  refine ⟨by decide, h, ?_⟩
  simp only [h]; decide

/-- The same defect on the shape that matters to the fold: a header (`h`, seq 0) whose
`parent_id` points at the leaf (`c`), so the parent chain is a cycle through the root. D4
rule 1 asks for `[h, b, c]`, header first; the snapshot returns `[]`, which `fold_journal`
turns into `Refusal::Header` (journal.ail:1685-1686). -/
def cycleEs : List Entry :=
  [{ id := "h", parentId := "c", seq := 0 },
   { id := "b", parentId := "h", seq := 1 },
   { id := "c", parentId := "b", seq := 2 }]

theorem bug_p5_3_cycle_through_header :
    pathUp cycleEs "c" [] [] = [] ∧
    pathUpFixed cycleEs "c" [] [] = cycleEs ∧
    endsAtB cycleEs "c" (pathUp cycleEs "c" [] []) = false := by
  have h3 : findEntry cycleEs "c" = some { id := "c", parentId := "b", seq := 2 } := by decide
  have h2 : findEntry cycleEs "b" = some { id := "b", parentId := "h", seq := 1 } := by decide
  have h1 : findEntry cycleEs "h" = some { id := "h", parentId := "c", seq := 0 } := by decide
  have hbug : pathUp cycleEs "c" [] [] = [] := by
    rw [pathUp_some (by decide) (by decide) h3, pathUp_some (by decide) (by decide) h2,
      pathUp_some (by decide) (by decide) h1]
    exact pathUp_seen (by decide) (by decide)
  refine ⟨hbug, ?_, ?_⟩
  · rw [pathUpFixed_some (by decide) (by decide) h3, pathUpFixed_some (by decide) (by decide) h2,
      pathUpFixed_some (by decide) (by decide) h1]
    rw [pathUpFixed_seen (by decide) (by decide)]; rfl
  · rw [hbug]; decide

/-- **Counterexample to P5.3 (empty id).** `""` is both the "no parent" sentinel
(`journal_entry_of_json`, journal.ail:722) and a string the decoder accepts as an `id`
(`at_string`, :668-670). An entry with id `""` is named by the start id `""`, and
`path_up` returns `[]` from its first branch. Unlike the cycle, the fix below keeps this:
it is the sentinel's collision, not the repeated-id branch. -/
theorem bug_p5_3_empty_id :
    let es := [{ id := "", parentId := "", seq := 0 : Entry }]
    (findEntry es "").isSome = true ∧ pathUp es "" [] [] = [] ∧
    pathUpFixed es "" [] [] = [] ∧ endsAtB es "" (pathUp es "" [] []) = false := by
  refine ⟨by decide, pathUp_empty _ _ _, pathUpFixed_empty _ _ _, ?_⟩
  simp only [pathUp_empty]; decide

/-! ## Step 8: the fix, `acc` on a repeated id

It satisfies all three properties, P5.3 in full except for the start id `""`; and it changes
the snapshot's result only where the snapshot returned `[]`. -/

theorem pathUpFixed_ids_nodup (es : List Entry) (id : String) (seen : List String)
    (acc : List Entry) :
    acc.map Entry.id = seen → seen.Nodup →
      ((pathUpFixed es id seen acc).map Entry.id).Nodup := by
  induction id, seen, acc using pathUpFixed.induct es with
  | case1 seen acc =>
    intro hacc hnd; rw [pathUpFixed_empty, hacc]; exact hnd
  | case2 id seen acc hid hs =>
    intro hacc hnd; rw [pathUpFixed_seen hid hs, hacc]; exact hnd
  | case3 id seen acc hid hs hf =>
    intro hacc hnd; rw [pathUpFixed_none hid hs hf, hacc]; exact hnd
  | case4 id seen acc hid hs e hf ih =>
    intro hacc hnd
    rw [pathUpFixed_some hid hs hf]
    apply ih
    · simp [hacc, (findEntry_spec hf).2]
    · refine List.nodup_cons.mpr ⟨?_, hnd⟩
      intro hm; exact hs ((containsString_iff _ _).mpr hm)

theorem pathUpFixed_chain (es : List Entry) (id : String) (seen : List String)
    (acc : List Entry) :
    chainB acc = true → headParentIs acc id → chainB (pathUpFixed es id seen acc) = true := by
  induction id, seen, acc using pathUpFixed.induct es with
  | case1 seen acc =>
    intro hc _; rw [pathUpFixed_empty]; exact hc
  | case2 id seen acc hid hs =>
    intro hc _; rw [pathUpFixed_seen hid hs]; exact hc
  | case3 id seen acc hid hs hf =>
    intro hc _; rw [pathUpFixed_none hid hs hf]; exact hc
  | case4 id seen acc hid hs e hf ih =>
    intro hc hh
    rw [pathUpFixed_some hid hs hf]
    exact ih (chainB_cons hc hh (findEntry_spec hf).2) rfl

/-- Once `acc` is non-empty its last entry never changes: the climb only prepends. -/
theorem pathUpFixed_last (es : List Entry) (id : String) (seen : List String)
    (acc : List Entry) (x : Entry) :
    acc.getLast? = some x → (pathUpFixed es id seen acc).getLast? = some x := by
  induction id, seen, acc using pathUpFixed.induct es with
  | case1 seen acc =>
    intro h; rw [pathUpFixed_empty]; exact h
  | case2 id seen acc hid hs =>
    intro h; rw [pathUpFixed_seen hid hs]; exact h
  | case3 id seen acc hid hs hf =>
    intro h; rw [pathUpFixed_none hid hs hf]; exact h
  | case4 id seen acc hid hs e hf ih =>
    intro h
    rw [pathUpFixed_some hid hs hf]
    apply ih
    cases acc with
    | nil => simp at h
    | cons a rest => rw [List.getLast?_cons_cons]; exact h

/-- **The fix satisfies P5.2 and P5.3** (the last clause for every start id but `""`); its
P5.1 is its definition's measure, the same as the snapshot's. -/
theorem fix_p5_2 (es : List Entry) (id : String) :
    ((pathUpFixed es id [] []).map Entry.id).Nodup :=
  pathUpFixed_ids_nodup es id [] [] rfl List.nodup_nil

theorem fix_p5_3_chain (es : List Entry) (id : String) :
    chainB (pathUpFixed es id [] []) = true :=
  pathUpFixed_chain es id [] [] rfl trivial

theorem fix_p5_3_ends_at_start (es : List Entry) (id : String) (hid : ¬id = "") :
    endsAtB es id (pathUpFixed es id [] []) = true := by
  unfold endsAtB
  split
  · rfl
  · rename_i e hf
    have hspec := (findEntry_spec hf).2
    rw [pathUpFixed_some hid (by simp [containsString]) hf]
    rw [pathUpFixed_last es e.parentId [id] [e] e rfl]
    show (some e.id == some id) = true
    rw [hspec]; exact (decide_eq_true rfl : (id == id) = true)

/-- The fix changes a result only where the snapshot returned `[]`: on every input where the
snapshot returns a non-empty path, the two agree. -/
theorem fix_agrees_or_snapshot_empty (es : List Entry) (id : String) (seen : List String)
    (acc : List Entry) :
    pathUp es id seen acc = pathUpFixed es id seen acc ∨ pathUp es id seen acc = [] := by
  induction id, seen, acc using pathUp.induct es with
  | case1 seen acc =>
    left; rw [pathUp_empty, pathUpFixed_empty]
  | case2 id seen acc hid hs =>
    right; exact pathUp_seen hid hs
  | case3 id seen acc hid hs hf =>
    left; rw [pathUp_none hid hs hf, pathUpFixed_none hid hs hf]
  | case4 id seen acc hid hs e hf ih =>
    rw [pathUp_some hid hs hf, pathUpFixed_some hid hs hf]
    exact ih

/-- On the snapshot, P5.3's second half fails ONLY by returning `[]`: whenever `path_up`
returns a non-empty path from a non-empty start id, the path ends at the start entry. So the
two counterexample shapes above are the whole of the violation: a repeated id on the climb
(the result is then always `[]`) and the start id `""`. -/
theorem p5_3_ends_at_start_unless_empty (es : List Entry) (id : String) (hid : ¬id = "")
    (hne : pathUp es id [] [] ≠ []) :
    endsAtB es id (pathUp es id [] []) = true := by
  rcases fix_agrees_or_snapshot_empty es id [] [] with h | h
  · rw [h]; exact fix_p5_3_ends_at_start es id hid
  · exact absurd h hne

/-! ## Satisfying witness (non-vacuity)

The universally quantified theorems above have no hypotheses beyond the caller's form, except
`fix_p5_3_ends_at_start` (`id ≠ ""`). A concrete input that meets it: a three-entry chain whose
path is the whole list, root first, on which the snapshot and the fix agree. -/

def chainEs : List Entry :=
  [{ id := "r", parentId := "", seq := 0 },
   { id := "m", parentId := "r", seq := 1 },
   { id := "l", parentId := "m", seq := 2 }]

theorem witness_chain :
    pathUp chainEs "l" [] [] = chainEs ∧
    endsAtB chainEs "l" (pathUp chainEs "l" [] []) = true := by
  have hp : pathUp chainEs "l" [] [] = chainEs := by
    rw [pathUp_some (by decide) (by decide)
          (by decide : findEntry chainEs "l" = some { id := "l", parentId := "m", seq := 2 }),
        pathUp_some (by decide) (by decide)
          (by decide : findEntry chainEs "m" = some { id := "m", parentId := "r", seq := 1 }),
        pathUp_some (by decide) (by decide)
          (by decide : findEntry chainEs "r" = some { id := "r", parentId := "", seq := 0 }),
        pathUp_empty]
    rfl
  refine ⟨hp, ?_⟩
  rw [hp]; decide

#print axioms p5_1_terminates
#print axioms p5_2_no_repeated_id
#print axioms p5_3_chain
#print axioms bug_p5_3_cycle_returns_empty
#print axioms bug_p5_3_cycle_through_header
#print axioms bug_p5_3_empty_id
#print axioms fix_p5_2
#print axioms fix_p5_3_chain
#print axioms fix_p5_3_ends_at_start
#print axioms fix_agrees_or_snapshot_empty
#print axioms witness_chain
#print axioms p5_3_ends_at_start_unless_empty
#print axioms pathUpFuel_eq
#print axioms pathUp_ids_nodup
#print axioms pathUp_chain
#print axioms pathUpFixed_ids_nodup
#print axioms pathUpFixed_chain
#print axioms pathUpFixed_last
#print axioms chainB_cons
#print axioms pathUp_empty
#print axioms pathUp_seen
#print axioms pathUp_none
#print axioms pathUp_some
#print axioms pathUpFixed_empty
#print axioms pathUpFixed_seen
#print axioms pathUpFixed_none
#print axioms pathUpFixed_some
#print axioms containsString_iff
#print axioms findEntry_spec
#print axioms findEntry_none
#print axioms filter_length_lt
#print axioms unseen_lt
#print axioms unseen_le_length
/-
Appended to PathUpModel.lean by run_diff.sh. The same inputs, in the same order, as
enumerate_pathup.ail; see that file's header for the two families and the line format.
-/

def idsA : List String := ["", "a", "b", "c"]
def parsA : List String := ["", "a", "b", "c", "z"]
def startsA : List String := ["", "a", "b", "c", "z"]

def alphaE (k seq : Nat) : Entry :=
  { id := idsA.getD (k / 5) "?", parentId := parsA.getD (k % 5) "?", seq := seq }

def entriesOf (s : List Nat) : List Entry :=
  (s.zip (List.range s.length)).map (fun (k, p) => alphaE k p)

def seqsOfLen : Nat → List (List Nat)
  | 0 => [[]]
  | n + 1 => (seqsOfLen n).flatMap (fun s => (List.range 20).map (fun i => s ++ [i]))

def varSeen (v : Nat) : List String :=
  if v = 1 then ["a"] else if v = 3 then ["c", "a"] else []

def varAcc (v : Nat) : List Entry :=
  if v ≥ 2 then [{ id := "q", parentId := "q", seq := 9 }] else []

def joinC (xs : List String) : String := String.intercalate "," xs

def showResult (r : List Entry) : String :=
  s!"{joinC (r.map (fun e => toString e.seq))}|{r.length}"

def eid (i : Nat) : String := s!"e{i}"

def ring (n k : Nat) : List Entry :=
  (List.range n).map (fun i =>
    { id := eid i, seq := i,
      parentId := if i = 0 then (if k = n then "" else eid k) else eid (i - 1) })

def ids2 : List String := ["", "a", "b", "c", "d", "e", "f"]
def pars2 : List String := ["", "a", "b", "c", "d", "e", "f", "z"]
def lcg (s : Nat) : Nat := (s * 1103515245 + 12345) % 2147483648
def pick (s m : Nat) : Nat := (s / 65536) % m

/-- `gen_entries(s, i, n)`, with the count of entries still to draw as the recursion. -/
def genEntries : Nat → Nat → Nat → Nat × List Entry
  | s, _, 0 => (s, [])
  | s, i, k + 1 =>
    let s1 := lcg s
    let s2 := lcg s1
    let e : Entry := { id := ids2.getD (pick s1 7) "?", parentId := pars2.getD (pick s2 8) "?", seq := i }
    let (s', es) := genEntries s2 (i + 1) k
    (s', e :: es)

def enc (e : Entry) : String := s!"{e.id}>{e.parentId}"

#eval show IO Unit from do
  for len in [0, 1, 2, 3] do
    for s in seqsOfLen len do
      let es := entriesOf s
      for st in List.range 5 do
        let nv := if s.length ≤ 2 then 4 else 1
        for v in List.range nv do
          let r := pathUpFixed es (startsA.getD st "?") (varSeen v) (varAcc v)
          IO.println s!"B|{joinC (s.map toString)}|{st}|{v}|{showResult r}"
  for n in (List.range 9).drop 1 do
    for k in List.range (n + 1) do
      for j in List.range (n + 1) do
        let r := pathUpFixed (ring n k) (eid j) [] []
        IO.println s!"R|{n}|{k}|{j}|{showResult r}"
  let mut s := 42
  for t in List.range 2000 do
    let s1 := lcg s
    let n := 4 + pick s1 7
    let (gs, es) := genEntries s1 0 n
    let s2 := lcg gs
    let start := pars2.getD (pick s2 8) "?"
    let r := pathUpFixed es start [] []
    IO.println s!"X|{t}|{String.intercalate ";" (es.map enc)}|{start}|{showResult r}"
    s := s2
