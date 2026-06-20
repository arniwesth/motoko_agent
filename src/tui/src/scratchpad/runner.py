import ast
import base64
import contextlib
import io
import json
import os
import socket
import sys
import traceback
import urllib.request
import uuid


EXEC_COUNT = 0
GLOBALS = {"__name__": "__motoko_scratchpad__"}
ORIG_STDOUT = sys.stdout

if os.environ.get("MOTOKO_SCRATCHPAD_NETWORK", "0") != "1":
    _orig_create_connection = socket.create_connection
    def _guarded_create_connection(address, *args, **kwargs):
        host = address[0] if isinstance(address, tuple) and address else ""
        if host in ("127.0.0.1", "localhost", "::1"):
            return _orig_create_connection(address, *args, **kwargs)
        raise OSError("network access is disabled for scratchpad kernels")
    socket.create_connection = _guarded_create_connection


def emit(obj):
    ORIG_STDOUT.write(json.dumps(obj, separators=(",", ":")) + "\n")
    ORIG_STDOUT.flush()


class Capture(io.StringIO):
    def __init__(self, frame_type, cell_id):
        super().__init__()
        self.frame_type = frame_type
        self.cell_id = cell_id

    def write(self, s):
        if s:
            emit({"type": self.frame_type, "id": self.cell_id, "text": s})
        return len(s)


def call_loopback(tool, arguments):
    url = os.environ.get("MOTOKO_SCRATCHPAD_LOOPBACK_URL", "")
    token = os.environ.get("MOTOKO_SCRATCHPAD_LOOPBACK_TOKEN", "")
    if not url or not token:
        raise RuntimeError("scratchpad loopback is not configured")
    req_id = str(uuid.uuid4())
    payload = json.dumps({
        "type": "tool-request",
        "reqId": req_id,
        "tool": tool,
        "arguments": arguments or {},
    }).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "content-type": "application/json",
            "authorization": "Bearer " + token,
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    if data.get("exit_code", 1) != 0:
        raise RuntimeError(data.get("stderr") or data.get("stdout") or "loopback tool failed")
    return data.get("stdout", "")


class ToolProxy:
    def read(self, path):
        return call_loopback("read", {"path": path})

    def write(self, path, content):
        return call_loopback("write", {"path": path, "content": content})

    def append(self, path, content):
        return call_loopback("append", {"path": path, "content": content})

    def search(self, pattern, path="."):
        return call_loopback("search", {"pattern": pattern, "path": path})


def agent(prompt, model=""):
    return call_loopback("agent", {"prompt": prompt, "model": model})


def _rich_image_bytes(value):
    """Best-effort: turn a rich display object into ``(mime, png/jpeg bytes)``.

    Handles the ergonomic forms agents reach for — a matplotlib ``Figure`` /
    ``Axes`` / the ``pyplot`` module, a PIL ``Image``, or anything exposing an
    IPython-style ``_repr_png_`` / ``_repr_jpeg_`` — so ``display(fig)`` and
    ``display(pil_image)`` just work instead of degrading to a text repr.
    Returns ``None`` when ``value`` is not a recognizable image object.
    """
    # IPython-style rich reprs (PIL Images and many plotting libs expose these).
    for meth, mime in (("_repr_png_", "image/png"), ("_repr_jpeg_", "image/jpeg")):
        fn = getattr(value, meth, None)
        if callable(fn):
            try:
                data = fn()
            except Exception:
                data = None
            if isinstance(data, (bytes, bytearray)):
                return mime, bytes(data)
            if isinstance(data, str):
                try:
                    return mime, base64.b64decode(data)
                except Exception:
                    pass
    # matplotlib: Figure and the pyplot module both expose savefig (pyplot saves
    # the current figure); an Axes exposes its parent via .figure.
    target = value
    if not hasattr(target, "savefig") and hasattr(target, "figure"):
        target = target.figure
    savefig = getattr(target, "savefig", None)
    if callable(savefig):
        try:
            buf = io.BytesIO()
            savefig(buf, format="png", bbox_inches="tight")
            blob = buf.getvalue()
            if blob:
                return "image/png", blob
        except Exception:
            pass
    # PIL Image (duck-typed: save + mode + size).
    if hasattr(value, "save") and hasattr(value, "mode") and hasattr(value, "size"):
        try:
            buf = io.BytesIO()
            value.save(buf, format="PNG")
            blob = buf.getvalue()
            if blob:
                return "image/png", blob
        except Exception:
            pass
    return None


def to_bundle(value):
    if isinstance(value, dict):
        mime = value.get("mime")
        data = value.get("data")
        if isinstance(mime, str) and mime.startswith("image/") and isinstance(data, str):
            return {
                "type": "image",
                "mime": mime,
                "data": data,
                "width": value.get("width"),
                "height": value.get("height"),
            }
        if isinstance(value.get("markdown"), str):
            return {"type": "markdown", "mime": "text/markdown", "data": value.get("markdown")}
        if isinstance(value.get("status"), str):
            return {"type": "status", "mime": "text/plain", "data": value.get("status")}
    if isinstance(value, (dict, list, int, float, bool)) or value is None:
        return {"type": "json", "mime": "application/json", "data": value}
    if isinstance(value, (bytes, bytearray)):
        return {"type": "image", "mime": "image/png", "data": base64.b64encode(bytes(value)).decode("ascii")}
    rich = _rich_image_bytes(value)
    if rich is not None:
        mime, blob = rich
        return {"type": "image", "mime": mime, "data": base64.b64encode(blob).decode("ascii")}
    return {"type": "text", "mime": "text/plain", "data": str(value)}


def display(value):
    current_id = GLOBALS.get("__motoko_cell_id", "")
    emit({"type": "display", "id": current_id, "bundle": to_bundle(value)})


GLOBALS.update({
    "display": display,
    "tool": ToolProxy(),
    "agent": agent,
})


def run_cell(frame):
    global EXEC_COUNT
    cell_id = frame.get("id", "")
    code = frame.get("code", "")
    cwd = frame.get("cwd", "")
    if cwd:
        os.chdir(cwd)
    GLOBALS["__motoko_cell_id"] = cell_id
    EXEC_COUNT += 1
    emit({"type": "started", "id": cell_id})
    status = "ok"
    cancelled = False
    try:
        tree = ast.parse(code, mode="exec")
        result_expr = None
        if tree.body and isinstance(tree.body[-1], ast.Expr):
            result_expr = ast.Expression(tree.body.pop().value)
            ast.fix_missing_locations(result_expr)
        stdout = Capture("stdout", cell_id)
        stderr = Capture("stderr", cell_id)
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            if tree.body:
                exec(compile(tree, "<motoko-scratchpad>", "exec"), GLOBALS, GLOBALS)
            if result_expr is not None:
                value = eval(compile(result_expr, "<motoko-scratchpad>", "eval"), GLOBALS, GLOBALS)
                if value is not None and not frame.get("silent", False):
                    emit({"type": "result", "id": cell_id, "bundle": to_bundle(value)})
    except KeyboardInterrupt:
        status = "timeout"
        cancelled = True
        emit({"type": "error", "id": cell_id, "ename": "KeyboardInterrupt", "evalue": "cancelled", "traceback": []})
    except BaseException as exc:
        status = "error"
        emit({
            "type": "error",
            "id": cell_id,
            "ename": exc.__class__.__name__,
            "evalue": str(exc),
            "traceback": traceback.format_exception(exc.__class__, exc, exc.__traceback__),
        })
    emit({"type": "done", "id": cell_id, "status": status, "executionCount": EXEC_COUNT, "cancelled": cancelled})


for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        frame = json.loads(line)
        if frame.get("type") == "exit":
            break
        if frame.get("type") == "run":
            run_cell(frame)
    except BaseException as exc:
        emit({
            "type": "error",
            "id": "",
            "ename": exc.__class__.__name__,
            "evalue": str(exc),
            "traceback": traceback.format_exception(exc.__class__, exc, exc.__traceback__),
        })
