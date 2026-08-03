#!/usr/bin/env python3
"""Derive the classifier-2 set and inventory its call sites (ADR-001 D5, classifier 2).

Classifier 2 answers two questions, and the second is worthless without the first:

  1. WHICH `ExtPorts` fields are members?  D5 states the criterion --
     "a field whose call is the extension-side entry to a core seam that D1
     requires to thread successor state, and which cannot return it" -- and then
     names `ai_step` as the only member with `clock_now`, `proc_exec` and
     `env_get` excluded.  That enumeration was true when written and WI-A12
     falsified it.  This tool DERIVES membership from the criterion every run and
     never consults a list, because a hardcoded list is a fail-open detector: it
     reports a clean routing audit over a cursor the ABI has started dropping.

  2. WHERE are they called?  A typed field-call inventory over `src` + `packages`,
     fail-closed on every alias, wrapper, re-export or computed access it cannot
     resolve to a typed receiver.

Membership is decided per `ExtPorts` field by three source facts, all re-read:

     a. the core seam the field fronts, found by resolving the extension-side
        bridge (`session.ext_ports_of`) through its closures and one level of
        named wrapper;
     b. whether that seam threads successor state -- its declared result type has
        a `next_state` field;
     c. whether the `ExtPorts` field's own result type can carry that successor.

  member       (a) and (b) and not (c)   -- a cursor is dropped at the ABI edge
  non-member   (a) and not (b)           -- the seam threads nothing to lose
  returns-it   (a) and (b) and (c)       -- widened; nothing is dropped
  unrouted     not (a)                   -- the field bypasses the core seam
                                            entirely.  Not a member (there is no
                                            entry to a seam), but reported loudly:
                                            `clock_now` is here by plan rule S2
                                            and the Clock poison probe is what
                                            covers it, not this classifier.
  unresolved   bridge unreadable         -- fail closed, exit 1.

Traps this tool is written against:

  * D5's non-member list is stale.  See above; membership is derived.
  * `env_get` and `clock_now` name BOTH an `ExtPorts` field and a core `Ports`
     field.  A bare `.env_get(` scan reports the core driver's own calls as
     extension seams.  Receivers are typed before they are counted.
  * comments and string literals mention `ExtPorts.ai_step` (dst_fault_catalogue
     has four).  Scanning raw text reports prose as an escaped function value.
     Source is stripped of comments and strings first.
  * `ailang iface` fails MOD010 on this repo's packages when handed an ABSOLUTE
     path and succeeds on a RELATIVE one -- the opposite of classifier 1's std/
     experience, and the error's two suggested fixes (`--relax-modules`,
     `AILANG_RELAX_MODULES=1`) are both rejected by `iface` itself.  Filed under
     ticket fb_d230853828108783.  `iface` is used only to confirm the ABI module
     parses; membership and sites come from source.
  * running from a temporary directory auto-relaxes MOD010 and hides that.
     Inherited refusal from classifier 1.

Exit codes: 0 clean, 1 unresolved membership or unresolved occurrences, 2 harness error.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ABI_TYPES = "packages/motoko-ext-abi/types.ail"
CORE_PORTS = "src/core/ports.ail"
BRIDGE_FILE = "src/core/session.ail"
BRIDGE_FUNC = "ext_ports_of"
SUCCESSOR_FIELD = "next_state"

IDENT = r"[A-Za-z_][A-Za-z0-9_]*"


# --------------------------------------------------------------------------
# source hygiene
# --------------------------------------------------------------------------

def strip_noise(text: str) -> str:
    """Blank out line comments and string literals, preserving offsets.

    Offsets are preserved so line numbers of surviving matches stay true. Without
    this, `delivery_constructor: "ExtPorts.ai_step"` in dst_fault_catalogue.ail
    is reported as an escaped function value, and every prose mention of a field
    name becomes an unresolved occurrence.
    """
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


def ail_files(root: Path) -> list[Path]:
    found: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".ailang", "node_modules", "__pycache__")]
        for fn in sorted(filenames):
            if fn.endswith(".ail"):
                found.append(Path(dirpath) / fn)
    return found


# --------------------------------------------------------------------------
# type declarations
# --------------------------------------------------------------------------

def record_types(text: str) -> dict[str, dict[str, str]]:
    """`export type X = { f: T, ... }` -> {X: {f: T}}. Braces in T are balanced."""
    types: dict[str, dict[str, str]] = {}
    for m in re.finditer(rf"^\s*(?:export\s+)?type\s+({IDENT})\s*=\s*\{{", text, re.M):
        name, start = m.group(1), m.end() - 1
        depth, i = 0, start
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        types[name] = split_fields(text[start + 1:i])
    return types


def split_fields(body: str) -> dict[str, str]:
    """Split a record body on top-level commas; `f: T` per part."""
    parts, depth, cur = [], 0, ""
    for ch in body:
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    fields: dict[str, str] = {}
    for p in parts:
        m = re.match(rf"\s*({IDENT})\s*:\s*(.+)", p, re.S)
        if m:
            fields[m.group(1)] = " ".join(m.group(2).split())
    return fields


def result_type(sig: str) -> str:
    """The result type of a function-typed field, minus its effect row.

    `(WorldState, string, string) -> EnvRead ! {Env}` -> `EnvRead`. The arrow is
    the LAST top-level one so that function-typed parameters do not win.
    """
    depth, arrow = 0, -1
    i = 0
    while i < len(sig):
        ch = sig[i]
        if ch in "{[(":
            depth += 1
        elif ch in "}])":
            depth -= 1
        elif depth == 0 and sig.startswith("->", i):
            arrow = i
        i += 1
    if arrow == -1:
        return ""
    return sig[arrow + 2:].split("!")[0].strip()


def threads_successor(tyname: str, types: dict[str, dict[str, str]]) -> bool:
    base = tyname.split("[")[0].strip()
    return SUCCESSOR_FIELD in types.get(base, {})


# --------------------------------------------------------------------------
# the bridge: which core seam does each ExtPorts field front?
# --------------------------------------------------------------------------

def body_after(text: str, pos: int) -> str | None:
    """The brace-balanced body starting at the first `{` at or after `pos` that
    is NOT an effect row.

    An AILANG signature ends `-> T ! {IO, Clock} {`, so the first `{` after a
    function header is the EFFECT ROW, not the body. Taking it yields `IO, Clock`
    -- a fragment in which no seam is ever found, which silently classifies every
    field as unrouted. That is a fail-open answer produced by a parsing slip, and
    it is the single most expensive bug in this tool's history.
    """
    i = pos
    while i < len(text):
        if text[i] == "{":
            depth, j = 0, i
            while j < len(text):
                if text[j] == "{":
                    depth += 1
                elif text[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            inner = text[i + 1:j]
            # an effect row is a bare comma-separated list of capitalised names
            if re.fullmatch(r"\s*(?:[A-Z][A-Za-z0-9_]*\s*)(?:,\s*[A-Z][A-Za-z0-9_]*\s*)*", inner):
                i = j + 1
                continue
            return inner
        if text[i] == "\n" and text[i - 1:i] == "":
            break
        i += 1
    return None


def func_body(text: str, name: str) -> str | None:
    m = re.search(rf"^\s*(?:export\s+)?(?:pure\s+)?func\s+{re.escape(name)}\b", text, re.M)
    if not m:
        return None
    return body_after(text, m.end())


def bridge_map(text: str, ext_fields: list[str], core_fields: list[str]) -> dict[str, str | None]:
    """ExtPorts field -> the core `Ports` field its bridge closure calls.

    Resolves the returned record literal's `field: expr` bindings through local
    `let`s and one level of named top-level function. `None` means the field
    reaches no core seam -- an unrouted bypass, not a silent pass.
    """
    body = func_body(text, BRIDGE_FUNC)
    if body is None:
        raise SystemExit(f"harness: could not read {BRIDGE_FUNC} in {BRIDGE_FILE}")

    # the port parameter's name, so `p.tool_exec(` is distinguishable from noise
    sig = re.search(rf"func\s+{BRIDGE_FUNC}\s*\(\s*({IDENT})\s*:\s*Ports\b", text)
    if not sig:
        raise SystemExit(f"harness: {BRIDGE_FUNC} has no `Ports`-typed parameter")
    portvar = sig.group(1)

    def seam_in(fragment: str, portname: str, depth: int) -> str | None:
        """Find the core seam `<portname>.<field>(` in `fragment`, following named
        calls that forward the port. Depth-limited; exhaustion is `None`, which is
        reported as `unrouted` rather than swallowed."""
        for cf in core_fields:
            if re.search(rf"\b{re.escape(portname)}\s*\.\s*{cf}\s*\(", fragment):
                return cf
        if depth <= 0:
            return None
        # follow one level of named call that forwards the port as an argument
        for call in re.finditer(rf"\b({IDENT})\s*\(([^()]*)\)", fragment):
            fn, argl = call.group(1), call.group(2)
            if not re.search(rf"\b{re.escape(portname)}\b", argl):
                continue
            inner = func_body(text, fn)
            if inner is None:
                continue
            wsig = re.search(rf"func\s+{re.escape(fn)}\s*\(([^)]*)\)", text)
            names = [portname]
            if wsig:
                names += [m.group(1) for m in
                          re.finditer(rf"({IDENT})\s*:\s*Ports\b", wsig.group(1))]
            for nm in names:
                got = seam_in(inner, nm, depth - 1)
                if got:
                    return got
        return None

    out: dict[str, str | None] = {}
    for ef in ext_fields:
        # the returned record literal binds `<field>: <expr>`; the signature's own
        # `<field>:` annotations live outside `body`, so this cannot confuse them.
        m = re.search(rf"^\s*{ef}\s*:\s*([^,\n}}]+)", body, re.M)
        if not m:
            out[ef] = None
            continue
        rhs = m.group(1).strip()
        # (i) the binding is a local `let <name> = func(...) { ... }`
        inner = let_lambda_body(body, rhs)
        if inner is not None:
            out[ef] = seam_in(inner, portvar, 2)
            continue
        # (ii) the binding names a top-level function; resolve through it
        top = func_body(text, rhs)
        if top is not None:
            wsig = re.search(rf"func\s+{re.escape(rhs)}\s*\(([^)]*)\)", text)
            names = [portvar]
            if wsig:
                names += [x.group(1) for x in
                          re.finditer(rf"({IDENT})\s*:\s*Ports\b", wsig.group(1))]
            seam = None
            for nm in names:
                seam = seam_in(top, nm, 2)
                if seam:
                    break
            out[ef] = seam
            continue
        out[ef] = seam_in(rhs, portvar, 2)
    return out


def let_lambda_body(body: str, name: str) -> str | None:
    m = re.search(rf"let\s+{re.escape(name)}\s*(?::[^=]+)?=\s*func\b", body)
    if not m:
        return None
    # `body_after`, not the next `{`: a lambda's signature carries an effect row
    # too, and taking it is the same fail-open slip documented there.
    return body_after(body, m.end())


# --------------------------------------------------------------------------
# call-site inventory
# --------------------------------------------------------------------------

class Occurrence:
    def __init__(self, path: str, line: int, receiver: str, field: str,
                 kind: str, why: str, text: str):
        self.path, self.line, self.receiver, self.field = path, line, receiver, field
        self.kind, self.why, self.text = kind, why, text

    def as_dict(self) -> dict:
        return {"file": self.path, "line": self.line, "receiver": self.receiver,
                "field": self.field, "kind": self.kind, "why": self.why,
                "source": self.text}


def binder_types(clean: str) -> dict[str, str]:
    """Identifier -> declared type, from DECLARATION contexts only.

    Two contexts count: a function signature's parameter list, and an annotated
    `let x: T`. Record LITERALS must not count -- `PortedProvider`'s construction
    binds `ports: p`, and a scan that treats `name: value` as an annotation
    concludes that `ports` has type `p` and then reports every core driver call
    as an unresolved extension seam. Requiring a capitalised type name is not
    enough on its own; the context restriction is what makes it right.
    """
    out: dict[str, str] = {}
    for sig in re.finditer(rf"func\s+(?:{IDENT}\s*)?\(", clean):
        # balanced, not `[^)]*`: a function-typed parameter such as
        # `(StreamChunk) -> ()` closes the list early and drops every binder
        # after it, which turns resolvable receivers into triage noise.
        depth, i = 0, sig.end() - 1
        while i < len(clean):
            if clean[i] == "(":
                depth += 1
            elif clean[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        for m in re.finditer(rf"({IDENT})\s*:\s*\[?([A-Z][A-Za-z0-9_]*)", clean[sig.end():i]):
            out.setdefault(m.group(1), m.group(2))
    for m in re.finditer(rf"let\s+({IDENT})\s*:\s*\[?([A-Z][A-Za-z0-9_]*)", clean):
        out[m.group(1)] = m.group(2)
    return out


def local_return_types(clean: str) -> dict[str, str]:
    """Local `func name(...) -> T` result types, for `let x = name(...)` receivers."""
    out: dict[str, str] = {}
    for m in re.finditer(rf"func\s+({IDENT})\s*\(", clean):
        tail = clean[m.end():m.end() + 600]
        rt = result_type("(" + tail)
        if rt and re.fullmatch(IDENT, rt):
            out[m.group(1)] = rt
    return out


def scan_file(path: Path, repo: Path, ext_fields: list[str], carriers: dict[str, str],
              other_owners: set[str]) -> list[Occurrence]:
    raw = path.read_text(errors="replace")
    clean = strip_noise(raw)
    rel = str(path.relative_to(repo))
    binders = binder_types(clean)
    returns = local_return_types(clean)
    # the file's own record types matter: `C2LoopState.provider: Ports` is declared
    # in session.ail, and without it `st.provider.env_get` resolves to nothing and
    # is triaged as an unresolved extension seam when it is a core driver call.
    types = {**ALL_TYPES, **record_types(clean)}

    # `let x = f(...)` where f is a local function with a declared result type
    for m in re.finditer(rf"let\s+({IDENT})\s*=\s*({IDENT})\s*\(", clean):
        if m.group(1) not in binders and m.group(2) in returns:
            binders[m.group(1)] = returns[m.group(2)]

    def type_of_path(recv: str) -> str | None:
        """Resolve a dotted identifier path to a declared type name, or None."""
        parts = recv.split(".")
        if not all(re.fullmatch(IDENT, p) for p in parts):
            return None
        ty = binders.get(parts[0])
        if ty is None:
            return None
        for p in parts[1:]:
            fields = types.get(ty)
            if not fields or p not in fields:
                return None
            ty = fields[p].split("[")[0].strip()
            if not re.fullmatch(IDENT, ty):
                return None
        return ty

    occurrences: list[Occurrence] = []
    lines = clean.splitlines()

    for i, line in enumerate(lines, 1):
        for field in ext_fields:
            # Either a dotted identifier path, or a `)`/`]` -- a receiver produced
            # by a call or an index, which is exactly the re-export and computed
            # forms and can never be resolved to a declared type.
            pat = (rf"(?:(?P<recv>{IDENT}(?:\s*\.\s*{IDENT})*)|(?P<opaque>[)\]]))"
                   rf"\s*\.\s*{field}\b\s*(?P<call>\(?)")
            for m in re.finditer(pat, line):
                recv = (m.group("recv") or "").replace(" ", "")
                opaque = m.group("opaque") is not None
                called = m.group("call") == "("
                src = raw.splitlines()[i - 1].strip()
                ty = None if opaque else (type_of_path(recv) if recv else None)

                if ty == "ExtPorts":
                    kind, why = ("call", "receiver is ExtPorts-typed") if called else (
                        "unresolved", "ExtPorts field taken as a VALUE, not called: "
                                      "the function escapes and its later call site is invisible")
                elif ty is not None and ty in other_owners:
                    # a different declared type owns this field name. `env_get` and
                    # `clock_now` name both an ExtPorts field and a core Ports field;
                    # these are the driver's own calls, not extension-side entries.
                    continue
                else:
                    kind = "unresolved"
                    if opaque:
                        why = ("receiver is a call or index result, not a typed identifier "
                               "path (re-export or computed access) -- cannot be resolved "
                               "to ExtPorts")
                    elif recv.split(".")[0] not in binders:
                        why = (f"receiver `{recv}` has no declared type in this file "
                               f"(local alias or wrapper) -- cannot be resolved to ExtPorts")
                    else:
                        why = f"receiver `{recv}` resolves to `{ty}`, not an ABI port type"
                occurrences.append(Occurrence(rel, i, recv or "<opaque>", field, kind, why, src))
    return occurrences


ALL_TYPES: dict[str, dict[str, str]] = {}


# --------------------------------------------------------------------------

def run(cmd: list[str], cwd: Path | None = None) -> tuple[int, str, str]:
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    return p.returncode, p.stdout, p.stderr


def source_revision(repo: Path) -> str | None:
    rc, out, _ = run(["git", "-C", str(repo), "rev-parse", "HEAD"])
    return out.strip() if rc == 0 else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=".", help="repository root")
    ap.add_argument("--roots", default="src,packages", help="comma-separated in-profile source roots")
    ap.add_argument("--json", action="store_true", help="emit the inventory as JSON")
    ap.add_argument("--self-test", action="store_true",
                    help="run the fixture suite: every unresolvable form must be reported "
                         "unresolved, and the derived membership must match the criterion "
                         "re-derived by hand in the fixture expectations")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()

    if str(repo).startswith("/tmp"):
        print("harness: repo is under /tmp; AILANG auto-relaxes MOD010 there and interface "
              "failures are hidden. Run from the checkout.", file=sys.stderr)
        return 2

    abi = (repo / ABI_TYPES).read_text()
    core = (repo / CORE_PORTS).read_text()
    bridge = (repo / BRIDGE_FILE).read_text()

    abi_types = record_types(strip_noise(abi))
    core_types = record_types(strip_noise(core))
    ALL_TYPES.clear()
    ALL_TYPES.update(core_types)
    ALL_TYPES.update(abi_types)

    if "ExtPorts" not in abi_types:
        print(f"harness: no ExtPorts record in {ABI_TYPES}", file=sys.stderr)
        return 2
    if "Ports" not in core_types:
        print(f"harness: no Ports record in {CORE_PORTS}", file=sys.stderr)
        return 2

    ext = abi_types["ExtPorts"]
    ports = core_types["Ports"]
    ext_fields = list(ext)
    seams = bridge_map(strip_noise(bridge), ext_fields, list(ports))

    # ---- membership, derived from D5's criterion every run ----
    membership: dict[str, dict] = {}
    for f in ext_fields:
        seam = seams[f]
        ext_result = result_type(ext[f])
        if seam is None:
            membership[f] = {"state": "unrouted", "seam": None,
                             "seam_threads": None, "ext_can_return": None,
                             "why": "the bridge reaches no core Ports seam -- this field "
                                    "bypasses the world protocol entirely (plan S2); the "
                                    "Clock poison probe covers it, not this classifier"}
            continue
        seam_result = result_type(ports[seam])
        threads = threads_successor(seam_result, core_types)
        can_return = threads_successor(ext_result, {**core_types, **abi_types})
        if threads and not can_return:
            state, why = "member", (f"fronts Ports.{seam}, whose {seam_result} threads "
                                    f"{SUCCESSOR_FIELD}; ExtPorts.{f} returns {ext_result} "
                                    f"and cannot carry it")
        elif not threads:
            state, why = "non-member", (f"fronts Ports.{seam}, whose {seam_result} threads no "
                                        f"successor -- no cursor to lose")
        else:
            state, why = "returns-it", (f"fronts Ports.{seam} and ExtPorts.{f}'s {ext_result} "
                                        f"carries {SUCCESSOR_FIELD} -- nothing dropped")
        membership[f] = {"state": state, "seam": seam, "seam_threads": threads,
                         "ext_can_return": can_return, "why": why}

    members = [f for f, m in membership.items() if m["state"] == "member"]
    unrouted = [f for f, m in membership.items() if m["state"] == "unrouted"]

    # ---- call-site inventory ----
    carriers = {ty: fld for ty, fields in {**abi_types, **core_types}.items()
                for fld, t in fields.items() if t.strip() == "ExtPorts"}
    carrier_fields = {fld for fld in carriers.values()}
    other_owners = {ty for ty, fields in {**abi_types, **core_types}.items()
                    if ty != "ExtPorts" and any(f in fields for f in ext_fields)}

    occurrences: list[Occurrence] = []
    for r in [x.strip() for x in args.roots.split(",") if x.strip()]:
        base = repo / r
        if not base.is_dir():
            print(f"harness: scan root {r} does not exist", file=sys.stderr)
            return 2
        for path in ail_files(base):
            occurrences.extend(scan_file(path, repo, ext_fields,
                                         {c: True for c in carrier_fields}, other_owners))

    member_calls = [o for o in occurrences if o.kind == "call" and o.field in members]
    other_calls = [o for o in occurrences if o.kind == "call" and o.field not in members]
    unresolved = [o for o in occurrences if o.kind == "unresolved"]

    rev = source_revision(repo)

    if args.self_test:
        return self_test(repo, membership, ext_fields)

    if args.json:
        print(json.dumps({
            "source_revision": rev,
            "scan_roots": args.roots.split(","),
            "ext_ports_fields": ext_fields,
            "membership": membership,
            "classifier_2_set": sorted(members),
            "unrouted_fields": sorted(unrouted),
            "member_call_sites": [o.as_dict() for o in member_calls],
            "non_member_call_sites": [o.as_dict() for o in other_calls],
            "unresolved": [o.as_dict() for o in unresolved],
        }, indent=2))
    else:
        print(f"source revision    {rev}")
        print(f"scan roots         {args.roots}")
        print(f"ExtPorts fields    {len(ext_fields)}: {', '.join(ext_fields)}")
        print()
        print("membership (derived from D5's criterion, not from its enumeration):")
        for f in ext_fields:
            m = membership[f]
            print(f"  {f:<12} {m['state']:<11} {m['why']}")
        print()
        print(f"CLASSIFIER-2 SET ({len(members)}): {', '.join(sorted(members)) or '-'}")
        if unrouted:
            print(f"UNROUTED ({len(unrouted)}): {', '.join(sorted(unrouted))} "
                  f"-- covered by the poison probe, not by this classifier")
        print()
        print(f"member call sites ({len(member_calls)}):")
        for o in member_calls:
            print(f"  {o.file_line()}  {o.receiver}.{o.field}")
        if other_calls:
            print(f"\nnon-member port calls ({len(other_calls)}), recorded not gated:")
            for o in other_calls:
                print(f"  {o.file_line()}  {o.receiver}.{o.field}")
        if unresolved:
            print(f"\nUNRESOLVED ({len(unresolved)}) -- fail closed, triage required:")
            for o in unresolved:
                print(f"  {o.file_line()}  .{o.field}")
                print(f"      {o.why}")
                print(f"      | {o.text}")

    return 1 if unresolved else 0


def self_test(repo: Path, membership: dict, ext_fields: list[str]) -> int:
    """The fixture suite. Each fixture uses one unresolvable form; each must be
    reported unresolved. A fixture that comes back clean is the fail-open defect
    this classifier exists to prevent, so silence is a failure, not a pass."""
    fixtures = repo / "tools/ext_call_inventory/fixtures"
    if not fixtures.is_dir():
        print(f"self-test: no fixture directory at {fixtures}", file=sys.stderr)
        return 2

    expected = json.loads((fixtures / "expected.json").read_text())
    fails: list[str] = []

    for path in ail_files(fixtures):
        rel = str(path.relative_to(fixtures))
        want = expected["fixtures"].get(rel)
        if want is None:
            fails.append(f"{rel}: fixture present but not declared in expected.json")
            continue
        got = scan_file(path, fixtures, ext_fields, {"ports": True}, set())
        n_unres = len([o for o in got if o.kind == "unresolved"])
        n_call = len([o for o in got if o.kind == "call"])
        if n_unres != want["unresolved"] or n_call != want["resolved"]:
            fails.append(f"{rel}: expected {want['unresolved']} unresolved / "
                         f"{want['resolved']} resolved, got {n_unres} / {n_call}"
                         f"  [{want['form']}]")
        else:
            print(f"  ok  {rel:<28} {want['form']}  "
                  f"({n_unres} unresolved, {n_call} resolved)")

    missing = set(expected["fixtures"]) - {str(p.relative_to(fixtures)) for p in ail_files(fixtures)}
    for m in sorted(missing):
        fails.append(f"{m}: declared in expected.json but the fixture file is gone")

    for f, want in expected["membership"].items():
        got = membership.get(f, {}).get("state")
        if got != want:
            fails.append(f"membership {f}: expected {want}, derived {got}")
        else:
            print(f"  ok  membership {f:<12} {want}")

    print(f"\nself-test: {len(fails)} failure(s)")
    for f in fails:
        print(f"  FAIL {f}")
    return 1 if fails else 0


def _file_line(self: Occurrence) -> str:
    return f"{self.path}:{self.line}"


Occurrence.file_line = _file_line  # type: ignore[attr-defined]


if __name__ == "__main__":
    sys.exit(main())
