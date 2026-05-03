#!/usr/bin/env python3
"""Aider Polyglot runner for Motoko.

Runs Exercism-style exercises by spawning Motoko in JSONL mode per attempt,
then executes language test suites locally and stores comparable result JSON.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from motoko_rpc import MotokoRpc  # noqa: E402


BENCHMARK_ROOT = Path(
    os.environ.get(
        "MOTOKO_BENCHMARK_ROOT",
        str((Path(__file__).resolve().parent.parent / "polyglot-benchmark")),
    )
)
RESULTS_DIR = Path(__file__).parent / "results"
RESULTS_FILE = RESULTS_DIR / "polyglot_results.json"
LIVE_FILE = RESULTS_DIR / "polyglot_live.json"
LOG_ROOT = Path(__file__).parent / "polyglot_logs"
DEFAULT_MODEL = "anthropic/claude-sonnet-4-6"


def _copy_exercise(src: Path, dst: Path) -> None:
    def _ignore(_dir: str, names: list[str]) -> list[str]:
        return [".meta"] if ".meta" in names else []

    shutil.copytree(src, dst, ignore=_ignore)


def _prepare_python(src: Path, work: Path):
    _copy_exercise(src, work)
    stubs = [p for p in work.glob("*.py") if not p.name.endswith("_test.py")]
    tests = list(work.glob("*_test.py"))
    return stubs, tests


def _run_python(work: Path, timeout: int):
    try:
        r = subprocess.run(
            ["python3", "-m", "pytest", "-x", "-q"],
            cwd=work,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return r.returncode == 0, (r.stdout + r.stderr)
    except subprocess.TimeoutExpired:
        return False, f"timed out after {timeout}s"


LANG_DESCRIPTORS = {
    "python": {
        "practice_dir": BENCHMARK_ROOT / "python" / "exercises" / "practice",
        "prepare": _prepare_python,
        "run_tests": _run_python,
        "syntax_hint": "Use Python 3. Run tests with `python -m pytest -x -q`.",
        "timeout_s": 90,
    },
}


def _build_prompt(exercise_name: str, stub_paths: list[Path], test_paths: list[Path], syntax_hint: str) -> str:
    stubs_list = "\n".join(f"  - {p.name}" for p in stub_paths)
    tests_list = "\n".join(f"  - {p.name}" for p in test_paths)
    return (
        f"Implement the Exercism exercise `{exercise_name}`.\n\n"
        f"Stub file(s) to implement:\n{stubs_list}\n\n"
        f"Test file(s) (for reference only — DO NOT edit):\n{tests_list}\n\n"
        f"{syntax_hint}\n\n"
        "Read the stubs + any `.docs/instructions.md` in the workspace, "
        "then implement the solution. Run the tests before finishing."
    )


def _load_results(path: Path) -> dict:
    if path.exists():
        try:
            return json.loads(path.read_text())
        except Exception:
            pass
    return {"exercises": {}, "meta": {}}


def _save_results(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n")
    tmp.replace(path)


def _write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, indent=2) + "\n")
    tmp.replace(path)


def _append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as fh:
        fh.write(json.dumps(payload) + "\n")


def _iso_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _run_exercise(
    lang: str,
    ex_name: str,
    model: str,
    retry: bool,
    verbose: bool,
    openai_base_url: str | None,
    ai_options_json: str | None,
    heartbeat_secs: int,
    live_state: dict[str, Any],
    live_path: Path,
    events_path: Path,
) -> dict:
    desc = LANG_DESCRIPTORS[lang]
    src = desc["practice_dir"] / ex_name
    if not src.exists():
        return {"status": "error", "reason": f"exercise not found: {src}"}

    log_dir = LOG_ROOT / lang / ex_name
    log_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / ex_name
        stubs, tests = desc["prepare"](src, work)
        prompt = _build_prompt(ex_name, stubs, tests, desc["syntax_hint"])

        t0 = time.time()
        state_lock = threading.Lock()
        obs: dict[str, Any] = {
            "last_event_type": "spawn",
            "last_step": 0,
            "event_count": 0,
            "last_event_at": _iso_now(),
            "attempt": 1,
        }
        stop_hb = threading.Event()

        def on_event(ev: dict[str, Any]) -> None:
            t = str(ev.get("type", ""))
            step = int(ev.get("step", 0)) if isinstance(ev.get("step"), int) else 0
            with state_lock:
                obs["last_event_type"] = t
                obs["last_step"] = max(int(obs["last_step"]), step)
                obs["event_count"] = int(obs["event_count"]) + 1
                obs["last_event_at"] = _iso_now()
            _append_jsonl(
                events_path,
                {
                    "ts": _iso_now(),
                    "exercise": f"{lang}/{ex_name}",
                    "attempt": int(obs["attempt"]),
                    "event": ev,
                },
            )
            live_state.update(
                {
                    "updated_at": _iso_now(),
                    "phase": "running",
                    "current": {
                        "exercise": f"{lang}/{ex_name}",
                        "attempt": int(obs["attempt"]),
                        "step": int(obs["last_step"]),
                        "last_event_type": t,
                        "last_event_at": obs["last_event_at"],
                    },
                }
            )
            _write_json_atomic(live_path, live_state)

        def heartbeat() -> None:
            while not stop_hb.wait(timeout=max(1, heartbeat_secs)):
                with state_lock:
                    event_count = int(obs["event_count"])
                    step = int(obs["last_step"])
                    event_type = str(obs["last_event_type"])
                elapsed = time.time() - t0
                if verbose:
                    print(
                        f"[{lang}/{ex_name}] heartbeat elapsed={elapsed:.0f}s "
                        f"attempt={int(obs['attempt'])} step={step} events={event_count} last={event_type}",
                        flush=True,
                    )

        hb_thread: threading.Thread | None = None
        if heartbeat_secs > 0:
            hb_thread = threading.Thread(target=heartbeat, daemon=True)
            hb_thread.start()

        if verbose:
            print(f"[{lang}/{ex_name}] start attempt=1", flush=True)
        with MotokoRpc(
            task=prompt,
            model=model,
            workdir=str(work),
            max_steps=50,
            benchmark="polyglot",
            ai_options_json=ai_options_json if ai_options_json else None,
            env={
                "MOTOKO_BENCHMARK": "polyglot",
                **({"OPENAI_BASE_URL": openai_base_url} if openai_base_url else {}),
            },
        ) as rpc:
            attempt1 = rpc.run_and_collect(timeout=900, on_event=on_event)
            attempt1_stderr = rpc.stderr()

        if attempt1.terminal_event == "error":
            stop_hb.set()
            if hb_thread:
                hb_thread.join(timeout=1)
            err = attempt1.error_message or "agent error before first step"
            (log_dir / "attempt1_error.txt").write_text(err + ("\n\n" + attempt1_stderr if attempt1_stderr else ""))
            if verbose:
                print(f"[{lang}/{ex_name}] error elapsed={attempt1.elapsed_s:.1f}s steps=0 reason={err}")
            return {
                "status": "error",
                "elapsed_s": round(attempt1.elapsed_s, 2),
                "step_count": 0,
                "reason": err,
            }

        passed, output = desc["run_tests"](work, desc["timeout_s"])
        status = "pass_1" if passed else "fail"
        step_count = attempt1.step_count

        attempt2 = None
        if not passed and retry:
            with state_lock:
                obs["attempt"] = 2
            if verbose:
                print(f"[{lang}/{ex_name}] start attempt=2", flush=True)
            retry_task = (
                f"{prompt}\n\n"
                "The tests failed. Output:\n"
                f"```\n{output[-4000:]}\n```\n"
                "Fix the implementation and run tests again."
            )
            with MotokoRpc(
                task=retry_task,
                model=model,
                workdir=str(work),
                max_steps=50,
                benchmark="polyglot",
                ai_options_json=ai_options_json if ai_options_json else None,
                env={
                    "MOTOKO_BENCHMARK": "polyglot",
                    **({"OPENAI_BASE_URL": openai_base_url} if openai_base_url else {}),
                },
            ) as rpc:
                attempt2 = rpc.run_and_collect(timeout=900, on_event=on_event)
                attempt2_stderr = rpc.stderr()
            if attempt2.terminal_event == "error":
                stop_hb.set()
                if hb_thread:
                    hb_thread.join(timeout=1)
                err2 = attempt2.error_message or "agent retry error before first step"
                (log_dir / "attempt2_error.txt").write_text(err2 + ("\n\n" + attempt2_stderr if attempt2_stderr else ""))
                status = "error"
                elapsed = round(time.time() - t0, 2)
                (log_dir / "tests_output.txt").write_text(output)
                (log_dir / "attempt1_final.txt").write_text(attempt1.final_output)
                (log_dir / "attempt1_thinking.txt").write_text(attempt1.thinking_text)
                (log_dir / "attempt2_final.txt").write_text(attempt2.final_output)
                (log_dir / "attempt2_thinking.txt").write_text(attempt2.thinking_text)
                if verbose:
                    print(f"[{lang}/{ex_name}] error elapsed={elapsed:.1f}s steps={step_count} reason={err2}")
                return {
                    "status": "error",
                    "elapsed_s": elapsed,
                    "step_count": step_count,
                    "reason": err2,
                }
            passed, output = desc["run_tests"](work, desc["timeout_s"])
            if passed:
                status = "pass_2"
            step_count += attempt2.step_count

        stop_hb.set()
        if hb_thread:
            hb_thread.join(timeout=1)

        elapsed = round(time.time() - t0, 2)
        (log_dir / "tests_output.txt").write_text(output)
        (log_dir / "attempt1_final.txt").write_text(attempt1.final_output)
        (log_dir / "attempt1_thinking.txt").write_text(attempt1.thinking_text)
        (log_dir / "attempt1_events.json").write_text(json.dumps(attempt1.events, indent=2) + "\n")
        if attempt2:
            (log_dir / "attempt2_final.txt").write_text(attempt2.final_output)
            (log_dir / "attempt2_thinking.txt").write_text(attempt2.thinking_text)
            (log_dir / "attempt2_events.json").write_text(json.dumps(attempt2.events, indent=2) + "\n")

        if verbose:
            print(f"[{lang}/{ex_name}] {status} elapsed={elapsed:.1f}s steps={step_count}")

        return {
            "status": status,
            "elapsed_s": elapsed,
            "step_count": step_count,
        }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--language", default="python")
    ap.add_argument("--exercise", default=None)
    ap.add_argument("--exercises", type=int, default=0, help="run first N exercises (0 = all)")
    ap.add_argument("--results", default=str(RESULTS_FILE))
    ap.add_argument("--openai-base-url", default=os.environ.get("OPENAI_BASE_URL", ""))
    ap.add_argument("--heartbeat-secs", type=int, default=20)
    ap.add_argument("--resume", action="store_true")
    ap.add_argument("--no-retry", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--thinking", choices=["on", "off", "auto"], default="auto")
    args = ap.parse_args()

    if args.language not in LANG_DESCRIPTORS:
        sys.exit(f"Unsupported language '{args.language}'. Supported: {sorted(LANG_DESCRIPTORS)}")

    desc = LANG_DESCRIPTORS[args.language]
    practice = desc["practice_dir"]
    if not practice.exists():
        sys.exit(
            f"Practice directory not found: {practice}\n"
            "Update BENCHMARK_ROOT in benchmarks/aider_polyglot.py."
        )

    openai_base_url = args.openai_base_url.strip() if args.openai_base_url else ""
    model_lower = args.model.strip().lower()
    is_openai_route = model_lower.startswith("openai/")
    if args.thinking in {"on", "off"} and not is_openai_route:
        sys.exit(
            f"--thinking={args.thinking} is only supported for openai/* model routes; got '{args.model}'. "
            "Use --thinking=auto or switch to an OpenAI-compatible route."
        )
    ai_options_json = ""
    if args.thinking == "on":
        ai_options_json = json.dumps({"chat_template_kwargs": {"enable_thinking": True}})
    elif args.thinking == "off":
        ai_options_json = json.dumps({"chat_template_kwargs": {"enable_thinking": False}})

    # Fail fast on bad model/provider config before burning through exercises.
    with tempfile.TemporaryDirectory() as tmp:
        with MotokoRpc(
            task="Respond with one short line and do not run commands.",
            model=args.model,
            workdir=tmp,
            max_steps=2,
            benchmark="polyglot",
            ai_options_json=ai_options_json if ai_options_json else None,
            env={
                "MOTOKO_BENCHMARK": "polyglot",
                **({"OPENAI_BASE_URL": openai_base_url} if openai_base_url else {}),
            },
        ) as rpc:
            preflight = rpc.run_and_collect(timeout=90)
            preflight_stderr = rpc.stderr()
    if preflight.terminal_event == "error":
        detail = preflight.error_message or "unknown startup error"
        if preflight_stderr.strip():
            detail = f"{detail}\n{preflight_stderr.strip()}"
        sys.exit(f"Model preflight failed for '{args.model}': {detail}")

    results_path = Path(args.results)
    results = _load_results(results_path) if args.resume else {"exercises": {}, "meta": {}}
    results["meta"] = {
        **results.get("meta", {}),
        "agent": "motoko",
        "model": args.model,
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "thinking_mode": args.thinking,
    }

    names: list[str]
    if args.exercise:
        names = [args.exercise]
    else:
        names = sorted(p.name for p in practice.iterdir() if p.is_dir())
        if args.exercises > 0:
            names = names[: args.exercises]

    run_id = datetime.datetime.now(datetime.timezone.utc).strftime("run-%Y%m%dT%H%M%SZ")
    events_path = RESULTS_DIR / f"polyglot_events_{run_id}.jsonl"
    live_state: dict[str, Any] = {
        "run_id": run_id,
        "started_at": _iso_now(),
        "updated_at": _iso_now(),
        "phase": "running",
        "language": args.language,
        "model": args.model,
        "total_exercises": len(names),
        "completed_exercises": 0,
        "current": None,
        "last_completed": None,
        "results_file": str(results_path),
        "events_file": str(events_path),
    }
    _write_json_atomic(LIVE_FILE, live_state)

    for idx, name in enumerate(names, start=1):
        key = f"{args.language}/{name}"
        if args.resume and results.get("exercises", {}).get(key, {}).get("status") in {"pass_1", "pass_2"}:
            continue
        live_state.update(
            {
                "updated_at": _iso_now(),
                "completed_exercises": len(results.get("exercises", {})),
                "current": {
                    "index": idx,
                    "total": len(names),
                    "exercise": key,
                    "attempt": 1,
                    "step": 0,
                    "last_event_type": "queued",
                    "started_at": _iso_now(),
                },
            }
        )
        _append_jsonl(events_path, {"ts": _iso_now(), "type": "exercise_start", "exercise": key, "index": idx, "total": len(names)})
        _write_json_atomic(LIVE_FILE, live_state)
        results.setdefault("exercises", {})[key] = _run_exercise(
            args.language,
            name,
            args.model,
            retry=not args.no_retry,
            verbose=args.verbose,
            openai_base_url=openai_base_url,
            ai_options_json=ai_options_json if ai_options_json else None,
            heartbeat_secs=max(0, args.heartbeat_secs),
            live_state=live_state,
            live_path=LIVE_FILE,
            events_path=events_path,
        )
        live_state["completed_exercises"] = len(results.get("exercises", {}))
        live_state["last_completed"] = {"exercise": key, "result": results["exercises"][key], "ts": _iso_now()}
        live_state["current"] = None
        live_state["updated_at"] = _iso_now()
        _append_jsonl(events_path, {"ts": _iso_now(), "type": "exercise_end", "exercise": key, "result": results["exercises"][key]})
        _write_json_atomic(LIVE_FILE, live_state)
        _save_results(results_path, results)

    live_state["phase"] = "done"
    live_state["updated_at"] = _iso_now()
    _write_json_atomic(LIVE_FILE, live_state)

    summary = {k: v.get("status") for k, v in results.get("exercises", {}).items()}
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
