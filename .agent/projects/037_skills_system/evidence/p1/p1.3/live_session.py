#!/usr/bin/env python3
"""037 P1.3b-e: run ONE headless session of the real runtime under `skills_proto`.

The command line and the `env -i` allowlist are P1.2's / P1.3a's (the TUI's
`buildChildEnv` and spawn, built by hand), with three differences:

  * the provider is real: `--ai` and `--model` are `openrouter/<vendor>/<model>`
    and OPENROUTER_API_KEY plus the egress-proxy variables are forwarded from this
    process's environment (as `buildChildEnv` forwards them). The key is never
    written: every line of the child's stdout/stderr is scrubbed of its value
    before it reaches disk.
  * PATH starts with ./stubs, so `gh` and `herdr` cannot act, and HOME is a
    scratch directory whose .profile keeps ./stubs first under `bash -lc`
    (build_home.sh). ~/.ailang is linked into it.
  * the launch directory is a disposable copy of the worktree (build_launch.sh),
    because an in-process BashExec runs in the launch directory.

Layout 1 only: the workdir is outside the launch directory and `--workdir` is absolute.

Before the session the workdir is rebuilt from its template (rsync --delete), so
every session starts from the same bytes. After it, what the session wrote into
the workdir and the launch directory is recorded, then the launch directory is
restored.

Spend: the session's token usage (run_summary, else the sum of `thinking`
events) is priced at list price from prices.json and appended to spend.tsv. A
session is refused when the running total plus --reserve would pass --cap, and
killed when its own running cost passes --session-cap.

  live_session.py --row b --label L --out DIR --template TPL --workdir WD \
      --model openrouter/deepseek/deepseek-v4-flash --task "..." [--recorder SCRIPT.json]
"""
import argparse, json, os, shutil, signal, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
WORKTREE = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
LEDGER = os.path.join(HERE, "spend.tsv")
PRICES = json.load(open(os.path.join(HERE, "prices.json")))
LEDGER_HEAD = "utc\trow\tlabel\tmodel\tsteps\tinput_tokens\toutput_tokens\tcache_read_tokens\tlist_cost_usd\trunning_total_usd\tnote\n"


def price(model, tin, tout):
    key = model[len("openrouter/"):] if model.startswith("openrouter/") else model
    p = PRICES.get(key)
    if p is None:
        return 0.0
    return tin * p["in"] / 1e6 + tout * p["out"] / 1e6


def ledger_total():
    if not os.path.exists(LEDGER):
        return 0.0
    tot = 0.0
    for line in open(LEDGER).read().splitlines()[1:]:
        f = line.split("\t")
        if len(f) > 8:
            tot += float(f[8])
    return tot


def ledger_add(row, label, model, steps, tin, tout, cache, cost, note=""):
    new = not os.path.exists(LEDGER)
    tot = ledger_total() + cost
    with open(LEDGER, "a") as f:
        if new:
            f.write(LEDGER_HEAD)
        f.write("%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%.6f\t%.6f\t%s\n" % (
            time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), row, label, model, steps, tin, tout, cache, cost, tot, note))
    return tot


# The key's usage counter when phase 2 started (key_usage.tsv, first line). The
# models endpoint lists one price per model, but OpenRouter routes a request to
# any of several providers whose prices differ several-fold (see results/
# endpoints-2026-10-04.txt), so the list-price ledger can understate the charge.
# The counter is the upper bound on what these sessions really cost: it also
# counts every other session on the key.
KEY_BASELINE = 63.569876129


def key_delta():
    try:
        import urllib.request
        req = urllib.request.Request("https://openrouter.ai/api/v1/key",
                                     headers={"Authorization": "Bearer " + os.environ["OPENROUTER_API_KEY"]})
        with urllib.request.urlopen(req, timeout=30) as r:
            return float(json.load(r)["data"]["usage"]) - KEY_BASELINE
    except Exception:
        return None


def rsync(src, dst, extra=()):
    # --checksum: two templates built in the same second differ in one digit of
    # config.json (max_steps 3 vs 8), same size and mtime, and rsync's quick check
    # then keeps the stale file. Found on the first two stamp sessions (voided).
    return subprocess.run(["rsync", "-a", "--delete", "--checksum", *extra, src.rstrip("/") + "/", dst.rstrip("/") + "/"],
                          capture_output=True, text=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--row", required=True)
    ap.add_argument("--label", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--template", required=True)
    ap.add_argument("--workdir", required=True)
    ap.add_argument("--launch", default="/tmp/motoko-037-p1.3/launch")
    ap.add_argument("--home", default="/tmp/motoko-037-p1.3/home")
    ap.add_argument("--model", required=True)
    ap.add_argument("--task", required=True)
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--cap", type=float, default=4.00)
    ap.add_argument("--reserve", type=float, default=0.05)
    ap.add_argument("--session-cap", type=float, default=0.10)
    ap.add_argument("--recorder", default="", help="script JSON: answer from the local recorder instead of a model (free)")
    ap.add_argument("--port", type=int, default=18441)
    a = ap.parse_args()

    a.out = os.path.abspath(a.out)
    os.makedirs(a.out, exist_ok=True)
    dry = a.recorder != ""
    if not dry:
        tot = ledger_total()
        if tot + a.reserve > a.cap:
            print("REFUSED: running total $%.4f + reserve $%.2f would pass the cap $%.2f" % (tot, a.reserve, a.cap))
            return 3
        if not os.environ.get("OPENROUTER_API_KEY"):
            print("REFUSED: OPENROUTER_API_KEY is not in the environment")
            return 3
        kd = key_delta()
        if kd is not None and kd + a.reserve > a.cap:
            print("REFUSED: the key's usage counter is $%.4f over the phase-2 baseline; with reserve $%.2f that would pass the cap $%.2f" % (kd, a.reserve, a.cap))
            return 3

    # 1. the workdir, from its template
    os.makedirs(a.workdir, exist_ok=True)
    r = rsync(a.template, a.workdir)
    if r.returncode != 0:
        print("workdir reset failed:", r.stderr)
        return 2

    stub_log = os.path.join(a.out, "stub_calls.log")
    env = {
        "PATH": os.path.join(HERE, "stubs") + ":" + os.environ["PATH"],
        # A scratch HOME (build_home.sh): BashExec runs `bash -lc`, and the real
        # ~/.profile puts ~/.local/bin, where the real `gh` is, ahead of ./stubs.
        "HOME": a.home,
        "AILANG_FS_SANDBOX": a.workdir,
        "AILANG_NO_VERSION_WARNINGS": "1",
        "MOTOKO_STREAM_EVENTS": "1",
        "MOTOKO_HEADLESS": "1",
        "MOTOKO_PROFILE_DIR": os.path.join(a.workdir, ".motoko", "config", "skills_proto"),
        "MOTOKO_JOURNAL_WORKDIR": a.workdir,
        "MOTOKO_SESSION_ID": "p1_3%s_%s_%d" % (a.row, a.label, int(time.time())),
        "MOTOKO_RESUME_COUNT": "0",
        "P13_STUB_LOG": stub_log,
    }
    secrets = []
    recorder = None
    if dry:
        env["OPENAI_API_KEY"] = "p1-capture-not-a-key"
        env["OPENAI_BASE_URL"] = "http://127.0.0.1:%d/v1" % a.port
        ai_arg, model_arg = "gpt5", "openai/p1-capture"
        for f in os.listdir(a.out):
            if f.startswith("req-") and f.endswith(".json"):
                os.remove(os.path.join(a.out, f))
        recorder = subprocess.Popen(
            [sys.executable, os.path.join(HERE, "..", "p1.3a", "capture_server.py"), a.out, str(a.port)],
            env=dict(os.environ, P13A_SCRIPT=os.path.abspath(a.recorder)),
            stdout=open(os.path.join(a.out, "server.log"), "w"), stderr=subprocess.STDOUT)
        time.sleep(1)
    else:
        key = os.environ["OPENROUTER_API_KEY"]
        secrets.append(key)
        env["OPENROUTER_API_KEY"] = key
        for k in ("HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy"):
            v = os.environ.get(k, "")
            if v.strip():
                env[k] = v
        ai_arg = model_arg = a.model

    cmd = ["ailang", "run",
           "--caps", "Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace",
           "--ai", ai_arg, "--entry", "main",
           "--net-allow-http", "--net-allow-localhost",
           "--stream-allow-http", "--stream-allow-localhost",
           "--max-recursion-depth", "1000000",
           "src/core/supervisor.ail", "--",
           "--profile", "skills_proto", "--model", model_arg, "--workdir", a.workdir, "--port", "8080",
           "--system-prompt", ".motoko-system-prompt.md", "--no-backend", a.task]

    marker = os.path.join(a.out, ".start_marker")
    open(marker, "w").close()
    time.sleep(0.05)
    started = time.time()
    with open(os.path.join(a.out, "session.txt"), "w") as f:
        f.write("label=%s\nrow=%s\nmodel=%s\nai_arg=%s\nlaunch_dir=%s\nworkdir=%s\ntemplate=%s\ndry_run_recorder=%s\ntask=%s\nstarted=%s\n" % (
            a.label, a.row, model_arg, ai_arg, a.launch, a.workdir, a.template, a.recorder or "<none: live model>", a.task,
            time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())))

    def scrub(s):
        for sec in secrets:
            if sec and sec in s:
                s = s.replace(sec, "[REDACTED-KEY]")
        return s

    out_path = os.path.join(a.out, "session.stdout.jsonl")
    err_f = open(os.path.join(a.out, "session.stderr.raw"), "w")
    proc = subprocess.Popen(cmd, cwd=a.launch, env=env, stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=err_f, text=True, errors="replace",
                            start_new_session=True)
    tin = tout = cache = 0
    steps = 0
    summary = None
    killed = ""
    deadline = started + a.timeout

    def on_alarm(signum, frame):
        raise TimeoutError()
    signal.signal(signal.SIGALRM, on_alarm)
    try:
        with open(out_path, "w") as out_f:
            signal.alarm(a.timeout)
            try:
                for line in proc.stdout:
                    out_f.write(scrub(line))
                    out_f.flush()
                    s = line.strip()
                    if not s.startswith("{"):
                        continue
                    try:
                        e = json.loads(s)
                    except ValueError:
                        continue
                    t = e.get("type")
                    if t == "thinking":
                        tin += int(e.get("input_tokens") or 0)
                        tout += int(e.get("output_tokens") or 0)
                        steps += 1
                        if not dry and price(a.model, tin, tout) > a.session_cap:
                            killed = "session-cap"
                            break
                    elif t == "run_summary":
                        summary = e
            except TimeoutError:
                killed = "timeout"
            finally:
                signal.alarm(0)
    finally:
        if proc.poll() is None:
            if killed:
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            try:
                proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait()
        err_f.close()
        if recorder is not None:
            recorder.terminate()
    rc = proc.returncode
    # stderr, scrubbed
    raw = os.path.join(a.out, "session.stderr.raw")
    with open(raw, errors="replace") as f, open(os.path.join(a.out, "session.stderr.log"), "w") as g:
        g.write(scrub(f.read()))
    os.remove(raw)

    if summary is not None:
        u = summary.get("usage", {})
        tin = int(u.get("input_tokens") or tin)
        tout = int(u.get("output_tokens") or tout)
        cache = int(u.get("cache_read_input_tokens") or 0)
        steps = summary.get("steps_executed", steps)
    cost = 0.0 if dry else price(a.model, tin, tout)

    # 2. what the session wrote
    wd_diff = subprocess.run(["diff", "-rq", a.template, a.workdir], capture_output=True, text=True).stdout
    open(os.path.join(a.out, "workdir_diff.txt"), "w").write(wd_diff)
    for where, root in (("workdir", a.workdir), ("launch", a.launch)):
        p = os.path.join(root, "STAMP.txt")
        if os.path.exists(p):
            shutil.copyfile(p, os.path.join(a.out, "STAMP.%s.txt" % where))
    lr = subprocess.run(["rsync", "-a", "--delete", "--itemize-changes",
                         "--exclude", "/.git", "--exclude", "/.motoko/herdr-delegates", "--exclude", "node_modules",
                         "--exclude", ".ailang/",
                         WORKTREE + "/", a.launch.rstrip("/") + "/"], capture_output=True, text=True)
    open(os.path.join(a.out, "launch_restore.txt"), "w").write(lr.stdout + lr.stderr)

    total = ledger_total() if dry else ledger_add(a.row, a.label, a.model, steps, tin, tout, cache, cost, killed)
    with open(os.path.join(a.out, "session.txt"), "a") as f:
        f.write("rc=%s\nkilled=%s\nwall_s=%.1f\nsteps=%s\ninput_tokens=%d\noutput_tokens=%d\ncache_read_tokens=%d\nlist_cost_usd=%.6f\nrunning_total_usd=%.6f\n" % (
            rc, killed or "no", time.time() - started, steps, tin, tout, cache, cost, total))
        f.write("finish_reason=%s\nerror=%s\n" % (
            (summary or {}).get("finish_reason"), json.dumps((summary or {}).get("error"))))
    print("[%s/%s] rc=%s%s steps=%s in=%d out=%d cost=$%.4f total=$%.4f wall=%.0fs finish=%s" % (
        a.row, a.label, rc, (" KILLED:" + killed) if killed else "", steps, tin, tout, cost, total,
        time.time() - started, (summary or {}).get("finish_reason")))
    return 0 if rc == 0 and not killed else 1


if __name__ == "__main__":
    sys.exit(main())
