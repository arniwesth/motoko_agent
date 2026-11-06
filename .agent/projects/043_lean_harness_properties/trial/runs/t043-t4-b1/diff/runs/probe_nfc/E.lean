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
  * `Str.length` (std/string `length`) — see `strLength`; its unit was settled by the
    differential test (SUMMARY.md, "model fixes").
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

/-- Non-vacuity: the hypothesis `Inj H` is satisfiable (by the identity), so each `bug_`
theorem above has at least one instance; `fixed_*` shows the same statements are not
false of everything. -/
theorem bug_P4_1_witness_id : ¬ P4_1 (fun s => s) canonicalMessageFrame
    (chainEmptyBase (fun s => s)) [mSys] [mUser] :=
  bug_P4_1_witness _ inj_id

theorem bug_P4_2_witness_id :
    (chainDigestsOver (fun s => s) canonicalMessageFrame (witnessBase (fun s => s)) [mUser]).getLast?
      ≠ some (chainDigestOver (fun s => s) canonicalMessageFrame (witnessBase (fun s => s)) [mUser]) :=
  bug_P4_2_witness _ inj_id

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
GENERATED by gen_cases.py (seed 1, 60 cases). The Lean half of the differential test:
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
  runCase 10 "E" "" [msg "system" "x:3:y;" [tc "é" "日本" "{\"a\":1}"] "" [im "" ""], msg "tool" "sha256:" [] "é" []]
  runCase 11 "E" "" [msg "system" "" [] "" [im "" "", im "data:image/png;base64,AAAA" ""], msg "é" "make[21]" [tc "é" "read_file" ""] "a" []]
  runCase 12 "L" "sha256:" []
  runCase 13 "L" "sha256:e3b0" [msg "é" "line\nbreak" [tc "call_1" "bash" "", tc "😀" "日本" "make[3]"] "a" [], msg "assistant" "𝔘𝔫𝔦" [tc "😀" "日本" "make[3]"] "" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 14 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "𝔘𝔫𝔦" [tc "call_1" "bash" "é", tc "😀" "bash" "{\"a\":1}"] "😀" [im "file:///tmp/a.png" ""], msg "é" "hi" [] "😀" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "" "" [] "😀" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 15 "B" "" [msg "assistant" "tc-end;" [tc "" "日本" "make[3]", tc "a" "read_file" "é"] "" [im "file:///tmp/a.png" "image/jpeg"], msg "" "m{role:4:user;}" [tc "é" "" "é"] "call_1" []]
  runCase 16 "B" "" [msg "" "make[21]" [tc "a" "read_file" "{}", tc "😀" "" "{}"] "" [], msg "system" "sha256:" [] "a" []]
  runCase 17 "E" "" [msg "" "make[1make[2]]" [] "a" [], msg "assistant" "make[1]" [tc "call_1" "" "é", tc "call_1" "日本" "é"] "" [], msg "assistant" "😀" [] "call_1" [], msg "assistant" "[ éa]a3{" [] "a" [im "é" "image/jpeg"]]
  runCase 18 "E" "" [msg "é" "make[21]" [tc "" "日本" "make[3]"] "call_1" [im "" "image/jpeg"], msg "assistant" "make[20] and make[2]" [] "call_1" [], msg "system" "make[1make[2]]" [tc "a" "日本" "make[3]", tc "call_1" "read_file" "{}"] "😀" []]
  runCase 19 "E" "" [msg "tool" "ü:2:ü;" [tc "😀" "bash" "é", tc "a" "" "{}"] "a" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "system" "0\n😀a1 " [tc "call_1" "bash" "{\"a\":1}"] "a" []]
  runCase 20 "E" "" [msg "tool" "tab\there" [] "é" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/jpeg"]]
  runCase 21 "E" "" []
  runCase 22 "E" "" []
  runCase 23 "E" "" [msg "user" "m1 " [tc "call_1" "" ""] "call_1" []]
  runCase 24 "B" "" [msg "" "😀{\\\";1bé:3{" [] "call_1" []]
  runCase 25 "L" "" [msg "" "list the files" [] "call_1" [], msg "" "you are motoko" [tc "call_1" "bash" "{}"] "call_1" []]
  runCase 26 "E" "" []
  runCase 27 "L" "" [msg "system" "{}" [tc "é" "read_file" "{}"] "é" [], msg "é" "back\\slash" [] "é" [im "file:///tmp/a.png" "image/jpeg"], msg "assistant" ";[-1b" [] "" [], msg "é" "á" [tc "call_1" "日本" "{}"] "" []]
  runCase 28 "L" "" [msg "user" "\"😀2m}\"[0[]2:" [] "" [im "" "image/jpeg"]]
  runCase 29 "B" "" [msg "tool" "" [] "a" []]
  runCase 30 "B" "" [msg "assistant" "tc-end;" [tc "😀" "bash" "{\"a\":1}"] "a" []]
  runCase 31 "E" "" [msg "system" "ü:2:ü;" [] "" [], msg "é" "sha256:" [] "é" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 32 "B" "" []
  runCase 33 "E" "" [msg "user" "0;\n 0" [] "a" []]
  runCase 34 "E" "" [msg "assistant" "\"[}0é\"}b]" [] "" [im "é" "image/jpeg"], msg "assistant" "ü:2:ü;" [tc "é" "bash" "é"] "call_1" [], msg "assistant" "{}" [tc "é" "bash" "{}", tc "call_1" "read_file" "make[3]"] "a" [], msg "assistant" "3\\3}" [tc "" "read_file" "é"] "" []]
  runCase 35 "B" "" [msg "é" "-]]1😀😀]é1\"" [tc "call_1" "read_file" "{}"] "" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" ""], msg "assistant" "ü:2:ü;" [tc "call_1" "read_file" "é"] "😀" []]
  runCase 36 "E" "" [msg "" "make[1]" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "" [tc "é" "" "é"] "😀" []]
  runCase 37 "E" "" [msg "system" ";m:{ :日]3é" [tc "a" "" "é"] "a" [im "é" "image/png", im "" ""], msg "" " nbsp" [] "call_1" []]
  runCase 38 "E" "" [msg "é" "make[20] and make[2]" [tc "é" "bash" "{}"] "😀" [], msg "assistant" "make[1make[2]]" [] "😀" []]
  runCase 39 "B" "" [msg "" "日}\"2😀é;[\\3" [] "call_1" []]
  runCase 40 "E" "" []
  runCase 41 "E" "" [msg "assistant" "-{:\n2\\0é\n2\n1" [] "" [im "é" ""], msg "assistant" "make[12]make[3]" [tc "😀" "日本" "{}", tc "é" "日本" "{\"a\":1}"] "😀" []]
  runCase 42 "B" "" [msg "" "\n[日 \né0}日 \n" [] "call_1" [im "" "image/jpeg", im "é" "image/jpeg"], msg "tool" " \\:😀]" [tc "call_1" "bash" "é", tc "a" "日本" ""] "a" [], msg "" " nbsp" [] "é" [im "file:///tmp/a.png" "image/png", im "é" ""]]
  runCase 43 "L" "x" [msg "" "m{role:4:user;}" [] "😀" [im "" ""], msg "system" "" [] "😀" []]
  runCase 44 "E" "" [msg "é" "tc-end;" [] "a" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" ""], msg "system" "[\"a\"]" [tc "call_1" "日本" "make[3]"] "😀" []]
  runCase 45 "E" "" [msg "é" "m2 ]3\"3}" [tc "call_1" "" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/jpeg"]]
  runCase 46 "L" "sha256:" [msg "user" ":-}" [tc "é" "read_file" "make[3]"] "call_1" [im "data:image/png;base64,AAAA" "image/png"], msg "user" "203];[0" [] "" []]
  runCase 47 "L" "sha256:" [msg "system" "" [] "😀" [], msg "user" "x:3:y;" [tc "😀" "日本" "", tc "call_1" "bash" "make[3]"] "a" []]
  runCase 48 "E" "" [msg "user" "日本語" [] "a" [], msg "assistant" "im-end;" [tc "a" "日本" ""] "call_1" [im "" "image/png"]]
  runCase 49 "E" "" []
  runCase 50 "E" "" [msg "system" "3\\0[3" [] "a" [], msg "system" "𝔘𝔫𝔦" [tc "😀" "bash" "make[3]", tc "é" "" "{\"a\":1}"] "" [im "file:///tmp/a.png" "image/png"], msg "system" "m{role:4:user;}" [] "" [], msg "system" "make[20] and make[2]" [] "é" []]
  runCase 51 "B" "" [msg "user" "日本語" [] "call_1" [], msg "é" "make[21]" [] "😀" [im "data:image/png;base64,AAAA" "", im "é" "image/jpeg"], msg "é" "m{role:4:user;}" [] "call_1" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 52 "L" "m-end;" []
  runCase 53 "B" "" [msg "" ":m};{b[ébb-:" [tc "é" "" "{}"] "call_1" [], msg "user" "á" [tc "a" "日本" "é", tc "" "" "{}"] "call_1" [], msg "system" "ü:2:ü;" [tc "" "" ""] "a" []]
  runCase 54 "L" "sha256:e3b0" []
  runCase 55 "B" "" []
  runCase 56 "L" "sha256:e3b0" [msg "" "make[12]make[3]" [] "😀" [im "é" "image/png"]]
  runCase 57 "E" "" [msg "tool" "}m{" [tc "😀" "bash" "", tc "a" "read_file" ""] "é" [im "file:///tmp/a.png" "image/png", im "é" ""], msg "user" "hi" [] "😀" [], msg "tool" "é" [] "call_1" [im "" "image/jpeg", im "" "image/png"]]
  runCase 58 "B" "" [msg "assistant" ":日m😀日23:\\" [] "a" [], msg "" "ü:2:ü;" [] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""], msg "assistant" "make[12]make[3]" [tc "😀" "read_file" "{}"] "a" []]
  runCase 59 "E" "" [msg "user" "é " [] "" [im "file:///tmp/a.png" "image/jpeg", im "" "image/png"], msg "assistant" "im-end;" [tc "" "bash" "{\"a\":1}"] "a" [im "é" "image/png", im "file:///tmp/a.png" ""]]
