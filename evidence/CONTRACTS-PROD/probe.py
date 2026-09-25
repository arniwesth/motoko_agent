#!/usr/bin/env python3
"""Regenerate verifier-words.md: what the verifier says about each excused
declaration, for the synthesised `ensures { true }` the policy checker uses AND
for the honest property the excuse claims it could not state.

The second probe is the one that matters to a reader. `ensures { true }` being
rejected shows the function is outside the fragment; it does not show that the
PROPERTY WORTH STATING was tried. Both are recorded so a wrong reason is visible.

Usage: probe.py [> evidence/CONTRACTS-PROD/verifier-words.md]
"""
import re, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "tools/verify_classify/generated"

# (path, name, the honest property, one line on what it would have said)
CASES = [
 ("src/core/ext/registry_normalize.ail", "vote_family",
  'ensures { result == None || result == Some("tool-policy") || result == Some("finalize") }',
  "the four vote kinds fall into exactly two families"),
 ("src/core/ext/registry_normalize.ail", "capability_data",
  'ensures { result != jo([]) }', "every atom discloses at least its kind"),
 ("src/core/ext/registry_normalize.ail", "strings_json",
  'ensures { length(result) == length(xs) }', "no advertised name is dropped or duplicated"),
 ("src/core/ext/registry_normalize.ail", "atoms_data",
  'ensures { length(result) == length(caps) }', "one data position per atom, list order preserved"),
 ("src/core/ext/registry_normalize.ail", "config_digest_material",
  'ensures { result != jo([]) }', "the material carries config AND the atoms (N58)"),
 ("src/core/ext/registry_normalize.ail", "compare_bytes",
  'ensures { result == -1 || result == 0 || result == 1 }', "the ordering's three-valued range"),
 ("src/core/ext/registry_normalize.ail", "insert_kv",
  'ensures { length(result) == length(sorted) + 1 }', "insertion adds one key and drops none"),
 ("src/core/ext/registry_normalize.ail", "sort_kvs",
  'ensures { length(result) == length(kvs) }', "the sort is a permutation, not a filter"),
 ("src/core/ext/registry_normalize.ail", "canonical_kvs",
  'ensures { length(result) == length(kvs) }', "recursing into values loses no pair"),
 ("src/core/ext/registry_normalize.ail", "canonical_list",
  'ensures { length(result) == length(xs) }', "array order is preserved (must NOT sort)"),
 ("src/core/ext/registry_normalize.ail", "canonical",
  'ensures { result != JNull }', "canonicalisation changes key order and nothing else"),
 ("src/core/ext/registry_normalize.ail", "canonical_json",
  'ensures { result != "" }', "deterministic for equal inputs (a TWO-call property)"),
 ("src/core/ext/registry_normalize.ail", "ext_config_digest",
  'ensures { result != "" }', "depends on config AND the data positions (N58); also two-call"),
 ("src/core/ext/registry_normalize.ail", "ext_config_digests",
  'ensures { length(result) == length(entries) }', "one row per entry, registry order"),
 ("src/core/ext/runtime.ail", "entry_base",
  'ensures { result.decision_state == None }', "D3: other hook sites receive None"),
 ("src/core/ext/runtime.ail", "stub_decision_answer",
  'ensures { result.usage.cost_millicents == Some(0) }', "the unconfigured arm bills nothing"),
 ("src/core/ext/runtime.ail", "decision_invocation_state",
  'ensures { result.interventions_used == 0 && result.run_cap_millicents == None }',
  "a fresh state has spent nothing and claims no cap"),
 ("src/core/ext/runtime.ail", "decision_view",
  'ensures { result.decision_state != None }', "the cursor is the only site that stamps one"),
 ("src/core/dst_profile_coverage.ail", "count_purity",
  'ensures { result >= 0 && result <= length(ks) }', "a count is bounded by what it counts"),
 ("src/core/ext/ctx_defaults.ail", "empty_tool_evidence",
  'ensures { not result.complete_from_session_start }', "the window asserts no success"),
]

def probe(path, name, clause):
    src = ROOT / path
    text = src.read_text()
    m = re.search(rf"^((?:export\s+)?pure\s+func\s+{re.escape(name)}\s*\([^)]*\)[^\n]*)$", text, re.M)
    assert m, f"{path}:{name} not found"
    sig = m.group(1)
    after = sig.split("->", 1)[-1]
    body_here = sig.rstrip().endswith("{") and after.count("{") - after.count("}") == 1
    head = sig.rstrip()[:-1].rstrip() if body_here else sig
    tail = "\n  {" if body_here else ""
    probed = text[:m.start()] + head + "\n  " + clause + tail + text[m.end():]
    rel = src.relative_to(ROOT).with_suffix("").as_posix()
    stem = rel.replace("/", "_")
    probed = probed.replace(f"module {rel}", f"module tools/verify_classify/generated/{stem}_ev", 1)
    GEN.mkdir(parents=True, exist_ok=True)
    f = GEN / f"{stem}_ev.ail"
    f.write_text(probed)
    res = subprocess.run(["ailang", "verify", str(f.relative_to(ROOT))],
                         capture_output=True, text=True, cwd=ROOT)
    f.unlink(missing_ok=True)
    out = re.sub(r"\x1b\[[0-9;]*m", "", res.stdout + res.stderr)
    keep = [l.rstrip() for l in out.splitlines()
            if re.search(rf"\b(VERIFIED|SKIPPED|ERROR)\s+{re.escape(name)}\b", l)
            or "Reason:" in l or "encoding error:" in l or "Z3 error" in l or "Hint:" in l
            or "declared:" in l or l.strip().startswith("(Bool")]
    return "\n".join(keep) or out.strip()

print("# verifier-words — what blocks a contract on each excused declaration\n")
print("GENERATED by `evidence/CONTRACTS-PROD/probe.py`. Two probes per declaration:\n")
print("* **trivial** — the `ensures { true }` the policy checker synthesises. Rejection")
print("  here is what makes the `-- contracts:` line pass its own gate.")
print("* **honest property** — what the excuse says it wanted to state. This is the one")
print("  worth reading: a rejected `true` shows the function is outside the fragment, but")
print("  only this shows the real property was tried rather than assumed impossible.\n")
for path, name, clause, gloss in CASES:
    print(f"\n## `{name}`\n\n`{path}`\n")
    print(f"**trivial** — `ensures {{ true }}`\n\n```\n{probe(path, name, 'ensures { true }')}\n```\n")
    print(f"**honest property** — {gloss}\n\n```ail\n  {clause}\n```\n")
    print(f"```\n{probe(path, name, clause)}\n```")
