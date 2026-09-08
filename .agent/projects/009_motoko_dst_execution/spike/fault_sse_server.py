#!/usr/bin/env python3
"""Minimal OpenAI-shaped SSE endpoint that streams N content deltas and then
fails mid-stream by closing the connection without a terminal chunk.

Used to drive std/ai.stepWithStreamRecorded through a genuine
partial-stream-then-error: the provider emits real chunks over real SSE, the
callback fires for each, and only then does the stream break.

  MODE=partial_error  deltas, then abrupt close   (default)
  MODE=success        deltas, then [DONE]
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = os.environ.get("MODE", "partial_error")
PORT = int(os.environ.get("PORT", "8817"))
DELTAS = ["partial-1", "partial-2"]


def chunk(text=None, finish=None):
    delta = {"content": text} if text is not None else {}
    return json.dumps({
        "id": "chatcmpl-probe",
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
        sys.stderr.write(f"[server] POST {self.path} mode={MODE}\n")
        sys.stderr.flush()

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
            # Break the stream: terminate the chunked body mid-flight without
            # a terminating 0-length chunk, then drop the socket.
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
