#!/usr/bin/env python3
"""pin_check.py — supporting evidence for B1-T5-1 (not a property check).

The evaluator's copies of the fold's helpers (src/eval/journal/reader.ail) each carry a pin,
`-- SOURCE src/core/journal.ail L.. B<start>-<end> sha256:<h> symbol=<name>`, the sha256 of
the core declaration's bytes when it was copied (tools/eval_protected/protected.py, PIN_RE).
This script hashes the CURRENT core declarations of `contains_string`, `find_entry` and
`path_up` (from `pure func <name>(` through the closing `}` and its newline) and compares
each with its pin. For `path_up` it also hashes the body with the repeated-id branch's
`then []` read as `then acc`.

Run from the tree root:  python3 -I ../out/repro/pin_check.py
Exit 1 when `path_up` no longer matches its pin AND the `acc` reading does (the body was
changed in exactly that token since the copy), 0 when `path_up` matches its pin, 2 otherwise.
"""
import hashlib
import re
import sys

core = open("src/core/journal.ail", "rb").read()
twin = open("src/eval/journal/reader.ail", "rb").read()
PIN =re.compile(rb"^-- SOURCE src/core/journal\.ail L(\d+)-(\d+) B(\d+)-(\d+) "
                 rb"sha256:([0-9a-f]{64}) symbol=(\S+)\s*$", re.M)
pins = {m.group(6).decode(): (m.group(5).decode(), int(m.group(4)) - int(m.group(3)))
        for m in PIN.finditer(twin)}


def decl(name):
    i = core.find(b"pure func " + name.encode() + b"(")
    if i < 0:
        return None
    j = core.find(b"\n}\n", i)
    return core[i:j + 3]


status = 2
for name in ("contains_string", "find_entry", "path_up"):
    body = decl(name)
    pin, n = pins.get(name, ("?", 0))
    h = hashlib.sha256(body).hexdigest() if body else "?"
    print(f"{name}: pinned {pin[:16]} ({n} bytes), current {h[:16]} ({len(body or b'')} bytes):"
          f" {'MATCH' if h == pin else 'DIFFERS'}")
    if name == "path_up":
        alt = body.replace(b"contains_string(seen, id) then []", b"contains_string(seen, id) then acc")
        ha = hashlib.sha256(alt).hexdigest()
        print(f"path_up with `then acc`: {ha[:16]} ({len(alt)} bytes): {'MATCH' if ha == pin else 'DIFFERS'}")
        if h == pin:
            status = 0
        elif ha == pin:
            status = 1
sys.exit(status)
