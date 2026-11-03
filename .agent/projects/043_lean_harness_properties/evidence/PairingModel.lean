/-
PairingModel.lean — the worked example for RESEARCH-lean-harness-properties.md §6.

CHECKED 2026-11-03, after this header was written: Lean 4.28.0 accepts the file with no
error, no theorem uses an axiom beyond `propext` and `Quot.sound`, and `hostPending` matched
the real `updatePending` on 16,105 histories (diff/README.md). `pairing` has still not been
run against `ailang run`. The header below is as first written.

A Lean model of two implementations of one rule, at origin/main 43530c0a:

  * `pair_step`, and the fold over it in `finish_fold`  (src/core/journal.ail)
    — the journal fold's pairing check, ADR-003 D4 rules 3 and 4.
  * `updatePending`                                    (src/tui/src/session-journal.ts)
    — the host's "three-line TypeScript twin" of the fold's trailing-pair rule,
      which becomes `exit.pending_tool_calls`.

What the model keeps and what it abstracts:

  * A message is its role, the ids of its `tool_calls` and its `tool_call_id`. Neither
    function reads anything else. `pair_step` reads the role only as `role == "tool"`, so
    the other three roles are kept for readability, not because they behave differently.
  * Ids are `String`: both sides only compare them for equality, and the host also tests
    for `""`.
  * `seq` is the message's index. In the source it is the journal entry's `seq`; it only
    ever reaches the refusal value and `cur_seq`, never a branch.

Not yet done, and the reason none of this is a finding: no differential test has run
this model against `ailang run`, and the `bun` half has run alone (diff/README.md). Every
statement below is about the model.

NOT YET CHECKED BY LEAN. Written for Lean 4.28.0, core only (no Mathlib, no Lake):
`lean PairingModel.lean`. The session that wrote it could not install a toolchain:
`release.lean-lang.org` answers 403 from its sandbox (2026-11-03). Until a run is recorded
in diff/README.md, no theorem here is "proved", and the axiom report at the end of the file
has not been read. Written without `sorry` or `native_decide`.
-/

inductive Role where
  | system | user | assistant | tool
  deriving DecidableEq, Repr

structure Msg where
  role   : Role
  calls  : List String   -- `call_ids(h.m.tool_calls)`
  callId : String        -- `h.m.tool_call_id`
  deriving DecidableEq, Repr

/-! ## The AILANG side: `journal.ail` -/

-- `contains_string`, `without_string`: same recursion as the source.
def containsString : List String → String → Bool
  | [], _ => false
  | x :: rest, t => if x = t then true else containsString rest t

def withoutString : List String → String → List String
  | [], _ => []
  | x :: rest, t => if x = t then withoutString rest t else x :: withoutString rest t

structure PairAcc where
  err     : Option Int
  openIds : List String
  curIds  : List String
  curSeq  : Int
  deriving DecidableEq, Repr

-- `pair_step`, branch for branch.
def pairStep (acc : PairAcc) (h : Nat × Msg) : PairAcc :=
  match acc.err with
  | some _ => acc
  | none =>
    if h.2.role = .tool then
      if containsString acc.curIds h.2.callId
      then { acc with openIds := withoutString acc.openIds h.2.callId }
      else { acc with err := some h.1 }
    else if acc.openIds.length > 0 then
      { acc with err := some acc.curSeq }
    else if h.2.calls.length > 0 then
      { acc with openIds := h.2.calls, curIds := h.2.calls, curSeq := h.1 }
    else acc

-- `pair0` in `finish_fold`.
def pair0 : PairAcc := { err := none, openIds := [], curIds := [], curSeq := -1 }

def tag : Nat → List Msg → List (Nat × Msg)
  | _, [] => []
  | n, m :: ms => (n, m) :: tag (n + 1) ms

-- `List.foldl(pair_step, pair0, forward)`. The fold's verdict on pairing is `.err`,
-- and `.openIds` is what it records as `SessionState.dangling`.
def pairing (ms : List Msg) : PairAcc := (tag 0 ms).foldl pairStep pair0

/-! ## The TypeScript side: `session-journal.ts` -/

-- `updatePending`: an assistant's `tool_calls` become the open set (empty ids dropped);
-- a `tool_call_id` closes the id it answers; anything else leaves the set alone.
-- Note that it never reads the role.
def updatePending (opn : List String) (m : Msg) : List String :=
  if m.calls.length > 0 then m.calls.filter (fun id => id != "")
  else if m.callId != "" then opn.filter (fun id => id != m.callId)
  else opn

def hostPending (ms : List Msg) : List String := ms.foldl updatePending []

/-! ## Fixtures -/

def asst (ids : List String) : Msg := { role := .assistant, calls := ids, callId := "" }
def result (id : String) : Msg := { role := .tool, calls := [], callId := id }
def user : Msg := { role := .user, calls := [], callId := "" }

/-! ## 1. Two shapes the fold's pairing check admits

D4 states the rule as: every tool result answers "a call in the assistant message before
it", and every call except a trailing one is answered. These two theorems record how
`pair_step` reads that sentence. Whether either shape is wrong is a question about D4's
intent, not about the code; §6 of the note sets it out. -/

-- A second result for a call that was already answered.
theorem admits_duplicate_result :
    (pairing [asst ["a"], result "a", result "a"]).err = none := by decide

-- A result for a closed batch, after a user message. `cur_ids` is replaced only by the
-- next assistant that makes calls, so it still holds "a".
theorem admits_result_after_user :
    (pairing [asst ["a"], result "a", user, result "a"]).err = none := by decide

-- Controls: the shapes D4 does name are refused.
theorem refuses_unanswered_call_before_user :
    (pairing [asst ["a", "b"], result "a", user]).err = some 0 := by decide

theorem refuses_result_for_unmade_call :
    (pairing [asst ["a"], result "b"]).err = some 1 := by decide

-- Satisfiability witness for the theorem in §2: its hypotheses hold of a real history.
theorem trailing_call_is_dangling :
    (pairing [asst ["a", "b"], result "a"]).err = none ∧
    (pairing [asst ["a", "b"], result "a"]).openIds = ["b"] ∧
    hostPending [asst ["a", "b"], result "a"] = ["b"] := by decide

/-! ## 2. The cross-language contract: host twin = fold, under two named hypotheses

`exit.pending_tool_calls` (host) must name the calls the next resume will strip
(`SessionState.dangling`, fold). Stated for every history the fold's pairing check
accepts, given:

  (H1) no call id is empty. The full fold refuses most such histories, but NOT all:
       an empty-id call in the TRAILING batch stays in `open_ids`, so it is in
       `dangling`, and `strip_dangling` removes it (`keep_calls` drops the dangling
       ids) before `history_valid_transcript` reads the message (journal.ail:1653-1670,
       1722-1731). So H1 is a real assumption in the trailing position;
       `h1_not_free_in_trailing_batch` in §3 is the case;
  (H2) no tool message carries tool calls — nothing in the fold refuses that, so this
       one is a real assumption about what the driver writes. §3 shows it is needed. -/

theorem err_sticky (xs : List (Nat × Msg)) (acc : PairAcc) (r : Int)
    (h : acc.err = some r) : (xs.foldl pairStep acc) = acc := by
  induction xs generalizing acc with
  | nil => rfl
  | cons x xs ih =>
    simp only [List.foldl]
    have : pairStep acc x = acc := by simp [pairStep, h]
    rw [this]; exact ih acc h

theorem containsString_mem {xs : List String} {t : String}
    (h : containsString xs t = true) : t ∈ xs := by
  induction xs with
  | nil => simp [containsString] at h
  | cons x xs ih =>
    by_cases hx : x = t
    · subst hx; simp
    · simp [containsString, hx] at h; exact List.mem_cons_of_mem _ (ih h)

theorem filter_eq_without (xs : List String) (t : String) :
    xs.filter (fun id => id != t) = withoutString xs t := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    by_cases hx : x = t
    · simp [withoutString, hx, ih]
    · simp [withoutString, hx, ih]

theorem filter_nonempty_id (xs : List String) (h : ∀ c ∈ xs, c ≠ "") :
    xs.filter (fun id => id != "") = xs := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    have hx : x ≠ "" := h x (by simp)
    have hr : ∀ c ∈ xs, c ≠ "" := fun c hc => h c (by simp [hc])
    simp [hx, ih hr]

-- One step keeps the host's open set equal to the fold's, and keeps every id in
-- `cur_ids` non-empty (the invariant that rules out an empty result id matching).
theorem step_agrees (acc : PairAcc) (x : Nat × Msg) (opn : List String)
    (hacc : acc.err = none) (hopen : opn = acc.openIds)
    (hcur : ∀ c ∈ acc.curIds, c ≠ "")
    (h1x : ∀ c ∈ x.2.calls, c ≠ "")
    (h2x : x.2.role = .tool → x.2.calls = [])
    (hstep : (pairStep acc x).err = none) :
    updatePending opn x.2 = (pairStep acc x).openIds ∧
    (∀ c ∈ (pairStep acc x).curIds, c ≠ "") := by
  obtain ⟨seq, role, calls, cid⟩ := x
  subst hopen
  simp only at h1x h2x
  cases role
  case tool =>
    have hc : calls = [] := h2x rfl
    subst hc
    by_cases hin : containsString acc.curIds cid = true
    · have hne : cid ≠ "" := hcur cid (containsString_mem hin)
      refine ⟨?_, ?_⟩
      · simp [pairStep, updatePending, hacc, hin, hne, filter_eq_without]
      · simpa [pairStep, hacc, hin] using hcur
    · simp [pairStep, hacc, hin] at hstep
  all_goals
    by_cases hopn : acc.openIds.length > 0
    · simp [pairStep, hacc, hopn] at hstep
    · have hempty : acc.openIds = [] := List.eq_nil_of_length_eq_zero (by omega)
      by_cases hcalls : calls.length > 0
      · refine ⟨?_, ?_⟩
        · simp [pairStep, updatePending, hacc, hopn, hcalls, filter_nonempty_id calls h1x]
        · simpa [pairStep, hacc, hopn, hcalls] using h1x
      · have hcnil : calls = [] := List.eq_nil_of_length_eq_zero (by omega)
        subst hcnil
        refine ⟨?_, ?_⟩
        · simp [pairStep, updatePending, hacc, hempty]
        · simpa [pairStep, hacc, hempty] using hcur

theorem agrees_fold (xs : List (Nat × Msg)) (acc : PairAcc) (opn : List String)
    (h1 : ∀ x ∈ xs, ∀ c ∈ x.2.calls, c ≠ "")
    (h2 : ∀ x ∈ xs, x.2.role = .tool → x.2.calls = [])
    (hacc : acc.err = none) (hopen : opn = acc.openIds)
    (hcur : ∀ c ∈ acc.curIds, c ≠ "")
    (hok : (xs.foldl pairStep acc).err = none) :
    (xs.map Prod.snd).foldl updatePending opn = (xs.foldl pairStep acc).openIds := by
  induction xs generalizing acc opn with
  | nil => simpa using hopen
  | cons x xs ih =>
    simp only [List.map_cons, List.foldl_cons] at hok ⊢
    cases hstep : (pairStep acc x).err with
    | some r =>
      simp [err_sticky xs _ r hstep, hstep] at hok
    | none =>
      obtain ⟨heq, hcur'⟩ :=
        step_agrees acc x opn hacc hopen hcur (h1 x (by simp)) (h2 x (by simp)) hstep
      exact ih _ _ (fun y hy => h1 y (by simp [hy])) (fun y hy => h2 y (by simp [hy]))
        hstep heq hcur' hok

theorem tag_map (n : Nat) (ms : List Msg) : (tag n ms).map Prod.snd = ms := by
  induction ms generalizing n with
  | nil => rfl
  | cons m ms ih => simp [tag, ih]

theorem tag_mem {n : Nat} {ms : List Msg} {x : Nat × Msg} (h : x ∈ tag n ms) : x.2 ∈ ms := by
  induction ms generalizing n with
  | nil => simp [tag] at h
  | cons m ms ih =>
    simp only [tag, List.mem_cons] at h
    rcases h with h | h
    · subst h; simp
    · exact List.mem_cons_of_mem _ (ih h)

theorem host_twin_agrees (ms : List Msg)
    (h1 : ∀ m ∈ ms, ∀ c ∈ m.calls, c ≠ "")
    (h2 : ∀ m ∈ ms, m.role = .tool → m.calls = [])
    (hok : (pairing ms).err = none) :
    hostPending ms = (pairing ms).openIds := by
  unfold hostPending
  unfold pairing at hok ⊢
  have := agrees_fold (tag 0 ms) pair0 []
    (fun x hx => h1 x.2 (tag_mem hx)) (fun x hx => h2 x.2 (tag_mem hx))
    rfl rfl (by simp [pair0]) hok
  rwa [tag_map] at this

/-! ## 3. Without (H2), or without (H1) in the trailing batch, the two sides disagree

A tool message that also carries `tool_calls`. `history_valid_transcript` checks a tool
message for a non-empty `tool_call_id` only, so the fold accepts this history; the fold
reads it as a result (role first), the host as a new batch (calls first). -/

theorem twin_disagrees_without_h2 :
    let ms := [asst ["a"], { role := .tool, calls := ["b"], callId := "a" : Msg }]
    (pairing ms).err = none ∧ (pairing ms).openIds = [] ∧ hostPending ms = ["b"] := by
  decide

/-! Without (H1), in the trailing batch, the two sides disagree too. The pairing check
accepts with `""` open; the full fold then strips that call from the assistant
(`strip_dangling`), so `history_valid_transcript` never sees an empty id and the fold
accepts with `dangling = [""]`. The host filters empty ids, so it records no pending call.
The strip and the transcript check are not in this model; that half of the claim rests
on reading journal.ail:1653-1670 and 1722-1731, not on Lean. -/

theorem h1_not_free_in_trailing_batch :
    (pairing [asst ["a", ""], result "a"]).err = none ∧
    (pairing [asst ["a", ""], result "a"]).openIds = [""] ∧
    hostPending [asst ["a", ""], result "a"] = [] := by decide

#print axioms admits_duplicate_result
#print axioms admits_result_after_user
#print axioms twin_disagrees_without_h2
#print axioms h1_not_free_in_trailing_batch
#print axioms host_twin_agrees
#print axioms refuses_unanswered_call_before_user
#print axioms refuses_result_for_unmade_call
#print axioms trailing_call_is_dangling
