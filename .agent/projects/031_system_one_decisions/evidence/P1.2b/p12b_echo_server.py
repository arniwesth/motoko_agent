# 031 PLAN-001 P1.2b probe stand-in for the environment server's /scratchpad-cell endpoint.
# Synthetic, loopback only: answers every POST with {"stdout": <the request body>, "exit_code": 0}.
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode()
        out = json.dumps({"stdout": body, "stderr": "", "exit_code": 0}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out))); self.end_headers(); self.wfile.write(out)
    def log_message(self, *a): pass
srv = HTTPServer(("127.0.0.1", int(sys.argv[1])), H)
print("listening", flush=True)
srv.serve_forever()
