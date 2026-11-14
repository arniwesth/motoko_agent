#!/usr/bin/env python3
"""W5: run chosen reproductions on chosen trees, under adjudicate.sh's conventions (PLAN-001 §8).

    w5_rerun.py <work> <runs.tsv> <jobs> <variant>=<tree> [<variant>=<tree> ...]

<runs.tsv> has a header and the columns session, report_id, variant. Each listed run is made
twice: a first run ("p") and a confirmation ("confirm"). A run stopped at the memory floor or by
the time limit is made once more alone ("solo"), and that result replaces the first.

What is copied from adjudicate.sh (sha256 5b2eaad9..., as it ran at W4), unchanged in effect:
  - prepare(): session S gets <work>/work/S/{tree,out,tmp}; out.pristine is a copy of
    /home/motoko/trial-043/s/S/out in which "/home/motoko/trial-043/s/S" becomes
    "<work>/work/S", in text files outside .ailang/ and node_modules/ and in symlink targets.
  - run_one(): before each run, tree/ is restored from the variant's tree and out/ from
    out.pristine with rsync --delete (keeping .ailang/), tmp/ is emptied; the command has the
    same rewrite; the environment is the arms' PATH, HOME, USER, LOGNAME, SHELL, LANG=LC_ALL=
    C.UTF-8, TERM and TMPDIR; 120 s wall clock for the process group; a process group over
    6 GiB resident is killed ("mem", an error); below 3 GiB available, the largest running
    reproduction is killed and queued again ("floor"). Exit 0 or 1 is a result; anything else
    is an error.
Reads the session's output directory; writes only under <work>.
"""
import csv, json, os, signal, subprocess, sys, time, threading, datetime, shutil
csv.field_size_limit(10**9)
ROOT = "/home/motoko/trial-043"
WORK, RUNS, JOBS = sys.argv[1], sys.argv[2], int(sys.argv[3])
TREES = dict(a.split("=", 1) for a in sys.argv[4:])
LIMIT_S, CAP, FLOOR = 120, 6 * 1024**3, 3 * 1024**3
PATH = "/home/motoko/.local/bin:/home/motoko/.bun/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
RES = os.path.join(WORK, "results"); os.makedirs(RES, exist_ok=True)
DB = os.path.join(RES, "runs.jsonl")
lock = threading.Lock()

def utc(): return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def reports():
    out = {}
    for s in sorted({r["session"] for r in csv.DictReader(open(RUNS), delimiter="\t")}):
        rows = list(csv.reader(open(f"{ROOT}/s/{s}/out/reports.tsv", encoding="utf-8"), delimiter="\t", quoting=csv.QUOTE_NONE))
        h = rows[0]
        for r in rows[1:]:
            d = dict(zip(h, r)); d["session"] = s; out[(s, d["report_id"])] = d
    return out

def prepare(s):
    w = os.path.join(WORK, "work", s); src = f"{ROOT}/s/{s}"
    if os.path.exists(os.path.join(w, ".prepared")): return
    shutil.rmtree(w, ignore_errors=True); os.makedirs(w + "/tree"); os.makedirs(w + "/tmp")
    subprocess.run(["rsync", "-a", src + "/out/", w + "/out.pristine/"], check=True)
    root, old, new = w + "/out.pristine", src.encode(), w.encode()
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
    subprocess.run(["rsync", "-a", w + "/out.pristine/", w + "/out/"], check=True)
    open(os.path.join(w, ".prepared"), "w").write(utc() + "\n")
    print(f"prepare {s}: {files} files and {links} symlinks rewritten", flush=True)

def mem_available():
    for l in open("/proc/meminfo"):
        if l.startswith("MemAvailable:"): return int(l.split()[1]) * 1024
    return 1 << 62

def group_rss(sid):
    tot = 0
    for p in os.listdir("/proc"):
        if not p.isdigit(): continue
        try:
            st = open(f"/proc/{p}/stat").read(); f = st[st.rfind(")") + 2:].split()
            if f[0] == "Z" or int(f[3]) != sid: continue
            tot += int(f[21]) * 4096
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

running = {}; floor_killed = set()

def restore(s, variant):
    w = os.path.join(WORK, "work", s)
    for src, dst in ((TREES[variant] + "/", w + "/tree/"), (w + "/out.pristine/", w + "/out/")):
        subprocess.run(["rsync", "-a", "--delete", "--exclude=.ailang/", src, dst], check=True)
    shutil.rmtree(w + "/tmp", ignore_errors=True); os.makedirs(w + "/tmp")

def run_one(rep, variant, tag):
    s = rep["session"]; w = os.path.join(WORK, "work", s)
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
        kill_session(p.pid)
        with lock: running.pop(p.pid, None); floor_killed.discard(p.pid)
    wall = round(time.time() - t0, 2)
    if status is None: status = "exit"
    sz = os.path.getsize(logf)
    if sz > 2 * 1024**2:
        b = open(logf, "rb").read(); open(logf, "wb").write(b[:1024**2] + b"\n[... cut by w5_rerun.py ...]\n" + b[-1024**2:])
    r = {"session": s, "report_id": rep["report_id"], "variant": variant, "tag": tag, "status": status,
         "rc": rc, "wall_s": wall, "peak_rss_mib": peak // 2**20, "started": utc(), "jobs": JOBS, "cmd": cmd}
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

def pool(tasks, jobs, tag):
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

def load():
    db = {}
    if os.path.exists(DB):
        for line in open(DB):
            r = json.loads(line); db.setdefault((r["session"], r["report_id"], r["variant"]), []).append(r)
    return db

def main():
    reps = reports()
    wanted = [(reps[(r["session"], r["report_id"])], r["variant"]) for r in csv.DictReader(open(RUNS), delimiter="\t")]
    for s in sorted({rep["session"] for rep, _ in wanted}): prepare(s)
    db = load()
    todo = [(rep, v) for rep, v in wanted if not any(x["tag"] == "p" for x in db.get((rep["session"], rep["report_id"], v), []))]
    print(f"w5_rerun: {len(wanted)} runs listed, {len(todo)} to do, {JOBS} sessions at once", flush=True)
    pool(todo, JOBS, "p")
    db = load()
    again = [(rep, v) for rep, v in wanted
             if (lambda rs: rs and rs[-1]["status"] in ("timeout", "floor") and not any(x["tag"] == "solo" for x in rs))(
                 [x for x in db.get((rep["session"], rep["report_id"], v), []) if x["tag"] in ("p", "solo")])]
    print(f"w5_rerun: {len(again)} runs again, alone", flush=True)
    pool(again, 1, "solo")
    db = load()
    conf = [(rep, v) for rep, v in wanted if not any(x["tag"] == "confirm" for x in db.get((rep["session"], rep["report_id"], v), []))]
    print(f"w5_rerun: {len(conf)} confirmation runs", flush=True)
    pool(conf, JOBS, "confirm")
    print("w5_rerun: done", flush=True)

main()
