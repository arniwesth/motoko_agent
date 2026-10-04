#!/usr/bin/env python3
"""037 P1.2 listing check: a local OpenAI-compatible endpoint that RECORDS each
request body and answers from a fixed script. No model is called.

  request 1 -> a tool call  Skill({"name":"workdir-stamp"})
  request 2 -> a tool call  Skill({"name":"no-such-skill"})
  request 3+ -> a final text answer
"""
import json, sys, os, time
from http.server import BaseHTTPRequestHandler, HTTPServer

OUT = sys.argv[1]
PORT = int(sys.argv[2])
count = {"n": 0}

SCRIPT = [
    {"tool": ("Skill", {"name": "workdir-stamp"})},
    {"tool": ("Skill", {"name": "no-such-skill"})},
    {"text": "Listing check complete."},
]

def chunk(delta, finish=None, usage=None):
    d = {"id": "chatcmpl-p1capture", "object": "chat.completion.chunk", "created": int(time.time()),
         "model": "p1-capture", "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]}
    if usage is not None:
        d["usage"] = usage
    return "data: " + json.dumps(d) + "\n\n"

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a):
        pass
    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(n)
        count["n"] += 1
        i = count["n"]
        try:
            body = json.loads(raw)
        except ValueError:
            body = {"_unparsed": raw.decode("utf-8", "replace")}
        with open(os.path.join(OUT, "req-%02d.json" % i), "w") as f:
            json.dump({"path": self.path, "header_names": sorted(self.headers.keys()), "body": body}, f, indent=1, ensure_ascii=False)
        step = SCRIPT[min(i, len(SCRIPT)) - 1]
        usage = {"prompt_tokens": 1000, "completion_tokens": 10, "total_tokens": 1010}
        if body.get("stream"):
            parts = [chunk({"role": "assistant", "content": ""})]
            if "tool" in step:
                name, args = step["tool"]
                parts.append(chunk({"tool_calls": [{"index": 0, "id": "call_p1capture%02d" % i, "type": "function",
                                                    "function": {"name": name, "arguments": json.dumps(args)}}]}))
                parts.append(chunk({}, "tool_calls", usage))
            else:
                parts.append(chunk({"content": step["text"]}))
                parts.append(chunk({}, "stop", usage))
            parts.append("data: [DONE]\n\n")
            data = "".join(parts).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(data)
        else:
            if "tool" in step:
                name, args = step["tool"]
                msg = {"role": "assistant", "content": None, "tool_calls": [{"id": "call_p1capture%02d" % i, "type": "function",
                       "function": {"name": name, "arguments": json.dumps(args)}}]}
                fin = "tool_calls"
            else:
                msg = {"role": "assistant", "content": step["text"]}
                fin = "stop"
            data = json.dumps({"id": "chatcmpl-p1capture", "object": "chat.completion", "created": int(time.time()),
                               "model": "p1-capture", "choices": [{"index": 0, "message": msg, "finish_reason": fin}],
                               "usage": usage}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(data)
    def do_GET(self):
        data = b'{"object":"list","data":[{"id":"p1-capture","object":"model"}]}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

HTTPServer(("127.0.0.1", PORT), H).serve_forever()
