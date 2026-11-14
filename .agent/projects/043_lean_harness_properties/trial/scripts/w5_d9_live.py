#!/usr/bin/env python3
"""W5 follow-up: D9 in a live Motoko session (the operator's request, sequence.log 19:5xZ).

    w5_d9_live.py <live dir> <label> <project dir> <session id> headless "<task>"
    w5_d9_live.py <live dir> <label> <project dir> <session id> tty [seconds]

<live dir> holds motoko/ (a copy of a trial tree, with src/tui/node_modules), profile/config.json
and provider/fake_openai.ts. The host is the real one, `bun src/tui/src/index.ts`, run from
motoko/ (so its journal and logs stay in that copy) with WORKDIR=<project dir>,
MOTOKO_CONFIG=<live dir>/profile and MOTOKO_SESSION_ID=<session id>. Its model provider is the
fake OpenAI-compatible endpoint on 127.0.0.1:18732; nothing leaves the machine.

  headless  `index.ts --headless <task>`: one task, run to completion (stdin is /dev/null).
  tty       `index.ts` with no task, under a pseudo-terminal (120x40): a host started on a session
            that has a journal resumes it at once (respawnForRestart, `--resume <journal>`). Its
            screen output is recorded for [seconds] (default 120), then it is stopped.

The environment is the arms' clean one (PATH, HOME, USER, LOGNAME, SHELL, LANG, LC_ALL, TERM,
TMPDIR) plus those three variables and OPENAI_API_KEY=w5-fake-key. Limits: the run's wall time;
every process working in <live dir> is watched, and the run is stopped if they pass 6 GiB
resident together. Afterwards every process working in <live dir> is ended (zombies, which this
container's PID 1 never reaps, are skipped). Writes <live dir>/logs/<label>.*.
"""
import os, sys, time, signal, subprocess, json, pty, fcntl, termios, struct, select

LIVE, LABEL, PROJECT, SID, MODE = sys.argv[1:6]
EXTRA = sys.argv[6:]
LOGS = os.path.join(LIVE, "logs"); os.makedirs(LOGS, exist_ok=True)
TMP = os.path.join(LIVE, "tmp"); os.makedirs(TMP, exist_ok=True)
MOTOKO = os.path.join(LIVE, "motoko")
CAP = 6 * 1024**3
PATHV = "/home/motoko/.local/bin:/home/motoko/.bun/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV = {"PATH": PATHV, "HOME": "/home/motoko", "USER": "motoko", "LOGNAME": "motoko", "SHELL": "/bin/bash",
       "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "TERM": "xterm-256color", "TMPDIR": TMP,
       "WORKDIR": PROJECT, "MOTOKO_CONFIG": os.path.join(LIVE, "profile"), "MOTOKO_SESSION_ID": SID,
       "OPENAI_API_KEY": "w5-fake-key"}

def utc(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def ancestors():
    """This driver and the processes that started it, which name LIVE in their own command lines."""
    out, p = set(), os.getpid()
    while p > 1:
        out.add(p)
        try:
            st = open(f"/proc/{p}/stat").read(); p = int(st[st.rfind(")") + 2:].split()[1])
        except (OSError, IndexError, ValueError):
            break
    return out

SELF = ancestors()

def procs_in_live():
    """(pid, state, rss bytes, cmdline) of every process whose cwd or cmdline is under LIVE."""
    out = []
    for p in os.listdir("/proc"):
        if not p.isdigit() or int(p) in SELF: continue
        try:
            st = open(f"/proc/{p}/stat").read(); f = st[st.rfind(")") + 2:].split()
            cmd = open(f"/proc/{p}/cmdline", "rb").read().replace(b"\0", b" ").decode(errors="replace")
            try: cwd = os.readlink(f"/proc/{p}/cwd")
            except OSError: cwd = ""
            if cwd.startswith(LIVE) or LIVE in cmd:
                out.append((int(p), f[0], int(f[21]) * 4096, cmd.strip()))
        except (OSError, IndexError, ValueError):
            pass
    return out

def end_all(note):
    for sig in (signal.SIGTERM, signal.SIGKILL):
        live = [x for x in procs_in_live() if x[1] != "Z"]
        for pid, _, _, _ in live:
            try: os.kill(pid, sig)
            except OSError: pass
        if live: time.sleep(2)
    left = [x for x in procs_in_live() if x[1] != "Z"]
    note(f"after the run: {len(left)} live processes left in {LIVE}")

def main():
    meta = open(os.path.join(LOGS, f"{LABEL}.meta.txt"), "w")
    note = lambda s: (meta.write(f"{utc()} {s}\n"), meta.flush(), print(f"{utc()} {s}", flush=True))
    pre = [x for x in procs_in_live() if x[1] != "Z"]
    if pre:
        note(f"refusing to start: {len(pre)} processes already work in {LIVE}: {[x[3][:80] for x in pre]}"); sys.exit(2)
    prov_env = dict(ENV, FAKE_PORT="18732", FAKE_LOG=os.path.join(LOGS, f"{LABEL}.provider.jsonl"))
    prov = subprocess.Popen(["bun", os.path.join(LIVE, "provider", "fake_openai.ts")], cwd=os.path.join(LIVE, "provider"),
                            env=prov_env, stdin=subprocess.DEVNULL, stdout=open(os.path.join(LOGS, f"{LABEL}.provider.out"), "wb"),
                            stderr=subprocess.STDOUT, start_new_session=True)
    time.sleep(1.5)
    note(f"label={LABEL} mode={MODE} project={PROJECT} session={SID} extra={EXTRA}")
    t0 = time.time(); peak = 0; status = "exit"; rc = None
    if MODE == "headless":
        limit = 300
        p = subprocess.Popen(["bun", "src/tui/src/index.ts", "--headless", EXTRA[0]], cwd=MOTOKO, env=ENV,
                             stdin=subprocess.DEVNULL, stdout=open(os.path.join(LOGS, f"{LABEL}.stdout"), "wb"),
                             stderr=open(os.path.join(LOGS, f"{LABEL}.stderr"), "wb"), start_new_session=True)
        while p.poll() is None:
            time.sleep(0.5)
            rss = sum(x[2] for x in procs_in_live() if x[1] != "Z" and x[0] != prov.pid); peak = max(peak, rss)
            if rss > CAP: status = "mem"; break
            if time.time() - t0 > limit: status = "timeout"; break
        rc = p.poll()
    elif MODE == "tty":
        limit = int(EXTRA[0]) if EXTRA else 120
        pid, fd = pty.fork()
        if pid == 0:
            os.chdir(MOTOKO)
            os.execvpe("bun", ["bun", "src/tui/src/index.ts"], ENV)
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        screen = open(os.path.join(LOGS, f"{LABEL}.tty"), "wb")
        while time.time() - t0 < limit:
            r, _, _ = select.select([fd], [], [], 0.5)
            if r:
                try: data = os.read(fd, 65536)
                except OSError: break
                if not data: break
                screen.write(data); screen.flush()
            rss = sum(x[2] for x in procs_in_live() if x[1] != "Z" and x[0] != prov.pid); peak = max(peak, rss)
            if rss > CAP: status = "mem"; break
            done, _ = os.waitpid(pid, os.WNOHANG)
            if done: rc = 0; break
        else:
            status = "stopped at its time limit, as planned"
        for ch in (b"\x03", b"\x03"):
            try: os.write(fd, ch)
            except OSError: pass
            time.sleep(1)
    note(f"host: status={status} rc={rc} wall={time.time() - t0:.1f}s peak_rss={peak // 2**20}MiB")
    end_all(note)
    try: os.killpg(prov.pid, signal.SIGKILL)
    except OSError: pass

main()
