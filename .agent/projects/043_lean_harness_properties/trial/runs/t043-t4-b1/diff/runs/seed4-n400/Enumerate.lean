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
GENERATED by gen_cases.py (seed 4, 400 cases). The Lean half of the differential test:
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
  runCase 10 "E" "" [msg "system" "list the files" [] "" [im "file:///tmp/a.png" "image/png"]]
  runCase 11 "E" "" [msg "" "m" [] "" [], msg "assistant" "line\nbreak" [tc "call_1" "bash" "make[3]", tc "call_1" "日本" "make[3]"] "a" []]
  runCase 12 "E" "" [msg "assistant" "x‍😀" [] "" [], msg "" "sha256:" [tc "a" "日本" "é"] "😀" []]
  runCase 13 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "" [] "" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 14 "L" "m-end;" [msg "user" "😀" [] "é" []]
  runCase 15 "E" "" [msg "tool" "}m{" [] "call_1" []]
  runCase 16 "E" "" [msg "user" "ü:2:ü;" [] "" [], msg "user" "é" [tc "" "" "", tc "" "" ""] "call_1" [], msg "é" ":0 [日0{m3" [tc "a" "" "make[3]"] "" []]
  runCase 17 "E" "" [msg "user" "\\;日[" [tc "a" "bash" "{}"] "" [], msg "é" "ok" [tc "" "日本" "make[3]"] "a" []]
  runCase 18 "E" "" []
  runCase 19 "B" "" [msg "tool" "make[20] and make[2]" [] "é" [im "é" "image/png"], msg "user" "𝔘𝔫𝔦" [tc "a" "日本" "{\"a\":1}"] "" [], msg "assistant" "sha256:" [] "é" [], msg "user" "\\;\\3-" [tc "" "日本" "é", tc "" "日本" "{\"a\":1}"] "😀" []]
  runCase 20 "B" "" [msg "é" "é\n[-m" [] "é" [im "" ""]]
  runCase 21 "E" "" []
  runCase 22 "L" "é😀" [msg "assistant" "make[1]" [tc "é" "日本" "é", tc "é" "read_file" "{}"] "a" []]
  runCase 23 "E" "" [msg "assistant" "3]\"b[} 1\"😀\n日" [] "" [], msg "é" "ü:2:ü;" [] "😀" []]
  runCase 24 "E" "" [msg "system" "" [] "call_1" []]
  runCase 25 "E" "" [msg "tool" "3]😀3" [] "" [], msg "" "😀" [tc "é" "bash" "{\"a\":1}"] "call_1" [im "é" "image/png"]]
  runCase 26 "E" "" [msg "user" "x:3:y;" [] "call_1" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 27 "B" "" []
  runCase 28 "E" "" [msg "é" "m{role:4:user;}" [] "é" [], msg "assistant" "ü:2:ü;" [tc "" "bash" "make[3]", tc "call_1" "日本" "make[3]"] "call_1" [im "é" "image/jpeg", im "é" ""]]
  runCase 29 "E" "" [msg "" "ok" [tc "" "read_file" "make[3]"] "a" []]
  runCase 30 "B" "" [msg "" "𝔘𝔫𝔦" [] "" [im "data:image/png;base64,AAAA" ""]]
  runCase 31 "B" "" [msg "user" "" [tc "" "" "{}"] "a" []]
  runCase 32 "L" "m-end;" [msg "system" "}" [tc "é" "read_file" "make[3]", tc "call_1" "日本" "make[3]"] "a" [im "data:image/png;base64,AAAA" ""], msg "assistant" "line\nbreak" [tc "é" "日本" "make[3]"] "é" []]
  runCase 33 "B" "" [msg "tool" "𝔘𝔫𝔦" [tc "é" "" "é"] "é" [im "" "image/png", im "" ""], msg "é" "make[1make[2]]" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 34 "L" "é😀" [msg "system" "make[1make[2]]" [] "" [], msg "tool" "}m{" [tc "😀" "" "{}", tc "😀" "read_file" "{\"a\":1}"] "" [], msg "system" "make[0]" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" ":\"2a\"{\né{[0" [tc "😀" "bash" "é"] "a" []]
  runCase 35 "B" "" [msg "tool" "日本語" [] "a" [im "" ""], msg "system" "make[1make[2]]" [] "" []]
  runCase 36 "E" "" [msg "" "}m{" [] "é" [im "data:image/png;base64,AAAA" "", im "é" ""], msg "user" "you are motoko" [tc "😀" "" ""] "é" [im "" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "" "make[1make[2]]" [tc "call_1" "bash" "{\"a\":1}"] "call_1" [], msg "é" "make[12]make[3]" [tc "é" "" "{}"] "a" []]
  runCase 37 "L" "é😀" [msg "" "tab\there" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/png"], msg "" "a:] m ab" [] "é" []]
  runCase 38 "E" "" [msg "user" "3- 3" [] "a" [im "é" "image/png"]]
  runCase 39 "B" "" [msg "é" "\"quoted\"" [tc "call_1" "read_file" "{\"a\":1}"] "" [im "é" ""], msg "assistant" "line\nbreak" [tc "call_1" "read_file" ""] "call_1" [im "" "image/png", im "é" ""]]

#eval show IO Unit from do
  runCase 40 "B" "" [msg "é" "}" [tc "" "read_file" ""] "a" [im "" "image/jpeg"], msg "assistant" "x‍😀" [] "a" [], msg "user" "{}" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/jpeg"]]
  runCase 41 "E" "" [msg "é" "éx" [tc "a" "" "{}", tc "😀" "" ""] "😀" [], msg "user" "hi" [] "" [], msg "é" "x:3:y;" [] "a" []]
  runCase 42 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "😀" [tc "é" "bash" "{}", tc "a" "read_file" ""] "a" [], msg "user" "232\";][2}" [tc "a" "bash" "{}"] "" []]
  runCase 43 "B" "" [msg "é" "b03}{3 " [tc "call_1" "" "{}"] "é" [], msg "tool" "\r\n" [] "" [], msg "assistant" "list the files" [tc "a" "bash" "{\"a\":1}"] "😀" [], msg "" "tab\there" [] "é" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 44 "E" "" [msg "system" "make[21]" [tc "call_1" "" "{\"a\":1}"] "call_1" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"], msg "system" "ü:2:ü;" [] "é" [im "" "image/png"]]
  runCase 45 "E" "" [msg "user" "[\"a\"]" [] "😀" []]
  runCase 46 "E" "" [msg "system" "}m{" [] "call_1" [im "" "", im "é" ""], msg "user" "b{0éba2\n" [tc "call_1" "bash" "{\"a\":1}"] "é" [], msg "tool" "make[20] and make[2]" [tc "a" "read_file" "{\"a\":1}", tc "" "bash" "{}"] "" []]
  runCase 47 "L" "" []
  runCase 48 "B" "" [msg "user" "}m{" [] "" [], msg "user" "you are motoko" [tc "call_1" "" ""] "a" [im "" "image/jpeg", im "" "image/jpeg"], msg "system" "-é0\\2{\n2" [tc "é" "read_file" "make[3]"] "é" []]
  runCase 49 "L" "m-end;" [msg "" "x‍😀" [tc "a" "" "make[3]"] "😀" [im "é" "", im "data:image/png;base64,AAAA" ""], msg "user" "make[12]make[3]" [tc "a" "日本" "make[3]", tc "call_1" "" ""] "a" []]
  runCase 50 "E" "" [msg "user" "[\"a\"]" [] "a" [im "" ""], msg "system" "" [tc "😀" "read_file" "{\"a\":1}", tc "a" "" "é"] "é" [], msg "é" "\n:1b" [] "a" [], msg "tool" "éx" [tc "" "read_file" ""] "call_1" [im "file:///tmp/a.png" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"]]
  runCase 51 "B" "" [msg "system" "x:3:y;" [] "😀" [im "" ""]]
  runCase 52 "E" "" []
  runCase 53 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "you are motoko" [] "a" [im "é" "image/jpeg"], msg "assistant" "303;1" [tc "😀" "bash" "é"] "é" []]
  runCase 54 "E" "" [msg "" "you are motoko" [] "😀" [], msg "" "tab\there" [tc "a" "read_file" "é", tc "a" "" "é"] "é" [im "" ""]]
  runCase 55 "E" "" [msg "é" "𝔘𝔫𝔦" [tc "call_1" "read_file" "{\"a\":1}", tc "call_1" "" "{\"a\":1}"] "call_1" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "tool" "m{role:4:user;}" [] "é" [], msg "" "line\nbreak" [tc "a" "bash" "é"] "😀" [], msg "user" "éx" [] "a" []]
  runCase 56 "B" "" [msg "tool" "hi" [tc "" "bash" "é", tc "" "read_file" "{\"a\":1}"] "é" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "user" "éx" [tc "a" "read_file" "{}"] "😀" [im "file:///tmp/a.png" ""], msg "assistant" "\"quoted\"" [] "" [im "file:///tmp/a.png" "", im "" "image/png"], msg "assistant" "sha256:" [tc "" "read_file" "{\"a\":1}"] "" [im "é" ""]]
  runCase 57 "E" "" [msg "é" "ok" [tc "é" "日本" "make[3]", tc "é" "bash" "{\"a\":1}"] "a" [], msg "user" " nbsp" [tc "é" "日本" ""] "😀" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "assistant" "日本語" [tc "😀" "" "", tc "" "read_file" "make[3]"] "a" [], msg "é" "ok" [tc "a" "read_file" "make[3]", tc "" "bash" ""] "" []]
  runCase 58 "L" "m-end;" []
  runCase 59 "E" "" [msg "assistant" ";m\\" [tc "call_1" "" "{}"] "" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 60 "E" "" [msg "tool" "[😀]}}1b[[\"日" [tc "call_1" "read_file" "make[3]"] "a" [], msg "" "21:日😀mm" [] "" [], msg "é" "\n-😀日:m2\";" [tc "call_1" "bash" "{\"a\":1}"] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" ""]]
  runCase 61 "E" "" []
  runCase 62 "B" "" [msg "é" "make[20] and make[2]" [tc "é" "" "é"] "call_1" []]
  runCase 63 "L" "x" [msg "é" "x‍😀" [] "😀" [], msg "é" "x:3:y;" [] "call_1" [], msg "user" "é2]2日2" [tc "😀" "bash" "é"] "a" []]
  runCase 64 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "\n22\\;}{" [] "😀" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"]]
  runCase 65 "E" "" [msg "é" "aéém😀}a;{ém\"" [tc "" "" ""] "😀" [im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "make[12]make[3]" [] "😀" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" "image/jpeg"], msg "system" "x:3:y;" [tc "call_1" "日本" "{}"] "é" [im "é" "image/jpeg"]]
  runCase 66 "L" "é😀" [msg "é" "make[1make[2]]" [] "call_1" []]
  runCase 67 "L" "m-end;" [msg "" "[0\"3m\"日\n1b1" [tc "é" "" "make[3]"] "call_1" [], msg "user" "list the files" [] "é" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 68 "L" "é😀" [msg "" "日本語" [] "call_1" []]
  runCase 69 "B" "" [msg "user" "x:3:y;" [tc "a" "bash" ""] "😀" [], msg "user" "back\\slash" [] "" [im "" "", im "file:///tmp/a.png" "image/png"]]
  runCase 70 "B" "" [msg "assistant" "x‍😀" [tc "" "日本" "é"] "😀" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "{\"0日--\\}}]日[" [tc "é" "read_file" "make[3]", tc "" "" "{\"a\":1}"] "😀" [], msg "" "tab\there" [] "call_1" [im "" "image/png"]]
  runCase 71 "B" "" [msg "assistant" "make[1make[2]]" [tc "a" "read_file" "make[3]", tc "" "" "{}"] "" [], msg "user" "\\m" [] "" []]
  runCase 72 "B" "" [msg "assistant" "𝔘𝔫𝔦" [] "😀" [], msg "assistant" "0b\na\"日ma\n2" [] "call_1" [im "" "image/jpeg", im "é" "image/jpeg"], msg "system" "x:3:y;" [tc "é" "" "make[3]"] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 73 "B" "" [msg "" "{é[\"" [tc "call_1" "bash" "{\"a\":1}"] "é" [], msg "é" ";};:😀{3" [tc "" "read_file" "{\"a\":1}"] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "system" "[0:\\" [tc "" "日本" "é", tc "é" "" "make[3]"] "é" [], msg "system" "sha256:" [tc "é" "" ""] "call_1" []]
  runCase 74 "B" "" [msg "tool" "ü:2:ü;" [tc "call_1" "日本" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" ""]]
  runCase 75 "E" "" [msg "system" "make[21]" [tc "😀" "bash" "make[3]"] "call_1" [im "é" "image/jpeg"], msg "" "x‍😀" [] "a" []]
  runCase 76 "E" "" [msg "tool" "😀" [] "a" []]
  runCase 77 "E" "" [msg "" "3ma13[30{" [tc "a" "" "{}"] "" [], msg "system" "back\\slash" [] "a" [], msg "assistant" "-\n a0日-日2" [tc "a" "日本" ""] "é" [im "file:///tmp/a.png" "image/png"], msg "tool" "𝔘𝔫𝔦" [tc "" "read_file" "{}", tc "é" "" ""] "a" [im "é" "image/png", im "file:///tmp/a.png" ""]]
  runCase 78 "L" "é😀" [msg "user" "ok" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/png"], msg "user" "x:3:y;" [] "" [], msg "system" "{}" [tc "" "read_file" "{\"a\":1}"] "call_1" [im "" "image/jpeg"], msg "user" "\\日a\\😀\\0é]😀}" [tc "é" "日本" "make[3]"] "" []]
  runCase 79 "B" "" [msg "" "you are motoko" [] "" []]

#eval show IO Unit from do
  runCase 80 "E" "" [msg "" "}é\"{😀日-é" [tc "call_1" "bash" ""] "a" [im "é" "image/png"], msg "é" "make[21]" [tc "call_1" "" "{}"] "" [], msg "tool" "" [] "é" [im "é" "image/png"], msg "" "é{2\n\nm0  😀\né" [tc "é" "read_file" "{\"a\":1}"] "" []]
  runCase 81 "L" "x" [msg "" "é" [] "😀" [im "" "image/jpeg"]]
  runCase 82 "B" "" [msg "tool" " 3\n0 {a3\n{{;" [tc "call_1" "" "{}"] "é" [], msg "" "😀" [tc "é" "read_file" "{}"] "" []]
  runCase 83 "E" "" [msg "" "m{role:4:user;}" [] "call_1" []]
  runCase 84 "B" "" [msg "" "x‍😀" [tc "a" "read_file" "make[3]"] "" []]
  runCase 85 "E" "" [msg "user" "make[1]" [tc "call_1" "read_file" "make[3]"] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 86 "B" "" []
  runCase 87 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "é" "line\nbreak" [] "a" []]
  runCase 88 "E" "" [msg "assistant" "x‍😀" [] "" [], msg "system" "日0" [] "a" [im "data:image/png;base64,AAAA" "", im "" ""], msg "user" "-1m1b{3;a\"" [] "call_1" [], msg "user" "x‍😀" [] "é" [im "" "", im "é" ""]]
  runCase 89 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "system" "" [] "a" [], msg "user" ":\né 日日{" [tc "😀" "read_file" "{\"a\":1}"] "call_1" [], msg "assistant" "\n\n" [] "" []]
  runCase 90 "B" "" [msg "" "-mmm" [tc "call_1" "bash" "make[3]"] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 91 "E" "" [msg "é" "\"quoted\"" [] "é" [], msg "system" "𝔘𝔫𝔦" [] "" [im "" "image/jpeg"], msg "user" "[a31{m\n2\\;" [] "" []]
  runCase 92 "B" "" []
  runCase 93 "L" "" [msg "" "\"quoted\"" [] "😀" [im "file:///tmp/a.png" ""], msg "user" "😀3😀;\\" [] "é" [im "é" "", im "" "image/png"], msg "tool" "é" [] "😀" []]
  runCase 94 "E" "" [msg "user" ":{{\n0😀0{\n日1\\" [] "call_1" [im "" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" " nbsp" [tc "a" "read_file" "make[3]", tc "call_1" "bash" "make[3]"] "" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 95 "E" "" [msg "user" " é\n3:" [tc "a" "read_file" "{}"] "a" [im "file:///tmp/a.png" "", im "" "image/jpeg"], msg "assistant" "make[1make[2]]" [] "é" []]
  runCase 96 "E" "" [msg "user" "" [] "😀" [], msg "assistant" "make[21]" [] "" [], msg "system" "á" [] "é" []]
  runCase 97 "E" "" [msg "tool" "make[12]make[3]" [] "a" [im "file:///tmp/a.png" "", im "" "image/jpeg"], msg "assistant" "á" [tc "call_1" "read_file" "{}"] "é" []]
  runCase 98 "E" "" [msg "tool" "tab\there" [] "a" [im "file:///tmp/a.png" ""]]
  runCase 99 "B" "" [msg "system" "日本語" [tc "é" "bash" "{\"a\":1}", tc "call_1" "" "é"] "é" [im "é" "image/jpeg"]]
  runCase 100 "B" "" [msg "é" ":1b;31]" [tc "😀" "日本" "é"] "é" [], msg "" "[02mb::;" [] "call_1" [im "" "image/png", im "file:///tmp/a.png" ""]]
  runCase 101 "E" "" [msg "é" "0]}" [tc "" "日本" "{\"a\":1}"] "😀" []]
  runCase 102 "B" "" [msg "" "𝔘𝔫𝔦" [] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""]]
  runCase 103 "L" "" [msg "tool" "make[1make[2]]" [] "😀" [im "file:///tmp/a.png" "image/jpeg"], msg "é" " nbsp" [tc "é" "日本" "make[3]"] "é" [im "é" "image/png"], msg "system" "make[20] and make[2]" [] "😀" []]
  runCase 104 "E" "" [msg "" "m02\\ba{ b" [] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/png"], msg "" "á" [tc "😀" "日本" "make[3]", tc "" "日本" "é"] "é" []]
  runCase 105 "E" "" [msg "é" "-" [] "😀" [im "é" "", im "" ""], msg "é" "\r\n" [] "" [], msg "é" "" [tc "😀" "bash" "{}"] "😀" []]
  runCase 106 "B" "" [msg "system" "日本語" [tc "" "" "{}"] "é" []]
  runCase 107 "E" "" [msg "system" "x‍😀" [] "😀" [], msg "system" " nbsp" [] "a" [], msg "tool" "日本" [tc "😀" "" "{}"] "a" [im "é" "image/png", im "file:///tmp/a.png" ""]]
  runCase 108 "E" "" [msg "assistant" "line\nbreak" [tc "" "" "{}"] "" [im "" "image/jpeg"]]
  runCase 109 "L" "m-end;" []
  runCase 110 "E" "" [msg "assistant" ";23日0;\n2é" [tc "é" "read_file" "{\"a\":1}"] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "user" "hi" [] "" [], msg "assistant" "make[1make[2]]" [] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/jpeg"], msg "tool" "\"quoted\"" [] "" []]
  runCase 111 "B" "" [msg "" "á" [tc "😀" "日本" ""] "call_1" [im "é" "", im "file:///tmp/a.png" "image/png"], msg "system" "😀" [] "" [], msg "é" " nbsp" [] "😀" [im "file:///tmp/a.png" ""]]
  runCase 112 "E" "" [msg "é" "éx" [] "" [], msg "system" "}m{" [tc "é" "read_file" "{}"] "call_1" [], msg "tool" "\"quoted\"" [] "" [], msg "assistant" "{" [tc "a" "bash" "é", tc "" "read_file" "make[3]"] "é" []]
  runCase 113 "E" "" [msg "user" "é" [tc "a" "read_file" "{}", tc "call_1" "日本" "{}"] "" [], msg "assistant" "hi" [tc "call_1" "read_file" ""] "" [im "data:image/png;base64,AAAA" ""]]
  runCase 114 "E" "" [msg "" "make[12]make[3]" [] "" [], msg "user" "  2日" [] "call_1" [im "file:///tmp/a.png" "image/jpeg"], msg "user" "é{日m2😀" [tc "call_1" "" "{}"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" ""]]
  runCase 115 "E" "" [msg "user" "" [] "a" [im "é" "image/jpeg", im "" ""], msg "user" "line\nbreak" [] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "data:image/png;base64,AAAA" ""], msg "system" "tc-end;" [] "" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" ":[3" [tc "a" "日本" "é", tc "a" "日本" ""] "😀" [im "" ""]]
  runCase 116 "L" "" []
  runCase 117 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "tc-end;" [] "call_1" [], msg "user" "b日0b" [] "" [im "" ""]]
  runCase 118 "B" "" [msg "user" "make[21]" [tc "😀" "日本" "make[3]"] "😀" [], msg "é" "m{role:4:user;}" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/png"]]
  runCase 119 "E" "" [msg "" "日3" [tc "call_1" "" ""] "" [im "é" "", im "é" "image/png"]]

#eval show IO Unit from do
  runCase 120 "L" "é😀" [msg "tool" "1日😀1\"}a" [tc "a" "read_file" "{\"a\":1}", tc "call_1" "日本" ""] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "" ""], msg "system" "back\\slash" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/jpeg"], msg "é" "{" [] "call_1" []]
  runCase 121 "B" "" [msg "" "[" [tc "é" "read_file" ""] "a" []]
  runCase 122 "E" "" [msg "user" "back\\slash" [tc "call_1" "bash" "é", tc "é" "" "make[3]"] "a" [], msg "é" "日;\\ma 1--]:1" [] "call_1" []]
  runCase 123 "B" "" [msg "tool" "\"quoted\"" [tc "a" "日本" "é"] "😀" [], msg "tool" "}m{" [] "😀" []]
  runCase 124 "E" "" [msg "assistant" "x‍😀" [] "😀" [], msg "tool" "éx" [tc "a" "bash" "make[3]", tc "é" "bash" "{}"] "" [], msg "tool" "" [] "call_1" []]
  runCase 125 "B" "" [msg "assistant" "😀" [tc "" "日本" ""] "é" []]
  runCase 126 "B" "" [msg "tool" "éx" [tc "call_1" "日本" "{\"a\":1}"] "é" [], msg "é" "you are motoko" [] "a" []]
  runCase 127 "L" "é😀" []
  runCase 128 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "tab\there" [tc "" "" "make[3]", tc "😀" "read_file" "{\"a\":1}"] "a" []]
  runCase 129 "L" "" [msg "user" "make[0]" [tc "" "" "make[3]", tc "call_1" "日本" "{}"] "é" []]
  runCase 130 "E" "" []
  runCase 131 "B" "" [msg "tool" "make[21]" [tc "" "" "{\"a\":1}"] "é" []]
  runCase 132 "E" "" [msg "é" "tab\there" [tc "é" "日本" ""] "call_1" [], msg "user" " nbsp" [tc "é" "日本" "{\"a\":1}"] "" [], msg "tool" "日\"😀" [tc "é" "bash" "{}", tc "a" "日本" "é"] "call_1" [im "" "image/png", im "é" ""]]
  runCase 133 "E" "" [msg "é" "line\nbreak" [] "call_1" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" "{}" [] "" []]
  runCase 134 "E" "" [msg "tool" "tc-end;" [] "call_1" [], msg "assistant" "tc-end;" [tc "é" "read_file" ""] "é" []]
  runCase 135 "L" "é😀" [msg "é" "\\a日m😀mm\"" [] "é" [im "file:///tmp/a.png" "image/png", im "" "image/png"], msg "assistant" "" [] "call_1" []]
  runCase 136 "E" "" [msg "é" "x:3:y;" [tc "é" "bash" "make[3]"] "😀" []]
  runCase 137 "E" "" []
  runCase 138 "L" "sha256:" [msg "assistant" "im-end;" [tc "a" "日本" "make[3]", tc "call_1" "bash" "{}"] "😀" []]
  runCase 139 "L" "é😀" [msg "assistant" "make[12]make[3]" [tc "" "bash" "é", tc "" "bash" "{\"a\":1}"] "😀" [], msg "" "𝔘𝔫𝔦" [tc "" "bash" "{\"a\":1}", tc "é" "bash" ""] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "you are motoko" [] "😀" [im "é" "", im "é" "image/jpeg"]]
  runCase 140 "L" "m-end;" []
  runCase 141 "E" "" []
  runCase 142 "B" "" [msg "user" "\"m" [tc "" "" "é"] "😀" [im "file:///tmp/a.png" ""], msg "assistant" "x‍😀" [tc "😀" "read_file" "{\"a\":1}"] "call_1" []]
  runCase 143 "B" "" [msg "assistant" "éx" [tc "a" "bash" "make[3]"] "call_1" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "m{role:4:user;}" [] "call_1" []]
  runCase 144 "B" "" [msg "é" "tc-end;" [tc "call_1" "" "make[3]", tc "a" "read_file" ""] "a" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"], msg "system" "𝔘𝔫𝔦" [] "call_1" [im "file:///tmp/a.png" "image/png"], msg "tool" "{}" [] "call_1" [im "é" "image/png", im "" "image/png"], msg "user" "1[\\" [] "é" []]
  runCase 145 "B" "" []
  runCase 146 "E" "" [msg "system" "m{role:4:user;}" [] "a" [im "é" ""]]
  runCase 147 "L" "sha256:e3b0" [msg "" "" [] "é" [], msg "" "b\n\"\\::" [] "" []]
  runCase 148 "B" "" [msg "system" "make[1make[2]]" [tc "😀" "" "", tc "" "" ""] "é" [], msg "assistant" "á" [tc "😀" "read_file" "{}"] "a" []]
  runCase 149 "E" "" [msg "system" "m-{\\b" [tc "call_1" "bash" "é"] "é" [im "" "image/jpeg", im "é" "image/jpeg"]]
  runCase 150 "B" "" [msg "assistant" "m日}aa:\n日;" [] "" [], msg "tool" "𝔘𝔫𝔦" [tc "a" "bash" "{}"] "" [im "" ""]]
  runCase 151 "E" "" [msg "" "you are motoko" [] "" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" "{\\é\\日0:\n -][" [] "" [], msg "user" "á" [] "😀" []]
  runCase 152 "E" "" []
  runCase 153 "E" "" [msg "" "sha256:" [] "" []]
  runCase 154 "E" "" []
  runCase 155 "E" "" [msg "assistant" "list the files" [] "" [im "data:image/png;base64,AAAA" ""], msg "assistant" "" [] "é" [im "file:///tmp/a.png" "image/jpeg", im "file:///tmp/a.png" ""], msg "" " nbsp" [] "call_1" []]
  runCase 156 "B" "" [msg "assistant" "\r\n" [tc "call_1" "bash" "é"] "é" [], msg "é" "back\\slash" [] "a" [im "file:///tmp/a.png" "image/png", im "" ""], msg "" "make[1]" [] "a" [im "é" "image/png"], msg "system" "" [tc "a" "日本" "{}", tc "" "日本" "make[3]"] "😀" []]
  runCase 157 "L" "x" []
  runCase 158 "E" "" [msg "" "make[12]make[3]" [tc "call_1" "read_file" "{\"a\":1}"] "é" [], msg "" "back\\slash" [tc "a" "日本" "{}"] "😀" [], msg "assistant" "make[21]" [tc "😀" "read_file" "{\"a\":1}"] "" [], msg "assistant" ":{{é\\{日" [] "a" []]
  runCase 159 "L" "x" [msg "system" "é" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/jpeg"], msg "é" "{3;;\"" [] "call_1" [], msg "tool" "日本語" [tc "é" "read_file" ""] "a" [], msg "tool" "\"quoted\"" [tc "😀" "read_file" "{\"a\":1}"] "call_1" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/jpeg"]]

#eval show IO Unit from do
  runCase 160 "B" "" [msg "tool" "ü:2:ü;" [] "" [], msg "" "" [] "" [], msg "user" "make[21]" [] "é" [im "file:///tmp/a.png" "image/jpeg", im "data:image/png;base64,AAAA" "image/png"], msg "system" "back\\slash" [tc "" "read_file" "{}"] "😀" []]
  runCase 161 "L" "sha256:e3b0" []
  runCase 162 "E" "" [msg "system" " nbsp" [] "" [], msg "tool" " 1[-😀[\"" [tc "" "日本" "{}"] "😀" [], msg "system" "\"quoted\"" [tc "é" "read_file" "{\"a\":1}"] "é" []]
  runCase 163 "E" "" [msg "user" "á" [tc "é" "bash" "{\"a\":1}"] "é" [im "" "", im "" "image/png"]]
  runCase 164 "E" "" [msg "tool" "x‍😀" [] "é" []]
  runCase 165 "L" "sha256:" [msg "" "make[20] and make[2]" [] "é" [], msg "tool" "you are motoko" [tc "call_1" "" "make[3]"] "call_1" [im "é" "image/png"]]
  runCase 166 "E" "" [msg "tool" "x:3:y;" [] "😀" [im "file:///tmp/a.png" "image/png"], msg "system" "ü:2:ü;" [tc "call_1" "read_file" ""] "call_1" [], msg "é" "ok" [tc "" "" "make[3]"] "é" [im "file:///tmp/a.png" "", im "" "image/jpeg"]]
  runCase 167 "L" "sha256:e3b0" [msg "" "m-mé { m\\" [] "call_1" [], msg "system" "list the files" [] "a" [], msg "user" "make[1]" [] "" [], msg "system" "make[1]" [] "é" [im "é" "image/png"]]
  runCase 168 "E" "" [msg "" "ü:2:ü;" [] "a" [], msg "system" "é😀\\" [tc "call_1" "read_file" ""] "call_1" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 169 "E" "" [msg "user" "list the files" [tc "😀" "" "é"] "call_1" [im "file:///tmp/a.png" "image/jpeg"], msg "system" "\r\n" [tc "" "bash" "make[3]"] "😀" []]
  runCase 170 "L" "é😀" []
  runCase 171 "E" "" [msg "system" "make[1]" [tc "é" "bash" ""] "a" []]
  runCase 172 "E" "" [msg "é" "im-end;" [] "" []]
  runCase 173 "L" "" [msg "user" "make[12]make[3]" [] "é" [], msg "system" "{3 :}a\"" [tc "call_1" "日本" "{}"] "😀" [], msg "" "tc-end;" [tc "é" "read_file" ""] "call_1" [], msg "user" "😀:2-]:日0[2" [tc "" "日本" "é"] "a" []]
  runCase 174 "E" "" [msg "tool" "make[12]make[3]" [] "" [], msg "é" "😀[ \\mm-[" [] "call_1" [im "é" "", im "é" "image/jpeg"], msg "tool" "tc-end;" [] "a" [], msg "user" "make[21]" [] "é" []]
  runCase 175 "E" "" [msg "" "make[12]make[3]" [] "😀" [im "" "image/jpeg"], msg "é" "list the files" [] "😀" [], msg "tool" "" [tc "a" "" "{\"a\":1}"] "a" []]
  runCase 176 "B" "" [msg "tool" "日本" [] "call_1" [], msg "é" "tc-end;" [] "é" [im "file:///tmp/a.png" ""], msg "tool" "𝔘𝔫𝔦" [] "" []]
  runCase 177 "E" "" [msg "tool" "" [] "call_1" [], msg "system" "" [] "é" [im "data:image/png;base64,AAAA" ""], msg "assistant" "tc-end;" [] "" [im "file:///tmp/a.png" "image/png"], msg "system" "sha256:" [tc "é" "read_file" "{}", tc "a" "" "{\"a\":1}"] "é" [im "data:image/png;base64,AAAA" ""]]
  runCase 178 "E" "" [msg "é" "𝔘𝔫𝔦" [tc "😀" "bash" "é"] "é" [], msg "tool" "3\\\\ 1{3\"b-é" [tc "call_1" "read_file" "make[3]"] "call_1" [], msg "assistant" " ma日}{日" [tc "é" "bash" ""] "" [im "" "image/jpeg"]]
  runCase 179 "B" "" [msg "assistant" "\n[]\n]\\\"é[" [] "" []]
  runCase 180 "E" "" [msg "assistant" "sha256:" [] "" []]
  runCase 181 "E" "" []
  runCase 182 "E" "" [msg "" "make[1]" [] "a" [], msg "assistant" "[\"a\"]" [] "" [im "" "image/jpeg", im "é" "image/png"], msg "é" "}}" [tc "😀" "" "{\"a\":1}"] "a" [], msg "user" "ü:2:ü;" [tc "é" "bash" "é"] "" [im "data:image/png;base64,AAAA" ""]]
  runCase 183 "L" "sha256:" [msg "system" "é" [tc "😀" "" "é"] "" [], msg "user" "tc-end;" [tc "a" "" "é"] "call_1" []]
  runCase 184 "E" "" [msg "" "make[20] and make[2]" [] "call_1" [], msg "assistant" "b-\"m]m日日mb] " [tc "" "read_file" "{\"a\":1}"] "😀" []]
  runCase 185 "E" "" [msg "system" "0b\\" [] "call_1" []]
  runCase 186 "E" "" []
  runCase 187 "B" "" [msg "é" "3" [] "a" [im "file:///tmp/a.png" "image/png", im "" ""], msg "user" "you are motoko" [] "é" [], msg "assistant" "\n😀 }-" [] "call_1" []]
  runCase 188 "L" "m-end;" []
  runCase 189 "E" "" [msg "" "ok" [] "é" [], msg "assistant" "é" [] "😀" [im "data:image/png;base64,AAAA" "", im "é" ""], msg "" "" [tc "" "" "{}", tc "😀" "read_file" "é"] "é" []]
  runCase 190 "E" "" [msg "assistant" "" [] "é" [], msg "" "\"quoted\"" [tc "a" "" "make[3]"] "é" [], msg "" "b2;é" [tc "call_1" "" "make[3]"] "a" [], msg "" "ok" [tc "call_1" "日本" "", tc "call_1" "read_file" "é"] "a" [im "é" "image/png"]]
  runCase 191 "B" "" [msg "" "\"quoted\"" [tc "é" "read_file" "é"] "call_1" [], msg "user" "日\\😀;{\\" [] "call_1" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" "make[1]" [] "call_1" [im "data:image/png;base64,AAAA" "image/jpeg", im "" "image/png"], msg "é" "list the files" [] "é" []]
  runCase 192 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" []
  runCase 193 "E" "" [msg "é" "m{role:4:user;}" [tc "a" "bash" "é"] "" []]
  runCase 194 "E" "" [msg "user" "" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 195 "L" "m-end;" [msg "user" "make[21]" [] "call_1" [], msg "tool" "ok" [tc "" "" "é"] "😀" []]
  runCase 196 "B" "" [msg "system" "22\\;21" [] "😀" [im "é" "image/jpeg", im "" "image/jpeg"]]
  runCase 197 "L" "sha256:e3b0" [msg "assistant" "tab\there" [] "" []]
  runCase 198 "B" "" [msg "assistant" "3a\n\\" [tc "call_1" "" "é", tc "é" "bash" "é"] "é" [], msg "user" "you are motoko" [tc "a" "read_file" "{}", tc "é" "bash" "é"] "call_1" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""], msg "system" "you are motoko" [tc "😀" "read_file" "é"] "😀" [im "é" "image/jpeg", im "é" ""], msg "é" "x:3:y;" [tc "😀" "日本" "make[3]", tc "call_1" "" "{}"] "" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/png"]]
  runCase 199 "E" "" [msg "system" "hi" [] "a" []]

#eval show IO Unit from do
  runCase 200 "L" "m-end;" [msg "tool" " nbsp" [] "" [], msg "tool" "\n-{" [tc "é" "bash" "{\"a\":1}", tc "call_1" "日本" ""] "😀" [], msg "system" "m{role:4:user;}" [] "é" [im "é" "image/jpeg", im "é" "image/png"]]
  runCase 201 "E" "" [msg "assistant" "{}" [tc "é" "日本" "é"] "call_1" [], msg "assistant" ":}2😀1m " [] "😀" []]
  runCase 202 "B" "" [msg "assistant" "sha256:" [] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""]]
  runCase 203 "L" "x" [msg "tool" "[\"a\"]" [] "a" [], msg "tool" "\"}-:\"\\a;日3" [] "" []]
  runCase 204 "B" "" [msg "tool" "𝔘𝔫𝔦" [] "" [], msg "" "é1a{aa\\-\"😀[0" [tc "call_1" "" "make[3]"] "call_1" [], msg "é" "im-end;" [] "call_1" [im "file:///tmp/a.png" ""], msg "" "im-end;" [] "😀" []]
  runCase 205 "L" "m-end;" [msg "" "sha256:" [tc "é" "日本" "{\"a\":1}"] "😀" [], msg "assistant" "ok" [tc "" "日本" ""] "call_1" [im "" "", im "file:///tmp/a.png" ""], msg "user" "éx" [] "😀" [im "é" "image/jpeg", im "é" "image/jpeg"], msg "assistant" "\"a0\n3[ ;日" [] "😀" [im "data:image/png;base64,AAAA" "image/jpeg", im "é" "image/jpeg"]]
  runCase 206 "E" "" [msg "user" "make[0]" [tc "a" "bash" ""] "é" [im "data:image/png;base64,AAAA" "image/png", im "" "image/jpeg"], msg "tool" "á" [] "é" [], msg "assistant" "make[21]" [tc "😀" "bash" "é"] "" [], msg "assistant" "tc-end;" [tc "é" "日本" "{}"] "call_1" [im "" "", im "é" ""]]
  runCase 207 "L" "é😀" [msg "é" "x:3:y;" [tc "é" "" "{}"] "" [], msg "assistant" ":3" [] "call_1" [], msg "assistant" "make[1make[2]]" [tc "é" "read_file" "{}"] "é" [], msg "tool" "make[21]" [] "" [im "data:image/png;base64,AAAA" ""]]
  runCase 208 "B" "" [msg "tool" "make[0]" [tc "😀" "" "{}", tc "a" "read_file" "make[3]"] "call_1" [im "file:///tmp/a.png" "image/png"]]
  runCase 209 "B" "" [msg "" "make[1make[2]]" [] "call_1" [], msg "" "]-éb\n" [tc "a" "" "{\"a\":1}"] "😀" []]
  runCase 210 "E" "" []
  runCase 211 "L" "sha256:" [msg "assistant" "日本語" [tc "é" "" "make[3]", tc "a" "" "é"] "😀" [], msg "system" "hi" [tc "a" "read_file" "é"] "😀" [], msg "system" "𝔘𝔫𝔦" [] "" []]
  runCase 212 "L" "m-end;" []
  runCase 213 "E" "" [msg "é" "0é[1[日{;" [] "😀" []]
  runCase 214 "E" "" [msg "tool" "make[0]" [tc "" "bash" "{}"] "call_1" [], msg "system" "m2\"" [] "a" [], msg "user" "\r\n" [tc "é" "日本" "make[3]", tc "a" "read_file" "{\"a\":1}"] "a" []]
  runCase 215 "E" "" [msg "assistant" "éa:1;{" [tc "" "read_file" ""] "a" [], msg "" "{}" [tc "call_1" "日本" "é", tc "é" "read_file" "{}"] "" []]
  runCase 216 "L" "sha256:" [msg "é" "á" [] "😀" [im "file:///tmp/a.png" "image/png"], msg "system" "😀}0a\\12" [] "" [im "" "image/png", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 217 "B" "" [msg "é" " nbsp" [tc "" "read_file" "{\"a\":1}", tc "" "" "{}"] "" [], msg "é" "𝔘𝔫𝔦" [tc "😀" "" "make[3]", tc "😀" "read_file" ""] "call_1" [im "é" ""]]
  runCase 218 "L" "m-end;" []
  runCase 219 "L" "sha256:" [msg "é" "[\"a\"]" [tc "é" "" "{}"] "é" [im "é" "image/png", im "é" ""], msg "system" "á" [tc "é" "bash" "{}", tc "😀" "日本" "{}"] "😀" [], msg "assistant" "line\nbreak" [] "é" [], msg "é" "日本語" [] "é" []]
  runCase 220 "E" "" []
  runCase 221 "L" "m-end;" [msg "é" "ü:2:ü;" [] "a" []]
  runCase 222 "L" "" [msg "tool" "日本" [] "é" []]
  runCase 223 "L" "sha256:e3b0" []
  runCase 224 "E" "" [msg "system" "line\nbreak" [tc "call_1" "read_file" ""] "a" [im "file:///tmp/a.png" "image/jpeg", im "" "image/jpeg"]]
  runCase 225 "E" "" [msg "" "make[1]" [] "a" [im "é" "image/jpeg"]]
  runCase 226 "B" "" [msg "assistant" "\"quoted\"" [] "" [], msg "tool" "sha256:" [tc "😀" "read_file" "{\"a\":1}", tc "a" "" "make[3]"] "a" [im "" "image/jpeg", im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" "\n[\"{" [] "😀" [im "file:///tmp/a.png" ""], msg "tool" "ok" [tc "" "bash" "{}"] "" []]
  runCase 227 "B" "" [msg "assistant" "}m{" [] "😀" [], msg "" "x‍😀" [tc "é" "bash" ""] "é" [], msg "tool" "back\\slash" [] "😀" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/png"]]
  runCase 228 "E" "" [msg "system" "330b\\]a" [tc "😀" "read_file" "é"] "a" [], msg "tool" "make[20] and make[2]" [tc "" "" "{\"a\":1}"] "é" [], msg "" ";0]m; " [tc "😀" "read_file" "é", tc "" "" ""] "call_1" [im "data:image/png;base64,AAAA" "", im "" "image/png"], msg "tool" "sha256:" [] "a" [im "" "image/png"]]
  runCase 229 "B" "" [msg "é" ";{:日m" [tc "call_1" "read_file" "{\"a\":1}", tc "😀" "read_file" "make[3]"] "😀" [], msg "é" "tc-end;" [] "a" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" "image/png"], msg "tool" ":0 ;a3]]:" [tc "😀" "bash" ""] "é" [], msg "" "\\1😀a02;éb-]" [tc "a" "read_file" ""] "a" []]
  runCase 230 "B" "" [msg "tool" "[\"a\"]" [tc "a" "" ""] "a" [], msg "tool" "tc-end;" [tc "é" "bash" "{}", tc "é" "日本" ""] "" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/png"], msg "assistant" "\"quoted\"" [tc "a" "" "{}"] "" [], msg "é" "make[1make[2]]" [] "😀" [im "" ""]]
  runCase 231 "B" "" [msg "user" "" [tc "call_1" "" "make[3]", tc "" "日本" "é"] "call_1" []]
  runCase 232 "E" "" [msg "é" "make[12]make[3]" [] "😀" [], msg "é" "a\n{" [] "" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 233 "E" "" [msg "é" "tab\there" [tc "a" "bash" "{\"a\":1}"] "a" [im "file:///tmp/a.png" ""], msg "user" "x‍😀" [] "call_1" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 234 "E" "" []
  runCase 235 "E" "" [msg "tool" "}m{" [tc "" "" "é", tc "" "日本" ""] "" []]
  runCase 236 "E" "" [msg "é" "1[" [tc "" "日本" "é", tc "call_1" "bash" "{\"a\":1}"] "😀" [], msg "system" "--m\\;:日\"]33" [] "😀" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 237 "B" "" [msg "é" "\" ;]m- ]}{b:" [tc "😀" "read_file" "", tc "é" "日本" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "image/jpeg"], msg "user" "x‍😀" [tc "" "日本" "make[3]"] "a" [im "é" "image/jpeg", im "é" ""], msg "tool" "0mba]{0;" [tc "😀" "日本" "{\"a\":1}"] "call_1" [im "file:///tmp/a.png" "image/png"]]
  runCase 238 "E" "" [msg "system" "日-2-3--]]日-" [tc "" "bash" ""] "é" [im "file:///tmp/a.png" "image/png", im "file:///tmp/a.png" "image/png"], msg "tool" "list the files" [] "" [im "file:///tmp/a.png" ""], msg "assistant" "😀\né:aa" [tc "😀" "日本" ""] "" [im "é" "", im "" "image/jpeg"]]
  runCase 239 "B" "" [msg "system" "line\nbreak" [] "" [im "data:image/png;base64,AAAA" ""], msg "system" "-\"-" [] "call_1" []]

#eval show IO Unit from do
  runCase 240 "B" "" [msg "" "22\n32-{😀\\a" [tc "" "" "", tc "" "bash" ""] "é" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/jpeg"], msg "user" "x‍😀" [tc "😀" "read_file" "é"] "é" []]
  runCase 241 "B" "" [msg "tool" "make[20] and make[2]" [tc "a" "" "{\"a\":1}", tc "call_1" "日本" "{}"] "" [], msg "é" "é\":" [tc "a" "" "é", tc "call_1" "" ""] "" [], msg "assistant" "}m{" [tc "" "read_file" "", tc "😀" "" ""] "call_1" []]
  runCase 242 "E" "" [msg "é" "a}12:0{\"m\"]" [tc "😀" "日本" "make[3]", tc "é" "read_file" "{}"] "" []]
  runCase 243 "E" "" [msg "é" "\r\n" [] "" [im "é" "image/png"]]
  runCase 244 "B" "" [msg "" "{}" [] "" [im "file:///tmp/a.png" "image/jpeg"], msg "tool" "}m{" [] "call_1" [], msg "user" ":\"" [tc "😀" "bash" "{\"a\":1}"] "a" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "tool" "[\"a\"]" [] "a" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""]]
  runCase 245 "B" "" [msg "system" "😀" [] "é" []]
  runCase 246 "E" "" [msg "" "m:😀[" [tc "call_1" "" "", tc "é" "bash" "é"] "call_1" [], msg "system" "a{\n}0\n;2}😀\\" [tc "é" "bash" "{\"a\":1}", tc "a" "read_file" ""] "é" [im "é" "image/jpeg"], msg "system" "-3a{😀3m;" [] "a" [im "file:///tmp/a.png" "image/png"]]
  runCase 247 "B" "" [msg "é" "b;-😀1\"" [] "😀" [im "data:image/png;base64,AAAA" ""]]
  runCase 248 "E" "" [msg "assistant" "\\😀1;30aé0]-1" [] "é" [im "" "image/jpeg", im "é" "image/png"]]
  runCase 249 "E" "" [msg "assistant" "back\\slash" [tc "" "bash" "é", tc "😀" "bash" ""] "a" [], msg "" "" [tc "é" "日本" "", tc "a" "" "make[3]"] "é" [im "é" "", im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 250 "E" "" [msg "é" "" [tc "a" "" "", tc "call_1" "bash" "{}"] "" [], msg "tool" "\"quoted\"" [tc "call_1" "read_file" "{}"] "é" [], msg "" "" [tc "é" "日本" "é"] "call_1" [], msg "é" "x:3:y;" [tc "call_1" "bash" "{}", tc "call_1" "日本" "é"] "😀" []]
  runCase 251 "E" "" [msg "tool" "\n m" [tc "é" "日本" "make[3]"] "call_1" [im "data:image/png;base64,AAAA" ""]]
  runCase 252 "L" "" [msg "" "m{2😀a{日;" [] "a" [], msg "user" "\"quoted\"" [] "é" [], msg "assistant" "list the files" [] "call_1" [im "é" ""]]
  runCase 253 "B" "" [msg "system" "tc-end;" [tc "😀" "" "{}", tc "é" "日本" "{\"a\":1}"] "" [], msg "é" "\r\n" [] "é" [im "data:image/png;base64,AAAA" "image/jpeg", im "file:///tmp/a.png" "image/jpeg"], msg "" "make[12]make[3]" [] "é" []]
  runCase 254 "B" "" [msg "é" "-\n-1é " [] "call_1" []]
  runCase 255 "E" "" [msg "é" "b}" [tc "é" "" "é"] "😀" [im "" "image/jpeg", im "" ""]]
  runCase 256 "L" "sha256:" [msg "assistant" "ü:2:ü;" [tc "é" "" "make[3]"] "é" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 257 "E" "" [msg "system" "\r\n" [] "a" [], msg "tool" "0\n3}😀m3\n;\n" [tc "é" "" "make[3]"] "é" []]
  runCase 258 "L" "m-end;" [msg "assistant" "\"2:}" [tc "😀" "日本" "{\"a\":1}"] "é" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 259 "E" "" [msg "assistant" "line\nbreak" [tc "a" "日本" "make[3]"] "call_1" [], msg "user" "you are motoko" [] "call_1" [im "" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "é" "[b\n }32 \";" [] "😀" [im "" "image/png"]]
  runCase 260 "B" "" [msg "assistant" "]13 [😀3m" [tc "a" "read_file" "é", tc "call_1" "bash" "{}"] "" [], msg "" "make[20] and make[2]" [] "a" [im "é" "image/jpeg", im "é" "image/png"], msg "é" "日本" [tc "é" "" "{}"] "😀" []]
  runCase 261 "B" "" [msg "assistant" "\r\n" [] "" [], msg "system" "2:bb-{\\b:;-a" [] "é" [im "é" "image/png", im "" "image/jpeg"], msg "é" "\\;[\\é3" [tc "" "bash" "{\"a\":1}"] "a" [im "" ""]]
  runCase 262 "B" "" []
  runCase 263 "E" "" [msg "assistant" " nbsp" [] "a" [im "data:image/png;base64,AAAA" "image/jpeg"], msg "system" "}m{" [] "call_1" []]
  runCase 264 "B" "" [msg "" "}m{" [] "é" [], msg "tool" "tc-end;" [] "é" [], msg "tool" "😀" [tc "a" "" "{}"] "😀" [im "" "image/jpeg"], msg "system" "make[20] and make[2]" [] "é" []]
  runCase 265 "E" "" [msg "assistant" "日本語" [tc "" "" "make[3]"] "" []]
  runCase 266 "L" "sha256:e3b0" [msg "é" "" [tc "😀" "read_file" "é"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/png"]]
  runCase 267 "L" "sha256:" [msg "assistant" "list the files" [] "" []]
  runCase 268 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "user" "𝔘𝔫𝔦" [] "😀" [im "file:///tmp/a.png" "image/jpeg", im "" ""]]
  runCase 269 "B" "" [msg "system" " }\\" [tc "call_1" "read_file" "{\"a\":1}", tc "call_1" "" ""] "😀" [im "é" "image/png"]]
  runCase 270 "L" "m-end;" [msg "assistant" "á" [] "é" [im "file:///tmp/a.png" ""]]
  runCase 271 "B" "" [msg "system" "éx" [tc "call_1" "日本" "make[3]"] "call_1" [], msg "user" "\r\n" [] "😀" [im "é" "image/png", im "" ""], msg "assistant" " nbsp" [] "😀" [], msg "assistant" "make[0]" [tc "call_1" "read_file" "make[3]"] "" [im "" ""]]
  runCase 272 "B" "" [msg "user" "make[1make[2]]" [] "" [], msg "user" "bb日{" [] "😀" [], msg "tool" "-}[20-" [tc "call_1" "bash" ""] "" [], msg "tool" "" [tc "é" "read_file" "{}"] "😀" [im "" "", im "data:image/png;base64,AAAA" ""]]
  runCase 273 "E" "" [msg "tool" "" [tc "😀" "" "{\"a\":1}", tc "😀" "read_file" ""] "call_1" [], msg "" "" [tc "call_1" "read_file" "", tc "a" "read_file" "{\"a\":1}"] "😀" [im "é" "image/jpeg", im "" "image/jpeg"], msg "tool" "m}0}" [tc "é" "bash" ""] "a" [im "data:image/png;base64,AAAA" "image/png", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 274 "E" "" [msg "" "á" [tc "a" "日本" "", tc "call_1" "bash" "{\"a\":1}"] "é" []]
  runCase 275 "L" "sha256:e3b0" [msg "user" "\"quoted\"" [tc "😀" "bash" "make[3]"] "a" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "user" "b" [tc "é" "bash" "make[3]", tc "😀" "read_file" ""] "a" [], msg "é" "日本語" [] "call_1" [im "data:image/png;base64,AAAA" ""]]
  runCase 276 "E" "" [msg "é" "{m3{\\é3m\"}3" [tc "a" "" "é"] "é" [], msg "system" "\"quoted\"" [tc "" "bash" "make[3]", tc "" "bash" "é"] "😀" [], msg "system" "hi" [tc "😀" "" "{}", tc "😀" "日本" ""] "" [im "é" "image/jpeg", im "" "image/png"], msg "é" "é日" [] "😀" []]
  runCase 277 "L" "sha256:e3b0" [msg "assistant" "make[21]" [] "é" [], msg "tool" "tc-end;" [] "é" []]
  runCase 278 "E" "" []
  runCase 279 "L" "" [msg "user" "sha256:" [tc "call_1" "read_file" "{\"a\":1}"] "" [], msg "tool" "hi" [] "call_1" []]

#eval show IO Unit from do
  runCase 280 "B" "" [msg "é" "back\\slash" [] "é" []]
  runCase 281 "E" "" [msg "tool" "x:3:y;" [] "a" [im "file:///tmp/a.png" "", im "é" "image/jpeg"], msg "system" "make[1make[2]]" [] "call_1" [], msg "user" "you are motoko" [] "call_1" [im "file:///tmp/a.png" "", im "" "image/jpeg"]]
  runCase 282 "B" "" [msg "user" "m3" [tc "a" "read_file" "{\"a\":1}", tc "call_1" "read_file" "{}"] "a" [im "é" ""], msg "" "日本語" [tc "call_1" "日本" "{}"] "" [im "data:image/png;base64,AAAA" "", im "" "image/png"]]
  runCase 283 "L" "sha256:" [msg "system" "á" [tc "😀" "" "make[3]"] "" []]
  runCase 284 "E" "" [msg "tool" "}m{" [tc "call_1" "日本" "{\"a\":1}"] "call_1" [im "data:image/png;base64,AAAA" "", im "é" "image/jpeg"], msg "é" "line\nbreak" [tc "call_1" "" "é"] "" []]
  runCase 285 "E" "" [msg "" "make[0]" [tc "😀" "bash" "{}"] "a" [], msg "é" "}m{" [tc "a" "read_file" "make[3]"] "call_1" [im "é" "image/jpeg", im "" "image/jpeg"]]
  runCase 286 "E" "" [msg "tool" "x‍😀" [] "😀" [], msg "system" "make[1]" [] "" [], msg "é" "" [tc "a" "日本" "{}", tc "é" "" "{}"] "😀" []]
  runCase 287 "E" "" [msg "é" "m{role:4:user;}" [tc "😀" "bash" ""] "😀" []]
  runCase 288 "B" "" [msg "tool" "-{" [] "call_1" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" "x‍😀" [tc "call_1" "日本" ""] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"], msg "tool" "😀" [tc "é" "bash" "{}"] "call_1" [im "" "image/jpeg"], msg "" "x‍😀" [tc "" "日本" "{}"] "é" []]
  runCase 289 "E" "" [msg "user" "tc-end;" [tc "é" "" "é"] "" [im "" "image/jpeg", im "é" "image/png"], msg "" "make[20] and make[2]" [tc "" "" ""] "call_1" [im "" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 290 "E" "" [msg "assistant" "á" [tc "" "read_file" "{}", tc "a" "" "{\"a\":1}"] "a" [], msg "assistant" "á" [tc "é" "bash" "{}", tc "a" "" "{}"] "é" [], msg "system" "[\"a\"]" [tc "a" "" "", tc "call_1" "read_file" "{}"] "é" []]
  runCase 291 "E" "" []
  runCase 292 "E" "" [msg "assistant" "x:3:y;" [tc "" "bash" "{\"a\":1}", tc "é" "" "é"] "a" [], msg "assistant" "\n\"a{é{😀😀2m1" [tc "é" "日本" "é"] "é" []]
  runCase 293 "E" "" [msg "" "x‍😀" [tc "call_1" "bash" "é"] "" [], msg "" "\n2" [tc "é" "" "make[3]"] "" [im "data:image/png;base64,AAAA" "image/png"], msg "tool" "1[-:é\n2" [tc "😀" "read_file" "é"] "call_1" [im "file:///tmp/a.png" "image/png", im "é" ""]]
  runCase 294 "E" "" [msg "system" "1:b0\n::-1{]-" [] "😀" [], msg "user" "😀ba" [] "call_1" [], msg "user" "back\\slash" [tc "" "read_file" ""] "a" [im "" "image/jpeg", im "" "image/jpeg"]]
  runCase 295 "E" "" []
  runCase 296 "E" "" [msg "user" "日本語" [] "é" []]
  runCase 297 "E" "" []
  runCase 298 "E" "" [msg "system" "😀{😀😀 b\na;}\\m" [tc "é" "日本" "é"] "" [im "é" ""], msg "" " -日-mb{  b\"" [tc "" "" "{\"a\":1}"] "é" [], msg "" "éx" [] "call_1" [im "" "", im "é" ""]]
  runCase 299 "L" "sha256:" [msg "user" "é10" [] "a" []]
  runCase 300 "B" "" [msg "tool" "éx" [] "" [im "" "", im "data:image/png;base64,AAAA" "image/png"], msg "user" "😀m[\n\n2\"]" [tc "call_1" "" "make[3]", tc "é" "" ""] "call_1" [], msg "assistant" "😀" [tc "é" "read_file" "{\"a\":1}"] "😀" [im "" ""], msg "tool" "back\\slash" [] "call_1" [im "file:///tmp/a.png" ""]]
  runCase 301 "E" "" [msg "tool" "😀😀{}\n日[-😀\\😀3" [tc "😀" "" "é"] "" []]
  runCase 302 "E" "" [msg "system" "make[20] and make[2]" [tc "é" "read_file" "é", tc "" "bash" ""] "é" [], msg "" "3é{ " [] "call_1" [], msg "é" "-;é:3" [] "" []]
  runCase 303 "L" "sha256:e3b0" [msg "user" "á" [] "a" []]
  runCase 304 "B" "" [msg "system" "ok" [tc "call_1" "" "é"] "a" [im "é" "image/jpeg", im "" "image/png"], msg "" "make[12]make[3]" [tc "" "read_file" "{\"a\":1}", tc "😀" "bash" ""] "" [im "file:///tmp/a.png" "image/png"], msg "" "é" [] "😀" [], msg "system" "make[0]" [tc "a" "" "{}"] "é" [im "data:image/png;base64,AAAA" ""]]
  runCase 305 "B" "" [msg "system" "日本語" [tc "é" "bash" ""] "" [im "" "image/png", im "é" "image/jpeg"]]
  runCase 306 "L" "" [msg "" "{}" [tc "" "bash" ""] "😀" [im "file:///tmp/a.png" ""], msg "user" "ü:2:ü;" [tc "😀" "bash" "make[3]", tc "" "read_file" "make[3]"] "😀" [im "data:image/png;base64,AAAA" "", im "" "image/png"]]
  runCase 307 "B" "" [msg "tool" "日本" [tc "" "日本" "{\"a\":1}", tc "😀" "read_file" "{}"] "a" [], msg "user" "im-end;" [tc "" "日本" "{\"a\":1}", tc "é" "bash" "{\"a\":1}"] "a" [im "data:image/png;base64,AAAA" "image/png"], msg "tool" "you are motoko" [tc "call_1" "" "", tc "😀" "" ""] "é" []]
  runCase 308 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" ":m]0:-m\"" [tc "" "read_file" "{}"] "call_1" [], msg "user" "\r\n" [tc "😀" "日本" "é", tc "call_1" "" "{}"] "a" [], msg "system" "-é" [tc "a" "read_file" "{\"a\":1}"] "😀" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/png"], msg "tool" "make[1make[2]]" [tc "é" "日本" "", tc "😀" "日本" ""] "" []]
  runCase 309 "E" "" [msg "tool" "" [tc "a" "" "{}"] "a" []]
  runCase 310 "E" "" []
  runCase 311 "L" "" [msg "assistant" "]0" [] "" [], msg "assistant" "" [tc "" "日本" "é"] "" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 312 "E" "" []
  runCase 313 "L" "é😀" [msg "" "make[0]" [tc "call_1" "日本" "{\"a\":1}"] "é" [], msg "" "日本" [tc "" "" "make[3]"] "😀" [im "" "image/png", im "" ""], msg "user" "tab\there" [tc "😀" "bash" "make[3]"] "a" [im "data:image/png;base64,AAAA" "image/jpeg"]]
  runCase 314 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "é" [] "" []]
  runCase 315 "E" "" [msg "" "ü:2:ü;" [] "a" [im "" "image/png"], msg "" "im-end;" [] "" [im "" "image/png"], msg "é" "m{role:4:user;}" [tc "😀" "日本" "make[3]", tc "é" "bash" "{\"a\":1}"] "" []]
  runCase 316 "L" "é😀" []
  runCase 317 "L" "é😀" [msg "assistant" "[\"a\"]" [] "a" [], msg "user" "b\"\"\\-😀b\"" [] "😀" [im "data:image/png;base64,AAAA" "", im "file:///tmp/a.png" ""], msg "system" "á" [tc "a" "" "{}"] "call_1" [im "file:///tmp/a.png" "image/jpeg"], msg "system" "]-02a1mm" [] "é" []]
  runCase 318 "L" "" [msg "system" "éx" [] "call_1" [], msg "é" "á" [tc "é" "read_file" "{}"] "😀" [], msg "" "make[21]" [] "a" [im "é" "image/jpeg"]]
  runCase 319 "L" "sha256:" [msg "" "😀" [] "é" [im "" "image/png", im "" "image/png"], msg "system" "line\nbreak" [] "" [], msg "" ":mab-m日[" [tc "call_1" "日本" "make[3]"] "a" []]

#eval show IO Unit from do
  runCase 320 "L" "sha256:e3b0" [msg "user" "b}\"2a1}}\\120" [] "é" [im "data:image/png;base64,AAAA" "image/png"], msg "system" "𝔘𝔫𝔦" [tc "" "" "", tc "é" "read_file" "{\"a\":1}"] "é" [], msg "user" "back\\slash" [tc "é" "read_file" "é"] "call_1" []]
  runCase 321 "E" "" [msg "user" "𝔘𝔫𝔦" [] "a" [], msg "user" "😀" [tc "" "日本" "é"] "" [], msg "user" "you are motoko" [tc "" "bash" "", tc "call_1" "bash" "{}"] "a" []]
  runCase 322 "B" "" []
  runCase 323 "B" "" []
  runCase 324 "E" "" [msg "" "m" [tc "" "read_file" "{\"a\":1}"] "" [], msg "user" "im-end;" [] "a" [im "é" "", im "é" "image/jpeg"]]
  runCase 325 "L" "sha256:" [msg "é" "ü:2:ü;" [tc "é" "" "make[3]"] "" [im "é" "image/jpeg"], msg "tool" "\"quoted\"" [] "call_1" [], msg "tool" "" [tc "é" "" "{\"a\":1}"] "😀" [im "file:///tmp/a.png" ""]]
  runCase 326 "E" "" [msg "tool" "m{role:4:user;}" [] "call_1" [], msg "" "m{role:4:user;}" [tc "é" "read_file" "make[3]", tc "é" "" ""] "é" []]
  runCase 327 "E" "" [msg "system" "make[12]make[3]" [tc "a" "bash" "make[3]", tc "" "read_file" "{}"] "a" []]
  runCase 328 "E" "" [msg "system" "make[0]" [] "😀" [], msg "system" "line\nbreak" [tc "😀" "" "{}"] "é" [], msg "é" "make[20] and make[2]" [] "" [im "é" "image/png", im "file:///tmp/a.png" "image/png"], msg "user" "\"😀\\ba 1a日" [tc "é" "" ""] "a" []]
  runCase 329 "B" "" [msg "user" "tc-end;" [] "" [im "" "image/png", im "" "image/jpeg"], msg "system" "á" [tc "a" "read_file" "make[3]", tc "call_1" "" "{\"a\":1}"] "😀" [], msg "assistant" "" [] "a" [im "é" "image/png"], msg "system" "" [] "a" []]
  runCase 330 "E" "" [msg "assistant" "list the files" [] "" []]
  runCase 331 "L" "sha256:" [msg "é" "make[0]" [tc "a" "" "{\"a\":1}"] "call_1" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "system" "ok" [tc "😀" "read_file" "", tc "😀" "日本" "é"] "a" [im "" "image/jpeg"]]
  runCase 332 "B" "" [msg "é" "sha256:" [] "" [im "é" "image/jpeg", im "" "image/png"]]
  runCase 333 "E" "" [msg "system" "make[1]" [] "call_1" [im "é" "image/png", im "é" "image/png"]]
  runCase 334 "E" "" [msg "tool" "á" [] "a" [], msg "tool" "b" [] "" [im "" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "á" [] "é" [im "data:image/png;base64,AAAA" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "tool" ";]é:3é日]0日3😀" [] "😀" []]
  runCase 335 "L" "m-end;" [msg "user" "á" [tc "a" "read_file" "é"] "é" [im "" ""], msg "tool" "é2" [tc "call_1" "read_file" "make[3]", tc "" "" "{\"a\":1}"] "" [], msg "" "{}" [tc "call_1" "日本" "{}", tc "call_1" "日本" "é"] "é" [im "file:///tmp/a.png" "image/png"], msg "system" "\"{b }}日- 😀" [] "é" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/jpeg"]]
  runCase 336 "E" "" [msg "user" "im-end;" [tc "call_1" "日本" "{\"a\":1}", tc "" "" "{\"a\":1}"] "😀" [], msg "" "make[1]" [tc "call_1" "read_file" "é"] "a" [im "" ""]]
  runCase 337 "E" "" [msg "é" " nbsp" [] "😀" [im "é" "image/jpeg"]]
  runCase 338 "E" "" [msg "tool" "back\\slash" [] "😀" []]
  runCase 339 "E" "" [msg "tool" "x‍😀" [] "é" [im "é" "image/png", im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "im-end;" [tc "a" "日本" "{\"a\":1}"] "call_1" [im "é" "image/jpeg", im "é" "image/png"]]
  runCase 340 "E" "" [msg "é" "ü:2:ü;" [tc "call_1" "bash" "make[3]", tc "call_1" "" "{\"a\":1}"] "call_1" []]
  runCase 341 "B" "" [msg "é" ";-é1]2😀😀aa😀0" [tc "😀" "read_file" "é"] "a" [], msg "" "" [tc "a" "read_file" "{\"a\":1}"] "😀" []]
  runCase 342 "E" "" []
  runCase 343 "E" "" [msg "tool" "make[12]make[3]" [] "call_1" [im "" "image/png"], msg "system" "é" [] "a" [], msg "assistant" "make[1]" [tc "a" "read_file" "", tc "😀" "bash" "make[3]"] "a" []]
  runCase 344 "E" "" [msg "" "{}" [] "" [], msg "tool" "list the files" [tc "é" "日本" "{\"a\":1}"] "a" [], msg "é" "日本" [tc "a" "日本" "{\"a\":1}", tc "a" "日本" "{\"a\":1}"] "é" [im "" "", im "file:///tmp/a.png" "image/jpeg"], msg "é" "make[21]" [] "" [im "" "image/jpeg"]]
  runCase 345 "L" "é😀" [msg "é" "[\"a\"]" [tc "" "日本" "é", tc "😀" "" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 346 "E" "" [msg "" "" [tc "call_1" "" "é", tc "é" "read_file" "{}"] "é" [im "é" "image/png", im "é" "image/png"], msg "tool" "" [] "call_1" [], msg "" "x:3:y;" [] "call_1" [im "é" "image/png"], msg "user" "x:3:y;" [] "😀" []]
  runCase 347 "E" "" [msg "assistant" "" [tc "😀" "read_file" "make[3]"] "call_1" [im "data:image/png;base64,AAAA" "image/png"], msg "é" "\"quoted\"" [tc "a" "bash" ""] "call_1" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" ""]]
  runCase 348 "B" "" [msg "" " nbsp" [] "" []]
  runCase 349 "B" "" [msg "user" "sha256:" [tc "😀" "" "é"] "a" [], msg "é" "im-end;" [tc "😀" "bash" "{\"a\":1}"] "" [im "é" "image/png", im "file:///tmp/a.png" "image/jpeg"], msg "system" "010\\ 3\\0:" [tc "é" "read_file" "make[3]"] "call_1" [im "" "image/png"]]
  runCase 350 "B" "" [msg "é" "a-\"3" [tc "" "bash" ""] "" [im "" ""], msg "assistant" "😀b01" [] "a" [], msg "system" "éx" [] "" [], msg "tool" "m2 ém" [] "a" []]
  runCase 351 "E" "" [msg "system" "im-end;" [tc "call_1" "read_file" "make[3]", tc "😀" "" "é"] "a" [], msg "é" "\"quoted\"" [] "" [im "" ""], msg "tool" "{}" [tc "call_1" "read_file" "é", tc "a" "日本" ""] "call_1" []]
  runCase 352 "L" "" [msg "é" "{}" [tc "a" "read_file" "make[3]"] "😀" [], msg "user" "" [tc "" "日本" "make[3]"] "é" []]
  runCase 353 "E" "" []
  runCase 354 "E" "" [msg "user" "\"quoted\"" [] "a" [], msg "system" "ü:2:ü;" [] "call_1" []]
  runCase 355 "L" "m-end;" [msg "é" "á" [tc "call_1" "bash" "make[3]", tc "call_1" "日本" ""] "" [], msg "system" "x:3:y;" [tc "a" "bash" "", tc "é" "bash" "{}"] "😀" [im "data:image/png;base64,AAAA" ""], msg "é" "éx" [tc "" "日本" "{}", tc "é" "" "{\"a\":1}"] "" [], msg "system" ";1b0a[\"" [] "😀" [im "é" ""]]
  runCase 356 "E" "" [msg "é" "}\"\" 0{" [] "é" [im "é" "image/png"]]
  runCase 357 "L" "x" [msg "assistant" "\n] ma2😀" [] "😀" [], msg "system" "" [tc "a" "read_file" "make[3]"] "a" [im "file:///tmp/a.png" "", im "file:///tmp/a.png" "image/png"]]
  runCase 358 "L" "" [msg "user" "😀😀-😀" [tc "a" "bash" "make[3]", tc "😀" "" "{\"a\":1}"] "" [], msg "é" "make[12]make[3]" [] "call_1" [im "é" "image/png"]]
  runCase 359 "B" "" [msg "tool" "make[12]make[3]" [] "a" [], msg "é" "😀" [] "é" [], msg "é" "é" [] "call_1" [im "" ""], msg "system" "[\\ }0\n" [tc "" "" "{\"a\":1}"] "a" [im "file:///tmp/a.png" "image/png"]]

#eval show IO Unit from do
  runCase 360 "E" "" [msg "system" "make[1make[2]]" [] "call_1" [im "é" "image/jpeg"]]
  runCase 361 "L" "" [msg "" "ok" [] "a" [], msg "é" "0[0a}" [] "call_1" []]
  runCase 362 "L" "m-end;" []
  runCase 363 "E" "" [msg "é" "é" [tc "" "日本" "é"] "" [im "é" ""]]
  runCase 364 "L" "sha256:e3b0" [msg "tool" "back\\slash" [tc "a" "" ""] "" []]
  runCase 365 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" "\"quoted\"" [] "a" [], msg "system" "im-end;" [tc "😀" "bash" "{}"] "" []]
  runCase 366 "B" "" [msg "tool" "you are motoko" [tc "é" "read_file" "make[3]", tc "" "bash" ""] "a" []]
  runCase 367 "L" "é😀" [msg "system" ":😀\\[2[日" [] "call_1" [im "" "", im "file:///tmp/a.png" "image/png"]]
  runCase 368 "B" "" [msg "é" "make[1make[2]]" [] "" [im "data:image/png;base64,AAAA" "image/jpeg", im "" ""], msg "tool" "m{role:4:user;}" [] "é" [], msg "é" "make[0]" [tc "a" "" "{}"] "" [im "é" "image/jpeg", im "file:///tmp/a.png" "image/png"]]
  runCase 369 "E" "" [msg "é" "}m{" [tc "😀" "bash" "make[3]"] "😀" []]
  runCase 370 "B" "" [msg "" "back\\slash" [tc "é" "bash" "", tc "😀" "read_file" "make[3]"] "é" [], msg "tool" "make[1make[2]]" [tc "" "日本" "{\"a\":1}", tc "😀" "" "{}"] "call_1" [im "" "image/png"], msg "user" "make[1make[2]]" [] "a" [im "é" "image/jpeg"]]
  runCase 371 "L" "" [msg "tool" "make[21]" [tc "é" "read_file" "é"] "" []]
  runCase 372 "E" "" [msg "assistant" "á" [] "é" [], msg "system" "tab\there" [] "é" [im "" "image/png"]]
  runCase 373 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "assistant" "2{\n-:-" [] "é" []]
  runCase 374 "E" "" [msg "system" "á" [] "😀" [im "file:///tmp/a.png" "image/png"], msg "" "2" [tc "" "" "é"] "call_1" [im "é" "image/jpeg", im "data:image/png;base64,AAAA" ""]]
  runCase 375 "B" "" []
  runCase 376 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "" "make[12]make[3]" [] "a" []]
  runCase 377 "L" "sha256:" [msg "system" "ok" [] "😀" [im "file:///tmp/a.png" ""], msg "é" ":a;[\n" [] "é" [im "é" "", im "file:///tmp/a.png" "image/jpeg"]]
  runCase 378 "E" "" [msg "" "back\\slash" [tc "call_1" "" "{}", tc "a" "" "é"] "é" [], msg "é" "}m{" [tc "" "bash" "é"] "😀" [im "file:///tmp/a.png" "image/jpeg"]]
  runCase 379 "E" "" [msg "assistant" "make[1]" [] "" [], msg "assistant" "éx" [] "é" [im "é" "", im "data:image/png;base64,AAAA" "image/jpeg"], msg "user" " nbsp" [] "call_1" []]
  runCase 380 "E" "" [msg "user" "tab\there" [] "" []]
  runCase 381 "B" "" [msg "system" "\\33[" [tc "call_1" "" "", tc "a" "日本" "é"] "a" [im "" "image/png", im "data:image/png;base64,AAAA" ""], msg "" "tc-end;" [] "😀" []]
  runCase 382 "E" "" [msg "assistant" "x‍😀" [] "" [], msg "é" "𝔘𝔫𝔦" [] "" [im "é" "image/png", im "é" ""], msg "system" "]" [] "😀" []]
  runCase 383 "L" "é😀" [msg "system" "\"quoted\"" [] "a" [im "é" "image/png"]]
  runCase 384 "E" "" [msg "user" "😀b 1" [tc "" "read_file" ""] "😀" [im "data:image/png;base64,AAAA" "image/png"]]
  runCase 385 "E" "" [msg "" "tc-end;" [] "call_1" [im "" ""], msg "system" "list the files" [tc "a" "" "", tc "é" "" "{}"] "é" []]
  runCase 386 "L" "sha256:0000000000000000000000000000000000000000000000000000000000000000" [msg "tool" "tc-end;" [] "é" [im "file:///tmp/a.png" "image/png", im "é" "image/png"], msg "assistant" "m]é" [tc "" "" "{}"] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "é" "image/png"]]
  runCase 387 "B" "" []
  runCase 388 "L" "" [msg "" " \"{0\\[mb" [tc "😀" "read_file" ""] "call_1" [], msg "user" "日本" [tc "😀" "read_file" "{\"a\":1}"] "call_1" []]
  runCase 389 "L" "m-end;" [msg "é" "ma日 aa]" [] "😀" [], msg "tool" "\r\n" [] "call_1" []]
  runCase 390 "E" "" [msg "assistant" "m日é\"\\\n:日 éé" [tc "" "日本" "{}", tc "call_1" "bash" "{\"a\":1}"] "call_1" [im "file:///tmp/a.png" "image/jpeg", im "é" "image/png"], msg "user" "ok" [tc "" "" "make[3]"] "" [], msg "user" "𝔘𝔫𝔦" [] "é" []]
  runCase 391 "L" "é😀" [msg "system" "tab\there" [tc "" "日本" "make[3]", tc "é" "日本" "é"] "é" [], msg "tool" "make[12]make[3]" [] "" [], msg "assistant" "ü:2:ü;" [] "" [im "file:///tmp/a.png" "image/png", im "data:image/png;base64,AAAA" ""], msg "system" "make[0]" [tc "" "" "{}"] "call_1" [im "data:image/png;base64,AAAA" "image/png", im "data:image/png;base64,AAAA" ""]]
  runCase 392 "B" "" [msg "system" " nbsp" [tc "a" "read_file" "{\"a\":1}"] "é" [im "file:///tmp/a.png" "", im "data:image/png;base64,AAAA" "image/png"], msg "assistant" "𝔘𝔫𝔦" [] "😀" []]
  runCase 393 "B" "" [msg "system" "{}" [] "call_1" [], msg "user" "\\a" [] "é" []]
  runCase 394 "E" "" []
  runCase 395 "L" "sha256:e3b0" [msg "system" "{[{}3é\n-0" [tc "é" "read_file" "é"] "call_1" [], msg "tool" "b0}{\"éé 😀1" [] "call_1" [im "é" "image/png", im "data:image/png;base64,AAAA" ""], msg "system" "b\n}m\n3" [tc "é" "bash" ""] "é" [im "file:///tmp/a.png" ""]]
  runCase 396 "E" "" [msg "user" "é" [tc "é" "bash" "make[3]", tc "😀" "bash" ""] "call_1" [im "é" "image/png", im "é" "image/jpeg"]]
  runCase 397 "E" "" [msg "system" "[\"a\"]" [] "😀" []]
  runCase 398 "L" "é😀" [msg "system" "{}" [tc "a" "日本" "", tc "a" "bash" "{}"] "a" [], msg "" "you are motoko" [] "call_1" [], msg "é" "{}" [tc "" "" "make[3]"] "😀" []]
  runCase 399 "E" "" []
