#!/usr/bin/env python3
"""W5: the numbers behind FINDINGS-001, computed from the record (PLAN-001 §9, §10).

    w5_tables.py <project dir> <findings dir> <out dir>

Reads trial/adjudication/{table,summary}.tsv, the 24 arm transcripts (times only),
collect/<s>/meta, collect/memwatch.log and <findings dir>/tokens.tsv. The real-defect groups
and who found them are CALLS.md's, as the operator accepted them (typed in below, with the
report ids, and checked against table.tsv). Writes sessions.tsv, replicates.tsv, routes.tsv and
defects.tsv to <out dir>, and prints the markdown tables FINDINGS-001 uses.
"""
import csv, json, sys, os, datetime, collections, re

PROJ, FIND, OUT = sys.argv[1:4]
ROOT = "/home/motoko/trial-043"
TP = "/home/motoko/.claude/projects"
os.makedirs(OUT, exist_ok=True)
T = lambda x: datetime.datetime.fromisoformat(x.replace("Z", "+00:00"))
rd = lambda p: list(csv.DictReader(open(p, encoding="utf-8"), delimiter="\t"))

table = rd(f"{PROJ}/trial/adjudication/table.tsv")
tokens = {r["name"]: r for r in rd(f"{FIND}/tokens.tsv")}
SESS = [f"t043-t{t}-{a}{i}" for t in "123456" for a in "ab" for i in "12"]
REPS = ["A1", "A2", "B1", "B2"]
rep_of = lambda s: s[-2].upper() + s[-1]
man = {r["id"]: r for r in rd(f"{PROJ}/trial/runs/planter/manifest.tsv")}
SEEDS = sorted(man)
VALID = [s for s in SEEDS if man[s]["class"] != "E"]

# --- CALLS.md, primary-property real defects (operator's grouping accepted 2026-11-05T18:59:42Z)
D = {
 "D1": ("T2", "P2.1", "known K7", "A1-T2-9 A2-T2-5 B1-T2-3 B2-T2-2 B1-T2-10"),
 "D2": ("T2", "P2.1", "unknown", "A1-T2-5 A2-T2-4 B1-T2-6 B2-T2-6"),
 "D3": ("T2", "P2.1", "unknown", "A1-T2-7 A2-T2-6 B1-T2-5 B2-T2-7"),
 "D4": ("T2", "P2.1", "unknown", "A1-T2-8 A2-T2-7 B1-T2-7 B2-T2-5"),
 "D5": ("T2", "P2.1", "unknown", "A1-T2-10 A2-T2-8 B1-T2-8 B2-T2-14"),
 "D6": ("T3", "P3.1", "unknown", "A1-T3-3 B1-T3-6"),
 "D7": ("T3", "P3.1", "unknown", "A1-T3-4 A2-T3-5"),
 "D8": ("T3", "P3.1", "unknown", "A1-T3-5 B1-T3-5 A2-T3-5 B2-T3-6"),
 "D9": ("T3", "P3.1", "unknown", "B1-T3-9"),
 "D10": ("T3", "P3.2", "unknown, reachable", "A1-T3-6 B1-T3-7 B2-T3-5"),
 "D11": ("T3", "P3.2", "unknown", "A2-T3-4"),
 "D12": ("T5", "P5.3", "unknown", "A1-T5-2 A2-T5-3 B1-T5-3 B2-T5-2"),
}
real_rows = {r["report_id"]: r for r in table if r["class"] == "real defect"}
for g, (_, _, _, rs) in D.items():
    for r in rs.split():
        assert r in real_rows, (g, r, "not a real defect in table.tsv")

def found_by(g, primary_only=False):
    out = set()
    for r in D[g][3].split():
        prop = real_rows[r]["property"]
        if primary_only and not prop.startswith("P"):
            continue
        out.add(r[:2])
    return out

# --- seeds per replicate, from table.tsv (a seed counts once per replicate: W4 decision 18:25:21Z)
det = collections.defaultdict(set); det_route = collections.defaultdict(lambda: collections.defaultdict(set))
det_prop = collections.defaultdict(lambda: collections.defaultdict(set))
for r in table:
    if r["class"] == "detects":
        rp = r["arm"] + r["rep"]
        for s in r["seeds"].split(","):
            det[rp].add(s); det_route[rp][s].add(r["route"]); det_prop[rp][s].add(r["property"])
dc = lambda rp, c: sum(1 for s in det[rp] if man[s]["class"] == c)

# --- times from the transcripts, and memwatch
def times(s):
    meta = dict(l.strip().split("=", 1) for l in open(f"{ROOT}/collect/{s}/meta") if "=" in l)
    f = f"{TP}/-home-motoko-trial-043-s-{s}-tree/{meta['session_id']}.jsonl"
    recs = [json.loads(l) for l in open(f)]
    txt = lambda c: c if isinstance(c, str) else " ".join(x.get("text", "") for x in c if x.get("type") == "text")
    ten = [T(r["timestamp"]) for r in recs if r.get("type") == "user" and txt(r["message"]["content"]).startswith("Ten minutes left")][0]
    td = [(T(r["timestamp"]), r["durationMs"]) for r in recs if r.get("type") == "system" and r.get("subtype") == "turn_duration"]
    before = [x for x in td if x[0] < ten]
    st, sp = T(meta["start_utc"]), T(meta["stop_utc"])
    return {"start": meta["start_utc"], "stop": meta["stop_utc"], "slot_min": (sp - st).total_seconds() / 60,
            "working_min": (before[-1][0] - st).total_seconds() / 60, "active_min": sum(x[1] for x in before) / 60000,
            "ten_min_line": ten.strftime("%H:%M:%SZ")}

kills = collections.Counter()
for l in open(f"{ROOT}/collect/memwatch.log"):
    m = re.search(r" (cap|floor) killed (t043-\S+)", l)
    if m: kills[(m.group(2), m.group(1))] += 1

# --- per session
srows = []
for s in SESS:
    tk = tokens[s]; tm = times(s); rs = [r for r in table if r["session"] == s]
    srows.append({"session": s, "arm": s[-2].upper(), "rep": s[-1], "target": "T" + s[6], "reports": len(rs),
        "detects": sum(r["class"] == "detects" for r in rs), "real": sum(r["class"] == "real defect" for r in rs),
        "unclassified": sum(r["class"] == "unclassified" for r in rs),
        "seeds": ",".join(sorted({x for r in rs if r["class"] == "detects" for x in r["seeds"].split(",")})),
        "tokens_total": int(tk["tokens_total"]), "input": int(tk["input_tokens"]), "cache_write": int(tk["cache_creation_input_tokens"]),
        "cache_read": int(tk["cache_read_input_tokens"]), "output": int(tk["output_tokens"]), "messages": int(tk["messages"]),
        "cs_cost_usd": float(tk["cs_cost_usd"]), "cs_tokens_opus": sum(int(tk[k]) for k in ("cs_opus_input", "cs_opus_cache_creation", "cs_opus_cache_read", "cs_opus_output")),
        "idle_compactions": int(tk["compactions"]), **{k: (round(v, 1) if isinstance(v, float) else v) for k, v in tm.items()},
        "cap_kills": kills[(s, "cap")], "floor_kills": kills[(s, "floor")]})
with open(f"{OUT}/sessions.tsv", "w") as f:
    w = csv.DictWriter(f, fieldnames=list(srows[0]), delimiter="\t"); w.writeheader(); w.writerows(srows)

# --- per replicate
def rep_rows(rp):
    ss = [r for r in srows if r["arm"] + r["rep"] == rp]
    U = sorted((g for g in D if D[g][2] != "known K7" and rp in found_by(g)), key=lambda g: int(g[1:]))
    Up = sorted((g for g in D if D[g][2] != "known K7" and rp in found_by(g, True)), key=lambda g: int(g[1:]))
    return {"rep": rp, **{f"D({c})": dc(rp, c) for c in ("S1", "S2", "S3", "S4", "E")},
            "D(S1+S2+S3)": sum(dc(rp, c) for c in ("S1", "S2", "S3")),
            "F": sum(1 for r in table if r["arm"] + r["rep"] == rp and r["class"] == "false report"),
            "missed": ",".join(s for s in VALID if s not in det[rp]) or "none",
            "U": len(U), "U_list": " ".join(U), "U_primary_reports_only": len(Up), "U_reachable": sum(1 for g in U if "reachable" in D[g][2]),
            "tokens_total": sum(r["tokens_total"] for r in ss), "output": sum(r["output"] for r in ss),
            "input_plus_output_fields": sum(r["input"] + r["output"] for r in ss),
            "cs_tokens_opus": sum(r["cs_tokens_opus"] for r in ss), "cs_cost_usd": round(sum(r["cs_cost_usd"] for r in ss), 2),
            "working_min": round(sum(r["working_min"] for r in ss), 1), "active_min": round(sum(r["active_min"] for r in ss), 1),
            "slot_min": round(sum(r["slot_min"] for r in ss), 1),
            "cap_kills": sum(r["cap_kills"] for r in ss), "floor_kills": sum(r["floor_kills"] for r in ss)}
rrows = [rep_rows(rp) for rp in REPS]
for arm in "AB":
    a, b = [r for r in rrows if r["rep"][0] == arm]
    m = {"rep": f"{arm} mean"}
    for k in a:
        if k == "rep": continue
        m[k] = (a[k] + b[k]) / 2 if isinstance(a[k], (int, float)) else ""
    rrows.append(m)
with open(f"{OUT}/replicates.tsv", "w") as f:
    w = csv.DictWriter(f, fieldnames=list(rrows[0]), delimiter="\t"); w.writeheader(); w.writerows(rrows)

# --- routes
with open(f"{OUT}/routes.tsv", "w") as f:
    f.write("rep\tseed\tclass\troutes\tproperties\n")
    for rp in REPS:
        for s in sorted(det[rp]):
            f.write(f"{rp}\t{s}\t{man[s]['class']}\t{','.join(sorted(det_route[rp][s]))}\t{','.join(sorted(det_prop[rp][s]))}\n")
with open(f"{OUT}/defects.tsv", "w") as f:
    f.write("group\ttarget\tproperty\tstatus\treports\tfound_by\troutes\n")
    for g, (t, p, st, rs) in D.items():
        routes = sorted({real_rows[r]["route"] for r in rs.split()})
        f.write(f"{g}\t{t}\t{p}\t{st}\t{rs}\t{' '.join(sorted(found_by(g)))}\t{','.join(routes)}\n")

# --- print
def md(rows, keys):
    print("| " + " | ".join(keys) + " |"); print("|" + "---|" * len(keys))
    for r in rows: print("| " + " | ".join(str(r[k]) for k in keys) + " |")
    print()
md(rrows, ["rep", "D(S1)", "D(S2)", "D(S3)", "D(S4)", "D(E)", "D(S1+S2+S3)", "F", "missed", "U", "U_list", "U_reachable"])
md(rrows, ["rep", "tokens_total", "output", "input_plus_output_fields", "cs_tokens_opus", "cs_cost_usd", "working_min", "active_min", "cap_kills", "floor_kills"])
md(srows, ["session", "target", "reports", "detects", "real", "seeds", "tokens_total", "output", "cs_cost_usd", "working_min", "active_min", "idle_compactions", "cap_kills", "floor_kills"])
rc = collections.Counter((r["arm"], r["route"], r["class"]) for r in table)
print("routes per report (arm, route, class):", dict(sorted(rc.items())))
for arm in "AB":
    ta = sum(r["tokens_total"] for r in srows if r["arm"] == arm); oa = sum(r["output"] for r in srows if r["arm"] == arm)
    print(arm, "tokens_total", ta, "output", oa)
ta = {a: sum(r["tokens_total"] for r in srows if r["arm"] == a) for a in "AB"}
oa = {a: sum(r["output"] for r in srows if r["arm"] == a) for a in "AB"}
ia = {a: sum(r["input"] + r["output"] for r in srows if r["arm"] == a) for a in "AB"}
ca = {a: sum(r["cs_tokens_opus"] for r in srows if r["arm"] == a) for a in "AB"}
ua = {a: sum(r["cs_cost_usd"] for r in srows if r["arm"] == a) for a in "AB"}
print(f"B/A: tokens_total {ta['B']/ta['A']:.3f}; output {oa['B']/oa['A']:.3f}; input_tokens+output {ia['B']/ia['A']:.3f}; cost-state opus tokens {ca['B']/ca['A']:.3f}; cost-state USD {ua['B']/ua['A']:.3f}")
for t in "123456":
    a = sum(r["tokens_total"] for r in srows if r["arm"] == "A" and r["target"] == "T" + t)
    b = sum(r["tokens_total"] for r in srows if r["arm"] == "B" and r["target"] == "T" + t)
    print(f"T{t}: A {a} B {b} B/A {b/a:.2f}")
