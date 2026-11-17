#!/usr/bin/env python3
"""039 random-mutant pilot: the draw.

    draw.py order                 write draw-order.tsv: every site, in the seeded order, with the
                                  operator and the candidate drawn for it. Pure; reads only the
                                  enumeration and base.txt.
    draw.py check <scratch> [n]   walk draw-order.tsv from the top: apply each drawn candidate in
                                  the scratch worktree, run `ailang check` on the edited file,
                                  restore, verify. Stop when n (default 30) have type-checked.
                                  Writes draw-checked.tsv, one row per site walked.

THE GENERATOR. Nobody picks the seed: it is the base commit's full SHA, read from base.txt. Every
random choice is a SHA-256 of the seed and a label, read as an integer:

    h(label) = int(sha256("<seed>|<label>"), 16)

    site order:      the sites sorted by h("site|<site>")                 (a permutation)
    operator:        sorted(operators at the site)[h("op|<site>") % n]
    candidate:       sorted(candidate ids of that operator there)[h("cand|<site>|<op>") % m]

Nothing else is consulted, so anyone can recompute the order from the two files. A site is never
skipped or reordered: a drawn mutant that does not type-check is recorded as such and the next
site in the order is taken.
"""
import hashlib
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENUM = os.path.join(HERE, "enumeration-a1")
FILES = ["src/core/session.ail", "src/core/step_machine.ail", "src/core/recovery.ail", "src/core/tool_phase.ail"]


def seed():
    for l in open(os.path.join(HERE, "base.txt"), encoding="utf-8"):
        k, v = l.rstrip("\n").split("\t")
        if k == "base_commit":
            return v
    sys.exit("no base_commit in base.txt")


def h(s, label):
    return int(hashlib.sha256(f"{s}|{label}".encode()).hexdigest(), 16)


def read_tsv(p):
    rows = [l.rstrip("\n").split("\t") for l in open(p, encoding="utf-8")]
    return [dict(zip(rows[0], r)) for r in rows[1:] if r and r[0]]


def order():
    s = seed()
    cands = read_tsv(os.path.join(ENUM, "candidates.tsv"))
    by_site = {}
    for c in cands:
        site = f"{c['id'].split(':')[0]}:{c['line']}"
        by_site.setdefault(site, {}).setdefault(c["operator"], []).append(c["id"])
    sites = sorted(by_site, key=lambda x: h(s, f"site|{x}"))
    out = []
    for rank, site in enumerate(sites, 1):
        ops = sorted(by_site[site])
        op = ops[h(s, f"op|{site}") % len(ops)]
        ids = sorted(by_site[site][op])
        cid = ids[h(s, f"cand|{site}|{op}") % len(ids)]
        out.append((rank, site, ",".join(ops), op, len(ids), cid))
    with open(os.path.join(HERE, "draw-order.tsv"), "w", encoding="utf-8") as o:
        o.write("rank\tsite\toperators_at_site\tdrawn_operator\tcandidates_of_that_operator\tdrawn_candidate\n")
        for r in out:
            o.write("\t".join(map(str, r)) + "\n")
    print(f"seed {s}; {len(out)} sites ordered")


def sh(cmd, cwd, timeout=600):
    p = subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout + p.stderr


def base_hashes(scratch):
    rc, out = sh("sha256sum " + " ".join(FILES), scratch)
    return out


def check(scratch, want=30):
    base = open(os.path.join(HERE, "base.sha256"), encoding="utf-8").read()
    rows = read_tsv(os.path.join(HERE, "draw-order.tsv"))
    out_path = os.path.join(HERE, "draw-checked.tsv")
    with open(out_path, "w", encoding="utf-8") as o:
        o.write("rank\tsite\tdrawn_operator\tdrawn_candidate\ttype_check\tcheck_secs\tfirst_error\tmutant_no\n")
    ok = 0
    for r in rows:
        if ok >= want:
            break
        if base_hashes(scratch) != base or sh("git status --short", scratch)[1].strip():
            sys.exit(f"ABORT before {r['drawn_candidate']}: scratch not at base")
        rc, msg = sh(f"python3 {HERE}/scripts/mutator.py apply '{r['drawn_candidate']}' {scratch}", scratch)
        if rc != 0:
            sys.exit(f"ABORT: apply refused {r['drawn_candidate']}: {msg}")
        path = r["drawn_candidate"].split(":")[0]
        f = next(x for x in FILES if x.endswith(f"/{path}.ail"))
        t0 = time.time()
        rc, msg = sh(f"ailang check {f}", scratch)
        secs = round(time.time() - t0, 1)
        first = next((l.strip() for l in msg.splitlines() if "rror" in l), "") if rc else ""
        sh("git checkout -- " + " ".join(FILES), scratch)
        if base_hashes(scratch) != base or sh("git status --short", scratch)[1].strip():
            sys.exit(f"ABORT after {r['drawn_candidate']}: restore failed")
        verdict = "ok" if rc == 0 else f"FAILED(rc={rc})"
        if rc == 0:
            ok += 1
        with open(out_path, "a", encoding="utf-8") as o:
            o.write("\t".join([r["rank"], r["site"], r["drawn_operator"], r["drawn_candidate"], verdict,
                               str(secs), first.replace("\t", " ")[:300], f"m{ok:02d}" if rc == 0 else "-"]) + "\n")
        print(f"{r['rank']:>4} {r['drawn_candidate']:45} {verdict:12} {secs}s", flush=True)
    print(f"{ok} type-checked")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["order"]:
        order()
    elif a[:1] == ["check"] and len(a) in (2, 3):
        check(a[1], int(a[2]) if len(a) == 3 else 30)
    else:
        sys.exit(__doc__)
