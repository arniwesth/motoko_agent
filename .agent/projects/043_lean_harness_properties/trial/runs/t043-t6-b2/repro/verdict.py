#!/usr/bin/env python3
"""Judges one line of repro.ail output for one property. Exit 1 if the defect is present,
0 if absent, 2 if the line is malformed (the repro did not run as designed).

  verdict.py <P6.1|P6.3|X-1>   < line

P6.1  the clipped part (the real truncate_utf8_by_bytes's result) is over the cap (cap >= 0)
P6.3  the input is valid UTF-8 and the clipped part is not
X-1   store_stdout_and_elide says truncated=true, and its stdout, less the notice, is over
      the cap: here, the entire input
"""
import sys

prop = sys.argv[1]
line = sys.stdin.read().strip().splitlines()
if len(line) != 1 or line[0].count("|") != 4:
    print(f"malformed repro output: {line!r}")
    sys.exit(2)
s, cap, trunc, out, raw_path = line[0].split("|")
b = lambda f: bytes(int(x) for x in f.split(".")) if f else b""
s, cap, out = b(s), int(cap), b(out)
notice = f"\n[stdout elided; full output at {raw_path}]".encode()
if trunc != "1" or not out.endswith(notice):
    print(f"not truncated, or notice missing: truncated={trunc}")
    sys.exit(2)
clipped = out[: len(out) - len(notice)]

def valid(x):
    try:
        x.decode("utf-8", errors="strict"); return True
    except UnicodeDecodeError:
        return False

show = lambda x: x.hex() if len(x) <= 16 else f"{x[:8].hex()}...({len(x)} bytes)"
print(f"input {show(s)} ({len(s)} bytes, valid={valid(s)}), cap {cap}: "
      f"truncated={trunc}, clipped {show(clipped)} ({len(clipped)} bytes, valid={valid(clipped)})")
if prop == "P6.1":
    bad = cap >= 0 and len(clipped) > cap
elif prop == "P6.3":
    bad = valid(s) and not valid(clipped)
elif prop == "X-1":
    bad = cap >= 0 and len(clipped) > cap
    if bad and clipped == s:
        print("the 'clipped' part is the whole input: nothing was elided")
else:
    print(f"unknown property {prop}"); sys.exit(2)
print(f"{prop}: {'DEFECT PRESENT' if bad else 'absent'}")
sys.exit(1 if bad else 0)
