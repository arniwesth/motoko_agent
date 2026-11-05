/-
ChainModel.lean — a Lean model of the journal's digest chain, and its properties.

Lean 4.28.0, core only (no Mathlib, no Lake):  `lean ChainModel.lean`.
No `sorry`, no `native_decide`; the axiom report is the `#print axioms` block at the end
(captured in ../axioms.txt by diff/run_diff.sh and check_axioms.sh).

SOURCE — the snapshot at /home/motoko/trial-043/s/t043-t4-b1/tree, read 2026-11-04:

  src/core/journal.ail:242-244   chain_digest_base         -> chainDigestBase
  src/core/journal.ail:253-255   chain_digest_after        -> chainDigestAfter
  src/core/journal.ail:260-262   chain_step                -> chainStep
  src/core/journal.ail:264-266   chain_digest_over         -> chainDigestOver
  src/core/journal.ail:287-290   chain_prefix_step         -> chainPrefixStep
  src/core/journal.ail:292-294   chain_digests_over        -> chainDigestsOver
  src/core/journal.ail:299-301   chain_digests_json        -> chainDigestsJsonText (with `encode`)
  src/core/journal.ail:322-324   chain_empty_base          -> chainEmptyBase

and, so that the differential test can compare CONCRETE digests, the callees the chain hashes
through (no theorem below depends on these; every theorem is stated for an arbitrary frame
function `F` and an arbitrary — or an arbitrary injective — hash `H`):

  src/core/phase_vocab.ail:271-273 frame, 275-282 digest_content, 284-290 canonical_tool_calls,
  292-294 canonical_message, 299-301 canonical_messages, 321-323 canonical_message_body,
  325-331 canonical_images, 357-359 canonical_message_frame, 361-363 digest_messages.

CHECKED 2026-11-04, in the session that wrote it:
  * `lean ChainModel.lean` (4.28.0): no error. One warning, `unused variable base` at
    `chainDigestsOver` — the defect, flagged by the linter.
  * check_axioms.sh: every `theorem` has a `#print axioms`; none uses more than propext,
    Classical.choice, Quot.sound (../axioms.txt). No `sorry`, no `native_decide`.
  * diff/run_diff.sh against the REAL code: 0 mismatches on every recorded run
    (SUMMARY.md lists them). Negative control (MUTANT=fixed): the fixed model mismatches the
    real code in exactly the predicted cases; against a tree patched with the fix
    (repro/fix_check.sh) the fixed model has 0 mismatches.

MODEL CHANGES MADE BY STEP (2) — two edits to this file, net zero:
  1. `strLength` changed from scalar values to "scalar values that are not combining marks"
     (a grapheme-count guess) after seed 1 mismatched on "a\u0301". Still mismatched.
  2. Reverted to scalar values. The cause was in the HARNESS, not the model: AILANG
     NFC-normalises string LITERALS ("a\u0301" in source becomes "á"), while strings built
     at run time (`concat(["a", "\u0301"])`) are kept as they are and counted in scalar values.
     gen_cases.py now feeds the Lean half NFC-normalised literals and adds run-time-built
     strings; with that, 0 mismatches. diff/runs/ChainModel.fix1-rejected.lean is edit 1.

WHAT THE MODEL KEEPS AND WHAT IT ABSTRACTS

  * An AILANG `string` is a `List Char` (`Str`). `++` and `${..}` interpolation are list append;
    string equality is list equality. Literals are written `lit "..."`, except the two the
    proofs look inside (`sha256Tag` = "sha256:", `mEnd` = "m-end;"), which are spelled as
    character lists so the kernel never has to decode a `String`.
  * `sha256Hex` is the parameter `H : Str → Str`. Properties that need it assume only
    `Inj H` — the task's "injective black box". The differential test instantiates `H` with a
    real SHA-256 written in Lean (diff/Sha256.lean.tail).
  * `List.foldl` is Lean's `List.foldl`: same argument order (step, init, list), left to right.
  * The chain functions are generic in the message type `α` and in the frame `F : α → Str`
    (`canonical_message_frame` in the source). The concrete model is `F := canonicalMessageFrame`.
  * `Str.length` (std/string `length`) counts Unicode scalar values — settled by the
    differential test (above).
-/

abbrev Str := List Char

def lit (s : String) : Str := s.toList

/-- The task's black-box assumption on `sha256Hex`. -/
def Inj {α β : Type} (f : α → β) : Prop := ∀ a b, f a = f b → a = b

theorem inj_id : Inj (fun s : Str => s) := fun _ _ h => h

/-! ## Message (std/ai) and the canonical frame (phase_vocab.ail) -/

structure ToolCall where
  id        : Str
  name      : Str
  arguments : Str
  deriving Repr, DecidableEq

structure ImagePart where
  source : Str
  mime   : Str
  deriving Repr, DecidableEq

structure Message where
  role         : Str
  content      : Str
  tool_calls   : List ToolCall
  tool_call_id : Str
  images       : List ImagePart
  deriving Repr, DecidableEq

/-- std/string `length`: Unicode scalar values. (A grapheme-count variant was tried as
fix 1 and REJECTED by the differential test; see SUMMARY.md.) -/
def strLength (s : Str) : Nat := s.length

/-- `show(int)` on a non-negative int. -/
def showNat (n : Nat) : Str := lit (toString n)

-- phase_vocab.ail:271-273
def frame (label value : Str) : Str :=
  label ++ lit ":" ++ showNat (strLength value) ++ lit ":" ++ value ++ lit ";"

-- phase_vocab.ail:275-282: `replaceMany` with ("make[20]","make[0]") .. ("make[1]","make[0]"),
-- in that order. MODEL ASSUMPTION: `replaceMany` replaces each pair in turn, all occurrences.
def digestContentPairs : List (String × String) :=
  (List.range 20).reverse.map (fun i => ("make[" ++ toString (i + 1) ++ "]", "make[0]"))

def digestContent (value : Str) : Str :=
  lit (digestContentPairs.foldl (fun s p => s.replace p.1 p.2) (String.ofList value))

-- phase_vocab.ail:284-290
def canonicalToolCalls : List ToolCall → Str
  | [] => lit "tc-end;"
  | c :: rest =>
    lit "tc{" ++ frame (lit "id") c.id ++ frame (lit "name") c.name ++ frame (lit "args") c.arguments
      ++ lit "}" ++ canonicalToolCalls rest

-- phase_vocab.ail:292-294
def canonicalMessage (m : Message) : Str :=
  lit "m{" ++ frame (lit "role") m.role ++ frame (lit "content") (digestContent m.content)
    ++ frame (lit "tool_call_id") m.tool_call_id
    ++ frame (lit "tool_calls_len") (showNat m.tool_calls.length)
    ++ canonicalToolCalls m.tool_calls ++ lit "}"

/-- "m-end;" -/
def mEnd : Str := ['m', '-', 'e', 'n', 'd', ';']

-- phase_vocab.ail:299-301: `concat(List.map(canonical_message, msgs) ++ ["m-end;"])`
def canonicalMessages (msgs : List Message) : Str :=
  List.flatten (msgs.map canonicalMessage ++ [mEnd])

-- phase_vocab.ail:321-323
def canonicalMessageBody (m : Message) : Str :=
  frame (lit "role") m.role ++ frame (lit "content") m.content
    ++ frame (lit "tool_call_id") m.tool_call_id
    ++ frame (lit "tool_calls_len") (showNat m.tool_calls.length)
    ++ canonicalToolCalls m.tool_calls

-- phase_vocab.ail:325-331
def canonicalImages : List ImagePart → Str
  | [] => lit "im-end;"
  | i :: rest =>
    lit "im{" ++ frame (lit "source") i.source ++ frame (lit "mime") i.mime ++ lit "}"
      ++ canonicalImages rest

-- phase_vocab.ail:357-359
def canonicalMessageFrame (m : Message) : Str :=
  lit "m{" ++ canonicalMessageBody m ++ canonicalImages m.images ++ lit "}"

/-- "sha256:" -/
def sha256Tag : Str := ['s', 'h', 'a', '2', '5', '6', ':']

-- phase_vocab.ail:361-363
def digestMessages (H : Str → Str) (msgs : List Message) : Str :=
  sha256Tag ++ H (canonicalMessages msgs)

/-! ## The chain (journal.ail:242-324), as written -/

section Chain
variable {α : Type} (H : Str → Str) (F : α → Str)

-- journal.ail:242-244
def chainDigestBase (seed : List Message) : Str := digestMessages H seed

-- journal.ail:322-324
def chainEmptyBase : Str := chainDigestBase H []

-- journal.ail:253-255: "sha256:${sha256Hex("${previous}${canonical_message_frame(m)}")}"
def chainDigestAfter (previous : Str) (m : α) : Str := sha256Tag ++ H (previous ++ F m)

-- journal.ail:260-262
def chainStep (previous : Str) (m : α) : Str := chainDigestAfter H F previous m

-- journal.ail:264-266: List.foldl(chain_digest_after, base, ms)
def chainDigestOver (base : Str) (ms : List α) : Str := ms.foldl (chainDigestAfter H F) base

structure PrefixAcc where
  last : Str
  out  : List Str

-- journal.ail:287-290
def chainPrefixStep (acc : PrefixAcc) (m : α) : PrefixAcc :=
  let d := chainDigestAfter H F acc.last m
  { last := d, out := acc.out ++ [d] }

-- journal.ail:292-294, AS WRITTEN: the fold starts from `chain_empty_base()`, and `base` is
-- never read. (Lean's unused-variable linter flags `base` here, as it should.)
def chainDigestsOver (base : Str) (ms : List α) : List Str :=
  (ms.foldl (chainPrefixStep H F) { last := chainEmptyBase H, out := [] }).out

-- journal.ail:299-301 composed with std/json `encode`: ja(List.map(js, ds)), compact.
-- MODEL ASSUMPTION: no escaping is needed, which holds for "sha256:" ++ lowercase hex.
def chainDigestsJsonText (ds : List Str) : Str :=
  lit "[" ++ List.intercalate (lit ",") (ds.map (fun d => lit "\"" ++ d ++ lit "\"")) ++ lit "]"

/-- The fix (Kiro's step 8): seed the fold with `base`. -/
def chainDigestsOverFixed (base : Str) (ms : List α) : List Str :=
  (ms.foldl (chainPrefixStep H F) { last := base, out := [] }).out

/-- The intent, stated directly: one digest per message, each the chain at that prefix. -/
def prefixChain (b : Str) : List α → List Str
  | [] => []
  | m :: ms => chainDigestAfter H F b m :: prefixChain (chainDigestAfter H F b m) ms

end Chain

/-! ## The properties, as registered -/

section Props
variable {α : Type} (H : Str → Str) (F : α → Str)

/-- P4.1 at one input. -/
def P4_1 (b : Str) (xs ys : List α) : Prop :=
  chainDigestsOver H F b (xs ++ ys)
    = chainDigestsOver H F b xs ++ chainDigestsOver H F (chainDigestOver H F b xs) ys

/-- P4.2, second half, at one input ("for a non-empty `ms` its last element is ..."). -/
def P4_2_last (b : Str) (ms : List α) : Prop :=
  ms ≠ [] → (chainDigestsOver H F b ms).getLast? = some (chainDigestOver H F b ms)

end Props

/-! ## Lemmas about the fold -/

section Lemmas
variable {α : Type} (H : Str → Str) (F : α → Str)

theorem foldl_prefixStep (ms : List α) :
    ∀ acc : PrefixAcc, ms.foldl (chainPrefixStep H F) acc
      = { last := chainDigestOver H F acc.last ms, out := acc.out ++ prefixChain H F acc.last ms } := by
  induction ms with
  | nil => intro acc; cases acc; simp [chainDigestOver, prefixChain]
  | cons m ms ih =>
    intro acc
    simp only [List.foldl_cons]
    rw [ih]
    simp [chainPrefixStep, chainDigestOver, prefixChain, List.append_assoc]

/-- What the code computes: the prefix chain from the EMPTY base, whatever `b` is. -/
theorem chainDigestsOver_eq (b : Str) (ms : List α) :
    chainDigestsOver H F b ms = prefixChain H F (chainEmptyBase H) ms := by
  simp [chainDigestsOver, foldl_prefixStep]

theorem chainDigestsOverFixed_eq (b : Str) (ms : List α) :
    chainDigestsOverFixed H F b ms = prefixChain H F b ms := by
  simp [chainDigestsOverFixed, foldl_prefixStep]

theorem chainDigestOver_cons (b : Str) (m : α) (ms : List α) :
    chainDigestOver H F b (m :: ms) = chainDigestOver H F (chainDigestAfter H F b m) ms := by
  simp [chainDigestOver]

theorem prefixChain_append (xs ys : List α) :
    ∀ b, prefixChain H F b (xs ++ ys) = prefixChain H F b xs ++ prefixChain H F (chainDigestOver H F b xs) ys := by
  induction xs with
  | nil => intro b; simp [prefixChain, chainDigestOver]
  | cons x xs ih => intro b; simp [prefixChain, ih, chainDigestOver_cons]

theorem prefixChain_length (ms : List α) : ∀ b, (prefixChain H F b ms).length = ms.length := by
  induction ms with
  | nil => intro b; rfl
  | cons m ms ih => intro b; simp [prefixChain, ih]

theorem prefixChain_getLast?_getD (ms : List α) :
    ∀ b, (prefixChain H F b ms).getLast?.getD b = chainDigestOver H F b ms := by
  induction ms with
  | nil => intro b; rfl
  | cons m ms ih =>
    intro b
    simp only [prefixChain, List.getLast?_cons, Option.getD_some]
    rw [ih, chainDigestOver_cons]

theorem prefixChain_getLast? (b : Str) (ms : List α) (h : ms ≠ []) :
    (prefixChain H F b ms).getLast? = some (chainDigestOver H F b ms) := by
  cases ms with
  | nil => exact absurd rfl h
  | cons m ms =>
    simp only [prefixChain, List.getLast?_cons]
    rw [prefixChain_getLast?_getD, chainDigestOver_cons]

/-- One step is injective in `previous`, for a fixed message, when `H` is. -/
theorem chainDigestAfter_inj_prev (hH : Inj H) (p p' : Str) (m : α)
    (h : chainDigestAfter H F p m = chainDigestAfter H F p' m) : p = p' := by
  unfold chainDigestAfter at h
  have h1 := hH _ _ (List.append_cancel_left h)
  exact (List.append_left_inj (F m)).mp h1

/-- The whole chain is injective in its base, for a fixed list, when `H` is. -/
theorem chainDigestOver_inj_base (hH : Inj H) (ms : List α) :
    ∀ p p', chainDigestOver H F p ms = chainDigestOver H F p' ms → p = p' := by
  induction ms with
  | nil => intro p p' h; simpa [chainDigestOver] using h
  | cons m ms ih =>
    intro p p' h
    rw [chainDigestOver_cons, chainDigestOver_cons] at h
    exact chainDigestAfter_inj_prev H F hH p p' m (ih _ _ h)

def Tagged (s : Str) : Prop := ∃ t, s = sha256Tag ++ t

theorem chainEmptyBase_eq : chainEmptyBase H = sha256Tag ++ H mEnd := by
  simp [chainEmptyBase, chainDigestBase, digestMessages, canonicalMessages]

theorem chainEmptyBase_tagged : Tagged (chainEmptyBase H) := ⟨H mEnd, chainEmptyBase_eq H⟩

theorem chainDigestOver_tagged (ms : List α) :
    ∀ p, Tagged p → Tagged (chainDigestOver H F p ms) := by
  induction ms with
  | nil => intro p hp; simpa [chainDigestOver] using hp
  | cons m ms ih =>
    intro p _
    rw [chainDigestOver_cons]
    exact ih _ ⟨_, rfl⟩

theorem tagged_append_ne_mEnd (p q : Str) (hp : Tagged p) : p ++ q ≠ mEnd := by
  obtain ⟨t, rfl⟩ := hp
  intro h
  have := congrArg List.head? h
  simp [sha256Tag, mEnd] at this

/-- No non-empty chain from a tagged base returns to the empty base. -/
theorem chainDigestOver_ne_emptyBase (hH : Inj H) (p : Str) (hp : Tagged p) (ms : List α)
    (hms : ms ≠ []) : chainDigestOver H F p ms ≠ chainEmptyBase H := by
  intro h
  obtain ⟨init, last, rfl⟩ := List.eq_nil_or_concat ms |>.resolve_left hms
  rw [chainDigestOver, List.concat_eq_append, List.foldl_append, List.foldl_cons, List.foldl_nil,
    chainEmptyBase_eq] at h
  unfold chainDigestAfter at h
  have h1 := hH _ _ (List.append_cancel_left h)
  exact tagged_append_ne_mEnd _ _ (chainDigestOver_tagged H F init p hp) h1

end Lemmas

/-! ## P4.2 -/

section P42
variable {α : Type} (H : Str → Str) (F : α → Str)

/-- P4.2, first half: PROVED, for every hash and frame. -/
theorem P4_2_length (b : Str) (ms : List α) :
    (chainDigestsOver H F b ms).length = ms.length := by
  rw [chainDigestsOver_eq, prefixChain_length]

/-- P4.2, second half, holds at the base every current caller passes. -/
theorem P4_2_last_at_empty_base (ms : List α) : P4_2_last H F (chainEmptyBase H) ms := by
  intro h
  rw [chainDigestsOver_eq]
  exact prefixChain_getLast? H F _ ms h

/-- P4.2, second half, FAILS at every other base, for every non-empty list. -/
theorem bug_P4_2_last (hH : Inj H) (b : Str) (hb : b ≠ chainEmptyBase H) (ms : List α)
    (hms : ms ≠ []) : (chainDigestsOver H F b ms).getLast? ≠ some (chainDigestOver H F b ms) := by
  rw [chainDigestsOver_eq, prefixChain_getLast? H F _ ms hms]
  intro h
  exact hb (chainDigestOver_inj_base H F hH ms _ _ (Option.some.inj h)).symm

/-- Exactly where P4.2's second half holds. -/
theorem P4_2_last_iff (hH : Inj H) (b : Str) (ms : List α) :
    P4_2_last H F b ms ↔ (ms = [] ∨ b = chainEmptyBase H) := by
  constructor
  · intro h
    by_cases hms : ms = []
    · exact Or.inl hms
    · by_cases hb : b = chainEmptyBase H
      · exact Or.inr hb
      · exact absurd (h hms) (bug_P4_2_last H F hH b hb ms hms)
  · rintro (h | h)
    · intro hne; exact absurd h hne
    · subst h; exact P4_2_last_at_empty_base H F ms

end P42

/-! ## P4.1 -/

section P41
variable {α : Type} (H : Str → Str) (F : α → Str)

/-- P4.1 FAILS for every base and every pair of non-empty lists, when `H` is injective. -/
theorem bug_P4_1 (hH : Inj H) (b : Str) (xs ys : List α) (hxs : xs ≠ []) (hys : ys ≠ []) :
    ¬ P4_1 H F b xs ys := by
  unfold P4_1
  rw [chainDigestsOver_eq, chainDigestsOver_eq, chainDigestsOver_eq, prefixChain_append]
  intro h
  have h1 := List.append_cancel_left h
  cases ys with
  | nil => exact hys rfl
  | cons y ys =>
    simp only [prefixChain, List.cons.injEq] at h1
    have h2 := chainDigestAfter_inj_prev H F hH _ _ y h1.1
    exact chainDigestOver_ne_emptyBase H F hH _ (chainEmptyBase_tagged H) xs hxs h2

/-- Exactly where P4.1 holds: only when one side of the split is empty. -/
theorem P4_1_iff (hH : Inj H) (b : Str) (xs ys : List α) :
    P4_1 H F b xs ys ↔ (xs = [] ∨ ys = []) := by
  constructor
  · intro h
    by_cases hxs : xs = []
    · exact Or.inl hxs
    · by_cases hys : ys = []
      · exact Or.inr hys
      · exact absurd h (bug_P4_1 H F hH b xs ys hxs hys)
  · rintro (h | h)
    · subst h; simp [P4_1, chainDigestsOver_eq, prefixChain]
    · subst h; simp [P4_1, chainDigestsOver_eq, prefixChain]

end P41

/-! ## The fix (step 8): both properties hold for every hash and frame, with no injectivity -/

section Fixed
variable {α : Type} (H : Str → Str) (F : α → Str)

theorem fixed_P4_1 (b : Str) (xs ys : List α) :
    chainDigestsOverFixed H F b (xs ++ ys)
      = chainDigestsOverFixed H F b xs ++ chainDigestsOverFixed H F (chainDigestOver H F b xs) ys := by
  simp only [chainDigestsOverFixed_eq, prefixChain_append]

theorem fixed_P4_2_length (b : Str) (ms : List α) :
    (chainDigestsOverFixed H F b ms).length = ms.length := by
  rw [chainDigestsOverFixed_eq, prefixChain_length]

theorem fixed_P4_2_last (b : Str) (ms : List α) (h : ms ≠ []) :
    (chainDigestsOverFixed H F b ms).getLast? = some (chainDigestOver H F b ms) := by
  rw [chainDigestsOverFixed_eq]; exact prefixChain_getLast? H F b ms h

/-- The fix changes nothing at the base every current caller passes. -/
theorem fixed_agrees_at_empty_base (b : Str) (ms : List α) :
    chainDigestsOverFixed H F (chainEmptyBase H) ms = chainDigestsOver H F b ms := by
  rw [chainDigestsOverFixed_eq, chainDigestsOver_eq]

end Fixed

/-! ## The concrete counterexamples, on the concrete model (`F := canonicalMessageFrame`)

These are the inputs repro/ runs on the real code. They hold for EVERY injective `H`, so they
do not depend on what SHA-256 happens to output. -/

def mSys : Message :=
  { role := lit "system", content := lit "you are motoko", tool_calls := [], tool_call_id := [], images := [] }
def mUser : Message :=
  { role := lit "user", content := lit "list the files", tool_calls := [], tool_call_id := [], images := [] }
def mAsst : Message :=
  { role := lit "assistant", content := lit "ok", tool_calls := [], tool_call_id := [], images := [] }

/-- The base a `history_replaced` re-bases to has this shape: `chain_digest_base(...)`. -/
def witnessBase (H : Str → Str) : Str := chainDigestBase H [mSys]

theorem witnessBase_ne_empty (H : Str → Str) (hH : Inj H) : witnessBase H ≠ chainEmptyBase H := by
  intro h
  have h1 := hH _ _ (List.append_cancel_left h)
  have h2 := congrArg List.length h1
  have h3 : (lit "m{").length = 2 := by decide
  simp [canonicalMessages, canonicalMessage, mEnd] at h2
  omega

/-- P4.2 (last element), real inputs: base `chain_digest_base([sys])`, list `[user]`. -/
theorem bug_P4_2_witness (H : Str → Str) (hH : Inj H) :
    (chainDigestsOver H canonicalMessageFrame (witnessBase H) [mUser]).getLast?
      ≠ some (chainDigestOver H canonicalMessageFrame (witnessBase H) [mUser]) :=
  bug_P4_2_last H _ hH _ (witnessBase_ne_empty H hH) [mUser] (by simp)

/-- P4.2 (last element), the empty-string base. -/
theorem bug_P4_2_witness_emptystr (H : Str → Str) (hH : Inj H) :
    (chainDigestsOver H canonicalMessageFrame [] [mUser]).getLast?
      ≠ some (chainDigestOver H canonicalMessageFrame [] [mUser]) :=
  bug_P4_2_last H _ hH [] (by rw [chainEmptyBase_eq]; simp [sha256Tag]) [mUser] (by simp)

/-- P4.1 at the base every caller uses, `chain_empty_base()`, xs = [sys], ys = [user]. -/
theorem bug_P4_1_witness (H : Str → Str) (hH : Inj H) :
    ¬ P4_1 H canonicalMessageFrame (chainEmptyBase H) [mSys] [mUser] :=
  bug_P4_1 H _ hH _ [mSys] [mUser] (by simp) (by simp)

/-- Non-vacuity: the hypothesis `Inj H` is satisfiable (by the identity), so each `bug_` theorem above has at least one instance; `fixed_*` shows the same statements are not
false of everything. -/
theorem bug_P4_1_witness_id : ¬ P4_1 (fun s => s) canonicalMessageFrame
    (chainEmptyBase (fun s => s)) [mSys] [mUser] :=
  bug_P4_1_witness _ inj_id

theorem bug_P4_2_witness_id :
    (chainDigestsOver (fun s => s) canonicalMessageFrame (witnessBase (fun s => s)) [mUser]).getLast?
      ≠ some (chainDigestOver (fun s => s) canonicalMessageFrame (witnessBase (fun s => s)) [mUser]) :=
  bug_P4_2_witness _ inj_id

/-! ## Observation (not a reported defect): what one step's digest determines

`chain_digest_after` hashes `previous ++ frame(m)` with no separator. When both previous
values have the same length — every digest is "sha256:" ++ 64 hex = 71 characters — one step
determines the previous value and the frame (`chainDigestAfter_inj_eqlen`). For bases of
different lengths it does not (`chainDigestAfter_shift`): a base can absorb a prefix of the
frame. Every caller passes a digest as the base, so this is recorded in SUMMARY.md as an
observation about the exported signature, not as a finding. -/

theorem chainDigestAfter_inj_eqlen {α : Type} (H : Str → Str) (F : α → Str) (hH : Inj H)
    (p p' : Str) (m m' : α) (hlen : p.length = p'.length)
    (h : chainDigestAfter H F p m = chainDigestAfter H F p' m') : p = p' ∧ F m = F m' := by
  unfold chainDigestAfter at h
  exact List.append_inj (hH _ _ (List.append_cancel_left h)) hlen

theorem chainDigestAfter_shift {α : Type} (H : Str → Str) (F : α → Str) (p X : Str) (m m' : α)
    (hF : F m = X ++ F m') : chainDigestAfter H F p m = chainDigestAfter H F (p ++ X) m' := by
  simp [chainDigestAfter, hF, List.append_assoc]

/-! ## Axiom report -/

#print axioms foldl_prefixStep
#print axioms chainDigestsOver_eq
#print axioms chainDigestsOverFixed_eq
#print axioms prefixChain_append
#print axioms prefixChain_length
#print axioms prefixChain_getLast?
#print axioms chainDigestAfter_inj_prev
#print axioms chainDigestOver_inj_base
#print axioms chainDigestOver_ne_emptyBase
#print axioms P4_2_length
#print axioms P4_2_last_at_empty_base
#print axioms bug_P4_2_last
#print axioms P4_2_last_iff
#print axioms bug_P4_1
#print axioms P4_1_iff
#print axioms fixed_P4_1
#print axioms fixed_P4_2_length
#print axioms fixed_P4_2_last
#print axioms fixed_agrees_at_empty_base
#print axioms witnessBase_ne_empty
#print axioms bug_P4_2_witness
#print axioms bug_P4_2_witness_emptystr
#print axioms bug_P4_1_witness
#print axioms bug_P4_1_witness_id
#print axioms bug_P4_2_witness_id
#print axioms chainDigestAfter_inj_eqlen
#print axioms chainDigestAfter_shift
#print axioms inj_id
#print axioms chainDigestOver_cons
#print axioms prefixChain_getLast?_getD
#print axioms chainEmptyBase_eq
#print axioms chainEmptyBase_tagged
#print axioms chainDigestOver_tagged
#print axioms tagged_append_ne_mEnd
/-
Sha256.lean.tail — appended to ChainModel.lean by run_diff.sh, for EXECUTION ONLY.
A plain SHA-256 (FIPS 180-4) over the UTF-8 bytes of a string, lowercase hex, so that the
model's `H` can be instantiated with the same function as std/crypto `sha256Hex`. No theorem
uses it. Checked against known vectors by the `#eval` at the end of this tail.
-/

namespace SHA256

def K : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

def H0 : Array UInt32 := #[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

@[inline] def rotr (x : UInt32) (n : UInt32) : UInt32 := (x >>> n) ||| (x <<< (32 - n))

def pad (msg : ByteArray) : ByteArray := Id.run do
  let bitLen : UInt64 := msg.size.toUInt64 * 8
  let mut b := msg.push 0x80
  while b.size % 64 != 56 do
    b := b.push 0
  for i in [0:8] do
    b := b.push ((bitLen >>> ((7 - i).toUInt64 * 8)).toUInt8)
  return b

def compress (h : Array UInt32) (b : ByteArray) (off : Nat) : Array UInt32 := Id.run do
  let mut w : Array UInt32 := Array.replicate 64 0
  for t in [0:16] do
    let i := off + 4 * t
    w := w.set! t ((b[i]!.toUInt32 <<< 24) ||| (b[i+1]!.toUInt32 <<< 16)
                   ||| (b[i+2]!.toUInt32 <<< 8) ||| b[i+3]!.toUInt32)
  for t in [16:64] do
    let x := w[t-15]!
    let y := w[t-2]!
    let s0 := rotr x 7 ^^^ rotr x 18 ^^^ (x >>> 3)
    let s1 := rotr y 17 ^^^ rotr y 19 ^^^ (y >>> 10)
    w := w.set! t (w[t-16]! + s0 + w[t-7]! + s1)
  let mut a := h[0]!
  let mut bb := h[1]!
  let mut c := h[2]!
  let mut d := h[3]!
  let mut e := h[4]!
  let mut f := h[5]!
  let mut g := h[6]!
  let mut hh := h[7]!
  for t in [0:64] do
    let S1 := rotr e 6 ^^^ rotr e 11 ^^^ rotr e 25
    let ch := (e &&& f) ^^^ ((~~~ e) &&& g)
    let t1 := hh + S1 + ch + K[t]! + w[t]!
    let S0 := rotr a 2 ^^^ rotr a 13 ^^^ rotr a 22
    let maj := (a &&& bb) ^^^ (a &&& c) ^^^ (bb &&& c)
    let t2 := S0 + maj
    hh := g
    g := f
    f := e
    e := d + t1
    d := c
    c := bb
    bb := a
    a := t1 + t2
  return #[h[0]! + a, h[1]! + bb, h[2]! + c, h[3]! + d, h[4]! + e, h[5]! + f, h[6]! + g, h[7]! + hh]

def hexDigit (n : UInt32) : Char :=
  if n < 10 then Char.ofNat (48 + n.toNat) else Char.ofNat (87 + n.toNat)

def wordHex (x : UInt32) : List Char :=
  (List.range 8).map (fun i => hexDigit ((x >>> ((7 - i).toUInt32 * 4)) &&& 0xf))

def sha256Bytes (msg : ByteArray) : List Char := Id.run do
  let b := pad msg
  let mut h := H0
  for i in [0:b.size / 64] do
    h := compress h b (64 * i)
  return h.toList.flatMap wordHex

end SHA256

/-- `sha256Hex` (std/crypto): SHA-256 of the string's UTF-8 bytes, lowercase hex. -/
def sha256Hex (s : Str) : Str := SHA256.sha256Bytes (String.ofList s).toUTF8

#eval do
  let v1 := String.ofList (sha256Hex (lit "abc"))
  let v2 := String.ofList (sha256Hex [])
  let v3 := String.ofList (sha256Hex (lit "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))
  if v1 == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
     && v2 == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
     && v3 == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
  then IO.println "#sha256-selftest ok"
  else IO.println s!"#sha256-selftest FAILED {v1} {v2} {v3}"
/-
GENERATED by gen_cases.py (seed 5, 400 cases). The Lean half of the differential test:
appended to ChainModel.lean and Sha256.lean.tail; prints the same lines as cases.ail.
-/

def tc (i n a : String) : ToolCall := ⟨lit i, lit n, lit a⟩
def im (s m : String) : ImagePart := ⟨lit s, lit m⟩
def msg (r c : String) (tcs : List ToolCall) (tcid : String) (ims : List ImagePart) : Message :=
  ⟨lit r, lit c, tcs, lit tcid, ims⟩

def baseOf (kind : String) (l : String) (ms : List Message) : Str :=
  if kind == "E" then chainEmptyBase sha256Hex
  else if kind == "B" then chainDigestBase sha256Hex ms
  else lit l

def runCase (i : Nat) (kind l : String) (ms : List Message) : IO Unit := do
  let b := baseOf kind l ms
  let ds := chainDigestsOver sha256Hex canonicalMessageFrame b ms
  IO.println s!"{i}|cdb|{String.ofList (chainDigestBase sha256Hex ms)}"
  IO.println s!"{i}|over|{String.ofList (chainDigestOver sha256Hex canonicalMessageFrame b ms)}"
  IO.println s!"{i}|digests|{ds.length}|{String.intercalate "," (ds.map String.ofList)}"
  IO.println s!"{i}|json|{String.ofList (chainDigestsJsonText ds)}"

#eval show IO Unit from do
  IO.println s!"E|{String.ofList (chainEmptyBase sha256Hex)}"
  runCase 0 "E" "" []
  runCase 1 "E" "" [msg "system" "you are motoko" [] "" []]
  runCase 2 "E" "" [msg "system" "you are motoko" [] "" [], msg "user" "list the files" [] "" []]
  runCase 3 "E" "" [msg "system" "you are motoko" [] "" [], msg "user" "list the files" [] "" [], msg "assistant" "ok" [] "" []]
  runCase 4 "L" "" [msg "user" "list the files" [] "" []]
  runCase 5 "L" "x" [msg "user" "list the files" [] "" [], msg "assistant" "ok" [] "" []]
  runCase 6 "B" "" [msg "system" "you are motoko" [] "" []]
  runCase 7 "B" "" [msg "system" "you are motoko" [] "" [], msg "user" "list the files" [] "" []]
  runCase 8 "B" "" []
  runCase 9 "L" "" []
  runCase 10 "B" "" [msg "assistant" "-\na日]-b};2😀" [] "é" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "é" " nbsp" [tc "a" "bash" "{\"a\":1}"] "😀" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "system" "make[1]" [] "call_1" []]
  runCase 11 "E" "" [msg "é" "\"quoted\"" [] "é" [], msg "system" "ok" [] "" []]
  runCase 12 "B" "" [msg "" "\"quoted\"" [] "" [], msg "assistant" "make[12]make[3]" [] "é" [im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "back\\slash" [] "é" [], msg "" "im-end;" [] "é" []]
  runCase 13 "E" "" [msg "user" "[\"a\"]" [tc "call_1" "" "make[3]"] "call_1" [im "" "image/jpeg"], msg "é" "make[1make[2]]" [] "é" []]
  runCase 14 "E" "" [msg "" "m\":01" [] "a" []]
  runCase 15 "E" "" [msg "é" "back\\slash" [] "" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "" "line\nbreak" [tc "a" "bash" "{}"] "é" [], msg "user" "-é" [] "a" [im "file:///tmp/a.png" "image/png"]]
  runCase 16 "E" "" [msg "tool" "tc-end;" [] "😀" [im "é" "image/jpeg"], msg "é" "x:3:y;" [tc "a" "bash" "é"] "😀" [], msg "é" ":😀" [] "😀" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/jpeg"], msg "" "\"m😀m0" [] "a" [im "" "", im "file:///tmp/a.png" ""]]
  runCase 17 "B" "" [msg "assistant" "{}" [] "call_1" [], msg "é" "2}日21\n" [] "😀" []]
  runCase 18 "E" "" [msg "assistant" "\"quoted\"" [] "é" [], msg "" "tab\there" [tc "call_1" "" "{}"] "a" [], msg "" "make[21]" [tc "a" "bash" "é", tc "a" "read_file" "{}"] "a" [], msg "assistant" "}m{" [] "é" [im "file:///tmp/a.png" ""]]
  runCase 19 "E" "" [msg "user" "" [] "é" [], msg "tool" "}m{" [] "" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 20 "B" "" [msg "assistant" "é\\-\"2日" [] "a" [im "é" "image/jpeg", im "é" "image/png"], msg "user" "𝔘𝔫𝔦" [tc "" "日本" "{}", tc "call_1" "read_file" ""] "😀" [im "é" ""]]
  runCase 21 "E" "" [msg "assistant" "}  m0😀" [] "é" [], msg "assistant" " nbsp" [] "a" [im "" "image/png"]]
  runCase 22 "L" "x" [msg "system" "" [tc "😀" "" "{\"a\":1}"] "é" []]
  runCase 23 "E" "" [msg "assistant" "0😀 😀" [tc "😀" "bash" "{}"] "a" [], msg "assistant" "make[1make[2]]" [tc "😀" "bash" "é", tc "call_1" "" "make[3]"] "a" []]
  runCase 24 "E" "" [msg "" "\"[aéé \\--😀" [tc "é" "日本" "{\"a\":1}"] "call_1" [im "" ""]]
  runCase 25 "E" "" [msg "tool" "x:3:y;" [] "a" [], msg "tool" "\"{é\\\"" [] "" [], msg "assistant" "a1é:3😀b;;]" [tc "" "read_file" ""] "é" []]
  runCase 26 "E" "" [msg "user" "tc-end;" [] "" [im "" "image/jpeg", im "é" "image/jpeg"], msg "system" "you are motoko" [tc "é" "read_file" "{}", tc "é" "bash" ""] "😀" [im "é" ""]]
  runCase 27 "B" "" []
  runCase 28 "E" "" [msg "assistant" "m{role:4:user;}" [] "😀" [im "data:image/png;base64,AAAA" "", im "" "image/jpeg"], msg "user" "{]2日3}{a" [tc "call_1" "bash" "make[3]", tc "" "bash" "{}"] "😀" [im "é" "image/png", im "é" ""], msg "tool" "m{role:4:user;}" [] "😀" [im "" "image/png"]]
  runCase 29 "L" "m-end;" [msg "user" " nbsp" [tc "é" "read_file" "{\"a\":1}", tc "😀" "日本" ""] "a" [], msg "assistant" "33{2-0-é2\nb\\" [tc "a" "read_file" "é"] "" [], msg "system" "éx" [] "" [im "é" "image/jpeg"], msg "assistant" "\r\n" [] "😀" [im "file:///tmp/a.png" ""]]
  runCase 30 "L" "" [msg "user" "ü:2:ü;" [tc "é" "read_file" "make[3]"] "call_1" []]
  runCase 31 "B" "" [msg "user" "hi" [tc "" "" ""] "call_1" [], msg "é" "\r\n" [tc "a" "bash" ""] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "á" [tc "a" "bash" "make[3]"] "é" [], msg "é" "make[1make[2]]" [] "é" []]
  runCase 32 "E" "" [msg "é" "tc-end;" [tc "call_1" "bash" "é"] "" [im "é" "image/png"]]
  runCase 33 "E" "" []
  runCase 34 "B" "" []
  runCase 35 "E" "" [msg "tool" "\r\n" [] "a" []]
  runCase 36 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "system" "\r\n" [tc "call_1" "bash" "{}"] "a" [], msg "é" "}m{" [] "" [], msg "system" "éx" [tc "" "read_file" "make[3]"] "" [im "file:///tmp/a.png" ""], msg "tool" "line\nbreak" [] "" []]
  runCase 37 "L" "sha256:e3b0" [msg "" "list the files" [] "é" []]
  runCase 38 "E" "" [msg "" "éx" [tc "" "日本" "make[3]", tc "a" "" "{}"] "é" []]
  runCase 39 "E" "" [msg "user" ":" [tc "call_1" "日本" "make[3]"] "" [], msg "é" "" [tc "a" "bash" "{}"] "é" [], msg "system" "ok" [] "" []]

#eval show IO Unit from do
  runCase 40 "E" "" [msg "assistant" "hi" [] "😀" [im "" "image/png", im "" "image/png"]]
  runCase 41 "E" "" [msg "assistant" "tc-end;" [] "a" [im "é" "image/png", im "file:///tmp/a.png" "image/png"], msg "assistant" "tc-end;" [] "" [], msg "" "ok" [tc "é" "日本" "{}"] "call_1" [], msg "tool" "😀" [] "é" []]
  runCase 42 "E" "" [msg "tool" "you are motoko" [] "é" [], msg "user" "im-end;" [] "é" []]
  runCase 43 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "}m{" [tc "call_1" "read_file" ""] "call_1" []]
  runCase 44 "E" "" [msg "tool" "[\"a\"]" [] "é" [im "" "image/png"], msg "user" "[1😀😀" [tc "😀" "bash" "{\"a\":1}"] "é" []]
  runCase 45 "E" "" [msg "" "日本語" [] "call_1" [], msg "" "x:3:y;" [tc "é" "日本" "make[3]"] "😀" []]
  runCase 46 "E" "" [msg "tool" "tab\there" [tc "a" "" ""] "" [], msg "system" "ü:2:ü;" [tc "é" "" "{}", tc "call_1" "read_file" "{}"] "" [], msg "é" "é" [tc "😀" "read_file" "é", tc "😀" "bash" "{}"] "a" [], msg "" "33}-\n[ 131" [] "😀" []]
  runCase 47 "E" "" []
  runCase 48 "E" "" [msg "assistant" "}" [] "é" []]
  runCase 49 "E" "" [msg "system" "line\nbreak" [tc "é" "日本" "{\"a\":1}"] "é" [im "data:image/png;base64,AAAA" ""], msg "tool" "make[12]make[3]" [] "é" [], msg "user" "tc-end;" [tc "a" "日本" "{\"a\":1}"] "call_1" [im "" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 50 "E" "" []
  runCase 51 "L" "x" [msg "" "ü:2:ü;" [tc "é" "read_file" "make[3]"] "é" [], msg "system" "list the files" [] "a" [], msg "" "á" [tc "call_1" "read_file" "make[3]", tc "😀" "bash" ""] "" [], msg "user" "á" [tc "" "read_file" "é", tc "😀" "日本" "é"] "" []]
  runCase 52 "B" "" [msg "é" "\r\n" [] "" [im "file:///tmp/a.png" "image/png"]]
  runCase 53 "E" "" [msg "tool" "13{" [] "é" [], msg "" "ü:2:ü;" [] "😀" [im "" "image/png"], msg "tool" "back\\slash" [] "a" [], msg "system" "make[1]" [tc "é" "read_file" "{}"] "é" []]
  runCase 54 "E" "" [msg "system" "éx" [] "" [], msg "assistant" ":b[[日a😀\n" [] "call_1" [im "é" "image/jpeg", im "" "image/png"], msg "user" "\\- -\\b" [] "" [im "é" ""], msg "tool" "éx" [] "a" []]
  runCase 55 "E" "" [msg "system" "😀" [] "call_1" [], msg "tool" "line\nbreak" [] "a" [im "" "image/png"]]
  runCase 56 "L" "" [msg "user" "[\"a\"]" [tc "call_1" "日本" "{\"a\":1}"] "é" [], msg "system" "" [] "a" [im "" ""]]
  runCase 57 "E" "" [msg "é" "0\n" [tc "😀" "bash" "", tc "" "bash" "é"] "call_1" [], msg "assistant" "á" [] "😀" [], msg "assistant" "á" [tc "é" "read_file" "{\"a\":1}", tc "é" "bash" "{}"] "" [], msg "tool" "0b\n" [] "" [im "file:///tmp/a.png" "image/png"]]
  runCase 58 "B" "" [msg "tool" "𝔘𝔫𝔦" [] "😀" [im "file:///tmp/a.png" "image/jpeg", im "é" ""], msg "assistant" "tab\there" [] "é" []]
  runCase 59 "E" "" [msg "" "\"2é{" [tc "call_1" "bash" "é"] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/png"], msg "system" "𝔘𝔫𝔦" [] "call_1" []]
  runCase 60 "B" "" [msg "assistant" "you are motoko" [] "call_1" [], msg "é" "{}" [] "call_1" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" "you are motoko" [] "é" [], msg "é" "ü:2:ü;" [tc "" "bash" "make[3]", tc "é" "bash" "é"] "😀" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 61 "E" "" [msg "system" "hi" [] "é" [], msg "é" "[\"a\"]" [] "call_1" [], msg "tool" "make[1make[2]]" [] "" []]
  runCase 62 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" " [日:{" [] "" [im "é" "image/jpeg"], msg "" "ok" [tc "a" "日本" "make[3]"] "call_1" []]
  runCase 63 "E" "" [msg "assistant" "𝔘𝔫𝔦" [] "😀" [], msg "é" "make[0]" [] "call_1" [im "" "image/png", im "file:///tmp/a.png" ""]]
  runCase 64 "B" "" [msg "" "line\nbreak" [] "" [], msg "assistant" "日本" [tc "a" "bash" "make[3]"] "é" [], msg "é" "é" [] "" [], msg "system" "ü:2:ü;" [tc "" "bash" ""] "" []]
  runCase 65 "E" "" []
  runCase 66 "L" "" [msg "tool" "\r\n" [] "😀" [im "file:///tmp/a.png" "image/jpeg", im "" "image/jpeg"], msg "" "list the files" [tc "é" "bash" "{\"a\":1}"] "a" []]
  runCase 67 "E" "" []
  runCase 68 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 69 "B" "" [msg "" "" [] "😀" []]
  runCase 70 "L" "m-end;" [msg "user" "{}" [tc "😀" "bash" "{\"a\":1}", tc "call_1" "bash" "é"] "call_1" [im "file:///tmp/a.png" ""], msg "user" "x:3:y;" [tc "😀" "bash" "{\"a\":1}"] "😀" [], msg "tool" "日" [] "a" []]
  runCase 71 "E" "" [msg "system" "á" [tc "a" "日本" "{}", tc "call_1" "" ""] "" [im "" "image/png", im "" ""], msg "" "x:3:y;" [tc "😀" "" "make[3]"] "call_1" [], msg "assistant" "😀" [] "a" []]
  runCase 72 "E" "" [msg "é" "\r\n" [] "call_1" [im "file:///tmp/a.png" ""], msg "" "back\\slash" [tc "😀" "" "make[3]"] "" [], msg "" "{}" [tc "é" "" "{}"] "a" [im "" "", im "" "image/jpeg"], msg "user" "m{role:4:user;}" [] "é" []]
  runCase 73 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "]\\:" [tc "😀" "" "é", tc "😀" "" "{\"a\":1}"] "" [], msg "" "bm\na{éb" [tc "" "read_file" "{\"a\":1}"] "" [], msg "tool" "😀0\n:a  " [tc "😀" "read_file" "{}"] "é" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/png"]]
  runCase 74 "E" "" [msg "assistant" "日本語" [] "" [im "" ""], msg "user" "make[1]" [] "é" []]
  runCase 75 "E" "" [msg "tool" "" [] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 76 "E" "" [msg "tool" "日[[1\\mb[" [tc "a" "" "{}"] "😀" [im "file:///tmp/a.png" "image/png"], msg "é" "ok" [tc "é" "bash" "{}", tc "😀" "日本" ""] "" [im "data:image/png;base64,AAAA" ""]]
  runCase 77 "E" "" []
  runCase 78 "B" "" [msg "tool" "𝔘𝔫𝔦" [] "😀" [im "é" "image/png", im "é" ""], msg "" "😀0;" [tc "" "日本" "{\"a\":1}"] "" [im "file:///tmp/a.png" "image/png", im "" "image/jpeg"], msg "assistant" "ü:2:ü;" [] "call_1" [], msg "" "-:b😀\n😀[日0{" [tc "call_1" "日本" "make[3]"] "" [im "data:image/png;base64,AAAA" "", im "" "image/jpeg"]]
  runCase 79 "B" "" []

#eval show IO Unit from do
  runCase 80 "L" "sha256:" [msg "system" "😀" [] "call_1" [], msg "assistant" "you are motoko" [tc "call_1" "bash" "é"] "" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""]]
  runCase 81 "L" "sha256:e3b0" [msg "" "ü:2:ü;" [tc "😀" "日本" "é"] "a" [im "é" "", im "" "image/png"], msg "system" "2é \\" [] "a" []]
  runCase 82 "L" "x" [msg "assistant" "á" [tc "" "bash" "{}"] "call_1" [], msg "assistant" "😀" [tc "call_1" "read_file" ""] "😀" [im "é" "", im "é" "image/png"], msg "user" ":;日m21-;3" [tc "é" "" "{\"a\":1}"] "a" [im "é" "", im "file:///tmp/a.png" "image/png"]]
  runCase 83 "E" "" [msg "system" "make[0]" [] "😀" [], msg "tool" "you are motoko" [] "é" []]
  runCase 84 "E" "" [msg "user" "x:3:y;" [tc "😀" "bash" "{}"] "😀" [], msg "system" "make[1]" [] "" [], msg "tool" "\r\n" [tc "a" "bash" "{\"a\":1}"] "call_1" [], msg "user" "\"quoted\"" [] "a" []]
  runCase 85 "B" "" []
  runCase 86 "E" "" []
  runCase 87 "E" "" [msg "é" "1mé}m" [] "" [im "data:image/png;base64,AAAA" "image/png"], msg "é" "0😀]b\"[3\\;0😀b" [tc "call_1" "bash" "é", tc "a" "bash" "{}"] "a" [], msg "assistant" "" [tc "" "" "make[3]", tc "é" "" ""] "call_1" [], msg "" "" [tc "😀" "read_file" "{\"a\":1}"] "" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 88 "E" "" [msg "é" "[\"a\"]" [tc "a" "read_file" "{\"a\":1}", tc "" "日本" "{\"a\":1}"] "é" [], msg "é" "im-end;" [tc "😀" "bash" ""] "😀" [im "" ""]]
  runCase 89 "E" "" [msg "user" "make[1make[2]]" [tc "call_1" "日本" "make[3]"] "😀" [], msg "user" "line\nbreak" [] "" [im "" "", im "data:image/png;base64,AAAA" ""]]
  runCase 90 "E" "" [msg "assistant" "[\"a\"]" [] "" []]
  runCase 91 "B" "" [msg "system" "make[21]" [] "é" [im "file:///tmp/a.png" "image/png"], msg "tool" "😀\"b3  " [] "a" [im "file:///tmp/a.png" "", im "data:image/png;base64,AAAA" ""], msg "tool" "tab\there" [] "é" []]
  runCase 92 "E" "" [msg "user" "ü:2:ü;" [tc "a" "日本" "é", tc "é" "日本" "make[3]"] "a" []]
  runCase 93 "B" "" [msg "é" "you are motoko" [tc "é" "bash" "{\"a\":1}"] "" [im "data:image/png;base64,AAAA" "image/png"], msg "system" "😀" [tc "a" "bash" "{}"] "call_1" [im "file:///tmp/a.png" "image/jpeg"], msg "user" "x:3:y;" [tc "😀" "" "{}", tc "😀" "" "{}"] "é" []]
  runCase 94 "E" "" [msg "" "make[1make[2]]" [] "a" [im "" "image/jpeg"]]
  runCase 95 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "😀" [] "call_1" []]
  runCase 96 "E" "" [msg "assistant" " nbsp" [] "a" []]
  runCase 97 "E" "" [msg "" "m{role:4:user;}" [tc "call_1" "bash" "{\"a\":1}", tc "" "bash" "é"] "call_1" [], msg "" "make[12]make[3]" [] "" [im "é" ""], msg "system" "3:;a10\"日" [] "a" []]
  runCase 98 "B" "" [msg "system" "" [tc "é" "" "é"] "" []]
  runCase 99 "E" "" [msg "tool" "line\nbreak" [tc "😀" "日本" "make[3]"] "a" [im "file:///tmp/a.png" "image/png"]]
  runCase 100 "E" "" [msg "system" "x‍😀" [tc "é" "bash" "é"] "call_1" [im "data:image/png;base64,AAAA" "", im "é" ""], msg "user" "make[0]" [] "call_1" [], msg "" "make[1make[2]]" [tc "é" "bash" "é", tc "" "read_file" "{}"] "a" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 101 "B" "" [msg "é" "x‍😀" [tc "a" "read_file" "é"] "é" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" ""]]
  runCase 102 "L" "" [msg "assistant" "\r\n" [] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/jpeg"], msg "é" "m{role:4:user;}" [] "call_1" []]
  runCase 103 "B" "" [msg "user" "😀" [] "😀" [], msg "tool" "}a1b;[é\n " [tc "" "日本" "{\"a\":1}"] "call_1" [], msg "tool" "make[12]make[3]" [] "call_1" [], msg "tool" "😀1}]" [] "é" []]
  runCase 104 "E" "" []
  runCase 105 "L" "sha256:" [msg "system" "m{role:4:user;}" [tc "é" "read_file" "é", tc "a" "日本" "é"] "call_1" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 106 "L" "sha256:e3b0" [msg "" "x‍😀" [] "call_1" []]
  runCase 107 "E" "" [msg "é" ";\n]}\\-10[ " [tc "a" "read_file" "make[3]"] "é" [], msg "" "\"quoted\"" [] "call_1" [], msg "system" "x:3:y;" [tc "😀" "read_file" ""] "" [], msg "system" "line\nbreak" [tc "" "" "{\"a\":1}"] "é" [im "" ""]]
  runCase 108 "B" "" [msg "é" "m{role:4:user;}" [tc "😀" "read_file" "make[3]", tc "😀" "bash" "é"] "a" []]
  runCase 109 "B" "" [msg "user" "make[21]" [] "é" []]
  runCase 110 "E" "" [msg "system" "\"quoted\"" [] "call_1" [], msg "system" " ]\\é\n\\😀0;" [] "a" [im "é" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 111 "L" "" [msg "user" "make[0]" [] "" [im "" ""], msg "user" "á" [tc "é" "日本" "é", tc "a" "" ""] "é" [im "" "image/jpeg"], msg "system" "a[\"日{11-é:1" [] "é" []]
  runCase 112 "E" "" []
  runCase 113 "E" "" []
  runCase 114 "E" "" []
  runCase 115 "E" "" [msg "tool" "make[21]" [tc "call_1" "read_file" "{\"a\":1}"] "" [], msg "assistant" "\r\n" [tc "é" "read_file" "make[3]"] "call_1" []]
  runCase 116 "E" "" []
  runCase 117 "E" "" [msg "é" "2m😀😀😀:日\":1" [] "😀" [im "" "image/jpeg", im "" "image/jpeg"], msg "system" ";" [tc "" "read_file" "make[3]"] "é" []]
  runCase 118 "E" "" [msg "assistant" "[😀1m]2\\日\\[]" [] "a" [], msg "system" "x:3:y;" [] "call_1" [im "é" "image/png", im "" "image/png"]]
  runCase 119 "E" "" [msg "é" "3m" [] "call_1" [im "" "image/jpeg", im "file:///tmp/a.png" ""], msg "user" "2}é}😀]1b}\n" [tc "call_1" "" "{\"a\":1}"] "" [im "" "image/png"]]

#eval show IO Unit from do
  runCase 120 "E" "" [msg "é" "ü:2:ü;" [tc "a" "日本" "{\"a\":1}"] "é" []]
  runCase 121 "E" "" [msg "é" "éabm1é]2;\\a" [tc "é" "" "make[3]", tc "😀" "bash" ""] "é" [im "é" "image/jpeg"]]
  runCase 122 "E" "" [msg "é" "x:3:y;" [] "é" [], msg "system" "😀" [] "😀" []]
  runCase 123 "E" "" []
  runCase 124 "B" "" [msg "user" "[" [] "a" [], msg "" "x‍😀" [tc "😀" "" "make[3]", tc "call_1" "日本" "{}"] "é" [], msg "tool" "make[21]" [tc "" "read_file" "{\"a\":1}", tc "😀" "" "{\"a\":1}"] "😀" [], msg "assistant" "😀" [tc "😀" "read_file" ""] "call_1" []]
  runCase 125 "B" "" [msg "é" "tab\there" [tc "😀" "日本" "{}", tc "😀" "" "{\"a\":1}"] "" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 126 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "system" "make[21]" [tc "é" "bash" "", tc "a" "日本" "{}"] "é" [], msg "" "}m{" [tc "call_1" "read_file" "{\"a\":1}", tc "a" "read_file" "{\"a\":1}"] "call_1" [im "é" "image/jpeg"], msg "tool" "\nb{}2\\" [] "" [], msg "user" "  a{-日m{:" [tc "é" "" "{\"a\":1}", tc "" "read_file" "é"] "a" []]
  runCase 127 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 128 "E" "" [msg "assistant" ":;" [] "call_1" [im "é" "image/png"], msg "user" "😀é😀:3日01]😀" [] "a" [], msg "é" " nbsp" [tc "😀" "bash" "é"] "😀" [im "data:image/png;base64,AAAA" ""]]
  runCase 129 "E" "" [msg "" "𝔘𝔫𝔦" [tc "a" "" "é"] "é" [], msg "user" "ü:2:ü;" [] "a" [im "" ""]]
  runCase 130 "L" "é😀" [msg "assistant" "back\\slash" [tc "call_1" "" "", tc "😀" "" "{\"a\":1}"] "" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" "a1" [] "a" [], msg "assistant" "𝔘𝔫𝔦" [tc "a" "read_file" "make[3]"] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "{}" [] "😀" [im "file:///tmp/a.png" "", im "" "image/jpeg"]]
  runCase 131 "E" "" [msg "" "[a😀1{\n" [] "é" []]
  runCase 132 "E" "" [msg "assistant" "" [] "😀" []]
  runCase 133 "E" "" []
  runCase 134 "E" "" [msg "" "line\nbreak" [] "😀" [im "file:///tmp/a.png" "", im "é" "image/png"]]
  runCase 135 "B" "" [msg "system" "{}" [tc "call_1" "bash" "{\"a\":1}"] "a" [im "" "image/png", im "file:///tmp/a.png" "image/png"], msg "é" "ü:2:ü;" [tc "call_1" "bash" "é"] "a" [], msg "assistant" "]\\[日}" [] "😀" [im "é" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 136 "E" "" [msg "" "back\\slash" [tc "call_1" "read_file" ""] "😀" [im "data:image/png;base64,AAAA" "image/png"], msg "é" "make[1make[2]]" [tc "é" "bash" ""] "😀" [], msg "tool" "hi" [] "" [], msg "user" "}][" [] "a" [im "é" "image/png"]]
  runCase 137 "B" "" [msg "system" " 3}é]" [tc "😀" "bash" "é", tc "call_1" "read_file" "é"] "" []]
  runCase 138 "E" "" [msg "é" "𝔘𝔫𝔦" [] "é" [], msg "tool" "{}日- 1a" [tc "call_1" "" "", tc "😀" "日本" "make[3]"] "" []]
  runCase 139 "B" "" [msg "assistant" "}m{" [] "é" []]
  runCase 140 "E" "" []
  runCase 141 "E" "" [msg "user" "make[12]make[3]" [] "" [], msg "system" "𝔘𝔫𝔦" [] "é" []]
  runCase 142 "E" "" []
  runCase 143 "L" "é😀" [msg "assistant" "x‍😀" [tc "" "bash" "", tc "call_1" "read_file" "é"] "call_1" [im "file:///tmp/a.png" "", im "" "image/jpeg"], msg "user" "é[" [tc "a" "日本" ""] "call_1" [im "é" "image/jpeg"]]
  runCase 144 "L" "sha256:" [msg "assistant" " [m[3[😀-" [] "call_1" [], msg "" "á" [tc "😀" "日本" "make[3]"] "call_1" [im "é" "image/jpeg", im "file:///tmp/a.png" ""], msg "é" "😀2ab{m日-3;" [tc "call_1" "read_file" "{}"] "a" []]
  runCase 145 "L" "sha256:e3b0" [msg "user" "3[]2 -b" [tc "😀" "bash" "make[3]"] "😀" [im "é" "", im "file:///tmp/a.png" "image/png"], msg "" "line\nbreak" [tc "" "" ""] "a" [], msg "" "make[20] and make[2]" [tc "é" "bash" "make[3]"] "😀" [im "data:image/png;base64,AAAA" ""]]
  runCase 146 "E" "" []
  runCase 147 "E" "" []
  runCase 148 "E" "" [msg "system" "im-end;" [] "a" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "tool" "😀" [] "é" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 149 "E" "" [msg "é" "[\"a\"]" [] "é" [im "" "image/png"], msg "tool" "make[0]" [tc "call_1" "" "make[3]"] "😀" [im "" "image/png"], msg "system" ";{\\; " [] "😀" [], msg "tool" "" [tc "call_1" "bash" "", tc "😀" "" "{}"] "call_1" []]
  runCase 150 "L" "sha256:" [msg "é" "ok" [tc "call_1" "" "make[3]"] "é" [], msg "é" "😀;2}m\\mm3" [] "😀" [im "data:image/png;base64,AAAA" ""]]
  runCase 151 "E" "" [msg "é" "3:01:-" [] "" [], msg "assistant" "é:{[02\\]" [] "😀" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 152 "B" "" [msg "system" "á" [] "" []]
  runCase 153 "E" "" []
  runCase 154 "E" "" [msg "user" "[\"a\"]" [] "" [], msg "tool" "😀\"{\\ b\"}{:-" [] "call_1" [], msg "é" "make[1]" [tc "é" "" "{\"a\":1}"] "😀" [im "é" "image/jpeg"], msg "" "make[20] and make[2]" [] "😀" []]
  runCase 155 "E" "" [msg "é" "list the files" [] "call_1" [], msg "" "日本語" [] "call_1" [], msg "user" "á" [tc "😀" "" "make[3]"] "😀" [], msg "system" "ü:2:ü;" [tc "😀" "bash" "make[3]", tc "call_1" "read_file" "make[3]"] "a" []]
  runCase 156 "B" "" [msg "tool" "𝔘𝔫𝔦" [tc "call_1" "" "make[3]"] "😀" []]
  runCase 157 "L" "m-end;" [msg "tool" "[\"a\"]" [] "😀" []]
  runCase 158 "E" "" [msg "system" "{}" [tc "call_1" "read_file" ""] "a" [], msg "assistant" "hi" [] "😀" [], msg "tool" "é日日é" [tc "a" "日本" "{\"a\":1}"] "a" [], msg "user" "}m{" [tc "é" "" "{}"] "call_1" []]
  runCase 159 "L" "m-end;" [msg "system" "you are motoko" [] "" []]

#eval show IO Unit from do
  runCase 160 "B" "" [msg "system" "mab[" [tc "" "" "{}"] "" [], msg "" "hi" [tc "call_1" "" "make[3]", tc "a" "日本" ""] "" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "x‍😀" [] "é" []]
  runCase 161 "L" "é😀" [msg "" "31}\"1]" [] "é" [], msg "tool" "" [tc "" "日本" "make[3]"] "" [im "file:///tmp/a.png" "image/png", im "é" ""], msg "é" ":" [] "call_1" []]
  runCase 162 "E" "" []
  runCase 163 "L" "sha256:e3b0" [msg "system" "sha256:" [tc "a" "read_file" "{\"a\":1}"] "" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/png"], msg "" "日本" [tc "call_1" "read_file" "make[3]"] "a" [], msg "system" "line\nbreak" [] "😀" []]
  runCase 164 "B" "" [msg "assistant" "{}" [] "é" []]
  runCase 165 "E" "" [msg "system" "}m{" [tc "" "日本" "{}"] "a" [], msg "assistant" "😀a" [tc "" "bash" "make[3]", tc "call_1" "bash" ""] "é" [im "é" "image/png", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 166 "E" "" [msg "system" "日本語" [tc "a" "bash" "é", tc "a" "" "make[3]"] "é" [], msg "" "á" [tc "call_1" "read_file" "make[3]"] "a" [], msg "system" "sha256:" [] "" [im "data:image/png;base64,AAAA" "image/png", im "" ""], msg "é" "\"quoted\"" [] "a" []]
  runCase 167 "B" "" [msg "" "á" [tc "é" "日本" "{}", tc "😀" "bash" ""] "a" [], msg "" "é" [] "" [im "é" "image/jpeg", im "" "image/png"], msg "assistant" "á" [] "" [im "é" "", im "é" ""]]
  runCase 168 "B" "" [msg "" "x‍😀" [] "" [], msg "" "é" [] "" [im "é" "image/jpeg"]]
  runCase 169 "B" "" []
  runCase 170 "B" "" [msg "" "make[12]make[3]" [tc "call_1" "" "é"] "é" [im "" "image/png", im "file:///tmp/a.png" ""], msg "assistant" "tab\there" [tc "call_1" "bash" "make[3]", tc "" "" "é"] "a" [], msg "" "éx" [] "😀" []]
  runCase 171 "B" "" [msg "assistant" "😀" [] "a" []]
  runCase 172 "E" "" [msg "assistant" "make[1make[2]]" [] "😀" [im "" "image/png", im "" "image/jpeg"], msg "system" "ü:2:ü;" [] "é" [], msg "é" "] \n日\\b:😀[é" [] "" [], msg "tool" "hi" [tc "call_1" "" "make[3]"] "" []]
  runCase 173 "E" "" [msg "" "tc-end;" [] "😀" [im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "\n" [tc "😀" "read_file" "{\"a\":1}"] "é" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/jpeg"], msg "system" "{}" [tc "call_1" "bash" "make[3]", tc "" "read_file" "make[3]"] "" [], msg "é" "日本" [tc "😀" "bash" "é", tc "a" "read_file" "make[3]"] "a" []]
  runCase 174 "E" "" [msg "user" "á" [] "call_1" [im "é" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 175 "B" "" [msg "tool" ";-\\\\\\-" [tc "😀" "bash" "é"] "a" []]
  runCase 176 "E" "" [msg "system" "tab\there" [tc "é" "" "{\"a\":1}", tc "call_1" "日本" ""] "call_1" [], msg "é" "😀" [tc "" "read_file" ""] "call_1" []]
  runCase 177 "E" "" [msg "user" "日本語" [tc "" "" "make[3]"] "call_1" [], msg "" "] \n13" [tc "call_1" "bash" "{\"a\":1}", tc "😀" "" "make[3]"] "a" []]
  runCase 178 "E" "" [msg "é" "[\"a\"]" [tc "é" "bash" "é", tc "é" "read_file" "make[3]"] "é" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "assistant" "tc-end;" [tc "😀" "read_file" "é"] "call_1" []]
  runCase 179 "E" "" [msg "user" "}m{" [] "é" [im "é" "image/jpeg", im "" ""], msg "" "{}" [] "call_1" [im "" "image/png"]]
  runCase 180 "B" "" [msg "é" "éx" [] "a" [im "" "image/jpeg", im "" "image/jpeg"]]
  runCase 181 "E" "" [msg "" "" [] "😀" [im "" ""]]
  runCase 182 "L" "" []
  runCase 183 "E" "" [msg "tool" "tab\there" [] "é" [im "é" "image/png"]]
  runCase 184 "E" "" [msg "é" "" [] "a" [], msg "user" ";[\\" [] "é" []]
  runCase 185 "E" "" [msg "system" "0a;ab}" [tc "call_1" "bash" "", tc "é" "read_file" "make[3]"] "call_1" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 186 "L" "x" [msg "é" "}]\\{[{{;3 😀" [] "😀" [], msg "é" "𝔘𝔫𝔦" [tc "" "bash" ""] "" [], msg "assistant" "]:\"m-1]" [tc "a" "read_file" "{\"a\":1}"] "" [], msg "tool" " nbsp" [] "" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 187 "E" "" [msg "user" "\"\n😀 {\"\"\n}}\"" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "" "😀 " [] "" [], msg "é" "tc-end;" [tc "😀" "bash" "{\"a\":1}", tc "a" "read_file" ""] "é" [im "é" "image/jpeg", im "" "image/png"]]
  runCase 188 "L" "x" [msg "assistant" "á" [] "é" [im "" "image/png", im "" "image/jpeg"]]
  runCase 189 "E" "" [msg "system" "𝔘𝔫𝔦" [tc "😀" "日本" "é", tc "" "" "{\"a\":1}"] "é" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 190 "E" "" [msg "é" "you are motoko" [tc "" "日本" "{\"a\":1}"] "call_1" [im "" "image/png"], msg "user" "\r\n" [] "call_1" []]
  runCase 191 "E" "" [msg "system" "sha256:" [] "😀" [], msg "assistant" "make[1]" [tc "😀" "bash" "{\"a\":1}"] "😀" [], msg "system" ";0}a\"];{\"13日" [] "" []]
  runCase 192 "E" "" [msg "" "é" [tc "😀" "" "", tc "" "read_file" "é"] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "é" "x‍😀" [tc "é" "read_file" "{}", tc "é" "bash" "{\"a\":1}"] "" []]
  runCase 193 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 194 "B" "" [msg "" "tc-end;" [tc "" "日本" "make[3]"] "" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/png"], msg "system" "make[0]" [tc "" "" "", tc "call_1" "日本" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 195 "E" "" []
  runCase 196 "E" "" [msg "tool" "you are motoko" [tc "é" "日本" "{\"a\":1}"] "call_1" [im "" ""], msg "é" "make[12]make[3]" [] "é" [im "data:image/png;base64,AAAA" "", im "" "image/png"], msg "é" "0[:" [tc "a" "bash" "{}"] "" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/png"], msg "tool" "{]\"a]é\"-\"" [tc "😀" "日本" "é"] "é" []]
  runCase 197 "L" "" [msg "é" "b]é" [] "" []]
  runCase 198 "E" "" [msg "é" "m" [] "😀" []]
  runCase 199 "L" "x" [msg "é" "\"quoted\"" [tc "é" "bash" "é"] "😀" []]

#eval show IO Unit from do
  runCase 200 "E" "" [msg "user" "tc-end;" [tc "é" "read_file" "{}"] "é" [], msg "é" "日本" [tc "a" "read_file" "{}", tc "😀" "bash" ""] "" [], msg "" "é" [tc "😀" "bash" "{}"] "😀" []]
  runCase 201 "E" "" [msg "user" "make[20] and make[2]" [] "😀" [], msg "assistant" "[\"a\"]" [] "a" [], msg "" "im-end;" [tc "😀" "" "make[3]"] "😀" [], msg "user" "日1 -21" [] "call_1" [im "" ""]]
  runCase 202 "E" "" [msg "é" ":\"-]" [tc "😀" "read_file" "make[3]"] "call_1" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 203 "E" "" [msg "é" "x‍😀" [] "😀" [], msg "é" "é" [] "😀" [], msg "tool" "list the files" [] "a" []]
  runCase 204 "L" "sha256:e3b0" []
  runCase 205 "E" "" []
  runCase 206 "E" "" [msg "tool" "make[12]make[3]" [tc "a" "" "é"] "😀" [], msg "assistant" "make[1make[2]]" [tc "a" "read_file" "é"] "é" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 207 "E" "" [msg "assistant" "\"quoted\"" [tc "call_1" "" "make[3]", tc "a" "bash" "make[3]"] "call_1" [im "é" "image/png"]]
  runCase 208 "L" "m-end;" [msg "assistant" "list the files" [] "call_1" [], msg "é" "m{role:4:user;}" [] "a" [im "file:///tmp/a.png" ""], msg "tool" "list the files" [tc "call_1" "bash" "{}"] "" []]
  runCase 209 "L" "x" [msg "assistant" "}]21[{\"]m1 " [tc "é" "" "{}"] "😀" [], msg "é" "list the files" [] "é" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/png"]]
  runCase 210 "L" "sha256:e3b0" [msg "system" "make[20] and make[2]" [tc "" "bash" "make[3]"] "é" [], msg "" "é1{" [tc "a" "bash" "", tc "a" "read_file" "make[3]"] "é" []]
  runCase 211 "L" "m-end;" [msg "system" "" [] "é" [], msg "user" "\\😀]11" [] "" [], msg "é" "3}é:[é;" [] "call_1" []]
  runCase 212 "E" "" [msg "tool" "line\nbreak" [tc "é" "日本" "é"] "a" [], msg "" "back\\slash" [tc "call_1" "" "{}"] "é" [], msg "user" "é ]a2}" [tc "" "日本" "é"] "😀" [], msg "system" "{{}" [tc "call_1" "" "{\"a\":1}", tc "é" "bash" "{}"] "call_1" []]
  runCase 213 "E" "" [msg "é" "日日a[" [tc "" "" "", tc "" "" "{}"] "" [], msg "é" "x:3:y;" [tc "😀" "日本" ""] "é" [im "file:///tmp/a.png" "image/png"], msg "é" "m[{0\n" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" "make[1make[2]]" [tc "😀" "read_file" "{\"a\":1}"] "" [im "é" ""]]
  runCase 214 "E" "" [msg "tool" "im-end;" [tc "a" "" "", tc "😀" "日本" "{\"a\":1}"] "é" [], msg "assistant" "x:3:y;" [tc "a" "" "make[3]"] "😀" [im "" "image/jpeg"]]
  runCase 215 "E" "" [msg "system" "á" [tc "é" "bash" "make[3]"] "call_1" [], msg "" "ok" [] "😀" [im "" "image/jpeg"]]
  runCase 216 "E" "" [msg "system" "ém" [] "é" [im "é" "image/png"]]
  runCase 217 "B" "" [msg "assistant" "𝔘𝔫𝔦" [tc "😀" "read_file" "", tc "call_1" "read_file" "é"] "" [], msg "é" "éa-\n0" [] "call_1" [], msg "user" "2" [] "é" [], msg "user" "{}" [] "é" [im "é" "image/jpeg", im "" "image/png"]]
  runCase 218 "B" "" [msg "system" "日本語" [tc "é" "read_file" "make[3]"] "call_1" [], msg "" "back\\slash" [] "a" []]
  runCase 219 "L" "" [msg "" "m{role:4:user;}" [tc "😀" "" "make[3]"] "é" [], msg "" ":" [] "é" [im "file:///tmp/a.png" "image/png"]]
  runCase 220 "B" "" [msg "system" "x‍😀" [] "é" [im "file:///tmp/a.png" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 221 "B" "" [msg "system" "{}" [] "" [], msg "é" "ü:2:ü;" [] "" []]
  runCase 222 "E" "" [msg "system" "\"quoted\"" [] "é" [], msg "user" "[\"a\"]" [tc "😀" "bash" "make[3]"] "😀" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 223 "E" "" [msg "" "" [tc "call_1" "" ""] "call_1" []]
  runCase 224 "B" "" [msg "é" "make[1make[2]]" [tc "a" "bash" "{\"a\":1}"] "" [im "" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "system" "á" [tc "call_1" "" "{}", tc "a" "read_file" "{}"] "😀" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 225 "E" "" [msg "system" "ok" [] "" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "user" "you are motoko" [tc "😀" "bash" "{\"a\":1}", tc "call_1" "read_file" "{}"] "a" [], msg "system" "hi" [] "" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 226 "B" "" [msg "system" "]\"\"b{ 😀b" [tc "" "bash" "{}", tc "😀" "bash" "make[3]"] "😀" [], msg "" "ok" [tc "call_1" "" "{\"a\":1}"] "a" [im "" "image/png"]]
  runCase 227 "E" "" [msg "user" "é" [tc "a" "read_file" "{}"] "é" [im "" "", im "data:image/png;base64,AAAA" ""], msg "user" "m{role:4:user;}" [tc "é" "日本" "{\"a\":1}"] "😀" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "sha256:" [tc "call_1" "read_file" "make[3]"] "a" []]
  runCase 228 "L" "sha256:" [msg "assistant" "x:3:y;" [] "é" []]
  runCase 229 "B" "" [msg "assistant" "tab\there" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/png"], msg "" "][]}0]0😀1{0;" [tc "a" "bash" "{}"] "call_1" []]
  runCase 230 "B" "" [msg "é" "m{role:4:user;}" [tc "a" "日本" ""] "é" []]
  runCase 231 "L" "" [msg "é" "tab\there" [] "é" [im "é" "", im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "back\\slash" [] "a" [im "" "", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 232 "L" "x" [msg "user" "}m{" [] "call_1" [im "file:///tmp/a.png" "image/jpeg"], msg "é" "" [tc "😀" "" "{}"] "😀" []]
  runCase 233 "E" "" [msg "system" "日日21" [tc "😀" "bash" "é"] "😀" []]
  runCase 234 "B" "" [msg "" "back\\slash" [] "call_1" [], msg "tool" "日本" [tc "call_1" "" "make[3]"] "" []]
  runCase 235 "L" "sha256:" [msg "" "}" [] "call_1" [im "é" "image/png"], msg "" "日本" [tc "é" "日本" "make[3]"] "😀" [], msg "tool" "á" [] "é" [im "" ""], msg "assistant" "éx" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 236 "B" "" [msg "" "á" [tc "a" "" "make[3]"] "😀" [], msg "tool" "é" [tc "é" "" "{}"] "😀" [], msg "é" "tc-end;" [tc "" "" ""] "call_1" [], msg "assistant" "make[0]" [] "" [im "é" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 237 "E" "" [msg "user" " \\}é\n-}a:2{" [] "😀" [im "" "image/jpeg"], msg "system" ";ééé1😀{1;2\\" [tc "a" "" "{}"] "call_1" [], msg "tool" "tc-end;" [] "😀" [im "é" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 238 "E" "" [msg "" "m😀]\n2" [tc "é" "" "é"] "😀" [], msg "system" "x:3:y;" [] "é" [im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "130b😀 1};" [tc "" "bash" "make[3]"] "a" []]
  runCase 239 "L" "é😀" []

#eval show IO Unit from do
  runCase 240 "E" "" [msg "user" "日本語" [] "call_1" [], msg "é" "m{role:4:user;}" [tc "call_1" "日本" "{}", tc "😀" "" "{}"] "😀" []]
  runCase 241 "E" "" []
  runCase 242 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "日本" [] "é" [], msg "system" ";[0\\a-\"😀é" [] "call_1" [], msg "" "]{ [1é{3}0" [tc "" "bash" ""] "😀" [im "file:///tmp/a.png" ""], msg "" "tab\there" [tc "" "read_file" "{\"a\":1}"] "" []]
  runCase 243 "L" "é😀" []
  runCase 244 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "éx" [tc "call_1" "bash" "", tc "😀" "" ""] "a" [], msg "" "éx" [tc "call_1" "read_file" "make[3]"] "é" [], msg "user" "日本語" [tc "a" "read_file" "{\"a\":1}", tc "a" "read_file" "{\"a\":1}"] "call_1" []]
  runCase 245 "L" "" [msg "" "m2" [tc "call_1" "日本" "é"] "a" [], msg "tool" " 0\"é{3-;" [] "call_1" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 246 "B" "" [msg "tool" "hi" [] "é" [], msg "tool" "x‍😀" [tc "a" "日本" "é"] "é" []]
  runCase 247 "E" "" []
  runCase 248 "E" "" [msg "é" "x:3:y;" [] "é" [], msg "é" "é" [tc "é" "bash" "{\"a\":1}"] "" [im "file:///tmp/a.png" ""], msg "é" "" [] "call_1" [], msg "assistant" "😀" [] "call_1" []]
  runCase 249 "E" "" [msg "user" "make[21]" [] "call_1" [], msg "é" "\"quoted\"" [tc "call_1" "日本" "make[3]"] "call_1" [], msg "system" "" [] "😀" [], msg "tool" "x:3:y;" [] "call_1" []]
  runCase 250 "L" "" [msg "" "make[1]" [] "a" []]
  runCase 251 "L" "sha256:" [msg "" "" [tc "😀" "read_file" "make[3]"] "call_1" []]
  runCase 252 "B" "" [msg "é" "list the files" [] "é" [im "é" "image/jpeg"]]
  runCase 253 "E" "" [msg "" "日本" [] "" [], msg "user" "you are motoko" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 254 "E" "" []
  runCase 255 "L" "sha256:" [msg "é" "you are motoko" [] "é" [], msg "assistant" " nbsp" [] "call_1" [im "é" "image/jpeg", im "é" ""], msg "system" "[{日\n]02b\"2" [] "😀" [], msg "assistant" "éx" [] "a" []]
  runCase 256 "E" "" []
  runCase 257 "E" "" [msg "tool" "\né" [tc "😀" "read_file" "é", tc "" "bash" "make[3]"] "" [], msg "system" "]😀{ma\\:2日0" [] "" [], msg "" "sha256:" [tc "é" "read_file" "é"] "é" []]
  runCase 258 "E" "" [msg "é" "[{2:;" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/png"], msg "system" "make[12]make[3]" [tc "" "日本" "make[3]", tc "" "日本" "é"] "call_1" []]
  runCase 259 "L" "sha256:" [msg "" "make[1]" [] "call_1" [im "" "image/png"]]
  runCase 260 "E" "" [msg "" "é33}:a:20" [tc "call_1" "bash" "{\"a\":1}"] "" [im "data:image/png;base64,AAAA" ""], msg "user" "make[21]" [] "a" []]
  runCase 261 "L" "x" [msg "user" "back\\slash" [tc "😀" "bash" "{}"] "a" [], msg "" "[[ 😀}a-\"3" [] "😀" [im "" "image/jpeg"], msg "é" "" [tc "é" "" "make[3]"] "" [im "data:image/png;base64,AAAA" "", im "" "image/jpeg"]]
  runCase 262 "E" "" [msg "" "ü:2:ü;" [tc "a" "日本" "{\"a\":1}", tc "" "read_file" "{\"a\":1}"] "call_1" [], msg "" "ok" [] "é" [], msg "tool" "é" [] "😀" []]
  runCase 263 "L" "m-end;" [msg "assistant" "make[12]make[3]" [] "call_1" [], msg "tool" "make[21]" [tc "call_1" "日本" ""] "call_1" [], msg "system" "{}" [] "a" [], msg "system" "" [] "" []]
  runCase 264 "E" "" []
  runCase 265 "E" "" [msg "user" "b\\" [tc "" "日本" "make[3]"] "é" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "assistant" "make[1]" [] "a" [im "data:image/png;base64,AAAA" "", im "" "image/jpeg"], msg "" "list the files" [tc "😀" "日本" "{}"] "a" []]
  runCase 266 "E" "" [msg "user" "line\nbreak" [] "😀" [], msg "system" "😀" [tc "call_1" "日本" "{}", tc "é" "bash" "{\"a\":1}"] "😀" []]
  runCase 267 "B" "" []
  runCase 268 "E" "" [msg "tool" "im-end;" [] "" [im "file:///tmp/a.png" ""]]
  runCase 269 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "make[1make[2]]" [] "😀" []]
  runCase 270 "E" "" []
  runCase 271 "L" "sha256:" [msg "é" " nbsp" [] "é" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"], msg "system" "line\nbreak" [tc "é" "bash" "{}"] "😀" []]
  runCase 272 "E" "" [msg "" "make[12]make[3]" [] "a" [], msg "tool" "x‍😀" [tc "😀" "" "{\"a\":1}"] "😀" [], msg "é" "😀" [tc "😀" "read_file" "é"] "a" [im "é" "", im "" "image/jpeg"], msg "tool" "make[1]" [tc "é" "日本" "é"] "call_1" [im "file:///tmp/a.png" "image/png"]]
  runCase 273 "E" "" [msg "" "list the files" [tc "😀" "bash" "{}"] "call_1" []]
  runCase 274 "L" "sha256:" [msg "system" "" [] "a" [], msg "user" "😀" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 275 "E" "" [msg "system" "😀" [tc "😀" "bash" "make[3]"] "call_1" [], msg "é" "im-end;" [] "call_1" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "assistant" "\r\n" [] "call_1" [], msg "tool" "1;\n- m2;😀[a" [tc "call_1" "bash" "é", tc "a" "bash" "é"] "é" []]
  runCase 276 "E" "" [msg "assistant" "\\12a\"b [éé}\\" [] "a" [im "é" "", im "" "image/jpeg"], msg "é" "[}}10]" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" "\n{😀 é;]\\\"  m" [] "é" [im "" "image/png", im "" "image/png"], msg "assistant" "tc-end;" [] "é" [im "file:///tmp/a.png" "image/png"]]
  runCase 277 "E" "" [msg "system" "á" [tc "a" "日本" "{}", tc "" "" "{\"a\":1}"] "😀" []]
  runCase 278 "E" "" []
  runCase 279 "E" "" []

#eval show IO Unit from do
  runCase 280 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "x:3:y;" [tc "a" "" "{}"] "call_1" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 281 "B" "" [msg "" "hi" [] "" [im "" "image/jpeg"], msg "system" "list the files" [] "call_1" [], msg "assistant" "á" [tc "😀" "日本" ""] "" [im "file:///tmp/a.png" ""]]
  runCase 282 "E" "" [msg "é" "im-end;" [tc "a" "read_file" "{}"] "" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "user" ":303:😀\n\"{{日2" [tc "😀" "日本" ""] "" [], msg "é" "\r\n" [tc "é" "bash" "{}", tc "call_1" "" "é"] "a" [im "file:///tmp/a.png" "image/jpeg"], msg "system" "make[20] and make[2]" [] "😀" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" ""]]
  runCase 283 "E" "" [msg "assistant" "make[20] and make[2]" [] "😀" []]
  runCase 284 "E" "" [msg "" " nbsp" [] "😀" [im "" ""], msg "" "\r\n" [] "call_1" [im "" "image/jpeg", im "file:///tmp/a.png" ""]]
  runCase 285 "L" "" [msg "" "make[21]" [tc "call_1" "bash" "{}"] "a" [im "data:image/png;base64,AAAA" ""]]
  runCase 286 "E" "" [msg "" "éx" [tc "a" "read_file" "", tc "" "" "{\"a\":1}"] "😀" [im "é" "", im "file:///tmp/a.png" "image/jpeg"], msg "tool" "\r\n" [tc "😀" "bash" "", tc "😀" "" ""] "call_1" [im "" "image/png"]]
  runCase 287 "L" "x" []
  runCase 288 "E" "" [msg "user" "hi" [] "call_1" [], msg "assistant" "" [] "call_1" [], msg "user" " 2-322\"日abé\n" [tc "a" "日本" "make[3]"] "a" [im "" "", im "é" "image/png"]]
  runCase 289 "E" "" [msg "user" "0é0[3é" [tc "😀" "bash" "{}"] "a" [im "data:image/png;base64,AAAA" "image/png"], msg "assistant" " nbsp" [] "😀" []]
  runCase 290 "E" "" [msg "tool" "\"quoted\"" [tc "call_1" "" "{\"a\":1}", tc "é" "bash" "{\"a\":1}"] "call_1" []]
  runCase 291 "E" "" [msg "user" "1{}\n" [tc "call_1" "" "make[3]", tc "é" "" "{}"] "" [im "é" "image/jpeg", im "file:///tmp/a.png" ""], msg "user" " nbsp" [] "" [], msg "system" "日\\\"\n\n-}{ [3" [] "é" []]
  runCase 292 "L" "x" [msg "tool" "make[20] and make[2]" [tc "call_1" "" "é"] "é" []]
  runCase 293 "E" "" []
  runCase 294 "E" "" [msg "" ";;\"{-2]m\\b\\" [tc "" "read_file" ""] "call_1" [], msg "assistant" "back\\slash" [] "é" [im "file:///tmp/a.png" "image/png"]]
  runCase 295 "B" "" [msg "tool" "[:a{\"a:" [tc "é" "bash" ""] "é" [im "é" "image/jpeg"]]
  runCase 296 "L" "é😀" [msg "user" "2\\ éa3\"" [tc "é" "read_file" "{}"] "é" [im "é" ""], msg "assistant" "éx" [] "call_1" [], msg "system" "make[1make[2]]" [tc "call_1" "日本" "é"] "é" []]
  runCase 297 "E" "" [msg "" "line\nbreak" [] "call_1" [], msg "system" "tc-end;" [tc "😀" "日本" "{\"a\":1}"] "a" [im "" "image/png", im "" "image/png"]]
  runCase 298 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "éx" [tc "é" "read_file" "{\"a\":1}"] "a" [], msg "" "日本" [] "a" [], msg "tool" "back\\slash" [tc "é" "" "é"] "call_1" [], msg "assistant" "1;;\\{ 2[m 日" [] "😀" []]
  runCase 299 "E" "" [msg "user" "3{b-" [] "é" [im "file:///tmp/a.png" ""], msg "assistant" "tc-end;" [] "😀" [im "file:///tmp/a.png" "", im "" ""]]
  runCase 300 "E" "" [msg "tool" "[\"a\"]" [] "call_1" [im "é" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "assistant" "[\"a\"]" [] "a" [im "é" "image/png"], msg "assistant" "" [] "a" [], msg "system" " nbsp" [] "call_1" [im "é" "image/jpeg", im "é" "image/jpeg"]]
  runCase 301 "L" "sha256:" [msg "system" "éx" [tc "call_1" "" "é", tc "😀" "read_file" ""] "" [], msg "system" "\"-11\"[ b日" [] "call_1" [], msg "tool" ";}" [tc "😀" "" "", tc "call_1" "日本" "{}"] "a" [im "" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "ü:2:ü;" [] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 302 "E" "" [msg "assistant" "ok" [tc "call_1" "read_file" "make[3]"] "😀" [], msg "user" "[\"a\"]" [] "call_1" []]
  runCase 303 "L" "sha256:e3b0" [msg "assistant" "make[12]make[3]" [] "" []]
  runCase 304 "B" "" [msg "user" "éx" [tc "😀" "read_file" "{\"a\":1}"] "😀" [im "é" "image/jpeg"], msg "é" "ok" [tc "😀" "read_file" "make[3]", tc "é" "read_file" ""] "" [], msg "é" "0m" [tc "a" "日本" "{}", tc "" "bash" "make[3]"] "call_1" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "" ";日\"03日[\" " [] "😀" []]
  runCase 305 "B" "" [msg "system" "}m{" [tc "" "read_file" "{\"a\":1}", tc "é" "bash" "{}"] "😀" [im "é" "image/jpeg"], msg "tool" "ü:2:ü;" [tc "😀" "read_file" "make[3]"] "call_1" []]
  runCase 306 "E" "" [msg "" "😀" [] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "" "image/jpeg"], msg "tool" "日本語" [tc "a" "read_file" "{}"] "" []]
  runCase 307 "E" "" []
  runCase 308 "B" "" [msg "system" " nbsp" [] "😀" [], msg "system" "\"quoted\"" [tc "😀" "日本" "make[3]", tc "" "bash" "{\"a\":1}"] "😀" []]
  runCase 309 "E" "" [msg "system" "sha256:" [tc "" "" "{\"a\":1}"] "" [], msg "assistant" "\"quoted\"" [tc "😀" "日本" "é", tc "" "" "é"] "😀" [], msg "user" "ü:2:ü;" [] "" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 310 "B" "" [msg "assistant" "; \"m\n]ma2]" [] "é" [], msg "user" "{}" [] "call_1" []]
  runCase 311 "B" "" [msg "assistant" "\n]m" [] "call_1" [], msg "tool" "éx" [tc "a" "日本" "é"] "a" []]
  runCase 312 "B" "" [msg "é" " nbsp" [] "call_1" [], msg "assistant" "á" [] "call_1" [im "" "", im "é" "image/png"], msg "é" "sha256:" [] "😀" [im "é" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 313 "B" "" []
  runCase 314 "E" "" [msg "assistant" "sha256:" [tc "call_1" "bash" "é"] "a" [im "file:///tmp/a.png" "image/png", im "" "image/png"], msg "é" "3:-" [] "a" [im "é" "", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 315 "L" "" [msg "system" "a]é" [tc "😀" "日本" "{}", tc "é" "" ""] "😀" [], msg "user" "make[1]" [tc "" "bash" "{}"] "call_1" []]
  runCase 316 "B" "" [msg "assistant" "sha256:" [] "😀" [], msg "" "b3{:[2\"-}m}:" [tc "😀" "read_file" "", tc "" "bash" "make[3]"] "a" [], msg "é" "make[1]" [] "a" [im "é" "image/png", im "" "image/png"], msg "é" "ü:2:ü;" [] "a" []]
  runCase 317 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 318 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" "\"quoted\"" [] "call_1" [im "file:///tmp/a.png" "image/jpeg"], msg "é" "b" [] "" []]
  runCase 319 "B" "" [msg "assistant" " nbsp" [] "a" []]

#eval show IO Unit from do
  runCase 320 "E" "" [msg "tool" "im-end;" [tc "😀" "日本" "{}"] "a" [], msg "é" "\"quoted\"" [tc "a" "" "make[3]"] "😀" []]
  runCase 321 "E" "" [msg "system" "𝔘𝔫𝔦" [] "😀" [], msg "system" ";20; {aé" [] "é" [im "file:///tmp/a.png" "image/png"]]
  runCase 322 "E" "" [msg "assistant" "3{" [tc "a" "bash" "make[3]"] "" [], msg "system" "\"]}日\"12[\\b" [] "call_1" [], msg "é" "ü:2:ü;" [tc "a" "" "é"] "a" [], msg "" "make[1make[2]]" [] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 323 "B" "" [msg "system" "\\m" [tc "" "bash" "{}", tc "" "" "é"] "é" []]
  runCase 324 "E" "" [msg "" "ok" [] "" []]
  runCase 325 "B" "" [msg "" "}m{" [] "call_1" [im "é" "image/jpeg", im "é" "image/jpeg"], msg "tool" "back\\slash" [tc "é" "日本" "{\"a\":1}", tc "" "" ""] "a" [im "é" "image/png"], msg "tool" "éx" [tc "😀" "bash" "{\"a\":1}"] "call_1" [im "" ""]]
  runCase 326 "E" "" [msg "tool" "back\\slash" [tc "😀" "read_file" "make[3]", tc "😀" "bash" "é"] "a" [], msg "é" "make[20] and make[2]" [] "call_1" []]
  runCase 327 "L" "m-end;" [msg "" "😀日" [tc "😀" "bash" "é"] "" [im "file:///tmp/a.png" "image/png"]]
  runCase 328 "B" "" [msg "é" "-- :b;" [tc "" "bash" "é"] "" [], msg "é" "20;2" [tc "é" "" "{\"a\":1}"] "a" []]
  runCase 329 "B" "" [msg "system" "[\"a\"]" [] "😀" [im "é" "image/png", im "file:///tmp/a.png" ""], msg "é" "you are motoko" [tc "😀" "" "é"] "😀" []]
  runCase 330 "E" "" [msg "system" "back\\slash" [tc "é" "bash" "é", tc "😀" "日本" "é"] "a" [im "file:///tmp/a.png" "image/jpeg"], msg "tool" "a\n\\]-b😀;😀3" [] "é" []]
  runCase 331 "L" "sha256:" []
  runCase 332 "E" "" [msg "system" "[\"a\"]" [tc "call_1" "日本" "", tc "a" "read_file" "make[3]"] "a" [], msg "tool" " nbsp" [tc "é" "bash" "{}"] "call_1" [im "é" "image/jpeg"]]
  runCase 333 "E" "" [msg "assistant" "\"quoted\"" [] "😀" []]
  runCase 334 "L" "m-end;" [msg "user" "𝔘𝔫𝔦" [] "call_1" [], msg "assistant" "{}" [] "😀" [], msg "system" "back\\slash" [tc "call_1" "bash" "", tc "a" "read_file" "make[3]"] "😀" [im "" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 335 "B" "" [msg "tool" "make[1]" [tc "😀" "read_file" "make[3]"] "a" [im "data:image/png;base64,AAAA" ""], msg "system" "back\\slash" [] "é" [], msg "" "}3\\日\"\n3-10" [] "é" []]
  runCase 336 "B" "" []
  runCase 337 "L" "é😀" [msg "assistant" "" [] "" []]
  runCase 338 "E" "" [msg "tool" "ok" [tc "call_1" "bash" "make[3]"] "a" [], msg "tool" "\n日😀日" [] "é" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" ""]]
  runCase 339 "E" "" [msg "assistant" "you are motoko" [] "a" [], msg "" "you are motoko" [tc "😀" "bash" "{}"] "é" [], msg "tool" "{}" [] "😀" []]
  runCase 340 "B" "" [msg "é" "make[1]" [] "call_1" [], msg "tool" "a\"{01[m日}m}]" [tc "a" "bash" "{}"] "call_1" []]
  runCase 341 "E" "" [msg "tool" "3\"😀a😀[}1b1b}" [tc "a" "" "é"] "a" [im "" "image/jpeg"], msg "tool" "make[1]" [] "é" [im "" "image/png", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 342 "E" "" [msg "" "日本" [tc "a" "日本" "{}"] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "" "image/jpeg"]]
  runCase 343 "E" "" []
  runCase 344 "E" "" [msg "assistant" "2\\3a32\n0]" [tc "a" "" "{}"] "😀" []]
  runCase 345 "L" "sha256:e3b0" [msg "tool" "line\nbreak" [] "a" [], msg "system" "x:3:y;" [] "😀" []]
  runCase 346 "B" "" [msg "tool" "}0é\"a-m" [] "a" [im "" "", im "file:///tmp/a.png" "image/jpeg"], msg "é" "2" [] "a" [im "é" "", im "é" ""], msg "assistant" "1éé[m3\n{3日日" [tc "call_1" "read_file" "make[3]", tc "😀" "bash" "é"] "call_1" []]
  runCase 347 "L" "" [msg "assistant" "[\"a\"]" [] "😀" [im "data:image/png;base64,AAAA" "image/png"], msg "é" "日本語" [] "" [im "data:image/png;base64,AAAA" "image/png"], msg "system" "ok" [tc "😀" "" ""] "" [], msg "é" "you are motoko" [tc "call_1" "bash" "make[3]"] "call_1" []]
  runCase 348 "E" "" [msg "é" "é" [] "😀" [], msg "" "tc-end;" [] "call_1" [], msg "tool" "😀0 -3m{é{3é" [] "" [], msg "user" "} -:" [tc "a" "" "{}"] "é" [im "file:///tmp/a.png" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 349 "E" "" [msg "user" "you are motoko" [tc "a" "bash" "é"] "call_1" [], msg "tool" "日本" [] "a" [], msg "" "make[12]make[3]" [] "a" []]
  runCase 350 "L" "sha256:" [msg "é" "m\\😀é[m[13\"[" [tc "a" "bash" "é"] "a" []]
  runCase 351 "E" "" [msg "user" "日本語" [] "call_1" [im "é" "image/jpeg"], msg "system" "x:3:y;" [] "é" [im "" "image/jpeg", im "file:///tmp/a.png" ""]]
  runCase 352 "E" "" [msg "é" "" [tc "" "" "{\"a\":1}", tc "" "" "{}"] "a" [], msg "assistant" "á" [tc "😀" "" "make[3]"] "" [], msg "user" "back\\slash" [tc "😀" "read_file" "é", tc "a" "read_file" ""] "a" []]
  runCase 353 "L" "sha256:e3b0" [msg "user" "😀" [] "a" [im "file:///tmp/a.png" "image/jpeg"], msg "tool" "" [tc "😀" "" "é"] "é" []]
  runCase 354 "E" "" [msg "assistant" "á" [] "é" []]
  runCase 355 "B" "" [msg "user" "{}" [tc "a" "日本" "", tc "😀" "" "{}"] "a" [], msg "tool" "make[0]" [] "é" [], msg "é" "𝔘𝔫𝔦" [] "é" [im "" "image/png"]]
  runCase 356 "E" "" [msg "tool" "2;日2]é\": " [] "😀" [im "data:image/png;base64,AAAA" "", im "é" "image/jpeg"]]
  runCase 357 "L" "é😀" [msg "tool" "\\ ; \n" [] "" [], msg "system" "you are motoko" [tc "" "" "{}"] "call_1" [], msg "system" "you are motoko" [] "call_1" [im "é" "image/jpeg"], msg "é" "" [] "é" []]
  runCase 358 "E" "" [msg "" ";\\{bé m😀" [tc "é" "" "make[3]"] "😀" [im "" "", im "" "image/png"], msg "system" "line\nbreak" [] "call_1" [], msg "system" "日本語" [tc "" "bash" "{}", tc "😀" "bash" "é"] "call_1" [im "file:///tmp/a.png" ""]]
  runCase 359 "E" "" [msg "user" "á" [tc "call_1" "read_file" "{}"] "call_1" []]

#eval show IO Unit from do
  runCase 360 "E" "" [msg "" "b" [tc "a" "日本" "make[3]", tc "a" "" ""] "a" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "日本語" [] "é" [im "file:///tmp/a.png" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" " [" [tc "é" "bash" "make[3]"] "" [], msg "é" "1:0]1-😀😀" [] "call_1" []]
  runCase 361 "E" "" []
  runCase 362 "E" "" [msg "" "make[21]" [tc "a" "日本" "make[3]", tc "call_1" "" "make[3]"] "é" [im "" "image/png"], msg "" "make[1]" [tc "a" "read_file" "make[3]", tc "é" "read_file" ""] "" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 363 "L" "x" [msg "assistant" "日本語" [] "" [im "é" "image/png", im "" ""]]
  runCase 364 "E" "" [msg "system" "make[12]make[3]" [] "a" []]
  runCase 365 "L" "é😀" [msg "" "á" [tc "😀" "日本" "{\"a\":1}"] "😀" [im "é" ""]]
  runCase 366 "E" "" [msg "user" "im-end;" [] "é" [im "file:///tmp/a.png" "image/png", im "é" ""]]
  runCase 367 "E" "" [msg "é" "make[0]" [tc "😀" "日本" ""] "" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "á" [] "a" []]
  runCase 368 "L" "sha256:e3b0" [msg "é" "make[1]" [tc "call_1" "bash" "", tc "call_1" "bash" "make[3]"] "call_1" []]
  runCase 369 "E" "" [msg "user" "}}m;b" [tc "call_1" "bash" "{}"] "" [], msg "user" "tab\there" [tc "é" "" "{}"] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "" "you are motoko" [tc "" "read_file" "{\"a\":1}"] "call_1" []]
  runCase 370 "E" "" []
  runCase 371 "L" "é😀" [msg "" "tc-end;" [] "😀" [im "é" "image/png", im "file:///tmp/a.png" "image/png"], msg "system" "[" [] "" []]
  runCase 372 "E" "" []
  runCase 373 "B" "" [msg "tool" "\"0aa 2:" [] "é" [], msg "" "make[1]" [tc "call_1" "bash" "make[3]"] "call_1" [im "é" ""]]
  runCase 374 "L" "sha256:" [msg "user" "list the files" [] "" []]
  runCase 375 "L" "x" [msg "assistant" "line\nbreak" [tc "call_1" "bash" "{\"a\":1}"] "call_1" [], msg "tool" "}m{" [] "😀" [], msg "assistant" "x:3:y;" [tc "" "日本" "é"] "call_1" [im "é" "image/jpeg", im "" ""]]
  runCase 376 "B" "" [msg "tool" " \\" [tc "a" "" "{\"a\":1}", tc "😀" "日本" "{}"] "call_1" [], msg "assistant" "tab\there" [tc "a" "" "{}", tc "😀" "bash" ""] "é" []]
  runCase 377 "E" "" []
  runCase 378 "B" "" [msg "" "😀" [] "a" [], msg "system" "make[12]make[3]" [tc "" "bash" "{}"] "" []]
  runCase 379 "E" "" []
  runCase 380 "E" "" [msg "" "x‍😀" [] "😀" [im "data:image/png;base64,AAAA" ""]]
  runCase 381 "E" "" [msg "é" " " [tc "é" "" "{}"] "😀" [im "é" "image/png"], msg "tool" "m{role:4:user;}" [] "😀" []]
  runCase 382 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "system" "sha256:" [] "é" [], msg "system" "sha256:" [] "call_1" [], msg "é" ";-" [tc "😀" "" "{\"a\":1}"] "😀" []]
  runCase 383 "B" "" [msg "system" "á" [tc "a" "bash" "{\"a\":1}"] "call_1" [], msg "system" "" [tc "call_1" "bash" "{}", tc "call_1" "bash" "make[3]"] "😀" [im "é" "image/png"]]
  runCase 384 "L" "" [msg "user" "é" [] "call_1" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "ok" [tc "" "bash" "make[3]"] "call_1" [], msg "tool" "á" [] "call_1" [], msg "user" "tab\there" [tc "a" "read_file" "", tc "a" "read_file" "make[3]"] "a" [im "é" "", im "é" "image/jpeg"]]
  runCase 385 "E" "" [msg "assistant" "}m{" [tc "é" "日本" "{\"a\":1}"] "call_1" []]
  runCase 386 "E" "" [msg "" "ü:2:ü;" [tc "😀" "read_file" "é"] "" [], msg "tool" "make[1make[2]]" [tc "é" "bash" "{}"] "😀" [], msg "" "make[12]make[3]" [tc "" "日本" "{}"] "é" [im "é" "image/png"]]
  runCase 387 "E" "" [msg "" "x:3:y;" [] "😀" [], msg "" "x‍😀" [] "a" [], msg "tool" "make[21]" [] "é" [im "" "image/png", im "file:///tmp/a.png" ""], msg "é" "ü:2:ü;" [] "😀" [im "data:image/png;base64,AAAA" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 388 "E" "" [msg "user" "\\0日-0日b\n\"" [] "😀" [], msg "system" "[\"a\"]" [] "" [im "" "image/png", im "" "image/jpeg"]]
  runCase 389 "L" "sha256:" [msg "é" "[\"a\"]" [] "call_1" [im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "tc-end;" [] "call_1" [], msg "user" "you are motoko" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "tool" "2m2😀am-{ \n日" [] "" []]
  runCase 390 "B" "" [msg "" "😀\\1\"1a23" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/png"], msg "" "\";0:13é1日mé]" [] "é" []]
  runCase 391 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "system" "make[20] and make[2]" [tc "" "read_file" "make[3]", tc "a" "" "{\"a\":1}"] "" [im "data:image/png;base64,AAAA" "image/png", im "" "image/png"], msg "tool" "tc-end;" [] "call_1" [], msg "system" "é{\\;" [] "call_1" []]
  runCase 392 "L" "sha256:" [msg "user" "\\3" [tc "call_1" "read_file" ""] "call_1" []]
  runCase 393 "E" "" [msg "é" "\n;m:[-]1]{" [tc "" "bash" "make[3]"] "call_1" [], msg "é" "á" [tc "😀" "日本" "{\"a\":1}"] "a" [im "data:image/png;base64,AAAA" "image/png"], msg "system" "]bm]bé3a " [] "" [im "é" "image/jpeg"], msg "system" "make[20] and make[2]" [] "call_1" []]
  runCase 394 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "you are motoko" [tc "a" "" "{}", tc "😀" "bash" "{\"a\":1}"] "😀" [im "é" "image/png"]]
  runCase 395 "L" "m-end;" [msg "é" "ü:2:ü;" [] "😀" [im "data:image/png;base64,AAAA" ""]]
  runCase 396 "B" "" [msg "" "0\"{0é{日 " [tc "call_1" "" "{}", tc "" "read_file" "é"] "call_1" [], msg "system" "é" [tc "😀" "" "make[3]"] "" [im "file:///tmp/a.png" "image/png"]]
  runCase 397 "E" "" [msg "é" "á" [tc "😀" "" "make[3]"] "a" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 398 "L" "" [msg "user" "im-end;" [] "é" []]
  runCase 399 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
