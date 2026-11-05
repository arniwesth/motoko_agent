#!/usr/bin/env bash
# PLAN-001 §8, W4: the adjudication, as one script. Every reproduction in every arm session's
# reports.tsv is run on the seeded tree T, on the unseeded base B0, and on T−s for each seed s
# (T with s's patch reversed), and classified by §8's rules.
#
#   adjudicate.sh build              B0, T and T−s01..T−s14 under $ADJ/trees, each hash checked
#   adjudicate.sh prepare            one work directory per session, with a copy of its out/
#   adjudicate.sh run [JOBS]         every report on every tree; resumable; JOBS sessions at once
#   adjudicate.sh pairs [JOBS]       T−{s,t} for every pair, for reports §8 calls seed interaction
#   adjudicate.sh table              classifies, and writes $ADJ/table.tsv, summary.tsv and runs.tsv
#   adjudicate.sh check              the 24 output directories still hash to their W2 values
#   adjudicate.sh all [JOBS]         check build prepare run pairs table check
#
# How a reproduction is run (the choices PLAN-001 leaves open, logged in sequence.log at W4):
#  - LAYOUT. §8: "one command, run from the tree root", and A3's reproductions refer to ../out/.
#    Session S gets $ADJ/work/S/{tree,out,tmp}. Before each run, tree/ is restored from the
#    pristine variant tree and out/ from a pristine copy of S's output directory, both with
#    rsync --delete, so no run sees another run's writes. AILANG's .ailang/ compile caches are
#    kept between runs: their key is a hash of the compiler version, the module's source and its
#    dependencies' digests (ailang e1ef33f, internal/pipeline/cache_key.go), so a cache entry
#    cannot serve one tree's code to another.
#  - PATHS. Arms wrote absolute paths to their own directories (/home/motoko/trial-043/s/S/...)
#    in commands, scripts and symlinks. The originals must not be touched and this machine
#    allows no mount namespace, so in the copy of out/ (text files outside .ailang/ and
#    node_modules/), in symlink targets and in the command, "/home/motoko/trial-043/s/S" becomes
#    "$ADJ/work/S". Nothing else in any file changes.
#  - ENVIRONMENT. PATH as the arms had it, HOME, USER, LOGNAME, SHELL, LANG, LC_ALL, TERM, and
#    TMPDIR=$ADJ/work/S/tmp (emptied before each run). Nothing else: no herdr variables, no
#    credentials, no proxy.
#  - LIMITS. §8's 120 s, wall clock, for the whole process group. A memory guard the plan does
#    not have, because this machine froze under memory pressure at W2: a run whose process
#    group's resident memory passes 6 GiB, the cap memwatch.py held the arms to, is killed and
#    recorded as an error ("mem"); and while MemAvailable is under 3 GiB, the largest running
#    reproduction is killed and queued again ("floor", never final).
#  - LOAD AND STABILITY. A run that times out, or is stopped at the floor, is run again alone
#    after its batch; the solo result is final. Every result that would decide a detection (T−s
#    exiting 0 where T exited 1) and every B0 result that decides real against interaction is
#    run a second time, together with T; a detection needs the same outcome both times.
#  - Results: exit 0 or 1; anything else, a timeout or a memory kill is an error (§8).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
ADJ="${ADJ:-$ROOT/adjudication}"
PLANTER="$PROJECT/trial/runs/planter"
SEEDS="s01 s02 s03 s04 s05 s06 s07 s08 s09 s10 s11 s12 s13 s14"
# W0 and W1 hashes (sequence.log): the unseeded tree, the seeded tree, the manifest and the patch.
B0_SHA=d23702050e5c4d248d3252fce95d82f30ed489cf8b487758aafe1160465a39aa
T_SHA=e143a3900ce1cd392d1d35bf481cb15ec548a0c11633f733e0a3ab94f6d09bf3
MANIFEST_SHA=24c2bbe26280aaf2c2b80c444ee9728cea6512086845ca91bf40fbc916fb9d2c
PATCH_SHA=a21b56bd986ac6a7feeebdf29d29403adc42665e0c83dcc193c768f66e08f9de
SESSIONS="$(for t in 1 2 3 4 5 6; do for r in a1 a2 b1 b2; do printf 't043-t%s-%s ' $t $r; done; done)"
export ADJ ROOT PLANTER SEEDS SESSIONS

die() { echo "adjudicate: $*" >&2; exit 2; }

check() {
  for s in $SESSIONS; do
    want=$(grep '^out_sha256=' "$ROOT/collect/$s/meta" | cut -d= -f2)
    got=$(hash_dir "$ROOT/s/$s/out")
    [ "$got" = "$want" ] || die "$s: out/ hashes to $got, not its W2 value $want"
  done
  echo "check: all 24 output directories hash to their W2 out_sha256"
}

build() {
  [ "$(sha256sum < "$PLANTER/manifest.tsv" | cut -d' ' -f1)" = "$MANIFEST_SHA" ] || die "manifest hash"
  [ "$(sha256sum < "$PLANTER/seeds.patch" | cut -d' ' -f1)" = "$PATCH_SHA" ] || die "seeds.patch hash"
  mkdir -p "$ADJ/trees"; cd "$ADJ/trees"
  local f="$ADJ/trees/HASHES"; : > "$f.new"
  if [ ! -d B0 ]; then h=$(bash "$SCRIPTS/build_tree.sh" B0); else h=$(hash_dir B0); fi
  [ "$h" = "$B0_SHA" ] || die "B0 hashes to $h, not W0's $B0_SHA"; echo "B0 $h" >> "$f.new"
  if [ ! -d T ]; then h=$(bash "$SCRIPTS/build_tree.sh" T "$PLANTER/seeds.patch"); else h=$(hash_dir T); fi
  [ "$h" = "$T_SHA" ] || die "T hashes to $h, not W1's $T_SHA"; echo "T $h" >> "$f.new"
  for s in $SEEDS; do
    if [ ! -d "T-$s" ]; then
      cp -a T "T-$s.tmp"
      (cd "T-$s.tmp" && patch -R -p1 -s -f --no-backup-if-mismatch < "$PLANTER/seeds/$s.patch") \
        || die "$s does not reverse cleanly on T"
      [ -z "$(find "T-$s.tmp" -name '*.rej' -o -name '*.orig')" ] || die "$s left .rej/.orig files"
      mv "T-$s.tmp" "T-$s"
    fi
    echo "T-$s $(hash_dir "T-$s")" >> "$f.new"
  done
  # Each T−s differs from B0 only in the files of the other seeds' patches and in ailang.lock:
  # seeds.patch also refreshes the lock's content_hash for the seeded packages, and the per-seed
  # patches carry no lock hunk, so T−s keeps T's lock (as the planter's T−s did; AILANG only warns).
  for s in $SEEDS; do
    want=$( (echo ailang.lock; for o in $SEEDS; do [ "$o" = "$s" ] || grep '^+++ ' "$PLANTER/seeds/$o.patch" | sed 's|^+++ b/||; s|\t.*||'; done) | sort -u)
    got=$( (diff -rq B0 "T-$s" || true) | sed -E 's|^Files B0/([^ ]+) and .*|\1|' | sort -u)
    # A file two seeds share stays changed while either remains; compare as sets.
    [ -z "$(comm -13 <(echo "$want") <(echo "$got"))" ] || die "T-$s changes files outside the other seeds: $(comm -13 <(echo "$want") <(echo "$got"))"
  done
  mv "$f.new" "$f"; cat "$f"
}

prepare() {
  mkdir -p "$ADJ/work"
  for s in $SESSIONS; do
    w="$ADJ/work/$s"; src="$ROOT/s/$s"
    if [ -f "$w/.prepared" ]; then continue; fi
    rm -rf "$w"; mkdir -p "$w/tree" "$w/tmp"
    rsync -a "$src/out/" "$w/out.pristine/"
    python3 -I - "$w/out.pristine" "$src" "$w" <<'PY'
import os, sys
root, old, new = sys.argv[1], sys.argv[2].encode(), sys.argv[3].encode()
files = links = 0
for d, dirs, fs in os.walk(root):
    dirs[:] = [x for x in dirs if x not in (".ailang", "node_modules")]
    for n in fs + [x for x in os.listdir(d) if os.path.islink(os.path.join(d, x)) and x not in fs]:
        p = os.path.join(d, n)
        if os.path.islink(p):
            t = os.readlink(p).encode()
            if t == old or t.startswith(old + b"/"):
                st = os.lstat(p); os.unlink(p); os.symlink(new + t[len(old):], p)
                os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns), follow_symlinks=False); links += 1
            continue
        if not os.path.isfile(p): continue
        b = open(p, "rb").read()
        if b"\0" in b[:8192] or old not in b: continue
        st = os.stat(p)
        open(p, "wb").write(b.replace(old, new))
        os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns)); files += 1
print(f"prepare {os.path.basename(sys.argv[2])}: {files} files and {links} symlinks rewritten")
PY
    rsync -a "$w/out.pristine/" "$w/out/"      # once, with the session's .ailang/ caches
    touch "$w/.prepared"
  done
}

run_py() { # the runner and the classifier
  python3 -I - "$@" <<'PY'
import csv, json, os, signal, subprocess, sys, time, threading, itertools, datetime, shutil
csv.field_size_limit(10**9)
ADJ, ROOT = os.environ["ADJ"], os.environ["ROOT"]
SEEDS = os.environ["SEEDS"].split(); SESSIONS = os.environ["SESSIONS"].split()
PLANTER = os.environ["PLANTER"]
mode = sys.argv[1]; jobs = int(sys.argv[2]) if len(sys.argv) > 2 else 3
LIMIT_S, CAP, FLOOR = 120, 6 * 1024**3, 3 * 1024**3
PATH = "/home/motoko/.local/bin:/home/motoko/.bun/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
RES = os.path.join(ADJ, "results"); os.makedirs(RES, exist_ok=True)
DB = os.path.join(RES, "runs.jsonl")
lock = threading.Lock()

def utc(): return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def reports():
    out = []
    for s in SESSIONS:
        rows = list(csv.reader(open(f"{ROOT}/s/{s}/out/reports.tsv", encoding="utf-8"), delimiter="\t", quoting=csv.QUOTE_NONE))
        h = rows[0]
        for r in rows[1:]:
            d = dict(zip(h, r)); d["session"] = s; out.append(d)
    return out

def load():
    db = {}
    if os.path.exists(DB):
        for line in open(DB):
            r = json.loads(line); db.setdefault((r["session"], r["report_id"], r["variant"]), []).append(r)
    return db

def mem_available():
    for l in open("/proc/meminfo"):
        if l.startswith("MemAvailable:"): return int(l.split()[1]) * 1024
    return 1 << 62

def group_rss(sid):
    tot = 0
    for p in os.listdir("/proc"):
        if not p.isdigit(): continue
        try:
            st = open(f"/proc/{p}/stat").read()
            f = st[st.rfind(")") + 2:].split()
            if f[0] == "Z" or int(f[3]) != sid: continue   # field 6 (session id) after state, ppid, pgrp
            tot += int(f[21]) * 4096                       # rss in pages
        except (OSError, IndexError, ValueError):
            pass
    return tot

def kill_session(sid):
    for p in os.listdir("/proc"):
        if not p.isdigit(): continue
        try:
            st = open(f"/proc/{p}/stat").read(); f = st[st.rfind(")") + 2:].split()
            if int(f[3]) == sid and f[0] != "Z": os.kill(int(p), signal.SIGKILL)
        except (OSError, IndexError, ValueError):
            pass

running = {}   # sid -> [rss, key]; for the floor
floor_killed = set()

def tree_of(variant):
    return os.path.join(ADJ, "trees", variant)

def restore(s, variant):
    w = os.path.join(ADJ, "work", s)
    for src, dst in ((tree_of(variant) + "/", w + "/tree/"), (w + "/out.pristine/", w + "/out/")):
        subprocess.run(["rsync", "-a", "--delete", "--exclude=.ailang/", src, dst], check=True)
    shutil.rmtree(w + "/tmp", ignore_errors=True); os.makedirs(w + "/tmp")

def run_one(rep, variant, tag):
    s = rep["session"]; w = os.path.join(ADJ, "work", s)
    restore(s, variant)
    cmd = rep["repro"].replace(f"{ROOT}/s/{s}", w)
    env = {"PATH": PATH, "HOME": "/home/motoko", "USER": "motoko", "LOGNAME": "motoko", "SHELL": "/bin/bash",
           "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "TERM": "xterm-256color", "TMPDIR": w + "/tmp"}
    logd = os.path.join(RES, s, rep["report_id"]); os.makedirs(logd, exist_ok=True)
    logf = os.path.join(logd, f"{variant}.{tag}.log")
    t0 = time.time(); peak = 0; status = None
    with open(logf, "wb") as lf:
        p = subprocess.Popen(["bash", "-c", cmd], cwd=w + "/tree", env=env, stdin=subprocess.DEVNULL,
                             stdout=lf, stderr=subprocess.STDOUT, start_new_session=True)
        with lock: running[p.pid] = [0, (s, rep["report_id"], variant)]
        while p.poll() is None:
            time.sleep(0.25)
            rss = group_rss(p.pid); peak = max(peak, rss)
            with lock:
                running[p.pid][0] = rss
                if p.pid in floor_killed: status = "floor"
            if status: kill_session(p.pid); break
            if time.time() - t0 > LIMIT_S: status = "timeout"; kill_session(p.pid); break
            if rss > CAP: status = "mem"; kill_session(p.pid); break
        rc = p.wait()
        kill_session(p.pid)                     # whatever it left running in its session
        with lock: running.pop(p.pid, None); floor_killed.discard(p.pid)
    wall = round(time.time() - t0, 2)
    if status is None: status = "exit"
    sz = os.path.getsize(logf)
    if sz > 2 * 1024**2:                        # keep the first and last MiB of a long log
        b = open(logf, "rb").read(); open(logf, "wb").write(b[:1024**2] + b"\n[... cut by adjudicate.sh ...]\n" + b[-1024**2:])
    r = {"session": s, "report_id": rep["report_id"], "variant": variant, "tag": tag, "status": status,
         "rc": rc, "wall_s": wall, "peak_rss_mib": peak // 2**20, "started": utc(), "jobs": jobs, "cmd": cmd}
    with lock:
        with open(DB, "a") as f: f.write(json.dumps(r) + "\n")
    print(f"{r['started']} {s} {rep['report_id']} {variant} {tag}: {status} rc={rc} {wall}s {peak // 2**20}MiB", flush=True)
    return r

def floor_watch(stop):
    while not stop.is_set():
        time.sleep(0.5)
        if mem_available() < FLOOR:
            with lock:
                c = [(v[0], pid) for pid, v in running.items() if pid not in floor_killed]
                if c: floor_killed.add(max(c)[1])

def outcome(r):
    if r["status"] == "exit" and r["rc"] in (0, 1): return str(r["rc"])
    return {"exit": f"E{r['rc']}", "timeout": "TO", "mem": "MEM", "floor": "FLOOR"}[r["status"]]

def final(db, key):
    """The result that counts for one (session, report, variant): the solo re-run if there is one."""
    rs = [r for r in db.get(key, []) if r["tag"] in ("p", "solo")]
    if not rs: return None
    solo = [r for r in rs if r["tag"] == "solo"]
    return outcome(solo[-1] if solo else rs[-1])

def confirm(db, key):
    rs = [r for r in db.get(key, []) if r["tag"] == "confirm"]
    return outcome(rs[-1]) if rs else None

def pool(tasks, jobs, tag):
    """tasks: list of (rep, variant). One worker per session at a time; up to `jobs` sessions."""
    by = {}
    for rep, v in tasks: by.setdefault(rep["session"], []).append((rep, v))
    q = list(by.items()); qlock = threading.Lock()
    def worker():
        while True:
            with qlock:
                if not q: return
                s, items = q.pop(0)
            for rep, v in items:
                while mem_available() < FLOOR + CAP // 2: time.sleep(2)
                run_one(rep, v, tag)
    stop = threading.Event(); fw = threading.Thread(target=floor_watch, args=(stop,), daemon=True); fw.start()
    ts = [threading.Thread(target=worker) for _ in range(min(jobs, len(q)))]
    for t in ts: t.start()
    for t in ts: t.join()
    stop.set()

VARIANTS = ["T", "B0"] + [f"T-{s}" for s in SEEDS]

def do_run():
    reps = reports(); db = load()
    # Within a session, tree by tree: T for every report first, then B0, then each T−s.
    todo = [(r, v) for v in VARIANTS for r in reps if (r["session"], r["report_id"], v) not in db]
    print(f"run: {len(reps)} reports x {len(VARIANTS)} trees; {len(todo)} runs to do, {jobs} sessions at once", flush=True)
    pool(todo, jobs, "p")
    db = load()   # timeouts and floor kills: once more, alone
    again = [(r, v) for r in reps for v in VARIANTS
             if (lambda rs: rs and rs[-1]["status"] in ("timeout", "floor") and not any(x["tag"] == "solo" for x in rs))(
                 [x for x in db.get((r["session"], r["report_id"], v), []) if x["tag"] in ("p", "solo")])]
    print(f"run: {len(again)} runs again, alone", flush=True)
    pool(again, 1, "solo")
    db = load()   # confirmations: T, and every tree whose result would decide a detection or real vs interaction
    conf = []
    for r in reps:
        k = lambda v: (r["session"], r["report_id"], v)
        if final(db, k("T")) != "1": continue
        dec = [v for v in VARIANTS[2:] if final(db, k(v)) == "0"] + ["B0"]
        for v in ["T"] + dec:
            if confirm(db, k(v)) is None: conf.append((r, v))
    print(f"run: {len(conf)} confirmation runs", flush=True)
    pool(conf, jobs, "confirm")

def stable(db, key):
    """The counted outcome, and whether its confirmation (if any) agrees."""
    f = final(db, key); c = confirm(db, key)
    return f, (c is None or c == f)

def pair_trees(a, b):
    name = f"T-{a}-{b}"; d = tree_of(name)
    if not os.path.isdir(d):
        tmp = d + ".tmp"; shutil.rmtree(tmp, ignore_errors=True)
        subprocess.run(["cp", "-a", tree_of(f"T-{a}"), tmp], check=True)
        subprocess.run(["patch", "-R", "-p1", "-s", "-f", "--no-backup-if-mismatch", "-i", f"{PLANTER}/seeds/{b}.patch"], cwd=tmp, check=True)
        os.rename(tmp, d)
    return name

def classify(db, r):
    k = lambda v: (r["session"], r["report_id"], v)
    T, Tok = stable(db, k("T")); B0, B0ok = stable(db, k("B0"))
    res = {v: final(db, k(v)) for v in VARIANTS}
    notes = []
    if T is None: return "not run", [], res, notes
    if T not in ("0", "1"): return "error", [], res, notes
    if T == "0": return "false report", [], res, notes
    if not Tok: notes.append("T's confirmation run differs"); return "unstable", [], res, notes
    det = [s for s in SEEDS if res[f"T-{s}"] == "0"]
    unstable = [s for s in det if not stable(db, k(f"T-{s}"))[1]]
    if unstable: notes.append("confirmation differs on " + ",".join("T-" + s for s in unstable))
    det = [s for s in det if s not in unstable]
    errs = [v for v in VARIANTS[2:] if res[v] not in ("0", "1")]
    if errs: notes.append("errors on " + ",".join(errs))
    if det:
        if B0 == "1": notes.append("also exits 1 on B0")
        return "detects", det, res, notes
    if not B0ok: notes.append("B0's confirmation run differs"); return "unstable", [], res, notes
    if B0 is None: return "not run", [], res, notes
    if B0 == "1": return "real defect", [], res, notes
    if B0 == "0" or B0 not in ("0", "1"):
        pairs = [tuple(sorted((a, b))) for a, b in itertools.combinations(SEEDS, 2)
                 if final(db, k(f"T-{a}-{b}")) == "0"]
        if B0 != "0": notes.append(f"B0 gave {B0}")
        if pairs: return "detects (pair)", sorted({x for p in pairs for x in p}), res, notes + ["pairs " + " ".join("+".join(p) for p in pairs)]
        if any(final(db, k(f"T-{a}-{b}")) is None for a, b in itertools.combinations(SEEDS, 2)):
            return "interaction: pairs not run", [], res, notes
        return ("false report" if B0 == "0" else "unclassified"), [], res, notes + ["no single seed or pair explains it"]

def do_pairs():
    reps = reports(); db = load(); todo = []
    for r in reps:
        c = classify(db, r)[0]
        if c in ("interaction: pairs not run",):
            for a, b in itertools.combinations(SEEDS, 2):
                v = pair_trees(a, b)
                if (r["session"], r["report_id"], v) not in db: todo.append((r, v))
    print(f"pairs: {len(todo)} runs", flush=True)
    pool(todo, jobs, "p")
    db = load()
    again = [(r, v) for (r, v) in todo if (lambda rs: rs and rs[-1]["status"] in ("timeout", "floor"))(
        [x for x in db.get((r["session"], r["report_id"], v), []) if x["tag"] in ("p", "solo")])]
    print(f"pairs: {len(again)} runs again, alone", flush=True)
    pool(again, 1, "solo")

def do_table():
    reps = reports(); db = load()
    man = {row["id"]: row for row in csv.DictReader(open(f"{PLANTER}/manifest.tsv", encoding="utf-8"), delimiter="\t")}
    cols = ["session", "arm", "rep", "target", "report_id", "property", "route", "T", "B0"] + [f"T-{s}" for s in SEEDS] + \
           ["class", "seeds", "seed_classes", "notes"]
    with open(os.path.join(ADJ, "table.tsv"), "w") as f:
        f.write("\t".join(cols) + "\n")
        for r in reps:
            c, det, res, notes = classify(db, r)
            s = r["session"]; arm, rep_ = s[-2].upper(), s[-1]
            row = [s, arm, rep_, "T" + s[5], r["report_id"], r["property"], r["route"], res["T"] or "-", res["B0"] or "-"] + \
                  [res[f"T-{x}"] or "-" for x in SEEDS] + [c, ",".join(det), ",".join(man[x]["class"] for x in det), "; ".join(notes)]
            f.write("\t".join(row) + "\n")
    print(open(os.path.join(ADJ, "table.tsv")).read().count("\n") - 1, "rows in", os.path.join(ADJ, "table.tsv"))
    # summary.tsv: per session, then per arm replicate (its six sessions, one per target), then per
    # arm (the mean of its two replicates, §10). A seed counts once per session however many of the
    # session's reports detect it (§8, "same defect ... for seeds, the same seed").
    classes = ["S1", "S2", "S3", "S4", "E"]
    rows = {}
    for r in reps:
        c, det, res, notes = classify(db, r)
        a = rows.setdefault(r["session"], {"seeds": set(), "reports": 0, "false": 0, "error": 0, "real": 0,
                                           "interaction": 0, "unstable": 0, "other": 0})
        a["reports"] += 1
        if c in ("detects", "detects (pair)"): a["seeds"].update(det)
        elif c == "false report": a["false"] += 1
        elif c == "error": a["error"] += 1
        elif c == "real defect": a["real"] += 1
        elif c.startswith("interaction") or c == "unclassified": a["interaction"] += 1
        elif c == "unstable": a["unstable"] += 1
        else: a["other"] += 1
    def counts(seeds):
        return [sum(1 for x in seeds if man[x]["class"] == k) for k in classes]
    head = ["unit", "reports"] + [f"D({k})" for k in classes] + ["seeds", "false", "error", "real", "interaction", "unstable", "other"]
    out = ["\t".join(head)]
    for s in SESSIONS:
        a = rows[s]
        out.append("\t".join(map(str, [s, a["reports"]] + counts(a["seeds"]) + [",".join(sorted(a["seeds"])),
                   a["false"], a["error"], a["real"], a["interaction"], a["unstable"], a["other"]])))
    rep_tot = {}
    for arm in "ab":
        for i in "12":
            ss = [f"t043-t{t}-{arm}{i}" for t in "123456"]
            seeds = set().union(*(rows[s]["seeds"] for s in ss))
            tot = {k: sum(rows[s][k] for s in ss) for k in ("reports", "false", "error", "real", "interaction", "unstable", "other")}
            rep_tot[arm + i] = (counts(seeds), tot)
            out.append("\t".join(map(str, [f"{arm.upper()}{i}", tot["reports"]] + counts(seeds) + [",".join(sorted(seeds)),
                       tot["false"], tot["error"], tot["real"], tot["interaction"], tot["unstable"], tot["other"]])))
    for arm in "ab":
        c1, t1 = rep_tot[arm + "1"]; c2, t2 = rep_tot[arm + "2"]
        mean = [(x + y) / 2 for x, y in zip(c1, c2)]
        out.append("\t".join(map(str, [f"{arm.upper()} mean", (t1["reports"] + t2["reports"]) / 2] + mean + ["",
                   (t1["false"] + t2["false"]) / 2, (t1["error"] + t2["error"]) / 2, (t1["real"] + t2["real"]) / 2,
                   (t1["interaction"] + t2["interaction"]) / 2, (t1["unstable"] + t2["unstable"]) / 2, (t1["other"] + t2["other"]) / 2])))
    open(os.path.join(ADJ, "summary.tsv"), "w").write("\n".join(out) + "\n")
    # runs.tsv: every run, without its command (the command is the report's, with the path rewrite)
    keys = ["session", "report_id", "variant", "tag", "status", "rc", "wall_s", "peak_rss_mib", "started", "jobs"]
    with open(os.path.join(ADJ, "runs.tsv"), "w") as f:
        f.write("\t".join(keys) + "\n")
        for line in open(DB):
            r = json.loads(line); f.write("\t".join(str(r[k]) for k in keys) + "\n")
    print("summary.tsv and runs.tsv written")

{"run": do_run, "pairs": do_pairs, "table": do_table}[mode]()
PY
}

case "${1:-}" in
  check) check ;;
  build) build ;;
  prepare) prepare ;;
  run) run_py run "${2:-3}" ;;
  pairs) run_py pairs "${2:-3}" ;;
  table) run_py table ;;
  all) check; build; prepare; run_py run "${2:-3}"; run_py pairs "${2:-3}"; run_py table; check ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
