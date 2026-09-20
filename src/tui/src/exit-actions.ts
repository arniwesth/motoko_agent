import { spawnSync } from "child_process";
import { createHash } from "crypto";
import * as fs from "fs";
import { randomBytes } from "crypto";
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
 * and performs the two verbs below. `mot-owner` does not appear in this file, and neither does
 * `.dagr`: a publish names paths, and whether they may be written is decided by the operator's
 * grant, not by this file recognising what is in them.
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
 * and this file verifies the pane presents them before closing anything — without ever learning
 * whose panes are whose.
 *
 * WHAT THAT IS WORTH, STATED HONESTLY. It makes a STALE action no more dangerous than a fresh one,
 * which is the property the cache needed. It does NOT make the close atomic: `pane list` and
 * `pane close` are two calls, ownership can change between them, and every action in the manifest
 * is checked against one enumeration taken before any of them ran. Re-listing before each close
 * would shrink the window, not remove it; removing it needs an operation herdr does not offer —
 * close this pane incarnation if its token still matches. The pre-7.0 reaper had the same race,
 * and this is a best-effort snapshot check, not a guarantee that a reassigned pane is never
 * closed.
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

/**
 * Milliseconds the WHOLE exit dispatch may take, across every action.
 *
 * A per-call timeout is not a deadline, and the arithmetic is the argument: 32 actions naming 32
 * distinct binaries is 32 enumerations plus 32 closes, so a per-call bound of 1s permitted a
 * 64-second exit while the prose called it "bounded". This is checked between actions, so the true
 * worst case is this budget plus one in-flight call.
 */
export const EXIT_BUDGET_MS = 3000;

/**
 * Largest manifest this will read, in bytes. A file that grew past this is not parsed at all —
 * the reader is a fixed-size JSON document produced by a fold over registered atoms, so anything
 * larger is a sign the file is not what it claims and nothing good comes of parsing it at exit.
 */
export const MAX_MANIFEST_BYTES = 1 << 20;

export interface ClosePaneAction {
  kind: "close_pane";
  pane: string;
  tokenKey: string;
  tokenValue: string;
}

/**
 * The only verb a manifest may request.
 *
 * WHAT THIS TYPE USED TO HOLD, and why it does not any more. Through the first draft it also
 * carried `run_argv` ({bin, args}) and `publish_file` ({tmp, dest}), and `close_pane` named its own
 * `bin`. All three were arbitrary-execution or arbitrary-write surfaces reachable by anything that
 * can write one file under the workdir — another extension with FS access, an agent file tool, a
 * delegate sharing the checkout — performed at exit with this process's privileges, outside the
 * runtime's FS sandbox and outside its filtered child environment. "No shell" bought nothing when
 * `bin` could be `/bin/sh` and `args` could be `["-c", …]`.
 *
 * The executable is now resolved HERE, from this process's own environment, and is never read from
 * the file. A manifest writer can ask for a tagged pane to be closed and can ask for nothing else.
 */
/**
 * Publish a file the extension already wrote, by rename. ABI 7.1, and the SECOND and last verb.
 *
 * READ `ExitAction`'s note above before this one: 7.0 deleted a `publish_file` carrying two free
 * paths, and this is not that. Every one of the following must hold or the rename does not happen,
 * and the first four are what make the difference:
 *
 *   1. `MOTOKO_EXIT_PUBLISH_ROOT` is set in THIS process's environment. Unset — the default — and
 *      no publish in any manifest executes. The manifest cannot set it, name it, or widen it.
 *   2. Both paths are absolute and resolve inside that root. The check is on the REAL path of each
 *      parent directory, so a symlinked directory cannot walk out of the root.
 *   3. Neither path is a symlink, fifo, device or directory: `lstat().isFile()`, which is false for
 *      all of them.
 *   4. `dest` already EXISTS. There is no publish-if-absent mode, so a manifest cannot create files.
 *   5. `dest` hashes to `expect_sha256` — the extension's generation precondition, required. A
 *      digest and not a size: AILANG's `length` counts runes, so a byte count would disagree with
 *      `stat().size` for any run file holding a non-ASCII task title and refuse every publish on
 *      exactly the real data.
 *   6. `tmp` is at least as new as `dest`. THE MANIFEST CANNOT INFLUENCE THIS ONE, which is why it
 *      is here and not in the ABI: it is what actually catches a concurrent writer that happened to
 *      leave `dest` the same size.
 *
 * The host holds no content and serializes nothing: the extension wrote the bytes at turn end,
 * through its own routed ports, inside the runtime's FS sandbox. This half is one syscall.
 */
export interface PublishFileAction {
  kind: "publish_file";
  tmp: string;
  dest: string;
  expectSha256: string;
}

export type ExitAction = ClosePaneAction | PublishFileAction;

/**
 * The operator's grant. Read from this process's environment and never from a manifest.
 *
 * Its ABSENCE is the default and the safe direction: a publish verb that worked out of the box
 * would be a write surface every install carried whether or not anything needed it.
 */
export const EXIT_PUBLISH_ROOT_VAR = "MOTOKO_EXIT_PUBLISH_ROOT";

/**
 * Where the manifest for THIS session lives.
 *
 * The HOST names the file and forwards the name; the runtime reads the name and never derives one.
 * A derived path on both sides would be one more rule duplicated across a language boundary, which
 * is the MOT-118 shape this project has already paid for twice. Keyed by the session clock so two
 * Motokos in one checkout cannot overwrite each other's manifest.
 */
export function exitManifestPath(
  workdir: string,
  sessionMs: number | string = sessionStartMs(),
  nonce: string = sessionNonce(),
): string {
  return path.resolve(workdir, ".motoko", "exit", `manifest-${sessionMs}-${nonce}.json`);
}

/**
 * A random per-process suffix for the manifest name.
 *
 * A MILLISECOND IS NOT AN IDENTITY. Keyed on the clock alone, two Motokos started in the same
 * millisecond in one checkout share both the manifest and its `.tmp` — so one can publish over the
 * other, one can execute the other's actions, and the write-tmp-then-rename transaction stops
 * being atomic because two writers share the temporary inode. Concurrent sessions in one checkout
 * are an ordinary way to use herdr, which is the whole reason the run file is session-keyed too.
 *
 * This is uniqueness, not authorization: it stops an accident, not an attacker. What stops an
 * attacker is that a close carries a proof the pane must still present.
 */
let nonce: string | null = null;

export function sessionNonce(): string {
  if (nonce === null) nonce = randomBytes(8).toString("hex");
  return nonce;
}

/** Test seam: pins (or with null, releases) the nonce. */
export function __setSessionNonceForTests(value: string | null): void {
  nonce = value;
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

/** A non-empty string, or null. Never "" — see `parseAction` for why that distinction is load-bearing. */
function reqStr(v: unknown): string | null {
  return typeof v === "string" && v !== "" ? v : null;
}

/**
 * One action, or null.
 *
 * EVERY FIELD IS REQUIRED, and that is a fix rather than a preference. The first draft read a
 * missing `token_key` as "" and then treated "" as "close any pane that exists" — so the escape
 * hatch documented as deliberate was also what malformed input DECAYED to. A close request that
 * lost its proof in transit must be refused, not promoted to an unconditional close. There is no
 * unproven-close mode now; if one is ever wanted it needs its own authorization.
 */
function parseAction(raw: Record<string, unknown>): ExitAction | null {
  if (raw?.kind === "close_pane") {
    const pane = reqStr(raw.pane);
    const tokenKey = reqStr(raw.token_key);
    const tokenValue = reqStr(raw.token_value);
    if (!pane || !tokenKey || !tokenValue) return null;
    return { kind: "close_pane", pane, tokenKey, tokenValue };
  }
  if (raw?.kind === "publish_file") {
    const tmp = reqStr(raw.tmp);
    const dest = reqStr(raw.dest);
    // A DIGEST THAT IS NOT A DIGEST IS NOT A WILDCARD. Missing, empty, uppercase, truncated and
    // "any" are all refused rather than coerced: `expect_sha256` is the precondition, and a
    // precondition that decays to a permissive value on malformed input is the `token_key` mistake
    // in a new coat. The shape is checked here so the executor compares two digests or nothing.
    const expectSha256 = reqStr(raw.expect_sha256);
    if (!tmp || !dest || !expectSha256 || !/^[0-9a-f]{64}$/.test(expectSha256)) return null;
    return { kind: "publish_file", tmp, dest, expectSha256 };
  }
  return null;
}

/** Test seam: replaces every subprocess. Returns stdout. */
let runner: ((bin: string, args: string[]) => string) | null = null;

export function __setRunnerForTests(fn: ((bin: string, args: string[]) => string) | null): void {
  runner = fn;
}

function run(bin: string, args: string[]): string {
  if (runner) return runner(bin, args);
  try {
    // SYNCHRONOUS, and not by preference: an async spawn started inside an 'exit' handler never
    // runs, because the event loop is already closed.
    //
    // `killSignal: "SIGKILL"` IS THE FIX FOR A TIMEOUT THAT WAS NOT A DEADLINE. spawnSync's
    // `timeout` sends its kill signal and then WAITS for the child to die; the default SIGTERM is
    // catchable, so a child that handles it without exiting blocks this call past its nominal
    // bound — measured at 2.2s against a nominal 1000ms. SIGKILL cannot be caught, so the bound is
    // real. See `EXIT_BUDGET_MS` for the aggregate, which is the half that actually matters.
    const out = spawnSync(bin, args, {
      encoding: "utf8",
      timeout: CALL_TIMEOUT_MS,
      killSignal: "SIGKILL",
    });
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
  // No empty-key case: `parseAction` refuses an action without all three fields, so there is no
  // shape reaching here that means "close whatever exists".
  return tokens.get(action.pane)?.[action.tokenKey] === action.tokenValue;
}

export interface ExitActionReport {
  /** Actions actually performed, in order. */
  performed: ExitAction[];
  /** Actions the cap left undone. */
  truncated: number;
  /** Close actions skipped because the pane no longer presented the proof. */
  unproven: number;
  /** Actions abandoned because the aggregate budget ran out. */
  overBudget: number;
  /** Publish actions refused: no operator grant, outside the root, or a failed precondition. */
  refused: number;
}

/**
 * The operator-granted publish root, resolved to a real path, or null.
 *
 * Null for every reason: unset, relative, missing, not a directory, unreadable. A publish action
 * without a root is refused, so "cannot tell" and "not allowed" collapse to the same answer.
 */
export function resolvePublishRoot(env: NodeJS.ProcessEnv = process.env): string | null {
  const raw = env[EXIT_PUBLISH_ROOT_VAR] ?? "";
  if (raw === "" || !path.isAbsolute(raw)) return null;
  try {
    const real = fs.realpathSync(raw);
    return fs.statSync(real).isDirectory() ? real : null;
  } catch {
    return null;
  }
}

/**
 * `p`'s stats if it is an existing REGULAR file inside `root`, else null.
 *
 * The containment test is on the real path of the PARENT, not of `p` itself: `p` may be renamed
 * away a moment later, and resolving the parent is what stops a symlinked directory from walking
 * out of the grant. `lstatSync` and not `statSync`, so a symlink is rejected as itself rather than
 * followed to whatever it names.
 */
function containedRegularFile(p: string, root: string): fs.Stats | null {
  if (!path.isAbsolute(p)) return null;
  let parentReal: string;
  try {
    parentReal = fs.realpathSync(path.dirname(p));
  } catch {
    return null;
  }
  if (parentReal !== root && !parentReal.startsWith(root + path.sep)) return null;
  try {
    const st = fs.lstatSync(p);
    return st.isFile() ? st : null;
  } catch {
    return null;
  }
}

/** One publish, or false with nothing written. Every check in `PublishFileAction`'s list, in order. */
function performPublish(a: PublishFileAction, root: string | null): boolean {
  if (!root) return false;
  const tmpSt = containedRegularFile(a.tmp, root);
  if (!tmpSt) return false;
  // `dest` must ALREADY EXIST: no publish-if-absent mode, so this cannot create a file.
  const destSt = containedRegularFile(a.dest, root);
  if (!destSt) return false;
  // Hashed, not sized — see `PublishFileAction`. The file is a run document of a few KB and this
  // runs once per publish at exit.
  let actual: string;
  try {
    actual = createHash("sha256").update(fs.readFileSync(a.dest)).digest("hex");
  } catch {
    return false;
  }
  if (actual !== a.expectSha256) return false;
  // The host's own guard, which no manifest can influence.
  if (tmpSt.mtimeMs < destSt.mtimeMs) return false;
  try {
    fs.renameSync(a.tmp, a.dest);
    return true;
  } catch {
    return false;
  }
}

/**
 * Perform a manifest's actions. Synchronous, bounded, best-effort, and safe to call twice — the
 * second pass finds panes already closed and a tmp file already renamed.
 */
/**
 * Perform a manifest's actions with a host-resolved `bin`. Synchronous, bounded by BOTH the action
 * cap and the aggregate budget, best-effort, and safe to call twice — the second pass finds the
 * panes already closed.
 *
 * `bin` is a PARAMETER, not a field of any action: the caller supplies the multiplexer it already
 * knows about from its own environment. Nothing in the manifest can name an executable.
 */
export function performExitActions(
  actions: ExitAction[],
  bin: string,
  now: () => number = Date.now,
  publishRoot: string | null = null,
): ExitActionReport {
  const targets = actions.slice(0, EXIT_ACTION_LIMIT);
  const report: ExitActionReport = {
    performed: [],
    truncated: actions.length - targets.length,
    unproven: 0,
    overBudget: 0,
    refused: 0,
  };
  if (targets.length === 0) return report;

  // A PUBLISH NEEDS NO BINARY, so `bin` stopped being a precondition for the whole dispatch when
  // 7.1 landed. It is still a precondition for every CLOSE: no binary means no way to close a pane,
  // and inventing one is exactly what this file must not do.
  const closes = targets.filter((a): a is ClosePaneAction => a.kind === "close_pane");
  if (closes.length > 0 && !bin) report.overBudget = closes.length;

  const deadline = now() + EXIT_BUDGET_MS;
  // One enumeration for the whole manifest: every close names the same server, because the server
  // is ours and not the file's. Skipped entirely when nothing needs it — a manifest of publishes
  // should not spawn a subprocess at exit.
  const tokens =
    closes.length > 0 && bin ? paneTokens(run(bin, ["pane", "list"])) : new Map<string, Record<string, string>>();

  for (let i = 0; i < targets.length; i += 1) {
    const a = targets[i]!;
    if (now() >= deadline) {
      report.overBudget += targets.length - i;
      break;
    }
    if (a.kind === "publish_file") {
      if (performPublish(a, publishRoot)) report.performed.push(a);
      else report.refused += 1;
      continue;
    }
    if (!bin) continue;
    if (!paneProofHolds(tokens, a)) {
      report.unproven += 1;
      continue;
    }
    run(bin, ["pane", "close", a.pane]);
    report.performed.push(a);
  }

  if (report.truncated > 0) {
    process.stderr.write(
      `motoko: performed ${report.performed.length} exit actions; ${report.truncated} left undone (limit ${EXIT_ACTION_LIMIT})\n`,
    );
  }
  if (report.overBudget > 0) {
    process.stderr.write(
      `motoko: exit budget of ${EXIT_BUDGET_MS}ms spent; ${report.overBudget} action(s) left undone\n`,
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
export function runExitActions(env: NodeJS.ProcessEnv = process.env): ExitActionReport {
  const empty: ExitActionReport = { performed: [], truncated: 0, unproven: 0, overBudget: 0, refused: 0 };
  if (dispatched) return empty;
  dispatched = true;
  const p = manifestPath;
  if (!p) return empty;

  // THE EXECUTABLE COMES FROM HERE AND NOWHERE ELSE. `HERDR_BIN_PATH` is injected into the pane by
  // the multiplexer itself; the manifest has no say. Outside a pane there is nothing to close and
  // nothing is run.
  const bin = env.HERDR_BIN_PATH ?? "";

  let json: string;
  try {
    // A REGULAR FILE, AND A BOUNDED ONE. `statSync` before `readFileSync` so a fifo or a device
    // node cannot block the exit path, and a size cap so a file that grew past anything this
    // producer could write is refused rather than parsed.
    const st = fs.statSync(p);
    if (!st.isFile() || st.size > MAX_MANIFEST_BYTES) return empty;
    json = fs.readFileSync(p, "utf8");
  } catch {
    return empty;
  }
  try {
    return performExitActions(parseExitManifest(json), bin, Date.now, resolvePublishRoot(env));
  } catch {
    // Never let an exit action keep Motoko from exiting.
    return empty;
  }
}

/**
 * Register the exit-time dispatch. ONE 'exit' listener, and deliberately no signal handlers.
 *
 * WHY NOT SIGINT/SIGTERM. The obvious reasoning — "a signal with no listener terminates the process
 * without running 'exit' handlers, so register for the signals too" — produced a handler that ran
 * the actions and then returned. Installing a listener REMOVES Node's default termination, so that
 * handler turned Ctrl+C into a no-op: measured, a process with it installed survived both SIGINT
 * and SIGTERM. It did not surface in the real TUI only because `env-server.ts` registers its own
 * SIGINT/SIGTERM handlers at `index.ts:779`, before this one, and those call `process.exit(0)` —
 * which fires 'exit' listeners, including this one. So the correct behaviour was already there and
 * this file was contributing a latent hang behind it.
 *
 * The rule that follows: signal termination has ONE owner in this process, and it is not this file.
 * An 'exit' listener is all a cleanup needs, because every path that terminates deliberately goes
 * through `process.exit()`. `herdr-agent-state.ts` still carries a re-raising SIGINT/SIGTERM pair
 * of its own that predates this work and has the same shape of problem; it is left alone here
 * rather than folded into an unrelated change.
 *
 * Registered BEFORE the herdr reporter's 'exit' hook: Node runs 'exit' listeners in registration
 * order, and giving lifecycle authority back to herdr should be the last thing that happens.
 */
export function initExitActions(): void {
  process.on("exit", () => {
    runExitActions();
  });
}
