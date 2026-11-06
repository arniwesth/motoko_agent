/-
T3Model.lean — Kiro-method model for target T3 (ADR-003 D1, D4): the journal writer twin and
the round trip. Lean 4.28.0, core only (no Mathlib, no Lake): `lean T3Model.lean`.

Source modelled (snapshot at /home/motoko/trial-043/s/t043-t3-b1/tree):

  HOST  src/tui/src/session-journal.ts
          :484-555  SessionJournal.record          (routing; only the history-relevant arms)
          :576-664  recordSeed                     (D1's three `history_seeded` arms)
          :666-688  recordAppended
          :690-726  recordReplaced                 (incl. the `first_kept` range check :704-713)
          :760-797  recordResumed                  (arming of `replaceNextSeed`, :790-791)
          :849-874  noteHistoryMessage, replaceLastHistoryMessage, updatePending
  TWIN  src/core/journal.ail
          :1923-1942 TwinAcc, :1944-1949 twin_has_dangling, :1975-1990 twin_seed_messages,
          :1992-2128 twin_event, :2137-2149 journal_lines_of_records
  FOLD  src/core/journal.ail
          :1453-1474 fold_append, :1490-1515 fold_replace, :1523-1620 fold_entry,
          :1634-1651 pair_step, :1653-1675 strip_dangling/keep_calls,
          :1677-1713 fold_journal, :1715-1754 finish_fold
        src/core/phase_vocab.ail :84 system_is_head_prefix, :115 valid_message_transcript

What the model keeps and what it abstracts (each choice was checked by the differential test
in diff/, see SUMMARY.md):

  * A message is its role, its tool-call ids, its `tool_call_id` and a content `tag`.
  * A digest is a term: `base ms` is `digest_messages(ms)` (`chain_digest_base`), `after d m`
    is `chain_digest_after(d, m)`, `none` is the host's empty string, `lit n` an arbitrary
    other string. sha256 is treated as injective on these terms (no collisions).
  * The journal is the list of HISTORY entries on the (linear) path after the header.
    Every other entry type the two writers produce (`run_started`, `state_delta`,
    `settings`, `resumed`, `suspended`, `run_finished`) is decoded by the fold without
    touching `rev_msgs`, `digest`, `digest_prev` or the pairing, and neither writer can make
    one malformed from a well-typed wire event, so they are dropped. `seq` is the entry's
    position; the fold uses it only as an identity (strip_dangling) and inside refusals,
    and the comparison is on the refusal's id.
  * The wire event `session_resumed` is kept because it arms D1's second arm in both writers.
-/

inductive Role where
  | system | user | assistant | tool
  deriving DecidableEq, Repr

structure Msg where
  role   : Role
  calls  : List String
  callId : String
  tag    : Nat
  deriving DecidableEq, Repr

inductive Dig where
  | none                       -- the host's "" (initial `chainDigest`)
  | lit  (n : Nat)             -- any other opaque digest string
  | base (ms : List Msg)       -- digest_messages(ms) = chain_digest_base(ms)
  | after (d : Dig) (m : Msg)  -- chain_digest_after(d, m)
  deriving DecidableEq, Repr

def chainEmptyBase : Dig := .base []
def chainOver (b : Dig) (ms : List Msg) : Dig := ms.foldl Dig.after b

/-- `chain_digests_over(_, ms)` (journal.ail:292). NOTE: the source ignores its `base`
argument and always starts from `chain_empty_base()`; modelled as written. -/
def chainDigestsAux : Dig → List Msg → List Dig
  | _, [] => []
  | d, m :: rest => Dig.after d m :: chainDigestsAux (Dig.after d m) rest
def chainDigestsOver (_b : Dig) (ms : List Msg) : List Dig := chainDigestsAux chainEmptyBase ms

/-! ## Wire events and journal entries -/

inductive Ev where
  | seeded   (ms : List Msg) (d : Dig) (ds : List Dig)
  | appended (m : Msg) (rep : Bool) (d : Dig)
  | replaced (reason : String) (fk : Option Int) (ms : List Msg) (d : Dig)
  | resumed  (promptFrom promptTo : String)
  deriving DecidableEq, Repr

inductive Ent where
  | app  (m : Msg) (rep : Bool) (d : Dig)
  | repl (reason : String) (fk : Option Int) (ms : List Msg) (d : Dig)
  deriving DecidableEq, Repr

/-! ## The fold (journal.ail) -/

inductive Refusal where
  | digest (seq : Nat) | pairing (seq : Int) | headPrefix | transcript
  deriving DecidableEq, Repr

def Refusal.id : Refusal → String
  | .digest _ => "digest" | .pairing _ => "pairing" | .headPrefix => "head-prefix"
  | .transcript => "transcript"

abbrev HistMsg := Nat × Msg

structure FoldAcc where
  err     : Option Refusal := none
  revMsgs : List HistMsg := []
  digest  : Dig := chainEmptyBase
  digestPrev : Dig := chainEmptyBase

def takeSystemHist : List HistMsg → List HistMsg
  | [] => []
  | h :: rest => if h.2.role = .system then h :: takeSystemHist rest else []

/-- `drop_hist` (journal.ail:1376): `n <= 0` keeps everything, otherwise drop `n`. Written
with `List.drop` (structural) rather than the source's recursion on `n - 1`, so the kernel
can evaluate it; the two agree for every `n`. -/
def dropHist (n : Int) (xs : List HistMsg) : List HistMsg :=
  if n ≤ 0 then xs else xs.drop n.toNat

def tagMessages (seq : Nat) (ms : List Msg) : List HistMsg := ms.map (fun m => (seq, m))

/-- `fold_append` (journal.ail:1453). -/
def foldAppend (acc : FoldAcc) (seq : Nat) (m : Msg) (rep : Bool) (d : Dig) : FoldAcc :=
  let base := if rep then acc.digestPrev else acc.digest
  let kept := if rep then (match acc.revMsgs with | [] => [] | _ :: rest => rest) else acc.revMsgs
  let expected := Dig.after base m
  if d ≠ expected then { acc with err := some (.digest seq) }
  else { acc with revMsgs := (seq, m) :: kept, digest := expected, digestPrev := base }

/-- `fold_replace` (journal.ail:1490). -/
def foldReplace (acc : FoldAcc) (seq : Nat) (reason : String) (fk : Option Int)
    (ms : List Msg) (d : Dig) : FoldAcc :=
  let switch := reason = "profile_switch" ∨ reason = "resume"
  let forward := acc.revMsgs.reverse
  let pre := if switch then [] else takeSystemHist forward
  let kept := if switch then [] else (match fk with | none => [] | some i => dropHist i forward)
  let replacement := tagMessages seq ms
  let emitted := pre ++ replacement ++ kept
  let expected := if switch then chainOver chainEmptyBase ms
                  else Dig.base ((pre ++ replacement).map (·.2))
  if d ≠ expected then { acc with err := some (.digest seq) }
  else { acc with revMsgs := emitted.reverse, digest := expected, digestPrev := acc.digest }

/-- `fold_entry` restricted to the history entries (journal.ail:1523). -/
def foldEntry (acc : FoldAcc) (se : Nat × Ent) : FoldAcc :=
  match acc.err with
  | some _ => acc
  | none =>
    match se.2 with
    | .app m rep d => foldAppend acc se.1 m rep d
    | .repl r fk ms d => foldReplace acc se.1 r fk ms d

-- `contains_string`, `without_string`, `call_ids`
def containsString : List String → String → Bool
  | [], _ => false
  | x :: rest, t => if x = t then true else containsString rest t

def withoutString : List String → String → List String
  | [], _ => []
  | x :: rest, t => if x = t then withoutString rest t else x :: withoutString rest t

structure PairAcc where
  err    : Option Refusal := none
  openIds : List String := []
  curIds : List String := []
  curSeq : Int := -1

/-- `pair_step` (journal.ail:1634). -/
def pairStep (acc : PairAcc) (h : HistMsg) : PairAcc :=
  match acc.err with
  | some _ => acc
  | none =>
    if h.2.role = .tool then
      if containsString acc.curIds h.2.callId
      then { acc with openIds := withoutString acc.openIds h.2.callId }
      else { acc with err := some (.pairing h.1) }
    else if acc.openIds.length > 0 then { acc with err := some (.pairing acc.curSeq) }
    else if h.2.calls.length > 0 then
      { acc with openIds := h.2.calls, curIds := h.2.calls, curSeq := h.1 }
    else acc

def keepCalls (dangling : List String) : List String → List String
  | [] => []
  | c :: rest => if containsString dangling c then keepCalls dangling rest else c :: keepCalls dangling rest

/-- `strip_dangling` (journal.ail:1653). -/
def stripDangling (dangling : List String) (curSeq : Int) : List HistMsg → List HistMsg
  | [] => []
  | h :: rest =>
    if (h.1 : Int) = curSeq ∧ h.2.calls.length > 0
    then (h.1, { h.2 with calls := keepCalls dangling h.2.calls }) :: stripDangling dangling curSeq rest
    else h :: stripDangling dangling curSeq rest

/-- `system_is_head_prefix` (phase_vocab.ail:84). -/
def systemIsHeadPrefix : List Msg → Bool → Bool
  | [], _ => true
  | m :: rest, stillHead =>
    if m.role = .system then stillHead && systemIsHeadPrefix rest true
    else systemIsHeadPrefix rest false

/-- `valid_message_transcript` (phase_vocab.ail:115, via valid_tool_calls). -/
def validTranscript : List Msg → Bool
  | [] => true
  | m :: rest =>
    if m.role = .tool then m.callId ≠ "" && validTranscript rest
    else m.calls.all (· ≠ "") && validTranscript rest

structure State where
  history  : List Msg
  dangling : List String
  deriving DecidableEq, Repr

/-- `finish_fold` (journal.ail:1715). `history_from_seed` repeats the head-prefix test and
cannot fail after it, so it is not modelled separately. -/
def finishFold (acc : FoldAcc) : Except Refusal State :=
  let forward := acc.revMsgs.reverse
  let pairs := forward.foldl pairStep {}
  match pairs.err with
  | some r => .error r
  | none =>
    let dangling := pairs.openIds
    let stripped := if dangling.length = 0 then forward else stripDangling dangling pairs.curSeq forward
    let msgs := stripped.map (·.2)
    if !systemIsHeadPrefix msgs true then .error .headPrefix
    else if !validTranscript msgs then .error .transcript
    else .ok { history := msgs, dangling := dangling }

def numberFrom : Nat → List Ent → List (Nat × Ent)
  | _, [] => []
  | n, e :: rest => (n, e) :: numberFrom (n + 1) rest

/-- `fold_journal(lines, leaf)` with the leaf the last line: the header is seq 0. -/
def fold (j : List Ent) : Except Refusal State :=
  let acc := (numberFrom 1 j).foldl foldEntry {}
  match acc.err with
  | some r => .error r
  | none => finishFold acc

/-! ## The twin: `journal_lines_of_records` (journal.ail:1923-2149) -/

structure Twin where
  out : List Ent := []          -- in order (the source conses and reverses at the end)
  digest : Dig := chainEmptyBase
  seeded : Bool := false
  replaceNextSeed : Bool := false
  replaceReason : String := "profile_switch"
  replacedSinceSeed : Bool := false

def Twin.line (t : Twin) (e : Ent) : Twin := { t with out := t.out ++ [e] }

/-- `twin_has_dangling` (journal.ail:1944): the fold's own rule over the lines so far. -/
def Twin.hasDangling (t : Twin) : Bool :=
  match fold t.out with
  | .ok s => s.dangling.length > 0
  | .error _ => false

/-- `twin_seed_messages` (journal.ail:1975). -/
def twinSeedMessages : Twin → List Msg → Twin
  | t, [] => t
  | t, m :: rest =>
    let d := Dig.after t.digest m
    twinSeedMessages { t.line (.app m false d) with digest := d } rest

/-- `twin_event` (journal.ail:1992), history-relevant arms. -/
def twinEvent (t : Twin) : Ev → Twin
  | .seeded ms d _ =>
    if t.seeded && t.replaceNextSeed then
      { t.line (.repl t.replaceReason none ms d) with
          digest := d, replaceNextSeed := false, replacedSinceSeed := false }
    else if t.seeded then t
    else twinSeedMessages { t with seeded := true } ms
  | .appended m rep d => { t.line (.app m rep d) with digest := d }
  | .replaced r fk ms d => { t.line (.repl r fk ms d) with digest := d }   -- journal.ail:2045-2053
  | .resumed pf pt =>
    let switch := pf ≠ pt
    { t with replaceNextSeed := switch || t.replacedSinceSeed || t.hasDangling,
             replaceReason := if switch then "profile_switch" else "resume" }

def twinLines (evs : List Ev) : List Ent := (evs.foldl twinEvent {}).out

/-! ## The host: `SessionJournal` (session-journal.ts) -/

structure Host where
  out : List Ent := []
  seeded : Bool := false
  replaceNextSeed : Bool := false
  replaceReason : String := "profile_switch"
  chainDigest : Dig := .none
  historyMessages : Int := 0
  openCallIds : List String := []
  replacedSinceSeed : Bool := false
  unresumable : Bool := false

def Host.append (h : Host) (e : Ent) : Host := { h with out := h.out ++ [e] }

/-- `updatePending` (:864). -/
def Host.updatePending (h : Host) (m : Msg) : Host :=
  if m.calls.length > 0 then { h with openCallIds := m.calls.filter (· ≠ "") }
  else if m.callId ≠ "" then { h with openCallIds := h.openCallIds.filter (· ≠ m.callId) }
  else h

/-- `noteHistoryMessage` (:849). -/
def Host.noteHistoryMessage (h : Host) (m : Msg) : Host :=
  ({ h with historyMessages := h.historyMessages + 1 }).updatePending m

/-- `replaceLastHistoryMessage` (:854): the message argument is not read. -/
def Host.replaceLastHistoryMessage (h : Host) (_m : Msg) : Host :=
  if h.historyMessages = 0 then { h with historyMessages := 1 } else h

/-- Arm 1's loop (:604-619). -/
def hostExpand : Host → List (Msg × Dig) → Host
  | h, [] => h
  | h, (m, d) :: rest =>
    hostExpand ({ (h.append (.app m false d)) with chainDigest := d }.noteHistoryMessage m) rest

/-- `recordSeed` (:576). -/
def hostSeed (h : Host) (ms : List Msg) (d : Dig) (ds : List Dig) : Host :=
  if !h.seeded then
    let h := { h with seeded := true }
    if ds.length ≠ ms.length then { h with unresumable := true }
    else
      let h := hostExpand h (ms.zip ds)
      let h := if d ≠ .none then { h with chainDigest := d } else h
      { h with replacedSinceSeed := false }
  else if h.replaceNextSeed then
    let h := { h with replaceNextSeed := false }
    { (h.append (.repl h.replaceReason none ms d)) with
        chainDigest := d, historyMessages := ms.length, openCallIds := [],
        replacedSinceSeed := false }
  else if d ≠ h.chainDigest then { h with unresumable := true }
  else h

/-- `record` (:484) over the history-relevant events. -/
def hostEvent (h : Host) : Ev → Host
  | .seeded ms d ds => hostSeed h ms d ds
  | .appended m rep d =>
    let h := { (h.append (.app m rep d)) with chainDigest := d }
    if rep then h.replaceLastHistoryMessage m else h.noteHistoryMessage m
  | .replaced r fk ms d =>
    let fk' := match fk with
      | some k => if 0 ≤ k ∧ k ≤ h.historyMessages then some k else none
      | none => none
    { (h.append (.repl r fk' ms d)) with
        chainDigest := d, historyMessages := ms.length, openCallIds := [],
        replacedSinceSeed := true }
  | .resumed pf pt =>
    { h with replaceNextSeed := pf ≠ pt || h.openCallIds.length > 0 || h.replacedSinceSeed,
             replaceReason := if pf ≠ pt then "profile_switch" else "resume" }

def hostRun (evs : List Ev) : Host := evs.foldl hostEvent {}
def hostLines (evs : List Ev) : List Ent := (hostRun evs).out

/-! ## The verdict both properties compare -/

inductive Verdict where
  | accept (s : State)
  | refuse (id : String)
  deriving DecidableEq, Repr

def verdict : Except Refusal State → Verdict
  | .ok s => .accept s
  | .error r => .refuse r.id

/-- P3.1, for one event sequence. -/
def foldsAlike (evs : List Ev) : Prop :=
  verdict (fold (hostLines evs)) = verdict (fold (twinLines evs))

instance (evs : List Ev) : Decidable (foldsAlike evs) := by
  unfold foldsAlike; exact inferInstance

/-! ## What a run emits: the child simulator (the Lean copy of diff/gen.ail)

The digests are the child's, computed the way `session.ail` computes them:
`c2_append_step` (:840-865: `after(at, m)`, or `after(prev, m)` for the hybrid batch's
`replaces_previous` entry), the checkpoint (:3099-3116: `messages = [summary]`,
`digest_after = digest_messages(prefix ++ [summary])`), the seed (:3868-3872, from the
empty base) and `c2_seed_digest` (:501). Steps: 0-5 and 12 append one message, 6 is the
hybrid replacement, 7 a checkpoint, 8 a crash resume (`session_resumed` with equal prompt
digests, then the seed of the history with dangling calls stripped), 9 a profile-switch
resume, 10 a follow-up run (a new seed of the same history), 11 a checkpoint that keeps
the last message (`first_kept = some (n-1)`: not emitted at HEAD).
-/

def mk (role : Role) (tag : Nat) (ids : List String) (tcid : String) : Msg := ⟨role, ids, tcid, tag⟩
def mSys  := mk .system 0 [] ""
def mUser := mk .user 1 [] ""
def mA    := mk .assistant 2 [] ""
def mCa   := mk .assistant 3 ["a"] ""
def mCab  := mk .assistant 4 ["a", "b"] ""
def mRa   := mk .tool 5 [] "a"
def mRb   := mk .tool 6 [] "b"
def mU2   := mk .user 7 [] ""
def mSum  := mk .user 8 [] ""
def mSys2 := mk .system 9 [] ""
def mCe   := mk .assistant 10 ["a", ""] ""

def initOf : List Msg → List Msg
  | [] => [] | [_] => [] | m :: rest => m :: initOf rest
def takeSystem : List Msg → List Msg
  | [] => [] | m :: rest => if m.role = .system then m :: takeSystem rest else []
def dropSystem : List Msg → List Msg
  | [] => [] | m :: rest => if m.role = .system then dropSystem rest else m :: rest

def answeredAfter : List Msg → List String
  | [] => [] | m :: rest => if m.role = .tool then m.callId :: answeredAfter rest else answeredAfter rest
def lastCallIndex : List Msg → Nat → Int → Int
  | [], _, best => best
  | m :: rest, i, best => lastCallIndex rest (i + 1) (if m.calls.length > 0 then (i : Int) else best)
def viewAt : List Msg → Nat → Nat → List String → List Msg
  | [], _, _, _ => []
  | m :: rest, i, k, ans =>
    if i = k then { m with calls := m.calls.filter (fun c => ans.contains c) } :: viewAt rest (i + 1) k ans
    else m :: viewAt rest (i + 1) k ans
def view (ms : List Msg) : List Msg :=
  let k := lastCallIndex ms 0 (-1)
  if k < 0 then ms else viewAt ms 0 k.toNat (answeredAfter (ms.drop (k.toNat + 1)))

structure Sim where
  hist : List Msg
  atD  : Dig
  prev : Dig
  rev  : List Ev

def seedEv (ms : List Msg) : Ev := .seeded ms (chainOver chainEmptyBase ms) (chainDigestsOver chainEmptyBase ms)
def seededWith (s : Sim) (ms : List Msg) : Sim :=
  { s with hist := ms, atD := chainOver chainEmptyBase ms,
           prev := if ms.length = 0 then chainEmptyBase else chainOver chainEmptyBase (initOf ms) }
def simApp (s : Sim) (m : Msg) : Sim :=
  let d := Dig.after s.atD m
  { s with rev := .appended m false d :: s.rev, hist := s.hist ++ [m], atD := d, prev := s.atD }
def simHyb (s : Sim) (m : Msg) : Sim :=
  let d := Dig.after s.prev m
  { s with rev := .appended m true d :: s.rev, hist := initOf s.hist ++ [m], atD := d }
def simCheckpoint (s : Sim) (keepLast : Bool) : Sim :=
  let pre := takeSystem s.hist
  let k := s.hist.length - 1
  let kept := if keepLast then s.hist.drop k else []
  let d := Dig.base (pre ++ [mSum])
  let fk : Option Int := if keepLast then some ((s.hist.length : Int) - 1) else none
  { s with rev := .replaced "checkpoint" fk [mSum] d :: s.rev,
           hist := pre ++ [mSum] ++ kept, atD := d, prev := s.atD }
def simResume (s : Sim) (switch : Bool) : Sim :=
  let v := view s.hist
  let ms := if switch then [mSys2] ++ dropSystem v else v
  let r : Ev := if switch then .resumed "sha256:p0" "sha256:p1" else .resumed "sha256:p0" "sha256:p0"
  seededWith { s with rev := seedEv ms :: r :: s.rev } ms
def simFollow (s : Sim) : Sim := seededWith { s with rev := seedEv s.hist :: s.rev } s.hist

def simStep (s : Sim) (i : Nat) : Sim :=
  match i with
  | 0 => simApp s mA | 1 => simApp s mCa | 2 => simApp s mCab | 3 => simApp s mRa
  | 4 => simApp s mRb | 5 => simApp s mU2 | 6 => simHyb s mCa | 7 => simCheckpoint s false
  | 8 => simResume s false | 9 => simResume s true | 10 => simFollow s
  | 11 => simCheckpoint s true | _ => simApp s mCe

def eventsOf (ix : List Nat) : List Ev :=
  let s0 : Sim := { hist := [], atD := chainEmptyBase, prev := chainEmptyBase, rev := [] }
  let s := seededWith { s0 with rev := [seedEv [mSys, mUser]] } [mSys, mUser]
  (ix.foldl simStep s).rev.reverse


def simRun (ix : List Nat) : Sim :=
  let s0 : Sim := { hist := [], atD := chainEmptyBase, prev := chainEmptyBase, rev := [] }
  ix.foldl simStep (seededWith { s0 with rev := [seedEv [mSys, mUser]] } [mSys, mUser])

/-! ## Rule 3 over a record list (journal.ail:1266-1270), as P3.2 states it

The seed, then one message per appended entry, an entry with `replaces_previous` taking the
place of the message before it; from the latest `history_replaced`, the head system prefix
(checkpoint) or nothing (profile switch / resume), then its messages, then the entries after
it (or from `first_kept`). A later seed re-states the history (D1 arm 3). -/
def rule3Step : Option (List Msg) → Ev → Option (List Msg)
  | none, .seeded ms _ _ => some ms
  | some h, .appended m rep _ => some (if rep then initOf h ++ [m] else h ++ [m])
  | some h, .replaced r fk ms _ =>
    some (if r = "profile_switch" ∨ r = "resume" then ms
          else takeSystem h ++ ms ++ (match fk with | none => [] | some i => if i ≤ 0 then h else h.drop i.toNat))
  | o, _ => o

def rule3 (evs : List Ev) : Option (List Msg) := evs.foldl rule3Step none

/-! ## Theorems: P3.1 on the fragment without `session_resumed` -/

/-- The events of the fragment: everything but `session_resumed`, and checkpoints with no
`first_kept` (HEAD's only shape, session.ail:3109-3116). -/
def okEv : Ev → Bool
  | .resumed _ _ => false
  | .replaced _ fk _ _ => fk.isNone
  | _ => true

def seedEntries : Dig → List Msg → List Ent
  | _, [] => []
  | b, m :: rest => .app m false (.after b m) :: seedEntries (.after b m) rest

theorem chainDigestsAux_length (b : Dig) (ms : List Msg) : (chainDigestsAux b ms).length = ms.length := by
  induction ms generalizing b with
  | nil => rfl
  | cons m rest ih => simp [chainDigestsAux, ih]

theorem hostExpand_out (h : Host) (b : Dig) (ms : List Msg) :
    (hostExpand h (ms.zip (chainDigestsAux b ms))).out = h.out ++ seedEntries b ms ∧
    (hostExpand h (ms.zip (chainDigestsAux b ms))).seeded = h.seeded ∧
    (hostExpand h (ms.zip (chainDigestsAux b ms))).replaceNextSeed = h.replaceNextSeed := by
  induction ms generalizing h b with
  | nil => simp [chainDigestsAux, hostExpand, seedEntries]
  | cons m rest ih =>
    simp only [chainDigestsAux, List.zip_cons_cons, hostExpand, seedEntries]
    obtain ⟨h1, h2, h3⟩ := ih ({ (h.append (.app m false (.after b m))) with chainDigest := .after b m }.noteHistoryMessage m) (.after b m)
    refine ⟨?_, ?_, ?_⟩
    · rw [h1]; simp [Host.noteHistoryMessage, Host.updatePending, Host.append]; split <;> (try split) <;> simp
    · rw [h2]; simp [Host.noteHistoryMessage, Host.updatePending, Host.append]; split <;> (try split) <;> simp
    · rw [h3]; simp [Host.noteHistoryMessage, Host.updatePending, Host.append]; split <;> (try split) <;> simp

theorem twinSeed_out (t : Twin) (ms : List Msg) :
    (twinSeedMessages t ms).out = t.out ++ seedEntries t.digest ms ∧
    (twinSeedMessages t ms).seeded = t.seeded ∧
    (twinSeedMessages t ms).replaceNextSeed = t.replaceNextSeed := by
  induction ms generalizing t with
  | nil => simp [twinSeedMessages, seedEntries]
  | cons m rest ih =>
    simp only [twinSeedMessages, seedEntries]
    obtain ⟨h1, h2, h3⟩ := ih { t.line (.app m false (.after t.digest m)) with digest := .after t.digest m }
    refine ⟨?_, h2, h3⟩
    rw [h1]; simp [Twin.line]

/-- Both writers past their first seed, holding the same lines, with D1's second arm unarmed. -/
def WInv (h : Host) (t : Twin) : Prop :=
  h.out = t.out ∧ h.seeded = true ∧ t.seeded = true ∧ h.replaceNextSeed = false ∧ t.replaceNextSeed = false

theorem inv_step (h : Host) (t : Twin) (e : Ev) (he : okEv e = true) (hi : WInv h t) :
    WInv (hostEvent h e) (twinEvent t e) := by
  obtain ⟨ho, hs, ts, hr, tr⟩ := hi
  cases e with
  | seeded ms d ds =>
    simp only [hostEvent, twinEvent, hostSeed, hs, tr, hr, ts]
    refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> (repeat' split) <;> simp_all
  | appended m rep d =>
    simp only [hostEvent, twinEvent]
    refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;>
      (cases rep <;> simp [Host.replaceLastHistoryMessage, Host.noteHistoryMessage, Host.updatePending,
        Host.append, Twin.line, ho, hs, ts, hr, tr] <;> (try split) <;> (try split) <;> simp_all)
  | replaced r fk ms d =>
    cases fk with
    | none => simp [hostEvent, twinEvent, Host.append, Twin.line, WInv, ho, hs, ts, hr, tr]
    | some k => simp [okEv] at he
  | resumed pf pt => simp [okEv] at he

theorem inv_fold (h : Host) (t : Twin) (evs : List Ev) (he : evs.all okEv = true) (hi : WInv h t) :
    WInv (evs.foldl hostEvent h) (evs.foldl twinEvent t) := by
  induction evs generalizing h t with
  | nil => exact hi
  | cons e rest ih =>
    simp only [List.all_cons, Bool.and_eq_true] at he
    exact ih _ _ he.2 (inv_step h t e he.1 hi)

/-- **P3.1, proved on the fragment**: for every journal-class event sequence that opens with a
seed carrying the child's chain (`digests`, session.ail:3871) and contains no
`session_resumed` and no `first_kept`, the host and the twin write the SAME history entries,
so their journals fold alike. -/
theorem host_twin_same_lines (ms : List Msg) (d : Dig) (rest : List Ev)
    (hrest : rest.all okEv = true) :
    hostLines (.seeded ms d (chainDigestsOver chainEmptyBase ms) :: rest) =
    twinLines (.seeded ms d (chainDigestsOver chainEmptyBase ms) :: rest) := by
  have hl := chainDigestsAux_length chainEmptyBase ms
  obtain ⟨h1, h2, h3⟩ := hostExpand_out { seeded := true } chainEmptyBase ms
  obtain ⟨t1, t2, t3⟩ := twinSeed_out { seeded := true } ms
  have h0 : WInv (hostEvent {} (.seeded ms d (chainDigestsOver chainEmptyBase ms)))
                (twinEvent {} (.seeded ms d (chainDigestsOver chainEmptyBase ms))) := by
    simp only [hostEvent, twinEvent, hostSeed, chainDigestsOver, hl]
    refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> (repeat' split) <;> simp_all [chainEmptyBase]
  have := inv_fold _ _ rest hrest h0
  exact this.1

theorem p31_fragment (ms : List Msg) (d : Dig) (rest : List Ev) (hrest : rest.all okEv = true) :
    foldsAlike (.seeded ms d (chainDigestsOver chainEmptyBase ms) :: rest) := by
  unfold foldsAlike; rw [host_twin_same_lines ms d rest hrest]

/-! ## Theorems: P3.2 on single-frame runs -/

def foldAcc (j : List Ent) : FoldAcc := (numberFrom 1 j).foldl foldEntry {}

theorem numberFrom_snoc (n : Nat) (j : List Ent) (e : Ent) :
    numberFrom n (j ++ [e]) = numberFrom n j ++ [(n + j.length, e)] := by
  induction j generalizing n with
  | nil => simp [numberFrom]
  | cons x rest ih => simp [numberFrom, ih]; omega

theorem foldAcc_snoc (j : List Ent) (e : Ent) :
    foldAcc (j ++ [e]) = foldEntry (foldAcc j) (1 + j.length, e) := by
  simp [foldAcc, numberFrom_snoc, List.foldl_append]

theorem initOf_eq_dropLast (xs : List Msg) : initOf xs = xs.dropLast := by
  induction xs with
  | nil => rfl
  | cons x rest ih =>
    cases rest with
    | nil => rfl
    | cons y r => simp [initOf, ih]

theorem tail_reverse_map (l : List HistMsg) :
    (l.tail.reverse.map (·.2)) = (l.reverse.map (·.2)).dropLast := by
  cases l with
  | nil => rfl
  | cons x r => simp [List.dropLast_append_of_ne_nil]

theorem takeSystemHist_map (xs : List HistMsg) : (takeSystemHist xs).map (·.2) = takeSystem (xs.map (·.2)) := by
  induction xs with
  | nil => rfl
  | cons x rest ih => simp only [takeSystemHist, takeSystem, List.map_cons]; split <;> simp [ih]

/-- The steps of one run (no resume, no follow-up, no `first_kept`): appends, the hybrid
replacement, the checkpoint. -/
def inFrag (i : Nat) : Bool := i ∈ [0, 1, 2, 3, 4, 5, 6, 7, 12]

def twinOf (s : Sim) : Twin := s.rev.reverse.foldl twinEvent {}

/-- The round-trip invariant: the fold's rule-3 accumulator over the twin's lines IS the
child's history and chain, and rule 3 over the records says the same history. -/
def SInv (s : Sim) : Prop :=
  (foldAcc (twinOf s).out).err = none ∧
  (foldAcc (twinOf s).out).revMsgs.reverse.map (·.2) = s.hist ∧
  (foldAcc (twinOf s).out).digest = s.atD ∧
  (foldAcc (twinOf s).out).digestPrev = s.prev ∧
  (twinOf s).seeded = true ∧ (twinOf s).replaceNextSeed = false ∧
  rule3 s.rev.reverse = some s.hist

theorem twinOf_cons (s s' : Sim) (e : Ev) (h : s'.rev = e :: s.rev) : twinOf s' = twinEvent (twinOf s) e := by
  simp [twinOf, h, List.foldl_append]

theorem rule3_cons (s s' : Sim) (e : Ev) (h : s'.rev = e :: s.rev) : rule3 s'.rev.reverse = rule3Step (rule3 s.rev.reverse) e := by
  simp [rule3, h, List.foldl_append]

theorem sinv_app (s : Sim) (m : Msg) (hi : SInv s) : SInv (simApp s m) := by
  obtain ⟨e0, h0, d0, p0, se, rn, r0⟩ : SInv s := hi
  have ht : twinOf (simApp s m) = { (twinOf s).line (.app m false (.after s.atD m)) with digest := .after s.atD m } := by
    rw [twinOf_cons s _ _ rfl]; rfl
  have hr : rule3 (simApp s m).rev.reverse = some (s.hist ++ [m]) := by
    rw [rule3_cons s _ _ rfl, r0]; simp [rule3Step]
  have hf : foldAcc (twinOf (simApp s m)).out =
      { foldAcc (twinOf s).out with
          revMsgs := (1 + (twinOf s).out.length, m) :: (foldAcc (twinOf s).out).revMsgs
          digest := .after s.atD m
          digestPrev := s.atD } := by
    rw [ht]; simp only [Twin.line]; rw [foldAcc_snoc]
    simp [foldEntry, e0, foldAppend, d0]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · rw [hf]; exact e0
  · rw [hf]; simp [simApp, ← h0]
  · rw [hf]; rfl
  · rw [hf]; rfl
  · rw [ht]; exact se
  · rw [ht]; exact rn
  · rw [hr]; rfl

theorem sinv_hyb (s : Sim) (m : Msg) (hi : SInv s) : SInv (simHyb s m) := by
  obtain ⟨e0, h0, d0, p0, se, rn, r0⟩ : SInv s := hi
  have ht : twinOf (simHyb s m) = { (twinOf s).line (.app m true (.after s.prev m)) with digest := .after s.prev m } := by
    rw [twinOf_cons s _ _ rfl]; rfl
  have hr : rule3 (simHyb s m).rev.reverse = some (initOf s.hist ++ [m]) := by
    rw [rule3_cons s _ _ rfl, r0]; simp [rule3Step]
  have hf : foldAcc (twinOf (simHyb s m)).out =
      { foldAcc (twinOf s).out with
          revMsgs := (1 + (twinOf s).out.length, m) :: (foldAcc (twinOf s).out).revMsgs.tail
          digest := .after s.prev m
          digestPrev := s.prev } := by
    rw [ht]; simp only [Twin.line]; rw [foldAcc_snoc]
    simp only [foldEntry, e0, foldAppend, p0]
    cases (foldAcc (twinOf s).out).revMsgs <;> simp
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · rw [hf]; exact e0
  · rw [hf]; simp only [simHyb, initOf_eq_dropLast, ← h0]
    simp only [List.map_cons, List.reverse_cons, List.map_append, List.map_nil]
    rw [tail_reverse_map]
  · rw [hf]; rfl
  · rw [hf]; rfl
  · rw [ht]; exact se
  · rw [ht]; exact rn
  · rw [hr]; rfl

theorem sinv_checkpoint (s : Sim) (hi : SInv s) : SInv (simCheckpoint s false) := by
  obtain ⟨e0, h0, d0, p0, se, rn, r0⟩ : SInv s := hi
  have ht : twinOf (simCheckpoint s false) =
      { (twinOf s).line (.repl "checkpoint" none [mSum] (.base (takeSystem s.hist ++ [mSum])))
        with digest := .base (takeSystem s.hist ++ [mSum]) } := by
    rw [twinOf_cons s _ _ rfl]; rfl
  have hr : rule3 (simCheckpoint s false).rev.reverse = some (takeSystem s.hist ++ [mSum]) := by
    rw [rule3_cons s _ _ rfl, r0]; simp [rule3Step]
  have hpre : ((takeSystemHist (foldAcc (twinOf s).out).revMsgs.reverse).map (·.2)) = takeSystem s.hist := by
    rw [takeSystemHist_map, h0]
  have hf : foldAcc (twinOf (simCheckpoint s false)).out =
      { foldAcc (twinOf s).out with
          revMsgs := (takeSystemHist (foldAcc (twinOf s).out).revMsgs.reverse ++
                       [(1 + (twinOf s).out.length, mSum)]).reverse
          digest := .base (takeSystem s.hist ++ [mSum])
          digestPrev := s.atD } := by
    rw [ht]; simp only [Twin.line]; rw [foldAcc_snoc]
    simp [foldEntry, e0, foldReplace, tagMessages, d0, ← hpre]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · rw [hf]; exact e0
  · rw [hf]; simp [simCheckpoint, ← hpre]
  · rw [hf]; rfl
  · rw [hf]; rfl
  · rw [ht]; exact se
  · rw [ht]; exact rn
  · rw [hr]; simp [simCheckpoint]

theorem sinv_seed : SInv (simRun []) := by unfold SInv; decide

theorem sinv_from (s : Sim) (ix : List Nat) (hs : SInv s) (h : ix.all inFrag = true) :
    SInv (ix.foldl simStep s) := by
  induction ix generalizing s with
  | nil => exact hs
  | cons i rest ih =>
    simp only [List.all_cons, Bool.and_eq_true] at h
    apply ih _ _ h.2
    have hfrag := h.1
    simp only [inFrag, List.mem_cons, List.mem_nil_iff, or_false, decide_eq_true_eq] at hfrag
    rcases hfrag with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      simp only [simStep] <;>
      first | exact sinv_app _ _ hs | exact sinv_hyb _ _ hs | exact sinv_checkpoint _ hs

theorem sinv_run (ix : List Nat) (h : ix.all inFrag = true) : SInv (simRun ix) :=
  sinv_from _ ix sinv_seed h

theorem eventsOf_eq (ix : List Nat) : eventsOf ix = (simRun ix).rev.reverse := rfl

/-- **P3.2, proved for every single run** (any sequence of appends, hybrid replacements and
checkpoints after the seed): folding the twin's journal never refuses at rule 3 (no
`digest` refusal), its rule-3 history is exactly rule 3 over the records, and what the fold
returns is `finish_fold` of that history — so a refusal can only be the run's own history
failing pairing, head-prefix or transcript. -/
theorem p32_single_run (ix : List Nat) (h : ix.all inFrag = true) :
    (foldAcc (twinLines (eventsOf ix))).err = none ∧
    rule3 (eventsOf ix) = some ((foldAcc (twinLines (eventsOf ix))).revMsgs.reverse.map (·.2)) ∧
    fold (twinLines (eventsOf ix)) = finishFold (foldAcc (twinLines (eventsOf ix))) := by
  obtain ⟨e0, h0, -, -, -, -, r0⟩ := sinv_run ix h
  have hl : twinLines (eventsOf ix) = (twinOf (simRun ix)).out := rfl
  refine ⟨?_, ?_, ?_⟩
  · rw [hl]; exact e0
  · rw [hl, h0, eventsOf_eq]; exact r0
  · rw [hl]
    show (match (foldAcc (twinOf (simRun ix)).out).err with
          | some r => Except.error r
          | none => finishFold (foldAcc (twinOf (simRun ix)).out)) = _
    rw [e0]

theorem finishFold_history (acc : FoldAcc) (st : State) (h : finishFold acc = .ok st)
    (hd : st.dangling = []) : st.history = acc.revMsgs.reverse.map (·.2) := by
  unfold finishFold at h
  simp only at h
  repeat' split at h
  all_goals first
    | (cases h; done)
    | (injection h with h'; subst h'; simp_all)

/-- P3.2's history clause, for a run that ends with every call answered: when the fold
accepts with no dangling call, its history IS rule 3 over the records. -/
theorem p32_single_run_history (ix : List Nat) (h : ix.all inFrag = true) (st : State)
    (hacc : fold (twinLines (eventsOf ix)) = .ok st) (hd : st.dangling = []) :
    rule3 (eventsOf ix) = some st.history := by
  obtain ⟨-, hr, hf⟩ := p32_single_run ix h
  rw [hf] at hacc
  rw [hr, finishFold_history _ st hacc hd]

/-! ## Counterexamples (`bug_`), each a concrete run of the child simulator

Every one is reproduced on the real code by a script in repro/ (see reports.tsv). -/

/-- The concrete input of the first witness, spelled out: run 0 seeds `[system, user]` and
takes a checkpoint; the child crashes; run 1 resumes with the SAME prompt digest, seeds the
folded history `[system, summary]` and appends a user message. -/
theorem w_checkpoint_resume_events :
    eventsOf [7, 8, 5] =
      [ seedEv [mSys, mUser],
        .replaced "checkpoint" none [mSum] (.base [mSys, mSum]),
        .resumed "sha256:p0" "sha256:p0",
        seedEv [mSys, mSum],
        .appended mU2 false (.after (chainOver chainEmptyBase [mSys, mSum]) mU2) ] := by decide

/-- **P3.1 violated (twin)**: after a checkpoint, a crash resume makes the host journal the
resumed seed as a `history_replaced` (`replacedSinceSeed`, session-journal.ts:724,790), and
the twin does not: `TwinAcc.replaced_since_seed` is never set by `HistoryReplaced`
(journal.ail:2045-2053), so `SessionResumed` leaves `replace_next_seed` unarmed, the seed is
dropped, and the resumed run's first append fails the fold's chain. -/
theorem bug_twin_forgets_checkpoint_at_resume :
    verdict (fold (hostLines (eventsOf [7, 8, 5]))) = .accept ⟨[mSys, mSum, mU2], []⟩ ∧
    verdict (fold (twinLines (eventsOf [7, 8, 5]))) = .refuse "digest" := by decide

/-- **P3.2 violated** on the same two-frame record list: rule 3 defines a history and the fold
of the twin's journal refuses it. -/
theorem bug_twin_round_trip_refuses_checkpoint_resume :
    rule3 (eventsOf [7, 8, 5]) = some [mSys, mSum, mU2] ∧
    verdict (fold (twinLines (eventsOf [7, 8, 5]))) = .refuse "digest" := by decide

/-- **P3.1 violated (host)**: the hybrid batch's `replaces_previous` entry carries the
augmented assistant's calls, and `replaceLastHistoryMessage` (session-journal.ts:854-856)
never reads its message, so the host's open-call set stays empty. The exit entry would record
`pending_tool_calls: []` while the fold reports the call dangling ... -/
theorem bug_host_pending_misses_hybrid_calls :
    (hostRun (eventsOf [0, 6])).openCallIds = [] ∧
    verdict (fold (hostLines (eventsOf [0, 6]))) = .accept ⟨[mSys, mUser, { mCa with calls := [] }], ["a"]⟩ := by
  decide

/-- ... and on the crash resume that follows, the host does not arm D1's second arm, drops
the resumed seed (whose chain covers the STRIPPED assistant), and the resumed run's first
append is refused by the fold; the twin, which asks the fold, journals the replacement. -/
theorem bug_host_hybrid_crash_resume :
    verdict (fold (hostLines (eventsOf [0, 6, 8, 5]))) = .refuse "digest" ∧
    verdict (fold (twinLines (eventsOf [0, 6, 8, 5]))) =
      .accept ⟨[mSys, mUser, { mCa with calls := [] }, mU2], []⟩ := by decide

/-- **P3.1 violated (host, latent at HEAD)**: after a checkpoint the host counts only the
replacement's messages (session-journal.ts:722) while the fold also keeps the head system
prefix and the kept tail, so an in-range `first_kept` is judged out of range and DROPPED
(:704-713); the entry is still written, and its fold is the silent truncation the comment
at :700-703 says the check exists to prevent. -/
theorem bug_host_drops_in_range_first_kept :
    verdict (fold (hostLines (eventsOf [11, 11]))) = .accept ⟨[mSys, mSum], []⟩ ∧
    verdict (fold (twinLines (eventsOf [11, 11]))) = .accept ⟨[mSys, mSum, mUser], []⟩ := by decide

/-- Observation (H1 of RESEARCH §6.2, now with a P3.1 consequence): a call with an empty id
is filtered by the host's pending set and kept open by the fold, so the two writers disagree
on arming at the resume and their journals fold with different `dangling`. -/
theorem bug_empty_call_id_dangling_differs :
    verdict (fold (hostLines (eventsOf [12, 3, 8]))) =
      .accept ⟨[mSys, mUser, { mCe with calls := ["a"] }, mRa], [""]⟩ ∧
    verdict (fold (twinLines (eventsOf [12, 3, 8]))) =
      .accept ⟨[mSys, mUser, { mCe with calls := ["a"] }, mRa], []⟩ := by decide

/-- **P3.2 violated by both writers alike** (documented: session-journal.ts:646-655, "P3
Part 3 §4"): a follow-up run after a checkpoint chains from the empty base, the journal
from the rebased one; both journals are refused. -/
theorem bug_followup_after_checkpoint :
    rule3 (eventsOf [7, 10, 5]) = some [mSys, mSum, mU2] ∧
    verdict (fold (hostLines (eventsOf [7, 10, 5]))) = .refuse "digest" ∧
    verdict (fold (twinLines (eventsOf [7, 10, 5]))) = .refuse "digest" := by decide

/-- Scope note on P3.2's wording: rule 4 strips a trailing unanswered call, so for a run cut
mid tool-phase the folded history is not rule 3's history (by design, D4 rule 4). -/
theorem obs_rule4_strips_rule3_history :
    rule3 (eventsOf [1]) = some [mSys, mUser, mCa] ∧
    verdict (fold (twinLines (eventsOf [1]))) = .accept ⟨[mSys, mUser, { mCa with calls := [] }], ["a"]⟩ := by
  decide

/-! ## The fixes (Kiro step 8), proved to close each witness -/

/-- The twin with `replaced_since_seed: true` on `HistoryReplaced`, as its own field comment
(journal.ail:1936-1938) and the host (session-journal.ts:724) say it should be. -/
def twinEventFix (t : Twin) : Ev → Twin
  | .replaced r fk ms d => { t.line (.repl r fk ms d) with digest := d, replacedSinceSeed := true }
  | e => twinEvent t e

def twinLinesFix (evs : List Ev) : List Ent := (evs.foldl twinEventFix {}).out

/-- The host whose `replaceLastHistoryMessage` also runs `updatePending` on the replacing
message, as `noteHistoryMessage` does. -/
def hostEventFix (h : Host) : Ev → Host
  | .appended m true d =>
    (({ (h.append (.app m true d)) with chainDigest := d }).replaceLastHistoryMessage m).updatePending m
  | e => hostEvent h e

def hostLinesFix (evs : List Ev) : List Ent := (evs.foldl hostEventFix {}).out

theorem fix_twin_closes_checkpoint_resume :
    verdict (fold (twinLinesFix (eventsOf [7, 8, 5]))) = verdict (fold (hostLines (eventsOf [7, 8, 5]))) ∧
    verdict (fold (twinLinesFix (eventsOf [11, 8, 5]))) = verdict (fold (hostLines (eventsOf [11, 8, 5]))) := by
  decide

theorem fix_host_closes_hybrid_crash_resume :
    verdict (fold (hostLinesFix (eventsOf [0, 6, 8, 5]))) = verdict (fold (twinLines (eventsOf [0, 6, 8, 5]))) ∧
    ((eventsOf [0, 6]).foldl hostEventFix {}).openCallIds = ["a"] := by
  decide

/-! ## Vacuity: a concrete input satisfying every hypothesis of each general theorem -/

theorem witness_p31_fragment :
    eventsOf [1, 3, 7, 0, 6, 10, 2, 4] = seedEv [mSys, mUser] :: (eventsOf [1, 3, 7, 0, 6, 10, 2, 4]).tail ∧
    (eventsOf [1, 3, 7, 0, 6, 10, 2, 4]).tail.all okEv = true := by decide

theorem witness_p32_single_run :
    [1, 3, 7, 0, 6, 3, 2, 4, 3, 5].all inFrag = true ∧
    verdict (fold (twinLines (eventsOf [1, 3, 7, 0, 6, 3, 2, 4, 3, 5]))) =
      .accept ⟨[mSys, mSum, mCa, mRa, mCab, mRb, mRa, mU2], []⟩ := by decide

/-! ## The wire boundary (X-3), added AFTER the probe repro/unicode.sh found it

Not part of the differential-tested model above, whose messages are opaque tags and whose
host is fed exactly the child's messages. On the real wire the child's `std/json` `encode`
replaces bytes that are not UTF-8 with U+FFFD, while its chain digest
(`canonical_message_frame`, phase_vocab.ail) is over the raw bytes. `toWire` models that:
the host receives `wireMsg m` (tag 11 "ab\xFFbc" becomes tag 12 "ab\uFFFDbc") and the
child's digests unchanged; the twin, in the same process as the child, receives `m`. -/

def mBad := mk .user 11 [] ""
def wireMsg (m : Msg) : Msg := if m.tag = 11 then { m with tag := 12 } else m
def toWire : Ev → Ev
  | .seeded ms d ds => .seeded (ms.map wireMsg) d ds
  | .appended m rep d => .appended (wireMsg m) rep d
  | .replaced r fk ms d => .replaced r fk (ms.map wireMsg) d
  | e => e

def wBad : List Ev := eventsOf [] ++ [.appended mBad false (.after (chainOver chainEmptyBase [mSys, mUser]) mBad)]

theorem bug_wire_replacement_breaks_host_chain :
    verdict (fold (hostLines (wBad.map toWire))) = .refuse "digest" ∧
    verdict (fold (twinLines wBad)) = .accept ⟨[mSys, mUser, mBad], []⟩ := by decide

/-! ## Axiom report: every theorem in this file -/

#print axioms chainDigestsAux_length
#print axioms hostExpand_out
#print axioms twinSeed_out
#print axioms inv_step
#print axioms inv_fold
#print axioms host_twin_same_lines
#print axioms p31_fragment
#print axioms numberFrom_snoc
#print axioms foldAcc_snoc
#print axioms initOf_eq_dropLast
#print axioms tail_reverse_map
#print axioms takeSystemHist_map
#print axioms twinOf_cons
#print axioms rule3_cons
#print axioms sinv_app
#print axioms sinv_hyb
#print axioms sinv_checkpoint
#print axioms sinv_seed
#print axioms sinv_from
#print axioms sinv_run
#print axioms eventsOf_eq
#print axioms p32_single_run
#print axioms finishFold_history
#print axioms p32_single_run_history
#print axioms w_checkpoint_resume_events
#print axioms bug_twin_forgets_checkpoint_at_resume
#print axioms bug_twin_round_trip_refuses_checkpoint_resume
#print axioms bug_host_pending_misses_hybrid_calls
#print axioms bug_host_hybrid_crash_resume
#print axioms bug_host_drops_in_range_first_kept
#print axioms bug_empty_call_id_dangling_differs
#print axioms bug_followup_after_checkpoint
#print axioms obs_rule4_strips_rule3_history
#print axioms fix_twin_closes_checkpoint_resume
#print axioms fix_host_closes_hybrid_crash_resume
#print axioms witness_p31_fragment
#print axioms witness_p32_single_run
#print axioms bug_wire_replacement_breaks_host_chain
