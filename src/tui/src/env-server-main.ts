import { startEnvServer } from "./env-server.js";

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

const boundPort = await startEnvServer(requestedPort, workdir);

process.stdout.write(`[env-server] listening on http://127.0.0.1:${boundPort} workdir=${workdir}\n`);
