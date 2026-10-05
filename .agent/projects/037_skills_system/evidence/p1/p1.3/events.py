"""037 P1.3: read one session's event stream (session.stdout.jsonl)."""
import json, os


def load(out_dir):
    ev = []
    p = os.path.join(out_dir, "session.stdout.jsonl")
    if not os.path.exists(p):
        return ev
    for line in open(p, encoding="utf-8", errors="replace"):
        line = line.strip()
        if line.startswith("{"):
            try:
                ev.append(json.loads(line))
            except ValueError:
                pass
    return ev


def session_txt(out_dir):
    d = {}
    p = os.path.join(out_dir, "session.txt")
    if os.path.exists(p):
        for line in open(p):
            if "=" in line:
                k, v = line.rstrip("\n").split("=", 1)
                d[k] = v
    return d


def calls_by_step(ev):
    """{step: [(tool, arguments-dict)]} in the order the model emitted them."""
    out = {}
    for e in ev:
        if e.get("type") == "native_tool_calls":
            out.setdefault(e.get("step"), []).extend(
                (c.get("tool"), c.get("arguments") or {}) for c in e.get("tool_calls", []))
    return out


def steps(ev):
    """One dict per provider response: step, finish_reason, tokens, text."""
    return [{"step": e.get("step"), "finish_reason": e.get("finish_reason"), "tool_calls": e.get("tool_calls"),
             "input_tokens": e.get("input_tokens") or 0, "output_tokens": e.get("output_tokens") or 0,
             "text": e.get("text") or ""} for e in ev if e.get("type") == "thinking"]


def tool_messages(ev):
    """[(step, content)] for every tool message appended to history."""
    return [(e.get("step"), e["message"].get("content") or "") for e in ev
            if e.get("type") == "history_appended" and e.get("message", {}).get("role") == "tool"]


def of_type(ev, *types):
    return [e for e in ev if e.get("type") in types]


def summary(ev):
    s = of_type(ev, "run_summary")
    return s[-1] if s else None


def start(ev):
    for e in ev:
        if e.get("type") == "session_start" and "loaded_extensions" in e:
            return e
    return {}
