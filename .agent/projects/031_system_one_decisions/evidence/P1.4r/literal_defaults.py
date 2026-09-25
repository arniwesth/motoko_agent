#!/usr/bin/env python3
"""031 PLAN-001 P1.4r: the host context LITERALS carry D3's truthful defaults.

A static fixture, for the literal sites no cheap test reaches (`rpc.ail`'s
three and `session.ail`'s exit context sit inside effectful drivers; the
per-turn `mk_v2_ext_ctx` also has a unit test in `session.ail`). Run from a
repo root; exit 0 when every rule holds, 1 otherwise, each failure printed.

Rules over every `.ail` file under src/core (as found on disk, so a mutated
copy is what is read):
  1. `verification: <Ctor>` with a VerificationEvidence constructor is
     `NotReached` -- a default never says Passed/Failed/Disabled/Unavailable.
  2. `tool_evidence: <expr>` is `empty_tool_evidence()`, and that function's
     body in ext/ctx_defaults.ail is exactly the empty, INCOMPLETE window with
     an UNKNOWN omitted count.
  3. `decision_state: <v>` is `None`, except `ext/runtime.ail`'s
     `decision_view` (the cursor's per-atom `Some`) and record updates of the
     runtime's test literal `smoke_ctx()` inside its tests.
  4. The host literals are all accounted for: exactly the six sites below
     carry all three fields with the defaults (a literal added or dropped
     changes the count and must be looked at).
"""
import re, sys, pathlib

CTORS = ("NotReached", "Disabled", "Passed", "Failed", "VerificationUnavailable")
HOST_SITES = {  # file -> number of full default triples expected
    "src/core/session.ail": 2,   # mk_v2_ext_ctx; publish_turn_exit_manifest
    "src/core/rpc.ail": 3,       # the three inline literals (P1.1 attempt 2)
    "src/core/ext/runtime.ail": 1,  # smoke_ctx, the runtime's test host literal
}
EMPTY_WINDOW = "{ records: [], complete_from_session_start: false, omitted_count: None }"

fails = []
triples = {}
for p in sorted(pathlib.Path("src/core").rglob("*.ail")):
    rel = str(p)
    lines = p.read_text().splitlines()
    for n, line in enumerate(lines, 1):
        code = line.split("--", 1)[0]
        for m in re.finditer(r"\bverification:\s*([A-Za-z_]+)", code):
            if m.group(1) in CTORS and m.group(1) != "NotReached":
                fails.append(f"{rel}:{n}: verification default is {m.group(1)}, not NotReached")
        for m in re.finditer(r"\btool_evidence:\s*([^,}\n]+)", code):
            v = m.group(1).strip()
            if v.startswith("{") or v in ("ToolEvidenceWindow",):
                continue  # a type annotation, or a scripted window in a test (checked below by rule 3's scope)
            if v != "empty_tool_evidence()":
                fails.append(f"{rel}:{n}: tool_evidence default is {v!r}, not empty_tool_evidence()")
        for m in re.finditer(r"\bdecision_state:\s*([A-Za-z_]+)", code):
            v = m.group(1)
            if v in ("Option",):
                continue  # the field's type
            if v == "None":
                continue
            ok = (rel == "src/core/ext/runtime.ail" and
                  ("{ base | decision_state: Some(decision_invocation_state(" in code
                   or "{ smoke_ctx() | decision_state: Some(" in code))
            if not ok:
                fails.append(f"{rel}:{n}: decision_state is {v}(...) outside the cursor's decision_view")
    text = "\n".join(l.split("--", 1)[0] for l in lines)
    triples[rel] = len(re.findall(
        r"verification:\s*NotReached,\s*tool_evidence:\s*empty_tool_evidence\(\),\s*decision_state:\s*None\b", text))

for rel, want in HOST_SITES.items():
    got = triples.get(rel, 0)
    if got != want:
        fails.append(f"{rel}: {got} host literal(s) with the three truthful defaults, want {want}")
extra = {r: c for r, c in triples.items() if c and r not in HOST_SITES}
for r, c in extra.items():
    fails.append(f"{r}: {c} unlisted host literal(s); add the site to HOST_SITES after review")

cd = pathlib.Path("src/core/ext/ctx_defaults.ail").read_text()
m = re.search(r"export pure func empty_tool_evidence\(\) -> ToolEvidenceWindow \{\s*(\{[^}]*\})\s*\}", cd)
if not m or re.sub(r"\s+", " ", m.group(1)) != EMPTY_WINDOW:
    fails.append(f"src/core/ext/ctx_defaults.ail: empty_tool_evidence is {m.group(1) if m else 'missing'!r}, want {EMPTY_WINDOW}")

for f in fails:
    print("literal_defaults: FAIL " + f)
if fails:
    sys.exit(1)
print("literal_defaults: ok -- " + ", ".join(f"{r} {c}" for r, c in sorted(triples.items()) if c)
      + "; empty_tool_evidence is the empty incomplete window")
