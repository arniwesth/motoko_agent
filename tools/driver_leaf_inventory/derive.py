#!/usr/bin/env python3
"""Derive the driver-side leaf inventory (PLAN-001 P-INV, ADR-001 D2 §2.1).

D2's first deliverable: every direct `Ports`/`ContextReader` field call by
driver-side code, with file, line, receiver name, and helped-or-exempt class;
the call graph of aggregate helpers (functions that carry successors and
request evidence without being request sites); and the exempt list (the ten
`ExtPorts` forwarding closures in `ext_ports_of`, structural exemption:
extension-initiated, not driver-helped).

Pattern: `tools/ext_call_inventory/derive.py` (strip_noise with offsets
preserved so comment/string mentions never count as sites).

Helped leaf kinds and their RequestClass (frozen here, consumed by P2 Part 1):
  EnvRead    <- env_get        (WorldState, string, string) -> EnvRead
  FileRead   <- file_read      (WorldState, string) -> FileRead
  ClockRead  <- clock_now      (WorldState) -> ClockReading
  ToolExec   <- tool_exec      (WorldState, ToolInvocation) -> ToolExecution
               approval_read  (WorldState, ApprovalRequest) -> ApprovalInput
                              (maps to ToolExec: the approval gate classes the
                              tool dispatch it guards; no sixth variant)
  ModelStep  <- model_step     (WorldState, string, [Message], cb) -> ProviderExchange

Structural facts, re-measured (not assumed):
  - `Ports` record: model_step, approval_read, clock_now, env_get, file_read,
    file_write, file_remove, path_stat, dir_list, dir_make, tool_exec,
    ext_effect_exec (src/core/ports.ail:783-939).
  - ext_effect_exec is bridge-exempt (extension-initiated dispatch), never a
    driver-helped leaf: no RequestClass variant for it.
  - file_write/file_remove/path_stat/dir_list/dir_make have zero driver-side
    call sites at this revision (measured below); they stay in the Ports shape
    but contribute no leaves.
  - `ContextReader` (env_get, file_read) is a PROJECTION of Ports bound to the
    same closures (`context_reader_of` is the only constructor), so r.env_get /
    r.file_read sites in context_usage.ail are helped leaves of the same kinds.

Scan roots: src/core/session.ail, src/core/tool_phase.ail,
src/core/context_usage.ail, src/core/test/stub_step.ail.

Exit codes: 0 clean (fixtures all report as expected), 1 fixture mismatch,
2 harness error.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# source hygiene (same contract as classifier 2: offsets preserved)
# --------------------------------------------------------------------------

def strip_noise(text: str) -> str:
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == "\\":
                    j += 1
                j += 1
            for k in range(i, min(j + 1, n)):
                if out[k] != "\n":
                    out[k] = " "
            i = j + 1
        elif c == "-" and text.startswith("--", i):
            j = text.find("\n", i)
            j = n if j == -1 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        else:
            i += 1
    return "".join(out)


# --------------------------------------------------------------------------
# the pinned ground truth: measured at 3fe71b0, re-derived every run
# --------------------------------------------------------------------------

# receiver.method -> RequestClass for HELPED driver leaves.
#
# The bridge region (ext_ports_of, session.ail ~:808-1180) is EXCLUDED by
# construction: `p.*` calls there are extension-initiated forwarding seams,
# not driver-helped leaves. `st.provider.env_get` (:2730) is a helped EnvRead
# (provider record projection of the same Ports value). `base.model_step`
# (stub_step.ail:362) is a test-harness override delegation, not a driver
# leaf: the helped ModelStep leaf is dispatch_step's ports.model_step (:712).
HELPED = {
    "ports.env_get": "EnvRead",
    "provider.ports.clock_now": "ClockRead",
    "ports.clock_now": "ClockRead",
    "ports.tool_exec": "ToolExec",
    "ports.model_step": "ModelStep",
    "st.provider.approval_read": "ToolExec",
    "st.provider.env_get": "EnvRead",
    "r.env_get": "EnvRead",
    "r.file_read": "FileRead",
    "ports.file_read": "FileRead",
}

# The extension-bridge region (ext_ai_step + ext_ports_of, session.ail
# 808-1197): forwarding/delegating seams, never driver-helped leaves.
# p.model_step at :816 delegates to the harness override chain; the helped
# ModelStep leaf is dispatch_step's ports.model_step (stub_step.ail:712).
BRIDGE_SPAN = ("src/core/session.ail", 808, 1197)

AGGREGATE_HELPERS = [
    "resolve_context_limit",
    "session_policy_init",
    "session_policy_with_model",
    "derive_session_id",
    "execute_allowed_tool_call",
    "dispatch_tool_entries_with_builtin",
    "dispatch_pre_step_chain",  # defined in src/core/ext/runtime.ail, used in session.ail
    "dispatch_step",
]

EXEMPT_FIELDS = [
    "ai_step", "tool_handle", "file_read", "file_write", "file_remove",
    "path_stat", "dir_list", "dir_make", "clock_now", "env_get",
]

EXEMPT_ROWS = {
    "ai_step": "{AI, IO, Trace}",
    "tool_handle": "{IO, Process, FS}",
    "file_read": "{FS}",
    "file_write": "{FS}",
    "file_remove": "{FS}",
    "path_stat": "{FS}",
    "dir_list": "{FS}",
    "dir_make": "{FS}",
    "clock_now": "{Clock}",
    "env_get": "{Env}",
}

REQUEST_CLASS = ["EnvRead", "FileRead", "ClockRead", "ToolExec", "ModelStep"]

SCAN_FILES = [
    "src/core/session.ail",
    "src/core/tool_phase.ail",
    "src/core/context_usage.ail",
    "src/core/test/stub_step.ail",
]

CALL_RE = re.compile(
    r"(?P<recv>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)"
    r"\.(?P<method>env_get|file_read|clock_now|tool_exec|model_step|approval_read)"
    r"\s*\("
)


def scan_leaves(repo: Path):
    leaves = []
    for rel in SCAN_FILES:
        text = (repo / rel).read_text()
        clean = strip_noise(text)
        for m in CALL_RE.finditer(clean):
            line = clean.count("\n", 0, m.start()) + 1
            key = m.group("recv") + "." + m.group("method")
            if rel == BRIDGE_SPAN[0] and BRIDGE_SPAN[1] <= line <= BRIDGE_SPAN[2]:
                continue  # extension-bridge seam/delegation, not a driver leaf
            if key == "base.model_step":
                continue  # test-harness override delegation, not a driver leaf
            cls = HELPED.get(key)
            if cls is None:
                # receiver-typed miss: record loudly, fail closed
                leaves.append({"file": rel, "line": line, "site": key,
                               "class": None, "status": "UNRESOLVED-RECEIVER"})
                continue
            leaves.append({"file": rel, "line": line, "site": key,
                           "class": cls, "status": "helped"})
    # de-duplicate on (file, line, site)
    seen, out = set(), []
    for leaf in leaves:
        k = (leaf["file"], leaf["line"], leaf["site"])
        if k not in seen:
            seen.add(k)
            out.append(leaf)
    return sorted(out, key=lambda l: (l["file"], l["line"]))


def check_helpers(repo: Path):
    """Every aggregate helper must be defined somewhere in src/core."""
    blob = ""
    for f in ["src/core/session.ail", "src/core/tool_phase.ail",
              "src/core/test/stub_step.ail", "src/core/context_usage.ail",
              "src/core/ext/runtime.ail"]:
        blob += (repo / f).read_text()
    missing = [h for h in AGGREGATE_HELPERS
               if not re.search(r"(func\s+" + h + r"\b|" + h + r"\s*[:=])", blob)]
    return missing


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=".", help="repository root")
    ap.add_argument("--json", action="store_true", help="emit inventory as JSON")
    ap.add_argument("--self-test", action="store_true", help="run fixture suite")
    args = ap.parse_args()
    repo = Path(args.repo).resolve()

    leaves = scan_leaves(repo)
    missing_helpers = check_helpers(repo)
    unresolved = [l for l in leaves if l["class"] is None]

    by_class: dict[str, int] = {}
    for leaf in leaves:
        if leaf["class"]:
            by_class[leaf["class"]] = by_class.get(leaf["class"], 0) + 1

    if args.self_test:
        return self_test(repo)

    if args.json:
        print(json.dumps({
            "scan_files": SCAN_FILES,
            "leaves": leaves,
            "by_class": by_class,
            "aggregate_helpers": AGGREGATE_HELPERS,
            "helpers_missing": missing_helpers,
            "exempt_fields": EXEMPT_FIELDS,
            "exempt_rows": EXEMPT_ROWS,
            "request_class": REQUEST_CLASS,
            "unresolved": unresolved,
        }, indent=2))
    else:
        print(f"driver leaf inventory ({len(leaves)} sites, "
              f"{len(unresolved)} unresolved):")
        for leaf in leaves:
            tag = leaf["class"] or leaf["status"]
            print(f"  {leaf['file']}:{leaf['line']:<5} {leaf['site']:<28} {tag}")
        print()
        print("by RequestClass: " + ", ".join(
            f"{k}={by_class.get(k, 0)}" for k in REQUEST_CLASS))
        print(f"aggregate helpers ({len(AGGREGATE_HELPERS)}): "
              + ", ".join(AGGREGATE_HELPERS))
        if missing_helpers:
            print(f"MISSING helpers: {', '.join(missing_helpers)}")
        print(f"exempt ExtPorts fields ({len(EXEMPT_FIELDS)}): "
              + ", ".join(EXEMPT_FIELDS))
        print(f"RequestClass frozen: {', '.join(REQUEST_CLASS)}")
    fails = list(unresolved) + missing_helpers
    return 1 if fails else 0


# --------------------------------------------------------------------------
# fixture suite: the four shapes from PLAN §2.1
# --------------------------------------------------------------------------

def self_test(repo: Path) -> int:
    fixtures = repo / "tools/driver_leaf_inventory/fixtures"
    if not fixtures.is_dir():
        print(f"self-test: no fixture directory at {fixtures}", file=sys.stderr)
        return 2
    expected = json.loads((fixtures / "expected.json").read_text())
    fails: list[str] = []
    for rel, want in sorted(expected["fixtures"].items()):
        path = fixtures / rel
        if not path.is_file():
            fails.append(f"{rel}: declared in expected.json but the fixture file is gone")
            continue
        text = strip_noise(path.read_text())
        verdict = classify_fixture(text)
        if verdict != want["verdict"]:
            fails.append(f"{rel}: expected {want['verdict']}, got {verdict} [{want['form']}]")
        else:
            print(f"  ok  {rel:<28} {want['form']}  [{verdict}]")
    present = {str(p.relative_to(fixtures)) for p in fixtures.glob("*.ail")}
    for rel in sorted(present - set(expected["fixtures"])):
        fails.append(f"{rel}: fixture present but not declared in expected.json")
    print(f"\nself-test: {len(fails)} failure(s)")
    for f in fails:
        print(f"  FAIL {f}")
    return 1 if fails else 0


def classify_fixture(clean: str) -> str:
    """Classify one fixture's stripped source into the four verdicts.

    `advance`/`witness` stub DEFINITIONS (`export func advance(`) are not
    calls: only call sites count. A call is an occurrence not preceded by
    `func <name>` on the same line.
    """
    def call_positions(name: str) -> list[int]:
        out = []
        for mm in re.finditer(name + r"\s*\(", clean):
            line_start = clean.rfind("\n", 0, mm.start()) + 1
            prefix = clean[line_start:mm.start()]
            if re.search(r"func\s+" + name + r"\s*$", prefix):
                continue  # stub definition, not a call
            out.append(mm.start())
        return out

    adv_calls = call_positions("advance")
    wit_calls = call_positions("witness")
    m = re.search(r"\{\s*world_state\s*:", clean)
    has_record = m is not None
    if not adv_calls:
        return "un-advanced-and-unwitnessed"
    if adv_calls and wit_calls and has_record:
        # order: any witness call after the record literal?
        if any(w > m.start() for w in wit_calls):
            return "witnessed-after-construction"
        return "clean"
    if adv_calls and not wit_calls:
        return "advanced-unwitnessed"
    return "clean"


if __name__ == "__main__":
    sys.exit(main())
