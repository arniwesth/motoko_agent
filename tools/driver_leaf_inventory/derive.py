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
                              tool dispatch it guards; not a variant of its own)
  ModelStep  <- model_step     (WorldState, string, [Message], cb) -> ProviderExchange
  WakeRead   <- wake_read      (WorldState, ParkRequest) -> WakeInput
                              (the SIXTH class, PLAN-002 W3 under ADR-002 D2: a
                              wake is an operator/host observation that is not
                              the tool dispatch approval guards, so it does not
                              fold into ToolExec. No driver call site until W4;
                              the fixture pair form_wake_read_unwitnessed /
                              control_wake_read_witnessed pins its verdicts)

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
    # PLAN-002 W3 (ADR-002 D2). No tree site until W4's Park arm; the fixture
    # pair is what exercises these today.
    "ports.wake_read": "WakeRead",
    "st.provider.wake_read": "WakeRead",
}

# The extension-bridge region (ext_ai_step + ext_ports_of, session.ail
# 788-1177): forwarding/delegating seams, never driver-helped leaves.
# p.model_step at :795 delegates to the harness override chain; the helped
# ModelStep leaf is dispatch_step's ports.model_step (stub_step.ail:712).
#
# RE-PINNED, NOT WIDENED (ADR-003 D1, PLAN-003 P1 Part 3). The span was
# 808-1197 and every line in it moved -20 when `RuntimeStatusCounts` and its two
# helpers left session.ail for phase_vocab.ail; `ext_ai_step` still opens the
# region and the `file_write` bridge still closes it, character for character.
# This is a LINE PIN over unchanged content, the same class of artifact as the
# attribution anchors, and it is re-pinned here rather than deferred because
# unlike `make anchors` this gate is GREEN at HEAD and a stale span reports
# `p.model_step` as an unresolved driver leaf — a fail-closed error, not drift.
#
# RE-PINNED AGAIN AT PLAN-003 P3 PART 3, 829-1218 -> 1045-1434, ALL +216, and
# the content is UNCHANGED: `diff` of `git show HEAD:src/core/session.ail | sed
# -n '829,1218p'` against `sed -n '1045,1434p'` of the working tree is EMPTY.
# The whole +216 is above the span — ADR-003 D1's chain-digest type, its four
# helpers, the journal-class event builders and the `history_digest` field on
# `C2LoopState`, which is declared where the record is declared, at the top of
# the file. No leaf was added, removed or re-routed: the inventory is the same
# 26 sites with the same classes, and the two UNRESOLVED-RECEIVER rows inside
# the span (`p.file_read`, `p.clock_now`) are the same two the span exists to
# exclude — with the span applied the inventory is 24 sites and 0 unresolved,
# which is what P1 Part 4 measured. §0.8's frozen `HELPED`, `CALL_RE` and
# `REQUEST_CLASS` are untouched.
# RE-PINNED AT PLAN-002 W2, 1045-1434 -> 1061-1450, ALL +16, content UNCHANGED:
# `diff` of `git show 957c91e:src/core/session.ail | sed -n '1045,1434p'` against
# `sed -n '1061,1450p'` of the working tree is EMPTY. The +16 is above the span:
# `C2LoopState.open_waits` and its comment (ADR-002 D2/D3), declared with the
# record. No leaf was added, removed or re-routed.
# RE-PINNED AT PLAN-002 W4, 1061-1450 -> 1085-1474, ALL +24, content UNCHANGED:
# `diff` of `git show 9430873:src/core/session.ail | sed -n '1061,1450p'` against
# `sed -n '1085,1474p'` of the working tree is EMPTY. The +24 is above the span:
# `C2LoopState.park_ordinal`/`park_attempt` and `initial_park_ordinal` (ADR-002
# D2, PLAN-002 §8.4). No leaf was added, removed or re-routed inside the span.
BRIDGE_SPAN = ("src/core/session.ail", 1085, 1474)

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

REQUEST_CLASS = ["EnvRead", "FileRead", "ClockRead", "ToolExec", "ModelStep", "WakeRead"]

SCAN_FILES = [
    "src/core/session.ail",
    "src/core/tool_phase.ail",
    "src/core/context_usage.ail",
    "src/core/test/stub_step.ail",
]

CALL_RE = re.compile(
    r"(?P<recv>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)"
    r"\.(?P<method>env_get|file_read|clock_now|tool_exec|model_step|approval_read|wake_read)"
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


# --------------------------------------------------------------------------
# order-of-witness over the TREE (PLAN-001 P2D; ADR-001 D2 part 6)
# --------------------------------------------------------------------------
#
# Until P2D the tree scan only proved that every leaf RESOLVES to a class; the
# order-of-witness rule was exercised on the four fixtures alone. This checks
# it at the 24 production sites, with the same verdict function the fixtures
# go through (`leaf_verdict`), so a fixture and a tree site cannot disagree
# about what "witnessed in order" means.
#
# Per leaf, inside its enclosing function, textually:
#   1. ADVANCED   the successor `B.next_state` of the leaf's binding `B` is
#                 passed to `advance(` — else `un-advanced-and-unwitnessed`;
#                 and it is never used un-advanced (up to a rebinding of `B`)
#                 — else `un-advanced-carry`.
#   2. IN ORDER   a `witness(` whose arguments carry the advanced successor
#                 (inline, or through `let V = advance(B.next_state …)`) comes
#                 before any record FIELD carrying it — else
#                 `witnessed-after-construction`; no such witness and a field
#                 carries it with a later `witness(` → the same verdict; no
#                 witness at all → `advanced-unwitnessed`.
#   3. RETURNED   a leaf in a function with no witness is legal only when the
#                 function is a RETURNING helper below: its successor leaves in
#                 a `next_state:` field and is witnessed ON RECEIPT.
#
# Receipts (RECEIPTS) are checked the same way at their binding in session.ail:
# the first use of the received successor must be inside a `witness(` or inside
# a helped leaf call whose own verdict is `clean`.
#
# WHAT THIS CANNOT SEE, recorded (the ADR's restricted claim, amended at P2D):
#   - cross-function flow. Policy init and the eight `context_usage` reads reach
#     their witness through `{ pp | world: init.next_state }` and the traced
#     entry's provider (D2 part 2, Bootstrap); `execute_allowed_tool_call`'s
#     successor threads through `dispatch_tool_entries_with_builtin`'s recursion
#     to `ToolDispatchDone`/`Pending`. Those links are HAND-MAINTAINED
#     (BOOTSTRAP_CHAIN below) and covered at runtime by `make world_framed_wire`.
#   - a whole-record drop (`st` for `post`): no textual shape distinguishes it;
#     the frame gate's repeated-ordinal red is the instrument.

RETURNING = {
    # function -> where its successor is witnessed (receipt), for the report
    "derive_session_id": "receipt: traced entries' start-clock witness (RECEIPTS)",
    "session_policy_init": "bootstrap chain (BOOTSTRAP_CHAIN; hand-maintained)",
    "catalog_path": "bootstrap chain via resolve_context_limit_sum (hand-maintained)",
    "catalogue_read": "bootstrap chain via resolve_context_limit_sum (hand-maintained)",
    "profile_dir_path": "bootstrap chain via resolve_context_limit_sum (hand-maintained)",
    "config_context_limit_override": "bootstrap chain via resolve_context_limit_sum (hand-maintained)",
    "execute_allowed_tool_call": "receipt: c2_loop executed / ToolDispatchDone / ToolDispatchPending (RECEIPTS)",
    "dispatch_step": "receipt: c2_loop exchange (RECEIPTS)",
}

# (helper, file, enclosing function, binding regex, received successor)
RECEIPTS = [
    ("dispatch_step", "src/core/session.ail", "c2_loop",
     r"let\s+exchange\s*=\s*dispatch_step\s*\(", "exchange.next_state"),
    ("execute_allowed_tool_call", "src/core/session.ail", "c2_loop",
     r"let\s+executed\s*=\s*execute_allowed_tool_call\s*\(", "executed.next_state"),
    ("execute_allowed_tool_call", "src/core/session.ail", "c2_loop",
     r"ToolDispatchDone\s*\(\s*done\s*\)\s*=>", "done.world"),
    ("execute_allowed_tool_call", "src/core/session.ail", "c2_loop",
     r"ToolDispatchPending\s*\(\s*pending\s*\)\s*=>", "pending.world"),
    ("derive_session_id", "src/core/session.ail", "run_v2_traced_from_seed",
     r"let\s+derived\s*=\s*derive_session_id\s*\(", "derived.next_state"),
    ("derive_session_id", "src/core/session.ail", "run_v2_from_messages_with_policy_and_counts",
     r"let\s+derived\s*=\s*derive_session_id\s*\(", "derived.next_state"),
]

BOOTSTRAP_CHAIN = [
    "session_policy_init's successor -> `{ pp | world: init.next_state }` -> the traced entry's "
    "provider.world -> derive_session_id -> start clock -> witness (run_v2_traced_from_seed / "
    "run_v2_from_messages_with_policy_and_counts)",
    "context_usage's four functions -> resolve_context_limit_sum -> session_policy_init (above)",
    "execute_allowed_tool_call -> dispatch_tool_entries_with_builtin recursion -> "
    "ToolDispatchDone.world / ToolDispatchPending.world (RECEIPTS)",
]

CLEAN_VERDICTS = ("clean", "returned")

# PLAN-002 W4 (ADR-002 D2). A leaf whose PORT returns an already-advanced
# successor. `wake_read`'s adapters advance inside themselves: W3's unbound
# default returns `advance(world, WakeRead)` (PLAN-002 §1 row 1), W4's scripted
# adapter `advance({ w | wakes: rest }, WakeRead)` (W4 Part 4), and the `Park`
# arm owes only a witness because "the port has advanced the world either way"
# (W4 Part 2). For these, `B.next_state` IS the advanced successor: the
# ADVANCED step (1) is satisfied by the port, and steps 2-3 read `B.next_state`
# as the carried value. A call-site `advance(B.next_state …)` is still read as
# a carry too, so W3's two fixtures keep their verdicts.
PORT_ADVANCED_METHODS = ("wake_read",)

FUNC_RE = re.compile(r"^(?:export\s+)?(?:pure\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)


def func_spans(clean: str):
    starts = [(m.start(), m.group(1)) for m in FUNC_RE.finditer(clean)]
    out = []
    for i, (s, name) in enumerate(starts):
        e = starts[i + 1][0] if i + 1 < len(starts) else len(clean)
        out.append((s, e, name))
    return out


def enclosing(spans, pos: int):
    for s, e, name in spans:
        if s <= pos < e:
            return s, e, name
    return None


def paren_span(clean: str, open_idx: int) -> int:
    """Index just past the `)` matching the `(` at open_idx (strings/comments are blanked)."""
    depth, i = 0, open_idx
    while i < len(clean):
        if clean[i] == "(":
            depth += 1
        elif clean[i] == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return len(clean)


def witness_calls(clean: str, lo: int, hi: int):
    """(start, args_text) for every `witness(` CALL in [lo, hi)."""
    out = []
    for m in re.finditer(r"\bwitness\s*\(", clean[lo:hi]):
        start = lo + m.start()
        line_start = clean.rfind("\n", 0, start) + 1
        if re.search(r"func\s+$", clean[line_start:start]):
            continue  # a definition, not a call
        open_idx = lo + m.end() - 1
        out.append((start, clean[open_idx:paren_span(clean, open_idx)]))
    return out


def leaf_verdict(clean: str, call_start: int, fn_end: int, fn_name: str, port_advanced: bool = False) -> str:
    line_start = clean.rfind("\n", 0, call_start) + 1
    lets = list(re.finditer(r"\blet\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]*)?=", clean[line_start:call_start]))
    if not lets:
        return "unbound-leaf"
    b = re.escape(lets[-1].group(1))
    tail_end = fn_end
    # a rebinding of B ends B's scope at the end of that line
    rb = re.search(r"\blet\s+" + b + r"\s*(?::[^=]*)?=", clean[call_start:fn_end])
    if rb:
        eol = clean.find("\n", call_start + rb.end())
        tail_end = fn_end if eol == -1 else min(fn_end, eol)
    t0, tail = call_start, clean[call_start:tail_end]
    adv = r"advance\s*\(\s*" + b + r"\.next_state\b"
    if not port_advanced:
        if not re.search(adv, tail):
            return "un-advanced-and-unwitnessed"
        for m in re.finditer(r"\b" + b + r"\.next_state\b", tail):
            if not re.search(r"advance\s*\(\s*$", tail[:m.start()]):
                return "un-advanced-carry"
    cands = [adv] if not port_advanced else [adv, r"\b" + b + r"\.next_state\b"]
    vm = re.search(r"\blet\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]*)?=\s*" + adv, tail)
    if vm:
        cands.append(r"\b" + re.escape(vm.group(1)) + r"\b(?!\s*[:=(])")
    carry = "(?:" + "|".join(cands) + ")"
    wits = witness_calls(clean, t0, fn_end)
    w = next((ws for ws, args in wits if re.search(carry, args)), None)
    field = re.search(r"\b[A-Za-z_][A-Za-z0-9_]*\s*:\s*" + carry, clean[t0:fn_end])
    field_at = None if field is None else t0 + field.start()
    if w is not None:
        if field_at is not None and field_at < w:
            return "witnessed-after-construction"
        return "clean"
    if field_at is not None and any(ws > field_at for ws, _ in wits):
        return "witnessed-after-construction"
    if fn_name in RETURNING:
        return "returned"
    return "advanced-unwitnessed"


def order_check(repo: Path, leaves, texts: dict | None = None):
    """Attach a verdict to each leaf; check RECEIPTS. Returns (leaves, receipt_rows)."""
    texts = texts or {}
    cache = {}

    def clean_of(rel):
        if rel not in cache:
            cache[rel] = strip_noise(texts.get(rel) or (repo / rel).read_text())
        return cache[rel]

    clean_verdict_at = {}
    for leaf in leaves:
        clean = clean_of(leaf["file"])
        spans = func_spans(clean)
        # re-locate the call on its line (offsets, not line numbers, drive the check)
        ls = 0
        for _ in range(leaf["line"] - 1):
            ls = clean.find("\n", ls) + 1
        le = clean.find("\n", ls)
        m = CALL_RE.search(clean, ls, len(clean) if le == -1 else le)
        encl = enclosing(spans, ls)
        if m is None or encl is None:
            leaf["order"], leaf["function"] = "unlocated", None
            continue
        _, fe, fn = encl
        leaf["function"] = fn
        leaf["order"] = leaf_verdict(clean, m.start(), fe, fn, m.group("method") in PORT_ADVANCED_METHODS)
        clean_verdict_at[(leaf["file"], m.start())] = leaf["order"]

    rows = []
    for helper, rel, fn, bind_re, succ in RECEIPTS:
        clean = clean_of(rel)
        span = next(((s, e) for s, e, n in func_spans(clean) if n == fn), None)
        row = {"helper": helper, "file": rel, "function": fn, "successor": succ}
        if span is None:
            rows.append({**row, "line": None, "verdict": "receipt-function-missing"})
            continue
        s, e = span
        bm = re.compile(bind_re).search(clean, s, e)
        if bm is None:
            rows.append({**row, "line": None, "verdict": "receipt-binding-missing"})
            continue
        row["line"] = clean.count("\n", 0, bm.start()) + 1
        use = re.compile(r"\b" + re.escape(succ) + r"\b").search(clean, bm.end(), e)
        if use is None:
            rows.append({**row, "verdict": "receipt-dropped"})
            continue
        verdict = "receipt-used-before-witness"
        for ws, args in witness_calls(clean, bm.end(), e):
            if ws < use.start() < ws + len("witness") + len(args) + 1:
                verdict = "clean"
                break
        if verdict != "clean":
            for cm in CALL_RE.finditer(clean, bm.end(), use.start()):
                open_idx = cm.end() - 1
                if use.start() < paren_span(clean, open_idx) and \
                        clean_verdict_at.get((rel, cm.start())) == "clean":
                    verdict = "clean"
                    break
        rows.append({**row, "verdict": verdict})
    return leaves, rows


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
    leaves, receipts = order_check(repo, leaves)
    out_of_order = [l for l in leaves
                    if l["class"] is not None and l.get("order") not in CLEAN_VERDICTS]
    unreceived = [r for r in receipts if r["verdict"] != "clean"]
    unowned = sorted({l["function"] for l in leaves
                      if l.get("order") == "returned" and l["function"] not in RETURNING})

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
            "receipts": receipts,
            "bootstrap_chain_hand_maintained": BOOTSTRAP_CHAIN,
            "out_of_order": out_of_order,
        }, indent=2))
    else:
        print(f"driver leaf inventory ({len(leaves)} sites, "
              f"{len(unresolved)} unresolved, {len(out_of_order)} out of order):")
        for leaf in leaves:
            tag = leaf["class"] or leaf["status"]
            print(f"  {leaf['file']}:{leaf['line']:<5} {leaf['site']:<28} {tag:<10} "
                  f"{leaf.get('order')}  [{leaf.get('function')}]")
        print()
        print(f"receipts ({len(receipts)}, {len(unreceived)} red):")
        for r in receipts:
            print(f"  {r['file']}:{r['line'] or '?':<5} {r['helper']:<26} "
                  f"{r['successor']:<20} {r['verdict']}  [{r['function']}]")
        print("hand-maintained (cross-function; runtime-covered by make world_framed_wire):")
        for c in BOOTSTRAP_CHAIN:
            print(f"  - {c}")
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
        for l in out_of_order:
            print(f"FAIL order: {l['file']}:{l['line']} {l['site']} -> {l.get('order')} [{l.get('function')}]")
        for r in unreceived:
            print(f"FAIL receipt: {r['file']}:{r['line']} {r['helper']} {r['successor']} -> {r['verdict']} [{r['function']}]")
        for fn in unowned:
            print(f"FAIL returning helper not in RETURNING: {fn}")
    fails = list(unresolved) + missing_helpers + out_of_order + unreceived + unowned
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
    fails += tree_mutants(repo)
    print(f"\nself-test: {len(fails)} failure(s)")
    for f in fails:
        print(f"  FAIL {f}")
    return 1 if fails else 0


def classify_fixture(clean: str) -> str:
    """Classify one fixture's stripped source through the TREE's verdict.

    The fixture's helped leaves are found with the tree's CALL_RE/HELPED and
    judged by `leaf_verdict` — the function `order_check` applies at the 24
    production sites — so the four fixtures test the tree check itself, not a
    fixture-only classifier. A fixture's verdict is its first non-clean leaf's.
    """
    spans = func_spans(clean)
    verdicts = []
    for m in CALL_RE.finditer(clean):
        if HELPED.get(m.group("recv") + "." + m.group("method")) is None:
            continue
        encl = enclosing(spans, m.start())
        if encl is None:
            verdicts.append("unlocated")
            continue
        verdicts.append(leaf_verdict(clean, m.start(), encl[1], encl[2], m.group("method") in PORT_ADVANCED_METHODS))
    if not verdicts:
        return "no-helped-leaf"
    return next((v for v in verdicts if v not in CLEAN_VERDICTS), verdicts[0])


# In-memory mutants of the REAL tree: each is one same-line textual edit (so
# line numbers do not move) that must turn the tree check red at a named site.
# The fixtures prove the verdict function on toy sources; these prove it still
# bites on session.ail/tool_phase.ail as they stand. A mutant whose anchor text
# is gone fails the self-test — a stale mutant is not a passing one.
TREE_MUTANTS = [
    ("witness moved after the approval record",
     "src/core/session.ail",
     "let approved = witness(session_id, trace_with_decision, advance(input.next_state, ToolExec)); "
     "let post: C2LoopState = { st | world_state: approved.world };",
     "let post0: C2LoopState = { st | world_state: advance(input.next_state, ToolExec) }; "
     "let approved = witness(session_id, trace_with_decision, post0.world_state); "
     "let post: C2LoopState = { st | world_state: approved.world };",
     ("leaf", "st.provider.approval_read", {"witnessed-after-construction"})),
    ("tool_exec successor returned un-advanced",
     "src/core/tool_phase.ail",
     "next_state: advance(execution.next_state, ToolExec),",
     "next_state: execution.next_state,",
     ("leaf", "ports.tool_exec", {"un-advanced-and-unwitnessed", "un-advanced-carry"})),
    ("dispatch_step's successor not witnessed on receipt",
     "src/core/session.ail",
     "exchange.next_state); let trace_after_call = stepped.trace;",
     "st.world_state); let trace_after_call = stepped.trace;",
     ("receipt", "exchange.next_state", {"receipt-dropped", "receipt-used-before-witness"})),
    # PLAN-002 W4 gate 4 (W3 Part 6's tree half): the `Park` arm's witness
    # removed. The port-advanced successor then reaches a record field with no
    # witness draining it.
    ("wake_read successor not witnessed",
     "src/core/session.ail",
     "let woke = witness(session_id, trace_entered, wake.next_state);",
     "let woke = { trace: trace_entered, world: wake.next_state };",
     ("leaf", "st.provider.wake_read", {"advanced-unwitnessed", "witnessed-after-construction"})),
    ("exit-publish read never witnessed",
     "src/core/session.ail",
     "let seen = witness(session_id, trace, named_world);",
     "let seen = { trace: trace, world: named_world };",
     ("leaf", "ports.env_get@publish_turn_exit_manifest",
      {"advanced-unwitnessed", "witnessed-after-construction"})),
]


def tree_mutants(repo: Path) -> list[str]:
    fails = []
    for name, rel, old, new, (kind, key, want) in TREE_MUTANTS:
        text = (repo / rel).read_text()
        if text.count(old) != 1:
            fails.append(f"mutant '{name}': anchor text occurs {text.count(old)} time(s) in {rel}, expected 1 (stale mutant)")
            continue
        leaves, receipts = order_check(repo, scan_leaves(repo), {rel: text.replace(old, new)})
        if kind == "leaf":
            site, _, fn = key.partition("@")
            hits = [l for l in leaves if l["file"] == rel and l["site"] == site
                    and (not fn or l.get("function") == fn)]
            got = sorted({l.get("order") for l in hits})
        else:
            got = sorted({r["verdict"] for r in receipts if r["successor"] == key})
        if set(got) & want:
            print(f"  ok  mutant: {name:<48} [{', '.join(got)}]")
        else:
            fails.append(f"mutant '{name}': expected one of {sorted(want)}, got {got} — the tree check did not go red")
    # and the unmutated tree must be clean, or the mutants prove nothing
    leaves, receipts = order_check(repo, scan_leaves(repo))
    dirty = [l for l in leaves if l.get("order") not in CLEAN_VERDICTS] + \
            [r for r in receipts if r["verdict"] != "clean"]
    if dirty:
        fails.append(f"unmutated tree is not clean ({len(dirty)} red) — mutant reds are not attributable")
    else:
        print(f"  ok  unmutated tree: {len(leaves)} leaves clean/returned, {len(receipts)} receipts clean")
    return fails


if __name__ == "__main__":
    sys.exit(main())
