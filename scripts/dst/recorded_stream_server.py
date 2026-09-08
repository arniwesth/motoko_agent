#!/usr/bin/env python3
"""Minimal OpenAI-shaped SSE endpoint for WI-C2's D1 gate probe.

Derived from `.agent/projects/009_motoko_dst_execution/spike/fault_sse_server.py`,
which dispositioned the D1 substrate gate against a prototype. Two differences,
both deliberate:

  1. DELTAS is a MULTI-CHUNK, ORDER-DISTINGUISHING sequence with a deliberate
     ADJACENT REPEAT. `--ai-stub` fires the callback exactly twice
     (`ContentDelta(full_text)` then `Usage`) because it is a provider without
     native streaming — measured, not assumed — so a stub-driven pass exercises
     ordering barely and duplication not at all. Five distinct-except-for-the-
     repeat deltas make a reordering visible and make a de-duplicating
     implementation visible; two chunks make neither.

  2. It is a REAL NATIVE SSE STREAM, which is the only way to induce a genuine
     partial-stream-then-error. A config-driven provider cannot: `stepWithStream`
     falls back to a NO-OP synthetic-chunk path for those, which by construction
     cannot produce a PARTIAL stream.

  MODE=success        deltas, then a finish chunk and [DONE]
  MODE=partial_error  deltas, then an abrupt mid-chunked-body close
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = os.environ.get("MODE", "partial_error")
PORT = int(os.environ.get("PORT", "8819"))

# The adjacent "rep" pair is the duplication control: exact parity must preserve
# it. An implementation that de-duplicated, or that returned a set rather than
# the observed sequence, returns four chunks here and five is required.
DELTAS = ["c1-alpha", "c2-beta", "rep", "rep", "c5-omega"]


def chunk(text=None, finish=None):
    delta = {"content": text} if text is not None else {}
    return json.dumps({
        "id": "chatcmpl-c2",
        "object": "chat.completion.chunk",
        "created": 0,
        "model": "gpt-probe",
        "choices": [{"index": 0, "delta": delta, "finish_reason": finish}],
    })


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        for d in DELTAS:
            self._sse(chunk(text=d))

        if MODE == "success":
            self._sse(chunk(finish="stop"))
            self._sse("[DONE]")
            self._end_chunked()
        else:
            # Break the stream: terminate the chunked body mid-flight without a
            # terminating 0-length chunk, then drop the socket.
            self.wfile.flush()
            self.close_connection = True
            try:
                self.connection.close()
            except OSError:
                pass

    def _sse(self, payload):
        body = f"data: {payload}\n\n".encode()
        self.wfile.write(b"%x\r\n" % len(body) + body + b"\r\n")
        self.wfile.flush()

    def _end_chunked(self):
        self.wfile.write(b"0\r\n\r\n")
        self.wfile.flush()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    sys.stderr.write(f"[server] listening on {PORT} mode={MODE}\n")
    sys.stderr.flush()
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
