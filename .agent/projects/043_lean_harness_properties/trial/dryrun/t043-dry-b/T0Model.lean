/-
T0Model.lean — dry run, target T0 (arm B, replicate 1).

Models, in Lean 4.28.0, core only (no Mathlib, no Lake):
  * `pair_step`            src/core/journal.ail:1634-1652
  * `finish_fold` (pairing fold only: `pair0` and `List.foldl(pair_step, ...)`, and
    `dangling = pairs.open_ids`)  src/core/journal.ail:1715-1721
  * helpers `contains_string`, `without_string`, `call_ids`  src/core/journal.ail:1364-1374
  * `updatePending`        src/tui/src/session-journal.ts:865-875  (-> exit.pending_tool_calls,
                           session-journal.ts:820-829)

Snapshot: /home/motoko/trial-043/s/t043-dry-b/tree (no git). The model below began as a
transcription of the project's evidence/PairingModel.lean; each definition was re-read
against the snapshot's source lines named above and found to match branch for branch, so
step (2) started from it. Differential runs: diff/run_diff.sh, results in SUMMARY.md.

Property P0.1 is `host_twin_agrees` (pairing level) plus `p01_fold` (fold level: the full
fold's `dangling` is `pairs.open_ids`, and the full fold accepts only if pairing does).
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

/-! ## 4. P0.1 at the level of `finish_fold` (journal.ail:1715-1750)

`finish_fold` runs the pairing fold; on `Some(r)` it refuses; otherwise it sets
`dangling = pairs.open_ids` and either refuses on a later check (head prefix,
`history_from_seed`, `history_valid_transcript`, over the stripped messages) or returns
`Ok(st)` with `st.dangling = dangling`. The later checks never change `dangling`, so they
are modelled as an arbitrary predicate `post` on the history. -/

def finishFold (post : List Msg → Bool) (ms : List Msg) : Option (List String) :=
  match (pairing ms).err with
  | some _ => none
  | none => if post ms then some (pairing ms).openIds else none

-- P0.1: for every history the fold accepts, with no empty call id (H1) and no tool
-- message carrying calls (H2), exit.pending_tool_calls (= hostPending) = SessionState.dangling.
theorem p01_fold (post : List Msg → Bool) (ms : List Msg) (d : List String)
    (h1 : ∀ m ∈ ms, ∀ c ∈ m.calls, c ≠ "")
    (h2 : ∀ m ∈ ms, m.role = .tool → m.calls = [])
    (hacc : finishFold post ms = some d) :
    hostPending ms = d := by
  unfold finishFold at hacc
  cases herr : (pairing ms).err with
  | some r => simp [herr] at hacc
  | none =>
    simp only [herr] at hacc
    by_cases hp : post ms = true
    · simp [hp] at hacc
      rw [← hacc]; exact host_twin_agrees ms h1 h2 herr
    · simp [hp] at hacc

/-! ## 5. Exploratory: shapes the pairing check admits that D4 seems to exclude (bug_ form)

X-1: a second result for an already-answered call is accepted (pair_step checks the result
against `cur_ids`, the batch's ids, not `open_ids`, the still-open ones).
X-2: a result arriving after a user message, for a closed batch, is accepted.
X-3: an empty call id in the trailing batch stays dangling in the fold (`[""]`) while the
host drops it (`[]`): P0.1's hypothesis H1 is load-bearing and the two sides diverge. -/

theorem bug_X1_duplicate_result_accepted :
    (pairing [asst ["a"], result "a", result "a"]).err = none ∧
    (pairing [asst ["a"], result "a", result "a"]).openIds = [] := by decide

theorem bug_X2_result_after_user_accepted :
    (pairing [asst ["a"], result "a", user, result "a"]).err = none := by decide

theorem bug_X3_trailing_empty_id :
    (pairing [asst [""]]).err = none ∧ (pairing [asst [""]]).openIds = [""] ∧
    hostPending [asst [""]] = [] := by decide

#print axioms p01_fold
#print axioms bug_X1_duplicate_result_accepted
#print axioms bug_X2_result_after_user_accepted
#print axioms bug_X3_trailing_empty_id
#print axioms err_sticky
#print axioms containsString_mem
#print axioms filter_eq_without
#print axioms filter_nonempty_id
#print axioms step_agrees
#print axioms agrees_fold
#print axioms tag_map
#print axioms tag_mem
