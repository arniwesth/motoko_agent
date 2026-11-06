/-
JournalTwinModel.lean — T3: the journal writer twin and the round trip (ADR-003 D1, D4).

Lean 4.28.0, core only (no Mathlib, no Lake): `lean JournalTwinModel.lean`.

A model of three functions in the Motoko snapshot at
/home/motoko/trial-043/s/t043-t3-b2/tree (no commit id available; the snapshot is not a git
checkout):

  * HOST WRITER — `SessionJournal` (src/tui/src/session-journal.ts:139-880):
      `adopt` (:288-333), `record` (:484-555), `recordSeed` (:576-664), `recordAppended`
      (:666-688), `recordReplaced` (:690-726), `recordResumed` (:760-797), `noteHistoryMessage`
      (:849-852), `replaceLastHistoryMessage` (:854-856), `updatePending` (:864-874).
  * TWIN WRITER — `journal_lines_of_records` (src/core/journal.ail:2137-2145) over
      `twin_event` (:1992-2128), `twin_seed_messages` (:1975-1990), `twin_has_dangling` (:1944-1949).
  * THE JUDGE — `fold_journal` (src/core/journal.ail:1677-1713): `fold_entry` (:1523-1621),
      `fold_append` (:1453-1471), `fold_replace` (:1490-1515), `pair_step` (:1634-1651),
      `strip_dangling` (:1653-1662), `finish_fold` (:1715-1750).
  * WHAT A RUN EMITS (the generator, not under test) — src/core/session.ail: the chain pair
      (:482-506), `c2_append_step` (:840-861), the checkpoint emit (:3109-3141), the follow-up
      turn (:4387-4393), the resume seed (:4805-4810).

What the model keeps and what it abstracts:

  * A message is its role, its content, the ids of its `tool_calls` and its `tool_call_id`.
    `images` is always empty in what we generate and is dropped.
  * DIGESTS ARE SYMBOLIC. `Dg.base ms` is `chain_digest_base ms` (= `digest_messages`),
    `Dg.after d m` is `chain_digest_after d m`. Equality of `Dg` is syntactic, i.e. the model
    assumes sha256 over the canonical frames is collision-free and that `base` and `after`
    never collide with each other. That assumption is what makes a digest check decidable here.
  * Only the entries that carry history (`history_appended`, `history_replaced`) and the
    entries the resume arms write (`resumed`, `settings`) are modelled; `run_started`,
    `state_delta`, `run_finished`, `park`, `wake` neither change `history` nor `dangling`
    and the fold accepts them from either writer.
  * The envelope (`id`, `parent_id`, `seq`, `at_ms`) is abstracted to a 1-based position: both
    writers produce a linear chain and the fold walks it from the last line (`journal_leaf`).

Fixes to the model forced by the differential test (step 2) are recorded in
`diff/MODEL_FIXES.md` and counted in SUMMARY.md: there were none.

CHECKED 2026-11-04. Lean 4.28.0 accepts this file with no error or warning, and no theorem
uses an axiom beyond `propext` (axioms.txt). `diff/run_diff.sh` runs 7,381 runs × 3 comparisons
(host, twin, host across processes) and finds 0 mismatches between this model and the real
code. Its negative control, with both one-line fixes applied to the real side, finds exactly
the 416 mismatches the model predicts.
-/

/-! ## Messages and digests -/

inductive Role where
  | system | user | assistant | tool
  deriving DecidableEq, Repr

structure Msg where
  role    : Role
  content : String
  calls   : List String   -- `call_ids(m.tool_calls)`
  callId  : String        -- `m.tool_call_id`
  deriving DecidableEq, Repr

inductive Dg where
  | base  : List Msg → Dg          -- `chain_digest_base` / `digest_messages`
  | after : Dg → Msg → Dg          -- `chain_digest_after`
  deriving DecidableEq, Repr

def emptyBase : Dg := .base []                       -- `chain_empty_base()`
def chainOver (b : Dg) (ms : List Msg) : Dg := ms.foldl .after b   -- `chain_digest_over`

-- `chain_digests_over(base, ms)` (journal.ail:292). It ignores `base` and starts from the
-- empty base; every caller passes the empty base.
def chainDigests (ms : List Msg) : List Dg :=
  (ms.foldl (fun (acc : Dg × List Dg) m => (Dg.after acc.1 m, acc.2 ++ [Dg.after acc.1 m]))
    (emptyBase, [])).2

/-! ## Wire events and journal entries -/

inductive Ev where
  | seeded   (msgs : List Msg) (digest : Dg) (digests : List Dg)       -- `history_seeded`
  | appended (m : Msg) (rep : Bool) (d : Dg)                           -- `history_appended`
  | replaced (reason : String) (firstKept : Option Int) (msgs : List Msg) (d : Dg)
  | resumed  (promptFrom promptTo profileFrom profileTo : String)      -- `session_resumed`
  deriving DecidableEq, Repr

inductive Entry where
  | appended (m : Msg) (rep : Bool) (d : Dg)
  | replaced (reason : String) (firstKept : Option Int) (msgs : List Msg) (d : Dg)
  | resumed
  | settings (profile : String)
  deriving DecidableEq, Repr

/-! ## The fold (journal.ail) -/

inductive Refusal where
  | digest  (seq : Nat)
  | pairing (seq : Int)
  | headPrefix
  | transcript
  deriving DecidableEq, Repr

def Refusal.id : Refusal → String
  | .digest _ => "digest"
  | .pairing _ => "pairing"
  | .headPrefix => "head-prefix"
  | .transcript => "transcript"

structure FoldAcc where
  err        : Option Refusal := none
  rev        : List (Int × Msg) := []      -- `rev_msgs`, newest first; `HistMsg = {seq, m}`
  digest     : Dg := emptyBase
  digestPrev : Dg := emptyBase
  deriving Repr

def takeSystem : List (Int × Msg) → List (Int × Msg)          -- `take_system_hist`
  | [] => []
  | h :: rest => if h.2.role = .system then h :: takeSystem rest else []

def dropHist : Int → List (Int × Msg) → List (Int × Msg)       -- `drop_hist`
  | _, [] => []
  | n, x :: xs => if n ≤ 0 then x :: xs else dropHist (n - 1) xs

def foldEntry (acc : FoldAcc) (se : Nat × Entry) : FoldAcc :=
  match acc.err with
  | some _ => acc
  | none =>
    match se.2 with
    | .appended m rep d =>                                       -- `fold_append`
      let base := if rep then acc.digestPrev else acc.digest
      let kept := if rep then acc.rev.tail else acc.rev
      let expected := Dg.after base m
      if d ≠ expected then { acc with err := some (.digest se.1) }
      else { acc with rev := ((se.1 : Int), m) :: kept, digest := expected, digestPrev := base }
    | .replaced reason fk msgs d =>                              -- `fold_replace`
      let switch := reason = "profile_switch" ∨ reason = "resume"
      let forward := acc.rev.reverse
      let pre := if switch then [] else takeSystem forward
      let kept := if switch then [] else match fk with | none => [] | some i => dropHist i forward
      let replacement := msgs.map (fun m => ((se.1 : Int), m))
      let emitted := pre ++ replacement ++ kept
      let expected := if switch then chainOver emptyBase msgs
                      else Dg.base ((pre ++ replacement).map Prod.snd)
      if d ≠ expected then { acc with err := some (.digest se.1) }
      else { acc with rev := emitted.reverse, digest := expected, digestPrev := acc.digest }
    | _ => acc                                                   -- `resumed`, `settings`

-- Pairing (D4 rules 3b/4): `pair_step`, branch for branch.
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

def pair0 : PairAcc := { err := none, openIds := [], curIds := [], curSeq := -1 }

def pairStep (acc : PairAcc) (h : Int × Msg) : PairAcc :=
  match acc.err with
  | some _ => acc
  | none =>
    if h.2.role = .tool then
      if containsString acc.curIds h.2.callId
      then { acc with openIds := withoutString acc.openIds h.2.callId }
      else { acc with err := some h.1 }
    else if acc.openIds.length > 0 then { acc with err := some acc.curSeq }
    else if h.2.calls.length > 0 then
      { acc with openIds := h.2.calls, curIds := h.2.calls, curSeq := h.1 }
    else acc

def keepCalls (dangling : List String) : List String → List String
  | [] => []
  | c :: rest => if containsString dangling c then keepCalls dangling rest else c :: keepCalls dangling rest

def stripDangling (dangling : List String) (curSeq : Int) : List (Int × Msg) → List (Int × Msg)
  | [] => []
  | h :: rest =>
    if h.1 = curSeq ∧ h.2.calls.length > 0
    then (h.1, { h.2 with calls := keepCalls dangling h.2.calls }) :: stripDangling dangling curSeq rest
    else h :: stripDangling dangling curSeq rest

def headPrefix : List Msg → Bool → Bool                      -- `system_is_head_prefix`
  | [], _ => true
  | m :: rest, still => if m.role = .system then still && headPrefix rest true else headPrefix rest false

def validTranscript : List Msg → Bool                         -- `valid_message_transcript`
  | [] => true
  | m :: rest =>
    if m.role = .tool then m.callId != "" && validTranscript rest
    else m.calls.all (· != "") && validTranscript rest

-- The fold's verdict, `history` and `dangling`.
abbrev Verdict := Except Refusal (List Msg × List String)

def finishFold (acc : FoldAcc) : Verdict :=
  let forward := acc.rev.reverse
  let p := forward.foldl pairStep pair0
  match p.err with
  | some s => .error (.pairing s)
  | none =>
    let stripped := if p.openIds.length = 0 then forward else stripDangling p.openIds p.curSeq forward
    let msgs := stripped.map Prod.snd
    if !headPrefix msgs true then .error .headPrefix
    else if !validTranscript msgs then .error .transcript
    else .ok (msgs, p.openIds)

def tagE : Nat → List Entry → List (Nat × Entry)
  | _, [] => []
  | n, e :: es => (n, e) :: tagE (n + 1) es

-- `fold_journal(lines, journal_leaf(lines))` on a linear journal whose line 0 is the header.
def foldJournal (es : List Entry) : Verdict :=
  let acc := (tagE 1 es).foldl foldEntry {}
  match acc.err with
  | some r => .error r
  | none => finishFold acc

def hasDangling (v : Verdict) : Bool :=
  match v with
  | .ok (_, d) => d.length > 0
  | .error _ => false

/-! ## The host writer (session-journal.ts) -/

structure Host where
  seeded        : Bool := false
  replaceNext   : Bool := false
  replaceReason : String := "profile_switch"
  chain         : Option Dg := none          -- `chainDigest`, `""` is `none`
  openIds       : List String := []          -- `openCallIds`
  count         : Nat := 0                   -- `historyMessages`
  replacedSince : Bool := false              -- `replacedSinceSeed`
  unresumable   : Bool := false
  out           : List Entry := []
  deriving Repr

-- `updatePending`: the host's three-line twin of D4 rule 4.
def updatePending (opn : List String) (m : Msg) : List String :=
  if m.calls.length > 0 then m.calls.filter (fun id => id != "")
  else if m.callId != "" then opn.filter (fun id => id != m.callId)
  else opn

def Host.emit (h : Host) (e : Entry) : Host := { h with out := h.out ++ [e] }

def Host.noteMsg (h : Host) (m : Msg) : Host :=                 -- `noteHistoryMessage`
  { h with count := h.count + 1, openIds := updatePending h.openIds m }

-- `replaceLastHistoryMessage`, AS WRITTEN: it adjusts the count and never reads `message`.
def Host.replaceLast (h : Host) (_m : Msg) : Host :=
  if h.count = 0 then { h with count := 1 } else h

def Host.seedExpand : Host → List Msg → List Dg → Host
  | h, m :: ms, d :: ds => Host.seedExpand ({ h.emit (.appended m false d) with chain := some d }.noteMsg m) ms ds
  | h, _, _ => h

def Host.record (h : Host) : Ev → Host
  | .seeded msgs digest digests =>
    if !h.seeded then
      let h := { h with seeded := true }
      if digests.length ≠ msgs.length then { h with unresumable := true }
      else { h.seedExpand msgs digests with chain := some digest, replacedSince := false }
    else if h.replaceNext then
      { h.emit (.replaced h.replaceReason none msgs digest) with
          replaceNext := false, chain := some digest, count := msgs.length, openIds := [],
          replacedSince := false }
    else if some digest ≠ h.chain then { h with unresumable := true } else h
  | .appended m rep d =>
    let h := { h.emit (.appended m rep d) with chain := some d }
    if rep then h.replaceLast m else h.noteMsg m
  | .replaced reason fk msgs d =>
    let fk' := match fk with
      | some k => if 0 ≤ k ∧ k ≤ (h.count : Int) then some k else none
      | none => none
    { h.emit (.replaced reason fk' msgs d) with
        chain := some d, count := msgs.length, openIds := [], replacedSince := true }
  | .resumed pf pt rf rt =>
    let h := h.emit .resumed
    let h := { h with replaceNext := decide (pf ≠ pt) || h.openIds.length > 0 || h.replacedSince,
                      replaceReason := if pf ≠ pt then "profile_switch" else "resume" }
    if rt ≠ "" ∧ rt ≠ rf then h.emit (.settings rt) else h

def hostJournal (evs : List Ev) : List Entry := (evs.foldl Host.record {}).out

-- `adopt` (session-journal.ts:288-333): the state a NEW `SessionJournal` on an existing file
-- rebuilds, entry by entry. It is what a host process that starts after a `kill -9` or a quit
-- holds when the resumed child's first event arrives.
def Host.adoptEntry (h : Host) : Entry → Host
  | .appended m rep d =>
    let h := { h with seeded := true, chain := some d }
    if rep then h.replaceLast m else h.noteMsg m
  | .replaced _ _ msgs d =>
    { h with seeded := true, chain := some d, count := msgs.length, openIds := [], replacedSince := true }
  | _ => h

def Host.adopt (es : List Entry) : Host := { es.foldl Host.adoptEntry {} with out := es }

-- The host across processes: every `session_resumed` arrives at a freshly adopted host.
def Host.recordAcross (h : Host) (e : Ev) : Host :=
  match e with
  | .resumed .. => (Host.adopt h.out).record e
  | _ => h.record e

def hostJournalAcross (evs : List Ev) : List Entry := (evs.foldl Host.recordAcross {}).out

/-! ## The twin writer (journal.ail) -/

structure Twin where
  out           : List Entry := []
  seeded        : Bool := false
  replaceNext   : Bool := false
  replaceReason : String := "profile_switch"
  replacedSince : Bool := false
  digest        : Dg := emptyBase
  deriving Repr

def Twin.seedMessages (t : Twin) : List Msg → Twin              -- `twin_seed_messages`
  | [] => t
  | m :: ms =>
    let d := Dg.after t.digest m
    Twin.seedMessages { t with out := t.out ++ [.appended m false d], digest := d } ms

def Twin.record (t : Twin) : Ev → Twin
  | .seeded msgs digest _ =>
    if t.seeded && t.replaceNext then
      { t with out := t.out ++ [.replaced t.replaceReason none msgs digest], digest := digest,
               replaceNext := false, replacedSince := false }
    else if t.seeded then t
    else Twin.seedMessages { t with seeded := true } msgs
  | .appended m rep d => { t with out := t.out ++ [.appended m rep d], digest := d }
  -- AS WRITTEN: `{ next | digest: i.digest_after }` — `replaced_since_seed` is not set.
  | .replaced reason fk msgs d => { t with out := t.out ++ [.replaced reason fk msgs d], digest := d }
  | .resumed pf pt rf rt =>
    let dangling := hasDangling (foldJournal t.out)                 -- `twin_has_dangling(acc)`
    let t := { t with out := t.out ++ [.resumed],
                      replaceNext := decide (pf ≠ pt) || t.replacedSince || dangling,
                      replaceReason := if pf ≠ pt then "profile_switch" else "resume" }
    if rt = rf then t else { t with out := t.out ++ [.settings rt] }

def twinJournal (evs : List Ev) : List Entry := (evs.foldl Twin.record {}).out

/-! ## What a run emits: the child, as `session.ail` drives it

The child keeps its history and its chain pair `{at, prev}` (session.ail:482-506). -/

def sysMsg : Msg := ⟨.system, "you are motoko", [], ""⟩
def sys2Msg : Msg := ⟨.system, "you are motoko, switched", [], ""⟩
def usrMsg : Msg := ⟨.user, "list the files", [], ""⟩
def a0 : Msg := ⟨.assistant, "plain", [], ""⟩            -- the plain assistant (hybrid extraction)
def a1 : Msg := ⟨.assistant, "calls", ["c1"], ""⟩        -- an assistant that makes one call
def a1h : Msg := ⟨.assistant, "plain", ["c1"], ""⟩       -- the hybrid batch's augmented assistant
def t1 : Msg := ⟨.tool, "result", [], "c1"⟩
def u2 : Msg := ⟨.user, "next", [], ""⟩
def summaryMsg : Msg := ⟨.assistant, "[CHECKPOINT] s", [], ""⟩

structure Child where
  hist : List Msg
  cur  : Dg
  prev : Dg
  deriving Repr

-- `c2_seed_digest` (session.ail:501): `{at, prev}` over the whole list from the empty base.
def seedDigest (ms : List Msg) : Dg × Dg :=
  ms.foldl (fun (p : Dg × Dg) m => (Dg.after p.1 m, p.1)) (emptyBase, emptyBase)

def tagM : Int → List Msg → List (Int × Msg)
  | _, [] => []
  | n, m :: ms => (n, m) :: tagM (n + 1) ms

-- The resume plan's history: the fold's rule 4 over the child's own history.
def planOf (ms : List Msg) : List Msg :=
  let tagged := tagM 0 ms
  let p := tagged.foldl pairStep pair0
  if p.err.isSome || p.openIds.length = 0 then ms
  else (stripDangling p.openIds p.curSeq tagged).map Prod.snd

def seedEv (ms : List Msg) : Ev := .seeded ms (chainOver emptyBase ms) (chainDigests ms)

def Child.reseed (ms : List Msg) : Child := { hist := ms, cur := (seedDigest ms).1, prev := (seedDigest ms).2 }

def Child.app (c : Child) (m : Msg) : Child × List Ev :=
  ({ hist := c.hist ++ [m], cur := .after c.cur m, prev := c.cur }, [.appended m false (.after c.cur m)])

/-- Actions: 0 A a0, 1 A a1, 2 A t1, 3 A u2, 4 R a1h (hybrid), 5 C checkpoint,
    6 X resume (same profile), 7 Y resume (profile switch), 8 F follow-up turn. -/
def Child.step (c : Child) : Nat → Child × List Ev
  | 0 => c.app a0
  | 1 => c.app a1
  | 2 => c.app t1
  | 3 => c.app u2
  | 4 => ({ hist := c.hist.dropLast ++ [a1h], cur := .after c.prev a1h, prev := c.prev },
          [.appended a1h true (.after c.prev a1h)])
  | 5 =>
    let cp := (c.hist.takeWhile (fun m => m.role = .system)) ++ [summaryMsg]
    ({ hist := cp, cur := .base cp, prev := c.cur }, [.replaced "checkpoint" none [summaryMsg] (.base cp)])
  | 6 =>
    let plan := planOf c.hist
    (Child.reseed plan, [.resumed "p0" "p0" "prof" "prof", seedEv plan])
  | 7 =>
    let plan := sys2Msg :: (planOf c.hist).dropWhile (fun m => m.role = .system)
    (Child.reseed plan, [.resumed "p0" "p1" "prof" "prof2", seedEv plan])
  -- 8: a follow-up turn (session.ail:4387-4393): the operator's message, chained from the
  -- turn history's seed digest, then the run's seed of the history with it.
  | _ =>
    let h := c.hist ++ [u2]
    (Child.reseed h, [.appended u2 false (.after (seedDigest c.hist).1 u2), seedEv h])

def child0 : Child := Child.reseed [sysMsg, usrMsg]

def runOf (acts : List Nat) : Child × List Ev :=
  acts.foldl (fun (p : Child × List Ev) a => let r := p.1.step a; (r.1, p.2 ++ r.2))
    (child0, [seedEv [sysMsg, usrMsg]])

def eventsOf (acts : List Nat) : List Ev := (runOf acts).2

-- A sequence a run can emit: every prefix's history passes the pairing rule, a result answers an
-- open call, the hybrid replacement directly follows the plain assistant, and a checkpoint or a
-- follow-up seed happens only with no call open (between steps / between turns).
def openOf (ms : List Msg) : Option (List String) :=
  let p := (tagM 0 ms).foldl pairStep pair0
  if p.err.isSome then none else some p.openIds

-- `last` is the previous action (none at the start of the run).
def validStep (c : Child) (last : Option Nat) (a : Nat) : Bool :=
  match openOf c.hist with
  | none => false
  | some opn =>
    match a with
    | 2 => containsString opn "c1"
    | 4 => last == some 0
    | 5 => opn.isEmpty
    | 8 => opn.isEmpty
    | _ => true

def validRun (acts : List Nat) : Bool :=
  let r := acts.foldl (fun (p : Child × Option Nat × Bool) a =>
      (p.1.step a |>.1, some a, p.2.2 && validStep p.1 p.2.1 a)) (child0, none, true)
  r.2.2 && (openOf r.1.hist).isSome

-- The history rule 3 defines for the run (the child's own history), and rule 4 applied to it.
def specOf (acts : List Nat) : List Msg × List String :=
  let h := (runOf acts).1.hist
  (planOf h, (openOf h).getD [])

/-! ## Verdict projections (decidable) -/

def refusalId : Verdict → Option String
  | .error r => some r.id
  | .ok _ => none

def accepted (v : Verdict) : Option (List Msg × List String) := v.toOption

/-! ## Counterexamples (`bug_`), each on a sequence the model marks as one a run can emit -/

-- (1) THE TWIN NEVER SETS `replaced_since_seed`. After a checkpoint, a same-profile resume
-- with no open call: the host arms D1's second arm (its `replacedSinceSeed` is set by the
-- checkpoint) and writes `history_replaced(resume)`; the twin's flag is still false, so it
-- DROPS the resume seed (arm 3), and the resumed run's first append chains from a digest the
-- twin's journal does not hold. P3.1: host accepts, twin refuses `digest`. P3.2: the twin's
-- journal of a record list a run can emit is refused.
theorem bug_twin_checkpoint_then_resume :
    validRun [5, 6, 0] = true ∧
    accepted (foldJournal (hostJournal (eventsOf [5, 6, 0]))) = some (specOf [5, 6, 0]) ∧
    refusalId (foldJournal (twinJournal (eventsOf [5, 6, 0]))) = some "digest" := by
  decide

-- (2) THE HOST'S `replaceLastHistoryMessage` NEVER UPDATES THE OPEN-CALL SET. On the hybrid
-- path (plain assistant, then the augmented assistant with `replaces_previous` and a call),
-- a crash before the result leaves the fold with `dangling = [c1]` but the host with no open
-- call, so on the resume it does not arm D1's second arm; the twin, reading the fold, does.
-- P3.1: both accept, with `dangling = [c1]` (host) and `[]` (twin).
theorem bug_host_hybrid_call_not_pending :
    validRun [0, 4, 6] = true ∧
    (accepted (foldJournal (hostJournal (eventsOf [0, 4, 6])))).map Prod.snd = some ["c1"] ∧
    (accepted (foldJournal (twinJournal (eventsOf [0, 4, 6])))).map Prod.snd = some [] ∧
    (specOf [0, 4, 6]).2 = [] := by
  decide

-- ... and one more append makes it a refusal on the host side only.
theorem bug_host_hybrid_then_append :
    validRun [0, 4, 6, 0] = true ∧
    refusalId (foldJournal (hostJournal (eventsOf [0, 4, 6, 0]))) = some "digest" ∧
    accepted (foldJournal (twinJournal (eventsOf [0, 4, 6, 0]))) = some (specOf [0, 4, 6, 0]) := by
  decide

-- The same, across processes: the adopted host (`adopt`) has the same blind spot, because
-- `adopt` routes a `replaces_previous` entry through the same `replaceLastHistoryMessage`.
theorem bug_host_hybrid_across_processes :
    refusalId (foldJournal (hostJournalAcross (eventsOf [0, 4, 6, 0]))) = some "digest" := by
  decide

-- (3) P3.2 BOTH WAYS: a checkpoint, then a follow-up turn. The conversation loop chains the
-- operator's message from `c2_seed_digest(turn_history)`, the chain from the empty base,
-- while the journal's chain was re-based by the checkpoint (session.ail:4372-4386 states this
-- as a known limitation). Both writers write a journal the fold refuses.
theorem bug_checkpoint_then_followup_turn :
    validRun [5, 8] = true ∧
    refusalId (foldJournal (hostJournal (eventsOf [5, 8]))) = some "digest" ∧
    refusalId (foldJournal (twinJournal (eventsOf [5, 8]))) = some "digest" := by
  decide

/-! ## P3.1, proved for every length on the fragment without resumes

Host and twin write THE SAME JOURNAL for any run that starts with a well-formed seed (the child's
own `digests`) and then emits any number of `history_seeded`, `history_appended` (with or
without `replaces_previous`, any digest) and `history_replaced` events with `first_kept = None`
— i.e. everything except `session_resumed` and a `first_kept`. So on that fragment they fold
alike by construction. The counterexamples above show both exclusions are needed. -/

def okEv : Ev → Bool
  | .resumed .. => false
  | .replaced _ (some _) _ _ => false
  | _ => true

def chainFrom : Dg → List Msg → List Dg
  | _, [] => []
  | d, m :: ms => Dg.after d m :: chainFrom (Dg.after d m) ms

def seedEntries : Dg → List Msg → List Entry
  | _, [] => []
  | d, m :: ms => .appended m false (Dg.after d m) :: seedEntries (Dg.after d m) ms

theorem chainFrom_length (d : Dg) (ms : List Msg) : (chainFrom d ms).length = ms.length := by
  induction ms generalizing d with
  | nil => rfl
  | cons m ms ih => simp [chainFrom, ih]

theorem chainDigests_foldl (ms : List Msg) (d : Dg) (pre : List Dg) :
    (ms.foldl (fun (acc : Dg × List Dg) m => (Dg.after acc.1 m, acc.2 ++ [Dg.after acc.1 m]))
      (d, pre)).2 = pre ++ chainFrom d ms := by
  induction ms generalizing d pre with
  | nil => simp [chainFrom]
  | cons m ms ih => simp [List.foldl, ih, chainFrom]

theorem chainDigests_eq (ms : List Msg) : chainDigests ms = chainFrom emptyBase ms := by
  simp [chainDigests, chainDigests_foldl]

theorem host_seedExpand (h : Host) (d : Dg) (ms : List Msg) :
    (h.seedExpand ms (chainFrom d ms)).out = h.out ++ seedEntries d ms ∧
    (h.seedExpand ms (chainFrom d ms)).seeded = h.seeded ∧
    (h.seedExpand ms (chainFrom d ms)).replaceNext = h.replaceNext := by
  induction ms generalizing h d with
  | nil => simp [Host.seedExpand, seedEntries]
  | cons m ms ih =>
    simp only [chainFrom, Host.seedExpand, seedEntries]
    obtain ⟨h1, h2, h3⟩ := ih ({ h.emit (.appended m false (Dg.after d m)) with chain := some (Dg.after d m) }.noteMsg m) (Dg.after d m)
    refine ⟨?_, ?_, ?_⟩
    · rw [h1]; simp [Host.noteMsg, Host.emit]
    · rw [h2]; simp [Host.noteMsg, Host.emit]
    · rw [h3]; simp [Host.noteMsg, Host.emit]

theorem twin_seedMessages (t : Twin) (ms : List Msg) :
    (t.seedMessages ms).out = t.out ++ seedEntries t.digest ms ∧
    (t.seedMessages ms).seeded = t.seeded ∧
    (t.seedMessages ms).replaceNext = t.replaceNext := by
  induction ms generalizing t with
  | nil => simp [Twin.seedMessages, seedEntries]
  | cons m ms ih =>
    simp only [Twin.seedMessages, seedEntries]
    obtain ⟨h1, h2, h3⟩ := ih { t with out := t.out ++ [.appended m false (Dg.after t.digest m)], digest := Dg.after t.digest m }
    exact ⟨by rw [h1]; simp, h2, h3⟩

-- The invariant after the first seed: same journal so far, both seeded, neither armed.
def TwinInv (h : Host) (t : Twin) : Prop :=
  h.out = t.out ∧ h.seeded = true ∧ t.seeded = true ∧ h.replaceNext = false ∧ t.replaceNext = false

theorem inv_step (h : Host) (t : Twin) (e : Ev) (hi : TwinInv h t) (he : okEv e = true) :
    TwinInv (h.record e) (t.record e) := by
  obtain ⟨ho, hs, ts, hr, tr⟩ := hi
  cases e with
  | seeded msgs d ds =>
    unfold TwinInv
    simp only [Host.record, Twin.record, hs, ts, hr, tr]
    by_cases hc : some d = h.chain <;> simp_all
  | appended m rep d =>
    unfold TwinInv
    cases rep <;> simp [Host.record, Twin.record, Host.emit, Host.noteMsg, Host.replaceLast, ho, hs, ts, hr, tr] <;> split <;> simp_all
  | replaced reason fk msgs d =>
    cases fk with
    | none => exact ⟨by simp [Host.record, Twin.record, Host.emit, ho], by simp [Host.record, Host.emit, hs],
                     by simp [Twin.record, ts], by simp [Host.record, Host.emit, hr], by simp [Twin.record, tr]⟩
    | some k => simp [okEv] at he
  | resumed => simp [okEv] at he

theorem inv_fold (rest : List Ev) (h : Host) (t : Twin) (hi : TwinInv h t) (hok : rest.all okEv = true) :
    TwinInv (rest.foldl Host.record h) (rest.foldl Twin.record t) := by
  induction rest generalizing h t with
  | nil => exact hi
  | cons e rest ih =>
    simp only [List.all_cons, Bool.and_eq_true] at hok
    exact ih _ _ (inv_step h t e hi hok.1) hok.2

theorem inv_seed (ms : List Msg) : TwinInv (({} : Host).record (seedEv ms)) (({} : Twin).record (seedEv ms)) := by
  obtain ⟨h1, h2, h3⟩ := host_seedExpand { ({} : Host) with seeded := true } emptyBase ms
  obtain ⟨t1, t2, t3⟩ := twin_seedMessages { ({} : Twin) with seeded := true } ms
  simp only [seedEv, Host.record, Twin.record, chainDigests_eq, chainFrom_length]
  refine ⟨?_, ?_, ?_, ?_, ?_⟩ <;> simp_all <;> rfl

theorem host_twin_same_journal_without_resume (ms : List Msg) (rest : List Ev)
    (hok : rest.all okEv = true) :
    hostJournal (seedEv ms :: rest) = twinJournal (seedEv ms :: rest) := by
  have := inv_fold rest _ _ (inv_seed ms) hok
  exact this.1

-- P3.1 on that fragment, in the property's own terms: the two journals fold alike.
theorem p31_without_resume (ms : List Msg) (rest : List Ev) (hok : rest.all okEv = true) :
    foldJournal (hostJournal (seedEv ms :: rest)) = foldJournal (twinJournal (seedEv ms :: rest)) := by
  rw [host_twin_same_journal_without_resume ms rest hok]

-- Not vacuous: the hypotheses hold of a run with a checkpoint and a hybrid replacement.
theorem p31_without_resume_witness :
    (eventsOf [0, 4, 2, 5, 0]).all okEv = true ∧ validRun [0, 4, 2, 5, 0] = true ∧
    (eventsOf [0, 4, 2, 5, 0]).head? = some (seedEv [sysMsg, usrMsg]) := by
  decide

/-! ## The fixes (Kiro's step 8)

TWIN: `HistoryReplaced(i) => { next | digest: i.digest_after, replaced_since_seed: true }`
(journal.ail:2049), which is what the field's own comment (:1938-1939) and the host's
`recordReplaced` (session-journal.ts:724) say.
HOST: `replaceLastHistoryMessage` also calls `this.updatePending(message)`
(session-journal.ts:854-856); `adopt` routes `replaces_previous` entries through it, so the one
line fixes both the live and the adopted host. -/

def Twin.recordFixed (t : Twin) (e : Ev) : Twin :=
  match e with
  | .replaced .. => { t.record e with replacedSince := true }
  | _ => t.record e

def Host.recordFixed (h : Host) (e : Ev) : Host :=
  match e with
  | .appended m true _ => let h' := h.record e; { h' with openIds := updatePending h'.openIds m }
  | _ => h.record e

def Host.adoptEntryFixed (h : Host) (e : Entry) : Host :=
  match e with
  | .appended m true _ => let h' := h.adoptEntry e; { h' with openIds := updatePending h'.openIds m }
  | _ => h.adoptEntry e

def Host.recordAcrossFixed (h : Host) (e : Ev) : Host :=
  match e with
  | .resumed .. => ({ h.out.foldl Host.adoptEntryFixed {} with out := h.out }).recordFixed e
  | _ => h.recordFixed e

def twinJournalFixed (evs : List Ev) : List Entry := (evs.foldl Twin.recordFixed {}).out
def hostJournalFixed (evs : List Ev) : List Entry := (evs.foldl Host.recordFixed {}).out
def hostJournalAcrossFixed (evs : List Ev) : List Entry := (evs.foldl Host.recordAcrossFixed {}).out

theorem fix_twin_closes_checkpoint_then_resume :
    accepted (foldJournal (twinJournalFixed (eventsOf [5, 6, 0]))) = some (specOf [5, 6, 0]) ∧
    accepted (foldJournal (hostJournal (eventsOf [5, 6, 0]))) = some (specOf [5, 6, 0]) := by
  decide

theorem fix_host_closes_hybrid :
    accepted (foldJournal (hostJournalFixed (eventsOf [0, 4, 6]))) = some (specOf [0, 4, 6]) ∧
    accepted (foldJournal (hostJournalFixed (eventsOf [0, 4, 6, 0]))) = some (specOf [0, 4, 6, 0]) ∧
    accepted (foldJournal (hostJournalAcrossFixed (eventsOf [0, 4, 6, 0]))) = some (specOf [0, 4, 6, 0]) := by
  decide

-- The fixes do not touch the fragment `host_twin_same_journal_without_resume` covers, except
-- through the flags they set, which only a `session_resumed` reads.
theorem fix_keeps_known_limitation :
    refusalId (foldJournal (twinJournalFixed (eventsOf [5, 8]))) = some "digest" := by
  decide

/-! ## X-1 (exploratory): `first_kept` after a checkpoint

The host checks `first_kept` against `historyMessages`, which after a checkpoint is the
replacement's `messages.length` (session-journal.ts:722) while the fold's pre-checkpoint history
is the head system prefix PLUS those messages (journal.ail:1500-1503). With a two-message system
prefix, an index the fold resolves is "out of range" to the host, which DROPS the field and still
writes the entry (session-journal.ts:704-712): the fold then keeps no tail. The twin writes the
field as given. Not reachable at HEAD: the only producer sends `first_kept: None`
(session.ail:3109-3116). -/

def sysB : Msg := ⟨.system, "project rules", [], ""⟩

def x1Events : List Ev :=
  let s := [sysMsg, sysB, usrMsg]
  let d0 := chainOver emptyBase s
  let d1 := Dg.after d0 a0
  let cp := [sysMsg, sysB, summaryMsg]
  let d2 := Dg.after (.base cp) u2
  [seedEv s, .appended a0 false d1, .replaced "checkpoint" none [summaryMsg] (.base cp),
   .appended u2 false d2, .replaced "checkpoint" (some 3) [summaryMsg] (.base cp)]

theorem bug_host_drops_first_kept_after_checkpoint :
    accepted (foldJournal (hostJournal x1Events)) = some ([sysMsg, sysB, summaryMsg], []) ∧
    accepted (foldJournal (twinJournal x1Events)) = some ([sysMsg, sysB, summaryMsg, u2], []) := by
  decide

/-! ## P3.2, rule 3, proved for every length on the append-only fragment

A run that seeds `s` and then appends `ms`, each `digest_after` the child's chain
(`c2_chain_step`): the twin's journal passes every digest check of the fold, and the history the
fold hands to rules 3b/4 is exactly `s ++ ms` — the seed, then one message per appended entry.
The host writes the same journal (`host_twin_same_journal_without_resume`), so the same holds of
it. Rules 3b/4 (pairing, strip, head prefix, transcript) then apply to that history. -/

def appendEvs : Dg → List Msg → List Ev
  | _, [] => []
  | d, m :: ms => .appended m false (Dg.after d m) :: appendEvs (Dg.after d m) ms

theorem seedEntries_append (d : Dg) (xs ys : List Msg) :
    seedEntries d (xs ++ ys) = seedEntries d xs ++ seedEntries (chainOver d xs) ys := by
  induction xs generalizing d with
  | nil => rfl
  | cons x xs ih => simp [seedEntries, chainOver, List.foldl, ih]

theorem twin_seedMessages_digest (t : Twin) (ms : List Msg) :
    (t.seedMessages ms).digest = chainOver t.digest ms := by
  induction ms generalizing t with
  | nil => rfl
  | cons m ms ih => simp [Twin.seedMessages, ih, chainOver, List.foldl]

theorem twin_appendEvs (t : Twin) (ms : List Msg) :
    ((appendEvs t.digest ms).foldl Twin.record t).out = t.out ++ seedEntries t.digest ms ∧
    ((appendEvs t.digest ms).foldl Twin.record t).digest = chainOver t.digest ms := by
  induction ms generalizing t with
  | nil => simp [appendEvs, seedEntries, chainOver]
  | cons m ms ih =>
    simp only [appendEvs, List.foldl_cons]
    have := ih (t.record (.appended m false (Dg.after t.digest m)))
    simp only [Twin.record] at this ⊢
    refine ⟨?_, ?_⟩
    · rw [this.1]; simp [seedEntries]
    · rw [this.2]; simp [chainOver, List.foldl]

theorem twin_journal_append_only (s ms : List Msg) :
    twinJournal (seedEv s :: appendEvs (chainOver emptyBase s) ms) = seedEntries emptyBase (s ++ ms) := by
  unfold twinJournal
  simp only [List.foldl_cons]
  have hs : (({} : Twin).record (seedEv s)) = ({ seeded := true } : Twin).seedMessages s := by
    simp [seedEv, Twin.record]
  have hd : (({} : Twin).record (seedEv s)).digest = chainOver emptyBase s := by
    rw [hs, twin_seedMessages_digest]
  have ho : (({} : Twin).record (seedEv s)).out = seedEntries emptyBase s := by
    rw [hs]; have := (twin_seedMessages ({ seeded := true } : Twin) s).1; simpa using this
  have := (twin_appendEvs (({} : Twin).record (seedEv s)) ms).1
  rw [hd] at this
  rw [this, ho, seedEntries_append]

theorem fold_seedEntries (xs : List Msg) (n : Nat) (acc : FoldAcc) (h : acc.err = none) :
    ((tagE n (seedEntries acc.digest xs)).foldl foldEntry acc).err = none ∧
    ((tagE n (seedEntries acc.digest xs)).foldl foldEntry acc).rev.map Prod.snd
      = xs.reverse ++ acc.rev.map Prod.snd := by
  induction xs generalizing n acc with
  | nil => simp [seedEntries, tagE, h]
  | cons x xs ih =>
    simp only [seedEntries, tagE, List.foldl_cons]
    have hstep : foldEntry acc (n, .appended x false (Dg.after acc.digest x)) =
        { acc with rev := ((n : Int), x) :: acc.rev, digest := Dg.after acc.digest x, digestPrev := acc.digest } := by
      simp [foldEntry, h]
    rw [hstep]
    have := ih (n + 1) { acc with rev := ((n : Int), x) :: acc.rev, digest := Dg.after acc.digest x, digestPrev := acc.digest } (by simp [h])
    refine ⟨this.1, ?_⟩
    rw [this.2]; simp

theorem p32_rule3_append_only (s ms : List Msg) :
    let acc := (tagE 1 (twinJournal (seedEv s :: appendEvs (chainOver emptyBase s) ms))).foldl foldEntry {}
    acc.err = none ∧ acc.rev.reverse.map Prod.snd = s ++ ms ∧
    foldJournal (twinJournal (seedEv s :: appendEvs (chainOver emptyBase s) ms)) = finishFold acc := by
  intro acc
  have key := fold_seedEntries (s ++ ms) 1 ({} : FoldAcc) rfl
  have hj := twin_journal_append_only s ms
  have hacc : acc = (tagE 1 (seedEntries ({} : FoldAcc).digest (s ++ ms))).foldl foldEntry {} := by
    simp only [acc, hj]
  have herr : acc.err = none := by rw [hacc]; exact key.1
  refine ⟨herr, ?_, ?_⟩
  · rw [hacc, List.map_reverse, key.2]; simp
  · show (match acc.err with | some r => Except.error r | none => finishFold acc) = finishFold acc
    rw [herr]

-- Not vacuous: the enumeration's run `1,2,0,3` is in the fragment.
theorem p32_rule3_append_only_witness :
    eventsOf [1, 2, 0, 3] = seedEv [sysMsg, usrMsg] :: appendEvs (chainOver emptyBase [sysMsg, usrMsg]) [a1, t1, a0, u2] := by
  decide

/-! ## Axiom report: every theorem in this file -/

#print axioms bug_twin_checkpoint_then_resume
#print axioms bug_host_hybrid_call_not_pending
#print axioms bug_host_hybrid_then_append
#print axioms bug_host_hybrid_across_processes
#print axioms bug_checkpoint_then_followup_turn
#print axioms chainFrom_length
#print axioms chainDigests_foldl
#print axioms chainDigests_eq
#print axioms host_seedExpand
#print axioms twin_seedMessages
#print axioms inv_step
#print axioms inv_fold
#print axioms inv_seed
#print axioms host_twin_same_journal_without_resume
#print axioms p31_without_resume
#print axioms p31_without_resume_witness
#print axioms fix_twin_closes_checkpoint_then_resume
#print axioms fix_host_closes_hybrid
#print axioms fix_keeps_known_limitation
#print axioms bug_host_drops_first_kept_after_checkpoint
#print axioms seedEntries_append
#print axioms twin_seedMessages_digest
#print axioms twin_appendEvs
#print axioms twin_journal_append_only
#print axioms fold_seedEntries
#print axioms p32_rule3_append_only
#print axioms p32_rule3_append_only_witness
