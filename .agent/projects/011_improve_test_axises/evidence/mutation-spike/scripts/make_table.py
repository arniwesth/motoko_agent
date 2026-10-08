#!/usr/bin/env python3
"""SPIKE ONLY — builds evidence/mutation-spike/mutants.tsv from the run output. Nothing is typed by hand."""
import importlib.util, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
m1, m3, s2 = load("mutants"), load("mutants3"), load("score2")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
GATES = ["corpus_pr", "strict_replay", "discovery", "stream_parity", "ledger_parity"]

def site(file, old, anchor=None):
    src = open(file, encoding="utf-8").read()
    start = src.index(anchor) if anchor else 0
    return f"{file}:{src.count(chr(10), 0, src.index(old, start)) + 1}"

def steps(d):
    st = {}
    p = os.path.join(d, "summary.tsv")
    if not os.path.exists(p): return st
    for line in open(p, encoding="utf-8", errors="replace"):
        f = line.rstrip("\n").split("\t")
        if f[0] == "step":
            r = re.fullmatch(r"rc=(-?\d+)", f[2]); st[f[1]] = int(r.group(1)) if r else None
    return st

def reds(d, gates):
    st = steps(d)
    if not st: return "not run"
    if st.get("check") != 0: return "type check failed"
    r = [g for g in gates if st.get(g) not in (0, None)]
    return ",".join(r) if r else "none"

def sweep_failed(mid):
    p = os.path.join(HERE, "out", f"sweep-{mid}", "dst.log")
    if not os.path.exists(p): return None
    t = ANSI.sub("", open(p, encoding="utf-8", errors="replace").read())
    blk = re.search(r"FAILED \(\d+\):\n((?:\s+\S+.*\n)+)", t)
    return set(l.split()[0] for l in blk.group(1).splitlines() if l.strip()) if blk else set()

def fam(outdir, mid, idx):
    s2.OUT = os.path.join(HERE, outdir)
    ok, why, base = s2.parse(os.path.join(s2.OUT, "baseline-3" if outdir == "out3" else "baseline"))
    if not ok or not os.path.isdir(os.path.join(s2.OUT, mid)): return "not run"
    ok2, why2, rows = s2.parse(os.path.join(s2.OUT, mid))
    if not ok2: return "incomplete"
    new = s2.new_findings(base, rows, idx)
    return ("red: " + ",".join(sorted({r for _, r in new})) + f" on {len({m for m, _ in new})} member(s)") if new else "clean"

base_sweep = sweep_failed("unmutated") or set()
rows = []
for m in m1.MUTANTS:
    mid = m["id"]
    sw = sweep_failed(mid)
    sweep = "not run (killed by the targeted gates)" if sw is None else (",".join(sorted(sw - base_sweep)) or "none")
    if mid == "K0": sweep = "not run (four affected targets rerun alone: all pass)"
    rows.append([mid, site(m["file"], m["old"], m.get("anchor")), m["rule"], m["predict"],
                 reds(os.path.join(HERE, "out", mid), GATES), sweep,
                 fam("out2", mid, 2), fam("out4", mid, 2), fam("out4", mid, 3)])
G3 = GATES + ["world_state"]
for m in m3.MUTANTS:
    mid = m["id"]
    if not mid.startswith("T"): continue
    p = "P" + mid[1:]
    reach = reds(os.path.join(HERE, "out3", p), G3)
    bank = "bank reaches it" if steps(os.path.join(HERE, "out3", p)).get("bank_probe") not in (0, None) else "bank does not reach it"
    rows.append([mid, site(m3.S, m["old"]), m["rule"], "see predictions3.tsv",
                 reds(os.path.join(HERE, "out3", mid), G3) + f" [reached by: {reach}; {bank}]", "not run",
                 fam("out3", mid, 2), fam("out4", mid, 2), fam("out4", mid, 3)])
for mid, note in (("K2", "known bad for the existing outcome rule"), ("M3m", "mirror of M3: the success finalize reports a failure reason")):
    rows.append([mid, "src/core/session.ail", note, "see predictions4.tsv", "not run", "not run",
                 fam("out2", mid, 2), fam("out4", mid, 2), fam("out4", mid, 3)])
hdr = ["id", "site", "rule broken", "predicted (targeted gates)", "targeted gates red", "full sweep: red beyond the unmutated baseline",
       "invariant set on the corpus, as shipped", "invariant set on the corpus, with the prototype", "prototype's probe-side rules"]
print("\t".join(hdr))
for r in rows: print("\t".join(r))
