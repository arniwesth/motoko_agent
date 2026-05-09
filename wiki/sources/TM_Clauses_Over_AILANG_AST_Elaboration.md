# TM Clauses Over AILANG AST Features — Elaboration

## The Existing Situation

The AILANG codebase already contains hand-written propositional classifiers for code errors. In `src/core/ext/compose/guard.ail`:

```ailang
export func classify_ailang_error(errors: string) -> string {
  let e = toLower(errors);
  if contains(e, "missing effect") || contains(e, "effect checking") then "effect"
  else if contains(e, "expected next token") || contains(e, "unexpected token") then "parse"
  else if contains(e, "undefined") || contains(e, "not found") then "import_or_symbol"
  else if contains(e, "type mismatch") || contains(e, "cannot unify") then "type"
  else "other"
}
```

And a hint generator that maps error patterns to remediation:

```ailang
export func targeted_hint(errors: string) -> string {
  let e = toLower(errors);
  if contains(e, "missing effect") || contains(e, "effect checking")
    then "Hint: add missing effects in main signature, usually ! {IO, FS}."
  else if contains(e, "=>") || contains(e, "expected next token")
    then "Hint: AILANG uses match arms with => and lambdas as \\x. expr..."
  else if contains(e, "then") || contains(e, "got {")
    then "Hint: if syntax is `if cond then a else b` with no braces..."
  ...
}
```

These are propositional formulas over string-containment predicates. They are conjunctive clauses written by hand. This is literally what a Tsetlin Machine learns — but the TM learns them from data instead of from a developer's intuition about error messages.

The compose system (`src/core/ext/compose/`) runs an agentic loop where an LLM generates AILANG code through tool calls, the code is checked with `ailang check`, errors are classified and fed back, and telemetry tracks error counts per category (`check_error_parse`, `check_error_effect`, `check_error_type`, `check_error_import_or_symbol`, `check_error_other`). Every compose run produces labeled data: (AILANG snippet, error category or success).

The claim is: a TM trained on features extracted from AILANG ASTs can learn these classifiers — and discover patterns the hand-written rules miss — while producing rules that are readable, auditable, and translatable back into AILANG code.

---

## Feature Extraction: From AST to Boolean Vector

The first question is what boolean features to extract from an AILANG program. The features need to be computable before compilation (since the goal is to predict errors before or instead of running `ailang check`), which means they come from parsing the source text or a lightweight AST pass.

### Feature Categories

**Structural features** (does the program have X construct?):

| Feature | Meaning |
|---|---|
| `has_module_decl` | First line is `module path/name` |
| `has_export_main` | Contains `export func main` |
| `has_block_body` | Main function uses `{ }` body |
| `has_equals_body` | Main function uses `= expr` body |
| `uses_semicolons` | Contains `;` inside a block |
| `uses_in_keyword` | Contains `let ... in` binding |
| `mixes_semi_and_in` | Contains both `;` and `in` binding styles |
| `has_match_expr` | Contains `match ... {` |
| `match_arm_multi_let_no_braces` | Match arm has sequential `let` without wrapping `{ }` |
| `has_letrec` | Uses `letrec` for recursive lambda |
| `has_type_def` | Defines an ADT with `type X = ...` |
| `has_record_literal` | Contains `{field: value}` |
| `has_record_update` | Contains `{base | field: value}` |
| `has_lambda` | Contains `\x. body` |
| `has_curried_lambda` | Contains `\x. \y. body` (nested) |
| `uses_list_cons` | Contains `::` operator |
| `has_if_then_else` | Contains `if ... then ... else` |
| `uses_braces_in_if` | Contains `if ... {` (invalid syntax) |

**Import features** (what modules are imported?):

| Feature | Meaning |
|---|---|
| `imports_std_io` | Imports from `std/io` |
| `imports_std_fs` | Imports from `std/fs` |
| `imports_std_net` | Imports from `std/net` |
| `imports_std_json` | Imports from `std/json` |
| `imports_std_list` | Imports from `std/list` |
| `imports_std_string` | Imports from `std/string` |
| `imports_std_ai` | Imports from `std/ai` |
| `imports_std_env` | Imports from `std/env` |
| `imports_std_option` | Imports from `std/option` |
| `imports_std_result` | Imports from `std/result` |
| `imports_std_process` | Imports from `std/process` |
| `uses_quoted_import` | Contains `import "std/..."` (invalid) |

**Effect features** (what effects are declared?):

| Feature | Meaning |
|---|---|
| `declares_IO` | Signature includes `IO` in `! {..}` |
| `declares_FS` | Signature includes `FS` |
| `declares_Net` | Signature includes `Net` |
| `declares_AI` | Signature includes `AI` |
| `declares_Env` | Signature includes `Env` |
| `declares_Process` | Signature includes `Process` |
| `has_any_effect` | Signature has `! {..}` at all |
| `is_pure` | Function marked `pure func` |

**Call-site features** (what functions are called?):

| Feature | Meaning |
|---|---|
| `calls_println` | Body contains `println(` |
| `calls_print` | Body contains `print(` |
| `calls_readFile` | Body contains `readFile(` |
| `calls_writeFile` | Body contains `writeFile(` |
| `calls_httpGet` | Body contains `httpGet(` |
| `calls_httpPost` | Body contains `httpPost(` |
| `calls_call_ai` | Body contains `call(` from std/ai context |
| `calls_readLine` | Body contains `readLine(` |
| `calls_show` | Body contains `show(` |
| `calls_exec` | Body contains `exec(` |
| `calls_getArgs` | Body contains `getArgs(` |
| `calls_map` | Body contains `map(` |
| `calls_foldl` | Body contains `foldl(` |
| `calls_stringToInt` | Body contains `stringToInt(` |

**Anti-pattern features** (indicators of likely errors):

| Feature | Meaning |
|---|---|
| `print_without_show` | `println(` or `print(` with non-string argument and no `show` |
| `for_or_while` | Contains `for ` or `while ` (invalid in AILANG) |
| `uses_def_keyword` | Contains `def ` (Python habit) |
| `uses_class_keyword` | Contains `class ` (Python/JS habit) |
| `uses_arrow_fn_syntax` | Contains `=>` outside match context (JS habit) |
| `reserved_word_as_name` | Variable name is one of 43 reserved keywords |
| `concat_call_not_operator` | Contains `concat(a, b)` instead of `a ++ b` |
| `method_call_syntax` | Contains `list.map(` instead of `map(f, list)` |
| `curried_call_on_multiarg` | Uses `f(a)(b)` on a `func f(a, b)` definition |

This gives roughly 70-80 boolean features. With negations, that is 140-160 literals — well within TM capacity. Granmo's paper handles 784 features for MNIST.

---

## Classification Targets

Using the existing taxonomy from `ComposeTelemetry`:

| Label | Meaning |
|---|---|
| `correct` | Code passes `ailang check` |
| `effect` | Missing or wrong effect declaration |
| `parse` | Syntax error |
| `type` | Type mismatch or unification failure |
| `import_or_symbol` | Missing import or undefined symbol |
| `other` | Uncategorized error |

For multi-class classification, the TM uses one set of clauses per class (positive and negative polarity). Five error classes + one success class = six class-specific clause pools.

---

## Training Data

Training data comes from three sources, each naturally available in the AILANG ecosystem:

### 1. Compose Telemetry (Already Collected)

Every compose run (an LLM writing AILANG code) produces a sequence of (snippet, check_result) pairs. The snippet is the rendered AILANG source. The check_result is either success or an error string that `classify_ailang_error` already categorizes. The telemetry JSON records counts per category.

To extract training data: log the full snippet and error string at each check step. Feature extraction runs over the snippet text. The label comes from the existing classifier or directly from `ailang check` exit behavior.

This is the most valuable source because it captures the actual mistakes that LLM agents make when writing AILANG. The distribution of errors is different from what humans produce — agents disproportionately generate Python-isms (`def`, `for`, `class`), miss effect declarations, and confuse curried vs. multi-arg call conventions.

### 2. Test Suite and Benchmark Solutions

AILANG benchmark solutions (`module benchmark/solution`) in the test suite provide positive examples. Deliberately broken variants (e.g., removing an effect, adding a syntax error) provide negative examples with known labels. This is the curriculum approach from Gao et al. (2026).

### 3. LLM-Generated Synthetic Data (Paper 2 Approach)

Following the LLM-guided semantic bootstrapping from Paper 2:

1. **Sub-intent discovery**: Prompt an LLM to decompose each error class into sub-intents:
   - `effect_error_due_to_calling_println_without_IO`
   - `effect_error_due_to_calling_readFile_without_FS`
   - `parse_error_due_to_braces_in_if_expression`
   - `parse_error_due_to_mixed_let_binding_styles`
   - `type_error_due_to_print_without_show`
   - `import_error_due_to_missing_import_for_used_function`
   - `import_error_due_to_quoted_import_path`

2. **Three-stage generation** (seed -> core -> enriched): Generate AILANG snippets for each sub-intent with increasing lexical/structural variety. The seed stage uses real error examples from compose logs. The core stage varies the structure while preserving the error pattern. The enriched stage introduces surrounding code complexity.

3. **NTM pretraining**: Train the Non-Negated TM on synthetic examples to extract high-confidence literal sets per sub-intent. These become the symbolic features that capture "what an effect error looks like in code structure."

---

## What Learned Clauses Would Look Like

A TM trained on the features above might converge on clauses like these. These are not hypothetical — they are the propositional formulas that the feedback dynamics of the TM game would produce given the feature/label distribution.

### Effect Error Clauses

Positive polarity (votes for `effect` error):
```
Clause 1: calls_println AND NOT declares_IO
Clause 2: calls_readFile AND NOT declares_FS
Clause 3: calls_httpGet AND NOT declares_Net
Clause 4: calls_call_ai AND NOT declares_AI
Clause 5: calls_exec AND NOT declares_Process
Clause 6: calls_getArgs AND NOT declares_Env
```

These are exactly the rules that AILANG's effect checker enforces — but learned from examples, not from the language specification. Each clause is a propositional formula capturing one specific way an effect error manifests.

Negative polarity (votes against `effect` error):
```
Clause 7: calls_println AND declares_IO
Clause 8: NOT calls_println AND NOT calls_readFile AND NOT calls_httpGet AND is_pure
```

### Parse Error Clauses

```
Clause 1: mixes_semi_and_in
Clause 2: uses_braces_in_if
Clause 3: match_arm_multi_let_no_braces
Clause 4: uses_quoted_import
Clause 5: for_or_while
Clause 6: uses_arrow_fn_syntax AND NOT has_match_expr
```

### Import/Symbol Error Clauses

```
Clause 1: calls_println AND NOT imports_std_io AND NOT has_export_main
Clause 2: calls_readFile AND NOT imports_std_fs
Clause 3: calls_stringToInt AND NOT imports_std_string
Clause 4: calls_map AND NOT imports_std_list
```

(Note: `println` is in prelude for entry modules, so the `NOT has_export_main` literal matters — it distinguishes library modules where `println` requires an import from entry modules where it does not. The TM would discover this nuance from training data.)

### Type Error Clauses

```
Clause 1: print_without_show
Clause 2: curried_call_on_multiarg
Clause 3: method_call_syntax
```

### Cross-Class Discrimination

Type II feedback ensures clauses do not fire for the wrong class. For example, `calls_println AND NOT declares_IO` would initially fire for both `effect` errors and `import_or_symbol` errors (since a missing import for println also causes a missing function error). Type II feedback from `import_or_symbol` examples that have `NOT imports_std_io` would force the clause to include `imports_std_io` as a literal — refining it to:

```
calls_println AND NOT declares_IO AND imports_std_io
```

This says: "println is imported (so it's not a missing-import error) but IO is not declared (so it's an effect error)." The TM discovers the discrimination boundary between error classes through the game dynamics.

---

## Translation Back to AILANG Code

Learned clauses are propositional formulas. AILANG speaks propositional logic natively. The translation is mechanical:

```ailang
-- Learned TM clause, translated to AILANG
pure func predict_effect_error(f: CodeFeatures) -> bool ! {}
  ensures { result == (f.calls_println && not f.declares_IO && f.imports_std_io) }
{
  f.calls_println && not f.declares_IO && f.imports_std_io
}
```

Where `CodeFeatures` is a record type with one boolean field per feature:

```ailang
type CodeFeatures = {
  calls_println: bool,
  calls_readFile: bool,
  calls_httpGet: bool,
  declares_IO: bool,
  declares_FS: bool,
  declares_Net: bool,
  imports_std_io: bool,
  imports_std_fs: bool,
  ...
}
```

The full multi-clause classifier becomes:

```ailang
pure func classify_error(f: CodeFeatures) -> string ! {}
{
  -- Effect error clauses (positive polarity)
  let effect_pos_1 = f.calls_println && not f.declares_IO && f.imports_std_io;
  let effect_pos_2 = f.calls_readFile && not f.declares_FS;
  let effect_pos_3 = f.calls_httpGet && not f.declares_Net;
  -- Effect error clauses (negative polarity)
  let effect_neg_1 = f.calls_println && f.declares_IO;
  -- Effect vote
  let effect_vote = boolToInt(effect_pos_1) + boolToInt(effect_pos_2) + boolToInt(effect_pos_3)
                   - boolToInt(effect_neg_1);

  -- Parse error clauses
  let parse_pos_1 = f.mixes_semi_and_in;
  let parse_pos_2 = f.uses_braces_in_if;
  let parse_pos_3 = f.match_arm_multi_let_no_braces;
  let parse_vote = boolToInt(parse_pos_1) + boolToInt(parse_pos_2) + boolToInt(parse_pos_3);

  -- ... (import, type, other classes)

  -- Majority vote: highest vote wins
  argmax([
    ("effect", effect_vote),
    ("parse", parse_vote),
    ("import_or_symbol", import_vote),
    ("type", type_vote),
    ("correct", correct_vote)
  ])
}
```

This is Z3-verifiable. The pure function with integer arithmetic and boolean logic is exactly in AILANG's decidable fragment. Contracts can assert properties like "if no function calls are made, the prediction is never `effect`" — provable for all inputs.

---

## Comparison to the Hand-Written Classifier

The existing `classify_ailang_error` in `guard.ail` operates on the compiler's error MESSAGE text. It sees strings like "missing effect" or "unexpected token" and classifies from there. This has several limitations:

1. **Post-hoc**: It runs after `ailang check`, so it cannot predict errors before compilation. It is reactive, not predictive.

2. **Fragile**: If the compiler changes its error message wording, the classifier breaks. The predicates `contains(e, "missing effect")` are coupled to message format.

3. **Incomplete**: The `"other"` category is a catch-all. Any error pattern the developer did not anticipate falls through.

4. **Opaque intent**: The rules encode one developer's intuition about which substrings correlate with which error types. There is no principled coverage guarantee.

A TM operating on AST features instead of error text:

1. **Predictive**: It classifies code structure before compilation. It can preempt errors.

2. **Decoupled from compiler messages**: Features are extracted from the source code itself. Compiler message format is irrelevant.

3. **Complete by learning**: The TM's clause dynamics distribute representation across all observed patterns. Novel error patterns produce new clauses rather than falling to a catch-all.

4. **Auditable**: Every clause is a propositional formula that explains one specific way an error manifests. The rules are learned from data but readable by humans.

5. **Discoverable**: The TM may discover error-predicting patterns that a human rule-writer would miss. For example, a correlation between `has_curried_lambda AND calls_foldl` and type errors (because `foldl` takes a multi-arg function, but agents frequently pass a curried lambda). The hand-written classifier has no visibility into this — it only sees the error message after the fact.

---

## The Self-Improvement Loop

The compose system already runs an agentic loop:

```
LLM generates code -> ailang check -> classify error -> generate hint -> LLM retries
```

With a TM integrated:

```
LLM generates code
  -> extract features from AST
  -> TM predicts error class (before compilation)
  -> if TM predicts error:
       skip compilation, generate hint immediately (saves latency + API cost)
       feed back to LLM with targeted_hint
  -> if TM predicts correct:
       run ailang check to confirm
       if check fails: this is a TM misclassification -> new training example
       if check passes: confirmed correct
  -> log (features, actual_label) to training set
  -> periodically retrain TM on accumulated data
```

Each compose run makes the TM better. Misclassifications are self-correcting: when the TM predicts "correct" but `ailang check` finds an error, that becomes a training example that refines the clauses. When the TM predicts an error and preempts compilation, the latency savings compound across thousands of compose runs.

The learned clauses can also improve the hint generator. Instead of the hand-written `targeted_hint` function, the NTM's sub-intent literals provide semantic feature groups:

```
Sub-intent: effect_error_due_to_println_without_IO
Feature group: {calls_println, has_export_main, imports_std_io, NOT declares_IO}
Generated hint: "Function calls println (imported from std/io) but does not declare IO effect. Add ! {IO} to the function signature."
```

The hint is generated from the clause that fired, not from a hand-written table. New error patterns get new hints automatically.

---

## What This Means for AILANG's Compose System Specifically

The compose telemetry already tracks:
- `check_error_parse: int`
- `check_error_effect: int`
- `check_error_type: int`
- `check_error_import_or_symbol: int`
- `check_error_other: int`

A TM classifier could:

1. **Replace `classify_ailang_error`** with a learned classifier that operates on code features rather than error message strings. The learned version is more robust (decoupled from message format) and more informative (explains which code features triggered the classification).

2. **Replace `targeted_hint`** with hints derived from activated TM clauses. Each clause that fires explains one contributing factor. The hint generator walks the activated clauses and describes what each one found.

3. **Reduce compose iterations** by predicting errors before compilation. If the TM says "this snippet has an effect error because it calls readFile without declaring FS," the compose loop can skip `ailang check` and immediately feed the correction hint. At typical LLM API costs and latencies, this is a direct improvement to both cost and wall-clock time.

4. **Improve the guard** (`compose_snippet_guard`). The guard currently checks for fabricated analysis markers via string containment. A TM trained on features of fabricated vs. genuine analysis snippets could learn subtler indicators — for instance, that genuine analysis code tends to have `imports_std_fs AND calls_readFile AND declares_FS` while fabricated analysis tends to have `NOT imports_std_fs AND NOT calls_readFile AND has_export_main`.

5. **Feed telemetry with richer signals**. Instead of incrementing coarse counters, the telemetry could log which specific TM clauses activated, giving downstream analysis precise insight into what error patterns an LLM is prone to. This enables per-model error profiling: "Claude tends to trigger Clause 3 (curried call on multi-arg function) while GPT tends to trigger Clause 1 (missing IO effect)."

---

## Scale and Feasibility

The feature count (~80 features, ~160 literals) is modest by TM standards. The Granmo paper handles 784 features for MNIST with competitive accuracy. The Gao et al. paper handles full bag-of-words vocabularies (thousands of features) for text classification.

Training data volume depends on compose usage. Each compose run with 3-5 check iterations produces 3-5 labeled examples. A few hundred compose runs yields a dataset of 1000+ labeled snippets — sufficient for a TM to learn stable clauses. The synthetic data pipeline from Paper 2 can bootstrap the initial training set before real compose data accumulates.

The NTM variant is particularly well-suited here. Since we are learning what code features PREDICT errors (affirmative correlation), the monotonic conjunctions of the NTM (no negated literals) produce more interpretable rules: "this code calls println AND does not declare IO" reads naturally. The standard TM with negated literals would also learn useful rules, but the NTM's restriction to positive correlations aligns with the diagnostic framing ("what is present in the code that causes the error").

Feature extraction is cheap — regular expression or simple parsing over the source text, not a full compilation. This is important because the TM classifier is meant to run BEFORE or INSTEAD of `ailang check`, so it must be faster than full type-checking.

---

## Summary

The existing hand-written classifiers in `guard.ail` are propositional formulas over string-containment predicates, maintained by hand, operating post-hoc on error messages, with a catch-all for anything unanticipated.

A TM over AST features learns the same kind of formulas from data, operates predictively on code structure, discovers patterns humans miss, produces auditable rules, and improves with every compose run. The learned clauses translate directly to AILANG code that is Z3-verifiable.

This is not a speculative application of TMs to an unrelated domain. The compose system is already doing hand-written propositional classification on AILANG code. The TM automates and improves what is already there, using the same symbolic vocabulary AILANG already speaks.
