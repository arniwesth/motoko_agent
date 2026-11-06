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
GENERATED by gen_cases.py (seed 3, 400 cases). The Lean half of the differential test:
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
  runCase 10 "E" "" [msg "" "-\\: a😀m" [tc "a" "read_file" "é"] "😀" [im "é" "", im "data:image/png;base64,AAAA" "image/png"], msg "é" "a:}\\b0" [] "call_1" [im "é" "image/jpeg"]]
  runCase 11 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" ";b{😀[" [] "é" [], msg "tool" "é" [tc "😀" "日本" "make[3]"] "a" [], msg "é" "make[0]" [tc "a" "" "make[3]"] "😀" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 12 "B" "" [msg "system" "\r\n" [] "call_1" []]
  runCase 13 "L" "x" []
  runCase 14 "B" "" [msg "tool" "tc-end;" [] "é" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "user" "list the files" [] "😀" [im "" "image/png", im "é" ""]]
  runCase 15 "B" "" [msg "é" "日本" [] "call_1" []]
  runCase 16 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "\"; \nmé-]0é" [] "😀" [], msg "" "1a3 \\-{b-" [tc "call_1" "日本" "", tc "call_1" "" "é"] "" [im "" "image/jpeg", im "" ""]]
  runCase 17 "B" "" [msg "tool" "make[1]" [] "a" [], msg "assistant" "{}" [tc "" "bash" "make[3]"] "a" [], msg "" "1}é" [tc "" "bash" "make[3]", tc "call_1" "" "{\"a\":1}"] "é" []]
  runCase 18 "E" "" [msg "é" "m];b\n[1" [tc "a" "" ""] "" [im "file:///tmp/a.png" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 19 "B" "" [msg "assistant" "make[1make[2]]" [tc "😀" "日本" "{}"] "é" [], msg "user" "x‍😀" [tc "é" "read_file" "{}"] "é" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 20 "E" "" [msg "" "make[21]" [] "" [im "data:image/png;base64,AAAA" "", im "" "image/png"], msg "tool" "make[1make[2]]" [] "" [im "é" "image/png", im "" ""], msg "user" "b2][;\";" [] "a" [], msg "user" "line\nbreak" [tc "é" "bash" ""] "a" []]
  runCase 21 "L" "" [msg "assistant" "hi" [] "" [], msg "system" "á" [tc "" "日本" "", tc "a" "" "{}"] "call_1" [im "é" "image/jpeg"]]
  runCase 22 "B" "" [msg "assistant" "you are motoko" [] "😀" []]
  runCase 23 "L" "sha256:e3b0" []
  runCase 24 "E" "" []
  runCase 25 "B" "" [msg "" "line\nbreak" [] "😀" [im "" ""], msg "é" "é日a][\"" [] "😀" []]
  runCase 26 "L" "x" [msg "user" "\"m;日;" [tc "😀" "日本" "{}", tc "call_1" "bash" "make[3]"] "" [im "data:image/png;base64,AAAA" "image/png"], msg "tool" "á" [tc "" "日本" "{\"a\":1}"] "" []]
  runCase 27 "E" "" []
  runCase 28 "E" "" [msg "tool" "0:b\\\n\n];\"" [tc "" "bash" "make[3]", tc "call_1" "read_file" "{}"] "a" [], msg "é" "sha256:" [tc "call_1" "" "make[3]"] "é" [], msg "" "m{role:4:user;}" [] "é" []]
  runCase 29 "L" "m-end;" [msg "" "x:3:y;" [] "é" [], msg "user" "\r\n" [tc "😀" "日本" "make[3]", tc "a" "read_file" ""] "a" []]
  runCase 30 "B" "" [msg "é" "é \\\\m[0am😀" [tc "a" "read_file" "make[3]"] "call_1" []]
  runCase 31 "B" "" [msg "user" "\"quoted\"" [tc "a" "日本" "make[3]"] "😀" [], msg "tool" "日本語" [tc "" "日本" "{\"a\":1}", tc "a" "bash" "{\"a\":1}"] "call_1" []]
  runCase 32 "E" "" [msg "assistant" "tab\there" [] "call_1" [], msg "system" "back\\slash" [] "" [], msg "assistant" "é" [tc "😀" "" "{}"] "" [], msg "assistant" "make[20] and make[2]" [tc "😀" "日本" "é", tc "a" "" "{}"] "call_1" []]
  runCase 33 "L" "" [msg "" "\"quoted\"" [] "call_1" [im "file:///tmp/a.png" "image/jpeg"], msg "é" ";1\\\"" [tc "" "日本" "make[3]"] "call_1" []]
  runCase 34 "B" "" [msg "é" "line\nbreak" [tc "a" "read_file" "", tc "é" "bash" "{}"] "😀" [], msg "assistant" "😀" [tc "call_1" "read_file" "é"] "é" [], msg "user" "make[1]" [tc "😀" "日本" ""] "" []]
  runCase 35 "B" "" [msg "system" "m{role:4:user;}" [] "a" [im "file:///tmp/a.png" "", im "é" ""], msg "" "x:3:y;" [] "a" []]
  runCase 36 "E" "" [msg "system" "}" [tc "a" "日本" "é", tc "a" "read_file" "é"] "a" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "[\"a\"]" [tc "é" "日本" ""] "😀" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/jpeg"], msg "é" "😀a [-a;]😀}" [tc "é" "read_file" "{\"a\":1}"] "😀" []]
  runCase 37 "E" "" [msg "" "\\" [] "a" [], msg "tool" "hi" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "" ""], msg "" "日本" [] "call_1" [], msg "é" "[\"a\"]" [tc "" "bash" ""] "a" []]
  runCase 38 "E" "" [msg "é" "you are motoko" [] "é" [], msg "user" "x:3:y;" [tc "" "日本" "{\"a\":1}", tc "é" "" "{}"] "é" [im "é" ""]]
  runCase 39 "E" "" [msg "system" "é" [tc "😀" "" "make[3]"] "é" [], msg "system" "é" [] "é" [im "data:image/png;base64,AAAA" "image/png", im "data:image/png;base64,AAAA" "image/png"]]

#eval show IO Unit from do
  runCase 40 "E" "" [msg "tool" "ok" [] "😀" [], msg "tool" "" [tc "é" "" "é"] "" []]
  runCase 41 "E" "" [msg "system" "𝔘𝔫𝔦" [] "a" [], msg "tool" "tc-end;" [] "call_1" []]
  runCase 42 "E" "" [msg "é" "0😀]\"ma1" [tc "call_1" "" "{}", tc "" "日本" "{}"] "😀" [im "" "image/png", im "" "image/jpeg"], msg "system" "x‍😀" [] "é" [], msg "user" "😀1😀" [] "" [im "file:///tmp/a.png" "image/jpeg"], msg "é" "make[1make[2]]" [] "é" []]
  runCase 43 "L" "é😀" [msg "" "3\"" [] "a" []]
  runCase 44 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" "make[0]" [] "😀" [im "é" "", im "" "image/png"]]
  runCase 45 "E" "" [msg "system" "\"quoted\"" [tc "" "" "{\"a\":1}", tc "😀" "bash" "make[3]"] "" [im "é" "image/jpeg"], msg "é" "list the files" [] "é" [], msg "assistant" "list the files" [tc "a" "read_file" "{}", tc "a" "read_file" "make[3]"] "" []]
  runCase 46 "E" "" [msg "user" "😀" [tc "😀" "" "make[3]"] "a" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 47 "E" "" []
  runCase 48 "E" "" [msg "system" "𝔘𝔫𝔦" [] "" [], msg "tool" " ;-😀23 日;0" [tc "é" "日本" "{\"a\":1}"] "" [im "" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 49 "E" "" [msg "assistant" "2é-: \n[]" [] "" []]
  runCase 50 "E" "" [msg "tool" "éx" [] "a" [], msg "é" " 日\"é2[ é😀é😀" [tc "" "" "{}"] "a" []]
  runCase 51 "E" "" [msg "user" "line\nbreak" [tc "" "read_file" "{\"a\":1}"] "call_1" [im "é" "image/png"], msg "assistant" "{}" [] "a" [], msg "tool" "list the files" [] "a" [im "file:///tmp/a.png" ""]]
  runCase 52 "B" "" [msg "tool" "m{role:4:user;}" [tc "a" "" ""] "call_1" []]
  runCase 53 "L" "sha256:" [msg "assistant" "aa{-\n{\"a" [] "" []]
  runCase 54 "E" "" [msg "tool" "\"b😀}]" [] "call_1" [im "file:///tmp/a.png" "image/png"], msg "" "make[1make[2]]" [] "a" [im "é" "image/jpeg"], msg "assistant" "hi" [tc "a" "read_file" "{\"a\":1}", tc "é" "" "make[3]"] "a" [], msg "system" "line\nbreak" [] "é" [im "é" ""]]
  runCase 55 "E" "" [msg "user" "éx" [tc "" "日本" ""] "é" [im "file:///tmp/a.png" ""]]
  runCase 56 "L" "sha256:" [msg "user" "hi" [tc "é" "read_file" "é"] "😀" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/jpeg"], msg "" "make[0]" [tc "call_1" "bash" "é", tc "" "" "{}"] "😀" [im "é" "image/png"]]
  runCase 57 "B" "" [msg "user" "1bm[b1" [] "😀" [im "file:///tmp/a.png" "image/png"]]
  runCase 58 "E" "" [msg "assistant" "][:\n;-;" [tc "" "" "{}", tc "é" "" "é"] "é" [], msg "assistant" "make[21]" [tc "a" "read_file" "{\"a\":1}"] "a" [im "é" "image/jpeg"]]
  runCase 59 "E" "" [msg "tool" "éx" [] "a" []]
  runCase 60 "E" "" []
  runCase 61 "E" "" [msg "user" "日本語" [] "" [], msg "system" "ok" [tc "call_1" "bash" "{\"a\":1}"] "" []]
  runCase 62 "E" "" [msg "user" "x‍😀" [tc "" "" "é"] "" [], msg "" "é日\"\"0日{\"日" [tc "a" "" "{\"a\":1}"] "call_1" []]
  runCase 63 "B" "" [msg "user" "hi" [tc "😀" "read_file" "{}"] "😀" []]
  runCase 64 "E" "" [msg "system" "2\nm:日\"\\日1{" [tc "😀" "read_file" ""] "é" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "assistant" "2100m}; \n]1" [tc "a" "" "é", tc "call_1" "日本" "{\"a\":1}"] "é" [], msg "" "tc-end;" [tc "😀" "日本" "make[3]"] "" [], msg "tool" "0b]33[:2\n[b\"" [tc "" "日本" "é"] "😀" []]
  runCase 65 "E" "" [msg "assistant" "é" [tc "" "日本" "{\"a\":1}", tc "call_1" "read_file" "{}"] "call_1" []]
  runCase 66 "E" "" [msg "system" "make[20] and make[2]" [] "" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/jpeg"]]
  runCase 67 "B" "" [msg "é" "1\\;\n3]😀" [] "call_1" [], msg "" ":éa23a😀}😀" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "tab\there" [] "é" [], msg "system" ":" [tc "call_1" "bash" "{}"] "call_1" [im "é" "image/jpeg"]]
  runCase 68 "E" "" [msg "é" "im-end;" [] "call_1" [], msg "é" "line\nbreak" [tc "" "read_file" "make[3]"] "" [], msg "user" "302日\n][\\" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "" "\n[日bé0-[😀" [] "a" []]
  runCase 69 "L" "" [msg "tool" "sha256:" [] "call_1" [im "data:image/png;base64,AAAA" ""], msg "é" "日本語" [] "é" []]
  runCase 70 "E" "" [msg "assistant" "make[12]make[3]" [tc "" "read_file" "{\"a\":1}", tc "call_1" "日本" "{\"a\":1}"] "😀" []]
  runCase 71 "E" "" [msg "é" " ]}\n3" [tc "😀" "日本" "make[3]"] "a" [], msg "tool" "}m{" [tc "é" "bash" "make[3]"] "a" []]
  runCase 72 "L" "m-end;" [msg "user" "x:3:y;" [] "é" [im "é" "image/png", im "" "image/jpeg"], msg "tool" "1;2\n{0😀-\"" [] "é" []]
  runCase 73 "L" "" [msg "assistant" "list the files" [tc "😀" "" "make[3]", tc "call_1" "" "é"] "call_1" [], msg "tool" "é😀2\\}" [] "call_1" []]
  runCase 74 "L" "m-end;" []
  runCase 75 "B" "" [msg "user" "\"3" [tc "a" "日本" "make[3]"] "😀" [], msg "system" "\"quoted\"" [] "a" [im "data:image/png;base64,AAAA" "image/png", im "" "image/jpeg"]]
  runCase 76 "E" "" [msg "" "list the files" [tc "call_1" "" "{\"a\":1}"] "call_1" [], msg "user" "😀" [] "call_1" []]
  runCase 77 "E" "" [msg "" "]]m21;;{:]" [tc "call_1" "bash" ""] "a" []]
  runCase 78 "E" "" [msg "tool" "é" [tc "é" "日本" "é"] "call_1" [], msg "" "bb" [] "é" [], msg "user" "back\\slash" [] "call_1" []]
  runCase 79 "E" "" [msg "" "[;}[:" [tc "é" "" "{\"a\":1}"] "" [im "file:///tmp/a.png" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "user" "á" [tc "a" "bash" "{}", tc "" "日本" "é"] "😀" [im "é" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" "\r\n" [] "" []]

#eval show IO Unit from do
  runCase 80 "B" "" [msg "é" "b" [] "é" [], msg "" "make[12]make[3]" [tc "a" "日本" "é", tc "a" "bash" ""] "a" []]
  runCase 81 "E" "" [msg "tool" "日本" [tc "" "read_file" ""] "" [], msg "tool" "日本" [] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 82 "L" "m-end;" [msg "user" "make[1make[2]]" [] "a" [im "" ""], msg "" "m{role:4:user;}" [] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/jpeg"], msg "assistant" "x:3:y;" [] "é" []]
  runCase 83 "E" "" []
  runCase 84 "L" "é😀" []
  runCase 85 "E" "" [msg "" "" [] "call_1" [], msg "tool" "{0-\\:3-b;[]:" [] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "é" "a😀:2😀:é1" [tc "é" "日本" "é"] "call_1" [im "" "", im "file:///tmp/a.png" ""]]
  runCase 86 "B" "" [msg "tool" "you are motoko" [tc "call_1" "日本" "é", tc "é" "read_file" ""] "😀" [], msg "é" "tc-end;" [tc "a" "日本" "{\"a\":1}"] "call_1" [], msg "é" "make[0]" [tc "é" "" "é"] "é" [], msg "assistant" "3m\n]{" [] "a" [im "" "image/jpeg", im "é" "image/jpeg"]]
  runCase 87 "E" "" [msg "tool" "m{role:4:user;}" [tc "é" "read_file" "é"] "é" [], msg "é" "" [] "😀" []]
  runCase 88 "E" "" [msg "" "tc-end;" [] "call_1" [im "data:image/png;base64,AAAA" "", im "é" "image/png"], msg "user" "😀1-日\na" [] "😀" []]
  runCase 89 "B" "" [msg "" "[:[3" [] "a" []]
  runCase 90 "E" "" [msg "system" "make[20] and make[2]" [tc "a" "日本" "{}"] "😀" [], msg "user" ":m2[0{2[[" [tc "😀" "bash" "é", tc "é" "" "{}"] "😀" [im "file:///tmp/a.png" "image/jpeg"], msg "assistant" "á" [] "call_1" []]
  runCase 91 "E" "" []
  runCase 92 "L" "sha256:e3b0" [msg "é" "im-end;" [] "call_1" [], msg "" "ü:2:ü;" [] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/png"]]
  runCase 93 "E" "" [msg "assistant" "𝔘𝔫𝔦" [] "😀" [], msg "system" "}😀a;}2😀" [] "é" [im "data:image/png;base64,AAAA" "", im "é" ""], msg "assistant" "1😀\\😀\"日a😀" [] "call_1" [], msg "user" "ü:2:ü;" [] "a" []]
  runCase 94 "B" "" []
  runCase 95 "B" "" [msg "system" "" [tc "" "日本" "{\"a\":1}"] "" [im "é" "", im "é" "image/png"], msg "tool" ":;::[;m:" [tc "call_1" "bash" "{\"a\":1}", tc "" "日本" "{}"] "" [im "data:image/png;base64,AAAA" "", im "é" "image/jpeg"]]
  runCase 96 "B" "" [msg "assistant" "make[20] and make[2]" [tc "😀" "bash" "{\"a\":1}", tc "😀" "日本" "{\"a\":1}"] "call_1" [im "é" "image/jpeg"], msg "tool" "0-0:]}\"1日3]\n" [tc "😀" "" "", tc "call_1" "" "{\"a\":1}"] "call_1" [], msg "system" "make[1make[2]]" [tc "é" "日本" "make[3]"] "é" [], msg "system" "back\\slash" [] "é" []]
  runCase 97 "L" "é😀" [msg "" "\n😀[0::😀日" [tc "a" "read_file" ""] "a" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "é" "im-end;" [] "call_1" [], msg "é" "you are motoko" [] "call_1" [im "file:///tmp/a.png" ""]]
  runCase 98 "E" "" [msg "é" "line\nbreak" [tc "😀" "日本" ""] "😀" [im "file:///tmp/a.png" "image/png"], msg "system" "𝔘𝔫𝔦" [tc "" "" "{}"] "a" [], msg "tool" "ü:2:ü;" [] "😀" [], msg "tool" "hi" [] "😀" []]
  runCase 99 "B" "" [msg "" "ü:2:ü;" [] "😀" [im "data:image/png;base64,AAAA" ""]]
  runCase 100 "L" "m-end;" [msg "tool" "\r\n" [] "😀" [], msg "assistant" "" [] "" [im "" ""], msg "é" ":ébm2}é2éa" [] "😀" []]
  runCase 101 "E" "" [msg "tool" "tc-end;" [] "a" [], msg "é" "éx" [tc "call_1" "read_file" "{\"a\":1}"] "😀" [im "é" "image/png"], msg "tool" "\\3:[3-;[\\22m" [] "é" [im "é" "image/png", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 102 "E" "" [msg "assistant" "[[3-" [] "a" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""]]
  runCase 103 "E" "" [msg "system" "im-end;" [] "😀" [im "" "image/jpeg"], msg "" "tc-end;" [] "a" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" ""], msg "é" "make[1]" [tc "😀" "日本" "{}", tc "a" "" "{}"] "😀" [im "" "image/jpeg"]]
  runCase 104 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 105 "L" "sha256:" [msg "assistant" ":日[:m日" [tc "" "" "make[3]", tc "" "read_file" "make[3]"] "😀" [], msg "assistant" "-1éb:\\a{[" [tc "a" "bash" "{\"a\":1}"] "call_1" []]
  runCase 106 "E" "" [msg "tool" "𝔘𝔫𝔦" [] "call_1" []]
  runCase 107 "L" "sha256:e3b0" [msg "user" "list the files" [tc "call_1" "read_file" "{\"a\":1}"] "é" [], msg "system" "x:3:y;" [tc "a" "read_file" "{\"a\":1}"] "a" [im "file:///tmp/a.png" ""]]
  runCase 108 "E" "" [msg "user" ":-}}-" [tc "" "日本" "{}"] "a" [], msg "user" "𝔘𝔫𝔦" [] "a" [im "é" "image/png", im "file:///tmp/a.png" "image/png"], msg "tool" "you are motoko" [tc "😀" "read_file" "{\"a\":1}"] "😀" [], msg "system" "éa 3;]\"é}::😀" [] "a" []]
  runCase 109 "B" "" [msg "" "日0:;2\\\\" [] "" [], msg "assistant" "éx" [] "" [], msg "assistant" "x:3:y;" [tc "" "日本" "é", tc "" "" ""] "a" [im "file:///tmp/a.png" "image/png", im "" ""], msg "" "{3m:\\[" [tc "😀" "bash" "é"] "call_1" []]
  runCase 110 "B" "" [msg "user" "im-end;" [tc "é" "" "{\"a\":1}"] "a" [im "" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" "3日\n\"03\"30" [] "😀" [im "file:///tmp/a.png" "image/png", im "" ""], msg "" ";]日\\" [tc "😀" "日本" "{\"a\":1}", tc "" "日本" "é"] "a" [im "file:///tmp/a.png" "image/png"]]
  runCase 111 "B" "" [msg "assistant" "x‍😀" [] "" [], msg "tool" "{}" [tc "é" "bash" "{\"a\":1}"] "" [im "é" ""], msg "system" "}-2;\\2--2-" [] "call_1" []]
  runCase 112 "E" "" [msg "" "" [] "é" [], msg "assistant" "make[21]" [] "😀" [im "" ""], msg "é" "" [] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/png"]]
  runCase 113 "E" "" [msg "" "á" [] "a" [], msg "user" "{}" [tc "" "日本" "{\"a\":1}"] "" []]
  runCase 114 "E" "" [msg "é" "make[1]" [] "a" [], msg "assistant" "日:" [] "a" []]
  runCase 115 "E" "" []
  runCase 116 "E" "" [msg "" "make[1make[2]]" [tc "" "日本" "{}"] "a" [], msg "system" "make[0]" [] "a" []]
  runCase 117 "E" "" [msg "é" "you are motoko" [tc "a" "read_file" "", tc "call_1" "read_file" "{}"] "a" [im "" "image/png"], msg "assistant" "á" [] "call_1" [im "file:///tmp/a.png" "", im "é" "image/jpeg"], msg "system" "m\\😀" [] "😀" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 118 "E" "" [msg "assistant" "you are motoko" [tc "é" "read_file" ""] "a" [], msg "assistant" "x‍😀" [] "" [], msg "assistant" "tc-end;" [tc "a" "read_file" ""] "😀" []]
  runCase 119 "E" "" [msg "assistant" "\"quoted\"" [] "é" [], msg "" "sha256:" [] "a" [im "" "", im "é" ""], msg "assistant" "{}" [tc "" "bash" "{}", tc "é" "bash" "make[3]"] "a" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/png"]]

#eval show IO Unit from do
  runCase 120 "B" "" [msg "" "]a3\n\"m" [] "call_1" []]
  runCase 121 "B" "" []
  runCase 122 "E" "" [msg "system" ":éa日é\n😀]:" [] "😀" [], msg "" "make[21]" [tc "😀" "日本" "make[3]"] "é" [im "" "image/jpeg", im "é" ""], msg "é" ":2amé\"日12 ;a" [tc "😀" "" "{\"a\":1}"] "😀" []]
  runCase 123 "B" "" [msg "assistant" "make[0]" [] "" [], msg "tool" "line\nbreak" [] "a" []]
  runCase 124 "L" "x" [msg "assistant" "á" [] "😀" [im "é" ""], msg "é" " 3m2日-\\b\né\n" [] "a" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" ""]]
  runCase 125 "E" "" [msg "assistant" "21[a" [tc "" "日本" "{}"] "call_1" [im "file:///tmp/a.png" "", im "" "image/png"]]
  runCase 126 "E" "" [msg "system" "tc-end;" [tc "😀" "read_file" "make[3]", tc "a" "日本" "é"] "call_1" []]
  runCase 127 "B" "" [msg "assistant" "\\\"-[2" [] "a" [], msg "é" " 2日日;:" [] "é" [im "é" "image/jpeg"]]
  runCase 128 "L" "sha256:" [msg "tool" ";b" [] "" []]
  runCase 129 "B" "" [msg "" "1aa[0\\-日0\\3" [] "😀" [], msg "tool" "-😀]" [] "😀" []]
  runCase 130 "E" "" [msg "system" "sha256:" [tc "call_1" "read_file" "make[3]"] "é" [], msg "tool" "]b😀:" [] "" [], msg "é" "á" [] "é" [], msg "system" "é1b 0;a m-" [tc "call_1" "" "{\"a\":1}"] "" [im "file:///tmp/a.png" "image/jpeg", im "" ""]]
  runCase 131 "B" "" [msg "system" "á" [tc "" "bash" "", tc "call_1" "" ""] "é" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""], msg "" ";{\n2\\]2" [tc "" "" "{\"a\":1}"] "call_1" []]
  runCase 132 "E" "" []
  runCase 133 "E" "" [msg "" "3\" ; b[\"" [tc "é" "日本" "make[3]"] "call_1" [], msg "user" "3:é3[[3😀[" [] "call_1" [], msg "system" "you are motoko" [] "😀" [im "data:image/png;base64,AAAA" ""], msg "" "😀" [tc "😀" "日本" "{\"a\":1}"] "é" []]
  runCase 134 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "á" [tc "😀" "bash" "{}"] "" [], msg "tool" "[\\;😀" [tc "é" "" "é"] "😀" [], msg "system" "😀" [] "é" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 135 "B" "" [msg "user" "[\"a\"]" [] "" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" "image/png"]]
  runCase 136 "L" "sha256:e3b0" []
  runCase 137 "E" "" [msg "é" "\"quoted\"" [tc "" "" "make[3]"] "😀" []]
  runCase 138 "E" "" [msg "" "x:3:y;" [tc "" "日本" "", tc "😀" "bash" "{\"a\":1}"] "" []]
  runCase 139 "E" "" [msg "" "line\nbreak" [tc "" "bash" "é", tc "é" "bash" ""] "é" [], msg "user" "日1日m\n-2é3b" [tc "é" "bash" "make[3]"] "call_1" []]
  runCase 140 "E" "" [msg "user" "{😀]\n" [tc "😀" "" "{}"] "😀" []]
  runCase 141 "B" "" [msg "user" "make[1make[2]]" [tc "😀" "read_file" "é"] "😀" [], msg "tool" "list the files" [tc "é" "" ""] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 142 "E" "" []
  runCase 143 "E" "" [msg "system" "é;[] }\\}0" [] "a" [], msg "assistant" "hi" [] "a" [im "file:///tmp/a.png" "image/jpeg", im "é" ""]]
  runCase 144 "B" "" [msg "" "á" [] "" [im "é" "image/png"], msg "user" "é" [] "" [im "" "image/png", im "é" "image/png"]]
  runCase 145 "L" "" [msg "system" "日 \\0\\ b]m-日日" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" "you are motoko" [tc "😀" "日本" ""] "a" [], msg "user" "[b\\}]3m1" [] "call_1" [], msg "system" "}m{" [] "😀" [im "é" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 146 "E" "" [msg "tool" "sha256:" [tc "a" "" "{}", tc "call_1" "bash" ""] "é" [], msg "system" "- " [] "a" [], msg "é" "日本" [] "😀" []]
  runCase 147 "E" "" [msg "user" "日本" [] "call_1" [], msg "é" "make[0]" [tc "a" "read_file" "", tc "" "read_file" "é"] "call_1" [im "file:///tmp/a.png" "image/jpeg", im "é" ""]]
  runCase 148 "L" "m-end;" [msg "assistant" "x:3:y;" [tc "call_1" "日本" "make[3]", tc "" "read_file" "make[3]"] "é" [im "" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 149 "E" "" [msg "assistant" "make[1]" [tc "call_1" "" ""] "" []]
  runCase 150 "E" "" [msg "é" "mb😀é\"\\日0;" [] "" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" "0;];\"] 1:-3é" [tc "call_1" "read_file" "make[3]", tc "a" "bash" "make[3]"] "😀" []]
  runCase 151 "L" "é😀" []
  runCase 152 "L" "é😀" [msg "system" "ok" [] "é" [im "" "image/jpeg", im "file:///tmp/a.png" ""]]
  runCase 153 "B" "" [msg "é" "ok" [] "é" [im "é" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 154 "L" "" [msg "tool" "line\nbreak" [tc "a" "read_file" "", tc "a" "bash" "{}"] "a" [], msg "system" "\r\n" [] "a" [], msg "user" "0\\\n[{\\" [tc "a" "bash" "{}"] "é" []]
  runCase 155 "E" "" [msg "user" ";\"" [] "é" [], msg "system" "tab\there" [tc "a" "" "{}", tc "call_1" "bash" "make[3]"] "" [im "é" "image/jpeg"]]
  runCase 156 "E" "" [msg "user" "hi" [] "é" [], msg "tool" "back\\slash" [] "call_1" [], msg "é" "\\1日\\\"" [] "é" [im "é" "image/jpeg"], msg "tool" "im-end;" [tc "call_1" "bash" ""] "😀" []]
  runCase 157 "L" "x" [msg "tool" "m日\n2😀éaa:" [] "call_1" [im "é" "image/png", im "" "image/jpeg"]]
  runCase 158 "E" "" [msg "user" "{}" [] "😀" []]
  runCase 159 "E" "" [msg "tool" ";\"b" [tc "a" "read_file" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/png"], msg "" "make[1make[2]]" [] "é" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/jpeg"], msg "é" "-日;-]é" [] "a" [], msg "user" "m{role:4:user;}" [] "😀" [im "é" "image/png"]]

#eval show IO Unit from do
  runCase 160 "B" "" [msg "tool" "á" [tc "a" "日本" "{}", tc "a" "日本" ""] "a" [], msg "tool" "tc-end;" [tc "call_1" "read_file" "make[3]"] "call_1" [], msg "tool" "a" [] "é" []]
  runCase 161 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 162 "L" "x" [msg "assistant" ":日2日0a0\"m0mé" [] "" [im "data:image/png;base64,AAAA" ""], msg "system" "日本" [] "😀" [], msg "system" "a1日m;-" [tc "a" "" "make[3]"] "call_1" [], msg "" "é" [] "call_1" []]
  runCase 163 "E" "" [msg "user" "x‍😀" [tc "" "bash" ""] "😀" [], msg "system" "\"quoted\"" [tc "é" "日本" "{}", tc "a" "" "é"] "é" [], msg "assistant" "back\\slash" [] "a" [im "é" "image/jpeg"]]
  runCase 164 "E" "" [msg "é" "日;{\"\"é日" [] "é" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"], msg "user" "tab\there" [tc "" "" "make[3]"] "😀" []]
  runCase 165 "B" "" []
  runCase 166 "E" "" []
  runCase 167 "E" "" []
  runCase 168 "L" "sha256:" [msg "é" "make[1make[2]]" [tc "é" "read_file" "{\"a\":1}"] "😀" [im "file:///tmp/a.png" "image/jpeg", im "" "image/jpeg"], msg "user" "" [tc "é" "日本" "", tc "" "日本" "make[3]"] "é" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/png"]]
  runCase 169 "L" "é😀" [msg "assistant" "}m{" [] "" [], msg "user" "a\\ " [] "a" [im "data:image/png;base64,AAAA" "", im "é" ""]]
  runCase 170 "E" "" []
  runCase 171 "E" "" []
  runCase 172 "L" "sha256:e3b0" [msg "user" "[ }é]é\"1" [] "" [], msg "user" "list the files" [tc "😀" "read_file" "{}"] "é" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" ""], msg "system" "b:😀" [tc "a" "" "{}"] "é" [im "" ""], msg "system" "m{role:4:user;}" [tc "" "" "{}"] "call_1" []]
  runCase 173 "B" "" [msg "user" "make[20] and make[2]" [tc "é" "" "", tc "call_1" "日本" "make[3]"] "a" []]
  runCase 174 "E" "" [msg "é" "make[20] and make[2]" [] "" [], msg "user" "日本" [tc "" "read_file" "{\"a\":1}", tc "call_1" "日本" "{}"] "é" [im "é" ""]]
  runCase 175 "B" "" []
  runCase 176 "L" "sha256:" [msg "é" "[\"a\"]" [] "é" [], msg "é" "tab\there" [tc "" "" "é", tc "call_1" "日本" "{\"a\":1}"] "" [], msg "system" "[\"a\"]" [] "a" [], msg "tool" "\né\\日" [tc "😀" "" "make[3]"] "" [im "file:///tmp/a.png" "image/png"]]
  runCase 177 "E" "" [msg "system" "\r\n" [] "a" [], msg "" "sha256:" [] "call_1" [im "é" "", im "" "image/jpeg"]]
  runCase 178 "L" "m-end;" [msg "assistant" "" [] "é" []]
  runCase 179 "B" "" [msg "user" "ü:2:ü;" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "日本語" [tc "" "read_file" "é", tc "" "日本" "{}"] "" []]
  runCase 180 "B" "" [msg "system" "😀" [tc "😀" "bash" "{}"] "" []]
  runCase 181 "L" "m-end;" [msg "assistant" "im-end;" [] "" [], msg "assistant" "make[20] and make[2]" [] "a" [], msg "" "[\"a\"]" [] "😀" []]
  runCase 182 "B" "" [msg "user" "\r\n" [tc "é" "日本" "make[3]", tc "" "" "é"] "call_1" [im "" "image/png", im "é" "image/jpeg"]]
  runCase 183 "E" "" [msg "system" "\"2m\"é" [] "é" []]
  runCase 184 "B" "" [msg "system" "1\"{0[{-3\n" [tc "😀" "bash" ""] "" [im "file:///tmp/a.png" ""]]
  runCase 185 "B" "" [msg "assistant" "[\"a\"]" [tc "é" "" "é"] "a" [], msg "é" "m{role:4:user;}" [tc "😀" "read_file" "{\"a\":1}"] "😀" [], msg "user" "3\\a\nm-\n" [] "é" []]
  runCase 186 "L" "sha256:" [msg "user" "tc-end;" [] "call_1" []]
  runCase 187 "E" "" [msg "assistant" "b[3" [] "call_1" []]
  runCase 188 "E" "" [msg "" "list the files" [tc "é" "日本" "é", tc "😀" "read_file" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" ""], msg "user" "back\\slash" [] "a" [], msg "system" "日本" [] "call_1" [], msg "user" "ü:2:ü;" [tc "call_1" "" "é", tc "é" "" "{\"a\":1}"] "" []]
  runCase 189 "E" "" [msg "system" "" [tc "é" "" ""] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/jpeg"], msg "user" "m{role:4:user;}" [tc "a" "" "make[3]", tc "😀" "日本" ""] "é" []]
  runCase 190 "E" "" [msg "assistant" "日本" [tc "😀" "" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/png"], msg "tool" "é" [] "" []]
  runCase 191 "L" "x" [msg "system" "日]\"2a0\\}\\\n:" [] "call_1" []]
  runCase 192 "E" "" [msg "system" "you are motoko" [] "😀" [im "file:///tmp/a.png" "image/png", im "" "image/jpeg"], msg "tool" "ok" [tc "call_1" "" "{\"a\":1}"] "é" []]
  runCase 193 "E" "" [msg "é" "[[😀" [tc "é" "日本" "é"] "a" []]
  runCase 194 "E" "" [msg "é" "ok" [tc "call_1" "read_file" "{}"] "a" [im "é" "image/png", im "data:image/png;base64,AAAA" ""], msg "system" "\"quoted\"" [tc "a" "read_file" "{}", tc "" "" "make[3]"] "é" [], msg "tool" "m{role:4:user;}" [tc "é" "" ""] "a" []]
  runCase 195 "E" "" [msg "" "mé:0m;[" [] "a" [im "file:///tmp/a.png" ""], msg "system" "ok" [] "é" []]
  runCase 196 "E" "" []
  runCase 197 "B" "" []
  runCase 198 "B" "" [msg "é" "\nb00\"}[éb😀" [tc "😀" "" "{\"a\":1}", tc "é" "bash" "make[3]"] "é" [], msg "assistant" "back\\slash" [] "😀" []]
  runCase 199 "E" "" [msg "" "á" [tc "a" "" "é"] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "data:image/png;base64,AAAA" "image/png"]]

#eval show IO Unit from do
  runCase 200 "E" "" [msg "assistant" "sha256:" [tc "é" "read_file" "{}"] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 201 "E" "" [msg "tool" "á" [] "é" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" " nbsp" [] "" [], msg "user" "line\nbreak" [tc "call_1" "" "make[3]"] "é" [], msg "" "]aéa:a[0]\\" [tc "a" "" "{}"] "é" []]
  runCase 202 "E" "" []
  runCase 203 "B" "" [msg "é" "make[21]" [tc "call_1" "read_file" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 204 "E" "" [msg "assistant" "" [tc "a" "bash" "{\"a\":1}", tc "é" "日本" "é"] "" [im "é" "image/png", im "file:///tmp/a.png" "image/png"]]
  runCase 205 "E" "" [msg "tool" "sha256:" [tc "call_1" "" "make[3]"] "😀" [im "é" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 206 "E" "" [msg "" "{}" [] "call_1" [im "" "", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 207 "E" "" []
  runCase 208 "B" "" [msg "é" "tc-end;" [] "😀" []]
  runCase 209 "E" "" [msg "" "line\nbreak" [tc "😀" "日本" "{}", tc "é" "read_file" "{}"] "😀" [], msg "" "éa" [tc "" "" "make[3]"] "😀" []]
  runCase 210 "E" "" []
  runCase 211 "L" "sha256:e3b0" [msg "" "éx" [] "é" [], msg "tool" "make[20] and make[2]" [] "é" [], msg "é" "hi" [] "call_1" []]
  runCase 212 "L" "" [msg "system" "300m0-" [] "" [im "é" "image/jpeg"]]
  runCase 213 "L" "" [msg "" "é3" [tc "a" "bash" "é"] "" [im "" ""], msg "é" "make[20] and make[2]" [] "😀" [im "" ""], msg "tool" "x:3:y;" [tc "a" "日本" "{\"a\":1}", tc "call_1" "read_file" "{\"a\":1}"] "é" [], msg "" "im-end;" [] "call_1" [im "é" "image/jpeg"]]
  runCase 214 "E" "" [msg "" "a日" [tc "" "read_file" "make[3]"] "é" []]
  runCase 215 "E" "" [msg "" ";3]{" [] "😀" [], msg "assistant" "make[12]make[3]" [] "" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 216 "E" "" [msg "" "b{\n" [] "a" []]
  runCase 217 "B" "" [msg "é" "😀" [] "" [im "é" "image/jpeg"]]
  runCase 218 "B" "" []
  runCase 219 "E" "" []
  runCase 220 "L" "x" [msg "tool" "}m{" [] "😀" [], msg "system" "}m{" [tc "é" "" "make[3]"] "a" []]
  runCase 221 "B" "" [msg "é" " nbsp" [] "é" [], msg "user" "" [] "" []]
  runCase 222 "L" "m-end;" [msg "tool" "you are motoko" [tc "é" "" "é", tc "call_1" "日本" ""] "" [im "file:///tmp/a.png" "", im "" "image/png"]]
  runCase 223 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "日本語" [tc "call_1" "bash" ""] "😀" []]
  runCase 224 "L" "sha256:e3b0" [msg "user" "make[1]" [] "é" []]
  runCase 225 "B" "" [msg "user" "1;m" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" ""], msg "é" "tc-end;" [] "😀" [], msg "system" "éx" [] "😀" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""], msg "system" "sha256:" [tc "😀" "" "é"] "a" []]
  runCase 226 "E" "" []
  runCase 227 "L" "m-end;" [msg "tool" "ü:2:ü;" [] "a" [], msg "assistant" "{}" [] "call_1" []]
  runCase 228 "E" "" [msg "" "m{role:4:user;}" [] "😀" [], msg "é" "ok" [] "😀" []]
  runCase 229 "B" "" [msg "user" "𝔘𝔫𝔦" [] "é" [], msg "tool" "line\nbreak" [tc "a" "" "make[3]", tc "call_1" "read_file" "{\"a\":1}"] "😀" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 230 "E" "" [msg "é" "make[21]" [tc "a" "read_file" "{\"a\":1}"] "" [], msg "system" "x‍😀" [tc "a" "日本" "", tc "😀" "" ""] "😀" [], msg "user" "3\\-2😀2121[ ]" [] "" [], msg "tool" "\r\n" [] "a" []]
  runCase 231 "E" "" [msg "é" "}m{" [tc "😀" "" "{}", tc "😀" "" "make[3]"] "a" []]
  runCase 232 "E" "" [msg "tool" "a;\n3 " [] "😀" [im "" "image/png", im "" ""]]
  runCase 233 "B" "" [msg "" "ü:2:ü;" [tc "" "read_file" "make[3]"] "a" [im "file:///tmp/a.png" "image/png"]]
  runCase 234 "E" "" [msg "assistant" "\r\n" [] "call_1" [], msg "" ":b1😀\"😀😀a1" [] "call_1" []]
  runCase 235 "E" "" [msg "é" "" [] "call_1" []]
  runCase 236 "L" "" [msg "tool" "{}" [] "call_1" [im "é" "", im "file:///tmp/a.png" ""]]
  runCase 237 "L" "x" [msg "user" "[ ]1]\"" [tc "" "日本" "{\"a\":1}", tc "😀" "bash" "é"] "" [im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "b" [tc "a" "read_file" "{\"a\":1}"] "call_1" [im "é" "image/png", im "é" ""]]
  runCase 238 "L" "é😀" []
  runCase 239 "E" "" [msg "system" "{\"\n}{é1" [tc "😀" "read_file" "é"] "😀" [], msg "assistant" "[{;1é;{{\n\na" [] "call_1" [], msg "assistant" "make[20] and make[2]" [] "" [im "file:///tmp/a.png" "image/jpeg"]]

#eval show IO Unit from do
  runCase 240 "E" "" []
  runCase 241 "L" "é😀" []
  runCase 242 "E" "" [msg "é" "𝔘𝔫𝔦" [] "😀" [im "é" "image/png"], msg "é" "á" [] "call_1" [], msg "tool" "line\nbreak" [] "" [im "" "", im "" ""], msg "" "b\n;[{😀日b0😀1" [] "call_1" []]
  runCase 243 "B" "" [msg "system" "back\\slash" [] "a" [], msg "é" ";mb0m:日" [] "é" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/jpeg"], msg "é" " nbsp" [] "é" [im "file:///tmp/a.png" "image/jpeg"], msg "user" "-}]" [tc "" "" "é"] "call_1" []]
  runCase 244 "E" "" []
  runCase 245 "L" "x" []
  runCase 246 "E" "" [msg "" "m{role:4:user;}" [] "é" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" ""], msg "é" "日本語" [] "" [], msg "user" "make[12]make[3]" [] "é" [], msg "system" "-\\日]日1{}\n 2" [tc "call_1" "read_file" "make[3]", tc "a" "bash" ""] "a" []]
  runCase 247 "E" "" [msg "user" "m{role:4:user;}" [tc "" "bash" "{\"a\":1}"] "é" [], msg "é" "m{role:4:user;}" [] "" [im "é" ""], msg "assistant" "{[\"a\"ab" [] "é" [], msg "é" "á" [tc "a" "bash" "make[3]"] "😀" []]
  runCase 248 "B" "" []
  runCase 249 "L" "x" [msg "system" "ü:2:ü;" [] "call_1" []]
  runCase 250 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "system" "{}" [tc "😀" "" "{\"a\":1}", tc "é" "日本" ""] "" []]
  runCase 251 "L" "é😀" [msg "system" "list the files" [] "é" [im "data:image/png;base64,AAAA" "", im "é" "image/png"], msg "user" "{}" [] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 252 "E" "" [msg "system" "1{😀😀1]" [] "call_1" [], msg "system" "😀" [] "a" [im "file:///tmp/a.png" "", im "é" "image/png"], msg "system" "line\nbreak" [tc "😀" "bash" "make[3]"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" ""]]
  runCase 253 "L" "sha256:e3b0" [msg "" "hi" [] "call_1" [], msg "tool" "make[0]" [] "" [], msg "user" ";😀😀0b" [tc "é" "日本" "make[3]"] "a" []]
  runCase 254 "L" "m-end;" [msg "é" "sha256:" [tc "call_1" "" "", tc "é" "bash" "{\"a\":1}"] "é" []]
  runCase 255 "E" "" [msg "user" "line\nbreak" [] "😀" []]
  runCase 256 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "é" "\n\n2}" [tc "call_1" "日本" "{}"] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "" "image/png"]]
  runCase 257 "L" "é😀" [msg "assistant" "make[1]" [tc "a" "bash" "é"] "" [im "é" "", im "é" "image/png"]]
  runCase 258 "E" "" [msg "tool" "a;-][" [] "call_1" [im "" "image/png"], msg "é" "éx" [tc "😀" "" "é"] "é" []]
  runCase 259 "E" "" [msg "é" "ok" [] "a" []]
  runCase 260 "E" "" [msg "é" "日 }a;am2" [tc "é" "" ""] "call_1" [], msg "assistant" "make[0]" [tc "" "" "make[3]", tc "call_1" "bash" ""] "a" [im "é" "", im "é" "image/png"]]
  runCase 261 "L" "sha256:" [msg "assistant" "\\[]3[11" [] "é" [im "é" "", im "data:image/png;base64,AAAA" ""], msg "system" "x‍😀" [tc "😀" "" "make[3]"] "é" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 262 "E" "" [msg "assistant" "you are motoko" [] "a" [im "é" "image/png"], msg "user" "[\"a\"]" [] "a" [im "file:///tmp/a.png" "image/png"], msg "é" "make[20] and make[2]" [] "" [], msg "system" "2}ma}\n\n]b0\"" [tc "call_1" "" "é"] "😀" [im "file:///tmp/a.png" ""]]
  runCase 263 "E" "" [msg "user" "}m{" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 264 "L" "sha256:" [msg "system" "m]:}" [tc "call_1" "日本" "{\"a\":1}"] "a" [im "data:image/png;base64,AAAA" "image/png", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 265 "E" "" [msg "system" "{a-日éé0😀]{a-" [tc "call_1" "bash" "make[3]"] "call_1" [im "file:///tmp/a.png" "", im "" "image/jpeg"], msg "é" "sha256:" [] "" [], msg "system" "make[12]make[3]" [] "😀" [im "file:///tmp/a.png" ""]]
  runCase 266 "E" "" [msg "user" ";{:" [] "é" [], msg "é" "ab[" [] "a" []]
  runCase 267 "B" "" [msg "tool" "}3;日b\\[:a[" [tc "😀" "" "{\"a\":1}"] "é" [], msg "user" " nbsp" [] "é" [], msg "system" "you are motoko" [] "é" [im "é" "image/png"]]
  runCase 268 "B" "" [msg "tool" "éx" [] "call_1" [], msg "" "]\n😀{2:a\n\n:\n" [] "a" [im "é" "image/png"], msg "system" "make[1]" [] "a" [im "data:image/png;base64,AAAA" ""]]
  runCase 269 "B" "" [msg "tool" "3" [] "😀" [], msg "tool" "make[0]" [tc "a" "日本" ""] "call_1" [im "" "image/jpeg", im "é" "image/png"], msg "tool" "}m{" [tc "call_1" "日本" "", tc "a" "bash" "é"] "a" [im "file:///tmp/a.png" "", im "data:image/png;base64,AAAA" ""], msg "assistant" "make[20] and make[2]" [] "é" [im "" ""]]
  runCase 270 "E" "" [msg "system" "\n3] [\"" [tc "😀" "read_file" "{\"a\":1}", tc "é" "" "{\"a\":1}"] "😀" [], msg "tool" "}m{" [tc "é" "" ""] "" []]
  runCase 271 "L" "sha256:" []
  runCase 272 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" ";{😀m3\\}a-\"m" [tc "😀" "日本" "", tc "😀" "日本" "é"] "é" [], msg "system" "éx" [] "é" [], msg "tool" "\"\né😀\\é" [tc "" "日本" "{}"] "call_1" []]
  runCase 273 "E" "" [msg "tool" "𝔘𝔫𝔦" [] "é" [], msg "tool" "make[0]" [] "é" [], msg "tool" "line\nbreak" [tc "😀" "bash" "{\"a\":1}"] "é" [im "" "image/png"], msg "user" "é" [] "a" []]
  runCase 274 "L" "x" [msg "assistant" "á" [] "call_1" [], msg "é" "" [tc "😀" "" "{}"] "a" [], msg "tool" "-3b\\a]-" [] "a" []]
  runCase 275 "E" "" [msg "" "list the files" [tc "" "日本" "{}", tc "é" "日本" "é"] "call_1" [], msg "system" "éx" [] "😀" [], msg "user" "éx" [] "😀" [im "" "", im "" ""], msg "assistant" "\\;\"" [tc "" "read_file" "{\"a\":1}"] "call_1" []]
  runCase 276 "B" "" [msg "system" " nbsp" [tc "call_1" "日本" ""] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 277 "B" "" [msg "assistant" ":a] m0-;a3" [tc "call_1" "read_file" "é"] "call_1" []]
  runCase 278 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "é" "x‍😀" [] "😀" [], msg "" "x:3:y;" [] "😀" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" "image/png"]]
  runCase 279 "B" "" [msg "é" "3\";]日b" [tc "call_1" "read_file" "{}"] "" []]

#eval show IO Unit from do
  runCase 280 "B" "" [msg "tool" "back\\slash" [] "" [im "file:///tmp/a.png" "image/png", im "" "image/jpeg"]]
  runCase 281 "B" "" [msg "" "á" [] "a" []]
  runCase 282 "E" "" []
  runCase 283 "E" "" [msg "system" "á" [] "" [im "" ""]]
  runCase 284 "B" "" []
  runCase 285 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "]" [tc "call_1" "日本" "{}"] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" ""], msg "assistant" "[\"a\"]" [tc "" "" "é"] "é" [], msg "system" "{}" [tc "call_1" "bash" "make[3]"] "call_1" [], msg "tool" "\"{[" [] "a" []]
  runCase 286 "B" "" [msg "system" "😀}b😀\"{" [] "" []]
  runCase 287 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "m{role:4:user;}" [] "😀" [im "é" "image/png", im "data:image/png;base64,AAAA" ""], msg "tool" "back\\slash" [] "😀" [im "é" "image/jpeg"], msg "assistant" "x‍😀" [] "é" [], msg "tool" "\"quoted\"" [] "😀" []]
  runCase 288 "B" "" [msg "" "--\\b[" [tc "😀" "read_file" "{\"a\":1}", tc "" "" "é"] "é" [], msg "é" "" [tc "" "" "make[3]"] "" []]
  runCase 289 "L" "sha256:e3b0" [msg "tool" "😀\\3:23b[" [tc "😀" "bash" "make[3]", tc "a" "" ""] "a" [im "" ""]]
  runCase 290 "E" "" [msg "assistant" "list the files" [tc "😀" "read_file" ""] "a" [], msg "assistant" "[\"a\"]" [tc "a" "" "é"] "call_1" []]
  runCase 291 "B" "" []
  runCase 292 "B" "" [msg "é" "im-end;" [tc "é" "bash" "make[3]"] "a" []]
  runCase 293 "E" "" [msg "é" "x‍😀" [] "" [im "file:///tmp/a.png" "image/png"], msg "" "b2\n" [] "a" [im "" "image/jpeg"]]
  runCase 294 "B" "" [msg "user" "make[0]" [] "é" [im "data:image/png;base64,AAAA" ""]]
  runCase 295 "E" "" [msg "system" "\"quoted\"" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/jpeg"], msg "user" "" [tc "😀" "bash" "{}"] "" []]
  runCase 296 "E" "" [msg "tool" "-😀ém]😀1\"-1" [tc "a" "日本" "make[3]", tc "é" "日本" "{\"a\":1}"] "" [], msg "" "}m{" [] "call_1" []]
  runCase 297 "L" "é😀" []
  runCase 298 "E" "" [msg "" "x‍😀" [tc "call_1" "read_file" ""] "é" []]
  runCase 299 "B" "" [msg "user" "á" [] "call_1" [im "file:///tmp/a.png" "image/png", im "" ""], msg "user" "日本" [tc "" "read_file" "", tc "call_1" "" "make[3]"] "😀" [], msg "user" "make[21]" [tc "é" "" "é"] "é" [im "data:image/png;base64,AAAA" "", im "é" "image/jpeg"]]
  runCase 300 "L" "sha256:e3b0" [msg "" "[\"a\"]" [tc "call_1" "" "é"] "😀" [], msg "é" "😀" [tc "😀" "read_file" "make[3]"] "😀" []]
  runCase 301 "B" "" [msg "" "é00\n2[é" [] "😀" [], msg "tool" "make[0]" [] "call_1" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 302 "E" "" [msg "" "b" [tc "call_1" "read_file" "{\"a\":1}"] "😀" []]
  runCase 303 "B" "" [msg "tool" "sha256:" [tc "call_1" "read_file" "{\"a\":1}"] "😀" [], msg "system" "m{role:4:user;}" [tc "a" "read_file" ""] "call_1" [im "data:image/png;base64,AAAA" ""], msg "assistant" "\"" [tc "😀" "" "é"] "é" [im "file:///tmp/a.png" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "assistant" "2 ]:bm \"日132" [tc "call_1" "bash" "", tc "call_1" "read_file" "é"] "é" []]
  runCase 304 "E" "" []
  runCase 305 "L" "m-end;" [msg "assistant" " 日 b0\"a😀\"3" [] "é" [], msg "tool" "á" [] "😀" []]
  runCase 306 "L" "é😀" [msg "user" "𝔘𝔫𝔦" [tc "é" "read_file" "make[3]"] "" [im "é" "image/jpeg"], msg "system" "😀" [tc "" "" "{\"a\":1}", tc "😀" "" "{}"] "call_1" [], msg "assistant" "😀" [tc "é" "日本" "é"] "a" [], msg "tool" "á" [tc "" "bash" "é", tc "call_1" "日本" "make[3]"] "call_1" []]
  runCase 307 "E" "" [msg "system" "{a  \\0]日0日a" [tc "a" "" "{\"a\":1}"] "a" [], msg "" "abba\n2" [tc "😀" "" "{}"] "😀" [im "é" ""]]
  runCase 308 "E" "" [msg "user" "make[20] and make[2]" [] "😀" [], msg "" "á" [tc "é" "read_file" "", tc "a" "" ""] "" [], msg "assistant" "\r\n" [] "" []]
  runCase 309 "E" "" [msg "user" "ü:2:ü;" [tc "call_1" "日本" "é"] "é" [im "data:image/png;base64,AAAA" "image/png"], msg "tool" "ok" [] "call_1" [im "data:image/png;base64,AAAA" ""]]
  runCase 310 "E" "" [msg "" "1\"2\"日" [tc "" "read_file" "make[3]"] "é" [], msg "assistant" "b]é日23日" [tc "" "日本" "make[3]", tc "a" "bash" "{\"a\":1}"] "😀" []]
  runCase 311 "B" "" [msg "" "make[20] and make[2]" [tc "" "" "{}"] "é" [], msg "system" "{}" [tc "a" "日本" "", tc "é" "" "é"] "" [], msg "system" "é" [] "" [im "data:image/png;base64,AAAA" ""], msg "tool" "" [] "😀" []]
  runCase 312 "B" "" []
  runCase 313 "E" "" [msg "system" "line\nbreak" [tc "a" "bash" "{}"] "😀" []]
  runCase 314 "B" "" [msg "é" "make[0]" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/jpeg"], msg "tool" " " [tc "😀" "read_file" "{}"] "é" [], msg "tool" "ü:2:ü;" [] "😀" [], msg "" "-é" [] "a" [im "" "image/jpeg"]]
  runCase 315 "L" "m-end;" [msg "system" "make[0]" [] "a" [], msg "" "\"quoted\"" [tc "" "日本" "é"] "" []]
  runCase 316 "B" "" [msg "tool" "im-end;" [] "é" [], msg "system" " nbsp" [] "😀" [], msg "user" "😀" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" ""], msg "tool" "ok" [tc "a" "bash" "{\"a\":1}", tc "😀" "read_file" "é"] "a" [im "é" "image/png", im "" ""]]
  runCase 317 "E" "" [msg "tool" "\"\"-" [] "a" [], msg "tool" "line\nbreak" [tc "" "日本" "", tc "" "日本" "{\"a\":1}"] "😀" [im "é" "", im "" "image/png"]]
  runCase 318 "E" "" [msg "tool" "make[21]" [] "" [im "" "image/jpeg"], msg "user" "x‍😀" [] "é" [im "" ""], msg "user" " {:\n1" [tc "a" "bash" "make[3]", tc "call_1" "日本" "{\"a\":1}"] "" [im "data:image/png;base64,AAAA" "", im "é" "image/png"]]
  runCase 319 "E" "" [msg "assistant" "á" [tc "call_1" "read_file" "make[3]"] "" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "" [tc "😀" "日本" "make[3]"] "a" [], msg "system" "{}" [tc "call_1" "read_file" "make[3]", tc "é" "" ""] "😀" [], msg "user" "list the files" [] "a" []]

#eval show IO Unit from do
  runCase 320 "B" "" [msg "assistant" "日本語" [] "é" [], msg "é" "á" [tc "😀" "read_file" "make[3]"] "😀" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" ""]]
  runCase 321 "E" "" [msg "" "x‍😀" [tc "😀" "bash" ""] "a" [im "data:image/png;base64,AAAA" "image/png"], msg "system" "2\n-😀" [] "😀" []]
  runCase 322 "E" "" [msg "" ";{mé]😀\";\"]" [] "é" [im "file:///tmp/a.png" ""], msg "tool" "}m{" [tc "😀" "日本" "{}"] "é" [im "é" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 323 "B" "" []
  runCase 324 "B" "" []
  runCase 325 "L" "x" [msg "" "0\\[0" [tc "é" "bash" "make[3]"] "é" [], msg "é" "a é0" [] "a" []]
  runCase 326 "L" "sha256:e3b0" [msg "assistant" "𝔘𝔫𝔦" [] "a" [], msg "user" "make[20] and make[2]" [] "a" [], msg "" "\n\"" [] "call_1" [im "file:///tmp/a.png" ""]]
  runCase 327 "L" "x" [msg "user" "you are motoko" [tc "😀" "日本" "{}"] "😀" [], msg "assistant" "á" [tc "call_1" "" "make[3]"] "é" [], msg "assistant" "é" [tc "é" "bash" "make[3]"] "" [im "" ""], msg "assistant" "-\":;éa;bb" [] "call_1" []]
  runCase 328 "E" "" [msg "tool" "é" [] "😀" [], msg "tool" " nbsp" [tc "" "" ""] "é" [im "é" "image/jpeg"]]
  runCase 329 "L" "sha256:e3b0" [msg "tool" " \n2bé}a2é" [] "😀" []]
  runCase 330 "B" "" [msg "é" ":;1日" [tc "a" "日本" "make[3]", tc "a" "bash" "{\"a\":1}"] "a" [im "é" "image/jpeg", im "é" ""], msg "é" "back\\slash" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/jpeg"]]
  runCase 331 "E" "" [msg "assistant" ":\"\n\n" [tc "" "日本" ""] "call_1" []]
  runCase 332 "L" "sha256:" [msg "é" "x:3:y;" [] "é" [], msg "" "á" [tc "call_1" "bash" "{\"a\":1}", tc "" "bash" "é"] "😀" [im "é" ""], msg "system" "\"quoted\"" [] "call_1" [], msg "assistant" "sha256:" [] "" []]
  runCase 333 "L" "m-end;" [msg "assistant" "list the files" [] "é" [im "é" "", im "" ""]]
  runCase 334 "E" "" [msg "tool" "" [] "call_1" [im "" "image/png", im "data:image/png;base64,AAAA" ""], msg "user" "\n" [tc "call_1" "" ""] "call_1" [im "" "image/jpeg"]]
  runCase 335 "E" "" [msg "user" "list the files" [tc "" "read_file" "{}"] "😀" [], msg "tool" "\\}\"日0" [] "😀" [], msg "system" "line\nbreak" [] "😀" []]
  runCase 336 "B" "" [msg "user" "}m{" [] "a" [], msg "system" "im-end;" [] "😀" [], msg "assistant" " nbsp" [tc "é" "" "{}"] "é" []]
  runCase 337 "L" "sha256:" [msg "é" "line\nbreak" [tc "é" "bash" "{\"a\":1}"] "😀" [im "data:image/png;base64,AAAA" ""], msg "assistant" "😀" [] "" [im "data:image/png;base64,AAAA" ""]]
  runCase 338 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "system" "ok" [] "é" [], msg "user" "\n{}" [] "a" [], msg "system" "é" [tc "call_1" "日本" "{}"] "" [im "file:///tmp/a.png" "image/png"]]
  runCase 339 "B" "" [msg "tool" "you are motoko" [] "😀" [], msg "user" "x:3:y;" [] "😀" []]
  runCase 340 "B" "" [msg "" "im-end;" [tc "é" "read_file" "{\"a\":1}"] "call_1" [], msg "system" ":--}日3]2:;m" [] "" [], msg "tool" "[\"a\"]" [] "😀" [im "é" "image/jpeg", im "file:///tmp/a.png" ""]]
  runCase 341 "E" "" [msg "" "\n2" [tc "😀" "" "{\"a\":1}", tc "" "日本" "make[3]"] "" []]
  runCase 342 "E" "" []
  runCase 343 "L" "sha256:" [msg "system" "tc-end;" [] "a" [], msg "tool" "ü:2:ü;" [] "" []]
  runCase 344 "E" "" [msg "assistant" "sha256:" [] "😀" [im "" "image/jpeg"], msg "assistant" "make[12]make[3]" [tc "é" "bash" "é"] "é" [], msg "assistant" "a[b\"a;]{3" [tc "é" "read_file" "é"] "call_1" [], msg "assistant" "ü:2:ü;" [tc "call_1" "read_file" "é", tc "😀" "read_file" "{\"a\":1}"] "" []]
  runCase 345 "L" "m-end;" [msg "" "0: m1" [] "call_1" [], msg "assistant" "\r\n" [] "😀" [], msg "system" "" [tc "é" "read_file" "é"] "" []]
  runCase 346 "L" "sha256:" [msg "assistant" "make[0]" [] "é" [], msg "é" "hi" [tc "a" "日本" "make[3]"] "😀" [im "data:image/png;base64,AAAA" "", im "é" ""]]
  runCase 347 "L" "sha256:" [msg "é" "á" [tc "a" "bash" "{\"a\":1}", tc "a" "read_file" "é"] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/png"], msg "é" "make[21]" [] "😀" [], msg "" "};a2-]{" [] "é" [], msg "" "á" [tc "😀" "日本" ""] "" []]
  runCase 348 "E" "" [msg "system" "b{b\n32é;][" [tc "😀" "read_file" "make[3]", tc "call_1" "" "{\"a\":1}"] "a" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""], msg "" "ü:2:ü;" [tc "" "日本" "{}", tc "a" "日本" "{}"] "" [im "data:image/png;base64,AAAA" "image/png", im "é" ""]]
  runCase 349 "E" "" [msg "user" "𝔘𝔫𝔦" [tc "call_1" "" "{\"a\":1}"] "é" [im "" "image/png"], msg "é" "ü:2:ü;" [] "a" [], msg "system" "{}" [] "😀" [im "" "", im "data:image/png;base64,AAAA" ""], msg "assistant" "x:3:y;" [] "é" [im "" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 350 "B" "" [msg "tool" "make[1]" [tc "a" "read_file" "é", tc "😀" "" "make[3]"] "é" [im "file:///tmp/a.png" "", im "é" "image/jpeg"]]
  runCase 351 "E" "" [msg "é" "make[20] and make[2]" [tc "é" "" "{}", tc "a" "read_file" "{\"a\":1}"] "é" [], msg "" "á" [] "call_1" []]
  runCase 352 "L" "é😀" [msg "é" "im-end;" [tc "😀" "" "é", tc "a" "日本" "{\"a\":1}"] "😀" [im "data:image/png;base64,AAAA" ""]]
  runCase 353 "L" "x" [msg "tool" "]{a0" [tc "call_1" "日本" "{\"a\":1}"] "call_1" [], msg "assistant" "é\"m😀:b\"\\;0;" [] "😀" [], msg "system" "bb" [] "" [im "" "image/jpeg"], msg "tool" "😀" [] "call_1" []]
  runCase 354 "E" "" [msg "" "you are motoko" [tc "😀" "" "{\"a\":1}"] "😀" [im "é" "image/png", im "file:///tmp/a.png" ""], msg "" "make[1]" [] "a" []]
  runCase 355 "B" "" [msg "system" "3\\0]" [] "" [im "file:///tmp/a.png" "image/png"], msg "system" "b;-0日éb] " [] "" [im "é" ""]]
  runCase 356 "E" "" [msg "" "" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 357 "B" "" [msg "system" "back\\slash" [tc "" "日本" "{}", tc "a" "日本" "é"] "é" [], msg "system" "b[" [] "" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"]]
  runCase 358 "E" "" [msg "user" "\"[[ " [] "call_1" [], msg "system" ":3日1]" [tc "é" "bash" "{\"a\":1}", tc "call_1" "bash" "make[3]"] "call_1" []]
  runCase 359 "E" "" [msg "assistant" "make[20] and make[2]" [tc "" "日本" "é"] "😀" [im "" "", im "" "image/jpeg"], msg "tool" "2日}日b" [tc "é" "" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/png"]]

#eval show IO Unit from do
  runCase 360 "E" "" [msg "assistant" "日;];30\"2" [tc "" "bash" "make[3]"] "é" []]
  runCase 361 "B" "" [msg "tool" "make[0]" [tc "" "bash" "make[3]"] "é" [], msg "assistant" "make[21]" [] "" []]
  runCase 362 "B" "" [msg "" "" [tc "" "read_file" "é", tc "call_1" "" "{\"a\":1}"] "é" [im "" "image/jpeg"]]
  runCase 363 "E" "" [msg "system" "tc-end;" [tc "😀" "bash" ""] "" [im "é" "image/jpeg", im "é" "image/png"], msg "assistant" "日[\" 😀" [] "" [], msg "system" "make[0]" [] "call_1" [], msg "" "x‍😀" [] "call_1" [im "é" "image/png", im "file:///tmp/a.png" ""]]
  runCase 364 "E" "" [msg "" "\"quoted\"" [tc "call_1" "bash" "{\"a\":1}"] "a" [], msg "system" "tc-end;" [] "😀" [], msg "assistant" "ü:2:ü;" [tc "😀" "日本" "{\"a\":1}"] "call_1" [], msg "system" "line\nbreak" [tc "a" "" "{\"a\":1}"] "a" []]
  runCase 365 "E" "" [msg "assistant" "á" [tc "😀" "" "{\"a\":1}"] "é" [], msg "assistant" "ok" [] "call_1" []]
  runCase 366 "E" "" [msg "assistant" "make[20] and make[2]" [] "é" [], msg "" "make[1]" [tc "a" "read_file" "é"] "é" [], msg "é" "日-2 \\;1 a" [tc "" "日本" ""] "é" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""]]
  runCase 367 "L" "sha256:e3b0" [msg "" "ok" [] "é" [], msg "tool" "éé:a[aa0a[" [tc "" "日本" "make[3]"] "a" []]
  runCase 368 "E" "" [msg "user" "é" [] "call_1" [], msg "tool" ";221{m}01" [] "é" [im "file:///tmp/a.png" "image/png"], msg "system" " nbsp" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg", im "" ""], msg "tool" "1a[ 2[ 3;b" [tc "" "" "{\"a\":1}"] "a" [im "é" "image/png"]]
  runCase 369 "L" "é😀" [msg "é" "" [tc "é" "bash" "{}"] "a" [], msg "tool" "𝔘𝔫𝔦" [] "é" []]
  runCase 370 "B" "" [msg "assistant" "tc-end;" [] "" [], msg "tool" "á" [tc "a" "bash" "{\"a\":1}"] "é" []]
  runCase 371 "L" "sha256:" [msg "é" "tab\there" [tc "😀" "" "{}", tc "call_1" "" ""] "a" [], msg "tool" "2]321éb" [tc "😀" "bash" "é"] "a" [im "é" ""]]
  runCase 372 "E" "" [msg "user" "back\\slash" [tc "é" "bash" "{}"] "" []]
  runCase 373 "L" "sha256:e3b0" [msg "é" "𝔘𝔫𝔦" [tc "call_1" "日本" "{\"a\":1}"] "😀" [im "" "image/jpeg", im "é" ""], msg "system" "make[1make[2]]" [] "call_1" []]
  runCase 374 "L" "sha256:" [msg "system" "x‍😀" [] "😀" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/png"], msg "system" "日:;03b}0 [;" [tc "😀" "read_file" "make[3]"] "" [im "" ""]]
  runCase 375 "E" "" [msg "tool" "[\"a\"]" [tc "call_1" "日本" "{}"] "é" []]
  runCase 376 "B" "" []
  runCase 377 "B" "" [msg "é" "1\"\"mé3b{][\\;" [] "" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 378 "L" "é😀" [msg "é" "make[20] and make[2]" [] "" [im "é" ""]]
  runCase 379 "E" "" [msg "user" "list the files" [] "😀" [], msg "tool" "" [tc "" "日本" "é"] "" [], msg "user" "{}" [tc "a" "日本" "é"] "call_1" [im "é" "", im "é" "image/jpeg"], msg "user" "make[1]" [tc "😀" "bash" "{}", tc "" "" "{}"] "😀" [im "é" "image/png"]]
  runCase 380 "L" "sha256:e3b0" [msg "system" "日{ 33{日" [tc "a" "日本" "make[3]"] "a" [im "é" "image/png"]]
  runCase 381 "E" "" [msg "system" "im-end;" [] "a" [im "" ""], msg "é" ":m😀2;]\\:\\:" [tc "call_1" "read_file" "{\"a\":1}"] "" [], msg "é" "{}" [tc "call_1" "read_file" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "image/png", im "" "image/jpeg"]]
  runCase 382 "E" "" [msg "" "éx" [tc "a" "" "{\"a\":1}"] "" [im "é" "image/png", im "file:///tmp/a.png" ""], msg "assistant" "😀\\}é [\"}02-" [] "call_1" []]
  runCase 383 "L" "" [msg "é" "ok" [] "call_1" []]
  runCase 384 "B" "" [msg "é" "" [tc "a" "bash" "{\"a\":1}", tc "" "read_file" "{\"a\":1}"] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/jpeg"], msg "assistant" "make[20] and make[2]" [] "😀" [], msg "system" "}m{" [] "😀" [], msg "user" "x‍😀" [] "é" [im "é" ""]]
  runCase 385 "E" "" [msg "é" "back\\slash" [tc "call_1" "" "", tc "call_1" "日本" "é"] "call_1" [], msg "é" "éx" [] "😀" [im "é" "image/jpeg", im "é" "image/png"], msg "user" "make[1make[2]]" [] "é" [im "" "", im "" "image/png"]]
  runCase 386 "E" "" [msg "assistant" "é{-b}3日[{{\\" [tc "" "日本" "make[3]"] "a" [], msg "user" "é" [tc "" "read_file" "make[3]"] "" [im "" "image/jpeg"]]
  runCase 387 "E" "" [msg "system" "tab\there" [tc "😀" "" "é"] "😀" [], msg "" "\n[0" [] "" [im "" "image/png"]]
  runCase 388 "B" "" [msg "é" "\"quoted\"" [] "é" [], msg "tool" "make[12]make[3]" [] "a" [], msg "system" "x:3:y;" [tc "call_1" "bash" "é"] "call_1" [], msg "tool" "[\\;{a}2m]}\n3" [tc "😀" "" ""] "a" []]
  runCase 389 "B" "" [msg "user" "ü:2:ü;" [] "a" [im "" "image/jpeg", im "file:///tmp/a.png" ""], msg "é" "😀" [] "call_1" []]
  runCase 390 "B" "" [msg "tool" ":b{]" [] "call_1" [], msg "assistant" "21{b\\ é;:" [tc "😀" "日本" "{}"] "é" [im "file:///tmp/a.png" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "tool" "日本" [tc "😀" "" "", tc "" "read_file" "é"] "" []]
  runCase 391 "L" "" [msg "system" "you are motoko" [tc "" "日本" "{}", tc "call_1" "read_file" ""] "😀" [im "file:///tmp/a.png" ""], msg "tool" "}é日b;" [tc "call_1" "" "make[3]"] "" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 392 "E" "" [msg "tool" "make[1make[2]]" [tc "call_1" "日本" "{}"] "a" [im "data:image/png;base64,AAAA" ""]]
  runCase 393 "B" "" [msg "tool" "b" [] "" [], msg "system" "" [] "a" [im "é" "image/png"]]
  runCase 394 "B" "" [msg "tool" "list the files" [tc "é" "read_file" "make[3]"] "😀" [], msg "tool" " nbsp" [] "é" []]
  runCase 395 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "tc-end;" [] "😀" [], msg "é" "list the files" [tc "call_1" "read_file" "{}"] "😀" [im "" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "make[1]" [tc "a" "" ""] "" [im "" "image/jpeg"]]
  runCase 396 "E" "" [msg "" "line\nbreak" [] "call_1" []]
  runCase 397 "B" "" [msg "user" "ü:2:ü;" [] "" [im "" ""], msg "tool" "😀" [] "😀" [], msg "user" "x‍😀" [tc "é" "bash" "{\"a\":1}", tc "call_1" "bash" ""] "é" [], msg "" "{}" [tc "😀" "bash" ""] "call_1" [im "file:///tmp/a.png" "image/png", im "" ""]]
  runCase 398 "B" "" [msg "user" "line\nbreak" [tc "é" "bash" "", tc "😀" "" "make[3]"] "a" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" ""], msg "user" "x:3:y;" [tc "" "日本" "make[3]", tc "é" "日本" ""] "a" [], msg "assistant" "" [tc "😀" "bash" "{}"] "😀" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""]]
  runCase 399 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" ";00]2a\\\\" [] "call_1" []]
