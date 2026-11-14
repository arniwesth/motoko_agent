#!/usr/bin/env python3
"""make_mutants.py — builds the mutation-check files from ../HerdrFailureModel.lean.

Each mutant = the model part (up to `## Theorems`) with ONE behaviour changed, plus the
definitions the witnesses use, and the STATEMENTS of two `bug_` theorems copied verbatim and
evaluated with `#eval decide (...)`: the TARGET states the very behaviour the mutant removes and
must evaluate to `false` on the mutant (so it cannot be proved there: the theorem is not
vacuous), the CONTROL is about an unrelated behaviour and must still be `true`.

Why `#eval` and not the proofs: a failing `decide +kernel` on a mutant drives Lean past 6 GB
before it reports (measured), so whole-file mutant runs are OOM-killed. `#eval` is a diagnostic
here only; no reported theorem uses compiled evaluation."""
import re, pathlib
here = pathlib.Path(__file__).parent
src = (here / "../HerdrFailureModel.lean").read_text()
model = src[:src.index("/-! ## Theorems")]
defs = "\n".join(l for l in src.splitlines()
                 if re.match(r"def (notFound|agentNotFound|undecodable|canonical) ", l))
def stmt(name):
    m = re.search(r"\ntheorem " + name + r" :\n(.*?):= by", src, re.S)
    return m.group(1).rstrip()   # keep the indentation: `let` bodies are layout-sensitive
MUT = {
  "M1_ts_verdict_narrowed": (
     'def herdrMeansAgentGone (r : HerdrResult) : Bool :=\n  endsWithL (herdrFailureCode r) "_not_found".toList',
     'def herdrMeansAgentGone (r : HerdrResult) : Bool :=\n  herdrFailureCode r == "agent_not_found".toList   -- MUTANT',
     "bug_p21_suffix", "bug_p21_key_order"),
  "M2_ts_exit_zero_only": (
     "  else if r.code ≤ 0 then []", "  else if r.code = 0 then []   -- MUTANT",
     "bug_p21_negative_exit", "bug_p21_suffix"),
  "M3_ail_json_first": (
     '  else if containsL stderr nestedPat then "nested_herdr".toList\n  else if containsL stderr errPat then "herdr_json".toList',
     '  else if containsL stderr errPat then "herdr_json".toList   -- MUTANT\n  else if containsL stderr nestedPat then "nested_herdr".toList',
     "bug_p21_nested_in_message", "bug_p21_trailing_text"),
  "M4_ail_decode_whole_input": (
     "  | some (v, _) => some v\n  | none => none''')" if False else "  match parseValue false (2 * s.length + 2) s with\n  | some (v, _) => some v",
     "  match parseValue false (2 * s.length + 2) s with\n  | some (v, r) => if skipWs r = [] then some v else none   -- MUTANT",
     "bug_p21_trailing_text", "bug_p21_suffix"),
}
for name, (old, new, target, control) in MUT.items():
    assert model.count(old) == 1, name
    body = model.replace(old, new) + "\n" + defs + "\n\n" + \
        f"def targetHolds : Bool := decide (\n{stmt(target)})\n\n" + \
        f"def controlHolds : Bool := decide (\n{stmt(control)})\n\n" + \
        f"#eval IO.println s!\"TARGET {target} {{targetHolds}}\"\n" + \
        f"#eval IO.println s!\"CONTROL {control} {{controlHolds}}\"\n"
    (here / f"{name}.lean").write_text(f"-- {name}: target {target} must be false, control {control} true\n" + body)
    print(name, target, control)
