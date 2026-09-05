import { spawnSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import { sessionStartMs } from "./session-identity.js";

/**
 * Execute the exit actions extensions published for this session — the host half of ABI 7.0's
 * `ExitIntent`.
 *
 * WHAT THIS FILE REPLACED, AND WHY IT HAD TO. `herdr-reap.ts` did this job for one extension, and
 * to do it, it had to know things that were never the host's: the token key `mot-owner`, the token
 * FORMAT, the `herdr pane list` JSON shape, and the `HERDR_REAP_ON_EXIT` opt-in. A pluggable
 * extension that requires hardcoded TUI changes is not pluggable, and every one of those four
 * facts was a second copy of a rule whose first copy lives in AILANG.
 *
 * Nothing here knows what a delegate is. It reads a manifest, checks a proof the manifest names,
 * and performs three kinds of action. `mot-owner` does not appear in this file.
 *
 * WHY A MANIFEST FILE RATHER THAN A CALL INTO THE EXTENSION. The extension's code runs in the
 * AILANG runtime, a child process that is normally already gone by the time this runs — and even
 * when it is not, an async spawn started inside an `exit` handler never runs, because the event
 * loop is already closed. So the extension computes its actions while it is alive (at every turn
 * end) and publishes them; this reads what it finds. "Computed from already-known data" is a
 * consequence of the architecture rather than a rule anyone has to remember.
 *
 * WHY THE TOKEN CHECK IS STILL HERE WHEN THE POLICY IS NOT. A cached action is a claim about a
 * past moment, and pane ids can be recycled. `close_pane` therefore carries the pane id AND the
 * token that must still be on it; the extension decides which key and which value prove ownership,
 * and this file verifies the pane presents them before closing anything. That is what buys back
 * the freshness the cache gives up, without teaching the host whose panes are whose.
 *
 * WHAT IT CANNOT DO. SIGKILL, a power loss, or a crash runs nothing at all — the manifest is a
 * best-effort courtesy on a clean exit, and every producer needs its own startup-side backstop
 * (for delegate panes that is the orphan sweep in `packages/motoko-ext-herdr`).
 */

/** The manifest shape this dispatcher understands. Mirrors `exit_manifest.manifest_version()`. */
export const EXIT_MANIFEST_VERSION = "exit-actions/1";

/**
 * How many actions one exit may perform. A wedged server must not be able to hold the process open
 * indefinitely, and a truncated sweep that reads as a complete one is the failure worth avoiding —
 * so the cap is announced when it bites.
 */
export const EXIT_ACTION_LIMIT = 32;

/** Milliseconds any single subprocess at exit may take. Synchronous by necessity — see `run`. */
const CALL_TIMEOUT_MS = 1000;

export interface ClosePaneAction {
  kind: "close_pane";
  bin: string;
  pane: string;
  tokenKey: string;
  tokenValue: string;
}

export interface PublishFileAction {
  kind: "publish_file";
  tmp: string;
  dest: string;
}

export interface RunArgvAction {
  kind: "run_argv";
  bin: string;
  args: string[];
}

export type ExitAction = ClosePaneAction | PublishFileAction | RunArgvAction;

/**
 * Where the manifest for THIS session lives.
 *
 * The HOST names the file and forwards the name; the runtime reads the name and never derives one.
 * A derived path on both sides would be one more rule duplicated across a language boundary, which
 * is the MOT-118 shape this project has already paid for twice. Keyed by the session clock so two
 * Motokos in one checkout cannot overwrite each other's manifest.
 */
export function exitManifestPath(workdir: string, sessionMs: number | string = sessionStartMs()): string {
  return path.resolve(workdir, ".motoko", "exit", `manifest-${sessionMs}.json`);
}

/**
 * The path this process will read at exit, remembered when a runtime is spawned.
 *
 * Null until `buildChildEnv` names one. A Motoko that never started a runtime has nothing to
 * execute, and this is how it knows.
 */
let manifestPath: string | null = null;

export function rememberExitManifestPath(p: string | null): void {
  manifestPath = p;
}

export function currentExitManifestPath(): string | null {
  return manifestPath;
}

/**
 * Read a published manifest into actions, in order.
 *
 * FAIL CLOSED, EVERY TIME. Unparseable JSON, a version this build does not know, a missing
 * `intents` array, an action of an unknown kind, or an action missing a field it needs all yield
 * NOTHING for that item rather than a guess. Executing a subset of a manifest we half-understood
 * while reporting a completed sweep is the one outcome worth engineering against.
 */
export function parseExitManifest(json: string): ExitAction[] {
  let doc: unknown;
  try {
    doc = JSON.parse(json);
  } catch {
    return [];
  }
  const root = doc as { version?: unknown; intents?: unknown };
  if (root?.version !== EXIT_MANIFEST_VERSION) return [];
  if (!Array.isArray(root.intents)) return [];

  const actions: ExitAction[] = [];
  for (const intent of root.intents as Array<{ enabled?: unknown; actions?: unknown }>) {
    // A disclosed-but-disabled intent publishes an empty list already; honouring `enabled` here
    // too means a manifest cannot be made to act by hand-editing only the actions.
    if (intent?.enabled !== true) continue;
    if (!Array.isArray(intent.actions)) continue;
    for (const raw of intent.actions as Array<Record<string, unknown>>) {
      const parsed = parseAction(raw);
      if (parsed) actions.push(parsed);
    }
  }
  return actions;
}

function str(v: unknown): string {
  return typeof v === "string" ? v : "";
}

function parseAction(raw: Record<string, unknown>): ExitAction | null {
  switch (raw?.kind) {
    case "close_pane": {
      const bin = str(raw.bin);
      const pane = str(raw.pane);
      if (!bin || !pane) return null;
      return {
        kind: "close_pane",
        bin,
        pane,
        tokenKey: str(raw.token_key),
        tokenValue: str(raw.token_value),
      };
    }
    case "publish_file": {
      const tmp = str(raw.tmp);
      const dest = str(raw.dest);
      if (!tmp || !dest) return null;
      return { kind: "publish_file", tmp, dest };
    }
    case "run_argv": {
      const bin = str(raw.bin);
      if (!bin) return null;
      const args = Array.isArray(raw.args) ? raw.args.filter((a): a is string => typeof a === "string") : [];
      return { kind: "run_argv", bin, args };
    }
    default:
      return null;
  }
}

/** Test seam: replaces every subprocess. Returns stdout. */
let runner: ((bin: string, args: string[]) => string) | null = null;

export function __setRunnerForTests(fn: ((bin: string, args: string[]) => string) | null): void {
  runner = fn;
}

/** Test seam: replaces the rename `publish_file` performs. */
let renamer: ((tmp: string, dest: string) => void) | null = null;

export function __setRenamerForTests(fn: ((tmp: string, dest: string) => void) | null): void {
  renamer = fn;
}

function run(bin: string, args: string[]): string {
  if (runner) return runner(bin, args);
  try {
    // SYNCHRONOUS, and not by preference: an async spawn started inside an 'exit' handler never
    // runs, because the event loop is already closed. The timeout is what keeps that from turning
    // into a hang on a wedged server.
    const out = spawnSync(bin, args, { encoding: "utf8", timeout: CALL_TIMEOUT_MS });
    return out.stdout ?? "";
  } catch {
    // Best-effort by construction: an action that did not happen is a smaller problem than a
    // Motoko that cannot exit.
    return "";
  }
}

interface PaneRow {
  pane_id?: string;
  tokens?: Record<string, string>;
}

/**
 * The tokens each pane currently carries, from one `<bin> pane list`.
 *
 * ONE CALL PER BINARY, not one per pane: the close actions of a session all name the same server,
 * and the exit budget is small enough that the difference is the whole design.
 */
export function paneTokens(listJson: string): Map<string, Record<string, string>> {
  const out = new Map<string, Record<string, string>>();
  let rows: PaneRow[];
  try {
    const parsed = JSON.parse(listJson) as { result?: { panes?: PaneRow[] } };
    rows = parsed?.result?.panes ?? [];
  } catch {
    return out;
  }
  if (!Array.isArray(rows)) return out;
  for (const row of rows) {
    const id = row?.pane_id;
    if (!id) continue;
    out.set(id, row?.tokens ?? {});
  }
  return out;
}

/**
 * Does this pane still present the proof the action named?
 *
 * A pane that is gone, or that lost the token, or that never had it, is NOT ours to close. The
 * empty key is the deliberate "no proof required" case, which a caller has to write on purpose.
 */
export function paneProofHolds(
  tokens: Map<string, Record<string, string>>,
  action: ClosePaneAction,
): boolean {
  if (action.tokenKey === "") return tokens.has(action.pane);
  return tokens.get(action.pane)?.[action.tokenKey] === action.tokenValue;
}

export interface ExitActionReport {
  /** Actions actually performed, in order. */
  performed: ExitAction[];
  /** Actions the cap left undone. */
  truncated: number;
  /** Close actions skipped because the pane no longer presented the proof. */
  unproven: number;
}

/**
 * Perform a manifest's actions. Synchronous, bounded, best-effort, and safe to call twice — the
 * second pass finds panes already closed and a tmp file already renamed.
 */
export function performExitActions(actions: ExitAction[]): ExitActionReport {
  const targets = actions.slice(0, EXIT_ACTION_LIMIT);
  const report: ExitActionReport = { performed: [], truncated: actions.length - targets.length, unproven: 0 };
  if (targets.length === 0) return report;

  // Resolve the proofs first, one `pane list` per distinct binary, so a manifest with twenty
  // closes costs one enumeration rather than twenty.
  const tokensByBin = new Map<string, Map<string, Record<string, string>>>();
  for (const a of targets) {
    if (a.kind !== "close_pane" || tokensByBin.has(a.bin)) continue;
    tokensByBin.set(a.bin, paneTokens(run(a.bin, ["pane", "list"])));
  }

  for (const a of targets) {
    switch (a.kind) {
      case "close_pane": {
        const tokens = tokensByBin.get(a.bin) ?? new Map();
        if (!paneProofHolds(tokens, a)) {
          report.unproven += 1;
          continue;
        }
        run(a.bin, ["pane", "close", a.pane]);
        report.performed.push(a);
        break;
      }
      case "publish_file": {
        try {
          // A rename, not a copy, and not a subprocess: this is the half of the extension's
          // write-tmp-then-publish transaction that has to happen last. `renameSync` is one
          // syscall, which is what makes it affordable inside the exit budget at all.
          if (renamer) renamer(a.tmp, a.dest);
          else fs.renameSync(a.tmp, a.dest);
          report.performed.push(a);
        } catch {
          // The destination keeps its previous version. A stale file beats a truncated one.
        }
        break;
      }
      case "run_argv": {
        run(a.bin, a.args);
        report.performed.push(a);
        break;
      }
    }
  }

  if (report.truncated > 0) {
    process.stderr.write(
      `motoko: performed ${targets.length} exit actions; ${report.truncated} left undone (limit ${EXIT_ACTION_LIMIT})\n`,
    );
  }
  return report;
}

/** Idempotence guard: several exit paths reach the dispatcher, and one pass is the contract. */
let dispatched = false;

export function __resetExitDispatchForTests(): void {
  dispatched = false;
}

/**
 * Read the published manifest and perform what it holds. The whole exit-time surface.
 *
 * A missing manifest is the ordinary case, not an error: a session that spawned no runtime, or an
 * install with no extension declaring an intent, has nothing to do here and says nothing.
 */
export function runExitActions(): ExitActionReport {
  const empty: ExitActionReport = { performed: [], truncated: 0, unproven: 0 };
  if (dispatched) return empty;
  dispatched = true;
  const p = manifestPath;
  if (!p) return empty;
  let json: string;
  try {
    json = fs.readFileSync(p, "utf8");
  } catch {
    return empty;
  }
  try {
    return performExitActions(parseExitManifest(json));
  } catch {
    // Never let an exit action keep Motoko from exiting.
    return empty;
  }
}

/**
 * Register the exit-time dispatch.
 *
 * BEFORE the herdr reporter's own hooks, deliberately: Node runs 'exit' listeners in registration
 * order, and giving lifecycle authority back to herdr should be the last thing that happens, after
 * whatever the session still owned has been dealt with.
 *
 * 'exit' covers `process.exit()`, which is how index.ts terminates on every normal path.
 * SIGINT/SIGTERM are registered separately because a signal with no listener terminates the process
 * WITHOUT running 'exit' handlers — and `runExitActions` is idempotent, so a signal followed by an
 * exit performs one pass, not two.
 */
export function initExitActions(): void {
  process.on("exit", () => {
    runExitActions();
  });
  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.on(signal, () => {
      runExitActions();
    });
  }
}
