"""Terminal-Bench BaseAgent adapter for Motoko."""
from __future__ import annotations

import base64
import os
import re
import sys
import uuid
from pathlib import Path

from terminal_bench.agents.base_agent import AgentResult, BaseAgent
from terminal_bench.agents.failure_mode import FailureMode
from terminal_bench.terminal.tmux_session import TmuxSession

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from motoko_rpc import MotokoRpc  # noqa: E402
from tb_adapter.shell_sidecar import ShellSidecar  # noqa: E402


DEFAULT_MODEL = "anthropic/claude-sonnet-4-6"
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
MAX_LINES = 200


def _strip_ansi(s: str) -> str:
    return ANSI_RE.sub("", s)


def _format_output(raw: str, code: int, cwd: str, timed_out: bool, backend_note: str) -> str:
    cleaned = _strip_ansi(raw).replace("\r", "")
    lines = cleaned.split("\n")
    deduped = []
    last, dup = None, 0
    for ln in lines:
        if ln == last:
            dup += 1
            continue
        if dup > 0:
            deduped.append(f"  [... {dup} duplicate line(s) collapsed ...]")
        dup = 0
        deduped.append(ln)
        last = ln
    if dup > 0:
        deduped.append(f"  [... {dup} duplicate line(s) collapsed ...]")

    truncated = False
    if len(deduped) > MAX_LINES:
        head = MAX_LINES // 2
        tail = MAX_LINES // 4
        skipped = len(deduped) - head - tail
        deduped = deduped[:head] + [f"  [... {skipped} lines truncated ...]"] + deduped[-tail:]
        truncated = True

    body = "\n".join(deduped)
    bits = [f"exit={code}", f"cwd={cwd}", f"timed_out={'true' if timed_out else 'false'}"]
    if truncated:
        bits.append("output_truncated=true")
    if backend_note:
        bits.append(backend_note)
    footer = "[" + " ".join(bits) + "]"
    return f"{body}\n{footer}" if body else footer


class _TmuxShellProxy:
    """Routes shell commands to Terminal-Bench TmuxSession with sentinel parsing."""

    def __init__(self, tmux: TmuxSession, session_id: str):
        self.tmux = tmux
        self.sid = session_id
        self._cursor = 0
        self._initialized = False

    def _init_once(self) -> None:
        if self._initialized:
            return
        setup = "export PAGER=cat GIT_PAGER=cat LESS=FRX MANPAGER=cat SYSTEMD_PAGER=cat"
        try:
            self.tmux.send_keys([setup, "Enter"], block=True, max_timeout_sec=5.0)
            pane = self.tmux.capture_pane(capture_entire=True)
            self._cursor = len(pane)
        except Exception:
            self._cursor = 0
        self._initialized = True

    def _stage(self, command: str, script_path: str, sentinel: str) -> bool:
        full = (
            f"{{ {command}; }}\n"
            f"__rc=$?\n"
            f"rm -f {script_path}\n"
            f"printf '\\n{sentinel}:%d:' \"$__rc\"\n"
            f"pwd\n"
        )
        try:
            cmd_b64 = base64.b64encode(full.encode("utf-8", errors="replace")).decode()
            result = self.tmux.container.exec_run(
                ["sh", "-c", f"printf '%s' '{cmd_b64}' | base64 -d > {script_path}"],
            )
            return getattr(result, "exit_code", 0) == 0
        except Exception:
            return False

    def run(self, command: str, timeout: int) -> str:
        self._init_once()
        sentinel = f"__MOTOKO_END_{uuid.uuid4().hex[:8]}__"
        script_path = f"/tmp/motoko_{sentinel}.sh"
        if not self._stage(command, script_path, sentinel):
            return _format_output(
                "Error: could not stage command to container (exec_run failed).",
                -1,
                "?",
                False,
                "backend=tmux-proxy",
            )
        try:
            self.tmux.send_keys([f"source {script_path}", "Enter"], block=True, max_timeout_sec=float(timeout))
        except Exception:
            pass

        try:
            pane = self.tmux.capture_pane(capture_entire=True)
        except Exception:
            pane = ""

        prev_cursor = self._cursor
        marker = pane.rfind(sentinel + ":")
        if marker < 0:
            body = pane[prev_cursor:] if prev_cursor <= len(pane) else ""
            return _format_output(body.strip(), -1, "?", True, "backend=tmux-proxy")

        tail = pane[marker + len(sentinel) + 1 :]
        parts = tail.split(":", 1)
        code = int(parts[0]) if parts and parts[0].isdigit() else -1
        cwd = "?"
        if len(parts) > 1:
            cwd_lines = parts[1].lstrip("\r\n").split("\n")
            if cwd_lines:
                cwd = cwd_lines[0].strip() or "?"

        post = pane.find("\n", marker)
        post = (post + 1) if post >= 0 else len(pane)
        cwd_end = pane.find("\n", post)
        self._cursor = (cwd_end + 1) if cwd_end >= 0 else post

        body_end_line = pane.rfind("\n", 0, marker)
        body_start = prev_cursor if prev_cursor <= marker else 0
        body_end = body_end_line if body_end_line > body_start else marker
        body = pane[body_start:body_end]
        body = re.sub(r";\s*tmux\s+wait\s+-S\s+done\b", "", body)
        first = body.find(sentinel)
        if first >= 0:
            eol = body.find("\n", first)
            body = body[eol + 1 :] if eol >= 0 else ""
        body = body.lstrip("\n\r ")
        return _format_output(body, code, cwd, False, "backend=tmux-proxy")


class MotokoAgent(BaseAgent):
    @staticmethod
    def name() -> str:
        return "motoko"

    def __init__(
        self,
        model_name: str | None = None,
        max_steps: int = 40,
        verbose: bool = False,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self._model = model_name or os.environ.get("TB_MOTOKO_MODEL") or DEFAULT_MODEL
        self._max_steps = max_steps
        self._verbose = verbose

    def perform_task(
        self,
        instruction: str,
        session: TmuxSession,
        logging_dir: Path | None = None,
    ) -> AgentResult:
        session_id = f"tb-{uuid.uuid4().hex[:10]}"
        proxy = _TmuxShellProxy(session, session_id)
        sidecar = ShellSidecar(proxy)
        sidecar.start()

        failure = FailureMode.NONE
        tokens_in = 0
        tokens_out = 0

        log_fh = None
        if logging_dir is not None:
            logging_dir.mkdir(parents=True, exist_ok=True)
            log_fh = (logging_dir / "motoko.log").open("w")

        prompt = (
            "You are solving a Terminal-Bench task inside a Linux container.\n"
            "Use shell commands only; keep actions minimal and verifiable.\n"
            "When complete, provide a concise final result.\n\n"
            f"TASK:\n{instruction}\n"
        )

        system_md = Path(__file__).resolve().parent.parent / "prompts" / "tb_system.md"

        try:
            with MotokoRpc(
                task=prompt,
                model=self._model,
                max_steps=self._max_steps,
                benchmark="terminal_bench",
                env={
                    "TB_EXEC_PROXY": sidecar.url,
                    "SYSTEM_MD": str(system_md),
                    "MOTOKO_BENCHMARK": "terminal_bench",
                },
            ) as rpc:
                result = rpc.run_and_collect(timeout=3600)

            if result.terminal_event == "error":
                failure = FailureMode.UNKNOWN_AGENT_ERROR

            if log_fh:
                log_fh.write("=== final output ===\n")
                log_fh.write(result.final_output + "\n\n")
                log_fh.write(f"steps={result.step_count} elapsed_s={result.elapsed_s}\n")
                if result.error_message:
                    log_fh.write(f"error={result.error_message}\n")
                if self._verbose:
                    for st in result.steps:
                        log_fh.write(f"\n$ {st.get('cmd','')}\n")
                        out = str(st.get("stdout", ""))
                        if out:
                            log_fh.write(out[:1000] + "\n")
        except Exception as e:
            failure = FailureMode.UNKNOWN_AGENT_ERROR
            if log_fh:
                log_fh.write(f"AGENT ERROR: {e}\n")
        finally:
            sidecar.shutdown()
            if log_fh:
                log_fh.flush()
                log_fh.close()

        return AgentResult(
            total_input_tokens=tokens_in,
            total_output_tokens=tokens_out,
            failure_mode=failure,
        )
