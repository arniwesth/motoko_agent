#!/usr/bin/env python3
"""Derive the classifier-2 set and inventory its call sites (ADR-001 D5, classifier 2).

Classifier 2 answers two questions, and the second is worthless without the first:

  1. WHICH `ExtPorts` fields are members?  D5 states the criterion --
     "a field whose call is the extension-side entry to a core seam that D1
     requires to thread successor state, and which cannot return it" -- and then
     names `ai_step` as the only member with `clock_now`, `tool_handle` and
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
  * 8.0 (ADR-001 (031) D2/D7) projects `ExtPorts` into per-row VIEWS -- `FsPorts`,
     `AiPorts`, `InterceptPorts`, built by taking each field as a value into a
     record literal -- and every callback calls its port through its view.
     Matching `ExtPorts` by name reported the ABI's own projections as form 3
     (15 sites), skipped every call through a view silently, and left every
     extension closure UNRESOLVED. Views are derived by STRUCTURE (identical
     field signatures), projections into a view resolve, binders are read from
     their own function -- see "8.0: the views" at the call-site inventory.

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
                 kind: str, why: str, text: str, via: str = ""):
        self.path, self.line, self.receiver, self.field = path, line, receiver, field
        self.kind, self.why, self.text, self.via = kind, why, text, via

    def as_dict(self) -> dict:
        d = {"file": self.path, "line": self.line, "receiver": self.receiver,
             "field": self.field, "kind": self.kind, "why": self.why,
             "source": self.text}
        if self.via:
            d["via"] = self.via
        return d


# --------------------------------------------------------------------------
# 8.0 (ADR-001 (031) D2, D7): the views.  `ExtCtx` is projected into six
# per-row context views, and the port record with it: `FsCtx.ports: FsPorts`,
# `AiCtx.ports: AiPorts`, `InterceptCtx.ports: InterceptPorts`, each a record
# of `ExtPorts` fields under the same names with the IDENTICAL signatures,
# built by the ABI's `fs_ports` / `ai_ports` / `intercept_ports`, which take
# each `ExtPorts` field as a VALUE into a record literal.  Before 8.0 this
# tool matched `ExtPorts` by name (D7's row said so) and resolved nothing
# else; at 8.0 every callback on a view calls its port through the view, and
# the projections read as form 3 -- 15 unresolved sites in the ABI alone,
# every closure UNRESOLVED, and the closure yield 0 of 18 (P1.7r).
#
# Three things are taught, each in one place and each derived, not listed:
#
#   * A VIEW is any record type -- ABI or extension-local -- other than
#     `ExtPorts` every one of whose fields is an `ExtPorts` field under the
#     same name with the identical signature, effect row included.  Derived by
#     STRUCTURE (`port_views`): a name list is the fail-open detector this
#     tool's docstring warns about, silent the day the ABI adds a view; the
#     structure also excludes core `Ports` and `ContextReader`, which share
#     field names with `ExtPorts` and no signature (they take `WorldState`).
#     A call whose receiver resolves to a view is a mediated call.
#   * A PROJECTION -- an `ExtPorts` (or view) field taken as a value -- is
#     resolved when, and only when, it is the same-named field of a record
#     literal inside a function whose declared result type is a view that
#     declares that field: the value does not escape, it is forwarded under
#     its own name into a record this tool reads as a receiver, so the later
#     call site is visible after all.  Any other value-escape stays form 3.
#   * Binders are SCOPED to the function that declares them.  Before, an
#     identifier's type was the first declaration anywhere in the file, so
#     compose's `ctx: ProviderCtx` read as its first `ctx: PureCtx` (no
#     `ports`) and agentcli's `p: ExtPorts` as its first `p: Provider` --
#     two unresolved sites that were never unresolvable, and, the other way,
#     an unannotated `let p = ctx.ports` counted as resolved because some
#     other function declared a `p: ExtPorts` (form 1, hidden).
# --------------------------------------------------------------------------

def port_views(types: dict[str, dict[str, str]], ext: dict[str, str]) -> dict[str, list[str]]:
    """Record type -> its fields, for every VIEW of `ExtPorts` in `types`."""
    views: dict[str, list[str]] = {}
    for name, fields in types.items():
        if name == "ExtPorts" or not fields:
            continue
        # THE VIEW RULE: every field an ExtPorts field, same name, identical signature.
        if all(f in ext and ext[f] == sig for f, sig in fields.items()):
            views[name] = sorted(fields)
    return views


#: views found in scanned files but declared outside the ABI (an extension's own
#: narrower port record), `name -> file`, for the report; cleared per run
LOCAL_VIEWS: dict[str, str] = {}


class Scope:
    """One `func` -- named or anonymous, nested included -- with the span of its
    body in the cleaned text, its parameters' declared types and its declared
    result type (an identifier, or "" for a record literal or none)."""

    def __init__(self, name: str | None, start: int, end: int,
                 params: dict[str, str], result: str):
        self.name, self.start, self.end, self.params, self.result = name, start, end, params, result


def _balanced_end(text: str, i: int, open_ch: str, close_ch: str) -> int:
    """Index of the bracket closing the one at `text[i]`, or -1."""
    depth = 0
    while i < len(text):
        if text[i] == open_ch:
            depth += 1
        elif text[i] == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def header_and_body(clean: str, pos: int) -> tuple[str, int, int] | None:
    """From just after a parameter list's `)`: `(result type text, body start,
    body end)`.

    Reads the signature the way the grammar does -- `-> T`, then an optional
    effect row `! {…}`, then the body `{` -- instead of taking "the first `{`
    that is not an effect row", which mistakes a RECORD-LITERAL result type
    (`-> { ok: bool, next_state: ExtWorld } ! {IO} {`, compose has several)
    for the body and leaves the real body outside every scope.
    """
    n, i = len(clean), pos
    result = ""
    while i < n and clean[i] in " \t\r\n":
        i += 1
    if clean.startswith("->", i):
        i += 2
        j = i
        while j < n:
            c = clean[j]
            if c in "{[(":
                if c == "{" and clean[i:j].strip() != "" and clean[i:j].strip()[-1:] not in "-,>":
                    break                     # a `{` after a complete type is the body
                k = _balanced_end(clean, j, c, {"{": "}", "[": "]", "(": ")"}[c])
                if k == -1:
                    return None
                j = k + 1
                continue
            if c == "!":
                break
            j += 1
        result = " ".join(clean[i:j].split())
        i = j
    while i < n and clean[i] in " \t\r\n":
        i += 1
    if clean.startswith("!", i):              # the effect row
        b = clean.find("{", i)
        if b == -1:
            return None
        e = _balanced_end(clean, b, "{", "}")
        if e == -1:
            return None
        i = e + 1
        while i < n and clean[i] in " \t\r\n":
            i += 1
    if i >= n or clean[i] != "{":
        return None
    e = _balanced_end(clean, i, "{", "}")
    if e == -1:
        return None
    return result, i + 1, e


def func_scopes(clean: str) -> list[Scope]:
    """Every `func` in the file as a `Scope`, in source order."""
    scopes: list[Scope] = []
    for m in re.finditer(rf"\bfunc\b\s*({IDENT})?\s*\(", clean):
        close = _balanced_end(clean, m.end() - 1, "(", ")")
        if close == -1:
            continue
        params: dict[str, str] = {}
        for pm in re.finditer(rf"({IDENT})\s*:\s*\[?([A-Z][A-Za-z0-9_]*)", clean[m.end():close]):
            params.setdefault(pm.group(1), pm.group(2))
        hb = header_and_body(clean, close + 1)
        if hb is None:
            continue
        result, bstart, bend = hb
        scopes.append(Scope(m.group(1), bstart, bend, params,
                            result if re.fullmatch(IDENT, result or "") else ""))
    return scopes


def scan_file(path: Path, repo: Path, ext_fields: list[str], carriers: dict[str, str],
              other_owners: set[str], projections: list[Occurrence] | None = None
              ) -> list[Occurrence]:
    """Every `<receiver>.<ExtPorts field>` in `path`, resolved or fail-closed.

    Resolved PROJECTIONS (see above) are neither calls nor unresolved: they are
    appended to `projections` when the caller passes a list (the inventory's
    own report) and otherwise not reported -- the same treatment a core-owned
    receiver gets, so classifier 3's mediated-call count stays a count of
    CALLS."""
    raw = path.read_text(errors="replace")
    clean = strip_noise(raw)
    rel = str(path.relative_to(repo))
    ext = ALL_TYPES.get("ExtPorts", {})
    # the file's own record types matter: `C2LoopState.provider: Ports` is declared
    # in session.ail, and without it `st.provider.env_get` resolves to nothing and
    # is triaged as an unresolved extension seam when it is a core driver call.
    local_types = record_types(clean)
    types = {**ALL_TYPES, **local_types}
    views = port_views(types, ext)
    for v in views:
        if v in local_types and v not in ALL_TYPES:
            LOCAL_VIEWS.setdefault(v, rel)
    receivers = {"ExtPorts", *views}

    scopes = func_scopes(clean)
    returns = {s.name: s.result for s in scopes if s.name and s.result}
    # `let x: T`; `let x = f(...)` where f is a local function with a declared
    # result type; and -- 8.0, P1.7r -- `let x = a.b.c;`, an ALIAS OF A
    # DECLARED-TYPED PATH, which binds `x` to the type that path resolves to in
    # scope by the same declaration-only lookup a direct `a.b.c.field(` call
    # gets (no inference: if the path does not resolve, `x` stays unbound and
    # its calls are form 1).  Each is scoped to the innermost function holding
    # it, and a later `let` of the same name wins.  ("alias", offset, name,
    # path) entries are resolved lazily, against the binders in force there.
    lets: list[tuple[int, str, str, str]] = []
    for m in re.finditer(rf"let\s+({IDENT})\s*:\s*\[?([A-Z][A-Za-z0-9_]*)", clean):
        lets.append((m.start(), m.group(1), "type", m.group(2)))
    for m in re.finditer(rf"let\s+({IDENT})\s*=\s*({IDENT})\s*\(", clean):
        if m.group(2) in returns:
            lets.append((m.start(), m.group(1), "type", returns[m.group(2)]))
    for m in re.finditer(rf"let\s+({IDENT})\s*=\s*({IDENT}(?:[ \t]*\.[ \t]*{IDENT})*)[ \t]*(?:;|\n)", clean):
        # THE ALIAS RULE: a declared-typed path, resolved in scope, binds the alias.
        lets.append((m.start(), m.group(1), "alias", m.group(2).replace(" ", "").replace("\t", "")))
    lets.sort()

    def type_of_path(recv: str, binders: dict[str, str]) -> str | None:
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

    def containing(o: int) -> list[Scope]:
        # THE SCOPE RULE: the functions whose bodies hold `o`, outermost first.
        return [s for s in scopes if s.start <= o < s.end]

    def bind_let(b: dict[str, str], name: str, how: str, what: str) -> None:
        if how == "type":
            b[name] = what
        else:
            ty = type_of_path(what, b)
            if ty is not None:
                b[name] = ty
            else:
                b.pop(name, None)                       # re-bound to something unreadable

    def binders_at(o: int) -> dict[str, str]:
        chain = containing(o)
        b: dict[str, str] = {}
        for off, name, how, what in lets:               # file-scope lets
            if off < o and not containing(off):
                bind_let(b, name, how, what)
        for sc in chain:
            b.update(sc.params)
            for off, name, how, what in lets:           # lets declared in this body
                if off < o and sc.start <= off < sc.end and (containing(off)[-1] is sc):
                    bind_let(b, name, how, what)
        return b

    occurrences: list[Occurrence] = []
    raw_lines = raw.splitlines()

    for field in ext_fields:
        # Either a dotted identifier path, or a `)`/`]` -- a receiver produced
        # by a call or an index, which is exactly the re-export and computed
        # forms and can never be resolved to a declared type.  Line-local, as
        # the per-line scan this replaces was.
        pat = (rf"(?:(?P<recv>{IDENT}(?:[ \t]*\.[ \t]*{IDENT})*)|(?P<opaque>[)\]]))"
               rf"[ \t]*\.[ \t]*{field}\b[ \t]*(?P<call>\(?)")
        for m in re.finditer(pat, clean):
            o = m.start()
            i = clean.count("\n", 0, o) + 1
            recv = (m.group("recv") or "").replace(" ", "").replace("\t", "")
            opaque = m.group("opaque") is not None
            called = m.group("call") == "("
            src = raw_lines[i - 1].strip() if i - 1 < len(raw_lines) else ""
            binders = binders_at(o)
            ty = None if opaque else (type_of_path(recv, binders) if recv else None)

            if ty in receivers:
                if called:
                    why = ("receiver is ExtPorts-typed" if ty == "ExtPorts" else
                           f"receiver is `{ty}`, a view of ExtPorts ({len(views[ty])} field(s), "
                           f"identical signatures) -- a mediated call through the view")
                    occurrences.append(Occurrence(rel, i, recv, field, "call", why, src,
                                                  via="" if ty == "ExtPorts" else f"view:{ty}"))
                    continue
                # THE PROJECTION RULE: the same-named field of a record literal, in a
                # function whose declared result type is a view declaring that field.
                inner = containing(o)
                target = inner[-1].result if inner else ""
                named_field = re.search(rf"[{{,]\s*{field}\s*:\s*$", clean[:o]) is not None
                if named_field and target in views and field in types[target]:
                    occ = Occurrence(rel, i, recv, field, "projection",
                                     f"`{ty}.{field}` forwarded under its own name into a "
                                     f"`{target}` record -- a view this tool reads as a receiver, "
                                     f"so the call site is the view's", src, via=f"view:{target}")
                    if projections is not None:
                        projections.append(occ)
                    continue
                kind, why = ("unresolved",
                             "ExtPorts field taken as a VALUE, not called: the function escapes "
                             "and its later call site is invisible")
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
                    why = (f"receiver `{recv}` has no declared type in scope "
                           f"(local alias or wrapper) -- cannot be resolved to ExtPorts")
                else:
                    why = f"receiver `{recv}` resolves to `{ty}`, not an ABI port type"
            occurrences.append(Occurrence(rel, i, recv or "<opaque>", field, kind, why, src))
    occurrences.sort(key=lambda x: (x.line, x.field))
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
    # 8.0: an ABI record that shares field NAMES with `ExtPorts` is either a VIEW
    # (structurally, above) or nothing this tool may skip; only the CORE's own
    # owners of those names (`Ports`, `ContextReader`, the driver's calls) are
    # skipped as another type's field.  Before, the ABI's views were skipped
    # here silently -- a call through a view was neither counted nor flagged.
    other_owners = {ty for ty, fields in core_types.items()
                    if ty != "ExtPorts" and any(f in fields for f in ext_fields)}
    abi_views = port_views(abi_types, ext)
    LOCAL_VIEWS.clear()
    projections: list[Occurrence] = []

    occurrences: list[Occurrence] = []
    for r in [x.strip() for x in args.roots.split(",") if x.strip()]:
        base = repo / r
        if not base.is_dir():
            print(f"harness: scan root {r} does not exist", file=sys.stderr)
            return 2
        for path in ail_files(base):
            occurrences.extend(scan_file(path, repo, ext_fields,
                                         {c: True for c in carrier_fields}, other_owners,
                                         projections=projections))

    member_calls = [o for o in occurrences if o.kind == "call" and o.field in members]
    other_calls = [o for o in occurrences if o.kind == "call" and o.field not in members]
    unresolved = [o for o in occurrences if o.kind == "unresolved"]

    rev = source_revision(repo)

    if args.self_test:
        return self_test(repo, membership, ext_fields, abi_views)

    views_report = {v: {"fields": fs, "declared_in": ABI_TYPES} for v, fs in sorted(abi_views.items())}
    views_report.update({v: {"fields": port_views(record_types(strip_noise((repo / f).read_text(errors="replace"))), ext)[v],
                             "declared_in": f} for v, f in sorted(LOCAL_VIEWS.items())})

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
            "port_views": views_report,
            "port_view_projections": [o.as_dict() for o in projections],
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
        print(f"ExtPorts VIEWS ({len(views_report)}, derived by structure -- 8.0): "
              + ", ".join(f"{v} ({len(d['fields'])} field(s){'' if d['declared_in'] == ABI_TYPES else ', ' + d['declared_in']})"
                          for v, d in views_report.items()))
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
        if projections:
            print(f"\nport-view projections ({len(projections)}), resolved -- a port forwarded "
                  f"under its own name into a view record:")
            for o in projections:
                print(f"  {o.file_line()}  {o.receiver}.{o.field} -> {o.via.split(':', 1)[1]}")
        if unresolved:
            print(f"\nUNRESOLVED ({len(unresolved)}) -- fail closed, triage required:")
            for o in unresolved:
                print(f"  {o.file_line()}  .{o.field}")
                print(f"      {o.why}")
                print(f"      | {o.text}")

    return 1 if unresolved else 0


def self_test(repo: Path, membership: dict, ext_fields: list[str],
              abi_views: dict[str, list[str]] | None = None) -> int:
    """The fixture suite. Each fixture uses one unresolvable form; each must be
    reported unresolved. A fixture that comes back clean is the fail-open defect
    this classifier exists to prevent, so silence is a failure, not a pass.

    8.0 (P1.7r) adds the CONTROLS for what the views taught: a call through a
    view resolves, a same-named projection into a view resolves (and is counted
    as a projection, not a call), a binder is read from ITS function; and their
    negatives: a value forwarded under another name or into a record that is
    not a view is still form 3.  The ABI's views are pinned by name and field
    set in both directions, like the membership rows."""
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
        projs: list[Occurrence] = []
        got = scan_file(path, fixtures, ext_fields, {"ports": True}, set(), projections=projs)
        n_unres = len([o for o in got if o.kind == "unresolved"])
        n_call = len([o for o in got if o.kind == "call"])
        n_proj = len(projs)
        want_proj = want.get("projections", 0)
        if n_unres != want["unresolved"] or n_call != want["resolved"] or n_proj != want_proj:
            fails.append(f"{rel}: expected {want['unresolved']} unresolved / "
                         f"{want['resolved']} resolved / {want_proj} projection(s), got "
                         f"{n_unres} / {n_call} / {n_proj}  [{want['form']}]")
        else:
            print(f"  ok  {rel:<32} {want['form']}  "
                  f"({n_unres} unresolved, {n_call} resolved"
                  + (f", {n_proj} projection(s))" if n_proj else ")"))

    missing = set(expected["fixtures"]) - {str(p.relative_to(fixtures)) for p in ail_files(fixtures)}
    for m in sorted(missing):
        fails.append(f"{m}: declared in expected.json but the fixture file is gone")

    # WI-B4's POSITIVE CONTROL for the BRIDGE, which is a different thing from
    # `control_resolved.ail`. That fixture proves the CALL-SITE matcher still
    # resolves a typed path; it says nothing about whether `bridge_map` still
    # follows `ext_ports_of`'s closures down to a core `Ports` seam. That is the
    # half that fails OPEN: a parsing slip in `body_after` or in the one-level
    # call-forwarding regex returns `None`, every field becomes `unrouted`, and
    # `unrouted` is not a milder `member` -- it means the field bypasses the
    # world protocol entirely and leaves the gated set. WI-B2b hit exactly this
    # twice in one item, from a nested paren in an argument list and from an
    # anonymous record return type, and each time it read like a clean pass.
    #
    # Pinning `state` alone is not enough, because a slip that resolved a field
    # to the WRONG core seam keeps its state and moves nothing. The pin
    # therefore carries `seam` as well, and `seam: null` is a legitimate pinned
    # value only for a field that is genuinely unrouted (`clock_now`, per S2).
    for f, want in expected["membership"].items():
        if isinstance(want, str):          # pre-B4 shape: state only
            want = {"state": want, "seam": "<unpinned>"}
        got_state = membership.get(f, {}).get("state")
        got_seam = membership.get(f, {}).get("seam")
        if got_state != want["state"]:
            fails.append(f"membership {f}: expected {want['state']}, derived {got_state}")
        elif want["seam"] != "<unpinned>" and got_seam != want["seam"]:
            fails.append(f"membership {f}: state {got_state} agrees but the BRIDGE SEAM moved -- "
                         f"expected Ports.{want['seam']}, derived "
                         f"{('Ports.' + got_seam) if got_seam else 'none (unrouted)'}")
        else:
            print(f"  ok  membership {f:<12} {want['state']:<11} "
                  f"seam={('Ports.' + got_seam) if got_seam else 'none'}")

    # WI-D16's REACHABILITY assertion, which is a different question from every
    # verdict above and is asserted separately per plan rule S24.
    #
    # The loop above iterates `expected["membership"]`, so it can only ever
    # check fields the PIN already names. A field ADDED to `ExtPorts` is
    # therefore invisible to it: WI-D16 added `file_read` and the suite stayed
    # green on four pinned fields while saying nothing at all about the fifth.
    # That is the fail-open shape this file's own docstring is written against,
    # reappearing one level up in the harness rather than in the classifier —
    # and it is the same asymmetry the `fixtures` block already closes with its
    # `missing` check, which had no membership counterpart.
    #
    # Both directions are asserted because they fail differently: an UNPINNED
    # derived field is a new seam nobody reviewed, and a PINNED field that no
    # longer derives is a row deleted from the ABI without the pin noticing.
    pinned = set(expected["membership"])
    derived = set(membership)
    reach_fails = [
        f"REACHABILITY: ExtPorts.{f} derives '{membership[f]['state']}' but is not "
        "pinned in expected.json. A new ABI row is not covered by a pin that does "
        "not name it."
        for f in sorted(derived - pinned)
    ] + [
        f"REACHABILITY: expected.json pins ExtPorts.{f} but no such field derives. "
        "The row was removed or renamed and the pin did not notice."
        for f in sorted(pinned - derived)
    ]
    fails.extend(reach_fails)
    if not reach_fails:
        print(f"  ok  reachability      {len(derived)} ExtPorts field(s) derived, "
              f"{len(pinned)} pinned, sets identical")

    # THE VIEWS PIN (8.0, P1.7r): the ABI's views of `ExtPorts`, derived by
    # structure every run, pinned by name AND field set in both directions --
    # the same shape as the membership reachability check, for the same reason:
    # a view added to the ABI without a pin is a receiver nobody reviewed, and
    # a pinned view that no longer derives is a projection the ABI dropped (or
    # a signature that drifted from `ExtPorts`, which silently turns every call
    # through it into form 3).
    want_views = expected.get("port_views")
    if want_views is not None:
        want_views = {k: v for k, v in want_views.items() if not k.startswith("_")}
    got_views = abi_views or {}
    if want_views is None:
        fails.append("VIEWS: expected.json has no `port_views` block; the ABI's views are "
                     "receivers and must be pinned")
    else:
        for v in sorted(set(want_views) | set(got_views)):
            if v not in got_views:
                fails.append(f"VIEWS: expected.json pins the view `{v}` but no such view derives "
                             f"from the ABI (removed, or a field's signature drifted from ExtPorts)")
            elif v not in want_views:
                fails.append(f"VIEWS: the ABI declares the view `{v}` {got_views[v]} and expected.json "
                             f"does not pin it -- a new receiver nobody reviewed")
            elif sorted(want_views[v]) != sorted(got_views[v]):
                fails.append(f"VIEWS: `{v}` pinned as {sorted(want_views[v])}, derived {got_views[v]}")
            else:
                print(f"  ok  view {v:<16} {len(got_views[v])} field(s): {', '.join(got_views[v])}")

    # And the control that makes the pinned seams falsifiable: if the
    # bridge resolves NOTHING, every membership line above would still have to
    # be individually wrong to notice. One assertion catches the whole class.
    resolved_seams = [f for f, m in membership.items() if m.get("seam")]
    if not resolved_seams:
        fails.append("BRIDGE POSITIVE CONTROL: not one ExtPorts field resolved to a core "
                     f"Ports seam through {BRIDGE_FUNC}. That is the fail-open answer -- a "
                     "parsing slip, not an empty bridge.")

    print(f"\nself-test: {len(fails)} failure(s)")
    for f in fails:
        print(f"  FAIL {f}")
    return 1 if fails else 0


def _file_line(self: Occurrence) -> str:
    return f"{self.path}:{self.line}"


Occurrence.file_line = _file_line  # type: ignore[attr-defined]


if __name__ == "__main__":
    sys.exit(main())
