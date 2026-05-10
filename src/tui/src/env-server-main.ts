import { startEnvServer } from "./env-server.js";

// http import is required for the health-on-conflict fallback below.
import * as http from "http";

// healthCheck pings GET /health on the existing env-server. Returns true if
// the URL is alive — used when our bind() fails with EADDRINUSE to detect
// "another sibling already won the race; we should yield".
function healthCheck(port: number, timeoutMs = 1500): Promise<boolean> {
  return new Promise((resolve) => {
    const req = http.get(`http://127.0.0.1:${port}/health`, { timeout: timeoutMs }, (res) => {
      res.resume();
      resolve(res.statusCode === 200);
    });
    req.on("error", () => resolve(false));
    req.on("timeout", () => { req.destroy(); resolve(false); });
  });
}

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw || raw.trim() === "") return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function argValue(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  if (index < 0) return undefined;
  const value = process.argv[index + 1];
  if (!value || value.startsWith("--")) return undefined;
  return value;
}

// M-MOTOKO-EVAL-HARNESS-HARDENING follow-up (2026-05-08): default port
// to 0 so the kernel atomically picks a free port. Eliminates the
// pick_free_port TOCTOU race on parallel motoko spawns. Operator
// override (--port 18080 or ENV_PORT=18080) still works for fixed-port
// setups (Docker, etc).
const requestedPort = Number(argValue("--port") ?? "") || intEnv("ENV_PORT", 0);
const workdir = argValue("--workdir") ?? process.env.WORKDIR ?? process.cwd();

// M-MOTOKO-EVAL-HARNESS-HARDENING follow-up #2 (2026-05-08): when the
// AILANG eval harness spawns N parallel motoko sessions, all N race to
// bind cfg.port (8080 in dogfood). The backend.ail health-check
// short-circuits siblings that arrive AFTER the winner has bound — but
// when all N spawn simultaneously, all N see "no env-server" at the
// instant they health-check, all N try to bind, only the winner gets it.
// The losers' bind() throws EADDRINUSE.
//
// Fix: catch EADDRINUSE here. If the URL is now alive (the winner has
// finished binding), exit 0 — the parent's BackendHandle still points
// at cfg.url, the AILANG runtime connects to the winner. If the URL is
// NOT alive (genuine port conflict with an unrelated process), exit 1.
let boundPort: number;
try {
  boundPort = await startEnvServer(requestedPort, workdir);
} catch (err: unknown) {
  const code = (err as NodeJS.ErrnoException).code;
  if (code === "EADDRINUSE" && requestedPort > 0) {
    // Brief delay so a sibling that won the race has a moment to finish
    // binding before we probe (some Node versions emit EADDRINUSE before
    // the winner's listen() callback fires).
    await new Promise((r) => setTimeout(r, 200));
    if (await healthCheck(requestedPort)) {
      process.stderr.write(`[env-server] port ${requestedPort} already serving (sibling won the race) — yielding\n`);
      process.exit(0);
    }
    process.stderr.write(`[env-server] port ${requestedPort} in use AND no /health response — genuine conflict\n`);
    process.exit(1);
  }
  throw err;
}

process.stdout.write(`[env-server] listening on http://127.0.0.1:${boundPort} workdir=${workdir}\n`);
