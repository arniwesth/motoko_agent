#!/usr/bin/env python3
"""classify.py <scratch dir>: attributes every P2.1 disagreement between the REAL twins
(ts.out, ail.out from run_diff.sh) to the mechanisms of reports B1-T2-1..8, by predicates on
the input alone, and counts the disagreements no mechanism explains (the list is complete for
this corpus only if that count is 0)."""
import json, math, os, sys, collections

here = os.path.dirname(os.path.abspath(sys.argv[0]))
cs = json.load(open(os.path.join(here, "gen", "corpus.json")))["stderr"]
JSON_WS = " \t\n\r"
JS_WS = set("\t\n\u000b\u000c\r       　﻿" + "".join(chr(c) for c in range(0x2000, 0x200b)))

def dup_hook(pairs):
    keys = [k for k, _ in pairs]
    if len(keys) != len(set(keys)):
        raise KeyError("dup")
    return dict(pairs)

def first_value(s):
    t = s.lstrip(JSON_WS)
    try:
        v, end = json.JSONDecoder().raw_decode(t)
        return v, t[end:]
    except Exception:
        return None, None

def mechanisms(e, s, ts_code):
    m = []
    if e < 0: m.append("2-negative-exit")
    if ts_code.endswith("_not_found") and ts_code != "agent_not_found": m.append("1-suffix")
    if "nested herdr" in s: m.append("3-nested")
    if '{"error"' not in s: m.append("4-sniff")
    if (s[:1] in JS_WS and s[:1] not in JSON_WS) or (s[-1:] in JS_WS and s[-1:] not in JSON_WS): m.append("5-js-trim")
    v, rest = first_value(s)
    if rest is not None and rest.strip(JSON_WS) != "": m.append("6-trailing")
    try:
        json.loads(s.strip("".join(JS_WS)), object_pairs_hook=dup_hook)
    except KeyError:
        m.append("7-dup-key")
    except Exception:
        pass
    try:
        json.loads(s.strip("".join(JS_WS)), parse_float=lambda x: (_ for _ in ()).throw(OverflowError()) if math.isinf(float(x)) else float(x),
                   parse_int=lambda x: (_ for _ in ()).throw(OverflowError()) if math.isinf(float(x)) else int(x))
    except OverflowError:
        m.append("8-f64")
    except Exception:
        pass
    return m

ts = [l.rstrip("\n").split("|") for l in open(os.path.join(sys.argv[1], "ts.out"))]
ail = [l.rstrip("\n").split("|") for l in open(os.path.join(sys.argv[1], "ail.out"))]
count, alone, unexplained, total = collections.Counter(), collections.Counter(), [], 0
for t, a in zip(ts, ail):
    assert t[:2] == a[:2]
    if t[3] == a[3]:
        continue
    total += 1
    s = cs[int(t[0])]
    ms = mechanisms(int(t[1]), s, t[2])
    for x in ms: count[x] += 1
    if len(ms) == 1: alone[ms[0]] += 1
    if not ms: unexplained.append((t, a, s))
print("P2.1 disagreements: %d; unexplained by any mechanism: %d" % (total, len(unexplained)))
for k in sorted(count):
    print("  %-16s applies to %5d, sole mechanism for %5d" % (k, count[k], alone[k]))
for t, a, s in unexplained[:10]:
    print("  UNEXPLAINED", t, a, json.dumps(s))
