#!/usr/bin/env python3
"""ADR-002 D7: `resolve_process_limit` is the only constructor of both results.

A record type is structural in AILANG, so the compiler cannot enforce this: any module can
write the literal, or a record update, and it type-checks. This scans every `.ail` file git
sees (tracked or untracked, not ignored), with comments and string contents removed, so that
text about the rule is not mistaken for a breach of it. It exits 1 on any of:

  1. A result label, written to anywhere outside the two type declarations and the resolver.
     Both results hold `session_default` and `effective_ceiling`, and a record cannot exist
     without its labels, so a literal cannot avoid this, wherever it is and however it is laid
     out. A label followed by `,` or `}` counts too, in case of a punned field.
  2. A record update, on any base at all, whose labels are all result fields, including
     `budget` (`{ r | clamped: true }`, `{ idr(r) | budget: x }`). `PureCtx` has a `budget` too,
     and this scan has no types, so the labels decide: AILANG refuses an update naming a field
     the record lacks, which means `{ pure_ctx(c) | task: t, budget: b }` cannot be on a result.
     Row g7 in the evidence below holds that refusal to account.
  3. `ProcessResolved` or `ProcessInvalid` used as anything but a pattern, the type
     declaration, or an unaliased import: a wrapping call, an alias, or a bare function value.
  4. Inside the module: not exactly one construction of each constructor in the resolver, or
     a label there holding anything but `limits.default` and `limits.ceiling`, or field counts
     in the two type declarations that differ from what is written here.

Exit 2 means it could not check: the module or the resolver is missing, or git failed. That is
never a pass. Reading a field (`r.session_default`) and matching (`ProcessResolved(r) =>`) are
allowed, because that is how every caller uses the value.

Limits. It is a scan and not a type check: a future function parameter named `session_default`
is a false alarm, and should be renamed. So is an update of another record that names only result
fields, `{ ctx | budget: b }`: name one of its other fields as well. It does not stop a `.ail`
file git ignores.

`make verify_single_construction` runs it, and `check_core` depends on that target, so a breach
or a could-not-check fails `check_core`. evidence/W4/mutate.sh also runs it, and the proof that
it is a real gate is in evidence/gate-single-construction/, both under
.agent/projects/041_process_execution_timeouts/.
"""
import re
import subprocess
import sys
from pathlib import Path

MODULE = "src/core/process_limits.ail"
RESOLVER = "resolve_process_limit"
LABELS = ("session_default", "effective_ceiling", "clamped", "requested_ms")
UPDATE_FIELDS = LABELS + ("budget",)
CTORS = ("ProcessResolved", "ProcessInvalid")
LABEL_RE = re.compile(r"(?<![.\w])(%s)\s*[:,}]" % "|".join(LABELS))
# The head of an update's field list: one `|`, not `||`, then `label:`. Nothing else in the
# language has that shape, so the base in front of it, braces and all, does not have to be read.
UPDATE_RE = re.compile(r"(?<!\|)\|(?!\|)\s*(?=\w+\s*:)")
CTOR_RE = re.compile(r"\b(%s)\b" % "|".join(CTORS))
IMPORT_RE = re.compile(r"^\s*import\b[^\n(]*(\([^)]*\))?", re.M)
TOP_RE = re.compile(r"^(?:export\s+)?(?:pure\s+)?(?:func|type)\s+(\w+)", re.M)


def strip(text):
    """Comments and string contents become spaces, so offsets and line numbers hold."""
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith("--", i):
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
        elif text[i] == '"':
            out.append('"')
            i += 1
            while i < n and text[i] != '"':
                if text[i] == "\\" and i + 1 < n:
                    out.append("  ")
                    i += 2
                else:
                    out.append("\n" if text[i] == "\n" else " ")
                    i += 1
            out.append('"')
            i += 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def spans(code):
    """{top-level name: (start, end)}, each running to the next top-level declaration."""
    ms = list(TOP_RE.finditer(code))
    return {m.group(1): (m.start(), ms[k + 1].start() if k + 1 < len(ms) else len(code))
            for k, m in enumerate(ms)}


def update_labels(code, start):
    """The labels of the update whose field list starts at `start`, not those nested in its values."""
    depth, top = 0, []
    for c in code[start:]:
        if c == "}" and depth == 0:
            break
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0:
            top.append(c)
    return re.findall(r"(?:^|,)\s*(\w+)\s*:", "".join(top))


def is_pattern(code, end):
    """True when the constructor ending at `end` has `(...)` and then `=>`."""
    i = end
    while i < len(code) and code[i].isspace():
        i += 1
    if i >= len(code) or code[i] != "(":
        return False
    depth = 0
    while i < len(code):
        depth += {"(": 1, ")": -1}.get(code[i], 0)
        i += 1
        if depth == 0:
            break
    # A nested pattern, `Some(ProcessResolved(r)) =>`, closes its outer parens first.
    while i < len(code) and (code[i].isspace() or code[i] == ")"):
        i += 1
    return code.startswith("=>", i)


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    ls = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "*.ail"],
                        cwd=root, capture_output=True, text=True)
    if ls.returncode != 0:
        print("cannot list files: " + ls.stderr.strip())
        return 2
    files = sorted(set(ls.stdout.split()))
    # `ls-files -c` still lists a tracked file that is gone from disk, so the listing alone
    # would skip the module and exit 0.
    if MODULE not in files or not (root / MODULE).is_file():
        print(f"cannot check: {MODULE} is not there")
        return 2

    bad, scanned = [], 0
    for rel in files:
        path = root / rel
        if not path.is_file():
            continue
        scanned += 1
        code = strip(path.read_text(errors="replace"))
        line = lambda off: code.count("\n", 0, off) + 1
        allowed = []
        if rel == MODULE:
            sp = spans(code)
            for name in (RESOLVER, "ResolvedProcess", "InvalidRequest", "ProcessResolution"):
                if name not in sp:
                    print(f"cannot check: {name} is not declared in {MODULE}")
                    return 2
            allowed = [sp[RESOLVER], sp["ResolvedProcess"], sp["InvalidRequest"], sp["ProcessResolution"]]
        inside = lambda off: any(a <= off < b for a, b in allowed)

        for m in LABEL_RE.finditer(code):
            if not inside(m.start()):
                bad.append(f"{rel}:{line(m.start())}: result label `{m.group(1)}` written outside the resolver")
        for m in UPDATE_RE.finditer(code):
            labels = update_labels(code, m.end())
            if labels and set(labels) <= set(UPDATE_FIELDS) and not inside(m.start()):
                bad.append(f"{rel}:{line(m.start())}: record update of result field `{labels[0]}`")

        imports = [m.span() for m in IMPORT_RE.finditer(code)]
        for m in CTOR_RE.finditer(code):
            off = m.start()
            imp = next((s for s in imports if s[0] <= off < s[1]), None)
            if imp:
                if re.match(r"\s+as\b", code[m.end():]):
                    bad.append(f"{rel}:{line(off)}: `{m.group(1)}` imported under an alias")
                continue
            if rel == MODULE and sp["ProcessResolution"][0] <= off < sp["ProcessResolution"][1]:
                continue
            if rel == MODULE and sp[RESOLVER][0] <= off < sp[RESOLVER][1]:
                continue
            if not is_pattern(code, m.end()):
                bad.append(f"{rel}:{line(off)}: `{m.group(1)}` used as a value, not a pattern")

        if rel == MODULE:
            body = code[sp[RESOLVER][0]:sp[RESOLVER][1]]
            for ctor in CTORS:
                n = len(re.findall(r"\b%s\(" % ctor, body))
                if n != 1:
                    bad.append(f"{rel}: the resolver constructs {ctor} {n} times, not once")
            for label, want in (("session_default", "limits.default"), ("effective_ceiling", "limits.ceiling")):
                vals = re.findall(r"\b%s\s*:\s*([^,}\s]+)" % label, body)
                if vals != [want, want]:
                    bad.append(f"{rel}: the resolver writes {label} as {vals}, not {want} in each result")
            for ty, n in (("ResolvedProcess", 5), ("InvalidRequest", 3)):
                decl = code[sp[ty][0]:sp[ty][1]]
                if len(re.findall(r"\w+\s*:", decl)) != n:
                    bad.append(f"{rel}: {ty} does not have the {n} fields this check knows")

    for b in bad:
        print(b)
    print(f"check_single_construction: {scanned} .ail files, {len(bad)} breaches")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
