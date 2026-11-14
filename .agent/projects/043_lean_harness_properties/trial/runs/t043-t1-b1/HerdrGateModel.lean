/-
HerdrGateModel.lean — a Lean 4.28.0 model (core only: no Mathlib, no Lake) of the herdr
environment gate, a cross-language twin tracked as MOT-118.

Source, in the snapshot at /home/motoko/trial-043/s/t043-t1-b1/tree (read 2026-11-04):

  * `readHerdrEnvironment`  src/tui/src/herdr-agent-state.ts:157-166
        (intent: the doc comment at :139-156, "THEY MUST MOVE TOGETHER (MOT-118)")
  * `herdr_env_ready`       packages/motoko-ext-herdr/types.ail:1425-1433
        (intent: the comment at :1407-1424, "ALL THREE ARE REQUIRED")
  * the caller of the second, `register_with_config`
                            packages/motoko-ext-herdr/register.ail:43-50, :206
  * the forwarding between them, `buildChildEnv`'s HERDR_ loop
                            src/tui/src/runtime-process.ts:629-633

Run: `lean HerdrGateModel.lean`. Written without `sorry` and without `native_decide`; the axiom
report is the `#print axioms` block at the end of the file (recorded in ../axioms.txt).

CHECKED 2026-11-04 with Lean 4.28.0 (7e01a1bf5c70): no error, 23 theorems, none uses `sorryAx`
or `Lean.ofReduceBool`. Step (2): sections 1-2 against the real code on 46,656 triples
(diff/run_diff.sh) and section 4 on 512 TUI environments (diff/run_e2e.sh), 0 mismatches each,
with no change to the model; see ../SUMMARY.md.

What the model keeps and what it abstracts:

  * A string is `List Char` (`Str`), not Lean's `String`. Both real functions only compare
    strings for equality, against "", and (AILANG) with `>=` against "1". Lean 4.28's `String`
    is a byte array whose `toList` and `<` reduce in the kernel only through
    `Classical.choice`; a `List Char` keeps every concrete witness below decidable with no
    axiom at all. The differential test (diff/) feeds the same values to all three halves.
  * An environment variable is `Option Str`: `none` is unset (`undefined` in TypeScript), and
    P1.1 hands an unset variable to the AILANG side as "" (`Option.getD []`).
  * AILANG's `>=` on two strings is modelled as lexicographic comparison on code points, the
    order Go's byte-wise string comparison induces on valid UTF-8 (`strLt`). Step (2) checks
    this choice against the real `ailang run` on the values in diff/gen_alphabet.py.
  * JS `!x` on `string | undefined` is "unset or empty" (`falsy`).
  * JS `String.prototype.trim` is modelled by the WhiteSpace and LineTerminator code points of
    ECMA-262 (`jsSpace`), used only in the end-to-end model (section 4).
-/

abbrev Str := List Char

/-! ## 1. The TypeScript side: `readHerdrEnvironment` (herdr-agent-state.ts:157-166) -/

structure HerdrEnvironment where
  paneId : Str
  bin    : Str
  deriving DecidableEq, Repr

/-- JS falsiness of a `string | undefined`: undefined, or the empty string. -/
def falsy : Option Str → Bool
  | none => true
  | some s => s.isEmpty

/-- `readHerdrEnvironment`, statement for statement.

```ts
if (env.HERDR_ENV !== "1") return null;
const paneId = env.HERDR_PANE_ID;
const bin = env.HERDR_BIN_PATH;
if (!paneId || bin === undefined) return null;
return { paneId, bin };
```
-/
def readHerdrEnvironment (herdrEnv binPath paneId : Option Str) : Option HerdrEnvironment :=
  if herdrEnv ≠ some ['1'] then none else
  if falsy paneId || binPath == none then none else
  match paneId, binPath with
  | some p, some b => some { paneId := p, bin := b }
  | _, _ => none   -- unreachable: the guard above excludes it

/-! ## 2. The AILANG side: `herdr_env_ready` (types.ail:1425-1433) -/

/-- Strict lexicographic order on code points: Go's `<` on strings, for valid UTF-8. -/
def strLt : Str → Str → Bool
  | _, [] => false
  | [], _ :: _ => true
  | a :: as, b :: bs =>
    if a.toNat < b.toNat then true else if b.toNat < a.toNat then false else strLt as bs

/-- AILANG `a >= b` on strings. -/
def strGe (a b : Str) : Bool := !strLt a b

/-- `herdr_env_ready`:
```
{ herdr_env >= "1" && bin_path != "" && pane_id != "" }
```
-/
def herdrEnvReady (herdrEnv binPath paneId : Str) : Bool :=
  strGe herdrEnv ['1'] && binPath != [] && paneId != []

/-! ## 3. P1.1 and what is wrong with it -/

/-- P1.1: for every value of the three variables, each unset or any string, with unset passed to
the AILANG side as "", the TypeScript gate is non-null iff `herdr_env_ready` is true. -/
def P1_1 : Prop :=
  ∀ e b p : Option Str,
    (readHerdrEnvironment e b p).isSome = herdrEnvReady (e.getD []) (b.getD []) (p.getD [])

-- Concrete values, as `List Char` so that `decide` needs no axiom.
def binW  : Str := ['/', 'u', 's', 'r', '/', 'b', 'i', 'n', '/', 'h', 'e', 'r', 'd', 'r']
def paneW : Str := ['w', '1', ':', 'p', '7']

/-- Non-vacuity: the five inline `tests [...]` of `herdr_env_ready` (types.ail:1426-1432) hold in
the model, with `binW` for "/usr/local/bin/herdr". -/
theorem model_passes_inline_tests :
    herdrEnvReady ['1'] binW paneW = true ∧
    herdrEnvReady [] binW paneW = false ∧
    herdrEnvReady ['1'] [] paneW = false ∧
    herdrEnvReady ['1'] binW [] = false ∧
    herdrEnvReady ['0'] binW paneW = false := by decide

/-- Non-vacuity on the TypeScript side: the cases of herdr-agent-state.test.ts:27-43. -/
theorem model_passes_ts_tests :
    readHerdrEnvironment (some ['1']) (some binW) (some paneW) = some ⟨paneW, binW⟩ ∧
    readHerdrEnvironment none none none = none ∧
    readHerdrEnvironment none (some binW) (some paneW) = none ∧
    readHerdrEnvironment (some ['0']) (some binW) (some paneW) = none ∧
    readHerdrEnvironment (some ['1']) (some binW) none = none ∧
    readHerdrEnvironment (some ['1']) none (some paneW) = none ∧
    readHerdrEnvironment (some ['1']) (some binW) (some []) = none := by decide

/-- BUG 1 (P1.1). `HERDR_ENV=2`, the other two set: the TypeScript gate is null (it wants exactly
"1"), and `herdr_env_ready` is true, because `"2" >= "1"`. -/
theorem bug_P1_1_herdr_env_2 :
    (readHerdrEnvironment (some ['2']) (some binW) (some paneW)).isSome = false ∧
    herdrEnvReady ['2'] binW paneW = true := by decide

/-- The same class, on values a person might actually export: "10", "1 " and "true". -/
theorem bug_P1_1_herdr_env_more :
    (readHerdrEnvironment (some ['1', '0']) (some binW) (some paneW)).isSome = false ∧
    herdrEnvReady ['1', '0'] binW paneW = true ∧
    (readHerdrEnvironment (some ['1', ' ']) (some binW) (some paneW)).isSome = false ∧
    herdrEnvReady ['1', ' '] binW paneW = true ∧
    (readHerdrEnvironment (some ['t', 'r', 'u', 'e']) (some binW) (some paneW)).isSome = false ∧
    herdrEnvReady ['t', 'r', 'u', 'e'] binW paneW = true := by decide

/-- BUG 2 (P1.1). `HERDR_BIN_PATH` set to the empty string: the TypeScript gate is non-null, with
`bin = ""` (it tests `bin === undefined`, not `!bin`), and `herdr_env_ready` is false. -/
theorem bug_P1_1_empty_bin :
    readHerdrEnvironment (some ['1']) (some []) (some paneW) = some ⟨paneW, []⟩ ∧
    herdrEnvReady ['1'] [] paneW = false := by decide

theorem not_P1_1 : ¬ P1_1 := by
  intro h
  have := h (some ['2']) (some binW) (some paneW)
  revert this
  decide

/-! ### The whole disagreement set, for every input -/

theorem one_toNat : '1'.toNat = 49 := rfl

theorem strGe_one_iff (s : Str) : strGe s ['1'] = true ↔ ∃ c t, s = c :: t ∧ 49 ≤ c.toNat := by
  cases s with
  | nil => simp [strGe, strLt]
  | cons c t =>
    simp only [strGe, strLt, one_toNat]
    by_cases h1 : c.toNat < 49
    · simp [h1]
    · by_cases h2 : 49 < c.toNat
      · simp [h1, h2]; omega
      · cases t <;> simp [h1, h2] <;> omega

/-- Where the two copies disagree, exactly: either HERDR_ENV is some string other than "1" whose
first code point is at least '1' (with the other two non-empty), or HERDR_ENV is "1", the pane id
is non-empty and HERDR_BIN_PATH is set to "". Nowhere else. -/
theorem disagree_iff (e b p : Option Str) :
    (readHerdrEnvironment e b p).isSome ≠ herdrEnvReady (e.getD []) (b.getD []) (p.getD []) ↔
      ((e ≠ some ['1'] ∧ strGe (e.getD []) ['1'] = true ∧ b.getD [] ≠ [] ∧ p.getD [] ≠ []) ∨
       (e = some ['1'] ∧ b = some [] ∧ p.getD [] ≠ [])) := by
  by_cases he : e = some ['1']
  · subst he
    cases p with
    | none => cases b <;> simp [readHerdrEnvironment, herdrEnvReady, falsy, strGe, strLt]
    | some p =>
      cases b with
      | none => cases p <;> simp [readHerdrEnvironment, herdrEnvReady, falsy, strGe, strLt]
      | some b =>
        cases p <;> cases b <;> simp [readHerdrEnvironment, herdrEnvReady, falsy, strGe, strLt]
  · simp [readHerdrEnvironment, he, herdrEnvReady]

/-- Corollary: P1.1 does hold whenever HERDR_ENV is unset, "1", or starts below '1' (in
particular "" and "0"), and HERDR_BIN_PATH is not the empty string. -/
theorem P1_1_outside_disagreement (e b p : Option Str)
    (he : e = some ['1'] ∨ strGe (e.getD []) ['1'] = false) (hb : b ≠ some []) :
    (readHerdrEnvironment e b p).isSome = herdrEnvReady (e.getD []) (b.getD []) (p.getD []) := by
  apply Decidable.byContradiction
  intro hne
  rcases (disagree_iff e b p).mp hne with ⟨h1, h2, _, _⟩ | ⟨_, h2, _⟩
  · rcases he with he | he
    · exact h1 he
    · rw [he] at h2; exact Bool.false_ne_true h2
  · exact hb h2

/-! ### The fix, and that it closes the gap -/

/-- `herdr_env_ready` with `herdr_env == "1"` in place of `herdr_env >= "1"`. -/
def herdrEnvReadyFixed (herdrEnv binPath paneId : Str) : Bool :=
  herdrEnv == ['1'] && binPath != [] && paneId != []

/-- `readHerdrEnvironment` with `!bin` in place of `bin === undefined`. -/
def readHerdrEnvironmentFixed (herdrEnv binPath paneId : Option Str) : Option HerdrEnvironment :=
  if herdrEnv ≠ some ['1'] then none else
  if falsy paneId || falsy binPath then none else
  match paneId, binPath with
  | some p, some b => some { paneId := p, bin := b }
  | _, _ => none

theorem fixed_P1_1 (e b p : Option Str) :
    (readHerdrEnvironmentFixed e b p).isSome
      = herdrEnvReadyFixed (e.getD []) (b.getD []) (p.getD []) := by
  by_cases he : e = some ['1']
  · subst he
    cases p with
    | none => cases b <;> simp [readHerdrEnvironmentFixed, herdrEnvReadyFixed, falsy]
    | some p =>
      cases b with
      | none => cases p <;> simp [readHerdrEnvironmentFixed, herdrEnvReadyFixed, falsy]
      | some b =>
        cases p <;> cases b <;> simp [readHerdrEnvironmentFixed, herdrEnvReadyFixed, falsy]
  · have hg : (e.getD [] == ['1']) = false := by
      cases e with
      | none => rfl
      | some s => simp only [Option.getD_some]; simpa using he
    simp [readHerdrEnvironmentFixed, he, herdrEnvReadyFixed, hg]

/-- The fix keeps the intended behaviour: on every input outside the disagreement set, each
fixed copy gives the same answer as the original. -/
theorem fixed_ts_keeps (e b p : Option Str) (hb : b ≠ some []) :
    readHerdrEnvironmentFixed e b p = readHerdrEnvironment e b p := by
  unfold readHerdrEnvironmentFixed readHerdrEnvironment
  cases b with
  | none => simp [falsy]
  | some s => cases s with
    | nil => exact absurd rfl hb
    | cons c t => simp [falsy]

theorem fixed_ail_keeps (e b p : Str) (he : e = ['1'] ∨ strGe e ['1'] = false) :
    herdrEnvReadyFixed e b p = herdrEnvReady e b p := by
  rcases he with he | he
  · subst he; simp [herdrEnvReadyFixed, herdrEnvReady, strGe, strLt]
  · have hne : e ≠ ['1'] := by intro h; subst h; simp [strGe, strLt] at he
    simp [herdrEnvReadyFixed, herdrEnvReady, he, hne]

/-! ## 4. End to end: what each copy is actually handed (exploratory property X-1)

The intent comment (herdr-agent-state.ts:150-155) names the path between the copies: the TUI reads
`process.env` itself; the AILANG copy runs in the runtime, a grandchild of the pane, and sees only
what `buildChildEnv` forwards (runtime-process.ts:629-633), read through `getEnvOr` with the
defaults at register.ail:45-50. X-1 is P1.1 along that path, with nothing passed by hand. -/

/-- ECMA-262 WhiteSpace ∪ LineTerminator: the code points `String.prototype.trim` removes. -/
def jsSpace (c : Char) : Bool :=
  let n := c.toNat
  n == 0x09 || n == 0x0A || n == 0x0B || n == 0x0C || n == 0x0D || n == 0x20 || n == 0xA0 ||
  n == 0x1680 || (0x2000 ≤ n && n ≤ 0x200A) || n == 0x2028 || n == 0x2029 || n == 0x202F ||
  n == 0x205F || n == 0x3000 || n == 0xFEFF

/-- runtime-process.ts:629-633: a `HERDR_` variable reaches the runtime only when
`value && value.trim() !== ""`. The empty string is all-space, so it is dropped too. -/
def forwarded : Option Str → Option Str
  | none => none
  | some s => if s.all jsSpace then none else some s

/-- AILANG `getEnvOr(name, default)` in the runtime. Only `forwarded` values reach it, and none of
them is "", so how `getEnvOr` treats a set-but-empty variable never arises on this path. -/
def getEnvOr (v : Option Str) (dflt : Str) : Str := v.getD dflt

def herdrW : Str := ['h', 'e', 'r', 'd', 'r']

/-- register.ail:45-50 and :206: the gate `register_with_config` computes. -/
def registerGate (e b p : Option Str) : Bool :=
  herdrEnvReady (getEnvOr (forwarded e) []) (getEnvOr (forwarded b) herdrW)
    (getEnvOr (forwarded p) [])

/-- X-1: for every TUI environment, the TUI reports to herdr iff the extension advertises tools. -/
def X_1 : Prop := ∀ e b p : Option Str, (readHerdrEnvironment e b p).isSome = registerGate e b p

/-- BUG (X-1). HERDR_BIN_PATH unset: the TUI copy is null, and the runtime copy is open, because
register.ail:49 defaults the unset variable to "herdr", which is not "". -/
theorem bug_X_1_unset_bin :
    readHerdrEnvironment (some ['1']) none (some paneW) = none ∧
    registerGate (some ['1']) none (some paneW) = true := by decide

/-- The `bin_path != ""` conjunct of `herdr_env_ready` can never be false on the real path ... -/
theorem register_bin_never_empty (b : Option Str) : getEnvOr (forwarded b) herdrW ≠ [] := by
  cases b with
  | none => simp [forwarded, getEnvOr, herdrW]
  | some s =>
    cases s with
    | nil => simp [forwarded, getEnvOr, herdrW]
    | cons c t =>
      simp only [forwarded, getEnvOr]
      split <;> simp [herdrW]

/-- ... so, as the runtime calls it, the AILANG gate does not depend on HERDR_BIN_PATH at all:
"ALL THREE ARE REQUIRED" (types.ail:1407) holds of the function and not of its only caller. -/
theorem registerGate_ignores_bin (e b b' p : Option Str) :
    registerGate e b p = registerGate e b' p := by
  have h1 : (getEnvOr (forwarded b) herdrW != []) = true := by
    simpa [bne_iff_ne] using register_bin_never_empty b
  have h2 : (getEnvOr (forwarded b') herdrW != []) = true := by
    simpa [bne_iff_ne] using register_bin_never_empty b'
  simp only [registerGate, herdrEnvReady, h1, h2]

/-- BUG (X-1). HERDR_PANE_ID a single space: the TUI copy is non-null (" " is truthy), and
`buildChildEnv` drops it (" ".trim() is ""), so the runtime copy sees "" and is closed. -/
theorem bug_X_1_blank_pane :
    (readHerdrEnvironment (some ['1']) (some binW) (some [' '])).isSome = true ∧
    registerGate (some ['1']) (some binW) (some [' ']) = false := by decide

/-- The P1.1 class survives the path: HERDR_ENV=2 is forwarded, and opens only the runtime copy. -/
theorem bug_X_1_herdr_env_2 :
    (readHerdrEnvironment (some ['2']) (some binW) (some paneW)).isSome = false ∧
    registerGate (some ['2']) (some binW) (some paneW) = true := by decide

/-- And P1.1's other class does NOT survive it: HERDR_BIN_PATH="" is dropped by `buildChildEnv`,
defaulted to "herdr", and both copies are open. The two defects cancel on this input. -/
theorem empty_bin_agrees_end_to_end :
    (readHerdrEnvironment (some ['1']) (some []) (some paneW)).isSome = true ∧
    registerGate (some ['1']) (some []) (some paneW) = true := by decide

theorem not_X_1 : ¬ X_1 := by
  intro h
  have := h (some ['1']) none (some paneW)
  revert this
  decide

/-! ### A fix for X-1, and that it closes the gap

Three changes together: `herdr_env_ready` compares with `==` (as for P1.1); `register.ail:49`
defaults HERDR_BIN_PATH to "" rather than "herdr"; and the TypeScript copy treats a blank value
(`!v || v.trim() === ""`, the same test `buildChildEnv` applies) as unset, for both the pane id and
the binary. -/

def blank : Option Str → Bool
  | none => true
  | some s => s.all jsSpace

def readHerdrEnvironmentE2E (herdrEnv binPath paneId : Option Str) : Option HerdrEnvironment :=
  if herdrEnv ≠ some ['1'] then none else
  if blank paneId || blank binPath then none else
  match paneId, binPath with
  | some p, some b => some { paneId := p, bin := b }
  | _, _ => none

def registerGateFixed (e b p : Option Str) : Bool :=
  herdrEnvReadyFixed (getEnvOr (forwarded e) []) (getEnvOr (forwarded b) [])
    (getEnvOr (forwarded p) [])

theorem fwd_nonempty (v : Option Str) : (getEnvOr (forwarded v) [] != []) = !blank v := by
  cases v with
  | none => rfl
  | some s =>
    simp only [forwarded, getEnvOr, blank]
    cases h : s.all jsSpace with
    | true => rfl
    | false =>
      cases s with
      | nil => simp at h
      | cons c t => rfl

theorem fwd_one (e : Option Str) : (getEnvOr (forwarded e) [] == ['1']) = decide (e = some ['1']) := by
  cases e with
  | none => rfl
  | some s =>
    simp only [forwarded, getEnvOr]
    cases h : s.all jsSpace with
    | true =>
      have : s ≠ ['1'] := by intro hs; subst hs; revert h; decide
      simp [this]
    | false => by_cases hs : s = ['1'] <;> simp [hs]

theorem fixed_X_1 (e b p : Option Str) :
    (readHerdrEnvironmentE2E e b p).isSome = registerGateFixed e b p := by
  simp only [registerGateFixed, herdrEnvReadyFixed, fwd_one, fwd_nonempty]
  unfold readHerdrEnvironmentE2E
  by_cases he : e = some ['1']
  · simp only [he, ne_eq, not_true_eq_false, if_false, decide_true, Bool.true_and]
    cases p with
    | none => simp [blank]
    | some p =>
      cases b with
      | none => simp [blank]
      | some b =>
        cases hp : blank (some p) <;> cases hb : blank (some b) <;> simp
  · simp [he]

/-! ## Axiom report -/

#print axioms model_passes_inline_tests
#print axioms model_passes_ts_tests
#print axioms bug_P1_1_herdr_env_2
#print axioms bug_P1_1_herdr_env_more
#print axioms bug_P1_1_empty_bin
#print axioms not_P1_1
#print axioms one_toNat
#print axioms strGe_one_iff
#print axioms disagree_iff
#print axioms P1_1_outside_disagreement
#print axioms fixed_P1_1
#print axioms fixed_ts_keeps
#print axioms fixed_ail_keeps
#print axioms bug_X_1_unset_bin
#print axioms register_bin_never_empty
#print axioms registerGate_ignores_bin
#print axioms bug_X_1_blank_pane
#print axioms bug_X_1_herdr_env_2
#print axioms empty_bin_agrees_end_to_end
#print axioms not_X_1
#print axioms fwd_nonempty
#print axioms fwd_one
#print axioms fixed_X_1
