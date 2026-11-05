#!/usr/bin/env python3
"""compare.py — joins the three halves of the T2 differential test.

  compare.py <ts.out> <ail.out> <model.out> <cases.json>

ts.out / ail.out:  <i>\t<JSON string code>\t<T|F>       (the REAL code)
model.out:         <i>\t<hex tsCode>\t<T|F>\t<hex ailCode>\t<T|F>   (the Lean model)

Reports, and exits 1 on any:
  * model-vs-real mismatches on either side (these send the model back to step 2);
Also prints (informational, not a failure) the real cross-language disagreements, P2.1 and P2.2.
"""
import json, sys

def load_real(p):
    rows = {}
    for line in open(p, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or not line[0].isdigit():
            continue
        i, code, gone = line.split("\t")
        rows[int(i)] = (pua(json.loads(code)), gone)
    return rows

def pua(s):
    # The model writes a lone UTF-16 unit u (which only JSON.parse can produce) as U+F0000+u.
    return "".join(chr(0xF0000 + ord(ch)) if 0xD800 <= ord(ch) <= 0xDFFF else ch for ch in s)

ts = load_real(sys.argv[1]); ail = load_real(sys.argv[2])
model = {}
for line in open(sys.argv[3], encoding="utf-8"):
    line = line.rstrip("\n")
    if not line or not line[0].isdigit():
        continue
    i, tc, tg, ac, ag = line.split("\t")
    model[int(i)] = ((bytes.fromhex(tc).decode("utf-8"), tg), (bytes.fromhex(ac).decode("utf-8"), ag))
cases = json.load(open(sys.argv[4], encoding="utf-8"))["cases"]
n = len(cases)
assert len(ts) == n and len(ail) == n and len(model) == n, (len(ts), len(ail), len(model), n)

bad_ts = [i for i in range(n) if model[i][0] != ts[i]]
bad_ail = [i for i in range(n) if model[i][1] != ail[i]]
p21 = [i for i in range(n) if ts[i][1] != ail[i][1]]
p22 = [i for i in range(n) if ts[i][0] != ail[i][0]]

def show(i):
    c = cases[i]
    return f"    #{i} code={c['code']} err={json.dumps(c['err'])}  ts={ts[i]} ail={ail[i]} model_ts={model[i][0]} model_ail={model[i][1]}"

print(f"cases: {n}")
print(f"model vs real TS:     {len(bad_ts)} mismatches")
for i in bad_ts[:15]: print(show(i))
print(f"model vs real AILANG: {len(bad_ail)} mismatches")
for i in bad_ail[:15]: print(show(i))
print(f"real P2.1 disagreements (gone): {len(p21)}; real P2.2 disagreements (code): {len(p22)}")
sys.exit(1 if bad_ts or bad_ail else 0)
