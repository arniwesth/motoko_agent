/-
HerdrGateModel.lean — target T1 of the 043 trial: the herdr environment gate, a
cross-language twin (MOT-118). Lean 4.28.0, core only: no Mathlib, no Lake.
`lean HerdrGateModel.lean`.

Models, at the snapshot in ../tree:

  * `readHerdrEnvironment`  src/tui/src/herdr-agent-state.ts:157-166
        if (env.HERDR_ENV !== "1") return null;
        const paneId = env.HERDR_PANE_ID;
        const bin = env.HERDR_BIN_PATH;
        if (!paneId || bin === undefined) return null;
        return { paneId, bin };

  * `herdr_env_ready`       packages/motoko-ext-herdr/types.ail:1425-1433
        { herdr_env >= "1" && bin_path != "" && pane_id != "" }

  and, for the exploratory end-to-end statements only (X-1, X-2), the two places that put
  values into those parameters:

  * `register_with_config`  packages/motoko-ext-herdr/register.ail:43-50, :206
        getEnvOr("HERDR_ENV", ""), getEnvOr("HERDR_BIN_PATH", "herdr"),
        getEnvOr("HERDR_PANE_ID", "")
  * `buildChildEnv`         src/tui/src/runtime-process.ts:630-634
        forwards a HERDR_* variable only when `value && value.trim() !== ""`

Intent (herdr-agent-state.ts:145, types.ail:1420-1424): one rule, two copies, "THEY MUST
MOVE TOGETHER". All three variables are required (herdr-agent-state.ts:158-160,
types.ail:1407).

What the model keeps and what it abstracts:

  * An environment variable is `Option String`: `none` is unset, `some s` is set to `s`.
    The TypeScript side reads `NodeJS.ProcessEnv`, `string | undefined`; JS truthiness of
    that type is "set and not empty" (`truthy`).
  * The AILANG side takes three `string`s. Property P1.1 passes unset as `""` (`orEmpty`).
  * AILANG's `>=` on strings is Go's byte-wise lexicographic order. The model uses Lean's
    `String` order, which is lexicographic on code points (`String.lt_iff`); on valid UTF-8
    the two orders coincide, because UTF-8 preserves code-point order byte-wise. The
    differential test (diff/) checks the model against the real `>=` on 60 values, ASCII and
    not; it cannot reach strings that are not valid UTF-8, which Lean's `String` excludes.
  * `trim` in `buildChildEnv` is abstracted as a predicate `blank` with one property used:
    `blank ""`. Nothing else about JavaScript's whitespace set is assumed.
  * The returned record is kept field for field, so the differential test compares what the
    TypeScript gate returns, not only whether it returns.

Differential test: diff/run_diff.sh. Step (2) changed this model 0 times (SUMMARY.md).
-/

/-! ## The TypeScript side: `readHerdrEnvironment` -/

/-- The three variables the gate reads. `none` is unset. -/
structure Env where
  herdrEnv : Option String   -- HERDR_ENV
  binPath  : Option String   -- HERDR_BIN_PATH
  paneId   : Option String   -- HERDR_PANE_ID
  deriving DecidableEq, Repr

/-- `interface HerdrEnvironment` (herdr-agent-state.ts:127-137). -/
structure HerdrEnvironment where
  paneId : String
  bin    : String
  deriving DecidableEq, Repr

/-- JavaScript truthiness of a `string | undefined`: `undefined` and `""` are falsy. -/
def truthy : Option String → Bool
  | none   => false
  | some s => s != ""

/-- `readHerdrEnvironment`, line for line. -/
def readHerdrEnvironment (env : Env) : Option HerdrEnvironment :=
  if env.herdrEnv != some "1" then none                 -- `env.HERDR_ENV !== "1"`
  else
    match env.paneId, env.binPath with                   -- `const paneId = …; const bin = …;`
    | some paneId, some bin =>
        if !truthy (some paneId) then none               -- `!paneId`
        else some { paneId := paneId, bin := bin }       -- `return { paneId, bin }`
    | _, _ => none                                       -- `!paneId || bin === undefined`

/-- The TypeScript gate is open: `readHerdrEnvironment(env) !== null`. -/
def tsOpen (env : Env) : Bool := (readHerdrEnvironment env).isSome

/-! ## The AILANG side: `herdr_env_ready` -/

/-- AILANG `a >= b` on strings, as Lean's lexicographic `String` order (see header). -/
def strGe (a b : String) : Bool := decide (b ≤ a)

/-- `herdr_env_ready`, verbatim. -/
def herdrEnvReady (herdrEnv binPath paneId : String) : Bool :=
  strGe herdrEnv "1" && binPath != "" && paneId != ""

/-- P1.1's convention: unset is passed to the AILANG side as `""`. -/
def orEmpty : Option String → String
  | none   => ""
  | some s => s

def ailOpen (env : Env) : Bool :=
  herdrEnvReady (orEmpty env.herdrEnv) (orEmpty env.binPath) (orEmpty env.paneId)

/-! ## Sanity: the model passes both sides' own tests

`types.ail:1426-1432` (`herdr_env_ready`'s inline tests) and
`herdr-agent-state.test.ts:27-43`. Each is a closed computation, checked by `decide`. -/

theorem ail_inline_tests :
    herdrEnvReady "1" "/usr/local/bin/herdr" "w1:p7" = true ∧
    herdrEnvReady "" "/usr/local/bin/herdr" "w1:p7" = false ∧
    herdrEnvReady "1" "" "w1:p7" = false ∧
    herdrEnvReady "1" "/usr/local/bin/herdr" "" = false ∧
    herdrEnvReady "0" "/usr/local/bin/herdr" "w1:p7" = false := by decide

def inHerdr : Env := ⟨some "1", some "/usr/local/bin/herdr", some "w1:p2"⟩

theorem ts_unit_tests :
    readHerdrEnvironment inHerdr = some ⟨"w1:p2", "/usr/local/bin/herdr"⟩ ∧
    readHerdrEnvironment ⟨none, none, none⟩ = none ∧
    readHerdrEnvironment { inHerdr with herdrEnv := none } = none ∧
    readHerdrEnvironment { inHerdr with herdrEnv := some "0" } = none ∧
    readHerdrEnvironment { inHerdr with paneId := none } = none ∧
    readHerdrEnvironment { inHerdr with binPath := none } = none ∧
    readHerdrEnvironment { inHerdr with paneId := some "" } = none := by decide

/-! ## Lemmas: each side in closed form -/

theorem tsOpen_iff (env : Env) :
    tsOpen env = true ↔
      env.herdrEnv = some "1" ∧ env.binPath.isSome ∧ truthy env.paneId := by
  rcases env with ⟨e, b, p⟩
  simp only [tsOpen, readHerdrEnvironment]
  by_cases he : e = some "1"
  · subst he
    cases p with
    | none => cases b <;> simp [truthy]
    | some p =>
      cases b with
      | none => simp [truthy]
      | some b => by_cases hp : p = "" <;> simp [truthy, hp]
  · simp [he]

theorem ailOpen_iff (env : Env) :
    ailOpen env = true ↔
      "1" ≤ orEmpty env.herdrEnv ∧ orEmpty env.binPath ≠ "" ∧ orEmpty env.paneId ≠ "" := by
  simp [ailOpen, herdrEnvReady, strGe, and_assoc]

theorem truthy_iff (o : Option String) : truthy o = true ↔ orEmpty o ≠ "" := by
  cases o <;> simp [truthy, orEmpty]

/-! ## P1.1 is false

P1.1: for every value of the three variables, each unset or any string, with unset passed to
the AILANG side as `""`, `readHerdrEnvironment` is non-null iff `herdr_env_ready` is true.
Stated as `∀ env, tsOpen env = ailOpen env`; refuted twice, once per side. -/

def P1_1 : Prop := ∀ env : Env, tsOpen env = ailOpen env

/-- Witness A (the AILANG side is wider): HERDR_ENV="2". `"2" >= "1"` holds lexicographically,
so the AILANG gate opens where the TypeScript gate, which wants exactly "1", stays shut. -/
def witnessA : Env := ⟨some "2", some "/usr/local/bin/herdr", some "w1:p7"⟩

theorem bug_P1_1_env_two :
    readHerdrEnvironment witnessA = none ∧
    herdrEnvReady "2" "/usr/local/bin/herdr" "w1:p7" = true := by decide

/-- Witness B (the TypeScript side is wider): HERDR_BIN_PATH set to "". `bin === undefined`
lets it through, and the gate returns `{ paneId, bin: "" }`; the AILANG side refuses it. -/
def witnessB : Env := ⟨some "1", some "", some "w1:p7"⟩

theorem bug_P1_1_empty_bin :
    readHerdrEnvironment witnessB = some ⟨"w1:p7", ""⟩ ∧
    herdrEnvReady "1" "" "w1:p7" = false := by decide

theorem bug_P1_1 : ¬ P1_1 := by
  intro h
  have := h witnessA
  revert this
  decide

/-- Every disagreement, exactly. The two sides differ iff the pane id is non-empty and either
(A) HERDR_ENV is a string other than "1" that sorts at or after "1", with a non-empty bin path,
or (B) HERDR_ENV is "1" and HERDR_BIN_PATH is set to the empty string. -/
theorem disagree_iff (env : Env) :
    tsOpen env ≠ ailOpen env ↔
      orEmpty env.paneId ≠ "" ∧
      ((env.herdrEnv ≠ some "1" ∧ "1" ≤ orEmpty env.herdrEnv ∧ orEmpty env.binPath ≠ "") ∨
       (env.herdrEnv = some "1" ∧ env.binPath = some "")) := by
  rcases env with ⟨e, b, p⟩
  have hT := tsOpen_iff ⟨e, b, p⟩
  have hA := ailOpen_iff ⟨e, b, p⟩
  have hP := truthy_iff p
  simp only at hT hA ⊢
  have h11 : ("1" : String) ≤ "1" := by decide
  cases b with
  | none =>
    by_cases he : e = some "1" <;> by_cases hle : "1" ≤ orEmpty e <;>
      by_cases hpe : orEmpty p = "" <;>
      cases hts : tsOpen ⟨e, none, p⟩ <;> cases hai : ailOpen ⟨e, none, p⟩ <;>
      simp_all [orEmpty]
  | some b =>
    by_cases he : e = some "1" <;> by_cases hle : "1" ≤ orEmpty e <;>
      by_cases hbe : b = "" <;> by_cases hpe : orEmpty p = "" <;>
      cases hts : tsOpen ⟨e, some b, p⟩ <;> cases hai : ailOpen ⟨e, some b, p⟩ <;>
      simp_all [orEmpty]

/-- Corollary: on witness-free ground the two agree. When HERDR_ENV is unset, "1", or sorts
below "1", and HERDR_BIN_PATH is never set to "", the gates match. This is the domain the
existing tests on both sides sample, which is why neither suite sees the split. -/
theorem agree_off_the_witnesses (env : Env)
    (hE : env.herdrEnv = some "1" ∨ ¬ ("1" ≤ orEmpty env.herdrEnv))
    (hB : env.binPath ≠ some "") :
    tsOpen env = ailOpen env := by
  apply Classical.byContradiction
  intro hne
  have := (disagree_iff env).mp hne
  rcases this with ⟨_, ⟨hne1, hle, _⟩ | ⟨_, hb⟩⟩
  · rcases hE with h | h
    · exact hne1 h
    · exact h hle
  · exact hB hb

/-- The hypotheses of `agree_off_the_witnesses` are satisfiable, on both outcomes. -/
theorem agree_off_the_witnesses_not_vacuous :
    (tsOpen inHerdr = true ∧ ailOpen inHerdr = true) ∧
    (tsOpen ⟨some "0", some "/b", some "p"⟩ = false ∧
     ailOpen ⟨some "0", some "/b", some "p"⟩ = false) := by decide

/-! ## The fix, proved

Change both sides to the rule both comments state: HERDR_ENV is exactly "1", and both other
variables are set and non-empty. AILANG: `herdr_env == "1"`. TypeScript: `!paneId || !bin`. -/

def herdrEnvReadyFixed (herdrEnv binPath paneId : String) : Bool :=
  herdrEnv == "1" && binPath != "" && paneId != ""

def readHerdrEnvironmentFixed (env : Env) : Option HerdrEnvironment :=
  if env.herdrEnv != some "1" then none
  else
    match env.paneId, env.binPath with
    | some paneId, some bin =>
        if !truthy (some paneId) || !truthy (some bin) then none
        else some { paneId := paneId, bin := bin }
    | _, _ => none

theorem fixed_agree (env : Env) :
    (readHerdrEnvironmentFixed env).isSome =
      herdrEnvReadyFixed (orEmpty env.herdrEnv) (orEmpty env.binPath) (orEmpty env.paneId) := by
  rcases env with ⟨e, b, p⟩
  simp only [readHerdrEnvironmentFixed, herdrEnvReadyFixed]
  cases e with
  | none => simp [orEmpty]
  | some e =>
    by_cases he : e = "1"
    · subst he
      cases p with
      | none => cases b <;> simp [orEmpty]
      | some p =>
        cases b with
        | none => by_cases hp : p = "" <;> simp [orEmpty, hp]
        | some b =>
          by_cases hp : p = "" <;> by_cases hb : b = "" <;> simp [truthy, orEmpty, hp, hb]
    · simp [orEmpty, he]

/-- Each side's fix agrees with the original wherever the original sides already agreed,
so the fix changes behaviour only on the two disagreement families. -/
theorem fixed_ail_keeps_agreed (env : Env) (h : tsOpen env = ailOpen env) :
    herdrEnvReadyFixed (orEmpty env.herdrEnv) (orEmpty env.binPath) (orEmpty env.paneId)
      = ailOpen env := by
  rw [← fixed_agree]
  rcases env with ⟨e, b, p⟩
  rw [← h]
  simp only [tsOpen, readHerdrEnvironment, readHerdrEnvironmentFixed]
  cases e with
  | none => simp
  | some e =>
    by_cases he : e = "1"
    · subst he
      cases p with
      | none => cases b <;> simp
      | some p =>
        cases b with
        | none => simp
        | some b =>
          by_cases hb : b = ""
          · -- the only case the TS fix changes; `h` rules it out unless the pane is empty
            subst hb
            by_cases hp : p = ""
            · simp [truthy, hp]
            · exfalso
              have := (disagree_iff ⟨some "1", some "", some p⟩).mpr
                ⟨by simp [orEmpty, hp], Or.inr ⟨rfl, rfl⟩⟩
              exact this h
          · simp [truthy, hb]
    · simp [he]

theorem fixed_passes_both_suites :
    herdrEnvReadyFixed "1" "/usr/local/bin/herdr" "w1:p7" = true ∧
    herdrEnvReadyFixed "" "/usr/local/bin/herdr" "w1:p7" = false ∧
    herdrEnvReadyFixed "1" "" "w1:p7" = false ∧
    herdrEnvReadyFixed "1" "/usr/local/bin/herdr" "" = false ∧
    herdrEnvReadyFixed "0" "/usr/local/bin/herdr" "w1:p7" = false ∧
    readHerdrEnvironmentFixed inHerdr = some ⟨"w1:p2", "/usr/local/bin/herdr"⟩ ∧
    readHerdrEnvironmentFixed ⟨none, none, none⟩ = none ∧
    readHerdrEnvironmentFixed { inHerdr with herdrEnv := some "0" } = none ∧
    readHerdrEnvironmentFixed { inHerdr with paneId := none } = none ∧
    readHerdrEnvironmentFixed { inHerdr with binPath := none } = none ∧
    readHerdrEnvironmentFixed { inHerdr with paneId := some "" } = none := by decide

/-! ## Exploratory: the gate as the runtime actually calls it (X-1, X-2)

P1.1 fixes the AILANG side's input as "unset ↦ \"\"". The real caller does not.
`register_with_config` reads `getEnvOr("HERDR_BIN_PATH", "herdr")` (register.ail:49), and the
runtime only sees what `buildChildEnv` forwards from the TUI's environment: a HERDR_* variable
whose value is set and not blank (runtime-process.ts:631). -/

/-- AILANG `getEnvOr(name, default)`. -/
def getEnvOr (v : Option String) (dflt : String) : String :=
  match v with
  | none   => dflt
  | some s => s

/-- What `register_with_config` passes to `herdr_env_ready` (register.ail:45-50, :206). -/
def registerGate (env : Env) : Bool :=
  herdrEnvReady (getEnvOr env.herdrEnv "") (getEnvOr env.binPath "herdr") (getEnvOr env.paneId "")

/-- `buildChildEnv`'s filter for one HERDR_* variable, with JavaScript's `trim() === ""`
abstracted as `blank`. -/
def forward (blank : String → Bool) : Option String → Option String
  | none   => none
  | some s => if s != "" && !blank s then some s else none

def forwardEnv (blank : String → Bool) (env : Env) : Env :=
  ⟨forward blank env.herdrEnv, forward blank env.binPath, forward blank env.paneId⟩

/-- X-1, model half. With HERDR_BIN_PATH unset, the TypeScript gate is shut and the AILANG
gate, as `register_with_config` calls it, is open: the default "herdr" fills the hole that
the "all three are required" rule was meant to see. -/
def witnessX1 : Env := ⟨some "1", none, some "w1:p7"⟩

theorem bug_X1_bin_unset :
    readHerdrEnvironment witnessX1 = none ∧ registerGate witnessX1 = true := by decide

/-- X-1, general form: under the real caller, the bin-path conjunct of `herdr_env_ready` can
never be false on anything `buildChildEnv` forwards, whatever `trim` counts as blank (no
hypothesis on `blank` is needed: the `value &&` test alone keeps "" out, and the default
"herdr" fills the unset case). The runtime's gate is a two-variable test. -/
theorem register_gate_ignores_bin (blank : String → Bool)
    (env : Env) (b' : Option String) :
    registerGate (forwardEnv blank env) =
      registerGate (forwardEnv blank { env with binPath := b' }) := by
  rcases env with ⟨e, b, p⟩
  have key : ∀ o : Option String, getEnvOr (forward blank o) "herdr" ≠ "" := by
    intro o
    cases o with
    | none => simp [forward, getEnvOr]
    | some s =>
      by_cases hs : s = ""
      · subst hs; simp [forward, getEnvOr]
      · by_cases hb : blank s = true
        · simp [forward, getEnvOr, hb]
        · simp [forward, getEnvOr, hs, hb]
  have k1 : (getEnvOr (forward blank b) "herdr" != "") = true := by
    simpa [bne_iff_ne] using key b
  have k2 : (getEnvOr (forward blank b') "herdr" != "") = true := by
    simpa [bne_iff_ne] using key b'
  show herdrEnvReady _ (getEnvOr (forward blank b) "herdr") _ =
       herdrEnvReady _ (getEnvOr (forward blank b') "herdr") _
  simp only [herdrEnvReady, k1, k2]
  rfl

/-- X-2, model half. A blank pane id (one space) passes the TypeScript gate, which tests only
truthiness; `buildChildEnv` drops it, so the runtime's gate sees "" and stays shut. Stated for
any `blank` that counts " " as blank, which JavaScript's `trim` does. -/
def witnessX2 : Env := ⟨some "1", some "/usr/local/bin/herdr", some " "⟩

theorem bug_X2_blank_pane (blank : String → Bool) (h : blank " " = true) :
    readHerdrEnvironment witnessX2 = some ⟨" ", "/usr/local/bin/herdr"⟩ ∧
    registerGate (forwardEnv blank witnessX2) = false := by
  refine ⟨by decide, ?_⟩
  simp [registerGate, forwardEnv, forward, witnessX2, getEnvOr, h, herdrEnvReady]

/-! ## Axiom report -/

#print axioms ail_inline_tests
#print axioms ts_unit_tests
#print axioms tsOpen_iff
#print axioms ailOpen_iff
#print axioms truthy_iff
#print axioms bug_P1_1_env_two
#print axioms bug_P1_1_empty_bin
#print axioms bug_P1_1
#print axioms disagree_iff
#print axioms agree_off_the_witnesses
#print axioms agree_off_the_witnesses_not_vacuous
#print axioms fixed_agree
#print axioms fixed_ail_keeps_agreed
#print axioms fixed_passes_both_suites
#print axioms bug_X1_bin_unset
#print axioms register_gate_ignores_bin
#print axioms bug_X2_blank_pane
