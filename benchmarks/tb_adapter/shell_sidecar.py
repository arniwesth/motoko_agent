"""HTTP sidecar that adapts Motoko /exec calls to Terminal-Bench tmux shell."""
from __future__ import annotations

import json
import re
import threading
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Protocol


_FOOTER_RE = re.compile(r"\[exit=(?P<code>-?\d+)\s+cwd=(?P<cwd>[^\s\]]+).*$")


class ShellRunner(Protocol):
    def run(self, command: str, timeout: int) -> str:
        ...


@dataclass
class ParsedShellOutput:
    stdout: str
    exit_code: int
    cwd: str


def parse_shell_output(raw: str) -> ParsedShellOutput:
    text = str(raw or "")
    lines = text.splitlines()
    if not lines:
        return ParsedShellOutput(stdout="", exit_code=1, cwd="?")

    footer = lines[-1].strip()
    m = _FOOTER_RE.match(footer)
    if not m:
        return ParsedShellOutput(stdout=text, exit_code=1, cwd="?")

    try:
        code = int(m.group("code"))
    except Exception:
        code = 1
    cwd = m.group("cwd")
    body = "\n".join(lines[:-1]).rstrip("\n")
    return ParsedShellOutput(stdout=body, exit_code=code, cwd=cwd)


class ShellSidecar:
    def __init__(self, runner: ShellRunner, host: str = "127.0.0.1", port: int = 0):
        self._runner = runner
        self._host = host
        self._server = ThreadingHTTPServer((host, port), self._make_handler())
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._cwd = "/app"

    def _make_handler(self):
        parent = self

        class Handler(BaseHTTPRequestHandler):
            def _json(self, status: int, payload: dict):
                b = json.dumps(payload).encode("utf-8")
                self.send_response(status)
                self.send_header("content-type", "application/json")
                self.send_header("content-length", str(len(b)))
                self.end_headers()
                self.wfile.write(b)

            def do_POST(self):  # noqa: N802
                if self.path != "/exec":
                    self._json(404, {"error": "not found"})
                    return
                try:
                    n = int(self.headers.get("Content-Length", "0"))
                    body = self.rfile.read(n)
                    req = json.loads(body.decode("utf-8") or "{}")
                except Exception:
                    self._json(400, {"error": "bad json"})
                    return

                command = str(req.get("command") or req.get("cmd") or "")
                timeout = int(req.get("timeout") or 30)
                if not command.strip():
                    self._json(200, {"stdout": "", "stderr": "empty command", "exit_code": 1})
                    return

                prefixed = command
                if parent._cwd and parent._cwd != "?":
                    quoted = parent._cwd.replace("'", "'\"'\"'")
                    prefixed = f"cd '{quoted}' && {command}"

                try:
                    raw = parent._runner.run(prefixed, timeout)
                    parsed = parse_shell_output(raw)
                    if parsed.cwd and parsed.cwd != "?":
                        parent._cwd = parsed.cwd
                    self._json(
                        200,
                        {
                            "stdout": parsed.stdout[:8000],
                            "stderr": "",
                            "exit_code": parsed.exit_code,
                        },
                    )
                except Exception as e:
                    self._json(200, {"stdout": "", "stderr": f"sidecar error: {e}", "exit_code": 1})

            def do_GET(self):  # noqa: N802
                if self.path == "/health":
                    self._json(200, {"ok": True})
                else:
                    self._json(404, {"error": "not found"})

            def log_message(self, fmt: str, *args):
                return

        return Handler

    @property
    def port(self) -> int:
        return int(self._server.server_address[1])

    @property
    def url(self) -> str:
        return f"http://{self._host}:{self.port}"

    def start(self) -> None:
        self._thread.start()

    def shutdown(self) -> None:
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=2)
