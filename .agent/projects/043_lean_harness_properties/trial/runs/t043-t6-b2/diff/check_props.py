#!/usr/bin/env python3
"""Bounded check of P6.1-P6.3 on the REAL code's outputs, with no model in between.

Reads direct.out (the real `truncate_utf8_by_bytes`, via the exposed copy) and caller.out
(the real, unmodified `store_stdout_and_elide`), as written by run_diff.sh, and counts the
cases that violate each property. UTF-8 validity is Python's strict decoder, which accepts
exactly what Go's utf8.ValidString accepts (no surrogates, no overlongs, nothing above
U+10FFFF).

  check_props.py <direct.out> <caller.out>

Prints counts and the first witnesses. Exit 0 always: this is a measurement, not a gate.
"""
import sys

NOTICE = b"\n[stdout elided; full output at W/.motoko-store/compose/C.stdout]"


def parse_bytes(field):
    return bytes(int(x) for x in field.split(".")) if field else b""


def valid(b):
    try:
        b.decode("utf-8", errors="strict")
        return True
    except UnicodeDecodeError:
        return False


def main(direct_path, caller_path):
    n = 0
    viol = {"P6.1": [], "P6.2-prefix": [], "P6.2-fits": [], "P6.3": []}
    fits = invalid_in = 0
    for line in open(direct_path):
        tag, s, m, r = line.rstrip("\n").split("|")
        s, m, r = parse_bytes(s), int(m), parse_bytes(r)
        n += 1
        if not valid(s):
            invalid_in += 1
        if m >= 0 and len(r) > m:
            viol["P6.1"].append((s, m, r))
        if not s.startswith(r):
            viol["P6.2-prefix"].append((s, m, r))
        if len(s) <= m:
            fits += 1
            if r != s:
                viol["P6.2-fits"].append((s, m, r))
        if valid(s) and not valid(r):
            viol["P6.3"].append((s, m, r))
    print(f"direct (real truncate_utf8_by_bytes, exposed copy): {n} cases, "
          f"{fits} fit, {invalid_in} with invalid UTF-8 input")
    for k, v in viol.items():
        ex = ", ".join(f"({s.hex()},{m})->{r.hex()}" for s, m, r in v[:3])
        print(f"  {k}: {len(v)} violations{'; e.g. ' + ex if v else ''}")

    c = trunc = x1 = bad_notice = 0
    x1_ex = []
    for line in open(caller_path):
        tag, s, m, t, out = line.rstrip("\n").split("|")
        s, m, out = parse_bytes(s), int(m), parse_bytes(out)
        c += 1
        if t == "1":
            trunc += 1
            if not out.endswith(NOTICE):
                bad_notice += 1
                continue
            clipped = out[: len(out) - len(NOTICE)]
            # X-1: for a cap >= 0 (the caller clamps it positive, compose.ail:851), a result
            # marked truncated must carry a clipped part within the cap. (Its clipped part
            # can then never be the whole input, since truncated means len(s) > cap.)
            if m >= 0 and len(clipped) > m:
                x1 += 1
                if len(x1_ex) < 3:
                    x1_ex.append((s, m, clipped))
    print(f"caller (real store_stdout_and_elide, unmodified): {c} cases, {trunc} truncated, "
          f"{bad_notice} without the expected notice")
    ex = ", ".join(f"({s.hex()},{m})->clipped {cl.hex()}" for s, m, cl in x1_ex)
    print(f"  X-1 (cap >= 0, truncated=true, clipped part over the cap): {x1}{'; e.g. ' + ex if x1 else ''}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
