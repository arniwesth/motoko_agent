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
GENERATED by gen_cases.py (seed 2, 400 cases). The Lean half of the differential test:
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
  let ds := chainDigestsOverFixed sha256Hex canonicalMessageFrame b ms
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
  runCase 10 "E" "" []
  runCase 11 "E" "" [msg "user" "make[1make[2]]" [] "😀" []]
  runCase 12 "E" "" [msg "é" "日本語" [tc "😀" "" "make[3]", tc "é" "" "{}"] "" [], msg "tool" "\n}\"}]]" [] "a" []]
  runCase 13 "E" "" [msg "" "\"}日é\n2\\22日" [] "é" [im "data:image/png;base64,AAAA" ""]]
  runCase 14 "B" "" [msg "" "日日2\\\"日😀]1}" [tc "call_1" "日本" ""] "call_1" [im "é" "", im "data:image/png;base64,AAAA" ""], msg "" "𝔘𝔫𝔦" [] "call_1" []]
  runCase 15 "E" "" [msg "system" "á" [] "😀" [], msg "é" "m{role:4:user;}" [] "call_1" [], msg "user" "𝔘𝔫𝔦" [tc "" "bash" "", tc "call_1" "read_file" "{\"a\":1}"] "" []]
  runCase 16 "E" "" []
  runCase 17 "E" "" []
  runCase 18 "E" "" [msg "assistant" "}\na3\\b]{ba2" [tc "" "" ""] "é" []]
  runCase 19 "B" "" [msg "" "3 {😀" [] "" [], msg "system" "éx" [tc "😀" "日本" "é"] "😀" []]
  runCase 20 "E" "" [msg "assistant" "😀" [tc "" "read_file" "{}", tc "call_1" "bash" "{\"a\":1}"] "a" [], msg "system" " nbsp" [tc "" "read_file" "{\"a\":1}", tc "é" "bash" ""] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" ""], msg "é" "" [] "" [im "é" "image/png"], msg "system" "you are motoko" [] "" []]
  runCase 21 "E" "" []
  runCase 22 "E" "" []
  runCase 23 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" " nbsp" [] "é" [im "" "image/jpeg"]]
  runCase 24 "E" "" [msg "" "😀2a\n; 2020" [] "é" [], msg "system" "a日bé-😀日[\\ " [] "" []]
  runCase 25 "E" "" [msg "assistant" "sha256:" [tc "a" "bash" "make[3]"] "call_1" [im "é" "image/png"]]
  runCase 26 "B" "" [msg "system" "tc-end;" [] "é" [], msg "é" "x:3:y;" [] "é" []]
  runCase 27 "B" "" [msg "user" "m{role:4:user;}" [tc "é" "日本" ""] "é" [], msg "user" "😀" [tc "" "bash" "{}", tc "call_1" "read_file" "make[3]"] "a" [im "" "image/png"]]
  runCase 28 "E" "" [msg "assistant" "1日}\n0;{\"é;" [] "😀" []]
  runCase 29 "B" "" [msg "user" "2\\{日日a" [tc "é" "read_file" "é"] "😀" []]
  runCase 30 "L" "sha256:" [msg "assistant" "-😀2\"1:]\" [3" [tc "é" "bash" "", tc "é" "日本" "{\"a\":1}"] "" [], msg "tool" "3[;3\"[m\\\\" [] "é" [im "data:image/png;base64,AAAA" "image/png", im "é" ""]]
  runCase 31 "B" "" [msg "" ":2a😀\":\\😀1日m\n" [tc "" "bash" "make[3]"] "call_1" [], msg "tool" "[\"a\"]" [tc "a" "bash" "{\"a\":1}", tc "é" "日本" "é"] "call_1" []]
  runCase 32 "E" "" [msg "" "hi" [tc "é" "日本" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" ""]]
  runCase 33 "B" "" []
  runCase 34 "B" "" [msg "assistant" "{}" [] "é" [im "" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "" "\n-:0b]日\"]\nmb" [] "" [im "file:///tmp/a.png" "image/png"], msg "assistant" "é" [] "é" [im "file:///tmp/a.png" ""], msg "user" "line\nbreak" [] "call_1" []]
  runCase 35 "E" "" []
  runCase 36 "E" "" [msg "user" "2{" [] "a" [], msg "" "[\"a\"]" [tc "call_1" "" "make[3]", tc "😀" "" "é"] "call_1" [im "" "", im "file:///tmp/a.png" ""]]
  runCase 37 "L" "x" [msg "assistant" " nbsp" [] "call_1" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 38 "E" "" [msg "user" "-éa\"1] 3\"0😀" [tc "a" "" "", tc "a" "日本" "{}"] "a" []]
  runCase 39 "B" "" [msg "user" "make[12]make[3]" [] "a" []]

#eval show IO Unit from do
  runCase 40 "E" "" [msg "assistant" "ü:2:ü;" [] "a" []]
  runCase 41 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "ü:2:ü;" [] "call_1" [im "é" "image/png", im "" ""], msg "tool" "  :\\\n\"😀3" [tc "é" "read_file" "é", tc "é" "日本" "{}"] "" [im "data:image/png;base64,AAAA" "image/png"], msg "é" "日本語" [] "é" [], msg "assistant" "make[1]" [] "a" [im "" ""]]
  runCase 42 "L" "" [msg "tool" "}m{" [] "a" [im "" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" "tab\there" [tc "a" "read_file" ""] "é" [], msg "user" "á" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" ""], msg "" " nbsp" [tc "😀" "read_file" "make[3]", tc "" "read_file" "{\"a\":1}"] "a" [im "data:image/png;base64,AAAA" ""]]
  runCase 43 "B" "" [msg "user" "{}" [] "" [im "" "", im "file:///tmp/a.png" ""], msg "" "é{\"" [tc "" "bash" "make[3]", tc "😀" "read_file" "{\"a\":1}"] "a" [im "" "image/jpeg"]]
  runCase 44 "E" "" [msg "system" "\"b]{ 1b" [tc "a" "bash" "{\"a\":1}", tc "😀" "read_file" "{}"] "é" [], msg "user" "[\"a\"]" [] "😀" [im "" "", im "é" "image/jpeg"], msg "é" "日本" [tc "" "" "{}", tc "a" "日本" ""] "call_1" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 45 "E" "" [msg "user" "á" [] "é" [im "file:///tmp/a.png" "image/jpeg"], msg "user" "sha256:" [tc "😀" "" ""] "" [], msg "assistant" " -\\" [] "call_1" []]
  runCase 46 "B" "" []
  runCase 47 "E" "" [msg "system" "make[12]make[3]" [tc "call_1" "" "é"] "" [im "é" "image/jpeg"], msg "system" "make[20] and make[2]" [] "a" [im "é" "image/jpeg", im "" "image/jpeg"], msg "" "list the files" [tc "é" "read_file" "{\"a\":1}"] "😀" [], msg "user" "\\ 3\né" [] "a" [im "" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 48 "L" "sha256:e3b0" [msg "system" "x:3:y;" [tc "call_1" "read_file" "{\"a\":1}"] "a" [], msg "" "\"ab3é3]\nm" [] "call_1" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/jpeg"]]
  runCase 49 "E" "" [msg "tool" "" [] "é" [], msg "user" "make[21]" [tc "" "read_file" ""] "" [im "" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "é" "tab\there" [] "é" []]
  runCase 50 "B" "" [msg "assistant" "é" [] "😀" [], msg "assistant" "😀0\n " [] "" [], msg "assistant" "é" [tc "😀" "bash" "{}", tc "😀" "日本" "é"] "é" [], msg "user" "im-end;" [tc "call_1" "read_file" "", tc "" "bash" "{\"a\":1}"] "😀" []]
  runCase 51 "L" "" [msg "system" "]\"[" [] "" [im "" "image/jpeg"]]
  runCase 52 "B" "" [msg "é" "m{role:4:user;}" [tc "é" "read_file" "{\"a\":1}"] "é" [], msg "tool" "im-end;" [] "😀" [im "é" "image/jpeg"]]
  runCase 53 "L" "x" [msg "" "am" [tc "a" "read_file" "é", tc "😀" "" "é"] "é" [im "data:image/png;base64,AAAA" ""], msg "tool" "sha256:" [tc "" "日本" "make[3]", tc "" "日本" ""] "" [im "é" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 54 "B" "" [msg "tool" "ü:2:ü;" [tc "é" "read_file" "make[3]"] "😀" []]
  runCase 55 "L" "sha256:" [msg "assistant" "𝔘𝔫𝔦" [] "é" [], msg "tool" "á" [] "é" [im "file:///tmp/a.png" "image/jpeg"], msg "assistant" "𝔘𝔫𝔦" [tc "a" "日本" "é", tc "é" "read_file" "é"] "call_1" [], msg "" "\"quoted\"" [] "call_1" []]
  runCase 56 "L" "é😀" []
  runCase 57 "E" "" [msg "system" "1 13}" [tc "call_1" "bash" "make[3]", tc "😀" "日本" "é"] "😀" [], msg "tool" "é" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 58 "E" "" []
  runCase 59 "B" "" [msg "tool" "" [tc "😀" "read_file" "{\"a\":1}"] "😀" [], msg "user" "\\ 😀日m:" [tc "a" "" "{\"a\":1}"] "call_1" []]
  runCase 60 "E" "" [msg "" "[\\日" [] "é" []]
  runCase 61 "E" "" [msg "user" "\r\n" [tc "call_1" "read_file" "{\"a\":1}", tc "😀" "read_file" "é"] "😀" [], msg "é" "\"quoted\"" [] "" [im "" "", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 62 "E" "" [msg "tool" "é" [] "call_1" []]
  runCase 63 "B" "" [msg "tool" "{日" [tc "" "" "{\"a\":1}", tc "é" "bash" "make[3]"] "call_1" [], msg "system" "list the files" [tc "a" "read_file" "make[3]"] "call_1" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 64 "B" "" [msg "system" "tc-end;" [] "call_1" [], msg "user" "" [] "" []]
  runCase 65 "E" "" [msg "system" " {2{é[0\"aa1" [tc "a" "bash" "make[3]", tc "" "read_file" "é"] "é" []]
  runCase 66 "L" "m-end;" [msg "assistant" "éx" [tc "" "bash" "{}", tc "a" "" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 67 "E" "" [msg "assistant" "é[é-b1é😀-\"" [] "a" [im "" "image/jpeg", im "" "image/png"], msg "é" "sha256:" [tc "a" "" "make[3]", tc "😀" "bash" "{}"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "" "image/jpeg"], msg "assistant" "tab\there" [tc "é" "日本" "{}"] "call_1" [], msg "system" "im-end;" [] "call_1" []]
  runCase 68 "E" "" [msg "tool" "ok" [tc "a" "日本" "{\"a\":1}", tc "" "" "é"] "é" []]
  runCase 69 "E" "" [msg "system" "éa[" [tc "call_1" "read_file" "{\"a\":1}"] "call_1" [], msg "assistant" "0\\é😀" [tc "é" "" "é"] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 70 "L" "é😀" [msg "" "im-end;" [] "call_1" [im "é" "image/jpeg"], msg "system" "😀\n-m}[2;" [tc "a" "read_file" "é", tc "a" "read_file" "make[3]"] "é" []]
  runCase 71 "E" "" [msg "tool" "back\\slash" [] "a" []]
  runCase 72 "E" "" [msg "" "\r\n" [tc "call_1" "read_file" "{\"a\":1}"] "é" [], msg "user" "m\"m m}a-" [tc "é" "bash" "{}"] "é" []]
  runCase 73 "B" "" [msg "é" "á" [] "a" [im "" "image/png"]]
  runCase 74 "B" "" [msg "é" "𝔘𝔫𝔦" [] "" []]
  runCase 75 "E" "" [msg "é" "tab\there" [tc "a" "日本" ""] "" [], msg "system" "\\{aa2[-\\" [tc "é" "日本" "make[3]"] "😀" []]
  runCase 76 "E" "" [msg "system" "á" [tc "😀" "bash" "{\"a\":1}", tc "" "" ""] "" [], msg "é" ";3-}" [tc "" "read_file" "{\"a\":1}"] "a" [im "é" "image/jpeg", im "" "image/jpeg"], msg "assistant" "hi" [] "a" [], msg "" "you are motoko" [tc "a" "read_file" ""] "call_1" []]
  runCase 77 "E" "" [msg "user" "2" [tc "a" "read_file" "{\"a\":1}"] "é" [], msg "system" "x‍😀" [] "call_1" [], msg "" "b0:😀\n{ \\20" [tc "é" "日本" "{}"] "😀" []]
  runCase 78 "E" "" [msg "é" "tc-end;" [] "é" [], msg "user" "m{role:4:user;}" [tc "a" "日本" "{\"a\":1}", tc "" "" ""] "call_1" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 79 "B" "" [msg "assistant" "" [] "" [], msg "assistant" "\r\n" [tc "a" "read_file" "{\"a\":1}"] "" []]

#eval show IO Unit from do
  runCase 80 "E" "" []
  runCase 81 "L" "" [msg "" "m{role:4:user;}" [] "" [], msg "system" ":m\n" [tc "call_1" "bash" "{\"a\":1}"] "😀" []]
  runCase 82 "E" "" [msg "" "á" [] "" [im "é" "image/png"], msg "é" "𝔘𝔫𝔦" [] "call_1" [], msg "user" "sha256:" [] "a" []]
  runCase 83 "E" "" [msg "assistant" "  {1" [tc "a" "read_file" "{\"a\":1}"] "é" [im "" ""], msg "tool" "[\"a\"]" [] "é" []]
  runCase 84 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "é" "make[21]" [tc "é" "bash" "make[3]"] "é" [], msg "system" "𝔘𝔫𝔦" [tc "a" "read_file" "{\"a\":1}"] "" [], msg "assistant" "𝔘𝔫𝔦" [tc "😀" "bash" "{\"a\":1}"] "" []]
  runCase 85 "E" "" []
  runCase 86 "B" "" [msg "user" ":é\" };é0]a" [tc "a" "" "{}", tc "a" "read_file" "é"] "😀" [im "é" "image/png"], msg "system" "-\n[é;日日\n}" [tc "a" "" "make[3]"] "a" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 87 "B" "" [msg "system" "line\nbreak" [tc "call_1" "read_file" "{}"] "😀" [], msg "user" "1b[ b[2ba😀3" [tc "a" "bash" "make[3]"] "é" [], msg "assistant" "you are motoko" [] "call_1" []]
  runCase 88 "L" "m-end;" [msg "assistant" "\"a a " [tc "😀" "bash" "é", tc "é" "日本" "make[3]"] "é" [im "file:///tmp/a.png" "", im "" ""], msg "system" "éx" [tc "call_1" "read_file" "{\"a\":1}"] "" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/png"], msg "system" "{m" [] "é" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 89 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" "á" [tc "a" "bash" ""] "é" [im "" "image/jpeg"], msg "tool" "make[0]" [tc "" "日本" "make[3]"] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" "日本" [tc "" "" "{}", tc "é" "" "é"] "a" [im "file:///tmp/a.png" "image/jpeg"], msg "tool" "make[1]" [] "" []]
  runCase 90 "E" "" [msg "user" "make[20] and make[2]" [tc "call_1" "日本" "make[3]", tc "a" "bash" "{}"] "" []]
  runCase 91 "L" "m-end;" []
  runCase 92 "L" "sha256:" [msg "assistant" "hi" [tc "é" "日本" "", tc "" "read_file" "é"] "a" [im "é" "", im "é" "image/jpeg"]]
  runCase 93 "B" "" [msg "" "make[21]" [tc "é" "" "{\"a\":1}", tc "é" "日本" "{}"] "call_1" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/png"], msg "" "hi" [] "" [], msg "user" "-[-" [] "" [im "file:///tmp/a.png" "image/jpeg", im "é" ""], msg "" ";0\n" [tc "é" "日本" "make[3]"] "call_1" []]
  runCase 94 "E" "" [msg "tool" "\r\n" [tc "é" "read_file" "{\"a\":1}"] "😀" [], msg "" "𝔘𝔫𝔦" [] "call_1" [im "" "image/png"]]
  runCase 95 "B" "" [msg "é" "[\\\\é1\"[m{" [tc "call_1" "read_file" "make[3]", tc "" "bash" "make[3]"] "é" [], msg "" "}m{" [tc "call_1" "read_file" "é", tc "a" "" "é"] "call_1" [], msg "" "m{role:4:user;}" [tc "é" "bash" "é"] "a" []]
  runCase 96 "E" "" [msg "system" "list the files" [] "" [], msg "assistant" "[" [tc "é" "read_file" "é", tc "😀" "read_file" "é"] "a" [], msg "user" "𝔘𝔫𝔦" [tc "a" "read_file" "", tc "é" "" ""] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 97 "E" "" []
  runCase 98 "E" "" [msg "" "éé0" [] "call_1" []]
  runCase 99 "L" "é😀" [msg "é" "make[1make[2]]" [] "😀" [im "" "image/png", im "é" "image/jpeg"], msg "assistant" "\r\n" [tc "é" "bash" "{}"] "é" [im "é" "image/jpeg"], msg "system" "make[21]" [tc "call_1" "日本" "", tc "😀" "" "make[3]"] "call_1" [im "é" "image/jpeg", im "é" ""]]
  runCase 100 "E" "" [msg "" "back\\slash" [] "a" [], msg "system" "á" [tc "😀" "日本" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" "image/png"], msg "system" "make[1]" [tc "call_1" "read_file" "{}"] "" [], msg "user" "make[12]make[3]" [] "a" []]
  runCase 101 "E" "" [msg "é" "ok" [] "" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "\"quoted\"" [tc "" "日本" ""] "é" [im "" "image/png", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 102 "B" "" []
  runCase 103 "L" "sha256:e3b0" [msg "system" "日本語" [] "😀" [im "" "image/png"], msg "tool" "\n\"]{a😀日1 日" [tc "é" "" "{\"a\":1}"] "😀" [im "file:///tmp/a.png" "image/jpeg", im "é" ""]]
  runCase 104 "E" "" []
  runCase 105 "E" "" [msg "tool" "make[1make[2]]" [] "a" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" "image/jpeg"], msg "user" "x‍😀" [] "" [], msg "" "𝔘𝔫𝔦" [] "😀" [], msg "é" "日本" [] "call_1" [im "é" "image/png"]]
  runCase 106 "E" "" [msg "user" "sha256:" [] "a" [im "é" "", im "" ""], msg "assistant" ":" [] "😀" [im "" "image/jpeg"], msg "user" "sha256:" [tc "😀" "bash" "{\"a\":1}"] "😀" [], msg "é" "make[0]" [] "a" []]
  runCase 107 "L" "x" [msg "tool" "m{role:4:user;}" [tc "call_1" "日本" "", tc "call_1" "" "é"] "" [], msg "tool" "sha256:" [tc "é" "read_file" "{\"a\":1}", tc "" "日本" "make[3]"] "call_1" [im "é" "image/png", im "é" "image/jpeg"]]
  runCase 108 "E" "" [msg "user" "\r\n" [tc "é" "bash" "{\"a\":1}", tc "😀" "read_file" "make[3]"] "" []]
  runCase 109 "E" "" [msg "" "[\"a\"]" [] "é" []]
  runCase 110 "E" "" [msg "system" "" [] "😀" [], msg "" "sha256:" [tc "" "" "make[3]", tc "call_1" "read_file" ""] "" []]
  runCase 111 "B" "" [msg "system" "á" [] "é" [], msg "é" "1}日1 0 " [] "call_1" []]
  runCase 112 "L" "sha256:" []
  runCase 113 "B" "" [msg "assistant" "\"0}:{0" [tc "é" "" "make[3]"] "é" [], msg "" "ü:2:ü;" [tc "call_1" "bash" "make[3]"] "😀" [], msg "assistant" " ; é--ba" [tc "é" "read_file" ""] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 114 "L" "sha256:" [msg "tool" "line\nbreak" [tc "é" "read_file" "é", tc "a" "日本" "make[3]"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"]]
  runCase 115 "E" "" [msg "" "tab\there" [tc "call_1" "bash" "é"] "é" [], msg "system" "[\"a\"]" [tc "call_1" "" "{}", tc "" "" "{}"] "call_1" []]
  runCase 116 "L" "m-end;" [msg "tool" "b-\n😀\\日}[é" [tc "😀" "bash" "{}"] "" [im "file:///tmp/a.png" ""], msg "assistant" "}m{" [tc "é" "bash" "{}", tc "a" "bash" "é"] "" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "" " nbsp" [tc "call_1" "日本" "make[3]", tc "é" "日本" ""] "" [], msg "system" "" [] "😀" [im "é" "", im "é" ""]]
  runCase 117 "E" "" [msg "user" "hi" [tc "é" "read_file" "é"] "😀" [], msg "" "m{role:4:user;}" [] "call_1" [im "" "", im "" "image/png"], msg "user" "make[0]" [tc "" "bash" "make[3]"] "call_1" []]
  runCase 118 "L" "é😀" [msg "é" "make[1make[2]]" [tc "a" "read_file" "é"] "call_1" [im "" "", im "" ""]]
  runCase 119 "B" "" [msg "assistant" "2m[-\\3}0日-" [] "" [im "é" "image/png"], msg "é" "}m{" [tc "" "read_file" ""] "😀" []]

#eval show IO Unit from do
  runCase 120 "E" "" [msg "system" "" [] "a" [im "" "", im "file:///tmp/a.png" "image/png"], msg "system" "ém]" [tc "é" "bash" "{\"a\":1}"] "call_1" [], msg "assistant" "[}3😀m}33][;\"" [tc "é" "bash" "{}"] "" []]
  runCase 121 "L" "x" [msg "user" "hi" [] "" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" ""], msg "user" "tc-end;" [tc "😀" "日本" "{\"a\":1}"] "é" [], msg "system" "\r\n" [tc "" "" "{\"a\":1}"] "" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/png"]]
  runCase 122 "E" "" [msg "" "{\n13\\" [] "a" [], msg "é" "]3m" [] "a" [im "file:///tmp/a.png" "image/png"], msg "assistant" "make[0]" [] "é" [], msg "assistant" "tab\there" [tc "call_1" "" "make[3]", tc "é" "bash" "make[3]"] "é" []]
  runCase 123 "E" "" [msg "tool" "m{role:4:user;}" [] "😀" [], msg "assistant" "im-end;" [tc "😀" "bash" "é", tc "a" "read_file" "{\"a\":1}"] "é" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 124 "E" "" [msg "tool" ":日}é]\"1é-" [tc "é" "read_file" ""] "é" [im "" "", im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "make[21]" [] "" [im "file:///tmp/a.png" "image/png"], msg "assistant" " }{;\n[]\n\\]日" [] "😀" [im "file:///tmp/a.png" "image/png", im "" "image/png"]]
  runCase 125 "B" "" [msg "assistant" "é" [tc "é" "read_file" "make[3]"] "a" [], msg "tool" " nbsp" [tc "call_1" "read_file" "make[3]"] "é" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 126 "B" "" [msg "assistant" "ü:2:ü;" [] "" [im "é" ""], msg "system" "日本語" [] "😀" []]
  runCase 127 "E" "" [msg "é" "𝔘𝔫𝔦" [tc "é" "bash" "{\"a\":1}"] "a" [], msg "system" "]]" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/png"]]
  runCase 128 "E" "" [msg "tool" "make[21]" [] "call_1" [im "" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "user" "}m{" [tc "a" "read_file" ""] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "sha256:" [] "call_1" []]
  runCase 129 "L" "sha256:" [msg "tool" " nbsp" [] "a" []]
  runCase 130 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "x:3:y;" [tc "" "日本" "make[3]"] "a" [], msg "user" "list the files" [tc "a" "日本" ""] "a" [im "file:///tmp/a.png" ""]]
  runCase 131 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "a103:😀日" [] "a" []]
  runCase 132 "E" "" [msg "user" "][\n" [] "😀" [im "é" "image/jpeg"], msg "é" "{}" [] "" []]
  runCase 133 "B" "" []
  runCase 134 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "é" "á" [tc "😀" "" ""] "a" [im "é" "image/png"]]
  runCase 135 "E" "" [msg "assistant" "𝔘𝔫𝔦" [] "😀" [im "" "image/png", im "file:///tmp/a.png" ""], msg "tool" "𝔘𝔫𝔦" [] "a" []]
  runCase 136 "E" "" [msg "é" "日本語" [tc "😀" "" "é", tc "a" "bash" "make[3]"] "😀" []]
  runCase 137 "B" "" [msg "" "make[12]make[3]" [tc "call_1" "bash" "é"] "call_1" [], msg "system" "make[1]" [] "😀" [], msg "é" "line\nbreak" [tc "" "" "é", tc "😀" "" "{}"] "call_1" [], msg "é" " nbsp" [] "é" []]
  runCase 138 "L" "" [msg "tool" "\r\n" [] "a" [], msg "system" "[\"a\"]" [tc "call_1" "read_file" "é"] "call_1" []]
  runCase 139 "B" "" []
  runCase 140 "B" "" [msg "é" "0éa]:0" [tc "😀" "bash" "", tc "é" "日本" "é"] "é" []]
  runCase 141 "B" "" [msg "assistant" "tab\there" [] "" [], msg "é" "x:3:y;" [] "😀" [], msg "system" " nbsp" [tc "a" "read_file" "{}", tc "a" "bash" "{\"a\":1}"] "" [], msg "" "make[1make[2]]" [] "" []]
  runCase 142 "L" "sha256:e3b0" [msg "assistant" "};b😀{😀\\03😀;]" [tc "call_1" "bash" ""] "call_1" [im "" "image/png"], msg "tool" "éx" [tc "é" "日本" "{}"] "a" [], msg "system" "sha256:" [tc "" "" "make[3]", tc "é" "" "{\"a\":1}"] "é" [], msg "user" "}m{" [tc "😀" "bash" "{\"a\":1}"] "" []]
  runCase 143 "B" "" [msg "system" "\"\\aam :\n]" [tc "é" "" "{\"a\":1}", tc "a" "日本" "é"] "" [im "" "image/png"], msg "assistant" "\"quoted\"" [] "a" [], msg "user" "éx" [tc "😀" "日本" "{\"a\":1}"] "😀" [], msg "user" "é\"[" [] "a" []]
  runCase 144 "B" "" [msg "assistant" ";{m;13" [tc "é" "" "{}"] "call_1" [], msg "system" " \"😀-3" [tc "é" "bash" "make[3]"] "😀" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" " nbsp" [tc "é" "read_file" "{\"a\":1}", tc "call_1" "" "make[3]"] "😀" [], msg "" "日本" [] "a" []]
  runCase 145 "B" "" [msg "user" "é :\nm\\éé0 2" [tc "call_1" "" "é"] "é" [im "é" "image/png"], msg "system" "hi" [tc "" "日本" "{\"a\":1}"] "a" [], msg "user" "á" [] "" []]
  runCase 146 "E" "" [msg "system" "{}" [tc "😀" "日本" "é"] "😀" [], msg "tool" "im-end;" [tc "é" "bash" ""] "😀" []]
  runCase 147 "E" "" [msg "tool" "x‍😀" [] "é" [im "" "", im "é" "image/jpeg"], msg "assistant" "line\nbreak" [] "a" []]
  runCase 148 "E" "" []
  runCase 149 "L" "x" []
  runCase 150 "B" "" [msg "é" "\"quoted\"" [tc "😀" "read_file" "{\"a\":1}", tc "" "日本" "{}"] "" [], msg "tool" "make[0]" [tc "call_1" "read_file" ""] "a" []]
  runCase 151 "E" "" [msg "é" "x:3:y;" [] "" []]
  runCase 152 "E" "" [msg "tool" "you are motoko" [] "😀" [im "file:///tmp/a.png" "image/jpeg"], msg "tool" "make[20] and make[2]" [] "" []]
  runCase 153 "L" "sha256:" [msg "system" "back\\slash" [tc "😀" "日本" "é"] "" [], msg "system" "ok" [] "😀" [], msg "tool" "22\\-1}😀" [] "call_1" [im "" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 154 "E" "" [msg "system" "日本語" [tc "" "read_file" "{\"a\":1}", tc "call_1" "bash" "{}"] "é" [], msg "user" "sha256:" [tc "call_1" "bash" "make[3]"] "a" [im "" "image/jpeg"], msg "tool" "}\"{a3}0" [] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 155 "B" "" [msg "assistant" "back\\slash" [] "😀" [], msg "é" "ü:2:ü;" [tc "call_1" "" "{}", tc "a" "bash" "{\"a\":1}"] "" []]
  runCase 156 "E" "" [msg "tool" "{}" [] "" []]
  runCase 157 "E" "" [msg "user" "im-end;" [tc "😀" "日本" ""] "😀" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""]]
  runCase 158 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "é" [tc "" "日本" "make[3]"] "" [], msg "" "m{role:4:user;}" [] "😀" []]
  runCase 159 "E" "" [msg "assistant" "á" [tc "call_1" "日本" "é"] "call_1" [im "" "", im "data:image/png;base64,AAAA" ""], msg "tool" "]\"} \\a]éém" [] "" []]

#eval show IO Unit from do
  runCase 160 "L" "x" [msg "user" "0m-\"12\n1:" [tc "call_1" "日本" "make[3]"] "call_1" [im "" "image/png"]]
  runCase 161 "E" "" [msg "é" "éx" [] "call_1" []]
  runCase 162 "B" "" [msg "" "á" [] "a" [im "é" "image/jpeg"], msg "system" "\"quoted\"" [] "a" [], msg "tool" "á" [tc "" "bash" "{}"] "" []]
  runCase 163 "B" "" [msg "user" "" [] "😀" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/png"], msg "" "make[1make[2]]" [] "call_1" []]
  runCase 164 "E" "" [msg "system" "tc-end;" [] "é" [im "" "image/png"]]
  runCase 165 "L" "sha256:" [msg "system" "tc-end;" [tc "😀" "read_file" "{\"a\":1}"] "a" [], msg "é" "m11[日mm日[3" [] "" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"]]
  runCase 166 "E" "" [msg "assistant" " nbsp" [] "call_1" [im "é" "image/jpeg", im "" "image/png"], msg "assistant" "[\"a\"]" [] "" []]
  runCase 167 "E" "" [msg "tool" "á" [tc "" "" "é"] "call_1" [], msg "tool" "}m{" [] "" [], msg "system" "ü:2:ü;" [] "😀" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""]]
  runCase 168 "B" "" [msg "tool" "3[-日\"-2" [] "é" []]
  runCase 169 "E" "" []
  runCase 170 "L" "é😀" [msg "assistant" "\"quoted\"" [] "" [], msg "é" "x:3:y;" [] "é" [], msg "assistant" "make[20] and make[2]" [tc "call_1" "" "{\"a\":1}"] "é" [], msg "assistant" "make[20] and make[2]" [tc "" "日本" "{\"a\":1}", tc "a" "" "é"] "" [im "é" "image/png"]]
  runCase 171 "L" "sha256:e3b0" [msg "" "b\"\n[;bb😀[" [] "call_1" []]
  runCase 172 "E" "" [msg "assistant" "[\"a\"]" [tc "" "日本" "{}"] "é" [im "é" "", im "é" ""], msg "é" "日本" [] "a" []]
  runCase 173 "E" "" [msg "system" "x‍😀" [tc "a" "bash" "é"] "call_1" []]
  runCase 174 "B" "" [msg "é" "}m{" [tc "call_1" "read_file" "{}", tc "" "read_file" "é"] "call_1" []]
  runCase 175 "E" "" [msg "assistant" "" [tc "é" "read_file" "make[3]", tc "é" "read_file" "{\"a\":1}"] "a" [im "" ""], msg "system" "0日\n0:😀 -\n" [tc "é" "日本" "{\"a\":1}", tc "call_1" "bash" "{}"] "a" [im "" "image/png", im "é" ""], msg "assistant" "0;{11bb}" [] "call_1" [], msg "é" "sha256:" [tc "" "read_file" "{\"a\":1}"] "call_1" []]
  runCase 176 "L" "m-end;" [msg "system" "im-end;" [] "a" [im "é" "image/png"]]
  runCase 177 "B" "" [msg "user" "b\\日😀\"" [tc "call_1" "日本" "é"] "call_1" [], msg "tool" "á" [] "" [], msg "é" " nbsp" [tc "" "bash" ""] "é" []]
  runCase 178 "L" "sha256:e3b0" [msg "tool" "hi" [] "call_1" [], msg "user" "make[1]" [] "call_1" [im "file:///tmp/a.png" "image/png", im "é" "image/jpeg"], msg "user" "b\"2\\\"日bb{\\1" [] "a" [im "" "", im "é" "image/jpeg"], msg "assistant" "tab\there" [tc "a" "" "{}"] "é" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 179 "L" "x" [msg "" "make[0]" [] "a" [], msg "assistant" "\"quoted\"" [tc "é" "read_file" "{\"a\":1}", tc "" "" "{\"a\":1}"] "" [im "é" ""], msg "system" "" [tc "call_1" "read_file" ""] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""], msg "assistant" "}m{" [] "é" [im "" ""]]
  runCase 180 "L" "x" [msg "system" "éx" [] "é" [], msg "tool" "á" [tc "" "" ""] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""], msg "user" "hi" [] "😀" [im "é" "image/jpeg"]]
  runCase 181 "B" "" [msg "assistant" "sha256:" [] "" [], msg "é" "日本語" [tc "é" "bash" "", tc "call_1" "bash" "é"] "é" [im "data:image/png;base64,AAAA" ""]]
  runCase 182 "E" "" [msg "tool" "make[21]" [tc "é" "read_file" "make[3]"] "é" [], msg "tool" "3日日-0😀a" [] "a" [], msg "user" "x:3:y;" [] "" [], msg "assistant" "a3b0 3\"" [] "call_1" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 183 "L" "" [msg "é" "\n3\\;2;\n\n\n;\"" [tc "é" "" "{}", tc "" "日本" "{}"] "call_1" [im "file:///tmp/a.png" ""], msg "é" "" [] "é" [], msg "tool" "{}" [tc "😀" "日本" "make[3]"] "" [im "file:///tmp/a.png" ""]]
  runCase 184 "B" "" [msg "tool" "mb{\"😀😀\"2]:ma" [] "é" [], msg "tool" "abm10a" [] "é" []]
  runCase 185 "L" "é😀" [msg "user" "" [tc "call_1" "read_file" "{}"] "a" [], msg "user" "[{a\nmm" [] "😀" [im "é" ""], msg "" "you are motoko" [] "call_1" [], msg "user" " nbsp" [] "é" []]
  runCase 186 "E" "" [msg "system" "é" [] "call_1" [], msg "é" "{m;[ 日\n\"\"\\a" [] "" []]
  runCase 187 "E" "" [msg "assistant" "日本" [] "a" [im "data:image/png;base64,AAAA" ""], msg "é" "[\"a\"]" [] "😀" []]
  runCase 188 "E" "" [msg "system" "[\"a\"]" [] "call_1" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/png"], msg "tool" "make[1make[2]]" [] "call_1" [im "é" "", im "é" "image/jpeg"]]
  runCase 189 "E" "" [msg "assistant" "{b😀é\\{m\n}]31" [] "" [im "" "image/png", im "é" "image/png"], msg "" "m" [] "😀" []]
  runCase 190 "E" "" [msg "tool" "{}" [] "" [], msg "system" "日本語" [] "call_1" [im "file:///tmp/a.png" ""]]
  runCase 191 "E" "" [msg "user" "" [] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 192 "E" "" []
  runCase 193 "E" "" [msg "tool" "tc-end;" [] "😀" [], msg "é" "" [] "call_1" [im "é" "image/png"], msg "user" "make[1make[2]]" [] "a" [im "file:///tmp/a.png" "image/png"], msg "user" "é" [tc "é" "bash" "make[3]"] "é" []]
  runCase 194 "E" "" [msg "" "make[12]make[3]" [tc "" "read_file" "make[3]", tc "é" "日本" "é"] "a" [], msg "system" "make[0]" [tc "" "日本" "{\"a\":1}"] "call_1" [], msg "user" "33" [] "é" [], msg "system" "ü:2:ü;" [tc "é" "bash" ""] "call_1" []]
  runCase 195 "E" "" [msg "assistant" "make[0]" [tc "" "" "make[3]", tc "call_1" "日本" "{\"a\":1}"] "call_1" [im "é" "", im "" "image/jpeg"]]
  runCase 196 "B" "" [msg "é" "-m[; \"" [] "call_1" [], msg "system" "" [tc "a" "日本" "", tc "a" "read_file" "{\"a\":1}"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"], msg "tool" "hi" [tc "a" "日本" "{\"a\":1}"] "é" [], msg "é" "日本語" [] "call_1" []]
  runCase 197 "B" "" [msg "tool" "hi" [] "é" [], msg "" "back\\slash" [tc "" "" "é"] "😀" []]
  runCase 198 "L" "x" [msg "system" "é" [tc "😀" "read_file" "{}"] "call_1" []]
  runCase 199 "E" "" []

#eval show IO Unit from do
  runCase 200 "E" "" [msg "assistant" "}m{" [tc "é" "bash" "{\"a\":1}"] "a" [im "" ""], msg "" "make[12]make[3]" [tc "a" "日本" "{\"a\":1}"] "é" []]
  runCase 201 "E" "" []
  runCase 202 "E" "" [msg "assistant" "]ba[{ " [tc "a" "" "{}", tc "😀" "日本" "make[3]"] "é" [], msg "assistant" "x:3:y;" [] "call_1" []]
  runCase 203 "E" "" [msg "" "mé😀]\"03a" [] "😀" [im "é" "image/png", im "file:///tmp/a.png" "image/png"], msg "user" "}m{" [] "" []]
  runCase 204 "E" "" [msg "user" "][\\\":" [] "call_1" [], msg "é" "tc-end;" [] "é" [im "é" "image/png", im "" ""], msg "assistant" "日2" [tc "é" "" "é"] "😀" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 205 "L" "m-end;" [msg "" "\"quoted\"" [tc "call_1" "日本" "é"] "é" [im "" ""], msg "system" "日本" [tc "" "" "make[3]", tc "é" "read_file" "make[3]"] "a" [], msg "assistant" "á" [] "call_1" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 206 "E" "" [msg "tool" "ü:2:ü;" [] "" [], msg "assistant" "m{role:4:user;}" [tc "😀" "" "make[3]"] "é" []]
  runCase 207 "B" "" [msg "" "x:3:y;" [] "é" [], msg "assistant" "back\\slash" [] "😀" []]
  runCase 208 "E" "" []
  runCase 209 "B" "" [msg "é" "3;-" [tc "a" "日本" "é"] "" []]
  runCase 210 "E" "" [msg "assistant" "" [] "a" [], msg "system" "x:3:y;" [] "" [], msg "system" "\r\n" [tc "call_1" "read_file" "make[3]"] "call_1" [im "file:///tmp/a.png" "image/png"]]
  runCase 211 "E" "" [msg "é" "make[1]" [tc "é" "日本" ""] "" [im "file:///tmp/a.png" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 212 "E" "" [msg "" "" [tc "😀" "日本" "{\"a\":1}", tc "é" "日本" "make[3]"] "" [im "file:///tmp/a.png" ""], msg "tool" "line\nbreak" [] "😀" [], msg "tool" "back\\slash" [tc "a" "bash" "{}"] "😀" [], msg "" "}m{" [] "call_1" []]
  runCase 213 "B" "" [msg "user" "back\\slash" [] "" [], msg "" ";;日" [tc "😀" "" "", tc "call_1" "read_file" "{}"] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 214 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" "make[12]make[3]" [] "call_1" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 215 "B" "" [msg "assistant" "𝔘𝔫𝔦" [] "call_1" []]
  runCase 216 "E" "" [msg "tool" "line\nbreak" [tc "call_1" "日本" "é"] "a" [im "é" "image/png", im "file:///tmp/a.png" "image/png"], msg "user" "" [] "a" [], msg "system" "make[0]" [tc "call_1" "" "{}"] "call_1" []]
  runCase 217 "L" "sha256:e3b0" [msg "é" "make[0]" [] "a" [im "file:///tmp/a.png" "image/png"]]
  runCase 218 "L" "sha256:e3b0" []
  runCase 219 "L" "é😀" [msg "tool" "sha256:" [tc "😀" "" "é", tc "a" "" ""] "a" [], msg "é" "line\nbreak" [tc "é" "日本" "make[3]", tc "call_1" "" "{}"] "a" []]
  runCase 220 "E" "" [msg "é" "x:3:y;" [tc "a" "" "é"] "" [im "" ""]]
  runCase 221 "E" "" []
  runCase 222 "B" "" []
  runCase 223 "L" "m-end;" [msg "system" "😀" [tc "" "bash" "é"] "é" [im "" ""], msg "assistant" "x:3:y;" [tc "a" "" "{}"] "call_1" []]
  runCase 224 "E" "" [msg "" "m{role:4:user;}" [] "é" [im "" "image/png", im "file:///tmp/a.png" "image/jpeg"], msg "user" "m{role:4:user;}" [tc "" "bash" "make[3]"] "" [], msg "é" "\n\"1" [tc "" "read_file" "{\"a\":1}", tc "" "" "{}"] "" [im "file:///tmp/a.png" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 225 "L" "x" [msg "assistant" "x‍😀" [tc "😀" "日本" "{\"a\":1}"] "a" [], msg "" "{}" [tc "call_1" "bash" "make[3]"] "" [], msg "system" "line\nbreak" [] "a" [], msg "user" "1{\"{😀-😀😀[3" [] "a" []]
  runCase 226 "B" "" [msg "assistant" "tab\there" [tc "é" "日本" "{\"a\":1}"] "call_1" []]
  runCase 227 "E" "" [msg "assistant" "back\\slash" [] "" []]
  runCase 228 "E" "" [msg "assistant" "á" [tc "a" "read_file" "{}"] "é" [], msg "assistant" "\"quoted\"" [tc "call_1" "日本" "é", tc "" "read_file" "é"] "é" []]
  runCase 229 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "é" "😀b1b[}1;2😀0{" [] "" []]
  runCase 230 "B" "" [msg "assistant" "\r\n" [tc "a" "bash" "make[3]", tc "a" "" "make[3]"] "" []]
  runCase 231 "E" "" [msg "system" "\"quoted\"" [tc "😀" "bash" "{\"a\":1}", tc "call_1" "bash" "{\"a\":1}"] "é" [], msg "" " 330" [tc "😀" "日本" ""] "a" []]
  runCase 232 "L" "é😀" [msg "user" "日本語" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "" ""], msg "" "ok" [tc "😀" "" "é"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "" ""], msg "user" "make[21]" [] "" [], msg "assistant" "make[21]" [] "" []]
  runCase 233 "E" "" [msg "user" "2\"日2b{:;" [tc "a" "日本" "{}"] "" [im "é" "image/png"], msg "user" "-1;a;日a-m😀" [tc "a" "" "{\"a\":1}", tc "é" "read_file" "{}"] "" []]
  runCase 234 "E" "" []
  runCase 235 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "}😀bm\"é{-0" [tc "é" "" "{}"] "" [], msg "é" "日本語" [] "call_1" []]
  runCase 236 "E" "" [msg "system" "im-end;" [] "call_1" [], msg "tool" " nbsp" [tc "😀" "read_file" "{}"] "😀" [], msg "system" "{0" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/png"], msg "system" "\r\n" [] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 237 "E" "" [msg "é" "make[1make[2]]" [tc "😀" "bash" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "list the files" [] "a" [im "file:///tmp/a.png" "image/png"]]
  runCase 238 "B" "" [msg "assistant" "list the files" [tc "" "read_file" ""] "é" []]
  runCase 239 "B" "" [msg "assistant" "make[1]" [tc "😀" "bash" ""] "call_1" [im "" "image/jpeg", im "file:///tmp/a.png" "image/png"]]

#eval show IO Unit from do
  runCase 240 "L" "sha256:e3b0" [msg "" "line\nbreak" [] "😀" []]
  runCase 241 "B" "" []
  runCase 242 "E" "" [msg "assistant" "]21\"}:a" [tc "a" "bash" "make[3]", tc "é" "日本" "{}"] "😀" [], msg "" "line\nbreak" [] "" [], msg "" "x:3:y;" [] "é" [], msg "assistant" "you are motoko" [] "a" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 243 "E" "" [msg "user" "tc-end;" [tc "a" "日本" "{}"] "a" [im "é" ""], msg "user" "line\nbreak" [] "" [], msg "system" "x:3:y;" [tc "" "bash" ""] "" [im "file:///tmp/a.png" ""], msg "user" "sha256:" [] "😀" [im "é" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 244 "B" "" [msg "assistant" "; ;b1\n;" [tc "" "bash" "{\"a\":1}"] "é" [im "" "image/png"], msg "system" "make[1]" [tc "é" "日本" "é"] "é" [], msg "system" "make[1]" [] "é" []]
  runCase 245 "E" "" [msg "" "tab\there" [] "" [im "é" ""], msg "tool" "you are motoko" [tc "" "日本" "é"] "call_1" [im "file:///tmp/a.png" "image/jpeg"], msg "" " ]-2-" [tc "call_1" "日本" "é", tc "call_1" "read_file" "{}"] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""]]
  runCase 246 "E" "" [msg "tool" "" [] "😀" [], msg "é" "back\\slash" [tc "a" "日本" "make[3]"] "" []]
  runCase 247 "B" "" [msg "é" "list the files" [tc "call_1" "" "make[3]", tc "call_1" "" "é"] "😀" []]
  runCase 248 "B" "" [msg "tool" "tc-end;" [] "" []]
  runCase 249 "L" "sha256:e3b0" [msg "é" "make[0]" [] "a" [], msg "user" "make[20] and make[2]" [tc "😀" "read_file" "é"] "a" []]
  runCase 250 "B" "" [msg "assistant" "[\"a\"]" [tc "a" "read_file" "make[3]"] "é" [], msg "system" "m{role:4:user;}" [tc "a" "bash" ""] "call_1" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/png"], msg "é" "hi" [tc "a" "" "é", tc "a" "" "make[3]"] "😀" [], msg "" "[3:3" [] "a" [im "é" "image/jpeg", im "é" ""]]
  runCase 251 "B" "" [msg "" "-" [] "a" [im "file:///tmp/a.png" ""], msg "system" "[\"a\"]" [] "😀" [], msg "user" "" [] "" [], msg "tool" "make[12]make[3]" [tc "😀" "bash" "{\"a\":1}"] "" []]
  runCase 252 "B" "" [msg "tool" "日😀\\[" [tc "" "read_file" "é"] "😀" [], msg "system" "ok" [tc "" "日本" "é"] "é" [im "é" "", im "" "image/png"], msg "é" "[3}]\"日" [] "😀" []]
  runCase 253 "L" "x" [msg "system" "😀" [tc "a" "日本" "{\"a\":1}"] "é" []]
  runCase 254 "E" "" [msg "é" "-[0\\3 -é日" [] "é" [im "data:image/png;base64,AAAA" "", im "" ""], msg "system" "im-end;" [tc "é" "read_file" "", tc "" "" "make[3]"] "a" [im "é" "", im "file:///tmp/a.png" "image/jpeg"], msg "é" "a}]-{]m\"" [] "call_1" [], msg "system" " a0😀😀:\"0]😀:" [tc "call_1" "日本" "{}", tc "a" "bash" ""] "call_1" [im "é" ""]]
  runCase 255 "E" "" [msg "" "\n日3:}0a}\n2é" [tc "😀" "bash" "{}"] "😀" [], msg "é" "ü:2:ü;" [] "😀" [im "é" "image/jpeg"]]
  runCase 256 "E" "" [msg "system" "im-end;" [tc "" "read_file" "{}"] "call_1" [im "data:image/png;base64,AAAA" "", im "" "image/png"]]
  runCase 257 "B" "" [msg "system" "[20{:-aé}a" [] "call_1" [], msg "tool" "\\2b:😀-b日[:[;" [tc "" "bash" "", tc "a" "日本" "é"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "é" ""], msg "é" "back\\slash" [tc "call_1" "" "", tc "a" "read_file" ""] "a" []]
  runCase 258 "B" "" [msg "assistant" "a:\n" [] "a" [], msg "tool" "é" [tc "é" "read_file" "make[3]"] "😀" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""]]
  runCase 259 "E" "" [msg "assistant" "make[0]" [tc "😀" "read_file" "{\"a\":1}", tc "é" "read_file" "é"] "" [im "" "image/jpeg", im "file:///tmp/a.png" ""], msg "tool" " nbsp" [] "é" [], msg "assistant" "make[1]" [tc "a" "" "é"] "call_1" [im "" "image/png", im "" "image/png"]]
  runCase 260 "E" "" [msg "user" "\r\n" [] "a" []]
  runCase 261 "L" "é😀" [msg "system" "[\"a\"]" [tc "😀" "read_file" "make[3]"] "é" []]
  runCase 262 "L" "sha256:" []
  runCase 263 "E" "" [msg "system" "" [tc "a" "" "{}"] "é" [], msg "system" "日 日é" [tc "a" "" "é"] "" [im "" "", im "é" "image/jpeg"], msg "" "line\nbreak" [] "" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 264 "E" "" [msg "user" "m{role:4:user;}" [] "" [], msg "system" "list the files" [tc "" "" ""] "call_1" [], msg "system" "éx" [tc "" "bash" ""] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 265 "E" "" [msg "assistant" "im-end;" [] "call_1" [], msg "é" "; [1  mb2a{😀" [tc "😀" "日本" "make[3]", tc "call_1" "日本" "{\"a\":1}"] "" [im "file:///tmp/a.png" ""]]
  runCase 266 "B" "" [msg "user" "x‍😀" [tc "é" "bash" ""] "é" [], msg "tool" "make[20] and make[2]" [tc "call_1" "日本" "é"] "" [], msg "tool" "á" [] "é" [], msg "é" "line\nbreak" [] "call_1" []]
  runCase 267 "B" "" []
  runCase 268 "B" "" [msg "" "sha256:" [tc "" "" "{}"] "a" [], msg "tool" "make[1]" [tc "a" "read_file" ""] "😀" [], msg "system" ":\nm2" [] "" [im "" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "éx" [tc "" "日本" "é"] "é" []]
  runCase 269 "E" "" []
  runCase 270 "B" "" [msg "é" "make[12]make[3]" [tc "😀" "日本" "é"] "a" [], msg "" " nbsp" [] "a" [], msg "user" "" [tc "😀" "bash" "{}", tc "" "bash" "{\"a\":1}"] "😀" [im "é" "image/jpeg"], msg "system" "1- é[[b1]m \"" [tc "é" "bash" "{}"] "" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 271 "E" "" [msg "tool" " 3é :" [tc "é" "日本" ""] "call_1" []]
  runCase 272 "E" "" [msg "system" " nbsp" [tc "call_1" "日本" "{\"a\":1}"] "a" [], msg "" "á" [tc "a" "bash" ""] "é" []]
  runCase 273 "E" "" [msg "user" "😀1\\33]" [] "" []]
  runCase 274 "B" "" [msg "é" "{\"\\{日:m:3033" [tc "a" "bash" "é"] "😀" [im "" "image/png", im "é" ""], msg "assistant" "tab\there" [] "" [im "é" "image/jpeg", im "file:///tmp/a.png" ""]]
  runCase 275 "E" "" [msg "assistant" "tc-end;" [tc "call_1" "日本" "é", tc "" "" "{\"a\":1}"] "call_1" [], msg "assistant" "make[21]" [] "" [], msg "tool" "line\nbreak" [tc "😀" "read_file" ""] "a" [im "é" ""]]
  runCase 276 "L" "" [msg "user" "make[1]" [tc "é" "日本" "", tc "😀" "read_file" "make[3]"] "call_1" [im "" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "user" "1😀33ba1" [] "a" []]
  runCase 277 "L" "sha256:" [msg "" "\r\n" [] "call_1" [im "" "image/jpeg", im "" ""], msg "tool" "you are motoko" [tc "a" "" ""] "a" []]
  runCase 278 "B" "" [msg "" "𝔘𝔫𝔦" [] "a" [im "é" "", im "é" "image/jpeg"]]
  runCase 279 "L" "" [msg "system" " 😀:" [] "" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" "image/png"]]

#eval show IO Unit from do
  runCase 280 "E" "" [msg "" "😀m😀😀" [tc "é" "bash" "{}", tc "a" "日本" "é"] "a" []]
  runCase 281 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "you are motoko" [] "é" [im "data:image/png;base64,AAAA" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 282 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" "a m 0\\" [tc "é" "bash" "{}", tc "a" "" "é"] "call_1" []]
  runCase 283 "B" "" [msg "system" "\"1b😀]][{é}]3" [tc "a" "read_file" ""] "😀" []]
  runCase 284 "E" "" [msg "tool" "make[0]" [tc "" "bash" "{\"a\":1}"] "call_1" [], msg "é" "日本" [] "a" []]
  runCase 285 "L" "m-end;" [msg "assistant" " m]2[]\né3;" [tc "😀" "" "é"] "a" [im "" ""], msg "tool" " \\}1\";a1-" [] "call_1" [], msg "system" "\n-😀0" [tc "" "" "{}"] "😀" [im "é" ""]]
  runCase 286 "E" "" [msg "" "日本" [tc "a" "" "make[3]"] "a" [im "data:image/png;base64,AAAA" "image/png"], msg "é" "" [] "😀" [], msg "user" "make[21]" [tc "a" "read_file" "é", tc "a" "read_file" ""] "" []]
  runCase 287 "E" "" [msg "tool" " 1" [] "" []]
  runCase 288 "E" "" [msg "" "á" [] "😀" []]
  runCase 289 "B" "" []
  runCase 290 "E" "" [msg "é" "日本" [] "call_1" [], msg "tool" "b日{}ab\"a[\\2b" [] "😀" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 291 "E" "" [msg "assistant" " nbsp" [tc "" "" "{\"a\":1}"] "" [], msg "user" "line\nbreak" [] "é" [], msg "user" "𝔘𝔫𝔦" [tc "call_1" "日本" "make[3]", tc "é" "bash" ""] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" ""], msg "system" "日本" [] "a" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 292 "B" "" [msg "assistant" "make[20] and make[2]" [] "call_1" [im "data:image/png;base64,AAAA" "", im "é" "image/png"], msg "é" "x:3:y;" [tc "a" "bash" ""] "é" []]
  runCase 293 "L" "sha256:e3b0" [msg "assistant" "b:1 日a23b{{\"" [] "a" []]
  runCase 294 "E" "" []
  runCase 295 "B" "" [msg "é" "a\n{日1;é[\n:" [tc "😀" "" "", tc "call_1" "日本" "{}"] "é" []]
  runCase 296 "L" "" [msg "user" "b😀{:é}2b" [] "call_1" []]
  runCase 297 "B" "" [msg "é" "m:\\ 😀-日\" \\\nm" [tc "a" "日本" "{\"a\":1}"] "😀" [], msg "system" ";é}\"\\1]]" [tc "a" "日本" "make[3]", tc "a" "" "é"] "😀" []]
  runCase 298 "L" "é😀" [msg "é" "1-é 3m[é" [tc "é" "bash" "{\"a\":1}"] "é" [im "file:///tmp/a.png" "image/png", im "é" ""]]
  runCase 299 "E" "" [msg "é" "list the files" [] "a" [im "" ""], msg "tool" "m{role:4:user;}" [tc "" "日本" "{}"] "call_1" [im "" "image/png"]]
  runCase 300 "L" "" [msg "system" "}:\n- 3{2日2m" [] "😀" [], msg "system" "make[1make[2]]" [tc "a" "bash" "make[3]"] "é" [], msg "assistant" "tc-end;" [] "😀" [], msg "user" "日本語" [] "" [im "" "image/png"]]
  runCase 301 "E" "" []
  runCase 302 "E" "" [msg "system" "😀" [] "a" [], msg "" "tab\there" [] "" [], msg "" "tc-end;" [] "" []]
  runCase 303 "L" "" []
  runCase 304 "E" "" [msg "é" "é" [tc "call_1" "bash" "é"] "" [im "data:image/png;base64,AAAA" "", im "é" "image/jpeg"]]
  runCase 305 "E" "" []
  runCase 306 "E" "" []
  runCase 307 "L" "é😀" []
  runCase 308 "E" "" [msg "assistant" "x:3:y;" [] "call_1" [im "é" "image/jpeg"], msg "user" "á" [tc "a" "日本" "{\"a\":1}"] "" [im "é" "", im "" ""], msg "é" "make[21]" [tc "call_1" "" ""] "é" [], msg "é" "á" [] "call_1" [im "é" ""]]
  runCase 309 "L" "sha256:e3b0" [msg "é" "-\nb-\"m-\"" [tc "a" "" "{\"a\":1}"] "😀" [im "é" "image/jpeg"], msg "é" "" [] "é" []]
  runCase 310 "L" "" [msg "" "03;b3\"\"" [tc "" "bash" "{\"a\":1}", tc "a" "" "{\"a\":1}"] "a" [im "é" "image/jpeg", im "é" "image/png"], msg "" "[]a mé0}23 😀" [tc "" "" "{\"a\":1}"] "😀" []]
  runCase 311 "E" "" [msg "assistant" "im-end;" [tc "😀" "read_file" "é"] "a" [], msg "" "x:3:y;" [] "" []]
  runCase 312 "E" "" [msg "assistant" "x‍😀" [] "é" [], msg "system" "make[12]make[3]" [tc "é" "" "é"] "" []]
  runCase 313 "E" "" [msg "" "make[0]" [tc "é" "read_file" "é"] "" []]
  runCase 314 "B" "" [msg "user" "😀" [tc "call_1" "日本" "{\"a\":1}"] "call_1" []]
  runCase 315 "E" "" []
  runCase 316 "E" "" [msg "é" "😀 {[m[日-" [] "😀" []]
  runCase 317 "E" "" [msg "" "日本" [tc "é" "日本" "{}", tc "é" "" "make[3]"] "" [im "file:///tmp/a.png" "image/png", im "é" ""], msg "user" "make[20] and make[2]" [] "" []]
  runCase 318 "B" "" [msg "" "im-end;" [] "" [], msg "system" "" [tc "a" "" "é"] "a" [im "file:///tmp/a.png" "image/png", im "" ""], msg "assistant" "tc-end;" [tc "call_1" "bash" ""] "é" [], msg "system" "2" [] "a" [im "é" "", im "file:///tmp/a.png" ""]]
  runCase 319 "B" "" [msg "é" " nbsp" [] "é" [im "data:image/png;base64,AAAA" "image/png"], msg "" " nbsp" [tc "a" "read_file" "{\"a\":1}"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/jpeg"], msg "é" "\r\n" [] "é" [], msg "user" "make[12]make[3]" [tc "é" "read_file" "{\"a\":1}"] "" [im "file:///tmp/a.png" ""]]

#eval show IO Unit from do
  runCase 320 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" "}m{" [tc "😀" "read_file" "é"] "é" [im "é" "image/png"], msg "" "a\né-é 1" [] "é" [im "" "image/jpeg"]]
  runCase 321 "B" "" [msg "é" "make[0]" [tc "" "日本" "{\"a\":1}", tc "" "" "make[3]"] "a" []]
  runCase 322 "E" "" [msg "tool" "0ba]" [] "é" [im "é" ""]]
  runCase 323 "E" "" [msg "" "ok" [tc "" "" "make[3]", tc "a" "" "make[3]"] "a" [], msg "tool" "line\nbreak" [tc "é" "" "{\"a\":1}"] "call_1" [], msg "assistant" "a" [tc "a" "bash" "make[3]"] "" []]
  runCase 324 "L" "é😀" [msg "" "x:3:y;" [tc "a" "日本" "é"] "call_1" [im "" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 325 "L" "x" [msg "é" "}m{" [tc "call_1" "bash" ""] "a" [im "" ""]]
  runCase 326 "L" "é😀" [msg "assistant" "hi" [] "" []]
  runCase 327 "E" "" []
  runCase 328 "E" "" []
  runCase 329 "B" "" [msg "é" "make[1make[2]]" [] "é" [im "data:image/png;base64,AAAA" "image/png", im "" "image/jpeg"]]
  runCase 330 "E" "" [msg "system" "日本語" [tc "call_1" "日本" "make[3]"] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "" "x‍😀" [] "a" []]
  runCase 331 "E" "" [msg "assistant" "hi" [] "" [], msg "é" "😀" [] "" [im "" "", im "file:///tmp/a.png" "image/png"], msg "" "" [] "a" []]
  runCase 332 "L" "sha256:" [msg "é" "line\nbreak" [tc "" "bash" "{\"a\":1}", tc "" "" "é"] "call_1" [im "file:///tmp/a.png" "image/png"]]
  runCase 333 "E" "" [msg "" "ok" [tc "call_1" "read_file" "{}"] "a" [], msg "é" " nbsp" [tc "😀" "日本" "é"] "é" [], msg "" "" [] "😀" []]
  runCase 334 "E" "" [msg "é" "make[12]make[3]" [] "a" [], msg "system" "22[b1]\\1\n-2" [tc "" "" "make[3]", tc "" "bash" "{}"] "a" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" "back\\slash" [] "😀" [], msg "assistant" "x:3:y;" [] "😀" []]
  runCase 335 "E" "" [msg "user" "x‍😀" [] "a" [], msg "tool" "tc-end;" [] "a" [im "" "image/png", im "" "image/jpeg"], msg "system" "é[" [tc "a" "read_file" ""] "call_1" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 336 "E" "" [msg "assistant" "m;m10😀}mm日" [] "call_1" [im "data:image/png;base64,AAAA" "", im "é" "image/png"], msg "system" "sha256:" [] "call_1" [], msg "user" "ok" [] "😀" []]
  runCase 337 "E" "" []
  runCase 338 "B" "" [msg "tool" "á" [tc "a" "bash" "{}"] "😀" []]
  runCase 339 "B" "" [msg "user" "x:3:y;" [] "" [], msg "tool" "}m{" [tc "a" "bash" ""] "😀" [], msg "" "]1]b:b" [tc "" "" "{}"] "a" []]
  runCase 340 "E" "" []
  runCase 341 "L" "sha256:" []
  runCase 342 "L" "m-end;" [msg "system" "[\"a\"]" [] "call_1" []]
  runCase 343 "E" "" [msg "tool" "line\nbreak" [tc "call_1" "日本" "é"] "😀" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" ""], msg "tool" "make[12]make[3]" [] "é" []]
  runCase 344 "E" "" [msg "assistant" "x‍😀" [tc "call_1" "bash" "{}"] "" []]
  runCase 345 "L" "sha256:e3b0" [msg "user" "{}" [tc "" "日本" "{\"a\":1}"] "" [], msg "" "1m" [tc "é" "" "make[3]"] "a" [im "file:///tmp/a.png" "image/png"], msg "system" "m{role:4:user;}" [] "a" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" ""]]
  runCase 346 "B" "" [msg "user" "make[0]" [tc "é" "bash" "{}", tc "😀" "read_file" "{\"a\":1}"] "a" [], msg "" "2\n-3é" [tc "" "bash" "", tc "call_1" "bash" "{\"a\":1}"] "é" [], msg "user" "tc-end;" [] "" [], msg "tool" "á" [] "😀" []]
  runCase 347 "B" "" [msg "tool" "😀" [tc "😀" "日本" "{}"] "" [im "é" "image/png"], msg "tool" "é\\2]}2\"\\" [tc "😀" "read_file" "{\"a\":1}"] "a" [im "é" "image/png", im "file:///tmp/a.png" "image/png"], msg "tool" "sha256:" [] "é" []]
  runCase 348 "B" "" []
  runCase 349 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "" [tc "" "" "", tc "" "" ""] "é" []]
  runCase 350 "E" "" [msg "system" "é12😀日a\"\"日a\n1" [tc "é" "bash" "{}", tc "é" "日本" "{}"] "call_1" [im "file:///tmp/a.png" "image/png"], msg "user" "x:3:y;" [tc "" "日本" "make[3]"] "" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 351 "B" "" []
  runCase 352 "E" "" [msg "" ";\n{[é:1\"" [] "é" [im "file:///tmp/a.png" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 353 "L" "" []
  runCase 354 "B" "" [msg "é" "b];{3]b\n-" [tc "" "" "", tc "call_1" "" "é"] "a" [im "" "", im "file:///tmp/a.png" ""]]
  runCase 355 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 356 "B" "" [msg "assistant" "line\nbreak" [tc "é" "" "{\"a\":1}", tc "call_1" "bash" "{\"a\":1}"] "é" [], msg "assistant" "[\"a\"]" [] "" []]
  runCase 357 "E" "" [msg "é" "é2{a😀0}2;" [] "a" [], msg "é" "hi" [] "call_1" [], msg "" "\"quoted\"" [tc "é" "日本" "{}", tc "" "日本" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" "", im "é" "image/jpeg"], msg "tool" "\r\n" [] "call_1" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 358 "B" "" [msg "assistant" "😀" [tc "é" "日本" "é", tc "" "" ""] "" [im "file:///tmp/a.png" ""], msg "system" "{3 " [tc "é" "日本" "{}"] "a" []]
  runCase 359 "E" "" [msg "" "hi" [tc "😀" "bash" "{\"a\":1}"] "😀" [im "" "", im "é" ""], msg "tool" "you are motoko" [] "é" [im "file:///tmp/a.png" "", im "é" "image/jpeg"]]

#eval show IO Unit from do
  runCase 360 "B" "" [msg "tool" "é]0;a" [tc "😀" "read_file" "{\"a\":1}"] "é" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 361 "L" "" [msg "tool" "back\\slash" [] "é" [], msg "tool" "é{}-é\\\na" [tc "😀" "日本" "{}", tc "call_1" "bash" "make[3]"] "😀" [im "" "", im "data:image/png;base64,AAAA" ""], msg "tool" "\"quoted\"" [tc "a" "日本" "é"] "a" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" ""], msg "user" "make[0]" [] "" [im "file:///tmp/a.png" ""]]
  runCase 362 "L" "x" [msg "user" "make[0]" [] "😀" []]
  runCase 363 "B" "" [msg "" "0" [tc "é" "" "make[3]"] "😀" [], msg "é" "0" [] "a" [], msg "" "you are motoko" [tc "call_1" "bash" "{\"a\":1}", tc "é" "read_file" "{}"] "" [], msg "user" "list the files" [tc "call_1" "read_file" "{}"] "" []]
  runCase 364 "E" "" []
  runCase 365 "E" "" [msg "system" "}m{" [] "" [], msg "assistant" "á" [] "a" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "make[1]" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "assistant" "make[1]" [] "call_1" []]
  runCase 366 "E" "" [msg "assistant" "é" [] "a" []]
  runCase 367 "B" "" [msg "é" "\r\n" [] "😀" [], msg "system" "x‍😀" [tc "é" "read_file" "{}"] "é" []]
  runCase 368 "L" "sha256:e3b0" [msg "" "\"quoted\"" [] "a" [im "é" "image/jpeg"], msg "" "}]😀1:\"1-" [] "😀" [im "é" ""], msg "tool" "[\"a\"]" [tc "a" "" "{}", tc "é" "日本" "{\"a\":1}"] "" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"], msg "user" "}[3a" [tc "call_1" "日本" "{}", tc "" "" "make[3]"] "call_1" []]
  runCase 369 "L" "sha256:" []
  runCase 370 "E" "" []
  runCase 371 "E" "" [msg "user" "éx" [tc "" "日本" "make[3]"] "" [], msg "é" "make[1]" [tc "call_1" "日本" ""] "a" []]
  runCase 372 "L" "m-end;" [msg "system" "make[1]" [] "😀" [im "é" ""]]
  runCase 373 "E" "" []
  runCase 374 "E" "" [msg "assistant" "" [tc "😀" "read_file" "é"] "é" [], msg "user" "\"quoted\"" [tc "" "日本" "{\"a\":1}"] "call_1" []]
  runCase 375 "L" "sha256:e3b0" [msg "assistant" "you are motoko" [tc "a" "日本" "", tc "call_1" "bash" "{\"a\":1}"] "" []]
  runCase 376 "L" "sha256:e3b0" [msg "system" "éé[\n  -\"-\\}" [tc "call_1" "" "make[3]"] "a" []]
  runCase 377 "E" "" []
  runCase 378 "E" "" [msg "é" "b😀é ]\n1\\" [tc "😀" "bash" "é"] "😀" [], msg "user" "a} " [tc "é" "bash" "{}"] "" [], msg "assistant" "😀" [] "call_1" [im "é" "image/png"]]
  runCase 379 "L" "sha256:" [msg "é" "\\" [tc "" "read_file" "", tc "" "日本" "é"] "" [], msg "user" "make[0]" [] "é" []]
  runCase 380 "E" "" [msg "system" "日a3" [] "😀" [im "" "image/png", im "" "image/jpeg"], msg "é" "tc-end;" [] "call_1" [], msg "tool" "3 a\\日" [] "😀" [], msg "" "hi" [] "a" []]
  runCase 381 "B" "" [msg "é" "make[12]make[3]" [] "a" [], msg "assistant" ";a;\n " [tc "😀" "read_file" ""] "😀" []]
  runCase 382 "E" "" [msg "system" "ok" [tc "a" "日本" "é", tc "call_1" "read_file" "{\"a\":1}"] "" [], msg "tool" "3😀1[é:0é2日m" [] "é" [], msg "system" "m03😀}}};mb" [] "call_1" [im "file:///tmp/a.png" "image/png"], msg "assistant" "[\"a\"]" [tc "é" "bash" "{}", tc "é" "日本" ""] "a" []]
  runCase 383 "L" "" [msg "é" "日本" [tc "call_1" "bash" "make[3]", tc "😀" "日本" "é"] "é" [], msg "user" "1\n2\\b]]" [tc "😀" "" "{}"] "call_1" [im "file:///tmp/a.png" ""]]
  runCase 384 "E" "" []
  runCase 385 "E" "" [msg "é" "á" [] "é" [], msg "system" "😀" [] "😀" []]
  runCase 386 "L" "sha256:" [msg "" "\"quoted\"" [] "a" [], msg "user" "日本" [] "😀" [], msg "é" "x:3:y;" [tc "a" "read_file" "make[3]"] "call_1" [], msg "tool" "日{\né😀b\n-éb" [tc "" "" "{\"a\":1}", tc "a" "bash" "make[3]"] "é" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 387 "E" "" [msg "é" "make[1make[2]]" [] "" []]
  runCase 388 "E" "" [msg "" "" [] "😀" [], msg "user" "[{:\n1m😀m日\n\n" [tc "" "bash" "{\"a\":1}"] "call_1" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""], msg "" "make[1]" [tc "😀" "日本" "{\"a\":1}", tc "😀" "read_file" ""] "😀" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/png"], msg "tool" "3a[b:" [] "call_1" []]
  runCase 389 "L" "sha256:e3b0" [msg "tool" "\"-22😀b;b3" [tc "call_1" "日本" "é", tc "" "bash" ""] "é" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/png"], msg "user" "\r\n" [tc "call_1" "" ""] "é" []]
  runCase 390 "E" "" []
  runCase 391 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 392 "E" "" [msg "assistant" "sha256:" [] "call_1" [im "file:///tmp/a.png" ""]]
  runCase 393 "B" "" [msg "assistant" "make[0]" [] "a" [], msg "tool" "sha256:" [] "é" [im "é" "image/png"], msg "" "b" [] "" [im "file:///tmp/a.png" "image/png"], msg "" "日本" [] "é" []]
  runCase 394 "E" "" [msg "user" "x:3:y;" [] "a" [], msg "é" "{10\"é{a\"" [tc "😀" "bash" "{}"] "a" [im "" "image/png"], msg "tool" "日本" [tc "a" "bash" "make[3]"] "é" [im "" ""], msg "tool" "m{role:4:user;}" [] "call_1" []]
  runCase 395 "E" "" [msg "user" "tc-end;" [tc "é" "" ""] "a" [im "" "image/jpeg"], msg "é" "sha256:" [tc "" "" "{}"] "a" [], msg "tool" "ok" [] "😀" [im "data:image/png;base64,AAAA" "image/png", im "" "image/png"]]
  runCase 396 "B" "" [msg "é" "éx" [] "" [], msg "user" "tc-end;" [tc "😀" "read_file" "é"] "😀" [im "" "image/jpeg", im "" "image/jpeg"]]
  runCase 397 "E" "" [msg "system" "make[21]" [tc "call_1" "日本" "{\"a\":1}", tc "😀" "" "{}"] "call_1" [im "file:///tmp/a.png" "image/png"], msg "system" "😀" [tc "" "bash" "make[3]"] "é" [], msg "é" ";\" m😀é{m[}[1" [] "😀" [im "é" "image/jpeg"], msg "tool" "make[0]" [tc "call_1" "bash" "{\"a\":1}"] "call_1" []]
  runCase 398 "B" "" [msg "user" "😀" [tc "a" "日本" ""] "" [], msg "é" "make[12]make[3]" [] "call_1" [im "" "image/jpeg", im "é" ""]]
  runCase 399 "B" "" [msg "" "\na\n😀é" [tc "é" "日本" ""] "" [im "file:///tmp/a.png" "image/png"]]
