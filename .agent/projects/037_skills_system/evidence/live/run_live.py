#!/usr/bin/env python3
"""037 live smoke: one headless session of the real runtime, on the final skills
package, against a real model. The command line and the `env -i` allowlist are
those of evidence/p1/p1.3/live_session.py; the profile is the committed `skills`
profile (copied into the fixture, max_steps 8). The key is read from the
environment, passed in the child's environment only, and replaced in everything
written to disk.

  run_live.py <label> <model>
"""
import json, os, subprocess, sys, time

S = os.path.dirname(os.path.abspath(__file__))
LAUNCH, HOME, TPL, WORK = (os.path.join(S, d) for d in ("launch", "home", "tpl", "work"))
TASK = "Stamp the working directory. We are freezing this workspace for the 0.9 release."
PRICES = {  # USD per million tokens, OpenRouter list, as fetched 2026-10-04
    "openrouter/deepseek/deepseek-v4-pro": (0.2088, 0.4176),
    "openrouter/meta/muse-spark-1.3-contributor": (0.10, 0.20),
}


def main():
    label, model = sys.argv[1], sys.argv[2]
    out = os.path.join(S, "out", label)
    os.makedirs(out, exist_ok=True)
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if not key:
        print("REFUSED: OPENROUTER_API_KEY is not in the environment")
        return 2
    r = subprocess.run(["rsync", "-a", "--delete", TPL + "/", WORK + "/"], capture_output=True, text=True)
    if r.returncode != 0:
        print("workdir reset failed:", r.stderr)
        return 2
    env = {
        "PATH": os.path.join(S, "stubs") + ":" + os.environ["PATH"],
        "HOME": HOME,
        "AILANG_FS_SANDBOX": WORK,
        "AILANG_NO_VERSION_WARNINGS": "1",
        "MOTOKO_STREAM_EVENTS": "1",
        "MOTOKO_HEADLESS": "1",
        "MOTOKO_PROFILE_DIR": os.path.join(WORK, ".motoko", "config", "skills"),
        "MOTOKO_JOURNAL_WORKDIR": WORK,
        "MOTOKO_SESSION_ID": "live_smoke_%s_%d" % (label, int(time.time())),
        "MOTOKO_RESUME_COUNT": "0",
        "P13_STUB_LOG": os.path.join(out, "stub_calls.log"),
        "OPENROUTER_API_KEY": key,
    }
    for k in ("HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy"):
        v = os.environ.get(k, "")
        if v.strip():
            env[k] = v
    cmd = ["ailang", "run",
           "--caps", "Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream,Trace",
           "--ai", model, "--entry", "main",
           "--net-allow-http", "--net-allow-localhost",
           "--stream-allow-http", "--stream-allow-localhost",
           "--max-recursion-depth", "1000000",
           "src/core/supervisor.ail", "--",
           "--profile", "skills", "--model", model, "--workdir", WORK, "--port", "8080",
           "--system-prompt", ".motoko-system-prompt.md", "--no-backend", TASK]
    started = time.time()
    try:
        p = subprocess.run(cmd, cwd=LAUNCH, env=env, stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, errors="replace", timeout=420)
        rc, so, se, killed = p.returncode, p.stdout, p.stderr, False
    except subprocess.TimeoutExpired as e:
        rc, killed = 124, True
        so = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        se = (e.stderr or b"").decode("utf-8", "replace") if isinstance(e.stderr, bytes) else (e.stderr or "")
    wall = time.time() - started
    scrub = lambda s: s.replace(key, "[REDACTED-KEY]")
    open(os.path.join(out, "session.stdout.jsonl"), "w").write(scrub(so))
    open(os.path.join(out, "session.stderr.log"), "w").write(scrub(se))

    ev = []
    for line in so.splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                ev.append(json.loads(line))
            except ValueError:
                pass
    calls = []
    for e in ev:
        if e.get("type") == "native_tool_calls":
            for c in e.get("tool_calls", []):
                calls.append((e.get("step"), c.get("tool"), c.get("arguments") or {}))
    tool_msgs = [(e.get("step"), (e["message"].get("content") or "")) for e in ev
                 if e.get("type") == "history_appended" and e.get("message", {}).get("role") == "tool"]
    tin = sum((e.get("input_tokens") or 0) for e in ev if e.get("type") == "thinking")
    tout = sum((e.get("output_tokens") or 0) for e in ev if e.get("type") == "thinking")
    pin, pout = PRICES.get(model, (0, 0))
    start = next((e for e in ev if e.get("type") == "session_start"), {})
    errors = [e for e in ev if e.get("type") == "error"]
    summ = next((e for e in reversed(ev) if e.get("type") == "run_summary"), {})
    stamp_path = os.path.join(WORK, "STAMP.txt")
    stamp = open(stamp_path).read().strip() if os.path.exists(stamp_path) else None
    diff = subprocess.run(["diff", "-rq", TPL, WORK], capture_output=True, text=True).stdout

    print("== %s  %s" % (label, model))
    print("exit %s%s, %.0fs, %d events, %d provider responses" % (
        rc, " (killed at the 420 s limit)" if killed else "", wall, len(ev),
        sum(1 for e in ev if e.get("type") == "thinking")))
    print("loaded extensions:", start.get("loaded_extensions"))
    print("tool calls, in order:")
    for step, tool, args in calls:
        a = json.dumps(args, ensure_ascii=False)
        print("  step %s  %s %s" % (step, tool, a if len(a) < 150 else a[:150] + "…"))
    skill_results = [c for _, c in tool_msgs if ".motoko/skills/workdir-stamp" in c[:400]]
    if skill_results:
        print("Skill result begins:", json.dumps(skill_results[0][:170], ensure_ascii=False))
    print("error events:", [str(e.get("message"))[:200] for e in errors] or "none")
    print("finish:", summ.get("finish_reason") or summ.get("reason") or "?")
    print("STAMP.txt:", json.dumps(stamp) if stamp is not None else "NOT WRITTEN")
    print("workdir changes:", " | ".join(l.replace(TPL, "tpl").replace(WORK, "work") for l in diff.strip().splitlines()) or "none")
    print("tokens: %d in, %d out; list price $%.4f" % (tin, tout, tin / 1e6 * pin + tout / 1e6 * pout))
    stub = os.path.join(out, "stub_calls.log")
    print("stub calls:", open(stub).read().strip() if os.path.exists(stub) else "none")
    return 0


if __name__ == "__main__":
    sys.exit(main())
