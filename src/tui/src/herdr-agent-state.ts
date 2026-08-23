/**
 * herdr-agent-state — report Motoko's lifecycle to a herdr session, so herdr treats Motoko
 * as a first-class agent rather than as an unrecognised process in a pane.
 *
 * Decision record: `.agent/projects/020_herdr_agent_integration/ADR-001-herdr-agent-integration.md`.
 *
 * WHY THIS EXISTS AS CODE AND NOT AS CONFIGURATION. herdr recognises agents two ways. The default
 * is a *screen manifest*: it reads the bottom of the pane buffer and pattern-matches a known
 * agent's UI. That route is closed to Motoko — herdr's own docs state that "adding a completely
 * new agent still requires a Herdr binary update", and the local override directory
 * (~/.config/herdr/agent-detection/<agent>.toml) only replaces manifests for agents it already
 * knows. The second route is a *custom integration*, which explicitly does "not need to be built
 * into Herdr or use a recognized agent executable": the process reports its own state over
 * herdr's local socket. This module is that report.
 *
 * The result is the stronger of the two. An agent that reports its own lifecycle is a herdr
 * "lifecycle authority" — herdr stops running screen detection for the pane and takes these
 * reports as truth. Claude Code and Codex are screen-manifest agents, so Motoko is better
 * integrated here than either of them.
 *
 * EVERY EXPORTED FUNCTION IS INERT OUTSIDE HERDR. `HERDR_ENV=1`, `HERDR_PANE_ID` and
 * `HERDR_BIN_PATH` are injected by herdr into the processes it launches in a pane; when any is
 * missing, `initHerdrReporter` installs nothing and the report functions return immediately. That
 * covers the ordinary devcontainer, CI, and a plain terminal.
 *
 * IT MUST NEVER BE ABLE TO BREAK OR STALL THE TUI. Reports are fire-and-forget child processes
 * with output discarded and errors swallowed; the one synchronous call is the release on exit,
 * which carries a hard timeout. A broken or absent herdr binary costs nothing but the absence of
 * a sidebar row.
 */

import { spawn, spawnSync } from "child_process";

/**
 * Motoko's own run states, restated here rather than imported from ui.ts.
 *
 * The duplication is deliberate and load-bearing in two directions. It keeps this module free of
 * any dependency on ui.ts, which imports *it* — a cycle otherwise. And it turns "someone added a
 * run state and forgot the mapping" into a compile error: `reportRunState` takes this union, ui.ts
 * passes it a `RunState`, so a new `RunState` member that is absent here fails to typecheck at the
 * call site rather than silently reporting nothing.
 */
export type MotokoRunState = "idle" | "thinking" | "tools_wait" | "tools_run" | "error";

/** The four states herdr's `pane report-agent --state` accepts. */
export type HerdrState = "idle" | "working" | "blocked" | "unknown";

/**
 * The agent label herdr shows in the sidebar and accepts as a command target. herdr requires
 * `[a-z][a-z0-9_-]{0,31}`.
 */
export const HERDR_AGENT_LABEL = "motoko";

/**
 * The reporting source. herdr keys lifecycle authority on this string, so it must be stable across
 * releases — changing it orphans the authority a running pane already granted. herdr allows at most
 * 80 characters of ASCII letters, digits, colon, dot, underscore and hyphen.
 */
export const HERDR_SOURCE = "custom:motoko";

export interface HerdrReport {
  state: HerdrState;
  /** herdr shows this beside a blocked row. Only set where it says something the state does not. */
  message?: string;
}

/**
 * Motoko's run state -> herdr's lifecycle vocabulary.
 *
 * Four of the five are direct. `error` is a judgment call, recorded in ADR-001 D3: herdr defines
 * `blocked` as "recognized an approval or question UI", and Motoko has no approval UI at all — that
 * absence is why project 018 runs delegates with permission bypass on. But `blocked` is the state
 * that turns the sidebar row red, rolls up to the tab and workspace, and satisfies
 * `herdr agent wait --until blocked`, which is exactly the behaviour an errored run wants. The
 * alternative, `unknown`, means "herdr cannot classify this" and would leave a failed run looking
 * indistinguishable from a detection gap.
 *
 * If Motoko ever grows a real approval prompt, that becomes the true `blocked` and this mapping
 * must be revisited — see ADR-001 Consequences.
 */
export function mapRunState(state: MotokoRunState): HerdrReport {
  switch (state) {
    case "idle":
      return { state: "idle" };
    case "thinking":
    case "tools_wait":
    case "tools_run":
      return { state: "working" };
    case "error":
      return { state: "blocked", message: "the run ended in an error — see the pane" };
  }
}

export interface HerdrEnvironment {
  /** The pane this process was launched in. Every report is addressed to it. */
  paneId: string;
  /**
   * The herdr binary, taken from HERDR_BIN_PATH rather than resolved from PATH. herdr injects the
   * absolute path to the running server's own binary, which is what its integration guide tells
   * custom reporters to invoke: a `herdr` found on PATH could be a different build, and inside
   * agent_confined it could be a self-updated copy in ~/.local/bin shadowing the operator's.
   */
  bin: string;
}

/**
 * Read herdr's injected environment, or null when this process is not running in a herdr pane.
 *
 * Pure, and takes the environment as an argument, so the "are we inside herdr" decision is
 * testable without touching process.env.
 */
export function readHerdrEnvironment(env: NodeJS.ProcessEnv): HerdrEnvironment | null {
  // herdr's guidance is to report only when HERDR_ENV=1, so that an integration is a no-op
  // everywhere else. All three are required: a pane id with no binary cannot report, and a binary
  // with no pane id has nothing to report about.
  if (env.HERDR_ENV !== "1") return null;
  const paneId = env.HERDR_PANE_ID;
  const bin = env.HERDR_BIN_PATH;
  if (!paneId || !bin) return null;
  return { paneId, bin };
}

/**
 * The argv for one `pane report-agent` call.
 *
 * `seq` is not decoration. Reports are fire-and-forget child processes, so two transitions close
 * together can reach the server out of order; herdr ignores a report whose sequence is lower than
 * one it has already accepted from the same source. Without it, a fast working -> idle pair can
 * leave the sidebar showing `working` for ever.
 */
export function buildReportArgs(
  paneId: string,
  report: HerdrReport,
  seq: number,
): string[] {
  const args = [
    "pane",
    "report-agent",
    paneId,
    "--source",
    HERDR_SOURCE,
    "--agent",
    HERDR_AGENT_LABEL,
    "--state",
    report.state,
    "--seq",
    String(seq),
  ];
  if (report.message) args.push("--message", report.message);
  return args;
}

/** The argv that hands herdr this run's transcript, for display in `agent get` / `agent list`. */
export function buildSessionArgs(paneId: string, sessionPath: string, seq: number): string[] {
  return [
    "pane",
    "report-agent-session",
    paneId,
    "--source",
    HERDR_SOURCE,
    "--agent",
    HERDR_AGENT_LABEL,
    "--agent-session-path",
    sessionPath,
    "--seq",
    String(seq),
  ];
}

/** The argv that gives up lifecycle authority, so the sidebar does not keep a dead row. */
export function buildReleaseArgs(paneId: string, seq: number): string[] {
  return [
    "pane",
    "release-agent",
    paneId,
    "--source",
    HERDR_SOURCE,
    "--agent",
    HERDR_AGENT_LABEL,
    "--seq",
    String(seq),
  ];
}

// --------------------------------------------------------------------------------------------
// The impure half: one module-level reporter, installed once.
// --------------------------------------------------------------------------------------------

let active: HerdrEnvironment | null = null;
let seq = 0;
let released = false;

/** Test seam: the last argv each helper would have spawned, when capture is installed. */
let spawnHook: ((args: string[]) => void) | null = null;

/** Installs a capture function in place of spawning, and returns a restore callback. */
export function __setSpawnHookForTests(hook: ((args: string[]) => void) | null): void {
  spawnHook = hook;
}

/** Resets module state between tests. Not called in production. */
export function __resetForTests(): void {
  active = null;
  seq = 0;
  released = false;
}

function fire(args: string[]): void {
  if (spawnHook) {
    spawnHook(args);
    return;
  }
  if (!active) return;
  try {
    // Detached from our stdio and unref'd: a herdr server that never answers must not keep the
    // Motoko process alive at exit, and its output must never land in the TUI's terminal.
    const child = spawn(active.bin, args, { stdio: "ignore", detached: false });
    child.unref();
    // A spawn that fails asynchronously (binary vanished, EAGAIN) emits 'error'; without a listener
    // Node turns that into an unhandled exception and kills the TUI over a sidebar update.
    child.on("error", () => {});
  } catch {
    // Same reasoning for the synchronous throw. Reporting is best-effort by construction.
  }
}

/**
 * Detect herdr, register the exit hooks, and report the initial state.
 *
 * The initial report is not redundant. ui.ts's `setRunState` returns early when the state is
 * unchanged, and Motoko starts in `idle` — so without an explicit first report the pane would not
 * become an agent row until the user's first task, which is precisely when they are looking at the
 * sidebar to see that it started.
 *
 * Returns true when Motoko is running inside a herdr pane.
 */
export function initHerdrReporter(env: NodeJS.ProcessEnv = process.env): boolean {
  active = readHerdrEnvironment(env);
  if (!active) return false;

  reportRunState("idle");

  // Release on the way out, so the sidebar does not keep a "motoko working" row for a process that
  // is gone. herdr does not clear a custom source on its own: a custom reporter is not tied to a
  // detected process, which is the same property that lets it work at all.
  //
  // 'exit' covers process.exit(), which is how index.ts terminates on every normal path — and there
  // are several. SIGINT/SIGTERM are registered separately because a signal with no listener
  // terminates the process WITHOUT running 'exit' handlers.
  process.on("exit", () => releaseHerdrReporter());
  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.on(signal, () => {
      releaseHerdrReporter();
      // Re-raise with the default disposition, so this handler does not change how Motoko dies.
      process.kill(process.pid, signal);
    });
  }
  return true;
}

/** Report a Motoko run-state transition. Call it from the one place transitions happen. */
export function reportRunState(state: MotokoRunState): void {
  if (!active && !spawnHook) return;
  const paneId = active?.paneId ?? "test-pane";
  fire(buildReportArgs(paneId, mapRunState(state), ++seq));
}

/**
 * Tell herdr where this run's transcript is.
 *
 * Informational only, and worth being clear about why: herdr uses a native session reference for
 * automatic restore, but restoring also requires herdr to know how to LAUNCH the agent, and Motoko
 * is not one of its known kinds. So this surfaces the path in `herdr agent get` and nothing more.
 */
export function reportSessionPath(sessionPath: string): void {
  if (!active && !spawnHook) return;
  const paneId = active?.paneId ?? "test-pane";
  fire(buildSessionArgs(paneId, sessionPath, ++seq));
}

/**
 * Give up lifecycle authority. Idempotent — several exit paths can reach it, and a second release
 * would be a stray report against a pane that may already host something else.
 */
export function releaseHerdrReporter(): void {
  if (released) return;
  if (!active && !spawnHook) return;
  released = true;
  const paneId = active?.paneId ?? "test-pane";
  const args = buildReleaseArgs(paneId, ++seq);
  if (spawnHook) {
    spawnHook(args);
    return;
  }
  try {
    // SYNCHRONOUS here, unlike every other report: an async spawn started inside an 'exit' handler
    // never runs, because the event loop is already closed. The timeout is the safeguard that keeps
    // that from turning into a hang on a wedged herdr server.
    spawnSync(active!.bin, args, { stdio: "ignore", timeout: 1000 });
  } catch {
    // Best-effort: a stale sidebar row is a far smaller problem than a Motoko that cannot exit.
  }
}
