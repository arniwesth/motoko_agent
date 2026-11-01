import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as http from "http";
import type { AddressInfo } from "net";
import * as os from "os";
import * as path from "path";
import { fileURLToPath } from "url";
import { interruptRuntime, RuntimeProcess, type AgentEvent } from "./runtime-process.js";

// ADR-002 D6's experiment as a test (041 PLAN-001 W3): cancelling a run should stop the command and
// its ordinary descendants, with no late effect. Today it does not. `rp.kill()` signals the runtime
// alone, the command leads its own process group, and nothing owns the deadline once the runtime is
// dead, so both markers below are written. That is sunholo-data/ailang#2034.
//
// THE TWO `it.failing` ROWS ARE THE WITNESS, EXPECTED TO FAIL BECAUSE OF #2034. The suite stays green
// while the defect stands and turns red when the behaviour changes: Jest reports "Failing test passed
// even though it was supposed to fail" (under this runner the printed row has an empty body, and the
// sentence is only in `--json`'s `failureDetails`). W9 then removes `.failing` from both rows. Do not weaken the
// assertions to make them pass, and do not read a green run as anything but the defect still being
// there. W3 satisfies no ADR criterion: A22 says a recorded failure alone does not, and W9 satisfies it.
//
// `it.failing` accepts ANY failure, so the expected failures assert nothing except the markers. The
// ordinary row is what says the experiment really ran. Should the experiment not run at all, no marker
// exists, and that row and both witness rows go red together.
//
// Everything is real: `RuntimeProcess`, `interruptRuntime`, the runtime, the supervisor, and a native
// `BashExec` dispatched from a model step. Only the provider is local, a loopback SSE endpoint whose
// first reply asks for the command. It needs `ailang` on PATH. A run takes about 7 s, plus about 30 s
// when the supervisor has to compile cold. SIGINT has its evidence only in
// scripts/verify_runtime_cancel_process_tree.sh, because `RuntimeProcess` sends SIGTERM alone.

const LIMIT_MS = 3000;
const MARKER_MS = LIMIT_MS + 1000;
/** Keep looking this long after the signal, well past the markers. It stops early once both exist. */
const OBSERVE_MS = MARKER_MS + 3000;
const START_BUDGET_MS = 240_000;

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

interface Observed {
  error: string | null;
  started: boolean;
  isParked: boolean | null;
  action: string | null;
  /** The signal reached a command still inside its limit, so the deadline cannot explain a marker. */
  signalledInsideLimit: boolean;
  runtimeExited: boolean;
  runtimeExitedClean: boolean;
  sawDone: boolean;
  dispatched: boolean;
  /** How long after the command started the markers were last read. */
  readAfterStartMs: number;
  commandMarker: boolean;
  descendantMarker: boolean;
}

/** An OpenAI-shaped stream: the first reply asks for the command, any later one finishes the run. */
function startProvider(cmd: string): Promise<http.Server> {
  let requests = 0;
  const chunk = (delta: object, finish: string | null) =>
    `data: ${JSON.stringify({
      id: "chatcmpl-w3",
      object: "chat.completion.chunk",
      created: 0,
      model: "w3-probe",
      choices: [{ index: 0, delta, finish_reason: finish }],
    })}\n\n`;
  const server = http.createServer((req, res) => {
    req.resume();
    req.on("end", () => {
      requests += 1;
      res.writeHead(200, { "content-type": "text/event-stream" });
      if (requests === 1) {
        const call = { index: 0, id: "call_w3", type: "function", function: { name: "BashExec", arguments: JSON.stringify({ cmd }) } };
        res.write(chunk({ role: "assistant", tool_calls: [call] }, null));
        res.write(chunk({}, "tool_calls"));
      } else {
        res.write(chunk({ role: "assistant", content: "finished" }, null));
        res.write(chunk({}, "stop"));
      }
      res.end("data: [DONE]\n\n");
    });
  });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server)));
}

function until(ready: () => boolean, budgetMs: number): Promise<boolean> {
  const deadline = Date.now() + budgetMs;
  return new Promise((resolve) => {
    const poll = () => {
      if (ready()) resolve(true);
      else if (Date.now() >= deadline) resolve(false);
      else setTimeout(poll, 20);
    };
    poll();
  });
}

describe("cancelling a run with a native BashExec in flight (ADR-002 D6)", () => {
  let workdir: string;
  let server: http.Server | undefined;
  let rp: RuntimeProcess | undefined;
  const savedEnv = { ...process.env };
  const observed: Observed = {
    error: null,
    started: false,
    isParked: null,
    action: null,
    signalledInsideLimit: false,
    runtimeExited: false,
    runtimeExitedClean: false,
    sawDone: false,
    dispatched: false,
    readAfterStartMs: 0,
    commandMarker: false,
    descendantMarker: false,
  };

  async function experiment(): Promise<void> {
    const startedPath = path.join(workdir, "started");
    const commandPath = path.join(workdir, "command-marker");
    const descendantPath = path.join(workdir, "descendant-marker");
    const seconds = MARKER_MS / 1000;
    const cmd = [
      `printf up > '${startedPath}'`,
      `(sleep ${seconds}; printf late > '${descendantPath}') &`,
      `sleep ${seconds}; printf late > '${commandPath}'`,
    ].join("\n");

    server = await startProvider(cmd);
    const port = (server.address() as AddressInfo).port;

    // `RuntimeProcess` runs `src/core/supervisor.ail` from the current directory, and Jest's is
    // src/tui. `exec` keeps the pid, so the signal still goes to the runtime and to nothing else.
    const bin = path.join(workdir, "ailang-from-repo-root.sh");
    fs.writeFileSync(bin, `#!/bin/sh\ncd '${REPO_ROOT}' || exit 97\nexec ailang "$@"\n`, { mode: 0o755 });
    process.env.AILANG_BIN = bin;
    process.env.MOTOKO_PROCESS_TIMEOUT = `${LIMIT_MS}ms`;
    process.env.MOTOKO_HEADLESS = "1";
    process.env.MOTOKO_REPO = REPO_ROOT;
    process.env.OPENAI_API_KEY = "placeholder-the-loopback-provider-ignores";

    let exited = false;
    const running = new RuntimeProcess(
      "run the command", "http://127.0.0.1:1", "w3-probe", workdir, "default", 1, "",
      `http://127.0.0.1:${port}/v1`, "",
      (e: AgentEvent) => {
        if (e.type === "done") observed.sawDone = true;
        if (e.type === "v2_tool_dispatch_start") observed.dispatched = true;
      },
      () => {
        exited = true;
      },
    );
    rp = running;

    observed.started = await until(() => fs.existsSync(startedPath) || exited, START_BUDGET_MS) && fs.existsSync(startedPath);
    if (!observed.started) return;

    const startedAt = fs.statSync(startedPath).mtimeMs;
    observed.isParked = running.isParked;
    observed.action = interruptRuntime(running);
    observed.signalledInsideLimit = Date.now() - startedAt < LIMIT_MS;

    observed.runtimeExited = await until(() => exited, OBSERVE_MS);
    const proc = (running as unknown as { proc: { exitCode: number | null } }).proc;
    observed.runtimeExitedClean = proc.exitCode === 0;

    await until(() => fs.existsSync(commandPath) && fs.existsSync(descendantPath), OBSERVE_MS);
    observed.readAfterStartMs = Date.now() - startedAt;
    observed.commandMarker = fs.existsSync(commandPath);
    observed.descendantMarker = fs.existsSync(descendantPath);
  }

  beforeAll(async () => {
    workdir = fs.mkdtempSync(path.join(os.tmpdir(), "runtime-cancel-"));
    // A throw here would fail every row, and `it.failing` would count that as its expected failure.
    await experiment().catch((err: unknown) => {
      observed.error = String(err);
    });
  }, START_BUDGET_MS + 2 * OBSERVE_MS + 10_000);

  afterAll(() => {
    rp?.kill();
    server?.closeAllConnections();
    server?.close();
    for (const key of ["AILANG_BIN", "MOTOKO_PROCESS_TIMEOUT", "MOTOKO_HEADLESS", "MOTOKO_REPO", "OPENAI_API_KEY"]) {
      const saved = savedEnv[key];
      if (saved === undefined) delete process.env[key];
      else process.env[key] = saved;
    }
    fs.rmSync(workdir, { recursive: true, force: true });
  });

  it("really ran: the command started under a native BashExec, the helper signalled it, the runtime died", () => {
    expect({
      error: observed.error,
      dispatched: observed.dispatched,
      started: observed.started,
      isParked: observed.isParked,
      action: observed.action,
      signalledInsideLimit: observed.signalledInsideLimit,
      runtimeExited: observed.runtimeExited,
      runtimeExitedClean: observed.runtimeExitedClean,
      sawDone: observed.sawDone,
    }).toEqual({
      error: null,
      dispatched: true,
      started: true,
      isParked: false,
      action: "kill",
      signalledInsideLimit: true,
      runtimeExited: true,
      runtimeExitedClean: false,
      sawDone: false,
    });
    expect(observed.readAfterStartMs).toBeGreaterThan(LIMIT_MS);
  });

  // Expected to fail until sunholo-data/ailang#2034 is fixed. W9 removes `.failing`.
  it.failing("the command writes no marker after the signal, past its limit (#2034)", () => {
    expect(observed.commandMarker).toBe(false);
  });

  // Expected to fail until sunholo-data/ailang#2034 is fixed. W9 removes `.failing`.
  it.failing("its ordinary descendant writes no marker after the signal, past the limit (#2034)", () => {
    expect(observed.descendantMarker).toBe(false);
  });
});
