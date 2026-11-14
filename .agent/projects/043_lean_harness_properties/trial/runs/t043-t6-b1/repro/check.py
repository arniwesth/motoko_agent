#!/usr/bin/env python3
"""check.py PROPERTY CAP OUT_FILE — judge one run of elide_driver.ail.

The returned `stdout` is `"${clipped}\n[stdout elided; full output at ${raw_path}]"`
(store.ail:41) when `truncated`; `clipped` is truncate_utf8_by_bytes's result. This recovers
`clipped` by removing that exact suffix and checks it against the property:

  P6.1  len(clipped) <= CAP                                  (CAP >= 0)
  P6.2  clipped is a byte prefix of the input
  P6.3  input valid UTF-8  =>  clipped valid UTF-8          (Python's strict decoder = Go's)

Prints one line and exits 1 if the property is violated, 0 if it holds, 2 if the run is not
in the expected shape.
"""
import sys

prop, cap, path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
f = {}
for line in open(path, encoding="utf-8", errors="replace"):
    k, _, v = line.rstrip("\n").partition("|")
    f[k] = v
def b(csv): return bytes(int(x) for x in csv.split(",")) if csv else b""
try:
    inp, out, raw_path, truncated = b(f["input"]), b(f["stdout"]), f["raw_path"], f["truncated"]
except KeyError as e:
    print(f"unexpected driver output, missing {e}"); sys.exit(2)
if truncated != "true":
    print(f"truncated={truncated}: truncate_utf8_by_bytes was not called"); sys.exit(2)
notice = f"\n[stdout elided; full output at {raw_path}]".encode()
if not out.endswith(notice):
    print("returned stdout does not end with the elision notice"); sys.exit(2)
clipped = out[: len(out) - len(notice)]

def valid(x):
    try: x.decode("utf-8", errors="strict"); return True
    except UnicodeDecodeError: return False

shown = clipped.hex(" ") if len(clipped) <= 12 else clipped[:6].hex(" ") + " ... " + clipped[-6:].hex(" ")
head = f"input {len(inp)} bytes, cap {cap}: clipped = {len(clipped)} bytes [{shown}]"
if prop == "P6.1":
    bad = len(clipped) > cap
    print(f"{head}; P6.1 {'VIOLATED' if bad else 'holds'} ({len(clipped)} > {cap})" if bad else f"{head}; P6.1 holds")
elif prop == "P6.2":
    bad = not inp.startswith(clipped)
    print(f"{head}; P6.2 {'VIOLATED' if bad else 'holds'}")
elif prop == "P6.3":
    bad = valid(inp) and not valid(clipped)
    print(f"{head}; input valid={valid(inp)}, clipped valid={valid(clipped)}; P6.3 {'VIOLATED' if bad else 'holds'}")
else:
    print("unknown property"); sys.exit(2)
sys.exit(1 if bad else 0)
