# PLAN-001 W2 deviation: keep the machine responsive while arm sessions run. On 2026-11-04 eight
# sessions froze the container (its swap is zram, which thrashes instead of letting the kernel
# kill one process). Every second: kill any process an arm session started (a descendant of an
# arm's Claude Code, never Claude Code itself) whose RSS is over CAP; and while MemAvailable is
# under FLOOR, kill the largest such process. Each kill is logged; the arm sees its command
# killed, as under an out-of-memory kill. The same rule holds for both arms.
#   python3 -I memwatch.py [--dry]
import os, sys, time
ROOT = "/home/motoko/trial-043"
LOG = ROOT + "/collect/memwatch.log"
FLOOR, CAP = 3 * 2**30, 6 * 2**30
PAGE = os.sysconf("SC_PAGE_SIZE")
MARK = "--add-dir " + ROOT + "/s/"

def available():
    for l in open("/proc/meminfo"):
        if l.startswith("MemAvailable:"): return int(l.split()[1]) * 1024

def procs():
    out = {}
    for p in os.listdir("/proc"):
        if not p.isdigit(): continue
        try:
            st = open(f"/proc/{p}/stat").read()
            ppid = int(st.rsplit(")", 1)[1].split()[1])
            rss = int(open(f"/proc/{p}/statm").read().split()[1]) * PAGE
            cmd = open(f"/proc/{p}/cmdline", "rb").read().replace(b"\0", b" ").decode(errors="replace").strip()
        except Exception: continue
        out[int(p)] = (ppid, rss, cmd)
    return out

def session_of(pid, ps):
    p, hops = ps[pid][0], 0
    while p in ps and hops < 64:
        cmd = ps[p][2]
        if cmd.startswith("claude ") and MARK in cmd: return cmd.split(MARK, 1)[1].split("/", 1)[0]
        p, hops = ps[p][0], hops + 1
    return None

def candidates():
    ps = procs()
    for pid, (ppid, rss, cmd) in ps.items():
        if cmd.startswith("claude ") or pid == os.getpid(): continue
        s = session_of(pid, ps)
        if s: yield rss, pid, s, cmd

def log(reason, rss, pid, s, cmd):
    line = (f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} {reason} killed {s} pid={pid} "
            f"rss={rss / 2**30:.2f}GiB avail={available() / 2**30:.2f}GiB cmd={cmd[:200]}")
    with open(LOG, "a") as f: f.write(line + "\n")

if "--dry" in sys.argv:
    for rss, pid, s, cmd in sorted(candidates(), reverse=True)[:12]:
        print(f"{rss / 2**20:8.0f} MiB {pid} {s} {cmd[:90]}")
    print(f"available {available() / 2**30:.2f} GiB"); sys.exit(0)

with open(LOG, "a") as f: f.write(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()) + f" memwatch started pid={os.getpid()} floor=3GiB cap=6GiB\n")
while True:
    try:
        c = sorted(candidates(), reverse=True)
        for rss, pid, s, cmd in c:
            if rss > CAP:
                try: os.kill(pid, 9); log("cap", rss, pid, s, cmd)
                except ProcessLookupError: pass
        if c and available() < FLOOR:
            rss, pid, s, cmd = max((x for x in candidates()), default=(0, 0, "", ""))
            if pid:
                try: os.kill(pid, 9); log("floor", rss, pid, s, cmd)
                except ProcessLookupError: pass
    except Exception as e:
        with open(LOG, "a") as f: f.write(f"error {e!r}\n")
    time.sleep(1)
