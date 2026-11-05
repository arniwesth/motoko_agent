/-
ChainModel.lean — a Lean model of the journal's digest chain, and its properties.

Lean 4.28.0, core only (no Mathlib, no Lake):  `lean ChainModel.lean`.
No `sorry`, no `native_decide`; the axiom report is the `#print axioms` block at the end
(captured in axioms.txt, next to this file, by check_axioms.sh).

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
through. No PROPERTY theorem depends on these: each is stated for an arbitrary frame function
`F` and an arbitrary — or an arbitrary injective — hash `H`. Only the concrete-witness theorems
(`bug_*_witness*`, `witnessBase_ne_empty`) instantiate `F := canonicalMessageFrame`:

  src/core/phase_vocab.ail:271-273 frame, 275-282 digest_content, 284-290 canonical_tool_calls,
  292-294 canonical_message, 299-301 canonical_messages, 321-323 canonical_message_body,
  325-331 canonical_images, 357-359 canonical_message_frame, 361-363 digest_messages.

CHECKED 2026-11-04, in the session that wrote it:
  * `lean ChainModel.lean` (4.28.0): no error. One warning, `unused variable base` at
    `chainDigestsOver` — the defect, flagged by the linter.
  * check_axioms.sh: every `theorem` has a `#print axioms`; none uses more than propext,
    Classical.choice, Quot.sound (axioms.txt). No `sorry`, no `native_decide`.
  * diff/run_diff.sh against the REAL code: 0 mismatches on every recorded run
    (SUMMARY.md lists them). Negative control (MUTANT=fixed): the fixed model mismatches the
    real code in exactly the predicted cases; against a tree patched with the fix
    (repro/fix_check.sh) the fixed model has 0 mismatches.

MODEL CHANGES MADE BY STEP (2) — two edits to this file, net zero:
  1. `strLength` changed from scalar values to "scalar values that are not combining marks"
     (a grapheme-count guess) after seed 1 mismatched on "a\u0301". Still mismatched.
  2. Reverted to scalar values. The cause was in the HARNESS, not the model: AILANG
     normalises string LITERALS, as observed consistent with NFC ("a\u0301" in source
     arrives as "á"), while strings built
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
