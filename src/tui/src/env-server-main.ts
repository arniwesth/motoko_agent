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

const port = Number(argValue("--port") ?? "") || intEnv("ENV_PORT", 8080);
const workdir = argValue("--workdir") ?? process.env.WORKDIR ?? process.cwd();

startEnvServer(port, workdir);

process.stdout.write(`[env-server] listening on http://127.0.0.1:${port} workdir=${workdir}\n`);
