"""Motoko JSONL RPC client for benchmark harnesses.

Spawns the non-TTY Motoko TUI process with MOTOKO_JSONL_OUTPUT=1 and drains
structured AgentEvent JSON lines until a terminal event (done/error).
"""
from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parent.parent
TUI_ENTRY = REPO_ROOT / "src" / "tui" / "dist" / "index.js"


@dataclass
class MotokoResult:
    steps: list[dict[str, Any]] = field(default_factory=list)
    final_output: str = ""
    thinking_text: str = ""
    step_count: int = 0
    agent_ended: bool = False
    elapsed_s: float = 0.0
    terminal_event: str = ""
    error_message: str = ""
    events: list[dict[str, Any]] = field(default_factory=list)


class MotokoRpc:
    def __init__(
        self,
        task: str,
        model: str = "anthropic/claude-sonnet-4-6",
        workdir: str | None = None,
        env_port: int | None = None,
        max_steps: int = 50,
        env: dict[str, str] | None = None,
        timeout: float = 900,
        benchmark: str | None = None,
        ai_options_json: str | None = None,
    ):
        self.task = task
        self.model = model
        self.workdir = workdir or os.getcwd()
        self.max_steps = max_steps
        self.timeout = timeout
        self._env_port = env_port or self._pick_free_port()
        self._closed = False

        if not TUI_ENTRY.exists():
            raise FileNotFoundError(
                f"TUI entry not found at {TUI_ENTRY}. Run: cd src/tui && npm run build"
            )

        full_env = dict(os.environ)
        if env:
            full_env.update(env)
        full_env.update(
            {
                "TASK": task,
                "MODEL": model,
                "WORKDIR": self.workdir,
                "ENV_PORT": str(self._env_port),
                "AI_MAX_STEPS": str(max_steps),
                "MOTOKO_JSONL_OUTPUT": "1",
            }
        )
        if benchmark:
            full_env["MOTOKO_BENCHMARK"] = benchmark
        if ai_options_json:
            full_env["MOTOKO_AI_OPTIONS_JSON"] = ai_options_json

        self._proc = subprocess.Popen(
            ["node", str(TUI_ENTRY), task],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=str(REPO_ROOT),
            env=full_env,
            text=True,
            bufsize=1,
            start_new_session=True,
        )

        self._events: list[dict[str, Any]] = []
        self._stderr_lines: list[str] = []
        self._raw_stdout_lines: list[str] = []
        self._lock = threading.Lock()
        self._cv = threading.Condition(self._lock)

        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()
        self._stderr_reader = threading.Thread(target=self._read_stderr_loop, daemon=True)
        self._stderr_reader.start()

    @staticmethod
    def _pick_free_port() -> int:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.bind(("", 0))
            s.listen(1)
            return int(s.getsockname()[1])
        finally:
            s.close()

    def _read_loop(self) -> None:
        assert self._proc.stdout is not None
        while True:
            line = self._proc.stdout.readline()
            if not line:
                break
            text = line.rstrip("\r\n")
            if not text:
                continue
            with self._cv:
                self._raw_stdout_lines.append(text)
            try:
                ev = json.loads(text)
                if not isinstance(ev, dict):
                    continue
            except json.JSONDecodeError:
                continue
            with self._cv:
                self._events.append(ev)
                self._cv.notify_all()

    def _read_stderr_loop(self) -> None:
        assert self._proc.stderr is not None
        while True:
            line = self._proc.stderr.readline()
            if not line:
                break
            with self._lock:
                self._stderr_lines.append(line.rstrip("\r\n"))

    def _wait_for_event(self, deadline: float) -> dict[str, Any] | None:
        with self._cv:
            while True:
                if self._events:
                    return self._events.pop(0)
                if self._proc.poll() is not None:
                    return None
                remaining = deadline - time.time()
                if remaining <= 0:
                    return None
                self._cv.wait(timeout=remaining)

    def run_and_collect(
        self,
        timeout: float | None = None,
        on_event: Callable[[dict[str, Any]], None] | None = None,
    ) -> MotokoResult:
        timeout_s = self.timeout if timeout is None else timeout
        deadline = time.time() + timeout_s
        started = time.time()

        result = MotokoResult()
        pending_cmds: dict[int, str] = {}

        while True:
            if time.time() >= deadline:
                self.abort()
                break

            ev = self._wait_for_event(deadline)
            if ev is None:
                if self._proc.poll() is not None:
                    break
                continue

            result.events.append(ev)
            if on_event is not None:
                try:
                    on_event(ev)
                except Exception:
                    pass
            t = str(ev.get("type", ""))
            if t == "thinking":
                text = str(ev.get("text", ""))
                if text:
                    result.thinking_text += ("\n" if result.thinking_text else "") + text
            elif t == "proposed_cmd":
                step = int(ev.get("step", 0))
                pending_cmds[step] = str(ev.get("cmd", ""))
            elif t == "obs":
                step = int(ev.get("step", 0))
                cmd = str(ev.get("cmd", "")) or pending_cmds.get(step, "")
                result.steps.append(
                    {
                        "step": step,
                        "cmd": cmd,
                        "stdout": str(ev.get("stdout", "")),
                        "stderr": str(ev.get("stderr", "")),
                        "exit_code": int(ev.get("exit_code", 1)),
                    }
                )
                if step > result.step_count:
                    result.step_count = step
            elif t == "done":
                result.final_output = str(ev.get("output", ""))
                result.step_count = max(result.step_count, int(ev.get("step", result.step_count or 0)))
                result.agent_ended = True
                result.terminal_event = "done"
                break
            elif t == "error":
                result.error_message = str(ev.get("message", ""))
                result.agent_ended = True
                result.terminal_event = "error"
                break

        result.elapsed_s = round(time.time() - started, 3)
        self.close()
        return result

    def abort(self) -> None:
        if self._proc.poll() is not None:
            return
        try:
            if self._proc.stdin and not self._proc.stdin.closed:
                self._proc.stdin.write('{"type":"abort"}\n')
                self._proc.stdin.flush()
                return
        except Exception:
            pass
        try:
            os.killpg(os.getpgid(self._proc.pid), signal.SIGTERM)
        except OSError:
            try:
                self._proc.terminate()
            except Exception:
                pass

    def close(self, timeout: float = 5) -> None:
        if self._closed:
            return
        self._closed = True

        try:
            if self._proc.stdin and not self._proc.stdin.closed:
                self._proc.stdin.close()
        except Exception:
            pass

        try:
            self._proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(os.getpgid(self._proc.pid), signal.SIGKILL)
            except OSError:
                try:
                    self._proc.kill()
                except Exception:
                    pass
            try:
                self._proc.wait(timeout=2)
            except Exception:
                pass

    def stderr(self) -> str:
        with self._lock:
            return "\n".join(self._stderr_lines)

    def raw_stdout(self) -> list[str]:
        with self._lock:
            return list(self._raw_stdout_lines)

    def __enter__(self) -> "MotokoRpc":
        return self

    def __exit__(self, *_: Any) -> None:
        self.close()
